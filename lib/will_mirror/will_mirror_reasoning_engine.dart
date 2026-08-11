import 'dart:math' as math;

import 'will_mirror_models.dart';

class WillMirrorCandidate {
  const WillMirrorCandidate({
    required this.label,
    required this.matchedNodeIds,
    required this.reasons,
  });

  final String label;
  final List<String> matchedNodeIds;
  final List<String> reasons;
}

class WillMirrorProbeInterpretation {
  const WillMirrorProbeInterpretation({
    required this.summary,
    required this.cautions,
    required this.nextProbe,
  });

  final String summary;
  final List<String> cautions;
  final WillMirrorProbeType? nextProbe;
}

class WillMirrorReasoningEngine {
  static const String kbVersion = '4.0.0-kb.1';
  static const String promptVersion = 'will-mirror-v4-grounded-1';
  static const String localModelVersion = 'wm-local-rules-v1';

  static const String metaphysicalGuardrail =
      '这是基于目前生命证据形成的暂定模型，不是对你本质的证明。这里的“意志”借用叔本华哲学框架，AI 无法直接测量作为物自身的意志。';

  static const String scopeGuardrail =
      '本工具用于结构化自我反思，不是精神疾病诊断、心理治疗，也不替代医疗、法律或财务专业判断。';

  WillMirrorSurfaceAnalysis analyzeSurfaceGoal(WillMirrorGoal goal) {
    final text = goal.text.trim();
    final known = <String>[];
    final unknowns = <String>[];
    var object = text;

    final amount = RegExp(r'(\d+(?:\.\d+)?)\s*(万|万元|元|亿)')
        .firstMatch(text);
    if (amount != null) {
      object = '金钱/资源目标';
      known.add('目标金额：${amount.group(0)}');
      unknowns.addAll(<String>[
        '金钱承担的具体功能',
        '安全与自主各占什么位置',
        '社会可见性是否改变欲望',
      ]);
    } else if (_containsAny(text, <String>['辞职', '工作', '职业', '创业'])) {
      object = '职业/事业目标';
      unknowns.addAll(<String>[
        '想离开什么具体条件',
        '想靠近哪一种工作与生活方式',
        '目标本身和反控制动机如何区分',
      ]);
    } else if (_containsAny(text, <String>['恋爱', '结婚', '上床', '关系', '伴侣'])) {
      object = '亲密/关系目标';
      unknowns.addAll(<String>[
        '亲密、认可、身体需要与归属分别承担什么功能',
        '对方作为具体的人与目标象征如何区分',
        '伦理、同意与现实边界',
      ]);
    } else {
      object = text.isEmpty ? '尚未说明的表象目标' : '当前表象目标';
      unknowns.addAll(<String>[
        '它实现后最重要的具体变化',
        '它是目的、手段，还是两者都有',
        '哪些事实会改变你对它的理解',
      ]);
    }
    if (goal.domain.trim().isNotEmpty) known.add('领域：${goal.domain}');
    known.add('当前欲望强度：${goal.baselineDesire}/100');
    return WillMirrorSurfaceAnalysis(
      object: object,
      known: known,
      unknowns: unknowns,
      nextQuestion: '$text 真正实现以后，最重要、最具体的变化是什么？',
    );
  }

