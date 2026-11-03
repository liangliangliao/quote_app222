part of 'repository.dart';

extension QuoteKnowledgeEconomy on QuoteKnowledgeRepository {
  Future<void> initializeEconomy(Database db) async {
    await db.transaction((txn) async {
      final row = (await txn.query('qk_ai_budget', where: 'id=1')).single;
      if (row['migrated'] == 0) {
        await txn.rawUpdate(
            "UPDATE qk_jobs SET status='blocked',last_error='已停用旧版自动重试，请按需手动继续整理。' WHERE status IN ('retry','waiting_model','running')");
        await txn.update('qk_ai_budget', {'migrated': 1}, where: 'id=1');
      }
    });
  }

  Future<ClassificationUsage> usage() async {
    final db = await database,
        b = (await db.query('qk_ai_budget', where: 'id=1')).single;
    final counts = await db
        .rawQuery('SELECT method,COUNT(*) AS n FROM qk_jobs GROUP BY method');
    int n(String method) => counts
        .where((c) => c['method'] == method)
        .fold(0, (n, c) => n + (c['n'] as num).toInt());
    final blocked = (await db.rawQuery(
            "SELECT COUNT(*) AS n FROM qk_jobs WHERE status IN ('blocked','budget')"))
        .single['n'] as num;
    return ClassificationUsage(
        limit: b['request_limit'] as int,
        used: b['used'] as int,
        estimatedUsed: b['estimated_used'] as int,
        estimatedLimit: 0,
        stopped: b['stopped'] == 1,
        running: (b['lease_ms'] as int) > now().millisecondsSinceEpoch,
        local: n('local'),
        cached: n('cache') + n('batch'),
        ai: n('ai'),
        blocked: blocked.toInt());
  }

  Future<void> beginRound(
      {int requestLimit = ClassificationCostPolicy.defaultRequests}) async {
    if (![1, 3, 6].contains(requestLimit)) throw ArgumentError('请选择1、3或6次请求上限');
    final db = await database;
    await db.transaction((txn) async {
      final b = (await txn.query('qk_ai_budget', where: 'id=1')).single;
      if ((b['lease_ms'] as int) > now().millisecondsSinceEpoch) {
        await txn.update('qk_ai_budget', {'request_limit': requestLimit},
            where: 'id=1');
        return;
      }
      // Repeated clicks/restarts do not replenish an unfinished allowance.
      if (b['stopped'] == 1 ||
          (b['used'] as int) >= (b['request_limit'] as int)) {
        await txn.update(
            'qk_ai_budget',
            {
              'request_limit': requestLimit,
              'used': 0,
              'estimated_used': 0,
              'stopped': 0,
              'token': '',
              'lease_ms': 0
            },
            where: 'id=1');
      } else {
        await txn.update('qk_ai_budget', {'request_limit': requestLimit},
            where: 'id=1');
      }
    });
  }

  Future<AiReservation> reserveRequest(
      List<ClassificationClaim> claims, int estimate) async {
    final db = await database, ms = now().millisecondsSinceEpoch;
    final reservation = await db.transaction((txn) async {
      final b = (await txn.query('qk_ai_budget', where: 'id=1')).single;
      if ((b['lease_ms'] as int) > ms) return const AiReservation('busy');
      if (b['stopped'] == 1 ||
          (b['used'] as int) >= (b['request_limit'] as int)) {
        await txn.update('qk_ai_budget', {'stopped': 1}, where: 'id=1');
        return const AiReservation('budget');
      }
      for (final c in claims) {
        final rows = await txn.query('qk_jobs',
            where: "quote_key=? AND token=? AND status='running'",
            whereArgs: [c.quoteKey, c.token]);
        final row = await _quote(txn, c.quoteKey);
        if (rows.isEmpty ||
            row == null ||
            knowledgeInputHash(row) != c.inputHash)
          return const AiReservation('stale');
      }
      final id = insightHash([ms, claims.map((c) => c.token).toList()]);
      await txn.insert('qk_ai_requests', {
        'id': id,
        'created_ms': ms,
        'quote_count': claims.length,
        'estimated_tokens': estimate,
        'status': 'reserved'
      });
      await txn.update(
          'qk_ai_budget',
          {
            'used': (b['used'] as int) + 1,
            'estimated_used': (b['estimated_used'] as int) + estimate,
            'token': id,
            'lease_ms': ms + 180000
          },
          where: 'id=1');
      for (final c in claims) {
        await txn.rawUpdate(
            'UPDATE qk_jobs SET request_id=?,ai_attempts=ai_attempts+1 WHERE quote_key=? AND token=?',
            [id, c.quoteKey, c.token]);
      }
      return AiReservation('ready', id);
    });
    if (reservation.state == 'ready' || reservation.state == 'budget')
      QuoteKnowledgeEvents.notify();
    return reservation;
  }

