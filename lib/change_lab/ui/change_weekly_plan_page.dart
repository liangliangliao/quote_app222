import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../models/change_models.dart';
import 'change_concept_detail_page.dart';
import 'change_task_instance_detail_page.dart';
import 'widgets/section_card.dart';

class ChangeWeeklyPlanPage extends StatelessWidget {
  const ChangeWeeklyPlanPage({super.key, required this.controller});

  final ChangeLabController controller;

  @override
  Widget build(BuildContext context) {
    final plan = controller.currentWeeklyPlan;
    final weekly = controller.weeklyTaskInstances;
    final failed = controller.failedTaskInstances;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final grouped = <String, List<ChangeTaskInstance>>{};
        for (final instance in controller.weeklyTaskInstances) {
          final key = controller.weeklyBucketLabel(instance.plannedFor);
          grouped.putIfAbsent(key, () => []).add(instance);
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF4F2F8),
          appBar: AppBar(
            title: const Text('本周计划引擎'),
            backgroundColor: const Color(0xFFF4F2F8),
            actions: [
              IconButton(
                tooltip: '重生成本周计划',
                onPressed: () {
                  controller.regenerateWeeklyPlan();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已按当前状态重生成本周计划。')),
                  );
                },
                icon: const Icon(Icons.refresh),
              )
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: '计划摘要',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan?.summary ?? '本周计划尚未生成。', style: const TextStyle(height: 1.55)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('计划任务 ${weekly.length}')),
                        Chip(label: Text('今日待做 ${controller.todayTaskInstances.where((e) => e.isOpen).length}')),
                        Chip(label: Text('失败待重启 ${failed.length}')),
                      ],
                    )
                  ],
                ),
              ),
              if (grouped.isNotEmpty)
                ...grouped.entries.map((entry) {
                  return SectionCard(
                    title: entry.key,
                    trailing: Chip(label: Text('${entry.value.length} 项')),
                    child: Column(
                      children: entry.value.map((instance) {
                        final concept = controller.conceptById(instance.conceptId);
                        final task = controller.taskById(instance.conceptId, instance.taskId);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F8FD),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE7E1F1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                  Chip(
                                    backgroundColor: controller.taskInstanceStatusColor(instance.status).withOpacity(0.12),
                                    label: Text(
                                      controller.taskInstanceStatusLabel(instance.status),
                                      style: TextStyle(color: controller.taskInstanceStatusColor(instance.status)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(concept.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5E6270))),
                              const SizedBox(height: 8),
                              Text(instance.assignedReason.isEmpty ? task.summary : instance.assignedReason),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (instance.status == TaskInstanceStatus.planned || instance.status == TaskInstanceStatus.inProgress)
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
                                      child: Text(instance.status == TaskInstanceStatus.inProgress ? '继续执行' : '开始执行'),
                                    ),
                                  if (instance.status == TaskInstanceStatus.failed)
                                    FilledButton.tonal(
                                      onPressed: () {
                                        controller.restartTaskInstance(instance.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('已生成一个更小的重启任务。')),
                                        );
                                      },
                                      child: const Text('失败重启'),
                                    ),
                                  if (instance.status == TaskInstanceStatus.planned || instance.status == TaskInstanceStatus.inProgress)
                                    OutlinedButton(
                                      onPressed: () {
                                        controller.skipTaskInstance(instance.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('本次已跳过，系统会在后续计划中再次安排。')),
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
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
