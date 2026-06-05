import 'dart:convert';
import "package:flutter/material.dart";

import 'goal_models.dart';

class GoalWorldTaskDef {
  final String taskId;
  final String title;
  final String description;

  const GoalWorldTaskDef({
    required this.taskId,
    required this.title,
    required this.description,
  });
}

class GoalWorldSceneDef {
  final String sceneId;
  final String title;
  final String subtitle;
  final String mission;
  final String inputLabel;
  final String rewardTitle;
  final String rewardDescription;
  final Color accentColor;
  final List<String> relatedSegmentIds;
  final List<GoalWorldTaskDef> tasks;

  const GoalWorldSceneDef({
    required this.sceneId,
    required this.title,
    required this.subtitle,
    required this.mission,
    required this.inputLabel,
    required this.rewardTitle,
    required this.rewardDescription,
    required this.accentColor,
    required this.relatedSegmentIds,
    required this.tasks,
  });
}

class GoalWorldSimulationChoiceDef {
  final String choiceId;
  final String title;
  final String description;
  final String reflectionPrompt;

  const GoalWorldSimulationChoiceDef({
    required this.choiceId,
    required this.title,
    required this.description,
    required this.reflectionPrompt,
  });
}

const goalWorldRoleSuggestions = <String>[
  '学生',
  '职场人',
  '创业者',
  '自由职业者',
  '求职者',
  '照护者',
  '创作者',
];

const goalWorldLifeAreas = <String>[
  '学习',
  '工作',
  '职业转型',
  '关系',
  '健康',
  '金钱',
  '个人成长',
];

const goalWorldScenes = <GoalWorldSceneDef>[
  GoalWorldSceneDef(
    sceneId: 'fog_plain',
    title: '迷雾平原',
    subtitle: '适合“我现在很迷茫，不知道该追什么”的状态。',
    mission: '先从混乱里找出一个暂时方向：区分别人期待的目标、自己真正不想失去的东西，以及眼下最值得先走的一步。',
    inputLabel: '把你在迷雾平原里找到的“暂时方向”写下来。',
    rewardTitle: '方向火种',
    rewardDescription: '完成后可把“暂时方向”同步到目标工坊，作为当前愿景与身份线索。',
    accentColor: Color(0xFF0F766E),
    relatedSegmentIds: ['PP12_16', 'ST13_10', 'ST13_09'],
    tasks: [
      GoalWorldTaskDef(
        taskId: 'fog_expectation',
        title: '辨认一个“别人期待”的目标',
        description: '先承认它存在，而不是把它误认为真实自我。',
      ),
      GoalWorldTaskDef(
        taskId: 'fog_cannot_without',
        title: '回答“我不能没有什么”',
        description: '用一句话写出你不愿长期失去的东西。',
      ),
      GoalWorldTaskDef(
        taskId: 'fog_direction',
        title: '形成一个暂时方向',
        description: '不是一辈子答案，而是接下来一段时间更想朝哪里走。',
      ),
    ],
  ),
  GoalWorldSceneDef(
    sceneId: 'mirror_lake',
    title: '镜湖',
    subtitle: '适合“我有目标，但不确定是不是属于自己”的状态。',
    mission: '围绕自我一致性做一次校准：判断目标是否真的像你、有没有让你更有能量，以及你是为了热爱还是为了迎合。',
    inputLabel: '写下：这个目标最像我的地方，或最不像我的地方。',
    rewardTitle: '清晰镜片',
    rewardDescription: '完成后可把“像我/不像我”的判断同步到目标工坊，帮助修正 why 与现实阻碍。',
    accentColor: Color(0xFF1D4ED8),
    relatedSegmentIds: ['PP12_16', 'ST13_02', 'PP12_18'],
    tasks: [
      GoalWorldTaskDef(
        taskId: 'mirror_real_me',
        title: '判断这个目标像不像真正的我',
        description: '从兴趣、价值、身份三个角度看它。',
      ),
      GoalWorldTaskDef(
        taskId: 'mirror_energy',
        title: '观察它是否带来能量',
        description: '回想做这件事时，你是更有劲还是更耗竭。',
      ),
      GoalWorldTaskDef(
        taskId: 'mirror_pressure',
        title: '分辨热爱与迎合',
        description: '这件事里有多少来自你自己，有多少只是外界压力。',
      ),
    ],
  ),
  GoalWorldSceneDef(
    sceneId: 'workshop_city',
    title: '工坊城',
    subtitle: '适合“我已经知道方向，但就是落不下来”的状态。',
    mission: '把方向打造成现实路径：把目标写下来、设 lifeline、拆成本周推进和明天第一步，再准备 if-then 应对阻碍。',
    inputLabel: '写下你准备真正落地的一步，或你现在最需要的本周推进。',
    rewardTitle: '执行蓝图',
    rewardDescription: '完成后可把本周推进与下一步同步到目标工坊，形成现实执行草稿。',
    accentColor: Color(0xFF7C3AED),
    relatedSegmentIds: ['ST13_11', 'ST13_14', 'ST13_12'],
    tasks: [
      GoalWorldTaskDef(
        taskId: 'workshop_lifeline',
        title: '设一个 lifeline',
        description: '给目标一个明确时间点，而不是“以后再说”。',
      ),
      GoalWorldTaskDef(
        taskId: 'workshop_weekly',
        title: '写出本周推进',
        description: '把长期方向压缩成这周能推进的一步。',
      ),
      GoalWorldTaskDef(
        taskId: 'workshop_ifthen',
        title: '准备一个 if-then',
        description: '提前决定：如果遇到阻碍，我先做什么。',
      ),
    ],
  ),
];

