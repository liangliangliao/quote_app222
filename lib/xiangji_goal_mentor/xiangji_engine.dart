import 'xiangji_knowledge_repository.dart';
import 'xiangji_models.dart';

class XiangjiSafetyAssessment {
  const XiangjiSafetyAssessment({
    required this.highRisk,
    required this.message,
  });

  final bool highRisk;
  final String message;
}

class _RouteRule {
  const _RouteRule({
    required this.systemId,
    required this.mechanismId,
    required this.label,
    required this.keywords,
  });

  final String systemId;
  final String mechanismId;
  final String label;
  final List<String> keywords;
}

class _RouteMatch {
  const _RouteMatch(this.rule, this.score);

  final _RouteRule rule;
  final int score;
}

class XiangjiGoalMentorEngine {
  static const List<_RouteRule> _rules = <_RouteRule>[
    _RouteRule(
      systemId: 'maslow',
      mechanismId: 'capacity_constraint',
      label: '资源与容量不足',
      keywords: <String>['太累', '疲惫', '睡不够', '没时间', '过载', '身体', '生病', '撑不住'],
    ),
    _RouteRule(
      systemId: 'self_determination',
      mechanismId: 'external_control',
      label: '外部标准与目标内化',
      keywords: <String>['别人要求', '父母', '应该', '羡慕', '比较', '面子', '证明自己', '不属于我'],
    ),
    _RouteRule(
      systemId: 'ellis_rebt',
      mechanismId: 'perfectionism',
      label: '完美主义与绝对要求',
      keywords: <String>['完美', '必须', '不能失败', '一定要', '受不了', '不能出错'],
    ),
    _RouteRule(
      systemId: 'beck_cognitive_therapy',
      mechanismId: 'result_dependency',
      label: '结果焦虑与未经检验的预测',
      keywords: <String>['失败', '焦虑', '害怕', '担心', '没能力', '否定', '来不及', '没希望'],
    ),
    _RouteRule(
      systemId: 'act',
      mechanismId: 'experiential_avoidance',
      label: '等待不适消失才行动',
      keywords: <String>['不想面对', '逃避', '羞耻', '厌烦', '低落', '情绪', '不舒服', '不敢'],
    ),
    _RouteRule(
      systemId: 'behavioral_activation',
      mechanismId: 'avoidance_loop',
      label: '短期回避循环',
      keywords: <String>['刷手机', '躺着', '取消', '拖着', '什么都不做', '封闭自己'],
    ),
    _RouteRule(
      systemId: 'gollwitzer',
      mechanismId: 'action_start',
      label: '启动线索不足',
      keywords: <String>['拖延', '忘记', '开始不了', '走不动', '总不开始', '执行', '行动', '坚持不了'],
    ),
    _RouteRule(
      systemId: 'bandura',
      mechanismId: 'skill_confidence',
      label: '技能与胜任感不足',
      keywords: <String>['不会做', '不知道怎么', '做不到', '没经验', '缺少方法', '学不会'],
    ),
    _RouteRule(
      systemId: 'frankl',
      mechanismId: 'meaning_disconnect',
      label: '意义断裂',
      keywords: <String>['没意义', '为什么', '空虚', '失去方向', '还有什么用', '无意义'],
    ),
    _RouteRule(
      systemId: 'oettingen',
      mechanismId: 'wish_obstacle_gap',
      label: '愿望与现实障碍脱节',
      keywords: <String>['想象', '幻想', '愿望很大', '总是计划', '计划很多', '障碍'],
    ),
    _RouteRule(
      systemId: 'dewey',
      mechanismId: 'feedback_gap',
      label: '方法缺少现实检验',
      keywords: <String>['反复失败', '方法没用', '试了很多', '不知道原因', '总是一样'],
    ),
    _RouteRule(
      systemId: 'self_determination',
      mechanismId: 'goal_mist',
      label: '目标模糊与自主方向',
      keywords: <String>['迷茫', '没有目标', '不知道想要什么', '方向', '不知道做什么', '找不到目标'],
    ),
  ];

