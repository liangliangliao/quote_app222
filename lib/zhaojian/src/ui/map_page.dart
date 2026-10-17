import 'package:flutter/material.dart';

import '../copy.dart';
import '../domain/controller.dart';
import 'nav.dart';
import 'widgets.dart';

/// 原理：思想地图。每个理论接在哪里，能跳过去的才给跳转。
class MapPage extends StatelessWidget {
  const MapPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  Widget build(BuildContext context) {
    return ZPage(
      title: '原理',
      controller: controller,
      content: (BuildContext context) => <Widget>[
        const ZNote('这个工具把几种说法接在同一条因果链上，每条都只是工作假设；叔本华的引用以二手资料为准，措辞请核对原文。'),
        const ZNote(ZCopy.chainLine),
        const SizedBox(height: 6),
        for (final List<String> t in ZCopy.theoryMap)
          ZItem(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(t[0], style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(t[1], style: const TextStyle(fontSize: 13, height: 1.5)),
                ZNote('用在：${t[2]}'),
                if (ZNav.byName(t[3]) != null && ZNav.isReady(ZNav.byName(t[3])!))
                  TextButton(
                    onPressed: () => ZNav.open(context, controller, ZNav.byName(t[3])!),
                    child: Text('去看：${ZNav.info[ZNav.byName(t[3])!]!.title}'),
                  ),
              ],
            ),
          ),
        const ZNote(ZCopy.redLine),
      ],
    );
  }
}
