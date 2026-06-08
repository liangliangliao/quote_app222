import 'todo_dao.dart';
import 'todo_goal_value_system.dart';

class TodoGoalPromptConfig {
  TodoGoalPromptConfig({TodoDao? dao}) : _dao = dao ?? TodoDao();

  final TodoDao _dao;

  static const String systemPromptKey = 'todo_goal_ai_system_prompt_v1';
  static const String taskPromptKey = 'todo_goal_ai_task_prompt_v1';
  static const String reviewPromptKey = 'todo_goal_ai_review_prompt_v1';

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
  "deepMeaning": "用现实语言说明它通向哪种生活、能力或身份，并明确今天为什么值得做",
  "desiredIdentity": "我正在成为怎样的人",
  "goalCategory": "工作/学习/健康/关系/成长/生活/其他",
  "goalOriginType": "内在愿望/价值驱动/现实必要/外部压力/焦虑驱动/尚不确定",
  "selfConcordanceScore": 0,
  "processValue": "做今天这一小步时，用户要观察、体验或练习什么，必须可记录",
  "obstacleSummary": "可能让用户无法进入当下行动的阻力",
  "todayMinimumAction": "5分钟内可开始、清晰可观察的动作",
  "minimumStandard": "最低完成标准：足够小，避免恐慌",
  "recommendedStandard": "推荐完成标准：正常拉伸区",
  "stretchStandard": "拉伸挑战：可选，不制造压力",
  "difficultyScore": 5,
  "zoneType": "comfort/stretch/panic",
  "coachMessage": "不要讲道理，只用两三句话告诉用户现在先做什么、为什么只做最低标准也有效"
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
    );
  }

  Future<void> save(TodoGoalPromptTemplates templates) async {
    await _dao.ensureTables();
    await _dao.setSetting(systemPromptKey, templates.systemPrompt.trim().isEmpty ? defaultSystemPrompt : templates.systemPrompt.trim());
    await _dao.setSetting(taskPromptKey, templates.taskPrompt.trim().isEmpty ? defaultTaskPromptTemplate : templates.taskPrompt.trim());
    await _dao.setSetting(reviewPromptKey, templates.reviewPrompt.trim().isEmpty ? defaultReviewPromptTemplate : templates.reviewPrompt.trim());
  }

  Future<void> reset() async {
    await save(const TodoGoalPromptTemplates(
      systemPrompt: defaultSystemPrompt,
      taskPrompt: defaultTaskPromptTemplate,
      reviewPrompt: defaultReviewPromptTemplate,
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
  const TodoGoalPromptTemplates({required this.systemPrompt, required this.taskPrompt, required this.reviewPrompt});

  final String systemPrompt;
  final String taskPrompt;
  final String reviewPrompt;
}
