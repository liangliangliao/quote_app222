import 'package:flutter/material.dart';

import '../models/action_engine_models.dart';
import '../repository/action_engine_dao.dart';

class ActionGrowthPage extends StatefulWidget {
  const ActionGrowthPage({super.key});

  @override
  State<ActionGrowthPage> createState() => _ActionGrowthPageState();
}

class _ActionGrowthPageState extends State<ActionGrowthPage> {
  final _dao = ActionEngineDao();
  bool _loading = true;
  List<ActionGrowthSnapshot> _growth = const [];
  List<ActionExecution> _executions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _dao.ensureSchema();
    final growth = await _dao.listGrowth();
    final execs = await _dao.listExecutions(limit: 20);
    if (!mounted) return;
    setState(() {
      _growth = growth;
      _executions = execs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('行动成长'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Text(
                '这里看的是“行动”层面的成长：你最常练什么、最常卡在哪、哪些概念的完成率更高。阻力默认不是主路径，只有真正出现时才被记录为异常。',
                style: TextStyle(color: Color(0xFF4B5563), height: 1.45),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_growth.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: const Text('还没有行动引擎记录。先完成一个行动链，再回来查看成长。'),
              )
            else ...[
              const Text('按概念查看成长', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ..._growth.map((g) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.concept, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('行动链 ${g.totalPlans} 条 · 执行 ${g.totalExecutions} 次 · 完成 ${g.completedExecutions} 次', style: const TextStyle(color: Color(0xFF4B5563))),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: g.completionRate, minHeight: 8, borderRadius: BorderRadius.circular(999)),
                      const SizedBox(height: 6),
                      Text('完成率 ${(g.completionRate * 100).toStringAsFixed(0)}% · 累计异常 ${g.totalFrictions}', style: const TextStyle(color: Color(0xFF4B5563))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _pill(g.mostCommonDirection.isEmpty ? '常练方向：暂无' : '常练方向：${g.mostCommonDirection}'),
                        _pill(g.mostCommonFrictionType.isEmpty ? '常见异常：暂无' : '常见异常：${g.mostCommonFrictionType}'),
                      ]),
                    ]),
                  )),
              const SizedBox(height: 8),
              const Text('最近执行记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ..._executions.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                    child: ListTile(
                      title: Text(e.concept, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${e.status} · 完成 ${e.completedSteps}/${e.totalSteps} · 异常 ${e.frictionCount}'),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151))),
      );
}
