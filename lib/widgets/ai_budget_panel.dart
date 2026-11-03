import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_request_accounting.dart';
import '../services/ai_request_audit.dart';
import '../services/global_ai_request_settings.dart';

String aiHistoricalOutputPolicy(Map<String, dynamic> row) {
  final raw = row['budget'];
  final budget = raw is Map ? raw : const {};
  if (budget['policy'] == 'service_capacity') {
    final capacity = budget['provider_required_capacity'];
    return capacity == null ? '应用输出上限：未设置' : '应用输出上限：未设置 · 协议必填的模型容量 $capacity';
  }
  final historical = budget['effective'];
  return historical is num && historical > 0
      ? '历史请求的输出上限：$historical'
      : '历史请求的输出上限：未记录';
}

class AiBudgetPanel extends StatefulWidget {
  final String purpose;
  final int defaultBudget;
  const AiBudgetPanel(
      {super.key, required this.purpose, required this.defaultBudget});
  @override
  State<AiBudgetPanel> createState() => _AiBudgetPanelState();
}

class _AiBudgetPanelState extends State<AiBudgetPanel> {
  AiOutputBudget? budget;
  Map<String, dynamic>? latest;
  StreamSubscription<Map<String, dynamic>>? subscription;
  StreamSubscription<dynamic>? budgetSubscription, configSubscription;
  @override
  void initState() {
    super.initState();
    _load();
    budgetSubscription =
        AiRequestAudit.budgetChanges.stream.listen((_) => _load());
    configSubscription =
        GlobalAiRequestSettings.changes.stream.listen((_) => _load());
    subscription = AiRequestAudit.updates.stream.listen((row) {
      if (AiRequestAudit.budgetKey('${row['purpose']}') ==
              AiRequestAudit.budgetKey(widget.purpose) &&
          mounted) {
        setState(() => latest = row);
      }
    });
  }

  void _load() {
    final config = GlobalAiRequestSettings.cached;
    final value = config == null ? null : const AiOutputBudget.unlimited();
    final last = AiRequestAudit.recent
        .where((r) =>
            AiRequestAudit.budgetKey('${r['purpose']}') ==
            AiRequestAudit.budgetKey(widget.purpose))
        .firstOrNull;
    if (mounted)
      setState(() {
        budget = value;
        latest = last;
      });
  }

  @override
  void dispose() {
    subscription?.cancel();
    budgetSubscription?.cancel();
    configSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(budget?.label ?? '应用不设置输出 Token 上限',
              style: const TextStyle(fontSize: 11)),
          if (latest != null)
            Text(
                '最近请求：${AiTokenUsage.fromJson(latest!['usage'] as Map? ?? {}).label}'
                '${(latest!['finish_reason'] ?? '').toString().isEmpty ? '' : ' · 结束 ${latest!['finish_reason']}'}',
                style: const TextStyle(fontSize: 11)),
        ]),
      );
}

class AiUsagePage extends StatefulWidget {
  const AiUsagePage({super.key});
  @override
  State<AiUsagePage> createState() => _AiUsagePageState();
}

class _AiUsagePageState extends State<AiUsagePage> {
  late Future<List<Map<String, dynamic>>> rows = AiRequestAudit.history();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AI 实际用量'), actions: [
          IconButton(
              tooltip: '刷新用量',
              onPressed: () => setState(() => rows = AiRequestAudit.history()),
              icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              '应用不设置输出 Token 上限。以下只记录本机最近100次统一文字生成请求；供应商未返回的用量显示未知，不能据此视为免费。缓存与推理数量已包含在输入、输出中。'),
          FutureBuilder<List<Map<String, dynamic>>>(
              future: rows,
              builder: (context, snapshot) {
                final data = snapshot.data ?? [];
                final groups = <String, List<Map<String, dynamic>>>{};
                for (final row in data) {
                  groups
                      .putIfAbsent('${row['operation_id']}', () => [])
                      .add(row);
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (data.isEmpty) const Text('暂无已记录请求；浏览此页不会调用 AI。'),
                      for (final group in groups.values)
                        ExpansionTile(
                          title: Text(
                              '${group.first['purpose']} · ${group.length}次请求'),
                          subtitle: Text(_summary(group)),
                          children: [
                            if ('${group.first['purpose']}'
                                .startsWith('quote_knowledge.'))
                              const Text('分类批次保留请求次数控制；输出不设置应用额度。')
                            else
                              AiBudgetPanel(
                                  purpose: '${group.first['purpose']}',
                                  defaultBudget: group.first['budget'] is Map &&
                                          (group.first['budget'] as Map)['task']
                                              is int
                                      ? (group.first['budget'] as Map)['task']
                                          as int
                                      : 1800),
                            for (final row in group)
                              ListTile(
                                title: Text(
                                    '${row['provider']} / ${row['model']}'),
                                subtitle: Text(
                                    '${row['at']}\n${AiTokenUsage.fromJson(row['usage'] as Map? ?? {}).label}\n'
                                    '${aiHistoricalOutputPolicy(row)} · HTTP ${row['status'] ?? '未知'} · ${row['finish_reason'] ?? ''}'
                                    '${row['failure'] == null ? '' : ' · ${row['failure']}'}'),
                              )
                          ],
                        ),
                    ]);
              }),
        ]),
      );
  String _summary(List<Map<String, dynamic>> rows) {
    int? input, output;
    var missing = false;
    for (final row in rows) {
      final usage = AiTokenUsage.fromJson(row['usage'] as Map? ?? {});
      if (usage.input != null) input = (input ?? 0) + usage.input!;
      if (usage.output != null) output = (output ?? 0) + usage.output!;
      missing |= usage.input == null || usage.output == null;
    }
    return '累计已知输入 ${input ?? '未知'} · 输出 ${output ?? '未知'}${missing ? '；部分用量未知，累计不完整' : ''}';
  }
}
