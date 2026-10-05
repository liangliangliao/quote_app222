import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/beautiful_enemy/src/data/enemy_dao.dart';
import 'package:quote_app/beautiful_enemy/src/data/models.dart';
import 'package:quote_app/beautiful_enemy/src/domain/enemy_engine.dart';
import 'package:quote_app/beautiful_enemy/src/domain/enemy_presence.dart';
import 'package:quote_app/beautiful_enemy/src/domain/evidence_source.dart';
import 'package:quote_app/beautiful_enemy/src/domain/guard.dart';
import 'package:quote_app/beautiful_enemy/src/domain/opposition.dart';
import 'package:quote_app/beautiful_enemy/src/enemy_oracle.dart';
import 'package:quote_app/beautiful_enemy/src/enemy_talker.dart';
import 'package:quote_app/beautiful_enemy/src/persona.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Src extends EvidenceSource {
  Src(this.sourceId);

  final String sourceId;
  List<EventDraft> drafts = <EventDraft>[];
  int version = 0;

  @override
  String get id => sourceId;

  @override
  String get label => sourceId;

  @override
  Future<List<EventDraft>> collect(Database db, int sinceMs) async => drafts;

  @override
  Future<String?> watermark(Database db) async => 'v$version';
}

class RecordingTalker implements EnemyTalker {
  final List<String> situations = <String>[];

  @override
  Future<String?> talk({
    required Map<String, dynamic> digest,
    required List<EnemyMessage> history,
    required String situation,
    required String userText,
    required int intensity,
    required String address,
    required int nowMs,
  }) async {
    situations.add(situation);
    return null;
  }
}

const int hour = 3600 * 1000;
const int day = 24 * hour;

