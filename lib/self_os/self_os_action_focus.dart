import 'dart:async';
import 'package:flutter/material.dart';
import 'self_os_models.dart';
import 'self_os_widgets.dart';

/// The field screen uses the sealed pre-action protocol. It shows one cue,
/// permits refusal, pauses on backgrounding and records use separately from
/// effectiveness (which can only be reported after the real action).
class SelfOsActionFocus extends StatefulWidget {
  const SelfOsActionFocus({super.key, required this.snapshot});
  final Map<String, dynamic> snapshot;
  @override
  State<SelfOsActionFocus> createState() => _SelfOsActionFocusState();
}

class _SelfOsActionFocusState extends State<SelfOsActionFocus>
    with WidgetsBindingObserver {
  late final fields = osMap(widget.snapshot['fields']);
  late final settings = osMap(osMap(widget.snapshot['v37'])['settings']);
  late final cue = osText(settings['holdCue']);
  late final duration =
      (int.tryParse('${settings['holdSeconds']}') ?? 15).clamp(10, 20);
  late int remaining = duration;
  bool started = false, declined = false, foreground = true, allowPop = false;
  Timer? timer;
  final checked = <int>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (cue.isNotEmpty)
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !foreground || started || declined) return;
        if (remaining > 0) setState(() => remaining--);
        if (remaining == 0) timer?.cancel();
      });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void finish(String result) {
    if (allowPop) return;
    setState(() => allowPop = true);
    Navigator.pop(context, <String, dynamic>{
      'result': result,
      'heldSeconds': cue.isEmpty ? 0 : duration - remaining,
      'cueUsed': cue.isNotEmpty && !declined && remaining == 0,
      'declined': declined,
      'firstActionStarted': started,
      'checkedSteps': checked.toList(),
      'recordedAt': DateTime.now().toIso8601String()
    });
  }

  @override
  Widget build(BuildContext context) {
    final first = osText(fields['firstAction']);
    final steps = osText(fields['ritual'])
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return SelfOsTheme(
        child: PopScope(
            canPop: allowPop,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) finish('cancelled');
            },
            child: Scaffold(
              appBar: AppBar(
                  leading: IconButton(
                      tooltip: '退出现场',
                      onPressed: () => finish('cancelled'),
                      icon: const Icon(Icons.arrow_back)),
                  title: const Text('只走到下一个节点')),
              body: SafeArea(
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: ListView(
                              padding: const EdgeInsets.all(24),
                              children: [
                                const Text('ACTION MOMENT',
                                    style: TextStyle(
                                        letterSpacing: 2,
                                        fontSize: 11,
                                        color: osGold)),
                                const SizedBox(height: 24),
                                if (!started) ...[
                                  Text(
                                      cue.isEmpty || declined
                                          ? '第一步，仅此而已。'
                                          : cue,
                                      key: const ValueKey('single_action_cue'),
                                      style: const TextStyle(
                                          fontSize: 29,
                                          height: 1.5,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 28),
                                  if (cue.isNotEmpty && !declined) ...[
                                    LinearProgressIndicator(
                                        value:
                                            (duration - remaining) / duration,
                                        minHeight: 5,
                                        borderRadius: BorderRadius.circular(8)),
                                    const SizedBox(height: 12),
                                    Text(
                                        remaining > 0
                                            ? '让这条观念留在前景 · $remaining 秒'
                                            : '现在，把观念接上动作。',
                                        key: const ValueKey('hold_countdown')),
                                  ],
                                  const SizedBox(height: 24),
                                  OsSection(title: '接下来', children: [
                                    Text(first,
                                        style: const TextStyle(
                                            fontSize: 22, height: 1.5)),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                        key: const ValueKey(
                                            'focus_first_action'),
                                        onPressed: cue.isEmpty ||
                                                declined ||
                                                remaining == 0
                                            ? () =>
                                                setState(() => started = true)
                                            : null,
                                        icon: const Icon(Icons.arrow_forward),
                                        label: const Text('开始这个动作'))
                                  ]),
                                  if (cue.isNotEmpty && !declined)
                                    TextButton(
                                        onPressed: () =>
                                            setState(() => declined = true),
                                        child: const Text('这条提示不适合此刻，直接执行第一步')),
                                ] else ...[
                                  const Text('已经迈出第一步。',
                                      style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 20),
                                  for (var i = 0; i < steps.length; i++)
                                    CheckboxListTile(
                                        value: checked.contains(i),
                                        onChanged: (v) => setState(() {
                                              if (v == true) {
                                                checked.add(i);
                                              } else {
                                                checked.remove(i);
                                              }
                                            }),
                                        title: Text(steps[i]),
                                        contentPadding: EdgeInsets.zero),
                                  const SizedBox(height: 20),
                                  FilledButton.icon(
                                      onPressed: () => finish('review'),
                                      icon: const Icon(
                                          Icons.auto_stories_outlined),
                                      label: const Text('到达节点，记录真实行动')),
                                ],
                                const SizedBox(height: 24),
                                Text(
                                    '出现这些新信息时重新评估：${osText(fields['reconsiderWhen']).isEmpty ? '与现实有关的重要变化' : fields['reconsiderWhen']}',
                                    style: const TextStyle(
                                        height: 1.6, color: Color(0xFF68786E))),
                                OutlinedButton.icon(
                                    onPressed: () => finish('reconsider'),
                                    icon: const Icon(Icons.update),
                                    label: const Text('出现重要新信息，先重审')),
                              ])))),
            )));
  }
}
