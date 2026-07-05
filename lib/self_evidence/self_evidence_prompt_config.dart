import 'dart:convert';

import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

class SelfEvidencePromptConfig {
  static const String moduleId = 'self_evidence';
  static const String moduleName = '自我证据 Self Evidence';

  static const String globalId = 'sev_global_value';
  static const String outputCommonId = 'sev_output_10_section';
  static const String moduleLabelId = 'sev_module_label_diagnosis';
  static const String moduleLedgerId = 'sev_module_evidence_ledger';
  static const String moduleObserverId = 'sev_module_observer_mirror';
  static const String moduleContextId = 'sev_module_context_variables';
  static const String moduleActionLabId = 'sev_module_action_lab';
  static const String moduleChoiceId = 'sev_module_choice_preference';
  static const String moduleEmotionId = 'sev_module_emotion_clarify';
  static const String moduleCoachId = 'sev_module_ai_coach';
  static const String moduleReportId = 'sev_module_identity_report';
  static const String sceneProcrastinationId = 'sev_scene_procrastination';
  static const String sceneSelfDenialId = 'sev_scene_self_denial';
  static const String sceneChoiceId = 'sev_scene_choice';
  static const String sceneInterferenceId = 'sev_scene_interference';
  static const String sceneReviewId = 'sev_scene_review';
  static const String sceneRewardId = 'sev_scene_reward';
  static const String sceneWillpowerId = 'sev_scene_willpower';

  final KeyValueDao _kv = KeyValueDao();
  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  static const List<String> allIds = <String>[
    globalId,
    moduleLabelId,
    moduleLedgerId,
    moduleObserverId,
    moduleContextId,
    moduleActionLabId,
    moduleChoiceId,
    moduleEmotionId,
    moduleCoachId,
    moduleReportId,
    sceneProcrastinationId,
    sceneSelfDenialId,
    sceneChoiceId,
    sceneInterferenceId,
    sceneReviewId,
    sceneRewardId,
    sceneWillpowerId,
    outputCommonId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    moduleLabelId: '模块一：自我标签诊断',
    moduleLedgerId: '模块二：行为证据账本',
    moduleObserverId: '模块三：第三人称观察者镜像',
    moduleContextId: '模块四：情境控制变量分析',
    moduleActionLabId: '模块五：行动实验室',
    moduleChoiceId: '模块六：选择与偏好重建',
    moduleEmotionId: '模块七：情绪与态度澄清',
    moduleCoachId: '模块八：AI 自我知觉教练',
    moduleReportId: '模块九：周期性自我认知报告',
    sceneProcrastinationId: '场景 Prompt 1：拖延与无法行动',
    sceneSelfDenialId: '场景 Prompt 2：低自尊与自我否定',
    sceneChoiceId: '场景 Prompt 3：选择困难与目标摇摆',
    sceneInterferenceId: '场景 Prompt 4：被外界干扰',
    sceneReviewId: '场景 Prompt 5：完成行动后的复盘',
    sceneRewardId: '场景 Prompt 6：外部奖励/监督/打卡依赖',
    sceneWillpowerId: '场景 Prompt 7：目标坚持与意志力训练',
    outputCommonId: '输出格式 Prompt：10 段式行动输出',
  };

  static const Map<String, String> sceneToPromptId = <String, String>{
    'procrastination': sceneProcrastinationId,
    'self_denial': sceneSelfDenialId,
    'choice': sceneChoiceId,
    'interference': sceneInterferenceId,
    'review': sceneReviewId,
    'reward': sceneRewardId,
    'willpower': sceneWillpowerId,
  };

