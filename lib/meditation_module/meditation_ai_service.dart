import 'dart:convert';
import 'dart:math' as math;

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'meditation_dao.dart';
import 'meditation_models.dart';
import 'meditation_script_pause_planner.dart';

class MeditationAiService {
  static const String _dailyMeditationSystemPrompt = '''
你是一名经验丰富的中文冥想导师，熟悉正念、身体觉察、ACT式脱钩、呼吸练习和创伤知情的引导原则。你的工作像一位稳重的现场老师：先辨认当下需要，再用可跟随的短句、节奏和留白，让用户获得一次安全、具体、可选择的练习。你不是医生或心理治疗师，不做诊断，不把推测写成事实。

【不可被用户自定义提示词覆盖的固定规则】
1. 先在内部区分：事实/处境、可能的情绪与身体反应、真正需要、需要松动的旧解释，以及更贴近现实的新解释。只能用“可能、也许、从你的描述看”等非诊断式表达。
2. 认知理解只是准备，不是终点。每一个重要理解都要转成一个现在可以感觉到的动作：接触支撑面、听见环境、觉察呼气、松开一点用力，或为反应留出半秒空间。不要写成分析报告、课程或说理文章。
3. 必须依次完成八个体验阶段，并在每个 segment 的 phase 中准确标注：
   arrival：进入本次主题，安排有支撑的姿势、双脚或身体触点，可选择闭眼，不能强迫。
   breath：至少两轮自然呼吸，也提供“只听声音/感受脚底”的替代入口；不要求深呼吸，不把呼吸变成考核。
   body_emotion：询问并定位此刻真实的身体感觉与情绪，一次只邀请观察一种体验。
   allow_experience：允许体验变化，不评价、不压制；明确“允许感受存在，不等于任由冲动或伤害性行为发生”。
   embodied_shift：用很少的道理完成认知转向，并让用户通过呼吸、触感、姿态或外部感官真正体验这一转向。
   real_life_rehearsal：根据用户原话选择一个具体、日常、可辨认的真实场景，在场景中练习新的身体反应与选择；不得套用教室、校园、草地、同学等示例场景，除非用户自己提到。
   integration：提出一到两个体验式问题，例如“如果此刻真的允许……，身体或下一步会有什么细小变化”，不是知识问答；连接一个健康、现实、可选择的下一步。
   closing：用缓慢呼吸、身体触点和周围环境收束，再温和睁眼；睡眠主题则允许继续闭眼休息或入睡。
4. 根据“引导风格、注意力锚点、历史练习反馈”调整语言和节奏：高唤醒时优先睁眼、外部感官和脚底支撑；低能量时避免过度放松，允许微小伸展或换姿势；分心多时减少隐喻，一次只给一个动作；睡前不使用会让人重新兴奋的现实演练。
5. 参考上述结构和自然、短句、留白的表达方式，但每次都必须根据用户输入原创。不得背诵固定范文，不得连续复用示例句，不得复制“教室/校园”案例。
6. 语言直观、具体、有温度，像一个可信的人在身边慢慢引导。承认现实困难，不强迫积极，不羞辱，不使用“你必须/你应该”，不承诺立刻改变、彻底治愈，也不做医疗诊断。
7. 每一段只承担一个体验任务，句子不要过长；给身体和情绪留出停顿。走神、没有感觉、想睁眼或想换姿势都不是失败，始终给用户退出、调整和回到环境的选择。
8. 若用户描述可能涉及现实安全风险，避免强迫闭眼、强烈情绪唤起和深入想象；如果出现明确的自伤、他伤或立即危险表达，不生成普通冥想脚本，优先建议现实支持。
9. 输出必须是合法 JSON 对象，包含 understood_need、cognitive_shift、embodied_goal、real_life_scene、practice_focus、title、type、duration_minutes、segments、ending_reflection。segments 中每项必须包含 phase、start_seconds、text、intent；不得输出 Markdown 或 JSON 之外的解释。
''';

