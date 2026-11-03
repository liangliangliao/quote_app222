import '../widgets/ai_budget_panel.dart';
import '../services/ai_request_audit.dart';
import 'reading_map_quality.dart';
import '../services/semantic_json_transport.dart';
import 'package:flutter/material.dart';
import 'concept_meaning_diagram.dart';
import 'concept_meaning_network.dart';
import 'concept_hierarchy_view.dart';
import 'semantic_scope.dart';
import 'cognitive_mode.dart';
import 'semantic_scope_service.dart';

String scopeStatus(String value) => switch (value) {
      'text_claim' => '按原句主张',
      'definition' => '依所列定义',
      'interpretation' => 'AI 暂定解释',
      _ => '需要补充具体条件',
    };

class SemanticScopePanel extends StatefulWidget {
  final List<ScopeSource> sources;
  final String focus;
  final SemanticScope? initial;
  final SemanticScopeService? service;
  final bool stars, allowCircles, showViewSelector;
  final SemanticContext analysisContext;
  final EpistemicViewKind? preferredView;
  final ValueChanged<SemanticScope>? onResult;
  final void Function(String, SemanticScope)? onOpenConcept;
  final Map<String, String> imagePaths;
  const SemanticScopePanel(
      {super.key,
      required this.sources,
      this.focus = '句中概念',
      this.initial,
      this.service,
      this.stars = false,
      this.allowCircles = true,
      this.showViewSelector = true,
      this.analysisContext = const SemanticContext(),
      this.preferredView,
      this.onResult,
      this.onOpenConcept,
      this.imagePaths = const {}});
  @override
  State<SemanticScopePanel> createState() => _SemanticScopePanelState();
}

