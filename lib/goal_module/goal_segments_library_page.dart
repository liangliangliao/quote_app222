import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_segment_detail_page.dart';
import 'goal_study_progress_page.dart';

class GoalSegmentsLibraryPage extends StatefulWidget {
  final String? initialCourse;
  final String? initialModuleGroup;

  const GoalSegmentsLibraryPage({super.key, this.initialCourse, this.initialModuleGroup});

  @override
  State<GoalSegmentsLibraryPage> createState() => _GoalSegmentsLibraryPageState();
}

class _GoalSegmentsLibraryPageState extends State<GoalSegmentsLibraryPage> {
  final _dao = GoalDao();
  late String _course;
  late String _moduleGroup;
  late Future<_LibraryBundle> _future;

  @override
  void initState() {
    super.initState();
    _course = widget.initialCourse ?? 'ALL';
    _moduleGroup = widget.initialModuleGroup ?? 'ALL';
    _future = _load();
  }

  Future<_LibraryBundle> _load() async {
    final modules = await _dao.listModuleGroups();
    final items = await _dao.listSegments(
      sourceCourse: _course == 'ALL' ? null : _course,
      moduleGroup: _moduleGroup == 'ALL' ? null : _moduleGroup,
    );
    return _LibraryBundle(modules: modules, segments: items);
  }

  void _reload({String? course, String? moduleGroup}) {
    setState(() {
      if (course != null) _course = course;
      if (moduleGroup != null) _moduleGroup = moduleGroup;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课程原文馆'),
        actions: [
          IconButton(
            tooltip: '学习进度',
            onPressed: () {
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GoalStudyProgressPage()));
            },
            icon: const Icon(Icons.timeline_outlined),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_LibraryBundle>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(snap.error?.toString() ?? '加载失败'));
          }
          final data = snap.data!;
          return Column(
            children: [
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _filterChip('全部', 'ALL'),
                    const SizedBox(width: 8),
                    _filterChip('PP12（21段）', 'PP12'),
                    const SizedBox(width: 8),
                    _filterChip('第13集（15段）', 'ST13'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _moduleGroup,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('全部主题')),
                        ...data.modules.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                      ],
                      onChanged: (v) {
                        if (v != null) _reload(moduleGroup: v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: data.segments.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _HeroInfo(count: data.segments.length, course: _course, moduleGroup: _moduleGroup);
                    }
                    final s = data.segments[index - 1];
                    return _SegmentTile(
                      segment: s,
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: s.segmentId)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _course == value;
    return GestureDetector(
      onTap: () => _reload(course: value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? null : const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : const Color(0xFF374151), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  final int count;
  final String course;
  final String moduleGroup;
  const _HeroInfo({required this.count, required this.course, required this.moduleGroup});

  @override
  Widget build(BuildContext context) {
    String subtitle;
    if (course == 'PP12') {
      subtitle = '正在查看 POSITIVE PSYCHOLOGY 12 后半段的 21 段课程简化正文。';
    } else if (course == 'ST13') {
      subtitle = '正在查看第13集《面对压力》中与目标直接相关的 15 段课程简化正文。';
    } else {
      subtitle = '这里完整保留了 36 段课程简化正文，供用户查看、复习与后续实践调用。';
    }
    if (moduleGroup != 'ALL') {
      subtitle = '$subtitle\n当前主题：$moduleGroup';
    }
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
          const Text('原课程正文层', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(height: 1.6, color: Color(0xFF4B5563))),
          const SizedBox(height: 12),
          Text('当前条目：$count 段', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('你也可以从右上角进入“学习进度”，查看最近复习、章节完成度和难点回顾。', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5)),
        ],
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final GoalCourseSegment segment;
  final VoidCallback onTap;
  const _SegmentTile({required this.segment, required this.onTap});

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
                child: Center(
                  child: Text('${segment.segmentNo}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(segment.sectionTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(segment.moduleGroup, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    Text(
                      segment.segmentText.replaceAll('\n', ' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryBundle {
  final List<String> modules;
  final List<GoalCourseSegment> segments;

  _LibraryBundle({required this.modules, required this.segments});
}