GoalWorldSceneDef sceneById(String sceneId) => goalWorldScenes.firstWhere((e) => e.sceneId == sceneId);

List<GoalWorldSimulationChoiceDef> simulationChoicesForScene({
  required GoalWorldSceneDef scene,
  required String roleTitle,
  required String lifeArea,
  required String realEvent,
  required String desiredIdentity,
}) {
  final who = roleTitle.trim().isEmpty ? '现在的你' : roleTitle.trim();
  final area = lifeArea.trim().isEmpty ? '当前生活议题' : lifeArea.trim();
  final event = realEvent.trim().isEmpty ? '你最近最在意的一件事' : realEvent.trim();
  final desired = desiredIdentity.trim().isEmpty ? '更一致地行动的人' : desiredIdentity.trim();

  switch (scene.sceneId) {
    case 'fog_plain':
      return [
        GoalWorldSimulationChoiceDef(
          choiceId: 'fog_clear_noise',
          title: '先停下比较，辨认噪音',
          description: '把“别人希望$who在$area怎么做”与“你真正不想失去什么”分开。围绕事件：$event。',
          reflectionPrompt: '如果你先不证明自己，只问“我不能没有什么”，你的方向会怎么变？',
        ),
        GoalWorldSimulationChoiceDef(
          choiceId: 'fog_keep_small_fire',
          title: '先保护一团小火',
          description: '不急着找终极答案，而是先保护那件还能让你保持生命感的小事。它正在指向：$desired。',
          reflectionPrompt: '哪件小事虽然不宏大，却最像你真正想守住的东西？',
        ),
        GoalWorldSimulationChoiceDef(
          choiceId: 'fog_choose_temp_direction',
          title: '先做一个阶段性选择',
          description: '接受“暂时方向”也有价值。就围绕“$event”决定接下来 2 周先朝哪边走。',
          reflectionPrompt: '如果只为接下来的两周负责，你愿意先试着往哪里走？',
        ),
      ];
    case 'mirror_lake':
      return [
        GoalWorldSimulationChoiceDef(
          choiceId: 'mirror_energy_check',
          title: '用能量感检查目标',
          description: '把事件“$event”代入目标里，问：做这件事时，我是在靠近 $desired，还是只是在耗竭自己？',
          reflectionPrompt: '这个目标在你身上最像“热爱”还是“迎合”？为什么？',
        ),
        GoalWorldSimulationChoiceDef(
          choiceId: 'mirror_identity_check',
          title: '用身份感检查目标',
          description: '不是问“值不值得做”，而是问：这是不是像$who在$area里真正愿意活出的样子。',
          reflectionPrompt: '这个目标最像你的地方是什么？最不像你的地方又是什么？',
        ),
        GoalWorldSimulationChoiceDef(
          choiceId: 'mirror_pressure_check',
          title: '拆开热爱与压力',
          description: '把目标里混杂的外界期待拆出来，看看事件“$event”里究竟有哪些是你真的想要的。',
          reflectionPrompt: '如果没有外界评价，你还会不会继续追这个目标？',
        ),
      ];
    default:
      return [
        GoalWorldSimulationChoiceDef(
          choiceId: 'workshop_breakdown',
          title: '先把目标拆到这周',
          description: '围绕事件“$event”，把长期方向压缩成$who在$area里这周就能做的一步。',
          reflectionPrompt: '如果你只能做一件最小但真实的推进，它会是什么？',
        ),
        GoalWorldSimulationChoiceDef(
          choiceId: 'workshop_ifthen',
          title: '提前写好 if-then',
          description: '不要等拖延出现再补救。先为$event准备一个 if-then，让行动更像$desired。',
          reflectionPrompt: '当你最常见的阻碍出现时，你准备先做什么？',
        ),
        GoalWorldSimulationChoiceDef(
          choiceId: 'workshop_lifeline',
          title: '给行动一个生命线',
          description: '把“以后再说”变成一个可兑现的 lifeline，让$who在$area里真正开始。',
          reflectionPrompt: '你愿意把这一步放到哪一天之前完成？',
        ),
      ];
  }
}


