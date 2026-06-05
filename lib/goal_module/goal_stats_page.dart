import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';

class GoalStatsPage extends StatefulWidget {
  const GoalStatsPage({super.key});

  @override
  State<GoalStatsPage> createState() => _GoalStatsPageState();
}

class _GoalStatsPageState extends State<GoalStatsPage> {
  final _dao = GoalDao();
  late Future<_StatsBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatsBundle> _load() async {
    final stats = await _dao.getStatsSummary();
    final recent = await _dao.listActionRecordViews(limit: 5);
    final moduleReviews = await _dao.listModuleReviewProgress();
    return _StatsBundle(stats: stats, recent: recent, moduleReviews: moduleReviews);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('目标模块数据看板')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_StatsBundle>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(snap.error?.toString() ?? '加载失败'));
          }
          final s = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _hero(),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.45,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _statCard('课程正文', '${s.stats['segments'] ?? 0}', '36 段原文作为学习底座'),
                  _statCard('概念实践卡', '${s.stats['concepts'] ?? 0}', '每段课程外挂概念实践层'),
                  _statCard('已复习正文', '${s.stats['reviewed'] ?? 0}', '打开正文详情后会计入复习轨迹'),
                  _statCard('收藏/重点/难点', '${(s.stats['favorites'] ?? 0)}/${(s.stats['keys'] ?? 0)}/${(s.stats['difficult'] ?? 0)}', '便于回看与复习'),
                  _statCard('行动记录', '${s.stats['actions'] ?? 0}', '执行次数与复盘痕迹'),
                  _statCard('二次复盘', '${s.stats['followups'] ?? 0}', '继续 / 调整 / 放弃 的闭环决策'),
                  _statCard('场景任务 / 奖励', '${s.stats['worldScenes'] ?? 0}/${s.stats['worldRewards'] ?? 0}', '目标试验场完成数与已领奖励'),
                  _statCard('主题复盘 / 入行动', '${s.stats['moduleReviews'] ?? 0}/${s.stats['moduleReviewActions'] ?? 0}', '已写主题复盘数 / 已发起行动数'),
                ],
              ),

              const SizedBox(height: 12),
              _card(
                title: '主题复盘统计',
                child: s.moduleReviews.isEmpty
                    ? const Text('还没有主题复盘统计。')
                    : Column(
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _pillStat('已写主题复盘', '${s.moduleReviews.where((e) => e.hasReflection).length}'),
                              _pillStat('写过现实一步', '${s.moduleReviews.where((e) => e.hasActionStep).length}'),
                              _pillStat('进入行动', '${s.moduleReviews.where((e) => e.enteredActionLoop).length}'),
                              _pillStat('进入闭环', '${s.moduleReviews.where((e) => e.enteredFollowupLoop).length}'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _moduleReviewVisualizationCard(s.moduleReviews),
                          const SizedBox(height: 12),
                          for (final item in s.moduleReviews) ...[
                            _moduleReviewTile(item),
                            if (item != s.moduleReviews.last) const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '最近行动',
                child: s.recent.isEmpty
                    ? const Text('还没有行动记录。')
                    : Column(
                        children: [
                          for (final item in s.recent)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(item.actionTitle, style: const TextStyle(fontWeight: FontWeight.w800))),
                                        if (item.hasFollowup) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF111827),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(item.followupDecision, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text('${(item.record.completionRate * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(item.conceptTitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hero() => _card(
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('成长不是只看页面数量', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              '这个看板帮助你看到：课程原文、概念实践、收藏复习和现实行动是否真正形成闭环。',
              style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
            ),
          ],
        ),
      );

  Widget _pillStat(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      );

  Widget _moduleReviewTile(GoalModuleReviewProgress item) {
    final updated = item.updatedAtMs <= 0 ? '未写复盘' : _fmt(item.updatedAtMs);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.moduleGroup, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text('${(item.completionRate * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.sourceCourseName, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(item.hasReflection ? '已复盘' : '未复盘', item.hasReflection),
              _statusChip(item.hasActionStep ? '写过现实一步' : '未写现实一步', item.hasActionStep),
              _statusChip(item.enteredActionLoop ? '已进行动' : '未进行动', item.enteredActionLoop),
              _statusChip(item.enteredFollowupLoop ? '已进闭环' : '未进闭环', item.enteredFollowupLoop),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '已复习 ${item.reviewedSegments}/${item.totalSegments} · 行动 ${item.actionCount} · 闭环 ${item.followupCount} · 最近更新 $updated',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }


  Widget _moduleReviewVisualizationCard(List<GoalModuleReviewProgress> items) {
    final total = items.length;
    final reflectionCount = items.where((e) => e.hasReflection).length;
    final actionReadyCount = items.where((e) => e.hasActionStep).length;
    final actionCount = items.where((e) => e.enteredActionLoop).length;
    final followupCount = items.where((e) => e.enteredFollowupLoop).length;
    final blockedAtAction = items.where((e) => e.hasActionStep && !e.enteredActionLoop).toList();
    final blockedAtFollowup = items.where((e) => e.enteredActionLoop && !e.enteredFollowupLoop).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('主题复盘转化可视化', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            '从“写下复盘”到“进入行动”再到“进入闭环”，这里帮助你看见每个主题最容易卡在哪一步。',
            style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          _stageBar('已写复盘', reflectionCount, total),
          const SizedBox(height: 8),
          _stageBar('写过现实一步', actionReadyCount, total),
          const SizedBox(height: 8),
          _stageBar('进入行动', actionCount, total),
          const SizedBox(height: 8),
          _stageBar('进入闭环', followupCount, total),
          if (blockedAtAction.isNotEmpty) ...[
            const SizedBox(height: 12),
            _warningList(
              title: '更容易卡在“写了现实一步，但还没发起行动”的主题',
              items: blockedAtAction,
            ),
          ],
          if (blockedAtFollowup.isNotEmpty) ...[
            const SizedBox(height: 12),
            _warningList(
              title: '更容易卡在“已经行动，但还没完成二次复盘”的主题',
              items: blockedAtFollowup,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stageBar(String label, int value, int total) {
    final rate = total == 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('$value/$total · ${(rate * 100).round()}%', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: rate,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF111827)),
          ),
        ),
      ],
    );
  }

  Widget _warningList({required String title, required List<GoalModuleReviewProgress> items}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final item in items.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.fiber_manual_record_rounded, size: 10, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.moduleGroup} · ${item.reviewedSegments}/${item.totalSegments} 已复习 · 行动 ${item.actionCount} · 闭环 ${item.followupCount}',
                      style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF4B5563)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _statusChip(String label, bool active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? const Color(0xFF111827) : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      );

  String _fmt(int ms) {
    if (ms <= 0) return '未记录';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  Widget _statCard(String title, String value, String subtitle) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF6B7280))),
          ],
        ),
      );

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
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      );
}

class _StatsBundle {
  final Map<String, int> stats;
  final List<GoalActionRecordView> recent;
  final List<GoalModuleReviewProgress> moduleReviews;
  _StatsBundle({required this.stats, required this.recent, required this.moduleReviews});
}
