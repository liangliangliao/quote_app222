import 'package:flutter/material.dart';
import 'self_os_models.dart';
import 'self_os_representation_learning.dart';
import 'self_os_widgets.dart';

class SelfOsRepresentationEditor extends StatelessWidget {
  const SelfOsRepresentationEditor(
      {super.key,
      required this.value,
      required this.history,
      required this.onChanged,
      required this.enabled});
  final SelfOsCase value;
  final List<SelfOsCase> history;
  final void Function(VoidCallback) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final task = value.text('representation.task');
    final window = value.text('representation.window');
    final recommendation =
        SelfOsRepresentationLearning.recommend(history, task, window);
    final patterns = SelfOsRepresentationLearning.patterns(history)
        .where((p) => p.task == task && p.window == window)
        .toList();
    Widget choice(String key, String label, Map<String, String> options) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
            key: ValueKey(
                'representation_pick_${key}_${value.text('representation.$key')}'),
            isExpanded: true,
            initialValue: options.containsKey(value.text('representation.$key'))
                ? value.text('representation.$key')
                : null,
            decoration: InputDecoration(labelText: label),
            items: options.entries
                .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: enabled
                ? (v) => onChanged(
                    () => value.fields['representation.$key'] = v ?? '')
                : null));
    return OsSection(
        title: '换一种方式，让后果更容易理解',
        subtitle: '先确认问题结构与使用时点，再选择表达。AI 生成或自己填写的内容，都要保留事实来源和未知。',
        children: [
          choice('task', '这次要看清什么？', osRepresentationTasks),
          choice('window', '准备什么时候使用？', osRepresentationWindows),
          if (recommendation != null) ...[
            OsNote(
                '相似情境中，「${osRepresentationFormats[recommendation.format]}」有 ${recommendation.helped}/${recommendation.total} 次理解帮助、${recommendation.harmed} 次反作用。可优先尝试，仍由这次反馈检验。'),
            TextButton(
                key: const ValueKey('representation_use_recommendation'),
                onPressed: enabled
                    ? () => onChanged(() =>
                        value.fields['representation.format'] =
                            recommendation.format)
                    : null,
                child: const Text('采用历史中较有帮助的方式')),
          ] else
            const OsNote('这类问题与时点的实际样本还不足。先选一种试用，未知不会计为有效。'),
          if (patterns.isNotEmpty)
            ExpansionTile(
                title: const Text('查看比较依据与反例'),
                tilePadding: EdgeInsets.zero,
                children: [
                  const Text(
                      '同类问题、同一时点，至少 3 次复盘、2 个案例与 2 种情境后才用于推荐。按理解帮助减反作用排序；这是个人自报关联。'),
                  for (final p in patterns)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${osRepresentationFormats[p.format]} · 理解 ${p.helped}/${p.total} · 反作用 ${p.harmed}'),
                        subtitle: Text(
                            '动机进入考虑 ${p.available}/${p.availabilityTotal} · 行动帮助 ${p.acted}/${p.actionTotal} · 未知或条件未厘清 ${p.observations.length - p.total}\n${p.observations.take(6).map((o) => '${osDate(DateTime.tryParse(osText(o['recordedAt'])) ?? DateTime(1970))} · ${o['context']}：${o['observation'].toString().isEmpty ? '未记录实际作用' : o['observation']}\n适用条件：${o['conditions']}').join('\n')}')),
                ]),
          choice('format', '本次表达方式', osRepresentationFormats),
          TextFormField(
              key: ValueKey('representation_draft_${value.round}'),
              initialValue: value.text('representation.draft'),
              enabled: enabled,
              minLines: 3,
              maxLines: 6,
              maxLength: 6000,
              decoration: const InputDecoration(
                  labelText: '手动写一版具体表达',
                  hintText: '例如：列出现在、下周、下个月可能发生的变化，并标注条件。数值没有依据就保持未知。'),
              onChanged: (v) => value.fields['representation.draft'] = v),
          TextFormField(
              key: ValueKey('representation_source_${value.round}'),
              initialValue: value.text('representation.source'),
              enabled: enabled,
              minLines: 1,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: '内容依据与尚待核验的部分'),
              onChanged: (v) => value.fields['representation.source'] = v),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              key: const ValueKey('representation_adopt'),
              onPressed: enabled
                  ? () {
                      try {
                        onChanged(() => SelfOsRepresentationLearning.adopt(
                            value,
                            choice: {
                              'format': value.text('representation.format'),
                              'task': task,
                              'window': window
                            },
                            content: value.text('representation.draft'),
                            source: value.text('representation.source')));
                        osMessage(context, '已写入 K2。继续校准动机，行动后再反馈这版表达的实际作用。');
                      } on FormatException catch (e) {
                        osMessage(context, e.message);
                      }
                    }
                  : null,
              icon: const Icon(Icons.check),
              label: const Text('采用这版表达，继续校准动机')),
        ]);
  }
}

