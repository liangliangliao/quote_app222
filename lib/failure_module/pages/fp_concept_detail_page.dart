import 'package:flutter/material.dart';
import '../fp_dao.dart';
import '../fp_models.dart';
import 'fp_segment_page.dart';
import 'fp_practice_runner_page.dart';

class FpConceptDetailPage extends StatefulWidget {
  final String nodeId;
  const FpConceptDetailPage({super.key, required this.nodeId});

  @override
  State<FpConceptDetailPage> createState() => _FpConceptDetailPageState();
}

class _FpConceptDetailPageState extends State<FpConceptDetailPage> {
  final _dao = FpDao();
  bool _loading = true;
  String? _err;
  FpConceptNode? _node;
  List<FpSegment> _segments = const [];
  List<FpTask> _tasks = const [];
  List<FpConceptEdge> _edges = const [];
  Map<String, FpConceptNode> _nodeMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final n = await _dao.getConceptNode(widget.nodeId);
      if (n == null) throw Exception('概念不存在');
      final segs = await _dao.listSegmentsByConcept(widget.nodeId);
      final tasks = await _dao.listTasks(conceptId: widget.nodeId);
      final edges = await _dao.listConceptEdges();
      final related = edges.where((e) => e.fromNode == widget.nodeId || e.toNode == widget.nodeId).toList();
      final ids = <String>{widget.nodeId};
      for (final e in related) {
        ids.add(e.fromNode);
        ids.add(e.toNode);
      }
      final map = <String, FpConceptNode>{};
      for (final id in ids) {
        final cn = await _dao.getConceptNode(id);
        if (cn != null) map[id] = cn;
      }
      if (!mounted) return;
      setState(() {
        _node = n;
        _segments = segs;
        _tasks = tasks;
        _edges = related;
        _nodeMap = map;
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

  String _catName(String c) {
    switch (c) {
      case 'A':
        return '失败与学习';
      case 'B':
        return '完美主义机制';
      case 'C':
        return '心理安全与环境';
      case 'D':
        return '自尊与自我慈悲';
      case 'X':
        return '扩展工具';
      default:
        return c;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _node;
    return Scaffold(
      appBar: AppBar(title: Text(widget.nodeId)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text(_err!))
              : n == null
                  ? const Center(child: Text('概念不存在'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        Text('${n.nodeId} · ${n.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('分类：${_catName(n.category)}', style: TextStyle(color: Colors.black.withOpacity(0.65))),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(n.definition, style: TextStyle(color: Colors.black.withOpacity(0.85), height: 1.35)),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => FpPracticeRunnerPage(taskId: 'TASK_${n.nodeId}')),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('做一个与该概念一致的练习'),
                        ),
                        const SizedBox(height: 16),
                        if (_edges.isNotEmpty) ...[
                          Text('逻辑关系（与其它概念）', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withOpacity(0.75))),
                          const SizedBox(height: 8),
                          for (final e in _edges)
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Text('${e.fromNode} → ${e.toNode}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text(e.relation),
                                onTap: () {
                                  final other = e.fromNode == n.nodeId ? e.toNode : e.fromNode;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => FpConceptDetailPage(nodeId: other)),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                        Text('对应课程段落', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withOpacity(0.75))),
                        const SizedBox(height: 8),
                        if (_segments.isEmpty)
                          Text('暂无段落', style: TextStyle(color: Colors.black.withOpacity(0.6)))
                        else
                          for (final s in _segments)
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              child: ListTile(
                                title: Text(s.summaryZh, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${s.segmentId} · 第${s.episodeNo}集'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => FpSegmentPage(segmentId: s.segmentId)),
                                ),
                              ),
                            ),
                        const SizedBox(height: 16),
                        if (_tasks.isNotEmpty) ...[
                          Text('练习列表', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withOpacity(0.75))),
                          const SizedBox(height: 8),
                          for (final t in _tasks)
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.black.withOpacity(0.08)),
                              ),
                              child: ListTile(
                                title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text('难度${t.difficulty} · ${t.durationMin}分钟'),
                                trailing: const Icon(Icons.play_arrow),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => FpPracticeRunnerPage(taskId: t.taskId)),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
    );
  }
}
