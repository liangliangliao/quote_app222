import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_agent_service.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_state_machine.dart';

void main() {
  test('Rev5.2 restores the complete A00-A19 agent registry', () {
    expect(XiangjiAgentId.values, hasLength(20));
    expect(
      XiangjiAgentId.values.map((agent) => agent.code).toList(),
      <String>[
        for (var index = 0; index < 20; index++)
          'A${index.toString().padLeft(2, '0')}',
      ],
    );
  });

  group('TC-EP: epistemic invariants', () {
    test('TC-EP-014/015 complexity never raises certainty', () {
      const engine = XiangjiEpistemicEngine();
      final profile = engine.assess(const XiangjiEpistemicAssessmentInput(
        basisType: XiangjiBasisType.aiInference,
        systematicity: 'highly_systematic',
        isHighImpact: true,
      ));

      expect(profile.systematicity, 'highly_systematic');
      expect(profile.summaryStatus, XiangjiSummaryStatus.highDebt);
      expect(engine.claimStateFor(profile), XiangjiClaimState.epistemicDebt);
    });

    test('TC-EP-016 valid inference cannot rescue ungrounded premise', () {
      const machine = XiangjiClaimStateMachine();
      final decision = machine.evaluate(
        XiangjiClaimState.draft,
        XiangjiClaimState.grounded,
        const XiangjiClaimTransitionContext(
          isHighImpact: true,
          criticalPremisesComplete: false,
          validGroundingCount: 0,
        ),
      );

      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('关键前提'));
    });

    test('TC-EP-017 direct perception keeps observation conditions', () {
      const engine = XiangjiK0RuleEngine();
      final result = engine.preflight(const XiangjiRuleRequest(
        requestId: 'ep17',
        directPerceptionMissingConditions: true,
      ));

      expect(result.ruleIds, contains('K0-RULE-017'));
      expect(result.hits.single.action, contains('观察条件'));
    });

    test('TC-KB-025 semantic recall cannot become evidence', () {
      const engine = XiangjiK0RuleEngine();
      final result = engine.preflight(const XiangjiRuleRequest(
        requestId: 'kb25',
        semanticSimilarityUsedAsGrounding: true,
      ));

      expect(result.ruleIds, contains('K0-RULE-025'));
      expect(result.hits.single.blocking, isTrue);
    });
  });

  group('TC-PS: problem state machine', () {
    test('CAPTURED cannot jump to EXECUTING', () {
      const machine = XiangjiProblemStateMachine();
      final decision = machine.evaluate(
        XiangjiProblemState.captured,
        XiangjiProblemState.executing,
        const XiangjiProblemTransitionContext(
          operatorSelected: true,
          predictionPrecommitted: true,
          userConfirmedAction: true,
        ),
      );

      expect(decision.allowed, isFalse);
    });

    test('PS-010 reality result is required before verifying', () {
      const machine = XiangjiProblemStateMachine();
      final decision = machine.evaluate(
        XiangjiProblemState.executing,
        XiangjiProblemState.verifying,
        const XiangjiProblemTransitionContext(),
      );

      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('现实结果'));
    });

    test('RESOLVED needs reality and success criteria', () {
      const machine = XiangjiProblemStateMachine();
      expect(
        machine
            .evaluate(
              XiangjiProblemState.verifying,
              XiangjiProblemState.resolved,
              const XiangjiProblemTransitionContext(
                realityResultPresent: true,
                resolutionCriteriaMet: false,
              ),
            )
            .allowed,
        isFalse,
      );
      expect(
        machine
            .evaluate(
              XiangjiProblemState.verifying,
              XiangjiProblemState.resolved,
              const XiangjiProblemTransitionContext(
                realityResultPresent: true,
                resolutionCriteriaMet: true,
              ),
            )
            .allowed,
        isTrue,
      );
    });
  });

  group('TC-ST: campaign gates', () {
    test('formal execution requires all six gates', () {
      const machine = XiangjiCampaignStateMachine();
      final blocked = machine.evaluate(
        XiangjiCampaignState.prepare,
        XiangjiCampaignState.executing,
        const XiangjiCampaignTransitionContext(
          worthinessReviewed: true,
          victoryAndExitCriteriaDefined: true,
          resourceBudgetDefined: true,
          criticalUnknownsHandled: true,
          redTeamComplete: false,
          userConfirmed: true,
        ),
      );
      final allowed = machine.evaluate(
        XiangjiCampaignState.prepare,
        XiangjiCampaignState.executing,
        const XiangjiCampaignTransitionContext(
          worthinessReviewed: true,
          victoryAndExitCriteriaDefined: true,
          resourceBudgetDefined: true,
          criticalUnknownsHandled: true,
          redTeamComplete: true,
          userConfirmed: true,
        ),
      );

      expect(blocked.allowed, isFalse);
      expect(allowed.allowed, isTrue);
    });

    test('closing a campaign requires battle review', () {
      const machine = XiangjiCampaignStateMachine();
      expect(
        machine
            .evaluate(
              XiangjiCampaignState.won,
              XiangjiCampaignState.closed,
              const XiangjiCampaignTransitionContext(),
            )
            .allowed,
        isFalse,
      );
    });
  });

  group('TC-KB: provider and candidate lifecycle', () {
    const unverified = XiangjiProviderCapability(
      providerId: 'test',
      label: 'Test',
      supportsPersistentFile: true,
      supportsStore: true,
      supportsDelete: true,
      supportsReuse: true,
      supportsCitations: true,
      supportsStructuredOutput: true,
      retentionPolicy: 'unknown',
      indexingMode: 'remote',
    );

    test('TC-KB-010 cannot claim READY without verified persistence', () {
      const machine = XiangjiProviderFileStateMachine();
      final decision = machine.evaluate(
        XiangjiProviderFileState.uploading,
        XiangjiProviderFileState.ready,
        capability: unverified,
        remoteFileId: 'file_1',
      );

      expect(decision.allowed, isFalse);
    });

    test('TC-KB-015 provider deletion requires remote confirmation', () {
      const machine = XiangjiProviderFileStateMachine();
      final verified = XiangjiProviderCapability(
        providerId: 'test',
        label: 'Test',
        supportsPersistentFile: true,
        supportsStore: true,
        supportsDelete: true,
        supportsReuse: true,
        supportsCitations: true,
        supportsStructuredOutput: true,
        retentionPolicy: 'persistent',
        indexingMode: 'remote',
        verified: true,
      );

      expect(
        machine
            .evaluate(
              XiangjiProviderFileState.deleting,
              XiangjiProviderFileState.deleted,
              capability: verified,
            )
            .allowed,
        isFalse,
      );
    });

    test('TC-KB-018 one AI inference cannot become a stable rule', () {
      const machine = XiangjiKnowledgeItemStateMachine();
      final decision = machine.evaluate(
        XiangjiKnowledgeItemState.candidate,
        XiangjiKnowledgeItemState.stable,
        distinctEventCount: 0,
        userExplicitlyConfirmed: false,
        hasScope: true,
        counterexamplesPreserved: true,
      );

      expect(decision.allowed, isFalse);
    });
  });

  group('TC-LG/AC: grounding and monitoring', () {
    test('concept cycle is detected separately from reality spring', () {
      const graph = XiangjiGroundingGraph();
      final audit = graph.audit(
        rootId: 'claim-a',
        nodes: const <XiangjiGroundingNode>[
          XiangjiGroundingNode(id: 'claim-a', type: 'claim'),
          XiangjiGroundingNode(id: 'concept-b', type: 'concept'),
        ],
        edges: const <XiangjiGroundingEdge>[
          XiangjiGroundingEdge(from: 'claim-a', to: 'concept-b'),
          XiangjiGroundingEdge(from: 'concept-b', to: 'claim-a'),
        ],
      );

      expect(audit.hasConceptCycle, isTrue);
      expect(audit.hasGrounding, isFalse);
    });

    test('AC-006 high-risk irreversible debt creates RED freeze', () {
      const engine = XiangjiMonitorEngine();
      final result = engine.evaluate(const XiangjiMonitorInput(
        highRiskIrreversible: true,
        highEpistemicDebt: true,
      ));

      expect(result.state, XiangjiAlertState.red);
      expect(result.defaultAction, contains('冻结'));
    });
  });
}
