import 'dart:convert';
import 'dart:math' as math;

import 'meditation_models.dart';

class MeditationScriptBuildOptions {
  final int targetDurationMinutes;
  final String meditationType;
  final String pauseStyle;
  final String processMode;

  const MeditationScriptBuildOptions({
    required this.targetDurationMinutes,
    required this.meditationType,
    required this.pauseStyle,
    required this.processMode,
  });

  int get targetSeconds => targetDurationMinutes.clamp(8, 180).toInt() * 60;
}

class _ScriptSegmentDraft {
  final String text;
  final int pauseAfterSeconds;
  final String intent;

  const _ScriptSegmentDraft({
    required this.text,
    required this.pauseAfterSeconds,
    required this.intent,
  });

  _ScriptSegmentDraft copyWith({int? pauseAfterSeconds}) => _ScriptSegmentDraft(
        text: text,
        pauseAfterSeconds: pauseAfterSeconds ?? this.pauseAfterSeconds,
        intent: intent,
      );
}

class MeditationScriptPausePlanner {
  static MeditationSessionTemplate buildLocal({
    required String rawText,
    required String fileName,
    required MeditationScriptBuildOptions options,
  }) {
    final raw = _normalizeRaw(rawText);
    if (raw.isEmpty) {
      throw const FormatException('脚本内容为空');
    }
    final jsonSession = _tryParseJson(raw, fileName, options);
    if (jsonSession != null) return jsonSession;

    final titleAndBody = _extractTitleAndBody(raw, fileName);
    final drafts = _draftsFromText(titleAndBody.body, options);
    return _sessionFromDrafts(
      title: titleAndBody.title,
      fileName: fileName,
      sourceDescription: options.processMode == 'preserve'
          ? '保留原文并插入系统可识别停顿，按目标时长自动校准。'
          : '轻微整理原文并插入系统可识别停顿，按目标时长自动校准。',
      type: options.meditationType.trim().isEmpty ? _guessType(raw) : options.meditationType.trim(),
      drafts: drafts,
      options: options,
      source: 'local_imported',
    );
  }

  static MeditationSessionTemplate? buildFromAiOutput({
    required String aiRaw,
    required String originalRawText,
    required String fileName,
    required MeditationScriptBuildOptions options,
  }) {
    final raw = aiRaw.trim();
    if (raw.isEmpty) return null;
    final json = _tryParseJson(raw, fileName, options);
    if (json != null) {
      return json.copyWith(
        key: 'local_script_${DateTime.now().millisecondsSinceEpoch}',
        source: 'local_imported',
        description: 'AI 保留原脚本主体内容，仅做轻微断句与停顿标注，时长约 ${json.durationMinutes} 分钟。',
      );
    }

    final titleAndBody = _extractTitleAndBody(originalRawText, fileName);
    final drafts = _draftsFromText(raw, options);
    if (drafts.isEmpty) return null;
    return _sessionFromDrafts(
      title: _guessAiTitle(raw, titleAndBody.title),
      fileName: fileName,
      sourceDescription: 'AI 保留原脚本主体内容，仅做轻微断句与停顿标注，按目标时长自动校准。',
      type: options.meditationType.trim().isEmpty ? _guessType(originalRawText) : options.meditationType.trim(),
      drafts: drafts,
      options: options,
      source: 'local_imported',
    );
  }

  static MeditationSessionTemplate _sessionFromDrafts({
    required String title,
    required String fileName,
    required String sourceDescription,
    required String type,
    required List<_ScriptSegmentDraft> drafts,
    required MeditationScriptBuildOptions options,
    required String source,
  }) {
    final safeDrafts = drafts.isEmpty
        ? <_ScriptSegmentDraft>[
            const _ScriptSegmentDraft(text: '现在，先坐下来，感受身体和呼吸。', pauseAfterSeconds: 8, intent: 'settling'),
            const _ScriptSegmentDraft(text: '如果走神了，不用责备自己。看见它，然后回来。', pauseAfterSeconds: 10, intent: 'grounding'),
          ]
        : drafts;
    final calibrated = _calibratePauses(safeDrafts, options);
    final steps = <MeditationStep>[];
    var cursor = 0;
    for (final draft in calibrated) {
      steps.add(MeditationStep(
        startSecond: cursor,
        text: draft.text,
        pauseAfterSeconds: draft.pauseAfterSeconds,
        intent: draft.intent,
      ));
      cursor += _estimateSpeechSeconds(draft.text, options) + draft.pauseAfterSeconds;
    }
    final duration = math.max(options.targetSeconds, cursor).clamp(60, 24 * 60 * 60).toInt();
    return MeditationSessionTemplate(
      key: 'local_script_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? _cleanFileTitle(fileName) : title.trim(),
      type: type.trim().isEmpty ? '本地脚本' : type.trim(),
      category: '本地上传',
      description: '$sourceDescription 目标 ${options.targetDurationMinutes} 分钟，实际约 ${(duration / 60).round()} 分钟。',
      durationSeconds: duration,
      steps: steps,
      endingReflection: '你已经跟随自己的脚本完成了一次带停顿的静心练习。',
      isSleep: type.contains('睡') || title.contains('睡'),
      source: source,
    );
  }

