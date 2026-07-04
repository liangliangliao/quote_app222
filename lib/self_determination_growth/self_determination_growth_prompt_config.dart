import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

class SelfDeterminationGrowthPromptConfig {
  static const String moduleId = 'self_determination_growth';
  static const String moduleName = '自我决定成长系统 · SDT Growth';

  static const String globalId = 'sdg_global';
  static const String sceneGoalId = 'sdg_scene_goal_setting';
  static const String sceneProcrastinationId = 'sdg_scene_procrastination';
  static const String sceneRelationshipId = 'sdg_scene_relationship_boundary';
  static const String sceneFailureId = 'sdg_scene_failure_recovery';
  static const String sceneTemptationId = 'sdg_scene_temptation_review';
  static const String sceneConfusionId = 'sdg_scene_goal_confusion';
  static const String needsRadarId = 'sdg_feature_needs_radar';
  static const String goalReviewId = 'sdg_feature_goal_content_review';
  static const String motivationId = 'sdg_feature_motivation_spectrum';
  static const String internalizationId = 'sdg_feature_internalization_workbench';
  static const String minActionId = 'sdg_feature_min_action_ability_tree';
  static const String relationshipMapId = 'sdg_feature_relationship_map';
  static const String environmentId = 'sdg_feature_environment_redesign';
  static const String adversityGameId = 'sdg_feature_adversity_game';
  static const String narrativeId = 'sdg_feature_growth_narrative';
  static const String weeklyReportId = 'sdg_report_weekly';
  static const String outputId = 'sdg_output_standard';
  static const String safetyId = 'sdg_safety_ethics';
  static const String jsonRepairId = 'sdg_json_repair';

  static const List<String> allIds = <String>[
    globalId,
    sceneGoalId,
    sceneProcrastinationId,
    sceneRelationshipId,
    sceneFailureId,
    sceneTemptationId,
    sceneConfusionId,
    needsRadarId,
    goalReviewId,
    motivationId,
    internalizationId,
    minActionId,
    relationshipMapId,
    environmentId,
    adversityGameId,
    narrativeId,
    weeklyReportId,
    outputId,
    safetyId,
    jsonRepairId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    sceneGoalId: '场景：用户设定目标',
    sceneProcrastinationId: '场景：用户拖延',
    sceneRelationshipId: '场景：被影响/干扰/羞辱/控制',
    sceneFailureId: '场景：失败后自责',
    sceneTemptationId: '场景：沉迷诱惑',
    sceneConfusionId: '场景：目标迷茫',
    needsRadarId: '功能：三大心理需要雷达',
    goalReviewId: '功能：目标内容审查',
    motivationId: '功能：动机光谱分析器',
    internalizationId: '功能：目标内化工作台',
    minActionId: '功能：最小行动与能力树',
    relationshipMapId: '功能：关系感与边界系统',
    environmentId: '功能：环境改造系统',
    adversityGameId: '功能：逆境之路游戏化系统',
    narrativeId: '功能：成长叙事与身份整合',
    weeklyReportId: '报告：每周成长报告',
    outputId: '输出格式：标准结构',
    safetyId: '安全伦理边界',
    jsonRepairId: '异常恢复：JSON 修复',
  };

