import 'package:flutter/material.dart';
import 'cognitive_models.dart';
import 'cognitive_preferences.dart';
import 'cognitive_service.dart';
import 'cognitive_store.dart';
import 'cognitive_input_dialog.dart';
import 'cognitive_snapshot_view.dart';
import 'cognitive_mode.dart';
import 'cognitive_evidence_view.dart';
import 'cognitive_usage.dart';
import 'concept_meaning_diagram.dart';
import '../models/quote_insight.dart';

Future<void> showCognitiveAnalysis(
  BuildContext context, {
  required CognitiveSelection selection,
  required CognitiveTask task,
  String Function()? currentText,
  CognitiveService? service,
  CognitiveNote? note,
  GroundLens? initialLens,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xfffaf6ee),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .88,
          child: CognitiveAnalysisSheet(
            selection: selection,
            task: task,
            currentText: currentText,
            service: service,
            initialNote: note,
            initialLens: initialLens,
          ),
        ),
      ),
    );

class CognitiveAnalysisSheet extends StatefulWidget {
  final CognitiveSelection selection;
  final CognitiveTask task;
  final String Function()? currentText;
  final CognitiveService? service;
  final CognitiveNote? initialNote;
  final GroundLens? initialLens;
  const CognitiveAnalysisSheet({
    super.key,
    required this.selection,
    required this.task,
    this.currentText,
    this.service,
    this.initialNote,
    this.initialLens,
  });
  @override
  State<CognitiveAnalysisSheet> createState() => _CognitiveAnalysisSheetState();
}

