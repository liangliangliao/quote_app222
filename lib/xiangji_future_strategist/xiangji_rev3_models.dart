import 'dart:convert';

import 'xiangji_rev4_models.dart';

/// Rev.3 keeps the user's raw material immutable and stores the AI's current
/// understanding as a separate, versioned model that can become stale.
enum XiangjiSituationModelState {
  raw,
  parsed,
  judged,
  grounded,
  needsClarification,
  framed,
  stale,
}

extension XiangjiSituationModelStateX on XiangjiSituationModelState {
  String get wire => switch (this) {
        XiangjiSituationModelState.raw => 'RAW',
        XiangjiSituationModelState.parsed => 'PARSED',
        XiangjiSituationModelState.judged => 'JUDGED',
        XiangjiSituationModelState.grounded => 'GROUNDED',
        XiangjiSituationModelState.needsClarification =>
          'NEEDS_CLARIFICATION',
        XiangjiSituationModelState.framed => 'FRAMED',
        XiangjiSituationModelState.stale => 'STALE',
      };

  String get label => switch (this) {
        XiangjiSituationModelState.raw => '原始输入',
        XiangjiSituationModelState.parsed => '已解析',
        XiangjiSituationModelState.judged => '已完成判断力审查',
        XiangjiSituationModelState.grounded => '已完成根据审查',
        XiangjiSituationModelState.needsClarification => '等待一个关键补充',
        XiangjiSituationModelState.framed => '已形成真问题',
        XiangjiSituationModelState.stale => '已过期，待重算',
      };
}

enum XiangjiDecisionImpact { low, medium, high, critical }

extension XiangjiDecisionImpactX on XiangjiDecisionImpact {
  String get wire => name.toUpperCase();

  int get rank => switch (this) {
        XiangjiDecisionImpact.low => 0,
        XiangjiDecisionImpact.medium => 1,
        XiangjiDecisionImpact.high => 2,
        XiangjiDecisionImpact.critical => 3,
      };
}

/// This is intentionally a closed set. `ASK_FORM` does not exist in Rev.3.
enum XiangjiAskUserOutcome {
  continueAutonomous,
  askOne,
  scoutInReality,
  userDecision,
}

extension XiangjiAskUserOutcomeX on XiangjiAskUserOutcome {
  String get wire => switch (this) {
        XiangjiAskUserOutcome.continueAutonomous => 'CONTINUE_AUTONOMOUS',
        XiangjiAskUserOutcome.askOne => 'ASK_ONE',
        XiangjiAskUserOutcome.scoutInReality => 'SCOUT_IN_REALITY',
        XiangjiAskUserOutcome.userDecision => 'USER_DECISION',
      };
}

enum XiangjiOrchestrationState {
  cognitiveModeling,
  problemSolving,
  strategicCouncil,
  actionCompression,
  realityReconciliation,
  backgroundWatch,
}

extension XiangjiOrchestrationStateX on XiangjiOrchestrationState {
  String get wire => switch (this) {
        XiangjiOrchestrationState.cognitiveModeling => 'COGNITIVE_MODELING',
        XiangjiOrchestrationState.problemSolving => 'PROBLEM_SOLVING',
        XiangjiOrchestrationState.strategicCouncil => 'STRATEGIC_COUNCIL',
        XiangjiOrchestrationState.actionCompression => 'ACTION_COMPRESSION',
        XiangjiOrchestrationState.realityReconciliation =>
          'REALITY_RECONCILIATION',
        XiangjiOrchestrationState.backgroundWatch => 'BACKGROUND_WATCH',
      };

  String get label => switch (this) {
        XiangjiOrchestrationState.cognitiveModeling => '正在理解事实与处境',
        XiangjiOrchestrationState.problemSolving => '正在重构真问题并求解',
        XiangjiOrchestrationState.strategicCouncil => '正在谋划多条路线并红队审查',
        XiangjiOrchestrationState.actionCompression => '正在压缩为唯一当前行动',
        XiangjiOrchestrationState.realityReconciliation => '正在对照预测与现实',
        XiangjiOrchestrationState.backgroundWatch => '正在检查高价值变化',
      };
}

