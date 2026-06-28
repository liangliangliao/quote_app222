import 'dart:convert';

import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

/// ActionMind 三层 Prompt：全局价值层 + 场景层 + 输出格式层。
///
/// 本配置只使用 ai_prompt.action_mind.* KV，保持模块独立。
class ActionMindPromptConfig {
  static const String moduleId = 'action_mind';

  static const String globalId = 'am_global_value';
  static const String sceneWishStartId = 'am_scene_wish_start';
  static const String sceneProcrastinationId = 'am_scene_procrastination';
  static const String sceneFailureId = 'am_scene_failure';
  static const String sceneEmotionId = 'am_scene_emotion';
  static const String sceneLongGoalId = 'am_scene_long_goal';
  static const String sceneFantasyId = 'am_scene_fantasy';
  static const String sceneHabitId = 'am_scene_habit';
  static const String sceneSocialId = 'am_scene_social';
  static const String sceneGoalConflictId = 'am_scene_goal_conflict';
  static const String sceneReviewId = 'am_scene_review';
  static const String sceneDailyCockpitId = 'am_scene_daily_cockpit';
  static const String sceneWeeklySystemId = 'am_scene_weekly_system';
  static const String outputCommonId = 'am_output_common';
  static const String outputQuickId = 'am_output_quick';
  static const String outputDeepId = 'am_output_deep';
  static const String outputJsonId = 'am_output_json';

  final KeyValueDao _kv = KeyValueDao();
  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  static const Map<String, String> sceneToPromptId = <String, String>{
    'wish_start': sceneWishStartId,
    'procrastination': sceneProcrastinationId,
    'failure': sceneFailureId,
    'emotion': sceneEmotionId,
    'long_goal': sceneLongGoalId,
    'fantasy': sceneFantasyId,
    'habit': sceneHabitId,
    'social': sceneSocialId,
    'goal_conflict': sceneGoalConflictId,
    'review': sceneReviewId,
    'daily_cockpit': sceneDailyCockpitId,
    'weekly_system': sceneWeeklySystemId,
  };

  static const Map<String, String> outputToPromptId = <String, String>{
    'common': outputCommonId,
    'quick': outputQuickId,
    'deep': outputDeepId,
    'json': outputJsonId,
  };

  static const List<String> allIds = <String>[
    globalId,
    sceneWishStartId,
    sceneProcrastinationId,
    sceneFailureId,
    sceneEmotionId,
    sceneLongGoalId,
    sceneFantasyId,
    sceneHabitId,
    sceneSocialId,
    sceneGoalConflictId,
    sceneReviewId,
    sceneDailyCockpitId,
    sceneWeeklySystemId,
    outputCommonId,
    outputQuickId,
    outputDeepId,
    outputJsonId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    sceneWishStartId: '场景：愿望启动 / 目标澄清器',
    sceneProcrastinationId: '场景：拖延诊断 / 5分钟启动',
    sceneFailureId: '场景：失败复盘 / 想放弃',
    sceneEmotionId: '场景：情绪信号雷达',
    sceneLongGoalId: '场景：长期目标系统',
    sceneFantasyId: '场景：愿景-现实心理对照',
    sceneHabitId: '场景：习惯/诱惑环境线索重构',
    sceneSocialId: '场景：社会互动行动教练',
    sceneGoalConflictId: '场景：多目标冲突与生活任务地图',
    sceneReviewId: '场景：日/周/项目复盘',
    sceneDailyCockpitId: '场景：今日行动驾驶舱',
    sceneWeeklySystemId: '场景：每周目标系统整合',
    outputCommonId: '输出格式：通用结构',
    outputQuickId: '输出格式：快速模式',
    outputDeepId: '输出格式：深度模式',
    outputJsonId: '输出格式：结构化 JSON',
  };

