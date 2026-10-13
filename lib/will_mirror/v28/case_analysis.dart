import 'case_models.dart';

/// Deterministic evidence eligibility and ranking. Scores describe this review,
/// never a latent trait, causal effect, preference percentage or success chance.
class WmAnalysisEngine {
  const WmAnalysisEngine();
  static const rubricVersion = 'wm-motive-2.8.1';
  static const dimensions = [
    'personal_fit',
    'evidence_quality',
    'decision_materiality',
    'context_relevance'
  ];
  static const boundary = '个人认识是有条件、可修订的经验假设。没行动不等于不想要，完成也不能单独证明原因。';

  WmAnalysis local(WmCase c) {
    final ids = c.activeEvidence.map((e) => e.id).toList();
    final brief =
        c.issue.length > 48 ? '${c.issue.substring(0, 48)}…' : c.issue;
    final want = WmWant(
        id: '${c.id}_want',
        claim: '关于「$brief」，你愿意保留的目标和愿意承担的代价仍待确认',
        evidenceIds: ids.take(1).toList(),
        context: '仅当前课题',
        alternative: '也可能来自外界要求、短暂感受或尚未核实的条件',
        nextTest: '先核实最影响选择的一件事；不必现在给自己下结论',
        status: ids.isEmpty ? 'unknown' : 'tentative');
    final routes = [
      WmRoute(
          id: '${c.id}_verify',
          title: '先核实关键条件',
          action: '围绕「$brief」，写下一个会改变选择的未知，并查一个可靠来源。',
          wantIds: [want.id],
          evidenceIds: ids.take(1).toList(),
          near: '可能减少信息缺口，也需要时间',
          far: '能否改善结果仍未知',
          protective: true,
          requirement: '核实过程本身安全、合法，不涉及未经同意的接触',
          falsifier: '信息已足够，或核实本身不安全'),
      WmRoute(
          id: '${c.id}_small',
          title: '定义一个可撤回的小试验',
          action: '把你愿意尝试的动作缩小到能观察的一步，再核实所需条件。',
          wantIds: [want.id],
          near: '得到少量真实体验；成本需先确认',
          far: '一次体验不能代表长期适配',
          support: '可调整工具、时段、训练或请求自愿协作',
          requirement: '先明确动作、成本、资格与退出条件'),
      WmRoute(
          id: '${c.id}_pause',
          title: '暂缓或保护性退出',
          action: '暂不执行未核实的手段，保留目标；需要时向可信的人或适当专业渠道求助。',
          wantIds: [want.id],
          near: '保留重新判断的空间；机会成本仍待核实',
          far: '暂缓一个手段不等于永久放弃所有可能',
          protective: true,
          requirement: '核对迫近时限；存在现实危险时优先保护和求助'),
    ];
    final motives = [
      WmMotive(
          id: '${c.id}_m1',
          text: '你提出了这个现实课题；哪些结果值得保留，需要由本人确认。',
          directionByRoute: {routes[1].id: 'conditional'},
          wantIds: [want.id],
          evidenceIds: ids.take(1).toList(),
          semanticKey: 'stated_goal',
          representation: 'abstract',
          horizon: 'near',
          source: 'local_rule',
          falsifier: '用户不再认可该目标'),
      WmMotive(
          id: '${c.id}_m2',
          text: '关键条件尚未核实，过早行动可能忽略真实限制。',
          directionByRoute: {routes[0].id: 'support', routes[1].id: 'oppose'},
          evidenceIds: [],
          semanticKey: 'missing_conditions',
          representation: 'abstract',
          horizon: 'present',
          source: 'local_rule',
          safetyConcern: true,
          falsifier: '关键条件已被可靠核实'),
      WmMotive(
          id: '${c.id}_m3',
          text: '可以保留目标，同时更换手段；当前还不知道哪种日常过程适合你。',
          directionByRoute: {
            routes[1].id: 'conditional',
            routes[2].id: 'support'
          },
          wantIds: [want.id],
          semanticKey: 'means_and_fit',
          representation: 'abstract',
          horizon: 'long',
          source: 'local_rule',
          falsifier: '现实中没有安全可行的替代手段'),
    ];
    return WmAnalysis(
        wants: [want],
        routes: routes,
        motives: motives,
        unknowns: ['哪些是已核实的事实，哪些是预测？', '本人所欲、行动机会、身体技能与外部限制尚不能由一句话确定'],
        receipt:
            '本地整理 · ${motives.length} 条待审议候选；未生成 50 条个人化动机，也未调用 Decisions API。',
        version: c.analysis.version + 1);
  }

