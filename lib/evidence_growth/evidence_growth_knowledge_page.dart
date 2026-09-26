import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_ai_service.dart';
import 'evidence_growth_jev.dart';
import 'evidence_growth_journey_models.dart';
import 'evidence_growth_knowledge.dart';
import 'evidence_growth_knowledge_runtime.dart';
import 'evidence_growth_models.dart';

/// Learn and apply from every step, with source snapshots and user reflection.
class EvidenceGrowthKnowledgePage extends StatefulWidget {
  const EvidenceGrowthKnowledgePage(
      {super.key,
      required this.dao,
      required this.journey,
      required this.stage,
      this.initialNodeId});
  final EvidenceGrowthDao dao;
  final GrowthJourney journey;
  final String stage;
  final String? initialNodeId;
  @override
  State<EvidenceGrowthKnowledgePage> createState() => _KnowledgeState();
}

class _KnowledgeState extends State<EvidenceGrowthKnowledgePage> {
  late GrowthJourney j = widget.journey;
  late String at = EvidenceGrowthKnowledgeRuntime.stage(widget.stage);
  final question = TextEditingController();
  final jev = EvidenceGrowthJev();
  static const channel =
      MethodChannel('com.example.quote_app/mental_health_checkup');
  List<EvidenceKNode> matches = [];
  List<GrowthData> history = [];
  GrowthData ranking = {};
  bool busy = false, catalog = false, configured = false;
  String status = '本地检索候选；请结合事实核对适用性。';
  @override
  void initState() {
    super.initState();
    match();
    unawaited(refresh());
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final current = await widget.dao.journeys.find(j.id);
    final records = await widget.dao.journeys.history(j.id);
    final enabled = await widget.dao.getSetting('jev_enabled') == 'true';
    if (mounted)
      setState(() {
        j = current ?? j;
        history = records;
        configured = enabled;
      });
  }

  GrowthData get situation => EvidenceGrowthKnowledgeRuntime.context(j, at,
      question: question.text.trim());
  void match() {
    final q = EvidenceGrowthKnowledgeRuntime.query(situation);
    matches = EvidenceGrowthKnowledgeRuntime.retrieve(at, q, limit: 12);
    final initial = EvidenceGrowthKnowledge.byId(widget.initialNodeId ?? '');
    if (initial != null && !matches.any((n) => n.id == initial.id))
      matches.insert(0, initial);
    ranking = {};
    status = matches.isEmpty
        ? '没有找到可靠候选。可补充卡点或浏览完整知识库，不自动补一条知识。'
        : '词法检索候选，不代表已确认适用。可跨六模块匹配。';
  }

  Future<void> perform(Future<void> Function() fn) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await fn();
      await refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> rank() async {
    final encrypted = await widget.dao.getSetting('jev_key_encrypted');
    final key = encrypted.isEmpty
        ? ''
        : await channel
                .invokeMethod<String>('decryptText', {'value': encrypted}) ??
            '';
    if (key.isEmpty) {
      await settings();
      return;
    }
    final result = await jev.rank(situation, matches, apiKey: key);
    if (!mounted) return;
    setState(() {
      ranking = result;
      final scores = {
        for (final row in growthRows(result['scores'])) row['id']: row
      };
      matches.sort((a, b) => ((scores[b.id]?['relevance'] as num?) ?? 0)
          .compareTo((scores[a.id]?['relevance'] as num?) ?? 0));
      status = result['status'] == 'JEV'
          ? 'JEV 已辅助排序；分数是模型估计，前提未知仍需核对。未自动采用任何知识。'
          : 'JEV 暂不可用，继续使用本地候选。';
    });
  }

