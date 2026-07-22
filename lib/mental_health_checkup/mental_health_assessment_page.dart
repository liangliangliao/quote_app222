import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_engine.dart';
import 'mental_health_checkup_models.dart';
import 'mental_health_checkup_repository.dart';

class MentalHealthAssessmentPage extends StatefulWidget {
  final MentalHealthCheckupCatalog catalog;
  final CheckupModeSpec mode;
  final MentalHealthCheckupRepository repository;
  final String? focusDomainId;
  final Map<String, dynamic>? draft;

  const MentalHealthAssessmentPage({
    super.key,
    required this.catalog,
    required this.mode,
    required this.repository,
    this.focusDomainId,
    this.draft,
  });

  @override
  State<MentalHealthAssessmentPage> createState() =>
      _MentalHealthAssessmentPageState();
}

class _MentalHealthAssessmentPageState
    extends State<MentalHealthAssessmentPage> {
  late final MentalHealthCheckupEngine _engine;
  late final List<CheckupQuestion> _questions;
  late final String _sessionId;
  late final int _startedAtMs;
  final Map<String, CheckupAnswer> _answers = <String, CheckupAnswer>{};
  int _index = 0;
  bool _finishing = false;
  bool _savingDraft = false;

  @override
  void initState() {
    super.initState();
    _engine = MentalHealthCheckupEngine(widget.catalog);
    _questions = widget.catalog.questionsForMode(
      widget.mode.id,
      focusDomainId: widget.focusDomainId,
    );
    final draft = widget.draft;
    _sessionId = (draft?['session_id'] ?? '').toString().trim().isNotEmpty
        ? draft!['session_id'].toString()
        : 'session_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    _startedAtMs = (draft?['started_at_ms'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    if (draft != null && draft['answers'] is List) {
      for (final value in (draft['answers'] as List).whereType<Map>()) {
        final answer = CheckupAnswer.fromJson(Map<String, dynamic>.from(value));
        _answers[answer.questionId] = answer;
      }
      _index = ((draft['current_index'] as num?)?.toInt() ?? 0)
          .clamp(0, _questions.isEmpty ? 0 : _questions.length - 1)
          .toInt();
    }
  }

  CheckupQuestion get _question => _questions[_index];
  CheckupAnswer? get _answer => _answers[_question.id];

  Future<void> _persistDraft() async {
    if (_savingDraft || _finishing) return;
    _savingDraft = true;
    try {
      await widget.repository.saveDraft(
        sessionId: _sessionId,
        modeId: widget.mode.id,
        modeName: widget.mode.name,
        focusDomainId: widget.focusDomainId,
        startedAtMs: _startedAtMs,
        currentIndex: _index,
        answers: _answers.values.toList(growable: false),
      );
    } finally {
      _savingDraft = false;
    }
  }

  Future<bool> _onWillPop() async {
    await _persistDraft();
    return true;
  }

  Future<void> _select(CheckupAnswerChoice choice) async {
    final answer = CheckupAnswer(
      questionId: _question.id,
      label: choice.label,
      value: choice.value,
      answeredAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => _answers[_question.id] = answer);
    await _persistDraft();
    if (!mounted || !_question.isSafety) return;
    final alert = _question.id == 'B20-S3'
        ? choice.value >= 2
        : choice.value >= 2;
    final uncertain = choice.value >= 1;
    if (alert || uncertain) await _showSafetyInterruption(alert: alert);
  }

  Future<void> _showSafetyInterruption({required bool alert}) async {
    if (!mounted) return;
    final stop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          alert ? Icons.health_and_safety : Icons.shield_outlined,
          color: alert ? const Color(0xFFC62828) : const Color(0xFFE65100),
          size: 36,
        ),
        title: Text(alert ? '先处理现实安全' : '先把安全情况说清楚'),
        content: Text(
          alert
              ? '你的回答触发了安全分流。本轮将停止普通课程评分和课程行动处方。请不要独自承担：联系可信任的人、当地专业支持；如有立即危险，请联系当地紧急服务。'
              : '你的回答存在不确定或轻度异常。本轮不会继续生成普通课程处方。请先查看安全路线，并在需要时寻求人工支持。',
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _launchPhone('988'),
            icon: const Icon(Icons.call_outlined),
            label: const Text('加拿大/美国 988'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存并查看安全路线'),
          ),
        ],
      ),
    );
    if (stop == true && mounted) await _finish(allowIncomplete: true);
  }

  Future<void> _launchPhone(String number) async {
    try {
      await launchUrl(Uri.parse('tel:$number'));
    } catch (_) {}
  }

  Future<void> _next() async {
    if (_answer == null && _question.required) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这一题属于固定门题，请先选择最符合的答案。')),
      );
      return;
    }
    if (_index >= _questions.length - 1) {
      await _finish();
      return;
    }
    setState(() => _index++);
    await _persistDraft();
  }

  Future<void> _previous() async {
    if (_index == 0) return;
    setState(() => _index--);
    await _persistDraft();
  }

  Future<void> _finish({bool allowIncomplete = false}) async {
    if (_finishing) return;
    if (!allowIncomplete) {
      final missingRequired = _questions.any(
        (question) => question.required && !_answers.containsKey(question.id),
      );
      if (missingRequired) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('还有固定门题没有完成，请返回补充。')),
        );
        return;
      }
    }
    setState(() => _finishing = true);
    final answers = _answers.values.toList(growable: false);
    final report = _engine.buildReport(
      sessionId: _sessionId,
      modeId: widget.mode.id,
      questions: _questions,
      answers: answers,
    );
    final session = CheckupSession(
      id: _sessionId,
      modeId: widget.mode.id,
      modeName: widget.mode.name,
      startedAtMs: _startedAtMs,
      completedAtMs: DateTime.now().millisecondsSinceEpoch,
      answers: answers,
      report: report,
    );
    await widget.repository.clearDraft();
    if (!mounted) return;
    Navigator.of(context).pop(session);
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('当前模式没有可用题目。')),
      );
    }
    final progress = (_index + 1) / _questions.length;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F7FB),
          title: Text(widget.mode.name),
          actions: <Widget>[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_index + 1}/${_questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: const Color(0xFFE1E7F0),
                color: const Color(0xFF5664D2),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _Tag(
                            icon: _question.isSafety
                                ? Icons.shield_outlined
                                : Icons.category_outlined,
                            label: _question.group,
                            color: _question.isSafety
                                ? const Color(0xFFC62828)
                                : const Color(0xFF4554C5),
                          ),
                          _Tag(
                            icon: Icons.verified_outlined,
                            label: _shortSourceLevel(_question.sourceLevel),
                            color: const Color(0xFF39715D),
                          ),
                          if (!_question.required)
                            const _Tag(
                              icon: Icons.tune,
                              label: '自适应追问',
                              color: Color(0xFF6A4C93),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Semantics(
                        header: true,
                        child: Text(
                          _question.prompt,
                          style: const TextStyle(
                            fontSize: 23,
                            height: 1.45,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1C2434),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _question.scaleLabel,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ..._question.choices.map(
                        (choice) => _AnswerTile(
                          choice: choice,
                          selected: _answer?.value == choice.value,
                          onTap: _finishing ? null : () => _select(choice),
                        ),
                      ),
                      if (_question.isOpenCheck) ...<Widget>[
                        const SizedBox(height: 14),
                        const _PrivacyNote(),
                      ],
                      const SizedBox(height: 22),
                      _EvidenceHint(question: _question),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomSheet: SafeArea(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _index == 0 || _finishing ? null : _previous,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('上一题'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _finishing ? null : _next,
                    icon: _finishing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(_index == _questions.length - 1
                            ? Icons.auto_graph
                            : Icons.arrow_forward),
                    label: Text(
                      _finishing
                          ? '正在生成本地报告…'
                          : _index == _questions.length - 1
                              ? '完成并生成报告'
                              : _answer == null && !_question.required
                                  ? '跳过此题'
                                  : '下一题',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _shortSourceLevel(String value) {
    if (value.contains('D2')) return 'D2 安全层';
    if (value.contains('D1')) return 'D1 产品参数';
    if (value.contains('C1')) return 'C1 课程直接';
    if (value.contains('C2')) return 'C2 机制推导';
    return value.isEmpty ? '来源待核对' : value;
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _AnswerTile extends StatelessWidget {
  final CheckupAnswerChoice choice;
  final bool selected;
  final VoidCallback? onTap;

  const _AnswerTile({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          selected: selected,
          button: true,
          label: choice.label,
          child: Material(
            color: selected ? const Color(0xFFE9ECFF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF5664D2)
                        : const Color(0xFFD9DFE8),
                    width: selected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? const Color(0xFF5664D2)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF5664D2)
                              : const Color(0xFF98A2B3),
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 17, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        choice.label,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: const Color(0xFF263043),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7F4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.lock_outline, color: Color(0xFF39715D), size: 20),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                '为减少敏感文本暴露，本版本只保存“存在未覆盖问题”这一结构化信号，不保存开放题原文。你可以在之后与可信任的人或专业人员补充说明。',
                style: TextStyle(
                  color: Color(0xFF315C4E),
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
}

class _EvidenceHint extends StatelessWidget {
  final CheckupQuestion question;

  const _EvidenceHint({required this.question});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (question.indicatorId != null) '指标 ${question.indicatorId}',
      if (question.lecture != null) 'Lecture ${question.lecture}',
      if (question.evidenceLocation?.isNotEmpty == true)
        question.evidenceLocation!,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.menu_book_outlined, size: 18, color: Color(0xFF667085)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '课程定位：${parts.join(' · ')}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF667085),
            ),
          ),
        ),
      ],
    );
  }
}
