import 'package:flutter/material.dart';

import '../copy.dart';

/// 「发现之旅」里的火种入口卡片。
///
/// 只描述这里有什么，不做任何鼓动。卡片上不出现数量、进度或状态。
class KindlingDiscoverEntry extends StatelessWidget {
  const KindlingDiscoverEntry({super.key, required this.onTap});

  static const Key entryKey = ValueKey<String>('discover_kindling_v1');

  /// 入口副标题：模块内的四件事，陈述句。
  static const String subtitle =
      '${KCopy.recall} · ${KCopy.menuVerdict} · ${KCopy.burn} · ${KCopy.released}';

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: KCopy.discoverSemantics,
      child: Material(
        key: entryKey,
        color: const Color(0xFFF6F3EE),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFE9E2D6),
                  child: Icon(
                    Icons.local_fire_department_outlined,
                    size: 21,
                    color: Color(0xFF7A6544),
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        KCopy.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A7F6E),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Color(0xFF9A8E7B)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
