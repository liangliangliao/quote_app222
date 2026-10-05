import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/beautiful_enemy/src/data/enemy_dao.dart';
import 'package:quote_app/beautiful_enemy/src/data/enemy_schema.dart';
import 'package:quote_app/beautiful_enemy/src/data/models.dart';
import 'package:quote_app/beautiful_enemy/src/domain/enemy_engine.dart';
import 'package:quote_app/beautiful_enemy/src/domain/enemy_presence.dart';
import 'package:quote_app/beautiful_enemy/src/domain/evidence_source.dart';
import 'package:quote_app/beautiful_enemy/src/domain/guard.dart';
import 'package:quote_app/beautiful_enemy/src/enemy_talker.dart';
import 'package:quote_app/beautiful_enemy/src/persona.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MutableSource extends EvidenceSource {
  List<EventDraft> drafts = <EventDraft>[];

  @override
  String get id => 'habit';

  @override
  String get label => '习惯';

  @override
  Future<List<EventDraft>> collect(Database db, int sinceMs) async => drafts;
}

class FakeTalker implements EnemyTalker {
  FakeTalker(this.reply);

  final String? Function(String situation, String userText) reply;
  int calls = 0;
  String lastSituation = '';

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
    calls++;
    lastSituation = situation;
    return reply(situation, userText);
  }
}

