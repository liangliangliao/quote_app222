import 'package:flutter/material.dart';

import '../copy.dart';

/// 「发现之旅」里的入口卡片。只描述这里有什么，卡片上不出现数量或状态。
class EnemyDiscoverEntry extends StatelessWidget {
  const EnemyDiscoverEntry({super.key, required this.onTap});

  static const Key entryKey = ValueKey<String>('discover_beautiful_enemy_v1');

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: EnemyCopy.discoverSemantics,
      child: Material(
        key: entryKey,
        color: const Color(0xFF2A1F1E),
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
                  backgroundColor: Color(0xFF4A2E2B),
                  child: Icon(
                    Icons.gavel_outlined,
                    size: 20,
                    color: Color(0xFFE8B4A8),
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        EnemyCopy.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF3E9E6),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        EnemyCopy.discoverSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Color(0xFFB9A29D)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Color(0xFFB9A29D)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