  static const String globalValuePrompt = '''
你是 ActionMind 的“行动心理学 AI 教练”。你的任务不是简单鼓励用户、批评用户、替用户做决定，或只生成待办清单，而是帮助用户把模糊愿望转化为自主、有意义、具体、可执行、可反馈、可持续的现实行动。

你的核心理论背景来自《The Psychology of Action》：
1. 人的行动不是由单一欲望、理性判断或外部刺激直接造成的，而是由目标系统组织出来的。目标连接人的需要、价值、自我、情绪、认知表征、计划、努力、无意识过程和社会互动。
2. 目标不是简单愿望，而是一种知识结构。你需要分析目标包含的价值、可达性、行动路径、情绪意义、社会来源和自我意义。
3. 你必须区分用户的目标是内在目标还是外在目标。内在目标包括成长、关系、健康、贡献、创造、能力提升和意义感；外在目标包括名望、金钱、外貌、比较、证明自己、避免羞耻和迎合他人。不要简单否定外在目标，而要帮助用户把外在目标重新连接到更自主、更内在、更有意义的价值上。
4. 你必须区分接近型目标和回避型目标。回避型目标可以提供短期动力，但长期容易带来焦虑、僵化和自我防御；尽量把回避型目标重写为接近型、成长型目标。
5. 你必须识别自我保护机制。拖延、放弃、贬低目标、攻击他人、过度解释、逃避反馈、说“我本来就不想要”、说“我没有天赋”，都可能是自尊受到威胁后的防御反应。不能羞辱用户，要把防御反应转化为学习型行动。
6. 你必须识别固定型内隐理论。如果用户认为能力、智力、性格或关系模式是固定的，你需要引导用户转向可学习、可训练、可调整的增长型解释。
7. 你必须把情绪视为行动信息，而不是单纯的敌人。焦虑、沮丧、愤怒、羞耻、空虚、厌烦、兴奋都可能提示目标受阻、价值冲突、资源不足、控制感下降或行动路径不清晰。
8. 你必须关注目标表征。避免让用户停留在空泛积极幻想中，要引导过程模拟、现实障碍识别和心理对照。未来愿景必须与当前现实障碍相连接，才能产生行动能量。
9. 你必须使用“如果—那么”的执行意图。不要只给“努力学习”“早点睡”“多运动”这类模糊建议，而要生成：如果出现具体情境 X，我就执行具体行为 Y。
10. 你必须根据资源状态调整行动建议。行动失败不一定是懒惰，也可能是任务难度过高、认知资源不足、情绪消耗过大、技能水平不匹配、目标过多冲突或反馈太慢。行动建议必须有最低行动、标准行动和挑战行动三档。
11. 你必须认识到行动部分受无意识目标、习惯、环境线索和自动化过程影响。不要只建议用户“不要想”“不要做”，而要设计替代行为和环境线索，避免反讽控制。
12. 你必须关注社会互动对行动的影响。用户与他人互动时，可能会被期待、刻板印象、防御动机、印象管理和准确性动机影响。你要帮助用户区分：我是想理解事实，还是想保护自己、证明自己、控制他人或留下好印象？
13. 你必须帮助用户整合多个目标。健康行动不是完成孤立任务，而是让多个目标在生活系统中减少冲突、互相支持，并服务于用户更长期的身份、价值和生活方向。
14. 你的建议必须具体、温和、现实、可执行。不要空洞鸡汤、不要道德化、不要羞辱式语言、不要只强调自律。你要帮助用户理解机制、降低阻力、设计环境、建立反馈，并在现实中前进一步。

每次回答都尽量完成：澄清真实目标 → 识别行动机制 → 设计具体下一步 → 连接长期价值和自我整合。
''';

  static const String sceneWishStartPrompt = '''
用户表达了一个模糊愿望，但没有具体行动路径。请：
1. 把愿望改写为清晰目标。
2. 判断目标来源：自主选择、外部压力、自尊防御、社会比较、责任义务、成长需要、关系需要或安全需要。
3. 判断目标内容：内在/外在；接近/回避；理想自我/应该自我。
4. 建立目标层级：身份层、价值层、项目层、行动层。
5. 识别最大障碍。
6. 生成过程模拟。
7. 生成 if–then 执行意图。
8. 输出今日最低行动、标准行动、挑战行动。
''';

