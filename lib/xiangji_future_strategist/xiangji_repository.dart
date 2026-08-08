import 'dart:convert';

import '../external_data/todo_dao.dart';
import 'xiangji_agent_service.dart';
import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_state_machine.dart';

class XiangjiRepository {
  XiangjiRepository({
    XiangjiDao? dao,
    TodoDao? todoDao,
    XiangjiAgentService? agentService,
  })  : _dao = dao ?? XiangjiDao(),
        _todoDao = todoDao ?? TodoDao(),
        _agentService = agentService ?? XiangjiAgentService(dao: dao);

  final XiangjiDao _dao;
  final TodoDao _todoDao;
  final XiangjiAgentService _agentService;
  final XiangjiProblemStateMachine _problemMachine =
      const XiangjiProblemStateMachine();
  final XiangjiCampaignStateMachine _campaignMachine =
      const XiangjiCampaignStateMachine();
  final XiangjiMonitorEngine _monitor = const XiangjiMonitorEngine();

  static int _idCounter = 0;

  String newId(String prefix) {
    _idCounter = (_idCounter + 1) % 1000000;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  Future<void> initialize() => _dao.ensureSchema();

  Future<XiangjiDashboardSnapshot> dashboard() async {
    await refreshTodoBindings();
    return _dao.dashboard();
  }

  Future<List<XiangjiProblemRecord>> problems({bool includeArchived = false}) =>
      _dao.problems(includeArchived: includeArchived);

  Future<List<XiangjiCampaignRecord>> campaigns({bool includeClosed = false}) =>
      _dao.campaigns(includeClosed: includeClosed);

  Future<List<XiangjiActionRecord>> currentActions() =>
      _dao.actions(currentOnly: true);

  Future<String> createProblem({
    required String rawQuestion,
    required String rawContext,
    String sensitivity = 'sensitive',
  }) async {
    final question = rawQuestion.trim();
    if (question.isEmpty) throw ArgumentError('请先写下真实问题。');
    final problemId = newId('xf_problem');
    final eventId = newId('xf_event');
    await _dao.createProblem(
      id: problemId,
      rawEventId: eventId,
      rawQuestion: question,
      contextText: rawContext.trim().isEmpty ? question : rawContext.trim(),
      sensitivity: sensitivity,
    );
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
  }) async {
    final problem = await _requireProblem(problemId);
    if (problem.state != XiangjiProblemState.solving) {
      throw StateError('只有在 SOLVING 阶段才能选定当前算子。');
    }
    if (<String>[title, targetGap, mechanism, strategicMeaning, groundingReason, prediction]
        .any((value) => value.trim().isEmpty)) {
      throw ArgumentError('行动、四层为什么和事前预测必须完整。');
    }
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
        'cost': '$expectedMinutes 分钟',
        'reversibility': 'high',
        'information_value': '执行后以现实结果更新当前判断',
      },
    );
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
      title: title.trim(),
      problemId: problemId,
      campaignId: campaignId,
      prediction: prediction.trim(),
      expectedMinutes: expectedMinutes,
      whyChain: <String, Object?>{
        'strategic_meaning': strategicMeaning.trim(),
        'key_gap': targetGap.trim(),
        'operator_mechanism': mechanism.trim(),
        'epistemic_grounding': groundingReason.trim(),
      },
    );
    await _dao.updateProblemState(
      problemId,
      XiangjiProblemState.actionReady,
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
    final alert = await _dao.latestOpenAlert();
    if ((alert?['state'] ?? '').toString() == XiangjiAlertState.red.wire) {
      throw StateError('当前为红色预警，原计划已冻结；请先补证、降风险或完成战略复核。');
    }
    if (action.problemId.isNotEmpty) {
      final problem = await _requireProblem(action.problemId);
      final decision = _problemMachine.evaluate(
        problem.state,
        XiangjiProblemState.executing,
        XiangjiProblemTransitionContext(
          operatorSelected: true,
          predictionPrecommitted: action.prediction.trim().isNotEmpty,
          userConfirmedAction: userConfirmed,
        ),
      );
      decision.requireAllowed();
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
  }

  Future<void> blockAction({
    required String actionId,
    required String blockerType,
  }) =>
      _dao.updateAction(
        actionId,
        <String, Object?>{
          'state': XiangjiActionState.blocked.wire,
          'blocker_type': blockerType,
        },
        eventType: 'blocked',
      );

  Future<void> resumeAction(String actionId) async {
    final action = await _requireAction(actionId);
    if (action.state != XiangjiActionState.blocked) {
      throw StateError('只有受阻行动可以恢复。');
    }
    final alert = await _dao.latestOpenAlert();
    if ((alert?['state'] ?? '').toString() == XiangjiAlertState.red.wire) {
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
  }

  Future<void> completeAction({
    required String actionId,
    required List<String> realityFacts,
    List<String> unexpected = const <String>[],
    List<String> evidenceRefs = const <String>[],
    String userInterpretation = '',
  }) async {
    final action = await _requireAction(actionId);
    if (!<XiangjiActionState>{
      XiangjiActionState.inProgress,
      XiangjiActionState.blocked,
      XiangjiActionState.ready,
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
    if (action.todoRef.isNotEmpty) {
      await _todoDao.updateTaskCompletion(
        taskId: action.todoRef,
        completed: true,
      );
    }
    if (realityFacts.isEmpty) {
      // Action DONE is valid, but the Problem remains EXECUTING until reality
      // is captured. This is an explicit state-machine invariant.
      return;
    }
    await _dao.recordRealityResult(
      id: newId('xf_reality'),
      actionId: actionId,
      facts: realityFacts.map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
      unexpected: unexpected,
      sourceRefs: evidenceRefs,
      userInterpretation: userInterpretation,
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
    }
  }

  Future<void> recordRealityForCompletedAction({
    required String actionId,
    required List<String> realityFacts,
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
    await _dao.recordRealityResult(
      id: newId('xf_reality'),
      actionId: actionId,
      facts: realityFacts,
      unexpected: unexpected,
      sourceRefs: evidenceRefs,
      userInterpretation: userInterpretation,
    );
    if (action.problemId.isEmpty) return;
    final problem = await _requireProblem(action.problemId);
    if (problem.state == XiangjiProblemState.executing) {
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
    }
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
        realityResultPresent: true,
        resolutionCriteriaMet: resolutionCriteriaMet,
      ),
    );
    decision.requireAllowed();
    await _dao.updateProblemState(action.problemId, next);
    if (verdict == 'refutes' && aiModelRunId.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _dao.saveAiError(<String, Object?>{
        'id': newId('xf_ai_error'),
        'model_run_id': aiModelRunId,
        'wrong_claim_id': wrongClaimId,
        'discovered_by': 'reality_result:${reality['id']}',
        'impact': '行动现实反驳了 AI 参与形成的预测/判断',
        'correction': correction,
        'corrected_at_ms': now,
      });
    }
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
    required String reversibility,
    required List<String> assumptions,
    required List<String> stopConditions,
    String evidenceLevel = 'hypothesis',
  }) =>
      _dao.addStrategyOption(<String, Object?>{
        'id': newId('xf_strategy'),
        'campaign_id': campaignId,
        'name': name,
        'strategy_type': type,
        'benefits_json': jsonEncode(benefits),
        'costs_json': jsonEncode(costs),
        'reversibility': reversibility,
        'key_assumptions_json': jsonEncode(assumptions),
        'stop_conditions_json': jsonEncode(stopConditions),
        'evidence_level': evidenceLevel,
        'selected': 0,
        'version_no': 1,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> transitionCampaign({
    required String campaignId,
    required XiangjiCampaignState target,
    bool userConfirmed = false,
    bool reviewRecorded = false,
  }) async {
    final campaign = await _requireCampaign(campaignId);
    if (target == XiangjiCampaignState.executing) {
      final alert = await _dao.latestOpenAlert();
      if ((alert?['state'] ?? '').toString() == XiangjiAlertState.red.wire) {
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
    final taskId = await _todoDao.createLocalTask(
      listId: listId,
      title: action.title,
      bodyText: '来自向己·未来军师\n为什么：${jsonEncode(action.whyChain)}\n事前预测：${action.prediction}',
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
        await _dao.updateAction(
          actionId,
          <String, Object?>{
            'state': XiangjiActionState.done.wire,
            'completed_at_ms': DateTime.now().millisecondsSinceEpoch,
          },
          eventType: 'todo_completed',
        );
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
}