  static List<_ScriptSegmentDraft> _draftsFromText(String rawText, MeditationScriptBuildOptions options) {
    final manual = _parseManualPauseText(rawText, options);
    if (manual.isNotEmpty) return manual;
    var body = _stripCodeFence(rawText)
        .replaceAll(RegExp(r'(?m)^\s*[-*#>]+\s*'), '')
        .replaceAll(RegExp(r'(?i)duration\s*[:：]\s*\d+\s*(min|m|分钟)?'), '')
        .replaceAll(RegExp(r'(?m)^\s*时长\s*[:：].*$'), '')
        .trim();
    if (options.processMode == 'light') {
      body = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    final sentences = _splitIntoGuideSentences(body);
    return sentences.map((s) {
      final intent = _classifyIntent(s);
      return _ScriptSegmentDraft(
        text: s,
        pauseAfterSeconds: _basePauseForIntent(intent, options.pauseStyle),
        intent: intent,
      );
    }).toList();
  }

  static List<_ScriptSegmentDraft> _parseManualPauseText(String rawText, MeditationScriptBuildOptions options) {
    final text = _stripCodeFence(rawText).trim();
    if (!RegExp(r'\[\s*pause\s+\d{1,3}\s*s\s*\]', caseSensitive: false).hasMatch(text)) {
      return const <_ScriptSegmentDraft>[];
    }
    final drafts = <_ScriptSegmentDraft>[];
    final buffer = StringBuffer();
    final pauseReg = RegExp(r'\[\s*pause\s+(\d{1,3})\s*s\s*\]', caseSensitive: false);
    final lines = text.split('\n');
    void flushWithPause(int pause) {
      final raw = buffer.toString().trim();
      buffer.clear();
      if (raw.isEmpty) return;
      final pieces = _splitIntoGuideSentences(raw);
      if (pieces.isEmpty) return;
      for (var i = 0; i < pieces.length; i++) {
        final intent = _classifyIntent(pieces[i]);
        drafts.add(_ScriptSegmentDraft(
          text: pieces[i],
          pauseAfterSeconds: i == pieces.length - 1 ? pause.clamp(0, 60).toInt() : _basePauseForIntent(intent, options.pauseStyle),
          intent: intent,
        ));
      }
    }

    for (final line in lines) {
      final match = pauseReg.firstMatch(line.trim());
      if (match != null && line.trim().replaceAll(pauseReg, '').trim().isEmpty) {
        flushWithPause(int.tryParse(match.group(1) ?? '') ?? _basePauseForIntent('normal', options.pauseStyle));
      } else {
        buffer.writeln(line);
      }
    }
    if (buffer.toString().trim().isNotEmpty) {
      flushWithPause(_basePauseForIntent('ending', options.pauseStyle));
    }
    return drafts;
  }

  static MeditationSessionTemplate? _tryParseJson(String raw, String fileName, MeditationScriptBuildOptions options) {
    try {
      final decoded = jsonDecode(_stripCodeFence(raw));
      if (decoded is! Map) return null;
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      final title = _cleanOneLine(map['title']?.toString()).isNotEmpty
          ? _cleanOneLine(map['title']?.toString())
          : _cleanFileTitle(fileName);
      final type = _cleanOneLine(map['type']?.toString()).isNotEmpty
          ? _cleanOneLine(map['type']?.toString())
          : options.meditationType;
      final rawSegments = map['segments'] ?? map['steps'];
      final drafts = <_ScriptSegmentDraft>[];
      if (rawSegments is List) {
        for (final item in rawSegments) {
          if (item is! Map) continue;
          final text = _cleanText(item['text'] ?? item['content'] ?? item['guide']);
          if (text.isEmpty) continue;
          final intent = _cleanOneLine(item['intent']?.toString()).isEmpty ? _classifyIntent(text) : _cleanOneLine(item['intent']?.toString());
          final pause = _readPause(item['pause_after_seconds'] ?? item['pauseAfterSeconds'] ?? item['pause'] ?? item['pause_seconds']) ?? _basePauseForIntent(intent, options.pauseStyle);
          drafts.add(_ScriptSegmentDraft(text: text, pauseAfterSeconds: pause.clamp(0, 60).toInt(), intent: intent));
        }
      }
      final fallback = (map['script_text'] ?? map['text'] ?? '').toString();
      final safeDrafts = drafts.isEmpty ? _draftsFromText(fallback.isEmpty ? raw : fallback, options) : drafts;
      return _sessionFromDrafts(
        title: title,
        fileName: fileName,
        sourceDescription: '根据脚本 JSON 字段生成带停顿冥想脚本。',
        type: type,
        drafts: safeDrafts,
        options: options,
        source: 'local_imported',
      );
    } catch (_) {
      return null;
    }
  }

  static List<_ScriptSegmentDraft> _calibratePauses(List<_ScriptSegmentDraft> drafts, MeditationScriptBuildOptions options) {
    final speechTotal = drafts.fold<int>(0, (sum, e) => sum + _estimateSpeechSeconds(e.text, options));
    final minPauses = drafts.map((e) => _minPauseForIntent(e.intent, options.pauseStyle)).toList();
    final basePauses = drafts.map((e) => e.pauseAfterSeconds <= 0 ? _basePauseForIntent(e.intent, options.pauseStyle) : e.pauseAfterSeconds).toList();
    final minTotal = minPauses.fold<int>(0, (a, b) => a + b);
    final baseTotal = basePauses.fold<int>(0, (a, b) => a + b);
    final targetPauseTotal = math.max(minTotal, options.targetSeconds - speechTotal);

    if (targetPauseTotal <= minTotal || baseTotal <= 0) {
      return List.generate(drafts.length, (i) => drafts[i].copyWith(pauseAfterSeconds: minPauses[i].clamp(0, 60).toInt()));
    }

    final scale = targetPauseTotal / baseTotal;
    return List.generate(drafts.length, (i) {
      final maxPause = _maxPauseForIntent(drafts[i].intent, options.pauseStyle);
      final next = (basePauses[i] * scale).round().clamp(minPauses[i], maxPause).toInt();
      return drafts[i].copyWith(pauseAfterSeconds: next);
    });
  }

  static int _estimateSpeechSeconds(String text, MeditationScriptBuildOptions options) {
    final chars = text.replaceAll(RegExp(r'\s+'), '').runes.length;
    final speed = options.meditationType.contains('睡') ? 2.45 : 2.85;
    return math.max(2, (chars / speed).ceil()).clamp(2, 180).toInt();
  }

  static int _basePauseForIntent(String intent, String style) {
    final mult = _styleMultiplier(style);
    final base = intent == 'breath'
        ? 8
        : intent == 'body_scan'
            ? 14
            : intent == 'emotion'
                ? 16
                : intent == 'acceptance'
                    ? 10
                    : intent == 'ending'
                        ? 20
                        : intent == 'settling'
                            ? 10
                            : 5;
    return math.max(1, (base * mult).round()).clamp(1, 60).toInt();
  }

  static int _minPauseForIntent(String intent, String style) {
    if (style.contains('较少')) return intent == 'normal' ? 1 : 2;
    return intent == 'normal' ? 2 : 4;
  }

  static int _maxPauseForIntent(String intent, String style) {
    if (style.contains('深度')) return 60;
    if (style.contains('较长')) return intent == 'normal' ? 18 : 45;
    if (style.contains('较少')) return intent == 'normal' ? 8 : 18;
    return intent == 'normal' ? 12 : 30;
  }

  static double _styleMultiplier(String style) {
    if (style.contains('较少')) return 0.65;
    if (style.contains('较长')) return 1.45;
    if (style.contains('深度')) return 2.0;
    return 1.0;
  }

  static String _classifyIntent(String text) {
    if (RegExp(r'吸气|呼气|呼吸|气息|深吸|吐气').hasMatch(text)) return 'breath';
    if (RegExp(r'身体|肩膀|胸口|腹部|双脚|脚底|脊柱|手|腿|背部|脸|下颌').hasMatch(text)) return 'body_scan';
    if (RegExp(r'情绪|感受|感觉|念头|思绪|心里|焦虑|紧张|羞耻|自责').hasMatch(text)) return 'emotion';
    if (RegExp(r'允许|接纳|没关系|不需要|不用|可以').hasMatch(text)) return 'acceptance';
    if (RegExp(r'开始|现在|坐下|安顿|闭上眼睛|闭眼').hasMatch(text)) return 'settling';
    if (RegExp(r'结束|带回|感谢|完成|慢慢睁开|睁开眼睛').hasMatch(text)) return 'ending';
    return 'normal';
  }

  static List<String> _splitIntoGuideSentences(String body) {
    final cleaned = body.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final out = <String>[];
    final buffer = StringBuffer();
    void flush() {
      final text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      buffer.clear();
      if (text.isEmpty) return;
      if (text.length > 70) {
        out.addAll(_splitLongSentence(text));
      } else {
        out.add(text);
      }
    }

    for (final rune in cleaned.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '\n') {
        final current = buffer.toString().trim();
        if (current.length >= 18) flush();
        continue;
      }
      buffer.write(ch);
      if ('。！？!?；;'.contains(ch)) flush();
    }
    flush();
    return out.where((e) => e.trim().isNotEmpty).toList();
  }

