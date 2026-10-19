import 'package:flutter/material.dart';
import 'self_os_home_page.dart';
import 'self_os_widgets.dart';

class SelfOsDiscoverEntry extends StatelessWidget {
  const SelfOsDiscoverEntry({super.key, this.onTap});
  static const entryKey = ValueKey('discover_self_os_v3');
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        key: entryKey,
        color: const Color(0xFFEAF0E9),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ??
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const SelfOsHomePage())),
          child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(children: [
                CircleAvatar(
                    backgroundColor: Color(0xFFD8E5D7),
                    child: Icon(Icons.explore_outlined, color: osForest)),
                SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('成为自己 · Self OS',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: osForest)),
                      SizedBox(height: 4),
                      Text('V3.7 · 看见可能性，在行动中认识自己',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF65766B)))
                    ])),
                Icon(Icons.chevron_right, color: osForest),
              ])),
        ),
      );
}
