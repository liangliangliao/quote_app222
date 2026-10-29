import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_ai_service.dart';
import 'package:quote_app/self_os/self_os_engine.dart';
import 'package:quote_app/self_os/self_os_guidance.dart';
import 'package:quote_app/self_os/self_os_insights.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_progress.dart';
import 'package:quote_app/self_os/self_os_strength_learning.dart';
import 'package:quote_app/self_os/self_os_v37_rules.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;
import 'self_os_guide_test.dart' show guideResponse, experimentGuide;
import 'self_os_v37_rules_test.dart' show decision, proof, node, link;

SelfOsCase routedCase(String task, {String problem = '两种生活安排之间的取舍'}) {
  final c = SelfOsCase(problem: problem)..v37 = decision();
  final response = guideResponse('problem', c.problem)
    ..['risk'] = 'low'
    ..['routing'] = {'task': task, 'reason': '根据本人处境，先处理这个结构缺口'};
  SelfOsGuidance.receive(
      c,
      OsGuideFrame.parse(response,
          userSources: {'problem': c.problem}, latestId: 'problem'),
      c.guide.revision);
  return c;
}

SelfOsProfile strengthProfile() => SelfOsProfile()
  ..strengths.add(OsStrength({
    'id': 'curiosity',
    'title': '具体提问',
    'definition': '把泛泛担忧变成一个可回答的问题',
    'counter': '紧张时也会问得太多',
    'overuse': '限制问题数量，保留对方暂停的空间'
  }));

SelfOsCase strengthCase() {
  final c = plannedCase();
  SelfOsStrengthLearning.draftUse(c, 'curiosity', 'cognition', '用一个具体问题检验假设');
  c.motives.first.strengthId = 'curiosity';
  c.motives.first.reason = '从能回答的问题开始';
  c.v37.settings
      .addAll({'cueSource': 'strength:curiosity', 'holdCue': '先问一件事'});
  c.commit();
  c.addReview(reviewFor(c));
  return c;
}

