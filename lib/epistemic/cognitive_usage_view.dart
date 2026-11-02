import 'package:flutter/material.dart';
import 'cognitive_mode.dart';
import 'cognitive_usage.dart';

class CognitiveUsageDialog extends StatefulWidget {
  final CognitiveUsageStore? store;
  const CognitiveUsageDialog({super.key, this.store});
  @override
  State<CognitiveUsageDialog> createState() => _CognitiveUsageDialogState();
}

class _CognitiveUsageDialogState extends State<CognitiveUsageDialog> {
  late final _store = widget.store ?? CognitiveUsageStore.instance;
  Map<CognitiveEvent, int> _counters = {};
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool clear = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (clear) await _store.clear();
      final values = await _store.read();
      if (mounted) setState(() => _counters = values);
    } catch (_) {
      if (mounted) setState(() => _error = '本地记录暂未读取，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CognitiveMode(
      fallback: AlertDialog(
          title: const Text('认知风格已关闭'),
          content: const Text('已停止记录新的认知交互。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'))
          ]),
      child: AlertDialog(
          title: const Text('本地匿名使用记录'),
          content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text(
                        '仅累计交互次数和错误类别，不包含正文、记录 ID、时间线、模型返回或设备标识，不上传。次数不用于评价认识水平。'),
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null)
                      TextButton(onPressed: _load, child: Text(_error!)),
                    if (!_busy && _counters.isEmpty)
                      const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text('暂无记录。可在设置中自愿启用。')),
                    for (final event in CognitiveEvent.values)
                      if (_counters.containsKey(event))
                        Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text('${event.label}：${_counters[event]}')),
                  ]))),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => _load(clear: true),
                child: const Text('清除本地计数')),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭')),
          ]));
}
