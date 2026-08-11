import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_signature_method_engine.dart';

void main() {
  const router = XiangjiSignatureCapabilityRouter();

  XiangjiSolverSnapshot base({
    Map<String, Object?> keyGap = const <String, Object?>{
      'id': 'gap-old',
      'type': 'action',
      'label': '旧关键差距',
    },
    Map<String, Object?> activeOperator = const <String, Object?>{
      'id': 'operator-old',
      'title': '旧办法',
      'status': 'selected',
    },
    Map<String, Object?> predictionLedger = const <String, Object?>{},
  }) =>
      XiangjiSolverSnapshot(
        problemId: 'problem-mec',
        need: '解决真实问题',
        problemFrame: const <String, Object?>{
          'raw_question': '为什么我总是不去找工作？',
        },
        currentState: const <String, Object?>{
          'summary': '今天仍没有投递',
          'facts': <String>['今天投递数为 0'],
        },
        goalState: const <String, Object?>{
          'statement': '获得与能力匹配的工作机会',
          'success_criteria': <String>['每周完成 5 次有效投递'],
        },
        keyGap: keyGap,
        activeOperator: activeOperator,
        predictionLedger: predictionLedger,
      );

  XiangjiSignatureRouterResult run(
    String methodId, {
    XiangjiSolverSnapshot? state,
    List<String> facts = const <String>[],
    List<String> experiences = const <String>[],
    List<String> interpretations = const <String>[],
    List<String> causes = const <String>[],
    List<String> counterevidence = const <String>[],
    List<Map<String, Object?>> gaps = const <Map<String, Object?>>[],
    List<String> missing = const <String>[],
    String difference = '',
    String vague = '',
    String label = '',
    bool groundWeak = false,
    bool complexModel = false,
    bool realityConflict = false,
    bool goalNeedsAudit = false,
    bool pathAsGoal = false,
    String prediction = '',
    Map<String, Object?> reality = const <String, Object?>{},
    String verdict = '',
    String failedLayer = '',
    bool actionMode = false,
  }) =>
      router.route(
        state: state ?? base(),
        context: XiangjiSignatureMethodContext(
          problemId: 'problem-mec',
          problemState: XiangjiProblemState.solving,
          requestedMethodIds: <String>[methodId],
          facts: facts,
          experiences: experiences,
          interpretations: interpretations,
          causalCandidates: causes,
          counterevidence: counterevidence,
          candidateGaps: gaps,
          missingPreconditions: missing,
          decisiveDifference: difference,
          vagueExperience: vague,
          abstractLabel: label,
          highImpactClaim: '这是一个高影响判断',
          weakestPremise: '招聘方是否会回复尚未知',
          groundWeak: groundWeak,
          complexModel: complexModel,
          realityConflict: realityConflict,
          goalNeedsAudit: goalNeedsAudit,
          pathAsGoal: pathAsGoal,
          prediction: prediction,
          reality: reality,
          realityVerdict: verdict,
          earliestFailedLayer: failedLayer,
          operatorTitle: '发送一份针对性申请',
          operatorMechanism: '增加一次能产生回复的真实接触',
          operatorExpectedEffect: '24 小时内获得送达或回复信号',
          operatorCost: '25 分钟',
          actionMode: actionMode,
          createdAtMs: 1000,
          eventIdPrefix: 'test-turn',
        ),
      );

  void expectClosedLoop(XiangjiSignatureRouterResult result, String methodId) {
    expect(result.events, hasLength(1));
    final event = result.events.single;
    expect(event.methodId, methodId);
    expect(event.trigger, isNotEmpty);
    expect(event.operationSummary, isNotEmpty);
    expect(event.dataMutations, isNotEmpty);
    expect(event.decisionEffect, isNotEmpty);
    expect(event.userVisibleSummary, isNotEmpty);
    expect(event.realityTest, isNotEmpty);
    expect(event.changedState, isTrue);
    expect(result.after.stateVersion, greaterThan(result.before.stateVersion));
  }

  test('T-MEC-01 separates experience and interpretation authority', () {
    final result = run(
      'MEC-001',
      experiences: const <String>['我不想去'],
      interpretations: const <String>['这说明我不适合工作'],
    );
    expectClosedLoop(result, 'MEC-001');
    expect(result.after.currentState['interpretations_may_drive_goal'], isFalse);
    expect(result.after.currentState['experiences'], contains('我不想去'));
  });

  test('T-MEC-02 preserves feeling and demotes external cause', () {
    final result = run(
      'MEC-002',
      experiences: const <String>['我很害怕'],
      interpretations: const <String>['所以外面一定危险'],
    );
    expectClosedLoop(result, 'MEC-002');
    expect(result.after.currentState['external_cause_is_fact'], isFalse);
    expect(result.after.hypotheses.single['status'], 'unresolved');
  });

  test('T-MEC-03 creates distinct causal mechanisms and a test', () {
    final result = run('MEC-003', causes: const <String>['害怕被拒绝']);
    expectClosedLoop(result, 'MEC-003');
    expect(result.after.hypotheses.length, greaterThanOrEqualTo(2));
    expect(
      result.after.hypotheses
          .map((item) => item['mechanism'])
          .toSet()
          .length,
      greaterThanOrEqualTo(2),
    );
    expect(result.after.hypotheses.first['discriminating_observation'], isNotEmpty);
  });

  test('T-MEC-04 decisive difference changes Gap and invalidates reuse', () {
    final result = run(
      'MEC-004',
      difference: '过去没有面试；这次有面试但没有 Offer',
    );
    expectClosedLoop(result, 'MEC-004');
    expect(result.after.keyGap, isNot(equals(result.before.keyGap)));
    expect(result.after.activeOperator['status'],
        'invalidated_by_decisive_difference');
  });

  test('T-MEC-05 keeps a not-yet-named experience without forced label', () {
    final result = run('MEC-005', vague: '说不清，但进办公室前就是不对劲');
    expectClosedLoop(result, 'MEC-005');
    expect(result.after.currentState['forced_label'], isFalse);
    expect(result.after.currentState['unconceptualized_experiences'], isNotEmpty);
  });

  test('T-MEC-06 counterexample shrinks concept scope', () {
    final result = run(
      'MEC-006',
      label: '我就是懒',
      experiences: const <String>['投递前会心慌'],
      counterevidence: const <String>['帮助朋友申请时我会立刻行动'],
    );
    expectClosedLoop(result, 'MEC-006');
    final fidelity = result.after.problemFrame['concept_fidelity'] as Map;
    expect(fidelity['status'], 'scope_reduced');
    expect(fidelity['counterexamples'], isNotEmpty);
  });

  test('T-MEC-07 weak ground lowers action commitment', () {
    final result = run('MEC-007', groundWeak: true);
    expectClosedLoop(result, 'MEC-007');
    expect(result.after.epistemicProfile['epistemic_status'], 'EPISTEMIC_DEBT');
    expect(result.after.activeOperator['commitment'], 'scout_or_reversible_only');
  });

  test('T-MEC-08 systematicity never raises epistemic status', () {
    final result = run(
      'MEC-008',
      complexModel: true,
      groundWeak: true,
    );
    expectClosedLoop(result, 'MEC-008');
    expect(result.after.epistemicProfile['systematicity'], 'high');
    expect(result.after.epistemicProfile['epistemic_status'], 'EPISTEMIC_DEBT');
    expect(result.after.epistemicProfile['truth_bonus_from_complexity'], isFalse);
  });

  test('T-MEC-09 reality mismatch changes downstream state', () {
    final result = run(
      'MEC-009',
      realityConflict: true,
      reality: const <String, Object?>{'facts': <String>['连续两次结果相反']},
    );
    expectClosedLoop(result, 'MEC-009');
    expect(result.after.keyGap['type'], 'concept');
    expect(result.after.activeOperator['status'], 'invalidated_by_reality');
  });

  test('T-MEC-10 path-as-goal creates a user decision gate', () {
    final result = run(
      'MEC-010',
      goalNeedsAudit: true,
      pathAsGoal: true,
    );
    expectClosedLoop(result, 'MEC-010');
    expect(result.after.goalState['user_confirmation_required'], isTrue);
    expect(result.after.problemFrame['solver_gate'], 'await_goal_confirmation');
  });

  test('T-MEC-11 same Goal but different S0 selects different KeyGap', () {
    final first = run(
      'MEC-011',
      gaps: const <Map<String, Object?>>[
        <String, Object?>{'id': 'g1', 'type': 'information', 'label': '不知道岗位要求', 'priority': 100},
      ],
    );
    final second = run(
      'MEC-011',
      gaps: const <Map<String, Object?>>[
        <String, Object?>{'id': 'g2', 'type': 'capability', 'label': '面试表达不足', 'priority': 100},
      ],
    );
    expectClosedLoop(first, 'MEC-011');
    expectClosedLoop(second, 'MEC-011');
    expect(first.after.keyGap['id'], isNot(second.after.keyGap['id']));
  });

  test('T-MEC-12 missing precondition becomes recursive subgoal', () {
    final result = run(
      'MEC-012',
      missing: const <String>['完成简历初稿', '确认一个目标岗位'],
      prediction: '投递后获得送达信号',
    );
    expectClosedLoop(result, 'MEC-012');
    expect(result.after.activeSubgoal['kind'], 'precondition_subgoal');
    expect(result.after.subgoalGraph['logic'], 'AND');
    expect(result.after.activeOperator['preconditions'], hasLength(2));
  });

  test('T-MEC-13 preserves prediction and updates H/Gap on contrary reality', () {
    final state = base(
      predictionLedger: const <String, Object?>{
        'prediction': '投递后 24 小时内会收到回复',
        'locked': true,
      },
    ).copyWith(
      hypotheses: const <Map<String, Object?>>[
        <String, Object?>{'id': 'h1', 'status': 'candidate'},
      ],
    );
    final result = run(
      'MEC-013',
      state: state,
      prediction: '不应覆盖原预测',
      reality: const <String, Object?>{'facts': <String>['48 小时无回复']},
      verdict: 'refutes',
      realityConflict: true,
    );
    expectClosedLoop(result, 'MEC-013');
    expect(result.after.predictionSummary, '投递后 24 小时内会收到回复');
    expect(result.after.hypotheses.single['status'], 'challenged_by_reality');
    expect(result.after.gaps, isNotEmpty);
  });

  test('T-MEC-14 identifies earliest failed layer and reroutes', () {
    final result = run(
      'MEC-014',
      failedLayer: 'Precondition',
      reality: const <String, Object?>{'facts': <String>['行动完成但没有效果']},
    );
    expectClosedLoop(result, 'MEC-014');
    expect(result.after.backtrackHistory.single['earliest_failed_layer'],
        'Precondition');
    expect(result.after.activeOperator['status'], 'invalidated_by_backtrack');
    expect(result.after.activeSubgoal['kind'], 'backtrack_repair');
  });

  test('contextual reveal shows at most 3 and Action Mode shows none', () {
    final methods = XiangjiSignatureCapabilityRouter.capabilityIds;
    final normal = router.route(
      state: base(),
      context: XiangjiSignatureMethodContext(
        problemId: 'problem-mec',
        problemState: XiangjiProblemState.solving,
        requestedMethodIds: methods,
        facts: const <String>['一个事实'],
        interpretations: const <String>['一个解释'],
        prediction: '会有结果',
        createdAtMs: 1000,
      ),
    );
    final actionMode = router.route(
      state: base(),
      context: XiangjiSignatureMethodContext(
        problemId: 'problem-mec',
        problemState: XiangjiProblemState.executing,
        requestedMethodIds: const <String>['MEC-013'],
        prediction: '会有结果',
        actionMode: true,
        createdAtMs: 1000,
      ),
    );

    expect(normal.events, hasLength(14));
    expect(normal.visibleEvents.length, lessThanOrEqualTo(3));
    expect(actionMode.visibleEvents, isEmpty);
  });
}