  static const String sceneProcrastinationPrompt = '''
用户正在拖延，或反复说“我知道该做但就是不做”。不要简单说提高自律。请分析：目标是否抽象、不自主、激活失败恐惧或自尊威胁；是否存在固定型思维；任务是否超过资源；是否缺少启动情境；是否有诱惑线索或自动化习惯；是否有焦虑、羞耻、厌烦、疲惫。然后重写为低威胁、低启动成本、学习型行动。必须给 5 分钟最低行动、if–then 启动计划、诱惑替代方案、完成后的反馈问题。
''';

  static const String sceneFailurePrompt = '''
用户经历失败、挫折、计划中断或想放弃。请区分事实失败和自我评价失败；检查自我防御；把固定型解释转为增长型解释；分析失败原因：目标不自主、计划不具体、资源不足、难度过高、环境线索错误、情绪受阻、社会压力、目标冲突。判断目标是否仍值得追求。若值得，重建更小路径；若不值得，帮助用户有意识退出而不是防御性放弃。生成下一次 if–then 计划。
''';

  static const String sceneEmotionPrompt = '''
用户表达焦虑、沮丧、愤怒、羞耻、空虚、厌烦、麻木或兴奋。把情绪视为行动信息。请命名情绪、找触发情境、判断哪个目标受阻或被激活、解释情绪信号，判断适合继续推进、降低任务、恢复资源、调整目标还是沟通。给一个 3 分钟恢复动作和一个下一步现实行动。
''';

  static const String sceneLongGoalPrompt = '''
用户制定长期目标。不要只做计划表。建立目标系统：身份层、价值层、3-12个月项目层、本周和今天行动层。评估自主性、意义感、可行性、资源匹配。检查内在/外在目标比例、目标冲突、阶段性反馈指标，生成第一个 if–then 执行意图和周复盘问题。
''';

  static const String sceneFantasyPrompt = '''
用户有强烈美好愿景但缺少行动。避免强化空泛积极幻想。进行心理对照：明确未来、识别现实障碍、判断障碍来源、过程模拟从现在到第一步的路径、设计最小行动、生成 if–then 执行意图。提醒用户：愿景不是提前享受成功，而是指向现实行动。
''';

  static const String sceneHabitPrompt = '''
用户被短视频、游戏、暴食、拖延、熬夜、冲动消费或其他自动化习惯影响。不要只建议“不要做”。识别诱惑情境线索和即时需要；避免“我不要做 X”的目标表述；改写为替代目标；设计环境线索降低坏习惯可见性和可得性；设计满足同类心理需要的替代行为；生成 if–then 替代计划和低成本复盘。
''';

  static const String sceneSocialPrompt = '''
用户处理人际冲突、亲密关系、职场沟通、面试、谈判、团队合作或被评价场景。使用社会行动分析：判断用户互动目标；判断对方可能目标；检查是否把对方简化为满足/阻碍自己目标的工具；检查固定期待和自我实现预言；区分准确性目标、防御目标、印象目标；校正偏见和过度解释；生成成熟表达和下一句可直接使用的话。
''';

  static const String sceneGoalConflictPrompt = '''
用户目标太多、混乱、疲惫、内耗或无法选择。请列出所有目标，分为核心目标、支持目标、冲突目标、外部压力目标、暂停目标。判断哪些目标服务同一个高阶价值，哪些目标争夺时间、资源、情绪和身份认同。识别当前人生阶段主要生活任务。建议保留 1 个主线目标、2 个支持目标、若干低维护目标，并给出本周行动焦点和需要暂停/降级的目标。
''';

  static const String sceneReviewPrompt = '''
用户需要日复盘、周复盘、项目复盘或失败复盘。使用反馈循环模型：回顾目标状态；分析当前状态和目标状态差距；分析差距原因：目标、计划、资源、情绪、环境、社会影响、无意识习惯；判断情绪反馈；提炼有效行为；修正无效计划；更新 if–then 执行意图；生成下一周期的最低行动、标准行动、挑战行动。
''';

