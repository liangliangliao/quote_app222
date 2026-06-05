import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'goal_setting_dao.dart';
import 'goal_setting_famous_figures.dart';
import 'goal_setting_models.dart';

class GoalSettingAiResult {
  final List<GoalSettingAction> actions;
  final String provider;
  final String modelLabel;
  final bool usedFallback;
  final String generationNote;
  final String rawResponse;

  const GoalSettingAiResult({
    required this.actions,
    required this.provider,
    required this.modelLabel,
    this.usedFallback = false,
    this.generationNote = '',
    this.rawResponse = '',
  });
}

class GoalSettingAiService {
  final GoalSettingDao _goalDao = GoalSettingDao();
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _unifiedAiService = UnifiedAiService();

  Future<Map<String, String>> getGlobalAiState() => _settings.getState();
  Future<String> getUnderstandingPrompt() => _settings.getGoalSettingUnderstandingPrompt();
  Future<String> getActionPrompt() => _settings.getGoalSettingActionPrompt();
  Future<String> getLoopPrompt() => _settings.getGoalSettingLoopPrompt();

  Future<GoalSettingUnderstandingResult> generateUnderstandingAnalysis({
    required GoalSettingSegment segment,
  }) async {
    final state = await getGlobalAiState();
    final fallback = GoalSettingUnderstandingResult(
      whatText: segment.whatText,
      whyText: segment.whyText,
      howText: segment.howSteps.join('；'),
      realCase: segment.cases.join('；'),
      provider: 'local',
      modelLabel: state['label'] ?? '本地策略',
    );
    if (state['available'] != '1') return fallback;
    final basePrompt = await getUnderstandingPrompt();
    final understandingTemplate = _settings.ensurePromptContains(
      basePrompt,
      requiredBlocks: <String, String>{
        'segment_title': '课程标题：{{segment_title}}',
        'original_text': '课程原文（必须完整阅读并紧扣分析）：\n{{original_text}}',
      },
    );
    final prompt = _settings.renderTemplate(
      understandingTemplate,
      <String, String>{
        'segment_title': segment.title,
        'original_text': segment.originalText,
      },
    );
    final raw = await _requestText(prompt: prompt, purpose: 'goal_setting_understanding');
    final parsed = _extractJsonObject(raw);
    if (parsed.isEmpty) return fallback;
    final whatText = ('${parsed['what_text'] ?? ''}').trim();
    final whyText = ('${parsed['why_text'] ?? ''}').trim();
    final howText = ('${parsed['how_to_do'] ?? ''}').trim();
    final realCase = ('${parsed['real_case'] ?? ''}').trim();
    if (whatText.isEmpty || whyText.isEmpty || howText.isEmpty || realCase.isEmpty) return fallback;
    return GoalSettingUnderstandingResult(
      whatText: whatText,
      whyText: whyText,
      howText: howText,
      realCase: realCase,
      provider: state['provider'] ?? 'ai',
      modelLabel: state['label'] ?? 'AI',
    );
  }

  Future<GoalSettingAiResult> generateActionOptions({
    required GoalSettingSegment segment,
    required String userConcern,
  }) async {
    final state = await getGlobalAiState();
    final fallback = _buildLocalActions(segment: segment, userConcern: userConcern);
    if (state['available'] != '1') {
      return GoalSettingAiResult(actions: fallback, provider: 'local', modelLabel: state['label'] ?? '本地策略', usedFallback: true, generationNote: '当前未配置可用 AI，已回退到本地动作草稿。');
    }
    final basePrompt = await getActionPrompt();
    final actionTemplate = _settings.ensurePromptContains(
      basePrompt,
      requiredBlocks: <String, String>{
        'segment_title': '课程标题：{{segment_title}}',
        'original_text': '''课程原文（必须完整阅读并紧扣行动设计）：
{{original_text}}''',
        'core_concepts': '核心概念：{{core_concepts}}',
        'default_action_title': '默认动作标题：{{default_action_title}}',
        'default_action_body': '默认动作说明：{{default_action_body}}',
        'how_steps': '课程建议步骤：{{how_steps}}',
        'user_concern': '用户当前困扰：{{user_concern}}',
      },
    );
    final prompt = _settings.renderTemplate(
      actionTemplate,
      <String, String>{
        'segment_title': segment.title,
        'original_text': segment.originalText,
        'core_concepts': segment.concepts.join('、'),
        'default_action_title': segment.defaultActionTitle,
        'default_action_body': segment.defaultActionBody,
        'how_steps': segment.howSteps.join('；'),
        'user_concern': userConcern.trim().isEmpty ? '未提供，请按一般学习者输出。' : userConcern.trim(),
      },
    );
    try {
      final raw = await _requestText(prompt: prompt, purpose: 'goal_setting_actions');
      if (raw.trim().isEmpty) {
        return GoalSettingAiResult(actions: fallback, provider: state['provider'] ?? 'ai', modelLabel: state['label'] ?? 'AI', usedFallback: true, generationNote: 'AI 返回为空，已回退到本地动作草稿。', rawResponse: raw);
      }
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) {
        if (_looksLikeActionErrorResponse(raw)) {
          return GoalSettingAiResult(actions: fallback, provider: state['provider'] ?? 'ai', modelLabel: state['label'] ?? 'AI', usedFallback: true, generationNote: 'AI 请求返回错误内容，已回退到本地动作草稿。', rawResponse: raw);
        }
        final salvaged = _salvageActionsFromRaw(raw: raw, segment: segment, userConcern: userConcern, fallback: fallback);
        if (salvaged != null && salvaged.isNotEmpty) {
          return GoalSettingAiResult(
            actions: salvaged,
            provider: state['provider'] ?? 'ai',
            modelLabel: state['label'] ?? 'AI',
            usedFallback: false,
            generationNote: 'AI 已返回内容；已放宽结构校验并自动整理为结构化动作，缺失字段已按默认值补齐。',
            rawResponse: raw,
          );
        }
        return GoalSettingAiResult(actions: fallback, provider: state['provider'] ?? 'ai', modelLabel: state['label'] ?? 'AI', usedFallback: true, generationNote: 'AI 已返回，但内容全空或没有可用动作信息，已回退到本地动作草稿。', rawResponse: raw);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final minimalObj = _mapValue(parsed['minimal_action']);
      final standardObj = _mapValue(parsed['standard_action']);
      final deepObj = _mapValue(parsed['deep_action']);
      final reviewQuestionRaw = ('${parsed['review_question'] ?? segment.reflectionQuestion}').trim();
      final reviewQuestion = reviewQuestionRaw.isEmpty ? segment.reflectionQuestion : reviewQuestionRaw;
      final minimal = GoalSettingAction(
        id: 'gs_ai_min_${segment.id}_$now',
        segmentId: segment.id,
        segmentTitle: segment.title,
        level: 'min',
        source: 'ai',
        title: _readActionTitle(minimalObj, fallback: 'AI最小动作｜${segment.defaultActionTitle}'),
        body: _readActionBody(minimalObj, fallback: segment.defaultActionBody),
        steps: _readActionSteps(minimalObj, fallback: segment.howSteps.take(2).toList()),
        successCriteria: _readActionField(minimalObj, 'success_criteria', fallback: '今天能开始，并留下 1 条事实记录。'),
        fallbackAction: _readActionField(minimalObj, 'fallback_action', fallback: '把动作进一步缩小到 5 分钟。'),
        reviewQuestion: reviewQuestion,
        createdAt: now,
      );
      final standard = GoalSettingAction(
        id: 'gs_ai_std_${segment.id}_$now',
        segmentId: segment.id,
        segmentTitle: segment.title,
        level: 'standard',
        source: 'ai',
        title: _readActionTitle(standardObj, fallback: 'AI标准动作｜${segment.defaultActionTitle}'),
        body: _readActionBody(standardObj, fallback: segment.defaultActionBody),
        steps: _readActionSteps(standardObj, fallback: segment.howSteps),
        successCriteria: _readActionField(standardObj, 'success_criteria', fallback: '完成一次完整练习，并写出一个新理解。'),
        fallbackAction: _readActionField(standardObj, 'fallback_action', fallback: '把动作缩小并继续。'),
        reviewQuestion: reviewQuestion,
        createdAt: now + 1,
      );
      final deep = GoalSettingAction(
        id: 'gs_ai_deep_${segment.id}_$now',
        segmentId: segment.id,
        segmentTitle: segment.title,
        level: 'deep',
        source: 'ai',
        title: _readActionTitle(deepObj, fallback: 'AI深度动作｜${segment.defaultActionTitle}'),
        body: _readActionBody(deepObj, fallback: segment.defaultActionBody),
        steps: _readActionSteps(deepObj, fallback: [...segment.howSteps, '写一次复盘']),
        successCriteria: _readActionField(deepObj, 'success_criteria', fallback: '完成一轮连续实践并写复盘。'),
        fallbackAction: _readActionField(deepObj, 'fallback_action', fallback: '先回退到标准动作。'),
        reviewQuestion: reviewQuestion,
        createdAt: now + 2,
      );
      return GoalSettingAiResult(actions: <GoalSettingAction>[minimal, standard, deep], provider: state['provider'] ?? 'ai', modelLabel: state['label'] ?? 'AI', generationNote: '已使用 AI 生成结构化行动方案。', rawResponse: raw);
    } catch (e) {
      return GoalSettingAiResult(actions: fallback, provider: state['provider'] ?? 'ai', modelLabel: state['label'] ?? 'AI', usedFallback: true, generationNote: 'AI 请求失败，已回退到本地动作草稿：$e');
    }
  }

