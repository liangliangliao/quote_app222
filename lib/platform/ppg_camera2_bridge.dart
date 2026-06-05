import 'dart:async';

import 'package:flutter/services.dart';

/// Android Camera2 PPG bridge (with optional Flutter texture preview).
///
/// Streams ROI mean values (y/u/v + derived g/r) from native Camera2.
///
/// Channel names must match the Android implementation.
class PpgCamera2Bridge {
  static const MethodChannel _mc = MethodChannel('com.example.quote_app/ppg_camera2');
  static const EventChannel _ec = EventChannel('com.example.quote_app/ppg_camera2_stream');

  static Stream<Map<String, dynamic>>? _cached;

  static Future<bool> isSupported() async {
    try {
      final r = await _mc.invokeMethod('isSupported');
      return r == true;
    } catch (_) {
      return false;
    }
  }

  /// Start Camera2 streaming.
  ///
  /// Returns a config map: width/height/fpsLower/fpsUpper/torch/textureId.
  ///
  /// - textureId: Flutter texture id for camera preview (may be null if not supported).
  static Future<Map<String, dynamic>> start({
    int width = 640,
    int height = 480,
    int fps = 30,
    bool torch = true,
  }) async {
    final r = await _mc.invokeMethod('start', {
      'width': width,
      'height': height,
      'fps': fps,
      'torch': torch,
    });
    if (r is Map) {
      return r.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  static Future<void> stop() async {
    try {
      await _mc.invokeMethod('stop');
    } catch (_) {
      // ignore
    }
  }

  static Stream<Map<String, dynamic>> frames() {
    _cached ??= _ec.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    });
    return _cached!;
  }
}