EventDraft habitMissed(DateTime at, {int id = 1, String label = '晨跑'}) => EventDraft(
      ts: at.millisecondsSinceEpoch,
      source: 'habit',
      type: 'habit_missed',
      dedupeKey: 'habit:$id:missed',
      payload: <String, dynamic>{
        'subject': 'preset:$id',
        'label': label,
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
  late MutableSource source;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = EnemyDao(db);
    await dao.ensureSchema();
    current = wednesday;
    source = MutableSource();
  });

  tearDown(() async {
    await db.close();
  });

  Future<EnemyPresence> makePresence({EnemyTalker? talker}) async {
    final EnemyEngine engine = EnemyEngine(
      dao: dao,
      oracle: const LocalFactOracle(),
      sources: <EvidenceSource>[source],
      clock: () => current,
    );
    await engine.grantAll();
    return EnemyPresence(engine: engine, talker: talker);
  }

  group('本地台词', () {
    test('每一句都过同一套校验：禁区、长度、粗口只在 3 档', () {
      const List<String> types = <String>[
        'habit_missed',
        'habit_done',
        'kindling_completed',
        'kindling_aborted',
        'knowledge_converted',
        'commitment_missed',
        'commitment_done',
        'something_else',
      ];
      const DraftValidator v = DraftValidator();
      for (final String type in types) {
        for (int tone = 1; tone <= 3; tone++) {
          for (int seed = 0; seed < 8; seed++) {
            for (final String stake in <String>['', '先做十五分钟火种再碰手机']) {
              final String line = PersonaLines.interject(
                type: type,
                label: '晨跑',
                address: '对手',
                tone: tone,
                minutes: 4,
                stake: stake,
                seed: seed,
              );
              expect(v.validateLine(line, maxTone: tone), isEmpty,
                  reason: '$type tone=$tone seed=$seed -> $line');
            }
          }
        }
      }
      for (int tone = 1; tone <= 3; tone++) {
        for (int seed = 0; seed < 6; seed++) {
          expect(
            v.validateLine(PersonaLines.chat(address: '对手', tone: tone, seed: seed), maxTone: tone),
            isEmpty,
          );
          expect(
            v.validateLine(
              PersonaLines.dueSoon(text: '译完第九节', address: '对手', minutes: 5, seed: seed),
              maxTone: tone,
            ),
            isEmpty,
          );
        }
      }
      expect(v.validateLine(PersonaLines.concede('对手'), maxTone: 1), isEmpty);
      expect(v.validateLine(PersonaLines.opening('对手'), maxTone: 1), isEmpty);
    });

    test('台词带着事实：对象、称呼、赌注', () {
      final String missed = PersonaLines.interject(
        type: 'habit_missed',
        label: '晨跑',
        address: '老对手',
        tone: 2,
      );
      expect(missed, contains('晨跑'));
      final String lost = PersonaLines.interject(
        type: 'commitment_missed',
        label: '译完第九节',
        address: '对手',
        tone: 2,
        stake: '先做十五分钟火种再碰手机',
      );
      expect(lost, contains('先做十五分钟火种再碰手机'));
      final String won = PersonaLines.interject(
        type: 'commitment_done',
        label: '译完第九节',
        address: '对手',
        tone: 2,
        stake: '先做十五分钟火种再碰手机',
      );
      expect(won, contains('作废'));
    });

    test('1、2 档绝不出现粗口', () {
      for (int tone = 1; tone <= 2; tone++) {
        for (int seed = 0; seed < 12; seed++) {
          final String line = PersonaLines.interject(
            type: 'habit_missed',
            label: '晨跑',
            address: '对手',
            tone: tone,
            seed: seed,
          );
          expect(DraftValidator.profanityMarkers.any(line.contains), isFalse, reason: line);
        }
      }
    });
  });

  group('对话', () {
    test('时间线为空时敌人先开口，只开一次，并带上称呼', () async {
      final EnemyPresence p = await makePresence();
      expect(await p.engine.setAddress('老对手'), isTrue);
      final EnemyMessage? first = await p.ensureOpening();
      expect(first, isNotNull);
      expect(first!.text, contains('老对手'));
      expect(first.fromEnemy, isTrue);
      expect(await p.ensureOpening(), isNull);
      expect((await p.thread()).length, 1);
    });

    test('合规的模型回复被采用，并带着情境发给模型', () async {
      final FakeTalker talker = FakeTalker((String s, String u) => '你说了三件事，案卷里只有一件。');
      final EnemyPresence p = await makePresence(talker: talker);
      final SayResult r = await p.say('我今天做了很多');
      expect(r.user!.text, '我今天做了很多');
      expect(r.enemy!.text, '你说了三件事，案卷里只有一件。');
      expect(talker.calls, 1);
      expect((await p.thread()).map((EnemyMessage m) => m.role), <String>['user', 'enemy']);
    });

    test('模型违规：重试一次，仍违规就用本地台词', () async {
      final FakeTalker talker = FakeTalker((String s, String u) => '你就是个废物。');
      final EnemyPresence p = await makePresence(talker: talker);
      final SayResult r = await p.say('我今天没做');
      expect(talker.calls, 2);
      expect(r.enemy!.text, isNot(contains('废物')));
      expect(r.enemy!.text, isNotEmpty);
    });

    test('2 档下模型说粗口算违规', () async {
      final FakeTalker talker = FakeTalker((String s, String u) => '少他妈找借口，对手。');
      final EnemyPresence p = await makePresence(talker: talker);
      final SayResult r = await p.say('我今天没做');
      expect(talker.calls, 2);
      expect(r.enemy!.text, isNot(contains('他妈')));
    });

    test('模型没产出就不重试，直接用本地台词', () async {
      final FakeTalker talker = FakeTalker((String s, String u) => null);
      final EnemyPresence p = await makePresence(talker: talker);
      final SayResult r = await p.say('我今天没做');
      expect(talker.calls, 1);
      expect(r.enemy, isNotNull);
    });

    test('没接模型也能对话', () async {
      final EnemyPresence p = await makePresence();
      final SayResult r = await p.say('我今天没做');
      expect(r.enemy, isNotNull);
    });

    test('危机表达：敌人退场、静音，这句话既不存储也不发给模型', () async {
      final FakeTalker talker = FakeTalker((String s, String u) => '不该被调用');
      final EnemyPresence p = await makePresence(talker: talker);
      final SayResult r = await p.say('我真的不想活了');
      expect(r.crisis, isTrue);
      expect(r.enemy!.kind, MessageKind.exit);
      expect(r.enemy!.text, contains('联系'));
      expect(talker.calls, 0);
      expect(await p.engine.isMuted(), isTrue);
      expect(await dao.boolSetting(EnemySettings.crisisNoticePending), isTrue);
      final List<EnemyMessage> all = await p.thread();
      expect(all.any((EnemyMessage m) => m.text.contains('不想活')), isFalse);
      expect(all.every((EnemyMessage m) => m.fromEnemy), isTrue);
    });

    test('只说停战：静音，但不显示危机文案', () async {
      final EnemyPresence p = await makePresence();
      final SayResult r = await p.say('停战');
      expect(r.crisis, isFalse);
      expect(r.enemy!.kind, MessageKind.exit);
      expect(await p.engine.isMuted(), isTrue);
      expect(await dao.boolSetting(EnemySettings.crisisNoticePending), isFalse);
    });

    test('静音期间说话送不出去，也不留下记录', () async {
      final EnemyPresence p = await makePresence();
      await p.engine.muteFor24h(crisis: false);
      final SayResult r = await p.say('在吗');
      expect(r.muted, isTrue);
      expect(await dao.messageCount(), 0);
    });
  });

  group('开庭', () {
    test('判词作为敌人的一条消息进入时间线', () async {
      final EnemyPresence p = await makePresence();
      source.drafts = <EventDraft>[habitMissed(current.subtract(const Duration(hours: 1)))];
      final EnemyOutcome o = await p.openCourt();
      expect(o.kind, EnemyOutcomeKind.verdict);
      final List<EnemyMessage> all = await p.thread();
      expect(all.single.kind, MessageKind.verdict);
      expect(all.single.refId, o.verdict!.id);
    });
  });

  group('实时插话', () {
    test('第一次只定起点，不翻旧账；之后的新事件才开口', () async {
      final EnemyPresence p = await makePresence();
      source.drafts = <EventDraft>[habitMissed(current.subtract(const Duration(hours: 2)), id: 1)];
      expect(await p.react(), isNull);

      source.drafts = <EventDraft>[
        habitMissed(current.subtract(const Duration(hours: 2)), id: 1),
        habitMissed(current, id: 2, label: '读书'),
      ];
      final EnemyMessage? m = await p.react();
      expect(m, isNotNull);
      expect(m!.kind, MessageKind.interject);
      expect(m.text, contains('读书'));
      expect(await p.react(), isNull);
    });

    test('有模型时用模型的话，并把事件作为情境发过去', () async {
      final FakeTalker talker = FakeTalker((String s, String u) => '「读书」空着。你有时间做别的。');
      final EnemyPresence p = await makePresence(talker: talker);
      await p.react();
      source.drafts = <EventDraft>[habitMissed(current, id: 2, label: '读书')];
      final EnemyMessage? m = await p.react();
      expect(m!.text, '「读书」空着。你有时间做别的。');
      expect(talker.lastSituation, contains('习惯没完成'));
      expect(talker.lastSituation, contains('读书'));
    });

    test('间隔太近不开口，且不丢事件：过了间隔再说', () async {
      final EnemyPresence p = await makePresence();
      await p.react();
      source.drafts = <EventDraft>[habitMissed(current, id: 2, label: '读书')];
      expect(await p.react(), isNotNull);

      source.drafts = <EventDraft>[
        habitMissed(current, id: 2, label: '读书'),
        habitMissed(current, id: 3, label: '写作'),
      ];
      expect(await p.react(), isNull);

      current = current.add(const Duration(minutes: 6));
      final EnemyMessage? later = await p.react();
      expect(later, isNotNull);
      expect(later!.text, contains('写作'));
    });

    test('force 绕过间隔和上限，但不绕过静音', () async {
      final EnemyPresence p = await makePresence();
      await p.react();
      source.drafts = <EventDraft>[habitMissed(current, id: 2)];
      expect(await p.react(), isNotNull);
      source.drafts = <EventDraft>[habitMissed(current, id: 2), habitMissed(current, id: 3, label: '写作')];
      expect(await p.react(force: true), isNotNull);

      await p.engine.muteFor24h(crisis: false);
      source.drafts = <EventDraft>[
        habitMissed(current, id: 2),
        habitMissed(current, id: 3, label: '写作'),
        habitMissed(current, id: 4, label: '跑步'),
      ];
      expect(await p.react(force: true), isNull);
    });

    test('每日上限：到了就不再插话', () async {
      final EnemyPresence p = await makePresence();
      await dao.setSetting(EnemySettings.interjectCap, '1');
      await p.react();
      source.drafts = <EventDraft>[habitMissed(current, id: 2)];
      expect(await p.react(), isNotNull);

      current = current.add(const Duration(minutes: 6));
      source.drafts = <EventDraft>[habitMissed(current, id: 2), habitMissed(current, id: 3, label: '写作')];
      expect(await p.react(), isNull);
    });

    test('静默时段不插话，这批事件也不会在早上被翻出来', () async {
      final EnemyPresence p = await makePresence();
      await p.react();
      current = DateTime(2026, 9, 30, 23, 30);
      source.drafts = <EventDraft>[habitMissed(current, id: 2)];
      expect(await p.react(), isNull);

      current = DateTime(2026, 10, 1, 9);
      expect(await p.react(), isNull);
    });

    test('总开关关掉：不插话', () async {
      final EnemyPresence p = await makePresence();
      await p.react();
      await dao.setBoolSetting(EnemySettings.interject, false);
      source.drafts = <EventDraft>[habitMissed(current, id: 2)];
      expect(await p.react(), isNull);
    });

    test('静音时不插话', () async {
      final EnemyPresence p = await makePresence();
      await p.react();
      await p.engine.muteFor24h(crisis: false);
      source.drafts = <EventDraft>[habitMissed(current, id: 2)];
      expect(await p.react(), isNull);
    });

    test('字据快到期：提醒一次，只一次', () async {
      final EnemyPresence p = await makePresence();
      await p.react();
      await p.engine.addCommitment('译完第九节', due: current.add(const Duration(minutes: 8)));
      final EnemyMessage? warn = await p.react();
      expect(warn, isNotNull);
      expect(warn!.text, contains('译完第九节'));
      expect(warn.text, contains('8'));

      current = current.add(const Duration(minutes: 6));
      expect(await p.react(), isNull);
    });

    test('字据到期输了：敌人当场把赌注摆出来', () async {
      final EnemyPresence p = await makePresence();
      await p.react();
      await p.engine.addCommitment(
        '译完第九节',
        due: current.add(const Duration(hours: 1)),
        stake: '先做十五分钟火种再碰手机',
      );
      current = current.add(const Duration(hours: 2));
      final EnemyMessage? m = await p.react();
      expect(m, isNotNull);
      expect(m!.text, contains('先做十五分钟火种再碰手机'));
    });

    test('兑现字据：认账，赌注作废', () async {
      final EnemyPresence p = await makePresence();
      await p.react();
      final int id = (await p.engine.addCommitment(
        '译完第九节',
        due: current.add(const Duration(hours: 1)),
        stake: '先做十五分钟火种再碰手机',
      ))
          .id!;
      await p.engine.complete(id);
      final EnemyMessage? m = await p.react(force: true);
      expect(m, isNotNull);
      expect(m!.text, contains('作废'));
    });
  });

  group('赌注与称呼', () {
    test('赌注只能是行动：伤害自己、羞辱、涉及钱都被拒绝', () async {
      final EnemyPresence p = await makePresence();
      for (final String bad in <String>['今晚不吃饭', '打自己十下', '转账给朋友', '发朋友圈道歉']) {
        final r = await p.engine.addCommitment('译完第九节', stake: bad);
        expect(r.id, isNull, reason: bad);
        expect(r.error, isNotNull, reason: bad);
      }
      expect(await dao.commitments(), isEmpty);
      final r = await p.engine.addCommitment('译完第九节', stake: '先做十五分钟火种再碰手机');
      expect(r.id, isNotNull);
      expect((await dao.commitment(r.id!))!.stake, '先做十五分钟火种再碰手机');
    });

    test('赌注里出现危机表达：按安全阀处理，不入库', () async {
      final EnemyPresence p = await makePresence();
      final r = await p.engine.addCommitment('译完第九节', stake: '我想死');
      expect(r.crisis, isTrue);
      expect(r.id, isNull);
      expect(await p.engine.isMuted(), isTrue);
    });

    test('称呼不能是羞辱性的，也不能太长', () async {
      final EnemyPresence p = await makePresence();
      expect(await p.engine.setAddress('废物'), isFalse);
      expect(await p.engine.setAddress('这是一个特别特别长的称呼'), isFalse);
      expect(await p.engine.address(), '对手');
      expect(await p.engine.setAddress('老对手'), isTrue);
      expect(await p.engine.address(), '老对手');
      expect(await p.engine.setAddress(''), isTrue);
      expect(await p.engine.address(), '对手');
    });
  });

  group('行对话校验', () {
    const DraftValidator v = DraftValidator();

    test('空、过长、禁区、1/2 档粗口都被拦', () {
      expect(v.validateLine('', maxTone: 3), contains('empty'));
      expect(v.validateLine('字' * 201, maxTone: 3), contains('too_long'));
      expect(v.validateLine('你这种人没救了', maxTone: 3), contains('banned_content'));
      expect(v.validateLine('少他妈找借口', maxTone: 2), contains('profanity_below_tier3'));
      expect(v.validateLine('少他妈找借口', maxTone: 3), isEmpty);
      expect(v.validateLine('字据到期，你输了。', maxTone: 1), isEmpty);
    });
  });

  group('迁移', () {
    test('v1 的库（承诺表没有赌注列）进场后补列，已有数据保留', () async {
      final Database old = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await old.execute('''CREATE TABLE be_commitment (
        id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL,
        created_ms INTEGER NOT NULL, due_ms INTEGER,
        status TEXT NOT NULL DEFAULT 'open', origin TEXT NOT NULL DEFAULT 'manual',
        verdict_id INTEGER)''');
      await old.insert('be_commitment', <String, Object?>{'text': '旧字据', 'created_ms': 1});
      await EnemySchema.createAll(old);
      await EnemySchema.createAll(old); // 幂等
      final List<EnemyCommitment> rows = await EnemyDao(old).commitments();
      expect(rows.single.text, '旧字据');
      expect(rows.single.stake, '');
      await old.close();
    });
  });
}
