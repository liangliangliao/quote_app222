import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/dao.dart';

class VisionHookHistoryPage extends StatefulWidget {
  const VisionHookHistoryPage({super.key});

  @override
  State<VisionHookHistoryPage> createState() => _VisionHookHistoryPageState();
}

class _VisionHookHistoryPageState extends State<VisionHookHistoryPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await VisionDao().listHooksAll();
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('未完成钩子历史'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            '还没有钩子记录。',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final row = _items[index];
                        final id = (row['id'] ?? '').toString();
                        final text = (row['text'] ?? '').toString();
                        final nextAction = (row['next_action'] ?? '').toString();
                      final goalTitle = (row['goal_title'] ?? '').toString();
                      final woopWish = (row['woop_wish'] ?? '').toString();
                      final taskTitle = (row['task_title'] ?? '').toString();
                        final resolved = (row['resolved'] ?? 0) != 0;

                        final ts = _fmtTs(row['created_ts']);
                        final style = resolved
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              )
                            : const TextStyle();

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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          text.isEmpty ? '（空）' : text,
                                          style: style,
                                        ),
                                      ),
                                      if (!resolved)
                                        TextButton(
                                          onPressed: () async {
                                            if (id.isEmpty) return;
                                            await VisionDao().resolveHook(id);
                                            await _load();
                                          },
                                          child: const Text('标记已接上'),
                                        ),
                                    ],
                                  ),
                                  if (nextAction.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '下一步：$nextAction',
                                      style: resolved
                                          ? const TextStyle(
                                              decoration: TextDecoration.lineThrough,
                                              color: Colors.grey,
                                              fontSize: 12,
                                            )
                                          : const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                  if (taskTitle.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '专注：$taskTitle',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                  if (goalTitle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '所属愿景：$goalTitle',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                  if (woopWish.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '具体愿景：$woopWish',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                  if (ts.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      ts,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                  if (resolved) ...[
                                    const SizedBox(height: 6),
                                    const Text(
                                      '状态：已接上',
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemCount: _items.length,
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.close),
      ),
    );
  }
}