enum XiangjiDecisionDraftStatus {
  proposed,
  adopted,
  modified,
  opposed,
  deferred,
  stale,
}

extension XiangjiDecisionDraftStatusX on XiangjiDecisionDraftStatus {
  String get wire => name.toUpperCase();
}

enum XiangjiJudgmentState { draft, accepted, contested, revised }

extension XiangjiJudgmentStateX on XiangjiJudgmentState {
  String get wire => name.toUpperCase();
}

class XiangjiInformationNeed {
  const XiangjiInformationNeed({
    required this.id,
    required this.question,
    required this.missingField,
    this.missing = true,
    this.decisionImpact = XiangjiDecisionImpact.medium,
    this.canInfer = false,
    this.inferSourceRefs = const <String>[],
    this.scoutingPossible = false,
    this.scoutingOption = '',
    this.expectedValueOfInformation = 0,
    this.userBurden = 1,
    this.selectedForQuestion = false,
  });

  final String id;
  final String question;
  final String missingField;
  final bool missing;
  final XiangjiDecisionImpact decisionImpact;
  final bool canInfer;
  final List<String> inferSourceRefs;
  final bool scoutingPossible;
  final String scoutingOption;
  final double expectedValueOfInformation;
  final double userBurden;
  final bool selectedForQuestion;

  double get decisionValuePerBurden =>
      expectedValueOfInformation / (userBurden <= 0 ? 1 : userBurden);

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'question': question,
        'missing_field': missingField,
        'missing': missing,
        'decision_impact': decisionImpact.wire,
        'can_infer': canInfer,
        'infer_source_refs': inferSourceRefs,
        'scouting_possible': scoutingPossible,
        'scouting_option': scoutingOption,
        'expected_value_of_information': expectedValueOfInformation,
        'user_burden': userBurden,
        'selected_for_question': selectedForQuestion,
      };

  XiangjiInformationNeed copyWith({bool? selectedForQuestion}) =>
      XiangjiInformationNeed(
        id: id,
        question: question,
        missingField: missingField,
        missing: missing,
        decisionImpact: decisionImpact,
        canInfer: canInfer,
        inferSourceRefs: inferSourceRefs,
        scoutingPossible: scoutingPossible,
        scoutingOption: scoutingOption,
        expectedValueOfInformation: expectedValueOfInformation,
        userBurden: userBurden,
        selectedForQuestion:
            selectedForQuestion ?? this.selectedForQuestion,
      );
}

class XiangjiAskUserDecision {
  const XiangjiAskUserDecision({
    required this.outcome,
    this.selectedNeed,
    this.scoutingNeeds = const <XiangjiInformationNeed>[],
    this.reason = '',
  });

  final XiangjiAskUserOutcome outcome;
  final XiangjiInformationNeed? selectedNeed;
  final List<XiangjiInformationNeed> scoutingNeeds;
  final String reason;
}

class XiangjiRealityExtraction {
  const XiangjiRealityExtraction({
    this.facts = const <String>[],
    this.experiences = const <String>[],
    this.unexpected = const <String>[],
    this.interpretations = const <String>[],
  });

  final List<String> facts;
  final List<String> experiences;
  final List<String> unexpected;
  final List<String> interpretations;
}

/// Complete AI-prefilled workbench. The UI renders this draft; the user never
/// has to populate these internal structures from a blank form.
class XiangjiSituationDraft {
  const XiangjiSituationDraft({
    required this.need,
    required this.summary,
    required this.trueProblem,
    required this.goal,
    required this.valueLink,
    required this.successCriteria,
    required this.exitCriteria,
    required this.judgment,
    required this.recommendation,
    required this.why,
    required this.currentAction,
    required this.targetGap,
    required this.operatorMechanism,
    required this.strategicMeaning,
    required this.groundingReason,
    required this.prediction,
    required this.changeSignals,
    this.observedFacts = const <String>[],
    this.bodyExperiences = const <String>[],
    this.userInterpretations = const <String>[],
    this.predictions = const <String>[],
    this.assumptions = const <String>[],
    this.constraints = const <String>[],
    this.unknowns = const <String>[],
    this.causalHypotheses = const <String>[],
    this.relevantSimilarities = const <String>[],
    this.relevantDifferences = const <String>[],
    this.counterexamples = const <String>[],
    this.subGoals = const <String>[],
    this.operators = const <Map<String, Object?>>[],
    this.strategyOptions = const <Map<String, Object?>>[],
    this.redTeam = const <String>[],
    this.informationNeeds = const <XiangjiInformationNeed>[],
    this.expectedMinutes = 25,
    this.majorDecision = false,
    this.highRisk = false,
    this.irreversible = false,
    this.epistemicStatus = 'PROVISIONAL',
  });

