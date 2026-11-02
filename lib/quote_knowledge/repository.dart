import 'dart:convert';
import 'cost_policy.dart';
import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import '../data/db.dart';
import '../models/quote_insight.dart';
import 'models.dart';
import 'schema.dart';
part 'repository_cost.dart';

class QuoteKnowledgeRepository {
  final Future<Database> Function() _database;
  final DateTime Function() now;
  static final _initialized = Expando<Future<void>>();
  QuoteKnowledgeRepository(
      {Future<Database> Function()? database, DateTime Function()? clock})
      : _database = database ?? AppDatabase.instance,
        now = clock ?? DateTime.now;
  Future<Database> get database async {
    final db = await _database();
    try {
      await (_initialized[db] ??= _initialize(db));
    } catch (_) {
      _initialized[db] = null;
      rethrow;
    }
    return db;
  }

  Future<void> _initialize(Database db) async {
    await QuoteKnowledgeSchema.ensure(db);
    await initializeEconomy(db);
    await db.transaction((txn) async {
      if ((await txn.query('qk_categories', columns: ['id'], limit: 1))
          .isNotEmpty) return;
      for (final entry in const {
        '幸福': '关于幸福、满足与美好生活的名言',
        '痛苦': '关于痛苦、困境及面对苦难的名言',
        '自由': '关于自由、约束与自主选择的名言',
        '意志': '关于意愿、欲求与意志力量的名言',
        '成长': '关于学习、改变、自我发展与成长的名言',
        '责任': '关于责任、承担与回应处境的名言',
        '意义': '关于生命意义、目的与存在问题的名言',
        '价值': '关于价值判断、取舍与值得追求之事的名言',
      }.entries) {
        await _category(txn, entry.key, entry.value, '', 'seed', const []);
      }
    });
  }

