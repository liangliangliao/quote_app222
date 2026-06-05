import 'package:flutter/material.dart';
// NOTE: graphview exports its main API from `GraphView.dart` (capital G/V).
// Some build environments (Linux CI) are case-sensitive; importing the wrong
// entry file can lead to missing symbols like `GraphView`, `Node`, etc.
import 'package:graphview/GraphView.dart';

import '../data/dao.dart';

/// A lightweight mindmap-style visualization for selected thought taxonomy nodes.
///
/// What it shows:
/// - **Hierarchy** (ancestor/child relations) via a tree layout
/// - **Parallel/sibling relations** by adding siblings of selected nodes' parents
///
/// This is meant for read-only "回显" in history/stats pages.
class ThoughtTaxonomyMindMap extends StatefulWidget {
  final List<String> selectedUids;
  final double height;
  final bool compact;

  const ThoughtTaxonomyMindMap({
    super.key,
    required this.selectedUids,
    this.height = 160,
    this.compact = true,
  });

  @override
  State<ThoughtTaxonomyMindMap> createState() => _ThoughtTaxonomyMindMapState();
}

class _ThoughtTaxonomyMindMapState extends State<ThoughtTaxonomyMindMap> {
  late Future<_MindMapData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ThoughtTaxonomyMindMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedUids.join(',') != widget.selectedUids.join(',')) {
      _future = _load();
    }
  }

  String? _parentUidOf(String uid) {
    final i = uid.lastIndexOf('.');
    if (i <= 0) return null;
    return uid.substring(0, i);
  }

  Set<String> _ancestorsOf(String uid) {
    final out = <String>{};
    var cur = uid;
    while (cur.isNotEmpty) {
      out.add(cur);
      final p = _parentUidOf(cur);
      if (p == null) break;
      cur = p;
    }
    return out;
  }

  Future<_MindMapData> _load() async {
    final selected = widget.selectedUids.where((e) => e.trim().isNotEmpty).toSet();
    if (selected.isEmpty) {
      return const _MindMapData(nodesByUid: {}, edges: [], selected: {});
    }

    // Only include nodes explicitly selected (the selection UI auto-selects ancestors).
    // This keeps the mind-map strictly aligned with what the user picked and prevents
    // the graph from blowing up when multiple leaves are selected.
    final needed = selected;

    final rows = await VisionDao().listThoughtNodesByUids(needed);
    final nodesByUid = <String, _NodeInfo>{};
    for (final r in rows) {
      final uid = (r['uid'] ?? '').toString();
      if (uid.isEmpty) continue;
      nodesByUid[uid] = _NodeInfo(
        uid: uid,
        title: (r['title'] ?? uid).toString(),
        parentUid: (r['parent_uid'] ?? '').toString().trim().isEmpty ? null : (r['parent_uid'] ?? '').toString(),
        depth: (r['depth'] is int) ? r['depth'] as int : int.tryParse('${r['depth']}') ?? 0,
        order: (r['display_order'] is int) ? r['display_order'] as int : int.tryParse('${r['display_order']}') ?? 0,
      );
    }

    // Build edges for nodes that have their parent also included.
    final edges = <_EdgeInfo>[];
    for (final n in nodesByUid.values) {
      final p = n.parentUid;
      if (p != null && nodesByUid.containsKey(p)) {
        edges.add(_EdgeInfo(from: p, to: n.uid));
      }
    }

    // Ensure stable order for layout.
    edges.sort((a, b) {
      final da = nodesByUid[a.to]?.depth ?? 0;
      final db = nodesByUid[b.to]?.depth ?? 0;
      if (da != db) return da.compareTo(db);
      final oa = nodesByUid[a.to]?.order ?? 0;
      final ob = nodesByUid[b.to]?.order ?? 0;
      return oa.compareTo(ob);
    });

    return _MindMapData(nodesByUid: nodesByUid, edges: edges, selected: selected);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MindMapData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            height: widget.height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data;
        if (data == null || data.nodesByUid.isEmpty) {
          return const SizedBox.shrink();
        }

        // Defensive copies: avoid mutating Future-cached data across rebuilds.
        final nodesByUid = Map<String, _NodeInfo>.from(data.nodesByUid);
        final edges = List<_EdgeInfo>.from(data.edges);

        final graph = Graph()..isTree = true;
        final nodeMap = <String, Node>{};
        Node nodeOf(String uid) => nodeMap.putIfAbsent(uid, () => Node.Id(uid));

        // Pre-register nodes so even graphs without edges still render.
        for (final uid in nodesByUid.keys) {
          graph.addNode(nodeOf(uid));
        }

        // Multiple roots fallback: attach to a synthetic root.
        final roots = nodesByUid.values
            .where((n) => n.parentUid == null || !nodesByUid.containsKey(n.parentUid))
            .toList()
          ..sort((a, b) => a.depth.compareTo(b.depth));

        String rootUid;
        if (roots.length == 1) {
          rootUid = roots.first.uid;
        } else {
          rootUid = '__taxonomy_root__';
          nodesByUid[rootUid] = const _NodeInfo(uid: '__taxonomy_root__', title: '分类', parentUid: null, depth: 0, order: 0);
          graph.addNode(nodeOf(rootUid));
          for (final r in roots) {
            edges.add(_EdgeInfo(from: rootUid, to: r.uid));
          }
        }

        for (final e in edges) {
          if (!nodesByUid.containsKey(e.from) || !nodesByUid.containsKey(e.to)) continue;
          graph.addEdge(nodeOf(e.from), nodeOf(e.to));
        }
        // Ensure the root node exists in the graph.
        graph.addNode(nodeOf(rootUid));

        final cfg = BuchheimWalkerConfiguration()
          ..siblingSeparation = widget.compact ? 18 : 22
          ..levelSeparation = widget.compact ? 26 : 34
          ..subtreeSeparation = widget.compact ? 18 : 22
          ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT;

        Widget buildNode(Node node) {
          final k = node.key?.value;
          final uid = (k is String) ? k : (k?.toString() ?? '');
          final info = nodesByUid[uid];
          final title = info?.title ?? uid;
          final isSelected = data.selected.contains(uid);

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.compact ? 170 : 220),
            child: Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 10 : 12,
                  vertical: widget.compact ? 6 : 8,
                ),
                child: Text(
                  title,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: widget.compact ? 11.5 : 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }

        // Use a light background container to look like a "mindmap" preview.
        return SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
              ),
              child: InteractiveViewer(
                minScale: 0.2,
                maxScale: 2.0,
                boundaryMargin: const EdgeInsets.all(80),
                child: GraphView.builder(
                  graph: graph,
                  algorithm: BuchheimWalkerAlgorithm(cfg, TreeEdgeRenderer(cfg)),
                  // Keep this read-only and lightweight.
                  animated: false,
                  autoZoomToFit: false,
                  controller: GraphViewController(),
                  builder: (Node node) => buildNode(node),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NodeInfo {
  final String uid;
  final String title;
  final String? parentUid;
  final int depth;
  final int order;

  const _NodeInfo({
    required this.uid,
    required this.title,
    required this.parentUid,
    required this.depth,
    required this.order,
  });
}

class _EdgeInfo {
  final String from;
  final String to;
  const _EdgeInfo({required this.from, required this.to});
}

class _MindMapData {
  final Map<String, _NodeInfo> nodesByUid;
  final List<_EdgeInfo> edges;
  final Set<String> selected;
  const _MindMapData({required this.nodesByUid, required this.edges, required this.selected});
}
