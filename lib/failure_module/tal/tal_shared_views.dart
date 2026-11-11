import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tal_catalog.dart';

class TalSafetyCard extends StatelessWidget {
  const TalSafetyCard({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('先照顾你的安全',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('已停止复盘引导，这段危机文字不会保存或发送 AI。'
                '请联系可信任的人陪伴你；如果可能马上伤害自己，请联系当地急救或紧急服务，'
                '并尽量远离可用于伤害自己的物品。也可以向当地危机热线或专业人员求助。'),
          ]));
}

class TalSourceLinks extends StatelessWidget {
  const TalSourceLinks({super.key, required this.catalog, required this.ids});
  final TalCatalog catalog;
  final List<String> ids;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final id in ids)
          if (catalog.sources[id] case final Map source)
            TextButton(
                onPressed: () async {
                  final url = Uri.tryParse('${source['url']}');
                  if (url != null && url.scheme == 'https') {
                    try {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  }
                },
                child: Text('$id · ${source['title']}'
                    '${source['caution'] == null ? '' : '\n${source['caution']}'}'
                    '${source['scope'] == null ? '' : '\n${source['scope']}'}'))
      ]);
}
