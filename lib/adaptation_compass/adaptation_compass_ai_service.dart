import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'adaptation_compass_models.dart';
import 'adaptation_compass_prompt_config.dart';

class AdaptationCompassAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final AdaptationCompassPromptConfig _prompts = AdaptationCompassPromptConfig();

  Future<AdaptationCompassSession> generate({
    required String scene,
    required String userInput,
    required AdaptationCompassProfile profile,
    required String recentContextJson,
  }) async {
    final fallback = localAnalyze(scene: scene, userInput: userInput);
    final prompt = await _prompts.buildPrompt(
      scene: scene,
      userInput: userInput,
      profileJson: profile.encode(),
      recentContextJson: recentContextJson,
    );
    try {
      final text = await _ai.generateText(
        prompt: prompt,
        purpose: 'adaptation_compass.mature_adaptation_analysis',
        maxTokens: 5200,
        expectJson: true,
        temperature: 0.23,
      );
      final parsed = _tryParse(text, scene: scene, userInput: userInput);
      if (parsed != null && (parsed.aiResponse.trim().isNotEmpty || parsed.eventSummary.trim().isNotEmpty)) {
        return parsed;
      }
    } catch (_) {}
    return fallback;
  }

  AdaptationCompassSession? _tryParse(String raw, {required String scene, required String userInput}) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return null;
      return AdaptationCompassSession.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
        userInput: userInput,
        scene: scene,
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

  AdaptationCompassSession localAnalyze({required String scene, required String userInput}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final input = userInput.trim().isEmpty ? '我今天有一个说不清的压力事件，想理解自己如何适应。' : userInput.trim();
    final risk = _detectRisk(input, scene);
    if (risk == 'high' || risk == 'crisis' || scene == 'safety_support') {
      final response = '''【1. 温和概括】
你现在的描述可能涉及较高风险。此刻最重要的不是继续分析防御机制，而是先确保现实安全。

【2. 事实与解释】
如果你有伤害自己或他人的冲动、已经失控、或身处暴力/威胁情境，请把“立刻降低风险”放在第一位。

【3. 可能的适应方式】
当前不需要给自己贴任何标签。强烈冲动可能是在帮你逃离无法承受的痛苦，但它不应该驾驶接下来的行为。

【4. 它保护了什么】
它可能在保护你不被痛苦淹没。

【5. 它可能带来的代价】
如果独自承受或立刻行动，可能带来无法逆转的伤害。

【6. 成熟替代方向】
现在的成熟回应是：暂停深挖、远离危险物品或场所、联系真实的人。

【7. 具体行动】
10 分钟：远离可能伤害自己或他人的工具/地点，把手机拿在手上，联系一个可信任的人。
24 小时：联系专业人员、危机热线、急诊或当地紧急服务，告诉对方你需要现实支持。
7 天：建立一个安全计划，包括触发信号、可联系名单、专业资源和替代行动。

【8. 关系影响】
让一个真实的人知道你正在承受风险，比独自撑住更成熟。

【9. 长期成长问题】
当你安全后，再回来问：我当时的冲动在替我逃离什么痛苦？

【10. 安全提醒】
AI 不能替代紧急服务、专业医疗或危机干预。如果存在即时危险，请联系当地紧急服务或身边可信任的人。''';
      return AdaptationCompassSession(
        createdAtMs: now,
        updatedAtMs: now,
        scene: 'safety_support',
        userInput: input,
        aiResponse: response,
        eventSummary: '用户可能处于高风险或急性失控情境。',
        facts: '当前优先事项是确认现实安全。',
        interpretation: '不做普通成长分析。',
        emotions: const <String>['危机感', '失控感'],
        bodySignals: const <String>['高唤起或崩溃风险'],
        needs: const <String>['安全', '陪伴', '专业支持'],
        defenseLayer: '严重现实歪曲风险/危机支持',
        defenseMechanisms: const <String>['暂停深度分析'],
        protectiveFunction: '保护用户不在高风险状态下继续暴露于无法承受的材料。',
        longTermCost: '如果继续独自承受或立刻行动，风险可能升级。',
        realityCheck: '现在是否安全？是否可以立即联系一个真实的人或当地紧急服务？',
        matureAlternatives: const <String>['安全支持', '联系可信任的人', '专业/紧急资源'],
        action10m: '远离危险物品或地点，并联系一个可信任的人。',
        action24h: '联系专业人员、危机热线、急诊或当地紧急服务。',
        action7d: '建立书面安全计划：触发信号、联系人、专业资源和替代行动。',
        relationshipImpact: '主动求助会减少孤立，增加现实支持。',
        growthQuestion: '安全后再复盘：这个冲动在替我逃离什么痛苦？',
        riskLevel: risk,
        rawJson: '{}',
      );
    }

    final emotions = _detectEmotions(input, scene);
    final body = _detectBody(input);
    final needs = _detectNeeds(input, scene);
    final defenses = _detectDefenses(input, scene);
    final layer = _defenseLayer(defenses, scene, input);
    final alternatives = _alternatives(scene, defenses);
    final facts = _factsGuess(input);
    final interpretation = _interpretationGuess(input);
    final summary = _summary(input, scene);
    final protective = _protectiveFunction(defenses, scene);
    final cost = _longTermCost(layer, defenses, scene);
    final reality = _realityCheck(scene, input);
    final action10 = _action10(scene, alternatives);
    final action24 = _action24(scene, alternatives);
    final action7 = _action7(scene, alternatives);
    final relation = _relationshipImpact(scene, defenses);
    final task = _developmentTask(scene, input);
    final balance = _balanceFocus(scene, input);
    final generativity = _generativity(scene, input);
    final question = _growthQuestion(scene);

    final response = _composeMarkdown(
      summary: summary,
      facts: facts,
      interpretation: interpretation,
      emotions: emotions,
      body: body,
      defenses: defenses,
      layer: layer,
      protective: protective,
      cost: cost,
      reality: reality,
      alternatives: alternatives,
      action10: action10,
      action24: action24,
      action7: action7,
      relation: relation,
      question: question,
    );
    final json = <String, dynamic>{
      'scene': scene,
      'risk_level': risk,
      'event_summary': summary,
      'facts': facts,
      'interpretation': interpretation,
      'emotions': emotions,
      'body_signals': body,
      'needs': needs,
      'defense_layer': layer,
      'defense_mechanisms': defenses,
      'protective_function': protective,
      'long_term_cost': cost,
      'reality_check': reality,
      'mature_alternatives': alternatives,
      'action_10m': action10,
      'action_24h': action24,
      'action_7d': action7,
      'relationship_impact': relation,
      'development_task': task,
      'balance_focus': balance,
      'generativity_step': generativity,
      'growth_question': question,
      'ai_response': response,
    };
    return AdaptationCompassSession.fromJson(json, userInput: input, scene: scene).copyWith(
      createdAtMs: now,
      updatedAtMs: now,
      rawJson: jsonEncode(json),
    );
  }

  String _detectRisk(String input, String scene) {
    final t = input.toLowerCase();
    const crisis = ['自杀', '不想活', '结束生命', '伤害自己', '伤害别人', '杀了', 'suicide', 'kill myself', 'kill him', 'kill her'];
    if (crisis.any(t.contains)) return 'crisis';
    const high = ['活不下去', '撑不下去', '控制不住', '毁掉', '报复', '消失', '分不清现实', '有人控制我', '被威胁', '家暴'];
    if (high.any(t.contains)) return 'high';
    const medium = ['崩溃', '失眠', '惊恐', '快疯了', '麻木到不行', '喝酒停不下'];
    if (medium.any(t.contains) || scene == 'acting_out') return 'medium';
    return 'none';
  }

  List<String> _detectEmotions(String input, String scene) {
    const all = ['焦虑', '害怕', '恐惧', '愤怒', '生气', '羞耻', '尴尬', '内疚', '自责', '嫉妒', '羡慕', '难过', '悲伤', '失望', '孤独', '空虚', '委屈', '麻木', '厌烦', '无力', '压力'];
    final found = <String>[];
    for (final e in all) {
      if (input.contains(e)) found.add(e);
    }
    if (found.isNotEmpty) return found.take(4).toList(growable: false);
    switch (scene) {
      case 'anger_transform': return const <String>['愤怒', '受伤'];
      case 'shame_failure': return const <String>['羞耻', '自责'];
      case 'relationship_conflict': return const <String>['委屈', '防御'];
      case 'high_functioning': return const <String>['空洞', '麻木'];
      case 'generativity': return const <String>['意义感需求'];
      default: return const <String>['紧张', '不确定'];
    }
  }

  List<String> _detectBody(String input) {
    const all = ['胸闷', '胃痛', '胃紧', '头痛', '失眠', '心慌', '发抖', '僵住', '想哭', '疲惫', '发冷', '呼吸', '紧绷', '喝酒', '身体'];
    final found = <String>[];
    for (final e in all) {
      if (input.contains(e)) found.add(e);
    }
    return found.isEmpty ? const <String>['可补充：睡眠、呼吸、肌肉紧张、胃部或胸口反应'] : found.take(4).toList(growable: false);
  }

  List<String> _detectNeeds(String input, String scene) {
    final needs = <String>[];
    if (input.contains('否定') || input.contains('批评') || input.contains('失败')) needs.add('被认真看见与被具体反馈');
    if (input.contains('不公平') || input.contains('控制')) needs.add('边界与尊重');
    if (input.contains('孤独') || scene.contains('relationship') || scene.contains('intimacy')) needs.add('真实连接');
    if (input.contains('累') || input.contains('身体') || input.contains('失眠')) needs.add('身体恢复');
    if (scene == 'generativity') needs.add('意义与贡献');
    if (needs.isEmpty) needs.add('安全、现实感和可执行下一步');
    return needs.take(4).toList(growable: false);
  }

  List<String> _detectDefenses(String input, String scene) {
    final out = <String>[];
    if (input.contains('他就是') || input.contains('他们都') || input.contains('针对我') || input.contains('一定是')) out.add('投射/单一动机解释');
    if (input.contains('不想见') || input.contains('逃') || input.contains('消失') || input.contains('拖延')) out.add('回避/退缩');
    if (input.contains('骂') || input.contains('删') || input.contains('辞职') || input.contains('喝酒') || input.contains('报复')) out.add('行动化冲动');
    if (input.contains('分析') || input.contains('道理') || input.contains('逻辑') || scene == 'high_functioning') out.add('理智化');
    if (input.contains('没事') || input.contains('无所谓') || input.contains('不在乎')) out.add('压抑/情感隔离');
    if (input.contains('帮别人') || input.contains('总是照顾')) out.add('利他可能带边界风险');
    if (scene == 'anger_transform' && !out.contains('行动化冲动')) out.add('攻击性未整合');
    if (scene == 'relationship_conflict' && out.isEmpty) out.add('关系防御：回避/投射/讨好待检验');
    if (scene == 'work_consolidation' && out.isEmpty) out.add('职业自尊防御');
    if (scene == 'childhood_climate' && out.isEmpty) out.add('早年形成的保护性适应');
    if (out.isEmpty) out.add('暂时性抑制/防御不明');
    return out.take(4).toList(growable: false);
  }

  String _defenseLayer(List<String> defenses, String scene, String input) {
    if (scene == 'acting_out' || defenses.any((d) => d.contains('行动化'))) return '不成熟防御';
    if (defenses.any((d) => d.contains('投射') || d.contains('回避'))) return '不成熟防御';
    if (defenses.any((d) => d.contains('理智化') || d.contains('压抑') || d.contains('隔离'))) return '神经症性防御';
    if (defenses.any((d) => d.contains('利他'))) return '成熟防御（需边界）';
    return '未判断/混合适应';
  }

  List<String> _alternatives(String scene, List<String> defenses) {
    switch (scene) {
      case 'anger_transform': return const <String>['边界表达', '升华', '身体释放', '现实改变'];
      case 'shame_failure': return const <String>['现实检查', '自我慈悲', '修复行动'];
      case 'anxiety_fear': return const <String>['预期', '身体稳定', '求助', '风险拆解'];
      case 'relationship_conflict': return const <String>['关系修复', '边界表达', '事实-解释分离'];
      case 'work_consolidation': return const <String>['预期', '升华', '职业巩固行动'];
      case 'balance_four': return const <String>['工作-爱-游戏-身体平衡', '游戏恢复', '身体稳定'];
      case 'generativity': return const <String>['生成性行动', '有边界的利他', '经验转贡献'];
      case 'acting_out': return const <String>['冲动延迟', '身体稳定', '联系支持', '替代行动'];
      default:
        if (defenses.any((d) => d.contains('理智化'))) return const <String>['情绪命名', '身体扫描', '小剂量真实表达'];
        if (defenses.any((d) => d.contains('投射'))) return const <String>['现实检查', '低风险验证', '边界沟通'];
        return const <String>['现实检查', '预期', '抑制', '关系修复'];
    }
  }

  String _factsGuess(String input) => '可确认事实：${_short(input)}。请继续把第三方可观察的事实与自己的解释分开。';
  String _interpretationGuess(String input) => input.contains('一定') || input.contains('就是') ? '目前有较强解释/判断成分，需要验证对方动机和缺失信息。' : '目前解释尚可继续细化：哪些是事实，哪些是恐惧或旧经验被触发。';
  String _summary(String input, String scene) => '${_sceneName(scene)}：你正在尝试理解一个现实压力下的适应反应。';
  String _short(String s) => s.length > 80 ? '${s.substring(0, 80)}…' : s;

  String _protectiveFunction(List<String> defenses, String scene) {
    if (defenses.any((d) => d.contains('投射'))) return '它可能保护你不必立刻承认受伤、愤怒、依赖或不确定感。';
    if (defenses.any((d) => d.contains('行动化'))) return '它可能快速降低痛苦张力，让你感觉自己重新有力量。';
    if (defenses.any((d) => d.contains('理智化'))) return '它保护你的秩序感和责任感，让你在压力下仍能运转。';
    if (defenses.any((d) => d.contains('压抑'))) return '它让你暂时不被痛苦淹没，维持体面和功能。';
    if (scene == 'generativity') return '把痛苦转为贡献，可以让经历进入意义和关系。';
    return '它可能是在保护安全感、自尊和可控感。';
  }

  String _longTermCost(String layer, List<String> defenses, String scene) {
    if (layer.contains('不成熟')) return '如果长期依赖这种方式，可能损害现实感、亲密关系、工作选择和身体安全。';
    if (layer.contains('神经')) return '它能维持功能，但可能牺牲快乐、游戏、真实表达和亲密。';
    if (scene == 'generativity') return '如果缺少边界，贡献可能滑向讨好、控制或过度牺牲。';
    return '如果不复盘，短期保护可能变成长期僵化。';
  }

  String _realityCheck(String scene, String input) {
    if (scene == 'reality_check') return '请列出：已确认事实、我脑中的解释、最害怕版本、最希望版本、仍缺失的信息、一个低风险验证动作。';
    if (scene == 'relationship_conflict') return '先问：对方实际做了什么？我理解成了什么？有什么证据？我需要表达什么请求或边界？';
    if (scene == 'anxiety_fear') return '把担忧拆成：最坏情况、最可能情况、可准备事项、可求助的人、一个现在可做动作。';
    return '把事件拆成三栏：事实、解释、可行动部分。先验证现实，再决定行动。';
  }

  String _action10(String scene, List<String> alternatives) {
    if (scene == 'acting_out') return '先延迟 10 分钟，离开诱发环境，喝水/洗脸/走动，并给一个可信任的人发消息。';
    if (scene == 'anger_transform') return '写下三句：我愤怒是因为我在保护什么边界；我不能做的破坏性动作；我能做的成熟动作。';
    if (scene == 'relationship_conflict') return '写一句不控诉的话：当……发生时，我感到……我需要……我请求……';
    if (scene == 'anxiety_fear') return '做 3 分钟呼吸或走动，然后写下一个可准备事项和一个可求助的人。';
    if (scene == 'balance_four') return '给工作、爱、游戏、身体各打 0-10 分，并圈出今天最弱的一项。';
    return '写下三栏：事实、解释、下一步可行动作。';
  }

  String _action24(String scene, List<String> alternatives) {
    if (scene == 'work_consolidation') return '向相关人索要一个具体反馈，或把任务拆成一个 30 分钟可完成版本。';
    if (scene == 'relationship_conflict') return '选择一个安全时段，发送或说出一段“事实 + 感受 + 需要 + 请求”的修复表达。';
    if (scene == 'body_health') return '安排睡眠、饮食、运动或医学评估中的一个具体动作，不把身体问题简单心理化。';
    if (scene == 'generativity') return '把你的一个经验整理成一段可以帮助他人的文字或语音。';
    if (scene == 'anxiety_fear') return '完成一个具体准备动作，并向一个可信任的人说明你正在担心什么。';
    return '完成一个能减少现实混乱的小行动，并记录行动前后情绪变化。';
  }

  String _action7(String scene, List<String> alternatives) {
    if (scene == 'high_functioning') return '安排三次非功利活动：一次运动/散步、一次真实联系、一次纯粹游戏或创造。';
    if (scene == 'childhood_climate') return '写一封“旧防御感谢信”：感谢它曾保护我，再写一个现在可以发展的新适应。';
    if (scene == 'generativity') return '完成一个有边界的贡献行动，并复盘它是否也滋养了你。';
    if (scene == 'anxiety_fear') return '连续 7 天观察一个恐惧主题：它在提醒我预期什么，而不是证明我无能。';
    return '连续 7 天观察同一触发器：旧防御出现在哪里？哪一次我做出了更成熟回应？';
  }

  String _relationshipImpact(String scene, List<String> defenses) {
    if (scene == 'relationship_conflict' || scene == 'intimacy_avoidance') return '成熟回应不是压抑自己，而是在保护边界的同时保留修复可能。';
    if (defenses.any((d) => d.contains('投射'))) return '减少单一动机解释，会让关系多一点验证和少一点误伤。';
    if (defenses.any((d) => d.contains('理智化'))) return '把一点真实感受带入关系，会让别人接触到你的生命力，而不仅是功能面。';
    return '把洞察转化为具体表达和行动，会减少孤立。';
  }

  String _developmentTask(String scene, String input) {
    if (scene == 'work_consolidation') return '职业巩固';
    if (scene == 'relationship_conflict' || scene == 'intimacy_avoidance') return '亲密';
    if (scene == 'generativity') return '生成性';
    if (scene == 'life_stage_review') return '身份/亲密/职业巩固/生成性/意义守护/生命整合待辨认';
    if (input.contains('中年') || input.contains('孩子') || input.contains('父母')) return '生成性或意义守护';
    return '当前可能涉及现实适应与自我整合';
  }

  String _balanceFocus(String scene, String input) {
    if (scene == 'balance_four') return '工作、爱、游戏、身体四维中评分最低的一项';
    if (input.contains('累') || input.contains('失眠') || input.contains('身体')) return '身体';
    if (input.contains('孤独') || input.contains('关系')) return '爱';
    if (scene == 'high_functioning') return '游戏与爱';
    return '现实行动与关系连接';
  }

  String _generativity(String scene, String input) {
    if (scene == 'generativity') return '把一个痛苦经验转化为可分享的帮助，同时保留边界。';
    return '可选：把本次学到的一句话分享给一个可能需要的人。';
  }

  String _growthQuestion(String scene) {
    switch (scene) {
      case 'work_consolidation': return '我现在是在追求真实能力，还是在用成就保护自尊？';
      case 'relationship_conflict': return '我在亲密关系中最常用的旧防御是什么，它曾经保护过我什么？';
      case 'childhood_climate': return '哪些早年适应仍在保护我，哪些已经需要升级？';
      case 'generativity': return '我如何让自己的痛苦不继续传递，而是转化为对他人的帮助？';
      case 'anxiety_fear': return '我能把这份恐惧转化为哪一个可准备、可求助、可验证的现实动作？';
      default: return '如果把这件事放到一年的时间线里，它正在提醒我练习哪一种成熟适应？';
    }
  }

  String _sceneName(String scene) {
    switch (scene) {
      case 'daily_stress': return '日常压力事件';
      case 'defense_identify': return '防御机制识别';
      case 'reality_check': return '现实检查';
      case 'anger_transform': return '愤怒转化';
      case 'shame_failure': return '羞耻与失败修复';
      case 'anxiety_fear': return '焦虑与恐惧预期';
      case 'relationship_conflict': return '关系冲突';
      case 'intimacy_avoidance': return '亲密回避';
      case 'work_consolidation': return '工作压力与职业巩固';
      case 'balance_four': return '四维平衡';
      case 'high_functioning': return '高功能但不鲜活';
      case 'childhood_climate': return '童年关系气候';
      case 'body_health': return '身体与压力';
      case 'acting_out': return '行动化/成瘾冲动';
      case 'generativity': return '生成性与贡献';
      case 'life_stage_review': return '生命阶段复盘';
      case 'understand_other': return '理解他人';
      default: return '成熟适应力分析';
    }
  }

  String _composeMarkdown({
    required String summary,
    required String facts,
    required String interpretation,
    required List<String> emotions,
    required List<String> body,
    required List<String> defenses,
    required String layer,
    required String protective,
    required String cost,
    required String reality,
    required List<String> alternatives,
    required String action10,
    required String action24,
    required String action7,
    required String relation,
    required String question,
  }) {
    return '''【1. 温和概括】
$summary

【2. 事实与解释】
事实：$facts
解释/猜测：$interpretation
情绪：${emotions.join('、')}
身体：${body.join('、')}

【3. 可能的适应方式】
看起来可能涉及：${defenses.join('、')}。这只是反思工具，不是诊断或标签。

【4. 它保护了什么】
$protective

【5. 它可能带来的代价】
$cost

【6. 成熟替代方向】
${alternatives.join(' / ')}。

【7. 具体行动】
10 分钟：$action10
24 小时：$action24
7 天：$action7

【8. 关系影响】
$relation

【9. 长期成长问题】
$question

【10. 安全提醒】
如果出现自伤、伤人、严重失控、暴力或现实检验受损，请优先联系当地紧急服务、专业人员或可信任的人。''';
  }
}
