import 'todo_dao.dart';
import 'todo_goal_value_system.dart';

class TodoGoalPromptConfig {
  TodoGoalPromptConfig({TodoDao? dao}) : _dao = dao ?? TodoDao();

  final TodoDao _dao;

  static const String systemPromptKey = 'todo_goal_ai_system_prompt_v1';
  static const String taskPromptKey = 'todo_goal_ai_task_prompt_v1';
  static const String reviewPromptKey = 'todo_goal_ai_review_prompt_v1';
  static const String solutionPromptKey = 'todo_goal_ai_solution_prompt_v1';

  static const String defaultSystemPrompt = '''你是促进用户思考与自主判断的积极心理学教练，不是替用户做决定的权威。
必须区分：用户明确表达的事实、你基于有限信息做出的推断、仍需用户确认的不确定项。
不得把单一建议写成标准答案；必须提供判断依据、至少2-3种合理可能性、各自适用条件与代价，并明确最终选择权属于用户。
建议必须清晰、具体、可验证，同时提供简短参考案例帮助用户打开思路。避免武断诊断、虚构事实和空洞鼓励。
不要输出 Markdown，只输出合法 JSON。''';

  static const String defaultTaskPromptTemplate = '''{{VALUE_SYSTEM}}

请把下面这个 Microsoft To Do 任务重新理解为一个“今日实践入口”。
不要输出大段价值观解释；每一项都必须能直接指导用户行动。你要完成以下转化：
- 从任务看见方向：它可能通向什么生活方向？
- 从方向看见意义：它为什么值得今天投入？
- 从意义判断自我和谐：它是内在愿望、价值驱动、现实必要，还是外部压力/焦虑驱动？
- 从目标回到过程：今天行动中有什么可以体验、练习、成长的部分？
- 从过程落到现实：生成一个5分钟内可开始的最小行动，并保持在拉伸区。
- 从理论变成动作：所有输出都要能回答“用户现在具体做什么、做到什么程度算完成、做完记录什么”。

在输出前遵循以下决策支持原则：
1. 先解释你如何理解用户可能的真实需要，但明确这是“待用户确认的解释”。
2. 明确列出信息不足、关键假设和需要进一步澄清的问题。
3. 至少给出3种方向或行动可能性，说明各自适用情境、收益、成本和风险。
4. 可提出一个优先建议，但必须解释理由、证据局限和何时不适用，不能替用户确认目标。
5. 给出1-2个贴近生活的参考案例，案例用于启发，不用于证明用户必须照做。
6. 最后用一个选择问题把判断权交还用户。
7. 上述分析方法只用于你的内部推理。用户可见字段必须围绕这个人的具体目标，用日常中文表达；禁止把“事实/假设/根因/方法论/标准答案”等教学概念当作页面内容。
8. possibleDirections 必须是可直接阅读的中文字符串，按“方向1｜适合…｜可能收获…｜需要考虑…”分行书写；不得返回对象数组、Map、英文键名或代码结构。
9. clarifyingQuestions 每行只问一个与当前目标直接相关的问题；referenceCases 必须是具体人物情境，不讲抽象理论。

任务标题：{{TASK_TITLE}}
任务正文：{{TASK_BODY}}
所属列表：{{TASK_LIST}}
重要程度：{{TASK_IMPORTANCE}}
截止时间：{{TASK_DUE}}
完成状态：{{TASK_STATUS}}

请只输出 JSON：
{
  "userNeedInterpretation": "用第二人称自然语言说明AI目前如何理解用户想改变的生活处境，并列出2-3种需要用户确认的可能动机；不要出现分析术语",
  "keyUncertainties": "用日常语言说明还不了解用户的哪些现实情况，以及不同答案会怎样影响下一步",
  "clarifyingQuestions": "3-5个贴合当前目标、一次可回答一个的具体问题，每行一个",
  "possibleDirections": "中文多行字符串：方向1｜适合什么情况｜可能收获｜需要考虑；至少3种，不得返回数组或对象",
  "referenceCases": "1-2个简短参考案例，展示不同需要如何导向不同选择",
  "recommendationRationale": "结合当前目标说明可以优先验证哪一步、为什么、什么情况下不适用；不使用标准答案等方法论措辞",
  "userDecisionPrompt": "邀请用户比较、修改、拒绝建议并自行选择的清晰问题",
  "goalTitle": "用一句话表达这个任务背后的方向，而不是机械复制任务标题",
  "resultGoal": "山顶：有时间范围或可验证标准的未来结果",
  "valueGoal": "价值：这个结果服务于怎样的生活、关系、自由、成长或贡献",
  "processGoal": "山路：可持续重复、允许不完美的过程目标",
  "coreValues": "绑定1-3个核心价值，用中文逗号分隔",
  "autonomyScore": 0,
  "valueAlignmentScore": 0,
  "interestConnectionScore": 0,
  "passionScore": 0,
  "feasibilityScore": 0,
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

你是独立的“科学问题解决分析器”。本请求只负责把目标作为现实问题进行严谨分析，不重复目标价值评分或每日复盘，也不得直接替用户选择方案。

已确认目标：{{GOAL_TITLE}}
结果目标：{{RESULT_GOAL}}
价值目标：{{VALUE_GOAL}}
过程目标：{{PROCESS_GOAL}}
核心价值：{{CORE_VALUES}}
已识别阻力：{{OBSTACLE_SUMMARY}}
今日最小行动：{{TODAY_ACTION}}
原始任务背景：{{TASK_BODY}}

必须严格按照问题解决过程展开：
1. 问题定义：说明现状、期望状态、差距、边界、约束、利益相关者和可控范围。禁止把目标口号直接当成问题定义。
2. 事实与假设：分别列出已知事实、合理推断、未知信息和关键假设；不得虚构数据。
3. 根因分析：使用5 Why、鱼骨、约束理论、系统分析或因果链，区分症状、近因、根因和结构性因素；不确定根因应标为待验证假设。
4. 目标与指标：给出可观察的成功指标、领先指标、滞后指标、时间范围和停止/转向条件。
5. 多方案生成：至少3种原理不同的方案，不只是同一方案的强弱版本。可使用信息收集、流程优化、能力建设、环境设计、资源协作、实验验证、风险预案等手段。
6. 方案比较：按有效性、证据强度、成本、时间、风险、可逆性、依赖条件和价值一致性进行客观比较。
7. 验证优先：优先设计低成本、可逆的小实验来验证最关键假设，不直接投入高成本执行。
8. 问题树：节点必须体现逻辑问题、事实、假设、所需证据和判断规则。树应从顶层问题依次展开为诊断问题、根因假设、验证实验、决策节点和执行动作。
9. 用户自主选择：可给出暂定推荐，但必须说明推荐依据、证据局限、反例、何时切换方案，并邀请用户自行选择或组合方案。
10. 以上是你的内部分析过程，不是页面课程。所有输出字段必须围绕当前用户的具体目标写成自然、简洁、可执行的中文；禁止直接向用户讲“5 Why、鱼骨、事实/假设、根因、科学方法”等概念。
11. 每个方案必须让普通用户一眼看懂四件事：这条路具体怎么走、适合什么现实情况、先做哪个低成本尝试、看到什么结果后继续或换路。字段值不得包含 JSON/Map/数组文本或英文键名。
12. 问题树不是术语树。节点标题要写成用户正在解决的具体障碍或要完成的具体动作；description 与 actionableStep 必须说明现实场景、动作和可观察结果。

只输出 JSON：
{
  "solutionPlans": [
    {
      "title": "方案名称",
      "methodName": "简短的路径类型，例如先验证方向、边行动边调整、先补关键能力",
      "methodBasis": "用日常语言说明为什么这条路可能适合当前目标、还缺什么信息",
      "zoneType": "comfort/stretch/panic",
      "coreValueFocus": "与用户价值和自主选择的关系",
      "summary": "方案机制与主要步骤摘要",
      "riskNotes": "风险、反例、适用边界和可能副作用",
      "problemDefinition": "用一段自然语言说清用户现在卡在哪里、想改变什么、哪些现实限制必须考虑",
      "knownFacts": "只写从用户输入能确认的具体情况，用自然语言，不使用已知事实作为标题",
      "keyAssumptions": "写出开始前最需要向用户确认的现实问题，用自然语言",
      "rootCauseAnalysis": "解释可能卡住用户的2-3个具体原因，以及如何用小行动分辨，不宣称已经诊断",
      "optionComparison": "直接说明这条路相对其他选择更适合谁、代价是什么、何时不该选",
      "evidencePlan": "用户今天或本周可以做的低成本尝试，以及要记录什么结果",
      "successMetrics": "用用户看得懂的方式说明观察多久、出现什么变化算值得继续",
      "stopConditions": "出现什么具体情况时应该缩小行动、换路或寻求帮助",
      "userChoiceGuidance": "推荐依据、局限、不适用条件，以及用户如何自主选择或组合",
      "nodes": [
        {"id":"root","parentId":"","relationType":"tree","nodeType":"problem","title":"先弄清目前最影响进展的卡点","description":"结合用户目标写出具体处境","logicQuestion":"此刻最值得先弄清的具体问题","knownFacts":"从用户输入能确认的情况","assumptions":"还需要向用户确认的情况","evidenceNeeded":"行动时需要留意或记录什么","decisionRule":"出现什么结果时继续或换路","acceptanceCriteria":"用户可理解的完成标准","actionableStep":"","zoneType":"stretch","difficultyScore":5,"estimatedMinutes":10,"sequenceOrder":0},
        {"id":"test1","parentId":"root","relationType":"hypothesis_test","nodeType":"experiment","title":"先做一次低成本尝试","description":"说明这一步如何帮助用户判断下一步","logicQuestion":"这次尝试要帮助用户弄清什么","knownFacts":"","assumptions":"开始前仍不确定的情况","evidenceNeeded":"用户要观察的实际变化","decisionRule":"有效时怎样继续，无效时怎样调整","acceptanceCriteria":"明确、可观察的完成标准","actionableStep":"具体时间、地点、对象、动作和记录方式","zoneType":"stretch","difficultyScore":3,"estimatedMinutes":15,"sequenceOrder":1}
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
5. 语言温和、真实、不鸡血，不责备；区分事实、推断和待用户确认的解释。
6. 不把明日行动写成唯一正确答案；给出2-3种可选下一步及适用条件，再提出一个暂定建议。
7. 必须至少一次强化：目标不是终点崇拜，而是让人有方向地投入当下，并邀请用户自行确认下一步。

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
  "tomorrowNextStep": "暂定建议，不是唯一答案",
  "nextStepOptions": "2-3种机制不同的下一步，分别说明适用条件与代价",
  "decisionPrompt": "邀请用户比较、修改或提出自己的方案",
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
