import 'dart:convert';
import 'dart:math' as math;

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'meditation_dao.dart';
import 'meditation_models.dart';
import 'meditation_script_pause_planner.dart';

class MeditationAiService {
  static const String _dailyMeditationSystemPrompt = '''
你是一名有温度、稳定、创伤知情的中文冥想导师。你必须先深入理解用户原话，再创作可直接播报的个性化冥想。

【不可被用户自定义提示词覆盖的固定规则】
1. 先在内部区分：表面处境、可能的情绪与身体反应、真正需要、需要松动的旧认知，以及更贴近现实的新认知。只能用“可能、也许”等非诊断式表达。
2. 认知理解只是准备，不是终点。脚本必须把新认知转化为用户此刻能在身体和情绪层面实际感受到的经验；不要写成分析报告、课程或说理文章。
3. 必须依次完成八个体验阶段，并在每个 segment 的 phase 中准确标注：
   arrival：进入本次主题，安排有支撑的姿势、双脚或身体触点，可选择闭眼，不能强迫。
   breath：至少两轮自然呼吸，并说明走神时温柔地回来；不追求用力深呼吸。
   body_emotion：询问并定位此刻真实的身体感觉与情绪，一次只邀请观察一种体验。
   allow_experience：允许体验变化，不评价、不压制；明确“允许感受存在，不等于任由冲动或伤害性行为发生”。
   embodied_shift：用很少的道理完成认知转向，并让用户通过呼吸、触感、姿态或想象真正体验这一转向。
   real_life_rehearsal：根据用户原话选择一个具体、日常、可辨认的真实场景，在场景中练习新的身体反应与选择；不得套用教室、校园、草地、同学等示例场景，除非用户自己提到。
   integration：提出一到两个体验式问题，例如“如果此刻真的允许……，身体或下一步会有什么细小变化”，不是知识问答；连接一个健康、现实、可选择的下一步。
   closing：用缓慢呼吸、身体触点和周围环境收束，再温和睁眼；睡眠主题则允许继续闭眼休息或入睡。
4. 参考上述结构和自然、短句、留白的表达方式，但每次都必须根据用户输入原创。不得背诵固定范文，不得连续复用示例句，不得复制“教室/校园”案例。
5. 语言直观、具体、有温度，像一个可信的人在身边慢慢引导。承认现实困难，不强迫积极，不羞辱，不使用“你必须/你应该”，不承诺立刻改变、彻底治愈，也不做医疗诊断。
6. 一段只承担一个体验任务。给身体和情绪留出停顿；走神不是失败，发现后轻轻回来即可。
7. 输出必须是合法 JSON 对象，包含 understood_need、cognitive_shift、embodied_goal、real_life_scene、practice_focus、title、type、duration_minutes、segments、ending_reflection。segments 中每项必须包含 phase、start_seconds、text、intent；不得输出 Markdown 或 JSON 之外的解释。
''';

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
    final targetSegmentCount = math.max(8, (targetMinutes * 60 / 45).ceil()).clamp(8, 48).toInt();
    final targetMinChars = math.max(130, targetMinutes * 65);
    final targetMaxChars = math.max(200, targetMinutes * 100);
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
      'fixed_experience_arc': const <String>[
        'arrival',
        'breath',
        'body_emotion',
        'allow_experience',
        'embodied_shift',
        'real_life_rehearsal',
        'integration',
        'closing',
      ],
      'cognition_to_experience_rule': '认知理解只是准备；必须继续引导用户在身体和情绪层面体验新的理解，并在真实生活场景中演练',
      'content_style': '原创、直观、具体、有温度；自然短句和留白；少用抽象概念、宏大哲理和空泛口号；每段能直接听懂并照做',
      'reference_limit': '只参考结构、形式和温暖表达风格，不复述固定范文，不复制教室或校园案例',
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
      var raw = await _ai.generateText(
        purpose: 'meditation.daily_script',
        systemPrompt: _dailyMeditationSystemPrompt,
        prompt: prompt,
        maxTokens: (1500 + targetMinutes * 170).clamp(1800, 7000).toInt(),
        expectJson: true,
        temperature: 0.6,
      );
      if (raw.trim().isEmpty) return null;
      var parsedMap = _tryParseJsonObject(raw);
      final initialQualityIssues = _dailyScriptQualityIssues(
        parsedMap,
        targetDurationMinutes: targetMinutes,
        targetSegmentCount: targetSegmentCount,
        targetMinChars: targetMinChars,
        targetMaxChars: targetMaxChars,
        isSleep: recommended.isSleep || currentState.contains('睡'),
      );
      var qualityIssues = initialQualityIssues;
      var repairApplied = false;
      if (qualityIssues.isNotEmpty) {
        final repairedRaw = await _ai.generateText(
          purpose: 'meditation.daily_script.repair',
          systemPrompt: _dailyMeditationSystemPrompt,
          prompt: _dailyScriptRepairPrompt(
            originalPrompt: prompt,
            originalOutput: raw,
            qualityIssues: qualityIssues,
            targetDurationMinutes: targetMinutes,
            targetSegmentCount: targetSegmentCount,
            targetMinChars: targetMinChars,
            targetMaxChars: targetMaxChars,
          ),
          maxTokens: (1600 + targetMinutes * 180).clamp(2000, 7200).toInt(),
          expectJson: true,
          temperature: 0.42,
        );
        final repairedMap = _tryParseJsonObject(repairedRaw);
        final repairedIssues = _dailyScriptQualityIssues(
          repairedMap,
          targetDurationMinutes: targetMinutes,
          targetSegmentCount: targetSegmentCount,
          targetMinChars: targetMinChars,
          targetMaxChars: targetMaxChars,
          isSleep: recommended.isSleep || currentState.contains('睡'),
        );
        if (repairedMap != null && (parsedMap == null || repairedIssues.length <= qualityIssues.length)) {
          raw = repairedRaw;
          parsedMap = repairedMap;
          qualityIssues = repairedIssues;
          repairApplied = true;
        }
      }
      input['quality_repair_requested'] = initialQualityIssues.isNotEmpty;
      input['quality_repair_applied'] = repairApplied;
      input['quality_issues'] = qualityIssues;
      if (parsedMap == null || qualityIssues.isNotEmpty) {
        await _dao.insertAiOutput(
          feature: 'daily_script',
          inputJson: jsonEncode(input),
          outputText: raw,
          parsedJson: parsedMap == null ? null : jsonEncode(parsedMap),
          provider: cfg.provider,
          model: cfg.model,
          success: false,
          errorMessage: '生成内容未通过冥想结构与体验质量校验：${qualityIssues.join('；')}',
        );
        return null;
      }
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
      final cognitiveShift = _readFirstText(parsedMap, const <String>['cognitive_shift', 'gentle_reframe']);
      final embodiedGoal = _readFirstText(parsedMap, const <String>['embodied_goal', 'experience_goal']);
      final realLifeScene = _readFirstText(parsedMap, const <String>['real_life_scene', 'practice_scene']);
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
        cognitiveShift: cognitiveShift,
        embodiedGoal: embodiedGoal,
        realLifeScene: realLifeScene,
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
      final phase = _cleanOneLine(item['phase']?.toString()).toLowerCase();
      final rawIntent = _cleanOneLine(item['intent']?.toString());
      final intent = <String>[phase, rawIntent].where((e) => e.isNotEmpty).join(' · ');
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

