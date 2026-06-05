import 'package:flutter/material.dart';

import '../data/dao.dart';

class VisionReflectionHistoryPage extends StatefulWidget {
  const VisionReflectionHistoryPage({super.key});

  @override
  State<VisionReflectionHistoryPage> createState() => _VisionReflectionHistoryPageState();
}

class _VisionReflectionHistoryPageState extends State<VisionReflectionHistoryPage> {
  final ScrollController _controller = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int _offset = 0;
  static const int _pageSize = 50;

  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _controller.addListener(() {
      if (!_hasMore || _loadingMore) return;
      if (_controller.position.pixels > _controller.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _offset = 0;
      _items = [];
      _hasMore = true;
    });
    await _loadMore();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final rows = await VisionDao().listReflectionsPaged(limit: _pageSize, offset: _offset);
      if (rows.isEmpty) {
        _hasMore = false;
      } else {
        _items.addAll(rows);
        _offset += rows.length;
        if (rows.length < _pageSize) _hasMore = false;
      }
    } catch (_) {
      // ignore
    }
    if (!mounted) return;
    setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('反思与边界历史'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView.builder(
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
                          child: Text('已经到底了'),
                        ),
                      );
                    }
                    return const SizedBox(height: 24);
                  }

                  final row = _items[index];
                  final presence = row['presence'] is int
                      ? (row['presence'] as int)
                      : int.tryParse((row['presence'] ?? '').toString()) ?? -1;
                  final mood = (row['mood'] ?? '').toString();
                  final note = (row['note'] ?? '').toString();
                  final goalTitle = (row['goal_title'] ?? '').toString();
                  final woopWish = (row['woop_wish'] ?? '').toString();
                  final taskTitle = (row['task_title'] ?? '').toString();
                  final ts = _fmtTs(row['created_ts']);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '存在感：${presence >= 0 ? presence.toString() : '?'} / 10'
                              '${mood.isNotEmpty ? ' · 情绪：$mood' : ''}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(note, style: const TextStyle(fontSize: 13)),
                            ],
                            const SizedBox(height: 8),
                            if (taskTitle.isNotEmpty)
                              Text('专注：$taskTitle', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (goalTitle.isNotEmpty)
                              Text('所属愿景：$goalTitle', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (woopWish.isNotEmpty)
                              Text('具体愿景：$woopWish', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (ts.isNotEmpty)
                              Text('日期：$ts', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
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
