import 'package:flutter/material.dart';

import 'belief_mentor_ai_service.dart';
import 'belief_mentor_dao.dart';
import 'belief_mentor_models.dart';
import 'belief_mentor_policies.dart';
import 'belief_mentor_reminder_service.dart';

class BeliefMentorOnboardingPage extends StatefulWidget {
  const BeliefMentorOnboardingPage({
    super.key,
    required this.onCompleted,
    this.dao,
    this.ai,
  });

  final VoidCallback onCompleted;
  final BeliefMentorDao? dao;
  final BeliefMentorAiService? ai;

  @override
  State<BeliefMentorOnboardingPage> createState() =>
      _BeliefMentorOnboardingPageState();
}

class _BeliefMentorOnboardingPageState
    extends State<BeliefMentorOnboardingPage> {
  late final BeliefMentorDao _dao = widget.dao ?? BeliefMentorDao();
  late final BeliefMentorAiService _ai =
      widget.ai ?? BeliefMentorAiService(dao: _dao);
  late final BeliefMentorReminderService _reminders =
      BeliefMentorReminderService(dao: _dao);

  final _event = TextEditingController();
  final _thought = TextEditingController();
  final _action = TextEditingController();
  final _experimentAction = TextEditingController();
  final _experimentMinimum = TextEditingController();
  final _experimentFallback = TextEditingController();
  final _domains = <String>{'工作与学习'};
  BeliefMentorDiagnosis? _diagnosis;
  BeliefMentorAiResult<BeliefMentorDiagnosis>? _diagnosisResult;
  int _step = 0;
  int _selectedCandidate = 0;
  double _strength = 70;
  bool _remindersEnabled = false;
  bool _busy = false;
  String _tone = 'coach';
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 8, minute: 0);
  DateTime _experimentAt = DateTime.now().add(const Duration(hours: 2));
  double _experimentDifficulty = 3;
  double _experimentProbability = 75;

  static const _domainChoices = <String>[
    '工作与学习',
    '关系',
    '健康',
    '金钱',
    '创造',
    '自我评价',
  ];

  @override
  void dispose() {
    _event.dispose();
    _thought.dispose();
    _action.dispose();
    _experimentAction.dispose();
    _experimentMinimum.dispose();
    _experimentFallback.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_event.text.trim().isEmpty && _thought.text.trim().isEmpty) {
      _show('至少写下一个事件或当时冒出的想法');
      return;
    }
    setState(() => _busy = true);
    final result = await _ai.diagnose(
      event: _event.text,
      thought: _thought.text,
      action: _action.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _diagnosisResult = result;
      _diagnosis = result.value;
      _selectedCandidate = 0;
      _step = result.value.blocksNormalFlow ? 1 : 2;
    });
  }

  Future<void> _finish() async {
    final diagnosis = _diagnosis;
    if (diagnosis == null || diagnosis.candidates.isEmpty) {
      _show('请先完成一次分析并确认候选信念');
      return;
    }
    final candidate =
        diagnosis.candidates[_selectedCandidate.clamp(
          0,
          diagnosis.candidates.length - 1,
        )];
    if (_domains.isEmpty || _domains.length > 2) {
      _show('请选择 1–2 个优先领域');
      return;
    }
    final draft = BeliefMentorExperimentDraft(
      action: _experimentAction.text,
      minimumVersion: _experimentMinimum.text,
      fallbackAction: _experimentFallback.text,
      difficulty: _experimentDifficulty.round(),
      completionProbability: _experimentProbability.round(),
      rationale: 'Onboarding 首个现实检验',
    );
    final experimentErrors = BeliefMentorExperimentPolicy.validate(draft);
    if (experimentErrors.isNotEmpty) {
      _show(experimentErrors.join('；'));
      return;
    }
    if (_experimentAt.isBefore(DateTime.now()) ||
        _experimentAt.isAfter(DateTime.now().add(const Duration(hours: 24)))) {
      _show('首个微实验需安排在未来 24 小时内');
      return;
    }
    final safety = BeliefMentorSafetyPolicy.assess(
      '${candidate.statement} ${candidate.alternative} ${draft.action} '
      '${draft.minimumVersion} ${draft.fallbackAction}',
    );
    if (safety.blocksNormalFlow) {
      await _dao.recordSafetyEvent(
        category: safety.category,
        action: 'blocked_onboarding_confirmation',
        source: 'user_edit',
      );
      _show(safety.message);
      return;
    }
    setState(() => _busy = true);
    final now = DateTime.now();
    final belief = BeliefMentorBelief(
      id: 'belief_${now.microsecondsSinceEpoch}',
      statement: candidate.statement,
      type: candidate.type,
      strength: _strength.round(),
      initialStrength: _strength.round(),
      trigger: candidate.trigger,
      alternativeStatement: candidate.alternative,
      state: BeliefMentorBeliefState.alternativeFormed,
      userConfirmed: true,
      createdAtMs: now.millisecondsSinceEpoch,
      updatedAtMs: now.millisecondsSinceEpoch,
      patterns: candidate.patterns.isEmpty
          ? BeliefMentorCognitivePatternPolicy.detect(candidate.statement)
          : candidate.patterns,
    );
    await _dao.saveBelief(belief, scoreSource: 'onboarding_confirmation');
    var remindersEnabled = _remindersEnabled;
    if (remindersEnabled) {
      remindersEnabled = await _reminders.requestPermission();
    }
    final current = await _dao.profile();
    await _dao.saveProfile(
      current.copyWith(
        onboardingCompleted: true,
        domains: _domains.toList(growable: false),
        remindersEnabled: remindersEnabled,
        quietStart: _timeString(_quietStart),
        quietEnd: _timeString(_quietEnd),
        tone: _tone,
        timezone: now.timeZoneName,
        activeBeliefId: belief.id,
      ),
    );
    final experiment = await _dao.createExperiment(
      beliefId: belief.id,
      draft: draft,
      scheduledAt: _experimentAt,
    );
    if (remindersEnabled) {
      await _reminders.scheduleMorningPrime(belief: belief);
      await _reminders.scheduleExperimentPlan(experiment);
    }
    await _dao.track(
      'onboarding_completed',
      beliefId: belief.id,
      properties: <String, Object?>{
        'reminders_enabled': remindersEnabled,
        'tone': _tone,
        'domains': _domains.toList(growable: false),
        'quiet_start': _timeString(_quietStart),
        'quiet_end': _timeString(_quietEnd),
        'initial_experiment_created': true,
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onCompleted();
  }

  Future<void> _editCandidate(int index) async {
    final diagnosis = _diagnosis;
    if (diagnosis == null || index >= diagnosis.candidates.length) return;
    final item = diagnosis.candidates[index];
    final statement = TextEditingController(text: item.statement);
    final trigger = TextEditingController(text: item.trigger);
    final alternative = TextEditingController(text: item.alternative);
    var type = item.type;
    final patterns = <BeliefMentorCognitivePattern>{
      ...item.patterns,
      ...BeliefMentorCognitivePatternPolicy.detect(item.statement),
    };
    final updated = await showDialog<BeliefMentorCandidateBelief>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('按你的真实体验修改'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: statement,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '候选限制性信念'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<BeliefMentorBeliefType>(
                    value: type,
                    decoration: const InputDecoration(labelText: '信念类型'),
                    items: BeliefMentorBeliefType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setDialogState(() => type = value ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: trigger,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '常见触发情境'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: alternative,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '可检验的替代信念'),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '3M 思维雷达（可修改）',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ...BeliefMentorCognitivePattern.values.map(
                    (pattern) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(pattern.label),
                      subtitle: Text(pattern.description),
                      value: patterns.contains(pattern),
                      onChanged: (selected) => setDialogState(
                        () => selected == true
                            ? patterns.add(pattern)
                            : patterns.remove(pattern),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (statement.text.trim().isEmpty ||
                    alternative.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  BeliefMentorCandidateBelief(
                    statement: statement.text.trim(),
                    type: type,
                    trigger: trigger.text.trim(),
                    alternative: alternative.text.trim(),
                    confidence: item.confidence,
                    patterns: patterns.toList(growable: false),
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    statement.dispose();
    trigger.dispose();
    alternative.dispose();
    if (updated == null || !mounted) return;
    final candidates = diagnosis.candidates.toList(growable: true)
      ..[index] = updated;
    setState(() {
      _diagnosis = BeliefMentorDiagnosis(
        facts: diagnosis.facts,
        interpretations: diagnosis.interpretations,
        emotions: diagnosis.emotions,
        behaviorTendencies: diagnosis.behaviorTendencies,
        candidates: candidates,
        riskLevel: diagnosis.riskLevel,
        safetyMessage: diagnosis.safetyMessage,
      );
      _prepareInitialExperiment(updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4ED),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Belief Mentor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_step + 1}/4', style: theme.textTheme.labelLarge),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_step + 1) / 4,
              minHeight: 3,
              color: const Color(0xFF315B4A),
              backgroundColor: const Color(0xFFE5DED0),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: SingleChildScrollView(
                  key: ValueKey<int>(_step),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  child: switch (_step) {
                    0 => _intro(theme),
                    1 => _eventStep(theme),
                    2 => _candidateStep(theme),
                    _ => _preferenceStep(theme),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _step -= 1),
                  child: const Text('上一步'),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : switch (_step) {
                        0 => () => setState(() => _step = 1),
                        1 => _analyze,
                        2 =>
                          (_diagnosis?.blocksNormalFlow ?? false)
                              ? null
                              : () {
                                  final candidates = _diagnosis?.candidates;
                                  if (candidates == null ||
                                      candidates.isEmpty) {
                                    return;
                                  }
                                  _prepareInitialExperiment(
                                    candidates[_selectedCandidate.clamp(
                                      0,
                                      candidates.length - 1,
                                    )],
                                  );
                                  setState(() => _step = 3);
                                },
                        _ => _finish,
                      },
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _step == 1
                      ? '分析候选信念'
                      : _step == 3
                      ? '开始现实检验'
                      : '继续',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intro(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '不靠“想通”，靠现实证据更新信念。',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        '我们会把一个具体困扰拆成事实、解释、候选信念和可执行的微实验。候选由你确认，状态变化由行动与证据决定，不由 AI 单方面判定。',
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
      ),
      const SizedBox(height: 24),
      _principle(Icons.fact_check_outlined, '事实与解释分开', 'AI 推断只作为暂定假设。'),
      _principle(Icons.science_outlined, '24 小时微实验', '先做低风险、能记录结果的一步。'),
      _principle(Icons.shield_outlined, '安全与隐私优先', '云端前自动脱敏；紧急风险会停止普通教练流程。'),
      const SizedBox(height: 26),
      Text(
        '你最想先改善哪些领域？',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _domainChoices
            .map(
              (item) => FilterChip(
                label: Text(item),
                selected: _domains.contains(item),
                onSelected: (selected) {
                  if (selected && _domains.length >= 2) {
                    _show('最多选择 2 个优先领域');
                    return;
                  }
                  setState(
                    () => selected ? _domains.add(item) : _domains.remove(item),
                  );
                },
              ),
            )
            .toList(growable: false),
      ),
      const SizedBox(height: 20),
      const Card(
        color: Color(0xFFFFF5DA),
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Belief Mentor 不是医疗或心理治疗服务。如果你或他人正面临紧急危险，请立即联系当地紧急服务与可信任的人。',
          ),
        ),
      ),
    ],
  );

  Widget _eventStep(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '从一个真实时刻开始',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      const Text('不用讲完整人生故事。一个最近发生、能回忆细节的时刻就够了。'),
      const SizedBox(height: 22),
      TextField(
        controller: _event,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: '发生了什么？',
          hintText: '例：会议上我有一个想法，但最后没有发言',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _thought,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: '当时脑中冒出的原话',
          hintText: '例：如果说错，大家会觉得我不专业',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _action,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: '你做了什么，或回避了什么？',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      const Text('提交前会自动移除邮箱、电话与身份证号等直接标识信息。'),
      if (_diagnosis?.blocksNormalFlow ?? false) ...[
        const SizedBox(height: 18),
        Card(
          color: const Color(0xFFFFE7E2),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _diagnosis!.safetyMessage,
              style: const TextStyle(height: 1.5),
            ),
          ),
        ),
      ],
    ],
  );

  Widget _candidateStep(ThemeData theme) {
    final diagnosis = _diagnosis;
    if (diagnosis == null)
      return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '这些是候选，不是诊断',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _sourceBadge(),
          ],
        ),
        const SizedBox(height: 8),
        const Text('选择最贴近的一条，也可以先修改。只有你确认后，它才会进入信念地图。'),
        const SizedBox(height: 18),
        _factBox(
          '可观察事实',
          diagnosis.facts,
          onEdit: () => _editDiagnosisList('可观察事实', diagnosis.facts, 'facts'),
        ),
        _factBox(
          '解释 / 自动想法',
          diagnosis.interpretations,
          onEdit: () => _editDiagnosisList(
            '解释 / 自动想法',
            diagnosis.interpretations,
            'interpretations',
          ),
        ),
        _factBox(
          '情绪线索（请按实际感受修改）',
          diagnosis.emotions,
          onEdit: () =>
              _editDiagnosisList('情绪线索', diagnosis.emotions, 'emotions'),
        ),
        _factBox(
          '行动 / 回避倾向',
          diagnosis.behaviorTendencies,
          onEdit: () => _editDiagnosisList(
            '行动 / 回避倾向',
            diagnosis.behaviorTendencies,
            'behaviors',
          ),
        ),
        const SizedBox(height: 10),
        ...List<Widget>.generate(diagnosis.candidates.length, (index) {
          final item = diagnosis.candidates[index];
          final selected = index == _selectedCandidate;
          return Card(
            clipBehavior: Clip.antiAlias,
            color: selected ? const Color(0xFFE4EFE8) : Colors.white,
            child: InkWell(
              onTap: () => setState(() => _selectedCandidate = index),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Radio<int>(
                          value: index,
                          groupValue: _selectedCandidate,
                          onChanged: (value) =>
                              setState(() => _selectedCandidate = value ?? 0),
                        ),
                        Expanded(
                          child: Text(
                            item.statement,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _editCandidate(index),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: '修改',
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.type.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF315B4A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('替代信念：${item.alternative}'),
                          if (item.patterns.isNotEmpty ||
                              BeliefMentorCognitivePatternPolicy.detect(
                                item.statement,
                              ).isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children:
                                  <BeliefMentorCognitivePattern>{
                                        ...item.patterns,
                                        ...BeliefMentorCognitivePatternPolicy.detect(
                                          item.statement,
                                        ),
                                      }
                                      .map(
                                        (pattern) => Chip(
                                          label: Text(pattern.label),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      )
                                      .toList(growable: false),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 18),
        Text(
          '这条信念现在有多强？ ${_strength.round()}/100',
          style: theme.textTheme.titleSmall,
        ),
        Slider(
          value: _strength,
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: (value) => setState(() => _strength = value),
        ),
        const Card(
          color: Color(0xFFF2F0E8),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.radar_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '3M 思维雷达：Magnification（放大风险）· Minimization（缩小资源/进展）· Mind-reading / unsupported inference（无证据推断）。它们只是可修改的观察提示，不是诊断。',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _preferenceStep(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '选择支持方式',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      const Text('提醒不是越多越好。每天最多 2 次心理干预 + 1 次关键行动提醒，22:00–08:00 默认静默。'),
      const SizedBox(height: 22),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('开启情境提醒'),
        subtitle: const Text('晨间启动、行动前、反回避、证据捕捉与失败恢复'),
        value: _remindersEnabled,
        onChanged: (value) => setState(() => _remindersEnabled = value),
      ),
      const Divider(),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.bedtime_outlined),
        title: const Text('安静时段'),
        subtitle: Text(
          '${_quietStart.format(context)}–${_quietEnd.format(context)}',
        ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: _pickQuietHours,
      ),
      const Divider(),
      Text(
        '教练语气',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const <ButtonSegment<String>>[
          ButtonSegment(value: 'gentle', label: Text('温和')),
          ButtonSegment(value: 'coach', label: Text('教练')),
          ButtonSegment(value: 'challenger', label: Text('挑战者')),
          ButtonSegment(value: 'minimal', label: Text('极简')),
        ],
        selected: <String>{_tone},
        onSelectionChanged: (value) => setState(() => _tone = value.first),
      ),
      const SizedBox(height: 24),
      Text(
        '安排首个 24 小时微实验',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      const Text('先确认一个足够小、可观察结果的行动；完成 Onboarding 后即可开始。'),
      const SizedBox(height: 12),
      TextField(
        controller: _experimentAction,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: '要做的行动',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _experimentMinimum,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: '最小版本',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _experimentFallback,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: '如果卡住，备用动作',
          border: OutlineInputBorder(),
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule_outlined),
        title: const Text('行动时间'),
        subtitle: Text(
          '${_experimentAt.month}月${_experimentAt.day}日 '
          '${_experimentAt.hour.toString().padLeft(2, '0')}:'
          '${_experimentAt.minute.toString().padLeft(2, '0')}',
        ),
        trailing: const Icon(Icons.edit_calendar_outlined),
        onTap: _pickExperimentTime,
      ),
      Text('难度 ${_experimentDifficulty.round()}/10'),
      Slider(
        value: _experimentDifficulty,
        min: 1,
        max: 10,
        divisions: 9,
        onChanged: (value) => setState(() => _experimentDifficulty = value),
      ),
      Text(
        '预计完成概率 ${_experimentProbability.round()}%'
        '${_experimentProbability < 50 ? ' · 请继续缩小' : ''}',
      ),
      Slider(
        value: _experimentProbability,
        min: 0,
        max: 100,
        divisions: 20,
        onChanged: (value) => setState(() => _experimentProbability = value),
      ),
      const SizedBox(height: 16),
      const Card(
        color: Color(0xFFE4EFE8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('接下来会发生什么', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text(
                '1. 首个微实验会直接进入 Today\n2. 到点前只提醒最小动作\n3. 行动后记录现实结果\n4. 满足时间、行为、证据与自评分阈值后再更新信念状态',
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _principle(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFE4EFE8),
          child: Icon(icon, color: const Color(0xFF315B4A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(text),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _factBox(String title, List<String> items, {VoidCallback? onEdit}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (onEdit != null)
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: '修改',
              ),
          ],
        ),
        children: items
            .map(
              (item) => ListTile(
                dense: true,
                leading: const Icon(Icons.circle, size: 7),
                title: Text(item),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  void _prepareInitialExperiment(BeliefMentorCandidateBelief candidate) {
    if (_experimentAction.text.trim().isNotEmpty) return;
    _experimentAction.text = switch (candidate.type) {
      BeliefMentorBeliefType.relationship => '向一位相对安全的人表达一个小需求，并记录对方的实际回应',
      BeliefMentorBeliefType.capability => '用 15 分钟完成一个粗糙初稿，并保留可见结果',
      BeliefMentorBeliefType.failure => '提交一个低风险、不完美的小版本，并记录具体反馈',
      BeliefMentorBeliefType.identity => '做一件与旧身份结论不一致、可被观察到的小行动',
      BeliefMentorBeliefType.reality => '向一个可信来源核验当前判断中的一项具体事实',
      BeliefMentorBeliefType.action => '在 10 分钟内启动被回避任务的第一个可见步骤',
    };
    _experimentMinimum.text = switch (candidate.type) {
      BeliefMentorBeliefType.relationship => '先写出一句清楚、不过度解释的请求',
      BeliefMentorBeliefType.capability => '只完成标题与三条要点',
      BeliefMentorBeliefType.failure => '只提交一个最小片段或问题',
      BeliefMentorBeliefType.identity => '行动两分钟，并留下截图或文字记录',
      BeliefMentorBeliefType.reality => '写下一个可核验问题并找到一个来源',
      BeliefMentorBeliefType.action => '打开材料并完成两分钟启动',
    };
    _experimentFallback.text = '如果无法完成，就把动作再缩小一半，并重新安排具体时间';
  }

  Future<void> _editDiagnosisList(
    String title,
    List<String> current,
    String field,
  ) async {
    final controller = TextEditingController(text: current.join('\n'));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('修改$title'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '每行一条；删除不准确内容，补上你的真实描述',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final values = controller.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    controller.dispose();
    if (saved != true || !mounted) return;
    final diagnosis = _diagnosis;
    if (diagnosis == null) return;
    setState(() {
      _diagnosis = BeliefMentorDiagnosis(
        facts: field == 'facts' ? values : diagnosis.facts,
        interpretations: field == 'interpretations'
            ? values
            : diagnosis.interpretations,
        emotions: field == 'emotions' ? values : diagnosis.emotions,
        behaviorTendencies: field == 'behaviors'
            ? values
            : diagnosis.behaviorTendencies,
        candidates: diagnosis.candidates,
        riskLevel: diagnosis.riskLevel,
        safetyMessage: diagnosis.safetyMessage,
      );
    });
    await _dao.track(
      'diagnosis_section_edited',
      properties: <String, Object?>{
        'section': field,
        'item_count': values.length,
      },
    );
  }

  Future<void> _pickQuietHours() async {
    final start = await showTimePicker(
      context: context,
      initialTime: _quietStart,
      helpText: '安静时段开始',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: _quietEnd,
      helpText: '安静时段结束',
    );
    if (end == null) return;
    setState(() {
      _quietStart = start;
      _quietEnd = end;
    });
  }

  Future<void> _pickExperimentTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _experimentAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_experimentAt),
    );
    if (time == null) return;
    setState(() {
      _experimentAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  static String _timeString(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  Widget _sourceBadge() {
    final result = _diagnosisResult;
    final cloud = result?.usedCloudAi ?? false;
    return Tooltip(
      message: cloud
          ? '${result?.provider} · ${result?.model}'
          : '未配置或云端不可用时使用本地规则；不会伪装成 AI 结果',
      child: Chip(
        avatar: Icon(
          cloud ? Icons.cloud_done_outlined : Icons.phone_android_outlined,
          size: 16,
        ),
        label: Text(cloud ? 'AI 辅助' : '本地分析'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _show(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}
