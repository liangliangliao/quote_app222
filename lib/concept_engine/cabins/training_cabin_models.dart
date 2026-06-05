import 'package:flutter/material.dart';

import '../concept_engine_models.dart';

enum TrainingCabinType {
  delayReport,
  boundaryExpression,
  selfDisciplineStart,
}

class TrainingCabinDescriptor {
  final TrainingCabinType type;
  final String id;
  final String title;
  final String subtitle;
  final String defaultConcept;
  final String defaultGoal;
  final String domain;
  final String sceneNarration;
  final String roleLabel;
  final String missionLabel;
  final List<String> mindPrimingQuestions;
  final List<String> attitudes;
  final List<String> facts;
  final List<String> risks;
  final List<String> actions;
  final List<String> expressionBlocks;
  final List<String> quickActionChips;
  final List<String> toneOptions;
  final Color color;
  final IconData icon;

  const TrainingCabinDescriptor({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.defaultConcept,
    required this.defaultGoal,
    required this.domain,
    required this.sceneNarration,
    required this.roleLabel,
    required this.missionLabel,
    required this.mindPrimingQuestions,
    required this.attitudes,
    required this.facts,
    required this.risks,
    required this.actions,
    required this.expressionBlocks,
    required this.quickActionChips,
    required this.toneOptions,
    required this.color,
    required this.icon,
  });
}

class CabinPrepState {
  final List<String> selectedFacts;
  final List<String> rankedRisks;
  final List<String> orderedActions;
  final List<String> expressionBlocks;
  final String finalAttitude;

  const CabinPrepState({
    required this.selectedFacts,
    required this.rankedRisks,
    required this.orderedActions,
    required this.expressionBlocks,
    required this.finalAttitude,
  });
}

class TrainingCabinRunDraft {
  final TrainingCabinDescriptor descriptor;
  final String concept;
  final String goal;
  final String domain;
  final String selectedAttitude;
  final List<String> selectedMindPrompts;
  final CabinPrepState prepState;
  final bool returnToActionChain;
  final String? linkedPlanId;
  final String? linkedStepId;

  const TrainingCabinRunDraft({
    required this.descriptor,
    required this.concept,
    required this.goal,
    required this.domain,
    required this.selectedAttitude,
    required this.selectedMindPrompts,
    required this.prepState,
    this.returnToActionChain = false,
    this.linkedPlanId,
    this.linkedStepId,
  });
}

class CabinAssistResult {
  final String cabinType;
  final String recommendedTone;
  final String recommendedAction;
  final String recommendedPhrase;
  final bool completed;

  const CabinAssistResult({
    required this.cabinType,
    required this.recommendedTone,
    required this.recommendedAction,
    required this.recommendedPhrase,
    required this.completed,
  });
}

class TrainingCabinCompletedRun {
  final TrainingCabinRunDraft draft;
  final SceneOption scene;
  final ChallengeWorldState finalState;
  final ReplayResult replay;
  final List<ChallengeMessage> messages;
  final List<String> actionTags;
  final List<String> triggeredEvents;
  final String provider;
  final String model;
  final String transportMode;
  final String sessionKey;
  final ConceptWorldRewardResult? reward;
  final int? recordId;

  CabinAssistResult toAssistResult() {
    final phrase = replay.betterActions.isNotEmpty
        ? replay.betterActions.first.examplePhrase
        : (messages.isNotEmpty ? messages.last.content : replay.summary);
    return CabinAssistResult(
      cabinType: draft.descriptor.id,
      recommendedTone: draft.selectedAttitude,
      recommendedAction: actionTags.isNotEmpty ? actionTags.last : draft.prepState.orderedActions.first,
      recommendedPhrase: phrase,
      completed: replay.resultLabel.contains('成功'),
    );
  }

  const TrainingCabinCompletedRun({
    required this.draft,
    required this.scene,
    required this.finalState,
    required this.replay,
    required this.messages,
    required this.actionTags,
    required this.triggeredEvents,
    required this.provider,
    required this.model,
    required this.transportMode,
    required this.sessionKey,
    required this.reward,
    this.recordId,
  });
}

