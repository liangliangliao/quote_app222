import 'package:flutter/material.dart';

import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_repository.dart';
import 'mental_health_content_governance.dart';
import 'mental_health_generation_batch.dart';
import 'mental_health_generation_batch_service.dart';

class MentalHealthGenerationBatchPage extends StatefulWidget {
  final MentalHealthCheckupCatalog catalog;
  final MentalHealthCheckupRepository repository;

  const MentalHealthGenerationBatchPage({
    super.key,
    required this.catalog,
    required this.repository,
  });

  @override
  State<MentalHealthGenerationBatchPage> createState() =>
      _MentalHealthGenerationBatchPageState();
}

class _MentalHealthGenerationBatchPageState
    extends State<MentalHealthGenerationBatchPage> {
  late final MentalHealthGenerationBatchService _runner;
  List<CheckupGenerationBatch> _batches = const <CheckupGenerationBatch>[];
  bool _loading = true;
  String? _workingBatchId;
  int _chunkSize = 5;

  @override
  void initState() {
    super.initState();
    _runner = MentalHealthGenerationBatchService(repository: widget.repository);
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final batches = await widget.repository.loadGenerationBatches();
    if (!mounted) return;
    setState(() {
      _batches = batches;
      _loading = false;
    });
  }

  Future<void> _create() async {
    const governance = MentalHealthContentGovernanceEngine();
    final allPlans = governance.buildGenerationQueue(widget.catalog.indicators);
    var useAi = false;
    var lecture = 0;
    var name = '';
    final input = await showDialog<_BatchCreationInput>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final plans = lecture == 0
              ? allPlans
              : allPlans
                  .where((plan) => plan.lecture == lecture)
                  .toList(growable: false);
          final jobs = CheckupGenerationJob.expandPlans(
            batchId: 'preview',
            plans: plans,
            useAi: useAi,
            now: DateTime.fromMillisecondsSinceEpoch(0),
          );
          return AlertDialog(
            icon: Icon(
              useAi ? Icons.auto_awesome_outlined : Icons.offline_bolt_outlined,
            ),
            title: const Text('创建批量生成任务'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.offline_bolt_outlined),
                        label: Text('本地模板'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.auto_awesome_outlined),
                        label: Text('AI候选'),
                      ),
                    ],
                    selected: <bool>{useAi},
                    onSelectionChanged: (values) =>
                        setDialogState(() => useAi = values.first),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: lecture,
                    decoration: const InputDecoration(
                      labelText: '课程范围',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<int>>[
                      const DropdownMenuItem<int>(
                        value: 0,
                        child: Text('全部 Lecture 1—23'),
                      ),
                      for (var value = 1; value <= 23; value++)
                        DropdownMenuItem<int>(
                          value: value,
                          child: Text('Lecture $value'),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => lecture = value ?? 0),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(
                      labelText: '批次名称（可选）',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => name = value,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${plans.length} 项指标 · ${jobs.length} 个生成槽位\n'
                      '每个槽位独立保存状态，可分批继续、重试或取消。',
                      style: const TextStyle(
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (useAi) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'AI批次会产生供应商调用和费用。每次只处理你选择的'
                      '小批量；AI只能生成草稿，不能自动审核或签发。若已启用'
                      '供应商课程文件ID则复用，否则仅发送本地检索的课程摘录。',
                      style: TextStyle(color: Color(0xFFB54708), height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: plans.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          _BatchCreationInput(
                            useAi: useAi,
                            lecture: lecture,
                            name: name.trim(),
                          ),
                        ),
                child: const Text('创建任务'),
              ),
            ],
          );
        },
      ),
    );
    if (input == null || !mounted) return;
    final plans = input.lecture == 0
        ? allPlans
        : allPlans
            .where((plan) => plan.lecture == input.lecture)
            .toList(growable: false);
    final batch = await widget.repository.createGenerationBatch(
      name: input.name,
      useAi: input.useAi,
      plans: plans,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已创建 ${batch.totalJobs} 个可恢复任务。')));
    await _load();
  }

  Future<void> _run(CheckupGenerationBatch batch) async {
    if (batch.useAi) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('处理接下来 $_chunkSize 项？'),
          content: const Text(
            '将调用当前全局AI供应商。请求只包含课程知识、固定治理规则'
            '和生成槽位，不包含任何用户体检数据。生成结果仍为草稿。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('开始'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _workingBatchId = batch.id);
    try {
      final result = await _runner.runNextChunk(
        batch: batch,
        catalog: widget.catalog,
        maxJobs: _chunkSize,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '本轮 ${result.processed} 项：AI ${result.generated}，'
            '本地/回退 ${result.localFallbacks}，失败 ${result.failed}。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('批次执行失败：$error')));
    } finally {
      if (mounted) setState(() => _workingBatchId = null);
    }
    await _load();
  }

  Future<void> _retry(CheckupGenerationBatch batch) async {
    await widget.repository.retryFailedGenerationJobs(batch.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('失败项已重新排队。')));
    await _load();
  }

  Future<void> _cancel(CheckupGenerationBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消剩余任务？'),
        content: const Text('已生成的候选会保留；尚未执行和执行中的槽位会标记为已取消。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('取消剩余任务'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.repository.setGenerationBatchStatus(
      batch.id,
      CheckupGenerationBatchStatus.cancelled,
    );
    await _load();
  }

  Future<void> _openDetails(CheckupGenerationBatch batch) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MentalHealthGenerationBatchDetailPage(
          batch: batch,
          repository: widget.repository,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('批量候选生成'),
          actions: <Widget>[
            IconButton(
              tooltip: '刷新',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _workingBatchId == null ? _create : null,
          icon: const Icon(Icons.add),
          label: const Text('新建批次'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: <Widget>[
                    const _BatchNotice(),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: <Widget>[
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '单次处理量',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    '小批量运行可控制等待时间、费用和失败恢复范围。',
                                    style: TextStyle(
                                      color: Color(0xFF667085),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownButton<int>(
                              value: _chunkSize,
                              items: const <DropdownMenuItem<int>>[
                                DropdownMenuItem(value: 5, child: Text('5项')),
                                DropdownMenuItem(value: 10, child: Text('10项')),
                                DropdownMenuItem(value: 25, child: Text('25项')),
                              ],
                              onChanged: _workingBatchId == null
                                  ? (value) =>
                                      setState(() => _chunkSize = value ?? 5)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_batches.isEmpty)
                      const _BatchEmpty()
                    else
                      for (final batch in _batches)
                        _BatchCard(
                          batch: batch,
                          working: _workingBatchId == batch.id,
                          disabled: _workingBatchId != null,
                          onRun: () => _run(batch),
                          onRetry: () => _retry(batch),
                          onCancel: () => _cancel(batch),
                          onDetails: () => _openDetails(batch),
                        ),
                  ],
                ),
              ),
      );
}

class MentalHealthGenerationBatchDetailPage extends StatefulWidget {
  final CheckupGenerationBatch batch;
  final MentalHealthCheckupRepository repository;

  const MentalHealthGenerationBatchDetailPage({
    super.key,
    required this.batch,
    required this.repository,
  });

  @override
  State<MentalHealthGenerationBatchDetailPage> createState() =>
      _MentalHealthGenerationBatchDetailPageState();
}

class _MentalHealthGenerationBatchDetailPageState
    extends State<MentalHealthGenerationBatchDetailPage> {
  List<CheckupGenerationJob> _jobs = const <CheckupGenerationJob>[];
  CheckupGenerationJobStatus? _filter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final jobs = await widget.repository.loadGenerationJobs(widget.batch.id);
    if (!mounted) return;
    setState(() {
      _jobs = jobs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == null
        ? _jobs
        : _jobs.where((job) => job.status == _filter).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.batch.name),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      ChoiceChip(
                        label: Text('全部 ${_jobs.length}'),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      const SizedBox(width: 7),
                      for (final status
                          in CheckupGenerationJobStatus.values) ...[
                        ChoiceChip(
                          label: Text(
                            '${status.label} '
                            '${_jobs.where((job) => job.status == status).length}',
                          ),
                          selected: _filter == status,
                          onSelected: (_) => setState(() => _filter = status),
                        ),
                        const SizedBox(width: 7),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('没有匹配的任务。')),
                    ),
                  )
                else
                  for (final job in filtered)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: job.status.color.withValues(
                            alpha: 0.12,
                          ),
                          child: Icon(job.status.icon, color: job.status.color),
                        ),
                        title: Text(
                          '${job.indicatorId} · ${job.contentCode}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${job.status.label} · 尝试 ${job.attempts}'
                          '${job.candidateId.isEmpty ? '' : '\n候选：${job.candidateId}'}'
                          '${job.error.isEmpty ? '' : '\n${job.error}'}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine:
                            job.candidateId.isNotEmpty || job.error.isNotEmpty,
                      ),
                    ),
              ],
            ),
    );
  }
}

