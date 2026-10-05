import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'zhixing_extended_models.dart';
import 'zhixing_knowledge_repository.dart';
import 'zhixing_models.dart';
import 'zhixing_productization.dart';
import 'zhixing_remote_knowledge_models.dart';

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
  static const String _selectedLensesKey = 'zhixing_selected_lenses_v1';
  static const String _personalizationKey = 'zhixing_personalization_v1';
  static const String _actionPreferenceKey = 'zhixing_action_preference_v3';

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
    // AI content is stored in dedicated tables. No AI write path targets
    // zhixing_knowledge_items, which remains the reviewed package index.
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_ai_books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        thinker TEXT NOT NULL,
        title TEXT NOT NULL,
        file_name TEXT NOT NULL,
        local_path TEXT NOT NULL,
        mime_type TEXT NOT NULL DEFAULT '',
        byte_size INTEGER NOT NULL DEFAULT 0,
        sha256 TEXT NOT NULL,
        extracted_characters INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_ai_knowledge_drafts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        origin TEXT NOT NULL DEFAULT 'ai_derived',
        thinker TEXT NOT NULL,
        title TEXT NOT NULL,
        book_ids_json TEXT NOT NULL,
        core_values_json TEXT NOT NULL,
        core_ideas_json TEXT NOT NULL,
        knowledge_view TEXT NOT NULL,
        action_view TEXT NOT NULL,
        transformation_path TEXT NOT NULL,
        decision_cue TEXT NOT NULL,
        yangming_connection TEXT NOT NULL,
        common_ground_json TEXT NOT NULL,
        differences_json TEXT NOT NULL,
        boundaries_json TEXT NOT NULL,
        provider TEXT NOT NULL DEFAULT '',
        model_label TEXT NOT NULL DEFAULT '',
        source_mode TEXT NOT NULL DEFAULT 'local_upload',
        status TEXT NOT NULL DEFAULT 'saved',
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await _addColumnIfMissing(
      database,
      'zhixing_ai_knowledge_drafts',
      'source_mode',
      "TEXT NOT NULL DEFAULT 'local_upload'",
    );
    // Provider-side copies are stored separately from local book files and
    // separately from the reviewed knowledge package.  Only opaque provider
    // resource IDs are persisted here; API credentials remain in settings.
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_remote_knowledge_stores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT NOT NULL,
        thinker TEXT NOT NULL,
        remote_store_id TEXT NOT NULL,
        provider_model TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'ready',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        UNIQUE(provider, thinker)
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_remote_knowledge_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        provider TEXT NOT NULL,
        remote_file_id TEXT NOT NULL DEFAULT '',
        remote_store_id TEXT NOT NULL DEFAULT '',
        remote_document_id TEXT NOT NULL DEFAULT '',
        storage_kind TEXT NOT NULL DEFAULT '',
        retention_label TEXT NOT NULL DEFAULT '',
        provider_model TEXT NOT NULL DEFAULT '',
        expires_at_ms INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'ready',
        last_error TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        UNIQUE(book_id, provider)
      )
    ''');
    await _addColumnIfMissing(
      database,
      'zhixing_remote_knowledge_items',
      'expires_at_ms',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_review_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_uid TEXT NOT NULL,
        origin TEXT NOT NULL,
        knowledge_ref_id INTEGER NOT NULL DEFAULT 0,
        summary TEXT NOT NULL,
        progress_evidence TEXT NOT NULL,
        barrier_finding TEXT NOT NULL,
        recommended_decision TEXT NOT NULL,
        current_system_id TEXT NOT NULL DEFAULT '',
        recommended_system_ids_json TEXT NOT NULL,
        rationale TEXT NOT NULL,
        next_action TEXT NOT NULL,
        provider TEXT NOT NULL DEFAULT '',
        model_label TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_agent_settings (
        singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
        enabled INTEGER NOT NULL DEFAULT 0,
        hour INTEGER NOT NULL DEFAULT 9,
        minute INTEGER NOT NULL DEFAULT 0,
        review_hour INTEGER NOT NULL DEFAULT 20,
        review_minute INTEGER NOT NULL DEFAULT 30,
        days_ahead INTEGER NOT NULL DEFAULT 7,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_agent_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scene TEXT NOT NULL,
        event_type TEXT NOT NULL,
        detail_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL
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
    // `CREATE TABLE IF NOT EXISTS` does not evolve a table that was created by
    // an earlier app build.  In particular, some released builds created
    // zhixing_actions before action_uid was introduced.  Do this before
    // creating indexes so an existing database can be repaired in place rather
    // than failing when the user taps “开始并记录”.
    await _repairLegacyActionTable(database);
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
    await database.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_zhixing_ai_book_sha '
      'ON zhixing_ai_books(sha256)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_ai_draft_created '
      'ON zhixing_ai_knowledge_drafts(created_at_ms DESC)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_remote_books_provider '
      'ON zhixing_remote_knowledge_items(provider, book_id)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_remote_stores_provider '
      'ON zhixing_remote_knowledge_stores(provider, thinker)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_report_action '
      'ON zhixing_review_reports(action_uid, created_at_ms DESC)',
    );
  }

  Future<void> _addColumnIfMissing(
    Database database,
    String table,
    String column,
    String definition,
  ) async {
    final info = await database.rawQuery('PRAGMA table_info($table)');
    final hasColumn = info.any(
      (row) => (row['name'] ?? '').toString() == column,
    );
    if (!hasColumn) {
      await database.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  /// Repairs old on-device action tables without deleting any user data.
  /// Legacy variants contained extra required columns such as diagnosis_id.
  /// AppDatabase rebuilds those tables transactionally into the one canonical
  /// schema before this DAO creates indexes or writes a new action.
  Future<void> _repairLegacyActionTable(Database database) =>
      AppDatabase.ensureZhixingActionSchema(database);

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

  Future<Set<String>> selectedLenses() async {
    final raw = await _kv.getString(_selectedLensesKey);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  Future<void> setSelectedLenses(Set<String> lensIds) =>
      _kv.setString(_selectedLensesKey, jsonEncode(lensIds.toList()..sort()));

  Future<bool> personalizationEnabled() async =>
      (await _kv.getString(_personalizationKey)) != '0';

  Future<void> setPersonalizationEnabled(bool enabled) =>
      _kv.setString(_personalizationKey, enabled ? '1' : '0');

  Future<ZxActionPreference> actionPreference() async {
    final raw = await _kv.getString(_actionPreferenceKey);
    if (raw == null || raw.trim().isEmpty) {
      return const ZxActionPreference();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ZxActionPreference.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}
    return const ZxActionPreference();
  }

  Future<void> saveActionPreference(ZxActionPreference preference) =>
      _kv.setString(
        _actionPreferenceKey,
        jsonEncode(
          preference
              .copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch)
              .toJson(),
        ),
      );

  Future<void> resetPersonalization() async {
    final database = await _db;
    await database.delete('zhixing_lens_feedback');
    await setDisabledLenses(<String>{});
    await _kv.setString(_actionPreferenceKey, '');
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

  Future<int> saveAiBook(ZxAiBook book) async {
    final database = await _db;
    final existing = await database.query(
      'zhixing_ai_books',
      columns: <String>['id'],
      where: 'sha256 = ?',
      whereArgs: <Object?>[book.sha256],
      limit: 1,
    );
    if (existing.isNotEmpty) return _asInt(existing.first['id']);
    return database.insert(
      'zhixing_ai_books',
      <String, Object?>{
        ...book.toMap(),
        'created_at_ms': book.createdAtMs == 0
            ? DateTime.now().millisecondsSinceEpoch
            : book.createdAtMs,
      },
    );
  }

  Future<List<ZxAiBook>> aiBooks() async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_ai_books',
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(ZxAiBook.fromMap).toList(growable: false);
  }

  Future<ZxRemoteKnowledgeStore?> remoteKnowledgeStore({
    required ZxRemoteKnowledgeProvider provider,
    required String thinker,
  }) async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_remote_knowledge_stores',
      where: 'provider = ? AND thinker = ?',
      whereArgs: <Object?>[provider.key, thinker.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : ZxRemoteKnowledgeStore.fromMap(rows.first);
  }

  Future<ZxRemoteKnowledgeStore> saveRemoteKnowledgeStore(
    ZxRemoteKnowledgeStore store,
  ) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await remoteKnowledgeStore(
      provider: store.provider,
      thinker: store.thinker,
    );
    final row = <String, Object?>{
      ...store.toMap(),
      'created_at_ms': existing?.createdAtMs ??
          (store.createdAtMs == 0 ? now : store.createdAtMs),
      'updated_at_ms': now,
    };
    late final int id;
    if (existing == null) {
      id = await database.insert('zhixing_remote_knowledge_stores', row);
    } else {
      await database.update(
        'zhixing_remote_knowledge_stores',
        row,
        where: 'id = ?',
        whereArgs: <Object?>[existing.id],
      );
      id = existing.id;
    }
    final rows = await database.query(
      'zhixing_remote_knowledge_stores',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty
        ? ZxRemoteKnowledgeStore(
            id: id,
            provider: store.provider,
            thinker: store.thinker,
            remoteStoreId: store.remoteStoreId,
            providerModel: store.providerModel,
            status: store.status,
            createdAtMs: _asInt(row['created_at_ms']),
            updatedAtMs: now,
          )
        : ZxRemoteKnowledgeStore.fromMap(rows.first);
  }

  Future<ZxRemoteKnowledgeItem?> remoteKnowledgeItem({
    required int bookId,
    required ZxRemoteKnowledgeProvider provider,
  }) async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_remote_knowledge_items',
      where: 'book_id = ? AND provider = ?',
      whereArgs: <Object?>[bookId, provider.key],
      limit: 1,
    );
    return rows.isEmpty ? null : ZxRemoteKnowledgeItem.fromMap(rows.first);
  }

  Future<List<ZxRemoteKnowledgeItem>> remoteKnowledgeItems({
    ZxRemoteKnowledgeProvider? provider,
    List<int>? bookIds,
    bool includeDeleted = false,
  }) async {
    final database = await _db;
    final clauses = <String>[];
    final args = <Object?>[];
    if (provider != null) {
      clauses.add('provider = ?');
      args.add(provider.key);
    }
    if (bookIds != null && bookIds.isNotEmpty) {
      clauses.add('book_id IN (${List.filled(bookIds.length, '?').join(',')})');
      args.addAll(bookIds);
    }
    if (!includeDeleted) {
      clauses.add("status != 'deleted'");
    }
    final rows = await database.query(
      'zhixing_remote_knowledge_items',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at_ms DESC',
    );
    return rows
        .map(ZxRemoteKnowledgeItem.fromMap)
        .toList(growable: false);
  }

  Future<ZxRemoteKnowledgeItem> saveRemoteKnowledgeItem(
    ZxRemoteKnowledgeItem item,
  ) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await remoteKnowledgeItem(
      bookId: item.bookId,
      provider: item.provider,
    );
    final row = <String, Object?>{
      ...item.toMap(),
      'created_at_ms': existing?.createdAtMs ??
          (item.createdAtMs == 0 ? now : item.createdAtMs),
      'updated_at_ms': now,
    };
    late final int id;
    if (existing == null) {
      id = await database.insert('zhixing_remote_knowledge_items', row);
    } else {
      await database.update(
        'zhixing_remote_knowledge_items',
        row,
        where: 'id = ?',
        whereArgs: <Object?>[existing.id],
      );
      id = existing.id;
    }
    final rows = await database.query(
      'zhixing_remote_knowledge_items',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty
        ? item.copyWith(updatedAtMs: now)
        : ZxRemoteKnowledgeItem.fromMap(rows.first);
  }

  Future<int> saveAiKnowledgeDraft(ZxAiKnowledgeDraft draft) async {
    final database = await _db;
    return database.insert(
      'zhixing_ai_knowledge_drafts',
      <String, Object?>{
        ...draft.toMap(),
        'origin': 'ai_derived',
        'created_at_ms': draft.createdAtMs == 0
            ? DateTime.now().millisecondsSinceEpoch
            : draft.createdAtMs,
      },
    );
  }

  Future<List<ZxAiKnowledgeDraft>> aiKnowledgeDrafts({
    String status = 'saved',
  }) async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_ai_knowledge_drafts',
      where: status.trim().isEmpty ? null : 'status = ?',
      whereArgs:
          status.trim().isEmpty ? null : <Object?>[status.trim()],
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(ZxAiKnowledgeDraft.fromMap).toList(growable: false);
  }

  Future<ZxAiKnowledgeDraft?> aiKnowledgeDraft(int id) async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_ai_knowledge_drafts',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : ZxAiKnowledgeDraft.fromMap(rows.first);
  }

  Future<int> saveReviewReport(ZxReviewReport report) async {
    final database = await _db;
    return database.insert(
      'zhixing_review_reports',
      <String, Object?>{
        ...report.toMap(),
        'created_at_ms': report.createdAtMs == 0
            ? DateTime.now().millisecondsSinceEpoch
            : report.createdAtMs,
      },
    );
  }

  Future<List<ZxReviewReport>> reviewReports({
    String actionUid = '',
    int limit = 50,
  }) async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_review_reports',
      where: actionUid.trim().isEmpty ? null : 'action_uid = ?',
      whereArgs: actionUid.trim().isEmpty
          ? null
          : <Object?>[actionUid.trim()],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(ZxReviewReport.fromMap).toList(growable: false);
  }

  Future<ZxAgentSettings> agentSettings() async {
    final database = await _db;
    final rows = await database.query(
      'zhixing_agent_settings',
      where: 'singleton_id = 1',
      limit: 1,
    );
    return rows.isEmpty
        ? const ZxAgentSettings()
        : ZxAgentSettings.fromMap(rows.first);
  }

  Future<void> saveAgentSettings(ZxAgentSettings settings) async {
    final database = await _db;
    await database.insert(
      'zhixing_agent_settings',
      <String, Object?>{
        ...settings.toMap(),
        'singleton_id': 1,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> recordAgentEvent(
    ZxAgentScene scene,
    String eventType, {
    Map<String, Object?> detail = const <String, Object?>{},
  }) async {
    final database = await _db;
    await database.insert('zhixing_agent_events', <String, Object?>{
      'scene': scene.key,
      'event_type': eventType,
      'detail_json': jsonEncode(detail),
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<Map<String, dynamic>> exportSnapshot() async {
    final database = await _db;
    Future<List<Map<String, Object?>>> table(String name) =>
        database.query(name, orderBy: 'id ASC');
    final treeRows = await database.query('zhixing_tree_state');
    final selectedLensIds = (await selectedLenses()).toList()..sort();
    final preference = await actionPreference();
    return <String, dynamic>{
      'schema': 'zhixing-tree-export-v4',
      'exported_at': DateTime.now().toIso8601String(),
      'goals': await table('zhixing_goals'),
      'sessions': await table('zhixing_sessions'),
      'actions': await table('zhixing_actions'),
      'reviews': await table('zhixing_reviews'),
      'reward_ledger': await table('zhixing_reward_ledger'),
      'xp_ledger': await table('zhixing_xp_ledger'),
      'tree_events': await table('zhixing_tree_events'),
      'lens_feedback': await table('zhixing_lens_feedback'),
      'selected_lenses': selectedLensIds,
      'action_preference': preference.toJson(),
      'candidates': await table('zhixing_candidates'),
      'ai_books': await table('zhixing_ai_books'),
      'ai_knowledge_drafts': await table('zhixing_ai_knowledge_drafts'),
      'remote_knowledge_stores':
          await table('zhixing_remote_knowledge_stores'),
      'remote_knowledge_items':
          await table('zhixing_remote_knowledge_items'),
      'review_reports': await table('zhixing_review_reports'),
      'agent_events': await table('zhixing_agent_events'),
      'agent_settings': await database.query('zhixing_agent_settings'),
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
          'zhixing_review_reports',
          where: 'action_uid = ?',
          whereArgs: <Object?>[id],
        );
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
      'zhixing_review_reports',
      'zhixing_ai_knowledge_drafts',
      'zhixing_remote_knowledge_items',
      'zhixing_remote_knowledge_stores',
      'zhixing_ai_books',
      'zhixing_agent_events',
      'zhixing_agent_settings',
    ];
    await database.transaction((txn) async {
      for (final table in tables) {
        await txn.delete(table);
      }
    });
    await setDisabledLenses(<String>{});
    await setSelectedLenses(<String>{});
    await _kv.setString(_actionPreferenceKey, '');
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