  static const Map<String, String> _defaults = <String, String>{
    globalId: '''你是一个基于 Richard M. Ryan 与 Edward L. Deci《Self-Determination Theory: Basic Psychological Needs in Motivation, Development, and Wellness》的 AI 成长教练。你的核心任务不是控制、羞辱、催促或强迫用户完成任务，而是帮助用户满足自主感、胜任感和关系感三大基本心理需要，提升动机质量，并把外在目标逐步内化为用户真正认同的价值和身份。必须避免“你必须、你应该、你怎么又失败了、别人都能做到”这类控制性语言。失败不是人格缺陷，而是系统反馈。''',
    sceneGoalId: '当用户输入目标时，请分析：表层目标、深层心理需要、内在/外在目标成分、自主/胜任/关系评分、动机类型、羞耻/恐惧/报复/外部评价驱动、自主整合型重构、最小行动、能力树、失败恢复方式和身份整合句。用户目标：{{user_goal}}。原因：{{user_reason}}。身份连接：{{identity_link}}。',
    sceneProcrastinationId: '当用户拖延或不想行动时，不要说“你要自律”。请判断目标是否认同、任务是否过大、是否有外部控制压力、内摄压力、关系支持不足、环境诱惑过强，并给出 3 个可选最小行动、自主支持承诺和失败恢复方式。用户输入：{{user_input}}。',
    sceneRelationshipId: '当用户被别人一句话、眼神、动作、噪声、评价影响时，请分析事件、受威胁的心理需要、是否把自我价值交给别人、是否进入防御/羞耻/内耗，给出恢复自主感、保护胜任感、建立边界、表达需要和回到目标的具体话术。用户输入：{{user_input}}。',
    sceneFailureId: '当用户失败、断更、没完成任务或想放弃时，先明确失败不是人格结论，而是系统反馈；分析哪种心理需要受挫，判断目标是否过大/过外控/过度依赖羞耻，找出更小恢复行动，重新连接目标价值，生成非羞辱式复盘和自主承诺。用户输入：{{user_input}}。',
    sceneTemptationId: '当用户沉迷游戏、短视频、色情、烟酒、幻想、刷网页或逃避性睡觉时，请分析诱惑短期满足了什么需要、现实中哪种心理需要受挫、是否在补偿自主/胜任/关系缺失，设计环境阻断、替代行为、非羞辱复盘和回到最小行动。用户输入：{{user_input}}。',
    sceneConfusionId: '当用户不知道自己想要什么时，不要替用户决定目标。请帮助用户恢复自主探索，分析是否害怕失败、长期被外部评价压住、胜任感不足、目标想得太大或缺少尝试经验，并提供 3 个低成本探索实验。用户输入：{{user_input}}。',
    needsRadarId: '请根据 9 个心理需要回答生成自主感、胜任感、关系感、7 日趋势解释、需要受挫诊断和今日行动建议。回答 JSON：{{needs_answers_json}}。',
    goalReviewId: '请审查目标内容，分别给出内在目标评分（成长、健康、学习、创造、关系、贡献、意义、自我实现）和外在目标评分（财富、名声、外貌、地位、权力、羡慕、报复、证明、攀比），并将外控目标重构为内在价值。目标上下文：{{goal_context_json}}。',
    motivationId: '请判断当前动机位于无动机、外部调节、内摄调节、认同调节、整合调节或内在动机，并给出从当前阶段向更高质量动机移动的建议。上下文：{{motivation_context_json}}。',
    internalizationId: '请把外部要求、模糊愿望或焦虑目标转化为价值连接、四层目标结构（表层/功能/心理/价值/身份）和自主承诺。上下文：{{goal_context_json}}。',
    minActionId: '请根据用户当前状态生成 Level 0 到 Level 5 的任务难度分级、最小行动入口和能力树节点，原则是先恢复“我能开始”的感觉，再追求高强度执行。上下文：{{action_context_json}}。',
    relationshipMapId: '请帮助用户建立关系地图：支持自主、支持能力、提供连接、控制、羞辱、消耗、需要边界，并为具体关系事件生成边界表达和支持请求。上下文：{{relationship_context_json}}。',
    environmentId: '请扫描环境如何支持或削弱自主、胜任、关系，识别软件、空间、人际、噪声、诱惑干扰，并生成环境重构和诱惑阻断清单。上下文：{{environment_context_json}}。',
    adversityGameId: '请把现实成长行动转成逆境之路游戏化任务，不使用羞辱排名或失败惩罚。心理敌人包括拖延兽、无力巨人、羞耻之影、比较之蛇、外部评价魔像、控制者、讨好面具、内耗漩涡、失败审判官、孤立荒原、诱惑幻灵、自我否定者、恐惧守门人、愤怒反击者。上下文：{{game_context_json}}。',
    narrativeId: '请根据每日行动、失败、关系、诱惑和成长证据生成成长叙事、身份句和明日继续方式。上下文：{{narrative_context_json}}。',
    weeklyReportId: '请生成每周成长报告：自主感变化、胜任感变化、关系感变化、主要敌人、最有效行动、失败模式、身份变化和下周重点建议。周数据：{{weekly_context_json}}。',
    outputId: '''请尽量按照以下结构输出：
1. 你现在真正遇到的问题。
2. 这不是简单的意志力问题。
3. 三大心理需要分析：自主感、胜任感、关系感。
4. 当前动机类型：无动机/外部调节/内摄调节/认同调节/整合调节/内在动机。
5. 目标内容分析：内在目标成分、外在目标成分。
6. 自主整合型重构。
7. 现在可以做的 1—3 个最小行动。
8. 失败后的恢复方式。
9. 身份整合句。''',
    safetyId: '本产品不替代心理治疗，不做医学诊断，不用羞辱、恐吓、排名焦虑提高留存，不把失败解释为人格缺陷，不鼓励依赖 AI，不把财富名声地位包装成唯一价值，不鼓励报复仇恨或支配别人。出现严重自伤、自杀、伤害他人、暴力或违法风险时，引导用户寻求现实专业帮助或当地紧急支持。',
    jsonRepairId: '如果上一次输出不是合法 JSON 或缺少字段，请只修复格式，不改变原意。原始内容：{{raw_text}}。',
  };

