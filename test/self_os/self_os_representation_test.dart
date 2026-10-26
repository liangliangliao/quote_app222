import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_ai_service.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_representation_learning.dart';
import 'package:quote_app/self_os/self_os_guidance.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;
import 'self_os_guide_test.dart' show guideResponse;

const expressionChoice = {
  'format': 'timeline',
  'task': 'discomfort',
  'window': 'evening'
};
SelfOsCase expressionCase(
    {String format = 'timeline',
    String task = 'discomfort',
    String window = 'evening',
    String context = '面试前晚',
    bool feedback = true,
    String effect = 'helped',
    String attribution = 'considered'}) {
  final c = plannedCase();
  c.motives.first.occupancy = 20;
  SelfOsRepresentationLearning.adopt(c,
      choice: {'format': format, 'task': task, 'window': window},
      content: '明天到场先了解岗位，下周根据得到的信息再决定；结果仍未知。',
      source: '自己的预约记录；能否得到岗位信息待核验');
  c.motives.first.occupancy = 60;
  c.completeCognition('把可检验的信息价值带回选择');
  c.v37.settings['understandingReviewed'] = true;
  c.commit();
  c.addReview(reviewFor(c, context: context));
  if (feedback)
    SelfOsRepresentationLearning.saveFeedback(
        c.reviews.single,
        expressionNotes(c.reviews.single,
            effect: effect, attribution: attribution));
  c.guide.phase = 'learn';
  return c;
}

Map<String, String> expressionNotes(SelfOsReview r,
    {String effect = 'helped', String attribution = 'considered'}) {
  final id = SelfOsRepresentationLearning.uses(r.snapshot).single['id'];
  final prefix = 'representation.$id';
  return {
    '$prefix.understanding': effect,
    '$prefix.availability': 'notHelped',
    '$prefix.action': 'unknown',
    '$prefix.attribution': attribution,
    '$prefix.observation': '能分清眼前紧张与下周再决定，但现场仍没想起信息价值。',
    '$prefix.conditions': '只用于可离开的短时面试；睡眠、交通没有改变。'
  };
}

