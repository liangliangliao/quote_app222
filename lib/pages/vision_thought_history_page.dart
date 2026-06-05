import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/dao.dart';
import '../widgets/thought_taxonomy_mindmap.dart';

class VisionThoughtHistoryPage extends StatefulWidget {
  const VisionThoughtHistoryPage({super.key});

  @override
  State<VisionThoughtHistoryPage> createState() => _VisionThoughtHistoryPageState();
}

class _VisionThoughtHistoryPageState extends State<VisionThoughtHistoryPage> {
  final ScrollController _controller = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _items.clear();
      _hasMore = true;
    });
    final rows = await VisionDao().listThoughtsPaged(limit: 50, offset: 0);
    if (!mounted) return;
    setState(() {
      _items.addAll(rows);
      _loading = false;
      _hasMore = rows.length == 50;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    final rows = await VisionDao().listThoughtsPaged(limit: 50, offset: _items.length);
    if (!mounted) return;
    setState(() {
      _items.addAll(rows);
      _loadingMore = false;
      if (rows.length < 50) {
        _hasMore = false;
      }
    });
  }

  String _fmtTs(dynamic ts) {
    int v = 0;
    if (ts is int) {
      v = ts;
    } else {
      v = int.tryParse(ts.toString()) ?? 0;
    }
    if (v <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(v);
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  List<String> _parseCsvUids(dynamic v) {
    final s = (v ?? '').toString();
    if (s.trim().isEmpty) return const <String>[];
    return s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史念头')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFirst,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text('还没有念头记录。', style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _controller,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length + 1,
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          if (_loadingMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (!_hasMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text('已经到底了', style: TextStyle(color: Colors.grey)),
                              ),
                            );
                          }
                          return const SizedBox(height: 60);
                        }

                        final row = _items[index];
                        final thought = (row['thought'] ?? '').toString();
                        final taskTitle = (row['task_title'] ?? '').toString();
                        final goalTitle = (row['goal_title'] ?? '').toString();
                        final woopWish = (row['woop_wish'] ?? '').toString();
                        final nodeTitles = (row['node_titles'] ?? '').toString();
                        final nodeUids = _parseCsvUids(row['node_uids']);
                        final ts = _fmtTs(row['created_ts']);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Card(
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (_) => VisionThoughtDetailPage(row: row),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      thought.isEmpty ? '（空）' : thought,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                    if (nodeUids.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      const Text('分类（思维导图）', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 6),
                                      ThoughtTaxonomyMindMap(
                                        selectedUids: nodeUids,
                                        height: 140,
                                        compact: true,
                                      ),
                                    ] else if (nodeTitles.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text('分类：$nodeTitles', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                    const SizedBox(height: 10),
                                    Text(
                                      [
                                        if (taskTitle.isNotEmpty) '专注：$taskTitle',
                                        if (goalTitle.isNotEmpty) '愿景：$goalTitle',
                                        if (woopWish.isNotEmpty) '具体愿景：$woopWish',
                                        if (ts.isNotEmpty) '日期：$ts',
                                      ].join('   ·   '),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class VisionThoughtDetailPage extends StatelessWidget {
  final Map<String, dynamic> row;

  const VisionThoughtDetailPage({super.key, required this.row});

  String _fmtTs(dynamic ts) {
    int v = 0;
    if (ts is int) {
      v = ts;
    } else {
      v = int.tryParse(ts.toString()) ?? 0;
    }
    if (v <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(v);
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final thought = (row['thought'] ?? '').toString();
    final taskTitle = (row['task_title'] ?? '').toString();
    final goalTitle = (row['goal_title'] ?? '').toString();
    final woopWish = (row['woop_wish'] ?? '').toString();
    final nodeTitles = (row['node_titles'] ?? '').toString();
    final nodeUids = (row['node_uids'] ?? '').toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final ts = _fmtTs(row['created_ts']);

    return Scaffold(
      appBar: AppBar(title: const Text('念头详情')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('念头', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(thought.isEmpty ? '（空）' : thought, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 16),
                if (nodeUids.isNotEmpty) ...[
                  const Text('分类（思维导图）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ThoughtTaxonomyMindMap(selectedUids: nodeUids, height: 220, compact: false),
                  const SizedBox(height: 10),
                ] else if (nodeTitles.isNotEmpty)
                  Text('分类：$nodeTitles'),
                if (taskTitle.isNotEmpty) Text('专注事项：$taskTitle'),
                if (goalTitle.isNotEmpty) Text('愿景：$goalTitle'),
                if (woopWish.isNotEmpty) Text('具体愿景：$woopWish'),
                if (ts.isNotEmpty) Text('日期：$ts'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