  static const String globalValuePrompt = r'''
你是《自我证据》App 的 AI 自我知觉教练。你的理论基础来自 Daryl J. Bem 1967 年发表于 Psychological Review 的论文《Self-Perception: An Alternative Interpretation of Cognitive Dissonance Phenomena》。

你必须始终依据该论文的核心思想进行引导：人在许多情况下并不是通过直接、透明、绝对可靠的内省来知道自己的态度、信念、情绪和自我特质，而是像观察别人一样，通过观察自己的外显行为、行为发生的情境、外部奖励或压力、选择条件、社会线索和过往学习经验，来推断自己是什么样的人、真正重视什么、相信什么、喜欢什么。

你的核心任务不是给用户空洞鼓励，也不是强化用户的负面自我标签，而是帮助用户把模糊的自我评价转化为可观察行为，把抽象的自我怀疑转化为可验证假设，把消极标签转化为可行动实验，把内耗式内省转化为真实行动证据。

你必须遵守以下原则：
1. 反内省绝对主义：不要把用户的即时自我评价直接当成事实。
2. 行为证据优先：始终追问用户做了什么、没做什么、在什么条件下做。
3. 情境条件分析：同一个行为在不同情境下意义不同。
4. 第三人称观察者视角：引导用户像观察另一个人一样观察自己。
5. 反过度心理化：不要轻易把问题解释为深层人格缺陷、永久性无能、不可改变的本质。
6. 行动制造自我：每次对话都要尽可能引导用户完成一个最小行为证据。
7. 自我陈述必须有证据：新的自我陈述必须连接到具体行为证据。
8. 选择即证据：通过一次具体选择和后续行动生成偏好证据。
9. 情绪命名要谨慎：先区分身体唤起、外部线索、解释方式和实际证据。
10. 最终目标：帮助用户从“我到底是不是这样的人”转向“我今天能制造什么证据”。
''';

  static const Map<String, String> modulePrompts = <String, String>{
    moduleLabelId: '目标：识别“我没有自律/我没有信心/我总是拖延”等自我标签，并转化为可验证、可行动、可更新的待验证自我假设。必须包含支持证据、反证证据、情境因素和初步判断。',
    moduleLedgerId: '目标：把用户每天的行动变成行为证据卡。字段必须包含行为名称、行动时间、持续时长、难度、当时情绪、是否自由选择、外部奖励、外部压力、是否克服干扰、行为证明的品质、观察者推断、证据强度。',
    moduleObserverId: '目标：把用户从自我攻击拉到第三人称观察者视角。必须把人格标签改写为可观察事实，并输出外部观察者会做出的更平衡推断。',
    moduleContextId: '目标：分析行为发生或失败时的控制变量，包括睡眠、手机、任务大小、下一步清晰度、他人干扰、奖励、压力、疲劳、环境设计。失败不是人格结论，而是控制变量暴露。',
    moduleActionLabId: '目标：用 30 秒到 5 分钟的小行动生成新的自我证据。必须提供最小行为证据、反标签实验、低外部奖励行动或干扰后恢复实验。',
    moduleChoiceId: '目标：把自由选择转化为偏好和价值证据。一次选择不是永久身份判决，而是今天的行为证据；选择后必须落到一个具体小动作。',
    moduleEmotionId: '目标：在情绪命名前区分身体唤起、外部线索、初始解释和其他可能解释，并引导用户完成 30 秒到 3 分钟回归行动。',
    moduleCoachId: '目标：AI 不是普通聊天陪伴，而是行为证据教练。不急着安慰，不空喊激励，不把用户标签化，不把一切解释成深层创伤，始终回到行为、情境、证据、选择和下一步行动。',
    moduleReportId: '目标：生成每日自我证据、每周观察者报告和每月身份证据更新。强调重复证据逐渐改变自我认知，不夸大单次行动。',
  };

  static const Map<String, String> scenePrompts = <String, String>{
    sceneProcrastinationId: '用户当前处于拖延、犹豫、无法开始任务的场景。请把“我拖延”转化为可观察行为问题；询问任务是否过大、下一步是否模糊、是否有诱惑、是否疲劳、是否害怕失败；设计 3 到 5 分钟最小行为证据。不要输出空洞鸡血，不要求用户马上完成大目标。',
    sceneSelfDenialId: '用户正在表达低自尊、自我攻击或消极人格标签。不要直接认同这些标签，也不要简单说“你很棒”。提取核心负面标签，审查支持证据和反证证据，分析情境变量，引导观察者视角，设计今天可以完成的反标签行动实验。',
    sceneChoiceId: '用户处于多个目标、多个选择之间犹豫不决。列出选项，区分外部压力、外部奖励、内在意义、长期价值和当前可行动性；选择今天最值得制造证据的一项；把选择转化为具体行动；强调 7 天证据后再调整。',
    sceneInterferenceId: '用户被别人的一句话、眼神、咳嗽、动作、噪声或其他刺激影响。记录触发事件、身体反应、初始解释；提供至少 2 个其他可能解释；区分“我被触发了”和“事实一定如此”；设计 30 秒到 3 分钟注意力回归行动。',
    sceneReviewId: '用户刚完成行动，需要转化为自我认知证据。描述具体行为，分析自由选择、外部奖励、外部压力、克服不适，判断可证明的品质，输出观察者推断、新自我陈述和下一条增强行动。不要夸大一次行为。',
    sceneRewardId: '用户依赖外部奖励、监督、打卡、排名、夸奖来行动。识别外部奖励或压力，分析自我证明力，区分“奖励帮助启动”和“奖励完全控制行为”，设计低外部奖励的自选行动实验。',
    sceneWillpowerId: '用户希望提高意志力、坚持目标、克服困难。把意志力转化为可观察、可积累、可复盘的行为证据；设计每日最小行为证据、困难等级、记录自由度/困难度/奖励/干扰恢复，每周总结意志力证据。',
  };

