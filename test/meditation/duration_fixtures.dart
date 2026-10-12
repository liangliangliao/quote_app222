import 'dart:convert';

import 'package:quote_app/meditation_module/meditation_mentor_guidance.dart';
import 'package:quote_app/meditation_module/meditation_script_response.dart';

import 'response_recovery_test.dart' show cognitiveChangeScript;

// A deliberately long controlled response, not the device's original script.
// All pauses are already at the planner's protected experience floors.
Map<String, dynamic> timedCognitiveChangeScript(int seconds) {
  final script = MeditationScriptResponse.read(
          jsonEncode(cognitiveChangeScript()),
          durationSeconds: 480)!
      .script;
  final segments = script['segments'] as List;
  const core = [
    'body_emotion',
    'allow_experience',
    'embodied_shift',
    'real_life_rehearsal'
  ];
  for (final segment in segments) {
    segment['pause_after_seconds'] = core.contains(segment['phase']) ? 8 : 4;
  }
  int requiredSeconds() => segments.fold<int>(
      0,
      (sum, segment) =>
          sum +
          MeditationMentorGuidance.speechSeconds(segment['text'] as String) +
          (segment['pause_after_seconds'] as int));
  var index = 0;
  void addBodyBeat(String text) {
    segments
        .insert(segments.indexWhere((s) => s['phase'] == 'allow_experience'), {
      'phase': 'body_emotion',
      'intent': '观察实际反应',
      'start_seconds': 0,
      'text': text,
      'pause_after_seconds': 8,
    });
  }

  while (seconds - requiredSeconds() > 30) {
    addBodyBeat('留意手掌的触感，再听听周围的声音（第${++index}处触点）。');
  }
  final remaining = seconds - requiredSeconds();
  if (remaining > 0) {
    final speech = remaining - 8;
    var text = '再留意手掌触感';
    const detail = '，感受此刻的支撑';
    var character = 0;
    while (MeditationMentorGuidance.speechSeconds(text) < speech) {
      text += detail[character++ % detail.length];
    }
    if (MeditationMentorGuidance.speechSeconds(text) != speech ||
        text.length > 85) {
      throw StateError('Fixture cannot fit the requested budget');
    }
    addBodyBeat(text);
  }
  if (requiredSeconds() != seconds)
    throw StateError('Incorrect fixture budget');
  return script;
}
