import 'model.dart';

/// One schema supplies AI contracts and local validation. Optional fields end
/// in '?'; nullable values end in '?'. Unknown is a first-class enum value.
const factState =
    'enum:reported,observed,verified,hypothesized,contradicted,unknown';
const safetyState = 'enum:clear,verify_first,blocked,unknown';
const effect = 'enum:promotes,harms,mixed,unknown';
const control = 'enum:direct,indirect,shared,none,unknown';
const changeability =
    'enum:irreversible_past,modifiable_now,modifiable_with_support,hard_limit_for_task,externally_dependent,uncertain';
const relation = 'enum:supports,opposes,conditional,unclear';

final Map<NodeKind, Json> nodeShapes = {
  NodeKind.evidence: {
    'text': 'text',
    'category':
        'enum:event,wish,belief,feeling,correction,counter,preparation,capability,condition,action,outcome,experience',
    'source': 'enum:self_report,authorized_observation',
    'sensitive': 'bool',
    'scope': 'enum:case_only,selected_cases',
    'context?': 'note'
  },
  NodeKind.understanding: {
    'summary': 'text',
    'clarity?': {
      'stuckPoint': 'text',
      'perspective': 'text',
      'nextStep': 'text',
      'whyThisStep': 'text',
      'question': 'note',
    },
    'facts': [
      {
        'claim': 'text',
        'evidenceIds': ['text'],
        'quote': 'text'
      }
    ],
    'unknowns': ['text'],
    'keyQuestion': 'note',
    'domains': ['text'],
    'riskFlags': ['text'],
    'timeContext': 'enum:future,present,past,unclear'
  },
  NodeKind.want: {
    'claim': 'text',
    'contexts': ['text'],
    'alternatives': ['text'],
    'falsifier': 'text',
    'specificity': 'enum:generic,individual,tentative',
    'attractionSources': [
      'enum:social_symbol,anticipated_outcome,process_preference,lived_evidence,unknown'
    ],
    'immediateBenefit': 'note',
    'longTermCost': 'note',
    'nextTest': 'text'
  },
  NodeKind.belief: {
    'claim': 'text',
    'kind':
        'enum:fact,prediction,causal,value,goal_means,feeling,metaphysical,fiction',
    'realityStatus': factState,
    'confidence': 'confidence?',
    'awareness':
        'enum:known_before,not_known,noticed_at_trigger,recalled_after,unknown',
    'influence': 'enum:reported,observed,not_observed,unknown',
    'verify': 'text'
  },
  NodeKind.motive: {
    'summary': 'text',
    'wantIds': ['text'],
    'beliefIds': ['text'],
    'representation': 'enum:intuitive,abstract,mixed,unknown',
    'approach': 'enum:approach,avoid,mixed,unknown',
    'horizon': 'enum:now,next_episode,near,long,mixed,unknown',
    'semanticKey': 'text',
    'factStatus': factState,
    'personalBasis': 'enum:explicit,contextual,generic,unknown',
    'materiality': 'enum:critical,important,minor,unknown',
    'riskWarning': 'bool',
    'unknowns': ['text'],
    'falsifier': 'text',
    'counterReason': 'text',
    'directionByRoute': [
      {'routeId': 'text', 'relation': relation, 'reason': 'text'}
    ]
  },
  NodeKind.reframe: {
    'oldBeliefId': 'text',
    'newClaim': 'text',
    'operator': 'text',
    'operatorWhy': 'text',
    'mechanism': 'text',
    'oldMayBeRight': 'text',
    'alternatives': ['text'],
    'falsifier': 'text',
    'test': 'text',
    'conditions': ['text'],
    'unknowns': ['text'],
    'affectedMotiveIds': ['text'],
    'affectedRouteIds': ['text'],
    'theoryRefs': ['text']
  },
  NodeKind.route: {
    'title': 'text',
    'description': 'text',
    'firstStep': 'text',
    'family': 'text',
    'wantIds': ['text'],
    'conditions': ['text'],
    'constraints': ['text'],
    'reversibility': 'enum:reversible,partly_reversible,irreversible,unknown',
    'safety': safetyState,
    'feasibility': 'enum:verified,conditional,unknown,infeasible',
    'verify': 'text',
    'protective': 'bool',
    'dailyProcess': ['text'],
    'expectedBenefits': ['text'],
    'expectedCosts': ['text'],
    'explorationState':
        'enum:considered,interest_only,planned,attempted,experienced,unknown'
  },
  NodeKind.routeFit: {
    'routeId': 'text',
    'wantFit': 'enum:high,partial,low,unknown',
    'bodySkillFit':
        'enum:verified_fit,fit_with_support,unverified,mismatch_for_this_task,prohibited_due_to_safety',
    'externalFeasibility': 'enum:verified,conditional,unknown,infeasible',
    'motivationCognition': 'text',
    'hardSafetyGate': safetyState,
    'difficulty': 'difficulty?',
    'difficultyFactors': [
      {
        'factor': 'enum:start_friction,skill_gap,resources,emotional,context',
        'assessment': 'text',
        'level': 'difficulty?',
        'evidenceIds': ['text']
      }
    ],
    'matrix': [
      {
        'wantId': 'text',
        'horizon': 'enum:now,next_episode,near,long',
        'effect': effect,
        'reason': 'text',
        'conditions': ['text'],
        'evidenceIds': ['text']
      }
    ],
    'exploratoryIndex': 'index?',
    'indexDimensions': [
      {
        'dimension':
            'enum:want_alignment,long_horizon,tradeoffs,self_concordance',
        'value': 'index?',
        'basis': 'text',
        'evidenceIds': ['text']
      }
    ],
    'uncertainty': 'text',
    'lowerDifficultyRouteId': 'text?'
  },
  NodeKind.graphEdge: {
    'fromId': 'text',
    'toId': 'text',
    'routeId': 'text?',
    'relation':
        'enum:supports,opposes,conditional,unclear,requires_belief,activated_by,substitutes_for',
    'reason': 'text',
    'conditions': ['text'],
    'horizon': 'enum:now,near,long,mixed,unknown',
    'falsifier': 'text'
  },
  NodeKind.conflict: {
    'title': 'text',
    'kind':
        'enum:approach_approach,avoid_avoid,approach_avoid,double_approach_avoid,cross_time,unknown',
    'motiveIds': ['text'],
    'routeIds': ['text'],
    'explanation': 'text',
    'unknowns': ['text']
  },
  NodeKind.deliberation: {
    'label': 'text',
    'nodeIds': ['text'],
    'unknowns': ['text'],
    'endorsedIds': ['text'],
    'snapshot': 'json'
  },
  NodeKind.graphShift: {
    'beforeId': 'text',
    'afterId': 'text',
    'addedIds': ['text'],
    'removedIds': ['text'],
    'changedIds': ['text'],
    'reason': 'text',
    'nextTest': 'text'
  },
  NodeKind.consequence: {
    'routeId': 'text',
    'wantId': 'text?',
    'window': 'text',
    'horizon': 'enum:now,next_episode,near,long',
    'expectedAt': 'timestamp?',
    'pattern': 'enum:one_off,repeated,cumulative,threshold,unknown',
    'claim': 'text',
    'assumptions': ['text'],
    'loss':
        'enum:temporary,recoverable,irreversible,perceived_permanent,unknown',
    'restoreConditions': ['text'],
    'alternatives': ['text'],
    'observedObservationId': 'text?'
  },
  NodeKind.obstacle: {
    'statement': 'text',
    'routeId': 'text?',
    'stageAffected':
        'enum:knowledge,option_generation,deliberation,decision,attempt_start,execution,external_outcome,want_fit,unknown',
    'locus': 'enum:internal,external,interacting,unknown',
    'mechanisms': [
      'enum:epistemic_information,motive_conflict,emotion_self_regulation,capability_skill,health_physical,resources_access,environment_institution,other_agent,random_event,unknown_or_mixed'
    ],
    'evidenceStatus': factState,
    'controllability': control,
    'objectiveStatus': 'text',
    'believedAtT0': 'note',
    'workaround': 'text',
    'reversibility': 'text',
    'riskGate': safetyState,
    'alternatives': ['text'],
    'falsifier': 'text'
  },
  NodeKind.taskRequirement: {
    'routeId': 'text',
    'taskStep': 'text',
    'requirement': 'text',
    'precision': 'text',
    'riskIfUnmet': 'text',
    'status': factState,
    'validUntil': 'timestamp?'
  },
  NodeKind.capability: {
    'description': 'text',
    'functionalDomain': 'text',
    'stability':
        'enum:stable_reported,variable,trainable,context_dependent,unknown',
    'state':
        'enum:demonstrated_strength,trainable_gap,fit_with_support,variable_state,task_mismatch,unknown',
    'taskRequirementIds': ['text'],
    'status': factState,
    'sensitive': 'bool'
  },
  NodeKind.supportVariant: {
    'routeId': 'text',
    'requirementId': 'text?',
    'kind':
        'enum:training,assistive_tool,environment_adjustment,collaboration,time_shift,alternate_route,pause',
    'action': 'text',
    'prerequisite': 'text',
    'cost': 'text',
    'risk': 'text',
    'consentRequired': 'bool',
    'availability': factState,
    'nextTest': 'text'
  },
  NodeKind.resourceConflict: {
    'routeAId': 'text',
    'routeBId': 'text',
    'resource': 'text',
    'window': 'text',
    'relation':
        'enum:independent,compatible,competing,strictly_exclusive,prerequisite,unknown',
    'capacityBasis': 'text',
    'irreversibility': 'text',
    'alternatives': ['text'],
    'status': factState
  },
  NodeKind.tradeoff: {
    'selectedRouteIds': ['text'],
    'deferredRouteIds': ['text'],
    'abandonedRouteIds': ['text'],
    'mode': 'enum:parallel,sequence,reduce,defer,switch,drop,retain,unknown',
    'cost': 'note',
    'restoreCondition': 'text',
    'userConfirmed': 'bool'
  },
  NodeKind.preflight: {
    'routeId': 'text',
    'baseline': 'text',
    'possibleWithChanges': 'text',
    'unchangeable': ['text'],
    'unknowns': ['text'],
    'forecast': 'text',
    'triggerSignal': 'text',
    'verifyFirst': ['text'],
    'safetyException': 'text',
    'fallback': 'text'
  },
  NodeKind.intervention: {
    'routeId': 'text',
    'obstacleId': 'text?',
    'action': 'text',
    'mechanism': 'text',
    'control': control,
    'cost': 'text',
    'conditions': ['text'],
    'risk': 'text',
    'implementationEvidence': 'text',
    'fallback': 'text',
    'reversible': 'bool'
  },
  NodeKind.interventionExecution: {
    'interventionId': 'text',
    'state': 'enum:executed,partly_executed,not_executed,unknown',
    'detail': 'note'
  },
  NodeKind.scene: {
    'routeId': 'text',
    'motiveIds': ['text'],
    'reframeIds': ['text'],
    'mode': 'enum:facts,future,future_obstacle,process,verify_first',
    'frames': [
      {
        'kind': 'enum:fact,future,obstacle,response',
        'text': 'text',
        'claimType': 'enum:fact,plausible,hypothetical',
        'evidenceIds': ['text']
      }
    ],
    'fieldCue': 'text',
    'ifThen': 'text',
    'fallback': 'text',
    'riskGate': safetyState,
    'durationSeconds': 'duration'
  },
  NodeKind.sceneFeedback: {
    'sceneId': 'text',
    'response': 'enum:relatable,inaccurate,too_strong,skip,approved',
    'comment': 'note'
  },
  NodeKind.plan: {
    'routeId': 'text',
    'sourceAnalysisIds?': ['text'],
    'motiveIds': ['text'],
    'sceneId': 'text?',
    'principleId': 'text?',
    'triggerSignal': 'text',
    'verifyFirst': ['text'],
    'ifThen': 'text',
    'fallback': 'text',
    'safetyException': 'text',
    'forecast': 'note',
    'interventionIds': ['text'],
    'intention': 'enum:conditional,tentative,undecided',
    'remindAt': 'timestamp?',
    'expiresAt': 'timestamp?',
    'userConfirmed': 'bool'
  },
  NodeKind.seal: {
    'planId': 'text',
    'snapshot': 'json',
    'hash': 'text',
    'nonce': 'text',
    'sealedAt': 'timestamp',
    'clockWarning': 'bool',
    'privacyRedacted?': 'bool'
  },
  NodeKind.trigger: {
    'planId': 'text?',
    'signal': 'text',
    'scheduledAt': 'timestamp?',
    'expiresAt': 'timestamp?',
    'verificationRequired': 'bool'
  },
  NodeKind.triggerCheck: {
    'triggerId': 'text',
    'state': 'enum:unconfirmed,confirmed,changed,expired,cancelled',
    'detail': 'note',
    'occurredAt': 'timestamp?'
  },
  NodeKind.reappraisal: {
    'triggerCheckId': 'text',
    'planId': 'text?',
    'changes': ['text'],
    'immediateMotive': 'note',
    'rememberedMotiveIds': ['text'],
    'safetyChanged': 'bool',
    'choice': 'enum:original,alternative,verify,pause,refuse,later,unrecorded',
    'routeId': 'text?'
  },
  NodeKind.awareness: {
    'motiveId': 'text',
    'stage': 'enum:presented,opened,noticed,recalled,accepted,used,unknown',
    'source': 'enum:device,self_report',
    'detail': 'note'
  },
  NodeKind.decision: {
    'routeId': 'text?',
    'declaration': 'text',
    'type': 'enum:prospective,retrospective,at_trigger',
    'userConfirmed': 'bool',
    'jamesCandidates': [
      {
        'mode':
            'enum:rational_weighing,external_chance,internal_impulse,value_shift,effort_to_maintain,unknown',
        'reason': 'text',
        'evidenceIds': ['text']
      }
    ],
    'unknowns': ['text']
  },
  NodeKind.opportunity: {
    'state': 'enum:yes,no,unclear',
    'actualRouteIds': ['text'],
    'knownRouteIds': ['text'],
    'conditions': 'note',
    'autonomy': 'enum:reasonably_free,pressured,coerced,unknown',
    'tradeoff': 'note',
    'evidenceQuality': 'enum:strong,limited,insufficient',
    'assessment': [
      {
        'dimension':
            'enum:observation_reliability,choice_availability,autonomy,deliberation_access,known_tradeoff,context_coverage,alternatives',
        'state': 'enum:supported,limited,unknown',
        'reason': 'text'
      }
    ]
  },
  NodeKind.attempt: {
    'routeId': 'text?',
    'decisionId': 'text?',
    'stage':
        'enum:preparation,departed,arrived,attempted,started_blocked,not_started,unknown',
    'detail': 'text'
  },
  NodeKind.observation: {
    'routeId': 'text?',
    'attemptId': 'text?',
    'actionState':
        'enum:completed,partial,changed,blocked,not_performed,unknown',
    'action': 'text',
    'externalOutcome': 'note',
    'outcomeState': 'enum:achieved,partial,not_achieved,pending,unknown',
    'feeling': 'note',
    'noticedMotiveIds': ['text'],
    'context': 'note',
    'domains': ['text'],
    'opportunityId': 'text?'
  },
  NodeKind.acquisition: {
    'observationId': 'text',
    'routeId': 'text?',
    'state': 'enum:acquired,partly_acquired,not_acquired,unknown',
    'detail': 'note'
  },
  NodeKind.experience: {
    'observationId': 'text',
    'routeId': 'text?',
    'wantIds': ['text'],
    'window': 'enum:initial,routine,sustained,custom',
    'benefits': ['text'],
    'costs': ['text'],
    'feeling': 'note',
    'conditions': 'note',
    'unknowns': ['text'],
    'reviewAt': 'timestamp?'
  },
  NodeKind.review: {
    'decisionModes?': [
      {
        'mode':
            'enum:rational_weighing,external_chance,internal_impulse,value_shift,effort_to_maintain,unknown',
        'reason': 'text',
        'evidenceIds': ['text'],
        'counterIds': ['text']
      }
    ],
    'behaviorQualification?': [
      {
        'dimension':
            'enum:observation_reliability,choice_availability,autonomy,deliberation_access,known_tradeoff,context_coverage,alternatives',
        'state': 'enum:supported,limited,unknown',
        'reason': 'text',
        'evidenceIds': ['text']
      }
    ],
    'observationIds': ['text'],
    'planId': 'text?',
    'summary': 'text',
    'earliestDeviation':
        'enum:intention_attempt,attempt_action,action_outcome,outcome_want_fit,none,unknown',
    'knownFacts': [
      {
        'claim': 'text',
        'evidenceIds': ['text']
      }
    ],
    'hypotheses': [
      {
        'mechanism': 'text',
        'claim': 'text',
        'status':
            'enum:required_by_rule,supported_contribution,plausible,unknown,contradicted',
        'evidenceIds': ['text'],
        'counterIds': ['text'],
        'confounders': ['text'],
        'falsifier': 'text'
      }
    ],
    'regretTypes': [
      'enum:information,strategy,execution,uncontrollable_loss,moral,anticipated,unknown'
    ],
    'revisedClaims': [
      {
        'nodeId': 'text',
        'direction': 'enum:supported,challenged,uncertain',
        'reason': 'text',
        'evidenceIds': ['text']
      }
    ],
    'unknowns': ['text'],
    'nextTest': 'text',
    'satisfactionGap': 'note',
    'alternativeExplanations': ['text']
  },
  NodeKind.repair: {
    'reviewId': 'text',
    'action': 'text',
    'why': 'text',
    'conditions': ['text'],
    'cost': 'text',
    'risks': 'text',
    'nextStep': 'text',
    'state': 'enum:proposed,accepted,completed,declined,unknown'
  },
  NodeKind.insight: {
    'claim': 'text',
    'category': 'enum:want,ability,boundary,method,process,fit',
    'contexts': ['text'],
    'alternativeExplanations': ['text'],
    'confounders': ['text'],
    'maturity':
        'enum:tentative,multiple_contexts,contradicted,insufficient_evidence',
    'falsifier': 'text',
    'nextTest': 'text',
    'reviewReason?': 'note',
    'unknowns': ['text']
  },
  NodeKind.manifestation: {
    'eventIds': ['text'],
    'wantIds': ['text'],
    'motiveIds': ['text'],
    'relation':
        'enum:expression_possible,multi_motive_possible,context_modulated,contradictory_evidence,independent_facet,unknown',
    'claim': 'text',
    'contexts': ['text'],
    'alternatives': ['text'],
    'nextTest': 'text'
  },
  NodeKind.principle: {
    'summary': 'text',
    'fieldCue?': 'text',
    'ifCondition': 'text',
    'thenAction': 'text',
    'exceptionRule': 'text',
    'contexts': ['text'],
    'maturity': 'enum:tentative,multiple_contexts,needs_review',
    'falsifier': 'text',
    'nextTest': 'text',
    'reviewReason?': 'note',
    'riskGate': safetyState,
    'insightIds': ['text']
  },
  NodeKind.principleApplication: {
    'principleId': 'text',
    'principleVersion': 'text',
    'triggerId': 'text?',
    'exposure':
        'enum:proposed,opened,accepted,declined,scheduled,delivered,unknown',
    'recall': 'enum:unknown,explicitly_recalled,rejected,context_changed',
    'application':
        'enum:unknown,applied_verified,applied_self_report,not_applied',
    'attemptIds': ['text'],
    'preparationIds?': ['text'],
    'observationIds': ['text'],
    'detail': 'note'
  },
  NodeKind.principleMatch: {
    'principleId': 'text',
    'routeIds': ['text'],
    'fit': 'enum:applicable,conditional,not_applicable,unknown',
    'reason': 'text',
    'changedConditions': ['text'],
    'riskGate': safetyState
  },
  NodeKind.changeability: {
    'factId': 'text',
    'routeId': 'text?',
    'classification': changeability,
    'timeReference': 'text',
    'contextRequirements': ['text'],
    'reason': 'text',
    'safeAlternatives': ['text'],
    'reviewCondition': 'text'
  },
  NodeKind.strengthMatch: {
    'routeId': 'text',
    'capabilityIds': ['text'],
    'requirementIds': ['text'],
    'supportVariantIds': ['text'],
    'claim': 'text',
    'state':
        'enum:demonstrated_strength,trainable_gap,fit_with_support,variable_state,task_mismatch,unknown',
    'nextTest': 'text',
    'riskGate': safetyState
  },
  NodeKind.boundaryReview: {
    'ownActions': ['text'],
    'otherAutonomy': ['text'],
    'verifiedObligations': ['text'],
    'unknownObligations': ['text'],
    'safeOptions': ['text'],
    'riskGate': safetyState,
    'nextVerification': 'text'
  },
  NodeKind.recommendation: {
    'scoredAt?': 'timestamp?',
    'expiresAt?': 'timestamp?',
    'method': 'enum:decisions,rules,unscored',
    'rubricVersion': 'text',
    'weights': ['weight'],
    'allFacets?': [
      {
        'motiveId': 'text',
        'facets': [
          {
            'dimension':
                'enum:personal_fit,evidence_quality,decision_materiality,context_relevance',
            'score': 'score?',
            'confidence': 'confidence?',
            'status': 'enum:scored,unknown,refused',
            'answerName': 'text'
          }
        ]
      }
    ],
    'ranked': [
      {
        'motiveId': 'text',
        'rank': 'positive',
        'priority': 'score?',
        'reason': 'text',
        'rule': 'text',
        'facets': [
          {
            'dimension':
                'enum:personal_fit,evidence_quality,decision_materiality,context_relevance',
            'score': 'score?',
            'confidence': 'confidence?',
            'status': 'enum:scored,unknown,refused',
            'answerName': 'text'
          }
        ]
      }
    ],
    'shortlistIds': ['text'],
    'nearMissIds': ['text'],
    'verifyFirstIds': ['text'],
    'message': 'note',
    'model': 'note',
    'snapshotHash': 'text',
    'unstable': 'bool'
  },
  NodeKind.feedback: {
    'targetId': 'text',
    'action':
        'enum:accept,reject,verify,edit,not_applicable,later,skip,independent,retire',
    'comment': 'note'
  },
  NodeKind.reminder: {
    'triggerId': 'text',
    'planId': 'text',
    'principleId': 'text?',
    'runId': 'text?',
    'sceneId': 'text?',
    'jobId': 'positive',
    'scheduledAt': 'timestamp',
    'state': 'enum:scheduled,denied,cancelled,opened,failed,unknown',
    'snapshotVersion': 'positive'
  },
  NodeKind.permission: {
    'failureCode?': 'text',
    'failedStage?': 'text',
    'analysisFingerprint?': 'text',
    'stage?': 'note',
    'completed?': 'bool',
    'purpose': 'enum:analysis,scoring,cross_case',
    'allowedIds': ['text'],
    'sourceCaseIds': ['text'],
    'sensitiveAllowed': 'bool',
    'granted': 'bool',
    'runId': 'text'
  },
  NodeKind.revision: {
    'targetId': 'text',
    'reason': 'text',
    'beforeIds': ['text'],
    'afterIds': ['text']
  },
};

