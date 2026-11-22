import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'feedback.dart';

const _channel = MethodChannel('com.example.quote_app/interactive_feedback');
const _voice = EventChannel('com.example.quote_app/interactive_feedback/voice');

class InstalledFeedbackApp {
  const InstalledFeedbackApp(this.name, this.package);
  final String name;
  final String package;
}

class FeedbackPlatform {
  const FeedbackPlatform();

  Future<List<InstalledFeedbackApp>> apps() async {
    if (!Platform.isAndroid) return const [];
    final installed =
        await _channel.invokeListMethod<Map<Object?, Object?>>('apps') ??
            const [];
    return [
      for (final app in installed)
        InstalledFeedbackApp(app['name'] as String, app['package'] as String)
    ];
  }

  Future<FeedbackStep?> pickMedia(String artworkId, TouchAction action,
      {required bool gallery}) async {
    final selection =
        await _channel.invokeMapMethod<String, String>('pickMedia', {
      'artworkId': artworkId,
      'kind': action.name,
      'gallery': gallery,
    });
    return selection == null
        ? null
        : FeedbackStep(action,
            value: selection['file'], name: selection['name']);
  }

  Future<bool> playMedia(String artworkId, FeedbackStep step,
          {bool muted = false}) async =>
      await _channel.invokeMethod<bool>('playMedia', {
        'artworkId': artworkId,
        'kind': step.action.name,
        'value': step.value,
        'muted': muted,
      }) ??
      false;

  Future<void> stopMedia() => _channel.invokeMethod<void>('stopMedia');

  Future<void> setImmersive(bool enabled) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('setImmersive', enabled);
    }
  }

  Future<void> setHoldScreenOn(bool enabled) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('setHoldScreenOn', enabled);
    }
  }

  Future<void> openLink(Uri uri) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('openLink', uri.toString());
    } else if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw PlatformException(code: 'browser_missing');
    }
  }

  Future<void> openApp(FeedbackStep step) =>
      _channel.invokeMethod<void>('openApp', {
        'name': step.name,
        'package': step.value,
      });

  Stream<dynamic> get voiceEvents => _voice.receiveBroadcastStream();

  Future<void> startVoice({required bool allowSystemSpeech}) =>
      _channel.invokeMethod<void>('startVoice', allowSystemSpeech);

  Future<void> stopVoice() => _channel.invokeMethod<void>('stopVoice');
}
