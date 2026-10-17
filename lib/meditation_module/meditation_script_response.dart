import 'dart:convert';

import 'meditation_duration_planner.dart';
import 'meditation_mentor_guidance.dart';
import 'meditation_models.dart';

class NormalizedMeditationScript {
  final Map<String, dynamic> script;
  final List<String> corrections;
  final MeditationDurationPlan? durationPlan;

  const NormalizedMeditationScript(this.script, this.corrections,
      {this.durationPlan});
}

/// Recover presentation and scheduling fields without inventing narration.
/// Content and stage validation still runs on the resulting script.
class MeditationScriptResponse {
  static NormalizedMeditationScript? read(String raw,
      {required int durationSeconds}) {
    final corrections = <String>{};
    final decoded = decodeObject(raw);
    final Map<String, dynamic> script;
    if (decoded != null) {
      script = Map<String, dynamic>.from(decoded);
    } else {
      final prose = _plainNarration(raw);
      if (prose == null) return null;
      script = {
        'segments': [
          {'text': prose}
        ]
      };
      corrections.add('plain_text_narration');
    }
    MeditationDurationPlan? durationPlan;
    if (script['duration_minutes'] != durationSeconds ~/ 60) {
      script['duration_minutes'] = durationSeconds ~/ 60;
      corrections.add('duration_from_user_selection');
    }

    var original = script['segments'] ?? script['steps'];
    if (original is! List || original.isEmpty) {
      final prose = _firstText([
        if (original is String) original,
        script['narration'],
        script['script'],
        script['content'],
        script['guide'],
        script['text'],
      ]);
      if (prose != null) {
        original = [
          {'text': prose}
        ];
        corrections.add('narration_field');
      }
    }
    if (original is! List)
      return NormalizedMeditationScript(script, corrections.toList());
    final segments = <dynamic>[];
    var cursor = 0;
    for (final item in original) {
      final Map<String, dynamic> segment;
      if (item is String) {
        segment = {'text': item};
        corrections.add('string_segment');
      } else if (item is Map) {
        segment = Map<String, dynamic>.from(item);
      } else {
        corrections.add('empty_or_non_text_segments');
        continue;
      }
      final rawPhase = '${segment['phase'] ?? ''}'.trim().toLowerCase();
      final phase = rawPhase.isEmpty ? 'practice' : rawPhase;
      segment['phase'] = phase;
      if (rawPhase.isEmpty) corrections.add('optional_phase');
      final text =
          _firstText([segment['text'], segment['content'], segment['guide']]);
      if (text == null) {
        corrections.add('empty_or_non_text_segments');
        continue;
      }
      final intent = '${segment['intent'] ?? ''}'.trim();
      if (intent.isEmpty) {
        segment['intent'] = phase;
        corrections.add('optional_intent');
      }
      final rawPause = segment['pause_after_seconds'] ??
          segment['pauseAfterSeconds'] ??
          segment['pause_seconds'] ??
          segment['pause'];
      final parsedPause = _seconds(rawPause);
      final minimumPause = durationSeconds <= 120 ? 1 : 4;
      final defaultPause = durationSeconds <= 120
          ? 1
          : [
              'body_emotion',
              'allow_experience',
              'embodied_shift',
              'real_life_rehearsal'
            ].contains(phase)
              ? 8
              : 4;
      final pause = parsedPause == null || parsedPause <= 0
          ? defaultPause
          : parsedPause.clamp(minimumPause, 30).toInt();
      if (rawPause != pause) corrections.add('experience_pauses');
      final start = _seconds(segment['start_seconds'] ??
              segment['startSecond'] ??
              segment['start']) ??
          cursor;
      final beats = _shortBeats(text.trim(), durationSeconds <= 120 ? 55 : 85);
      if (beats.length > 1) corrections.add('short_beats');
      var beatStart = start;
      for (var i = 0; i < beats.length; i++) {
        // A formatting split is not a new full experience task. Keep a short
        // pause here and preserve the original task's pause on its final beat.
        final beatPause = i == beats.length - 1 ? pause : minimumPause;
        segments.add({
          ...segment,
          'text': beats[i],
          'start_seconds': beatStart,
          'pause_after_seconds': beatPause,
        });
        beatStart +=
            MeditationMentorGuidance.speechSeconds(beats[i]) + beatPause;
      }
      cursor = beatStart;
    }
    script['segments'] = segments;

    if (segments.isNotEmpty &&
        segments.every((s) =>
            s is Map &&
            s['text'] is String &&
            (s['text'] as String).trim().isNotEmpty &&
            s['pause_after_seconds'] is int)) {
      final steps = segments
          .map((s) => MeditationStep(
                startSecond: s['start_seconds'] as int,
                text: s['text'] as String,
                pauseAfterSeconds: s['pause_after_seconds'] as int,
                intent: '${s['phase']}',
              ))
          .toList();
      durationPlan = MeditationDurationPlanner.plan(steps, durationSeconds);
      if (durationPlan.pausesAdjusted)
        corrections.add('pause_budget_calibration');
      if (durationPlan.exceedsTarget)
        corrections.add('complete_version_duration');
      final scheduled = durationPlan.steps;
      for (var i = 0; i < scheduled.length; i++) {
        if (segments[i]['start_seconds'] != scheduled[i].startSecond)
          corrections.add('speech_and_silence_timeline');
        segments[i]['start_seconds'] = scheduled[i].startSecond;
        segments[i]['pause_after_seconds'] = scheduled[i].pauseAfterSeconds;
      }
    }

    final design = script['experience_design'];
    if (design is Map) {
      void useDesign(String field, String designField) {
        if ((script[field] == null || '${script[field]}'.trim().isEmpty) &&
            design[designField] is String) {
          script[field] = design[designField];
          corrections.add('optional_metadata');
        }
      }

      useDesign('title', 'theme');
      useDesign('understood_need', 'theme');
      useDesign('embodied_goal', 'body_invitation');
      if (script['practice_focus'] is! List ||
          (script['practice_focus'] as List).isEmpty) {
        script['practice_focus'] = design['sensory_cues'] is List
            ? List.of(design['sensory_cues'])
            : <String>[];
        corrections.add('optional_metadata');
      }
    }
    if (_firstText([script['title']]) == null) {
      script['title'] = '本次冥想引导';
      corrections.add('optional_metadata');
    }
    if (_firstText([script['type']]) == null) {
      script['type'] = '体验式冥想';
      corrections.add('optional_metadata');
    }
    if ((script['ending_reflection'] == null ||
            '${script['ending_reflection']}'.trim().isEmpty) &&
        segments.isNotEmpty &&
        segments.last is Map &&
        segments.last['phase'] == 'closing') {
      script['ending_reflection'] = segments.last['text'];
      corrections.add('optional_metadata');
    }
    return NormalizedMeditationScript(script, corrections.toList(),
        durationPlan: durationPlan);
  }

