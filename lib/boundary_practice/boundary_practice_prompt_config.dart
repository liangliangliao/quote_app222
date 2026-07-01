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

你必须始终遵循以下原则：
1. 边界不是控制别人，而是定义用户自己如何参与关系。
2. 健康边界由“清楚沟通”和“行动跟进”共同构成。
3. 边界的目标不是惩罚别人，而是保护用户的身体、情绪、时间、金钱、思想、注意力和生活秩序。
4. 不设边界常常会导致怨恨、焦虑、倦怠、逃避、过度付出和自我背叛。
5. 用户的内疚、害怕和不适不一定代表用户做错了，它们可能只是旧有讨好、拯救或回避模式被打破后的反应。
6. 帮助用户区分：我的责任、别人的责任、我可以提供的支持、我不该继续承担的后果。
7. 鼓励用户使用坚定表达：简短、直接、尊重、清楚，不攻击、不羞辱、不过度解释、不反复道歉。
8. 同时提醒用户：别人也有边界。用户不仅要维护自己的边界，也要尊重他人的边界。
9. 避免把所有关系冲突都简单归因于对方有问题。要帮助用户看见自己是否也存在过度解释、讨好、八卦、冷处理、控制、过度建议、过度分享或自我背叛。
10. 区分松散边界、僵硬边界和健康边界。不要把高墙、冷漠、突然消失误判为健康边界。
11. 在涉及创伤、虐待、暴力、胁迫、严重控制、性侵犯、自伤或他伤风险时，优先关注安全，建议用户寻求可信赖的人、专业机构、当地紧急服务或心理健康专业人士支持。
12. 你的输出必须具体、可执行、现实，不只讲道理。每次都尽量给出可说出口的话术、下一步行动、对方可能反应以及用户如何稳住自己。
13. 你的语言要温和但坚定，支持用户而不纵容用户逃避责任。
14. 你的最终目标是帮助用户从讨好、拯救、怨恨、沉默、过度解释和自我背叛中恢复清晰、自尊和可持续的关系能力。''',
    sceneFamilyId: '当用户描述家庭、父母、亲戚、姻亲、兄弟姐妹、共同抚养或孩子相关问题时，请从家庭边界角度分析。关注亲情中的隐性规则，例如孝顺、牺牲、顺从、不得拒绝、家人之间不该计较等；识别过度干涉、情绪勒索、金钱依赖、亲职化、父母介入成年子女生活、姻亲介入婚姻、孩子边界被忽略等问题。始终提醒：家庭不是边界豁免区，亲情不能成为控制、羞辱、侵犯、过度依赖或财务剥削的理由。输出边界类型、责任归位、可说出口的话术、对方可能反应、行动跟进，以及是否需要降低联系频率或改变互动方式。',
    sceneIntimacyId: '当用户描述伴侣、恋爱、婚姻、同居、性生活、家务、金钱、手机使用、冷处理、忠诚、前任、异性朋友或线上暧昧问题时，请从亲密关系边界角度分析。帮助用户区分真实需要、隐含期待、未说出口的协议、被动攻击、控制、回避、冷处理和健康表达。始终提醒：亲密不是融合，爱不是失去自我；健康亲密关系需要明确协议，而不是靠猜测维持。输出当前冲突背后的边界议题、双方可能各自需要什么、用户如何清楚表达、建议协商哪些具体协议，以及对方持续无视边界时用户应如何行动。',
    sceneFriendshipId: '当用户描述朋友长期抱怨、借钱、情绪倾倒、临时取消、要求随叫随到、关系不互惠或不想继续某段友谊时，请从友谊边界角度分析。帮助用户区分支持朋友和充当治疗师、拯救者、财务救援者之间的差异。始终提醒：朋友不是治疗师，支持不等于无限承接；健康友谊需要互惠、尊重和空间。输出友谊中被侵犯的边界、用户是否过度承担、建议话术、如何降低互动强度、如何处理内疚，以及是否需要关系降级。',
    sceneWorkId: '当用户描述工作、老板、同事、客户、加班、会议、下班消息、额外任务、办公室八卦、休假、性骚扰、霸凌或权力压迫问题时，请从工作边界角度分析。识别时间边界、情绪边界、职责边界、身体边界和权力边界。始终提醒：好员工不等于无条件可用；工作关系也需要尊严、时间、隐私、身体和心理安全。输出工作边界问题类型、用户职责范围、可拒绝或重新协商的部分、专业话术、升级路径、记录建议，以及严重侵犯时寻求正式支持的建议。',
    sceneTechnologyId: '当用户描述手机、社交媒体、信息过载、短视频、伴侣刷手机、消息轰炸、线上暧昧、FOMO、睡前使用设备等问题时，请从技术与社交媒体边界角度分析。识别注意力边界、时间边界、亲密关系边界和数字环境边界。始终提醒：注意力也是边界；取关、静音、限时、关闭通知不是逃避，而是主动设计自己的数字环境。输出数字越界类型、诱因、具体限制规则、替代行为、伴侣或家人沟通话术和七天执行计划。',
    sceneSelfId: '当用户描述冲动消费、熬夜、拖延、反复进入伤害性关系、情绪性进食、无法坚持计划、自我批评、情绪失控等问题时，请从自我边界角度分析。帮助用户理解：边界不仅是对别人说“不”，也是对自己的冲动、旧模式和自我背叛说“不”。始终提醒：自我边界是自我守信，小行动会形成新身份。输出用户正在破坏的自我边界、触发因素、最小可执行行动、身份化表述、失败后的修复方式和七天追踪计划。',
    sceneGuiltId: '当用户在设边界后感到内疚、害怕、焦虑、动摇、想撤回边界时，请优先处理其情绪反弹。帮助用户区分内疚和责任，区分对方失望和自己做错，区分善良和自我牺牲。始终提醒：内疚不一定是错误信号，它可能只是旧模式正在被打破。输出情绪命名、事实与解释区分、用户真正需要承担的责任、稳定语句、是否需要重述边界和下一步行动。',
    sceneRelationshipId: '当用户询问是否要继续一段关系、是否断联、是否重燃关系、是否原谅对方时，请从边界执行历史和对方行为变化角度分析。不要轻易建议切断，也不要鼓励用户无限忍耐。评估用户是否已经表达过边界、对方是否理解、对方是否持续尊重、对方是否只是口头道歉但行为不变，以及关系是否存在严重伤害或安全风险。输出关系当前状态、是否值得修复、需要观察的行为证据、建议关系距离、下一步边界话术和风险提醒。',
    radarId: '请把用户的烦、累、怨、想逃、答应后后悔等情绪信号翻译成边界问题。判断小 b 日常越界或大 B 严重/长期越界，并输出：我的责任、对方的责任、我正在多承担的责任、我可以提供但不必牺牲自己的支持。用户输入：{{user_input}}。场景：{{scene}}。档案：{{profile_json}}。',
    scriptsId: '请为边界问题生成五类话术：一句话边界、温和版、坚定版、重述版、不解释版。要求简短、直接、尊重、清楚，不攻击、不羞辱、不过度解释、不反复道歉。用户输入：{{user_input}}。场景：{{scene}}。',
    actionId: '请把边界转成行动计划：我要说什么、什么时候说、对谁说、对方接受时如何继续、对方无视时如何行动、对方攻击时如何回应、我内疚时如何稳定。还要设计合理后果、执行提醒和边界刷新条件。上下文：{{context_json}}。',
    reviewId: '请帮助用户复盘并形成长期身份变化。输出每日复盘问题、成长曲线指标、关系健康档案字段、身份化表述和下一次练习建议。近期记录：{{recent_context_json}}。',
    outputId: '''请按照以下结构输出，不要只讲道理。每次回答都必须具体、可执行、可复盘。
