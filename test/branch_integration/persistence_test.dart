import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/behavior_tracking/behavior_tracking_dao.dart';
import 'package:quote_app/behavior_tracking/behavior_tracking_models.dart';
import 'package:quote_app/external_data/todo_goal_dao.dart';
import 'package:quote_app/shame_transform/shame_transform_dao.dart';
import 'package:quote_app/shame_transform/shame_transform_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database database;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });
  tearDown(() async => database.close());

  test('existing observation schema migrates; deleted records leave stats and exports', () async {
    await database.execute('''
      CREATE TABLE behavior_tracking_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        record_date_ms INTEGER NOT NULL
      )
    ''');
    final dao = BehaviorTrackingDao(database: () async => database);
    // Model every column present in the previous production schema.
    final previous = BehaviorTrackingRecord.fromMap({
      'record_date_ms': DateTime.now().millisecondsSinceEpoch,
    }).toMap();
    for (final entry in previous.entries) {
      if (['id', 'created_at_ms', 'updated_at_ms', 'record_date_ms'].contains(entry.key)) continue;
      await database.execute('ALTER TABLE behavior_tracking_records ADD COLUMN ${entry.key}');
    }
    await dao.ensureTables(database);
    await dao.ensureTables(database);
    final record = BehaviorTrackingRecord.fromMap({
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      'record_date_ms': DateTime.now().millisecondsSinceEpoch,
      'title': '旧库升级后的记录',
      'behavior': '散步',
      'trigger_text': '午饭后',
      'entry_mode': 'quick_capture',
      'cue_tags_json': '["阳光"]',
    });
    final id = await dao.save(record);
    expect((await dao.recent()).single.title, '旧库升级后的记录');
    expect((await dao.statsOverview()).topTriggers.map((x) => x.label), contains('阳光'));
    await dao.delete(id);
    expect(await dao.recent(), isEmpty);
    expect((await dao.statsOverview()).totalRecords, 0);
    final exported = jsonDecode(await dao.exportJson()) as Map;
    expect(exported['records'], isEmpty);
    expect((await database.query(BehaviorTrackingDao.tableName)).single['deleted_at_ms'], isNotNull);
    await dao.purgeDeleted(olderThan: const Duration(days: 30));
    expect(await database.query(BehaviorTrackingDao.tableName), hasLength(1));
    await database.update(BehaviorTrackingDao.tableName, {
      'deleted_at_ms': DateTime.now().subtract(const Duration(days: 31)).millisecondsSinceEpoch,
    });
    await dao.purgeDeleted();
    expect(await database.query(BehaviorTrackingDao.tableName), isEmpty);
    final freshId = await dao.save(record);
    await dao.delete(freshId);
    await dao.purgeDeleted(olderThan: Duration.zero);
    expect(await database.query(BehaviorTrackingDao.tableName), isEmpty);
  });

  test('care bridge archives and joy survive alongside existing compass data', () async {
    final dao = ShameTransformDao(database: () async => database);
    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.saveEvent(ShameEvent.fromMap({
      'id': 'event', 'created_at': now, 'scene': 'todoGoal',
      'event_fact': '投递岗位', 'compass_primary': '退缩',
    }));
    await dao.saveEvidence(EvidenceItem.fromMap({
      'id': 'evidence', 'created_at': now, 'source_event_id': 'event',
      'action': '投递一次', 'identity_evidence': '我带着紧张行动了',
    }));
    await dao.saveShameNamingRecord(ShameNamingRecord.fromMap({
      'id': 'naming', 'created_at': now, 'primary_name': '被评价的羞耻',
      'source_event_id': 'event',
    }));
    await dao.saveMicroJoy(const MicroJoyRecord(
      id: 'joy', createdAt: 1, moment: '散步看见阳光', source: '散步',
      repeatAction: '午后走两分钟', affectBefore: 1, affectAfter: 3,
      shareable: false,
    ));
    expect((await dao.listMicroJoy()).single.affectAfter, 3);
    expect((await dao.listShameNamingRecords()).single.primaryName, '被评价的羞耻');
    expect((await dao.compassMetrics())['退缩'], 1);
    final dimension = (await dao.selfMap()).firstWhere((x) => x.name == '能力自我');
    expect(dimension.commonCompass, '退缩');
    expect(dimension.evidenceCount, 1);
    expect(dimension.latestPride, '我带着紧张行动了');
  });

  test('ritual checkins count persisted events, preserve edits, and keep RaiseBase tables', () async {
    final dao = TodoGoalDao(database: () async => database);
    await dao.ensureTables(database);
    await dao.ensureTables(database);
    for (final table in ['goal_raisebase_belief_maps', 'goal_raisebase_check_ins']) {
      expect(await database.query(table), isEmpty);
    }
    final id = await dao.saveRitual(
      goalId: 'goal', triggerText: '午饭后', minimumAction: '散步两分钟',
      minimumMinutes: 2, rewardOrRecord: '留一条证据',
      environmentDesign: '把鞋放门口', frictionPlan: '下雨走室内',
    );
    final original = (await dao.listRituals()).single;
    await dao.recordRitualCheckIn(ritual: original, result: 'completed');
    // A second callback may still hold the original snapshot.
    await dao.recordRitualCheckIn(ritual: original, result: 'blocked', note: '下雨');
    var restored = (await dao.listRituals()).single;
    expect(restored.checkInCount, 2);
    expect(restored.completedCheckIns, 1);
    expect(restored.blockedCheckIns, 1);
    expect(restored.stabilityScore, 50);
    await dao.saveRitual(
      ritualId: id, goalId: 'goal', triggerText: '晚饭后',
      minimumAction: '室内走两分钟', minimumMinutes: 2,
      rewardOrRecord: '留一条证据', environmentDesign: '鞋放门口',
      frictionPlan: '下雨走室内',
    );
    restored = (await dao.listRituals()).single;
    expect(restored.createdAtMs, original.createdAtMs);
    expect(restored.checkInCount, 2);
    expect(restored.stabilityScore, 50);
    await dao.addEffortEntry(
      goalId: 'goal', nodeId: 'node', ritualId: id, effortMinutes: 2,
      energyLevel: 'medium', emotionState: 'stable', availableMinutes: 5,
      zoneType: 'stretch', effortType: 'goal', investmentText: '走了两分钟',
      obstacle: '天气', frictionCategory: 'environment', effortContext: 'daily',
      cycleStage: 'review', relationshipQuality: 3, strategyUsed: '室内走',
      smallProgress: '已行动', nextMinimumStep: '明天再走', timeInLearning: '准备替代路线',
      identityEvidence: '我可以调整', gratitudeText: '', joyScore: 2,
      reflectionDepth: 2, strategyChanged: true, painScore: 1, gainScore: 4,
    );
    final effort = (await dao.listEffortEntries()).single;
    expect(effort.nodeId, 'node');
    expect(effort.ritualId, id);
    expect(effort.frictionCategory, 'environment');
    expect(effort.cycleStage, 'review');
    expect(effort.relationshipQuality, 3);
    expect((await dao.getEffortSummary()).lowPainHighGainCount, 1);
  });
}