class _CognitiveAnalysisSheetState extends State<CognitiveAnalysisSheet> {
  late final _service = widget.service ?? CognitiveService();
  CognitiveNote? _note;
  final _originalKey = GlobalKey();
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    CognitivePreferenceStore.instance.load();
    _note = widget.initialNote;
    CognitivePreferenceStore.instance.addListener(_modeChanged);
    if (_note == null) _generate();
  }

  void _modeChanged() {
    if (CognitivePreferenceStore.active && _note == null && !_busy) _generate();
  }

  @override
  void dispose() {
    CognitivePreferenceStore.instance.removeListener(_modeChanged);
    super.dispose();
  }

  Future<void> _generate({bool force = false}) async {
    await CognitivePreferenceStore.instance.load();
    if (!mounted || !CognitivePreferenceStore.active || _busy) return;
    CognitiveUsageStore.instance.track(CognitiveEvent.analysisRequested);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final note = await _service.analyze(
        widget.selection,
        widget.task,
        force: force,
      );
      if (mounted) setState(() => _note = note);
    } catch (e) {
      CognitiveUsageStore.instance.track(
        e is FormatException
            ? CognitiveEvent.invalidOutput
            : CognitiveEvent.requestFailed,
      );
      if (mounted)
        setState(() => _error = e is FormatException
            ? '分析尚未达到要求：${e.message}。原文与原注释保留。'
            : '暂未完成分析。请检查网络和全局 AI 配置后重试；原文保持不变。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(CognitiveNote note, {CognitiveEvent? event}) async {
    if (!CognitivePreferenceStore.active) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.store.save(note);
      if (event != null) CognitiveUsageStore.instance.track(event);
      if (mounted) setState(() => _note = note);
    } catch (_) {
      CognitiveUsageStore.instance.track(CognitiveEvent.storageFailed);
      if (mounted) setState(() => _error = '注释暂未保存，请重试。原文不受影响。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final note = _note;
    if (note == null) return;
    setState(() => _busy = true);
    try {
      await _service.store.delete(note);
      CognitiveUsageStore.instance.track(
        note.accepted ? CognitiveEvent.deleted : CognitiveEvent.skipped,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = '注释暂未删除，请重试。';
        });
    }
  }

  Future<void> _revise() async {
    final note = _note;
    if (note == null) return;
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => CognitiveInputDialog(
        title: '根据新材料修订判断',
        description: '新材料是你的报告，尚未外部核实。旧判断和原始记录会保留。',
        submitLabel: '保存修订',
        fields: [
          const CognitiveInputField('evidence', '具体的新材料或反例'),
          CognitiveInputField(
            'judgment',
            '修订后的判断',
            initialValue: note.currentJudgment,
          ),
          const CognitiveInputField('reason', '为什么改变判断（可选）', required: false),
        ],
      ),
    );
    if (values != null && mounted) {
      await _save(
        note.revise(
          judgment: values['judgment']!,
          evidence: values['evidence']!,
          reason: values['reason']!,
        ),
        event: CognitiveEvent.revised,
      );
    }
  }

  String get _title => switch (widget.task) {
        CognitiveTask.diary => '区分事实与解释',
        CognitiveTask.concept => '概念与具体经验',
        CognitiveTask.calibration => '还有哪些可能',
        CognitiveTask.reflection => '认识闭环',
        CognitiveTask.review => '认识回顾',
      };
  Widget _section(String title, String value, {IconData? icon}) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(value, style: const TextStyle(height: 1.65)),
            ],
          ),
        );

  @override
  Widget build(
    BuildContext context,
  ) =>
      ValueListenableBuilder<CognitivePreferences>(
        valueListenable: CognitivePreferenceStore.instance,
        builder: (context, prefs, _) {
          if (!CognitivePreferenceStore.active) {
            return CognitiveDisabledView(
              originalText: widget.task == CognitiveTask.review
                  ? null
                  : widget.selection.text,
            );
          }
          final note = _note;
          final stale = widget.currentText != null &&
              !widget.selection.matches(widget.currentText!());
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭分析',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Card(
                  key: _originalKey,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          note?.modelInfo == 'existing_record_snapshot'
                              ? '原记录快照 · 保持原样'
                              : '原文 · 保持原样',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if (widget.task == CognitiveTask.review)
                          for (final value in (insightObject(
                                widget.selection.text,
                              )['authorized_snapshots'] as List? ??
                              const []))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: CognitiveSnapshotView(
                                snapshot: insightObject(value),
                              ),
                            )
                        else
                          SelectableText(
                            widget.selection.text,
                            style: const TextStyle(height: 1.7),
                          ),
                      ],
                    ),
                  ),
                ),
                if (stale)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('原文已变化，这条注释的位置已失效。请返回原文重新选择；此处保留旧注释供回顾。'),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                if (!_busy && note == null && !stale)
                  TextButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试分析'),
                  ),
                if (note != null) ...[
                  Text(
                    note.accepted
                        ? '已采纳的注释 · 仍是一种理解'
                        : note.modelInfo == 'existing_record_snapshot'
                            ? '记录中的暂定理解 · 可修改或拒绝'
                            : 'AI 暂定理解 · 可修改或拒绝',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton.icon(
                    onPressed:
                        _busy || stale ? null : () => _generate(force: true),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('按新方法重新分析'),
                  ),
                  if (widget.initialLens case final lens?)
                    _section(
                      lens.label,
                      note.analysis.lenses[lens]?.isNotEmpty == true
                          ? note.analysis.lenses[lens]!
                          : '尚不能确定。${lens.question}',
                    ),
                  if (widget.task == CognitiveTask.diary) ...[
                    const SizedBox(height: 12),
                    for (final entry in note.analysis.spans.indexed)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SelectableText(
                                entry.$2.text,
                                style: const TextStyle(height: 1.6),
                              ),
                              DropdownButton<StatementKind>(
                                isExpanded: true,
                                value: entry.$2.kind,
                                items: StatementKind.values
                                    .map(
                                      (kind) => DropdownMenuItem(
                                        value: kind,
                                        child: Text(kind.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _busy || stale
                                    ? null
                                    : (kind) {
                                        if (kind == null ||
                                            kind == entry.$2.kind) return;
                                        final spans = [...note.analysis.spans];
                                        spans[entry.$1] =
                                            entry.$2.withKind(kind);
                                        _save(
                                          note.copyWith(
                                            analysis: note.analysis.withSpans(
                                              spans,
                                            ),
                                            classificationHistory: [
                                              ...note.classificationHistory,
                                              {
                                                'at': DateTime.now()
                                                    .toUtc()
                                                    .toIso8601String(),
                                                'analysis':
                                                    note.analysis.toJson(),
                                              },
                                            ],
                                          ),
                                          event: CognitiveEvent
                                              .classificationChanged,
                                        );
                                      },
                              ),
                              if (entry.$2.reason.isNotEmpty)
                                Text(
                                  entry.$2.reason,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.5),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (note.classificationHistory.isNotEmpty)
                      TextButton(
                        onPressed: _busy || stale
                            ? null
                            : () {
                                final history = [...note.classificationHistory];
                                final previous = history.removeLast();
                                _save(
                                  note.copyWith(
                                    analysis: CognitiveAnalysis.fromJson(
                                      previous['analysis'],
                                      note.selection.text,
                                    ),
                                    classificationHistory: history,
                                  ),
                                  event: CognitiveEvent.classificationUndone,
                                );
                              },
                        child: const Text('撤销上一次分类修改'),
                      ),
                  ],
                  if (widget.task == CognitiveTask.reflection)
                    CognitiveLoopSteps(note: note),
                  _section('一种理解', note.currentJudgment),
                  if (note.analysis.concepts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: note.analysis.concepts
                          .map((e) => Chip(label: Text(e)))
                          .toList(),
                    ),
                  ],
                  ConceptAnalysisView(
                    abstractions: note.analysis.abstractions,
                    scopes: note.analysis.scopes,
                  ),
                  for (final example in note.analysis.examples)
                    _section(
                      '具体示例 · 模拟情境',
                      '${example.situation}\n对应：${example.connection}\n局限：${example.boundary.isEmpty ? '尚需结合具体条件检验' : example.boundary}',
                    ),
                  _section('哪里相同', note.analysis.common),
                  _section('关键区别', note.analysis.difference),
                  _section('适用范围与边界', note.analysis.boundary),
                  _section('可能的反例', note.analysis.counterExample),
                  _section(
                    '可以怎样检验',
                    note.analysis.questions.map((q) => '• $q').join('\n'),
                  ),
                  if (prefs.grounds) ...[
                    CognitiveEvidenceView(
                      note: note,
                      onOriginal: () {
                        final originalContext = _originalKey.currentContext;
                        if (originalContext != null)
                          Scrollable.ensureVisible(
                            originalContext,
                            duration: prefs.reduceMotion ||
                                    MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 240),
                          );
                      },
                    ),
                    if (widget.task == CognitiveTask.diary)
                      for (final lens in GroundLens.values)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          expansionAnimationStyle: prefs.reduceMotion ||
                                  MediaQuery.disableAnimationsOf(context)
                              ? AnimationStyle.noAnimation
                              : const AnimationStyle(
                                  duration: Duration(milliseconds: 250),
                                ),
                          leading: Icon(_lensIcon(lens)),
                          initiallyExpanded: widget.initialLens == lens,
                          title: Text(lens.label),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    note.analysis.lenses[lens]?.isNotEmpty ==
                                            true
                                        ? note.analysis.lenses[lens]!
                                        : '尚不能确定',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(lens.question),
                                ],
                              ),
                            ),
                          ],
                        ),
                  ],
                  _section('仍然未知', note.analysis.unknown),
                  if (prefs.evidenceReminders)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text('有新材料或反例时，可以保留原判断并记录修订。'),
                    ),
                  if (note.revisions.isNotEmpty) ...[
                    const Divider(height: 32),
                    const Text(
                      '判断修订记录',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final entry in note.revisions.indexed)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                  '第 ${entry.$1 + 1} 次 · ${entry.$2.createdAt}'),
                              Text('原判断：${entry.$2.previous}'),
                              CognitiveChangedText(
                                before: entry.$2.previous,
                                after: entry.$2.judgment,
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                child: SelectableText(
                                  '新材料（用户报告）：${entry.$2.evidence}',
                                ),
                              ),
                              if (entry.$2.reason.isNotEmpty)
                                Text('改判理由：${entry.$2.reason}'),
                              TextButton(
                                onPressed: _busy || stale
                                    ? null
                                    : () => _save(
                                          note.revise(
                                            judgment: entry.$2.previous,
                                            evidence:
                                                '用户重新审视第 ${entry.$1 + 1} 次修订前的判断',
                                            reason: '手动回退，保留全部修订记录',
                                          ),
                                          event: CognitiveEvent.rolledBack,
                                        ),
                                child: const Text('回退到此前判断'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _busy || (stale && !note.accepted)
                            ? null
                            : () => _save(
                                  note.copyWith(accepted: !note.accepted),
                                  event: note.accepted
                                      ? CognitiveEvent.acceptanceUndone
                                      : CognitiveEvent.accepted,
                                ),
                        child: Text(note.accepted ? '撤销采纳' : '采纳这条注释'),
                      ),
                      OutlinedButton(
                        onPressed: _busy || stale ? null : _revise,
                        child: const Text('新证据与修订'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _delete,
                        child: Text(note.accepted ? '删除注释' : '拒绝并删除'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
}

IconData _lensIcon(GroundLens lens) => switch (lens) {
      GroundLens.time => Icons.schedule,
      GroundLens.space => Icons.place_outlined,
      GroundLens.cause => Icons.hub_outlined,
      GroundLens.evidence => Icons.fact_check_outlined,
      GroundLens.motive => Icons.favorite_border,
    };

class CognitiveChangedText extends StatelessWidget {
  final String before, after;
  const CognitiveChangedText({
    super.key,
    required this.before,
    required this.after,
  });
  @override
  Widget build(BuildContext context) {
    final old = before.characters.toList(), next = after.characters.toList();
    var prefix = 0, suffix = 0;
    while (prefix < old.length &&
        prefix < next.length &&
        old[prefix] == next[prefix]) {
      prefix++;
    }
    while (suffix < old.length - prefix &&
        suffix < next.length - prefix &&
        old[old.length - suffix - 1] == next[next.length - suffix - 1]) {
      suffix++;
    }
    return Semantics(
      label: '新判断：$after',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: '新判断：'),
            TextSpan(text: next.take(prefix).join()),
            TextSpan(
              text: next.sublist(prefix, next.length - suffix).join(),
              style: TextStyle(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: next.skip(next.length - suffix).join()),
          ],
        ),
      ),
    );
  }
}