  static const List<String> _selfHarmKeywords = <String>[
    '自杀',
    '结束生命',
    '结束自己',
    '不想活',
    '活不下去',
    '想死',
    '不如死',
    '死了算了',
    '活着没意思',
    '没有活下去的理由',
    '希望永远别醒来',
    '不想醒来',
    '消失就好了',
    '伤害自己',
    '自残',
  ];

  static const List<String> _violenceKeywords = <String>[
    '杀了他',
    '杀了她',
    '想杀人',
    '弄死他',
    '弄死她',
    '伤害别人',
    '同归于尽',
  ];

  static const List<String> _abuseDangerKeywords = <String>[
    '被家暴',
    '他打我',
    '她打我',
    '威胁要杀我',
    '控制我不让我走',
  ];

  static const List<String> _dangerousSelfNeglectKeywords = <String>[
    '几天不吃饭',
    '不配吃饭',
    '几天不睡觉',
    '工作到倒下',
    '累死算了',
  ];

  XiangjiSafetyAssessment assessSafety(String text) {
    final normalized = text.trim().toLowerCase();
    if (_violenceKeywords.any(normalized.contains)) {
      return const XiangjiSafetyAssessment(
        highRisk: true,
        message: '现在最重要的不是目标规划，而是先防止任何人受到伤害。'
            '如果你可能立即伤害他人，请立刻与对方拉开距离，移开武器或危险物品，并联系当地紧急服务或一位能到场的可信任的人。'
            '向己不能替代专业危机支持。',
      );
    }
    if (_abuseDangerKeywords.any(normalized.contains)) {
      return const XiangjiSafetyAssessment(
        highRisk: true,
        message: '这可能涉及现实的暴力或控制风险，先不做目标指导。'
            '如果危险迫近，请前往更安全的地方，联系当地紧急服务或一位可信任、能实际帮助你的人。'
            '如果你未成年，请尽快告诉可信任的成年人。',
      );
    }
    if (_dangerousSelfNeglectKeywords.any(normalized.contains)) {
      return const XiangjiSafetyAssessment(
        highRisk: true,
        message: '先停止用绝食、不睡或过度工作推进目标。'
            '如果你已经出现昏厥、意识混乱或其他紧急身体风险，请立即联系当地紧急服务，并请可信任的人陪伴。'
            '休息和进食不是目标失败。',
      );
    }
    if (!_selfHarmKeywords.any(normalized.contains)) {
      return const XiangjiSafetyAssessment(highRisk: false, message: '');
    }
    return const XiangjiSafetyAssessment(
      highRisk: true,
      message: '现在最重要的不是目标规划，而是先确保你的安全并获得现实支持。'
          '如果你可能立即伤害自己或他人，请立刻联系当地紧急服务，移开可能造成伤害的物品，并联系一位可信任的人陪在你身边。'
          '如果你未成年，请尽快告诉可信任的成年人。向己不能替代专业危机支持。',
    );
  }

  XiangjiGoalDraft buildDraft(
    String text,
    XiangjiKnowledgeCatalog catalog,
  ) {
    final original = text.trim();
    if (original.isEmpty) {
      throw const FormatException('请先写下你最不想忘记的目标');
    }
    final safety = assessSafety(original);
    if (safety.highRisk) {
      throw StateError(safety.message);
    }
    final match = _route(original);
    final values = _inferValues(original);
    final step = _buildStep(
      goalText: original,
      mechanismId: match.rule.mechanismId,
      sourceSystemId: match.rule.systemId,
    );
    final guidance = _guidanceFromMatch(
      match,
      catalog,
      actionText: step.actionText,
    );
    return XiangjiGoalDraft(
      originalText: original,
      whyText: '这件事可能与你想守住的“${values.join('、')}”有关。'
          '这只是待确认草案，请以你的真实原因修改它。',
      higherValues: values,
      successDefinition: '我能重复走出一个与这个方向一致、由自己控制的行动，并根据现实反馈调整。',
      scopeText: '先以未来 7 天内可观察的一步为范围，不把它变成终身承诺。',
      guidance: guidance,
      step: step,
    );
  }

