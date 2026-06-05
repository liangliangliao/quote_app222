import 'package:flutter/material.dart';

import '../models/daily_diet_entry.dart';
import '../repositories/daily_diet_entry_repository.dart';
import '../widgets/health_diet_data_source_banner.dart';

class DailyDietHistoryPage extends StatefulWidget {
  const DailyDietHistoryPage({super.key});

  @override
  State<DailyDietHistoryPage> createState() => _DailyDietHistoryPageState();
}

class _DailyDietHistoryPageState extends State<DailyDietHistoryPage> {
  final _repo = DailyDietEntryRepository();
  bool _loading = true;
  List<DailyDietEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _repo.recentEntries(limit: 80);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _delete(DailyDietEntry entry) async {
    if (entry.id == null) return;
    await _repo.deleteEntry(entry.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<DailyDietEntry>>{};
    for (final entry in _entries) {
      grouped.putIfAbsent(entry.entryDate, () => []).add(entry);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('饮食记录历史')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  HealthDietDataSourceBanner(
                    sources: const ['本地饮食记录', '用户确认食物', '历史图片/语音索引'],
                    updatedAt: DateTime.now(),
                    note: '历史记录来自本地数据库；删除或修改后会影响长期趋势和 Agent 复盘。',
                  ),
                  if (_entries.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('还没有饮食记录。'),
                      ),
                    ),
                  ...grouped.entries.expand((group) => [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                          child: Text(group.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        ...group.value.map(_entryCard),
                      ]),
                ],
              ),
            ),
    );
  }

  Widget _entryCard(DailyDietEntry entry) {
    final foods = entry.foods.map((e) => e.foodName).join('、');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_inputIcon(entry.inputType), size: 20)),
        title: Text('${_mealLabel(entry.mealType)} · ${_inputLabel(entry.inputType)}'),
        subtitle: Text(foods.isEmpty ? (entry.textDescription ?? entry.voiceText ?? '图片/条码记录') : foods, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(entry)),
      ),
    );
  }

  String _mealLabel(String type) {
    switch (type) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snack':
        return '加餐';
      case 'drink':
        return '饮品';
      case 'mixed':
        return '多餐混合';
      default:
        return '未知餐次';
    }
  }

  String _inputLabel(String type) {
    switch (type) {
      case 'image':
        return '图片';
      case 'voice':
        return '语音';
      case 'barcode':
        return '条码';
      case 'mixed':
        return '混合';
      default:
        return '文字';
    }
  }

  IconData _inputIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.photo_camera_outlined;
      case 'voice':
        return Icons.mic_none;
      case 'barcode':
        return Icons.qr_code_scanner;
      case 'mixed':
        return Icons.dashboard_customize_outlined;
      default:
        return Icons.edit_note;
    }
  }
}
