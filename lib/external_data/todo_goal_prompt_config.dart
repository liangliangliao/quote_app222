import 'todo_dao.dart';
import 'todo_goal_value_system.dart';

class TodoGoalPromptConfig {
  TodoGoalPromptConfig({TodoDao? dao}) : _dao = dao ?? TodoDao();

  final TodoDao _dao;

  static const String systemPromptKey = 'todo_goal_ai_system_prompt_v1';
  static const String taskPromptKey = 'todo_goal_ai_task_prompt_v1';
  static const String reviewPromptKey = 'todo_goal_ai_review_prompt_v1';
  static const String solutionPromptKey = 'todo_goal_ai_solution_prompt_v1';

  static const String defaultSystemPrompt = '''你是积极心理学行动教练。
不要讲抽象理论，不要输出 Markdown。
必须把目标价值体系落实成用户今天能做的动作：看见方向、判断来源、体验过程、开始5分钟、复盘下一步。
请只输出合法 JSON。''';

  static const String defaultTaskPromptTemplate = '''{{VALUE_SYSTEM}}

请把下面这个 Microsoft To Do 任务重新理解为一个“今日实践入口”。
不要输出大段价值观解释；每一项都必须能直接指导用户行动。你要完成以下转化：
- 从任务看见方向：它可能通向什么生活方向？
- 从方向看见意义：它为什么值得今天投入？
- 从意义判断自我和谐：它是内在愿望、价值驱动、现实必要，还是外部压力/焦虑驱动？
- 从目标回到过程：今天行动中有什么可以体验、练习、成长的部分？
- 从过程落到现实：生成一个5分钟内可开始的最小行动，并保持在拉伸区。
- 从理论变成动作：所有输出都要能回答“用户现在具体做什么、做到什么程度算完成、做完记录什么”。

任务标题：{{TASK_TITLE}}
任务正文：{{TASK_BODY}}
所属列表：{{TASK_LIST}}
重要程度：{{TASK_IMPORTANCE}}
截止时间：{{TASK_DUE}}
完成状态：{{TASK_STATUS}}

请只输出 JSON：
{
  "goalTitle": "用一句话表达这个任务背后的方向，而不是机械复制任务标题",
  "resultGoal": "山顶：有时间范围或可验证标准的未来结果",
  "valueGoal": "价值：这个结果服务于怎样的生活、关系、自由、成长或贡献",
  "processGoal": "山路：可持续重复、允许不完美的过程目标",
  "coreValues": "绑定1-3个核心价值，用中文逗号分隔",
  "autonomyScore": 0,
  "valueAlignmentScore": 0,
  "interestConnectionScore": 0,
  "passionScore": 0,
  "externalPressureScore": 0,
  "processHappinessScore": 0,
  "goalType": "自我一致目标/外部压力目标/结果焦虑型目标/过程缺失型目标/模糊愿望型目标/可行动目标/需要重写目标",
  "currentStage": "当前所处的现实阶段",
  "deepMeaning": "用现实语言说明它通向哪种生活、能力或身份，并明确今天为什么值得做",
  "desiredIdentity": "我正在成为怎样的人",
  "goalCategory": "工作/学习/健康/关系/成长/生活/其他",
  "goalOriginType": "内在愿望/价值驱动/现实必要/外部压力/焦虑驱动/尚不确定",
  "selfConcordanceScore": 0,
  "processValue": "做今天这一小步时，用户要观察、体验或练习什么，必须可记录",
  "obstacleSummary": "可能让用户无法进入当下行动的阻力",
  "todayMinimumAction": "结果型行动：5分钟内可开始、清晰可观察、直接推进结果的动作",
  "processAction": "过程型行动：让用户在主行动中体验学习、投入、勇气或掌控感的动作",
  "valueAction": "价值型行动：用一句话或一个微行动把今天与核心价值连接起来",
  "experiencePrompt": "今天做这件事时，你想体验什么？只问一个具体、可回答的问题",
  "actionPlace": "最容易开始的具体地点或场景",
  "startTrigger": "看到什么或打开什么后立即开始",
  "completionQuestion": "行动后用于提炼意义的一个问题",
  "minimumStandard": "最低版：2分钟也能完成，只证明可以开始",
  "simplifiedStandard": "简化版：5-10分钟，状态一般时仍能完成",
  "recommendedStandard": "标准版：正常状态下的清晰完成标准",
  "stretchStandard": "挑战版：状态允许时可选，不制造压力",

  "difficultyScore": 5,
  "zoneType": "comfort/stretch/panic",
  "coachMessage": "不要讲道理，只用两三句话告诉用户现在先做什么、为什么只做最低标准也有效"
}
''';


