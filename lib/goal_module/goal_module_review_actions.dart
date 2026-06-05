import 'dart:convert';

import 'goal_models.dart';

class GoalModuleReviewActionDraft {
  final String levelLabel;
  final String subtitle;
  final GoalActionTemplate action;
  final String conceptTitle;
  final String segmentTitle;

  const GoalModuleReviewActionDraft({
    required this.levelLabel,
    required this.subtitle,
    required this.action,
    required this.conceptTitle,
    required this.segmentTitle,
  });
}

List<GoalModuleReviewActionDraft> buildModuleReviewActionDrafts({
  required GoalCompletionRitual ritual,
  required String summaryText,
  required String insightText,
  required String actionText,
  GoalCourseSegment? anchorSegment,
}) {
  final cleanSummary = summaryText.trim().isEmpty ? '刚完成的主题：${ritual.moduleGroup}' : summaryText.trim();
  final cleanInsight = insightText.trim().isEmpty
      ? '先抓住这组内容里最触动你的一个概念，并把它带回现实。'
      : insightText.trim();
  final cleanAction = actionText.trim().isEmpty
      ? '把这组内容转成今天能开始的一步。'
      : actionText.trim();
  final segment = anchorSegment;
  final segmentId = segment?.segmentId ?? ritual.nextSegmentId ?? 'ST13_14';
  final segmentTitle = segment?.sectionTitle ?? ritual.summaryTitle;
  final conceptTitle = '主题复盘行动';

  GoalActionTemplate buildTemplate({
    required String level,
    required String title,
    required String goal,
    required List<String> steps,
    required List<String> feedback,
    required int duration,
    required String failurePlan,
  }) {
    final suffix = level == '微行动' ? 'micro' : (level == '标准行动' ? 'standard' : 'advanced');
    return GoalActionTemplate(
      actionId: 'module_review_${ritual.ritualKey}_${suffix}_${DateTime.now().millisecondsSinceEpoch}',
      segmentId: segmentId,
      conceptId: 'MODULE_REVIEW_AUTO',
      actionTitle: title,
      actionLevel: level,
      goalOfAction: goal,
      stepsJson: jsonEncode(steps),
      durationMin: duration,
      failurePlan: failurePlan,
      feedbackJson: jsonEncode(feedback),
    );
  }

  return [
    GoalModuleReviewActionDraft(
      levelLabel: '微行动',
      subtitle: '先把“我准备带去现实的一步”拉回今天，重点是启动。',
      conceptTitle: conceptTitle,
      segmentTitle: segmentTitle,
      action: buildTemplate(
        level: '微行动',
        title: '主题复盘微行动：把一小步带回现实',
        goal: '围绕「${ritual.moduleGroup}」完成一次最小但真实的现实启动。',
        steps: [
          '快速回看这组主题的核心：$cleanSummary',
          '记住你最有感的一点：$cleanInsight',
          '立刻完成这一小步：$cleanAction',
        ],
        feedback: ['今天是否真的启动了', '这一小步和主题的连接感', '做完后最真实的感受'],
        duration: 10,
        failurePlan: '如果今天状态不够，就把这一步压缩成 5 分钟，并确定明天继续的时间点。',
      ),
    ),
    GoalModuleReviewActionDraft(
      levelLabel: '标准行动',
      subtitle: '把这组内容转成一轮完整实践：理解、执行、记录、复盘。',
      conceptTitle: conceptTitle,
      segmentTitle: segmentTitle,
      action: buildTemplate(
        level: '标准行动',
        title: '主题复盘标准行动：完成一轮真实实践',
        goal: '把主题复盘里的收获，落实成一轮可记录、可复盘的现实行动。',
        steps: [
          '用一句话重述这组内容现在对你的意义：$cleanSummary',
          '把最触动你的洞见作为提醒：$cleanInsight',
          '完成你准备带去现实的一步：$cleanAction',
          '行动后立刻写下：这次做法更接近“理解”，还是更接近“改变”？',
        ],
        feedback: ['这次行动完成到什么程度', '最大的阻碍是什么', '这次更像知识复习还是现实实践'],
        duration: 20,
        failurePlan: '如果完整版本太重，就保留“回看洞见 + 完成现实一步”两步，剩余内容放到二次复盘里。',
      ),
    ),
    GoalModuleReviewActionDraft(
      levelLabel: '进阶行动',
      subtitle: '把一次主题复盘延长成一周实践，让学习真正开始沉淀。',
      conceptTitle: conceptTitle,
      segmentTitle: segmentTitle,
      action: buildTemplate(
        level: '进阶行动',
        title: '主题复盘进阶行动：把主题收获延长成一周实践',
        goal: '不只做一次，而是让刚完成的主题在一周里持续影响行动与反思。',
        steps: [
          '从这组主题里选一个最想继续验证的点：$cleanInsight',
          '把“现实的一步”扩展成至少 2 次推进：$cleanAction',
          '每次推进后，用一句话记录它是否真的改变了你的做法',
          '一周结束时判断：这组内容值得继续、调整，还是暂时放下',
        ],
        feedback: ['本周推进了几次', '哪次最有真实改变感', '这组主题接下来要继续/调整/放下什么'],
        duration: 30,
        failurePlan: '如果一周节律太难建立，就至少安排 2 个时间点并完成其中一次推进，剩余判断放到行动闭环里。',
      ),
    ),
  ];
}
