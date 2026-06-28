import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'mi_growth_models.dart';
import 'mi_growth_prompt_config.dart';

class MiGrowthAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final MiGrowthPromptConfig _prompts = MiGrowthPromptConfig();

  Future<MiGrowthSessionRecord> generate({
    required String scene,
    required String userInput,
    required MiGrowthValueProfile profile,
    required String recentContextJson,
  }) async {
    final local = localGuide(scene: scene, userInput: userInput, profile: profile);
    final prompt = await _prompts.buildPrompt(
      scene: scene,
      userInput: userInput,
      profileJson: profile.encode(),
      recentContextJson: recentContextJson,
    );
    try {
      final text = await _ai.generateText(
        prompt: prompt,
        purpose: 'mi_growth.navigator',
        maxTokens: 2200,
        expectJson: true,
        temperature: 0.35,
      );
      final parsed = _tryParse(text, scene: scene, userInput: userInput);
      if (parsed != null && parsed.aiResponse.trim().isNotEmpty) return parsed;
    } catch (_) {}
    return local;
  }

  MiGrowthSessionRecord localGuide({
    required String scene,
    required String userInput,
    required MiGrowthValueProfile profile,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final input = userInput.trim();
    final risk = _detectRisk(input);
    final discord = _detectDiscord(input);
    final values = _detectValues(input, profile);
    final changeTalk = _detectChangeTalk(input);
    final sustainTalk = _detectSustainTalk(input);
    if (risk == 'crisis' || risk == 'high') {
      return MiGrowthSessionRecord(
        createdAtMs: now,
        scene: scene,
        stage: 'safety',
        strategy: 'safety',
        userInput: input,
        aiResponse: '我很在意你现在的安全。这个情况已经超出普通自助成长对话，最好马上联系当地紧急服务、危机热线、专业人员，或让身边一个可信赖的人陪你一起处理。现在先不要一个人硬扛。',
        focus: '当前安全',
        valuesDetected: values,
        changeTalk: changeTalk,
        sustainTalk: sustainTalk,
        discordSignals: discord,
        riskLevel: risk,
      );
    }

    if (discord.isNotEmpty || scene == 'repairing_discord') {
      return MiGrowthSessionRecord(
        createdAtMs: now,
        scene: scene,
        stage: 'repairing_discord',
        strategy: 'repair',
        userInput: input,
        aiResponse: '你提醒得对，我可能不能急着往方案走。听起来你更需要先被理解，而不是被推着改变。我们可以先暂停建议，回到你真正想表达的部分：我刚才哪里最没有理解到你？',
        focus: '修复理解与自主感',
        valuesDetected: values,
        changeTalk: changeTalk,
        sustainTalk: sustainTalk,
        discordSignals: discord,
        riskLevel: risk,
      );
    }

    final focus = _inferFocus(input, scene);
    final reflection = _buildReflection(input, scene, changeTalk, sustainTalk, values);
    final question = _buildQuestion(scene, focus, changeTalk, values);
    final shouldPlan = _shouldPlan(scene, input, changeTalk);
    final action = shouldPlan ? _buildAction(scene, focus, values, profile, changeTalk) : const MiGrowthActionPlan();
    final reply = shouldPlan
        ? '$reflection\n\n我听到的改变理由是：${_shortReason(changeTalk, values)}\n\n【下一小步】\n时间：${action.timeText}\n地点：${action.place}\n动作：${action.action}\n时长：${action.duration}\n备用方案：${action.backupPlan}\n\n这只是一个可调整的版本，选择权在你。你对这一步的信心如果低于 7 分，我们就继续把它缩小。'
        : '$reflection\n\n我听到这里有一个值得被尊重的重点：${_shortReason(changeTalk, values)}\n\n$question';

    return MiGrowthSessionRecord(
      createdAtMs: now,
      scene: scene,
      stage: shouldPlan ? 'planning' : (scene == 'confusion_focus' ? 'focusing' : 'evoking'),
      strategy: shouldPlan ? 'action_planning' : (sustainTalk.isNotEmpty ? 'double_sided_reflection' : 'reflection'),
      userInput: input,
      aiResponse: reply,
      focus: focus,
      valuesDetected: values,
      changeTalk: changeTalk,
      sustainTalk: sustainTalk,
      discordSignals: discord,
      nextAction: action,
      riskLevel: risk,
    );
  }

  MiGrowthSessionRecord? _tryParse(String raw, {required String scene, required String userInput}) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      final actionMap = map['next_action'] is Map ? (map['next_action'] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final changeMap = map['change_talk'] is Map ? (map['change_talk'] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final action = MiGrowthActionPlan.fromJson(actionMap);
      return MiGrowthSessionRecord(
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        scene: scene,
        stage: (map['stage'] ?? 'engaging').toString(),
        strategy: (map['strategy'] ?? 'reflection').toString(),
        userInput: userInput.trim(),
        aiResponse: (map['user_visible_reply'] ?? map['reflection'] ?? '').toString(),
        focus: (map['focus'] ?? '').toString(),
        valuesDetected: _stringList(map['values_detected']),
        changeTalk: MiGrowthChangeTalk.fromJson(changeMap),
        sustainTalk: _stringList(map['sustain_talk']),
        discordSignals: _stringList(map['discord_signals']),
        nextAction: action,
        riskLevel: (map['risk_level'] ?? 'none').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  String _extractJsonObject(String raw) {
    final text = raw.trim();
    if (text.startsWith('{') && text.endsWith('}')) return text;
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) return text.substring(start, end + 1);
    return '';
  }

  String _detectRisk(String input) {
    final t = input.toLowerCase();
    final crisisWords = <String>['自杀', '轻生', '不想活', '结束生命', '杀了自己', 'suicide', 'kill myself'];
    final highWords = <String>['伤害自己', '自残', '伤害别人', '杀人', '被虐待', '家暴', '戒断', '幻听', '幻觉'];
    if (crisisWords.any(t.contains)) return 'crisis';
    if (highWords.any(t.contains)) return 'high';
    return 'none';
  }

  List<String> _detectDiscord(String input) {
    final patterns = <String>['你不懂', '别说教', '说得容易', '没用', '烦死', '被控制', '像我爸妈', '不要建议'];
    return patterns.where(input.contains).toList(growable: false);
  }

  List<String> _detectValues(String input, MiGrowthValueProfile profile) {
    final map = <String, List<String>>{
      '健康': <String>['健康', '身体', '睡眠', '运动', '体力', '病', '饮食'],
      '家庭': <String>['家人', '孩子', '父母', '伴侣', '家庭', '陪伴'],
      '成长': <String>['成长', '学习', '进步', '提升', '能力'],
      '自由': <String>['自由', '掌控', '选择', '独立'],
      '关系': <String>['朋友', '关系', '沟通', '亲密', '连接'],
      '责任': <String>['责任', '承诺', '工作', '任务', '照顾'],
      '尊严': <String>['尊严', '体面', '羞耻', '自尊'],
      '创造': <String>['创造', '作品', '写作', '表达'],
      '安全': <String>['安全', '稳定', '收入', '房子', '风险'],
    };
    final found = <String>{};
    for (final entry in map.entries) {
      if (entry.value.any(input.contains)) found.add(entry.key);
    }
    for (final v in profile.values) {
      if (v.trim().isNotEmpty && input.contains(v.trim())) found.add(v.trim());
    }
    if (found.isEmpty && profile.values.isNotEmpty) found.add(profile.values.first);
    return found.take(5).toList(growable: false);
  }

  MiGrowthChangeTalk _detectChangeTalk(String input) {
    final desire = _sentencesWith(input, <String>['想', '希望', '愿意', '不想再', '受够']);
    final ability = _sentencesWith(input, <String>['可以', '能', '做得到', '曾经', '试过']);
    final reasons = _sentencesWith(input, <String>['因为', '为了', '这样就', '重要', '在乎']);
    final need = _sentencesWith(input, <String>['需要', '必须得', '不能继续', '该改变']);
    final commitment = _sentencesWith(input, <String>['我会', '决定', '承诺', '今天就', '明天就']);
    final activation = _sentencesWith(input, <String>['准备', '打算', '先试', '可以先']);
    final taking = _sentencesWith(input, <String>['已经', '刚刚', '开始了', '做了一点']);
    return MiGrowthChangeTalk(
      desire: desire,
      ability: ability,
      reasons: reasons,
      need: need,
      commitment: commitment,
      activation: activation,
      takingSteps: taking,
    );
  }

  List<String> _detectSustainTalk(String input) {
    return _sentencesWith(input, <String>['但是', '可是', '没办法', '做不到', '不想', '太难', '没用', '算了', '懒得']);
  }

  List<String> _sentencesWith(String input, List<String> words) {
    final parts = input.split(RegExp(r'[。！？!?\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty);
    final found = <String>[];
    for (final part in parts) {
      if (words.any(part.contains)) found.add(part.length > 80 ? '${part.substring(0, 80)}…' : part);
    }
    return found.take(3).toList(growable: false);
  }

  String _inferFocus(String input, String scene) {
    if (scene == 'help_others') return '帮助别人改变的对话方式';
    if (scene == 'life_transition') return '人生转变中的价值与身份方向';
    if (input.contains('拖延')) return '拖延与启动困难';
    if (input.contains('睡') || input.contains('熬夜')) return '睡眠节奏';
    if (input.contains('运动') || input.contains('身体')) return '身体照顾';
    if (input.contains('手机') || input.contains('刷')) return '注意力与手机使用';
    if (input.contains('工作') || input.contains('学习')) return '工作学习行动';
    if (input.contains('关系') || input.contains('家人') || input.contains('孩子')) return '关系与沟通';
    if (scene == 'confusion_focus') return '从混乱中选择一个可开始焦点';
    return '今天最值得被照顾的一件事';
  }

  String _buildReflection(String input, String scene, MiGrowthChangeTalk changeTalk, List<String> sustainTalk, List<String> values) {
    if (scene == 'action_failure') return '这次没有做到，并不等于你这个人失败了。它更像是一条信息：当时的精力、环境、情绪或计划大小，可能和你真实处境不匹配。';
    if (scene == 'confusion_focus') return '你现在像是同时被好几件事拉住了。我们不需要一次解决全部，先把它们摆出来，再选一个最能带动其他方面的小焦点。';
    if (sustainTalk.isNotEmpty && !changeTalk.isEmpty) return '听起来你一方面确实想让事情变得不一样，另一方面也有很真实的阻力。你不是简单地“不想改变”，而是在价值、疲惫和现实压力之间拉扯。';
    if (!changeTalk.isEmpty) return '你刚才的话里已经有一些改变的种子：不是外面的人逼你，而是你自己在意某些东西，也希望生活有一点不一样。';
    if (values.isNotEmpty) return '我听到这件事背后可能牵动着${values.join('、')}。我们可以先不急着做计划，先看清它为什么对你重要。';
    return '我先不急着给建议。你愿意把这件事说出来，本身就说明它对你有分量，我们可以从理解它开始。';
  }

  String _buildQuestion(String scene, String focus, MiGrowthChangeTalk changeTalk, List<String> values) {
    if (scene == 'confusion_focus') return '如果只选一个焦点，让今天轻 5%，你最想先选哪一个？';
    if (scene == 'low_motivation') return '现在这样继续下去，对你有什么好处？又有没有一点点地方，是你不希望半年后还一样的？';
    if (scene == 'life_transition') return '在这个变化里，你最不想失去的是什么？';
    if (scene == 'help_others') return '如果少一点说服、多一点理解，你对对方说的第一句话可以怎么改？';
    if (!changeTalk.isEmpty) return '这些理由里面，哪一个最像你自己的声音，而不是别人要求你的声音？';
    if (values.isNotEmpty) return '如果这件事真的和${values.first}有关，你希望它先改善哪一个很小的部分？';
    return '如果我们只从一个很小、很现实的地方开始，你最想先谈哪里？';
  }

  bool _shouldPlan(String scene, String input, MiGrowthChangeTalk changeTalk) {
    if (scene == 'action_failure') return true;
    if (input.contains('怎么做') || input.contains('计划') || input.contains('下一步') || input.contains('帮我设计')) return true;
    if (changeTalk.commitment.isNotEmpty || changeTalk.activation.isNotEmpty || changeTalk.takingSteps.isNotEmpty) return true;
    return false;
  }

  MiGrowthActionPlan _buildAction(String scene, String focus, List<String> values, MiGrowthValueProfile profile, MiGrowthChangeTalk changeTalk) {
    final value = values.isNotEmpty ? values.first : (profile.values.isNotEmpty ? profile.values.first : '更接近自己重视的生活');
    String action;
    String place = '你最容易开始的地方';
    String duration = '3 分钟';
    if (focus.contains('拖延') || focus.contains('工作') || focus.contains('学习')) {
      action = '只打开相关文档或任务页面，看第一行，不要求立刻完成';
      place = '书桌前或手机备忘录里';
    } else if (focus.contains('睡眠')) {
      action = '把手机放到离床两步远的位置，然后关掉一个最容易继续刷的入口';
      place = '卧室';
    } else if (focus.contains('身体') || focus.contains('运动')) {
      action = '穿上鞋，到门口或楼下走一小圈';
      place = '家门口或楼下';
      duration = '5-8 分钟';
    } else if (focus.contains('关系') || focus.contains('沟通')) {
      action = '给对方发一句不说教的关心：我想先理解你现在最难的地方';
      place = '聊天窗口或面对面对话前';
    } else {
      action = '写下一句话：我现在最在乎的是什么，以及今天能做的一小步是什么';
      place = '备忘录或纸上';
    }
    return MiGrowthActionPlan(
      title: '今天的小步实验',
      focus: focus,
      valueConnection: '这一步不是为了证明你足够自律，而是为了让你朝“$value”靠近一点。',
      timeText: '今天或明天的一个固定时刻',
      place: place,
      action: action,
      duration: duration,
      backupPlan: '如果做不到原版，就只做 30 秒版本；目标是重新接触这件事，而不是补偿或加倍。',
      reviewQuestions: const <String>['哪一部分做到了？', '哪一部分卡住了？', '下一次要怎么调小或调准？'],
    );
  }

  String _shortReason(MiGrowthChangeTalk changeTalk, List<String> values) {
    if (changeTalk.reasons.isNotEmpty) return changeTalk.reasons.first;
    if (changeTalk.desire.isNotEmpty) return changeTalk.desire.first;
    if (changeTalk.need.isNotEmpty) return changeTalk.need.first;
    if (values.isNotEmpty) return '你在乎${values.join('、')}，希望生活更接近这些价值。';
    return '你愿意认真看待这件事，而不是继续自动忽略它。';
  }
}

List<String> _stringList(Object? value) {
  if (value == null) return <String>[];
  if (value is List) return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(growable: false);
  final raw = value.toString().trim();
  if (raw.isEmpty) return <String>[];
  return raw.split(RegExp(r'[,，;；\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
}
