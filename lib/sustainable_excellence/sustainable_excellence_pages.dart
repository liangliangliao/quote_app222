import 'dart:async';

import 'package:flutter/material.dart';

import 'sustainable_excellence_ai_service.dart';
import 'sustainable_excellence_dao.dart';
import 'sustainable_excellence_models.dart';
import 'sustainable_excellence_todo_bridge.dart';

class SustainableExperimentRunnerPage extends StatefulWidget {
  final SustainableExcellenceCase item;
  final SustainableActionExperiment experiment;

  const SustainableExperimentRunnerPage({super.key, required this.item, required this.experiment});

  @override
  State<SustainableExperimentRunnerPage> createState() => _SustainableExperimentRunnerPageState();
}

class _SustainableExperimentRunnerPageState extends State<SustainableExperimentRunnerPage> {
  final SustainableExcellenceDao _dao = SustainableExcellenceDao();
  final SustainableExcellenceAiService _ai = SustainableExcellenceAiService();
  final SustainableExcellenceTodoBridge _todo = SustainableExcellenceTodoBridge();
  final TextEditingController _resultCtrl = TextEditingController();
  final TextEditingController _emotionCtrl = TextEditingController();
  Timer? _timer;
  int _seconds = 0;
  int _actionSeconds = 0;
  int _recoverySeconds = 5 * 60;
  String _phase = 'prepare';
  bool _running = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _actionSeconds = _secondsForExperiment(widget.experiment);
    _seconds = _actionSeconds;
    _recoverySeconds = _recoverySecondsForExperiment(widget.experiment);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resultCtrl.dispose();
    _emotionCtrl.dispose();
    super.dispose();
  }

  int _secondsForExperiment(SustainableActionExperiment exp) {
    final text = '${exp.timeRequired} ${exp.title}';
    if (text.contains('90')) return 90 * 60;
    if (text.contains('45')) return 45 * 60;
    if (text.contains('40')) return 40 * 60;
    if (text.contains('30') || text.contains('25')) return 25 * 60;
    return 5 * 60;
  }

  int _recoverySecondsForExperiment(SustainableActionExperiment exp) {
    final text = '${exp.timeRequired} ${exp.recoveryAfter}';
    if (text.contains('15')) return 15 * 60;
    if (text.contains('8')) return 8 * 60;
    return 5 * 60;
  }

  void _resetAction() {
    _timer?.cancel();
    setState(() { _phase = 'prepare'; _seconds = _actionSeconds; _running = false; });
  }

  Future<void> _enterRecoveryPhase() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() { _phase = 'recovery'; _seconds = _recoverySeconds; _running = false; });
    await _todo.markSourceTodoStage(widget.item, '行动计时结束，进入恢复阶段：${widget.experiment.title}');
  }

  void _startPause() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_phase == 'prepare') _phase = 'action';
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_seconds <= 1) {
        t.cancel();
        if (!mounted) return;
        if (_phase == 'action') {
          setState(() { _seconds = 0; _running = false; });
          await _enterRecoveryPhase();
        } else if (_phase == 'recovery') {
          setState(() { _seconds = 0; _running = false; _phase = 'review'; });
          await _recordRecovery(auto: true);
        }
      } else if (mounted) {
        setState(() => _seconds -= 1);
      }
    });
  }


  Future<void> _complete() async {
    if (_phase != 'review') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先经历行动与恢复阶段，再完成复盘。')));
      return;
    }
    final note = await _askText(title: '行动完成复盘', label: '我实际完成了什么？哪个条件帮助我行动？');
    if (note == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.addLog(widget.item.id, SustainableEvidenceLog(
      id: 'selog_${DateTime.now().microsecondsSinceEpoch}',
      caseId: widget.item.id,
      experimentType: widget.experiment.type,
      type: 'action',
      title: '行动完成：${widget.experiment.title}',
      note: note.trim().isEmpty ? '完成了一次行动实验。' : note.trim(),
      details: <String>['过程锚点：${widget.experiment.processAnchor}', '行动后恢复：${widget.experiment.recoveryAfter}'],
      spiralStage: SustainableSpiralStage.action,
      createdAtMs: now,
    ));
    await _todo.markSourceTodoStage(widget.item, '已完成行动实验：${widget.experiment.title}');
    await _dao.addLog(widget.item.id, SustainableEvidenceLog(
      id: 'selog_${DateTime.now().microsecondsSinceEpoch + 1}',
      caseId: widget.item.id,
      experimentType: widget.experiment.type,
      type: 'process',
      title: '过程体验复盘',
      note: widget.item.processEnjoyment.afterActionReflection,
      details: <String>[widget.item.processEnjoyment.onePercentExperience],
      spiralStage: SustainableSpiralStage.feedback,
      createdAtMs: now + 1,
    ));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _fail() async {
    if (_phase == 'prepare') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先开始行动；如果还没开始，请记录行动前恢复或把任务缩小。')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('失败学习复盘'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const Text('失败不是自我判决，而是系统反馈。请写事实，不写人格结论。'),
            const SizedBox(height: 12),
            TextField(controller: _resultCtrl, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '实际发生了什么？', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _emotionCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: '当时的感受/卡点', border: OutlineInputBorder())),
          ]),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('生成失败学习')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      final review = await _ai.generateFailureReview(
        item: widget.item,
        experiment: widget.experiment,
        actualResult: _resultCtrl.text.trim(),
        emotion: _emotionCtrl.text.trim(),
      );
      await _dao.applyFailureReview(widget.item.id, review);
      final details = <String>[
        '失败类型：${review['failure_type'] ?? '启动失败'}',
        '学习点：${review['learning_point'] ?? ''}',
        '下一轮：${review['next_smaller_experiment'] ?? ''}',
      ];
      await _dao.addLog(widget.item.id, SustainableEvidenceLog(
        id: 'selog_${DateTime.now().microsecondsSinceEpoch}',
        caseId: widget.item.id,
        experimentType: widget.experiment.type,
        type: 'failure_learning',
        title: '失败学习：${review['failure_type'] ?? '启动失败'}',
        note: (review['depersonalized_reframe'] ?? '这次失败是行动系统反馈。').toString(),
        details: details,
        aiSummary: (review['strategy_change'] ?? '').toString(),
        spiralStage: SustainableSpiralStage.failedOrStuck,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ));
      await _todo.markSourceTodoStage(widget.item, '完成失败学习复盘：${review['failure_type'] ?? '启动失败'}');
      if (!mounted) return;
      final write = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('写回下一轮 Todo？'),
          content: Text((review['todo_writeback_title'] ?? review['next_smaller_experiment'] ?? '生成下一轮更小实验').toString()),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('暂不')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('写回 Todo')),
          ],
        ),
      );
      if (write == true) {
        final stepsRaw = review['todo_writeback_steps'];
        final steps = stepsRaw is List ? stepsRaw.map((e) => e.toString()).toList() : <String>['完成第一小步', '记录反馈', '安排恢复'];
        final latest = await _dao.getCase(widget.item.id) ?? widget.item;
        final generatedId = await _todo.writeFailureNextTodo(item: latest, title: (review['todo_writeback_title'] ?? '').toString(), steps: steps);
        await _todo.markSourceTodoStage(latest.copyWith(linkedTodoTaskId: generatedId), '失败复盘后已生成下一轮 Todo：$generatedId');
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _recordRecovery({bool auto = false}) async {
    if (!auto && _phase == 'action') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('行动阶段先专注当前小实验，恢复记录会在行动后阶段进行。')));
      return;
    }
    final stateText = auto ? widget.experiment.recoveryAfter : '手动恢复记录；当前阶段：$_phase；建议：${widget.experiment.recoveryAfter}';
    final plan = await _ai.generatePressureRecoveryPlan(item: widget.item, stateText: stateText);
    await _dao.applyPressureRecoveryPlan(widget.item.id, plan);
    final title = _phase == 'prepare' ? '行动前恢复' : '行动后恢复';
    final note = auto ? '恢复计时完成：${widget.experiment.recoveryAfter}' : widget.experiment.recoveryAfter;
    final micro = plan['micro_recovery'] is List ? (plan['micro_recovery'] as List).map((e) => e.toString()).take(3).join('；') : '';
    await _dao.addLog(widget.item.id, SustainableEvidenceLog(
      id: 'selog_${DateTime.now().microsecondsSinceEpoch}',
      caseId: widget.item.id,
      experimentType: widget.experiment.type,
      type: 'recovery',
      title: title,
      note: note,
      details: <String>[
        '推荐节律：${plan['rhythm'] ?? widget.item.recoveryPlan.recommendedRhythm}',
        if ((plan['explanation'] ?? '').toString().trim().isNotEmpty) 'AI恢复解释：${plan['explanation']}',
        if (micro.isNotEmpty) '微恢复：$micro',
      ],
      aiSummary: (plan['warning'] ?? '').toString(),
      spiralStage: SustainableSpiralStage.recovery,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
    await _todo.markSourceTodoStage(widget.item, auto ? '恢复阶段已完成' : '已记录${_phase == 'prepare' ? '行动前' : '行动后'}恢复');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auto ? '恢复阶段已完成' : '已记录恢复')));
  }

  Future<String?> _askText({required String title, required String label}) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, minLines: 3, maxLines: 6, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    final text = ctrl.text;
    ctrl.dispose();
    return ok == true ? text : null;
  }

  String get _phaseLabel {
    switch (_phase) {
      case 'action': return '行动阶段：只做当前小实验';
      case 'recovery': return '恢复阶段：让压力被身体消化';
      case 'review': return '复盘阶段：把结果转成反馈';
      default: return '准备阶段：先恢复，再行动';
    }
  }

  String get _timeLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(title: const Text('行动执行'), backgroundColor: const Color(0xFFF7F7FB)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            _Card(icon: Icons.play_circle_outline, title: widget.experiment.title, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(widget.experiment.suitableWhen, style: const TextStyle(height: 1.45, color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              Center(child: Text(_phaseLabel, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4338CA)))),
              const SizedBox(height: 6),
              Center(child: Text(_timeLabel, style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: Color(0xFF4338CA)))),
              Row(children: <Widget>[
                Expanded(child: FilledButton.icon(onPressed: _saving ? null : _startPause, icon: Icon(_running ? Icons.pause : Icons.play_arrow), label: Text(_running ? '暂停' : '开始'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: (_saving || _phase == 'action') ? null : () => _recordRecovery(), icon: const Icon(Icons.self_improvement_outlined), label: Text(_phase == 'prepare' ? '行动前恢复' : '记录恢复'))),
              ]),
              TextButton.icon(onPressed: _saving ? null : _resetAction, icon: const Icon(Icons.refresh), label: const Text('重置为准备阶段')),
            ])),
            const SizedBox(height: 12),
            _Card(icon: Icons.checklist_outlined, title: '行动步骤', child: _Bullets(widget.experiment.steps)),
            const SizedBox(height: 12),
            _Card(icon: Icons.spa_outlined, title: '恢复与过程锚点', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              _Line('行动前恢复', widget.experiment.recoveryBefore),
              _Line('过程锚点', widget.experiment.processAnchor),
              _Line('行动后恢复', widget.experiment.recoveryAfter),
              _Line('失败学习', widget.experiment.failureLearningMethod),
            ])),
            const SizedBox(height: 12),
            Row(children: <Widget>[
              Expanded(child: FilledButton.icon(onPressed: (_saving || _phase != 'review') ? null : _complete, icon: const Icon(Icons.check_circle_outline), label: const Text('完成并复盘'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: (_saving || _phase == 'prepare') ? null : _fail, icon: const Icon(Icons.replay_outlined), label: const Text('失败学习'))),
            ]),
          ],
        ),
      );
}

