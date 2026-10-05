import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/beautiful_enemy/src/data/enemy_dao.dart';
import 'package:quote_app/beautiful_enemy/src/data/models.dart';
import 'package:quote_app/beautiful_enemy/src/domain/claim_check.dart';
import 'package:quote_app/beautiful_enemy/src/domain/enemy_engine.dart';
import 'package:quote_app/beautiful_enemy/src/domain/enemy_presence.dart';
import 'package:quote_app/beautiful_enemy/src/domain/evidence_source.dart';
import 'package:quote_app/beautiful_enemy/src/domain/guard.dart';
import 'package:quote_app/beautiful_enemy/src/enemy_oracle.dart';
import 'package:quote_app/beautiful_enemy/src/persona.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ProbeSource extends EvidenceSource {
  ProbeSource(this.sourceId, {this.sig});

  final String sourceId;
  String? sig;
  int collects = 0;
  List<EventDraft> drafts = <EventDraft>[];

  @override
  String get id => sourceId;

  @override
  String get label => sourceId;

  @override
  Future<List<EventDraft>> collect(Database db, int sinceMs) async {
    collects++;
    return drafts;
  }

  @override
  Future<String?> watermark(Database db) async => sig;
}

EventDraft event(String type, DateTime at, {int id = 1, String label = '晨跑', String source = 'habit'}) =>
    EventDraft(
      ts: at.millisecondsSinceEpoch,
      source: source,
      type: type,
      dedupeKey: '$type:$id',
      payload: <String, dynamic>{'subject': 's:$id', 'label': label, 'day': '2026-10-01'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late EnemyDao dao;
  late DateTime current;
  late ProbeSource habit;
  late ProbeSource usage;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = EnemyDao(db);
    await dao.ensureSchema();
    current = DateTime(2026, 10, 1, 14); // 周四下午：不是晨报、不是结算、不是休战日
    habit = ProbeSource('habit');
    usage = ProbeSource('usage');
  });

  tearDown(() async {
    await db.close();
  });

  Future<EnemyPresence> make() async {
    final EnemyEngine engine = EnemyEngine(
      dao: dao,
      oracle: const LocalFactOracle(),
      sources: <EvidenceSource>[habit, usage],
      clock: () => current,
    );
    await engine.grantAll();
    return EnemyPresence(engine: engine);
  }

  group('变更指纹', () {
    test('指纹没变就不重新收集；变了才收集', () async {
      final EnemyPresence p = await make();
      habit.sig = 'a';
      await p.engine.syncIfChanged();
      await p.engine.syncIfChanged();
      expect(habit.collects, 1);
      habit.sig = 'b';
      await p.engine.syncIfChanged();
      expect(habit.collects, 2);
    });

    test('来源不提供指纹（null）时每次都收集', () async {
      final EnemyPresence p = await make();
      habit.sig = null;
      await p.engine.syncIfChanged();
      await p.engine.syncIfChanged();
      expect(habit.collects, 2);
    });

    test('没授权的来源既不查指纹也不收集', () async {
      final EnemyPresence p = await make();
      await p.engine.setConsent('habit', false);
      habit.sig = 'a';
      await p.engine.syncIfChanged();
      expect(habit.collects, 0);
    });
  });

  group('使用时长', () {
    test('授权后每分钟累加；没授权不记', () async {
      final EnemyPresence p = await make();
      await p.engine.setConsent('usage', false);
      await p.engine.recordUsageMinute();
      expect((await p.engine.usageToday()), isEmpty);

      await p.engine.setConsent('usage', true);
      await p.engine.recordUsageMinute();
      await p.engine.recordUsageMinute();
      final Map<String, dynamic> u = await p.engine.usageToday();
      expect(u['minutes_today'], 2);
      expect(u['late_night_minutes_today'], 0);
      expect(u['first_open_today'], '14:00');
    });

    test('静默时段内的算深夜使用', () async {
      final EnemyPresence p = await make();
      current = DateTime(2026, 10, 1, 23, 40);
      await p.engine.recordUsageMinute();
      final Map<String, dynamic> u = await p.engine.usageToday();
      expect(u['late_night_minutes_today'], 1);
    });

    test('使用时长进入证据摘要', () async {
      final EnemyPresence p = await make();
      await p.engine.recordUsageMinute();
      final snap = await p.engine.snapshot();
      final Map<String, dynamic> u = snap.digest.json['usage'] as Map<String, dynamic>;
      expect(u['minutes_today'], 1);
    });
  });

  group('核对说法', () {
    test('说做完了但账上没有；账上有；说没时间但在线很久', () {
      final Map<String, dynamic> empty = <String, dynamic>{};
      expect(ClaimCheck.assess('我做完了', empty).kind, ClaimKind.doneWithoutRecord);

      final Map<String, dynamic> withDone = <String, dynamic>{
        'kindling': <String, dynamic>{'completed': 1},
      };
      final ClaimAssessment ok = ClaimCheck.assess('我搞定了', withDone);
      expect(ok.kind, ClaimKind.doneWithRecord);
      expect(ok.records, 1);

      final Map<String, dynamic> online = <String, dynamic>{
        'usage': <String, dynamic>{'minutes_today': 45},
      };
      final ClaimAssessment busy = ClaimCheck.assess('今天太忙了', online);
      expect(busy.kind, ClaimKind.busyButOnline);
      expect(busy.minutes, 45);
      expect(busy.hint, contains('45'));

      expect(ClaimCheck.assess('今天太忙了', <String, dynamic>{
        'usage': <String, dynamic>{'minutes_today': 5},
      }).kind, ClaimKind.none);
      expect(ClaimCheck.assess('你好', empty).kind, ClaimKind.none);
    });

    test('对话里：说做完了、账上没有，敌人当场盘问', () async {
      final EnemyPresence p = await make();
      final SayResult r = await p.say('我今天都做完了');
      expect(r.enemy!.text, contains('没有一条完成记录'));
    });

    test('对话里：说做完了、账上有，敌人核对后认', () async {
      final EnemyPresence p = await make();
      habit.drafts = <EventDraft>[event('habit_done', current.subtract(const Duration(hours: 1)))];
      habit.sig = 'x';
      final SayResult r = await p.say('我做完了');
      expect(r.enemy!.text, contains('1 条完成记录'));
    });

    test('对话里：说没时间，但今天在 App 里待了 45 分钟', () async {
      final EnemyPresence p = await make();
      await dao.setSetting('usage_min_2026-10-01', '45');
      final SayResult r = await p.say('我今天没时间');
      expect(r.enemy!.text, contains('45'));
    });
  });

  group('主动巡查', () {
    test('晨报：早上的第一次巡查自己开口，一天只一次', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(days: 1)));
      current = DateTime(2026, 10, 2, 8);
      final EnemyMessage? m = await p.step();
      expect(m, isNotNull);
      expect(m!.kind, MessageKind.interject);
      expect(m.text, contains('译完第九节'));
      expect(m.text, contains('早'));
      expect(await p.step(), isNull);

      current = DateTime(2026, 10, 3, 8);
      expect(await p.step(), isNotNull);
    });

    test('安静时段不开口；没有账可报也不开口', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(days: 1)));
      current = DateTime(2026, 10, 2, 6, 30);
      expect(await p.step(), isNull);

      final EnemyPresence q = await make();
      await dao.wipeEverything();
      current = DateTime(2026, 10, 3, 8);
      expect(await q.step(), isNull);
    });

    test('晚间结算：到钟点后还有账没平就开口，一天一次', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(days: 1)));
      current = DateTime(2026, 10, 1, 19, 30);
      expect(await p.step(), isNull);

      current = DateTime(2026, 10, 1, 20, 30);
      final EnemyMessage? m = await p.step();
      expect(m, isNotNull);
      expect(m!.text, contains('1 条字据'));
      expect(m.text, contains('译完第九节'));
      expect(await p.step(), isNull);
    });

    test('晚间结算：今天一件完成的事都没有，就算没有字据也要说', () async {
      final EnemyPresence p = await make();
      current = DateTime(2026, 10, 1, 21);
      final EnemyMessage? m = await p.step();
      expect(m, isNotNull);
      expect(m!.text, contains('一件完成的事都没有'));
    });

    test('发呆：人在 App 里 25 分钟、案卷没有新记录、字据还开着', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(hours: 5)));
      final PatrolContext ctx = PatrolContext(
        foreground: true,
        sessionStartMs: current.subtract(const Duration(minutes: 25)).millisecondsSinceEpoch,
      );
      final EnemyMessage? m = await p.step(ctx: ctx);
      expect(m, isNotNull);
      expect(m!.text, contains('25'));
      expect(m.text, contains('译完第九节'));

      // 冷却期内不重复。
      current = current.add(const Duration(minutes: 30));
      final PatrolContext again = PatrolContext(
        foreground: true,
        sessionStartMs: current.subtract(const Duration(minutes: 25)).millisecondsSinceEpoch,
      );
      expect(await p.step(ctx: again), isNull);
    });

    test('发呆：这段时间里有过新记录就不点名；会话太短也不点名；后台没有会话', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(hours: 5)));
      final int start = current.subtract(const Duration(minutes: 25)).millisecondsSinceEpoch;

      habit.drafts = <EventDraft>[event('habit_done', current.subtract(const Duration(minutes: 5)))];
      habit.sig = 'x';
      // 先让游标定下，再让这条事件成为「新事」，由 react 处理掉。
      expect(await p.step(), isNull);
      habit.drafts = <EventDraft>[
        event('habit_done', current.subtract(const Duration(minutes: 5))),
        event('habit_done', current.subtract(const Duration(minutes: 4)), id: 2, label: '读书'),
      ];
      habit.sig = 'y';
      expect(await p.step(), isNotNull);
      current = current.add(const Duration(minutes: 6));
      expect(await p.step(ctx: PatrolContext(foreground: true, sessionStartMs: start)), isNull);

      final EnemyPresence q = await make();
      await dao.wipeEverything();
      await q.engine.addCommitment('译完第九节', due: current.add(const Duration(hours: 5)));
      final int shortStart = current.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch;
      expect(await q.step(ctx: PatrolContext(foreground: true, sessionStartMs: shortStart)), isNull);
      expect(await q.step(), isNull);
    });

    test('开关：主动巡查关掉、实时插话总开关关掉、静音时都不开口', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(days: 1)));
      current = DateTime(2026, 10, 2, 8);

      await dao.setBoolSetting(EnemySettings.patrol, false);
      expect(await p.step(), isNull);
      await dao.setBoolSetting(EnemySettings.patrol, true);

      await dao.setBoolSetting(EnemySettings.interject, false);
      expect(await p.step(), isNull);
      await dao.setBoolSetting(EnemySettings.interject, true);

      await p.engine.muteFor24h(crisis: false);
      expect(await p.step(), isNull);
      await p.engine.unmute();
      expect(await p.step(), isNotNull);
    });

    test('force 只接话，不做主动巡查', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(days: 1)));
      current = DateTime(2026, 10, 2, 8);
      await p.react();
      expect(await p.step(force: true), isNull);
    });

    test('新事件优先：有事件时 step 先接话，不抢着做晨报', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(days: 1)));
      current = DateTime(2026, 10, 2, 8);
      await p.react(); // 定起点
      habit.drafts = <EventDraft>[event('habit_missed', current, id: 7, label: '晨跑')];
      habit.sig = 'z';
      final EnemyMessage? m = await p.step();
      expect(m!.text, contains('晨跑'));
    });
  });

  group('其它模块有动静', () {
    test('字据开着时点出「在忙别处」；没有字据就不吭声', () async {
      final EnemyPresence p = await make();
      await p.react();
      habit.drafts = <EventDraft>[
        event('module_activity', current, id: 5, label: '运动', source: 'activity'),
      ];
      habit.sig = 'a1';
      expect(await p.react(), isNull);

      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(hours: 5)));
      habit.drafts = <EventDraft>[
        event('module_activity', current, id: 5, label: '运动', source: 'activity'),
        event('module_activity', current, id: 6, label: '冥想', source: 'activity'),
      ];
      habit.sig = 'a2';
      final EnemyMessage? m = await p.react();
      expect(m, isNotNull);
      expect(m!.text, contains('译完第九节'));
    });

    test('其它模块的动静进入摘要，并被计成「有记录」', () async {
      final EnemyPresence p = await make();
      habit.drafts = <EventDraft>[
        event('module_activity', current.subtract(const Duration(minutes: 3)),
            id: 1, label: '运动', source: 'activity'),
      ];
      habit.sig = 's';
      await p.engine.sync();
      final snap = await p.engine.snapshot();
      final Map<String, dynamic> activity = snap.digest.json['activity'] as Map<String, dynamic>;
      expect(activity['pulses'], 1);
      expect((activity['modules'] as List<dynamic>).single['label'], '运动');
    });
  });

  group('台词', () {
    test('巡查和核对的台词都过同一套校验', () {
      const DraftValidator v = DraftValidator();
      final List<String> lines = <String>[
        for (int seed = 0; seed < 4; seed++) ...<String>[
          PersonaLines.morningBrief(
            address: '对手',
            open: 2,
            nextText: '译完第九节',
            yesterdayDone: 1,
            yesterdayMissed: 1,
            seed: seed,
          ),
          PersonaLines.eveningLedger(
            address: '对手',
            open: 2,
            nextText: '译完第九节',
            doneToday: 0,
            seed: seed,
          ),
          PersonaLines.stall(address: '对手', minutes: 25, openText: '译完第九节', seed: seed),
          PersonaLines.activity(label: '运动', address: '对手', openText: '译完第九节', seed: seed),
        ],
        PersonaLines.claimNoRecord('对手'),
        PersonaLines.claimBusy('对手', 45),
        PersonaLines.claimConfirmed('对手', 2),
      ];
      for (final String line in lines) {
        expect(v.validateLine(line, maxTone: 1), isEmpty, reason: line);
      }
    });
  });
}