const List<TrainingCabinDescriptor> trainingCabins = [
  TrainingCabinDescriptor(
    type: TrainingCabinType.delayReport,
    id: 'delay_report',
    title: '延期汇报舱',
    subtitle: '练责任感、风险预警、承担与补救。',
    defaultConcept: '责任感',
    defaultGoal: '练习在延期或失误情况下稳定汇报并提出补救方案',
    domain: '职场',
    sceneNarration: '你站在会议室门口，必须在今天说明延期事实。对方最在意的不是解释，而是你是否承担、是否清楚风险、是否给得出修复路径。',
    roleLabel: '项目负责人 / 关键执行人',
    missionLabel: '在压力下完成一次承担型汇报，并守住信任。',
    mindPrimingQuestions: [
      '你现在最想回避的事实是什么？',
      '你最怕对方追问哪一句？',
      '如果必须先说一句话，你想先承担还是先解释？',
    ],
    attitudes: ['直面问题', '先承担再解释', '稳住局面', '先止损再说明'],
    facts: [
      '项目当前已延期 3 天',
      '一项关键数据需要重算',
      '客户还不知道全部影响范围',
      '团队成员 A 出现失误但可修复',
      '如果今天不说，信任会继续下降',
      '现有资源仍可给出阶段性补救方案',
    ],
    risks: ['信任受损', '交付崩盘', '团队甩锅', '客户升级投诉', '补救窗口缩小'],
    actions: ['确认影响范围', '先承认延期', '说明原因边界', '给补救方案', '承诺下一更新时间'],
    expressionBlocks: ['开场说明', '承担责任', '关键事实', '补救动作', '明确承诺'],
    quickActionChips: ['确认责任', '给出方案', '请求时间', '澄清误解', '收束局面'],
    toneOptions: ['稳定', '承担', '坚定', '温和', '防御性'],
    color: Color(0xFFDBEAFE),
    icon: Icons.fact_check_outlined,
  ),
  TrainingCabinDescriptor(
    type: TrainingCabinType.boundaryExpression,
    id: 'boundary_expression',
    title: '边界表达舱',
    subtitle: '练边界感、不内疚地拒绝与稳定立场。',
    defaultConcept: '边界感',
    defaultGoal: '练习在有关系压力时温和但清楚地表达拒绝',
    domain: '日常生活',
    sceneNarration: '你面对一个不愿接受的请求。你担心拒绝会伤关系，但继续让步又会让自己越来越失控。',
    roleLabel: '关系中的主动回应者',
    missionLabel: '在不攻击也不过度解释的情况下，清楚表达边界。',
    mindPrimingQuestions: [
      '你最怕拒绝后被如何评价？',
      '你最容易在哪一步开始退让？',
      '你最想用哪句解释来减轻内疚？',
    ],
    attitudes: ['温和但清楚', '先理解再表达边界', '保持关系但不退让', '坚定拒绝'],
    facts: [
      '对方提出的请求超出了你的承受范围',
      '你并不是不在乎对方，而是不愿继续失衡',
      '如果这次不表达边界，以后还会重复出现',
      '对方当前情绪可能波动较大',
      '你可以提供有限支持，但不能全部承担',
      '你需要把边界说清而不是消失',
    ],
    risks: ['内疚退让', '关系施压', '过度解释', '边界模糊', '情绪升级'],
    actions: ['表达理解', '明确边界', '给出可提供范围', '停止过度解释', '重复边界'],
    expressionBlocks: ['理解对方', '明确不能', '可提供支持', '不延长拉扯', '结束循环'],
    quickActionChips: ['表达理解', '明确边界', '重申立场', '停止解释', '结束循环'],
    toneOptions: ['温和', '边界清晰', '坚定', '平稳', '防御性'],
    color: Color(0xFFFCE7F3),
    icon: Icons.shield_outlined,
  ),
  TrainingCabinDescriptor(
    type: TrainingCabinType.selfDisciplineStart,
    id: 'self_discipline_start',
    title: '自律启动舱',
    subtitle: '练启动、抗拖延、切断逃避与持续推进。',
    defaultConcept: '自律',
    defaultGoal: '练习把拖延中的任务真正启动起来并完成最小行动闭环',
    domain: '日常生活',
    sceneNarration: '你知道今天必须开始这件事，但脑中已经出现了各种拖延理由。你这次不是来想清楚，而是来启动。',
    roleLabel: '对自己负责的执行者',
    missionLabel: '识别借口、启动第一步，并在阻力下保持推进。',
    mindPrimingQuestions: [
      '你现在最想用哪一个借口推迟开始？',
      '如果只能做最小的一步，那一步是什么？',
      '你最容易在启动后的哪一分钟放弃？',
    ],
    attitudes: ['先做第一步', '只做最低可行动作', '不等状态完美', '切断借口'],
    facts: [
      '任务已经足够明确，可以开始',
      '你最大的阻力不是不会做，而是不想开始',
      '拖延会让焦虑持续增加',
      '只要启动 3 分钟，就可能明显减轻阻力',
      '你必须先切断干扰源',
      '你不需要一开始就做得完美',
    ],
    risks: ['分心刷手机', '追求完美', '继续准备不行动', '状态焦虑', '半途逃离'],
    actions: ['关掉干扰源', '锁定第一步', '开始 3 分钟', '忽略完美标准', '完成一个闭环'],
    expressionBlocks: ['识别借口', '锁定第一步', '行动承诺', '持续推进', '微小闭环'],
    quickActionChips: ['切断干扰', '开始第一步', '降低标准', '继续推进', '重新聚焦'],
    toneOptions: ['坚定', '稳定', '直接', '抗干扰', '自我安抚'],
    color: Color(0xFFEDE9FE),
    icon: Icons.directions_run_outlined,
  ),
];

TrainingCabinDescriptor cabinByType(TrainingCabinType type) => trainingCabins.firstWhere((e) => e.type == type);

TrainingCabinType? trainingCabinTypeFromId(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'delayReport':
    case 'delay_report':
      return TrainingCabinType.delayReport;
    case 'boundaryExpression':
    case 'boundary_expression':
      return TrainingCabinType.boundaryExpression;
    case 'selfDisciplineStart':
    case 'self_discipline_start':
      return TrainingCabinType.selfDisciplineStart;
    default:
      return null;
  }
}
