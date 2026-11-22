import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

enum TouchGesture {
  tap('点击'),
  hold('长按'),
  swipe('滑动');

  const TouchGesture(this.label);
  final String label;
}

enum EffortDifficulty {
  easy('简单', 3, 100, Duration(milliseconds: 900)),
  standard('标准', 5, 220, Duration(milliseconds: 1500)),
  hard('困难', 8, 360, Duration(milliseconds: 2400));

  const EffortDifficulty(
      this.label, this.taps, this.swipeDistance, this.holdTime);

  final String label;
  final int taps;
  final double swipeDistance;
  final Duration holdTime;

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
}

class TouchEffort extends ValueNotifier<EffortProgress> {
  TouchEffort(this.difficulty, TickerProvider vsync)
      : _hold = AnimationController(
            vsync: vsync, animationBehavior: AnimationBehavior.preserve),
        super(const EffortProgress()) {
    _hold.addListener(() {
      if (value.gesture != TouchGesture.hold || value.reached) return;
      // The deadline, rather than the paint clock, authorizes feedback.
      value = EffortProgress(
          gesture: TouchGesture.hold, value: _hold.value.clamp(0, 0.999));
    });
  }

  static const tapGap = Duration(milliseconds: 650);
  static const swipeGap = Duration(milliseconds: 360);
  static const _resultTime = Duration(milliseconds: 900);

  final EffortDifficulty difficulty;
  final AnimationController _hold;
  Timer? _deadline;
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
    return _add(TouchGesture.tap, _tapCount / difficulty.taps, tapGap);
  }

  void hold(Duration alreadyHeld, VoidCallback onReached) {
    reset();
    _hold.duration = difficulty.holdTime;
    final start =
        alreadyHeld.inMicroseconds / difficulty.holdTime.inMicroseconds;
    value = EffortProgress(gesture: TouchGesture.hold, value: start);
    _hold.forward(from: start);
    _deadline = Timer(difficulty.holdTime - alreadyHeld, () {
      _finish(TouchGesture.hold);
      onReached();
    });
  }

  bool swipe(double distance) {
    _swipeDistance += distance;
    return _add(TouchGesture.swipe, _swipeDistance / difficulty.swipeDistance,
        swipeGap);
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
    _hold.stop();
    value = EffortProgress(gesture: gesture, value: 1);
    _setDeadline(_resultTime);
  }

  void _setDeadline(Duration duration) {
    _deadline?.cancel();
    _deadline = Timer(duration, reset);
  }

  void reset() {
    _deadline?.cancel();
    _hold.stop();
    _tapRegion = null;
    _tapCount = 0;
    _swipeDistance = 0;
    if (value.gesture != null) value = const EffortProgress();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _hold.dispose();
    super.dispose();
  }
}