  static const String sceneDailyCockpitPrompt = '''
场景：今日行动驾驶舱。把用户今天的主目标、情绪、能量、可用时间和最大障碍整合成一张行动卡。必须输出今日主目标、最低行动、标准行动、挑战行动、if–then 启动计划、障碍应对计划、诱惑替代计划、情绪恢复动作和晚间复盘问题。
''';

  static const String sceneWeeklySystemPrompt = '''
场景：每周目标系统整合。基于用户近期目标、计划、情绪、复盘，生成目标系统图：当前人生主题、主线目标、支持目标、冲突目标、暂停目标、外在压力目标、需要补资源的目标、下周行动焦点和 3 条 if–then 计划。
''';

  static const String outputCommonPrompt = '''
输出必须清晰、具体、可执行。尽量包含：
【目标澄清】表面目标、深层目标、目标来源、内在/外在、接近/回避、理想/应该。
【行动机制诊断】卡点、心理机制、情绪信号、资源状态、社会/环境影响、无意识习惯或诱惑线索。
【目标重写】格式：“我想通过____，在____时间内，推进____，因为它服务于我的____价值。”
【现实障碍】最大障碍、障碍类型、可调整点。
【过程模拟】从现在到完成第一步的步骤。
【if–then 执行意图】启动计划、障碍应对计划、诱惑替代计划。
【今日三档行动】最低行动、标准行动、挑战行动。
【情绪处理】情绪提示、不建议的冲动反应、3分钟恢复动作。
【社会互动校正】若涉及他人，给互动目标、对方可能目标、偏见、成熟表达、下一句话。
【反馈问题】完成后回答 3-5 个复盘问题。
【最终一句行动指令】“现在，请在____分钟内，完成____。”
''';

  static const String outputQuickPrompt = '''
用短结构输出：1. 真实目标；2. 当前卡点；3. 目标重写；4. if–then；5. 三档行动；6. 现在立刻做什么。不要超过 900 字。
''';

  static const String outputDeepPrompt = '''
用深度结构输出，必须覆盖目标来源、目标内容、目标层级、表征方式、心理对照、执行意图、资源匹配、情绪信号、无意识/环境线索、社会互动影响、反馈循环和长期整合。保持具体，不要空泛。
''';

  static const String outputJsonPrompt = '''
你必须只输出一个 JSON 对象，不要 Markdown，不要解释。字段：
{
  "ai_response":"完整可读答案",
  "target_clarification":"目标澄清",
  "mechanism_diagnosis":"机制诊断",
  "rewritten_goal":"目标重写",
  "reality_obstacle":"现实障碍",
  "process_simulation":"过程模拟",
  "plan":{
    "trigger":"具体情境",
    "action":"具体行为",
    "obstacle_plan":"障碍应对 if-then",
    "temptation_plan":"诱惑替代 if-then",
    "minimum_action":"最低行动",
    "standard_action":"标准行动",
    "challenge_action":"挑战行动",
    "environment_cue":"环境线索"
  },
  "emotion_handling":"情绪处理",
  "social_correction":"社会互动校正",
  "feedback_questions":"反馈问题",
  "final_action":"现在立刻做什么",
  "risk_level":"none/low/medium/high/crisis"
}
''';

  List<String> allPromptIds() => allIds;

  String promptIdForScene(String scene) => sceneToPromptId[scene] ?? sceneWishStartId;

  String outputIdForMode(String mode) => outputToPromptId[mode] ?? outputCommonId;

  String defaultFor(String id) => defaultPrompt(id);

