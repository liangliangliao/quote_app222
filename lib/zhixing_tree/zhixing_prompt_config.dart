import '../data/kv_dao.dart';

class ZxPromptConfig {
  static const String actionPromptKey = 'zhixing_action_prompt_v1';
  static const String expansionPromptKey = 'zhixing_expansion_prompt_v1';
  static const String assistantPromptKey = 'zhixing_assistant_prompt_v3';

  static const String defaultActionPrompt = '''
你是“知行树”的表达增强器。安全、诊断、思想匹配、难度、证据定位和奖励已由本地确定性规则完成，你无权修改它们。

你只可把本地主动作改写得更清楚、更具体。必须：
1. 保留同一个目标行为、障碍机制、难度与风险级别；
2. 只写用户可控制、可观察、可停止的一个主动作；
3. 不承诺结果，不替用户、第三方或专业人员作决定；
4. 不新增知识论断，不伪造证据定位；
5. 输出严格 JSON：{"main_action":"...","lower_load_alternative":"...","challenge_alternative":"..."}。
''';

  static const String defaultExpansionPrompt = '''
你是知识库扩展候选整理器。你的输出永远只是“候选”，不得进入核心知识、行动、安全或奖励引擎。
根据已明确的知识缺口，返回严格 JSON：
{"gap":"...","concept":"...","thinker":"...","work":"...","source_uri":"...","added_value":"...","risks":"..."}。
若无法给出可核查的一手或权威来源，source_uri 留空并在 risks 说明。不得虚构书目、页码或研究结论。
''';

  static const String defaultAssistantPrompt = '''
你是“知行树·智能行动成长”的模块助手。你的职责是教用户完成产品内已有流程，并把复杂概念解释成下一步可操作动作。

必须遵守：
1. 只依据随请求提供的“功能地图、当前状态、本地知识摘要”回答，不得虚构按钮、页面、服务商能力或用户行动结果；
2. 优先给一个最短可执行路径，再按需解释是什么、为什么、怎么做；
3. 用户不知道从哪开始时，引导到“现在做”：一个目标/问题 + 一个卡点即可，思想由系统先推荐；
4. 用户报告未完成时，不羞辱、不伪装完成；帮助缩小负荷、找到现实障碍并进入复盘；
5. 审核本地知识与AI派生知识必须清楚区分；AI内容不能覆盖核心知识、安全或奖励规则；
6. 涉及即时危险、严重功能风险或专业决策时，只解释产品安全边界并建议现实支持，不生成普通行动指令；
7. 回答简洁、具体，结尾给出一个可点击入口名称。不要输出JSON。
''';

  final KeyValueDao _kv = KeyValueDao();

  Future<String> actionPrompt() => _get(actionPromptKey, defaultActionPrompt);

  Future<String> expansionPrompt() =>
      _get(expansionPromptKey, defaultExpansionPrompt);

  Future<String> assistantPrompt() =>
      _get(assistantPromptKey, defaultAssistantPrompt);

  Future<void> saveActionPrompt(String value) =>
      _save(actionPromptKey, value, defaultActionPrompt);

  Future<void> saveExpansionPrompt(String value) =>
      _save(expansionPromptKey, value, defaultExpansionPrompt);

  Future<void> saveAssistantPrompt(String value) =>
      _save(assistantPromptKey, value, defaultAssistantPrompt);

  Future<void> reset() async {
    await _kv.setString(actionPromptKey, defaultActionPrompt);
    await _kv.setString(expansionPromptKey, defaultExpansionPrompt);
    await _kv.setString(assistantPromptKey, defaultAssistantPrompt);
  }

  Future<String> _get(String key, String fallback) async {
    final saved = ((await _kv.getString(key)) ?? '').trim();
    return saved.isEmpty ? fallback : saved;
  }

  Future<void> _save(String key, String value, String fallback) =>
      _kv.setString(key, value.trim().isEmpty ? fallback : value.trim());
}
