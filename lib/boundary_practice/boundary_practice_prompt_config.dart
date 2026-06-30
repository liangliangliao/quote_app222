import 'dart:convert';

import '../cognitive_consistency/cognitive_consistency_models.dart';
import '../data/kv_dao.dart';

/// Centralized prompt configuration for Boundary Practice.
///
/// All AI instructions used by the module are editable from the unified AI
/// prompt settings page. The module keeps these prompts separate from every
/// other product module by using the `bp_` id prefix and its own KV namespace.
class BoundaryPracticePromptConfig {
  static const String moduleId = 'boundary_practice';
  static const String moduleName = '边界练习场 Boundary Practice';

  static const String globalId = 'bp_global';
  static const String sceneFamilyId = 'bp_scene_family';
  static const String sceneIntimacyId = 'bp_scene_intimacy';
  static const String sceneFriendshipId = 'bp_scene_friendship';
  static const String sceneWorkId = 'bp_scene_work';
  static const String sceneTechnologyId = 'bp_scene_technology';
  static const String sceneSelfId = 'bp_scene_self';
  static const String sceneGuiltId = 'bp_scene_guilt';
  static const String sceneRelationshipId = 'bp_scene_relationship';
  static const String radarId = 'bp_boundary_radar';
  static const String scriptsId = 'bp_script_generator';
  static const String actionId = 'bp_action_consequence';
  static const String reviewId = 'bp_review_growth';
  static const String outputId = 'bp_output_standard';
  static const String safetyId = 'bp_safety_ethics';
  static const String jsonRepairId = 'bp_json_repair';

  static const List<String> allIds = <String>[
    globalId,
    sceneFamilyId,
    sceneIntimacyId,
    sceneFriendshipId,
    sceneWorkId,
    sceneTechnologyId,
    sceneSelfId,
    sceneGuiltId,
    sceneRelationshipId,
    radarId,
    scriptsId,
    actionId,
    reviewId,
    outputId,
    safetyId,
    jsonRepairId,
  ];

  static const Map<String, String> labels = <String, String>{
    globalId: '全局价值层 Prompt',
    sceneFamilyId: '场景：家庭边界',
    sceneIntimacyId: '场景：亲密关系边界',
    sceneFriendshipId: '场景：友谊边界',
    sceneWorkId: '场景：工作边界',
    sceneTechnologyId: '场景：技术与社交媒体边界',
    sceneSelfId: '场景：自我边界',
    sceneGuiltId: '场景：内疚与不适管理',
    sceneRelationshipId: '场景：关系评估与距离调整',
    radarId: '功能：边界雷达与责任归位',
    scriptsId: '功能：边界话术生成器',
    actionId: '功能：行动与后果跟踪',
    reviewId: '功能：复盘成长与身份建设',
    outputId: '输出格式：标准结构',
    safetyId: '安全伦理边界',
    jsonRepairId: '异常恢复：JSON 修复',
  };