  WillMirrorBoundaryAssessment assessBoundary(
    List<WillMirrorWhyNode> nodes,
  ) {
    if (nodes.isEmpty) {
      return const WillMirrorBoundaryAssessment(
        shouldContinueWhy: true,
        status: 'no_structure',
        reasons: <String>['尚未形成 Why 结构'],
        nextAction: '先记录当前表象目标，再添加第一个“为什么重要”。',
      );
    }

    final byId = <String, WillMirrorWhyNode>{
      for (final node in nodes) node.id: node,
    };
    final reasons = <String>[];
    var loopDetected = false;
    for (final node in nodes) {
      final current = _semanticKey(node.text);
      var parentId = node.parentId;
      while (parentId != null) {
        final parent = byId[parentId];
        if (parent == null) break;
        if (_semanticSimilarity(current, _semanticKey(parent.text)) >= 0.78) {
          loopDetected = true;
          break;
        }
        parentId = parent.parentId;
      }
      if (loopDetected) break;
    }
    if (loopDetected) reasons.add('语义开始循环，继续追问没有产生新结构');

    final children = <String?, List<WillMirrorWhyNode>>{};
    for (final node in nodes) {
      children.putIfAbsent(node.parentId, () => <WillMirrorWhyNode>[]).add(node);
    }
    final branchLeaves = nodes
        .where((node) => (children[node.id] ?? const <WillMirrorWhyNode>[]).isEmpty)
        .toList(growable: false);
    final convergence = <String, Set<String>>{};
    for (final leaf in branchLeaves) {
      final key = _candidateKey(leaf.text);
      if (key.isEmpty) continue;
      convergence.putIfAbsent(key, () => <String>{}).add(leaf.id);
    }
    final converged = convergence.entries.any((entry) => entry.value.length >= 2);
    if (converged) reasons.add('至少两条独立 Why 分支汇聚到同一稳定主题');

    final maxDepth = nodes
        .map((node) => node.depth)
        .fold<int>(0, (current, next) => math.max(current, next).toInt());
    final recent = nodes.where((node) => node.depth >= math.max(1, maxDepth - 1));
    final distinctRecent = recent.map((node) => _semanticKey(node.text)).toSet();
    final lowInformation = maxDepth >= 5 && distinctRecent.length <= 2;
    if (lowInformation) reasons.add('深层节点的信息增益已经明显降低');

    final shouldTransition = loopDetected || converged || lowInformation;
    if (shouldTransition) {
      return WillMirrorBoundaryAssessment(
        shouldContinueWhy: false,
        status: 'candidate_terminal_pattern',
        reasons: reasons,
        nextAction: 'Why → Where Else：到求学、工作、关系、家庭和长期行动中寻找同一主题与真正反例。',
      );
    }

    return WillMirrorBoundaryAssessment(
      shouldContinueWhy: true,
      status: 'useful_why_remains',
      reasons: <String>[
        if (branchLeaves.length <= 1) '当前结构仍可能存在尚未展开的并行原因',
        '下一次 Why 仍可能暴露新的目的、手段、功能或具体动机',
      ],
      nextAction: '继续一层，并主动问：这里是否其实有两个不同原因？',
    );
  }

  List<WillMirrorCandidate> deriveCandidates(
    List<WillMirrorWhyNode> nodes,
  ) {
    const dictionary = <String, List<String>>{
      '自主': <String>['自主', '自由', '自己决定', '选择权', '不被控制', '掌控时间', '拒绝'],
      '安全': <String>['安全', '稳定', '不担心', '保障', '风险', '储备', '基本生活'],
      '认可': <String>['认可', '赞美', '面子', '成功', '证明自己', '看得起', '尊重'],
      '亲密/归属': <String>['亲密', '爱', '陪伴', '连接', '归属', '理解', '关系'],
      '成长/胜任': <String>['成长', '学习', '能力', '胜任', '进步', '掌握', '创造'],
      '意义/贡献': <String>['意义', '帮助', '贡献', '价值', '影响', '有用'],
      '家庭责任': <String>['家人', '家庭', '孩子', '父母', '责任', '照顾'],
      '愉悦/生命力': <String>['快乐', '愉悦', '享受', '活力', '兴奋', '好玩'],
    };
    final result = <WillMirrorCandidate>[];
    for (final entry in dictionary.entries) {
      final matched = nodes.where((node) {
        final text = node.text.toLowerCase();
        return entry.value.any(text.contains);
      }).toList(growable: false);
      if (matched.isEmpty) continue;
      final branches = matched.map((item) => item.parentId ?? item.id).toSet();
      result.add(
        WillMirrorCandidate(
          label: entry.key,
          matchedNodeIds: matched.map((item) => item.id).toList(growable: false),
          reasons: <String>[
            '${matched.length} 个 Why 节点出现相关表达',
            if (branches.length >= 2) '来自至少两条不同分支',
          ],
        ),
      );
    }
    result.sort((a, b) => b.matchedNodeIds.length.compareTo(a.matchedNodeIds.length));
    return result;
  }