  final String need;
  final String summary;
  final String trueProblem;
  final String goal;
  final String valueLink;
  final String successCriteria;
  final String exitCriteria;
  final String judgment;
  final String recommendation;
  final String why;
  final String currentAction;
  final String targetGap;
  final String operatorMechanism;
  final String strategicMeaning;
  final String groundingReason;
  final String prediction;
  final String changeSignals;
  final List<String> observedFacts;
  final List<String> bodyExperiences;
  final List<String> userInterpretations;
  final List<String> predictions;
  final List<String> assumptions;
  final List<String> constraints;
  final List<String> unknowns;
  final List<String> causalHypotheses;
  final List<String> relevantSimilarities;
  final List<String> relevantDifferences;
  final List<String> counterexamples;
  final List<String> subGoals;
  final List<Map<String, Object?>> operators;
  final List<Map<String, Object?>> strategyOptions;
  final List<String> redTeam;
  final List<XiangjiInformationNeed> informationNeeds;
  final int expectedMinutes;
  final bool majorDecision;
  final bool highRisk;
  final bool irreversible;
  final String epistemicStatus;

  Map<String, Object?> toMap() => <String, Object?>{
        'need': need,
        'summary': summary,
        'true_problem': trueProblem,
        'goal': goal,
        'value_link': valueLink,
        'success_criteria': successCriteria,
        'exit_criteria': exitCriteria,
        'judgment': judgment,
        'recommendation': recommendation,
        'why': why,
        'current_action': currentAction,
        'target_gap': targetGap,
        'operator_mechanism': operatorMechanism,
        'strategic_meaning': strategicMeaning,
        'grounding_reason': groundingReason,
        'prediction': prediction,
        'change_signals': changeSignals,
        'observed_facts': observedFacts,
        'body_experiences': bodyExperiences,
        'user_interpretations': userInterpretations,
        'predictions': predictions,
        'assumptions': assumptions,
        'constraints': constraints,
        'unknowns': unknowns,
        'causal_hypotheses': causalHypotheses,
        'relevant_similarities': relevantSimilarities,
        'relevant_differences': relevantDifferences,
        'counterexamples': counterexamples,
        'sub_goals': subGoals,
        'operators': operators,
        'strategy_options': strategyOptions,
        'red_team': redTeam,
        'information_needs':
            informationNeeds.map((item) => item.toMap()).toList(),
        'expected_minutes': expectedMinutes,
        'major_decision': majorDecision,
        'high_risk': highRisk,
        'irreversible': irreversible,
        'epistemic_status': epistemicStatus,
      };

