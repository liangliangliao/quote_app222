import 'dart:convert';

enum GrowthModule { belief, goal, action, failure, review, change }

extension GrowthModuleX on GrowthModule {
  String get key => name.toUpperCase();
  String get label => switch (this) {
        GrowthModule.belief => '信念',
        GrowthModule.goal => '目标',
        GrowthModule.action => '行动',
        GrowthModule.failure => '失败与完美主义',
        GrowthModule.review => '复盘',
        GrowthModule.change => '改变',
      };
  String get loop => switch (this) {
        GrowthModule.belief => '我如何解释现实',
        GrowthModule.goal => '我要验证什么方向',
        GrowthModule.action => '我现在进入现实的哪一步',
        GrowthModule.failure => '结果提供了什么信息',
        GrowthModule.review => '预测与实际差在哪里',
        GrowthModule.change => '下一轮只改变什么',
      };

  static GrowthModule parse(Object? value) {
    final text = (value ?? '').toString().toLowerCase();
    return GrowthModule.values.firstWhere(
      (item) => item.name == text,
      orElse: () => GrowthModule.action,
    );
  }
}

class EvidenceSourceLocator {
  const EvidenceSourceLocator({
    required this.document,
    required this.pages,
    this.lectures = const <int>[],
    this.note = '',
  });
  final String document;
  final List<int> pages;
  final List<int> lectures;
  final String note;

  Map<String, Object?> toJson() => <String, Object?>{
        'document': document,
        'physical_pages': pages,
        'lectures': lectures,
        'note': note,
      };

  String get display {
    final p = pages.map((e) => 'p.$e').join(', ');
    final l = lectures.isEmpty ? '' : ' · Lecture ${lectures.join('/')}';
    return '$document $p$l';
  }
}

class EvidenceKNode {
  const EvidenceKNode({
    required this.id,
    required this.module,
    required this.sourceClass,
    required this.title,
    required this.claim,
    required this.mechanism,
    required this.triggers,
    required this.contraSignals,
    required this.prerequisites,
    required this.operators,
    required this.boundaries,
    required this.nextNodes,
    required this.evidenceStrength,
    required this.displayExcerpt,
    required this.locator,
    this.version = 1,
  });
  final String id;
  final GrowthModule module;
  final String sourceClass;
  final String title;
  final String claim;
  final String mechanism;
  final List<String> triggers;
  final List<String> contraSignals;
  final List<String> prerequisites;
  final List<String> operators;
  final List<String> boundaries;
  final List<String> nextNodes;
  final String evidenceStrength;
  final String displayExcerpt;
  final EvidenceSourceLocator locator;
  final int version;

  bool get isTal => sourceClass == 'K_TAL';
  bool get isExtension1 => sourceClass == 'K_EXT1';
  String get embeddingText => <String>[
        title,
        claim,
        mechanism,
        ...triggers,
        ...operators,
      ].join(' ');

  Map<String, Object?> toJson() => <String, Object?>{
        'node_id': id,
        'version': version,
        'module': module.key,
        'source_class': sourceClass,
        'title': title,
        'claim': claim,
        'mechanism': mechanism,
        'triggers': triggers,
        'contra_signals': contraSignals,
        'prerequisites': prerequisites,
        'operators': operators,
        'risk_boundary': boundaries,
        'next_nodes': nextNodes,
        'evidence_strength': evidenceStrength,
        'display_excerpt': displayExcerpt,
        'source_locator': locator.toJson(),
      };
}

class RoutedNode {
  const RoutedNode({required this.node, required this.score, required this.reason});
  final EvidenceKNode node;
  final double score;
  final String reason;
}

class EvidenceRouteResult {
  const EvidenceRouteResult({
    required this.rawInput,
    required this.facts,
    required this.primaryModule,
    required this.secondaryModules,
    required this.candidates,
    required this.selectedNodes,
    required this.requiredChecks,
    required this.status,
    required this.riskGate,
    required this.inference,
    required this.confidence,
    required this.operator,
    required this.actionInstruction,
    required this.completionDefinition,
    required this.reviewTrigger,
    required this.evidenceLevel,
    required this.alternatives,
    this.missingFacts = const <String>[],
  });
  final String rawInput;
  final List<String> facts;
  final GrowthModule primaryModule;
  final List<GrowthModule> secondaryModules;
  final List<RoutedNode> candidates;
  final List<EvidenceKNode> selectedNodes;
  final List<String> requiredChecks;
  final String status;
  final String riskGate;
  final String inference;
  final double confidence;
  final String operator;
  final String actionInstruction;
  final String completionDefinition;
  final String reviewTrigger;
  final String evidenceLevel;
  final List<String> alternatives;
  final List<String> missingFacts;

