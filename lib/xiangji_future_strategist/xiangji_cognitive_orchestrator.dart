import 'dart:convert';

import 'xiangji_agent_service.dart';
import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_rev3_models.dart';
import 'xiangji_sck_runtime.dart';
import 'xiangji_state_machine.dart';

typedef XiangjiIdFactory = String Function(String prefix);
typedef XiangjiOrchestrationProgress = void Function(
  XiangjiOrchestrationState state,
);

/// Executes the Rev.3 AI-first route end-to-end. A deterministic local kernel
/// always produces a complete draft; configured model agents may improve that
/// draft, but provider failure never turns the experience back into a form.
class XiangjiCognitiveOrchestrator {
  XiangjiCognitiveOrchestrator({
    required XiangjiDao dao,
    required XiangjiAgentService agentService,
    required XiangjiIdFactory idFactory,
    XiangjiSckRuntime sck = const XiangjiSckRuntime(),
  })  : _dao = dao,
        _agentService = agentService,
        _idFactory = idFactory,
        _sck = sck;

  final XiangjiDao _dao;
  final XiangjiAgentService _agentService;
  final XiangjiIdFactory _idFactory;
  final XiangjiSckRuntime _sck;

  Future<XiangjiCouncilResult> consult({
    required String problemId,
    required String utterance,
    required bool authorizedSensitiveContext,
    List<String> attachmentRefs = const <String>[],
    String attachmentText = '',
    List<String> retrievableSourceRefs = const <String>[],
    String retrievableContext = '',
    bool forceStrategic = false,
    bool clarificationAnswer = false,
    XiangjiOrchestrationProgress? onProgress,
  }) async {
    await _dao.ensureSchema();
    final problem = await _dao.problem(problemId);
    if (problem == null) throw StateError('问题不存在或已删除。');
    var rawEventId = await _dao.problemRawEventId(problemId);
    if (utterance.trim() != problem.rawQuestion.trim()) {
      rawEventId = _idFactory('xf_event');
      await _dao.addProblemUtterance(
        eventId: rawEventId,
        experienceId: _idFactory('xf_experience'),
        problemId: problemId,
        text: utterance.trim(),
        contextText: <String>[
          utterance.trim(),
          if (attachmentText.trim().isNotEmpty) attachmentText.trim(),
        ].join('\n\n'),
        sourceRefs: attachmentRefs,
      );
    }
    if (clarificationAnswer) {
      await _dao.answerOpenClarification(
        problemId: problemId,
        answerRef: 'raw_event:$rawEventId',
      );
    }

    final historyRows = await _dao.experiencesForProblem(problemId);
    final historyContext = historyRows
        .map((row) => (row['content'] ?? '').toString().trim())
        .where((text) => text.isNotEmpty && text != utterance.trim())
        .take(12)
        .join('\n');
    final previousSituation = await _dao.latestSituationModel(
      objectType: 'problem',
      objectId: problemId,
    );
    final previousModelContext = previousSituation != null &&
            (previousSituation['state'] ?? '').toString() !=
                XiangjiSituationModelState.stale.wire
        ? (previousSituation['model_json'] ?? '').toString().trim()
        : '';
    final existingContext = <String>[
      attachmentText.trim(),
      if (historyContext.isNotEmpty) '【已有历史，不得重复询问】\n$historyContext',
      if (previousModelContext.isNotEmpty)
        '【上一版可修订态势模型】\n$previousModelContext',
      if (retrievableContext.trim().isNotEmpty)
        '【可检索的目标 / Todo / 已有数据】\n${retrievableContext.trim()}',
    ].where((text) => text.isNotEmpty).join('\n\n');
    var draft = _sck.buildLocalDraft(
      utterance,
      attachmentRefs: attachmentRefs,
      attachmentText: existingContext,
      forceStrategic: forceStrategic,
    );
    final firstGuard = _sck.evaluateAskUserGuard(draft.informationNeeds);
    final situationId = _idFactory('xf_situation');
    final version = await _dao.nextSituationModelVersion(
      objectType: 'problem',
      objectId: problemId,
    );
    final sourceRefs = <String>[
      'raw_event:$rawEventId',
      if (previousSituation != null)
        'situation_model:${previousSituation['id']}',
      ...attachmentRefs,
      ...retrievableSourceRefs,
    ];
    final agentSourceMaterial = existingContext.length <= 60000
        ? existingContext
        : existingContext.substring(0, 60000);
    await _dao.saveSituationModel(
      id: situationId,
      objectType: 'problem',
      objectId: problemId,
      version: version,
      state: XiangjiSituationModelState.raw,
      summary: '正在建立可修订态势模型',
      currentNeed: draft.need,
      model: draft.toMap(),
      sourceRefs: sourceRefs,
    );

    final plan = _sck.orchestrationPlan(majorDecision: draft.majorDecision);
    final effectivePlan = firstGuard.outcome == XiangjiAskUserOutcome.askOne
        ? plan
            .takeWhile((agent) => agent != XiangjiAgentId.problemFramer)
            .toList()
        : plan;
    final outputs = <String, Map<String, Object?>>{};
    final runRecordIds = <String>[];
    final agentRunRecordIds = <String, String>{};
    final warnings = <String>[];
    var executionFrozen = false;
    XiangjiOrchestrationState? lastProgress;

    for (final agent in effectivePlan) {
      final orchestrationState = _stateForAgent(agent, draft.majorDecision);
      if (orchestrationState != lastProgress) {
        onProgress?.call(orchestrationState);
        lastProgress = orchestrationState;
      }
      final started = DateTime.now().millisecondsSinceEpoch;
      final runRecordId = _idFactory('xf_agent_run');
      try {
        final result = await _agentService.run(XiangjiAgentRequest(
          requestId: _idFactory('xf_request'),
          task: utterance,
          agent: agent,
          problemId: problemId,
          problemState: _problemStateForAgent(agent),
          isMajorDecision: draft.majorDecision,
          isHighRisk: draft.highRisk,
          isIrreversible: draft.irreversible,
          authorizedSensitiveContext: authorizedSensitiveContext,
          additionalContext: <String, Object?>{
            'situation_model_id': situationId,
            'situation_draft': draft.toMap(),
            'source_material': agentSourceMaterial,
            'source_refs': sourceRefs,
            'prior_agent_outputs': outputs,
            'ask_user_guard': firstGuard.outcome.wire,
            'sck_rule_ids': XiangjiSckRuntime.rules.keys.toList(),
          },
        ));
        outputs[agent.code] = result.output;
        executionFrozen = executionFrozen || result.executionFrozen;
        await _dao.saveAgentRun(<String, Object?>{
          'id': runRecordId,
          'problem_id': problemId,
          'campaign_id': '',
          'agent_role': agent.code,
          'orchestration_state': orchestrationState.wire,
          'model_run_id': result.modelRunId,
          'input_refs_json': jsonEncode(sourceRefs),
          'output_refs_json': jsonEncode(<String>[result.traceId]),
          'output_json': jsonEncode(result.output),
          'status': result.localOnly ? 'LOCAL_COMPLETE' : 'COMPLETE',
          'started_at_ms': started,
          'ended_at_ms': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (error) {
        warnings.add('${agent.code} ${agent.label}：${_safeError(error)}');
        await _dao.saveAgentRun(<String, Object?>{
          'id': runRecordId,
          'problem_id': problemId,
          'campaign_id': '',
          'agent_role': agent.code,
          'orchestration_state': orchestrationState.wire,
          'model_run_id': '',
          'input_refs_json': jsonEncode(sourceRefs),
          'output_refs_json': '[]',
          'output_json': '{}',
          'status': 'FAILED_LOCAL_DRAFT_USED',
          'started_at_ms': started,
          'ended_at_ms': DateTime.now().millisecondsSinceEpoch,
        });
      }
      runRecordIds.add(runRecordId);
      agentRunRecordIds[agent.code] = runRecordId;
    }

    draft = draft.mergeAgentOutputs(outputs);
    final guard = _sck.evaluateAskUserGuard(draft.informationNeeds);
    final clarification = guard.outcome == XiangjiAskUserOutcome.askOne
        ? guard.selectedNeed?.question ?? ''
        : '';
    final finalSituationState = clarification.isNotEmpty
        ? XiangjiSituationModelState.needsClarification
        : XiangjiSituationModelState.framed;
    const situationMachine = XiangjiSituationModelStateMachine();
    final stateHistory = <XiangjiSituationModelState>[
      XiangjiSituationModelState.raw,
    ];
    var currentSituationState = XiangjiSituationModelState.raw;
    void advanceSituation(
      XiangjiSituationModelState target,
      XiangjiSituationModelTransitionContext context,
    ) {
      final transition = situationMachine.evaluate(
        currentSituationState,
        target,
        context,
      );
      transition.requireAllowed();
      currentSituationState = target;
      stateHistory.add(target);
    }
    advanceSituation(
      XiangjiSituationModelState.parsed,
      const XiangjiSituationModelTransitionContext(
        rawSourceSaved: true,
        experienceAndInferenceSeparated: true,
      ),
    );
    advanceSituation(
      XiangjiSituationModelState.judged,
      const XiangjiSituationModelTransitionContext(
        judgmentCompleted: true,
      ),
    );
    advanceSituation(
      XiangjiSituationModelState.grounded,
      const XiangjiSituationModelTransitionContext(
        groundingCompleted: true,
      ),
    );
    advanceSituation(
      finalSituationState,
      XiangjiSituationModelTransitionContext(
        askUserGuardAllowsProgress: clarification.isEmpty,
        problemFramed: draft.trueProblem.trim().isNotEmpty,
      ),
    );
    await _dao.saveSituationModel(
      id: situationId,
      objectType: 'problem',
      objectId: problemId,
      version: version,
      state: finalSituationState,
      summary: draft.summary,
      currentNeed: draft.need,
      model: <String, Object?>{
        ...draft.toMap(),
        'ask_user_guard': guard.outcome.wire,
        'orchestration_plan': effectivePlan.map((agent) => agent.code).toList(),
        'state_history':
            stateHistory.map((state) => state.wire).toList(),
        'sck_rules': XiangjiSckRuntime.rules.keys.toList(),
      },
      sourceRefs: sourceRefs,
    );

    await _dao.supersedeOpenInformationNeeds(problemId);
    await _persistInformationNeeds(
      problemId: problemId,
      situationId: situationId,
      needs: draft.informationNeeds,
      selectedNeedId: guard.selectedNeed?.id ?? '',
    );
    if (clarification.isNotEmpty && guard.selectedNeed != null) {
      await _dao.saveClarificationQuestion(<String, Object?>{
        'id': _idFactory('xf_question'),
        'problem_id': problemId,
        'information_need_id':
            '$situationId-${guard.selectedNeed!.id}',
        'wording': clarification,
        'burden_estimate': guard.selectedNeed!.userBurden,
        'asked_at_ms': DateTime.now().millisecondsSinceEpoch,
        'answer_ref': '',
        'answered_at_ms': 0,
        'status': 'ASKED',
      });
    }

    await _persistProblemWorkbench(
      problemId: problemId,
      rawEventId: rawEventId,
      situationId: situationId,
      draft: draft,
      stopForClarification: clarification.isNotEmpty,
      agentRunId:
          agentRunRecordIds['A00'] ?? agentRunRecordIds['A02'] ?? '',
      sourceRefs: sourceRefs,
    );
    await _persistReasoning(
      problemId: problemId,
      situationId: situationId,
      draft: draft,
      agentRunIds: agentRunRecordIds,
    );

    var campaignId = '';
    var actionId = '';
    if (clarification.isEmpty && !executionFrozen) {
      if (draft.majorDecision) {
        campaignId = await _persistStrategicCampaign(
          problemId: problemId,
          draft: draft,
          situationId: situationId,
        );
      }
      actionId = await _persistCurrentAction(
        problemId: problemId,
        campaignId: campaignId,
        situationId: situationId,
        draft: draft,
      );
      if (actionId.isNotEmpty &&
          guard.outcome == XiangjiAskUserOutcome.scoutInReality) {
        await _dao.linkScoutingInformationNeeds(problemId, actionId);
      }
    }
    if (executionFrozen) {
      await _dao.saveAlert(
        id: _idFactory('xf_alert'),
        state: XiangjiAlertState.red,
        alertType: 'sck_high_risk_freeze',
        reason: '当前为不可逆高风险且认识债务高；Rev.3 已冻结推进型行动。',
        defaultAction: '先补证、降低不可逆性，并在需要时寻求专业复核。',
        problemId: problemId,
      );
    } else {
      await _dao.resolveOpenAlertsOfType(
        'sck_high_risk_freeze',
        problemId: problemId,
      );
    }

    final decisionDraftId = _idFactory('xf_decision_draft');
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.saveDecisionDraft(<String, Object?>{
      'id': decisionDraftId,
      'problem_id': problemId,
      'campaign_id': campaignId,
      'action_id': actionId,
      'situation_model_id': situationId,
      'true_problem': draft.trueProblem,
      'recommendation': executionFrozen
          ? '先冻结不可逆承诺，补证、降风险，并在需要时寻求专业复核。'
          : clarification.isEmpty
              ? draft.recommendation
              : '先补充这一项决定性信息，军师会自动继续。',
      'judgment': draft.judgment,
      'why_text': draft.why,
      'current_action': clarification.isEmpty && !executionFrozen
          ? draft.currentAction
          : '',
      'change_signals': draft.changeSignals,
      'epistemic_status': draft.epistemicStatus,
      'clarification_question': clarification,
      'options_json': jsonEncode(draft.strategyOptions),
      'uncertainty_json': jsonEncode(<String, Object?>{
        'unknowns': draft.unknowns,
        'model_is_revisable': true,
        'systematicity_is_not_certainty': true,
      }),
      'weakest_premise':
          draft.redTeam.isEmpty ? '' : draft.redTeam.first,
      'unresolved_items_json': jsonEncode(draft.unknowns),
      'agent_run_id': agentRunRecordIds['A00'] ?? '',
      'user_status': XiangjiDecisionDraftStatus.proposed.wire,
      'created_at_ms': now,
      'updated_at_ms': now,
    });

    return XiangjiCouncilResult(
      problemId: problemId,
      campaignId: campaignId,
      actionId: actionId,
      situationModelId: situationId,
      decisionDraftId: decisionDraftId,
      outcome: clarification.isNotEmpty
          ? XiangjiAskUserOutcome.askOne
          : XiangjiAskUserOutcome.userDecision,
      clarificationQuestion: clarification,
      draft: draft,
      agentRunIds: runRecordIds,
      warnings: warnings,
      executionFrozen: executionFrozen,
    );
  }

  Future<void> _persistInformationNeeds({
    required String problemId,
    required String situationId,
    required List<XiangjiInformationNeed> needs,
    required String selectedNeedId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var index = 0; index < needs.length; index++) {
      final need = needs[index];
      await _dao.saveInformationNeed(<String, Object?>{
        'id': '$situationId-${need.id}',
        'problem_id': problemId,
        'situation_model_id': situationId,
        'question': need.question,
        'missing_field': need.missingField,
        'missing': need.missing ? 1 : 0,
        'decision_impact': need.decisionImpact.wire,
        'can_infer': need.canInfer ? 1 : 0,
        'infer_source_refs_json': jsonEncode(need.inferSourceRefs),
        'scouting_possible': need.scoutingPossible ? 1 : 0,
        'scouting_option': need.scoutingOption,
        'evsi_rank': need.expectedValueOfInformation,
        'expected_value': need.expectedValueOfInformation.toString(),
        'user_burden': need.userBurden,
        'selected_for_question': need.id == selectedNeedId ? 1 : 0,
        'status': 'OPEN',
        'created_at_ms': now,
        'updated_at_ms': now,
      });
    }
  }

  Future<void> _persistProblemWorkbench({
    required String problemId,
    required String rawEventId,
    required String situationId,
    required XiangjiSituationDraft draft,
    required bool stopForClarification,
    required String agentRunId,
    required List<String> sourceRefs,
  }) async {
    await _dao.retireGeneratedProblemItems(problemId);
    final sourceRef = 'situation:$situationId';
    var order = 0;
    Future<void> addItems(String kind, List<String> values,
        {bool critical = false}) async {
      for (final value in values) {
        if (value.trim().isEmpty) continue;
        await _dao.addProblemItem(
          id: _idFactory('xf_item'),
          problemId: problemId,
          kind: kind,
          text: value.trim(),
          sourceRef: sourceRef,
          critical: critical,
          sortOrder: order++,
          data: <String, Object?>{
            'origin': 'ai_prefill',
            'situation_model_id': situationId,
            'derived_by_agent_run': agentRunId,
            'user_editable': true,
          },
        );
      }
    }

    await addItems('known', draft.observedFacts);
    await addItems('body_experience', draft.bodyExperiences);
    await addItems('user_interpretation', draft.userInterpretations);
    await addItems('prediction', draft.predictions);
    await addItems('assumption', draft.assumptions, critical: true);
    await addItems('constraint', draft.constraints, critical: true);
    await addItems('unknown', draft.unknowns, critical: true);
    await addItems('causal_hypothesis', draft.causalHypotheses);
    await addItems('sub_goal', draft.subGoals);
    for (final operator in draft.operators.take(5)) {
      final name = (operator['name'] ?? operator['title'] ?? '').toString();
      if (name.trim().isEmpty) continue;
      await _dao.addProblemItem(
        id: _idFactory('xf_item'),
        problemId: problemId,
        kind: 'operator_candidate',
        text: name,
        sourceRef: sourceRef,
        sortOrder: order++,
        data: <String, Object?>{
          ...operator,
          'origin': 'ai_prefill',
          'situation_model_id': situationId,
          'derived_by_agent_run': agentRunId,
        },
      );
    }

    for (final experience in draft.bodyExperiences) {
      await _dao.addExperience(
        id: _idFactory('xf_experience'),
        rawEventId: rawEventId,
        problemId: problemId,
        type: 'ai_extracted_experience',
        content: experience,
        isUserWording: false,
        observationConditions: <String, Object?>{
          'source_ref': 'raw_event:$rawEventId',
          'extraction': 'ai_candidate',
        },
      );
    }
    for (final inference in <MapEntry<String, String>>[
      MapEntry<String, String>('true_problem', draft.trueProblem),
      MapEntry<String, String>('judgment', draft.judgment),
      MapEntry<String, String>('recommendation', draft.recommendation),
    ]) {
      final inferenceId = _idFactory('xf_inference');
      await _dao.saveAiInference(<String, Object?>{
        'id': inferenceId,
        'situation_model_id': situationId,
        'problem_id': problemId,
        'text': inference.value,
        'inference_type': inference.key,
        'source_refs_json': jsonEncode(sourceRefs),
        'agent_run_id': agentRunId,
        'epistemic_status': draft.epistemicStatus,
        'user_confirmed': 0,
        'status': 'ACTIVE',
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
      await _dao.addClaim(
        id: _idFactory('xf_claim'),
        problemId: problemId,
        text: inference.value,
        claimType: inference.key,
        state: draft.epistemicStatus == 'EPISTEMIC_DEBT'
            ? XiangjiClaimState.epistemicDebt
            : XiangjiClaimState.provisional,
        importance: inference.key == 'judgment' ? 'high' : 'medium',
        sourceKind: 'ai_inference',
        sourceRef: inferenceId,
        userConfirmed: false,
        systematicity: 'structured',
      );
    }
    for (final raw in draft.causalHypotheses) {
      final sides = raw.split('|').map((item) => item.trim()).toList();
      if (sides.isEmpty || sides.first.isEmpty) continue;
      await _dao.addCausalHypothesis(
        id: _idFactory('xf_causal'),
        problemId: problemId,
        causeCandidate: sides.first,
        differentiatingEvidenceNeeded: sides.length > 1
            ? sides[1]
            : '需要能区分该解释与其他候选原因的现实材料',
      );
    }

    await _moveProblemToModelingState(
      problemId,
      stopForClarification: stopForClarification,
    );
    if (stopForClarification) return;
    await _dao.updateProblemDefinition(
      id: problemId,
      reframedQuestion: draft.trueProblem,
      goalText: draft.goal,
      valueLink: draft.valueLink,
      successCriteria: draft.successCriteria,
      exitCriteria: draft.exitCriteria,
      reviewAtMs: DateTime.now()
          .add(Duration(days: draft.majorDecision ? 7 : 3))
          .millisecondsSinceEpoch,
    );
    await _dao.saveConceptDefinition(
      conceptId: 'xf_concept_${_stableSlug(draft.need)}',
      versionId: _idFactory('xf_concept_version'),
      name: draft.need.length > 36 ? draft.need.substring(0, 36) : draft.need,
      definition: '围绕当前需要形成的可修订工作概念，不等于新的外部事实。',
      scope: problemId,
      observableCriteria: <String>[
        draft.successCriteria,
        draft.changeSignals,
      ],
      supportRefs: sourceRefs,
      counterexampleRefs: draft.counterexamples,
      changeReason: 'Rev.3 AI 预填；等待用户采用、修改或反对',
      origin: 'ai_inference',
    );
  }

  Future<void> _moveProblemToModelingState(
    String problemId, {
    required bool stopForClarification,
  }) async {
    var problem = await _dao.problem(problemId);
    if (problem == null) return;
    const machine = XiangjiProblemStateMachine();
    Future<void> move(
      XiangjiProblemState target,
      XiangjiProblemTransitionContext context,
    ) async {
      final current = problem;
      if (current == null) return;
      machine.evaluate(current.state, target, context).requireAllowed();
      await _dao.updateProblemState(
        problemId,
        target,
        actor: 'ai_orchestrator',
      );
      problem = await _dao.problem(problemId);
    }
    if (problem?.state == XiangjiProblemState.actionReady) {
      await _dao.invalidateReadyActions(problemId);
      await move(
        XiangjiProblemState.solving,
        const XiangjiProblemTransitionContext(
          conceptsReviewed: true,
          reframedQuestionConfirmed: true,
        ),
      );
    }
    if (problem?.state == XiangjiProblemState.executing ||
        problem?.state == XiangjiProblemState.verifying) {
      await move(
        XiangjiProblemState.backtracking,
        const XiangjiProblemTransitionContext(),
      );
    }
    if (problem?.state == XiangjiProblemState.backtracking ||
        problem?.state == XiangjiProblemState.resolved ||
        problem?.state == XiangjiProblemState.archived) {
      await move(
        XiangjiProblemState.formalizing,
        const XiangjiProblemTransitionContext(rawMaterialSaved: true),
      );
    }
    if (problem?.state == XiangjiProblemState.captured) {
      await move(
        XiangjiProblemState.formalizing,
        const XiangjiProblemTransitionContext(rawMaterialSaved: true),
      );
    }
    if (problem?.state == XiangjiProblemState.formalizing) {
      await move(
        XiangjiProblemState.epistemicReview,
        const XiangjiProblemTransitionContext(
          experienceAndInterpretationSeparated: true,
        ),
      );
    }
    if (stopForClarification) return;
    if (problem?.state == XiangjiProblemState.epistemicReview) {
      await move(
        XiangjiProblemState.conceptReview,
        const XiangjiProblemTransitionContext(
          groundingReviewed: true,
          criticalUnknownHandled: true,
        ),
      );
    }
    if (problem?.state == XiangjiProblemState.conceptReview) {
      await move(
        XiangjiProblemState.solving,
        const XiangjiProblemTransitionContext(
          conceptsReviewed: true,
          reframedQuestionConfirmed: true,
        ),
      );
    }
  }

  Future<void> _persistReasoning({
    required String problemId,
    required String situationId,
    required XiangjiSituationDraft draft,
    required Map<String, String> agentRunIds,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final artifacts = <String, Object?>{
      'causal_map': <String, Object?>{
        'hypotheses': draft.causalHypotheses,
        'sck_rules': const <String>['SCK-003', 'SCK-004'],
      },
      'judgment_map': <String, Object?>{
        'purpose': draft.goal,
        'similarities': draft.relevantSimilarities,
        'differences': draft.relevantDifferences,
        'counterexamples': draft.counterexamples,
      },
      'grounding_chain': <String, Object?>{
        'summary': draft.groundingReason,
        'unknowns': draft.unknowns,
        'sck_rules': const <String>['SCK-006', 'SCK-007', 'SCK-008', 'SCK-009', 'SCK-010', 'SCK-011'],
      },
      'problem_tree': <String, Object?>{
        'true_problem': draft.trueProblem,
        'goal': draft.goal,
        'gap': draft.targetGap,
        'sub_goals': draft.subGoals,
        'operators': draft.operators,
      },
      if (draft.majorDecision)
        'strategy_matrix': <String, Object?>{
          'options': draft.strategyOptions,
          'recommended': draft.recommendation,
        },
      if (draft.majorDecision)
        'red_team': <String, Object?>{'findings': draft.redTeam},
      if (draft.majorDecision)
        'war_game': <String, Object?>{
          'base_case': draft.prediction,
          'adverse_case': draft.redTeam,
          'change_signals': draft.changeSignals,
        },
    };
    for (final entry in artifacts.entries) {
      await _dao.saveReasoningArtifact(<String, Object?>{
        'id': _idFactory('xf_artifact'),
        'problem_id': problemId,
        'campaign_id': '',
        'situation_model_id': situationId,
        'agent_run_id': _artifactRunId(entry.key, agentRunIds),
        'kind': entry.key,
        'json_payload': jsonEncode(entry.value),
        'status': 'ACTIVE',
        'created_at_ms': now,
      });
    }
    await _dao.saveJudgment(<String, Object?>{
      'id': _idFactory('xf_judgment'),
      'problem_id': problemId,
      'situation_model_id': situationId,
      'purpose_scope': draft.goal,
      'compared_cases_json': jsonEncode(draft.observedFacts),
      'relevant_similarities_json': jsonEncode(draft.relevantSimilarities),
      'relevant_differences_json': jsonEncode(draft.relevantDifferences),
      'counterexamples_json': jsonEncode(draft.counterexamples),
      'conclusion': draft.judgment,
      'agent_run_id': agentRunIds['A02'] ?? '',
      'state': XiangjiJudgmentState.draft.wire,
      'created_at_ms': now,
      'updated_at_ms': now,
    });
  }

  Future<String> _persistStrategicCampaign({
    required String problemId,
    required XiangjiSituationDraft draft,
    required String situationId,
  }) async {
    final problem = await _dao.problem(problemId);
    var campaignId = problem?.campaignId ?? '';
    final linkedCampaign = campaignId.isEmpty
        ? null
        : await _dao.campaign(campaignId);
    if (campaignId.isNotEmpty &&
        (linkedCampaign == null ||
            <XiangjiCampaignState>{
          XiangjiCampaignState.retreat,
          XiangjiCampaignState.won,
          XiangjiCampaignState.lost,
          XiangjiCampaignState.closed,
            }.contains(linkedCampaign.state))) {
      campaignId = '';
    }
    if (campaignId.isEmpty) {
      campaignId = _idFactory('xf_campaign');
      final campaigns = await _dao.campaigns();
      await _dao.createCampaign(
        id: campaignId,
        title: draft.need.length > 32 ? '${draft.need.substring(0, 32)}…' : draft.need,
        northStar: draft.goal,
        strategicValue: draft.valueLink,
        isPrimary: campaigns.isEmpty,
      );
      await _dao.linkProblemCampaign(problemId, campaignId);
    }
    await _dao.updateCampaign(
      campaignId,
      <String, Object?>{
        'north_star': draft.goal,
        'grand_strategy': draft.recommendation,
        'strategic_value': draft.valueLink,
        'war_worthiness': draft.recommendation,
        'victory_criteria': draft.successCriteria,
        'exit_criteria': draft.exitCriteria,
        'resource_budget_json': jsonEncode(const <String, Object?>{
          'mode': 'bounded_commitment',
          'time': '先投入一个可复核周期',
          'money': '不超过用户可承受上限',
          'reserve': '保留退出与恢复资源',
        }),
        'review_at_ms': DateTime.now()
            .add(const Duration(days: 7))
            .millisecondsSinceEpoch,
        'user_confirmed': 0,
      },
      createVersion: true,
    );
    final existing = await _dao.strategyOptions(campaignId);
    final nextVersion = existing.isEmpty
        ? 1
        : existing
                .map((row) => (row['version_no'] as num?)?.toInt() ?? 1)
                .reduce((a, b) => a > b ? a : b) +
            1;
    for (final option in draft.strategyOptions.take(5)) {
      await _dao.addStrategyOption(<String, Object?>{
        'id': _idFactory('xf_strategy'),
        'campaign_id': campaignId,
        'name': (option['name'] ?? '候选路线').toString(),
        'strategy_type': (option['type'] ?? 'candidate').toString(),
        'benefits_json': jsonEncode(option['benefits'] ?? const <Object?>[]),
        'costs_json': jsonEncode(option['costs'] ?? const <Object?>[]),
        'opportunity_cost':
            (option['opportunity_cost'] ?? '').toString(),
        'reversibility': (option['reversibility'] ?? 'unknown').toString(),
        'key_assumptions_json':
            jsonEncode(option['assumptions'] ?? const <Object?>[]),
        'stop_conditions_json':
            jsonEncode(option['stop_conditions'] ?? const <Object?>[]),
        'evidence_level': 'hypothesis',
        'selected': 0,
        'version_no': nextVersion,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
    }
    for (var index = 0; index < draft.unknowns.length; index++) {
      await _dao.addCampaignIntel(<String, Object?>{
        'id': _idFactory('xf_intel'),
        'campaign_id': campaignId,
        'kind': 'critical_unknown',
        'text': draft.unknowns[index],
        'source_ref': 'situation:$situationId',
        'source_quality': 'ai_identified_gap',
        'freshness': 'current',
        'conflict_of_interest': '',
        'epistemic_status': 'SCOUTING',
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
    }
    for (final finding in draft.redTeam) {
      await _dao.addCampaignIntel(<String, Object?>{
        'id': _idFactory('xf_intel'),
        'campaign_id': campaignId,
        'kind': 'red_team_review',
        'text': finding,
        'source_ref': 'situation:$situationId',
        'source_quality': 'ai_hypothesis',
        'freshness': 'current',
        'conflict_of_interest': '',
        'epistemic_status': XiangjiClaimState.provisional.wire,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final contingencies = <String, Map<String, String>>{
      'risk': <String, String>{
        'trigger': draft.changeSignals,
        'action': '暂停加码，重新核对最脆弱前提与现实根据。',
      },
      'retreat': <String, String>{
        'trigger': draft.exitCriteria,
        'action': '保全剩余资源，停止原路线并进入战史复盘。',
      },
      'recovery': <String, String>{
        'trigger': '现实结果与事前预测相反',
        'action': '保留旧预测，回溯 Operator / Gap / Problem 并重算。',
      },
      if (draft.strategyOptions.any(
        (option) => option['type'] == 'opportunity_concentration',
      ))
        'opportunity': <String, String>{
          'trigger': '机会窗口、资源上限和退出路径同时成立',
          'action': '发起快速军议，在限额周期内集中主力。',
        },
    };
    for (final entry in contingencies.entries) {
      await _dao.saveContingency(<String, Object?>{
        'id': '$campaignId-rev3-${entry.key}',
        'campaign_id': campaignId,
        'kind': entry.key,
        'trigger_expression': entry.value['trigger']!,
        'action_plan': entry.value['action']!,
        'active': 1,
        'created_at_ms': now,
      });
    }
    await _dao.saveIndicator(<String, Object?>{
      'id': '$campaignId-rev3-leading',
      'campaign_id': campaignId,
      'indicator_type': 'leading',
      'metric': '能区分战略路线的独立现实证据数',
      'threshold_text': '>= 1',
      'direction': 'up',
      'window_text': '当前可复核周期',
      'latest_value': null,
      'latest_at_ms': null,
      'created_at_ms': now,
    });
    await _dao.saveIndicator(<String, Object?>{
      'id': '$campaignId-rev3-lagging',
      'campaign_id': campaignId,
      'indicator_type': 'lagging',
      'metric': draft.successCriteria,
      'threshold_text': '满足胜利判据',
      'direction': 'up',
      'window_text': '战役复核周期',
      'latest_value': null,
      'latest_at_ms': null,
      'created_at_ms': now,
    });
    await _advanceCampaignToDecision(campaignId);
    return campaignId;
  }

  Future<void> _advanceCampaignToDecision(String campaignId) async {
    const machine = XiangjiCampaignStateMachine();
    for (var step = 0; step < 10; step++) {
      final campaign = await _dao.campaign(campaignId);
      if (campaign == null) throw StateError('战役不存在。');
      if (campaign.state == XiangjiCampaignState.decision) return;
      final options = await _dao.strategyOptions(campaignId);
      final intel = await _dao.campaignIntel(campaignId);
      final target = switch (campaign.state) {
        XiangjiCampaignState.idea => XiangjiCampaignState.warWorthiness,
        XiangjiCampaignState.warWorthiness => XiangjiCampaignState.intel,
        XiangjiCampaignState.intel => XiangjiCampaignState.planning,
        XiangjiCampaignState.planning => XiangjiCampaignState.redTeam,
        XiangjiCampaignState.redTeam => XiangjiCampaignState.decision,
        XiangjiCampaignState.prepare => XiangjiCampaignState.hold,
        XiangjiCampaignState.executing => XiangjiCampaignState.adjust,
        XiangjiCampaignState.hold => XiangjiCampaignState.intel,
        XiangjiCampaignState.adjust => XiangjiCampaignState.planning,
        _ => throw StateError('当前战役已结束，需要新建战役版本。'),
      };
      final context = XiangjiCampaignTransitionContext(
        worthinessReviewed: campaign.warWorthiness.trim().isNotEmpty,
        victoryAndExitCriteriaDefined:
            campaign.victoryCriteria.trim().isNotEmpty &&
                campaign.exitCriteria.trim().isNotEmpty,
        resourceBudgetDefined: campaign.resourceBudget.isNotEmpty,
        criticalUnknownsHandled: !intel.any(
          (row) =>
              row['kind'] == 'critical_unknown' &&
              row['epistemic_status'] == 'UNRESOLVED',
        ),
        strategyOptionCount: options.length,
        redTeamComplete: intel.any(
          (row) => row['kind'] == 'red_team_review',
        ),
      );
      machine.evaluate(campaign.state, target, context).requireAllowed();
      await _dao.updateCampaign(
        campaignId,
        <String, Object?>{'state': target.wire},
        createVersion: target == XiangjiCampaignState.planning,
      );
    }
    throw StateError('战略编排未能到达用户决策门。');
  }

  Future<String> _persistCurrentAction({
    required String problemId,
    required String campaignId,
    required String situationId,
    required XiangjiSituationDraft draft,
  }) async {
    if (!_sck.operatorHasMechanism(draft)) return '';
    await _dao.invalidateReadyActions(problemId);
    await _dao.addProblemItem(
      id: _idFactory('xf_item'),
      problemId: problemId,
      kind: 'gap',
      text: draft.targetGap,
      sourceRef: 'situation:$situationId',
      critical: true,
      data: <String, Object?>{'origin': 'ai_prefill'},
    );
    await _dao.addProblemItem(
      id: _idFactory('xf_item'),
      problemId: problemId,
      kind: 'operator',
      text: draft.currentAction,
      sourceRef: 'situation:$situationId',
      critical: true,
      data: <String, Object?>{
        'target_gap': draft.targetGap,
        'mechanism': draft.operatorMechanism,
        'strategic_meaning': draft.strategicMeaning,
        'grounding_reason': draft.groundingReason,
        'origin': 'ai_prefill',
      },
    );
    final actionId = _idFactory('xf_action');
    await _dao.createAction(
      id: actionId,
      title: draft.currentAction,
      problemId: problemId,
      campaignId: campaignId,
      prediction: draft.prediction,
      expectedMinutes: draft.expectedMinutes,
      whyChain: <String, Object?>{
        'strategic_meaning': draft.strategicMeaning,
        'key_gap': draft.targetGap,
        'operator_mechanism': draft.operatorMechanism,
        'epistemic_grounding': draft.groundingReason,
        'situation_model_id': situationId,
        'generated_by_ai': true,
      },
    );
    final problem = await _dao.problem(problemId);
    if (problem?.state == XiangjiProblemState.solving) {
      const machine = XiangjiProblemStateMachine();
      machine
          .evaluate(
            problem!.state,
            XiangjiProblemState.actionReady,
            const XiangjiProblemTransitionContext(
              goalCriteriaDefined: true,
              operatorSelected: true,
            ),
          )
          .requireAllowed();
      await _dao.updateProblemState(
        problemId,
        XiangjiProblemState.actionReady,
        actor: 'ai_orchestrator',
      );
    }
    return actionId;
  }

  XiangjiOrchestrationState _stateForAgent(
    XiangjiAgentId agent,
    bool majorDecision,
  ) =>
      switch (agent) {
        XiangjiAgentId.epistemicAuditor ||
        XiangjiAgentId.causalAnalyst ||
        XiangjiAgentId.judgmentEngine ||
        XiangjiAgentId.groundingAuditor =>
          XiangjiOrchestrationState.cognitiveModeling,
        XiangjiAgentId.problemFramer || XiangjiAgentId.solver =>
          XiangjiOrchestrationState.problemSolving,
        XiangjiAgentId.strategist || XiangjiAgentId.redTeam =>
          XiangjiOrchestrationState.strategicCouncil,
        XiangjiAgentId.chiefStrategist => majorDecision
            ? XiangjiOrchestrationState.strategicCouncil
            : XiangjiOrchestrationState.problemSolving,
        XiangjiAgentId.actionOfficer =>
          XiangjiOrchestrationState.actionCompression,
        XiangjiAgentId.reviewHistorian =>
          XiangjiOrchestrationState.realityReconciliation,
        XiangjiAgentId.monitor || XiangjiAgentId.knowledgeRouter =>
          XiangjiOrchestrationState.backgroundWatch,
      };

  XiangjiProblemState _problemStateForAgent(XiangjiAgentId agent) =>
      switch (agent) {
        XiangjiAgentId.epistemicAuditor || XiangjiAgentId.causalAnalyst =>
          XiangjiProblemState.formalizing,
        XiangjiAgentId.judgmentEngine ||
        XiangjiAgentId.groundingAuditor =>
          XiangjiProblemState.epistemicReview,
        XiangjiAgentId.problemFramer => XiangjiProblemState.conceptReview,
        XiangjiAgentId.solver ||
        XiangjiAgentId.strategist ||
        XiangjiAgentId.redTeam ||
        XiangjiAgentId.chiefStrategist =>
          XiangjiProblemState.solving,
        XiangjiAgentId.actionOfficer => XiangjiProblemState.actionReady,
        XiangjiAgentId.reviewHistorian => XiangjiProblemState.verifying,
        XiangjiAgentId.monitor || XiangjiAgentId.knowledgeRouter =>
          XiangjiProblemState.solving,
      };

  String _artifactRunId(String kind, Map<String, String> agentRunIds) =>
      switch (kind) {
        'causal_map' => agentRunIds['A04'] ?? '',
        'judgment_map' => agentRunIds['A02'] ?? '',
        'grounding_chain' => agentRunIds['A03'] ?? '',
        'problem_tree' => agentRunIds['A06'] ?? '',
        'strategy_matrix' => agentRunIds['A07'] ?? '',
        'red_team' || 'war_game' => agentRunIds['A08'] ?? '',
        _ => '',
      };

  String _stableSlug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final normalized = slug.isEmpty ? 'current_need' : slug;
    return normalized.length > 48 ? normalized.substring(0, 48) : normalized;
  }

  String _safeError(Object error) {
    final value = error.toString();
    return value.length <= 240 ? value : value.substring(0, 240);
  }
}