class _SemanticScopePanelState extends State<SemanticScopePanel> {
  late final service = widget.service ?? SemanticScopeService();
  SemanticScope? result;
  bool busy = false, readingCache = false;
  String? error;
  String? verification;
  AiOperation? operation;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    result = widget.initial;
    _load();
  }

  @override
  void didUpdateWidget(SemanticScopePanel old) {
    super.didUpdateWidget(old);
    if (widget.sources.map((s) => s.toJson()).toString() !=
            old.sources.map((s) => s.toJson()).toString() ||
        widget.focus != old.focus ||
        widget.analysisContext.toJson().toString() !=
            old.analysisContext.toJson().toString()) {
      operation?.cancellation.cancel();
      generation++;
      verification = null;
      result = widget.initial;
      busy = false;
      readingCache = false;
      error = null;
      _load();
    } else if (widget.initial?.toJson().toString() !=
            old.initial?.toJson().toString() &&
        widget.initial != null) {
      operation?.cancellation.cancel();
      generation++;
      verification = null;
      result = widget.initial;
      busy = false;
      readingCache = false;
      error = null;
    }
  }

  Future<void> _load() async {
    final n = ++generation;
    readingCache = true;
    try {
      final value = await service.cached(widget.sources, widget.focus,
          context: widget.analysisContext);
      if (mounted && n == generation) {
        final retainComplete =
            widget.analysisContext.purpose == readingMapPurpose &&
                result != null &&
                ReadingMapQuality.issues(result!).isEmpty &&
                value != null &&
                ReadingMapQuality.issues(value).isNotEmpty;
        setState(() {
          if (!retainComplete) result = value ?? result;
        });
        if (result != null) widget.onResult?.call(result!);
      }
    } catch (_) {
    } finally {
      if (mounted && n == generation) setState(() => readingCache = false);
    }
  }

  Future<void> _analyze([String? conceptId]) async {
    final n = ++generation;
    setState(() {
      busy = true;
      readingCache = false;
      error = null;
    });
    final node = result?.concepts.where((c) => c.id == conceptId).firstOrNull;
    final context = node == null
        ? widget.analysisContext
        : SemanticContext(
            purpose: widget.analysisContext.purpose,
            conditions: widget.analysisContext.conditions,
            conceptId: node.id,
            conceptLabel: node.label,
            conceptDefinition: node.definition);
    try {
      operation = AiOperation('cognition.semantic.v4');
      final value = await AiRequestAudit.runOperation(
          operation!,
          () => service.analyze(widget.sources, widget.focus,
              force: conceptId == null && result != null, context: context));
      if (mounted && n == generation) {
        final combined = result != null && (node != null || value.needsRepair)
            ? result!.merge(value)
            : value;
        final next = SemanticScope.parse(combined.toJson(), widget.sources,
            model: combined.model);
        setState(() => result = next);
        widget.onResult?.call(next);
        if (node != null && !next.needsRepair) {
          try {
            await service.remember(widget.sources, widget.focus, next,
                context: widget.analysisContext);
          } catch (_) {
            if (mounted && n == generation)
              setState(() => error = '展开内容已显示，暂未保存；可稍后重试。');
          }
        }
      }
    } catch (e) {
      if (mounted && n == generation)
        setState(() => error = e is SemanticRequestException
            ? e.message
            : e is FormatException
                ? e.message
                : e is StateError
                    ? e.message
                    : '分析暂未完成，请检查文字 AI 设置后重试');
    } finally {
      if (mounted && n == generation) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    operation?.cancellation.cancel();
    super.dispose();
  }

  Future<void> _auxiliary(bool repair) async {
    final previous = result;
    if (previous == null) return;
    String? selectedClaim;
    if (!repair) {
      final targets = SemanticScopeService.verificationTargets(previous);
      if (targets.isEmpty) return;
      selectedClaim = targets.length == 1
          ? '${targets.first['claim']}'
          : await showDialog<String>(
              context: context,
              builder: (context) =>
                  SimpleDialog(title: const Text('选择一条命题进行辅助核验'), children: [
                    for (final target in targets)
                      SimpleDialogOption(
                          onPressed: () =>
                              Navigator.pop(context, '${target['claim']}'),
                          child: Text('${target['claim']}'))
                  ]));
      if (!mounted || selectedClaim == null) return;
    }
    final n = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    operation = AiOperation(repair
        ? 'cognition.semantic.repair.v4'
        : 'cognition.semantic.verify.v4');
    try {
      await AiRequestAudit.runOperation(operation!, () async {
        if (repair) {
          final next = await service.repair(
              widget.sources, widget.focus, previous,
              context: widget.analysisContext);
          if (mounted && n == generation) {
            setState(() => result = next);
            widget.onResult?.call(next);
          }
        } else {
          final raw = await service.verify(widget.sources, previous,
              claim: selectedClaim);
          if (mounted && n == generation) setState(() => verification = raw);
        }
      });
    } catch (e) {
      if (mounted && n == generation) setState(() => error = e.toString());
    } finally {
      if (mounted && n == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
      key: const ValueKey('semantic-scope-panel'),
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xfffcf7eb),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffdeceb0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('概念关系与根据图',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(widget.focus, style: const TextStyle(fontSize: 12)),
        Text(
            '材料来源：${widget.sources.map((s) => switch (s.origin) {
                  'quote' => '引文（出处待核对）',
                  'user_report' => '用户报告',
                  'synopsis' => '剧情梗概',
                  'ai_interpretation' => 'AI解释',
                  'simulation' => '教学模拟',
                  'direct_observation' => '直接观察记录',
                  'teaching_text' => '教学材料',
                  _ => '未核对的记录'
                }).toSet().join('、')}',
            style: const TextStyle(fontSize: 11)),
        const AiBudgetPanel(
            purpose: 'cognition.semantic.v4', defaultBudget: 10000),
        if (result case final value?)
          SemanticScopeView(
              value: value,
              guidedReading:
                  widget.analysisContext.purpose == readingMapPurpose,
              sources: widget.sources,
              stars: widget.stars,
              allowCircles: widget.allowCircles,
              showViewSelector: widget.showViewSelector,
              preferredView: widget.preferredView,
              imagePaths: widget.imagePaths,
              onExpand: busy ? null : (id) => _analyze(id),
              onOpenConcept: widget.onOpenConcept == null
                  ? null
                  : (id) => widget.onOpenConcept!(id, value))
        else
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('分析当前原文，连接一般概念与具体经验，并选择适合的含义圈、根据图或判断力视图。')),
        if (error != null)
          Text('$error${result != null ? ' 已保留已有分析。' : ''}',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (verification != null)
          ExpansionTile(
              title: const Text('AI 辅助核验 · 仍需人工复核'),
              children: [SelectableText(verification!)]),
        ExpansionTile(
            title: const Text('分支展开与辅助任务额度', style: TextStyle(fontSize: 12)),
            expansionAnimationStyle: cognitiveExpansionStyle(context),
            children: const [
              AiBudgetPanel(
                  purpose: 'cognition.semantic.expand.v4', defaultBudget: 4000),
              AiBudgetPanel(
                  purpose: 'cognition.semantic.repair.v4', defaultBudget: 2000),
              AiBudgetPanel(
                  purpose: 'cognition.semantic.verify.v4', defaultBudget: 2000),
            ]),
        if (result != null)
          Wrap(spacing: 8, children: [
            if (result!.needsRepair)
              TextButton(
                  onPressed: busy ? null : () => _auxiliary(true),
                  child: const Text('仅修复有问题的项目（默认2000额度）')),
            TextButton(
                onPressed: busy ? null : () => _auxiliary(false),
                child: const Text('主动 AI 辅助核验（默认2000额度）')),
          ]),
        if (busy || readingCache) const LinearProgressIndicator(),
        if (busy)
          TextButton(
              onPressed: () {
                operation?.cancellation.cancel();
                generation++;
                setState(() {
                  busy = false;
                  error = '已停止接收，保留已有结果；未返回的用量未知。';
                });
              },
              child: const Text('停止接收')),
        OutlinedButton.icon(
            onPressed: busy ? null : _analyze,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(busy
                ? '正在分析概念关系…'
                : widget.analysisContext.purpose == readingMapPurpose
                    ? (result == null ||
                            ReadingMapQuality.issues(result!).isNotEmpty
                        ? '生成概念树与适用的含义圈'
                        : '完善概念链与含义圈')
                    : result == null
                        ? '分析概念关系并绘图'
                        : '重新判断关系并绘图')),
      ]));
}

