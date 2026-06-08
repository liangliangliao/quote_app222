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

任务标题：{{TASK_TITLE}}
任务正文：{{TASK_BODY}}
所属列表：{{TASK_LIST}}
重要程度：{{TASK_IMPORTANCE}}
截止时间：{{TASK_DUE}}
完成状态：{{TASK_STATUS}}

请只输出 JSON：
{
  "userNeedInterpretation": "对用户可能真正需要的2-4种解释，明确哪些是事实、哪些是推断，并提示待用户确认",
  "keyUncertainties": "当前缺失的信息、关键假设以及这些不确定性为何会影响判断",
  "clarifyingQuestions": "3-5个帮助用户澄清需要、价值、代价和现实条件的问题",
  "possibleDirections": "至少3种可选方向；每种说明适用条件、可能收益、成本风险，不替用户选择",
  "referenceCases": "1-2个简短参考案例，展示不同需要如何导向不同选择",
  "recommendationRationale": "一个暂定优先建议及其依据、局限、反例和不适用条件；明确不是标准答案",
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

只输出 JSON：
{
  "solutionPlans": [
    {
      "title": "方案名称",
      "methodName": "主要科学方法",
      "methodBasis": "方法为何适用于当前问题以及证据局限",
      "zoneType": "comfort/stretch/panic",
      "coreValueFocus": "与用户价值和自主选择的关系",
      "summary": "方案机制与主要步骤摘要",
      "riskNotes": "风险、反例、适用边界和可能副作用",
      "problemDefinition": "现状、期望状态、差距、边界、约束、利益相关者、可控范围",
      "knownFacts": "仅列输入中可确认的事实，并与推断分开",
      "keyAssumptions": "需要验证的关键假设及错误时的后果",
      "rootCauseAnalysis": "症状、近因、候选根因、因果链和不确定性",
      "optionComparison": "与其他方案在有效性、成本、时间、风险、可逆性和依赖条件上的比较",
      "evidencePlan": "先收集什么信息、做什么低成本实验、如何减少不确定性",
      "successMetrics": "领先/滞后指标、观察周期和成功阈值",
      "stopConditions": "何时停止、降级、换方案或寻求专业帮助",
      "userChoiceGuidance": "推荐依据、局限、不适用条件，以及用户如何自主选择或组合",
      "nodes": [
        {"id":"root","parentId":"","relationType":"tree","nodeType":"problem","title":"顶层现实问题","description":"问题边界与差距","logicQuestion":"必须回答的核心问题","knownFacts":"节点相关事实","assumptions":"待验证假设","evidenceNeeded":"需要收集的数据或观察","decisionRule":"根据什么证据进入哪个分支","acceptanceCriteria":"可验证标准","actionableStep":"","zoneType":"stretch","difficultyScore":5,"estimatedMinutes":10,"sequenceOrder":0},
        {"id":"test1","parentId":"root","relationType":"hypothesis_test","nodeType":"experiment","title":"验证关键假设","description":"低成本可逆实验","logicQuestion":"该假设是否成立","knownFacts":"","assumptions":"待验证假设","evidenceNeeded":"可观察结果","decisionRule":"达到阈值则继续，否则切换方案","acceptanceCriteria":"明确阈值","actionableStep":"具体时间、地点、对象、动作和记录方式","zoneType":"stretch","difficultyScore":3,"estimatedMinutes":15,"sequenceOrder":1}
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
