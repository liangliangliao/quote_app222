import 'semantic_analysis_archive.dart';
import '../services/ai_request_audit.dart';
import 'reading_map_quality.dart';
import '../services/semantic_json_transport.dart';
import 'package:flutter/material.dart';
import 'concept_meaning_diagram.dart';
import 'concept_meaning_network.dart';
import 'concept_circle_preview.dart';
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
  final bool stars, allowCircles, showViewSelector, showActions, showHeader;
  final VoidCallback? onStateChanged;
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
      this.showActions = true,
      this.showHeader = true,
      this.onStateChanged,
      this.analysisContext = const SemanticContext(),
      this.preferredView,
      this.onResult,
      this.onOpenConcept,
      this.imagePaths = const {}});
  @override
  State<SemanticScopePanel> createState() => SemanticScopePanelState();
}

class SemanticScopePanelState extends State<SemanticScopePanel> {
  late final service = widget.service ?? SemanticScopeService();
  SemanticScope? result;
  bool busy = false,
      readingCache = false,
      saved = false,
      savePending = false,
      _attempted = false;
  String? error, verification;
  String _pendingRaw = '';
  AiOperation? operation;
  int generation = 0;
  late String inquiry = widget.analysisContext.inquiry;
  bool get canRetry => result != null || _attempted;
  void _notify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onStateChanged?.call();
    });
  }

  @override
  void initState() {
    super.initState();
    result = widget.initial;
    _load();
  }

  @override
  void didUpdateWidget(SemanticScopePanel old) {
    super.didUpdateWidget(old);
    if (old.sources.map((s) => s.toJson()).toString() !=
            widget.sources.map((s) => s.toJson()).toString() ||
        old.focus != widget.focus ||
        old.analysisContext.cacheJson().toString() !=
            widget.analysisContext.cacheJson().toString()) {
      operation?.cancellation.cancel();
      generation++;
      result = widget.initial;
      busy = false;
      saved = false;
      savePending = false;
      _attempted = false;
      _pendingRaw = '';
      error = null;
      verification = null;
      inquiry = widget.analysisContext.inquiry;
      _load();
    } else if (!busy &&
        old.initial?.toJson().toString() !=
            widget.initial?.toJson().toString() &&
        widget.initial != null) {
      result = widget.initial;
      saved = true;
      savePending = false;
      error = null;
      _notify();
    }
  }

  Future<void> _load() async {
    final n = ++generation;
    readingCache = true;
    try {
      final value = await service.cached(widget.sources, widget.focus,
          context: widget.analysisContext);
      if (!mounted || n != generation) return;
      setState(() {
        result = value ?? result;
        saved = value != null;
        readingCache = false;
      });
      _notify();
      if (result != null) widget.onResult?.call(result!);
      try {
        final entry = await service.archive
            .current(widget.sources, widget.focus, widget.analysisContext);
        final history = await service.archive
            .history(widget.sources, widget.focus, widget.analysisContext);
        if (mounted && n == generation)
          setState(() {
            if (entry?.inquiry.isNotEmpty == true) inquiry = entry!.inquiry;
            _attempted = history.isNotEmpty;
            if (history.firstOrNull?.status == 'failed')
              error =
                  result == null ? '上次分析未完成，可重试深入分析。' : '最近一次分析未完成，正显示上次本地结果。';
          });
      } catch (_) {
        /* Legacy caches remain readable without a revision index. */
      }
    } catch (_) {
      if (mounted && n == generation) setState(() => error = '本地分析暂未读取，可重试读取。');
    } finally {
      if (mounted && n == generation) {
        setState(() => readingCache = false);
        _notify();
      }
    }
  }

  Future<void> generate() => _analyze();
  Future<void> retryAnalysis() async {
    if (busy) return;
    final request = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => _SemanticRetryDialog(inquiry: inquiry));
    if (!mounted || request == null) return;
    inquiry = request['goal']!.isEmpty ? inquiry : request['goal']!;
    await _analyze(
        null,
        null,
        request['feedback']!.isEmpty
            ? '上一轮结果不满意，请从原文独立重审概念、必要中介、具体经验与含义范围，指出并纠正旧分析的问题。'
            : request['feedback']);
  }

  Future<void> retrySave() async {
    final value = result;
    if (value == null || busy) return;
    try {
      await service.archive.save(widget.sources, widget.focus,
          widget.analysisContext.withInquiry(inquiry),
          analysis: value, raw: _pendingRaw);
      if (mounted)
        setState(() {
          saved = true;
          savePending = false;
          error = null;
        });
    } catch (_) {
      if (mounted) setState(() => error = '本地保存仍未完成；当前结果继续保留。');
    }
    _notify();
  }

  Future<void> showSavedAnalyses() async {
    try {
      final items = await service.archive
          .history(widget.sources, widget.focus, widget.analysisContext);
      if (!mounted) return;
      final picked = await showModalBottomSheet<SavedSemanticAnalysis>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (c) => SafeArea(
              child: SizedBox(
                  height: MediaQuery.sizeOf(c).height * .65,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    const ListTile(
                        title: Text('本地分析版本'),
                        subtitle: Text('查看或恢复已有版本，不会重新请求 AI。')),
                    if (items.isEmpty)
                      const ListTile(title: Text('暂无保存的分析版本。')),
                    for (final item in items)
                      ListTile(
                          leading: Icon(item.status == 'complete'
                              ? Icons.check_circle_outline
                              : item.analysis == null
                                  ? Icons.error_outline
                                  : Icons.article_outlined),
                          title: Text(
                              '${item.at.toLocal().toString().split('.').first} · ${item.status == 'complete' ? '完整结果' : item.analysis == null ? '未完成' : '部分结果'}'),
                          subtitle: Text(
                              item.analysis?.analysisSummary.isNotEmpty == true
                                  ? item.analysis!.analysisSummary
                                  : item.error.isNotEmpty
                                      ? item.error
                                      : item.analysis?.analysisPurpose ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                          enabled: item.analysis != null,
                          onTap: () => Navigator.pop(c, item)),
                  ]))));
      if (picked == null || !mounted) return;
      await service.archive.select(picked);
      if (!mounted) return;
      operation?.cancellation.cancel();
      generation++;
      setState(() {
        result = picked.analysis;
        inquiry = picked.inquiry;
        busy = false;
        readingCache = false;
        saved = true;
        savePending = false;
        error = null;
        verification = null;
      });
      widget.onResult?.call(result!);
      _notify();
    } catch (_) {
      if (mounted) setState(() => error = '本地版本暂未读取，已有内容继续保留。');
    }
  }

  void stop() {
    operation?.cancellation.cancel();
    generation++;
    setState(() {
      busy = false;
      error = '已停止接收，保留已有结果。';
    });
    _notify();
  }

  Future<void> _analyze(
      [String? conceptId,
      EpistemicViewKind? requiredView,
      String? review]) async {
    if (busy || readingCache) return;
    final n = ++generation;
    setState(() {
      busy = true;
      error = null;
      verification = null;
      _attempted = true;
    });
    _notify();
    final node = result?.concepts.where((c) => c.id == conceptId).firstOrNull;
    var base = widget.analysisContext.withInquiry(inquiry);
    if (requiredView != null)
      base =
          base.withViews({...base.requestedViews, requiredView.name}.toList());
    if (review != null) {
      Map<String, dynamic>? previous = result?.toJson();
      try {
        final latest =
            (await service.archive.history(widget.sources, widget.focus, base))
                .firstOrNull;
        if (latest?.status == 'failed') {
          previous = {
            if (previous != null) 'last_usable_analysis': previous,
            'failed_response': latest!.raw,
            'failure': latest.error,
          };
        }
      } catch (_) {}
      base = base.withReview(review, previous);
    }
    final request = node == null
        ? base
        : SemanticContext(
            purpose: base.purpose,
            inquiry: inquiry,
            conditions: base.conditions,
            requestedViews: base.requestedViews,
            conceptId: node.id,
            conceptLabel: node.label,
            conceptDefinition: node.definition,
            existingCases: result!.alignedCases,
            existingConcepts: result!.concepts,
            existingHierarchy: result!.hierarchy,
            existingLinks: result!.meaningLinks,
            existingRelations: result!.relations);
    try {
      operation = AiOperation(SemanticScopeService.requestPurpose);
      SemanticScope next;
      SemanticScope? unsavedMerged;
      try {
        final response = await AiRequestAudit.runOperation(
            operation!,
            () => service.analyze(widget.sources, widget.focus,
                force: node == null, context: request));
        next = node == null
            ? response
            : SemanticScope.parse(
                result!.merge(response).toJson(), widget.sources,
                model: response.model);
        if (!mounted || n != generation) return;
        if (node != null) {
          try {
            await service.remember(widget.sources, widget.focus, next,
                context: base);
          } catch (_) {
            unsavedMerged = next;
            throw SemanticPersistenceException(next, '');
          }
        }
        if (mounted && n == generation)
          setState(() {
            result = next;
            saved = true;
            savePending = false;
            _pendingRaw = '';
          });
      } on SemanticPersistenceException catch (e) {
        next = unsavedMerged ??
            (node == null
                ? e.analysis
                : SemanticScope.parse(
                    result!.merge(e.analysis).toJson(), widget.sources,
                    model: e.analysis.model));
        if (mounted && n == generation)
          setState(() {
            result = next;
            savePending = true;
            saved = false;
            _pendingRaw = e.raw;
            error = e.toString();
          });
      }
      if (mounted && n == generation) widget.onResult?.call(result!);
    } catch (e) {
      if (mounted && n == generation)
        setState(() => error = e is SemanticRequestException
            ? e.message
            : e is FormatException
                ? e.message
                : e is StateError
                    ? e.message
                    : '分析暂未完成，已有结果仍保留，可重试深入分析。');
    } finally {
      if (mounted && n == generation) {
        setState(() => busy = false);
        _notify();
      }
    }
  }

  Future<void> _auxiliary(bool repair) async {
    final previous = result;
    if (previous == null || busy) return;
    final targets = SemanticScopeService.verificationTargets(previous);
    if (!repair && targets.isEmpty) return;
    final claim = repair
        ? null
        : await showDialog<String>(
            context: context,
            builder: (c) =>
                SimpleDialog(title: const Text('选择一项判断'), children: [
                  for (final target in targets)
                    SimpleDialogOption(
                        onPressed: () => Navigator.pop(c, '${target['claim']}'),
                        child: Text('${target['claim']}'))
                ]));
    if (!mounted || (!repair && claim == null)) return;
    final n = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    _notify();
    operation = AiOperation(SemanticScopeService.requestPurpose);
    try {
      await AiRequestAudit.runOperation(operation!, () async {
        if (repair) {
          final next = await service.repair(
              widget.sources, widget.focus, previous,
              context: widget.analysisContext.withInquiry(inquiry));
          if (mounted && n == generation) {
            setState(() {
              result = next;
              saved = true;
            });
            widget.onResult?.call(next);
          }
        } else {
          final raw =
              await service.verify(widget.sources, previous, claim: claim);
          if (mounted && n == generation) setState(() => verification = raw);
        }
      });
    } on SemanticPersistenceException catch (e) {
      if (mounted && n == generation) {
        setState(() {
          result = e.analysis;
          saved = false;
          savePending = true;
          _pendingRaw = e.raw;
          error = e.toString();
        });
        widget.onResult?.call(e.analysis);
      }
    } catch (_) {
      if (mounted && n == generation)
        setState(() => error = '本次核对未完成，已有结果仍保留。');
    } finally {
      if (mounted && n == generation) {
        setState(() => busy = false);
        _notify();
      }
    }
  }

  @override
  void dispose() {
    operation?.cancellation.cancel();
    super.dispose();
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
        if (widget.showHeader) ...[
          const Text('概念关系与直观依据',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('本次理解目的'),
              children: [
                TextFormField(
                    key: ValueKey(inquiry),
                    initialValue: inquiry,
                    enabled: !busy,
                    maxLines: 2,
                    onChanged: (s) => inquiry = s),
              ]),
        ],
        if (widget.showActions)
          SemanticAnalysisActions(
              busy: busy || readingCache,
              canRetry: canRetry,
              savePending: savePending,
              onGenerate: generate,
              onRetry: retryAnalysis,
              onHistory: showSavedAnalyses,
              onSave: retrySave,
              onStop: stop,
              initialLabel:
                  widget.sources.length > 1 ? '分析所选名言的含义关系' : '深入分析这句名言'),
        if (result case final value?)
          SemanticScopeView(
              value: value,
              sources: widget.sources,
              guidedReading:
                  widget.analysisContext.purpose == readingMapPurpose,
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
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('分析将连接原句、核心概念、具体经验及判断依据；已有本地结果会直接读取。')),
        if (saved)
          const Text('已保存到本地',
              style: TextStyle(fontSize: 12, color: Color(0xff547064))),
        if (error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        if (busy || readingCache) const LinearProgressIndicator(),
        if (verification != null)
          ExpansionTile(
              title: const Text('辅助核验 · 待复核'),
              children: [SelectableText(verification!)]),
        if (result != null && widget.showActions)
          ExpansionTile(title: const Text('核对与补全'), children: [
            Wrap(spacing: 8, children: [
              if (result!.needsRepair)
                TextButton(
                    onPressed: busy ? null : () => _auxiliary(true),
                    child: const Text('补全缺失项目')),
              TextButton(
                  onPressed: busy ? null : () => _auxiliary(false),
                  child: const Text('核查一项判断')),
            ])
          ]),
      ]));
}

