import 'package:flutter/material.dart';
import 'evidence_growth_notification_link.dart';

class EvidenceGrowthNotificationInbox extends StatefulWidget {
  const EvidenceGrowthNotificationInbox(
      {super.key, required this.targets, required this.onOpen});
  final List<GrowthNotificationTarget> targets;
  final Future<void> Function(GrowthNotificationTarget) onOpen;
  @override
  State<EvidenceGrowthNotificationInbox> createState() => _InboxState();
}

class _InboxState extends State<EvidenceGrowthNotificationInbox> {
  bool opening = false;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('证据成长 · 通知待办')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('这次通知包含 ${widget.targets.length} 项。选择一项即可定位到对应记录与节点。'),
        for (final t in widget.targets)
          Card(
              child: ListTile(
                  key: ValueKey(t.key),
                  title: Text(
                      t.title.isEmpty ? '证据成长 · ${t.nodeLabel}节点' : t.title),
                  subtitle: Text(t.summary.isEmpty ? '点击查看本项当前状态' : t.summary),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !opening,
                  onTap: () async {
                    setState(() => opening = true);
                    try {
                      await widget.onOpen(t);
                    } finally {
                      if (mounted) setState(() => opening = false);
                    }
                  }))
      ]));
}
