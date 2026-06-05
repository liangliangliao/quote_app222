import 'package:flutter/material.dart';

import '../controllers/change_lab_controller.dart';
import 'change_concept_detail_page.dart';
import 'widgets/section_card.dart';

class ChangeDiagnosisPage extends StatefulWidget {
  const ChangeDiagnosisPage({super.key, required this.controller});

  final ChangeLabController controller;

  @override
  State<ChangeDiagnosisPage> createState() => _ChangeDiagnosisPageState();
}

class _ChangeDiagnosisPageState extends State<ChangeDiagnosisPage> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        title: const Text('问题诊断'),
        backgroundColor: const Color(0xFFF4F2F8),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionCard(
            title: '诊断说明',
            child: Text('用 5 个问题快速判断你更适合先从哪几张概念卡开始，也帮助你识别自己的失败模式。'),
          ),
          ...controller.diagnosisQuestions.map((question) {
            return SectionCard(
              title: question.question,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: question.options.map((option) {
                  final selected = controller.diagnosisAnswer(question.id) == option.label;
                  return ChoiceChip(
                    label: Text(option.label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        controller.answerDiagnosis(question.id, option.label);
                      });
                    },
                  );
                }).toList(),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              setState(controller.calculateDiagnosis);
            },
            child: const Text('生成我的诊断结果'),
          ),
          if (controller.diagnosisResult != null) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: '诊断结果',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(controller.diagnosisResult!.summary, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 12),
                  ...controller.diagnosisResult!.recommendedConceptIds.map((cid) {
                    final concept = controller.conceptById(cid);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(concept.title),
                      subtitle: Text(concept.oneLineSummary),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeConceptDetailPage(
                              controller: controller,
                              concept: concept,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      final first = controller.diagnosisResult!.recommendedConceptIds.first;
                      controller.pinConcept(first);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已把 ${controller.conceptById(first).title} 钉住到首页。')),
                      );
                    },
                    icon: const Icon(Icons.push_pin_outlined),
                    label: const Text('把首推概念钉住到首页'),
                  )
                ],
              ),
            ),
            SectionCard(
              title: '失败模式画像',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: controller.dominantPatterns
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(child: Text(p)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
