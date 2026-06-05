import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_concept_detail_page.dart';
import 'goal_dao.dart';
import 'goal_models.dart';

class GoalConceptsPage extends StatefulWidget {
  const GoalConceptsPage({super.key});

  @override
  State<GoalConceptsPage> createState() => _GoalConceptsPageState();
}

class _GoalConceptsPageState extends State<GoalConceptsPage> {
  final _dao = GoalDao();
  String _course = 'ALL';
  late Future<List<GoalConceptCard>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<GoalConceptCard>> _load() {
    return _dao.listConceptCards(sourceCourse: _course == 'ALL' ? null : _course);
  }

  void _reload(String next) {
    setState(() {
      _course = next;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('概念实践馆')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('全部概念', 'ALL'),
                const SizedBox(width: 8),
                _filterChip('PP12 概念', 'PP12'),
                const SizedBox(width: 8),
                _filterChip('第13集概念', 'ST13'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<GoalConceptCard>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Center(child: Text(snap.error?.toString() ?? '加载失败'));
                }
                final items = snap.data!;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _HeroCard(course: _course, count: items.length);
                    }
                    final c = items[index - 1];
                    return _ConceptTile(
                      item: c,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => GoalConceptDetailPage(conceptId: c.conceptId)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _course == value;
    return GestureDetector(
      onTap: () => _reload(value),
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

class _HeroCard extends StatelessWidget {
  final String course;
  final int count;
  const _HeroCard({required this.course, required this.count});

  @override
  Widget build(BuildContext context) {
    String subtitle = '这里把 36 段课程正文各自外挂成“概念实践卡”，并加入误区辨析、小测问答、多级行动任务和反思统计。';
    if (course == 'PP12') subtitle = '正在查看 PP12 后半段对应的概念实践卡。';
    if (course == 'ST13') subtitle = '正在查看第13集目标主题对应的概念实践卡。';
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
          const Text('从原文到实践', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(height: 1.6, color: Color(0xFF4B5563))),
          const SizedBox(height: 12),
          Text('当前条目：$count 张概念卡', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ConceptTile extends StatelessWidget {
  final GoalConceptCard item;
  final VoidCallback onTap;
  const _ConceptTile({required this.item, required this.onTap});

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
                child: const Icon(Icons.lightbulb_outline, color: Color(0xFF111827)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.conceptTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      item.oneLineDefinition,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.45),
                    ),
                    const SizedBox(height: 8),
                    Text(item.interactionType, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w700)),
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
