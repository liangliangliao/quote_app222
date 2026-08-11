import 'package:flutter/material.dart';

import 'mental_health_checkup_ai_service.dart';
import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_repository.dart';
import 'mental_health_content_governance.dart';
import 'mental_health_indicator_governance.dart';
import 'mental_health_knowledge_base_service.dart';

class MentalHealthIndicatorGovernancePage extends StatefulWidget {
  final MentalHealthCheckupCatalog catalog;
  final MentalHealthCheckupRepository repository;

  const MentalHealthIndicatorGovernancePage({
    super.key,
    required this.catalog,
    required this.repository,
  });

  @override
  State<MentalHealthIndicatorGovernancePage> createState() =>
      _MentalHealthIndicatorGovernancePageState();
}

class _MentalHealthIndicatorGovernancePageState
    extends State<MentalHealthIndicatorGovernancePage> {
  final MentalHealthCheckupAiService _ai = MentalHealthCheckupAiService();
  late final MentalHealthKnowledgeBaseService _knowledgeBase;
  final TextEditingController _searchController = TextEditingController();
  List<CheckupIndicatorCandidate> _candidates =
      const <CheckupIndicatorCandidate>[];
  CheckupCandidateStage? _stageFilter;
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _knowledgeBase = MentalHealthKnowledgeBaseService(
      repository: widget.repository,
    );
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final candidates = await widget.repository.loadIndicatorCandidates();
    if (!mounted) return;
    setState(() {
      _candidates = candidates;
      _loading = false;
    });
  }

  int _count(CheckupCandidateStage stage) =>
      _candidates.where((candidate) => candidate.stage == stage).length;

  List<CheckupIndicatorCandidate> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _candidates.where((candidate) {
      if (_stageFilter != null && candidate.stage != _stageFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return candidate.proposedIndicatorId.toLowerCase().contains(query) ||
          candidate.name.toLowerCase().contains(query) ||
          candidate.area.toLowerCase().contains(query) ||
          '${candidate.lecture}'.contains(query);
    }).toList(growable: false);
  }

  Future<void> _discover() async {
    var lecture = 1;
    var area = widget.catalog.indicators
        .firstWhere(
          (indicator) => indicator.lecture == lecture,
          orElse: () => widget.catalog.indicators.first,
        )
        .area;
    var useAi = true;
    final input = await showDialog<_IndicatorDiscoveryInput>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.travel_explore_outlined),
          title: const Text('发现候选指标'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<int>(
                  initialValue: lecture,
                  decoration: const InputDecoration(
                    labelText: '目标讲次',
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<int>>[
                    for (var value = 1; value <= 23; value++)
                      DropdownMenuItem<int>(
                        value: value,
                        child: Text('Lecture $value'),
                      ),
                  ],
                  onChanged: (value) {
                    final next = value ?? 1;
                    final lectureIndicators = widget.catalog.indicators.where(
                      (indicator) => indicator.lecture == next,
                    );
                    setDialogState(() {
                      lecture = next;
                      if (lectureIndicators.isNotEmpty) {
                        area = lectureIndicators.first.area;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey<String>('area-$lecture-$area'),
                  initialValue: area,
                  decoration: const InputDecoration(
                    labelText: '拟归属领域',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => area = value,
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.auto_awesome_outlined),
                      label: Text('AI发现'),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.edit_note_outlined),
                      label: Text('本地骨架'),
                    ),
                  ],
                  selected: <bool>{useAi},
                  onSelectionChanged: (values) =>
                      setDialogState(() => useAi = values.first),
                ),
                const SizedBox(height: 12),
                Text(
                  useAi
                      ? 'AI只读该讲课程知识和现有指标清单，提出一个可追溯'
                          '草稿；指标ID由本机生成，AI不能审核或签发。'
                      : '只建立本地治理骨架，由编辑者自行填写课程证据、'
                          '构念和质量记录。',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    height: 1.45,
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
              onPressed: () => Navigator.of(context).pop(
                _IndicatorDiscoveryInput(
                  lecture: lecture,
                  area: area.trim(),
                  useAi: useAi,
                ),
              ),
              child: const Text('创建草稿'),
            ),
          ],
        ),
      ),
    );
    if (input == null || !mounted) return;
    if (input.useAi) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('生成AI候选指标？'),
          content: const Text(
            '请求仅含课程原文位置、现有指标和治理规则，不包含用户回答、'
            '报告、行动记录或设备标识。若已启用供应商课程文件ID则复用；'
            '否则使用本地摘录。AI输出始终停留在草稿阶段。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认生成'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _generating = true);
    try {
      final traces = await widget.repository.evidenceTracesForLecture(
        input.lecture,
        limit: 80,
      );
      CheckupIndicatorCandidate candidate;
      String message;
      if (input.useAi) {
        final resource = await _knowledgeBase.activeResource(
          catalog: widget.catalog,
        );
        final result = await _ai.generateIndicatorCandidate(
          lecture: input.lecture,
          area: input.area,
          courseVersion: widget.catalog.validation.version,
          evidenceTraces: traces,
          existingIndicators: widget.catalog.indicators,
          knowledgeResource: resource,
        );
        candidate = result.candidate;
        message = result.message;
      } else {
        candidate =
            const MentalHealthIndicatorGovernanceEngine().createLocalDraft(
          lecture: input.lecture,
          area: input.area,
          courseVersion: widget.catalog.validation.version,
          evidenceLocationIds: traces
              .map((trace) => trace.locationId)
              .take(12)
              .toList(growable: false),
          existingIndicatorIds: widget.catalog.indicators
              .where((indicator) => indicator.lecture == input.lecture)
              .map((indicator) => indicator.id)
              .toList(growable: false),
        );
        message = '已建立本地候选指标治理骨架。';
      }
      await widget.repository.saveIndicatorCandidate(candidate);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MentalHealthIndicatorCandidateEditorPage(
            candidate: candidate,
            catalog: widget.catalog,
            repository: widget.repository,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('候选指标创建失败：$error')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
    await _load();
  }

  Future<void> _open(CheckupIndicatorCandidate candidate) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthIndicatorCandidateEditorPage(
          candidate: candidate,
          catalog: widget.catalog,
          repository: widget.repository,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('候选指标治理'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: _loading || _generating ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generating ? null : _discover,
        icon: _generating
            ? const SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_generating ? '正在生成' : '发现候选'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: <Widget>[
                  const _IndicatorGovernanceNotice(),
                  const SizedBox(height: 12),
                  _IndicatorMetrics(
                    total: _candidates.length,
                    candidate: _count(CheckupCandidateStage.candidate),
                    pilot: _count(CheckupCandidateStage.pilot),
                    official: _count(CheckupCandidateStage.official),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: '搜索候选ID、名称、领域或讲次',
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
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
                        const SizedBox(width: 7),
                        for (final stage in CheckupCandidateStage.values) ...[
                          ChoiceChip(
                            label: Text('${stage.label} ${_count(stage)}'),
                            selected: _stageFilter == stage,
                            onSelected: (_) =>
                                setState(() => _stageFilter = stage),
                          ),
                          const SizedBox(width: 7),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (candidates.isEmpty)
                    const _IndicatorEmpty()
                  else
                    for (final candidate in candidates)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => _open(candidate),
                          contentPadding: const EdgeInsets.fromLTRB(
                            14,
                            8,
                            10,
                            8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(
                              0xFF4554C5,
                            ).withValues(alpha: 0.11),
                            child: Text(
                              '${candidate.lecture}',
                              style: const TextStyle(
                                color: Color(0xFF4554C5),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          title: Text(
                            candidate.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${candidate.proposedIndicatorId}\n'
                            '${candidate.area} · ${candidate.indicatorType} · '
                            '${candidate.stage.label} · '
                            '${candidate.quality.overall.toStringAsFixed(0)}分',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class MentalHealthIndicatorCandidateEditorPage extends StatefulWidget {
  final CheckupIndicatorCandidate candidate;
  final MentalHealthCheckupCatalog catalog;
  final MentalHealthCheckupRepository repository;

  const MentalHealthIndicatorCandidateEditorPage({
    super.key,
    required this.candidate,
    required this.catalog,
    required this.repository,
  });

  @override
  State<MentalHealthIndicatorCandidateEditorPage> createState() =>
      _MentalHealthIndicatorCandidateEditorPageState();
}

class _MentalHealthIndicatorCandidateEditorPageState
    extends State<MentalHealthIndicatorCandidateEditorPage> {
  static const MentalHealthIndicatorGovernanceEngine _engine =
      MentalHealthIndicatorGovernanceEngine();
  late CheckupIndicatorCandidate _candidate;
  late final TextEditingController _area;
  late final TextEditingController _name;
  late final TextEditingController _definition;
  late final TextEditingController _low;
  late final TextEditingController _high;
  late final TextEditingController _misuse;
  late final TextEditingController _function;
  late final TextEditingController _definitionLocation;
  late final TextEditingController _lowLocation;
  late final TextEditingController _highLocation;
  late final TextEditingController _actionLocation;
  late final TextEditingController _evidenceIds;
  late final TextEditingController _guardrailIds;
  late final TextEditingController _duplicateIds;
  late final TextEditingController _rationale;
  late final TextEditingController _safety;
  late final TextEditingController _author;
  late final TextEditingController _pilotSample;
  late final TextEditingController _pilotNotes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _candidate = widget.candidate;
    _area = TextEditingController(text: _candidate.area);
    _name = TextEditingController(text: _candidate.name);
    _definition = TextEditingController(text: _candidate.definition);
    _low = TextEditingController(text: _candidate.lowPattern);
    _high = TextEditingController(text: _candidate.highPattern);
    _misuse = TextEditingController(text: _candidate.misuseRisk);
    _function = TextEditingController(text: _candidate.functionalSignal);
    _definitionLocation = TextEditingController(
      text: _candidate.definitionLocation,
    );
    _lowLocation = TextEditingController(text: _candidate.lowLocation);
    _highLocation = TextEditingController(text: _candidate.highLocation);
    _actionLocation = TextEditingController(text: _candidate.actionLocation);
    _evidenceIds = TextEditingController(
      text: _candidate.evidenceLocationIds.join(', '),
    );
    _guardrailIds = TextEditingController(
      text: _candidate.guardrailIndicatorIds.join(', '),
    );
    _duplicateIds = TextEditingController(
      text: _candidate.possibleDuplicateIndicatorIds.join(', '),
    );
    _rationale = TextEditingController(text: _candidate.constructRationale);
    _safety = TextEditingController(text: _candidate.safetyBoundary);
    _author = TextEditingController(text: _candidate.author);
    _pilotSample = TextEditingController(text: '${_candidate.pilotSampleSize}');
    _pilotNotes = TextEditingController(text: _candidate.pilotNotes);
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _area,
      _name,
      _definition,
      _low,
      _high,
      _misuse,
      _function,
      _definitionLocation,
      _lowLocation,
      _highLocation,
      _actionLocation,
      _evidenceIds,
      _guardrailIds,
      _duplicateIds,
      _rationale,
      _safety,
      _author,
      _pilotSample,
      _pilotNotes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  CheckupIndicatorCandidate _fromForm() => _candidate.copyWith(
        area: _area.text.trim(),
        name: _name.text.trim(),
        definition: _definition.text.trim(),
        lowPattern: _low.text.trim(),
        highPattern: _high.text.trim(),
        misuseRisk: _misuse.text.trim(),
        functionalSignal: _function.text.trim(),
        definitionLocation: _definitionLocation.text.trim(),
        lowLocation: _lowLocation.text.trim(),
        highLocation: _highLocation.text.trim(),
        actionLocation: _actionLocation.text.trim(),
        evidenceLocationIds: _splitIds(_evidenceIds.text),
        guardrailIndicatorIds: _splitIds(_guardrailIds.text),
        possibleDuplicateIndicatorIds: _splitIds(_duplicateIds.text),
        constructRationale: _rationale.text.trim(),
        safetyBoundary: _safety.text.trim(),
        author: _author.text.trim(),
        pilotSampleSize: int.tryParse(_pilotSample.text.trim()) ?? 0,
        pilotNotes: _pilotNotes.text.trim(),
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );

  Future<void> _save({bool showMessage = true}) async {
    if (_candidate.isReadOnly) return;
    setState(() => _saving = true);
    try {
      final value = _fromForm();
      await widget.repository.saveIndicatorCandidate(value);
      if (!mounted) return;
      setState(() => _candidate = value);
      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('候选指标与门禁记录已保存在本机。')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  Future<_IndicatorAuditInput?> _askAudit(String title) async {
    final actor = TextEditingController();
    final note = TextEditingController();
    final result = await showDialog<_IndicatorAuditInput>(
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
                  labelText: '操作人/独立审核人/签发人',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '证据、结果或状态变更原因',
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
                _IndicatorAuditInput(
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

  Future<void> _advance() async {
    final target = _nextStage;
    if (target == null) return;
    if (!_candidate.isReadOnly) await _save(showMessage: false);
    if (!mounted) return;
    final input = await _askAudit(
      target == CheckupCandidateStage.retired ? '停用正式指标' : '进入${target.label}',
    );
    if (input == null || !mounted) return;
    try {
      final transition = _engine.transition(
        candidate: _candidate,
        target: target,
        actor: input.actor,
        note: input.note,
        existingIndicators: widget.catalog.indicators,
      );
      await widget.repository.saveIndicatorTransition(transition);
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
            color: Color(0xFFB54708),
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
    final input = await _askAudit('派生新修订版');
    if (input == null || !mounted) return;
    final revision = _engine.reviseOfficial(
      official: _candidate,
      author: input.actor,
    );
    await widget.repository.saveIndicatorCandidate(revision);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _setQuality(CheckupIndicatorCandidateQuality quality) {
    setState(() => _candidate = _candidate.copyWith(quality: quality));
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = _candidate.isReadOnly;
    final value = _fromForm();
    final validation = _engine.validate(
      value,
      existingIndicators: widget.catalog.indicators,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('指标 V${_candidate.version}'),
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
          _IndicatorStageCard(candidate: _candidate),
          const SizedBox(height: 10),
          _IndicatorValidationCard(validation: validation),
          const SizedBox(height: 16),
          const _IndicatorSection(
            title: '构念定义',
            subtitle: '保持单一、双向可解释、可观察，不得伪装成医学诊断。',
          ),
          const SizedBox(height: 10),
          _IndicatorField(
            controller: _name,
            label: '候选指标名称',
            enabled: !readOnly,
          ),
          _IndicatorField(controller: _area, label: '领域', enabled: !readOnly),
          DropdownButtonFormField<String>(
            initialValue: _candidate.indicatorType,
            decoration: const InputDecoration(
              labelText: '指标类型',
              border: OutlineInputBorder(),
            ),
            items: MentalHealthIndicatorGovernanceEngine.supportedTypes
                .map(
                  (type) =>
                      DropdownMenuItem<String>(value: type, child: Text(type)),
                )
                .toList(growable: false),
            onChanged: readOnly
                ? null
                : (type) => setState(
                      () =>
                          _candidate = _candidate.copyWith(indicatorType: type),
                    ),
          ),
          const SizedBox(height: 10),
          _IndicatorField(
            controller: _definition,
            label: '单一构念定义',
            enabled: !readOnly,
            minLines: 3,
          ),
          _IndicatorField(
            controller: _low,
            label: '低端/不足表现',
            enabled: !readOnly,
            minLines: 2,
          ),
          _IndicatorField(
            controller: _high,
            label: '高端表现与适用边界',
            enabled: !readOnly,
            minLines: 2,
          ),
          _IndicatorField(
            controller: _misuse,
            label: '僵化、高端误用或过度化风险',
            enabled: !readOnly,
            minLines: 2,
          ),
          _IndicatorField(
            controller: _function,
            label: '现实功能信号',
            enabled: !readOnly,
            minLines: 2,
          ),
          _IndicatorField(
            controller: _rationale,
            label: '单一构念与新增价值说明',
            enabled: !readOnly,
            minLines: 3,
          ),
          _IndicatorField(
            controller: _safety,
            label: '安全与解释边界',
            enabled: !readOnly,
            minLines: 3,
          ),
          const SizedBox(height: 16),
          const _IndicatorSection(
            title: '课程证据与制衡',
            subtitle: '只接受本地课程location_id；AI提出的不存在ID会被丢弃。',
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _candidate.sourceLevel,
            decoration: const InputDecoration(
              labelText: '来源等级',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'C1候选直接证据', child: Text('C1候选直接证据')),
              DropdownMenuItem(value: 'C2课程机制推导', child: Text('C2课程机制推导')),
            ],
            onChanged: readOnly
                ? null
                : (source) => setState(
                      () =>
                          _candidate = _candidate.copyWith(sourceLevel: source),
                    ),
          ),
          const SizedBox(height: 10),
          _IndicatorField(
            controller: _definitionLocation,
            label: 'DEF定义位置ID',
            enabled: !readOnly,
          ),
          _IndicatorField(
            controller: _lowLocation,
            label: 'LOW低端位置ID',
            enabled: !readOnly,
          ),
          _IndicatorField(
            controller: _highLocation,
            label: 'HIGH高端位置ID',
            enabled: !readOnly,
          ),
          _IndicatorField(
            controller: _actionLocation,
            label: 'ACT行动位置ID',
            enabled: !readOnly,
          ),
          _IndicatorField(
            controller: _evidenceIds,
            label: '全部课程证据ID（逗号分隔）',
            enabled: !readOnly,
            minLines: 2,
          ),
          _IndicatorField(
            controller: _guardrailIds,
            label: '制衡指标ID（逗号分隔）',
            enabled: !readOnly,
            minLines: 2,
          ),
          _IndicatorField(
            controller: _duplicateIds,
            label: '可能重复指标ID（逗号分隔）',
            enabled: !readOnly,
            minLines: 2,
          ),
          const SizedBox(height: 16),
          const _IndicatorSection(
            title: '质量评分',
            subtitle: 'AI分数只能作为建议；课程证据适配必须由人重新评分。',
          ),
          const SizedBox(height: 8),
          _IndicatorQualityEditor(
            quality: _candidate.quality,
            enabled: !readOnly,
            onChanged: _setQuality,
          ),
          const SizedBox(height: 16),
          const _IndicatorSection(
            title: '人工门禁',
            subtitle: '每一阶段都需要真实完成；勾选不会替代访谈、试测或专家工作。',
          ),
          const SizedBox(height: 8),
          _IndicatorField(
            controller: _author,
            label: '作者/生成来源',
            enabled: !readOnly,
          ),
          _ReviewSwitch(
            value: _candidate.evidenceReviewPassed,
            enabled: !readOnly,
            title: '课程证据相关性已独立复核',
            subtitle: '逐项确认location_id和证据角色，不以“同一讲”代替相关性。',
            onChanged: (checked) => setState(
              () => _candidate = _candidate.copyWith(
                evidenceReviewPassed: checked,
              ),
            ),
          ),
          _ReviewSwitch(
            value: _candidate.constructReviewPassed,
            enabled: !readOnly,
            title: '单一构念、去重与双向逻辑已复核',
            subtitle: '记录与可能重复指标保留、合并或拒绝的理由。',
            onChanged: (checked) => setState(
              () => _candidate = _candidate.copyWith(
                constructReviewPassed: checked,
              ),
            ),
          ),
          _ReviewSwitch(
            value: _candidate.expertReviewPassed,
            enabled: !readOnly,
            title: '课程专家审核已通过',
            subtitle: '专家确认课程忠实度、边界和不当使用风险。',
            onChanged: (checked) => setState(
              () =>
                  _candidate = _candidate.copyWith(expertReviewPassed: checked),
            ),
          ),
          _ReviewSwitch(
            value: _candidate.cognitiveInterviewPassed,
            enabled: !readOnly,
            title: '目标用户认知访谈已通过',
            subtitle: '确认用户对名称、定义和高低端表现的理解符合预期。',
            onChanged: (checked) => setState(
              () => _candidate = _candidate.copyWith(
                cognitiveInterviewPassed: checked,
              ),
            ),
          ),
          _ReviewSwitch(
            value: _candidate.pilotPassed,
            enabled: !readOnly,
            title: '小样本试测已通过',
            subtitle: '依据预设规则检查缺失、区分度、稳定性和安全反馈。',
            onChanged: (checked) => setState(
              () => _candidate = _candidate.copyWith(pilotPassed: checked),
            ),
          ),
          _IndicatorField(
            controller: _pilotSample,
            label: '试测样本数',
            enabled: !readOnly,
            keyboardType: TextInputType.number,
          ),
          _IndicatorField(
            controller: _pilotNotes,
            label: '认知访谈、试测与校准记录',
            enabled: !readOnly,
            minLines: 4,
          ),
          const SizedBox(height: 16),
          const _IndicatorSection(
            title: '身份、版本与审计',
            subtitle: '正式版本不可覆盖；修订保持指标ID并递增候选版本。',
          ),
          const SizedBox(height: 8),
          _IndicatorReadOnly(
            label: 'candidate_id',
            value: _candidate.candidateId,
          ),
          _IndicatorReadOnly(
            label: 'proposed_indicator_id',
            value: _candidate.proposedIndicatorId,
          ),
          _IndicatorReadOnly(
            label: '课程/Prompt/模型',
            value: '${_candidate.courseVersion} / '
                '${_candidate.promptVersion} / ${_candidate.modelVersion}',
          ),
          if (_candidate.reviewer.isNotEmpty)
            _IndicatorReadOnly(label: '独立审核人', value: _candidate.reviewer),
          if (_candidate.signer.isNotEmpty)
            _IndicatorReadOnly(label: '签发人', value: _candidate.signer),
          FutureBuilder<List<CheckupIndicatorAuditEvent>>(
            future: widget.repository.loadIndicatorAudit(
              _candidate.candidateId,
            ),
            builder: (context, snapshot) => _IndicatorAuditTimeline(
              events: snapshot.data ?? const <CheckupIndicatorAuditEvent>[],
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
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : readOnly
                          ? _revise
                          : _save,
                  icon: Icon(
                    readOnly ? Icons.fork_right_outlined : Icons.save_outlined,
                  ),
                  label: Text(readOnly ? '派生修订版' : '保存草稿'),
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

class _IndicatorDiscoveryInput {
  final int lecture;
  final String area;
  final bool useAi;

  const _IndicatorDiscoveryInput({
    required this.lecture,
    required this.area,
    required this.useAi,
  });
}

class _IndicatorAuditInput {
  final String actor;
  final String note;

  const _IndicatorAuditInput({required this.actor, required this.note});
}

class _IndicatorGovernanceNotice extends StatelessWidget {
  const _IndicatorGovernanceNotice();

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFF7ED),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.science_outlined, color: Color(0xFFB54708)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '候选指标发现是课程内容治理流程，不是从用户数据中自动“挖掘”'
                  '健康结论。AI只能基于课程知识提出草稿；课程专家、独立审核、'
                  '认知访谈、小样本试测和人工签发全部保留。',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
}

class _IndicatorMetrics extends StatelessWidget {
  final int total;
  final int candidate;
  final int pilot;
  final int official;

  const _IndicatorMetrics({
    required this.total,
    required this.candidate,
    required this.pilot,
    required this.official,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          _IndicatorMetric(value: '$total', label: '总候选'),
          const SizedBox(width: 7),
          _IndicatorMetric(value: '$candidate', label: '待访谈'),
          const SizedBox(width: 7),
          _IndicatorMetric(value: '$pilot', label: '试测'),
          const SizedBox(width: 7),
          _IndicatorMetric(value: '$official', label: '正式'),
        ],
      );
}

class _IndicatorMetric extends StatelessWidget {
  final String value;
  final String label;

  const _IndicatorMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4554C5).withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF4554C5),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

class _IndicatorEmpty extends StatelessWidget {
  const _IndicatorEmpty();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              Icon(Icons.travel_explore_outlined, size: 38),
              SizedBox(height: 9),
              Text('没有匹配的候选指标', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text(
                '点击“发现候选”可创建本地治理骨架或AI课程候选。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
      );
}

class _IndicatorStageCard extends StatelessWidget {
  final CheckupIndicatorCandidate candidate;

  const _IndicatorStageCard({required this.candidate});

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFF3F6FF),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                candidate.name,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  _IndicatorPill(text: 'Lecture ${candidate.lecture}'),
                  _IndicatorPill(text: candidate.indicatorType),
                  _IndicatorPill(text: candidate.stage.label),
                  _IndicatorPill(text: 'V${candidate.version}'),
                ],
              ),
            ],
          ),
        ),
      );
}

class _IndicatorValidationCard extends StatelessWidget {
  final CheckupIndicatorCandidateValidation validation;

  const _IndicatorValidationCard({required this.validation});

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
                  Expanded(
                    child: Text(
                      validation.valid
                          ? '自动结构与质量门已通过'
                          : '仍有 ${validation.blockingIssues.length} 项阻断门槛',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
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

class _IndicatorQualityEditor extends StatelessWidget {
  final CheckupIndicatorCandidateQuality quality;
  final bool enabled;
  final ValueChanged<CheckupIndicatorCandidateQuality> onChanged;

  const _IndicatorQualityEditor({
    required this.quality,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: <Widget>[
              _IndicatorScore(
                label: '课程证据适配',
                value: quality.courseEvidenceFit,
                threshold: 80,
                enabled: enabled,
                onChanged: (value) =>
                    onChanged(quality.copyWith(courseEvidenceFit: value)),
              ),
              _IndicatorScore(
                label: '构念清晰度',
                value: quality.constructClarity,
                threshold: 80,
                enabled: enabled,
                onChanged: (value) =>
                    onChanged(quality.copyWith(constructClarity: value)),
              ),
              _IndicatorScore(
                label: '非重复性',
                value: quality.nonDuplication,
                threshold: 80,
                enabled: enabled,
                onChanged: (value) =>
                    onChanged(quality.copyWith(nonDuplication: value)),
              ),
              _IndicatorScore(
                label: '可测量性',
                value: quality.measurability,
                threshold: 75,
                enabled: enabled,
                onChanged: (value) =>
                    onChanged(quality.copyWith(measurability: value)),
              ),
              _IndicatorScore(
                label: '双向解释',
                value: quality.bidirectionalBalance,
                threshold: 75,
                enabled: enabled,
                onChanged: (value) =>
                    onChanged(quality.copyWith(bidirectionalBalance: value)),
              ),
              _IndicatorScore(
                label: '行动可转化性',
                value: quality.actionability,
                threshold: 0,
                enabled: enabled,
                onChanged: (value) =>
                    onChanged(quality.copyWith(actionability: value)),
              ),
              _IndicatorScore(
                label: '安全性',
                value: quality.safety,
                threshold: 90,
                enabled: enabled,
                onChanged: (value) =>
                    onChanged(quality.copyWith(safety: value)),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    '加权综合分',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    quality.overall.toStringAsFixed(1),
                    style: TextStyle(
                      color: quality.overall >= 80
                          ? const Color(0xFF39715D)
                          : const Color(0xFFB54708),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _IndicatorScore extends StatelessWidget {
  final String label;
  final double value;
  final double threshold;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _IndicatorScore({
    required this.label,
    required this.value,
    required this.threshold,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  threshold > 0 ? '$label（门槛${threshold.toInt()}）' : label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          Slider(
            value: value.clamp(0, 100).toDouble(),
            max: 100,
            divisions: 20,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      );
}

class _ReviewSwitch extends StatelessWidget {
  final bool value;
  final bool enabled;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  const _ReviewSwitch({
    required this.value,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: enabled ? onChanged : null,
        title: Text(title),
        subtitle: Text(subtitle),
      );
}

class _IndicatorSection extends StatelessWidget {
  final String title;
  final String subtitle;

  const _IndicatorSection({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF667085), height: 1.4),
          ),
        ],
      );
}

class _IndicatorField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final int minLines;
  final TextInputType? keyboardType;

  const _IndicatorField({
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
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: minLines == 1 ? 2 : minLines + 3,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

class _IndicatorReadOnly extends StatelessWidget {
  final String label;
  final String value;

  const _IndicatorReadOnly({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class _IndicatorAuditTimeline extends StatelessWidget {
  final List<CheckupIndicatorAuditEvent> events;

  const _IndicatorAuditTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('尚无状态变更审计记录。', style: TextStyle(color: Color(0xFF667085))),
      );
    }
    return Column(
      children: <Widget>[
        const SizedBox(height: 8),
        for (final event in events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(
              '${event.fromStage.label} → ${event.toStage.label}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${event.actor}'
              '${event.note.isEmpty ? '' : '\n${event.note}'}',
            ),
          ),
      ],
    );
  }
}

class _IndicatorPill extends StatelessWidget {
  final String text;

  const _IndicatorPill({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF4554C5).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF4554C5),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      );
}

List<String> _splitIds(String value) => value
    .split(RegExp(r'[,，;；\s]+'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet()
    .toList(growable: false);