class GoalWorldRoleStatus {
  final int clarity;
  final int alignment;
  final int momentum;
  final String headline;
  final String nextFocus;

  const GoalWorldRoleStatus({
    required this.clarity,
    required this.alignment,
    required this.momentum,
    required this.headline,
    required this.nextFocus,
  });
}

class GoalWorldBranchOutcomeDef {
  final String title;
  final String immediateEffect;
  final String likelyRisk;
  final String realityExperiment;
  final String statusHint;

  const GoalWorldBranchOutcomeDef({
    required this.title,
    required this.immediateEffect,
    required this.likelyRisk,
    required this.realityExperiment,
    required this.statusHint,
  });
}

class GoalWorldBranchTaskDef {
  final String taskId;
  final String title;
  final String description;

  const GoalWorldBranchTaskDef({
    required this.taskId,
    required this.title,
    required this.description,
  });
}

class GoalWorldRecommendationRule {
  final List<String> preferredSegmentIds;
  final List<String> preferredActionLevels;
  final String recommendationHint;

  const GoalWorldRecommendationRule({
    required this.preferredSegmentIds,
    required this.preferredActionLevels,
    required this.recommendationHint,
  });
}

List<GoalWorldBranchTaskDef> branchTasksForSceneChoice({required String sceneId, required String choiceId}) {
  switch (choiceId) {
    case 'fog_clear_noise':
      return const [
        GoalWorldBranchTaskDef(
          taskId: 'fog_branch_noise_list',
          title: '列出 2 个“外界噪音”',
          description: '把比较、迎合或恐惧写出来，让它们从模糊压迫变成可辨认对象。',
        ),
        GoalWorldBranchTaskDef(
          taskId: 'fog_branch_keep_core',
          title: '守住 1 个“不能没有”的方向线索',
          description: '把最不愿失去的东西写成一句本周提醒。',
        ),
      ];
    case 'fog_keep_small_fire':
      return const [
        GoalWorldBranchTaskDef(
          taskId: 'fog_branch_fire_time',
          title: '为小火种预留 20 分钟',
          description: '先给那件最能点亮你的事留出真实时间。',
        ),
        GoalWorldBranchTaskDef(
          taskId: 'fog_branch_no_judge',
          title: '练习“不评价它够不够大”',
          description: '只确认它是否让你活过来，而不是先证明它多重要。',
        ),
      ];
    case 'fog_choose_temp_direction':
      return const [
        GoalWorldBranchTaskDef(
          taskId: 'fog_branch_two_weeks',
          title: '把方向限定在“接下来两周”',
          description: '不要替一辈子负责，只替接下来的两周负责。',
        ),
        GoalWorldBranchTaskDef(
          taskId: 'fog_branch_first_step',
          title: '把阶段方向落成第一步',
          description: '写出“这周第一步”，让方向真正开始移动。',
        ),
      ];
    case 'mirror_energy_check':
      return const [
        GoalWorldBranchTaskDef(
          taskId: 'mirror_branch_energy_before_after',
          title: '记录 3 次行动前后能量变化',
          description: '只写事实：做之前什么状态，做之后什么状态。',
        ),
        GoalWorldBranchTaskDef(
          taskId: 'mirror_branch_energy_pattern',
          title: '归纳一个“续航/耗竭”模式',
          description: '判断这条路更多是在给你续航，还是在消耗你。',
        ),
      ];
    case 'mirror_identity_check':
      return const [
        GoalWorldBranchTaskDef(
          taskId: 'mirror_branch_like_me',
          title: '写下“最像我的 1 点”',
          description: '不是泛泛评价，而是写出最像你的具体部分。',
        ),
        GoalWorldBranchTaskDef(
          taskId: 'mirror_branch_not_like_me',
          title: '写下“最不像我的 1 点”并准备调整',
          description: '把那一处不一致写出来，作为下一个修正入口。',
        ),
      ];
    case 'mirror_pressure_check':
      return const [
        GoalWorldBranchTaskDef(
          taskId: 'mirror_branch_split_columns',
          title: '把目标拆成“两列”',
          description: '一列写“我真想要”，一列写“别人希望我有”。',
        ),
        GoalWorldBranchTaskDef(
          taskId: 'mirror_branch_pick_own',
          title: '只为“我真想要”的那列写一条本周推进',
          description: '让方向重新回到自己手里。',
        ),
      ];
    case 'workshop_breakdown':
      return const [
        GoalWorldBranchTaskDef(
          taskId: 'workshop_branch_weekly_focus',
          title: '把目标压成一句“这周只推进什么”',
          description: '只保留本周最重要的一步。',
        ),
        GoalWorldBranchTaskDef(
          taskId: 'workshop_branch_schedule',
          title: '把这一推进写进日程',
          description: '不要只留在脑中，给它一个真实发生的位置。',
        ),
      ];
    case 'workshop_ifthen':
      return const [
        GoalWorldBranchTaskDef(
          taskId: 'workshop_branch_blocker',
          title: '选出最常见的一类阻碍',
          description: '先只盯最容易让你停下的一种阻碍。',
        ),
        GoalWorldBranchTaskDef(
          taskId: 'workshop_branch_script',
          title: '为它写 1 条 if-then 脚本',
          description: '把“如果……那么我先……”写成一句可执行的话。',
        ),
      ];
    case 'workshop_lifeline':
      return const [
        GoalWorldBranchTaskDef(
          taskId: 'workshop_branch_one_lifeline',
          title: '只给最重要的一步设 lifeline',
          description: '不要同时给所有事设期限，先抓最重要的一步。',
        ),
        GoalWorldBranchTaskDef(
          taskId: 'workshop_branch_check_pressure',
          title: '检查这个 lifeline 会不会把你压垮',
          description: '确认它足够真实，而不是只让你更想逃。',
        ),
      ];
    default:
      return const <GoalWorldBranchTaskDef>[];
  }
}

