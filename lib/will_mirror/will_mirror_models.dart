import 'dart:convert';

enum WillMirrorEvidenceLevel { a, aCandidate, b, c }

extension WillMirrorEvidenceLevelX on WillMirrorEvidenceLevel {
  String get value => switch (this) {
        WillMirrorEvidenceLevel.a => 'A',
        WillMirrorEvidenceLevel.aCandidate => 'A-candidate',
        WillMirrorEvidenceLevel.b => 'B',
        WillMirrorEvidenceLevel.c => 'C',
      };

  String get label => switch (this) {
        WillMirrorEvidenceLevel.a => 'A · 一手证据',
        WillMirrorEvidenceLevel.aCandidate => 'A-candidate · 待逐段核验',
        WillMirrorEvidenceLevel.b => 'B · 研究证据',
        WillMirrorEvidenceLevel.c => 'C · 产品推导',
      };
}

WillMirrorEvidenceLevel parseWillMirrorEvidenceLevel(Object? value) {
  return switch ((value ?? '').toString()) {
    'A' => WillMirrorEvidenceLevel.a,
    'A-candidate' => WillMirrorEvidenceLevel.aCandidate,
    'B' => WillMirrorEvidenceLevel.b,
    _ => WillMirrorEvidenceLevel.c,
  };
}

enum WillMirrorRelation { supports, limits, contradicts, operationalizes }

extension WillMirrorRelationX on WillMirrorRelation {
  String get value => name;

  String get label => switch (this) {
        WillMirrorRelation.supports => '支持',
        WillMirrorRelation.limits => '情境限制',
        WillMirrorRelation.contradicts => '反证',
        WillMirrorRelation.operationalizes => '操作化依据',
      };
}

WillMirrorRelation parseWillMirrorRelation(Object? value) {
  return WillMirrorRelation.values.firstWhere(
    (item) => item.name == value,
    orElse: () => WillMirrorRelation.supports,
  );
}

enum WillMirrorEvidenceType { realMe, action, pain, cost, counterexample }

extension WillMirrorEvidenceTypeX on WillMirrorEvidenceType {
  String get value => switch (this) {
        WillMirrorEvidenceType.realMe => 'real_me',
        WillMirrorEvidenceType.action => 'action',
        WillMirrorEvidenceType.pain => 'pain',
        WillMirrorEvidenceType.cost => 'cost',
        WillMirrorEvidenceType.counterexample => 'counterexample',
      };

  String get label => switch (this) {
        WillMirrorEvidenceType.realMe => 'Real-Me · 最像自己',
        WillMirrorEvidenceType.action => '行动镜 · 实际选择',
        WillMirrorEvidenceType.pain => '受阻/痛苦事件',
        WillMirrorEvidenceType.cost => '真实代价',
        WillMirrorEvidenceType.counterexample => '主动反证',
      };

  String get prompt => switch (this) {
        WillMirrorEvidenceType.realMe => '刚才什么时候最像自己？',
        WillMirrorEvidenceType.action => '你最终真正选择了什么？',
        WillMirrorEvidenceType.pain => '具体是哪一种受阻，而不只是“很痛苦”？',
        WillMirrorEvidenceType.cost => '你为了它真实付出了什么？',
        WillMirrorEvidenceType.counterexample => '哪条经历反驳或限制了当前模型？',
      };
}

WillMirrorEvidenceType parseWillMirrorEvidenceType(Object? value) {
  final raw = (value ?? '').toString();
  return WillMirrorEvidenceType.values.firstWhere(
    (item) => item.value == raw,
    orElse: () => WillMirrorEvidenceType.action,
  );
}

enum WillMirrorProbeType {
  noAudience,
  noPraiseComparison,
  opposition,
  oppositionRemoval,
  substitution,
  satisfactionResidue,
  mps,
}

extension WillMirrorProbeTypeX on WillMirrorProbeType {
  String get value => switch (this) {
        WillMirrorProbeType.noAudience => 'no_audience',
        WillMirrorProbeType.noPraiseComparison => 'no_praise_comparison',
        WillMirrorProbeType.opposition => 'opposition',
        WillMirrorProbeType.oppositionRemoval => 'opposition_removal',
        WillMirrorProbeType.substitution => 'substitution',
        WillMirrorProbeType.satisfactionResidue => 'satisfaction_residue',
        WillMirrorProbeType.mps => 'mps',
      };

