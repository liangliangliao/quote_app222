import 'dart:convert';
import 'dart:math' as math;

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'meditation_dao.dart';
import 'meditation_depth_guidance.dart';
import 'meditation_experiential_method.dart';
import 'meditation_models.dart';
import 'meditation_narration_guide.dart';
import 'meditation_mentor_guidance.dart';
import 'meditation_script_response.dart';
import 'meditation_script_pause_planner.dart';

class MeditationAiService {
  static const String _dailyMeditationSystemPrompt =
      MeditationNarrationGuide.systemPrompt;

  final UnifiedAiService _ai;
  final GlobalAiSettings _settings;
  final MeditationDao _dao;

  MeditationAiService({UnifiedAiService? ai, GlobalAiSettings? settings, MeditationDao? dao})
      : _ai = ai ?? UnifiedAiService(),
        _settings = settings ?? GlobalAiSettings(),
        _dao = dao ?? MeditationDao();

  /// 这是一个保守的本地分流器：只决定是否适合继续普通冥想生成，
  /// 不判断用户的心理状态，也不把关键词当成诊断依据。
  MeditationSafetyAssessment assessUserInput(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const MeditationSafetyAssessment(level: 'normal', message: '');
    }

    final highRisk = _containsActiveRisk(text, const <String>[
      '自杀',
      '自残',
      '自伤',
      '伤害自己',
      '想死',
      '不想活',
      '活不下去',
      '结束生命',
      '杀了自己',
      '伤害别人',
      '杀人',
      '正在被打',
      '家暴',
      '现在不安全',
      '有人要伤害我',
    ]);
    if (highRisk) {
      return const MeditationSafetyAssessment(
        level: 'high',
        message: '这段话可能涉及眼下的安全风险。冥想不能替代危机支持；如果你此刻有立即危险，请先联系身边可信任的人、当地急救或危机支持服务，确保自己和他人的安全后再练习。',
      );
    }

    final mediumRisk = RegExp(r'(崩溃|失控|绝望|撑不住|濒临|惊恐|虐待|创伤反应)').hasMatch(text);
    if (mediumRisk) {
      return const MeditationSafetyAssessment(
        level: 'medium',
        message: '如果这些感受让你难以保证安全，请先暂停冥想并联系现实中的支持。若你只是经历了强烈的不适，本次会优先采用睁眼、脚底和环境声音等低刺激锚点；你可以随时停下。',
      );
    }

