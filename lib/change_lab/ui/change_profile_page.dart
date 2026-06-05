import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import '../models/change_models.dart';
import 'widgets/section_card.dart';

class ChangeProfilePage extends StatelessWidget {
  const ChangeProfilePage({super.key, required this.controller});

  final ChangeLabController controller;

  String _statusText(ConceptStatus status) {
    switch (status) {
      case ConceptStatus.unread:
        return '未进入';
      case ConceptStatus.read:
        return '已阅读';
      case ConceptStatus.acted:
        return '已行动';
      case ConceptStatus.internalized:
        return '已内化';
    }
  }

  static const moduleNames = {
    'foundation': '基础逻辑',
    'resistance': '阻力与框架',
    'affect': '情绪路径',
    'behavior': '行为路径',
  };

  @override
  Widget build(BuildContext context) {
    final moduleRates = controller.moduleCompletionRates;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: const Text('成长画像'),
        backgroundColor: const Color(0xFFF4F2F8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: '总览',
            child: Row(
              children: [
                Expanded(child: _metric('连续行动', '${controller.streakDays}天')),
                Expanded(child: _metric('已行动概念', '${controller.actedConceptCount}')),
                Expanded(child: _metric('一致性分', controller.consistencyScore.toStringAsFixed(1))),
              ],
            ),
          ),
          SectionCard(
            title: '行动趋势',
            child: Row(
              children: [
                Expanded(child: _metric('今日动作', '${controller.todayActionCount}')),
                Expanded(child: _metric('本周动作', '${controller.weeklyActionCount}')),
                Expanded(child: _metric('平均缓解', controller.averageReliefScore.toStringAsFixed(1))),
              ],
            ),
          ),
          SectionCard(
            title: '模块完成度',
            child: Column(
              children: moduleNames.entries.map((entry) {
                final rate = moduleRates[entry.key] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text('${(rate * 100).round()}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: rate),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          SectionCard(
            title: '主要模式',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: controller.dominantPatterns
                  .map((pattern) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(pattern)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          SectionCard(
            title: '概念状态',
            child: Column(
              children: controller.concepts.map((concept) {
                final progress = controller.progressById(concept.id);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(concept.title),
                  subtitle: Text('行动 ${progress.actionCount} 次 · 复盘 ${progress.reflectionCount} 次'),
                  trailing: Text(_statusText(progress.status)),
                );
              }).toList(),
            ),
          ),
          SectionCard(
            title: '最近任务运行',
            child: controller.recentTaskRuns.isEmpty
                ? const Text('还没有任务记录。完成任意任务后，这里会自动展示。')
                : Column(
                    children: controller.recentTaskRuns.take(8).map((run) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${run.conceptId} · ${run.taskId}'),
                        subtitle: Text(run.combinedReflection),
                        trailing: Text('${run.beforeScore}→${run.afterScore}'),
                      );
                    }).toList(),
                  ),
          ),
          SectionCard(
            title: '最近复盘',
            child: controller.reflections.isEmpty
                ? const Text('还没有复盘记录。完成任意任务后，这里会自动展示。')
                : Column(
                    children: controller.reflections.take(10).map((entry) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${entry.conceptId} · ${entry.taskId}'),
                        subtitle: Text(entry.text),
                        trailing: Text('${entry.createdAt.month}/${entry.createdAt.day}'),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Color(0xFF70727A))),
      ],
    );
  }
}