  bool get canAct => status == 'READY_FOR_ACTION' && riskGate == 'PASS';

  EvidenceRouteResult copyWith({
    List<EvidenceKNode>? selectedNodes,
    String? status,
    String? riskGate,
    String? inference,
    double? confidence,
    String? operator,
    String? actionInstruction,
    String? completionDefinition,
    String? reviewTrigger,
    String? evidenceLevel,
    List<String>? alternatives,
  }) =>
      EvidenceRouteResult(
        rawInput: rawInput,
        facts: facts,
        primaryModule: primaryModule,
        secondaryModules: secondaryModules,
        candidates: candidates,
        selectedNodes: selectedNodes ?? this.selectedNodes,
        requiredChecks: requiredChecks,
        status: status ?? this.status,
        riskGate: riskGate ?? this.riskGate,
        inference: inference ?? this.inference,
        confidence: confidence ?? this.confidence,
        operator: operator ?? this.operator,
        actionInstruction: actionInstruction ?? this.actionInstruction,
        completionDefinition: completionDefinition ?? this.completionDefinition,
        reviewTrigger: reviewTrigger ?? this.reviewTrigger,
        evidenceLevel: evidenceLevel ?? this.evidenceLevel,
        alternatives: alternatives ?? this.alternatives,
        missingFacts: missingFacts,
      );
}

class RealityTrial {
  const RealityTrial({
    required this.id,
    required this.status,
    required this.rawInput,
    required this.facts,
    required this.primaryModule,
    required this.secondaryModules,
    required this.nodeIds,
    required this.evidenceLevel,
    required this.inference,
    required this.operator,
    required this.actionInstruction,
    required this.completionDefinition,
    required this.prediction,
    required this.probability,
    required this.reviewAtMs,
    required this.riskGate,
    required this.stretchLevel,
    required this.reversible,
    required this.nextRoundPreserved,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.didAction,
    this.actualOutcome = '',
    this.unexpected = '',
    this.failureClass = '',
    this.learning = '',
    this.ruleUpdate = '',
    this.decision = '',
    this.nextAction = '',
    this.kbVersion = '3.5',
    this.promptVersion = 'eg-p1.0',
  });
  final String id;
  final String status;
  final String rawInput;
  final List<String> facts;
  final GrowthModule primaryModule;
  final List<GrowthModule> secondaryModules;
  final List<String> nodeIds;
  final String evidenceLevel;
  final String inference;
  final String operator;
  final String actionInstruction;
  final String completionDefinition;
  final String prediction;
  final double probability;
  final int reviewAtMs;
  final String riskGate;
  final String stretchLevel;
  final bool reversible;
  final bool nextRoundPreserved;
  final int createdAtMs;
  final int updatedAtMs;
  final bool? didAction;
  final String actualOutcome;
  final String unexpected;
  final String failureClass;
  final String learning;
  final String ruleUpdate;
  final String decision;
  final String nextAction;
  final String kbVersion;
  final String promptVersion;

  bool get isClosed => status == 'DECIDED' || status == 'ARCHIVED';

  RealityTrial copyWith({
    String? status,
    bool? didAction,
    String? actualOutcome,
    String? unexpected,
    String? failureClass,
    String? learning,
    String? ruleUpdate,
    String? decision,
    String? nextAction,
    int? updatedAtMs,
  }) =>
      RealityTrial(
        id: id,
        status: status ?? this.status,
        rawInput: rawInput,
        facts: facts,
        primaryModule: primaryModule,
        secondaryModules: secondaryModules,
        nodeIds: nodeIds,
        evidenceLevel: evidenceLevel,
        inference: inference,
        operator: operator,
        actionInstruction: actionInstruction,
        completionDefinition: completionDefinition,
        prediction: prediction,
        probability: probability,
        reviewAtMs: reviewAtMs,
        riskGate: riskGate,
        stretchLevel: stretchLevel,
        reversible: reversible,
        nextRoundPreserved: nextRoundPreserved,
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        didAction: didAction ?? this.didAction,
        actualOutcome: actualOutcome ?? this.actualOutcome,
        unexpected: unexpected ?? this.unexpected,
        failureClass: failureClass ?? this.failureClass,
        learning: learning ?? this.learning,
        ruleUpdate: ruleUpdate ?? this.ruleUpdate,
        decision: decision ?? this.decision,
        nextAction: nextAction ?? this.nextAction,
        kbVersion: kbVersion,
        promptVersion: promptVersion,
      );

