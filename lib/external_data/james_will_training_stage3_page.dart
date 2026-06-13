import 'package:flutter/material.dart';

import 'james_will_training_ai_service.dart';
import 'james_will_training_dao.dart';
import 'james_will_training_models.dart';
import 'james_will_training_stage3_ai_service.dart';
import 'james_will_training_stage3_dao.dart';
import 'james_will_training_stage3_models.dart';
import 'todo_goal_dao.dart';
import 'todo_goal_models.dart';

const _stage3Purple = Color(0xFF4C3B7A);
const _stage3Bg = Color(0xFFF6F3FF);
const _stage3Ink = Color(0xFF26233A);

class JamesWillStage3CenterPage extends StatefulWidget {
  const JamesWillStage3CenterPage({super.key});

  @override
  State<JamesWillStage3CenterPage> createState() => _JamesWillStage3CenterPageState();
}

class _JamesWillStage3CenterPageState extends State<JamesWillStage3CenterPage> {
  final _baseDao = JamesWillTrainingDao();
  final _todoGoalDao = TodoGoalDao();
  final _actionAi = JamesWillTrainingAiService();
  final _stage3Dao = JamesWillTrainingStage3Dao();
  final _stage3Ai = JamesWillTrainingStage3AiService();

  List<JamesWillActionIdea> _ideas = const <JamesWillActionIdea>[];
  List<JamesWillLog> _logs = const <JamesWillLog>[];
  List<JamesWillSevenDayExperiment> _experiments = const <JamesWillSevenDayExperiment>[];
  List<JamesWillCooldownPlan> _cooldowns = const <JamesWillCooldownPlan>[];
  JamesWillValueMapSnapshot? _valueMap;
  Map<String, int> _stage3Stats = const <String, int>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _baseDao.ensureTables();
    await _stage3Dao.ensureTables();
    final ideas = await _baseDao.listActionIdeas(limit: 100);
    final logs = await _baseDao.listLogs(limit: 400);
    final experiments = await _stage3Dao.listExperiments(limit: 100);
    final cooldowns = await _stage3Dao.listCooldowns(limit: 100);
    final valueMap = await _stage3Dao.latestValueMap();
    final stats = await _stage3Dao.stage3Stats();
    if (!mounted) return;
    setState(() {
      _ideas = ideas;
      _logs = logs;
      _experiments = experiments;
      _cooldowns = cooldowns;
      _valueMap = valueMap ?? JamesWillValueMapSnapshot.fromIdeas(ideas, logs);
      _stage3Stats = stats;
    });
  }

  void _show(String message, {bool error = false}) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  Future<void> _generateValueMap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final snapshot = await _stage3Ai.generateValueMap(ideas: _ideas, logs: _logs);
      await _stage3Dao.saveValueMap(snapshot);
      await _load();
      _show('已生成长期价值地图。');
    } catch (e) {
      _show('生成长期价值地图失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<JamesWillActionIdea?> _pickIdea() async {
    if (_ideas.isEmpty) {
      _show('请先生成至少一张行动观念卡。', error: true);
      return null;
    }
    return showDialog<JamesWillActionIdea>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择一个目标生成7天实验'),
        children: _ideas
            .take(20)
            .map(
              (idea) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, idea),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(idea.originalGoal, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(idea.firstBodyAction, style: const TextStyle(color: Color(0xFF6B7280))),
                ]),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _createExperimentFromPickedIdea() async {
    final idea = await _pickIdea();
    if (idea == null || _busy) return;
    setState(() => _busy = true);
    try {
      final ideaLogs = _logs.where((e) => e.ideaId == idea.id).toList(growable: false);
      final experiment = await _stage3Ai.generateSevenDayExperiment(idea: idea, logs: ideaLogs);
      await _stage3Dao.saveExperiment(experiment);
      await _load();
      _show('已生成7天行动实验。');
    } catch (e) {
      _show('生成7天实验失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importTodoGoalAsActionIdea() async {
    if (_busy) return;
    await _todoGoalDao.ensureTables();
    final goals = await _todoGoalDao.listGoals(limit: 50);
    if (!mounted) return;
    if (goals.isEmpty) {
      _show('目标价值系统里还没有可导入目标。', error: true);
      return;
    }
    final picked = await showDialog<TodoGoalProfile>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('从Todo目标价值系统导入'),
        children: goals
            .take(30)
            .map(
              (goal) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, goal),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(goal.goalTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(goal.coreValues.isEmpty ? goal.processValue : goal.coreValues, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280))),
                ]),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final note = [
        '来源：Todo目标价值系统',
        if (picked.deepMeaning.isNotEmpty) '深层意义：${picked.deepMeaning}',
        if (picked.coreValues.isNotEmpty) '核心价值：${picked.coreValues}',
        if (picked.processValue.isNotEmpty) '过程价值：${picked.processValue}',
        if (picked.obstacleSummary.isNotEmpty) '阻碍摘要：${picked.obstacleSummary}',
        if (picked.processGoal.isNotEmpty) '过程目标：${picked.processGoal}',
      ].join('\n');
      final idea = await _actionAi.generateActionIdea(goal: picked.goalTitle, note: note);
      await _baseDao.upsertActionIdea(idea);
      await _load();
      _show('已从Todo目标价值系统导入并生成行动观念卡。');
    } catch (e) {
      _show('导入目标失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trends = JamesWillDailyTrend.fromLogs(_logs, days: 14);
    return Scaffold(
      backgroundColor: _stage3Bg,
      appBar: AppBar(
        title: const Text('足下意志 · 第三阶段深化'),
        actions: [IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _Stage3Hero(stats: _stage3Stats, ideas: _ideas.length, logs: _logs.length),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(onPressed: _busy ? null : _generateValueMap, icon: const Icon(Icons.account_tree_outlined), label: const Text('生成价值地图')),
                OutlinedButton.icon(onPressed: _busy ? null : _createExperimentFromPickedIdea, icon: const Icon(Icons.calendar_month_outlined), label: const Text('创建7天实验')),
                OutlinedButton.icon(onPressed: _busy ? null : _importTodoGoalAsActionIdea, icon: const Icon(Icons.input_outlined), label: const Text('导入Todo目标')),
              ]),
              const SizedBox(height: 16),
              const _Stage3SectionTitle('长期价值地图'),
              const SizedBox(height: 10),
              _ValueMapCard(snapshot: _valueMap ?? JamesWillValueMapSnapshot.fromIdeas(_ideas, _logs)),
              const SizedBox(height: 16),
              const _Stage3SectionTitle('观念趋势与努力曲线'),
              const SizedBox(height: 10),
              _TrendCard(trends: trends),
              const SizedBox(height: 16),
              const _Stage3SectionTitle('7天行动实验'),
              const SizedBox(height: 10),
              if (_experiments.isEmpty)
                const _Stage3Info(lines: ['还没有7天实验。选择一张行动观念卡后，AI会把它转成固定触发条件、地点、第一身体动作、每日计划和失败恢复方案。'])
              else
                ..._experiments.map((experiment) => _ExperimentCard(experiment: experiment, compact: false)),
              const SizedBox(height: 16),
              const _Stage3SectionTitle('冲动决定冷却池'),
              const SizedBox(height: 10),
              if (_cooldowns.isEmpty)
                const _Stage3Info(lines: ['还没有冷却计划。进入行动观念卡，在“第三阶段深化模块”中创建冷却计划，把冲动决定先放进24小时检查。'])
              else
                ..._cooldowns.map((plan) => _CooldownCard(plan: plan, compact: false)),
              const SizedBox(height: 16),
              const _Stage3SectionTitle('第三阶段覆盖清单'),
              const SizedBox(height: 10),
              const _Stage3Checklist(),
            ],
          ),
          if (_busy) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.05), child: const Center(child: CircularProgressIndicator()))),
        ],
      ),
    );
  }
}

