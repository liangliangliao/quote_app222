import 'package:flutter/material.dart';

import '../../../cognitive_consistency/cognitive_consistency_home_page.dart';
import '../../../cognitive_consistency/cognitive_consistency_source_status_card.dart';

import '../../cabins/training_cabin_models.dart';
import '../../cabins/training_intro_page.dart';
import '../../concept_engine_dao.dart';
import '../models/action_engine_models.dart';
import '../repository/action_engine_dao.dart';
import '../repository/action_engine_repository.dart';
import 'action_feedback_page.dart';

class ActionExecutionPage extends StatefulWidget {
  final ActionPlan plan;

  const ActionExecutionPage({super.key, required this.plan});

  @override
  State<ActionExecutionPage> createState() => _ActionExecutionPageState();
}

class _ActionExecutionPageState extends State<ActionExecutionPage> {
  final _dao = ActionEngineDao();
  final _repo = ActionEngineRepository();
  final _worldDao = ConceptEngineDao();
  late List<ActionStepExecution> _records;
  late String _executionId;
  late DateTime _startedAt;
  final _noteCtrl = TextEditingController();
  final Map<String, CabinAssistResult> _assistResults = {};

  @override
  void initState() {
    super.initState();
    _executionId = 'exec_${DateTime.now().millisecondsSinceEpoch}';
    _startedAt = DateTime.now();
    _records = [
      for (int i = 0; i < widget.plan.steps.length; i++)
        ActionStepExecution(
          stepId: widget.plan.steps[i].id,
          stepOrder: i,
          stepText: widget.plan.steps[i].text,
          completed: false,
          encounteredFriction: false,
        )
    ];
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  int get _currentIndex => _records.indexWhere((e) => !e.completed);
  bool get _finished => _currentIndex == -1;
  ActionStep get _currentPlanStep => widget.plan.steps[_currentIndex];
  ActionStepExecution get _currentRecord => _records[_currentIndex];
  CabinAssistResult? get _currentAssist => _assistResults[_currentPlanStep.id];

  Future<void> _completeStep() async {
    setState(() {
      _records[_currentIndex] = ActionStepExecution(
        stepId: _currentRecord.stepId,
        stepOrder: _currentRecord.stepOrder,
        stepText: _currentRecord.stepText,
        completed: true,
        encounteredFriction: _currentRecord.encounteredFriction,
        frictionType: _currentRecord.frictionType,
        fallbackAction: _currentRecord.fallbackAction,
        userNote: _noteCtrl.text.trim().isEmpty ? _currentRecord.userNote : _noteCtrl.text.trim(),
      );
      _noteCtrl.clear();
    });
    if (_finished) {
      await _finishExecution();
    }
  }

  void _shrinkStep() {
    final current = _currentPlanStep;
    final minimal = current.minimalVersion?.trim();
    if (minimal == null || minimal.isEmpty || minimal == _currentRecord.stepText) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('这一步已经是最小版本，或没有更小版本了。')));
      return;
    }
    setState(() {
      _records[_currentIndex] = ActionStepExecution(
        stepId: _currentRecord.stepId,
        stepOrder: _currentRecord.stepOrder,
        stepText: minimal,
        completed: false,
        encounteredFriction: true,
        frictionType: FrictionType.stepTooLarge.label,
        fallbackAction: minimal,
        userNote: _currentRecord.userNote,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已把当前步骤缩小为最小可执行版本。')));
  }


  Future<void> _openCognitiveConsistency({int initialTabIndex = 1}) async {
    final step = _currentPlanStep;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CognitiveConsistencyHomePage(
          initialTabIndex: initialTabIndex,
          initialGoal: widget.plan.goal.trim().isEmpty ? widget.plan.concept : widget.plan.goal,
          initialContext: '概念行动引擎步骤：${step.text}\n行动链：${widget.plan.title}\n概念：${widget.plan.concept}\n直接指令：${step.directInstruction ?? ''}\n执行提示：${step.executionHint ?? ''}\n完成信号：${step.doneSignal ?? ''}',
          initialValues: step.tags.join('；'),
          sourceType: 'concept_action_step',
          sourceId: '${widget.plan.planId}:${step.id}',
        ),
      ),
    );
    if (!mounted || changed != true) return;
    final markDone = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('一致行动已产生变化'),
        content: const Text('是否把当前概念行动步骤同步标记为完成？如果只是生成方案但没有实际执行，请选择“暂不”。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('暂不')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('标记完成')),
        ],
      ),
    );
    if (!mounted) return;
    if (markDone == true && !_finished) {
      await _completeStep();
    } else {
      setState(() {});
    }
  }

  Future<void> _openFrictionSheet() async {
    final current = _currentPlanStep;
    final type = await showModalBottomSheet<FrictionType>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('你卡住了？先告诉系统卡在哪', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('只有当你真的卡住时，才需要进入异常处理。正常情况下，直接完成当前步骤即可。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
                const SizedBox(height: 14),
                ...FrictionType.values.map((e) => ListTile(
                      title: Text(e.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(e),
                    )),
              ],
            ),
          ),
        );
      },
    );
    if (type == null) return;
    final suggestions = _repo.suggestFallbackSteps(type, current);
    if (!mounted) return;
    final fallback = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('异常处理 · ${type.label}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('系统给你几个更小、更容易开始的替代动作。选一个继续，而不是推倒重来。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
              const SizedBox(height: 12),
              ...suggestions.map((s) => ListTile(
                    title: Text(s),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(s),
                  )),
            ],
          ),
        ),
      ),
    );
    if (fallback == null) return;

    await _dao.logFriction(
      executionId: _executionId,
      stepId: current.id,
      frictionType: type.label,
      suggestedFallback: fallback,
      chosenFallback: fallback,
    );

    setState(() {
      _records[_currentIndex] = ActionStepExecution(
        stepId: _currentRecord.stepId,
        stepOrder: _currentRecord.stepOrder,
        stepText: fallback,
        completed: false,
        encounteredFriction: true,
        frictionType: type.label,
        fallbackAction: fallback,
        userNote: _currentRecord.userNote,
      );
    });
  }

  Future<void> _skipToNext() async {
    final idx = _currentIndex;
    final current = _currentRecord;
    setState(() {
      _records[idx] = ActionStepExecution(
        stepId: current.stepId,
        stepOrder: current.stepOrder,
        stepText: current.stepText,
        completed: false,
        encounteredFriction: true,
        frictionType: current.frictionType ?? '暂时跳过',
        fallbackAction: current.fallbackAction,
        userNote: (_noteCtrl.text.trim().isEmpty ? current.userNote : _noteCtrl.text.trim()) ?? '本轮暂时跳过此步',
      );
      final item = _records.removeAt(idx);
      _records.add(item);
      _noteCtrl.clear();
    });
  }

  Future<void> _openCabinAssist() async {
    final current = _currentPlanStep;
    final type = trainingCabinTypeFromId(current.linkedCabinType);
    if (type == null) return;
    final descriptor = cabinByType(type);
    final result = await Navigator.of(context).push<CabinAssistResult>(
      MaterialPageRoute(
        builder: (_) => TrainingCabinIntroPage(
          descriptor: descriptor,
          concept: widget.plan.concept,
          goal: widget.plan.goal.isEmpty ? current.text : widget.plan.goal,
          domain: widget.plan.domain,
          returnToActionChain: true,
          linkedPlanId: widget.plan.planId,
          linkedStepId: current.id,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _assistResults[current.id] = result;
      final old = _noteCtrl.text.trim();
      _noteCtrl.text = old.isEmpty ? result.recommendedPhrase : '$old\n${result.recommendedPhrase}';
      _records[_currentIndex] = ActionStepExecution(
        stepId: _currentRecord.stepId,
        stepOrder: _currentRecord.stepOrder,
        stepText: _currentRecord.stepText,
        completed: _currentRecord.completed,
        encounteredFriction: _currentRecord.encounteredFriction,
        frictionType: _currentRecord.frictionType,
        fallbackAction: _currentRecord.fallbackAction,
        userNote: '已预演：${descriptor.title} · ${result.recommendedAction}',
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已从${descriptor.title}带回建议，可继续执行这一步。')));
  }

  Future<void> _finishExecution() async {
    final completed = _records.where((e) => e.completed).length;
    final frictions = _records.where((e) => e.encounteredFriction).length;
    final status = completed == _records.length ? 'completed' : (completed == 0 ? 'interrupted' : 'partial');
    final execution = ActionExecution(
      executionId: _executionId,
      planId: widget.plan.planId,
      concept: widget.plan.concept,
      status: status,
      totalSteps: _records.length,
      completedSteps: completed,
      frictionCount: frictions,
      feedback: {
        'completed_steps': completed,
        'remaining_steps': _records.length - completed,
        'friction_count': frictions,
        'next_suggestion': _records.firstWhere((e) => !e.completed, orElse: () => _records.last).stepText,
        'cabin_assists': _assistResults.map((k, v) => MapEntry(k, {'tone': v.recommendedTone, 'action': v.recommendedAction, 'phrase': v.recommendedPhrase})),
      },
      createdAt: _startedAt,
      updatedAt: DateTime.now(),
    );
    await _dao.saveExecution(execution: execution, stepRecords: _records);
    final reward = await _worldDao.applyActionExecutionReward(
      concept: widget.plan.concept,
      domain: widget.plan.domain,
      totalSteps: _records.length,
      completedSteps: completed,
      frictionCount: frictions,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActionFeedbackPage(plan: widget.plan, execution: execution, records: _records, worldReward: reward),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final current = _currentRecord;
    final completedCount = _records.where((e) => e.completed).length;
    final stepMeta = _currentPlanStep;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.plan.title} · 执行'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('正常路径：先把当前这一步做出来', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('已完成 $completedCount / ${_records.length} 步', style: const TextStyle(color: Color(0xFF4B5563))),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _records.isEmpty ? 0 : completedCount / _records.length, minHeight: 10, borderRadius: BorderRadius.circular(999)),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('当前步骤 ${current.stepOrder + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                if (stepMeta.importance != 'normal') _metaBadge(stepMeta.importance == 'critical' ? '关键步骤' : '重要步骤'),
              ]),
              const SizedBox(height: 8),
              Text(current.stepText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.35)),
              const SizedBox(height: 8),
              Text('为什么做这一步：${_reasonForStep(current.stepText)}', style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
              if (stepMeta.shouldSuggestCabin) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('关键节点强化', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('这一步属于高价值动作。你可以直接执行，也可以先进入训练舱预演，再带着建议回到行动链继续。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      FilledButton.icon(onPressed: _openCabinAssist, icon: const Icon(Icons.fitness_center_outlined), label: const Text('进入训练舱预演')),
                      if (_currentAssist != null) _metaBadge('已完成预演'),
                    ]),
                    if (_currentAssist != null) ...[
                      const SizedBox(height: 8),
                      Text('带回建议：${_currentAssist!.recommendedPhrase}', style: const TextStyle(color: Color(0xFF374151), height: 1.4)),
                    ]
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              if (current.encounteredFriction)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(14)),
                  child: Text('当前这一步已经进入异常处理：${current.frictionType ?? '未分类'}\n替代动作：${current.fallbackAction ?? current.stepText}', style: const TextStyle(color: Color(0xFF9A3412), height: 1.45)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '可选：写下你准备怎么做，或记录这一步的现实表述',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(onPressed: _completeStep, icon: const Icon(Icons.check), label: const Text('完成这一步')),
              OutlinedButton.icon(onPressed: _openFrictionSheet, icon: const Icon(Icons.warning_amber_outlined), label: const Text('我卡住了')),
              OutlinedButton.icon(onPressed: _shrinkStep, icon: const Icon(Icons.compress), label: const Text('缩小一步')),
              OutlinedButton.icon(onPressed: _skipToNext, icon: const Icon(Icons.skip_next), label: const Text('暂时跳过')),
              OutlinedButton.icon(onPressed: () => _openCognitiveConsistency(), icon: const Icon(Icons.sync_alt_outlined), label: const Text('一致行动')),
              OutlinedButton.icon(onPressed: () => _openCognitiveConsistency(initialTabIndex: 5), icon: const Icon(Icons.card_giftcard_outlined), label: const Text('奖励降噪')),
              OutlinedButton.icon(onPressed: () => _openCognitiveConsistency(initialTabIndex: 6), icon: const Icon(Icons.fact_check_outlined), label: const Text('诚实校验')),
            ],
          ),
          const SizedBox(height: 12),
          CcSourceEvidenceStatusCard(
            sourceType: 'concept_action_step',
            sourceId: '${widget.plan.planId}:${_currentPlanStep.id}',
            initialGoal: widget.plan.goal.trim().isEmpty ? widget.plan.concept : widget.plan.goal,
            initialContext: '概念行动引擎步骤：${_currentPlanStep.text}\n行动链：${widget.plan.title}\n概念：${widget.plan.concept}',
            initialValues: _currentPlanStep.tags.join('；'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('接下来', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (_currentIndex + 1 < _records.length)
                Text(_records[_currentIndex + 1].stepText, style: const TextStyle(color: Color(0xFF4B5563)))
              else
                const Text('完成当前这一步后，就可以进入反馈页。', style: TextStyle(color: Color(0xFF4B5563))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _metaBadge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF3730A3))),
      );

  String _reasonForStep(String text) {
    if (text.contains('影响') || text.contains('后果')) return '先看清影响，能避免后面继续扩大。';
    if (text.contains('更新时间') || text.contains('时间')) return '给出时间点能让行动重新变得可追踪。';
    if (text.contains('边界') || text.contains('不能')) return '明确边界能减少反复拉扯。';
    if (text.contains('开始') || text.contains('第一步') || text.contains('3 分钟')) return '先做出来，比一直准备更有用。';
    return '把抽象想法变成一个现实动作，才能真正推进。';
  }
}