class _SemanticRetryDialog extends StatefulWidget {
  final String inquiry;
  const _SemanticRetryDialog({required this.inquiry});
  @override
  State<_SemanticRetryDialog> createState() => _SemanticRetryDialogState();
}

class _SemanticRetryDialogState extends State<_SemanticRetryDialog> {
  late final goal = TextEditingController(text: widget.inquiry);
  final feedback = TextEditingController();
  @override
  void dispose() {
    goal.dispose();
    feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('重新深入分析'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: goal,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '本次理解目的')),
            TextField(
                controller: feedback,
                maxLines: 3,
                maxLength: 1500,
                decoration: const InputDecoration(
                    labelText: '哪里不满意（可不填）',
                    hintText: '例如：关系没有说明依据，缺少具体经验或完整含义圈')),
            const Text('会重新核对原文、旧分析与具体问题，生成一个新版本；旧结果继续保留。',
                style: TextStyle(fontSize: 12)),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, {
                      'goal': goal.text.trim(),
                      'feedback': feedback.text.trim()
                    }),
                child: const Text('重试深入分析'))
          ]);
}

class SemanticAnalysisActions extends StatelessWidget {
  final bool busy, canRetry, savePending;
  final VoidCallback onGenerate, onRetry, onHistory, onSave, onStop;
  final String initialLabel;
  const SemanticAnalysisActions(
      {super.key,
      required this.busy,
      required this.canRetry,
      required this.savePending,
      required this.onGenerate,
      required this.onRetry,
      required this.onHistory,
      required this.onSave,
      required this.onStop,
      this.initialLabel = '深入分析这句名言'});
  @override
  Widget build(BuildContext context) => Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
                key: const ValueKey('semantic-analysis-action'),
                onPressed: busy
                    ? null
                    : canRetry
                        ? onRetry
                        : onGenerate,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(busy
                    ? '正在深入分析…'
                    : canRetry
                        ? '重试并深入分析'
                        : initialLabel)),
            IconButton(
                tooltip: '本地分析版本',
                onPressed: busy ? null : onHistory,
                icon: const Icon(Icons.history)),
            if (savePending)
              TextButton.icon(
                  onPressed: busy ? null : onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('重试保存')),
            if (busy) TextButton(onPressed: onStop, child: const Text('停止接收')),
          ]);
}

