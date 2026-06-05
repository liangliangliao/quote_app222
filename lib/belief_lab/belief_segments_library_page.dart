import 'package:flutter/material.dart';
import 'belief_dao.dart';
import 'belief_models.dart';
import 'belief_ui.dart';
import 'belief_segment_detail_page.dart';

class BeliefSegmentsLibraryPage extends StatefulWidget {
  const BeliefSegmentsLibraryPage({super.key});

  @override
  State<BeliefSegmentsLibraryPage> createState() => _BeliefSegmentsLibraryPageState();
}

class _BeliefSegmentsLibraryPageState extends State<BeliefSegmentsLibraryPage> {
  final _dao = BeliefDao();
  final _qCtrl = TextEditingController();
  String _q = '';
  String _tag = '全部';

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('资料库：57 段简化原文')),
      body: FutureBuilder<List<BeliefSegment>>(
        future: _dao.listSegments(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          final tags = <String>{};
          for (final s in all) {
            tags.addAll(s.tags);
          }
          final tagList = ['全部', ...tags.toList()..sort()];

          final filtered = all.where((s) {
            final q = _q.trim().toLowerCase();
            final okTag = (_tag == '全部') ? true : s.tags.contains(_tag);
            if (!okTag) return false;
            if (q.isEmpty) return true;
            return s.title.toLowerCase().contains(q) || s.body.toLowerCase().contains(q) || s.tags.any((t) => t.toLowerCase().contains(q));
          }).toList();

          // group by lecture
          final byLecture = <int, List<BeliefSegment>>{};
          for (final s in filtered) {
            byLecture.putIfAbsent(s.lecture, () => []).add(s);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _qCtrl,
                  decoration: InputDecoration(
                    hintText: '搜索段落（例：Stockdale / 认知失调 / priming）',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: tagList.length,
                  itemBuilder: (_, i) {
                    final t = tagList[i];
                    final selected = t == _tag;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(t),
                        selected: selected,
                        onSelected: (_) => setState(() => _tag = t),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: filtered.isEmpty
                    ? const BeliefEmptyState(title: '没有匹配内容', subtitle: '换个关键词或标签试试。')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                        children: [
                          for (final lecture in byLecture.keys.toList()..sort())
                            _LectureSection(
                              lecture: lecture,
                              segs: (byLecture[lecture]!..sort((a, b) => a.segNo.compareTo(b.segNo))),
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
}

class _LectureSection extends StatelessWidget {
  final int lecture;
  final List<BeliefSegment> segs;

  const _LectureSection({required this.lecture, required this.segs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text('Lecture $lecture', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        ...segs.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BeliefSegmentDetailPage(segmentKey: s.key)),
              ),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(s.key, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black45),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