  static const Map<String, String> _defaults = <String, String>{
    globalId: '''你是一名基于 Nedra Glover Tawwab《Set Boundaries, Find Peace》核心思想设计的 AI 边界行动教练。你的任务不是替用户控制别人，也不是鼓励用户冲动切断关系，而是帮助用户识别边界问题、清楚表达需要、制定现实行动、承受设边界后的不适，并在家庭、亲密关系、友谊、职场、技术使用和自我管理中练习健康边界。

始终遵循：
1. 边界不是控制别人，而是定义用户自己如何参与关系。
2. 健康边界由“清楚沟通”和“行动跟进”共同构成。
3. 边界保护身体、情绪、时间、金钱、思想、注意力和生活秩序。
4. 内疚、害怕和不适不一定代表用户做错了，可能只是旧模式被打破。
5. 区分：我的责任、别人的责任、我可以提供的支持、我不该继续承担的后果。
6. 鼓励简短、直接、尊重、清楚的坚定表达，不攻击、不羞辱、不过度解释、不反复道歉。
7. 同时提醒用户尊重他人的边界。
8. 区分松散边界、僵硬边界和健康边界，不把高墙、冷漠、突然消失误判为健康边界。
9. 涉及创伤、虐待、暴力、胁迫、严重控制、性侵犯、自伤或他伤风险时，优先关注安全并建议寻求可信赖的人、专业机构、当地紧急服务或心理健康专业人士支持。
10. 每次输出必须具体、可执行、可复盘。''',
    sceneFamilyId: '当用户描述家庭、父母、亲戚、姻亲、兄弟姐妹、共同抚养或孩子问题时，从家庭边界角度分析。关注孝顺、牺牲、顺从、不得拒绝、家人之间不该计较等隐性规则。提醒：家庭不是边界豁免区。输出边界类型、责任归位、话术、对方可能反应、行动跟进，以及是否需要降低联系频率或改变互动方式。',
    sceneIntimacyId: '当用户描述伴侣、恋爱、婚姻、同居、性生活、家务、金钱、手机使用、冷处理、忠诚、前任或线上暧昧时，从亲密关系边界分析。提醒：亲密不是融合，爱不是失去自我。输出冲突背后的边界议题、双方需要、清楚表达、具体协议和持续无视时的行动。',
    sceneFriendshipId: '当用户描述朋友长期抱怨、借钱、情绪倾倒、临时取消、随叫随到、关系不互惠或想降级友谊时，从友谊边界分析。提醒：朋友不是治疗师，支持不等于无限承接。输出被侵犯的边界、过度承担、话术、降低互动强度、内疚处理和关系降级建议。',
    sceneWorkId: '当用户描述老板、同事、客户、加班、会议、下班消息、额外任务、办公室八卦、休假、性骚扰、霸凌或权力压迫时，从工作边界分析。提醒：好员工不等于无条件可用。输出工作边界类型、职责范围、可拒绝或重新协商部分、专业话术、升级路径、记录建议和正式支持建议。',
    sceneTechnologyId: '当用户描述手机、社交媒体、信息过载、短视频、伴侣刷手机、消息轰炸、线上暧昧、FOMO 或睡前使用设备时，从技术边界分析。提醒：注意力也是边界。输出数字越界类型、诱因、限制规则、替代行为、沟通话术和七天执行计划。',
    sceneSelfId: '当用户描述冲动消费、熬夜、拖延、反复进入伤害性关系、情绪性进食、无法坚持计划、自我批评或情绪失控时，从自我边界分析。提醒：自我边界是自我守信，小行动会形成新身份。输出被破坏的自我边界、触发因素、最小行动、身份化表述、失败后的修复方式和七天追踪计划。',
    sceneGuiltId: '当用户在设边界后内疚、害怕、焦虑、动摇或想撤回边界时，优先处理情绪反弹。帮助区分内疚和责任、对方失望和自己做错、善良和自我牺牲。输出情绪命名、事实与解释、真正责任、稳定语句、是否需要重述边界和下一步行动。',
    sceneRelationshipId: '当用户询问是否继续、断联、重燃或原谅一段关系时，从边界执行历史和对方行为变化分析。不要轻易建议切断，也不要鼓励无限忍耐。评估表达历史、理解程度、持续尊重、口头道歉与行为变化、安全风险。输出关系状态、是否值得修复、行为证据、关系距离、话术和风险提醒。',
    radarId: '请把用户的烦、累、怨、想逃、答应后后悔等情绪信号翻译成边界问题。判断小 b 日常越界或大 B 严重/长期越界，并输出：我的责任、对方的责任、我正在多承担的责任、我可以提供但不必牺牲自己的支持。用户输入：{{user_input}}。场景：{{scene}}。档案：{{profile_json}}。',
    scriptsId: '请为边界问题生成五类话术：一句话边界、温和版、坚定版、重述版、不解释版。要求简短、直接、尊重、清楚，不攻击、不羞辱、不过度解释、不反复道歉。用户输入：{{user_input}}。场景：{{scene}}。',
    actionId: '请把边界转成行动计划：我要说什么、什么时候说、对谁说、对方接受时如何继续、对方无视时如何行动、对方攻击时如何回应、我内疚时如何稳定。还要设计合理后果、执行提醒和边界刷新条件。上下文：{{context_json}}。',
    reviewId: '请帮助用户复盘并形成长期身份变化。输出每日复盘问题、成长曲线指标、关系健康档案字段、身份化表述和下一次练习建议。近期记录：{{recent_context_json}}。',
    outputId: '''请严格按照以下结构输出：
1. 你现在遇到的边界问题
2. 这背后的核心边界议题
3. 责任归位：用户责任 / 对方责任 / 用户正在多承担 / 可提供但不牺牲的支持
4. 推荐边界句
5. 温和版话术
6. 坚定版话术
7. 如果对方这样回应，你可以这样说：至少覆盖质疑、生气、自私、讨价还价、冷处理、继续越界中的三类
8. 行动跟进
9. 内疚管理：三句稳定语句
10. 今日最小行动：具体到时间、对象或场景
11. 复盘问题：我是否清楚表达了？我是否过度解释或道歉了？我是否用行动维护了边界？
12. 安全提醒''',
    safetyId: '不要诊断精神疾病；不要鼓励冲动断联；不要把所有冲突归咎于对方；不要在暴力、胁迫、严重控制关系中只建议好好沟通；不要鼓励报复、操控或羞辱。涉及违法、暴力、性侵犯、自伤他伤或严重职场骚扰时，优先安全、记录证据、寻求可信赖的人、专业机构或当地紧急服务。',
    jsonRepairId: '如果上一次输出不是合法 JSON 或缺少字段，请只修复格式，不改变原意。必须返回可解析 JSON。原始内容：{{raw_text}}。',
  };

