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
  const _RouteMatch(this.rule, this.score, {this.explicitSelection = false});

  final _RouteRule rule;
  final int score;
  final bool explicitSelection;
}

class XiangjiGoalMentorEngine {
  static const List<_RouteRule> _rules = <_RouteRule>[
    _RouteRule(
      systemId: 'adler',
      mechanismId: 'hidden_goal',
      label: '隐藏目标与证明压力',
      keywords: <String>['证明自己', '自卑', '没价值', '不如别人', '退缩', '面子', '优越', '贡献'],
    ),
    _RouteRule(
      systemId: 'aristotle',
      mechanismId: 'good_life_hierarchy',
      label: '目标层级与好生活',
      keywords: <String>['优先级', '目标太多', '值得', '品格', '平衡', '长期', '好生活', '手段'],
    ),
    _RouteRule(
      systemId: 'carver_scheier',
      mechanismId: 'feedback_reengagement',
      label: '反馈差距与重新投入',
      keywords: <String>['进度', '反馈', '偏差', '落后', '放弃', '换目标', '反复失败', '没进展'],
    ),
    _RouteRule(
      systemId: 'dewey',
      mechanismId: 'inquiry_experiment',
      label: '现实调查与小实验',
      keywords: <String>['不知道怎么办', '问题', '方法没用', '试试看', '实验', '现实', '条件', '调查'],
    ),
    _RouteRule(
      systemId: 'epictetus',
      mechanismId: 'control_boundary',
      label: '可控范围与角色责任',
      keywords: <String>['控制不了', '焦虑', '别人怎么看', '结果', '运气', '担心', '责任', '失控'],
    ),
    _RouteRule(
      systemId: 'frankl',
      mechanismId: 'meaning_responsibility',
      label: '意义、责任与自我超越',
      keywords: <String>['没意义', '为什么', '空虚', '失去方向', '还有什么用', '无意义', '责任', '帮助'],
    ),
    _RouteRule(
      systemId: 'girard',
      mechanismId: 'mimetic_desire',
      label: '欲望来源与模仿审计',
      keywords: <String>['羡慕', '比较', '别人都有', '流行', '父母要求', '应该', '竞争', '想被看见'],
    ),
    _RouteRule(
      systemId: 'locke_latham',
      mechanismId: 'goal_design',
      label: '清晰目标与执行反馈',
      keywords: <String>['拖延', '执行', '行动', '计划', '具体', '期限', '绩效', '怎么开始', '坚持不了'],
    ),
    _RouteRule(
      systemId: 'nietzsche',
      mechanismId: 'value_revaluation',
      label: '价值重估与自我克服',
      keywords: <String>['价值', '活成自己', '重新开始', '突破', '恐惧', '评价', '规则', '重估'],
    ),
    _RouteRule(
      systemId: 'positive_psychology',
      mechanismId: 'self_concordance',
      label: '自我和谐与可持续幸福',
      keywords: <String>['迷茫', '没有目标', '幸福', '优势', '自己想要', '身心', '可持续', '方向', '走不动'],
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
    XiangjiKnowledgeCatalog catalog, {
    String selectedMentorId = '',
  }) {
    final original = text.trim();
    if (original.isEmpty) {
      throw const FormatException('请先写下你最不想忘记的目标');
    }
    final safety = assessSafety(original);
    if (safety.highRisk) {
      throw StateError(safety.message);
    }
    final match = _selectRoute(
      original,
      selectedMentorId: selectedMentorId,
    );
    final system = catalog.system(match.rule.systemId);
    if (system == null) {
      throw StateError('所选导师不在受控知识库中');
    }
    final values = _inferValues(original);
    final step = _buildStep(
      goalText: original,
      mechanismId: match.rule.mechanismId,
      sourceSystemId: match.rule.systemId,
      system: system,
    );
    final guidance = _guidanceFromMatch(
      match,
      catalog,
      actionText: step.actionText,
    );
    return XiangjiGoalDraft(
      originalText: original,
      whyText: '这件事可能与你想守住的“${values.join('、')}”有关。'
          '${system.profile?.centralQuestion ?? system.decisionCue}'
          ' 这是待确认的导师提问，不是对你的定论；请改成你的真实原因。',
      higherValues: values,
      successDefinition: system.journey?.successDefinition ??
          '我能重复走出一个与这个方向一致、由自己控制的行动，并根据现实反馈调整。',
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
    final selected = _selectRoute(
      text,
      selectedMentorId: currentSystemId,
    );
    final system = catalog.system(selected.rule.systemId);
    if (system == null) {
      throw StateError('当前导师不在受控知识库中');
    }
    final derivedAction = actionText.trim().isNotEmpty
        ? actionText.trim()
        : _buildStep(
            goalText: text,
            mechanismId: selected.rule.mechanismId,
            sourceSystemId: selected.rule.systemId,
            system: system,
          ).actionText;
    return _guidanceFromMatch(
      selected,
      catalog,
      actionText: derivedAction,
    );
  }

  XiangjiDailyStep createStep(
    String goalText,
    XiangjiGuidance guidance, {
    XiangjiKnowledgeSystem? system,
  }) {
    return _buildStep(
      goalText: goalText,
      mechanismId: guidance.mechanismId,
      sourceSystemId: guidance.systemId,
      system: system,
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
    if (resultType == 'no_longer_relevant') {
      return '你识别出这一步已经不再适合作为当前目标的载体'
          '${note.isEmpty ? '，及时退出不合适的路径也是成长证据。' : '：$note。'}';
    }
    return note.isEmpty
        ? '你如实记录了当前状态，没有把未开始解释成人格失败。'
        : '你如实记录了尚未开始的现实条件：$note。';
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

  _RouteMatch _selectRoute(
    String input, {
    String selectedMentorId = '',
  }) {
    if (selectedMentorId.isNotEmpty) {
      for (final rule in _rules) {
        if (rule.systemId == selectedMentorId) {
          return _RouteMatch(rule, 100, explicitSelection: true);
        }
      }
      return _RouteMatch(
        _RouteRule(
          systemId: selectedMentorId,
          mechanismId: 'mentor_goal_core',
          label: '用户选择的目标导师',
          keywords: const <String>[],
        ),
        100,
        explicitSelection: true,
      );
    }
    return _route(input);
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
            systemId: 'positive_psychology',
            mechanismId: 'self_concordance',
            label: '自我和谐与可持续幸福',
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
      selectionReason: match.explicitSelection
          ? '你主动选择了${system.displayName}。后续的价值判断、方法建议、每日行动与校准都保持这一导师视角，直到你明确更换。${system.decisionCue}'
          : match.score > 0
          ? '你的描述更接近“${match.rule.label}”。${system.decisionCue}'
          : '目前信息较少，先把“${match.rule.label}”作为可撤回的起点。'
              '这不是对你的定论；如果现实反馈不支持，可以换视角。${system.decisionCue}',
      boundaryNote: boundary,
      knowledgeView: system.knowledgeView,
      structureText: system.transformationPath,
      detailText: system.splitDiagnosis,
      actionDerivation: '知识库应用推导：$actionText',
      confidence: match.explicitSelection ? 1 : (match.score > 0 ? 0.86 : 0.58),
      sources: sources,
    );
  }

  XiangjiDailyStep _buildStep({
    required String goalText,
    required String mechanismId,
    required String sourceSystemId,
    XiangjiKnowledgeSystem? system,
  }) {
    final shortGoal = _shortGoal(goalText);
    if (system?.profile != null &&
        system!.practices.isNotEmpty &&
        system.settingSteps.isNotEmpty) {
      final practice = system.practices.first;
      final setting = system.settingSteps.first;
      return XiangjiDailyStep(
        id: 0,
        goalId: 0,
        goalVersionId: 0,
        actionText: '围绕“$shortGoal”，${practice.instruction}',
        triggerContext: '在今天下一段可保护的 10 分钟开始。',
        minimumDone: '完成一次“${practice.title}”并留下一个可见记录。',
        evidenceRule: '用一句话回答：${practice.reflectionQuestion}',
        controllabilityReason:
            '行动来自${system.displayName}的“${setting.title}”路径，只承诺你能选择的实践，不承诺外部结果。',
        smallerVariant: '只写下一句回答：“${setting.mentorQuestion}”',
        sourceSystemId: sourceSystemId,
        status: 'ready',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }
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
