
import 'package:flutter/material.dart';
import '../data/db.dart';

class MoodTrendPage extends StatefulWidget {
  const MoodTrendPage({super.key});
  @override
  State<MoodTrendPage> createState() => _MoodTrendPageState();
}

class _MoodTrendPageState extends State<MoodTrendPage> {
  bool _loading = true;
  Map<String,int> _counts = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await AppDatabase.instance();
    final since = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    try {
      final rows = await db.query('emotions', where: 'inserted_at >= ?', whereArgs: [since]);
      final map = <String,int>{};
      for (final m in rows) {
        final key = ((m['emoji_char'] ?? '') as String) + ' ' + ((m['emoji_name'] ?? '') as String);
        map[key] = (map[key] ?? 0) + 1;
      }
      setState((){ _counts = map; _loading = false; });
    } catch (_) {
      setState((){ _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('心情趋势（近30天）')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _counts.isEmpty
        ? const Center(child: Text('暂无心情数据')) 
        : ListView(children: _counts.entries.map((e)=> ListTile(title: Text(e.key), trailing: Text('${e.value} 次'))).toList()),
    );
  }
}
