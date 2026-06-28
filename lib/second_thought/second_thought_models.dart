import 'dart:convert';

/// 独立模块：第二念 / 矛盾心理与价值行动引擎。
///
/// 说明：本文件不复用、不继承任何已有成长模块的数据模型；只依赖 Dart 标准库。
/// 模块边界通过 second_thought_* 前缀的数据表与模型名保持清晰。
class SecondThoughtProfile {
  final List<String> coreValues;
  final String identityVision;
  final String relationshipContext;
  final String longTermDirection;
  final List<String> changeLanguageBank;
  final int updatedAtMs;

  const SecondThoughtProfile({
    this.coreValues = const <String>[],
    this.identityVision = '',
    this.relationshipContext = '',
    this.longTermDirection = '',
    this.changeLanguageBank = const <String>[],
    this.updatedAtMs = 0,
  });

  SecondThoughtProfile copyWith({
    List<String>? coreValues,
    String? identityVision,
    String? relationshipContext,
    String? longTermDirection,
    List<String>? changeLanguageBank,
    int? updatedAtMs,
  }) {
    return SecondThoughtProfile(
      coreValues: coreValues ?? this.coreValues,
      identityVision: identityVision ?? this.identityVision,
      relationshipContext: relationshipContext ?? this.relationshipContext,
      longTermDirection: longTermDirection ?? this.longTermDirection,
      changeLanguageBank: changeLanguageBank ?? this.changeLanguageBank,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'core_values': coreValues,
        'identity_vision': identityVision,
        'relationship_context': relationshipContext,
        'long_term_direction': longTermDirection,
        'change_language_bank': changeLanguageBank,
        'updated_at_ms': updatedAtMs,
      };

  factory SecondThoughtProfile.fromJson(Map<String, dynamic> json) => SecondThoughtProfile(
        coreValues: _stringList(json['core_values']),
        identityVision: (json['identity_vision'] ?? '').toString(),
        relationshipContext: (json['relationship_context'] ?? '').toString(),
        longTermDirection: (json['long_term_direction'] ?? '').toString(),
        changeLanguageBank: _stringList(json['change_language_bank']),
        updatedAtMs: _intValue(json['updated_at_ms']),
      );

  static SecondThoughtProfile fromRaw(String raw) {
    if (raw.trim().isEmpty) return const SecondThoughtProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return SecondThoughtProfile.fromJson(decoded);
      if (decoded is Map) return SecondThoughtProfile.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return const SecondThoughtProfile();
  }

  String encode() => jsonEncode(toJson());
}

class SecondThoughtForce {
  final String content;
  final String source;
  final int strength;

  const SecondThoughtForce({this.content = '', this.source = '', this.strength = 0});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'content': content,
        'source': source,
        'strength': strength,
      };

  factory SecondThoughtForce.fromJson(Map<String, dynamic> json) => SecondThoughtForce(
        content: (json['content'] ?? '').toString(),
        source: (json['source'] ?? '').toString(),
        strength: _intValue(json['strength']).clamp(0, 10).toInt(),
      );
}

class SecondThoughtInnerVoice {
  final String voiceName;
  final String whatItSays;
  final String whatItProtects;
  final String whatItFears;
  final String valueOrNeed;
  final String benefit;
  final String riskIfDominant;
  final int strength;

