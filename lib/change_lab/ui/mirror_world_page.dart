import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import 'change_world_achievement_page.dart';
import 'mirror_world_scene_page.dart';
import 'widgets/section_card.dart';

class MirrorWorldPage extends StatelessWidget {
  const MirrorWorldPage({super.key, required this.controller});

  final ChangeLabController controller;

  @override
  Widget build(BuildContext context) {
    final worlds = controller.worldScenes;
    final priorityMission = controller.priorityMission;
    final recentRewards = controller.recentRewardEvents(limit: 4);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: const Text('镜像世界'),
        backgroundColor: const Color(0xFFF4F2F8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),

        children: [
          if (priorityMission != null)
            SectionCard(
              title: '当前自动推荐的世界主线',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${controller.worldById(priorityMission.worldId).title} · ${priorityMission.title}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(controller.missionUnlockBanner(priorityMission), style: const TextStyle(height: 1.55)),
                  const SizedBox(height: 8),
                  Text(controller.worldMissionProgressText(priorityMission.id), style: const TextStyle(color: Color(0xFF7A6177))),
                  const SizedBox(height: 8),
                  Text(controller.nextMainlineSummary, style: const TextStyle(color: Color(0xFF7A6177), height: 1.45)),
                  if (controller.worldPriorityRecommendation != null) ...[
                    const SizedBox(height: 12),
                    Text('推荐动作：${controller.worldPriorityRecommendation!.task.title}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5E6270))),
                    const SizedBox(height: 6),
                    Text(controller.worldPriorityRecommendation!.reason, style: const TextStyle(height: 1.45)),
                  ],
                ],
              ),
            ),
          if (recentRewards.isNotEmpty)
            SectionCard(
              title: '奖励事件流',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: recentRewards.map((event) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• ${controller.rewardFeedNarrative(event)}', style: const TextStyle(height: 1.45)),
                )).toList(),
              ),
            ),
          if (controller.completedWorlds.isNotEmpty)
            SectionCard(
              title: '已完整点亮的世界',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '这些世界已经完成全部阶段，你可以回到场景里回看奖励，也可以顺着新的主线继续推进。',
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  ...controller.completedWorlds.take(3).map((world) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeWorldAchievementPage(controller: controller, worldId: world.id),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FFF9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDDEFE0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(world.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(controller.worldCompletionNarrative(world.id), style: const TextStyle(height: 1.45, color: Color(0xFF4A4F59))),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.tonal(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChangeWorldAchievementPage(controller: controller, worldId: world.id),
                                    ),
                                  );
                                },
                                child: const Text('查看世界成就'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          const SectionCard(
            title: '世界规则',
            child: Text('镜像世界并不替代现实。真正的剧情推进，必须由现实中的任务完成来解锁。'),
          ),
          ...worlds.map((world) {
            final unlocked = controller.isWorldUnlocked(world.id);
            return SectionCard(
              title: world.title,
              trailing: Chip(
                label: Text(unlocked ? '已解锁' : '待解锁'),
                backgroundColor: unlocked ? const Color(0xFFDFF5E8) : const Color(0xFFF1EEF7),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(world.description, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 8),
                  Text('场景目标：${world.sceneGoal}', style: const TextStyle(color: Color(0xFF5E6270))),
                  const SizedBox(height: 8),
                  Builder(builder: (_) {
                    final progress = controller.worldProgress(world.id);
                    final activeMission = controller.activeMissionForWorld(world.id);
                    final rewardHint = controller.latestRewardMessageForWorld(world.id);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: progress.ratio, minHeight: 8, borderRadius: BorderRadius.circular(99)),
                        const SizedBox(height: 8),
                        Text('推进进度：${progress.completedActions}/${progress.targetActions} · ${controller.worldProgressLabel(world.id)}', style: const TextStyle(color: Color(0xFF5E6270))),
                        const SizedBox(height: 6),
                        Text('阶段任务：${controller.completedMissionCountForWorld(world.id)}/${controller.missionsForWorld(world.id).length}', style: const TextStyle(color: Color(0xFF5E6270))),
                        if (activeMission != null) ...[
                          const SizedBox(height: 8),
                          Text('当前主线：${activeMission.title}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(controller.worldMissionProgressText(activeMission.id), style: const TextStyle(color: Color(0xFF7A6177))),
                        ],
                        if (rewardHint != null) ...[
                          const SizedBox(height: 8),
                          Text(rewardHint, style: const TextStyle(color: Color(0xFF1C9E5E), height: 1.4)),
                        ],
                        const SizedBox(height: 8),
                        Text(controller.worldUnlockHint(world.id), style: const TextStyle(color: Color(0xFF7A6177), height: 1.45)),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MirrorWorldScenePage(
                            controller: controller,
                            worldId: world.id,
                          ),
                        ),
                      );
                    },
                    child: Text(unlocked ? '进入场景' : '查看解锁条件'),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