  static const String defaultSolutionPromptTemplate = '''{{VALUE_SYSTEM}}

你是独立的“目标问题解决方案设计器”。本请求只负责生成问题解决方案，不再重复执行目标澄清、自我一致性评分或每日复盘。

已确认目标：{{GOAL_TITLE}}
结果目标：{{RESULT_GOAL}}
价值目标：{{VALUE_GOAL}}
过程目标：{{PROCESS_GOAL}}
核心价值：{{CORE_VALUES}}
已识别阻力：{{OBSTACLE_SUMMARY}}
今日最小行动：{{TODAY_ACTION}}
原始任务背景：{{TASK_BODY}}

请生成至少3个相互独立、完整可用的方案：舒适区、拉伸区、恐慌区。方案可使用问题分解、WOOP/心理对比、执行意图、行为激活、设计思维、反馈调节或风险预案等方法。
每个方案必须包含 nodes，用父子节点表达“顶层问题→子问题→更小子问题→底层可执行动作”。底层 action 必须具体到时间、地点、对象、动作与完成标准。
只输出 JSON：
{
  "solutionPlans": [
    {
      "title": "方案名称",
      "methodName": "科学方法",
      "methodBasis": "方法依据",
      "zoneType": "comfort/stretch/panic",
      "coreValueFocus": "如何保持自我一致并重视过程",
      "summary": "方案摘要",
      "riskNotes": "风险与适用边界",
      "nodes": [
        {"id":"root", "parentId":"", "relationType":"tree", "nodeType":"problem", "title":"顶层问题", "description":"", "acceptanceCriteria":"", "actionableStep":"", "zoneType":"stretch", "difficultyScore":5, "estimatedMinutes":10, "sequenceOrder":0},
        {"id":"a", "parentId":"root", "relationType":"tree", "nodeType":"action", "title":"底层动作", "description":"", "acceptanceCriteria":"", "actionableStep":"具体行动", "zoneType":"stretch", "difficultyScore":3, "estimatedMinutes":5, "sequenceOrder":1}
      ]
    }
  ]
}
''';

  static const String defaultReviewPromptTemplate = '''{{VALUE_SYSTEM}}

请根据用户今日目标行动记录生成积极心理学取向的复盘。
要求：
1. 强调真实行动，而不是只看结果。
2. 必须帮用户看见“过程本身的价值”，不要只看完成率。
3. 将微小行动和长期方向连接起来，说明它如何让用户更投入今天。
4. 给出明天5分钟内可开始的最小一步。
5. 语言温和、真实、不鸡血，不责备。
6. 必须至少一次强化：目标不是终点崇拜，而是让人有方向地投入当下。

目标：{{GOAL_TITLE}}
深层意义：{{DEEP_MEANING}}
过程价值：{{PROCESS_VALUE}}
今日行动：{{ACTION_TITLE}}
完成情况：{{COMPLETED_TEXT}}
用户复盘：{{USER_REFLECTION}}

请只输出 JSON：
{
  "summary": "",
  "processInsight": "",
  "meaningConnection": "",
  "tomorrowNextStep": "",
  "encouragement": ""
}
''';

  Future<TodoGoalPromptTemplates> load() async {
    await _dao.ensureTables();
    return TodoGoalPromptTemplates(
      systemPrompt: await _dao.getSetting(systemPromptKey, defaultValue: defaultSystemPrompt),
      taskPrompt: await _dao.getSetting(taskPromptKey, defaultValue: defaultTaskPromptTemplate),
      reviewPrompt: await _dao.getSetting(reviewPromptKey, defaultValue: defaultReviewPromptTemplate),
      solutionPrompt: await _dao.getSetting(solutionPromptKey, defaultValue: defaultSolutionPromptTemplate),
    );
  }

