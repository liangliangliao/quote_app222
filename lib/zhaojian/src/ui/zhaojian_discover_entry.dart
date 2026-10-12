import 'package:flutter/material.dart';

import '../copy.dart';

/// 「发现」页里的照见入口卡片。
///
/// 只描述这里有什么，不做任何鼓动：卡片上不出现数量、进度或状态。
class ZhaojianDiscoverEntry extends StatelessWidget {
  const ZhaojianDiscoverEntry({super.key, required this.onTap});

  static const Key entryKey = ValueKey<String>('discover_zhaojian_v1');

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ZCopy.discoverSemantics,
      child: Material(
        key: entryKey,
        color: const Color(0xFFF2F6F8),
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
                  backgroundColor: Color(0xFFDCE8ED),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    size: 21,
                    color: Color(0xFF2C5D70),
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ZCopy.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        ZCopy.discoverSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E7F86),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Color(0xFF7F949C)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
