import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_engine.dart';
import 'package:quote_app/self_os/self_os_models.dart';

SelfOsCase plannedCase() {
  final c = SelfOsCase(problem: '明天有面试，但我越来越不想去');
  c.desires.add(SelfOsDesire(title: '稳定', verdict: 'accepted'));
  c.fields.addAll({
    'trigger': '明天 8 点，闹钟响',
    'firstAction': '双脚落地',
    'k1': '失败说明没有能力',
    'k2': '面试提供一次具体反馈',
    'cognitiveOperation': '事实纠错'
  });
  c.scores.addAll({
    'planProbability': 55,
    'actionProbability': 31,
    'predictedDiscomfort': 9,
    'costAcceptance': 80
  });
  c.motives.addAll([
    SelfOsMotive(id: 'income', title: '稳定收入', type: '长期目标', selected: true),
    SelfOsMotive(
        id: 'comfort',
        title: '保住眼前舒适',
        side: 'against',
        type: '即时收益',
        selected: true)
  ]);
  return c;
}

SelfOsReview reviewFor(SelfOsCase c,
        {String context = '面试前的早晨',
        String outcome = 'done',
        bool feedback = true,
        List<String> effective = const ['income'],
        String cognition = 'helped'}) =>
    SelfOsReview(
        round: c.round,
        outcome: outcome,
        result: '去了现场并得到反馈',
        learning: '焦虑很强也能先行动十分钟',
        context: context,
        snapshot: c.commitment ?? c.evidenceSnapshot(),
        scores: {'actualDiscomfort': 6, 'actualCostAcceptance': 60},
        notes: {
          'servedDesire': '稳定',
          'evidenceUse': 'usable',
          'actualCost': '紧张与等待',
          'cognitionFeedback': cognition
        },
        effectiveMotives: effective,
        motiveFeedbackRecorded: feedback);

