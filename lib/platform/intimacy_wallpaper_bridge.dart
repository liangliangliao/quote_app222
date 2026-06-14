import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class IntimacyWallpaperBridge {
  static const MethodChannel _channel = MethodChannel('com.example.quote_app/intimacy_wallpaper');

  static bool get isAndroid => Platform.isAndroid;

  static Future<bool> saveConfig({
    required int style,
    required String wallpaperMode,
    required String calligraphyText,
    required String calligraphyStyle,
    required double calligraphySpeed,
    required String calligraphyStrokeData,
    required String calligraphyPlaylist,
    required String calligraphyAiHistory,
    required double intimacy,
    required double randomness,
    required double ribbonWidth,
    required double trail,
    required double fullScreenCoverage,
    required double strokeDensity,
    required bool previewAccelerated,
    required double previewCycleMinutes,
    required bool debugLoopEnabled,
    required double debugCycleMinutes,
    required bool bubbles,
    required bool powerSave,
    required bool randomCycle,
    required double cycleMinDays,
    required double cycleMaxDays,
    required double fixedCycleDays,
    required double ratioSeparation,
    required double ratioAttraction,
    required double ratioSync,
    required double ratioCritical,
    required double ratioRelease,
    required double ratioAfterglow,
    required double criticalMinSec,
    required double criticalMaxSec,
    required double releaseMinSec,
    required double releaseMaxSec,
    required double afterglowMinSec,
    required double afterglowMaxSec,
    bool resetSeed = true,
  }) async {
    if (!isAndroid) return false;
    final ok = await _channel.invokeMethod<bool>('saveConfig', <String, dynamic>{
      'style': style,
      'wallpaperMode': wallpaperMode,
      'calligraphyText': calligraphyText,
      'calligraphyStyle': calligraphyStyle,
      'calligraphySpeed': calligraphySpeed,
      'calligraphyStrokeData': calligraphyStrokeData,
      'calligraphyPlaylist': calligraphyPlaylist,
      'calligraphyAiHistory': calligraphyAiHistory,
      'intimacy': intimacy,
      'randomness': randomness,
      'ribbonWidth': ribbonWidth,
      'trail': trail,
      'fullScreenCoverage': fullScreenCoverage,
      'strokeDensity': strokeDensity,
      'previewAccelerated': previewAccelerated,
      'previewCycleMinutes': previewCycleMinutes,
      'debugLoopEnabled': debugLoopEnabled,
      'debugCycleMinutes': debugCycleMinutes,
      'bubbles': bubbles,
      'powerSave': powerSave,
      'randomCycle': randomCycle,
      'cycleMinDays': cycleMinDays,
      'cycleMaxDays': cycleMaxDays,
      'fixedCycleDays': fixedCycleDays,
      'ratioSeparation': ratioSeparation,
      'ratioAttraction': ratioAttraction,
      'ratioSync': ratioSync,
      'ratioCritical': ratioCritical,
      'ratioRelease': ratioRelease,
      'ratioAfterglow': ratioAfterglow,
      'criticalMinSec': criticalMinSec,
      'criticalMaxSec': criticalMaxSec,
      'releaseMinSec': releaseMinSec,
      'releaseMaxSec': releaseMaxSec,
      'afterglowMinSec': afterglowMinSec,
      'afterglowMaxSec': afterglowMaxSec,
      'resetSeed': resetSeed,
    });
    return ok == true;
  }

  static Future<Map<String, dynamic>> getConfig() async {
    if (!isAndroid) return <String, dynamic>{};
    try {
      return await _channel.invokeMapMethod<String, dynamic>('getConfig') ??
          <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<bool> setLiveWallpaperDirect() async {
    if (!isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setLiveWallpaperDirect');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openLiveWallpaper() async {
    if (!isAndroid) return false;
    final ok = await _channel.invokeMethod<bool>('openLiveWallpaper');
    return ok == true;
  }


  static Future<bool> isLiveWallpaperApplied() async {
    if (!isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('isLiveWallpaperApplied');
      return ok == true;
    } catch (_) {
      return false;
    }
  }
  static Future<Map<String, dynamic>> getLiveWallpaperDiagnostic() async {
    if (!isAndroid) return <String, dynamic>{'isAndroid': false};
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('getLiveWallpaperDiagnostic');
      return data ?? <String, dynamic>{};
    } catch (e) {
      return <String, dynamic>{'error': e.toString()};
    }
  }

  static Future<bool> isSupported() async {
    if (!isAndroid) return false;
    final ok = await _channel.invokeMethod<bool>('isSupported');
    return ok == true;
  }
}