  Future<GoalSettingActionLoopInsight> generateLoopInsight({
    required GoalSettingSegment segment,
    required GoalSettingAction action,
    required List<GoalSettingFactRecord> records,
    String actionStatus = 'todo',
    List<String> figureCategories = const <String>[],
    String figureCategory = GoalSettingFamousFigureCatalog.noneCategory,
    List<String> selectedFigures = const <String>[],
    List<String> customFigures = const <String>[],
  }) async {
    final state = await getGlobalAiState();

    final effectiveFigureCategories = figureCategories.where((e) => e.trim().isNotEmpty).toList();
    if (effectiveFigureCategories.isEmpty && figureCategory.trim().isNotEmpty && figureCategory != GoalSettingFamousFigureCatalog.noneCategory) {
      effectiveFigureCategories.add(figureCategory.trim());
    }

    final remoteContext = await _goalDao.fetchRemoteLoopContext(action.id);
    final remoteRecords = <GoalSettingFactRecord>[];
    final remoteFacts = remoteContext?['fact_records'];
    if (remoteFacts is List) {
      for (final item in remoteFacts) {
        if (item is Map) {
          remoteRecords.add(GoalSettingFactRecord.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final mergedById = <String, GoalSettingFactRecord>{};
    for (final record in [...remoteRecords, ...records]) {
      final key = record.id.trim().isEmpty ? '${record.createdAt}_${record.actionId}' : record.id;
      mergedById[key] = record;
    }
    final allRecords = mergedById.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final actionTitle = ((remoteContext?['action_title'] ?? '').toString().trim().isNotEmpty)
        ? (remoteContext?['action_title'] ?? '').toString().trim()
        : action.title;
    final actionBody = ((remoteContext?['action_body'] ?? '').toString().trim().isNotEmpty)
        ? (remoteContext?['action_body'] ?? '').toString().trim()
        : action.body;
    final actionSteps = _stringList(remoteContext?['action_steps']);
    final effectiveSteps = actionSteps.isEmpty ? action.steps : actionSteps;
    final behaviorChain = ((remoteContext?['behavior_chain'] ?? '').toString().trim().isNotEmpty)
        ? (remoteContext?['behavior_chain'] ?? '').toString().trim()
        : _buildBehaviorChain(action);
    final successCriteria = ((remoteContext?['success_criteria'] ?? '').toString().trim().isNotEmpty)
        ? (remoteContext?['success_criteria'] ?? '').toString().trim()
        : action.successCriteria;
    final effectiveFallbackAction = ((remoteContext?['fallback_action'] ?? '').toString().trim().isNotEmpty)
        ? (remoteContext?['fallback_action'] ?? '').toString().trim()
        : action.fallbackAction;
    final effectiveStatus = ((remoteContext?['action_status'] ?? '').toString().trim().isNotEmpty)
        ? (remoteContext?['action_status'] ?? '').toString().trim()
        : actionStatus;

    final latestRecord = allRecords.isEmpty ? null : allRecords.first;
    final latestFact = ((remoteContext?['latest_fact'] ?? '').toString().trim().isNotEmpty ? (remoteContext?['latest_fact'] ?? '').toString().trim() : (latestRecord?.fact.trim() ?? ''));
    final latestFeedback = ((remoteContext?['latest_feedback'] ?? '').toString().trim().isNotEmpty ? (remoteContext?['latest_feedback'] ?? '').toString().trim() : (latestRecord?.feedback.trim() ?? ''));
    final latestResult = ((remoteContext?['latest_result'] ?? '').toString().trim().isNotEmpty ? (remoteContext?['latest_result'] ?? '').toString().trim() : (latestRecord?.result.trim() ?? ''));

    final factsText = allRecords.isEmpty
        ? '暂无历史事实记录。'
        : allRecords
            .asMap()
            .entries
            .map((entry) {
              final e = entry.value;
              return '记录${entry.key + 1}｜时间:${DateTime.fromMillisecondsSinceEpoch(e.createdAt)}\n事实:${e.fact}\n反馈:${e.feedback}\n结果:${e.result}\n证据:${e.evidence}';
            })
            .join('\n\n');
    final factsStructured = allRecords.isEmpty
        ? '[]'
        : jsonEncode(allRecords.map((e) => {
              'createdAt': e.createdAt,
              'fact': e.fact,
              'feedback': e.feedback,
              'result': e.result,
              'evidence': e.evidence,
            }).toList());

    final loopPromptState = await _settings.inspectGoalSettingLoopPromptState();
    final rawLoopPrompt = (loopPromptState['value'] ?? '').trim();
    final promptSource = (loopPromptState['source'] ?? '').trim().isEmpty ? 'default_builtin' : (loopPromptState['source'] ?? '').trim();
    final promptSourceLabel = (loopPromptState['sourceLabel'] ?? '').trim().isEmpty ? '内置默认 Prompt' : (loopPromptState['sourceLabel'] ?? '').trim();
    final promptSourceNote = (loopPromptState['note'] ?? '').trim().isEmpty
        ? '当前闭环请求直接使用设置页中的行动闭环 Prompt；若删掉关键占位符，系统会自动补齐必要上下文。'
        : (loopPromptState['note'] ?? '').trim();
    final loopSystemPrompt = _buildLoopAnalysisSystemPrompt();
    final loopPromptTemplate = _settings.ensurePromptContains(
      _settings.buildEffectiveGoalSettingLoopPrompt(rawLoopPrompt),
      requiredBlocks: const <String, String>{
        'analysis_input_json': '【输入数据】\n{{analysis_input_json}}',
      },
    );
    final basePrompt = loopPromptTemplate;
    final baseDebugTrace = <String>[
      '提供方：${state['provider'] ?? 'unknown'}',
      '模型：${state['label'] ?? 'unknown'}',
      'Prompt 来源：$promptSourceLabel',
      '闭环请求将直接使用当前设置页模板；若缺少关键占位符，系统会自动补齐必要上下文。',
    ];

    final fallback = GoalSettingActionLoopInsight(
      actionId: action.id,
      segmentId: action.segmentId,
      evidenceBasis: const <String>[],
      experienceRecap: '',
      resultJudgement: '',
      resultReasonAnalysis: '',
      strengthsFound: '',
      weaknessesOrBlindspots: '',
      patternInduction: '',
      relatedKnowledgeConcepts: const <String>[],
      theoryElevation: '',
      courseConnection: '',
      retrospectiveGuidance: '',
      retryPlanTitle: '',
      retryVisualPlan: '',
      retryPlanSteps: const <String>[],
      closureSummary: '',
      provider: state['provider'] ?? 'ai',
      modelLabel: state['label'] ?? 'AI',
      usedFallback: false,
      generationNote: '',
      promptSource: promptSource,
      promptSourceLabel: promptSourceLabel,
      promptSourceNote: promptSourceNote,
      promptTemplateUsed: basePrompt,
      requestPrompt: '',
      rawResponse: '',
      retryRawResponse: '',
      fallbackReason: '',
      debugTrace: baseDebugTrace,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    if (state['available'] != '1') {
      return _withLoopInsightMeta(
        fallback,
        generationNote: '当前未配置可用 AI，未生成闭环总结。',
        fallbackReason: '当前未配置可用 AI。',
        debugTrace: <String>[...baseDebugTrace, '未配置可用 AI，未发起模型请求。'],
      );
    }
    if (allRecords.isEmpty) {
      return _withLoopInsightMeta(
        fallback,
        generationNote: '缺少事实、反馈或结果输入，未生成闭环总结。',
        fallbackReason: '缺少已保存的事实记录，无法发起有效闭环分析。',
        debugTrace: <String>[...baseDebugTrace, '没有可用于复盘的事实记录。'],
      );
    }

    final historicalClosedLoops = await _goalDao.loadHistoricalClosedLoops(
      segmentId: segment.id,
      actionTitle: actionTitle,
    );
    final historicalClosedLoopsJson = historicalClosedLoops.isEmpty
        ? '[]'
        : const JsonEncoder.withIndent('  ').convert(historicalClosedLoops.map((e) => e.toJson()).toList());
    final analysisInputJson = _buildLoopAnalysisInputJson(
      segment: segment,
      actionTitle: actionTitle,
      actionBody: actionBody,
      actionSteps: effectiveSteps,
      latestFact: latestFact,
      latestFeedback: latestFeedback,
      latestResult: latestResult,
      records: allRecords,
      historicalClosedLoops: historicalClosedLoops,
      figureCategories: effectiveFigureCategories,
      figureCategory: effectiveFigureCategories.isEmpty ? GoalSettingFamousFigureCatalog.noneCategory : effectiveFigureCategories.join('、'),
      selectedFigures: selectedFigures,
      customFigures: customFigures,
    );
    final prompt = _settings.renderTemplate(
      loopPromptTemplate,
      <String, String>{
        'segment_title': segment.title,
        'original_text': segment.originalText,
        'action_title': actionTitle,
        'action_body': actionBody,
        'action_steps': effectiveSteps.isEmpty ? '[]' : effectiveSteps.map((e) => '- $e').join('\n'),
        'behavior_chain': behaviorChain,
        'success_criteria': successCriteria,
        'fallback_action': effectiveFallbackAction,
        'action_status': effectiveStatus,
        'latest_fact': latestFact,
        'latest_feedback': latestFeedback,
        'latest_result': latestResult,
        'current_records': factsText,
        'historical_closed_loops': historicalClosedLoopsJson,
        'fact_records': factsStructured,
        'analysis_input_json': analysisInputJson,
      },
    );

    final debugTrace = <String>[
      ...baseDebugTrace,
      '事实记录数：${allRecords.length}',
      '历史闭环数：${historicalClosedLoops.length}',
      'System Prompt 长度：${loopSystemPrompt.length}',
      'User Prompt 长度：${prompt.length}',
      '本地提交策略：不截断、不删减；业务结果失败不自动重试，网络/连接中断默认不自动重试，避免 Eden AI 等按次扣费平台重复扣费。',
    ];

    final raw = await _requestText(prompt: prompt, purpose: 'goal_setting_loop', systemPrompt: loopSystemPrompt);
    const retryRaw = '';
    final parsed = _extractJsonObject(raw);
    const loopNote = '已使用 AI 生成结构化闭环分析；本地不再做内容层校验，仅要求结果可解析为 JSON。若 AI 某些字段返回为空，则页面按空字段显示。';
    debugTrace.add(raw.trim().isEmpty ? '首轮模型输出为空。' : '首轮模型输出长度：${raw.length}');

    if (parsed.isNotEmpty) {
      final topKeys = _unwrapLoopResponsePayload(parsed).keys.take(12).join(', ');
      debugTrace.add('首轮获得可解析 JSON；已直接采用 AI 结果，不做本地内容层校验。');
      if (topKeys.trim().isNotEmpty) {
        debugTrace.add('解析后的顶层键：$topKeys');
      }
      return _buildLoopInsightFromParsed(
        parsed: parsed,
        action: action,
        fallback: fallback,
        provider: state['provider'] ?? 'ai',
        modelLabel: state['label'] ?? 'AI',
        generationNote: loopNote,
        promptSource: promptSource,
        promptSourceLabel: promptSourceLabel,
        promptSourceNote: promptSourceNote,
        promptTemplateUsed: basePrompt,
        requestPrompt: prompt,
        rawResponse: raw,
        retryRawResponse: retryRaw,
        fallbackReason: '',
        debugTrace: debugTrace,
      );
    }

    debugTrace.add('首轮输出不是可解析 JSON；按放宽后的规则不再自动重试，优先直接展示可提取内容。');
    if (_looksLikeLoopErrorResponse(raw)) {
      const fallbackReason = 'loop_error_response:首轮输出包含明显错误信号。';
      return _withLoopInsightMeta(
        fallback,
        generationNote: 'AI 返回的是错误内容而不是有效闭环分析，无法直接展示结构化闭环结果。',
        fallbackReason: fallbackReason,
        requestPrompt: prompt,
        rawResponse: raw,
        retryRawResponse: retryRaw,
        debugTrace: <String>[...debugTrace, '最终回退原因：$fallbackReason'],
      );
    }
    final anchors = _extractLoopAnchors(
      records: allRecords,
      draftFact: '',
      draftFeedback: '',
      draftResult: '',
      actionTitle: actionTitle,
      segmentTitle: segment.title,
      actionBody: actionBody,
      actionSteps: effectiveSteps,
    );
    final recovered = _recoverLoopInsightFromCandidates(
      <String>[raw],
      anchors: anchors,
    );
    final relaxedRecovered = _buildRelaxedLoopInsightPayload(
      recovered,
      raw: raw,
      anchors: anchors,
    );
    if (_hasAnyLoopInsightContent(relaxedRecovered)) {
      final recoveryMode = recovered.isNotEmpty ? '结构恢复' : '原文直显';
      debugTrace.add(recovered.isNotEmpty
          ? '首轮虽不是完整 JSON，但已从原始文本恢复出部分结构字段；按放宽规则直接展示，不再自动重试。'
          : '首轮虽不是完整 JSON，但原始文本本身有内容；按放宽规则直接展示原文，不再自动重试。');
      return _buildLoopInsightFromParsed(
        parsed: relaxedRecovered,
        action: action,
        fallback: fallback,
        provider: state['provider'] ?? 'ai',
        modelLabel: '${state['label'] ?? 'AI'}（$recoveryMode）',
        generationNote: 'AI 已成功返回内容；系统已放宽闭环结构校验并直接展示可提取内容。即使部分字段为空也不回退；只有接口报错或返回整体为空时才回退。',
        promptSource: promptSource,
        promptSourceLabel: promptSourceLabel,
        promptSourceNote: promptSourceNote,
        promptTemplateUsed: basePrompt,
        requestPrompt: prompt,
        rawResponse: raw,
        retryRawResponse: retryRaw,
        fallbackReason: '',
        debugTrace: <String>[...debugTrace, '最终处理：已按放宽规则直接展示 AI 返回内容。'],
      );
    }
    const fallbackReason = 'loop_empty_response:首轮输出不是可解析 JSON，且提取后整体为空。';
    return _withLoopInsightMeta(
      fallback,
      generationNote: 'AI 已返回，但提取后整体为空、没有任何可显示内容。',
      fallbackReason: fallbackReason,
      requestPrompt: prompt,
      rawResponse: raw,
      retryRawResponse: retryRaw,
      debugTrace: <String>[...debugTrace, '最终回退原因：$fallbackReason'],
    );
  }

  GoalSettingActionLoopInsight _withLoopInsightMeta(
    GoalSettingActionLoopInsight base, {
    String? provider,
    String? modelLabel,
    bool? usedFallback,
    String? generationNote,
    String? promptSource,
    String? promptSourceLabel,
    String? promptSourceNote,
    String? promptTemplateUsed,
    String? requestPrompt,
    String? rawResponse,
    String? retryRawResponse,
    String? fallbackReason,
    List<String>? debugTrace,
  }) {
    final sanitizedClosureSummary = _sanitizeLoopClosureSummary(
      base.closureSummary,
      resultJudgement: base.resultJudgement,
      resultReasonAnalysis: base.resultReasonAnalysis,
      theoryElevation: base.theoryElevation,
      retrospectiveGuidance: base.retrospectiveGuidance,
    );

    return GoalSettingActionLoopInsight(
      actionId: base.actionId,
      segmentId: base.segmentId,
      evidenceBasis: base.evidenceBasis,
      experienceRecap: base.experienceRecap,
      resultJudgement: base.resultJudgement,
      resultReasonAnalysis: base.resultReasonAnalysis,
      strengthsFound: base.strengthsFound,
      weaknessesOrBlindspots: base.weaknessesOrBlindspots,
      patternInduction: base.patternInduction,
      relatedKnowledgeConcepts: base.relatedKnowledgeConcepts,
      theoryElevation: base.theoryElevation,
      courseConnection: base.courseConnection,
      retrospectiveGuidance: base.retrospectiveGuidance,
      retryPlanTitle: base.retryPlanTitle,
      retryVisualPlan: base.retryVisualPlan,
      retryPlanSteps: base.retryPlanSteps,
      closureSummary: sanitizedClosureSummary,
      provider: provider ?? base.provider,
      modelLabel: modelLabel ?? base.modelLabel,
      usedFallback: usedFallback ?? base.usedFallback,
      generationNote: generationNote ?? base.generationNote,
      promptSource: promptSource ?? base.promptSource,
      promptSourceLabel: promptSourceLabel ?? base.promptSourceLabel,
      promptSourceNote: promptSourceNote ?? base.promptSourceNote,
      promptTemplateUsed: promptTemplateUsed ?? base.promptTemplateUsed,
      requestPrompt: requestPrompt ?? base.requestPrompt,
      rawResponse: rawResponse ?? base.rawResponse,
      retryRawResponse: retryRawResponse ?? base.retryRawResponse,
      fallbackReason: fallbackReason ?? base.fallbackReason,
      debugTrace: debugTrace ?? base.debugTrace,
      extraSections: base.extraSections,
      createdAt: base.createdAt,
    );
  }

  GoalSettingActionLoopInsight _buildLoopInsightFromParsed({
    required Map<String, dynamic> parsed,
    required GoalSettingAction action,
    required GoalSettingActionLoopInsight fallback,
    required String provider,
    required String modelLabel,
    required String generationNote,
    required String promptSource,
    required String promptSourceLabel,
    required String promptSourceNote,
    required String promptTemplateUsed,
    required String requestPrompt,
    required String rawResponse,
    required String retryRawResponse,
    required String fallbackReason,
    required List<String> debugTrace,
  }) {
    final working = _unwrapLoopResponsePayload(parsed);
    final newSchema = working.containsKey('result_final_judgement') || working.containsKey('failure_analysis') || working.containsKey('strengths_and_blindspots');
    final intermediateSchema = working.containsKey('final_judgment') || working.containsKey('failure_analysis_and_suggestions') || working.containsKey('strengths_and_weaknesses') || working.containsKey('theoretical_analysis') || working.containsKey('historical_person_match') || working.containsKey('next_action_plan');

    String cleanText(dynamic value) => _cleanLoopText('${value ?? ''}');
    List<String> evidenceBasis = _stringList(working['evidence_basis']);
    if (evidenceBasis.isEmpty) evidenceBasis = fallback.evidenceBasis;
    String experienceRecap = cleanText(working['experience_recap']);
    String resultJudgement = cleanText(working['result_judgement']);
    String resultReasonAnalysis = cleanText(working['result_reason_analysis']);
    String strengthsFound = cleanText(working['strengths_found']);
    String weaknessesOrBlindspots = cleanText(working['weaknesses_or_blindspots']);
    String patternInduction = cleanText(working['pattern_induction']);
    List<String> relatedKnowledgeConcepts = _stringList(working['related_knowledge_concepts']);
    String theoryElevation = cleanText(working['theory_elevation']);
    String courseConnection = cleanText(working['course_connection']);
    String retrospectiveGuidance = cleanText(working['retrospective_guidance']);
    String retryPlanTitle = cleanText(working['retry_plan_title']);
    String retryVisualPlan = cleanText(working['retry_visual_plan']);
    List<String> retryPlanSteps = _stringList(working['retry_plan_steps']);
    String closureSummary = cleanText(working['closure_summary']);
    final baseExtraSections = _normalizeExtraSections(working['extra_sections']);
    Map<String, dynamic> mergedExtraSections = Map<String, dynamic>.from(baseExtraSections);

    if (newSchema) {
      final judgement = working['result_final_judgement'];
      if (judgement is Map) {
        final label = cleanText(judgement['label']);
        final confidence = cleanText(judgement['confidence']);
        final summary = cleanText(judgement['summary']);
        resultJudgement = [
          if (label.isNotEmpty) label,
          if (confidence.isNotEmpty) '置信度：$confidence',
          if (summary.isNotEmpty) summary,
        ].join('｜');
        if (closureSummary.isEmpty && summary.isNotEmpty) {
          closureSummary = summary;
        }
      }

      final failure = working['failure_analysis'];
      if (failure is Map) {
        final core = cleanText(failure['core_failure_point']);
        final deep = cleanText(failure['deep_analysis']);
        final suggestions = _stringList(failure['change_suggestions']);
        final parts = <String>[];
        if (core.isNotEmpty) parts.add('核心断点：$core');
        if (deep.isNotEmpty) parts.add(deep);
        if (suggestions.isNotEmpty) {
          parts.add('改变建议：\n${suggestions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}');
        }
        if (parts.isNotEmpty) {
          resultReasonAnalysis = parts.join('\n\n');
        }
      }

      final strengthsBlock = working['strengths_and_blindspots'];
      if (strengthsBlock is Map) {
        final strengths = strengthsBlock['strengths'];
        final weaknesses = strengthsBlock['weaknesses_or_blindspots'];
        if (strengths is List) {
          final lines = <String>[];
          for (final item in strengths) {
            if (item is Map) {
              final title = cleanText(item['title']);
              final analysis = cleanText(item['analysis']);
              final line = [if (title.isNotEmpty) title, if (analysis.isNotEmpty) analysis].join('：');
              if (line.trim().isNotEmpty) lines.add(line);
            } else if ('$item'.trim().isNotEmpty) {
              lines.add('$item'.trim());
            }
          }
          if (lines.isNotEmpty) strengthsFound = lines.join('\n');
        }
        if (weaknesses is List) {
          final lines = <String>[];
          for (final item in weaknesses) {
            if (item is Map) {
              final title = ('${item['title'] ?? ''}').trim();
              final analysis = ('${item['analysis'] ?? ''}').trim();
              final line = [if (title.isNotEmpty) title, if (analysis.isNotEmpty) analysis].join('：');
              if (line.trim().isNotEmpty) lines.add(line);
            } else if ('$item'.trim().isNotEmpty) {
              lines.add('$item'.trim());
            }
          }
          if (lines.isNotEmpty) weaknessesOrBlindspots = lines.join('\n');
        }
        final potentialMap = <String, dynamic>{};
        for (final key in <String>[
          'visible_strengths',
          'hidden_strengths',
          'reverse_potential_from_weakness',
          'historical_strength_evolution',
          'activation_suggestions',
        ]) {
          final value = strengthsBlock[key];
          if (value != null && _hasMeaningfulExtraSectionValue(value)) {
            potentialMap[key] = value;
          }
        }
        final nestedPotential = strengthsBlock['strength_potential_analysis'];
        if (nestedPotential is Map) {
          for (final entry in nestedPotential.entries) {
            if (_hasMeaningfulExtraSectionValue(entry.value)) {
              potentialMap['${entry.key}'] = entry.value;
            }
          }
        }
        if (potentialMap.isNotEmpty) {
          mergedExtraSections['strength_potential_analysis'] = potentialMap;
        }
      }

      final directStrengthPotential = working['strength_potential_analysis'];
      if (directStrengthPotential is Map && _hasMeaningfulExtraSectionValue(directStrengthPotential)) {
        mergedExtraSections['strength_potential_analysis'] = directStrengthPotential;
      }

      final comparative = working['comparative_judgement'];
      if (comparative is Map) {
        final same = _stringList(comparative['same_underlying_pattern']);
        final diff = _stringList(comparative['key_differences']);
        final shortLong = comparative['short_term_vs_long_term'];
        final hist = cleanText(comparative['historical_comparison']);
        final parts = <String>[];
        if (same.isNotEmpty) parts.add('同一底层结构：\n${same.join('\n')}');
        if (diff.isNotEmpty) parts.add('关键差异：\n${diff.join('\n')}');
        if (shortLong is Map) {
          final s = cleanText(shortLong['short_term']);
          final l = cleanText(shortLong['long_term']);
          final shortLongLines = <String>[];
          if (s.isNotEmpty) shortLongLines.add('短期：$s');
          if (l.isNotEmpty) shortLongLines.add('长期：$l');
          if (shortLongLines.isNotEmpty) {
            parts.add('短期/长期：\n${shortLongLines.join('\n')}');
          }
        }
        if (hist.isNotEmpty) parts.add('历史比较：$hist');
        if (parts.isNotEmpty) {
          patternInduction = parts.join('\n\n');
        }
      }

      final theories = working['related_theories'];
      if (theories is List) {
        final lines = <String>[];
        final theoryMaps = <Map<String, dynamic>>[];
        for (final item in theories) {
          if (item is Map) {
            final mapped = Map<String, dynamic>.from(item.cast<dynamic, dynamic>());
            theoryMaps.add(mapped);
            final name = cleanText(mapped['name']);
            final source = cleanText(mapped['source']);
            final relevance = cleanText(mapped['relevance_analysis']);
            final better = cleanText(mapped['why_this_fits_better']);
            final line = [
              if (name.isNotEmpty) name,
              if (source.isNotEmpty) '来源：$source',
              if (relevance.isNotEmpty) relevance,
              if (better.isNotEmpty) better,
            ].join('｜');
            if (line.trim().isNotEmpty) lines.add(line);
          } else if ('$item'.trim().isNotEmpty) {
            lines.add('$item'.trim());
          }
        }
        if (lines.isNotEmpty) {
          relatedKnowledgeConcepts = lines;
        }
        final explicitTheoryElevation = cleanText(working['theory_elevation']);
        if (explicitTheoryElevation.isNotEmpty) {
          theoryElevation = explicitTheoryElevation;
        } else if (theoryMaps.isNotEmpty) {
          theoryElevation = _synthesizeTheoryElevation(
            theoryMaps,
            comparative: working['comparative_judgement'],
            currentTheoryElevation: theoryElevation,
          );
        }
      }

      final next = working['next_iteration_guidance'];
      if (next is Map) {
        final review = cleanText(next['review_guidance']);
        if (review.isNotEmpty) {
          retrospectiveGuidance = review;
        }
        final plan = next['next_action_plan'];
        if (plan is Map) {
          final planTitle = cleanText(plan['plan_title']);
          final visualScript = cleanText(plan['visual_script']);
          final completion = cleanText(plan['completion_criteria']);
          final fallbackOption = cleanText(plan['fallback_option']);
          final planSteps = _stringList(plan['steps']);
          if (planTitle.isNotEmpty) retryPlanTitle = planTitle;
          if (planSteps.isNotEmpty) retryPlanSteps = planSteps;
          final visualLines = <String>[];
          if (visualScript.isNotEmpty) visualLines.add(visualScript);
          if (completion.isNotEmpty) visualLines.add('完成标准：$completion');
          if (fallbackOption.isNotEmpty) visualLines.add('遇阻替代：$fallbackOption');
          if (visualLines.isNotEmpty) retryVisualPlan = visualLines.join('\n');
        }
      }

      for (final key in <String>['comparative_judgement', 'related_theories', 'psychology_analysis', 'philosophy_analysis', 'similar_historical_figure', 'next_iteration_guidance', 'strength_potential_analysis', 'famous_figure_matching', 'subconscious_analysis']) {
        final value = working[key];
        if (value != null && (!(value is String) || value.trim().isNotEmpty)) {
          mergedExtraSections[key] = value;
        }
      }
    }

    if (intermediateSchema) {
      resultJudgement = cleanText(working['final_judgment']);
      resultReasonAnalysis = cleanText(working['failure_analysis_and_suggestions']);
      strengthsFound = cleanText(working['strengths_and_weaknesses']);
      theoryElevation = cleanText(working['theoretical_analysis']);
      retrospectiveGuidance = cleanText(working['next_action_plan']);
      if (closureSummary.isEmpty) {
        closureSummary = resultJudgement;
      }
      final psych = cleanText(working['psychological_analysis']);
      final phil = cleanText(working['philosophical_analysis']);
      final hist = cleanText(working['historical_person_match']);
      if (psych.isNotEmpty) mergedExtraSections['psychology_analysis'] = psych;
      if (phil.isNotEmpty) mergedExtraSections['philosophy_analysis'] = phil;
      if (hist.isNotEmpty) mergedExtraSections['similar_historical_figure'] = hist;
      if (theoryElevation.isNotEmpty && relatedKnowledgeConcepts.isEmpty) {
        relatedKnowledgeConcepts = <String>[theoryElevation];
      }
    }

    if (closureSummary.isEmpty) {
      closureSummary = _synthesizeLoopClosureSummaryFromWorking(
        working,
        resultJudgement: resultJudgement,
        resultReasonAnalysis: resultReasonAnalysis,
        theoryElevation: theoryElevation,
        retrospectiveGuidance: retrospectiveGuidance,
      );
    }
    // 不再自动补写“本轮经验重建”默认内容：仅展示 AI 实际返回并成功提取出的字段。
    mergedExtraSections = _ensureLoopExtraSections(
      mergedExtraSections,
      working,
      rawResponse,
      resultJudgement: resultJudgement,
      resultReasonAnalysis: resultReasonAnalysis,
      strengthsFound: strengthsFound,
      weaknessesOrBlindspots: weaknessesOrBlindspots,
      patternInduction: patternInduction,
      theoryElevation: theoryElevation,
      retrospectiveGuidance: retrospectiveGuidance,
    );
    // 仅显示 AI 实际返回或可从原始响应中提取出的潜意识内容，不再自动合成默认‘潜意识专栏’。
    mergedExtraSections = _mergeLoopUnmappedSections(
      mergedExtraSections,
      working,
      consumedKeys: const <String>{
        'evidence_basis',
        'experience_recap',
        'result_judgement',
        'result_reason_analysis',
        'strengths_found',
        'weaknesses_or_blindspots',
        'pattern_induction',
        'related_knowledge_concepts',
        'theory_elevation',
        'course_connection',
        'retrospective_guidance',
        'retry_plan_title',
        'retry_visual_plan',
        'retry_plan_steps',
        'closure_summary',
        'extra_sections',
        'result_final_judgement',
        'failure_analysis',
        'strengths_and_blindspots',
        'comparative_judgement',
        'related_theories',
        'psychology_analysis',
        'philosophy_analysis',
        'similar_historical_figure',
        'next_iteration_guidance',
        'strength_potential_analysis',
        'famous_figure_matching',
        'subconscious_analysis',
      },
    );
    mergedExtraSections = (_sanitizeLoopJsonValue(mergedExtraSections) as Map<String, dynamic>)
      ..removeWhere((key, value) => !_hasMeaningfulExtraSectionValue(value));

    return GoalSettingActionLoopInsight(
      actionId: action.id,
      segmentId: fallback.segmentId,
      evidenceBasis: evidenceBasis,
      experienceRecap: experienceRecap,
      resultJudgement: resultJudgement,
      resultReasonAnalysis: resultReasonAnalysis,
      strengthsFound: strengthsFound,
      weaknessesOrBlindspots: weaknessesOrBlindspots,
      patternInduction: patternInduction,
      relatedKnowledgeConcepts: relatedKnowledgeConcepts,
      theoryElevation: theoryElevation,
      courseConnection: courseConnection,
      retrospectiveGuidance: retrospectiveGuidance,
      retryPlanTitle: retryPlanTitle,
      retryVisualPlan: retryVisualPlan,
      retryPlanSteps: retryPlanSteps,
      closureSummary: closureSummary,
      provider: provider,
      modelLabel: modelLabel,
      usedFallback: false,
      generationNote: generationNote,
      promptSource: promptSource,
      promptSourceLabel: promptSourceLabel,
      promptSourceNote: promptSourceNote,
      promptTemplateUsed: promptTemplateUsed,
      requestPrompt: requestPrompt,
      rawResponse: rawResponse,
      retryRawResponse: retryRawResponse,
      fallbackReason: fallbackReason,
      debugTrace: debugTrace,
      extraSections: mergedExtraSections,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }


  Map<String, dynamic> _unwrapLoopResponsePayload(Map<String, dynamic> parsed) {
    if (parsed.isEmpty) return parsed;
    final direct = parsed.containsKey('result_final_judgement') ||
        parsed.containsKey('failure_analysis') ||
        parsed.containsKey('strengths_and_blindspots') ||
        parsed.containsKey('theory_elevation') ||
        parsed.containsKey('comparative_judgement') ||
        parsed.containsKey('next_iteration_guidance') ||
        parsed.containsKey('extra_sections') ||
        parsed.containsKey('result_judgement') ||
        parsed.containsKey('result_reason_analysis');
    if (direct) return parsed;

    Map<String, dynamic> tryUnwrap(dynamic value) {
      if (value is Map) {
        final mapped = Map<String, dynamic>.from(value.cast<dynamic, dynamic>());
        final nested = _unwrapLoopResponsePayload(mapped);
        if (nested.isNotEmpty && nested != mapped) return nested;
        if (mapped.containsKey('result_final_judgement') ||
            mapped.containsKey('failure_analysis') ||
            mapped.containsKey('theory_elevation') ||
            mapped.containsKey('result_judgement')) {
          return mapped;
        }
      }
      if (value is String && value.trim().isNotEmpty) {
        final nested = _extractJsonObject(value);
        if (nested.isNotEmpty) {
          final unwrapped = _unwrapLoopResponsePayload(nested);
          if (unwrapped.isNotEmpty) return unwrapped;
        }
      }
      return const <String, dynamic>{};
    }

    final fromContent = tryUnwrap(parsed['content']);
    if (fromContent.isNotEmpty) return fromContent;
    final fromMessage = tryUnwrap(parsed['message']);
    if (fromMessage.isNotEmpty) return fromMessage;

    final choices = parsed['choices'];
    if (choices is List && choices.isNotEmpty) {
      for (final item in choices) {
        final unwrapped = tryUnwrap(item);
        if (unwrapped.isNotEmpty) return unwrapped;
      }
    }

    final output = parsed['output'];
    if (output is List && output.isNotEmpty) {
      for (final item in output) {
        final unwrapped = tryUnwrap(item);
        if (unwrapped.isNotEmpty) return unwrapped;
      }
    }

    for (final entry in parsed.entries) {
      final unwrapped = tryUnwrap(entry.value);
      if (unwrapped.isNotEmpty) return unwrapped;
    }
    return parsed;
  }

  String _synthesizeExperienceRecapFromWorking(Map<String, dynamic> working, List<String> evidenceBasis) {
    final pieces = <String>[];
    final judgement = working['result_final_judgement'];
    if (judgement is Map) {
      final summary = _cleanLoopText('${judgement['summary'] ?? ''}');
      if (summary.isNotEmpty) pieces.add(summary);
    }
    final failure = working['failure_analysis'];
    if (failure is Map) {
      final core = _cleanLoopText('${failure['core_failure_point'] ?? ''}');
      if (core.isNotEmpty) pieces.add('本轮关键断点：$core');
    }
    if (pieces.isEmpty && evidenceBasis.isNotEmpty) {
      pieces.add(evidenceBasis.join('；'));
    }
    return pieces.join('\n');
  }


  String _synthesizeLoopClosureSummaryFromWorking(
    Map<String, dynamic> working, {
    required String resultJudgement,
    required String resultReasonAnalysis,
    required String theoryElevation,
    required String retrospectiveGuidance,
  }) {
    final judgement = working['result_final_judgement'];
    if (judgement is Map) {
      final summary = _cleanLoopText('${judgement['summary'] ?? ''}');
      if (summary.isNotEmpty) return summary;
    }
    final next = working['next_iteration_guidance'];
    if (next is Map) {
      final review = _cleanLoopText('${next['review_guidance'] ?? ''}');
      if (review.isNotEmpty) return review;
    }
    return _sanitizeLoopClosureSummary(
      '',
      resultJudgement: resultJudgement,
      resultReasonAnalysis: resultReasonAnalysis,
      theoryElevation: theoryElevation,
      retrospectiveGuidance: retrospectiveGuidance,
    );
  }

  Map<String, dynamic> _ensureLoopExtraSections(
    Map<String, dynamic> current,
    Map<String, dynamic> working,
    String rawResponse, {
    required String resultJudgement,
    required String resultReasonAnalysis,
    required String strengthsFound,
    required String weaknessesOrBlindspots,
    required String patternInduction,
    required String theoryElevation,
    required String retrospectiveGuidance,
  }) {
    final extra = Map<String, dynamic>.from(current);
    for (final key in <String>['comparative_judgement', 'related_theories', 'psychology_analysis', 'philosophy_analysis', 'similar_historical_figure', 'next_iteration_guidance']) {
      final value = working[key];
      if (value != null && (!(value is String) || value.trim().isNotEmpty)) {
        extra[key] = value;
      }
    }
    if (working['extra_sections'] != null) {
      extra.addAll(_normalizeExtraSections(working['extra_sections']));
    }
    if (working['subconscious_analysis'] != null) {
      extra['subconscious_analysis'] = working['subconscious_analysis'];
    } else {
      final rootExtra = _normalizeExtraSections(working['extra_sections']);
      if (rootExtra['subconscious_analysis'] != null) {
        extra['subconscious_analysis'] = rootExtra['subconscious_analysis'];
      }
    }
    if (working['famous_figure_matching'] != null) {
      extra['famous_figure_matching'] = working['famous_figure_matching'];
    } else {
      final rootExtra = _normalizeExtraSections(working['extra_sections']);
      if (rootExtra['famous_figure_matching'] != null) {
        extra['famous_figure_matching'] = rootExtra['famous_figure_matching'];
      }
    }

    if (working['strength_potential_analysis'] != null) {
      extra['strength_potential_analysis'] = working['strength_potential_analysis'];
    } else {
      final rootExtra = _normalizeExtraSections(working['extra_sections']);
      if (rootExtra['strength_potential_analysis'] != null) {
        extra['strength_potential_analysis'] = rootExtra['strength_potential_analysis'];
      }
    }

    if (!_hasMeaningfulExtraSectionValue(extra['famous_figure_matching'])) {
      final extractedFamous = _extractLoopExtraSectionFromRawResponse(rawResponse, 'famous_figure_matching');
      if (_hasMeaningfulExtraSectionValue(extractedFamous)) {
        extra['famous_figure_matching'] = extractedFamous;
      }
    }
    if (!_hasMeaningfulExtraSectionValue(extra['subconscious_analysis'])) {
      final extractedSub = _extractLoopExtraSectionFromRawResponse(rawResponse, 'subconscious_analysis');
      if (_hasMeaningfulExtraSectionValue(extractedSub)) {
        extra['subconscious_analysis'] = extractedSub;
      }
    }
    if (!_hasMeaningfulExtraSectionValue(extra['strength_potential_analysis'])) {
      final extractedStrengthPotential = _extractLoopExtraSectionFromRawResponse(rawResponse, 'strength_potential_analysis');
      if (_hasMeaningfulExtraSectionValue(extractedStrengthPotential)) {
        extra['strength_potential_analysis'] = extractedStrengthPotential;
      }
    }
    if (!_hasMeaningfulExtraSectionValue(extra['strength_potential_analysis'])) {
      final synthesizedStrengthPotential = _synthesizeStrengthPotentialAnalysis(
        working: working,
        resultJudgement: resultJudgement,
        resultReasonAnalysis: resultReasonAnalysis,
        strengthsFound: strengthsFound,
        weaknessesOrBlindspots: weaknessesOrBlindspots,
        patternInduction: patternInduction,
      );
      if (_hasMeaningfulExtraSectionValue(synthesizedStrengthPotential)) {
        extra['strength_potential_analysis'] = synthesizedStrengthPotential;
      }
    }
    if (extra.isEmpty) {
      final rawText = _cleanLoopText(_extractText(rawResponse));
      if (rawText.isNotEmpty) {
        extra['AI 原始返回（宽松展示）'] = rawText;
      }
    }
    return extra;
  }


  Map<String, dynamic> _synthesizeStrengthPotentialAnalysis({
    required Map<String, dynamic> working,
    required String resultJudgement,
    required String resultReasonAnalysis,
    required String strengthsFound,
    required String weaknessesOrBlindspots,
    required String patternInduction,
  }) {
    final visible = <Map<String, String>>[];
    final hidden = <Map<String, String>>[];
    final reverse = <Map<String, String>>[];
    final suggestions = <String>[];

    String firstNonEmptyLine(String text) {
      return text
          .split(RegExp(r'\r?\n'))
          .map((e) => _cleanLoopText(e))
          .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    }

    final explicitStrength = firstNonEmptyLine(strengthsFound);
    if (explicitStrength.isNotEmpty) {
      visible.add(<String, String>{
        'title': explicitStrength.contains('：') ? explicitStrength.split('：').first.trim() : '已显现的优势线索',
        'evidence': explicitStrength,
        'analysis': '这是根据 AI 已返回的 strengths_and_blindspots.strengths 提炼出的显性优势线索，说明用户本轮并非只有问题，也存在可继续发展的能力基础。',
      });
    }

    final judgementText = _cleanLoopText(resultJudgement);
    if (judgementText.isNotEmpty && (judgementText.contains('成功') || judgementText.contains('完成') || judgementText.contains('坚持'))) {
      hidden.add(<String, String>{
        'title': '带着阻力仍可行动的潜能',
        'evidence': judgementText,
        'analysis': '即使过程伴随阻力、痛苦或成本，只要本轮存在启动、坚持、完成或记录，就说明用户具备尚未完全稳定的行动承受力与目标维持能力。',
      });
    }

    final weaknessLine = firstNonEmptyLine(weaknessesOrBlindspots.isNotEmpty ? weaknessesOrBlindspots : resultReasonAnalysis);
    if (weaknessLine.isNotEmpty) {
      reverse.add(<String, String>{
        'weakness_or_failure_clue': weaknessLine,
        'potential': '这个问题反面暴露出一个可发展的能力入口：用户已经看见了最先失效的环节，具备把模糊失败转化为具体训练点的可能。',
        'development_direction': '下一轮不要只自责或泛泛用力，而要把这个失效环节外化为一个可观察、可提醒、可复盘的微动作。',
      });
    }

    final patternText = _cleanLoopText(patternInduction);
    final historySummary = patternText.isNotEmpty
        ? '结合 AI 已返回的模式归纳看：$patternText'
        : '暂无足够历史优势字段可比；本项基于本轮已返回的优势、盲点和结果判断做保守提炼。';

    suggestions.add('把已识别的优势线索写成下一轮行动前的启动提示，例如“我至少能先启动一分钟”。');
    suggestions.add('把失败或痛苦中的反面线索转化为外部结构，例如闹钟、便签、环境摆放、伙伴提醒或完成后记录。');

    if (visible.isEmpty && hidden.isEmpty && reverse.isEmpty) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{
      'visible_strengths': visible,
      'hidden_strengths': hidden,
      'reverse_potential_from_weakness': reverse,
      'historical_strength_evolution': historySummary,
      'activation_suggestions': suggestions,
      '_source': 'local_conservative_strength_potential',
      '_local_note': 'AI 本轮未显式返回 extra_sections.strength_potential_analysis；这里是 App 基于 AI 已返回的优势、盲点、结果判断和模式归纳自动生成的“系统保守版”潜能提炼，不等同于 AI 直接生成的完整深度分析。',
    };
  }

  Map<String, dynamic> _mergeLoopUnmappedSections(
    Map<String, dynamic> current,
    Map<String, dynamic> working, {
    required Set<String> consumedKeys,
  }) {
    final merged = Map<String, dynamic>.from(current);
    for (final entry in working.entries) {
      final key = '${entry.key}'.trim();
      if (key.isEmpty || consumedKeys.contains(key)) continue;
      if (!_hasMeaningfulExtraSectionValue(entry.value)) continue;
      merged[key] = entry.value;
    }
    return merged;
  }

  dynamic _extractLoopExtraSectionFromRawResponse(String rawResponse, String key) {
    final rawText = rawResponse.trim();
    if (rawText.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawText);
      if (decoded is Map) {
        final direct = decoded[key];
        if (direct != null) return direct;
        final extra = decoded['extra_sections'];
        if (extra is Map && extra[key] != null) return extra[key];
      }
    } catch (_) {}
    final extracted = _extractJsonObject(rawText);
    if (extracted.isNotEmpty) {
      if (extracted[key] != null) return extracted[key];
      final extra = extracted['extra_sections'];
      if (extra is Map && extra[key] != null) return extra[key];
    }
    final named = _extractNamedJsonValueFromText(rawText, key);
    if (_hasMeaningfulExtraSectionValue(named)) return named;
    final extraSections = _extractNamedJsonValueFromText(rawText, 'extra_sections');
    if (extraSections is Map && _hasMeaningfulExtraSectionValue(extraSections[key])) {
      return extraSections[key];
    }
    if (key == 'famous_figure_matching') {
      final salvaged = _extractFamousFigureMatchingFromMalformedRaw(rawText);
      if (_hasMeaningfulExtraSectionValue(salvaged)) return salvaged;
    }
    if (key == 'subconscious_analysis') {
      final salvaged = _extractSubconsciousAnalysisFromMalformedRaw(rawText);
      if (_hasMeaningfulExtraSectionValue(salvaged)) return salvaged;
    }
    return null;
  }

  dynamic _extractNamedJsonValueFromText(String rawText, String key) {
    final marker = '"$key"';
    final start = rawText.indexOf(marker);
    if (start < 0) return null;
    final colon = rawText.indexOf(':', start + marker.length);
    if (colon < 0) return null;
    var i = colon + 1;
    while (i < rawText.length && RegExp(r'\s').hasMatch(rawText[i])) {
      i++;
    }
    if (i >= rawText.length) return null;
    final snippet = _sliceNamedJsonValue(rawText, i);
    if (snippet.isEmpty) return null;
    try {
      return _sanitizeLoopJsonValue(jsonDecode(snippet));
    } catch (_) {
      if (snippet.startsWith('"') && snippet.endsWith('"')) {
        try {
          return _cleanLoopText(jsonDecode(snippet).toString());
        } catch (_) {
          final inner = snippet.substring(1, snippet.length - 1);
          return _cleanLoopText(inner);
        }
      }
      return _cleanLoopText(snippet);
    }
  }

  String _sliceNamedJsonValue(String text, int start) {
    if (start < 0 || start >= text.length) return '';
    final lead = text[start];
    if (lead == '{' || lead == '[') {
      final open = lead;
      final close = lead == '{' ? '}' : ']';
      var depth = 0;
      var inString = false;
      var escaped = false;
      for (var i = start; i < text.length; i++) {
        final ch = text[i];
        if (escaped) {
          escaped = false;
          continue;
        }
        if (ch == '\\') {
          escaped = true;
          continue;
        }
        if (ch == '"') {
          inString = !inString;
          continue;
        }
        if (inString) continue;
        if (ch == open) depth++;
        if (ch == close) {
          depth--;
          if (depth == 0) return text.substring(start, i + 1);
        }
      }
      return '';
    }
    if (lead == '"') {
      var escaped = false;
      for (var i = start + 1; i < text.length; i++) {
        final ch = text[i];
        if (escaped) {
          escaped = false;
          continue;
        }
        if (ch == '\\') {
          escaped = true;
          continue;
        }
        if (ch == '"') {
          return text.substring(start, i + 1);
        }
      }
      return text.substring(start);
    }
    var end = start;
    while (end < text.length && !',}]\n\r'.contains(text[end])) {
      end++;
    }
    return text.substring(start, end).trim();
  }

  Map<String, dynamic> _extractFamousFigureMatchingFromMalformedRaw(String rawText) {
    final chunk = _extractRawChunkAroundKey(rawText, 'famous_figure_matching');
    if (chunk.isEmpty) return const <String, dynamic>{};

    String extractString(String key) {
      final match = RegExp('"' + key + r'"\s*:\s*"((?:\\.|[^"\\])*)"', multiLine: true).firstMatch(chunk);
      final value = match?.group(1);
      if (value == null) return '';
      try {
        return _cleanLoopText(jsonDecode('"' + value + '"').toString());
      } catch (_) {
        return _cleanLoopText(value);
      }
    }

    List<String> extractList(String key) {
      final match = RegExp('"' + key + r'"\s*:\s*\[([\s\S]*?)\]', multiLine: true).firstMatch(chunk);
      if (match == null) return const <String>[];
      final block = match.group(1)?.trim() ?? '';
      if (block.isEmpty) return const <String>[];
      return RegExp(r'"((?:\\.|[^"\\])*)"', multiLine: true)
          .allMatches(block)
          .map((m) {
            final raw = m.group(1) ?? '';
            try {
              return _cleanLoopText(jsonDecode('"' + raw + '"').toString());
            } catch (_) {
              return _cleanLoopText(raw);
            }
          })
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final scoreText = extractString('best_match_score');
    final result = <String, dynamic>{
      'requested_category': extractString('requested_category'),
      'requested_categories': extractList('requested_categories'),
      'requested_figures': extractList('requested_figures'),
      'requested_custom_figures': extractList('requested_custom_figures'),
      'best_matched_figure': extractString('best_matched_figure'),
      'best_match_score': num.tryParse(scoreText) ?? 0,
      'overall_summary': extractString('overall_summary'),
    };

    final matches = <Map<String, dynamic>>[];
    final figureRegex = RegExp(r'"figure"\s*:\s*"((?:\\.|[^"\\])*)"', multiLine: true);
    final figureHits = figureRegex.allMatches(chunk).toList();
    for (var idx = 0; idx < figureHits.length; idx++) {
      final current = figureHits[idx];
      final itemStart = current.start;
      final itemEnd = idx + 1 < figureHits.length ? figureHits[idx + 1].start : chunk.length;
      final itemChunk = chunk.substring(itemStart, itemEnd);
      String itemString(String key) {
        final match = RegExp('"' + key + r'"\s*:\s*"((?:\\.|[^"\\])*)"', multiLine: true).firstMatch(itemChunk);
        final value = match?.group(1);
        if (value == null) return '';
        try {
          return _cleanLoopText(jsonDecode('"' + value + '"').toString());
        } catch (_) {
          return _cleanLoopText(value);
        }
      }
      final figure = itemString('figure');
      if (figure.isEmpty) continue;
      final score = itemString('match_score');
      final item = <String, dynamic>{
        'figure': figure,
        'source_category': itemString('source_category'),
        'match_score': num.tryParse(score) ?? 0,
        'match_level': itemString('match_level'),
        'analysis': itemString('analysis'),
        'thought_connection': itemString('thought_connection'),
        'difference_note': itemString('difference_note'),
        'practical_takeaway': itemString('practical_takeaway'),
      }..removeWhere((k, v) => !_hasMeaningfulExtraSectionValue(v));
      if (item.isNotEmpty) matches.add(item);
    }
    if (matches.isNotEmpty) result['matches'] = matches;
    result.removeWhere((k, v) => !_hasMeaningfulExtraSectionValue(v));
    return result;
  }

  Map<String, dynamic> _extractSubconsciousAnalysisFromMalformedRaw(String rawText) {
    final chunk = _extractRawChunkAroundKey(rawText, 'subconscious_analysis');
    if (chunk.isEmpty) return const <String, dynamic>{};
    String extractString(String key) {
      final match = RegExp('"' + key + r'"\s*:\s*"((?:\\.|[^"\\])*)"', multiLine: true).firstMatch(chunk);
      final value = match?.group(1);
      if (value == null) return '';
      try {
        return _cleanLoopText(jsonDecode('"' + value + '"').toString());
      } catch (_) {
        return _cleanLoopText(value);
      }
    }
    final result = <String, dynamic>{
      'core_unconscious_theme': extractString('core_unconscious_theme'),
      'hidden_protective_motive': extractString('hidden_protective_motive'),
      'repeated_inner_script': extractString('repeated_inner_script'),
      'desire_fear_conflict': extractString('desire_fear_conflict'),
      'awareness_upgrade': extractString('awareness_upgrade'),
      'summary': extractString('summary'),
    }..removeWhere((k, v) => !_hasMeaningfulExtraSectionValue(v));
    return result;
  }

  String _extractRawChunkAroundKey(String rawText, String key) {
    final marker = '"$key"';
    final start = rawText.indexOf(marker);
    if (start < 0) return '';
    final nextKeys = <String>[
      '"subconscious_analysis"',
      '"famous_figure_matching"',
      '"AI 原始返回（宽松展示）"',
      '"experience_recap_full"',
      '"result_final_judgement"',
      '"failure_analysis"',
      '"strengths_and_blindspots"',
      '"comparative_judgement"',
      '"related_theories"',
      '"theory_elevation"',
      '"psychology_analysis"',
      '"philosophy_analysis"',
      '"similar_historical_figure"',
      '"next_iteration_guidance"',
    ];
    var end = rawText.length;
    for (final candidate in nextKeys) {
      if (candidate == marker) continue;
      final idx = rawText.indexOf(candidate, start + marker.length);
      if (idx > start && idx < end) end = idx;
    }
    return rawText.substring(start, end);
  }


  dynamic _sanitizeLoopJsonValue(dynamic value) {
    if (value is String) return _cleanLoopText(value);
    if (value is List) {
      return value
          .map(_sanitizeLoopJsonValue)
          .where((e) => !(e is String) || e.trim().isNotEmpty)
          .toList();
    }
    if (value is Map) {
      final mapped = <String, dynamic>{};
      value.forEach((key, val) {
        final sanitized = _sanitizeLoopJsonValue(val);
        if (_hasMeaningfulExtraSectionValue(sanitized)) {
          mapped['$key'] = sanitized;
        }
      });
      return mapped;
    }
    return value;
  }

  bool _hasMeaningfulExtraSectionValue(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      final text = _cleanLoopText(value);
      if (text.isEmpty) return false;
      final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (compact == '未指定定向匹配人物' || compact == '用户未提供人物偏好，无法进行定向匹配。') {
        return false;
      }
      return true;
    }
    if (value is List) return value.any(_hasMeaningfulExtraSectionValue);
    if (value is Map) {
      for (final entry in value.entries) {
        final key = '${entry.key}';
        if (key == 'best_match_score') {
          final score = num.tryParse('${entry.value}'.trim()) ?? 0;
          if (score > 0) return true;
          continue;
        }
        if (_hasMeaningfulExtraSectionValue(entry.value)) return true;
      }
      return false;
    }
    if (value is num) return value != 0;
    if (value is bool) return value;
    return '${value}'.trim().isNotEmpty;
  }

  Map<String, dynamic> _synthesizeLoopSubconsciousAnalysis(
    Map<String, dynamic> working, {
    required String resultJudgement,
    required String resultReasonAnalysis,
    required String patternInduction,
    required String theoryElevation,
    required String retrospectiveGuidance,
  }) {
    String firstNonEmpty(List<String> values) {
      for (final value in values) {
        final trimmed = _cleanLoopText(value);
        if (trimmed.isNotEmpty) return trimmed;
      }
      return '';
    }

    final failure = working['failure_analysis'];
    final psycho = working['psychology_analysis'];
    final psychoanalysis = psycho is Map ? psycho['psychoanalysis'] : null;
    final coreFailurePoint = failure is Map ? _cleanLoopText('${failure['core_failure_point'] ?? ''}') : '';
    final deepAnalysis = failure is Map ? _cleanLoopText('${failure['deep_analysis'] ?? ''}') : '';
    final psychoText = psychoanalysis is Map ? _cleanLoopText('${psychoanalysis['analysis'] ?? ''}') : '';

    final theme = firstNonEmpty([
      psychoText,
      coreFailurePoint.isNotEmpty ? '关键时刻的自我保护性回避：$coreFailurePoint' : '',
      patternInduction,
      resultJudgement,
    ]);
    final motive = firstNonEmpty([
      deepAnalysis.contains('焦虑') || psychoText.contains('焦虑') ? '通过暂时回避行动来避免立即面对焦虑、评估压力或失败感。' : '',
      deepAnalysis.contains('逃避') || psychoText.contains('回避') ? '通过拖延、迟到或不进入情境来保护当下的自我感受。' : '',
      coreFailurePoint.isNotEmpty ? '在关键节点里，潜意识更倾向先保护自己不被压迫，而不是先完成行动。' : '',
    ]);
    final repeatedScript = firstNonEmpty([
      patternInduction,
      resultReasonAnalysis,
      resultJudgement,
    ]);
    final conflict = firstNonEmpty([
      resultJudgement.contains('失败') ? '一方面想获得机会与成长，另一方面又害怕面对结果、评价或自我受挫。' : '',
      theoryElevation.isNotEmpty ? '抽象意图想前进，但真实情境中的压力与回避倾向会拉住行动。' : '',
    ]);
    final awareness = firstNonEmpty([
      retrospectiveGuidance,
      theoryElevation,
      '把焦虑、回避和拖延视为可观察的触发信号，并提前设计第一步行动。',
    ]);
    final summary = firstNonEmpty([
      motive.isNotEmpty ? '这轮行为背后更像是“先保护自己，再决定要不要行动”的潜意识策略。' : '',
      theme,
      resultReasonAnalysis,
    ]);

    return <String, dynamic>{
      'core_unconscious_theme': theme,
      'hidden_protective_motive': motive,
      'repeated_inner_script': repeatedScript,
      'desire_fear_conflict': conflict,
      'awareness_upgrade': awareness,
      'summary': summary,
    }..removeWhere((key, value) => !_hasMeaningfulExtraSectionValue(value));
  }

  String _cleanLoopText(String input) {
    var text = input.replaceAll('\r', '').trim();
    if (text.isEmpty) return '';
    text = text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\"', '"');
    text = text.replaceAll(RegExp(r'(?:\n\s*""\s*){2,}', multiLine: true), '\n');
    text = text.replaceAll(RegExp(r'(?:\s*""\s*){3,}', multiLine: true), ' ');
    final lines = text
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => !_isLikelyLoopNoiseLine(line.trim()))
        .toList();
    text = lines.join('\n').trim();
    if (text.isEmpty) return '';
    final noiseMatch = RegExp(r'([A-Za-z])\1{24,}', multiLine: true).firstMatch(text) ??
        RegExp(r'([A-Za-z]{1,4})\1{12,}', multiLine: true).firstMatch(text);
    if (noiseMatch != null && noiseMatch.start >= 8) {
      text = text.substring(0, noiseMatch.start).trimRight();
    }
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    text = text.replaceAll(RegExp(r'["`]+$'), '').trim();
    return text;
  }
  bool _isLikelyLoopNoiseLine(String line) {
    final text = line.trim();
    if (text.isEmpty) return false;
    if (RegExp('^[{}\[\]"\'`,:;]+\$').hasMatch(text)) return true;
    if (RegExp(r'^(?:""\s*){4,}$').hasMatch(text)) return true;
    if (RegExp(r'^([A-Za-z])\1{20,}$').hasMatch(text)) return true;
    if (RegExp(r'^([A-Za-z]{1,4})\1{10,}$').hasMatch(text)) return true;
    return false;
  }

  bool _looksLikeStructuredJsonBlob(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) || (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return true;
    }
    final lower = trimmed.toLowerCase();
    return lower.contains('"result_final_judgement"') ||
        lower.contains('"failure_analysis"') ||
        lower.contains('"strengths_and_blindspots"') ||
        lower.contains('"comparative_judgement"') ||
        lower.contains('"related_theories"');
  }

  String _sanitizeLoopClosureSummary(
    String closureSummary, {
    required String resultJudgement,
    required String resultReasonAnalysis,
    required String theoryElevation,
    required String retrospectiveGuidance,
  }) {
    final trimmed = closureSummary.trim();
    if (trimmed.isEmpty) {
      for (final candidate in <String>[resultJudgement, resultReasonAnalysis, theoryElevation, retrospectiveGuidance]) {
        final v = candidate.trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }
    if (_looksLikeStructuredJsonBlob(trimmed)) {
      for (final candidate in <String>[resultJudgement, resultReasonAnalysis, theoryElevation, retrospectiveGuidance]) {
        final v = candidate.trim();
        if (v.isNotEmpty && !_looksLikeStructuredJsonBlob(v)) return v;
      }
      return '';
    }
    return trimmed;
  }

  String _buildLoopAnalysisInputJson({
    required GoalSettingSegment segment,
    required String actionTitle,
    required String actionBody,
    required List<String> actionSteps,
    required String latestFact,
    required String latestFeedback,
    required String latestResult,
    required List<GoalSettingFactRecord> records,
    required List<GoalSettingReview> historicalClosedLoops,
    required List<String> figureCategories,
    required String figureCategory,
    required List<String> selectedFigures,
    required List<String> customFigures,
  }) {
    final payload = <String, dynamic>{
      'course_context': <String, dynamic>{
        'segment_id': segment.id,
        'segment_title': segment.title,
        'segment_full_text': segment.originalText,
      },
      'action_context': <String, dynamic>{
        'action_title': actionTitle,
        'action_description': actionBody,
        'action_steps': actionSteps,
      },
      'famous_figure_preference': _buildLoopFamousFigurePreferencePayload(
        figureCategories: figureCategories,
        figureCategory: figureCategory,
        selectedFigures: selectedFigures,
        customFigures: customFigures,
      ),
      'current_attempt': <String, dynamic>{
        'fact': latestFact,
        'feedback': latestFeedback,
        'result': latestResult,
      },
      'current_records': records
          .map((e) => <String, dynamic>{
                'id': e.id,
                'created_at': e.createdAt,
                'action_title': e.actionTitle,
                'fact': e.fact,
                'feedback': e.feedback,
                'result': e.result,
                'evidence': e.evidence,
              })
          .toList(),
      'historical_closed_loops': historicalClosedLoops.map(_buildHistoricalClosedLoopPromptPayload).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Map<String, dynamic> _buildLoopFamousFigurePreferencePayload({
    required List<String> figureCategories,
    required String figureCategory,
    required List<String> selectedFigures,
    required List<String> customFigures,
  }) {
    final normalizedCategories = <String>[];
    for (final raw in figureCategories) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed == GoalSettingFamousFigureCatalog.noneCategory) continue;
      if (!normalizedCategories.contains(trimmed)) normalizedCategories.add(trimmed);
    }
    final fallbackCategory = figureCategory.trim();
    if (normalizedCategories.isEmpty && fallbackCategory.isNotEmpty && fallbackCategory != GoalSettingFamousFigureCatalog.noneCategory) {
      normalizedCategories.add(fallbackCategory);
    }

    final normalizedSelected = <String>[];
    for (final raw in selectedFigures) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (!normalizedSelected.contains(trimmed)) normalizedSelected.add(trimmed);
    }
    final normalizedCustom = <String>[];
    for (final raw in customFigures) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (!normalizedCustom.contains(trimmed)) normalizedCustom.add(trimmed);
    }

    final requestedFigures = <String>[...normalizedSelected, ...normalizedCustom.where((e) => !normalizedSelected.contains(e))];
    final useCandidateFigures = requestedFigures.isEmpty && normalizedCategories.isNotEmpty;
    final candidateFigures = useCandidateFigures
        ? GoalSettingFamousFigureCatalogX.figuresForCategories(normalizedCategories).take(12).toList()
        : const <String>[];

    return <String, dynamic>{
      'category': normalizedCategories.isEmpty ? GoalSettingFamousFigureCatalog.noneCategory : normalizedCategories.join('、'),
      'categories': normalizedCategories,
      'selected_figures': normalizedSelected,
      'custom_figures': normalizedCustom,
      'requested_figures': requestedFigures,
      if (candidateFigures.isNotEmpty) 'candidate_figures': candidateFigures,
    };
  }

  Map<String, dynamic> _buildHistoricalClosedLoopPromptPayload(GoalSettingReview review) {
    return <String, dynamic>{
      'id': review.id,
      'segmentId': review.segmentId,
      'segmentTitle': _cleanLoopText(review.segmentTitle),
      'fact': _cleanLoopText(review.fact),
      'feeling': _cleanLoopText(review.feeling),
      'action': _cleanLoopText(review.action),
      'result': _cleanLoopText(review.result),
      'summary': _cleanLoopText(review.summary),
      'createdAt': review.createdAt,
      'evidenceBasis': review.evidenceBasis.map(_cleanLoopText).where((e) => e.isNotEmpty).toList(),
      'learningSummary': _cleanLoopText(review.learningSummary),
      'abstractConcept': _cleanLoopText(review.abstractConcept),
      'retrospectiveGuidance': _cleanLoopText(review.retrospectiveGuidance),
      'retryPlan': review.retryPlan.map(_cleanLoopText).where((e) => e.isNotEmpty).toList(),
      'courseAnchor': _cleanLoopText(review.courseAnchor),
      'sourceActionTitle': _cleanLoopText(review.sourceActionTitle),
      'resultJudgement': _cleanLoopText(review.resultJudgement),
      'resultReasonAnalysis': _cleanLoopText(review.resultReasonAnalysis),
      'strengthsFound': _cleanLoopText(review.strengthsFound),
      'weaknessesOrBlindspots': _cleanLoopText(review.weaknessesOrBlindspots),
      'patternInduction': _cleanLoopText(review.patternInduction),
      'relatedKnowledgeConcepts': review.relatedKnowledgeConcepts.map(_cleanLoopText).where((e) => e.isNotEmpty).toList(),
      'theoryElevation': _cleanLoopText(review.theoryElevation),
      'courseConnection': _cleanLoopText(review.courseConnection),
      'retryPlanTitle': _cleanLoopText(review.retryPlanTitle),
      'retryVisualPlan': _cleanLoopText(review.retryVisualPlan),
    }..removeWhere((key, value) {
        if (value == null) return true;
        if (value is String) return value.trim().isEmpty;
        if (value is List) return value.isEmpty;
        return false;
      });
  }

  String _buildLoopAnalysisSystemPrompt() {
    return '';
  }

  String _buildHighJudgementLoopUserPrompt({
    required String analysisInputJson,
  }) {
    const template = '''你是“目标训练模块”的顶级 AI 复盘教练、心理学分析教练、理论整合教练与实践规划教练。

你的任务是：基于“课程理论—现实行动—本轮经验—历史经验—历史 AI 复盘数据”整合分析，帮助用户真正理解这次实践中发生了什么、为什么会这样、这意味着什么，以及下一步如何改变。不要复述课程，不要空泛鼓励，不要机械罗列术语。

你必须优先追求：判断准确、证据充分、历史比较清楚、概念匹配贴切、结论对用户真正有帮助。

【分析中心与信息优先级】
始终以本轮经验为中心，按以下顺序理解输入：
1. current_attempt：本轮 fact、feedback、result，是最重要的分析对象；
2. current_records：本轮事实记录明细，用作证据补充；
3. historical_closed_loops：同课程、同行动、且已成功生成 AI 闭环总结的历史数据，用于识别长期模式、重复卡点、进步、改善、升级、转向；
4. action_context：行动说明与行动步骤，用于理解用户在实践什么；
5. course_context：课程完整原文，用于理解理论背景。

【输入字段定位（必须按字段取数，不要猜）】
- course_context.segment_title / segment_full_text：课程标题与课程原文，是理论背景，不等于用户已经发生的事实。
- action_context.action_title / action_description / action_steps：用户当前练习的行动主题、行动说明、行动步骤。
- current_attempt.fact / feedback / result：本轮最核心的事实、反馈、结果。
- current_records：本轮事实记录明细，可作为证据与细节补充。
- historical_closed_loops：历史 AI 闭环总结列表；这里只能用于比较、归纳、识别重复结构、识别改善与升级，不能当作本轮新事实。
- historical_closed_loops 中的常见实际字段包括但不限于：summary、resultJudgement、resultReasonAnalysis、patternInduction、theoryElevation、retrospectiveGuidance、retryPlan。你要把这些看作“历史 AI 复盘数据”，用于比较本轮与历史在断点、模式、改进、重复、升级、转向上的关系。
- famous_figure_preference.selected_figures / custom_figures：用户真正指定要匹配的人物。
- famous_figure_preference.categories：用户选择的人物类别。
- famous_figure_preference.candidate_figures：只有在没有指定具体人物时，才允许从候选中选择 1-3 位。

【结果判定规则（必须严格遵守）】
1. 先只根据 current_attempt 与 current_records 判断本轮结果，不要先看历史就下结论。
2. 若用户完成了本轮行动的核心完成标准，则 label 必须判为“成功”；不得因为过程痛苦、阻力大、成本高，就把已完成行动误判为失败或部分失败。
3. 若用户完成了行动，但过程伴随明显痛苦、阻力、焦虑、自我对抗或高成本体验，你必须在 result_final_judgement.summary 中明确写出：这是“带明显阻力的成功”或“高成本成功”，而不是普通轻松成功。
4. 若用户未完成核心完成标准，但比历史更接近完成，则可判“部分失败”，并在 comparative_judgement.historical_comparison 中明确说明“较历史更接近成功”。
5. 不允许把“底层问题仍存在”直接等同于“本轮没有改善”；你必须同时判断：底层结构是否延续、完成结果是否改善、完成成本是否下降、调节能力是否提升。

【历史比较术语定义（必须按定义使用）】
- 重复：本轮与历史在核心断点上相同，且完成结果、完成度、持续时间、恢复能力均无明显提升。
- 改善：底层问题仍在，但相较历史，本轮完成度、持续时长、恢复能力或执行稳定性出现了明确提升。
- 升级：本轮相较历史，不仅结果更进一步，而且用户已开始出现新的能力（如能带着痛苦完成、能中断后恢复、能主动调节、能提前预热）。
- 转向：核心问题不再主要是历史中的旧断点，而转为新的主导问题。
- 新的结构性变化：历史中未出现过的新矛盾、新断点或新机制。

特别规则：
- 如果历史中曾失败而本轮成功，即使底层阻力仍在，也不得简单写“重复”；必须优先判断是否属于“改善”或“升级”。
- 如果历史中也成功，但本轮成功成本下降、情绪更稳、调节更主动，也应判断为“改善”或“升级”，而不是笼统写“重复”。
- comparative_judgement.historical_comparison 必须明确回答：本轮相对历史，到底是重复、改善、升级、转向还是新的结构性变化。

【历史经验整合要求】
- 只要 historical_closed_loops 非空，你就必须主动结合“当前经验 + 历史经验 + 历史 AI 复盘数据”进行分析，不能只围绕 current_attempt 单独作答。
- 你必须先阅读 historical_closed_loops 中每条记录的实际内容，再判断：本轮相对历史是重复、改善、升级、转向，还是新的结构性变化。
- 你必须把历史经验整合进以下位置：failure_analysis.deep_analysis、comparative_judgement.historical_comparison、theory_elevation、next_iteration_guidance.review_guidance。
- 若 historical_closed_loops 为空，才明确写“暂无历史闭环可比”或等价表述；若 historical_closed_loops 非空，则不得忽略历史部分。
- 课程原文和行动步骤用于理解背景，不要把它们误写成“用户已经完成”的事实。

【证据化要求】
所有关键判断都必须建立在输入中的明确证据上。
尤其是以下四类判断，必须明确基于哪些字段得出：
1. 本轮结果判断：基于 current_attempt 与 current_records；
2. 历史比较判断：基于 historical_closed_loops 中至少一条实际历史记录；
3. 理论提升判断：基于本轮事实 + 历史模式，而不是只引用课程原文；
4. 潜意识分析：只能作为“高可能性的心理结构归纳”，不能把未被输入直接证实的内容写成确定事实。

【优势与潜能深挖要求】
你必须在 strengths_and_blindspots 与 extra_sections.strength_potential_analysis 中重点深挖用户本轮行动中“显而易见的优势”和“不那么显而易见的潜藏优势 / 潜能”。
这不是简单表扬，而是基于证据的深层洞察：必须从 current_attempt、current_records、action_context、historical_closed_loops 和历史 AI 复盘数据中寻找蛛丝马迹。

无论本轮结果是成功、失败还是部分失败，都必须进行优势与潜能分析：
- 成功时：不仅指出完成任务的能力，还要分析背后更深层的能力结构，例如启动能力、坚持能力、情绪承受力、目标感、复盘能力、从历史中改善的能力。
- 失败或部分失败时：不能只写缺点和不足，也要从失败的反面挖掘潜能，例如：愿意记录失败可能说明诚实面对现实；能感到痛苦可能说明价值感仍在；能指出困扰可能说明元认知能力；反复卡住可能说明真正的成长入口已经稳定暴露；未完成但有尝试可能说明启动能力已经存在但维持机制不足。
- 历史经验非空时，必须结合 historical_closed_loops 判断：哪些优势是重复出现的稳定优势，哪些潜能正在萌芽，哪些能力相较历史已有改善或升级。

输出要求：
1. strengths_and_blindspots.strengths 继续输出“这次表现出的优势”，但不能只写表层优点，必须尽量包含“证据线索 → 深层优势 / 潜能 → 未来如何发展”的分析链条；
2. 你还必须额外输出 extra_sections.strength_potential_analysis，用于区别于普通优势项，并在页面中单独展示；
3. extra_sections.strength_potential_analysis 必须包含以下字段：
   - visible_strengths：显而易见的优势，说明证据来自哪里；
   - hidden_strengths：不那么显而易见的潜藏优势 / 潜能，说明是从哪些细节反推出的；
   - reverse_potential_from_weakness：从失败、缺点、痛苦、拖延、回避、自责等反面线索中挖掘出的潜能；
   - historical_strength_evolution：结合 historical_closed_loops 分析优势或潜能相较历史是稳定、改善、升级还是尚未稳定；
   - activation_suggestions：如何把这些潜能转化为下一轮更稳定的行动能力；
4. 若证据足够，visible_strengths 与 hidden_strengths 总数至少 2 条；若证据不足，也至少输出 1 条基于输入证据的谨慎判断；
5. 允许使用“可能体现”“倾向于说明”“这是一种潜在能力线索”等审慎表达，但不能无根据夸大；
6. weaknesses_or_blindspots 仍然要如实指出缺点、盲点和不足，但整体认识必须保持平衡：既看见问题，也看见问题背面暴露出的可发展能力；
7. 如果本轮失败，必须特别说明：失败暴露出的缺点背后，可能对应着哪种尚未成熟的能力或潜能。

【必须优先识别的核心变化】
你必须优先判断：本轮相较历史，最重要的变化是什么。
尤其要注意以下类型：
- 从做不到到做到
- 从中断到完成
- 从完全被情绪压倒到带着痛苦也能执行
- 从没有调节到开始出现调节
- 从结果失败到结果成功但成本仍高
- 从只有目标到开始形成更可执行的行动结构

若存在上述变化，你必须在以下位置明确写出：
- result_final_judgement.summary
- comparative_judgement.historical_comparison
- theory_elevation

【分析要求】
你必须体现出高水平判断力，而不是普通总结。尤其要主动指出：
1. 本轮最核心的问题、突破、变化或矛盾是什么；
2. 哪些看似不同的现象，本质上来自同一个底层结构；
3. 哪些看似相似的现象，其实在目的、功能、心理机制、关系意义或长期后果上不同；
4. 从短期效果和长期成长两个维度，本轮经验分别意味着什么；
5. 若有历史经验，本轮相对于历史是重复、改善、升级、转向，还是新的结构性变化；
6. 当前最值得保留的进步是什么，最需要修正的惯性是什么。

【心理学与哲学要求】
你要以真正懂心理学的方式理解经验，而不是只贴标签。分析时尽量看到：
- 行为层
- 情绪层
- 认知层
- 动机层
- 防御与保护层
- 关系层
- 自我调节层
- 时间结构层

至少考虑以下心理学视角：
- 行为主义
- 认知心理学
- 精神分析/心理动力学
- 人本主义
- 积极心理学
- 存在主义/存在心理学

但不要为了凑学派而硬套；若某学派解释力较弱，要明确说明它更像补充视角而非核心框架。

哲学分析必须真正服务于理解这次经验，重点说明：它如何帮助用户重新理解行动、失败、责任、坚持、自我关系与成长方向。不要只列哲学家名字。

【历史或当今人物相似匹配要求（全球范围）】
你需要判断：用户当前经验与“历史人物或当今人物”之间，是否存在以下四类相似性之一或多项：
1. 经历结构相似：外在经历、成长困境、行动处境在结构上相似；
2. 心理结构相似：情绪冲突、防御机制、自我矛盾、反复脚本相似；
3. 问题意识相似：他们所面对、思考或挣扎的核心问题与用户当前经验高度接近；
4. 应对路径相似：他们处理痛苦、失败、拖延、责任、意志、自我关系的方式，与用户当前需要发展的方向相似。

匹配范围说明：
- 这里的人物范围不限于历史人物，也包括当今仍在世的人物；
- 人物范围覆盖全球，不限国家、地区、文化传统或语言背景；
- 可匹配哲学家、心理学家、作家、艺术家、科学家、企业家、社会活动者、运动员、政治人物、宗教思想者、公共知识分子等，只要其经验结构、问题意识或应对路径与当前经验具有足够相关性；
- 不要求该人物与用户发生“几乎相同的外在事件”；
- 只要在“心理结构 / 问题意识 / 应对路径”中存在中高程度相似，就可以进行匹配；
- 但必须明确说明：相似的是哪一层，不相似的是哪一层，为什么不能简单类比；
- 不得把“思想上相关”直接等同于“经历高度相似”；
- 若只能做到“思想相关”，但做不到“经历结构 / 心理结构 / 应对路径”的中高相似，则应在 extra_sections.famous_figure_matching 中处理，而不是在 similar_historical_figure 中强行给高匹配。

similar_historical_figure 的输出判定规则：
- 虽然字段名保留为 similar_historical_figure，但这里实际表示“历史或当今人物中的最佳参考人物”；
- 若至少在“经历结构 / 心理结构 / 应对路径”三者中有两项达到中高相似，可以输出具体人物；
- 若不存在 80 分以上的高置信匹配，但存在 60-79 分的中等参考匹配，你仍然必须输出当前最佳参考人物，不得直接留空；
- 只有当所有可参考人物的匹配度都低于 60 分时，才允许写“暂时缺乏高置信匹配”；
- 当外在经历相似性不足，但心理结构、问题意识或应对路径相似性达到中高水平时，应优先输出“中等置信度参考人物”，而不是因为外在事件不完全相同就放弃匹配；
- 若只有“思想相关”而缺乏足够的经历或心理结构相似，不应输出为高度相似人物匹配。

匹配评分参考：
- 80-100：经历结构与心理结构都高度相似，且有明确可借鉴的应对路径；
- 60-79：心理结构、问题意识或应对路径高度相似，外在经历不完全相同，但仍具有强参考价值；
- 40-59：只有思想启发相关，不能算真正的高相似参考人物；
- 0-39：不建议匹配。

因此：
- 若达到 80 分以上，可直接输出为高置信匹配；
- 若达到 60-79 分，必须输出，但要在 similarity_summary 中明确写出：“这是中等参考匹配，主要相似于心理结构 / 问题意识 / 应对路径，而不是外在经历完全相同。”；
- 若只能达到 40-59 分，请不要把人物写进 similar_historical_figure 的最终匹配结论里；
- 若低于 60 分，才可写“暂时缺乏高置信匹配”。

similar_historical_figure 字段填写要求：
- name：最佳参考人物姓名；可为历史人物，也可为当今人物；若低于 60 分则写“暂时缺乏高置信匹配”；
- match_confidence：高 / 中 / 低；
- similarity_summary：必须写清楚“相似主要发生在哪一层（经历结构 / 心理结构 / 问题意识 / 应对路径）”；
- brief_intro：只做极简介绍，服务于理解当前经验，不要写成人物百科；
- difference_note：必须明确说明不可简单类比之处，包括时代背景、社会处境、身份角色、问题规模等差异；
- practical_inspiration：必须落到对用户当前这一轮经验真正有帮助的可借鉴点。

【名人思想定向匹配要求】
除了通用的历史人物相似匹配，你还需要结合输入中的 famous_figure_preference，对“用户当前经验 / 历史经验（如果有）”与一个或多个名人的思想、经验结构、问题意识或可借鉴方法进行定向匹配。

这里的重点不是判断“这个名人是否与用户人生经历几乎一样”，而是判断：
- 该名人的思想是否能解释用户当前经验；
- 该名人的问题意识是否与用户当前冲突高度贴近；
- 该名人的方法、精神结构或自我处理方式，是否对用户这轮实践具有直接借鉴价值。
- 这里的人物范围同样覆盖全球，不限于中国或西方，也不限于历史人物；只要是全球各国家、各地区、各文化传统中的人物，且其思想、问题意识或方法对当前经验具有解释力和借鉴价值，都可以纳入匹配。

处理规则如下：
1. 如果 custom_figures 非空，优先围绕这些人物分别进行匹配分析；
2. 如果 custom_figures 为空但 selected_figures 非空，就围绕这些人物分别进行匹配分析；
3. 如果没有指定具体人物，但 categories 非空且 candidate_figures 非空，可以在这些跨类别候选人物中选出 1-3 位最贴切的人物进行匹配；
4. 如果既没有具体人物也没有有效类别，可在该项中明确写“未指定定向匹配人物”。

特别规则：
- 若 selected_figures 或 custom_figures 非空，不要自行补充未指定人物；
- 若 categories 非空但未指定具体人物，最多只选 1-3 位最贴切的人物，不要机械罗列；
- 定向匹配的重点是“谁最能解释这轮经验、谁最值得借鉴”，不是人物百科，也不是平均分配篇幅；
- 允许出现这样的结论：某人物在“思想解释力”上高匹配，但在“经历结构”上并不相似；此时应明确说明；
- 不要因为 generic 历史人物高相似匹配不足，就把 famous_figure_matching 也写空；只要思想解释力、问题意识或实践借鉴价值足够高，就应正常输出；
- 若多个指定人物都相关，必须拉开差异：谁更适合解释当前痛点，谁更适合提供方法，谁更多只是辅助视角。

你需要在 extra_sections.famous_figure_matching 中输出：
- requested_category：用户选择的类别汇总；
- requested_categories：用户选择的类别列表；
- requested_figures：用户选择或输入的人物列表；
- requested_custom_figures：用户手动输入的人物列表；
- best_matched_figure：综合最贴切、对本轮最有解释力和借鉴价值的人物；
- best_match_score：0-100 的综合最佳匹配度；
- overall_summary：整体匹配结论，需明确说明“为什么此人物/这些人物比其他人更贴切”；
- matches：数组中每位人物都要单独包含：
  - figure：人物姓名；
  - source_category：人物所属类别；
  - match_score：0-100 的关联度分数；
  - match_level：高/中/低；
  - analysis：用户经验与该人物思想、问题意识或经验结构重合在哪里；
  - thought_connection：该人物最值得借鉴的思想、方法或精神结构；
  - difference_note：不能简单类比的差异；
  - practical_takeaway：对用户这轮实践最有价值的可借鉴处。

评分建议：
- 80-100：该人物对当前经验的解释力和借鉴价值都很强；
- 60-79：解释力较强，或能提供明确可用的方法；
- 40-59：只有部分启发意义；
- 0-39：关联较弱，不建议纳入最终匹配结果。

【理论提升与概念匹配要求】
你要先从用户本轮经验与历史经验（如果有）中提炼出更深层的经验结构，再去人类已有知识中寻找与之重合度最高、解释力最强的已有概念。

概念匹配时，请遵循以下原则：
1. 首先考虑当前经验本身的结构特征，而不是先决定要用哪门学科；
2. 心理学和哲学是重点优先考虑的来源，但不是唯一来源；
3. 你可以扩展到任何已有知识领域，只要它与当前经验的重合度更高、解释力更强；
4. 不要为了凑概念而硬套；不要因为某概念知名就优先采用；
5. 你需要优先选择“最贴切、最能解释当前经验核心结构”的概念，而不是“最熟悉、最常见”的概念；
6. 如果多个概念都相关，要比较它们的共同点、差异、适用边界，并说明为什么当前更适合用其中某一个；
7. 如果现有人类知识中没有足够贴切的概念，就不要强行匹配；此时应先对经验本身做高度概括与归纳，并在必要时提出一个新的暂定概念。

【潜意识专栏要求】
你还需要基于用户当前输入的行动数据与历史经验（如果有），从潜意识层面做深度分析与解释，目标是帮助用户看见自己当下未被充分意识到的内在驱动力、回避机制、保护性动机和重复脚本。

请在 extra_sections.subconscious_analysis 中输出：
- core_unconscious_theme：本轮经验背后最核心的潜意识主题；
- hidden_protective_motive：潜意识层面可能在保护什么；
- repeated_inner_script：反复出现的潜在内在脚本或自动模式；
- desire_fear_conflict：欲望与恐惧、推进与回避之间的潜在冲突；
- awareness_upgrade：用户最值得提升到意识层面的关键看见；
- summary：对这部分潜意识分析的总结。

潜意识分析约束：
- 这里只能输出“高可能性的心理结构归纳”，不能把未被输入直接证实的内容写成确定事实。
- 若证据不足，请使用“可能”“倾向于”“常表现为”这类表述。
- 不得把推测性内容写成已经被证实的事实。

【成功与失败分流】
若本轮结果是失败或部分失败：
- 必须重点分析失败原因、结构、改变方向；
- 必须给出详细复盘指导和下一轮行动规划。

若本轮结果是成功：
- 不分析成功原因；
- 不规划下一轮行动；
- 但仍可分析优势、不足、相关理论、心理学视角、哲学视角和历史或当今人物参照。
- 若是“带明显阻力的成功”或“高成本成功”，必须明确指出：用户虽然完成了行动，但完成过程成本高，当前最重要的问题已从“能否完成”转向“如何降低完成成本、提高情绪安全感与执行稳定性”。

【输出内容要求】
你必须完成以下内容：
0. 对本轮结果做最终判断；
1. 若失败或部分失败：深度分析失败原因并给出改变建议；若成功：返回 null；
2. 分析本轮体现出的优势，以及不足、缺点、盲点；
3. 深度分析并匹配与这次经验重合度最高、解释力最强的已有概念或理论框架；优先考虑心理学与哲学，但不局限于它们，也可以扩展到任何其他知识领域。你需要指出这些概念之间的共同点、差异、适用边界，以及为什么此时更适合用某个概念来理解当前经验；如果现有知识中没有足够贴切的概念，就不要强行匹配，而应先对经验进行理论层面的归纳和总结，并在必要时提出一个新的暂定概念。
4. 在 theory_elevation 中，先概括本轮经验最核心的结构，再说明与之重合度最高的已有概念或理论框架是什么、为什么更贴切；如果多个概念都相关，要比较后再给出当前最优匹配；如果暂无足够贴切的已有概念，就直接归纳这个经验结构，并在必要时提出一个新的暂定概念。这个字段不能只是重复 related_theories 中某一条概念解释，而要完成“从经验提升到理论层面”的总结。
5. 从多个心理学学派分析当前经验，并说明哪些最能解释核心问题，哪些只是补充；
6. 分析与本轮经验高度相关的哲学思想，并说明它如何帮助用户重新理解这次经验；
7. 匹配高度相似的历史或当今人物（全球范围）；若没有高质量匹配，明确说明；当没有高置信匹配但存在中等参考匹配时，仍须输出最佳参考人物；
8. 结合 famous_figure_preference，输出“名人思想定向匹配”结果：支持同时围绕多个指定人物分别评分、解释和总结；若未指定，则可在类别候选中选出最贴切的 1-3 位人物或明确说明未定向匹配；
9. 在 extra_sections.subconscious_analysis 中输出潜意识层面的深度分析、归纳和总结，帮助用户提升意识；
10. 若失败或部分失败：基于本轮经验与历史经验（如果有），给出详细复盘指导和下一轮实践行动；行动必须不脱离当前行动范畴，且可视化、可执行、具体、可观察；若成功：返回 null。

【输出规则】
只输出一个合法 JSON 对象。
不要输出 markdown、代码块、前言、后记或 JSON 之外的任何文字。
所有字段必须保留；不适用时返回 null、空字符串或空数组。
输出要稳定、清晰、可扩展；如需扩展内容，放入 extra_sections。

【输出 JSON 结构】
{
  "result_final_judgement": {
    "label": "成功/失败/部分失败",
    "confidence": "高/中/低",
    "summary": "对本轮结果的最终判断"
  },
  "failure_analysis": {
    "is_applicable": true,
    "core_failure_point": "本轮失败最核心的断点、失效环节或结构性问题",
    "deep_analysis": "对失败原因的深度分析；若有历史经验，要说明与历史相比是重复、升级、改善还是转向",
    "change_suggestions": ["建议1", "建议2"]
  },
  "strengths_and_blindspots": {
    "strengths": [
      {
        "title": "优势标题",
        "analysis": "为什么这是优势，它体现了怎样的能力或成长方向"
      }
    ],
    "weaknesses_or_blindspots": [
      {
        "title": "不足/缺点/盲点标题",
        "analysis": "为什么这是当前最需要看见和修正的地方"
      }
    ]
  },
  "comparative_judgement": {
    "same_underlying_pattern": ["哪些不同表现本质上来自同一个底层结构"],
    "key_differences": ["哪些内容看似相似，但目的、功能、心理机制或长期后果不同"],
    "function_analysis": {
      "action_function": "这次行动在现实中承担了什么功能",
      "emotion_function": "这次主要情绪承担了什么功能",
      "cognition_function": "当前认知方式在保护什么、限制什么",
      "relationship_function": "关系或他人评价在其中起了什么作用",
      "self_regulation_function": "自我调节系统的关键问题在哪里"
    },
    "short_term_vs_long_term": {
      "short_term": "从短期看，这次经验意味着什么",
      "long_term": "从长期成长看，这次经验意味着什么"
    },
    "historical_comparison": "若有历史数据，说明本轮相对历史是重复、改善、升级、转向还是新变化；若无则返回空字符串"
  },
  "related_theories": [
    {
      "name": "与当前经验高度重合的概念/理论/框架名称；若暂时无法高质量匹配，可写“暂缺高重合已有概念”",
      "source": "所属知识来源，如心理学、哲学、行为科学、社会学、认知科学、教育学、系统论等",
      "relevance_analysis": "为什么它与当前经验高度相关，主要重合在什么结构上",
      "similarities_with_other_concepts": "它与其他相近概念的共同点",
      "differences_from_other_concepts": "它与其他相近概念的差异",
      "scope_and_boundary": "它更适合解释哪一面，不适合解释哪一面",
      "why_this_fits_better": "为什么当前最终更适合用它来理解这次经验"
    }
  ],
  "theory_elevation": "先概括本轮经验最核心的结构，再把它提升到与之重合度最高的已有概念或理论框架；若暂无足够贴切的已有概念，则直接归纳这个经验结构，并在必要时提出新的暂定概念。不要只是重复 related_theories 中单条概念的解释。",
  "psychology_analysis": {
    "behaviorism": {
      "analysis": "从行为主义角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "cognitive_psychology": {
      "analysis": "从认知心理学角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "psychoanalysis": {
      "analysis": "从精神分析/心理动力学角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "humanistic_psychology": {
      "analysis": "从人本主义角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "positive_psychology": {
      "analysis": "从积极心理学角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "existential_psychology": {
      "analysis": "从存在主义/存在心理学角度分析",
      "fit_level": "高/中/低",
      "why": "为什么适合或不太适合"
    },
    "overall_judgement": "综合判断：哪几个心理学视角最能解释本轮核心问题，哪几个只是补充"
  },
  "philosophy_analysis": [
    {
      "tradition": "哲学思想/流派",
      "analysis": "为什么它与本轮经验高度相关",
      "core_help": "它帮助用户重新理解什么"
    }
  ],
  "similar_historical_figure": {
    "name": "人物姓名（可为历史人物或当今人物，范围覆盖全球）；若无高质量匹配则写“暂时缺乏高置信匹配”",
    "match_confidence": "高/中/低",
    "similarity_summary": "相似点",
    "brief_intro": "简要介绍",
    "difference_note": "不能简单类比的差异",
    "practical_inspiration": "可借鉴之处"
  },
  "next_iteration_guidance": {
    "is_applicable": true,
    "review_guidance": "详细复盘指导；若有历史经验，要结合历史模式给出指导",
    "next_action_plan": {
      "plan_title": "下一轮行动标题",
      "visual_script": "可视化行动脚本",
      "steps": ["步骤1", "步骤2", "步骤3"],
      "completion_criteria": "完成标准",
      "fallback_option": "遇阻替代方案"
    }
  },
  "extra_sections": {
    "strength_potential_analysis": {
      "visible_strengths": [
        {
          "title": "显性优势标题",
          "evidence": "来自 current_attempt / current_records / historical_closed_loops 的具体证据线索",
          "analysis": "为什么这是优势，以及它如何帮助本轮行动"
        }
      ],
      "hidden_strengths": [
        {
          "title": "潜藏优势或潜能标题",
          "evidence": "从细节、反应、失败方式或历史变化中反推出的线索",
          "analysis": "为什么这是不那么显而易见但值得发展的潜能"
        }
      ],
      "reverse_potential_from_weakness": [
        {
          "weakness_or_failure_clue": "失败、缺点、痛苦、回避、自责或卡点中的反面线索",
          "potential": "这条反面线索背后可能对应的尚未成熟能力或潜能",
          "development_direction": "如何把它转化为下一轮行动能力"
        }
      ],
      "historical_strength_evolution": "结合 historical_closed_loops 判断这些优势 / 潜能相较历史是稳定、改善、升级还是尚未稳定；若无历史则说明暂无历史可比",
      "activation_suggestions": ["把潜能转化为稳定能力的具体建议1", "具体建议2"]
    },
    "famous_figure_matching": {
      "requested_category": "用户选择的类别汇总；未指定则写“不指定”",
      "requested_categories": ["用户选择的类别列表"],
      "requested_figures": ["用户选择或输入的人物列表"],
      "requested_custom_figures": ["用户手动输入的人物列表"],
      "best_matched_figure": "综合最贴切的人物；若无法高质量匹配则写“暂时缺乏高置信匹配”或“未指定定向匹配人物”",
      "best_match_score": 0,
      "overall_summary": "对多人物匹配结果的整体总结",
      "matches": [
        {
          "figure": "人物姓名",
          "source_category": "人物所属类别",
          "match_score": 0,
          "match_level": "高/中/低",
          "analysis": "当前经验与该人物思想或经验结构重合在哪里",
          "thought_connection": "该人物最值得借鉴的思想、方法或精神结构",
          "difference_note": "不能简单类比的差异",
          "practical_takeaway": "对用户这轮实践最有价值的可借鉴处"
        }
      ]
    },
    "subconscious_analysis": {
      "core_unconscious_theme": "本轮经验背后最核心的潜意识主题",
      "hidden_protective_motive": "潜意识层面可能在保护什么",
      "repeated_inner_script": "反复出现的内在脚本或自动模式",
      "desire_fear_conflict": "欲望与恐惧、推进与回避之间的潜在冲突",
      "awareness_upgrade": "用户最值得提升到意识层面的关键看见",
      "summary": "对这部分潜意识分析的总结"
    }
  }
}

【输入数据】
{{analysis_input_json}}''';
    return template.replaceAll('{{analysis_input_json}}', analysisInputJson);
  }

  String _buildLoopRepairSystemPrompt() {
    return '你是 JSON 修复助手。你的唯一任务是把已有内容整理成一个合法 JSON 对象。不要补写新的分析，不要扩写，不要 markdown，不要代码块，只返回一个合法 JSON 对象。';
  }

  String _buildLoopRepairPrompt({
    required String rawOutput,
    required String analysisInputJson,
  }) {
    return '''请把下面内容整理成一个合法 JSON 对象，并且只返回 JSON。

修复要求：
- 只修 JSON 结构，不重做整轮分析；
- 尽量保留原意，不新增无依据的新结论；
- 缺失字段时：对象填 null 或 {}，数组填 []，字符串填 ""；
- comparative_judgement、related_theories、theory_elevation、psychology_analysis、philosophy_analysis、similar_historical_figure、next_iteration_guidance、extra_sections 都要保留；
- 若 extra_sections 中已有 famous_figure_matching，请优先保留其 requested_figures、best_matched_figure、best_match_score、overall_summary、matches；
- 若 extra_sections 中已有 subconscious_analysis，请优先保留其 core_unconscious_theme、hidden_protective_motive、repeated_inner_script、desire_fear_conflict、awareness_upgrade、summary；
- theory_elevation 需要优先保留已有输出中的“经验结构总结 / 最优概念匹配 / 新概念归纳”，不要只复制某一条 related_theories。
- 课程背景和行动步骤不能被补写成用户已经发生的事实。

固定字段名：
  result_final_judgement, failure_analysis, strengths_and_blindspots, comparative_judgement, related_theories, theory_elevation, psychology_analysis, philosophy_analysis, similar_historical_figure, next_iteration_guidance, extra_sections。

原始输出：
$rawOutput

输入数据（仅用于避免误把背景补成事实）：
$analysisInputJson''';
  }

  String _synthesizeTheoryElevation(
    List<Map<String, dynamic>> theories, {
    dynamic comparative,
    String currentTheoryElevation = '',
  }) {
    if (currentTheoryElevation.trim().isNotEmpty) {
      return currentTheoryElevation.trim();
    }
    if (theories.isEmpty) return currentTheoryElevation.trim();

    final first = theories.first;
    final primaryName = ('${first['name'] ?? ''}').trim();
    final primaryRel = ('${first['relevance_analysis'] ?? ''}').trim();
    final primaryFit = ('${first['why_this_fits_better'] ?? ''}').trim();
    final secondary = theories.length > 1 ? theories[1] : null;
    final secondaryName = secondary == null ? '' : ('${secondary['name'] ?? ''}').trim();
    final secondaryDiff = secondary == null ? '' : ('${secondary['differences_from_other_concepts'] ?? ''}').trim();
    String structure = '';
    if (comparative is Map) {
      final same = _stringList(comparative['same_underlying_pattern']);
      final diffs = _stringList(comparative['key_differences']);
      if (same.isNotEmpty) {
        structure = same.first.trim();
      } else if (diffs.isNotEmpty) {
        structure = diffs.first.trim();
      }
    }

    final parts = <String>[];
    if (structure.isNotEmpty) {
      parts.add('这轮经验更核心的结构是：$structure');
    }
    if (primaryName.isNotEmpty) {
      final reason = primaryFit.isNotEmpty ? primaryFit : primaryRel;
      parts.add(reason.isNotEmpty
          ? '与之重合度最高、当前最适合拿来理解这轮经验的已有概念，是“$primaryName”。$reason'
          : '与之重合度最高、当前最适合拿来理解这轮经验的已有概念，是“$primaryName”。');
    } else if (primaryRel.isNotEmpty) {
      parts.add(primaryRel);
    }
    if (secondaryName.isNotEmpty) {
      parts.add(secondaryDiff.isNotEmpty
          ? '它与“$secondaryName”也有相关之处，但两者的差异在于：$secondaryDiff'
          : '它与“$secondaryName”也有相关之处，但当前第一概念的解释力更强。');
    }
    if (parts.isEmpty && primaryRel.isNotEmpty) {
      parts.add(primaryRel);
    }
    return parts.join('\n');
  }

  Map<String, dynamic> _normalizeExtraSections(dynamic raw) {
    if (raw is Map) return _sanitizeLoopJsonValue(Map<String, dynamic>.from(raw)) as Map<String, dynamic>;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return _sanitizeLoopJsonValue(Map<String, dynamic>.from(decoded)) as Map<String, dynamic>;
      } catch (_) {}
      return <String, dynamic>{'notes': _cleanLoopText(raw)};
    }
    return const <String, dynamic>{};
  }

