import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_module_review_page.dart';
import 'goal_segment_detail_page.dart';

class GoalStudyProgressPage extends StatefulWidget {
  const GoalStudyProgressPage({super.key});

  @override
  State<GoalStudyProgressPage> createState() => _GoalStudyProgressPageState();
}

class _GoalStudyProgressPageState extends State<GoalStudyProgressPage> {
  final _dao = GoalDao();
  late Future<_ProgressBundle> _future;
  String _course = 'ALL';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProgressBundle> _load() async {
    final courseProgress = await _dao.listCourseProgress();
    final moduleProgress = await _dao.listModuleProgress(sourceCourse: _course == 'ALL' ? null : _course);
    final moduleReviewProgress = await _dao.listModuleReviewProgress(sourceCourse: _course == 'ALL' ? null : _course);
    final recent = await _dao.listRecentReviewedSegments(limit: 8);
    final difficult = await _dao.listReviewedSegments('difficult');
    return _ProgressBundle(
      courseProgress: courseProgress,
      moduleProgress: moduleProgress,
      moduleReviewProgress: moduleReviewProgress,
      recent: recent,
      difficult: difficult.take(6).toList(),
    );
  }

  void _reload({String? course}) {
    setState(() {
      if (course != null) _course = course;
      _future = _load();
    });
  }

