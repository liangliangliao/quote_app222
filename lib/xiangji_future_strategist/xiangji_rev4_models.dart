import 'dart:convert';

/// Rev.4 classifies every utterance before deciding whether it belongs to the
/// current problem. A message is never treated as a new problem merely because
/// it arrived in a new turn.
enum XiangjiInputType {
  need,
  newFact,
  experience,
  correction,
  actionFeedback,
  newProblem,
}

extension XiangjiInputTypeX on XiangjiInputType {
  String get wire => switch (this) {
        XiangjiInputType.need => 'NEED',
        XiangjiInputType.newFact => 'NEW_FACT',
        XiangjiInputType.experience => 'EXPERIENCE',
        XiangjiInputType.correction => 'CORRECTION',
        XiangjiInputType.actionFeedback => 'ACTION_FEEDBACK',
        XiangjiInputType.newProblem => 'NEW_PROBLEM',
      };

  String get label => switch (this) {
        XiangjiInputType.need => '需要或目标',
        XiangjiInputType.newFact => '新的现实事实',
        XiangjiInputType.experience => '真实体验',
        XiangjiInputType.correction => '纠正军师理解',
        XiangjiInputType.actionFeedback => '行动后的现实反馈',
        XiangjiInputType.newProblem => '独立的新问题',
      };
}

class XiangjiInputClassification {
  const XiangjiInputClassification({
    required this.type,
    required this.updateExistingProblem,
    required this.reason,
    this.targetProblemId = '',
    this.confidence = 1,
  });

  final XiangjiInputType type;
  final bool updateExistingProblem;
  final String targetProblemId;
  final String reason;
  final double confidence;

  Map<String, Object?> toMap() => <String, Object?>{
        'input_type': type.wire,
        'updates_existing_problem': updateExistingProblem,
        'target_problem_id': targetProblemId,
        'reason': reason,
        'confidence': confidence,
      };
}

/// The Rev.2/Rev.3 state remains available for backwards compatibility. This
/// lifecycle is persisted on immutable ProblemStateVersion rows and follows
/// the Rev.4 persistent solver vocabulary exactly.
enum XiangjiPersistentProblemState {
  captured,
  modeling,
  judging,
  framing,
  solving,
  testing,
  scouting,
  actionReady,
  executing,
  realityReturn,
  verifying,
  continuing,
  backtrack,
  reframe,
  resolved,
  archived,
}

extension XiangjiPersistentProblemStateX on XiangjiPersistentProblemState {
  String get wire => switch (this) {
        XiangjiPersistentProblemState.captured => 'CAPTURED',
        XiangjiPersistentProblemState.modeling => 'MODELING',
        XiangjiPersistentProblemState.judging => 'JUDGING',
        XiangjiPersistentProblemState.framing => 'FRAMING',
        XiangjiPersistentProblemState.solving => 'SOLVING',
        XiangjiPersistentProblemState.testing => 'TESTING',
        XiangjiPersistentProblemState.scouting => 'SCOUTING',
        XiangjiPersistentProblemState.actionReady => 'ACTION_READY',
        XiangjiPersistentProblemState.executing => 'EXECUTING',
        XiangjiPersistentProblemState.realityReturn => 'REALITY_RETURN',
        XiangjiPersistentProblemState.verifying => 'VERIFYING',
        XiangjiPersistentProblemState.continuing => 'CONTINUE',
        XiangjiPersistentProblemState.backtrack => 'BACKTRACK',
        XiangjiPersistentProblemState.reframe => 'REFRAME',
        XiangjiPersistentProblemState.resolved => 'RESOLVED',
        XiangjiPersistentProblemState.archived => 'ARCHIVED',
      };

  String get label => switch (this) {
        XiangjiPersistentProblemState.captured => '已保留原始需要',
        XiangjiPersistentProblemState.modeling => '正在整理现实与体验',
        XiangjiPersistentProblemState.judging => '正在比较同异与边界',
        XiangjiPersistentProblemState.framing => '正在确认真正要解的题',
        XiangjiPersistentProblemState.solving => '正在持续求解',
        XiangjiPersistentProblemState.testing => '正在检验候选解释',
        XiangjiPersistentProblemState.scouting => '正在用现实侦察关键未知',
        XiangjiPersistentProblemState.actionReady => '下一步已准备好',
        XiangjiPersistentProblemState.executing => '正在行动',
        XiangjiPersistentProblemState.realityReturn => '现实已经回来',
        XiangjiPersistentProblemState.verifying => '正在对照预测与现实',
        XiangjiPersistentProblemState.continuing => '继续解同一道题',
        XiangjiPersistentProblemState.backtrack => '正在回溯最早错误层',
        XiangjiPersistentProblemState.reframe => '现实要求重构问题',
        XiangjiPersistentProblemState.resolved => '已满足阶段性判据',
        XiangjiPersistentProblemState.archived => '已归档',
      };
}