  bool _passesLoopInsightQualityGate(
    Map<String, dynamic> parsed, {
    required List<GoalSettingFactRecord> records,
    required String draftFact,
    required String draftFeedback,
    required String draftResult,
    String actionTitle = '',
    String segmentTitle = '',
    String actionBody = '',
    List<String> actionSteps = const <String>[],
  }) {
    return _evaluateLoopInsightQualityIssues(
      parsed,
      records: records,
      draftFact: draftFact,
      draftFeedback: draftFeedback,
      draftResult: draftResult,
      actionTitle: actionTitle,
      segmentTitle: segmentTitle,
      actionBody: actionBody,
      actionSteps: actionSteps,
    ).isEmpty;
  }

  List<String> _evaluateLoopInsightQualityIssues(
    Map<String, dynamic> parsed, {
    required List<GoalSettingFactRecord> records,
    required String draftFact,
    required String draftFeedback,
    required String draftResult,
    String actionTitle = '',
    String segmentTitle = '',
    String actionBody = '',
    List<String> actionSteps = const <String>[],
  }) {
    final issues = <String>[];
    final evidenceBasis = _stringList(parsed['evidence_basis']);
    final relatedKnowledgeConcepts = _stringList(parsed['related_knowledge_concepts']);
    final retryPlanSteps = _stringList(parsed['retry_plan_steps']);

    final textFields = <String, String>{
      'experience_recap': ('${parsed['experience_recap'] ?? ''}').trim(),
      'result_judgement': ('${parsed['result_judgement'] ?? ''}').trim(),
      'result_reason_analysis': ('${parsed['result_reason_analysis'] ?? ''}').trim(),
      'strengths_found': ('${parsed['strengths_found'] ?? ''}').trim(),
      'weaknesses_or_blindspots': ('${parsed['weaknesses_or_blindspots'] ?? ''}').trim(),
      'pattern_induction': ('${parsed['pattern_induction'] ?? ''}').trim(),
      'theory_elevation': ('${parsed['theory_elevation'] ?? ''}').trim(),
      'course_connection': ('${parsed['course_connection'] ?? ''}').trim(),
      'retrospective_guidance': ('${parsed['retrospective_guidance'] ?? ''}').trim(),
      'retry_plan_title': ('${parsed['retry_plan_title'] ?? ''}').trim(),
      'retry_visual_plan': ('${parsed['retry_visual_plan'] ?? ''}').trim(),
      'closure_summary': ('${parsed['closure_summary'] ?? ''}').trim(),
    };

    final requiredLongFields = <String>[
      'experience_recap',
      'result_reason_analysis',
      'strengths_found',
      'weaknesses_or_blindspots',
      'pattern_induction',
      'retrospective_guidance',
      'closure_summary',
    ];
    for (final key in requiredLongFields) {
      final value = textFields[key] ?? '';
      if (value.isEmpty) {
        issues.add('$key 为空');
      } else if (value.runes.length < 18) {
        issues.add('$key 过短，像模板话术');
      }
    }

    final resultJudgement = textFields['result_judgement'] ?? '';
    if (resultJudgement.isEmpty) {
      issues.add('result_judgement 为空');
    } else {
      final hasOutcomeWord = <String>['成功', '失败', '部分成功', 'partial', 'success', 'fail'].any((e) => resultJudgement.toLowerCase().contains(e.toLowerCase()));
      if (!hasOutcomeWord) {
        issues.add('result_judgement 未明确判断成功/失败/部分成功');
      }
    }

    if (textFields['theory_elevation']!.isEmpty || textFields['theory_elevation']!.runes.length < 12) {
      issues.add('theory_elevation 为空或过短');
    }
    if (textFields['course_connection']!.isEmpty || textFields['course_connection']!.runes.length < 12) {
      issues.add('course_connection 为空或过短');
    }
    if (textFields['retry_plan_title']!.isEmpty) {
      issues.add('retry_plan_title 为空');
    }
    if (textFields['retry_visual_plan']!.isEmpty || textFields['retry_visual_plan']!.runes.length < 8) {
      issues.add('retry_visual_plan 为空或过短');
    }

    if (evidenceBasis.length < 2) {
      issues.add('evidence_basis 少于 2 条');
    }
    if (relatedKnowledgeConcepts.length < 2) {
      issues.add('related_knowledge_concepts 少于 2 条');
    }
    if (retryPlanSteps.length < 3) {
      issues.add('retry_plan_steps 少于 3 步');
    }

    final anchors = _extractLoopAnchors(
      records: records,
      draftFact: draftFact,
      draftFeedback: draftFeedback,
      draftResult: draftResult,
      actionTitle: actionTitle,
      segmentTitle: segmentTitle,
      actionBody: actionBody,
      actionSteps: actionSteps,
    );
    final evidenceText = evidenceBasis.join('\n');
    final analysisText = <String>[
      evidenceText,
      textFields['experience_recap'] ?? '',
      textFields['result_reason_analysis'] ?? '',
      textFields['strengths_found'] ?? '',
      textFields['weaknesses_or_blindspots'] ?? '',
      textFields['pattern_induction'] ?? '',
      textFields['retrospective_guidance'] ?? '',
      textFields['closure_summary'] ?? '',
    ].join('\n');
    if (anchors.isNotEmpty) {
      final evidenceHits = _countAnchorHits(evidenceText, anchors);
      final analysisHits = _countAnchorHits(analysisText, anchors);
      final recapHits = _countAnchorHits(textFields['experience_recap'] ?? '', anchors);
      final reasonHits = _countAnchorHits(textFields['result_reason_analysis'] ?? '', anchors);
      final patternHits = _countAnchorHits(
        <String>[
          textFields['strengths_found'] ?? '',
          textFields['weaknesses_or_blindspots'] ?? '',
          textFields['pattern_induction'] ?? '',
        ].join('\n'),
        anchors,
      );
      if (evidenceHits < 2) {
        issues.add('evidence_basis 没有充分引用用户输入锚点');
      }
      if (analysisHits < 3) {
        issues.add('整体分析与用户输入绑定不足');
      }
      if (recapHits < 1) {
        issues.add('experience_recap 未引用用户输入关键锚点');
      }
      if (reasonHits < 1) {
        issues.add('result_reason_analysis 未引用用户输入关键锚点');
      }
      if (patternHits < 1) {
        issues.add('优势/盲点/模式分析未引用用户输入关键锚点');
      }
    }

    final genericPhrases = <String>[
      '不是单纯意志不足',
      '触发场景不够清楚',
      '第一步过大',
      '形成闭环',
      '抽象动机',
      '留痕',
      '最先失效的一环',
    ];
    final genericHits = genericPhrases.where((phrase) => analysisText.contains(phrase)).length;
    if (genericHits >= 4 && anchors.isNotEmpty && _countAnchorHits(analysisText, anchors) < 4) {
      issues.add('分析出现明显模板化措辞，且用户证据锚点不足');
    }

    final coreKeys = <String>[
      'experience_recap',
      'result_reason_analysis',
      'strengths_found',
      'weaknesses_or_blindspots',
      'pattern_induction',
    ];
    for (final key in coreKeys) {
      final value = textFields[key] ?? '';
      if (value.isEmpty) continue;
      if (_containsGenericLoopPlaceholder(value) && (anchors.isEmpty || _countAnchorHits(value, anchors) < 1)) {
        issues.add('$key 出现泛化占位表述，缺少真实输入绑定');
      }
    }

    for (final item in relatedKnowledgeConcepts) {
      if (item.trim().runes.length < 8) {
        issues.add('related_knowledge_concepts 存在过短条目');
        break;
      }
    }
    for (final item in retryPlanSteps) {
      if (item.trim().runes.length < 6) {
        issues.add('retry_plan_steps 存在过短步骤');
        break;
      }
    }

    return issues.toSet().toList();
  }

