import 'dart:convert';

import 'package:flutter/material.dart';

import 'realistic_positivity_os_dao.dart';
import 'realistic_positivity_os_models.dart';

/// RPO V4 行动实验生命周期页。
///
/// 这是独立模块内的闭环层：行动卡不是结束，而是进入 7/14 天实验、每日 check-in、
/// ready_review、completed/recovered 等状态。它不接入其他既有模块。
class RealisticPositivityOsLifecyclePage extends StatefulWidget {
  const RealisticPositivityOsLifecyclePage({super.key});

  @override
  State<RealisticPositivityOsLifecyclePage> createState() => _RealisticPositivityOsLifecyclePageState();
}

class _RealisticPositivityOsLifecyclePageState extends State<RealisticPositivityOsLifecyclePage> {
  final RealisticPositivityOsDao _dao = RealisticPositivityOsDao();
  List<RpoPracticeRecord> _records = const <RpoPracticeRecord>[];
  List<Map<String, Object?>> _experiments = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _checkins = const <Map<String, Object?>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    final records = await _dao.listRecords(limit: 80);
    final experiments = await _dao.listExperiments(limit: 120);
    final checkins = await _dao.listCheckIns(limit: 200);
    if (!mounted) return;
    setState(() {
      _records = records;
      _experiments = experiments;
      _checkins = checkins;
      _loading = false;
    });
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _createFromRecord(RpoPracticeRecord item, int days) async {
    await _dao.createExperimentFromRecord(item, horizonDays: days, status: 'active');
    await _load();
    _toast('已创建 $days 天行动实验');
  }

  Future<void> _updateStatus(Map<String, Object?> item, String status) async {
    await _dao.updateExperiment(id: (item['id'] ?? '').toString(), status: status);
    await _load();
    _toast('实验状态已更新为 $status');
  }

