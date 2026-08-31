import 'dart:convert';

import 'xiangji_engine.dart';
import 'xiangji_grounded_ai_service.dart';
import 'xiangji_knowledge_repository.dart';
import 'xiangji_models.dart';

enum XiangjiGoalInterest { create, learn, career, connect, wellbeing, explore }

extension XiangjiGoalInterestX on XiangjiGoalInterest {
  String get label {
    switch (this) {
      case XiangjiGoalInterest.create:
        return '创作与表达';
      case XiangjiGoalInterest.learn:
        return '学习与掌握';
      case XiangjiGoalInterest.career:
        return '工作与事业';
      case XiangjiGoalInterest.connect:
        return '关系与连接';
      case XiangjiGoalInterest.wellbeing:
        return '身心与生活';
      case XiangjiGoalInterest.explore:
        return '探索与选择';
    }
  }
}

enum XiangjiSupportTone { gentle, practical, curious }

extension XiangjiSupportToneX on XiangjiSupportTone {
  String get label {
    switch (this) {
      case XiangjiSupportTone.gentle:
        return '轻一点带我开始';
      case XiangjiSupportTone.practical:
        return '直接告诉我怎么做';
      case XiangjiSupportTone.curious:
        return '先帮我看清盲点';
    }
  }
}

class XiangjiGoalSupportProfile {
  const XiangjiGoalSupportProfile({
    required this.interest,
    required this.tone,
    required this.minutes,
  });

  final XiangjiGoalInterest interest;
  final XiangjiSupportTone tone;
  final int minutes;

  Map<String, Object?> toJson() => <String, Object?>{
        'interest': interest.name,
        'support_tone': tone.name,
        'minutes': minutes,
      };

  factory XiangjiGoalSupportProfile.fromJson(Map<String, Object?> json) {
    final interestName = (json['interest'] ?? '').toString();
    final toneName = (json['support_tone'] ?? '').toString();
    final minutes = int.tryParse('${json['minutes'] ?? 5}') ?? 5;
    return XiangjiGoalSupportProfile(
      interest: XiangjiGoalInterest.values.firstWhere(
        (item) => item.name == interestName,
        orElse: () => XiangjiGoalInterest.create,
      ),
      tone: XiangjiSupportTone.values.firstWhere(
        (item) => item.name == toneName,
        orElse: () => XiangjiSupportTone.gentle,
      ),
      minutes: <int>[2, 5, 10, 15, 20].contains(minutes) ? minutes : 5,
    );
  }
}

class XiangjiTheoryApplication {
  const XiangjiTheoryApplication({
    required this.evidenceId,
    required this.mentorName,
    required this.concept,
    required this.locator,
    required this.caseApplication,
    required this.whyThisAction,
    required this.boundary,
  });

  final String evidenceId;
  final String mentorName;
  final String concept;
  final String locator;
  final String caseApplication;
  final String whyThisAction;
  final String boundary;

  Map<String, Object?> toJson() => <String, Object?>{
        'evidence_id': evidenceId,
        'mentor_name': mentorName,
        'concept': concept,
        'locator': locator,
        'case_application': caseApplication,
        'why_this_action': whyThisAction,
        'boundary': boundary,
      };

  factory XiangjiTheoryApplication.fromJson(Map<String, Object?> json) =>
      XiangjiTheoryApplication(
        evidenceId: (json['evidence_id'] ?? '').toString(),
        mentorName: (json['mentor_name'] ?? '').toString(),
        concept: (json['concept'] ?? '').toString(),
        locator: (json['locator'] ?? '').toString(),
        caseApplication: (json['case_application'] ?? '').toString(),
        whyThisAction: (json['why_this_action'] ?? '').toString(),
        boundary: (json['boundary'] ?? '').toString(),
      );
}

class XiangjiGoalIntelligenceReceipt {
  const XiangjiGoalIntelligenceReceipt({
    required this.aiRequested,
    required this.aiUsed,
    required this.provider,
    required this.model,
    required this.status,
    required this.fallbackReason,
    required this.knowledgeIds,
    required this.generatedAtMs,
    required this.situationSummary,
    required this.blindSpotQuestion,
  });

  final bool aiRequested;
  final bool aiUsed;
  final String provider;
  final String model;
  final String status;
  final String fallbackReason;
  final List<String> knowledgeIds;
  final int generatedAtMs;
  final String situationSummary;
  final String blindSpotQuestion;

  Map<String, Object?> toJson() => <String, Object?>{
        'ai_requested': aiRequested,
        'ai_used': aiUsed,
        'provider': provider,
        'model': model,
        'status': status,
        'fallback_reason': fallbackReason,
        'knowledge_ids': knowledgeIds,
        'generated_at_ms': generatedAtMs,
        'situation_summary': situationSummary,
        'blind_spot_question': blindSpotQuestion,
      };

  factory XiangjiGoalIntelligenceReceipt.fromJson(
    Map<String, Object?> json,
  ) {
    final rawKnowledgeIds = json['knowledge_ids'];
    return XiangjiGoalIntelligenceReceipt(
      aiRequested: json['ai_requested'] == true,
      aiUsed: json['ai_used'] == true,
      provider: (json['provider'] ?? 'local').toString(),
      model: (json['model'] ?? '本地知识规则').toString(),
      status: (json['status'] ?? 'local_selected').toString(),
      fallbackReason: (json['fallback_reason'] ?? '').toString(),
      knowledgeIds: rawKnowledgeIds is List
          ? rawKnowledgeIds
              .map((item) => item.toString())
              .toList(growable: false)
          : const <String>[],
      generatedAtMs: int.tryParse('${json['generated_at_ms'] ?? 0}') ?? 0,
      situationSummary: (json['situation_summary'] ?? '').toString(),
      blindSpotQuestion: (json['blind_spot_question'] ?? '').toString(),
    );
  }
}

class XiangjiGoalPlanRoute {
  const XiangjiGoalPlanRoute({
    required this.id,
    required this.title,
    required this.promise,
    required this.mentorId,
    required this.mentorName,
    required this.understanding,
    required this.blindSpot,
    required this.output,
    required this.whyItWorks,
    required this.successSignal,
    required this.draft,
    required this.applications,
  });

  final String id;
  final String title;
  final String promise;
  final String mentorId;
  final String mentorName;
  final String understanding;
  final String blindSpot;
  final String output;
  final String whyItWorks;
  final String successSignal;
  final XiangjiGoalDraft draft;
  final List<XiangjiTheoryApplication> applications;
}

class XiangjiGoalPlanBundle {
  const XiangjiGoalPlanBundle({
    required this.routes,
    required this.receipt,
  });

  final List<XiangjiGoalPlanRoute> routes;
  final XiangjiGoalIntelligenceReceipt receipt;
}

/// One complete, inspectable learning round: action -> reality -> judgment ->
/// next action. This is deliberately persisted separately from a generic
/// check-in so the user can see what changed and which knowledge caused it.
class XiangjiGoalRoundReview {
  const XiangjiGoalRoundReview({
    required this.goalId,
    required this.stepId,
    required this.result,
    required this.realityFacts,
    required this.realityComparison,
    required this.learning,
    required this.decision,
    required this.decisionReason,
    required this.nextStep,
    required this.theory,
    required this.receipt,
    required this.createdAtMs,
  });

