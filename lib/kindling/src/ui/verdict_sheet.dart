import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';

/// 判别式：如果没人知道你做了这件事，你还做吗？
///
/// 新建火种后强制弹一次，之后可从长按菜单手动重问。
class KindlingVerdictSheet extends StatelessWidget {
  const KindlingVerdictSheet({
    super.key,
    required this.title,
    required this.onAnswer,
  });

  static const Key sheetKey = ValueKey<String>('kindling_verdict_sheet');
  static const Key yesKey = ValueKey<String>('kindling_verdict_yes');
  static const Key noKey = ValueKey<String>('kindling_verdict_no');
  static const Key unsureKey = ValueKey<String>('kindling_verdict_unsure');

  final String title;
  final ValueChanged<String> onAnswer;

  /// 弹出判别式。返回用户的回答（未作答返回 null）。
  ///
  /// 作答会写入 k_verdict；答「不做」时火种移入「放掉的」，随后给一句说明。
  static Future<String?> show(
    BuildContext context, {
    required KindlingController controller,
    required int itemId,
    required String title,
  }) async {
    final String? answer = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext sheetContext) => KindlingVerdictSheet(
        title: title,
        onAnswer: (String value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    if (answer == null) return null;

    await controller.recordVerdict(itemId, answer);

    if (answer == KVerdictAnswer.no && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          content: const Text(
            KCopy.verdictNoTip,
            style: TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF2B2B2B)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(KCopy.done),
            ),
          ],
        ),
      );
    }
    return answer;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: sheetKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF8A8A8A),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              KCopy.verdictQ,
              style: TextStyle(
                fontSize: 18,
                height: 1.5,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                _VerdictButton(
                  buttonKey: yesKey,
                  label: KCopy.verdictYes,
                  onTap: () => onAnswer(KVerdictAnswer.yes),
                ),
                const SizedBox(width: 10),
                _VerdictButton(
                  buttonKey: noKey,
                  label: KCopy.verdictNo,
                  onTap: () => onAnswer(KVerdictAnswer.no),
                ),
                const SizedBox(width: 10),
                _VerdictButton(
                  buttonKey: unsureKey,
                  label: KCopy.verdictIdk,
                  onTap: () => onAnswer(KVerdictAnswer.unsure),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    required this.buttonKey,
    required this.label,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2B2B2B),
          side: const BorderSide(color: Color(0xFFDDDDDD)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