class JamesWillStage3IdeaSections extends StatefulWidget {
  const JamesWillStage3IdeaSections({super.key, required this.idea, required this.logs, required this.onChanged});
  final JamesWillActionIdea idea;
  final List<JamesWillLog> logs;
  final Future<void> Function() onChanged;

  @override
  State<JamesWillStage3IdeaSections> createState() => _JamesWillStage3IdeaSectionsState();
}

class _JamesWillStage3IdeaSectionsState extends State<JamesWillStage3IdeaSections> {
  final _baseDao = JamesWillTrainingDao();
  final _reviewAi = JamesWillTrainingAiService();
  final _dao = JamesWillTrainingStage3Dao();
  final _ai = JamesWillTrainingStage3AiService();
  JamesWillSevenDayExperiment? _experiment;
  List<JamesWillCooldownPlan> _cooldowns = const <JamesWillCooldownPlan>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant JamesWillStage3IdeaSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idea.id != widget.idea.id) _load();
  }

  Future<void> _load() async {
    await _dao.ensureTables();
    final experiment = await _dao.activeExperimentForIdea(widget.idea.id);
    final cooldowns = await _dao.listCooldowns(ideaId: widget.idea.id, limit: 5);
    if (!mounted) return;
    setState(() {
      _experiment = experiment;
      _cooldowns = cooldowns;
    });
  }

  void _show(String message, {bool error = false}) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  Future<void> _createExperiment() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final experiment = await _ai.generateSevenDayExperiment(idea: widget.idea, logs: widget.logs);
      await _dao.saveExperiment(experiment);
      await _load();
      await widget.onChanged();
      _show('已创建7天行动实验。');
    } catch (e) {
      _show('创建7天实验失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markExperimentDayDone() async {
    final experiment = _experiment;
    if (experiment == null || _busy) return;
    setState(() => _busy = true);
    try {
      final day = experiment.currentDay;
      final plan = experiment.dailyPlan.length >= day ? experiment.dailyPlan[day - 1] : experiment.minimumVersion;
      var log = JamesWillLog.create(
        ideaId: widget.idea.id,
        completed: true,
        beforeObstacle: widget.idea.obstacleIdeas.isEmpty ? '实验启动阻力' : widget.idea.obstacleIdeas.first,
        dominantActionIdea: plan,
        attentionRecoveryCount: 1,
        startDelayMinutes: 0,
        effortAttentionScore: 80,
        reflection: '完成7天实验第$day天：$plan',
      );
      final summary = await _reviewAi.summarizeReview(idea: widget.idea, log: log);
      log = JamesWillLog.create(
        ideaId: widget.idea.id,
        completed: true,
        beforeObstacle: widget.idea.obstacleIdeas.isEmpty ? '实验启动阻力' : widget.idea.obstacleIdeas.first,
        dominantActionIdea: plan,
        attentionRecoveryCount: 1,
        startDelayMinutes: 0,
        effortAttentionScore: 80,
        reflection: '完成7天实验第$day天：$plan',
        aiSummary: summary,
      );
      await _baseDao.saveLog(log);
      final nextDay = day >= 7 ? 7 : day + 1;
      final status = day >= 7 ? 'completed' : 'active';
      await _dao.saveExperiment(experiment.copyWith(currentDay: nextDay, status: status));
      await _load();
      await widget.onChanged();
      _show(day >= 7 ? '7天实验已完成，建议进入复盘日重新评估。' : '已记录第$day天实验完成。');
    } catch (e) {
      _show('记录实验失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createCooldown() async {
    if (_busy) return;
    final ctrl = TextEditingController(text: '我想立刻改变/放弃/推翻当前决定');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('创建冲动决定冷却计划'),
          content: TextField(
            controller: ctrl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: '现在想立刻做出的决定', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('进入冷却')),
          ],
        ),
      );
      if (ok != true) return;
      setState(() => _busy = true);
      final plan = await _ai.generateCooldownPlan(idea: widget.idea, decisionText: ctrl.text.trim());
      await _dao.saveCooldown(plan);
      await _load();
      await widget.onChanged();
      _show('已创建冲动决定冷却计划。');
    } catch (e) {
      _show('创建冷却计划失败：$e', error: true);
    } finally {
      ctrl.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trends = JamesWillDailyTrend.fromLogs(widget.logs, ideaId: widget.idea.id, days: 7);
    final valueMap = JamesWillValueMapSnapshot.fromIdeas(<JamesWillActionIdea>[widget.idea], widget.logs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Stage3SectionTitle('第三阶段：深化落地模块'),
        const SizedBox(height: 10),
        _ValueMapCard(snapshot: valueMap, compact: true),
        const SizedBox(height: 10),
        _TrendCard(trends: trends, compact: true),
        const SizedBox(height: 10),
        _ExperimentActionCard(
          experiment: _experiment,
          busy: _busy,
          onCreate: _createExperiment,
          onMarkDayDone: _markExperimentDayDone,
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('冲动决定冷却机制', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _stage3Ink)),
              const SizedBox(height: 8),
              const Text('当你突然想推翻决定、放弃目标或做重大改变时，先放入冷却池。执行期内不重新审判目标，只记录问题，冷却后再判断。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _busy ? null : _createCooldown, icon: const Icon(Icons.pause_circle_outline), label: const Text('创建24小时冷却计划')),
              if (_cooldowns.isNotEmpty) ...[
                const SizedBox(height: 10),
                ..._cooldowns.take(2).map((plan) => _CooldownCard(plan: plan, compact: true)),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _Stage3Hero extends StatelessWidget {
  const _Stage3Hero({required this.stats, required this.ideas, required this.logs});
  final Map<String, int> stats;
  final int ideas;
  final int logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_stage3Purple, Color(0xFF8E73D7)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('第三阶段：从功能完整到闭环完整', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('补齐长期价值地图、观念趋势、7天行动实验、冲动决定冷却和执行期闭环，让“行动观念训练”真正从一次启动进入持续成长。', style: TextStyle(color: Colors.white, height: 1.5)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _HeroPill(label: '行动观念', value: '$ideas'),
          _HeroPill(label: '日志', value: '$logs'),
          _HeroPill(label: '7天实验', value: '${stats['experiments'] ?? 0}'),
          _HeroPill(label: '冷却计划', value: '${stats['cooldowns'] ?? 0}'),
          _HeroPill(label: '价值地图', value: '${stats['valueMaps'] ?? 0}'),
          _HeroPill(label: '冷却中', value: '${stats['activeCooldowns'] ?? 0}'),
        ]),
      ]),
    );
  }
}

