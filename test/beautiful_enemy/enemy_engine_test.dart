import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/beautiful_enemy/src/data/enemy_dao.dart';
import 'package:quote_app/beautiful_enemy/src/data/models.dart';
import 'package:quote_app/beautiful_enemy/src/domain/digest_builder.dart';
import 'package:quote_app/beautiful_enemy/src/domain/enemy_engine.dart';
import 'package:quote_app/beautiful_enemy/src/domain/evidence_source.dart';
import 'package:quote_app/beautiful_enemy/src/enemy_oracle.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeSource implements EvidenceSource {
  FakeSource(this.build);

  final List<EventDraft> Function(int sinceMs) build;

  @override
  String get id => 'habit';

  @override
  String get label => '习惯';

  @override
  Future<List<EventDraft>> collect(Database db, int sinceMs) async => build(sinceMs);
}

class FakeOracle implements EnemyOracle {
  FakeOracle(this.build);

  final EnemyDraft? Function(Map<String, dynamic> digest, int nowMs) build;
  int calls = 0;

  @override
  Future<EnemyDraft?> judge({
    required Map<String, dynamic> digest,
    required int intensity,
    required int nowMs,
  }) async {
    calls++;
    return build(digest, nowMs);
  }
}

EnemyDraft goodDraft(
  Map<String, dynamic> digest,
  int now, {
  String charge = '习惯 1 项未完成，日志里写着「晨跑」。',
}) {
  return EnemyDraft(
    charge: charge,
    evidenceIds: (digest['evidence_ids'] as List<dynamic>).cast<int>().take(1).toList(),
    toneLevel: 2,
    lessonHint: '',
    action: '现在去跑 15 分钟',
    actionDueMs: now + const Duration(hours: 2).inMilliseconds,
    appealPrompt: '拿证据来',
  );
}

