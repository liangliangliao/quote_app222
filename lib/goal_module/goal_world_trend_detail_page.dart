import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_world_profile_page.dart';
import 'goal_world_timeline_page.dart';
import 'goal_world_scene_detail_page.dart';

class GoalWorldTrendDetailPage extends StatefulWidget {
  const GoalWorldTrendDetailPage({super.key});

  @override
  State<GoalWorldTrendDetailPage> createState() => _GoalWorldTrendDetailPageState();
}

class _GoalWorldTrendDetailPageState extends State<GoalWorldTrendDetailPage> {
  final _dao = GoalDao();
  late Future<_TrendBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TrendBundle> _load() async {
    final points = await _dao.getWorldSevenDayTrend();
    final snapshots = await _dao.listWorldStatusSnapshots(limit: 14);
    final profile = await _dao.getWorldProfile();
    return _TrendBundle(points: points, snapshots: snapshots, profile: profile);
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

  Widget? _snapshotContextButton(GoalWorldStatusSnapshot item, GoalWorldProfile profile) {
    if (item.sourceType == 'scene' && item.sourceId.trim().isNotEmpty) {
      return OutlinedButton.icon(
        onPressed: () => _openScene(item.sourceId),
        icon: const Icon(Icons.north_east_outlined),
        label: const Text('回到对应场景'),
      );
    }
    if (item.sourceType == 'profile' && profile.hasContent) {
      return OutlinedButton.icon(
        onPressed: _openProfile,
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('查看对应现实事件'),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('最近7天成长变化趋势')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_TrendBundle>(
        future: _future,
        builder: (context, snap) {
          final bundle = snap.data;
          final points = bundle?.points ?? const <GoalWorldSevenDayTrendPoint>[];
          final snapshots = bundle?.snapshots ?? const <GoalWorldStatusSnapshot>[];
          final profile = bundle?.profile ?? GoalWorldProfile.empty();
          final hasAny = points.any((e) => e.hasData);
          final maxValue = hasAny
              ? points.where((e) => e.hasData).map((e) => [e.clarity, e.alignment, e.momentum].reduce((a, b) => a > b ? a : b)).reduce((a, b) => a > b ? a : b)
              : 100;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Expanded(child: Text('最近7天成长变化趋势', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))), TextButton(onPressed: _openTimeline, child: const Text('看时间线'))]),
                    const SizedBox(height: 8),
                    Text(
                      hasAny ? '用最近7天的角色状态快照，看清晰度、一致性和行动势能是在持续抬升、波动，还是停在原地。' : '当你持续补全世界身份、推进场景练习并把收获带回现实后，这里会逐步长出最近7天的趋势图。',
                      style: const TextStyle(color: Color(0xFF374151), height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    if (profile.realEvent.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('最近关联的现实事件', style: TextStyle(fontWeight: FontWeight.w800)),
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
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: 220,
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
                                          _MiniBar(height: 120 * item.clarity / (maxValue == 0 ? 1 : maxValue), color: const Color(0xFF0EA5E9)),
                                          const SizedBox(width: 4),
                                          _MiniBar(height: 120 * item.alignment / (maxValue == 0 ? 1 : maxValue), color: const Color(0xFF8B5CF6)),
                                          const SizedBox(width: 4),
                                          _MiniBar(height: 120 * item.momentum / (maxValue == 0 ? 1 : maxValue), color: const Color(0xFFF59E0B)),
                                        ],
                                      )
                                    else
                                      const SizedBox(height: 120, child: Center(child: Text('—', style: TextStyle(color: Color(0xFF9CA3AF))))),
                                    const SizedBox(height: 8),
                                    Text(item.label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _LegendDot(color: Color(0xFF0EA5E9), label: '清晰度'),
                        _LegendDot(color: Color(0xFF8B5CF6), label: '一致性'),
                        _LegendDot(color: Color(0xFFF59E0B), label: '行动势能'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '逐日明细',
                child: points.isEmpty
                    ? const Text('当快照数据逐步积累后，这里会开始显示每天的明细。', style: TextStyle(color: Color(0xFF6B7280), height: 1.6))
                    : Column(
                        children: [
                          for (int i = 0; i < points.length; i++) ...[
                            _dayRow(points, i),
                            if (i != points.length - 1) const Divider(height: 20),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '最近状态快照',
                child: snapshots.isEmpty
                    ? const Text('当你持续推进试验场，最近的状态快照会出现在这里。', style: TextStyle(color: Color(0xFF6B7280), height: 1.6))
                    : Column(
                        children: [
                          for (final item in snapshots.take(8)) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_snapshotTitle(item), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text('清晰度 ${item.clarity} · 一致性 ${item.alignment} · 行动势能 ${item.momentum}', style: const TextStyle(color: Color(0xFF374151))),
                                  if (item.note.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(item.note, style: const TextStyle(color: Color(0xFF6B7280), height: 1.5)),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(_formatTime(item.createdAtMs), style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                  if (_snapshotContextButton(item, profile) != null) ...[
                                    const SizedBox(height: 8),
                                    _snapshotContextButton(item, profile)!,
                                  ],
                                ],
                              ),
                            ),
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

  Widget _dayRow(List<GoalWorldSevenDayTrendPoint> points, int index) {
    final item = points[index];
    GoalWorldSevenDayTrendPoint? prev;
    for (int i = index - 1; i >= 0; i--) {
      if (points[i].hasData) {
        prev = points[i];
        break;
      }
    }
    String deltaText(int current, int? previous) {
      if (previous == null) return '—';
      final delta = current - previous;
      return '${delta >= 0 ? '+' : ''}$delta';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 50, child: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
          child: !item.hasData
              ? const Text('暂无快照', style: TextStyle(color: Color(0xFF9CA3AF)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('清晰度 ${item.clarity}（${deltaText(item.clarity, prev?.clarity)}）', style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('一致性 ${item.alignment}（${deltaText(item.alignment, prev?.alignment)}）', style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('行动势能 ${item.momentum}（${deltaText(item.momentum, prev?.momentum)}）', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w700)),
                  ],
                ),
        ),
      ],
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

  String _snapshotTitle(GoalWorldStatusSnapshot item) {
    if (item.sourceType == 'scene') return '来自场景：${item.sourceId}';
    if (item.sourceType == 'profile') return '来自世界身份';
    return '状态快照';
  }


  Future<void> _openTimeline() async {
    await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalWorldTimelinePage()));
    setState(() => _future = _load());
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '刚刚';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _TrendBundle {
  final List<GoalWorldSevenDayTrendPoint> points;
  final List<GoalWorldStatusSnapshot> snapshots;
  final GoalWorldProfile profile;

  const _TrendBundle({required this.points, required this.snapshots, required this.profile});
}

class _MiniBar extends StatelessWidget {
  final double height;
  final Color color;
  const _MiniBar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: height.clamp(8.0, 120.0),
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
