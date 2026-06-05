import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_segments_library_page.dart';

class GoalTopicReviewPage extends StatefulWidget {
  const GoalTopicReviewPage({super.key});

  @override
  State<GoalTopicReviewPage> createState() => _GoalTopicReviewPageState();
}

class _GoalTopicReviewPageState extends State<GoalTopicReviewPage> {
  final _dao = GoalDao();
  late Future<_TopicBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TopicBundle> _load() async {
    final all = await _dao.listSegments();
    final counts = await _dao.getModuleSegmentCounts();
    final modules = <String, List<GoalCourseSegment>>{};
    for (final s in all) {
      modules.putIfAbsent(s.moduleGroup, () => []).add(s);
    }
    return _TopicBundle(modules: modules, counts: counts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('按主题复习')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_TopicBundle>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(snap.error?.toString() ?? '加载失败'));
          }
          final data = snap.data!;
          final ordered = data.modules.keys.toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _heroCard(),
              const SizedBox(height: 12),
              for (final module in ordered) ...[
                _TopicCard(
                  module: module,
                  count: data.counts[module] ?? data.modules[module]!.length,
                  courses: data.modules[module]!.map((e) => e.sourceCourseName).toSet().join(' / '),
                  titles: data.modules[module]!.map((e) => e.sectionTitle).take(3).toList(),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => GoalSegmentsLibraryPage(initialModuleGroup: module),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('按主题回看 36 段课程正文', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              '不是只按课次看，也可以按主题回看。这样做更适合在现实遇到问题时，直接找到相关课程内容。',
              style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
            ),
          ],
        ),
      );
}

class _TopicCard extends StatelessWidget {
  final String module;
  final int count;
  final String courses;
  final List<String> titles;
  final VoidCallback onTap;

  const _TopicCard({
    required this.module,
    required this.count,
    required this.courses,
    required this.titles,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(courses, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    Text(
                      titles.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicBundle {
  final Map<String, List<GoalCourseSegment>> modules;
  final Map<String, int> counts;

  _TopicBundle({required this.modules, required this.counts});
}