void main() {
  test('A38：默认引导确认后才追踪表达，实验和真实复盘共用同一闭环', () {
    final c = SelfOsCase(problem: '明早交流会很尴尬，想取消');
    SelfOsGuidance.answer(c, '只是去了解岗位，可以回来再决定');
    final latest = SelfOsGuidance.latestSource(c);
    final raw = guideResponse(latest, '只是去了解岗位，可以回来再决定', ready: true);
    raw['insight'] = {
      ...osMap(raw['insight']),
      'representation': {
        ...expressionChoice,
        'window': 'now',
        'actualEffect': 'helped',
        'verified': true
      }
    };
    final frame = OsGuideFrame.parse(raw,
        userSources: SelfOsGuidance.sources(c), latestId: latest);
    expect(osMap(frame.insight['representation']).containsKey('actualEffect'),
        isFalse);
    SelfOsGuidance.receive(c, frame, c.guide.revision);
    expect(c.v37.settings['representationUses'], isNull);
    SelfOsGuidance.confirm(c, 'toward');
    final use = osMaps(c.v37.settings['representationUses']).single;
    expect(use['window'], 'now');
    expect(use['knowledgeTraceId'], c.v37.knowledgeTraces.single['id']);
    c.guide.draft
        .addAll({'trigger': '明早出门前', 'costAccepted': true, 'reversible': true});
    SelfOsGuidance.commitExperiment(c);
    SelfOsGuidance.review(c,
        outcome: 'done',
        result: '确认可以只交流',
        learning: '这次能保留选择空间',
        context: '一次具体交流');
    expect(SelfOsRepresentationLearning.uses(c.reviews.single.snapshot),
        hasLength(1));
    expect(SelfOsRepresentationLearning.patterns([c]).single.total, 0);
    SelfOsRepresentationLearning.saveFeedback(
        c.reviews.single, expressionNotes(c.reviews.single));
    expect(SelfOsRepresentationLearning.patterns([c]).single.total, 1);
  });

  test('A38：采用前后认识、动机变化和实际复盘能沿封存快照追溯', () {
    final c = expressionCase();
    final use = SelfOsRepresentationLearning.uses(c.commitment!).single;
    expect(osMap(use['before'])['knowledge'], '面试提供一次具体反馈');
    expect(osMap(use['after'])['knowledge'], contains('下周'));
    expect(osMaps(use['motiveDelta']), isNotEmpty);
    expect(use['knowledgeTraceId'], c.v37.knowledgeTraces.single['id']);
    final p = SelfOsRepresentationLearning.patterns([c]).single;
    expect(p.helped, 1);
    expect(p.available, 0);
    expect(p.acted, 0);
    expect(p.observations.single['reviewId'], c.reviews.single.id);
    expect(p.eligible, isFalse);
  });

  test('A38：AI 文本、主观概率提高和未使用均不构成效果样本', () {
    final c = expressionCase(feedback: false);
    c.scores['revisedProbability'] = 100;
    c.suggestions['cognition'] = [
      {'field': 'k2', 'value': '一定有效'}
    ];
    final p = SelfOsRepresentationLearning.patterns([c]).single;
    expect(p.total, 0);
    expect(p.observations.single['understanding'], 'unknown');
    expect(SelfOsRepresentationLearning.recommend([c], 'discomfort', 'evening'),
        isNull);
    final notes = expressionNotes(c.reviews.single, effect: 'unknown');
    notes[notes.keys.firstWhere((k) => k.endsWith('.action'))] = 'helped';
    SelfOsRepresentationLearning.saveFeedback(c.reviews.single, notes);
    final separated = SelfOsRepresentationLearning.patterns([c]).single;
    expect(separated.total, 0);
    expect(separated.acted, 1);
    expect(separated.actionTotal, 1);
    final retrospective = plannedCase()..retrospective = true;
    expect(
        () => SelfOsRepresentationLearning.adopt(retrospective,
            choice: expressionChoice, content: '事后回忆', source: '回忆'),
        throwsFormatException);
  });

  test('A38：推荐只用同任务同窗口，保留反作用、未知和不同变化来源', () {
    final a = expressionCase(context: '周一面试');
    final b = expressionCase(context: '周二面试');
    final c = expressionCase(context: '周三面试');
    final harmed = expressionCase(context: '周四面试', effect: 'harmed');
    final confounded =
        expressionCase(context: '有人陪同', attribution: 'contextOnly');
    final unknown = expressionCase(feedback: false);
    final others = [
      for (var i = 0; i < 5; i++)
        expressionCase(
            format: 'scene', task: 'reward', window: 'onsite', context: '其他 $i')
    ];
    final history = [a, b, c, harmed, confounded, unknown, ...others];
    final best = SelfOsRepresentationLearning.recommend(
        history, 'discomfort', 'evening')!;
    expect(best.format, 'timeline');
    expect(best.total, 4);
    expect(best.helped, 3);
    expect(best.harmed, 1);
    expect(best.observations.length - best.total, 2);
    expect(SelfOsRepresentationLearning.recommend(history, 'reward', 'evening'),
        isNull);
    final alternatives = [
      for (var i = 0; i < 3; i++)
        expressionCase(format: 'counterfactual', context: '新面试 $i')
    ];
    expect(
        SelfOsRepresentationLearning.recommend(
                [...history, ...alternatives], 'discomfort', 'evening')!
            .format,
        'counterfactual');
  });

  test('A38：重复导入/保存不扩样，撤回判断或删除案例实时撤回推荐', () {
    final history = [
      for (var i = 0; i < 3; i++) expressionCase(context: '情境 $i')
    ];
    final frozen = jsonEncode(history.first.commitment);
    final r = history.first.reviews.single;
    SelfOsRepresentationLearning.saveFeedback(r, expressionNotes(r));
    expect(
        SelfOsRepresentationLearning.patterns(
            [...history, history.first.copy()]).single.total,
        3);
    SelfOsRepresentationLearning.saveFeedback(
        r, expressionNotes(r, effect: 'unknown'));
    expect(SelfOsRepresentationLearning.patterns(history).single.total, 2);
    expect(
        SelfOsRepresentationLearning.recommend(
            history, 'discomfort', 'evening'),
        isNull);
    expect(jsonEncode(history.first.commitment), frozen);
    expect(
        SelfOsRepresentationLearning.patterns(history.sublist(1)).single.total,
        2);
  });

  test('A38：反馈校验失败整体不写入，旧的粗粒度反馈不自动迁为表达证据', () {
    final c = expressionCase(feedback: false),
        r = expressionCase().reviews.single;
    final before = Map.of(r.notes);
    final notes = expressionNotes(r);
    notes[notes.keys.firstWhere((k) => k.endsWith('.observation'))] = '';
    expect(() => SelfOsRepresentationLearning.saveFeedback(r, notes),
        throwsFormatException);
    expect(r.notes, before);
    final old = plannedCase()..commit();
    old.addReview(reviewFor(old));
    expect(SelfOsRepresentationLearning.patterns([old]), isEmpty);
    expect(SelfOsRepresentationLearning.patterns([c]).single.total, 0);
  });

  test('A38：下一轮清除草稿与采用记录，保留原始历史，不补写事前反馈', () {
    final c = expressionCase();
    final frozen = jsonEncode(c.reviews.single.snapshot);
    c.nextRound();
    expect(
        c.fields.keys.where((k) => k.startsWith('representation.')), isEmpty);
    expect(c.v37.settings['representationUses'], isNull);
    expect(SelfOsRepresentationLearning.patterns([c]).single.total, 1);
    expect(jsonEncode(c.reviews.single.snapshot), frozen);
    expect(SelfOsRepresentationLearning.uses(c.evidenceSnapshot()), isEmpty);
  });

  test('A38：同一轮重复改写只留同格式一个采用记录，确认协议之后修改需重新审视', () {
    final c = plannedCase();
    for (var i = 0; i < 2; i++) {
      SelfOsRepresentationLearning.adopt(c,
          choice: expressionChoice, content: '第 $i 版', source: '自己的材料');
    }
    expect(osMaps(c.v37.settings['representationUses']), hasLength(1));
    c.completeCognition('修订表达', noChangeReason: '没有改变动机，只让时点更明确');
    c.v37.settings['understandingReviewed'] = true;
    c.commit();
    final frozen = jsonEncode(c.commitment);
    SelfOsRepresentationLearning.adopt(c,
        choice: expressionChoice, content: '新的表达', source: '新来源待核验');
    expect(c.v37.flag('requiresReconsideration'), isTrue);
    expect(jsonEncode(c.commitment), frozen);
    expect(c.commit, throwsFormatException);
  });

  test('A38：AI 获得可追溯的细分偏好；非法维度与伪造实际效果不能进入候选', () async {
    final history = [
      for (var i = 0; i < 3; i++) expressionCase(context: '面试 $i')
    ];
    final c = plannedCase()
      ..fields.addAll({
        'representation.task': 'discomfort',
        'representation.window': 'evening'
      });
    late Map<String, dynamic> input;
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      input = jsonDecode(prompt.split('用户数据：').last);
      return jsonEncode({
        'suggestions': [
          {
            'field': 'k2',
            'value': '分清现在与未来',
            'reason': '根据三个实际复盘',
            'representation': {
              ...expressionChoice,
              'verified': true,
              'actualEffect': 'helped'
            }
          },
          {
            'field': 'k2',
            'value': '另一版',
            'reason': '等待核验',
            'representation': {
              'format': 'mindReading',
              'task': 'discomfort',
              'window': 'evening'
            }
          }
        ]
      });
    });
    final rows = await ai.suggest(c, history, 'cognition');
    final preferences =
        osMap(osMap(input['personalEvidence'])['representationPreferences']);
    expect(preferences['recommendedFormat'], 'timeline');
    final pattern = osMaps(preferences['patterns']).single;
    expect(pattern['samples'], 3);
    expect(osMaps(pattern['observations']).map((o) => o['reviewId']),
        containsAll(history.map((c) => c.reviews.single.id)));
    expect(rows.first['representation'], expressionChoice);
    expect(rows.last.containsKey('representation'), isFalse);
    expect(c.v37.settings['representationUses'], isNull);
  });
}
