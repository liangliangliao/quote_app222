import 'package:flutter/material.dart';
import '../fp_dao.dart';
import '../fp_models.dart';
import 'fp_concept_detail_page.dart';
import 'fp_practice_runner_page.dart';

class FpSegmentPage extends StatefulWidget {
  final String segmentId;
  const FpSegmentPage({super.key, required this.segmentId});

  @override
  State<FpSegmentPage> createState() => _FpSegmentPageState();
}

class _FpSegmentPageState extends State<FpSegmentPage> {
  final _dao = FpDao();
  FpSegment? _seg;
  int _status = 0;
  bool _loading = true;
  String? _err;
  Map<String, FpConceptNode> _nodes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final seg = await _dao.getSegment(widget.segmentId);
      if (seg == null) throw Exception('段落不存在');
      final st = await _dao.getProgressStatus('seg:${seg.segmentId}');
      final ids = <String>{seg.primaryNode, ...seg.secondaryNodes};
      final nodes = <String, FpConceptNode>{};
      for (final id in ids) {
        final n = await _dao.getConceptNode(id);
        if (n != null) nodes[id] = n;
      }
      if (!mounted) return;
      setState(() {
        _seg = seg;
        _status = st;
        _nodes = nodes;
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  Future<void> _toggleLearned() async {
    final seg = _seg;
    if (seg == null) return;
    final next = _status >= 1 ? 0 : 1;
    await _dao.upsertProgress('seg:${seg.segmentId}', status: next, payload: {
      'episode': seg.episodeNo,
      'big_section': seg.bigSectionId,
    });
    if (!mounted) return;
    setState(() => _status = next);
  }

  @override
  Widget build(BuildContext context) {
    final seg = _seg;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.segmentId),
        actions: [
          IconButton(
            tooltip: _status >= 1 ? '取消已学' : '标记已学',
            onPressed: seg == null ? null : _toggleLearned,
            icon: Icon(_status >= 1 ? Icons.check_circle : Icons.circle_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text(_err!))
              : seg == null
                  ? const Center(child: Text('段落不存在'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        Text(seg.summaryZh, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        if (seg.excerptEn.trim().isNotEmpty) ...[
                          Text('原文摘录', style: TextStyle(color: Colors.black.withOpacity(0.7), fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(seg.excerptEn, style: TextStyle(color: Colors.black.withOpacity(0.8))),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text('关联概念', style: TextStyle(color: Colors.black.withOpacity(0.7), fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final id in [seg.primaryNode, ...seg.secondaryNodes])
                              _ConceptChip(
                                nodeId: id,
                                name: _nodes[id]?.name ?? id,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => FpConceptDetailPage(nodeId: id)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () async {
                            // default: run task for primary node
                            final taskId = 'TASK_${seg.primaryNode}';
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => FpPracticeRunnerPage(taskId: taskId, relatedSegmentId: seg.segmentId)),
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('做一个与本段一致的练习'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            // AAR is a good default
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FpPracticeRunnerPage(taskId: 'TASK_A01')),
                            );
                          },
                          icon: const Icon(Icons.edit_note_outlined),
                          label: const Text('失败复盘（AAR）'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '学习建议：先允许自己“不过度”，再把下一步变成“最小实验”。',
                          style: TextStyle(color: Colors.black.withOpacity(0.65)),
                        ),
                      ],
                    ),
    );
  }
}

class _ConceptChip extends StatelessWidget {
  final String nodeId;
  final String name;
  final VoidCallback onTap;
  const _ConceptChip({required this.nodeId, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Text('$nodeId · $name', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