  String _fmt(int ms) {
    if (ms <= 0) return '未记录';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('课程原文馆学习进度')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_ProgressBundle>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(snap.error?.toString() ?? '加载失败'));
          }
          final data = snap.data!;
          final reviewedTotal = data.courseProgress.fold<int>(0, (sum, e) => sum + e.reviewedCount);
          final total = data.courseProgress.fold<int>(0, (sum, e) => sum + e.totalCount);
          final difficultCount = data.courseProgress.fold<int>(0, (sum, e) => sum + e.difficultCount);
          final keyCount = data.courseProgress.fold<int>(0, (sum, e) => sum + e.keyCount);
          final reflectionCount = data.moduleReviewProgress.where((e) => e.hasReflection).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _heroCard(reviewedTotal, total, difficultCount, keyCount, reflectionCount),
              const SizedBox(height: 12),
              _card(
                title: '查看范围',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip('全部主题', 'ALL'),
                    _filterChip('PP12', 'PP12'),
                    _filterChip('第13集', 'ST13'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '章节完成度',
                child: Column(
                  children: [
                    for (final item in data.courseProgress) ...[
                      _courseProgressTile(item),
                      if (item != data.courseProgress.last) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '主题学习进度',
                child: data.moduleProgress.isEmpty
                    ? const Text('当前范围下还没有主题进度。')
                    : Column(
                        children: [
                          for (final item in data.moduleProgress) ...[
                            _moduleProgressTile(item),
                            if (item.completionRate >= 1) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '该主题已完成。下次再打开其中任意一段正文时，会触发章节完成仪式，并推荐下一步概念或行动。',
                                      style: TextStyle(height: 1.5, color: Color(0xFF4B5563)),
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => Navigator.of(context).push(
                                          CupertinoPageRoute(
                                            builder: (_) => GoalModuleReviewPage(
                                              sourceCourse: item.sourceCourse,
                                              moduleGroup: item.moduleGroup,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.edit_note_rounded),
                                        label: const Text('进入主题复盘'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (item != data.moduleProgress.last) const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: 12),
              _card(
                title: '主题复盘统计',
                child: data.moduleReviewProgress.isEmpty
                    ? const Text('当前范围下还没有主题复盘统计。')
                    : Column(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _tagInfo('已写主题复盘 ${data.moduleReviewProgress.where((e) => e.hasReflection).length}'),
                              _tagInfo('写过现实一步 ${data.moduleReviewProgress.where((e) => e.hasActionStep).length}'),
                              _tagInfo('进入行动 ${data.moduleReviewProgress.where((e) => e.enteredActionLoop).length}'),
                              _tagInfo('进入闭环 ${data.moduleReviewProgress.where((e) => e.enteredFollowupLoop).length}'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _moduleReviewVisualSummary(data.moduleReviewProgress),
                          const SizedBox(height: 12),
                          for (final item in data.moduleReviewProgress) ...[
                            _moduleReviewProgressTile(item),
                            if (item != data.moduleReviewProgress.last) const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '最近复习',
                child: data.recent.isEmpty
                    ? const Text('还没有复习记录。打开一段课程正文后，这里会显示最近复习。')
                    : Column(
                        children: [
                          for (final item in data.recent) ...[
                            _segmentReviewTile(item, subtitle: '最近复习：${_fmt(item.review.reviewedAtMs)}'),
                            if (item != data.recent.last) const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '难点回顾卡',
                child: data.difficult.isEmpty
                    ? const Text('还没有标记难点。遇到难理解的段落时，可以在正文详情页标记“难点”。')
                    : Column(
                        children: [
                          for (final item in data.difficult) ...[
                            _difficultyCard(item),
                            if (item != data.difficult.last) const SizedBox(height: 10),
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

  Widget _heroCard(int reviewedTotal, int total, int difficultCount, int keyCount, int reflectionCount) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('复习增强：把“看过”变成真正的学习轨迹', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              '这里汇总课程原文馆的最近复习、章节完成度、难点回顾和主题学习进度，让 36 段正文不只是被保存，而是被反复学习。',
              style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _mini('已复习', '$reviewedTotal/$total')),
                const SizedBox(width: 10),
                Expanded(child: _mini('难点', '$difficultCount')),
                const SizedBox(width: 10),
                Expanded(child: _mini('重点', '$keyCount')),
                const SizedBox(width: 10),
                Expanded(child: _mini('主题复盘', '$reflectionCount')),
              ],
            ),
          ],
        ),
      );


  Widget _moduleReviewVisualSummary(List<GoalModuleReviewProgress> items) {
    final total = items.length;
    final reflected = items.where((e) => e.hasReflection).length;
    final actionReady = items.where((e) => e.hasActionStep).length;
    final actioned = items.where((e) => e.enteredActionLoop).length;
    final closed = items.where((e) => e.enteredFollowupLoop).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('主题复盘转化进度', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('这四条进度帮助你看见：哪些主题已经从“学完”推进到“写下现实一步”“发起行动”和“进入闭环”。', style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          _miniProgress('已写主题复盘', reflected, total),
          const SizedBox(height: 8),
          _miniProgress('写过现实一步', actionReady, total),
          const SizedBox(height: 8),
          _miniProgress('进入行动', actioned, total),
          const SizedBox(height: 8),
          _miniProgress('进入闭环', closed, total),
        ],
      ),
    );
  }

  Widget _miniProgress(String label, int value, int total) {
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

  Widget _tagInfo(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w700)),
      );

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

  Widget _courseProgressTile(GoalCourseProgress item) {
    final pct = (item.completionRate * 100).round();
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
              Expanded(child: Text(item.sourceCourseName, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: item.completionRate,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Text('已复习 ${item.reviewedCount}/${item.totalCount} · 收藏 ${item.favoriteCount} · 难点 ${item.difficultCount} · 重点 ${item.keyCount}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _moduleProgressTile(GoalModuleProgress item) {
    final pct = (item.completionRate * 100).round();
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
              Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.sourceCourse == 'PP12' ? 'PP12' : '第13集', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: item.completionRate,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Text('已复习 ${item.reviewedCount}/${item.totalCount} · 难点 ${item.difficultCount} · 重点 ${item.keyCount}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _moduleReviewProgressTile(GoalModuleReviewProgress item) {
    final updated = item.updatedAtMs <= 0 ? '未写复盘' : _fmt(item.updatedAtMs);
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
          Row(
            children: [
              Expanded(
                child: Text(
                  item.moduleGroup,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${(item.completionRate * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.sourceCourseName,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallChip(item.hasReflection ? '已复盘' : '未复盘'),
              _smallChip(item.hasActionStep ? '写过现实一步' : '未写现实一步'),
              _smallChip(item.enteredActionLoop ? '已进行动' : '未进行动'),
              _smallChip(item.enteredFollowupLoop ? '已进闭环' : '未进闭环'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '已复习 ${item.reviewedSegments}/${item.totalSegments} · 行动 ${item.actionCount} · 闭环 ${item.followupCount} · 最近更新 $updated',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          if (item.completionRate >= 1) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => GoalModuleReviewPage(
                      sourceCourse: item.sourceCourse,
                      moduleGroup: item.moduleGroup,
                    ),
                  ),
                ),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('进入主题复盘'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _segmentReviewTile(GoalReviewedSegment item, {required String subtitle}) => Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: item.segment.segmentId)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('${item.segment.segmentNo}', style: const TextStyle(fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.segment.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      );

  Widget _difficultyCard(GoalReviewedSegment item) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _smallChip(item.segment.sourceCourse == 'PP12' ? 'PP12' : '第13集'),
                _smallChip('第${item.segment.segmentNo}段'),
                if (item.review.isKey) _smallChip('也是重点'),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.segment.sectionTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              item.segment.segmentText.replaceAll('\n', ' '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.5, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: item.segment.segmentId)),
                ),
                child: const Text('重新阅读'),
              ),
            ),
          ],
        ),
      );

  Widget _smallChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
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

  Widget _filterChip(String label, String value) {
    final selected = _course == value;
    return GestureDetector(
      onTap: () => _reload(course: value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF374151), fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ProgressBundle {
  final List<GoalCourseProgress> courseProgress;
  final List<GoalModuleProgress> moduleProgress;
  final List<GoalModuleReviewProgress> moduleReviewProgress;
  final List<GoalReviewedSegment> recent;
  final List<GoalReviewedSegment> difficult;

  _ProgressBundle({
    required this.courseProgress,
    required this.moduleProgress,
    required this.moduleReviewProgress,
    required this.recent,
    required this.difficult,
  });
}
