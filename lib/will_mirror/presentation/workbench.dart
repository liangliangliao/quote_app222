import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../ai/protocol.dart';
import '../ai/workbench_pass.dart';
import '../application/controller.dart';
import '../domain/model.dart';
import '../domain/ranking.dart';
import '../domain/rules.dart';
import 'design.dart';
import 'sheets.dart';
import 'tide.dart';
import 'visuals.dart';
import 'journey_views.dart';
import 'experience_cards.dart';

part 'workbench_analysis.dart';
part 'workbench_action.dart';
part 'workbench_review.dart';

class CaseWorkbench extends StatefulWidget {
  const CaseWorkbench(
      {super.key,
      required this.controller,
      required this.caseId,
      this.startAnalysis = false,
      this.initialStep,
      this.notificationStale = false,
      this.focusNodeId});
  final MirrorController controller;
  final String caseId;
  final bool startAnalysis, notificationStale;
  final int? initialStep;
  final String? focusNodeId;
  @override
  State<CaseWorkbench> createState() => _CaseWorkbenchState();
}

class _CaseWorkbenchState extends State<CaseWorkbench> {
  String? _focusedReframeId;
  String? _focusedPrincipleId;
  bool _expandedIssue = false;
  final _stepKeys = List.generate(7, (_) => GlobalKey());
  final _scroll = ScrollController();
  final _tts = FlutterTts();
  bool _rehearsing = false;
  String _sceneState = '';
  void _checkScene() {
    final file = c.file(widget.caseId);
    final signature =
        '${file?.selectedRouteId}/${file?.selectedMotiveIds.join(',')}/${file?.latest(NodeKind.scene)?.id}/${file?.latest(NodeKind.scene)?.status}';
    if (_rehearsing && signature != _sceneState) {
      _tts.stop();
      _rehearsing = false;
      if (mounted) Navigator.of(context).pop();
    }
    _sceneState = signature;
  }