  void validate(WmAnalysis a, WmCase c) {
    final evidence = c.activeEvidence.map((e) => e.id).toSet();
    final wants = a.wants.map((e) => e.id).toSet();
    final routes = a.routes.map((e) => e.id).toSet();
    final motives = a.motives.map((e) => e.id).toSet();
    if (wants.length != a.wants.length ||
        routes.length != a.routes.length ||
        motives.length != a.motives.length ||
        a.routes.length > 20 ||
        a.motives.length > 70 ||
        a.wants.length > 6 ||
        a.reframes.length > 6) {
      throw const FormatException('分析对象重复或超出范围');
    }
    void refs(List<String> ids, Set<String> allowed) {
      if (ids.any((id) => !allowed.contains(id)))
        throw const FormatException('分析引用了不存在或已撤回的证据');
    }

    for (final w in a.wants) {
      _text(w.id);
      _text(w.claim);
      _text(w.alternative);
      _text(w.nextTest);
      refs(w.evidenceIds, evidence);
      refs(w.counterIds, evidence);
      if (w.evidenceIds.isEmpty && w.status != 'unknown')
        throw const FormatException('欲求候选缺少来源');
      if (!['tentative', 'unknown', 'contradicted', 'user_endorsed']
          .contains(w.status)) throw const FormatException('不可把候选升级为性格结论');
    }
    for (final r in a.routes) {
      _text(r.id);
      _text(r.title);
      _text(r.action);
      refs(r.wantIds, wants);
      refs(r.evidenceIds, evidence);
      if (r.difficulty != null && (r.difficulty! < 1 || r.difficulty! > 5))
        throw const FormatException('路线难度越界');
      if (r.gate == WmGate.clear && r.evidenceIds.isEmpty)
        throw const FormatException('无来源不能核准路线');
    }
    for (final m in a.motives) {
      _text(m.id);
      _text(m.text);
      _text(m.falsifier);
      refs(m.wantIds, wants);
      refs(m.evidenceIds, evidence);
      refs(m.counterIds, evidence);
      refs(m.directionByRoute.keys.toList(), routes);
      if (m.directionByRoute.isEmpty ||
          m.directionByRoute.values.any((v) =>
              !['support', 'oppose', 'conditional', 'unknown'].contains(v)))
        throw const FormatException('动机必须关联有效路线');
      if (!['intuitive', 'abstract', 'mixed', 'unknown']
              .contains(m.representation) ||
          !['present', 'near', 'long', 'unknown'].contains(m.horizon) ||
          !['hypothesis', 'reported', 'verified', 'refuted', 'unknown']
              .contains(m.status)) throw const FormatException('动机类别不合法');
      if (m.status == 'verified' &&
          (m.evidenceIds.isEmpty ||
              m.evidenceIds.any((id) =>
                  c.evidence.firstWhere((e) => e.id == id).status !=
                  WmFactStatus.verified))) {
        throw const FormatException('模型不能自行核实事实');
      }
    }
    for (final r in a.reframes) {
      for (final field in [
        'oldBelief',
        'newClaim',
        'operator',
        'basis',
        'falsifier',
        'test'
      ]) {
        _text(wmText(r[field]));
      }
      refs(wmStrings(r['evidenceIds']), evidence);
      refs(wmStrings(r['routeIds']), routes);
      refs(wmStrings(r['motiveIds']), motives);
      if (r['status'] != 'hypothesis')
        throw const FormatException('新认识必须保持待检验');
    }
  }