class SemanticScopeView extends StatefulWidget {
  final SemanticScope value;
  final List<ScopeSource> sources;
  final bool stars, allowCircles, showViewSelector;
  final bool guidedReading;
  final EpistemicViewKind? preferredView;
  final ValueChanged<String>? onExpand, onOpenConcept;
  final Map<String, String> imagePaths;
  const SemanticScopeView(
      {super.key,
      required this.value,
      required this.sources,
      this.stars = false,
      this.guidedReading = false,
      this.allowCircles = true,
      this.showViewSelector = true,
      this.preferredView,
      this.onExpand,
      this.onOpenConcept,
      this.imagePaths = const {}});
  @override
  State<SemanticScopeView> createState() => _SemanticScopeViewState();
}

class _SemanticScopeViewState extends State<SemanticScopeView> {
  int selected = 0;
  EpistemicViewKind? chosen;
  @override
  void didUpdateWidget(SemanticScopeView old) {
    super.didUpdateWidget(old);
    if (old.preferredView != widget.preferredView ||
        old.sources.map((s) => s.toJson()).toString() !=
            widget.sources.map((s) => s.toJson()).toString()) {
      chosen = null;
      selected = 0;
    }
  }

  String where(String placement) => placement == 'cross'
      ? '跨材料'
      : widget.sources.length == 1
          ? '当前原文'
          : '$placement 句内';
  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final views = value.availableViews
        .where(
            (view) => widget.allowCircles || view != EpistemicViewKind.circles)
        .toList();
    final preferred = chosen ?? widget.preferredView;
    if (preferred == EpistemicViewKind.circles &&
        widget.allowCircles &&
        value.concepts.isNotEmpty &&
        !views.contains(EpistemicViewKind.circles))
      views.insert(0, EpistemicViewKind.circles);
    final active = views.contains(preferred)
        ? preferred
        : views.contains(value.primaryView)
            ? value.primaryView
            : views.firstOrNull;
    final drawable = value.relations.where((r) => r.scope != null).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (value.legacy)
        const Text('旧版缓存 · 可继续阅读，尚未按新版规则核验', style: TextStyle(fontSize: 11)),
      const Text('本地检查只核对结构与可确定的逻辑；AI 解释和模拟不能作为事实证明。',
          style: TextStyle(fontSize: 11)),
      for (final proposition in value.propositions)
        ExpansionTile(
            title: Text(proposition.conclusion),
            subtitle: Text(proposition.verification.reason),
            children: [
              SelectableText(
                  '主词：${proposition.subject}；谓词：${proposition.predicate}；量词：${proposition.quantifier}；否定：${proposition.polarity}；条件：${proposition.condition}；模态：${proposition.modality}\n原文依据：${proposition.evidence}')
            ]),
      if (readableModelName(value.model).isNotEmpty)
        Text('AI 分析 · ${readableModelName(value.model)}',
            style: const TextStyle(fontSize: 12)),
      if (value.needsRepair)
        ExpansionTile(
            expansionAnimationStyle: cognitiveExpansionStyle(context),
            tilePadding: EdgeInsets.zero,
            title:
                const Text('部分内容返回不完整，已保留可用分析', style: TextStyle(fontSize: 13)),
            children: [for (final issue in value.issues) Text(issue.message)]),
      if (widget.showViewSelector && views.length > 1)
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final view in views)
            ChoiceChip(
                label: Text(view.label),
                selected: active == view,
                onSelected: (_) => setState(() => chosen = view))
        ]),
      if (active == EpistemicViewKind.hierarchy)
        ConceptHierarchyView(
            value: value,
            traceGrounding: widget.guidedReading,
            imagePaths: widget.imagePaths,
            onExpand: widget.onExpand,
            onOpen: widget.onOpenConcept),
      if (active == EpistemicViewKind.abstraction) ...[
        const Text('具体材料 → 保留的共同规定 → 被省略的个别细节',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final node in value.concepts.where((n) =>
            n.kind == 'concept' &&
            [n.observed, n.retained, n.omitted].any((s) => s.isNotEmpty)))
          ConceptDetails(
              node: node,
              onExpand: widget.onExpand,
              imagePath: widget.imagePaths[node.id]),
      ],
      if (active == EpistemicViewKind.circles) ...[
        ConceptMeaningNetwork(
            value: value,
            onExpand: widget.onExpand,
            onOpen: widget.onOpenConcept,
            onRelation: (i) => setState(() => selected = i)),
        if (drawable.length > 1)
          Wrap(spacing: 6, children: [
            for (final r in drawable)
              ChoiceChip(
                  label: Text(
                      '${where(r.placement)}　${r.scope!.setA} / ${r.scope!.setB}'),
                  selected: value.relations.indexOf(r) == selected,
                  onSelected: (_) =>
                      setState(() => selected = value.relations.indexOf(r)))
          ]),
        if (drawable.isNotEmpty)
          _relation(value.relations.elementAtOrNull(selected)?.scope == null
              ? drawable.first
              : value.relations[selected]),
      ],
      if (active == EpistemicViewKind.grounds) ...[
        const Text('四重根据 · 按原文材料展开',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final root in [
          '生成根据 · 因果与条件',
          '认识根据 · 判断的依据',
          '存在根据 · 时间与空间',
          '行动根据 · 动机'
        ])
          if (value.grounds.any((g) => g.root == root)) ...[
            Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(root,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            for (final ground in value.grounds.where((g) => g.root == root))
              GroundRelationView(ground),
          ],
      ],
      if (active == EpistemicViewKind.judgment) ...[
        const Text('判断力 · 围绕当前目的辨清同异',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final j in value.judgments)
          Card(
              elevation: 0,
              color: const Color(0xfffffcf6),
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${where(j.placement)} · ${j.question}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        for (final field in [
                          ('共同规定', j.common),
                          ('关键区分', j.difference),
                          ('决定性差异', j.decisive),
                          ('适用条件', j.conditions),
                          ('判断依据', j.basis),
                          ('需要补充的材料', j.unknown)
                        ])
                          if (field.$2.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text('${field.$1}：${field.$2}',
                                    style: const TextStyle(height: 1.65))),
                        _references(j.references),
                      ]))),
        for (final r in value.relations.where((r) => r.scope == null))
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        '${where(r.placement)} · ${r.outcome == 'needs_context' ? '还需明确具体条件' : '采用概念与主张对照'}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(r.statement, style: const TextStyle(height: 1.65)),
                    _references(r.references),
                  ])),
      ],
      if (active == null) const Text('当前分析未形成可展示的视图，可保留原文后重新分析。'),
    ]);
  }

  Widget _references(List<ScopeReference> references) => ExpansionTile(
          expansionAnimationStyle: cognitiveExpansionStyle(context),
          tilePadding: EdgeInsets.zero,
          title: const Text('查看原文依据'),
          children: [
            for (final r in references)
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${r.source}　「${r.excerpt}」',
                      style: const TextStyle(height: 1.6)))
          ]);
  Widget _relation(SemanticRelation relation) {
    final scope = relation.scope!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(scopeStatus(relation.status), style: const TextStyle(fontSize: 12)),
      ConceptMeaningDiagram(
          key: ValueKey(scope.toJson().toString()),
          relation: scope.relation,
          setA: scope.setA,
          setB: scope.setB,
          universe: scope.universe,
          onlyA: scope.onlyA,
          onlyB: scope.onlyB,
          intersection: scope.intersection,
          otherMember: scope.otherMember,
          parts: scope.parts),
      Text(scope.justification, style: const TextStyle(height: 1.6)),
      Text(relation.statement, style: const TextStyle(height: 1.6)),
      ExpansionTile(
          expansionAnimationStyle: cognitiveExpansionStyle(context),
          tilePadding: EdgeInsets.zero,
          title: const Text('概念判准与原文依据'),
          children: [
            Text(
                'A　${scope.setA}\n${scope.criterionA}\nB　${scope.setB}\n${scope.criterionB}'),
            for (final p in scope.parts)
              Text('${p.term}　${p.criterion}\n${p.example}'),
            for (final r in relation.references)
              Text('${r.source}　「${r.excerpt}」'),
          ]),
    ]);
  }
}