  XiangjiGuidance guidanceFor(
    String text,
    XiangjiKnowledgeCatalog catalog, {
    String currentSystemId = '',
    String actionText = '',
  }) {
    final match = _route(text);
    _RouteMatch selected = match;
    if (match.score == 0 && currentSystemId.isNotEmpty) {
      final matchingRules =
          _rules.where((item) => item.systemId == currentSystemId).toList();
      final existing = matchingRules.isNotEmpty
          ? matchingRules.first
          : _RouteRule(
              systemId: currentSystemId,
              mechanismId: 'knowledge_action_gap',
              label: '目标记忆与知行连接',
              keywords: const <String>[],
            );
      selected = _RouteMatch(existing, 0);
    }
    final derivedAction = actionText.trim().isNotEmpty
        ? actionText.trim()
        : _buildStep(
            goalText: text,
            mechanismId: selected.rule.mechanismId,
            sourceSystemId: selected.rule.systemId,
          ).actionText;
    return _guidanceFromMatch(
      selected,
      catalog,
      actionText: derivedAction,
    );
  }

  XiangjiDailyStep createStep(
    String goalText,
    XiangjiGuidance guidance,
  ) {
    return _buildStep(
      goalText: goalText,
      mechanismId: guidance.mechanismId,
      sourceSystemId: guidance.systemId,
    );
  }