  const SecondThoughtInnerVoice({
    this.voiceName = '',
    this.whatItSays = '',
    this.whatItProtects = '',
    this.whatItFears = '',
    this.valueOrNeed = '',
    this.benefit = '',
    this.riskIfDominant = '',
    this.strength = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'voice_name': voiceName,
        'what_it_says': whatItSays,
        'what_it_protects': whatItProtects,
        'what_it_fears': whatItFears,
        'value_or_need': valueOrNeed,
        'benefit': benefit,
        'risk_if_dominant': riskIfDominant,
        'strength': strength,
      };

  factory SecondThoughtInnerVoice.fromJson(Map<String, dynamic> json) => SecondThoughtInnerVoice(
        voiceName: (json['voice_name'] ?? json['name'] ?? '').toString(),
        whatItSays: (json['what_it_says'] ?? json['says'] ?? '').toString(),
        whatItProtects: (json['what_it_protects'] ?? json['protects'] ?? '').toString(),
        whatItFears: (json['what_it_fears'] ?? json['fears'] ?? '').toString(),
        valueOrNeed: (json['value_or_need'] ?? json['value'] ?? '').toString(),
        benefit: (json['benefit'] ?? '').toString(),
        riskIfDominant: (json['risk_if_dominant'] ?? json['risk'] ?? '').toString(),
        strength: _intValue(json['strength']).clamp(0, 10).toInt(),
      );
}

class SecondThoughtValueConflict {
  final String valueA;
  final String valueB;
  final String description;

  const SecondThoughtValueConflict({this.valueA = '', this.valueB = '', this.description = ''});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'value_a': valueA,
        'value_b': valueB,
        'conflict_description': description,
      };

  factory SecondThoughtValueConflict.fromJson(Map<String, dynamic> json) => SecondThoughtValueConflict(
        valueA: (json['value_a'] ?? '').toString(),
        valueB: (json['value_b'] ?? '').toString(),
        description: (json['conflict_description'] ?? json['description'] ?? '').toString(),
      );
}

class SecondThoughtDecisionOption {
  final String optionName;
  final List<String> shortTermBenefits;
  final List<String> shortTermCosts;
  final List<String> longTermBenefits;
  final List<String> longTermCosts;
  final String valueAlignment;
  final String reversibility;
  final String riskLevel;
  final String costOfInaction;

  const SecondThoughtDecisionOption({
    this.optionName = '',
    this.shortTermBenefits = const <String>[],
    this.shortTermCosts = const <String>[],
    this.longTermBenefits = const <String>[],
    this.longTermCosts = const <String>[],
    this.valueAlignment = '',
    this.reversibility = '',
    this.riskLevel = '',
    this.costOfInaction = '',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'option_name': optionName,
        'short_term_benefits': shortTermBenefits,
        'short_term_costs': shortTermCosts,
        'long_term_benefits': longTermBenefits,
        'long_term_costs': longTermCosts,
        'value_alignment': valueAlignment,
        'reversibility': reversibility,
        'risk_level': riskLevel,
        'cost_of_inaction': costOfInaction,
      };

  factory SecondThoughtDecisionOption.fromJson(Map<String, dynamic> json) => SecondThoughtDecisionOption(
        optionName: (json['option_name'] ?? '').toString(),
        shortTermBenefits: _stringList(json['short_term_benefits']),
        shortTermCosts: _stringList(json['short_term_costs']),
        longTermBenefits: _stringList(json['long_term_benefits']),
        longTermCosts: _stringList(json['long_term_costs']),
        valueAlignment: (json['value_alignment'] ?? '').toString(),
        reversibility: (json['reversibility'] ?? '').toString(),
        riskLevel: (json['risk_level'] ?? '').toString(),
        costOfInaction: (json['cost_of_inaction'] ?? '').toString(),
      );
}

class SecondThoughtChangeTalk {
  final List<String> desire;
  final List<String> ability;
  final List<String> reasons;
  final List<String> need;
  final List<String> activation;
  final List<String> commitment;
  final List<String> takingSteps;

  const SecondThoughtChangeTalk({
    this.desire = const <String>[],
    this.ability = const <String>[],
    this.reasons = const <String>[],
    this.need = const <String>[],
    this.activation = const <String>[],
    this.commitment = const <String>[],
    this.takingSteps = const <String>[],
  });

  bool get isEmpty => desire.isEmpty && ability.isEmpty && reasons.isEmpty && need.isEmpty && activation.isEmpty && commitment.isEmpty && takingSteps.isEmpty;

