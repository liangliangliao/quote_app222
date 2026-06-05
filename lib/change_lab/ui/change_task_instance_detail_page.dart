import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../models/change_models.dart';
import 'change_concept_detail_page.dart';
import 'change_reminder_center_page.dart';
import 'widgets/section_card.dart';

class ChangeTaskInstanceDetailPage extends StatelessWidget {
  const ChangeTaskInstanceDetailPage({
    super.key,
    required this.controller,
    required this.instanceId,
  });

  final ChangeLabController controller;
  final String instanceId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final instance = controller.taskInstanceById(instanceId);
        if (instance == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('任务实例')),
            body: const Center(child: Text('这个任务实例已不存在。')),
          );
        }
        final concept = controller.conceptById(instance.conceptId);
        final task = controller.taskById(instance.conceptId, instance.taskId);
        final reminders = controller.remindersForInstance(instance.id);
        final dialogue = controller.coachDialogueForInstance(instance.id);
        final world = controller.worldScenes.where((w) => w.conceptIds.contains(instance.conceptId)).toList();
        final worldScene = world.isEmpty ? null : world.first;
        final activeMission = worldScene == null ? null : controller.activeMissionForWorld(worldScene.id);
        final statusColor = controller.taskInstanceStatusColor(instance.status);

        return Scaffold(
          backgroundColor: const Color(0xFFF4F2F8),
          appBar: AppBar(
            title: const Text('任务实例详情'),
            backgroundColor: const Color(0xFFF4F2F8),
            actions: [
              IconButton(
                tooltip: '提醒与跟进',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeReminderCenterPage(controller: controller),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_active_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: task.title,
                trailing: Chip(
                  backgroundColor: statusColor.withOpacity(0.12),
                  label: Text(
                    controller.taskInstanceStatusLabel(instance.status),
                    style: TextStyle(color: statusColor),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(concept.title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF5E6270))),
                    const SizedBox(height: 8),
                    Text(instance.assignedReason.isEmpty ? task.summary : instance.assignedReason, style: const TextStyle(height: 1.55)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('任务类型 ${_taskTypeLabel(instance.taskType)}')),
                        Chip(label: Text('计划日 ${instance.plannedFor.month}/${instance.plannedFor.day}')),
                        if (instance.failCount > 0) Chip(label: Text('失败 ${instance.failCount} 次')),
                      ],
                    ),
                    if (instance.failureReason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('最近卡点：${instance.failureReason}', style: const TextStyle(color: Color(0xFFC14C2A), height: 1.45)),
                    ],
                    const SizedBox(height: 12),
                    Text('下一步建议：${controller.coachPrimaryActionForInstance(instance.id)}', style: const TextStyle(color: Color(0xFF7A6177), height: 1.5)),
                  ],
                ),
              ),
              if (worldScene != null)
                SectionCard(
                  title: '世界推进挂接',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('这个任务会推进「${worldScene.title}」', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(worldScene.realWorldRule, style: const TextStyle(height: 1.5)),
                      if (activeMission != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE6E0F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(activeMission.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                                  Chip(
                                    backgroundColor: controller.worldMissionStatusColor(activeMission.id).withOpacity(0.12),
                                    label: Text(
                                      controller.worldMissionStatusLabel(activeMission.id),
                                      style: TextStyle(color: controller.worldMissionStatusColor(activeMission.id)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(activeMission.summary, style: const TextStyle(height: 1.5)),
                              const SizedBox(height: 8),
                              Text(controller.worldMissionProgressText(activeMission.id), style: const TextStyle(color: Color(0xFF5E6270))),
                              const SizedBox(height: 6),
                              Text('完成后奖励：${activeMission.rewardText}', style: const TextStyle(color: Color(0xFF7A6177), height: 1.45)),
                            ],
                          ),
                        ),
                      ],
                      if (controller.latestRewardMessageForWorld(worldScene.id) != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F5FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE6E0F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.workspace_premium_outlined, color: Color(0xFF6D3EF0)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  controller.latestRewardMessageForWorld(worldScene.id)!,
                                  style: const TextStyle(height: 1.45, color: Color(0xFF5E6270)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              SectionCard(
                title: 'AI 教练对话流',
                child: Column(
                  children: dialogue.map((turn) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                    );
                  }).toList(),
                ),
              ),
              SectionCard(
                title: '挂接提醒',
                child: reminders.isEmpty
                    ? const Text('这个任务目前还没有挂接提醒。')
                    : Column(
                        children: reminders.map((r) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(controller.reminderScheduleLabel(r)),
                            subtitle: Text('${controller.reminderDueLabel(r)} · ${r.message}'),
                            trailing: Chip(label: Text(r.status.name)),
                          );
                        }).toList(),
                      ),
              ),
              SectionCard(
                title: '操作',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (instance.status == TaskInstanceStatus.planned)
                      FilledButton.tonal(
                        onPressed: () {
                          controller.startTaskInstance(instance.id);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeConceptDetailPage(
                                controller: controller,
                                concept: concept,
                                initialTaskId: task.id,
                              ),
                            ),
                          );
                        },
                        child: const Text('开始执行'),
                      ),
                    if (instance.status == TaskInstanceStatus.inProgress)
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeConceptDetailPage(
                                controller: controller,
                                concept: concept,
                                initialTaskId: task.id,
                              ),
                            ),
                          );
                        },
                        child: const Text('继续执行'),
                      ),
                    if (instance.status == TaskInstanceStatus.failed)
                      FilledButton.tonal(
                        onPressed: () {
                          controller.restartTaskInstance(instance.id);
                          final milestone = controller.latestMilestoneMessage;
                          final message = milestone == null || milestone.isEmpty
                              ? '已生成一个更小的重启任务。'
                              : '已生成一个更小的重启任务。\n$milestone';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        },
                        child: const Text('失败重启'),
                      ),
                    if (instance.status == TaskInstanceStatus.planned || instance.status == TaskInstanceStatus.inProgress)
                      OutlinedButton(
                        onPressed: () {
                          controller.skipTaskInstance(instance.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('本次已跳过，系统会在后续计划里再次安排。')),
                          );
                        },
                        child: const Text('先跳过'),
                      ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeConceptDetailPage(
                              controller: controller,
                              concept: concept,
                              initialTaskId: task.id,
                            ),
                          ),
                        );
                      },
                      child: const Text('查看概念'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