void main() {
  test('原文 A17：十种语义分流跨领域与措辞不变，不能改变风险与承诺', () {
    for (final task in osGuideTasks.keys) {
      for (final domain in ['职业自主', '照护责任', '技能学习', '财务取舍', '共同生活', '创作投入']) {
        final c = routedCase(task, problem: '$domain：先比较做法，再决定下一步');
        final next = SelfOsProgress.next(c);
        expect(next.kind, task);
        expect(next.reason, contains('结构缺口'));
        expect(c.committedAt, isNull);
        expect(c.v37.text('risk'), 'low');
        if (['desire', 'motivation', 'cognition', 'action'].contains(task)) {
          expect(next.engine?.name, task);
        } else {
          expect(next.workspace, isNotNull);
        }
      }
    }
  });

  test('原文 A17：未知路由拒收；纠正使旧语义建议失效', () {
    final c = routedCase('alignment');
    final invalid = guideResponse('problem', c.problem)
      ..['routing'] = {'task': 'commit', 'reason': '替用户决定'};
    expect(
        () => OsGuideFrame.parse(invalid,
            userSources: {'problem': c.problem}, latestId: 'problem'),
        throwsFormatException);
    SelfOsGuidance.answer(c, '并不是要消灭情绪，我只是缺少一次沟通', correction: true);
    expect(c.guide.frame, isNull);
    expect(SelfOsProgress.next(c).kind, isNot('alignment'));
  });

  test('原文 A03/A05：未知与新反证优先于模型推荐，不用更多激励代替核验', () {
    final c = routedCase('motivation');
    c.v37.gaps.add(OsGap({
      'id': 'salary',
      'kind': 'fact',
      'question': '实际代价是多少',
      'access': 'public'
    }));
    expect(SelfOsProgress.next(c).kind, 'retrieve');
    c.v37.evidence.add(proof()..data['contradiction'] = 'conflict');
    expect(SelfOsProgress.next(c).kind, 'verify');
    c.fields['newInformation'] = '约定范围发生了变化';
    expect(SelfOsProgress.next(c).kind, 'reconsider');
  });

  test('原文 A24/A27/A47：结构状态主动分流到对齐、路径或长时域', () {
    final c = SelfOsCase(problem: '暂未形成引导回复')..v37 = decision();
    c.v37.settings
        .addAll({'natureConflict': true, 'natureEvidence': '本人记录的跨情境限制'});
    expect(SelfOsProgress.next(c).kind, 'alignment');
    c.v37.settings.remove('natureConflict');
    c.v37.settings['triggerSource'] = 'comparison';
    expect(SelfOsProgress.next(c).kind, 'routes');
    c.v37.settings.remove('triggerSource');
    c.v37.settings['longHorizon'] = true;
    c.v37.nodes.add(node('first', 1));
    expect(SelfOsProgress.next(c).analysisTask, 'horizon');
  });

  test('原文 A11：已经看清的冲突不反复拦截，动机变化后需要重新审视', () {
    final c = routedCase('conflict');
    c.motives.add(
        SelfOsMotive(id: 'm', selected: true, title: '稳定', importance: 80));
    c.v37.settings['reviewedConflict'] = SelfOsProgress.conflictFingerprint(c);
    expect(SelfOsProgress.next(c).kind, isNot('conflict'));
    c.motives.first.occupancy = 15;
    expect(SelfOsProgress.next(c).kind, 'conflict');
  });

  test('原文 A05/A41：已承诺仍先处理过期证据；有效的小实验可按时准备', () {
    final now = DateTime.now();
    final c = plannedCase();
    c.v37.evidence.add(proof(now: now)
      ..data['validUntil'] =
          now.add(const Duration(hours: 1)).toIso8601String());
    c.v37.gaps.add(OsGap({
      'id': 'availability',
      'access': 'public',
      'question': '场地可用吗',
      'resolutionConfirmed': true,
      'resolutionAnswer': '当前可用',
      'resolutionScope': '只适用于当前约定',
      'evidenceIds': ['proof']
    }));
    c.commit();
    expect(SelfOsProgress.actionBlocker(c, at: now), isNull);
    expect(
        SelfOsProgress.actionBlocker(c, at: now.add(const Duration(hours: 2))),
        isNotNull);
    expect(SelfOsProgress.next(c, at: now.add(const Duration(hours: 2))).kind,
        'assess');
    final experiment = experimentGuide();
    experiment.guide.draft['moment'] =
        now.add(const Duration(days: 1)).toIso8601String();
    SelfOsGuidance.commitExperiment(experiment);
    experiment.v37.interventions.single.data['dueAt'] =
        now.subtract(const Duration(minutes: 1)).toIso8601String();
    expect(SelfOsProgress.actionBlocker(experiment, at: now), isNull);
    expect(SelfOsProgress.next(experiment, at: now).kind, 'prepare');
    experiment.v37.settings['requiresReconsideration'] = true;
    expect(SelfOsProgress.actionBlocker(experiment), isNotNull);
  });

  test('原文动机公式：注意与个人历史影响实际排序，未知不伪造为分数', () {
    final m = SelfOsMotive(
        type: '自主',
        importance: 100,
        credibility: 80,
        vividness: 50,
        occupancy: 25,
        predicted: 99);
    const history = [SelfOsFingerprint('自主', 1, 5)];
    expect(
        SelfOsEngineService.currentMotiveEffect(m, history), closeTo(2, 0.001));
    m.occupancy = 100;
    expect(
        SelfOsEngineService.currentMotiveEffect(m, history), closeTo(8, 0.001));
    m.credibility = null;
    expect(SelfOsEngineService.currentMotiveEffect(m, history), isNull);
    expect(SelfOsEngineService.motiveRank(m, history), 20);
  });

  test('原文 A37/A51：逐节点保留直接依据，从薄弱的边开始降低置信度', () {
    final s = decision()..evidence.add(proof());
    s.nodes.addAll([
      node('a1', 1, label: 'fact'),
      node('a2', 2),
      node('a3', 3, label: 'unknown')
    ]);
    s.edges.addAll([link('a1', 'a2'), link('a2', 'a3')]);
    final path = SelfOsV37Rules.causalPaths(s).single;
    expect(path.nodeCertainties,
        {'a1': 'direct', 'a2': 'supported', 'a3': 'unknown'});
    expect(path.certainty, 'unknown');
    s.edges.first.data['condition'] = '';
    final broken = SelfOsV37Rules.causalPaths(s).single;
    expect(broken.nodeCertainties, {'a1': 'direct', 'a2': 'unknown'});
    expect(broken.nodes.map((n) => n.id), isNot(contains('a3')));
  });

  test('原文 A47/A51：六领域节点/边顺序变化不改变各阶置信度', () {
    for (final domain in ['职业', '家庭', '学习', '健康', '财务', '创作']) {
      final s = decision()..evidence.add(proof());
      for (var i = 1; i <= 6; i++) {
        s.nodes.add(
            node('a$i', i, label: 'fact')..data['title'] = '$domain 第 $i 阶状态');
        if (i > 1) s.edges.add(link('a${i - 1}', 'a$i', label: 'fact'));
      }
      s.nodes.setAll(0, s.nodes.reversed.toList());
      s.edges.setAll(0, s.edges.reversed.toList());
      final certainties = SelfOsV37Rules.causalPaths(s).single.nodeCertainties;
      expect(certainties['a1'], 'direct');
      expect(certainties['a3'], 'supported');
      expect(certainties['a5'], 'scenario');
      s.evidence.single.data['contradiction'] = 'conflict';
      expect(SelfOsV37Rules.causalPaths(s).single.nodeCertainties,
          {'a1': 'unknown'});
    }
  });

  test('原文 A26：三阶段实际反馈只增加一次力量样本，反作用保留', () {
    final c = strengthCase(), profile = strengthProfile();
    final r = c.reviews.single;
    expect(SelfOsStrengthLearning.uses(r.snapshot).map((u) => u['stage']),
        containsAll(['cognition', 'motivation', 'action']));
    expect(SelfOsStrengthLearning.applyFeedback(r, profile), isFalse);
    for (final stage in osStrengthStages.keys) {
      r.notes.addAll({
        'strength.curiosity.$stage.effect':
            stage == 'action' ? 'harmed' : 'helped',
        'strength.curiosity.$stage.usage':
            stage == 'action' ? 'overuse' : 'optimal',
        'strength.curiosity.$stage.observation': '实际观察：$stage 影响了提问与回应'
      });
    }
    SelfOsStrengthLearning.applyFeedback(r, profile);
    SelfOsStrengthLearning.applyFeedback(r, profile);
    final observations = profile.strengths.single.observations;
    expect(observations, hasLength(1));
    expect(observations.single['stageEffects'], hasLength(3));
    expect(observations.single['effect'], 'harmed');
    expect(SelfOsInsights.strength(profile.strengths.single, [c]).counters, 1);
    expect(SelfOsInsights.strength(profile.strengths.single, [c]).verified,
        isFalse);
    for (final stage in osStrengthStages.keys) {
      r.notes['strength.curiosity.$stage.effect'] = 'unknown';
    }
    SelfOsStrengthLearning.applyFeedback(r, profile);
    expect(profile.strengths.single.observations, isEmpty);
  });

  test('原文 A26/A44：只有具体观察可回写，下一轮不继承上轮实际结果和现场力量', () {
    final c = strengthCase(), profile = strengthProfile();
    final r = c.reviews.single;
    r.notes['strength.curiosity.cognition.effect'] = 'helped';
    SelfOsStrengthLearning.applyFeedback(r, profile);
    expect(profile.strengths.single.observations, isEmpty);
    c.fields['review.result'] = '这是上一轮结果';
    c.scores['review.actualDiscomfort'] = 3;
    c.v37.settings['actionBridge'] = {
      'strengthId': 'curiosity',
      'mechanism': '旧桥接'
    };
    c.nextRound();
    expect(c.text('review.result'), isEmpty);
    expect(c.scores['review.actualDiscomfort'], isNull);
    expect(
        SelfOsStrengthLearning.uses(c.evidenceSnapshot())
            .map((u) => u['stage']),
        ['motivation']);
    expect(c.reviews.single.result, isNotEmpty);
  });

  test('原文 A23/A26/A38：AI 获得真实个人指纹与所选操作，伪造力量引用剔除', () async {
    final history = <SelfOsCase>[];
    final profile = strengthProfile();
    for (var i = 0; i < 3; i++) {
      final c = strengthCase();
      c.v37.settings['shareExperience'] = true;
      c.reviews.single.notes.addAll({
        'strength.curiosity.cognition.effect': 'helped',
        'strength.curiosity.cognition.observation': '实际用问题澄清了条件 $i'
      });
      SelfOsStrengthLearning.applyFeedback(c.reviews.single, profile);
      history.add(c);
    }
    profile.strengths.single.data['observations'] = [
      ...profile.strengths.single.observations,
      {'reviewId': 'orphan', 'effect': 'helped', 'observation': '不存在的证据'}
    ];
    Map<String, dynamic>? captured;
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      captured = jsonDecode(prompt.substring(prompt.lastIndexOf('用户数据：') + 5));
      expect(prompt, contains('本次选定的 cognitiveOperation：事实纠错'));
      return jsonEncode({
        'suggestions': [
          {
            'field': 'k2',
            'value': '先核对可以回答的事实',
            'reason': '已提供的真实提问记录',
            'strengthId': 'curiosity'
          },
          {
            'field': 'k2',
            'value': '另一个候选',
            'reason': '仍待验证',
            'strengthId': 'invented'
          }
        ]
      });
    });
    final suggestions =
        await ai.suggest(plannedCase(), history, 'cognition', profile: profile);
    final personal = osMap(captured!['personalEvidence']);
    expect(
        osMaps(personal['cognitiveOperationPreferences']).single['samples'], 3);
    final strength = osMaps(personal['strengths']).single;
    expect(strength['observations'], hasLength(3));
    expect(strength['supportedReviewIds'], isNot(contains('orphan')));
    expect(suggestions.first['strengthId'], 'curiosity');
    expect(suggestions.last.containsKey('strengthId'), isFalse);
  });
}
