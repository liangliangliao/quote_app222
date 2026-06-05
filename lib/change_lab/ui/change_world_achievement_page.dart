import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/change_lab_controller.dart';
import 'change_concept_detail_page.dart';
import 'change_growth_timeline_page.dart';
import 'change_weekly_plan_page.dart';
import 'mirror_world_scene_page.dart';
import 'widgets/section_card.dart';

class ChangeWorldAchievementPage extends StatefulWidget {
  const ChangeWorldAchievementPage({
    super.key,
    required this.controller,
    required this.worldId,
  });

  final ChangeLabController controller;
  final String worldId;

  @override
  State<ChangeWorldAchievementPage> createState() => _ChangeWorldAchievementPageState();
}

class _ChangeWorldAchievementPageState extends State<ChangeWorldAchievementPage> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final worldId = widget.worldId;
    final world = controller.worldById(worldId);
    final completedAt = controller.worldCompletedAt(worldId);
    final missions = controller.missionsForWorld(worldId);
    final rewards = controller.rewardEventsForWorld(worldId).take(6).toList();
    final followUps = controller.followUpInstancesForCompletedWorld(worldId);
    final nextMission = controller.nextMissionAfterWorldCompletion(worldId);
    final recommended = controller.worldPriorityRecommendation ?? controller.recommendedTaskNow;
    final nextBranches = controller.recommendedNextWorldBranches(worldId);
    final nextBranchMissions = controller.recommendedNextBranchMissions(worldId);

    final completionText = completedAt == null
        ? '已点亮'
        : '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: const Text('世界完成成就'),
        backgroundColor: const Color(0xFFF4F2F8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7D5CFF), Color(0xFF4DA5F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'WORLD COMPLETED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  world.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  controller.worldAchievementPosterSubtitle(worldId),
                  style: const TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 14),
                Text(
                  controller.worldAchievementPosterBody(worldId),
                  style: const TextStyle(color: Colors.white, height: 1.55),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AchievementChip(label: '完成阶段 ${missions.length}', value: completionText),
                    _AchievementChip(label: '奖励事件', value: '${rewards.length}'),
                    _AchievementChip(label: '下一主线', value: nextMission == null ? '待推荐' : '已生成'),
                    _AchievementChip(label: '分支推荐', value: nextBranches.isEmpty ? '0' : '${nextBranches.length}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '完整世界叙事',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.worldCompletionNarrative(worldId), style: const TextStyle(height: 1.55)),
                const SizedBox(height: 10),
                Text(controller.nextMainlineSummaryForWorld(worldId), style: const TextStyle(color: Color(0xFF6A6175), height: 1.45)),
              ],
            ),
          ),
          SectionCard(
            title: '成就海报与后续计划',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('你可以把这个世界的完成叙事复制为海报文案，也可以直接基于它生成下一周计划，把奖励转成新的现实动作。', style: const TextStyle(height: 1.55)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: controller.achievementPosterShareText(worldId)));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('世界完成海报文案已复制，可直接分享或保存。')));
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('复制成就海报文案'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        controller.generateWeeklyPlanFromWorldCompletion(worldId);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已基于这个世界的完成状态生成新的下一周计划。')));
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeWeeklyPlanPage(controller: controller),
                          ),
                        );
                      },
                      icon: const Icon(Icons.event_note_outlined),
                      label: const Text('生成下一周计划'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F7FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6E0F0)),
                  ),
                  child: Text(
                    controller.achievementPosterShareText(worldId),
                    style: const TextStyle(height: 1.5, color: Color(0xFF4C4459)),
                  ),
                ),
              ],
            ),
          ),
          if (nextBranches.isNotEmpty)
            SectionCard(
              title: '多分支下一主线推荐',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(controller.branchRecommendationSummary(worldId), style: const TextStyle(height: 1.55)),
                  const SizedBox(height: 12),
                  ...nextBranches.take(3).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final branch = entry.value;
                    final mission = index < nextBranchMissions.length ? nextBranchMissions[index] : controller.activeMissionForWorld(branch.id);
                    final remaining = mission == null ? null : controller.remainingActionCountForMission(mission.id);
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
                              Expanded(
                                child: Text(branch.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              if (remaining != null)
                                Chip(label: Text('还差 $remaining 次动作')),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(branch.description, style: const TextStyle(height: 1.45)),
                          if (mission != null) ...[
                            const SizedBox(height: 6),
                            Text('当前阶段：${mission.title}', style: const TextStyle(color: Color(0xFF6A6175))),
                            const SizedBox(height: 4),
                            Text(controller.missionUnlockBanner(mission), style: const TextStyle(color: Color(0xFF6A6175), height: 1.4)),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MirrorWorldScenePage(controller: controller, worldId: branch.id),
                                    ),
                                  );
                                },
                                child: const Text('查看这条主线'),
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  controller.generateWeeklyPlanForWorldBranch(branch.id, sourceWorldId: worldId);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已将「${branch.title}」优先纳入下一周计划。')));
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChangeWeeklyPlanPage(controller: controller),
                                    ),
                                  );
                                },
                                child: const Text('纳入下一周计划'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          SectionCard(
            title: '阶段完成清单',
            child: Column(
              children: missions.map((mission) {
                final record = controller.missionRecordById(mission.id);
                final at = record.completedAt;
                final time = at == null
                    ? '未完成'
                    : '${at.month.toString().padLeft(2, '0')}/${at.day.toString().padLeft(2, '0')} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
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
                          Expanded(
                            child: Text('阶段 ${mission.stageNo}｜${mission.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const Chip(label: Text('已完成')),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(mission.summary, style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 6),
                      Text('完成时间：$time', style: const TextStyle(color: Color(0xFF6A6175))),
                      const SizedBox(height: 4),
                      Text('阶段奖励：${mission.rewardText}', style: const TextStyle(color: Color(0xFF6A6175), height: 1.4)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (followUps.isNotEmpty)
            SectionCard(
              title: '自动派发的下一步现实任务',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('完成这个世界后，系统已经为你派发了下一条主线动作。先别让奖励停在“感觉很好”，把它接成下一步现实证据。', style: const TextStyle(height: 1.55)),
                  const SizedBox(height: 12),
                  ...followUps.take(3).map((instance) {
                    final concept = controller.conceptById(instance.conceptId);
                    final task = controller.taskById(instance.conceptId, instance.taskId);
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
                          Text('${concept.title} · ${task.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(instance.assignedReason, style: const TextStyle(height: 1.45)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
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
                                child: const Text('去执行下一步'),
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChangeConceptDetailPage(controller: controller, concept: concept),
                                    ),
                                  );
                                },
                                child: const Text('查看对应概念'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          if (rewards.isNotEmpty)
            SectionCard(
              title: '奖励事件回放',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rewards.map((event) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('• ${controller.rewardFeedNarrative(event)}', style: const TextStyle(height: 1.45)),
                )).toList(),
              ),
            ),
          SectionCard(
            title: '下一步怎么走',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.nextMainlineSummaryForWorld(worldId), style: const TextStyle(height: 1.55)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
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
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MirrorWorldScenePage(controller: controller, worldId: worldId),
                          ),
                        );
                      },
                      child: const Text('回到完成世界'),
                    ),
                    if (recommended != null)
                      FilledButton(
                        onPressed: () {
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
                        child: const Text('去做推荐动作'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