  static void _text(String value) {
    if (value.trim().isEmpty || value.length > 4000)
      throw const FormatException('分析字段缺失或过长');
    if (RegExp(
            r'你(的本质|天生就是|注定|永远不可能)|测得.{0,8}(睿智性格|真正意志)|认命就好|必须忍受(虐待|暴力)|成功概率\s*[:：]?\s*\d+')
        .hasMatch(value)) {
      throw const FormatException('分析越过了证据或安全边界');
    }
  }

  List<WmMotive> deduplicate(Iterable<WmMotive> input) {
    final kept = <WmMotive>[];
    for (final m in input) {
      final duplicate = kept.indexWhere((old) =>
          _sameDirections(old, m) &&
          ((m.semanticKey.isNotEmpty && m.semanticKey == old.semanticKey) ||
              _similar(old.text, m.text)));
      if (duplicate < 0) {
        kept.add(m);
      } else if (m.safetyConcern && !kept[duplicate].safetyConcern) {
        kept[duplicate] = WmMotive.fromJson(
            {...kept[duplicate].toJson(), 'safetyConcern': true});
      }
    }
    return kept.take(70).toList();
  }

  bool _sameDirections(WmMotive a, WmMotive b) =>
      a.directionByRoute.length == b.directionByRoute.length &&
      a.directionByRoute.entries
          .every((e) => b.directionByRoute[e.key] == e.value);
  bool _similar(String a, String b) {
    String clean(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');
    final aa = clean(a), bb = clean(b);
    if (aa == bb) return true;
    Set<String> pairs(String s) =>
        {for (var i = 0; i < s.length - 1; i++) s.substring(i, i + 2)};
    final x = pairs(aa), y = pairs(bb), union = x.union(y);
    return union.isNotEmpty && x.intersection(y).length / union.length > .78;
  }

  /// Retain the most consequential opposing/long-horizon items before scoring.
  /// Safety candidates are never silently removed by a similarity-only stage.
  List<WmMotive> shortlist(WmCase c) {
    final all =
        deduplicate(c.analysis.motives).where((m) => eligible(c, m)).toList();
    all.sort((a, b) {
      int priority(WmMotive m) =>
          (m.safetyConcern ? 100 : 0) +
          (m.opposing ? 20 : 0) +
          (m.horizon == 'long' ? 10 : 0) +
          (m.feedback == 'endorsed' ? 5 : 0);
      final diff = priority(b) - priority(a);
      return diff != 0 ? diff : a.id.compareTo(b.id);
    });
    final safety = all.where((m) => m.safetyConcern).toList();
    return [
      ...safety,
      ...all
          .where((m) => !m.safetyConcern)
          .take((25 - safety.length).clamp(0, 25))
    ];
  }

  bool eligible(WmCase c, WmMotive m) {
    if (m.status == 'refuted' || (m.feedback == 'rejected' && !m.safetyConcern))
      return false;
    final active = c.activeEvidence.map((e) => e.id).toSet();
    if (m.evidenceIds.any((id) => !active.contains(id))) return false;
    final linked = c.analysis.routes
        .where((r) => m.directionByRoute.containsKey(r.id))
        .toList();
    if (linked.isEmpty) return false;
    // Supporting an unsafe route can never be rescued by a high score.
    return linked.any((r) =>
        m.directionByRoute[r.id] == 'oppose' || r.gate != WmGate.blocked);
  }

  WmJson rank(WmCase c,
      {required String runId,
      required int now,
      Map<String, WmJson>? remoteFacets,
      String? remoteReceipt}) {
    if (c.weights.keys.toSet().difference(dimensions.toSet()).isNotEmpty ||
        dimensions.any((d) => !c.weights.containsKey(d)) ||
        c.weights.values.any((v) => !v.isFinite || v < 0) ||
        (c.weights.values.fold(0.0, (a, b) => a + b) - 1).abs() > .00001)
      throw const FormatException('权重须为非负且合计为 1');
    final pool = shortlist(c);
    final facets = <String, WmJson>{};
    final scores = <String, double>{};
    final unknown = <String>[];
    for (final m in pool) {
      final ev =
          c.activeEvidence.where((e) => m.evidenceIds.contains(e.id)).toList();
      final quality = ev.isEmpty
          ? null
          : ev.any((e) => e.status == WmFactStatus.verified)
              ? 3.0
              : ev.any((e) => e.factual)
                  ? 2.0
                  : null;
      final personal = m.feedback == 'endorsed'
          ? 3.0
          : ev.any((e) => e.factual) && m.wantIds.isNotEmpty
              ? 2.0
              : null;
      final local = <String, dynamic>{
        'personal_fit': personal,
        'evidence_quality': quality,
        'decision_materiality': m.safetyConcern
            ? 4.0
            : m.opposing || m.horizon == 'long'
                ? 3.0
                : 2.0,
        'context_relevance': 2.0
      };
      final remote = remoteFacets?[m.id];
      final values = remote == null ? local : {...remote};
      for (final d in dimensions) {
        final v = values[d];
        if (v != null && (v is! num || !v.isFinite || v < 0 || v > 4))
          throw const FormatException('评分维度越界');
      }
      // A model score cannot replace missing personal / factual evidence.
      if (personal == null) values['personal_fit'] = null;
      if (quality == null) values['evidence_quality'] = null;
      facets[m.id] = {
        'values': values,
        'source': remote == null ? 'local_rule' : 'decisions',
        'confidence': remote?['confidence'],
        'evidenceIds': m.evidenceIds,
        'status': 'unscored'
      };
      if (dimensions.any((d) => values[d] is! num)) {
        unknown.add(m.id);
        continue;
      }
      final s = dimensions.fold(
          0.0, (sum, d) => sum + (values[d] as num).toDouble() * c.weights[d]!);
      scores[m.id] = s;
      facets[m.id]!['status'] = 'scored';
    }
    final scored = pool.where((m) => scores.containsKey(m.id)).toList()
      ..sort((a, b) {
        final diff = scores[b.id]!.compareTo(scores[a.id]!);
        return diff != 0 ? diff : a.id.compareTo(b.id);
      });
    final selected = <WmMotive>[];
    void include(WmMotive m) {
      if (selected.length < 5 && !selected.any((s) => s.id == m.id))
        selected.add(m);
    }

    // This is a set constraint, not a hard-coded positive/negative quota.
    for (final m in pool.where((m) => m.safetyConcern)) {
      include(m);
    }
    final opposing = scored.where((m) => m.opposing);
    if (opposing.isNotEmpty) include(opposing.first);
    final long = scored.where((m) => m.horizon == 'long');
    if (long.isNotEmpty) include(long.first);
    for (final m in scored) {
      include(m);
    }
    final nearTies = <String>[];
    for (var i = 1; i < scored.length; i++) {
      if ((scores[scored[i - 1].id]! - scores[scored[i].id]!).abs() < .08)
        nearTies.addAll([scored[i - 1].id, scored[i].id]);
    }
    return {
      'id': runId,
      'at': now,
      'phase': c.phase.name,
      'cycle': c.cycle,
      'graphVersion': c.analysis.version,
      'evidenceIds': c.activeEvidence.map((e) => e.id).toList(),
      'rubricVersion': rubricVersion,
      'weights': c.weights,
      'status': 'current',
      'provider': remoteFacets == null ? 'local_rule' : 'decisions',
      'receipt': remoteReceipt ?? '本地可解释规则排序 · 不是 Decisions API 评分',
      'facets': facets,
      'scores': scores,
      'unknown': unknown,
      'nearTies': nearTies.toSet().toList(),
      'shortlistIds': pool.map((m) => m.id).toList(),
      'topIds': selected.map((m) => m.id).toList(),
      'selections': selected
          .map((m) => {
                'motiveId': m.id,
                'evidenceIds': m.evidenceIds,
                'directionByRoute': m.directionByRoute,
                'reason': m.safetyConcern
                    ? '优先核实风险；不以分数覆盖安全，反驳个人关联也不会移除独立风险'
                    : m.opposing
                        ? '保留重要反方'
                        : m.horizon == 'long'
                            ? '保留长期代价与收益'
                            : '按当前证据和公开权重优先审议',
                'status': scores.containsKey(m.id) ? 'scored' : 'verify_first'
              })
          .toList()
    };
  }
}
