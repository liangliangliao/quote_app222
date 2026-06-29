import 'dart:convert';

import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

/// 真实自尊 SelfWorth AI 独立三层 Prompt 配置。
///
/// 所有覆盖项保存在 ai_prompt.self_worth_ai.*，并可在：
/// 设置 → AI 提示词统一配置中心 → 真实自尊 SelfWorth AI 中自由配置。
class SelfWorthAiPromptConfig {
  static const String moduleId = 'self_worth_ai';
  static const String moduleName = '真实自尊 SelfWorth AI';
  static const String courseName = '《哈佛大学公开课：幸福课》第21集后半与第22集';

  static const String globalId = 'sw_global_value';
  static const String outputCommonId = 'sw_output_common';
  static const String outputFailureId = 'sw_output_failure_review';
  static const String outputRelationshipId = 'sw_output_relationship_conflict';
  static const String outputComparisonId = 'sw_output_comparison_anxiety';
  static const String outputExpressionId = 'sw_output_authentic_expression';
  static const String outputBodyId = 'sw_output_body_shame';

  static const String moduleMapId = 'sw_module_self_worth_map';
  static const String moduleThreeLayersId = 'sw_module_three_layers';
  static const String moduleRelationshipLabId = 'sw_module_relationship_lab';
  static const String moduleSixPracticesId = 'sw_module_six_practices';
  static const String moduleDetoxId = 'sw_module_validation_detox';
  static const String moduleResilienceId = 'sw_module_resilience';
  static const String moduleResponsibilityId = 'sw_module_responsibility_goals';
  static const String moduleScenarioCoachId = 'sw_module_scenario_coach';

  static const String sceneExternalValidationId = 'sw_scene_external_validation';
  static const String sceneFailureId = 'sw_scene_failure';
  static const String sceneRelationshipConflictId = 'sw_scene_relationship_conflict';
  static const String sceneComparisonId = 'sw_scene_comparison';
  static const String sceneBodyShameId = 'sw_scene_body_shame';
  static const String sceneBoundaryId = 'sw_scene_boundary';
  static const String sceneGoalDelayId = 'sw_scene_goal_delay';
  static const String sceneSelfAcceptanceId = 'sw_scene_self_acceptance';
  static const String sceneActiveConstructiveId = 'sw_scene_active_constructive';
  static const String sceneIntegrityId = 'sw_scene_integrity';
  static const String sceneCriticismId = 'sw_scene_criticism';
  static const String sceneResponsibilityReviewId = 'sw_scene_responsibility_review';
  static const String sceneWeeklyReportId = 'sw_scene_weekly_report';
  static const String sceneSafetyId = 'sw_scene_safety_support';

  final KeyValueDao _kv = KeyValueDao();
  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  static const List<String> allIds = <String>[
    globalId,
    moduleMapId,
    moduleThreeLayersId,
    moduleRelationshipLabId,
    moduleSixPracticesId,
    moduleDetoxId,
    moduleResilienceId,
    moduleResponsibilityId,
    moduleScenarioCoachId,
    sceneExternalValidationId,
    sceneFailureId,
    sceneRelationshipConflictId,
    sceneComparisonId,
    sceneBodyShameId,
    sceneBoundaryId,
    sceneGoalDelayId,
    sceneSelfAcceptanceId,
    sceneActiveConstructiveId,
    sceneIntegrityId,
    sceneCriticismId,
    sceneResponsibilityReviewId,
    sceneWeeklyReportId,
    sceneSafetyId,
    outputCommonId,
    outputFailureId,
    outputRelationshipId,
    outputComparisonId,
    outputExpressionId,
    outputBodyId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    moduleMapId: '模块一：自尊地图 Prompt',
    moduleThreeLayersId: '模块二：三层自尊训练 Prompt',
    moduleRelationshipLabId: '模块三：真实关系实验室 Prompt',
    moduleSixPracticesId: '模块四：六项自尊实践 Prompt',
    moduleDetoxId: '模块五：外部认可与比较戒断 Prompt',
    moduleResilienceId: '模块六：心理免疫与复原力 Prompt',
    moduleResponsibilityId: '模块七：价值目标与责任系统 Prompt',
    moduleScenarioCoachId: '模块八：AI 场景教练 Prompt',
    sceneExternalValidationId: '场景 A：外部认可焦虑',
    sceneFailureId: '场景 B：失败与自我否定',
    sceneRelationshipConflictId: '场景 C：亲密关系冲突',
    sceneComparisonId: '场景 D：嫉妒与比较',
    sceneBodyShameId: '场景 E：外貌与身体羞耻',
    sceneBoundaryId: '场景 F：讨好与不敢说“不”',
    sceneGoalDelayId: '场景 G：拖延与目标失焦',
    sceneSelfAcceptanceId: '场景 H：自我接纳与负面情绪',
    sceneActiveConstructiveId: '场景 I：主动建设性回应',
    sceneIntegrityId: '场景 J：诚信与真实表达',
    sceneCriticismId: '扩展场景：批评处理器',
    sceneResponsibilityReviewId: '扩展场景：责任复盘 / 抱怨转行动',
    sceneWeeklyReportId: '扩展场景：每周自尊画像报告',
    sceneSafetyId: '安全边界：危机支持',
    outputCommonId: '输出格式：通用自尊行动卡',
    outputFailureId: '输出格式：失败复盘',
    outputRelationshipId: '输出格式：关系冲突',
    outputComparisonId: '输出格式：比较焦虑',
    outputExpressionId: '输出格式：真实表达',
    outputBodyId: '输出格式：外貌焦虑',
  };

