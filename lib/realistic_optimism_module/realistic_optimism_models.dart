import 'dart:convert';

List<String> _stringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  if (v is String && v.trim().isNotEmpty) return <String>[v.trim()];
  return <String>[];
}

String _str(dynamic v, [String fallback = '']) => (v ?? fallback).toString();
int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse((v ?? '').toString()) ?? fallback;
double _double(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse((v ?? '').toString()) ?? fallback;
bool _bool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  final s = (v ?? '').toString().toLowerCase();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return fallback;
}

Map<String, dynamic> _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return <Map<String, dynamic>>[];
}

class RealisticOptimismCase {
  final String id;
  final String source;
  final String title;
  final String originalInput;
  final String userGoal;
  final String coreProblem;
  final String mainBelief;
  final String riskLevel;
  final String aiPosition;
  final String oldBelief;
  final List<String> facts;
  final List<String> interpretations;
  final List<String> hiddenAssumptions;
  final List<String> behaviorEffects;
  final String newRealisticBelief;
  final List<String> controllableFactors;
  final List<String> uncontrollableFactors;
  final List<String> resources;
  final List<String> risks;
  final List<String> realityConstraints;
  final List<String> probabilityImprovers;
  final String neededState;
  final List<String> positiveCues;
  final String phonePrompt;
  final List<String> environmentChanges;
  final List<String> antiPrimingCleanup;
  final String todayMinimumAction;
  final String actionTime;
  final String actionPlace;
  final String minimumSuccessStandard;
  final String ifThenPlan;
  final String possibleObstacle;
  final String fallbackAction;
  final String possibleFailure;
  final String nonHelpfulExplanation;
  final String realisticExplanation;
  final String feedbackValue;
  final String nextAdjustment;
  final String avoidPattern;
  final String comfortZoneAction;
  final String stretchZoneAction;
  final String panicZoneAction;
  final String recommendedAction;
  final String selfPerceptionAfterAction;
  final List<String> options;
  final String recommendedButNotForced;
  final String reflectionQuestion;
  final List<Map<String, dynamic>> displayCards;
  final String provider;
  final String modelLabel;
  final int createdAtMs;
  final int updatedAtMs;