class _ExperimentActionCard extends StatelessWidget {
  const _ExperimentActionCard({required this.experiment, required this.busy, required this.onCreate, required this.onMarkDayDone});
  final JamesWillSevenDayExperiment? experiment;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onMarkDayDone;

  @override
  Widget build(BuildContext context) {
    final e = experiment;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('7天行动实验', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _stage3Ink)),
          const SizedBox(height: 8),
          if (e == null) ...[
            const Text('把当前行动观念封存为7天实验：执行期内不反复问“要不要做”，只记录反馈并优化动作。', style: TextStyle(color: Color(0xFF6B7280), height: 1.45)),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: busy ? null : onCreate, icon: const Icon(Icons.calendar_month_outlined), label: const Text('生成7天实验')),
          ] else ...[
            _ExperimentCard(experiment: e, compact: true),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: busy || e.status == 'completed' ? null : onMarkDayDone, icon: const Icon(Icons.check_circle_outline), label: Text(e.status == 'completed' ? '实验已完成' : '记录第${e.currentDay}天完成')),
          ],
        ]),
      ),
    );
  }
}

class _ValueMapCard extends StatelessWidget {
  const _ValueMapCard({required this.snapshot, this.compact = false});
  final JamesWillValueMapSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(compact ? '当前目标价值链' : '长期价值地图', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _stage3Ink)),
          const SizedBox(height: 8),
          Text(snapshot.summary, style: const TextStyle(height: 1.5, color: Color(0xFF374151))),
          const SizedBox(height: 10),
          if (snapshot.valueNodes.isNotEmpty) ...[
            const Text('核心价值', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: snapshot.valueNodes.take(compact ? 3 : 10).map((e) => _TinyChip(text: e)).toList()),
          ],
          if (!compact && snapshot.links.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('价值 → 动作连接', style: TextStyle(fontWeight: FontWeight.w900)),
            ...snapshot.links.take(8).map((e) => _Bullet(e)),
          ],
        ]),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trends, this.compact = false});
  final List<JamesWillDailyTrend> trends;
  final bool compact;

  String _dayLabel(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final visible = compact ? trends.take(7).toList(growable: false) : trends;
    final total = visible.fold<int>(0, (sum, e) => sum + e.total);
    final completed = visible.fold<int>(0, (sum, e) => sum + e.completed);
    final recoveries = visible.fold<int>(0, (sum, e) => sum + e.recoveries);
    final avgEffort = total == 0 ? 0 : (visible.fold<int>(0, (sum, e) => sum + e.averageEffort * e.total) / total).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(compact ? '7日观念趋势' : '14日观念趋势', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _stage3Ink)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _MetricPill(label: '记录', value: '$total'),
            _MetricPill(label: '完成', value: '$completed'),
            _MetricPill(label: '平均努力', value: '$avgEffort'),
            _MetricPill(label: '拉回', value: '$recoveries'),
          ]),
          const SizedBox(height: 12),
          ...visible.map((trend) {
            final value = trend.total == 0 ? 0.0 : (trend.averageEffort / 100).clamp(0.0, 1.0).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 44, child: Text(_dayLabel(trend.dayStartMs), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                Expanded(child: LinearProgressIndicator(value: value, minHeight: 8, borderRadius: BorderRadius.circular(999))),
                const SizedBox(width: 8),
                SizedBox(width: 82, child: Text('努${trend.averageEffort} 完${trend.completed}', style: const TextStyle(fontSize: 12))),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

class _ExperimentCard extends StatelessWidget {
  const _ExperimentCard({required this.experiment, this.compact = false});
  final JamesWillSevenDayExperiment experiment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final day = experiment.currentDay.clamp(1, 7).toInt();
    final currentPlan = experiment.dailyPlan.length >= day ? experiment.dailyPlan[day - 1] : experiment.minimumVersion;
    return Card(
      margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(experiment.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _stage3Ink))),
            _TinyChip(text: experiment.status == 'completed' ? '已完成' : '第$day天'),
          ]),
          const SizedBox(height: 8),
          Text(experiment.aiSummary, style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
          const SizedBox(height: 10),
          _KV(label: '触发条件', value: experiment.triggerText),
          _KV(label: '第一动作', value: experiment.firstBodyAction),
          _KV(label: '今日计划', value: currentPlan),
          if (!compact) ...[
            const SizedBox(height: 8),
            const Text('7天路径', style: TextStyle(fontWeight: FontWeight.w900)),
            ...experiment.dailyPlan.take(7).map((e) => _Bullet(e)),
          ],
          const SizedBox(height: 8),
          _KV(label: '失败恢复', value: experiment.recoveryPlan),
        ]),
      ),
    );
  }
}

