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
    final localOutlines = _fallbackPlans(analysis.goalTitle, analysis.todayMinimumAction).map(_withoutProblemNodes).toList(growable: false);
    TodoGoalSolutionGenerationResult fallback() => TodoGoalSolutionGenerationResult(
          plans: localOutlines,
          provider: 'local',
          modelLabel: state['label'] ?? '本地策略',
          usedFallback: true,
        );
    if (state['available'] != '1') return fallback();

    final context = _solutionContext(task: task, analysis: analysis);
    try {
      final raw = await _ai.generateText(
        prompt: '''$context
本次只生成三条问题解决“方案概览”，不要生成 nodes、problemTree、步骤或行动树。
分别提供 comfort、stretch、panic 三条原理不同的候选路径。每条只填写：title、methodName、methodBasis、zoneType、coreValueFocus、summary、riskNotes、problemDefinition、knownFacts、keyAssumptions、rootCauseAnalysis、optionComparison、evidencePlan、successMetrics、stopConditions、userChoiceGuidance、referenceCases。
每条方案必须把“它可能适合什么需要”写成待用户确认的假设，并给出1-2个具体参考案例帮助用户打开思路；案例只能启发，不能当作用户必须照做的结论。
用户稍后会手动点击某条方案，再单独请求该方案的问题树。不得提前生成节点，不得替用户选择。
只输出合法 JSON：{"solutionPlans":[{...},{...},{...}]}。''',
        purpose: 'microsoft_todo.goal_solution_outlines',
        systemPrompt: '你是严谨的现实问题求解器和决策支持教练。本次只比较三条方案概览，不生成任何问题树节点，不虚构事实，不替用户选择；用事实、假设、适用条件、代价、参考案例帮助用户自行判断。只输出合法JSON。',
        maxTokens: 3000,
        expectJson: true,
        temperature: 0.2,
      );
      final parsed = _extractJsonObject(raw);
      var outlines = _readPlans(parsed);
      if (outlines.isEmpty) outlines = _readPlans(_resolveAnalysisPayload(parsed));
      final byZone = <String, TodoGoalSolutionPlan>{};
      for (final plan in outlines) {
        if (!byZone.containsKey(plan.zoneType)) byZone[plan.zoneType] = _withoutProblemNodes(plan);
      }
      final completed = <TodoGoalSolutionPlan>[];
      for (final zone in const <String>['comfort', 'stretch', 'panic']) {
        completed.add(byZone[zone] ?? localOutlines.firstWhere((plan) => plan.zoneType == zone));
      }
      return TodoGoalSolutionGenerationResult(
        plans: completed,
        provider: byZone.length == 3 ? (state['provider'] ?? 'ai') : 'hybrid',
        modelLabel: state['label'] ?? 'AI',
        rawResponse: raw,
        usedFallback: byZone.length != 3,
      );
    } catch (_) {
      return fallback();
    }
  }

  Future<TodoGoalSolutionGenerationResult> generateProblemTree({
    required TodoTaskRecord task,
    required TodoGoalAnalysisResult analysis,
    required TodoGoalSolutionPlan outline,
  }) async {
    final state = await getGlobalAiState();
    if (state['available'] != '1') {
      return TodoGoalSolutionGenerationResult(
        plans: const <TodoGoalSolutionPlan>[],
        provider: 'local',
        modelLabel: state['label'] ?? '本地策略',
        usedFallback: true,
      );
    }
    final templates = await _promptConfig.load();
    final renderedPrompt = _promptConfig.renderSolutionPrompt(
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
    final solutionGuidance = renderedPrompt.split('只输出 JSON：').first;
    final context = _solutionContext(task: task, analysis: analysis);
    final zone = outline.zoneType;
    final zoneName = zone == 'comfort' ? '舒适区' : (zone == 'panic' ? '恐慌区' : '拉伸区');
    try {
      final raw = await _ai.generateText(
        prompt: '''$solutionGuidance
$context

用户已手动选择为下面这条“$zoneName”候选方案生成问题树：
${jsonEncode(_withoutProblemNodes(outline).toJson())}

本次请求只生成这一条方案的问题树：
- 只返回一个方案，放在 solutionPlans 数组中；zoneType 必须是 "$zone"。
- 根节点到可执行叶节点至少三层，总节点建议 6-12 个。
- 父节点必须能由子问题完成结果逻辑回推；dependencies 只引用本次节点 id。
- action 叶节点必须返回 actionWhen、actionWhere、actionObject、actionProcedure、actionOutput、acceptanceCriteria、evidenceNeeded。
- 每个非叶节点都要写清待解决问题、已知依据、关键假设、证据需求、决策规则；不得把建议当标准答案。
- 方案层必须保留或补充 referenceCases：给出1-2个具体参考案例，说明相似目标在不同需要下会走不同路径。
- 叶节点必须是现实中可以立即执行和验收的动作；信息不足时生成具体的信息获取动作，不得虚构事实。
- 必须使用下面的标准包裹结构，不能把 nodes/problemTree 直接放在根对象，也不能只返回节点数组：
{"solutionPlans":[{"title":"","methodName":"","methodBasis":"","zoneType":"$zone","summary":"","problemDefinition":"","knownFacts":"","keyAssumptions":"","evidencePlan":"","successMetrics":"","stopConditions":"","userChoiceGuidance":"","referenceCases":"","nodes":[{"id":"root","parentId":"","relationType":"and","nodeType":"goal_state","title":"","description":"","logicQuestion":"","knownFacts":"","assumptions":"","evidenceNeeded":"","decisionRule":"","acceptanceCriteria":"","dependencies":[]},{"id":"a1","parentId":"root","relationType":"sequence","nodeType":"action","title":"","description":"","logicQuestion":"","knownFacts":"","assumptions":"","evidenceNeeded":"","decisionRule":"","acceptanceCriteria":"","actionableStep":"","actionWhen":"","actionWhere":"","actionObject":"","actionProcedure":"","actionOutput":"","dependencies":[]}]}]}
只输出合法 JSON。''',
        purpose: 'microsoft_todo.goal_solution_tree_$zone',
        systemPrompt: '你是严谨的现实问题求解器和决策支持教练。本次只展开用户手动指定的一条候选方案。像证明题一样给出父子推导、判断依据、参考案例和现实动作；不替用户选择，不生成其他方案。只输出合法JSON。',
        maxTokens: 6000,
        expectJson: true,
        temperature: 0.2,
      );
      final parsed = _extractJsonObject(raw);
      var candidates = _readPlans(parsed);
      if (candidates.isEmpty) candidates = _readPlans(_resolveAnalysisPayload(parsed));
      for (final candidate in candidates) {
        final normalized = _repairGeneratedTreePlan(
          candidate: candidate,
          outline: outline,
          analysis: analysis,
          zone: zone,
        );
        final isStrictlyValid = _isRigorousPlan(normalized);
        if (normalized.zoneType == zone && (isStrictlyValid || _isRecoverableTreePlan(normalized))) {
          return TodoGoalSolutionGenerationResult(
            plans: <TodoGoalSolutionPlan>[normalized],
            provider: isStrictlyValid ? (state['provider'] ?? 'ai') : 'hybrid',
            modelLabel: state['label'] ?? 'AI',
            rawResponse: raw,
            usedFallback: !isStrictlyValid,
          );
        }
      }
      return TodoGoalSolutionGenerationResult(
        plans: const <TodoGoalSolutionPlan>[],
        provider: state['provider'] ?? 'ai',
        modelLabel: state['label'] ?? 'AI',
        rawResponse: raw,
        usedFallback: true,
      );
    } catch (_) {
      return TodoGoalSolutionGenerationResult(
        plans: const <TodoGoalSolutionPlan>[],
        provider: state['provider'] ?? 'ai',
        modelLabel: state['label'] ?? 'AI',
        usedFallback: true,
      );
    }
  }

  String _solutionContext({required TodoTaskRecord task, required TodoGoalAnalysisResult analysis}) => '''
用户目标：${analysis.goalTitle}
结果目标：${analysis.resultGoal}
价值目标：${analysis.valueGoal}
过程目标：${analysis.processGoal}
核心价值：${analysis.coreValues}
已知阻碍：${analysis.obstacleSummary}
当前最小行动：${analysis.todayMinimumAction}
用户补充：${task.bodyText}
''';

  TodoGoalSolutionPlan _withoutProblemNodes(TodoGoalSolutionPlan plan) => TodoGoalSolutionPlan(
        solutionId: plan.solutionId,
        goalId: plan.goalId,
        sourceTaskId: plan.sourceTaskId,
        title: plan.title,
        methodName: plan.methodName,
        methodBasis: plan.methodBasis,
        zoneType: plan.zoneType,
        coreValueFocus: plan.coreValueFocus,
        summary: plan.summary,
        riskNotes: plan.riskNotes,
        isSelected: plan.isSelected,
        status: plan.status,
        sortOrder: plan.sortOrder,
        rawJson: plan.rawJson,
        createdAtMs: plan.createdAtMs,
        updatedAtMs: plan.updatedAtMs,
        problemDefinition: plan.problemDefinition,
        knownFacts: plan.knownFacts,
        keyAssumptions: plan.keyAssumptions,
        rootCauseAnalysis: plan.rootCauseAnalysis,
        optionComparison: plan.optionComparison,
        evidencePlan: plan.evidencePlan,
        successMetrics: plan.successMetrics,
        stopConditions: plan.stopConditions,
        userChoiceGuidance: plan.userChoiceGuidance,
        referenceCases: plan.referenceCases,
      );

  Future<String> reframeEffortLanguage(String userText) async {
    final text = userText.trim();
    if (text.isEmpty) return '';
    final state = await getGlobalAiState();
    String fallback() {
      final lower = text.toLowerCase();
      if (lower.contains('懒')) return '这不是身份结论。更可能是启动阻力过高、行动过大或触发器不明确。先把下一步缩小到 2 分钟，并提前准备材料。';
      if (lower.contains('天赋') || lower.contains('不行') || lower.contains('废')) return '先把“我不行”改成可观察反馈：当前练习量、反馈方式或策略还没有产生需要的结果。选择一个可调整变量，做一次小实验。';
      return '不要用一次结果定义自己。把这句话改写成：我遇到了一个具体阻力；下一次可以调整行动大小、时间、环境或反馈方式。';
    }
    if (state['available'] != '1') return fallback();
    try {
      final raw = await _ai.generateText(
        prompt: '''用户原话：$text
请把固定型、羞耻型身份评价改写成努力语言。只围绕用户原话回答三点：可观察事实、可能的系统变量、一个 2-10 分钟可验证调整。不得诊断人格，不得空泛鼓励，不得说教。输出 2-4 句自然中文，不要 JSON。''',
        purpose: 'microsoft_todo.effort_language',
        systemPrompt: '你是积极心理学行动教练，把身份否定转换为可观察、可调整、可验证的过程反馈。',
        maxTokens: 500,
        expectJson: false,
        temperature: 0.35,
      );
      return raw.trim().isEmpty ? fallback() : raw.trim();
    } catch (_) {
      return fallback();
    }
  }

  Future<String> generateEffortResponsePaper({required List<TodoGoalEffortEntry> entries, required List<TodoGoalRitual> rituals}) async {
    if (entries.isEmpty) return '本周还没有努力记录。先完成一次 2 分钟行动并写一句 Time-In，周报才有真实证据。';
    final state = await getGlobalAiState();
    final evidence = entries.take(30).map((e) => '${e.effortDate}｜${e.sourceContextLabel}｜${e.effortMinutes}分钟｜${e.zoneLabel}｜类型:${e.effortTypeLabel}｜Pain:${e.painScore}/5｜Gain:${e.gainScore}/5｜痛感:${e.painTypeLabel}｜象限:${e.painGainQuadrantLabel}｜投入:${e.investmentText}｜阻力:${e.obstacle}｜策略:${e.strategyUsed}｜PainReframe:${e.painReframe}｜学习:${e.timeInLearning}｜回归:${e.isReturnEvent}｜回归触发:${e.returnTrigger}｜分心后回来:${e.attentionReturnCount}').join('\n');
    final ritualText = rituals.take(10).map((r) => '${r.goalTitle}｜触发:${r.triggerText}｜行动:${r.minimumAction}｜预案:${r.frictionPlan}').join('\n');
    String fallback() {
      final minutes = entries.fold<int>(0, (sum, e) => sum + e.effortMinutes);
      final returns = entries.where((e) => e.isReturnEvent).length;
      final stretch = entries.where((e) => e.zoneType == 'stretch').length;
      final attentionReturns = entries.fold<int>(0, (sum, e) => sum + e.attentionReturnCount);
      final highPainLowGain = entries.where((e) => e.painScore >= 4 && e.gainScore < 4).length;
      return '本周你留下了 ${entries.length} 次有意义努力、共 $minutes 分钟，其中 $stretch 次处在拉伸区，$returns 次完成了“回来”，分心/偏离后回来 $attentionReturns 次。${highPainLowGain > 0 ? '有 $highPainLowGain 次高痛低成长，先降级或重查意义。' : '继续记录 Pain-Gain，用证据区分成长性不适和无效消耗。'}下周保留一个有效触发器，并把最常见阻力对应的行动再缩小一级。';
    }
    if (state['available'] != '1') return fallback();
    try {
      final raw = await _ai.generateText(
        prompt: '''请根据以下真实记录写一篇简短的个人 Response Paper：本周最重要的努力、失败提供的反馈、有效仪式、拉伸区是否平衡、Pain-Gain 是否健康、哪些痛感值得继续、哪些高痛低成长需要调整、正念回归/分心后回来能力、努力中的愉悦与关系投入、哪些行动树/问题树节点产生了真实证据、需要重新定义的目标、下周一个最重要行动。区分事实与推断，不用完成率羞辱用户，不虚构记录。
努力记录：
$evidence
仪式：
$ritualText''',
        purpose: 'microsoft_todo.effort_response_paper',
        systemPrompt: '你是积极心理学行动教练，把一周努力证据综合为可内化、可调整的 Response Paper。必须融合 No Pain No Gain 的合理拉伸、Pain-Gain 校准、正念式回来、仪式化行动与恢复节奏，并明确指出努力记录对应的目标、每日行动或问题树节点。使用自然中文，不输出JSON。',
        maxTokens: 1200,
        expectJson: false,
        temperature: 0.4,
      );
      return raw.trim().isEmpty ? fallback() : raw.trim();
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
          processInsight: reflections.isEmpty
              ? '还没有过程复盘证据。'
              : '本周留下了 ${reflections.length} 条复盘、${reflections.where((item) => item.feedbackContent.trim().isNotEmpty).length} 次反馈消化和 ${reflections.where((item) => item.actionExperiment.trim().isNotEmpty).length} 个行动实验。这些真实证据比单纯完成率更能说明成长。',
          valueEvidence: goals.expand((goal) => goal.coreValueList).take(5).join('、'),
          adjustmentAdvice: goals.any((goal) => goal.externalPressureScore >= 70) ? '优先调整外部压力过高的目标：缩短承诺周期、降低强度或重新绑定价值。' : '保持能带来意义感和投入感的行动方式。',
          nextWeekFocus: '选择一个最自我一致的目标，每天只保留一个可以开始的最低行动。',
          provider: 'local',
          modelLabel: state['label'] ?? '本地策略',
          usedFallback: true,
        );
    if (state['available'] != '1') return fallback();
    final goalText = goals.take(12).map((goal) => '- ${goal.goalTitle}｜自我一致${goal.selfConcordanceScore}｜外部压力${goal.externalPressureScore}｜过程幸福${goal.processHappinessScore}｜价值${goal.coreValues}').join('\n');
    final reflectionText = reflections.take(20).map((reflection) => '- ${reflection.reflectionDate} ${reflection.goalTitle}｜模式:${reflection.reviewMode}｜身体:${reflection.bodySignal}｜情绪:${reflection.emotionLabel}｜解释:${reflection.cognition}｜真实:${reflection.authenticTruth}｜反馈学习:${reflection.feedbackLearning}｜模式:${reflection.corePattern}｜价值:${reflection.coreValue}｜行动实验:${reflection.actionExperiment}｜意义${reflection.meaningScore}/5｜过程${reflection.processScore}/5').join('\n');
    final prompt = '''
你是温和、诚实、结构化、行动导向的复盘伙伴。请生成“过程与自我一致”成长周报：识别高频情绪、场景、认知/回避模式、核心价值、反馈接纳、真实表达与行动实验趋势。不以完成率羞辱用户，不做心理诊断，也不替用户决定下周目标。区分记录事实、你的推断和待用户确认的问题；调整建议至少给出多种可能性及适用条件，并落到一个低成本现实行动。
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
    String bodySignal = '',
    String emotionLabel = '',
    String cognition = '',
    String authenticTruth = '',
    String feedbackContent = '',
    String feedbackLearning = '',
    String coreValue = '',
    String reviewMode = 'daily',
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
    final reflectiveContext = '''

【复行 · 结构化真实记录】
复盘模式：$reviewMode
B 身体信号：$bodySignal
D 情绪命名：$emotionLabel
C 当时解释：$cognition
未表达的真实：$authenticTruth
收到/请求的反馈：$feedbackContent
用户认为可用的信息：$feedbackLearning
想守护的价值：$coreValue

请以“温和、诚实、结构化、行动导向的复盘伙伴”回应。先接住情绪，再区分事实与解释，识别但不武断定义模式，提出价值问题，最后生成一个 5 分钟内可开始、包含时间/对象/场景、可验证且允许 60 分完成的小行动。反馈不是审判；不得诊断、羞辱、替用户断言他人有错或只做空泛安慰。
除原字段外，JSON 必须包含：
{"factReflection":"事实澄清","bodySignal":"身体线索","cognitionPattern":"认知解释","emotionLabel":"情绪命名","growthPattern":"待用户确认的高频模式","valueQuestion":"价值冲突或追问","feedbackInsight":"事实/评价/可用信息/不必吸收","authenticExpression":"温和真实的替代表达","actionExperiment":"一个具体小行动","actionWhen":"明确时间对象场景","actionEvidence":"完成证据","followUpQuestion":"行动后验证问题"}
''';
    try {
      final raw = await _ai.generateText(
        prompt: '$prompt$reflectiveContext',
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
        factReflection: _read(parsed, 'factReflection', fallback.factReflection),
        bodySignal: _read(parsed, 'bodySignal', fallback.bodySignal),
        cognitionPattern: _read(parsed, 'cognitionPattern', fallback.cognitionPattern),
        emotionLabel: _read(parsed, 'emotionLabel', fallback.emotionLabel),
        growthPattern: _read(parsed, 'growthPattern', fallback.growthPattern),
        valueQuestion: _read(parsed, 'valueQuestion', fallback.valueQuestion),
        feedbackInsight: _read(parsed, 'feedbackInsight', fallback.feedbackInsight),
        authenticExpression: _read(parsed, 'authenticExpression', fallback.authenticExpression),
        actionExperiment: _read(parsed, 'actionExperiment', fallback.actionExperiment),
        actionWhen: _read(parsed, 'actionWhen', fallback.actionWhen),
        actionEvidence: _read(parsed, 'actionEvidence', fallback.actionEvidence),
        followUpQuestion: _read(parsed, 'followUpQuestion', fallback.followUpQuestion),
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
    String parentProblem = '',
    String reasoningBasis = '',
    String decisionRule = '',
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
它正在解决的父问题：${parentProblem.trim().isEmpty ? '未提供' : parentProblem.trim()}
本步骤为何能推动父问题：${reasoningBasis.trim().isEmpty ? '未提供' : reasoningBasis.trim()}
原判断规则：${decisionRule.trim().isEmpty ? '未提供' : decisionRule.trim()}
最低标准：$minimumStandard
用户选择结果：$userResult
用户过程记录：${userReflection.trim().isEmpty ? '未填写' : userReflection.trim()}
用户阻力描述：${obstacle.trim().isEmpty ? '未填写' : obstacle.trim()}

请根据科学问题解决原则输出：
1. 先列出已观察事实，再区分可能原因与待验证假设；成功时提炼可复用条件，失败时指出问题发生在哪个更小环节。
2. 定位失败发生在当前动作内部、前置条件、依赖节点还是父问题推导关系，不能用泛化心理标签解释。
3. 如何重启当前子问题，优先缩小、换路径、换环境、补前置条件，而不是立刻推翻整套方案。
4. 给出3个机制不同、但仍然解决同一父问题的替代步骤。每个替代步骤必须说明它如何绕过本次具体阻力、产出什么证据、适用条件、代价和风险，不能只是改写原句。
5. 给出验证关键前提的低成本实验和判断规则。只有关键前提被证伪、同一父问题下的多个替代步骤均失败，或推导链与目标无关时，才建议重构全方案；最终由用户选择继续、换路、切备用方案或暂停。
6. 每个替代步骤必须填写具体时间/触发、地点/工具、对象、按顺序的操作和可核对产出。缺少信息时设计具体的信息收集动作，禁止使用“适当处理、进一步推进、做一些准备”等抽象说法。

只输出JSON：
{
  "failureDiagnosis": "对成功/失败原因的结构化分析；成功时提炼可复用条件，失败时指出卡在哪个子问题或触发环节",
  "restartGuidance": "重启当前子问题的具体指导，必须可照做",
  "principleFit": "说明为什么这些调整仍然符合整个目标原则和价值体系",
  "alternatives": [
    {"title": "替代步骤1", "rationale": "如何绕过本次具体阻力并继续解决同一父问题", "minimumStandard": "可核对的最低标准", "recommendedStandard": "推荐标准", "zoneType": "comfort/stretch/panic", "difficultyScore": 1, "actionWhen":"具体时间或启动触发", "actionWhere":"具体地点、页面或工具", "actionObject":"明确处理对象", "actionProcedure":"按顺序写出动词、对象、数量或时长", "actionOutput":"执行后留下的文件、记录、消息、录音或数量"},
    {"title": "替代步骤2", "rationale": "如何绕过本次具体阻力并继续解决同一父问题", "minimumStandard": "可核对的最低标准", "recommendedStandard": "推荐标准", "zoneType": "comfort/stretch/panic", "difficultyScore": 1, "actionWhen":"具体时间或启动触发", "actionWhere":"具体地点、页面或工具", "actionObject":"明确处理对象", "actionProcedure":"按顺序写出动词、对象、数量或时长", "actionOutput":"执行后留下的文件、记录、消息、录音或数量"},
    {"title": "替代步骤3", "rationale": "如何绕过本次具体阻力并继续解决同一父问题", "minimumStandard": "可核对的最低标准", "recommendedStandard": "推荐标准", "zoneType": "comfort/stretch/panic", "difficultyScore": 1, "actionWhen":"具体时间或启动触发", "actionWhere":"具体地点、页面或工具", "actionObject":"明确处理对象", "actionProcedure":"按顺序写出动词、对象、数量或时长", "actionOutput":"执行后留下的文件、记录、消息、录音或数量"}
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
      final alternatives = _readAlternativeSteps(parsed).where(_isConcreteAlternativeStep).toList(growable: false);
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
      factReflection: '先只保留可被观察或复述的事实，不把一次结果扩大成对自己的整体判断。',
      bodySignal: '身体反应是预警信息，不是软弱证据；留意最先紧绷、发热或沉重的位置。',
      cognitionPattern: userReflection.trim().isEmpty ? '当时你如何解释这件事，仍需要由你补充确认。' : '尝试区分：发生的事实，与脑中关于失败、认可或关系的解释。',
      emotionLabel: completed ? '可能同时有轻松、投入或不确定，请以你的真实命名为准。' : '可能有失落、焦虑或内疚，请以你的真实感受为准。',
      growthPattern: completed ? '待确认：哪些条件帮助你从想法进入了行动？' : '待确认：卡住是否与回避冲突、害怕评价、过度准备或行动过大有关？',
      valueQuestion: '这件事里，你真正想守护的是成长、真实、连接、自由、责任，还是别的价值？',
      feedbackInsight: '只吸收具体、可验证、能帮助下一次调整的信息；主观评价不需要全盘接受。',
      authenticExpression: '可以用“我注意到……我真实的想法/需要是……我愿意尝试……”表达，而不攻击或讨好。',
      actionExperiment: '明天做一个 5 分钟内可开始、允许只完成 60 分的现实实验。',
      actionWhen: '明天第一次进入相关场景时，先完成最低版本。',
      actionEvidence: '留下一句话、一次发送记录、一个具体产出或一条现实反馈。',
      followUpQuestion: '实际结果真的像我担心的那样吗？我获得了什么新信息？',
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
          actionWhen: '今天下一次拿起手机时，立即计时2分钟。',
          actionWhere: '手机计时器和执行“$actionTitle”所需的原页面或文件。',
          actionObject: '“$actionTitle”对应的原始页面、材料或文件。',
          actionProcedure: '打开原页面或文件；计时2分钟；只完成一个最小片段；结束时保存或截图。',
          actionOutput: '一张截图、一个已保存片段或一句事实记录。',
        ),
        TodoGoalAlternativeStep(
          title: '换入口：先解决最小阻力点',
          rationale: '如果原步骤卡住，先处理导致逃避的触发点。',
          minimumStandard: '写下一个最小阻力：时间、工具、资料、情绪或不确定性。',
          recommendedStandard: '针对这个阻力做一个可观察调整。',
          zoneType: 'stretch',
          difficultyScore: 3,
          actionWhen: '保存失败记录后立即进行，限定5分钟。',
          actionWhere: '同一份目标求解记录和手机/电脑日历。',
          actionObject: '本次失败记录中最先出现的一个具体阻力。',
          actionProcedure: '从时间、工具、资料、环境四类中勾选一类；写出一个具体阻力；完成一项调整并截图或保存。',
          actionOutput: '一条明确阻力记录和一个已完成的环境/工具/日程调整。',
        ),
        TodoGoalAlternativeStep(
          title: '同一目标的旁路推进',
          rationale: '不推翻父目标，只换一条更容易进入现实的路径。',
          minimumStandard: '选择一个旁路动作并做5分钟。',
          recommendedStandard: '做完后判断它是否能回推父问题。',
          zoneType: 'stretch',
          difficultyScore: 4,
          actionWhen: '完成阻力记录后的今天，预留5分钟执行。',
          actionWhere: '目标求解记录以及能够产生父问题证据的页面、工具或联系人窗口。',
          actionObject: '当前父问题要求的同一种产出，不改变父问题。',
          actionProcedure: '写出原动作预期产出；列出另一种获得同类产出的方式；选择成本最低的一种执行5分钟；保存结果。',
          actionOutput: '一个与原动作服务同一父问题的替代产出，以及采用该路径的记录。',
        ),
      ],
      restructureWarning: '暂不建议重构整个方案。先用替代步骤验证1-2次；只有连续多次证明父目标或方法方向错误时，再考虑重构。',
      provider: provider,
      modelLabel: modelLabel,
      usedFallback: true,
    );
  }


  bool _isRigorousPlan(TodoGoalSolutionPlan plan) {
    if (plan.title.trim().isEmpty ||
        plan.summary.trim().isEmpty ||
        plan.problemDefinition.trim().isEmpty ||
        plan.knownFacts.trim().isEmpty ||
        plan.keyAssumptions.trim().isEmpty ||
        plan.userChoiceGuidance.trim().isEmpty ||
        plan.nodes.length < 6) {
      return false;
    }
    final nodesById = <String, TodoGoalProblemNode>{};
    for (final node in plan.nodes) {
      final id = node.tempNodeId.trim();
      if (id.isEmpty || nodesById.containsKey(id)) return false;
      nodesById[id] = node;
    }
    final roots = plan.nodes.where((node) => node.tempParentNodeId.trim().isEmpty).toList(growable: false);
    if (roots.length != 1) return false;
    const logicalRelations = <String>{'and', 'or', 'sequence', 'dependency', 'network'};
    if (!plan.nodes.any((node) => logicalRelations.contains(node.relationType.trim().toLowerCase()))) return false;
    final children = <String, List<TodoGoalProblemNode>>{};
    for (final node in plan.nodes) {
      final id = node.tempNodeId.trim();
      final parent = node.tempParentNodeId.trim();
      if (parent.isNotEmpty) {
        if (!nodesById.containsKey(parent) || parent == id) return false;
        children.putIfAbsent(parent, () => <TodoGoalProblemNode>[]).add(node);
      }
      for (final dependency in node.resolvedDependencyNodeIds) {
        if (!nodesById.containsKey(dependency) || dependency == id) return false;
      }
      if (node.title.trim().isEmpty || node.acceptanceCriteria.trim().isEmpty || node.logicQuestion.trim().isEmpty || node.decisionRule.trim().isEmpty) {
        return false;
      }
    }
    var maxDepth = 0;
    var actionableLeaves = 0;
    final visiting = <String>{};
    final visited = <String>{};
    bool walk(String id, int depth) {
      if (!visiting.add(id)) return false;
      final node = nodesById[id];
      if (node == null) return false;
      maxDepth = depth > maxDepth ? depth : maxDepth;
      final descendants = children[id] ?? const <TodoGoalProblemNode>[];
      if (descendants.isEmpty) {
        if (!node.isActionable || !node.hasConcreteActionContract || node.evidenceNeeded.trim().isEmpty || !_isConcreteActionNode(node)) return false;
        actionableLeaves++;
      } else if (node.actionableStep.trim().isNotEmpty) {
        return false;
      }
      for (final child in descendants) {
        if (!walk(child.tempNodeId.trim(), depth + 1)) return false;
      }
      visiting.remove(id);
      visited.add(id);
      return true;
    }
    if (!walk(roots.first.tempNodeId.trim(), 0)) return false;
    return visited.length == plan.nodes.length && maxDepth >= 2 && actionableLeaves >= 2;
  }


  bool _isConcreteActionNode(TodoGoalProblemNode node) {
    final fields = <String>[
      node.actionWhen,
      node.actionWhere,
      node.actionObject,
      node.actionProcedure,
      node.actionOutput,
      node.acceptanceCriteria,
    ];
    const vagueOnly = <String>['视情况', '适当', '相关', '进一步', '做一些', '处理一下', '推进目标', '完成任务', '采取行动', '根据需要', '自行选择'];
    const vaguePhrases = <String>['相关内容', '相关材料', '相关页面', '相关工具', '做一点', '先行动', '逐步推进', '开展工作', '进行处理', '采取措施', '完成一个小步骤'];
    const schemaPlaceholders = <String>['具体时间或启动触发', '具体时间或触发', '具体地点、软件页面或工具', '具体地点或工具', '明确处理对象', '明确对象', '按顺序说明动词', '按顺序的现实操作', '可核对产出', '一句话行动摘要'];
    if (fields.any((field) => field.trim().length < 4)) return false;
    if (fields.any((field) => vagueOnly.any((word) => field.trim() == word || field.trim() == '$word。'))) return false;
    if (<String>[node.actionWhere, node.actionObject, node.actionProcedure, node.actionOutput].any((field) => vaguePhrases.any((phrase) => field.contains(phrase)))) return false;
    if (fields.any((field) => schemaPlaceholders.any((placeholder) => field.contains(placeholder)))) return false;
    final procedure = node.actionProcedure.trim();
    final hasActionVerb = RegExp(r'打开|进入|新建|填写|写下|发送|拨打|搜索|筛选|下载|上传|朗读|录制|练习|完成|整理|比较|测量|预约|询问|联系|保存|拍照|勾选|运行|修改|创建').hasMatch(procedure);
    final hasAmountOrDuration = RegExp(r'\d+|一份|一个|一条|一次|至少|每个|全部').hasMatch('${node.actionWhen}$procedure${node.acceptanceCriteria}');
    final hasVerifiableOutput = RegExp(r'文件|记录|清单|截图|消息|邮件|录音|视频|表格|文档|结果|数量|链接|日程|产出|完成').hasMatch('${node.actionOutput}${node.acceptanceCriteria}');
    return hasActionVerb && hasAmountOrDuration && hasVerifiableOutput;
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
        referenceCases: '案例A：有人想准备面试但迟迟不动，先只打开简历并标出一处可改内容，发现真正卡点是“不知道岗位要求”，于是转入信息收集。\n案例B：有人想恢复运动，先做2分钟热身而不是完整训练，连续三天后确认启动阻力下降，再逐步增加。',
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
        referenceCases: '案例A：有人想3个月换工作，不先海投，而是先用10分钟保存3个岗位、提炼共同要求，再决定补作品集还是练面试。\n案例B：有人想提升学习成绩，先记录错题类型和复习时间，再判断是知识漏洞、练习不足还是考试策略问题。',
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
        referenceCases: '案例A：有人明天必须交材料，先确认最低可交付版本、截止时间和求助对象，再集中45分钟产出草稿。\n案例B：有人误把模糊焦虑当成紧急期限，核实后发现没有硬截止，于是退回拉伸区，避免用恐慌驱动长期目标。',
        nodes: _fallbackNodes(goalTitle, actionTitle, 'panic'),
      ),
    ];
  }

  List<TodoGoalProblemNode> _fallbackNodes(String goalTitle, String actionTitle, String zone) {
    final difficulty = zone == 'panic' ? 8 : (zone == 'comfort' ? 2 : 5);
    final minutes = zone == 'panic' ? 45 : (zone == 'comfort' ? 2 : 10);
    TodoGoalProblemNode node({
      required String id,
      String parentId = '',
      required String relation,
      required String type,
      required String title,
      required String description,
      required String criteria,
      String action = '',
      String actionWhen = '',
      String actionWhere = '',
      String actionObject = '',
      String actionProcedure = '',
      String actionOutput = '',
      required String question,
      required String facts,
      required String assumptions,
      required String evidence,
      required String rule,
      List<String> dependencies = const <String>[],
      required int order,
      int? duration,
    }) {
      return TodoGoalProblemNode(
        nodeId: '',
        goalId: '',
        solutionId: '',
        parentNodeId: '',
        relationType: relation,
        nodeType: type,
        title: title,
        description: description,
        acceptanceCriteria: criteria,
        actionableStep: action,
        zoneType: zone,
        difficultyScore: difficulty,
        estimatedMinutes: duration ?? minutes,
        sequenceOrder: order,
        dependenciesJson: jsonEncode(dependencies),
        status: 'not_started',
        completionNote: '',
        aiReviewJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        tempNodeId: id,
        tempParentNodeId: parentId,
        logicQuestion: question,
        knownFacts: facts,
        assumptions: assumptions,
        evidenceNeeded: evidence,
        decisionRule: rule,
        actionWhen: actionWhen,
        actionWhere: actionWhere,
        actionObject: actionObject,
        actionProcedure: actionProcedure,
        actionOutput: actionOutput,
      );
    }

    return <TodoGoalProblemNode>[
      node(
        id: 'root',
        relation: 'and',
        type: 'goal_state',
        title: '实现“$goalTitle”的可验证目标状态',
        description: '从当前状态出发，先确认现实差距，再准备必要条件、执行关键动作并验证结果。',
        criteria: '用户确认所有必要子问题均已解决，并出现目标结果要求的现实证据。',
        question: '哪些必要条件全部成立时，“$goalTitle”才算真正实现？',
        facts: '用户已经明确表达目标“$goalTitle”。',
        assumptions: '具体期限、资源、能力基础和目标完成标准仍需用户确认。',
        evidence: '目标结果、时间范围以及用户认可的完成证据。',
        rule: '三个阶段问题都完成后，再由用户评估根问题成功或失败。',
        order: 0,
      ),
      node(
        id: 'baseline',
        parentId: 'root',
        relation: 'sequence',
        type: 'sub_problem',
        title: '确认当前状态与目标差距',
        description: '先取得真实起点，避免根据未确认的信息直接制定方案。',
        criteria: '写清当前状态、目标状态、期限、已有资源和一个主要阻力。',
        question: '当前状态与目标状态之间，最先需要确认的差距是什么？',
        facts: '目前只有目标标题和候选行动可用。',
        assumptions: '候选行动“$actionTitle”与目标存在直接关系，但仍需验证。',
        evidence: '用户填写的现状、期限、资源和阻力记录。',
        rule: '信息足以判断下一步时进入准备阶段；信息不足则继续补充，不虚构结论。',
        order: 1,
      ),
      node(
        id: 'baseline_action',
        parentId: 'baseline',
        relation: 'sequence',
        type: 'action',
        title: '写下目标起点与完成标准',
        description: '这份记录为后续步骤提供已知条件。',
        criteria: '至少写出当前状态、希望达到的状态、期限和一个可观察完成标准。',
        action: '建立一份“$goalTitle 求解记录”，填写当前状态、目标状态、期限和完成证据。',
        actionWhen: '现在或今天第一个不被打断的5分钟；打开手机备忘录后立即开始。',
        actionWhere: '手机备忘录、纸质笔记或电脑文档。',
        actionObject: '目标“$goalTitle”的当前状态、目标状态、期限和完成证据。',
        actionProcedure: '新建标题为“$goalTitle 求解记录”的笔记；依次写四个小标题“现在是、要达到、最晚时间、完成证据”；每个标题下至少写一句。',
        actionOutput: '一份包含四个已填写标题的目标起点记录。',
        question: '这些信息是否足以判断下一步，而不是继续猜测？',
        facts: '目标“$goalTitle”已被提出。',
        assumptions: '用户能够通过简短记录补齐最关键的信息。',
        evidence: '一段包含起点、目标状态、期限和完成标准的文字。',
        rule: '四项信息齐全则成功；缺哪一项就只补哪一项。',
        order: 2,
        duration: zone == 'comfort' ? 2 : 5,
      ),
      node(
        id: 'prepare',
        parentId: 'root',
        relation: 'and',
        type: 'sub_problem',
        title: '准备执行目标所需的最低条件',
        description: '只处理会直接阻止关键行动的条件，不无限准备。',
        criteria: '执行关键行动所必需的工具、材料、时间和环境均达到最低可用状态。',
        question: '缺少哪一个条件会让关键行动无法发生？',
        facts: '候选关键行动是“$actionTitle”。',
        assumptions: '主要阻力可以通过一次最小准备动作降低。',
        evidence: '工具、材料、时间段或协作对象已经就位。',
        rule: '最低条件具备即停止准备并进入执行；非必要准备不继续扩张。',
        dependencies: const <String>['baseline_action'],
        order: 3,
      ),
      node(
        id: 'prepare_action',
        parentId: 'prepare',
        relation: 'sequence',
        type: 'action',
        title: '移除一个最直接的执行阻力',
        description: '只选择当前证据最明确、能立刻处理的一个阻力。',
        criteria: '完成一个能让“$actionTitle”更容易开始的环境、工具或时间安排。',
        action: '从起点记录中选择一个明确阻力，并完成一项可见的准备。',
        actionWhen: '完成目标起点记录后立即进行，最多5分钟。',
        actionWhere: '阻力实际发生的工作位置；使用日历、文件夹或目标所需工具。',
        actionObject: '起点记录中写下的第一个明确阻力。',
        actionProcedure: '圈出一个会阻止下一步的具体障碍；只选择一种处理：把所需工具放到手边、把必要文件打开、或在日历中锁定一个时间段；完成后截图或勾选。',
        actionOutput: '一个已经就位的工具/文件，或一个已保存的具体日程。',
        question: '这个调整是否直接降低了关键行动的开始成本？',
        facts: '起点记录已经指出一个主要阻力。',
        assumptions: '处理该阻力会提高关键行动发生的可能性。',
        evidence: '可看到已准备的工具、材料、日程或环境变化。',
        rule: '阻力被实际移除则成功；没有变化则选择同一父问题下的另一准备动作。',
        dependencies: const <String>['baseline_action'],
        order: 4,
      ),
      node(
        id: 'execute_action',
        parentId: 'prepare',
        relation: 'sequence',
        type: 'action',
        title: '执行一次关键目标动作',
        description: '用一次现实行动验证当前路径能否产生与目标有关的进展。',
        criteria: zone == 'comfort' ? '执行2分钟并留下一个可观察产出。' : '执行5-10分钟并留下一个可观察产出。',
        action: '把“$actionTitle”完成一个可观察的最小片段，并保存产出。',
        actionWhen: zone == 'panic' ? '在已确认的最早可用45分钟时段开始。' : '完成准备动作后，在今天预留的${zone == 'comfort' ? '2' : '10'}分钟内开始。',
        actionWhere: '使用刚刚准备好的工具、文件或实际工作场景。',
        actionObject: '“$actionTitle”中能够独立保存或核对的第一个最小片段。',
        actionProcedure: '打开所需工具；只处理一个最小片段；过程中不扩展到第二项；结束时保存、拍照、录音或勾选完成。',
        actionOutput: '一个与“$actionTitle”直接相关、可保存或查看的最小产出。',
        question: '这次行动是否产生了能推动“$goalTitle”的实际产出？',
        facts: '起点和最低准备条件已经完成。',
        assumptions: '当前候选行动能够产生与目标直接相关的反馈。',
        evidence: '实际耗时、完成产出、遇到的具体阻力和下一步信息。',
        rule: '达到验收标准则进入验证阶段；失败则在同一父问题下选择替代动作，不立即推翻整套方案。',
        dependencies: const <String>['baseline_action', 'prepare_action'],
        order: 5,
      ),
      node(
        id: 'verify',
        parentId: 'root',
        relation: 'dependency',
        type: 'sub_problem',
        title: '验证这条路径是否真的推动目标',
        description: '比较行动前后变化，决定继续、调整或切换备用方案。',
        criteria: '能够根据行动证据说明继续、调整或换路的理由。',
        question: '现有结果支持继续当前路径，还是说明某个前提不成立？',
        facts: '关键行动已产生一次现实结果。',
        assumptions: '一次结果足以决定下一小步，但通常不足以证明整个方案必然有效。',
        evidence: '行动产出、阻力记录和与目标标准的差距变化。',
        rule: '有正向变化则继续；局部失败则换叶节点；关键前提被证伪时再考虑备用方案。',
        dependencies: const <String>['execute_action'],
        order: 6,
      ),
      node(
        id: 'verify_action',
        parentId: 'verify',
        relation: 'sequence',
        type: 'action',
        title: '记录结果并决定下一小步',
        description: '把成功或失败转换成下一次求解信息。',
        criteria: '记录实际结果、与验收标准的差距，以及下一次继续或替换的具体动作。',
        action: '在同一份求解记录中追加本轮结果和下一动作。',
        actionWhen: '关键动作结束后立即进行，限定3分钟。',
        actionWhere: '打开前面创建的“$goalTitle 求解记录”。',
        actionObject: '本轮实际产出、验收结果和遇到的具体阻力。',
        actionProcedure: '追加三行：“实际产出：”“是否达到标准：”“下一次具体动作：”；每行填写一句，下一动作必须包含动词、对象和数量。',
        actionOutput: '一条包含实际产出、验收结论和下一具体动作的复盘记录。',
        question: '这份记录能否明确支持下一次决策？',
        facts: '本轮行动结果已经发生。',
        assumptions: '如实记录能减少重复试错。',
        evidence: '一条包含结果、差距和下一动作的复盘记录。',
        rule: '能明确下一动作则成功；仍无法判断时补一次低成本验证，不直接重构全方案。',
        dependencies: const <String>['execute_action'],
        order: 7,
        duration: 3,
      ),
    ];
  }


  bool _looksLikeSingleProblemPlan(Map<String, dynamic> map) {
    const nodeKeys = <String>{
      'nodes',
      'problemNodes',
      'problem_nodes',
      'problemTree',
      'problem_tree',
      'tree',
      'steps',
      '问题树',
      '问题节点',
      '节点',
      '步骤',
    };
    if (nodeKeys.any(map.containsKey)) return true;
    const planOnlyKeys = <String>{
      'problemDefinition',
      'problem_definition',
      'problemToSolve',
      'problem_to_solve',
      'knownFacts',
      'known_facts',
      'knownBasis',
      'known_basis',
      'keyAssumptions',
      'key_assumptions',
      'referenceCases',
      'reference_cases',
    };
    final planSignals = planOnlyKeys.where(map.containsKey).length;
    return planSignals >= 2 && !_hasMeaningfulAnalysis(map);
  }

  TodoGoalSolutionPlan _repairGeneratedTreePlan({
    required TodoGoalSolutionPlan candidate,
    required TodoGoalSolutionPlan outline,
    required TodoGoalAnalysisResult analysis,
    required String zone,
  }) {
    String firstNonEmpty(List<String> values, [String fallback = '']) {
      for (final value in values) {
        final text = value.trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    final title = firstNonEmpty(<String>[candidate.title, outline.title], '问题解决路径');
    final problemDefinition = firstNonEmpty(<String>[candidate.problemDefinition, outline.problemDefinition, candidate.title, title], '把目标“${analysis.goalTitle}”转化为可验证、可执行、可复盘的现实问题。');
    final knownFacts = firstNonEmpty(<String>[candidate.knownFacts, outline.knownFacts, analysis.coreValues, analysis.processGoal], '已知用户已经确认了目标方向；资源、时间、能力和外部约束仍需通过行动验证。');
    final assumptions = firstNonEmpty(<String>[candidate.keyAssumptions, outline.keyAssumptions, analysis.obstacleSummary], '当前路径只是候选假设，需要用低成本行动验证是否符合真实需要。');
    final evidencePlan = firstNonEmpty(<String>[candidate.evidencePlan, outline.evidencePlan], '记录每个叶节点的产出、耗时、阻力和是否推动父问题成立。');
    final userChoiceGuidance = firstNonEmpty(<String>[candidate.userChoiceGuidance, outline.userChoiceGuidance], '请把这棵树当作待验证的候选路径：先做最底层动作，再根据证据保留、调整或切换。');

    return TodoGoalSolutionPlan(
      solutionId: candidate.solutionId,
      goalId: candidate.goalId,
      sourceTaskId: candidate.sourceTaskId,
      title: title,
      methodName: firstNonEmpty(<String>[candidate.methodName, outline.methodName], '问题树验证法'),
      methodBasis: firstNonEmpty(<String>[candidate.methodBasis, outline.methodBasis], '从目标状态反推必要条件，再用可验收行动验证关键假设。'),
      zoneType: zone,
      coreValueFocus: firstNonEmpty(<String>[candidate.coreValueFocus, outline.coreValueFocus, analysis.coreValues], '尊重用户真实需要，由用户根据证据自行判断。'),
      summary: firstNonEmpty(<String>[candidate.summary, outline.summary], '这是一条候选问题解决路径，用来帮助你从当前状态逐步验证并接近目标状态。'),
      riskNotes: firstNonEmpty(<String>[candidate.riskNotes, outline.riskNotes], '若行动产出不能推动父问题成立，应缩小动作、换替代路径或回到方案比较。'),
      isSelected: candidate.isSelected || outline.isSelected,
      status: candidate.status.trim().isEmpty ? 'candidate' : candidate.status,
      sortOrder: candidate.sortOrder,
      rawJson: candidate.rawJson,
      createdAtMs: candidate.createdAtMs,
      updatedAtMs: candidate.updatedAtMs,
      problemDefinition: problemDefinition,
      knownFacts: knownFacts,
      keyAssumptions: assumptions,
      rootCauseAnalysis: firstNonEmpty(<String>[candidate.rootCauseAnalysis, outline.rootCauseAnalysis], '先不假定唯一根因；用底层行动结果区分信息不足、能力缺口、环境阻力或目标定义问题。'),
      optionComparison: firstNonEmpty(<String>[candidate.optionComparison, outline.optionComparison], '这条路径可先小规模验证；若成本过高或证据不支持，再与其他候选方案比较。'),
      evidencePlan: evidencePlan,
      successMetrics: firstNonEmpty(<String>[candidate.successMetrics, outline.successMetrics], '至少一个叶节点留下可核对产出，并能说明它如何推动父问题。'),
      stopConditions: firstNonEmpty(<String>[candidate.stopConditions, outline.stopConditions], '关键假设被证伪、连续无产出或成本明显超过收益时，暂停并重定义问题。'),
      userChoiceGuidance: userChoiceGuidance,
      referenceCases: firstNonEmpty(<String>[candidate.referenceCases, outline.referenceCases], '案例：有人把“找工作”先拆成岗位信息验证、作品证据和投递反馈三类小实验；另一个人则先确认自己真正想换的是行业、岗位还是工作方式。'),
      nodes: _repairGeneratedTreeNodes(
        candidate.nodes,
        zone: zone,
        planProblem: problemDefinition,
        planFacts: knownFacts,
        planAssumptions: assumptions,
        planEvidence: evidencePlan,
      ),
    );
  }

  List<TodoGoalProblemNode> _repairGeneratedTreeNodes(
    List<TodoGoalProblemNode> nodes, {
    required String zone,
    required String planProblem,
    required String planFacts,
    required String planAssumptions,
    required String planEvidence,
  }) {
    String firstNonEmpty(List<String> values, [String fallback = '']) {
      for (final value in values) {
        final text = value.trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    String normalizedRelation(TodoGoalProblemNode node, bool isRoot) {
      final raw = node.relationType.trim().toLowerCase();
      const allowed = <String>{'and', 'or', 'sequence', 'dependency', 'network'};
      if (allowed.contains(raw)) return raw;
      if (isRoot) return 'and';
      if (node.nodeType.trim().toLowerCase() == 'action' || node.actionProcedure.trim().isNotEmpty) return 'sequence';
      return 'and';
    }

    final repaired = <TodoGoalProblemNode>[];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final isRoot = i == 0 || node.tempParentNodeId.trim().isEmpty && node.parentNodeId.trim().isEmpty;
      final nodeTypeRaw = node.nodeType.trim().toLowerCase();
      final hasActionContract = node.actionWhen.trim().isNotEmpty ||
          node.actionWhere.trim().isNotEmpty ||
          node.actionObject.trim().isNotEmpty ||
          node.actionProcedure.trim().isNotEmpty ||
          node.actionOutput.trim().isNotEmpty ||
          node.actionableStep.trim().isNotEmpty;
      final nodeType = nodeTypeRaw == 'action' || (!isRoot && hasActionContract && node.actionProcedure.trim().isNotEmpty) ? 'action' : (nodeTypeRaw.isEmpty || nodeTypeRaw == 'tree' ? (isRoot ? 'goal_state' : 'sub_problem') : node.nodeType);
      final title = firstNonEmpty(<String>[node.title == '子问题' ? '' : node.title, node.logicQuestion, node.actionableStep], isRoot ? planProblem : '待验证子问题 ${i + 1}');
      final isAction = nodeType.trim().toLowerCase() == 'action';
      final actionWhen = isAction ? firstNonEmpty(<String>[node.actionWhen], '今天打开目标详情页后，预留10分钟') : node.actionWhen;
      final actionWhere = isAction ? firstNonEmpty(<String>[node.actionWhere], '手机或电脑上的当前目标执行入口') : node.actionWhere;
      final actionObject = isAction ? firstNonEmpty(<String>[node.actionObject], '节点“$title”对应的材料、页面或沟通对象') : node.actionObject;
      final actionProcedure = isAction
          ? firstNonEmpty(<String>[node.actionProcedure], '打开执行入口；计时10分钟；完成节点“$title”的第一个可见动作；保存记录或截图')
          : node.actionProcedure;
      final actionOutput = isAction ? firstNonEmpty(<String>[node.actionOutput], '一条记录、截图或完成数量') : node.actionOutput;
      final acceptance = firstNonEmpty(<String>[
        node.acceptanceCriteria == '能用事实判断是否完成' ? '' : node.acceptanceCriteria,
        isAction && actionOutput.trim().isNotEmpty ? '留下$actionOutput，并能判断是否推动父问题' : '',
      ], isRoot ? '所有必要子问题完成后，能用证据判断目标状态是否成立。' : '能用事实判断该子问题是否成立。');
      final actionSummary = isAction ? firstNonEmpty(<String>[node.actionableStep, title], title) : node.actionableStep;
      repaired.add(TodoGoalProblemNode(
        nodeId: node.nodeId,
        goalId: node.goalId,
        solutionId: node.solutionId,
        parentNodeId: node.parentNodeId,
        relationType: normalizedRelation(node, isRoot),
        nodeType: nodeType,
        title: title,
        description: firstNonEmpty(<String>[node.description, title], title),
        acceptanceCriteria: acceptance,
        actionableStep: actionSummary,
        zoneType: zone,
        difficultyScore: node.difficultyScore <= 0 ? 5 : node.difficultyScore.clamp(1, 10).toInt(),
        estimatedMinutes: node.estimatedMinutes <= 0 ? (isAction ? 10 : 5) : node.estimatedMinutes,
        sequenceOrder: node.sequenceOrder == 0 ? i : node.sequenceOrder,
        dependenciesJson: node.dependenciesJson,
        status: node.status.trim().isEmpty ? 'not_started' : node.status,
        completionNote: node.completionNote,
        aiReviewJson: node.aiReviewJson,
        createdAtMs: node.createdAtMs,
        updatedAtMs: node.updatedAtMs,
        tempNodeId: firstNonEmpty(<String>[node.tempNodeId, node.nodeId], isRoot ? 'root' : 'n${i + 1}'),
        tempParentNodeId: isRoot ? '' : node.tempParentNodeId,
        logicQuestion: firstNonEmpty(<String>[node.logicQuestion], isAction ? '这个行动产出是否足以推动父问题成立？' : '这个子问题成立后能否回推父问题？'),
        knownFacts: firstNonEmpty(<String>[node.knownFacts], planFacts),
        assumptions: firstNonEmpty(<String>[node.assumptions], planAssumptions),
        evidenceNeeded: firstNonEmpty(<String>[node.evidenceNeeded, actionOutput], planEvidence),
        decisionRule: firstNonEmpty(<String>[node.decisionRule], isAction ? '达到验收标准则通过；否则记录阻力，并尝试同一父问题下的替代动作。' : '子节点全部达到验收标准后，再判断该父问题是否成立。'),
        actionWhen: actionWhen,
        actionWhere: actionWhere,
        actionObject: actionObject,
        actionProcedure: actionProcedure,
        actionOutput: actionOutput,
      ));
    }
    return repaired;
  }

  bool _isRecoverableTreePlan(TodoGoalSolutionPlan plan) {
    if (plan.nodes.length < 3) return false;
    final ids = <String>{};
    for (final node in plan.nodes) {
      final id = node.tempNodeId.trim();
      if (id.isEmpty || ids.contains(id)) return false;
      ids.add(id);
    }
    final roots = plan.nodes.where((node) => node.tempParentNodeId.trim().isEmpty).toList(growable: false);
    if (roots.isEmpty) return false;
    for (final node in plan.nodes) {
      final parent = node.tempParentNodeId.trim();
      if (parent.isNotEmpty && !ids.contains(parent)) return false;
      for (final dependency in node.resolvedDependencyNodeIds) {
        if (!ids.contains(dependency)) return false;
      }
    }
    return plan.nodes.any((node) => node.isActionable && node.hasConcreteActionContract && _isConcreteActionNode(node));
  }

  List<TodoGoalSolutionPlan> _readPlans(Map<String, dynamic> map) {
    final value = _readDynamic(map, const <String>[
      'solutionPlans',
      'solution_plans',
      'solutionPlan',
      'solution_plan',
      'selectedSolutionPlan',
      'selected_solution_plan',
      'solutions',
      'plans',
      'plan',
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
      if (_looksLikeSingleProblemPlan(value)) {
        addPlan(value, 0);
      } else {
        var i = 0;
        for (final entry in value.entries) {
          addPlan(entry.value, i, fallbackTitle: entry.key);
          i++;
        }
      }
    } else if (value is Map) {
      final converted = Map<String, dynamic>.from(value);
      if (_looksLikeSingleProblemPlan(converted)) {
        addPlan(converted, 0);
      } else {
        var i = 0;
        for (final entry in value.entries) {
          addPlan(entry.value, i, fallbackTitle: entry.key.toString());
          i++;
        }
      }
    }

    if (plans.isEmpty && _looksLikeSingleProblemPlan(map)) {
      addPlan(map, 0);
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

  bool _isConcreteAlternativeStep(TodoGoalAlternativeStep step) {
    final fields = <String>[step.actionWhen, step.actionWhere, step.actionObject, step.actionProcedure, step.actionOutput, step.minimumStandard];
    const placeholders = <String>['具体时间或启动触发', '具体地点、页面或工具', '明确处理对象', '按顺序写出动词', '执行后留下的文件'];
    if (fields.any((field) => field.trim().length < 4 || placeholders.any((placeholder) => field.contains(placeholder)))) return false;
    final hasVerb = RegExp(r'打开|进入|新建|填写|写下|发送|拨打|搜索|筛选|下载|上传|朗读|录制|练习|完成|整理|比较|测量|预约|询问|联系|保存|拍照|勾选|运行|修改|创建').hasMatch(step.actionProcedure);
    final hasAmount = RegExp(r'\d+|一份|一个|一条|一次|至少|每个|全部').hasMatch('${step.actionWhen}${step.actionProcedure}${step.minimumStandard}');
    return hasVerb && hasAmount;
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
    String cleanFence(String input) {
      return input
          .trim()
          .replaceAll(RegExp(r'^```json', multiLine: true), '')
          .replaceAll(RegExp(r'^```', multiLine: true), '')
          .replaceAll(RegExp(r'```$', multiLine: true), '')
          .trim();
    }

    Map<String, dynamic> convert(Object? decoded) {
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is List && decoded.isNotEmpty) {
        final maps = <Map<String, dynamic>>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            maps.add(item);
          } else if (item is Map) {
            maps.add(Map<String, dynamic>.from(item));
          }
        }
        if (maps.isEmpty) return <String, dynamic>{};
        if (maps.length == 1) return maps.first;
        final looksLikeNodeList = maps.every((m) => m.containsKey('id') || m.containsKey('parentId') || m.containsKey('parent_id') || m.containsKey('nodeType') || m.containsKey('node_type') || m.containsKey('actionWhen') || m.containsKey('problemToSolve'));
        return looksLikeNodeList ? <String, dynamic>{'nodes': maps} : <String, dynamic>{'solutionPlans': maps};
      }
      return <String, dynamic>{};
    }

    final initial = cleanFence(raw);
    if (initial.isEmpty) return <String, dynamic>{};
    final candidates = <String>[initial];
    if (initial.contains(r'\"') || initial.contains(r'\n')) {
      candidates.add(cleanFence(initial.replaceAll(r'\"', '"').replaceAll(r'\n', '\n')));
    }

    for (var round = 0; round < 3; round++) {
      final snapshot = List<String>.from(candidates);
      for (final candidate in snapshot) {
        final text = cleanFence(candidate);
        if (text.isEmpty) continue;
        try {
          final decoded = jsonDecode(text);
          if (decoded is String) {
            final inner = cleanFence(decoded);
            if (inner.isNotEmpty && !candidates.contains(inner)) candidates.add(inner);
            continue;
          }
          final converted = convert(decoded);
          if (converted.isNotEmpty) return converted;
        } catch (_) {}
        final start = text.indexOf('{');
        final end = text.lastIndexOf('}');
        if (start >= 0 && end > start) {
          final sliced = text.substring(start, end + 1);
          try {
            final decoded = jsonDecode(sliced);
            if (decoded is String) {
              final inner = cleanFence(decoded);
              if (inner.isNotEmpty && !candidates.contains(inner)) candidates.add(inner);
              continue;
            }
            final converted = convert(decoded);
            if (converted.isNotEmpty) return converted;
          } catch (_) {}
          final unescaped = sliced.replaceAll(r'\"', '"').replaceAll(r'\n', '\n');
          if (unescaped != sliced && !candidates.contains(unescaped)) candidates.add(unescaped);
        }
      }
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