GoalWorldRecommendationRule recommendationRuleForChoice(String choiceId) {
  switch (choiceId) {
    case 'fog_clear_noise':
      return const GoalWorldRecommendationRule(
        preferredSegmentIds: ['PP12_16', 'ST13_10', 'ST13_09'],
        preferredActionLevels: ['微行动', '标准行动'],
        recommendationHint: '这条分支更适合先做“辨认真实方向、区分外界期待”的动作，再进入更大的承诺。',
      );
    case 'fog_keep_small_fire':
      return const GoalWorldRecommendationRule(
        preferredSegmentIds: ['PP12_18', 'PP12_19', 'PP12_17'],
        preferredActionLevels: ['微行动', '进阶行动'],
        recommendationHint: '这条分支更适合保护内在火种、意义感和最想守住的东西，不急着上难度。',
      );
    case 'fog_choose_temp_direction':
      return const GoalWorldRecommendationRule(
        preferredSegmentIds: ['ST13_11', 'ST13_14', 'PP12_17'],
        preferredActionLevels: ['标准行动', '微行动'],
        recommendationHint: '这条分支更适合把“暂时方向”压成本周推进和第一步，快速把犹豫变成行动。',
      );
    case 'mirror_energy_check':
      return const GoalWorldRecommendationRule(
        preferredSegmentIds: ['ST13_06', 'ST13_02', 'PP12_11'],
        preferredActionLevels: ['微行动', '标准行动'],
        recommendationHint: '这条分支更适合先记录能量变化，用证据而不是情绪判断目标是否给你续航。',
      );
    case 'mirror_identity_check':
      return const GoalWorldRecommendationRule(
        preferredSegmentIds: ['PP12_16', 'ST13_06', 'ST13_02'],
        preferredActionLevels: ['标准行动', '进阶行动'],
        recommendationHint: '这条分支更适合继续做一致性校准：像不像我，哪里像，哪里不像。',
      );
    case 'mirror_pressure_check':
      return const GoalWorldRecommendationRule(
        preferredSegmentIds: ['ST13_10', 'PP12_19', 'PP12_20'],
        preferredActionLevels: ['标准行动', '微行动'],
        recommendationHint: '这条分支更适合拆开外界期待与真实想要，让现实推进重新站回自己这边。',
      );
    case 'workshop_breakdown':
      return const GoalWorldRecommendationRule(
        preferredSegmentIds: ['ST13_14', 'ST13_11', 'ST13_13'],
        preferredActionLevels: ['标准行动', '微行动'],
        recommendationHint: '这条分支更适合马上做拆解、计划和一步一步推进的现实动作。',
      );
    case 'workshop_ifthen':
      return const GoalWorldRecommendationRule(
        preferredSegmentIds: ['ST13_11', 'ST13_14', 'PP12_04'],
        preferredActionLevels: ['标准行动', '进阶行动'],
        recommendationHint: '这条分支更适合提前脚本化阻碍，把“最容易卡住的时候”也纳入执行系统。',
      );
    case 'workshop_lifeline':
      return const GoalWorldRecommendationRule(
        preferredSegmentIds: ['ST13_11', 'ST13_12', 'ST13_14'],
        preferredActionLevels: ['标准行动', '微行动'],
        recommendationHint: '这条分支更适合给最重要的一步设边界清晰但不过满的生命线。',
      );
    default:
      return const GoalWorldRecommendationRule(
        preferredSegmentIds: <String>[],
        preferredActionLevels: ['标准行动', '微行动', '进阶行动'],
        recommendationHint: '先做一条最贴近当前场景收获的现实行动，不要让理解停在页面里。',
      );
  }
}


