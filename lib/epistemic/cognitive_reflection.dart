import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import 'cognitive_models.dart';
import 'cognitive_preferences.dart';
import 'cognitive_sheet.dart';
import 'cognitive_store.dart';
import 'cognitive_record_adapter.dart';
import 'cognitive_input_dialog.dart';
import 'cognitive_service.dart';
import 'cognitive_usage.dart';

class CognitiveReflectionCard extends StatefulWidget {
  final String module, recordId, observation, judgment, basis;
  final List<String> concepts;
  final VoidCallback? onNewEvidence;
  final String newEvidence;
  final CognitiveStore? store;
  const CognitiveReflectionCard(
      {super.key,
      required this.module,
      required this.recordId,
      required this.observation,
      required this.judgment,
      required this.basis,
      this.concepts = const [],
      this.onNewEvidence,
      this.newEvidence = '',
      this.store});
  CognitiveNote get snapshot => CognitiveNote(
      id: insightHash([module, recordId, observation, judgment, basis]),
      task: CognitiveTask.reflection,
      selection: CognitiveSelection.fromText(
          module: module,
          recordId: recordId,
          title: '认识闭环',
          fullText: observation),
      analysis: CognitiveAnalysis(
          summary: judgment,
          basis: basis,
          concepts: concepts,
          boundary: '这是当前记录中的理解，仍需具体经验检验；原始记录与行动方案分别保留。',
          questions: const ['什么新材料会让这个判断改变？']),
      modelInfo: 'existing_record_snapshot',
      createdAt: DateTime.now().toUtc().toIso8601String());
  @override
  State<CognitiveReflectionCard> createState() =>
      _CognitiveReflectionCardState();
}

class _CognitiveReflectionCardState extends State<CognitiveReflectionCard> {
  bool _saving = false;
  Future<void> _save(BuildContext context) async {
    if (_saving ||
        !CognitivePreferenceStore.active ||
        widget.observation.trim().isEmpty ||
        widget.judgment.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final store = widget.store ?? CognitiveStore();
      final candidate = widget.snapshot;
      final adapter = CognitiveRecordAdapter(store: store);
      final proposal = await adapter.capture(candidate);
      var note = proposal.previous;
      if (!context.mounted || !CognitivePreferenceStore.active) return;
      if (proposal.requiresRevision) {
        final values = await showDialog<Map<String, String>>(
            context: context,
            builder: (_) => CognitiveInputDialog(
                    title: '把当前判断接入修订记录',
                    description:
                        '此前：${note.currentJudgment}\n当前记录给出：${candidate.analysis.summary}\n'
                        '请确认新增或纠正的材料；原始记录和此前判断均保留，材料尚未外部核对。',
                    submitLabel: '保存这次改判',
                    fields: [
                      CognitiveInputField('evidence', '这次新增或纠正的具体材料',
                          initialValue: widget.newEvidence),
                      CognitiveInputField('judgment', '本次判断',
                          initialValue: candidate.analysis.summary),
                      const CognitiveInputField('reason', '改判理由（可选）',
                          required: false),
                    ]));
        if (values == null ||
            !context.mounted ||
            !CognitivePreferenceStore.active) return;
        if (widget.snapshot.id != candidate.id)
          throw StateError('当前业务记录已更新，请重新查看后再保存。');
        note = await adapter.revise(proposal,
            judgment: values['judgment']!,
            evidence: values['evidence']!,
            reason: values['reason']!);
        CognitiveUsageStore.instance.track(CognitiveEvent.revised);
      }
      if (context.mounted)
        await showCognitiveAnalysis(context,
            selection: note.selection,
            task: note.task,
            note: note,
            service: CognitiveService(store: store));
    } catch (e) {
      CognitiveUsageStore.instance.track(CognitiveEvent.storageFailed);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                e is StateError ? e.message.toString() : '认识记录暂未保存，请重试。')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    CognitivePreferenceStore.instance.load();
    return ValueListenableBuilder<CognitivePreferences>(
        valueListenable: CognitivePreferenceStore.instance,
        builder: (context, prefs, _) =>
            !CognitivePreferenceStore.enabledInBuild || !prefs.enabled
                ? const SizedBox.shrink()
                : widget.observation.trim().isEmpty
                    ? const Card(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('尚无具体观察材料。可以先记录一次经过，再保存认识笔记。')))
                    : Card(
                        color: const Color(0xfffaf6ee),
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('认识闭环',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600)),
                                  CognitiveLoopSteps(note: widget.snapshot),
                                  Wrap(spacing: 8, children: [
                                    if (widget.onNewEvidence != null)
                                      FilledButton.tonalIcon(
                                          onPressed: _saving
                                              ? null
                                              : widget.onNewEvidence,
                                          icon: const Icon(Icons.update),
                                          label: const Text('补充新材料，重新判断')),
                                    TextButton(
                                        onPressed: _saving ||
                                                widget.judgment.trim().isEmpty
                                            ? null
                                            : () => _save(context),
                                        child: const Text('保存本次理解与修订笔记')),
                                    TextButton(
                                        onPressed: () => showCognitiveNotes(
                                            context,
                                            module: widget.module,
                                            recordId: widget.recordId,
                                            store: widget.store),
                                        child: const Text('查看修订历史')),
                                  ]),
                                ]))));
  }
}
