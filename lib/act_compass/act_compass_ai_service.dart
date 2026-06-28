import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'act_compass_models.dart';
import 'act_compass_prompt_config.dart';

class ActCompassAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final ActCompassPromptConfig _prompts = ActCompassPromptConfig();

  Future<ActCompassSessionRecord> generate({
    required String scene,
    required String userInput,
    required ActCompassProfile profile,
    required ActCompassFlexRadar radar,
    required String recentContextJson,
    String outputMode = 'common',
  }) async {
    final fallback = localAnalyze(
      scene: scene,
      userInput: userInput,
      profile: profile,
      radar: radar,
      outputMode: outputMode,
    );
    final prompt = await _prompts.buildPrompt(
      scene: scene,
      userInput: userInput,
      profileJson: profile.encode(),
      radarJson: radar.encode(),
      recentContextJson: recentContextJson,
      outputMode: outputMode,
    );
    try {
      final text = await _ai.generateText(
        prompt: prompt,
        purpose: 'act_compass.psychological_flexibility',
        maxTokens: 3600,
        expectJson: true,
        temperature: 0.28,
      );
      final parsed = _tryParse(text, scene: scene, userInput: userInput, outputMode: outputMode);
      if (parsed != null && parsed.aiResponse.trim().isNotEmpty) return parsed;
    } catch (_) {}
    return fallback;
  }

  ActCompassSessionRecord localAnalyze({
    required String scene,
    required String userInput,
    required ActCompassProfile profile,
    required ActCompassFlexRadar radar,
    String outputMode = 'common',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final input = userInput.trim().isEmpty ? '我现在有点卡住，想要回到价值并做一个小行动。' : userInput.trim();
    final risk = _detectRisk(input);
    if (risk == 'high' || risk == 'crisis' || scene == 'safety') {
      return ActCompassSessionRecord(
        createdAtMs: now,
        updatedAtMs: now,
        scene: scene,
        userInput: input,
        aiResponse: '我很在意你现在的安全。这个情况已经超出普通自助练习，请立即联系当地紧急服务、危机热线、专业人员，或让身边一个可信赖的人陪你一起处理。现在先远离可能伤害自己的工具或环境，不要一个人硬扛。',
        focusProcesses: const <String>['安全优先'],
        heardSummary: '你现在可能处在需要即时支持的风险状态。',
        processObservation: '此刻优先目标不是做 ACT 练习，而是确保安全并连接真实的人和专业支持。',
        groundingPractice: '请先把自己移动到更安全、有人在附近的地方，并联系一个具体的人。',
        riskLevel: risk,
        outputMode: outputMode,
      );
    }

    if (scene == 'weekly_report') {
      return _localWeeklyReport(now: now, input: input, profile: profile, radar: radar, outputMode: outputMode);
    }
    if (scene == 'profile_update') {
      return _localProfileUpdate(now: now, input: input, profile: profile, radar: radar, outputMode: outputMode);
    }

    final values = _detectValues(input, profile);
    final story = _detectStory(input, scene);
    final obstacle = _detectObstacle(input, scene);
    final processes = _detectProcesses(input, scene, radar);
    final value = values.isEmpty ? '成长' : values.first;
    final action = _buildAction(input: input, scene: scene, value: value, story: story, obstacle: obstacle);
    final heard = _heardSummary(input, scene);
    final process = _processObservation(scene, story, obstacle, radar);
    final grounding = _groundingPractice(scene);
    final defusion = _defusionSentence(story);
    final acceptance = _acceptanceSentence(obstacle, value);
    final reviews = _reviewQuestions(value);
    final response = _composeResponse(
      mode: outputMode,
      heard: heard,
      process: process,
      grounding: grounding,
      story: story,
      defusion: defusion,
      acceptance: acceptance,
      values: values,
      action: action,
      reviews: reviews,
    );

    return ActCompassSessionRecord(
      createdAtMs: now,
      updatedAtMs: now,
      scene: scene,
      userInput: input,
      aiResponse: response,
      focusProcesses: processes,
      heardSummary: heard,
      processObservation: process,
      groundingPractice: grounding,
      thoughtStory: story,
      defusionSentence: defusion,
      acceptanceSentence: acceptance,
      values: values,
      actionCard: action,
      reviewQuestions: reviews,
      riskLevel: risk,
      outputMode: outputMode,
    );
  }

  ActCompassSessionRecord _localWeeklyReport({required int now, required String input, required ActCompassProfile profile, required ActCompassFlexRadar radar, required String outputMode}) {
    final values = profile.coreValues.isEmpty ? <String>['成长', '责任', '真诚'] : profile.coreValues.take(4).toList(growable: false);
    final weakest = radar.weakestLabel;
    final action = ActCompassActionCard(
      valueDirection: values.first,
      obstacle: '本周最容易让行动缩小的头脑故事和回避策略',
      thoughtStory: '我需要状态好了、痛苦少了，才能继续行动。',
      defusionSentence: '我注意到，我的头脑正在讲“先解决不舒服再生活”的故事。',
      acceptanceSentence: '我可以允许不舒服在这里，同时继续做一个很小但真实的行动。',
      microAction: '下周每天选择一个 5–15 分钟的价值行动，并在当天完成后复盘 1 个问题。',
      startTime: '下周每天固定一个具体时间',
      duration: '5–15分钟',
      successCriteria: '开始就算完成，复盘比完美更重要。',
      ifPainThen: '如果焦虑/抗拒出现，就先命名它，再把行动缩小一半。',
    );
    final report = '''【本周心理灵活性报告】

1. 本周靠近的价值：${values.join(' / ')}。

2. 最需要留意的过程：$weakest。它不是缺陷，而是下周最值得训练的入口。

3. 常见头脑故事：头脑可能会说“必须状态好才能行动”“做不好就说明我不行”。下周练习把它们改写为“我注意到，头脑正在说……”。

4. 常见回避策略：拖延、刷手机、沉默、讨好或过度准备可能短期缓解不舒服，但长期会让生活离价值更远。

5. 带着不舒服行动的证据：只要你开始、接触、表达、复盘过一次，就已经在训练心理灵活性。

6. 下周最小训练重点：每天一次“回到当下 → 看见头脑 → 给体验空间 → 做 5–15 分钟价值行动”。

7. 推荐行动：${action.microAction}''';
    return ActCompassSessionRecord(
      createdAtMs: now,
      updatedAtMs: now,
      scene: 'weekly_report',
      userInput: input,
      aiResponse: report,
      focusProcesses: <String>[weakest, '价值连接', '承诺行动'],
      heardSummary: '这是基于近期记录生成的心理灵活性周报。',
      processObservation: '重点不是评价表现，而是看见哪些过程在帮助或阻碍价值行动。',
      groundingPractice: '读报告前先做一次慢呼气，提醒自己：复盘不是审判，而是学习。',
      thoughtStory: action.thoughtStory,
      defusionSentence: action.defusionSentence,
      acceptanceSentence: action.acceptanceSentence,
      values: values,
      actionCard: action,
      reviewQuestions: const <String>['本周我在哪个时刻带着不舒服行动了？', '下周我愿意把哪个行动缩小到 5 分钟？'],
      riskLevel: 'none',
      outputMode: outputMode,
    );
  }

  ActCompassSessionRecord _localProfileUpdate({required int now, required String input, required ActCompassProfile profile, required ActCompassFlexRadar radar, required String outputMode}) {
    final values = profile.coreValues.isEmpty ? <String>['成长', '真诚', '责任'] : profile.coreValues.take(5).toList(growable: false);
    final story = profile.commonStories.trim().isEmpty ? '我不够好 / 我会失败 / 别人会评价我' : profile.commonStories;
    final avoidance = profile.avoidancePatterns.trim().isEmpty ? '刷手机 / 拖延 / 沉默 / 讨好 / 过度准备' : profile.avoidancePatterns;
    final practice = profile.effectivePractices.trim().isEmpty ? '一次慢呼气、解离句、价值行动卡、行动后复盘' : profile.effectivePractices;
    final text = '''【个性化地图更新建议】

核心价值候选：${values.join(' / ')}。

常见头脑故事：$story。

常见回避动作：$avoidance。

有效回应方式：$practice。

下一个优先训练过程：${radar.weakestLabel}。

建议写入档案的一句话：当“$story”出现时，我先注意到它是头脑故事，再选择一个靠近 ${values.first} 的 5 分钟行动。''';
    return ActCompassSessionRecord(
      createdAtMs: now,
      updatedAtMs: now,
      scene: 'profile_update',
      userInput: input,
      aiResponse: text,
      focusProcesses: <String>['个性化地图', radar.weakestLabel],
      heardSummary: '正在把近期记录提炼成可复用的个性化地图。',
      processObservation: '个性化地图用于帮助后续 AI 更快识别常见故事、回避模式和有效练习。',
      groundingPractice: '先把这份地图当作假设，不当作标签；用行动继续验证。',
      thoughtStory: story,
      defusionSentence: '我注意到，我的头脑正在讲一个熟悉故事：$story。',
      acceptanceSentence: '我可以允许这些熟悉反应出现，同时把下一步缩小到可以开始。',
      values: values,
      actionCard: const ActCompassActionCard(),
      reviewQuestions: const <String>['这份地图里哪一条最贴近我？', '下一次卡住时，我想优先调用哪一句回应？'],
      riskLevel: 'none',
      outputMode: outputMode,
    );
  }

  ActCompassSessionRecord? _tryParse(String raw, {required String scene, required String userInput, required String outputMode}) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      final actionMap = _asMap(map['action_card']);
      final action = ActCompassActionCard.fromJson(actionMap);
      final now = DateTime.now().millisecondsSinceEpoch;
      return ActCompassSessionRecord(
        createdAtMs: now,
        updatedAtMs: now,
        scene: scene,
        userInput: userInput.trim(),
        aiResponse: (map['ai_response'] ?? '').toString(),
        focusProcesses: _stringList(map['focus_processes']),
        heardSummary: (map['heard_summary'] ?? '').toString(),
        processObservation: (map['process_observation'] ?? '').toString(),
        groundingPractice: (map['grounding_practice'] ?? '').toString(),
        thoughtStory: (map['thought_story'] ?? '').toString(),
        defusionSentence: (map['defusion_sentence'] ?? '').toString(),
        acceptanceSentence: (map['acceptance_sentence'] ?? '').toString(),
        values: _stringList(map['values']),
        actionCard: action,
        reviewQuestions: _stringList(map['review_questions']),
        riskLevel: (map['risk_level'] ?? 'none').toString(),
        outputMode: (map['output_mode'] ?? outputMode).toString(),
        rawJson: jsonText,
      );
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

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
    if (raw == null) return const <String>[];
    return raw
        .toString()
        .split(RegExp(r'[,，;；\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  String _detectRisk(String input) {
    final s = input.toLowerCase();
    final crisisWords = <String>['自杀', '不想活', '结束生命', '活不下去', '轻生', '杀了自己', 'suicide', 'kill myself'];
    final highWords = <String>['自伤', '伤害自己', '伤害别人', '杀人', '报复', '割腕', '跳楼', ' overdose', 'hurt myself'];
    if (crisisWords.any(s.contains)) return 'crisis';
    if (highWords.any(s.contains)) return 'high';
    return 'none';
  }

  List<String> _detectValues(String input, ActCompassProfile profile) {
    final candidates = <String>{...profile.coreValues};
    final mapping = <String, List<String>>{
      '学习': <String>['学习', '成长'],
      '工作': <String>['负责', '贡献', '专业'],
      '汇报': <String>['负责', '表达', '成长'],
      '关系': <String>['真诚', '亲密', '尊重'],
      '伴侣': <String>['亲密', '真诚'],
      '父母': <String>['家庭', '爱', '边界'],
      '健康': <String>['健康', '自我照顾'],
      '运动': <String>['健康', '活力'],
      '写': <String>['创造', '成长'],
      '考试': <String>['学习', '责任'],
      '自由': <String>['自由'],
      '责任': <String>['责任'],
      '勇气': <String>['勇气'],
      '真诚': <String>['真诚'],
    };
    for (final entry in mapping.entries) {
      if (input.contains(entry.key)) candidates.addAll(entry.value);
    }
    if (candidates.isEmpty) candidates.addAll(<String>['成长', '责任', '真诚']);
    return candidates.take(4).toList(growable: false);
  }

  String _detectStory(String input, String scene) {
    final patterns = <RegExp>[
      RegExp(r'我(就是|肯定|一定|永远|总是|根本|完全)[^，。！？\n]{1,36}'),
      RegExp(r'别人(肯定|一定|都会|会)[^，。！？\n]{1,36}'),
      RegExp(r'(必须|应该|不能|不可以)[^，。！？\n]{1,40}'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(input);
      if (m != null) return m.group(0) ?? '';
    }
    if (scene == 'procrastination') return '必须准备好、状态好，才值得开始。';
    if (scene == 'anxiety') return '如果我做不好，就会出现很糟的后果。';
    if (scene == 'self_criticism' || scene == 'self_as_context') return '我就是不够好。';
    if (scene == 'relationship') return '对方这样做说明我不被在乎。';
    if (scene == 'value_experiment') return '价值必须先完全想清楚，才可以开始行动。';
    return '我需要先把不舒服解决掉，才能开始生活。';
  }

  String _detectObstacle(String input, String scene) {
    if (input.contains('焦虑') || scene == 'anxiety') return '焦虑和灾难化预测';
    if (input.contains('羞耻') || input.contains('丢脸') || scene == 'self_criticism') return '羞耻、自我批评和失败感';
    if (input.contains('拖延') || input.contains('刷手机') || scene == 'procrastination') return '拖延带来的短期逃避舒适';
    if (input.contains('愤怒') || input.contains('吵') || scene == 'relationship') return '愤怒、委屈和自动防御';
    if (input.contains('睡') || scene == 'bedtime_rumination') return '睡前反刍与计划念头';
    if (input.contains('冲动') || scene == 'impulse') return '想立刻缓解不舒服的冲动';
    if (scene == 'clean_dirty_pain') return '二次痛苦中的“我不该这样/必须马上好起来”';
    if (scene == 'self_as_context') return '被自我故事定义后的收缩感';
    if (scene == 'present_moment') return '注意力被反刍和担忧拉走';
    if (scene == 'value_experiment') return '价值抽象、行动过大和害怕验证';
    return '不舒服、抗拒和不确定';
  }

  List<String> _detectProcesses(String input, String scene, ActCompassFlexRadar radar) {
    final set = <String>{};
    if (input.contains('必须') || input.contains('应该') || input.contains('就是') || scene == 'thought_defusion') set.add('认知解离');
    if (input.contains('不想') || input.contains('逃') || input.contains('刷手机') || scene == 'acceptance_training' || scene == 'clean_dirty_pain') set.add('接纳');
    if (input.contains('过去') || input.contains('以后') || input.contains('睡') || scene == 'bedtime_rumination' || scene == 'present_moment') set.add('当下觉察');
    if (input.contains('我就是') || scene == 'self_criticism' || scene == 'self_as_context') set.add('观察者自我');
    if (input.contains('迷茫') || input.contains('意义') || scene == 'values_confusion' || scene == 'values_compass' || scene == 'value_experiment') set.add('价值连接');
    set.add('承诺行动');
    set.add(radar.weakestLabel);
    return set.take(4).toList(growable: false);
  }

  String _heardSummary(String input, String scene) {
    if (scene == 'daily_checkin') return '你正在把今天的体验、价值和一个可开始的小行动放到同一张地图上。';
    if (scene == 'procrastination') return '你并不是单纯不自律，更像是某种不舒服一出现，行动就被推迟。';
    if (scene == 'anxiety') return '焦虑正在提醒你：这件事很重要，同时头脑也在放大可能的危险。';
    if (scene == 'relationship') return '这段关系里既有情绪，也有你真正想守护的关系价值。';
    if (scene == 'values_confusion') return '你不是必须马上找到人生标准答案，可以先用小实验寻找方向。';
    if (scene == 'present_moment') return '你正在练习把注意力从头脑故事带回此刻。';
    if (scene == 'self_as_context') return '你正在练习看见自我故事，而不是被故事完全定义。';
    if (scene == 'clean_dirty_pain') return '你正在区分不可避免的痛，以及抗拒痛苦带来的额外折磨。';
    if (scene == 'value_experiment') return '你正在把价值从抽象词变成接下来 7 天可以验证的行动实验。';
    return '我听见你现在有一部分很想改变，也有一部分被不舒服或头脑故事拉住。';
  }

  String _processObservation(String scene, String story, String obstacle, ActCompassFlexRadar radar) {
    return '这里可能不是“你不够好”，而是“$story”这个头脑故事和“$obstacle”正在共同影响行动。当前可优先练习：${radar.weakestLabel}。';
  }

  String _groundingPractice(String scene) {
    if (scene == 'acceptance_training') return '把注意力放到最明显的身体感受上，给它一个形状、温度和边界，呼气时只说：我允许它先在这里。';
    if (scene == 'bedtime_rumination') return '看见三个念头，把它们标记为“计划/后悔/预测”，然后把注意力放回一次呼气。';
    if (scene == 'present_moment') return '看见 3 个物体、听见 2 个声音、感受 1 次呼气；然后问自己：现在最小的一步是什么？';
    if (scene == 'self_as_context') return '轻声说：“我注意到我正在有一个故事。” 然后感受那个能看见故事的自己。';
    return '双脚踩地，慢慢吸气一次、呼气一次，然后看见你身边三个具体物体。';
  }

  String _defusionSentence(String story) => '我注意到，我的头脑正在告诉我：$story';

  String _acceptanceSentence(String obstacle, String value) => '我可以允许$obstacle在这里，同时继续靠近$value。';

  ActCompassActionCard _buildAction({required String input, required String scene, required String value, required String story, required String obstacle}) {
    String action;
    String duration = '5分钟';
    String start = '现在或今天固定一个具体时间';
    if (scene == 'relationship') {
      action = '写下一句真实、具体、非攻击的表达，并在合适时间说出或发送。';
      duration = '10分钟';
    } else if (scene == 'bedtime_rumination') {
      action = '写下明天一个最小行动，然后做 3 次呼气，把计划本合上。';
      duration = '3分钟';
      start = '睡前上床前';
    } else if (scene == 'values_confusion' || scene == 'values_compass' || scene == 'value_experiment') {
      action = '做一个 7 天价值实验的第一步：今天安排一个 10 分钟行动来测试“$value”是否重要。';
      duration = '10分钟';
    } else if (scene == 'present_moment') {
      action = '做 90 秒当下觉察：看见 3 个物体、听见 2 个声音、完成 1 次慢呼气，然后开始一个 2 分钟行动。';
      duration = '2分钟';
    } else if (scene == 'self_as_context') {
      action = '把“我是……”改写成“我注意到我正在有……故事”，然后选择一个价值一致的小动作。';
      duration = '5分钟';
    } else if (scene == 'clean_dirty_pain') {
      action = '写下干净痛苦和二次痛苦各一句，把二次痛苦中的“必须/不该”改写成愿意语。';
      duration = '5分钟';
    } else if (scene == 'procrastination') {
      action = '只打开任务相关文件或材料，写下 3 个要点，不修改、不追求质量。';
      duration = '5分钟';
    } else if (scene == 'impulse') {
      action = '把冲动延迟 10 分钟，同时做一个更靠近$value的小替代动作。';
      duration = '10分钟';
    } else {
      action = '选择一个能靠近$value的最小动作，做到“开始”即可。';
    }
    return ActCompassActionCard(
      valueDirection: value,
      obstacle: obstacle,
      thoughtStory: story,
      defusionSentence: _defusionSentence(story),
      acceptanceSentence: _acceptanceSentence(obstacle, value),
      microAction: action,
      startTime: start,
      duration: duration,
      successCriteria: '开始就算完成，不以状态好坏或质量完美作为标准。',
      ifPainThen: '如果$obstacle出现，就说“谢谢你，头脑，我先做完这一步”。',
      status: 'active',
    );
  }

  List<String> _reviewQuestions(String value) => <String>[
        '我是否带着不舒服靠近了一点点“$value”？',
        '行动中出现了什么头脑故事、情绪或身体感受？',
        '下一步可以怎样缩小一半，让它更容易开始？',
      ];

  String _composeResponse({
    required String mode,
    required String heard,
    required String process,
    required String grounding,
    required String story,
    required String defusion,
    required String acceptance,
    required List<String> values,
    required ActCompassActionCard action,
    required List<String> reviews,
  }) {
    final valueText = values.isEmpty ? '成长 / 责任 / 真诚' : values.join(' / ');
    if (mode == 'quick') {
      return '1. 停一下：$grounding\n2. 命名：这是不舒服和头脑故事，不是命令。\n3. 解离：$defusion\n4. 价值：这件事背后你可能在乎的是：$valueText。\n5. 行动：接下来只做：${action.microAction}\n6. 标准：${action.successCriteria}';
    }
    if (mode == 'action_card') {
      return '【价值行动卡】\n\n价值方向：${action.valueDirection}\n\n今天的障碍：${action.obstacle}\n\n头脑故事：“${action.thoughtStory}”\n\n解离句：${action.defusionSentence}\n\n接纳句：${action.acceptanceSentence}\n\n最小行动：${action.microAction}\n\n开始时间：${action.startTime}\n\n持续时间：${action.duration}\n\n完成标准：${action.successCriteria}\n\n如果失败：不惩罚，记录触发点，把行动缩小一半，重新开始。';
    }
    if (mode == 'deep') {
      return '【事件】\n$heard\n\n【内在体验】\n这里可能有：${action.obstacle}。\n\n【头脑故事】\n$story\n\n【回避策略】\n短期可能是在避开不舒服，长期代价是离价值更远。\n\n【价值方向】\n你可能在乎：$valueText。\n\n【愿意度】\n为了这些价值，你愿意给这份不舒服一点空间吗？\n\n【承诺行动】\n${action.microAction}\n开始时间：${action.startTime}；持续：${action.duration}。\n\n【复盘】\n${reviews.join('\n')}';
    }
    return '【1. 我听见的重点】\n$heard\n\n【2. 这可能不是你的问题，而是一个可观察的过程】\n$process\n\n【3. 先回到当下】\n$grounding\n\n【4. 看见头脑】\n$defusion\n\n【5. 给体验一点空间】\n$acceptance\n\n【6. 连接价值】\n这件事背后，你可能在乎：$valueText。你可以选择其中一个作为今天的方向。\n\n【7. 一个小到可以开始的行动】\n${action.microAction}\n开始时间：${action.startTime}；持续：${action.duration}。\n如果不舒服出现：${action.ifPainThen}\n完成标准：${action.successCriteria}\n\n【8. 复盘问题】\n${reviews.join('\n')}';
  }
}
