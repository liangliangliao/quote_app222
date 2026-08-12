import 'dart:convert';

import '../data/kv_dao.dart';
import '../external_data/todo_dao.dart';
import 'xiangji_agent_service.dart';
import 'xiangji_cognitive_orchestrator.dart';
import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_persistent_solver.dart';
import 'xiangji_rev3_models.dart';
import 'xiangji_rev4_models.dart';
import 'xiangji_sck_runtime.dart';
import 'xiangji_signature_method_engine.dart';
import 'xiangji_state_machine.dart';

class XiangjiRepository {
  XiangjiRepository({
    XiangjiDao? dao,
    TodoDao? todoDao,
    XiangjiAgentService? agentService,
    XiangjiSignatureCapabilityRouter? signatureRouter,
  })  : _dao = dao ?? XiangjiDao(),
        _todoDao = todoDao ?? TodoDao(),
        _agentService = agentService ?? XiangjiAgentService(dao: dao),
        _signatureRouter =
            signatureRouter ?? const XiangjiSignatureCapabilityRouter();

  final XiangjiDao _dao;
  final TodoDao _todoDao;
  final XiangjiAgentService _agentService;
  final XiangjiSignatureCapabilityRouter _signatureRouter;
  final KeyValueDao _kv = KeyValueDao();
  final XiangjiInputClassifier _inputClassifier =
      const XiangjiInputClassifier();
  final XiangjiProblemStateMachine _problemMachine =
      const XiangjiProblemStateMachine();
  final XiangjiCampaignStateMachine _campaignMachine =
      const XiangjiCampaignStateMachine();
  final XiangjiMonitorEngine _monitor = const XiangjiMonitorEngine();

  static int _idCounter = 0;
  static const String monitorEnabledKey = 'xiangji_monitor_enabled_v1';
  static const String methodTrainingKey = 'xiangji_method_training_v1';