  XiangjiDailyStep shrinkStep(XiangjiDailyStep current) {
    return XiangjiDailyStep(
      id: 0,
      goalId: current.goalId,
      goalVersionId: current.goalVersionId,
      actionText: current.smallerVariant,
      triggerContext: current.triggerContext,
      minimumDone: '完成 2 分钟，或留下第一个可见痕迹。',
      evidenceRule: '保存一句记录、一个勾选或一张不含敏感信息的截图。',
      controllabilityReason: '只要求启动和留下痕迹，不要求得到外部结果。',
      smallerVariant: '只用 30 秒写下第一句话，或打开材料并标记第一处。',
      sourceSystemId: current.sourceSystemId,
      status: 'ready',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  XiangjiDailyStep alternativeStep(
    XiangjiGoal goal,
    XiangjiDailyStep current,
  ) {
    final shortGoal = _shortGoal(goal.originalText);
    return XiangjiDailyStep(
      id: 0,
      goalId: goal.id,
      goalVersionId: goal.versionId,
      actionText: '用 5 分钟写下“$shortGoal”当前最值得验证的一个问题。',
      triggerContext: '在今天下一段不被打断的 5 分钟开始。',
      minimumDone: '只写一个问题，不要求立即找到答案。',
      evidenceRule: '保留这一个问题的文字记录。',
      controllabilityReason: '把推进改为澄清，完成标准完全由你控制。',
      smallerVariant: '只写下“我现在最不确定的是……”并补完一句。',
      sourceSystemId: current.sourceSystemId,
      status: 'ready',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String evidenceSummary({
    required XiangjiDailyStep step,
    required String resultType,
    required String userText,
  }) {
    final note = userText.trim();
    if (resultType == 'completed' || resultType == 'partially_completed') {
      return '你完成了一个由自己控制的真实动作：${step.actionText}'
          '${note.isEmpty ? '。' : '；你记录了：$note'}';
    }
    if (resultType == 'blocked') {
      return '你识别了这一步当前不适配的现实条件'
          '${note.isEmpty ? '，这为缩小范围或改变方法提供了依据。' : '：$note。'}';
    }
    return note.isEmpty ? '你如实记录了当前状态，没有把未开始解释成人格失败。' : note;
  }

  XiangjiCalibrationDecision calibrationDecision({
    required XiangjiGoal goal,
    required String valueAnswer,
    required String goalAnswer,
    required String methodAnswer,
    required String actionAnswer,
  }) {
    XiangjiCalibrationResult result;
    if (valueAnswer == 'no' || goalAnswer == 'no') {
      result = XiangjiCalibrationResult.reselect;
    } else if (actionAnswer == 'conditions_unavailable') {
      result = XiangjiCalibrationResult.pause;
    } else if (methodAnswer == 'ineffective') {
      result = XiangjiCalibrationResult.changeMethod;
    } else if (actionAnswer == 'too_big') {
      result = XiangjiCalibrationResult.reduceScope;
    } else {
      result = XiangjiCalibrationResult.continueGoal;
    }
    return XiangjiCalibrationDecision(
      valueAssessment: _valueAssessment(valueAnswer),
      goalAssessment: _goalAssessment(goalAnswer),
      methodAssessment: _methodAssessment(methodAnswer),
      actionAssessment: _actionAssessment(actionAnswer),
      result: result,
      retainedValues: goal.higherValues,
    );
  }

  _RouteMatch _route(String input) {
    final text = input.toLowerCase();
    _RouteRule? best;
    var bestScore = 0;
    for (final rule in _rules) {
      var score = 0;
      for (final keyword in rule.keywords) {
        if (text.contains(keyword.toLowerCase())) score += keyword.length;
      }
      if (score > bestScore) {
        best = rule;
        bestScore = score;
      }
    }
    return _RouteMatch(
      best ??
          const _RouteRule(
            systemId: 'yangming',
            mechanismId: 'knowledge_action_gap',
            label: '目标记忆与知行连接',
            keywords: <String>[],
          ),
      bestScore,
    );
  }

  XiangjiGuidance _guidanceFromMatch(
    _RouteMatch match,
    XiangjiKnowledgeCatalog catalog, {
    required String actionText,
  }) {
    final system = catalog.system(match.rule.systemId);
    if (system == null) {
      throw StateError('本地书库依据不足，无法选择当前导师');
    }
    final sources = catalog.citationsFor(system);
    if (sources.isEmpty) {
      throw StateError('本地书库没有可回定位依据，已停止生成确定性观点');
    }
    final core = system.coreIdeas.isEmpty
        ? system.knowledgeView
        : system.coreIdeas.first;
    final boundary = system.tensions.isEmpty
        ? '这一视角只处理当前最相关的一层，不替代医疗、心理治疗或其他专业支持。'
        : system.tensions.first;
    return XiangjiGuidance(
      systemId: system.id,
      mentorName: system.displayName,
      mechanismId: match.rule.mechanismId,
      mechanismLabel: match.rule.label,
      coreJudgment: core,
      selectionReason: match.score > 0
          ? '你的描述更接近“${match.rule.label}”。${system.decisionCue}'
          : '目前信息较少，先把“${match.rule.label}”作为可撤回的起点。'
              '这不是对你的定论；如果现实反馈不支持，可以换视角。${system.decisionCue}',
      boundaryNote: boundary,
      knowledgeView: system.knowledgeView,
      structureText: system.transformationPath,
      detailText: system.splitDiagnosis,
      actionDerivation: '知识库应用推导：$actionText',
      confidence: match.score > 0 ? 0.86 : 0.58,
      sources: sources,
    );
  }

  XiangjiDailyStep _buildStep({
    required String goalText,
    required String mechanismId,
    required String sourceSystemId,
  }) {
    final shortGoal = _shortGoal(goalText);
    String action;
    String trigger;
    String minimum;
    String evidence;
    String reason;
    String smaller;

    switch (mechanismId) {
      case 'goal_mist':
      case 'external_control':
        action = '用 5 分钟写下：如果没有任何人评价，我仍愿意为“$shortGoal”保留什么。';
        trigger = '在今天下一段安静的 5 分钟开始。';
        minimum = '写完一句自己的回答。';
        evidence = '保留这句回答。';
        reason = '只澄清你的选择，不要求立刻证明目标正确。';
        smaller = '只补完一句：“即使没人知道，我仍想保留……”';
        break;
      case 'capacity_constraint':
        action = '为“$shortGoal”划出 10 分钟不被打扰的恢复窗口。';
        trigger = '在今天最早可用的空档开始。';
        minimum = '保护这 10 分钟，不追加任务。';
        evidence = '记录恢复前后最明显的一项变化。';
        reason = '恢复和容量也是目标条件，完成不依赖外部评价。';
        smaller = '先保护 2 分钟，放下屏幕并让身体停下来。';
        break;
      case 'result_dependency':
      case 'perfectionism':
        action = '用 10 分钟完成“$shortGoal”的一个可测试草稿。';
        trigger = '下一次出现“必须做好”的念头时开始。';
        minimum = '产出一个允许不完整的草稿。';
        evidence = '保存草稿或一句测试结论。';
        reason = '只检验方法，不把结果等同于自我价值。';
        smaller = '只用 2 分钟写下草稿的第一句。';
        break;
      case 'skill_confidence':
        action = '用 10 分钟模仿一个与“$shortGoal”有关的最小示范动作。';
        trigger = '找到第一个可参考的示范后立即开始。';
        minimum = '完整照做一次，不评价好坏。';
        evidence = '写下一处已经会做和一处仍不清楚的地方。';
        reason = '先获得真实掌握经验，而不是凭感觉判定“做不到”。';
        smaller = '只观察示范的第一个动作，并照做一次。';
        break;
      case 'meaning_disconnect':
        action = '用 5 分钟写下“$shortGoal”今天能够服务的一个具体的人或责任。';
        trigger = '在今天下一次问“有什么用”时开始。';
        minimum = '只写一个具体对象和一件小事。';
        evidence = '保留这句责任连接。';
        reason = '把抽象意义落到当下可回应的对象。';
        smaller = '只补完一句：“今天，这件事可以帮助……”';
        break;
      default:
        action = '用 10 分钟完成“$shortGoal”的最小可见版本。';
        trigger = '下一次想到这个目标时，在 60 秒内开始。';
        minimum = '持续 10 分钟，或提前留下一个可见成果。';
        evidence = '保留一句记录、一个勾选或一张不含敏感信息的截图。';
        reason = '启动与留下证据由你控制，不以外在结果作为完成条件。';
        smaller = '只用 2 分钟完成第一句话、第一步或第一个标记。';
        break;
    }
    return XiangjiDailyStep(
      id: 0,
      goalId: 0,
      goalVersionId: 0,
      actionText: action,
      triggerContext: trigger,
      minimumDone: minimum,
      evidenceRule: evidence,
      controllabilityReason: reason,
      smallerVariant: smaller,
      sourceSystemId: sourceSystemId,
      status: 'ready',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  List<String> _inferValues(String text) {
    final values = <String>[];
    void add(String value) {
      if (!values.contains(value) && values.length < 3) values.add(value);
    }

    if (_containsAny(text, <String>['学习', '考试', '读书', '技能', '研究'])) add('成长');
    if (_containsAny(text, <String>['工作', '事业', '职业', '创业', '创作'])) add('创造与胜任');
    if (_containsAny(text, <String>['家人', '关系', '伴侣', '孩子', '朋友'])) add('连接与责任');
    if (_containsAny(text, <String>['健康', '运动', '睡眠', '身体', '康复'])) add('身心健康');
    if (_containsAny(text, <String>['自由', '自己', '选择', '独立'])) add('自主');
    if (_containsAny(text, <String>['帮助', '贡献', '服务', '公益'])) add('贡献');
    if (values.isEmpty) {
      add('自主');
      add('成长');
    }
    return values;
  }

  bool _containsAny(String text, List<String> terms) =>
      terms.any((term) => text.contains(term));

  String _shortGoal(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final runes = normalized.runes.toList(growable: false);
    if (runes.length <= 24) return normalized;
    return '${String.fromCharCodes(runes.take(24))}…';
  }

  String _valueAssessment(String answer) {
    switch (answer) {
      case 'no':
        return '原目标背后的价值已经不再被你认同。';
      case 'uncertain':
        return '这项价值仍需要进一步澄清，但不必强行得出结论。';
      default:
        return '原目标背后的高层价值仍然重要。';
    }
  }

  String _goalAssessment(String answer) {
    switch (answer) {
      case 'no':
        return '当前具体目标已不再是承载该价值的合适路径。';
      case 'uncertain':
        return '当前目标是否适配仍需通过更小实验观察。';
      default:
        return '当前具体目标仍可承载这项价值。';
    }
  }

  String _methodAssessment(String answer) {
    switch (answer) {
      case 'ineffective':
        return '当前方法没有得到现实反馈支持，需要改变。';
      case 'uncertain':
        return '当前方法证据不足，适合继续做低成本检验。';
      default:
        return '当前方法已有一定有效反馈。';
    }
  }

  String _actionAssessment(String answer) {
    switch (answer) {
      case 'conditions_unavailable':
        return '当前条件暂不允许继续推进，暂停可以保护目标和人。';
      case 'too_big':
        return '当前一步超过现实资源，需要缩小。';
      default:
        return '当前一步足够小、可控，并与现实资源基本适配。';
    }
  }
}
