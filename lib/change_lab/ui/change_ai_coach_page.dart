import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../models/change_models.dart';
import 'change_concept_detail_page.dart';
import 'change_task_instance_detail_page.dart';
import 'change_weekly_plan_page.dart';
import 'change_world_achievement_page.dart';
import 'mirror_world_scene_page.dart';
import 'widgets/section_card.dart';

class ChangeAiCoachPage extends StatelessWidget {
  const ChangeAiCoachPage({super.key, required this.controller});

  final ChangeLabController controller;

  @override
  Widget build(BuildContext context) {
    final recommended = controller.recommendedTaskNow;
    final recentRun = controller.recentTaskRuns.isEmpty ? null : controller.recentTaskRuns.first;
    final priorityMission = controller.priorityMission;
    final recentRewards = controller.recentRewardEvents(limit: 3);
    final assignedPrompt = recommended == null
        ? null
        : controller.aiPromptForTask(
            conceptId: recommended.concept.id,
            taskId: recommended.task.id,
            scenario: PromptScenario.taskAssigned,
          );
    final coachInstance = controller.activeTaskInstances.isNotEmpty
        ? controller.activeTaskInstances.first
        : (controller.failedTaskInstances.isNotEmpty ? controller.failedTaskInstances.first : null);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: const Text('AI 改变教练'),
        backgroundColor: const Color(0xFFF4F2F8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: '今日教练摘要',
            child: Text(controller.coachDailyBrief, style: const TextStyle(height: 1.6)),
          ),

          if (priorityMission != null)
            SectionCard(
              title: '世界主线提示',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${controller.worldById(priorityMission.worldId).title} · 阶段 ${priorityMission.stageNo}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(controller.missionUnlockBanner(priorityMission), style: const TextStyle(height: 1.55)),
                  const SizedBox(height: 8),
                  Text(controller.worldMissionProgressText(priorityMission.id), style: const TextStyle(color: Color(0xFF7A6177))),
                  const SizedBox(height: 8),
                  Text(controller.nextMainlineSummary, style: const TextStyle(color: Color(0xFF7A6177), height: 1.45)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MirrorWorldScenePage(
                            controller: controller,
                            worldId: priorityMission.worldId,
                          ),
                        ),
                      );
                    },
                    child: const Text('打开当前世界主线'),
                  ),
                ],
              ),
            ),
          if (recentRewards.isNotEmpty)
            SectionCard(
              title: '奖励事件流',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: recentRewards.map((event) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.workspace_premium_outlined, color: Color(0xFF6D5EF0), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(controller.rewardFeedNarrative(event), style: const TextStyle(height: 1.5)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (controller.completedWorldCount > 0)
            SectionCard(
              title: '完整世界成就',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('你已经完整点亮了 ${controller.completedWorldCount} 个镜像世界。每一个完整世界，都是你把现实动作沉淀成长期证据的结果。', style: const TextStyle(height: 1.55)),
                  const SizedBox(height: 10),
                  Text(controller.nextMainlineSummary, style: const TextStyle(color: Color(0xFF7A6177), height: 1.45)),
                ],
              ),
            ),
          if (controller.latestCompletionRewardEvent != null)
            SectionCard(
              title: '最新完整世界奖励',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.rewardFeedNarrative(controller.latestCompletionRewardEvent!),
                    style: const TextStyle(height: 1.55),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    controller.nextMainlineSummaryForWorld(controller.latestCompletionRewardEvent!.worldId),
                    style: const TextStyle(color: Color(0xFF7A6177), height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeWorldAchievementPage(
                                controller: controller,
                                worldId: controller.latestCompletionRewardEvent!.worldId,
                              ),
                            ),
                          );
                        },
                        child: const Text('打开世界成就页'),
                      ),
                      FilledButton(
                        onPressed: () {
                          controller.generateWeeklyPlanFromWorldCompletion(controller.latestCompletionRewardEvent!.worldId);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已基于完整世界奖励生成新的下一周计划。')));
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeWeeklyPlanPage(controller: controller),
                            ),
                          );
                        },
                        child: const Text('生成下一周计划'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (controller.currentWeeklyPlan != null)
            SectionCard(
              title: '计划与重启状态',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('今日待做 ${controller.todayTaskInstances.where((e) => e.isOpen).length}')),
                  Chip(label: Text('失败待重启 ${controller.restartQueueCount}')),
                  Chip(label: Text('本周计划 ${controller.weeklyTaskInstances.length}')),
                ],
              ),
            ),


          SectionCard(
            title: '通知与跟进桥接',
            child: Text(
              '当前已有 ${controller.deliveredReminderCount} 条提醒通过本地通知桥接发出。系统会在你回到 App 时同步到期提醒，并把次日追问接回行动系统。',
              style: const TextStyle(height: 1.55),
            ),
          ),
          if (controller.dueReminderCount > 0 || controller.nextDayFollowups.isNotEmpty)
            SectionCard(
              title: '提醒与次日追问',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('到期提醒 ${controller.dueReminderCount}')),
                      Chip(label: Text('次日追问 ${controller.nextDayFollowups.length}')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    controller.nextDayFollowups.isNotEmpty
                        ? controller.nextDayFollowupPrompt(controller.nextDayFollowups.first)
                        : '先处理到期提醒，再回到今天最推荐的动作。',
                    style: const TextStyle(height: 1.55),
                  ),
                ],
              ),
            ),
          if (coachInstance != null)
            SectionCard(
              title: '当前任务对话流',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...controller.coachDialogueForInstance(coachInstance.id).map((turn) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE6E0F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(turn.speaker, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF5E6270))),
                              const SizedBox(height: 6),
                              Text(turn.message, style: const TextStyle(height: 1.55)),
                              if (turn.emphasis.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(turn.emphasis, style: const TextStyle(color: Color(0xFF7A6177), height: 1.45)),
                              ],
                            ],
                          ),
                        ),
                      )),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeTaskInstanceDetailPage(
                            controller: controller,
                            instanceId: coachInstance.id,
                          ),
                        ),
                      );
                    },
                    child: const Text('打开当前任务实例'),
                  ),
                ],
              ),
            ),

          if (recommended != null)
            SectionCard(
              title: '此刻最推荐的动作',
              trailing: Chip(label: Text(_taskTypeLabel(recommended.task.type))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recommended.concept.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(recommended.reason),
                  const SizedBox(height: 12),
                  Text(recommended.task.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF5E6270))),
                  const SizedBox(height: 6),
                  Text(recommended.task.summary),
                  const SizedBox(height: 8),
                  Text('失败降级：${recommended.task.fallbackHint}',
                      style: const TextStyle(color: Color(0xFF7A6177))),
                  if (assignedPrompt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      assignedPrompt.prompt,
                      style: const TextStyle(color: Color(0xFF5E6270), height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final matching = controller.todayTaskInstances.where((e) => e.conceptId == recommended.concept.id && e.taskId == recommended.task.id && e.isOpen);
                      if (matching.isNotEmpty) {
                        controller.startTaskInstance(matching.first.id);
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeConceptDetailPage(
                            controller: controller,
                            concept: recommended.concept,
                            initialTaskId: recommended.task.id,
                          ),
                        ),
                      );
                    },
                    child: const Text('去执行这个动作'),
                  ),
                ],
              ),
            ),
          SectionCard(
            title: '你的主要阻力模式',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: controller.dominantPatterns
                  .map((pattern) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(pattern)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          if (recentRun != null)
            SectionCard(
              title: '最近一次行动反馈',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(controller.coachSuccessMessage(recentRun), style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 10),
                  Text(
                    '${controller.conceptById(recentRun.conceptId).title} · ${recentRun.taskId}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5E6270)),
                  ),
                  const SizedBox(height: 6),
                  Text(recentRun.combinedReflection),
                ],
              ),
            ),
          SectionCard(
            title: '失败时可以这样重启',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.recommendedTaskNow == null
                      ? '先把动作缩到足够小，只保留一点点不适，再重新开始。'
                      : controller.coachFailureMessage(
                          controller.recommendedTaskNow!.task,
                          controller.recommendedTaskNow!.concept,
                        ),
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 12),
                const Text('重启原则', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('1. 不把一次没做成解释成“我又不行了”\n2. 优先缩小动作，而不是加大道理\n3. 保留一点点不舒服，继续在拉伸区里练'),
              ],
            ),
          ),
          SectionCard(
            title: '概念追问卡',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (controller.pinnedConcept != null
                      ? controller.coachPromptsForConcept(controller.pinnedConcept!.id)
                      : const [
                          '今天哪一个动作最值得先做？',
                          '如果只做最小版本，你愿意怎么开始？',
                        ])
                  .map((prompt) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF5E6270)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(prompt)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _taskTypeLabel(TaskType type) {
    switch (type) {
      case TaskType.light:
        return '轻任务';
      case TaskType.main:
        return '主任务';
      case TaskType.challenge:
        return '挑战';
      case TaskType.fallback:
        return '降级';
    }
  }
}
