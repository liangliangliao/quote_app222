import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';

class GoalActionRunnerPage extends StatefulWidget {
  final GoalActionTemplate action;
  final String conceptTitle;
  final String segmentTitle;

  const GoalActionRunnerPage({
    super.key,
    required this.action,
    required this.conceptTitle,
    required this.segmentTitle,
  });

  @override
  State<GoalActionRunnerPage> createState() => _GoalActionRunnerPageState();
}

class _GoalActionRunnerPageState extends State<GoalActionRunnerPage> {
  final _dao = GoalDao();
  int _startedAtMs = 0;
  late List<bool> _checks;
  late final Map<String, TextEditingController> _feedbackControllers;
  final _reflection = TextEditingController();
  bool _saving = false;
  bool _hydratingDraft = false;
  bool _draftReady = false;

  @override
  void initState() {
    super.initState();
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    _checks = List<bool>.filled(widget.action.steps.length, false);
    _feedbackControllers = {
      for (final f in widget.action.feedbackFields) f: TextEditingController(),
    };
    _reflection.addListener(() { _persistDraft(); });
    for (final c in _feedbackControllers.values) {
      c.addListener(() { _persistDraft(); });
    }
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final draft = await _dao.getActionDraft(widget.action.actionId);
    if (!mounted) return;
    if (draft != null) {
      _hydratingDraft = true;
      _startedAtMs = draft.startedAtMs > 0 ? draft.startedAtMs : _startedAtMs;
      final draftChecks = draft.checks;
      _checks = List<bool>.generate(widget.action.steps.length, (i) => i < draftChecks.length ? draftChecks[i] : false);
      final feedbackValues = draft.feedbackValues;
      for (final entry in _feedbackControllers.entries) {
        entry.value.text = feedbackValues[entry.key] ?? '';
      }
      _reflection.text = draft.reflectionText;
      _hydratingDraft = false;
    }
    setState(() => _draftReady = true);
  }

  Future<void> _persistDraft() async {
    if (_hydratingDraft) return;
    await _dao.saveActionDraft(
      actionId: widget.action.actionId,
      conceptId: widget.action.conceptId,
      segmentId: widget.action.segmentId,
      startedAtMs: _startedAtMs,
      actionTitle: widget.action.actionTitle,
      actionLevel: widget.action.actionLevel,
      goalOfAction: widget.action.goalOfAction,
      steps: widget.action.steps,
      durationMin: widget.action.durationMin,
      failurePlan: widget.action.failurePlan,
      feedbackFields: widget.action.feedbackFields,
      checks: _checks,
      feedbackValues: {for (final e in _feedbackControllers.entries) e.key: e.value.text.trim()},
      reflectionText: _reflection.text.trim(),
      conceptTitleSnapshot: widget.conceptTitle,
      segmentTitleSnapshot: widget.segmentTitle,
    );
  }

  @override
  void dispose() {
    _reflection.dispose();
    for (final c in _feedbackControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _persistDraft();
    final total = widget.action.steps.isEmpty ? 1 : widget.action.steps.length;
    final done = _checks.where((e) => e).length;
    final feedback = <String, String>{
      for (final e in _feedbackControllers.entries) e.key: e.value.text.trim(),
    };
    await _dao.saveActionRecord(
      actionId: widget.action.actionId,
      conceptId: widget.action.conceptId,
      segmentId: widget.action.segmentId,
      startedAtMs: _startedAtMs,
      completionRate: done / total,
      feedbackMap: feedback,
      reflectionText: _reflection.text.trim(),
      actionTitleSnapshot: widget.action.actionTitle,
      conceptTitleSnapshot: widget.conceptTitle,
      segmentTitleSnapshot: widget.segmentTitle,
      actionLevelSnapshot: widget.action.actionLevel,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('行动记录已保存')));
    Navigator.of(context).maybePop(true);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.action.steps.isEmpty
        ? 0.0
        : _checks.where((e) => e).length / widget.action.steps.length;
    return Scaffold(
      appBar: AppBar(title: const Text('行动执行页')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chip(widget.action.actionLevel),
                const SizedBox(height: 12),
                Text(widget.action.actionTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(widget.action.goalOfAction, style: const TextStyle(height: 1.6, color: Color(0xFF374151))),
                const SizedBox(height: 12),
                Text('概念：${widget.conceptTitle}', style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                Text('来源：${widget.segmentTitle}', style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 12),
                if (_draftReady && (_checks.any((e) => e) || _reflection.text.trim().isNotEmpty || _feedbackControllers.values.any((c) => c.text.trim().isNotEmpty)))
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('已恢复你上次未完成的行动步骤，可从当前进度继续。', style: TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                  ),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: const Color(0xFFE5E7EB),
                ),
                const SizedBox(height: 8),
                Text('当前完成度：${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '步骤清单',
            child: Column(
              children: [
                for (int i = 0; i < widget.action.steps.length; i++)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _checks[i],
                    title: Text(widget.action.steps[i]),
                    subtitle: Text('第 ${i + 1} 步'),
                    onChanged: (v) {
                      setState(() => _checks[i] = v ?? false);
                      _persistDraft();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: '反馈记录',
            child: Column(
              children: [
                for (final f in widget.action.feedbackFields) ...[
                  _label(f),
                  TextField(
                    controller: _feedbackControllers[f],
                    onChanged: (_) { _persistDraft(); },
                    maxLines: 2,
                    decoration: _inputDecoration('请填写：$f'),
                  ),
                  const SizedBox(height: 10),
                ],
                _label('反思/复盘'),
                TextField(
                  controller: _reflection,
                  onChanged: (_) { _persistDraft(); },
                  maxLines: 4,
                  decoration: _inputDecoration('今天做完后，你最大的发现是什么？下次要改什么？'),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('失败备用方案：${widget.action.failurePlan}', style: const TextStyle(height: 1.6, color: Color(0xFF6B7280))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: Text(_saving ? '保存中…' : '保存行动记录'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }

  Widget _card({String? title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );
}