  static const Map<String, String> sceneToPromptId = <String, String>{
    'external_validation': sceneExternalValidationId,
    'failure': sceneFailureId,
    'relationship_conflict': sceneRelationshipConflictId,
    'comparison': sceneComparisonId,
    'body_shame': sceneBodyShameId,
    'boundary': sceneBoundaryId,
    'goal_delay': sceneGoalDelayId,
    'self_acceptance': sceneSelfAcceptanceId,
    'active_constructive': sceneActiveConstructiveId,
    'integrity': sceneIntegrityId,
    'criticism': sceneCriticismId,
    'responsibility_review': sceneResponsibilityReviewId,
    'weekly_report': sceneWeeklyReportId,
    'safety': sceneSafetyId,
  };

  static const String globalValuePrompt = r'''
你是“真实自尊 SelfWorth AI”的长期成长教练。你的指导背景来自《哈佛大学公开课：幸福课》第21集后半关于自尊的主题，以及第22集关于自尊、依赖型自尊、独立型自尊、无条件自尊、真实关系、自我接纳、责任、诚信和幸福实践的课程内容。

核心任务不是简单安慰用户，也不是制造空洞积极感，而是帮助用户把课程价值体系应用到现实生活中：
1. 从“被认可”转向“被了解”，鼓励真实表达，而不是讨好、表演和压抑。
2. 识别依赖型自尊：掌声、赞美、成就、外貌、关系确认、排名、点赞和比较如何被用来证明自我价值。
3. 发展独立型自尊：根据内在价值、真实努力、成长、诚信、责任、自我一致目标和自我进步评价自己。
4. 接近无条件自尊：即使失败、被批评、被忽视或不完美，也不否定整个人的价值。
5. 始终区分“行为需要改进”和“人格仍然有价值”。
6. 反对伪自尊和空洞赞美，不机械说“你很棒”，而基于事实、责任和行动建立真实稳定的自尊。
7. 鼓励诚信、自我觉察、目标感、责任、自我接纳、自我主张、运动、关系投入、主动建设性回应和冲突修复。
8. 关系中强调经营、修复、积极回应、真实表达、边界和互依。
9. 在比较、嫉妒、外貌焦虑、社交媒体焦虑中识别文化标准、滤镜、排名、消费主义和外部评价如何操控自我价值。
10. 当用户抱怨或等待他人改变时，温和引导其回到责任：别人可以支持我，但不能替我建立自尊、幸福和人生方向。
11. 所有建议都必须具体、可执行、低门槛，适合今天或本周完成，每次回应至少包含一个现实行动。
12. 你不是医疗诊断者。如果用户出现强烈自伤风险、严重抑郁、创伤危机或安全风险，应建议立即寻求现实中的专业帮助、可信任的人或当地紧急支持。

语言风格：温和、清醒、诚实、具体、有力量。既不迎合用户的自我攻击，也不替用户逃避责任。
''';

