import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:quote_app/beautiful_enemy/beautiful_enemy.dart';
import 'package:quote_app/beautiful_enemy/src/data/models.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_sources.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/prp_plugin_host/behavior_adapter.dart';
import 'package:quote_app/prp_plugin_host/enemy_adapter.dart';
import 'package:quote_app/prp_plugin_host/failure_adapter.dart';
import 'package:quote_app/prp_plugin_host/prp_host_impl.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PrpFixture f;
  setUp(() async {
    f = PrpFixture();
    await f.open();
  });
  tearDown(() async {
    await f.close();
  });

  test(
      'adapters treat unused modules as missing evidence without creating tables',
      () async {
    final behavior = PrpBehaviorAdapter(() async => f.db);
    final enemy = PrpEnemyAdapter(() async => f.db);
    expect(await behavior.evidence(f.signal()), isEmpty);
    expect(
        await behavior.recentDays('habit:preset:5', f.clock.now, 30), isEmpty);
    expect(await enemy.evidence(f.signal(subject: 'commitment:1')), isEmpty);
    expect(await enemy.recentDays('commitment:1', f.clock.now, 30), isEmpty);
    expect(
        await f.db
            .rawQuery("SELECT name FROM sqlite_master WHERE type='table'"),
        isEmpty);
  });

  test(
      'host governance reads existing quiet hours and mute, independent of enemy enablement',
      () async {
    final dao = EnemyDao(f.db);
    await dao.ensureSchema();
    await dao.setBoolSetting(EnemySettings.enabled, false);
    await dao.setSetting(EnemySettings.quietStartHour, '22');
    await dao.setSetting(EnemySettings.quietEndHour, '8');
    final adapter = PrpEnemyAdapter(() async => f.db);
    expect((await adapter.governance(DateTime(2026, 11, 4, 23))).quiet, true);
    expect((await adapter.governance(DateTime(2026, 11, 5, 7))).quiet, true);
    expect((await adapter.governance(DateTime(2026, 11, 5, 8))).quiet, false);
    await dao.setSetting(EnemySettings.mutedUntilMs,
        '${f.clock.now.add(const Duration(hours: 24)).millisecondsSinceEpoch}');
    expect((await adapter.governance(f.clock.now)).muted, true);
  });

  test(
      '30 day dots count explicit misses and done; skipped, absent, future stay unknown',
      () async {
    await f.db.execute(
        'CREATE TABLE behavior_observation_preset_checkins (id INTEGER PRIMARY KEY, preset_id INTEGER, check_date_ms INTEGER, status TEXT, missed_reason TEXT)');
    final today = DateTime(2026, 11, 4);
    for (final entry
        in {0: 'missed', 1: 'done', 2: 'skipped', -1: 'missed'}.entries) {
      await f.db.insert('behavior_observation_preset_checkins', {
        'preset_id': 5,
        'check_date_ms':
            today.subtract(Duration(days: entry.key)).millisecondsSinceEpoch,
        'status': entry.value
      });
    }
    final adapter = PrpBehaviorAdapter(() async => f.db);
    final days = await adapter.recentDays('habit:preset:5', f.clock.now, 30);
    expect(days, hasLength(30));
    expect(days.where((d) => d.status == 'missed'), hasLength(1));
    expect(days.where((d) => d.status == 'done'), hasLength(1));
    expect(days.where((d) => d.status == 'unknown'), hasLength(28));
  });

  test(
      'PRP waits for overdue confirmation; disabling restores legacy settlement',
      () async {
    final dao = EnemyDao(f.db);
    await dao.ensureSchema();
    final engine = EnemyEngine(
        dao: dao, oracle: const LocalFactOracle(), clock: f.clock.call);
    await f.enable();
    final result = await engine.addCommitment('打开书读 1 页',
        due: f.clock.now.subtract(const Duration(hours: 1)));
    expect(await engine.settleOverdue(), 0);
    expect((await dao.commitment(result.id!))!.status, CommitmentStatus.open);
    expect(
        await f.db.rawQuery(
            "SELECT name FROM sqlite_master WHERE name='prp_session'"),
        isEmpty);
    await engine.markMissed(result.id!);
    expect((await dao.commitment(result.id!))!.status, CommitmentStatus.missed);
    final second = await engine.addCommitment('打开书读 2 页',
        due: f.clock.now.subtract(const Duration(hours: 1)));
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(enabled: false));
    expect(await engine.settleOverdue(), 1);
    expect((await dao.commitment(second.id!))!.status, CommitmentStatus.missed);
  });

  test(
      'new commitment links a pending recall, then explicit completion verifies it',
      () async {
    final dao = EnemyDao(f.db);
    await dao.ensureSchema();
    final engine = EnemyEngine(
        dao: dao, oracle: const LocalFactOracle(), clock: f.clock.call);
    await f.enable();
    final lesson = await f.seal();
    await f.runtime.recallFor(const PrpContext(
        surface: PrpSurface.enemy,
        text: '阅读 20 分钟',
        location: 'new_commitment'));
    final result = await engine.addCommitment('阅读 20 分钟',
        due: f.clock.now.add(const Duration(hours: 1)));
    expect((await f.db.query('prp_recall')).single['subject_key'],
        'commitment:${result.id}');
    await engine.complete(result.id!);
    await engine.complete(result.id!);
    expect((await f.runtime.store.lesson(lesson.id))!.verifiedCount, 1);
  });

  test(
      'enemy reads PRP only through explicit per-source consent, and off exports nothing',
      () async {
    await f.enable();
    final lesson = await f.seal();
    final dao = EnemyDao(f.db);
    await dao.ensureSchema();
    final source = PrpEvidenceSource();
    final engine = EnemyEngine(
        dao: dao,
        oracle: const LocalFactOracle(),
        sources: [source],
        clock: f.clock.call);
    expect(await engine.sync(), 0);
    await engine.setConsent('prp', true);
    expect(await engine.sync(), 1);
    final rows = await f.db.query('be_event');
    expect(rows.single['payload'].toString(), isNot(contains(lesson.rule)));
    expect(rows.single['payload'].toString(), contains('verified'));
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(enabled: false));
    expect(await source.collect(f.db, 0), isEmpty);
  });

  Future<PrpFailureAdapter> failureAdapter() async {
    await f.db.execute(
        'CREATE TABLE fp_practice_run (id INTEGER PRIMARY KEY AUTOINCREMENT, task_id TEXT NOT NULL, ts_ms INTEGER NOT NULL, result_json TEXT NOT NULL)');
    await f.db.execute(
        "CREATE TABLE fp_learning_card (id INTEGER PRIMARY KEY AUTOINCREMENT, ts_ms INTEGER NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, tags_json TEXT NOT NULL DEFAULT '[]')");
    return PrpFailureAdapter(() async => f.db, () async {});
  }

  test(
      'failure-module result and learning card are written together and idempotently',
      () async {
    final adapter = await failureAdapter();
    final lesson = f
        .lesson(source: PrpSurface.failureModule)
        .copyWith(id: 11, state: 'sealed', sealedMs: 100);
    await adapter.lessonSealed(lesson, 42);
    await adapter.lessonSealed(lesson, 42);
    expect(await f.db.query('fp_practice_run'), hasLength(1));
    expect(await f.db.query('fp_learning_card'), hasLength(1));
    expect((await f.db.query('fp_learning_card')).single['body'],
        contains(lesson.rule));
    await adapter.lessonSealed(f.lesson(source: PrpSurface.enemy), 43);
    expect(await f.db.query('fp_learning_card'), hasLength(1));
  });

  test('failure-module dual-write rolls both records back if one insert fails',
      () async {
    final adapter = await failureAdapter();
    await f.db.execute(
        "CREATE TRIGGER reject_card BEFORE INSERT ON fp_learning_card BEGIN SELECT RAISE(ABORT, 'injected failure'); END");
    await expectLater(
        adapter.lessonSealed(f.lesson(source: PrpSurface.failureModule), 42),
        throwsA(anything));
    expect(await f.db.query('fp_practice_run'), isEmpty);
    expect(await f.db.query('fp_learning_card'), isEmpty);
    await f.db.execute('DROP TRIGGER reject_card');
    await adapter.lessonSealed(f.lesson(source: PrpSurface.failureModule), 42);
    expect(await f.db.query('fp_practice_run'), hasLength(1));
  });

  test(
      'plugin safety exit mutes the existing enemy persona and stops its voice',
      () async {
    final dao = EnemyDao(f.db);
    await dao.ensureSchema();
    await dao.setSetting(EnemySettings.quietStartHour, '23');
    await dao.setSetting(EnemySettings.dailyCap, '3');
    int stops = 0;
    const channel = MethodChannel('flutter_tts');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'stop') stops++;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final host =
        PrpHostImpl(openDatabase: () async => f.db, clock: f.clock.call);
    await host.safetyExit();
    expect(await dao.boolSetting(EnemySettings.crisisNoticePending), true);
    expect(await dao.intSetting(EnemySettings.mutedUntilMs, 0),
        f.clock.now.add(const Duration(hours: 24)).millisecondsSinceEpoch);
    expect(stops, 1);
    expect(await dao.getSetting(EnemySettings.quietStartHour), '23');
    expect(await dao.getSetting(EnemySettings.dailyCap), '3');
  });
}