  Future<String> _category(DatabaseExecutor db, String name, String definition,
      String parent, String origin, List<String> aliases) async {
    final key = categoryNameKey(name);
    if (key.isEmpty || name.trim().runes.length > 24)
      throw ArgumentError('类别名称请控制在24字以内');
    final alias = await db.query('qk_aliases',
        columns: ['category_id'],
        where: 'parent_id=? AND alias_key=?',
        whereArgs: [parent, key],
        limit: 1);
    if (alias.isNotEmpty) return '${alias.first['category_id']}';
    var id = categoryId(parent, name);
    final occupied = await db.query('qk_categories',
        columns: ['parent_id', 'name_key'], where: 'id=?', whereArgs: [id]);
    if (occupied.isNotEmpty &&
        (occupied.single['parent_id'] != parent ||
            occupied.single['name_key'] != key)) {
      id = 'qkc_${insightHash([
            parent,
            key,
            now().microsecondsSinceEpoch,
            math.Random.secure().nextInt(1 << 30)
          ]).substring(0, 24)}';
    }
    await db.insert(
        'qk_categories',
        {
          'id': id,
          'name': name.trim(),
          'name_key': key,
          'definition': definition.trim(),
          'parent_id': parent,
          'origin': origin,
          'created_ms': now().millisecondsSinceEpoch
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await db.query('qk_categories',
        columns: ['id'],
        where: 'parent_id=? AND name_key=?',
        whereArgs: [parent, key],
        limit: 1);
    final actual = '${rows.single['id']}';
    for (final value in [name, ...aliases]) {
      if (categoryNameKey(value).isEmpty) continue;
      await db.insert(
          'qk_aliases',
          {
            'category_id': actual,
            'parent_id': parent,
            'alias_key': categoryNameKey(value)
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    return actual;
  }

  Future<List<QuoteCategory>> categories() async => (await (await database)
          .query('qk_categories', orderBy: 'created_ms,name'))
      .map(QuoteCategory.fromRow)
      .toList();
  Future<Map<String, dynamic>?> _quote(DatabaseExecutor db, String key) async {
    final rows = await db.query('quotes',
        where: '${QuoteKnowledgeSchema.quoteKey}=?',
        whereArgs: [key],
        limit: 1);
    return rows.firstOrNull;
  }

  Future<List<QuoteCategory>> candidates(Map<String, dynamic> quote,
      {int limit = 120}) async {
    final all = await categories();
    final text =
        '${quote['content'] ?? ''} ${quote['theme'] ?? ''}'.toLowerCase();
    final aliases = await (await database).query('qk_aliases');
    final matched = <String>{
      for (final a in aliases)
        if (text.contains('${a['alias_key']}')) '${a['category_id']}'
    };
    int score(QuoteCategory c) =>
        (matched.contains(c.id) ? 100 : 0) +
        (text.contains(c.name.toLowerCase()) ? 100 : 0) +
        (c.parentId.isEmpty ? 20 : 0) +
        c.definition.runes
            .map(String.fromCharCode)
            .where((s) => s.trim().isNotEmpty && text.contains(s))
            .toSet()
            .length;
    all.sort((a, b) => score(b).compareTo(score(a)));
    final selected = <String, QuoteCategory>{
      for (final c in all.take(limit)) c.id: c
    };
    final byId = {for (final c in all) c.id: c};
    for (final c in selected.values.toList()) {
      var parent = c.parentId;
      final visited = <String>{};
      while (parent.isNotEmpty &&
          visited.add(parent) &&
          byId.containsKey(parent)) {
        selected[parent] = byId[parent]!;
        parent = byId[parent]!.parentId;
      }
    }
    return selected.values.toList();
  }

  /// Index existing labels without sending old records to a model. Such rows
  /// remain explicitly provisional until the user starts a semantic backfill.
  Future<int> bootstrapLegacy({int limit = 200}) async {
    final db = await database;
    final rows = await db.rawQuery('''SELECT q.* FROM quotes q WHERE NOT EXISTS
      (SELECT 1 FROM qk_jobs j WHERE j.quote_key=CASE WHEN trim(COALESCE(q.quote_uid,''))<>'' THEN trim(q.quote_uid) ELSE 'legacy:'||q.id END)
      ORDER BY q.id LIMIT ?''', [limit]);
    await db.transaction((txn) async {
      for (final row in rows) {
        final key = knowledgeQuoteKey(row);
        await txn.insert(
            'qk_jobs',
            {
              'quote_key': key,
              'status': 'legacy',
              'origin': 'legacy',
              'input_hash': knowledgeInputHash(row),
              'method': 'rule'
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
        await _provisional(txn, key, row);
      }
    });
    if (rows.isNotEmpty) QuoteKnowledgeEvents.notify();
    return rows.length;
  }

  Future<void> _provisional(
      DatabaseExecutor db, String key, Map<String, dynamic> row) async {
    final text = '${row['content'] ?? ''}',
        theme = '${row['theme'] ?? ''}'.trim();
    final labels = theme
        .split(RegExp(r'[,，、;；/|]'))
        .map((s) => s.trim())
        .where((s) =>
            s.runes.isNotEmpty &&
            s.runes.length <= 20 &&
            !RegExp(r'[。！？!?\n]').hasMatch(s))
        .take(4)
        .toSet();
    final roots = await db
        .query('qk_categories', where: "parent_id=''", columns: ['id', 'name']);
    final matches = <String, String>{};
    for (final c in roots) {
      final name = '${c['name']}';
      if (labels.any((l) => categoryNameKey(l) == categoryNameKey(name)) ||
          text.contains(name)) matches['${c['id']}'] = name;
    }
    for (final label in labels) {
      final existing = await db.query('qk_aliases',
          columns: ['category_id'],
          where: 'alias_key=?',
          whereArgs: [categoryNameKey(label)]);
      if (existing.length == 1) {
        matches['${existing.single['category_id']}'] = label;
      } else if (existing.isEmpty) {
        final id = await _category(
            db, label, '原记录中以“$label”标注的名言主题。', '', 'label', const []);
        matches[id] = label;
      }
      // Homonyms under different parents need semantic context; do not create
      // a third root or silently pick one of them during local topic indexing.
    }
    for (final entry in matches.entries.take(4)) {
      await db.insert(
          'qk_memberships',
          {
            'quote_key': key,
            'category_id': entry.key,
            'reason': theme.contains(entry.value) ? '按原记录主题初分' : '按原句主题词初分',
            'evidence': text.contains(entry.value) ? entry.value : '',
            'status': 'provisional'
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> provisional(ClassificationClaim claim) async {
    final db = await database;
    await db.transaction((txn) async {
      final current = await _quote(txn, claim.quoteKey);
      final jobs = await txn.query('qk_jobs',
          where: 'quote_key=? AND token=?',
          whereArgs: [claim.quoteKey, claim.token]);
      if (current != null &&
          knowledgeInputHash(current) == claim.inputHash &&
          jobs.isNotEmpty) await _provisional(txn, claim.quoteKey, current);
    });
    QuoteKnowledgeEvents.notify();
  }

  Future<void> enqueueBackfill(
      {bool semantic = false,
      int requestLimit = ClassificationCostPolicy.defaultRequests}) async {
    while (await bootstrapLegacy() == 200) {}
    await beginRound(requestLimit: requestLimit);
    await (await database).rawUpdate(
        "UPDATE qk_jobs SET status='pending',origin='backfill',strategy=?,next_ms=0,last_error='',request_id='',ai_attempts=CASE WHEN status IN ('blocked','waiting_model') THEN 0 ELSE ai_attempts END WHERE status IN ('legacy','paused','budget') OR (origin='backfill' AND status IN ('retry','waiting_model','blocked')) ${semantic ? "OR (status='done' AND method='local')" : ''}",
        [semantic ? 'ai' : 'economy']);
    QuoteKnowledgeEvents.notify();
  }

  Future<void> pauseBackfill() async {
    await (await database).rawUpdate(
        "UPDATE qk_jobs SET status='paused' WHERE origin='backfill' AND status IN ('pending','retry','waiting_model','budget')");
    QuoteKnowledgeEvents.notify();
  }

  Future<void> retryPending() async {
    await beginRound();
    await (await database).rawUpdate(
        "UPDATE qk_jobs SET status='pending',next_ms=0,last_error='',request_id='',ai_attempts=0 WHERE status IN ('retry','waiting_model','blocked','budget')");
    QuoteKnowledgeEvents.notify();
  }

  Future<ClassificationClaim?> claim() async {
    final db = await database, ms = now().millisecondsSinceEpoch;
    return db.transaction((txn) async {
      await txn.rawUpdate(
          "UPDATE qk_jobs SET status='blocked',token='',lease_ms=0,last_error='上次AI请求可能已发出，为避免重复计费已暂停，请手动重试。' WHERE status='running' AND lease_ms<=? AND request_id<>''",
          [ms]);
      final jobs = await txn.query('qk_jobs',
          where:
              "((status IN ('pending','retry') AND next_ms<=?) OR (status='running' AND lease_ms<=? AND request_id=''))",
          whereArgs: [ms, ms],
          orderBy: "CASE origin WHEN 'new' THEN 0 ELSE 1 END,next_ms,quote_key",
          limit: 1);
      if (jobs.isEmpty) return null;
      final key = '${jobs.first['quote_key']}', row = await _quote(txn, key);
      if (row == null) {
        await txn.delete('qk_jobs', where: 'quote_key=?', whereArgs: [key]);
        return null;
      }
      if ('${row['content'] ?? ''}'.trim().isEmpty) {
        await txn.update('qk_jobs', {'status': 'ignored'},
            where: 'quote_key=?', whereArgs: [key]);
        return null;
      }
      final token =
              insightHash([key, ms, math.Random.secure().nextInt(1 << 30)]),
          hash = knowledgeInputHash(row);
      await txn.update(
          'qk_jobs',
          {
            'status': 'running',
            'request_id': '',
            'token': token,
            'input_hash': hash,
            'lease_ms': ms + 180000,
            'attempts': (jobs.first['attempts'] as num).toInt() + 1
          },
          where: 'quote_key=?',
          whereArgs: [key]);
      return ClassificationClaim(key, token, hash, row,
          strategy: '${jobs.first['strategy']}');
    });
  }

  Future<void> defer(ClassificationClaim claim,
      {bool unavailable = false, String message = '自动归类暂未完成，可稍后重试。'}) async {
    final db = await database;
    final jobs = await db.query('qk_jobs',
        where: 'quote_key=? AND token=?',
        whereArgs: [claim.quoteKey, claim.token]);
    if (jobs.isEmpty) return;
    await db.update(
        'qk_jobs',
        {
          'status': 'blocked',
          'last_error': message,
          'lease_ms': 0,
          'token': ''
        },
        where: 'quote_key=? AND token=?',
        whereArgs: [claim.quoteKey, claim.token]);
    QuoteKnowledgeEvents.notify();
  }

  Future<bool> apply(ClassificationClaim claim, QuoteClassification result,
      {String method = 'ai'}) async {
    final db = await database;
    final applied = await db.transaction((txn) async {
      final row = await _quote(txn, claim.quoteKey);
      final job = await txn.query('qk_jobs',
          where: "quote_key=? AND token=? AND status='running'",
          whereArgs: [claim.quoteKey, claim.token]);
      if (row == null ||
          knowledgeInputHash(row) != claim.inputHash ||
          job.isEmpty) return false;
      if (result.assignments.isEmpty ||
          result.assignments.length > 4 ||
          result.assignments.any((a) =>
              a.evidence.isEmpty ||
              !'${row['content']}'.contains(a.evidence) ||
              a.reason.isEmpty) ||
          result.relations.any((r) =>
              r.evidence.isEmpty ||
              !'${row['content']}'.contains(r.evidence) ||
              r.reason.isEmpty ||
              !['related', 'contrast', 'condition', 'cause_claim']
                  .contains(r.kind))) {
        throw const FormatException('归类与关系必须保留逐字原文依据');
      }
      final proposals = {for (final c in result.categories) c.ref: c},
          resolved = <String, String>{};
      Future<String> resolve(String ref, Set<String> visited) async {
        if (resolved[ref] case final id?) return id;
        if (!visited.add(ref)) throw const FormatException('分类层级不能形成循环');
        final proposal = proposals[ref];
        if (proposal == null || proposal.existingId.isNotEmpty) {
          final id = proposal?.existingId ?? ref;
          if ((await txn.query('qk_categories',
                  columns: ['id'], where: 'id=?', whereArgs: [id], limit: 1))
              .isEmpty) throw const FormatException('类别已变化，请重新归类');
          resolved[ref] = id;
          return id;
        }
        final parent = proposal.parentRef.isEmpty
            ? ''
            : await resolve(proposal.parentRef, visited);
        final id = await _category(txn, proposal.name, proposal.definition,
            parent, 'ai', proposal.aliases);
        resolved[ref] = id;
        return id;
      }

      for (final a in result.assignments) {
        await resolve(a.categoryRef, {});
      }
      for (final r in result.relations) {
        await resolve(r.fromRef, {});
        await resolve(r.toRef, {});
      }
      await txn.delete('qk_memberships',
          where: 'quote_key=?', whereArgs: [claim.quoteKey]);
      await txn.delete('qk_relation_evidence',
          where: 'quote_key=?', whereArgs: [claim.quoteKey]);
      for (final a in result.assignments) {
        await txn.insert(
            'qk_memberships',
            {
              'quote_key': claim.quoteKey,
              'category_id': resolved[a.categoryRef],
              'reason': a.reason,
              'evidence': a.evidence,
              'status': result.needsReview ? 'review' : 'proposed'
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final r in result.relations) {
        var from = resolved[r.fromRef]!, to = resolved[r.toRef]!;
        if (from == to) continue;
        if (['related', 'contrast'].contains(r.kind) &&
            from.compareTo(to) > 0) {
          final old = from;
          from = to;
          to = old;
        }
        final id = 'qkr_${insightHash([from, to, r.kind]).substring(0, 24)}';
        await txn.insert('qk_relations',
            {'id': id, 'from_id': from, 'to_id': to, 'kind': r.kind},
            conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.insert(
            'qk_relation_evidence',
            {
              'relation_id': id,
              'quote_key': claim.quoteKey,
              'excerpt': r.evidence,
              'reason': r.reason
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.update(
          'qk_jobs',
          {
            'status': result.needsReview ? 'review' : 'done',
            'method': method,
            'review_reason': result.reviewReason,
            'token': '',
            'lease_ms': 0,
            'last_error': ''
          },
          where: 'quote_key=? AND token=?',
          whereArgs: [claim.quoteKey, claim.token]);
      if ((method == 'ai' || method == 'batch') && !result.needsReview)
        await rememberClassification(txn, claim, result, resolved);
      return true;
    });
    if (applied) QuoteKnowledgeEvents.notify();
    return applied;
  }

  static const _joinedKey =
      "CASE WHEN trim(COALESCE(q.quote_uid,''))<>'' THEN trim(q.quote_uid) ELSE 'legacy:'||q.id END";
  String _membershipCte(String query) =>
      '''WITH RECURSIVE members(quote_key,category_id) AS (
    SELECT m.quote_key,m.category_id FROM qk_memberships m JOIN quotes q ON $_joinedKey=m.quote_key
    ${query.isEmpty ? '' : "WHERE COALESCE(q.content,'') LIKE ?"}
    UNION SELECT m.quote_key,c.parent_id FROM members m JOIN qk_categories c ON c.id=m.category_id WHERE c.parent_id<>'')''';
  Future<QuoteKnowledgeGraph> snapshot({String query = ''}) async {
    final db = await database,
        args = query.isEmpty ? <Object?>[] : <Object?>['%$query%'];
    final cats = await db.rawQuery(
        '${_membershipCte(query)} SELECT c.*,COUNT(DISTINCT m.quote_key) AS quote_count FROM qk_categories c LEFT JOIN members m ON m.category_id=c.id GROUP BY c.id ORDER BY quote_count DESC,c.name',
        args);
    final categories = cats.map(QuoteCategory.fromRow).toList(),
        edges = <QuoteKnowledgeEdge>[];
    for (final c
        in categories.where((c) => c.parentId.isNotEmpty && c.quoteCount > 0)) {
      edges.add(QuoteKnowledgeEdge(c.parentId, c.id, 'subtopic'));
    }
    final relations = await db.rawQuery(
        '''SELECT r.*,COUNT(DISTINCT e.quote_key) AS weight,MIN(e.reason) AS explanation
      FROM qk_relations r JOIN qk_relation_evidence e ON e.relation_id=r.id JOIN quotes q ON $_joinedKey=e.quote_key
      ${query.isEmpty ? '' : "WHERE COALESCE(q.content,'') LIKE ?"} GROUP BY r.id''',
        args);
    for (final r in relations) {
      edges.add(QuoteKnowledgeEdge(
          '${r['from_id']}', '${r['to_id']}', '${r['kind']}',
          weight: (r['weight'] as num).toInt(),
          explanation: '${r['explanation']}'));
    }
    final shared = await db.rawQuery(
        '''SELECT a.category_id AS a,b.category_id AS b,COUNT(DISTINCT a.quote_key) AS n
      FROM qk_memberships a JOIN qk_memberships b ON a.quote_key=b.quote_key AND a.category_id<b.category_id
      JOIN quotes q ON $_joinedKey=a.quote_key ${query.isEmpty ? '' : "WHERE COALESCE(q.content,'') LIKE ?"}
      GROUP BY a.category_id,b.category_id ORDER BY n DESC LIMIT 300''', args);
    for (final r in shared) {
      if (!edges.any((e) =>
          (e.from == r['a'] && e.to == r['b']) ||
          (e.to == r['a'] && e.from == r['b']))) {
        edges.add(QuoteKnowledgeEdge('${r['a']}', '${r['b']}', 'cooccurrence',
            weight: (r['n'] as num).toInt(),
            explanation: '共同收录 ${r['n']} 条名言。'));
      }
    }
    final totals = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM quotes ${query.isEmpty ? '' : "WHERE COALESCE(content,'') LIKE ?"}',
        args);
    final jobs = await db
        .rawQuery('SELECT status,COUNT(*) AS n FROM qk_jobs GROUP BY status');
    int count(List<String> states) => jobs
        .where((r) => states.contains(r['status']))
        .fold(0, (n, r) => n + (r['n'] as num).toInt());
    return QuoteKnowledgeGraph(
        categories: categories,
        edges: edges,
        quoteCount: (totals.single['n'] as num).toInt(),
        pending: count(['pending', 'running', 'budget', 'retry']),
        needsReview: count(['review', 'blocked']),
        legacyRemaining: count(['legacy', 'paused']));
  }

  Future<List<Map<String, dynamic>>> quotesForCategory(String? id,
      {int offset = 0, int limit = 30, String query = ''}) async {
    final db = await database;
    if (id == null)
      return db.query('quotes',
          where: query.isEmpty ? null : 'content LIKE ?',
          whereArgs: query.isEmpty ? null : ['%$query%'],
          orderBy: 'id DESC',
          limit: limit,
          offset: offset);
    return db.rawQuery(
        '''WITH RECURSIVE subtree(id) AS (SELECT id FROM qk_categories WHERE id=?
      UNION SELECT c.id FROM qk_categories c JOIN subtree s ON c.parent_id=s.id)
      SELECT DISTINCT q.* FROM quotes q JOIN qk_memberships m ON m.quote_key=$_joinedKey
      JOIN subtree s ON s.id=m.category_id ${query.isEmpty ? '' : "WHERE COALESCE(q.content,'') LIKE ?"}
      ORDER BY q.id DESC LIMIT ? OFFSET ?''',
        [id, if (query.isNotEmpty) '%$query%', limit, offset]);
  }

  Future<List<Map<String, dynamic>>> assignments(String quoteKey) async =>
      (await database).rawQuery('''
    SELECT c.*,m.reason,m.evidence,m.status FROM qk_memberships m JOIN qk_categories c ON c.id=m.category_id WHERE m.quote_key=?''',
          [quoteKey]);
  Future<void> assignManually(String quoteKey, List<String> ids) async {
    final db = await database;
    await db.transaction((txn) async {
      final quote = await _quote(txn, quoteKey);
      if (quote == null || ids.isEmpty) throw ArgumentError('请选择名言与类别');
      for (final id in ids.toSet()) {
        if ((await txn.query('qk_categories',
                columns: ['id'], where: 'id=?', whereArgs: [id]))
            .isEmpty) throw ArgumentError('类别已不存在');
      }
      await txn.delete('qk_memberships',
          where: 'quote_key=?', whereArgs: [quoteKey]);
      await txn.delete('qk_relation_evidence',
          where: 'quote_key=?', whereArgs: [quoteKey]);
      for (final id in ids.toSet()) {
        await txn.insert('qk_memberships', {
          'quote_key': quoteKey,
          'category_id': id,
          'reason': '用户调整分类',
          'evidence': '',
          'status': 'manual'
        });
      }
      await txn.insert(
          'qk_jobs',
          {
            'quote_key': quoteKey,
            'status': 'done',
            'origin': 'manual',
            'input_hash': knowledgeInputHash(quote),
            'method': 'user'
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    QuoteKnowledgeEvents.notify();
  }

  Future<String> createCategory(String name, String definition,
      {String parentId = ''}) async {
    final db = await database;
    if (definition.trim().isEmpty) throw ArgumentError('请填写类别含义');
    if (parentId.isNotEmpty &&
        (await db.query('qk_categories', where: 'id=?', whereArgs: [parentId]))
            .isEmpty) throw ArgumentError('上位类别不存在');
    final id = await db.transaction(
        (txn) => _category(txn, name, definition, parentId, 'user', const []));
    QuoteKnowledgeEvents.notify();
    return id;
  }

  Future<void> moveCategory(String id, String parentId) async {
    final db = await database;
    await db.transaction((txn) async {
      var at = parentId;
      final visited = <String>{id};
      while (at.isNotEmpty) {
        if (!visited.add(at)) throw ArgumentError('不能把类别移动到它的下位类别');
        final rows =
            await txn.query('qk_categories', where: 'id=?', whereArgs: [at]);
        if (rows.isEmpty) throw ArgumentError('类别不存在');
        at = '${rows.single['parent_id']}';
      }
      await txn.update('qk_categories', {'parent_id': parentId},
          where: 'id=?', whereArgs: [id]);
      await txn.update('qk_aliases', {'parent_id': parentId},
          where: 'category_id=?', whereArgs: [id]);
    });
    QuoteKnowledgeEvents.notify();
  }

  Future<List<Map<String, dynamic>>> reviewQueue(
          {int offset = 0, int limit = 20}) async =>
      (await database).rawQuery(
          '''SELECT q.*,j.status AS classification_status,j.review_reason,j.last_error
      FROM quotes q JOIN qk_jobs j ON j.quote_key=$_joinedKey
      WHERE j.status IN ('review','retry','waiting_model','blocked','budget') ORDER BY q.id DESC LIMIT ? OFFSET ?''',
          [limit, offset]);

  Future<Map<String, String>> indexedMatches(
      List<String> keys, String concept) async {
    if (keys.isEmpty) return {};
    final rows = await (await database).rawQuery(
        '''WITH RECURSIVE target(id) AS (
      SELECT id FROM qk_categories WHERE name_key=?
      UNION SELECT category_id FROM qk_aliases WHERE alias_key=?
      UNION SELECT c.id FROM qk_categories c JOIN target t ON c.parent_id=t.id)
      SELECT m.quote_key,m.status FROM qk_memberships m JOIN target t ON t.id=m.category_id
      WHERE m.quote_key IN (${List.filled(keys.length, '?').join(',')})
      ORDER BY CASE m.status WHEN 'manual' THEN 0 WHEN 'provisional' THEN 2 ELSE 1 END''',
        [categoryNameKey(concept), categoryNameKey(concept), ...keys]);
    final matches = <String, String>{};
    for (final row in rows) {
      matches.putIfAbsent('${row['quote_key']}', () => '${row['status']}');
    }
    return matches;
  }

  Future<List<Map<String, dynamic>>> relationEvidence(
          String from, String to) async =>
      (await database).rawQuery('''
    SELECT e.quote_key,e.excerpt,e.reason,r.kind FROM qk_relations r JOIN qk_relation_evidence e ON e.relation_id=r.id
    WHERE (r.from_id=? AND r.to_id=?) OR (r.from_id=? AND r.to_id=?)''',
          [from, to, to, from]);
}
