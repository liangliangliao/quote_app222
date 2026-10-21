import 'self_os_codec.dart';
import 'self_os_v37_models.dart';

class OsRepresentationGap {
  const OsRepresentationGap(this.routeId, this.kind, this.reason);
  final String routeId, kind, reason;
  String get key => '$routeId:$kind';
}

class OsGate {
  const OsGate(this.action, this.reasons, {this.mayCommit = false});
  final String action;
  final List<String> reasons;
  final bool mayCommit;
  String get label => const {
        'PASS': '关键认识已足够',
        'ASK': '先补一个关键问题',
        'RETRIEVE': '先获取有来源的信息',
        'VERIFY': '先核验冲突或过期资料',
        'EXPERIMENT': '先做可逆的小实验',
        'HOLD': '暂缓不可逆承诺',
      }[action]!;
}

class OsCausalPath {
  const OsCausalPath(this.nodes, this.edges, this.certainty, this.explanation,
      this.stopReason);
  final List<OsConsequence> nodes;
  final List<OsCausalEdge> edges;
  final String certainty, explanation, stopReason;
}

/// V3.7 routing is based on the represented decision structure, never on life-
/// domain keywords. Labels/scores are transparent product rules, not diagnoses.
class SelfOsV37Rules {
  static List<OsRepresentationGap> representationGaps(SelfOsV37 s) {
    final result = <OsRepresentationGap>[];
    final routes = s.consideredRoutes;
    if (routes.length < 2 && !s.flag('expansionSkipped')) {
      result.add(const OsRepresentationGap(
          '', 'option', '目前只看到一种实现机制。补一个不同路径，或说明这次为何不需要扩面。'));
    }
    for (final route in routes) {
      final nodes =
          s.nodes.where((n) => n.routeId == route.id && n.relevant).toList();
      void add(String kind, String reason) {
        if (!s.dimensionWaived(route.id, kind))
          result.add(OsRepresentationGap(route.id, kind, reason));
      }

      final valences = nodes.map((n) => n.text('valence')).toSet();
      if (!valences.contains('mixed') &&
          !(valences.contains('benefit') && valences.contains('cost'))) {
        add('valence', '用同样深度检查这条路径的收益和代价，缺少证据的部分保持未知。');
      }
      final horizons = nodes.map((n) => n.horizon).toSet();
      if (!horizons.contains('now') ||
          !horizons.contains('near') ||
          (s.needsLongHorizon && !horizons.contains('long'))) {
        add('temporal',
            '尚未覆盖决定相关的现在、近期${s.needsLongHorizon ? '和长期 / 重复后' : ''}。');
      }
      if (nodes.isEmpty ||
          (s.needsLongHorizon && !nodes.any((n) => n.order >= 2))) {
        add('causal', '还没有追踪到会改变后续能力、资源、关系或选择空间的中间状态。');
      }
      if (nodes.isEmpty ||
          nodes.any((n) => n.text('concrete').trim().isEmpty)) {
        add('abstraction', '把重要后果写成能观察的现实变化；没有数字依据时不编造数值。');
      }
      if (s.flag('repeated') &&
          !nodes.any(
              (n) => n.flag('cumulative') && n.text('threshold').isNotEmpty)) {
        add('cumulative', '这是重复行为：需要说明累积条件、阈值或为何不适用，不能把一次行动夸大。');
      }
      final ids = nodes.map((n) => n.id).toSet();
      final edges =
          s.edges.where((e) => ids.contains(e.from) && ids.contains(e.to));
      if (edges.any((e) =>
              e.text('condition').trim().isEmpty ||
              e.text('basis').trim().isEmpty) ||
          nodes.any((n) =>
              n.order > 1 && !edges.any((e) => e.to == n.id && !e.isLoop))) {
        add('conditional', '后果之间缺少条件或因果依据；“可能”不能自动变成“必然”。');
      }
    }
    result.sort((a, b) => a.key.compareTo(b.key));
    return result;
  }

