import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/will_mirror_models.dart';
import 'package:quote_app/will_mirror/will_mirror_reasoning_engine.dart';

void main() {
  final engine = WillMirrorReasoningEngine();

  test('Deep Why keeps branching while useful structure remains', () {
    final assessment = engine.assessBoundary(<WillMirrorWhyNode>[
      _node('root', null, '我想换工作', 0),
      _node('autonomy', 'root', '我想自己安排时间', 1),
    ]);

    expect(assessment.shouldContinueWhy, isTrue);
    expect(assessment.status, 'useful_why_remains');
  });

  test('semantic loop switches Why into cross-life verification', () {
    final assessment = engine.assessBoundary(<WillMirrorWhyNode>[
      _node('root', null, '我想拥有自主决定权', 0),
      _node('loop', 'root', '因为我想有自主决定权', 1),
    ]);

    expect(assessment.shouldContinueWhy, isFalse);
    expect(assessment.nextAction, contains('Where Else'));
    expect(assessment.reasons.join(), contains('循环'));
  });

  test('opposition probe cannot stand without opposition-removal pair', () {
    final opposition = _probe(
      'opposition',
      WillMirrorProbeType.opposition,
      baseline: 55,
      after: 90,
    );

    final isolated = engine.interpretProbe(opposition);
    expect(isolated.nextProbe, WillMirrorProbeType.oppositionRemoval);
    expect(isolated.cautions.join(), contains('不得'));

    final paired = engine.interpretProbe(
      opposition,
      allProbes: <WillMirrorProbe>[
        opposition,
        _probe(
          'removal',
          WillMirrorProbeType.oppositionRemoval,
          baseline: 55,
          after: 45,
        ),
      ],
    );
    expect(paired.nextProbe, isNull);
    expect(paired.summary, contains('成对比较'));
  });

  test('character claim is blocked until counter-search gate is complete', () {
    final evidence = <WillMirrorLifeEvidence>[
      _evidence(
        'action',
        WillMirrorEvidenceType.action,
        lifeStage: '大学',
      ),
    ];
    final hypothesis = _hypothesis(counterSearchCompleted: false);
    final matrix = engine.buildEvidenceMatrix(
      hypothesis: hypothesis,
      evidence: evidence,
      links: <WillMirrorHypothesisEvidence>[
        _link('action', WillMirrorRelation.supports),
      ],
    );

    expect(matrix.band, WillMirrorConfidenceBand.insufficient);
    expect(matrix.canPublishCharacterClaim, isFalse);
    expect(matrix.blockedReasons.join(), contains('反证检索'));
  });

  test('cross-life action, cost and counterevidence yield bounded confidence', () {
    final evidence = <WillMirrorLifeEvidence>[
      _evidence(
        'action',
        WillMirrorEvidenceType.action,
        lifeStage: '中学',
        duration: 5,
        costLevel: 10,
      ),
      _evidence(
        'real-me',
        WillMirrorEvidenceType.realMe,
        lifeStage: '大学',
        duration: 4,
        costLevel: 5,
      ),
      _evidence(
        'cost',
        WillMirrorEvidenceType.cost,
        lifeStage: '工作后',
        duration: 4,
        costLevel: 8,
      ),
      _evidence(
        'counter',
        WillMirrorEvidenceType.counterexample,
        lifeStage: '家庭',
      ),
      _evidence(
        'limit',
        WillMirrorEvidenceType.counterexample,
        lifeStage: '照护期',
      ),
    ];
    final matrix = engine.buildEvidenceMatrix(
      hypothesis: _hypothesis(counterSearchCompleted: true),
      evidence: evidence,
      links: <WillMirrorHypothesisEvidence>[
        _link('action', WillMirrorRelation.supports),
        _link('real-me', WillMirrorRelation.supports),
        _link('cost', WillMirrorRelation.operationalizes),
        _link('counter', WillMirrorRelation.contradicts, weight: 0.4),
        _link('limit', WillMirrorRelation.limits, weight: 0.3),
      ],
      probes: <WillMirrorProbe>[
        _probe('audience', WillMirrorProbeType.noAudience),
        _probe('substitution', WillMirrorProbeType.substitution),
      ],
      observations: <WillMirrorObservation>[
        _observation('o1'),
        _observation('o2'),
        _observation('o3'),
      ],
    );

    expect(matrix.canPublishCharacterClaim, isTrue);
    expect(matrix.band, WillMirrorConfidenceBand.highWithLimits);
    expect(matrix.counterevidence, hasLength(1));
    expect(matrix.limits, hasLength(1));
    expect(matrix.conclusion, contains('暂定模型'));
    expect(matrix.conclusion, isNot(matches(RegExp(r'\d+%'))));
  });

  test('local inference downgrades when KB has no counter material', () {
    final hypothesis = _hypothesis(counterSearchCompleted: true);
    final matrix = engine.buildEvidenceMatrix(
      hypothesis: hypothesis,
      evidence: <WillMirrorLifeEvidence>[
        _evidence('action', WillMirrorEvidenceType.action, lifeStage: '中学'),
        _evidence('real-me', WillMirrorEvidenceType.realMe, lifeStage: '大学'),
        _evidence('cost', WillMirrorEvidenceType.cost, lifeStage: '工作后'),
      ],
      links: <WillMirrorHypothesisEvidence>[
        _link('action', WillMirrorRelation.supports),
        _link('real-me', WillMirrorRelation.supports),
        _link('cost', WillMirrorRelation.supports),
      ],
    );

    final result = engine.localInference(
      hypothesis: hypothesis,
      matrix: matrix,
      retrieval: const WillMirrorRetrievalBundle(
        support: <WillMirrorKnowledgePassage>[],
        counter: <WillMirrorKnowledgePassage>[],
        boundary: <WillMirrorKnowledgePassage>[],
      ),
    );

    expect(result.band, WillMirrorConfidenceBand.insufficient);
    expect(result.uncertainty.join(), contains('反证'));
  });
}

