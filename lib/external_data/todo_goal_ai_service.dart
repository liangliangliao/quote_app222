import 'dart:convert';

import '../services/global_ai_settings.dart';
import '../services/unified_ai_service.dart';
import 'todo_goal_models.dart';
import 'todo_goal_prompt_config.dart';
import 'todo_models.dart';

class TodoGoalAiService {
  final GlobalAiSettings _settings = GlobalAiSettings();
  final UnifiedAiService _ai = UnifiedAiService();
  final TodoGoalPromptConfig _promptConfig = TodoGoalPromptConfig();

  Future<Map<String, String>> getGlobalAiState() => _settings.getState();

  Future<TodoGoalAnalysisResult> analyzeTaskAsGoal(TodoTaskRecord task) async {
    final state = await getGlobalAiState();
    final fallback = _fallbackAnalysis(task, provider: 'local', modelLabel: state['label'] ?? '本地策略');
    if (state['available'] != '1') return fallback;
    final templates = await _promptConfig.load();
    final prompt = _promptConfig.renderTaskPrompt(
      templates,
      taskTitle: task.title,
      taskBody: task.bodyText,
      taskList: task.listDisplayName.trim().isEmpty ? task.listId : task.listDisplayName,
      taskImportance: task.importance,
      taskDue: task.dueDateTime,
      taskStatus: task.status,
    );
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'microsoft_todo.goal_analysis',
        systemPrompt: templates.systemPrompt,
        maxTokens: 3800,
        expectJson: true,
        temperature: 0.35,
      );
      if (raw.trim().isEmpty) return fallback;
      final parsedRoot = _extractJsonObject(raw);
      if (parsedRoot.isEmpty) {
        return _analysisFromAiRaw(task, raw, state, fallback);
      }
      final parsed = _resolveAnalysisPayload(parsedRoot);
      if (parsed.isEmpty) {
        return _analysisFromAiRaw(task, raw, state, fallback);
      }
      final aiHasMeaningfulContent = _hasMeaningfulAnalysis(parsed);
      if (!aiHasMeaningfulContent) {
        return _analysisFromAiRaw(task, raw, state, fallback);
      }