GoalWorldIdentityEvolution computeWorldIdentityEvolution({
  required GoalWorldProfile profile,
  required List<GoalWorldSceneProgress> progressList,
  required GoalWorldGrowthTrajectory trajectory,
}) {
  final status = computeWorldRoleStatus(profile: profile, progressList: progressList);
  final rewarded = progressList.where((e) => e.rewardClaimed).length;
  final simulated = progressList.where((e) => e.simulationChoiceId.trim().isNotEmpty).length;
  final translated = progressList.where((e) => e.realityNote.trim().isNotEmpty).length;
  String stageKey;
  String stageTitle;
  String stageSubtitle;
  String headline;
  final evidence = <String>[];

  if (!profile.hasContent) {
    stageKey = 'unnamed_wanderer';
    stageTitle = '尚未命名的旅人';
    stageSubtitle = '先把真实世界带进来';
    headline = '你正在从“还没真正命名自己现在是谁”走向“敢于承认自己正在经历什么”。';
    evidence.addAll(const [
      '补全现实角色与主战场',
      '写下最近一个真实事件',
      '写下想练习成为什么样的人',
    ]);
  } else if (rewarded >= 2 && status.alignment >= 60 && status.momentum >= 55 && trajectory.hasData) {
    stageKey = 'embodied_practitioner';
    stageTitle = '正在成为更稳定的践行者';
    stageSubtitle = '你开始把试验场的练习稳定带回现实';
    headline = '你不只是会理解这些概念，而是开始持续把方向、一致性和行动势能活出来。';
  } else if (status.momentum >= 55 || rewarded >= 1) {
    stageKey = 'path_builder';
    stageTitle = '正在成为会推进的人';
    stageSubtitle = '你开始把清晰感压成可执行的路径';
    headline = '你已经不只是想清楚，而是在练习把目标真正往前推。';
  } else if (status.alignment >= 50 || translated > 0) {
    stageKey = 'self_aligner';
    stageTitle = '正在成为更一致的人';
    stageSubtitle = '你开始辨认什么更像自己';
    headline = '你正在把“看起来正确”慢慢校准成“更像自己、更能持续”的路径。';
  } else if (status.clarity >= 35 || simulated > 0) {
    stageKey = 'signal_reader';
    stageTitle = '正在成为能辨认方向的人';
    stageSubtitle = '你开始从噪音里看见更真实的信号';
    headline = '你正在训练自己，不再只被外界推着走，而是开始听见对你真正重要的东西。';
  } else {
    stageKey = 'reality_facer';
    stageTitle = '正在成为敢于直面现实的人';
    stageSubtitle = '你开始把真实处境带进试验场';
    headline = '现在最重要的成长，不是更快给出答案，而是停止逃开自己眼前的真实处境。';
  }

  if (profile.desiredIdentity.trim().isNotEmpty) {
    evidence.add('你想练习成为：${profile.desiredIdentity.trim()}');
  }
  if (profile.realEvent.trim().isNotEmpty) {
    evidence.add('当前真实事件：${profile.realEvent.trim()}');
  }
  if (simulated > 0) {
    evidence.add('已做过 $simulated 次世界内决策模拟');
  }
  if (translated > 0) {
    evidence.add('已把 $translated 次场景收获翻译回现实');
  }
  if (trajectory.hasData) {
    final pieces = <String>[];
    if (trajectory.clarityDelta != 0) pieces.add('清晰度${trajectory.clarityDelta > 0 ? '+' : ''}${trajectory.clarityDelta}');
    if (trajectory.alignmentDelta != 0) pieces.add('一致性${trajectory.alignmentDelta > 0 ? '+' : ''}${trajectory.alignmentDelta}');
    if (trajectory.momentumDelta != 0) pieces.add('行动势能${trajectory.momentumDelta > 0 ? '+' : ''}${trajectory.momentumDelta}');
    if (pieces.isNotEmpty) evidence.add('最近成长变化：${pieces.join('，')}');
  }
  if (evidence.isEmpty) {
    evidence.add('先进入任意一个场景做一次选择，让身份演化开始拥有真实证据。');
  }

  return GoalWorldIdentityEvolution(
    stageKey: stageKey,
    stageTitle: stageTitle,
    stageSubtitle: stageSubtitle,
    headline: headline,
    evidenceJson: jsonEncode(evidence),
    updatedAtMs: DateTime.now().millisecondsSinceEpoch,
  );
}