  final int goalId;
  final int stepId;
  final XiangjiCheckinResult result;
  final String realityFacts;
  final String realityComparison;
  final String learning;
  final XiangjiCalibrationResult decision;
  final String decisionReason;
  final XiangjiDailyStep nextStep;
  final XiangjiTheoryApplication theory;
  final XiangjiGoalIntelligenceReceipt receipt;
  final int createdAtMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'goal_id': goalId,
        'step_id': stepId,
        'result': result.value,
        'reality_facts': realityFacts,
        'reality_comparison': realityComparison,
        'learning': learning,
        'decision': decision.value,
        'decision_reason': decisionReason,
        'next_step': <String, Object?>{
          'action_text': nextStep.actionText,
          'trigger_context': nextStep.triggerContext,
          'minimum_done': nextStep.minimumDone,
          'evidence_rule': nextStep.evidenceRule,
          'controllability_reason': nextStep.controllabilityReason,
          'smaller_variant': nextStep.smallerVariant,
          'source_system_id': nextStep.sourceSystemId,
          'status': nextStep.status,
          'created_at_ms': nextStep.createdAtMs,
        },
        'theory': theory.toJson(),
        'receipt': receipt.toJson(),
        'created_at_ms': createdAtMs,
      };

  factory XiangjiGoalRoundReview.fromJson(Map<String, Object?> json) {
    final next = _objectMap(json['next_step']);
    final parsedResult = tryParseXiangjiCheckinResult(json['result']);
    final decisionValue = (json['decision'] ?? '').toString();
    return XiangjiGoalRoundReview(
      goalId: int.tryParse('${json['goal_id'] ?? 0}') ?? 0,
      stepId: int.tryParse('${json['step_id'] ?? 0}') ?? 0,
      result: parsedResult ?? XiangjiCheckinResult.blocked,
      realityFacts: (json['reality_facts'] ?? '').toString(),
      realityComparison: (json['reality_comparison'] ?? '').toString(),
      learning: (json['learning'] ?? '').toString(),
      decision: XiangjiCalibrationResult.values.firstWhere(
        (item) => item.value == decisionValue,
        orElse: () => XiangjiCalibrationResult.changeMethod,
      ),
      decisionReason: (json['decision_reason'] ?? '').toString(),
      nextStep: XiangjiDailyStep(
        id: 0,
        goalId: int.tryParse('${json['goal_id'] ?? 0}') ?? 0,
        goalVersionId: 0,
        actionText: (next['action_text'] ?? '').toString(),
        triggerContext: (next['trigger_context'] ?? '').toString(),
        minimumDone: (next['minimum_done'] ?? '').toString(),
        evidenceRule: (next['evidence_rule'] ?? '').toString(),
        controllabilityReason:
            (next['controllability_reason'] ?? '').toString(),
        smallerVariant: (next['smaller_variant'] ?? '').toString(),
        sourceSystemId: (next['source_system_id'] ?? '').toString(),
        status: (next['status'] ?? 'ready').toString(),
        createdAtMs: int.tryParse('${next['created_at_ms'] ?? 0}') ?? 0,
      ),
      theory: XiangjiTheoryApplication.fromJson(
        _objectMap(json['theory']),
      ),
      receipt: XiangjiGoalIntelligenceReceipt.fromJson(
        _objectMap(json['receipt']),
      ),
      createdAtMs: int.tryParse('${json['created_at_ms'] ?? 0}') ?? 0,
    );
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return <String, Object?>{};
  return value.map<String, Object?>(
    (key, item) => MapEntry(key.toString(), item),
  );
}

class XiangjiGoalCapability {
  const XiangjiGoalCapability({
    required this.id,
    required this.name,
    required this.purpose,
    required this.input,
    required this.steps,
    required this.output,
    required this.why,
    required this.knowledgeIds,
  });

  final String id;
  final String name;
  final String purpose;
  final String input;
  final List<String> steps;
  final String output;
  final String why;
  final List<String> knowledgeIds;
}

class XiangjiGoalAssistantAnswer {
  const XiangjiGoalAssistantAnswer({
    required this.text,
    required this.sourceLabels,
    required this.aiUsed,
    required this.modeLabel,
  });

  final String text;
  final List<String> sourceLabels;
  final bool aiUsed;
  final String modeLabel;
}

class XiangjiGoalIntelligenceService {
  XiangjiGoalIntelligenceService({
    XiangjiGoalMentorEngine? engine,
    XiangjiStrictTextGenerator? generator,
  })  : _engine = engine ?? XiangjiGoalMentorEngine(),
        _generator = generator ?? _localOnlyGenerate;

  final XiangjiGoalMentorEngine _engine;
  final XiangjiStrictTextGenerator _generator;

  static const List<XiangjiGoalCapability> capabilities =
      <XiangjiGoalCapability>[
    XiangjiGoalCapability(
      id: 'need_to_routes',
      name: '目标/问题转三条路径',
      purpose: '把一句模糊愿望转成三条可选择、可产出的现实路径。',
      input: '目标或问题；结果和阻碍可不填。',
      steps: <String>['写一句真实需要', '选择兴趣、方式和时间', '比较三条路径'],
      output: '一个成功信号、一项今日产出和三条知识路径。',
      why: '先让用户选择可承受的路径，再用现实反馈校准，不要求先学会理论。',
      knowledgeIds: <String>['locke_latham', 'dewey', 'positive_psychology'],
    ),
    XiangjiGoalCapability(
      id: 'today_step',
      name: '今天只做一步',
      purpose: '把目标压缩成此刻可开始、可停止的一项行动。',
      input: '当前目标和真实可用时间。',
      steps: <String>['确认触发点', '完成最低标准', '留下现实证据'],
      output: '文档、问题、请求、记录或其他可见痕迹。',
      why: '完成标准由用户控制，外部结果不作为今天的失败判据。',
      knowledgeIds: <String>['epictetus', 'locke_latham'],
    ),
    XiangjiGoalCapability(
      id: 'blocked_recovery',
      name: '卡住后换路',
      purpose: '区分步骤太大、条件不足、方法无效或目标变化。',
      input: '没做成时实际发生的事实。',
      steps: <String>['选择一种阻碍', '缩小/改法/暂停/重选', '生成下一步'],
      output: '一项适配现实条件的新行动。',
      why: '没行动不能自动解释为没有动力或意志薄弱。',
      knowledgeIds: <String>['carver_scheier', 'dewey'],
    ),
    XiangjiGoalCapability(
      id: 'mentor_trace',
      name: '思想如何推出行动',
      purpose: '解释思想家概念怎样改变当前判断和具体做法。',
      input: '当前方案或今日行动。',
      steps: <String>['查看概念', '查看本案例应用', '查看为什么推出这一步'],
      output: '可回定位来源和通俗的行动推导。',
      why: '理论不是标签；只有改变判断和行为时才进入产品。',
      knowledgeIds: <String>['mentor_goal_core_v21'],
    ),
    XiangjiGoalCapability(
      id: 'reality_review',
      name: '现实反馈与校准',
      purpose: '用行动结果决定继续、改法、缩小、暂停或重选。',
      input: '做成/部分完成/没开始/受阻，以及一条事实。',
      steps: <String>['记录事实', '确认成长证据', '选择下一轮'],
      output: '一条证据和一项下一轮决定。',
      why: '目标和方法都是可修订假设，现实结果高于自我评价。',
      knowledgeIds: <String>['carver_scheier', 'dewey'],
    ),
    XiangjiGoalCapability(
      id: 'mentor_choice',
      name: '查看或更换思想家',
      purpose: '比较思想家的核心问题，并让选择真正改变判断、行动和校准。',
      input: '可不选；已有偏好时选择一位思想家。',
      steps: <String>['查看核心问题', '比较现实路径', '确认或更换'],
      output: '当前目标采用的知识路径和选择历史。',
      why: '导师是方法视角，不是人格标签；用户始终可以改选。',
      knowledgeIds: <String>['mentor_goal_core_v21'],
    ),
    XiangjiGoalCapability(
      id: 'mentor_setting',
      name: '八步目标设定',
      purpose: '在需要深入时逐步核对价值、目标、方法、条件和行动。',
      input: '当前目标下对八个问题的原话回答。',
      steps: <String>['按顺序回答', '随时退出并保存', '完成后回到今日行动'],
      output: '一组仅保存在本机的目标设定回答。',
      why: '它是可选的深度工具，不阻挡第一次行动。',
      knowledgeIds: <String>['mentor_setting_v21'],
    ),
    XiangjiGoalCapability(
      id: 'reminder',
      name: '目标守护提醒',
      purpose: '在用户选择的时间让目标或今日一步重新出现。',
      input: '是否开启、提醒时间和安静时段。',
      steps: <String>['用户主动开启', '设置时间', '可随时暂停或关闭'],
      output: '每天最多一次、不统计断签的轻提醒。',
      why: '提醒用于降低遗忘成本，不用压力或惩罚控制用户。',
      knowledgeIds: <String>['goal_presence_policy'],
    ),
    XiangjiGoalCapability(
      id: 'book_library',
      name: '私人书库与严格问书',
      purpose: '只依据用户本轮选定书籍的真实命中片段回答。',
      input: '导入的书籍、选择的 1—3 本书和一个问题。',
      steps: <String>['本机解析', '选择允许范围', '查看回答和可回定位依据'],
      output: '带来源、内容类型和边界的书籍回答。',
      why: '防止 AI 用通用记忆冒充书中观点。',
      knowledgeIds: <String>['strict_grounding_policy'],
    ),
    XiangjiGoalCapability(
      id: 'privacy_data',
      name: '数据导出与清除',
      purpose: '让用户检查、带走或清除自己的目标、行动和书籍数据。',
      input: '导出、删除单本书或清除全部数据的明确选择。',
      steps: <String>['先查看范围', '确认操作', '核对删除/导出结果'],
      output: '本机 JSON 导出或明确的数据清除结果。',
      why: '用户对自己的数据和 AI 外发范围保持控制。',
      knowledgeIds: <String>['local_first_privacy'],
    ),
    XiangjiGoalCapability(
      id: 'deep_strategy',
      name: '深度问题与战略空间',
      purpose: '把复杂、长期或多约束问题交给独立的未来军师模块。',
      input: '只有当前目标导师闭环无法承载的复杂战略问题。',
      steps: <String>['先完成目标导师最小澄清', '明确需要深度推演', '进入独立模块'],
      output: '未来军师自己的问题、战役和现实验算链。',
      why: '目标导师保持简单；跨模块能力不混成一个复杂首页。',
      knowledgeIds: <String>['future_strategist_bridge'],
    ),
  ];