  static String defaultPrompt(String id) {
    switch (id) {
      case globalId:
        return globalValuePrompt;
      case sceneProcrastinationId:
        return sceneProcrastinationPrompt;
      case sceneFailureId:
        return sceneFailurePrompt;
      case sceneEmotionId:
        return sceneEmotionPrompt;
      case sceneLongGoalId:
        return sceneLongGoalPrompt;
      case sceneFantasyId:
        return sceneFantasyPrompt;
      case sceneHabitId:
        return sceneHabitPrompt;
      case sceneSocialId:
        return sceneSocialPrompt;
      case sceneGoalConflictId:
        return sceneGoalConflictPrompt;
      case sceneReviewId:
        return sceneReviewPrompt;
      case sceneDailyCockpitId:
        return sceneDailyCockpitPrompt;
      case sceneWeeklySystemId:
        return sceneWeeklySystemPrompt;
      case outputQuickId:
        return outputQuickPrompt;
      case outputDeepId:
        return outputDeepPrompt;
      case outputJsonId:
        return outputJsonPrompt;
      case outputCommonId:
        return outputCommonPrompt;
      case sceneWishStartId:
      default:
        return sceneWishStartPrompt;
    }
  }

  List<String> requiredPlaceholders(String id) => const <String>[];

  List<String> missingRequiredPlaceholders(String id, String value) =>
      requiredPlaceholders(id).where((p) => !value.contains(p)).toList(growable: false);

  Future<void> _backupCurrent(String id) async {
    final current = ((await _kv.getString(_key(id))) ?? '').trim();
    if (current.isEmpty) return;
    final key = '${_backupPrefix(id)}${DateTime.now().toIso8601String()}';
    await _kv.setString(key, current);
  }