  String newId(String prefix) {
    _idCounter = (_idCounter + 1) % 1000000;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  Future<void> initialize() => _dao.ensureSchema();

  Future<XiangjiDashboardSnapshot> dashboard() async {
    await refreshTodoBindings();
    if ((await _kv.getString(monitorEnabledKey)) != '0') {
      await refreshAutomaticWatch();
    }
    return _dao.dashboard();
  }

  Future<List<XiangjiProblemRecord>> problems({bool includeArchived = false}) =>
      _dao.problems(includeArchived: includeArchived);

  Future<List<XiangjiCampaignRecord>> campaigns({bool includeClosed = false}) =>
      _dao.campaigns(includeClosed: includeClosed);

  Future<List<XiangjiActionRecord>> currentActions() =>
      _dao.actions(currentOnly: true);

  Future<List<XiangjiDecisionDraftRecord>> decisionDrafts({int limit = 20}) =>
      _dao.latestDecisionDrafts(limit: limit);

  Future<XiangjiDecisionDraftRecord?> latestDecisionDraft(String problemId) =>
      _dao.latestDecisionDraft(problemId: problemId);

  Future<XiangjiProblemProgress?> problemProgress(String problemId) =>
      _dao.problemProgress(problemId);

  Future<XiangjiSolverSnapshot?> solverSnapshot(String problemId) =>
      _dao.solverSnapshot(problemId);

  Future<List<XiangjiMethodEvent>> methodEvents(
    String problemId, {
    int limit = 20,
    bool userVisibleOnly = false,
  }) =>
      _dao.methodEvents(
        problemId: problemId,
        limit: limit,
        userVisibleOnly: userVisibleOnly,
      );

  Future<List<XiangjiCognitiveExperienceDraft>> cognitiveExperiences({
    String problemId = '',
    int limit = 100,
  }) =>
      _dao.cognitiveExperiences(problemId: problemId, limit: limit);

  Future<XiangjiCouncilResult> submitMethodExercise({
    required String problemId,
    required String cognitiveExperienceId,
    required String response,
    bool authorizedSensitiveContext = false,
  }) async {
    final value = response.trim();
    if (value.isEmpty) throw ArgumentError('请写下这一步练习带来的观察。');
    await _dao.recordMethodExerciseResponse(
      cognitiveExperienceId: cognitiveExperienceId,
      response: value,
    );
    return consultStrategist(
      utterance: '方法练习反馈：$value',
      problemId: problemId,
      authorizedSensitiveContext: authorizedSensitiveContext,
      clarificationAnswer: true,
    );
  }

  /// Rev.4 default entry: one natural-language utterance starts the complete
  /// cognitive route. Internal structures are AI-prefilled and persisted;
  /// users are never routed into a blank mandatory worksheet.
  Future<XiangjiCouncilResult> consultStrategist({
    required String utterance,
    String problemId = '',
    bool authorizedSensitiveContext = false,
    List<String> attachmentRefs = const <String>[],
    String attachmentText = '',
    bool forceStrategic = false,
    bool clarificationAnswer = false,
    bool forceNewProblem = false,
    String parentProblemId = '',
    bool userDoesNotKnow = false,
    bool realityContradicted = false,
    bool skipAutomaticRealityRouting = false,
    XiangjiOrchestrationProgress? onProgress,
  }) async {
    final text = utterance.trim();
    if (text.isEmpty) {
      throw ArgumentError('请告诉军师你想要什么、发生了什么，或卡在哪里。');
    }
    final requestedProblem = problemId.isEmpty
        ? await _dao.latestActiveProblem()
        : await _dao.problem(problemId);
    final activeActions = await _dao.actions(currentOnly: true);
    var classification = _inputClassifier.classify(
      input: text,
      activeProblem: requestedProblem,
      explicitNewProblem: forceNewProblem,
      hasActiveAction: activeActions.any(
        (action) => requestedProblem == null ||
            action.problemId == requestedProblem.id,
      ),
    );
    final explicitlySeparateTopic =
        classification.type == XiangjiInputType.newProblem &&
            classification.reason.startsWith('用户明确');
    var targetProblemId = '';
    if (!forceNewProblem &&
        requestedProblem != null &&
        ((!explicitlySeparateTopic && problemId.isNotEmpty) ||
            classification.type != XiangjiInputType.newProblem)) {
      targetProblemId = requestedProblem.id;
      if (!classification.updateExistingProblem ||
          classification.targetProblemId != targetProblemId ||
          classification.type == XiangjiInputType.newProblem) {
        classification = XiangjiInputClassification(
          type: classification.type == XiangjiInputType.newProblem
              ? XiangjiInputType.need
              : classification.type,
          updateExistingProblem: true,
          targetProblemId: targetProblemId,
          reason: problemId.isNotEmpty
              ? '用户正在当前问题工作台继续对话，因此更新同一道题。'
              : '输入与最近的活跃问题相连，因此继续更新稳定问题身份。',
          confidence: classification.confidence,
        );
      }
    }
    if (targetProblemId.isNotEmpty &&
        requestedProblem?.state == XiangjiProblemState.resolved) {
      await _dao.updateProblemState(
        targetProblemId,
        XiangjiProblemState.solving,
        actor: 'system_reopen_on_new_reality',
      );
    }
    if (targetProblemId.isEmpty) {
      targetProblemId = await createProblem(
        rawQuestion: text,
        rawContext: attachmentText.trim().isEmpty
            ? text
            : '$text\n\n附件摘录：\n${attachmentText.trim()}',
        parentProblemId: parentProblemId,
      );
      classification = XiangjiInputClassification(
        type: XiangjiInputType.newProblem,
        updateExistingProblem: false,
        targetProblemId: targetProblemId,
        reason: forceNewProblem
            ? '用户明确开启新问题；旧问题及历史保持不变。'
            : classification.reason,
        confidence: classification.confidence,
      );
    }
    final matchingActiveActions = activeActions
        .where((action) => action.problemId == targetProblemId)
        .toList();
    if (!skipAutomaticRealityRouting &&
        classification.type == XiangjiInputType.actionFeedback &&
        matchingActiveActions.isNotEmpty &&
        _inputClassifier.isExplicitActionFeedback(
          text,
          hasActiveAction: true,
        )) {
      return reconcileRealityFromNaturalLanguage(
        actionId: matchingActiveActions.first.id,
        feedback: text,
        authorizedSensitiveContext: authorizedSensitiveContext,
        onProgress: onProgress,
      );
    }
    final orchestrator = XiangjiCognitiveOrchestrator(
      dao: _dao,
      agentService: _agentService,
      idFactory: newId,
    );
    var retrievableContext = '';
    var retrievableSourceRefs = const <String>[];
    try {
      final allTasks = await _todoDao.listTasks('smart_all', limit: 50);
      final terms = _retrievalTerms(text);
      final tasks = allTasks.where((task) {
        if (terms.isEmpty) return false;
        final haystack = '${task.title}\n${task.bodyText}'.toLowerCase();
        return terms.any((term) => haystack.contains(term));
      }).take(20).toList();
      retrievableContext = tasks.map((task) {
        final body = task.bodyText.trim();
        final clippedBody = body.length <= 240 ? body : body.substring(0, 240);
        return <String>[
          'Todo：${task.title}',
          if (task.dueDateTime.trim().isNotEmpty)
            '截止：${task.dueDateTime.trim()}',
          if (clippedBody.isNotEmpty) '备注：$clippedBody',
        ].join('；');
      }).join('\n');
      retrievableSourceRefs = tasks
          .map((task) => 'todo:${task.taskId}')
          .toList(growable: false);
    } catch (_) {
      // Todo is helpful retrieval context, never a prerequisite for counsel.
    }
    var methodTrainingEnabled = false;
    try {
      methodTrainingEnabled =
          (await _kv.getString(methodTrainingKey)) == '1';
    } catch (_) {
      // A device preference must never prevent the deterministic counsel path
      // from working (for example before platform channels are available).
    }
    final result = await orchestrator.consult(
      problemId: targetProblemId,
      utterance: text,
      authorizedSensitiveContext: authorizedSensitiveContext,
      attachmentRefs: attachmentRefs,
      attachmentText: attachmentText,
      retrievableSourceRefs: retrievableSourceRefs,
      retrievableContext: retrievableContext,
      forceStrategic: forceStrategic,
      clarificationAnswer: clarificationAnswer,
      classification: classification,
      userDoesNotKnow: userDoesNotKnow,
      realityContradicted: realityContradicted,
      methodTrainingEnabled: methodTrainingEnabled,
      onProgress: onProgress,
    );
    await _applySignatureMethodsFromCouncil(
      result: result,
      utterance: text,
      sourceRefs: <String>[
        'input:${result.inputClassification?.type.wire ?? classification.type.wire}',
        ...attachmentRefs,
        ...retrievableSourceRefs,
      ],
      realityContradicted: realityContradicted,
    );
    return result;
  }

  Future<XiangjiCouncilResult> planCampaignWithStrategist({
    required String campaignId,
    required String utterance,
    bool authorizedSensitiveContext = false,
    XiangjiOrchestrationProgress? onProgress,
  }) async {
    final campaign = await _requireCampaign(campaignId);
    final linkedProblems = (await problems())
        .where((problem) => problem.campaignId == campaignId)
        .toList();
    var problemId = linkedProblems.isEmpty ? '' : linkedProblems.first.id;
    if (problemId.isEmpty) {
      problemId = await createProblem(
        rawQuestion: utterance.trim().isEmpty ? campaign.title : utterance,
        rawContext:
            '${campaign.title}\n北极星：${campaign.northStar}\n战略价值：${campaign.strategicValue}',
      );
      await _dao.linkProblemCampaign(problemId, campaignId);
    }
    return consultStrategist(
      utterance: utterance.trim().isEmpty ? campaign.title : utterance,
      problemId: problemId,
      authorizedSensitiveContext: authorizedSensitiveContext,
      forceStrategic: true,
      onProgress: onProgress,
    );
  }

  Future<void> respondToDecisionDraft({
    required String decisionDraftId,
    required XiangjiDecisionDraftStatus status,
    String recommendation = '',
    String currentAction = '',
  }) async {
    final draft = await _dao.decisionDraft(decisionDraftId);
    if (draft == null) throw StateError('军师草案不存在。');
    await _dao.updateDecisionDraftStatus(
      decisionDraftId,
      status,
      recommendation: recommendation,
      currentAction: currentAction,
    );
    if (status == XiangjiDecisionDraftStatus.adopted) {
      await _dao.acceptSituationModel(draft.situationModelId);
    }
    if (status == XiangjiDecisionDraftStatus.modified &&
        draft.actionId.isNotEmpty &&
        currentAction.trim().isNotEmpty) {
      await _dao.updateAction(
        draft.actionId,
        <String, Object?>{'title': currentAction.trim()},
        eventType: 'user_modified_ai_draft',
      );
    }
    if (status == XiangjiDecisionDraftStatus.adopted &&
        draft.campaignId.isNotEmpty) {
      await _dao.selectPreferredStrategy(draft.campaignId);
      final campaign = await _dao.campaign(draft.campaignId);
      if (campaign?.state == XiangjiCampaignState.decision) {
        await transitionCampaign(
          campaignId: draft.campaignId,
          target: XiangjiCampaignState.prepare,
          userConfirmed: true,
        );
      }
    }
  }

  Future<XiangjiCouncilResult> correctAndRecalculate({
    required String problemId,
    required String targetRef,
    required String oldValue,
    required String correctedValue,
    String reason = '用户指出 AI 理解有误',
    bool authorizedSensitiveContext = false,
    XiangjiOrchestrationProgress? onProgress,
  }) async {
    final correction = correctedValue.trim();
    if (correction.isEmpty) throw ArgumentError('请告诉军师正确情况。');
    await _dao.saveUserCorrectionAndInvalidate(
      id: newId('xf_correction'),
      problemId: problemId,
      targetRef: targetRef,
      oldValue: oldValue,
      correctedValue: correction,
      reason: reason,
    );
    return consultStrategist(
      utterance: '更正：$correction',
      problemId: problemId,
      authorizedSensitiveContext: authorizedSensitiveContext,
      clarificationAnswer: true,
      onProgress: onProgress,
    );
  }

  /// Natural-language reality feedback is extracted and reconciled by AI/SCK;
  /// the user does not choose a verdict or complete a post-mortem form.
  Future<XiangjiCouncilResult> reconcileRealityFromNaturalLanguage({
    required String actionId,
    required String feedback,
    bool authorizedSensitiveContext = false,
    XiangjiOrchestrationProgress? onProgress,
  }) async {
    final text = feedback.trim();
    if (text.isEmpty) throw ArgumentError('请直接告诉军师实际发生了什么。');
    var action = await _requireAction(actionId);
    if (action.problemId.isEmpty) throw StateError('该行动没有关联问题，无法回溯模型。');
    if (action.state == XiangjiActionState.ready) {
      await startAction(actionId: actionId, userConfirmed: true);
      action = await _requireAction(actionId);
    }
    const sck = XiangjiSckRuntime();
    final extraction = sck.extractRealityFeedback(text);
    final facts = extraction.facts;
    final unexpected = extraction.unexpected;
    if (action.state == XiangjiActionState.done) {
      if (await _dao.realityResult(actionId) == null) {
        await recordRealityForCompletedAction(
          actionId: actionId,
          realityFacts: facts,
          experiences: extraction.experiences,
          unexpected: unexpected,
          userInterpretation: extraction.interpretations.join('\n'),
        );
      }
    } else {
      await completeAction(
        actionId: actionId,
        realityFacts: facts,
        experiences: extraction.experiences,
        unexpected: unexpected,
        userInterpretation: extraction.interpretations.join('\n'),
      );
    }
    final sckVerdict = sck.reconcilePrediction(
      prediction: action.prediction,
      realityFeedback: text,
    );
    final verdict = switch (sckVerdict) {
      'contradicts' => 'refutes',
      'partially_supports' => 'partly_supports',
      'supports' => 'supports',
      _ => 'unknown',
    };
    XiangjiAgentResult? review;
    try {
      review = await _agentService.run(XiangjiAgentRequest(
        requestId: newId('xf_request'),
        task: '对照事前预测与现实反馈，定位最早错误层并形成修订。',
        agent: XiangjiAgentId.reviewHistorian,
        problemId: action.problemId,
        problemState: XiangjiProblemState.verifying,
        authorizedSensitiveContext: authorizedSensitiveContext,
        additionalContext: <String, Object?>{
          'prediction': action.prediction,
          'reality_feedback': text,
          'local_verdict': verdict,
          'has_reality_result': true,
          'sck_rules': const <String>['SCK-014', 'SCK-018'],
        },
      ));
    } catch (_) {
      // The deterministic SCK verdict remains sufficient for local continuity.
    }
    if (verdict == 'refutes') {
      await _dao.saveUserCorrectionAndInvalidate(
        id: newId('xf_reality_correction'),
        problemId: action.problemId,
        targetRef: 'prediction:$actionId',
        oldValue: action.prediction,
        correctedValue: text,
        reason: 'RealityResult 与事前 Prediction 冲突（SCK-018）',
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final attempts = await _dao.solutionAttempts(action.problemId);
      final matchingAttempts = attempts
          .where((attempt) =>
              (attempt['action_id'] ?? '').toString() == actionId)
          .toList();
      await _dao.saveConceptRealityConflict(<String, Object?>{
        'id': newId('xf_concept_conflict'),
        'problem_id': action.problemId,
        'concept_version_id': '',
        'reality_refs_json': jsonEncode(<String>['reality:$actionId']),
        'mismatch_pattern': '事前预测与行动后的现实结果不一致',
        'repetitions': 1,
        'impact': '需要复核行动机制、关键前提与当前问题框架',
        'status': XiangjiConceptConflictState.mismatchDetected.wire,
        'review_result': '已启动从算子到事实层的最早错误回溯',
        'created_at_ms': now,
        'updated_at_ms': now,
      });
      await _dao.saveBacktrackEvent(<String, Object?>{
        'id': newId('xf_backtrack'),
        'problem_id': action.problemId,
        'attempt_id': matchingAttempts.isEmpty
            ? ''
            : (matchingAttempts.first['id'] ?? '').toString(),
        'earliest_failed_layer':
            (review?.output['earliest_error_layer'] ?? 'operator_or_premise')
                .toString(),
        'old_ref': 'prediction:$actionId',
        'new_ref': 'reality:$actionId',
        'reason': '现实没有产生事前预测的可观察结果，先修订模型而不是归咎用户。',
        'evidence_refs_json': jsonEncode(<String>['reality:$actionId']),
        'created_at_ms': now,
      });
      await _dao.saveLearningMoment(<String, Object?>{
        'id': newId('xf_learning_moment'),
        'problem_id': action.problemId,
        'old_model': action.prediction,
        'new_reality': text,
        'revised_model': '原行动机制或其关键前提不足以解释这次现实，需要回溯后形成新版本。',
        'method_learned': '预测落空时先区分执行失败与机制失败，并让现实修订解释。',
        'evidence_refs_json': jsonEncode(<String>['reality:$actionId']),
        'created_at_ms': now,
      });
    }
    await _dao.updateSolutionAttemptForAction(
      actionId,
      <String, Object?>{
        'ended_at_ms': DateTime.now().millisecondsSinceEpoch,
        'outcome_ref': 'reality:$actionId',
        'result_class': verdict.toUpperCase(),
        'failure_layer': verdict == 'refutes'
            ? (review?.output['earliest_error_layer'] ?? 'operator_or_premise')
                .toString()
            : '',
        'status': 'RESULT_AVAILABLE',
      },
    );
    await verifyAction(
      actionId: actionId,
      verdict: verdict,
      resolutionCriteriaMet: false,
      aiModelRunId: review?.modelRunId ?? '',
      correction: verdict == 'refutes' ? text : '',
    );
    final problem = await _requireProblem(action.problemId);
    final resolutionCriteriaMet = verdict == 'supports' &&
        ((review?.output['resolution_criteria_met'] == true) ||
            _feedbackMeetsSuccessCriteria(
              feedback: text,
              successCriteria: problem.successCriteria,
            ));
    final result = await consultStrategist(
      utterance: '现实反馈：$text',
      problemId: action.problemId,
      authorizedSensitiveContext: authorizedSensitiveContext,
      forceStrategic: problem.campaignId.isNotEmpty,
      realityContradicted: verdict == 'refutes',
      skipAutomaticRealityRouting: true,
      onProgress: onProgress,
    );
    if (resolutionCriteriaMet) {
      await _markProblemResolved(
        problem: problem,
        result: result,
        realityRef: 'reality:$actionId',
      );
    }
    return result;
  }

  Future<String> createProblem({
    required String rawQuestion,
    required String rawContext,
    String sensitivity = 'sensitive',
    String parentProblemId = '',
  }) async {
    final question = rawQuestion.trim();
    if (question.isEmpty) throw ArgumentError('请先写下真实问题。');
    final problemId = newId('xf_problem');
    final eventId = newId('xf_event');
    final parent = parentProblemId.isEmpty
        ? null
        : await _dao.problem(parentProblemId);
    await _dao.createProblem(
      id: problemId,
      rawEventId: eventId,
      rawQuestion: question,
      contextText: rawContext.trim().isEmpty ? question : rawContext.trim(),
      sensitivity: sensitivity,
      parentProblemId: parentProblemId,
      rootGoalId: parent?.rootGoalId.isNotEmpty == true
          ? parent!.rootGoalId
          : parentProblemId,
    );
    await _dao.saveSolverSnapshot(XiangjiSolverSnapshot(
      problemId: problemId,
      need: question,
      problemFrame: <String, Object?>{
        'original_question': question,
        'status': 'captured',
      },
      currentState: <String, Object?>{
        'summary': rawContext.trim().isEmpty ? question : rawContext.trim(),
      },
      promptVersion: 'rev5.2',
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
    return problemId;
  }

  Future<void> beginFormalizing(String problemId) async {
    final problem = await _requireProblem(problemId);
    final decision = _problemMachine.evaluate(
      problem.state,
      XiangjiProblemState.formalizing,
      const XiangjiProblemTransitionContext(rawMaterialSaved: true),
    );
    decision.requireAllowed();
    await _dao.updateProblemState(problemId, XiangjiProblemState.formalizing);
  }

  Future<void> completeFormalization({
    required String problemId,
    required List<String> observedFacts,
    required List<String> bodyExperiences,
    required List<String> userInterpretations,
    required List<String> predictions,
    required List<String> criticalUnknowns,
    List<String> causalHypotheses = const <String>[],
  }) async {
    final problem = await _requireProblem(problemId);
    if (problem.state != XiangjiProblemState.formalizing) {
      throw StateError('当前问题不在事实/解释分层阶段。');
    }
    final rawEventId = await _dao.problemRawEventId(problemId);
    final items = <MapEntry<String, List<String>>>[
      MapEntry<String, List<String>>('known', observedFacts),
      MapEntry<String, List<String>>('body_experience', bodyExperiences),
      MapEntry<String, List<String>>('user_interpretation', userInterpretations),
      MapEntry<String, List<String>>('prediction', predictions),
      MapEntry<String, List<String>>('unknown', criticalUnknowns),
    ];
    for (final group in items) {
      for (var index = 0; index < group.value.length; index++) {
        final text = group.value[index].trim();
        if (text.isEmpty) continue;
        await _dao.addProblemItem(
          id: newId('xf_item'),
          problemId: problemId,
          kind: group.key,
          text: text,
          critical: group.key == 'unknown',
          sortOrder: index,
          data: <String, Object?>{
            'source': group.key == 'known' ||
                    group.key == 'body_experience' ||
                    group.key == 'user_interpretation'
                ? 'user'
                : 'user_or_system',
          },
        );
        if (<String>{'known', 'body_experience'}.contains(group.key)) {
          await _dao.addExperience(
            id: newId('xf_experience'),
            rawEventId: rawEventId,
            problemId: problemId,
            type: group.key == 'known' ? 'observation' : 'body',
            content: text,
            isUserWording: true,
            userConfirmed: true,
          );
        } else if (<String>{'user_interpretation', 'prediction'}
            .contains(group.key)) {
          await _dao.addClaim(
            id: newId('xf_claim'),
            problemId: problemId,
            text: text,
            claimType: group.key == 'prediction' ? 'prediction' : 'interpretation',
            state: XiangjiClaimState.draft,
            importance: group.key == 'prediction' ? 'high' : 'medium',
            sourceKind: 'user',
            isUserWording: true,
            userConfirmed: true,
          );
        }
      }
    }
    for (final raw in causalHypotheses) {
      final parts = raw.split('|').map((item) => item.trim()).toList();
      final cause = parts.isEmpty ? '' : parts.first;
      if (cause.isEmpty) continue;
      await _dao.addCausalHypothesis(
        id: newId('xf_causal'),
        problemId: problemId,
        causeCandidate: cause,
        differentiatingEvidenceNeeded: parts.length > 1 && parts[1].isNotEmpty
            ? parts[1]
            : '需要能区分该原因与其他竞争解释的现实材料',
      );
      await _dao.addProblemItem(
        id: newId('xf_item'),
        problemId: problemId,
        kind: 'causal_hypothesis',
        text: cause,
        data: <String, Object?>{
          'differentiating_evidence_needed':
              parts.length > 1 ? parts[1] : '',
        },
      );
    }
    final decision = _problemMachine.evaluate(
      problem.state,
      XiangjiProblemState.epistemicReview,
      const XiangjiProblemTransitionContext(
        experienceAndInterpretationSeparated: true,
      ),
    );
    decision.requireAllowed();
    await _dao.updateProblemState(
      problemId,
      XiangjiProblemState.epistemicReview,
    );
    final formalizationText = <String>[
      ...observedFacts,
      ...bodyExperiences,
      ...userInterpretations,
    ].join('；');
    await _applySignatureMethods(
      problemId: problemId,
      context: XiangjiSignatureMethodContext(
        problemId: problemId,
        problemState: XiangjiProblemState.formalizing,
        rawText: formalizationText,
        requestedMethodIds: <String>[
          if ((observedFacts.isNotEmpty || bodyExperiences.isNotEmpty) &&
              userInterpretations.isNotEmpty)
            'MEC-001',
          if (RegExp(r'害怕|恐惧|抗拒|焦虑|不想|感觉').hasMatch(formalizationText) &&
              RegExp(r'所以|说明|一定|肯定|证明').hasMatch(formalizationText))
            'MEC-002',
          if (causalHypotheses.isNotEmpty) 'MEC-003',
          if (RegExp(r'说不清|不对劲|怪怪的|难以描述').hasMatch(formalizationText))
            'MEC-005',
        ],
        sourceRefs: <String>['problem:$problemId'],
        facts: observedFacts,
        experiences: bodyExperiences,
        interpretations: userInterpretations,
        causalCandidates: causalHypotheses,
        vagueExperience: bodyExperiences.firstWhere(
          (item) => RegExp(r'说不清|不对劲|怪怪的|难以描述').hasMatch(item),
          orElse: () => '',
        ),
        eventIdPrefix: newId('xf_method_formalize'),
      ),
    );
  }

  Future<void> completeEpistemicReview({
    required String problemId,
    required bool groundingReviewed,
    required bool acceptUnresolvedUnknowns,
  }) async {
    final problem = await _requireProblem(problemId);
    if (problem.state != XiangjiProblemState.epistemicReview) {
      throw StateError('当前问题不在认识审查阶段。');
    }
    final unknowns = await _dao.problemItems(problemId, kind: 'unknown');
    var criticalUnknownHandled = unknowns.isEmpty;
    if (unknowns.isNotEmpty && acceptUnresolvedUnknowns) {
      criticalUnknownHandled = true;
      for (final unknown in unknowns) {
        final text = (unknown['text'] ?? '').toString();
        await _dao.addEpistemicDebt(
          id: newId('xf_debt'),
          problemId: problemId,
          description: text,
          decisionImpact: (unknown['critical'] ?? 0) == 1 ? 'high' : 'medium',
          groundingGap: '需要现实材料或独立来源',
          informationValue: '解决后可能改变问题定义或行动路线',
        );
        await _dao.addProblemItem(
          id: newId('xf_item'),
          problemId: problemId,
          kind: 'information_action',
          text: '侦察：获取能回答“$text”的现实材料',
          critical: true,
          data: <String, Object?>{'resolves_unknown_id': unknown['id']},
        );
      }
    }
    final decision = _problemMachine.evaluate(
      problem.state,
      XiangjiProblemState.conceptReview,
      XiangjiProblemTransitionContext(
        groundingReviewed: groundingReviewed,
        criticalUnknownHandled: criticalUnknownHandled,
      ),
    );
    decision.requireAllowed();
    await _dao.updateProblemState(
      problemId,
      XiangjiProblemState.conceptReview,
    );
    await _applySignatureMethods(
      problemId: problemId,
      context: XiangjiSignatureMethodContext(
        problemId: problemId,
        problemState: XiangjiProblemState.epistemicReview,
        requestedMethodIds: <String>[
          'MEC-007',
          if (unknowns.isNotEmpty) 'MEC-008',
        ],
        highImpactClaim: problem.reframedQuestion.isEmpty
            ? problem.rawQuestion
            : problem.reframedQuestion,
        weakestPremise:
            unknowns.isEmpty ? '' : (unknowns.first['text'] ?? '').toString(),
        complexModel: unknowns.isNotEmpty,
        groundWeak: !groundingReviewed || unknowns.isNotEmpty,
        sourceRefs: <String>['problem:$problemId'],
        eventIdPrefix: newId('xf_method_ground'),
      ),
    );
  }

  Future<void> confirmReframedProblem({
    required String problemId,
    required String reframedQuestion,
    required String goalText,
    required String valueLink,
    required String successCriteria,
    required String exitCriteria,
    required int reviewAtMs,
    List<String> conceptDefinitions = const <String>[],
  }) async {
    final problem = await _requireProblem(problemId);
    if (problem.state != XiangjiProblemState.conceptReview) {
      throw StateError('当前问题不在概念/真问题审查阶段。');
    }
    if (reframedQuestion.trim().isEmpty ||
        goalText.trim().isEmpty ||
        successCriteria.trim().isEmpty) {
      throw ArgumentError('真问题、目标和现实成功判据不能为空。');
    }
    await _dao.updateProblemDefinition(
      id: problemId,
      reframedQuestion: reframedQuestion.trim(),
      goalText: goalText.trim(),
      valueLink: valueLink.trim(),
      successCriteria: successCriteria.trim(),
      exitCriteria: exitCriteria.trim(),
      reviewAtMs: reviewAtMs,
    );
    for (final raw in conceptDefinitions) {
      final sides = raw.split('=').map((item) => item.trim()).toList();
      if (sides.length < 2 || sides.first.isEmpty || sides[1].isEmpty) {
        continue;
      }
      final detail = sides.sublist(1).join('=').split('|');
      final name = sides.first;
      final normalizedName = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '_');
      final conceptId = 'xf_concept_$normalizedName';
      await _dao.saveConceptDefinition(
        conceptId: conceptId,
        versionId: newId('xf_concept_version'),
        name: name,
        definition: detail.first.trim(),
        scope: problemId,
        observableCriteria: detail.length > 1
            ? detail
                .sublist(1)
                .expand((item) => item.split('、'))
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList()
            : const <String>[],
        changeReason: '问题概念审查，由用户确认',
      );
    }
    final decision = _problemMachine.evaluate(
      problem.state,
      XiangjiProblemState.solving,
      const XiangjiProblemTransitionContext(
        conceptsReviewed: true,
        reframedQuestionConfirmed: true,
      ),
    );
    decision.requireAllowed();
    await _dao.updateProblemState(problemId, XiangjiProblemState.solving);
    await _applySignatureMethods(
      problemId: problemId,
      context: XiangjiSignatureMethodContext(
        problemId: problemId,
        problemState: XiangjiProblemState.conceptReview,
        requestedMethodIds: <String>[
          if (conceptDefinitions.isNotEmpty) 'MEC-004',
          if (conceptDefinitions.isNotEmpty) 'MEC-006',
          'MEC-010',
          'MEC-011',
        ],
        decisiveDifference: conceptDefinitions.isEmpty
            ? ''
            : '本轮按当前目标和现实判据重新界定概念边界。',
        abstractLabel: conceptDefinitions.isEmpty
            ? ''
            : conceptDefinitions.first.split('=').first.trim(),
        // This form is itself the user's confirmation gate. Re-open it only
        // when the framed problem and goal are still the same path statement.
        goalNeedsAudit: false,
        pathAsGoal: reframedQuestion.trim() == goalText.trim(),
        candidateGaps: <Map<String, Object?>>[
          <String, Object?>{
            'type': 'action',
            'label': reframedQuestion.trim(),
            'priority': 1,
          },
        ],
        sourceRefs: <String>['problem:$problemId'],
        eventIdPrefix: newId('xf_method_frame'),
      ),
      seed: (snapshot) => snapshot.copyWith(
        problemFrame: <String, Object?>{
          ...snapshot.problemFrame,
          'statement': reframedQuestion.trim(),
          'value_link': valueLink.trim(),
        },
        goalState: <String, Object?>{
          'statement': goalText.trim(),
          'success_criteria': successCriteria.trim(),
          'exit_criteria': exitCriteria.trim(),
        },
      ),
    );
  }

  Future<String> selectOperator({
    required String problemId,
    required String title,
    required String targetGap,
    required String mechanism,
    required String strategicMeaning,
    required String groundingReason,
    required String prediction,
    required int expectedMinutes,
    String campaignId = '',
    List<String> missingPreconditions = const <String>[],
    String expectedEffect = '',
    String cost = '',
    String risk = 'low',
    String reversibility = 'high',
    String informationValue = 'medium',
  }) async {
    final problem = await _requireProblem(problemId);
    if (problem.state != XiangjiProblemState.solving) {
      throw StateError('只有在持续求解阶段才能选定当前办法。');
    }
    if (<String>[title, targetGap, mechanism, strategicMeaning, groundingReason, prediction]
        .any((value) => value.trim().isEmpty)) {
      throw ArgumentError('行动、四层为什么和事前预测必须完整。');
    }
    final normalizedPreconditions = missingPreconditions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final normalizedExpectedEffect = expectedEffect.trim().isEmpty
        ? prediction.trim()
        : expectedEffect.trim();
    final normalizedCost = cost.trim().isEmpty
        ? '$expectedMinutes 分钟'
        : cost.trim();
    final activeTitle = normalizedPreconditions.isEmpty
        ? title.trim()
        : '补齐前提：${normalizedPreconditions.first}';
    final activeMechanism = normalizedPreconditions.isEmpty
        ? mechanism.trim()
        : '先取得前提“${normalizedPreconditions.first}”成立或不成立的现实证据，解除原办法阻塞';
    final activePrediction = normalizedPreconditions.isEmpty
        ? prediction.trim()
        : '完成后应能确认前提“${normalizedPreconditions.first}”是否成立';
    await _dao.addProblemItem(
      id: newId('xf_item'),
      problemId: problemId,
      kind: 'gap',
      text: targetGap.trim(),
      critical: true,
      sortOrder: 0,
    );
    await _dao.addProblemItem(
      id: newId('xf_item'),
      problemId: problemId,
      kind: 'operator',
      text: title.trim(),
      critical: true,
      data: <String, Object?>{
        'target_gap': targetGap.trim(),
        'mechanism': mechanism.trim(),
        'strategic_meaning': strategicMeaning.trim(),
        'grounding_reason': groundingReason.trim(),
        'preconditions': normalizedPreconditions,
        'status': normalizedPreconditions.isEmpty
            ? 'selected'
            : 'blocked_by_precondition',
        'expected_effect': normalizedExpectedEffect,
        'cost': normalizedCost,
        'risk': risk.trim().isEmpty ? 'low' : risk.trim(),
        'reversibility':
            reversibility.trim().isEmpty ? 'high' : reversibility.trim(),
        'information_value': informationValue.trim().isEmpty
            ? '执行后以现实结果更新当前判断'
            : informationValue.trim(),
      },
    );
    for (var index = 0; index < normalizedPreconditions.length; index++) {
      final precondition = normalizedPreconditions[index];
      await _dao.addProblemItem(
        id: newId('xf_item'),
        problemId: problemId,
        kind: 'precondition_subgoal',
        text: precondition,
        critical: true,
        sortOrder: index,
        data: const <String, Object?>{
          'relation': 'AND',
          'status': 'missing',
        },
      );
    }
    final decision = _problemMachine.evaluate(
      problem.state,
      XiangjiProblemState.actionReady,
      const XiangjiProblemTransitionContext(
        goalCriteriaDefined: true,
        operatorSelected: true,
      ),
    );
    decision.requireAllowed();
    final actionId = newId('xf_action');
    await _dao.createAction(
      id: actionId,
      title: activeTitle,
      problemId: problemId,
      campaignId: campaignId,
      prediction: activePrediction,
      expectedMinutes: expectedMinutes,
      whyChain: <String, Object?>{
        'strategic_meaning': strategicMeaning.trim(),
        'key_gap': targetGap.trim(),
        'operator_mechanism': activeMechanism,
        'epistemic_grounding': groundingReason.trim(),
        'action_purpose': strategicMeaning.trim(),
        'time_boundary_minutes': expectedMinutes,
        'stop_condition':
            '达到 $expectedMinutes 分钟仍未出现事前预测中的关键信号时，停止加码并回来验算。',
        'reporting_facts': <String>[
          '是否出现：$activePrediction',
          '实际做了什么，用了多少时间',
          '有什么明显意外或身体、情绪体验',
        ],
        if (normalizedPreconditions.isNotEmpty)
          'blocked_operator': title.trim(),
      },
    );
    final stateVersion = await _dao.latestProblemStateVersion(problemId);
    await _dao.saveSolutionAttempt(<String, Object?>{
      'id': newId('xf_solution_attempt'),
      'problem_id': problemId,
      'state_version_id':
          (stateVersion?['id'] ?? 'legacy_problem:$problemId').toString(),
      'action_id': actionId,
      'operator_id': 'manual_operator:$actionId',
      'rationale': '$activeMechanism；目标差距：$targetGap',
      'prediction_id': '',
      'started_at_ms': 0,
      'ended_at_ms': 0,
      'outcome_ref': '',
      'result_class': 'PENDING',
      'failure_layer': '',
      'status': 'PLANNED',
    });
    await _dao.updateProblemState(
      problemId,
      XiangjiProblemState.actionReady,
    );
    await _applySignatureMethods(
      problemId: problemId,
      context: XiangjiSignatureMethodContext(
        problemId: problemId,
        problemState: XiangjiProblemState.solving,
        requestedMethodIds: const <String>['MEC-011', 'MEC-012', 'MEC-013'],
        candidateGaps: <Map<String, Object?>>[
          <String, Object?>{
            'type': 'action',
            'label': targetGap.trim(),
            'priority': 1,
          },
          for (final precondition in normalizedPreconditions)
            if (precondition.trim().isNotEmpty)
              <String, Object?>{
                'type': 'capability',
                'label': precondition.trim(),
                'priority': 2,
              },
        ],
        missingPreconditions: normalizedPreconditions,
        operatorTitle: title.trim(),
        operatorMechanism: mechanism.trim(),
        operatorExpectedEffect: normalizedExpectedEffect,
        operatorCost: normalizedCost,
        operatorRisk: risk.trim().isEmpty ? 'low' : risk.trim(),
        operatorReversibility:
            reversibility.trim().isEmpty ? 'high' : reversibility.trim(),
        operatorInformationValue: informationValue.trim().isEmpty
            ? '执行后以现实结果更新当前判断'
            : informationValue.trim(),
        prediction: activePrediction,
        sourceRefs: <String>['action:$actionId'],
        eventIdPrefix: newId('xf_method_operator'),
      ),
      seed: (snapshot) => snapshot.copyWith(
        goalState: snapshot.goalState.isEmpty
            ? <String, Object?>{
                'statement': problem.goalText,
                'success_criteria': problem.successCriteria,
              }
            : snapshot.goalState,
      ),
    );
    return actionId;
  }

  Future<void> startAction({
    required String actionId,
    required bool userConfirmed,
  }) async {
    final action = await _requireAction(actionId);
    if (action.state != XiangjiActionState.ready) {
      throw StateError('只有 READY 行动可以开始。');
    }
    if (!userConfirmed) throw StateError('用户未确认当前行动。');
    final alert = await _dao.blockingRedAlert(
      problemId: action.problemId,
      campaignId: action.campaignId,
    );
    if (alert != null) {
      throw StateError('当前为红色预警，原计划已冻结；请先补证、降风险或完成战略复核。');
    }
    XiangjiTransitionDecision<XiangjiProblemState>? problemDecision;
    if (action.problemId.isNotEmpty) {
      final problem = await _requireProblem(action.problemId);
      problemDecision = _problemMachine.evaluate(
        problem.state,
        XiangjiProblemState.executing,
        XiangjiProblemTransitionContext(
          operatorSelected: true,
          predictionPrecommitted: action.prediction.trim().isNotEmpty,
          userConfirmedAction: userConfirmed,
        ),
      );
      problemDecision.requireAllowed();
    }
    if (action.campaignId.isNotEmpty) {
      final campaign = await _requireCampaign(action.campaignId);
      if (campaign.state != XiangjiCampaignState.executing) {
        if (!<XiangjiCampaignState>{
          XiangjiCampaignState.prepare,
          XiangjiCampaignState.hold,
        }.contains(campaign.state)) {
          throw StateError('重大策略尚未经过用户决断与准备，不能进入执行。');
        }
        await transitionCampaign(
          campaignId: action.campaignId,
          target: XiangjiCampaignState.executing,
          userConfirmed: true,
        );
      }
    }
    if (action.problemId.isNotEmpty) {
      await _dao.updateProblemState(
        action.problemId,
        XiangjiProblemState.executing,
      );
    }
    await _dao.updateAction(
      actionId,
      <String, Object?>{
        'state': XiangjiActionState.inProgress.wire,
        'started_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      eventType: 'started',
    );
    await _dao.updateSolutionAttemptForAction(
      actionId,
      <String, Object?>{
        'started_at_ms': DateTime.now().millisecondsSinceEpoch,
        'status': 'EXECUTING',
      },
    );
    if (action.problemId.isNotEmpty) {
      await _appendLifecycleSnapshot(
        problemId: action.problemId,
        state: XiangjiPersistentProblemState.executing,
        currentFocus: '执行已确认的当前一步，并保留事前预测',
        currentExperiment: action.title,
        nextVerification: action.prediction,
        sourceRef: 'action:$actionId',
      );
      await _applySignatureMethods(
        problemId: action.problemId,
        context: XiangjiSignatureMethodContext(
          problemId: action.problemId,
          problemState: XiangjiProblemState.executing,
          requestedMethodIds: const <String>['MEC-013'],
          prediction: action.prediction,
          operatorTitle: action.title,
          actionMode: true,
          visibleLimit: 0,
          sourceRefs: <String>['action:$actionId'],
          eventIdPrefix: newId('xf_method_action'),
        ),
      );
    }
  }

  Future<void> blockAction({
    required String actionId,
    required String blockerType,
  }) async {
    final action = await _requireAction(actionId);
    await _dao.updateAction(
        actionId,
        <String, Object?>{
          'state': XiangjiActionState.blocked.wire,
          'blocker_type': blockerType,
        },
        eventType: 'blocked',
      );
    await _dao.updateSolutionAttemptForAction(
      actionId,
      <String, Object?>{
        'status': 'BLOCKED',
        'failure_layer': 'execution_blocker',
      },
    );
    if (action.problemId.isNotEmpty) {
      await _appendLifecycleSnapshot(
        problemId: action.problemId,
        state: XiangjiPersistentProblemState.executing,
        currentFocus: '当前行动遇到现实阻碍，等待解除或改变路线',
        currentExperiment: action.title,
        nextVerification: '阻碍解除后重新核对原预测是否仍然适用',
        sourceRef: 'action:$actionId',
      );
    }
  }

  Future<void> resumeAction(String actionId) async {
    final action = await _requireAction(actionId);
    if (action.state != XiangjiActionState.blocked) {
      throw StateError('只有受阻行动可以恢复。');
    }
    final alert = await _dao.blockingRedAlert(
      problemId: action.problemId,
      campaignId: action.campaignId,
    );
    if (alert != null) {
      throw StateError('当前为红色预警，不能恢复原计划。');
    }
    await _dao.updateAction(
      actionId,
      <String, Object?>{
        'state': XiangjiActionState.inProgress.wire,
        'blocker_type': '',
      },
      eventType: 'resumed',
    );
    await _dao.updateSolutionAttemptForAction(
      actionId,
      <String, Object?>{
        'status': 'EXECUTING',
        'failure_layer': '',
      },
    );
    if (action.problemId.isNotEmpty) {
      await _appendLifecycleSnapshot(
        problemId: action.problemId,
        state: XiangjiPersistentProblemState.executing,
        currentFocus: '阻碍已解除，继续执行原来的当前一步',
        currentExperiment: action.title,
        nextVerification: action.prediction,
        sourceRef: 'action:$actionId',
      );
    }
  }

  Future<void> completeAction({
    required String actionId,
    required List<String> realityFacts,
    List<String> experiences = const <String>[],
    List<String> unexpected = const <String>[],
    List<String> evidenceRefs = const <String>[],
    String userInterpretation = '',
  }) async {
    final action = await _requireAction(actionId);
    if (!<XiangjiActionState>{
      XiangjiActionState.inProgress,
      XiangjiActionState.blocked,
    }.contains(action.state)) {
      throw StateError('当前行动不能完成。');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.updateAction(
      actionId,
      <String, Object?>{
        'state': XiangjiActionState.done.wire,
        'completed_at_ms': now,
      },
      eventType: 'done',
    );
    await _dao.updateSolutionAttemptForAction(
      actionId,
      <String, Object?>{
        'ended_at_ms': now,
        'status': realityFacts.isEmpty
            ? 'ACTION_DONE_AWAITING_REALITY'
            : 'RESULT_AVAILABLE',
        'outcome_ref': realityFacts.isEmpty ? '' : 'reality_pending:$actionId',
      },
    );
    if (action.todoRef.isNotEmpty) {
      await _todoDao.updateTaskCompletion(
        taskId: action.todoRef,
        completed: true,
      );
    }
    if (realityFacts.isEmpty) {
      // Action DONE is valid, but the Problem remains EXECUTING until reality
      // is captured. This is an explicit state-machine invariant.
      if (action.problemId.isNotEmpty) {
        await _appendLifecycleSnapshot(
          problemId: action.problemId,
          state: XiangjiPersistentProblemState.executing,
          currentFocus: '行动已完成，但现实结果尚未回填',
          currentExperiment: action.title,
          nextVerification: '记录实际发生的事实，再与事前预测验算',
          sourceRef: 'action:$actionId',
        );
      }
      return;
    }
    await _dao.recordRealityResult(
      id: newId('xf_reality'),
      actionId: actionId,
      facts: realityFacts.map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
      experiences: experiences,
      unexpected: unexpected,
      sourceRefs: evidenceRefs,
      userInterpretation: userInterpretation,
    );
    await _dao.updateSolutionAttemptForAction(
      actionId,
      <String, Object?>{
        'ended_at_ms': DateTime.now().millisecondsSinceEpoch,
        'outcome_ref': 'reality:$actionId',
        'status': 'RESULT_AVAILABLE',
      },
    );
    if (action.problemId.isNotEmpty) {
      final problem = await _requireProblem(action.problemId);
      final decision = _problemMachine.evaluate(
        problem.state,
        XiangjiProblemState.verifying,
        const XiangjiProblemTransitionContext(realityResultPresent: true),
      );
      decision.requireAllowed();
      await _dao.updateProblemState(
        action.problemId,
        XiangjiProblemState.verifying,
      );
      await _appendLifecycleSnapshot(
        problemId: action.problemId,
        state: XiangjiPersistentProblemState.realityReturn,
        currentFocus: '现实结果已经回来，正在与事前预测对照',
        currentExperiment: action.title,
        nextVerification: action.prediction,
        sourceRef: 'reality:$actionId',
        additionalFacts: realityFacts,
      );
    }
  }

  Future<void> recordRealityForCompletedAction({
    required String actionId,
    required List<String> realityFacts,
    List<String> experiences = const <String>[],
    List<String> unexpected = const <String>[],
    List<String> evidenceRefs = const <String>[],
    String userInterpretation = '',
  }) async {
    final action = await _requireAction(actionId);
    if (action.state != XiangjiActionState.done) {
      throw StateError('只有已完成行动可以补录现实结果。');
    }
    if (realityFacts.isEmpty) {
      throw ArgumentError('请至少填写一项可观察事实。');
    }
    if (await _dao.realityResult(actionId) != null) {
      throw StateError('该行动已经有现实结果，请进入验算。');
    }
    if (action.problemId.isNotEmpty) {
      var problem = await _requireProblem(action.problemId);
      if (problem.state == XiangjiProblemState.actionReady) {
        if (action.campaignId.isNotEmpty) {
          final campaign = await _requireCampaign(action.campaignId);
          if (campaign.state != XiangjiCampaignState.executing) {
            if (!<XiangjiCampaignState>{
              XiangjiCampaignState.prepare,
              XiangjiCampaignState.hold,
            }.contains(campaign.state)) {
              throw StateError('重大策略尚未经过用户决断，不能用任务完成绕过执行门。');
            }
            await transitionCampaign(
              campaignId: action.campaignId,
              target: XiangjiCampaignState.executing,
              userConfirmed: true,
            );
          }
        }
        final startDecision = _problemMachine.evaluate(
          problem.state,
          XiangjiProblemState.executing,
          XiangjiProblemTransitionContext(
            operatorSelected: true,
            predictionPrecommitted: action.prediction.trim().isNotEmpty,
            userConfirmedAction: true,
          ),
        );
        startDecision.requireAllowed();
        await _dao.updateProblemState(
          action.problemId,
          XiangjiProblemState.executing,
        );
        problem = await _requireProblem(action.problemId);
      }
      if (problem.state != XiangjiProblemState.executing) {
        throw StateError('问题不在执行阶段，不能用现实回填绕过状态机。');
      }
    }
    await _dao.recordRealityResult(
      id: newId('xf_reality'),
      actionId: actionId,
      facts: realityFacts,
      experiences: experiences,
      unexpected: unexpected,
      sourceRefs: evidenceRefs,
      userInterpretation: userInterpretation,
    );
    await _dao.updateSolutionAttemptForAction(
      actionId,
      <String, Object?>{
        'ended_at_ms': DateTime.now().millisecondsSinceEpoch,
        'outcome_ref': 'reality:$actionId',
        'status': 'RESULT_AVAILABLE',
      },
    );
    if (action.problemId.isEmpty) return;
    final problem = await _requireProblem(action.problemId);
    final decision = _problemMachine.evaluate(
      problem.state,
      XiangjiProblemState.verifying,
      const XiangjiProblemTransitionContext(realityResultPresent: true),
    );
    decision.requireAllowed();
    await _dao.updateProblemState(
      action.problemId,
      XiangjiProblemState.verifying,
    );
    await _appendLifecycleSnapshot(
      problemId: action.problemId,
      state: XiangjiPersistentProblemState.realityReturn,
      currentFocus: '现实结果已经回来，正在与事前预测对照',
      currentExperiment: action.title,
      nextVerification: action.prediction,
      sourceRef: 'reality:$actionId',
      additionalFacts: realityFacts,
    );
  }

  Future<void> verifyAction({
    required String actionId,
    required String verdict,
    required bool resolutionCriteriaMet,
    String aiModelRunId = '',
    String wrongClaimId = '',
    String correction = '',
  }) async {
    final action = await _requireAction(actionId);
    final reality = await _dao.realityResult(actionId);
    if (reality == null) throw StateError('缺少 RealityResult，不能验算。');
    if (!<String>{'supports', 'partly_supports', 'refutes', 'unknown'}
        .contains(verdict)) {
      throw ArgumentError('未知验算结论。');
    }
    await _dao.setRealityVerdict(actionId, verdict);
    final hypothesisStatus = switch (verdict) {
      'supports' => XiangjiHypothesisStatus.supported,
      'partly_supports' => XiangjiHypothesisStatus.weakened,
      'refutes' => XiangjiHypothesisStatus.contradicted,
      _ => XiangjiHypothesisStatus.indeterminate,
    };
    final hypothesisConclusion = switch (verdict) {
      'supports' => '这次现实结果与事前预测一致，当前解释得到有限支持。',
      'partly_supports' => '现实只支持了部分预测，需要收窄解释边界后继续验证。',
      'refutes' => '现实没有出现事前预测的结果，当前解释或关键前提受到挑战。',
      _ => '这次现实结果不足以区分候选解释，需要新的低成本检验。',
    };
    await _dao.reconcileHypothesisTestsForAction(
      actionId: actionId,
      resultRef: 'reality:${reality['id']}',
      conclusion: hypothesisConclusion,
      status: hypothesisStatus,
    );
    await _dao.updateSolutionAttemptForAction(
      actionId,
      <String, Object?>{
        'outcome_ref': 'reality:${reality['id']}',
        'result_class': verdict.toUpperCase(),
        'failure_layer': verdict == 'refutes' ? 'operator_or_premise' : '',
        'status': 'VERIFIED',
      },
    );
    if (action.problemId.isEmpty) return;
    final problem = await _requireProblem(action.problemId);
    final next = resolutionCriteriaMet && verdict == 'supports'
        ? XiangjiProblemState.resolved
        : verdict == 'refutes'
            ? XiangjiProblemState.backtracking
            : XiangjiProblemState.solving;
    final decision = _problemMachine.evaluate(
      problem.state,
      next,
      XiangjiProblemTransitionContext(
        // Re-entering SOLVING after a completed reality cycle continues the
        // problem boundary that the user already confirmed before execution;
        // it is not a fresh AI rewrite of the original question.
        conceptsReviewed: next == XiangjiProblemState.solving,
        reframedQuestionConfirmed: next == XiangjiProblemState.solving,
        realityResultPresent: true,
        resolutionCriteriaMet: resolutionCriteriaMet,
      ),
    );
    decision.requireAllowed();
    await _dao.updateProblemState(action.problemId, next);
    await _appendLifecycleSnapshot(
      problemId: action.problemId,
      state: switch (next) {
        XiangjiProblemState.resolved =>
          XiangjiPersistentProblemState.resolved,
        XiangjiProblemState.backtracking =>
          XiangjiPersistentProblemState.backtrack,
        _ => XiangjiPersistentProblemState.continuing,
      },
      currentFocus: switch (next) {
        XiangjiProblemState.resolved => '阶段性成功判据已经由现实满足',
        XiangjiProblemState.backtracking => '现实反驳旧预测，正在定位最早错误层',
        _ => '根据本次现实结果继续缩小关键差距',
      },
      currentExperiment: '',
      nextVerification: next == XiangjiProblemState.resolved
          ? '若成功判据失效或出现新反例，在同一问题身份下重开'
          : '根据新版本选择下一项可逆实验',
      sourceRef: 'reality:${reality['id']}',
      resolvedItem: next == XiangjiProblemState.resolved
          ? problem.successCriteria
          : '',
    );
    if (verdict == 'refutes') {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _dao.saveAiError(<String, Object?>{
        'id': newId('xf_ai_error'),
        'model_run_id': aiModelRunId.isEmpty
            ? 'local_sck_reconciliation:$actionId'
            : aiModelRunId,
        'wrong_claim_id': wrongClaimId,
        'discovered_by': 'reality_result:${reality['id']}',
        'impact': '行动现实反驳了 AI 参与形成的预测/判断',
        'correction': correction,
        'corrected_at_ms': now,
      });
    }
    await _applySignatureMethods(
      problemId: action.problemId,
      context: XiangjiSignatureMethodContext(
        problemId: action.problemId,
        problemState: verdict == 'refutes'
            ? XiangjiProblemState.backtracking
            : XiangjiProblemState.verifying,
        requestedMethodIds: <String>[
          'MEC-013',
          if (verdict == 'refutes') 'MEC-009',
          if (verdict == 'refutes') 'MEC-014',
        ],
        prediction: action.prediction,
        reality: reality,
        realityVerdict: verdict,
        realityConflict: verdict == 'refutes',
        earliestFailedLayer:
            verdict == 'refutes' ? 'operator_or_premise' : '',
        operatorTitle: action.title,
        sourceRefs: <String>['reality:${reality['id']}'],
        eventIdPrefix: newId('xf_method_reality'),
      ),
    );
  }

  Future<String> createCampaign({
    required String title,
    required String northStar,
    required String strategicValue,
    bool isPrimary = false,
  }) =>
      _dao.createCampaign(
        id: newId('xf_campaign'),
        title: title.trim(),
        northStar: northStar.trim(),
        strategicValue: strategicValue.trim(),
        isPrimary: isPrimary,
      );

  Future<void> defineCampaignFoundation({
    required String campaignId,
    required String warWorthiness,
    required String victoryCriteria,
    required String exitCriteria,
    required Map<String, Object?> resourceBudget,
    required int reviewAtMs,
  }) async {
    if (warWorthiness.trim().isEmpty ||
        victoryCriteria.trim().isEmpty ||
        exitCriteria.trim().isEmpty ||
        resourceBudget.isEmpty) {
      throw ArgumentError('值得一战、胜利/止损、兵力预算和复核时间必须完整。');
    }
    await _dao.updateCampaign(
      campaignId,
      <String, Object?>{
        'war_worthiness': warWorthiness.trim(),
        'victory_criteria': victoryCriteria.trim(),
        'exit_criteria': exitCriteria.trim(),
        'resource_budget_json': jsonEncode(resourceBudget),
        'review_at_ms': reviewAtMs,
      },
      createVersion: true,
    );
  }

  Future<void> addCampaignIntel({
    required String campaignId,
    required String kind,
    required String text,
    String sourceRef = '',
    String sourceQuality = 'unknown',
    String freshness = 'unknown',
    XiangjiClaimState state = XiangjiClaimState.unresolved,
  }) =>
      _dao.addCampaignIntel(<String, Object?>{
        'id': newId('xf_intel'),
        'campaign_id': campaignId,
        'kind': kind,
        'text': text,
        'source_ref': sourceRef,
        'source_quality': sourceQuality,
        'freshness': freshness,
        'conflict_of_interest': '',
        'epistemic_status': state.wire,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> addStrategyOption({
    required String campaignId,
    required String name,
    required String type,
    required List<String> benefits,
    required List<String> costs,
    required String opportunityCost,
    required String reversibility,
    required List<String> assumptions,
    required List<String> stopConditions,
    String targetGap = '',
    String mechanismForThisCase = '',
    String whyNotOtherOptions = '',
    String switchTrigger = '',
    String userSummary = '',
    String evidenceLevel = 'hypothesis',
  }) async {
    final existingOptions = await _dao.strategyOptions(campaignId);
    final preferred = existingOptions.isEmpty;
    final currentVersion = existingOptions.isEmpty
        ? 1
        : (existingOptions.first['version_no'] as num?)?.toInt() ?? 1;
    await _dao.addStrategyOption(<String, Object?>{
        'id': newId('xf_strategy'),
        'campaign_id': campaignId,
        'name': name,
        'strategy_type': type,
        'benefits_json': jsonEncode(benefits),
        'costs_json': jsonEncode(costs),
        'opportunity_cost': opportunityCost,
        'reversibility': reversibility,
        'key_assumptions_json': jsonEncode(assumptions),
        'stop_conditions_json': jsonEncode(stopConditions),
        'target_gap': targetGap.trim().isEmpty
            ? '缩小当前战役目标与现实之间最关键的差距'
            : targetGap.trim(),
        'mechanism_for_this_case': mechanismForThisCase.trim().isEmpty
            ? '通过“${name.trim()}”在当前约束下改变关键条件，并用停止条件限制风险。'
            : mechanismForThisCase.trim(),
        'key_assumption': assumptions.isEmpty ? '' : assumptions.first,
        'why_preferred': preferred
            ? '这是当前首个完整候选路线；形成其他真正不同的路线后应重新比较。'
            : '',
        'why_not_other_options': whyNotOtherOptions.trim(),
        'switch_trigger': switchTrigger.trim().isEmpty
            ? (stopConditions.isEmpty ? '' : stopConditions.first)
            : switchTrigger.trim(),
        'user_summary': userSummary.trim().isEmpty
            ? '${name.trim()}：${benefits.join('；')}'
            : userSummary.trim(),
        'preferred': preferred ? 1 : 0,
        'evidence_level': evidenceLevel,
        'selected': 0,
        'version_no': currentVersion,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
  }

  Future<void> transitionCampaign({
    required String campaignId,
    required XiangjiCampaignState target,
    bool userConfirmed = false,
    bool reviewRecorded = false,
  }) async {
    final campaign = await _requireCampaign(campaignId);
    if (target == XiangjiCampaignState.executing) {
      final alert = await _dao.blockingRedAlert(campaignId: campaignId);
      if (alert != null) {
        throw StateError('当前为红色预警，战役推进已冻结；请先完成补证与复核。');
      }
    }
    final intel = await _dao.campaignIntel(campaignId);
    final options = await _dao.strategyOptions(campaignId);
    final criticalUnknowns = intel.where((row) =>
        (row['kind'] ?? '').toString() == 'critical_unknown' &&
        (row['epistemic_status'] ?? '').toString() == 'UNRESOLVED');
    final redTeamComplete = intel.any(
      (row) => (row['kind'] ?? '').toString() == 'red_team_review',
    );
    final context = XiangjiCampaignTransitionContext(
      worthinessReviewed: campaign.warWorthiness.trim().isNotEmpty,
      victoryAndExitCriteriaDefined:
          campaign.victoryCriteria.trim().isNotEmpty &&
              campaign.exitCriteria.trim().isNotEmpty,
      resourceBudgetDefined: campaign.resourceBudget.isNotEmpty,
      criticalUnknownsHandled: criticalUnknowns.isEmpty,
      strategyOptionCount: options.length,
      redTeamComplete: redTeamComplete,
      userConfirmed: userConfirmed || campaign.userConfirmed,
      reviewRecorded: reviewRecorded,
    );
    final decision = _campaignMachine.evaluate(campaign.state, target, context);
    decision.requireAllowed();
    if (target == XiangjiCampaignState.prepare) {
      await _dao.selectPreferredStrategy(campaignId);
    }
    await _dao.updateCampaign(
      campaignId,
      <String, Object?>{
        'state': target.wire,
        if (userConfirmed) 'user_confirmed': 1,
      },
      createVersion: target == XiangjiCampaignState.adjust ||
          target == XiangjiCampaignState.planning,
    );
  }

  Future<String> bindActionToNewTodo(String actionId) async {
    final action = await _requireAction(actionId);
    final lists = await _todoDao.listLists();
    var target = lists.where((list) => list.displayName == '向己·未来军师').toList();
    final listId = target.isEmpty
        ? await _todoDao.createLocalList('向己·未来军师')
        : target.first.listId;
    const whyLabels = <String, String>{
      'strategic_meaning': '它服务的更高目标',
      'key_gap': '目标差距',
      'operator_mechanism': '为什么这一步可能有效',
      'epistemic_grounding': '当前依据',
    };
    final whyText = action.whyChain.entries
        .where((entry) =>
            whyLabels.containsKey(entry.key) &&
            entry.value.toString().trim().isNotEmpty)
        .map((entry) =>
            '${whyLabels[entry.key] ?? '理由'}：${entry.value.toString().trim()}')
        .join('\n');
    final taskId = await _todoDao.createLocalTask(
      listId: listId,
      title: action.title,
      bodyText:
          '来自向己·未来军师\n${whyText.isEmpty ? '为什么：等待进一步说明' : whyText}\n事前预测：${action.prediction}',
      status: 'notStarted',
      importance: 'high',
      isMyDay: true,
      categoriesJson: jsonEncode(const <String>['向己未来军师']),
    );
    await _dao.saveTodoBinding(
      id: newId('xf_todo_binding'),
      actionId: actionId,
      todoTaskId: taskId,
      todoListId: listId,
    );
    return taskId;
  }

  Future<void> bindActionToExistingTodo({
    required String actionId,
    required String todoTaskId,
    required String todoListId,
  }) async {
    final task = await _todoDao.getTask(todoTaskId);
    if (task == null) throw ArgumentError('所选 Todo 不存在。');
    await _dao.saveTodoBinding(
      id: newId('xf_todo_binding'),
      actionId: actionId,
      todoTaskId: todoTaskId,
      todoListId: todoListId,
    );
  }

  /// Microsoft Todo remains the single source of completion truth. A completed
  /// Todo marks Action DONE, but never fabricates RealityResult or resolves the
  /// parent Problem/Campaign.
  Future<void> refreshTodoBindings() async {
    final bindings = await _dao.todoBindings();
    for (final binding in bindings) {
      final taskId = (binding['todo_task_id'] ?? '').toString();
      final actionId = (binding['action_id'] ?? '').toString();
      if (taskId.isEmpty || actionId.isEmpty) continue;
      final task = await _todoDao.getTask(taskId);
      final action = await _dao.action(actionId);
      if (task?.isCompleted == true &&
          action != null &&
          action.state != XiangjiActionState.done) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await _dao.updateAction(
          actionId,
          <String, Object?>{
            'state': XiangjiActionState.done.wire,
            'completed_at_ms': now,
          },
          eventType: 'todo_completed',
        );
        await _dao.updateSolutionAttemptForAction(
          actionId,
          <String, Object?>{
            'ended_at_ms': now,
            'status': 'ACTION_DONE_AWAITING_REALITY',
          },
        );
        if (action.problemId.isNotEmpty) {
          await _appendLifecycleSnapshot(
            problemId: action.problemId,
            state: XiangjiPersistentProblemState.executing,
            currentFocus: '行动已完成，但现实结果尚未回填',
            currentExperiment: action.title,
            nextVerification: '记录实际发生的事实，再与事前预测验算',
            sourceRef: 'todo:$taskId',
          );
        }
      }
    }
  }

  Future<XiangjiMonitorResult> runMonitor({
    required XiangjiMonitorInput input,
    String campaignId = '',
    String problemId = '',
  }) async {
    final result = _monitor.evaluate(input);
    if (result.state != XiangjiAlertState.green) {
      await _dao.saveAlert(
        id: newId('xf_alert'),
        state: result.state,
        alertType: 'periodic_monitor',
        reason: result.reason,
        defaultAction: result.defaultAction,
        campaignId: campaignId,
        problemId: problemId,
      );
    }
    return result;
  }

  Future<XiangjiMonitorResult> refreshAutomaticWatch() async {
    const alertType = 'rev4_background_watch';
    final values = await _dao.automaticMonitorSignals();
    int count(String key) => (values[key] as num?)?.toInt() ?? 0;
    bool flag(String key) => values[key] == true;
    final result = _monitor.evaluate(XiangjiMonitorInput(
      criticalUnknownCount: count('critical_unknown_count'),
      consecutivePredictionMisses:
          count('consecutive_prediction_misses'),
      investmentRisingWithoutResultCycles:
          count('investment_rising_without_result_cycles'),
      parallelHighLoadCampaigns: count('parallel_high_load_campaigns'),
      highRiskIrreversible: flag('high_risk_irreversible'),
      highEpistemicDebt: flag('high_epistemic_debt'),
      opportunityConditionsMet: count('opportunity_conditions_met'),
      opportunityConditionTotal: count('opportunity_condition_total'),
      conceptRealityConflicts: count('concept_reality_conflicts'),
      strategyResourceDriftCount: count('strategy_resource_drift_count'),
    ));
    final existing = await _dao.latestOpenAlertForType(alertType);
    final relatedProblemId =
        (values['related_problem_id'] ?? values['risk_problem_id'] ?? '')
            .toString();
    if (result.state == XiangjiAlertState.green) {
      if (existing != null) await _dao.resolveOpenAlertsOfType(alertType);
      return result;
    }
    final unchanged = existing != null &&
        (existing['state'] ?? '').toString() == result.state.wire &&
        (existing['reason'] ?? '').toString() == result.reason &&
        (existing['problem_id'] ?? '').toString() == relatedProblemId;
    if (!unchanged) {
      if (existing != null) await _dao.resolveOpenAlertsOfType(alertType);
      final alertId = newId('xf_watch_alert');
      await _dao.saveAlert(
        id: alertId,
        state: result.state,
        alertType: alertType,
        reason: result.reason,
        defaultAction: result.defaultAction,
        problemId: relatedProblemId,
      );
      if (<XiangjiAlertState>{
        XiangjiAlertState.orange,
        XiangjiAlertState.red,
        XiangjiAlertState.blue,
      }.contains(result.state)) {
        await _persistBackgroundCouncil(
          alertId: alertId,
          result: result,
          signals: values,
        );
      }
    }
    return result;
  }

  Future<void> _persistBackgroundCouncil({
    required String alertId,
    required XiangjiMonitorResult result,
    required Map<String, Object?> signals,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final problemId =
        (signals['related_problem_id'] ?? signals['risk_problem_id'] ?? '')
            .toString();
    final monitorRunId = newId('xf_agent_run');
    final chiefRunId = newId('xf_agent_run');
    final inputRefs = <String>['alert:$alertId'];
    final monitorOutput = <String, Object?>{
      'high_value_change': true,
      'alert_state': result.state.wire,
      'reason': result.reason,
      'signals': signals,
      'sck_rules': const <String>['SCK-014', 'SCK-017', 'SCK-018'],
      'next_agent': XiangjiAgentId.chiefStrategist.code,
    };
    await _dao.saveAgentRun(<String, Object?>{
      'id': monitorRunId,
      'problem_id': problemId,
      'campaign_id': '',
      'agent_role': XiangjiAgentId.monitor.code,
      'orchestration_state': XiangjiOrchestrationState.backgroundWatch.wire,
      'model_run_id': '',
      'input_refs_json': jsonEncode(inputRefs),
      'output_refs_json': jsonEncode(<String>['agent_run:$chiefRunId']),
      'output_json': jsonEncode(monitorOutput),
      'status': 'LOCAL_COMPLETE',
      'started_at_ms': now,
      'ended_at_ms': now,
    });
    await _dao.saveAgentRun(<String, Object?>{
      'id': chiefRunId,
      'problem_id': problemId,
      'campaign_id': '',
      'agent_role': XiangjiAgentId.chiefStrategist.code,
      'orchestration_state': XiangjiOrchestrationState.backgroundWatch.wire,
      'model_run_id': '',
      'input_refs_json': jsonEncode(<String>['agent_run:$monitorRunId']),
      'output_refs_json': jsonEncode(<String>['alert:$alertId']),
      'output_json': jsonEncode(<String, Object?>{
        'strategist_judgment': result.reason,
        'recommendation': result.defaultAction,
        'why': '跨周期信号已达到高价值变化门槛；只发起本次军议，不自动执行重大承诺。',
        'current_action': result.defaultAction,
        'change_signals': signals,
        'user_decision_required': true,
      }),
      'status': 'LOCAL_COMPLETE',
      'started_at_ms': now,
      'ended_at_ms': now,
    });
  }

  bool _feedbackMeetsSuccessCriteria({
    required String feedback,
    required String successCriteria,
  }) {
    final criteria = successCriteria.trim().toLowerCase();
    final reality = feedback.trim().toLowerCase();
    if (criteria.isEmpty || reality.isEmpty) return false;
    final positiveResult = const <String>[
      '达到',
      '满足',
      '实现',
      '已经解决',
      '成功',
      '收到',
      '获得',
      '完成',
    ].any(reality.contains);
    if (!positiveResult) return false;
    final criteriaTerms = RegExp(r'[a-z0-9]+|[\u4e00-\u9fff]{2,}')
        .allMatches(criteria)
        .map((match) => match.group(0)!)
        .where((term) => term.length >= 2)
        .toSet();
    return criteriaTerms.any(reality.contains);
  }

  Future<void> _appendLifecycleSnapshot({
    required String problemId,
    required XiangjiPersistentProblemState state,
    required String currentFocus,
    required String currentExperiment,
    required String nextVerification,
    required String sourceRef,
    String resolvedItem = '',
    List<String> additionalFacts = const <String>[],
  }) async {
    final latest = await _dao.latestProblemStateVersion(problemId);
    List<String> strings(Object? raw) {
      try {
        final value = raw is String ? jsonDecode(raw) : raw;
        if (value is! List) return const <String>[];
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } catch (_) {
        return const <String>[];
      }
    }

    final facts = <String>{
      ...strings(latest?['facts_json']),
      ...additionalFacts.map((item) => item.trim()).where((item) => item.isNotEmpty),
    };
    final resolved = <String>{
      ...strings(latest?['resolved_items_json']),
      if (resolvedItem.trim().isNotEmpty) resolvedItem.trim(),
    };
    await _dao.saveProblemStateVersion(<String, Object?>{
      'id': newId('xf_problem_state'),
      'problem_id': problemId,
      'version_no': await _dao.nextProblemStateVersion(problemId),
      'lifecycle_state': state.wire,
      'facts_json': jsonEncode(facts.toList()),
      'unknowns_json': latest?['unknowns_json'] ?? '[]',
      'assumptions_json': latest?['assumptions_json'] ?? '[]',
      'constraints_json': latest?['constraints_json'] ?? '[]',
      'key_gap': latest?['key_gap'] ?? '',
      'current_hypotheses_json':
          latest?['current_hypotheses_json'] ?? '[]',
      'selected_operator_json':
          latest?['selected_operator_json'] ?? '{}',
      'resolved_items_json': jsonEncode(resolved.toList()),
      'current_focus': currentFocus,
      'current_experiment': currentExperiment,
      'next_verification': nextVerification,
      'generated_by': 'PERSISTENT_LIFECYCLE_GUARD',
      'source_refs_json': jsonEncode(<String>[sourceRef]),
      'stale_reason': '',
    });
  }

  Future<void> _markProblemResolved({
    required XiangjiProblemRecord problem,
    required XiangjiCouncilResult result,
    required String realityRef,
  }) async {
    final latest = await _dao.latestProblemStateVersion(problem.id);
    final resolvedItems = <String>{
      ...?result.problemProgress?.resolvedItems,
      if (problem.successCriteria.trim().isNotEmpty)
        problem.successCriteria.trim(),
    };
    await _dao.saveProblemStateVersion(<String, Object?>{
      'id': newId('xf_problem_state'),
      'problem_id': problem.id,
      'version_no': await _dao.nextProblemStateVersion(problem.id),
      'lifecycle_state': XiangjiPersistentProblemState.resolved.wire,
      'facts_json': latest?['facts_json'] ?? '[]',
      'unknowns_json': latest?['unknowns_json'] ?? '[]',
      'assumptions_json': latest?['assumptions_json'] ?? '[]',
      'constraints_json': latest?['constraints_json'] ?? '[]',
      'key_gap': '',
      'current_hypotheses_json':
          latest?['current_hypotheses_json'] ?? '[]',
      'selected_operator_json':
          latest?['selected_operator_json'] ?? '{}',
      'resolved_items_json': jsonEncode(resolvedItems.toList()),
      'current_focus': '阶段性成功判据已经由现实结果满足',
      'current_experiment': '',
      'next_verification': '若成功判据失效或出现新的反例，在同一问题身份下重开。',
      'generated_by': 'PS-024_RESOLUTION_GUARD',
      'source_refs_json': jsonEncode(<String>[realityRef]),
      'stale_reason': '',
    });
    await _dao.updateProblemState(
      problem.id,
      XiangjiProblemState.resolved,
      actor: 'resolution_guard',
    );
  }

  Future<void> _applySignatureMethodsFromCouncil({
    required XiangjiCouncilResult result,
    required String utterance,
    required List<String> sourceRefs,
    bool realityContradicted = false,
  }) async {
    final draft = result.draft;
    final problem = await _requireProblem(result.problemId);
    final text = <String>[
      utterance,
      ...draft.bodyExperiences,
      ...draft.userInterpretations,
    ].join('；');
    final requested = <String>[];
    void add(String methodId, bool condition) {
      if (condition && !requested.contains(methodId)) requested.add(methodId);
    }

    if (realityContradicted) {
      requested.addAll(const <String>['MEC-013', 'MEC-009', 'MEC-014']);
    } else {
      add(
        'MEC-005',
        RegExp(r'说不清|不对劲|怪怪的|难以描述').hasMatch(text),
      );
      add(
        'MEC-001',
        draft.userInterpretations.isNotEmpty &&
            (draft.observedFacts.isNotEmpty ||
                draft.bodyExperiences.isNotEmpty),
      );
      add(
        'MEC-002',
        RegExp(r'害怕|恐惧|抗拒|焦虑|胸口|心慌|不想|感觉').hasMatch(text) &&
            RegExp(r'所以|说明|一定|肯定|就是因为|证明').hasMatch(text),
      );
      add('MEC-003', draft.causalHypotheses.isNotEmpty);
      add('MEC-004', draft.relevantDifferences.isNotEmpty);
      add(
        'MEC-006',
        RegExp(r'本质|天生|性格|能力|适合|失败者|拖延|人格').hasMatch(text),
      );
      add(
        'MEC-007',
        draft.groundingReason.isNotEmpty &&
            (draft.unknowns.isNotEmpty ||
                draft.epistemicStatus == 'EPISTEMIC_DEBT'),
      );
      add(
        'MEC-008',
        draft.unknowns.isNotEmpty &&
            (draft.assumptions.isNotEmpty || draft.operators.isNotEmpty),
      );
      add('MEC-010', draft.goal.isNotEmpty);
      add(
        'MEC-011',
        draft.targetGap.isNotEmpty ||
            draft.operators.any(
              (item) =>
                  (item['target_gap'] ?? '').toString().trim().isNotEmpty,
            ),
      );
      add(
        'MEC-012',
        (draft.currentAction.isNotEmpty &&
                draft.operatorMechanism.isNotEmpty) ||
            draft.operators.any(
              (item) =>
                  (item['mechanism'] ?? item['mechanism_for_this_case'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty,
            ),
      );
      add(
        'MEC-013',
        draft.prediction.isNotEmpty ||
            draft.operators.any(
              (item) =>
                  (item['prediction'] ?? '').toString().trim().isNotEmpty,
            ),
      );
    }
    final canAdvanceOperator = result.actionId.isNotEmpty &&
        !result.executionFrozen &&
        result.clarificationQuestion.isEmpty;
    if (!realityContradicted && !canAdvanceOperator) {
      requested
        ..remove('MEC-012')
        ..remove('MEC-013');
    }

    final operator = draft.operators.isEmpty
        ? const <String, Object?>{}
        : draft.operators.first;
    String operatorText(List<String> keys, String fallback) {
      for (final key in keys) {
        final value = (operator[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return fallback;
    }

    List<String> operatorStrings(String key) {
      final value = operator[key];
      if (value is! List) return const <String>[];
      return value
          .map((item) {
            if (item is Map) {
              final status = (item['status'] ?? '').toString().toLowerCase();
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
          .toList();
    }

    final missingPreconditions = operatorStrings('preconditions');
    final resolvedOperatorTitle = operatorText(
      const <String>['title', 'name'],
      draft.currentAction,
    );
    final resolvedTargetGap = operatorText(
      const <String>['target_gap'],
      draft.targetGap,
    );
    final resolvedMechanism = operatorText(
      const <String>['mechanism', 'mechanism_for_this_case'],
      draft.operatorMechanism,
    );
    final resolvedPrediction = operatorText(
      const <String>['prediction'],
      draft.prediction,
    );
    final activePrediction = missingPreconditions.isEmpty
        ? resolvedPrediction
        : '完成后应能确认前提“${missingPreconditions.first}”是否成立';
    final environmentConstraints = draft.constraints
        .where(
          (item) => RegExp(r'环境|外部|政策|市场|地点|他人|关系|窗口|时机')
              .hasMatch(item),
        )
        .toList();
    final gapVector = <Map<String, Object?>>[
      <String, Object?>{
        'id': 'gap-information-${result.problemId}',
        'type': 'information',
        'label': draft.unknowns.isEmpty
            ? '当前没有会改变下一步的关键信息缺口'
            : draft.unknowns.first,
        'items': draft.unknowns,
        'priority': draft.unknowns.isEmpty ? 0 : 90,
        'impact': draft.unknowns.isEmpty ? 0 : 4,
        'controllability': 4,
        'dependency_weight': 4,
        'information_value': draft.unknowns.isEmpty ? 0 : 5,
      },
      <String, Object?>{
        'id': 'gap-concept-${result.problemId}',
        'type': 'concept',
        'label': draft.counterexamples.isEmpty
            ? '当前概念边界尚未形成主要阻塞'
            : '当前概念仍有反例或边界未解释',
        'items': draft.counterexamples,
        'priority': draft.counterexamples.isEmpty ? 0 : 80,
        'impact': draft.counterexamples.isEmpty ? 0 : 4,
        'controllability': 3,
        'dependency_weight': 4,
        'information_value': draft.counterexamples.isEmpty ? 0 : 4,
      },
      <String, Object?>{
        'id': 'gap-capability-${result.problemId}',
        'type': 'capability',
        'label': missingPreconditions.isNotEmpty
            ? missingPreconditions.first
            : draft.subGoals.isNotEmpty
                ? draft.subGoals.first
                : '当前未发现需要先补齐的能力或前提',
        'items': <String>{...missingPreconditions, ...draft.subGoals}.toList(),
        'priority': missingPreconditions.isNotEmpty
            ? 105
            : draft.subGoals.isNotEmpty
                ? 75
                : 0,
        'impact': missingPreconditions.isNotEmpty ? 5 : 3,
        'controllability': 4,
        'dependency_weight': missingPreconditions.isNotEmpty ? 5 : 2,
        'information_value': 3,
      },
      <String, Object?>{
        'id': 'gap-resource-${result.problemId}',
        'type': 'resource',
        'label': draft.constraints.isEmpty
            ? '当前资源预算未形成主要阻塞'
            : draft.constraints.first,
        'items': draft.constraints,
        'priority': draft.constraints.isEmpty ? 0 : 70,
        'impact': draft.constraints.isEmpty ? 0 : 4,
        'controllability': 3,
        'dependency_weight': 3,
        'information_value': 2,
      },
      <String, Object?>{
        'id': 'gap-environment-${result.problemId}',
        'type': 'environment',
        'label': environmentConstraints.isEmpty
            ? '当前环境条件未形成主要阻塞'
            : environmentConstraints.first,
        'items': environmentConstraints,
        'priority': environmentConstraints.isEmpty ? 0 : 65,
        'impact': environmentConstraints.isEmpty ? 0 : 4,
        'controllability': 2,
        'dependency_weight': 3,
        'information_value': 3,
      },
      <String, Object?>{
        'id': 'gap-action-${result.problemId}',
        'type': 'action',
        'label': resolvedTargetGap.trim().isEmpty
            ? '当前没有已确认的行动差距'
            : resolvedTargetGap.trim(),
        'priority': resolvedTargetGap.trim().isEmpty ? 0 : 100,
        'impact': resolvedTargetGap.trim().isEmpty ? 0 : 5,
        'controllability': 5,
        'dependency_weight': 3,
        'information_value': 4,
      },
      <String, Object?>{
        'id': 'gap-risk-${result.problemId}',
        'type': 'risk',
        'label': draft.highRisk
            ? '需要先降低不可逆风险'
            : '当前未发现需要优先处理的不可逆风险',
        'priority': draft.highRisk ? 110 : 0,
        'impact': draft.highRisk ? 5 : 0,
        'controllability': 3,
        'dependency_weight': draft.highRisk ? 5 : 0,
        'information_value': draft.highRisk ? 4 : 0,
      },
    ];
    final weakestPremise = draft.redTeam.isNotEmpty
        ? draft.redTeam.first
        : draft.assumptions.isNotEmpty
            ? draft.assumptions.first
            : draft.unknowns.isNotEmpty
                ? draft.unknowns.first
                : '';
    final reality = result.inputClassification?.type ==
                XiangjiInputType.actionFeedback ||
            realityContradicted
        ? <String, Object?>{
            'summary': utterance,
            'source': 'user_reality_feedback',
          }
        : const <String, Object?>{};
    final pathAsGoal = draft.goal.trim().isNotEmpty &&
        draft.goal.trim() == draft.currentAction.trim();
    final goalNeedsAudit = pathAsGoal ||
        RegExp(r'证明|报复|让.*后悔|必须赢|不能输|坚持到底|已经投入').hasMatch(
          draft.goal,
        );
    if (!realityContradicted) {
      final focusOrder = canAdvanceOperator
          ? <String>[
              if (goalNeedsAudit) 'MEC-010',
              'MEC-011',
              'MEC-012',
              if (!goalNeedsAudit) 'MEC-010',
              'MEC-013',
              'MEC-007',
              'MEC-008',
              'MEC-001',
              'MEC-002',
              'MEC-003',
              'MEC-004',
              'MEC-005',
              'MEC-006',
            ]
          : const <String>[
              'MEC-001',
              'MEC-002',
              'MEC-003',
              'MEC-004',
              'MEC-005',
              'MEC-006',
              'MEC-007',
              'MEC-008',
              'MEC-010',
              'MEC-011',
            ];
      requested.sort((left, right) {
        final leftIndex = focusOrder.indexOf(left);
        final rightIndex = focusOrder.indexOf(right);
        return (leftIndex < 0 ? focusOrder.length : leftIndex).compareTo(
          rightIndex < 0 ? focusOrder.length : rightIndex,
        );
      });
      // Keep the means-ends chain primary, but reserve one contextual slot for
      // an actually triggered Schopenhauer cognitive method. Previously such
      // methods were generated and then hidden behind Goal/Gap/Operator.
      const epistemicMethods = <String>{
        'MEC-001',
        'MEC-002',
        'MEC-003',
        'MEC-004',
        'MEC-005',
        'MEC-006',
        'MEC-007',
        'MEC-008',
        'MEC-009',
      };
      final epistemicIndex = requested.indexWhere(epistemicMethods.contains);
      if (epistemicIndex >= 3) {
        final method = requested.removeAt(epistemicIndex);
        requested.insert(canAdvanceOperator ? 1 : 0, method);
      }
    }

    await _applySignatureMethods(
      problemId: result.problemId,
      context: XiangjiSignatureMethodContext(
        problemId: result.problemId,
        problemState: realityContradicted
            ? XiangjiProblemState.backtracking
            : problem.state,
        rawText: utterance,
        requestedMethodIds: requested,
        sourceRefs: sourceRefs,
        facts: draft.observedFacts,
        experiences: draft.bodyExperiences,
        interpretations: draft.userInterpretations,
        causalCandidates: draft.causalHypotheses,
        counterevidence: draft.counterexamples,
        candidateGaps: gapVector,
        missingPreconditions: missingPreconditions,
        decisiveDifference: draft.relevantDifferences.isEmpty
            ? ''
            : draft.relevantDifferences.first,
        vagueExperience: RegExp(r'说不清|不对劲|怪怪的|难以描述').hasMatch(text)
            ? utterance
            : '',
        abstractLabel: RegExp(r'本质|天生|性格|能力|适合|失败者|拖延|人格')
                .hasMatch(text)
            ? draft.trueProblem
            : '',
        highImpactClaim: draft.judgment,
        weakestPremise: weakestPremise,
        complexModel: draft.operators.isNotEmpty ||
            draft.strategyOptions.isNotEmpty ||
            draft.assumptions.isNotEmpty,
        groundWeak: draft.epistemicStatus == 'EPISTEMIC_DEBT' ||
            draft.unknowns.isNotEmpty,
        realityConflict: realityContradicted,
        goalNeedsAudit: goalNeedsAudit,
        pathAsGoal: pathAsGoal,
        prediction: activePrediction,
        reality: reality,
        realityVerdict: realityContradicted ? 'refutes' : '',
        earliestFailedLayer:
            realityContradicted ? 'operator_or_premise' : '',
        operatorTitle: resolvedOperatorTitle,
        operatorMechanism: resolvedMechanism,
        operatorExpectedEffect: operatorText(
          const <String>['expected_effect', 'prediction'],
          activePrediction,
        ),
        operatorCost: operatorText(
          const <String>['cost'],
          '${draft.expectedMinutes} 分钟',
        ),
        operatorRisk: operatorText(
          const <String>['risk'],
          draft.highRisk ? 'high' : 'low',
        ),
        operatorReversibility: operatorText(
          const <String>['reversibility'],
          draft.irreversible ? 'low' : 'high',
        ),
        operatorInformationValue: operatorText(
          const <String>['information_value'],
          '用现实结果缩小当前关键未知',
        ),
        visibleLimit: 3,
        eventIdPrefix: newId('xf_method_turn'),
      ),
      seed: (snapshot) {
        final activeOperator = canAdvanceOperator || realityContradicted
            ? <String, Object?>{
                ...snapshot.activeOperator,
                ...operator,
                if (resolvedOperatorTitle.isNotEmpty)
                  'title': resolvedOperatorTitle,
                if (resolvedTargetGap.isNotEmpty)
                  'target_gap': resolvedTargetGap,
                if (resolvedMechanism.isNotEmpty)
                  'mechanism': resolvedMechanism,
                'preconditions': missingPreconditions,
                'expected_effect': operatorText(
                  const <String>['expected_effect', 'prediction'],
                  activePrediction,
                ),
                'cost': operatorText(
                  const <String>['cost'],
                  '${draft.expectedMinutes} 分钟',
                ),
                'risk': operatorText(
                  const <String>['risk'],
                  draft.highRisk ? 'high' : 'low',
                ),
                'reversibility': operatorText(
                  const <String>['reversibility'],
                  draft.irreversible ? 'low' : 'high',
                ),
                'information_value': operatorText(
                  const <String>['information_value'],
                  '用现实结果缩小当前关键未知',
                ),
                if (activePrediction.isNotEmpty)
                  'prediction': activePrediction,
              }
            : <String, Object?>{
                'status': result.executionFrozen
                    ? 'frozen_by_runtime_gate'
                    : 'awaiting_clarification',
              };
        return snapshot.copyWith(
          need: draft.need.isEmpty ? snapshot.need : draft.need,
          problemFrame: <String, Object?>{
            ...snapshot.problemFrame,
            if (draft.trueProblem.isNotEmpty) 'statement': draft.trueProblem,
            if (draft.valueLink.isNotEmpty) 'value_link': draft.valueLink,
            'recommendation': draft.recommendation,
            'change_signals': draft.changeSignals,
          },
          currentState: <String, Object?>{
            ...snapshot.currentState,
            'summary': draft.summary,
            'facts': draft.observedFacts,
            'experiences': draft.bodyExperiences,
            'interpretations': draft.userInterpretations,
          },
          goalState: <String, Object?>{
            ...snapshot.goalState,
            'statement': draft.goal,
            'success_criteria': draft.successCriteria,
            'exit_criteria': draft.exitCriteria,
          },
          hypotheses: <Map<String, Object?>>[
            for (final hypothesis in draft.causalHypotheses)
              <String, Object?>{
                'claim': hypothesis,
                'status': 'candidate',
              },
          ],
          constraints: <Map<String, Object?>>[
            for (final constraint in draft.constraints)
              <String, Object?>{
                'label': constraint,
                'status': 'active',
              },
          ],
          candidateOperators:
              draft.operators.isEmpty ? <Map<String, Object?>>[activeOperator] : draft.operators,
          activeOperator: activeOperator,
          epistemicProfile: <String, Object?>{
            'status': draft.epistemicStatus,
            'weakest_premise': weakestPremise,
            'unknowns': draft.unknowns,
          },
          predictionLedger: <String, Object?>{
            ...snapshot.predictionLedger,
            if ((canAdvanceOperator || realityContradicted) &&
                activePrediction.isNotEmpty)
              'prediction': activePrediction,
          },
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
      },
    );
  }

  Future<void> _applySignatureMethods({
    required String problemId,
    required XiangjiSignatureMethodContext context,
    XiangjiSolverSnapshot Function(XiangjiSolverSnapshot snapshot)? seed,
  }) async {
    final problem = await _requireProblem(problemId);
    final current = await _dao.solverSnapshot(problemId) ??
        XiangjiSolverSnapshot(
          problemId: problemId,
          stateVersion: await _dao.problemVersion(problemId),
          need: problem.need.isEmpty ? problem.rawQuestion : problem.need,
          problemFrame: <String, Object?>{
            'statement': problem.reframedQuestion.isEmpty
                ? problem.rawQuestion
                : problem.reframedQuestion,
          },
          goalState: <String, Object?>{
            'statement': problem.goalText,
            'success_criteria': problem.successCriteria,
            'exit_criteria': problem.exitCriteria,
          },
          promptVersion: 'rev5.2',
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
    final prepared = seed == null ? current : seed(current);
    final routed = _signatureRouter.route(state: prepared, context: context);
    if (routed.events.isEmpty) {
      await _dao.saveSolverSnapshot(routed.after);
      return;
    }
    await _dao.saveSolverStateAndMethodEvents(
      snapshot: routed.after,
      events: routed.events,
    );
  }

  Future<XiangjiAgentResult> runAgent(XiangjiAgentRequest request) =>
      _agentService.run(request);

  Future<XiangjiProblemRecord> _requireProblem(String id) async {
    final value = await _dao.problem(id);
    if (value == null) throw StateError('问题不存在或已删除。');
    return value;
  }

  Future<XiangjiCampaignRecord> _requireCampaign(String id) async {
    final value = await _dao.campaign(id);
    if (value == null) throw StateError('战役不存在或已删除。');
    return value;
  }

  Future<XiangjiActionRecord> _requireAction(String id) async {
    final value = await _dao.action(id);
    if (value == null) throw StateError('行动不存在或已删除。');
    return value;
  }

  List<String> _retrievalTerms(String text) {
    final lower = text.toLowerCase();
    const domainTerms = <String>[
      '辞职', '离职', '工作', '职业', '项目', '合同', '签约', '创业', '投资',
      '结婚', '离婚', '买房', '卖房', '搬家', '移民', '手术', '健康', '收入',
      '预算', '截止', '期限', '面试', '简历', '客户', '邮件', '合伙',
    ];
    final values = <String>{
      ...domainTerms.where(lower.contains),
      ...RegExp(r'[a-z0-9][a-z0-9_-]{2,}')
          .allMatches(lower)
          .map((match) => match.group(0)!)
          .where((term) => !<String>{'the', 'and', 'with'}.contains(term)),
    };
    return values.toList();
  }
}