  XiangjiSituationDraft mergeAgentOutputs(
    Map<String, Map<String, Object?>> outputs,
  ) {
    final a01 = outputs['A01'] ?? const <String, Object?>{};
    final a02 = outputs['A02'] ?? const <String, Object?>{};
    final a03 = outputs['A03'] ?? const <String, Object?>{};
    final a04 = outputs['A04'] ?? const <String, Object?>{};
    final a05 = outputs['A05'] ?? const <String, Object?>{};
    final a06 = outputs['A06'] ?? const <String, Object?>{};
    final a09 = outputs['A09'] ?? const <String, Object?>{};
    final a10 = outputs['A10'] ?? const <String, Object?>{};
    final a12 = outputs['A12'] ?? const <String, Object?>{};
    final a00 = outputs['A00'] ?? const <String, Object?>{};
    final aiOptions = _mapList(a09['options']);
    final activeOperator = _mapObject(a06['active_operator']);
    final candidateOperators = _mapList(a06['candidate_operators']);
    final legacyOperators = _mapList(a06['operators']);
    final aiOperators = <Map<String, Object?>>[
      if (activeOperator.isNotEmpty) activeOperator,
      ...(candidateOperators.isNotEmpty
          ? candidateOperators
          : legacyOperators),
    ];
    return XiangjiSituationDraft(
      need: _nonEmpty(a00['current_need'], need),
      summary: _nonEmpty(a00['situation_summary'], summary),
      trueProblem: _nonEmpty(
        a00['true_problem'],
        _nonEmpty(a05['true_problem'], trueProblem),
      ),
      goal: _nonEmpty(a06['goal'], goal),
      valueLink: _nonEmpty(a06['value_link'], valueLink),
      successCriteria:
          _nonEmpty(a06['success_criteria'], successCriteria),
      exitCriteria: _nonEmpty(a06['exit_criteria'], exitCriteria),
      judgment: _nonEmpty(
        a00['strategist_judgment'],
        _nonEmpty(a03['conclusion'], judgment),
      ),
      recommendation: _nonEmpty(a00['recommendation'], recommendation),
      why: _nonEmpty(a00['why'], _nonEmpty(a06['reasoning_summary'], why)),
      currentAction: _nonEmpty(
        a12['current_action'],
        _nonEmpty(
          a00['current_action'],
          _nonEmpty(a06['current_action'], currentAction),
        ),
      ),
      targetGap: _nonEmpty(a06['key_gap'], targetGap),
      operatorMechanism:
          _nonEmpty(a06['operator_mechanism'], operatorMechanism),
      strategicMeaning:
          _nonEmpty(a06['strategic_meaning'], strategicMeaning),
      groundingReason: _nonEmpty(
        a04['grounding_summary'],
        _nonEmpty(a06['grounding_reason'], groundingReason),
      ),
      prediction: _nonEmpty(a06['prediction'], prediction),
      changeSignals:
          _nonEmpty(a00['change_signals'], changeSignals),
      observedFacts: _preferStrings(a01['raw_facts'], observedFacts),
      bodyExperiences:
          _preferStrings(a01['body_experiences'], bodyExperiences),
      userInterpretations:
          _preferStrings(a01['user_interpretations'], userInterpretations),
      predictions: _preferStrings(a01['predictions'], predictions),
      assumptions: _preferStrings(
        a05['hidden_premises'],
        _preferStrings(a06['hypotheses'], assumptions),
      ),
      constraints: _preferStrings(a06['constraints'], constraints),
      unknowns: _preferStrings(
        a04['critical_unknowns'],
        _preferStrings(a01['critical_unknowns'], unknowns),
      ),
      causalHypotheses: _preferStrings(
        a02['causal_hypotheses'],
        _preferStrings(a01['causal_hypotheses'], causalHypotheses),
      ),
      relevantSimilarities:
          _preferStrings(a03['relevant_similarities'], relevantSimilarities),
      relevantDifferences:
          _preferStrings(a03['relevant_differences'], relevantDifferences),
      counterexamples:
          _preferStrings(a03['counterexamples'], counterexamples),
      subGoals: _preferStrings(a06['sub_goals'], subGoals),
      operators: aiOperators.isEmpty ? operators : aiOperators,
      strategyOptions: aiOptions.isEmpty ? strategyOptions : aiOptions,
      redTeam: _mergeStrings(
        <Object?>[
          a10['vulnerable_premises'],
          a10['failure_paths'],
          a10['disagreements'],
        ],
        redTeam,
      ),
      informationNeeds: informationNeeds,
      expectedMinutes: _positiveInt(
        a12['expected_minutes'],
        _positiveInt(a06['expected_minutes'], expectedMinutes),
      ),
      majorDecision: majorDecision,
      highRisk: highRisk,
      irreversible: irreversible,
      epistemicStatus:
          _nonEmpty(a00['epistemic_status'], epistemicStatus),
    );
  }
}

