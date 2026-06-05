import 'package:flutter/material.dart';

import 'training_cabin_models.dart';
import 'training_consolidation_page.dart';

class TrainingCabinResultPage extends StatelessWidget {
  final TrainingCabinCompletedRun run;

  const TrainingCabinResultPage({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    final replay = run.replay;
    final reward = run.reward;
    final dimensionScores = replay.dimensionScores.isNotEmpty
        ? replay.dimensionScores
        : {
            '承担与直面': ((run.finalState.trustScore + run.finalState.goalProgress) ~/ 2).clamp(0, 100),
            '风险控制': (100 - run.finalState.riskScore).clamp(0, 100),
            '情绪稳定': (100 - run.finalState.emotionTension).clamp(0, 100),
            '推进执行': ((run.finalState.goalProgress + run.finalState.teamStability) ~/ 2).clamp(0, 100),
          };
    return Scaffold(
      appBar: AppBar(title: const Text('训练舱结算'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(run.draft.descriptor.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _badge(replay.resultLabel, const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
                _badge('总分 ${replay.totalScore}', const Color(0xFFECFDF5), const Color(0xFF166534)),
                _badge('Provider ${run.provider}', const Color(0xFFF3F4F6), const Color(0xFF374151)),
              ]),
              const SizedBox(height: 12),
              Text(replay.summary, style: const TextStyle(height: 1.45, color: Color(0xFF374151))),
            ]),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('现实影响', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _line('信任度', '${run.finalState.trustScore}'),
              _line('风险值', '${run.finalState.riskScore}'),
              _line('目标推进', '${run.finalState.goalProgress}'),
              _line('情绪张力', '${run.finalState.emotionTension}'),
              _line('结束原因', run.finalState.finishReason.isEmpty ? '模型判定结束' : run.finalState.finishReason),
            ]),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('分维度得分', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...dimensionScores.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.key),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: (e.value.clamp(0, 100)) / 100, minHeight: 8, borderRadius: BorderRadius.circular(999)),
                      const SizedBox(height: 4),
                      Text('${e.value}', style: const TextStyle(color: Color(0xFF6B7280))),
                    ]),
                  )),
            ]),
          ),
          if (reward != null) ...[
            const SizedBox(height: 12),
            _Card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('成长奖励', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _badge('+${reward.xpGained} XP', const Color(0xFFECFDF5), const Color(0xFF166534)),
                  _badge('Lv.${reward.profile.level}', const Color(0xFFE0E7FF), const Color(0xFF3730A3)),
                  _badge('连胜 ${reward.profile.streak}', const Color(0xFFFFF7ED), const Color(0xFF9A3412)),
                ]),
                if (reward.unlockedAchievements.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: reward.unlockedAchievements.map((e) => _badge(e, const Color(0xFFFEF3C7), const Color(0xFF92400E))).toList()),
                ],
                if (reward.worldEvents.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...reward.worldEvents.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $e', style: const TextStyle(color: Color(0xFF4B5563))),
                      )),
                ],
              ]),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => TrainingCabinConsolidationPage(run: run)),
            );
          },
          icon: const Icon(Icons.arrow_forward),
          label: const Text('进入固化层'),
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}