void validateShape(dynamic value, dynamic shape, [String path = 'body']) {
  if (shape is Map) {
    if (value is! Map)
      throw MirrorProblem('$path 不是结构化对象', code: 'response_shape_invalid');
    final allowed = shape.keys
        .map((e) => e.toString().replaceFirst(RegExp(r'\?$'), ''))
        .toSet();
    if (value.keys.any((e) => !allowed.contains(e)))
      throw MirrorProblem('$path 包含未知字段', code: 'response_shape_invalid');
    for (final entry in shape.entries) {
      final raw = entry.key as String;
      final optional = raw.endsWith('?');
      final key = optional ? raw.substring(0, raw.length - 1) : raw;
      if (!value.containsKey(key)) {
        if (!optional)
          throw MirrorProblem('$path.$key 缺失', code: 'response_shape_invalid');
      } else {
        validateShape(value[key], entry.value, '$path.$key');
      }
    }
    return;
  }
  if (shape is List) {
    if (value is! List || value.length > 300)
      throw MirrorProblem('$path 列表无效', code: 'response_shape_invalid');
    for (var i = 0; i < value.length; i++) {
      validateShape(value[i], shape.single, '$path[$i]');
    }
    return;
  }
  var type = shape as String;
  if (type.endsWith('?')) {
    if (value == null) return;
    type = type.substring(0, type.length - 1);
  }
  var ok = true;
  if (type.startsWith('enum:')) {
    ok = value is String && type.substring(5).split(',').contains(value);
  } else {
    ok = switch (type) {
      'text' =>
        value is String && value.trim().isNotEmpty && value.length <= 8000,
      'note' => value is String && value.length <= 16000,
      'bool' => value is bool,
      'timestamp' => parseTime(value) != null,
      'score' => value is num && value.isFinite && value >= 0 && value <= 4,
      'confidence' ||
      'weight' =>
        value is num && value.isFinite && value >= 0 && value <= 1,
      'index' => value is num && value.isFinite && value >= 0 && value <= 100,
      'difficulty' => value is int && value >= 1 && value <= 5,
      'duration' => value is int && value >= 10 && value <= 90,
      'positive' => value is int && value > 0,
      'json' => value is Map && canonicalJson(value).length <= 1500000,
      _ => false,
    };
  }
  if (!ok)
    throw MirrorProblem('$path 的数据类型或状态无效', code: 'response_shape_invalid');
}

