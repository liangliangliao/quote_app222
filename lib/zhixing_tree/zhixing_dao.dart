import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'zhixing_knowledge_repository.dart';
import 'zhixing_models.dart';

class ZxRewardContext {
  final int sameActionRewardedCount;
  final int sameDifficultyCountToday;
  final int coinsEarnedToday;

  const ZxRewardContext({
    required this.sameActionRewardedCount,
    required this.sameDifficultyCountToday,
    required this.coinsEarnedToday,
  });
}

/// Local-first persistence for the complete 知行树 loop.
///
/// The reward and XP ledgers are append-only. Tree snapshots are convenient
/// projections; balances can always be audited against the ledgers.
class ZxDao {
  static const String _knowledgeVersionKey = 'zhixing_knowledge_version_v1';
  static const String _disabledLensesKey = 'zhixing_disabled_lenses_v1';
  static const String _personalizationKey = 'zhixing_personalization_v1';

  final KeyValueDao _kv = KeyValueDao();

  Future<Database> get _db async {
    final database = await AppDatabase.instance();
    await ensureTables(db: database);
    return database;
  }

  Future<void> ensureTables({Database? db}) async {
    final database = db ?? await AppDatabase.instance();
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        domain TEXT NOT NULL DEFAULT 'general',
        value_direction TEXT NOT NULL DEFAULT '',
        autonomy REAL NOT NULL DEFAULT 0.5,
        stage TEXT NOT NULL DEFAULT 's1',
        status TEXT NOT NULL DEFAULT 'active',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER,
        input_json TEXT NOT NULL,
        diagnosis_json TEXT NOT NULL,
        match_json TEXT NOT NULL,
        risk_level TEXT NOT NULL,
        primary_barrier TEXT NOT NULL,
        primary_lens_id TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_uid TEXT NOT NULL UNIQUE,
        goal_id INTEGER,
        session_id INTEGER,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        barrier TEXT NOT NULL,
        risk_level TEXT NOT NULL,
        prescription_json TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_uid TEXT NOT NULL,
        review_json TEXT NOT NULL,
        completion_status TEXT NOT NULL,
        learning_status TEXT NOT NULL,
        proof_type TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_reward_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_uid TEXT NOT NULL,
        review_id INTEGER NOT NULL,
        completion_coins INTEGER NOT NULL DEFAULT 0,
        learning_coins INTEGER NOT NULL DEFAULT 0,
        total_coins INTEGER NOT NULL DEFAULT 0,
        formula_json TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_xp_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_uid TEXT NOT NULL,
        review_id INTEGER NOT NULL,
        ability_dimension TEXT NOT NULL,
        xp REAL NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_tree_state (
        singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
        state_json TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_tree_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        resource TEXT NOT NULL DEFAULT '',
        coin_delta INTEGER NOT NULL DEFAULT 0,
        resource_delta REAL NOT NULL DEFAULT 0,
        detail_json TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_lens_feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lens_id TEXT NOT NULL,
        helpfulness REAL NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_candidates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gap TEXT NOT NULL,
        concept TEXT NOT NULL,
        thinker TEXT NOT NULL,
        work TEXT NOT NULL,
        source_uri TEXT NOT NULL,
        added_value TEXT NOT NULL,
        risks TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'candidate',
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_knowledge_items (
        id TEXT PRIMARY KEY,
        item_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        locator TEXT NOT NULL,
        package_version TEXT NOT NULL,
        review_status TEXT NOT NULL
      )
    ''');
    try {
      await database.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS zhixing_knowledge_fts
        USING fts5(id UNINDEXED, title, body, locator, tokenize='unicode61')
      ''');
    } catch (_) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS zhixing_knowledge_fts (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          locator TEXT NOT NULL
        )
      ''');
    }
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_goals_status '
      'ON zhixing_goals(status, updated_at_ms DESC)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_actions_status '
      'ON zhixing_actions(status, updated_at_ms DESC)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_reviews_action '
      'ON zhixing_reviews(action_uid, created_at_ms DESC)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_rewards_day '
      'ON zhixing_reward_ledger(created_at_ms DESC)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_feedback_lens '
      'ON zhixing_lens_feedback(lens_id, created_at_ms DESC)',
    );
  }

  Future<void> seedKnowledge(ZxKnowledgeRepository repository) async {
    final version = repository.packageInfo.version;
    if (await _kv.getString(_knowledgeVersionKey) == version) return;
    final database = await _db;
    final rows = repository.indexRows();
    await database.transaction((txn) async {
      await txn.delete('zhixing_knowledge_items');
      await txn.delete('zhixing_knowledge_fts');
      for (final row in rows) {
        final id = (row['item_id'] ?? '').toString();
        final title = (row['title'] ?? '').toString();
        final body = (row['content'] ?? '').toString();
        final locator = (row['locator'] ?? '').toString();
        await txn.insert(
          'zhixing_knowledge_items',
          <String, Object?>{
            'id': id,
            'item_type': row['item_type'],
            'source_id': row['source_id'],
            'title': title,
            'body': body,
            'locator': locator,
            'package_version': version,
            'review_status': repository.packageInfo.reviewStatus,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'zhixing_knowledge_fts',
          <String, Object?>{
            'id': id,
            'title': title,
            'body': body,
            'locator': locator,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _kv.setString(_knowledgeVersionKey, version);
  }

  Future<int> saveGoal(ZxGoal goal) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = <String, Object?>{
      ...goal.toMap(),
      'created_at_ms': goal.createdAtMs == 0 ? now : goal.createdAtMs,
      'updated_at_ms': now,
    };
    if (goal.id > 0) {
      await database.update(
        'zhixing_goals',
        row,
        where: 'id = ?',
        whereArgs: <Object?>[goal.id],
      );
      return goal.id;
    }
    return database.insert('zhixing_goals', row);
  }

  Future<List<ZxGoal>> goals() async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_goals',
      orderBy: 'updated_at_ms DESC',
    );
    return rows.map(ZxGoal.fromMap).toList(growable: false);
  }

  Future<int> saveSession({
    required int goalId,
    required ZxSituationInput input,
    required ZxDiagnosisResult diagnosis,
    required ZxMatchResult match,
  }) async {
    final database = await _db;
    return database.insert('zhixing_sessions', <String, Object?>{
      'goal_id': goalId,
      'input_json': jsonEncode(input.toJson()),
      'diagnosis_json': jsonEncode(diagnosis.toJson()),
      'match_json': jsonEncode(match.toJson()),
      'risk_level': diagnosis.safety.risk.name,
      'primary_barrier': diagnosis.primary.barrier.key,
      'primary_lens_id': match.primary.id,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> saveAction(
    ZxActionPrescription action, {
    int sessionId = 0,
  }) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final stored = action.copyWith(
      updatedAtMs: now,
      status: action.status == ZxActionStatus.proposed
          ? ZxActionStatus.active
          : action.status,
    );
    await database.insert(
      'zhixing_actions',
      <String, Object?>{
        'action_uid': stored.id,
        'goal_id': stored.goalId,
        'session_id': sessionId == 0 ? null : sessionId,
        'title': stored.mainAction,
        'status': stored.status.name,
        'difficulty': stored.difficulty.name,
        'barrier': stored.primaryBarrier.key,
        'risk_level': stored.risk.name,
        'prescription_json': stored.encode(),
        'created_at_ms': stored.createdAtMs == 0 ? now : stored.createdAtMs,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateActionStatus(
    String actionUid,
    ZxActionStatus status,
  ) async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_actions',
      where: 'action_uid = ?',
      whereArgs: <Object?>[actionUid],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final action = ZxActionPrescription.fromMap(rows.first).copyWith(
      status: status,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await database.update(
      'zhixing_actions',
      <String, Object?>{
        'status': status.name,
        'prescription_json': action.encode(),
        'updated_at_ms': action.updatedAtMs,
      },
      where: 'action_uid = ?',
      whereArgs: <Object?>[actionUid],
    );
  }

  Future<List<ZxActionPrescription>> actions({
    Set<ZxActionStatus>? statuses,
    int limit = 50,
  }) async {
    final database = await _db;
    String? where;
    List<Object?>? args;
    if (statuses != null && statuses.isNotEmpty) {
      where = 'status IN (${List.filled(statuses.length, '?').join(',')})';
      args = statuses.map((item) => item.name).toList(growable: false);
    }
    final rows = await database.query(
      'zhixing_actions',
      where: where,
      whereArgs: args,
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(ZxActionPrescription.fromMap).toList(growable: false);
  }

  Future<ZxRewardContext> rewardContext(
    ZxActionPrescription action, {
    int? nowMs,
  }) async {
    final database = await _db;
    final now = DateTime.fromMillisecondsSinceEpoch(
      nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds;
    final sameAction = Sqflite.firstIntValue(await database.rawQuery(
          'SELECT COUNT(*) FROM zhixing_reward_ledger '
          'WHERE action_uid = ? AND total_coins > 0',
          <Object?>[action.id],
        )) ??
        0;
    final sameDifficulty = Sqflite.firstIntValue(await database.rawQuery(
          'SELECT COUNT(*) FROM zhixing_reward_ledger r '
          'JOIN zhixing_actions a ON a.action_uid = r.action_uid '
          'WHERE a.difficulty = ? AND r.total_coins > 0 '
          'AND r.created_at_ms >= ? AND r.created_at_ms < ?',
          <Object?>[action.difficulty.name, start, end],
        )) ??
        0;
    final dailyRows = await database.rawQuery(
      'SELECT COALESCE(SUM(total_coins), 0) AS total '
      'FROM zhixing_reward_ledger '
      'WHERE created_at_ms >= ? AND created_at_ms < ?',
      <Object?>[start, end],
    );
    final coins = _asInt(dailyRows.first['total']);
    return ZxRewardContext(
      sameActionRewardedCount: sameAction,
      sameDifficultyCountToday: sameDifficulty,
      coinsEarnedToday: coins,
    );
  }

  Future<ZxTreeState> loadTree() async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_tree_state',
      where: 'singleton_id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return const ZxTreeState();
    try {
      final decoded = jsonDecode((rows.first['state_json'] ?? '{}').toString());
      if (decoded is Map) {
        return ZxTreeState.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return const ZxTreeState();
  }

  Future<void> saveTree(
    ZxTreeState state, {
    String eventType = 'snapshot',
    String resource = '',
    int coinDelta = 0,
    double resourceDelta = 0,
  }) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction((txn) async {
      await txn.insert(
        'zhixing_tree_state',
        <String, Object?>{
          'singleton_id': 1,
          'state_json': jsonEncode(state.toJson()),
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('zhixing_tree_events', <String, Object?>{
        'event_type': eventType,
        'resource': resource,
        'coin_delta': coinDelta,
        'resource_delta': resourceDelta,
        'detail_json': jsonEncode(state.toJson()),
        'created_at_ms': now,
      });
    });
  }

  Future<void> recordReviewAndReward({
    required ZxActionPrescription action,
    required ZxReviewInput review,
    required ZxRewardOutcome reward,
    required ZxTreeState tree,
  }) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction((txn) async {
      final reviewId = await txn.insert(
        'zhixing_reviews',
        <String, Object?>{
          'action_uid': action.id,
          'review_json': jsonEncode(review.toJson()),
          'completion_status': review.completion.name,
          'learning_status': review.learning.name,
          'proof_type': review.proofType.name,
          'created_at_ms': now,
        },
      );
      await txn.insert('zhixing_reward_ledger', <String, Object?>{
        'action_uid': action.id,
        'review_id': reviewId,
        'completion_coins': reward.completionCoins,
        'learning_coins': reward.learningCoins,
        'total_coins': reward.totalCoins,
        'formula_json': jsonEncode(<String, Object?>{
          'proof_factor': reward.proofFactor,
          'reflection_factor': reward.reflectionFactor,
          'calibration_factor': reward.calibrationFactor,
          'novelty_factor': reward.noveltyFactor,
          'daily_cap_applied': reward.dailyCapApplied,
          'explanations': reward.explanations,
        }),
        'created_at_ms': now,
      });
      await txn.insert('zhixing_xp_ledger', <String, Object?>{
        'action_uid': action.id,
        'review_id': reviewId,
        'ability_dimension': reward.abilityDimension,
        'xp': reward.xp,
        'created_at_ms': now,
      });
      final finalStatus =
          review.completion == ZxCompletionStatus.notCompleted
              ? ZxActionStatus.learned
              : ZxActionStatus.completed;
      final updated = action.copyWith(
        status: finalStatus,
        updatedAtMs: now,
      );
      await txn.update(
        'zhixing_actions',
        <String, Object?>{
          'status': finalStatus.name,
          'prescription_json': updated.encode(),
          'updated_at_ms': now,
        },
        where: 'action_uid = ?',
        whereArgs: <Object?>[action.id],
      );
      await txn.insert(
        'zhixing_tree_state',
        <String, Object?>{
          'singleton_id': 1,
          'state_json': jsonEncode(tree.toJson()),
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('zhixing_tree_events', <String, Object?>{
        'event_type': 'reward',
        'resource': '',
        'coin_delta': reward.totalCoins,
        'resource_delta': 0,
        'detail_json': jsonEncode(<String, Object?>{
          'action_uid': action.id,
          'ability_dimension': reward.abilityDimension,
          'xp': reward.xp,
          'tree': tree.toJson(),
        }),
        'created_at_ms': now,
      });
    });
  }

  Future<List<Map<String, Object?>>> rewardLedger({int limit = 50}) async {
    final database = await _db;
    return database.query(
      'zhixing_reward_ledger',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> recordLensFeedback(
    String lensId,
    double helpfulness, {
    String reason = '',
  }) async {
    final database = await _db;
    await database.insert('zhixing_lens_feedback', <String, Object?>{
      'lens_id': lensId,
      'helpfulness': helpfulness.clamp(0.0, 1.0).toDouble(),
      'reason': reason,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<Map<String, double>> historicalLensResponse() async {
    final database = await _db;
    final rows = await database.rawQuery(
      'SELECT lens_id, AVG(helpfulness) AS average '
      'FROM zhixing_lens_feedback GROUP BY lens_id',
    );
    return <String, double>{
      for (final row in rows)
        (row['lens_id'] ?? '').toString(): _asDouble(row['average'], 0.5),
    };
  }

  Future<Set<String>> disabledLenses() async {
    final raw = await _kv.getString(_disabledLensesKey);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  Future<void> setDisabledLenses(Set<String> lensIds) =>
      _kv.setString(_disabledLensesKey, jsonEncode(lensIds.toList()..sort()));

  Future<bool> personalizationEnabled() async =>
      (await _kv.getString(_personalizationKey)) != '0';

  Future<void> setPersonalizationEnabled(bool enabled) =>
      _kv.setString(_personalizationKey, enabled ? '1' : '0');

  Future<void> resetPersonalization() async {
    final database = await _db;
    await database.delete('zhixing_lens_feedback');
    await setDisabledLenses(<String>{});
  }

  Future<int> addCandidate(ZxCandidateLens candidate) async {
    final database = await _db;
    return database.insert(
      'zhixing_candidates',
      <String, Object?>{
        ...candidate.toMap(),
        'created_at_ms': candidate.createdAtMs == 0
            ? DateTime.now().millisecondsSinceEpoch
            : candidate.createdAtMs,
      },
    );
  }

  Future<List<ZxCandidateLens>> candidates() async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_candidates',
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(ZxCandidateLens.fromMap).toList(growable: false);
  }

  Future<void> updateCandidateStatus(int id, String status) async {
    final database = await _db;
    await database.update(
      'zhixing_candidates',
      <String, Object?>{'status': status},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<Map<String, dynamic>> exportSnapshot() async {
    final database = await _db;
    Future<List<Map<String, Object?>>> table(String name) =>
        database.query(name, orderBy: 'id ASC');
    final treeRows = await database.query('zhixing_tree_state');
    return <String, dynamic>{
      'schema': 'zhixing-tree-export-v1',
      'exported_at': DateTime.now().toIso8601String(),
      'goals': await table('zhixing_goals'),
      'sessions': await table('zhixing_sessions'),
      'actions': await table('zhixing_actions'),
      'reviews': await table('zhixing_reviews'),
      'reward_ledger': await table('zhixing_reward_ledger'),
      'xp_ledger': await table('zhixing_xp_ledger'),
      'tree_events': await table('zhixing_tree_events'),
      'lens_feedback': await table('zhixing_lens_feedback'),
      'candidates': await table('zhixing_candidates'),
      'tree_state': treeRows,
    };
  }

  Future<void> deleteGoal(int goalId) async {
    final database = await _db;
    final actions = await database.query(
      'zhixing_actions',
      columns: <String>['action_uid'],
      where: 'goal_id = ?',
      whereArgs: <Object?>[goalId],
    );
    final ids = actions.map((row) => row['action_uid'].toString()).toList();
    await database.transaction((txn) async {
      for (final id in ids) {
        await txn.delete(
          'zhixing_reviews',
          where: 'action_uid = ?',
          whereArgs: <Object?>[id],
        );
        await txn.delete(
          'zhixing_reward_ledger',
          where: 'action_uid = ?',
          whereArgs: <Object?>[id],
        );
        await txn.delete(
          'zhixing_xp_ledger',
          where: 'action_uid = ?',
          whereArgs: <Object?>[id],
        );
      }
      await txn.delete(
        'zhixing_actions',
        where: 'goal_id = ?',
        whereArgs: <Object?>[goalId],
      );
      await txn.delete(
        'zhixing_sessions',
        where: 'goal_id = ?',
        whereArgs: <Object?>[goalId],
      );
      await txn.delete(
        'zhixing_goals',
        where: 'id = ?',
        whereArgs: <Object?>[goalId],
      );
    });
  }

  /// Deletes user-created data but keeps the reviewed knowledge package/index.
  Future<void> deleteAllUserData() async {
    final database = await _db;
    const tables = <String>[
      'zhixing_reviews',
      'zhixing_reward_ledger',
      'zhixing_xp_ledger',
      'zhixing_actions',
      'zhixing_sessions',
      'zhixing_goals',
      'zhixing_tree_events',
      'zhixing_tree_state',
      'zhixing_lens_feedback',
      'zhixing_candidates',
    ];
    await database.transaction((txn) async {
      for (final table in tables) {
        await txn.delete(table);
      }
    });
    await setDisabledLenses(<String>{});
  }
}

int _asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