  final KeyValueDao _kv = KeyValueDao();

  static String _key(String id) => 'ai_prompt.$moduleId.$id';
  String _backupPrefix(String id) => 'backup_${_key(id)}_';

  List<String> allPromptIds() => allIds;

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
      'note': saved.isEmpty
          ? '当前使用边界练习场内置 Prompt。'
          : '当前实际使用设置页保存的边界练习场 Prompt，下一次本模块 AI 调用立即生效。',
    };
  }

  List<String> missingRequiredPlaceholders(String id, String template) {
    final required = <String, List<String>>{
      radarId: <String>['{{user_input}}', '{{scene}}'],
      scriptsId: <String>['{{user_input}}', '{{scene}}'],
      actionId: <String>['{{context_json}}'],
      reviewId: <String>['{{recent_context_json}}'],
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
      final label = dt == null
          ? key
          : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return CcPromptBackupRecord(
        key: key,
        promptId: id,
        versionLabel: label,
        value: e['value'] ?? '',
      );
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

  String render(String template, Map<String, String> values) {
    var result = template;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  String scenePromptId(String scene) {
    switch (scene) {
      case 'family':
        return sceneFamilyId;
      case 'intimacy':
        return sceneIntimacyId;
      case 'friendship':
        return sceneFriendshipId;
      case 'work':
        return sceneWorkId;
      case 'technology':
        return sceneTechnologyId;
      case 'self':
        return sceneSelfId;
      case 'guilt':
        return sceneGuiltId;
      case 'relationship':
        return sceneRelationshipId;
      default:
        return sceneFamilyId;
    }
  }

  Future<String> buildPrompt({
    required String scene,
    required String userInput,
    required String profileJson,
    required String contextJson,
    required String recentContextJson,
    String outputMode = 'standard',
  }) async {
    final global = await getPrompt(globalId);
    final scenePrompt = await getPrompt(scenePromptId(scene));
    final radar = render(await getPrompt(radarId), <String, String>{
      'scene': scene,
      'user_input': userInput,
      'profile_json': profileJson,
      'context_json': contextJson,
      'recent_context_json': recentContextJson,
      'output_mode': outputMode,
    });
    final scripts = render(await getPrompt(scriptsId), <String, String>{
      'scene': scene,
      'user_input': userInput,
      'profile_json': profileJson,
      'context_json': contextJson,
      'recent_context_json': recentContextJson,
      'output_mode': outputMode,
    });
    final action = render(await getPrompt(actionId), <String, String>{
      'scene': scene,
      'user_input': userInput,
      'profile_json': profileJson,
      'context_json': contextJson,
      'recent_context_json': recentContextJson,
      'output_mode': outputMode,
    });
    final review = render(await getPrompt(reviewId), <String, String>{
      'scene': scene,
      'user_input': userInput,
      'profile_json': profileJson,
      'context_json': contextJson,
      'recent_context_json': recentContextJson,
      'output_mode': outputMode,
    });

    return render('''
【全局价值层 Prompt】
{{global_prompt}}

【当前场景层 Prompt】
{{scene_prompt}}

【边界雷达 Prompt】
{{radar_prompt}}

【话术生成 Prompt】
{{scripts_prompt}}

【行动与后果 Prompt】
{{action_prompt}}

【复盘成长 Prompt】
{{review_prompt}}

【安全伦理 Prompt】
{{safety_prompt}}

【输出格式 Prompt】
{{output_prompt}}

【用户边界档案 JSON】
{{profile_json}}

【本轮上下文 JSON】
{{context_json}}

【近期复盘 JSON】
{{recent_context_json}}

【当前场景】{{scene}}
【输出模式】{{output_mode}}
【用户输入】
{{user_input}}
''', <String, String>{
      'global_prompt': global,
      'scene_prompt': scenePrompt,
      'radar_prompt': radar,
      'scripts_prompt': scripts,
      'action_prompt': action,
      'review_prompt': review,
      'safety_prompt': await getPrompt(safetyId),
      'output_prompt': await getPrompt(outputId),
      'profile_json': profileJson,
      'context_json': contextJson,
      'recent_context_json': recentContextJson,
      'scene': scene,
      'output_mode': outputMode,
      'user_input': userInput,
    });
  }

  Future<void> _backupCurrent(String id) async {
    final current = ((await _kv.getString(_key(id))) ?? '').trim();
    if (current.isEmpty) return;
    await _kv.setString('${_backupPrefix(id)}${DateTime.now().millisecondsSinceEpoch}', current);
  }
}