  Future<void> settings() async {
    final c = TextEditingController();
    final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('JEV 匹配助手'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      '使用 TypeSafe 的 jev-latest。点击“JEV 辅助匹配”时发送当前情境和最多 12 条知识摘要；主模型保持原配置。密钥在 Android 本机加密保存。'),
                  TextField(
                      controller: c,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'TypeSafe API Key')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('停用并清除密钥')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('保存'))
                ]));
    final key = c.text.trim();
    c.dispose();
    if (save == null) return;
    if (!save) {
      await widget.dao.setSetting('jev_key_encrypted', '');
      await widget.dao.setSetting('jev_enabled', 'false');
      return;
    }
    if (key.isEmpty) throw ArgumentError('请输入密钥');
    if (!Platform.isAndroid)
      throw StateError('当前平台不支持 Android Keystore，可继续本地匹配');
    final encrypted =
        await channel.invokeMethod<String>('encryptText', {'value': key});
    if (encrypted == null || !encrypted.startsWith('keystore-v1:'))
      throw StateError('密钥未安全保存');
    await widget.dao.setSetting('jev_key_encrypted', encrypted);
    await widget.dao.setSetting('jev_enabled', 'true');
  }

  Future<void> apply(EvidenceKNode n) async {
    final cross =
        n.module != EvidenceGrowthKnowledgeRuntime.module(at) || !n.isTal;
    final fields = <String, String>{
      'understanding': '用自己的话解释：这个方法为什么有用？',
      'application': '在这个节点具体怎样用？写可执行步骤或思考问题',
      'expected_signal': '用什么可观察信号检验？',
      if (cross) 'transfer_reason': '为什么跨模块适用，或核心知识有什么缺口？'
    };
    final values = await form('将知识用于${GrowthJourney.labels[at]}', fields,
        boundary:
            '适用前提：${n.prerequisites.join('；')}\n反向信号：${n.contraSignals.join('；')}\n边界：${[
          ...n.boundaries,
          ...n.misuseBoundary
        ].join('；')}');
    if (values == null) return;
    j = await widget.dao.journeys.change(j, 'knowledge-apply', {
      'stage': at,
      'node_id': n.id,
      'node_version': n.version,
      'conditions_confirmed': true,
      ...values,
    });
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存用法。已发生的步骤和行动原预测保持原样；后续步骤会使用这条知识。')));
  }

  Future<void> explain(EvidenceKNode n) async {
    final text = await EvidenceGrowthAiService(dao: widget.dao)
        .explainKnowledge(j, at, n, question.text.trim());
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(n.title),
                content: SingleChildScrollView(child: SelectableText(text)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('回到原文核对'))
                ]));
  }

  Future<void> practice(EvidenceKNode n) async {
    final v =
        await form('练习与现实反馈', {'reflection': '回想原理，记录一次尝试：做了什么、观察到什么、哪里仍不理解？'});
    if (v != null)
      j = await widget.dao.journeys.change(j, 'knowledge-practice', {
        'stage': at,
        'node_id': n.id,
        'node_version': n.version,
        ...v,
      });
  }

  Future<Map<String, String>?> form(String title, Map<String, String> fields,
      {String? boundary}) async {
    final controllers = {
      for (final k in fields.keys) k: TextEditingController()
    };
    bool checked = boundary == null;
    final key = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                    title: Text(title),
                    content: SizedBox(
                        width: 500,
                        child: SingleChildScrollView(
                            child: Form(
                                key: key,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (boundary != null) Text(boundary),
                                      for (final e in fields.entries)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 12),
                                            child: TextFormField(
                                                controller: controllers[e.key],
                                                minLines: 2,
                                                maxLines: 5,
                                                maxLength: 2000,
                                                decoration: InputDecoration(
                                                    labelText: e.value,
                                                    alignLabelWithHint: true),
                                                validator: (v) =>
                                                    (v ?? '').trim().isEmpty
                                                        ? '请填写具体内容'
                                                        : null)),
                                      if (boundary != null)
                                        CheckboxListTile(
                                            value: checked,
                                            onChanged: (v) => update(
                                                () => checked = v ?? false),
                                            title: const Text(
                                                '我已核对前提和边界；未知条件需先查证')),
                                    ])))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: checked
                              ? () {
                                  if (key.currentState!.validate())
                                    Navigator.pop(ctx, {
                                      for (final e in controllers.entries)
                                        e.key: e.value.text.trim()
                                    });
                                }
                              : null,
                          child: const Text('保存'))
                    ])));
    for (final c in controllers.values) c.dispose();
    return result;
  }

  Widget source(EvidenceKNode n) {
    final score =
        growthRows(ranking['scores']).where((r) => r['id'] == n.id).firstOrNull;
    return Card(
        child: ExpansionTile(
            key: ValueKey('${at}_${n.id}'),
            initiallyExpanded: n.id == widget.initialNodeId,
            title: Text(n.title),
            subtitle: Text('${n.module.label} · ${n.sourceClass}\n${n.claim}'),
            children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (score != null)
                      Text(
                          'JEV 相关性 ${((score['relevance'] as num) * 100).round()}% · 边界冲突估计 ${((score['contra'] as num) * 100).round()}%${score['eligible'] == true ? ' · 候选' : ' · 暂不建议采用，需进一步核对'}'),
                    for (final e in <String, String>{
                      '为什么': n.mechanism,
                      '课堂语境': n.teachingContext,
                      '案例与研究': n.storyOrStudy,
                      '如何练习': n.howTo.join('\n'),
                      '适用前提': n.prerequisites.join('；'),
                      '反向信号': n.contraSignals.join('；'),
                      '边界与误用': [...n.boundaries, ...n.misuseBoundary].join('；'),
                      '知识库摘录': n.displayExcerpt,
                      '出处':
                          '${n.locator.display}\n${n.locator.note}\n${n.id} · ${n.version}',
                    }.entries)
                      if (e.value.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('${e.key}\n${e.value}')),
                    const Text('知识卡是知识库整理，不应当作逐字课程原话；自己的解释需与原文区分。'),
                    Wrap(spacing: 8, children: [
                      OutlinedButton(
                          onPressed:
                              busy ? null : () => perform(() => explain(n)),
                          child: const Text('结合情境讲解')),
                      OutlinedButton(
                          onPressed: busy || j.terminal
                              ? null
                              : () => perform(() => practice(n)),
                          child: const Text('复述、练习与反馈')),
                      FilledButton(
                          onPressed: busy || j.terminal
                              ? null
                              : () => perform(() => apply(n)),
                          child: const Text('核对并用于此节点'))
                    ]),
                  ]))
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final apps = growthRows(j.data['knowledge_applications']).where(
        (a) => a['stage'] == at && growthInt(a['effective_cycle']) >= j.cycle);
    final records = history
        .where((r) => r['kind'] == 'KNOWLEDGE_PRACTICE' && r['stage'] == at)
        .toList();
    final nodes = catalog ? EvidenceGrowthKnowledge.nodes : matches;
    return Scaffold(
        appBar: AppBar(title: const Text('知识学习与应用'), actions: [
          IconButton(
              tooltip: 'JEV 设置',
              onPressed: busy ? null : () => perform(settings),
              icon: const Icon(Icons.settings_outlined))
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(j.title, style: Theme.of(context).textTheme.titleLarge),
          Wrap(spacing: 6, children: [
            for (final s in EvidenceGrowthKnowledgeRuntime.stages)
              ChoiceChip(
                  label: Text(GrowthJourney.labels[s]!),
                  selected: at == s,
                  onSelected: busy
                      ? null
                      : (_) => setState(() {
                            at = s;
                            catalog = false;
                            match();
                          }))
          ]),
          Text(EvidenceGrowthKnowledgeRuntime.lessons[at]![0],
              style: Theme.of(context).textTheme.titleMedium),
          Text(EvidenceGrowthKnowledgeRuntime.lessons[at]![1]),
          const SizedBox(height: 12),
          TextField(
              controller: question,
              enabled: !busy,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: '此刻卡在哪里？想理解或练习什么？', border: OutlineInputBorder())),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                          catalog = false;
                          match();
                        }),
                child: const Text('结合当前事实匹配')),
            OutlinedButton(
                onPressed:
                    busy ? null : () => perform(configured ? rank : settings),
                child: Text(configured ? 'JEV 辅助匹配' : '配置 JEV')),
            TextButton(
                onPressed:
                    busy ? null : () => setState(() => catalog = !catalog),
                child: Text(catalog ? '返回匹配候选' : '浏览完整知识库'))
          ]),
          if (busy) const LinearProgressIndicator(),
          Text(status),
          for (final a in apps)
            Card(
                child: ListTile(
                    title: Text(
                        '已采用 · ${growthMap(a['snapshot'])['title']} · 第 ${a['effective_cycle']} 轮'),
                    subtitle: Text(
                        '我的理解：${a['understanding']}\n此节点用法：${a['application']}\n检验信号：${a['expected_signal']}'),
                    trailing: IconButton(
                        tooltip: '撤下后续应用，保留历史',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: busy || j.terminal
                            ? null
                            : () => perform(() async {
                                  j = await widget.dao.journeys.change(
                                      j,
                                      'knowledge-withdraw',
                                      {'application_id': a['id']});
                                })))),
          if (records.isNotEmpty)
            ExpansionTile(
                title: Text('练习与反馈 · ${records.length} 条（不等于掌握）'),
                children: [
                  for (final r in records.reversed)
                    ListTile(
                        title: Text('${growthMap(r['snapshot'])['title']}'),
                        subtitle: Text('${r['reflection']}'))
                ]),
          for (final n in nodes) source(n),
        ]));
  }
}
