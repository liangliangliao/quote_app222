import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_request_accounting.dart';
import '../services/ai_request_audit.dart';
import '../services/global_ai_request_settings.dart';

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
    final value = config == null
        ? null
        : AiOutputBudget.resolve(
            AiRequestAudit
                    .taskOverrides[AiRequestAudit.budgetKey(widget.purpose)] ??
                widget.defaultBudget,
            global: config.maxOutputTokens);
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

  Future<void> _edit() async {
    var draft = '${budget?.task ?? widget.defaultBudget}';
    final value = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('本任务输出额度'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    '这是单次输出上限，可能包含推理与正文；不会预先扣除这些 Token。最终仍受全局上限和服务端模型限制。'),
                TextFormField(
                    initialValue: draft,
                    onChanged: (value) => draft = value,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '正整数')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () {
                      final parsed = int.tryParse(draft.trim());
                      if (parsed != null && parsed > 0)
                        Navigator.pop(context, parsed);
                    },
                    child: const Text('保存'))
              ],
            ));
    // Dialog routes can keep the field alive during their exit animation.
    if (value == null) return;
    try {
      await AiRequestAudit.setBudget(widget.purpose, value);
      _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('任务额度暂未保存')));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(budget?.label ?? '任务默认 ${widget.defaultBudget} Token；全局上限待初始化',
              style: const TextStyle(fontSize: 11)),
          if (latest != null)
            Text(
                '最近请求：${AiTokenUsage.fromJson(latest!['usage'] as Map? ?? {}).label}'
                '${(latest!['finish_reason'] ?? '').toString().isEmpty ? '' : ' · 结束 ${latest!['finish_reason']}'}',
                style: const TextStyle(fontSize: 11)),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('调整任务额度'))),
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
        appBar: AppBar(title: const Text('任务额度与实际用量'), actions: [
          IconButton(
              tooltip: '刷新用量',
              onPressed: () => setState(() => rows = AiRequestAudit.history()),
              icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              '全局上限与实际消费不同。以下只记录本机最近100次统一文字生成请求；供应商未返回的用量显示未知，不能据此视为免费。缓存与推理数量已包含在输入、输出中。'),
          for (final task in const [
            ('cognition.semantic.v4', 10000, '概念图'),
            ('quote_ai.comparison.v7', 10000, '名言比较'),
            ('cognition.semantic.expand.v4', 4000, '分支展开'),
            ('cognition.semantic.repair.v4', 2000, '局部修复'),
            ('cognition.semantic.verify.v4', 2000, '辅助核验'),
          ])
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(task.$3),
                          AiBudgetPanel(
                              purpose: task.$1, defaultBudget: task.$2)
                        ]))),
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
                              const Text('分类批次由分类管理的成本策略控制额度。')
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
                                    '实际额度 ${(row['budget'] as Map?)?['effective'] ?? '未知'} · HTTP ${row['status'] ?? '未知'} · ${row['finish_reason'] ?? ''}'
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
