import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_world_scene_detail_page.dart';
import 'goal_world_profile_page.dart';
import 'goal_world_timeline_page.dart';

class GoalWorldIdentityLeapDetailPage extends StatefulWidget {
  const GoalWorldIdentityLeapDetailPage({super.key});

  @override
  State<GoalWorldIdentityLeapDetailPage> createState() => _GoalWorldIdentityLeapDetailPageState();
}

class _GoalWorldIdentityLeapDetailPageState extends State<GoalWorldIdentityLeapDetailPage> {
  final _dao = GoalDao();
  late Future<_LeapBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LeapBundle> _load() async {
    final detail = await _dao.getRecentIdentityLeapDetail();
    final shifts = await _dao.listWorldIdentityShiftEvents(limit: 8);
    final practice = await _dao.getWorldPracticeTimelineSummary();
    final profile = await _dao.getWorldProfile();
    return _LeapBundle(detail: detail, shifts: shifts, practice: practice, profile: profile);
  }

  Future<void> _openScene(String sceneId) async {
    if (sceneId.trim().isEmpty) return;
    await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => GoalWorldSceneDetailPage(sceneId: sceneId)));
    setState(() => _future = _load());
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorldProfilePage()));
    setState(() => _future = _load());
  }


  Future<void> _openTimeline() async {
    await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorldTimelinePage()));
    setState(() => _future = _load());
  }

  Widget? _contextButtonForEvent(GoalWorldTimelineEvent item, GoalWorldProfile profile) {
    if (item.sceneId.trim().isNotEmpty) {
      return OutlinedButton.icon(
        onPressed: () => _openScene(item.sceneId),
        icon: const Icon(Icons.north_east_outlined),
        label: const Text('回到对应场景'),
      );
    }
    if (profile.hasContent) {
      return OutlinedButton.icon(
        onPressed: _openProfile,
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('查看对应现实事件'),
      );
    }
    return null;
  }

  Widget _timelineEventCard(GoalWorldTimelineEvent item, GoalWorldProfile profile) {
    final btn = _contextButtonForEvent(item, profile);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (item.body.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.body, style: const TextStyle(color: Color(0xFF4B5563), height: 1.55)),
          ],
          const SizedBox(height: 6),
          Text(_formatTime(item.createdAtMs), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          if (btn != null) ...[
            const SizedBox(height: 8),
            btn,
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, int? before, int? after, int delta) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text('${before ?? 0} → ${after ?? 0}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${delta >= 0 ? '+' : ''}$delta', style: TextStyle(fontWeight: FontWeight.w700, color: delta >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('最近一次身份跃迁详情')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_LeapBundle>(
        future: _future,
        builder: (context, snap) {
          final bundle = snap.data;
          final detail = bundle?.detail ?? const GoalWorldRecentIdentityLeapDetail.empty();
          final shifts = bundle?.shifts ?? const <GoalWorldTimelineEvent>[];
          final practice = bundle?.practice ?? const GoalWorldPracticeTimelineSummary.empty();
          final profile = bundle?.profile ?? GoalWorldProfile.empty();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Expanded(child: Text('最近一次身份跃迁', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))), TextButton(onPressed: _openTimeline, child: const Text('看时间线'))]),
                    const SizedBox(height: 8),
                    Text(
                      detail.headline.trim().isNotEmpty ? detail.headline : '当试验场里的练习真正改变了你是谁，这里会把最近一次跃迁讲清楚。',
                      style: const TextStyle(color: Color(0xFF374151), height: 1.6),
                    ),
                    if (detail.hasShift) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detail.latestShift!.title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF312E81))),
                            if (detail.latestShift!.body.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(detail.latestShift!.body, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                            ],
                            if (_contextButtonForEvent(detail.latestShift!, profile) != null) ...[
                              const SizedBox(height: 8),
                              _contextButtonForEvent(detail.latestShift!, profile)!,
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (profile.realEvent.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('当前对应的现实事件', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(profile.realEvent, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _openProfile,
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('查看现实事件上下文'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '这次跃迁前后，你哪里变了',
                child: detail.hasBeforeAfter
                    ? Row(
                        children: [
                          Expanded(child: _metric('清晰度', detail.beforeSnapshot?.clarity, detail.afterSnapshot?.clarity, detail.clarityDelta)),
                          const SizedBox(width: 8),
                          Expanded(child: _metric('一致性', detail.beforeSnapshot?.alignment, detail.afterSnapshot?.alignment, detail.alignmentDelta)),
                          const SizedBox(width: 8),
                          Expanded(child: _metric('行动势能', detail.beforeSnapshot?.momentum, detail.afterSnapshot?.momentum, detail.momentumDelta)),
                        ],
                      )
                    : const Text('还没有足够的前后快照来对比这次跃迁。', style: TextStyle(color: Color(0xFF6B7280), height: 1.6)),
              ),
              const SizedBox(height: 12),
              _card(
                title: '这次变化的证据',
                child: detail.evidence.isEmpty
                    ? const Text('当你写下现实事件、推进场景、把收获带回现实后，这里会开始积累这次变化的证据。', style: TextStyle(color: Color(0xFF6B7280), height: 1.6))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in detail.evidence)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
                              child: Text(item, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '最近最推动这次变化的场景',
                child: detail.hasStrongestScene
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(detail.strongestSceneTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                          if (detail.strongestSceneReason.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(detail.strongestSceneReason, style: const TextStyle(color: Color(0xFF374151), height: 1.55)),
                          ],
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openScene(detail.strongestSceneId),
                            icon: const Icon(Icons.north_east_outlined),
                            label: const Text('去看看这一关'),
                          ),
                        ],
                      )
                    : const Text('当某一关明显推动了你的变化，这里会直接指出来。', style: TextStyle(color: Color(0xFF6B7280), height: 1.6)),
              ),
              const SizedBox(height: 12),
              _card(
                title: '最近几次身份跃迁',
                child: shifts.isEmpty
                    ? const Text('当身份演化真正发生变化时，这里会逐步积累“身份跃迁”事件。', style: TextStyle(color: Color(0xFF6B7280), height: 1.6))
                    : Column(
                        children: [
                          for (final item in shifts) _timelineEventCard(item, profile),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '它在整条练习时间轴里的位置',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(practice.headline, style: const TextStyle(color: Color(0xFF374151), height: 1.6)),
                    if (practice.recentEvents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final item in practice.recentEvents.take(4)) _timelineEventCard(item, profile),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card({String? title, required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      );

  String _formatTime(int ms) {
    if (ms <= 0) return '刚刚';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _LeapBundle {
  final GoalWorldRecentIdentityLeapDetail detail;
  final List<GoalWorldTimelineEvent> shifts;
  final GoalWorldPracticeTimelineSummary practice;
  final GoalWorldProfile profile;

  const _LeapBundle({required this.detail, required this.shifts, required this.practice, required this.profile});
}
