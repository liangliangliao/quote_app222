import 'package:flutter/material.dart';

import '../data/dao.dart';

class ThoughtRecordResult {
  final String thought;
  final List<String> selectedNodeUids;

  const ThoughtRecordResult({required this.thought, required this.selectedNodeUids});
}

/// Dialog used by "记录弹出的念头".
///
/// Features:
/// - Thought quick note input
/// - Lazy-loaded concept tree
/// - Multi-select any node
class ThoughtRecordDialog extends StatefulWidget {
  final String? initialText;
  final List<String>? initialSelected;

  const ThoughtRecordDialog({
    super.key,
    this.initialText,
    this.initialSelected,
  });

  @override
  State<ThoughtRecordDialog> createState() => _ThoughtRecordDialogState();
}

class _ThoughtRecordDialogState extends State<ThoughtRecordDialog> {
  final _ctrl = TextEditingController();
  final _selected = <String>{};

  bool _loadingRoot = true;
  final _expanded = <String>{};
  final Map<String?, List<Map<String, dynamic>>> _childrenCache = {};
  final Map<String, bool> _loadingChildren = {};

  @override
  void initState() {
    super.initState();
    _ctrl.text = (widget.initialText ?? '').trim();
    _selected.addAll((widget.initialSelected ?? const <String>[]).where((e) => e.trim().isNotEmpty));
    _loadRoot();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoot() async {
    setState(() => _loadingRoot = true);
    try {
      final rows = await VisionDao().listThoughtRootNodes();
      if (!mounted) return;
      setState(() {
        _childrenCache[null] = rows;
        _loadingRoot = false;
      });

      // UX: if there is only one root (common case), expand it automatically.
      if (rows.length == 1) {
        final root = rows.first;
        if (_hasChildren(root)) {
          // ignore: unawaited_futures
          _toggleExpand(root);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRoot = false);
    }
  }

  Future<void> _toggleExpand(Map<String, dynamic> node) async {
    final uid = (node['uid'] ?? '').toString();
    if (uid.isEmpty) return;
    if (_expanded.contains(uid)) {
      setState(() => _expanded.remove(uid));
      return;
    }

    setState(() => _expanded.add(uid));
    if (_childrenCache.containsKey(uid)) return;
    if (_loadingChildren[uid] == true) return;

    _loadingChildren[uid] = true;
    try {
      final rows = await VisionDao().listThoughtChildNodes(uid);
      if (!mounted) return;
      setState(() {
        _childrenCache[uid] = rows;
      });
    } finally {
      _loadingChildren[uid] = false;
      if (mounted) setState(() {});
    }
  }

  List<Map<String, dynamic>> _flatten() {
    final out = <Map<String, dynamic>>[];
    void walk(List<Map<String, dynamic>> nodes) {
      for (final n in nodes) {
        out.add(n);
        final uid = (n['uid'] ?? '').toString();
        if (uid.isEmpty) continue;
        if (_expanded.contains(uid)) {
          final children = _childrenCache[uid] ?? const <Map<String, dynamic>>[];
          if (children.isNotEmpty) {
            walk(children);
          }
        }
      }
    }

    final roots = _childrenCache[null] ?? const <Map<String, dynamic>>[];
    walk(roots);
    return out;
  }

  int _depthOf(Map<String, dynamic> node) {
    final d = node['depth'];
    if (d is int) return d;
    return int.tryParse(d?.toString() ?? '') ?? 0;
  }

  bool _hasChildren(Map<String, dynamic> node) {
    final v = node['has_children'];
    if (v is int) return v == 1;
    return (v?.toString() ?? '0') == '1';
  }

  String? _parentUidOf(String uid) {
    final i = uid.lastIndexOf('.');
    if (i <= 0) return null;
    return uid.substring(0, i);
  }

  void _selectWithAncestors(String uid) {
    var cur = uid;
    while (cur.isNotEmpty) {
      _selected.add(cur);
      final p = _parentUidOf(cur);
      if (p == null) break;
      cur = p;
    }
  }

  void _toggleSelect(Map<String, dynamic> node) {
    final uid = (node['uid'] ?? '').toString();
    if (uid.isEmpty) return;

    final isLeaf = !_hasChildren(node);
    setState(() {
      if (_selected.contains(uid)) {
        _selected.remove(uid);
      } else {
        if (isLeaf) {
          // 需求：选择叶子节点时，自动选中所有上级节点。
          _selectWithAncestors(uid);
        } else {
          _selected.add(uid);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _flatten();

    // 全屏弹框：需求 1
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('刚刚想到什么？'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final text = _ctrl.text.trim();
                  Navigator.of(context).pop(
                    ThoughtRecordResult(
                      thought: text,
                      selectedNodeUids: _selected.toList()..sort(),
                    ),
                  );
                },
                child: const Text('保存'),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _ctrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: '简单记一下，专注结束后再处理。',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('念头分类（可多选）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_selected.isNotEmpty)
                      Text('已选 ${_selected.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loadingRoot
                      ? const Center(child: CircularProgressIndicator())
                      : Scrollbar(
                          child: ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final n = items[index];
                              final uid = (n['uid'] ?? '').toString();
                              final title = (n['title'] ?? '').toString();
                              final depth = _depthOf(n);
                              final hasChildren = _hasChildren(n);
                              final expanded = _expanded.contains(uid);
                              final loading = _loadingChildren[uid] == true;
                              final checked = _selected.contains(uid);

                              return InkWell(
                                onTap: uid.isEmpty ? null : () => _toggleSelect(n),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(width: 10.0 * depth),
                                      SizedBox(
                                        width: 28,
                                        child: hasChildren
                                            ? IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                iconSize: 18,
                                                icon: loading
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : Icon(expanded ? Icons.expand_more : Icons.chevron_right),
                                                onPressed: () => _toggleExpand(n),
                                              )
                                            : const SizedBox(),
                                      ),
                                      Checkbox(
                                        value: checked,
                                        onChanged: uid.isEmpty ? null : (_) => _toggleSelect(n),
                                      ),
                                      Expanded(
                                        child: Text(
                                          title.isEmpty ? uid : title,
                                          // 需求 1：节点文字不能截断
                                          softWrap: true,
                                          overflow: TextOverflow.visible,
                                          style: TextStyle(
                                            fontSize: depth <= 2 ? 13.5 : 13,
                                            fontWeight: depth <= 2 ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