  List<String> get all => <String>[...desire, ...ability, ...reasons, ...need, ...activation, ...commitment, ...takingSteps];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'desire': desire,
        'ability': ability,
        'reasons': reasons,
        'need': need,
        'activation': activation,
        'commitment': commitment,
        'taking_steps': takingSteps,
      };

  factory SecondThoughtChangeTalk.fromJson(Map<String, dynamic> json) => SecondThoughtChangeTalk(
        desire: _stringList(json['desire']),
        ability: _stringList(json['ability']),
        reasons: _stringList(json['reasons']),
        need: _stringList(json['need']),
        activation: _stringList(json['activation']),
        commitment: _stringList(json['commitment']),
        takingSteps: _stringList(json['taking_steps']),
      );

  static SecondThoughtChangeTalk fromRaw(String raw) {
    if (raw.trim().isEmpty) return const SecondThoughtChangeTalk();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return SecondThoughtChangeTalk.fromJson(decoded);
      if (decoded is Map) return SecondThoughtChangeTalk.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return const SecondThoughtChangeTalk();
  }

  String encode() => jsonEncode(toJson());
}

class SecondThoughtActionExperiment {
  final String microAction;
  final String startTime;
  final String duration;
  final String successCriteria;
  final List<Map<String, String>> ifThenPlan;
  final String recoveryPlanIfFailed;

  const SecondThoughtActionExperiment({
    this.microAction = '',
    this.startTime = '',
    this.duration = '',
    this.successCriteria = '',
    this.ifThenPlan = const <Map<String, String>>[],
    this.recoveryPlanIfFailed = '',
  });

  bool get hasAction => microAction.trim().isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'micro_action': microAction,
        'start_time': startTime,
        'duration': duration,
        'success_criteria': successCriteria,
        'if_then_plan': ifThenPlan,
        'recovery_plan_if_failed': recoveryPlanIfFailed,
      };

  factory SecondThoughtActionExperiment.fromJson(Map<String, dynamic> json) => SecondThoughtActionExperiment(
        microAction: (json['micro_action'] ?? json['action'] ?? '').toString(),
        startTime: (json['start_time'] ?? '').toString(),
        duration: (json['duration'] ?? '').toString(),
        successCriteria: (json['success_criteria'] ?? '').toString(),
        ifThenPlan: _ifThenList(json['if_then_plan']),
        recoveryPlanIfFailed: (json['recovery_plan_if_failed'] ?? json['recovery_plan'] ?? '').toString(),
      );

  static SecondThoughtActionExperiment fromRaw(String raw) {
    if (raw.trim().isEmpty) return const SecondThoughtActionExperiment();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return SecondThoughtActionExperiment.fromJson(decoded);
      if (decoded is Map) return SecondThoughtActionExperiment.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return const SecondThoughtActionExperiment();
  }

  String encode() => jsonEncode(toJson());
}

class SecondThoughtCaseRecord {
  final int? id;
  final int createdAtMs;
  final int updatedAtMs;
  final String title;
  final String scene;
  final String userInput;
  final String aiResponse;
  final String ambivalenceType;
  final double confidence;
  final String coreConflict;
  final List<SecondThoughtForce> goForces;
  final List<SecondThoughtForce> noForces;
  final List<SecondThoughtInnerVoice> innerCommittee;
  final List<String> possibleValues;
  final List<String> coreValuesToConfirm;
  final List<SecondThoughtValueConflict> valueConflicts;
  final List<String> evidenceQuestions;
  final List<SecondThoughtDecisionOption> options;
  final List<String> thirdWayPossibilities;
  final SecondThoughtChangeTalk changeTalk;
  final SecondThoughtActionExperiment actionExperiment;
  final String status;
  final String riskLevel;