int _clampPercent(num value) {
  if (value < 0) return 0;
  if (value > 100) return 100;
  return value.round();
}

GoalWorldRoleStatus computeWorldRoleStatus({
  required GoalWorldProfile profile,
  required List<GoalWorldSceneProgress> progressList,
}) {
  final filled = profile.completionRate;
  final rewarded = progressList.where((e) => e.rewardClaimed).length;
  final simulated = progressList.where((e) => e.simulationChoiceId.trim().isNotEmpty).length;
  final notes = progressList.where((e) => e.realityNote.trim().isNotEmpty).length;
  final reflections = progressList.where((e) => e.simulationReflection.trim().isNotEmpty).length;
  final totalTasks = goalWorldScenes.fold<int>(0, (sum, e) => sum + e.tasks.length);
  final doneTasks = progressList.fold<int>(0, (sum, e) => sum + e.completedTaskIds.length);
  final taskRatio = totalTasks == 0 ? 0.0 : doneTasks / totalTasks;

  final clarity = _clampPercent((filled * 55) + (notes * 10) + (simulated * 8));
  final alignment = _clampPercent((filled * 40) + (reflections * 14) + (rewarded * 10) + (profile.desiredIdentity.trim().isNotEmpty ? 12 : 0));
  final momentum = _clampPercent((taskRatio * 65) + (rewarded * 12) + (notes * 8));

  String headline;
  if (clarity >= 70 && alignment >= 70 && momentum >= 60) {
    headline = '你正在把真实生活稳稳搬进试验场。';
  } else if (clarity < 45) {
    headline = '现在最需要的不是更努力，而是先看清自己站在哪。';
  } else if (alignment < 50) {
    headline = '方向已经浮现，但还需要再校准：这条路到底像不像你。';
  } else {
    headline = '你已经有方向感，下一步要把它继续压到现实动作。';
  }

  String nextFocus;
  if (profile.realEvent.trim().isEmpty) {
    nextFocus = '先补全一个最近真实事件，场景分支才会更贴近你。';
  } else if (simulated == 0) {
    nextFocus = '至少在一个场景里做一次决策模拟，再把选择翻译回现实。';
  } else if (rewarded == 0) {
    nextFocus = '完成任一场景并领取奖励，把试验场的收获同步回工坊或现实行动。';
  } else {
    nextFocus = '挑一个最近刚领完奖励的场景，把那条推荐现实行动真的做掉。';
  }

  return GoalWorldRoleStatus(
    clarity: clarity,
    alignment: alignment,
    momentum: momentum,
    headline: headline,
    nextFocus: nextFocus,
  );
}