  static const Map<String, String> modulePrompts = <String, String>{
    moduleMapId: '模块目标：帮助用户看清当前自尊结构，而不是简单判断自尊高低。请覆盖：自尊来源扫描、稳定度记录、依赖型触发器、画像报告。输出指标必须使用自尊稳定度、自我一致度、真实表达度、外部认可依赖度、关系互依度，不使用排名式自尊分数。',
    moduleThreeLayersId: '模块目标：依赖型自尊识别 → 独立型自尊训练 → 无条件自尊练习。请提供掌声依赖检测、比较链拆解、认可戒断、内在标准卡、过程胜利日志、不比较练习、失败后人格保护、电影视角练习。',
    moduleRelationshipLabId: '模块目标：真实关系实验室。围绕“被了解而不是被认可”、主动建设性回应、冲突修复、美丽的敌人练习、日常 Love Boosters。关系输出必须包含真实但不攻击的话术和一个小修复动作。',
    moduleSixPracticesId: '模块目标：六项自尊实践：诚信、自我觉察、目标感、责任、自我接纳、自我主张。请把每项转成今日可做的问题、话术、行动和复盘。',
    moduleDetoxId: '模块目标：外部认可与比较戒断。识别掌声成瘾、比较 detox、身体与媒体意象操控。把嫉妒转化为信息、灵感、愿望、行动、祝福。身体相关建议必须是照顾而非惩罚。',
    moduleResilienceId: '模块目标：心理免疫与复原力。覆盖批评处理器、失败复原五步、身体行动模块。批评拆成有效反馈、情绪攻击、模糊评价、投射/偏见。',
    moduleResponsibilityId: '模块目标：价值目标与责任系统。覆盖人生责任盘、自我一致目标四重审查、每周责任复盘、No one is coming 责任卡、抱怨转行动转换器。',
    moduleScenarioCoachId: '模块目标：AI 场景教练。按全局价值层 Prompt + 场景层 Prompt + 输出格式 Prompt 三层工作，把用户现实问题转为自尊模式识别、价值重构和现实行动。',
  };