  const SecondThoughtCaseRecord({
    this.id,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.title = '',
    this.scene = 'capture',
    this.userInput = '',
    this.aiResponse = '',
    this.ambivalenceType = '暂不确定',
    this.confidence = 0.0,
    this.coreConflict = '',
    this.goForces = const <SecondThoughtForce>[],
    this.noForces = const <SecondThoughtForce>[],
    this.innerCommittee = const <SecondThoughtInnerVoice>[],
    this.possibleValues = const <String>[],
    this.coreValuesToConfirm = const <String>[],
    this.valueConflicts = const <SecondThoughtValueConflict>[],
    this.evidenceQuestions = const <String>[],
    this.options = const <SecondThoughtDecisionOption>[],
    this.thirdWayPossibilities = const <String>[],
    this.changeTalk = const SecondThoughtChangeTalk(),
    this.actionExperiment = const SecondThoughtActionExperiment(),
    this.status = 'exploring',
    this.riskLevel = 'none',
  });

  SecondThoughtCaseRecord copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    String? title,
    String? scene,
    String? userInput,
    String? aiResponse,
    String? ambivalenceType,
    double? confidence,
    String? coreConflict,
    List<SecondThoughtForce>? goForces,
    List<SecondThoughtForce>? noForces,
    List<SecondThoughtInnerVoice>? innerCommittee,
    List<String>? possibleValues,
    List<String>? coreValuesToConfirm,
    List<SecondThoughtValueConflict>? valueConflicts,
    List<String>? evidenceQuestions,
    List<SecondThoughtDecisionOption>? options,
    List<String>? thirdWayPossibilities,
    SecondThoughtChangeTalk? changeTalk,
    SecondThoughtActionExperiment? actionExperiment,
    String? status,
    String? riskLevel,
  }) {
    return SecondThoughtCaseRecord(
      id: id ?? this.id,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      title: title ?? this.title,
      scene: scene ?? this.scene,
      userInput: userInput ?? this.userInput,
      aiResponse: aiResponse ?? this.aiResponse,
      ambivalenceType: ambivalenceType ?? this.ambivalenceType,
      confidence: confidence ?? this.confidence,
      coreConflict: coreConflict ?? this.coreConflict,
      goForces: goForces ?? this.goForces,
      noForces: noForces ?? this.noForces,
      innerCommittee: innerCommittee ?? this.innerCommittee,
      possibleValues: possibleValues ?? this.possibleValues,
      coreValuesToConfirm: coreValuesToConfirm ?? this.coreValuesToConfirm,
      valueConflicts: valueConflicts ?? this.valueConflicts,
      evidenceQuestions: evidenceQuestions ?? this.evidenceQuestions,
      options: options ?? this.options,
      thirdWayPossibilities: thirdWayPossibilities ?? this.thirdWayPossibilities,
      changeTalk: changeTalk ?? this.changeTalk,
      actionExperiment: actionExperiment ?? this.actionExperiment,
      status: status ?? this.status,
      riskLevel: riskLevel ?? this.riskLevel,
    );
  }

  factory SecondThoughtCaseRecord.fromMap(Map<String, Object?> row) => SecondThoughtCaseRecord(
        id: _nullableInt(row['id']),
        createdAtMs: _intValue(row['created_at_ms']),
        updatedAtMs: _intValue(row['updated_at_ms']),
        title: (row['title'] ?? '').toString(),
        scene: (row['scene'] ?? 'capture').toString(),
        userInput: (row['user_input'] ?? '').toString(),
        aiResponse: (row['ai_response'] ?? '').toString(),
        ambivalenceType: (row['ambivalence_type'] ?? '暂不确定').toString(),
        confidence: _doubleValue(row['confidence']),
        coreConflict: (row['core_conflict'] ?? '').toString(),
        goForces: _mapList(row['go_forces_json']).map(SecondThoughtForce.fromJson).toList(growable: false),
        noForces: _mapList(row['no_forces_json']).map(SecondThoughtForce.fromJson).toList(growable: false),
        innerCommittee: _mapList(row['inner_committee_json']).map(SecondThoughtInnerVoice.fromJson).toList(growable: false),
        possibleValues: _stringListFromRaw((row['possible_values_json'] ?? '').toString()),
        coreValuesToConfirm: _stringListFromRaw((row['core_values_json'] ?? '').toString()),
        valueConflicts: _mapList(row['value_conflicts_json']).map(SecondThoughtValueConflict.fromJson).toList(growable: false),
        evidenceQuestions: _stringListFromRaw((row['evidence_questions_json'] ?? '').toString()),
        options: _mapList(row['options_json']).map(SecondThoughtDecisionOption.fromJson).toList(growable: false),
        thirdWayPossibilities: _stringListFromRaw((row['third_way_json'] ?? '').toString()),
        changeTalk: SecondThoughtChangeTalk.fromRaw((row['change_talk_json'] ?? '').toString()),
        actionExperiment: SecondThoughtActionExperiment.fromRaw((row['action_experiment_json'] ?? '').toString()),
        status: (row['status'] ?? 'exploring').toString(),
        riskLevel: (row['risk_level'] ?? 'none').toString(),
      );
}

