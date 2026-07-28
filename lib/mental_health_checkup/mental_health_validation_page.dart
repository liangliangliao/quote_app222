import 'package:flutter/material.dart';

import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_repository.dart';
import 'mental_health_content_governance.dart';
import 'mental_health_validation.dart';

class MentalHealthValidationCenterPage extends StatefulWidget {
  final MentalHealthCheckupCatalog catalog;
  final MentalHealthCheckupRepository repository;

  const MentalHealthValidationCenterPage({
    super.key,
    required this.catalog,
    required this.repository,
  });

  @override
  State<MentalHealthValidationCenterPage> createState() =>
      _MentalHealthValidationCenterPageState();
}

class _MentalHealthValidationCenterPageState
    extends State<MentalHealthValidationCenterPage> {
  final TextEditingController _searchController = TextEditingController();
  List<CheckupContentCandidate> _candidates =
      const <CheckupContentCandidate>[];
  List<CheckupExpertReviewRecord> _expertReviews =
      const <CheckupExpertReviewRecord>[];
  List<CheckupCognitiveInterviewRecord> _interviews =
      const <CheckupCognitiveInterviewRecord>[];
  List<CheckupPilotObservation> _pilotObservations =
      const <CheckupPilotObservation>[];
  List<CheckupSeedReviewRecord> _seedReviews =
      const <CheckupSeedReviewRecord>[];
  CheckupCandidateStage? _stageFilter;
  bool _loading = true;
  bool _transferring = false;

  @override
  void initState() {
    super.initState();
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
    final expertReviews = await widget.repository.loadExpertReviews();
    final interviews = await widget.repository.loadCognitiveInterviews();
    final pilotObservations =
        await widget.repository.loadPilotObservations();
    final seedReviews = await widget.repository.loadSeedReviews();
    if (!mounted) return;
    setState(() {
      _candidates = candidates;
      _expertReviews = expertReviews;
      _interviews = interviews;
      _pilotObservations = pilotObservations;
      _seedReviews = seedReviews;
      _loading = false;
    });
  }

  List<CheckupContentCandidate> get _filteredCandidates {
    final query = _searchController.text.trim().toLowerCase();
    return _candidates.where((candidate) {
      if (_stageFilter != null && candidate.stage != _stageFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return candidate.candidateId.toLowerCase().contains(query) ||
          candidate.primaryIndicatorId.toLowerCase().contains(query) ||
          candidate.indicatorName.toLowerCase().contains(query) ||
          candidate.contentCode.toLowerCase().contains(query) ||
          candidate.content.toLowerCase().contains(query);
    }).take(200).toList(growable: false);
  }

  int get _blueprintCount => _candidates
      .where(
        (candidate) => candidate.candidateId.startsWith(
          MentalHealthContentBlueprintFactory.candidatePrefix,
        ),
      )
      .length;

  int get _passedSeedCount {
    final latest = <String, CheckupSeedReviewRecord>{};
    for (final record in _seedReviews) {
      final key = '${record.targetKind.name}|${record.targetId}';
      final previous = latest[key];
      if (previous == null || record.createdAtMs > previous.createdAtMs) {
        latest[key] = record;
      }
    }
    return latest.values
        .where(
          (record) =>
              record.passed &&
              record.sourceVersion == widget.catalog.validation.version,
        )
        .length;
  }

  Future<String?> _askPassword({
    required String title,
    required String action,
  }) async {
    final controller = TextEditingController();
    var obscure = true;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '验证包包含内容、匿名化研究记录和审核留痕。密码至少8位，'
                '请通过另一安全渠道交给协作方。',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '验证包密码',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final password = controller.text;
                if (password.length < 8) return;
                Navigator.of(context).pop(password);
              },
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _exportPackage() async {
    final password = await _askPassword(
      title: '导出加密验证包',
      action: '选择保存位置',
    );
    if (password == null || !mounted) return;
    setState(() => _transferring = true);
    try {
      final exported =
          await widget.repository.exportEncryptedValidationPackage(
        catalog: widget.catalog,
        password: password,
      );
      if (!mounted) return;
      _showMessage(exported ? '加密验证包已导出。' : '已取消导出。');
    } catch (error) {
      if (mounted) _showMessage('导出失败：$error', error: true);
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _importPackage() async {
    final password = await _askPassword(
      title: '导入加密验证包',
      action: '选择文件',
    );
    if (password == null || !mounted) return;
    setState(() => _transferring = true);
    try {
      final count =
          await widget.repository.importEncryptedValidationPackage(
        catalog: widget.catalog,
        password: password,
      );
      if (!mounted) return;
      _showMessage(count == 0 ? '已取消导入。' : '已校验并导入$count条验证记录。');
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(
          '导入被阻止：${error.toString().replaceFirst('FormatException: ', '')}',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB42318) : null,
      ),
    );
  }

  Future<void> _openSeedReviews() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthSeedReviewPage(
          catalog: widget.catalog,
          repository: widget.repository,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openCandidate(CheckupContentCandidate candidate) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthCandidateValidationPage(
          candidateId: candidate.candidateId,
          repository: widget.repository,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredCandidates;
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容验证与发布证据'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: _loading || _transferring ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: visible.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _ValidationNotice(),
                            const SizedBox(height: 12),
                            _ValidationMetrics(
                              blueprintCount: _blueprintCount,
                              expertReviewCount: _expertReviews.length,
                              cognitiveCount: _interviews.length,
                              pilotCount: _pilotObservations.length,
                            ),
                            const SizedBox(height: 12),
                            _ValidationActions(
                              transferring: _transferring,
                              passedSeedCount: _passedSeedCount,
                              onSeedReviews: _openSeedReviews,
                              onExport: _exportPackage,
                              onImport: _importPackage,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              '逐条内容验证',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              '默认最多显示200条；可按candidate_id、指标、题型或正文搜索。'
                              '所有通过状态都由当前内容指纹对应的真实记录计算，不能手工勾选。',
                              style: TextStyle(
                                color: Color(0xFF667085),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: '搜索内容或指标',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon:
                                    _searchController.text.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {});
                                            },
                                            icon: const Icon(Icons.clear),
                                          ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: <Widget>[
                                  ChoiceChip(
                                    label: const Text('全部'),
                                    selected: _stageFilter == null,
                                    onSelected: (_) =>
                                        setState(() => _stageFilter = null),
                                  ),
                                  for (final stage
                                      in CheckupCandidateStage.values) ...[
                                    const SizedBox(width: 8),
                                    ChoiceChip(
                                      label: Text(stage.label),
                                      selected: _stageFilter == stage,
                                      onSelected: (_) => setState(
                                        () => _stageFilter = stage,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '显示${visible.length}条，共${_candidates.length}条',
                              style: const TextStyle(
                                color: Color(0xFF667085),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        );
                      }
                      final candidate = visible[index - 1];
                      return _CandidateValidationTile(
                        candidate: candidate,
                        onTap: () => _openCandidate(candidate),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class MentalHealthCandidateValidationPage extends StatefulWidget {
  final String candidateId;
  final MentalHealthCheckupRepository repository;

  const MentalHealthCandidateValidationPage({
    super.key,
    required this.candidateId,
    required this.repository,
  });

  @override
  State<MentalHealthCandidateValidationPage> createState() =>
      _MentalHealthCandidateValidationPageState();
}

class _MentalHealthCandidateValidationPageState
    extends State<MentalHealthCandidateValidationPage> {
  CheckupContentCandidate? _candidate;
  CheckupValidationDossier? _dossier;
  CheckupValidationDecision? _decision;
  List<String> _seedBlockers = const <String>[];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final candidate =
        await widget.repository.loadContentCandidate(widget.candidateId);
    if (candidate == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final dossier =
        await widget.repository.loadValidationDossier(widget.candidateId);
    final seedBlockers =
        await widget.repository.loadSeedPublicationBlockers(widget.candidateId);
    const engine = MentalHealthValidationEngine();
    final decision = engine.evaluate(candidate: candidate, dossier: dossier);
    if (!mounted) return;
    setState(() {
      _candidate = candidate;
      _dossier = dossier;
      _decision = decision;
      _seedBlockers = seedBlockers;
      _loading = false;
    });
  }

  Future<void> _synchronize() async {
    setState(() => _syncing = true);
    try {
      await widget.repository.synchronizeContentValidation(widget.candidateId);
      await _load();
    } catch (error) {
      if (mounted) _message('计算失败：$error', error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _addExpertReview() async {
    final candidate = _candidate;
    if (candidate == null) return;
    final record = await showDialog<CheckupExpertReviewRecord>(
      context: context,
      builder: (_) => _ExpertReviewDialog(candidate: candidate),
    );
    if (record == null) return;
    await widget.repository.saveExpertReview(record);
    await _synchronize();
  }

  Future<void> _addInterview() async {
    final candidate = _candidate;
    if (candidate == null) return;
    final record = await showDialog<CheckupCognitiveInterviewRecord>(
      context: context,
      builder: (_) => _CognitiveInterviewDialog(candidate: candidate),
    );
    if (record == null) return;
    await widget.repository.saveCognitiveInterview(record);
    await _synchronize();
  }

  Future<void> _addPilotObservation() async {
    final candidate = _candidate;
    if (candidate == null) return;
    final record = await showDialog<CheckupPilotObservation>(
      context: context,
      builder: (_) => _PilotObservationDialog(candidate: candidate),
    );
    if (record == null) return;
    await widget.repository.savePilotObservation(record);
    await _synchronize();
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB42318) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _candidate == null || _decision == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('验证记录')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final candidate = _candidate!;
    final dossier = _dossier!;
    final decision = _decision!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${candidate.contentCode} · ${candidate.indicatorName}'),
        actions: <Widget>[
          IconButton(
            tooltip: '重新计算门槛',
            onPressed: _syncing ? null : _synchronize,
            icon: const Icon(Icons.calculate_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _StatusPill(
                        text: candidate.stage.label,
                        passed: candidate.stage ==
                            CheckupCandidateStage.official,
                      ),
                      _StatusPill(
                        text: candidate.sourceLevel,
                        passed: candidate.sourceLevel.startsWith('C1'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    candidate.content,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.45,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${candidate.primaryIndicatorId} · '
                    '${candidate.scaleOrDuration} · ${candidate.recallWindow}',
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    '内容指纹 ${MentalHealthValidationEngine.candidateFingerprint(candidate)}',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DecisionCard(
            decision: decision,
            externalBlockers: _seedBlockers,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.fact_check_outlined),
                  ),
                  title: const Text(
                    '专家独立审核',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${dossier.expertReviews.length}条记录；课程专家与测量审核人必须不同，'
                    '风险内容另需安全审核。',
                  ),
                  trailing: const Icon(Icons.add),
                  onTap: _addExpertReview,
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.record_voice_over_outlined),
                  ),
                  title: const Text(
                    '目标用户认知访谈',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${decision.cognitiveSampleSize}/'
                    '${CheckupValidationProtocol.v25.minCognitiveParticipants}人；'
                    '只保存研究盐生成的匿名键。',
                  ),
                  trailing: const Icon(Icons.add),
                  onTap: _addInterview,
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.science_outlined),
                  ),
                  title: const Text(
                    '小样本试测与校准',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${decision.pilotSampleSize}/'
                    '${CheckupValidationProtocol.v25.minPilotParticipants}人；'
                    '计算缺失、耗时、相关、群体差异与报警指标。',
                  ),
                  trailing: const Icon(Icons.add),
                  onTap: _addPilotObservation,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '统计指标',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (decision.metrics.isEmpty)
            const _EmptyCard(text: '尚无可计算指标。')
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: decision.metrics.entries
                      .map(
                        (entry) => Chip(
                          label: Text(
                            '${_metricLabel(entry.key)} '
                            '${_metricValue(entry.key, entry.value)}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            '最近记录',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (dossier.expertReviews.isEmpty &&
              dossier.cognitiveInterviews.isEmpty &&
              dossier.pilotObservations.isEmpty)
            const _EmptyCard(text: '尚未录入真实审核或研究记录。')
          else ...[
            for (final review in dossier.expertReviews.reversed.take(5))
              _RecordTile(
                icon: Icons.fact_check_outlined,
                title: '${review.role.label} · ${review.reviewerId}',
                subtitle:
                    '${review.passed ? '通过' : '未通过'} · 综合'
                    '${review.quality.overall.toStringAsFixed(0)} · '
                    '${review.note.isEmpty ? '无备注' : review.note}',
                currentFingerprint: review.candidateFingerprint ==
                    MentalHealthValidationEngine.candidateFingerprint(
                      candidate,
                    ),
              ),
            for (final interview
                in dossier.cognitiveInterviews.reversed.take(5))
              _RecordTile(
                icon: Icons.record_voice_over_outlined,
                title: '认知访谈 · ${_shortKey(interview.participantKey)}',
                subtitle:
                    '${interview.misunderstood ? '发现理解偏差' : '理解符合预期'} · '
                    '${interview.burdenAcceptable ? '负担可接受' : '负担不可接受'}',
                currentFingerprint: interview.candidateFingerprint ==
                    MentalHealthValidationEngine.candidateFingerprint(
                      candidate,
                    ),
              ),
            for (final observation
                in dossier.pilotObservations.reversed.take(5))
              _RecordTile(
                icon: Icons.science_outlined,
                title: '试测 · ${_shortKey(observation.participantKey)}',
                subtitle:
                    '${observation.missing ? '缺失' : '完成'} · '
                    '${(observation.completionTimeMs / 1000).toStringAsFixed(0)}秒 · '
                    '组别${observation.fairnessGroup.isEmpty ? '未填' : observation.fairnessGroup}',
                currentFingerprint: observation.candidateFingerprint ==
                    MentalHealthValidationEngine.candidateFingerprint(
                      candidate,
                    ),
              ),
          ],
        ],
      ),
    );
  }
}

class MentalHealthSeedReviewPage extends StatefulWidget {
  final MentalHealthCheckupCatalog catalog;
  final MentalHealthCheckupRepository repository;

  const MentalHealthSeedReviewPage({
    super.key,
    required this.catalog,
    required this.repository,
  });

  @override
  State<MentalHealthSeedReviewPage> createState() =>
      _MentalHealthSeedReviewPageState();
}

class _MentalHealthSeedReviewPageState
    extends State<MentalHealthSeedReviewPage> {
  final TextEditingController _searchController = TextEditingController();
  CheckupSeedTargetKind _kind = CheckupSeedTargetKind.indicator;
  Set<String> _targetIds = const <String>{};
  List<CheckupSeedReviewRecord> _reviews =
      const <CheckupSeedReviewRecord>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final targetIds = await widget.repository.loadSeedTargetIds(
      targetKind: _kind,
      catalog: widget.catalog,
    );
    final reviews =
        await widget.repository.loadSeedReviews(targetKind: _kind);
    if (!mounted) return;
    setState(() {
      _targetIds = targetIds;
      _reviews = reviews;
      _loading = false;
    });
  }

  Map<String, CheckupSeedReviewRecord> get _latestReviews {
    final latest = <String, CheckupSeedReviewRecord>{};
    for (final record in _reviews) {
      final previous = latest[record.targetId];
      if (previous == null || record.createdAtMs > previous.createdAtMs) {
        latest[record.targetId] = record;
      }
    }
    return latest;
  }

  List<String> get _visibleIds {
    final query = _searchController.text.trim().toLowerCase();
    final values = _targetIds
        .where((id) => query.isEmpty || id.toLowerCase().contains(query))
        .toList()
      ..sort();
    return values.take(300).toList(growable: false);
  }

  Future<void> _addReview(String targetId) async {
    final summary = await widget.repository.loadSeedTargetSummary(
      targetKind: _kind,
      targetId: targetId,
      catalog: widget.catalog,
    );
    if (!mounted) return;
    final record = await showDialog<CheckupSeedReviewRecord>(
      context: context,
      builder: (_) => _SeedReviewDialog(
        kind: _kind,
        targetId: targetId,
        sourceVersion: widget.catalog.validation.version,
        summary: summary,
      ),
    );
    if (record == null) return;
    await widget.repository.saveSeedReview(record);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latestReviews;
    final passed =
        latest.values
            .where(
              (record) =>
                  record.passed &&
                  record.sourceVersion == widget.catalog.validation.version,
            )
            .length;
    final visible = _visibleIds;
    return Scaffold(
      appBar: AppBar(title: const Text('基础内容专家确认')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: visible.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Card(
                        color: const Color(0xFFFFF7ED),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '这里确认345项指标、1380条指标—证据关系、14个诊断模式和'
                            '23个行动处方。记录必须来自可追责的真实专家；AI不能代签。',
                            style: TextStyle(height: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            for (final kind
                                in CheckupSeedTargetKind.values) ...[
                              ChoiceChip(
                                label: Text(kind.label),
                                selected: _kind == kind,
                                onSelected: (_) {
                                  if (_kind == kind) return;
                                  setState(() => _kind = kind);
                                  _load();
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_kind.label}：已通过$passed/${_targetIds.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _targetIds.isEmpty
                            ? 0
                            : passed / _targetIds.length,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: '按ID搜索',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '显示${visible.length}条；点击录入或更新专家结论。',
                        style: const TextStyle(color: Color(0xFF667085)),
                      ),
                      const SizedBox(height: 6),
                    ],
                  );
                }
                final targetId = visible[index - 1];
                final record = latest[targetId];
                return Card(
                  child: ListTile(
                    onTap: () => _addReview(targetId),
                    leading: CircleAvatar(
                      backgroundColor: record?.passed == true
                          ? const Color(0xFFE7F5EE)
                          : const Color(0xFFFFF1E8),
                      child: Icon(
                        record?.passed == true
                            ? Icons.verified_outlined
                            : Icons.pending_actions_outlined,
                        color: record?.passed == true
                            ? const Color(0xFF39715D)
                            : const Color(0xFFB54708),
                      ),
                    ),
                    title: Text(
                      targetId,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      record == null
                          ? '待真实专家确认'
                          : '${record.reviewerRole} · ${record.reviewerId} · '
                              '${record.passed ? '通过' : '未通过'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}

class _ExpertReviewDialog extends StatefulWidget {
  final CheckupContentCandidate candidate;

  const _ExpertReviewDialog({required this.candidate});

  @override
  State<_ExpertReviewDialog> createState() => _ExpertReviewDialogState();
}

class _ExpertReviewDialogState extends State<_ExpertReviewDialog> {
  final TextEditingController _reviewerController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  CheckupExpertReviewRole _role = CheckupExpertReviewRole.courseExpert;
  bool _passed = false;
  double _indicator = 80;
  double _course = 80;
  double _nonDuplication = 80;
  double _measurability = 80;
  double _scale = 80;
  double _bidirectional = 80;
  double _safety = 90;
  String _error = '';

  @override
  void dispose() {
    _reviewerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final reviewer = _reviewerController.text.trim();
    if (reviewer.isEmpty ||
        reviewer.toLowerCase().contains('ai') ||
        reviewer.toLowerCase() == widget.candidate.author.trim().toLowerCase()) {
      setState(() => _error = '请输入真实且独立于作者的审核人标识，不能填写AI。');
      return;
    }
    final now = DateTime.now();
    Navigator.of(context).pop(
      CheckupExpertReviewRecord(
        id: 'expert-${widget.candidate.candidateId}-${now.microsecondsSinceEpoch}',
        candidateId: widget.candidate.candidateId,
        candidateFingerprint:
            MentalHealthValidationEngine.candidateFingerprint(
          widget.candidate,
        ),
        reviewerId: reviewer,
        role: _role,
        quality: CheckupCandidateQuality(
          indicatorConsistency: _indicator,
          courseFidelity: _course,
          nonDuplication: _nonDuplication,
          measurability: _measurability,
          scaleWindowFit: _scale,
          bidirectionalLogic: _bidirectional,
          safety: _safety,
        ),
        passed: _passed,
        note: _noteController.text.trim(),
        createdAtMs: now.millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('录入独立专家审核'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _reviewerController,
                  decoration: const InputDecoration(
                    labelText: '审核人唯一标识',
                    helperText: '使用机构内部可追责编号，不填写证件号',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<CheckupExpertReviewRole>(
                  isExpanded: true,
                  value: _role,
                  items: CheckupExpertReviewRole.values
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
                const SizedBox(height: 8),
                _ScoreSlider(
                  label: '指标一致性',
                  value: _indicator,
                  onChanged: (value) => setState(() => _indicator = value),
                ),
                _ScoreSlider(
                  label: '课程忠实度',
                  value: _course,
                  onChanged: (value) => setState(() => _course = value),
                ),
                _ScoreSlider(
                  label: '非重复性',
                  value: _nonDuplication,
                  onChanged: (value) =>
                      setState(() => _nonDuplication = value),
                ),
                _ScoreSlider(
                  label: '可测量性',
                  value: _measurability,
                  onChanged: (value) =>
                      setState(() => _measurability = value),
                ),
                _ScoreSlider(
                  label: '量尺/时间窗适配',
                  value: _scale,
                  onChanged: (value) => setState(() => _scale = value),
                ),
                _ScoreSlider(
                  label: '双向逻辑',
                  value: _bidirectional,
                  onChanged: (value) =>
                      setState(() => _bidirectional = value),
                ),
                _ScoreSlider(
                  label: '安全性',
                  value: _safety,
                  onChanged: (value) => setState(() => _safety = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _passed,
                  onChanged: (value) => setState(() => _passed = value),
                  title: const Text('该审核角色结论：通过'),
                  subtitle: const Text('未通过记录同样会保存并阻止进入下一阶段。'),
                ),
                TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '依据、修改意见或利益冲突声明',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(onPressed: _submit, child: const Text('保存审核')),
        ],
      );
}

class _CognitiveInterviewDialog extends StatefulWidget {
  final CheckupContentCandidate candidate;

  const _CognitiveInterviewDialog({required this.candidate});

  @override
  State<_CognitiveInterviewDialog> createState() =>
      _CognitiveInterviewDialogState();
}

class _CognitiveInterviewDialogState
    extends State<_CognitiveInterviewDialog> {
  final TextEditingController _saltController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _construct = true;
  bool _window = true;
  bool _options = true;
  bool _doubleBarrel = false;
  bool _leading = false;
  bool _burden = true;
  String _error = '';

  @override
  void dispose() {
    _saltController.dispose();
    _aliasController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final key = MentalHealthValidationEngine.participantKey(
        studySalt: _saltController.text,
        localAlias: _aliasController.text,
      );
      final now = DateTime.now();
      Navigator.of(context).pop(
        CheckupCognitiveInterviewRecord(
          id: 'cognitive-${widget.candidate.candidateId}-${now.microsecondsSinceEpoch}',
          candidateId: widget.candidate.candidateId,
          candidateFingerprint:
              MentalHealthValidationEngine.candidateFingerprint(
            widget.candidate,
          ),
          participantKey: key,
          understoodConstruct: _construct,
          understoodRecallWindow: _window,
          optionsClear: _options,
          doubleBarrelDetected: _doubleBarrel,
          leadingLanguageDetected: _leading,
          burdenAcceptable: _burden,
          note: _noteController.text.trim(),
          createdAtMs: now.millisecondsSinceEpoch,
        ),
      );
    } catch (error) {
      setState(
        () => _error =
            error.toString().replaceFirst('Invalid argument(s): ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('录入认知访谈'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '请先取得适用的知情同意。应用不会保存姓名、电话或本地代号；'
                  '只保存研究盐与代号生成的SHA-256匿名键。',
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _saltController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '研究盐（至少8位）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _aliasController,
                  decoration: const InputDecoration(
                    labelText: '本地参与者代号',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                _CheckRow(
                  title: '正确理解目标构念',
                  value: _construct,
                  onChanged: (value) => setState(() => _construct = value),
                ),
                _CheckRow(
                  title: '正确理解回忆时间窗',
                  value: _window,
                  onChanged: (value) => setState(() => _window = value),
                ),
                _CheckRow(
                  title: '选项与措辞清楚',
                  value: _options,
                  onChanged: (value) => setState(() => _options = value),
                ),
                _CheckRow(
                  title: '检出双重问题',
                  value: _doubleBarrel,
                  onChanged: (value) =>
                      setState(() => _doubleBarrel = value),
                ),
                _CheckRow(
                  title: '检出诱导措辞',
                  value: _leading,
                  onChanged: (value) => setState(() => _leading = value),
                ),
                _CheckRow(
                  title: '回答负担可接受',
                  value: _burden,
                  onChanged: (value) => setState(() => _burden = value),
                ),
                TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '逐字反馈摘要与修订建议（不要写身份信息）',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(onPressed: _submit, child: const Text('保存访谈')),
        ],
      );
}

class _PilotObservationDialog extends StatefulWidget {
  final CheckupContentCandidate candidate;

  const _PilotObservationDialog({required this.candidate});

  @override
  State<_PilotObservationDialog> createState() =>
      _PilotObservationDialogState();
}

class _PilotObservationDialogState extends State<_PilotObservationDialog> {
  final TextEditingController _saltController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _secondsController =
      TextEditingController(text: '30');
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _restController = TextEditingController();
  final TextEditingController _retestController = TextEditingController();
  final TextEditingController _criterionController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();
  bool _missing = false;
  bool _includeAlarm = false;
  bool _expectedAlarm = false;
  bool _actualAlarm = false;
  String _error = '';

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _saltController,
      _aliasController,
      _secondsController,
      _itemController,
      _restController,
      _retestController,
      _criterionController,
      _groupController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : double.tryParse(value);
  }

  void _submit() {
    try {
      final key = MentalHealthValidationEngine.participantKey(
        studySalt: _saltController.text,
        localAlias: _aliasController.text,
      );
      final seconds = int.tryParse(_secondsController.text.trim());
      if (seconds == null || seconds < 0) {
        setState(() => _error = '请填写有效完成秒数。');
        return;
      }
      final now = DateTime.now();
      Navigator.of(context).pop(
        CheckupPilotObservation(
          id: 'pilot-${widget.candidate.candidateId}-${now.microsecondsSinceEpoch}',
          candidateId: widget.candidate.candidateId,
          candidateFingerprint:
              MentalHealthValidationEngine.candidateFingerprint(
            widget.candidate,
          ),
          participantKey: key,
          missing: _missing,
          completionTimeMs: seconds * 1000,
          itemScore: _number(_itemController),
          restScore: _number(_restController),
          retestScore: _number(_retestController),
          behaviorCriterion: _number(_criterionController),
          fairnessGroup: _groupController.text.trim(),
          expectedAlarm: _includeAlarm ? _expectedAlarm : null,
          actualAlarm: _includeAlarm ? _actualAlarm : null,
          createdAtMs: now.millisecondsSinceEpoch,
        ),
      );
    } catch (error) {
      setState(
        () => _error =
            error.toString().replaceFirst('Invalid argument(s): ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('录入试测观察'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '正式门槛暂按D1协议执行：至少30名独立参与者，并检查缺失、'
                  '完成时间、区分度/效标、重测、公平性与报警校准。',
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _saltController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '研究盐（至少8位）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _aliasController,
                  decoration: const InputDecoration(
                    labelText: '本地参与者代号',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _missing,
                  onChanged: (value) => setState(() => _missing = value),
                  title: const Text('该条记录缺失/未完成'),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CompactField(
                        controller: _secondsController,
                        label: '完成秒数',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactField(
                        controller: _groupController,
                        label: '公平性组别编码',
                        numeric: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CompactField(
                        controller: _itemController,
                        label: '题目/任务得分',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactField(
                        controller: _restController,
                        label: '其余量表得分',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CompactField(
                        controller: _retestController,
                        label: '重测得分',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactField(
                        controller: _criterionController,
                        label: '行为效标',
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _includeAlarm,
                  onChanged: (value) =>
                      setState(() => _includeAlarm = value),
                  title: const Text('该观察纳入报警校准'),
                ),
                if (_includeAlarm) ...[
                  _CheckRow(
                    title: '专家/金标准预期应报警',
                    value: _expectedAlarm,
                    onChanged: (value) =>
                        setState(() => _expectedAlarm = value),
                  ),
                  _CheckRow(
                    title: '系统实际报警',
                    value: _actualAlarm,
                    onChanged: (value) =>
                        setState(() => _actualAlarm = value),
                  ),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(onPressed: _submit, child: const Text('保存观察')),
        ],
      );
}

class _SeedReviewDialog extends StatefulWidget {
  final CheckupSeedTargetKind kind;
  final String targetId;
  final String sourceVersion;
  final Map<String, String> summary;

  const _SeedReviewDialog({
    required this.kind,
    required this.targetId,
    required this.sourceVersion,
    required this.summary,
  });

  @override
  State<_SeedReviewDialog> createState() => _SeedReviewDialogState();
}

class _SeedReviewDialogState extends State<_SeedReviewDialog> {
  final TextEditingController _reviewerController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _course = false;
  bool _terminology = false;
  bool _safety = false;
  String _error = '';

  @override
  void dispose() {
    _reviewerController.dispose();
    _roleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final reviewer = _reviewerController.text.trim();
    final role = _roleController.text.trim();
    if (reviewer.isEmpty ||
        reviewer.toLowerCase().contains('ai') ||
        role.isEmpty) {
      setState(() => _error = '请填写真实专家标识与专业角色，不能由AI代签。');
      return;
    }
    final now = DateTime.now();
    Navigator.of(context).pop(
      CheckupSeedReviewRecord(
        id: 'seed-${widget.kind.name}-${widget.targetId}-${now.microsecondsSinceEpoch}',
        targetKind: widget.kind,
        targetId: widget.targetId,
        reviewerId: reviewer,
        reviewerRole: role,
        courseAccuracyPassed: _course,
        terminologyPassed: _terminology,
        safetyPassed: _safety,
        sourceVersion: widget.sourceVersion,
        note: _noteController.text.trim(),
        createdAtMs: now.millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('确认${widget.kind.label}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText(
                  widget.targetId,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (widget.summary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final entry in widget.summary.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${entry.key}：'
                              '${entry.value.isEmpty ? '—' : entry.value}',
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _reviewerController,
                  decoration: const InputDecoration(
                    labelText: '专家唯一标识',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _roleController,
                  decoration: const InputDecoration(
                    labelText: '专业角色/资质说明',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                _CheckRow(
                  title: '课程含义与证据关系准确',
                  value: _course,
                  onChanged: (value) => setState(() => _course = value),
                ),
                _CheckRow(
                  title: '术语、构念边界与表述准确',
                  value: _terminology,
                  onChanged: (value) =>
                      setState(() => _terminology = value),
                ),
                _CheckRow(
                  title: '安全边界与排除条件可接受',
                  value: _safety,
                  onChanged: (value) => setState(() => _safety = value),
                ),
                TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '依据、问题与修改建议',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(onPressed: _submit, child: const Text('保存结论')),
        ],
      );
}

class _ValidationNotice extends StatelessWidget {
  const _ValidationNotice();

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFEEF4FF),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.verified_user_outlined, color: Color(0xFF3448A1)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '系统已准备完整的内容与验证工作流，但不会把“尚待专家确认”伪装成正式内容。'
                  '只有与当前内容指纹一致的独立专家审核、真实用户访谈、试测统计和人工签发'
                  '全部通过，才允许发布。',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ValidationMetrics extends StatelessWidget {
  final int blueprintCount;
  final int expertReviewCount;
  final int cognitiveCount;
  final int pilotCount;

  const _ValidationMetrics({
    required this.blueprintCount,
    required this.expertReviewCount,
    required this.cognitiveCount,
    required this.pilotCount,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _MetricBox(
            value: '$blueprintCount/3105',
            label: '完整内容蓝图',
            color: const Color(0xFF4554C5),
          ),
          _MetricBox(
            value: '$expertReviewCount',
            label: '专家审核记录',
            color: const Color(0xFF7A4E9D),
          ),
          _MetricBox(
            value: '$cognitiveCount',
            label: '访谈记录',
            color: const Color(0xFFB54708),
          ),
          _MetricBox(
            value: '$pilotCount',
            label: '试测记录',
            color: const Color(0xFF39715D),
          ),
        ],
      );
}

class _ValidationActions extends StatelessWidget {
  final bool transferring;
  final int passedSeedCount;
  final VoidCallback onSeedReviews;
  final VoidCallback onExport;
  final VoidCallback onImport;

  const _ValidationActions({
    required this.transferring,
    required this.passedSeedCount,
    required this.onSeedReviews,
    required this.onExport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: <Widget>[
            ListTile(
              onTap: onSeedReviews,
              leading: const CircleAvatar(
                child: Icon(Icons.account_tree_outlined),
              ),
              title: const Text(
                '基础指标、证据、模式与处方确认',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('已有$passedSeedCount条真实专家结论通过'),
              trailing: const Icon(Icons.chevron_right),
            ),
            const Divider(height: 1, indent: 72),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: transferring ? null : onExport,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('导出验证包'),
                  ),
                ),
                const SizedBox(
                  height: 36,
                  child: VerticalDivider(width: 1),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: transferring ? null : onImport,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('导入验证包'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _CandidateValidationTile extends StatelessWidget {
  final CheckupContentCandidate candidate;
  final VoidCallback onTap;

  const _CandidateValidationTile({
    required this.candidate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gates = <bool>[
      candidate.evidenceReviewPassed,
      candidate.constructReviewPassed,
      candidate.cognitiveInterviewPassed,
      candidate.pilotPassed,
    ];
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(
            candidate.contentCode,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(
          '${candidate.primaryIndicatorId} · ${candidate.indicatorName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${candidate.stage.label} · 门槛${gates.where((value) => value).length}/4 · '
          '${candidate.content}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  final CheckupValidationDecision decision;
  final List<String> externalBlockers;

  const _DecisionCard({
    required this.decision,
    this.externalBlockers = const <String>[],
  });

  @override
  Widget build(BuildContext context) {
    final ready =
        decision.readyForHumanSignature && externalBlockers.isEmpty;
    return Card(
      color: ready ? const Color(0xFFE7F5EE) : const Color(0xFFFFF1E8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  ready ? Icons.verified_outlined : Icons.block_outlined,
                  color: ready
                      ? const Color(0xFF39715D)
                      : const Color(0xFFB54708),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ready ? '机器可核验门槛已通过，等待人工签发' : '当前禁止正式发布',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatusPill(
                  text: '课程审核',
                  passed: decision.evidenceReviewPassed,
                ),
                _StatusPill(
                  text: '构念审核',
                  passed: decision.constructReviewPassed,
                ),
                _StatusPill(
                  text: '安全审核',
                  passed: decision.safetyReviewPassed,
                ),
                _StatusPill(
                  text: '认知访谈',
                  passed: decision.cognitiveInterviewPassed,
                ),
                _StatusPill(text: '试测', passed: decision.pilotPassed),
                _StatusPill(
                  text:
                      '质量${decision.reviewedQuality.overall.toStringAsFixed(0)}',
                  passed:
                      decision.reviewedQuality.passesPublishedThresholds,
                ),
              ],
            ),
            if (decision.blockingIssues.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final issue in decision.blockingIssues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $issue'),
                ),
            ],
            if (externalBlockers.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final issue in externalBlockers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $issue'),
                ),
            ],
            if (decision.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final warning in decision.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '提示：$warning',
                    style: const TextStyle(color: Color(0xFF7A4E00)),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              '协议：${decision.protocolVersion}（D1暂行阈值，正式阈值须由研究方案冻结）',
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool currentFingerprint;

  const _RecordTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.currentFingerprint,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(
            currentFingerprint ? subtitle : '旧内容指纹，已自动失效 · $subtitle',
          ),
          trailing: Icon(
            currentFingerprint ? Icons.link : Icons.link_off,
            color: currentFingerprint
                ? const Color(0xFF39715D)
                : const Color(0xFFB42318),
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  final String text;
  final bool passed;

  const _StatusPill({required this.text, required this.passed});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: passed
              ? const Color(0xFFDDF3E8)
              : const Color(0xFFFFE8D9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${passed ? '✓' : '○'} $text',
          style: TextStyle(
            color: passed
                ? const Color(0xFF27614D)
                : const Color(0xFF9A4A08),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _MetricBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MetricBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: 158,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      );
}

class _ScoreSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _ScoreSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$label ${value.toStringAsFixed(0)}'),
          Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 20,
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ],
      );
}

class _CheckRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: value,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (next) => onChanged(next ?? false),
        title: Text(title),
      );
}

class _CompactField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool numeric;

  const _CompactField({
    required this.controller,
    required this.label,
    this.numeric = true,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType:
            numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, style: const TextStyle(color: Color(0xFF667085))),
        ),
      );
}

String _metricLabel(String key) => switch (key) {
      'cognitive_misunderstanding_rate' => '误解率',
      'cognitive_double_barrel_rate' => '双重问题率',
      'cognitive_leading_rate' => '诱导措辞率',
      'cognitive_burden_rate' => '负担率',
      'pilot_missing_rate' => '缺失率',
      'pilot_median_completion_ms' => '完成中位数',
      'pilot_floor_rate' => '地板率',
      'pilot_ceiling_rate' => '天花板率',
      'item_rest_correlation' => '题目区分度',
      'retest_correlation' => '重测相关',
      'criterion_correlation' => '效标相关',
      'normalized_group_gap' => '群体差异',
      'alarm_sensitivity' => '报警敏感度',
      'alarm_specificity' => '报警特异度',
      _ => key,
    };

String _metricValue(String key, double value) {
  if (key == 'pilot_median_completion_ms') {
    return '${(value / 1000).toStringAsFixed(0)}秒';
  }
  if (key.endsWith('_correlation')) return value.toStringAsFixed(2);
  return '${(value * 100).toStringAsFixed(1)}%';
}

String _shortKey(String value) {
  if (value.isEmpty) return '无有效匿名键';
  if (value.length <= 10) return value;
  return '${value.substring(0, 10)}…';
}