  List<String> _extractLoopAnchors({
    required List<GoalSettingFactRecord> records,
    required String draftFact,
    required String draftFeedback,
    required String draftResult,
    String actionTitle = '',
    String segmentTitle = '',
    String actionBody = '',
    List<String> actionSteps = const <String>[],
  }) {
    final rawParts = <String>[
      actionTitle,
      segmentTitle,
      actionBody,
      ...actionSteps,
      draftFact,
      draftFeedback,
      draftResult,
      ...records.map((e) => e.fact),
      ...records.map((e) => e.feedback),
      ...records.map((e) => e.result),
    ].where((e) => e.trim().isNotEmpty);
    final anchors = <String>[];
    final seen = <String>{};
    for (final part in rawParts) {
      _addLoopAnchorsFromText(part, anchors, seen);
      if (anchors.length >= 24) break;
    }
    return anchors;
  }

  void _addLoopAnchorsFromText(String raw, List<String> anchors, Set<String> seen) {
    final normalized = raw
        .replaceAll('「', ' ')
        .replaceAll('」', ' ')
        .replaceAll('【', ' ')
        .replaceAll('】', ' ')
        .replaceAll('（', ' ')
        .replaceAll('）', ' ')
        .replaceAll('(', ' ')
        .replaceAll(')', ' ')
        .replaceAll('｜', ' ')
        .trim();
    if (normalized.isEmpty) return;

    void addToken(String token) {
      final t = token.trim();
      if (t.isEmpty) return;
      if (RegExp(r'^[0-9]+$').hasMatch(t)) return;
      if (_isLoopStopAnchor(t)) return;
      final minLen = _isMostlyCjk(t) ? 2 : 3;
      if (t.length < minLen || t.length > 24) return;
      final key = t.toLowerCase();
      if (seen.add(key)) anchors.add(t);
    }

    addToken(normalized);
    final stripped = normalized.replaceFirst(RegExp(r'^(今天|昨天|今日|今晚|明天|这次|本次|本轮|这轮|最近一次|最近|当前|现在)'), '').trim();
    if (stripped.isNotEmpty && stripped != normalized) addToken(stripped);

    final parts = normalized
        .split(RegExp(r'[\s,，。；;：:！!？?、/\|]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final part in parts) {
      addToken(part);
      final trimmedTime = part.replaceFirst(RegExp(r'^(今天|昨天|今日|今晚|明天|这次|本次|本轮|这轮|最近一次|最近|当前|现在)'), '').trim();
      if (trimmedTime.isNotEmpty && trimmedTime != part) addToken(trimmedTime);
      if (_isMostlyCjk(part) && part.length >= 5) {
        final variants = <String>{
          part.substring(part.length - 4),
          part.substring(part.length - 3),
        };
        if (part.length >= 6) variants.add(part.substring(part.length - 5));
        for (final variant in variants) {
          addToken(variant);
        }
      }
      if (anchors.length >= 24) return;
    }
  }

  bool _isMostlyCjk(String text) {
    var cjk = 0;
    var letters = 0;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      if ((rune >= 0x4E00 && rune <= 0x9FFF) || (rune >= 0x3400 && rune <= 0x4DBF)) {
        cjk += 1;
        letters += 1;
      } else if (RegExp(r'[A-Za-z0-9]').hasMatch(ch)) {
        letters += 1;
      }
    }
    return letters > 0 && cjk * 2 >= letters;
  }