  WillMirrorProbeInterpretation interpretProbe(
    WillMirrorProbe probe, {
    List<WillMirrorProbe> allProbes = const <WillMirrorProbe>[],
  }) {
    final magnitude = probe.delta.abs();
    final direction = probe.delta > 0
        ? '上升'
        : probe.delta < 0
            ? '下降'
            : '没有变化';
    var summary = '该条件下欲望从 ${probe.baseline} 变为 ${probe.after}，$direction ${magnitude.abs()} 点。';
    final cautions = <String>[];
    WillMirrorProbeType? nextProbe;

    switch (probe.type) {
      case WillMirrorProbeType.noAudience:
      case WillMirrorProbeType.noPraiseComparison:
        summary += magnitude >= 25
            ? '社会可见性、赞美或比较可能明显参与目标。'
            : '社会变量目前看起来不是唯一解释，但仍不能据此排除认可需要。';
        cautions.add('探针隔离的是一个变量，不是真假判决。');
        break;
      case WillMirrorProbeType.opposition:
        final paired = allProbes.any(
          (item) => item.type == WillMirrorProbeType.oppositionRemoval,
        );
        if (!paired) {
          summary += '被反对后的变化还无法区分目标本身与反抗变量。';
          nextProbe = WillMirrorProbeType.oppositionRemoval;
          cautions.add('必须补做“反对突然消失”，否则不得把坚持解释为更真实。');
        } else {
          summary += '请与“反对突然消失”的结果成对比较。';
        }
        break;
      case WillMirrorProbeType.oppositionRemoval:
        final opposition = allProbes.where(
          (item) => item.type == WillMirrorProbeType.opposition,
        );
        if (opposition.isNotEmpty && probe.after < opposition.first.after - 15) {
          summary += '阻力消失后明显回落，反控制、证明自己或维护自主可能是新增动机。';
        } else {
          summary += '阻力消失后仍较稳定，原目标可能仍有独立驱动力，但需要人生证据。';
        }
        break;
      case WillMirrorProbeType.substitution:
        summary += magnitude >= 25
            ? '替代方案显著削弱欲望，原目标可能较多承担手段功能。'
            : '替代后仍保留较多欲望，目标可能还有尚未解释的独立功能。';
        break;
      case WillMirrorProbeType.satisfactionResidue:
        summary += '回答中的剩余欠缺应作为新的并行分支，而不是被强行归入创伤。';
        break;
      case WillMirrorProbeType.mps:
        summary += '意义、愉悦、优势与最像自己的汇聚只生成候选，仍需行动验证。';
        break;
    }
    return WillMirrorProbeInterpretation(
      summary: summary,
      cautions: cautions,
      nextProbe: nextProbe,
    );
  }

  WillMirrorEvidenceMatrix buildEvidenceMatrix({
    required WillMirrorHypothesis hypothesis,
    required List<WillMirrorLifeEvidence> evidence,
    required List<WillMirrorHypothesisEvidence> links,
    List<WillMirrorProbe> probes = const <WillMirrorProbe>[],
    List<WillMirrorObservation> observations = const <WillMirrorObservation>[],
  }) {
    final byId = <String, WillMirrorLifeEvidence>{
      for (final item in evidence) item.id: item,
    };
    List<WillMirrorLifeEvidence> select(Set<WillMirrorRelation> relations) {
      final ids = links
          .where((link) => relations.contains(link.relation))
          .map((link) => link.evidenceId)
          .toSet();
      return ids.map((id) => byId[id]).whereType<WillMirrorLifeEvidence>().toList();
    }

    final supports = select(<WillMirrorRelation>{
      WillMirrorRelation.supports,
      WillMirrorRelation.operationalizes,
    });
    final counter = select(<WillMirrorRelation>{WillMirrorRelation.contradicts});
    final limits = select(<WillMirrorRelation>{WillMirrorRelation.limits});
    final positive = <WillMirrorLifeEvidence>{...supports};
    final stages = positive.map((item) => item.lifeStage.trim()).where((e) => e.isNotEmpty).toSet();

    var score = 0.0;
    score += 0.25 * (stages.length / 3).clamp(0.0, 1.0).toDouble();
    if (positive.any((item) => item.type == WillMirrorEvidenceType.action)) {
      score += 0.20;
    }
    if (positive.isNotEmpty) {
      final duration = positive
          .map((item) => item.duration)
          .reduce((current, next) => math.max(current, next).toInt());
      score += 0.15 * (duration / 5).clamp(0.0, 1.0).toDouble();
      final cost = positive
          .map((item) => item.costLevel)
          .reduce((current, next) => math.max(current, next).toInt());
      score += 0.15 * (cost / 10).clamp(0.0, 1.0).toDouble();
    }
    score += 0.10 * (probes.length / 2).clamp(0.0, 1.0).toDouble();
    if (positive.any((item) => item.type == WillMirrorEvidenceType.realMe)) {
      score += 0.05;
    }
    score +=
        0.10 * (observations.length / 3).clamp(0.0, 1.0).toDouble();

    final counterPenalty = links
        .where((link) =>
            link.relation == WillMirrorRelation.contradicts ||
            link.relation == WillMirrorRelation.limits)
        .fold<double>(0, (sum, link) => sum + link.weight.abs() * 0.10)
        .clamp(0.0, 0.30)
        .toDouble();
    final finalScore = (score - counterPenalty).clamp(0.0, 1.0).toDouble();

    final blocked = <String>[];
    if (supports.isEmpty) blocked.add('尚无与该候选明确关联的支持性人生证据');
    if (!hypothesis.counterSearchCompleted) blocked.add('尚未完成主动反证检索');
    if (hypothesis.type == WillMirrorHypothesisType.empiricalCharacter &&
        stages.length < 3) {
      blocked.add('经验性格候选至少需要三个不同人生阶段/情境');
    }
    if (hypothesis.type == WillMirrorHypothesisType.empiricalCharacter &&
        !positive.any((item) => item.type == WillMirrorEvidenceType.action)) {
      blocked.add('经验性格候选不能只有口头叙述，仍需实际行动证据');
    }
    if (hypothesis.type == WillMirrorHypothesisType.empiricalCharacter &&
        counter.isEmpty &&
        limits.isEmpty) {
      blocked.add('经验性格候选至少需要一条已连接的反证或情境限制');
    }

    WillMirrorConfidenceBand band;
    if (blocked.isNotEmpty) {
      band = WillMirrorConfidenceBand.insufficient;
    } else if (finalScore < 0.30) {
      band = WillMirrorConfidenceBand.low;
    } else if (finalScore < 0.60) {
      band = WillMirrorConfidenceBand.medium;
    } else if (counter.isNotEmpty || limits.isNotEmpty) {
      band = WillMirrorConfidenceBand.highWithLimits;
    } else {
      band = WillMirrorConfidenceBand.high;
    }

    final conclusion = blocked.isNotEmpty
        ? '“${hypothesis.label}”目前仍是候选：${blocked.join('；')}。'
        : counter.isNotEmpty || limits.isNotEmpty
            ? '现有证据${band == WillMirrorConfidenceBand.highWithLimits ? '较强' : '一定程度'}支持“${hypothesis.label}”在多个情境中重复，但它具有明确条件性，不能被推广成任何情况下都优先。'
            : '现有证据${band == WillMirrorConfidenceBand.high ? '较强' : '一定程度'}支持“${hypothesis.label}”作为稳定意欲候选；当前未发现强反例不等于反例不存在。';

    return WillMirrorEvidenceMatrix(
      supports: supports,
      counterevidence: counter,
      limits: limits,
      band: band,
      internalScore: finalScore,
      blockedReasons: blocked,
      conclusion: '$conclusion $metaphysicalGuardrail',
    );
  }

