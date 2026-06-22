import 'dart:convert';

String _s(dynamic v, [String fallback = '']) => (v == null ? fallback : v.toString()).trim();
int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? fallback;
double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? fallback;
bool _b(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  final s = _s(v).toLowerCase();
  if (s == '1' || s == 'true' || s == 'yes') return true;
  if (s == '0' || s == 'false' || s == 'no') return false;
  return fallback;
}

Map<String, dynamic> _m(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<String> _list(dynamic v) {
  if (v is List) return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  final s = _s(v);
  if (s.isEmpty) return <String>[];
  return <String>[s];
}

class RealisticOptimismTrainingRecord {
  final String id;
  final String scene;
  final String rawInput;
  final String intensityLevel;
  final String intensityReason;
  final List<String> allowedInterventions;
  final List<String> blockedInterventions;
  final String eventSummary;
  final String primaryEmotion;
  final String validationText;
  final List<String> objectiveFacts;
  final List<String> unknowns;
  final String automaticInterpretation;
  final int permanenceScore;
  final int pervasivenessScore;
  final int personalizationScore;
  final int catastrophizingScore;
  final int helplessnessScore;
  final int filteringScore;
  final String mainPattern;
  final String faultFinderStory;
  final String emotionalEffect;
  final String behavioralEffect;
  final String balancedInterpretation;
  final String notDeniedPain;
  final List<String> possibleLearning;
  final List<String> remainingResources;
  final List<String> possibleMeaning;
  final List<String> uncontrollableParts;
  final List<String> influenceableParts;
  final List<String> controllableActions;
  final String fiveMinuteAction;
  final List<String> nextThreeSteps;
  final List<String> ifThenPlan;
  final double? predictedPain;
  final double? actualPain;
  final String predictedRecovery;
  final String actualRecovery;
  final String psychologicalAntibody;
  final List<String> whatStillMatters;
  final String savoringPrompt;
  final String smallAppreciationAction;
  final String dailyValueWord;
  final String lockScreenSentence;
  final String benefitFinderQuestion;
  final String antiPrimeCleanupAction;
  final String specificAction;
  final String provedCapacity;
  final String identityType;
  final String identitySentence;
  final String finalUserMessage;
  final String provider;
  final String modelLabel;
  final Map<String, dynamic> payload;
  final int createdAtMs;
  final int updatedAtMs;

  const RealisticOptimismTrainingRecord({
    required this.id,
    required this.scene,
    required this.rawInput,
    required this.intensityLevel,
    required this.intensityReason,
    required this.allowedInterventions,
    required this.blockedInterventions,
    required this.eventSummary,
    required this.primaryEmotion,
    required this.validationText,
    required this.objectiveFacts,
    required this.unknowns,
    required this.automaticInterpretation,
    required this.permanenceScore,
    required this.pervasivenessScore,
    required this.personalizationScore,
    required this.catastrophizingScore,
    required this.helplessnessScore,
    required this.filteringScore,
    required this.mainPattern,
    required this.faultFinderStory,
    required this.emotionalEffect,
    required this.behavioralEffect,
    required this.balancedInterpretation,
    required this.notDeniedPain,
    required this.possibleLearning,
    required this.remainingResources,
    required this.possibleMeaning,
    required this.uncontrollableParts,
    required this.influenceableParts,
    required this.controllableActions,
    required this.fiveMinuteAction,
    required this.nextThreeSteps,
    required this.ifThenPlan,
    required this.predictedPain,
    required this.actualPain,
    required this.predictedRecovery,
    required this.actualRecovery,
    required this.psychologicalAntibody,
    required this.whatStillMatters,
    required this.savoringPrompt,
    required this.smallAppreciationAction,
    required this.dailyValueWord,
    required this.lockScreenSentence,
    required this.benefitFinderQuestion,
    required this.antiPrimeCleanupAction,
    required this.specificAction,
    required this.provedCapacity,
    required this.identityType,
    required this.identitySentence,
    required this.finalUserMessage,
    required this.provider,
    required this.modelLabel,
    required this.payload,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'scene': scene,
        'raw_input': rawInput,
        'intensity_level': intensityLevel,
        'primary_emotion': primaryEmotion,
        'automatic_interpretation': automaticInterpretation,
        'main_pattern': mainPattern,
        'five_minute_action': fiveMinuteAction,
        'identity_sentence': identitySentence,
        'provider': provider,
        'model_label': modelLabel,
        'payload_json': jsonEncode(payload),
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  static RealisticOptimismTrainingRecord fromRow(Map<String, Object?> row) {
    final payloadRaw = _s(row['payload_json'], '{}');
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(payloadRaw);
      json = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      json = <String, dynamic>{};
    }
    return fromJson(json).copyWith(
      id: _s(row['id'], _s(json['id'])),
      scene: _s(row['scene'], _s(json['scene'])),
      rawInput: _s(row['raw_input'], _s(json['raw_input'])),
      intensityLevel: _s(row['intensity_level'], _s(_m(json['intensity_check'])['level'], 'L1')),
      primaryEmotion: _s(row['primary_emotion'], _s(_m(json['emotion_validation'])['primary_emotion'])),
      automaticInterpretation: _s(row['automatic_interpretation'], _s(_m(json['interpretation_style'])['automatic_interpretation'])),
      mainPattern: _s(row['main_pattern'], _s(_m(json['interpretation_style'])['main_pattern'])),
      fiveMinuteAction: _s(row['five_minute_action'], _s(_m(json['process_action_plan'])['five_minute_action'])),
      identitySentence: _s(row['identity_sentence'], _s(_m(json['identity_evidence'])['identity_sentence'])),
      provider: _s(row['provider'], _s(json['provider'], 'local')),
      modelLabel: _s(row['model_label'], _s(json['model_label'], '内置策略')),
      createdAtMs: _i(row['created_at_ms'], _i(json['created_at_ms'])),
      updatedAtMs: _i(row['updated_at_ms'], _i(json['updated_at_ms'])),
    );
  }

  static RealisticOptimismTrainingRecord fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final intensity = _m(json['intensity_check']);
    final emotion = _m(json['emotion_validation']);
    final facts = _m(json['fact_layer']);
    final style = _m(json['interpretation_style']);
    final fault = _m(json['fault_finder_layer']);
    final benefit = _m(json['benefit_finder_layer']);
    final agency = _m(json['agency_layer']);
    final action = _m(json['process_action_plan']);
    final failure = _m(json['failure_immunity']);
    final gratitude = _m(json['gratitude_or_savoring']);
    final prime = _m(json['prime']);
    final identity = _m(json['identity_evidence']);
    final raw = _s(json['raw_input'], _s(json['original_input']));
    final id = _s(json['id'], 'rot_${now}_${raw.hashCode.abs()}');
    final map = Map<String, dynamic>.from(json);
    map['id'] = id;
    map['raw_input'] = raw;
    map['created_at_ms'] = _i(json['created_at_ms'], now);
    map['updated_at_ms'] = _i(json['updated_at_ms'], now);
    return RealisticOptimismTrainingRecord(
      id: id,
      scene: _s(json['scene'], 'event_reframe'),
      rawInput: raw,
      intensityLevel: _s(intensity['level'], 'L1'),
      intensityReason: _s(intensity['reason']),
      allowedInterventions: _list(intensity['allowed_intervention']),
      blockedInterventions: _list(intensity['blocked_intervention']),
      eventSummary: _s(json['user_event_summary']),
      primaryEmotion: _s(emotion['primary_emotion']),
      validationText: _s(emotion['validation_text']),
      objectiveFacts: _list(facts['objective_facts']),
      unknowns: _list(facts['unknowns_or_assumptions']),
      automaticInterpretation: _s(style['automatic_interpretation']),
      permanenceScore: _i(style['permanence_score']).clamp(0, 10).toInt(),
      pervasivenessScore: _i(style['pervasiveness_score']).clamp(0, 10).toInt(),
      personalizationScore: _i(style['personalization_score']).clamp(0, 10).toInt(),
      catastrophizingScore: _i(style['catastrophizing_score']).clamp(0, 10).toInt(),
      helplessnessScore: _i(style['helplessness_score']).clamp(0, 10).toInt(),
      filteringScore: _i(style['filtering_score']).clamp(0, 10).toInt(),
      mainPattern: _s(style['main_pattern']),
      faultFinderStory: _s(fault['fault_finder_story']),
      emotionalEffect: _s(fault['likely_emotional_effect']),
      behavioralEffect: _s(fault['likely_behavioral_effect']),
      balancedInterpretation: _s(benefit['balanced_interpretation']),
      notDeniedPain: _s(benefit['not_denied_pain']),
      possibleLearning: _list(benefit['possible_learning']),
      remainingResources: _list(benefit['remaining_resources']),
      possibleMeaning: _list(benefit['possible_meaning']),
      uncontrollableParts: _list(agency['uncontrollable_parts']),
      influenceableParts: _list(agency['influenceable_parts']),
      controllableActions: _list(agency['controllable_actions']),
      fiveMinuteAction: _s(action['five_minute_action']),
      nextThreeSteps: _list(action['next_three_steps']),
      ifThenPlan: _list(action['if_then_plan']),
      predictedPain: failure['predicted_pain'] == null ? null : _d(failure['predicted_pain']),
      actualPain: failure['actual_pain'] == null ? null : _d(failure['actual_pain']),
      predictedRecovery: _s(failure['predicted_recovery']),
      actualRecovery: _s(failure['actual_recovery']),
      psychologicalAntibody: _s(failure['psychological_antibody']),
      whatStillMatters: _list(gratitude['what_still_matters']),
      savoringPrompt: _s(gratitude['savoring_prompt']),
      smallAppreciationAction: _s(gratitude['small_appreciation_action']),
      dailyValueWord: _s(prime['daily_value_word']),
      lockScreenSentence: _s(prime['lock_screen_sentence']),
      benefitFinderQuestion: _s(prime['benefit_finder_question']),
      antiPrimeCleanupAction: _s(prime['anti_prime_cleanup_action']),
      specificAction: _s(identity['specific_action']),
      provedCapacity: _s(identity['proved_capacity']),
      identityType: _s(identity['identity_type']),
      identitySentence: _s(identity['identity_sentence']),
      finalUserMessage: _s(json['final_user_message']),
      provider: _s(json['provider'], 'local'),
      modelLabel: _s(json['model_label'], '内置策略'),
      payload: map,
      createdAtMs: _i(json['created_at_ms'], now),
      updatedAtMs: _i(json['updated_at_ms'], now),
    );
  }

  RealisticOptimismTrainingRecord copyWith({
    String? id,
    String? scene,
    String? rawInput,
    String? intensityLevel,
    String? primaryEmotion,
    String? automaticInterpretation,
    String? mainPattern,
    String? fiveMinuteAction,
    String? identitySentence,
    String? provider,
    String? modelLabel,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return RealisticOptimismTrainingRecord(
      id: id ?? this.id,
      scene: scene ?? this.scene,
      rawInput: rawInput ?? this.rawInput,
      intensityLevel: intensityLevel ?? this.intensityLevel,
      intensityReason: intensityReason,
      allowedInterventions: allowedInterventions,
      blockedInterventions: blockedInterventions,
      eventSummary: eventSummary,
      primaryEmotion: primaryEmotion ?? this.primaryEmotion,
      validationText: validationText,
      objectiveFacts: objectiveFacts,
      unknowns: unknowns,
      automaticInterpretation: automaticInterpretation ?? this.automaticInterpretation,
      permanenceScore: permanenceScore,
      pervasivenessScore: pervasivenessScore,
      personalizationScore: personalizationScore,
      catastrophizingScore: catastrophizingScore,
      helplessnessScore: helplessnessScore,
      filteringScore: filteringScore,
      mainPattern: mainPattern ?? this.mainPattern,
      faultFinderStory: faultFinderStory,
      emotionalEffect: emotionalEffect,
      behavioralEffect: behavioralEffect,
      balancedInterpretation: balancedInterpretation,
      notDeniedPain: notDeniedPain,
      possibleLearning: possibleLearning,
      remainingResources: remainingResources,
      possibleMeaning: possibleMeaning,
      uncontrollableParts: uncontrollableParts,
      influenceableParts: influenceableParts,
      controllableActions: controllableActions,
      fiveMinuteAction: fiveMinuteAction ?? this.fiveMinuteAction,
      nextThreeSteps: nextThreeSteps,
      ifThenPlan: ifThenPlan,
      predictedPain: this.predictedPain,
      actualPain: this.actualPain,
      predictedRecovery: predictedRecovery,
      actualRecovery: actualRecovery,
      psychologicalAntibody: psychologicalAntibody,
      whatStillMatters: whatStillMatters,
      savoringPrompt: savoringPrompt,
      smallAppreciationAction: smallAppreciationAction,
      dailyValueWord: dailyValueWord,
      lockScreenSentence: lockScreenSentence,
      benefitFinderQuestion: benefitFinderQuestion,
      antiPrimeCleanupAction: antiPrimeCleanupAction,
      specificAction: specificAction,
      provedCapacity: provedCapacity,
      identityType: identityType,
      identitySentence: identitySentence ?? this.identitySentence,
      finalUserMessage: finalUserMessage,
      provider: provider ?? this.provider,
      modelLabel: modelLabel ?? this.modelLabel,
      payload: payload,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }
}

class RealisticOptimismTrainingActionEvidence {
  final String id;
  final String recordId;
  final String action;
  final String evidenceText;
  final bool completed;
  final int createdAtMs;

  const RealisticOptimismTrainingActionEvidence({
    required this.id,
    required this.recordId,
    required this.action,
    required this.evidenceText,
    required this.completed,
    required this.createdAtMs,
  });

  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'record_id': recordId,
        'action': action,
        'evidence_text': evidenceText,
        'completed': completed ? 1 : 0,
        'created_at_ms': createdAtMs,
      };

  static RealisticOptimismTrainingActionEvidence fromRow(Map<String, Object?> row) => RealisticOptimismTrainingActionEvidence(
        id: _s(row['id']),
        recordId: _s(row['record_id']),
        action: _s(row['action']),
        evidenceText: _s(row['evidence_text']),
        completed: _b(row['completed']),
        createdAtMs: _i(row['created_at_ms']),
      );
}

class RealisticOptimismTrainingBaseline {
  final String id;
  final int tsMs;
  final double happinessScore;
  final double recoveryScore;
  final double agencyScore;
  final double permanenceFrequency;
  final double gratitudeSensitivity;
  final double actionStability;
  final String note;

  const RealisticOptimismTrainingBaseline({
    required this.id,
    required this.tsMs,
    required this.happinessScore,
    required this.recoveryScore,
    required this.agencyScore,
    required this.permanenceFrequency,
    required this.gratitudeSensitivity,
    required this.actionStability,
    required this.note,
  });

  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'ts_ms': tsMs,
        'happiness_score': happinessScore,
        'recovery_score': recoveryScore,
        'agency_score': agencyScore,
        'permanence_frequency': permanenceFrequency,
        'gratitude_sensitivity': gratitudeSensitivity,
        'action_stability': actionStability,
        'note': note,
      };

  static RealisticOptimismTrainingBaseline fromRow(Map<String, Object?> row) => RealisticOptimismTrainingBaseline(
        id: _s(row['id']),
        tsMs: _i(row['ts_ms']),
        happinessScore: _d(row['happiness_score']),
        recoveryScore: _d(row['recovery_score']),
        agencyScore: _d(row['agency_score']),
        permanenceFrequency: _d(row['permanence_frequency']),
        gratitudeSensitivity: _d(row['gratitude_sensitivity']),
        actionStability: _d(row['action_stability']),
        note: _s(row['note']),
      );
}

class RealisticOptimismTrainingStats {
  final int records;
  final int actions;
  final int baselines;
  final int gratitude;
  final int primes;
  final int identity;
  final int explanationScores;
  final int benefitReframes;
  final int failureImmunity;
  final int controlledChallenges;
  final int savoring;
  final int antiPrimes;
  final int relationshipGratitude;
  final int eventIntensity;
  final int processPlans;

  const RealisticOptimismTrainingStats({
    required this.records,
    required this.actions,
    required this.baselines,
    required this.gratitude,
    required this.primes,
    required this.identity,
    this.explanationScores = 0,
    this.benefitReframes = 0,
    this.failureImmunity = 0,
    this.controlledChallenges = 0,
    this.savoring = 0,
    this.antiPrimes = 0,
    this.relationshipGratitude = 0,
    this.eventIntensity = 0,
    this.processPlans = 0,
  });
}
