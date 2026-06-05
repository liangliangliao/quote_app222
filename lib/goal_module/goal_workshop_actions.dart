import 'dart:convert';

import 'goal_models.dart';

class GoalWorkshopActionDraft {
  final String levelLabel;
  final String subtitle;
  final GoalActionTemplate action;
  final String conceptTitle;
  final String segmentTitle;

  const GoalWorkshopActionDraft({
    required this.levelLabel,
    required this.subtitle,
    required this.action,
    required this.conceptTitle,
    required this.segmentTitle,
  });
}

List<GoalWorkshopActionDraft> buildWorkshopActionDrafts(GoalWorkshopDraft draft) {
  final goalText = draft.vision.trim().isEmpty ? '当前目标' : draft.vision.trim();
  final whyText = draft.whyText.trim().isEmpty ? '先把这次实践和“为什么值得做”重新连起来。' : draft.whyText.trim();
  final weekly = draft.weeklyGoal.trim().isEmpty ? '围绕当前目标推进一次最小但真实的实践。' : draft.weeklyGoal.trim();
  final firstStep = draft.firstStep.trim().isEmpty ? '把目标压缩成今天能开始的一步，并在 10 分钟内启动。' : draft.firstStep.trim();
  final ifThen = draft.ifThenText.trim().isEmpty
      ? '如果开始前想拖延，那么先只做 5 分钟。'
      : draft.ifThenText.trim();
  final lifeline = draft.lifeline.trim().isEmpty ? '本周内完成这次推进。' : '生命线：${draft.lifeline.trim()}';
  final focusSource = draft.identityStatement.trim().isNotEmpty ? draft.identityStatement.trim() : goalText;
  final riskHint = draft.detectedRisks.isNotEmpty ? draft.detectedRisks.first : '当前重点是先建立一条真的执行轨迹。';

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
      actionId: 'workshop_auto_${suffix}_${DateTime.now().millisecondsSinceEpoch}',
      segmentId: 'ST13_11',
      conceptId: 'WORKSHOP_AUTO',
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
    GoalWorkshopActionDraft(
      levelLabel: '微行动',
      subtitle: '先把“目标”拉回到今天，重点是启动，不追求完美。',
      conceptTitle: '工坊自动生成行动',
      segmentTitle: '在切入“压力”前：目标设定的几个基本技巧（setting goals）',
      action: buildTemplate(
        level: '微行动',
        title: '微行动：为“$goalText”启动 10 分钟',
        goal: '围绕“$goalText”完成一次最小但真实的启动，把想法拉回今天。',
        steps: [
          '先重读你的 why：$whyText',
          '只执行这一小步：$firstStep',
          '结束后立刻写下一句：今天启动后，我最真实的感受是什么？',
        ],
        feedback: ['今天是否真的启动了', '启动后的阻力变化', '明天还想不想继续'],
        duration: 10,
        failurePlan: '如果今天时间碎片化，就只做 5 分钟，并立刻确定明天继续的具体时间。',
      ),
    ),
    GoalWorkshopActionDraft(
      levelLabel: '标准行动',
      subtitle: '按课程逻辑完整做一轮：why、推进点、第一步、if-then。',
      conceptTitle: '工坊自动生成行动',
      segmentTitle: '分解成功（breaking down successes）：把大目标拆成可走的步子 + 计划 + 仪式',
      action: buildTemplate(
        level: '标准行动',
        title: '标准行动：围绕“$goalText”完成一次本周推进',
        goal: '把“本周推进”从工坊文字变成一次真实执行，并验证它是否可持续。',
        steps: [
          '先确认本周推进：$weekly',
          '执行明天第一步或其等价动作：$firstStep',
          '如果遇到阻碍，就立即调用这条 if-then：$ifThen',
          '结束后判断：这次推进更接近“我的目标”还是“外界期待”？',
        ],
        feedback: ['本周推进完成到什么程度', '最大阻碍是什么', '这次更像自己的目标还是更像外界期待'],
        duration: 20,
        failurePlan: '如果完整版本太重，就保留“确认 why + 执行第一步”两步，剩余内容放到复盘里处理。',
      ),
    ),
    GoalWorkshopActionDraft(
      levelLabel: '进阶行动',
      subtitle: '把一次推进延伸成节律，开始形成你自己的执行系统。',
      conceptTitle: '工坊自动生成行动',
      segmentTitle: '“伸展目标（stretch goals）”：肯尼迪登月目标与 NASA 动力下滑',
      action: buildTemplate(
        level: '进阶行动',
        title: '进阶行动：把“$goalText”升级成一周节律',
        goal: '不只完成一次行动，而是让这个目标开始拥有稳定节律和复盘机制。',
        steps: [
          '为这周再安排 2 个可执行时间点，并写下：$lifeline',
          '把当前最主要的拉扯或风险写成一句提醒：$riskHint',
          '至少完成一次推进，并在结束后补一条新的 if-then 或调整建议',
          '决定这条目标接下来是继续、调整，还是暂时放下，并写下理由',
          '回到工坊，检查“$focusSource”是否仍与当前路径一致',
        ],
        feedback: ['本周节律是否建立', '哪一条安排最现实', '接下来要继续/调整/放下什么', '新的 if-then 是什么'],
        duration: 30,
        failurePlan: '如果一次做不完，就先完成“安排 2 个时间点 + 完成一次推进”，剩余判断放到二次复盘里。',
      ),
    ),
  ];
}
