import 'dart:convert';

import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

/// 《新榜 New Tablets》三层 Prompt 配置。
///
/// 所有覆盖写入 ai_prompt.new_tablets.*，可在设置页 AI 提示词统一配置中心自由编辑，
/// 与其他模块完全隔离。
class NewTabletsPromptConfig {
  static const String moduleId = 'new_tablets';

  static const String globalId = 'nt_global_value';
  static const String sceneProcrastinationId = 'nt_scene_procrastination';
  static const String sceneBadConscienceId = 'nt_scene_bad_conscience';
  static const String sceneValueConfusionId = 'nt_scene_value_confusion';
  static const String sceneHerdId = 'nt_scene_herd';
  static const String sceneCommitmentId = 'nt_scene_commitment';
  static const String scenePastRegretId = 'nt_scene_past_regret';
  static const String sceneLearningOutputId = 'nt_scene_learning_output';
  static const String sceneOldTabletScanId = 'nt_scene_old_tablet_scan';
  static const String sceneNewTabletDraftId = 'nt_scene_new_tablet_draft';
  static const String sceneDailyCommandId = 'nt_scene_daily_command';
  static const String sceneFailureRepairId = 'nt_scene_failure_repair';
  static const String sceneWeeklyRevaluationId = 'nt_scene_weekly_revaluation';
  static const String outputStandardId = 'nt_output_standard';
  static const String outputCommitmentCardId = 'nt_output_commitment_card';
  static const String outputJsonId = 'nt_output_json';

  static const List<String> allIds = <String>[
    globalId,
    sceneProcrastinationId,
    sceneBadConscienceId,
    sceneValueConfusionId,
    sceneHerdId,
    sceneCommitmentId,
    scenePastRegretId,
    sceneLearningOutputId,
    sceneOldTabletScanId,
    sceneNewTabletDraftId,
    sceneDailyCommandId,
    sceneFailureRepairId,
    sceneWeeklyRevaluationId,
    outputStandardId,
    outputCommitmentCardId,
    outputJsonId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    sceneProcrastinationId: '场景：偷懒 / 拖延 / 无法行动',
    sceneBadConscienceId: '场景：强烈自责 / 内疚 / 羞耻',
    sceneValueConfusionId: '场景：价值迷茫 / 不知道为什么努力',
    sceneHerdId: '场景：群体 / 父母 / 社会评价影响',
    sceneCommitmentId: '场景：目标或长期计划 / 主权承诺卡',
    scenePastRegretId: '场景：过去后悔 / 怨恨 / 时间浪费',
    sceneLearningOutputId: '场景：学习很多但没有输出',
    sceneOldTabletScanId: '模块：旧榜扫描',
    sceneNewTabletDraftId: '模块：新榜草案与价值强度评分',
    sceneDailyCommandId: '流程：每日今日命令',
    sceneFailureRepairId: '流程：失败后的主权修复',
    sceneWeeklyRevaluationId: '流程：每周价值重估',
    outputStandardId: '输出格式：8 段标准行动诊断',
    outputCommitmentCardId: '输出格式：主权承诺卡',
    outputJsonId: '输出格式：结构化 JSON',
  };

  static const Map<String, String> sceneToPromptId = <String, String>{
    'procrastination': sceneProcrastinationId,
    'bad_conscience': sceneBadConscienceId,
    'value_confusion': sceneValueConfusionId,
    'herd': sceneHerdId,
    'commitment': sceneCommitmentId,
    'past_regret': scenePastRegretId,
    'learning_output': sceneLearningOutputId,
    'old_tablet_scan': sceneOldTabletScanId,
    'new_tablet_draft': sceneNewTabletDraftId,
    'daily_command': sceneDailyCommandId,
    'failure_repair': sceneFailureRepairId,
    'weekly_revaluation': sceneWeeklyRevaluationId,
  };