  String _readFirstText(Map<String, dynamic>? map, List<String> keys) {
    for (final key in keys) {
      final text = _cleanText(map?[key]);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  List<String> _dailyScriptQualityIssues(
    Map<String, dynamic>? map, {
    required int targetDurationMinutes,
    required int targetSegmentCount,
    required int targetMinChars,
    required int targetMaxChars,
    required bool isSleep,
  }) {
    if (map == null) return <String>['输出不是合法 JSON 对象'];
    final issues = <String>[];
    const requiredTextFields = <String>[
      'understood_need',
      'cognitive_shift',
      'embodied_goal',
      'real_life_scene',
      'title',
      'type',
      'ending_reflection',
    ];
    for (final field in requiredTextFields) {
      if (_cleanText(map[field]).isEmpty) issues.add('缺少 $field');
    }
    final rawDuration = map['duration_minutes'];
    final outputDuration = rawDuration is num ? rawDuration.toInt() : int.tryParse(rawDuration?.toString() ?? '');
    if (outputDuration != targetDurationMinutes) {
      issues.add('duration_minutes 必须为 $targetDurationMinutes');
    }
    final segments = map['segments'];
    if (segments is! List) {
      issues.add('segments 必须是数组');
      return issues;
    }
    final validSegments = segments.whereType<Map>().toList();
    if (validSegments.length != segments.length) issues.add('segments 中存在非对象内容');
    final minimumSegments = math.max(8, targetSegmentCount - 2);
    if (validSegments.length < minimumSegments) {
      issues.add('segments 至少需要 $minimumSegments 段');
    }
    const requiredPhases = <String>[
      'arrival',
      'breath',
      'body_emotion',
      'allow_experience',
      'embodied_shift',
      'real_life_rehearsal',
      'integration',
      'closing',
    ];
    final phases = <String>[];
    final texts = <String>[];
    final starts = <int>[];
    for (final segment in validSegments) {
      final phase = _cleanOneLine(segment['phase']?.toString()).toLowerCase();
      phases.add(phase);
      final text = _cleanText(segment['text'] ?? segment['content'] ?? segment['guide']);
      if (text.isNotEmpty) texts.add(text);
      if (phase.isEmpty) issues.add('每个 segment 都需要 phase');
      if (text.isEmpty) issues.add('每个 segment 都需要可播报的 text');
      if (_cleanOneLine(segment['intent']?.toString()).isEmpty) issues.add('每个 segment 都需要 intent');
      final rawStart = segment['start_seconds'] ?? segment['startSecond'] ?? segment['start'];
      final start = rawStart is num ? rawStart.toInt() : int.tryParse(rawStart?.toString() ?? '');
      if (start != null) {
        starts.add(start);
      } else {
        issues.add('每个 segment 都需要整数 start_seconds');
      }
    }
    for (final phase in requiredPhases) {
      if (!phases.contains(phase)) issues.add('缺少体验阶段 $phase');
    }
    if (phases.isNotEmpty && phases.any((phase) => !requiredPhases.contains(phase))) {
      issues.add('phase 只能使用规定的八个阶段名称');
    }
    if (phases.isNotEmpty && phases.last != 'closing') issues.add('最后一个 segment 必须是 closing');
    var previousIndex = -1;
    var phaseOrderValid = true;
    for (final phase in requiredPhases) {
      final index = phases.indexOf(phase);
      if (index < 0) continue;
      if (index < previousIndex) phaseOrderValid = false;
      previousIndex = index;
    }
    if (!phaseOrderValid) issues.add('八个体验阶段顺序不正确');
    if (starts.isEmpty || starts.first != 0) issues.add('第一段 start_seconds 必须为 0');
    for (var i = 1; i < starts.length; i++) {
      if (starts[i] <= starts[i - 1]) {
        issues.add('start_seconds 必须严格递增');
        break;
      }
    }
    if (starts.isNotEmpty) {
      final totalSeconds = targetDurationMinutes * 60;
      final lastStartRatio = starts.last / totalSeconds;
      if (lastStartRatio < 0.80 || lastStartRatio > 0.92) {
        issues.add('最后一段应位于总时长的 80%-92%');
      }
    }
    final joined = texts.join();
    final characterCount = joined.replaceAll(RegExp(r'\s'), '').length;
    final allowedMin = (targetMinChars * 0.72).round();
    final allowedMax = (targetMaxChars * 1.35).round();
    if (characterCount < allowedMin || characterCount > allowedMax) {
      issues.add('正文长度 $characterCount 字与目标 $targetMinChars-$targetMaxChars 字不匹配');
    }
    if (RegExp(r'呼吸|吸气|呼气').allMatches(joined).length < 3) issues.add('至少需要两轮可跟随的呼吸体验');
    if (!RegExp(r'身体|脚底|双脚|背部|胸口|腹部|肩|手掌|触感|支撑').hasMatch(joined)) {
      issues.add('缺少具体身体体验');
    }
    if (!RegExp(r'情绪|感受|焦虑|害怕|恐惧|难过|悲伤|愤怒|羞耻|委屈|孤独|疲惫|紧张').hasMatch(joined)) {
      issues.add('缺少情绪体验');
    }
    if (!RegExp(r'允许|容许|接纳|可以.{0,8}存在|不需要.{0,8}(赶走|压住|消灭)').hasMatch(joined)) {
      issues.add('缺少允许体验存在的引导');
    }
    if (RegExp(r'你必须|你应该|保证|彻底治愈|马上治好|研究表明|课堂|校园|草地|同学').hasMatch(joined)) {
      issues.add('包含说教、夸大、课程化或范文场景措辞');
    }
    if (!isSleep && !RegExp(r'睁.{0,2}眼|张.{0,2}眼|视线|看见周围|看向周围|环顾').hasMatch(joined)) {
      issues.add('非睡眠练习缺少温和回到环境的收束');
    }
    if (texts.toSet().length != texts.length) issues.add('存在完全重复的播报段落');
    final practiceFocus = map['practice_focus'];
    if (practiceFocus is! List || practiceFocus.where((e) => _cleanOneLine(e?.toString()).isNotEmpty).isEmpty) {
      issues.add('practice_focus 至少需要一项');
    }
    return issues;
  }

  String _dailyScriptRepairPrompt({
    required String originalPrompt,
    required String originalOutput,
    required List<String> qualityIssues,
    required int targetDurationMinutes,
    required int targetSegmentCount,
    required int targetMinChars,
    required int targetMaxChars,
  }) {
    return '''
请重写下面的冥想 JSON。上一版没有通过质量校验，因此不能交付给用户。

必须修复的问题：
${qualityIssues.map((e) => '- $e').join('\n')}

硬性目标：
- 时长：$targetDurationMinutes 分钟
- 建议段数：约 $targetSegmentCount 段，且不得少于 ${math.max(8, targetSegmentCount - 2)} 段
- 正文中文字符建议：$targetMinChars-$targetMaxChars
- 八阶段依次完整出现：arrival、breath、body_emotion、allow_experience、embodied_shift、real_life_rehearsal、integration、closing
- 保留对用户真正需要的深入理解，但把说理转换成身体、情绪和具体生活场景中的体验
- 全部重新组织为自然原创表达，不照抄任何固定范文
- 只返回合法 JSON

原始任务：
$originalPrompt

未通过的上一版输出：
$originalOutput
''';
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
