import 'package:flutter/material.dart';

import '../models/diet_habit_models.dart';
import '../repositories/diet_habit_repository.dart';
import '../services/diet_long_term_report_service.dart';
import '../widgets/health_diet_data_source_banner.dart';

class DietMicroActionPage extends StatefulWidget {
  const DietMicroActionPage({super.key});

  @override
  State<DietMicroActionPage> createState() => _DietMicroActionPageState();
}

class _DietMicroActionPageState extends State<DietMicroActionPage> {
  final _repo = DietHabitRepository();
  final _reportService = DietLongTermReportService();
  bool _loading = true;
  List<DietMicroAction> _actions = const [];
  DietMicroAction? _suggested;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await _reportService.buildReport(days: 7);
    final actions = await _repo.microActions();
    if (!mounted) return;
    setState(() {
      _suggested = report.priorityAction;
      _actions = actions;
      _loading = false;
    });
  }

  Future<void> _toggle(DietMicroAction action) async {
    if (action.id == null) return;
    if (action.status == 'completed') {
      await _repo.reactivateMicroAction(action.id!);
    } else {
      await _repo.completeMicroAction(action.id!);
    }
    await _load();
  }

  Future<void> _delete(DietMicroAction action) async {
    if (action.id == null) return;
    await _repo.deleteMicroAction(action.id!);
    await _load();
  }

  Future<void> _addCustomAction() async {
    final titleController = TextEditingController();
    final reasonController = TextEditingController(text: '这是我自己选择的下一步小改变。');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增微行动'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '今天只改这一点')),
            TextField(controller: reasonController, decoration: const InputDecoration(labelText: '为什么选择它'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && titleController.text.trim().isNotEmpty) {
      await _repo.createMicroAction(actionTitle: titleController.text.trim(), actionReason: reasonController.text.trim().isEmpty ? '这是一个更容易坚持的小改变。' : reasonController.text.trim());
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('饮食微行动')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addCustomAction, icon: const Icon(Icons.add), label: const Text('新增')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  HealthDietDataSourceBanner(
                    sources: const ['长期饮食模式', '今日健康目标', '本地微行动库'],
                    updatedAt: DateTime.now(),
                    note: '微行动依据最近饮食趋势生成；完成状态会回写本地并影响后续 Agent 安排。',
                  ),
                  _introCard(),
                  if (_suggested != null) ...[
                    const SizedBox(height: 14),
                    _suggestedCard(_suggested!),
                  ],
                  const SizedBox(height: 16),
                  const Text('微行动记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_actions.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('还没有微行动。系统会根据最近 7 天饮食模式自动生成一个最小改变，也可以手动新增。')))
                  else
                    ..._actions.map(_actionCard),
                ],
              ),
            ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFFFFFBEB), Color(0xFFF0FDF4)]),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.flag_outlined, color: Color(0xFF059669)), SizedBox(width: 8), Text('每天只改一个点', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          SizedBox(height: 8),
          Text('微行动不是让你突然变得完美，而是从最容易执行的一点开始，把饮食习惯一点点拉回更健康的方向。', style: TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  Widget _suggestedCard(DietMicroAction action) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('系统建议的优先微行动', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(action.actionTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(action.actionReason, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }

  Widget _actionCard(DietMicroAction action) {
    final done = action.status == 'completed';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: Checkbox(value: done, onChanged: (_) => _toggle(action)),
        title: Text(action.actionTitle, style: TextStyle(fontWeight: FontWeight.bold, decoration: done ? TextDecoration.lineThrough : null)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${action.actionDate} · ${action.actionReason}', style: const TextStyle(height: 1.35)),
        ),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(action)),
      ),
    );
  }
}