  MirrorController get c => widget.controller;
  CaseFile get f => c.file(widget.caseId)!;
  int get _active =>
      f.retrospective && f.stage == CaseStage.newCase ? 0 : f.step;
  bool get _busy => c.busyCaseId == widget.caseId;
  @override
  void initState() {
    super.initState();
    _checkScene();
    c.addListener(_checkScene);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.initialStep != null) {
        await _go(widget.initialStep!);
      } else {
        _scrollTo(f.step);
      }
      if (widget.notificationStale && mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('这条提醒对应的预案已变更，请以课题的当前记录为准。')));
      if (widget.startAnalysis && mounted) await _analyze();
      if (widget.focusNodeId != null && mounted) {
        final node = c.resolve(widget.focusNodeId!);
        if (node != null && node.usable)
          await showNodeDetails(context, c, node);
      }
    });
  }

  @override
  void dispose() {
    c.removeListener(_checkScene);
    _scroll.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action) =>
      runUiAction(context, action);
  void _focusReframe(String id) => setState(() => _focusedReframeId = id);
  void _focusPrinciple(String id) => setState(() => _focusedPrincipleId = id);
  Future<void> _go(int step) async {
    await _act(() => c.advance(widget.caseId, step));
    if (!mounted) return;
    setState(() {});
    _scrollTo(step);
  }

  void _scrollTo(int step) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _stepKeys[step].currentContext;
      if (target != null)
        Scrollable.ensureVisible(target,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            alignment: .02);
    });
  }

  Future<void> _analyze([AnalysisStage? stage, Json options = const {}]) async {
    final pass = stage == null && options.isEmpty ? passForStep(_active) : null;
    final request = {
      ...(pass == null ? options : {'workbenchPass': pass.name}),
      'requireClarity': true,
    };
    final consent = await askAnalysisConsent(
      context,
      c,
      f,
      action: stage == null
          ? options['fullWorkflow'] == true
              ? '重新分析整件事'
              : '看清当前这一步'
          : stageTitles[stage]!,
      scope: options['fullWorkflow'] == true
          ? '从新事实重新检查欲求、走法、理由、认识和路线条件，保留原来历史。'
          : pass == null
              ? null
              : switch (pass) {
                  WorkbenchPass.understand =>
                    '只还原事实与欲求候选，先给出可核对的理解。后续步骤由你选择继续。',
                  WorkbenchPass.reasons => '生成不同走法和正反理由，后台补全候选并整理最多五条优先理由。',
                  WorkbenchPass.cognition => '检验旧认识、提出其他解释并检查反证。',
                  WorkbenchPass.routes => '比较现有路线的欲求得失、能力、难度与现实限制。',
                },
    );
    if (consent == null || !mounted) return;
    await _act(() => c.analyze(consent, onlyStage: stage, options: request));
    if (mounted && c.notice != null)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(c.notice!)));
  }

  Future<void> _continue(int step) async {
    await _go(step);
    if (!mounted || stepHasAnalysis(f, step)) return;
    await _analyze();
  }

  Future<void> _evidence({String category = 'condition'}) async {
    final result = await askText(context,
        title: category == 'counter' ? '补充相反证据' : '补充一条现实记录',
        questions: [
          const TextQuestion('text', '发生了什么，或者刚核实了什么？',
              required: true, lines: 3)
        ],
        explanation: '新发现会保留自己的记录时间，不会写回事前。');
    if (result != null)
      await _act(() => c.addEvidence(
            f.id,
            result['text']!,
            category: category,
            materialChange: f.current(NodeKind.route).isNotEmpty &&
                {'condition', 'correction', 'counter'}.contains(category),
          ));
  }

  void _details(MirrorNode node) => showNodeDetails(context, c, node);
  Widget _sourceLink(MirrorNode node, {String label = '依据、反证与适用条件'}) =>
      TextButton.icon(
          onPressed: () => _details(node),
          icon: const Icon(Icons.notes_outlined, size: 17),
          label:
              Text('${contentSourceLabel(node, resolve: c.resolve)} · $label'));
  Widget _heading(String text, [String? body]) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: Theme.of(context).textTheme.titleLarge),
        if (body != null) ...[const SizedBox(height: 7), Text(body)],
        const SizedBox(height: 16)
      ]);
  Widget _primary(String text, VoidCallback? onPressed,
          {IconData icon = Icons.arrow_forward}) =>
      Padding(
          padding: const EdgeInsets.only(top: 18),
          child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon, size: 18),
                  label: Text(text))));
  Widget _nodeList(NodeKind kind, {String? title, int? limit}) {
    final nodes = f.current(kind);
    if (nodes.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) ...[
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium)
      ],
      for (final node in nodes.take(limit ?? nodes.length))
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(nodeTitle(node)),
            subtitle: Text(
                '${contentSourceLabel(node, resolve: c.resolve)} · ${statusLabel(node.status)}'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _details(node))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          if (c.file(widget.caseId) == null)
            return Scaffold(
                appBar: AppBar(title: const Text('课题')),
                body: const Center(child: Text('这份课题已删除。')));
          final theme = Theme.of(context);
          final active = _active;
          return Scaffold(
              appBar: AppBar(
                  title: const Text('这件事的工作台'),
                  actions: [
                    IconButton(
                        tooltip: '补充事实',
                        onPressed: () => _evidence(),
                        icon: const Icon(Icons.add_comment_outlined)),
                    PopupMenuButton<String>(
                        tooltip: '课题操作',
                        onSelected: _menu,
                        itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'reanalyze',
                                  child: Text('按新事实重新分析整件事')),
                              PopupMenuItem(
                                  value: 'history', child: Text('查看真实历程与版本')),
                              PopupMenuItem(
                                  value: 'observation',
                                  child: Text('直接记录已经发生的事')),
                              PopupMenuItem(
                                  value: 'pause', child: Text('暂缓这个课题')),
                              PopupMenuItem(
                                  value: 'cancel', child: Text('关闭这个课题的提醒')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('删除这个课题'))
                            ])
                  ],
                  bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(43),
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                          child: Row(children: [
                            MirrorTag(f.phaseLabel,
                                icon: Icons.circle_outlined, emphasis: true),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text('同一课题 · 第 ${f.cycle} 轮',
                                    style: theme.textTheme.bodySmall)),
                            if (_busy)
                              const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                          ])))),
              body: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(f.issue,
                                maxLines: _expandedIssue ? null : 3,
                                overflow: _expandedIssue
                                    ? null
                                    : TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge)),
                        if (f.issue.length > 80)
                          Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                  onPressed: () => setState(
                                      () => _expandedIssue = !_expandedIssue),
                                  child: Text(
                                      _expandedIssue ? '收起原话' : '展开完整原话'))),
                        const SizedBox(height: 18),
                        if (!_busy &&
                            f.current(NodeKind.route).any(
                                (r) => EvidenceRules.routeNeedsReview(r, f)))
                          MirrorCard(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                const Text('现实条件有新记录，旧走法与理由需要重新核实。'),
                                TextButton(
                                    onPressed: () =>
                                        _analyze(null, {'fullWorkflow': true}),
                                    child: const Text('根据新事实重新分析整件事')),
                              ])),
                        if (_busy)
                          MirrorCard(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: .5),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.progressTitle,
                                        style: theme.textTheme.titleMedium),
                                    const SizedBox(height: 6),
                                    Text(c.progressDetail),
                                    const SizedBox(height: 12),
                                    const LinearProgressIndicator(),
                                    TextButton(
                                        onPressed: c.stop,
                                        child: const Text('停止本次分析，保留已有结果'))
                                  ])),
                        if (c.error != null && !_busy)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: MirrorEmpty(
                                  title: '这一步暂时没完成',
                                  body: c.error!,
                                  icon: Icons.cloud_off_outlined,
                                  action: TextButton(
                                      onPressed: () => _analyze(c.retryStage, {
                                            ...c.retryOptions,
                                            'resumeWorkflow': c.retryWorkflow
                                          }),
                                      child: const Text('重试这一步')))),
                        CaseJourneyHeader(
                          file: f,
                          step: active,
                          onStep: (step) => _go(step),
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          key: _stepKeys[active],
                          padding: const EdgeInsets.only(bottom: 14),
                          child: MirrorCard(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    MirrorTag(
                                      '${active + 1}'.padLeft(2, '0'),
                                      emphasis: true,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(_stepTitles[active],
                                          style: theme.textTheme.titleSmall),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                switch (active) {
                                  0 => _understanding(),
                                  1 => _motives(),
                                  2 => _cognition(),
                                  3 => _routes(),
                                  4 => _preparation(),
                                  5 => _field(),
                                  _ => _review()
                                }
                              ],
                            ),
                          ),
                        ),
                        ExpansionTile(
                          key: const ValueKey('mirror-case-overview'),
                          tilePadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          title: const Text('回看这件事的全貌与已有记录'),
                          children: [
                            for (var i = 0; i < 7; i++)
                              ListTile(
                                leading: Text('${i + 1}'.padLeft(2, '0')),
                                title: Text(_stepTitles[i]),
                                subtitle: Text(
                                  _stepSummary(i),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _go(i),
                              ),
                          ],
                        ),
                        if (!_busy)
                          TextButton.icon(
                              onPressed: () => _evidence(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('事实有变化，补充一条记录')),
                        const SizedBox(height: 10),
                        Text('未知可以保留，路线可以改变。你的反馈会修订这里的认识。',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall),
                      ])));
        });
  }

  static const _stepTitles = [
    '看清这件事',
    '看见正反理由',
    '检验新的认识',
    '比较实际走法',
    '为那个时刻做准备',
    '真正的条件出现了吗',
    '回望事实，带走经验'
  ];
  String _stepSummary(int i) {
    final source = switch (i) {
      0 => f.latest(NodeKind.understanding),
      1 => f.latest(NodeKind.recommendation) ?? f.latest(NodeKind.motive),
      2 => f.latest(NodeKind.reframe),
      3 => f.node(f.selectedRouteId) ?? f.latest(NodeKind.routeFit),
      4 => f.latest(NodeKind.plan),
      5 => f.latest(NodeKind.triggerCheck),
      _ => f.latest(NodeKind.observation),
    };
    final summary = switch (i) {
      0 => f.latest(NodeKind.understanding)?.text('summary') ?? '从你的原话开始',
      1 => f.current(NodeKind.motive).isEmpty
          ? '还没有生成候选'
          : '${MotiveRanking.distinct(f.current(NodeKind.motive)).length} 条候选 · ${f.selectedMotiveIds.length} 条已选理由',
      2 => f.current(NodeKind.reframe).isEmpty
          ? '原来的认识也可能正确'
          : '${f.current(NodeKind.reframe).length} 项可检验的认识',
      3 => f.selectedRouteId == null
          ? '比较收益、代价与现实条件'
          : f.node(f.selectedRouteId)?.text('title') ?? '路线需要复核',
      4 => f.latest(NodeKind.plan)?.text('ifThen') ?? '安排可真实执行的条件',
      5 => f.latest(NodeKind.triggerCheck) == null
          ? '提醒到时仍需核实条件'
          : humanValue(f.latest(NodeKind.triggerCheck)!.text('state')),
      _ => f.latest(NodeKind.observation) == null
          ? '等待真实反馈'
          : humanValue(f.latest(NodeKind.observation)!.text('actionState')),
    };
    return source == null
        ? summary
        : '${contentSourceLabel(source, resolve: c.resolve)} · $summary';
  }

  Future<void> _menu(String action) async {
    if (action == 'reanalyze') {
      await _analyze(null, {'fullWorkflow': true});
      return;
    }
    if (action == 'pause') {
      await _act(() => c.pause(f.id));
      return;
    }
    if (action == 'cancel') {
      await _act(() => c.cancelReminders(f.id));
      return;
    }
    if (action == 'observation') {
      await _go(6);
      return;
    }
    if (action == 'history') {
      await _journey();
      return;
    }
    if (action == 'delete') {
      final result = await chooseOption(context,
          title: '删除这份课题？',
          explanation: '原始内容、历史快照和相关派生内容会删除，其他课题中依赖它的解释将停止使用。',
          options: {'keep': '保留', 'delete': '删除课题与相关资料'});
      if (result == 'delete') {
        await _act(() => c.deleteCase(f.id));
        if (mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _journey() async {
    final versions = await c.store.history(f.id);
    if (!mounted) return;
    await mirrorSheet<void>(context,
        title: '同一个课题，真实走过的历程',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('准备、决意、尝试与结果各自留存。记录的先后本身不能证明因果。'),
          const SizedBox(height: 14),
          JourneyTimeline(file: f, onNode: _details),
          const Divider(),
          ExpansionTile(title: Text('${versions.length} 个保存版本'), children: [
            for (final version in versions.take(30))
              ListTile(
                  title: Text('版本 ${version.revision} · ${version.phaseLabel}'),
                  subtitle: Text(timeLabel(version.updatedAt)),
                  onTap: () => mirrorSheet<void>(context,
                      title: '版本 ${version.revision} 的记录',
                      child: Column(children: [
                        for (final n in version.nodes.where((n) => n.usable))
                          ListTile(
                              title: Text(nodeTitle(n),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(kindLabel(n.kind)),
                              onTap: () => _details(n))
                      ])))
          ]),
        ]));
  }
}