  Future<void> finishRequest(String id, {required bool failed}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
          'qk_ai_requests', {'status': failed ? 'failed' : 'complete'},
          where: 'id=?', whereArgs: [id]);
      await txn.update(
          'qk_ai_budget',
          {
            'token': '',
            'lease_ms': 0,
          },
          where: 'id=1 AND token=?',
          whereArgs: [id]);
    });
    QuoteKnowledgeEvents.notify();
  }

  Future<void> retryFailure(ClassificationClaim c, String message) async {
    final db = await database;
    final rows = await db.query('qk_jobs',
        where: 'quote_key=? AND token=?', whereArgs: [c.quoteKey, c.token]);
    if (rows.isEmpty) return;
    final attempts = rows.single['ai_attempts'] as int;
    final retry = attempts < 1 + ClassificationCostPolicy.maxRetries;
    await db.update(
        'qk_jobs',
        {
          'status': retry ? 'retry' : 'blocked',
          'token': '',
          'lease_ms': 0,
          'next_ms': retry
              ? now().millisecondsSinceEpoch +
                  (15000 * (1 << math.min(3, attempts - 1).clamp(0, 3)))
              : 0,
          'last_error': retry
              ? '$message 已安排重试，最多3次，计入本轮预算。'
              : '$message 已达3次重试上限，请人工调整或手动重试。'
        },
        where: 'quote_key=? AND token=?',
        whereArgs: [c.quoteKey, c.token]);
    QuoteKnowledgeEvents.notify();
  }

  Future<void> hold(ClassificationClaim c,
      {bool budget = false, bool busy = false, String message = ''}) async {
    await (await database).update(
        'qk_jobs',
        {
          'status': busy
              ? 'pending'
              : budget
                  ? 'budget'
                  : 'blocked',
          'token': '',
          'lease_ms': 0,
          'next_ms': busy ? now().millisecondsSinceEpoch + 10000 : 0,
          'last_error': message
        },
        where: 'quote_key=? AND token=?',
        whereArgs: [c.quoteKey, c.token]);
    QuoteKnowledgeEvents.notify();
  }

  Future<bool> localMatch(ClassificationClaim c) async {
    await provisional(c);
    final db = await database;
    final applied = await db.transaction((txn) async {
      final quote = await _quote(txn, c.quoteKey);
      if (quote == null || knowledgeInputHash(quote) != c.inputHash)
        return false;
      final members = await txn.query('qk_memberships',
          columns: ['quote_key'],
          where: 'quote_key=?',
          whereArgs: [c.quoteKey],
          limit: 1);
      if (members.isEmpty) return false;
      return await txn.update(
              'qk_jobs',
              {
                'status': 'done',
                'method': 'local',
                'token': '',
                'lease_ms': 0,
                'last_error': ''
              },
              where: "quote_key=? AND token=? AND status='running'",
              whereArgs: [c.quoteKey, c.token]) >
          0;
    });
    if (applied) QuoteKnowledgeEvents.notify();
    return applied;
  }

  String _cacheKey(ClassificationClaim c) =>
      insightHash(['classification.v2', '${c.quote['content']}'.trim()]);
  Future<String> _dependencies(DatabaseExecutor db, Set<String> ids) async {
    final all = (await db.query('qk_categories'))
            .map(QuoteCategory.fromRow)
            .toList(),
        byId = <String, QuoteCategory>{};
    for (final c in all) {
      byId[c.id] = c;
    }
    final found = <String, Map<String, dynamic>>{}, pending = ids.toList();
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (found.containsKey(id)) continue;
      final c = byId[id];
      if (c == null) return '';
      found[id] = c.toPromptJson();
      if (c.parentId.isNotEmpty) pending.add(c.parentId);
    }
    return insightHash(
        (found.keys.toList()..sort()).map((id) => found[id]).toList());
  }

  Future<void> rememberClassification(
      DatabaseExecutor db,
      ClassificationClaim claim,
      QuoteClassification result,
      Map<String, String> resolved) async {
    final ids = resolved.values.toSet(),
        fingerprint = await _dependencies(db, ids);
    final raw = {
      'categories': [],
      'assignments': [
        for (final a in result.assignments)
          {
            'category_ref': resolved[a.categoryRef],
            'evidence': a.evidence,
            'reason': a.reason
          }
      ],
      'relations': [
        for (final r in result.relations)
          {
            'from_ref': resolved[r.fromRef],
            'to_ref': resolved[r.toRef],
            'kind': r.kind,
            'evidence': r.evidence,
            'reason': r.reason
          }
      ]
    };
    await db.insert(
        'qk_classification_cache',
        {
          'cache_key': _cacheKey(claim),
          'dependencies':
              jsonEncode({'ids': ids.toList(), 'hash': fingerprint}),
          'analysis': jsonEncode(raw)
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<QuoteClassification?> cachedClassification(
      ClassificationClaim c) async {
    final db = await database,
        rows = await db.query('qk_classification_cache',
            where: 'cache_key=?', whereArgs: [_cacheKey(c)]);
    if (rows.isEmpty) return null;
    try {
      final dependency = insightObject(rows.single['dependencies']);
      if (await _dependencies(
              db, (dependency['ids'] as List).cast<String>().toSet()) !=
          dependency['hash']) return null;
      return QuoteClassification.parse(
          rows.single['analysis'], '${c.quote['content']}', await categories());
    } catch (_) {
      return null;
    }
  }
}
