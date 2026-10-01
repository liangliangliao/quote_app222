import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/beautiful_enemy/beautiful_enemy.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_ai_oracle.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_ai_talker.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_sources.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 宿主装配层的测试：来源读宿主的表，模型输出只被解析、不被信任。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  const int now = 1790000000000; // 固定时刻，避免测试依赖真实时钟。

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> createHostTables() async {
    await db.execute('''CREATE TABLE behavior_observation_presets (
      id INTEGER PRIMARY KEY AUTOINCREMENT, created_at_ms INTEGER NOT NULL,
      updated_at_ms INTEGER NOT NULL, name TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE behavior_observation_preset_checkins (
      id INTEGER PRIMARY KEY AUTOINCREMENT, preset_id INTEGER NOT NULL,
      check_date_ms INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'pending',
      missed_reason TEXT, reviewed_at_ms INTEGER,
      created_at_ms INTEGER NOT NULL, updated_at_ms INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE behavior_tracking_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT, created_at_ms INTEGER NOT NULL,
      updated_at_ms INTEGER NOT NULL, record_date_ms INTEGER NOT NULL,
      title TEXT, source TEXT)''');
    await db.execute('''CREATE TABLE k_item (
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE k_burn (
      id INTEGER PRIMARY KEY AUTOINCREMENT, item_id INTEGER NOT NULL,
      started_at INTEGER NOT NULL, seconds INTEGER NOT NULL,
      want_more INTEGER, aborted INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE evidence_growth_knowledge_transforms (
      transform_id INTEGER PRIMARY KEY AUTOINCREMENT, node_title TEXT,
      created_at_ms INTEGER NOT NULL)''');
  }

  group('证据来源', () {
    test('宿主的表还不存在时，所有来源都返回空而不是抛', () async {
      for (final EvidenceSource s in defaultEnemySources()) {
        expect(await s.collect(db, 0), isEmpty, reason: s.id);
      }
    });

    test('打卡只取 done / missed / skipped，pending 不算证据', () async {
      await createHostTables();
      await db.insert('behavior_observation_presets',
          <String, Object?>{'id': 1, 'created_at_ms': 0, 'updated_at_ms': 0, 'name': '晨跑'});
      for (final String status in <String>['done', 'missed', 'skipped', 'pending']) {
        await db.insert('behavior_observation_preset_checkins', <String, Object?>{
          'preset_id': 1,
          'check_date_ms': now + status.length,
          'status': status,
          'created_at_ms': now,
          'updated_at_ms': now,
        });
      }
      final List<EventDraft> drafts = await const HabitEvidenceSource().collect(db, 0);
      expect(drafts.map((EventDraft d) => d.type).toSet(),
          <String>{'habit_done', 'habit_missed', 'habit_skipped'});
      expect(drafts.every((EventDraft d) => d.payload['label'] == '晨跑'), isTrue);
    });

    test('行为记录不含预设打卡生成的和 AI 每日总结', () async {
      await createHostTables();
      Future<void> rec(String title, String? source) => db.insert(
            'behavior_tracking_records',
            <String, Object?>{
              'created_at_ms': now,
              'updated_at_ms': now,
              'record_date_ms': now,
              'title': title,
              'source': source,
            },
          );
      await rec('手动记录', 'manual');
      await rec('没有来源', null);
      await rec('打卡生成', 'planned_behavior');
      await rec('AI 总结', 'auto_daily_summary');
      final List<EventDraft> drafts = await const JournalEvidenceSource().collect(db, 0);
      expect(drafts.map((EventDraft d) => d.payload['label']).toSet(), <Object?>{'手动记录', '没有来源'});
    });

    test('火种区分完成和中途退出，并带上分钟数', () async {
      await createHostTables();
      await db.insert('k_item', <String, Object?>{'id': 1, 'title': '译完第九节'});
      await db.insert('k_burn', <String, Object?>{
        'item_id': 1, 'started_at': now, 'seconds': 900, 'aborted': 0,
      });
      await db.insert('k_burn', <String, Object?>{
        'item_id': 1, 'started_at': now + 1, 'seconds': 120, 'aborted': 1,
      });
      final List<EventDraft> drafts = await const KindlingEvidenceSource().collect(db, 0);
      expect(drafts.map((EventDraft d) => d.type).toSet(),
          <String>{'kindling_completed', 'kindling_aborted'});
      final EventDraft done = drafts.firstWhere((EventDraft d) => d.type == 'kindling_completed');
      expect(done.payload['minutes'], 15);
    });

    test('重复采集产出同样的 dedupeKey', () async {
      await createHostTables();
      await db.insert('k_item', <String, Object?>{'id': 1, 'title': 'x'});
      await db.insert('k_burn', <String, Object?>{
        'item_id': 1, 'started_at': now, 'seconds': 900, 'aborted': 0,
      });
      final List<EventDraft> a = await const KindlingEvidenceSource().collect(db, 0);
      final List<EventDraft> b = await const KindlingEvidenceSource().collect(db, 0);
      expect(a.single.dedupeKey, b.single.dedupeKey);
    });

    test('端到端：授权后同步进案卷，开庭得到带证据的事实播报', () async {
      await createHostTables();
      // 固定在周三下午：不是休战日，也不在静默时段。
      final DateTime clockNow = DateTime(2026, 9, 30, 15);
      final int justNow = clockNow.millisecondsSinceEpoch - 60000;
      await db.insert('behavior_observation_presets',
          <String, Object?>{'id': 1, 'created_at_ms': 0, 'updated_at_ms': 0, 'name': '晨跑'});
      await db.insert('behavior_observation_preset_checkins', <String, Object?>{
        'preset_id': 1,
        'check_date_ms': justNow,
        'status': 'missed',
        'reviewed_at_ms': justNow,
        'created_at_ms': justNow,
        'updated_at_ms': justNow,
      });
      final EnemyEngine engine = await EnemyEntry.buildEngine(
        db: db,
        sources: defaultEnemySources(),
        clock: () => clockNow,
      );

      // 没授权：敌人什么都看不到。
      expect(await engine.sync(), 0);
      expect((await engine.judge(manual: true)).kind, EnemyOutcomeKind.insufficient);

      await engine.grantAll();
      expect(await engine.sync(), 1);
      final EnemyOutcome o = await engine.judge(manual: true);
      expect(o.kind, EnemyOutcomeKind.verdict);
      expect(o.verdict!.factOnly, isTrue);
      expect(o.verdict!.evidenceIds, isNotEmpty);
      expect(o.verdict!.charge, contains('未完成 1'));
    });
  });

  group('AI 判词解析', () {
    test('解析标准 JSON，包括被代码围栏包着的', () {
      final EnemyDraft? d = EnemyAiOracle.parse(
        '```json\n{"charge":"承诺 3 条失效 2 条","evidence_ids":[4,5],"tone_level":2,'
        '"lesson_hint":"","action":"现在补做第一条","action_due":"2026-09-30T18:00:00",'
        '"appeal_prompt":"拿证据来"}\n```',
        nowMs: DateTime(2026, 9, 30, 15).millisecondsSinceEpoch,
        intensity: 2,
      );
      expect(d, isNotNull);
      expect(d!.evidenceIds, <int>[4, 5]);
      expect(d.toneLevel, 2);
      expect(d.actionDueMs, DateTime(2026, 9, 30, 18).millisecondsSinceEpoch);
    });

    test('模型自己说证据不足，或输出不是 JSON，都返回 null', () {
      expect(EnemyAiOracle.parse('{"charge":"证据不足，不评判"}', nowMs: 1, intensity: 2), isNull);
      expect(EnemyAiOracle.parse('我觉得你最近不太行', nowMs: 1, intensity: 2), isNull);
      expect(EnemyAiOracle.parse('{"charge":', nowMs: 1, intensity: 2), isNull);
    });

    test('截止时间缺失或已过期：用默认两小时，不废掉整条判词', () {
      final EnemyDraft? d = EnemyAiOracle.parse(
        '{"charge":"失效 2 条","evidence_ids":[1],"action":"补做","action_due":"2001-01-01T00:00:00"}',
        nowMs: 1000,
        intensity: 2,
      );
      expect(d!.actionDueMs, 1000 + EnemyAiOracle.defaultDue.inMilliseconds);
    });

    test('模型不可用或抛错时返回 null，让引擎降级', () async {
      final EnemyAiOracle off = EnemyAiOracle(
        isAvailable: () async => false,
        call: ({required String prompt, required String systemPrompt, required String purpose}) async =>
            throw StateError('不该被调用'),
      );
      expect(await off.judge(digest: const <String, dynamic>{}, intensity: 2, nowMs: 1), isNull);

      final EnemyAiOracle boom = EnemyAiOracle(
        isAvailable: () async => true,
        call: ({required String prompt, required String systemPrompt, required String purpose}) async =>
            throw Exception('network down'),
      );
      expect(await boom.judge(digest: const <String, dynamic>{}, intensity: 2, nowMs: 1), isNull);
    });

    test('0 档（休战日）不调模型', () async {
      bool called = false;
      final EnemyAiOracle o = EnemyAiOracle(
        isAvailable: () async => true,
        call: ({required String prompt, required String systemPrompt, required String purpose}) async {
          called = true;
          return '{}';
        },
      );
      expect(await o.judge(digest: const <String, dynamic>{}, intensity: 0, nowMs: 1), isNull);
      expect(called, isFalse);
    });

    test('系统提示里写死了铁律和各档边界', () {
      const String p = EnemyAiOracle.systemPrompt;
      expect(p, contains('只评行为不评人'));
      expect(p, contains('无证据不开口'));
      expect(p, contains('不能是人'));
    });
  });

  group('AI 说话（对话 / 插话）', () {
    test('清理模型输出：围栏、角色前缀、旁白、外层引号', () {
      expect(EnemyAiTalker.clean('```\n对手，账在这。\n```'), '对手，账在这。');
      expect(EnemyAiTalker.clean('敌人：对手，账在这。'), '对手，账在这。');
      expect(EnemyAiTalker.clean('美丽的敌人：对手，账在这。'), '对手，账在这。');
      expect(EnemyAiTalker.clean('（冷笑）对手，账在这。'), '对手，账在这。');
      expect(EnemyAiTalker.clean('「对手，账在这。」'), '对手，账在这。');
      expect(EnemyAiTalker.clean('“对手，账在这。”'), '对手，账在这。');
    });

    test('提示里带情境、称呼、强度、证据摘要，历史只取最近几条并截断', () {
      final List<EnemyMessage> history = <EnemyMessage>[
        for (int i = 0; i < 12; i++)
          EnemyMessage(
            id: i,
            ts: i,
            role: i.isEven ? MessageRole.enemy : MessageRole.user,
            kind: 'chat',
            text: 'm$i ${'字' * 100}',
          ),
      ];
      final String prompt = EnemyAiTalker.buildPrompt(
        digest: const <String, dynamic>{'evidence_ids': <int>[7]},
        history: history,
        situation: '刚刚发生了一件事',
        userText: '我做完了',
        intensity: 2,
        address: '老对手',
      );
      expect(prompt, contains('刚刚发生了一件事'));
      expect(prompt, contains('我做完了'));
      expect(prompt, contains('称呼：老对手'));
      expect(prompt, contains('强度：2'));
      expect(prompt, contains('"evidence_ids":[7]'));
      expect(prompt, contains('m11'));
      expect(prompt, isNot(contains('m3 ')));
      expect(prompt, contains('…'));
    });

    test('主动开口时标明「没有用户输入」', () {
      final String prompt = EnemyAiTalker.buildPrompt(
        digest: const <String, dynamic>{},
        history: const <EnemyMessage>[],
        situation: '刚刚发生了一件事',
        userText: '',
        intensity: 2,
        address: '对手',
      );
      expect(prompt, contains('是你主动开口'));
      expect(prompt, contains('还没有'));
    });

    test('模型不可用、抛错或只返回空白：返回 null，让模块用本地台词', () async {
      Future<String> boom({
        required String prompt,
        required String systemPrompt,
        required String purpose,
      }) async =>
          throw Exception('network down');
      Future<String> blank({
        required String prompt,
        required String systemPrompt,
        required String purpose,
      }) async =>
          '  ';
      Future<String?> ask(EnemyAiTalker t) => t.talk(
            digest: const <String, dynamic>{},
            history: const <EnemyMessage>[],
            situation: 's',
            userText: '',
            intensity: 2,
            address: '对手',
            nowMs: 1,
          );
      expect(await ask(EnemyAiTalker(isAvailable: () async => false, call: boom)), isNull);
      expect(await ask(EnemyAiTalker(isAvailable: () async => true, call: boom)), isNull);
      expect(await ask(EnemyAiTalker(isAvailable: () async => true, call: blank)), isNull);
    });

    test('正常返回时清理后交给模块', () async {
      final EnemyAiTalker t = EnemyAiTalker(
        isAvailable: () async => true,
        call: ({required String prompt, required String systemPrompt, required String purpose}) async {
          expect(purpose, 'beautiful_enemy.talk');
          expect(systemPrompt, contains('美丽的敌人'));
          return '敌人：对手，账在这。';
        },
      );
      final String? out = await t.talk(
        digest: const <String, dynamic>{},
        history: const <EnemyMessage>[],
        situation: 's',
        userText: '在吗',
        intensity: 2,
        address: '对手',
        nowMs: 1,
      );
      expect(out, '对手，账在这。');
    });

    test('系统提示写死了人设、铁律和退场条件', () {
      const String p = EnemyAiTalker.systemPrompt;
      expect(p, contains('值得尊重的对手'));
      expect(p, contains('无证据不开口'));
      expect(p, contains('只评行为不评人'));
      expect(p, contains('放下角色'));
    });
  });
}
