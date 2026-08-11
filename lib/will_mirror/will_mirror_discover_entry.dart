import 'package:flutter/material.dart';

import 'will_mirror_widgets.dart';

class WillMirrorDiscoverEntry extends StatelessWidget {
  const WillMirrorDiscoverEntry({
    super.key,
    required this.onTap,
  });

  static const Key entryKey = ValueKey<String>('discover_will_mirror_v4');

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '意志之镜 V4.0，表象、动机、跨人生证据、反证与现实实验',
      child: Material(
        key: entryKey,
        color: const Color(0xFFF1EDE5),
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
                  backgroundColor: Color(0xFFE3D7C3),
                  child: Icon(
                    Icons.filter_vintage_outlined,
                    size: 21,
                    color: WillMirrorPalette.forest,
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '意志之镜 · 自我一致人生',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: WillMirrorPalette.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Deep Why · 跨人生证据 · 强制反证 · 7日现实实验',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: WillMirrorPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: WillMirrorPalette.moss),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