enum XiangjiHypothesisStatus {
  proposed,
  testDesigned,
  executing,
  resultAvailable,
  supported,
  weakened,
  contradicted,
  indeterminate,
}

extension XiangjiHypothesisStatusX on XiangjiHypothesisStatus {
  String get wire => switch (this) {
        XiangjiHypothesisStatus.proposed => 'PROPOSED',
        XiangjiHypothesisStatus.testDesigned => 'TEST_DESIGNED',
        XiangjiHypothesisStatus.executing => 'EXECUTING',
        XiangjiHypothesisStatus.resultAvailable => 'RESULT_AVAILABLE',
        XiangjiHypothesisStatus.supported => 'SUPPORTED',
        XiangjiHypothesisStatus.weakened => 'WEAKENED',
        XiangjiHypothesisStatus.contradicted => 'CONTRADICTED',
        XiangjiHypothesisStatus.indeterminate => 'INDETERMINATE',
      };

  String get label => switch (this) {
        XiangjiHypothesisStatus.proposed => '待验证',
        XiangjiHypothesisStatus.testDesigned => '已设计区分实验',
        XiangjiHypothesisStatus.executing => '实验进行中',
        XiangjiHypothesisStatus.resultAvailable => '已有结果，待核对',
        XiangjiHypothesisStatus.supported => '得到现实支持',
        XiangjiHypothesisStatus.weakened => '被现实削弱',
        XiangjiHypothesisStatus.contradicted => '与现实冲突',
        XiangjiHypothesisStatus.indeterminate => '结果仍不足以判断',
      };
}

enum XiangjiConceptConflictState {
  mismatchDetected,
  underReview,
  refined,
  superseded,
  retainedWithScope,
}

extension XiangjiConceptConflictStateX on XiangjiConceptConflictState {
  String get wire => switch (this) {
        XiangjiConceptConflictState.mismatchDetected => 'MISMATCH_DETECTED',
        XiangjiConceptConflictState.underReview => 'UNDER_REVIEW',
        XiangjiConceptConflictState.refined => 'REFINED',
        XiangjiConceptConflictState.superseded => 'SUPERSEDED',
        XiangjiConceptConflictState.retainedWithScope => 'RETAINED_WITH_SCOPE',
      };
}

enum XiangjiCognitivePresentation {
  experienceInterpretation,
  modelHumility,
  competingCauses,
  caseComparison,
  groundingExplanation,
  conceptBoundary,
  realityConflict,
  systematicityAudit,
  premiseAudit,
  actionMechanism,
  learningMoment,
  actThenLearn,
}

extension XiangjiCognitivePresentationX on XiangjiCognitivePresentation {
  String get wire => switch (this) {
        XiangjiCognitivePresentation.experienceInterpretation =>
          'EXPERIENCE_INTERPRETATION',
        XiangjiCognitivePresentation.modelHumility => 'MODEL_HUMILITY',
        XiangjiCognitivePresentation.competingCauses => 'COMPETING_CAUSES',
        XiangjiCognitivePresentation.caseComparison => 'CASE_COMPARISON',
        XiangjiCognitivePresentation.groundingExplanation =>
          'GROUNDING_EXPLANATION',
        XiangjiCognitivePresentation.conceptBoundary => 'CONCEPT_BOUNDARY',
        XiangjiCognitivePresentation.realityConflict => 'REALITY_CONFLICT',
        XiangjiCognitivePresentation.systematicityAudit =>
          'SYSTEMATICITY_AUDIT',
        XiangjiCognitivePresentation.premiseAudit => 'PREMISE_AUDIT',
        XiangjiCognitivePresentation.actionMechanism => 'ACTION_MECHANISM',
        XiangjiCognitivePresentation.learningMoment => 'LEARNING_MOMENT',
        XiangjiCognitivePresentation.actThenLearn => 'ACT_THEN_LEARN',
      };