  final KeyValueDao _kv = KeyValueDao();

  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  String defaultFor(String id) => _defaults[id] ?? '';

  Future<String> getPrompt(String id, [String? fallback]) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    if (saved.isNotEmpty) return saved;
    return fallback ?? defaultFor(id);
  }

  Future<void> savePrompt(String id, String value) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), value.trim());
  }

  Future<void> clearPromptOverride(String id) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), '');
  }

  Future<Map<String, String>> inspectPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return <String, String>{
      'value': saved.isEmpty ? defaultFor(id) : saved,
      'source': saved.isEmpty ? 'default_builtin' : 'local_saved',
      'sourceLabel': saved.isEmpty ? '内置默认 Prompt' : '本地已保存 Prompt',
      'note': saved.isEmpty ? '当前使用自我决定成长系统内置 Prompt。' : '当前实际使用设置页保存的 SDT Growth Prompt，下一次本模块 AI 调用立即生效。',
    };
  }

  List<String> missingRequiredPlaceholders(String id, String template) {
    final required = <String, List<String>>{
      sceneGoalId: <String>['{{user_goal}}'],
      sceneProcrastinationId: <String>['{{user_input}}'],
      sceneRelationshipId: <String>['{{user_input}}'],
      sceneFailureId: <String>['{{user_input}}'],
      sceneTemptationId: <String>['{{user_input}}'],
      sceneConfusionId: <String>['{{user_input}}'],
      needsRadarId: <String>['{{needs_answers_json}}'],
      goalReviewId: <String>['{{goal_context_json}}'],
      motivationId: <String>['{{motivation_context_json}}'],
      internalizationId: <String>['{{goal_context_json}}'],
      minActionId: <String>['{{action_context_json}}'],
      relationshipMapId: <String>['{{relationship_context_json}}'],
      environmentId: <String>['{{environment_context_json}}'],
      adversityGameId: <String>['{{game_context_json}}'],
      narrativeId: <String>['{{narrative_context_json}}'],
      weeklyReportId: <String>['{{weekly_context_json}}'],
      jsonRepairId: <String>['{{raw_text}}'],
    }[id];
    if (required == null) return const <String>[];
    return required.where((p) => !template.contains(p)).toList(growable: false);
  }

  Future<List<CcPromptBackupRecord>> listBackups(String id) async {
    final rows = await _kv.keyValuesWithPrefix(_backupPrefix(id));
    return rows.map((e) {
      final key = e['key'] ?? '';
      final suffix = key.replaceFirst(_backupPrefix(id), '');
      final ms = int.tryParse(suffix) ?? 0;
      final dt = ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
      final label = dt == null ? key : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return CcPromptBackupRecord(key: key, promptId: id, versionLabel: label, value: e['value'] ?? '');
    }).toList(growable: false);
  }

  Future<void> restoreBackup(String id, String backupKey) async {
    final rows = await _kv.keyValuesWithPrefix(backupKey);
    final match = rows.where((e) => (e['key'] ?? '') == backupKey).toList(growable: false);
    if (match.isEmpty) return;
    await _backupCurrent(id);
    await _kv.setString(_key(id), match.first['value'] ?? '');
  }

  Future<void> _backupCurrent(String id) async {
    final current = await _kv.getString(_key(id));
    if (current == null || current.trim().isEmpty) return;
    await _kv.setString('${_backupPrefix(id)}${DateTime.now().millisecondsSinceEpoch}', current);
  }
}