  Map<String, Object?> toRow() => <String, Object?>{
        'trial_id': id,
        'status': status,
        'raw_input': rawInput,
        'facts_json': jsonEncode(facts),
        'primary_module': primaryModule.name,
        'secondary_modules_json': jsonEncode(secondaryModules.map((e) => e.name).toList()),
        'node_ids_json': jsonEncode(nodeIds),
        'evidence_level': evidenceLevel,
        'ai_inference': inference,
        'operator': operator,
        'action_instruction': actionInstruction,
        'completion_definition': completionDefinition,
        'prediction': prediction,
        'probability': probability,
        'review_at_ms': reviewAtMs,
        'risk_gate': riskGate,
        'stretch_level': stretchLevel,
        'reversible': reversible ? 1 : 0,
        'next_round_preserved': nextRoundPreserved ? 1 : 0,
        'did_action': didAction == null ? null : (didAction! ? 1 : 0),
        'actual_outcome': actualOutcome,
        'unexpected': unexpected,
        'failure_class': failureClass,
        'learning': learning,
        'rule_update': ruleUpdate,
        'decision': decision,
        'next_action': nextAction,
        'kb_version': kbVersion,
        'prompt_version': promptVersion,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory RealityTrial.fromRow(Map<String, Object?> row) {
    List<String> list(Object? raw) {
      try {
        final decoded = jsonDecode((raw ?? '[]').toString());
        return decoded is List ? decoded.map((e) => e.toString()).toList() : <String>[];
      } catch (_) {
        return <String>[];
      }
    }
    return RealityTrial(
      id: (row['trial_id'] ?? '').toString(),
      status: (row['status'] ?? 'DRAFT').toString(),
      rawInput: (row['raw_input'] ?? '').toString(),
      facts: list(row['facts_json']),
      primaryModule: GrowthModuleX.parse(row['primary_module']),
      secondaryModules: list(row['secondary_modules_json']).map(GrowthModuleX.parse).toList(),
      nodeIds: list(row['node_ids_json']),
      evidenceLevel: (row['evidence_level'] ?? 'E1').toString(),
      inference: (row['ai_inference'] ?? '').toString(),
      operator: (row['operator'] ?? '').toString(),
      actionInstruction: (row['action_instruction'] ?? '').toString(),
      completionDefinition: (row['completion_definition'] ?? '').toString(),
      prediction: (row['prediction'] ?? '').toString(),
      probability: (row['probability'] as num?)?.toDouble() ?? .5,
      reviewAtMs: (row['review_at_ms'] as num?)?.toInt() ?? 0,
      riskGate: (row['risk_gate'] ?? 'PASS').toString(),
      stretchLevel: (row['stretch_level'] ?? 'STRETCH').toString(),
      reversible: row['reversible'] == 1,
      nextRoundPreserved: row['next_round_preserved'] == 1,
      createdAtMs: (row['created_at_ms'] as num?)?.toInt() ?? 0,
      updatedAtMs: (row['updated_at_ms'] as num?)?.toInt() ?? 0,
      didAction: row['did_action'] == null ? null : row['did_action'] == 1,
      actualOutcome: (row['actual_outcome'] ?? '').toString(),
      unexpected: (row['unexpected'] ?? '').toString(),
      failureClass: (row['failure_class'] ?? '').toString(),
      learning: (row['learning'] ?? '').toString(),
      ruleUpdate: (row['rule_update'] ?? '').toString(),
      decision: (row['decision'] ?? '').toString(),
      nextAction: (row['next_action'] ?? '').toString(),
      kbVersion: (row['kb_version'] ?? '3.5').toString(),
      promptVersion: (row['prompt_version'] ?? 'eg-p1.0').toString(),
    );
  }
}

class TrialReviewResult {
  const TrialReviewResult({
    required this.predictionOriginal,
    required this.actualFacts,
    required this.predictionError,
    required this.failureClass,
    required this.learning,
    required this.ruleUpdate,
    required this.decision,
    required this.nextChangeOneVariable,
    required this.knowledgeNodeIds,
  });
  final String predictionOriginal;
  final List<String> actualFacts;
  final String predictionError;
  final String failureClass;
  final String learning;
  final String ruleUpdate;
  final String decision;
  final String nextChangeOneVariable;
  final List<String> knowledgeNodeIds;
}

class EvidenceSummary {
  const EvidenceSummary({
    required this.learnedNodes,
    required this.activatedNodes,
    required this.startedTrials,
    required this.completedActions,
    required this.failureSamples,
    required this.strategyChanges,
    required this.exits,
    required this.moduleCounts,
    required this.topNodeIds,
  });
  final int learnedNodes;
  final int activatedNodes;
  final int startedTrials;
  final int completedActions;
  final int failureSamples;
  final int strategyChanges;
  final int exits;
  final Map<GrowthModule, int> moduleCounts;
  final List<String> topNodeIds;
  double get activationRate => learnedNodes == 0 ? 0 : activatedNodes / learnedNodes;
  double get actionRate => startedTrials == 0 ? 0 : completedActions / startedTrials;
}