class SustainableReviewPage extends StatefulWidget {
  final String reviewType;
  const SustainableReviewPage({super.key, this.reviewType = 'daily'});

  @override
  State<SustainableReviewPage> createState() => _SustainableReviewPageState();
}

class _SustainableReviewPageState extends State<SustainableReviewPage> {
  final SustainableExcellenceDao _dao = SustainableExcellenceDao();
  final SustainableExcellenceAiService _ai = SustainableExcellenceAiService();
  bool _loading = true;
  bool _generating = false;
  List<SustainableDailyReview> _reviews = <SustainableDailyReview>[];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final reviews = await _dao.loadReviewsByType(widget.reviewType);
    if (!mounted) return;
    setState(() { _reviews = reviews; _loading = false; });
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final allCases = await _dao.loadCases();
      final cases = _casesInRange(allCases);
      final review = await _ai.generateDailyReview(cases: cases, reviewType: widget.reviewType);
      await _dao.saveReview(review);
      await _load();
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  List<SustainableExcellenceCase> _casesInRange(List<SustainableExcellenceCase> cases) {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final startDate = widget.reviewType == 'weekly' ? dayStart.subtract(Duration(days: dayStart.weekday - 1)) : dayStart;
    final endDate = widget.reviewType == 'weekly' ? startDate.add(const Duration(days: 7)) : dayStart.add(const Duration(days: 1));
    final start = startDate.millisecondsSinceEpoch;
    final end = endDate.millisecondsSinceEpoch;
    return cases.map((c) {
      final filteredLogs = c.logs.where((l) => l.createdAtMs >= start && l.createdAtMs < end).toList();
      return c.copyWith(logs: filteredLogs);
    }).where((c) => c.logs.isNotEmpty || (widget.reviewType == 'weekly' && c.updatedAtMs >= start)).toList();
  }

