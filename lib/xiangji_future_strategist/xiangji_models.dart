import 'dart:convert';

import 'xiangji_method_catalog.dart';

/// Domain language is stored as stable English keys. The military wording is
/// a presentation choice only, so it can be replaced by ordinary-language UI
/// without migrating persisted records.
enum XiangjiClaimState {
  draft,
  grounded,
  provisional,
  unresolved,
  epistemicDebt,
  conflicted,
  retired,
}

enum XiangjiProblemState {
  captured,
  formalizing,
  epistemicReview,
  conceptReview,
  solving,
  actionReady,
  executing,
  verifying,
  backtracking,
  resolved,
  archived,
}

enum XiangjiCampaignState {
  idea,
  warWorthiness,
  intel,
  planning,
  redTeam,
  decision,
  prepare,
  executing,
  hold,
  adjust,
  retreat,
  won,
  lost,
  closed,
}

enum XiangjiActionState {
  planned,
  ready,
  inProgress,
  blocked,
  done,
  aborted,
  invalidated,
}

enum XiangjiAlertState { green, yellow, orange, red, blue }

enum XiangjiKnowledgeLayer { k0, k1, k2, k3, k4 }

enum XiangjiKnowledgeSourceStatus {
  draft,
  active,
  stale,
  conflicted,
  retired,
}

enum XiangjiKnowledgeItemState {
  candidate,
  supported,
  stable,
  conflicted,
  superseded,
  retired,
}

enum XiangjiProviderFileState {
  notUploaded,
  uploading,
  processing,
  ready,
  failed,
  deleting,
  deleted,
}

enum XiangjiProviderBindingState {
  unbound,
  binding,
  bound,
  degraded,
  unbinding,
}

enum XiangjiRetrievalSessionState {
  created,
  rulePreflight,
  routing,
  retrieving,
  assembled,
  used,
  audited,
}

enum XiangjiBasisType {
  directExperience,
  measurement,
  document,
  multiSourceObservation,
  induction,
  causalInference,
  abstractDerivation,
  aiInference,
  unknown,
}

enum XiangjiSummaryStatus {
  strongSupport,
  provisional,
  unresolved,
  highDebt,
  conflicted,
}

extension XiangjiClaimStateWire on XiangjiClaimState {
  String get wire => switch (this) {
        XiangjiClaimState.draft => 'DRAFT',
        XiangjiClaimState.grounded => 'GROUNDED',
        XiangjiClaimState.provisional => 'PROVISIONAL',
        XiangjiClaimState.unresolved => 'UNRESOLVED',
        XiangjiClaimState.epistemicDebt => 'EPISTEMIC_DEBT',
        XiangjiClaimState.conflicted => 'CONFLICTED',
        XiangjiClaimState.retired => 'RETIRED',
      };

  String get label => switch (this) {
        XiangjiClaimState.draft => '草稿',
        XiangjiClaimState.grounded => '较强支持',
        XiangjiClaimState.provisional => '暂时支持',
        XiangjiClaimState.unresolved => '未决',
        XiangjiClaimState.epistemicDebt => '高认识债务',
        XiangjiClaimState.conflicted => '与现实冲突',
        XiangjiClaimState.retired => '已退役',
      };
}

extension XiangjiProblemStateWire on XiangjiProblemState {
  String get wire => switch (this) {
        XiangjiProblemState.captured => 'CAPTURED',
        XiangjiProblemState.formalizing => 'FORMALIZING',
        XiangjiProblemState.epistemicReview => 'EPISTEMIC_REVIEW',
        XiangjiProblemState.conceptReview => 'CONCEPT_REVIEW',
        XiangjiProblemState.solving => 'SOLVING',
        XiangjiProblemState.actionReady => 'ACTION_READY',
        XiangjiProblemState.executing => 'EXECUTING',
        XiangjiProblemState.verifying => 'VERIFYING',
        XiangjiProblemState.backtracking => 'BACKTRACKING',
        XiangjiProblemState.resolved => 'RESOLVED',
        XiangjiProblemState.archived => 'ARCHIVED',
      };

  String get label => switch (this) {
        XiangjiProblemState.captured => '已记录原题',
        XiangjiProblemState.formalizing => '事实与解释分层',
        XiangjiProblemState.epistemicReview => '认识审查',
        XiangjiProblemState.conceptReview => '概念与真问题审查',
        XiangjiProblemState.solving => '求解中',
        XiangjiProblemState.actionReady => '行动待确认',
        XiangjiProblemState.executing => '行动中',
        XiangjiProblemState.verifying => '现实验算',
        XiangjiProblemState.backtracking => '回溯中',
        XiangjiProblemState.resolved => '阶段性解决',
        XiangjiProblemState.archived => '已归档',
      };
}

extension XiangjiCampaignStateWire on XiangjiCampaignState {
  String get wire => switch (this) {
        XiangjiCampaignState.idea => 'IDEA',
        XiangjiCampaignState.warWorthiness => 'WAR_WORTHINESS',
        XiangjiCampaignState.intel => 'INTEL',
        XiangjiCampaignState.planning => 'PLANNING',
        XiangjiCampaignState.redTeam => 'RED_TEAM',
        XiangjiCampaignState.decision => 'DECISION',
        XiangjiCampaignState.prepare => 'PREPARE',
        XiangjiCampaignState.executing => 'EXECUTING',
        XiangjiCampaignState.hold => 'HOLD',
        XiangjiCampaignState.adjust => 'ADJUST',
        XiangjiCampaignState.retreat => 'RETREAT',
        XiangjiCampaignState.won => 'WON',
        XiangjiCampaignState.lost => 'LOST',
        XiangjiCampaignState.closed => 'CLOSED',
      };

