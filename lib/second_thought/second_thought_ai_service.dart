import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'second_thought_models.dart';
import 'second_thought_prompt_config.dart';

class SecondThoughtAiService {
  final UnifiedAiService _ai = UnifiedAiService();
  final SecondThoughtPromptConfig _prompts = SecondThoughtPromptConfig();

  Future<SecondThoughtCaseRecord> generate({
    required String scene,
    required String userInput,
    required SecondThoughtProfile profile,
    required String recentContextJson,
  }) async {
    final fallback = localAnalyze(scene: scene, userInput: userInput, profile: profile);
    final prompt = await _prompts.buildPrompt(
      scene: scene,
      userInput: userInput,
      profileJson: profile.encode(),
      recentContextJson: recentContextJson,
    );
    try {
      final text = await _ai.generateText(
        prompt: prompt,
        purpose: 'second_thought.ambivalence_engine',
        maxTokens: 3200,
        expectJson: true,
        temperature: 0.32,
      );
      final parsed = _tryParse(text, scene: scene, userInput: userInput);
      if (parsed != null && parsed.aiResponse.trim().isNotEmpty) return parsed;
    } catch (_) {}
    return fallback;
  }

  SecondThoughtCaseRecord localAnalyze({
    required String scene,
    required String userInput,
    required SecondThoughtProfile profile,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final input = userInput.trim();
    final risk = _detectRisk(input);
    final type = _detectAmbivalenceType(input);
    final values = _detectValues(input, profile);
    final go = _detectGoForces(input, type, values);
    final no = _detectNoForces(input, type);
    final voices = _buildVoices(input, go, no, values);
    final conflicts = _buildValueConflicts(values, type);
    final changeTalk = _detectChangeTalk(input, values);
    final action = risk == 'high' || risk == 'crisis'
        ? const SecondThoughtActionExperiment()
        : _buildActionExperiment(input: input, type: type, values: values, scene: scene);
    final options = _buildOptions(type, values);
    final thirdWays = _buildThirdWays(type, input);
    final title = _inferTitle(input, type);
    final response = risk == 'high' || risk == 'crisis'
        ? '我很在意你现在的安全。这个情况已经超出普通自助成长对话，最好马上联系当地紧急服务、危机热线、专业人员，或让身边一个可信赖的人陪你一起处理。现在先不要一个人硬扛。'
        : _buildUserReply(type: type, values: values, go: go, no: no, voices: voices, action: action);
    return SecondThoughtCaseRecord(
      createdAtMs: now,
      updatedAtMs: now,
      title: title,
      scene: scene,
      userInput: input,
      aiResponse: response,
      ambivalenceType: type,
      confidence: type == '暂不确定' ? 0.45 : 0.74,
      coreConflict: _coreConflict(go, no),
      goForces: go,
      noForces: no,
      innerCommittee: voices,
      possibleValues: values,
      coreValuesToConfirm: values.take(3).toList(growable: false),
      valueConflicts: conflicts,
      evidenceQuestions: _evidenceQuestions(values),
      options: options,
      thirdWayPossibilities: thirdWays,
      changeTalk: changeTalk,
      actionExperiment: action,
      status: action.hasAction ? 'acting' : 'exploring',
      riskLevel: risk,
    );
  }

  SecondThoughtCaseRecord? _tryParse(String raw, {required String scene, required String userInput}) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      final summary = _asMap(map['case_summary']);
      final goNo = _asMap(map['go_no_map']);
      final valuesMap = _asMap(map['values_clarification']);
      final bigPicture = _asMap(map['big_picture']);
      final aiResponse = _asMap(map['ai_response_to_user']);
      final now = DateTime.now().millisecondsSinceEpoch;
      final type = (summary['ambivalence_type'] ?? '暂不确定').toString();
      final userIssue = (summary['user_issue'] ?? '').toString();
      final responseParts = <String>[
        (aiResponse['empathetic_summary'] ?? '').toString(),
        (aiResponse['structured_analysis'] ?? '').toString(),
        (aiResponse['next_question'] ?? '').toString(),
      ].where((e) => e.trim().isNotEmpty).join('\n\n');
      return SecondThoughtCaseRecord(
        createdAtMs: now,
        updatedAtMs: now,
        title: userIssue.isEmpty ? _inferTitle(userInput, type) : userIssue,
        scene: scene,
        userInput: userInput.trim(),
        aiResponse: responseParts,
        ambivalenceType: type,
        confidence: _double(summary['confidence']),
        coreConflict: (summary['core_conflict'] ?? '').toString(),
        goForces: _listOfMaps(goNo['go_forces']).map(SecondThoughtForce.fromJson).toList(growable: false),
        noForces: _listOfMaps(goNo['no_forces']).map(SecondThoughtForce.fromJson).toList(growable: false),
        innerCommittee: _listOfMaps(map['inner_committee']).map(SecondThoughtInnerVoice.fromJson).toList(growable: false),
        possibleValues: _stringList(valuesMap['possible_values']),
        coreValuesToConfirm: _stringList(valuesMap['core_values_to_confirm']),
        valueConflicts: _listOfMaps(valuesMap['values_in_conflict']).map(SecondThoughtValueConflict.fromJson).toList(growable: false),
        evidenceQuestions: _stringList(valuesMap['evidence_questions']),
        options: _listOfMaps(bigPicture['options']).map(SecondThoughtDecisionOption.fromJson).toList(growable: false),
        thirdWayPossibilities: _stringList(bigPicture['third_way_possibilities']),
        changeTalk: SecondThoughtChangeTalk.fromJson(_asMap(map['change_talk'])),
        actionExperiment: SecondThoughtActionExperiment.fromJson(_asMap(map['action_experiment'])),
        status: _asMap(map['action_experiment']).isEmpty ? 'exploring' : 'acting',
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

  String _detectAmbivalenceType(String input) {
    final t = input;
    final switchWords = <String>['两边', '两个', 'A', 'B', '辞职', '换工作', '搬家', '分手', '离开', '留下', '选哪个', '选择'];
    final goNoSignals = <String>['想', '喜欢', '舍不得', '享受', '渴望', '希望'];
    final noSignals = <String>['但是', '可是', '又怕', '担心', '抗拒', '不想', '害怕', '痛苦', '风险', '后悔'];
    final badBothSignals = <String>['都不好', '都很糟', '两难', '没办法', '进退两难', '左右为难', '两害'];
    final goodBothSignals = <String>['都很好', '都不错', '两个机会', '两个都', '都喜欢', '都想要'];
    if (badBothSignals.any(t.contains)) return 'No-No';
    if (goodBothSignals.any(t.contains)) return 'Go-Go';
    if (switchWords.any(t.contains) && goNoSignals.any(t.contains) && noSignals.any(t.contains)) return 'Go-No-Go-No';
    if (goNoSignals.any(t.contains) && noSignals.any(t.contains)) return 'Go-No';
    if (switchWords.any(t.contains)) return 'Go-No-Go-No';
    return '暂不确定';
  }

  List<String> _detectValues(String input, SecondThoughtProfile profile) {
    final map = <String, List<String>>{
      '健康': <String>['健康', '身体', '睡眠', '运动', '饮食', '病', '精力'],
      '成长': <String>['成长', '学习', '进步', '提升', '能力', '变强'],
      '自由': <String>['自由', '选择', '掌控', '独立', '不被控制'],
      '责任': <String>['责任', '承诺', '工作', '任务', '照顾', '该做'],
      '亲密': <String>['亲密', '关系', '伴侣', '爱', '朋友', '连接'],
      '真实': <String>['真实', '诚实', '表达', '说真话', '做自己'],
      '安全': <String>['安全', '稳定', '收入', '风险', '房子', '未来'],
      '自尊': <String>['自尊', '尊严', '体面', '羞耻', '看得起自己'],
      '贡献': <String>['贡献', '帮助', '意义', '价值', '影响'],
      '乐趣': <String>['快乐', '享受', '放松', '乐趣', '舒服'],
    };
    final found = <String>{};
    for (final entry in map.entries) {
      if (entry.value.any(input.contains)) found.add(entry.key);
    }
    for (final v in profile.coreValues) {
      if (v.trim().isNotEmpty && input.contains(v.trim())) found.add(v.trim());
    }
    if (found.isEmpty && profile.coreValues.isNotEmpty) found.addAll(profile.coreValues.take(2));
    if (found.isEmpty) found.addAll(<String>['成长', '自尊', '安全']);
    return found.take(6).toList(growable: false);
  }

  List<SecondThoughtForce> _detectGoForces(String input, String type, List<String> values) {
    final list = <SecondThoughtForce>[];
    list.add(SecondThoughtForce(content: '这件事里有某种你想靠近、想获得或不想失去的东西。', source: '欲望/需要', strength: 7));
    if (input.contains('学习') || input.contains('改变') || input.contains('成长')) {
      list.add(const SecondThoughtForce(content: '你想让生活更接近成长、能力和长期自由。', source: '价值', strength: 8));
    }
    if (input.contains('关系') || input.contains('分手') || input.contains('舍不得') || input.contains('伴侣')) {
      list.add(const SecondThoughtForce(content: '你在乎连接、爱、熟悉感或关系中的重要意义。', source: '关系', strength: 8));
    }
    if (input.contains('辞职') || input.contains('换工作') || input.contains('机会')) {
      list.add(const SecondThoughtForce(content: '新选项可能带来自由、发展空间或新的身份可能性。', source: '未来可能性', strength: 7));
    }
    if (values.isNotEmpty) {
      list.add(SecondThoughtForce(content: '你希望选择能更接近“${values.take(3).join('、')}”。', source: '核心价值', strength: 8));
    }
    return _dedupeForces(list).take(5).toList(growable: false);
  }

  List<SecondThoughtForce> _detectNoForces(String input, String type) {
    final list = <SecondThoughtForce>[];
    list.add(const SecondThoughtForce(content: '另一部分你在担心代价、风险、失控或后悔。', source: '恐惧/现实风险', strength: 7));
    if (input.contains('失败') || input.contains('做不到') || input.contains('拖延')) {
      list.add(const SecondThoughtForce(content: '害怕努力后仍然失败，于是先用拖延保护自己不再受挫。', source: '保护/羞耻', strength: 8));
    }
    if (input.contains('稳定') || input.contains('收入') || input.contains('钱') || input.contains('辞职')) {
      list.add(const SecondThoughtForce(content: '现实安全与收入稳定的声音在提醒你不要冲动。', source: '安全/现实责任', strength: 8));
    }
    if (input.contains('别人') || input.contains('父母') || input.contains('伴侣') || input.contains('评价')) {
      list.add(const SecondThoughtForce(content: '外界期待或他人反应可能让你担心冲突与否定。', source: '外部压力/关系', strength: 7));
    }
    if (type == 'No-No') {
      list.add(const SecondThoughtForce(content: '你可能觉得不管怎么选都要承担损失，所以大脑倾向于暂时不选。', source: '两害压力', strength: 9));
    }
    return _dedupeForces(list).take(5).toList(growable: false);
  }

  List<SecondThoughtForce> _dedupeForces(List<SecondThoughtForce> list) {
    final seen = <String>{};
    final out = <SecondThoughtForce>[];
    for (final f in list) {
      if (seen.add(f.content)) out.add(f);
    }
    return out;
  }

  List<SecondThoughtInnerVoice> _buildVoices(String input, List<SecondThoughtForce> go, List<SecondThoughtForce> no, List<String> values) {
    final valueText = values.isEmpty ? '更重要的生活' : values.take(3).join('、');
    return <SecondThoughtInnerVoice>[
      SecondThoughtInnerVoice(
        voiceName: '想靠近的我',
        whatItSays: go.isEmpty ? '我想要一些新的可能。' : go.first.content,
        whatItProtects: '渴望、希望、生命力和新的可能性',
        whatItFears: '一直停在旧模式里',
        valueOrNeed: valueText,
        benefit: '让你不只是逃避风险，也能看见自己想要的未来。',
        riskIfDominant: '如果只听它，可能低估现实代价。',
        strength: 7,
      ),
      SecondThoughtInnerVoice(
        voiceName: '想保护的我',
        whatItSays: no.isEmpty ? '先别急，可能会有风险。' : no.first.content,
        whatItProtects: '安全、稳定、少受伤、少后悔',
        whatItFears: '冲动决定、失败、损失或关系破裂',
        valueOrNeed: '安全/保护',
        benefit: '提醒你看见成本、边界和支持资源。',
        riskIfDominant: '如果它完全掌控，可能让你长期停滞。',
        strength: 8,
      ),
      SecondThoughtInnerVoice(
        voiceName: '价值声音',
        whatItSays: '我想知道：哪个选择更能让我成为自己尊重的人？',
        whatItProtects: '长期方向、自尊和身份一致性',
        whatItFears: '被短期情绪、羞耻或他人期待带走',
        valueOrNeed: valueText,
        benefit: '把选择从一时情绪带回核心价值。',
        riskIfDominant: '如果过度理想化，可能忽略疲惫和现实限制。',
        strength: 8,
      ),
      if (input.contains('拖延') || input.contains('刷') || input.contains('不想做'))
        const SecondThoughtInnerVoice(
          voiceName: '拖延保护者',
          whatItSays: '现在先别面对，太累或太难了。',
          whatItProtects: '短期缓解、免于失败感和压力',
          whatItFears: '一开始就被证明自己不行',
          valueOrNeed: '休息/保护/掌控感',
          benefit: '说明你可能真的需要降低门槛和恢复能量。',
          riskIfDominant: '长期会侵蚀自尊和选择权。',
          strength: 8,
        ),
      if (input.contains('关系') || input.contains('分手') || input.contains('伴侣') || input.contains('父母'))
        const SecondThoughtInnerVoice(
          voiceName: '关系守护者',
          whatItSays: '我不想伤害关系，也不想轻易失去重要的人。',
          whatItProtects: '连接、忠诚、亲密和归属',
          whatItFears: '孤独、冲突、被抛弃或被责备',
          valueOrNeed: '亲密/忠诚/归属',
          benefit: '提醒你选择会影响真实的人。',
          riskIfDominant: '可能为了维持关系而持续牺牲真实和边界。',
          strength: 7,
        ),
    ];
  }

  List<SecondThoughtValueConflict> _buildValueConflicts(List<String> values, String type) {
    final v = values.isEmpty ? <String>['安全', '成长'] : values;
    final a = v.first;
    final b = v.length > 1 ? v[1] : (a == '安全' ? '成长' : '安全');
    final conflicts = <SecondThoughtValueConflict>[
      SecondThoughtValueConflict(valueA: a, valueB: b, description: '这两个价值都重要，但在当前处境里似乎要求你朝不同方向用力。'),
    ];
    if (type == 'Go-No-Go-No') {
      conflicts.add(const SecondThoughtValueConflict(valueA: '稳定', valueB: '突破', description: '一个声音想保留熟悉结构，另一个声音想打开新的可能。'));
    }
    if (type == 'Go-No') {
      conflicts.add(const SecondThoughtValueConflict(valueA: '当下缓解', valueB: '长期自尊', description: '同一个对象既提供短期好处，也可能带来长期代价。'));
    }
    return conflicts.take(3).toList(growable: false);
  }

  List<String> _evidenceQuestions(List<String> values) {
    final v = values.isEmpty ? <String>['成长', '自尊'] : values.take(3).toList(growable: false);
    return <String>[
      '如果别人要证明你重视“${v.first}”，最近一周能看到哪些生活证据？',
      '为了守住这些价值，你愿意承担哪一种小代价？',
      '这件事里有没有某个价值其实来自他人期待，而不是你的真实选择？',
      '哪个选择更能让你在三个月后仍然尊重自己？',
    ];
  }

  SecondThoughtChangeTalk _detectChangeTalk(String input, List<String> values) {
    final desire = _sentencesWith(input, <String>['想', '希望', '渴望', '不想再', '舍不得']);
    final ability = _sentencesWith(input, <String>['可以', '能', '做得到', '曾经', '试过']);
    final reasons = _sentencesWith(input, <String>['因为', '为了', '这样就', '重要', '在乎']);
    final need = _sentencesWith(input, <String>['需要', '必须', '不能继续', '该', '不得不']);
    final activation = _sentencesWith(input, <String>['愿意', '准备', '打算', '先试', '可以先']);
    final commitment = _sentencesWith(input, <String>['决定', '承诺', '我会', '今天就', '明天就']);
    final taking = _sentencesWith(input, <String>['已经', '刚刚', '开始了', '做了一点']);
    final inferredDesire = desire.isEmpty && values.isNotEmpty ? <String>['我想让这件事更接近${values.first}。'] : desire;
    return SecondThoughtChangeTalk(
      desire: inferredDesire,
      ability: ability.isEmpty ? const <String>['我可以先做一个很小、可逆的实验。'] : ability,
      reasons: reasons.isEmpty && values.isNotEmpty ? <String>['这样做的理由是：我在乎${values.take(2).join('、')}。'] : reasons,
      need: need,
      activation: activation,
      commitment: commitment,
      takingSteps: taking,
    );
  }

  List<String> _sentencesWith(String input, List<String> words) {
    final parts = input.split(RegExp(r'[。！？!?\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty);
    final found = <String>[];
    for (final part in parts) {
      if (words.any(part.contains)) found.add(part.length > 90 ? '${part.substring(0, 90)}…' : part);
    }
    return found.take(3).toList(growable: false);
  }

  List<SecondThoughtDecisionOption> _buildOptions(String type, List<String> values) {
    final valueText = values.isEmpty ? '核心价值' : values.take(3).join('、');
    return <SecondThoughtDecisionOption>[
      SecondThoughtDecisionOption(
        optionName: 'A. 维持现状',
        shortTermBenefits: const <String>['暂时降低压力', '不用立刻面对未知'],
        shortTermCosts: const <String>['矛盾可能继续循环', '行动能量继续被消耗'],
        longTermBenefits: const <String>['保留稳定与熟悉结构'],
        longTermCosts: const <String>['可能持续背离真正重要的价值', '未来后悔成本上升'],
        valueAlignment: '部分照顾安全，但可能牺牲$valueText。',
        reversibility: '中',
        riskLevel: '中',
        costOfInaction: '让环境、时间或他人替你做决定。',
      ),
      SecondThoughtDecisionOption(
        optionName: 'B. 采取改变',
        shortTermBenefits: const <String>['重新获得主动感', '让价值有行动证据'],
        shortTermCosts: const <String>['需要面对不适、风险或他人反应'],
        longTermBenefits: <String>['更可能接近$valueText', '积累自我信任'],
        longTermCosts: const <String>['需要承担选择后的调整成本'],
        valueAlignment: '更有机会支持$valueText，但需要控制风险。',
        reversibility: '视具体行动而定',
        riskLevel: type == 'No-No' ? '高' : '中',
        costOfInaction: '错过窗口，或继续被旧模式牵引。',
      ),
      const SecondThoughtDecisionOption(
        optionName: 'C. 暂缓但设定期限',
        shortTermBenefits: <String>['避免冲动', '争取更多信息'],
        shortTermCosts: <String>['若没有期限，容易变成拖延'],
        longTermBenefits: <String>['用时间换取清晰和准备'],
        longTermCosts: <String>['可能延长内耗'],
        valueAlignment: '适合需要更多信息但不能无限拖延的情况。',
        reversibility: '高',
        riskLevel: '低-中',
        costOfInaction: '必须设置复查日期，否则代价继续累积。',
      ),
      const SecondThoughtDecisionOption(
        optionName: 'D. 第三条路 / 实验性方案',
        shortTermBenefits: <String>['降低二选一压力', '用小实验获得真实信息'],
        shortTermCosts: <String>['需要设计清楚边界与评估点'],
        longTermBenefits: <String>['更可能兼顾多个价值', '减少后悔和极端化'],
        longTermCosts: <String>['可能需要多轮迭代'],
        valueAlignment: '通常是矛盾心理最适合先尝试的方向。',
        reversibility: '高',
        riskLevel: '低',
        costOfInaction: '如果不实验，矛盾只能停留在想象层。',
      ),
    ];
  }

  List<String> _buildThirdWays(String type, String input) {
    final ways = <String>[
      '先做一个 24–72 小时的小实验，而不是立即做终局决定。',
      '设置一个复查日期：到那天只评估事实证据，不反复自责。',
      '把不可逆决定拆成可逆步骤：搜索、沟通、试做、记录反馈。',
    ];
    if (input.contains('辞职') || input.contains('工作')) ways.add('不立刻辞职，先更新简历、投 1–3 个岗位或访谈一个行业内的人。');
    if (input.contains('关系') || input.contains('分手')) ways.add('不立刻做最终关系决定，先进行一次边界清楚、非指责式沟通。');
    if (input.contains('学习') || input.contains('拖延')) ways.add('不要求彻底自律，只做 10 分钟启动实验，观察阻力来自哪里。');
    return ways.take(5).toList(growable: false);
  }

  SecondThoughtActionExperiment _buildActionExperiment({required String input, required String type, required List<String> values, required String scene}) {
    String action = '写下两列：我靠近它是因为……；我远离它是因为……。每列至少 3 条。';
    String duration = '10 分钟';
    if (input.contains('学习') || input.contains('拖延') || input.contains('工作')) {
      action = '打开相关材料，只做 10 分钟，不追求完成；结束后记录“哪个声音最强”。';
      duration = '10 分钟';
    } else if (input.contains('手机') || input.contains('刷')) {
      action = '把手机放到离手两步远的位置，先做 10 分钟替代动作，再决定是否继续刷。';
      duration = '10 分钟';
    } else if (input.contains('辞职') || input.contains('换工作')) {
      action = '更新简历或岗位搜索 20 分钟，只收集信息，不做最终决定。';
      duration = '20 分钟';
    } else if (input.contains('关系') || input.contains('分手') || input.contains('伴侣')) {
      action = '写一段不指责的表达：我在乎什么、我害怕什么、我希望先怎么沟通。';
      duration = '15 分钟';
    }
    final valueText = values.isEmpty ? '核心价值' : values.take(2).join('、');
    return SecondThoughtActionExperiment(
      microAction: action,
      startTime: '今天一个能被提醒的固定时刻',
      duration: duration,
      successCriteria: '只要开始并完成最低时长就算成功，不用解决整个问题。',
      ifThenPlan: <Map<String, String>>[
        <String, String>{'if': '如果开始前又想逃避', 'then': '先把动作缩小到 2 分钟，只做打开/写标题/放远手机这一步'},
        <String, String>{'if': '如果出现自责声音', 'then': '把它命名为“羞耻声音”，提醒自己：我在做实验，不是在审判自己'},
        <String, String>{'if': '如果仍然摇摆', 'then': '回到价值问题：哪一步最能照顾$valueText，同时风险最小'},
      ],
      recoveryPlanIfFailed: '没有完成也不归零。只记录失败发生前 10 分钟的环境、情绪和身体状态，然后把下一次行动再缩小一半。',
    );
  }

  String _buildUserReply({required String type, required List<String> values, required List<SecondThoughtForce> go, required List<SecondThoughtForce> no, required List<SecondThoughtInnerVoice> voices, required SecondThoughtActionExperiment action}) {
    final valueText = values.isEmpty ? '你真正重视的东西' : values.take(3).join('、');
    final goText = go.isEmpty ? '你想靠近某种可能' : go.first.content;
    final noText = no.isEmpty ? '你也在担心代价或风险' : no.first.content;
    final voicesText = voices.take(3).map((v) => v.voiceName).join('、');
    return '我先不把这件事简化成“你应该怎么做”。从现在的信息看，它更像是 $type 型矛盾：一方面，$goText；另一方面，$noText。\n\n这不是软弱，而是多个真实动机同时存在。现在桌上至少有这些内在声音：$voicesText。它们都在保护某些东西，只是保护方式不同。\n\n这件事背后可能触碰到：$valueText。下一步不一定是做最终决定，而是先用一个小实验把矛盾从脑内循环带到现实证据里。\n\n【下一小步】${action.microAction}\n时间：${action.startTime}\n时长：${action.duration}\n完成标准：${action.successCriteria}\n\n你可以先确认：这些价值里，哪一个最像你真正想守住的自己？';
  }

  String _coreConflict(List<SecondThoughtForce> go, List<SecondThoughtForce> no) {
    final a = go.isNotEmpty ? go.first.content : '一部分你想靠近新的可能';
    final b = no.isNotEmpty ? no.first.content : '另一部分你担心代价与风险';
    return '一方面，$a；另一方面，$b。';
  }

  String _inferTitle(String input, String type) {
    final clean = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return '一次$type矛盾探索';
    return clean.length <= 24 ? clean : '${clean.substring(0, 24)}…';
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is List) return value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
  return <Map<String, dynamic>>[];
}

List<String> _stringList(Object? value) {
  if (value == null) return <String>[];
  if (value is List) return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  final raw = value.toString().trim();
  if (raw.isEmpty) return <String>[];
  return raw.split(RegExp(r'[,，;；\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
}

double _double(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0.0;
}