ProbeFacts facts({
  int now = 1000 * day,
  bool kindling = false,
  bool habit = false,
  bool knowledge = false,
  int open = 1,
  int created24 = 1,
  int lastKindling = 0,
  int knowledge24 = 0,
  int actions24 = 0,
  int habit7 = 3,
  List<DormantModule> dormant = const <DormantModule>[],
  EnemyLesson? lesson,
  EnemyVerdict? ignored,
  int rejected7 = 0,
  EnemyMessage? unanswered,
  int follow = 0,
  bool tooLateForMotion = false,
  bool motionAllowed = true,
  Map<String, int> lastProbe = const <String, int>{},
}) {
  return ProbeFacts(
    nowMs: now,
    consentKindling: kindling,
    consentHabit: habit,
    consentKnowledge: knowledge,
    openCommitments: open,
    createdLast24h: created24,
    lastKindlingCompletedMs: lastKindling,
    knowledge24h: knowledge24,
    actions24h: actions24,
    habitEvents7d: habit7,
    dormant: dormant,
    repeatedLesson: lesson,
    ignoredVerdict: ignored,
    rejected7d: rejected7,
    unanswered: unanswered,
    unansweredFollowUps: follow,
    motionDueMs: tooLateForMotion ? 0 : now + 5000,
    motionAllowed: motionAllowed,
    lastProbeMs: lastProbe,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('选质询（纯逻辑）', () {
    test('什么都抓不到也要问：兜底的开放式质询，不是沉默', () {
      final ProbePlan? p = Opposition.choose(facts());
      expect(p, isNotNull);
      expect(p!.type, 'open_question');
      expect(p.motion, isNull);
    });

    test('手里一条字据都没有：质询，并正式提动议（要他亲手写具体内容）', () {
      final ProbePlan p = Opposition.choose(facts(open: 0, created24: 0))!;
      expect(p.type, 'no_commitments');
      expect(p.motion, isNotNull);
      expect(p.motion!.needsText, isTrue);
    });

    test('动议不可用（有未决动议、到上限、或太晚）：只质询，不提动议', () {
      expect(Opposition.choose(facts(open: 0, created24: 0, motionAllowed: false))!.motion, isNull);
      expect(Opposition.choose(facts(open: 0, created24: 0, tooLateForMotion: true))!.motion, isNull);
    });

    test('火种 24 小时没有完整的十五分钟：质询并提动议，动议带核实', () {
      final int now = 1000 * day;
      final ProbePlan p = Opposition.choose(
        facts(now: now, kindling: true, lastKindling: now - 30 * hour),
      )!;
      expect(p.type, 'kindling_absent');
      expect(p.hours, 30);
      expect(p.motion!.verify, 'kindling');
      expect(p.motion!.needsText, isFalse);

      expect(Opposition.choose(facts(now: now, kindling: true, lastKindling: now - 2 * hour))!.type,
          isNot('kindling_absent'));
      expect(Opposition.choose(facts(now: now, kindling: false))!.type, isNot('kindling_absent'));
    });

    test('知识转化了、行动是零：纸上谈兵', () {
      final ProbePlan p = Opposition.choose(facts(knowledge: true, knowledge24: 3, actions24: 0))!;
      expect(p.type, 'knowledge_without_action');
      expect(p.n, 3);
      expect(Opposition.choose(facts(knowledge: true, knowledge24: 3, actions24: 1))!.type,
          isNot('knowledge_without_action'));
    });

    test('沉寂的模块、预设打卡七天零条、驳回成习惯、重复踩坑、判词被无视', () {
      expect(Opposition.choose(facts(dormant: const <DormantModule>[DormantModule('运动', 5)]))!.type,
          'dormant_module');
      expect(Opposition.choose(facts(habit: true, habit7: 0))!.type, 'habit_empty');
      expect(Opposition.choose(facts(rejected7: 2))!.type, 'reject_pattern');
      expect(
        Opposition.choose(facts(
          lesson: const EnemyLesson(
            id: 1,
            verdictId: null,
            category: '拖延',
            reasonText: 'r',
            lesson: '因「拖延」失败：r',
            createdMs: 1,
            timesRepeated: 3,
          ),
        ))!
            .type,
        'lesson_repeat',
      );
      expect(
        Opposition.choose(facts(
          ignored: const EnemyVerdict(
            id: 1,
            ts: 1,
            trigger: 'manual',
            intensity: 2,
            charge: '账',
            evidenceIds: <int>[1],
            lessonHint: '',
            action: 'a',
            actionDueMs: 2,
            appealPrompt: '',
            userResponse: 'pending',
            appealText: '',
            outcome: 'pending',
            outcomeMs: null,
            commitmentId: null,
            factOnly: false,
          ),
        ))!
            .type,
        'ignored_verdict',
      );
    });

    test('没回答的质询：2 小时后追问，最多两次，追问优先于其它', () {
      final int now = 1000 * day;
      final EnemyMessage q = EnemyMessage(
        id: 9,
        ts: now - 3 * hour,
        role: MessageRole.enemy,
        kind: MessageKind.inquiry,
        text: '请回答：你今天最想躲开的那一件事是什么？',
      );
      final ProbePlan p = Opposition.choose(facts(now: now, unanswered: q, open: 0, created24: 0))!;
      expect(p.type, 'unanswered_inquiry');
      expect(p.followUpOf, 9);
      expect(p.hours, 3);

      expect(Opposition.choose(facts(now: now, unanswered: q, follow: 2))!.type,
          isNot('unanswered_inquiry'));
      final EnemyMessage fresh = EnemyMessage(
        id: 10,
        ts: now - hour,
        role: MessageRole.enemy,
        kind: MessageKind.inquiry,
        text: 'q',
      );
      expect(Opposition.choose(facts(now: now, unanswered: fresh))!.type,
          isNot('unanswered_inquiry'));
    });

    test('每一类都有冷却：刚问过就换下一件，全部冷却中则不开口', () {
      final int now = 1000 * day;
      final Map<String, int> all = <String, int>{
        for (final String t in Opposition.cooldownHours.keys) t: now - hour,
      };
      expect(Opposition.choose(facts(now: now, open: 0, created24: 0, lastProbe: all)), isNull);
      final Map<String, int> some = <String, int>{'no_commitments': now - hour};
      expect(Opposition.choose(facts(now: now, open: 0, created24: 0, lastProbe: some))!.type,
          'open_question');
    });

    test('情境里写明了不能编造：账上没有的只说账上没有', () {
      final ProbePlan p = Opposition.choose(facts(open: 0, created24: 0))!;
      expect(p.situation, contains('账上没有'));
      expect(p.situation, contains('不能攻击他这个人'));
    });
  });

  group('台词', () {
    test('质询、动议、反驳、通过：全部过同一套校验，1 档没有粗口', () {
      const DraftValidator v = DraftValidator();
      final List<String> types = Opposition.cooldownHours.keys.toList();
      for (final String type in types) {
        for (int tone = 1; tone <= 3; tone++) {
          for (int seed = 0; seed < 8; seed++) {
            for (final int hours in <int>[0, 5]) {
              final String line = PersonaLines.probe(
                type: type,
                address: '对手',
                tone: tone,
                n: 3,
                m: 1,
                hours: hours,
                days: 5,
                label: '运动',
                text: '请回答：你今天最想躲开的那一件事是什么？',
                category: '拖延',
                seed: seed,
              );
              expect(v.validateLine(line, maxTone: tone), isEmpty, reason: '$type tone=$tone -> $line');
            }
          }
        }
      }
      for (int seed = 0; seed < 4; seed++) {
        expect(
          v.validateLine(
            PersonaLines.motion(address: '对手', text: '完成一次完整的十五分钟火种', dueText: '17:00', tone: 2, seed: seed),
            maxTone: 2,
          ),
          isEmpty,
        );
        expect(
          v.validateLine(PersonaLines.rebut(address: '对手', reason: '今天真的没空，改天吧', seed: seed), maxTone: 1),
          isEmpty,
        );
      }
      expect(
        v.validateLine(
          PersonaLines.motionAccepted(address: '对手', text: '译完第九节', dueText: '17:00', stake: '先做十五分钟火种'),
          maxTone: 1,
        ),
        isEmpty,
      );
    });

    test('质询里带着事实', () {
      expect(PersonaLines.probe(type: 'dormant_module', address: '对手', tone: 1, label: '运动', days: 5),
          allOf(contains('运动'), contains('5')));
      expect(PersonaLines.probe(type: 'kindling_absent', address: '对手', tone: 1, hours: 30),
          contains('30'));
      expect(PersonaLines.probe(type: 'reject_pattern', address: '对手', tone: 1, n: 3, m: 1),
          allOf(contains('3'), contains('1')));
    });
  });

  group('反对党在场：用户一声不响，敌人不跟着安静', () {
    late Database db;
    late EnemyDao dao;
    late DateTime current;
    late Src habit;
    late Src kindling;
    late Src activity;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      dao = EnemyDao(db);
      await dao.ensureSchema();
      current = DateTime(2026, 10, 1, 14); // 周四下午
      habit = Src('habit');
      kindling = Src('kindling');
      activity = Src('activity');
    });

    tearDown(() async {
      await db.close();
    });

    Future<EnemyPresence> make({EnemyTalker? talker, List<Src> sources = const <Src>[]}) async {
      final EnemyEngine engine = EnemyEngine(
        dao: dao,
        oracle: const LocalFactOracle(),
        sources: <EvidenceSource>[habit, kindling, activity, ...sources],
        clock: () => current,
      );
      await engine.grantAll();
      // 这几个来源默认授权后会让很多质询触发；这里按需要逐个关。
      return EnemyPresence(engine: engine, talker: talker);
    }

    /// 敌人上线的第一步：先定下事件起点，紧接着就在同一步里开口质询——它不会等你先动。
    Future<EnemyMessage?> stepAfterBaseline(EnemyPresence p) => p.step();

    test('案卷空空如也、一条字据都没有：它自己开口质询，还提了动议', () async {
      final EnemyPresence p = await make();
      final EnemyMessage? m = await stepAfterBaseline(p);
      expect(m, isNotNull);
      expect(m!.kind, MessageKind.motion);
      final EnemyMotion? mo = await dao.motion(m.refId!);
      expect(mo, isNotNull);
      expect(mo!.isOpen, isTrue);
      expect(mo.needsText, isTrue);
      expect(mo.dueMs, greaterThan(current.millisecondsSinceEpoch));
    });

    test('节奏：间隔没到不再质询；到了就换一件事问；有未决动议时不再提新动议', () async {
      final EnemyPresence p = await make();
      await stepAfterBaseline(p);

      current = current.add(const Duration(minutes: 30));
      expect(await p.step(), isNull);
      expect((await p.status()).lastWhy, 'probe_wait');

      current = current.add(const Duration(minutes: 61));
      final EnemyMessage? second = await p.step();
      expect(second, isNotNull);
      expect(second!.kind, isNot(MessageKind.motion));
      expect((await dao.motionsSince(0)).length, 1);
    });

    test('每日上限：到了就不再质询', () async {
      final EnemyPresence p = await make();
      await dao.setSetting(EnemySettings.probeCap, '1');
      await stepAfterBaseline(p);
      current = current.add(const Duration(hours: 2));
      expect(await p.step(), isNull);
      expect((await p.status()).lastWhy, 'probe_capped');
    });

    test('质询频率可调：改成「密」45 分钟', () async {
      final EnemyPresence p = await make();
      await dao.setSetting(EnemySettings.probeGapMin, '45');
      await stepAfterBaseline(p);
      current = current.add(const Duration(minutes: 50));
      expect(await p.step(), isNotNull);
    });

    test('开关：反对党质询关掉就不质询；静默时段、静音也不', () async {
      final EnemyPresence p = await make();
      await p.step();
      expect(await dao.motionsSince(0), isNotEmpty);
      await dao.setBoolSetting(EnemySettings.opposition, false);
      current = current.add(const Duration(seconds: 25));
      expect(await p.step(), isNull);
      expect((await p.status()).lastWhy, 'opposition_off');
      await dao.setBoolSetting(EnemySettings.opposition, true);

      current = DateTime(2026, 10, 1, 23, 30);
      expect(await p.step(), isNull);
      expect((await p.status()).lastWhy, 'quiet');

      current = DateTime(2026, 10, 2, 10);
      await p.engine.muteFor24h(crisis: false);
      expect(await p.step(), isNull);
      expect((await p.status()).lastWhy, 'muted');
    });

    test('火种质询：提动议；接受后立成带核实的字据', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(days: 1)));
      final EnemyMessage? m = await stepAfterBaseline(p);
      expect(m, isNotNull);
      expect(m!.kind, MessageKind.motion);
      final EnemyMotion mo = (await dao.motion(m.refId!))!;
      expect(mo.kind, 'kindling_absent');
      expect(mo.verify, 'kindling');

      final MotionResult r = await p.acceptMotion(mo.id, stake: '先做十五分钟火种再碰手机');
      expect(r.ok, isTrue);
      expect(r.enemy!.text, contains('字据'));
      final EnemyMotion after = (await dao.motion(mo.id))!;
      expect(after.status, MotionStatus.accepted);
      final EnemyCommitment c = (await dao.commitment(after.commitmentId!))!;
      expect(c.origin, 'motion');
      expect(c.verify, 'kindling');
      expect(c.stake, '先做十五分钟火种再碰手机');
      expect(c.text, '完成一次完整的十五分钟火种');
    });

    test('需要亲手写内容的动议：不写不行；赌注不合规被拒；处理过的不能再处理', () async {
      final EnemyPresence p = await make();
      final EnemyMessage m = (await stepAfterBaseline(p))!;
      final int id = m.refId!;

      expect((await p.acceptMotion(id)).note, contains('具体'));
      final MotionResult bad = await p.acceptMotion(id, text: '译完第九节', stake: '今晚不吃饭');
      expect(bad.ok, isFalse);
      expect(bad.note, EnemyCopy_stake);
      expect((await dao.motion(id))!.isOpen, isTrue);

      final MotionResult ok = await p.acceptMotion(id, text: '译完第九节');
      expect(ok.ok, isTrue);
      expect((await p.acceptMotion(id, text: '再来一次')).note, contains('处理过'));
    });

    test('驳回动议：要给理由，敌人当场反驳，动议状态记下', () async {
      final EnemyPresence p = await make();
      final EnemyMessage m = (await stepAfterBaseline(p))!;
      final int id = m.refId!;

      expect((await p.rejectMotion(id, '不')).note, contains('理由'));
      final MotionResult r = await p.rejectMotion(id, '今天真的没空，改天再说吧');
      expect(r.ok, isTrue);
      expect(r.enemy!.text, contains('今天真的没空'));
      final EnemyMotion mo = (await dao.motion(id))!;
      expect(mo.status, MotionStatus.rejected);
      expect(mo.responseText, '今天真的没空，改天再说吧');
      final List<EnemyMessage> thread = await p.thread();
      expect(thread.any((EnemyMessage x) => x.role == MessageRole.user && x.text.contains('没空')), isTrue);
    });

    test('驳回的理由里出现危机表达：敌人退场、静音，这句话不存储', () async {
      final EnemyPresence p = await make();
      final EnemyMessage m = (await stepAfterBaseline(p))!;
      final MotionResult r = await p.rejectMotion(m.refId!, '我真的撑不住了，不想活了');
      expect(r.crisis, isTrue);
      expect(await p.engine.isMuted(), isTrue);
      final List<EnemyMessage> thread = await p.thread();
      expect(thread.any((EnemyMessage x) => x.text.contains('不想活')), isFalse);
      expect((await dao.motion(m.refId!))!.isOpen, isTrue);
    });

    test('追问：没回答的质询 2 小时后追问，最多两次', () async {
      current = DateTime(2026, 10, 1, 8); // 上午：避开晚间结算和静默时段
      final EnemyPresence p = await make();
      await dao.setSetting(EnemySettings.probeCap, '20');
      await dao.setSetting(EnemySettings.motionCap, '0'); // 只要质询，不要动议
      final EnemyMessage first = (await p.step())!;
      expect(first.kind, MessageKind.inquiry);

      Future<EnemyMessage?> later() async {
        current = current.add(const Duration(hours: 2, minutes: 1));
        return p.step();
      }

      // 追问的台词有两种说法，都带着「没回答」的意思。
      final Matcher asksAgain = anyOf(contains('小时前问过'), contains('没有回答'));
      final EnemyMessage f1 = (await later())!;
      expect(f1.text, asksAgain);
      final EnemyMessage f2 = (await later())!;
      expect(f2.text, asksAgain);
      final EnemyMessage f3 = (await later())!;
      expect(f3.text, isNot(asksAgain));
    });

    test('用户回答之后就不再追问；敌人对话时知道他在回应哪条质询', () async {
      final RecordingTalker talker = RecordingTalker();
      final EnemyPresence p = await make(talker: talker);
      await dao.setSetting(EnemySettings.motionCap, '0');
      final EnemyMessage q = (await p.step())!;
      expect(q.kind, MessageKind.inquiry);

      await p.say('我今天在想怎么把事情拆小');
      expect(talker.situations.last, contains('你刚才质询过他'));

      // 他答了，所以过了 3 小时也不会追问同一条。
      current = current.add(const Duration(hours: 3, minutes: 1));
      final EnemyMessage? next = await p.step();
      final Matcher asksAgain = anyOf(contains('小时前问过'), contains('没有回答'));
      expect(next?.text ?? '', isNot(asksAgain));
    });

    test('不回应也不是好结果：没说话的人，不会因为没动静被放过', () async {
      final EnemyPresence p = await make();
      expect(await p.step(), isNotNull);
      int spoke = 0;
      for (int i = 0; i < 6; i++) {
        current = current.add(const Duration(minutes: 91));
        if (current.hour >= 23) break;
        if (await p.step() != null) spoke++;
      }
      expect(spoke, greaterThanOrEqualTo(3));
    });

    test('沉寂的模块：曾经常有记录、最近 5 天一条没有', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(days: 1)));
      // 没有授权火种/知识/打卡的质询条件，且已有字据——剩下沉寂模块。
      await p.engine.setConsent('kindling', false);
      activity.drafts = <EventDraft>[
        for (int i = 0; i < 4; i++)
          EventDraft(
            ts: current.subtract(Duration(days: 5, hours: i * 2)).millisecondsSinceEpoch,
            source: 'activity',
            type: 'module_activity',
            dedupeKey: 'act:$i',
            payload: const <String, dynamic>{'label': '运动', 'subject': 'table:sport_records', 'day': 'd'},
          ),
      ];
      activity.version++;
      final EnemyMessage? m = await stepAfterBaseline(p);
      expect(m, isNotNull);
      expect(m!.text, contains('运动'));
    });

    test('只有最近发生的事才值得插话：灌进来的旧账不触发反应', () async {
      final EnemyPresence p = await make();
      await p.react();
      habit.drafts = <EventDraft>[
        EventDraft(
          ts: current.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
          source: 'habit',
          type: 'habit_missed',
          dedupeKey: 'old:1',
          payload: const <String, dynamic>{'label': '晨跑', 'subject': 's', 'day': 'd'},
        ),
      ];
      habit.version++;
      expect(await p.react(), isNull);
      expect((await p.status()).lastWhy, 'no_new');
    });

    test('字据标记完成但账上没有火种：敌人不认', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(days: 1)));
      final EnemyMessage m = (await stepAfterBaseline(p))!;
      final int id = m.refId!;
      expect((await dao.motion(id))!.kind, 'kindling_absent');
      final int cid = (await p.acceptMotion(id)).ok
          ? (await dao.motion(id))!.commitmentId!
          : -1;

      await p.engine.complete(cid);
      final EnemyMessage? reply = await p.react(force: true);
      expect(reply, isNotNull);
      expect(reply!.text, anyOf(contains('不认'), contains('账上却是空的')));
    });

    test('字据标记完成而且账上确实有火种：不质疑', () async {
      final EnemyPresence p = await make();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(days: 1)));
      final EnemyMessage m = (await stepAfterBaseline(p))!;
      final int id = m.refId!;
      await p.acceptMotion(id);
      final int cid = (await dao.motion(id))!.commitmentId!;

      kindling.drafts = <EventDraft>[
        EventDraft(
          ts: current.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
          source: 'kindling',
          type: 'kindling_completed',
          dedupeKey: 'k:1',
          payload: const <String, dynamic>{'label': '译书', 'minutes': 15, 'subject': 's', 'day': 'd'},
        ),
      ];
      kindling.version++;
      current = current.add(const Duration(minutes: 5));
      await p.engine.complete(cid);
      final List<EnemyEvent> events =
          await dao.eventsBetween(0, 1 << 50, source: 'commitment');
      expect(events.any((EnemyEvent e) => e.type == 'commitment_unverified'), isFalse);
    });

    test('质询演练：带【演练】，不提动议，不占今天的次数和间隔', () async {
      final EnemyPresence p = await make();
      final DrillResult r = await p.drill('probe');
      expect(r.message, isNotNull);
      expect(r.message!.kind, MessageKind.drill);
      expect(r.message!.text, startsWith('【演练】'));
      expect(await dao.motionsSince(0), isEmpty);
      expect((await p.status()).probesToday, 0);
      expect(await dao.intSetting(EnemySettings.probeGlobalMs, 0), 0);
    });

    test('自检状态包含质询的节奏', () async {
      final EnemyPresence p = await make();
      await stepAfterBaseline(p);
      final EnemyStatus s = await p.status();
      expect(s.opposition, isTrue);
      expect(s.probesToday, 1);
      expect(s.probeCap, 8);
      expect(s.probeGapMin, 90);
      expect(s.openMotion, isTrue);
      expect(s.probeAgeSec, greaterThanOrEqualTo(0));
    });
  });
}

// 与 EnemyCopy.stakeRejected 一致；测试里不依赖 copy.dart 的私有结构。
const String EnemyCopy_stake = '赌注只能是一个行动：不能伤害自己、羞辱自己，也不能涉及钱。换一个。';