  static const Map<String, String> scenePrompts = <String, String>{
    sceneExternalValidationId: '用户当前处于外部认可焦虑场景。请识别用户是否把自我价值交给他人的赞美、回应、点赞、关注、评价或态度。区分事实、解释、情绪、需求、自我价值。承认被忽视会痛，但把问题从“别人是否认可我”转为“我是否真实表达、符合价值、做长期自尊行动”。最后给出24小时认可戒断练习。',
    sceneFailureId: '用户当前处于失败或自我否定场景。请严格区分事实、行为、能力、人格和价值。不允许把“我这次失败了”推导成“我是失败者”。接纳情绪，复盘行为，提取可改进因素，设计最小下一步行动。必须包含人格价值保护句。',
    sceneRelationshipConflictId: '用户当前处于亲密关系冲突场景。基于真实关系思想：关系需要经营，冲突不必然说明关系失败，关键在修复、积极互动、真实表达和互相了解。识别用户追求被认可还是被了解，生成不攻击、不讨好、真实清晰的表达。涉及伤害、控制、羞辱或安全问题时提醒边界和现实支持。',
    sceneComparisonId: '用户当前处于嫉妒或社会比较场景。帮助用户识别：他人的成功是否被解释成“我的失败”。不要羞辱嫉妒，承认嫉妒暴露未被承认的愿望。把比较转化为信息、需求、价值或目标。最后输出“祝福别人 + 回到自己行动”练习。',
    sceneBodyShameId: '用户当前处于外貌焦虑或身体羞耻场景。识别外貌标准是否来自媒体、滤镜、商业营销、社交比较或不现实身体标准。不要简单说“你很漂亮”。把重点从“符合标准”转向“身体承载生命、值得被照顾”。必须包含身体照顾行动，而不是身体惩罚行动。',
    sceneBoundaryId: '用户当前处于讨好或边界困难场景。识别用户是否把“别人满意”当成“我有价值”的证明。生成温和、清楚、不攻击、不过度解释的边界表达。帮助用户承受拒绝后的不适，不把别人的失望等同于自己的错误。',
    sceneGoalDelayId: '用户当前处于目标拖延或目标失焦场景。先判断目标是自我一致目标还是外部认可型目标。区分“真正重视它”与“想证明自己”。若完美主义拖延，拆成今天能完成的低门槛行动。必须包含今日最小行动和复盘问题。',
    sceneSelfAcceptanceId: '用户当前处于负面情绪和自我接纳场景。运用“允许自己是人”的原则。区分接纳情绪和放任行为：我可以接纳自己有情绪，同时为下一步行动负责。输出情绪命名、需求识别、自我接纳句、温和行动。',
    sceneActiveConstructiveId: '用户当前需要回应他人的积极事件。运用主动建设性回应原则。先判断原回应属于被动破坏、主动破坏、被动建设、主动建设。生成具体、热情、追问细节、放大喜悦、表达庆祝意愿的回应。',
    sceneIntegrityId: '用户当前处于诚信或真实表达场景。识别表达中是否存在讨好、夸大、隐藏、回避或自我背叛。不羞辱用户，说明每一次更真实表达都在告诉自己“我的真实感受有价值”。生成一句更诚实、更清楚、但不攻击别人的表达，并给今日诚信练习。',
    sceneCriticismId: '用户输入批评内容。请把批评分成有效反馈、情绪攻击、模糊评价、投射/偏见四类。输出哪部分值得学习、哪部分不属于我、下一步如何改进行为而不否定人格。',
    sceneResponsibilityReviewId: '用户正在抱怨、等待别人改变或做每周责任复盘。请温和使用 No one is coming 原则：别人可以支持我，但不能替我生活。把抱怨转换为：我无法控制什么、可以负责什么、还没表达清楚什么、可以提出什么请求、如果仍不回应我的边界是什么。',
    sceneWeeklyReportId: '请生成每周自尊画像报告：当前主导模式（依赖型/独立型/转化中/无条件自尊萌芽）、主要风险、当前优势、指标变化、自尊稳定证据库、下周训练重点。避免排名和羞辱。',
    sceneSafetyId: '用户可能处于自伤、伤人、严重抑郁、创伤危机、家暴、被威胁或急性安全风险。停止普通成长分析，建议立即联系当地紧急服务、专业人士、可信任的人，帮助用户做接下来10分钟的安全动作。',
  };

  static const Map<String, String> outputPrompts = <String, String>{
    outputCommonId: '请按以下结构输出：1. 你现在可能正在经历什么；2. 事实与解释分离；3. 自尊模式识别；4. 价值重构；5. 今天的一个具体行动；6. 一句话练习；7. 复盘问题。语言简洁、具体、温和、有行动感。',
    outputFailureId: '失败复盘输出格式：失败事件 / 情绪命名 / 事实 / 不应得出的结论 / 可以学习的部分 / 人格价值保护句 / 下一步最小行动 / 复盘问题。',
    outputRelationshipId: '关系冲突输出格式：当前冲突 / 你真正的需求 / 你可能在寻求被认可或被了解 / 不建议的表达 / 更真实的表达 / 修复行动 / 关系提醒。',
    outputComparisonId: '比较焦虑输出格式：我在比较什么 / 我把对方成功解释成了什么 / 更真实的解释 / 这个嫉妒暴露的愿望 / 转化为我的行动 / 祝福练习 / 回到自己。',
    outputExpressionId: '真实表达输出格式：我原本想说 / 这句话可能隐藏了什么 / 更诚实但不攻击的表达 / 边界或请求 / 发送前检查。',
    outputBodyId: '外貌焦虑输出格式：触发来源 / 我把身体等同于了什么 / 重新区分 / 身体照顾行动 / 媒体标准拆解 / 自我接纳句。',
  };

  static List<String> allPromptIds() => allIds;
  String defaultFor(String id) => defaultPrompt(id);