  static Map<String, Set<String>> coverage(SelfOsV37 s) => {
        for (final route in s.consideredRoutes)
          route.id: {
            for (final node in s.nodes
                .where((n) => n.routeId == route.id && n.relevant)) ...[
              node.horizon,
              if (node.text('valence') == 'mixed') ...['benefit', 'cost'] else
                node.text('valence'),
              node.order > 1 ? 'indirect' : 'direct',
              node.flag('cumulative') ? 'repeated' : 'single',
            ]
          }
      };

  static List<String> symmetryWarnings(SelfOsV37 s) {
    final covered = coverage(s);
    final union = covered.values.expand((v) => v).toSet()..remove('');
    Set<String> missing(OsRoute route) => union
        .difference(covered[route.id]!)
        .where((v) => !s.dimensionWaived(
            route.id,
            switch (v) {
              'benefit' || 'cost' => 'valence',
              'now' || 'near' || 'long' => 'temporal',
              'direct' || 'indirect' => 'causal',
              _ => 'cumulative',
            }))
        .toSet();
    return [
      for (final route in s.consideredRoutes)
        if (missing(route).isNotEmpty)
          '「${route.title}」还没有按同样的问题深度检查：${missing(route).map((v) => {
                ...osHorizons,
                ...osValences,
                'direct': '直接后果',
                'indirect': '间接后果',
                'single': '单次',
                'repeated': '累积'
              }[v] ?? v).join('、')}。允许有依据地标记不适用。'
    ];
  }

  static OsGate gate(SelfOsV37 s, {DateTime? at}) {
    final now = at ?? DateTime.now();
    if (s.flag('requiresReconsideration')) {
      return const OsGate('ASK', ['现实条件有新变化，先回应新信息并更新认识，再确认原来的约定。']);
    }
    if (!['low', 'medium', 'high'].contains(s.text('risk'))) {
      return const OsGate('ASK', ['先确认本次成本、可逆性和机会成本，再决定检查深度。']);
    }
    if (s.text('riskSuggestion') == 'high' &&
        !s.flag('riskSuggestionReviewed')) {
      return const OsGate('ASK', ['分析发现可能涉及重大风险，请重新确认真实成本和可逆性。']);
    }
    final open = s.gaps
        .where((g) => g.important && !g.resolvedBy(s.evidence, now))
        .toList();
    final conflicted =
        s.evidence.where((e) => e.text('contradiction') == 'conflict').toList();
    if (open.any((g) => g.flag('unavailable')) && s.highStakes) {
      return const OsGate('HOLD', ['关键未知可能改变选择，且目前无法降低；先暂停不可逆部分。']);
    }
    if (conflicted.isNotEmpty)
      return OsGate(
          'VERIFY', conflicted.map((e) => '来源冲突：${e.claim}').toList());
    final challenged =
        s.nodes.where((n) => n.relevant && n.flag('calibrationNeedsReview'));
    if (challenged.isNotEmpty) {
      return OsGate(
          'VERIFY', ['实际反馈没有支持原来的推断，先修订「${challenged.first.title}」及相关后续路径。']);
    }
    if (s.cognitionOpen)
      return const OsGate(
          'ASK', ['本次认识更新尚未完成：保存 K2，说明它改变了哪些动机；若没有影响，明确记录并停止重复准备。']);
    if (open.isNotEmpty) {
      open.sort((a, b) => (a.sensitivity == 'flip' ? 0 : 1)
          .compareTo(b.sensitivity == 'flip' ? 0 : 1));
      final g = open.first;
      if (g.strings('evidenceIds').any(
          (id) => s.evidence.any((e) => e.id == id && !e.reliableAt(now)))) {
        return OsGate(
            'VERIFY', ['「${g.text('question')}」引用的材料未核实、已过期或不是可验证证据。']);
      }
      if (s.text('risk') == 'low' &&
          s.flag('reversible') &&
          s.text('experimentPlan').trim().isNotEmpty) {
        return OsGate(
            'EXPERIMENT', ['保留未知：${g.text('question')}。仅批准已写明边界的可逆实验。'],
            mayCommit: true);
      }
      return OsGate(
          switch (g.text('access')) {
            'public' => 'RETRIEVE',
            'experience' => 'EXPERIMENT',
            _ => 'ASK'
          },
          [
            '${g.sensitivity == 'flip' ? '不同答案会翻转选择：' : '待确认：'}${g.text('question')}'
          ]);
    }
    if (s.highStakes) {
      final structure = representationGaps(s);
      if (structure.isNotEmpty)
        return OsGate('ASK', structure.take(3).map((g) => g.reason).toList());
      final asymmetric = symmetryWarnings(s);
      if (asymmetric.isNotEmpty)
        return OsGate('ASK', asymmetric.take(3).toList());
      if (!s.evidence.any((e) => e.reliableAt(now))) {
        return const OsGate('VERIFY', ['重大承诺需要至少一条可追溯、未过期且无冲突的已核实依据。']);
      }
      if (!s.flag('criticalUnknownsReviewed'))
        return const OsGate('ASK', ['请确认已检查可能翻转选择的关键未知，明确仍保留哪些未知。']);
    }
    if (s.highStakes &&
        ['external', 'impulse', 'values'].contains(jamesMode(s)) &&
        !s.flag('cooledAndReviewed')) {
      return const OsGate('HOLD', ['本次决定带有偶然、爆发或短时价值变化特征。完成冷却与证据复核后再作不可逆承诺。']);
    }
    if (!s.flag('understandingReviewed') ||
        s.text('understandingSummary').trim().isEmpty ||
        s.text('remainingUnknowns').trim().isEmpty) {
      return const OsGate('ASK', ['还没有确认这次决定的具体理解与未知。没有填写缺口，不代表已经检查充分。']);
    }
    return const OsGate('PASS', ['本次决定的理解与关键未知已确认。按记录的范围行动，并保留后续复审条件。'],
        mayCommit: true);
  }

  static String stopAdvice(SelfOsV37 s) {
    final g = gate(s);
    if (!g.mayCommit) return '${g.label}：${g.reasons.first}';
    if ((s.number('deliberationCycles') ?? 0) >= 3 &&
        s.text('informationGain') == 'none') {
      return '同一批证据已反复比较，没有新增认识。选择一条适用的个人原则、一个低成本实验，或明确复审时间。';
    }
    if (s.gaps.isNotEmpty && s.gaps.every((g) => !g.important)) {
      return '关键未知在已记录的合理情景下不改变选择。可以停止搜索，进入实验或行动。';
    }
    return '只补会改变决定的信息；新的材料不自动等于更好的决定。';
  }

  static String conflict(SelfOsV37 s, List<Map<String, dynamic>> motives) {
    final byOption = <String, Set<String>>{};
    for (final m in motives) {
      if (m['selected'] != true || (osNumber(m['importance']) ?? 0) < 60)
        continue;
      final option = osText(m['optionId']);
      if (option.isEmpty) continue;
      byOption
          .putIfAbsent(option, () => {})
          .add(m['side'] == 'against' ? 'against' : 'for');
    }
    final mixed = byOption.values.where((v) => v.length == 2).length;
    if (s.flag('mutuallyExclusive') && mixed >= 2) return 'double';
    if (mixed >= 1) return 'approachAvoidance';
    if (s.flag('mutuallyExclusive') &&
        byOption.values.where((v) => v.contains('for')).length >= 2)
      return 'approach';
    if (s.flag('mutuallyExclusive') &&
        byOption.values.where((v) => v.contains('against')).length >= 2)
      return 'avoidance';
    return 'unknown';
  }

  static const conflictLabels = {
    'double': '双重趋避',
    'approachAvoidance': '趋近—回避',
    'approach': '趋近—趋近',
    'avoidance': '回避—回避',
    'unknown': '尚不足以分类',
  };
  static const conflictAdvice = {
    'double': '两边都有真实收益和代价；同深度比较，承认舍弃的价值。',
    'approachAvoidance': '同一目标同时吸引和排斥你。出现抗拒，不代表欲求是假的。',
    'approach': '两个未来都值得。比较适配与机会成本，必要时做小实验。',
    'avoidance': '先承认每条路都有损失，再寻找第三路径和最小可接受代价。',
    'unknown': '先关联选项、正反方向和重要度；分类只描述这次冲突。',
  };

  static String jamesMode(SelfOsV37 s) {
    if (!['near', 'decided', 'reviewed'].contains(s.text('decisionStage')) ||
        s.text('decisionEvidence').trim().isEmpty) return 'unknown';
    return osJamesModes.containsKey(s.text('jamesMode'))
        ? s.text('jamesMode')
        : 'unknown';
  }

  static List<Map<String, dynamic>> attentionBreaks(
          List<Map<String, dynamic>> motives) =>
      motives
          .where((m) =>
              m['selected'] == true &&
              ['valued', 'available', 'linked'].contains(m['endorsement']) &&
              ((osNumber(m['occupancy']) ?? 0) < 35 ||
                  osText(m['actionLink']).trim().isEmpty))
          .toList();

  static List<Map<String, dynamic>> motiveDelta(
      Map<String, dynamic> before, Map<String, dynamic> after) {
    final old = {for (final m in osMaps(before['motives'])) osText(m['id']): m};
    final next = {for (final m in osMaps(after['motives'])) osText(m['id']): m};
    final result = <Map<String, dynamic>>[];
    for (final id in {...old.keys, ...next.keys}) {
      final a = old[id], b = next[id];
      if (a == null && b != null) {
        result.add({'id': id, 'title': b['title'], 'change': 'added'});
        continue;
      }
      if (b == null && a != null) {
        result.add({'id': id, 'title': a['title'], 'change': 'invalidated'});
        continue;
      }
      final gains = <double>[];
      for (final key in [
        'importance',
        'credibility',
        'vividness',
        'occupancy'
      ]) {
        final x = osNumber(a?[key]), y = osNumber(b?[key]);
        if (x != null && y != null && x != y) gains.add(y - x);
      }
      if (gains.isNotEmpty ||
          a?['attention'] != b?['attention'] ||
          a?['actionLink'] != b?['actionLink']) {
        final total = gains.fold<double>(0, (a, b) => a + b);
        result.add({
          'id': id,
          'title': b?['title'],
          'change': total < 0
              ? 'weakened'
              : total > 0
                  ? 'strengthened'
                  : 'availability',
          'before': a,
          'after': b
        });
      }
    }
    return result;
  }

  static Map<String, dynamic> interventionGain(
      Map<String, dynamic> before, Map<String, dynamic> after) {
    final knowledge = osText(before['knowledge']) != osText(after['knowledge']);
    final delta = motiveDelta(before, after);
    final probability = before['probability'] != after['probability'];
    return {
      'knowledgeChanged': knowledge,
      'motiveChanges': delta,
      'predictionChanged': probability,
      'decisionConditionsChanged': knowledge || delta.isNotEmpty || probability
    };
  }

  static List<OsCausalPath> causalPaths(SelfOsV37 s,
      {String? routeId, int limit = 7, int maxDepth = 8, DateTime? at}) {
    if (routeId == null && s.routes.length > 1) {
      // Share the display budget across options before adding a second branch
      // of any one route. Insertion order must not hide competing futures.
      final routes = [...s.routes]..sort((a, b) => a.id.compareTo(b.id));
      final groups = [
        for (final r in routes)
          causalPaths(s,
              routeId: r.id, limit: limit, maxDepth: maxDepth, at: at)
      ];
      final balanced = <OsCausalPath>[];
      for (var index = 0; index < limit && balanced.length < limit; index++) {
        for (final group in groups) {
          if (index < group.length && balanced.length < limit)
            balanced.add(group[index]);
        }
      }
      return balanced;
    }
    final now = at ?? DateTime.now();
    final relevant = {
      for (final n in s.nodes.where(
          (n) => n.relevant && (routeId == null || n.routeId == routeId)))
        n.id: n
    };
    final nonLoops = s.edges
        .where((e) =>
            !e.isLoop &&
            relevant.containsKey(e.from) &&
            relevant.containsKey(e.to))
        .toList();
    final destinations = nonLoops.map((e) => e.to).toSet();
    final roots = relevant.values
        .where((n) => !destinations.contains(n.id))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final result = <OsCausalPath>[];
    int rank(String label, List<String> ids) {
      final proof = s.evidence.where((e) => ids.contains(e.id)).toList();
      if (proof
          .any((e) => e.text('contradiction') == 'conflict' || !e.freshAt(now)))
        return 0;
      if (label == 'unknown' ||
          (['fact', 'personal', 'external'].contains(label) &&
              !proof.any((e) => e.reliableAt(now)))) return 0;
      if (label == 'simulation') return 1;
      if (label == 'inference')
        return proof.any((e) => e.reliableAt(now)) ? 2 : 1;
      return 3;
    }

    void visit(OsConsequence node, List<OsConsequence> chain,
        List<OsCausalEdge> links, int certainty) {
      if (result.length >= limit) return;
      final path = [...chain, node];
      var weakest = rank(node.label, node.evidenceIds);
      if (weakest > certainty) weakest = certainty;
      if (links.isNotEmpty) {
        final e = links.last;
        final edgeRank = e.text('condition').isEmpty || e.text('basis').isEmpty
            ? 0
            : rank(e.text('label'), e.evidenceIds);
        if (edgeRank < weakest) weakest = edgeRank;
      }
      if (path.length > 1 && weakest > 2) weakest = 2;
      if (path.length >= 5 && weakest > 1) weakest = 1;
      final next = nonLoops.where((e) => e.from == node.id).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      String stop = '';
      if (weakest == 0) stop = '这里开始不确定：关键依据缺失、冲突或失效，停止继续推断。';
      if (node.flag('calibrationNeedsReview')) {
        weakest = 0;
        stop = '实际反馈与预期不符。先修订这个节点，暂不沿旧判断推演后续路径。';
      }
      if (path.length >= maxDepth) stop = '已到本次展开边界；只有新增决定相关证据时才继续。';
      if (node.flag('prune'))
        stop = node.text('pruneReason').isEmpty
            ? '继续延伸不会改变本次选择。'
            : node.text('pruneReason');
      if (stop.isNotEmpty || next.isEmpty) {
        result.add(OsCausalPath(
            path,
            links,
            ['unknown', 'scenario', 'supported', 'direct'][weakest],
            '按最弱关键依据、未知暴露与路径深度判断；不机械相乘概率。${path.length >= 5 ? '远期包含多次条件传递。' : ''}',
            stop));
        return;
      }
      for (final edge in next.take(4)) {
        if (path.any((n) => n.id == edge.to)) {
          result.add(OsCausalPath(
              path, links, 'unknown', '检测到重复节点。', '请把反馈标记为闭环，而非无限复制节点。'));
        } else {
          visit(relevant[edge.to]!, path, [...links, edge], weakest);
        }
      }
    }

    for (final root in roots) {
      visit(root, [], [], 3);
    }
    return result.take(limit).toList();
  }

  static List<String> expansionStop(SelfOsV37 s) {
    final kinds = s.routes.map((r) => r.mechanism).toSet();
    final duplicates =
        s.routes.length - s.routes.map((r) => r.structuralKey).toSet().length;
    return [
      if (duplicates > 0) '$duplicates 个候选机制重复，先合并而非继续堆数量。',
      if (kinds.length >= 4) '已有 ${kinds.length} 类机制，可以转入个体性筛选。',
      if (s.flag('constraintsCovered')) '关键现实约束已覆盖，可以停止扩面。',
      if (s.text('informationGain') == 'none') '新增候选没有带来新信息，转入比较或实验。',
    ];
  }

  static String natureAdvice(SelfOsV37 s) => switch (s.text('changeObject')) {
        'nature' => '接受已验证倾向，利用力量并设计环境；具体表现仍可以训练。',
        'skill' => '把目标拆成可练习的技能，用分级任务和现实反馈检验。',
        'habit' => '调整触发、动作链与环境条件，分别记录计划和现场。',
        'cognition' => '检查事实、解释与遗漏；情绪可以存在，认识可以修正。',
        'environment' => '优先改变条件与手段，再评价个人表现。',
        'limit' => '保留限制的证据和适用范围，寻找兼容路径。',
        _ => '尚未验证的“我天生不适合”不是结论。先做低成本实验。',
      };
}