  Future<void> _deleteReview(SustainableDailyReview review) async {
    await _dao.deleteReview(review.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(title: Text(widget.reviewType == 'weekly' ? '周度卓越报告' : '每日卓越复盘'), backgroundColor: const Color(0xFFF7F7FB)),
        body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _generating ? null : _generate, icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: Text(_generating ? '正在生成…' : '生成复盘报告'))),
            const SizedBox(height: 12),
            if (_reviews.isEmpty) const Text('还没有复盘报告。') else for (final r in _reviews) _ReviewCard(review: r, onDelete: () => _deleteReview(r)),
          ],
        ),
      );
}


class SustainablePerfectionismTrainingPage extends StatefulWidget {
  final SustainableExcellenceCase item;
  const SustainablePerfectionismTrainingPage({super.key, required this.item});

  @override
  State<SustainablePerfectionismTrainingPage> createState() => _SustainablePerfectionismTrainingPageState();
}

class _SustainablePerfectionismTrainingPageState extends State<SustainablePerfectionismTrainingPage> {
  final SustainableExcellenceDao _dao = SustainableExcellenceDao();
  final SustainableExcellenceTodoBridge _todo = SustainableExcellenceTodoBridge();
  final SustainableExcellenceAiService _ai = SustainableExcellenceAiService();
  bool _saving = false;