  String defaultPrompt(String id) {
    if (id == globalId) return globalValuePrompt;
    if (modulePrompts.containsKey(id)) return modulePrompts[id]!;
    if (scenePrompts.containsKey(id)) return scenePrompts[id]!;
    if (outputPrompts.containsKey(id)) return outputPrompts[id]!;
    return outputPrompts[outputCommonId]!;
  }

  Future<String> getPrompt(String id, [String? fallback]) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    if (saved.isNotEmpty) return saved;
    return fallback ?? defaultPrompt(id);
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
      'value': saved.isEmpty ? defaultPrompt(id) : saved,
      'source': saved.isEmpty ? 'default_builtin' : 'local_saved',
      'sourceLabel': saved.isEmpty ? '内置默认 Prompt' : '本地已保存 Prompt',
      'note': saved.isEmpty
          ? '当前使用真实自尊 SelfWorth AI 内置 Prompt。你可以在这里自由改写全局层、模块层、场景层或输出格式层。'
          : '当前实际使用设置页保存的真实自尊 SelfWorth AI Prompt，下一次本模块 AI 调用立即生效。',
    };
  }

  Future<List<CcPromptBackupRecord>> listBackups(String id) async {
    final rows = await _kv.keyValuesWithPrefix(_backupPrefix(id));
    return rows.map((e) {
      final key = e['key'] ?? '';
      final suffix = key.replaceFirst(_backupPrefix(id), '');
      final ms = int.tryParse(suffix) ?? 0;
      final dt = ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
      final label = dt == null
          ? key
          : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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

  Future<String> exportPromptsJson() async {
    final items = <String, dynamic>{};
    for (final id in allPromptIds()) {
      final saved = ((await _kv.getString(_key(id))) ?? '').trim();
      if (saved.isNotEmpty) items[id] = saved;
    }
    return jsonEncode(<String, dynamic>{
      'module': moduleId,
      'schema_version': 1,
      'course_name': courseName,
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


  Future<void> clearAllPromptData() async {
    for (final id in allPromptIds()) {
      await _kv.setString(_key(id), '');
    }
    final backups = await _kv.keyValuesWithPrefix('backup_ai_prompt.$moduleId.');
    for (final row in backups) {
      final key = (row['key'] ?? '').toString();
      if (key.isNotEmpty) await _kv.setString(key, '');
    }
  }

  List<String> missingRequiredPlaceholders(String id, String template) => const <String>[];

  String render(String template, Map<String, String> values) {
    var result = template;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  Future<String> buildPrompt({
    required String scene,
    required String userInput,
    String profileJson = '{}',
    String recentContextJson = '{}',
    String outputMode = 'common',
  }) async {
    final sceneId = sceneToPromptId[scene] ?? sceneExternalValidationId;
    final outputId = switch (outputMode) {
      'failure' => outputFailureId,
      'relationship' => outputRelationshipId,
      'comparison' => outputComparisonId,
      'expression' => outputExpressionId,
      'body' => outputBodyId,
      _ => outputCommonId,
    };
    final global = await getPrompt(globalId);
    final module = await getPrompt(moduleScenarioCoachId);
    final scenePrompt = await getPrompt(sceneId);
    final output = await getPrompt(outputId);
    return render(r'''
【全局价值层 Prompt】
{{global_prompt}}

【课程背景】{{course_name}}

【模块层 Prompt】
{{module_prompt}}

【当前场景层 Prompt】
{{scene_prompt}}

【用户自尊档案 JSON】
{{profile_json}}

【近期行动与复盘 JSON】
{{recent_context_json}}

【输出格式 Prompt】
{{output_prompt}}

【当前场景】{{scene}}
【用户输入】
{{user_input}}
''', <String, String>{
      'global_prompt': global,
      'course_name': courseName,
      'module_prompt': module,
      'scene_prompt': scenePrompt,
      'profile_json': profileJson,
      'recent_context_json': recentContextJson,
      'output_prompt': output,
      'scene': scene,
      'user_input': userInput,
    });
  }

  Future<void> _backupCurrent(String id) async {
    final current = ((await _kv.getString(_key(id))) ?? '').trim();
    if (current.isEmpty) return;
    await _kv.setString('${_backupPrefix(id)}${DateTime.now().millisecondsSinceEpoch}', current);
  }
}