    return const MeditationSafetyAssessment(level: 'normal', message: '');
  }

  bool _containsActiveRisk(String text, List<String> phrases) {
    for (final phrase in phrases) {
      var offset = text.indexOf(phrase);
      while (offset >= 0) {
        final prefix = text.substring(math.max(0, offset - 8).toInt(), offset);
        final negated = RegExp(r'(不想|不愿|不会|没有|没|不是|并非|避免)\s*$').hasMatch(prefix);
        if (!negated) return true;
        offset = text.indexOf(phrase, offset + phrase.length);
      }
    }
    return false;
  }

  Map<String, dynamic> _buildAdaptiveProfile(List<MeditationRecord> records) {
    final usable = records.where((record) => record.completed).take(8).toList();
    if (usable.isEmpty) {
      return <String, dynamic>{
        'sample_size': 0,
        'pattern': '暂无足够练习反馈，采用低负担、可随时调整的基础引导。',
        'next_session_adjustments': <String>[
          '先建立身体支撑和选择感',
          '一次只邀请一个注意力动作',
          '不把放松或情绪变化当作完成标准',
        ],
      };
    }

    double average(int? Function(MeditationRecord record) read) {
      final values = usable.map(read).whereType<int>().toList();
      if (values.isEmpty) return -1;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final averageBefore = average((record) => record.beforeMood);
    final averageAfter = average((record) => record.afterMood);
    final averageDistraction = average((record) => record.distractionLevel);
    final averageRelax = average((record) => record.bodyRelaxLevel);
    final typeCounts = <String, int>{};
    for (final record in usable) {
      final type = record.type.trim();
      if (type.isNotEmpty) typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    final sortedTypes = typeCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final lastType = usable.first.type.trim();
    final adjustments = <String>[];

    if (averageDistraction >= 7) {
      adjustments.add('分心偏多：用更短的句子、更少的隐喻和更清楚的回返提示。');
    } else if (averageDistraction >= 0 && averageDistraction <= 3) {
      adjustments.add('分心较少：可以保留更长的留白，让觉察自然展开。');
    }
    if (averageRelax >= 0 && averageRelax <= 3) {
      adjustments.add('身体放松评分偏低：不追求放松，增加支撑面、姿势调整和外部感官。');
    } else if (averageRelax >= 7) {
      adjustments.add('身体较能安定：可以逐步延长身体扫描或呼气后的留白。');
    }
    if (averageBefore >= 0 && averageAfter >= 0 && averageAfter > averageBefore) {
      adjustments.add('上次练习后烦乱上升：本次降低情绪深入和想象强度，优先定向到当下环境。');
    } else if (averageBefore >= 0 && averageAfter >= 0 && averageBefore - averageAfter >= 2) {
      adjustments.add('上次练习出现了明显缓和：保留有效锚点，但不承诺每次都要达到同样结果。');
    }
    if (lastType.isNotEmpty && (typeCounts[lastType] ?? 0) >= 2) {
      adjustments.add('最近反复练习“$lastType”：可换一个相邻入口，避免把单一方法当成唯一答案。');
    }
    if (adjustments.isEmpty) {
      adjustments.add('反馈没有显示明确偏向：保持温和节奏，同时给出睁眼、换姿势和回到环境的选择。');
    }

    return <String, dynamic>{
      'sample_size': usable.length,
      'average_before_tension': _roundMetric(averageBefore),
      'average_after_tension': _roundMetric(averageAfter),
      'average_distraction': _roundMetric(averageDistraction),
      'average_body_relax': _roundMetric(averageRelax),
      'recent_types': usable.map((record) => record.type).where((type) => type.trim().isNotEmpty).toList(),
      'most_repeated_type': sortedTypes.isEmpty ? '' : sortedTypes.first.key,
      'last_type': lastType,
      'next_session_adjustments': adjustments,
    };
  }

  String _limitPromptText(String text, int maxCharacters) {
    if (text.length <= maxCharacters) return text;
    return '${text.substring(0, maxCharacters)}…';
  }

  dynamic _roundMetric(double value) {
    if (value < 0) return null;
    return double.parse(value.toStringAsFixed(1));
  }

  Future<MeditationAiGenerationResult?> generateDailyMeditation({
    required String currentState,
    required MeditationSessionTemplate recommended,
    required List<MeditationRecord> recentRecords,
    required int durationMinutes,
    String userDescription = '',
    MeditationExpertPreferences preferences = const MeditationExpertPreferences(),
    void Function(String stage)? onProgress,
  }) async {
    final targetMinutes = durationMinutes.clamp(1, 30).toInt();
    final targetSegmentCount = math.max(8, (targetMinutes * 60 / 22).ceil()).clamp(8, 96).toInt();
    final targetMinChars = math.max(130, targetMinutes * 80);
    final targetMaxChars = math.max(200, targetMinutes * 115);
    final normalizedDescription = _limitPromptText(userDescription.trim(), 1200);
    final safety = assessUserInput(normalizedDescription);
    if (safety.requiresImmediateSupport) return null;
    final adaptiveProfile = _buildAdaptiveProfile(recentRecords);
    final primaryInput = normalizedDescription.isNotEmpty
        ? normalizedDescription : (currentState.trim().isEmpty ? '日常练习' : currentState.trim());
    final isSleep = normalizedDescription.isNotEmpty
        ? RegExp(r'睡前|入睡|睡眠|失眠|助眠').hasMatch(normalizedDescription)
        : recommended.isSleep || currentState.contains('睡');
    final useImagery = safety.isNormal &&
        preferences.imageryPreference != '真实感官' &&
        MeditationExperientialMethod.allowsImagery(primaryInput);
    final input = <String, dynamic>{
      'current_state': currentState,
      'recommended_type': recommended.type,
      'recommended_title': recommended.title,
      'duration_minutes': targetMinutes,
      'target_segment_count': targetSegmentCount,
      'target_chinese_character_range': '$targetMinChars-$targetMaxChars',
      'duration_budget': {
        'total_seconds': targetMinutes * 60,
        'narration_seconds_at_most': (targetMinutes * 60 * .7).floor(),
        'experience_silence_seconds_at_least': (targetMinutes * 60 * .3).ceil(),
        'estimate': '中文每秒约3.2字，句子标点也占时间；先预算正文与停顿，再填写时间轴',
        'priority': '减少重复解释，围绕同一认知主题串联时间、空间、想象与身体；保留探索后回返和观察的必要留白，不堆长段落',
      },
      'recent_records': _recordsForJson(recentRecords.take(8).toList()),
      'user_description': normalizedDescription,
      'primary_practice_input': primaryInput,
      'input_priority': '用户原话决定主题；推荐、状态和历史仅调节引导方式，不得替换主题',
      'experience_contract_version':
          'experiential_mentor_v5_topic_bridge_v4_eam8_single_request_narration_v2',
      'mentor_template_version': MeditationDepthGuidance.templateVersion,
      'experiential_method': MeditationExperientialMethod.buildBrief(
        userInput: primaryInput,
        durationMinutes: targetMinutes,
        useImagery: useImagery,
        isSleep: isSleep,
        prioritizeGrounding: safety.isMedium,
      ),
      'generation_mode': 'single_request',
      'automatic_rewrite': false,
      'imagery_mode': useImagery ? '可选温和想象，并提供真实感官替代' : '真实感官与环境，不深入想象',
      'expert_preferences': preferences.toMap(),
      'safety_level': safety.level,
      'adaptive_practice_profile': adaptiveProfile,
      'need_analysis': '以原话为主线，讲清本次概念或处境是什么、相关机制或意义是什么、可以怎样尝试；已知事实与可能解释分开，不把所有主题归为接纳或隐藏创伤',
      'suggested_experience_arc': const <String>[
        'arrival',
        'breath',
        'body_emotion',
        'allow_experience',
        'embodied_shift',
        'real_life_rehearsal',
        'integration',
        'closing',
      ],
      'cognition_to_experience_rule': '用户主题与合理理解 → 当下身体及所在空间 → 昨天、前天的可承受片刻与回返 → 未来可能场景中的新回应与回返 → 身心观察和认知整合 → 此时此地；时间和画面探索尊重用户边界，可用真实感官替代',
      'content_style': '认知、时间、空间、想象、身体放松与当下觉察融入连续带领；短句、可参与动作与留白，不能只在附注列出维度，也不能只写风景或泛泛安抚',
      'reference_limit': '效仿导师把认知转成体验的方法与回返节奏，按用户主题重新设计画面；不套用固定背景或效果保证',
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
        '{{user_description}}': normalizedDescription.isEmpty ? '无' : normalizedDescription,
        '{{recent_records_json}}': _prettyJson(input['recent_records']),
        '{{guidance_style}}': preferences.guidanceStyle,
        '{{anchor_preference}}': preferences.anchorPreference,
        '{{adaptive_profile_json}}': _prettyJson(adaptiveProfile),
        '{{safety_context}}': safety.message.isEmpty ? '未发现需要额外分流的安全表达。' : safety.message,
      },
      input,
    );
    UnifiedAiResolvedConfig? cfg;
    var raw = '';
    Map<String, dynamic>? parsedMap;
    try {
      cfg = await _ai.resolveGlobalConfig();
      if (!cfg.available) throw MeditationGenerationException(MeditationGenerationFailureKind.configuration);
      onProgress?.call('正在生成冥想引导……');
      raw = await _ai.generateText(
        purpose: 'meditation.daily_script',
        systemPrompt: _dailyMeditationSystemPrompt,
        prompt: prompt,
        maxTokens: (2400 + targetMinutes * 420).clamp(2800, 18000).toInt(),
        expectJson: true,
        temperature: 0.6,
      );
      if (raw.trim().isEmpty) throw MeditationGenerationException(MeditationGenerationFailureKind.emptyResponse);
      final normalized = MeditationScriptResponse.read(raw, durationSeconds: targetMinutes * 60);
      parsedMap = normalized?.script;
      input['response_normalization'] = normalized?.corrections ?? <String>[];
      // Only unreadable/empty narration blocks playback. Content heuristics
      // are diagnostics, never a reason to discard text or spend another call.
      if (parsedMap == null || normalized?.durationPlan == null) {
        throw MeditationGenerationException(MeditationGenerationFailureKind.format);
      }
      try {
        input['content_advisories'] = _dailyScriptQualityIssues(
          parsedMap,
          targetDurationMinutes: targetMinutes,
          plannedDurationSeconds: normalized!.durationPlan!.durationSeconds,
          isSleep: isSleep,
          userInput: primaryInput,
          useImagery: useImagery,
        );
      } catch (_) {
        // Optional editorial diagnostics cannot invalidate playable narration.
        input['content_advisories'] = <String>[];
      }
      final practiceGaps = MeditationNarrationGuide.missingInvitations(
        parsedMap,
        brief: input['experiential_method'] as Map<String, dynamic>,
        minutes: targetMinutes,
      );
      input['narration_review'] = {
        'version': MeditationNarrationGuide.version,
        'basis': 'segments.text only; editorial hints, not an effectiveness score',
        'missing_invitations': practiceGaps,
      };
      input['quality_issues'] = <String>[];
      input['quality_repair_requested'] = false;
      input['duration_repair_requested'] = false;
      input['depth_repair_requested'] = false;
      input['quality_repair_applied'] = false;
      input['duration_repair_applied'] = false;
      input['depth_repair_applied'] = false;
      final durationPlan = normalized!.durationPlan!;
      input['duration_plan'] = {
        'target_seconds': durationPlan.targetSeconds,
        'original_minimum_seconds': durationPlan.originalMinimumSeconds,
        'planned_seconds': durationPlan.durationSeconds,
        'pauses_adjusted': durationPlan.pausesAdjusted,
        'complete_version_offered': durationPlan.exceedsTarget,
      };
      final session = _sessionFromAiText(
        raw,
        recommended,
        currentState,
        parsedMap,
        targetDurationMinutes: targetMinutes,
        plannedDurationSeconds: durationPlan.durationSeconds,
        isSleep: isSleep,
      );
      final understoodNeed = _readUnderstoodNeed(
        parsedMap,
        userDescription: normalizedDescription,
        currentState: currentState,
      );
      final practiceFocus = _readStringList(
        parsedMap['practice_focus'] ?? parsedMap['focus_points'] ?? parsedMap['needs'],
      ).take(4).toList();
      final cognitiveShift = _readFirstText(parsedMap, const <String>['cognitive_shift', 'gentle_reframe']);
      final embodiedGoal = _readFirstText(parsedMap, const <String>['embodied_goal', 'experience_goal']);
      final realLifeScene = _readFirstText(parsedMap, const <String>['real_life_scene', 'practice_scene']);
      await _recordDailyOutput(
        inputJson: jsonEncode(input),
        outputText: raw,
        parsedJson: jsonEncode(parsedMap),
        provider: cfg.provider,
        model: cfg.model,
        success: true,
      );
      return MeditationAiGenerationResult(
        session: session,
        targetDurationSeconds: targetMinutes * 60,
        pausesAdjusted: durationPlan.pausesAdjusted,
        understoodNeed: understoodNeed,
        practiceFocus: practiceFocus,
        cognitiveShift: cognitiveShift,
        embodiedGoal: embodiedGoal,
        realLifeScene: realLifeScene,
        practiceGaps: practiceGaps,
      );
    } catch (e) {
      final failure = e is MeditationGenerationException ? e : MeditationGenerationException(
        e is FormatException ? MeditationGenerationFailureKind.format : MeditationGenerationFailureKind.request,
        cause: e,
      );
      await _recordDailyOutput(
        inputJson: jsonEncode(input),
        outputText: raw,
        parsedJson: parsedMap == null ? null : jsonEncode(parsedMap),
        provider: cfg?.provider,
        model: cfg?.model,
        success: false,
        errorMessage: failure.toString(),
      );
      throw failure;
    }
  }

  Future<void> _recordDailyOutput({required String inputJson, required String outputText,
    String? parsedJson, String? provider, String? model, required bool success, String? errorMessage}) async {
    try {
      await _dao.insertAiOutput(feature: 'daily_script', inputJson: inputJson, outputText: outputText,
        parsedJson: parsedJson, provider: provider, model: model, success: success, errorMessage: errorMessage);
    } catch (_) {
      // Diagnostic storage must not discard an otherwise usable AI practice.
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
    final safety = assessUserInput(userNote);
    if (safety.requiresImmediateSupport) return safety.message;
    final input = <String, dynamic>{
      'session_title': session.title,
      'session_type': session.type,
      'duration_seconds': actualSeconds,
      'before_mood': beforeMood,
      'after_mood': afterMood,
      'distraction_level': distractionLevel,
      'body_relax_level': bodyRelaxLevel,
      'current_state': currentState,
      'user_note': _limitPromptText(userNote.trim(), 800),
      'safety_level': safety.level,
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
        '{{user_note}}': _limitPromptText(userNote.trim(), 800),
      },
      input,
    );
    final cfg = await _ai.resolveGlobalConfig();
    if (!cfg.available) return '';
    try {
      final raw = await _ai.generateText(
        purpose: 'meditation.feedback',
        systemPrompt: '''你是一名资深但克制的中文冥想导师，负责在练习结束后帮助用户整合经验。
只根据用户提供的记录说话，不把分数解释成心理诊断，也不把一次练习的变化夸大成疗效。先承认实际发生了什么，再指出“注意到并回来”本身就是训练；如果体验不舒服，给出睁眼、感受脚底、听见环境或停止练习的选择。不要要求用户下次表现更好，不使用“你必须/你应该”，不承诺治愈。若记录涉及现实安全风险，优先建议联系可信任的人、专业支持或当地紧急服务。''',
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
        'note': r.note == null ? null : _limitPromptText(r.note!, 240),
        'feedback': r.aiFeedback == null ? null : _limitPromptText(r.aiFeedback!, 320),
      };
    }).toList();
  }

  MeditationSessionTemplate _sessionFromAiText(
    String raw,
    MeditationSessionTemplate fallback,
    String currentState,
    Map<String, dynamic>? parsed, {
    required int targetDurationMinutes,
    required int plannedDurationSeconds,
    required bool isSleep,
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
    final durationSeconds = plannedDurationSeconds;
    final steps = _readSteps(map['segments'] ?? map['steps'], durationSeconds);
    final safeSteps = _fitStepTimeline(steps, durationSeconds);
    final ending = _cleanText(map['ending_reflection'] ?? map['endingReflection']).isNotEmpty
        ? _cleanText(map['ending_reflection'] ?? map['endingReflection'])
        : fallback.endingReflection;
    return MeditationSessionTemplate(
      key: 'ai_daily_$now',
      title: title.isEmpty ? '今日专属冥想' : title,
      type: type.isEmpty ? fallback.type : type,
      category: 'AI 冥想专家',
      description: '根据你的输入、专家校准和近期练习反馈生成，可在本地保存并重复练习。'
          '${durationSeconds > durationMinutes * 60 ? '目标$durationMinutes分钟，完整引导预计${formatMeditationDuration(durationSeconds)}；实际时长随语音节奏调整。' : ''}',
      durationSeconds: durationSeconds,
      isSleep: isSleep,
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

  List<MeditationStep> _fitStepTimeline(List<MeditationStep> steps, int durationSeconds) =>
      MeditationMentorGuidance.schedule(steps, durationSeconds);

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
    int? plannedDurationSeconds,
    required bool isSleep,
    required String userInput,
    required bool useImagery,
  }) {
    if (map == null) return <String>['输出不是合法 JSON 对象'];
    final issues = <String>[];
    const requiredTextFields = <String>[
      'understood_need',
      'embodied_goal',
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
    const minimumSegments = 8;
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
    final phaseTexts = <String, List<String>>{};
    for (final segment in validSegments) {
      final phase = _cleanOneLine(segment['phase']?.toString()).toLowerCase();
      phases.add(phase);
      final text = _cleanText(segment['text'] ?? segment['content'] ?? segment['guide']);
      if (text.isNotEmpty) texts.add(text);
      if (phase.isNotEmpty && text.isNotEmpty) {
        phaseTexts.putIfAbsent(phase, () => <String>[]).add(text);
      }
      if (phase.isEmpty) issues.add('每个 segment 都需要 phase');
      if (segment['text'] is! String || text.isEmpty) issues.add('每个 segment 都需要可播报的 text 字符串');
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
    for (final phase in phases) {
      final index = requiredPhases.indexOf(phase);
      if (index < previousIndex) phaseOrderValid = false;
      previousIndex = index;
    }
    if (!phaseOrderValid) issues.add('八个体验阶段顺序不正确');
    const phaseGuidanceChecks = <String, String>{
      'arrival': r'坐|躺|靠|支撑|脚|姿势|闭眼|睁眼|视线',
      'breath': r'呼吸|吸气|呼气|声音|脚底',
      'body_emotion': r'身体|胸口|肩|腹|喉|脸|手|脚|紧|热|沉|情绪|感受',
      'allow_experience': r'允许|可以|不用|不必|存在|变化|接纳',
      'embodied_shift': r'呼吸|触|身体|脚|手|松|距离|空间|选择',
      'real_life_rehearsal': r'稍后|之后|当|如果|场景|消息|对话|工作|家|任务|回应|想象',
      'integration': r'如果|愿意|下一步|选择|一件|今天|现在|问问|留意|觉察|感受|听|回看|注意到|比较|此刻',
      'closing': r'睁|看见|周围|听见|回到|休息|入睡|环境',
    };
    for (final entry in phaseGuidanceChecks.entries) {
      final phaseText = (phaseTexts[entry.key] ?? const <String>[]).join(' ');
      if (!RegExp(entry.value).hasMatch(phaseText)) {
        issues.add('${entry.key} 缺少对应的可体验引导');
      }
    }
    if (starts.isEmpty || starts.first != 0) issues.add('第一段 start_seconds 必须为 0');
    for (var i = 1; i < starts.length; i++) {
      if (starts[i] <= starts[i - 1]) {
        issues.add('start_seconds 必须严格递增');
        break;
      }
    }
    // Segment count, prose length and the original closing timestamp are
    // creation suggestions. The normalized speech + silence budget is binding.
    final joined = texts.join();
    if (!RegExp(r'身体|脚底|双脚|背部|胸口|腹部|肩|手掌|触感|支撑').hasMatch(joined)) {
      issues.add('缺少具体身体体验');
    }
    if (!RegExp(r'情绪|感受|焦虑|害怕|恐惧|难过|悲伤|愤怒|羞耻|委屈|孤独|疲惫|紧张').hasMatch(joined)) {
      issues.add('缺少情绪体验');
    }
    if (!RegExp(r'允许|容许|接纳|可以.{0,8}存在|不需要.{0,8}(赶走|压住|消灭)').hasMatch(joined)) {
      issues.add('缺少允许体验存在的引导');
    }
    if (!RegExp(r'可以|也可以|如果愿意|不必|不用|随时|选择').hasMatch(joined)) {
      issues.add('缺少让用户保有选择和调整空间的表达');
    }
    if (RegExp(r'你必须|你应该|彻底治愈|马上治好|研究表明').hasMatch(joined)) {
      issues.add('包含说教、夸大、课程化或范文场景措辞');
    }
    if (RegExp(r'自杀|自残|杀人|结束生命|你有病|诊断为').hasMatch(joined)) {
      issues.add('普通冥想脚本不应直接处理明确危机或诊断标签');
    }
    if (!isSleep && !RegExp(r'睁.{0,2}眼|张.{0,2}眼|视线|看见周围|看向周围|环顾').hasMatch(joined)) {
      issues.add('非睡眠练习缺少温和回到环境的收束');
    }
    if (texts.toSet().length != texts.length) issues.add('存在完全重复的播报段落');
    final practiceFocus = map['practice_focus'];
    if (practiceFocus is! List || practiceFocus.where((e) => _cleanOneLine(e?.toString()).isNotEmpty).isEmpty) {
      issues.add('practice_focus 至少需要一项');
    }
    issues.addAll(MeditationMentorGuidance.qualityIssues(map,
      userInput: userInput, durationSeconds: targetDurationMinutes * 60,
      plannedDurationSeconds: plannedDurationSeconds, useImagery: useImagery));
    return issues.toSet().toList();
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