  String get label => switch (this) {
        WillMirrorProbeType.noAudience => '无人知晓',
        WillMirrorProbeType.noPraiseComparison => '去掉赞美与比较',
        WillMirrorProbeType.opposition => '遭到反对/阻止',
        WillMirrorProbeType.oppositionRemoval => '反对突然消失',
        WillMirrorProbeType.substitution => '功能替代',
        WillMirrorProbeType.satisfactionResidue => '满足后的残差',
        WillMirrorProbeType.mps => '意义·愉悦·优势',
      };

  String questionFor(String goal) => switch (this) {
        WillMirrorProbeType.noAudience =>
          '如果没有任何人知道你实现了“$goal”，欲望会从多少变到多少？',
        WillMirrorProbeType.noPraiseComparison =>
          '去掉掌声、声望、比较和证明以后，你仍会多想要“$goal”？',
        WillMirrorProbeType.opposition =>
          '如果重要的人强烈反对或真正阻止，你对“$goal”的欲望怎样变化？',
        WillMirrorProbeType.oppositionRemoval =>
          '如果明天所有反对者都改为支持，你对“$goal”的欲望还剩多少？',
        WillMirrorProbeType.substitution =>
          '如果不用“$goal”也能得到它承担的主要功能，你还想要多少？',
        WillMirrorProbeType.satisfactionResidue =>
          '假设“$goal”已经完全得到，安静一周以后仍然缺什么？',
        WillMirrorProbeType.mps =>
          '这条路在意义、愉悦、优势和“最像自己”四方面分别留下什么？',
      };
}

WillMirrorProbeType parseWillMirrorProbeType(Object? value) {
  final raw = (value ?? '').toString();
  return WillMirrorProbeType.values.firstWhere(
    (item) => item.value == raw,
    orElse: () => WillMirrorProbeType.noAudience,
  );
}

enum WillMirrorConfidenceBand {
  insufficient,
  low,
  medium,
  high,
  highWithLimits,
}

extension WillMirrorConfidenceBandX on WillMirrorConfidenceBand {
  String get value => switch (this) {
        WillMirrorConfidenceBand.insufficient => 'insufficient',
        WillMirrorConfidenceBand.low => 'low',
        WillMirrorConfidenceBand.medium => 'medium',
        WillMirrorConfidenceBand.high => 'high',
        WillMirrorConfidenceBand.highWithLimits => 'high_with_limits',
      };

  String get label => switch (this) {
        WillMirrorConfidenceBand.insufficient => '证据不足',
        WillMirrorConfidenceBand.low => '低可信',
        WillMirrorConfidenceBand.medium => '中可信',
        WillMirrorConfidenceBand.high => '高可信',
        WillMirrorConfidenceBand.highWithLimits => '高可信但有重要限制',
      };
}

WillMirrorConfidenceBand parseWillMirrorConfidenceBand(Object? value) {
  final raw = (value ?? '').toString();
  return WillMirrorConfidenceBand.values.firstWhere(
    (item) => item.value == raw,
    orElse: () => WillMirrorConfidenceBand.insufficient,
  );
}

enum WillMirrorHypothesisType { motive, stableWant, empiricalCharacter }

extension WillMirrorHypothesisTypeX on WillMirrorHypothesisType {
  String get value => switch (this) {
        WillMirrorHypothesisType.motive => 'motive',
        WillMirrorHypothesisType.stableWant => 'stable_want',
        WillMirrorHypothesisType.empiricalCharacter => 'empirical_character',
      };

  String get label => switch (this) {
        WillMirrorHypothesisType.motive => '具体动机候选',
        WillMirrorHypothesisType.stableWant => '稳定意欲候选',
        WillMirrorHypothesisType.empiricalCharacter => '经验性格候选',
      };
}

WillMirrorHypothesisType parseWillMirrorHypothesisType(Object? value) {
  final raw = (value ?? '').toString();
  return WillMirrorHypothesisType.values.firstWhere(
    (item) => item.value == raw,
    orElse: () => WillMirrorHypothesisType.motive,
  );
}

enum WillMirrorExperimentStatus { planned, active, completed, abandoned }

extension WillMirrorExperimentStatusX on WillMirrorExperimentStatus {
  String get value => name;

  String get label => switch (this) {
        WillMirrorExperimentStatus.planned => '待开始',
        WillMirrorExperimentStatus.active => '验证中',
        WillMirrorExperimentStatus.completed => '已完成',
        WillMirrorExperimentStatus.abandoned => '已停止',
      };
}

WillMirrorExperimentStatus parseWillMirrorExperimentStatus(Object? value) {
  return WillMirrorExperimentStatus.values.firstWhere(
    (item) => item.name == value,
    orElse: () => WillMirrorExperimentStatus.planned,
  );
}