class _CooldownCard extends StatelessWidget {
  const _CooldownCard({required this.plan, this.compact = false});
  final JamesWillCooldownPlan plan;
  final bool compact;

  String _timeLeft(int ms) {
    final diff = ms - DateTime.now().millisecondsSinceEpoch;
    if (diff <= 0) return '可复盘';
    final d = Duration(milliseconds: diff);
    if (d.inHours >= 1) return '剩余 ${d.inHours} 小时';
    return '剩余 ${d.inMinutes.clamp(1, 59)} 分钟';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: compact ? const EdgeInsets.only(bottom: 8) : const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('冲动决定冷却', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _stage3Ink))),
            _TinyChip(text: _timeLeft(plan.coolUntilMs)),
          ]),
          const SizedBox(height: 8),
          _KV(label: '触发观念', value: plan.triggerText),
          _KV(label: '暂缓决定', value: plan.decisionText),
          _KV(label: '风险判断', value: plan.riskLevel),
          _KV(label: '冷却理由', value: plan.reason),
          _KV(label: '冷却期动作', value: plan.fallbackAction),
          if (!compact) ...[
            const SizedBox(height: 8),
            const Text('冷却后检查', style: TextStyle(fontWeight: FontWeight.w900)),
            ...plan.checkQuestions.map((e) => _Bullet(e)),
          ],
        ]),
      ),
    );
  }
}