String scopePattern(String name) => switch (name) {
      'equal' => '① 外延重合',
      'subset' || 'superset' => '② 完全包含',
      'partition' => '③ 互斥且穷尽上位范围',
      'overlap' => '④ 部分相交',
      'siblings' => '⑤ 同属上位范围且未穷尽',
      _ => '需要补充具体条件',
    };

class GroundRelationView extends StatelessWidget {
  final GroundDiagram graph;
  const GroundRelationView(this.graph, {super.key});
  @override
  Widget build(BuildContext context) {
    final title = switch (graph.kind) {
      'evidence' => '认识根据 → 判断',
      'cause' => '生成根据 · 因果条件',
      'time' => '时间 · 先后关系',
      'space' => '空间 · 相对位置',
      _ => '动机 → 行动'
    };
    return Card(
        elevation: 0,
        color: const Color(0xfff0f3f4),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(scopeStatus(graph.status),
                      style: const TextStyle(fontSize: 12)),
                  Text(graph.limitation, style: const TextStyle(fontSize: 11)),
                  if (graph.kind == 'space')
                    _space()
                  else
                    Column(children: [
                      _node(graph.from),
                      SizedBox(
                          height: 42,
                          child: CustomPaint(
                              painter: _GroundArrow(
                                  dashed: graph.kind == 'cause' ||
                                      graph.status == 'unknown'),
                              child: const SizedBox(width: 50))),
                      _node(graph.to),
                    ]),
                  Text(graph.link, style: const TextStyle(height: 1.5)),
                  for (final r in graph.references)
                    Text('${r.source}　「${r.excerpt}」',
                        style: const TextStyle(fontSize: 12)),
                ])));
  }

  Widget _space() {
    if (graph.position == 'inside')
      return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xff9aa9ae)),
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(graph.to),
            const SizedBox(height: 12),
            _node(graph.from)
          ]));
    final reversed = ['right', 'below'].contains(graph.position);
    final items = <Widget>[
      _node(reversed ? graph.to : graph.from),
      const SizedBox(width: 24, height: 24),
      _node(reversed ? graph.from : graph.to)
    ];
    final vertical = ['above', 'below', 'unspecified'].contains(graph.position);
    return CustomPaint(
        painter: const _SpaceGrid(),
        child: Padding(
            padding: const EdgeInsets.all(8),
            child: vertical
                ? Column(children: items)
                : Row(children: [
                    Expanded(child: items[0]),
                    items[1],
                    Expanded(child: items[2])
                  ])));
  }

  Widget _node(String s) => Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xff9aa9ae)),
          borderRadius: BorderRadius.circular(10)),
      child: Text(s, textAlign: TextAlign.center));
}

