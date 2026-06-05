import 'package:flutter/material.dart';

import '../models/action_engine_models.dart';
import 'action_engine_home_page.dart';
import 'action_execution_page.dart';

class ActionFeedbackPage extends StatelessWidget {
  final ActionPlan plan;
  final ActionExecution execution;
  final List<ActionStepExecution> records;
  final ActionWorldReward? worldReward;

  const ActionFeedbackPage({
    super.key,
    required this.plan,
    required this.execution,
    required this.records,
    this.worldReward,
  });

  @override
  Widget build(BuildContext context) {
    final completed = records.where((e) => e.completed).toList();
    final pending = records.where((e) => !e.completed).toList();
    final frictions = records.where((e) => e.encounteredFriction).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('行动反馈'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_resultTitle(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('完成 ${execution.completedSteps}/${execution.totalSteps} 步 · 异常 ${execution.frictionCount} 次', style: const TextStyle(color: Color(0xFF4B5563))),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: execution.totalSteps == 0 ? 0 : execution.completedSteps / execution.totalSteps, minHeight: 10, borderRadius: BorderRadius.circular(999)),
            ]),
          ),
          if (worldReward != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('世界成长反馈', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _badge('+${worldReward!.xpGained} XP', const Color(0xFFECFDF5), const Color(0xFF166534)),
                  _badge('Lv.${worldReward!.levelAfter}', const Color(0xFFE0E7FF), const Color(0xFF3730A3)),
                  _badge('连胜 ${worldReward!.streakAfter}', const Color(0xFFFFF7ED), const Color(0xFF9A3412)),
                ]),
                if (worldReward!.unlockedAchievements.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: worldReward!.unlockedAchievements.map((e) => _badge(e, const Color(0xFFFEF3C7), const Color(0xFF92400E))).toList()),
                ],
                if (worldReward!.worldEvents.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...worldReward!.worldEvents.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $e', style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
                      )),
                ]
              ]),
            ),
          ],
          const SizedBox(height: 16),
          if (completed.isNotEmpty) _section('已完成步骤', completed.map((e) => e.stepText).toList()),
          if (pending.isNotEmpty) _section('未完成步骤', pending.map((e) => e.stepText).toList()),
          if (frictions.isNotEmpty)
            _section(
              '出现异常的步骤',
              frictions.map((e) => '${e.stepText}（${e.frictionType ?? '未分类'} → ${e.fallbackAction ?? '无替代动作'}）').toList(),
            ),
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('下一步建议', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(_nextSuggestion(), style: const TextStyle(color: Color(0xFF4B5563), height: 1.45)),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => ActionExecutionPage(plan: plan)),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新执行这条行动链'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const ActionEngineHomePage()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('返回行动引擎首页'),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _section(String title, List<String> items) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 8, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e, style: const TextStyle(color: Color(0xFF4B5563), height: 1.45))),
                ]),
              )),
        ]),
      );

  String _resultTitle() {
    switch (execution.status) {
      case 'completed':
        return '行动已完整完成';
      case 'partial':
        return '行动部分完成';
      case 'interrupted':
        return '这次行动中断了';
      default:
        return '行动已记录';
    }
  }

  String _nextSuggestion() {
    if (execution.status == 'completed') return '你已经把这条行动链走完了。下一次可以复制这条行动链，或在同一概念下尝试另一个行动方向。';
    if (execution.frictionCount > 0) return '你并不是“做不到”，而是在某些步骤上出现了异常。下次先从最常卡住的那一步开始，并直接使用更小版本。';
    return '先不要推翻整条行动链，保留已完成的部分，只把未完成步骤继续往前推进。';
  }
}