  const RealisticOptimismCase({
    required this.id,
    required this.source,
    required this.title,
    required this.originalInput,
    required this.userGoal,
    required this.coreProblem,
    required this.mainBelief,
    required this.riskLevel,
    required this.aiPosition,
    required this.oldBelief,
    required this.facts,
    required this.interpretations,
    required this.hiddenAssumptions,
    required this.behaviorEffects,
    required this.newRealisticBelief,
    required this.controllableFactors,
    required this.uncontrollableFactors,
    required this.resources,
    required this.risks,
    required this.realityConstraints,
    required this.probabilityImprovers,
    required this.neededState,
    required this.positiveCues,
    required this.phonePrompt,
    required this.environmentChanges,
    required this.antiPrimingCleanup,
    required this.todayMinimumAction,
    required this.actionTime,
    required this.actionPlace,
    required this.minimumSuccessStandard,
    required this.ifThenPlan,
    required this.possibleObstacle,
    required this.fallbackAction,
    required this.possibleFailure,
    required this.nonHelpfulExplanation,
    required this.realisticExplanation,
    required this.feedbackValue,
    required this.nextAdjustment,
    required this.avoidPattern,
    required this.comfortZoneAction,
    required this.stretchZoneAction,
    required this.panicZoneAction,
    required this.recommendedAction,
    required this.selfPerceptionAfterAction,
    required this.options,
    required this.recommendedButNotForced,
    required this.reflectionQuestion,
    required this.displayCards,
    required this.provider,
    required this.modelLabel,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'source': source,
        'title': title,
        'original_input': originalInput,
        'summary': <String, dynamic>{
          'user_goal': userGoal,
          'core_problem': coreProblem,
          'main_belief': mainBelief,
          'risk_level': riskLevel,
          'ai_position': aiPosition,
        },
        'belief_chain': <String, dynamic>{
          'old_belief': oldBelief,
          'facts': facts,
          'interpretations': interpretations,
          'hidden_assumptions': hiddenAssumptions,
          'behavior_effects': behaviorEffects,
          'new_realistic_belief': newRealisticBelief,
        },
        'reality_check': <String, dynamic>{
          'controllable_factors': controllableFactors,
          'uncontrollable_factors': uncontrollableFactors,
          'resources': resources,
          'risks': risks,
          'reality_constraints': realityConstraints,
          'probability_improvers': probabilityImprovers,
        },
        'priming_design': <String, dynamic>{
          'needed_state': neededState,
          'positive_cues': positiveCues,
          'phone_prompt': phonePrompt,
          'environment_changes': environmentChanges,
          'anti_priming_cleanup': antiPrimingCleanup,
        },
        'action_experiment': <String, dynamic>{
          'today_minimum_action': todayMinimumAction,
          'time': actionTime,
          'place': actionPlace,
          'minimum_success_standard': minimumSuccessStandard,
          'if_then_plan': ifThenPlan,
          'possible_obstacle': possibleObstacle,
          'fallback_action': fallbackAction,
        },
        'failure_learning': <String, dynamic>{
          'possible_failure': possibleFailure,
          'non_helpful_explanation': nonHelpfulExplanation,
          'realistic_explanation': realisticExplanation,
          'feedback_value': feedbackValue,
          'next_adjustment': nextAdjustment,
        },
        'cope_design': <String, dynamic>{
          'avoid_pattern': avoidPattern,
          'comfort_zone_action': comfortZoneAction,
          'stretch_zone_action': stretchZoneAction,
          'panic_zone_action': panicZoneAction,
          'recommended_action': recommendedAction,
          'self_perception_after_action': selfPerceptionAfterAction,
        },
        'user_choice': <String, dynamic>{
          'options': options,
          'recommended_but_not_forced': recommendedButNotForced,
          'reflection_question': reflectionQuestion,
        },
        'display_cards': displayCards,
        'provider': provider,
        'model_label': modelLabel,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  static RealisticOptimismCase fromRow(Map<String, Object?> row) {
    final payload = jsonDecode((row['payload_json'] ?? '{}').toString());
    final m = payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
    return fromJson(m).copyWith(
      id: _str(row['id'], _str(m['id'])),
      source: _str(row['source'], _str(m['source'], 'manual')),
      title: _str(row['title'], _str(m['title'], '现实乐观行动实验')),
      createdAtMs: _int(row['created_at_ms'], _int(m['created_at_ms'])),
      updatedAtMs: _int(row['updated_at_ms'], _int(m['updated_at_ms'])),
    );
  }

  static RealisticOptimismCase fromJson(Map<String, dynamic> m) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final summary = _map(m['summary']);
    final belief = _map(m['belief_chain']);
    final reality = _map(m['reality_check']);
    final priming = _map(m['priming_design']);
    final action = _map(m['action_experiment']);
    final failure = _map(m['failure_learning']);
    final cope = _map(m['cope_design']);
    final choice = _map(m['user_choice']);
    final source = _str(m['source'], 'manual');
    final original = _str(m['original_input']);
    final goal = _str(summary['user_goal'], _str(m['user_goal']));
    final oldBelief = _str(belief['old_belief'], _str(summary['main_belief']));
    final title = _str(m['title'], goal.isEmpty ? '现实乐观行动实验' : goal);
    return RealisticOptimismCase(
      id: _str(m['id'], 'ro_${now}_${original.hashCode.abs()}'),
      source: source,
      title: title,
      originalInput: original,
      userGoal: goal,
      coreProblem: _str(summary['core_problem']),
      mainBelief: _str(summary['main_belief'], oldBelief),
      riskLevel: _str(summary['risk_level'], 'medium'),
      aiPosition: _str(summary['ai_position'], '现实乐观，不承诺结果，强调行动实验'),
      oldBelief: oldBelief,
      facts: _stringList(belief['facts']),
      interpretations: _stringList(belief['interpretations']),
      hiddenAssumptions: _stringList(belief['hidden_assumptions']),
      behaviorEffects: _stringList(belief['behavior_effects']),
      newRealisticBelief: _str(belief['new_realistic_belief']),
      controllableFactors: _stringList(reality['controllable_factors']),
      uncontrollableFactors: _stringList(reality['uncontrollable_factors']),
      resources: _stringList(reality['resources']),
      risks: _stringList(reality['risks']),
      realityConstraints: _stringList(reality['reality_constraints']),
      probabilityImprovers: _stringList(reality['probability_improvers']),
      neededState: _str(priming['needed_state']),
      positiveCues: _stringList(priming['positive_cues']),
      phonePrompt: _str(priming['phone_prompt']),
      environmentChanges: _stringList(priming['environment_changes']),
      antiPrimingCleanup: _stringList(priming['anti_priming_cleanup']),
      todayMinimumAction: _str(action['today_minimum_action']),
      actionTime: _str(action['time']),
      actionPlace: _str(action['place']),
      minimumSuccessStandard: _str(action['minimum_success_standard']),
      ifThenPlan: _str(action['if_then_plan']),
      possibleObstacle: _str(action['possible_obstacle']),
      fallbackAction: _str(action['fallback_action']),
      possibleFailure: _str(failure['possible_failure']),
      nonHelpfulExplanation: _str(failure['non_helpful_explanation']),
      realisticExplanation: _str(failure['realistic_explanation']),
      feedbackValue: _str(failure['feedback_value']),
      nextAdjustment: _str(failure['next_adjustment']),
      avoidPattern: _str(cope['avoid_pattern']),
      comfortZoneAction: _str(cope['comfort_zone_action']),
      stretchZoneAction: _str(cope['stretch_zone_action']),
      panicZoneAction: _str(cope['panic_zone_action']),
      recommendedAction: _str(cope['recommended_action']),
      selfPerceptionAfterAction: _str(cope['self_perception_after_action']),
      options: _stringList(choice['options']),
      recommendedButNotForced: _str(choice['recommended_but_not_forced']),
      reflectionQuestion: _str(choice['reflection_question']),
      displayCards: _mapList(m['display_cards']),
      provider: _str(m['provider'], 'local'),
      modelLabel: _str(m['model_label'], '内置策略'),
      createdAtMs: _int(m['created_at_ms'], now),
      updatedAtMs: _int(m['updated_at_ms'], now),
    );
  }

  RealisticOptimismCase copyWith({
    String? id,
    String? source,
    String? title,
    String? originalInput,
    int? createdAtMs,
    int? updatedAtMs,
    String? provider,
    String? modelLabel,
  }) => RealisticOptimismCase(
        id: id ?? this.id,
        source: source ?? this.source,
        title: title ?? this.title,
        originalInput: originalInput ?? this.originalInput,
        userGoal: userGoal,
        coreProblem: coreProblem,
        mainBelief: mainBelief,
        riskLevel: riskLevel,
        aiPosition: aiPosition,
        oldBelief: oldBelief,
        facts: facts,
        interpretations: interpretations,
        hiddenAssumptions: hiddenAssumptions,
        behaviorEffects: behaviorEffects,
        newRealisticBelief: newRealisticBelief,
        controllableFactors: controllableFactors,
        uncontrollableFactors: uncontrollableFactors,
        resources: resources,
        risks: risks,
        realityConstraints: realityConstraints,
        probabilityImprovers: probabilityImprovers,
        neededState: neededState,
        positiveCues: positiveCues,
        phonePrompt: phonePrompt,
        environmentChanges: environmentChanges,
        antiPrimingCleanup: antiPrimingCleanup,
        todayMinimumAction: todayMinimumAction,
        actionTime: actionTime,
        actionPlace: actionPlace,
        minimumSuccessStandard: minimumSuccessStandard,
        ifThenPlan: ifThenPlan,
        possibleObstacle: possibleObstacle,
        fallbackAction: fallbackAction,
        possibleFailure: possibleFailure,
        nonHelpfulExplanation: nonHelpfulExplanation,
        realisticExplanation: realisticExplanation,
        feedbackValue: feedbackValue,
        nextAdjustment: nextAdjustment,
        avoidPattern: avoidPattern,
        comfortZoneAction: comfortZoneAction,
        stretchZoneAction: stretchZoneAction,
        panicZoneAction: panicZoneAction,
        recommendedAction: recommendedAction,
        selfPerceptionAfterAction: selfPerceptionAfterAction,
        options: options,
        recommendedButNotForced: recommendedButNotForced,
        reflectionQuestion: reflectionQuestion,
        displayCards: displayCards,
        provider: provider ?? this.provider,
        modelLabel: modelLabel ?? this.modelLabel,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );
}

class RealisticOptimismActionLog {
  final String id;
  final String caseId;
  final String status;
  final String note;
  final int createdAtMs;
  const RealisticOptimismActionLog({required this.id, required this.caseId, required this.status, required this.note, required this.createdAtMs});

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'case_id': caseId, 'status': status, 'note': note, 'created_at_ms': createdAtMs};
  static RealisticOptimismActionLog fromRow(Map<String, Object?> row) => RealisticOptimismActionLog(
        id: _str(row['id']),
        caseId: _str(row['case_id']),
        status: _str(row['status']),
        note: _str(row['note']),
        createdAtMs: _int(row['created_at_ms']),
      );
}