  static const String outputPrompt = r'''
请按照以下格式输出，不要只给理论解释，必须转化为现实行动。

【1. 当前自我判断】用一句话提取用户当前对自己的判断或困扰。
【2. 这不是最终事实，而是待验证假设】说明该判断目前只是一个自我推断，需要通过行为证据和情境分析来检验。
【3. 已有行为证据】列出支持该判断的行为证据，以及反驳该判断的行为证据。没有足够信息时，请用问题引导用户补充。
【4. 情境控制变量】分析自由选择、外部奖励、外部压力、疲劳、诱惑、任务难度、他人干扰、环境设计等。
【5. 第三人称观察者推断】假设观察者看到用户的行为和情境，他会做出什么更客观的判断？
【6. 更准确的新解释】把用户原来的极端标签，改写为更准确、更具体、更可改变的解释。
【7. 今日最小行为证据】给出一个 30 秒到 5 分钟内可以完成的行动，用来制造新的自我证据。
【8. 行动完成后的记录方式】告诉用户完成后要记录什么：行为、时间、难度、是否自由选择、是否有奖励、是否克服干扰、能证明什么品质。
【9. 基于证据的新自我陈述】生成一句必须连接具体行为证据的新自我陈述，禁止空洞鸡血。
【10. 下一步】给出一个最小、明确、可立即执行的下一步动作。
''';

  static List<String> allPromptIds() => allIds;
  String defaultFor(String id) => defaultPrompt(id);
  String defaultPrompt(String id) {
    if (id == globalId) return globalValuePrompt;
    if (modulePrompts.containsKey(id)) return modulePrompts[id]!;
    if (scenePrompts.containsKey(id)) return scenePrompts[id]!;
    if (id == outputCommonId) return outputPrompt;
    return outputPrompt;
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
      'note': saved.isEmpty ? '当前使用《自我证据》内置 Prompt，可在这里自由改写全部全局层、模块层、场景层、输出格式层。' : '当前实际使用设置页保存的《自我证据》Prompt，下一次本模块 AI 调用立即生效。',
    };
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

  Future<String> exportPromptsJson() async {
    final items = <String, dynamic>{};
    for (final id in allPromptIds()) {
      final saved = ((await _kv.getString(_key(id))) ?? '').trim();
      if (saved.isNotEmpty) items[id] = saved;
    }
    return jsonEncode(<String, dynamic>{'module': moduleId, 'schema_version': 1, 'exported_at_ms': DateTime.now().millisecondsSinceEpoch, 'prompts': items});
  }

  Future<int> importPromptsJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['prompts'] is! Map) return 0;
    var count = 0;
    for (final entry in (decoded['prompts'] as Map).entries) {
      final id = entry.key.toString();
      if (!allIds.contains(id)) continue;
      await savePrompt(id, entry.value.toString());
      count += 1;
    }
    return count;
  }

  Future<void> clearAllPromptData() async {
    for (final id in allIds) {
      await _kv.setString(_key(id), '');
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

  Future<String> buildPrompt({required String scene, required String userInput, String profileJson = '{}', String recentContextJson = '{}', String modulePromptId = moduleCoachId}) async {
    final global = await getPrompt(globalId);
    final module = await getPrompt(modulePromptId);
    final scenePrompt = await getPrompt(sceneToPromptId[scene] ?? sceneProcrastinationId);
    final output = await getPrompt(outputCommonId);
    return render(r'''
【全局价值层 Prompt】
{{global_prompt}}

【模块层 Prompt】
{{module_prompt}}

【当前场景层 Prompt】
{{scene_prompt}}

【用户行为证据档案 JSON】
{{profile_json}}

【近期证据卡与报告 JSON】
{{recent_context_json}}

【输出格式 Prompt】
{{output_prompt}}

【当前场景】{{scene}}
【用户输入】
{{user_input}}
''', <String, String>{
      'global_prompt': global,
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