  Future<void> _runTraining(String title, List<String> steps, String reminder) async {
    final note = await _askTrainingResult(title);
    if (note == null) return;
    setState(() => _saving = true);
    try {
      final exp = SustainableActionExperiment(
        type: 'perfectionism_training',
        title: title,
        suitableWhen: '当用户把高标准变成自我审判、害怕提交、过度准备或迟迟不开始时。',
        steps: steps,
        timeRequired: title.contains('5分钟') ? '5分钟' : '25分钟',
        failurePoint: '把不完美结果等同于自我失败。',
        failureLearningMethod: '失败后只提取一个可改变变量，不做人格结论。',
        recoveryBefore: '开始前写下：我保留高标准，但不把结果当作人格审判。',
        recoveryAfter: '完成后离开任务 3 分钟，避免立刻反复检查。',
        processAnchor: reminder,
      );
      final scan = await _ai.generatePerfectionismScan(item: widget.item, userInput: '${widget.item.userGoal}\n$title\n$note');
      await _dao.applyPerfectionismScan(widget.item.id, scan);
      final preserve = scan['preserve'] is List ? (scan['preserve'] as List).map((e) => e.toString()).join('；') : '';
      final adjust = scan['adjust'] is List ? (scan['adjust'] as List).map((e) => e.toString()).join('；') : '';
      await _dao.addLog(widget.item.id, SustainableEvidenceLog(
        id: 'selog_${DateTime.now().microsecondsSinceEpoch}',
        caseId: widget.item.id,
        experimentType: exp.type,
        type: 'process',
        title: '完美主义训练：$title',
        note: note.trim().isEmpty ? reminder : note.trim(),
        details: <String>[
          ...steps,
          if ((scan['mode'] ?? '').toString().trim().isNotEmpty) 'AI识别模式：${scan['mode']}',
          if (preserve.isNotEmpty) '保留：$preserve',
          if (adjust.isNotEmpty) '调整：$adjust',
        ],
        aiSummary: (scan['explanation'] ?? '').toString(),
        spiralStage: SustainableSpiralStage.feedback,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ));
      await _todo.markSourceTodoStage(widget.item, '完成完美主义训练：$title');
      if (!mounted) return;
      final write = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('把这次训练写回 Todo？'),
          content: Text('生成一个可继续练习的 Todo：$title'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('暂不')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('写回 Todo')),
          ],
        ),
      );
      if (write == true) await _todo.writeExperimentTodo(widget.item, exp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('训练记录已保存')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askTrainingResult(String title) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: '这次练习中，我实际做了什么？我如何面对不完美？', border: OutlineInputBorder()),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    final text = ctrl.text;
    ctrl.dispose();
    return ok == true ? text : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(title: const Text('完美主义训练器'), backgroundColor: const Color(0xFFF7F7FB)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: <Widget>[
          _Card(icon: Icons.balance_outlined, title: '不是降低追求，而是改变失败关系', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _Line('保留', widget.item.valueMapping.preserve.join('、')),
            _Line('调整', widget.item.valueMapping.adjust.join('、')),
            _Line('重构', widget.item.valueMapping.coreReframe),
          ])),
          const SizedBox(height: 12),
          _DynamicTrainingTile(title: '提交不完美版本练习', steps: const <String>['定义最低可交付标准', '限制修改次数', '提交一个可反馈版本', '只收集反馈，不做人格审判'], reminder: '真正的卓越来自反馈循环，不来自无错幻想。', saving: _saving, onStart: _runTraining),
          _DynamicTrainingTile(title: '5分钟粗糙开始练习', steps: const <String>['打开材料', '只做第一小步', '不要求完整', '结束时写一个反馈'], reminder: '我正在练习开始，而不是证明自己完美。', saving: _saving, onStart: _runTraining),
          _DynamicTrainingTile(title: '失败预演与复盘练习', steps: const <String>['写下可能失败点', '提前写失败后的处理句', '失败后只提取一个变量', '生成下一轮更小实验'], reminder: '失败不是结论，而是数据。', saving: _saving, onStart: _runTraining),
        ]),
      );
}

