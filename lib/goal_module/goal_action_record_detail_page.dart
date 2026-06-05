import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'goal_dao.dart';
import 'goal_models.dart';
import 'goal_segment_detail_page.dart';
import 'goal_workshop_page.dart';

class GoalActionRecordDetailPage extends StatefulWidget {
  final int recordId;
  const GoalActionRecordDetailPage({super.key, required this.recordId});

  @override
  State<GoalActionRecordDetailPage> createState() => _GoalActionRecordDetailPageState();
}

class _GoalActionRecordDetailPageState extends State<GoalActionRecordDetailPage> {
  final _dao = GoalDao();
  late Future<GoalActionRecordBundle?> _future;
  final _reflection = TextEditingController();
  final _nextStep = TextEditingController();
  final _weeklyFocus = TextEditingController();
  String _decision = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<GoalActionRecordBundle?> _load() async {
    final bundle = await _dao.getActionRecordBundle(widget.recordId);
    if (bundle != null) {
      _decision = bundle.followup.decision;
      _reflection.text = bundle.followup.reflectionText;
      _nextStep.text = bundle.followup.nextStep;
      _weeklyFocus.text = bundle.followup.weeklyFocus;
    }
    return bundle;
  }

  @override
  void dispose() {
    _reflection.dispose();
    _nextStep.dispose();
    _weeklyFocus.dispose();
    super.dispose();
  }

  Future<void> _save({bool openWorkshop = false}) async {
    setState(() => _saving = true);
    final reflectionText = _reflection.text.trim();
    final nextStep = _nextStep.text.trim();
    final weeklyFocus = _weeklyFocus.text.trim();
    await _dao.saveActionFollowup(
      actionRecordId: widget.recordId,
      decision: _decision,
      reflectionText: reflectionText,
      nextStep: nextStep,
      weeklyFocus: weeklyFocus,
    );

    GoalWorkshopDraft? mergedDraft;
    if (openWorkshop) {
      mergedDraft = await _dao.mergeFollowupIntoWorkshop(
        actionRecordId: widget.recordId,
        decision: _decision,
        reflectionText: reflectionText,
        nextStep: nextStep,
        weeklyFocus: weeklyFocus,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(openWorkshop ? '已保存并同步到目标工坊' : '二次复盘已保存')),
    );

    if (openWorkshop) {
      final note = _buildWorkshopNote(mergedDraft);
      await Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => GoalWorkshopPage(entryNote: note)),
      );
      if (mounted) {
        setState(() {
          _future = _load();
        });
      }
    }
  }

  String _buildWorkshopNote(GoalWorkshopDraft? draft) {
    if (draft == null) {
      return '已从行动闭环带入本周聚焦与下一步动作，请在工坊里继续调整。';
    }
    final parts = <String>[];
    if (draft.weeklyGoal.trim().isNotEmpty) parts.add('本周推进：${draft.weeklyGoal.trim()}');
    if (draft.firstStep.trim().isNotEmpty) parts.add('下一步：${draft.firstStep.trim()}');
    return parts.isEmpty
        ? '已从行动闭环带入本周聚焦与下一步动作，请在工坊里继续调整。'
        : '已从行动闭环同步到目标工坊。${parts.join('；')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('行动记录详情')),
      backgroundColor: const Color(0xFFF5F6FA),
      body: FutureBuilder<GoalActionRecordBundle?>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(snap.error?.toString() ?? '未找到记录'));
          }
          final bundle = snap.data;
          if (bundle == null) return const Center(child: Text('未找到记录'));
          final view = bundle.view;
          final feedback = view.record.feedbackMap;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip('已执行'),
                        if (view.hasFollowup) _chip('已${view.followupDecision}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(view.actionTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(view.conceptTitle, style: const TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    Text(view.segmentTitle, style: const TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _stat('完成度', '${(view.record.completionRate * 100).round()}%')),
                        const SizedBox(width: 10),
                        Expanded(child: _stat('完成时间', _shortDate(view.record.completedAtMs))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '首次记录',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (feedback.isNotEmpty)
                      for (final e in feedback.entries) ...[
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(e.value.isEmpty ? '—' : e.value, style: const TextStyle(height: 1.6, color: Color(0xFF374151))),
                        const SizedBox(height: 10),
                      ],
                    const Text('首次反思', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      view.record.reflectionText.trim().isEmpty ? '—' : view.record.reflectionText,
                      style: const TextStyle(height: 1.6, color: Color(0xFF374151)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '二次复盘：接下来怎么办',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _decisionChip('继续'),
                        _decisionChip('调整'),
                        _decisionChip('放弃'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _label('我现在的判断'),
                    TextField(
                      controller: _reflection,
                      maxLines: 4,
                      decoration: _inputDecoration('这次行动让我更想继续，还是需要调整？真正的问题出在哪里？'),
                    ),
                    const SizedBox(height: 12),
                    _label('下一步动作'),
                    TextField(
                      controller: _nextStep,
                      maxLines: 2,
                      decoration: _inputDecoration('例如：明天把动作缩小到 10 分钟，只做第一步'),
                    ),
                    const SizedBox(height: 12),
                    _label('本周聚焦'),
                    TextField(
                      controller: _weeklyFocus,
                      maxLines: 2,
                      decoration: _inputDecoration('例如：这周只追踪一致性，不追求完成量'),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '点“保存并同步到工坊”后，会把本周聚焦写入目标工坊，把下一步动作写入“明天第一步”；如果选择“调整”，还会把本次复盘写入“现实阻碍”。',
                        style: TextStyle(height: 1.6, color: Color(0xFF6B7280)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : () => _save(openWorkshop: true),
                            icon: const Icon(Icons.move_down_outlined),
                            label: const Text('保存并同步到工坊'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: '回看原课程正文',
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => GoalSegmentDetailPage(segmentId: view.record.segmentId)),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('查看对应课程正文'),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? '保存中…' : '保存二次复盘'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _decisionChip(String value) {
    final selected = _decision == value;
    return GestureDetector(
      onTap: () => setState(() => _decision = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          value,
          style: TextStyle(color: selected ? Colors.white : const Color(0xFF374151), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _card({String? title, required Widget child}) => Container(
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

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Widget _stat(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
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

  String _shortDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
