import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_ai_service.dart';
import 'package:quote_app/self_os/self_os_guidance.dart';
import 'package:quote_app/self_os/self_os_learning.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_progress.dart';
import 'package:quote_app/self_os/self_os_v37_ai.dart';
import 'package:quote_app/self_os/self_os_v37_rules.dart';
import 'self_os_guide_test.dart' show experimentGuide, guideResponse;
import 'self_os_v37_rules_test.dart' show decision, proof;

SelfOsCase observedExperiment(
    {String outcome = 'done', bool schedule = false}) {
  final c = experimentGuide();
  c.guide.draft['routeId'] = c.v37.routes.first.id;
  if (schedule)
    c.guide.draft['moment'] =
        DateTime.now().add(const Duration(days: 1)).toIso8601String();
  SelfOsGuidance.commitExperiment(c);
  SelfOsGuidance.review(c,
      outcome: outcome,
      result: outcome == 'notDone' ? '没有找到沟通时机' : '对方仍要求这项小任务逐次审批',
      learning: '这次沟通没有改变审批方式',
      context: '周三例会后的一次小任务沟通');
  return c;
}

void calibrate(SelfOsCase c,
        {String verdict = 'weakened',
        bool resolve = false,
        String influence = 'protect',
        bool conflictsChecked = false}) =>
    SelfOsLearning.calibrate(c,
        reviewId: c.reviews.last.id,
        verdict: verdict,
        conclusion: '这次小任务的审批方式没有改变，别的任务仍未知',
        scope: '仅用于周三讨论的这个小任务，不能推广到所有任务或岗位',
        influence: influence,
        resolveGap: resolve,
        conflictsChecked: conflictsChecked);

