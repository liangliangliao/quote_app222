import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_world_profile_page.dart';
import 'goal_world_identity_leap_detail_page.dart';
import 'goal_world_trend_detail_page.dart';
import 'goal_world_scene_detail_page.dart';
import 'goal_world_timeline_page.dart';
import 'goal_world_seed.dart';

class GoalVirtualWorldPage extends StatefulWidget {
  const GoalVirtualWorldPage({super.key});

  @override
  State<GoalVirtualWorldPage> createState() => _GoalVirtualWorldPageState();
}

class _GoalVirtualWorldPageState extends State<GoalVirtualWorldPage> {
  final _dao = GoalDao();
  late Future<_WorldHomeBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBundle();
  }

  Future<_WorldHomeBundle> _loadBundle() async {
    final progress = await _dao.listWorldSceneProgress();
    final profile = await _dao.getWorldProfile();
    final timeline = await _dao.listWorldTimelineEvents(limit: 6);
    final trajectory = await _dao.getWorldGrowthTrajectory(limit: 5);
    final evolution = await _dao.getWorldIdentityEvolution();
    final identityShifts = await _dao.listWorldIdentityShiftEvents(limit: 4);
    final practiceTimeline = await _dao.getWorldPracticeTimelineSummary();
    final leapDetail = await _dao.getRecentIdentityLeapDetail();
    final sevenDayTrend = await _dao.getWorldSevenDayTrend();
    return _WorldHomeBundle(
      profile: profile,
      progress: progress,
      timeline: timeline,
      trajectory: trajectory,
      evolution: evolution,
      identityShifts: identityShifts,
      practiceTimeline: practiceTimeline,
      leapDetail: leapDetail,
      sevenDayTrend: sevenDayTrend,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadBundle();
    });
  }

  Future<void> _openProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => const GoalWorldProfilePage()),
    );
    if (changed == true) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目标试验场'),
        actions: [
          IconButton(onPressed: _openProfile, icon: const Icon(Icons.person_outline)),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_WorldHomeBundle>(
        future: _future,
        builder: (context, snap) {
          final bundle = snap.data;
          final progressMap = {
            for (final item in (bundle?.progress ?? const <GoalWorldSceneProgress>[])) item.sceneId: item,
          };
          final profile = bundle?.profile ?? GoalWorldProfile.empty();
          final completedScenes = goalWorldScenes.where((scene) => (progressMap[scene.sceneId]?.completedTaskIds.length ?? 0) == scene.tasks.length && scene.tasks.isNotEmpty).length;
          final claimedRewards = goalWorldScenes.where((scene) => progressMap[scene.sceneId]?.rewardClaimed == true).length;
          final roleStatus = computeWorldRoleStatus(profile: profile, progressList: bundle?.progress ?? const <GoalWorldSceneProgress>[]);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _HeroCard(completedScenes: completedScenes, totalScenes: goalWorldScenes.length, claimedRewards: claimedRewards),
              const SizedBox(height: 12),
              _ProfileCard(profile: profile, onEdit: _openProfile),
              const SizedBox(height: 12),
              _RoleStatusCard(status: roleStatus),
              const SizedBox(height: 12),
              _GrowthTrajectoryCard(trajectory: bundle?.trajectory ?? const GoalWorldGrowthTrajectory.empty()),
              const SizedBox(height: 12),
              _IdentityEvolutionCard(
                evolution: bundle?.evolution ?? const GoalWorldIdentityEvolution.empty(),
                identityShifts: bundle?.identityShifts ?? const <GoalWorldTimelineEvent>[],
              ),
              const SizedBox(height: 12),
              _PracticeTimelineCard(
                summary: bundle?.practiceTimeline ?? const GoalWorldPracticeTimelineSummary.empty(),
                onOpenStrongestScene: () async {
                  final summary = bundle?.practiceTimeline ?? const GoalWorldPracticeTimelineSummary.empty();
                  if (!summary.hasStrongestScene) return;
                  await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => GoalWorldSceneDetailPage(sceneId: summary.strongestSceneId)));
                  await _reload();
                },
              ),
              const SizedBox(height: 12),
              _IdentityLeapDetailCard(
                detail: bundle?.leapDetail ?? const GoalWorldRecentIdentityLeapDetail.empty(),
                onOpenStrongestScene: () async {
                  final detail = bundle?.leapDetail ?? const GoalWorldRecentIdentityLeapDetail.empty();
                  if (!detail.hasStrongestScene) return;
                  await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => GoalWorldSceneDetailPage(sceneId: detail.strongestSceneId)));
                  await _reload();
                },
                onOpenDetail: () async {
                  await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorldIdentityLeapDetailPage()));
                  await _reload();
                },
              ),
              const SizedBox(height: 12),
              _SevenDayTrendCard(
                points: bundle?.sevenDayTrend ?? const <GoalWorldSevenDayTrendPoint>[],
                onOpenDetail: () async {
                  await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorldTrendDetailPage()));
                  await _reload();
                },
              ),
              const SizedBox(height: 12),
              _TimelineCard(
                events: bundle?.timeline ?? const <GoalWorldTimelineEvent>[],
                onOpenTimeline: () async {
                  await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorldTimelinePage()));
                  await _reload();
                },
              ),
              const SizedBox(height: 12),
              for (final scene in goalWorldScenes) ...[
                _SceneCard(
                  scene: scene,
                  profile: profile,
                  progress: progressMap[scene.sceneId] ?? GoalWorldSceneProgress.empty(scene.sceneId),
                  allProgress: bundle?.progress ?? const <GoalWorldSceneProgress>[],
                  onTap: () async {
                    await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => GoalWorldSceneDetailPage(sceneId: scene.sceneId)));
                    await _reload();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WorldHomeBundle {
  final GoalWorldProfile profile;
  final List<GoalWorldSceneProgress> progress;
  final List<GoalWorldTimelineEvent> timeline;
  final GoalWorldGrowthTrajectory trajectory;
  final GoalWorldIdentityEvolution evolution;
  final List<GoalWorldTimelineEvent> identityShifts;
  final GoalWorldPracticeTimelineSummary practiceTimeline;
  final GoalWorldRecentIdentityLeapDetail leapDetail;
  final List<GoalWorldSevenDayTrendPoint> sevenDayTrend;

  const _WorldHomeBundle({
    required this.profile,
    required this.progress,
    required this.timeline,
    required this.trajectory,
    required this.evolution,
    required this.identityShifts,
    required this.practiceTimeline,
    required this.leapDetail,
    required this.sevenDayTrend,
  });
}

class _HeroCard extends StatelessWidget {
  final int completedScenes;
  final int totalScenes;
  final int claimedRewards;

  const _HeroCard({
    required this.completedScenes,
    required this.totalScenes,
    required this.claimedRewards,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('目标试验场：把真实生活搬进一个可练习的虚拟世界', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            '这里不只是场景入口。先写下你的现实身份、最近发生的事和感受，再把它们带进迷雾平原、镜湖和工坊城，做一轮决策模拟；你选择的分支会进一步解锁不同后续任务，并影响系统推荐的现实行动。',
            style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _mini('完成场景', '$completedScenes/$totalScenes')),
              const SizedBox(width: 10),
              Expanded(child: _mini('已领奖励', '$claimedRewards')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );
}

class _ProfileCard extends StatelessWidget {
  final GoalWorldProfile profile;
  final VoidCallback onEdit;

  const _ProfileCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFF111827).withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.person_pin_circle_outlined, color: Color(0xFF111827)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('我的世界身份', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: Text(profile.hasContent ? '编辑' : '开始构建')),
            ],
          ),
          const SizedBox(height: 10),
          if (!profile.hasContent)
            const Text('还没有把真实世界带进试验场。先写下你的身份、最近事件和感受，场景里的任务和决策会更贴近你。', style: TextStyle(color: Color(0xFF4B5563), height: 1.6))
          else ...[
            Text(profile.profileTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (profile.summaryLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(profile.summaryLine, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
            ],
            if (profile.realEvent.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('最近真实事件：${profile.realEvent.trim()}', style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}



class _RoleStatusCard extends StatelessWidget {
  final GoalWorldRoleStatus status;

  const _RoleStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('角色状态面板', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(status.headline, style: const TextStyle(color: Color(0xFF374151), height: 1.6)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _meter('清晰度', status.clarity)),
              const SizedBox(width: 10),
              Expanded(child: _meter('一致性', status.alignment)),
              const SizedBox(width: 10),
              Expanded(child: _meter('行动势能', status.momentum)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('下一步聚焦：${status.nextFocus}', style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
          ),
        ],
      ),
    );
  }

  Widget _meter(String label, int value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );
}


class _GrowthTrajectoryCard extends StatelessWidget {
  final GoalWorldGrowthTrajectory trajectory;

  const _GrowthTrajectoryCard({required this.trajectory});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('持续成长轨迹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(trajectory.headline, style: const TextStyle(color: Color(0xFF374151), height: 1.6)),
          if (!trajectory.hasData) ...[
            const SizedBox(height: 10),
            const Text('当你更新世界身份、完成场景练习、把收获翻译回现实之后，这里会开始记录角色状态的抬升轨迹。', style: TextStyle(color: Color(0xFF6B7280), height: 1.6)),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _miniDelta('清晰度', trajectory.latestSnapshot!.clarity, trajectory.clarityDelta)),
                const SizedBox(width: 8),
                Expanded(child: _miniDelta('一致性', trajectory.latestSnapshot!.alignment, trajectory.alignmentDelta)),
                const SizedBox(width: 8),
                Expanded(child: _miniDelta('行动势能', trajectory.latestSnapshot!.momentum, trajectory.momentumDelta)),
              ],
            ),
            if (trajectory.recentSnapshots.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final item in trajectory.recentSnapshots.take(3)) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.note.trim().isEmpty ? '角色状态更新' : item.note.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('清晰度 ${item.clarity} · 一致性 ${item.alignment} · 行动势能 ${item.momentum}', style: const TextStyle(color: Color(0xFF4B5563))),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _miniDelta(String label, int value, int delta) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${delta >= 0 ? '+' : ''}$delta', style: TextStyle(fontSize: 12, color: delta >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );
}


class _IdentityEvolutionCard extends StatelessWidget {
  final GoalWorldIdentityEvolution evolution;
  final List<GoalWorldTimelineEvent> identityShifts;

  const _IdentityEvolutionCard({required this.evolution, required this.identityShifts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('我正在成为什么样的人', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (!evolution.hasContent)
            const Text('当你补全世界身份、推进场景练习并把收获带回现实之后，这里会开始形成一条身份演化记录。', style: TextStyle(color: Color(0xFF4B5563), height: 1.6))
          else ...[
            Text(evolution.stageTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (evolution.stageSubtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(evolution.stageSubtitle, style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
            ],
            const SizedBox(height: 8),
            Text(evolution.headline, style: const TextStyle(color: Color(0xFF374151), height: 1.6)),
            if (evolution.evidence.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in evolution.evidence.take(4))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(999)),
                      child: Text(item, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
            if (identityShifts.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('最近的身份演化节点', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final item in identityShifts.take(3))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (item.body.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(item.body, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PracticeTimelineCard extends StatelessWidget {
  final GoalWorldPracticeTimelineSummary summary;
  final VoidCallback onOpenStrongestScene;

  const _PracticeTimelineCard({required this.summary, required this.onOpenStrongestScene});

  Widget _deltaTile(String label, int before, int after) {
    final delta = after - before;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('$before → $after', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${delta >= 0 ? '+' : ''}$delta', style: TextStyle(fontSize: 12, color: delta >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('人生练习时间轴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(summary.headline, style: const TextStyle(color: Color(0xFF374151), height: 1.6)),
          if (summary.hasIdentityShift) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('最近一次身份跃迁', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  Text(summary.latestIdentityShift!.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (summary.latestIdentityShift!.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(summary.latestIdentityShift!.body, style: const TextStyle(color: Color(0xFF374151), height: 1.5)),
                  ],
                ],
              ),
            ),
          ],
          if (summary.hasBeforeAfter) ...[
            const SizedBox(height: 12),
            const Text('身份跃迁前后对比', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _deltaTile('清晰度', summary.previousSnapshot!.clarity, summary.latestSnapshot!.clarity)),
                const SizedBox(width: 8),
                Expanded(child: _deltaTile('一致性', summary.previousSnapshot!.alignment, summary.latestSnapshot!.alignment)),
                const SizedBox(width: 8),
                Expanded(child: _deltaTile('行动势能', summary.previousSnapshot!.momentum, summary.latestSnapshot!.momentum)),
              ],
            ),
          ],
          if (summary.hasStrongestScene) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('最近最推动这次变化的场景', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5))),
                  const SizedBox(height: 4),
                  Text(summary.strongestSceneTitle, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF312E81))),
                  if (summary.strongestSceneReason.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(summary.strongestSceneReason, style: const TextStyle(color: Color(0xFF374151), height: 1.5)),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onOpenStrongestScene,
                    icon: const Icon(Icons.landscape_outlined),
                    label: const Text('回到这个场景看看'),
                  ),
                ],
              ),
            ),
          ],
          if (summary.recentEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('最近几个推动节点', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final item in summary.recentEvents.take(3)) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (item.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(item.body, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _IdentityLeapDetailCard extends StatelessWidget {
  final GoalWorldRecentIdentityLeapDetail detail;
  final VoidCallback onOpenStrongestScene;
  final VoidCallback onOpenDetail;

  const _IdentityLeapDetailCard({required this.detail, required this.onOpenStrongestScene, required this.onOpenDetail});

  Widget _deltaTile(String label, int delta) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text('${delta >= 0 ? '+' : ''}$delta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: delta >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('最近一次身份跃迁详情', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            detail.headline.trim().isNotEmpty ? detail.headline : '当身份演化真正发生变化时，这里会告诉你最近一次变化是什么、为什么发生，以及是哪一关最推动了这次变化。',
            style: const TextStyle(color: Color(0xFF374151), height: 1.6),
          ),
          if (detail.hasShift) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.latestShift!.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (detail.latestShift!.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(detail.latestShift!.body, style: const TextStyle(color: Color(0xFF4B5563), height: 1.5)),
                  ],
                ],
              ),
            ),
          ],
          if (detail.hasBeforeAfter) ...[
            const SizedBox(height: 12),
            const Text('这次跃迁带来的状态变化', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _deltaTile('清晰度', detail.clarityDelta)),
                const SizedBox(width: 8),
                Expanded(child: _deltaTile('一致性', detail.alignmentDelta)),
                const SizedBox(width: 8),
                Expanded(child: _deltaTile('行动势能', detail.momentumDelta)),
              ],
            ),
          ],
          if (detail.evidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('这次变化的证据', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in detail.evidence.take(4))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
                    child: Text(item, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  ),
              ],
            ),
          ],
          if (detail.hasStrongestScene) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('最近最推动这次身份跃迁的场景', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5))),
                  const SizedBox(height: 4),
                  Text(detail.strongestSceneTitle, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF312E81))),
                  if (detail.strongestSceneReason.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(detail.strongestSceneReason, style: const TextStyle(color: Color(0xFF374151), height: 1.5)),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onOpenStrongestScene,
                    icon: const Icon(Icons.north_east_outlined),
                    label: const Text('去看看这一关'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onOpenDetail,
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('展开跃迁详情'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SevenDayTrendCard extends StatelessWidget {
  final List<GoalWorldSevenDayTrendPoint> points;
  final VoidCallback onOpenDetail;
  const _SevenDayTrendCard({required this.points, required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    final hasAny = points.any((e) => e.hasData);
    final maxValue = hasAny
        ? points.where((e) => e.hasData).map((e) => [e.clarity, e.alignment, e.momentum].reduce((a, b) => a > b ? a : b)).reduce((a, b) => a > b ? a : b)
        : 100;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('最近7天成长变化趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            hasAny ? '用最近7天的角色状态快照，看清晰度、一致性和行动势能是持续抬升、波动，还是停在原地。' : '当你持续补全世界身份、推进场景练习并把收获带回现实后，这里会开始显示最近7天的成长变化趋势。',
            style: const TextStyle(color: Color(0xFF374151), height: 1.6),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (item.hasData)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _MiniBar(height: 90 * item.clarity / (maxValue == 0 ? 1 : maxValue), color: const Color(0xFF0EA5E9)),
                                const SizedBox(width: 3),
                                _MiniBar(height: 90 * item.alignment / (maxValue == 0 ? 1 : maxValue), color: const Color(0xFF8B5CF6)),
                                const SizedBox(width: 3),
                                _MiniBar(height: 90 * item.momentum / (maxValue == 0 ? 1 : maxValue), color: const Color(0xFFF59E0B)),
                              ],
                            )
                          else
                            Container(
                              height: 90,
                              alignment: Alignment.center,
                              child: const Text('—', style: TextStyle(color: Color(0xFF9CA3AF))),
                            ),
                          const SizedBox(height: 8),
                          Text(item.label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendDot(color: Color(0xFF0EA5E9), label: '清晰度'),
              _LegendDot(color: Color(0xFF8B5CF6), label: '一致性'),
              _LegendDot(color: Color(0xFFF59E0B), label: '行动势能'),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onOpenDetail,
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('查看趋势明细'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final double height;
  final Color color;
  const _MiniBar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: height.clamp(6.0, 90.0),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final List<GoalWorldTimelineEvent> events;
  final VoidCallback onOpenTimeline;

  const _TimelineCard({required this.events, required this.onOpenTimeline});

  String _sceneLabel(String sceneId) {
    if (sceneId.trim().isEmpty) return '世界身份 / 演化';
    for (final scene in goalWorldScenes) {
      if (scene.sceneId == sceneId) return scene.title;
    }
    return '目标试验场';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('现实事件时间线', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              TextButton(onPressed: onOpenTimeline, child: const Text('查看全部')),
            ],
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Text('你在试验场里的分支选择、奖励领取和现实翻译，都会逐步沉淀在这里。', style: TextStyle(color: Color(0xFF6B7280), height: 1.6))
          else
            for (final item in events.take(4)) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(item.body, style: const TextStyle(color: Color(0xFF374151), height: 1.5)),
                    const SizedBox(height: 6),
                    Text(_sceneLabel(item.sceneId), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  final GoalWorldSceneDef scene;
  final GoalWorldProfile profile;
  final GoalWorldSceneProgress progress;
  final List<GoalWorldSceneProgress> allProgress;
  final VoidCallback onTap;

  const _SceneCard({required this.scene, required this.profile, required this.progress, required this.allProgress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = progress.completedTaskIds.length;
    final total = scene.tasks.length;
    final ratio = total == 0 ? 0.0 : done / total;
    final personalization = _scenePersonalization();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scene.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.landscape_outlined, color: scene.accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(scene.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(scene.subtitle, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                ],
              ),
              const SizedBox(height: 12),
              if (personalization.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scene.accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(personalization, style: TextStyle(color: scene.accentColor, height: 1.55, fontWeight: FontWeight.w600)),
                ),
              if (personalization.isNotEmpty) const SizedBox(height: 12),
              if (_incomingStateShift() != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('后续场景状态', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      const SizedBox(height: 4),
                      Text(_incomingStateShift()!.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(_incomingStateShift()!.description, style: const TextStyle(color: Color(0xFF374151), height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(scene.accentColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusChip('$done/$total 基础任务', const Color(0xFFF3F4F6), const Color(0xFF374151)),
                  if (_branchTaskCount() > 0)
                    _statusChip('${progress.completedBranchTaskIds.length}/${_branchTaskCount()} 分支任务', scene.accentColor.withOpacity(0.08), scene.accentColor),
                  _statusChip(progress.rewardClaimed ? '已领奖励' : '奖励未领取', progress.rewardClaimed ? scene.accentColor.withOpacity(0.12) : const Color(0xFFF3F4F6), progress.rewardClaimed ? scene.accentColor : const Color(0xFF6B7280)),
                  if (progress.activeBranchTaskId.trim().isNotEmpty)
                    _statusChip('分支停在：${_shortBranchTaskTitle(progress.activeBranchTaskId)}', scene.accentColor.withOpacity(0.08), scene.accentColor)
                  else if (progress.activeTaskId.trim().isNotEmpty)
                    _statusChip('上次停在：${_shortTaskTitle(progress.activeTaskId)}', scene.accentColor.withOpacity(0.08), scene.accentColor),
                ],
              ),
              if (progress.simulationChoiceId.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scene.accentColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _branchOutcomeSummary(),
                    style: TextStyle(color: scene.accentColor, height: 1.55, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(scene.rewardTitle + '：' + scene.rewardDescription, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
            ],
          ),
        ),
      ),
    );
  }

  String _scenePersonalization() {
    if (!profile.hasContent) return '';
    final role = profile.roleTitle.trim().isEmpty ? '现在的你' : profile.roleTitle.trim();
    final area = profile.lifeArea.trim().isEmpty ? '当前生活议题' : profile.lifeArea.trim();
    final event = profile.realEvent.trim();
    switch (scene.sceneId) {
      case 'fog_plain':
        return event.isEmpty
            ? '把 $role 在 $area 里的真实迷茫带进这一关，先找一个“暂时方向”。'
            : '围绕“$event”，先帮 $role 辨认什么是噪音，什么是你真的不能没有的。';
      case 'mirror_lake':
        return event.isEmpty
            ? '把你当前最重要的目标带进镜湖，检查它是不是像真正的你。'
            : '把“$event”代入镜湖，看看你现在追的目标更像热爱，还是更像迎合。';
      default:
        return event.isEmpty
            ? '把现在最想推进的一件事带进工坊城，拆成可以这周开始的一步。'
            : '把“$event”打造成执行蓝图，让 $role 在 $area 里真的迈出一步。';
    }
  }

  GoalWorldSceneStateShift? _incomingStateShift() => incomingSceneStateShift(
        sceneId: scene.sceneId,
        progressList: allProgress,
        profile: profile,
      );

  String _branchOutcomeSummary() {
    final outcome = branchOutcomeForSceneChoice(
      scene: scene,
      profile: profile,
      choiceId: progress.simulationChoiceId,
      reflection: progress.simulationReflection,
    );
    if (outcome == null) return '已做场景分支选择。';
    final count = _branchTaskCount();
    if (count > 0) {
      return '${outcome.title}：${outcome.statusHint} 当前分支任务 ${progress.completedBranchTaskIds.length}/$count。';
    }
    return '${outcome.title}：${outcome.statusHint}';
  }

  int _branchTaskCount() => branchTasksForSceneChoice(sceneId: scene.sceneId, choiceId: progress.simulationChoiceId).length;

  String _shortBranchTaskTitle(String taskId) {
    for (final task in branchTasksForSceneChoice(sceneId: scene.sceneId, choiceId: progress.simulationChoiceId)) {
      if (task.taskId == taskId) return task.title;
    }
    return '继续分支';
  }

  String _shortTaskTitle(String taskId) {
    for (final task in scene.tasks) {
      if (task.taskId == taskId) return task.title;
    }
    return '继续任务';
  }

  Widget _statusChip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w700)),
      );
}