class SecondThoughtReviewRecord {
  final int? id;
  final int caseId;
  final int createdAtMs;
  final String status;
  final String whatHappened;
  final String valuesLived;
  final String remainingVoices;
  final String adjustment;
  final String nextMicroAction;

  const SecondThoughtReviewRecord({
    this.id,
    this.caseId = 0,
    this.createdAtMs = 0,
    this.status = 'partial',
    this.whatHappened = '',
    this.valuesLived = '',
    this.remainingVoices = '',
    this.adjustment = '',
    this.nextMicroAction = '',
  });

  factory SecondThoughtReviewRecord.fromMap(Map<String, Object?> row) => SecondThoughtReviewRecord(
        id: _nullableInt(row['id']),
        caseId: _intValue(row['case_id']),
        createdAtMs: _intValue(row['created_at_ms']),
        status: (row['status'] ?? 'partial').toString(),
        whatHappened: (row['what_happened'] ?? '').toString(),
        valuesLived: (row['values_lived'] ?? '').toString(),
        remainingVoices: (row['remaining_voices'] ?? '').toString(),
        adjustment: (row['adjustment'] ?? '').toString(),
        nextMicroAction: (row['next_micro_action'] ?? '').toString(),
      );
}

class SecondThoughtStats {
  final int cases;
  final int actionExperiments;
  final int openCases;
  final int reviews;
  final int valueCount;
  final int changeTalkCount;

  const SecondThoughtStats({
    this.cases = 0,
    this.actionExperiments = 0,
    this.openCases = 0,
    this.reviews = 0,
    this.valueCount = 0,
    this.changeTalkCount = 0,
  });
}

List<String> _stringList(Object? value) {
  if (value == null) return <String>[];
  if (value is List) return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  final raw = value.toString().trim();
  if (raw.isEmpty) return <String>[];
  if (raw.startsWith('[')) return _stringListFromRaw(raw);
  return raw.split(RegExp(r'[,，;；\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
}

List<String> _stringListFromRaw(String raw) {
  if (raw.trim().isEmpty) return <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return _stringList(decoded);
  } catch (_) {}
  return _stringList(raw);
}

List<Map<String, dynamic>> _mapList(Object? raw) {
  if (raw == null) return <Map<String, dynamic>>[];
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is List) {
      return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
    }
  } catch (_) {}
  return <Map<String, dynamic>>[];
}

List<Map<String, String>> _ifThenList(Object? raw) {
  final maps = _mapList(raw);
  return maps.map((m) => <String, String>{
        'if': (m['if'] ?? '').toString(),
        'then': (m['then'] ?? '').toString(),
      }).where((m) => (m['if'] ?? '').isNotEmpty || (m['then'] ?? '').isNotEmpty).toList(growable: false);
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

double _doubleValue(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0.0;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