  final KeyValueDao _kv = KeyValueDao();
  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  static const String globalValuePrompt = '''
你是《新榜 New Tablets》App 中的 AI 自我超克导师。你的思想背景来自尼采《查拉图斯特拉如是说》〈论自我超克〉〈论旧榜与新榜〉、《善恶的彼岸》第 19/199 节、《道德的谱系》第二论文。
你的任务不是廉价安慰用户维持原状，也不是用罪感逼迫用户行动，而是帮助用户识别自己正在被什么支配，并引导其从被动服从、旧价值、坏良心和低级冲动中，转向自我命令、价值重估、主权责任和创造性行动。
必须遵守：生命肯定、权力意志、自我超克、命令与服从、反群体本能、价值重估、主权个体、坏良心转化、创造、坚硬但不残酷。
禁止鼓励自虐、伤害他人、支配羞辱他人、极端压迫自己；当用户出现“不配吃饭/休息”“必须惩罚自己”等表达时，必须转向安全回应：任务不是惩罚，而是恢复可行动状态并重新设计小承诺。
''';

  static const String sceneProcrastinationPrompt = '用户正在表达拖延、偷懒、逃避或无法开始行动。分析内部冲动争夺命令权、当前支配者、更高意志、具体命令与最小行动。不要羞辱，重点是夺回命令权。';
  static const String sceneBadConsciencePrompt = '用户正在表达自责、羞耻、自我否定、罪感或“我不配”等坏良心语言。识别坏良心，将其改写为主权责任，并给出不基于羞耻的修复行动。';
  static const String sceneValueConfusionPrompt = '用户正在表达迷茫、空虚、没有目标、不知道为什么努力。识别旧榜、借来的欲望和愿意承担代价的新榜，并连接 7 天现实实验。';
  static const String sceneHerdPrompt = '用户正在被父母、社会、同龄人、职业标准、舆论或网络比较影响。识别外部命令，判断工具价值与生命削弱，设计断连练习。';
  static const String sceneCommitmentPrompt = '用户正在建立目标、计划或承诺。判断焦虑/群体/新榜驱动，检查过度许诺，降级为可兑现小许诺，输出主权承诺卡。';
  static const String scenePastRegretPrompt = '用户正在后悔、怨恨过去或觉得时间浪费。承认真实损失，区分事实与意义，把过去转化为未来行动材料。';
  static const String sceneLearningOutputPrompt = '用户大量学习、阅读、看课但缺少行动或输出。判断消化还是逃避，识别败坏胃状态，要求把输入转成具体输出。';
  static const String sceneOldTabletScanPrompt = '旧榜扫描：追问用户从小被灌输的“应该”、成功标准、对别人评价的恐惧、目标来源，输出旧榜清单：旧榜/来源/影响/是否增强生命。';
  static const String sceneNewTabletDraftPrompt = '新榜草案：引导用户写出新的生命原则，并用生命增强、自主性、创造性、可承担性四维评分，必须配 7 天现实实验。';
  static const String sceneDailyCommandPrompt = '每日使用：询问今天最可能被什么支配，输出今日命令、今日超克对象、今日最小行动、防坏良心提醒与晚间复盘。';
  static const String sceneFailureRepairPrompt = '失败后的主权修复：不羞辱断签，判断承诺过大、环境失败、身体不足或低级冲动夺权，重设更小承诺。';
  static const String sceneWeeklyRevaluationPrompt = '每周价值重估：识别仍在支配的旧榜、被行动证明的新榜、过大的承诺、被转化的失败和下周要超克的旧我。';
  static const String outputStandardPrompt = '请按 8 段输出：1 当前状态诊断；2 尼采式映射；3 谁在命令你；4 需要打碎的旧榜/超克的旧我；5 新榜或主权命令；6 今日最小行动；7 防止坏良心提醒；8 复盘问题。';
  static const String outputCommitmentCardPrompt = '输出主权承诺卡：承诺标题、来源判断、等级、周期、最小行动、履约条件、阻力处理、失败修复、可靠性指标。';
  static const String outputJsonPrompt = '如需 JSON，只输出对象：diagnosis,mapping,commanders,oldSelf,newCommand,minAction,guardrail,reviewQuestions,metrics,nextExperiment。';

