import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../models/change_models.dart';
import 'change_concept_detail_page.dart';
import 'change_task_instance_detail_page.dart';
import 'widgets/section_card.dart';

class ChangeReminderCenterPage extends StatelessWidget {
  const ChangeReminderCenterPage({super.key, required this.controller});

  final ChangeLabController controller;

  @override
  Widget build(BuildContext context) {
    final due = controller.dueReminderSchedules;
    final upcoming = controller.upcomingReminderSchedules.take(8).toList();
    final followups = controller.nextDayFollowups.take(6).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: const Text('提醒与跟进'),
        backgroundColor: const Color(0xFFF4F2F8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: '调度概览',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('到期提醒', '${due.length}'),
                _chip('待跟进', '${followups.length}'),
                _chip('未来提醒', '${upcoming.length}'),
              ],
            ),
          ),
          if (due.isNotEmpty)
            SectionCard(
              title: '现在最该处理的提醒',
              child: Column(
                children: due.map((schedule) => _ReminderTile(controller: controller, schedule: schedule)).toList(),
              ),
            ),
          if (followups.isNotEmpty)
            SectionCard(
              title: '次日追问',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: followups.map((schedule) {
                  final concept = controller.conceptById(schedule.conceptId);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE6E0F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(concept.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(controller.nextDayFollowupPrompt(schedule), style: const TextStyle(height: 1.55)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: () {
                                controller.markReminderDone(schedule.id, note: '已完成次日追问：${controller.nextDayFollowupPrompt(schedule)}');
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已记录次日追问。')));
                              },
                              child: const Text('记录追问'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ChangeConceptDetailPage(
                                    controller: controller,
                                    concept: concept,
                                    initialTaskId: schedule.taskId,
                                  ),
                                ));
                              },
                              child: const Text('回到概念'),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          SectionCard(
            title: '未来提醒',
            child: upcoming.isEmpty
                ? const Text('当前没有未来提醒。继续执行今天的任务，系统会自动为你生成新的提醒与追问。')
                : Column(
                    children: upcoming.map((schedule) => _ReminderTile(controller: controller, schedule: schedule, compact: true)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) => Container(
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

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.controller, required this.schedule, this.compact = false});

  final ChangeLabController controller;
  final ReminderSchedule schedule;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final concept = controller.conceptById(schedule.conceptId);
    final task = controller.taskById(schedule.conceptId, schedule.taskId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(controller.reminderScheduleLabel(schedule)),
      subtitle: Text('${concept.title} · ${task.title}\n${schedule.message}\n${controller.reminderDueLabel(schedule)}'),
      isThreeLine: true,
      trailing: compact
          ? null
          : Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: '完成',
                  onPressed: () {
                    controller.markReminderDone(schedule.id);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已完成提醒。')));
                  },
                  icon: const Icon(Icons.check_circle_outline),
                ),
                IconButton(
                  tooltip: '稍后提醒',
                  onPressed: () {
                    controller.snoozeReminder(schedule.id);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已延后 2 小时。')));
                  },
                  icon: const Icon(Icons.snooze_outlined),
                ),
                IconButton(
                  tooltip: '忽略',
                  onPressed: () {
                    controller.dismissReminder(schedule.id);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已忽略提醒。')));
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
      onTap: () {
        final instance = controller.taskInstanceById(schedule.instanceId);
        if (instance != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChangeTaskInstanceDetailPage(
              controller: controller,
              instanceId: instance.id,
            ),
          ));
          return;
        }
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChangeConceptDetailPage(
            controller: controller,
            concept: concept,
            initialTaskId: task.id,
          ),
        ));
      },
    );
  }
}
