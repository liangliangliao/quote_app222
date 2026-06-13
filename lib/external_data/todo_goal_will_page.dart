import 'dart:async';

import 'package:flutter/material.dart';

import 'james_will_training_complete_dao.dart';
import 'james_will_training_complete_models.dart';
import 'james_will_training_models.dart';
import 'james_will_training_page.dart';
import 'todo_goal_dao.dart';
import 'todo_goal_models.dart';
import 'todo_goal_will_bridge.dart';
import 'todo_goal_will_state.dart';

/// Todo remains the goal/action source of truth. This page is the practice
/// surface where the user calibrates competing ideas, holds attention and
/// turns the selected idea into the first bodily movement.
class TodoGoalWillCenterPage extends StatefulWidget {
  const TodoGoalWillCenterPage({super.key, required this.goal, this.step});

  final TodoGoalProfile goal;
  final TodoGoalActionStep? step;

  @override
  State<TodoGoalWillCenterPage> createState() => _TodoGoalWillCenterPageState();
}

class _TodoGoalWillCenterPageState extends State<TodoGoalWillCenterPage> {
  final _bridge = TodoGoalWillBridge();
  final _goalDao = TodoGoalDao();
  final _completeDao = JamesWillTrainingCompleteDao();
  JamesWillActionIdea? _idea;
  TodoGoalWillState? _state;
  JamesWillHabit? _habit;
  List<JamesWillLog> _logs = const <JamesWillLog>[];
  Timer? _attentionTimer;
  int _attentionRemaining = 0;
  bool _holdingAttention = false;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _attentionTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final idea = await _bridge.synchronize(goal: widget.goal, step: widget.step);
      final state = await _bridge.loadState(idea);
      final logs = await _bridge.logsFor(goalId: widget.goal.goalId, stepId: widget.step?.stepId);
      final habit = await _completeDao.activeHabitForIdea(idea.id);
      if (!mounted) return;
      setState(() {
        _idea = idea;
        _state = state;
        _logs = logs;
        _habit = habit;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _saveState(TodoGoalWillState next) async {
    setState(() => _state = next);
    await _bridge.saveState(next);
  }

  Future<void> _calibrateCompetition() async {
    final idea = _idea;
    final current = _state;
    if (idea == null || current == null) return;
    var obstacle = current.selectedObstacle.isEmpty && idea.obstacleIdeas.isNotEmpty ? idea.obstacleIdeas.first : current.selectedObstacle;
    var actionStrength = current.actionStrength.toDouble();
    var obstacleStrength = current.obstacleStrength.toDouble();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('校准当前观念竞争', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('强度不是 AI 对你的判决。请按此刻真实体验校准；犹豫只是观念在竞争。', style: TextStyle(color: Color(0xFF66706C), height: 1.45)),
              const SizedBox(height: 16),
              const Text('此刻最强的阻碍观念', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: idea.obstacleIdeas.map((item) => ChoiceChip(label: Text(item), selected: obstacle == item, onSelected: (_) => setLocal(() => obstacle = item))).toList(),
              ),
              const SizedBox(height: 16),
              _strengthSlider('行动观念', actionStrength, const Color(0xFF2D7A67), (value) => setLocal(() => actionStrength = value)),
              _strengthSlider('阻碍观念', obstacleStrength, const Color(0xFFC15B4A), (value) => setLocal(() => obstacleStrength = value)),
              const SizedBox(height: 8),
              Text(
                actionStrength > obstacleStrength
                    ? '行动观念已暂时取得优势。现在最适合立刻进入身体动作。'
                    : '阻碍仍占优势。无需消灭它，只需缩小行动并把注意力带回 30 秒。',
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheetContext, true), child: const Text('保存真实强度'))),
            ]),
          ),
        ),
      ),
    );
    if (saved == true) {
      await _saveState(current.copyWith(selectedObstacle: obstacle, actionStrength: actionStrength.round(), obstacleStrength: obstacleStrength.round()));
    }
  }

  Widget _strengthSlider(String label, double value, Color color, ValueChanged<double> onChanged) => Column(
        children: [
          Row(children: [Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900))), Text('${value.round()}')]),
          Slider(value: value, min: 0, max: 100, divisions: 20, activeColor: color, onChanged: onChanged),
        ],
      );

  Future<void> _calibrateActionImage() async {
    final current = _state;
    if (current == null) return;
    var experience = current.actionExperience;
    var capability = current.bodyCapability;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('动作表象与身体边界'),
          content: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('意志不能凭空调用完全没有表象的动作。先确认你是否做过，以及身体执行机制当前是否允许。', style: TextStyle(height: 1.45)),
              const SizedBox(height: 14),
              const Text('我对这个动作的经验', style: TextStyle(fontWeight: FontWeight.w800)),
              RadioListTile<String>(value: 'known', groupValue: experience, title: const Text('我做过，能清楚想象'), onChanged: (value) => setLocal(() => experience = value!)),
              RadioListTile<String>(value: 'similar', groupValue: experience, title: const Text('做过类似动作，需要简短预演'), onChanged: (value) => setLocal(() => experience = value!)),
              RadioListTile<String>(value: 'new', groupValue: experience, title: const Text('完全陌生，需要示范或先学习'), onChanged: (value) => setLocal(() => experience = value!)),
              const Divider(),
              const Text('我的身体当前', style: TextStyle(fontWeight: FontWeight.w800)),
              RadioListTile<String>(value: 'ready', groupValue: capability, title: const Text('可以执行第一动作'), onChanged: (value) => setLocal(() => capability = value!)),
              RadioListTile<String>(value: 'adapt', groupValue: capability, title: const Text('需要更小动作或辅助方式'), onChanged: (value) => setLocal(() => capability = value!)),
              RadioListTile<String>(value: 'blocked', groupValue: capability, title: const Text('身体条件暂不允许执行'), onChanged: (value) => setLocal(() => capability = value!)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存校准')),
          ],
        ),
      ),
    );
    if (saved == true) await _saveState(current.copyWith(actionExperience: experience, bodyCapability: capability));
  }

  void _startAttentionHold() {
    final current = _state;
    if (current == null || _holdingAttention) return;
    _attentionTimer?.cancel();
    setState(() {
      _attentionRemaining = current.attentionTargetSeconds;
      _holdingAttention = true;
    });
    _attentionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (_attentionRemaining <= 1) {
        timer.cancel();
        setState(() {
          _attentionRemaining = 0;
          _holdingAttention = false;
        });
        await _saveState(current.copyWith(rehearsalCompleted: true));
      } else {
        setState(() => _attentionRemaining -= 1);
      }
    });
  }

  Future<void> _markFirstAction({required bool completed}) async {
    final current = _state;
    if (current == null) return;
    await _saveState(current.copyWith(firstActionCompleted: completed));
    if (!completed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('阻力仍在并不等于失败。先把动作缩到“看向入口、触碰材料或移动一小步”。')));
    }
  }

  Future<void> _startFiveMinutes() async {
    final idea = _idea;
    final state = _state;
    if (idea == null || state == null) return;
    if (state.bodyExecutionBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('身体执行条件暂不允许。意志并未失败；请先选择辅助方式、康复建议或一个身体可行的替代动作。')));
      return;
    }
    if (state.needsActionDemonstration) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('这个动作还没有清晰表象。请先观看示范、模仿一次或把任务改成“学习第一步怎么做”。')));
      return;
    }
    if (!state.rehearsalCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先完成一次注意力保持：让行动观念稳定留在心中 30 秒。')));
      return;
    }
    final beforeCount = _logs.length;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => JamesWillFiveMinuteStarterPage(idea: idea)));
    await _load();
    if (!mounted || _logs.length <= beforeCount || widget.step == null) return;
    final latest = _logs.first;
    if (latest.completed) await _offerTodoCompletion(latest);
  }

  Future<void> _offerTodoCompletion(JamesWillLog log) async {
    final step = widget.step;
    if (step == null) return;
    final complete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('把实践反馈带回 Todo'),
        content: Text('你完成了五分钟启动，并把注意力拉回 ${log.attentionRecoveryCount} 次。是否已经达到该步骤的最低完成标准？\n\n${step.minimumStandard}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('仅记录训练，继续进行')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('达到最低标准，完成步骤')),
        ],
      ),
    );
    if (complete == true) {
      await _goalDao.completeStep(step.stepId, completed: true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已将真实实践结果回写到 Todo 行动步骤。')));
    }
  }

  Future<void> _createHabit() async {
    final idea = _idea;
    if (idea == null || _busy) return;
    setState(() => _busy = true);
    try {
      final habit = JamesWillHabit.fromIdea(
        idea,
        trigger: widget.step?.startTrigger.trim().isNotEmpty == true ? widget.step!.startTrigger : '固定提醒时间到达时',
        place: widget.step?.actionPlace.trim().isNotEmpty == true ? widget.step!.actionPlace : '行动发生的固定地点',
      );
      await _completeDao.saveHabit(habit);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已把触发条件、地点、第一动作和失败恢复版沉淀为习惯结构。')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFullEngine() async {
    final idea = _idea;
    if (idea == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => JamesWillActionIdeaDetailPage(ideaId: idea.id)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final idea = _idea;
    final state = _state;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(title: const Text('今日意志中心')),
      body: idea == null || state == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text('意志中心加载失败：$_error')))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                children: [
                  _hero(idea, state),
                  const SizedBox(height: 12),
                  _actionImageCard(idea, state),
                  const SizedBox(height: 12),
                  _competitionCard(idea, state),
                  const SizedBox(height: 12),
                  _attentionCard(idea, state),
                  const SizedBox(height: 12),
                  _bodyActionCard(idea, state),
                  const SizedBox(height: 12),
                  _feedbackAndHabitCard(idea),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _openFullEngine, icon: const Icon(Icons.account_tree_outlined), label: const Text('决定分析 · 封存实验 · 深度复盘与成长地图')),
                ],
              ),
            ),
    );
  }

  Widget _hero(JamesWillActionIdea idea, TodoGoalWillState state) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF25342F), borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('现在的战场不是“使劲”，而是注意力主导权', style: TextStyle(color: Color(0xFFD9B56D), fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(idea.actionIdea, style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.35, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text('核心价值：${idea.coreValue}', style: const TextStyle(color: Color(0xFFD8E4DF), height: 1.45)),
          const SizedBox(height: 10),
          _dominanceBadge(state),
        ]),
      );

  Widget _dominanceBadge(TodoGoalWillState state) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: state.actionIdeaDominant ? const Color(0xFFDBF2E8) : const Color(0xFFFFE4DE), borderRadius: BorderRadius.circular(99)),
        child: Text(
          state.actionIdeaDominant ? '行动观念暂时占优 ${state.actionStrength} : ${state.obstacleStrength}' : '阻碍观念暂时占优 ${state.obstacleStrength} : ${state.actionStrength}',
          style: TextStyle(color: state.actionIdeaDominant ? const Color(0xFF16614E) : const Color(0xFF913F32), fontWeight: FontWeight.w900),
        ),
      );

  Widget _actionImageCard(JamesWillActionIdea idea, TodoGoalWillState state) => _section(
        icon: Icons.visibility_outlined,
        title: '1. 先形成可调用的动作表象',
        subtitle: '自愿行动不能凭空调用完全没有经验过的动作。先确认经验，再尊重身体执行边界。',
        children: [
          _line('第一身体动作', idea.firstBodyAction),
          _line('动作经验', switch (state.actionExperience) {'known' => '做过，表象清晰', 'new' => '完全陌生，需要示范或学习', _ => '做过类似动作，需要预演'}),
          _line('身体执行', switch (state.bodyCapability) {'adapt' => '需要更小动作或辅助', 'blocked' => '当前身体条件不允许', _ => '当前可以执行'}),
          OutlinedButton.icon(onPressed: _calibrateActionImage, icon: const Icon(Icons.tune), label: const Text('校准动作经验与身体条件')),
        ],
      );

  Widget _competitionCard(JamesWillActionIdea idea, TodoGoalWillState state) => _section(
        icon: Icons.swap_vert_circle_outlined,
        title: '2. 看见观念竞争，不批评自己',
        subtitle: '强度由你校准。目标不是消灭相反观念，而是让更高价值的行动观念取得足够优势。',
        children: [
          _meter('行动观念', idea.actionIdea, state.actionStrength, const Color(0xFF2D7A67)),
          _meter('当前阻碍', state.selectedObstacle.isEmpty ? '尚未选择' : state.selectedObstacle, state.obstacleStrength, const Color(0xFFC15B4A)),
          OutlinedButton.icon(onPressed: _calibrateCompetition, icon: const Icon(Icons.psychology_alt_outlined), label: const Text('按此刻真实体验校准')),
        ],
      );

  Widget _attentionCard(JamesWillActionIdea idea, TodoGoalWillState state) => _section(
        icon: Icons.center_focus_strong,
        title: '3. 努力性注意：把困难但正确的观念留下来',
        subtitle: '不要求情绪、恐惧或懒惰先消失。只在它们仍存在时，把行动观念保持到足以进入动作。',
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF0F5F2), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text(idea.attentionAnchor, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.4)),
              const SizedBox(height: 10),
              Text(_holdingAttention ? '$_attentionRemaining 秒' : (state.rehearsalCompleted ? '已完成一次注意力保持' : '${state.attentionTargetSeconds} 秒'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: <int>[30, 60, 300]
                .map((seconds) => ChoiceChip(
                      label: Text(seconds == 300 ? '5 分钟' : '$seconds 秒'),
                      selected: state.attentionTargetSeconds == seconds,
                      onSelected: _holdingAttention ? null : (_) => _saveState(state.copyWith(attentionTargetSeconds: seconds, rehearsalCompleted: false)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: _holdingAttention ? null : _startAttentionHold, icon: const Icon(Icons.timer_outlined), label: Text(state.rehearsalCompleted ? '再保持一次' : '开始注意力保持')),
        ],
      );

  Widget _bodyActionCard(JamesWillActionIdea idea, TodoGoalWillState state) => _section(
        icon: Icons.directions_walk_outlined,
        title: '4. 让观念终止于第一身体动作',
        subtitle: state.bodyExecutionBlocked ? '身体机制暂不能执行，不等于意志失败。请转向辅助、康复或可行替代动作。' : '动作不从“有心情”开始，而从一个可观察的身体变化开始。',
        children: [
          _line('现在唯一动作', idea.firstBodyAction),
          _line('最低版本', idea.minimumAction),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: state.bodyExecutionBlocked ? null : () => _markFirstAction(completed: false), child: const Text('我还在抗拒'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: state.bodyExecutionBlocked ? null : () => _markFirstAction(completed: true), child: Text(state.firstActionCompleted ? '第一动作已完成' : '我已执行第一动作'))),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _startFiveMinutes, icon: const Icon(Icons.play_arrow_rounded), label: const Text('进入 5 分钟真实行动'))),
        ],
      );

  Widget _feedbackAndHabitCard(JamesWillActionIdea idea) {
    final completed = _logs.where((log) => log.completed).length;
    final recoveries = _logs.fold<int>(0, (sum, log) => sum + log.attentionRecoveryCount);
    return _section(
      icon: Icons.autorenew_outlined,
      title: '5. 反馈沉淀为习惯，而不是永远硬撑',
      subtitle: '最高级的意志训练，是逐渐减少每次启动所需的痛苦和提醒。',
      children: [
        _line('实践证据', '${_logs.length} 次启动 · $completed 次完成 · $recoveries 次注意力拉回'),
        _line('习惯状态', _habit == null ? (completed >= 3 ? '已有足够证据，建议建立固定触发结构' : '再积累 ${3 - completed} 次完成，即可建立习惯结构') : 'L${_habit!.level} · ${_habit!.trigger} → ${_habit!.place} → ${_habit!.firstBodyAction}'),
        if (_habit == null)
          OutlinedButton.icon(onPressed: completed == 0 || _busy ? null : _createHabit, icon: const Icon(Icons.add_task_outlined), label: const Text('把实践沉淀为习惯结构')),
      ],
    );
  }

  Widget _meter(String label, String content, int strength, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900))), Text('$strength')]),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(height: 1.35)),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: strength / 100, color: color, backgroundColor: color.withOpacity(.12)),
        ]),
      );

  Widget _section({required IconData icon, required String title, required String subtitle, required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7E0D4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: const Color(0xFF38695B)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF66706C), height: 1.45)),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Color(0xFF8B6F47), fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(value.trim().isEmpty ? '待澄清' : value, style: const TextStyle(height: 1.4))]),
      );
}