  bool _isLoopStopAnchor(String token) {
    const stopwords = <String>{
      '用户', '记录', '事实', '反馈', '结果', '当前', '最近', '一次', '本轮', '这轮', '今天', '昨天', '明天',
      '行动', '步骤', '课程', '标题', '说明', '状态'
    };
    return stopwords.contains(token);
  }

  int _countAnchorHits(String text, List<String> anchors) {
    final normalized = text.toLowerCase();
    var hits = 0;
    for (final anchor in anchors) {
      if (anchor.trim().isEmpty) continue;
      if (normalized.contains(anchor.toLowerCase())) hits += 1;
    }
    return hits;
  }

  List<String> _filterBlockingLoopQualityIssues(
    List<String> issues, {
    required Map<String, dynamic> parsed,
    required List<GoalSettingFactRecord> records,
    required String draftFact,
    required String draftFeedback,
    required String draftResult,
    String actionTitle = '',
    String segmentTitle = '',
    String actionBody = '',
    List<String> actionSteps = const <String>[],
  }) {
    if (issues.isEmpty) return const <String>[];
    final evidenceBasis = _stringList(parsed['evidence_basis']);
    final recap = ('${parsed['experience_recap'] ?? ''}').trim();
    final reason = ('${parsed['result_reason_analysis'] ?? ''}').trim();
    final resultJudgement = ('${parsed['result_judgement'] ?? ''}').trim();
    final strengths = ('${parsed['strengths_found'] ?? ''}').trim();
    final weaknesses = ('${parsed['weaknesses_or_blindspots'] ?? ''}').trim();
    final pattern = ('${parsed['pattern_induction'] ?? ''}').trim();
    final anchors = _extractLoopAnchors(
      records: records,
      draftFact: draftFact,
      draftFeedback: draftFeedback,
      draftResult: draftResult,
      actionTitle: actionTitle,
      segmentTitle: segmentTitle,
      actionBody: actionBody,
      actionSteps: actionSteps,
    );
    final evidenceText = evidenceBasis.join('\n');
    final coreText = <String>[recap, reason, resultJudgement].join('\n');
    final patternText = <String>[strengths, weaknesses, pattern].join('\n');
    final evidenceHits = _countAnchorHits(evidenceText, anchors);
    final coreHits = _countAnchorHits(coreText, anchors);
    final patternHits = _countAnchorHits(patternText, anchors);

    bool hasOutcomeWord(String text) =>
        <String>['成功', '失败', '部分成功', 'partial', 'success', 'fail'].any((e) => text.toLowerCase().contains(e.toLowerCase()));

    final blocking = <String>[];
    for (final issue in issues) {
      if (issue == '最终输出不是可解析 JSON。' || issue == '首轮输出不是可解析 JSON。' || issue == '重试输出不是可解析 JSON。') {
        blocking.add(issue);
        continue;
      }
      if (issue == 'result_judgement 为空' || issue == 'result_judgement 未明确判断成功/失败/部分成功') {
        blocking.add(issue);
        continue;
      }
      if (issue == 'experience_recap 为空' || issue == 'result_reason_analysis 为空') {
        blocking.add(issue);
        continue;
      }
      if (issue == 'evidence_basis 少于 2 条') {
        if (evidenceBasis.isEmpty) blocking.add(issue);
        continue;
      }
      if (issue == 'evidence_basis 没有充分引用用户输入锚点') {
        if (evidenceHits == 0 && coreHits == 0) blocking.add(issue);
        continue;
      }
      if (issue == '整体分析与用户输入绑定不足') {
        if (coreHits == 0 && evidenceHits == 0) blocking.add(issue);
        continue;
      }
      if (issue == 'experience_recap 未引用用户输入关键锚点' || issue == 'result_reason_analysis 未引用用户输入关键锚点') {
        if (coreHits == 0 && evidenceHits == 0) blocking.add(issue);
        continue;
      }
      if (issue == '优势/盲点/模式分析未引用用户输入关键锚点') {
        if (patternText.isNotEmpty && patternHits == 0 && coreHits == 0 && evidenceHits == 0) blocking.add(issue);
        continue;
      }
      if (issue.contains('出现泛化占位表述')) {
        blocking.add(issue);
        continue;
      }
      if (issue == '分析出现明显模板化措辞，且用户证据锚点不足') {
        if (evidenceHits == 0 && coreHits == 0) blocking.add(issue);
        continue;
      }
      if (issue.endsWith('为空')) {
        if (issue.startsWith('strengths_found') || issue.startsWith('weaknesses_or_blindspots') || issue.startsWith('pattern_induction')) {
          continue;
        }
        if (issue.startsWith('theory_elevation') || issue.startsWith('course_connection') || issue.startsWith('retrospective_guidance') || issue.startsWith('retry_plan_title') || issue.startsWith('retry_visual_plan') || issue.startsWith('closure_summary')) {
          continue;
        }
      }
      if (issue.contains('过短')) {
        continue;
      }
      if (issue.startsWith('related_knowledge_concepts ') || issue.startsWith('retry_plan_steps ')) {
        continue;
      }
      if (!hasOutcomeWord(resultJudgement) || recap.isEmpty || reason.isEmpty) {
        blocking.add(issue);
      }
    }
    return blocking.toSet().toList();
  }

