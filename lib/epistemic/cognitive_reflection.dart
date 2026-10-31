import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import 'cognitive_models.dart';
import 'cognitive_preferences.dart';
import 'cognitive_sheet.dart';
import 'cognitive_store.dart';

class CognitiveReflectionCard extends StatelessWidget {
  final String module, recordId, observation, judgment, basis;
  final List<String> concepts;
  final VoidCallback? onNewEvidence;
  const CognitiveReflectionCard(
      {super.key,
      required this.module,
      required this.recordId,
      required this.observation,
      required this.judgment,
      required this.basis,
      this.concepts = const [],
      this.onNewEvidence});
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
  Future<void> _save(BuildContext context) async {
    try {
      final store = CognitiveStore();
      var note = snapshot;
      final existing = (await store.forRecord(module, recordId))
          .where((e) => e.id == note.id)
          .firstOrNull;
      if (existing != null) {
        note = existing;
      } else {
        await store.save(note);
      }
      if (context.mounted)
        await showCognitiveAnalysis(context,
            selection: note.selection, task: note.task, note: note);
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('认识记录暂未保存，请重试。')));
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
                              CognitiveLoopSteps(note: snapshot),
                              Wrap(spacing: 8, children: [
                                if (onNewEvidence != null)
                                  FilledButton.tonalIcon(
                                      onPressed: onNewEvidence,
                                      icon: const Icon(Icons.update),
                                      label: const Text('补充新材料，重新判断')),
                                TextButton(
                                    onPressed: () => _save(context),
                                    child: const Text('保存本次理解与修订笔记')),
                                TextButton(
                                    onPressed: () => showCognitiveNotes(context,
                                        module: module, recordId: recordId),
                                    child: const Text('查看修订历史')),
                              ]),
                            ]))));
  }
}
