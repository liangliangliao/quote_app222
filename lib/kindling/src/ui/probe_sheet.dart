import 'package:flutter/material.dart';

import '../copy.dart';
import '../domain/controller.dart';

/// 痒度自评。唯一的主观信号，只喂给排序。
///
/// 界面上没有数字、没有星级、没有程度条，只有五句措辞；答完不给任何反馈，
/// 用户也无从知道自己"打了几分"。
class KindlingProbeSheet extends StatelessWidget {
  const KindlingProbeSheet({
    super.key,
    required this.title,
    required this.onPick,
  });

  static const Key sheetKey = ValueKey<String>('kindling_probe_sheet');

  final String title;

  /// 回传 0..4。下标与 [KCopy.probeLadder] 的顺序相反：最痒在最上面。
  final ValueChanged<int> onPick;

  static Future<void> show(
    BuildContext context, {
    required KindlingController controller,
    required int itemId,
    required String title,
  }) async {
    final int? score = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext sheetContext) => KindlingProbeSheet(
        title: title,
        onPick: (int value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    if (score == null) return;
    await controller.recordProbe(itemId, score);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: sheetKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: Color(0xFF8A8A8A)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              KCopy.menuProbe,
              style: TextStyle(fontSize: 18, color: Color(0xFF2B2B2B)),
            ),
          ),
          // 屏幕矮或字号大时让档位自己滚动，不挤压也不裁切。
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: KCopy.probeLadder.length,
              itemBuilder: (BuildContext context, int i) {
                final int score = KCopy.probeLadder.length - 1 - i;
                return ListTile(
                  key: ValueKey<String>('kindling_probe_$score'),
                  title: Text(
                    KCopy.probeLadder[i],
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  onTap: () => onPick(score),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
