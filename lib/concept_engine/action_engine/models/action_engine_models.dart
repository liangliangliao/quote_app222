import 'dart:convert';

class ActionConcept {
  final String concept;
  final String shortDescription;
  final List<String> dimensions;
  final bool generatedByAi;
  final String generationNote;
  final List<ActionDirection> directions;

  const ActionConcept({
    required this.concept,
    required this.shortDescription,
    required this.directions,
    this.dimensions = const [],
    this.generatedByAi = false,
    this.generationNote = '',
  });

  factory ActionConcept.fromJson(Map<String, dynamic> json) {
    return ActionConcept(
      concept: (json['concept'] ?? '').toString(),
      shortDescription: (json['short_description'] ?? json['description'] ?? '').toString(),
      dimensions: ((json['dimensions'] as List?) ?? const []).map((e) => e.toString()).toList(),
      generatedByAi: json['generated_by_ai'] == true || json['generatedByAi'] == true,
      generationNote: (json['generation_note'] ?? json['generationNote'] ?? '').toString(),
      directions: ((json['directions'] as List?) ?? const [])
          .map((e) => ActionDirection.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'concept': concept,
        'short_description': shortDescription,
        'dimensions': dimensions,
        'generated_by_ai': generatedByAi,
        'generation_note': generationNote,
        'directions': directions.map((e) => e.toJson()).toList(),
      };
}

class ActionDirection {
  final String id;
  final String title;
  final String description;
  final String realityMeaning;
  final List<String> observableChanges;
  final String experienceFact;
  final String factDoneSignal;
  final List<ActionModule> modules;
  final bool needsExpansion;
  final int previewModuleCount;
  final int previewStepCount;

  const ActionDirection({
    required this.id,
    required this.title,
    required this.description,
    required this.modules,
    this.realityMeaning = '',
    this.observableChanges = const [],
    this.experienceFact = '',
    this.factDoneSignal = '',
    this.needsExpansion = false,
    this.previewModuleCount = 0,
    this.previewStepCount = 0,
  });

  int get stepCount => modules.fold(0, (sum, m) => sum + m.steps.length);
  int get displayModuleCount => modules.isNotEmpty ? modules.length : previewModuleCount;
  int get displayStepCount => stepCount > 0 ? stepCount : previewStepCount;

  ActionDirection copyWith({
    String? id,
    String? title,
    String? description,
    List<ActionModule>? modules,
    bool? needsExpansion,
    int? previewModuleCount,
    int? previewStepCount,
  }) {
    return ActionDirection(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      modules: modules ?? this.modules,
      needsExpansion: needsExpansion ?? this.needsExpansion,
      previewModuleCount: previewModuleCount ?? this.previewModuleCount,
      previewStepCount: previewStepCount ?? this.previewStepCount,
    );
  }

  factory ActionDirection.fromJson(Map<String, dynamic> json) {
    return ActionDirection(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      modules: ((json['modules'] as List?) ?? const [])
          .map((e) => ActionModule.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      needsExpansion: json['needs_expansion'] == true || json['needsExpansion'] == true,
      previewModuleCount: int.tryParse((json['preview_module_count'] ?? json['previewModuleCount'] ?? 0).toString()) ?? 0,
      previewStepCount: int.tryParse((json['preview_step_count'] ?? json['previewStepCount'] ?? 0).toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'modules': modules.map((e) => e.toJson()).toList(),
        'needs_expansion': needsExpansion,
        'preview_module_count': previewModuleCount,
        'preview_step_count': previewStepCount,
      };
}

class ActionModule {
  final String id;
  final String title;
  final String realityMeaning;
  final List<String> observableChanges;
  final String experienceFact;
  final String factDoneSignal;
  final List<ActionStep> steps;

  const ActionModule({
    required this.id,
    required this.title,
    required this.steps,
    this.realityMeaning = '',
    this.observableChanges = const [],
    this.experienceFact = '',
    this.factDoneSignal = '',
  });

  factory ActionModule.fromJson(Map<String, dynamic> json) {
    return ActionModule(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      realityMeaning: (json['reality_meaning'] ?? json['realityMeaning'] ?? '').toString(),
      observableChanges: ((json['observable_changes'] as List?) ?? (json['observableChanges'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      experienceFact: (json['experience_fact'] ?? json['experienceFact'] ?? '').toString(),
      factDoneSignal: (json['fact_done_signal'] ?? json['factDoneSignal'] ?? '').toString(),
      steps: ((json['steps'] as List?) ?? const [])
          .map((e) => ActionStep.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'reality_meaning': realityMeaning,
        'observable_changes': observableChanges,
        'experience_fact': experienceFact,
        'fact_done_signal': factDoneSignal,
        'steps': steps.map((e) => e.toJson()).toList(),
      };
}

class ActionStep {
  final String id;
  final String text;
  final bool isCustom;
  final String? minimalVersion;
  final List<String> tags;
  final String importance; // normal / important / critical
  final String? linkedCabinType; // delayReport / boundaryExpression / selfDisciplineStart
  final String? directInstruction; // 用户可以直接照做的一句话指令
  final String? executionHint; // 怎么做/按什么顺序做
  final String? doneSignal; // 做到什么算完成
  final String? example; // 更直观的一句示例

  const ActionStep({
    required this.id,
    required this.text,
    this.isCustom = false,
    this.minimalVersion,
    this.tags = const [],
    this.importance = 'normal',
    this.linkedCabinType,
    this.directInstruction,
    this.executionHint,
    this.doneSignal,
    this.example,
  });

  bool get shouldSuggestCabin => linkedCabinType != null && linkedCabinType!.isNotEmpty && importance != 'normal';

  ActionStep copyWith({
    String? id,
    String? text,
    bool? isCustom,
    String? minimalVersion,
    List<String>? tags,
    String? importance,
    String? linkedCabinType,
    String? directInstruction,
    String? executionHint,
    String? doneSignal,
    String? example,
  }) {
    return ActionStep(
      id: id ?? this.id,
      text: text ?? this.text,
      isCustom: isCustom ?? this.isCustom,
      minimalVersion: minimalVersion ?? this.minimalVersion,
      tags: tags ?? this.tags,
      importance: importance ?? this.importance,
      linkedCabinType: linkedCabinType ?? this.linkedCabinType,
      directInstruction: directInstruction ?? this.directInstruction,
      executionHint: executionHint ?? this.executionHint,
      doneSignal: doneSignal ?? this.doneSignal,
      example: example ?? this.example,
    );
  }

  factory ActionStep.fromJson(Map<String, dynamic> json) {
    return ActionStep(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      isCustom: json['isCustom'] == true || json['is_custom'] == true,
      minimalVersion: json['minimalVersion']?.toString() ?? json['minimal_version']?.toString(),
      tags: ((json['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
      importance: (json['importance'] ?? 'normal').toString(),
      linkedCabinType: json['linkedCabinType']?.toString() ?? json['linked_cabin_type']?.toString(),
      directInstruction: json['directInstruction']?.toString() ?? json['direct_instruction']?.toString(),
      executionHint: json['executionHint']?.toString() ?? json['execution_hint']?.toString(),
      doneSignal: json['doneSignal']?.toString() ?? json['done_signal']?.toString(),
      example: json['example']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isCustom': isCustom,
        'minimalVersion': minimalVersion,
        'tags': tags,
        'importance': importance,
        'linkedCabinType': linkedCabinType,
        'directInstruction': directInstruction,
        'executionHint': executionHint,
        'doneSignal': doneSignal,
        'example': example,
      };
}

class ActionPlan {
  final String planId;
  final String concept;
  final String goal;
  final String domain;
  final String title;
  final String? sourceDirectionId;
  final String? sourceDirectionTitle;
  final String provider;
  final String model;
  final String transportMode;
  final List<ActionStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ActionPlan({
    required this.planId,
    required this.concept,
    required this.goal,
    required this.domain,
    required this.title,
    required this.provider,
    required this.model,
    required this.transportMode,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
    this.sourceDirectionId,
    this.sourceDirectionTitle,
  });

  factory ActionPlan.fromMap(Map<String, dynamic> map) {
    final raw = (map['plan_json'] ?? '{}').toString();
    Map<String, dynamic> decoded = const {};
    try {
      decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}
    return ActionPlan(
      planId: (map['plan_id'] ?? '').toString(),
      concept: (map['concept'] ?? decoded['concept'] ?? '').toString(),
      goal: (map['goal'] ?? decoded['goal'] ?? '').toString(),
      domain: (map['domain'] ?? decoded['domain'] ?? '').toString(),
      title: (map['title'] ?? decoded['title'] ?? '').toString(),
      sourceDirectionId: (map['source_direction_id'] ?? decoded['source_direction_id'])?.toString(),
      sourceDirectionTitle: (map['source_direction_title'] ?? decoded['source_direction_title'])?.toString(),
      provider: (map['provider'] ?? decoded['provider'] ?? 'deepseek').toString(),
      model: (map['model'] ?? decoded['model'] ?? '').toString(),
      transportMode: (map['transport_mode'] ?? decoded['transport_mode'] ?? 'direct').toString(),
      steps: ((decoded['steps'] as List?) ?? const [])
          .map((e) => ActionStep.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toPlanJson() => {
        'plan_id': planId,
        'concept': concept,
        'goal': goal,
        'domain': domain,
        'title': title,
        'source_direction_id': sourceDirectionId,
        'source_direction_title': sourceDirectionTitle,
        'provider': provider,
        'model': model,
        'transport_mode': transportMode,
        'steps': steps.map((e) => e.toJson()).toList(),
      };
}

class ActionExecution {
  final String executionId;
  final String planId;
  final String concept;
  final String status;
  final int totalSteps;
  final int completedSteps;
  final int frictionCount;
  final Map<String, dynamic> feedback;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ActionExecution({
    required this.executionId,
    required this.planId,
    required this.concept,
    required this.status,
    required this.totalSteps,
    required this.completedSteps,
    required this.frictionCount,
    required this.feedback,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActionExecution.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> feedback = const {};
    try {
      feedback = Map<String, dynamic>.from(jsonDecode((map['feedback_json'] ?? '{}').toString()) as Map);
    } catch (_) {}
    return ActionExecution(
      executionId: (map['execution_id'] ?? '').toString(),
      planId: (map['plan_id'] ?? '').toString(),
      concept: (map['concept'] ?? '').toString(),
      status: (map['status'] ?? 'partial').toString(),
      totalSteps: (map['total_steps'] as int?) ?? 0,
      completedSteps: (map['completed_steps'] as int?) ?? 0,
      frictionCount: (map['friction_count'] as int?) ?? 0,
      feedback: feedback,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class ActionStepExecution {
  final String stepId;
  final int stepOrder;
  final String stepText;
  final bool completed;
  final bool encounteredFriction;
  final String? frictionType;
  final String? fallbackAction;
  final String? userNote;

  const ActionStepExecution({
    required this.stepId,
    required this.stepOrder,
    required this.stepText,
    required this.completed,
    required this.encounteredFriction,
    this.frictionType,
    this.fallbackAction,
    this.userNote,
  });

  factory ActionStepExecution.fromMap(Map<String, dynamic> map) => ActionStepExecution(
        stepId: (map['step_id'] ?? '').toString(),
        stepOrder: (map['step_order'] as int?) ?? 0,
        stepText: (map['step_text'] ?? '').toString(),
        completed: (map['completed'] as int? ?? 0) == 1,
        encounteredFriction: (map['encountered_friction'] as int? ?? 0) == 1,
        frictionType: map['friction_type']?.toString(),
        fallbackAction: map['fallback_action']?.toString(),
        userNote: map['user_note']?.toString(),
      );
}

class ActionGrowthSnapshot {
  final String concept;
  final int totalPlans;
  final int totalExecutions;
  final int completedExecutions;
  final int totalFrictions;
  final String mostCommonDirection;
  final String mostCommonFrictionType;
  final DateTime updatedAt;

  const ActionGrowthSnapshot({
    required this.concept,
    required this.totalPlans,
    required this.totalExecutions,
    required this.completedExecutions,
    required this.totalFrictions,
    required this.mostCommonDirection,
    required this.mostCommonFrictionType,
    required this.updatedAt,
  });

  double get completionRate => totalExecutions == 0 ? 0 : completedExecutions / totalExecutions;

  factory ActionGrowthSnapshot.fromMap(Map<String, dynamic> map) => ActionGrowthSnapshot(
        concept: (map['concept'] ?? '').toString(),
        totalPlans: (map['total_plans'] as int?) ?? 0,
        totalExecutions: (map['total_executions'] as int?) ?? 0,
        completedExecutions: (map['completed_executions'] as int?) ?? 0,
        totalFrictions: (map['total_frictions'] as int?) ?? 0,
        mostCommonDirection: (map['most_common_direction'] ?? '').toString(),
        mostCommonFrictionType: (map['most_common_friction_type'] ?? '').toString(),
        updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? DateTime.now(),
      );
}


class ActionWorldReward {
  final int xpGained;
  final int levelAfter;
  final int streakAfter;
  final String zoneId;
  final int anomalyLevelAfter;
  final List<String> unlockedAchievements;
  final List<String> unlockedZones;
  final List<String> worldEvents;

  const ActionWorldReward({
    required this.xpGained,
    required this.levelAfter,
    required this.streakAfter,
    required this.zoneId,
    required this.anomalyLevelAfter,
    required this.unlockedAchievements,
    required this.unlockedZones,
    required this.worldEvents,
  });
}

enum FrictionType { notStarting, fearExpression, stepTooLarge, delayLoop, unclearNext }

extension FrictionTypeX on FrictionType {
  String get label {
    switch (this) {
      case FrictionType.notStarting:
        return '不想开始';
      case FrictionType.fearExpression:
        return '害怕表达';
      case FrictionType.stepTooLarge:
        return '这一步太大';
      case FrictionType.delayLoop:
        return '想继续拖延';
      case FrictionType.unclearNext:
        return '不知道下一步';
    }
  }
}
