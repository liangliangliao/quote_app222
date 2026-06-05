import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../models/change_models.dart';
import 'change_concept_detail_page.dart';
import 'change_reminder_center_page.dart';
import 'change_task_instance_detail_page.dart';
import 'change_weekly_plan_page.dart';
import 'widgets/section_card.dart';

class ChangeTaskCenterPage extends StatefulWidget {
  const ChangeTaskCenterPage({super.key, required this.controller});

  final ChangeLabController controller;

  @override
  State<ChangeTaskCenterPage> createState() => _ChangeTaskCenterPageState();
}

class _ChangeTaskCenterPageState extends State<ChangeTaskCenterPage> {
  TaskType? filter;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final taskEntries = controller.suggestedToday
        .expand((concept) => concept.tasks
            .where((task) => filter == null || task.type == filter)
            .map((task) => MapEntry(concept, task)))
        .toList();
    final pinned = controller.pinnedConcept;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: const Text('现实任务中心'),
        backgroundColor: const Color(0xFFF4F2F8),
        actions: [
          IconButton(
            tooltip: '本周计划',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeWeeklyPlanPage(controller: controller),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
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
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionCard(
            title: '今日原则',
            child: Text('不要只收藏概念。每次至少完成一个现实动作，再决定是否升级难度。'),
          ),
          SectionCard(
            title: 'AI 教练提示',
            child: Text(controller.coachDailyBrief, style: const TextStyle(height: 1.55)),
          ),

          if (controller.dueReminderCount > 0)
            SectionCard(
              title: '提醒与跟进',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('你当前有 ${controller.dueReminderCount} 条到期提醒。先处理提醒，再执行任务，会让本周计划更稳定。', style: const TextStyle(height: 1.55)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeReminderCenterPage(controller: controller),
                        ),
                      );
                    },
                    child: const Text('打开提醒中心'),
                  ),
                ],
              ),
            ),
          SectionCard(
            title: '今日任务筛选',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部'),
                  selected: filter == null,
                  onSelected: (_) => setState(() => filter = null),
                ),
                ...TaskType.values.map((type) => ChoiceChip(
                      label: Text(_taskTypeLabel(type)),
                      selected: filter == type,
                      onSelected: (_) => setState(() => filter = type),
                    )),
              ],
            ),
          ),
          if (pinned != null)
            SectionCard(
              title: '当前钉住任务',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pinned.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(pinned.problemSolved),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeConceptDetailPage(
                            controller: controller,
                            concept: pinned,
                          ),
                        ),
                      );
                    },
                    child: const Text('继续这个概念'),
                  )
                ],
              ),
            ),
          if (controller.currentWeeklyPlan != null)
            SectionCard(
              title: '本周计划',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(controller.weeklyPlanSummary, style: const TextStyle(height: 1.55)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('今日待做 ${controller.todayTaskInstances.where((e) => e.isOpen).length}')),
                      Chip(label: Text('失败待重启 ${controller.restartQueueCount}')),
                      Chip(label: Text('本周任务 ${controller.weeklyTaskInstances.length}')),
                    ],
                  ),
                ],
              ),
            ),
          if (controller.todayTaskInstances.isNotEmpty)
            SectionCard(
              title: '今日计划任务',
              child: Column(
                children: controller.todayTaskInstances.map((instance) {
                  final owner = controller.conceptById(instance.conceptId);
                  final task = controller.taskById(instance.conceptId, instance.taskId);
                  final statusColor = controller.taskInstanceStatusColor(instance.status);
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
                            Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                            Chip(
                              backgroundColor: statusColor.withOpacity(0.12),
                              label: Text(controller.taskInstanceStatusLabel(instance.status), style: TextStyle(color: statusColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(owner.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5E6270))),
                        const SizedBox(height: 8),
                        Text(instance.assignedReason.isEmpty ? task.summary : instance.assignedReason),
                        if (instance.failureReason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('上次卡点：${instance.failureReason}', style: const TextStyle(color: Color(0xFFC14C2A))),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (instance.status == TaskInstanceStatus.planned)
                              FilledButton.tonal(
                                onPressed: () {
                                  controller.startTaskInstance(instance.id);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChangeTaskInstanceDetailPage(
                                        controller: controller,
                                        instanceId: instance.id,
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
                                      builder: (_) => ChangeTaskInstanceDetailPage(
                                        controller: controller,
                                        instanceId: instance.id,
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已生成降级重启任务。')),
                                  );
                                },
                                child: const Text('失败重启'),
                              ),
                            OutlinedButton(
                              onPressed: instance.status == TaskInstanceStatus.completed
                                  ? null
                                  : () {
                                      controller.failTaskInstance(instance.id, reason: '用户在任务中心手动转入重启');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(controller.coachFailureMessage(task, owner))),
                                      );
                                    },
                              child: const Text('转入重启'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (controller.failedTaskInstances.isNotEmpty)
            SectionCard(
              title: '失败重启队列',
              child: Column(
                children: controller.failedTaskInstances.take(4).map((instance) {
                  final owner = controller.conceptById(instance.conceptId);
                  final task = controller.taskById(instance.conceptId, instance.taskId);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(task.title),
                    subtitle: Text(instance.failureReason.isEmpty ? owner.title : '${owner.title} · ${instance.failureReason}'),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        controller.restartTaskInstance(instance.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已按更小版本重启。')),
                        );
                      },
                      child: const Text('重启'),
                    ),
                  );
                }).toList(),
              ),
            ),
          SectionCard(
            title: '任务队列',
            trailing: Chip(label: Text('${taskEntries.length} 个')),
            child: taskEntries.isEmpty
                ? const Text('当前筛选下暂无任务。可以切换筛选，或先进入概念页钉住一个重点概念。')
                : Column(
                    children: taskEntries.map((entry) {
                      final owner = entry.key;
                      final task = entry.value;
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
                                  child: Text(task.title,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                Chip(label: Text(_taskTypeLabel(task.type))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(owner.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, color: Color(0xFF5E6270))),
                            const SizedBox(height: 8),
                            Text(task.summary),
                            const SizedBox(height: 8),
                            Text(task.instructions,
                                style: const TextStyle(color: Color(0xFF5E6270), height: 1.45)),
                            const SizedBox(height: 8),
                            Text('失败时降级：${task.fallbackHint}',
                                style: const TextStyle(color: Color(0xFF7A6177))),
                            const SizedBox(height: 8),
                            ...controller.reminderTemplatesForTask(task, owner).map((tip) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(tip, style: const TextStyle(fontSize: 12, color: Color(0xFF5E6270))),
                                )),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                FilledButton.tonal(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ChangeConceptDetailPage(
                                          controller: controller,
                                          concept: owner,
                                          initialTaskId: task.id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('去完成'),
                                ),
                                const SizedBox(width: 8),
                                Text('${task.estimatedMinutes} 分钟'),
                              ],
                            )
                          ],
                        ),
                      );
                    }).toList(),
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