  Future<XiangjiGoalPlanBundle> generate({
    required String need,
    required String desiredOutcome,
    required String obstacle,
    required XiangjiGoalSupportProfile profile,
    required XiangjiKnowledgeCatalog catalog,
    required bool allowAi,
    String preferredMentorId = '',
  }) async {
    final cleanNeed = need.trim();
    if (cleanNeed.isEmpty) throw const FormatException('请先写下目标或问题');
    final safety = _engine.assessSafety(cleanNeed);
    if (safety.highRisk) throw StateError(safety.message);
    final localRoutes = _localRoutes(
      need: cleanNeed,
      desiredOutcome: desiredOutcome.trim(),
      obstacle: obstacle.trim(),
      profile: profile,
      catalog: catalog,
      preferredMentorId: preferredMentorId,
    );
    final knowledgeIds = localRoutes
        .expand((item) => item.applications.map((item) => item.evidenceId))
        .toSet()
        .toList(growable: false);
    final localSummary = _localSummary(cleanNeed, obstacle);
    final localQuestion = _blindSpot(obstacle);

    XiangjiGoalPlanBundle fallback({
      bool requested = false,
      String reason = '',
    }) {
      return XiangjiGoalPlanBundle(
        routes: localRoutes,
        receipt: XiangjiGoalIntelligenceReceipt(
          aiRequested: requested,
          aiUsed: false,
          provider: 'local',
          model: '本地知识规则',
          status: requested ? 'local_fallback' : 'local_selected',
          fallbackReason: reason,
          knowledgeIds: knowledgeIds,
          generatedAtMs: DateTime.now().millisecondsSinceEpoch,
          situationSummary: localSummary,
          blindSpotQuestion: localQuestion,
        ),
      );
    }

    if (!allowAi) return fallback();
    final payload = _promptPayload(
      need: cleanNeed,
      desiredOutcome: desiredOutcome,
      obstacle: obstacle,
      profile: profile,
      catalog: catalog,
      routes: localRoutes,
    );
    try {
      final generated = await _generator(
        systemPrompt: _planSystemPrompt,
        prompt: jsonEncode(payload),
      );
      if (generated.text.trim().isEmpty) {
        return fallback(
          requested: true,
          reason: '未检测到可用 AI 配置，本次由本地知识规则完成。',
        );
      }
      final decoded = _jsonObject(generated.text);
      final routes = _validatedAiRoutes(
        decoded: decoded,
        localRoutes: localRoutes,
        catalog: catalog,
      );
      if (routes == null) {
        return fallback(
          requested: true,
          reason: 'AI 方案缺少具体产出、完成信号或有效知识依据，本地规则已接管。',
        );
      }
      final summary = _text(decoded['situation_summary']);
      final question = _text(decoded['blind_spot_question']);
      if (summary.isEmpty || question.isEmpty || _forbidden(summary)) {
        return fallback(
          requested: true,
          reason: 'AI 分析未通过认识边界，本地规则已接管。',
        );
      }
      return XiangjiGoalPlanBundle(
        routes: routes,
        receipt: XiangjiGoalIntelligenceReceipt(
          aiRequested: true,
          aiUsed: true,
          provider: generated.provider,
          model: generated.modelLabel,
          status: 'ai_grounded',
          fallbackReason: '',
          knowledgeIds: routes
              .expand((item) => item.applications.map((item) => item.evidenceId))
              .toSet()
              .toList(growable: false),
          generatedAtMs: DateTime.now().millisecondsSinceEpoch,
          situationSummary: summary,
          blindSpotQuestion: question,
        ),
      );
    } catch (error) {
      return fallback(
        requested: true,
        reason: 'AI 暂时不可用，本地知识规则已接管：${_safeError(error)}',
      );
    }
  }

