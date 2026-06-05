import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_action_history_page.dart';
import 'goal_action_record_detail_page.dart';
import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_segment_detail_page.dart';

class GoalReviewCenterPage extends StatefulWidget {
  const GoalReviewCenterPage({super.key});

  @override
  State<GoalReviewCenterPage> createState() => _GoalReviewCenterPageState();
}

class _GoalReviewCenterPageState extends State<GoalReviewCenterPage> {
  final _dao = GoalDao();
  String _tab = 'favorite';
  late Future<_ReviewBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReviewBundle> _load() async {
    final segments = await _dao.listReviewedSegments(_tab);
    final actions = await _dao.listActionRecordViews(limit: 20);
    return _ReviewBundle(segments: segments, actions: actions);
  }

  void _reload(String tab) {
    setState(() {
      _tab = tab;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('复习与行动记录')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<_ReviewBundle>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(snap.error?.toString() ?? '加载失败'));
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _heroCard(),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('收藏', 'favorite'),
                    const SizedBox(width: 8),
                    _chip('难点', 'difficult'),
                    const SizedBox(width: 8),
                    _chip('重点', 'key'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '正文复习列表',
                child: data.segments.isEmpty
                    ? const Text('这里还没有内容。去课程原文馆给段落打上收藏、难点或重点标记后，会出现在这里。')
: Column(
                        children: [
                          for (final item in data.segments)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
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
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text('${item.segment.segmentNo}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.segment.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                                              const SizedBox(height: 4),
                                              Text(item.segment.moduleGroup, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '最近行动记录',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          CupertinoPageRoute(builder: (_) => const GoalActionHistoryPage()),
                        ),
                        icon: const Icon(Icons.autorenew_outlined),
                        label: const Text('查看行动闭环'),
                      ),
                    ),
                    data.actions.isEmpty
                    ? const Text('还没有行动记录。可以从概念实践卡里的“立即执行”进入行动执行页。')
: Column(
                        children: [
                          for (final item in data.actions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => Navigator.of(context).push(
                                    CupertinoPageRoute(builder: (_) => GoalActionRecordDetailPage(recordId: item.record.id)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(item.actionTitle, style: const TextStyle(fontWeight: FontWeight.w800))),
                                            Text('${(item.record.completionRate * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(item.conceptTitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(child: Text(item.segmentTitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                                            if (item.hasFollowup)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF111827),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(item.followupDecision, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                                              ),
                                          ],
                                        ),
                                        if (item.record.reflectionText.trim().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(item.record.reflectionText, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.5, color: Color(0xFF374151))),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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

  Widget _heroCard() => _card(
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('复习中心', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              '这里集中查看你标记过的课程正文，以及最近完成的行动记录。让“看过”变成“回看过、做过、留下痕迹”。',
              style: TextStyle(height: 1.6, color: Color(0xFF4B5563)),
            ),
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

  Widget _chip(String label, String value) {
    final selected = _tab == value;
    return GestureDetector(
      onTap: () => _reload(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected ? null : const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF374151), fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ReviewBundle {
  final List<GoalReviewedSegment> segments;
  final List<GoalActionRecordView> actions;
  _ReviewBundle({required this.segments, required this.actions});
}