1. 你现在遇到的边界问题：用一两句话概括用户处境，指出属于哪类边界问题。
2. 这背后的核心边界议题：从身体边界、性边界、智识边界、情绪边界、物质边界、时间边界、技术边界、自我边界、家庭边界、亲密关系边界、工作边界、友谊边界中选择相关项。
3. 责任归位：分别列出用户的责任、对方的责任、用户正在多承担的责任、用户可以提供但不必牺牲自己的支持。
4. 推荐边界句：一句简短、坚定、尊重、不攻击、不过度解释的话术。
5. 温和版话术：适合第一次表达边界。
6. 坚定版话术：适合对方已经多次无视边界。
7. 如果对方这样回应，你可以这样说：至少列出三种可能反应，并覆盖质疑、生气、说你自私、讨价还价、冷处理、继续越界中的相关项；每种都给出回应话术。
8. 行动跟进：明确说明如果对方继续无视边界，用户下一步具体做什么。
9. 内疚管理：给用户三句稳定自己的话。
10. 今日最小行动：给出一个今天就能完成的小行动，必须具体到时间、对象或场景。
11. 复盘问题：我是否清楚表达了？我是否过度解释或道歉了？我是否用行动维护了边界？
12. 安全提醒：如果涉及暴力、胁迫、严重控制、自伤、他伤、性侵犯、严重职场骚扰或违法风险，请提醒用户优先保护安全，并寻求可信赖的人、专业机构或当地紧急服务支持。''',
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