class CognitiveLoopSteps extends StatelessWidget {
  final CognitiveNote note;
  const CognitiveLoopSteps({super.key, required this.note});
  @override
  Widget build(BuildContext context) {
    final steps = [
      ('观察经验', note.selection.text),
      (
        '抽象概念',
        note.analysis.concepts.isEmpty
            ? '概念尚待澄清，先保留具体经验。'
            : note.analysis.concepts.join('、'),
      ),
      (
        '判断与根据',
        '${note.currentJudgment}\n最初根据：${note.analysis.basis}'
            '${note.revisions.isEmpty ? '' : '\n修订材料：${note.revisions.last.evidence}'}',
      ),
      ('回到经验检验', note.analysis.questions.join('\n')),
      (
        '修订认识',
        note.revisions.isEmpty
            ? '有新材料时，可以保留旧判断并记录修订。'
            : note.revisions.last.reason.isEmpty
                ? note.revisions.last.evidence
                : note.revisions.last.reason,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          for (final entry in steps.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: [
                  Colors.amber.shade100,
                  Colors.blue.shade100,
                  Colors.teal.shade100,
                  Colors.orange.shade100,
                  Colors.purple.shade100,
                ][entry.$1],
                child: Text('${entry.$1 + 1}'),
              ),
              title: Text(entry.$2.$1),
              subtitle: Text(
                entry.$2.$2,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showCognitiveNotes(
  BuildContext context, {
  required String module,
  required String recordId,
  String Function()? currentText,
  CognitiveStore? store,
}) async {
  final repository = store ?? CognitiveStore();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CognitiveNotesList(
      module: module,
      recordId: recordId,
      currentText: currentText,
      store: repository,
    ),
  );
}

class _CognitiveNotesList extends StatefulWidget {
  final String module, recordId;
  final String Function()? currentText;
  final CognitiveStore store;
  const _CognitiveNotesList({
    required this.module,
    required this.recordId,
    required this.currentText,
    required this.store,
  });
  @override
  State<_CognitiveNotesList> createState() => _CognitiveNotesListState();
}

class _CognitiveNotesListState extends State<_CognitiveNotesList> {
  late Future<List<CognitiveNote>> _notes = widget.store.forRecord(
    widget.module,
    widget.recordId,
  );
  @override
  Widget build(BuildContext context) => CognitiveMode(
        fallback: const CognitiveDisabledView(),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: FutureBuilder<List<CognitiveNote>>(
              future: _notes,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _notes = widget.store.forRecord(
                          widget.module,
                          widget.recordId,
                        );
                      }),
                      child: const Text('注释暂未读取，点击重试'),
                    ),
                  );
                final notes = snapshot.data ?? [];
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      '认识注释',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (notes.isEmpty)
                      const Text('尚无注释。选中原文中的一段文字，可选择“区分事实与解释”。'),
                    for (final note in notes)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          note.selection.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          widget.currentText != null &&
                                  !note.selection.matches(widget.currentText!())
                              ? '原文已变化 · 请重新选择'
                              : note.accepted
                                  ? '已采纳 · 一种理解'
                                  : '待确认 · AI 暂定理解',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await showCognitiveAnalysis(
                            context,
                            selection: note.selection,
                            task: note.task,
                            note: note,
                            currentText: widget.currentText,
                            service: CognitiveService(store: widget.store),
                          );
                          if (mounted)
                            setState(() {
                              _notes = widget.store.forRecord(
                                widget.module,
                                widget.recordId,
                              );
                            });
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}

class CognitiveAction extends StatelessWidget {
  final String label;
  final CognitiveTask task;
  final CognitiveSelection selection;
  final String Function()? currentText;
  const CognitiveAction({
    super.key,
    required this.label,
    required this.task,
    required this.selection,
    this.currentText,
  });
  @override
  Widget build(BuildContext context) {
    CognitivePreferenceStore.instance.load();
    return ValueListenableBuilder<CognitivePreferences>(
      valueListenable: CognitivePreferenceStore.instance,
      builder: (context, prefs, _) =>
          !CognitivePreferenceStore.enabledInBuild || !prefs.enabled
              ? const SizedBox.shrink()
              : TextButton.icon(
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: Text(label),
                  onPressed: () => showCognitiveAnalysis(
                    context,
                    selection: selection,
                    task: task,
                    currentText: currentText,
                  ),
                ),
    );
  }
}