class RealisticOptimismFailureReview {
  final String id;
  final String caseId;
  final String event;
  final String originalExplanation;
  final bool permanentFlag;
  final bool globalFlag;
  final bool personalizationFlag;
  final bool catastropheFlag;
  final String realisticExplanation;
  final String feedback;
  final String nextAdjustment;
  final int createdAtMs;

  const RealisticOptimismFailureReview({
    required this.id,
    required this.caseId,
    required this.event,
    required this.originalExplanation,
    required this.permanentFlag,
    required this.globalFlag,
    required this.personalizationFlag,
    required this.catastropheFlag,
    required this.realisticExplanation,
    required this.feedback,
    required this.nextAdjustment,
    required this.createdAtMs,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'case_id': caseId,
        'event': event,
        'original_explanation': originalExplanation,
        'permanent_flag': permanentFlag ? 1 : 0,
        'global_flag': globalFlag ? 1 : 0,
        'personalization_flag': personalizationFlag ? 1 : 0,
        'catastrophe_flag': catastropheFlag ? 1 : 0,
        'realistic_explanation': realisticExplanation,
        'feedback': feedback,
        'next_adjustment': nextAdjustment,
        'created_at_ms': createdAtMs,
      };

  static RealisticOptimismFailureReview fromRow(Map<String, Object?> row) => RealisticOptimismFailureReview(
        id: _str(row['id']),
        caseId: _str(row['case_id']),
        event: _str(row['event']),
        originalExplanation: _str(row['original_explanation']),
        permanentFlag: _bool(row['permanent_flag']),
        globalFlag: _bool(row['global_flag']),
        personalizationFlag: _bool(row['personalization_flag']),
        catastropheFlag: _bool(row['catastrophe_flag']),
        realisticExplanation: _str(row['realistic_explanation']),
        feedback: _str(row['feedback']),
        nextAdjustment: _str(row['next_adjustment']),
        createdAtMs: _int(row['created_at_ms']),
      );
}

class RealisticOptimismBaselineEntry {
  final int? id;
  final int tsMs;
  final double moodScore;
  final double selfEsteemScore;
  final double selfEfficacyScore;
  final int copeCount;
  final int avoidCount;
  final bool minimumActionDone;
  final bool failureReviewDone;
  final bool realisticOptimismUsed;
  final String note;