class _BatchCreationInput {
  final bool useAi;
  final int lecture;
  final String name;

  const _BatchCreationInput({
    required this.useAi,
    required this.lecture,
    required this.name,
  });
}

class _BatchNotice extends StatelessWidget {
  const _BatchNotice();

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFF7ED),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.rule_folder_outlined, color: Color(0xFFB54708)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '批量生成覆盖每项指标规定的A类题型与B0—B4任务槽位。'
                  '所有结果先进入候选治理库；中断后从本地任务状态继续，'
                  '不会把未审核文本直接混入正式体检。',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
}

class _BatchCard extends StatelessWidget {
  final CheckupGenerationBatch batch;
  final bool working;
  final bool disabled;
  final VoidCallback onRun;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onDetails;

  const _BatchCard({
    required this.batch,
    required this.working,
    required this.disabled,
    required this.onRun,
    required this.onRetry,
    required this.onCancel,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final actionable = batch.status != CheckupGenerationBatchStatus.completed &&
        batch.status != CheckupGenerationBatchStatus.cancelled;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  batch.useAi
                      ? Icons.auto_awesome_outlined
                      : Icons.offline_bolt_outlined,
                  color: const Color(0xFF4554C5),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    batch.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  batch.status.label,
                  style: TextStyle(
                    color: batch.status.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: batch.progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 7),
            Text(
              '${batch.completedJobs}/${batch.totalJobs} 已生成'
              '${batch.failedJobs == 0 ? '' : ' · ${batch.failedJobs} 失败'}',
              style: const TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: disabled ? null : onDetails,
                    child: const Text('查看任务'),
                  ),
                ),
                if (batch.failedJobs > 0 && actionable) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: disabled ? null : onRetry,
                      child: const Text('重试失败项'),
                    ),
                  ),
                ],
                if (actionable) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: disabled ? null : onRun,
                      icon: working
                          ? const SizedBox.square(
                              dimension: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(working ? '处理中' : '继续'),
                    ),
                  ),
                ],
              ],
            ),
            if (actionable) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: disabled ? null : onCancel,
                  child: const Text('取消剩余任务'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BatchEmpty extends StatelessWidget {
  const _BatchEmpty();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              Icon(Icons.playlist_add_outlined, size: 38),
              SizedBox(height: 9),
              Text('还没有批量任务', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text(
                '可按全部课程或指定Lecture创建本地/AI候选批次。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
      );
}

extension on CheckupGenerationBatchStatus {
  String get label => switch (this) {
        CheckupGenerationBatchStatus.queued => '待运行',
        CheckupGenerationBatchStatus.running => '运行中',
        CheckupGenerationBatchStatus.paused => '可继续',
        CheckupGenerationBatchStatus.completed => '已完成',
        CheckupGenerationBatchStatus.cancelled => '已取消',
      };

  Color get color => switch (this) {
        CheckupGenerationBatchStatus.queued => const Color(0xFF667085),
        CheckupGenerationBatchStatus.running => const Color(0xFF4554C5),
        CheckupGenerationBatchStatus.paused => const Color(0xFFB54708),
        CheckupGenerationBatchStatus.completed => const Color(0xFF39715D),
        CheckupGenerationBatchStatus.cancelled => const Color(0xFFC62828),
      };
}

extension on CheckupGenerationJobStatus {
  String get label => switch (this) {
        CheckupGenerationJobStatus.queued => '排队',
        CheckupGenerationJobStatus.running => '运行中',
        CheckupGenerationJobStatus.generated => 'AI已生成',
        CheckupGenerationJobStatus.localFallback => '本地/回退',
        CheckupGenerationJobStatus.failed => '失败',
        CheckupGenerationJobStatus.cancelled => '已取消',
      };

  Color get color => switch (this) {
        CheckupGenerationJobStatus.queued => const Color(0xFF667085),
        CheckupGenerationJobStatus.running => const Color(0xFF4554C5),
        CheckupGenerationJobStatus.generated => const Color(0xFF39715D),
        CheckupGenerationJobStatus.localFallback => const Color(0xFF7A4E9D),
        CheckupGenerationJobStatus.failed => const Color(0xFFC62828),
        CheckupGenerationJobStatus.cancelled => const Color(0xFF667085),
      };

  IconData get icon => switch (this) {
        CheckupGenerationJobStatus.queued => Icons.schedule,
        CheckupGenerationJobStatus.running => Icons.sync,
        CheckupGenerationJobStatus.generated => Icons.auto_awesome,
        CheckupGenerationJobStatus.localFallback => Icons.offline_bolt_outlined,
        CheckupGenerationJobStatus.failed => Icons.error_outline,
        CheckupGenerationJobStatus.cancelled => Icons.block_outlined,
      };
}