  WillMirrorGroundedInference localInference({
    required WillMirrorHypothesis hypothesis,
    required WillMirrorEvidenceMatrix matrix,
    required WillMirrorRetrievalBundle retrieval,
  }) {
    final uncertainties = <String>[
      ...matrix.blockedReasons,
      if (matrix.counterevidence.isEmpty)
        '当前没有已记录的强反例，仍需在高风险、责任或结构化情境中继续寻找。',
      if (retrieval.counter.isEmpty)
        '理论 KB 未返回反证/限制条目，不能发布经验性格结论。',
    ];
    final band = retrieval.counter.isEmpty
        ? WillMirrorConfidenceBand.insufficient
        : matrix.band;
    return WillMirrorGroundedInference(
      conclusion: matrix.conclusion,
      supportEvidenceIds:
          matrix.supports.map((item) => item.id).toList(growable: false),
      counterEvidenceIds: <String>[
        ...matrix.counterevidence.map((item) => item.id),
        ...matrix.limits.map((item) => item.id),
      ],
      kbPassageIds:
          retrieval.all.map((item) => item.recordId).toList(growable: false),
      band: band,
      uncertainty: uncertainties,
      nextAction: band == WillMirrorConfidenceBand.insufficient
          ? '补充一条跨人生行动证据，并主动寻找一个真正可能推翻“${hypothesis.label}”的反例。'
          : '设计一个 7 日低风险现实实验，让生活继续检验“${hypothesis.label}”。',
      guardrail: '$metaphysicalGuardrail $scopeGuardrail',
      provider: 'local',
      model: localModelVersion,
    );
  }

  static bool _containsAny(String text, List<String> words) =>
      words.any(text.contains);

  static String _semanticKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u3400-\u9fff]+'), '')
      .replaceAll(RegExp(r'(我想|我要|因为|所以|就是|能够|可以)'), '')
      .trim();

  static double _semanticSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b || a.contains(b) || b.contains(a)) return 1;
    Set<String> bigrams(String value) {
      if (value.length <= 1) return <String>{value};
      return <String>{
        for (var i = 0; i < value.length - 1; i++) value.substring(i, i + 2),
      };
    }
    final aa = bigrams(a);
    final bb = bigrams(b);
    final intersection = aa.intersection(bb).length;
    return (2 * intersection) / (aa.length + bb.length);
  }

  static String _candidateKey(String value) {
    const groups = <String, List<String>>{
      '自主': <String>['自主', '自由', '自己决定', '选择权', '控制'],
      '安全': <String>['安全', '稳定', '保障', '不担心'],
      '认可': <String>['认可', '证明', '赞美', '尊重'],
      '亲密': <String>['亲密', '爱', '归属', '陪伴'],
      '成长': <String>['成长', '能力', '学习', '进步'],
      '意义': <String>['意义', '贡献', '帮助', '价值'],
    };
    for (final entry in groups.entries) {
      if (entry.value.any(value.contains)) return entry.key;
    }
    return _semanticKey(value);
  }
}