Json jsonSchema(dynamic shape) {
  if (shape is Map)
    return {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        for (final entry in shape.entries)
          entry.key.toString().replaceFirst(RegExp(r'\?$'), ''):
              jsonSchema(entry.value)
      },
      'required': shape.keys
          .map((e) => e.toString().replaceFirst(RegExp(r'\?$'), ''))
          .toList()
    };
  if (shape is List)
    return {
      'type': 'array',
      'items': jsonSchema(shape.single),
      'maxItems': 300
    };
  var type = shape as String;
  if (type.endsWith('?'))
    return {
      'anyOf': [
        jsonSchema(type.substring(0, type.length - 1)),
        {'type': 'null'}
      ]
    };
  if (type.startsWith('enum:'))
    return {'type': 'string', 'enum': type.substring(5).split(',')};
  if (type == 'json') return {'type': 'object'};
  if (type == 'bool') return {'type': 'boolean'};
  if (type == 'text' || type == 'note' || type == 'timestamp')
    return {
      'type': 'string',
      'maxLength': type == 'note' ? 16000 : 8000,
      if (type == 'text') 'minLength': 1
    };
  final max = switch (type) {
    'score' => 4,
    'index' => 100,
    'difficulty' => 5,
    'duration' => 90,
    'positive' => 2147483647,
    _ => 1
  };
  return {
    'type': {'difficulty', 'duration', 'positive'}.contains(type)
        ? 'integer'
        : 'number',
    'minimum': type == 'difficulty' || type == 'positive'
        ? 1
        : type == 'duration'
            ? 10
            : 0,
    'maximum': max
  };
}
