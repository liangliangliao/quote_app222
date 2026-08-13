import 'dart:convert';

import 'xiangji_agent_service.dart';
import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_persistent_solver.dart';
import 'xiangji_rev3_models.dart';
import 'xiangji_rev4_models.dart';
import 'xiangji_sck_runtime.dart';
import 'xiangji_state_machine.dart';

typedef XiangjiIdFactory = String Function(String prefix);
typedef XiangjiOrchestrationProgress = void Function(
  XiangjiOrchestrationState state,
);

/// Executes the Rev.5.2 AI-first route end-to-end. A deterministic local kernel
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
    XiangjiInputClassification? classification,
    bool userDoesNotKnow = false,
    bool realityContradicted = false,
    bool methodTrainingEnabled = false,
    XiangjiOrchestrationProgress? onProgress,
  }) async {
    await _dao.ensureSchema();
    final problem = await _dao.problem(problemId);
    if (problem == null) throw StateError('问题不存在或已删除。');
    final effectiveClassification = classification ??
        XiangjiInputClassification(
          type: XiangjiInputType.need,
          updateExistingProblem: true,
          targetProblemId: problemId,
          reason: '直接调用持久求解器，继续更新当前问题。',
        );
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
    await _dao.saveInputClassification(
      id: _idFactory('xf_input_classification'),
      rawEventId: rawEventId,
      inputText: utterance.trim(),
      classification: effectiveClassification,
    );

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
        ? _naturalPreviousModelContext(previousSituation['model_json'])
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
      userSignalText: <String>[
        utterance.trim(),
        attachmentText.trim(),
        historyContext,
      ].where((text) => text.isNotEmpty).join('\n'),
      forceStrategic: forceStrategic,
    );
    final firstGuard = _guardForUnknownAnswer(
      _sck.evaluateAskUserGuard(draft.informationNeeds),
      userDoesNotKnow: userDoesNotKnow,
    );
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

    final localBaselineDraft = draft;
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
    final cloudAgentLabels = <String>[];
    final localAgentLabels = <String>[];
    final sensitiveCategories = <String>{};
    var aiConfigured = false;
    var cloudAgentCount = 0;
    var localAgentCount = 0;
    var failedAgentCount = 0;
    var privacyBlockedAgentCount = 0;
    var totalLatencyMs = 0;
    var redactedFieldCount = 0;
    var provider = '';
    var model = '';
    var executionFrozen = false;
    var freezeReason = '';
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
            'input_classification': effectiveClassification.toMap(),
            'user_does_not_know': userDoesNotKnow,
            'sck_rule_ids': XiangjiSckRuntime.rules.keys.toList(),
          },
        ));
        aiConfigured = aiConfigured || result.aiConfigured;
        if (result.provider.trim().isNotEmpty) provider = result.provider;
        if (result.model.trim().isNotEmpty) model = result.model;
        totalLatencyMs += result.latencyMs;
        if (result.redactedFieldCount > redactedFieldCount) {
          redactedFieldCount = result.redactedFieldCount;
        }
        sensitiveCategories.addAll(result.sensitiveCategories);
        if (result.localOnly) {
          localAgentCount++;
          localAgentLabels.add(agent.label);
          if (result.runStatus == 'sensitive_consent_required') {
            privacyBlockedAgentCount++;
          }
          if (result.runStatus == 'cloud_failed_local_fallback') {
            failedAgentCount++;
            warnings.add(
              '${agent.code} ${agent.label}：云端模型未完成，已使用本地求解结果保持连续。',
            );
          }
        } else {
          cloudAgentCount++;
          cloudAgentLabels.add(agent.label);
        }
        outputs[agent.code] = result.output;
        executionFrozen = executionFrozen || result.executionFrozen;
        if (result.executionFrozen && freezeReason.isEmpty) {
          freezeReason = '当前为不可逆高风险且认识债务高；先补证并降低不可逆性。';
        }
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
          'status': result.runStatus == 'cloud_failed_local_fallback'
              ? 'CLOUD_FAILED_LOCAL_COMPLETE'
              : result.runStatus == 'sensitive_consent_required'
                  ? 'PRIVACY_LOCAL_COMPLETE'
                  : result.localOnly
                      ? 'LOCAL_COMPLETE'
                      : 'COMPLETE',
          'started_at_ms': started,
          'ended_at_ms': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (error) {
        failedAgentCount++;
        // An unexpected provider/service exception still leaves the
        // deterministic local draft as the effective output for this role.
        // Record both facts: the attempted agent failed, and the user-facing
        // result was completed locally. Otherwise the persisted AI receipt
        // misleadingly reports zero local participation.
        localAgentCount++;
        localAgentLabels.add(agent.label);
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

    final methodGate = outputs[XiangjiAgentId.methodEffectValidator.code];
    final methodFailures = methodGate?['failures'];
    if (methodGate != null &&
        (methodGate['release_gate_passed'] != true ||
            (methodFailures is List && methodFailures.isNotEmpty))) {
      executionFrozen = true;
      freezeReason = '方法效果校验未通过：本轮分析尚未产生可审计的状态或决策变化。';
      warnings.add('${XiangjiAgentId.methodEffectValidator.code} $freezeReason');
    }
    final antiTemplateGate = outputs[XiangjiAgentId.antiTemplateValidator.code];
    final invalidOperators = antiTemplateGate?['invalid_operators'];
    if (invalidOperators is List && invalidOperators.isNotEmpty) {
      executionFrozen = true;
      freezeReason = '反模板校验发现当前办法没有针对本案例的有效机制，已停止自动推进。';
      warnings.add('${XiangjiAgentId.antiTemplateValidator.code} $freezeReason');
    }

    draft = draft.mergeAgentOutputs(outputs);
    final changedArtifacts = cloudAgentCount == 0
        ? const <String>[]
        : _cloudChangedArtifacts(localBaselineDraft, draft);
    final aiExecution = XiangjiAiExecutionSummary(
      aiConfigured: aiConfigured,
      provider: provider,
      model: model,
      plannedAgentCount: effectivePlan.length,
      cloudAgentCount: cloudAgentCount,
      localAgentCount: localAgentCount,
      failedAgentCount: failedAgentCount,
      privacyBlockedAgentCount: privacyBlockedAgentCount,
      totalLatencyMs: totalLatencyMs,
      redactedFieldCount: redactedFieldCount,
      cloudAgentLabels: cloudAgentLabels,
      localAgentLabels: localAgentLabels,
      changedArtifacts: changedArtifacts,
      sensitiveCategories: sensitiveCategories.toList(),
    );
    final guard = _guardForUnknownAnswer(
      _sck.evaluateAskUserGuard(draft.informationNeeds),
      userDoesNotKnow: userDoesNotKnow,
    );
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
        // Persist the public execution receipt with the versioned situation
        // model. The user can still see whether AI actually participated after
        // leaving the conversation, without exposing private chain-of-thought.
        'ai_execution': aiExecution.toMap(),
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
          agentRunRecordIds['A00'] ?? agentRunRecordIds['A03'] ?? '',
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
    final persistedAction =
        actionId.isEmpty ? null : await _dao.action(actionId);
    final visibleCurrentAction =
        persistedAction?.title ?? draft.currentAction;
    final cognitiveExperiences = await _persistRev4Runtime(
      problemId: problemId,
      situationId: situationId,
      actionId: actionId,
      utterance: utterance,
      draft: draft,
      classification: effectiveClassification,
      sourceRefs: sourceRefs,
      generatedBy: agentRunRecordIds['A06'] ??
          agentRunRecordIds['A00'] ??
          'A06_LOCAL_GUARD',
      awaitingClarification: clarification.isNotEmpty,
      userDoesNotKnow: userDoesNotKnow,
      realityContradicted: realityContradicted,
      methodTrainingEnabled: methodTrainingEnabled,
    );
    final problemProgress = await _dao.problemProgress(problemId);
    if (executionFrozen) {
      final releaseGateFreeze = freezeReason.contains('校验');
      await _dao.saveAlert(
        id: _idFactory('xf_alert'),
        state: XiangjiAlertState.red,
        alertType: releaseGateFreeze
            ? 'runtime_release_gate_freeze'
            : 'sck_high_risk_freeze',
        reason: freezeReason.isEmpty
            ? '当前推进条件未通过运行时门控。'
            : freezeReason,
        defaultAction: releaseGateFreeze
            ? '保留当前事实，回退到本地确定性求解并重新生成针对本案例的办法。'
            : '先补证、降低不可逆性，并在需要时寻求专业复核。',
        problemId: problemId,
      );
    } else {
      await _dao.resolveOpenAlertsOfType(
        'sck_high_risk_freeze',
        problemId: problemId,
      );
      await _dao.resolveOpenAlertsOfType(
        'runtime_release_gate_freeze',
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
          ? (freezeReason.isEmpty
              ? '当前推进条件未通过，先保留事实并重新生成可审计的下一步。'
              : freezeReason)
          : clarification.isEmpty
              ? draft.recommendation
              : '先补充这一项决定性信息，军师会自动继续。',
      'judgment': draft.judgment,
      'why_text': draft.why,
      'current_action': clarification.isEmpty && !executionFrozen
          ? visibleCurrentAction
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
      cognitiveExperiences: cognitiveExperiences,
      inputClassification: effectiveClassification,
      problemProgress: problemProgress,
      aiExecution: aiExecution,
    );
  }

  List<String> _cloudChangedArtifacts(
    XiangjiSituationDraft before,
    XiangjiSituationDraft after,
  ) {
    final values = <String>[];
    if (before.trueProblem.trim() != after.trueProblem.trim()) {
      values.add('重构了真问题');
    }
    if (before.causalHypotheses.join('\n') !=
        after.causalHypotheses.join('\n')) {
      values.add('补充并比较了竞争原因');
    }
    if (before.targetGap.trim() != after.targetGap.trim()) {
      values.add('重新选择了当前关键差距');
    }
    if (before.currentAction.trim() != after.currentAction.trim()) {
      values.add('调整了当前唯一行动');
    }
    if (before.operatorMechanism.trim() != after.operatorMechanism.trim()) {
      values.add('补全了办法的作用机制');
    }
    if (before.prediction.trim() != after.prediction.trim()) {
      values.add('生成了可被现实反驳的事前预测');
    }
    if (before.redTeam.join('\n') != after.redTeam.join('\n')) {
      values.add('加入了反方与失败条件');
    }
    if (values.isEmpty) {
      values.add('审查了本地草案，并保留当前解法');
    }
    return values;
  }

  XiangjiAskUserDecision _guardForUnknownAnswer(
    XiangjiAskUserDecision guard, {
    required bool userDoesNotKnow,
  }) {
    if (!userDoesNotKnow || guard.outcome != XiangjiAskUserOutcome.askOne) {
      return guard;
    }
    final need = guard.selectedNeed;
    return XiangjiAskUserDecision(
      outcome: XiangjiAskUserOutcome.scoutInReality,
      scoutingNeeds:
          need == null ? const <XiangjiInformationNeed>[] : <XiangjiInformationNeed>[need],
      reason: '用户当前不知道答案；不重复追问，改用保守假设与低成本现实侦察继续求解。',
    );
  }

  Future<List<XiangjiCognitiveExperienceDraft>> _persistRev4Runtime({
    required String problemId,
    required String situationId,
    required String actionId,
    required String utterance,
    required XiangjiSituationDraft draft,
    required XiangjiInputClassification classification,
    required List<String> sourceRefs,
    required String generatedBy,
    required bool awaitingClarification,
    required bool userDoesNotKnow,
    required bool realityContradicted,
    required bool methodTrainingEnabled,
  }) async {
    const manager = XiangjiProblemStateManager();
    const generator = XiangjiCognitiveExperienceGenerator();
    final previousState = await _dao.latestProblemStateVersion(problemId);
    final version = await _dao.nextProblemStateVersion(problemId);
    final lifecycle = manager.lifecycleFor(
      classification: classification,
      draft: draft,
      awaitingClarification: awaitingClarification,
      userDoesNotKnow: userDoesNotKnow,
      realityContradicted: realityContradicted,
    );
    final stateVersionId = _idFactory('xf_problem_state');
    await _dao.saveProblemStateVersion(<String, Object?>{
      'id': stateVersionId,
      ...manager.buildVersion(
        problemId: problemId,
        version: version,
        state: lifecycle,
        draft: draft,
        previousState: previousState,
        generatedBy: generatedBy,
        sourceRefs: sourceRefs,
      ),
    });

    final hypothesisIds = <String>[];
    for (final hypothesisText in draft.causalHypotheses.take(6)) {
      final parts = hypothesisText
          .split('|')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parts.isEmpty) continue;
      final id = _idFactory('xf_hypothesis');
      hypothesisIds.add(id);
      await _dao.saveHypothesis(<String, Object?>{
        'id': id,
        'problem_id': problemId,
        'effect_ref': 'problem_state:$stateVersionId',
        'statement': parts.first,
        'mechanism': parts.length > 1 ? parts.sublist(1).join('；') : '',
        'support_refs_json': jsonEncode(draft.observedFacts),
        'counter_refs_json': jsonEncode(draft.counterexamples),
        'status': XiangjiHypothesisStatus.proposed.wire,
        'scope': draft.need,
      });
    }

    var hypothesisTestId = '';
    if (hypothesisIds.length >= 2 || draft.unknowns.isNotEmpty) {
      hypothesisTestId = _idFactory('xf_hypothesis_test');
      await _dao.saveHypothesisTest(<String, Object?>{
        'id': hypothesisTestId,
        'problem_id': problemId,
        'hypothesis_ids_json': jsonEncode(hypothesisIds),
        'discriminating_action_id': actionId.isEmpty
            ? 'planned:$stateVersionId'
            : actionId,
        'expected_patterns_json': jsonEncode(<String>[
          draft.prediction,
          '候选原因应当对同一现实实验给出可以区分的结果模式。',
        ]),
        'result_ref': '',
        'conclusion': '',
        'status': XiangjiHypothesisStatus.testDesigned.wire,
      });
    }

    if (draft.relevantSimilarities.isNotEmpty ||
        draft.relevantDifferences.isNotEmpty) {
      final comparisonId = _idFactory('xf_case_comparison');
      await _dao.saveCaseComparison(<String, Object?>{
        'id': comparisonId,
        'problem_id': problemId,
        'situation_model_id': situationId,
        'purpose': '判断旧案例或旧标签能否迁移到当前目标',
        'current_case_refs_json': jsonEncode(sourceRefs),
        'historical_case_refs_json': jsonEncode(
          previousState == null
              ? const <String>[]
              : <String>['problem_state:${previousState['id']}'],
        ),
        'similarities_json': jsonEncode(draft.relevantSimilarities),
        'differences_json': jsonEncode(draft.relevantDifferences),
        'decisive_differences_json':
            jsonEncode(draft.relevantDifferences.take(3).toList()),
        'conclusion': draft.relevantDifferences.isEmpty
            ? '尚不足以按旧案例迁移结论。'
            : '只有在这些关键差异不改变作用机制时，旧案例才可有限迁移。',
      });
      for (final difference in draft.relevantDifferences.take(5)) {
        await _dao.saveRelevantDifference(<String, Object?>{
          'id': _idFactory('xf_relevant_difference'),
          'comparison_id': comparisonId,
          'feature': difference,
          'why_it_matters': '该差异可能改变目标、因果机制或路线选择。',
          'evidence_refs_json': jsonEncode(sourceRefs),
          'impact_on_decision': draft.judgment,
        });
      }
    }

    final experiences = generator.generate(
      draft: draft,
      utterance: utterance,
      idFactory: _idFactory,
      hasPriorState: previousState != null,
      realityConflict: realityContradicted,
      userCorrection: classification.type == XiangjiInputType.correction,
      oldModel: previousState == null
          ? ''
          : (previousState['current_focus'] ??
                  previousState['next_verification'] ??
                  '')
              .toString(),
      newReality: realityContradicted ||
              classification.type == XiangjiInputType.correction
          ? utterance
          : '',
      methodTrainingEnabled: methodTrainingEnabled,
    );
    for (final experience in experiences) {
      await _dao.saveCognitiveExperience(
        problemId: problemId,
        situationModelId: situationId,
        experience: experience,
      );
      if (experience.methodText.trim().isNotEmpty) {
        await _dao.saveMethodExperience(<String, Object?>{
          'id': _idFactory('xf_method_experience'),
          'problem_id': problemId,
          'cognitive_experience_id': experience.id,
          'method_id': experience.presentation.wire,
          'context': experience.trigger,
          'explanation': experience.methodText,
          'user_viewed': 0,
          'user_response': '',
          'transfer_prompt': experience.transferPrompt,
        });
      }
    }

    if (classification.type == XiangjiInputType.correction &&
        previousState != null) {
      await _dao.saveLearningMoment(<String, Object?>{
        'id': _idFactory('xf_learning_moment'),
        'problem_id': problemId,
        'old_model': (previousState['current_focus'] ?? '').toString(),
        'new_reality': utterance,
        'revised_model': draft.judgment,
        'method_learned': '用户纠正优先于旧推断；保留旧版本并按新现实重算。',
        'evidence_refs_json': jsonEncode(sourceRefs),
      });
    }

    await _dao.saveExplanationCard(<String, Object?>{
      'id': _idFactory('xf_explanation_card'),
      'problem_id': problemId,
      'situation_model_id': situationId,
      'target_ref': actionId.isEmpty
          ? 'decision:$stateVersionId'
          : 'action:$actionId',
      ...generator.explanationCard(draft),
    });

    if (actionId.isNotEmpty) {
      final persistedAction = await _dao.action(actionId);
      final persistedMechanism =
          (persistedAction?.whyChain['operator_mechanism'] ??
                  draft.operatorMechanism)
              .toString();
      final persistedGap =
          (persistedAction?.whyChain['key_gap'] ?? draft.targetGap).toString();
      await _dao.saveSolutionAttempt(<String, Object?>{
        'id': _idFactory('xf_solution_attempt'),
        'problem_id': problemId,
        'state_version_id': stateVersionId,
        'action_id': actionId,
        'operator_id': 'action:$actionId',
        'rationale': '$persistedMechanism；目标差距：$persistedGap',
        'prediction_id': hypothesisTestId,
        'started_at_ms': 0,
        'ended_at_ms': 0,
        'outcome_ref': '',
        'result_class': 'PENDING',
        'failure_layer': '',
        'status': 'PLANNED',
      });
    }
    return experiences;
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
      final unconceptualized = const <String>[
        '说不清',
        '不对劲',
        '难以描述',
        '不知道怎么形容',
      ].any(experience.contains);
      await _dao.addExperience(
        id: _idFactory('xf_experience'),
        rawEventId: rawEventId,
        problemId: problemId,
        type: unconceptualized
            ? 'unconceptualized_experience'
            : 'user_reported_experience',
        content: experience,
        isUserWording: true,
        observationConditions: <String, Object?>{
          'source_ref': 'raw_event:$rawEventId',
          'preserve_without_forced_label': unconceptualized,
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
      applicabilityBoundary:
          '仅适用于“${draft.trueProblem}”与当前约束；出现反例或现实冲突时必须修订。',
      unexplainedDetails: <String>{
        ...draft.unknowns,
        ...draft.counterexamples,
      }.toList(),
      changeReason: 'Rev.5.2 AI 预填；等待用户采用、修改或反对',
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
      'agent_run_id': agentRunIds['A03'] ?? '',
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
            jsonEncode(option['assumptions'] ?? <Object?>[
              option['key_assumption'] ?? '',
            ]),
        'stop_conditions_json':
            jsonEncode(option['stop_conditions'] ?? const <Object?>[]),
        'target_gap': (option['target_gap'] ?? draft.targetGap).toString(),
        'mechanism_for_this_case':
            (option['mechanism_for_this_case'] ??
                    draft.operatorMechanism)
                .toString(),
        'key_assumption': (option['key_assumption'] ?? '').toString(),
        'why_preferred': (option['why_preferred'] ?? '').toString(),
        'why_not_other_options':
            (option['why_not_other_options'] ?? '').toString(),
        'switch_trigger':
            (option['switch_trigger'] ?? draft.changeSignals).toString(),
        'user_summary': (option['user_summary'] ?? '').toString(),
        'preferred': option['preferred'] == true ? 1 : 0,
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
      'id': '$campaignId-rev4-leading',
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
      'id': '$campaignId-rev4-lagging',
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
    final contract = draft.operators.isEmpty
        ? const <String, Object?>{}
        : draft.operators.first;
    String contractText(List<String> keys, String fallback) {
      for (final key in keys) {
        final value = (contract[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return fallback;
    }

    final rawPreconditions = contract['preconditions'];
    final missingPreconditions = rawPreconditions is List
        ? rawPreconditions
            .map((item) {
              if (item is Map) {
                final status =
                    (item['status'] ?? '').toString().toLowerCase();
                final satisfied = item['satisfied'] == true ||
                    <String>{'satisfied', 'complete', 'completed', 'met'}
                        .contains(status);
                if (satisfied) return '';
                return (item['label'] ??
                        item['text'] ??
                        item['condition'] ??
                        item['name'] ??
                        '')
                    .toString()
                    .trim();
              }
              return item.toString().trim();
            })
            .where((item) => item.isNotEmpty)
            .toList()
        : const <String>[];
    final blockedTitle = contractText(
      const <String>['title', 'name'],
      draft.currentAction,
    );
    final targetGap = contractText(
      const <String>['target_gap'],
      draft.targetGap,
    );
    final activeTitle = missingPreconditions.isEmpty
        ? blockedTitle
        : '补齐前提：${missingPreconditions.first}';
    final activeMechanism = missingPreconditions.isEmpty
        ? contractText(
            const <String>['mechanism', 'mechanism_for_this_case'],
            draft.operatorMechanism,
          )
        : '先取得前提“${missingPreconditions.first}”成立或不成立的现实证据，解除原办法阻塞';
    final activePrediction = missingPreconditions.isEmpty
        ? contractText(
            const <String>['prediction', 'expected_effect'],
            draft.prediction,
          )
        : '完成后应能确认前提“${missingPreconditions.first}”是否成立';
    final expectedEffect = missingPreconditions.isEmpty
        ? contractText(
            const <String>['expected_effect'],
            draft.prediction,
          )
        : '前提“${missingPreconditions.first}”形成可观察满足证据，或被现实证伪后改换路线';
    await _dao.invalidateReadyActions(problemId);
    await _dao.addProblemItem(
      id: _idFactory('xf_item'),
      problemId: problemId,
      kind: 'gap',
      text: targetGap,
      sourceRef: 'situation:$situationId',
      critical: true,
      data: <String, Object?>{'origin': 'ai_prefill'},
    );
    await _dao.addProblemItem(
      id: _idFactory('xf_item'),
      problemId: problemId,
      kind: 'operator',
      text: activeTitle,
      sourceRef: 'situation:$situationId',
      critical: true,
      data: <String, Object?>{
        'target_gap': targetGap,
        'mechanism': activeMechanism,
        'preconditions': missingPreconditions,
        'expected_effect': expectedEffect,
        'cost': contractText(
          const <String>['cost'],
          '${draft.expectedMinutes} 分钟',
        ),
        'risk': contractText(const <String>['risk'], 'low'),
        'reversibility': contractText(
          const <String>['reversibility'],
          draft.irreversible ? 'low' : 'high',
        ),
        'information_value': contractText(
          const <String>['information_value'],
          '现实结果会改变下一轮判断',
        ),
        'strategic_meaning': draft.strategicMeaning,
        'grounding_reason': draft.groundingReason,
        'status': missingPreconditions.isEmpty
            ? 'selected'
            : 'precondition_subgoal_selected',
        if (missingPreconditions.isNotEmpty)
          'blocked_operator_title': blockedTitle,
        'origin': 'ai_prefill',
      },
    );
    for (var index = 0; index < missingPreconditions.length; index++) {
      await _dao.addProblemItem(
        id: _idFactory('xf_item'),
        problemId: problemId,
        kind: 'precondition_subgoal',
        text: missingPreconditions[index],
        sourceRef: 'situation:$situationId',
        critical: true,
        sortOrder: index,
        data: const <String, Object?>{
          'relation': 'AND',
          'status': 'missing',
          'origin': 'ai_prefill',
        },
      );
    }
    final actionId = _idFactory('xf_action');
    await _dao.createAction(
      id: actionId,
      title: activeTitle,
      problemId: problemId,
      campaignId: campaignId,
      prediction: activePrediction,
      expectedMinutes: draft.expectedMinutes,
      whyChain: <String, Object?>{
        'strategic_meaning': draft.strategicMeaning,
        'key_gap': targetGap,
        'operator_mechanism': activeMechanism,
        'epistemic_grounding': draft.groundingReason,
        'action_purpose': draft.strategicMeaning,
        'time_boundary_minutes': draft.expectedMinutes,
        'stop_condition': draft.changeSignals.trim().isEmpty
            ? '达到 ${draft.expectedMinutes} 分钟仍未出现事前预测中的关键信号时，停止加码并回来验算。'
            : draft.changeSignals,
        'reporting_facts': <String>[
          '是否出现：$activePrediction',
          '实际做了什么，用了多少时间',
          '有什么明显意外或身体、情绪体验',
        ],
        if (missingPreconditions.isNotEmpty)
          'blocked_operator': blockedTitle,
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
        XiangjiAgentId.campaignSelector ||
        XiangjiAgentId.resourcePlanner ||
        XiangjiAgentId.strategist ||
        XiangjiAgentId.redTeam ||
        XiangjiAgentId.wargameContingency =>
          XiangjiOrchestrationState.strategicCouncil,
        XiangjiAgentId.chiefStrategist => majorDecision
            ? XiangjiOrchestrationState.strategicCouncil
            : XiangjiOrchestrationState.problemSolving,
        XiangjiAgentId.actionOfficer ||
        XiangjiAgentId.methodTranslator ||
        XiangjiAgentId.methodEffectValidator ||
        XiangjiAgentId.antiTemplateValidator =>
          XiangjiOrchestrationState.actionCompression,
        XiangjiAgentId.reviewHistorian ||
        XiangjiAgentId.personalScienceLearner =>
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
        XiangjiAgentId.campaignSelector ||
        XiangjiAgentId.resourcePlanner ||
        XiangjiAgentId.strategist ||
        XiangjiAgentId.redTeam ||
        XiangjiAgentId.wargameContingency ||
        XiangjiAgentId.chiefStrategist =>
          XiangjiProblemState.solving,
        XiangjiAgentId.actionOfficer => XiangjiProblemState.actionReady,
        XiangjiAgentId.methodTranslator ||
        XiangjiAgentId.methodEffectValidator ||
        XiangjiAgentId.antiTemplateValidator =>
          XiangjiProblemState.actionReady,
        XiangjiAgentId.reviewHistorian ||
        XiangjiAgentId.personalScienceLearner =>
          XiangjiProblemState.verifying,
        XiangjiAgentId.monitor || XiangjiAgentId.knowledgeRouter =>
          XiangjiProblemState.solving,
      };

  String _naturalPreviousModelContext(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return '';
      final map = decoded.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
      String text(String key) => (map[key] ?? '').toString().trim();
      String list(String key) {
        final value = map[key];
        if (value is! List) return '';
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .join('；');
      }

      return <String>[
        if (text('need').isNotEmpty) '上一轮需要：${text('need')}',
        if (text('true_problem').isNotEmpty)
          '上一轮真问题：${text('true_problem')}',
        if (text('goal').isNotEmpty) '上一轮目标：${text('goal')}',
        if (list('observed_facts').isNotEmpty)
          '已记录事实：${list('observed_facts')}',
        if (list('unknowns').isNotEmpty) '仍未知：${list('unknowns')}',
        if (text('judgment').isNotEmpty)
          '上一轮可修订判断：${text('judgment')}',
        if (text('current_action').isNotEmpty)
          '上一轮行动：${text('current_action')}',
        if (text('prediction').isNotEmpty)
          '上一轮事前预测：${text('prediction')}',
      ].join('\n');
    } catch (_) {
      return '';
    }
  }

  String _artifactRunId(String kind, Map<String, String> agentRunIds) =>
      switch (kind) {
        'causal_map' => agentRunIds['A02'] ?? '',
        'judgment_map' => agentRunIds['A03'] ?? '',
        'grounding_chain' => agentRunIds['A04'] ?? '',
        'problem_tree' => agentRunIds['A06'] ?? '',
        'strategy_matrix' => agentRunIds['A09'] ?? '',
        'red_team' => agentRunIds['A10'] ?? '',
        'war_game' => agentRunIds['A11'] ?? '',
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