EventDraft habitMissed(int nowMs, {int id = 1}) => EventDraft(
      ts: nowMs - const Duration(hours: 1).inMilliseconds,
      source: 'habit',
      type: 'habit_missed',
      dedupeKey: 'habit:$id:missed',
      payload: <String, dynamic>{
        'subject': 'preset:$id',
        'label': '晨跑',
        'day': '2026-09-30',
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  // 2026-09-30 是周三：不是休战日，也不在静默时段。
  final DateTime wednesday = DateTime(2026, 9, 30, 15);

  late Database db;
  late EnemyDao dao;
  late DateTime current;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = EnemyDao(db);
    await dao.ensureSchema();
    current = wednesday;
  });

  tearDown(() async {
    await db.close();
  });

  EnemyEngine makeEngine({EnemyOracle? oracle, bool withSource = true}) {
    return EnemyEngine(
      dao: dao,
      oracle: oracle ?? const LocalFactOracle(),
      sources: withSource
          ? <EvidenceSource>[
              FakeSource((int since) => <EventDraft>[
                    habitMissed(current.millisecondsSinceEpoch),
                  ]),
            ]
          : const <EvidenceSource>[],
      clock: () => current,
    );
  }

  group('证据采集', () {
    test('没授权的来源不采集；授权后采集一次，重复同步不重复入库', () async {
      final EnemyEngine e = makeEngine();
      expect(await e.sync(), 0);
      await e.grantAll();
      expect(await e.sync(), 1);
      expect(await e.sync(), 0);
      expect(await dao.eventCount(), 1);
    });

    test('来源抛异常不会拖垮同步', () async {
      final EnemyEngine e = EnemyEngine(
        dao: dao,
        oracle: const LocalFactOracle(),
        sources: <EvidenceSource>[
          FakeSource((int since) => throw StateError('boom')),
        ],
        clock: () => current,
      );
      await e.grantAll();
      expect(await e.sync(), 0);
    });
  });

  group('摘要', () {
    test('同一项同一天只认最后一次状态', () {
      final int now = wednesday.millisecondsSinceEpoch;
      EnemyEvent ev(int id, String type, int offsetMin) => EnemyEvent(
            id: id,
            ts: now - offsetMin * 60000,
            source: 'habit',
            type: type,
            payload: const <String, dynamic>{
              'subject': 'preset:1',
              'label': '晨跑',
              'day': '2026-09-30',
            },
          );
      final EnemyDigest d = DigestBuilder.build(
        nowMs: now,
        windowMs: const Duration(hours: 24).inMilliseconds,
        intensity: 2,
        events: <EnemyEvent>[ev(1, 'habit_missed', 60), ev(2, 'habit_done', 10)],
        weekCommitments: const <EnemyCommitment>[],
        recentVerdicts: const <EnemyVerdict>[],
        lessons: const <EnemyLesson>[],
      );
      final Map<String, dynamic> habits = d.json['habits'] as Map<String, dynamic>;
      expect(habits['done'], 1);
      expect(habits['missed'], 0);
    });

    test('没有任何证据就是不足', () {
      final EnemyDigest d = DigestBuilder.build(
        nowMs: wednesday.millisecondsSinceEpoch,
        windowMs: const Duration(hours: 24).inMilliseconds,
        intensity: 2,
        events: const <EnemyEvent>[],
        weekCommitments: const <EnemyCommitment>[],
        recentVerdicts: const <EnemyVerdict>[],
        lessons: const <EnemyLesson>[],
      );
      expect(d.sufficient, isFalse);
    });
  });

  group('开庭', () {
    test('证据不足时不生成判词', () async {
      final EnemyEngine e = makeEngine(withSource: false);
      final EnemyOutcome o = await e.judge(manual: true);
      expect(o.kind, EnemyOutcomeKind.insufficient);
      expect(await dao.latestVerdict(), isNull);
    });

    test('合规的模型判词被保存，动作自动成为承诺', () async {
      final FakeOracle oracle = FakeOracle(
        (Map<String, dynamic> d, int now) => goodDraft(d, now),
      );
      final EnemyEngine e = makeEngine(oracle: oracle);
      await e.grantAll();
      final EnemyOutcome o = await e.judge(manual: true);
      expect(o.kind, EnemyOutcomeKind.verdict);
      final EnemyVerdict v = o.verdict!;
      expect(v.factOnly, isFalse);
      expect(v.evidenceIds, isNotEmpty);
      final EnemyCommitment? c = await dao.commitment(v.commitmentId!);
      expect(c, isNotNull);
      expect(c!.origin, 'verdict');
      expect(c.status, CommitmentStatus.open);
    });

    test('违规输出最多重试两次，然后降级成事实播报', () async {
      final FakeOracle oracle = FakeOracle(
        (Map<String, dynamic> d, int now) =>
            goodDraft(d, now, charge: '你就是个废物，习惯 1 项没做'),
      );
      final EnemyEngine e = makeEngine(oracle: oracle);
      await e.grantAll();
      final EnemyOutcome o = await e.judge(manual: true);
      expect(oracle.calls, 3);
      expect(o.verdict!.factOnly, isTrue);
      expect(o.verdict!.intensity, 0);
      expect(o.verdict!.charge, isNot(contains('废物')));
    });

    test('模型没产出就不重试，直接降级', () async {
      final FakeOracle oracle = FakeOracle((Map<String, dynamic> d, int now) => null);
      final EnemyEngine e = makeEngine(oracle: oracle);
      await e.grantAll();
      final EnemyOutcome o = await e.judge(manual: true);
      expect(oracle.calls, 1);
      expect(o.verdict!.factOnly, isTrue);
    });

    test('模型引用了摘要里没有的证据会被拒绝', () async {
      final FakeOracle oracle = FakeOracle(
        (Map<String, dynamic> d, int now) => EnemyDraft(
          charge: '习惯 1 项未完成。',
          evidenceIds: const <int>[9999],
          toneLevel: 2,
          lessonHint: '',
          action: '现在去跑 15 分钟',
          actionDueMs: now + const Duration(hours: 2).inMilliseconds,
          appealPrompt: '',
        ),
      );
      final EnemyEngine e = makeEngine(oracle: oracle);
      await e.grantAll();
      final EnemyOutcome o = await e.judge(manual: true);
      expect(o.verdict!.factOnly, isTrue);
    });

    test('休战日只报事实，不调模型', () async {
      current = DateTime(2026, 10, 3, 15); // 周六
      final FakeOracle oracle = FakeOracle(
        (Map<String, dynamic> d, int now) => goodDraft(d, now),
      );
      final EnemyEngine e = makeEngine(oracle: oracle);
      await e.grantAll();
      final EnemyOutcome o = await e.judge(manual: true);
      expect(oracle.calls, 0);
      expect(o.verdict!.factOnly, isTrue);
    });

    test('静默时段和每日上限只拦自动开庭，手动开庭不受限', () async {
      final FakeOracle oracle = FakeOracle(
        (Map<String, dynamic> d, int now) => goodDraft(d, now),
      );
      final EnemyEngine e = makeEngine(oracle: oracle);
      await e.grantAll();

      current = DateTime(2026, 9, 30, 23, 30);
      expect((await e.judge()).reason, 'quiet');

      current = wednesday;
      for (int i = 0; i < 3; i++) {
        expect((await e.judge()).kind, EnemyOutcomeKind.verdict);
      }
      expect((await e.judge()).reason, 'cap');
      expect((await e.judge(manual: true)).kind, EnemyOutcomeKind.verdict);
    });
  });

  group('闭环', () {
    Future<EnemyVerdict> firstVerdict(EnemyEngine e) async {
      await e.grantAll();
      return (await e.judge(manual: true)).verdict!;
    }

    test('兑现：认账，判词记为完成', () async {
      final EnemyEngine e = makeEngine(
        oracle: FakeOracle((Map<String, dynamic> d, int now) => goodDraft(d, now)),
      );
      final EnemyVerdict v = await firstVerdict(e);
      final String? msg = await e.complete(v.commitmentId!);
      expect(msg, startsWith('认账'));
      expect((await dao.verdict(v.id))!.outcome, 'done');
    });

    test('到期没兑现：承诺失效，判词记为失败', () async {
      final EnemyEngine e = makeEngine(
        oracle: FakeOracle((Map<String, dynamic> d, int now) => goodDraft(d, now)),
      );
      final EnemyVerdict v = await firstVerdict(e);
      current = wednesday.add(const Duration(hours: 3));
      expect(await e.settleOverdue(), 1);
      expect((await dao.commitment(v.commitmentId!))!.status, CommitmentStatus.missed);
      expect((await dao.verdict(v.id))!.outcome, 'missed');
      final List<EnemyEvent> events = await dao.eventsBetween(0, 1 << 50, source: 'commitment');
      expect(events.map((EnemyEvent e) => e.type), contains('commitment_missed'));
    });

    test('归因不收空话；同类别再次失败只累加次数', () async {
      final EnemyEngine e = makeEngine(withSource: false);
      final int id = (await e.addCommitment('译完第九节')).id!;

      final r1 = await e.attribute(commitmentId: id, category: '拖延', reason: '忙');
      expect(r1.ok, isFalse);
      final r2 = await e.attribute(commitmentId: id, category: '拖延', reason: '太忙了');
      expect(r2.ok, isFalse);

      final r3 = await e.attribute(
        commitmentId: id,
        category: '拖延',
        reason: '晚上先调了两小时壁纸，一直没碰这件事',
      );
      expect(r3.ok, isTrue);
      expect(r3.lesson!.timesRepeated, 1);

      final r4 = await e.attribute(
        commitmentId: id,
        category: '拖延',
        reason: '又是先刷了知识卡片才想起来',
      );
      expect(r4.lesson!.timesRepeated, 2);
      expect((await dao.lessons()).length, 1);
    });

    test('申辩要写理由；成立的记为豁免；每周额度用完后照记', () async {
      final EnemyEngine e = makeEngine(
        oracle: FakeOracle((Map<String, dynamic> d, int now) => goodDraft(d, now)),
      );
      await e.grantAll();
      final List<EnemyVerdict> vs = <EnemyVerdict>[];
      for (int i = 0; i < 3; i++) {
        vs.add((await e.judge(manual: true)).verdict!);
      }

      expect((await e.appeal(vs[0].id, '  ')).kind, ResponseKind.needsText);
      expect((await e.appeal(vs[0].id, '那天临时出差，没带电脑')).kind, ResponseKind.appealAccepted);
      expect((await dao.verdict(vs[0].id))!.outcome, 'excused');
      expect((await dao.commitment(vs[0].commitmentId!))!.status, CommitmentStatus.excused);

      expect((await e.appeal(vs[1].id, '身体不舒服去了医院')).kind, ResponseKind.appealAccepted);
      expect((await e.appeal(vs[2].id, '今天又有事')).kind, ResponseKind.appealQuotaExceeded);
      expect((await dao.verdict(vs[2].id))!.outcome, isNot('excused'));
    });
  });

  group('安全阀', () {
    test('申辩里出现危机表达：立刻静音，不当作申辩处理', () async {
      final EnemyEngine e = makeEngine(
        oracle: FakeOracle((Map<String, dynamic> d, int now) => goodDraft(d, now)),
      );
      await e.grantAll();
      final EnemyVerdict v = (await e.judge(manual: true)).verdict!;

      final ResponseResult r = await e.appeal(v.id, '我真的撑不住了');
      expect(r.kind, ResponseKind.crisis);
      expect(r.message, contains('联系'));
      expect(await e.isMuted(), isTrue);
      expect(await dao.boolSetting(EnemySettings.crisisNoticePending), isTrue);
      expect((await dao.verdict(v.id))!.outcome, isNot('excused'));

      // 静音对手动开庭同样生效。
      expect((await e.judge(manual: true)).reason, 'muted');

      await e.unmute();
      expect(await e.isMuted(), isFalse);
      expect(await dao.boolSetting(EnemySettings.crisisNoticePending), isFalse);
    });

    test('立承诺、写归因时出现危机表达同样静音，且不入库', () async {
      final EnemyEngine e = makeEngine(withSource: false);
      final r = await e.addCommitment('我不想活了');
      expect(r.crisis, isTrue);
      expect(r.id, isNull);
      expect(await dao.commitments(), isEmpty);
      expect(await e.isMuted(), isTrue);
    });

    test('只说「停战」：静音，但不显示危机文案', () async {
      final EnemyEngine e = makeEngine(withSource: false);
      await e.truce();
      expect(await e.isMuted(), isTrue);
      expect(await dao.boolSetting(EnemySettings.crisisNoticePending), isFalse);
    });

    test('点了「太过了」之后实际档位下降', () async {
      final EnemyEngine e = makeEngine(withSource: false);
      await dao.setSetting(EnemySettings.intensity, '3');
      expect(await e.effectiveIntensity(), 3);
      await e.markTooMuch();
      expect(await e.effectiveIntensity(), 2);
      // 四天后是周日：过了 72 小时窗口，也不是周六休战日。
      current = wednesday.add(const Duration(days: 4));
      expect(await e.effectiveIntensity(), 3);
    });

    test('连续三条判词过了一天都没回应：降一档', () async {
      final EnemyEngine e = makeEngine(
        oracle: FakeOracle((Map<String, dynamic> d, int now) => goodDraft(d, now)),
      );
      await dao.setSetting(EnemySettings.intensity, '3');
      await e.grantAll();
      for (int i = 0; i < 3; i++) {
        await e.judge(manual: true);
      }
      current = wednesday.add(const Duration(hours: 30));
      expect(await e.effectiveIntensity(), 2);
    });
  });

  group('每周审判', () {
    test('本周没有数据时不给百分比', () async {
      final EnemyEngine e = makeEngine(withSource: false);
      final WeeklyReview r = await e.weeklyReview();
      expect(r.commitmentRate, isNull);
      expect(r.verdictActRate, isNull);
      expect(r.focus, contains('下周唯一重点'));
    });

    test('统计兑现率，并把最常见的失败类别作为下周重点', () async {
      final EnemyEngine e = makeEngine(withSource: false);
      final int a = (await e.addCommitment('A', due: current.add(const Duration(hours: 1)))).id!;
      final int b = (await e.addCommitment('B', due: current.add(const Duration(hours: 1)))).id!;
      await e.complete(a);
      await e.attribute(
        commitmentId: b,
        category: '目标太大',
        reason: '一上来就想译完整章，第一步都没定义',
      );
      current = wednesday.add(const Duration(hours: 2));
      await e.settleOverdue();
      final WeeklyReview r = await e.weeklyReview();
      expect(r.commitmentsDone, 1);
      expect(r.commitmentsMissed, 1);
      expect(r.commitmentRate, 50);
      expect(r.topFailures.first.category, '目标太大');
      expect(r.focus, contains('目标太大'));
    });
  });
}
