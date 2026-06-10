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
你同时遵循 ChangePath 改变教练原则：真实承认 → 模式识别 → 阻力判断 → 行动设计 → 复盘强化。不要使用“马上逆袭、彻底改变、从此不再”等 quick fix 语言；不要把未完成归因于意志力；必须识别旧模式想保护的正面价值，并把行动校准在 4-6 分拉伸区。每次分析最终都必须落到现实行动、最低完成标准、失败预案和自我证据问题。
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

必须严格按照“证明题式问题求解”展开。目标不是生成鼓励性说辞，而是给出可检查的结论和从已知条件推导到结论的完整过程：
1. 明确待求：把结果目标改写成可验证的目标状态，写清当前状态、目标状态、差距、时间边界与完成判据。
2. 锁定已知条件：只能把用户输入、To Do 字段和已确认目标信息作为事实。凡未提供的数据、能力、资源、心理原因和外部环境，一律列为未知或待验证条件，禁止补写成事实。
3. 建立求解条件：列出实现目标所必需的条件，并说明每个条件为什么必要；区分必要条件、可选条件、约束和风险边界。
4. 构造推导链：从目标状态反向推导必须先解决的父问题，再把父问题递归分解为子问题，直到叶节点成为用户可在现实中直接执行且可验收的动作。
5. 每一步必须有依据：每个节点都要写清它解决什么、由哪些已知条件或前置节点支持、完成后如何推动父问题、如何验收；不能出现与父问题没有推导关系的通用建议。
6. 使用合适关系：
   - sequence：必须按顺序完成；
   - and：多个子问题必须全部解决，父问题才成立；
   - or：多个替代路径任一成立即可；
   - dependency：除父子关系外还依赖其他节点，用 dependencies 引用节点 id；
   - network：存在交叉依赖时使用网状关系，不得强行画成单一路径。
7. 生成至少3个原理不同的完整方案，而不是同一方案只改变强度：例如信息验证、能力建设、流程/环境重构、资源协作、风险控制等。每个方案标注舒适区、拉伸区或恐慌区，并客观比较有效性、成本、时间、风险、可逆性和适用条件。
8. 每个方案都必须从初始状态覆盖到目标状态，至少包含3个层级和6个节点；至少2个叶节点必须是可执行动作。非叶节点不可伪装成行动。
   每个行动叶节点必须分别填写以下字段，任何一项都不能省略或用“视情况、适当、相关、进一步、做一些”等模糊词代替：
   - actionWhen：具体日期/时段，或可观察的启动触发；
   - actionWhere：具体地点、软件、页面、设备或工具；
   - actionObject：要处理的具体人、材料、文件、题目、身体动作或其他对象；
   - actionProcedure：按顺序写出的实际操作，至少包含动词、对象和数量/时长；
   - actionOutput：执行后必须留下的文件、记录、消息、录音、完成数量或其他可核对产出；
   - acceptanceCriteria：用户如何根据数量、质量或状态直接判断成功/失败。
   actionableStep 只是这些字段的一句话摘要，不能替代以上结构化字段。
