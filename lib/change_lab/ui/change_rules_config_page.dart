import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../models/change_models.dart';
import 'change_growth_timeline_page.dart';
import 'widgets/section_card.dart';

class ChangeRulesConfigPage extends StatelessWidget {
  const ChangeRulesConfigPage({super.key, required this.controller});

  final ChangeLabController controller;

  @override
  Widget build(BuildContext context) {
    final reminderCount = controller.reminders.length;
    final promptCount = controller.aiPrompts.length;
    final worldCount = controller.worldScenes.length;
    final taskCount = controller.concepts.fold<int>(0, (sum, c) => sum + c.tasks.length);
    final taskInstanceCount = controller.taskInstances.length;
    final reminderScheduleCount = controller.reminderSchedules.length;
    final missionCount = controller.missionStages.length;
    final rewardEventCount = controller.worldRewardEvents.length;
    final timelineCount = controller.growthTimelineItems(limit: 999).length;
    final priorityMission = controller.priorityMission;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: const Text('任务规则与配置'),
        backgroundColor: const Color(0xFFF4F2F8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: '内容引擎概览',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip('概念卡', '${controller.concepts.length}'),
                _metricChip('任务配置', '$taskCount'),
                _metricChip('提醒模板', '$reminderCount'),
                _metricChip('AI 模板', '$promptCount'),
                _metricChip('世界场景', '$worldCount'),
                _metricChip('剧情任务', '$missionCount'),
                _metricChip('任务实例', '$taskInstanceCount'),
                _metricChip('提醒调度', '$reminderScheduleCount'),
                _metricChip('已发通知', '${controller.deliveredReminderCount}'),
                _metricChip('阶段奖励', '$rewardEventCount'),
                _metricChip('未读奖励', '${controller.unseenRewardCount}'),
                _metricChip('时间线', '$timelineCount'),
                _metricChip('完成世界', '${controller.completedWorldCount}'),
              ],
            ),
          ),
          SectionCard(
            title: '运行引擎快照',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.weeklyPlanSummary, style: const TextStyle(height: 1.55)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metricChip('今日计划', '${controller.todayTaskInstances.length}'),
                    _metricChip('开放实例', '${controller.activeTaskInstances.length}'),
                    _metricChip('失败重启', '${controller.restartQueueCount}'),
                    _metricChip('到期提醒', '${controller.dueReminderCount}'),
                  ],
                ),
              ],
            ),
          ),

          if (priorityMission != null)
            SectionCard(
              title: '自动推荐主线快照',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${controller.worldById(priorityMission.worldId).title} · ${priorityMission.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(controller.missionUnlockBanner(priorityMission), style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 8),
                  Text(controller.nextMainlineSummary, style: const TextStyle(color: Color(0xFF6A6175), height: 1.45)),
                ],
              ),
            ),
          const SectionCard(
            title: '当前配置原则',
            child: Text(
              '1. 每张概念卡都至少有轻任务、主任务、挑战任务、失败降级。\n'
              '2. 每个任务都配有预提醒、临场提醒、中断提醒、次日追问。\n'
              '3. AI 教练按任务分配、完成、失败、复盘追问等场景调用模板。\n'
              '4. 镜像世界由现实任务解锁，不靠纯点击推进。\n'
              '5. 到期提醒会通过本地通知桥接同步，次日追问可回流为新的行动实例。',
              style: TextStyle(height: 1.6),
            ),
          ),
          SectionCard(
            title: '世界阶段任务快照',
            child: Column(
              children: controller.worldScenes.map((world) {
                final missions = controller.missionsForWorld(world.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F8FD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6E0F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(world.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      ...missions.map((mission) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Text('阶段 ${mission.stageNo}｜${mission.title}')),
                                Chip(label: Text(controller.worldMissionStatusLabel(mission.id))),
                              ],
                            ),
                          )),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          SectionCard(
            title: '世界解锁规则',
            child: Column(
              children: controller.worldScenes.map((world) {
                final unlocked = controller.isWorldUnlocked(world.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F8FD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6E0F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(world.title,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Chip(label: Text(unlocked ? '已解锁' : '待解锁')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(world.sceneGoal, style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 8),
                      Text('前置概念：${world.unlockConceptIds.map((id) => controller.conceptById(id).title).join('、')}'),
                      const SizedBox(height: 6),
                      Text('推进进度：${controller.worldProgress(world.id).completedActions}/${controller.worldProgress(world.id).targetActions}'),
                      const SizedBox(height: 6),
                      Text(controller.worldUnlockHint(world.id), style: const TextStyle(color: Color(0xFF5E6270))),
                      const SizedBox(height: 6),
                      Text('剧情阶段：${controller.worldNarrativeText(world.id)}', style: const TextStyle(color: Color(0xFF7A6177), height: 1.45)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          SectionCard(
            title: '最近阶段奖励',
            child: controller.worldRewardEvents.isEmpty
                ? const Text('当前还没有阶段奖励事件。完成世界阶段任务后，系统会自动领奖并写入这里。')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...controller.worldRewardEvents.take(6).map((e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${controller.worldById(e.worldId).title}｜${e.title}'),
                        subtitle: Text(e.message),
                        trailing: Text('${e.createdAt.month}/${e.createdAt.day}'),
                      )),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeGrowthTimelinePage(controller: controller),
                            ),
                          );
                        },
                        child: const Text('打开成长时间线'),
                      ),
                    ],
                  ),
          ),
          SectionCard(
            title: '提醒调度快照',
            child: controller.reminderSchedules.isEmpty
                ? const Text('当前还没有提醒调度实例。生成本周计划后，系统会根据任务实例自动创建提醒与次日追问。')
                : Column(
                    children: controller.reminderSchedules.take(8).map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(controller.reminderScheduleLabel(r)),
                      subtitle: Text('${controller.reminderDueLabel(r)} · ${r.message}'),
                      trailing: Chip(label: Text(r.status.name)),
                    )).toList(),
                  ),
          ),
          SectionCard(
            title: '提醒模板预览',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: controller.reminders.take(8).map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFF5E6270)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_reminderTypeLabel(r.type)}｜${r.message}',
                          style: const TextStyle(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          SectionCard(
            title: 'AI 教练模板预览',
            child: Column(
              children: controller.aiPrompts.take(8).map((p) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_scenarioLabel(p.scenario)),
                  subtitle: Text(p.prompt),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E0F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF666A73))),
        ],
      ),
    );
  }

  String _reminderTypeLabel(ReminderType type) {
    switch (type) {
      case ReminderType.pre:
        return '预提醒';
      case ReminderType.moment:
        return '临场提醒';
      case ReminderType.interrupt:
        return '中断提醒';
      case ReminderType.nextDay:
        return '次日追问';
    }
  }

  String _scenarioLabel(PromptScenario scenario) {
    switch (scenario) {
      case PromptScenario.taskAssigned:
        return '任务分配';
      case PromptScenario.taskCompleted:
        return '任务完成';
      case PromptScenario.taskFailed:
        return '任务失败';
      case PromptScenario.nextDayCheckin:
        return '次日追问';
      case PromptScenario.reflectionFollowup:
        return '复盘追问';
    }
  }
}
