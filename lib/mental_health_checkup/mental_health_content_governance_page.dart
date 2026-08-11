import 'package:flutter/material.dart';

import 'mental_health_checkup_ai_service.dart';
import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_repository.dart';
import 'mental_health_content_governance.dart';
import 'mental_health_generation_batch_page.dart';
import 'mental_health_indicator_governance_page.dart';
import 'mental_health_knowledge_base_page.dart';
import 'mental_health_knowledge_base_service.dart';
import 'mental_health_validation_page.dart';

class MentalHealthContentGovernancePage extends StatefulWidget {
  final MentalHealthCheckupCatalog catalog;
  final MentalHealthCheckupRepository repository;

  const MentalHealthContentGovernancePage({
    super.key,
    required this.catalog,
    required this.repository,
  });

  @override
  State<MentalHealthContentGovernancePage> createState() =>
      _MentalHealthContentGovernancePageState();
}

class _MentalHealthContentGovernancePageState
    extends State<MentalHealthContentGovernancePage> {
  static const MentalHealthContentGovernanceEngine _engine =
      MentalHealthContentGovernanceEngine();
  final TextEditingController _searchController = TextEditingController();
  late MentalHealthCheckupCatalog _catalog;
  List<CheckupContentGenerationPlan> _plans =
      const <CheckupContentGenerationPlan>[];
  List<CheckupContentCandidate> _candidates = const <CheckupContentCandidate>[];
  CheckupCandidateStage? _stageFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalog;
    _plans = _engine.buildGenerationQueue(_catalog.indicators);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final candidates = await widget.repository.loadContentCandidates();
    final indicatorCandidates =
        await widget.repository.loadIndicatorCandidates();
    if (!mounted) return;
    final catalog = widget.catalog
        .withGovernedIndicators(indicatorCandidates)
        .withPublishedContent(candidates);
    setState(() {
      _candidates = candidates;
      _catalog = catalog;
      _plans = _engine.buildGenerationQueue(catalog.indicators);
      _loading = false;
    });
  }

  List<CheckupContentGenerationPlan> get _filteredPlans {
    final query = _searchController.text.trim().toLowerCase();
    final matchingCandidateIds = _stageFilter == null
        ? null
        : _candidates
            .where((candidate) => candidate.stage == _stageFilter)
            .map((candidate) => candidate.primaryIndicatorId)
            .toSet();
    return _plans.where((plan) {
      if (matchingCandidateIds != null &&
          !matchingCandidateIds.contains(plan.indicatorId)) {
        return false;
      }
      if (query.isEmpty) return true;
      return plan.indicatorId.toLowerCase().contains(query) ||
          plan.indicatorName.toLowerCase().contains(query) ||
          plan.indicatorType.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  int _stageCount(CheckupCandidateStage stage) =>
      _candidates.where((candidate) => candidate.stage == stage).length;

  Future<void> _openPlan(CheckupContentGenerationPlan plan) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthContentPlanPage(
          catalog: _catalog,
          repository: widget.repository,
          plan: plan,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openIndicatorGovernance() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthIndicatorGovernancePage(
          catalog: _catalog,
          repository: widget.repository,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openKnowledgeBase() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthKnowledgeBasePage(
          catalog: _catalog,
          repository: widget.repository,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openGenerationBatches() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthGenerationBatchPage(
          catalog: _catalog,
          repository: widget.repository,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openValidationCenter() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthValidationCenterPage(
          catalog: _catalog,
          repository: widget.repository,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final plans = _filteredPlans;
    return Scaffold(
      appBar: AppBar(
        title: const Text('课程内容候选治理台'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  const _GovernanceNotice(),
                  const SizedBox(height: 14),
                  _QueueDashboard(
                    queueCount: _plans.length,
                    candidateCount: _candidates.length,
                    officialCount: _stageCount(CheckupCandidateStage.official),
                    pilotCount: _stageCount(CheckupCandidateStage.pilot),
                  ),
                  const SizedBox(height: 12),
                  _GovernanceToolbox(
                    onIndicators: _openIndicatorGovernance,
                    onKnowledge: _openKnowledgeBase,
                    onBatches: _openGenerationBatches,
                    onValidation: _openValidationCenter,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${_plans.length}项指标生成队列',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '每项均固定生成4类适配题目和B0—B4任务，共3105条版本化蓝图。'
                    '蓝图在模块首启时写入本地数据库，不把大批重复文本塞进APK。',
                    style: TextStyle(color: Color(0xFF667085), height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      labelText: '搜索指标ID、名称或类型',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        ChoiceChip(
                          label: Text('全部 ${_candidates.length}'),
                          selected: _stageFilter == null,
                          onSelected: (_) =>
                              setState(() => _stageFilter = null),
                        ),
                        const SizedBox(width: 8),
                        for (final stage in CheckupCandidateStage.values) ...[
                          ChoiceChip(
                            label: Text('${stage.label} ${_stageCount(stage)}'),
                            selected: _stageFilter == stage,
                            onSelected: (_) =>
                                setState(() => _stageFilter = stage),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (plans.isEmpty)
                    const _GovernanceEmpty(text: '没有匹配的生成计划或候选状态。')
                  else
                    for (final plan in plans)
                      _GenerationPlanTile(
                        plan: plan,
                        candidates: _candidates
                            .where(
                              (candidate) =>
                                  candidate.primaryIndicatorId ==
                                  plan.indicatorId,
                            )
                            .toList(growable: false),
                        onTap: () => _openPlan(plan),
                      ),
                ],
              ),
            ),
    );
  }
}

class MentalHealthContentPlanPage extends StatefulWidget {
  final MentalHealthCheckupCatalog catalog;
  final MentalHealthCheckupRepository repository;
  final CheckupContentGenerationPlan plan;

  const MentalHealthContentPlanPage({
    super.key,
    required this.catalog,
    required this.repository,
    required this.plan,
  });

  @override
  State<MentalHealthContentPlanPage> createState() =>
      _MentalHealthContentPlanPageState();
}

class _MentalHealthContentPlanPageState
    extends State<MentalHealthContentPlanPage> {
  static const MentalHealthContentGovernanceEngine _engine =
      MentalHealthContentGovernanceEngine();
  final MentalHealthCheckupAiService _ai = MentalHealthCheckupAiService();
  List<CheckupContentCandidate> _candidates = const <CheckupContentCandidate>[];
  bool _loading = true;
  String? _generatingCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final candidates = await widget.repository.loadContentCandidates(
      indicatorId: widget.plan.indicatorId,
    );
    if (!mounted) return;
    setState(() {
      _candidates = candidates;
      _loading = false;
    });
  }

  Future<void> _create(String code, {required bool useAi}) async {
    if (useAi) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.auto_awesome_outlined),
          title: const Text('生成AI候选草稿？'),
          content: const Text(
            '仅发送当前指标、生成规则和课程证据摘录；不会发送用户回答、报告、行动记录、安装标识或支持号码。'
            'AI只能生成草稿，不能审核、试测或签发。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('生成候选'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _generatingCode = code);
    CheckupContentCandidate candidate;
    String message;
    if (useAi) {
      final traces = await widget.repository.evidenceTracesForIndicators(
        <String>[widget.plan.indicatorId],
        limit: 12,
      );
      final knowledgeResource = await MentalHealthKnowledgeBaseService(
        repository: widget.repository,
      ).activeResource(catalog: widget.catalog);
      final result = await _ai.generateContentCandidate(
        plan: widget.plan,
        contentCode: code,
        courseVersion: widget.catalog.validation.version,
        evidenceTraces: traces,
        knowledgeResource: knowledgeResource,
      );
      candidate = result.candidate;
      message = result.message;
    } else {
      candidate = _engine.createLocalDraft(
        plan: widget.plan,
        contentCode: code,
        courseVersion: widget.catalog.validation.version,
      );
      message = '已创建本地模板草稿；课程忠实度需由独立审核人确认。';
    }
    await widget.repository.saveContentCandidate(candidate);
    if (!mounted) return;
    setState(() => _generatingCode = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    await _openCandidate(candidate);
    await _load();
  }

  Future<void> _openCandidate(CheckupContentCandidate candidate) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthContentCandidateEditorPage(
          candidate: candidate,
          repository: widget.repository,
        ),
      ),
    );
    await _load();
  }

  Widget _generationGroup({
    required String title,
    required String subtitle,
    required List<String> codes,
  }) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF667085), height: 1.4),
              ),
              const SizedBox(height: 12),
              for (final code in codes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 48,
                        child: Text(
                          code,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _generatingCode == null
                              ? () => _create(code, useAi: false)
                              : null,
                          icon: const Icon(Icons.offline_bolt_outlined),
                          label: const Text('本地草稿'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _generatingCode == null
                              ? () => _create(code, useAi: true)
                              : null,
                          icon: _generatingCode == code
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome_outlined),
                          label: const Text('AI候选'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.plan.indicatorId)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  Card(
                    color: const Color(0xFFF3F6FF),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.plan.indicatorName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: <Widget>[
                              _GovernancePill(
                                text: 'Lecture ${widget.plan.lecture}',
                              ),
                              _GovernancePill(text: widget.plan.indicatorType),
                              _GovernancePill(text: widget.plan.sourceLevel),
                              _GovernancePill(text: widget.plan.reviewStatus),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '证据ID：${widget.plan.evidenceIds.join('、')}',
                            style: const TextStyle(height: 1.45),
                          ),
                          if (widget.plan.guardrailIndicatorIds.isNotEmpty)
                            Text(
                              '制衡指标：${widget.plan.guardrailIndicatorIds.join('、')}',
                              style: const TextStyle(height: 1.45),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _generationGroup(
                    title: '九类题型计划',
                    subtitle: '按指标类型限定必生成组合；AI不能改动primary_indicator_id。',
                    codes: widget.plan.itemTypeCodes,
                  ),
                  const SizedBox(height: 10),
                  _generationGroup(
                    title: 'B0—B4行为计划',
                    subtitle: '基线、探针、实验、仪式和迁移分层生成，行为基线不被干预表现回写。',
                    codes: widget.plan.behaviorLevels,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '候选版本 · ${_candidates.length}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_candidates.isEmpty)
                    const _GovernanceEmpty(
                      text: '尚无候选。可先创建本地草稿，或让用户配置的AI基于课程证据生成草稿。',
                    )
                  else
                    for (final candidate in _candidates)
                      _CandidateTile(
                        candidate: candidate,
                        onTap: () => _openCandidate(candidate),
                      ),
                ],
              ),
      );
}

class MentalHealthContentCandidateEditorPage extends StatefulWidget {
  final CheckupContentCandidate candidate;
  final MentalHealthCheckupRepository repository;

  const MentalHealthContentCandidateEditorPage({
    super.key,
    required this.candidate,
    required this.repository,
  });

  @override
  State<MentalHealthContentCandidateEditorPage> createState() =>
      _MentalHealthContentCandidateEditorPageState();
}

class _MentalHealthContentCandidateEditorPageState
    extends State<MentalHealthContentCandidateEditorPage> {
  static const MentalHealthContentGovernanceEngine _engine =
      MentalHealthContentGovernanceEngine();
  late CheckupContentCandidate _candidate;
  late final TextEditingController _contentController;
  late final TextEditingController _scaleController;
  late final TextEditingController _directionController;
  late final TextEditingController _windowController;
  late final TextEditingController _rationaleController;
  late final TextEditingController _safetyController;
  late final TextEditingController _smallerController;
  late final TextEditingController _counterController;
  late final TextEditingController _authorController;
  late final TextEditingController _pilotSampleController;
  late final TextEditingController _pilotNotesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _candidate = widget.candidate;
    _contentController = TextEditingController(text: _candidate.content);
    _scaleController = TextEditingController(text: _candidate.scaleOrDuration);
    _directionController = TextEditingController(
      text: _candidate.scoringDirection,
    );
    _windowController = TextEditingController(text: _candidate.recallWindow);
    _rationaleController = TextEditingController(
      text: _candidate.constructRationale,
    );
    _safetyController = TextEditingController(text: _candidate.safetyRule);
    _smallerController = TextEditingController(text: _candidate.smallerVersion);
    _counterController = TextEditingController(
      text: _candidate.counterEvidencePrompt,
    );
    _authorController = TextEditingController(text: _candidate.author);
    _pilotSampleController = TextEditingController(
      text: '${_candidate.pilotSampleSize}',
    );
    _pilotNotesController = TextEditingController(text: _candidate.pilotNotes);
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _contentController,
      _scaleController,
      _directionController,
      _windowController,
      _rationaleController,
      _safetyController,
      _smallerController,
      _counterController,
      _authorController,
      _pilotSampleController,
      _pilotNotesController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  CheckupContentCandidate _fromForm() => _candidate.copyWith(
        content: _contentController.text.trim(),
        scaleOrDuration: _scaleController.text.trim(),
        scoringDirection: _directionController.text.trim(),
        recallWindow: _windowController.text.trim(),
        constructRationale: _rationaleController.text.trim(),
        safetyRule: _safetyController.text.trim(),
        smallerVersion: _smallerController.text.trim(),
        counterEvidencePrompt: _counterController.text.trim(),
        author: _authorController.text.trim(),
        pilotSampleSize: int.tryParse(_pilotSampleController.text.trim()) ?? 0,
        pilotNotes: _pilotNotesController.text.trim(),
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );

  Future<void> _save({bool showMessage = true}) async {
    if (_candidate.isReadOnly) return;
    setState(() => _saving = true);
    final value = _fromForm();
    await widget.repository.saveContentCandidate(value);
    if (!mounted) return;
    setState(() {
      _candidate = value;
      _saving = false;
    });
    if (showMessage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('候选草稿与质量记录已保存在本机。')));
    }
  }

  Future<_GovernanceAuditInput?> _askAuditInput(String title) async {
    final actor = TextEditingController();
    final note = TextEditingController();
    final result = await showDialog<_GovernanceAuditInput>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: actor,
                decoration: const InputDecoration(
                  labelText: '操作人/审核人',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '依据、结果或原因',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (actor.text.trim().isEmpty) return;
              Navigator.of(context).pop(
                _GovernanceAuditInput(
                  actor: actor.text.trim(),
                  note: note.text.trim(),
                ),
              );
            },
            child: const Text('确认并留痕'),
          ),
        ],
      ),
    );
    actor.dispose();
    note.dispose();
    return result;
  }

  CheckupCandidateStage? get _nextStage => switch (_candidate.stage) {
        CheckupCandidateStage.draft => CheckupCandidateStage.candidate,
        CheckupCandidateStage.candidate =>
          CheckupCandidateStage.cognitiveInterview,
        CheckupCandidateStage.cognitiveInterview => CheckupCandidateStage.pilot,
        CheckupCandidateStage.pilot => CheckupCandidateStage.official,
        CheckupCandidateStage.official => CheckupCandidateStage.retired,
        CheckupCandidateStage.retired => null,
      };

  Future<void> _advance() async {
    final target = _nextStage;
    if (target == null) return;
    if (!_candidate.isReadOnly) await _save(showMessage: false);
    if (!mounted) return;
    final input = await _askAuditInput(
      target == CheckupCandidateStage.retired ? '停用正式版本' : '进入${target.label}',
    );
    if (input == null || !mounted) return;
    try {
      final transition = _engine.transition(
        candidate: _candidate,
        target: target,
        actor: input.actor,
        note: input.note,
      );
      await widget.repository.saveContentTransition(transition);
      if (!mounted) return;
      setState(() => _candidate = transition.candidate);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已进入${target.label}并写入审计记录。')));
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.rule_folder_outlined,
            color: Color(0xFFC05621),
          ),
          title: const Text('状态门槛尚未满足'),
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('继续完善'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _revise() async {
    final input = await _askAuditInput('派生新修订版');
    if (input == null || !mounted) return;
    final revision = _engine.reviseOfficial(
      official: _candidate,
      author: input.actor,
    );
    await widget.repository.saveContentCandidate(revision);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _setQuality(CheckupCandidateQuality value) {
    setState(() => _candidate = _candidate.copyWith(quality: value));
  }

  Future<void> _openValidation() async {
    if (!_candidate.isReadOnly) await _save(showMessage: false);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthCandidateValidationPage(
          candidateId: _candidate.candidateId,
          repository: widget.repository,
        ),
      ),
    );
    final updated = await widget.repository.loadContentCandidate(
      _candidate.candidateId,
    );
    if (!mounted || updated == null) return;
    setState(() {
      _candidate = updated;
      _pilotSampleController.text = '${updated.pilotSampleSize}';
      _pilotNotesController.text = updated.pilotNotes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = _candidate.isReadOnly;
    final validation = _engine.validate(_fromForm());
    return Scaffold(
      appBar: AppBar(
        title: Text('${_candidate.contentCode} · V${_candidate.version}'),
        actions: <Widget>[
          if (!readOnly)
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('保存'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: <Widget>[
          _CandidateStageHeader(candidate: _candidate),
          const SizedBox(height: 12),
          _GovernanceGateCard(validation: validation),
          const SizedBox(height: 16),
          const _EditorSectionTitle(
            title: '候选内容',
            subtitle: 'candidate_id和primary_indicator_id不可由AI改写。',
          ),
          const SizedBox(height: 10),
          _EditorField(
            controller: _contentController,
            label: '题干或任务',
            enabled: !readOnly,
            minLines: 3,
          ),
          _EditorField(
            controller: _scaleController,
            label: '量尺或期限',
            enabled: !readOnly,
          ),
          _EditorField(
            controller: _directionController,
            label: '计分方向',
            enabled: !readOnly,
          ),
          _EditorField(
            controller: _windowController,
            label: '回忆时间窗',
            enabled: !readOnly,
          ),
          if (_candidate.answerOptions.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '情境判断选项',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    for (var index = 0;
                        index < _candidate.answerOptions.length;
                        index++)
                      Text(
                        '${index == _candidate.correctAnswerIndex ? '✓' : '○'} '
                        '${_candidate.answerOptions[index]}',
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          const _EditorSectionTitle(
            title: '证据、构念与安全',
            subtitle: 'C1/C2、制衡指标和安全规则必须显式保留。',
          ),
          const SizedBox(height: 10),
          _ReadOnlyValue(
            label: '课程证据ID',
            value: _candidate.courseEvidenceIds.join('、'),
          ),
          _ReadOnlyValue(label: '来源等级', value: _candidate.sourceLevel),
          _ReadOnlyValue(
            label: '制衡指标',
            value: _candidate.guardrailIndicatorIds.isEmpty
                ? '待人工绑定'
                : _candidate.guardrailIndicatorIds.join('、'),
          ),
          _EditorField(
            controller: _rationaleController,
            label: '单一构念理由',
            enabled: !readOnly,
            minLines: 2,
          ),
          _EditorField(
            controller: _safetyController,
            label: '安全/停止规则',
            enabled: !readOnly,
            minLines: 2,
          ),
          if (_candidate.kind == CheckupContentKind.behaviorTask) ...[
            _EditorField(
              controller: _smallerController,
              label: '更小版本',
              enabled: !readOnly,
              minLines: 2,
            ),
            _EditorField(
              controller: _counterController,
              label: '反证、跨情境或恢复预案证据',
              enabled: !readOnly,
              minLines: 2,
            ),
          ],
          const SizedBox(height: 16),
          const _EditorSectionTitle(
            title: '质量评分',
            subtitle: 'AI只能建议分数；人工仍需逐项核验，门槛不可被总分掩盖。',
          ),
          const SizedBox(height: 8),
          _QualityEditor(
            value: _candidate.quality,
            enabled: !readOnly,
            onChanged: _setQuality,
          ),
          const SizedBox(height: 16),
          const _EditorSectionTitle(
            title: '人工门槛',
            subtitle: '状态只由当前内容指纹对应的真实记录计算，不能手工勾选。',
          ),
          const SizedBox(height: 8),
          _EditorField(
            controller: _authorController,
            label: '作者/生成来源',
            enabled: !readOnly,
          ),
          Card(
            color: const Color(0xFFEEF4FF),
            child: ListTile(
              onTap: _saving ? null : _openValidation,
              leading: const CircleAvatar(
                child: Icon(Icons.verified_user_outlined),
              ),
              title: const Text(
                '录入和计算验证证据',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('专家审核 · 认知访谈 · 试测统计 · 内容指纹校验'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _candidate.evidenceReviewPassed,
            onChanged: null,
            title: const Text('课程证据相关性已独立审核'),
            subtitle: const Text('由通过的课程专家记录自动计算。'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _candidate.constructReviewPassed,
            onChanged: null,
            title: const Text('单一构念与量尺适配已审核'),
            subtitle: const Text('由独立测量审核记录自动计算。'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _candidate.cognitiveInterviewPassed,
            onChanged: null,
            title: const Text('目标用户认知访谈通过'),
            subtitle: const Text('由去重后的匿名访谈样本和预设阈值计算。'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _candidate.pilotPassed,
            onChanged: null,
            title: const Text('小样本试测通过'),
            subtitle: const Text('由缺失、耗时、相关、公平性和报警校准自动计算。'),
          ),
          _EditorField(
            controller: _pilotSampleController,
            label: '试测样本数',
            enabled: false,
            keyboardType: TextInputType.number,
          ),
          _EditorField(
            controller: _pilotNotesController,
            label: '试测结果与校准记录',
            enabled: false,
            minLines: 2,
          ),
          const SizedBox(height: 16),
          const _EditorSectionTitle(
            title: '版本与审计',
            subtitle: '正式内容不可覆盖；修订必须派生新candidate_id和版本。',
          ),
          const SizedBox(height: 8),
          _ReadOnlyValue(label: 'candidate_id', value: _candidate.candidateId),
          _ReadOnlyValue(
            label: 'primary_indicator_id',
            value: _candidate.primaryIndicatorId,
          ),
          _ReadOnlyValue(
            label: '模型/Prompt',
            value: '${_candidate.modelVersion} / ${_candidate.promptVersion}',
          ),
          _ReadOnlyValue(
            label: '指标/课程版本',
            value:
                '${_candidate.indicatorVersion} / ${_candidate.courseVersion}',
          ),
          if (_candidate.reviewer.isNotEmpty)
            _ReadOnlyValue(label: '独立审核人', value: _candidate.reviewer),
          if (_candidate.signer.isNotEmpty)
            _ReadOnlyValue(label: '签发人', value: _candidate.signer),
          FutureBuilder<List<CheckupContentAuditEvent>>(
            future: widget.repository.loadContentAudit(_candidate.candidateId),
            builder: (context, snapshot) => _AuditTimeline(
              events: snapshot.data ?? const <CheckupContentAuditEvent>[],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE4E7EC))),
          ),
          child: Row(
            children: <Widget>[
              if (_candidate.isReadOnly)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _revise,
                    icon: const Icon(Icons.fork_right_outlined),
                    label: const Text('派生新修订版'),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存草稿'),
                  ),
                ),
              if (_nextStage != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _advance,
                    icon: Icon(
                      _nextStage == CheckupCandidateStage.official
                          ? Icons.verified_outlined
                          : _nextStage == CheckupCandidateStage.retired
                              ? Icons.block_outlined
                              : Icons.arrow_forward,
                    ),
                    label: Text(
                      _nextStage == CheckupCandidateStage.official
                          ? '人工签发'
                          : _nextStage == CheckupCandidateStage.retired
                              ? '停用'
                              : '进入${_nextStage!.label}',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GovernanceNotice extends StatelessWidget {
  const _GovernanceNotice();

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFF7ED),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.gavel_outlined, color: Color(0xFFB54708)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '这是本地课程内容治理工作台，不是用户体检结论页。AI只能提出候选；'
                  '任何正式内容都必须经过独立证据审核、认知访谈、小样本试测和人工签发。',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
}

class _GovernanceToolbox extends StatelessWidget {
  final VoidCallback onIndicators;
  final VoidCallback onKnowledge;
  final VoidCallback onBatches;
  final VoidCallback onValidation;

  const _GovernanceToolbox({
    required this.onIndicators,
    required this.onKnowledge,
    required this.onBatches,
    required this.onValidation,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: <Widget>[
            ListTile(
              onTap: onIndicators,
              leading: const CircleAvatar(
                child: Icon(Icons.travel_explore_outlined),
              ),
              title: const Text(
                '候选指标发现与治理',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('AI/本地发现 · 证据复核 · 专家审核 · 访谈 · 试测 · 签发'),
              trailing: const Icon(Icons.chevron_right),
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              onTap: onBatches,
              leading: const CircleAvatar(
                child: Icon(Icons.playlist_play_outlined),
              ),
              title: const Text(
                '批量生成题目与B0—B4任务',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('持久队列 · 分块继续 · 失败重试 · 不自动发布'),
              trailing: const Icon(Icons.chevron_right),
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              onTap: onValidation,
              leading: const CircleAvatar(
                child: Icon(Icons.verified_user_outlined),
              ),
              title: const Text(
                '专家与真实用户验证中心',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('内容指纹 · 独立评审 · 访谈 · 试测 · 统计门槛'),
              trailing: const Icon(Icons.chevron_right),
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              onTap: onKnowledge,
              leading:
                  const CircleAvatar(child: Icon(Icons.cloud_sync_outlined)),
              title: const Text(
                'AI课程知识库与文件ID',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('默认本地RAG · 可选首次上传 · 哈希校验 · 可解除关联'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      );
}

class _QueueDashboard extends StatelessWidget {
  final int queueCount;
  final int candidateCount;
  final int officialCount;
  final int pilotCount;

  const _QueueDashboard({
    required this.queueCount,
    required this.candidateCount,
    required this.officialCount,
    required this.pilotCount,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: _QueueMetric(
              value: '$queueCount',
              label: '指标计划',
              color: const Color(0xFF4554C5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QueueMetric(
              value: '$candidateCount',
              label: '候选版本',
              color: const Color(0xFF7A4E9D),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QueueMetric(
              value: '$pilotCount',
              label: '试测',
              color: const Color(0xFFB54708),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QueueMetric(
              value: '$officialCount',
              label: '正式',
              color: const Color(0xFF39715D),
            ),
          ),
        ],
      );
}

class _QueueMetric extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _QueueMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
            ),
          ],
        ),
      );
}

class _GenerationPlanTile extends StatelessWidget {
  final CheckupContentGenerationPlan plan;
  final List<CheckupContentCandidate> candidates;
  final VoidCallback onTap;

  const _GenerationPlanTile({
    required this.plan,
    required this.candidates,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF4554C5).withValues(alpha: 0.11),
            child: Text(
              '${plan.lecture}',
              style: const TextStyle(
                color: Color(0xFF4554C5),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          title: Text(
            '${plan.indicatorId} · ${plan.indicatorName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${plan.indicatorType} · '
            '${plan.itemTypeCodes.join('/')} · B0/B1/B2/B3/B4\n'
            '${plan.evidenceIds.length}个证据位置 · ${plan.reviewStatus}',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '${candidates.length}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
}

class _CandidateTile extends StatelessWidget {
  final CheckupContentCandidate candidate;
  final VoidCallback onTap;

  const _CandidateTile({required this.candidate, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(child: Text(candidate.contentCode)),
          title: Text(
            candidate.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'V${candidate.version} · ${candidate.stage.label} · '
            '质量 ${candidate.quality.overall.toStringAsFixed(0)} · '
            '${candidate.author}',
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class _CandidateStageHeader extends StatelessWidget {
  final CheckupContentCandidate candidate;

  const _CandidateStageHeader({required this.candidate});

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFF3F6FF),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${candidate.primaryIndicatorId} · ${candidate.indicatorName}',
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  _GovernancePill(text: candidate.kind.label),
                  _GovernancePill(text: candidate.indicatorType),
                  _GovernancePill(text: candidate.stage.label),
                  _GovernancePill(text: 'V${candidate.version}'),
                ],
              ),
            ],
          ),
        ),
      );
}

class _GovernanceGateCard extends StatelessWidget {
  final CheckupCandidateValidation validation;

  const _GovernanceGateCard({required this.validation});

  @override
  Widget build(BuildContext context) => Card(
        color: validation.valid
            ? const Color(0xFFECFDF3)
            : const Color(0xFFFFF7ED),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    validation.valid
                        ? Icons.check_circle_outline
                        : Icons.rule_outlined,
                    color: validation.valid
                        ? const Color(0xFF39715D)
                        : const Color(0xFFB54708),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    validation.valid
                        ? '自动质量门已通过'
                        : '仍有 ${validation.blockingIssues.length} 项阻断门槛',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              if (validation.blockingIssues.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final issue in validation.blockingIssues)
                  Text('• $issue', style: const TextStyle(height: 1.4)),
              ],
              if (validation.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final warning in validation.warnings)
                  Text(
                    '提示：$warning',
                    style:
                        const TextStyle(color: Color(0xFF667085), height: 1.4),
                  ),
              ],
            ],
          ),
        ),
      );
}

class _QualityEditor extends StatelessWidget {
  final CheckupCandidateQuality value;
  final bool enabled;
  final ValueChanged<CheckupCandidateQuality> onChanged;

  const _QualityEditor({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '综合质量',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    value.overall.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              _QualitySlider(
                label: '指标一致性',
                value: value.indicatorConsistency,
                threshold: 75,
                enabled: enabled,
                onChanged: (score) =>
                    onChanged(value.copyWith(indicatorConsistency: score)),
              ),
              _QualitySlider(
                label: '课程忠实度',
                value: value.courseFidelity,
                threshold: 80,
                enabled: enabled,
                onChanged: (score) =>
                    onChanged(value.copyWith(courseFidelity: score)),
              ),
              _QualitySlider(
                label: '非重复性',
                value: value.nonDuplication,
                enabled: enabled,
                onChanged: (score) =>
                    onChanged(value.copyWith(nonDuplication: score)),
              ),
              _QualitySlider(
                label: '可测量性',
                value: value.measurability,
                enabled: enabled,
                onChanged: (score) =>
                    onChanged(value.copyWith(measurability: score)),
              ),
              _QualitySlider(
                label: '量尺/时间窗',
                value: value.scaleWindowFit,
                threshold: 80,
                enabled: enabled,
                onChanged: (score) =>
                    onChanged(value.copyWith(scaleWindowFit: score)),
              ),
              _QualitySlider(
                label: '双向/制衡逻辑',
                value: value.bidirectionalLogic,
                enabled: enabled,
                onChanged: (score) =>
                    onChanged(value.copyWith(bidirectionalLogic: score)),
              ),
              _QualitySlider(
                label: '安全性',
                value: value.safety,
                threshold: 90,
                enabled: enabled,
                onChanged: (score) => onChanged(value.copyWith(safety: score)),
              ),
            ],
          ),
        ),
      );
}

class _QualitySlider extends StatelessWidget {
  final String label;
  final double value;
  final double? threshold;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _QualitySlider({
    required this.label,
    required this.value,
    this.threshold,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label)),
              Text(
                '${value.toStringAsFixed(0)}'
                '${threshold == null ? '' : ' / ≥${threshold!.toStringAsFixed(0)}'}',
                style: TextStyle(
                  color: threshold != null && value < threshold!
                      ? const Color(0xFFC05621)
                      : const Color(0xFF39715D),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(0, 100).toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      );
}

class _EditorSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EditorSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF667085), height: 1.4),
          ),
        ],
      );
}

class _EditorField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final int minLines;
  final TextInputType? keyboardType;

  const _EditorField({
    required this.controller,
    required this.label,
    required this.enabled,
    this.minLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: minLines == 1 ? 1 : minLines + 3,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: minLines > 1,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

class _ReadOnlyValue extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
              const SizedBox(height: 3),
              SelectableText(value.isEmpty ? '—' : value),
            ],
          ),
        ),
      );
}

class _AuditTimeline extends StatelessWidget {
  final List<CheckupContentAuditEvent> events;

  const _AuditTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _GovernanceEmpty(text: '尚无状态变更审计记录。');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            for (final event in events)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(
                  '${event.fromStage.label} → ${event.toStage.label}',
                ),
                subtitle: Text(
                  '${event.actor} · ${event.note.isEmpty ? '无备注' : event.note}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GovernancePill extends StatelessWidget {
  final String text;

  const _GovernancePill({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD0D5DD)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
}

class _GovernanceEmpty extends StatelessWidget {
  final String text;

  const _GovernanceEmpty({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.inbox_outlined, color: Color(0xFF667085)),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _GovernanceAuditInput {
  final String actor;
  final String note;

  const _GovernanceAuditInput({required this.actor, required this.note});
}