  Future<void> save(TodoGoalPromptTemplates templates) async {
    await _dao.ensureTables();
    await _dao.setSetting(systemPromptKey, templates.systemPrompt.trim().isEmpty ? defaultSystemPrompt : templates.systemPrompt.trim());
    await _dao.setSetting(taskPromptKey, templates.taskPrompt.trim().isEmpty ? defaultTaskPromptTemplate : templates.taskPrompt.trim());
    await _dao.setSetting(reviewPromptKey, templates.reviewPrompt.trim().isEmpty ? defaultReviewPromptTemplate : templates.reviewPrompt.trim());
    await _dao.setSetting(solutionPromptKey, templates.solutionPrompt.trim().isEmpty ? defaultSolutionPromptTemplate : templates.solutionPrompt.trim());
  }

  Future<void> reset() async {
    await save(const TodoGoalPromptTemplates(
      systemPrompt: defaultSystemPrompt,
      taskPrompt: defaultTaskPromptTemplate,
      reviewPrompt: defaultReviewPromptTemplate,
      solutionPrompt: defaultSolutionPromptTemplate,
    ));
  }

  String renderTaskPrompt(TodoGoalPromptTemplates templates, {
    required String taskTitle,
    required String taskBody,
    required String taskList,
    required String taskImportance,
    required String taskDue,
    required String taskStatus,
  }) {
    return _render(templates.taskPrompt, <String, String>{
      'VALUE_SYSTEM': todoGoalValueSystemPromptBlock(),
      'TASK_TITLE': taskTitle,
      'TASK_BODY': taskBody.trim().isEmpty ? '无' : taskBody,
      'TASK_LIST': taskList,
      'TASK_IMPORTANCE': taskImportance,
      'TASK_DUE': taskDue.trim().isEmpty ? '无' : taskDue,
      'TASK_STATUS': taskStatus,
    });
  }

  String renderSolutionPrompt(
    TodoGoalPromptTemplates templates, {
    required String goalTitle,
    required String resultGoal,
    required String valueGoal,
    required String processGoal,
    required String coreValues,
    required String obstacleSummary,
    required String todayAction,
    required String taskBody,
  }) {
    return _render(templates.solutionPrompt, <String, String>{
      'VALUE_SYSTEM': todoGoalValueSystemPromptBlock(),
      'GOAL_TITLE': goalTitle,
      'RESULT_GOAL': resultGoal,
      'VALUE_GOAL': valueGoal,
      'PROCESS_GOAL': processGoal,
      'CORE_VALUES': coreValues,
      'OBSTACLE_SUMMARY': obstacleSummary,
      'TODAY_ACTION': todayAction,
      'TASK_BODY': taskBody.trim().isEmpty ? '无' : taskBody,
    });
  }

  String renderReviewPrompt(TodoGoalPromptTemplates templates, {
    required String goalTitle,
    required String deepMeaning,
    required String processValue,
    required String actionTitle,
    required bool completed,
    required String userReflection,
  }) {
    return _render(templates.reviewPrompt, <String, String>{
      'VALUE_SYSTEM': todoGoalValueSystemPromptBlock(),
      'GOAL_TITLE': goalTitle,
      'DEEP_MEANING': deepMeaning,
      'PROCESS_VALUE': processValue,
      'ACTION_TITLE': actionTitle,
      'COMPLETED_TEXT': completed ? '已完成' : '未完成或部分完成',
      'USER_REFLECTION': userReflection.trim().isEmpty ? '用户未填写，请根据行动给出简短复盘。' : userReflection.trim(),
    });
  }

  String _render(String template, Map<String, String> values) {
    var out = template;
    for (final entry in values.entries) {
      out = out.replaceAll('{{${entry.key}}}', entry.value);
    }
    return out;
  }
}

class TodoGoalPromptTemplates {
  const TodoGoalPromptTemplates({required this.systemPrompt, required this.taskPrompt, required this.reviewPrompt, required this.solutionPrompt});

  final String systemPrompt;
  final String taskPrompt;
  final String reviewPrompt;
  final String solutionPrompt;
}
