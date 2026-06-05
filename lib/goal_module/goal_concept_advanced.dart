import 'dart:convert';

import 'goal_models.dart';

class GoalMisconceptionItem {
  final String myth;
  final String correction;
  final String hint;

  const GoalMisconceptionItem({
    required this.myth,
    required this.correction,
    required this.hint,
  });
}

class GoalQuizQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const GoalQuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class GoalActionTier {
  final String levelLabel;
  final String emphasis;
  final GoalActionTemplate action;

  const GoalActionTier({
    required this.levelLabel,
    required this.emphasis,
    required this.action,
  });
}

List<GoalMisconceptionItem> buildConceptMisconceptions(GoalConceptCard concept) {
  return [
    GoalMisconceptionItem(
      myth: '“${concept.conceptTitle}”只要看懂就够了。',
      correction: '真正有效的是把理解转成一次可验证的小行动，再通过反馈修正。',
      hint: '先做一次最小实践，而不是只停留在理解层。',
    ),
    GoalMisconceptionItem(
      myth: '这个概念只有在状态特别好、意志力很强的时候才用得上。',
      correction: '课程强调的是结构、提问方式和微行动，它们正是为了在现实不完美时也能使用。',
      hint: '把门槛降到可以在今天开始。',
    ),
    GoalMisconceptionItem(
      myth: '只要结果做出来，过程怎么熬都无所谓。',
      correction: concept.whyItMatters,
      hint: '回到“为什么重要”和“怎样让旅程更可持续”。',
    ),
  ];
}

List<GoalQuizQuestion> buildConceptQuiz(GoalConceptCard concept, GoalCourseSegment? segment) {
  final segmentTitle = segment?.sectionTitle ?? '对应课程正文';
  return [
    GoalQuizQuestion(
      prompt: '下面哪一句最符合“${concept.conceptTitle}”？',
      options: [
        concept.oneLineDefinition,
        '只要先把结果想大一点，过程自然会变好。',
        '先等条件完美再开始，才比较稳妥。',
      ],
      correctIndex: 0,
      explanation: '这张概念卡的一句话定义就是本概念最核心的判断。',
    ),
    GoalQuizQuestion(
      prompt: '学完“${concept.conceptTitle}”后，最合适的下一步是什么？',
      options: [
        concept.interactionType,
        '先收藏起来，等以后有空再系统做。',
        '把行动完全交给别人来提醒或推动。',
      ],
      correctIndex: 0,
      explanation: '课程强调要把概念立即转成一次小而真的练习。来源段落：$segmentTitle。',
    ),
  ];
}

List<GoalActionTier> buildActionTiers(GoalConceptCard concept, List<GoalActionTemplate> actions) {
  if (actions.isEmpty) return const [];
  final base = actions.first;
  final baseSteps = base.steps;
  final microSteps = <String>[];
  if (baseSteps.isNotEmpty) microSteps.add(baseSteps.first);
  if (baseSteps.length > 1) microSteps.add(baseSteps[1]);
  if (microSteps.isEmpty) microSteps.add('把这个概念转成今天能开始的一步。');

  final advancedSteps = <String>[
    ...baseSteps,
    '执行完成后，记录这次做法最顺手和最卡的一点。',
    '把这次经验转成一个下周仍可重复的仪式。',
  ];

  return [
    GoalActionTier(
      levelLabel: '微行动',
      emphasis: '先把门槛降到今天就能开始，目标是启动。',
      action: GoalActionTemplate(
        actionId: '${base.actionId}__micro',
        segmentId: base.segmentId,
        conceptId: base.conceptId,
        actionTitle: '微行动：${base.actionTitle}',
        actionLevel: '微行动',
        goalOfAction: '先启动一次与“${concept.conceptTitle}”相关的最小实践。',
        stepsJson: jsonEncode(microSteps),
        durationMin: microSteps.length <= 1 ? 5 : 8,
        failurePlan: '如果今天时间很碎，就只完成第一步，并写下明天继续的时间点。',
        feedbackJson: jsonEncode(['今天最小一步是否完成', '完成后感受', '明天还能再做什么']),
      ),
    ),
    GoalActionTier(
      levelLabel: '标准行动',
      emphasis: '按照课程当前建议完整做一遍，建立第一次完整体验。',
      action: base,
    ),
    GoalActionTier(
      levelLabel: '进阶行动',
      emphasis: '把这次实践延伸到下周，让概念开始形成稳定模式。',
      action: GoalActionTemplate(
        actionId: '${base.actionId}__advanced',
        segmentId: base.segmentId,
        conceptId: base.conceptId,
        actionTitle: '进阶行动：${base.actionTitle}',
        actionLevel: '进阶行动',
        goalOfAction: '把“${concept.conceptTitle}”从一次动作推进成可重复的节律。',
        stepsJson: jsonEncode(advancedSteps),
        durationMin: (base.durationMin + 10).clamp(15, 35).toInt(),
        failurePlan: '如果今天做不完整，就先完成原标准行动，再把额外两步留到下次复盘。',
        feedbackJson: jsonEncode(['完成情况', '对现实问题是否更有帮助', '下周要保留的仪式', '要停止的无效做法']),
      ),
    ),
  ];
}
