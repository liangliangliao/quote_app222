import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'self_os_models.dart';
import 'self_os_v37_rules.dart';
import 'self_os_v37_ai.dart';
import 'self_os_source_service.dart';
import 'self_os_insights.dart';
import 'self_os_learning.dart';
import 'self_os_progress.dart';
import 'self_os_horizon_view.dart';
import 'self_os_widgets.dart';
import 'self_os_workbench_widgets.dart';

part 'self_os_routes_panel.dart';
part 'self_os_knowledge_panel.dart';
part 'self_os_conflict_panel.dart';
part 'self_os_preparation_panel.dart';
part 'self_os_strength_panel.dart';
part 'self_os_reentry_panel.dart';

class SelfOsWorkbench extends StatefulWidget {
  const SelfOsWorkbench(
      {super.key,
      required this.value,
      required this.profile,
      required this.history,
      required this.onChanged,
      required this.onAi,
      required this.onEngine,
      required this.onRouteState,
      required this.onProfile,
      this.initialSection = 0});
  final SelfOsCase value;
  final SelfOsProfile profile;
  final List<SelfOsCase> history;
  final Future<bool> Function() onChanged;
  final Future<void> Function(String) onAi;
  final ValueChanged<SelfOsEngine> onEngine;
  final Future<void> Function(OsRoute, String) onRouteState;
  final Future<void> Function(SelfOsProfile) onProfile;
  final int initialSection;
  @override
  State<SelfOsWorkbench> createState() => _SelfOsWorkbenchState();
}

