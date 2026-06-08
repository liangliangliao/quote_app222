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
        prompt: '$prompt\n\n${_deepProblemSolutionSchema()}',
        purpose: 'microsoft_todo.goal_deep_problem_solution',
        systemPrompt: '${templates.systemPrompt}\n你还必须把目标当成用户关注的棘手问题，输出多套科学问题解决方案和可执行问题树。',
        maxTokens: 4200,
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
      final aiPlans = _readPlans(parsed);
      final aiHasMeaningfulContent = _hasMeaningfulAnalysis(parsed);
      if (!aiHasMeaningfulContent && aiPlans.isEmpty) {
        return _analysisFromAiRaw(task, raw, state, fallback);
      }

      final aiDefaults = _analysisFromAiRaw(task, raw, state, fallback, markRawOnly: false);
      final goalTitle = _read(parsed, 'goalTitle', aiDefaults.goalTitle);
      final todayMinimumAction = _read(parsed, 'todayMinimumAction', aiDefaults.todayMinimumAction);
      final actionTitle = todayMinimumAction.trim().isEmpty
          ? (goalTitle.length > 18 ? '${goalTitle.substring(0, 18)}…' : goalTitle)
          : todayMinimumAction;
      // v55: as long as the provider returned usable AI text/fields, do not mark
      // the whole target as local fallback merely because some fields or plans
      // are absent. Fill missing fields with AI-raw-derived safe defaults and
      // only supplement the plan tree locally.
      final effectivePlans = aiPlans.isEmpty ? _fallbackPlans(goalTitle, actionTitle) : aiPlans;

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
        recommendedStandard: _read(parsed, 'recommendedStandard', aiDefaults.recommendedStandard),
        stretchStandard: _read(parsed, 'stretchStandard', aiDefaults.stretchStandard),
        difficultyScore: _readInt(parsed, 'difficultyScore', aiDefaults.difficultyScore).clamp(1, 10).toInt(),
        zoneType: _normalizeZone(_read(parsed, 'zoneType', aiDefaults.zoneType)),
        coachMessage: _read(parsed, 'coachMessage', aiDefaults.coachMessage),
        provider: state['provider'] ?? 'ai',
        solutionPlans: effectivePlans,
        modelLabel: state['label'] ?? 'AI',
        rawResponse: raw,
        usedFallback: false,
      );
    } catch (_) {
      return fallback;
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
1. 为什么这一步成功/失败；成功时提炼可复用条件，失败时指出问题发生在哪个更小环节。
2. 如何重启当前子问题，优先缩小、换路径、换环境、降低阻力，而不是立刻推翻整套方案。
3. 给出3个替代步骤，必须符合目标价值体系：目标服务当下、过程重于抵达、自我和谐、拉伸而非恐慌。
4. 只有在原方案方向明显错误时才提醒可重构整个方案；默认不建议重构，避免功亏一篑。

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
      minimumStandard: _readTextFieldFromRaw(raw, _fieldAliases('minimumStandard'), '只要开始 2-5 分钟，并留下一个事实记录即可。'),
      recommendedStandard: _readTextFieldFromRaw(raw, _fieldAliases('recommendedStandard'), '完成一个清晰小步骤，并记录过程、阻力和下一步。'),
      stretchStandard: _readTextFieldFromRaw(raw, _fieldAliases('stretchStandard'), '状态允许时连续推进 15-25 分钟，并拆出下一个子问题。'),
      difficultyScore: _readIntFromRaw(raw, _fieldAliases('difficultyScore'), 5).clamp(1, 10).toInt(),
      zoneType: _normalizeZone(_readTextFieldFromRaw(raw, _fieldAliases('zoneType'), 'stretch')),
      coachMessage: _readTextFieldFromRaw(
        raw,
        _fieldAliases('coachMessage'),
        '先不要追求一次解决全部问题。把目标拆成今天能开始的最小动作，做完后再根据反馈调整。',
      ),
      provider: state['provider'] ?? 'ai',
      solutionPlans: _fallbackPlans(goalTitle, todayAction),
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
      minimumStandard: '开始5分钟即可；目标的第一作用是让你进入当下，不要求完美完成。',
      recommendedStandard: '完成一个清晰小步骤，并写下一句话：这个过程里有什么值得体验。',
      stretchStandard: '连续推进 25 分钟，并整理出下一步。',
      difficultyScore: 5,
      zoneType: 'stretch',
      coachMessage: '当前是本地兜底结果：先把它变成今天能够开始的一小步；如需真正贴合目标背景的问题树，请检查AI配置后点击“AI重新分析”。',
      provider: provider,
      solutionPlans: _fallbackPlans(title, actionTitle),
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
        title: '舒适区方案：先恢复行动链条',
        methodName: '微行动法 + 行为激活',
        methodBasis: '把问题缩小到能立刻开始的行为单元，先用行动产生反馈，再逐渐提高难度。',
        zoneType: 'comfort',
        coreValueFocus: '目标服务当下；先进入过程，不追求一次完成。',
        summary: '适合状态低、容易逃避、需要重新启动的人。优先建立“我能开始”的证据。',
        riskNotes: '进展较慢，需要避免一直停留在过小动作里。',
        isSelected: false,
        status: 'candidate',
        sortOrder: 0,
        rawJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        nodes: _fallbackNodes(goalTitle, actionTitle, 'comfort'),
      ),
      TodoGoalSolutionPlan(
        solutionId: '',
        goalId: '',
        sourceTaskId: '',
        title: '拉伸区方案：问题树逐层拆解',
        methodName: '问题分解 + 执行意图 + 反馈调节',
        methodBasis: '把大问题拆成父子节点；从底层可执行动作开始，完成后逐层回推到父问题。',
        zoneType: 'stretch',
        coreValueFocus: '自我和谐、过程重于抵达、拉伸而非恐慌。',
        summary: '推荐方案。既不空谈目标，也不直接硬扛结果，而是每天推进一个可验证子节点。',
        riskNotes: '需要按节点复盘；失败时优先换替代步骤，不轻易推翻整套方案。',
        isSelected: false,
        status: 'candidate',
        sortOrder: 1,
        rawJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        nodes: _fallbackNodes(goalTitle, actionTitle, 'stretch'),
      ),
      TodoGoalSolutionPlan(
        solutionId: '',
        goalId: '',
        sourceTaskId: '',
        title: '恐慌区方案：高强度冲刺对照',
        methodName: '限时冲刺 + 外部约束',
        methodBasis: '用明确截止时间和强约束快速推进，但只作为对照方案或短期应急方案。',
        zoneType: 'panic',
        coreValueFocus: '提醒用户识别恐慌区，避免把目标变成压迫。',
        summary: '适合真实紧急且代价明确的场景；默认不推荐长期使用。',
        riskNotes: '容易导致逃避、挫败或反弹；若连续失败，应退回拉伸区方案。',
        isSelected: false,
        status: 'candidate',
        sortOrder: 2,
        rawJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
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
        title: '顶层问题：实现“$goalTitle”',
        description: '把目标视为一个需要被解决的问题，而不是一句口号。',
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
      ),
      TodoGoalProblemNode(
        nodeId: '',
        goalId: '',
        solutionId: '',
        parentNodeId: '',
        relationType: 'tree',
        nodeType: 'sub_problem',
        title: '子问题A：找到今天能开始的入口',
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
      ),
      TodoGoalProblemNode(
        nodeId: '',
        goalId: '',
        solutionId: '',
        parentNodeId: '',
        relationType: 'tree',
        nodeType: 'action',
        title: '底层动作：$actionTitle',
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
      ),
      TodoGoalProblemNode(
        nodeId: '',
        goalId: '',
        solutionId: '',
        parentNodeId: '',
        relationType: 'tree',
        nodeType: 'sub_problem',
        title: '子问题B：复盘并选择下一步',
        description: '根据成功/失败反馈调整动作，不轻易推翻整套方案。',
        acceptanceCriteria: '复盘中至少得到一个替代步骤或下一步。',
        actionableStep: '完成后记录：成功/失败、阻力、下一步替代动作。',
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

  String _deepProblemSolutionSchema() => '''
额外要求：除了原有字段，你必须增加 solutionPlans 数组，至少3个方案：舒适区、拉伸区、恐慌区。
每个方案都要体现不同科学方法，例如问题分解、WOOP/心理对比、执行意图、行为激活、设计思维、反馈调节、风险预案等。
每个方案都必须包含 nodes 数组，用父子节点表达“顶层问题→子问题→更小子问题→底层可执行动作”。
节点之间可以是 tree/linear/network 关系，但必须给 parentId；底层 action 节点必须是用户现实中可直接执行的动作。
未被用户选中的方案会保存为备用方案，因此每个方案都要完整可用。

solutionPlans 的结构：
[
  {
    "title": "方案名称",
    "methodName": "使用的方法",
    "methodBasis": "科学依据/问题解决依据",
    "zoneType": "comfort/stretch/panic",
    "coreValueFocus": "如何体现目标服务当下、过程重于抵达、自我和谐、拉伸而非恐慌",
    "summary": "方案摘要",
    "riskNotes": "风险与适用边界",
    "nodes": [
      {"id":"root", "parentId":"", "relationType":"tree", "nodeType":"problem", "title":"顶层问题", "description":"", "acceptanceCriteria":"", "actionableStep":"", "zoneType":"stretch", "difficultyScore":5, "estimatedMinutes":10, "sequenceOrder":0},
      {"id":"a", "parentId":"root", "relationType":"tree", "nodeType":"sub_problem", "title":"子问题", "description":"", "acceptanceCriteria":"", "actionableStep":"", "zoneType":"stretch", "difficultyScore":4, "estimatedMinutes":8, "sequenceOrder":1},
      {"id":"a1", "parentId":"a", "relationType":"tree", "nodeType":"action", "title":"底层动作", "description":"", "acceptanceCriteria":"", "actionableStep":"具体到时间/地点/对象/动作/完成标准", "zoneType":"stretch", "difficultyScore":3, "estimatedMinutes":5, "sequenceOrder":2}
    ]
  }
]
''';

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
    final text = value == null ? '' : value.toString().trim();
    return text.isEmpty ? fallback : text;
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
