import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'will_mirror_models.dart';
import 'will_mirror_practice_models.dart';
import 'will_mirror_vault_cipher.dart';

class WillMirrorIds {
  static final Random _random = Random.secure();

  static String next(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix = _random.nextInt(1 << 32).toRadixString(36);
    return '${prefix}_$now$suffix';
  }
}

class WillMirrorVaultStatus {
  const WillMirrorVaultStatus({
    required this.keystoreAvailable,
    required this.localOnly,
    required this.databasePath,
  });

  final bool keystoreAvailable;
  final bool localOnly;
  final String databasePath;
}

/// Separate, encrypted-at-field-level SQLite vault for private life evidence.
///
/// The regular application database is deliberately not used. All
/// user-authored strings and inference payloads are encrypted before SQLite
/// sees them; relationship IDs, types and timestamps remain queryable metadata.
class WillMirrorVault {
  WillMirrorVault({
    WillMirrorVaultCipher? cipher,
    DatabaseFactory? factory,
    Future<String> Function()? baseDirectoryProvider,
  })  : _cipher = cipher ?? AndroidKeystoreWillMirrorCipher(),
        _factoryOverride = factory,
        _baseDirectoryProvider = baseDirectoryProvider;

  static const String fileName = 'will_mirror_vault.sqlite';
  static const int schemaVersion = 1;
  static const String practiceProfileKey = 'v5_practice_profile';
  static const String activeActionPlanKey = 'v5_active_action_plan';
  static const String assistantHistoryKey = 'v5_assistant_history';

  static String actionPlanKey(String goalId) => 'v5_action_plan_$goalId';

  final WillMirrorVaultCipher _cipher;
  final DatabaseFactory? _factoryOverride;
  final Future<String> Function()? _baseDirectoryProvider;
  Database? _db;
  Future<Database>? _opening;
  String? _path;

  DatabaseFactory get _factory => _factoryOverride ?? databaseFactory;

  Future<String> _resolvePath() async {
    if (_path != null) return _path!;
    final directory = _baseDirectoryProvider == null
        ? (await getApplicationDocumentsDirectory()).path
        : await _baseDirectoryProvider();
    _path = p.join(directory, fileName);
    return _path!;
  }

