import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../concept_engine_detail_page.dart';
import 'training_cabin_models.dart';
import 'training_hub_page.dart';
import 'training_intro_page.dart';
import 'training_growth_archive_page.dart';

class TrainingCabinConsolidationPage extends StatelessWidget {
  final TrainingCabinCompletedRun run;

  const TrainingCabinConsolidationPage({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    final replay = run.replay;
    final assist = run.toAssistResult();
    return Scaffold(
      appBar: AppBar(title: const Text('行动固化与重演'), backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      backgroundColor: const Color(0xFFF7F7FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('关键节点', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...replay.rootCauses.map((e) => _bullet(e)),
              if (replay.ignoredSignals.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('你忽略的信号', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...replay.ignoredSignals.map((e) => _bullet(e)),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('更优替代动作', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...replay.betterActions.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('问题：${e.problem}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('更优动作：${e.betterAction}', style: const TextStyle(color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      Text('推荐句式：${e.examplePhrase}', style: const TextStyle(color: Color(0xFF6B7280))),
                    ]),
                  )),
            ]),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('可带回行动链的建议', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('建议语气：${assist.recommendedTone}', style: const TextStyle(color: Color(0xFF374151))),
              const SizedBox(height: 6),
              Text('建议动作：${assist.recommendedAction}', style: const TextStyle(color: Color(0xFF374151))),
              const SizedBox(height: 6),
              Text('建议表达：${assist.recommendedPhrase}', style: const TextStyle(color: Color(0xFF6B7280), height: 1.45)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: assist.recommendedPhrase));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制一条可直接带回行动链的表达')));
                },
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('复制建议表达'),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('重演与继续', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (run.draft.returnToActionChain)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(assist),
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('返回行动链继续执行'),
                  ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => TrainingCabinIntroPage(
                          descriptor: run.draft.descriptor,
                          concept: run.draft.concept,
                          goal: run.draft.goal,
                          domain: run.draft.domain,
                          returnToActionChain: run.draft.returnToActionChain,
                          linkedPlanId: run.draft.linkedPlanId,
                          linkedStepId: run.draft.linkedStepId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('从头再练一次'),
                ),
                OutlinedButton.icon(
                  onPressed: run.recordId == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ConceptEngineDetailPage(recordId: run.recordId!)),
                          );
                        },
                  icon: const Icon(Icons.history),
                  label: const Text('查看完整记录'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const TrainingHubPage()),
                    );
                  },
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('返回训练舱大厅'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TrainingGrowthArchivePage()),
                    );
                  },
                  icon: const Icon(Icons.insights_outlined),
                  label: const Text('查看成长档案'),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('• $text', style: const TextStyle(color: Color(0xFF4B5563), height: 1.4)),
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
