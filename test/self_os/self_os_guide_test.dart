import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_ai_service.dart';
import 'package:quote_app/self_os/self_os_guidance.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_v37_rules.dart';

Map<String, dynamic> guideResponse(String id, String quote,
        {bool ready = false}) =>
    {
      'understanding': ready
          ? '你并不讨厌工作内容，更困扰的是做决定时缺少自主。换工作可能有帮助，但改变协作边界也值得比较。'
          : '你想让工作有所改变，也想保住已经积累的稳定。我们先看清想离开的是什么。',
      'toward': '在工作中拥有自主空间',
      'protect': '稳定收入与已经积累的经验',
      'basis': [
        {'turnId': id, 'quote': quote}
      ],
      'risk': 'high',
      if (ready)
        'insight': {
          'before': '只有换一份工作，才可能摆脱眼前的不适',
          'after': '我可能需要更多自主空间，不一定需要换掉工作内容',
          'reason': '不喜欢的是每个决定都要审批；协作边界能否改变还不知道',
        },
      'routes': ready
          ? [
              {
                'title': '留在原岗位，调整协作边界',
                'mechanism': 'conditions',
                'benefit': '可能保留稳定并增加自主',
                'cost': '需要沟通且对方可能拒绝',
                'unknown': '主管是否愿意试着授权'
              },
              {
                'title': '了解其他岗位后再决定',
                'mechanism': 'transition',
                'benefit': '可能找到更适合的协作方式',
                'cost': '了解岗位会花时间',
                'unknown': '新岗位的实际自主空间'
              },
            ]
          : [],
      'question': ready
          ? null
          : {
              'text': '最近一次觉得想离开，发生了什么？',
              'why': '先分清需要改变的是工作内容，还是工作的方式。',
              'options': ['工作内容不喜欢', '缺少自主决定的空间', '还说不清楚'],
              'access': 'private',
            },
      'experiment': ready
          ? {
              'action': '用20分钟梳理一个小任务，向主管确认能独立决定的范围',
              'question': '协作边界能否通过一次具体沟通改善',
              'prediction': '假设：至少有一项小决定可以不再逐次审批',
              'observe': '记下得到授权和仍需审批的事项，不把一句鼓励当成授权',
              'boundary': '只花20分钟准备与沟通，不辞职、不作岗位承诺',
              'stopWhen': '对方不方便或沟通升级为冲突时暂停，重新选择时机',
              'cue': '这次只了解一个边界，不必决定整个未来',
            }
          : null,
    };

SelfOsCase readyGuide() {
  final c = SelfOsCase(problem: '想换工作，又怕后悔。');
  const answer = '我并不讨厌工作内容，只是不喜欢每个决定都要审批。';
  SelfOsGuidance.answer(c, answer);
  SelfOsGuidance.receive(
      c,
      OsGuideFrame.parse(
          guideResponse(SelfOsGuidance.latestSource(c), answer, ready: true),
          userSources: SelfOsGuidance.sources(c),
          latestId: SelfOsGuidance.latestSource(c)),
      c.guide.revision);
  return c;
}

SelfOsCase experimentGuide() {
  final c = readyGuide();
  SelfOsGuidance.confirm(c, 'toward');
  c.guide.draft.addAll(
      {'trigger': '明天下午例会后，找主管空闲时', 'costAccepted': true, 'reversible': true});
  return c;
}

SelfOsAiService scenarioAi({List<String>? purposes}) =>
    SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      purposes?.add(purpose);
      if (purpose == 'self_os.desires')
        return jsonEncode({
          'desires': [
            for (final title in ['自主', '稳定', '成长', '被尊重', '生活平衡'])
              {
                'title': title,
                'support': '原始问题中的可能性',
                'counter': '尚未了解具体情况',
                'question': '这种需要在什么时候最强？',
                'confidence': 30
              }
          ]
        });
      final input = jsonDecode(
              prompt.substring(prompt.lastIndexOf('用户数据：') + '用户数据：'.length))
          as Map<String, dynamic>;
      final id = input['latestSourceId'] as String;
      final text = input['userSources'][id] as String;
      return jsonEncode(guideResponse(id, text, ready: id != 'problem'));
    });

