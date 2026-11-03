import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_request_accounting.dart';
import '../services/ai_request_audit.dart';
import '../widgets/ai_budget_panel.dart';
import 'philosophy_benchmark.dart';

class PhilosophyBenchmarkPage extends StatefulWidget {
  final PhilosophyBenchmarkService? service;
  const PhilosophyBenchmarkPage({super.key, this.service});
  @override
  State<PhilosophyBenchmarkPage> createState() =>
      _PhilosophyBenchmarkPageState();
}

class _PhilosophyBenchmarkPageState extends State<PhilosophyBenchmarkPage> {
  late final service = widget.service ?? PhilosophyBenchmarkService();
  List<Map<String, dynamic>> runs = [];
  AiOperation? operation;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await service.history();
      if (mounted) setState(() => runs = value);
    } catch (_) {
      if (mounted) setState(() => error = '验收记录暂未读取');
    }
  }

  @override
  void dispose() {
    operation?.cancellation.cancel();
    super.dispose();
  }

  Future<void> _run(PhilosophyCase item) async {
    final next = AiOperation('philosophy.benchmark.${item.id}');
    setState(() {
      operation = next;
      error = null;
    });
    try {
      await service.run(item, next);
      await _load();
    } catch (e) {
      if (mounted)
        setState(() => error = e is StateError ? e.message : '验收结果暂未保存，请检查日志');
    } finally {
      if (mounted) setState(() => operation = null);
    }
  }

  Future<void> _review(Map<String, dynamic> run) async {
    final values = Map<String, dynamic>.from(run['review'] as Map? ?? {});
    var notes = (run['review_notes'] ?? '').toString();
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('人工逐项复核'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final dimension in philosophyReviewDimensions)
                    DropdownButtonFormField<String>(
                        initialValue:
                            (values[dimension] ?? 'pending').toString(),
                        decoration: InputDecoration(labelText: dimension),
                        items: const [
                          DropdownMenuItem(
                              value: 'pending', child: Text('待复核')),
                          DropdownMenuItem(value: 'pass', child: Text('通过')),
                          DropdownMenuItem(value: 'issue', child: Text('有问题'))
                        ],
                        onChanged: (value) =>
                            setDialogState(() => values[dimension] = value)),
                  TextFormField(
                      initialValue: notes,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: '具体依据、问题与限制'),
                      onChanged: (value) => notes = value),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () {
                        if (values.values.contains('issue') &&
                            notes.trim().isEmpty) return;
                        Navigator.pop(context, true);
                      },
                      child: const Text('保存复核'))
                ],
              ),
            ));
    if (saved != true) return;
    final next = {
      ...run,
      'review': values,
      'review_notes': notes,
      'reviewed_at': DateTime.now().toIso8601String()
    };
    next['review_status'] = PhilosophyBenchmarkService.reviewStatus(next);
    await service.save(next);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('哲学材料 · 真实模型验收')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              '使用手机当前配置的模型。每次点击只运行一组，不自动重试、不自动评分。供应商可能收费；待人工复核不算通过。本地保留最近60次结果，原始输入与输出可复制。'),
          const AiBudgetPanel(
              purpose: 'cognition.semantic.v4', defaultBudget: 10000),
          if (error != null)
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (operation != null) ...[
            const LinearProgressIndicator(),
            TextButton(
                onPressed: () => operation?.cancellation.cancel(),
                child: const Text('停止接收本次请求'))
          ],
          for (final item in philosophyCases)
            Card(
                child: ExpansionTile(
              title: Text('${item.id} · ${item.title}'),
              subtitle: Text(item.boundary),
              children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final source in item.sources)
                            SelectableText(source.text),
                          Text('禁止结论：${item.forbidden}'),
                          FilledButton(
                              onPressed:
                                  operation != null ? null : () => _run(item),
                              child: const Text('运行此组一次')),
                        ]))
              ],
            )),
          for (final run in runs)
            Card(
                child: ExpansionTile(
              title: Text('${run['case']} · ${run['at']}'),
              subtitle: Text('生成 ${switch (run['generation_status']) {
                'received' => '结构已接收',
                'contract_issue' => '结构待修复',
                'output_limit' => '输出达限',
                'transport' => '连接未完成',
                'format' => '格式未完成',
                'cancelled' => '已停止',
                _ => '请求未完成'
              }} · ${switch (run['review_status']) {
                'passed' => '人工已通过',
                'issues' => '人工记录问题',
                _ => '待人工复核'
              }}'),
              children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final attempt in run['attempts'] is List
                              ? run['attempts'] as List
                              : [])
                            if (attempt is Map)
                              Text(AiTokenUsage.fromJson(
                                      attempt['usage'] as Map? ?? {})
                                  .label),
                          SelectableText(
                              (run['raw_json'] ?? run['error'] ?? '未收到正文')
                                  .toString()),
                          if (run['review_notes'] != null)
                            Text('复核说明：${run['review_notes']}'),
                          TextButton(
                              onPressed: () => _review(run),
                              child: const Text('人工逐项复核')),
                          TextButton(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(
                                    text: const JsonEncoder.withIndent('  ')
                                        .convert(run)));
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('已复制输入、输出、配置与复核记录')));
                              },
                              child: const Text('复制完整验收记录')),
                        ]))
              ],
            )),
        ]),
      );
}