  static List<String> _splitLongSentence(String text) {
    final pieces = text.split(RegExp(r'[，,、：:]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (pieces.length <= 1) return <String>[text];
    final out = <String>[];
    final buffer = StringBuffer();
    for (final piece in pieces) {
      if (buffer.length == 0) {
        buffer.write(piece);
      } else if ((buffer.length + piece.length) <= 48) {
        buffer.write('，$piece');
      } else {
        out.add(buffer.toString());
        buffer.clear();
        buffer.write(piece);
      }
    }
    if (buffer.length > 0) out.add(buffer.toString());
    return out;
  }

  static ({String title, String body}) _extractTitleAndBody(String raw, String fileName) {
    final lines = _stripCodeFence(raw).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    var title = _cleanFileTitle(fileName);
    var bodyLines = List<String>.from(lines);
    while (bodyLines.isNotEmpty && RegExp(r'^(时长|duration)\s*[:：]', caseSensitive: false).hasMatch(bodyLines.first)) {
      bodyLines = bodyLines.skip(1).toList();
    }
    if (bodyLines.isNotEmpty) {
      final first = bodyLines.first.replaceAll(RegExp(r'^#+\s*'), '').replaceAll(RegExp(r'^标题[:：]\s*'), '').trim();
      if (first.length >= 2 && first.length <= 36 && !first.contains('。') && !first.contains('{') && !RegExp(r'^\[?\d').hasMatch(first)) {
        title = first;
        bodyLines = bodyLines.skip(1).toList();
      }
    }
    return (title: title, body: bodyLines.join('\n').trim().isEmpty ? raw : bodyLines.join('\n').trim());
  }

  static int? _readPause(dynamic value) {
    if (value is num) return value.toInt();
    final raw = value?.toString() ?? '';
    final m = RegExp(r'\d+').firstMatch(raw);
    return int.tryParse(m?.group(0) ?? '');
  }

  static String _normalizeRaw(String text) => text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  static String _stripCodeFence(String raw) => raw.trim().replaceAll(RegExp(r'^```(?:json|JSON)?\s*'), '').replaceAll(RegExp(r'\s*```$'), '').trim();
  static String _cleanFileTitle(String name) => name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ').trim();
  static String _cleanOneLine(String? value) => (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  static String _cleanText(dynamic value) => (value ?? '').toString().replaceAll('\r\n', '\n').trim();
  static String _guessType(String raw) {
    if (raw.contains('睡') || raw.contains('入睡')) return '睡前放松';
    if (raw.contains('反刍') || raw.contains('念头')) return '反刍中断';
    if (raw.contains('焦虑') || raw.contains('呼吸')) return '呼吸稳定';
    if (raw.contains('身体扫描') || raw.contains('身体')) return '身体扫描';
    if (raw.contains('羞耻') || raw.contains('自责')) return '自责松绑';
    return '本地脚本';
  }

  static String _guessAiTitle(String raw, String fallback) {
    final lines = raw.split('\n').map(_cleanOneLine).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return fallback;
    final first = lines.first.replaceAll(RegExp(r'^#+\s*'), '').replaceAll(RegExp(r'^标题[:：]\s*'), '').trim();
    if (first.length >= 2 && first.length <= 32 && !first.contains('{') && !first.contains('[')) return first;
    return fallback;
  }
}

extension MeditationSessionTemplateCopyForPausePlanner on MeditationSessionTemplate {
  MeditationSessionTemplate copyWith({
    String? key,
    String? title,
    String? type,
    String? category,
    String? description,
    int? durationSeconds,
    bool? isSleep,
    String? source,
    List<MeditationStep>? steps,
    String? endingReflection,
  }) {
    return MeditationSessionTemplate(
      key: key ?? this.key,
      title: title ?? this.title,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isSleep: isSleep ?? this.isSleep,
      source: source ?? this.source,
      steps: steps ?? this.steps,
      endingReflection: endingReflection ?? this.endingReflection,
    );
  }
}
