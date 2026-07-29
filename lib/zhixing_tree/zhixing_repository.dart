import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'zhixing_engine.dart';
import 'zhixing_models.dart';

class ZhixingRepository {
  final ZhixingEngine engine;

  ZhixingRepository({ZhixingEngine? engine}) : engine = engine ?? ZhixingEngine();

  Future<Database> _database() => AppDatabase.instance();

  Future<void> ensureTables() async {
    final db = await _database();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_diagnoses (
        id TEXT PRIMARY KEY,
        created_at_ms INTEGER NOT NULL,
        payload_json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_diagnoses_created '
      'ON zhixing_diagnoses(created_at_ms DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_actions (
        id TEXT PRIMARY KEY,
        diagnosis_id TEXT NOT NULL,
        status TEXT NOT NULL,
        challenge_type TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        completed_at_ms INTEGER,
        payload_json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_actions_status '
      'ON zhixing_actions(status, updated_at_ms DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_evidence (
        id TEXT PRIMARY KEY,
        prescription_id TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        payload_json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_evidence_action '
      'ON zhixing_evidence(prescription_id, created_at_ms DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_match_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prescription_id TEXT NOT NULL,
        dominant TEXT NOT NULL,
        confidence REAL NOT NULL DEFAULT 0,
        user_fit TEXT NOT NULL DEFAULT '',
        completed INTEGER,
        created_at_ms INTEGER NOT NULL,
        payload_json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_zhixing_match_history_action '
      'ON zhixing_match_history(prescription_id, created_at_ms DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zhixing_state (
        state_key TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
  }

  Future<void> saveDiagnosis(ZhixingDiagnosis diagnosis) async {
    await ensureTables();
    final db = await _database();
    await db.insert(
      'zhixing_diagnoses',
      <String, Object?>{
        'id': diagnosis.id,
        'created_at_ms': diagnosis.createdAtMs,
        'payload_json': jsonEncode(diagnosis.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAction(ZhixingPrescription action) async {
    await ensureTables();
    final db = await _database();
    await db.transaction((txn) async {
      await _upsertAction(txn, action);
      final existing = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM zhixing_match_history WHERE prescription_id = ?',
            <Object?>[action.id],
          )) ??
          0;
      if (existing == 0) {
        await txn.insert('zhixing_match_history', <String, Object?>{
          'prescription_id': action.id,
          'dominant': action.thoughtMatch.dominant,
          'confidence': action.thoughtMatch.confidence,
          'user_fit': '',
          'completed': null,
          'created_at_ms': action.createdAtMs,
          'payload_json': jsonEncode(action.thoughtMatch.toJson()),
        });
      }
    });
  }

  Future<ZhixingDashboard> loadDashboard() async {
    await ensureTables();
    final db = await _database();
    var game = await _loadGame(db);
    final refreshed = _refreshLifecycle(game);
    if (refreshed.encode() != game.encode()) {
      await _saveState(db, 'game', refreshed.encode());
      game = refreshed;
    }
    final profile = await _loadProfile(db);
    final actions = await listActions(limit: 30);
    final evidence = await listEvidence(limit: 30);
    ZhixingPrescription? active;
    for (final action in actions) {
      if (action.status == ZhixingActionStatus.ready ||
          action.status == ZhixingActionStatus.started ||
          action.status == ZhixingActionStatus.blocked) {
        active = action;
        break;
      }
    }
    return ZhixingDashboard(
      game: game,
      profile: profile,
      active: active,
      recentActions: actions,
      recentEvidence: evidence,
    );
  }

  Future<ZhixingActionProfile> loadProfile() async {
    await ensureTables();
    return _loadProfile(await _database());
  }

  Future<void> saveProfile(ZhixingActionProfile profile) async {
    await ensureTables();
    await _saveState(await _database(), 'profile', profile.encode());
  }

  Future<ZhixingGameState> loadGame() async {
    await ensureTables();
    final db = await _database();
    final refreshed = _refreshLifecycle(await _loadGame(db));
    await _saveState(db, 'game', refreshed.encode());
    return refreshed;
  }

  Future<List<ZhixingPrescription>> listActions({int limit = 100}) async {
    await ensureTables();
    final db = await _database();
    final rows = await db.query(
      'zhixing_actions',
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows
        .map((row) {
          try {
            return ZhixingPrescription.decode((row['payload_json'] ?? '{}').toString());
          } catch (_) {
            return null;
          }
        })
        .whereType<ZhixingPrescription>()
        .toList();
  }

  Future<List<ZhixingEvidence>> listEvidence({
    String? prescriptionId,
    int limit = 100,
  }) async {
    await ensureTables();
    final db = await _database();
    final rows = await db.query(
      'zhixing_evidence',
      where: prescriptionId == null ? null : 'prescription_id = ?',
      whereArgs: prescriptionId == null ? null : <Object?>[prescriptionId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows
        .map((row) {
          try {
            return ZhixingEvidence.decode((row['payload_json'] ?? '{}').toString());
          } catch (_) {
            return null;
          }
        })
        .whereType<ZhixingEvidence>()
        .toList();
  }

  Future<void> beginAction(ZhixingPrescription action) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await saveAction(action.copyWith(
      status: ZhixingActionStatus.started,
      startedAtMs: action.startedAtMs ?? now,
      updatedAtMs: now,
    ));
  }

  Future<ZhixingPrescription> applyStuckStrategy(
    ZhixingPrescription action,
    String strategy,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    String nextAction;
    String nextFirst;
    switch (strategy) {
      case 'adapt':
        nextAction = action.stuckAdapt;
        nextFirst = '移除一个阻力或发出一个具体支持请求';
        break;
      case 'carry':
        nextAction = action.stuckCarry;
        nextFirst = action.firstPhysicalAction;
        break;
      case 'reconsider':
        nextAction = action.stuckReconsider;
        nextFirst = '写下：目标、风险、资源、恢复，哪个才是当前真正问题';
        break;
      case 'shrink':
      default:
        nextAction = action.stuckShrink;
        nextFirst = action.firstPhysicalAction;
        strategy = 'shrink';
    }
    final updated = action.copyWith(
      action: nextAction,
      firstPhysicalAction: nextFirst,
      status: ZhixingActionStatus.blocked,
      updatedAtMs: now,
      selectedStuckStrategy: strategy,
    );
    await saveAction(updated);
    return updated;
  }

  Future<ZhixingRewardResult> completeAction(
    ZhixingPrescription action,
    ZhixingEvidence evidence,
  ) async {
    await ensureTables();
    final db = await _database();
    return db.transaction((txn) async {
      final rows = await txn.query(
        'zhixing_actions',
        where: 'id = ?',
        whereArgs: <Object?>[action.id],
        limit: 1,
      );
      ZhixingPrescription stored = action;
      if (rows.isNotEmpty) {
        try {
          stored = ZhixingPrescription.decode((rows.first['payload_json'] ?? '{}').toString());
        } catch (_) {}
      }
      var game = _refreshLifecycle(await _loadGame(txn));
      if (stored.status == ZhixingActionStatus.completed) {
        return ZhixingRewardResult(
          game: game,
          grantedXp: 0,
          grantedCoins: 0,
          returnBonus: false,
          alreadySettled: true,
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final completed = stored.copyWith(
        status: ZhixingActionStatus.completed,
        completedAtMs: now,
        updatedAtMs: now,
      );
      await _upsertAction(txn, completed);
      await _upsertEvidence(txn, evidence);

      final profile = await _loadProfile(txn);
      final nextProfile = engine.profileAfterEvidence(profile, completed, evidence);
      await _saveState(txn, 'profile', nextProfile.encode());

      final today = _dayKey(DateTime.now());
      var dailyXp = game.dayKey == today ? game.dailyXp : 0;
      var dailyCoins = game.dayKey == today ? game.dailyCoins : 0;
      final gapMs = game.lastActionAtMs == null ? 0 : now - game.lastActionAtMs!;
      final returnBonus = game.completedCount > 0 && gapMs >= const Duration(hours: 48).inMilliseconds;
      final requestedXp = completed.rewardXp + (returnBonus ? 10 : 0);
      final requestedCoins = completed.rewardCoins + (returnBonus ? 10 : 0);
      final grantedXp = mathMin(requestedXp, ZhixingEngine.dailyXpCap - dailyXp);
      final grantedCoins = mathMin(requestedCoins, ZhixingEngine.dailyCoinCap - dailyCoins);
      dailyXp += grantedXp;
      dailyCoins += grantedCoins;

      final nextXp = game.xp + grantedXp;
      final nextCompleted = game.completedCount + 1;
      final stage = _stageFor(nextCompleted);
      final highest = _higherStage(game.highestStage, stage);
      game = game.copyWith(
        xp: nextXp,
        coins: game.coins + grantedCoins,
        water: game.water + completed.rewardWater,
        sunlight: game.sunlight + completed.rewardSunlight,
        fertilizer: game.fertilizer + completed.rewardFertilizer,
        dailyXp: dailyXp,
        dailyCoins: dailyCoins,
        dayKey: today,
        level: _levelFor(nextXp),
        stage: stage,
        highestStage: highest,
        condition: 'healthy',
        health: (game.health + 12).clamp(0, 100).toDouble(),
        dormant: false,
        lastActionAtMs: now,
        completedCount: nextCompleted,
        returnCount: game.returnCount + (returnBonus ? 1 : 0),
      );
      await _saveState(txn, 'game', game.encode());
      await txn.update(
        'zhixing_match_history',
        <String, Object?>{
          'user_fit': evidence.fit,
          'completed': 1,
        },
        where: 'prescription_id = ?',
        whereArgs: <Object?>[completed.id],
      );
      return ZhixingRewardResult(
        game: game,
        grantedXp: grantedXp,
        grantedCoins: grantedCoins,
        returnBonus: returnBonus,
      );
    });
  }

  Future<void> recalibrateAction(
    ZhixingPrescription action,
    ZhixingEvidence evidence,
  ) async {
    await ensureTables();
    final db = await _database();
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = action.copyWith(
        status: ZhixingActionStatus.recalibrate,
        updatedAtMs: now,
      );
      await _upsertAction(txn, updated);
      await _upsertEvidence(txn, evidence);
      final profile = await _loadProfile(txn);
      await _saveState(
        txn,
        'profile',
        engine.profileAfterEvidence(profile, updated, evidence).encode(),
      );
      await txn.update(
        'zhixing_match_history',
        <String, Object?>{
          'user_fit': evidence.fit,
          'completed': 0,
        },
        where: 'prescription_id = ?',
        whereArgs: <Object?>[updated.id],
      );
    });
  }

  Future<ZhixingGameState> buyResourcePack(String pack) async {
    await ensureTables();
    final db = await _database();
    return db.transaction((txn) async {
      var game = await _loadGame(txn);
      var price = 0;
      var water = 0;
      var sun = 0;
      var fertilizer = 0;
      switch (pack) {
        case 'water':
          price = 8;
          water = 1;
          break;
        case 'sunlight':
          price = 8;
          sun = 1;
          break;
        case 'fertilizer':
          price = 12;
          fertilizer = 1;
          break;
        case 'care':
          price = 25;
          water = 1;
          sun = 1;
          break;
        case 'complete':
          price = 40;
          water = 1;
          sun = 1;
          fertilizer = 1;
          break;
        default:
          throw ArgumentError.value(pack, 'pack', 'Unknown resource pack');
      }
      if (game.coins < price) throw StateError('金币不足');
      game = game.copyWith(
        coins: game.coins - price,
        water: game.water + water,
        sunlight: game.sunlight + sun,
        fertilizer: game.fertilizer + fertilizer,
      );
      await _saveState(txn, 'game', game.encode());
      return game;
    });
  }

  Future<ZhixingGameState> nourish(String resource) async {
    await ensureTables();
    final db = await _database();
    return db.transaction((txn) async {
      var game = await _loadGame(txn);
      var water = game.water;
      var sun = game.sunlight;
      var fertilizer = game.fertilizer;
      var healthGain = 0.0;
      switch (resource) {
        case 'water':
          if (water <= 0) throw StateError('水不足');
          water -= 1;
          healthGain = 12;
          break;
        case 'sunlight':
          if (sun <= 0) throw StateError('阳光不足');
          sun -= 1;
          healthGain = 10;
          break;
        case 'fertilizer':
          if (fertilizer <= 0) throw StateError('肥料不足');
          fertilizer -= 1;
          healthGain = 8;
          break;
        default:
          throw ArgumentError.value(resource, 'resource', 'Unknown resource');
      }
      final health = (game.health + healthGain).clamp(0, 100).toDouble();
      game = game.copyWith(
        water: water,
        sunlight: sun,
        fertilizer: fertilizer,
        health: health,
        condition: health >= 65 ? 'healthy' : game.condition,
      );
      await _saveState(txn, 'game', game.encode());
      return game;
    });
  }

  Future<ZhixingGameState> setDormant(bool dormant) async {
    await ensureTables();
    final db = await _database();
    var game = await _loadGame(db);
    game = game.copyWith(
      dormant: dormant,
      condition: dormant ? 'dormant' : _refreshLifecycle(game.copyWith(dormant: false)).condition,
    );
    await _saveState(db, 'game', game.encode());
    return game;
  }

  Future<ZhixingGameState> rebirth() async {
    await ensureTables();
    final db = await _database();
    var game = await _loadGame(db);
    if (game.condition != 'seed_waiting' && game.health > 0) return game;
    game = game.copyWith(
      stage: 'seed',
      condition: 'healthy',
      health: 45,
      dormant: false,
      rebirthCount: game.rebirthCount + 1,
      treeBirthAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _saveState(db, 'game', game.encode());
    return game;
  }

  Future<void> deleteAction(String actionId) async {
    await ensureTables();
    final db = await _database();
    await db.transaction((txn) async {
      await txn.delete(
        'zhixing_evidence',
        where: 'prescription_id = ?',
        whereArgs: <Object?>[actionId],
      );
      await txn.delete(
        'zhixing_match_history',
        where: 'prescription_id = ?',
        whereArgs: <Object?>[actionId],
      );
      await txn.delete(
        'zhixing_actions',
        where: 'id = ?',
        whereArgs: <Object?>[actionId],
      );
    });
  }

  Future<void> clearAll() async {
    await ensureTables();
    final db = await _database();
    await db.transaction((txn) async {
      await txn.delete('zhixing_evidence');
      await txn.delete('zhixing_match_history');
      await txn.delete('zhixing_actions');
      await txn.delete('zhixing_diagnoses');
      await txn.delete('zhixing_state');
    });
  }

  Future<void> _upsertAction(
    DatabaseExecutor db,
    ZhixingPrescription action,
  ) async {
    await db.insert(
      'zhixing_actions',
      <String, Object?>{
        'id': action.id,
        'diagnosis_id': action.diagnosisId,
        'status': action.status.code,
        'challenge_type': action.challengeType.code,
        'created_at_ms': action.createdAtMs,
        'updated_at_ms': action.updatedAtMs,
        'completed_at_ms': action.completedAtMs,
        'payload_json': action.encode(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _upsertEvidence(
    DatabaseExecutor db,
    ZhixingEvidence evidence,
  ) async {
    await db.insert(
      'zhixing_evidence',
      <String, Object?>{
        'id': evidence.id,
        'prescription_id': evidence.prescriptionId,
        'completed': evidence.completed ? 1 : 0,
        'created_at_ms': evidence.createdAtMs,
        'payload_json': evidence.encode(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ZhixingGameState> _loadGame(DatabaseExecutor db) async {
    final raw = await _loadState(db, 'game');
    if (raw == null) {
      final initial = ZhixingGameState(
        dayKey: _dayKey(DateTime.now()),
        treeBirthAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _saveState(db, 'game', initial.encode());
      return initial;
    }
    return ZhixingGameState.decode(raw);
  }

  Future<ZhixingActionProfile> _loadProfile(DatabaseExecutor db) async {
    final raw = await _loadState(db, 'profile');
    if (raw == null) return const ZhixingActionProfile();
    return ZhixingActionProfile.decode(raw);
  }

  Future<String?> _loadState(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      'zhixing_state',
      columns: <String>['payload_json'],
      where: 'state_key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['payload_json']?.toString();
  }

  Future<void> _saveState(
    DatabaseExecutor db,
    String key,
    String payload,
  ) async {
    await db.insert(
      'zhixing_state',
      <String, Object?>{
        'state_key': key,
        'payload_json': payload,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  ZhixingGameState _refreshLifecycle(ZhixingGameState game) {
    if (game.dormant) return game.copyWith(condition: 'dormant');
    final last = game.lastActionAtMs;
    if (last == null) return game.copyWith(condition: 'healthy');
    final days = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(last))
        .inDays;
    if (days < 3) {
      return game.copyWith(condition: 'healthy');
    }
    if (days < 7) {
      return game.copyWith(
        condition: 'dry',
        health: mathMinDouble(game.health, 78),
      );
    }
    if (days < 14) {
      return game.copyWith(
        condition: 'withered',
        health: mathMinDouble(game.health, 48),
      );
    }
    if (days < 45) {
      return game.copyWith(
        condition: 'withered',
        health: mathMinDouble(game.health, 22),
      );
    }
    return game.copyWith(
      condition: 'seed_waiting',
      stage: 'seed',
      health: 0,
    );
  }

  int _levelFor(int xp) {
    if (xp >= 1250) return 7;
    if (xp >= 850) return 6;
    if (xp >= 520) return 5;
    if (xp >= 280) return 4;
    if (xp >= 120) return 3;
    if (xp >= 40) return 2;
    return 1;
  }

  String _stageFor(int completed) {
    if (completed >= 100) return 'ancient_tree';
    if (completed >= 50) return 'great_tree';
    if (completed >= 25) return 'mature_tree';
    if (completed >= 10) return 'small_tree';
    if (completed >= 4) return 'sapling';
    if (completed >= 1) return 'sprout';
    return 'seed';
  }

  String _higherStage(String first, String second) {
    const stages = <String>[
      'seed',
      'sprout',
      'sapling',
      'small_tree',
      'mature_tree',
      'great_tree',
      'ancient_tree',
    ];
    final a = stages.indexOf(first);
    final b = stages.indexOf(second);
    return stages[a >= b ? (a < 0 ? 0 : a) : (b < 0 ? 0 : b)];
  }

  String _dayKey(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

int mathMin(int a, int b) {
  if (b <= 0) return 0;
  return a < b ? a : b;
}

double mathMinDouble(double a, double b) => a < b ? a : b;