  String get label => switch (this) {
        XiangjiCampaignState.idea => '构想',
        XiangjiCampaignState.warWorthiness => '是否值得一战',
        XiangjiCampaignState.intel => '侦察与战争迷雾',
        XiangjiCampaignState.planning => '战略规划',
        XiangjiCampaignState.redTeam => '红队军议',
        XiangjiCampaignState.decision => '等待用户决断',
        XiangjiCampaignState.prepare => '准备',
        XiangjiCampaignState.executing => '推进中',
        XiangjiCampaignState.hold => '暂停保全',
        XiangjiCampaignState.adjust => '调整',
        XiangjiCampaignState.retreat => '战略撤退',
        XiangjiCampaignState.won => '已达胜利条件',
        XiangjiCampaignState.lost => '未达目标',
        XiangjiCampaignState.closed => '已结束',
      };
}

extension XiangjiActionStateWire on XiangjiActionState {
  String get wire => switch (this) {
        XiangjiActionState.planned => 'PLANNED',
        XiangjiActionState.ready => 'READY',
        XiangjiActionState.inProgress => 'IN_PROGRESS',
        XiangjiActionState.blocked => 'BLOCKED',
        XiangjiActionState.done => 'DONE',
        XiangjiActionState.aborted => 'ABORTED',
        XiangjiActionState.invalidated => 'INVALIDATED',
      };

  String get label => switch (this) {
        XiangjiActionState.planned => '计划中',
        XiangjiActionState.ready => '准备行动',
        XiangjiActionState.inProgress => '行动中',
        XiangjiActionState.blocked => '遇到阻碍',
        XiangjiActionState.done => '行动已完成，待验算',
        XiangjiActionState.aborted => '已中止',
        XiangjiActionState.invalidated => '前提失效',
      };
}

extension XiangjiAlertStateWire on XiangjiAlertState {
  String get wire => name.toUpperCase();

  String get label => switch (this) {
        XiangjiAlertState.green => '正常推进 / 当前证据基本一致',
        XiangjiAlertState.yellow => '认识不足 / 先补情报',
        XiangjiAlertState.orange => '战略偏航 / 暂停加码',
        XiangjiAlertState.red => '高风险 / 关键认识不足',
        XiangjiAlertState.blue => '出现战机 / 值得快速军议',
      };
}

extension XiangjiKnowledgeLayerWire on XiangjiKnowledgeLayer {
  String get wire => name.toUpperCase();

  String get label => switch (this) {
        XiangjiKnowledgeLayer.k0 => 'K0 认识论内核',
        XiangjiKnowledgeLayer.k1 => 'K1 问题求解',
        XiangjiKnowledgeLayer.k2 => 'K2 战略决策',
        XiangjiKnowledgeLayer.k3 => 'K3 思想与行动方法',
        XiangjiKnowledgeLayer.k4 => 'K4 个人经验科学',
      };
}

extension XiangjiKnowledgeItemStateWire on XiangjiKnowledgeItemState {
  String get wire => name.toUpperCase();
}

extension XiangjiProviderFileStateWire on XiangjiProviderFileState {
  String get wire => switch (this) {
        XiangjiProviderFileState.notUploaded => 'NOT_UPLOADED',
        XiangjiProviderFileState.uploading => 'UPLOADING',
        XiangjiProviderFileState.processing => 'PROCESSING',
        XiangjiProviderFileState.ready => 'READY',
        XiangjiProviderFileState.failed => 'FAILED',
        XiangjiProviderFileState.deleting => 'DELETING',
        XiangjiProviderFileState.deleted => 'DELETED',
      };

  String get label => switch (this) {
        XiangjiProviderFileState.notUploaded => '未上传',
        XiangjiProviderFileState.uploading => '上传中',
        XiangjiProviderFileState.processing => '索引中',
        XiangjiProviderFileState.ready => '已就绪',
        XiangjiProviderFileState.failed => '失败',
        XiangjiProviderFileState.deleting => '删除中',
        XiangjiProviderFileState.deleted => '已删除',
      };
}

extension XiangjiProviderBindingStateWire on XiangjiProviderBindingState {
  String get wire => name.toUpperCase();
}

extension XiangjiRetrievalSessionStateWire on XiangjiRetrievalSessionState {
  String get wire => switch (this) {
        XiangjiRetrievalSessionState.created => 'CREATED',
        XiangjiRetrievalSessionState.rulePreflight => 'RULE_PREFLIGHT',
        XiangjiRetrievalSessionState.routing => 'ROUTING',
        XiangjiRetrievalSessionState.retrieving => 'RETRIEVING',
        XiangjiRetrievalSessionState.assembled => 'ASSEMBLED',
        XiangjiRetrievalSessionState.used => 'USED',
        XiangjiRetrievalSessionState.audited => 'AUDITED',
      };
}

XiangjiClaimState parseClaimState(Object? raw) => _enumByWire(
      XiangjiClaimState.values,
      raw,
      (value) => value.wire,
      XiangjiClaimState.draft,
    );

XiangjiProblemState parseProblemState(Object? raw) => _enumByWire(
      XiangjiProblemState.values,
      raw,
      (value) => value.wire,
      XiangjiProblemState.captured,
    );

XiangjiCampaignState parseCampaignState(Object? raw) => _enumByWire(
      XiangjiCampaignState.values,
      raw,
      (value) => value.wire,
      XiangjiCampaignState.idea,
    );

