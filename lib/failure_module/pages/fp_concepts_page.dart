import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../fp_dao.dart';
import '../fp_models.dart';
import 'fp_concept_detail_page.dart';

class FpConceptsPage extends StatefulWidget {
  const FpConceptsPage({super.key});

  @override
  State<FpConceptsPage> createState() => _FpConceptsPageState();
}

class _FpConceptsPageState extends State<FpConceptsPage> {
  final _dao = FpDao();
  bool _loading = true;
  String? _err;
  List<FpConceptNode> _nodes = const [];
  List<FpConceptEdge> _edges = const [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ns = await _dao.listConceptNodes();
      final es = await _dao.listConceptEdges();
      if (!mounted) return;
      setState(() {
        _nodes = ns;
        _edges = es;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err != null) return Center(child: Text(_err!));

    final filtered = _q.trim().isEmpty
        ? _nodes
        : _nodes
            .where((n) => n.nodeId.toLowerCase().contains(_q.toLowerCase()) || n.name.toLowerCase().contains(_q.toLowerCase()))
            .toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索概念（如 A01 失败=学习 / 完美主义 / 粗稿）',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: '列表'),
              Tab(text: '逻辑图'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ConceptList(nodes: filtered),
                _ConceptGraph(nodes: _nodes, edges: _edges),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptList extends StatelessWidget {
  final List<FpConceptNode> nodes;
  const _ConceptList({required this.nodes});

  String _catName(String c) {
    switch (c) {
      case 'A':
        return 'A 失败与学习';
      case 'B':
        return 'B 完美主义机制';
      case 'C':
        return 'C 心理安全与环境';
      case 'D':
        return 'D 自尊与自我慈悲';
      case 'X':
        return '扩展工具';
      default:
        return c;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<FpConceptNode>>{};
    for (final n in nodes) {
      groups.putIfAbsent(n.category, () => []).add(n);
    }
    final keys = groups.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        for (final k in keys) ...[
          Text(_catName(k), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final n in groups[k]!)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.black.withOpacity(0.08)),
              ),
              child: ListTile(
                title: Text('${n.nodeId} · ${n.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(n.definition, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FpConceptDetailPage(nodeId: n.nodeId)),
                ),
              ),
            ),
          const SizedBox(height: 14),
        ]
      ],
    );
  }
}

class _ConceptGraph extends StatefulWidget {
  final List<FpConceptNode> nodes;
  final List<FpConceptEdge> edges;
  const _ConceptGraph({required this.nodes, required this.edges});

  @override
  State<_ConceptGraph> createState() => _ConceptGraphState();
}

class _ConceptGraphState extends State<_ConceptGraph> {
  final Graph _graph = Graph();
  final SugiyamaConfiguration _builder = SugiyamaConfiguration();
  late final Map<String, Node> _nodeWidgets;

  @override
  void initState() {
    super.initState();
    _builder
      ..nodeSeparation = 30
      ..levelSeparation = 36
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;
    _nodeWidgets = {for (final n in widget.nodes) n.nodeId: Node.Id(n.nodeId)};
    for (final n in widget.nodes) {
      _graph.addNode(_nodeWidgets[n.nodeId]!);
    }
    for (final e in widget.edges) {
      final a = _nodeWidgets[e.fromNode];
      final b = _nodeWidgets[e.toNode];
      if (a != null && b != null) {
        _graph.addEdge(a, b);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodeMap = {for (final n in widget.nodes) n.nodeId: n};
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(80),
      minScale: 0.2,
      maxScale: 3.0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GraphView(
          graph: _graph,
          algorithm: SugiyamaAlgorithm(_builder),
          paint: Paint()
            ..color = Colors.black.withOpacity(0.25)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            String id = '';
            final k = node.key;
            if (k is ValueKey) {
              id = k.value.toString();
            } else if (k != null) {
              id = k.toString();
            }
            final cn = nodeMap[id];
            return _GraphNode(
              id: id,
              name: cn?.name ?? id,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FpConceptDetailPage(nodeId: id)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GraphNode extends StatelessWidget {
  final String id;
  final String name;
  final VoidCallback onTap;
  const _GraphNode({required this.id, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(id, style: TextStyle(color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 2),
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
