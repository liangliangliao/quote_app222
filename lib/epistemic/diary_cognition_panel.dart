import 'package:flutter/material.dart';
import 'cognitive_models.dart';

/// An optional doorway under the existing editor, not a second diary editor.
class DiaryCognitionPanel extends StatelessWidget {
  final VoidCallback onAnalyze, onNotes;
  final ValueChanged<GroundLens> onLens;
  const DiaryCognitionPanel({
    super.key,
    required this.onAnalyze,
    required this.onNotes,
    required this.onLens,
  });
  static const colors = [
    Color(0xff4d96ce),
    Color(0xffd47f87),
    Color(0xffe1a84b),
    Color(0xff65a88d),
    Color(0xff8b83b9),
  ];
  static const icons = [
    Icons.schedule,
    Icons.place_outlined,
    Icons.hub_outlined,
    Icons.fact_check_outlined,
    Icons.favorite_outline,
  ];
  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('diary-cognition-panel'),
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xfffcf8ef),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe8dfcf)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              for (final entry in ['事实', '感受', '解释', '判断', '根据'].indexed)
                Expanded(
                    child: InkWell(
                        key: ValueKey('diary-classification-${entry.$1}'),
                        onTap: onAnalyze,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                          color: colors[entry.$1].withAlpha(22),
                                          shape: BoxShape.circle),
                                      child: Icon(
                                          [
                                            Icons.event_note_outlined,
                                            Icons.favorite_outline,
                                            Icons.lightbulb_outline,
                                            Icons.balance_outlined,
                                            Icons.fact_check_outlined
                                          ][entry.$1],
                                          size: 20,
                                          color: colors[entry.$1])),
                                  const SizedBox(height: 6),
                                  Text(entry.$2,
                                      style: const TextStyle(fontSize: 12)),
                                ])))),
            ]),
            const SizedBox(height: 14),
            const Text(
              '从不同视角看这件事',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              '先选择愿意分析的文字；原文保留，理解可以修订。',
              style: TextStyle(
                  fontSize: 12, color: Color(0xff736c62), height: 1.5),
            ),
            const SizedBox(height: 10),
            for (final lens in GroundLens.values.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.white.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    leading: Icon(icons[lens.$1], color: colors[lens.$1]),
                    title: Text(
                      lens.$2.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(lens.$2.question),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => onLens(lens.$2),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onNotes,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('查看注释与修订'),
              ),
            ),
          ],
        ),
      );
}
