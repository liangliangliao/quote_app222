import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../ai/protocol.dart';
import '../application/controller.dart';
import '../domain/model.dart';
import '../domain/ranking.dart';
import '../domain/rules.dart';
import 'design.dart';
import 'sheets.dart';
import 'tide.dart';
import 'visuals.dart';

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
  final Set<int> _opened = {};
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
  Future<void> _go(int step) async {
    await _act(() => c.advance(widget.caseId, step));
    if (!mounted) return;
    setState(() => _opened.clear());
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
    final consent = await askAnalysisConsent(context, c, f,
        action: stage == null ? '开始分析' : stageTitles[stage]!);
    if (consent == null || !mounted) return;
    await _act(() => c.analyze(consent, onlyStage: stage, options: options));
    if (mounted && c.notice != null)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(c.notice!)));
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
      await _act(
          () => c.addEvidence(f.id, result['text']!, category: category));
  }

  void _details(MirrorNode node) => showNodeDetails(context, c, node);
  Widget _sourceLink(MirrorNode node, {String label = '依据、反证与适用条件'}) =>
      TextButton.icon(
          onPressed: () => _details(node),
          icon: const Icon(Icons.notes_outlined, size: 17),
          label: Text(label));
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
                '${sourceLabel(node.origin)} · ${statusLabel(node.status)}'),
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
                                style: theme.textTheme.titleLarge)),
                        const SizedBox(height: 18),
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
                                  title: '本次分析尚未完成',
                                  body: c.error!,
                                  icon: Icons.cloud_off_outlined,
                                  action: TextButton(
                                      onPressed: () => _analyze(c.retryStage,
                                          {'resumeWorkflow': c.retryWorkflow}),
                                      child: const Text('检查资料后重试')))),
                        for (var i = 0; i < 7; i++)
                          Padding(
                              key: _stepKeys[i],
                              padding: const EdgeInsets.only(bottom: 14),
                              child: MirrorCard(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        InkWell(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            onTap: () => setState(() {
                                                  if (_opened.contains(i)) {
                                                    _opened.remove(i);
                                                  } else {
                                                    _opened.add(i);
                                                  }
                                                }),
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6),
                                                child: Row(children: [
                                                  Container(
                                                      width: 31,
                                                      height: 31,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                          color: i == active
                                                              ? theme
                                                                  .colorScheme
                                                                  .primary
                                                              : theme
                                                                  .colorScheme
                                                                  .surfaceContainer,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  10)),
                                                      child: Text('${i + 1}'.padLeft(2, '0'),
                                                          style: TextStyle(
                                                              color: i == active
                                                                  ? theme
                                                                      .colorScheme
                                                                      .onPrimary
                                                                  : theme
                                                                      .colorScheme
                                                                      .onSurface,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight.w700))),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                        Text(_stepTitles[i],
                                                            style: theme
                                                                .textTheme
                                                                .titleSmall),
                                                        if (i != active &&
                                                            !_opened
                                                                .contains(i))
                                                          Text(_stepSummary(i),
                                                              style: theme
                                                                  .textTheme
                                                                  .bodySmall,
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis)
                                                      ])),
                                                  Icon(
                                                      i == active ||
                                                              _opened
                                                                  .contains(i)
                                                          ? Icons
                                                              .keyboard_arrow_up
                                                          : Icons
                                                              .keyboard_arrow_down,
                                                      size: 20)
                                                ]))),
                                        if (i == active ||
                                            _opened.contains(i)) ...[
                                          const SizedBox(height: 18),
                                          switch (i) {
                                            0 => _understanding(),
                                            1 => _motives(),
                                            2 => _cognition(),
                                            3 => _routes(),
                                            4 => _preparation(),
                                            5 => _field(),
                                            _ => _review()
                                          }
                                        ],
                                      ]))),
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
    '理解这次取舍',
    '看见正反理由',
    '检验新的认识',
    '比较实际走法',
    '为那个时刻做准备',
    '真正的条件出现了吗',
    '回望事实，带走经验'
  ];
  String _stepSummary(int i) => switch (i) {
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
  Future<void> _menu(String action) async {
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