class SemanticScopeView extends StatefulWidget {
  final SemanticScope value;
  final List<ScopeSource> sources;
  final bool stars, allowCircles, showViewSelector;
  final bool guidedReading;
  final EpistemicViewKind? preferredView;
  final ValueChanged<String>? onExpand, onOpenConcept;
  final VoidCallback? onRegenerate;
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
      this.onRegenerate,
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
      : widget.value.alignedCases.any((c) => c.id == placement)
          ? '相关案例'
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
    if ((preferred == EpistemicViewKind.hierarchy ||
            (preferred == EpistemicViewKind.circles && widget.allowCircles)) &&
        !views.contains(preferred)) views.insert(0, preferred!);
    final active = views.contains(preferred)
        ? preferred
        : views.contains(value.primaryView)
            ? value.primaryView
            : views.firstOrNull;
    final drawable = value.relations.where((r) => r.scope != null).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (value.legacy)
        const Text('旧版缓存 · 保留原分析，可主动按新版重分析以补充关系连线',
            style: TextStyle(fontSize: 11)),
      if (value.analysisSummary.isNotEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SelectableText(value.analysisSummary,
                style: const TextStyle(fontSize: 17, height: 1.65))),
      for (final item in value.alignedCases)
        Card(
            color: const Color(0xffedf4ef),
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('相关教学案例 · ${item.title}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(item.text, style: const TextStyle(height: 1.65)),
                      Text('分析目的：${item.purpose}'),
                      ExpansionTile(
                          title: const Text('与原句的对应及适用边界'),
                          children: [
                            for (final pair in item.alignment)
                              Text(
                                  '原句「${pair['excerpt']}」\n案例「${pair['case_detail']}」\n保留的意义：${pair['preserved_meaning']}'),
                            Text(item.boundary),
                          ]),
                      const Text('下图中的案例事件属于教学情境，不冒充原句记述的事实。',
                          style: TextStyle(fontSize: 11)),
                    ]))),
      if (value.analysisPurpose.isNotEmpty)
        Text('当前考量：${value.analysisPurpose}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      if (value.selectionStrategy.isNotEmpty)
        ExpansionTile(title: const Text('为什么选取这些概念'), children: [
          Text(value.selectionStrategy),
          for (final node in value.concepts
              .where((n) => n.kind == 'concept' && n.role != 'perspective'))
            ListTile(
                title: Text(node.label),
                subtitle: Text(node.selectionReason.isEmpty
                    ? node.definition
                    : node.selectionReason)),
        ]),
      for (final proposition in value.propositions)
        ExpansionTile(
            title: Text(proposition.conclusion),
            subtitle: Text(proposition.verification.status.name == 'unknown' &&
                    !proposition.verification.reason.contains('强化')
                ? '转述分析 · 展开核对原文与命题结构'
                : proposition.verification.reason),
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
            title: const Text('部分结果已保留 · 查看需要补全的内容',
                style: TextStyle(fontSize: 13)),
            children: [
              for (final message in value.issues.map((i) => i.message).toSet())
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(message))
            ]),
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
        if (value.concepts.any((n) => n.kind != 'concept'))
          const Text('可辨认的个别经验', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final node in value.concepts.where((n) => n.kind != 'concept'))
          Card(
              color: const Color(0xffedf3f3),
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(node.label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                            node.status == 'example'
                                ? '教学案例中的个别内容'
                                : '所给材料中的个别内容',
                            style: const TextStyle(fontSize: 12)),
                        Text(node.definition,
                            style: const TextStyle(height: 1.65)),
                        Wrap(spacing: 6, children: [
                          for (final edge in value.hierarchy
                              .where((e) => e.child == node.id))
                            ActionChip(
                                label: Text(
                                    '对应概念：${value.concepts.where((n) => n.id == edge.parent).firstOrNull?.label ?? edge.parent}'),
                                onPressed: () => inspectConcept(
                                    context, edge.parent, value,
                                    onExpand: widget.onExpand,
                                    onOpen: widget.onOpenConcept))
                        ]),
                      ]))),
        const Text('具体材料 → 保留的共同规定 → 被省略的个别细节',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final node in value.concepts.where((n) =>
            n.kind == 'concept' &&
            [n.observed, n.retained, n.omitted].any((s) => s.isNotEmpty)))
          ConceptDetails(
              node: node,
              hierarchy: value.hierarchy,
              concepts: value.concepts,
              onExpand: widget.onExpand,
              imagePath: widget.imagePaths[node.id]),
      ],
      if (active == EpistemicViewKind.circles) ...[
        ConceptMeaningNetwork(
            value: value,
            onExpand: widget.onExpand,
            onOpen: widget.onOpenConcept,
            onRelation: (i) => setState(() => selected = i)),
        if (drawable.isEmpty && widget.onRegenerate != null)
          FilledButton.icon(
              onPressed: widget.onRegenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('按本次考量补全共同尺度与含义圈')),
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
      if (active == EpistemicViewKind.connections)
        ConceptCirclePreview(
            value: value,
            withGrounding: true,
            onExpand: widget.onExpand,
            onOpen: widget.onOpenConcept),
      if (active == EpistemicViewKind.grounds) ...[
        const Text('四重根据 · 按当前材料与相关案例展开',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final root in [
          '生成根据 · 因果与条件',
          '认识根据 · 判断的依据',
          '存在根据 · 时间与空间',
          '行动根据 · 动机'
        ])
          if (value.meaningfulGrounds.any((g) => g.root == root)) ...[
            Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(root,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            for (final ground
                in value.meaningfulGrounds.where((g) => g.root == root))
              GroundRelationView(ground, value: value),
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
      Text(
          scope.basisKind == 'analytic_definition'
              ? '依本次明示的分析性定义 · 区域情形不冒充原文事实'
              : scope.basisKind == 'teaching_example'
                  ? '教学模型 · 不作为原句证明'
                  : scopeStatus(relation.status),
          style: const TextStyle(fontSize: 12)),
      if (!ConceptCircleLayout.build(widget.value)
          .any((g) => !g.geometryConsistent && g.relations.contains(relation)))
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
  final SemanticScope? value;
  const GroundRelationView(this.graph, {super.key, this.value});
  @override
  Widget build(BuildContext context) {
    final title = switch (graph.kind) {
      'evidence' => '认识根据 → 判断',
      'cause' => '生成根据 · 因果条件',
      'time' => ['during', 'simultaneous'].contains(graph.temporalRelation)
          ? '时间 · 同一时段'
          : graph.temporalRelation == 'unspecified'
              ? '时间信息 · 尚未说明时序'
              : '时间 · 先后关系',
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
                  Text(
                      graph.status == 'example'
                          ? '相关教学案例中的关系'
                          : scopeStatus(graph.status),
                      style: const TextStyle(fontSize: 12)),
                  Text(graph.limitation, style: const TextStyle(fontSize: 11)),
                  if (graph.kind == 'evidence' && graph.premises.isNotEmpty)
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(top: 10),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: const Color(0xffaaa0bb)),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('共同作为前提',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    for (final entry in graph.premises.indexed)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                              '${entry.$1 + 1}. ${entry.$2}',
                                              style: const TextStyle(
                                                  height: 1.6))),
                                  ])),
                          const Center(
                              child: SizedBox(
                                  width: 40,
                                  height: 35,
                                  child: CustomPaint(painter: _GroundArrow()))),
                          const Center(
                              child: Text('支持此判断 · 非因果箭头',
                                  style: TextStyle(fontSize: 12))),
                          Center(child: _node(graph.to)),
                        ])
                  else if (graph.kind == 'space')
                    _space()
                  else if (graph.kind == 'time' &&
                      graph.temporalRelation != 'before' &&
                      graph.temporalRelation != 'after')
                    Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [_node(graph.from), _node(graph.to)])
                  else
                    Column(children: [
                      _node(graph.temporalRelation == 'after'
                          ? graph.to
                          : graph.from),
                      SizedBox(
                          height: 42,
                          child: CustomPaint(
                              painter: _GroundArrow(
                                  dashed: graph.kind == 'cause' ||
                                      graph.status == 'unknown'),
                              child: const SizedBox(width: 50))),
                      _node(graph.temporalRelation == 'after'
                          ? graph.from
                          : graph.to),
                    ]),
                  Text(graph.link, style: const TextStyle(height: 1.5)),
                  if (value != null && graph.experienceIds.isNotEmpty)
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final id in graph.experienceIds.where((id) => value!
                          .concepts
                          .any((n) => n.id == id && n.kind != 'concept')))
                        ActionChip(
                            label: Text(
                                '回到具体内容：${value!.concepts.singleWhere((n) => n.id == id).label}'),
                            onPressed: () =>
                                inspectConcept(context, id, value!)),
                    ]),
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
