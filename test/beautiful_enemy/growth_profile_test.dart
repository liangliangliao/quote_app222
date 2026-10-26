import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/beautiful_enemy/beautiful_enemy.dart';
import 'package:quote_app/beautiful_enemy/src/data/growth_store.dart';
import 'package:quote_app/beautiful_enemy/src/data/models.dart';
import 'package:quote_app/beautiful_enemy/src/domain/guard.dart';
import 'package:quote_app/beautiful_enemy/src/persona.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_ai_talker.dart';
import 'package:quote_app/beautiful_enemy_host/enemy_ai_oracle.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late EnemyEngine engine;
  final now = DateTime(2026, 10, 23, 12);
  const weakness = GrowthWeakness(
      id: 'avoidance', description: '我害怕失败，会拖延求职', goal: '遇到恐惧时仍然投递一份简历');
  EnemyGrowthProfile profile() => EnemyGrowthProfile(
      sourceName: '自我认识.docx',
      originalText: '私密全文不得自动发给模型',
      weaknesses: [weakness],
      updatedMs: now.millisecondsSinceEpoch,
      strengths: '善于整理材料',
      values: '经济独立与稳定生活');
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    engine = await EnemyEntry.buildEngine(db: db, clock: () => now);
    await engine.growth.save(profile());
  });
  tearDown(() async => db.close());

  test('档案持久化、上下文区分自述与证据，并排除原文', () async {
    final reloaded = EnemyGrowthStore(db);
    expect((await reloaded.load())!.weaknesses.single.id, 'avoidance');
    final snap = await engine.snapshot();
    final context = snap.digest.json['growth_profile'] as Map;
    expect(context['source'], 'user_confirmed_self_report');
    expect(jsonEncode(context), contains('拖延求职'));
    expect(jsonEncode(context), isNot(contains('私密全文')));
    expect(snap.digest.evidenceIds, isEmpty);
    expect(snap.digest.sufficient, isFalse, reason: '自我评价不能成为指控行为的证据');
  });

  test('行动原子关联弱点、目标、预案和验证；完成与复盘持续进入上下文', () async {
    final id = await engine.addGrowthAction(
        weakness: weakness,
        action: '今天投递一份简历',
        obstaclePlan: '如果害怕失败，就先用两分钟打开招聘页面',
        evidence: '投递成功的确认记录',
        due: now.add(const Duration(hours: 2)));
    expect((await engine.dao.commitment(id))!.origin, 'growth_profile');
    final action = (await engine.growth.actions()).single;
    expect(action['weakness_id'], weakness.id);
    expect(action['goal'], weakness.goal);
    expect(action['obstacle_plan'], contains('两分钟'));
    expect(action['evidence'], contains('确认记录'));
    await engine.complete(id);
    await engine.growth.review(id, '已投递，收到确认页', '明天继续先做两分钟');
    final context =
        (await engine.snapshot()).digest.json['growth_profile'] as Map;
    final current = (context['actions'] as List).single as Map;
    expect(current['status'], CommitmentStatus.done);
    expect(current['observation'], contains('已投递'));
    expect(current['result_source'], 'user_report_not_independently_verified');
  });

  test('未启用、不属于档案、缺少预案、过期时间均不能创建行动', () async {
    Future<int> add(
            {GrowthWeakness w = weakness,
            String obstacle = '先做两分钟',
            DateTime? due}) =>
        engine.addGrowthAction(
            weakness: w,
            action: '投递简历',
            obstaclePlan: obstacle,
            evidence: '确认页',
            due: due ?? now.add(const Duration(hours: 1)));
    await expectLater(add(obstacle: ''), throwsFormatException);
    await expectLater(add(due: now), throwsFormatException);
    await expectLater(
        add(w: const GrowthWeakness(id: 'unknown', description: '未知')),
        throwsFormatException);
    await engine.growth.setEnabled(false);
    await expectLater(add(), throwsFormatException);
    expect(await engine.dao.commitments(), isEmpty);
  });

  test('停用、删除、全量清空均使下一次请求停止引用档案', () async {
    await engine.growth.setEnabled(false);
    expect((await engine.snapshot()).digest.json['growth_profile'], isEmpty);
    await engine.growth.setEnabled(true);
    final id = await engine.addGrowthAction(
        weakness: weakness,
        action: '投递简历',
        obstaclePlan: '先打开网页',
        evidence: '确认页',
        due: now.add(const Duration(hours: 1)));
    await engine.growth.delete();
    expect((await engine.snapshot()).digest.json['growth_profile'], isEmpty);
    expect(await engine.growth.actions(), isEmpty);
    expect(await engine.dao.commitment(id), isNotNull, reason: '自主接受的承诺保留');
    await engine.growth.save(profile());
    await engine.dao.wipeEverything();
    expect(await engine.growth.load(), isNull);
  });

  test('页面与后台共享上下文，AI 对话和反馈都能收到档案', () async {
    final snap = await engine.snapshot();
    String? talkPrompt;
    final talker = EnemyAiTalker(
        isAvailable: () async => true,
        call: (
            {required prompt, required systemPrompt, required purpose}) async {
          talkPrompt = prompt;
          return '先核实恐惧与拖延之间的关系，今天愿意试投一份吗？';
        });
    await talker.talk(
        digest: snap.digest.json,
        history: [],
        situation: '用户求助',
        userText: '害怕投递',
        intensity: 2,
        address: '你',
        nowMs: now.millisecondsSinceEpoch);
    expect(talkPrompt, contains('拖延求职'));
    String? judgePrompt;
    final oracle = EnemyAiOracle(
        isAvailable: () async => true,
        call: (
            {required prompt, required systemPrompt, required purpose}) async {
          judgePrompt = prompt;
          return '{}';
        });
    await oracle.judge(
        digest: snap.digest.json,
        intensity: 2,
        nowMs: now.millisecondsSinceEpoch);
    expect(judgePrompt, contains('经济独立'));
  });

  test('离线对话对相关弱点提出待核实关联，停用后不再引用', () async {
    final p = await EnemyEntry.buildPresence(db: db, clock: () => now);
    final reply = await p.say('我又拖延了，不敢投简历');
    expect(reply.enemy!.text, contains('我害怕失败，会拖延求职'));
    expect(reply.enemy!.text, contains('可能相关'));
    await engine.growth.setEnabled(false);
    expect((await p.say('我又拖延了')).enemy!.text, isNot(contains('我害怕失败，会拖延求职')));
  });

  test('AI 建议只有接受后才成为承诺；不接受、不回应都不算失约', () async {
    DateTime moment = now;
    final e = await EnemyEntry.buildEngine(db: db, clock: () => moment);
    await e.dao.insertEvent(EventDraft(
        ts: now.millisecondsSinceEpoch - 1,
        source: 'habit',
        type: 'habit_missed',
        dedupeKey: 'test-habit',
        payload: {'subject': 'habit:1', 'label': '投递简历', 'day': '2026-10-23'}));
    final v = (await e.judge(manual: true)).verdict!;
    expect((await e.dao.commitment(v.commitmentId!))!.status,
        CommitmentStatus.proposed);
    moment = moment.add(const Duration(hours: 3));
    expect(await e.settleOverdue(), 0);
    expect((await e.weeklyReview()).commitmentsMissed, 0);
    await e.declineSuggestion(v.id);
    expect((await e.dao.commitment(v.commitmentId!))!.status,
        CommitmentStatus.declined);
    final accepted = (await e.judge(manual: true)).verdict!;
    await e.acknowledge(accepted.id);
    expect((await e.dao.commitment(accepted.commitmentId!))!.status,
        CommitmentStatus.open);
  });

  test('成长行动允许具体描述超过 40 字，不误用赌注的长度限制', () async {
    final action = '打开招聘页面，选择一个符合条件的岗位，核对联系方式与个人经历，发送一份简历并保存投递成功的确认记录';
    expect(action.length, greaterThan(40));
    final id = await engine.addGrowthAction(
        weakness: weakness,
        action: action,
        obstaclePlan: '如果犹豫，先完成第一步',
        evidence: '投递确认记录',
        due: now.add(const Duration(hours: 2)));
    expect((await engine.dao.commitment(id))!.text, action);
  });

  test('高强度仍禁止粗口；缺少记录不推断逃避；完成不自动加码', () {
    const validator = DraftValidator();
    expect(validator.validateLine('少他妈找借口', maxTone: 3),
        contains('profanity_not_allowed'));
    expect(PersonaLines.claimNoRecord('你'), contains('不代表没有行动'));
    expect(
        PersonaLines.probe(type: 'unanswered_inquiry', address: '你', tone: 3),
        contains('不代表认同'));
    expect(
        PersonaLines.interject(
            type: 'habit_done', label: '投递简历', address: '你', tone: 3),
        isNot(contains('门槛')));
  });
}
