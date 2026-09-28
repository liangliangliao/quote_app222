import 'dart:convert';
import 'dart:math' as math;

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'meditation_dao.dart';
import 'meditation_models.dart';
import 'meditation_script_pause_planner.dart';

class MeditationAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final GlobalAiSettings _settings = GlobalAiSettings();
  final MeditationDao _dao = MeditationDao();

  Future<MeditationAiGenerationResult?> generateDailyMeditation({
    required String currentState,
    required MeditationSessionTemplate recommended,
    required List<MeditationRecord> recentRecords,
    required int durationMinutes,
    String userDescription = '',
  }) async {
    final targetMinutes = durationMinutes.clamp(1, 30).toInt();
    final targetSegmentCount = math.max(4, (targetMinutes * 60 / 45).ceil()).clamp(4, 40).toInt();
    final targetMinChars = targetMinutes * 45;
    final targetMaxChars = targetMinutes * 75;
    final input = <String, dynamic>{
      'current_state': currentState,
      'recommended_type': recommended.type,
      'recommended_title': recommended.title,
      'duration_minutes': targetMinutes,
      'target_segment_count': targetSegmentCount,
      'target_chinese_character_range': '$targetMinChars-$targetMaxChars',
      'recent_records': _recordsForJson(recentRecords.take(8).toList()),
      'user_description': userDescription.trim(),
      'need_analysis': '从用户原话中区分表面困扰、当下感受、未说出的真正需要和本次练习目标；使用“可能”而非诊断式断言',
      'content_style': '直观、具体、有温度；少用抽象概念和宏大哲理；每一段都能直接听懂并照做',
      'tone': '温和、稳定、不说教、不空泛鼓励',
      'language': 'zh-CN',
    };
    final prompt = await _renderPrompt(
      () => _settings.inspectMeditationDailyScriptPromptState(),
      _settings.defaultMeditationDailyScriptPrompt,
      <String, String>{
        '{{current_state}}': currentState,
        '{{practice_type}}': recommended.type,
        '{{duration_minutes}}': targetMinutes.toString(),
        '{{target_segment_count}}': targetSegmentCount.toString(),
        '{{target_character_range}}': '$targetMinChars-$targetMaxChars',
        '{{user_description}}': userDescription.trim().isEmpty ? '无' : userDescription.trim(),
        '{{recent_records_json}}': _prettyJson(input['recent_records']),
      },
      input,
    );
    final cfg = await _ai.resolveGlobalConfig();
    if (!cfg.available) return null;
    try {
      final raw = await _ai.generateText(
        purpose: 'meditation.daily_script',
        systemPrompt: '你是一名温和、稳定、不说教的中文冥想引导师。先从用户原话中理解表面困扰背后的真正需要，再生成直观、具体、能直接跟随的引导；不要堆砌抽象概念、哲学术语或空泛口号。若用户补充了文字描述，必须优先贴合这段描述。',
        prompt: prompt,
        maxTokens: (1200 + targetMinutes * 150).clamp(1400, 6000).toInt(),
        expectJson: true,
        temperature: 0.6,
      );
      if (raw.trim().isEmpty) return null;
      final parsedMap = _tryParseJsonObject(raw);
      final session = _sessionFromAiText(
        raw,
        recommended,
        currentState,
        parsedMap,
        targetDurationMinutes: targetMinutes,
        targetSegmentCount: targetSegmentCount,
      );
      final understoodNeed = _readUnderstoodNeed(
        parsedMap,
        userDescription: userDescription,
        currentState: currentState,
      );
      final practiceFocus = _readStringList(
        parsedMap?['practice_focus'] ?? parsedMap?['focus_points'] ?? parsedMap?['needs'],
      ).take(4).toList();
      await _dao.insertAiOutput(
        feature: 'daily_script',
        inputJson: jsonEncode(input),
        outputText: raw,
        parsedJson: parsedMap == null ? null : jsonEncode(parsedMap),
        provider: cfg.provider,
        model: cfg.model,
        success: true,
      );
      return MeditationAiGenerationResult(
        session: session,
        understoodNeed: understoodNeed,
        practiceFocus: practiceFocus,
      );
    } catch (e) {
      await _dao.insertAiOutput(
        feature: 'daily_script',
        inputJson: jsonEncode(input),
        outputText: '',
        provider: cfg.provider,
        model: cfg.model,
        success: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<String> generatePracticeFeedback({
    required MeditationSessionTemplate session,
    required String currentState,
    required int actualSeconds,
    required int beforeMood,
    required int afterMood,
    required int distractionLevel,
    required int bodyRelaxLevel,
    required String userNote,
  }) async {
    final input = <String, dynamic>{
      'session_title': session.title,
      'session_type': session.type,
      'duration_seconds': actualSeconds,
      'before_mood': beforeMood,
      'after_mood': afterMood,
      'distraction_level': distractionLevel,
      'body_relax_level': bodyRelaxLevel,
      'current_state': currentState,
      'user_note': userNote,
    };
    final prompt = await _renderPrompt(
      () => _settings.inspectMeditationFeedbackPromptState(),
      _settings.defaultMeditationFeedbackPrompt,
      <String, String>{
        '{{session_title}}': session.title,
        '{{session_type}}': session.type,
        '{{duration_seconds}}': actualSeconds.toString(),
        '{{before_mood}}': beforeMood.toString(),
        '{{after_mood}}': afterMood.toString(),
        '{{distraction_level}}': distractionLevel.toString(),
        '{{body_relax_level}}': bodyRelaxLevel.toString(),
        '{{user_note}}': userNote,
      },
      input,
    );
    final cfg = await _ai.resolveGlobalConfig();
    if (!cfg.available) return '';
    try {
      final raw = await _ai.generateText(
        purpose: 'meditation.feedback',
        systemPrompt: '你是一名温和、克制、不诊断用户的中文冥想反馈助手。',
        prompt: prompt,
        maxTokens: 520,
        temperature: 0.55,
      );
      final text = _stripCodeFence(raw).trim();
      if (text.isEmpty) return '';
      await _dao.insertAiOutput(
        feature: 'practice_feedback',
        inputJson: jsonEncode(input),
        outputText: text,
        provider: cfg.provider,
        model: cfg.model,
        success: true,
      );
      return text;
    } catch (e) {
      await _dao.insertAiOutput(
        feature: 'practice_feedback',
        inputJson: jsonEncode(input),
        outputText: '',
        provider: cfg.provider,
        model: cfg.model,
        success: false,
        errorMessage: e.toString(),
      );
      return '';
    }
  }

  Future<String> generateWeeklySummary({
    required List<MeditationRecord> records,
    required MeditationStats stats,
  }) async {
    if (records.isEmpty) return '';
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final statsJson = <String, dynamic>{
      'date_range': '${_dateKey(weekStart)} 至 ${_dateKey(weekEnd)}',
      'total_sessions': records.length,
      'total_minutes': (records.fold<int>(0, (sum, r) => sum + r.durationSeconds) / 60).round(),
      'streak_days': stats.streakDays,
      'week_completed_count': stats.weekCompletedCount,
      'most_used_type': stats.mostUsedType,
      'total_completed_count': stats.totalCompletedCount,
    };
    final input = <String, dynamic>{
      'weekly_records': _recordsForJson(records),
      'weekly_stats': statsJson,
    };
    final prompt = await _renderPrompt(
      () => _settings.inspectMeditationWeeklySummaryPromptState(),
      _settings.defaultMeditationWeeklySummaryPrompt,
      <String, String>{
        '{{weekly_records_json}}': _prettyJson(input['weekly_records']),
        '{{weekly_stats_json}}': _prettyJson(statsJson),
      },
      input,
    );
    final cfg = await _ai.resolveGlobalConfig();
    if (!cfg.available) return '';
    try {
      final raw = await _ai.generateText(
        purpose: 'meditation.weekly_summary',
        systemPrompt: '你是一名正念练习总结助手。请温和、具体、克制地总结，不做医疗诊断。',
        prompt: prompt,
        maxTokens: 900,
        temperature: 0.55,
      );
      final text = _stripCodeFence(raw).trim();
      if (text.isEmpty) return '';
      final outputId = await _dao.insertAiOutput(
        feature: 'weekly_summary',
        inputJson: jsonEncode(input),
        outputText: text,
        provider: cfg.provider,
        model: cfg.model,
        success: true,
      );
      final ms = DateTime.now().millisecondsSinceEpoch;
      await _dao.insertWeeklySummary(
        MeditationWeeklySummary(
          weekStart: _dateKey(weekStart),
          weekEnd: _dateKey(weekEnd),
          summaryText: text,
          statsJson: jsonEncode(statsJson),
          aiOutputId: outputId,
          createdAt: ms,
          updatedAt: ms,
        ),
      );
      return text;
    } catch (e) {
      await _dao.insertAiOutput(
        feature: 'weekly_summary',
        inputJson: jsonEncode(input),
        outputText: '',
        provider: cfg.provider,
        model: cfg.model,
        success: false,
        errorMessage: e.toString(),
      );
      return '';
    }
  }

  Future<String> generateRecommendationReason({
    required String currentState,
    required MeditationSessionTemplate recommended,
  }) async {
    final input = <String, dynamic>{
      'current_state': currentState,
      'practice_type': recommended.type,
      'practice_title': recommended.title,
    };
    final prompt = await _renderPrompt(
      () => _settings.inspectMeditationRecommendationPromptState(),
      _settings.defaultMeditationRecommendationPrompt,
      <String, String>{
        '{{current_state}}': currentState,
        '{{practice_type}}': recommended.type,
      },
      input,
    );
    final cfg = await _ai.resolveGlobalConfig();
    if (!cfg.available) return '';
    try {
      final raw = await _ai.generateText(
        purpose: 'meditation.recommendation_reason',
        systemPrompt: '你是一名中文冥想推荐助手。只输出一句话。',
        prompt: prompt,
        maxTokens: 120,
        temperature: 0.5,
      );
      final text = _stripCodeFence(raw).trim();
      if (text.isEmpty) return '';
      await _dao.insertAiOutput(
        feature: 'recommendation_reason',
        inputJson: jsonEncode(input),
        outputText: text,
        provider: cfg.provider,
        model: cfg.model,
        success: true,
      );
      return text;
    } catch (e) {
      await _dao.insertAiOutput(
        feature: 'recommendation_reason',
        inputJson: jsonEncode(input),
        outputText: '',
        provider: cfg.provider,
        model: cfg.model,
        success: false,
        errorMessage: e.toString(),
      );
      return '';
    }
  }


  Future<MeditationSessionTemplate?> annotateUploadedScriptWithPauses({
    required String rawScript,
    required String fileName,
    required MeditationScriptBuildOptions options,
  }) async {
    final input = <String, dynamic>{
      'raw_script': rawScript,
      'target_duration_minutes': options.targetDurationMinutes,
      'meditation_type': options.meditationType,
      'pause_style': options.pauseStyle,
      'process_mode': options.processMode,
      'preserve_original': options.processMode == 'preserve',
    };
    final prompt = await _renderPrompt(
      () => _settings.inspectMeditationUploadPausePromptState(),
      _settings.defaultMeditationUploadPausePrompt,
      <String, String>{
        '{{raw_script}}': rawScript,
        '{{target_duration_minutes}}': options.targetDurationMinutes.toString(),
        '{{meditation_type}}': options.meditationType,
        '{{pause_style}}': options.pauseStyle,
        '{{process_mode}}': options.processMode,
      },
      input,
    );
    final cfg = await _ai.resolveGlobalConfig();
    if (!cfg.available) return null;
    try {
      final raw = await _ai.generateText(
        purpose: 'meditation.upload_pause_annotation',
        systemPrompt: '你是专业冥想脚本节奏整理助手。你的任务是尽量保留原文，只做轻微断句和停顿标注，不要重新创作。',
        prompt: prompt,
        maxTokens: 3200,
        expectJson: true,
        temperature: 0.25,
      );
      if (raw.trim().isEmpty) return null;
      final session = MeditationScriptPausePlanner.buildFromAiOutput(
        aiRaw: raw,
        originalRawText: rawScript,
        fileName: fileName,
        options: options,
      );
      await _dao.insertAiOutput(
        feature: 'upload_pause_annotation',
        inputJson: jsonEncode(input),
        outputText: raw,
        parsedJson: session == null ? null : jsonEncode(session.steps.map((e) => e.toJson()).toList()),
        provider: cfg.provider,
        model: cfg.model,
        success: session != null,
        errorMessage: session == null ? 'AI 输出未能解析为可用脚本，已交由本地规则兜底。' : null,
      );
      return session;
    } catch (e) {
      await _dao.insertAiOutput(
        feature: 'upload_pause_annotation',
        inputJson: jsonEncode(input),
        outputText: '',
        provider: cfg.provider,
        model: cfg.model,
        success: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<String> _renderPrompt(
    Future<Map<String, String>> Function() inspect,
    String fallback,
    Map<String, String> replacements,
    Map<String, dynamic> input,
  ) async {
    String template;
    try {
      template = (await inspect())['value'] ?? fallback;
    } catch (_) {
      template = fallback;
    }
    var out = template;
    replacements.forEach((key, value) {
      out = out.replaceAll(key, value);
    });
    out = out.trim();
    if (out.isEmpty) out = fallback;
    return '$out\n\n【结构化输入，必要时请优先参考】\n${_prettyJson(input)}';
  }

  List<Map<String, dynamic>> _recordsForJson(List<MeditationRecord> records) {
    return records.map((r) {
      return <String, dynamic>{
        'date': DateTime.fromMillisecondsSinceEpoch(r.startedAt).toIso8601String(),
        'title': r.title,
        'type': r.type,
        'duration_seconds': r.durationSeconds,
        'before_mood': r.beforeMood,
        'after_mood': r.afterMood,
        'distraction_level': r.distractionLevel,
        'body_relax_level': r.bodyRelaxLevel,
        'current_state': r.currentState,
        'note': r.note,
        'feedback': r.aiFeedback,
      };
    }).toList();
  }

  MeditationSessionTemplate _sessionFromAiText(
    String raw,
    MeditationSessionTemplate fallback,
    String currentState,
    Map<String, dynamic>? parsed, {
    required int targetDurationMinutes,
    required int targetSegmentCount,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = parsed ?? <String, dynamic>{};
    final title = _cleanOneLine(map['title']?.toString()).isNotEmpty
        ? _cleanOneLine(map['title']?.toString())
        : _guessTitle(raw, fallback.title);
    final type = _cleanOneLine(map['type']?.toString()).isNotEmpty
        ? _cleanOneLine(map['type']?.toString())
        : fallback.type;
    final durationMinutes = targetDurationMinutes.clamp(1, 30).toInt();
    final durationSeconds = durationMinutes * 60;
    final steps = _readSteps(map['segments'] ?? map['steps'], durationSeconds);
    final parsedSteps = steps.isNotEmpty ? steps : _plainTextToSteps(raw, durationSeconds, targetSegmentCount);
    final safeSteps = _fitStepTimeline(parsedSteps, durationSeconds);
    final ending = _cleanText(map['ending_reflection'] ?? map['endingReflection']).isNotEmpty
        ? _cleanText(map['ending_reflection'] ?? map['endingReflection'])
        : fallback.endingReflection;
    return MeditationSessionTemplate(
      key: 'ai_daily_$now',
      title: title.isEmpty ? '今日专属冥想' : title,
      type: type.isEmpty ? fallback.type : type,
      category: 'AI 今日冥想',
      description: 'AI 根据你的输入分析真正需要后生成，可在本地保存并重复练习。',
      durationSeconds: durationSeconds,
      isSleep: fallback.isSleep || currentState.contains('睡'),
      source: 'ai_generated',
      steps: safeSteps,
      endingReflection: ending,
    );
  }

  List<MeditationStep> _readSteps(dynamic value, int durationSeconds) {
    if (value is! List) return const <MeditationStep>[];
    final out = <MeditationStep>[];
    for (final item in value) {
      if (item is! Map) continue;
      final text = _cleanText(item['text'] ?? item['content'] ?? item['guide']);
      if (text.isEmpty) continue;
      final rawStart = item['start_seconds'] ?? item['startSecond'] ?? item['start'] ?? item['time'];
      int start = 0;
      if (rawStart is num) {
        start = rawStart.toInt();
      } else {
        start = int.tryParse(RegExp(r'\d+').firstMatch(rawStart?.toString() ?? '')?.group(0) ?? '0') ?? 0;
      }
      final pause = _readSeconds(item['pause_after_seconds'] ?? item['pauseAfterSeconds'] ?? item['pause_seconds'] ?? item['pause'], 0).clamp(0, 60).toInt();
      final intent = _cleanOneLine(item['intent']?.toString());
      out.add(MeditationStep(
        startSecond: start.clamp(0, math.max(0, durationSeconds - 1)).toInt(),
        text: text,
        pauseAfterSeconds: pause,
        intent: intent.isEmpty ? null : intent,
      ));
    }
    out.sort((a, b) => a.startSecond.compareTo(b.startSecond));
    if (out.isNotEmpty && out.first.startSecond != 0) {
      final first = out.first;
      out[0] = MeditationStep(
        startSecond: 0,
        text: first.text,
        pauseAfterSeconds: first.pauseAfterSeconds,
        intent: first.intent,
      );
    }
    return out;
  }

  List<MeditationStep> _plainTextToSteps(String raw, int durationSeconds, int targetSegmentCount) {
    final cleaned = _stripCodeFence(raw)
        .replaceAll(RegExp(r'^[#>*\-\s]+', multiLine: true), '')
        .replaceAll(RegExp(r'(?i)title\s*[:：]'), '')
        .trim();
    final pieces = cleaned
        .split(RegExp(r'\n\s*\n|\n\d+[\.、]\s*|\n[-•]\s*'))
        .map((e) => _cleanText(e))
        .where((e) => e.isNotEmpty)
        .toList();
    final selected = pieces.length > targetSegmentCount ? pieces.take(targetSegmentCount).toList() : pieces;
    final safe = selected.isEmpty
        ? <String>['现在，先不用解决任何问题。只是坐下来，感受身体和呼吸。', '如果走神了，不用责备自己。看见它，然后回来。']
        : selected;
    final step = math.max(20, durationSeconds ~/ math.max(1, safe.length));
    return List.generate(safe.length, (i) => MeditationStep(startSecond: math.min(durationSeconds - 1, i * step), text: safe[i]));
  }

  List<MeditationStep> _fitStepTimeline(List<MeditationStep> steps, int durationSeconds) {
    final safe = steps.where((e) => e.text.trim().isNotEmpty).toList();
    if (safe.isEmpty) {
      return const <MeditationStep>[
        MeditationStep(startSecond: 0, text: '现在，先不用解决所有问题。感受身体被支撑，慢慢回到这一刻。'),
      ];
    }
    if (safe.length == 1) {
      return <MeditationStep>[
        MeditationStep(
          startSecond: 0,
          text: safe.first.text,
          pauseAfterSeconds: safe.first.pauseAfterSeconds,
          intent: safe.first.intent,
        ),
      ];
    }
    final lastUsefulSecond = math.max(1, (durationSeconds * 0.88).round());
    final interval = lastUsefulSecond / (safe.length - 1);
    return List<MeditationStep>.generate(safe.length, (index) {
      final original = safe[index];
      return MeditationStep(
        startSecond: math.min(durationSeconds - 1, (interval * index).round()),
        text: original.text,
        pauseAfterSeconds: original.pauseAfterSeconds,
        intent: original.intent,
      );
    });
  }

  String _readUnderstoodNeed(
    Map<String, dynamic>? parsed, {
    required String userDescription,
    required String currentState,
  }) {
    final candidates = <dynamic>[
      parsed?['understood_need'],
      parsed?['need_summary'],
      parsed?['core_need'],
      parsed?['true_need'],
    ];
    for (final value in candidates) {
      final text = _cleanText(value);
      if (text.isNotEmpty) return text;
    }
    final description = userDescription.trim();
    if (description.isNotEmpty) {
      return '这次练习会先承接你描述的处境，再帮助你回到身体、稳定注意力，并为下一步保留选择空间。';
    }
    return '你此刻可能需要的不是继续逼迫自己，而是先从“$currentState”中稳下来，重新感到自己仍有选择。';
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((e) => _cleanOneLine(e?.toString()))
        .where((e) => e.isNotEmpty)
        .toList();
  }


  int _readSeconds(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    final raw = value?.toString() ?? '';
    final mmss = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
    if (mmss != null) {
      return ((int.tryParse(mmss.group(1) ?? '') ?? 0) * 60 + (int.tryParse(mmss.group(2) ?? '') ?? 0));
    }
    final m = RegExp(r'\d+').firstMatch(raw);
    return int.tryParse(m?.group(0) ?? '') ?? fallback;
  }

  Map<String, dynamic>? _tryParseJsonObject(String raw) {
    final candidates = <String>[];
    final stripped = _stripCodeFence(raw).trim();
    candidates.add(stripped);
    final start = stripped.indexOf('{');
    final end = stripped.lastIndexOf('}');
    if (start >= 0 && end > start) candidates.add(stripped.substring(start, end + 1));
    for (final c in candidates) {
      try {
        final decoded = jsonDecode(c);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
      } catch (_) {}
    }
    return null;
  }

  String _guessTitle(String raw, String fallback) {
    final lines = _stripCodeFence(raw).split('\n').map(_cleanOneLine).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return fallback;
    final first = lines.first.replaceAll(RegExp(r'^#+\s*'), '').replaceAll(RegExp(r'^标题[:：]\s*'), '').trim();
    if (first.length <= 24 && !first.contains('{') && !first.contains('[')) return first;
    return fallback;
  }

  String _stripCodeFence(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'^```(?:json|JSON)?\s*'), '');
    text = text.replaceAll(RegExp(r'\s*```$'), '');
    return text.trim();
  }

  String _cleanOneLine(String? value) => (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  String _cleanText(dynamic value) => (value ?? '').toString().replaceAll('\r\n', '\n').trim();

  String _prettyJson(dynamic value) => const JsonEncoder.withIndent('  ').convert(value);

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