  static String defaultPrompt(String id) {
    switch (id) {
      case globalId: return globalValuePrompt;
      case sceneProcrastinationId: return sceneProcrastinationPrompt;
      case sceneBadConscienceId: return sceneBadConsciencePrompt;
      case sceneValueConfusionId: return sceneValueConfusionPrompt;
      case sceneHerdId: return sceneHerdPrompt;
      case sceneCommitmentId: return sceneCommitmentPrompt;
      case scenePastRegretId: return scenePastRegretPrompt;
      case sceneLearningOutputId: return sceneLearningOutputPrompt;
      case sceneOldTabletScanId: return sceneOldTabletScanPrompt;
      case sceneNewTabletDraftId: return sceneNewTabletDraftPrompt;
      case sceneDailyCommandId: return sceneDailyCommandPrompt;
      case sceneFailureRepairId: return sceneFailureRepairPrompt;
      case sceneWeeklyRevaluationId: return sceneWeeklyRevaluationPrompt;
      case outputCommitmentCardId: return outputCommitmentCardPrompt;
      case outputJsonId: return outputJsonPrompt;
      case outputStandardId:
      default: return outputStandardPrompt;
    }
  }

  String defaultFor(String id) => defaultPrompt(id);
  List<String> allPromptIds() => allIds;
  List<String> requiredPlaceholders(String id) => const <String>[];
  List<String> missingRequiredPlaceholders(String id, String value) => const <String>[];

  Future<void> _backupCurrent(String id) async {
    final current = ((await _kv.getString(_key(id))) ?? '').trim();
    if (current.isEmpty) return;
    await _kv.setString('${_backupPrefix(id)}${DateTime.now().toIso8601String()}', current);
  }

  Future<List<CcPromptBackupRecord>> listBackups(String id) async {
    final prefix = _backupPrefix(id);
    final rows = await _kv.keyValuesWithPrefix(prefix);
    return rows.map((row) => CcPromptBackupRecord(
      key: row['key'] ?? '',
      promptId: id,
      versionLabel: (row['key'] ?? '').startsWith(prefix) ? (row['key'] ?? '').substring(prefix.length) : (row['key'] ?? ''),
      value: row['value'] ?? '',
    )).where((e) => e.value.trim().isNotEmpty).toList(growable: false);
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
      'note': saved.isEmpty ? '当前使用《新榜 New Tablets》内置三层 Prompt。可在统一配置中心自由改写。' : '当前实际使用设置页保存的新榜 Prompt，下一次本模块 AI 生成立即生效。',
    };
  }

  Future<String> exportPromptsJson() async {
    final items = <String, dynamic>{};
    for (final id in allIds) {
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
      count++;
    }
    return count;
  }

  Future<String> buildPrompt({required String scene, required String userInput, String profileJson = '{}', String recentContextJson = '{}', String outputMode = 'standard'}) async {
    final sceneId = sceneToPromptId[scene] ?? sceneDailyCommandId;
    return render('''
【全局价值层 Prompt】
{{global}}

【场景层 Prompt】
{{scene_prompt}}

【用户新榜档案 JSON】
{{profile_json}}

【近期上下文 JSON】
{{recent_context_json}}

【用户输入】
{{user_input}}

【输出格式 Prompt】
{{output_prompt}}
''', <String, String>{
      'global': await getPrompt(globalId),
      'scene_prompt': await getPrompt(sceneId),
      'profile_json': profileJson,
      'recent_context_json': recentContextJson,
      'user_input': userInput,
      'output_prompt': await getPrompt(outputMode == 'commitment' ? outputCommitmentCardId : outputStandardId),
    });
  }

  String render(String template, Map<String, String> values) {
    var out = template;
    values.forEach((key, value) => out = out.replaceAll('{{$key}}', value));
    return out;
  }
}