XiangjiActionState parseActionState(Object? raw) => _enumByWire(
      XiangjiActionState.values,
      raw,
      (value) => value.wire,
      XiangjiActionState.planned,
    );

XiangjiAlertState parseAlertState(Object? raw) => _enumByWire(
      XiangjiAlertState.values,
      raw,
      (value) => value.wire,
      XiangjiAlertState.green,
    );

XiangjiProviderFileState parseProviderFileState(Object? raw) => _enumByWire(
      XiangjiProviderFileState.values,
      raw,
      (value) => value.wire,
      XiangjiProviderFileState.notUploaded,
    );

T _enumByWire<T>(
  Iterable<T> values,
  Object? raw,
  String Function(T value) wire,
  T fallback,
) {
  final normalized = raw?.toString().trim().toUpperCase() ?? '';
  for (final value in values) {
    if (wire(value).toUpperCase() == normalized) return value;
  }
  return fallback;
}

class XiangjiEpistemicProfile {
  const XiangjiEpistemicProfile({
    required this.basisType,
    required this.directness,
    required this.completeness,
    required this.independentValidation,
    required this.counterexampleState,
    required this.freshness,
    required this.summaryStatus,
    this.systematicity = 'unknown',
    this.weakestPremise = '',
  });

  final XiangjiBasisType basisType;
  final int directness;
  final String completeness;
  final int independentValidation;
  final String counterexampleState;
  final String freshness;
  final XiangjiSummaryStatus summaryStatus;

  /// Deliberately separate from epistemic status (EP-015).
  final String systematicity;
  final String weakestPremise;

  Map<String, Object?> toMap() => <String, Object?>{
        'basis_type': basisType.name,
        'directness': directness,
        'completeness': completeness,
        'independent_validation': independentValidation,
        'counterexample_state': counterexampleState,
        'freshness': freshness,
        'summary_status': summaryStatus.name,
        'systematicity': systematicity,
        'weakest_premise': weakestPremise,
      };

  factory XiangjiEpistemicProfile.fromMap(Map<String, Object?> map) {
    final basis = map['basis_type']?.toString() ?? '';
    final summary = map['summary_status']?.toString() ?? '';
    return XiangjiEpistemicProfile(
      basisType: XiangjiBasisType.values.firstWhere(
        (value) => value.name == basis,
        orElse: () => XiangjiBasisType.unknown,
      ),
      directness: _asInt(map['directness']),
      completeness: (map['completeness'] ?? 'weak').toString(),
      independentValidation: _asInt(map['independent_validation']),
      counterexampleState:
          (map['counterexample_state'] ?? 'unresolved').toString(),
      freshness: (map['freshness'] ?? 'unknown').toString(),
      summaryStatus: XiangjiSummaryStatus.values.firstWhere(
        (value) => value.name == summary,
        orElse: () => XiangjiSummaryStatus.unresolved,
      ),
      systematicity: (map['systematicity'] ?? 'unknown').toString(),
      weakestPremise: (map['weakest_premise'] ?? '').toString(),
    );
  }
}

class XiangjiProblemRecord {
  const XiangjiProblemRecord({
    required this.id,
    required this.rawQuestion,
    required this.state,
    this.reframedQuestion = '',
    this.campaignId = '',
    this.goalText = '',
    this.successCriteria = '',
    this.exitCriteria = '',
    this.reviewAtMs = 0,
    this.priority = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.need = '',
    this.rootGoalId = '',
    this.parentProblemId = '',
    this.currentStateVersionId = '',
    this.canonicalProblemId = '',
    this.problemStatus = 'ACTIVE',
  });

  final String id;
  final String rawQuestion;
  final String reframedQuestion;
  final XiangjiProblemState state;
  final String campaignId;
  final String goalText;
  final String successCriteria;
  final String exitCriteria;
  final int reviewAtMs;
  final int priority;
  final int createdAtMs;
  final int updatedAtMs;
  final String need;
  final String rootGoalId;
  final String parentProblemId;
  final String currentStateVersionId;
  final String canonicalProblemId;
  final String problemStatus;

  factory XiangjiProblemRecord.fromMap(Map<String, Object?> row) =>
      XiangjiProblemRecord(
        id: (row['id'] ?? '').toString(),
        rawQuestion: (row['raw_question'] ?? '').toString(),
        reframedQuestion: (row['reframed_question'] ?? '').toString(),
        state: parseProblemState(row['state']),
        campaignId: (row['campaign_id'] ?? '').toString(),
        goalText: (row['goal_text'] ?? '').toString(),
        successCriteria: (row['success_criteria'] ?? '').toString(),
        exitCriteria: (row['exit_criteria'] ?? '').toString(),
        reviewAtMs: _asInt(row['review_at_ms']),
        priority: _asInt(row['priority']),
        createdAtMs: _asInt(row['created_at_ms']),
        updatedAtMs: _asInt(row['updated_at_ms']),
        need: (row['need'] ?? '').toString(),
        rootGoalId: (row['root_goal_id'] ?? '').toString(),
        parentProblemId: (row['parent_problem_id'] ?? '').toString(),
        currentStateVersionId:
            (row['current_state_version_id'] ?? '').toString(),
        canonicalProblemId: (row['canonical_problem_id'] ?? '').toString(),
        problemStatus: (row['problem_status'] ?? 'ACTIVE').toString(),
      );
}