void main() {
  test('读取未知或无效的实际分数时保留未知，不补成零', () {
    final c = plannedCase()..commit();
    final json = reviewFor(c).toJson();
    json['scores'] = {'actualDiscomfort': null, 'alignment': '未知'};
    final loaded = SelfOsReview.fromJson(json);
    expect(loaded.scores, isEmpty);
    expect(loaded.predictionError, isNull);
  });
  test('欲求冲突合并反向记录，行动校准不把部分完成当作失败', () {
    final a = plannedCase()..commit();
    final ar = reviewFor(a)..notes['sacrificedDesire'] = '舒适';
    a.addReview(ar);
    final b = plannedCase()..commit();
    final br = reviewFor(b, outcome: 'notDone')
      ..notes.addAll({'servedDesire': '舒适', 'sacrificedDesire': '稳定'});
    b.addReview(br);
    final p = plannedCase()..commit();
    p.addReview(reviewFor(p, outcome: 'partial'));
    final pair = SelfOsEngineService.conflicts([a, b, p]).single;
    expect(pair.total, 2);
    expect(pair.firstWins, 1);
    expect(pair.secondWins, 1);
    expect(SelfOsEngineService.actionCalibrationError([a, b, p]), 50);
    ar.notes['evidenceUse'] = 'contextOnly';
    expect(SelfOsEngineService.patterns([a, b, p]), isEmpty);
  });

  test('反复高意愿未行动后自动推荐现场设计', () {
    final c = plannedCase();
    c.scores['planProbability'] = 90;
    c.commit();
    c.addReview(reviewFor(c, outcome: 'notDone'));
    for (var i = 0; i < 2; i++) {
      c.nextRound();
      c.scores.addAll({'planProbability': 90, 'actionProbability': 80});
      c.commit();
      c.addReview(reviewFor(c, outcome: 'notDone'));
    }
    c.nextRound();
    expect(SelfOsEngineService.next(c).engine, SelfOsEngine.action);
    expect(SelfOsEngineService.next(c).reason, contains('最近三轮'));
  });
  test('四类阻塞分流，不把路径或环境问题强行送入认知纠错', () {
    final c = plannedCase();
    for (final e in {
      'desire': SelfOsEngine.desire,
      'means': SelfOsEngine.desire,
      'environment': SelfOsEngine.action
    }.entries) {
      c.blocker = e.key;
      expect(SelfOsEngineService.next(c).engine, e.value);
    }
    c.blocker = 'cognition';
    c.fields.remove('k2');
    expect(SelfOsEngineService.next(c).engine, SelfOsEngine.cognition);
    c.blocker = 'unknown';
    expect(SelfOsEngineService.next(c).reason, contains('先区分'));
  });

  test('时间差保持有符号，现场落差过大优先现场设计', () {
    final c = plannedCase();
    expect(c.temporalGap, 24);
    c.scores['planProbability'] = 95;
    expect(SelfOsEngineService.next(c).engine, SelfOsEngine.action);
    c.scores['planProbability'] = 10;
    expect(c.temporalGap, -21);
    c.scores.remove('actionProbability');
    expect(c.temporalGap, isNull);
  });

  test('协议必须包含双时态预测、正反动机、触发和第一步', () {
    final c = plannedCase();
    c.motives.removeLast();
    expect(c.commit, throwsFormatException);
    c.motives.add(SelfOsMotive(side: 'against', selected: true));
    c.scores.remove('actionProbability');
    expect(c.commit, throwsFormatException);
    c.scores['actionProbability'] = 0;
    c.commit();
    expect(c.evidenceLevel, '决意证据');
    expect(c.commitment!['scores']['actionProbability'], 0);
  });

  test('快照保留原认识和预测，修改当前草稿不会改写历史', () {
    final c = plannedCase()..commit();
    c.fields['k1'] = '后来改变的认识';
    c.scores['predictedDiscomfort'] = 2;
    c.motives.first.title = '改过的标题';
    c.addReview(reviewFor(c));
    final loaded = SelfOsCase.fromJson(jsonDecode(jsonEncode(c.toJson())));
    expect(loaded.reviews.single.snapshot['fields']['k1'], '失败说明没有能力');
    expect(loaded.reviews.single.snapshot['motives'][0]['title'], '稳定收入');
    expect(loaded.reviews.single.predictionError, 3);
    expect(loaded.evidenceLevel, '行动证据');
    expect(loaded.reviews.single.scores['actualCostAcceptance'], 60);
  });

  test('每轮仅一条复盘，新一轮清空事前预测并保留旧证据', () {
    final c = plannedCase()..commit();
    c.addReview(reviewFor(c, outcome: 'notDone'));
    expect(() => c.addReview(reviewFor(c)), throwsFormatException);
    expect(c.commit, throwsFormatException);
    c.nextRound();
    expect(c.round, 2);
    expect(c.text('k1'), '焦虑很强也能先行动十分钟');
    expect(c.text('k2'), isEmpty);
    expect(c.committedAt, isNull);
    expect(c.scores['planProbability'], isNull);
    expect(c.reviews.single.snapshot['scores']['planProbability'], 55);
    expect(c.reviewed, isFalse);
  });

  test('空结果或空新证据不能成为有效复盘', () {
    final c = plannedCase();
    expect(
        () => c.addReview(SelfOsReview(
            round: 1,
            outcome: 'done',
            result: '',
            learning: '',
            context: '早晨',
            snapshot: {})),
        throwsFormatException);
    expect(c.reviews, isEmpty);
  });

  test('Why Tree 支持分支合并与回退，拒绝悬空父节点和环', () {
    final c = SelfOsCase();
    c.addWhy(SelfOsWhyNode(id: 'a', answer: '稳定'));
    c.addWhy(SelfOsWhyNode(id: 'b', answer: '自由'));
    c.addWhy(SelfOsWhyNode(id: 'c', answer: '自主生活', parents: ['a', 'b']));
    expect(
        () =>
            c.addWhy(SelfOsWhyNode(id: 'loop', answer: '环', parents: ['loop'])),
        throwsFormatException);
    c.removeWhy('a');
    expect(c.whyTree.last.parents, ['b']);
    expect(c.copy().whyTree.last.parents, ['b']);
  });

  test('单次和单情境记录不产出性格结论，跨案例跨情境才出候选模式', () {
    final a = plannedCase()..commit();
    a.addReview(reviewFor(a));
    expect(SelfOsEngineService.patterns([a]), isEmpty);
    a.nextRound();
    a.addReview(reviewFor(a));
    a.nextRound();
    a.addReview(reviewFor(a));
    expect(SelfOsEngineService.patterns([a]), isEmpty);
    final b = plannedCase()..commit();
    b.addReview(reviewFor(b, context: '周末的学习选择'));
    expect(SelfOsEngineService.patterns([a, b]).single, contains('待反证'));
  });

  test('缺失反馈不当作失败，反方动机也进入个人指纹', () {
    final a = plannedCase()..commit();
    a.addReview(reviewFor(a, feedback: false));
    expect(SelfOsEngineService.motiveFingerprint([a]), isEmpty);
    final b = plannedCase()..commit();
    b.addReview(reviewFor(b, effective: ['comfort']));
    final history = SelfOsEngineService.motiveFingerprint([a, b]);
    expect(history.first.label, '即时收益');
    expect(history.first.helped, 1);
    expect(history.first.total, 1);
    expect(history.last.helped, 0);
    expect(SelfOsEngineService.average([null, 2, 4]), 3);
    expect(SelfOsEngineService.average([null]), isNull);
  });

  test('有实证后排序覆盖 AI 先验，认知指纹只使用已反馈样本', () {
    final m = SelfOsMotive(type: '长期目标', predicted: 99);
    expect(
        SelfOsEngineService.motiveRank(
            m, [const SelfOsFingerprint('长期目标', 1, 5)]),
        20);
    expect(
        SelfOsEngineService.motiveRank(
            m, [const SelfOsFingerprint('长期目标', 0, 1)]),
        99);
    final a = plannedCase()..commit();
    a.addReview(reviewFor(a, cognition: 'unknown'));
    expect(SelfOsEngineService.cognitiveFingerprint([a]), isEmpty);
    final b = plannedCase()..commit();
    b.addReview(reviewFor(b, cognition: 'helped'));
    expect(SelfOsEngineService.cognitiveFingerprint([a, b]).single.total, 1);
  });
}