GoalWorldBranchOutcomeDef? branchOutcomeForSceneChoice({
  required GoalWorldSceneDef scene,
  required GoalWorldProfile profile,
  required String choiceId,
  required String reflection,
}) {
  if (choiceId.trim().isEmpty) return null;
  final desired = profile.desiredIdentity.trim().isEmpty ? '更一致地行动的人' : profile.desiredIdentity.trim();
  final event = profile.realEvent.trim().isEmpty ? '眼前最重要的现实议题' : profile.realEvent.trim();
  final feeling = profile.currentFeeling.trim().isEmpty ? '当前的拉扯感' : profile.currentFeeling.trim();

  switch (choiceId) {
    case 'fog_clear_noise':
      return GoalWorldBranchOutcomeDef(
        title: '结果分支：先剥离噪音',
        immediateEffect: '短期内你会更快看见：哪些声音只是比较、迎合或恐惧，哪些才是和 $event 真正有关的方向信号。',
        likelyRisk: '风险是：你可能因为一时没有终极答案而觉得不安，又重新退回对别人标准的依赖。',
        realityExperiment: '现实实验：今天写下 1 条“别人期待我做”的路径，再写下 1 条“我真正不想失去”的方向，然后只为后者做一个最小动作。',
        statusHint: '这条分支最能提升你的清晰度，让 $feeling 先变成可辨认的信号，而不是纯消耗。',
      );
    case 'fog_keep_small_fire':
      return GoalWorldBranchOutcomeDef(
        title: '结果分支：先守住一团小火',
        immediateEffect: '你不会立刻拥有终极地图，但会先保住一件还能让你靠近 “$desired” 的小事。',
        likelyRisk: '风险是：如果你太急着证明这件小事“足够大”，它又会被外界评价吞回去。',
        realityExperiment: '现实实验：未来 48 小时里，给那件最能点亮你的小事预留 20 分钟，只负责守住它，不评价它大不大。',
        statusHint: '这条分支更像在恢复内在火种，先让生命感回来，再谈大方向。',
      );
    case 'fog_choose_temp_direction':
      return GoalWorldBranchOutcomeDef(
        title: '结果分支：先做阶段性选择',
        immediateEffect: '你会用一个“暂时方向”替代无限摇摆，这能快速提升行动感和现实推进感。',
        likelyRisk: '风险是：把阶段性选择误当成终局承诺，然后因为害怕选错而再次停住。',
        realityExperiment: '现实实验：只为未来两周设一个方向，不许加“永远”。然后写下本周第一步。',
        statusHint: '这条分支最能提升行动动量，特别适合现在卡在犹豫里的人。',
      );
    case 'mirror_energy_check':
      return GoalWorldBranchOutcomeDef(
        title: '结果分支：用能量感校准目标',
        immediateEffect: '你会更快看见：这个目标是在给你续航，还是只让你持续耗竭。',
        likelyRisk: '风险是：把“累”误判成“不适合”。有些累来自成长，不一定来自错路。',
        realityExperiment: '现实实验：连续 3 次记录做这件事前后的能量变化，只写事实，不下结论。',
        statusHint: '这条分支最能提升你对自身状态的敏感度，帮助你把感觉变成证据。',
      );
    case 'mirror_identity_check':
      return GoalWorldBranchOutcomeDef(
        title: '结果分支：用身份感校准目标',
        immediateEffect: '你会更清楚这个目标到底像不像你，也更容易分辨哪些努力其实只是扮演别人眼中的好样子。',
        likelyRisk: '风险是：为了避免外界评价，过早否定一条本来值得再走近一点的路。',
        realityExperiment: '现实实验：写下“这个目标最像我的 1 点”和“最不像我的 1 点”，然后只针对后者做一次路径调整。',
        statusHint: '这条分支最能提升一致性，让方向感从“对不对”变成“像不像我”。',
      );
    case 'mirror_pressure_check':
      return GoalWorldBranchOutcomeDef(
        title: '结果分支：拆开热爱与压力',
        immediateEffect: '你会更清楚：在 $event 里，到底哪些是自己真想要，哪些只是外界推着你跑。',
        likelyRisk: '风险是：一旦拆出太多外界压力，可能会短暂感到失重，不知道接下来该靠什么站稳。',
        realityExperiment: '现实实验：把当前目标拆成“我真想要”和“别人希望我有”的两列，然后为第一列单独设一条本周推进。',
        statusHint: '这条分支最能降低迎合感，帮你把方向重新放回自己手里。',
      );
    case 'workshop_breakdown':
      return GoalWorldBranchOutcomeDef(
        title: '结果分支：先拆到本周',
        immediateEffect: '你会更快从抽象目标切到现实动作，把拖延感压缩成一个可执行的台阶。',
        likelyRisk: '风险是：如果拆得太细但没有 why 支撑，很容易把行动做成机械勾选。',
        realityExperiment: '现实实验：把眼前目标压成一句“这周只推进什么”，并写进日程。',
        statusHint: '这条分支最能提升推进感，适合已经知道方向但总落不下来的人。',
      );
    case 'workshop_ifthen':
      return GoalWorldBranchOutcomeDef(
        title: '结果分支：提前写好 if-then',
        immediateEffect: '你会更快把“阻碍出现时怎么办”提前脚本化，减少临场崩掉的概率。',
        likelyRisk: '风险是：if-then 写得太理想化，真正卡住时仍然不愿执行。',
        realityExperiment: '现实实验：只为最常见的一类阻碍写 1 条 if-then，并在下次触发时立刻照着做。',
        statusHint: '这条分支最能增强可持续性，让行动不完全依赖当下状态。',
      );
    case 'workshop_lifeline':
      return GoalWorldBranchOutcomeDef(
        title: '结果分支：先设生命线',
        immediateEffect: '你会把“以后再说”压成一个有时间边界的承诺，行动开始有了真实抓手。',
        likelyRisk: '风险是：把 lifeline 设得过满，反而让自己因为压力过大而回避。',
        realityExperiment: '现实实验：只给当前最重要的一步设一个 lifeline，而不是给所有事都设期限。',
        statusHint: '这条分支最能帮你从想法进入承诺，让执行真正有开始的时点。',
      );
    default:
      return GoalWorldBranchOutcomeDef(
        title: '结果分支：把选择带回现实',
        immediateEffect: '你已经从试验场里做出了一个方向判断，下一步是把它变成现实动作。',
        likelyRisk: '风险是：只停留在理解，不真正执行。',
        realityExperiment: '现实实验：把你刚写下的一步安排到接下来 24 小时里。',
        statusHint: '你现在最需要的，不是再理解更多，而是让这一步真的发生。',
      );
  }
}


class GoalWorldSceneStateShift {
  final String affectedSceneId;
  final String title;
  final String description;
  final String stateLabel;

