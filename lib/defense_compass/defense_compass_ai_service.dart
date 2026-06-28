import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'defense_compass_models.dart';
import 'defense_compass_prompt_config.dart';

class DefenseCompassAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final DefenseCompassPromptConfig _prompts = DefenseCompassPromptConfig();

  Future<DefenseCompassSession> generate({
    required String scene,
    required String userInput,
    required DefenseCompassProfile profile,
    required String recentContextJson,
    String outputMode = 'standard',
  }) async {
    final fallback = localAnalyze(
      scene: scene,
      userInput: userInput,
      profile: profile,
      recentContextJson: recentContextJson,
      outputMode: outputMode,
    );
    final prompt = await _prompts.buildPrompt(
      scene: scene,
      userInput: userInput,
      profileJson: profile.encode(),
      recentContextJson: recentContextJson,
      outputMode: outputMode,
    );
    try {
      final text = await _ai.generateText(
        prompt: prompt,
        purpose: 'defense_compass.self_defense_analysis',
        maxTokens: 4200,
        expectJson: true,
        temperature: 0.24,
      );
      final parsed = _tryParse(text, scene: scene, userInput: userInput, outputMode: outputMode);
      if (parsed != null && (parsed.aiResponse.trim().isNotEmpty || parsed.eventSummary.trim().isNotEmpty)) {
        return parsed;
      }
    } catch (_) {}
    return fallback;
  }

  DefenseCompassSession localAnalyze({
    required String scene,
    required String userInput,
    required DefenseCompassProfile profile,
    required String recentContextJson,
    String outputMode = 'standard',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final input = userInput.trim().isEmpty ? '我今天遇到一件让我很有反应的事情，但暂时说不清楚。' : userInput.trim();
    final risk = _detectRisk(input);
    if (risk == 'high' || risk == 'crisis' || scene == 'safety') {
      final response = '''【安全优先】
你现在的描述可能包含较高风险。此刻不适合继续深挖防御机制或创伤细节，优先目标是确保你不独自承受风险。

【先做三步】
1. 远离可能伤害自己或他人的工具、地点或情境。
2. 立刻联系一个具体的可信任的人，告诉对方：我现在不安全/很失控，需要你陪我。
3. 如果存在即时危险，请联系当地紧急服务或专业危机支持。

【提醒】
这不是诊断；AI 不能替代紧急支持。等安全稳定后，再回到自我防御罗盘做温和复盘。''';
      return DefenseCompassSession(
        createdAtMs: now,
        updatedAtMs: now,
        scene: 'safety',
        outputMode: outputMode,
        userInput: input,
        aiResponse: response,
        eventSummary: '用户可能处在安全风险或强烈失控状态。',
        emotions: const <String>['危机感', '失控感'],
        primaryAnxietySource: '安全风险',
        anxietyExplanation: '当前优先任务不是解释防御，而是确保现实安全与专业/人际支持。',
        defenseMechanisms: const <String>['暂停深度分析'],
        protectiveFunction: '保护用户免于在高风险状态下继续暴露于无法承受的材料。',
        longTermCost: '若长期独自承受风险，可能加重功能受损；需要真实支持。',
        realityCheck: '现在是否有一个可以立刻联系的人？是否需要紧急服务？',
        microAction: '立刻联系一个可信任的人，或在即时危险时联系当地紧急服务。',
        outputCardType: 'safety_support',
        riskLevel: risk,
        rawJson: '{}',
      );
    }

    final emotions = _detectEmotions(input, scene);
    final hidden = _detectHiddenEmotions(input, emotions);
    final wishes = _detectWishes(input, scene);
    final prohibitions = _detectSuperego(input);
    final anxiety = _detectAnxietySource(input, scene, emotions, prohibitions);
    final defenses = _detectDefenses(input, scene, anxiety);
    final action = _buildMicroAction(scene: scene, input: input, defenses: defenses, anxiety: anxiety);
    final cardType = _cardTypeFor(scene, outputMode);
    final facts = _factsGuess(input);
    final interpretation = _interpretationGuess(input);
    final external = _externalReality(input, scene);
    final evidence = _defenseEvidence(defenses, input);
    final protective = _protectiveFunction(defenses, anxiety);
    final cost = _longTermCost(defenses);
    final reality = _realityCheck(scene, defenses, input);
    final summary = _summary(input, scene);
    final response = _composeResponse(
      scene: scene,
      summary: summary,
      facts: facts,
      interpretation: interpretation,
      emotions: emotions,
      hidden: hidden,
      wishes: wishes,
      prohibitions: prohibitions,
      external: external,
      anxiety: anxiety,
      defenses: defenses,
      evidence: evidence,
      protective: protective,
      cost: cost,
      reality: reality,
      action: action,
    );
    final json = <String, dynamic>{
      'scene': scene,
      'output_card_type': cardType,
      'risk_level': risk,
      'event_summary': summary,
      'facts': facts,
      'interpretation': interpretation,
      'emotions': emotions,
      'hidden_emotions': hidden,
      'id_wishes': wishes,
      'superego_prohibitions': prohibitions,
      'external_reality': external,
      'primary_anxiety_source': anxiety,
      'anxiety_explanation': _anxietyExplanation(anxiety),
      'defense_mechanisms': defenses,
      'defense_evidence': evidence,
      'protective_function': protective,
      'long_term_cost': cost,
      'reality_check': reality,
      'micro_action': action,
      'ai_response': response,
    };
    return DefenseCompassSession.fromJson(json, userInput: input, scene: scene, outputMode: outputMode).copyWith(
      createdAtMs: now,
      updatedAtMs: now,
      rawJson: jsonEncode(json),
    );
  }

  DefenseCompassSession? _tryParse(String raw, {required String scene, required String userInput, required String outputMode}) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return null;
      return DefenseCompassSession.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
        userInput: userInput,
        scene: scene,
        outputMode: outputMode,
      ).copyWith(rawJson: jsonText);
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

  String _detectRisk(String input) {
    final t = input.toLowerCase();
    const crisis = ['自杀', '不想活', '结束生命', '伤害自己', '伤害别人', '杀了', 'suicide', 'kill myself', 'kill him', 'kill her'];
    if (crisis.any(t.contains)) return 'crisis';
    const high = ['活不下去', '撑不下去', '控制不住', '毁掉', '报复', '消失', '分不清现实', '有人控制我'];
    if (high.any(t.contains)) return 'high';
    const medium = ['崩溃', '失眠', '惊恐', '快疯了', '麻木到不行'];
    if (medium.any(t.contains)) return 'medium';
    return 'none';
  }

  List<String> _detectEmotions(String input, String scene) {
    const all = ['焦虑', '害怕', '恐惧', '愤怒', '生气', '羞耻', '尴尬', '内疚', '自责', '嫉妒', '羡慕', '难过', '悲伤', '失望', '孤独', '空虚', '委屈', '麻木', '厌烦', '无力'];
    final found = <String>[];
    for (final e in all) {
      if (input.contains(e)) found.add(e);
    }
    if (found.isNotEmpty) return found.take(4).toList(growable: false);
    if (scene == 'relationship_defense') return const <String>['委屈', '愤怒'];
    if (scene == 'self_limitation') return const <String>['害怕失败', '羞耻'];
    if (scene == 'affect_tolerance') return const <String>['强烈情绪'];
    return const <String>['紧张', '不确定'];
  }

  List<String> _detectHiddenEmotions(String input, List<String> emotions) {
    final hidden = <String>[];
    if (!emotions.contains('羞耻') && (input.contains('失败') || input.contains('不行') || input.contains('丢脸'))) hidden.add('羞耻');
    if (!emotions.contains('嫉妒') && (input.contains('别人') && (input.contains('更好') || input.contains('比较')))) hidden.add('嫉妒');
    if (!emotions.contains('愤怒') && (input.contains('不公平') || input.contains('被否定') || input.contains('被控制'))) hidden.add('愤怒');
    if (!emotions.contains('悲伤') && (input.contains('无所谓') || input.contains('没关系'))) hidden.add('失望/悲伤');
    return hidden.isEmpty ? const <String>['可能还有尚未命名的不快情绪'] : hidden.take(3).toList(growable: false);
  }

  List<String> _detectWishes(String input, String scene) {
    final wishes = <String>[];
    if (input.contains('认可') || input.contains('看见') || input.contains('肯定')) wishes.add('被看见/被认可');
    if (input.contains('爱') || input.contains('在乎') || input.contains('陪')) wishes.add('被爱/被在乎');
    if (input.contains('赢') || input.contains('成功') || input.contains('优秀') || input.contains('证明')) wishes.add('成功/证明自己');
    if (input.contains('拒绝') || input.contains('边界') || input.contains('不想')) wishes.add('拒绝/保护边界');
    if (input.contains('生气') || input.contains('愤怒') || input.contains('不公平')) wishes.add('表达攻击性或不满');
    if (input.contains('自由') || input.contains('离开') || input.contains('逃')) wishes.add('自由/离开压力');
    if (scene == 'altruistic_surrender') wishes.add('把属于自己的愿望收回一点');
    if (wishes.isEmpty) wishes.add('被理解并恢复行动选择');
    return wishes.take(4).toList(growable: false);
  }

  List<String> _detectSuperego(String input) {
    final list = <String>[];
    if (input.contains('不应该') || input.contains('不能')) list.add('我不应该/不能有这种反应');
    if (input.contains('自私')) list.add('我不能自私');
    if (input.contains('必须') || input.contains('一定要')) list.add('我必须达到某个标准');
    if (input.contains('懂事') || input.contains('应该体谅')) list.add('我必须懂事、体谅别人');
    if (input.contains('脆弱') || input.contains('依赖')) list.add('我不能脆弱或依赖');
    if (list.isEmpty) list.add('我可能有一个要求自己必须表现得合理/坚强的内在声音');
    return list.take(4).toList(growable: false);
  }

  String _detectAnxietySource(String input, String scene, List<String> emotions, List<String> superego) {
    if (scene == 'safety') return '安全风险';
    if (input.contains('不应该') || input.contains('内疚') || input.contains('自责') || input.contains('自私') || superego.any((e) => e.contains('必须'))) {
      return '超我焦虑';
    }
    if (input.contains('惩罚') || input.contains('离开我') || input.contains('嘲笑') || input.contains('领导') || input.contains('父母') || input.contains('后果')) {
      return '客观现实焦虑';
    }
    if (input.contains('控制不住') || input.contains('太想') || input.contains('淹没') || input.contains('失控')) {
      return '本能强度焦虑';
    }
    if (emotions.any((e) => e.contains('羞耻') || e.contains('嫉妒') || e.contains('悲伤') || e.contains('失望'))) {
      return '情感不快焦虑';
    }
    if (input.contains('一方面') || input.contains('又想') || input.contains('矛盾') || input.contains('既想')) {
      return '自我综合焦虑';
    }
    if (scene == 'transition') return '本能强度焦虑';
    return '情感不快焦虑';
  }

  List<String> _detectDefenses(String input, String scene, String anxiety) {
    final d = <String>[];
    if (input.contains('想不起来') || input.contains('没感觉') || input.contains('不知道为什么')) d.add('压抑/隔离');
    if (input.contains('无所谓') || input.contains('没关系') || input.contains('一点也不')) d.add('否认');
    if (input.contains('他肯定') || input.contains('他们一定') || input.contains('别人都')) d.add('投射');
    if (input.contains('特别客气') || input.contains('特别好') || input.contains('特别道德')) d.add('反向形成');
    if (input.contains('怪自己') || input.contains('我太差') || input.contains('攻击自己') || input.contains('自责')) d.add('转向自身');
    if (input.contains('不做了') || input.contains('放弃') || input.contains('退出') || scene == 'self_limitation') d.add('自我限制');
    if (input.contains('变得像') || input.contains('先攻击') || input.contains('控制别人')) d.add('认同攻击者');
    if (input.contains('帮别人') || input.contains('为别人争取') || scene == 'altruistic_surrender') d.add('利他性让渡');
    if (input.contains('一直想') || input.contains('道理') || input.contains('人生意义') || scene == 'transition') d.add('理智化');
    if (input.contains('不配享受') || input.contains('不能放松') || input.contains('所有欲望')) d.add('禁欲主义');
    if (scene == 'reality_check') d.add('现实检验不足/投射假设');
    if (scene == 'affect_tolerance') d.add('情感防御');
    if (d.isEmpty) {
      if (anxiety == '超我焦虑') d.add('压抑/反向形成');
      else if (anxiety == '客观现实焦虑') d.add('否认/自我限制');
      else if (anxiety == '本能强度焦虑') d.add('理智化/禁欲主义');
      else d.add('情感隔离/回避');
    }
    return d.toSet().take(4).toList(growable: false);
  }

  String _cardTypeFor(String scene, String outputMode) {
    if (scene == 'safety' || outputMode == 'safety') return 'safety_support';
    if (scene == 'reality_check' || outputMode == 'reality') return 'reality_check';
    if (scene == 'affect_tolerance' || outputMode == 'emotion') return 'emotion_tolerance';
    if (scene == 'wish_integration' || outputMode == 'wish') return 'wish_integration';
    if (scene == 'self_limitation' || outputMode == 'self_limitation') return 'self_limitation_breakthrough';
    if (scene == 'relationship_defense' || outputMode == 'relationship') return 'relationship_communication';
    if (scene == 'altruistic_surrender' || outputMode == 'altruistic') return 'altruistic_boundary';
    if (scene == 'transition' || outputMode == 'transition') return 'transition_stability';
    if (scene == 'family_education' || outputMode == 'family') return 'family_education_response';
    if (scene == 'monthly_review' || outputMode == 'monthly') return 'monthly_report';
    if (scene == 'closure_audit' || outputMode == 'closure') return 'closure_audit';
    if (scene == 'action_review' || outputMode == 'action_review') return 'action_review';
    if (scene == 'action_generation' || outputMode == 'action') return 'action_card';
    if (scene == 'profile_update' || outputMode == 'profile') return 'profile_update';
    return 'standard_analysis';
  }

  String _buildMicroAction({required String scene, required String input, required List<String> defenses, required String anxiety}) {
    if (scene == 'reality_check' || defenses.any((d) => d.contains('投射'))) {
      return '用 5 分钟写下“我确认知道的事实”和“我正在猜测的解释”，再选择一个低风险方式验证其中一条。';
    }
    if (scene == 'affect_tolerance' || anxiety == '情感不快焦虑') {
      return '做 90 秒情绪停留：命名情绪、感受身体位置、提醒自己“情绪不是行动”。';
    }
    if (scene == 'wish_integration' || anxiety == '超我焦虑') {
      return '写一句“我其实想要……”，再把它改写成一个不攻击、不讨好的成熟请求。';
    }
    if (scene == 'self_limitation' || defenses.any((d) => d.contains('自我限制'))) {
      return '选择一个曾回避的领域，做 5 分钟不公开、不比较的最小恢复练习。';
    }
    if (scene == 'relationship_defense') {
      return '给关系对象写一句事实+感受+需求的话，先不发送，只检查是否不攻击、不讨好、不压抑。';
    }
    if (scene == 'altruistic_surrender') {
      return '今天为自己提出一个很小的偏好或请求，不把全部力量交给别人。';
    }
    if (scene == 'action_review') {
      return '复盘这次行动：记录现实发生了什么、防御是否松动、下一步是否需要降低难度。';
    }
    if (scene == 'closure_audit') {
      return '补齐一个闭环缺口：完成一次行动复盘、更新个人防御地图，或生成一份月度成长报告。';
    }
    if (scene == 'transition') {
      return '把一个抽象人生问题落到一个 10 分钟身份小实验：做一件能代表新方向的小事。';
    }
    return '在今天结束前完成一个 10 分钟内可开始的小行动：命名一个情绪、验证一个事实、表达一个小需求。';
  }

  String _factsGuess(String input) => input.length > 80 ? '${input.substring(0, 80)}…' : input;

  String _interpretationGuess(String input) {
    if (input.contains('肯定') || input.contains('一定')) return '描述中可能包含对他人想法或未来后果的确定化解释，需要现实检验。';
    if (input.contains('无所谓') || input.contains('没关系')) return '“无所谓/没关系”可能是真实感受，也可能是在保护自己免于失望。';
    return '目前解释需要和事实分开看，先把它当作自我保护下的理解假设。';
  }

  String _externalReality(String input, String scene) {
    if (input.contains('领导') || input.contains('父母') || input.contains('老师')) return '存在权威或评价压力，需要区分真实后果与预期惩罚。';
    if (input.contains('朋友') || input.contains('伴侣') || input.contains('同事')) return '存在关系压力，需要区分对方实际行为与内在猜测。';
    if (scene == 'self_limitation') return '现实中可能存在比较、失败、被嘲笑或被嫉妒的风险，但风险大小需要验证。';
    return '外部现实需要继续补充：发生了什么、谁参与、可确认后果是什么。';
  }

  String _defenseEvidence(List<String> defenses, String input) => defenses.isEmpty
      ? '目前只能把防御作为观察假设。'
      : '依据包括用户描述中的情绪回避、确定化解释、退出/自责/过度帮助等线索；需要继续用现实记录验证。';

  String _protectiveFunction(List<String> defenses, String anxiety) {
    if (defenses.any((d) => d.contains('投射'))) return '帮助用户暂时不用承认自己的敌意、需求、嫉妒或担忧，把痛苦放到外部。';
    if (defenses.any((d) => d.contains('自我限制'))) return '帮助用户避免失败、比较、羞辱或被攻击的痛苦。';
    if (defenses.any((d) => d.contains('利他'))) return '帮助用户间接保存愿望，同时避免为自己争取带来的罪疚或羞耻。';
    if (defenses.any((d) => d.contains('理智化'))) return '把强烈情绪或冲动转化为抽象思考，让自我感觉更可控。';
    if (anxiety == '超我焦虑') return '减少内疚、自责和“我不应该这样”的内在惩罚。';
    return '帮助用户短期降低不快、焦虑或失控感。';
  }

  String _longTermCost(List<String> defenses) {
    if (defenses.any((d) => d.contains('投射'))) return '可能误解别人、关系紧张，并让现实检验变弱。';
    if (defenses.any((d) => d.contains('自我限制'))) return '可能让能力领域萎缩，人生选择变窄。';
    if (defenses.any((d) => d.contains('利他'))) return '可能让自己的愿望长期被交给别人，边界和自我需求变弱。';
    if (defenses.any((d) => d.contains('理智化'))) return '可能停留在想明白，却无法真正感受和行动。';
    if (defenses.any((d) => d.contains('转向自身'))) return '可能把对外界的愤怒变成自责，增加内耗。';
    return '如果长期僵化，可能让用户越来越依赖旧的保护方式，而减少现实行动选择。';
  }

  String _realityCheck(String scene, List<String> defenses, String input) {
    if (scene == 'reality_check' || defenses.any((d) => d.contains('投射'))) return '我现在确认知道的事实是什么？哪些只是我根据过去经验做出的猜测？';
    if (defenses.any((d) => d.contains('否认'))) return '如果这件事其实影响了我，最难承认的部分是什么？';
    if (defenses.any((d) => d.contains('自我限制'))) return '我是真的不喜欢，还是为了避免失败/羞辱而退出？';
    return '这个判断有没有证据？有没有一种更温和但仍现实的替代解释？';
  }

  String _anxietyExplanation(String anxiety) {
    switch (anxiety) {
      case '超我焦虑':
        return '用户可能害怕愿望或情绪违反内在禁令，引发内疚、自责或羞耻。';
      case '客观现实焦虑':
        return '用户可能害怕外部惩罚、失爱、失败、嘲笑或权威否定。';
      case '本能强度焦虑':
        return '用户可能害怕冲动、欲望或情绪太强，一旦承认就会失控。';
      case '自我综合焦虑':
        return '用户可能同时拥有多个真实但矛盾的自我部分，担心破坏自我一致性。';
      case '情感不快焦虑':
      default:
        return '用户可能主要在防御羞耻、嫉妒、悲伤、失望或恐惧等难以承受的情绪。';
    }
  }

  String _summary(String input, String scene) {
    final prefix = scene == 'monthly_review'
        ? '这是一段阶段性复盘。'
        : scene == 'family_education'
            ? '这是一个家庭/教育场景。'
            : '这是一次现实事件记录。';
    final clean = input.replaceAll('\n', ' ').trim();
    return '$prefix ${clean.length > 90 ? '${clean.substring(0, 90)}…' : clean}';
  }

  String _composeResponse({
    required String scene,
    required String summary,
    required String facts,
    required String interpretation,
    required List<String> emotions,
    required List<String> hidden,
    required List<String> wishes,
    required List<String> prohibitions,
    required String external,
    required String anxiety,
    required List<String> defenses,
    required String evidence,
    required String protective,
    required String cost,
    required String reality,
    required String action,
  }) {
    return '''【事件摘要】
$summary

【事实与解释】
事实：$facts
解释：$interpretation
缺失信息：$external

【主要情绪】
显性情绪：${emotions.join('、')}
可能被防御的隐性情绪：${hidden.join('、')}

【自我三方地图】
本我愿望：${wishes.join('、')}
超我禁令：${prohibitions.join('、')}
外部现实压力：$external
自我防御：${defenses.join('、')}

【主要焦虑来源】
可能来源：$anxiety
依据：${_anxietyExplanation(anxiety)}

【可能的防御机制】
${defenses.map((d) => '- $d：$evidence').join('\n')}

【它保护了你】
$protective

【它可能限制你】
$cost

【现实检验】
$reality

【今日小行动】
$action

【提醒】
这不是诊断，只是基于《自我与防御机制》的自我观察假设。目标不是羞辱或拆除防御，而是让你多一个更灵活的选择。''';
  }
}