class _SelfOsWorkbenchState extends State<SelfOsWorkbench> {
  late int section = widget.initialSection;
  bool retrieving = false;
  int routeSelectionRevision = 0;
  SelfOsCase get c => widget.value;
  SelfOsV37 get s => c.v37;
  Map<String, String> get routeNames =>
      {for (final r in s.routes) r.id: r.title};
  Map<String, String> get nodeNames =>
      {for (final n in s.nodes) n.id: '${n.order}阶 · ${n.title}'};
  void redraw() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SelfOsWorkbench oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection)
      section = widget.initialSection;
  }

  Future<void> changed() async {
    redraw();
    await widget.onChanged();
  }

  Future<void> update(void Function(SelfOsV37) action) async {
    try {
      final draft = s.copy();
      action(draft);
      draft.validate();
      c.v37 = draft;
      await changed();
    } on FormatException catch (e) {
      if (mounted) osMessage(context, e.message);
    }
  }

  void put<T extends OsEntity>(List<T> list, T entry) {
    final index = list.indexWhere((e) => e.id == entry.id);
    if (index < 0) {
      list.add(entry);
    } else {
      list[index] = entry;
    }
  }

  Widget text(String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(value, style: const TextStyle(height: 1.55, fontSize: 13)));
  Widget button(String title, IconData icon, VoidCallback? tap,
          {bool primary = false}) =>
      Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: primary
              ? FilledButton.icon(
                  onPressed: tap,
                  icon: Icon(icon, size: 18),
                  label: Text(title))
              : OutlinedButton.icon(
                  onPressed: tap,
                  icon: Icon(icon, size: 18),
                  label: Text(title)));
  Widget ai(String title, String task) => button(
      title, Icons.auto_awesome_outlined, () => widget.onAi('v37.$task'));

  Future<List<String>?> pickEvidence(List<String> initial) async {
    final selected = initial.toSet();
    return showDialog<List<String>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, redraw) => AlertDialog(
                  title: const Text('关联来源与证据'),
                  content: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        if (s.evidence.isEmpty)
                          const OsNote('先在证据台账记录材料。未核实材料仍保持未知。'),
                        for (final e in s.evidence)
                          CheckboxListTile(
                              value: selected.contains(e.id),
                              title: Text(e.claim),
                              subtitle: Text(
                                  '${osEpistemicLabels[e.effectiveLabel]} · ${e.text('source')}'),
                              onChanged: (v) => redraw(() {
                                    if (v == true) {
                                      selected.add(e.id);
                                    } else {
                                      selected.remove(e.id);
                                    }
                                  })),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, selected.toList()),
                        child: const Text('关联'))
                  ],
                )));
  }

  Future<void> scope() async {
    final values = await osRecordEditor(context,
        title: '这次决定需要多深的认识？',
        initial: s.settings,
        note: s.text('riskSuggestion') == 'high'
            ? '分析发现可能涉及高风险，请核对成本与可逆性。风险由你结合真实情况确认。'
            : '检查深度随风险变化。轻量、可逆行动可以带着未知做实验。',
        fields: const [
          OsInput('risk', '本次决定的风险 / 成本', required: true, options: {
            'low': '低 · 小成本，可承受',
            'medium': '中 · 需要认真比较',
            'high': '高 · 可能有重大损失'
          }),
          OsInput('reversible', '现实中可以低成本撤回', kind: 'bool'),
          OsInput('highOpportunityCost', '会占用重要机会或长期资源', kind: 'bool'),
          OsInput('longHorizon', '后续能力、资源或未来路径可能分化', kind: 'bool'),
          OsInput('repeated', '这是会重复发生的选择 / 行为', kind: 'bool'),
          OsInput('mutuallyExclusive', '这些主要路径不能同时实现', kind: 'bool'),
          OsInput('riskReason', '判断风险与可逆性的依据', required: true),
          OsInput('understandingSummary', '现在怎样理解这件具体的事？'),
          OsInput('understandingReviewed', '这份理解符合我的情况，已检查关键未知', kind: 'bool'),
          OsInput('experimentPlan', '允许保留未知时，只做哪一个可逆实验？'),
          OsInput('criticalUnknownsReviewed', '已逐项检查会翻转决定的关键未知', kind: 'bool'),
          OsInput('remainingUnknowns', '仍保留哪些未知？为什么不妨碍当前行动？'),
        ]);
    if (values == null || !mounted) return;
    await update((d) {
      d.settings.addAll(values);
      d.settings['riskSuggestionReviewed'] = true;
    });
  }

  Widget gateCard() {
    final gate = SelfOsV37Rules.gate(s);
    return OsSection(
        title: '下一步 · ${gate.label}',
        subtitle: gate.reasons.join('\n'),
        trailing:
            OsPill(gate.action, color: gate.mayCommit ? osForest : osGold),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            OsPill(s.text('risk') == 'unassessed'
                ? '风险待确认'
                : '${{
                    'low': '低',
                    'medium': '中',
                    'high': '高'
                  }[s.text('risk')]}风险'),
            OsPill(s.flag('reversible') ? '可逆性待现实校准' : '涉及不可逆部分'),
            OsPill(
                '${s.evidence.where((e) => e.reliableAt(DateTime.now())).length} 条可追溯证据'),
          ]),
          const SizedBox(height: 12),
          button('确认风险与行动边界', Icons.tune, scope),
        ]);
  }

  Widget proposalCard() {
    final p = OsAnalysisProposal(s.pendingProposal!);
    final labels = {
      'routes': '候选路径',
      'gaps': '认识缺口',
      'nodes': '后果节点',
      'edges': '条件关系',
      'futureOptions': '未来路径变化',
      'interventions': '准备动作',
      'motiveChanges': '动机变化建议',
      'bridges': '力量桥接'
    };
    return OsSection(title: '待你审阅的候选', subtitle: p.summary, children: [
      if (osText(p.data['stopReason']).isNotEmpty)
        OsNote('停止边界：${p.data['stopReason']}'),
      for (final group in labels.entries)
        if (osMaps(p.data[group.key]).isNotEmpty)
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title:
                  Text('${group.value} · ${osMaps(p.data[group.key]).length}'),
              children: [
                for (final row in osMaps(p.data[group.key]))
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: text(row.entries
                          .where((e) =>
                              ![
                                'id',
                                'routeId',
                                'from',
                                'to',
                                'nodeId',
                                'gapId',
                                'evidenceIds'
                              ].contains(e.key) &&
                              e.value != '' &&
                              e.value != null)
                          .map((e) =>
                              '${_proposalLabel(e.key)}：${_proposalValue(e.key, e.value)}')
                          .join('\n'))),
              ]),
      const OsNote('采用后仍是待核验的草稿，可逐项编辑。不会替你确认事实、做出承诺或修改主路线。'),
      Wrap(children: [
        button('采用到工作台', Icons.check, () async {
          try {
            if (osMaps(p.data['gaps']).isNotEmpty ||
                osMaps(p.data['nodes']).isNotEmpty) c.beginCognition();
            final draft = p.preview(s);
            c.v37 = draft;
            c.suggestions['v37.reentry'] = osMaps(p.data['motiveChanges']);
            await changed();
          } on FormatException catch (e) {
            if (mounted) osMessage(context, e.message);
          }
        }, primary: true),
        button(
            '暂不采用', Icons.close, () => update((d) => d.pendingProposal = null)),
      ]),
    ]);
  }

  String _proposalLabel(String key) =>
      const {
        'title': '候选',
        'mechanism': '机制',
        'mechanismDetail': '结构区别',
        'desire': '服务欲求',
        'ability': '能力依据',
        'cost': '代价',
        'reality': '现实约束',
        'opportunityCost': '机会成本',
        'strength': '力量',
        'source': '来源',
        'kind': '缺口类别',
        'question': '关键问题',
        'reason': '依据',
        'access': '获取方式',
        'lowScenario': '情景一',
        'highScenario': '情景二',
        'lowChoice': '情景一的选择',
        'highChoice': '情景二的选择',
        'concrete': '现实含义',
        'order': '阶数',
        'horizon': '时间',
        'valence': '收益代价',
        'stateType': '状态',
        'relevance': '决定相关性',
        'label': '证据性质',
        'cumulative': '是否累积',
        'threshold': '阈值',
        'lockIn': '改道成本',
        'reversibleWindow': '可逆窗口',
        'counter': '反证',
        'prune': '停止延伸',
        'pruneReason': '停止原因',
        'condition': '条件',
        'basis': '因果依据',
        'branch': '情景束',
        'signal': '可观察信号',
        'loop': '回路',
        'breakCondition': '打断条件',
        'probabilityNote': '概率边界',
        'delta': '路径变化',
        'type': '准备方式',
        'task': '具体动作',
        'window': '时点',
        'expectedChange': '预期变化',
        'motiveId': '关联动机',
        'optionId': '关联路线',
        'side': '方向',
        'change': '变化',
        'strengthId': '关联力量',
        'weakness': '当前阻碍',
        'action': '动作',
        'guardrail': '护栏',
        'evidence': '依据',
        'status': '状态',
        'createdAt': '提出时间',
      }[key] ??
      key;
  String _proposalValue(String key, dynamic value) {
    if (value is bool) return value ? '是' : '否';
    final dictionaries = <String, Map<String, String>>{
      'mechanism': osMechanisms,
      'kind': osGapKinds,
      'access': {'private': '询问用户', 'public': '获取外部来源', 'experience': '现实实验'},
      'horizon': osHorizons,
      'valence': osValences,
      'label': osEpistemicLabels,
      'delta': osOptionDeltas,
      'type': osInterventionTypes,
      'window': osPreparationWindows,
      'side': {'for': '趋近 / 支持', 'against': '回避 / 反对'},
      'change': {
        'added': '新增',
        'strengthened': '增强',
        'weakened': '减弱',
        'invalidated': '失效'
      },
      'status': selfOsRouteStates
    };
    return dictionaries[key]?[value] ?? '$value';
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: osForest, borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('选择的地图',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('先看见可能，再用证据决定。',
                  style: TextStyle(color: Color(0xFFD9E6D8), height: 1.6)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in {
                  0: '选择空间',
                  1: '认识与因果',
                  2: '冲突与决意',
                  3: '未来准备',
                  4: '力量对齐'
                }.entries)
                  ChoiceChip(
                      key: ValueKey('workbench_tab_${e.key}'),
                      label: Text(e.value),
                      selected: section == e.key,
                      onSelected: (_) {
                        section = e.key;
                        redraw();
                      })
              ]),
            ])),
        if (s.pendingProposal != null) proposalCard(),
        ...[
          routesPanel,
          knowledgePanel,
          conflictPanel,
          preparationPanel,
          strengthPanel
        ][section](),
      ]);
}