  String get label => switch (this) {
        XiangjiCognitivePresentation.experienceInterpretation => '发生的事与解释',
        XiangjiCognitivePresentation.modelHumility => '当前理解可以被修订',
        XiangjiCognitivePresentation.competingCauses => '还可能是什么原因？',
        XiangjiCognitivePresentation.caseComparison => '这次真的一样吗？',
        XiangjiCognitivePresentation.groundingExplanation => '为什么军师这么判断？',
        XiangjiCognitivePresentation.conceptBoundary => '这个概念解释到哪里？',
        XiangjiCognitivePresentation.realityConflict => '现实正在挑战旧解释',
        XiangjiCognitivePresentation.systematicityAudit => '完整不等于确定',
        XiangjiCognitivePresentation.premiseAudit => '逻辑成立不等于现实已证明',
        XiangjiCognitivePresentation.actionMechanism => '为什么是这一步？',
        XiangjiCognitivePresentation.learningMoment => '这次认识怎样改变了？',
        XiangjiCognitivePresentation.actThenLearn => '现在先行动，再用现实继续解题',
      };
}

class XiangjiCognitiveExperienceDraft {
  const XiangjiCognitiveExperienceDraft({
    required this.id,
    required this.trigger,
    required this.sckRuleIds,
    required this.headline,
    required this.userMessage,
    required this.presentation,
    this.details = const <String, String>{},
    this.methodText = '',
    this.transferPrompt = '',
    this.linkedClaims = const <String>[],
    this.createdAtMs = 0,
  });

  final String id;
  final String trigger;
  final List<String> sckRuleIds;
  final String headline;
  final String userMessage;
  final XiangjiCognitivePresentation presentation;
  final Map<String, String> details;
  final String methodText;
  final String transferPrompt;
  final List<String> linkedClaims;
  final int createdAtMs;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'trigger': trigger,
        'sck_rule_ids_json': jsonEncode(sckRuleIds),
        'headline': headline,
        'user_message': userMessage,
        'presentation_type': presentation.wire,
        'details_json': jsonEncode(details),
        'method_text': methodText,
        'transfer_prompt': transferPrompt,
        'linked_claims_json': jsonEncode(linkedClaims),
        'created_at_ms': createdAtMs,
      };

  factory XiangjiCognitiveExperienceDraft.fromMap(
    Map<String, Object?> row,
  ) {
    final wire = (row['presentation_type'] ?? '').toString();
    return XiangjiCognitiveExperienceDraft(
      id: (row['id'] ?? '').toString(),
      trigger: (row['trigger'] ?? '').toString(),
      sckRuleIds: _decodeStringList(row['sck_rule_ids_json']),
      headline: (row['headline'] ?? '').toString(),
      userMessage: (row['user_message'] ?? '').toString(),
      presentation: XiangjiCognitivePresentation.values.firstWhere(
        (value) => value.wire == wire,
        orElse: () => XiangjiCognitivePresentation.modelHumility,
      ),
      details: _decodeStringMap(row['details_json']),
      methodText: (row['method_text'] ?? '').toString(),
      transferPrompt: (row['transfer_prompt'] ?? '').toString(),
      linkedClaims: _decodeStringList(row['linked_claims_json']),
      createdAtMs: _asInt(row['created_at_ms']),
    );
  }
}

class XiangjiProblemProgress {
  const XiangjiProblemProgress({
    required this.problemId,
    required this.state,
    this.version = 0,
    this.resolvedItems = const <String>[],
    this.currentFocus = '',
    this.keyUnknowns = const <String>[],
    this.currentExperiment = '',
    this.nextVerification = '',
    this.hypotheses = const <Map<String, Object?>>[],
    this.attempts = const <Map<String, Object?>>[],
    this.backtracks = const <Map<String, Object?>>[],
  });

  final String problemId;
  final XiangjiPersistentProblemState state;
  final int version;
  final List<String> resolvedItems;
  final String currentFocus;
  final List<String> keyUnknowns;
  final String currentExperiment;
  final String nextVerification;
  final List<Map<String, Object?>> hypotheses;
  final List<Map<String, Object?>> attempts;
  final List<Map<String, Object?>> backtracks;
}

List<String> _decodeStringList(Object? raw) {
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! List) return const <String>[];
    return decoded
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  } catch (_) {
    return const <String>[];
  }
}

Map<String, String> _decodeStringMap(Object? raw) {
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) return const <String, String>{};
    return decoded.map(
      (key, dynamic value) => MapEntry(key.toString(), value.toString()),
    );
  } catch (_) {
    return const <String, String>{};
  }
}

int _asInt(Object? value) =>
    value is int ? value : int.tryParse((value ?? '').toString()) ?? 0;