void main() {
  test('低风险且零缺口仍不能把空白认识判成充分', () {
    final s = SelfOsV37()..settings.addAll({'risk': 'low', 'reversible': true});
    expect(SelfOsV37Rules.gate(s).action, 'ASK');
    s.settings['understandingReviewed'] = true;
    expect(SelfOsV37Rules.gate(s).mayCommit, isFalse);
    s.settings.addAll({
      'understandingSummary': '只确认资料是否齐全',
      'remainingUnknowns': '处理时长未知，但不影响整理资料'
    });
    expect(SelfOsV37Rules.gate(s).action, 'PASS');
  });

  test('只接受真实用户引用并回应最近一次纠正，拒绝虚构依据与多问题', () {
    final c = readyGuide();
    SelfOsGuidance.answer(c, '不是能力不足，是审批范围不清楚。', correction: true);
    final latest = SelfOsGuidance.latestSource(c);
    OsGuideFrame parse(Map<String, dynamic> row) => OsGuideFrame.parse(row,
        userSources: SelfOsGuidance.sources(c), latestId: latest);
    expect(() => parse(guideResponse('problem', c.problem)),
        throwsFormatException);
    expect(() => parse(guideResponse(latest, '我曾经被裁员')), throwsFormatException);
    final row = guideResponse(latest, '审批范围不清楚');
    (row['question'] as Map)['text'] = '你想要什么？又怕什么？';
    expect(() => parse(row), throwsFormatException);
    expect(c.guide.confirmed, isFalse);
    expect(c.v37.flag('understandingReviewed'), isFalse);
    expect(c.guide.frame, isNull);
  });

  test('首次不能跳过理解直接安排动作，AI不能写入用户承诺或分数', () {
    final c = SelfOsCase(problem: '想换工作');
    expect(
        () => OsGuideFrame.parse(
            guideResponse('problem', c.problem, ready: true),
            userSources: {'problem': c.problem},
            latestId: 'problem'),
        throwsFormatException);
    final frame = OsGuideFrame.parse({
      ...guideResponse('problem', c.problem),
      'verified': true,
      'committedAt': DateTime.now().toIso8601String(),
      'scores': {'actionProbability': 99},
      'outcome': 'done'
    }, userSources: {
      'problem': c.problem
    }, latestId: 'problem');
    SelfOsGuidance.receive(c, frame, 0);
    expect(c.commitment, isNull);
    expect(c.scores, isEmpty);
    expect(c.v37.evidence, isEmpty);
    expect(c.guide.frame!.containsKey('verified'), isFalse);
  });

  test('认可解释才连接认识变化、双向动机与对称路径，不虚构证据和重要度', () {
    final c = readyGuide();
    expect(c.motives, isEmpty);
    expect(c.v37.routes, isEmpty);
    SelfOsGuidance.confirm(c, 'protect');
    expect(c.acceptedDesires, hasLength(1));
    expect(c.motives.where((m) => m.selected), hasLength(2));
    expect(c.motives.singleWhere((m) => m.side == 'against').attention,
        'foreground');
    expect(c.motives.every((m) => m.importance == null && m.occupancy == null),
        isTrue);
    expect(c.v37.knowledgeTraces, hasLength(1));
    expect(c.v37.knowledgeTraces.single['delta'], isNotEmpty);
    expect(c.v37.nodes, hasLength(4));
    expect(c.v37.evidence, isEmpty);
    expect(SelfOsV37Rules.gate(c.v37).mayCommit, isFalse);
    SelfOsGuidance.confirm(c, 'protect');
    expect(c.v37.knowledgeTraces, hasLength(1));
    c.v37.validate();
  });

  test('实验与人生承诺隔离，未确认成本或可逆性时不能封存；未知概率保持未知', () {
    final c = experimentGuide();
    c.guide.draft['costAccepted'] = false;
    expect(() => SelfOsGuidance.commitExperiment(c), throwsFormatException);
    c.guide.draft['costAccepted'] = true;
    c.guide.draft['reversible'] = false;
    expect(() => SelfOsGuidance.commitExperiment(c), throwsFormatException);
    c.guide.draft['reversible'] = true;
    SelfOsGuidance.commitExperiment(c);
    expect(c.commitment!['commitmentScope'], 'experiment');
    expect(c.scores['actionProbability'], isNull);
    expect(c.v37.text('risk'), 'unassessed');
    expect(c.v37.routes.every((r) => r.status != 'active'), isTrue);
    expect(c.commit, throwsFormatException);
    final action = c.commitment!['fields']['firstAction'];
    c.guide.draft['action'] = '后来修改的草稿';
    expect(c.commitment!['fields']['firstAction'], action);
    expect(c.commitment!['experiment']['action'], action);
  });

  test('实际反馈保留事前预期、反证和未知，不自动证明实验假设或稳定性格', () {
    final c = experimentGuide();
    SelfOsGuidance.commitExperiment(c);
    final snapshot = jsonEncode(c.commitment);
    SelfOsGuidance.review(c,
        outcome: 'partial',
        result: '只得到一个小任务的授权',
        learning: '部分审批边界可以讨论，长期是否持续还不知道',
        context: '例会后主管有空',
        actualCost: '准备与沟通用了18分钟');
    expect(jsonEncode(c.reviews.single.snapshot), snapshot);
    expect(c.v37.evidence.single.text('reviewId'), c.reviews.single.id);
    expect(c.v37.evidence.single.reliableAt(DateTime.now()), isFalse);
    expect(
        c.v37.gaps.single.resolvedBy(c.v37.evidence, DateTime.now()), isFalse);
    expect(c.guide.phase, 'learn');
    expect(c.reviews.single.effectiveMotives, isEmpty);
    expect(
        () => SelfOsGuidance.review(c,
            outcome: 'done', result: '重复', learning: '重复', context: '重复'),
        throwsFormatException);
    expect(c.reviews, hasLength(1));
    expect(c.v37.evidence, hasLength(1));
  });

  test('有明确未来时刻的实验把事前记录与实际反馈接到准备证据', () {
    final c = experimentGuide();
    c.guide.draft['moment'] =
        DateTime.now().add(const Duration(days: 1)).toIso8601String();
    SelfOsGuidance.commitExperiment(c);
    expect(c.v37.interventions.single.started, isTrue);
    expect(c.v37.interventions.single.completed, isFalse);
    SelfOsGuidance.review(c,
        outcome: 'notDone',
        result: '主管临时有事，没能沟通',
        learning: '需要先确认双方空闲时间，不能只准备自己的话',
        context: '临时加会');
    expect(c.v37.interventions.single.data['actualOutcome'], 'notDone');
    expect(c.v37.interventions.single.data['reviewId'], c.reviews.single.id);
    expect(c.v37.interventions.single.data['late'], isFalse);
  });

  test('纠正使旧方案失效，迟到分析不得覆盖新输入，封存协议保留', () {
    final c = experimentGuide();
    SelfOsGuidance.commitExperiment(c);
    final frozen = jsonEncode(c.commitment);
    final frame = OsGuideFrame.saved(c.guide.frame!);
    final oldRevision = c.guide.revision;
    SelfOsGuidance.answer(c, '主管已明确拒绝沟通，需要重新理解。', correction: true);
    expect(() => SelfOsGuidance.receive(c, frame, oldRevision),
        throwsFormatException);
    expect(() => SelfOsGuidance.commitExperiment(c), throwsFormatException);
    expect(c.v37.flag('newInformationReviewed'), isFalse);
    expect(jsonEncode(c.commitment), frozen);
  });

  test('从旧复盘入口开始下一轮也会重置引导与认识确认，保留历史证据', () {
    final c = experimentGuide();
    SelfOsGuidance.commitExperiment(c);
    SelfOsGuidance.review(c,
        outcome: 'done',
        result: '得到一项授权',
        learning: '可以先谈一个小范围',
        context: '单独沟通');
    c.v37.settings['understandingReviewed'] = true;
    c.nextRound();
    expect(c.guide.phase, 'explore');
    expect(c.guide.confirmed, isFalse);
    expect(c.guide.draft, isEmpty);
    expect(c.guide.frame, isNull);
    expect(c.v37.flag('understandingReviewed'), isFalse);
    expect(c.reviews, hasLength(1));
    expect(c.v37.evidence, hasLength(1));
  });

  test('引导状态和未发送内容往返保存，旧版本不丢失历史', () {
    final c = experimentGuide();
    c.guide.compose = '还没说完的情况';
    c.guide.draft['correcting'] = true;
    final loaded = c.copy();
    expect(loaded.guide.confirmed, isTrue);
    expect(loaded.guide.compose, '还没说完的情况');
    expect(loaded.guide.draft['correcting'], isTrue);
    expect(loaded.guide.turns, c.guide.turns);
    final old = c.toJson()..remove('guide');
    final migrated = SelfOsCase.fromJson(old);
    expect(migrated.guide.turns, isEmpty);
    expect(migrated.v37.knowledgeTraces, c.v37.knowledgeTraces);
    expect(migrated.desires.single.id, c.desires.single.id);
  });

  test('引导 AI 带入最新纠正与个人实证，不把 Why Tree 当独立欲求的依据', () async {
    final calls = <String>[];
    final c = SelfOsCase(problem: '想换工作，又怕后悔。');
    final ai = scenarioAi(purposes: calls);
    c.desires.addAll(await ai.discover(c, []));
    final first = await ai.guide(c, [], SelfOsProfile());
    expect(first.ready, isFalse);
    SelfOsGuidance.receive(c, first, c.guide.revision);
    SelfOsGuidance.answer(c, '我并不讨厌工作内容，只是不喜欢每个决定都要审批。', correction: true);
    final second = await ai.guide(c, [], SelfOsProfile());
    expect(second.ready, isTrue);
    expect(second.data['basis'][0]['turnId'], SelfOsGuidance.latestSource(c));
    expect(calls, ['self_os.desires', 'self_os.guide', 'self_os.guide']);
  });
}