class SustainableProcessTrainingPage extends StatefulWidget {
  final SustainableExcellenceCase item;
  const SustainableProcessTrainingPage({super.key, required this.item});

  @override
  State<SustainableProcessTrainingPage> createState() => _SustainableProcessTrainingPageState();
}

class _SustainableProcessTrainingPageState extends State<SustainableProcessTrainingPage> {
  final SustainableExcellenceDao _dao = SustainableExcellenceDao();
  final SustainableExcellenceTodoBridge _todo = SustainableExcellenceTodoBridge();
  final SustainableExcellenceAiService _ai = SustainableExcellenceAiService();
  final TextEditingController _painCtrl = TextEditingController();
  bool _saving = false;
  String _anchor = '掌控感';

  @override
  void dispose() { _painCtrl.dispose(); super.dispose(); }

  Future<void> _saveProcessTraining() async {
    setState(() => _saving = true);
    try {
      final pain = _painCtrl.text.trim();
      final note = pain.isEmpty
          ? '我选择用“$_anchor”作为过程锚点，只寻找 1% 的过程体验。'
          : '这个任务痛苦点：$pain；我选择用“$_anchor”作为过程锚点，只寻找 1% 的过程体验。';
      final reframe = await _ai.generateProcessReframe(item: widget.item, task: widget.item.userGoal, feeling: pain);
      await _dao.applyProcessReframe(widget.item.id, reframe);
      final experiences = reframe['one_percent_experience'] is List ? (reframe['one_percent_experience'] as List).map((e) => e.toString()).toList() : <String>[];
      await _dao.addLog(widget.item.id, SustainableEvidenceLog(
        id: 'selog_${DateTime.now().microsecondsSinceEpoch}',
        caseId: widget.item.id,
        experimentType: 'process_training',
        type: 'process',
        title: '过程享受训练：$_anchor',
        note: note,
        details: <String>[
          widget.item.processEnjoyment.meaningConnection,
          widget.item.processEnjoyment.onePercentExperience,
          widget.item.processEnjoyment.afterActionReflection,
          if ((reframe['validation'] ?? '').toString().trim().isNotEmpty) 'AI承认：${reframe['validation']}',
          if ((reframe['long_term_value'] ?? '').toString().trim().isNotEmpty) '长期价值：${reframe['long_term_value']}',
          ...experiences,
          if ((reframe['during_action_sentence'] ?? '').toString().trim().isNotEmpty) '行动中提醒：${reframe['during_action_sentence']}',
        ],
        aiSummary: (reframe['low_pressure_method'] ?? '').toString(),
        spiralStage: SustainableSpiralStage.feedback,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ));
      await _todo.markSourceTodoStage(widget.item, '完成过程享受训练：$_anchor');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('过程训练已写入成长证据')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(title: const Text('过程享受训练'), backgroundColor: const Color(0xFFF7F7FB)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: <Widget>[
          _Card(icon: Icons.spa_outlined, title: '不强迫快乐，只寻找 1%', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _Line('意义连接', widget.item.processEnjoyment.meaningConnection),
            _Line('1% 体验', widget.item.processEnjoyment.onePercentExperience),
            _Line('行动中提醒', widget.item.processEnjoyment.duringActionReminder),
            _Line('行动后复盘', widget.item.processEnjoyment.afterActionReflection),
          ])),
          const SizedBox(height: 12),
          _Card(icon: Icons.edit_note_outlined, title: '动态过程重构', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            TextField(controller: _painCtrl, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '这个任务最痛苦/最枯燥的地方是什么？', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              for (final a in const <String>['能力感', '掌控感', '意义感', '好奇心', '身体节奏', '自由感', '未来自我连接'])
                ChoiceChip(label: Text(a), selected: _anchor == a, onSelected: (_) => setState(() => _anchor = a)),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _saveProcessTraining, icon: const Icon(Icons.save_outlined), label: const Text('保存过程训练证据'))),
          ])),
          const SizedBox(height: 12),
          const _TrainingTile(title: '过程锚点参考', steps: <String>['能力感：我正在练什么', '掌控感：我能控制哪一步', '意义感：它连接到什么长期价值', '身体节奏：我如何慢下来'], reminder: '过程不是终点的附属品，过程本身也能积累生命感。'),
        ]),
      );
}