  const GoalWorldSceneStateShift({
    required this.affectedSceneId,
    required this.title,
    required this.description,
    required this.stateLabel,
  });
}

String choiceTitleForSceneChoice({required GoalWorldSceneDef scene, required String choiceId}) {
  for (final item in simulationChoicesForScene(
    scene: scene,
    roleTitle: '',
    lifeArea: '',
    realEvent: '',
    desiredIdentity: '',
  )) {
    if (item.choiceId == choiceId) return item.title;
  }
  return '做出了一次分支选择';
}

List<GoalWorldSceneStateShift> sceneStateShiftsForChoice({
  required String sceneId,
  required String choiceId,
  required GoalWorldProfile profile,
}) {
  switch (choiceId) {
    case 'fog_clear_noise':
      return const [
        GoalWorldSceneStateShift(
          affectedSceneId: 'mirror_lake',
          title: '镜湖进入「降噪校准」状态',
          description: '下一次进入镜湖时，会更适合优先辨认外界期待、比较和真实目标之间的边界。',
          stateLabel: '降噪校准',
        ),
      ];
    case 'fog_keep_small_fire':
      return const [
        GoalWorldSceneStateShift(
          affectedSceneId: 'mirror_lake',
          title: '镜湖进入「火种守护」状态',
          description: '下一次进入镜湖时，会更适合先检查这条路是否持续给你能量和生命感。',
          stateLabel: '火种守护',
        ),
      ];
    case 'fog_choose_temp_direction':
      return const [
        GoalWorldSceneStateShift(
          affectedSceneId: 'mirror_lake',
          title: '镜湖进入「阶段校准」状态',
          description: '下一次进入镜湖时，会更适合围绕最近两周的暂时方向做轻量校准，而不是一次把一辈子想清楚。',
          stateLabel: '阶段校准',
        ),
      ];
    case 'mirror_energy_check':
      return const [
        GoalWorldSceneStateShift(
          affectedSceneId: 'workshop_city',
          title: '工坊城进入「续航执行」状态',
          description: '下一次进入工坊城时，会更适合把真正能给你续航的那一部分压成每周推进。',
          stateLabel: '续航执行',
        ),
      ];
    case 'mirror_identity_check':
      return const [
        GoalWorldSceneStateShift(
          affectedSceneId: 'workshop_city',
          title: '工坊城进入「身份修正」状态',
          description: '下一次进入工坊城时，会更适合先调整路径，让行动方式更像真正的你。',
          stateLabel: '身份修正',
        ),
      ];
    case 'mirror_pressure_check':
      return const [
        GoalWorldSceneStateShift(
          affectedSceneId: 'workshop_city',
          title: '工坊城进入「去迎合执行」状态',
          description: '下一次进入工坊城时，会更适合把“我真想要”的那部分单独变成现实计划。',
          stateLabel: '去迎合执行',
        ),
      ];
    case 'workshop_breakdown':
      return const [
        GoalWorldSceneStateShift(
          affectedSceneId: 'fog_plain',
          title: '迷雾平原进入「执行回环」状态',
          description: '下一次回到迷雾平原时，会更适合检视：正在执行的方向是否仍然值得继续。',
          stateLabel: '执行回环',
        ),
      ];
    case 'workshop_ifthen':
      return const [
        GoalWorldSceneStateShift(
          affectedSceneId: 'fog_plain',
          title: '迷雾平原进入「阻碍预警」状态',
          description: '下一次回到迷雾平原时，会更适合辨认：什么阻碍最常把你从真实方向上拉开。',
          stateLabel: '阻碍预警',
        ),
      ];
    case 'workshop_lifeline':
      return const [
        GoalWorldSceneStateShift(
          affectedSceneId: 'fog_plain',
          title: '迷雾平原进入「时间边界回看」状态',
          description: '下一次回到迷雾平原时，会更适合检查：你给自己的生命线，是点燃了行动，还是压垮了自己。',
          stateLabel: '时间边界回看',
        ),
      ];
    default:
      return const <GoalWorldSceneStateShift>[];
  }
}

GoalWorldSceneStateShift? incomingSceneStateShift({
  required String sceneId,
  required List<GoalWorldSceneProgress> progressList,
  required GoalWorldProfile profile,
}) {
  GoalWorldSceneStateShift? latest;
  var latestAt = 0;
  for (final item in progressList) {
    if (!item.rewardClaimed || item.simulationChoiceId.trim().isEmpty) continue;
    for (final shift in sceneStateShiftsForChoice(
      sceneId: item.sceneId,
      choiceId: item.simulationChoiceId,
      profile: profile,
    )) {
      if (shift.affectedSceneId == sceneId && item.updatedAtMs >= latestAt) {
        latest = shift;
        latestAt = item.updatedAtMs;
      }
    }
  }
  return latest;
}
