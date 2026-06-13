import 'package:flutter/material.dart';

import 'james_will_training_models.dart';
import 'james_will_training_page.dart';
import 'todo_goal_models.dart';
import 'todo_goal_will_bridge.dart';

class TodoGoalWillCenterPage extends StatefulWidget {
  const TodoGoalWillCenterPage({super.key, required this.goal, this.step});

  final TodoGoalProfile goal;
  final TodoGoalActionStep? step;

  @override
  State<TodoGoalWillCenterPage> createState() => _TodoGoalWillCenterPageState();
}

class _TodoGoalWillCenterPageState extends State<TodoGoalWillCenterPage> {
  final _bridge = TodoGoalWillBridge();
  JamesWillActionIdea? _idea;
  List<JamesWillLog> _logs = const <JamesWillLog>[];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final idea = await _bridge.synchronize(goal: widget.goal, step: widget.step);
      final logs = await _bridge.logsFor(goalId: widget.goal.goalId, stepId: widget.step?.stepId);
      if (!mounted) return;
      setState(() {
        _idea = idea;
        _logs = logs;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _openEngine() async {
    final idea = _idea;
    if (idea == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => JamesWillActionIdeaDetailPage(ideaId: idea.id)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final idea = _idea;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(title: const Text('今日意志中心')),
      body: idea == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text('意志中心加载失败：$_error')))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                children: [
                  _hero(idea),
                  const SizedBox(height: 12),
                  _section('目标 → 价值 → 行动观念', [
                    _line('Todo 目标', widget.goal.goalTitle),
                    _line('核心价值', idea.coreValue),
                    _line('今日行动观念', idea.actionIdea),
                    _line('第一身体动作', idea.firstBodyAction),
                    _line('最小 / 5分钟版本', '${idea.minimumAction}\n${idea.fiveMinuteVersion}'),
                  ]),
                  const SizedBox(height: 12),
                  _competition(idea),
                  const SizedBox(height: 12),
                  _section('可控域与决定边界', [
                    _line('不可直接控制', '最终结果、他人评价、环境变化和一次行动能否立刻见效'),
                    _line('此刻可控制', idea.firstBodyAction),
                    _line('决定封存原则', '进入执行期后不反复审判整个目标；新疑问先记录，到复盘日再判断。'),
                  ]),
                  const SizedBox(height: 12),
                  _section('意志训练反馈', [
                    _line('已记录行动', '${_logs.length} 次'),
                    _line('注意力恢复', '${_logs.fold<int>(0, (sum, log) => sum + log.attentionRecoveryCount)} 次'),
                    _line('训练重点', '不是只看完成数量，而是看你在阻力中把行动观念拉回了多少次。'),
                  ]),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _openEngine, icon: const Icon(Icons.play_arrow_rounded), label: const Text('预演第一动作并开始 5 分钟')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: _openEngine, icon: const Icon(Icons.psychology_alt_outlined), label: const Text('观念竞争 · 决定封存 · 意志复盘')),
                ],
              ),
            ),
    );
  }

  Widget _hero(JamesWillActionIdea idea) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF25342F), borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('足下意志 × Todo 目标价值', style: TextStyle(color: Color(0xFFD9B56D), fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(idea.attentionAnchor, style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.35, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text('今天最重要的不是完成一堆任务，而是让哪个观念占据意识，并进入一个身体动作。', style: TextStyle(color: Colors.white.withOpacity(.76), height: 1.45)),
        ]),
      );

  Widget _competition(JamesWillActionIdea idea) => _section(
        '当前观念竞争',
        idea.competitionItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(width: 72, child: Text(item.type, style: const TextStyle(fontWeight: FontWeight.w800))),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.content), const SizedBox(height: 4), LinearProgressIndicator(value: item.strength / 100)])),
            const SizedBox(width: 10),
            Text('${item.strength}'),
          ]),
        )).toList(),
      );

  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7E0D4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 12), ...children]),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Color(0xFF8B6F47), fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(value, style: const TextStyle(height: 1.4))]),
      );
}