  bool _containsGenericLoopPlaceholder(String text) {
    final placeholders = <String>[
      '某项目标',
      '某个目标',
      '某件事',
      '某种情绪',
      '用户尝试了',
      '这可能源于',
      '目标执行中断',
      '情绪干扰',
      '用户在这次经历中',
      '某个任务',
    ];
    return placeholders.any((e) => text.contains(e));
  }

  bool _isAllowedPartialRecoveryIssue(String issue) {
    const allowedPrefixes = <String>[
      'theory_elevation 为空或过短',
      'course_connection 为空或过短',
      'retrospective_guidance ',
      'retry_plan_title ',
      'retry_visual_plan ',
      'retry_plan_steps ',
      'closure_summary ',
      'related_knowledge_concepts 少于 2 条',
      'related_knowledge_concepts 存在过短条目',
    ];
    for (final prefix in allowedPrefixes) {
      if (issue.startsWith(prefix)) return true;
    }
    return false;
  }

  List<String> _buildFallbackEvidenceBasis(List<GoalSettingFactRecord> records) {
    final items = <String>[];
    for (final entry in records.asMap().entries) {
      final r = entry.value;
      if (r.fact.isNotEmpty) items.add('记录${entry.key + 1}事实：${r.fact}');
      if (r.feedback.isNotEmpty) items.add('记录${entry.key + 1}反馈：${r.feedback}');
      if (r.result.isNotEmpty) items.add('记录${entry.key + 1}结果：${r.result}');
    }
    return items;
  }

  String _buildBehaviorChain(GoalSettingAction action) {
    final steps = action.steps.where((e) => e.trim().isNotEmpty).toList();
    if (steps.isEmpty) {
      return '触发：遇到相关困境时；第一步：先做一个 5 分钟最小动作；留痕：完成后立即记录事实、反馈和结果。';
    }
    final buffer = <String>[];
    for (var i = 0; i < steps.length; i++) {
      buffer.add('第${i + 1}步：${steps[i]}');
    }
    buffer.add('完成后：立刻记录事实、反馈和结果。');
    return buffer.join('；');
  }

  String _buildFallbackResultJudgement(List<GoalSettingFactRecord> records, String actionStatus) {
    if (records.isEmpty) {
      return actionStatus == 'done' ? '部分成功：状态显示已完成，但缺少事实记录作为依据。' : '部分成功：已有行动意图，但证据不足，暂不能判定完全成功或失败。';
    }
    final joined = records.map((e) => '${e.feedback} ${e.result}').join(' ').toLowerCase();
    final successHits = ['完成', '做到', '推进', '成功', '开始', '坚持'].where((e) => joined.contains(e)).length;
    final failHits = ['失败', '没', '未', '拖', '中断', '放弃', '逃避'].where((e) => joined.contains(e)).length;
    if (successHits > 0 && failHits == 0) return '成功：有清晰结果与推进证据。';
    if (failHits > 0 && successHits == 0) return '失败：目前记录显示关键行为链没有跑通。';
    return '部分成功：有推进，但关键环节仍存在中断或阻碍。';
  }

  String _buildFallbackResultReasonAnalysis({
    required GoalSettingAction action,
    required List<GoalSettingFactRecord> records,
    required String actionStatus,
  }) {
    if (records.isEmpty) {
      return '当前还缺少足够的事实、反馈与结果记录，因此不能对成功或失败原因做可靠判断。下一步应先补一条包含“做了什么 / 遇到什么 / 结果如何”的记录。';
    }
    final latest = records.first;
    final text = '${latest.fact} ${latest.feedback} ${latest.result}'.trim();
    final lower = text.toLowerCase();
    final failed = text.contains('失败') || text.contains('没') || text.contains('未') || text.contains('拖') || text.contains('中断') || lower.contains('fail');
    if (failed) {
      return '根据用户记录，这轮更像是在“启动到第一步”之间或“做完后留痕”这一环出现中断。原因不是单纯意志不足，而更像触发场景不够清楚、第一步过大、情绪阻碍或完成后没有形成闭环。';
    }
    return '根据用户记录，这轮之所以能够推进，说明触发场景、第一步动作或留痕方式里至少有一环是有效的。真正值得保留的是这些可重复的成功条件，而不是笼统地说“我这次状态好”。';
  }

  String _buildFallbackStrengths(List<GoalSettingFactRecord> records) {
    if (records.isEmpty) return '当前最明显的优势是：你愿意进入练习并尝试记录，这为后续成长提供了最基本的证据。';
    return '这轮实践中表现出的优势包括：愿意把抽象想法带进真实场景、愿意记录过程、能够在结果不完美时仍然留下反馈。';
  }