class XiangjiDecisionDraftRecord {
  const XiangjiDecisionDraftRecord({
    required this.id,
    required this.problemId,
    required this.situationModelId,
    required this.recommendation,
    required this.judgment,
    required this.why,
    required this.currentAction,
    required this.changeSignals,
    required this.epistemicStatus,
    required this.status,
    this.trueProblem = '',
    this.campaignId = '',
    this.actionId = '',
    this.clarificationQuestion = '',
    this.options = const <Map<String, Object?>>[],
    this.weakestPremise = '',
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;
  final String problemId;
  final String campaignId;
  final String actionId;
  final String situationModelId;
  final String trueProblem;
  final String recommendation;
  final String judgment;
  final String why;
  final String currentAction;
  final String changeSignals;
  final String epistemicStatus;
  final String clarificationQuestion;
  final List<Map<String, Object?>> options;
  final String weakestPremise;
  final XiangjiDecisionDraftStatus status;
  final int createdAtMs;
  final int updatedAtMs;

  factory XiangjiDecisionDraftRecord.fromMap(Map<String, Object?> row) {
    final statusWire = (row['user_status'] ?? 'PROPOSED').toString();
    return XiangjiDecisionDraftRecord(
      id: (row['id'] ?? '').toString(),
      problemId: (row['problem_id'] ?? '').toString(),
      campaignId: (row['campaign_id'] ?? '').toString(),
      actionId: (row['action_id'] ?? '').toString(),
      situationModelId: (row['situation_model_id'] ?? '').toString(),
      trueProblem: (row['true_problem'] ?? '').toString(),
      recommendation: (row['recommendation'] ?? '').toString(),
      judgment: (row['judgment'] ?? '').toString(),
      why: (row['why_text'] ?? '').toString(),
      currentAction: (row['current_action'] ?? '').toString(),
      changeSignals: (row['change_signals'] ?? '').toString(),
      epistemicStatus: (row['epistemic_status'] ?? 'PROVISIONAL').toString(),
      clarificationQuestion:
          (row['clarification_question'] ?? '').toString(),
      options: _decodeMapList(row['options_json']),
      weakestPremise: (row['weakest_premise'] ?? '').toString(),
      status: XiangjiDecisionDraftStatus.values.firstWhere(
        (value) => value.wire == statusWire,
        orElse: () => XiangjiDecisionDraftStatus.proposed,
      ),
      createdAtMs: _asInt(row['created_at_ms']),
      updatedAtMs: _asInt(row['updated_at_ms']),
    );
  }
}

class XiangjiCouncilResult {
  const XiangjiCouncilResult({
    required this.problemId,
    required this.situationModelId,
    required this.decisionDraftId,
    required this.outcome,
    required this.draft,
    this.campaignId = '',
    this.actionId = '',
    this.clarificationQuestion = '',
    this.agentRunIds = const <String>[],
    this.warnings = const <String>[],
    this.executionFrozen = false,
    this.cognitiveExperiences = const <XiangjiCognitiveExperienceDraft>[],
    this.inputClassification,
    this.problemProgress,
    this.aiExecution = const XiangjiAiExecutionSummary(),
  });

  final String problemId;
  final String campaignId;
  final String actionId;
  final String situationModelId;
  final String decisionDraftId;
  final XiangjiAskUserOutcome outcome;
  final String clarificationQuestion;
  final XiangjiSituationDraft draft;
  final List<String> agentRunIds;
  final List<String> warnings;
  final bool executionFrozen;
  final List<XiangjiCognitiveExperienceDraft> cognitiveExperiences;
  final XiangjiInputClassification? inputClassification;
  final XiangjiProblemProgress? problemProgress;
  final XiangjiAiExecutionSummary aiExecution;
}

/// Auditable evidence of model participation without private chain-of-thought.
class XiangjiAiExecutionSummary {
  const XiangjiAiExecutionSummary({
    this.aiConfigured = false,
    this.provider = '',
    this.model = '',
    this.plannedAgentCount = 0,
    this.cloudAgentCount = 0,
    this.localAgentCount = 0,
    this.failedAgentCount = 0,
    this.privacyBlockedAgentCount = 0,
    this.totalLatencyMs = 0,
    this.redactedFieldCount = 0,
    this.cloudAgentLabels = const <String>[],
    this.localAgentLabels = const <String>[],
    this.changedArtifacts = const <String>[],
    this.sensitiveCategories = const <String>[],
  });

  final bool aiConfigured;
  final String provider;
  final String model;
  final int plannedAgentCount;
  final int cloudAgentCount;
  final int localAgentCount;
  final int failedAgentCount;
  final int privacyBlockedAgentCount;
  final int totalLatencyMs;
  final int redactedFieldCount;
  final List<String> cloudAgentLabels;
  final List<String> localAgentLabels;
  final List<String> changedArtifacts;
  final List<String> sensitiveCategories;

  bool get cloudAiUsed => cloudAgentCount > 0;
  bool get sensitiveConsentRequired => privacyBlockedAgentCount > 0;

  Map<String, Object?> toMap() => <String, Object?>{
        'ai_configured': aiConfigured,
        'provider': provider,
        'model': model,
        'planned_agent_count': plannedAgentCount,
        'cloud_agent_count': cloudAgentCount,
        'local_agent_count': localAgentCount,
        'failed_agent_count': failedAgentCount,
        'privacy_blocked_agent_count': privacyBlockedAgentCount,
        'total_latency_ms': totalLatencyMs,
        'redacted_field_count': redactedFieldCount,
        'cloud_agent_labels': cloudAgentLabels,
        'local_agent_labels': localAgentLabels,
        'changed_artifacts': changedArtifacts,
        'sensitive_categories': sensitiveCategories,
      };

  factory XiangjiAiExecutionSummary.fromMap(Map<String, Object?> value) =>
      XiangjiAiExecutionSummary(
        aiConfigured: value['ai_configured'] == true,
        provider: (value['provider'] ?? '').toString(),
        model: (value['model'] ?? '').toString(),
        plannedAgentCount: _asInt(value['planned_agent_count']),
        cloudAgentCount: _asInt(value['cloud_agent_count']),
        localAgentCount: _asInt(value['local_agent_count']),
        failedAgentCount: _asInt(value['failed_agent_count']),
        privacyBlockedAgentCount:
            _asInt(value['privacy_blocked_agent_count']),
        totalLatencyMs: _asInt(value['total_latency_ms']),
        redactedFieldCount: _asInt(value['redacted_field_count']),
        cloudAgentLabels: _stringList(value['cloud_agent_labels']),
        localAgentLabels: _stringList(value['local_agent_labels']),
        changedArtifacts: _stringList(value['changed_artifacts']),
        sensitiveCategories: _stringList(value['sensitive_categories']),
      );
}

String _nonEmpty(Object? value, String fallback) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

int _positiveInt(Object? value, int fallback) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : fallback;
}

List<String> _preferStrings(Object? value, List<String> fallback) {
  final parsed = _stringList(value);
  return parsed.isEmpty ? fallback : parsed;
}

List<String> _mergeStrings(List<Object?> values, List<String> fallback) {
  final merged = <String>[];
  final seen = <String>{};
  for (final value in values) {
    for (final item in _stringList(value)) {
      if (seen.add(item)) merged.add(item);
    }
  }
  return merged.isEmpty ? fallback : merged;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) {
        if (item is Map) {
          return (item['text'] ??
                  item['content'] ??
                  item['statement'] ??
                  item['name'] ??
                  '')
              .toString()
              .trim();
        }
        return item.toString().trim();
      })
      .where((item) => item.isNotEmpty)
      .toList();
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return value
      .whereType<Map>()
      .map((item) => item.map(
            (key, dynamic value) => MapEntry(key.toString(), value as Object?),
          ))
      .toList();
}

Map<String, Object?> _mapObject(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map(
    (key, dynamic item) => MapEntry(key.toString(), item as Object?),
  );
}

List<Map<String, Object?>> _decodeMapList(Object? raw) {
  try {
    final decoded = jsonDecode((raw ?? '[]').toString());
    return _mapList(decoded);
  } catch (_) {
    return const <Map<String, Object?>>[];
  }
}

int _asInt(Object? value) =>
    value is int ? value : int.tryParse((value ?? '').toString()) ?? 0;
