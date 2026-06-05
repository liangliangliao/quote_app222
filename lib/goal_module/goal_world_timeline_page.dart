import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_world_profile_page.dart';
import 'goal_world_scene_detail_page.dart';
import 'goal_world_seed.dart';

class GoalWorldTimelinePage extends StatefulWidget {
  const GoalWorldTimelinePage({super.key});

  @override
  State<GoalWorldTimelinePage> createState() => _GoalWorldTimelinePageState();
}

class _GoalWorldTimelinePageState extends State<GoalWorldTimelinePage> {
  final _dao = GoalDao();
  late Future<_TimelineBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TimelineBundle> _load() async {
    final events = await _dao.listWorldTimelineEvents(limit: 60);
    final profile = await _dao.getWorldProfile();
    final evolution = await _dao.getWorldIdentityEvolution();
    return _TimelineBundle(events: events, profile: profile, evolution: evolution);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
  }

  Future<void> _openScene(String sceneId) async {
    if (sceneId.trim().isEmpty) return;
    await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => GoalWorldSceneDetailPage(sceneId: sceneId)));
    await _reload();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorldProfilePage()));
    await _reload();
  }

  String _sceneLabel(String sceneId) {
    if (sceneId.trim().isEmpty) return '世界身份 / 演化';
    for (final scene in goalWorldScenes) {
      if (scene.sceneId == sceneId) return scene.title;
    }
    return '目标试验场';
  }

  String _eventTypeLabel(String eventType) {
    switch (eventType) {
      case 'identity_shift':
        return '身份跃迁';
      case 'growth_shift':
        return '成长变化';
      case 'reward_claimed':
        return '奖励领取';
      case 'branch_choice':
        return '分支选择';
      case 'reality_translation':
        return '带回现实';
      default:
        return '事件';
    }
  }

  Color _eventColor(String eventType) {
    switch (eventType) {
      case 'identity_shift':
        return const Color(0xFF7C3AED);
      case 'growth_shift':
        return const Color(0xFF0EA5E9);
      case 'reward_claimed':
        return const Color(0xFF059669);
      case 'branch_choice':
        return const Color(0xFFF59E0B);
      case 'reality_translation':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '刚刚';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.month}-${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('现实事件时间线')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_TimelineBundle>(
        future: _future,
        builder: (context, snap) {
          final bundle = snap.data;
          final events = bundle?.events ?? const <GoalWorldTimelineEvent>[];
          final profile = bundle?.profile ?? GoalWorldProfile.empty();
          final evolution = bundle?.evolution ?? const GoalWorldIdentityEvolution.empty();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('世界导航链', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      '这里把你在目标试验场里经历的关键事件，沿着时间轴串起来：你是谁、你在场景里怎么选、收获了什么、这些练习怎样推动了你的成长与身份演化。',
                      style: TextStyle(color: Color(0xFF374151), height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _navChip(Icons.person_outline, '世界身份', _openProfile),
                        if (profile.hasContent)
                          _navChip(Icons.track_changes_outlined, '当前演化：${evolution.stageTitle}', _openProfile),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (events.isEmpty)
                _card(
                  child: const Text('当你在场景里做选择、领取奖励、把练习带回现实后，这里会逐步长出一条可回看的世界时间线。', style: TextStyle(color: Color(0xFF6B7280), height: 1.6)),
                )
              else
                ...events.map((item) {
                  final hasScene = item.sceneId.trim().isNotEmpty;
                  return _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: _eventColor(item.eventType), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _pill(_eventTypeLabel(item.eventType)),
                            _pill(_sceneLabel(item.sceneId)),
                            _pill(_formatTime(item.createdAtMs)),
                          ],
                        ),
                        if (item.body.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(item.body, style: const TextStyle(color: Color(0xFF374151), height: 1.6)),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (hasScene)
                              OutlinedButton.icon(
                                onPressed: () => _openScene(item.sceneId),
                                icon: const Icon(Icons.north_east_outlined),
                                label: const Text('回到对应场景'),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: _openProfile,
                                icon: const Icon(Icons.fact_check_outlined),
                                label: const Text('查看现实事件上下文'),
                              ),
                            if (item.eventType == 'identity_shift')
                              FilledButton.tonalIcon(
                                onPressed: _openProfile,
                                icon: const Icon(Icons.psychology_alt_outlined),
                                label: const Text('查看身份演化'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _navChip(IconData icon, String label, VoidCallback onTap) => ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      );

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: child,
      );
}

class _TimelineBundle {
  final List<GoalWorldTimelineEvent> events;
  final GoalWorldProfile profile;
  final GoalWorldIdentityEvolution evolution;

  const _TimelineBundle({required this.events, required this.profile, required this.evolution});
}