class SelfOsRepresentationFeedback extends StatefulWidget {
  const SelfOsRepresentationFeedback(
      {super.key, required this.review, required this.onSave});
  final SelfOsReview review;
  final Future<bool> Function(Map<String, String>) onSave;
  @override
  State<SelfOsRepresentationFeedback> createState() =>
      _SelfOsRepresentationFeedbackState();
}

class _SelfOsRepresentationFeedbackState
    extends State<SelfOsRepresentationFeedback> {
  late final draft = Map<String, String>.from(widget.review.notes);
  bool busy = false;
  String? message;
  @override
  Widget build(BuildContext context) {
    final uses = SelfOsRepresentationLearning.uses(widget.review.snapshot);
    if (uses.isEmpty) return const SizedBox.shrink();
    return OsSection(
        title: '哪种表达真的帮助了这次认识？',
        subtitle: '理解、动机与行动分别记录。现场没用到或无法判断，就保留未知。',
        children: [
          for (final use in uses)
            ExpansionTile(
                key: ValueKey('representation_feedback_${use['id']}'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                    '${osRepresentationFormats[use['format']]} · ${osRepresentationWindows[use['window']]}'),
                subtitle: Text(osRepresentationTasks[use['task']]!),
                children: [
                  Text(osText(use['content']),
                      style: const TextStyle(height: 1.6)),
                  Text('当时依据：${use['source']}',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  for (final dimension in const {
                    'understanding': '是否帮助理解事实与后果？',
                    'availability': '相关动机是否真正进入了考虑？',
                    'action': '是否帮助了实际行动？',
                  }.entries)
                    _choice('representation.${use['id']}.${dimension.key}',
                        dimension.value, osRepresentationEffects),
                  _input(
                      'representation.${use['id']}.observation', '具体观察到了什么？'),
                  _choice('representation.${use['id']}.attribution',
                      '其他变化对结果的影响', const {
                    'unknown': '还没有厘清',
                    'contextOnly': '同时变化较多，只解释这一次',
                    'considered': '已考虑其他变化，可在相近条件下参考',
                  }),
                  _input('representation.${use['id']}.conditions',
                      '知识、环境、状态有哪些变化？只适用什么条件？'),
                ]),
          if (message != null) OsNote(message!),
          OutlinedButton.icon(
              key: const ValueKey('save_representation_feedback'),
              onPressed: busy
                  ? null
                  : () async {
                      final notes = {
                        for (final e in draft.entries)
                          if (e.key.startsWith('representation.'))
                            e.key: e.value
                      };
                      try {
                        SelfOsRepresentationLearning.saveFeedback(
                            SelfOsReview.fromJson(
                                osClone(widget.review.toJson())),
                            notes);
                      } on FormatException catch (e) {
                        setState(() => message = e.message);
                        return;
                      }
                      setState(() {
                        busy = true;
                        message = null;
                      });
                      bool saved;
                      try {
                        saved = await widget.onSave(notes);
                      } catch (_) {
                        saved = false;
                      }
                      if (mounted)
                        setState(() {
                          busy = false;
                          message = saved
                              ? '已保存。下次相似问题会参考这些实际反馈。'
                              : '保存失败，反馈仍在这里，请重试。';
                        });
                    },
              icon: const Icon(Icons.check),
              label: Text(busy ? '保存中…' : '保存表达的实际作用')),
        ]);
  }

  Widget _choice(String key, String label, Map<String, String> options) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
              key: ValueKey(key),
              isExpanded: true,
              initialValue:
                  options.containsKey(draft[key]) ? draft[key] : 'unknown',
              decoration: InputDecoration(labelText: label),
              items: options.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => setState(() => draft[key] = v ?? 'unknown')));
  Widget _input(String key, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
          key: ValueKey(key),
          initialValue: draft[key] ?? '',
          enabled: !busy,
          minLines: 2,
          maxLines: 4,
          maxLength: 3000,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) => draft[key] = v));
}
