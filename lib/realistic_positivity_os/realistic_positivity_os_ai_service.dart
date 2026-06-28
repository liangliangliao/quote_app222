import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'realistic_positivity_os_models.dart';
import 'realistic_positivity_os_prompt_config.dart';

class RpoAiResult {
  final RpoPracticeRecord record;
  final bool usedAi;
  final String raw;

  const RpoAiResult({required this.record, required this.usedAi, required this.raw});
}

class RealisticPositivityOsAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final RealisticPositivityOsPromptConfig _promptConfig = RealisticPositivityOsPromptConfig();

  Future<RpoAiResult> generate({
    required String userInput,
    required String sceneType,
    RpoProfile profile = const RpoProfile(),
  }) async {
    final cleanInput = userInput.trim();
    final detectedScene = _normalizeScene(sceneType.trim().isEmpty ? _detectScene(cleanInput) : sceneType);
    final profileContext = profile.toPromptContext();
    final scenePrompt = await _promptConfig.buildScenePrompt(
      sceneType: detectedScene,
      userInput: cleanInput,
      profileContext: profileContext,
      recentContext: profile.recentContextHint(),
    );
    final outputPrompt = await _promptConfig.effectivePrompt(RealisticPositivityOsPromptConfig.outputCommonId);
    final globalPrompt = await _promptConfig.effectivePrompt(RealisticPositivityOsPromptConfig.globalId);
    final prompt = '''
$scenePrompt

$outputPrompt
''';
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'realistic_positivity_os.generate_action_card',
        systemPrompt: globalPrompt,
        maxTokens: 2800,
        expectJson: true,
        temperature: 0.35,
      );
      final parsed = _tryParse(raw, fallbackInput: cleanInput, fallbackScene: detectedScene);
      if (parsed != null) return RpoAiResult(record: parsed, usedAi: raw.trim().isNotEmpty, raw: raw);
    } catch (_) {}
    final local = _localGenerate(cleanInput, detectedScene, profile: profile);
    return RpoAiResult(record: local, usedAi: false, raw: local.rawJson);
  }

  RpoPracticeRecord? _tryParse(String raw, {required String fallbackInput, required String fallbackScene}) {
    final text = _extractJsonObject(raw);
    if (text.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final json = decoded.map((key, value) => MapEntry(key.toString(), value));
      json['original_input'] = (json['original_input'] ?? fallbackInput).toString().trim().isEmpty ? fallbackInput : json['original_input'];
      json['scene_type'] = _normalizeScene((json['scene_type'] ?? fallbackScene).toString());
      json['id'] = 'rpo_${DateTime.now().millisecondsSinceEpoch}_${json['scene_type'].toString().hashCode.abs()}';
      return RpoPracticeRecord.fromJson(json, fallbackInput: fallbackInput);
    } catch (_) {
      return null;
    }
  }

  String _extractJsonObject(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .replaceAll('```', '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) return text.substring(start, end + 1);
    return text;
  }

  String _normalizeScene(String raw) {
    const scenes = <String>{
      'onboarding',
      'reality_lens',
      'question_reframing',
      'gratitude',
      'relational_gratitude',
      'emotional_processing',
      'meaning_making',
      'savoring_peak',
      'change_lab',
      'abc_change',
      'behavior_first',
      'stretch_zone',
      'weekly_integration',
      'crisis',
    };
    final s = raw.trim();
    return scenes.contains(s) ? s : 'reality_lens';
  }

  String _detectScene(String input) {
    final text = input.toLowerCase();
    if (_riskLevel(text) == 'crisis') return 'crisis';
    if (_containsAny(text, const ['感谢', '感恩', '谢谢', '想谢谢', '感激', 'gratitude'])) return 'relational_gratitude';
    if (_containsAny(text, const ['开心', '高光', '成功', '温暖', '美好', 'peak', '幸福的一刻'])) return 'savoring_peak';
    if (_containsAny(text, const ['拖延', '没动力', '不想开始', '启动不了', '懒', '刷手机'])) return 'behavior_first';
    if (_containsAny(text, const ['改不了', '反复失败', '完美主义', '焦虑', '内疚', '讨好', '价值', '旧模式'])) return 'change_lab';
    if (_containsAny(text, const ['崩溃', '难过', '痛苦', '失落', '羞耻', '生气', '愤怒', '委屈'])) return 'emotional_processing';
    if (_containsAny(text, const ['反复想', '一直想', '停不下来', '后悔', '如果当时'])) return 'meaning_making';
    if (_containsAny(text, const ['挑战', '突破', '害怕但想', '舒适区', 'stretch'])) return 'stretch_zone';
    if (_containsAny(text, const ['复盘', '这一周', '本周', 'weekly'])) return 'weekly_integration';
    if (_containsAny(text, const ['珍惜', '拥有', '日常', '好事'])) return 'gratitude';
    return 'reality_lens';
  }

  bool _containsAny(String text, List<String> keywords) => keywords.any((k) => text.contains(k.toLowerCase()));

  String _riskLevel(String text) {
    const crisis = ['自杀', '杀了自己', '不想活', '结束生命', '伤害自己', '伤害别人', 'suicide', 'kill myself'];
    if (crisis.any(text.contains)) return 'crisis';
    const high = ['活不下去', '撑不下去', '彻底消失', '失控', '家暴', '被威胁'];
    if (high.any(text.contains)) return 'high';
    return 'low';
  }

  RpoPracticeRecord _localGenerate(String input, String scene, {required RpoProfile profile}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final risk = _riskLevel(input.toLowerCase());
    if (risk == 'crisis' || scene == 'crisis') {
      final json = <String, dynamic>{
        'id': 'rpo_${now}_crisis',
        'scene_type': 'crisis',
        'title': '安全支持优先',
        'original_input': input,
        'state_diagnosis': {'primary_state': 'crisis', 'secondary_state': '', 'risk_level': 'crisis', 'recommended_module': 'safety_support'},
        'core_values': ['安全支持', 'Permission to be human', '社会支持'],
        'real_situation': '你现在可能处在非常痛苦或失控的状态。此刻目标不是积极重构，也不是挑战自己，而是先保证安全并连接真实支持。',
        'old_question': '我是不是只能一个人扛？',
        'better_question': '我现在可以联系谁，或通过什么方式让自己先安全下来？',
        'intervention_summary': '高风险状态下，真实积极行动系统会暂停感恩、挑战和成长任务，优先安全、陪伴和专业支持。',
        'abc_plan': {'affect': '允许自己承认痛苦，不再独自压住它。', 'behavior': '立刻联系一个可信任的人；如有即时危险，联系当地紧急服务。', 'cognition': '现在不是证明自己能扛的时候，而是让自己活下来并获得支持。'},
        'micro_action': {'title': '联系真实支持者', 'duration_minutes': 2, 'steps': ['把手机拿在手里', '给一个可信任的人发送“我现在很危险/很痛苦，需要你陪我一下”', '如果有即时危险，联系当地紧急服务']},
        'relationship_action': '联系可信任的人、家人、朋友、心理咨询师或当地紧急服务。',
        'safety_note': '如果你有立即伤害自己或他人的风险，请现在联系当地紧急服务，或让身边的人陪你去安全地点。',
        'reflection_question': '我现在是否已经让一个真实的人知道我的处境？',
        'identity_evidence': '我正在学习在危险时寻求支持，而不是独自承受。',
        'display_cards': [
          {'title': '安全优先', 'content': '暂停积极重构，先连接真实支持。', 'type': 'safety'},
        ],
      };
      return RpoPracticeRecord.fromJson(json);
    }

    final title = _sceneTitle(scene);
    final oldQuestion = _guessOldQuestion(input, scene);
    final betterQuestion = _betterQuestionFor(scene);
    final coreValues = _coreValuesFor(scene);
    final action = _microActionFor(input, scene);
    final abc = _abcFor(scene, action);
    final binding = _bindingFor(input, scene);
    final stretch = _stretchFor(scene, input);
    final relationship = _relationshipFor(scene);
    final savor = _savorOrMeaningFor(scene);
    final json = <String, dynamic>{
      'id': 'rpo_${now}_${scene.hashCode.abs()}',
      'scene_type': scene,
      'title': title,
      'original_input': input,
      'state_diagnosis': {'primary_state': _primaryStateFor(scene), 'secondary_state': '', 'risk_level': 'low', 'recommended_module': scene},
      'core_values': coreValues,
      'real_situation': _realSituationFor(input, scene),
      'old_question': oldQuestion,
      'better_question': betterQuestion,
      'intervention_summary': _summaryFor(scene),
      'abc_plan': abc.toJson(),
      'value_binding': binding.toJson(),
      'micro_action': action.toJson(),
      'relationship_action': relationship,
      'savoring_or_meaning_making': savor,
      'stretch_zone': stretch.toJson(),
      'reflection_question': _reflectionFor(scene),
      'identity_evidence': _identityFor(scene),
      'safety_note': '',
      'display_cards': [
        {'title': '课程价值', 'content': coreValues.join(' / '), 'type': 'value'},
        {'title': '更好的问题', 'content': betterQuestion, 'type': 'question'},
        {'title': '最小行动', 'content': '${action.title}（约 ${action.durationMinutes} 分钟）', 'type': 'action'},
      ],
    };
    return RpoPracticeRecord.fromJson(json);
  }

  String _sceneTitle(String scene) {
    switch (scene) {
      case 'onboarding': return 'Onboarding 人格地图卡';
      case 'gratitude': return '感恩 Freshness 训练';
      case 'relational_gratitude': return '关系感恩行动卡';
      case 'emotional_processing': return 'Permission to be Human 情绪卡';
      case 'meaning_making': return '痛苦整合书写卡';
      case 'savoring_peak': return '积极经验重温卡';
      case 'change_lab': return '价值绑定拆解卡';
      case 'abc_change': return 'ABC 改变计划卡';
      case 'behavior_first': return '低动力 2 分钟启动卡';
      case 'stretch_zone': return 'Stretch Zone 挑战卡';
      case 'weekly_integration': return '每周人格整合卡';
      case 'question_reframing': return '问题重构卡';
      default: return '真实看见 Reality Lens';
    }
  }

  String _primaryStateFor(String scene) {
    switch (scene) {
      case 'onboarding': return 'mixed';
      case 'emotional_processing': return 'emotional_pain';
      case 'meaning_making': return 'rumination';
      case 'gratitude': return 'gratitude';
      case 'relational_gratitude': return 'relationship_gratitude';
      case 'savoring_peak': return 'positive_experience';
      case 'change_lab': return 'change_failure';
      case 'behavior_first': return 'low_motivation';
      case 'stretch_zone': return 'stretch_growth';
      case 'weekly_integration': return 'weekly_review';
      default: return 'mixed';
    }
  }

  List<String> _coreValuesFor(String scene) {
    switch (scene) {
      case 'onboarding': return ['人格地图', '长期背景', '个性化分流'];
      case 'gratitude': return ['感恩与欣赏', 'Freshness', '日常奇迹'];
      case 'relational_gratitude': return ['关系性感恩', 'Upward spiral', 'Pay it forward'];
      case 'emotional_processing': return ['Permission to be human', 'Active acceptance', '情绪智慧'];
      case 'meaning_making': return ['痛苦整合', '表达与叙事', '社会支持'];
      case 'savoring_peak': return ['Savoring', 'Peak experience', 'PPEO'];
      case 'change_lab': return ['反 quick fix', '价值绑定拆解', '长期人格训练'];
      case 'abc_change': return ['ABC 改变模型', '情绪-行为-认知整合', '行动实验'];
      case 'behavior_first': return ['行为优先', '新身份证据', '不等动力'];
      case 'stretch_zone': return ['Stretch zone', '可承受不适', '成长挑战'];
      case 'weekly_integration': return ['每周整合', '人格证据', '长期训练'];
      case 'question_reframing': return ['问题创造现实', '认知重构', '行动问题'];
      default: return ['现实主义积极', 'Benefit Finder', '完整现实'];
    }
  }

  String _realSituationFor(String input, String scene) {
    if (scene == 'onboarding') return '你正在建立人格地图：当前困扰、旧问题、价值绑定、支持关系与 Stretch 方向会成为后续 AI 引导的长期背景。';
    if (scene == 'savoring_peak') return '你记录的是一个积极、高光或温暖的时刻。此刻不需要过度分析，而是要把它重温、保存并转成一个小行动。';
    if (scene == 'gratitude' || scene == 'relational_gratitude') return '你正在把一个容易被视为理所当然的人、事或关系重新带回注意力中。';
    if (scene == 'behavior_first') return '你现在卡在低动力或启动困难中。问题不一定是人格失败，而可能是启动门槛过高。';
    if (scene == 'change_lab') return '你想改变一个旧模式，但它可能曾经保护过你，也可能绑定了某个珍贵价值。';
    if (scene == 'emotional_processing') return '你现在有真实情绪需要被看见。此刻不急着积极，先允许情绪存在。';
    return input.trim().isEmpty ? '你正在练习把现实看完整：既承认困难，也寻找资源和可行动部分。' : '这件事里可能既有真实困难，也有被忽略的资源、支持或可行动部分。';
  }

  String _guessOldQuestion(String input, String scene) {
    if (scene == 'onboarding') return '我目前最常被哪些旧问题和旧模式困住？';
    if (scene == 'behavior_first') return '我为什么这么废，为什么就是开始不了？';
    if (scene == 'change_lab') return '我是不是永远改不了？';
    if (scene == 'emotional_processing') return '我是不是不该有这种情绪？';
    if (scene == 'meaning_making') return '为什么这件事一直发生在我身上？';
    if (scene == 'gratitude') return '这有什么特别的，不是本来就应该存在吗？';
    if (scene == 'onboarding') return '你正在建立人格地图：当前困扰、旧问题、价值绑定、支持关系与 Stretch 方向会成为后续 AI 引导的长期背景。';
    if (scene == 'savoring_peak') return '这是不是只是偶然，很快就会消失？';
    if (scene == 'stretch_zone') return '如果我害怕，是不是说明我不适合做？';
    return '这件事是不是说明我不够好，或者情况已经没有办法？';
  }

  String _betterQuestionFor(String scene) {
    switch (scene) {
      case 'behavior_first': return '我现在能否只启动 2 分钟，而不是要求自己立刻完成或完美？';
      case 'change_lab': return '这个旧模式想保护什么珍贵价值？我如何保留价值、放下痛苦形式？';
      case 'emotional_processing': return '我现在真实感到什么？接纳它之后，最小有效行动是什么？';
      case 'meaning_making': return '这件事本身不一定是好的，但我可以如何表达、理解、求助或修复？';
      case 'gratitude': return '这件事如果明天消失，我会怀念什么？我今天如何重新体验它？';
      case 'relational_gratitude': return '谁曾具体帮助过我，而我还没有认真表达感谢？';
      case 'savoring_peak': return '这个时刻最值得保存的一秒是什么？它邀请我以后多做什么？';
      case 'stretch_zone': return '什么行动会让我有一点紧张但仍可承受？';
      case 'weekly_integration': return '本周有哪些证据说明我更真实、更感恩、更能行动？';
      default: return '这件事中真实困难是什么？仍存在的资源是什么？我能影响的 1% 是什么？';
    }
  }

  String _summaryFor(String scene) {
    switch (scene) {
      case 'gratitude': return '感恩不是机械列清单，而是通过具体、感官化和表达，让已有价值重新进入心理现实。';
      case 'relational_gratitude': return '感恩需要走向真实关系，表达给具体的人，形成 win-win 与 upward spiral。';
      case 'emotional_processing': return '先 permission to be human，再 active acceptance；接纳情绪但不沉溺。';
      case 'meaning_making': return '负面经验适合书写、表达、分析和整合；避免封闭反刍。';
      case 'savoring_peak': return '积极经验适合重温、描述、保存和行动化，而不是过度分析。';
      case 'change_lab': return '改变失败常因旧模式绑定珍贵价值；改变不是消灭自己，而是拆解并重组。';
      case 'behavior_first': return '不需要等动力出现，小行为可以反过来塑造态度和身份。';
      case 'stretch_zone': return '成长通常发生在可承受的不适中；panic zone 需要降级和支持。';
      default: return '真实积极不是粉饰现实，而是让困难、资源、可控行动同时被看见。';
    }
  }

  RpoMicroAction _microActionFor(String input, String scene) {
    switch (scene) {
      case 'gratitude':
        return const RpoMicroAction(title: '三层感恩记录', durationMinutes: 5, steps: ['写下一个具体对象', '写出它为什么重要', '闭眼重温一个画面或感官细节']);
      case 'relational_gratitude':
        return const RpoMicroAction(title: '写一条具体感谢', durationMinutes: 8, steps: ['写出对方做过的具体事', '写出它当时如何影响你', '发送一条真诚但不夸张的感谢']);
      case 'emotional_processing':
        return const RpoMicroAction(title: '三句话允许情绪', durationMinutes: 5, steps: ['我现在感到____', '这种情绪可能在提醒我____', '我今天不强迫自己____，只做____']);
      case 'meaning_making':
        return const RpoMicroAction(title: '痛苦事件七句书写', durationMinutes: 10, steps: ['写事实，不写评价', '写最痛的一点', '写一个可以表达/求助/修复的小行动']);
      case 'savoring_peak':
        return const RpoMicroAction(title: '积极经验 Replay', durationMinutes: 5, steps: ['回到当时画面', '写下声音/光线/身体感受', '给这个瞬间取名并保存']);
      case 'change_lab':
        return const RpoMicroAction(title: '价值绑定拆解', durationMinutes: 10, steps: ['写旧模式', '写它保护的珍贵价值', '写健康表达的一句话']);
      case 'abc_change':
        return const RpoMicroAction(title: 'ABC 三层行动', durationMinutes: 8, steps: ['允许一种情绪', '做一个最小行为', '替换一个旧解释']);
      case 'behavior_first':
        return const RpoMicroAction(title: '2 分钟启动', durationMinutes: 2, steps: ['打开材料或站起来', '只做最小第一步', '完成后写“我已经启动了”']);
      case 'stretch_zone':
        return const RpoMicroAction(title: '5% Stretch 行动', durationMinutes: 10, steps: ['选择一个略紧张但可承受的动作', '执行最小版本', '记录紧张度和完成证据']);
      default:
        return const RpoMicroAction(title: '完整现实四格', durationMinutes: 7, steps: ['写困难事实', '写仍有资源', '写可控 1%', '写今天一步行动']);
    }
  }

  RpoAbcPlan _abcFor(String scene, RpoMicroAction action) {
    return RpoAbcPlan(
      affect: scene == 'emotional_processing' ? '允许情绪存在，不把情绪当错误。' : '先识别此刻情绪，不要求自己立刻变积极。',
      behavior: '执行：${action.title}。',
      cognition: _betterQuestionFor(scene),
    );
  }

  RpoValueBinding _bindingFor(String input, String scene) {
    final text = input;
    if (scene != 'change_lab' && scene != 'abc_change') return const RpoValueBinding();
    if (text.contains('完美')) return const RpoValueBinding(oldPattern: '完美主义', boundValue: '雄心、优秀、高标准', painfulForm: '只有完美才值得开始', healthyExpression: '保留高标准，同时允许粗糙第一版和持续迭代');
    if (text.contains('焦虑')) return const RpoValueBinding(oldPattern: '焦虑', boundValue: '责任感、认真', painfulForm: '用灾难预演证明自己负责', healthyExpression: '保留责任，用计划和下一步行动替代过度预演');
    if (text.contains('内疚')) return const RpoValueBinding(oldPattern: '内疚', boundValue: '善良、同理心', painfulForm: '用自责维持关系', healthyExpression: '保留关心，同时建立清晰边界');
    if (text.contains('讨好')) return const RpoValueBinding(oldPattern: '讨好', boundValue: '爱与连接', painfulForm: '牺牲真实需求换取关系安全', healthyExpression: '保留连接愿望，同时练习诚实表达');
    return const RpoValueBinding(oldPattern: '旧模式', boundValue: '某个珍贵价值', painfulForm: '旧模式的痛苦保护壳', healthyExpression: '保留价值，放下痛苦形式，用小行动表达价值');
  }

  RpoStretchZone _stretchFor(String scene, String input) {
    if (scene == 'stretch_zone') return const RpoStretchZone(currentZone: 'stretch', nextChallenge: '选择一个紧张度 4–6/10 的行动，而不是直接进入崩溃区。');
    if (input.contains('崩溃') || input.contains('失控')) return const RpoStretchZone(currentZone: 'panic', nextChallenge: '先降级挑战，恢复安全，联系支持者。');
    return const RpoStretchZone(currentZone: 'unknown', nextChallenge: '把下一步缩小到可承受的不适。');
  }

  String _relationshipFor(String scene) {
    if (scene == 'relational_gratitude') return '选择一个具体的人，表达 TA 曾经如何帮助过你；表达后，做一个 pay it forward 小行动。';
    if (scene == 'meaning_making' || scene == 'emotional_processing') return '如果情绪强度较高，请联系一个可信任的人，只说事实和需要，不必一次讲清全部。';
    return '';
  }

  String _savorOrMeaningFor(String scene) {
    if (scene == 'onboarding') return '你正在建立人格地图：当前困扰、旧问题、价值绑定、支持关系与 Stretch 方向会成为后续 AI 引导的长期背景。';
    if (scene == 'savoring_peak') return '请重温画面、声音和身体感受，给这个时刻命名，并设计一个延续行动。';
    if (scene == 'meaning_making' || scene == 'emotional_processing') return '请通过书写或分享来整合负面经验，不要只在脑中反复播放。';
    return '';
  }

  String _reflectionFor(String scene) {
    switch (scene) {
      case 'behavior_first': return '启动前后，我的状态有哪怕 1% 的变化吗？';
      case 'gratitude': return '这次感恩是否让我重新感受到某个平时被忽略的价值？';
      case 'change_lab': return '我保留了哪个珍贵价值？放下了哪种痛苦形式？';
      case 'emotional_processing': return '我是否先允许了情绪，再选择了一个行动？';
      case 'stretch_zone': return '这个挑战处在 comfort、stretch 还是 panic？下次应升级还是降级？';
      default: return '完成行动后，我看见了什么新的现实或身份证据？';
    }
  }

  String _identityFor(String scene) {
    switch (scene) {
      case 'behavior_first': return '我是一个可以在低动力时仍然启动的人。';
      case 'gratitude': return '我是一个能重新看见日常价值的人。';
      case 'relational_gratitude': return '我是一个能把珍惜表达给真实关系的人。';
      case 'emotional_processing': return '我是一个不再用压抑或羞耻处理情绪的人。';
      case 'change_lab': return '我是一个能保留珍贵价值、放下旧模式的人。';
      case 'stretch_zone': return '我是一个愿意在可承受不适中成长的人。';
      default: return '我是一个能真实看见困难，也能采取小行动的人。';
    }
  }
}