  Future<XiangjiGoalRoundReview> reviewRound({
    required XiangjiGoal goal,
    required XiangjiDailyStep step,
    required XiangjiCheckinResult result,
    required String realityFacts,
    required XiangjiGoalSupportProfile profile,
    required XiangjiGuidance guidance,
    required bool allowAi,
  }) async {
    final facts = realityFacts.trim();
    if (facts.length < 2) {
      throw const FormatException('请写一条真实发生的事实，不需要评价自己。');
    }
    final safety = _engine.assessSafety(facts);
    if (safety.highRisk) throw StateError(safety.message);
    if (guidance.sources.isEmpty) {
      throw StateError('当前知识依据不足，已停止生成下一步。');
    }
    final local = _localRoundReview(
      goal: goal,
      step: step,
      result: result,
      realityFacts: facts,
      profile: profile,
      guidance: guidance,
      aiRequested: allowAi,
    );
    if (!allowAi) return local;
    final payload = _redactJson(<String, Object?>{
      'goal': goal.originalText,
      'previous_action': step.actionText,
      'minimum_done': step.minimumDone,
      'result': result.value,
      'reality_facts': facts,
      'preference': profile.toJson(),
      'local_review': <String, Object?>{
        'reality_comparison': local.realityComparison,
        'learning': local.learning,
        'decision': local.decision.value,
        'decision_reason': local.decisionReason,
        'next_action': local.nextStep.actionText,
        'next_minimum_done': local.nextStep.minimumDone,
        'next_evidence_rule': local.nextStep.evidenceRule,
      },
      'allowed_theory': <String, Object?>{
        'evidence_id': local.theory.evidenceId,
        'mentor_name': local.theory.mentorName,
        'concept': local.theory.concept,
        'locator': local.theory.locator,
        'boundary': local.theory.boundary,
      },
    }) as Map<String, Object?>;
    try {
      final generated = await _generator(
        systemPrompt: _roundReviewSystemPrompt,
        prompt: jsonEncode(payload),
      );
      if (generated.text.trim().isEmpty) {
        return _roundReviewWithReceipt(
          local,
          reason: '未检测到可用 AI 配置，本轮由本地知识规则完成。',
        );
      }
      final decoded = _jsonObject(generated.text);
      final evidenceId = _text(decoded['evidence_id']);
      final comparison = _text(decoded['reality_comparison']);
      final learning = _text(decoded['learning']);
      final decisionReason = _text(decoded['decision_reason']);
      final nextAction = _text(decoded['next_action']);
      final minimumDone = _text(decoded['next_minimum_done']);
      final evidenceRule = _text(decoded['next_evidence_rule']);
      final caseApplication = _text(decoded['case_application']);
      final whyThisAction = _text(decoded['why_this_action']);
      final required = <String>[
        comparison,
        learning,
        decisionReason,
        nextAction,
        minimumDone,
        evidenceRule,
        caseApplication,
        whyThisAction,
      ];
      if (evidenceId != local.theory.evidenceId ||
          required.any((value) => value.length < 4 || _forbidden(value)) ||
          !RegExp(r'\d').hasMatch(nextAction)) {
        return _roundReviewWithReceipt(
          local,
          reason: 'AI 复盘缺少现实事实、可执行下一步或有效知识依据，本地规则已接管。',
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      return XiangjiGoalRoundReview(
        goalId: goal.id,
        stepId: step.id,
        result: result,
        realityFacts: facts,
        realityComparison: comparison,
        learning: learning,
        decision: local.decision,
        decisionReason: decisionReason,
        nextStep: XiangjiDailyStep(
          id: 0,
          goalId: goal.id,
          goalVersionId: goal.versionId,
          actionText: nextAction,
          triggerContext: '选择一个真实可用的 ${profile.minutes} 分钟窗口；到点就停。',
          minimumDone: minimumDone,
          evidenceRule: evidenceRule,
          controllabilityReason: local.nextStep.controllabilityReason,
          smallerVariant: local.nextStep.smallerVariant,
          sourceSystemId: guidance.systemId,
          status: 'ready',
          createdAtMs: now,
        ),
        theory: XiangjiTheoryApplication(
          evidenceId: local.theory.evidenceId,
          mentorName: local.theory.mentorName,
          concept: local.theory.concept,
          locator: local.theory.locator,
          caseApplication: caseApplication,
          whyThisAction: whyThisAction,
          boundary: local.theory.boundary,
        ),
        receipt: XiangjiGoalIntelligenceReceipt(
          aiRequested: true,
          aiUsed: true,
          provider: generated.provider,
          model: generated.modelLabel,
          status: 'ai_round_review',
          fallbackReason: '',
          knowledgeIds: <String>[local.theory.evidenceId],
          generatedAtMs: now,
          situationSummary: comparison,
          blindSpotQuestion: decisionReason,
        ),
        createdAtMs: now,
      );
    } catch (error) {
      return _roundReviewWithReceipt(
        local,
        reason: 'AI 暂时不可用，本轮由本地知识规则完成：${_safeError(error)}',
      );
    }
  }

  Future<XiangjiGoalAssistantAnswer> answer({
    required String question,
    required XiangjiKnowledgeCatalog catalog,
    XiangjiGoal? goal,
    XiangjiDailyStep? step,
    XiangjiGuidance? guidance,
    bool allowAi = false,
  }) async {
    final query = question.trim();
    if (query.isEmpty) {
      return const XiangjiGoalAssistantAnswer(
        text: '请直接问：我现在该做什么、这个功能怎么用、为什么这样做，或者我卡住了怎么办。',
        sourceLabels: <String>['目标导师功能目录'],
        aiUsed: false,
        modeLabel: '本地操作助手',
      );
    }
    final safety = _engine.assessSafety(query);
    if (safety.highRisk) {
      return XiangjiGoalAssistantAnswer(
        text: safety.message,
        sourceLabels: const <String>['安全边界'],
        aiUsed: false,
        modeLabel: '安全转介',
      );
    }
    final local = _localAssistantAnswer(query, goal: goal, step: step, guidance: guidance);
    if (!allowAi) return local;
    final sourceIds = guidance?.sources.map((item) => item.evidenceId).toSet() ?? <String>{};
    final payload = <String, Object?>{
      'question': _redact(query),
      'current_goal': goal == null ? '' : _redact(goal.originalText),
      'current_step': step?.actionText ?? '',
      'local_answer': local.text,
      'capabilities': capabilities
          .map((item) => <String, Object?>{
                'id': item.id,
                'name': item.name,
                'purpose': item.purpose,
                'steps': item.steps,
                'output': item.output,
                'why': item.why,
              })
          .toList(growable: false),
      'sources': guidance?.sources
              .map((item) => <String, Object?>{
                    'id': item.evidenceId,
                    'mentor': guidance.mentorName,
                    'locator': item.locator,
                    'summary': item.summary,
                    'boundary': item.boundary,
                  })
              .toList(growable: false) ??
          const <Object?>[],
    };
    try {
      final generated = await _generator(
        systemPrompt: _assistantSystemPrompt,
        prompt: jsonEncode(payload),
      );
      if (generated.text.trim().isEmpty) return local;
      final decoded = _jsonObject(generated.text);
      final text = _text(decoded['answer']);
      final rawIds = decoded['source_ids'];
      final ids = rawIds is List
          ? rawIds.map((item) => item.toString()).toSet()
          : <String>{};
      if (text.isEmpty || _forbidden(text) || !sourceIds.containsAll(ids)) return local;
      return XiangjiGoalAssistantAnswer(
        text: text,
        sourceLabels: ids.isEmpty
            ? const <String>['目标导师功能目录']
            : guidance!.sources
                .where((item) => ids.contains(item.evidenceId))
                .map((item) => '${guidance.mentorName} · ${item.locator}')
                .toList(growable: false),
        aiUsed: true,
        modeLabel: '${generated.modelLabel} · 知识约束回答',
      );
    } catch (_) {
      return XiangjiGoalAssistantAnswer(
        text: local.text,
        sourceLabels: local.sourceLabels,
        aiUsed: false,
        modeLabel: 'AI 不可用 · 本地助手已接管',
      );
    }
  }

  XiangjiGoalRoundReview _localRoundReview({
    required XiangjiGoal goal,
    required XiangjiDailyStep step,
    required XiangjiCheckinResult result,
    required String realityFacts,
    required XiangjiGoalSupportProfile profile,
    required XiangjiGuidance guidance,
    required bool aiRequested,
  }) {
    final decision = switch (result) {
      XiangjiCheckinResult.completed => XiangjiCalibrationResult.continueGoal,
      XiangjiCheckinResult.partiallyCompleted =>
        XiangjiCalibrationResult.reduceScope,
      XiangjiCheckinResult.notStarted => XiangjiCalibrationResult.reduceScope,
      XiangjiCheckinResult.blocked => XiangjiCalibrationResult.changeMethod,
      XiangjiCheckinResult.noLongerRelevant =>
        XiangjiCalibrationResult.changeMethod,
    };
    final comparison = switch (result) {
      XiangjiCheckinResult.completed =>
        '现实已经出现了最低完成信号。现在要保留有效条件，不把一次完成夸大成永久能力。',
      XiangjiCheckinResult.partiallyCompleted =>
        '行动已经产生部分现实痕迹，但尚未达到最低完成；有效部分和剩余负担需要分开。',
      XiangjiCheckinResult.notStarted =>
        '本轮没有进入行动，说明触发条件或行动大小与现实容量不匹配，不能据此评价人格。',
      XiangjiCheckinResult.blocked =>
        '行动被现实条件阻断；需要先改变条件或方法，而不是重复同一要求。',
      XiangjiCheckinResult.noLongerRelevant =>
        '现实已经使当前步骤失去作用；保留目标判断权，停止重复无效动作。',
    };
    final learning = switch (result) {
      XiangjiCheckinResult.completed => '本轮可确认的经验：小而可停止的行动能够产生真实反馈。',
      XiangjiCheckinResult.partiallyCompleted => '本轮可确认的经验：方向仍有响应，但步骤需要缩到现实能承受的范围。',
      XiangjiCheckinResult.notStarted => '本轮可确认的经验：先修正启动条件，动力不能替代清楚的触发点。',
      XiangjiCheckinResult.blocked => '本轮可确认的经验：阻碍是一条待处理的条件信息，不是失败证明。',
      XiangjiCheckinResult.noLongerRelevant => '本轮可确认的经验：方法是可替换假设，不必为沉没成本继续。',
    };
    final decisionReason = switch (decision) {
      XiangjiCalibrationResult.continueGoal => '方向与方法已经得到一次现实支持，继续但只增加一个难度层级。',
      XiangjiCalibrationResult.reduceScope => '方向暂不否定，先降低步骤与启动成本，再观察下一轮事实。',
      XiangjiCalibrationResult.changeMethod => '目标暂时保留，现实事实要求更换条件或推进方法。',
      XiangjiCalibrationResult.pause => '现实容量暂不支持继续推进，暂停比强迫更符合当前事实。',
      XiangjiCalibrationResult.reselect => '具体目标已经不再服务原有价值，需要重新选择。',
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    final source = guidance.sources.first;
    final nextStep = XiangjiDailyStep(
      id: 0,
      goalId: goal.id,
      goalVersionId: goal.versionId,
      actionText: _reviewNextAction(
        goal: goal,
        step: step,
        result: result,
        profile: profile,
        realityFacts: realityFacts,
      ),
      triggerContext: '选择一个真实可用的 ${profile.minutes} 分钟窗口；到点就停。',
      minimumDone: _reviewMinimumDone(result, profile.interest),
      evidenceRule: _reviewEvidenceRule(profile.interest),
      controllabilityReason: '下一步只要求由你控制的动作与现实痕迹；外部回应只作为新事实，不作为人格评分。',
      smallerVariant: '如果仍难开始，只用 2 分钟准备材料、写第一句或消除一个启动条件。',
      sourceSystemId: guidance.systemId,
      status: 'ready',
      createdAtMs: now,
    );
    final theory = XiangjiTheoryApplication(
      evidenceId: source.evidenceId,
      mentorName: guidance.mentorName,
      concept: guidance.mechanismLabel,
      locator: '${source.bookTitle} · ${source.locator}',
      caseApplication: '用“${_short(realityFacts)}”修正对“${_short(goal.originalText)}”的判断；事实优先于抽象自我评价。',
      whyThisAction: '$decisionReason 因此下一轮只执行一项可停止、可留下证据的行动。',
      boundary: source.boundary,
    );
    return XiangjiGoalRoundReview(
      goalId: goal.id,
      stepId: step.id,
      result: result,
      realityFacts: realityFacts,
      realityComparison: comparison,
      learning: learning,
      decision: decision,
      decisionReason: decisionReason,
      nextStep: nextStep,
      theory: theory,
      receipt: XiangjiGoalIntelligenceReceipt(
        aiRequested: aiRequested,
        aiUsed: false,
        provider: 'local',
        model: '本地知识规则',
        status: aiRequested ? 'local_fallback' : 'local_round_review',
        fallbackReason: '',
        knowledgeIds: <String>[source.evidenceId],
        generatedAtMs: now,
        situationSummary: comparison,
        blindSpotQuestion: decisionReason,
      ),
      createdAtMs: now,
    );
  }

  XiangjiGoalRoundReview _roundReviewWithReceipt(
    XiangjiGoalRoundReview local, {
    required String reason,
  }) =>
      XiangjiGoalRoundReview(
        goalId: local.goalId,
        stepId: local.stepId,
        result: local.result,
        realityFacts: local.realityFacts,
        realityComparison: local.realityComparison,
        learning: local.learning,
        decision: local.decision,
        decisionReason: local.decisionReason,
        nextStep: local.nextStep,
        theory: local.theory,
        receipt: XiangjiGoalIntelligenceReceipt(
          aiRequested: true,
          aiUsed: false,
          provider: 'local',
          model: '本地知识规则',
          status: 'local_fallback',
          fallbackReason: reason,
          knowledgeIds: local.receipt.knowledgeIds,
          generatedAtMs: DateTime.now().millisecondsSinceEpoch,
          situationSummary: local.realityComparison,
          blindSpotQuestion: local.decisionReason,
        ),
        createdAtMs: local.createdAtMs,
      );

  static String _reviewNextAction({
    required XiangjiGoal goal,
    required XiangjiDailyStep step,
    required XiangjiCheckinResult result,
    required XiangjiGoalSupportProfile profile,
    required String realityFacts,
  }) {
    if (result == XiangjiCheckinResult.notStarted) {
      return '只用 2 分钟执行更小版本：${step.smallerVariant}';
    }
    if (result == XiangjiCheckinResult.blocked ||
        result == XiangjiCheckinResult.noLongerRelevant) {
      return '用 ${profile.minutes} 分钟处理“${_short(realityFacts, 20)}”暴露出的一个条件，再为“${_short(goal.originalText)}”完成一个可见动作。';
    }
    if (result == XiangjiCheckinResult.partiallyCompleted) {
      return '用 ${profile.minutes} 分钟保留本轮有效部分，只完成“${_short(step.minimumDone, 22)}”中尚未完成的一小段。';
    }
    switch (profile.interest) {
      case XiangjiGoalInterest.create:
        return '用 ${profile.minutes} 分钟把现有成果扩展一层：补一个段落、例子或待回答问题；到点就停。';
      case XiangjiGoalInterest.learn:
        return '用 ${profile.minutes} 分钟用自己的话解释一个仍模糊的点，并写下一个可验证问题。';
      case XiangjiGoalInterest.career:
        return '用 ${profile.minutes} 分钟把现有成果交给一个真实对象，或发出一个只含一个问题的具体询问。';
      case XiangjiGoalInterest.connect:
        return '用 ${profile.minutes} 分钟根据本轮回应修改一条具体、可拒绝且有边界的请求。';
      case XiangjiGoalInterest.wellbeing:
        return '用 ${profile.minutes} 分钟重复本轮有效的恢复动作，并记录前后一个可观察变化。';
      case XiangjiGoalInterest.explore:
        return '用 ${profile.minutes} 分钟补充一个真实选项、一条支持事实和一条限制事实。';
    }
  }

  static String _reviewMinimumDone(
    XiangjiCheckinResult result,
    XiangjiGoalInterest interest,
  ) {
    if (result == XiangjiCheckinResult.notStarted) return '完成 2 分钟更小版本，并留下第一条痕迹。';
    if (result == XiangjiCheckinResult.blocked ||
        result == XiangjiCheckinResult.noLongerRelevant) {
      return '处理一个现实条件，并留下一个新的可执行入口。';
    }
    return switch (interest) {
      XiangjiGoalInterest.create => '新增一个可继续修改的内容单元。',
      XiangjiGoalInterest.learn => '留下三句解释和一个问题。',
      XiangjiGoalInterest.career => '形成一个可发送成果或发出一个具体询问。',
      XiangjiGoalInterest.connect => '形成一句可讨论、可拒绝的具体请求。',
      XiangjiGoalInterest.wellbeing => '完成一次恢复动作并记录前后变化。',
      XiangjiGoalInterest.explore => '新增一个选项、一条支持和一条限制。',
    };
  }

  static String _reviewEvidenceRule(XiangjiGoalInterest interest) =>
      '保留${_output(interest, 0)}，或写下一条阻止它发生的现实条件。';

  List<XiangjiGoalPlanRoute> _localRoutes({
    required String need,
    required String desiredOutcome,
    required String obstacle,
    required XiangjiGoalSupportProfile profile,
    required XiangjiKnowledgeCatalog catalog,
    required String preferredMentorId,
  }) {
    final inferred = _engine.buildDraft(need, catalog).guidance.systemId;
    final candidates = <String>[
      if (preferredMentorId.isNotEmpty) preferredMentorId,
      inferred,
      ..._mentorCandidates(profile.interest),
      'dewey',
      'locke_latham',
      'positive_psychology',
    ].where((id) => catalog.system(id) != null).toSet().take(3).toList();
    if (candidates.length < 3) throw StateError('目标导师知识库不足三条可用路径');
    return List<XiangjiGoalPlanRoute>.generate(3, (index) {
      final mentor = catalog.system(candidates[index])!;
      final base = _engine.buildDraft(
        need,
        catalog,
        selectedMentorId: mentor.id,
      );
      final baseAction = _actionFor(
        need: need,
        obstacle: obstacle,
        interest: profile.interest,
        minutes: profile.minutes,
        index: index,
        mentor: mentor,
      );
      final action = _applyTone(baseAction, profile.tone);
      final success = _successSignal(profile.interest, index);
      final output = _output(profile.interest, index);
      final step = XiangjiDailyStep(
        id: 0,
        goalId: 0,
        goalVersionId: 0,
        actionText: action,
        triggerContext: '选择今天一个真实可用的 ${profile.minutes} 分钟窗口；到点就停。',
        minimumDone: success,
        evidenceRule: '保留$output，或记录阻止它发生的一条现实条件。',
        controllabilityReason: '只要求产生由你控制的现实痕迹，不要求外部结果，也不把未完成解释成意志薄弱。',
        smallerVariant: '只用 2 分钟准备材料、写下第一句或明确第一个动作。',
        sourceSystemId: mentor.id,
        status: 'ready',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final source = base.guidance.sources.first;
      final application = XiangjiTheoryApplication(
        evidenceId: source.evidenceId,
        mentorName: mentor.displayName,
        concept: base.guidance.mechanismLabel,
        locator: '${source.bookTitle} · ${source.locator}',
        caseApplication: index == 0
            ? '把“$need”先变成一个今天可观察的产出，而不是继续停留在愿望层。'
            : index == 1
                ? '把“${obstacle.isEmpty ? '当前最不确定的地方' : obstacle}”作为待检验条件，只澄清会改变下一步的一层。'
                : '把“$need”放入七天的多次选择中，用做成、受阻和继续意愿共同校准。',
        whyThisAction: index == 0
            ? '现实产出能提供新证据，并减少抽象自我评价。'
            : index == 1
                ? '看清一个关键阻碍后立刻行动，避免无限分析。'
                : '多次现实反馈比一次表态更能区分目标、方法与条件。',
        boundary: source.boundary,
      );
      final routeDraft = base.copyWith(
        whyText: application.caseApplication,
        successDefinition: desiredOutcome.isEmpty ? success : desiredOutcome,
        scopeText: '先用未来 7 天验证这条路径；今天只完成 ${profile.minutes} 分钟。',
        step: step,
      );
      return XiangjiGoalPlanRoute(
        id: const <String>['direct_output', 'clarify_then_act', 'seven_day_loop'][index],
        title: const <String>['先做出一个成果', '先看清再行动', '用七天让现实回答'][index],
        promise: const <String>['今天就有可见产出', '一问一行动，不无限分析', '做成和没做成都能更新下一步'][index],
        mentorId: mentor.id,
        mentorName: mentor.displayName,
        understanding: base.guidance.coreJudgment,
        blindSpot: index == 1 ? _blindSpot(obstacle) : base.guidance.selectionReason,
        output: output,
        whyItWorks: application.whyThisAction,
        successSignal: success,
        draft: routeDraft,
        applications: <XiangjiTheoryApplication>[application],
      );
    });
  }

  List<XiangjiGoalPlanRoute>? _validatedAiRoutes({
    required Map<String, dynamic> decoded,
    required List<XiangjiGoalPlanRoute> localRoutes,
    required XiangjiKnowledgeCatalog catalog,
  }) {
    final raw = decoded['routes'];
    if (raw is! List || raw.length != 3) return null;
    final localById = <String, XiangjiGoalPlanRoute>{for (final item in localRoutes) item.id: item};
    final result = <XiangjiGoalPlanRoute>[];
    for (final item in raw) {
      if (item is! Map) return null;
      final map = Map<String, dynamic>.from(item);
      final id = _text(map['id']);
      final local = localById[id];
      if (local == null || result.any((route) => route.id == id)) return null;
      final mentorId = _text(map['mentor_id']);
      if (mentorId != local.mentorId || catalog.system(mentorId) == null) return null;
      final action = _text(map['action']);
      final success = _text(map['success_signal']);
      final output = _text(map['output']);
      final why = _text(map['why_it_works']);
      final understanding = _text(map['understanding']);
      final blindSpot = _text(map['blind_spot']);
      if (<String>[action, success, output, why, understanding, blindSpot]
              .any((value) => value.length < 4 || _forbidden(value)) ||
          !RegExp(r'\d').hasMatch(action)) return null;
      final rawApplications = map['theory_applications'];
      if (rawApplications is! List || rawApplications.isEmpty) return null;
      final allowed = <String, XiangjiTheoryApplication>{
        for (final app in local.applications) app.evidenceId: app,
      };
      final applications = <XiangjiTheoryApplication>[];
      for (final rawApplication in rawApplications) {
        if (rawApplication is! Map) return null;
        final appMap = Map<String, dynamic>.from(rawApplication);
        final evidenceId = _text(appMap['evidence_id']);
        final base = allowed[evidenceId];
        final caseApplication = _text(appMap['case_application']);
        final whyAction = _text(appMap['why_this_action']);
        if (base == null || caseApplication.length < 6 || whyAction.length < 6) return null;
        applications.add(
          XiangjiTheoryApplication(
            evidenceId: base.evidenceId,
            mentorName: base.mentorName,
            concept: base.concept,
            locator: base.locator,
            caseApplication: caseApplication,
            whyThisAction: whyAction,
            boundary: base.boundary,
          ),
        );
      }
      final step = XiangjiDailyStep(
        id: 0,
        goalId: 0,
        goalVersionId: 0,
        actionText: action,
        triggerContext: local.draft.step.triggerContext,
        minimumDone: success,
        evidenceRule: '保留$output，或记录一条现实阻碍。',
        controllabilityReason: local.draft.step.controllabilityReason,
        smallerVariant: local.draft.step.smallerVariant,
        sourceSystemId: mentorId,
        status: 'ready',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      result.add(
        XiangjiGoalPlanRoute(
          id: id,
          title: _text(map['title']).isEmpty ? local.title : _text(map['title']),
          promise: local.promise,
          mentorId: mentorId,
          mentorName: local.mentorName,
          understanding: understanding,
          blindSpot: blindSpot,
          output: output,
          whyItWorks: why,
          successSignal: success,
          draft: local.draft.copyWith(
            whyText: understanding,
            successDefinition: success,
            step: step,
          ),
          applications: applications,
        ),
      );
    }
    return result;
  }

  Map<String, Object?> _promptPayload({
    required String need,
    required String desiredOutcome,
    required String obstacle,
    required XiangjiGoalSupportProfile profile,
    required XiangjiKnowledgeCatalog catalog,
    required List<XiangjiGoalPlanRoute> routes,
  }) {
    final payload = <String, Object?>{
      'user': <String, Object?>{
        'need': need,
        'desired_outcome': desiredOutcome,
        'obstacle': obstacle,
        'interest': profile.interest.label,
        'support_tone': profile.tone.label,
        'minutes': profile.minutes,
      },
      'candidate_routes': routes.map((route) {
        final system = catalog.system(route.mentorId)!;
        return <String, Object?>{
          'id': route.id,
          'mentor_id': route.mentorId,
          'mentor_name': route.mentorName,
          'knowledge_view': system.knowledgeView,
          'decision_cue': system.decisionCue,
          'action': route.draft.step.actionText,
          'success_signal': route.successSignal,
          'output': route.output,
          'allowed_evidence': route.applications
              .map((item) => <String, Object?>{
                    'evidence_id': item.evidenceId,
                    'concept': item.concept,
                    'locator': item.locator,
                    'boundary': item.boundary,
                  })
              .toList(growable: false),
        };
      }).toList(growable: false),
    };
    return _redactJson(payload) as Map<String, Object?>;
  }

  XiangjiGoalAssistantAnswer _localAssistantAnswer(
    String query, {
    XiangjiGoal? goal,
    XiangjiDailyStep? step,
    XiangjiGuidance? guidance,
  }) {
    if (_contains(query, <String>['现在', '下一步', '今天做', '先做什么'])) {
      return XiangjiGoalAssistantAnswer(
        text: step == null
            ? '先在“今天”页写一句目标或问题，选择兴趣、引导方式和真实可用时间，再比较三条方案。'
            : '现在只做这一件事：${step.actionText}\n做到这里就算完成：${step.minimumDone}\n留下：${step.evidenceRule}',
        sourceLabels: <String>[guidance?.mentorName ?? '目标导师功能目录'],
        aiUsed: false,
        modeLabel: '本地操作助手',
      );
    }
    if (_contains(query, <String>['卡住', '没做', '做不到', '拖延', '太难'])) {
      return XiangjiGoalAssistantAnswer(
        text: step == null
            ? '先把目标写下来；结果和阻碍都可以留空。系统会给出一条 2 分钟版本。'
            : '先不要补做，也不要评价自己。点击“再缩小一点”；如果是时间、资源或目标变化，记录一条事实后选择改法、暂停或重选。更小版本：${step.smallerVariant}',
        sourceLabels: const <String>['卡住后换路', '现实反馈与校准'],
        aiUsed: false,
        modeLabel: '本地操作助手',
      );
    }
    if (_contains(query, <String>['理论', '思想', '为什么', '依据', '导师'])) {
      return XiangjiGoalAssistantAnswer(
        text: guidance == null
            ? '每条方案都必须展示“思想家/概念 → 怎样应用到你的目标 → 为什么推出这一步 → 理论边界”。先生成方案即可看到。'
            : '${guidance.mentorName}当前用于：${guidance.mechanismLabel}。\n怎样应用：${guidance.actionDerivation}\n边界：${guidance.boundaryNote}',
        sourceLabels: guidance?.sources
                .map((item) => '${guidance.mentorName} · ${item.locator}')
                .toList(growable: false) ??
            const <String>['目标导师知识路径'],
        aiUsed: false,
        modeLabel: '本地知识助手',
      );
    }
    final capability = _capabilityForQuery(query);
    return XiangjiGoalAssistantAnswer(
      text: '${capability.name}是用来${capability.purpose}\n填写：${capability.input}\n怎么做：${capability.steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('；')}。\n你会得到：${capability.output}\n为什么：${capability.why}',
      sourceLabels: capability.knowledgeIds,
      aiUsed: false,
      modeLabel: '本地功能说明',
    );
  }

  static XiangjiGoalCapability _capabilityForQuery(String query) {
    final routes = <List<String>, String>{
      <String>['三条', '方案', '路径怎么选']: 'need_to_routes',
      <String>['今天一步', '今日行动']: 'today_step',
      <String>['反馈', '复盘', '校准']: 'reality_review',
      <String>['换导师', '选导师', '思想家']: 'mentor_choice',
      <String>['八步', '目标设定']: 'mentor_setting',
      <String>['提醒', '通知']: 'reminder',
      <String>['书库', '问书', '导入书']: 'book_library',
      <String>['导出', '清除数据', '隐私']: 'privacy_data',
      <String>['未来军师', '战略空间']: 'deep_strategy',
    };
    for (final entry in routes.entries) {
      if (entry.key.any(query.contains)) {
        return capabilities.firstWhere((item) => item.id == entry.value);
      }
    }
    return capabilities.first;
  }

  static List<String> _mentorCandidates(XiangjiGoalInterest interest) {
    switch (interest) {
      case XiangjiGoalInterest.create:
        return const <String>['dewey', 'locke_latham', 'nietzsche'];
      case XiangjiGoalInterest.learn:
        return const <String>['locke_latham', 'dewey', 'positive_psychology'];
      case XiangjiGoalInterest.career:
        return const <String>['aristotle', 'frankl', 'epictetus'];
      case XiangjiGoalInterest.connect:
        return const <String>['adler', 'girard', 'epictetus'];
      case XiangjiGoalInterest.wellbeing:
        return const <String>['positive_psychology', 'epictetus', 'frankl'];
      case XiangjiGoalInterest.explore:
        return const <String>['positive_psychology', 'dewey', 'frankl'];
    }
  }

  static String _actionFor({
    required String need,
    required String obstacle,
    required XiangjiGoalInterest interest,
    required int minutes,
    required int index,
    required XiangjiKnowledgeSystem mentor,
  }) {
    final obstacleText = obstacle.isEmpty ? '当前最不确定的地方' : obstacle;
    if (index == 1) {
      return '用 $minutes 分钟回答“${mentor.profile?.centralQuestion ?? mentor.decisionCue}”，再把答案转成一个可以立刻执行的动作；只做第一步。';
    }
    if (index == 2) {
      return '未来七天任选至少三天，每次用 $minutes 分钟推进“${_short(need)}”；每次记录做成了什么，或哪条现实条件阻止了行动。';
    }
    switch (interest) {
      case XiangjiGoalInterest.create:
        return '打开与“${_short(need)}”有关的文件，用 $minutes 分钟写一个标题和三条要点；到点就停。';
      case XiangjiGoalInterest.learn:
        return '选“${_short(need)}”中的一个概念，用 $minutes 分钟写三句自己的解释和一个仍不懂的问题。';
      case XiangjiGoalInterest.career:
        return '围绕“${_short(need)}”，用 $minutes 分钟完成一个可发送的最小成果，或向一位真实对象发出一个具体询问。';
      case XiangjiGoalInterest.connect:
        return '用 $minutes 分钟写下一句可被拒绝的真实请求；先检查边界，再选择是否发送。';
      case XiangjiGoalInterest.wellbeing:
        return '承认“$obstacleText”是现实条件，用 $minutes 分钟完成一个可停止的恢复动作，并记录前后最明显的一项变化。';
      case XiangjiGoalInterest.explore:
        return '用 $minutes 分钟为“${_short(need)}”找一个真实选项，写下一条支持事实和一条限制事实。';
    }
  }

  static String _applyTone(String action, XiangjiSupportTone tone) {
    switch (tone) {
      case XiangjiSupportTone.gentle:
        return '只做最低版本：$action';
      case XiangjiSupportTone.practical:
        return action;
      case XiangjiSupportTone.curious:
        return '把它当成一次验证：$action';
    }
  }

  static String _successSignal(XiangjiGoalInterest interest, int index) {
    if (index == 1) return '得到一句更清楚的判断，并完成由它推出的第一个现实动作。';
    if (index == 2) return '形成至少三次不同日期的行动或阻碍记录。';
    switch (interest) {
      case XiangjiGoalInterest.create:
        return '文件里出现一个标题和三条可继续修改的要点。';
      case XiangjiGoalInterest.learn:
        return '留下三句自己的解释和一个具体问题。';
      case XiangjiGoalInterest.career:
        return '形成一个可发送成果，或发出一个具体询问。';
      case XiangjiGoalInterest.connect:
        return '形成一句尊重双方边界、可以被拒绝的请求。';
      case XiangjiGoalInterest.wellbeing:
        return '完成一次恢复动作并记录前后变化。';
      case XiangjiGoalInterest.explore:
        return '得到一个真实选项、一条支持事实和一条限制。';
    }
  }

  static String _output(XiangjiGoalInterest interest, int index) {
    if (index == 1) return '一条盲点判断 + 一个现实动作痕迹';
    if (index == 2) return '七天行动/阻碍记录 + 下一轮决定';
    switch (interest) {
      case XiangjiGoalInterest.create:
        return '可继续编辑的草稿骨架';
      case XiangjiGoalInterest.learn:
        return '概念解释卡与待解决问题';
      case XiangjiGoalInterest.career:
        return '可发送成果或真实回复入口';
      case XiangjiGoalInterest.connect:
        return '一条有边界的真实表达';
      case XiangjiGoalInterest.wellbeing:
        return '恢复记录与现实容量线索';
      case XiangjiGoalInterest.explore:
        return '真实选项比较记录';
    }
  }

  static String _localSummary(String need, String obstacle) => obstacle.trim().isEmpty
      ? '已把“${_short(need)}”当作待验证目标；目前缺少的不是更多概念，而是一项现实产出和反馈。'
      : '当前已知目标是“${_short(need)}”，已知阻碍是“${_short(obstacle)}”；阻碍先作为条件，不解释成人格缺陷。';

  static String _blindSpot(String obstacle) => obstacle.trim().isEmpty
      ? '真正阻止你开始的，是步骤不清、时间精力、评价压力，还是目标本身已经变化？'
      : '如果“${_short(obstacle)}”暂时消失，你最先会做哪一个具体动作？';

  static bool _contains(String value, List<String> words) => words.any(value.contains);

  static bool _forbidden(String value) => <String>[
        '你的本质是',
        '真正的你就是',
        '唯一真实目标',
        '童年创伤导致',
        '必须坚持',
        '不够自律',
        '离不开向己',
      ].any(value.contains);

  static Map<String, dynamic> _jsonObject(String raw) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) throw const FormatException('AI 未返回 JSON 对象');
    final decoded = jsonDecode(cleaned.substring(start, end + 1));
    if (decoded is! Map) throw const FormatException('AI JSON 结构无效');
    return Map<String, dynamic>.from(decoded);
  }

  static String _redact(String value) => value
      .replaceAll(
        RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
        '[邮箱已隐藏]',
      )
      .replaceAll(RegExp(r'\b1[3-9]\d{9}\b'), '[手机号已隐藏]')
      .replaceAll(RegExp(r'\b\d{17}[0-9Xx]\b'), '[证件号已隐藏]');

  static dynamic _redactJson(dynamic value) {
    if (value is String) return _redact(value);
    if (value is List) return value.map(_redactJson).toList(growable: false);
    if (value is Map) {
      return value.map<String, Object?>(
        (key, item) => MapEntry(key.toString(), _redactJson(item)),
      );
    }
    return value;
  }

  static String _text(Object? value) => (value ?? '').toString().trim();

  static String _short(String value, [int max = 28]) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    final runes = normalized.runes.toList(growable: false);
    return runes.length <= max
        ? normalized
        : '${String.fromCharCodes(runes.take(max))}…';
  }

  static String _safeError(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 70 ? text : '${text.substring(0, 70)}…';
  }

  static Future<XiangjiGeneratedText> _localOnlyGenerate({
    required String systemPrompt,
    required String prompt,
    String? forcedProvider,
  }) async => const XiangjiGeneratedText(
        text: '',
        provider: 'local',
        modelLabel: '本地知识规则',
      );

  static const String _planSystemPrompt = '''
你是“向己·智能目标导师”的知识到行动规划器。只输出 JSON。
只可使用 candidate_routes 中给定的导师、证据和边界；不得用模型记忆发明思想家、概念或引文。
必须原样保留 direct_output、clarify_then_act、seven_day_loop 三个 id 和各自 mentor_id。
每条路径必须针对用户当前目标，给出含明确分钟数的行动、可观察完成信号、现实产出、通俗理解、盲点和为什么有效。
theory_applications 只能使用该路径 allowed_evidence 的 evidence_id，并解释概念怎样应用到本案例、为什么推出这一步。
不得诊断、宣布用户本质或唯一真实目标；不得把未行动解释为意志薄弱。
不得用羞耻、威胁、敌人刺激、损失恐惧、打卡惩罚或制造依赖来促进行动。
输出结构：
{"situation_summary":"","blind_spot_question":"","routes":[{"id":"","mentor_id":"","title":"","understanding":"","blind_spot":"","action":"","success_signal":"","output":"","why_it_works":"","theory_applications":[{"evidence_id":"","case_application":"","why_this_action":""}]}]}
''';

  static const String _roundReviewSystemPrompt = '''
你是“向己·智能目标导师”的现实复盘器。只输出 JSON。
只能使用输入中的现实事实、local_review 与 allowed_theory；不得发明用户经历、思想家、概念、引文或来源。
decision 必须沿用 local_review 的决定；你的任务是把事实与上轮预期对照，提炼一条可验证经验，并把下一步改写得更贴近情境。
next_action 必须包含明确分钟数、只做一件事、可停止；next_minimum_done 与 next_evidence_rule 必须可观察。
evidence_id 必须等于 allowed_theory.evidence_id，并解释该概念怎样改变本案例判断、为什么推出下一步。
不得诊断、羞辱、威胁、利用恐惧或创伤、制造依赖，也不得把未行动解释为意志薄弱。
输出结构：
{"evidence_id":"","reality_comparison":"","learning":"","decision_reason":"","next_action":"","next_minimum_done":"","next_evidence_rule":"","case_application":"","why_this_action":""}
''';

  static const String _assistantSystemPrompt = '''
你是“向己·智能目标导师”的操作助手。只依据输入的 capabilities、current_goal、current_step、local_answer 和 sources 回答。
优先告诉用户此刻点哪里、填什么、做到哪里算完成；用短句，不增加不必要任务。
不得发明功能或来源，不得诊断、羞辱、威胁、制造依赖或宣称比用户更了解其本质。
只输出 JSON：{"answer":"","source_ids":[]}。source_ids 只能来自 sources；纯操作回答可以为空。
''';
}