WillMirrorWhyNode _node(
  String id,
  String? parentId,
  String text,
  int depth,
) {
  return WillMirrorWhyNode(
    id: id,
    goalId: 'goal',
    parentId: parentId,
    nodeType: 'why',
    text: text,
    depth: depth,
    createdAt: depth,
  );
}

WillMirrorProbe _probe(
  String id,
  WillMirrorProbeType type, {
  int baseline = 60,
  int after = 55,
}) {
  return WillMirrorProbe(
    id: id,
    goalId: 'goal',
    nodeId: null,
    type: type,
    baseline: baseline,
    after: after,
    answer: '测试回答',
    createdAt: 1,
  );
}

WillMirrorHypothesis _hypothesis({required bool counterSearchCompleted}) {
  return WillMirrorHypothesis(
    id: 'hypothesis',
    goalId: 'goal',
    label: '自主',
    type: WillMirrorHypothesisType.empiricalCharacter,
    status: 'candidate',
    confidenceBand: WillMirrorConfidenceBand.insufficient,
    explanation: '跨人生候选',
    counterSearchCompleted: counterSearchCompleted,
    counterSearchNote: counterSearchCompleted ? '已主动寻找反例' : '',
    createdAt: 1,
    updatedAt: 1,
  );
}

WillMirrorLifeEvidence _evidence(
  String id,
  WillMirrorEvidenceType type, {
  required String lifeStage,
  int duration = 3,
  int costLevel = 4,
}) {
  return WillMirrorLifeEvidence(
    id: id,
    goalId: 'goal',
    type: type,
    title: '证据 $id',
    note: '具体事件',
    lifeStage: lifeStage,
    domain: '工作',
    intensity: 7,
    duration: duration,
    costLevel: costLevel,
    audiencePresent: false,
    externallyRequested: false,
    rewardPresent: false,
    energyBefore: 4,
    energyAfter: 8,
    repeatWish: 8,
    occurredAt: 1,
    createdAt: 1,
  );
}

WillMirrorHypothesisEvidence _link(
  String evidenceId,
  WillMirrorRelation relation, {
  double weight = 1,
}) {
  return WillMirrorHypothesisEvidence(
    hypothesisId: 'hypothesis',
    evidenceId: evidenceId,
    relation: relation,
    weight: weight,
    contextLimit: relation == WillMirrorRelation.supports ? '' : '仅限低风险情境',
  );
}

WillMirrorObservation _observation(String id) {
  return WillMirrorObservation(
    id: id,
    experimentId: 'experiment',
    energy: 8,
    realMe: 8,
    persistence: 8,
    satisfaction: 8,
    note: '现实反馈',
    observedAt: 1,
  );
}