  Future<void> _openCheckIn(Map<String, Object?> item) async {
    final actionCtrl = TextEditingController();
    final emotionCtrl = TextEditingController();
    final reflectionCtrl = TextEditingController();
    final nextCtrl = TextEditingController();
    String zone = 'stretch';
    final plan = _decodeMap(item['plan_json']);
    final micro = _decodeMap(plan['micro_action']);
    actionCtrl.text = (micro['title'] ?? item['title'] ?? '').toString();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('行动实验 Check-in'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(controller: actionCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '今天实际完成了什么？', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: emotionCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '行动前后情绪/身体有什么变化？', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: zone,
                    decoration: const InputDecoration(labelText: '今天处在哪个区？', border: OutlineInputBorder()),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'comfort', child: Text('Comfort Zone：太容易/没成长')),
                      DropdownMenuItem(value: 'stretch', child: Text('Stretch Zone：有点难但可承受')),
                      DropdownMenuItem(value: 'panic', child: Text('Panic Zone：过载/失控，需要降级')),
                    ],
                    onChanged: (v) => setDialogState(() => zone = v ?? 'stretch'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: reflectionCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '复盘：这个行动提供了什么新身份证据？', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: nextCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '下一次如何微调？', border: OutlineInputBorder())),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存 Check-in')),
            ],
          ),
        ),
      );
      if (ok == true) {
        await _dao.addCheckIn(
          experimentId: (item['id'] ?? '').toString(),
          completedAction: actionCtrl.text.trim(),
          emotionNote: emotionCtrl.text.trim(),
          zone: zone,
          reflection: reflectionCtrl.text.trim(),
          nextAdjustment: nextCtrl.text.trim(),
        );
        if (zone == 'panic') {
          await _dao.updateExperiment(id: (item['id'] ?? '').toString(), status: 'needs_support');
        }
        await _load();
        _toast('Check-in 已保存');
      }
    } finally {
      actionCtrl.dispose();
      emotionCtrl.dispose();
      reflectionCtrl.dispose();
      nextCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('RPO 行动实验生命周期', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: <Widget>[
          _section(
            title: '为什么需要生命周期？',
            subtitle: '终极产品方案要求“行动卡 → 现实小行动 → 复盘 → 新身份证据 → 周整合”。本页把一次 AI 输出升级为 7/14 天可追踪实验，避免停留在建议层。',
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              _Bullet('行动卡不是完成，而是实验的起点。'),
              _Bullet('每天记录行动、情绪、Comfort/Stretch/Panic 状态和下一步微调。'),
              _Bullet('Panic Zone 自动标记为 needs_support，避免把过载误当成长。'),
              _Bullet('到期后进入 ready_review，再决定 completed / recovered / paused。'),
            ]),
          ),
          const SizedBox(height: 12),
          _section(
            title: '从行动卡创建实验',
            subtitle: '选择最近生成的行动卡，把其中微行动、ABC、价值绑定和反思问题转成实验计划。',
            child: _records.isEmpty
                ? const Text('暂无行动卡。请先在 RPO 首页或深度工作台生成行动卡。')
                : Column(children: _records.take(12).map(_recordSeedTile).toList(growable: false)),
          ),
          const SizedBox(height: 12),
          _section(
            title: '进行中的实验',
            subtitle: '状态：planned / active / needs_support / ready_review / completed / paused / recovered。',
            child: _experiments.isEmpty
                ? const Text('暂无行动实验。')
                : Column(children: _experiments.map(_experimentTile).toList(growable: false)),
          ),
          const SizedBox(height: 12),
          _section(
            title: '最近 Check-in',
            subtitle: '用真实执行记录替代“我应该改变”的空想。',
            child: _checkins.isEmpty ? const Text('暂无 Check-in。') : Column(children: _checkins.take(20).map(_checkinTile).toList(growable: false)),
          ),
        ],
      ),
    );
  }

  Widget _recordSeedTile(RpoPracticeRecord item) {
    final title = item.microAction.title.trim().isEmpty ? item.title : item.microAction.title;
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${item.sceneType} · ${_limit(item.betterQuestion, 70)}'),
        isThreeLine: true,
        trailing: PopupMenuButton<int>(
          tooltip: '创建实验',
          itemBuilder: (_) => const <PopupMenuEntry<int>>[
            PopupMenuItem(value: 7, child: Text('创建 7 天实验')),
            PopupMenuItem(value: 14, child: Text('创建 14 天实验')),
          ],
          onSelected: (days) => _createFromRecord(item, days),
          child: const Icon(Icons.add_task_outlined),
        ),
      ),
    );
  }

  Widget _experimentTile(Map<String, Object?> item) {
    final status = (item['status'] ?? 'active').toString();
    final day = int.tryParse((item['day_index'] ?? '0').toString()) ?? 0;
    final horizon = int.tryParse((item['horizon_days'] ?? '7').toString()) ?? 7;
    final metrics = _decodeMap(item['metrics_json']);
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text((item['title'] ?? '行动实验').toString(), style: const TextStyle(fontWeight: FontWeight.w900))),
            Chip(label: Text(status), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 4),
          Text('${item['scene_type'] ?? ''} · 第 $day / $horizon 天 · 最近区间：${metrics['last_zone'] ?? '-'}', style: const TextStyle(color: Color(0xFF64748B))),
          if ((metrics['last_reflection'] ?? '').toString().trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text('最近复盘：${metrics['last_reflection']}'),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            ActionChip(label: const Text('今日 Check-in'), onPressed: () => _openCheckIn(item)),
            ActionChip(label: const Text('完成'), onPressed: () => _updateStatus(item, 'completed')),
            ActionChip(label: const Text('暂停'), onPressed: () => _updateStatus(item, 'paused')),
            ActionChip(label: const Text('恢复/重启'), onPressed: () => _updateStatus(item, 'recovered')),
          ]),
        ]),
      ),
    );
  }

  Widget _checkinTile(Map<String, Object?> item) {
    return ListTile(
      leading: const Icon(Icons.fact_check_outlined, color: Color(0xFF4F46E5)),
      title: Text((item['completed_action'] ?? '').toString().isEmpty ? 'Check-in' : (item['completed_action'] ?? '').toString()),
      subtitle: Text('${item['checkin_date'] ?? ''} · ${item['zone'] ?? ''}\n${item['reflection'] ?? ''}'),
      isThreeLine: true,
    );
  }

  Widget _section({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        if (subtitle.trim().isNotEmpty) ...<Widget>[const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.35))],
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Map<String, dynamic> _decodeMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  String _limit(String text, int max) {
    final t = text.trim().replaceAll('\n', ' ');
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('• ', style: TextStyle(fontWeight: FontWeight.w900)),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ]),
      );
}
