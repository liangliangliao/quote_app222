import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quote_app/meditation_module/meditation_audio_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  late Completer<dynamic> finished;
  late Completer<void> started;
  late List<MethodCall> calls;

  setUp(() {
    finished = Completer<dynamic>();
    started = Completer<void>();
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      if (call.method == 'speak') {
        started.complete();
        return finished.future;
      }
      return 1;
    });
  });

  tearDown(() {
    if (!finished.isCompleted) finished.complete(0);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('系统朗读等待真实完成，再交还给体验停顿', () async {
    final service = MeditationAudioService();
    var returned = false;
    final speaking = service
        .speakWithSystemTts('留意手掌的真实触感。', awaitCompletion: true)
        .then((_) => returned = true);
    await started.future;
    expect(returned, isFalse);
    expect(
        calls
            .firstWhere((call) => call.method == 'awaitSpeakCompletion')
            .arguments,
        isTrue);
    finished.complete(1);
    await speaking;
    expect(returned, isTrue);
  });

  test('原生引擎只回报错误时，等待能退出而不会卡在当前段', () async {
    final service = MeditationAudioService();
    final speaking =
        service.speakWithSystemTts('留意手掌的真实触感。', awaitCompletion: true);
    final expectation = expectLater(speaking, throwsStateError);
    await started.future;
    final acknowledged = Completer<void>();
    binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter_tts',
      const StandardMethodCodec().encodeMethodCall(
          const MethodCall('speak.onError', 'voice unavailable')),
      (_) => acknowledged.complete(),
    );
    await acknowledged.future;
    await expectation;
  });
}