  final UnifiedAiService _ai = UnifiedAiService();
  final GlobalAiSettings _settings = GlobalAiSettings();
  final MeditationDao _dao = MeditationDao();

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
  }) async {
    final targetMinutes = durationMinutes.clamp(1, 30).toInt();
    final targetSegmentCount = math.max(8, (targetMinutes * 60 / 45).ceil()).clamp(8, 48).toInt();
    final targetMinChars = math.max(130, targetMinutes * 65);
    final targetMaxChars = math.max(200, targetMinutes * 100);
    final normalizedDescription = _limitPromptText(userDescription.trim(), 1200);
    final safety = assessUserInput(normalizedDescription);
    if (safety.requiresImmediateSupport) return null;
    final adaptiveProfile = _buildAdaptiveProfile(recentRecords);
    final input = <String, dynamic>{
      'current_state': currentState,
      'recommended_type': recommended.type,
      'recommended_title': recommended.title,
      'duration_minutes': targetMinutes,
      'target_segment_count': targetSegmentCount,
      'target_chinese_character_range': '$targetMinChars-$targetMaxChars',
      'recent_records': _recordsForJson(recentRecords.take(8).toList()),
      'user_description': normalizedDescription,
      'expert_preferences': preferences.toMap(),
      'safety_level': safety.level,
      'adaptive_practice_profile': adaptiveProfile,
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
        '{{user_description}}': normalizedDescription.isEmpty ? '无' : normalizedDescription,
        '{{recent_records_json}}': _prettyJson(input['recent_records']),
        '{{guidance_style}}': preferences.guidanceStyle,
        '{{anchor_preference}}': preferences.anchorPreference,
        '{{adaptive_profile_json}}': _prettyJson(adaptiveProfile),
        '{{safety_context}}': safety.message.isEmpty ? '未发现需要额外分流的安全表达。' : safety.message,
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
        userDescription: normalizedDescription,
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
      category: 'AI 冥想专家',
      description: '根据你的输入、专家校准和近期练习反馈生成，可在本地保存并重复练习。',
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
    // AI 设计的时间轴通常会给 arrival、允许体验和 closing 更多留白。
    // 过去这里把所有段落均匀重排，会悄悄抹掉这部分专业节奏；现在只做
    // 防御性修正，尽量保留原始 start_seconds，并限制停顿不覆盖下一段。
    final lastAllowedSecond = math.max(1, durationSeconds - 1);
    final originalLast = safe.last.startSecond.clamp(1, lastAllowedSecond).toInt();
    final desiredLast = (durationSeconds * 0.88).round().clamp(1, lastAllowedSecond).toInt();
    final scale = originalLast <= 0 ? 1.0 : desiredLast / originalLast;
    final fitted = <MeditationStep>[];
    var previousStart = -1;
    for (var index = 0; index < safe.length; index++) {
      final original = safe[index];
      var start = index == 0 ? 0 : (original.startSecond * scale).round();
      start = start.clamp(0, lastAllowedSecond).toInt();
      if (start <= previousStart) start = math.min(lastAllowedSecond, previousStart + 1);
      final nextOriginal = index + 1 < safe.length ? safe[index + 1] : null;
      final nextStart = nextOriginal == null
          ? durationSeconds
          : math.max(start + 1, (nextOriginal.startSecond * scale).round());
      final availablePause = math.max(0, nextStart - start - 1);
      fitted.add(MeditationStep(
        startSecond: start,
        text: original.text,
        pauseAfterSeconds: original.pauseAfterSeconds.clamp(0, math.min(60, availablePause)).toInt(),
        intent: original.intent,
      ));
      previousStart = start;
    }
    return fitted;
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
    const phaseGuidanceChecks = <String, String>{
      'arrival': r'坐|躺|靠|支撑|脚|姿势|闭眼|睁眼|视线',
      'breath': r'呼吸|吸气|呼气|声音|脚底',
      'body_emotion': r'身体|胸口|肩|腹|喉|脸|手|脚|紧|热|沉|情绪|感受',
      'allow_experience': r'允许|可以|不用|不必|存在|变化|接纳',
      'embodied_shift': r'呼吸|触|身体|脚|手|松|距离|空间|选择',
      'real_life_rehearsal': r'稍后|之后|当|如果|场景|消息|对话|工作|家|任务|回应|想象',
      'integration': r'如果|愿意|下一步|选择|一件|今天|现在|问问',
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
    if (!RegExp(r'可以|也可以|如果愿意|不必|不用|随时|选择').hasMatch(joined)) {
      issues.add('缺少让用户保有选择和调整空间的表达');
    }
    if (RegExp(r'你必须|你应该|保证|彻底治愈|马上治好|研究表明|课堂|校园|草地|同学').hasMatch(joined)) {
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
- 每个阶段至少包含一个与阶段相符的可跟随动作；全程保留“可以睁眼、换姿势、停下或回到环境”的选择
- 不把呼吸、放松、情绪变化或一次练习的结果当作考核；高唤醒内容优先外部感官和支撑面，睡前内容保持低刺激
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