class _Stage3Checklist extends StatelessWidget {
  const _Stage3Checklist();

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      '长期价值地图：把目标、核心价值、行动观念、第一身体动作连接起来，避免价值停留在口号。',
      '观念趋势：按天呈现努力性注意、完成、分心拉回，观察行动观念是否越来越稳定。',
      '7天行动实验：把决定封存为可撤回实验，执行期内只优化行动，不反复审判选择。',
      '冲动冷却：对内在自动爆发型决定设置24小时检查，降低情绪性重大选择风险。',
      '闭环落地：目标输入、Todo目标导入、行动观念、观念竞争、决定、启动、复盘、习惯、实验、价值地图全部串联。',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline, color: _stage3Purple), const SizedBox(width: 8), Expanded(child: Text(e, style: const TextStyle(height: 1.45)))]))).toList()),
      ),
    );
  }
}

class _Stage3SectionTitle extends StatelessWidget {
  const _Stage3SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _stage3Ink));
}

class _Stage3Info extends StatelessWidget {
  const _Stage3Info({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines.map((e) => _Bullet(e)).toList()),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 78, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: _stage3Ink))),
        Expanded(child: Text(value.trim().isEmpty ? '—' : value, style: const TextStyle(height: 1.45))),
      ]),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('• ', style: TextStyle(fontWeight: FontWeight.w900)),
        Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
      ]),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFEDE7FF), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: _stage3Purple, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: const Color(0xFFF0ECFF), borderRadius: BorderRadius.circular(999)),
      child: Text('$label：$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _stage3Purple)),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
      child: Text('$label：$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}