  const RealisticOptimismBaselineEntry({
    this.id,
    required this.tsMs,
    required this.moodScore,
    required this.selfEsteemScore,
    required this.selfEfficacyScore,
    required this.copeCount,
    required this.avoidCount,
    required this.minimumActionDone,
    required this.failureReviewDone,
    required this.realisticOptimismUsed,
    required this.note,
  });

  Map<String, dynamic> toRow() => <String, dynamic>{
        if (id != null) 'id': id,
        'ts_ms': tsMs,
        'mood_score': moodScore,
        'self_esteem_score': selfEsteemScore,
        'self_efficacy_score': selfEfficacyScore,
        'cope_count': copeCount,
        'avoid_count': avoidCount,
        'minimum_action_done': minimumActionDone ? 1 : 0,
        'failure_review_done': failureReviewDone ? 1 : 0,
        'realistic_optimism_used': realisticOptimismUsed ? 1 : 0,
        'note': note,
      };

  static RealisticOptimismBaselineEntry fromRow(Map<String, Object?> row) => RealisticOptimismBaselineEntry(
        id: row['id'] is num ? (row['id'] as num).toInt() : null,
        tsMs: _int(row['ts_ms']),
        moodScore: _double(row['mood_score']),
        selfEsteemScore: _double(row['self_esteem_score']),
        selfEfficacyScore: _double(row['self_efficacy_score']),
        copeCount: _int(row['cope_count']),
        avoidCount: _int(row['avoid_count']),
        minimumActionDone: _bool(row['minimum_action_done']),
        failureReviewDone: _bool(row['failure_review_done']),
        realisticOptimismUsed: _bool(row['realistic_optimism_used']),
        note: _str(row['note']),
      );
}