      final aiDefaults = _analysisFromAiRaw(task, raw, state, fallback, markRawOnly: false);
      final goalTitle = _read(parsed, 'goalTitle', aiDefaults.goalTitle);
      final todayMinimumAction = _read(parsed, 'todayMinimumAction', aiDefaults.todayMinimumAction);
      return TodoGoalAnalysisResult(
        goalTitle: goalTitle,
        deepMeaning: _read(parsed, 'deepMeaning', aiDefaults.deepMeaning),
        desiredIdentity: _read(parsed, 'desiredIdentity', aiDefaults.desiredIdentity),
        goalCategory: _read(parsed, 'goalCategory', aiDefaults.goalCategory),
        goalOriginType: _read(parsed, 'goalOriginType', aiDefaults.goalOriginType),
        selfConcordanceScore: _readInt(parsed, 'selfConcordanceScore', aiDefaults.selfConcordanceScore).clamp(0, 100).toInt(),
        processValue: _read(parsed, 'processValue', aiDefaults.processValue),
        obstacleSummary: _read(parsed, 'obstacleSummary', aiDefaults.obstacleSummary),
        todayMinimumAction: todayMinimumAction,
        minimumStandard: _read(parsed, 'minimumStandard', aiDefaults.minimumStandard),
        simplifiedStandard: _read(parsed, 'simplifiedStandard', aiDefaults.simplifiedStandard),
        recommendedStandard: _read(parsed, 'recommendedStandard', aiDefaults.recommendedStandard),
        stretchStandard: _read(parsed, 'stretchStandard', aiDefaults.stretchStandard),
        difficultyScore: _readInt(parsed, 'difficultyScore', aiDefaults.difficultyScore).clamp(1, 10).toInt(),
        zoneType: _normalizeZone(_read(parsed, 'zoneType', aiDefaults.zoneType)),
        coachMessage: _read(parsed, 'coachMessage', aiDefaults.coachMessage),
        resultGoal: _read(parsed, 'resultGoal', aiDefaults.resultGoal),
        valueGoal: _read(parsed, 'valueGoal', aiDefaults.valueGoal),
        processGoal: _read(parsed, 'processGoal', aiDefaults.processGoal),
        coreValues: _read(parsed, 'coreValues', aiDefaults.coreValues),
        autonomyScore: _readInt(parsed, 'autonomyScore', aiDefaults.autonomyScore).clamp(0, 100).toInt(),
        valueAlignmentScore: _readInt(parsed, 'valueAlignmentScore', aiDefaults.valueAlignmentScore).clamp(0, 100).toInt(),
        interestConnectionScore: _readInt(parsed, 'interestConnectionScore', aiDefaults.interestConnectionScore).clamp(0, 100).toInt(),
        passionScore: _readInt(parsed, 'passionScore', aiDefaults.passionScore).clamp(0, 100).toInt(),
        feasibilityScore: _readInt(parsed, 'feasibilityScore', aiDefaults.feasibilityScore).clamp(0, 100).toInt(),
        externalPressureScore: _readInt(parsed, 'externalPressureScore', aiDefaults.externalPressureScore).clamp(0, 100).toInt(),
        processHappinessScore: _readInt(parsed, 'processHappinessScore', aiDefaults.processHappinessScore).clamp(0, 100).toInt(),
        goalType: _read(parsed, 'goalType', aiDefaults.goalType),
        currentStage: _read(parsed, 'currentStage', aiDefaults.currentStage),
        actionPlace: _read(parsed, 'actionPlace', aiDefaults.actionPlace),
        startTrigger: _read(parsed, 'startTrigger', aiDefaults.startTrigger),
        completionQuestion: _read(parsed, 'completionQuestion', aiDefaults.completionQuestion),
        processAction: _read(parsed, 'processAction', aiDefaults.processAction),
        valueAction: _read(parsed, 'valueAction', aiDefaults.valueAction),
        experiencePrompt: _read(parsed, 'experiencePrompt', aiDefaults.experiencePrompt),
        userNeedInterpretation: _read(parsed, 'userNeedInterpretation', aiDefaults.userNeedInterpretation),
        keyUncertainties: _read(parsed, 'keyUncertainties', aiDefaults.keyUncertainties),
        clarifyingQuestions: _read(parsed, 'clarifyingQuestions', aiDefaults.clarifyingQuestions),
        possibleDirections: _read(parsed, 'possibleDirections', aiDefaults.possibleDirections),
        referenceCases: _read(parsed, 'referenceCases', aiDefaults.referenceCases),
        recommendationRationale: _read(parsed, 'recommendationRationale', aiDefaults.recommendationRationale),
        userDecisionPrompt: _read(parsed, 'userDecisionPrompt', aiDefaults.userDecisionPrompt),
        provider: state['provider'] ?? 'ai',
        solutionPlans: const <TodoGoalSolutionPlan>[],
        modelLabel: state['label'] ?? 'AI',
        rawResponse: raw,
        usedFallback: false,
      );
    } catch (_) {
      return fallback;
    }
  }

  Future<TodoGoalSolutionGenerationResult> generateProblemSolutions({
    required TodoTaskRecord task,
    required TodoGoalAnalysisResult analysis,
  }) async {
    final state = await getGlobalAiState();
    final fallbackPlans = _fallbackPlans(analysis.goalTitle, analysis.todayMinimumAction);
    TodoGoalSolutionGenerationResult fallback() => TodoGoalSolutionGenerationResult(
          plans: fallbackPlans,
          provider: 'local',
          modelLabel: state['label'] ?? '本地策略',
          usedFallback: true,
        );
    if (state['available'] != '1') return fallback();

    final templates = await _promptConfig.load();
    final prompt = _promptConfig.renderSolutionPrompt(
      templates,
      goalTitle: analysis.goalTitle,
      resultGoal: analysis.resultGoal,
      valueGoal: analysis.valueGoal,
      processGoal: analysis.processGoal,
      coreValues: analysis.coreValues,
      obstacleSummary: analysis.obstacleSummary,
      todayAction: analysis.todayMinimumAction,
      taskBody: task.bodyText,
    );
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'microsoft_todo.goal_problem_solutions',
        systemPrompt: '你是严谨、务实、客观的科学问题解决分析器。区分事实、推断、假设和未知；使用根因分析、方案比较和验证实验；不得替用户做最终选择。只输出合法JSON。',
        maxTokens: 6500,
        expectJson: true,
        temperature: 0.35,
      );
      if (raw.trim().isEmpty) return fallback();
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) return fallback();
      var plans = _readPlans(parsed);
      if (plans.isEmpty) plans = _readPlans(_resolveAnalysisPayload(parsed));
      if (plans.isEmpty) return fallback();
      return TodoGoalSolutionGenerationResult(
        plans: plans,
        provider: state['provider'] ?? 'ai',
        modelLabel: state['label'] ?? 'AI',
        rawResponse: raw,
      );
    } catch (_) {
      return fallback();
    }
  }

  Future<TodoGoalWeeklySummaryResult> generateWeeklySummary({
    required List<TodoGoalProfile> goals,
    required List<TodoGoalReflection> reflections,
  }) async {
    final state = await getGlobalAiState();
    TodoGoalWeeklySummaryResult fallback() => TodoGoalWeeklySummaryResult(
          alignmentInsight: goals.isEmpty ? '本周还没有可分析的目标。' : '本周共有 ${goals.length} 个目标，其中 ${goals.where((goal) => goal.selfConcordanceScore >= 70).length} 个自我一致度较高。',
          processInsight: reflections.isEmpty ? '还没有过程复盘证据。' : '本周留下了 ${reflections.length} 条过程复盘，这些记录比单纯完成率更能说明真实成长。',
          valueEvidence: goals.expand((goal) => goal.coreValueList).take(5).join('、'),
          adjustmentAdvice: goals.any((goal) => goal.externalPressureScore >= 70) ? '优先调整外部压力过高的目标：缩短承诺周期、降低强度或重新绑定价值。' : '保持能带来意义感和投入感的行动方式。',
          nextWeekFocus: '选择一个最自我一致的目标，每天只保留一个可以开始的最低行动。',
          provider: 'local',
          modelLabel: state['label'] ?? '本地策略',
          usedFallback: true,
        );
    if (state['available'] != '1') return fallback();
    final goalText = goals.take(12).map((goal) => '- ${goal.goalTitle}｜自我一致${goal.selfConcordanceScore}｜外部压力${goal.externalPressureScore}｜过程幸福${goal.processHappinessScore}｜价值${goal.coreValues}').join('\n');
    final reflectionText = reflections.take(20).map((reflection) => '- ${reflection.reflectionDate} ${reflection.goalTitle}｜意义${reflection.meaningScore}/5｜过程${reflection.processScore}/5｜${reflection.processExperience}').join('\n');
    final prompt = '''
你是促进用户自主判断的积极心理学目标教练。请生成“过程与自我一致”周总结，不以完成率羞辱用户，也不替用户决定下周目标。区分记录事实、你的推断和待用户确认的问题；调整建议至少给出多种可能性及适用条件。
目标：
$goalText
本周复盘：
$reflectionText
只输出JSON：
{"alignmentInsight":"哪些目标更自我一致","processInsight":"哪些行动带来过程幸福","valueEvidence":"本周体现了哪些价值","adjustmentAdvice":"哪些目标需暂停、降强度或重写","nextWeekFocus":"下周一个温和具体的重点"}
''';
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'microsoft_todo.goal_weekly_summary',
        systemPrompt: '你是温和、具体、反对完成率崇拜并尊重用户自主选择的积极心理学目标教练。不得把建议写成唯一答案。只输出合法JSON。',
        maxTokens: 1200,
        expectJson: true,
        temperature: 0.4,
      );
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) return fallback();
      final local = fallback();
      return TodoGoalWeeklySummaryResult(
        alignmentInsight: _read(parsed, 'alignmentInsight', local.alignmentInsight),
        processInsight: _read(parsed, 'processInsight', local.processInsight),
        valueEvidence: _read(parsed, 'valueEvidence', local.valueEvidence),
        adjustmentAdvice: _read(parsed, 'adjustmentAdvice', local.adjustmentAdvice),
        nextWeekFocus: _read(parsed, 'nextWeekFocus', local.nextWeekFocus),
        provider: state['provider'] ?? 'ai',
        modelLabel: state['label'] ?? 'AI',
      );
    } catch (_) {
      return fallback();
    }
  }

  Future<TodoGoalReviewResult> generateDailyReview({
    required String goalTitle,
    required String deepMeaning,
    required String processValue,
    required String actionTitle,
    required bool completed,
    required String userReflection,
  }) async {
    final state = await getGlobalAiState();
    final fallback = _fallbackReview(
      goalTitle: goalTitle,
      deepMeaning: deepMeaning,
      actionTitle: actionTitle,
      completed: completed,
      userReflection: userReflection,
      provider: 'local',
      modelLabel: state['label'] ?? '本地策略',
    );
    if (state['available'] != '1') return fallback;
    final templates = await _promptConfig.load();
    final prompt = _promptConfig.renderReviewPrompt(
      templates,
      goalTitle: goalTitle,
      deepMeaning: deepMeaning,
      processValue: processValue,
      actionTitle: actionTitle,
      completed: completed,
      userReflection: userReflection,
    );
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'microsoft_todo.goal_review',
        systemPrompt: templates.systemPrompt,
        maxTokens: 1400,
        expectJson: true,
        temperature: 0.45,
      );
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) return fallback;
      return TodoGoalReviewResult(
        summary: _read(parsed, 'summary', fallback.summary),
        processInsight: _read(parsed, 'processInsight', fallback.processInsight),
        meaningConnection: _read(parsed, 'meaningConnection', fallback.meaningConnection),
        tomorrowNextStep: _read(parsed, 'tomorrowNextStep', fallback.tomorrowNextStep),
        encouragement: _read(parsed, 'encouragement', fallback.encouragement),
        nextStepOptions: _read(parsed, 'nextStepOptions', fallback.nextStepOptions),
        decisionPrompt: _read(parsed, 'decisionPrompt', fallback.decisionPrompt),
        provider: state['provider'] ?? 'ai',
        modelLabel: state['label'] ?? 'AI',
        rawResponse: raw,
      );
    } catch (_) {
      return fallback;
    }
  }

  Future<TodoGoalStepRecoveryResult> generateStepRecovery({
    required String goalTitle,
    required String deepMeaning,
    required String processValue,
    required String actionTitle,
    required String minimumStandard,
    required String userResult,
    required String userReflection,
    required String obstacle,
  }) async {
    final state = await getGlobalAiState();
    final fallback = _fallbackRecovery(
      goalTitle: goalTitle,
      actionTitle: actionTitle,
      userResult: userResult,
      userReflection: userReflection,
      obstacle: obstacle,
      provider: 'local',
      modelLabel: state['label'] ?? '本地策略',
    );
    if (state['available'] != '1') return fallback;
    final prompt = '''
你是“目标问题解决系统”的AI复盘教练。请把用户对某个节点/步骤的结果当作问题解决反馈，而不是道德评价。

目标：$goalTitle
深层意义：$deepMeaning
过程价值：$processValue
当前步骤：$actionTitle
最低标准：$minimumStandard
用户选择结果：$userResult
用户过程记录：${userReflection.trim().isEmpty ? '未填写' : userReflection.trim()}
用户阻力描述：${obstacle.trim().isEmpty ? '未填写' : obstacle.trim()}

请根据科学问题解决原则输出：
1. 先列出已观察事实，再区分可能原因与待验证假设；成功时提炼可复用条件，失败时指出问题发生在哪个更小环节。
2. 如何重启当前子问题，优先缩小、换路径、换环境、降低阻力，而不是立刻推翻整套方案。
3. 给出3个机制不同的替代步骤，说明各自适用条件、代价和风险，不能替用户选择；必须符合目标价值体系：目标服务当下、过程重于抵达、自我和谐、拉伸而非恐慌。
4. 给出验证关键假设的低成本实验和判断规则。只有证据显示原方案方向错误时才提醒重构；最终由用户选择继续、换路或暂停。

只输出JSON：
{
  "failureDiagnosis": "对成功/失败原因的结构化分析；成功时提炼可复用条件，失败时指出卡在哪个子问题或触发环节",
  "restartGuidance": "重启当前子问题的具体指导，必须可照做",
  "principleFit": "说明为什么这些调整仍然符合整个目标原则和价值体系",
  "alternatives": [
    {"title": "替代步骤1", "rationale": "为什么更适合", "minimumStandard": "最低标准", "recommendedStandard": "推荐标准", "zoneType": "comfort/stretch/panic", "difficultyScore": 1},
    {"title": "替代步骤2", "rationale": "为什么更适合", "minimumStandard": "最低标准", "recommendedStandard": "推荐标准", "zoneType": "comfort/stretch/panic", "difficultyScore": 1},
    {"title": "替代步骤3", "rationale": "为什么更适合", "minimumStandard": "最低标准", "recommendedStandard": "推荐标准", "zoneType": "comfort/stretch/panic", "difficultyScore": 1}
  ],
  "restructureWarning": "是否需要重构全方案。默认写：暂不建议重构，先用替代步骤验证。"
}
''';
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'microsoft_todo.goal_step_recovery',
        systemPrompt: '你是严谨、温和、重视现实落地的积极心理学问题解决教练。只输出合法JSON。',
        maxTokens: 2200,
        expectJson: true,
        temperature: 0.4,
      );
      final parsed = _extractJsonObject(raw);
      if (parsed.isEmpty) return fallback;
      final alternatives = _readAlternativeSteps(parsed);
      return TodoGoalStepRecoveryResult(
        failureDiagnosis: _read(parsed, 'failureDiagnosis', fallback.failureDiagnosis),
        restartGuidance: _read(parsed, 'restartGuidance', fallback.restartGuidance),
        principleFit: _read(parsed, 'principleFit', fallback.principleFit),
        alternatives: alternatives.isEmpty ? fallback.alternatives : alternatives,
        restructureWarning: _read(parsed, 'restructureWarning', fallback.restructureWarning),
        provider: state['provider'] ?? 'ai',
        modelLabel: state['label'] ?? 'AI',
        rawResponse: raw,
      );
    } catch (_) {
      return fallback;
    }
  }

  TodoGoalAnalysisResult _analysisFromAiRaw(
    TodoTaskRecord task,
    String raw,
    Map<String, String> state,
    TodoGoalAnalysisResult fallback, {
    bool markRawOnly = true,
  }) {
    final title = task.title.trim().isEmpty ? fallback.goalTitle : task.title.trim();
    final rawExcerpt = _aiRawExcerpt(raw);
    final goalTitle = _readTextFieldFromRaw(raw, _fieldAliases('goalTitle'), title);
    final actionTitle = goalTitle.length > 18 ? '${goalTitle.substring(0, 18)}…' : goalTitle;
    final todayAction = _readTextFieldFromRaw(
      raw,
      _fieldAliases('todayMinimumAction'),
      '先围绕“$actionTitle”做一个 2-5 分钟内能开始的现实动作，并留下事实记录。',
    );
    final category = _inferGoalCategory(goalTitle, task.bodyText);
    return TodoGoalAnalysisResult(
      goalTitle: goalTitle,
      deepMeaning: _readTextFieldFromRaw(
        raw,
        _fieldAliases('deepMeaning'),
        markRawOnly
            ? 'AI 已返回分析内容，但当前返回格式没有被完整拆成 deepMeaning 字段。可先依据模型返回的核心内容推进：$rawExcerpt'
            : 'AI 已返回部分结构化内容，但未提供明确“深层意义”字段。先追问：这个目标今天通向哪种生活、能力或身份？',
      ),
      desiredIdentity: _readTextFieldFromRaw(raw, _fieldAliases('desiredIdentity'), '成为能把问题拆小、把目标落到现实行动中的人。'),
      goalCategory: _readTextFieldFromRaw(raw, _fieldAliases('goalCategory'), category),
      goalOriginType: _readTextFieldFromRaw(raw, _fieldAliases('goalOriginType'), '尚不确定'),
      selfConcordanceScore: _readIntFromRaw(raw, _fieldAliases('selfConcordanceScore'), fallback.selfConcordanceScore).clamp(0, 100).toInt(),
      processValue: _readTextFieldFromRaw(
        raw,
        _fieldAliases('processValue'),
        '今天先把推进过程当成一次现实练习：观察自己如何从问题进入行动，而不是只等待最终结果。',
      ),
      obstacleSummary: _readTextFieldFromRaw(
        raw,
        _fieldAliases('obstacleSummary'),
        '可能阻力是开始成本高、目标过大、紧张焦虑、信息不清或不知道第一步怎么落地。',
      ),
      todayMinimumAction: todayAction,
      minimumStandard: _readTextFieldFromRaw(raw, _fieldAliases('minimumStandard'), '只要开始 2 分钟，并留下一个事实记录即可。'),
      simplifiedStandard: _readTextFieldFromRaw(raw, _fieldAliases('simplifiedStandard'), '做5分钟，完成一个不要求完美的小片段。'),
      recommendedStandard: _readTextFieldFromRaw(raw, _fieldAliases('recommendedStandard'), '完成一个清晰小步骤，并记录过程、阻力和下一步。'),
      stretchStandard: _readTextFieldFromRaw(raw, _fieldAliases('stretchStandard'), '状态允许时连续推进 15-25 分钟，并拆出下一个子问题。'),
      difficultyScore: _readIntFromRaw(raw, _fieldAliases('difficultyScore'), 5).clamp(1, 10).toInt(),
      zoneType: _normalizeZone(_readTextFieldFromRaw(raw, _fieldAliases('zoneType'), 'stretch')),
      coachMessage: _readTextFieldFromRaw(
        raw,
        _fieldAliases('coachMessage'),
        '先不要追求一次解决全部问题。把目标拆成今天能开始的最小动作，做完后再根据反馈调整。',
      ),
      resultGoal: _readTextFieldFromRaw(raw, _fieldAliases('resultGoal'), goalTitle),
      valueGoal: _readTextFieldFromRaw(raw, _fieldAliases('valueGoal'), fallback.valueGoal.isEmpty ? fallback.deepMeaning : fallback.valueGoal),
      processGoal: _readTextFieldFromRaw(raw, _fieldAliases('processGoal'), fallback.processGoal.isEmpty ? fallback.processValue : fallback.processGoal),
      coreValues: _readTextFieldFromRaw(raw, _fieldAliases('coreValues'), fallback.coreValues),
      autonomyScore: _readIntFromRaw(raw, _fieldAliases('autonomyScore'), fallback.autonomyScore).clamp(0, 100).toInt(),
      valueAlignmentScore: _readIntFromRaw(raw, _fieldAliases('valueAlignmentScore'), fallback.valueAlignmentScore).clamp(0, 100).toInt(),
      interestConnectionScore: _readIntFromRaw(raw, _fieldAliases('interestConnectionScore'), fallback.interestConnectionScore).clamp(0, 100).toInt(),
      passionScore: _readIntFromRaw(raw, _fieldAliases('passionScore'), fallback.passionScore).clamp(0, 100).toInt(),
      feasibilityScore: _readIntFromRaw(raw, _fieldAliases('feasibilityScore'), fallback.feasibilityScore).clamp(0, 100).toInt(),
      externalPressureScore: _readIntFromRaw(raw, _fieldAliases('externalPressureScore'), fallback.externalPressureScore).clamp(0, 100).toInt(),
      processHappinessScore: _readIntFromRaw(raw, _fieldAliases('processHappinessScore'), fallback.processHappinessScore).clamp(0, 100).toInt(),
      goalType: _readTextFieldFromRaw(raw, _fieldAliases('goalType'), fallback.goalType),
      currentStage: _readTextFieldFromRaw(raw, _fieldAliases('currentStage'), fallback.currentStage),
      actionPlace: _readTextFieldFromRaw(raw, _fieldAliases('actionPlace'), fallback.actionPlace),
      startTrigger: _readTextFieldFromRaw(raw, _fieldAliases('startTrigger'), fallback.startTrigger),
      completionQuestion: _readTextFieldFromRaw(raw, _fieldAliases('completionQuestion'), fallback.completionQuestion),
      processAction: _readTextFieldFromRaw(raw, _fieldAliases('processAction'), fallback.processAction),
      valueAction: _readTextFieldFromRaw(raw, _fieldAliases('valueAction'), fallback.valueAction),
      experiencePrompt: _readTextFieldFromRaw(raw, _fieldAliases('experiencePrompt'), fallback.experiencePrompt),
      userNeedInterpretation: _readTextFieldFromRaw(raw, _fieldAliases('userNeedInterpretation'), fallback.userNeedInterpretation),
      keyUncertainties: _readTextFieldFromRaw(raw, _fieldAliases('keyUncertainties'), fallback.keyUncertainties),
      clarifyingQuestions: _readTextFieldFromRaw(raw, _fieldAliases('clarifyingQuestions'), fallback.clarifyingQuestions),
      possibleDirections: _readTextFieldFromRaw(raw, _fieldAliases('possibleDirections'), fallback.possibleDirections),
      referenceCases: _readTextFieldFromRaw(raw, _fieldAliases('referenceCases'), fallback.referenceCases),
      recommendationRationale: _readTextFieldFromRaw(raw, _fieldAliases('recommendationRationale'), fallback.recommendationRationale),
      userDecisionPrompt: _readTextFieldFromRaw(raw, _fieldAliases('userDecisionPrompt'), fallback.userDecisionPrompt),
      provider: state['provider'] ?? 'ai',
      solutionPlans: const <TodoGoalSolutionPlan>[],
      modelLabel: state['label'] ?? 'AI',
      rawResponse: raw,
      usedFallback: false,
    );
  }

  String _inferGoalCategory(String title, String body) {
    final lower = '$title $body'.toLowerCase();
    if (lower.contains('面试') || lower.contains('工作') || lower.contains('项目') || lower.contains('resume') || lower.contains('interview')) return '工作';
    if (lower.contains('英语') || lower.contains('学习') || lower.contains('考试') || lower.contains('study')) return '学习';
    if (lower.contains('运动') || lower.contains('减肥') || lower.contains('睡眠') || lower.contains('健康')) return '健康';
    if (lower.contains('钥匙') || lower.contains('房间') || lower.contains('开锁') || lower.contains('物业') || lower.contains('生活')) return '生活';
    return '成长';
  }

  String _aiRawExcerpt(String raw) {
    var text = raw
        .replaceAll(RegExp(r'^```json', multiLine: true), '')
        .replaceAll(RegExp(r'^```', multiLine: true), '')
        .replaceAll(RegExp(r'```$', multiLine: true), '')
        .replaceAll(RegExp(r'[{}\[\]"]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length > 260) text = '${text.substring(0, 260)}…';
    return text.isEmpty ? '模型已返回文本，但未能提取出明确字段。' : text;
  }

  String _readTextFieldFromRaw(String raw, List<String> aliases, String fallback) {
    final direct = _readTextFieldByRegex(raw, aliases);
    if (direct.trim().isNotEmpty) return direct.trim();
    final lines = raw.split(RegExp(r'\r?\n'));
    for (final rawLine in lines) {
      var line = rawLine
          .trim()
          .replaceFirst(RegExp(r'^[\-\*•\d\.、\)\s]+'), '')
          .replaceAll(RegExp(r'^["“”]+|["“”]+$'), '')
          .trim();
      if (line.isEmpty) continue;
      for (final alias in aliases) {
        final idx = line.indexOf(alias);
        if (idx < 0) continue;
        final tail = line.substring(idx + alias.length);
        final colon = tail.indexOf('：') >= 0 ? tail.indexOf('：') : tail.indexOf(':');
        if (colon < 0) continue;
        var value = tail.substring(colon + 1).trim();
        value = value
            .replaceAll(RegExp(r'^["“”]+|["“”,，]+$'), '')
            .replaceAll(RegExp(r',$'), '')
            .trim();
        if (value.isNotEmpty && value != 'null') {
          if (value.length > 520) value = '${value.substring(0, 520)}…';
          return value;
        }
      }
    }
    return fallback;
  }

  String _readTextFieldByRegex(String raw, List<String> aliases) {
    for (final alias in aliases) {
      final escaped = RegExp.escape(alias);
      final quoted = RegExp('["“]?$escaped["”]?\\s*[:：]\\s*["“]([^"”\\n]{1,700})["”]', multiLine: true);
      final m1 = quoted.firstMatch(raw);
      if (m1 != null) return (m1.group(1) ?? '').trim();
      final plain = RegExp('["“]?$escaped["”]?\\s*[:：]\\s*([^,，\\n}]{1,700})', multiLine: true);
      final m2 = plain.firstMatch(raw);
      if (m2 != null) return (m2.group(1) ?? '').trim().replaceAll(RegExp(r'["“”]+$'), '').trim();
    }
    return '';
  }

  int _readIntFromRaw(String raw, List<String> aliases, int fallback) {
    final text = _readTextFieldFromRaw(raw, aliases, '');
    final m = RegExp(r'\d+').firstMatch(text);
    return int.tryParse(m?.group(0) ?? '') ?? fallback;
  }

  TodoGoalAnalysisResult _fallbackAnalysis(TodoTaskRecord task, {required String provider, required String modelLabel}) {
    final title = task.title.trim().isEmpty ? '未命名 To Do 目标' : task.title.trim();
    final body = task.bodyText.trim();
    final lower = '$title $body'.toLowerCase();
    var category = '成长';
    if (lower.contains('面试') || lower.contains('工作') || lower.contains('项目') || lower.contains('resume') || lower.contains('interview')) category = '工作';
    if (lower.contains('英语') || lower.contains('学习') || lower.contains('考试') || lower.contains('study')) category = '学习';
    if (lower.contains('运动') || lower.contains('减肥') || lower.contains('睡眠') || lower.contains('健康')) category = '健康';
    final actionTitle = title.length > 18 ? '${title.substring(0, 18)}…' : title;
    return TodoGoalAnalysisResult(
      goalTitle: title,
      deepMeaning: '【本地兜底分析】这个目标暂时没有拿到可靠AI返回，因此先按通用目标转化原则处理：它可能不是单纯待办事项，而是一个方向线索，帮助你从迷茫回到当下，从等待结果回到真实行动。',
      desiredIdentity: '成为能够把想法落实为真实行动的人。',
      goalCategory: category,
      goalOriginType: '尚不确定',
      selfConcordanceScore: 68,
      processValue: '【兜底过程价值】先把推进过程当作一次“为沿途而活”的练习：不把幸福押在完成那一刻，而是在今天这一小步里体验自己进入现实、获得方向、逐渐成长。',
      obstacleSummary: '【兜底阻力判断】可能的阻力是目标过大、意义感不清、开始成本高、担心做得不够好，或把目标误解为终点压力。建议重新点击 AI 分析以获得更贴合此目标的判断。',
      todayMinimumAction: '围绕“$actionTitle”先做 5 分钟，并留下一个事实记录。',
      minimumStandard: '开始2分钟即可；目标的第一作用是让你进入当下，不要求完美完成。',
      simplifiedStandard: '做5分钟，完成一个不要求完美的小片段。',
      recommendedStandard: '完成一个清晰小步骤，并写下一句话：这个过程里有什么值得体验。',
      stretchStandard: '连续推进 25 分钟，并整理出下一步。',
      difficultyScore: 5,
      zoneType: 'stretch',
      coachMessage: '当前是本地兜底结果：先把它变成今天能够开始的一小步；如需真正贴合目标背景的问题树，请在目标详情页单独点击“问题树”按钮。',
      resultGoal: title,
      valueGoal: '让这个方向服务于真实需要、选择权与长期成长，而不是只服务于比较和焦虑。',
      processGoal: '每天用一个 2-5 分钟可开始的动作练习投入、不完美行动和现实反馈。',
      coreValues: '成长、自由、勇气',
      autonomyScore: 68,
      valueAlignmentScore: 72,
      interestConnectionScore: 60,
      passionScore: 58,
      feasibilityScore: 76,
      externalPressureScore: 35,
      processHappinessScore: 70,
      goalType: '需要继续澄清的自我一致目标',
      currentStage: '最小行动验证期',
      actionPlace: '当前最容易开始的安静位置',
      startTrigger: '打开完成动作所需的第一个工具后立即开始',
      completionQuestion: '完成后，你比开始前多了一点什么？',
      processAction: '行动时只观察一个瞬间：我正在练习开始、学习或面对不完美。',
      valueAction: '写一句这一步如何服务于成长、自由或勇气。',
      experiencePrompt: '今天做这件事时，你想体验什么：学习感、掌控感、勇气、自由，还是一点点进步？',
      userNeedInterpretation: '你写下“$title”，可能是想解决一个眼前任务，也可能是希望获得更多选择、能力或安心感。仅凭标题还不能判断哪一种对你最重要。',
      keyUncertainties: '尚不确定这是你主动选择的目标、现实必要任务，还是主要来自外部期待；也不清楚你愿意投入的时间与可接受代价。',
      clarifyingQuestions: '如果没有人评价你，你还会选择“$title”吗？\n你最希望它改变的是眼前结果、长期能力，还是当前生活状态？\n你目前愿意为它投入多少时间和精力？',
      possibleDirections: '1. 先花一点时间弄清自己真正想通过“$title”改变什么。适合方向仍模糊、暂时没有硬期限的情况。\n2. 保留目标，但先从“$actionTitle”的最小版本开始。适合目标基本明确、只是难以启动的情况。\n3. 保留真正重视的需要，换一条成本更可承受的实现路径。适合当前方式长期消耗、却仍认可目标价值的情况。',
      referenceCases: '例如，同样想完成“$title”的两个人，一个可能先解决眼前期限，另一个可能先补关键能力。看起来目标相同，但他们适合的第一步并不一样。',
      recommendationRationale: '可以先做一个成本很低、容易撤回的小尝试，因为实际体验通常比继续空想更能帮助你判断。若你面临明确期限或安全风险，则不适合只做缓慢试探。',
      userDecisionPrompt: '看完这些可能性后，哪一种最接近你现在真正想解决的问题？你也可以拒绝全部建议并重新描述。',
      provider: provider,
      solutionPlans: const <TodoGoalSolutionPlan>[],
      modelLabel: modelLabel,
      usedFallback: true,
    );
  }

  TodoGoalReviewResult _fallbackReview({
    required String goalTitle,
    required String deepMeaning,
    required String actionTitle,
    required bool completed,
    required String userReflection,
    required String provider,
    required String modelLabel,
  }) {
    final done = completed ? '你今天已经完成了一个真实行动。' : '今天即使没有完整完成，也已经暴露出目标落地中的真实阻力。';
    return TodoGoalReviewResult(
      summary: '$done 这件事的意义不只在于“$actionTitle”本身，而在于你把目标落成了一个可观察动作，让抽象愿望进入了现实。',
      processInsight: userReflection.trim().isEmpty ? '可以先观察：开始前最难的地方是什么，做起来以后有没有更清楚地进入当下、看见过程本身的一点价值。' : '你今天记录下来的过程感受，是后续调整目标难度和节奏的重要材料。',
      meaningConnection: deepMeaning.trim().isEmpty ? '这个目标可以继续追问：它究竟通向你想要的哪一种生活？它是自我和谐目标，还是外部压力伪装成目标？' : deepMeaning,
      tomorrowNextStep: '明天继续做一个更小、更清晰、5分钟内能开始的动作；先开始最低标准，再观察过程。',
      encouragement: '不要只用完成率评价自己。能把任务缩小、开始、记录、再设计下一步，本身就是改变。',
      nextStepOptions: completed
          ? '选项A：重复最低行动巩固；选项B：只增加一个小变量；选项C：先复盘最有效的条件。'
          : '选项A：缩小到2分钟；选项B：更换时间或环境；选项C：先收集导致卡住的信息。',
      decisionPrompt: '哪一种下一步最符合你明天的精力、现实条件和真正需要？你也可以提出第四种。',
      provider: provider,
      modelLabel: modelLabel,
      usedFallback: true,
    );
  }

  TodoGoalStepRecoveryResult _fallbackRecovery({
    required String goalTitle,
    required String actionTitle,
    required String userResult,
    required String userReflection,
    required String obstacle,
    required String provider,
    required String modelLabel,
  }) {
    return TodoGoalStepRecoveryResult(
      failureDiagnosis: userResult == 'success'
          ? '这一步已经产生有效反馈：说明当前动作粒度基本可执行。接下来不要突然加码过猛，而是沿着同一父问题继续推进一个相邻小节点。'
          : '失败不等于目标错误，更可能是子步骤仍然过大、触发条件不清、环境阻力未处理，或最低标准没有低到可以开始。',
      restartGuidance: userResult == 'success'
          ? '保持原方案，用同样时间、地点或触发线索再做一次；成功后只增加一个很小的变量。'
          : '先不要重构整个目标。把“$actionTitle”缩小到2分钟内能开始：打开相关页面、写一句、读一段、列一个清单，完成后马上记录事实。',
      principleFit: '替代步骤保留父目标方向，但把难度拉回舒适区与拉伸区之间，让目标继续服务当下，而不是制造恐慌。',
      alternatives: <TodoGoalAlternativeStep>[
        TodoGoalAlternativeStep(
          title: '2分钟重启：只打开并留下一个事实痕迹',
          rationale: '把启动成本降到最低，先恢复行动链条。',
          minimumStandard: '计时2分钟，只打开材料或写一句事实。',
          recommendedStandard: '完成5分钟并记录“我实际做了什么”。',
          zoneType: 'comfort',
          difficultyScore: 2,
        ),
        TodoGoalAlternativeStep(
          title: '换入口：先解决最小阻力点',
          rationale: '如果原步骤卡住，先处理导致逃避的触发点。',
          minimumStandard: '写下一个最小阻力：时间、工具、资料、情绪或不确定性。',
          recommendedStandard: '针对这个阻力做一个可观察调整。',
          zoneType: 'stretch',
          difficultyScore: 3,
        ),
        TodoGoalAlternativeStep(
          title: '同一目标的旁路推进',
          rationale: '不推翻父目标，只换一条更容易进入现实的路径。',
          minimumStandard: '选择一个旁路动作并做5分钟。',
          recommendedStandard: '做完后判断它是否能回推父问题。',
          zoneType: 'stretch',
          difficultyScore: 4,
        ),
      ],
      restructureWarning: '暂不建议重构整个方案。先用替代步骤验证1-2次；只有连续多次证明父目标或方法方向错误时，再考虑重构。',
      provider: provider,
      modelLabel: modelLabel,
      usedFallback: true,
    );
  }

  List<TodoGoalSolutionPlan> _fallbackPlans(String goalTitle, String actionTitle) {
    return <TodoGoalSolutionPlan>[
      TodoGoalSolutionPlan(
        solutionId: '',
        goalId: '',
        sourceTaskId: '',
        title: '先重新开始：把第一步降到足够小',
        methodName: '适合目前很难开始或精力不足时',
        methodBasis: '把问题缩小到能立刻开始的行为单元，先用行动产生反馈，再逐渐提高难度。',
        zoneType: 'comfort',
        coreValueFocus: '目标服务当下；先进入过程，不追求一次完成。',
        summary: '先围绕“$actionTitle”做一个极小版本，降低开始时的压力；连续尝试几次后，再判断真正卡住你的是启动、能力还是方向。',
        riskNotes: '进展较慢，需要避免一直停留在过小动作里。',
        isSelected: false,
        status: 'candidate',
        sortOrder: 0,
        rawJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        problemDefinition: '当前问题不是“必须立刻完成目标”，而是尚未形成低阻力、可重复的启动链条；需要先验证启动成本是否是主要约束。',
        knownFacts: '已知用户有目标，并需要一个今天能开始的动作；其他资源、时间、能力与阻力信息尚不充分。',
        keyAssumptions: '假设主要瓶颈是启动成本而不是方向错误或资源缺失；需要用微行动验证。',
        rootCauseAnalysis: '候选近因包括动作过大、触发不清、环境阻力和完美主义；目前没有证据断言唯一根因。',
        optionComparison: '成本最低、可逆性最高、反馈快，但对能力或资源型问题的解决力度有限。',
        evidencePlan: '连续2-3次只做2分钟，记录是否顺利开始、在哪一步卡住，以及做完后是否更愿意继续。',
        successMetrics: '看到提示后能开始，并且你越来越能说清具体卡点，而不是只觉得“我不行”。',
        stopConditions: '若多次可启动但目标仍无进展，或发现核心问题是知识、资源或方向，则切换方案。',
        userChoiceGuidance: '若你当前精力低且最大问题是开始，可优先考虑；若存在硬性期限或专业能力缺口，不应只用微行动。',
        nodes: _fallbackNodes(goalTitle, actionTitle, 'comfort'),
      ),
      TodoGoalSolutionPlan(
        solutionId: '',
        goalId: '',
        sourceTaskId: '',
        title: '边做边判断：逐步找出真正卡点',
        methodName: '适合目标大致明确、但路径和阻力还不清楚时',
        methodBasis: '把大问题拆成父子节点；从底层可执行动作开始，完成后逐层回推到父问题。',
        zoneType: 'stretch',
        coreValueFocus: '自我和谐、过程重于抵达、拉伸而非恐慌。',
        summary: '把“$goalTitle”拆成几个现实障碍，每次只处理一个，并根据行动结果决定下一步，不预先假定唯一原因。',
        riskNotes: '需要按节点复盘；失败时优先换替代步骤，不轻易推翻整套方案。',
        isSelected: false,
        status: 'candidate',
        sortOrder: 1,
        rawJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        problemDefinition: '需要把目标与现实差距拆成可验证子问题，识别真正约束并逐步解决，而不是直接把目标拆成待办清单。',
        knownFacts: '已知目标方向和一个候选行动；根因、资源约束、优先级和有效路径仍需验证。',
        keyAssumptions: '假设问题可以通过分解、证据收集和迭代实验逐步降低不确定性。',
        rootCauseAnalysis: '先区分症状、近因、能力缺口、资源限制、环境结构和目标本身是否合理，再验证最关键根因。',
        optionComparison: '信息质量和长期有效性较高，成本与速度居中；需要用户持续记录事实和执行判断规则。',
        evidencePlan: '先挑一个最可能影响进展的卡点，做一次低成本尝试；再根据结果决定补能力、改流程、换环境还是寻求协作。',
        successMetrics: '每次尝试后都更清楚什么有效、什么无效，并且能看到一个与目标相关的实际变化。',
        stopConditions: '若证据否定核心因果链、成本超过收益或目标不再符合价值，应暂停并重定义问题。',
        userChoiceGuidance: '适合愿意用事实逐步判断、又不希望过度冲刺的情况；这是暂定推荐，不是自动选择。',
        nodes: _fallbackNodes(goalTitle, actionTitle, 'stretch'),
      ),
      TodoGoalSolutionPlan(
        solutionId: '',
        goalId: '',
        sourceTaskId: '',
        title: '期限真的紧迫时：集中完成关键结果',
        methodName: '只适合期限真实、后果明确且资源足够时',
        methodBasis: '用明确截止时间和强约束快速推进，但只作为对照方案或短期应急方案。',
        zoneType: 'panic',
        coreValueFocus: '提醒用户识别恐慌区，避免把目标变成压迫。',
        summary: '先确认期限和最低必要结果，再集中时间处理最关键部分，同时保留健康和错误率的底线；不作为长期方式。',
        riskNotes: '容易导致逃避、挫败或反弹；若连续失败，应退回拉伸区方案。',
        isSelected: false,
        status: 'candidate',
        sortOrder: 2,
        rawJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        problemDefinition: '存在可能的真实紧急期限，需要判断高强度投入是否必要、有效且风险可接受。',
        knownFacts: '当前没有足够信息证明必须冲刺；期限真实性、失败代价和可用资源需要确认。',
        keyAssumptions: '假设时间是首要约束，且外部约束能提高执行而不会造成不可接受的反弹。',
        rootCauseAnalysis: '若根因是信息不足、路径错误或能力缺口，单纯加压可能只会放大问题。',
        optionComparison: '速度可能最快，但风险、成本和不可持续性最高；只有紧急性证据充分时才合理。',
        evidencePlan: '先核实真正的截止时间、最低必须交付什么、能获得哪些帮助，再试一个短周期集中行动。',
        successMetrics: '在限定周期内产生关键结果，同时睡眠、健康和错误率保持在可接受范围。',
        stopConditions: '出现健康恶化、错误率显著增加、连续失败或紧急性被证伪时立即降级。',
        userChoiceGuidance: '仅在真实紧急、代价明确且你知情同意时考虑；默认不应作为长期方案。',
        nodes: _fallbackNodes(goalTitle, actionTitle, 'panic'),
      ),
    ];
  }

  List<TodoGoalProblemNode> _fallbackNodes(String goalTitle, String actionTitle, String zone) {
    final difficulty = zone == 'panic' ? 8 : (zone == 'comfort' ? 2 : 5);
    final minutes = zone == 'panic' ? 45 : (zone == 'comfort' ? 2 : 10);
    return <TodoGoalProblemNode>[
      TodoGoalProblemNode(
        nodeId: '',
        goalId: '',
        solutionId: '',
        parentNodeId: '',
        relationType: 'tree',
        nodeType: 'problem',
        title: '先说清“$goalTitle”现在具体卡在哪里',
        description: '先把想达到的状态、当前差距和现实限制说具体。',
        acceptanceCriteria: '能说清目标状态，并看到至少一个现实中的证据。',
        actionableStep: '',
        zoneType: zone,
        difficultyScore: difficulty,
        estimatedMinutes: minutes,
        sequenceOrder: 0,
        dependenciesJson: '',
        status: 'not_started',
        completionNote: '',
        aiReviewJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        tempNodeId: 'root',
        logicQuestion: '现实差距是什么，哪些部分可控，最关键的不确定性是什么？',
        knownFacts: '用户表达了目标“$goalTitle”。',
        assumptions: '目标值得继续、且存在可通过行动改变的因素；均待用户与证据确认。',
        evidenceNeeded: '当前状态、期望标准、期限、资源、约束和利益相关者信息。',
        decisionRule: '先补齐影响路径选择的关键信息，再决定进入诊断、实验或执行分支。',
      ),
      TodoGoalProblemNode(
        nodeId: '',
        goalId: '',
        solutionId: '',
        parentNodeId: '',
        relationType: 'tree',
        nodeType: 'sub_problem',
        title: '找到今天能够开始的一步',
        description: '把抽象目标落到一个可观察动作。',
        acceptanceCriteria: '存在一个2-10分钟内能开始的动作。',
        actionableStep: '',
        zoneType: zone,
        difficultyScore: difficulty,
        estimatedMinutes: minutes,
        sequenceOrder: 1,
        dependenciesJson: '',
        status: 'not_started',
        completionNote: '',
        aiReviewJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        tempNodeId: 'entry',
        tempParentNodeId: 'root',
        logicQuestion: '当前最大约束是启动、能力、资源、环境还是目标方向？',
        knownFacts: '现有行动入口为“$actionTitle”。',
        assumptions: '该入口足够小且与结果存在因果联系。',
        evidenceNeeded: '实际开始时间、卡点、完成结果和过程记录。',
        decisionRule: '若能启动但无有效反馈，转向能力/路径诊断；若不能启动，继续降低阻力。',
      ),
      TodoGoalProblemNode(
        nodeId: '',
        goalId: '',
        solutionId: '',
        parentNodeId: '',
        relationType: 'tree',
        nodeType: 'action',
        title: '先试一次：$actionTitle',
        description: '先做最低标准，做完记录事实和过程体验。',
        acceptanceCriteria: zone == 'comfort' ? '只做2分钟即可。' : '完成5-10分钟，并留下一个事实记录。',
        actionableStep: actionTitle,
        zoneType: zone,
        difficultyScore: difficulty,
        estimatedMinutes: minutes,
        sequenceOrder: 2,
        dependenciesJson: '',
        status: 'not_started',
        completionNote: '',
        aiReviewJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        tempNodeId: 'first_action',
        tempParentNodeId: 'entry',
        logicQuestion: '执行该动作能否产生支持或否定关键假设的证据？',
        knownFacts: '这是当前可用的最小实验动作。',
        assumptions: '完成动作会提供比继续思考更多的现实信息。',
        evidenceNeeded: '是否开始、实际耗时、产出、阻力和下一步信息。',
        decisionRule: '达到验收标准则保留或小幅升级；未达到则分析具体环节并换实验。',
      ),
      TodoGoalProblemNode(
        nodeId: '',
        goalId: '',
        solutionId: '',
        parentNodeId: '',
        relationType: 'tree',
        nodeType: 'sub_problem',
        title: '根据这次结果决定下一步',
        description: '看这一步是否带来实际变化；有效就继续，遇到阻碍就缩小或换一种走法。',
        acceptanceCriteria: '复盘中至少得到一个替代步骤或下一步。',
        actionableStep: '完成后记录：发生了什么、哪里卡住、下一次准备怎样调整。',
        zoneType: zone,
        difficultyScore: difficulty,
        estimatedMinutes: 5,
        sequenceOrder: 3,
        dependenciesJson: '',
        status: 'not_started',
        completionNote: '',
        aiReviewJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        tempNodeId: 'review',
        tempParentNodeId: 'root',
      ),
    ];
  }


  List<TodoGoalSolutionPlan> _readPlans(Map<String, dynamic> map) {
    final value = _readDynamic(map, const <String>[
      'solutionPlans',
      'solution_plans',
      'solutions',
      'plans',
      'problemSolvingPlans',
      'problem_solving_plans',
      'problemSolutions',
      'problem_solutions',
      '方案',
      '解决方案',
      '问题解决方案',
      '多套方案',
      '方案列表',
      'problem_solution_options',
      'options',
    ]);
    final plans = <TodoGoalSolutionPlan>[];
    void addPlan(Object? item, int index, {String fallbackTitle = ''}) {
      if (item is Map<String, dynamic>) {
        final copy = Map<String, dynamic>.from(item);
        if (fallbackTitle.trim().isNotEmpty && !copy.containsKey('title') && !copy.containsKey('方案名称')) {
          copy['title'] = fallbackTitle.trim();
        }
        plans.add(TodoGoalSolutionPlan.fromJson(copy, sortOrder: index));
      } else if (item is Map) {
        addPlan(Map<String, dynamic>.from(item), index, fallbackTitle: fallbackTitle);
      }
    }

    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        addPlan(value[i], i);
      }
    } else if (value is Map<String, dynamic>) {
      var i = 0;
      for (final entry in value.entries) {
        addPlan(entry.value, i, fallbackTitle: entry.key);
        i++;
      }
    } else if (value is Map) {
      var i = 0;
      for (final entry in value.entries) {
        addPlan(entry.value, i, fallbackTitle: entry.key.toString());
        i++;
      }
    }

    if (plans.isEmpty) {
      final singlePlanKeys = const <String>[
        'comfortPlan', 'comfort_plan', '舒适区方案',
        'stretchPlan', 'stretch_plan', '拉伸区方案',
        'panicPlan', 'panic_plan', '恐慌区方案',
      ];
      for (var i = 0; i < singlePlanKeys.length; i++) {
        final key = singlePlanKeys[i];
        if (map.containsKey(key)) addPlan(map[key], plans.length, fallbackTitle: key);
      }
    }
    return plans;
  }

  List<TodoGoalAlternativeStep> _readAlternativeSteps(Map<String, dynamic> map) {
    final value = map['alternatives'] ?? map['alternativeSteps'];
    if (value is! List) return <TodoGoalAlternativeStep>[];
    final steps = <TodoGoalAlternativeStep>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        steps.add(TodoGoalAlternativeStep.fromJson(item));
      } else if (item is Map) {
        steps.add(TodoGoalAlternativeStep.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return steps;
  }

  Map<String, dynamic> _extractJsonObject(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return <String, dynamic>{};
    text = text
        .replaceAll(RegExp(r'^```json', multiLine: true), '')
        .replaceAll(RegExp(r'^```', multiLine: true), '')
        .replaceAll(RegExp(r'```$', multiLine: true), '')
        .trim();
    Map<String, dynamic> convert(Object? decoded) {
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is List && decoded.isNotEmpty) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) return item;
          if (item is Map) return Map<String, dynamic>.from(item);
        }
      }
      return <String, dynamic>{};
    }

    try {
      final converted = convert(jsonDecode(text));
      if (converted.isNotEmpty) return converted;
    } catch (_) {}
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final converted = convert(jsonDecode(text.substring(start, end + 1)));
        if (converted.isNotEmpty) return converted;
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _resolveAnalysisPayload(Map<String, dynamic> root) {
    if (_hasMeaningfulAnalysis(root) || _readPlans(root).isNotEmpty) return root;
    final choices = root['choices'];
    if (choices is List) {
      for (final choice in choices) {
        if (choice is! Map) continue;
        final message = choice['message'];
        final content = message is Map ? message['content'] : choice['content'];
        final resolved = _resolvePayloadValue(content);
        if (resolved.isNotEmpty) return resolved;
      }
    }
    for (final key in const <String>[
      'analysis', 'goalAnalysis', 'goal_analysis', 'goalProfile', 'goal_profile', 'profile',
      'result', 'data', 'payload', 'content', 'output', 'answer', 'text',
      '目标分析', '目标画像', '目标转化', '目标信息', '目标分析结果', '分析结果', '返回结果',
    ]) {
      if (!root.containsKey(key)) continue;
      final resolved = _resolvePayloadValue(root[key]);
      if (resolved.isNotEmpty) return resolved;
    }
    // Some providers wrap the actual object one level deeper under an arbitrary
    // key. Inspect direct child maps only; avoid walking solution plan nodes.
    for (final value in root.values) {
      final resolved = _resolvePayloadValue(value, shallowOnly: true);
      if (resolved.isNotEmpty) return resolved;
    }
    return root;
  }

  Map<String, dynamic> _resolvePayloadValue(Object? value, {bool shallowOnly = false}) {
    if (value is Map<String, dynamic>) {
      if (_hasMeaningfulAnalysis(value) || _readPlans(value).isNotEmpty) return value;
      if (!shallowOnly) return _resolveAnalysisPayload(value);
    } else if (value is Map) {
      final m = Map<String, dynamic>.from(value);
      if (_hasMeaningfulAnalysis(m) || _readPlans(m).isNotEmpty) return m;
      if (!shallowOnly) return _resolveAnalysisPayload(m);
    } else if (value is String && value.trim().isNotEmpty) {
      final parsed = _extractJsonObject(value);
      if (parsed.isNotEmpty && (_hasMeaningfulAnalysis(parsed) || _readPlans(parsed).isNotEmpty)) return parsed;
    } else if (value is List) {
      for (final item in value) {
        final resolved = _resolvePayloadValue(item, shallowOnly: shallowOnly);
        if (resolved.isNotEmpty) return resolved;
      }
    }
    return <String, dynamic>{};
  }

  bool _hasMeaningfulAnalysis(Map<String, dynamic> map) {
    var count = 0;
    for (final key in const <String>['goalTitle', 'deepMeaning', 'processValue', 'todayMinimumAction', 'coachMessage']) {
      final text = _read(map, key, '').trim();
      if (text.isNotEmpty && !text.contains('【本地兜底分析】') && !text.contains('【兜底过程价值】')) count++;
    }
    return count >= 2;
  }

  Object? _readDynamic(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) return map[key];
    }
    for (final wrapper in const <String>[
      'analysis', 'goalAnalysis', 'goal_analysis', 'goalProfile', 'goal_profile', 'profile',
      'result', 'data', 'payload', 'content', 'output', 'answer',
      '目标分析', '目标画像', '目标转化', '目标信息', '目标分析结果', '分析结果',
    ]) {
      final value = map[wrapper];
      if (value is Map<String, dynamic>) {
        final found = _readDynamic(value, keys);
        if (found != null) return found;
      } else if (value is Map) {
        final found = _readDynamic(Map<String, dynamic>.from(value), keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  List<String> _fieldAliases(String key) {
    switch (key) {
      case 'goalTitle':
        return const <String>['goalTitle', 'goal_title', 'title', 'targetTitle', 'target_title', 'problemTitle', 'problem_title', '目标标题', '目标名称', '目标', '问题标题', '问题名称'];
      case 'deepMeaning':
        return const <String>['deepMeaning', 'deep_meaning', 'meaning', 'deepMeaningText', 'whyToday', 'why_today', 'meaningToday', 'meaning_today', 'valueMeaning', 'value_meaning', '深层意义', '深层含义', '意义', '价值意义', '为什么值得做', '今天为什么值得做', '方向意义', '深度意义'];
      case 'desiredIdentity':
        return const <String>['desiredIdentity', 'desired_identity', 'identity', 'identityDirection', 'identity_direction', 'becoming', 'personToBecome', 'person_to_become', '身份方向', '理想身份', '我正在成为怎样的人', '成为怎样的人', '想成为的人'];
      case 'goalCategory':
        return const <String>['goalCategory', 'goal_category', 'category', 'type', 'domain', '目标类别', '目标分类', '类别', '领域'];
      case 'goalOriginType':
        return const <String>['goalOriginType', 'goal_origin_type', 'originType', 'origin_type', 'motivationType', 'motivation_type', '目标来源', '来源类型', '动机来源', '目标动机'];
      case 'selfConcordanceScore':
        return const <String>['selfConcordanceScore', 'self_concordance_score', 'selfConcordance', 'score', '自我和谐分', '自我和谐评分'];
      case 'processValue':
        return const <String>['processValue', 'process_value', 'processMeaning', 'process_meaning', 'todayProcessValue', 'today_process_value', 'processExperience', 'process_experience', '过程价值', '过程意义', '今日过程价值', '体验过程', '沿途价值'];
      case 'obstacleSummary':
        return const <String>['obstacleSummary', 'obstacle_summary', 'obstacles', 'obstacle', 'barriers', 'barrier', 'challenge', 'challenges', 'risk', 'risks', '阻力', '阻力摘要', '可能阻力', '阻碍', '困难', '卡点', '风险'];
      case 'todayMinimumAction':
        return const <String>['todayMinimumAction', 'today_minimum_action', 'minimumAction', 'minimum_action', 'todayAction', 'today_action', 'firstStep', 'first_step', 'nextStep', 'next_step', 'tinyAction', 'tiny_action', 'tinyStep', 'tiny_step', 'minimumNextStep', 'minimum_next_step', 'starterAction', 'starter_action', 'actionStep', 'action_step', 'immediateAction', 'immediate_action', '今日最小行动', '最小行动', '今天行动', '今日行动', '最小步骤', '第一步', '下一步', '启动动作', '立即行动', '可执行行动'];
      case 'minimumStandard':
        return const <String>['minimumStandard', 'minimum_standard', 'minStandard', 'min_standard', 'doneMinimum', 'done_minimum', '最低标准', '最小标准', '最低完成标准', '完成底线'];
      case 'recommendedStandard':
        return const <String>['recommendedStandard', 'recommended_standard', 'normalStandard', 'normal_standard', 'standard', '推荐标准', '正常标准', '标准完成'];
      case 'stretchStandard':
        return const <String>['stretchStandard', 'stretch_standard', 'challengeStandard', 'challenge_standard', 'stretchChallenge', 'stretch_challenge', '拉伸标准', '挑战标准', '拉伸挑战'];
      case 'difficultyScore':
        return const <String>['difficultyScore', 'difficulty_score', 'difficulty', '难度', '难度分'];
      case 'zoneType':
        return const <String>['zoneType', 'zone_type', 'zone', 'difficultyZone', 'difficulty_zone', 'comfortZone', 'comfort_zone', '难度区间', '区域', '舒适区拉伸区恐慌区'];
      case 'coachMessage':
        return const <String>['coachMessage', 'coach_message', 'message', 'suggestion', 'advice', 'guidance', 'coachAdvice', 'coach_advice', '教练提示', '提示', '行动建议', '教练建议', '当前建议'];
    }
    return <String>[key];
  }

  String _read(Map<String, dynamic> map, String key, String fallback) {
    final value = _readDynamic(map, _fieldAliases(key));
    final text = _toUserFacingText(value, fieldKey: key);
    return text.isEmpty ? fallback : text;
  }

  String _toUserFacingText(dynamic value, {required String fieldKey}) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) {
      final lines = <String>[];
      for (var index = 0; index < value.length; index++) {
        final item = value[index];
        final text = item is Map
            ? _mapToUserFacingText(Map<String, dynamic>.from(item), fieldKey: fieldKey, index: index)
            : item.toString().trim();
        if (text.isNotEmpty) lines.add(text);
      }
      return lines.join('\n');
    }
    if (value is Map) {
      return _mapToUserFacingText(Map<String, dynamic>.from(value), fieldKey: fieldKey, index: 0);
    }
    return value.toString().trim();
  }

  String _mapToUserFacingText(Map<String, dynamic> value, {required String fieldKey, required int index}) {
    String read(List<String> keys) {
      for (final key in keys) {
        final item = value[key];
        if (item != null && item.toString().trim().isNotEmpty) return item.toString().trim();
      }
      return '';
    }

    if (fieldKey == 'possibleDirections') {
      final direction = read(const <String>['direction', 'title', 'name', '方向', '路径']);
      final conditions = read(const <String>['applicableConditions', 'applicable_conditions', 'conditions', '适用条件']);
      final benefits = read(const <String>['benefits', 'possibleBenefits', '收益', '可能收获']);
      final costs = read(const <String>['costsAndRisks', 'costs_and_risks', 'risks', '成本风险', '需要考虑']);
      return <String>[
        '${index + 1}. ${direction.isEmpty ? '一种可选路径' : direction}',
        if (conditions.isNotEmpty) '适合：$conditions',
        if (benefits.isNotEmpty) '可能收获：$benefits',
        if (costs.isNotEmpty) '需要考虑：$costs',
      ].join('\n');
    }

    if (fieldKey == 'referenceCases') {
      final title = read(const <String>['title', 'case', 'scenario', '案例', '情境']);
      final choice = read(const <String>['choice', 'approach', 'action', '选择', '做法']);
      final lesson = read(const <String>['lesson', 'insight', 'result', '启发', '结果']);
      return <String>[
        '${index + 1}. ${title.isEmpty ? '参考情境' : title}',
        if (choice.isNotEmpty) choice,
        if (lesson.isNotEmpty) '可以借鉴：$lesson',
      ].join('\n');
    }

    const labels = <String, String>{
      'interpretation': '一种可能',
      'reason': '原因',
      'condition': '适合',
      'benefit': '可能收获',
      'risk': '需要考虑',
      'question': '想一想',
    };
    final parts = <String>[];
    for (final entry in value.entries) {
      final text = _toUserFacingText(entry.value, fieldKey: fieldKey);
      if (text.isEmpty) continue;
      parts.add('${labels[entry.key] ?? ''}${labels.containsKey(entry.key) ? '：' : ''}$text');
    }
    return parts.join('\n');
  }

  int _readInt(Map<String, dynamic> map, String key, int fallback) {
    final value = _readDynamic(map, _fieldAliases(key));
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _normalizeZone(String value) {
    final v = value.trim().toLowerCase();
    if (v.contains('panic') || v.contains('恐慌')) return 'panic';
    if (v.contains('comfort') || v.contains('舒适')) return 'comfort';
    return 'stretch';
  }
}
