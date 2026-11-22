import 'dart:async';

import 'package:flutter/foundation.dart';

enum TouchGesture {
  tap('点击'),
  hold('长按'),
  swipe('滑动');

  const TouchGesture(this.label);
  final String label;
}

class EffortTuning {
  const EffortTuning({
    required this.taps,
    required this.swipeDistance,
    required this.holdTime,
    this.tapGap = const Duration(milliseconds: 650),
    this.swipeGap = const Duration(milliseconds: 360),
  });

  final int taps;
  final int swipeDistance;
  final Duration holdTime;
  final Duration tapGap;
  final Duration swipeGap;

  // Keep converted inputs in the millisecond range of a signed 32-bit delay.
  static const maxDelayMilliseconds = 2147483647;

  static EffortTuning? fromStored(Object? value, EffortTuning preset) {
    if (value is! Map) return null;
    return EffortTuning(
      taps: _positiveInt(value['taps']) ?? preset.taps,
      swipeDistance:
          _positiveInt(value['swipeDistance']) ?? preset.swipeDistance,
      holdTime: _delay(value['holdMilliseconds']) ?? preset.holdTime,
      tapGap: _delay(value['tapGapMilliseconds']) ?? preset.tapGap,
      swipeGap: _delay(value['swipeGapMilliseconds']) ?? preset.swipeGap,
    );
  }

  static int? _positiveInt(Object? value) =>
      value is int && value > 0 ? value : null;

  static Duration? _delay(Object? value) =>
      value is int && value > 0 && value <= maxDelayMilliseconds
          ? Duration(milliseconds: value)
          : null;

  Map<String, int> toJson() => {
        'taps': taps,
        'swipeDistance': swipeDistance,
        'holdMilliseconds': holdTime.inMilliseconds,
        'tapGapMilliseconds': tapGap.inMilliseconds,
        'swipeGapMilliseconds': swipeGap.inMilliseconds,
      };
}

enum EffortDifficulty {
  easy('简单', 3, 100, 900, 1),
  standard('标准', 5, 220, 1500, 30),
  hard('困难', 8, 360, 2400, 30),
  veryHard('非常困难', 8, 360, 2400, 30 * 100),
  extreme('极端困难', 8, 360, 2400, 30 * 500);

  const EffortDifficulty(this.label, int taps, int swipeDistance,
      int holdMilliseconds, int multiplier)
      : _taps = taps * multiplier,
        _swipeDistance = swipeDistance * multiplier,
        _holdMilliseconds = holdMilliseconds * multiplier;

  final String label;
  final int _taps;
  final int _swipeDistance;
  final int _holdMilliseconds;

  EffortTuning get preset => EffortTuning(
        taps: _taps,
        swipeDistance: _swipeDistance,
        holdTime: Duration(milliseconds: _holdMilliseconds),
      );

  static EffortDifficulty fromStored(Object? name) =>
      values.where((difficulty) => difficulty.name == name).firstOrNull ??
      standard;
}

class EffortProgress {
  const EffortProgress({this.gesture, this.value = 0});

  final TouchGesture? gesture;
  final double value;

  bool get reached => value == 1;
  int get percent => (value * 100).floor();

  String get percentLabel {
    if (value > 0 && value < 0.01) {
      final thousandths = (value * 100000).floor();
      return thousandths == 0
          ? '<0.001%'
          : '${(thousandths / 1000).toStringAsFixed(3)}%';
    }
    return '$percent%';
  }
}

class TouchEffort extends ValueNotifier<EffortProgress> {
  TouchEffort(this.difficulty, {EffortTuning? tuning})
      : tuning = tuning ?? difficulty.preset,
        super(const EffortProgress());

  static const _resultTime = Duration(milliseconds: 900);

  final EffortDifficulty difficulty;
  final EffortTuning tuning;
  Timer? _deadline;
  Timer? _holdUpdates;
  String? _tapRegion;
  int _tapCount = 0;
  double _swipeDistance = 0;

  void beginPointer(String? tapRegion) {
    if (value.gesture != TouchGesture.tap ||
        value.reached ||
        tapRegion != _tapRegion) {
      reset();
    }
  }

  bool tap(String regionId) {
    if (_tapRegion != regionId || value.reached) reset();
    _tapRegion = regionId;
    _tapCount++;
    return _add(TouchGesture.tap, _tapCount / tuning.taps, tuning.tapGap);
  }

  void hold(Duration alreadyHeld, VoidCallback onReached) {
    reset();
    final goal = tuning.holdTime.inMicroseconds;
    if (alreadyHeld >= tuning.holdTime) {
      _finish(TouchGesture.hold);
      onReached();
      return;
    }
    value = EffortProgress(
        gesture: TouchGesture.hold, value: alreadyHeld.inMicroseconds / goal);
    // Sample multi-hour holds more slowly while the deadline remains exact.
    final interval = Duration(
        milliseconds: (tuning.holdTime.inMilliseconds ~/ 4000).clamp(24, 750));
    _holdUpdates = Timer.periodic(interval, (timer) {
      final elapsed = alreadyHeld + interval * timer.tick;
      value = EffortProgress(
          gesture: TouchGesture.hold,
          value: (elapsed.inMicroseconds / goal).clamp(0.0, 0.99999));
    });
    _deadline = Timer(tuning.holdTime - alreadyHeld, () {
      _finish(TouchGesture.hold);
      onReached();
    });
  }

  bool swipe(double distance) {
    _swipeDistance += distance;
    return _add(TouchGesture.swipe, _swipeDistance / tuning.swipeDistance,
        tuning.swipeGap);
  }

  bool _add(TouchGesture gesture, double progress, Duration gap) {
    if (progress >= 1) {
      _finish(gesture);
      return true;
    }
    value = EffortProgress(gesture: gesture, value: progress);
    _setDeadline(gap);
    return false;
  }

  void _finish(TouchGesture gesture) {
    _holdUpdates?.cancel();
    value = EffortProgress(gesture: gesture, value: 1);
    _setDeadline(_resultTime);
  }

  void _setDeadline(Duration duration) {
    _deadline?.cancel();
    _deadline = Timer(duration, reset);
  }

  void reset() {
    _deadline?.cancel();
    _holdUpdates?.cancel();
    _tapRegion = null;
    _tapCount = 0;
    _swipeDistance = 0;
    if (value.gesture != null) value = const EffortProgress();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _holdUpdates?.cancel();
    super.dispose();
  }
}
