import 'package:flutter/material.dart';

import 'todo_failure_growth_engine.dart';
import 'todo_failure_growth_models.dart';
import 'todo_goal_dao.dart';
import 'todo_goal_models.dart';

class TodoFailureGrowthPage extends StatefulWidget {
  const TodoFailureGrowthPage({
    super.key,
    required this.dao,
    required this.goals,
    required this.onDataChanged,
  });

  final TodoGoalDao dao;
  final List<TodoGoalProfile> goals;
  final Future<void> Function() onDataChanged;

  @override
  State<TodoFailureGrowthPage> createState() => _TodoFailureGrowthPageState();
}

class _TodoFailureGrowthPageState extends State<TodoFailureGrowthPage> {
  static const _ink = Color(0xFF27233A);
  final _engine = const TodoFailureGrowthEngine();
  final _eventCtrl = TextEditingController();
  final _emotionCtrl = TextEditingController();
  final _thoughtCtrl = TextEditingController();
  final _fearCtrl = TextEditingController();
  List<TodoFailureGrowthLoop> _loops = const [];
  TodoFailureGrowthMetrics _metrics = const TodoFailureGrowthMetrics(
    attempts: 0,
    reflections: 0,
    feedbackSamples: 0,
    revisions: 0,
    restarts: 0,
    activeExperiments: 0,
  );
  String _goalId = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _goalId = widget.goals.isEmpty ? '' : widget.goals.first.goalId;
    _load();
  }

  @override
  void didUpdateWidget(covariant TodoFailureGrowthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_goalId.isEmpty && widget.goals.isNotEmpty) _goalId = widget.goals.first.goalId;
  }

  @override
  void dispose() {
    _eventCtrl.dispose();
    _emotionCtrl.dispose();
    _thoughtCtrl.dispose();
    _fearCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loops = await widget.dao.listFailureGrowthLoops();
    final metrics = await widget.dao.failureGrowthMetrics();
    if (!mounted) return;
    setState(() {
      _loops = loops;
      _metrics = metrics;
      _loading = false;
    });
  }

  Future<void> _createLoop() async {
    if (_eventCtrl.text.trim().isEmpty || _goalId.isEmpty || _saving) {
      _show(_goalId.isEmpty ? '请先创建或转化一个目标，再把失败转成目标实验。' : '请先写下发生了什么。');
      return;
    }
    final draft = _engine.build(
      event: _eventCtrl.text,
      emotion: _emotionCtrl.text,
      automaticThought: _thoughtCtrl.text,
      fearedOutcome: _fearCtrl.text,
    );
    final confirmed = await _previewDraft(draft);
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      final goal = widget.goals.firstWhere((g) => g.goalId == _goalId);
      final stepId = await widget.dao.createActionStep(
        goalId: goal.goalId,
        sourceTaskId: goal.sourceTaskId,
        title: draft.experimentTitle,
        minimumStandard: draft.minimumStandard,
        simplifiedStandard: '只完成一个 5 分钟版本，并保留反馈证据。',
        recommendedStandard: '在 5–30 分钟内完成一次真实尝试，不以结果好坏作为完成条件。',
        stretchStandard: '状态允许时，再向一个人索取具体反馈；不要求一次成功。',
        difficultyScore: 3,
        zoneType: 'comfort',
        completionQuestion: draft.reflectionQuestion,
        actionType: 'process',
        experienceIntention: draft.valueStatement,
      );
      await widget.dao.saveFailureGrowthLoop(
        goalId: goal.goalId,
        linkedStepId: stepId,
        eventText: _eventCtrl.text,
        emotionText: _emotionCtrl.text,
        automaticThought: _thoughtCtrl.text,
        fearedOutcome: _fearCtrl.text,
        draft: draft,
      );
      _eventCtrl.clear();
      _emotionCtrl.clear();
      _thoughtCtrl.clear();
      _fearCtrl.clear();
      await _load();
      await widget.onDataChanged();
      _show('已生成 70 分行动任务卡，并加入“山路行动”。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _previewDraft(TodoFailureGrowthDraft draft) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${draft.patternLabel} · 成长重构'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PreviewLine(title: '事实 / 解释分离', text: draft.factStatement),
                  _PreviewLine(title: '成长型解释', text: draft.growthReframe),
                  _PreviewLine(title: '失败给出的信息', text: draft.learningSignal),
                  _PreviewLine(title: '最坏结果重估', text: draft.recoveryPlan),
                  _PreviewLine(title: '下一步实验', text: draft.experimentTitle),
                  _PreviewLine(title: '70 分完成标准', text: draft.minimumStandard),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('继续修改')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('生成任务卡')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _review(TodoFailureGrowthLoop loop) async {
    final result = TextEditingController();
    final revision = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('完成反馈复盘'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loop.reflectionQuestion, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(controller: result, maxLines: 3, decoration: const InputDecoration(labelText: '实际发生了什么？我学到了什么？', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: revision, maxLines: 2, decoration: const InputDecoration(labelText: '下一版只改哪一个变量？', border: OutlineInputBorder())),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('稍后')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存成长证据')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || result.text.trim().isEmpty) {
      result.dispose();
      revision.dispose();
      return;
    }
    final resultText = result.text;
    final nextRevision = revision.text;
    result.dispose();
    revision.dispose();
    await widget.dao.completeFailureGrowthLoop(loop: loop, resultText: resultText, nextRevision: nextRevision);
    await _load();
    await widget.onDataChanged();
    _show('已记录一次尝试、反馈、复盘与修正。完成不等于完美。');
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6252B8), Color(0xFF8A6FD6)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('失败成长回路', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('失败不是终点，是下一次行动的入口。先稳定情绪，再把身份判断还原为反馈，最后生成一个 5–30 分钟的现实实验。', style: TextStyle(color: Color(0xFFF2EEFF), height: 1.5)),
            ]),
          ),
          const SizedBox(height: 12),
          _MetricsCard(metrics: _metrics),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('开始一次成长回路', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
                const SizedBox(height: 4),
                const Text('发生了什么 → 感受什么 → 如何解释 → 最坏结果 → 70 分行动', style: TextStyle(color: Color(0xFF6F6A7D))),
                const SizedBox(height: 14),
                if (widget.goals.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: widget.goals.any((g) => g.goalId == _goalId) ? _goalId : widget.goals.first.goalId,
                    decoration: const InputDecoration(labelText: '关联目标 / To Do', border: OutlineInputBorder()),
                    items: widget.goals.map((g) => DropdownMenuItem(value: g.goalId, child: Text(g.goalTitle, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (value) => setState(() => _goalId = value ?? ''),
                  )
                else
                  const Text('暂无目标：请先在“我的山峰”中转化一个 To Do 任务。', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(controller: _eventCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '1. 我发生了什么？', hintText: '例如：汇报讲得很乱，看到对方皱眉', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _emotionCtrl, decoration: const InputDecoration(labelText: '2. 我现在感受到什么？', hintText: '羞耻、焦虑、失望、害怕……', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _thoughtCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '3. 我把它解释成了什么？', hintText: '例如：我就是不行 / 别人会看不起我', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _fearCtrl, maxLines: 2, decoration: const InputDecoration(labelText: '4. 我害怕的最坏结果是什么？', hintText: '写具体事件，不写人格判决', border: OutlineInputBorder())),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _createLoop, icon: const Icon(Icons.loop), label: Text(_saving ? '正在生成…' : '重构并生成 70 分任务卡'))),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Text('我的反馈实验', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 8),
          if (_loops.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('还没有失败成长回路。下一次卡住时，不用先证明自己，先创造一个反馈。'))),
          ..._loops.map((loop) => _LoopCard(loop: loop, onReview: () => _review(loop))),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.metrics});
  final TodoFailureGrowthMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final items = <(String, int, IconData)>[
      ('尝试', metrics.attempts, Icons.rocket_launch_outlined),
      ('复盘', metrics.reflections, Icons.rate_review_outlined),
      ('反馈', metrics.feedbackSamples, Icons.sensors_outlined),
      ('修正', metrics.revisions, Icons.tune_outlined),
      ('重启力', metrics.restarts, Icons.restart_alt),
    ];
    return Card(
      color: const Color(0xFFF7F4FF),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('成长指标 · 不只奖励成功结果', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: items.map((item) => Chip(avatar: Icon(item.$3, size: 17, color: const Color(0xFF6D5BD0)), label: Text('${item.$1} ${item.$2}'))).toList()),
          if (metrics.restarts > 0) const Padding(padding: EdgeInsets.only(top: 8), child: Text('你回来了，这就是重启力。成长不是不断线，而是断了还能回来。')),
        ]),
      ),
    );
  }
}

class _LoopCard extends StatelessWidget {
  const _LoopCard({required this.loop, required this.onReview});
  final TodoFailureGrowthLoop loop;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(loop.experimentTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            Chip(label: Text(loop.isCompleted ? '已获得反馈' : loop.patternLabel), backgroundColor: loop.isCompleted ? const Color(0xFFE6F5EC) : const Color(0xFFF0EBFF)),
          ]),
          Text(loop.goalTitle, style: const TextStyle(color: Color(0xFF6D5BD0), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(loop.growthReframe, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 8),
          Text('最低标准：${loop.minimumStandard}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (loop.isCompleted) ...[
            const Divider(height: 22),
            Text('成长证据：${loop.resultText}'),
            if (loop.nextRevision.trim().isNotEmpty) Text('下一版：${loop.nextRevision}', style: const TextStyle(color: Color(0xFF3F7D61), fontWeight: FontWeight.w700)),
          ] else ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(onPressed: onReview, icon: const Icon(Icons.check_circle_outline), label: const Text('完成实验并复盘'))),
          ],
        ]),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.title, required this.text});
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6D5BD0))),
          const SizedBox(height: 3),
          Text(text, style: const TextStyle(height: 1.4)),
        ]),
      );
}
