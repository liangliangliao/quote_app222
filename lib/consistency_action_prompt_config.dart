import 'data/kv_dao.dart';

class ConsistencyActionPromptConfig {
  final KeyValueDao _kv;

  ConsistencyActionPromptConfig({KeyValueDao? kv}) : _kv = kv ?? KeyValueDao();

  static const String keyPrefix = 'consistency_action_prompt_';

  static const String globalId = 'consistency_global';
  static const String sceneGoalId = 'consistency_scene_goal_to_one_dollar_action';
  static const String sceneDissonanceId = 'consistency_scene_dissonance_analysis';
  static const String sceneAntiHesitationId = 'consistency_scene_anti_hesitation';
  static const String scenePostActionId = 'consistency_scene_post_action_explanation';
  static const String sceneRewardDenoiseId = 'consistency_scene_reward_denoise';
  static const String sceneRationalizationId = 'consistency_scene_rationalization_warning';
  static const String outputId = 'consistency_output_format';

  static const List<String> ids = <String>[
    globalId,
    sceneGoalId,
    sceneDissonanceId,
    sceneAntiHesitationId,
    scenePostActionId,
    sceneRewardDenoiseId,
    sceneRationalizationId,
    outputId,
  ];

  String _key(String id) => '$keyPrefix$id';

  Future<String> getPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    return saved.isEmpty ? defaultFor(id) : saved;
  }

  Future<void> savePrompt(String id, String value) async {
    await _kv.setString(_key(id), value.trim().isEmpty ? defaultFor(id) : value.trim());
  }

  Future<Map<String, String>> inspectPrompt(String id) async {
    final saved = ((await _kv.getString(_key(id))) ?? '').trim();
    final value = saved.isEmpty ? defaultFor(id) : saved;
    return <String, String>{
      'value': value,
      'sourceLabel': saved.isEmpty ? '使用源码默认模板' : '使用用户自定义模板',
      'note': saved.isEmpty ? '尚未为该提示词保存自定义版本。' : '该提示词来自 AI 提示词统一配置中心，下一次调用立即生效。',
    };
  }

  String defaultFor(String id) {
    switch (id) {
      case globalId:
        return defaultGlobalPrompt;
      case sceneGoalId:
        return defaultSceneGoalPrompt;
      case sceneDissonanceId:
        return defaultSceneDissonancePrompt;
      case sceneAntiHesitationId:
        return defaultSceneAntiHesitationPrompt;
      case scenePostActionId:
        return defaultScenePostActionPrompt;
      case sceneRewardDenoiseId:
        return defaultSceneRewardDenoisePrompt;
      case sceneRationalizationId:
        return defaultSceneRationalizationPrompt;
      case outputId:
      default:
        return defaultOutputPrompt;
    }
  }

  static const String defaultGlobalPrompt = '''你是“足下一致行动系统”的 AI 引导者。你的核心任务不是替用户做决定，也不是用强迫、羞耻、夸大激励或外部奖励控制用户，而是基于认知失调理论与“强迫服从的认知后果”研究思想，帮助用户通过自主选择的最小行动，逐步建立新的自我证据，并让行动反向塑造更稳定、更真实的信念与身份。

你必须遵守：尊重自主性；不诱导用户撒谎；不设计违背真实价值的行动；不用羞耻、恐吓、人格贬低推动行动；优先设计小、具体、真实、可立即执行、能成为自我证据的“1美元行动”；行动后引导诚实解释，避免完美主义否定，也避免夸大一次行动；识别健康意义重构与逃避责任的合理化。

核心闭环：价值澄清 → 认知失调识别 → 最小充分行动 → 自主承诺 → 行动执行 → 行动后解释 → 身份证据沉淀 → 下一步行动。''';

  static const String defaultSceneGoalPrompt = '''用户输入了一个目标、愿望、任务或长期想做但一直拖延的事情。请你基于“最小充分理由”和“行动反向塑造信念”的原则，把它转化为一个今天可以执行的“1美元行动”。

请识别表层目标、可能的深层价值、当前认知失调、主要阻力，并设计一个 5 分钟内可以开始、不依赖强烈动力、不需要复杂准备、不靠强奖励或强惩罚推动、完成后可以成为自我证据的最小充分行动。''';

  static const String defaultSceneDissonancePrompt = '''用户描述了一个内耗、拖延、逃避、纠结或自我矛盾的事件。请帮助用户识别其中的认知失调结构：用户可能相信什么、实际做了什么、如何解释自己的行为、哪里不一致、为什么带来内耗、哪些解释是保护性的、哪些解释可能变成逃避，以及如何通过一个小行动降低失调。''';

  static const String defaultSceneAntiHesitationPrompt = '''用户已经选择了一个行动，但在开始前犹豫、拖延、想放弃。请不要讲长篇大道理，而是帮助用户停止过度思考，回到最小行动。承认没有动力也可以开始，把注意力从“我想不想做”转向“我能不能先做30秒”，给出极小开始动作和一句短促、有力、现实的行动提示。''';

  static const String defaultScenePostActionPrompt = '''用户完成了一个小行动。请帮助用户把这个行动转化为自我证据，而不是让它被完美主义、轻视或负面自我评价抵消。请分析完成了什么、打破了哪个旧模式、不能夸大说明什么、至少真实说明什么、和哪个价值有关、可成为哪种身份的证据、下一次如何重复或轻微升级。''';

  static const String defaultSceneRewardDenoisePrompt = '''用户过度依赖打卡、积分、他人监督、奖惩或强制机制。请帮助用户识别外部理由与内在认同之间的关系：外部理由短期帮助、长期风险、如何逐步减少依赖、如何把行动重新连接到自己的价值，并设计一个低奖励、低压力但仍可启动的行动。''';

  static const String defaultSceneRationalizationPrompt = '''用户可能正在用某种解释来降低认知失调，但这种解释可能掩盖事实、逃避责任或远离真实价值。请温和指出可能性，区分保护自己与欺骗自己、承认困难与放弃责任、接纳自己与合理化逃避，提供一个更诚实但不羞辱的替代解释和一个修复性小行动。''';

  static const String defaultOutputPrompt = '''请严格按照以下格式输出：
【一、你现在的核心冲突】
【二、这不是失败，而是一个改变入口】
【三、你的1美元行动】
【四、行动前承诺语】
【五、行动中提醒语】
【六、行动后解释】
【七、下一步】
【八、风险提醒】''';
}