void main() {
  test('确认、实验、现实反馈和修订同步推进业务阶段，无需手动切换标签', () {
    final c = experimentGuide();
    expect(c.v37.text('phase'), 'filter');
    SelfOsGuidance.commitExperiment(c);
    expect(c.v37.text('phase'), 'experiment');
    SelfOsGuidance.review(c,
        outcome: 'partial',
        result: '只获得一个任务的授权',
        learning: '需要缩小范围',
        context: '本次沟通');
    expect(c.v37.text('phase'), 'revise');
    calibrate(c, verdict: 'uncertain', influence: 'unchanged');
    expect(c.v37.text('informationGain'), 'none');
    expect(c.v37.number('deliberationCycles'), 2);
    c.nextRound();
    expect(c.v37.text('phase'), 'filter');
    expect(c.text('k1'), c.reviews.single.notes['calibrationConclusion']);
  });
  test('重大决定的竞争路线必须对称比较；有理由的不适用仍保留', () {
    final s = decision(risk: 'high')..evidence.add(proof());
    s.settings['criticalUnknownsReviewed'] = true;
    for (final route in s.routes) {
      final first = OsConsequence({
        'id': '${route.id}1',
        'routeId': route.id,
        'title': '即时与近期状态',
        'order': 1,
        'horizon': 'now',
        'valence': 'mixed',
        'concrete': '一次具体变化'
      });
      final later = OsConsequence({
        'id': '${route.id}2',
        'routeId': route.id,
        'title': '随后变化',
        'order': 2,
        'horizon': 'near',
        'valence': 'mixed',
        'concrete': '具体后续条件'
      });
      s.nodes.addAll([
        first,
        later,
        OsConsequence({
          'id': '${route.id}3',
          'routeId': route.id,
          'title': '长期状态',
          'order': 1,
          'horizon': 'long',
          'valence': 'mixed',
          'concrete': '长期需观察的条件',
          'cumulative': route.id == 'a',
          'threshold': '持续投入'
        })
      ]);
      s.edges.add(OsCausalEdge({
        'from': first.id,
        'to': later.id,
        'condition': '条件保持',
        'basis': '待验证推断'
      }));
    }
    expect(SelfOsV37Rules.representationGaps(s), isEmpty);
    expect(SelfOsV37Rules.gate(s).action, 'ASK');
    s.settings['coverageExceptions'] = {
      'b': {'cumulative': '本选项仅发生一次，不形成重复累积'}
    };
    expect(SelfOsV37Rules.gate(s).action, 'PASS');
  });

  test('新分析提示重大风险时，旧的风险确认不覆盖新的提醒', () {
    final c = SelfOsCase(problem: '新变化')..v37 = decision();
    c.v37.settings['riskSuggestionReviewed'] = true;
    final proposal = OsAnalysisProposal.parse({
      'summary': '发现重大成本',
      'stopReason': '先核对实际损失',
      'signals': {'risk': 'high'}
    }, c);
    final revised = proposal.preview(c.v37);
    expect(revised.flag('riskSuggestionReviewed'), isFalse);
    expect(SelfOsV37Rules.gate(revised).mayCommit, isFalse);
  });
  test('AI情景不替用户决定敏感性；相同情景不能充当高低情景', () {
    final c = SelfOsCase(problem: '选择')..v37 = decision();
    final proposal = OsAnalysisProposal.parse({
      'summary': '候选情景，等待本人确认',
      'gaps': [
        {
          'id': 'candidate',
          'kind': 'fact',
          'access': 'private',
          'question': '投入成本',
          'lowScenario': '每周一小时',
          'highScenario': '每周三小时',
          'lowChoice': 'a',
          'highChoice': 'a',
          'sensitivityReviewed': true,
          'irrelevant': true
        }
      ],
    }, c);
    c.v37 = proposal.preview(c.v37);
    final gap = c.v37.gaps.single;
    expect(gap.sensitivity, 'stable');
    expect(gap.important, isTrue);
    expect(SelfOsV37Rules.gate(c.v37).mayCommit, isFalse);
    gap.data['sensitivityReviewed'] = true;
    expect(gap.important, isFalse);
    gap.data['highScenario'] = gap.text('lowScenario');
    expect(gap.sensitivity, 'unknown');
    expect(gap.important, isTrue);
  });

  test('有关联来源不等于已回答；答案、范围、本人确认和时效须同时成立', () {
    final s = decision()..evidence.add(proof());
    final gap = OsGap({
      'question': '这次可投入多少时间',
      'evidenceIds': ['proof']
    });
    s.gaps.add(gap);
    expect(gap.resolvedBy(s.evidence, DateTime.now()), isFalse);
    gap.data.addAll({'resolutionConfirmed': true, 'resolutionAnswer': '一小时'});
    expect(gap.resolvedBy(s.evidence, DateTime.now()), isFalse);
    gap.data['resolutionScope'] = '本周已有安排';
    expect(gap.resolvedBy(s.evidence, DateTime.now()), isTrue);
    s.evidence.single.data['validUntil'] =
        DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String();
    expect(gap.resolvedBy(s.evidence, DateTime.now()), isFalse);
    expect(SelfOsV37Rules.gate(s).action, 'VERIFY');
  });

  test('真实反证回到认识动机因果和未来路径；原协议保持封存', () {
    final c = observedExperiment(schedule: true);
    final frozen = jsonEncode(c.commitment);
    final nodeId = osText(osMap(c.commitment!['experiment'])['nodeId']);
    final target = c.v37.nodes.singleWhere((n) => n.id == nodeId);
    final future = OsFutureOption({
      'routeId': target.routeId,
      'nodeId': nodeId,
      'title': '更大任务的自主范围',
      'delta': 'easier'
    });
    c.v37.futureOptions.add(future);
    expect(SelfOsProgress.next(c).kind, 'calibrate');
    calibrate(c);
    expect(SelfOsProgress.next(c).kind, 'verify');
    expect(SelfOsV37Rules.gate(c.v37).mayCommit, isFalse);
    expect(target.flag('calibrationNeedsReview'), isTrue);
    expect(target.label, 'inference');
    expect(future.flag('needsReview'), isTrue);
    expect(
        SelfOsV37Rules.causalPaths(c.v37).any((p) =>
            p.nodes.any((n) => n.id == nodeId) &&
            p.stopReason.contains('实际反馈')),
        isTrue);
    expect(c.v37.knowledgeTraces.last['reviewId'], c.reviews.single.id);
    expect(osMaps(c.v37.knowledgeTraces.last['delta']), isNotEmpty);
    expect(
        c.v37.gaps.single.resolvedBy(c.v37.evidence, DateTime.now()), isFalse);
    expect(c.v37.interventions.single.data['calibrationId'],
        c.reviews.single.notes['calibrationId']);
    expect(osMap(c.v37.interventions.single.data['gain'])['knowledgeChanged'],
        isTrue);
    expect(jsonEncode(c.commitment), frozen);
    expect(jsonEncode(c.reviews.single.snapshot), frozen);
    c.v37.validate();
  });

  test('用户可限定范围关闭已回答经验问题；关闭不赋予人生承诺或因果事实', () {
    final c = observedExperiment();
    expect(() => calibrate(c, resolve: true), throwsFormatException);
    expect(SelfOsLearning.calibrated(c.reviews.single), isFalse);
    calibrate(c, resolve: true, conflictsChecked: true);
    expect(
        c.v37.gaps.single.resolvedBy(c.v37.evidence, DateTime.now()), isTrue);
    expect(c.v37.gaps.single.text('resolutionReviewId'), c.reviews.single.id);
    expect(c.v37.routes.any((r) => r.status == 'active'), isFalse);
    expect(SelfOsV37Rules.gate(c.v37).action, isNot('PASS'));
    final before = jsonEncode(c.toJson());
    expect(() => calibrate(c), throwsFormatException);
    expect(jsonEncode(c.toJson()), before);
  });

  test('未行动不能检验结果；未知、公共资料或改过的问题不被误关闭', () {
    final c = observedExperiment(outcome: 'notDone');
    expect(() => calibrate(c), throwsFormatException);
    calibrate(c, verdict: 'unobserved', influence: 'unchanged');
    expect(c.v37.nodes.any((n) => n.flag('calibrationNeedsReview')), isFalse);
    expect(
        c.v37.gaps.single.resolvedBy(c.v37.evidence, DateTime.now()), isFalse);
    for (final change in ['uncertain', 'public', 'changedQuestion']) {
      final probe = observedExperiment();
      if (change == 'public') probe.v37.gaps.single.data['access'] = 'public';
      if (change == 'changedQuestion')
        probe.v37.gaps.single.data['question'] = '一个新的不同问题';
      final before = jsonEncode(probe.toJson());
      expect(
          () => calibrate(probe,
              verdict: change == 'uncertain' ? 'uncertain' : 'supported',
              resolve: true,
              conflictsChecked: true),
          throwsFormatException);
      expect(jsonEncode(probe.toJson()), before);
    }
  });

  test('同一问题续验复用缺口，引用不存在的问题或路径会拒绝', () {
    final c = experimentGuide();
    final id = SelfOsGuidance.latestSource(c),
        quote = SelfOsGuidance.sources(c)[id]!;
    final raw = guideResponse(id, quote, ready: true);
    final experiment = osMap(raw['experiment']);
    experiment['gapId'] = c.v37.gaps.single.id;
    experiment['routeTitle'] = c.v37.routes.first.title;
    raw['experiment'] = experiment;
    OsGuideFrame parse() => OsGuideFrame.parse(raw,
        userSources: SelfOsGuidance.sources(c),
        latestId: id,
        knownGapIds: c.v37.gaps.map((g) => g.id).toSet());
    c.guide.confirmedRevision = null;
    SelfOsGuidance.receive(c, parse(), c.guide.revision);
    SelfOsGuidance.confirm(c, 'unchanged');
    expect(c.v37.gaps, hasLength(1));
    expect(c.guide.draft['routeId'], c.v37.routes.first.id);
    experiment['gapId'] = 'fake';
    expect(parse, throwsFormatException);
    experiment['gapId'] = c.v37.gaps.single.id;
    experiment['routeTitle'] = '不存在的路线';
    expect(parse, throwsFormatException);
  });

  test('明确约定时刻不被误当现在；到时准备、完成反馈和新信息有优先次序', () {
    final c = experimentGuide();
    final now = DateTime.now(), moment = now.add(const Duration(days: 1));
    c.guide.draft['moment'] = moment.toIso8601String();
    SelfOsGuidance.commitExperiment(c);
    final i = c.v37.interventions.single;
    expect(i.dueAt(c.v37.futureMoment, now), moment);
    expect(SelfOsProgress.next(c, at: now).kind, 'act');
    c.committedAt = null;
    c.guide.confirmedRevision = null;
    expect(SelfOsProgress.next(c, at: now).kind, isNot('prepare'));
    expect(SelfOsProgress.next(c, at: moment).kind, 'prepare');
    c.v37.settings['requiresReconsideration'] = true;
    expect(SelfOsProgress.next(c, at: moment).kind, 'reconsider');
    expect(SelfOsV37Rules.gate(c.v37).mayCommit, isFalse);
  });

  for (final domain in ['转岗', '照顾家人', '学习技能', '预算安排', '共同生活', '创作计划']) {
    test('下一步按证据结构分流而非领域措辞：$domain', () {
      for (final entry in {
        'private': 'ask',
        'public': 'retrieve',
        'experience': 'experiment'
      }.entries) {
        final c = SelfOsCase(problem: '$domain：保持还是调整')..v37 = decision();
        c.v37.gaps.add(OsGap(
            {'id': 'key', 'question': '$domain 的现实条件', 'access': entry.key}));
        expect(SelfOsProgress.next(c).kind, entry.value);
        c.problem = '先调整，还是保持？$domain';
        c.v37.routes.setAll(0, c.v37.routes.reversed.toList());
        expect(SelfOsProgress.next(c).kind, entry.value);
      }
    });
  }

  test('采纳动机变化必须实际校准；AI说增强不等于数值已增强', () {
    final c = experimentGuide();
    final m = c.motives.first;
    final original = m.toJson();
    final suggestion = <String, dynamic>{
      'motiveId': m.id,
      'title': m.title,
      'change': 'strengthened',
      'reason': '仅候选'
    };
    final reviewed = SelfOsMotive.fromJson(original)..selected = false;
    SelfOsLearning.reviewMotive(c, suggestion, reviewed, '实际材料显示这个理由不再适用于该任务');
    expect(c.v37.cognitionOpen, isTrue);
    c.fields['k2'] = '该任务并没有提供更多自主空间';
    c.completeCognition('本人根据实际材料取消原动机');
    expect(osMaps(c.v37.knowledgeTraces.last['delta']).single['change'],
        'invalidated');
    expect(reviewed.predicted, isNull);
    expect(suggestion['reviewStatus'], 'reviewed');
  });

  test('校准结论和来源进入AI上下文，前后认识可恢复且不会代替原始预测', () async {
    final observed = observedExperiment()
      ..v37.settings['shareExperience'] = true;
    calibrate(observed, verdict: 'uncertain', influence: 'unchanged');
    final restored =
        SelfOsCase.fromJson(jsonDecode(jsonEncode(observed.toJson())));
    expect(SelfOsLearning.history([restored]).single['reviewId'],
        observed.reviews.single.id);
    final next = SelfOsCase(problem: '新工作也需要逐次审批');
    Map<String, dynamic>? sent;
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      sent = jsonDecode(
          prompt.substring(prompt.lastIndexOf('用户数据：') + '用户数据：'.length));
      return jsonEncode(guideResponse('problem', next.problem));
    });
    await ai.guide(next, [restored, next], SelfOsProfile());
    final observation = osMaps(sent!['calibratedObservations']).single;
    expect(observation['actual'], observed.reviews.single.result);
    expect(observation['scope'], contains('不能推广'));
    expect(observation['verdict'], 'uncertain');
    expect(observation['prediction'],
        osMap(observed.commitment!['experiment'])['prediction']);
    expect(osMap(sent!['nextStep'])['kind'], 'explore');
  });
}