  String _buildFallbackWeaknesses(List<GoalSettingFactRecord> records, String actionStatus) {
    if (records.isEmpty) return '当前暴露出的主要盲点是：缺少足够事实记录，导致复盘容易停留在印象层而不是证据层。';
    final latest = records.first;
    return '这轮更明显的薄弱环节在于：${latest.feedback.trim().isNotEmpty ? latest.feedback.trim() : '行为链中的触发、第一步或留痕环节还不稳定'}。这提示你下一轮要优先修“最先失效的一环”。';
  }

  String _buildFallbackPatternInduction(List<GoalSettingFactRecord> records, String actionTitle) {
    if (records.isEmpty) return '目前可提炼的模式是：在没有足够事实证据时，人容易把行动问题理解成自我评价问题。';
    return '从这轮经验可提炼出的模式是：你在面对「$actionTitle」时，真正影响结果的往往不是抽象动机，而是触发是否清楚、第一步是否过大、以及是否及时留痕。';
  }

  List<String> _buildFallbackKnowledgeConcepts(List<GoalSettingFactRecord> records) {
    if (records.isEmpty) {
      return const <String>[
        '方法论层面｜证据优先：在心理学与实践哲学中，缺少经验材料就无法做可靠归纳。',
        '反思方法｜事实记录：没有事实记录，复盘容易退化成自我评价。',
      ];
    }
    final joined = records.map((e) => '${e.fact} ${e.feedback} ${e.result}').join(' ').toLowerCase();
    final hasFail = ['失败', '没', '未', '拖', '中断', '放弃', '逃避', '自责', '焦虑'].any((e) => joined.contains(e));
    if (hasFail) {
      return const <String>[
        '行为主义 / 行为设计｜行为链设计：失败往往不是“人不行”，而是触发、第一步或强化链没有设计好。',
        '认知心理学｜自我效能感：一次受阻后若把结果解释成“我就是做不到”，后续启动成本会继续升高。',
        '精神分析 / 心理动力学｜防御与回避：拖延、逃开、合理化有时是为了暂时躲开羞耻、焦虑或自我价值受损。',
        '存在主义 / 人本主义｜意义与选择：若行动与真实价值脱节，人会在关键时刻失去承担与投入。',
        '积极心理学｜优势与韧性：即使失败，也要识别已经出现的优势信号，否则容易只剩负面自我定义。',
      ];
    }
    return const <String>[
      '行为主义 / 行为设计｜实施意图：成功往往来自明确触发和较小可执行动作，而不是抽象决心。',
      '认知心理学｜自我效能感：成功经验会提升“我能做到”的判断，并增加下一次启动概率。',
      '积极心理学｜优势识别：保留成功时真正起作用的优势，比笼统夸自己更有复用价值。',
      '实用主义｜用结果检验方法：有效的做法值得继续迭代，而不是停留在概念正确。',
    ];
  }

  String _buildFallbackTheoryElevation({required GoalSettingSegment segment, required List<GoalSettingFactRecord> records, required String actionTitle}) {
    if (records.isEmpty) {
      return '当前更适合把这轮经验提升到“方法论”层面来理解：没有足够事实记录时，任何理论归纳都容易失真。先补足证据，再谈哪一类心理机制或哲学问题更相关。';
    }
    final joined = records.map((e) => '${e.fact} ${e.feedback} ${e.result}').join(' ');
    final hasFail = ['失败', '没', '未', '拖', '中断', '放弃', '逃避', '自责', '焦虑'].any((e) => joined.contains(e));
    if (hasFail) {
      return '从理论层面看，这轮更像是一个“行动结构失配 + 情绪防御并存”的失败经验：一方面，行为主义/行为设计会提醒你检查触发—动作—强化链是否过大或断裂；另一方面，精神分析与存在主义视角会提醒你，失败不只可能是技术问题，也可能和羞耻、自我评价、意义感不足或对选择后果的回避有关。若现有概念仍不足以贴合，可暂时把这类经验命名为“启动后退缩型失败”——指用户不是完全没有意愿，而是在真正启动或留痕时被内外阻力拉回去。';
    }
    return '从理论层面看，这轮更像是一个“有效触发 + 小步推进 + 正反馈累积”的成功经验。行为设计强调清晰触发与小动作，人本主义和积极心理学则提醒你看到自己已经在行动中展现出的主动性、价值感与优势。若要给这类经验一个更概括的名字，可以叫“可复制的小步成功结构”——即通过清晰触发、低阻力启动与及时留痕，让成功不再只靠一时状态。';
  }

  String _buildFallbackCourseConnection({required GoalSettingSegment segment, required List<GoalSettingFactRecord> records}) {
    return '当前课程原文提供的是训练语境：${segment.title}。从这轮经验看，课程强调的不是空想目标，而是把目标压到具体行为结构中去。';
  }

  String _buildFallbackRetryVisualPlan({required GoalSettingAction action, required List<GoalSettingFactRecord> records}) {
    return '下一次当你再次遇到与「${action.title}」相关的真实情境时，在一个固定地点先只做第一步动作，做完后立即写下事实、反馈和结果，避免这轮再次只停留在感受层。';
  }

  List<String> _buildFallbackRetrySteps({required GoalSettingSegment segment, required GoalSettingAction action, required List<GoalSettingFactRecord> records}) {
    return <String>[
      '先固定一个会再次出现的具体场景，例如今天晚上回到书桌前或明天上班打开电脑后。',
      '只执行第一步：${action.steps.isNotEmpty ? action.steps.first : '先做一个 5 分钟最小动作'}。',
      '如果卡住，立刻执行降级方案：${action.fallbackAction}',
      '完成后 1 分钟内写下事实、反馈和结果，作为下一轮复盘依据。',
    ];
  }

  String _buildFallbackExperienceRecap({
    required GoalSettingAction action,
    required List<GoalSettingFactRecord> records,
    required String actionStatus,
  }) {
    if (records.isEmpty) {
      return '目前还没有足够的实践证据。当前状态是「$actionStatus」，说明这轮练习还停留在准备阶段。下一步先在一个明确场景里做出一次可观察动作，并立即留下事实记录。';
    }
    final latest = records.first;
    final fact = latest.fact.trim();
    final resultText = latest.result.trim().isEmpty ? '结果尚未写清。' : '结果是：${latest.result.trim()}';
    final feedbackText = latest.feedback.trim().isEmpty ? '反馈尚未写清。' : '当时的反馈是：${latest.feedback.trim()}';
    final looksLikeOutcomeOnly = fact.contains('失败') || fact.contains('没') || fact.contains('未') || fact.contains('达成目标') || fact.contains('没做到');
    if (looksLikeOutcomeOnly) {
      return '最近一次围绕「${action.title}」的实践中，你已经尝试推进这个动作；目前能确认的事实是：${fact.isEmpty ? '尚未写清具体执行细节。' : fact}，$feedbackText $resultText 这说明这轮记录更清楚地保留了结果与情绪，但具体执行细节还需要在下一轮补得更完整。';
    }
    return '最近一次围绕「${action.title}」的实践中，你实际做了：${fact.isEmpty ? '尚未写清具体动作。' : fact} $feedbackText $resultText 这说明你已经把课程从想法推进到了真实场景。';
  }

  String _buildFallbackLearningSummary({
    required GoalSettingAction action,
    required List<GoalSettingFactRecord> records,
    required String actionStatus,
  }) {
    if (records.isEmpty) {
      return '当前最关键的学习点不是再理解概念，而是先补一条真实证据：什么时候开始、做了什么、卡在了哪一步。没有证据，复盘就会滑向空泛。';
    }
    final latest = records.first;
    final text = '${latest.feedback} ${latest.result}'.trim();
    final lower = text.toLowerCase();
    final failed = text.contains('失败') || text.contains('没') || text.contains('未') || text.contains('拖') || lower.contains('fail');
    if (failed) {
      return '这次失败或停滞暴露出的不是“你不行”，而是行为链不够清楚：要么触发场景不明确，要么第一步太大，要么做完后没有及时留痕。真正该学到的是：下一轮要把动作缩小、场景固定、记录提前准备好。';
    }
    return '这次经验里已经出现了有效信号：你能够启动并留下结果。下一步要学到的不是“我终于做到了”这么笼统，而是具体识别：是哪一个触发场景、哪一个第一步、哪一种留痕方式最帮你推进。';
  }

  String _buildFallbackAbstractConcept({
    required GoalSettingSegment segment,
    required GoalSettingAction action,
    required List<GoalSettingFactRecord> records,
  }) {
    final key = segment.concepts.isNotEmpty ? segment.concepts.take(3).join('、') : segment.title;
    if (records.isEmpty) {
      return '从这段课看，当前最需要被验证的概念是「$key」：抽象原则只有压成具体行为链，才会真正产生作用。';
    }
    return '从这轮经验可抽出来的概念是：这段课强调的「$key」并不是停留在理解层，而是要通过明确触发、最小动作、事实留痕，把抽象原则转成可重复的行为结构。';
  }

  String _buildFallbackGuidance({
    required GoalSettingSegment segment,
    required GoalSettingAction action,
    required List<GoalSettingFactRecord> records,
  }) {
    if (records.isEmpty) {
      return '先不要急着下结论，下一轮最优先修的是“证据采集”这一环：挑一个明确场景，按行动链只做第一步，并在结束后 1 分钟内写下事实、反馈和结果。';
    }
    final latest = records.first;
    final evidence = '${latest.fact} ${latest.feedback} ${latest.result}'.trim();
    final failed = evidence.contains('失败') || evidence.contains('没') || evidence.contains('未') || evidence.contains('拖') || evidence.contains('不想');
    if (failed) {
      return '复盘指导：下一轮先不要扩大目标，优先修“第一步过大/触发不清”这一环。做法是固定一个更具体的触发场景，把第一步缩到 5-15 分钟，并提前准备留痕方式。';
    }
    return '复盘指导：下一轮优先固化这次有效环节——把最有帮助的触发场景、第一步动作和留痕方式写成固定模板，并在同类情境里再次复用。';
  }

  List<String> _buildFallbackRetryPlan({
    required GoalSettingAction action,
    required List<GoalSettingFactRecord> records,
  }) {
    final scene = records.isEmpty ? '今晚 20:00，在你通常最容易拖延的那个地点' : '下一次再次出现同类情境时（例如你又想回避「${action.title}」）';
    return <String>[
      '重新挑战标题：把课程原则压成下一次看得见的动作。',
      '可视化场景：$scene，先不要追求完整解决，只追求启动第一步。',
      '第一步动作：${action.steps.isNotEmpty ? action.steps.first : '先做一个 5 分钟的最小动作'}。',
      '遇阻替代：如果卡住，立刻执行降级方案——${action.fallbackAction}',
      '完成留痕：动作结束后 1 分钟内写下“我做了什么、卡在哪、结果如何”。',
    ];
  }

  String _buildFallbackClosureSummary(List<GoalSettingFactRecord> records) {
    if (records.isEmpty) {
      return '你现在最需要补的不是更多想法，而是一条真实记录：先做，再记，再用记录来提炼概念。';
    }
    return '真正的闭环不是“这次成不成功”，而是把这次经验变成下一轮更清楚的动作设计。';
  }

  List<GoalSettingAction> previewActionOptions({
    required GoalSettingSegment segment,
    String userConcern = '',
  }) => _buildLocalActions(segment: segment, userConcern: userConcern);

  String buildReviewSummary({
    required GoalSettingSegment segment,
    required String fact,
    required String feeling,
    required String action,
    required String result,
  }) {
    return '你这次围绕「${segment.title}」做了一次现实练习。事实层面：$fact。感受层面：$feeling。行动层面：$action。结果层面：$result。结合这段课程，更值得保留的不是一句口号，而是你今天真正做出的那一步。下一次建议：把动作再缩小一点，但保持重复。';
  }

  List<String> buildReviewQuestions({required GoalSettingSegment segment}) => <String>[
        '这次行动里，最接近客观事实的一句话是什么？',
        '你原本担心什么，真实发生了什么？',
        segment.reflectionQuestion,
        '下一次我最想保留的一个动作是什么？',
      ];