class _DynamicTrainingTile extends StatelessWidget {
  final String title;
  final List<String> steps;
  final String reminder;
  final bool saving;
  final Future<void> Function(String title, List<String> steps, String reminder) onStart;
  const _DynamicTrainingTile({required this.title, required this.steps, required this.reminder, required this.saving, required this.onStart});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _Card(icon: Icons.fitness_center_outlined, title: title, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      _Bullets(steps),
      const SizedBox(height: 8),
      Text(reminder, style: const TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.w800, height: 1.45)),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saving ? null : () => onStart(title, steps, reminder), icon: const Icon(Icons.play_arrow), label: const Text('开始训练并记录'))),
    ])),
  );
}

class _ReviewCard extends StatelessWidget {
  final SustainableDailyReview review;
  final VoidCallback onDelete;
  const _ReviewCard({required this.review, required this.onDelete});
  @override
  Widget build(BuildContext context) => _Card(icon: Icons.summarize_outlined, title: review.title, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 16), label: const Text('删除报告'))),
    Text(review.summary, style: const TextStyle(height: 1.45, fontWeight: FontWeight.w700)),
    const SizedBox(height: 10),
    _Line('行动证据', review.actionEvidence.join('；')),
    _Line('失败模式', review.failurePatterns.join('；')),
    _Line('恢复洞察', review.recoveryInsights.join('；')),
    _Line('过程体验', review.processInsights.join('；')),
    _Line('下一轮变量', review.nextOneVariable),
  ]));
}

class _TrainingTile extends StatelessWidget {
  final String title;
  final List<String> steps;
  final String reminder;
  const _TrainingTile({required this.title, required this.steps, required this.reminder});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _Card(icon: Icons.fitness_center_outlined, title: title, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      _Bullets(steps),
      const SizedBox(height: 8),
      Text(reminder, style: const TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.w800, height: 1.45)),
    ])),
  );
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 8))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[Icon(icon, color: const Color(0xFF4338CA)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _Line extends StatelessWidget {
  final String label;
  final String text;
  const _Line(this.label, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(text: TextSpan(style: const TextStyle(color: Color(0xFF111827), height: 1.45), children: <TextSpan>[
          TextSpan(text: '$label：', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4338CA))),
          TextSpan(text: text.trim().isEmpty ? '暂无' : text),
        ])),
      );
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  const _Bullets(this.items);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: items.map((e) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[const Text('• ', style: TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.w900)), Expanded(child: Text(e, style: const TextStyle(height: 1.4)))]),
  )).toList());
}
