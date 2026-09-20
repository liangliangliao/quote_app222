import 'evidence_growth_cycle.dart';
import 'evidence_growth_knowledge_runtime.dart';
import 'evidence_growth_journey_models.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_router.dart';

/// Compiles the active plan, never an obsolete Trial's frozen ACT conditions.
class EvidenceGrowthJourneyRuntime {
  static bool canInherit(GrowthJourney j, RealityTrial? previous) =>
      EvidenceGrowthKnowledgeRuntime.applications(j, 'ACTION').isEmpty &&
      previous != null &&
      previous.isClosed &&
      previous.nextTrialId.isEmpty &&
      const ['ACT', 'ADJUST'].contains(previous.decision) &&
      growthInt(j.data['previous_plan_version']) ==
          growthInt(j.plan['version']) &&
      growthMap(j.data['next_change'])['target'] != 'EXIT';

  static EvidenceRouteResult compile(GrowthJourney j,
      {RealityTrial? previous}) {
    const router = EvidenceGrowthRouter();
    final inherit = canInherit(j, previous);
    final change = growthMap(j.data['next_change']);
    final nextAction = '${change['next_action'] ?? ''}'.trim();
    final planChanged = growthInt(j.data['previous_plan_version']) !=
        growthInt(j.plan['version']);
    final gap = planChanged || nextAction.isEmpty
        ? '${j.plan['strategy'] ?? '通过一轮现实行动验证下一步'}'
        : nextAction;
    var route = inherit
        ? router.nextTrial(previous!)
        : router.route('${j.title}\n当前事实：${j.data['current']}\n当前计划：$gap');
    final chosen =
        planChanged ? '${j.plan['strategy'] ?? ''}'.trim() : nextAction;
    if (chosen.isNotEmpty &&
        chosen != '先完成一轮现实采样，再按结果调整' &&
        route.canAct &&
        !inherit) {
      final check = router.route(chosen);
      if (!EvidenceGrowthRouter.protected(check))
        route = route.copyWith(actionInstruction: chosen);
    }
    final applications =
        EvidenceGrowthKnowledgeRuntime.applications(j, 'ACTION');
    if (applications.isNotEmpty && !EvidenceGrowthRouter.protected(route)) {
      final nodes = EvidenceGrowthKnowledgeRuntime.appliedNodes(j, 'ACTION');
      nodes.sort((a, b) => (a.isTal ? 0 : 1).compareTo(b.isTal ? 0 : 1));
      final instruction = applications.map((a) => a['application']).join('；');
      final guard =
          router.route('${j.title}\n${j.data['current']}\n$instruction');
      if (EvidenceGrowthRouter.protected(guard)) {
        route = guard;
      } else {
        route = router.fromSelection(route.rawInput, route.candidates, nodes,
            ['${j.data['current'] ?? ''}'], '用户核对知识前提后选择的具体练习',
            gap: nodes.any((n) => !n.isTal)
                ? applications.map((a) => a['transfer_reason']).join('；')
                : '');
        if (route.canAct)
          route = route.copyWith(
            actionInstruction: instruction,
            riskChecks: {
              ...route.riskChecks,
              'SELECTION': 'USER_KNOWLEDGE_APPLICATION',
              'CONTENT_ORIGIN': 'USER'
            },
            inputDrafts: {
              ...route.inputDrafts,
              'prediction':
                  applications.map((a) => a['expected_signal']).join('；')
            },
          );
      }
    }
    final constraints = [
      for (final key in ['quality', 'control_boundary', 'stop_condition'])
        if ('${j.contract[key] ?? ''}'.trim().isNotEmpty)
          '$key: ${j.contract[key]}',
      for (final key in [
        'cadence',
        'schedule',
        'resource_limit',
        'stop_rule',
        'selection_rule'
      ])
        if ('${j.plan[key] ?? ''}'.trim().isNotEmpty) '$key: ${j.plan[key]}'
    ];
    return route.copyWith(
      goalState: j.title,
      currentState: '${j.data['current'] ?? ''}',
      topGap: gap,
      requiredChecks: [...route.requiredChecks, ...constraints],
      cyclePlan: {
        ...route.cyclePlan,
        'goal': j.title,
        'current': '${j.data['current'] ?? ''}',
        'gap': gap,
        'belief': '${j.data['belief'] ?? ''}',
        'belief_basis':
            '${growthMap(j.data['belief_details'])['belief_basis'] ?? ''}',
        'belief_update_rule':
            '${growthMap(j.data['belief_details'])['belief_update_rule'] ?? ''}',
        'measurement': '${j.contract['measurement'] ?? ''}',
        'review_gate': '${j.contract['review_gate'] ?? ''}',
        'expected_signal': applications.isNotEmpty
            ? '${applications.last['expected_signal']}'
            : '${j.plan['expected_signal'] ?? ''}',
        'why_action': route.inference,
        'learning_applied': '${j.data['learning'] ?? ''}'
      },
      cycleContext: [
        if (inherit) EvidenceGrowthCycle.context(previous!),
        {
          'journey_context': j.data,
          'active_plan': j.plan,
          'confirmed_next_change': change,
          'plan_constraints': constraints
        }
      ],
    );
  }
}
