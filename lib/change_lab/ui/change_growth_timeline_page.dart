import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../models/change_models.dart';
import 'change_concept_detail_page.dart';
import 'mirror_world_scene_page.dart';
import 'widgets/section_card.dart';

class ChangeGrowthTimelinePage extends StatelessWidget {
  const ChangeGrowthTimelinePage({super.key, required this.controller});

  final ChangeLabController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final items = controller.growthTimelineItems(limit: 60);
        return Scaffold(
          backgroundColor: const Color(0xFFF4F2F8),
          appBar: AppBar(
            title: const Text('成长时间线'),
            backgroundColor: const Color(0xFFF4F2F8),
            actions: [
              IconButton(
                tooltip: '全部标记奖励为已读',
                onPressed: controller.unseenRewardCount == 0 ? null : controller.markAllRewardEventsSeen,
                icon: const Icon(Icons.done_all_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: '成长快照',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metricChip('时间线条目', '${items.length}'),
                        _metricChip('未读奖励', '${controller.unseenRewardCount}'),
                        _metricChip('本周动作', '${controller.weeklyActionCount}'),
                        _metricChip('阶段奖励', '${controller.worldRewardEvents.length}'),
                        _metricChip('已点亮世界', '${controller.completedWorldCount}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(controller.growthJourneySummary, style: const TextStyle(height: 1.55)),
                    const SizedBox(height: 10),
                    Text(controller.nextMainlineSummary, style: const TextStyle(color: Color(0xFF6A6175), height: 1.45)),
                  ],
                ),
              ),
              if (controller.latestMilestoneMessage != null && controller.latestMilestoneMessage!.trim().isNotEmpty)
                SectionCard(
                  title: '最近里程碑',
                  child: Text(controller.latestMilestoneMessage!, style: const TextStyle(height: 1.55)),
                ),
              if (controller.recommendedTaskQueue.isNotEmpty)
                SectionCard(
                  title: '下一步最值得做的动作',
                  child: Column(
                    children: controller.recommendedTaskQueue.take(4).map((rec) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${rec.concept.title} · ${rec.task.title}'),
                        subtitle: Text(rec.reason),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeConceptDetailPage(
                                controller: controller,
                                concept: rec.concept,
                                initialTaskId: rec.task.id,
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              SectionCard(
                title: '成长时间线',
                child: items.isEmpty
                    ? const Text('还没有时间线记录。先完成一个现实动作，或推进一个世界阶段。')
                    : Column(
                        children: items.map((item) => _TimelineTile(controller: controller, item: item)).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E0F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF6A6175))),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.controller, required this.item});

  final ChangeLabController controller;
  final GrowthTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(item.type);
    final icon = _iconFor(item.type);
    final isUnseenReward = item.type == TimelineItemType.reward && !controller.seenRewardEventIds.contains(item.id.replaceFirst('timeline_reward_', ''));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isUnseenReward ? const Color(0xFFD8C7FF) : const Color(0xFFE6E0F0)),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () {
          if (item.worldId != null && item.worldId!.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MirrorWorldScenePage(controller: controller, worldId: item.worldId!),
              ),
            );
            if (item.type == TimelineItemType.reward) {
              controller.markRewardEventSeen(item.id.replaceFirst('timeline_reward_', ''));
            }
            return;
          }
          if (item.conceptId != null && item.conceptId!.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeConceptDetailPage(
                  controller: controller,
                  concept: controller.conceptById(item.conceptId!),
                ),
              ),
            );
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      if (item.accentLabel.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(item.accentLabel, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item.message, style: const TextStyle(height: 1.5, color: Color(0xFF4A4F59))),
                  const SizedBox(height: 8),
                  Text(
                    _timeLabel(item.createdAt),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7B7F89)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _accentColor(TimelineItemType type) {
    switch (type) {
      case TimelineItemType.action:
        return const Color(0xFF1570EF);
      case TimelineItemType.reflection:
        return const Color(0xFF8E5CF7);
      case TimelineItemType.reward:
        return const Color(0xFF6D3EF0);
      case TimelineItemType.unlock:
        return const Color(0xFF1C9E5E);
    }
  }

  IconData _iconFor(TimelineItemType type) {
    switch (type) {
      case TimelineItemType.action:
        return Icons.play_circle_outline;
      case TimelineItemType.reflection:
        return Icons.history_edu_outlined;
      case TimelineItemType.reward:
        return Icons.workspace_premium_outlined;
      case TimelineItemType.unlock:
        return Icons.lock_open_outlined;
    }
  }

  String _timeLabel(DateTime time) {
    return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
