import 'package:flutter/material.dart';

import 'touch_effort.dart';

Future<({EffortTuning? value})?> editEffortTuning(
  BuildContext context,
  EffortDifficulty difficulty,
  EffortTuning tuning,
) =>
    showDialog<({EffortTuning? value})>(
      context: context,
      builder: (context) =>
          _EffortTuningDialog(difficulty: difficulty, tuning: tuning),
    );

String effortHoldLabel(Duration time) {
  if (time.inHours > 0 &&
      time.inMinutes.remainder(60) == 0 &&
      time.inMilliseconds.remainder(60000) == 0) {
    return '${time.inHours} 小时';
  }
  return '${_seconds(time)} 秒';
}

String _seconds(Duration time) => (time.inMilliseconds / 1000)
    .toStringAsFixed(3)
    .replaceFirst(RegExp(r'\.?0+$'), '');

class _EffortTuningDialog extends StatefulWidget {
  const _EffortTuningDialog({required this.difficulty, required this.tuning});

  final EffortDifficulty difficulty;
  final EffortTuning tuning;

  @override
  State<_EffortTuningDialog> createState() => _EffortTuningDialogState();
}

class _EffortTuningDialogState extends State<_EffortTuningDialog> {
  final _form = GlobalKey<FormState>();
  late int _taps = widget.tuning.taps;
  late int _swipe = widget.tuning.swipeDistance;
  late int _holdMs = widget.tuning.holdTime.inMilliseconds;
  late int _tapGap = widget.tuning.tapGap.inMilliseconds;
  late int _swipeGap = widget.tuning.swipeGap.inMilliseconds;

  void _save() {
    final form = _form.currentState!;
    if (!form.validate()) return;
    form.save();
    Navigator.pop(context, (
      value: EffortTuning(
        taps: _taps,
        swipeDistance: _swipe,
        holdTime: Duration(milliseconds: _holdMs),
        tapGap: Duration(milliseconds: _tapGap),
        swipeGap: Duration(milliseconds: _swipeGap),
      )
    ));
  }

  Widget _number(
      {required String label,
      required String initial,
      required ValueChanged<int> onSaved,
      bool seconds = false,
      bool delay = false}) {
    int? parse(String? raw) {
      final text = raw?.trim().replaceAll(',', '.');
      if (text == null) return null;
      if (!seconds) {
        return RegExp(r'^\d+$').hasMatch(text) ? int.tryParse(text) : null;
      }
      if (!RegExp(r'^(?:\d+(?:\.\d{1,3})?|\.\d{1,3})$').hasMatch(text))
        return null;
      final value = double.tryParse(text);
      if (value == null ||
          !value.isFinite ||
          value * 1000 > EffortTuning.maxDelayMilliseconds) return null;
      return (value * 1000).round();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TextFormField(
        initialValue: initial,
        keyboardType: TextInputType.numberWithOptions(decimal: seconds),
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: (text) {
          final number = parse(text);
          if (number == null ||
              number < 1 ||
              (delay && number > EffortTuning.maxDelayMilliseconds)) {
            return seconds ? '请输入有效秒数，最多三位小数' : '请输入有效的正整数';
          }
          return null;
        },
        onSaved: (text) => onSaved(parse(text)!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text('手动调节 · ${widget.difficulty.label}'),
        content: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _number(
                  label: '连点次数',
                  initial: '${widget.tuning.taps}',
                  onSaved: (value) => _taps = value),
              _number(
                  label: '滑动距离（逻辑像素）',
                  initial: '${widget.tuning.swipeDistance}',
                  onSaved: (value) => _swipe = value),
              _number(
                  label: '长按时长（秒）',
                  initial: _seconds(widget.tuning.holdTime),
                  seconds: true,
                  delay: true,
                  onSaved: (value) => _holdMs = value),
              _number(
                  label: '连点最大间隔（毫秒）',
                  initial: '${widget.tuning.tapGap.inMilliseconds}',
                  delay: true,
                  onSaved: (value) => _tapGap = value),
              _number(
                  label: '滑动最大停顿（毫秒）',
                  initial: '${widget.tuning.swipeGap.inMilliseconds}',
                  delay: true,
                  onSaved: (value) => _swipeGap = value),
            ])),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, (value: null as EffortTuning?)),
              child: const Text('恢复此档默认')),
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: _save, child: const Text('应用')),
        ],
      );
}
