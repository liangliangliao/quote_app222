import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'belief_dao.dart';
import 'belief_models.dart';
import 'belief_levels.dart';
import 'belief_ui.dart';

class BeliefSegmentDetailPage extends StatelessWidget {
  final String segmentKey; // like L6#12
  const BeliefSegmentDetailPage({super.key, required this.segmentKey});

  @override
  Widget build(BuildContext context) {
    final dao = BeliefDao();
    return Scaffold(
      appBar: AppBar(
        title: Text(segmentKey),
        actions: [
          IconButton(
            tooltip: '复制正文',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              final s = await dao.getSegmentByKey(segmentKey);
              if (s == null) return;
              await Clipboard.setData(ClipboardData(text: '${s.title}\n\n${s.body}'));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<BeliefSegment?>(
        future: dao.getSegmentByKey(segmentKey),
        builder: (context, snap) {
          final s = snap.data;
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (s == null) return const BeliefEmptyState(title: '找不到段落', subtitle: '可能是数据未初始化或 key 不存在。');

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              Text(
                s.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(children: s.tags.map((t) => BeliefChip(t)).toList()),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final related = beliefConcepts.where((c) => c.segmentKeys.contains(segmentKey)).toList()
                    ..sort((a, b) => a.title.compareTo(b.title));
                  if (related.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('关联概念（概念地图）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(children: related.map((c) => BeliefChip(c.title)).toList()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                s.body,
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '建议用法：读完后写一句“我现在要做的最小行动是什么？”。然后去行动关卡里做一个任务。',
                  style: TextStyle(color: Colors.black.withOpacity(0.75)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