  Future<Database> _database() async {
    if (_db != null) return _db!;
    if (_opening != null) return _opening!;
    final path = await _resolvePath();
    _opening = _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          // Android sqflite classifies secure_delete as a query because the
          // PRAGMA returns its effective value. Using execute() throws even
          // though SQLite reports SQLITE_OK.
          await db.rawQuery('PRAGMA secure_delete = ON');
        },
        onCreate: _create,
      ),
    );
    try {
      _db = await _opening!;
      return _db!;
    } finally {
      _opening = null;
    }
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE wm_goal (
        id TEXT PRIMARY KEY,
        text_enc TEXT NOT NULL,
        domain_enc TEXT NOT NULL,
        baseline_desire INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX wm_goal_status_idx ON wm_goal(status, updated_at DESC)',
    );
    await db.execute('''
      CREATE TABLE wm_why_node (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        parent_id TEXT,
        node_type TEXT NOT NULL,
        text_enc TEXT NOT NULL,
        depth INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES wm_goal(id) ON DELETE CASCADE,
        FOREIGN KEY(parent_id) REFERENCES wm_why_node(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX wm_why_goal_idx ON wm_why_node(goal_id, created_at)',
    );
    await db.execute('''
      CREATE TABLE wm_life_evidence (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        evidence_type TEXT NOT NULL,
        title_enc TEXT NOT NULL,
        note_enc TEXT NOT NULL,
        life_stage_enc TEXT NOT NULL,
        domain_enc TEXT NOT NULL,
        intensity INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        cost_level INTEGER NOT NULL,
        audience_present INTEGER NOT NULL,
        externally_requested INTEGER NOT NULL,
        reward_present INTEGER NOT NULL,
        energy_before INTEGER NOT NULL,
        energy_after INTEGER NOT NULL,
        repeat_wish INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES wm_goal(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX wm_life_evidence_goal_idx
      ON wm_life_evidence(goal_id, evidence_type, occurred_at DESC)
    ''');
    await db.execute('''
      CREATE TABLE wm_probe (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        node_id TEXT,
        probe_type TEXT NOT NULL,
        baseline INTEGER NOT NULL,
        after_value INTEGER NOT NULL,
        answer_enc TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES wm_goal(id) ON DELETE CASCADE,
        FOREIGN KEY(node_id) REFERENCES wm_why_node(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE wm_hypothesis (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        label_enc TEXT NOT NULL,
        hypothesis_type TEXT NOT NULL,
        status TEXT NOT NULL,
        confidence_band TEXT NOT NULL,
        explanation_enc TEXT NOT NULL,
        counter_search_completed INTEGER NOT NULL DEFAULT 0,
        counter_search_note_enc TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES wm_goal(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE wm_hypothesis_evidence (
        hypothesis_id TEXT NOT NULL,
        evidence_id TEXT NOT NULL,
        relation_type TEXT NOT NULL,
        weight REAL NOT NULL,
        context_limit_enc TEXT NOT NULL,
        PRIMARY KEY(hypothesis_id, evidence_id),
        FOREIGN KEY(hypothesis_id) REFERENCES wm_hypothesis(id) ON DELETE CASCADE,
        FOREIGN KEY(evidence_id) REFERENCES wm_life_evidence(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE wm_experiment (
        id TEXT PRIMARY KEY,
        hypothesis_id TEXT NOT NULL,
        title_enc TEXT NOT NULL,
        protocol_enc TEXT NOT NULL,
        start_at INTEGER NOT NULL,
        end_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(hypothesis_id) REFERENCES wm_hypothesis(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE wm_experiment_observation (
        id TEXT PRIMARY KEY,
        experiment_id TEXT NOT NULL,
        metrics_enc TEXT NOT NULL,
        note_enc TEXT NOT NULL,
        observed_at INTEGER NOT NULL,
        FOREIGN KEY(experiment_id) REFERENCES wm_experiment(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE wm_inference_run (
        id TEXT PRIMARY KEY,
        engine TEXT NOT NULL,
        input_enc TEXT NOT NULL,
        output_enc TEXT NOT NULL,
        kb_version TEXT NOT NULL,
        model_version TEXT NOT NULL,
        prompt_version TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE wm_setting (
        setting_key TEXT PRIMARY KEY,
        value_enc TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE wm_sync_outbox (
        op_id TEXT PRIMARY KEY,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_enc TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');
  }

  Future<void> ensureSecureReady() async {
    if (!await _cipher.isAvailable()) {
      throw StateError('Android Keystore 当前不可用，已阻止私密人生数据写入。');
    }
    await _database();
  }

  Future<String> _enc(String value) => _cipher.encrypt(value);

  Future<String> _dec(Object? value) => _cipher.decrypt((value ?? '').toString());

  int _bool(bool value) => value ? 1 : 0;

  bool _asBool(Object? value) => value == 1 || value == true;

  /// SQLite `INSERT OR REPLACE` deletes the conflicting row before inserting
  /// it again. With foreign keys enabled that can cascade-delete a Why tree,
  /// evidence links or experiment observations. Parent entities therefore use
  /// update-then-insert semantics instead.
  Future<void> _upsert(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final updated = await db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
    );
    if (updated == 0) await db.insert(table, values);
  }

  Future<void> _recordOutbox({
    required DatabaseExecutor db,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final syncEnabled = await _readSettingWithDb(db, 'cloud_sync_opt_in');
    if (syncEnabled != 'true') return;
    await db.insert(
      'wm_sync_outbox',
      <String, Object?>{
        'op_id': WillMirrorIds.next('op'),
        'entity_id': entityId,
        'operation': operation,
        'payload_enc': await _enc(jsonEncode(payload)),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveGoal(WillMirrorGoal goal) async {
    await ensureSecureReady();
    final db = await _database();
    final text = await _enc(goal.text);
    final domain = await _enc(goal.domain);
    await db.transaction((txn) async {
      if (goal.status == 'active') {
        await txn.update(
          'wm_goal',
          <String, Object?>{
            'status': 'archived',
            'updated_at': goal.updatedAt,
          },
          where: 'id != ? AND status = ?',
          whereArgs: <Object?>[goal.id, 'active'],
        );
      }
      await _upsert(
        txn,
        'wm_goal',
        <String, Object?>{
          'id': goal.id,
          'text_enc': text,
          'domain_enc': domain,
          'baseline_desire': goal.baselineDesire,
          'status': goal.status,
          'created_at': goal.createdAt,
          'updated_at': goal.updatedAt,
        },
        where: 'id = ?',
        whereArgs: <Object?>[goal.id],
      );
      await _recordOutbox(
        db: txn,
        entityId: goal.id,
        operation: 'upsert_goal',
        payload: goal.toJson(),
      );
    });
  }

  Future<List<WillMirrorGoal>> goals() async {
    final db = await _database();
    final rows = await db.query('wm_goal', orderBy: 'updated_at DESC');
    final result = <WillMirrorGoal>[];
    for (final row in rows) {
      result.add(
        WillMirrorGoal(
          id: row['id'].toString(),
          text: await _dec(row['text_enc']),
          domain: await _dec(row['domain_enc']),
          baselineDesire: (row['baseline_desire'] as num?)?.toInt() ?? 0,
          status: row['status'].toString(),
          createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
          updatedAt: (row['updated_at'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return result;
  }

  Future<WillMirrorGoal?> activeGoal() async {
    final all = await goals();
    for (final goal in all) {
      if (goal.status == 'active') return goal;
    }
    return null;
  }

  Future<void> saveWhyNode(WillMirrorWhyNode node) async {
    await ensureSecureReady();
    final db = await _database();
    await db.transaction((txn) async {
      await _upsert(
        txn,
        'wm_why_node',
        <String, Object?>{
          'id': node.id,
          'goal_id': node.goalId,
          'parent_id': node.parentId,
          'node_type': node.nodeType,
          'text_enc': await _enc(node.text),
          'depth': node.depth,
          'created_at': node.createdAt,
        },
        where: 'id = ?',
        whereArgs: <Object?>[node.id],
      );
      await _recordOutbox(
        db: txn,
        entityId: node.id,
        operation: 'upsert_why_node',
        payload: node.toJson(),
      );
    });
  }

  Future<List<WillMirrorWhyNode>> whyNodes(String goalId) async {
    final db = await _database();
    final rows = await db.query(
      'wm_why_node',
      where: 'goal_id = ?',
      whereArgs: <Object?>[goalId],
      orderBy: 'created_at ASC',
    );
    final result = <WillMirrorWhyNode>[];
    for (final row in rows) {
      result.add(
        WillMirrorWhyNode(
          id: row['id'].toString(),
          goalId: row['goal_id'].toString(),
          parentId: row['parent_id']?.toString(),
          nodeType: row['node_type'].toString(),
          text: await _dec(row['text_enc']),
          depth: (row['depth'] as num?)?.toInt() ?? 0,
          createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return result;
  }

  Future<void> saveEvidence(WillMirrorLifeEvidence evidence) async {
    await ensureSecureReady();
    final db = await _database();
    await db.transaction((txn) async {
      await _upsert(
        txn,
        'wm_life_evidence',
        <String, Object?>{
          'id': evidence.id,
          'goal_id': evidence.goalId,
          'evidence_type': evidence.type.value,
          'title_enc': await _enc(evidence.title),
          'note_enc': await _enc(evidence.note),
          'life_stage_enc': await _enc(evidence.lifeStage),
          'domain_enc': await _enc(evidence.domain),
          'intensity': evidence.intensity,
          'duration': evidence.duration,
          'cost_level': evidence.costLevel,
          'audience_present': _bool(evidence.audiencePresent),
          'externally_requested': _bool(evidence.externallyRequested),
          'reward_present': _bool(evidence.rewardPresent),
          'energy_before': evidence.energyBefore,
          'energy_after': evidence.energyAfter,
          'repeat_wish': evidence.repeatWish,
          'occurred_at': evidence.occurredAt,
          'created_at': evidence.createdAt,
        },
        where: 'id = ?',
        whereArgs: <Object?>[evidence.id],
      );
      await _recordOutbox(
        db: txn,
        entityId: evidence.id,
        operation: 'upsert_evidence',
        payload: evidence.toJson(),
      );
    });
  }

  Future<List<WillMirrorLifeEvidence>> evidenceForGoal(String goalId) async {
    final db = await _database();
    final rows = await db.query(
      'wm_life_evidence',
      where: 'goal_id = ?',
      whereArgs: <Object?>[goalId],
      orderBy: 'occurred_at DESC, created_at DESC',
    );
    final result = <WillMirrorLifeEvidence>[];
    for (final row in rows) {
      result.add(
        WillMirrorLifeEvidence(
          id: row['id'].toString(),
          goalId: row['goal_id'].toString(),
          type: parseWillMirrorEvidenceType(row['evidence_type']),
          title: await _dec(row['title_enc']),
          note: await _dec(row['note_enc']),
          lifeStage: await _dec(row['life_stage_enc']),
          domain: await _dec(row['domain_enc']),
          intensity: (row['intensity'] as num?)?.toInt() ?? 0,
          duration: (row['duration'] as num?)?.toInt() ?? 0,
          costLevel: (row['cost_level'] as num?)?.toInt() ?? 0,
          audiencePresent: _asBool(row['audience_present']),
          externallyRequested: _asBool(row['externally_requested']),
          rewardPresent: _asBool(row['reward_present']),
          energyBefore: (row['energy_before'] as num?)?.toInt() ?? 0,
          energyAfter: (row['energy_after'] as num?)?.toInt() ?? 0,
          repeatWish: (row['repeat_wish'] as num?)?.toInt() ?? 0,
          occurredAt: (row['occurred_at'] as num?)?.toInt() ?? 0,
          createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return result;
  }

  Future<void> saveProbe(WillMirrorProbe probe) async {
    await ensureSecureReady();
    final db = await _database();
    await _upsert(
      db,
      'wm_probe',
      <String, Object?>{
        'id': probe.id,
        'goal_id': probe.goalId,
        'node_id': probe.nodeId,
        'probe_type': probe.type.value,
        'baseline': probe.baseline,
        'after_value': probe.after,
        'answer_enc': await _enc(probe.answer),
        'created_at': probe.createdAt,
      },
      where: 'id = ?',
      whereArgs: <Object?>[probe.id],
    );
  }

  Future<List<WillMirrorProbe>> probes(String goalId) async {
    final db = await _database();
    final rows = await db.query(
      'wm_probe',
      where: 'goal_id = ?',
      whereArgs: <Object?>[goalId],
      orderBy: 'created_at DESC',
    );
    final result = <WillMirrorProbe>[];
    for (final row in rows) {
      result.add(
        WillMirrorProbe(
          id: row['id'].toString(),
          goalId: row['goal_id'].toString(),
          nodeId: row['node_id']?.toString(),
          type: parseWillMirrorProbeType(row['probe_type']),
          baseline: (row['baseline'] as num?)?.toInt() ?? 0,
          after: (row['after_value'] as num?)?.toInt() ?? 0,
          answer: await _dec(row['answer_enc']),
          createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return result;
  }

  Future<void> saveHypothesis(WillMirrorHypothesis hypothesis) async {
    await ensureSecureReady();
    final db = await _database();
    await _upsert(
      db,
      'wm_hypothesis',
      <String, Object?>{
        'id': hypothesis.id,
        'goal_id': hypothesis.goalId,
        'label_enc': await _enc(hypothesis.label),
        'hypothesis_type': hypothesis.type.value,
        'status': hypothesis.status,
        'confidence_band': hypothesis.confidenceBand.value,
        'explanation_enc': await _enc(hypothesis.explanation),
        'counter_search_completed':
            _bool(hypothesis.counterSearchCompleted),
        'counter_search_note_enc': await _enc(hypothesis.counterSearchNote),
        'created_at': hypothesis.createdAt,
        'updated_at': hypothesis.updatedAt,
      },
      where: 'id = ?',
      whereArgs: <Object?>[hypothesis.id],
    );
  }

  Future<List<WillMirrorHypothesis>> hypotheses(String goalId) async {
    final db = await _database();
    final rows = await db.query(
      'wm_hypothesis',
      where: 'goal_id = ?',
      whereArgs: <Object?>[goalId],
      orderBy: 'updated_at DESC',
    );
    final result = <WillMirrorHypothesis>[];
    for (final row in rows) {
      result.add(
        WillMirrorHypothesis(
          id: row['id'].toString(),
          goalId: row['goal_id'].toString(),
          label: await _dec(row['label_enc']),
          type: parseWillMirrorHypothesisType(row['hypothesis_type']),
          status: row['status'].toString(),
          confidenceBand:
              parseWillMirrorConfidenceBand(row['confidence_band']),
          explanation: await _dec(row['explanation_enc']),
          counterSearchCompleted:
              _asBool(row['counter_search_completed']),
          counterSearchNote: await _dec(row['counter_search_note_enc']),
          createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
          updatedAt: (row['updated_at'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return result;
  }

  Future<void> linkEvidence(WillMirrorHypothesisEvidence link) async {
    await ensureSecureReady();
    final db = await _database();
    await _upsert(
      db,
      'wm_hypothesis_evidence',
      <String, Object?>{
        'hypothesis_id': link.hypothesisId,
        'evidence_id': link.evidenceId,
        'relation_type': link.relation.value,
        'weight': link.weight,
        'context_limit_enc': await _enc(link.contextLimit),
      },
      where: 'hypothesis_id = ? AND evidence_id = ?',
      whereArgs: <Object?>[link.hypothesisId, link.evidenceId],
    );
  }

  Future<List<WillMirrorHypothesisEvidence>> links(
    String hypothesisId,
  ) async {
    final db = await _database();
    final rows = await db.query(
      'wm_hypothesis_evidence',
      where: 'hypothesis_id = ?',
      whereArgs: <Object?>[hypothesisId],
    );
    final result = <WillMirrorHypothesisEvidence>[];
    for (final row in rows) {
      result.add(
        WillMirrorHypothesisEvidence(
          hypothesisId: row['hypothesis_id'].toString(),
          evidenceId: row['evidence_id'].toString(),
          relation: parseWillMirrorRelation(row['relation_type']),
          weight: (row['weight'] as num?)?.toDouble() ?? 0,
          contextLimit: await _dec(row['context_limit_enc']),
        ),
      );
    }
    return result;
  }

  Future<void> unlinkEvidence(String hypothesisId, String evidenceId) async {
    final db = await _database();
    await db.delete(
      'wm_hypothesis_evidence',
      where: 'hypothesis_id = ? AND evidence_id = ?',
      whereArgs: <Object?>[hypothesisId, evidenceId],
    );
  }

  Future<void> saveExperiment(WillMirrorExperiment experiment) async {
    await ensureSecureReady();
    final db = await _database();
    await _upsert(
      db,
      'wm_experiment',
      <String, Object?>{
        'id': experiment.id,
        'hypothesis_id': experiment.hypothesisId,
        'title_enc': await _enc(experiment.title),
        'protocol_enc': await _enc(experiment.protocol),
        'start_at': experiment.startAt,
        'end_at': experiment.endAt,
        'status': experiment.status.value,
        'created_at': experiment.createdAt,
      },
      where: 'id = ?',
      whereArgs: <Object?>[experiment.id],
    );
  }

  Future<List<WillMirrorExperiment>> experiments({
    String? hypothesisId,
  }) async {
    final db = await _database();
    final rows = await db.query(
      'wm_experiment',
      where: hypothesisId == null ? null : 'hypothesis_id = ?',
      whereArgs: hypothesisId == null ? null : <Object?>[hypothesisId],
      orderBy: 'created_at DESC',
    );
    final result = <WillMirrorExperiment>[];
    for (final row in rows) {
      result.add(
        WillMirrorExperiment(
          id: row['id'].toString(),
          hypothesisId: row['hypothesis_id'].toString(),
          title: await _dec(row['title_enc']),
          protocol: await _dec(row['protocol_enc']),
          startAt: (row['start_at'] as num?)?.toInt() ?? 0,
          endAt: (row['end_at'] as num?)?.toInt() ?? 0,
          status: parseWillMirrorExperimentStatus(row['status']),
          createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return result;
  }

  Future<WillMirrorExperiment?> activeExperiment() async {
    final all = await experiments();
    for (final item in all) {
      if (item.status == WillMirrorExperimentStatus.active) return item;
    }
    return null;
  }

  Future<void> saveObservation(WillMirrorObservation observation) async {
    await ensureSecureReady();
    final db = await _database();
    final metrics = jsonEncode(<String, int>{
      'energy': observation.energy,
      'real_me': observation.realMe,
      'persistence': observation.persistence,
      'satisfaction': observation.satisfaction,
    });
    await _upsert(
      db,
      'wm_experiment_observation',
      <String, Object?>{
        'id': observation.id,
        'experiment_id': observation.experimentId,
        'metrics_enc': await _enc(metrics),
        'note_enc': await _enc(observation.note),
        'observed_at': observation.observedAt,
      },
      where: 'id = ?',
      whereArgs: <Object?>[observation.id],
    );
  }

  Future<List<WillMirrorObservation>> observations(String experimentId) async {
    final db = await _database();
    final rows = await db.query(
      'wm_experiment_observation',
      where: 'experiment_id = ?',
      whereArgs: <Object?>[experimentId],
      orderBy: 'observed_at DESC',
    );
    final result = <WillMirrorObservation>[];
    for (final row in rows) {
      final raw = jsonDecode(await _dec(row['metrics_enc']));
      final metrics = raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      int metric(String key) =>
          int.tryParse((metrics[key] ?? 0).toString()) ?? 0;
      result.add(
        WillMirrorObservation(
          id: row['id'].toString(),
          experimentId: row['experiment_id'].toString(),
          energy: metric('energy'),
          realMe: metric('real_me'),
          persistence: metric('persistence'),
          satisfaction: metric('satisfaction'),
          note: await _dec(row['note_enc']),
          observedAt: (row['observed_at'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return result;
  }

  Future<void> saveInferenceRun({
    required String engine,
    required Map<String, dynamic> input,
    required Map<String, dynamic> output,
    required String kbVersion,
    required String modelVersion,
    required String promptVersion,
  }) async {
    await ensureSecureReady();
    final db = await _database();
    await db.insert('wm_inference_run', <String, Object?>{
      'id': WillMirrorIds.next('run'),
      'engine': engine,
      'input_enc': await _enc(jsonEncode(input)),
      'output_enc': await _enc(jsonEncode(output)),
      'kb_version': kbVersion,
      'model_version': modelVersion,
      'prompt_version': promptVersion,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> writeSetting(String key, String value) async {
    await ensureSecureReady();
    final db = await _database();
    await _upsert(
      db,
      'wm_setting',
      <String, Object?>{
        'setting_key': key,
        'value_enc': await _enc(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'setting_key = ?',
      whereArgs: <Object?>[key],
    );
  }

  Future<String?> _readSettingWithDb(
    DatabaseExecutor db,
    String key,
  ) async {
    final rows = await db.query(
      'wm_setting',
      columns: <String>['value_enc'],
      where: 'setting_key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _dec(rows.first['value_enc']);
  }

  Future<String?> readSetting(String key) async {
    final db = await _database();
    return _readSettingWithDb(db, key);
  }

  Future<void> savePracticeProfile(WillMirrorPracticeProfile profile) {
    return writeSetting(practiceProfileKey, jsonEncode(profile.toJson()));
  }

  Future<WillMirrorPracticeProfile?> practiceProfile() async {
    final raw = await readSetting(practiceProfileKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return WillMirrorPracticeProfile.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveActionPlan(WillMirrorActionPlan plan) async {
    await writeSetting(actionPlanKey(plan.goalId), plan.encode());
    if (plan.status == 'active') {
      await writeSetting(activeActionPlanKey, plan.goalId);
    }
  }

  Future<WillMirrorActionPlan?> actionPlan(String goalId) async {
    final raw = await readSetting(actionPlanKey(goalId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return WillMirrorActionPlan.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<WillMirrorActionPlan?> activeActionPlan() async {
    final storedGoalId = await readSetting(activeActionPlanKey);
    if (storedGoalId != null && storedGoalId.isNotEmpty) {
      final stored = await actionPlan(storedGoalId);
      if (stored != null && stored.status == 'active') return stored;
    }
    final goal = await activeGoal();
    if (goal == null) return null;
    final byGoal = await actionPlan(goal.id);
    return byGoal?.status == 'active' ? byGoal : null;
  }

  Future<WillMirrorVaultStatus> status() async {
    final path = await _resolvePath();
    final sync = await readSetting('cloud_sync_opt_in');
    return WillMirrorVaultStatus(
      keystoreAvailable: await _cipher.isAvailable(),
      localOnly: sync != 'true',
      databasePath: path,
    );
  }

  Future<Map<String, dynamic>> exportDecrypted() async {
    final goalList = await goals();
    final goalPayloads = <Map<String, dynamic>>[];
    final allHypotheses = <WillMirrorHypothesis>[];
    for (final goal in goalList) {
      final nodes = await whyNodes(goal.id);
      final evidence = await evidenceForGoal(goal.id);
      final goalProbes = await probes(goal.id);
      final hypothesisList = await hypotheses(goal.id);
      final practicePlan = await actionPlan(goal.id);
      allHypotheses.addAll(hypothesisList);
      goalPayloads.add(<String, dynamic>{
        ...goal.toJson(),
        'why_nodes': nodes.map((item) => item.toJson()).toList(),
        'evidence': evidence.map((item) => item.toJson()).toList(),
        'probes': goalProbes.map((item) => item.toJson()).toList(),
        'hypotheses': hypothesisList.map((item) => item.toJson()).toList(),
        if (practicePlan != null) 'practice_plan': practicePlan.toJson(),
      });
    }
    final experimentList = await experiments();
    final experimentPayloads = <Map<String, dynamic>>[];
    for (final experiment in experimentList) {
      experimentPayloads.add(<String, dynamic>{
        ...experiment.toJson(),
        'observations': (await observations(experiment.id))
            .map((item) => item.toJson())
            .toList(),
      });
    }
    final linkPayloads = <Map<String, dynamic>>[];
    for (final hypothesis in allHypotheses) {
      linkPayloads.addAll(
        (await links(hypothesis.id)).map((item) => item.toJson()),
      );
    }
    final profile = await practiceProfile();
    final rawAssistantHistory = await readSetting(assistantHistoryKey);
    Object? assistantHistory;
    if (rawAssistantHistory != null && rawAssistantHistory.isNotEmpty) {
      try {
        assistantHistory = jsonDecode(rawAssistantHistory);
      } catch (_) {
        assistantHistory = rawAssistantHistory;
      }
    }
    return <String, dynamic>{
      'product': '意志之镜',
      'schema_version': '5.0',
      'exported_at': DateTime.now().toIso8601String(),
      'notice': '这是用户主动导出的明文副本，请由用户自行安全保管。',
      if (profile != null) 'practice_profile': profile.toJson(),
      if (assistantHistory != null) 'assistant_history': assistantHistory,
      'goals': goalPayloads,
      'hypothesis_evidence': linkPayloads,
      'experiments': experimentPayloads,
    };
  }

  Future<String> exportToFile() async {
    final directory = _baseDirectoryProvider == null
        ? (await getApplicationDocumentsDirectory()).path
        : await _baseDirectoryProvider();
    final exportDirectory = Directory(p.join(directory, 'will_mirror_exports'));
    await exportDirectory.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File(p.join(exportDirectory.path, 'will_mirror_$stamp.json'));
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(await exportDecrypted()), flush: true);
    return file.path;
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await db.close();
  }

  /// Cryptographic erasure: delete the SQLite file, then destroy the Keystore
  /// key so any remnant ciphertext is irrecoverable.
  Future<void> deleteAll() async {
    final path = await _resolvePath();
    final db = await _database();
    await db.rawQuery('PRAGMA secure_delete = ON');
    await close();
    await _factory.deleteDatabase(path);
    await _cipher.destroyKey();
  }
}
