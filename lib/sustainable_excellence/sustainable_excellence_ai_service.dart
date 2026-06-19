import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'sustainable_excellence_models.dart';
import 'sustainable_excellence_prompt_config.dart';

class SustainableExcellenceAiResult {
  final SustainableExcellenceCase item;
  final String provider;
  final String modelLabel;
  final bool fromFallback;

  const SustainableExcellenceAiResult({
    required this.item,
    required this.provider,
    required this.modelLabel,
    required this.fromFallback,
  });
}

class SustainableExcellenceAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final SustainableExcellencePromptConfig _prompts = SustainableExcellencePromptConfig();

  Future<Map<String, String>> getGlobalAiState() async {
    try {
      return await _settings.getState();
    } catch (_) {
      return <String, String>{'provider': 'none', 'model': 'none', 'label': '未配置（将使用内置策略）', 'available': '0'};
    }
  }

  Future<SustainableExcellenceAiResult> generateCase({
    required String userGoal,
    required String userState,
    String source = 'manual',
    String extraContext = '',
  }) async {
    final state = await getGlobalAiState();
    final available = (state['available'] ?? '0') == '1';
    if (available) {
      final prompt = '${await _prompts.buildGoalToExperimentPrompt(userGoal: userGoal, userState: userState, source: source, extraContext: extraContext)}\n\n${await _prompts.getPrompt(SustainableExcellencePromptConfig.outputCommonId)}';
      try {
        final raw = await _ai.generateText(
          prompt: prompt,
          purpose: 'sustainable_excellence.generate_case',
          systemPrompt: await _prompts.getPrompt(SustainableExcellencePromptConfig.globalId),
          maxTokens: 2600,
          expectJson: true,
          temperature: 0.35,
        );
        final parsed = _parseJson(raw);
        if (parsed != null) {
          parsed['id'] = parsed['id'] ?? _newId();
          parsed['source'] = source;
          final ctxTodoId = _contextValue(extraContext, 'source_todo_id');
          final ctxListId = _contextValue(extraContext, 'source_list_id');
          if ((parsed['source_todo_id'] ?? '').toString().trim().isEmpty) parsed['source_todo_id'] = ctxTodoId;
          if ((parsed['source_list_id'] ?? '').toString().trim().isEmpty) parsed['source_list_id'] = ctxListId;
          parsed['linked_todo_task_id'] = parsed['linked_todo_task_id'] ?? '';
          parsed['generated_todo_task_ids'] = parsed['generated_todo_task_ids'] ?? <String>[];
          parsed['spiral_stage'] = parsed['spiral_stage'] ?? 'experiment';
          parsed['spiral_cycle_count'] = parsed['spiral_cycle_count'] ?? 0;
          parsed['last_failure_type'] = parsed['last_failure_type'] ?? '';
          parsed['last_recovery_at_ms'] = parsed['last_recovery_at_ms'] ?? 0;
          parsed['last_action_at_ms'] = parsed['last_action_at_ms'] ?? 0;
          parsed['next_recommended_stage'] = parsed['next_recommended_stage'] ?? 'action';
          parsed['archived_at_ms'] = parsed['archived_at_ms'] ?? 0;
          parsed['user_goal'] = (parsed['user_goal'] ?? userGoal).toString();
          parsed['provider'] = state['provider'] ?? 'global_ai';
          parsed['model_label'] = state['label'] ?? state['model'] ?? 'AI';
          parsed['created_at_ms'] = DateTime.now().millisecondsSinceEpoch;
          parsed['updated_at_ms'] = DateTime.now().millisecondsSinceEpoch;
          final item = SustainableExcellenceCase.fromJson(parsed);
          return SustainableExcellenceAiResult(
            item: item,
            provider: item.provider,
            modelLabel: item.modelLabel,
            fromFallback: false,
          );
        }
      } catch (_) {
        // fall through to local fallback
      }
    }

    final fallback = _buildFallbackCase(
      userGoal: userGoal,
      userState: userState,
      source: source,
      extraContext: extraContext,
      provider: available ? (state['provider'] ?? 'global_ai_error') : 'local',
      modelLabel: available ? '${state['label'] ?? 'AI'}（解析失败，已用内置策略兜底）' : '内置策略',
    );
    return SustainableExcellenceAiResult(
      item: fallback,
      provider: fallback.provider,
      modelLabel: fallback.modelLabel,
      fromFallback: true,
    );
  }

  String _contextValue(String context, String key) {
    final raw = context.trim();
    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return (decoded[key] ?? '').toString().trim();
      } catch (_) {}
    }
    final match = RegExp(r'(?:^|[;\n])\s*' + RegExp.escape(key) + r'=([^;\n]*)').firstMatch(context);
    return match == null ? '' : (match.group(1) ?? '').trim();
  }

  Map<String, dynamic>? _parseJson(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .replaceAll('```', '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) text = text.substring(start, end + 1);
    final decoded = jsonDecode(text);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }



  Future<Map<String, dynamic>> generateFailureReview({
    required SustainableExcellenceCase item,
    required SustainableActionExperiment experiment,
    required String actualResult,
    required String emotion,
  }) async {
    final history = item.logs.take(8).map((e) => '${e.type}: ${e.note}').join('\n');
    final state = await getGlobalAiState();
    final available = (state['available'] ?? '0') == '1';
    if (available) {
      try {
        final raw = await _ai.generateText(
          prompt: await _prompts.buildFailureReviewPrompt(
            goal: item.userGoal,
            experiment: experiment.title,
            actualResult: actualResult,
            emotion: emotion,
            history: history,
          ),
          purpose: 'sustainable_excellence.failure_review',
          systemPrompt: await _prompts.getPrompt(SustainableExcellencePromptConfig.globalId),
          maxTokens: 1500,
          expectJson: true,
          temperature: 0.25,
        );
        return _parseJson(raw) ?? _fallbackFailureReview(item, actualResult, emotion);
      } catch (_) {}
    }
    return _fallbackFailureReview(item, actualResult, emotion);
  }


  Future<Map<String, dynamic>> generatePerfectionismScan({
    required SustainableExcellenceCase item,
    required String userInput,
  }) async {
    final state = await getGlobalAiState();
    final available = (state['available'] ?? '0') == '1';
    if (available) {
      try {
        final raw = await _ai.generateText(
          prompt: await _prompts.buildPerfectionismScanPrompt(userInput: userInput, context: item.toJson().toString()),
          purpose: 'sustainable_excellence.perfectionism_scan',
          systemPrompt: await _prompts.getPrompt(SustainableExcellencePromptConfig.globalId),
          maxTokens: 1400,
          expectJson: true,
          temperature: 0.25,
        );
        return _parseJson(raw) ?? _fallbackPerfectionismScan(item, userInput);
      } catch (_) {}
    }
    return _fallbackPerfectionismScan(item, userInput);
  }

  Future<Map<String, dynamic>> generatePressureRecoveryPlan({
    required SustainableExcellenceCase item,
    required String stateText,
  }) async {
    final state = await getGlobalAiState();
    final available = (state['available'] ?? '0') == '1';
    if (available) {
      try {
        final raw = await _ai.generateText(
          prompt: await _prompts.buildPressureRecoveryPrompt(tasks: item.userGoal, state: stateText),
          purpose: 'sustainable_excellence.pressure_recovery',
          systemPrompt: await _prompts.getPrompt(SustainableExcellencePromptConfig.globalId),
          maxTokens: 1400,
          expectJson: true,
          temperature: 0.25,
        );
        return _parseJson(raw) ?? _fallbackPressureRecovery(item, stateText);
      } catch (_) {}
    }
    return _fallbackPressureRecovery(item, stateText);
  }

  Future<Map<String, dynamic>> generateProcessReframe({
    required SustainableExcellenceCase item,
    required String task,
    required String feeling,
  }) async {
    final state = await getGlobalAiState();
    final available = (state['available'] ?? '0') == '1';
    if (available) {
      try {
        final raw = await _ai.generateText(
          prompt: await _prompts.buildProcessEnjoymentPrompt(task: task, feeling: feeling, context: item.toJson().toString()),
          purpose: 'sustainable_excellence.process_reframe',
          systemPrompt: await _prompts.getPrompt(SustainableExcellencePromptConfig.globalId),
          maxTokens: 1400,
          expectJson: true,
          temperature: 0.25,
        );
        return _parseJson(raw) ?? _fallbackProcessReframe(item, task, feeling);
      } catch (_) {}
    }
    return _fallbackProcessReframe(item, task, feeling);
  }

  Future<SustainableDailyReview> generateDailyReview({
    required List<SustainableExcellenceCase> cases,
    String reviewType = 'daily',
  }) async {
    final casesSummary = cases.take(12).map((e) => '${e.title} / 阶段:${SustainableSpiralStage.label(e.spiralStage)} / 证据:${e.logs.length}').join('\n');
    final logsSummary = cases.expand((e) => e.logs).take(40).map((e) => '${e.type}: ${e.note}').join('\n');
    final state = await getGlobalAiState();
    final available = (state['available'] ?? '0') == '1';
    if (available) {
      try {
        final raw = await _ai.generateText(
          prompt: await _prompts.buildDailyReviewPrompt(casesSummary: casesSummary, logsSummary: logsSummary, reviewType: reviewType),
          purpose: 'sustainable_excellence.daily_review',
          systemPrompt: await _prompts.getPrompt(SustainableExcellencePromptConfig.globalId),
          maxTokens: 1800,
          expectJson: true,
          temperature: 0.25,
        );
        final parsed = _parseJson(raw);
        if (parsed != null) {
          parsed['id'] = parsed['id'] ?? 'sr_${DateTime.now().microsecondsSinceEpoch}';
          parsed['review_type'] = parsed['review_type'] ?? reviewType;
          parsed['created_at_ms'] = DateTime.now().millisecondsSinceEpoch;
          return SustainableDailyReview.fromJson(parsed);
        }
      } catch (_) {}
    }
    return _fallbackDailyReview(cases, reviewType: reviewType);
  }


  Map<String, dynamic> _fallbackPerfectionismScan(SustainableExcellenceCase item, String userInput) {
    final text = userInput.toLowerCase();
    final high = _hasAny(text, const <String>['完美', '提交', '反复', '害怕', '失败', '评价', '不敢']);
    return <String, dynamic>{
      'mode': high ? 'mixed' : 'excellence',
      'preserve': item.valueMapping.preserve,
      'adjust': high ? <String>['把结果等同于自我价值', '因为害怕不完美而推迟开始或提交'] : item.valueMapping.adjust,
      'explanation': '这不是简单懒惰，而是目标关系和失败关系需要被调小、调清楚。保留高标准，同时把行动改成可以试错的实验。',
      'practices': <Map<String, dynamic>>[
        <String, dynamic>{'title': '提交不完美版本练习', 'steps': <String>['定义最低可交付标准', '提交一个可反馈版本'], 'gentle_reminder': '反馈循环比无错幻想更接近卓越。'},
        <String, dynamic>{'title': '5分钟粗糙开始练习', 'steps': <String>['打开材料', '只做第一小步'], 'gentle_reminder': '先练习开始，不证明完美。'},
      ],
    };
  }

  Map<String, dynamic> _fallbackPressureRecovery(SustainableExcellenceCase item, String stateText) {
    final high = _hasAny(stateText.toLowerCase(), const <String>['累', '疲惫', '压力', '焦虑', '崩', '睡眠']);
    return <String, dynamic>{
      'pressure_level': high ? 'high' : item.modeDetection.pressureLevel,
      'recovery_gap': high ? 'insufficient' : item.modeDetection.recoveryLevel,
      'explanation': '压力本身不是敌人，但没有恢复的压力会破坏长期表现。',
      'must_do_tasks': <String>[item.userGoal],
      'shrink_tasks': <String>['把下一步缩小到 5-25 分钟内可执行。'],
      'micro_recovery': item.recoveryPlan.microRecovery,
      'medium_recovery': item.recoveryPlan.mediumRecovery,
      'deep_recovery': item.recoveryPlan.deepRecovery,
      'rhythm': high ? '25/5' : '45/8',
      'warning': '不要把硬撑误认为自律；恢复也是训练的一部分。',
    };
  }

  Map<String, dynamic> _fallbackProcessReframe(SustainableExcellenceCase item, String task, String feeling) {
    return <String, dynamic>{
      'validation': '不需要强迫自己喜欢这个过程，只需要找到 1% 可以体验的掌控、能力或意义。',
      'long_term_value': item.processEnjoyment.meaningConnection,
      'one_percent_experience': <String>['掌控感：我能控制下一小步', '能力感：我正在练习开始', '意义感：这连接到长期目标'],
      'process_anchor': item.processEnjoyment.duringActionReminder,
      'low_pressure_method': '只做 5 分钟，把它当成一次观察实验。',
      'during_action_sentence': '我不是在证明完美，我是在积累反馈。',
      'after_action_questions': <String>['哪一小步让我更清楚？', '下次只保留哪个条件？'],
    };
  }

  Map<String, dynamic> _fallbackFailureReview(SustainableExcellenceCase item, String actualResult, String emotion) {
    final text = '$actualResult\n$emotion'.toLowerCase();
    final repeated = item.logs.where((e) => e.type == 'failure_learning').length >= 2;
    final failureType = _hasAny(text, const <String>['累', '疲惫', '睡眠', '没力'])
        ? '恢复不足'
        : _hasAny(text, const <String>['怕', '不敢', '失败', '评价', '丢脸'])
            ? '完美主义拖延'
            : _hasAny(text, const <String>['太大', '复杂', '不知道'])
                ? '任务过大'
                : '启动失败';
    return <String, dynamic>{
      'depersonalized_reframe': '这次失败不是对你价值的判决，而是行动系统暴露出的反馈。',
      'failure_type': failureType,
      'learning_point': repeated ? '你可能一直用同一种策略撞同一堵墙，下一轮要换变量，而不是只增加压力。' : '这次失败说明下一步需要更小、更具体，并且要配恢复。',
      'is_repeated_pattern': repeated,
      'strategy_change': repeated ? '把任务大小、环境、时间或恢复方式至少改变一个变量。' : '先把下一步缩小到 5 分钟内可开始。',
      'next_smaller_experiment': '打开相关材料，只做第一小步，结束后写一句反馈。',
      'restart_sentence': '我不是从零开始，我是在带着反馈重新开始。',
      'todo_writeback_title': '做一次 5 分钟「${item.userGoal}」重新开始实验',
      'todo_writeback_steps': <String>['打开材料', '只做第一小步', '记录失败暴露的一个变量', '安排 3 分钟微恢复'],
      'spiral_stage': SustainableSpiralStage.failedOrStuck,
    };
  }

  SustainableDailyReview _fallbackDailyReview(List<SustainableExcellenceCase> cases, {required String reviewType}) {
    final logs = cases.expand((e) => e.logs).toList();
    List<String> notes(String type) => logs.where((e) => e.type == type).take(5).map((e) => e.note).toList();
    return SustainableDailyReview(
      id: 'sr_${DateTime.now().microsecondsSinceEpoch}',
      reviewType: reviewType,
      title: reviewType == 'weekly' ? '周度可持续卓越报告' : '今日可持续卓越复盘',
      summary: logs.isEmpty ? '还没有足够证据。下一步不是评价成败，而是先完成一次最小行动或恢复记录。' : '你已经积累了 ${logs.length} 条成长证据，复盘重点应放在行动条件、失败类型、恢复节律和过程连接上。',
      actionEvidence: notes('action').isEmpty ? <String>['先完成一次 5 分钟最小行动，形成第一条证据。'] : notes('action'),
      failurePatterns: notes('failure_learning').isEmpty ? <String>['暂无明显失败模式；若卡住，请先记录一次失败学习。'] : notes('failure_learning'),
      recoveryInsights: notes('recovery').isEmpty ? <String>['恢复记录不足；建议每次行动后补一个微恢复。'] : notes('recovery'),
      processInsights: notes('process').isEmpty ? <String>['过程体验记录不足；只需寻找 1% 的掌控感。'] : notes('process'),
      nextOneVariable: '下一轮只调整一个变量：任务大小、行动时间、环境诱因或恢复方式。',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  SustainableExcellenceCase _buildFallbackCase({
    required String userGoal,
    required String userState,
    required String source,
    String extraContext = '',
    required String provider,
    required String modelLabel,
  }) {
    final text = '$userGoal\n$userState';
    final highPressure = _hasAny(text, const <String>['压力', '焦虑', '崩', '很累', '疲惫', '撑不住', '任务多', '痛苦']);
    final perfection = _hasAny(text, const <String>['完美', '不够好', '怕失败', '害怕失败', '迟迟', '反复改', '提交', '拖延', '必须']);
    final failureFear = _hasAny(text, const <String>['失败', '丢脸', '做不好', '被评价', '不敢', '担心']);
    final processLow = _hasAny(text, const <String>['没意思', '只想快点', '痛苦', '枯燥', '等结果', '看不到意义']);
    final now = DateTime.now().millisecondsSinceEpoch;
    final goal = userGoal.trim().isEmpty ? '推进一个重要目标' : userGoal.trim();

    return SustainableExcellenceCase(
      id: _newId(),
      source: source,
      sourceTodoId: _contextValue(extraContext, 'source_todo_id'),
      sourceListId: _contextValue(extraContext, 'source_list_id'),
      linkedTodoTaskId: '',
      generatedTodoTaskIds: const <String>[],
      title: '「$goal」的可持续卓越实验',
      coreTheme: '压力-恢复-失败-反馈-卓越-过程',
      userGoal: goal,
      currentStateSummary: highPressure
          ? '当前更需要把目标从“硬撑到底”改造成“核心行动 + 主动恢复 + 失败学习”的节律。'
          : '当前适合把目标从抽象愿望转成一个可以尝试、可以失败、可以复盘的小实验。',
      modeDetection: SustainableModeDetection(
        pressureLevel: highPressure ? 'high' : 'medium',
        recoveryLevel: highPressure ? 'insufficient' : 'enough',
        perfectionismLevel: perfection ? 'high' : 'medium',
        failureFearLevel: failureFear ? 'high' : 'medium',
        processConnectionLevel: processLow ? 'low' : 'medium',
      ),
      valueMapping: SustainableValueMapping(
        preserve: const <String>['目标感', '责任感', '认真投入', '想把事情做好', '希望现实变得更好'],
        adjust: <String>[
          if (perfection) '把一次结果等同于自我价值',
          if (failureFear) '害怕失败导致不敢开始',
          if (highPressure) '只增加压力却没有安排恢复',
          '只盯终点而忽略过程中的学习证据',
        ],
        coreReframe: '不是降低追求，而是把“必须完美成功”的直线，改造成“尝试—恢复—失败学习—反馈修正—再行动”的卓越螺旋。',
      ),
      obstacleAnalysis: <SustainableObstacleAnalysis>[
        SustainableObstacleAnalysis(
          obstacle: perfection ? '完美主义启动阻碍' : '目标过大导致启动成本高',
          evidence: perfection ? '描述中出现了怕失败、迟迟行动、反复准备或必须做好的线索。' : '目标还没有被压缩成一个今天就能开始的小动作。',
          changeableVariable: '把目标缩小到 5 分钟内可开始的一步。',
        ),
        SustainableObstacleAnalysis(
          obstacle: highPressure ? '恢复不足' : '缺少过程锚点',
          evidence: highPressure ? '当前状态提示压力较高，继续硬顶可能损害长期表现。' : '如果只盯结果，过程会更容易变成忍耐。',
          changeableVariable: highPressure ? '每轮行动后强制加入微恢复。' : '为行动绑定一个能力感、掌控感或意义感锚点。',
        ),
      ],
      actionExperiments: <SustainableActionExperiment>[
        SustainableActionExperiment(
          type: 'minimum_action',
          title: '5分钟粗糙开始：$goal',
          suitableWhen: '适合压力高、害怕失败、能量低或一直拖延时。',
          steps: <String>['打开与目标相关的材料或页面', '只完成第一小步，不要求完整', '结束时写下一句“我获得了什么反馈”'],
          timeRequired: '5分钟',
          failurePoint: '开始前把任务想成必须完整完成，导致焦虑升高。',
          failureLearningMethod: '如果没有开始，只记录卡住点是任务太大、能量不足、环境诱因还是失败恐惧。',
          recoveryBefore: '行动前做 3 次慢呼吸，提醒自己这只是实验。',
          recoveryAfter: '行动后离开屏幕 3 分钟，喝水或伸展。',
          processAnchor: '我正在练习开始，而不是证明自己完美。',
        ),
        SustainableActionExperiment(
          type: 'standard_action',
          title: '25分钟行动 + 5分钟恢复',
          suitableWhen: '适合能量中等、可以专注一小段时间时。',
          steps: <String>['选定一个明确小块', '计时25分钟，只做这一块', '结束后复盘一个有效条件与一个阻碍'],
          timeRequired: '30分钟',
          failurePoint: '中途分心，或把标准临时抬高。',
          failureLearningMethod: '只分析一个可改变变量，例如时间、地点、任务大小或恢复方式。',
          recoveryBefore: '清理桌面，只保留当前材料。',
          recoveryAfter: '5分钟散步、伸展或闭眼休息。',
          processAnchor: '我在积累行动证据、能力感和反馈。',
        ),
        SustainableActionExperiment(
          type: 'challenge_action',
          title: '提交一个不完美版本',
          suitableWhen: '适合已经准备了一些，但因害怕评价或不完美迟迟不交付时。',
          steps: <String>['定义最低可交付标准', '完成并提交一个版本', '只收集反馈，不反复自我审判'],
          timeRequired: '40-90分钟',
          failurePoint: '反复修改、害怕评价、想等到完全有把握。',
          failureLearningMethod: '把反馈看作版本迭代信息，而不是人格判决。',
          recoveryBefore: '写下“这个版本允许不完美，但必须进入反馈循环”。',
          recoveryAfter: '完成后做一次中恢复，暂时停止反复检查。',
          processAnchor: '真正的卓越来自反馈循环，不来自无错幻想。',
        ),
      ],
      recoveryPlan: SustainableRecoveryPlan(
        microRecovery: const <String>['3次慢呼吸', '闭眼30秒', '喝水', '伸展肩颈', '离开屏幕2分钟'],
        mediumRecovery: const <String>['15分钟散步', '整理桌面', '洗澡', '冥想10分钟', '听一首稳定节奏的音乐'],
        deepRecovery: const <String>['半天低刺激', '保证睡眠', '自然环境散步', '减少社交媒体', '完整休息日'],
        recommendedRhythm: highPressure ? '25分钟行动 + 5分钟恢复；不要连续硬顶超过两轮' : '45分钟行动 + 8分钟恢复，或 25/5 节律',
      ),
      failureLearning: SustainableFailureLearning(
        possibleFailureType: perfection ? '完美主义拖延 / 启动失败' : '目标过大 / 缺少下一步',
        ifFailedThen: '如果失败，先写事实，再写一个可改变变量，不做“我不行”的人格结论。',
        learningQuestion: '这次失败暴露的是任务大小、恢复不足、环境诱因、情绪过载，还是失败恐惧？',
        nextSmallerExperiment: '把下一步缩小为 5 分钟内可以开始的动作。',
      ),
      processEnjoyment: SustainableProcessEnjoyment(
        meaningConnection: '这个目标连接到你的能力、自由、尊严和长期成长。',
        onePercentExperience: processLow ? '不要求喜欢，只寻找 1% 的掌控感或“我开始了”的能力感。' : '留意行动中哪一小步带来了掌控、清晰或成长感。',
        duringActionReminder: '这不是证明我行不行的考试，只是一次获得反馈的实验。',
        afterActionReflection: '这个过程里，哪一部分值得保留到下一次？',
      ),
      todoWriteback: SustainableTodoWriteback(
        nextTodoTitle: '做一次 5 分钟「$goal」最小行动实验',
        nextTodoSteps: const <String>['打开材料', '完成第一小步', '记录一个反馈', '安排微恢复'],
        parentGoal: goal,
        statusLabel: 'attempted',
        evidenceTags: const <String>['已尝试', '失败可学习', '恢复已安排', '过程锚点'],
      ),
      reflectionQuestions: const <String>[
        '今天我处在卓越螺旋的哪一环：目标、尝试、失败、恢复、反馈、修正，还是再行动？',
        '我需要保留的是高标准，还是需要放下自我审判？',
        '这次行动里，哪一个小证据说明我正在前进？',
      ],
      coachMessage: '先不要追求一次性解决全部问题。今天只需要选一个实验，配一个恢复，失败也要留下学习证据。',
      riskNote: '如果你长期处在严重绝望、无法维持基本生活或有自伤风险，请立刻联系现实中可信任的人或专业支持。',
      provider: provider,
      modelLabel: modelLabel,
      selectedExperimentType: '',
      spiralStage: SustainableSpiralStage.experiment,
      spiralCycleCount: 0,
      lastFailureType: '',
      lastRecoveryAtMs: 0,
      lastActionAtMs: 0,
      nextRecommendedStage: SustainableSpiralStage.action,
      archivedAtMs: 0,
      logs: const <SustainableEvidenceLog>[],
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  bool _hasAny(String text, List<String> keys) => keys.any((k) => text.contains(k));

  String _newId() => 'se_${DateTime.now().microsecondsSinceEpoch}';
}