9. 根节点代表目标问题；中间节点代表阶段状态、必要条件、决策或子问题；叶节点代表直接行动。所有节点必须能沿父子或依赖关系回推到根节点，禁止孤立节点、循环依赖和无依据跳步。
10. 对未知原因先设计低成本验证节点，再根据结果进入不同分支；不能直接断言用户缺乏能力、存在心理问题或某方法必然有效。
11. 给出清晰答案：summary 要说明该方案如何从当前状态推进到目标状态；userChoiceGuidance 要说明在什么现实条件下选它，不能替用户决定。
12. 用户选择主方案后，未选方案保留为备用；节点失败时优先在同一父问题下换叶节点、替代路径或备用方案。只有关键前提被证伪且局部修复无效时，才建议重构整套方案。
13. 如果输入信息不足以生成目标领域内的具体行动，不得猜测。此时叶节点必须改为具体的信息获取动作，例如打开哪个页面、询问谁、记录哪些字段、产出什么清单；获得信息后再进入后续求解分支。
14. 以上严谨结构用于系统求解和校验。用户可见文字仍要围绕具体目标，使用清楚的日常中文，不输出空泛理论课程、虚构案例或无法验证的断言。
只输出 JSON：
{
  "solutionPlans": [
    {
      "title": "方案名称",
      "methodName": "简短的路径类型，例如先验证方向、边行动边调整、先补关键能力",
      "methodBasis": "用日常语言说明为什么这条路可能适合当前目标、还缺什么信息",
      "zoneType": "comfort/stretch/panic",
      "coreValueFocus": "与用户价值和自主选择的关系",
      "summary": "明确答案：说明如何从当前状态经过哪些关键中间状态到达目标状态",
      "riskNotes": "风险、反例、适用边界和可能副作用",
      "problemDefinition": "待求问题：当前状态、目标状态、差距、边界、约束与完成判据",
      "knownFacts": "已知条件：仅限输入中可确认的事实；不得把推测写成事实",
      "keyAssumptions": "未知条件与待验证前提，以及前提错误会影响哪一步推导",
      "rootCauseAnalysis": "候选原因、推导依据、相互关系和对应验证节点；不宣称未经验证的根因",
      "optionComparison": "直接说明这条路相对其他选择更适合谁、代价是什么、何时不该选",
      "evidencePlan": "优先验证哪些未知条件、由哪个节点验证、记录什么结果以及如何影响后续分支",
      "successMetrics": "用用户看得懂的方式说明观察多久、出现什么变化算值得继续",
      "stopConditions": "出现什么具体情况时应该缩小行动、换路或寻求帮助",
      "userChoiceGuidance": "推荐依据、局限、不适用条件，以及用户如何自主选择或组合",
      "nodes": [
        {"id":"root","parentId":"","relationType":"and","nodeType":"goal_state","title":"达到可验证的目标状态","description":"当前状态→关键中间状态→目标状态的完整求解结论","logicQuestion":"哪些必要条件全部成立时，目标才算实现","knownFacts":"仅写输入中确认的信息","assumptions":"尚未确认的前提","evidenceNeeded":"最终结果证据","decisionRule":"所有必要子问题完成后，用户评估根问题成功或失败","acceptanceCriteria":"明确的目标完成判据","actionableStep":"","dependencies":[],"zoneType":"stretch","difficultyScore":5,"estimatedMinutes":10,"sequenceOrder":0},
        {"id":"condition1","parentId":"root","relationType":"sequence","nodeType":"sub_problem","title":"解决一个实现目标所必需的具体条件","description":"说明该条件为何是根问题的必要组成部分","logicQuestion":"这个条件不成立时，目标为什么无法实现","knownFacts":"支持该子问题的已知条件","assumptions":"需要验证的未知条件","evidenceNeeded":"该中间状态的证据","decisionRule":"子节点全部完成后再评估此父节点","acceptanceCriteria":"中间状态的可验证标准","actionableStep":"","dependencies":[],"zoneType":"stretch","difficultyScore":4,"estimatedMinutes":10,"sequenceOrder":1},
        {"id":"action1","parentId":"condition1","relationType":"sequence","nodeType":"action","title":"完成一个不可再分的现实动作","description":"说明动作产出如何直接解决父问题","logicQuestion":"该产出是否足以推动父问题成立","knownFacts":"执行动作所需且已确认的条件","assumptions":"动作将验证的前提","evidenceNeeded":"可观察产出","decisionRule":"达到验收标准则成功，否则进入同父问题的替代步骤","acceptanceCriteria":"明确数量、质量或可观察结果","actionableStep":"一句话行动摘要","actionWhen":"具体时间或启动触发","actionWhere":"具体地点、软件页面或工具","actionObject":"明确处理对象","actionProcedure":"按顺序说明动词、对象、数量或时长","actionOutput":"执行后留下的可核对产出","dependencies":[],"zoneType":"stretch","difficultyScore":3,"estimatedMinutes":15,"sequenceOrder":2}
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