  static String? _firstText(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  // Preserve prose without requiring JSON, but never read broken JSON or an
  // HTML gateway error aloud as a meditation. No model repair is requested.
  static String? _plainNarration(String raw, [int depth = 0]) {
    if (depth > 3) return null;
    final text = raw
        .trim()
        .replaceFirst(
            RegExp(r'^```(?:json|text|markdown)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is String ? _plainNarration(decoded, depth + 1) : null;
    } on FormatException {
      if (RegExp(r'^[\{\[\"]|^```|^<(?:!doctype|html|head|body)\b',
              caseSensitive: false)
          .hasMatch(text)) {
        return null;
      }
      return text;
    }
  }

  static Map<String, dynamic>? decodeObject(String raw, [int depth = 0]) {
    if (depth > 3) return null;
    final stripped = raw
        .trim()
        .replaceFirst(RegExp(r'^\uFEFF'), '')
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
    final candidates = <String>[stripped];
    for (final match
        in RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
            .allMatches(raw)) {
      candidates.add(match.group(1)!);
    }
    final start = stripped.indexOf('{');
    final end = stripped.lastIndexOf('}');
    if (start >= 0 && end > start)
      candidates.add(stripped.substring(start, end + 1));
    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is String) {
          final nested = decodeObject(decoded, depth + 1);
          if (nested != null) return nested;
        }
      } on FormatException {
        // Try only recognized JSON wrappers; do not replace escaped characters.
      }
    }
    return null;
  }

  static int? _seconds(dynamic value) {
    if (value is num && value.isFinite) return value.round();
    if (value is! String) return null;
    final text = value.trim();
    final mmss = RegExp(r'^(\d{1,3}):(\d{2})$').firstMatch(text);
    if (mmss != null) return int.parse(mmss[1]!) * 60 + int.parse(mmss[2]!);
    final seconds = RegExp(r'^(?:停顿|停留)?\s*(\d+(?:\.\d+)?)\s*(?:s|秒)?$',
            caseSensitive: false)
        .firstMatch(text);
    return seconds == null ? null : double.tryParse(seconds[1]!)?.round();
  }

  static List<String> _shortBeats(String text, int limit) {
    if (text.replaceAll(RegExp(r'\s'), '').length <= limit) return [text];
    List<String> units(String source, String punctuation) {
      final result = <String>[];
      var start = 0;
      for (var i = 0; i < source.length; i++) {
        if (!punctuation.contains(source[i])) continue;
        while (i + 1 < source.length && '”’」』）)'.contains(source[i + 1])) i++;
        result.add(source.substring(start, i + 1));
        start = i + 1;
      }
      if (start < source.length) result.add(source.substring(start));
      return result;
    }

    final sentences = units(text, '。！？!?；;\n');
    final pieces = <String>[];
    for (final sentence in sentences) {
      pieces.addAll(sentence.replaceAll(RegExp(r'\s'), '').length > limit
          ? units(sentence, '，,')
          : [sentence]);
    }
    final beats = <String>[];
    var current = '';
    for (final piece in pieces) {
      if ((current + piece).replaceAll(RegExp(r'\s'), '').length > limit &&
          current.trim().isNotEmpty) {
        beats.add(current.trim());
        current = '';
      }
      current += piece;
    }
    if (current.trim().isNotEmpty) beats.add(current.trim());
    return beats;
  }
}
