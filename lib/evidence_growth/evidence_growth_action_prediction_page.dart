import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'evidence_growth_action_prediction.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_journey_models.dart';

class EvidenceGrowthActionPredictionPage extends StatefulWidget {
  const EvidenceGrowthActionPredictionPage({
    super.key,
    required this.dao,
    this.journey,
  });

  final EvidenceGrowthDao dao;
  final GrowthJourney? journey;

  @override
  State<EvidenceGrowthActionPredictionPage> createState() =>
      _EvidenceGrowthActionPredictionPageState();
}

class _EvidenceGrowthActionPredictionPageState
    extends State<EvidenceGrowthActionPredictionPage> {
  static const _channel =
      MethodChannel('com.example.quote_app/mental_health_checkup');
  static const _teal = Color(0xff24766c);

  late final EvidenceGrowthActionPredictionService service;
  final plan = TextEditingController();
  final context = TextEditingController();
  final similarHistory = TextEditingController();

  DateTime? scheduledAt;
  GrowthData result = {};
  List<GrowthData> records = [];
  bool busy = false;
  bool jevConfigured = false;

  @override
  void initState() {
    super.initState();
    service = EvidenceGrowthActionPredictionService(dao: widget.dao);
    _prefill();
    unawaited(reload());
  }

  void _prefill() {
    final j = widget.journey;
    if (j == null) return;
    final actionApps = growthRows(j.data['knowledge_applications'])
        .where((a) => a['stage'] == 'ACTION' && a['state'] != 'WITHDRAWN')
        .toList();
    final next = growthMap(j.data['next_change']);
    final candidate = actionApps.isNotEmpty
        ? '${actionApps.last['application'] ?? ''}'
        : '${next['next_action'] ?? j.plan['strategy'] ?? ''}';
    plan.text = candidate.trim().isNotEmpty ? candidate : j.title;
    final facts = <String>[
      if ('${j.data['current'] ?? ''}'.trim().isNotEmpty)
        '当前事实：${j.data['current']}',
      if ('${j.data['belief'] ?? ''}'.trim().isNotEmpty)
        '当前判断：${j.data['belief']}',
      if ('${j.data['pending_entry'] ?? ''}'.trim().isNotEmpty)
        '最新补充：${j.data['pending_entry']}',
      if ('${j.plan['schedule'] ?? ''}'.trim().isNotEmpty)
        '已有时间安排：${j.plan['schedule']}',
      if ('${j.plan['resource_limit'] ?? ''}'.trim().isNotEmpty)
        '资源限制：${j.plan['resource_limit']}',
    ];
    context.text = facts.join('\n');
  }

  @override
  void dispose() {
    plan.dispose();
    context.dispose();
    similarHistory.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final history = await service.history();
    final enabled = await widget.dao.getSetting('jev_enabled') == 'true';
    if (!mounted) return;
    setState(() {
      records = history;
      jevConfigured = enabled;
    });
  }

  Future<String> _jevKey() async {
    if (!jevConfigured || !Platform.isAndroid) return '';
    final encrypted = await widget.dao.getSetting('jev_key_encrypted');
    if (encrypted.isEmpty) return '';
    try {
      return await _channel
              .invokeMethod<String>('decryptText', {'value': encrypted}) ??
          '';
    } catch (_) {
      return '';
    }
  }

  Future<void> configureJev() async {
    final controller = TextEditingController();
    final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('JEV 行动预测'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    '与知识匹配共用 TypeSafe JEV 配置。预测时发送当前行动、现实情境、AI 结构化提取和有限的个人结果摘要；密钥仍在 Android Keystore 加密保存。'),
                TextField(
                    controller: controller,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'TypeSafe API Key'))
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('停用并清除')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('保存'))
              ],
            ));
    final key = controller.text.trim();
    controller.dispose();
    if (save == null) return;
    if (!save) {
      await widget.dao.setSetting('jev_key_encrypted', '');
      await widget.dao.setSetting('jev_enabled', 'false');
      await reload();
      return;
    }
    if (key.isEmpty) {
      if (mounted) _message('请输入 TypeSafe API Key');
      return;
    }
    if (!Platform.isAndroid) {
      if (mounted) _message('当前平台不支持 Android Keystore，未保存密钥');
      return;
    }
    final encrypted =
        await _channel.invokeMethod<String>('encryptText', {'value': key});
    if (encrypted == null || !encrypted.startsWith('keystore-v1:')) {
      if (mounted) _message('密钥未安全保存');
      return;
    }
    await widget.dao.setSetting('jev_key_encrypted', encrypted);
    await widget.dao.setSetting('jev_enabled', 'true');
    await reload();
  }

  Future<void> chooseTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 365)),
        initialDate: scheduledAt ?? now);
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            scheduledAt ?? now.add(const Duration(hours: 1))));
    if (time == null) return;
    setState(() {
      scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> predict() async {
    if (busy || plan.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final output = await service.predict(
        plan: plan.text,
        scheduledAt: scheduledAt,
        context: context.text,
        similarHistory: similarHistory.text,
        journey: widget.journey,
        jevApiKey: await _jevKey(),
      );
      await service.savePrediction(output);
      if (!mounted) return;
      setState(() => result = output);
      await reload();
    } catch (e) {
      if (mounted) _message('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> recordOutcome(String id, String outcome) async {
    try {
      await service.recordOutcome(id, outcome);
      await reload();
      if (result['id'] == id) {
        final latest = records.where((r) => r['id'] == id).firstOrNull;
        if (latest != null && mounted) setState(() => result = latest);
      }
    } catch (e) {
      if (mounted) _message('$e');
    }
  }

  Future<void> clearHistory() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('清空行动预测历史？'),
              content: const Text('这会删除本机保存的预测与结果，个人基线也会重新开始。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('清空'))
              ],
            ));
    if (yes != true) return;
    await service.clearHistory();
    if (mounted) setState(() => result = {});
    await reload();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _pct(Object? value) =>
      value is num ? '${(value.toDouble() * 100).round()}%' : '—';

  String _time(int ms) {
    if (ms <= 0) return '未指定';
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _outcome(String value) => const {
        'PENDING': '等待现实结果',
        'ON_TIME': '按时开始',
        'LATE': '完成但延期',
        'NOT_DONE': '未执行',
      }[value] ??
      value;

  Widget _section(String title, Widget child) => Card(
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            child
          ])));

  Widget _result() {
    if (result.isEmpty) return const SizedBox.shrink();
    final available = result['estimate_available'] == true;
    final estimate = result['estimate'] as num?;
    final ai = growthMap(result['ai']);
    final jev = growthMap(result['jev']);
    final baseline = growthMap(result['history_baseline']);
    final factors = growthMap(result['factors']).entries.toList()
      ..sort((a, b) {
        final av = growthMap(a.value)['score'] as num?;
        final bv = growthMap(b.value)['score'] as num?;
        return (av ?? 2).compareTo(bv ?? 2);
      });

    return Column(children: [
      _section(
          '本次预测',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (available) ...[
              Text(_pct(estimate),
                  style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: _teal)),
              Text('${result['band']}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: estimate!.toDouble()),
            ] else
              const Text('当前没有足够的 AI、JEV 或个人历史数据形成综合估计。'),
            const SizedBox(height: 12),
            Text('AI：${_pct(ai['execution_likelihood'])} · ${ai['status'] ?? '—'}'),
            Text('JEV：${_pct(jev['overall'])} · ${jev['status'] ?? '—'}'),
            Text(
                '个人基线：${_pct(baseline['rate'])} · 已记录 ${baseline['resolved_count'] ?? 0} 次现实结果'),
            if (result['agreement'] == 'MODEL_DISAGREEMENT')
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('AI 与 JEV 的估计差异较大：不要急着相信单一数字，优先补充缺失信息。',
                      style: TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(height: 10),
            Text('${result['calibration_note']}',
                style: const TextStyle(color: Colors.black54)),
          ])),
      _section(
          '九个预测因素',
          Column(children: [
            for (final entry in factors)
              Builder(builder: (_) {
                final row = growthMap(entry.value);
                return ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('${row['label'] ?? entry.key}'),
                    subtitle: Text(
                        '综合 ${_pct(row['score'])} · AI ${_pct(row['ai'])} · JEV ${_pct(row['jev'])}'),
                    children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Text('${row['evidence'] ?? '暂无明确事实依据'}'))
                    ]);
              })
          ])),
      if (growthRows(result['top_risks']).isNotEmpty)
        _section(
            '最可能拉住行动的地方',
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: growthRows(result['top_risks'])
                    .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                            '• ${r['label']} · ${_pct(r['score'])}\n  ${r['evidence'] ?? ''}')))
                    .toList())),
      if (growthStrings(result['failure_modes']).isNotEmpty)
        _section(
            '可能的失败路径',
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: growthStrings(result['failure_modes'])
                    .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $s')))
                    .toList())),
      if (growthStrings(result['protective_actions']).isNotEmpty)
        _section(
            '优先修改这些行动条件',
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: growthStrings(result['protective_actions'])
                    .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $s')))
                    .toList())),
      if (growthStrings(result['missing_information']).isNotEmpty)
        _section(
            '补充这些信息会让下一次预测更可靠',
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: growthStrings(result['missing_information'])
                    .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $s')))
                    .toList())),
      _section(
          '现实结果',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('当前：${_outcome('${result['outcome'] ?? 'PENDING'}')}'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                  onPressed: () => recordOutcome(result['id'], 'ON_TIME'),
                  child: const Text('按时开始')),
              OutlinedButton(
                  onPressed: () => recordOutcome(result['id'], 'LATE'),
                  child: const Text('完成但延期')),
              OutlinedButton(
                  onPressed: () => recordOutcome(result['id'], 'NOT_DONE'),
                  child: const Text('未执行')),
            ])
          ])),
    ]);
  }

  Widget _history() => ExpansionTile(
      title: Text('预测历史（${records.length}）'),
      subtitle: const Text('真实结果会逐渐形成你的个人执行基线'),
      children: [
        if (records.isNotEmpty)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: clearHistory, child: const Text('清空历史'))),
        for (final row in records.take(20))
          ListTile(
              title: Text('${row['plan']}',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${_pct(row['estimate'])} · ${_outcome('${row['outcome'] ?? 'PENDING'}')} · ${_time((row['scheduled_at_ms'] as num?)?.toInt() ?? 0)}'),
              onTap: () => setState(() => result = row)),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('行动发生可能性预测'), actions: [
          IconButton(
              tooltip: jevConfigured ? 'JEV 已配置' : '配置 JEV',
              onPressed: busy ? null : configureJev,
              icon: Icon(
                  jevConfigured ? Icons.hub : Icons.hub_outlined))
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _section(
              'AI + JEV 行动预测器',
              const Text(
                  '预测“这一步会不会如期发生”，而不是判断目标好不好。AI 负责理解情境和提取九个因素，JEV 用 typed questions 独立判断，真实结果再形成个人基线。数字在充分校准前只是模型估计，不是保证。')),
          _section(
              '1. 描述下一步',
              Column(children: [
                TextField(
                    controller: plan,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        labelText: '具体准备做什么？',
                        hintText: '例如：明天 8:00 出门去公司体检',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('计划开始时间'),
                    subtitle: Text(scheduledAt == null
                        ? '未指定'
                        : _time(scheduledAt!.millisecondsSinceEpoch)),
                    trailing: TextButton(
                        onPressed: chooseTime, child: const Text('选择'))),
                TextField(
                    controller: context,
                    minLines: 4,
                    maxLines: 9,
                    decoration: const InputDecoration(
                        labelText: '现在的现实情况、情绪、阻力、替代选择、承诺',
                        hintText:
                            '不用自己给因素打分，直接把真实情况告诉 AI。',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: similarHistory,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                        labelText: '过去相似计划通常怎样？（可选）',
                        hintText: '例如：以前临近出发时常会重新犹豫，然后取消。',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: busy || plan.text.trim().isEmpty
                              ? null
                              : predict,
                          icon: const Icon(Icons.psychology_alt_outlined),
                          label: Text(busy ? '正在联合判断…' : '开始预测'))),
                  const SizedBox(width: 8),
                  OutlinedButton(
                      onPressed: busy ? null : configureJev,
                      child: Text(jevConfigured ? 'JEV已配置' : '配置JEV'))
                ]),
                if (busy)
                  const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator())
              ])),
          _result(),
          _history(),
          const SizedBox(height: 30),
        ]));
  }
}
