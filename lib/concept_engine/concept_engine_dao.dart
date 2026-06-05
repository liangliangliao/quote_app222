import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'action_engine/models/action_engine_models.dart';
import 'concept_engine_models.dart';

class ConceptEngineDao {
  static const _zones = ['work', 'life', 'team'];

  Future<void> ensureSchema() async {
    final db = await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ce_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concept TEXT NOT NULL,
        domain TEXT,
        goal TEXT,
        scene_title TEXT,
        provider TEXT DEFAULT 'deepseek',
        model TEXT DEFAULT '',
        transport_mode TEXT DEFAULT 'direct',
        session_key TEXT DEFAULT '',
        result_label TEXT,
        total_score INTEGER DEFAULT 0,
        summary TEXT,
        state_json TEXT,
        replay_json TEXT,
        history_json TEXT,
        scene_json TEXT,
        action_tags_json TEXT,
        triggered_events_json TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ce_world_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        total_xp INTEGER DEFAULT 0,
        level INTEGER DEFAULT 1,
        total_runs INTEGER DEFAULT 0,
        successful_runs INTEGER DEFAULT 0,
        streak INTEGER DEFAULT 0,
        achievements_json TEXT DEFAULT '[]',
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ce_world_zone_state (
        zone_id TEXT PRIMARY KEY,
        unlocked INTEGER DEFAULT 0,
        cleared_count INTEGER DEFAULT 0,
        failed_count INTEGER DEFAULT 0,
        anomaly_level INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ce_cabin_stage_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_key TEXT NOT NULL,
        cabin_type TEXT DEFAULT '',
        stage TEXT NOT NULL,
        payload_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL
      )
    ''');

    final worldRows = await db.query('ce_world_profile', where: 'id = 1', limit: 1);
    if (worldRows.isEmpty) {
      await db.insert('ce_world_profile', {
        'id': 1,
        'total_xp': 0,
        'level': 1,
        'total_runs': 0,
        'successful_runs': 0,
        'streak': 0,
        'achievements_json': '[]',
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    final info = await db.rawQuery('PRAGMA table_info(ce_sessions)');
    final cols = info.map((e) => (e['name'] ?? '').toString()).toSet();
    if (!cols.contains('provider')) {
      await db.execute("ALTER TABLE ce_sessions ADD COLUMN provider TEXT DEFAULT 'deepseek'");
    }
    if (!cols.contains('model')) {
      await db.execute("ALTER TABLE ce_sessions ADD COLUMN model TEXT DEFAULT ''");
    }
    if (!cols.contains('transport_mode')) {
      await db.execute("ALTER TABLE ce_sessions ADD COLUMN transport_mode TEXT DEFAULT 'direct'");
    }
    if (!cols.contains('session_key')) {
      await db.execute("ALTER TABLE ce_sessions ADD COLUMN session_key TEXT DEFAULT ''");
    }
    if (!cols.contains('history_json')) {
      await db.execute("ALTER TABLE ce_sessions ADD COLUMN history_json TEXT DEFAULT '[]'");
    }
    if (!cols.contains('scene_json')) {
      await db.execute("ALTER TABLE ce_sessions ADD COLUMN scene_json TEXT DEFAULT '{}'");
    }
    if (!cols.contains('action_tags_json')) {
      await db.execute("ALTER TABLE ce_sessions ADD COLUMN action_tags_json TEXT DEFAULT '[]'");
    }
    if (!cols.contains('triggered_events_json')) {
      await db.execute("ALTER TABLE ce_sessions ADD COLUMN triggered_events_json TEXT DEFAULT '[]'");
    }
    if (!cols.contains('cabin_type')) {
      await db.execute("ALTER TABLE ce_sessions ADD COLUMN cabin_type TEXT DEFAULT ''");
    }
    if (!cols.contains('process_json')) {
      await db.execute("ALTER TABLE ce_sessions ADD COLUMN process_json TEXT DEFAULT '{}'");
    }

    for (final zoneId in _zones) {
      final rows = await db.query('ce_world_zone_state', where: 'zone_id = ?', whereArgs: [zoneId], limit: 1);
      if (rows.isEmpty) {
        await db.insert('ce_world_zone_state', ConceptWorldZoneState.initial(zoneId, unlocked: zoneId == 'work').toMap());
      }
    }
  }

  Future<int> insertSession({
    required String concept,
    required String domain,
    required String goal,
    required String sceneTitle,
    required String provider,
    required String model,
    required String transportMode,
    required String sessionKey,
    String cabinType = '',
    Map<String, dynamic>? processData,
    required ReplayResult replay,
    required ChallengeWorldState state,
    required SceneOption? scene,
    required List<ChallengeMessage> history,
    required List<String> actionTags,
    required List<String> triggeredEvents,
  }) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    return db.insert(
      'ce_sessions',
      {
        'concept': concept,
        'domain': domain,
        'goal': goal,
        'scene_title': sceneTitle,
        'provider': provider,
        'model': model,
        'transport_mode': transportMode,
        'session_key': sessionKey,
        'cabin_type': cabinType,
        'process_json': jsonEncode(processData ?? <String, dynamic>{}),
        'result_label': replay.resultLabel,
        'total_score': replay.totalScore,
        'summary': replay.summary,
        'state_json': jsonEncode(state.toJson()),
        'replay_json': jsonEncode(replay.toJson()),
        'history_json': jsonEncode(history.map((e) => e.toJson()).toList()),
        'scene_json': jsonEncode(scene?.toJson() ?? <String, dynamic>{}),
        'action_tags_json': jsonEncode(actionTags),
        'triggered_events_json': jsonEncode(triggeredEvents),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> logCabinStageEvent({
    required String sessionKey,
    required String cabinType,
    required String stage,
    required Map<String, dynamic> payload,
  }) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    await db.insert('ce_cabin_stage_events', {
      'session_key': sessionKey,
      'cabin_type': cabinType,
      'stage': stage,
      'payload_json': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> listCabinStageEvents(String sessionKey) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query(
      'ce_cabin_stage_events',
      where: 'session_key = ?',
      whereArgs: [sessionKey],
      orderBy: 'id ASC',
    );
    return rows
        .map((row) => {
              'id': row['id'],
              'session_key': row['session_key'],
              'cabin_type': row['cabin_type'],
              'stage': row['stage'],
              'payload': _tryJsonMap((row['payload_json'] ?? '{}').toString()),
              'created_at': (row['created_at'] ?? '').toString(),
            })
        .toList();
  }

  Map<String, dynamic> _tryJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<List<ConceptEngineSessionRecord>> listRecent({int limit = 20}) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query('ce_sessions', orderBy: 'id DESC', limit: limit);
    return rows.map(ConceptEngineSessionRecord.fromMap).toList();
  }

  Future<ConceptEngineSessionRecord?> getById(int id) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query('ce_sessions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return ConceptEngineSessionRecord.fromMap(rows.first);
  }

  Future<Map<String, dynamic>> getCabinProcessInsights({int limit = 200}) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query('ce_cabin_stage_events', orderBy: 'id DESC', limit: limit);
    final attitudeCounts = <String, int>{};
    final impactDecisionCounts = <String, int>{};
    final stageCounts = <String, int>{};
    final cabinStageCounts = <String, int>{};

    for (final row in rows) {
      final stage = (row['stage'] ?? '').toString();
      final cabinType = (row['cabin_type'] ?? '').toString();
      final payload = _tryJsonMap((row['payload_json'] ?? '{}').toString());
      stageCounts[stage] = (stageCounts[stage] ?? 0) + 1;
      cabinStageCounts[cabinType] = (cabinStageCounts[cabinType] ?? 0) + 1;
      final attitude = (payload['selected_attitude'] ?? payload['attitude'] ?? '').toString();
      if (attitude.isNotEmpty) attitudeCounts[attitude] = (attitudeCounts[attitude] ?? 0) + 1;
      final decision = (payload['quick_decision'] ?? payload['decision_label'] ?? '').toString();
      if (decision.isNotEmpty) impactDecisionCounts[decision] = (impactDecisionCounts[decision] ?? 0) + 1;
    }

    return {
      'attitudes': attitudeCounts,
      'impact_decisions': impactDecisionCounts,
      'stages': stageCounts,
      'cabin_stage_counts': cabinStageCounts,
    };
  }

  Future<ConceptWorldProfile> getWorldProfile() async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query('ce_world_profile', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return ConceptWorldProfile.initial();
    return ConceptWorldProfile.fromMap(rows.first);
  }

  Future<List<ConceptWorldZoneState>> listWorldZones() async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query('ce_world_zone_state', orderBy: 'CASE zone_id WHEN "work" THEN 1 WHEN "life" THEN 2 ELSE 3 END');
    return rows.map(ConceptWorldZoneState.fromMap).toList();
  }

  Future<ConceptWorldMapData> getWorldMapData() async {
    final profile = await getWorldProfile();
    final zones = await listWorldZones();
    return ConceptWorldMapData(profile: profile, zones: zones);
  }

  Future<void> _saveZoneState(ConceptWorldZoneState state) async {
    final db = await AppDatabase.instance();
    await db.insert('ce_world_zone_state', state.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ConceptWorldRewardResult> applyReplayReward({
    required ReplayResult replay,
    required String domain,
    required String sceneTitle,
    String? zoneId,
  }) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final current = await getWorldProfile();
    final zones = {for (final z in await listWorldZones()) z.zoneId: z};
    final resolvedZoneId = zoneId ?? conceptWorldZoneIdForDomain(domain);
    final currentZone = zones[resolvedZoneId] ?? ConceptWorldZoneState.initial(resolvedZoneId, unlocked: resolvedZoneId == 'work');
    final isSuccess = replay.resultLabel.contains('成功');
    int xpGain = 12 + (replay.totalScore ~/ 8);
    if (isSuccess) xpGain += 8;
    if (replay.totalScore >= 85) xpGain += 6;
    if (sceneTitle.contains('高压') || sceneTitle.contains('危机')) xpGain += 4;
    xpGain += currentZone.anomalyLevel * 3;

    final achievements = [...current.achievements];
    final unlockedAchievements = <String>[];
    final unlockedZones = <String>[];
    final worldEvents = <String>[];

    void unlockAchievement(String code, String label) {
      if (!achievements.contains(code)) {
        achievements.add(code);
        unlockedAchievements.add(label);
      }
    }

    if (current.totalRuns == 0) unlockAchievement('first_mission', '首次闯关');
    if (replay.totalScore >= 80) unlockAchievement('score_80', '高分通关');
    if (isSuccess && domain.contains('团队')) unlockAchievement('team_command', '团队协同者');
    if (isSuccess && domain.contains('职场')) unlockAchievement('work_command', '职场执行官');
    if (current.streak + (isSuccess ? 1 : 0) >= 3) unlockAchievement('three_streak', '三连胜');

    var zone = currentZone;
    var anomaly = zone.anomalyLevel;
    if (isSuccess) {
      zone = zone.copyWith(clearedCount: zone.clearedCount + 1);
      if (anomaly > 0) {
        anomaly -= 1;
        worldEvents.add('${_zoneTitle(resolvedZoneId)} 的异常波动被压制，危险度下降。');
      }
    } else {
      zone = zone.copyWith(failedCount: zone.failedCount + 1);
      anomaly = anomaly < 3 ? anomaly + 1 : 3;
      worldEvents.add('${_zoneTitle(resolvedZoneId)} 出现新的世界异常，后续关卡危险度上升。');
    }
    if (replay.totalScore < 60 && anomaly < 3) {
      anomaly += 1;
      worldEvents.add('低分结算引发了额外的不稳定余波。');
    }
    zone = zone.copyWith(anomalyLevel: anomaly, updatedAt: DateTime.now());
    await _saveZoneState(zone);

    Future<void> unlockZone(String id, String reason) async {
      final z = zones[id] ?? ConceptWorldZoneState.initial(id);
      if (!z.unlocked) {
        final next = z.copyWith(unlocked: true, updatedAt: DateTime.now());
        zones[id] = next;
        unlockedZones.add(_zoneTitle(id));
        worldEvents.add(reason);
        await _saveZoneState(next);
      }
    }

    final totalRunsAfter = current.totalRuns + 1;
    final successAfter = current.successfulRuns + (isSuccess ? 1 : 0);
    final totalXp = current.totalXp + xpGain;
    final level = 1 + (totalXp ~/ 100);

    if ((zones['work']?.clearedCount ?? 0) + ((resolvedZoneId == 'work' && isSuccess) ? 1 : 0) >= 2 || level >= 2) {
      await unlockZone('life', '你已解锁【关系实验室】。现实关系线开始向你开放。');
      unlockAchievement('unlock_life', '关系实验室解锁');
    }
    if (successAfter >= 3 || level >= 3) {
      await unlockZone('team', '你已解锁【团队指挥塔】。多角色协作训练已开放。');
      unlockAchievement('unlock_team', '团队指挥塔解锁');
    }
    if (zone.anomalyLevel == 0 && currentZone.anomalyLevel >= 2 && isSuccess) {
      unlockAchievement('purify_zone', '异常净化者');
      worldEvents.add('${_zoneTitle(resolvedZoneId)} 的异常已被完全净化。');
    }

    final nextProfile = ConceptWorldProfile(
      totalXp: totalXp,
      level: level,
      totalRuns: totalRunsAfter,
      successfulRuns: successAfter,
      streak: isSuccess ? current.streak + 1 : 0,
      achievements: achievements,
      updatedAt: DateTime.now(),
    );

    await db.update('ce_world_profile', nextProfile.toMap(), where: 'id = 1');
    return ConceptWorldRewardResult(
      profile: nextProfile,
      xpGained: xpGain,
      unlockedAchievements: unlockedAchievements,
      unlockedZones: unlockedZones,
      worldEvents: worldEvents,
      zoneId: resolvedZoneId,
      anomalyLevelAfter: zone.anomalyLevel,
    );
  }


  Future<ActionWorldReward> applyActionExecutionReward({
    required String concept,
    required String domain,
    required int totalSteps,
    required int completedSteps,
    required int frictionCount,
    String? zoneId,
  }) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final current = await getWorldProfile();
    final zones = {for (final z in await listWorldZones()) z.zoneId: z};

    String resolveZone() {
      final c = concept.trim();
      if (c.contains('边界')) return 'life';
      if (c.contains('自律')) return 'team';
      return zoneId ?? conceptWorldZoneIdForDomain(domain);
    }

    final resolvedZoneId = resolveZone();
    final currentZone = zones[resolvedZoneId] ?? ConceptWorldZoneState.initial(resolvedZoneId, unlocked: resolvedZoneId == 'work');
    final success = totalSteps > 0 && completedSteps >= totalSteps;
    int xpGain = 4 + (completedSteps * 4);
    if (success) xpGain += 8;
    xpGain -= frictionCount;
    if (xpGain < 4) xpGain = 4;

    final achievements = [...current.achievements];
    final unlockedAchievements = <String>[];
    final unlockedZones = <String>[];
    final worldEvents = <String>[];

    void unlockAchievement(String code, String label) {
      if (!achievements.contains(code)) {
        achievements.add(code);
        unlockedAchievements.add(label);
      }
    }

    if (current.totalRuns == 0) unlockAchievement('action_first_run', '首次行动');
    if (success) unlockAchievement('action_complete_once', '完整执行者');
    if (frictionCount == 0 && success) unlockAchievement('action_smooth_run', '顺畅推进');
    if (current.streak + (success ? 1 : 0) >= 3) unlockAchievement('action_three_streak', '行动三连胜');

    var zone = currentZone;
    var anomaly = zone.anomalyLevel;
    if (success) {
      zone = zone.copyWith(clearedCount: zone.clearedCount + 1);
      if (anomaly > 0) {
        anomaly -= 1;
        worldEvents.add('${_zoneTitle(resolvedZoneId)} 的异常被你的持续行动压低。');
      } else {
        worldEvents.add('${_zoneTitle(resolvedZoneId)} 因为一次完整行动而更加稳定。');
      }
    } else {
      zone = zone.copyWith(failedCount: zone.failedCount + 1);
      if (frictionCount > 0 && anomaly < 3) anomaly += 1;
      worldEvents.add('${_zoneTitle(resolvedZoneId)} 记录到一次未完成行动。');
    }
    zone = zone.copyWith(anomalyLevel: anomaly, updatedAt: DateTime.now());
    await _saveZoneState(zone);

    Future<void> unlockZone(String id, String reason) async {
      final z = zones[id] ?? ConceptWorldZoneState.initial(id);
      if (!z.unlocked) {
        final next = z.copyWith(unlocked: true, updatedAt: DateTime.now());
        zones[id] = next;
        unlockedZones.add(_zoneTitle(id));
        worldEvents.add(reason);
        await _saveZoneState(next);
      }
    }

    final totalRunsAfter = current.totalRuns + 1;
    final successAfter = current.successfulRuns + (success ? 1 : 0);
    final totalXp = current.totalXp + xpGain;
    final level = 1 + (totalXp ~/ 100);

    if ((zones['work']?.clearedCount ?? 0) + ((resolvedZoneId == 'work' && success) ? 1 : 0) >= 2 || level >= 2) {
      await unlockZone('life', '你已解锁【关系实验室】。边界与关系类行动开始开放。');
    }
    if ((zones['life']?.clearedCount ?? 0) + ((resolvedZoneId == 'life' && success) ? 1 : 0) >= 2 || level >= 3) {
      await unlockZone('team', '你已解锁【团队指挥塔】。更复杂的协作行动开始开放。');
    }

    final nextProfile = ConceptWorldProfile(
      totalXp: totalXp,
      level: level,
      totalRuns: totalRunsAfter,
      successfulRuns: successAfter,
      streak: success ? current.streak + 1 : 0,
      achievements: achievements,
      updatedAt: DateTime.now(),
    );
    await db.update('ce_world_profile', nextProfile.toMap(), where: 'id = 1');

    return ActionWorldReward(
      xpGained: xpGain,
      levelAfter: nextProfile.level,
      streakAfter: nextProfile.streak,
      zoneId: resolvedZoneId,
      anomalyLevelAfter: zone.anomalyLevel,
      unlockedAchievements: unlockedAchievements,
      unlockedZones: unlockedZones,
      worldEvents: worldEvents,
    );
  }

  String _zoneTitle(String zoneId) {
    switch (zoneId) {
      case 'life':
        return '关系实验室';
      case 'team':
        return '团队指挥塔';
      default:
        return '职场训练基地';
    }
  }
}
