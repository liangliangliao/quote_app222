import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import 'change_concept_detail_page.dart';
import 'change_world_achievement_page.dart';
import 'widgets/section_card.dart';

class MirrorWorldScenePage extends StatelessWidget {
  const MirrorWorldScenePage({
    super.key,
    required this.controller,
    required this.worldId,
  });

  final ChangeLabController controller;
  final String worldId;

  @override
  Widget build(BuildContext context) {
    final world = controller.worldById(worldId);
    final unlocked = controller.isWorldUnlocked(worldId);
    final concepts = controller.conceptsForWorld(worldId);
    final recommendation = controller.recommendedTaskForWorld(worldId);
    final progress = controller.worldProgress(worldId);
    final missions = controller.missionsForWorld(worldId);
    final activeMission = controller.activeMissionForWorld(worldId);
    final rewardEvents = controller.rewardEventsForWorld(worldId).take(3).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: Text(world.title),
        backgroundColor: const Color(0xFFF4F2F8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: '场景说明',
            trailing: Chip(label: Text(unlocked ? '已解锁' : '待解锁')),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(world.description, style: const TextStyle(height: 1.6)),
                const SizedBox(height: 10),
                Text('场景目标：${world.sceneGoal}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(controller.worldUnlockHint(world.id), style: const TextStyle(color: Color(0xFF5E6270), height: 1.5)),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress.ratio, minHeight: 8, borderRadius: BorderRadius.circular(99)),
                const SizedBox(height: 8),
                Text('当前推进：${progress.completedActions}/${progress.targetActions} · ${controller.worldProgressLabel(world.id)}', style: const TextStyle(color: Color(0xFF5E6270))),
              ],
            ),
          ),
          SectionCard(
            title: '这里主要练什么',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: concepts
                  .map((concept) => ActionChip(
                        label: Text(concept.title),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeConceptDetailPage(
                                controller: controller,
                                concept: concept,
                              ),
                            ),
                          );
                        },
                      ))
                  .toList(),
            ),
          ),

          SectionCard(
            title: '剧情推进',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.worldNarrativeText(world.id), style: const TextStyle(height: 1.6)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.worldStoryBeats(world.id).asMap().entries.map((entry) {
                    final beatIndex = entry.key;
                    final stage = controller.worldStage(world.id);
                    final active = stage >= 1 && beatIndex <= (stage - 1).clamp(0, 2);
                    return Chip(
                      backgroundColor: active ? const Color(0xFFE8F4EC) : const Color(0xFFF2F0F7),
                      label: Text(entry.value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Text(controller.worldNextMilestoneText(world.id), style: const TextStyle(color: Color(0xFF5E6270), height: 1.5)),
              ],
            ),
          ),
          if (missions.isNotEmpty)
            SectionCard(
              title: '阶段剧情任务',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (activeMission != null) ...[
                    Text('当前主线：${activeMission.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(activeMission.summary, style: const TextStyle(height: 1.55)),
                    const SizedBox(height: 8),
                    Text(controller.worldMissionProgressText(activeMission.id), style: const TextStyle(color: Color(0xFF5E6270))),
                    const SizedBox(height: 12),
                  ],
                  ...missions.map((mission) {
                    final color = controller.worldMissionStatusColor(mission.id);
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
                          Row(
                            children: [
                              Expanded(child: Text('阶段 ${mission.stageNo}｜${mission.title}', style: const TextStyle(fontWeight: FontWeight.w700))),
                              Chip(
                                backgroundColor: color.withOpacity(0.12),
                                label: Text(
                                  controller.worldMissionStatusLabel(mission.id),
                                  style: TextStyle(color: color),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(mission.summary, style: const TextStyle(height: 1.5)),
                          const SizedBox(height: 8),
                          Text(controller.worldMissionProgressText(mission.id), style: const TextStyle(color: Color(0xFF5E6270))),
                          const SizedBox(height: 6),
                          Text('完成奖励：${mission.rewardText}', style: const TextStyle(color: Color(0xFF7A6177), height: 1.45)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),


          if (progress.completed)
            SectionCard(
              title: '世界完成奖励',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(controller.worldCompletionNarrative(world.id), style: const TextStyle(height: 1.55)),
                  const SizedBox(height: 10),
                  Text(controller.nextMainlineSummaryForWorld(world.id), style: const TextStyle(color: Color(0xFF6A6175), height: 1.45)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeWorldAchievementPage(controller: controller, worldId: world.id),
                            ),
                          );
                        },
                        child: const Text('查看世界成就'),
                      ),
                      if ((controller.worldPriorityRecommendation ?? controller.recommendedTaskNow) != null)
                        OutlinedButton(
                          onPressed: () {
                            final rec = controller.worldPriorityRecommendation ?? controller.recommendedTaskNow;
                            if (rec == null) return;
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
                          child: const Text('去做下一步动作'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (rewardEvents.isNotEmpty)
            SectionCard(
              title: '最近领取的阶段奖励',
              child: Column(
                children: rewardEvents.map((event) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F7FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE6E0F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(event.message, style: const TextStyle(height: 1.5)),
                        const SizedBox(height: 6),
                        Text(
                          '领取时间：${event.createdAt.month}/${event.createdAt.day} ${event.createdAt.hour.toString().padLeft(2, '0')}:${event.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Color(0xFF7A6177)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (recommendation != null)
            SectionCard(
              title: '场景推荐动作',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recommendation.concept.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(recommendation.task.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5E6270))),
                  const SizedBox(height: 6),
                  Text(recommendation.reason),
                  const SizedBox(height: 8),
                  Text('现实规则：${world.realWorldRule}', style: const TextStyle(color: Color(0xFF7A6177), height: 1.45)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeConceptDetailPage(
                            controller: controller,
                            concept: recommendation.concept,
                            initialTaskId: recommendation.task.id,
                          ),
                        ),
                      );
                    },
                    child: const Text('去完成推荐动作'),
                  ),
                ],
              ),
            ),
          if (progress.lastActionAt != null)
            SectionCard(
              title: '最近一次现实推进',
              child: Text('最近一次推进发生在 ${progress.lastActionAt!.month}/${progress.lastActionAt!.day} ${progress.lastActionAt!.hour.toString().padLeft(2, '0')}:${progress.lastActionAt!.minute.toString().padLeft(2, '0')}，继续完成对应概念动作就能推动场景前进。', style: const TextStyle(height: 1.55)),
            ),
          SectionCard(
            title: '现实联动规则',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(world.realWorldRule, style: const TextStyle(height: 1.6)),
                if (world.nextWorldIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '后续世界：${world.nextWorldIds.map((id) => controller.worldById(id).title).join('、')}',
                    style: const TextStyle(color: Color(0xFF5E6270)),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