  List<GoalSettingAction> _buildLocalActions({required GoalSettingSegment segment, required String userConcern}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final concern = userConcern.trim().isEmpty ? '当前先按课程默认动作来练。' : userConcern.trim();
    return <GoalSettingAction>[
      GoalSettingAction(
        id: 'gs_local_min_${segment.id}_$now',
        segmentId: segment.id,
        segmentTitle: segment.title,
        level: 'min',
        source: 'local',
        title: '最小动作｜${segment.defaultActionTitle}',
        body: '围绕你的现实问题「$concern」，先完成一个低阻力版本：${segment.defaultActionBody}',
        steps: segment.howSteps.take(2).toList(),
        successCriteria: '今天能开始，并留下 1 条事实记录。',
        fallbackAction: '如果做不完整，就只完成第一步。',
        reviewQuestion: segment.reflectionQuestion,
        createdAt: now,
      ),
      GoalSettingAction(
        id: 'gs_local_std_${segment.id}_$now',
        segmentId: segment.id,
        segmentTitle: segment.title,
        level: 'standard',
        source: 'local',
        title: '标准动作｜${segment.defaultActionTitle}',
        body: segment.defaultActionBody,
        steps: segment.howSteps,
        successCriteria: '完成一次完整练习，并写出一个新理解。',
        fallbackAction: '如果卡住，就把动作缩小到 10 分钟。',
        reviewQuestion: segment.reflectionQuestion,
        createdAt: now + 1,
      ),
      GoalSettingAction(
        id: 'gs_local_deep_${segment.id}_$now',
        segmentId: segment.id,
        segmentTitle: segment.title,
        level: 'deep',
        source: 'local',
        title: '挑战动作｜把它带进真实场景',
        body: '把这段课程真正带进一个现实场景：$concern。不是只写下来，而是在事情发生时当场使用。',
        steps: <String>[...segment.howSteps, '结束后写一次复盘'],
        successCriteria: '在现实场景里完成一次迁移应用。',
        fallbackAction: '如果真实场景难度太大，就先做脑内预演。',
        reviewQuestion: segment.reflectionQuestion,
        createdAt: now + 2,
      ),
    ];
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      return <String, dynamic>{'body': value.trim()};
    }
    return <String, dynamic>{};
  }

  String _readActionTitle(Map<String, dynamic> obj, {required String fallback}) {
    final raw = ('${obj['title'] ?? ''}').trim();
    return raw.isEmpty ? fallback : raw;
  }

  String _readActionBody(Map<String, dynamic> obj, {required String fallback}) {
    final raw = ('${obj['body'] ?? ''}').trim();
    return raw.isEmpty ? fallback : raw;
  }

  List<String> _readActionSteps(Map<String, dynamic> obj, {required List<String> fallback}) {
    final steps = _stringList(obj['steps']);
    return steps.isEmpty ? fallback : steps;
  }

  bool _looksLikeActionErrorResponse(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return true;
    const hardSignals = <String>[
      '"error"',
      'request failed',
      'api error',
      'invalid api key',
      'authentication failed',
      'rate limit',
      'context length',
      'timeout',
      'timed out',
      '网络错误',
      '请求失败',
      '调用失败',
      '认证失败',
      '超时',
      '限流',
    ];
    for (final signal in hardSignals) {
      if (text.contains(signal)) return true;
    }
    return false;
  }


  List<GoalSettingAction>? _salvageActionsFromRaw({
    required String raw,
    required GoalSettingSegment segment,
    required String userConcern,
    required List<GoalSettingAction> fallback,
  }) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final lines = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    String? current;
    final sections = <String, List<String>>{'min': <String>[], 'standard': <String>[], 'deep': <String>[]};

    String detect(String line) {
      final s = line.replaceAll('：', ':');
      if (RegExp(r'^(最小动作|最小行动|微行动|minimal_action|minimal action)', caseSensitive: false).hasMatch(s)) return 'min';
      if (RegExp(r'^(标准动作|标准行动|standard_action|standard action)', caseSensitive: false).hasMatch(s)) return 'standard';
      if (RegExp(r'^(深度动作|深度行动|挑战动作|deep_action|deep action)', caseSensitive: false).hasMatch(s)) return 'deep';
      return '';
    }

    for (final line in lines) {
      final hit = detect(line);
      if (hit.isNotEmpty) {
        current = hit;
        sections[current]!.add(line);
      } else if (current != null) {
        sections[current]!.add(line);
      }
    }

    final hasSections = sections.values.any((e) => e.isNotEmpty);
    if (!hasSections) {
      sections['standard'] = lines;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    GoalSettingAction build(String level, List<String> sec, GoalSettingAction fb, int offset) {
      final bodyLines = <String>[];
      final steps = <String>[];
      String success = fb.successCriteria;
      String fallbackAction = fb.fallbackAction;
      String title = fb.title;
      for (final line in sec) {
        final normalized = line.replaceAll('：', ':');
        if (normalized.contains(':') && (normalized.startsWith('最小动作') || normalized.startsWith('最小行动') || normalized.startsWith('微行动') || normalized.startsWith('标准动作') || normalized.startsWith('标准行动') || normalized.startsWith('深度动作') || normalized.startsWith('深度行动') || normalized.startsWith('挑战动作'))) {
          final parts = normalized.split(':');
          if (parts.length >= 2 && parts.sublist(1).join(':').trim().isNotEmpty) {
            title = parts.sublist(1).join(':').trim();
          }
          continue;
        }
        if (normalized.startsWith('完成标准:') || normalized.startsWith('完成标准：')) {
          success = normalized.split(':').sublist(1).join(':').trim();
          continue;
        }
        if (normalized.startsWith('降级动作:') || normalized.startsWith('失败后的降级动作:') || normalized.startsWith('fallback_action:')) {
          fallbackAction = normalized.split(':').sublist(1).join(':').trim();
          continue;
        }
        if (line.startsWith('-') || line.startsWith('•') || RegExp(r'^[0-9]+[.、]').hasMatch(line)) {
          steps.add(line.replaceFirst(RegExp(r'^[-•]\s*'), '').replaceFirst(RegExp(r'^[0-9]+[.、]\s*'), '').trim());
        } else {
          bodyLines.add(line);
        }
      }
      final body = bodyLines.join('\n').trim().isEmpty ? fb.body : bodyLines.join('\n').trim();
      return GoalSettingAction(
        id: 'gs_salvage_${level}_${segment.id}_$now',
        segmentId: segment.id,
        segmentTitle: segment.title,
        level: level,
        source: 'ai',
        title: title,
        body: body,
        steps: steps.isEmpty ? fb.steps : steps,
        successCriteria: success.isEmpty ? fb.successCriteria : success,
        fallbackAction: fallbackAction.isEmpty ? fb.fallbackAction : fallbackAction,
        reviewQuestion: fb.reviewQuestion,
        createdAt: now + offset,
      );
    }

    return <GoalSettingAction>[
      build('min', sections['min']!, fallback[0], 0),
      build('standard', sections['standard']!, fallback[1], 1),
      build('deep', sections['deep']!, fallback[2], 2),
    ];
  }

  String _readActionField(Map<String, dynamic> obj, String key, {required String fallback}) {
    final raw = ('${obj[key] ?? ''}').trim();
    return raw.isEmpty ? fallback : raw;
  }

  Future<String> _requestText({required String prompt, required String purpose, String? systemPrompt}) async {
    return _unifiedAiService.generateText(
      prompt: prompt,
      purpose: 'goal_setting_ai.$purpose',
      systemPrompt: systemPrompt ?? _defaultSystemPromptForPurpose(purpose),
      maxTokens: _openAiMaxTokensForPurpose(purpose),
      expectJson: _expectsJsonResponse(purpose),
      temperature: 0.1,
    );
  }

  String _defaultSystemPromptForPurpose(String purpose) {
    switch (purpose) {
      case 'goal_setting_loop':
        return _buildLoopAnalysisSystemPrompt();
      case 'goal_setting_understanding':
      case 'goal_setting_actions':
      default:
        return '你是目标设定知行课的 AI 教练。回答必须全中文；若要求 JSON，则只能输出 JSON 对象。';
    }
  }

  bool _expectsJsonResponse(String purpose) {
    switch (purpose) {
      case 'goal_setting_understanding':
      case 'goal_setting_actions':
      case 'goal_setting_loop':
        return true;
      default:
        return false;
    }
  }

  int _openAiMaxTokensForPurpose(String purpose) {
    switch (purpose) {
      case 'goal_setting_loop':
        return 4200;
      case 'goal_setting_actions':
        return 1800;
      case 'goal_setting_understanding':
        return 1500;
      default:
        return 1800;
    }
  }

  String _extractText(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map && data['output'] is List) {
        for (final dynamic item in data['output'] as List) {
          if (item is Map && item['content'] is List) {
            for (final dynamic content in item['content'] as List) {
              if (content is Map && content['text'] != null) return _cleanLoopText(content['text'].toString());
            }
          }
        }
      }
      if (data is Map && data['choices'] is List && (data['choices'] as List).isNotEmpty) {
        final first = (data['choices'] as List).first;
        if (first is Map) {
          final msg = first['message'];
          if (msg is Map) {
            final content = msg['content'];
            if (content is String) return _cleanLoopText(content);
            if (content is List) {
              final buffer = StringBuffer();
              for (final item in content) {
                if (item is Map && item['text'] != null) buffer.write(item['text'].toString());
              }
              if (buffer.isNotEmpty) return _cleanLoopText(buffer.toString());
            }
          }
        }
      }
      if (data is Map && data['content'] != null) return _cleanLoopText(data['content'].toString());
    } catch (_) {}
    return _cleanLoopText(raw);
  }

  Map<String, dynamic> _extractJsonObject(String raw) {
    final normalized = _normalizeJsonCandidate(raw);
    if (normalized.isEmpty) return <String, dynamic>{};
    for (final candidate in <String>[
      normalized,
      _sliceToOutermostJson(normalized),
      _sliceToBalancedJson(normalized),
    ]) {
      final text = candidate.trim();
      if (text.isEmpty) continue;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        if (decoded is String && decoded.trim().isNotEmpty) {
          final nested = _extractJsonObject(decoded);
          if (nested.isNotEmpty) return nested;
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  String _normalizeJsonCandidate(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    text = text.replaceAll(RegExp(r'^[^{\[]*'), '');
    text = text.replaceAll(RegExp(r'[^}\]]*$'), '');
    text = text.replaceAll('“', '"').replaceAll('”', '"').replaceAll('’', "'");
    text = text.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    return text.trim();
  }

  String _sliceToOutermostJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) return text.substring(start, end + 1);
    return text;
  }

  String _sliceToBalancedJson(String text) {
    final start = text.indexOf('{');
    if (start < 0) return text;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          return text.substring(start, i + 1);
        }
      }
    }
    return _sliceToOutermostJson(text);
  }

  Map<String, dynamic> _recoverLoopInsightFromCandidates(
    List<String> raws, {
    Map<String, dynamic>? baseParsed,
    List<String> anchors = const <String>[],
  }) {
    final candidates = <Map<String, dynamic>>[];
    if (baseParsed != null && baseParsed.isNotEmpty) {
      candidates.add(Map<String, dynamic>.from(baseParsed));
    }
    for (final raw in raws) {
      if (raw.trim().isEmpty) continue;
      final parsed = _extractLoopInsightPartialFields(raw);
      if (parsed.isNotEmpty) candidates.add(parsed);
    }
    if (candidates.isEmpty) return <String, dynamic>{};
    return _mergeLoopInsightCandidates(candidates, anchors: anchors);
  }

  Map<String, dynamic> _mergeLoopInsightCandidates(
    List<Map<String, dynamic>> candidates, {
    List<String> anchors = const <String>[],
  }) {
    if (candidates.isEmpty) return <String, dynamic>{};
    final merged = <String, dynamic>{};

    for (final key in <String>['evidence_basis', 'related_knowledge_concepts', 'retry_plan_steps']) {
      List<String> best = const <String>[];
      var bestScore = -1;
      for (final candidate in candidates) {
        final list = _stringList(candidate[key]);
        if (list.isEmpty) continue;
        final score = _scoreLoopListField(list, anchors: anchors, key: key);
        if (score > bestScore) {
          best = list;
          bestScore = score;
        }
      }
      if (best.isNotEmpty) merged[key] = best;
    }

    for (final key in <String>[
      'experience_recap',
      'result_judgement',
      'result_reason_analysis',
      'strengths_found',
      'weaknesses_or_blindspots',
      'pattern_induction',
      'theory_elevation',
      'course_connection',
      'retrospective_guidance',
      'retry_plan_title',
      'retry_visual_plan',
      'closure_summary',
    ]) {
      var best = '';
      var bestScore = -1;
      for (final candidate in candidates) {
        final value = ('${candidate[key] ?? ''}').trim();
        if (value.isEmpty) continue;
        final score = _scoreLoopTextField(value, anchors: anchors, key: key);
        if (score > bestScore) {
          best = value;
          bestScore = score;
        }
      }
      if (best.isNotEmpty) merged[key] = best;
    }

    for (final key in <String>[
      'result_final_judgement',
      'failure_analysis',
      'strengths_and_blindspots',
      'comparative_judgement',
      'related_theories',
      'psychology_analysis',
      'philosophy_analysis',
      'similar_historical_figure',
      'next_iteration_guidance',
      'famous_figure_matching',
      'subconscious_analysis',
    ]) {
      dynamic best;
      var bestScore = -1;
      for (final candidate in candidates) {
        final value = candidate[key];
        if (!_hasMeaningfulExtraSectionValue(value)) continue;
        final score = _scoreLoopStructuredField(value, anchors: anchors, key: key);
        if (score > bestScore) {
          best = _sanitizeLoopJsonValue(value);
          bestScore = score;
        }
      }
      if (_hasMeaningfulExtraSectionValue(best)) {
        merged[key] = best;
      }
    }

    final mergedExtra = <String, dynamic>{};
    for (final candidate in candidates) {
      final extra = _normalizeExtraSections(candidate['extra_sections']);
      extra.forEach((key, value) {
        if (_hasMeaningfulExtraSectionValue(value)) {
          final existing = mergedExtra[key];
          final newScore = _scoreLoopStructuredField(value, anchors: anchors, key: key);
          final oldScore = _scoreLoopStructuredField(existing, anchors: anchors, key: key);
          if (newScore >= oldScore) {
            mergedExtra[key] = _sanitizeLoopJsonValue(value);
          }
        }
      });
    }
    for (final key in <String>['famous_figure_matching', 'subconscious_analysis']) {
      if (_hasMeaningfulExtraSectionValue(merged[key]) && !_hasMeaningfulExtraSectionValue(mergedExtra[key])) {
        mergedExtra[key] = merged[key];
      }
    }
    if (mergedExtra.isNotEmpty) {
      merged['extra_sections'] = mergedExtra;
    }

    return merged;
  }

  int _scoreLoopStructuredField(dynamic value, {List<String> anchors = const <String>[], String key = ''}) {
    if (!_hasMeaningfulExtraSectionValue(value)) return -1;
    String flat;
    try {
      flat = jsonEncode(value);
    } catch (_) {
      flat = '$value';
    }
    flat = _cleanLoopText(flat);
    var score = flat.runes.length;
    final anchorHits = _countAnchorHits(flat, anchors);
    score += anchorHits * 80;
    if (value is List) score += value.length * 30;
    if (value is Map) score += value.length * 20;
    if (key == 'related_theories' && value is List) score += value.length * 40;
    if (key == 'psychology_analysis' && value is Map) score += 120;
    if (key == 'comparative_judgement' && value is Map) score += 100;
    if (key == 'strengths_and_blindspots' && value is Map) score += 80;
    if (key == 'next_iteration_guidance' && value is Map) score += 120;
    return score;
  }

  int _scoreLoopListField(List<String> items, {List<String> anchors = const <String>[], String key = ''}) {
    final text = items.join('\n');
    var score = text.runes.length + (items.length * 40);
    final anchorHits = _countAnchorHits(text, anchors);
    score += anchorHits * 60;
    if (key == 'evidence_basis' && items.length >= 2) score += 120;
    if (key == 'retry_plan_steps' && items.length >= 3) score += 90;
    if (key == 'related_knowledge_concepts' && items.length >= 2) score += 80;
    return score;
  }

  int _scoreLoopTextField(String value, {List<String> anchors = const <String>[], String key = ''}) {
    final text = value.trim();
    if (text.isEmpty) return -1;
    var score = text.runes.length;
    final anchorHits = _countAnchorHits(text, anchors);
    score += anchorHits * 80;

    final genericPhrases = <String>[
      '不是单纯意志不足',
      '触发场景不够清楚',
      '第一步过大',
      '形成闭环',
      '抽象动机',
      '留痕',
      '最先失效的一环',
    ];
    final genericHits = genericPhrases.where((phrase) => text.contains(phrase)).length;
    if (genericHits > 0 && anchorHits == 0) {
      score -= genericHits * 45;
    }
    if (_containsGenericLoopPlaceholder(text) && anchorHits == 0) {
      score -= 220;
    }

    if (key == 'result_judgement') {
      final hasOutcomeWord = <String>['成功', '失败', '部分成功', 'partial', 'success', 'fail'].any((e) => text.toLowerCase().contains(e.toLowerCase()));
      if (hasOutcomeWord) score += 60;
    }
    if (key == 'retry_plan_title' && text.runes.length >= 6) score += 20;
    if (key == 'retry_visual_plan' && text.runes.length >= 16) score += 30;
    return score;
  }

  Map<String, dynamic> _mergeLoopInsightParsed(Map<String, dynamic> primary, Map<String, dynamic> secondary) {
    if (secondary.isEmpty) return Map<String, dynamic>.from(primary);
    final merged = <String, dynamic>{...secondary, ...primary};
    for (final key in <String>['evidence_basis', 'related_knowledge_concepts', 'retry_plan_steps']) {
      final primaryList = _stringList(primary[key]);
      if (primaryList.isNotEmpty) {
        merged[key] = primaryList;
        continue;
      }
      final secondaryList = _stringList(secondary[key]);
      if (secondaryList.isNotEmpty) merged[key] = secondaryList;
    }
    for (final key in <String>[
      'experience_recap',
      'result_judgement',
      'result_reason_analysis',
      'strengths_found',
      'weaknesses_or_blindspots',
      'pattern_induction',
      'theory_elevation',
      'course_connection',
      'retrospective_guidance',
      'retry_plan_title',
      'retry_visual_plan',
      'closure_summary',
    ]) {
      final primaryValue = ('${primary[key] ?? ''}').trim();
      if (primaryValue.isNotEmpty) {
        merged[key] = primaryValue;
        continue;
      }
      final secondaryValue = ('${secondary[key] ?? ''}').trim();
      if (secondaryValue.isNotEmpty) merged[key] = secondaryValue;
    }
    return merged;
  }

  bool _isRecoverablePartialLoopInsight(Map<String, dynamic> parsed) {
    final filledCount = _countRecoveredLoopInsightFields(parsed);
    final coreOk = _stringList(parsed['evidence_basis']).length >= 2 &&
        ('${parsed['experience_recap'] ?? ''}').trim().isNotEmpty &&
        ('${parsed['result_reason_analysis'] ?? ''}').trim().isNotEmpty;
    return filledCount >= 6 || coreOk;
  }

  int _countRecoveredLoopInsightFields(Map<String, dynamic> parsed) {
    var count = 0;
    if (_stringList(parsed['evidence_basis']).isNotEmpty) count += 1;
    if (_stringList(parsed['related_knowledge_concepts']).isNotEmpty) count += 1;
    if (_stringList(parsed['retry_plan_steps']).isNotEmpty) count += 1;
    for (final key in <String>[
      'experience_recap',
      'result_judgement',
      'result_reason_analysis',
      'strengths_found',
      'weaknesses_or_blindspots',
      'pattern_induction',
      'theory_elevation',
      'course_connection',
      'retrospective_guidance',
      'retry_plan_title',
      'retry_visual_plan',
      'closure_summary',
    ]) {
      if (('${parsed[key] ?? ''}').trim().isNotEmpty) count += 1;
    }
    for (final key in <String>[
      'result_final_judgement',
      'failure_analysis',
      'strengths_and_blindspots',
      'comparative_judgement',
      'related_theories',
      'psychology_analysis',
      'philosophy_analysis',
      'similar_historical_figure',
      'next_iteration_guidance',
      'famous_figure_matching',
      'subconscious_analysis',
    ]) {
      if (_hasMeaningfulExtraSectionValue(parsed[key])) count += 1;
    }
    final extra = _normalizeExtraSections(parsed['extra_sections']);
    if (extra.isNotEmpty) count += extra.length;
    return count;
  }

  Map<String, dynamic> _extractLoopInsightPartialFields(String raw) {
    final text = _extractText(raw).trim();
    if (text.isEmpty) return <String, dynamic>{};
    final result = <String, dynamic>{};

    List<String> extractList(String key) {
      final match = RegExp('"$key"\\s*:\\s*(\\[[\\s\\S]*?\\])', multiLine: true).firstMatch(text);
      if (match == null) return const <String>[];
      final block = match.group(1)?.trim() ?? '';
      if (block.isEmpty) return const <String>[];
      try {
        final decoded = jsonDecode(block);
        if (decoded is List) {
          return decoded.map((e) => _cleanLoopText('$e')).where((e) => e.trim().isNotEmpty).toList();
        }
      } catch (_) {}
      return const <String>[];
    }

    String extractString(String key) {
      final match = RegExp('"$key"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"', multiLine: true).firstMatch(text);
      final value = match?.group(1);
      if (value == null) return '';
      try {
        return _cleanLoopText(jsonDecode('"' + value + '"').toString());
      } catch (_) {
        return _cleanLoopText(value.replaceAll(r'\\n', '\n').replaceAll(r'\\"', '"'));
      }
    }

    for (final key in <String>[
      'result_final_judgement',
      'failure_analysis',
      'strengths_and_blindspots',
      'comparative_judgement',
      'related_theories',
      'psychology_analysis',
      'philosophy_analysis',
      'similar_historical_figure',
      'next_iteration_guidance',
    ]) {
      final structured = _extractNamedJsonValueFromText(text, key);
      if (_hasMeaningfulExtraSectionValue(structured)) {
        result[key] = structured;
      }
    }

    final famous = _extractLoopExtraSectionFromRawResponse(text, 'famous_figure_matching');
    if (_hasMeaningfulExtraSectionValue(famous)) {
      result['famous_figure_matching'] = famous;
    }
    final subconscious = _extractLoopExtraSectionFromRawResponse(text, 'subconscious_analysis');
    if (_hasMeaningfulExtraSectionValue(subconscious)) {
      result['subconscious_analysis'] = subconscious;
    }

    final evidenceBasis = extractList('evidence_basis');
    if (evidenceBasis.isNotEmpty) result['evidence_basis'] = evidenceBasis;
    final relatedKnowledgeConcepts = extractList('related_knowledge_concepts');
    if (relatedKnowledgeConcepts.isNotEmpty) result['related_knowledge_concepts'] = relatedKnowledgeConcepts;
    final retryPlanSteps = extractList('retry_plan_steps');
    if (retryPlanSteps.isNotEmpty) result['retry_plan_steps'] = retryPlanSteps;

    for (final key in <String>[
      'experience_recap',
      'result_judgement',
      'result_reason_analysis',
      'strengths_found',
      'weaknesses_or_blindspots',
      'pattern_induction',
      'theory_elevation',
      'course_connection',
      'retrospective_guidance',
      'retry_plan_title',
      'retry_visual_plan',
      'closure_summary',
    ]) {
      final value = extractString(key);
      if (value.isNotEmpty) result[key] = value;
    }

    final label = extractString('label');
    final confidence = extractString('confidence');
    final summary = extractString('summary');
    if ((result['result_judgement'] ?? '').toString().trim().isEmpty) {
      final parts = <String>[
        if (label.isNotEmpty) label,
        if (confidence.isNotEmpty) '置信度：$confidence',
        if (summary.isNotEmpty) summary,
      ];
      if (parts.isNotEmpty) result['result_judgement'] = parts.join('｜');
    }

    final coreFailurePoint = extractString('core_failure_point');
    final deepAnalysis = extractString('deep_analysis');
    final changeSuggestions = extractList('change_suggestions');
    if ((result['result_reason_analysis'] ?? '').toString().trim().isEmpty) {
      final parts = <String>[];
      if (coreFailurePoint.isNotEmpty) parts.add('核心断点：$coreFailurePoint');
      if (deepAnalysis.isNotEmpty) parts.add(deepAnalysis);
      if (changeSuggestions.isNotEmpty) {
        parts.add('改变建议：\n${changeSuggestions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}');
      }
      if (parts.isNotEmpty) result['result_reason_analysis'] = parts.join('\n\n');
    }

    final reviewGuidance = extractString('review_guidance');
    if ((result['retrospective_guidance'] ?? '').toString().trim().isEmpty && reviewGuidance.isNotEmpty) {
      result['retrospective_guidance'] = reviewGuidance;
    }
    final planTitle = extractString('plan_title');
    if ((result['retry_plan_title'] ?? '').toString().trim().isEmpty && planTitle.isNotEmpty) {
      result['retry_plan_title'] = planTitle;
    }
    final visualScript = extractString('visual_script');
    final completionCriteria = extractString('completion_criteria');
    final fallbackOption = extractString('fallback_option');
    if ((result['retry_visual_plan'] ?? '').toString().trim().isEmpty) {
      final visualLines = <String>[];
      if (visualScript.isNotEmpty) visualLines.add(visualScript);
      if (completionCriteria.isNotEmpty) visualLines.add('完成标准：$completionCriteria');
      if (fallbackOption.isNotEmpty) visualLines.add('遇阻替代：$fallbackOption');
      if (visualLines.isNotEmpty) result['retry_visual_plan'] = visualLines.join('\n');
    }
    final nestedSteps = extractList('steps');
    if (_stringList(result['retry_plan_steps']).isEmpty && nestedSteps.isNotEmpty) {
      result['retry_plan_steps'] = nestedSteps;
    }

    if ((result['closure_summary'] ?? '').toString().trim().isEmpty && summary.isNotEmpty) {
      result['closure_summary'] = summary;
    }
    return result;
  }

  Map<String, dynamic> _buildRelaxedLoopInsightPayload(
    Map<String, dynamic> parsed, {
    required String raw,
    List<String> anchors = const <String>[],
  }) {
    final merged = Map<String, dynamic>.from(parsed);
    final hadStructuredInput = merged.isNotEmpty;
    final text = _extractText(raw).trim();

    String firstNonEmpty(Iterable<String> values) {
      for (final value in values) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return '';
    }

    if (!hadStructuredInput && text.isNotEmpty) {
      if (_looksLikeStructuredJsonBlob(text)) {
        merged['extra_sections'] = <String, dynamic>{
          'AI 原始返回（宽松展示）': text,
        };
        return merged;
      }
      merged['experience_recap'] = text;
      merged['closure_summary'] = text;
      merged['extra_sections'] = <String, dynamic>{
        'AI 原始返回（宽松展示）': text,
      };
      return merged;
    }

    final summaryCandidate = firstNonEmpty(<String>[
      '${merged['closure_summary'] ?? ''}',
      '${merged['result_judgement'] ?? ''}',
      '${merged['result_reason_analysis'] ?? ''}',
      '${merged['experience_recap'] ?? ''}',
      text,
    ]);
    if (summaryCandidate.isNotEmpty && !_looksLikeStructuredJsonBlob(summaryCandidate)) {
      merged['closure_summary'] = summaryCandidate;
    }

    if (text.isNotEmpty) {
      final extra = Map<String, dynamic>.from(_normalizeExtraSections(merged['extra_sections']));
      final hasStructuredContent = _countRecoveredLoopInsightFields(merged) > 0;
      if (!hasStructuredContent) {
        extra['AI 原始返回（宽松展示）'] = text;
      } else if (extra.isEmpty && _countAnchorHits(text, anchors) > 0 && text.runes.length <= 1200) {
        extra['AI 原始补充文本'] = text;
      }
      if (extra.isNotEmpty) {
        merged['extra_sections'] = extra;
      }
    }

    return merged;
  }

  bool _hasAnyLoopInsightContent(Map<String, dynamic> parsed) {
    if (parsed.isEmpty) return false;
    if (_stringList(parsed['evidence_basis']).isNotEmpty) return true;
    if (_stringList(parsed['related_knowledge_concepts']).isNotEmpty) return true;
    if (_stringList(parsed['retry_plan_steps']).isNotEmpty) return true;
    for (final key in <String>[
      'experience_recap',
      'result_judgement',
      'result_reason_analysis',
      'strengths_found',
      'weaknesses_or_blindspots',
      'pattern_induction',
      'theory_elevation',
      'course_connection',
      'retrospective_guidance',
      'retry_plan_title',
      'retry_visual_plan',
      'closure_summary',
    ]) {
      if (('${parsed[key] ?? ''}').trim().isNotEmpty) return true;
    }
    for (final key in <String>[
      'result_final_judgement',
      'failure_analysis',
      'strengths_and_blindspots',
      'comparative_judgement',
      'related_theories',
      'psychology_analysis',
      'philosophy_analysis',
      'similar_historical_figure',
      'next_iteration_guidance',
      'famous_figure_matching',
      'subconscious_analysis',
    ]) {
      if (_hasMeaningfulExtraSectionValue(parsed[key])) return true;
    }
    final extra = _normalizeExtraSections(parsed['extra_sections']);
    if (extra.isNotEmpty) return true;
    return false;
  }

  bool _looksLikeLoopErrorResponse(String raw) {
    final text = _extractText(raw).trim().toLowerCase();
    if (text.isEmpty) return true;
    const hardSignals = <String>[
      '"error"',
      'request failed',
      'api error',
      'invalid api key',
      'authentication failed',
      'rate limit',
      'context length',
      'timeout',
      'timed out',
      'network error',
      'service unavailable',
      'bad gateway',
      '网络错误',
      '请求失败',
      '调用失败',
      '认证失败',
      '超时',
      '限流',
      '余额不足',
      '无权限',
    ];
    for (final signal in hardSignals) {
      if (text.contains(signal)) return true;
    }
    return false;
  }

  String _extractFinishReason(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map && data['choices'] is List && (data['choices'] as List).isNotEmpty) {
        final first = (data['choices'] as List).first;
        if (first is Map && first['finish_reason'] != null) return first['finish_reason'].toString();
      }
    } catch (_) {}
    return '';
  }

  bool _shouldRetryDeepSeekResponse(String raw, String purpose) {
    if (!_expectsJsonResponse(purpose)) return false;
    final finishReason = _extractFinishReason(raw).trim().toLowerCase();
    if (finishReason == 'length') return true;
    final text = _extractText(raw).trim();
    if (text.isEmpty) return false;
    if (finishReason.isNotEmpty && finishReason != 'stop' && _extractJsonObject(text).isEmpty) return true;
    return false;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => _cleanLoopText('$e')).where((e) => e.trim().isNotEmpty).toList();
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.map((e) => _cleanLoopText('$e')).where((e) => e.trim().isNotEmpty).toList();
      } catch (_) {}
    }
    return <String>[];
  }
}