class WillMirrorGoal {
  const WillMirrorGoal({
    required this.id,
    required this.text,
    required this.domain,
    required this.baselineDesire,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String text;
  final String domain;
  final int baselineDesire;
  final String status;
  final int createdAt;
  final int updatedAt;

  WillMirrorGoal copyWith({
    String? text,
    String? domain,
    int? baselineDesire,
    String? status,
    int? updatedAt,
  }) {
    return WillMirrorGoal(
      id: id,
      text: text ?? this.text,
      domain: domain ?? this.domain,
      baselineDesire: baselineDesire ?? this.baselineDesire,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'domain': domain,
        'baseline_desire': baselineDesire,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class WillMirrorWhyNode {
  const WillMirrorWhyNode({
    required this.id,
    required this.goalId,
    required this.parentId,
    required this.nodeType,
    required this.text,
    required this.depth,
    required this.createdAt,
  });

  final String id;
  final String goalId;
  final String? parentId;
  final String nodeType;
  final String text;
  final int depth;
  final int createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal_id': goalId,
        'parent_id': parentId,
        'node_type': nodeType,
        'text': text,
        'depth': depth,
        'created_at': createdAt,
      };
}

class WillMirrorLifeEvidence {
  const WillMirrorLifeEvidence({
    required this.id,
    required this.goalId,
    required this.type,
    required this.title,
    required this.note,
    required this.lifeStage,
    required this.domain,
    required this.intensity,
    required this.duration,
    required this.costLevel,
    required this.audiencePresent,
    required this.externallyRequested,
    required this.rewardPresent,
    required this.energyBefore,
    required this.energyAfter,
    required this.repeatWish,
    required this.occurredAt,
    required this.createdAt,
  });

  final String id;
  final String goalId;
  final WillMirrorEvidenceType type;
  final String title;
  final String note;
  final String lifeStage;
  final String domain;
  final int intensity;
  final int duration;
  final int costLevel;
  final bool audiencePresent;
  final bool externallyRequested;
  final bool rewardPresent;
  final int energyBefore;
  final int energyAfter;
  final int repeatWish;
  final int occurredAt;
  final int createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal_id': goalId,
        'type': type.value,
        'title': title,
        'note': note,
        'life_stage': lifeStage,
        'domain': domain,
        'intensity': intensity,
        'duration': duration,
        'cost_level': costLevel,
        'audience_present': audiencePresent,
        'externally_requested': externallyRequested,
        'reward_present': rewardPresent,
        'energy_before': energyBefore,
        'energy_after': energyAfter,
        'repeat_wish': repeatWish,
        'occurred_at': occurredAt,
        'created_at': createdAt,
      };
}

class WillMirrorProbe {
  const WillMirrorProbe({
    required this.id,
    required this.goalId,
    required this.nodeId,
    required this.type,
    required this.baseline,
    required this.after,
    required this.answer,
    required this.createdAt,
  });

  final String id;
  final String goalId;
  final String? nodeId;
  final WillMirrorProbeType type;
  final int baseline;
  final int after;
  final String answer;
  final int createdAt;

  int get delta => after - baseline;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal_id': goalId,
        'node_id': nodeId,
        'type': type.value,
        'baseline': baseline,
        'after': after,
        'answer': answer,
        'created_at': createdAt,
      };
}

class WillMirrorHypothesis {
  const WillMirrorHypothesis({
    required this.id,
    required this.goalId,
    required this.label,
    required this.type,
    required this.status,
    required this.confidenceBand,
    required this.explanation,
    required this.counterSearchCompleted,
    required this.counterSearchNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String goalId;
  final String label;
  final WillMirrorHypothesisType type;
  final String status;
  final WillMirrorConfidenceBand confidenceBand;
  final String explanation;
  final bool counterSearchCompleted;
  final String counterSearchNote;
  final int createdAt;
  final int updatedAt;

  WillMirrorHypothesis copyWith({
    String? label,
    WillMirrorHypothesisType? type,
    String? status,
    WillMirrorConfidenceBand? confidenceBand,
    String? explanation,
    bool? counterSearchCompleted,
    String? counterSearchNote,
    int? updatedAt,
  }) {
    return WillMirrorHypothesis(
      id: id,
      goalId: goalId,
      label: label ?? this.label,
      type: type ?? this.type,
      status: status ?? this.status,
      confidenceBand: confidenceBand ?? this.confidenceBand,
      explanation: explanation ?? this.explanation,
      counterSearchCompleted:
          counterSearchCompleted ?? this.counterSearchCompleted,
      counterSearchNote: counterSearchNote ?? this.counterSearchNote,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal_id': goalId,
        'label': label,
        'type': type.value,
        'status': status,
        'confidence_band': confidenceBand.value,
        'explanation': explanation,
        'counter_search_completed': counterSearchCompleted,
        'counter_search_note': counterSearchNote,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class WillMirrorHypothesisEvidence {
  const WillMirrorHypothesisEvidence({
    required this.hypothesisId,
    required this.evidenceId,
    required this.relation,
    required this.weight,
    required this.contextLimit,
  });

  final String hypothesisId;
  final String evidenceId;
  final WillMirrorRelation relation;
  final double weight;
  final String contextLimit;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hypothesis_id': hypothesisId,
        'evidence_id': evidenceId,
        'relation': relation.value,
        'weight': weight,
        'context_limit': contextLimit,
      };
}

class WillMirrorExperiment {
  const WillMirrorExperiment({
    required this.id,
    required this.hypothesisId,
    required this.title,
    required this.protocol,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String hypothesisId;
  final String title;
  final String protocol;
  final int startAt;
  final int endAt;
  final WillMirrorExperimentStatus status;
  final int createdAt;

  WillMirrorExperiment copyWith({WillMirrorExperimentStatus? status}) {
    return WillMirrorExperiment(
      id: id,
      hypothesisId: hypothesisId,
      title: title,
      protocol: protocol,
      startAt: startAt,
      endAt: endAt,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'hypothesis_id': hypothesisId,
        'title': title,
        'protocol': protocol,
        'start_at': startAt,
        'end_at': endAt,
        'status': status.value,
        'created_at': createdAt,
      };
}

class WillMirrorObservation {
  const WillMirrorObservation({
    required this.id,
    required this.experimentId,
    required this.energy,
    required this.realMe,
    required this.persistence,
    required this.satisfaction,
    required this.note,
    required this.observedAt,
  });

  final String id;
  final String experimentId;
  final int energy;
  final int realMe;
  final int persistence;
  final int satisfaction;
  final String note;
  final int observedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'experiment_id': experimentId,
        'energy': energy,
        'real_me': realMe,
        'persistence': persistence,
        'satisfaction': satisfaction,
        'note': note,
        'observed_at': observedAt,
      };
}

class WillMirrorKnowledgePassage {
  const WillMirrorKnowledgePassage({
    required this.recordId,
    required this.sourceId,
    required this.creator,
    required this.workTitle,
    required this.workPart,
    required this.sectionRef,
    required this.locatorText,
    required this.originalText,
    required this.zhTranslation,
    required this.translationStatus,
    required this.evidenceLevel,
    required this.summary,
    required this.methodologicalImplication,
    required this.productRule,
    required this.misuseBoundary,
    required this.tags,
    required this.modules,
    required this.relations,
    required this.hypothesisCodes,
    required this.sourceFidelity,
    required this.rightsStatus,
    required this.canonicalUrl,
    required this.contentSha256,
  });

  final String recordId;
  final String sourceId;
  final String creator;
  final String workTitle;
  final String workPart;
  final String sectionRef;
  final String locatorText;
  final String originalText;
  final String zhTranslation;
  final String translationStatus;
  final WillMirrorEvidenceLevel evidenceLevel;
  final String summary;
  final String methodologicalImplication;
  final String productRule;
  final String misuseBoundary;
  final List<String> tags;
  final List<String> modules;
  final List<WillMirrorRelation> relations;
  final List<String> hypothesisCodes;
  final double sourceFidelity;
  final String rightsStatus;
  final String canonicalUrl;
  final String contentSha256;

  factory WillMirrorKnowledgePassage.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    final relationValues = strings(json['relations']);
    return WillMirrorKnowledgePassage(
      recordId: (json['record_id'] ?? '').toString(),
      sourceId: (json['source_id'] ?? '').toString(),
      creator: (json['creator'] ?? '').toString(),
      workTitle: (json['work_title'] ?? '').toString(),
      workPart: (json['work_part'] ?? '').toString(),
      sectionRef: (json['section_ref'] ?? '').toString(),
      locatorText: (json['locator_text'] ?? '').toString(),
      originalText: (json['original_text'] ?? '').toString(),
      zhTranslation: (json['zh_translation'] ?? '').toString(),
      translationStatus: (json['translation_status'] ?? '').toString(),
      evidenceLevel: parseWillMirrorEvidenceLevel(json['evidence_level']),
      summary: (json['summary'] ?? '').toString(),
      methodologicalImplication:
          (json['methodological_implication'] ?? '').toString(),
      productRule: (json['product_rule'] ?? '').toString(),
      misuseBoundary: (json['misuse_boundary'] ?? '').toString(),
      tags: strings(json['tags']),
      modules: strings(json['modules']),
      relations: relationValues
          .map(parseWillMirrorRelation)
          .toList(growable: false),
      hypothesisCodes: strings(json['hypothesis_codes']),
      sourceFidelity:
          double.tryParse((json['source_fidelity'] ?? 0).toString()) ?? 0,
      rightsStatus: (json['rights_status'] ?? '').toString(),
      canonicalUrl: (json['canonical_url'] ?? '').toString(),
      contentSha256: (json['content_sha256'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'record_id': recordId,
        'source_id': sourceId,
        'creator': creator,
        'work_title': workTitle,
        'work_part': workPart,
        'section_ref': sectionRef,
        'locator_text': locatorText,
        'original_text': originalText,
        'zh_translation': zhTranslation,
        'translation_status': translationStatus,
        'evidence_level': evidenceLevel.value,
        'summary': summary,
        'methodological_implication': methodologicalImplication,
        'product_rule': productRule,
        'misuse_boundary': misuseBoundary,
        'tags': tags,
        'modules': modules,
        'relations': relations.map((item) => item.value).toList(),
        'hypothesis_codes': hypothesisCodes,
        'source_fidelity': sourceFidelity,
        'rights_status': rightsStatus,
        'canonical_url': canonicalUrl,
        'content_sha256': contentSha256,
      };
}

class WillMirrorBoundaryAssessment {
  const WillMirrorBoundaryAssessment({
    required this.shouldContinueWhy,
    required this.status,
    required this.reasons,
    required this.nextAction,
  });

  final bool shouldContinueWhy;
  final String status;
  final List<String> reasons;
  final String nextAction;
}

class WillMirrorSurfaceAnalysis {
  const WillMirrorSurfaceAnalysis({
    required this.object,
    required this.known,
    required this.unknowns,
    required this.nextQuestion,
  });

  final String object;
  final List<String> known;
  final List<String> unknowns;
  final String nextQuestion;
}

class WillMirrorEvidenceMatrix {
  const WillMirrorEvidenceMatrix({
    required this.supports,
    required this.counterevidence,
    required this.limits,
    required this.band,
    required this.internalScore,
    required this.blockedReasons,
    required this.conclusion,
  });

  final List<WillMirrorLifeEvidence> supports;
  final List<WillMirrorLifeEvidence> counterevidence;
  final List<WillMirrorLifeEvidence> limits;
  final WillMirrorConfidenceBand band;
  final double internalScore;
  final List<String> blockedReasons;
  final String conclusion;

  bool get canPublishCharacterClaim => blockedReasons.isEmpty;
}

class WillMirrorRetrievalBundle {
  const WillMirrorRetrievalBundle({
    required this.support,
    required this.counter,
    required this.boundary,
  });

  final List<WillMirrorKnowledgePassage> support;
  final List<WillMirrorKnowledgePassage> counter;
  final List<WillMirrorKnowledgePassage> boundary;

  List<WillMirrorKnowledgePassage> get all {
    final byId = <String, WillMirrorKnowledgePassage>{};
    for (final item in <WillMirrorKnowledgePassage>[
      ...support,
      ...counter,
      ...boundary,
    ]) {
      byId[item.recordId] = item;
    }
    return byId.values.toList(growable: false);
  }
}

class WillMirrorGroundedInference {
  const WillMirrorGroundedInference({
    required this.conclusion,
    required this.supportEvidenceIds,
    required this.counterEvidenceIds,
    required this.kbPassageIds,
    required this.band,
    required this.uncertainty,
    required this.nextAction,
    required this.guardrail,
    required this.provider,
    required this.model,
  });

  final String conclusion;
  final List<String> supportEvidenceIds;
  final List<String> counterEvidenceIds;
  final List<String> kbPassageIds;
  final WillMirrorConfidenceBand band;
  final List<String> uncertainty;
  final String nextAction;
  final String guardrail;
  final String provider;
  final String model;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'conclusion': conclusion,
        'support_evidence_ids': supportEvidenceIds,
        'counter_evidence_ids': counterEvidenceIds,
        'kb_passage_ids': kbPassageIds,
        'confidence_band': band.value,
        'uncertainty': uncertainty,
        'next_action': nextAction,
        'guardrail': guardrail,
        'provider': provider,
        'model': model,
      };

  String encode() => jsonEncode(toJson());
}
