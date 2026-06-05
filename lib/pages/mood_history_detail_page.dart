
import 'package:flutter/material.dart';
import '../data/emotions.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// 历史心事明细页面
class MoodHistoryDetailPage extends StatefulWidget {
  const MoodHistoryDetailPage({super.key});

  @override
  State<MoodHistoryDetailPage> createState() => _MoodHistoryDetailPageState();
}

class _MoodHistoryDetailPageState extends State<MoodHistoryDetailPage> {
  final _dao = EmotionDao();
  final ScrollController _scroll = ScrollController();

  // 过滤条件
  DateTime? _start;
  DateTime? _end;
  final TextEditingController _typeCtrl = TextEditingController();
  final TextEditingController _thoughtCtrl = TextEditingController(); // 信念
  final TextEditingController _eventCtrl = TextEditingController();
  final TextEditingController _behaviorCtrl = TextEditingController();

  // 数据
  final List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  bool _exhausted = false;
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    // 默认加载第一页
    _query(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 80) {
        if (!_loading && !_exhausted) {
          _query();
        }
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _typeCtrl.dispose();
    _thoughtCtrl.dispose();
    _eventCtrl.dispose();
    _behaviorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(1970,1,1),
      lastDate: DateTime(now.year+5),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start ?? now),
    );
    setState(() {
      _start = DateTime(date.year, date.month, date.day, time?.hour ?? 0, time?.minute ?? 0);
    });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _end ?? now,
      firstDate: DateTime(1970,1,1),
      lastDate: DateTime(now.year+5),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end ?? now),
    );
    setState(() {
      _end = DateTime(date.year, date.month, date.day, time?.hour ?? 23, time?.minute ?? 59);
    });
  }

  Future<void> _query({bool reset = false}) async {
    if (reset) {
      _rows.clear();
      _exhausted = false;
    }
    setState(() { _loading = true; });
    final page = await _dao.listHistory(
      start: _start,
      end: _end,
      typeLike: _typeCtrl.text,
      thoughtLike: _thoughtCtrl.text,
      eventLike: _eventCtrl.text,
      behaviorLike: _behaviorCtrl.text,
      limit: _pageSize,
      offset: _rows.length,
    );
    setState(() {
      _rows.addAll(page);
      _loading = false;
      if (page.length < _pageSize) _exhausted = true;
    });
  }

  String _fmt(String? s) => (s ?? '').toString();

  Future<void> _exportCsv() async {
    try {
      // 分页把所有符合当前筛选条件的数据拉出来
      const int pageSize = 1000;
      int offset = 0;
      final List<List<dynamic>> csvRows = [];
      // 表头
      csvRows.add(['emoji_name','emoji_char','type','inserted_at','trigger_event','thought','behavior']);

      while (true) {
        final page = await _dao.listHistory(
          start: _start,
          end: _end,
          typeLike: _typeCtrl.text,
          thoughtLike: _thoughtCtrl.text,
          eventLike: _eventCtrl.text,
          behaviorLike: _behaviorCtrl.text,
          limit: pageSize,
          offset: offset,
        );
        if (page.isEmpty) break;
        for (final r in page) {
          csvRows.add([
            (r['emoji_name'] ?? '').toString(),
            (r['emoji_char'] ?? '').toString(),
            (r['type'] ?? '').toString(),
            (r['inserted_at'] ?? '').toString(),
            (r['trigger_event'] ?? '').toString(),
            (r['thought'] ?? '').toString(),
            (r['behavior'] ?? '').toString(),
          ]);
        }
        if (page.length < pageSize) break;
        offset += page.length;
      }

      final converter = const ListToCsvConverter();
      final csv = converter.convert(csvRows);

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final fname = 'mood_history_%s-%s-%s_%s-%s.csv'
          .replaceFirst('%s', ts.year.toString())
          .replaceFirst('%s', two(ts.month))
          .replaceFirst('%s', two(ts.day))
          .replaceFirst('%s', two(ts.hour))
          .replaceFirst('%s', two(ts.minute));
      final file = File('\${dir.path}/' + fname);
      await file.writeAsString(csv);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV 已导出到：' + file.path)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：' + e.toString())),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史心事明细'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCsv,
            tooltip: '导出CSV',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _query(reset: true),
            tooltip: '查询',
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部筛选区域（中间）
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickStart,
                        child: Text(_start == null ? '起始时间' : _start.toString().substring(0,16)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickEnd,
                        child: Text(_end == null ? '结束时间' : _end.toString().substring(0,16)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _typeCtrl, decoration: const InputDecoration(labelText: '类型(模糊)'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _thoughtCtrl, decoration: const InputDecoration(labelText: '信念(模糊)'))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _eventCtrl, decoration: const InputDecoration(labelText: '事件(模糊)'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _behaviorCtrl, decoration: const InputDecoration(labelText: '行为(模糊)'))),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: _scroll,
              itemCount: _rows.length + (_loading && _rows.isEmpty ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (_rows.isEmpty && _loading) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (index >= _rows.length) return const SizedBox.shrink();
                final r = _rows[index];
                // 行展示：第一行 情绪(名称+表情)、类型、时间
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_fmt(r['emoji_name'])} ${_fmt(r['emoji_char'])}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Expanded(child: Text('类型：${_fmt(r['type'])}', style: const TextStyle(fontSize: 14))),
                          const SizedBox(width: 12),
                          Text(_fmt(r['inserted_at']), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('事件：${_fmt(r['trigger_event'])}', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('信念：${_fmt(r['thought'])}', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('行为：${_fmt(r['behavior'])}', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
