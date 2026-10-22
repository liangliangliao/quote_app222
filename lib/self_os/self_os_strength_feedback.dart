import 'package:flutter/material.dart';
import 'self_os_models.dart';
import 'self_os_strength_learning.dart';
import 'self_os_widgets.dart';

class SelfOsStrengthFeedback extends StatefulWidget {
  const SelfOsStrengthFeedback(
      {super.key,
      required this.review,
      required this.profile,
      required this.onSave});
  final SelfOsReview review;
  final SelfOsProfile profile;
  final Future<bool> Function(Map<String, String>) onSave;
  @override
  State<SelfOsStrengthFeedback> createState() => _SelfOsStrengthFeedbackState();
}

class _SelfOsStrengthFeedbackState extends State<SelfOsStrengthFeedback> {
  late final draft = Map<String, String>.from(widget.review.notes);
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final uses = SelfOsStrengthLearning.uses(widget.review.snapshot)
        .where(
            (u) => widget.profile.strengths.any((s) => s.id == u['strengthId']))
        .toList();
    if (uses.isEmpty) return const SizedBox.shrink();
    return OsSection(
        title: '这次调用的力量，实际起作用了吗？',
        subtitle: '分别看认识、动机与行动中的作用。一次行动只增加一个样本，不能因为用了三次就算三条证据。',
        children: [
          for (final use in uses)
            ExpansionTile(
                key: ValueKey('strength_feedback_${use['key']}'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                    '${widget.profile.strengths.firstWhere((s) => s.id == use['strengthId']).title} · ${osStrengthStages[use['stage']]}'),
                subtitle: Text(use['detail']!,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                children: [
                  _choice('strength.${use['key']}.effect', '实际作用', const {
                    'unknown': '无法判断 / 没有使用',
                    'helped': '有帮助',
                    'notHelped': '没有观察到帮助',
                    'harmed': '产生反作用'
                  }),
                  _choice('strength.${use['key']}.usage', '使用程度', const {
                    'unknown': '不确定',
                    'underuse': '使用不足',
                    'optimal': '合适使用',
                    'overuse': '过度使用'
                  }),
                  TextFormField(
                      key: ValueKey('strength_observation_${use['key']}'),
                      initialValue:
                          draft['strength.${use['key']}.observation'] ?? '',
                      minLines: 2,
                      maxLines: 4,
                      enabled: !busy,
                      decoration:
                          const InputDecoration(labelText: '实际发生了什么，如何帮助或妨碍？'),
                      onChanged: (v) =>
                          draft['strength.${use['key']}.observation'] = v),
                  const SizedBox(height: 12),
                ]),
          if (error != null) OsNote(error!),
          OutlinedButton.icon(
              key: const ValueKey('save_strength_feedback'),
              onPressed: busy
                  ? null
                  : () async {
                      for (final use in uses) {
                        final prefix = 'strength.${use['key']}';
                        if (['helped', 'notHelped', 'harmed']
                                .contains(draft['$prefix.effect']) &&
                            (draft['$prefix.observation'] ?? '')
                                .trim()
                                .isEmpty) {
                          setState(() => error = '请补充具体观察；还无法判断时保留未知。');
                          return;
                        }
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      bool saved;
                      try {
                        saved = await widget.onSave({
                          for (final e in draft.entries)
                            if (e.key.startsWith('strength.')) e.key: e.value
                        });
                      } catch (_) {
                        saved = false;
                      }
                      if (mounted)
                        setState(() {
                          busy = false;
                          error =
                              saved ? '已保存，后续分析会参考这次实际作用。' : '保存失败，反馈仍在这里，请重试。';
                        });
                    },
              icon: const Icon(Icons.check),
              label: Text(busy ? '保存中…' : '保存力量的实际作用')),
        ]);
  }

  Widget _choice(String key, String label, Map<String, String> values) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
              key: ValueKey(key),
              isExpanded: true,
              initialValue:
                  values.containsKey(draft[key]) ? draft[key] : 'unknown',
              decoration: InputDecoration(labelText: label),
              items: values.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => setState(() => draft[key] = v ?? 'unknown')));
}