class XiangjiCampaignRecord {
  const XiangjiCampaignRecord({
    required this.id,
    required this.title,
    required this.state,
    this.northStar = '',
    this.grandStrategy = '',
    this.theater = '',
    this.strategicValue = '',
    this.warWorthiness = '',
    this.victoryCriteria = '',
    this.exitCriteria = '',
    this.resourceBudget = const <String, Object?>{},
    this.reviewAtMs = 0,
    this.isPrimary = false,
    this.userConfirmed = false,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;
  final String title;
  final XiangjiCampaignState state;
  final String northStar;
  final String grandStrategy;
  final String theater;
  final String strategicValue;
  final String warWorthiness;
  final String victoryCriteria;
  final String exitCriteria;
  final Map<String, Object?> resourceBudget;
  final int reviewAtMs;
  final bool isPrimary;
  final bool userConfirmed;
  final int createdAtMs;
  final int updatedAtMs;

  factory XiangjiCampaignRecord.fromMap(Map<String, Object?> row) =>
      XiangjiCampaignRecord(
        id: (row['id'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        state: parseCampaignState(row['state']),
        northStar: (row['north_star'] ?? '').toString(),
        grandStrategy: (row['grand_strategy'] ?? '').toString(),
        theater: (row['theater'] ?? '').toString(),
        strategicValue: (row['strategic_value'] ?? '').toString(),
        warWorthiness: (row['war_worthiness'] ?? '').toString(),
        victoryCriteria: (row['victory_criteria'] ?? '').toString(),
        exitCriteria: (row['exit_criteria'] ?? '').toString(),
        resourceBudget: _jsonMap(row['resource_budget_json']),
        reviewAtMs: _asInt(row['review_at_ms']),
        isPrimary: _asBool(row['is_primary']),
        userConfirmed: _asBool(row['user_confirmed']),
        createdAtMs: _asInt(row['created_at_ms']),
        updatedAtMs: _asInt(row['updated_at_ms']),
      );
}

class XiangjiActionRecord {
  const XiangjiActionRecord({
    required this.id,
    required this.title,
    required this.state,
    this.campaignId = '',
    this.problemId = '',
    this.whyChain = const <String, Object?>{},
    this.prediction = '',
    this.expectedMinutes = 0,
    this.todoRef = '',
    this.blockerType = '',
    this.startedAtMs = 0,
    this.completedAtMs = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;
  final String title;
  final XiangjiActionState state;
  final String campaignId;
  final String problemId;
  final Map<String, Object?> whyChain;
  final String prediction;
  final int expectedMinutes;
  final String todoRef;
  final String blockerType;
  final int startedAtMs;
  final int completedAtMs;
  final int createdAtMs;
  final int updatedAtMs;

  factory XiangjiActionRecord.fromMap(Map<String, Object?> row) =>
      XiangjiActionRecord(
        id: (row['id'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        state: parseActionState(row['state']),
        campaignId: (row['campaign_id'] ?? '').toString(),
        problemId: (row['problem_id'] ?? '').toString(),
        whyChain: _jsonMap(row['why_chain_json']),
        prediction: (row['prediction'] ?? '').toString(),
        expectedMinutes: _asInt(row['expected_minutes']),
        todoRef: (row['todo_ref'] ?? '').toString(),
        blockerType: (row['blocker_type'] ?? '').toString(),
        startedAtMs: _asInt(row['started_at_ms']),
        completedAtMs: _asInt(row['completed_at_ms']),
        createdAtMs: _asInt(row['created_at_ms']),
        updatedAtMs: _asInt(row['updated_at_ms']),
      );
}

class XiangjiDashboardSnapshot {
  const XiangjiDashboardSnapshot({
    this.northStar = '',
    this.primaryCampaign,
    this.currentProblem,
    this.currentAction,
    this.alertState = XiangjiAlertState.green,
    this.alertReason = '',
    this.alertDefaultAction = '',
    this.keyGap = '',
    this.strategistJudgment = '',
    this.strategistEpistemicStatus = '',
    this.contingency = '',
    this.nextReviewAtMs = 0,
    this.unresolvedDebtCount = 0,
  });

  final String northStar;
  final XiangjiCampaignRecord? primaryCampaign;
  final XiangjiProblemRecord? currentProblem;
  final XiangjiActionRecord? currentAction;
  final XiangjiAlertState alertState;
  final String alertReason;
  final String alertDefaultAction;
  final String keyGap;
  final String strategistJudgment;
  final String strategistEpistemicStatus;
  final String contingency;
  final int nextReviewAtMs;
  final int unresolvedDebtCount;
}

/// The durable, single-chain solver state introduced by V6.1 Rev.5.2.
///
/// The existing normalized tables remain the source of truth for facts,
/// claims, actions and reality results. This snapshot makes the current
/// means-ends chain explicit so the UI and MethodEvent audit trail can point
/// to the same versioned state instead of reconstructing it from prose.
class XiangjiSolverSnapshot {
  const XiangjiSolverSnapshot({
    required this.problemId,
    this.stateVersion = 1,
    this.need = '',
    this.problemFrame = const <String, Object?>{},
    this.currentState = const <String, Object?>{},
    this.goalState = const <String, Object?>{},
    this.hypotheses = const <Map<String, Object?>>[],
    this.constraints = const <Map<String, Object?>>[],
    this.gaps = const <Map<String, Object?>>[],
    this.keyGap = const <String, Object?>{},
    this.subgoalGraph = const <String, Object?>{},
    this.activeSubgoal = const <String, Object?>{},
    this.candidateOperators = const <Map<String, Object?>>[],
    this.activeOperator = const <String, Object?>{},
    this.epistemicProfile = const <String, Object?>{},
    this.predictionLedger = const <String, Object?>{},
    this.lastRealityResult = const <String, Object?>{},
    this.backtrackHistory = const <Map<String, Object?>>[],
    this.promptVersion = 'rev5.2',
    this.updatedAtMs = 0,
  });

  final String problemId;
  final int stateVersion;
  final String need;
  final Map<String, Object?> problemFrame;
  final Map<String, Object?> currentState;
  final Map<String, Object?> goalState;
  final List<Map<String, Object?>> hypotheses;
  final List<Map<String, Object?>> constraints;
  final List<Map<String, Object?>> gaps;
  final Map<String, Object?> keyGap;
  final Map<String, Object?> subgoalGraph;
  final Map<String, Object?> activeSubgoal;
  final List<Map<String, Object?>> candidateOperators;
  final Map<String, Object?> activeOperator;
  final Map<String, Object?> epistemicProfile;
  final Map<String, Object?> predictionLedger;
  final Map<String, Object?> lastRealityResult;
  final List<Map<String, Object?>> backtrackHistory;
  final String promptVersion;
  final int updatedAtMs;

  String get currentStateSummary {
    final summary = (currentState['summary'] ?? '').toString().trim();
    if (summary.isNotEmpty) return summary;
    final facts = currentState['facts'];
    if (facts is List && facts.isNotEmpty) return facts.first.toString();
    return need;
  }

  String get goalSummary =>
      (goalState['statement'] ?? goalState['goal'] ?? '').toString();

  String get keyGapSummary =>
      (keyGap['label'] ?? keyGap['description'] ?? '').toString();

  String get activeSubgoalSummary =>
      (activeSubgoal['label'] ?? activeSubgoal['description'] ?? '').toString();

  String get activeOperatorSummary =>
      (activeOperator['title'] ?? activeOperator['name'] ?? '').toString();

  String get predictionSummary =>
      (predictionLedger['prediction'] ?? '').toString();

  XiangjiSolverSnapshot copyWith({
    int? stateVersion,
    String? need,
    Map<String, Object?>? problemFrame,
    Map<String, Object?>? currentState,
    Map<String, Object?>? goalState,
    List<Map<String, Object?>>? hypotheses,
    List<Map<String, Object?>>? constraints,
    List<Map<String, Object?>>? gaps,
    Map<String, Object?>? keyGap,
    Map<String, Object?>? subgoalGraph,
    Map<String, Object?>? activeSubgoal,
    List<Map<String, Object?>>? candidateOperators,
    Map<String, Object?>? activeOperator,
    Map<String, Object?>? epistemicProfile,
    Map<String, Object?>? predictionLedger,
    Map<String, Object?>? lastRealityResult,
    List<Map<String, Object?>>? backtrackHistory,
    String? promptVersion,
    int? updatedAtMs,
  }) =>
      XiangjiSolverSnapshot(
        problemId: problemId,
        stateVersion: stateVersion ?? this.stateVersion,
        need: need ?? this.need,
        problemFrame: problemFrame ?? this.problemFrame,
        currentState: currentState ?? this.currentState,
        goalState: goalState ?? this.goalState,
        hypotheses: hypotheses ?? this.hypotheses,
        constraints: constraints ?? this.constraints,
        gaps: gaps ?? this.gaps,
        keyGap: keyGap ?? this.keyGap,
        subgoalGraph: subgoalGraph ?? this.subgoalGraph,
        activeSubgoal: activeSubgoal ?? this.activeSubgoal,
        candidateOperators: candidateOperators ?? this.candidateOperators,
        activeOperator: activeOperator ?? this.activeOperator,
        epistemicProfile: epistemicProfile ?? this.epistemicProfile,
        predictionLedger: predictionLedger ?? this.predictionLedger,
        lastRealityResult: lastRealityResult ?? this.lastRealityResult,
        backtrackHistory: backtrackHistory ?? this.backtrackHistory,
        promptVersion: promptVersion ?? this.promptVersion,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, Object?> toDatabaseMap() => <String, Object?>{
        'problem_id': problemId,
        'state_version': stateVersion,
        'need_text': need,
        'problem_frame_json': jsonEncode(problemFrame),
        'current_state_json': jsonEncode(currentState),
        'goal_state_json': jsonEncode(goalState),
        'hypotheses_json': jsonEncode(hypotheses),
        'constraints_json': jsonEncode(constraints),
        'gaps_json': jsonEncode(gaps),
        'key_gap_json': jsonEncode(keyGap),
        'subgoal_graph_json': jsonEncode(subgoalGraph),
        'active_subgoal_json': jsonEncode(activeSubgoal),
        'candidate_operators_json': jsonEncode(candidateOperators),
        'active_operator_json': jsonEncode(activeOperator),
        'epistemic_profile_json': jsonEncode(epistemicProfile),
        'prediction_ledger_json': jsonEncode(predictionLedger),
        'last_reality_result_json': jsonEncode(lastRealityResult),
        'backtrack_history_json': jsonEncode(backtrackHistory),
        'prompt_version': promptVersion,
        'updated_at_ms': updatedAtMs,
      };

  Map<String, Object?> toPromptMap() => <String, Object?>{
        'problem_id': problemId,
        'state_version': stateVersion,
        'need': need,
        'problem_frame': problemFrame,
        'current_state': currentState,
        'goal_state': goalState,
        'hypotheses': hypotheses,
        'constraints': constraints,
        'gaps': gaps,
        'key_gap': keyGap,
        'subgoal_graph': subgoalGraph,
        'active_subgoal': activeSubgoal,
        'candidate_operators': candidateOperators,
        'active_operator': activeOperator,
        'epistemic_profile': epistemicProfile,
        'prediction_ledger': predictionLedger,
        'last_reality_result': lastRealityResult,
        'backtrack_history': backtrackHistory,
        'prompt_version': promptVersion,
      };

  factory XiangjiSolverSnapshot.fromMap(Map<String, Object?> row) =>
      XiangjiSolverSnapshot(
        problemId: (row['problem_id'] ?? '').toString(),
        stateVersion: _asInt(row['state_version']) <= 0
            ? 1
            : _asInt(row['state_version']),
        need: (row['need_text'] ?? '').toString(),
        problemFrame: _jsonMap(row['problem_frame_json']),
        currentState: _jsonMap(row['current_state_json']),
        goalState: _jsonMap(row['goal_state_json']),
        hypotheses: _jsonMaps(row['hypotheses_json']),
        constraints: _jsonMaps(row['constraints_json']),
        gaps: _jsonMaps(row['gaps_json']),
        keyGap: _jsonMap(row['key_gap_json']),
        subgoalGraph: _jsonMap(row['subgoal_graph_json']),
        activeSubgoal: _jsonMap(row['active_subgoal_json']),
        candidateOperators: _jsonMaps(row['candidate_operators_json']),
        activeOperator: _jsonMap(row['active_operator_json']),
        epistemicProfile: _jsonMap(row['epistemic_profile_json']),
        predictionLedger: _jsonMap(row['prediction_ledger_json']),
        lastRealityResult: _jsonMap(row['last_reality_result_json']),
        backtrackHistory: _jsonMaps(row['backtrack_history_json']),
        promptVersion: (row['prompt_version'] ?? 'rev5.2').toString(),
        updatedAtMs: _asInt(row['updated_at_ms']),
      );
}

/// A concise, auditable record of a signature method changing (or explicitly
/// retaining) the solver state. It intentionally stores no private reasoning.
class XiangjiMethodEvent {
  const XiangjiMethodEvent({
    required this.id,
    required this.methodId,
    required this.problemId,
    required this.stateVersion,
    required this.trigger,
    required this.operationSummary,
    required this.dataMutations,
    required this.decisionEffect,
    required this.userVisibleSummary,
    required this.realityTest,
    this.sourceRefs = const <String>[],
    this.beforeStateRefs = const <String, Object?>{},
    this.afterStateRefs = const <String, Object?>{},
    this.learningLink = '',
    this.changedState = true,
    this.retainedStateReason = '',
    this.userVisible = true,
    this.createdAtMs = 0,
  });

  final String id;
  final String methodId;
  final String problemId;
  final int stateVersion;
  final String trigger;
  final List<String> sourceRefs;
  final Map<String, Object?> beforeStateRefs;
  final String operationSummary;
  final List<Map<String, Object?>> dataMutations;
  final Map<String, Object?> afterStateRefs;
  final String decisionEffect;
  final String userVisibleSummary;
  final String realityTest;
  final String learningLink;
  final bool changedState;
  final String retainedStateReason;
  final bool userVisible;
  final int createdAtMs;

  XiangjiMethodKnowledge get knowledge => XiangjiMethodCatalog.forId(methodId);

  /// Exact Rev.5.2 capability name. This is intentionally distinct from the
  /// original concept and from the user-facing effect of this specific turn.
  String get capabilityName => knowledge.displayName;

  String get methodLabel => knowledge.displayName;
  String get methodTradition => knowledge.domain;

  /// Backwards-compatible getter retained for persisted Rev.5.2 events. Some
  /// capabilities are product solver concepts rather than Schopenhauer terms,
  /// so callers should present this as `sourceConcept`, not as a philosopher
  /// attribution.
  String get schopenhauerConcept => knowledge.sourceConcept;
  String get sourceConcept => knowledge.sourceConcept;
  String get philosophyPrinciple => knowledge.principle;
  String get transferQuestion => knowledge.transferQuestion;
  String get philosophySource => knowledge.sourceLocator;
  List<String> get relatedRuleIds => knowledge.relatedRuleIds;

  Map<String, Object?> toDatabaseMap() => <String, Object?>{
        'id': id,
        'method_id': methodId,
        'problem_id': problemId,
        'state_version': stateVersion,
        'trigger_text': trigger,
        'source_refs_json': jsonEncode(sourceRefs),
        'before_state_refs_json': jsonEncode(beforeStateRefs),
        'operation_summary': operationSummary,
        'data_mutations_json': jsonEncode(dataMutations),
        'after_state_refs_json': jsonEncode(afterStateRefs),
        'decision_effect': decisionEffect,
        'user_visible_summary': userVisibleSummary,
        'reality_test': realityTest,
        'learning_link': learningLink,
        'changed_state': changedState ? 1 : 0,
        'retained_state_reason': retainedStateReason,
        'user_visible': userVisible ? 1 : 0,
        'created_at_ms': createdAtMs,
      };

  Map<String, Object?> toPromptMap() => <String, Object?>{
        'method_event_id': id,
        'method_id': methodId,
        'problem_id': problemId,
        'state_version': stateVersion,
        'trigger': trigger,
        'source_refs': sourceRefs,
        'before_state': beforeStateRefs,
        'cognitive_operation_summary': operationSummary,
        'data_mutations': dataMutations,
        'after_state': afterStateRefs,
        'decision_effect': decisionEffect,
        'user_visible_summary': userVisibleSummary,
        'reality_test': realityTest,
        if (learningLink.isNotEmpty) 'learning_link': learningLink,
      };

  factory XiangjiMethodEvent.fromMap(Map<String, Object?> row) =>
      XiangjiMethodEvent(
        id: (row['id'] ?? '').toString(),
        methodId: (row['method_id'] ?? '').toString(),
        problemId: (row['problem_id'] ?? '').toString(),
        stateVersion: _asInt(row['state_version']),
        trigger: (row['trigger_text'] ?? '').toString(),
        sourceRefs: _jsonStrings(row['source_refs_json']),
        beforeStateRefs: _jsonMap(row['before_state_refs_json']),
        operationSummary: (row['operation_summary'] ?? '').toString(),
        dataMutations: _jsonMaps(row['data_mutations_json']),
        afterStateRefs: _jsonMap(row['after_state_refs_json']),
        decisionEffect: (row['decision_effect'] ?? '').toString(),
        userVisibleSummary: (row['user_visible_summary'] ?? '').toString(),
        realityTest: (row['reality_test'] ?? '').toString(),
        learningLink: (row['learning_link'] ?? '').toString(),
        changedState: _asBool(row['changed_state']),
        retainedStateReason: (row['retained_state_reason'] ?? '').toString(),
        userVisible: _asBool(row['user_visible']),
        createdAtMs: _asInt(row['created_at_ms']),
      );
}

class XiangjiKnowledgeSourceRecord {
  const XiangjiKnowledgeSourceRecord({
    required this.id,
    required this.layer,
    required this.kind,
    required this.title,
    required this.status,
    this.version = '1',
    this.contentHash = '',
    this.localUri = '',
    this.mime = '',
    this.parseStatus = 'LOCAL_ONLY',
    this.indexStatus = 'LOCAL_ONLY',
    this.sensitivity = 'normal',
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;
  final XiangjiKnowledgeLayer layer;
  final String kind;
  final String title;
  final XiangjiKnowledgeSourceStatus status;
  final String version;
  final String contentHash;
  final String localUri;
  final String mime;
  final String parseStatus;
  final String indexStatus;
  final String sensitivity;
  final int createdAtMs;
  final int updatedAtMs;

  factory XiangjiKnowledgeSourceRecord.fromMap(Map<String, Object?> row) {
    final layer = (row['layer'] ?? 'K3').toString().toLowerCase();
    final status = (row['status'] ?? 'active').toString().toLowerCase();
    return XiangjiKnowledgeSourceRecord(
      id: (row['id'] ?? '').toString(),
      layer: XiangjiKnowledgeLayer.values.firstWhere(
        (value) => value.name == layer,
        orElse: () => XiangjiKnowledgeLayer.k3,
      ),
      kind: (row['kind'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      status: XiangjiKnowledgeSourceStatus.values.firstWhere(
        (value) => value.name == status,
        orElse: () => XiangjiKnowledgeSourceStatus.active,
      ),
      version: (row['version'] ?? '1').toString(),
      contentHash: (row['content_hash'] ?? '').toString(),
      localUri: (row['local_uri'] ?? '').toString(),
      mime: (row['mime'] ?? '').toString(),
      parseStatus: (row['parse_status'] ?? 'LOCAL_ONLY').toString(),
      indexStatus: (row['index_status'] ?? 'LOCAL_ONLY').toString(),
      sensitivity: (row['sensitivity'] ?? 'normal').toString(),
      createdAtMs: _asInt(row['created_at_ms']),
      updatedAtMs: _asInt(row['updated_at_ms']),
    );
  }
}

class XiangjiProviderCapability {
  const XiangjiProviderCapability({
    required this.providerId,
    required this.label,
    required this.supportsPersistentFile,
    required this.supportsStore,
    required this.supportsDelete,
    required this.supportsReuse,
    required this.supportsCitations,
    required this.supportsStructuredOutput,
    required this.retentionPolicy,
    required this.indexingMode,
    this.maxFileSize = 0,
    this.maxTotalStorage = 0,
    this.verified = false,
    this.notes = '',
  });

  final String providerId;
  final String label;
  final bool supportsPersistentFile;
  final bool supportsStore;
  final bool supportsDelete;
  final bool supportsReuse;
  final bool supportsCitations;
  final bool supportsStructuredOutput;
  final int maxFileSize;
  final int maxTotalStorage;
  final String retentionPolicy;
  final String indexingMode;
  final bool verified;
  final String notes;

  bool get mayClaimPersistentStorage =>
      supportsPersistentFile && supportsReuse && verified;

  Map<String, Object?> toMap() => <String, Object?>{
        'provider_id': providerId,
        'label': label,
        'persistent_file': supportsPersistentFile ? 1 : 0,
        'store': supportsStore ? 1 : 0,
        'supports_delete': supportsDelete ? 1 : 0,
        'reuse': supportsReuse ? 1 : 0,
        'citation': supportsCitations ? 1 : 0,
        'structured_output': supportsStructuredOutput ? 1 : 0,
        'max_file_size': maxFileSize,
        'max_total_storage': maxTotalStorage,
        'retention_policy': retentionPolicy,
        'indexing_mode': indexingMode,
        'verified': verified ? 1 : 0,
        'notes': notes,
      };

  factory XiangjiProviderCapability.fromMap(Map<String, Object?> row) =>
      XiangjiProviderCapability(
        providerId: (row['provider_id'] ?? '').toString(),
        label: (row['label'] ?? '').toString(),
        supportsPersistentFile: _asBool(row['persistent_file']),
        supportsStore: _asBool(row['store']),
        supportsDelete: _asBool(row['supports_delete']),
        supportsReuse: _asBool(row['reuse']),
        supportsCitations: _asBool(row['citation']),
        supportsStructuredOutput: _asBool(row['structured_output']),
        maxFileSize: _asInt(row['max_file_size']),
        maxTotalStorage: _asInt(row['max_total_storage']),
        retentionPolicy: (row['retention_policy'] ?? '').toString(),
        indexingMode: (row['indexing_mode'] ?? '').toString(),
        verified: _asBool(row['verified']),
        notes: (row['notes'] ?? '').toString(),
      );
}

class XiangjiProviderFileRecord {
  const XiangjiProviderFileRecord({
    required this.id,
    required this.providerId,
    required this.sourceId,
    required this.state,
    this.remoteFileId = '',
    this.remoteStoreId = '',
    this.retentionInfo = '',
    this.lastError = '',
    this.uploadedAtMs = 0,
    this.expiresAtMs = 0,
  });

  final String id;
  final String providerId;
  final String sourceId;
  final String remoteFileId;
  final String remoteStoreId;
  final XiangjiProviderFileState state;
  final String retentionInfo;
  final String lastError;
  final int uploadedAtMs;
  final int expiresAtMs;

  bool get isExpired =>
      expiresAtMs > 0 && expiresAtMs <= DateTime.now().millisecondsSinceEpoch;

  bool get usable =>
      state == XiangjiProviderFileState.ready &&
      !isExpired &&
      remoteFileId.isNotEmpty;

  factory XiangjiProviderFileRecord.fromMap(Map<String, Object?> row) =>
      XiangjiProviderFileRecord(
        id: (row['id'] ?? '').toString(),
        providerId: (row['provider_id'] ?? '').toString(),
        sourceId: (row['source_id'] ?? '').toString(),
        remoteFileId: (row['remote_file_id'] ?? '').toString(),
        remoteStoreId: (row['remote_store_id'] ?? '').toString(),
        state: parseProviderFileState(row['status']),
        retentionInfo: (row['retention_info'] ?? '').toString(),
        lastError: (row['last_error'] ?? '').toString(),
        uploadedAtMs: _asInt(row['uploaded_at_ms']),
        expiresAtMs: _asInt(row['expires_at_ms']),
      );
}

class XiangjiRetrievalTrace {
  const XiangjiRetrievalTrace({
    required this.id,
    required this.requestId,
    required this.objectRefs,
    required this.routePlan,
    required this.sourcesUsed,
    required this.rejectedSources,
    required this.conflicts,
    required this.ruleIds,
    required this.debtIds,
    required this.state,
    this.createdAtMs = 0,
  });

  final String id;
  final String requestId;
  final List<String> objectRefs;
  final List<String> routePlan;
  final List<String> sourcesUsed;
  final List<String> rejectedSources;
  final List<String> conflicts;
  final List<String> ruleIds;
  final List<String> debtIds;
  final XiangjiRetrievalSessionState state;
  final int createdAtMs;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'request_id': requestId,
        'object_refs_json': jsonEncode(objectRefs),
        'route_plan_json': jsonEncode(routePlan),
        'sources_used_json': jsonEncode(sourcesUsed),
        'rejected_sources_json': jsonEncode(rejectedSources),
        'conflicts_json': jsonEncode(conflicts),
        'rule_ids_json': jsonEncode(ruleIds),
        'debt_ids_json': jsonEncode(debtIds),
        'state': state.wire,
        'created_at_ms': createdAtMs,
      };

  factory XiangjiRetrievalTrace.fromMap(Map<String, Object?> row) =>
      XiangjiRetrievalTrace(
        id: (row['id'] ?? '').toString(),
        requestId: (row['request_id'] ?? '').toString(),
        objectRefs: _jsonStrings(row['object_refs_json']),
        routePlan: _jsonStrings(row['route_plan_json']),
        sourcesUsed: _jsonStrings(row['sources_used_json']),
        rejectedSources: _jsonStrings(row['rejected_sources_json']),
        conflicts: _jsonStrings(row['conflicts_json']),
        ruleIds: _jsonStrings(row['rule_ids_json']),
        debtIds: _jsonStrings(row['debt_ids_json']),
        state: _enumByWire(
          XiangjiRetrievalSessionState.values,
          row['state'],
          (value) => value.wire,
          XiangjiRetrievalSessionState.created,
        ),
        createdAtMs: _asInt(row['created_at_ms']),
      );
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1';
}

Map<String, Object?> _jsonMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  try {
    final decoded = jsonDecode(value?.toString() ?? '');
    if (decoded is Map) {
      return decoded.map((key, item) => MapEntry(key.toString(), item));
    }
  } catch (_) {}
  return const <String, Object?>{};
}

List<String> _jsonStrings(Object? value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  try {
    final decoded = jsonDecode(value?.toString() ?? '');
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList();
    }
  } catch (_) {}
  return const <String>[];
}

List<Map<String, Object?>> _jsonMaps(Object? value) {
  Object? decoded = value;
  if (value is! List) {
    try {
      decoded = jsonDecode(value?.toString() ?? '');
    } catch (_) {
      return const <Map<String, Object?>>[];
    }
  }
  if (decoded is! List) return const <Map<String, Object?>>[];
  return decoded
      .whereType<Map>()
      .map(
        (item) => item.map(
          (key, entry) => MapEntry(key.toString(), entry),
        ),
      )
      .toList();
}
