import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'evidence_growth_ai_cache.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_discovery.dart';
import 'evidence_growth_journey_models.dart';
import 'evidence_growth_knowledge_page.dart';
import 'evidence_growth_models.dart';

typedef GrowthDiscoverCall = Future<GrowthData> Function(String raw,
    {bool refresh});

class GrowthDiscoveryPage extends StatefulWidget {
  const GrowthDiscoveryPage({
    super.key,
    required this.dao,
    required this.journey,
    this.service,
  });
  final EvidenceGrowthDao dao;
  final GrowthJourney journey;
  final GrowthDiscovery? service;
  @override
  State<GrowthDiscoveryPage> createState() => _DiscoveryState();
}

class _DiscoveryState extends State<GrowthDiscoveryPage> {
  late final service = widget.service ?? GrowthDiscovery(widget.dao);
  String inputOf(GrowthJourney j) =>
      [j.data['pending_entry'], j.data['raw_input'], j.title]
          .map((v) => '${v ?? ''}'.trim())
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');
  late final String raw = inputOf(widget.journey);
  final own = TextEditingController();
  GrowthData analysis = {}, matching = {}, solution = {};
  List<GrowthData> selectedNeeds = [], selectedKnowledge = [];
  int phase = 0;
  bool busy = false, loading = true;
  String error = '';
  Future<void> saving = Future.value();
  String get storage => 'discovery_session_${widget.journey.id}';
  @override
  void initState() {
    super.initState();
    unawaited(restore());
  }

  @override
  void dispose() {
    own.dispose();
    super.dispose();
  }

  Future<void> persist() {
    final value = jsonEncode({
      'fingerprint': GrowthAiCache.fingerprint(raw),
      'analysis': analysis,
      'matching': matching,
      'solution': solution,
      'needs': selectedNeeds,
      'knowledge': selectedKnowledge,
      'phase': phase,
    });
    saving = saving
        .catchError((Object _) {})
        .then((_) => widget.dao.setSetting(storage, value));
    return saving;
  }

