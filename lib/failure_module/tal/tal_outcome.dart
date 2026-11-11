import 'dart:async';
import 'package:flutter/material.dart';
import '../../beautiful_enemy/src/domain/guard.dart' show SafetyValve;
import 'tal_ledger.dart';
import 'tal_models.dart';
import 'tal_shared_views.dart';

/// Follow-up is deliberately limited to action and result. It does not reopen
/// the reflection questionnaire or ask users to mark a lesson "validated".
class TalOutcomeSheet extends StatefulWidget {
  const TalOutcomeSheet(
      {super.key,
      required this.record,
      required this.ledger,
      required this.onCrisis});
  final TalRecord record;
  final TalLessonLedger ledger;
  final Future<void> Function() onCrisis;
  @override
  State<TalOutcomeSheet> createState() => _TalOutcomeSheetState();
}

class _TalOutcomeSheetState extends State<TalOutcomeSheet> {
  final _observation = TextEditingController();
  final String _evidenceId =
      'feedback:${DateTime.now().microsecondsSinceEpoch}';
  String? _done;
  String _outcome = 'unclear', _error = '';
  bool _busy = false, _crisis = false;
  @override
  void initState() {
    super.initState();
    _observation.addListener(_guard);
  }

  void _guard() {
    if (!_crisis && SafetyValve.isCrisis(_observation.text)) {
      setState(() => _crisis = true);
      unawaited(widget.onCrisis().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    _observation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _crisis) return;
    if (_done == null) {
      setState(() => _error = '可以选“还不确定”，也可以先关闭。');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await widget.ledger.appendOutcome(widget.record.eventId,
          trialId: widget.record.currentTrial!.id,
          evidenceId: _evidenceId,
          actionDone: _done == 'yes'
              ? true
              : _done == 'no'
                  ? false
                  : null,
          outcome: _done == 'yes' ? _outcome : 'unclear',
          observation: _observation.text);
      if (mounted) Navigator.pop(context, r);
    } on TalCrisisException {
      if (mounted) setState(() => _crisis = true);
      await widget.onCrisis();
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = '这次还没保存，请重试。';
        });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: _crisis
              ? const TalSafetyCard()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Text('这次实际怎么样？',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(widget.record.currentTrial!.action),
                      const SizedBox(height: 20),
                      const Text('1. 这个动作做了吗？'),
                      Wrap(spacing: 8, children: [
                        for (final e in const {
                          'yes': '做了',
                          'no': '没有做',
                          'unknown': '还不确定'
                        }.entries)
                          ChoiceChip(
                              label: Text(e.value),
                              selected: _done == e.key,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(() => _done = e.key))
                      ]),
                      const SizedBox(height: 16),
                      const Text('2. 结果如何？'),
                      if (_done == 'yes')
                        Wrap(spacing: 8, children: [
                          for (final e in const {
                            'helped': '这次有帮助',
                            'unclear': '效果还不清楚',
                            'not_helped': '这次没帮助'
                          }.entries)
                            ChoiceChip(
                                label: Text(e.value),
                                selected: _outcome == e.key,
                                onSelected: _busy
                                    ? null
                                    : (_) => setState(() => _outcome = e.key))
                        ])
                      else
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('还没确认行动发生，就先保留“效果未知”，不用解释成方法或你不好。')),
                      TextField(
                          key: const ValueKey('tal_feedback_observation'),
                          controller: _observation,
                          minLines: 1,
                          maxLines: 3,
                          maxLength: 10000,
                          decoration: const InputDecoration(
                              labelText: '愿意的话，留一句具体结果（可跳过）', counterText: '')),
                      const SizedBox(height: 8),
                      const Text('自述有帮助先作为这次反馈，不自动证明教训有效或长期改变。'),
                      if (_error.isNotEmpty) Text(_error),
                      FilledButton(
                          key: const ValueKey('tal_save_feedback'),
                          onPressed: _busy ? null : _save,
                          child: Text(_busy ? '保存中…' : '保存这次反馈')),
                    ])));
}