class _GroundArrow extends CustomPainter {
  final bool dashed;
  const _GroundArrow({this.dashed = false});
  @override
  void paint(Canvas c, Size s) {
    final pen = Paint()
      ..color = const Color(0xff687b81)
      ..strokeWidth = 2;
    if (dashed) {
      for (double y = 3; y < s.height - 8; y += 9)
        c.drawLine(Offset(s.width / 2, y), Offset(s.width / 2, y + 5), pen);
    } else
      c.drawLine(
          Offset(s.width / 2, 3), Offset(s.width / 2, s.height - 6), pen);
    c.drawLine(Offset(s.width / 2, s.height - 6),
        Offset(s.width / 2 - 5, s.height - 13), pen);
    c.drawLine(Offset(s.width / 2, s.height - 6),
        Offset(s.width / 2 + 5, s.height - 13), pen);
  }

  @override
  bool shouldRepaint(_GroundArrow old) => old.dashed != dashed;
}

class _SpaceGrid extends CustomPainter {
  const _SpaceGrid();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xffc6d1d4)
      ..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 24)
      c.drawLine(Offset(x, 0), Offset(x, s.height), p);
    for (double y = 0; y < s.height; y += 24)
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
  }

  @override
  bool shouldRepaint(_SpaceGrid old) => false;
}