  Future<void> restore() async {
    try {
      final s = await widget.dao.getSetting(storage);
      final v = s.isEmpty ? <String, dynamic>{} : growthMap(jsonDecode(s));
      if (v['fingerprint'] == GrowthAiCache.fingerprint(raw)) {
        analysis = growthMap(v['analysis']);
        matching = growthMap(v['matching']);
        solution = growthMap(v['solution']);
        selectedNeeds = growthRows(v['needs']);
        selectedKnowledge = growthRows(v['knowledge']);
        phase = growthInt(v['phase']).clamp(0, 2);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => loading = false);
    if (analysis.isEmpty) await run(() => analyse());
  }

  Future<void> run(Future<void> Function() fn) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await fn();
      await persist();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> analyse({bool refresh = false}) async {
    final result = await service.discover(raw, refresh: refresh);
    if (!mounted) return;
    setState(() {
      analysis = result;
      if (refresh) {
        selectedNeeds =
            selectedNeeds.where((n) => n['origin'] == 'USER').toList();
        selectedKnowledge = [];
        matching = {};
        solution = {};
        phase = 0;
      }
    });
  }

  void selectNeed(GrowthData row, bool value) {
    setState(() {
      selectedNeeds = selectedNeeds.where((n) => n['id'] != row['id']).toList();
      if (value) selectedNeeds.add({...row, 'selection_origin': 'USER'});
      matching = {};
      selectedKnowledge = [];
      solution = {};
    });
    unawaited(persist());
  }

  Future<void> match({bool refresh = false}) async {
    final r = await service.knowledge(raw, selectedNeeds, refresh: refresh);
    if (!mounted) return;
    setState(() {
      matching = r;
      if (refresh) selectedKnowledge = [];
      phase = 1;
      solution = {};
    });
  }

  Future<void> solve({bool refresh = false}) async {
    final r = await service.solve(
      raw,
      selectedNeeds,
      selectedKnowledge,
      refresh: refresh,
    );
    if (!mounted) return;
    setState(() {
      solution = r;
      phase = 2;
    });
  }

  Future<void> accept() async {
    final current = await widget.dao.journeys.find(widget.journey.id);
    if (current == null) throw StateError('目标已不存在');
    final currentRaw = inputOf(current);
    if (currentRaw != raw) throw StateError('输入已变化，请返回重新分析。');
    final result =
        await widget.dao.journeys.change(current, 'discovery-confirm', {
      'raw_input': raw,
      'needs': selectedNeeds,
      'knowledge': selectedKnowledge,
      'solution': solution,
      'user_confirmed': true,
    });
    if (mounted) Navigator.pop(context, result);
  }

  Widget notice(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text),
      );
  Widget needCard(GrowthData row) {
    final selected = selectedNeeds.any((n) => n['id'] == row['id']);
    final score = row['score'];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            key: ValueKey('need_${row['id']}'),
            value: selected,
            onChanged: busy ? null : (v) => selectNeed(row, v ?? false),
            title: Text('${row['need']}'),
            subtitle: Text(
              '${row['problem']}\n${score is num ? '${row['score_origin']} 匹配度 ${(score * 100).round()}/100' : '你补充的需求'}',
            ),
          ),
          ExpansionTile(
            title: const Text('为什么提出这个候选？'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  [
                    if ('${row['intention'] ?? ''}'.isNotEmpty)
                      '可能目的：${row['intention']}',
                    if ('${row['reason'] ?? ''}'.isNotEmpty)
                      '相关理由：${row['reason']}',
                    if ('${row['fact_quote'] ?? ''}'.isNotEmpty)
                      '对应原话：${row['fact_quote']}',
                    if ('${row['question'] ?? ''}'.isNotEmpty)
                      '自我核对：${row['question']}',
                  ].join('\n'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget knowledgeCard(GrowthData row) {
    final n = EvidenceKNode.fromJson(growthMap(row['snapshot']));
    final selected = selectedKnowledge.any((n) => n['id'] == row['id']);
    final score = row['score'], contra = row['contra'];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            key: ValueKey('knowledge_${n.id}'),
            value: selected,
            onChanged: busy
                ? null
                : (value) {
                    setState(() {
                      selectedKnowledge = selectedKnowledge
                          .where((n) => n['id'] != row['id'])
                          .toList();
                      if (value == true)
                        selectedKnowledge.add({
                          ...row,
                          'selection_origin': 'USER',
                        });
                      solution = {};
                    });
                    unawaited(persist());
                  },
            title: Text(n.title),
            subtitle: Text(
              '${n.module.label} · ${score is num ? 'JEV 匹配度 ${(score * 100).round()}/100' : '本地检索 · 无 JEV 评分'}\n${n.claim}',
            ),
          ),
          if (contra is num && contra > .2)
            notice('有适用条件冲突的可能，请核对下面的边界；高匹配不等于安全适用。'),
          ExpansionTile(
            title: const Text('方法、前提与出处'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '怎么用：${n.howTo.join('；')}\n前提：${n.prerequisites.join('；')}\n边界：${[
                    ...n.boundaries,
                    ...n.misuseBoundary
                  ].join('；')}\n来源：${n.locator.display}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('先弄清需要，再选择方法'),
          actions: [
            IconButton(
              tooltip: 'JEV 与知识设置',
              icon: const Icon(Icons.settings),
              onPressed: busy
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EvidenceGrowthKnowledgePage(
                            dao: widget.dao,
                            journey: widget.journey,
                            stage: widget.journey.node,
                          ),
                        ),
                      );
                    },
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(raw, style: Theme.of(context).textTheme.titleMedium),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < 3; i++)
                        ChoiceChip(
                          label: Text(['1 选择需求', '2 选择知识', '3 查看方案'][i]),
                          selected: phase == i,
                          onSelected: busy || i > phase
                              ? null
                              : (_) => setState(() => phase = i),
                        ),
                    ],
                  ),
                  notice('最终由你选择。AI 候选不是诊断，也不代表已确定你的真实意图；匹配分数只用于排序。'),
                  if (busy) const LinearProgressIndicator(),
                  if (error.isNotEmpty) notice(error),
                  if (phase == 0) ...[
                    if ('${analysis['reason'] ?? ''}'.isNotEmpty)
                      notice('${analysis['reason']}'),
                    Text('最多 20 项，可多选。已选 ${selectedNeeds.length} 项'),
                    for (final row in growthRows(analysis['candidates']))
                      needCard(row),
                    for (final row in selectedNeeds.where(
                      (n) => n['origin'] == 'USER',
                    ))
                      needCard(row),
                    TextField(
                      controller: own,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '都不完全符合？写下或改写自己的需求',
                        hintText: '例如：我想先弄清是哪一个条件妨碍了开始',
                      ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              final text = own.text.trim();
                              if (text.isEmpty) return;
                              selectNeed({
                                'id':
                                    'own_${GrowthAiCache.fingerprint(text).substring(0, 12)}',
                                'need': text,
                                'problem': text,
                                'origin': 'USER',
                              }, true);
                              own.clear();
                            },
                      child: const Text('加入我的表述'),
                    ),
                    OutlinedButton(
                      onPressed:
                          busy ? null : () => run(() => analyse(refresh: true)),
                      child: const Text('重新分析候选'),
                    ),
                    FilledButton(
                      key: const ValueKey('confirm_needs'),
                      onPressed: busy || selectedNeeds.isEmpty
                          ? null
                          : () => run(() => match()),
                      child: const Text('这些符合我，匹配知识'),
                    ),
                  ],
                  if (phase == 1) ...[
                    Text('以你选择的 ${selectedNeeds.length} 项需求匹配知识。勾选你认为有帮助的方法。'),
                    if ('${matching['reason'] ?? ''}'.isNotEmpty)
                      notice('${matching['reason']}'),
                    notice('展示召回候选中的前 5 项。知识选择仍需结合前提核对，不自动等于已经应用。'),
                    for (final row in growthRows(matching['candidates']))
                      knowledgeCard(row),
                    OutlinedButton(
                      onPressed:
                          busy ? null : () => run(() => match(refresh: true)),
                      child: const Text('重新匹配知识'),
                    ),
                    FilledButton(
                      key: const ValueKey('confirm_knowledge'),
                      onPressed: busy || selectedKnowledge.isEmpty
                          ? null
                          : () => run(() => solve()),
                      child: const Text('用已选知识生成方案'),
                    ),
                  ],
                  if (phase == 2) ...[
                    if (solution['origin'] == 'AI') ...[
                      notice('AI 方案 · ${solution['model'] ?? ''} · 待你核对'),
                      SelectableText('${solution['summary']}'),
                      notice('${solution['relationships'] ?? ''}'),
                      for (final step in growthRows(solution['steps']))
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${step['action']}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  '为什么：${step['why']}\n观察什么：${step['signal']}\n边界：${step['boundary']}',
                                ),
                                Text(
                                  '对应需求：${selectedNeeds.where((n) => growthStrings(step['need_ids']).contains(n['id'])).map((n) => n['need']).join('；')}',
                                ),
                                Text(
                                  '知识依据：${selectedKnowledge.where((n) => growthStrings(step['node_ids']).contains(n['id'])).map((n) => growthMap(n['snapshot'])['title']).join('；')}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (growthStrings(solution['alternatives']).isNotEmpty)
                        notice(
                          '其他选择：${growthStrings(solution['alternatives']).join('；')}',
                        ),
                      if (growthStrings(solution['unknowns']).isNotEmpty)
                        notice(
                          '还需核实：${growthStrings(solution['unknowns']).join('；')}',
                        ),
                      FilledButton(
                        key: const ValueKey('continue_journey'),
                        onPressed: busy ? null : () => run(accept),
                        child: const Text('保留我的选择，进入六节点旅程'),
                      ),
                    ] else
                      notice('${solution['reason'] ?? '方案暂未生成，你的两轮选择已保留。'}'),
                    OutlinedButton(
                      onPressed:
                          busy ? null : () => run(() => solve(refresh: true)),
                      child: const Text('重新生成方案'),
                    ),
                  ],
                  if (phase > 0)
                    TextButton(
                      onPressed: busy ? null : () => setState(() => phase--),
                      child: const Text('返回修改选择'),
                    ),
                ],
              ),
      );
}