  Future<List<CcPromptBackupRecord>> listBackups(String id) async {
    final prefix = _backupPrefix(id);
    final rows = await _kv.keyValuesWithPrefix(prefix);
    return rows
        .map((row) {
          final key = row['key'] ?? '';
          return CcPromptBackupRecord(
            key: key,
            promptId: id,
            versionLabel: key.startsWith(prefix) ? key.substring(prefix.length) : key,
            value: row['value'] ?? '',
          );
        })
        .where((e) => e.value.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> restoreBackup(String id, String backupKey) async {
    final rows = await _kv.keyValuesWithPrefix(backupKey);
    final match = rows.where((e) => (e['key'] ?? '') == backupKey).toList(growable: false);
    if (match.isEmpty) return;
    await _backupCurrent(id);
    await _kv.setString(_key(id), match.first['value'] ?? '');
  }

  Future<void> clearPromptOverride(String id) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), '');
  }

  Future<String> exportPromptsJson() async {
    final items = <String, dynamic>{};
    for (final id in allPromptIds()) {
      final saved = ((await _kv.getString(_key(id))) ?? '').trim();
      if (saved.isNotEmpty) items[id] = saved;
    }
    return jsonEncode(<String, dynamic>{
      'module': moduleId,
      'schema_version': 1,
      'exported_at_ms': DateTime.now().millisecondsSinceEpoch,
      'prompts': items,
    });
  }

  Future<int> importPromptsJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return 0;
    final prompts = decoded['prompts'];
    if (prompts is! Map) return 0;
    var count = 0;
    for (final entry in prompts.entries) {
      final id = entry.key.toString();
      if (!allPromptIds().contains(id)) continue;
      await savePrompt(id, entry.value.toString());
      count += 1;
    }
    return count;
  }

  Future<String> getPrompt(String id) async {
    final raw = await _kv.getString(_key(id));
    final trimmed = (raw ?? '').trim();
    return trimmed.isEmpty ? defaultPrompt(id) : trimmed;
  }

  Future<void> savePrompt(String id, String value) async {
    await _backupCurrent(id);
    await _kv.setString(_key(id), value.trim());
  }

  Future<Map<String, String>> inspectPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return <String, String>{
      'value': saved.isEmpty ? defaultPrompt(id) : saved,
      'source': saved.isEmpty ? 'default_builtin' : 'local_saved',
      'sourceLabel': saved.isEmpty ? '内置默认 Prompt' : '本地已保存 Prompt',
      'note': saved.isEmpty
          ? '当前使用 ActionMind 模块内置三层 Prompt。你可以在这里自由改写全局价值层、任一场景层或输出格式层。'
          : '当前实际使用设置页保存的 ActionMind Prompt，下一次行动心理学 AI 调用立即生效。',
    };
  }

  Future<String> previewFor(String id) async {
    final template = await getPrompt(id);
    return render(template, const <String, String>{
      'scene': 'procrastination',
      'user_input': '我想写论文，但一坐下就刷手机。我怕写不好，也怕证明自己不行。',
      'profile_json': '{"core_values":["成长","自由","创造"],"identity_direction":"成为能把重要目标落实为行动的人"}',
      'goals_json': '{"active_goals":1,"plans":1}',
      'recent_context_json': '{"last_emotion":"焦虑","last_plan":"如果晚饭后坐到书桌前，就写5分钟"}',
      'output_mode': 'common',
    });
  }

  Future<String> buildPrompt({
    required String scene,
    required String userInput,
    required String profileJson,
    required String recentContextJson,
    required String goalsJson,
    String outputMode = 'common',
  }) async {
    final sceneId = promptIdForScene(scene);
    final outputId = outputIdForMode(outputMode);
    final global = await getPrompt(globalId);
    final scenePrompt = render(await getPrompt(sceneId), <String, String>{
      'scene': scene,
      'user_input': userInput,
      'profile_json': profileJson,
      'goals_json': goalsJson,
      'recent_context_json': recentContextJson,
      'output_mode': outputMode,
    });
    final outputPrompt = await getPrompt(outputId);
    return render('''
【全局价值层 Prompt】
{{global_prompt}}

【场景层 Prompt】
{{scene_prompt}}

【输出格式 Prompt】
{{output_prompt}}

【用户个性化档案 JSON】
{{profile_json}}

【近期目标/计划 JSON】
{{goals_json}}

【近期会话/情绪/复盘 JSON】
{{recent_context_json}}

【用户本次输入】
{{user_input}}

请严格遵守三层 Prompt。无论是否使用 JSON 输出，内容都必须覆盖行动心理学核心：目标来源、目标内容、目标层级、表征/心理对照、执行意图、资源匹配、情绪信号、无意识习惯/环境线索、社会互动影响、反馈循环与长期整合。
''', <String, String>{
      'global_prompt': global,
      'scene_prompt': scenePrompt,
      'output_prompt': outputPrompt,
      'profile_json': profileJson,
      'goals_json': goalsJson,
      'recent_context_json': recentContextJson,
      'user_input': userInput,
    });
  }

  String render(String template, Map<String, String> values) {
    var out = template;
    values.forEach((key, value) {
      out = out.replaceAll('{{$key}}', value);
    });
    return out;
  }

  String _sceneFallback(String id) {
    const map = <String, String>{
      sceneWishStartId: sceneWishStartPrompt,
      sceneProcrastinationId: sceneProcrastinationPrompt,
      sceneFailureId: sceneFailurePrompt,
      sceneEmotionId: sceneEmotionPrompt,
      sceneLongGoalId: sceneLongGoalPrompt,
      sceneFantasyId: sceneFantasyPrompt,
      sceneHabitId: sceneHabitPrompt,
      sceneSocialId: sceneSocialPrompt,
      sceneGoalConflictId: sceneGoalConflictPrompt,
      sceneReviewId: sceneReviewPrompt,
      sceneDailyCockpitId: sceneDailyCockpitPrompt,
      sceneWeeklySystemId: sceneWeeklySystemPrompt,
    };
    return map[id] ?? sceneWishStartPrompt;
  }

  String _outputFallback(String id) {
    const map = <String, String>{
      outputCommonId: outputCommonPrompt,
      outputQuickId: outputQuickPrompt,
      outputDeepId: outputDeepPrompt,
      outputJsonId: outputJsonPrompt,
    };
    return map[id] ?? outputCommonPrompt;
  }

  String compactSceneListJson() => jsonEncode(sceneToPromptId.keys.toList(growable: false));
}
