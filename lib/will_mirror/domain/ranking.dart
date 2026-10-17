import 'model.dart';
import 'rules.dart';

const rankingDimensions = [
  'personal_fit',
  'evidence_quality',
  'decision_materiality',
  'context_relevance'
];
const rubricVersion = 'wm-v28-four-facets-1';

class MotiveRanking {
  static String semanticText(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');
  static bool similar(MirrorNode a, MirrorNode b) {
    if (semanticText(a.text('semanticKey')) ==
        semanticText(b.text('semanticKey'))) return true;
    Set<String> grams(String text) {
      final runes = semanticText(text).runes.toList();
      return {
        for (var i = 0; i + 2 < runes.length; i++)
          String.fromCharCodes(runes.sublist(i, i + 3))
      };
    }

    final x = grams(a.text('summary')), y = grams(b.text('summary'));
    if (x.isEmpty || y.isEmpty) return a.text('summary') == b.text('summary');
    return x.intersection(y).length / x.union(y).length > 0.76;
  }

  static List<MirrorNode> distinct(Iterable<MirrorNode> input) {
    final out = <MirrorNode>[];
    for (final n in input) {
      if (!out.any((p) => similar(p, n))) out.add(n);
    }
    return out;
  }

  static bool isCounter(MirrorNode n) =>
      n.objects('directionByRoute').any((r) => r['relation'] == 'opposes');
  static bool isLong(MirrorNode n) =>
      {'long', 'mixed'}.contains(n.text('horizon'));
  static bool isCritical(MirrorNode n) =>
      n.flag('riskWarning') || n.text('materiality') == 'critical';
  static bool eligible(MirrorNode n, CaseFile file) {
    if (!n.usable ||
        n.text('factStatus') == 'contradicted' ||
        n.text('personalBasis') == 'unknown') return false;
    final all = {for (final node in file.nodes) node.id: node};
    final hasSource = EvidenceRules.actualRoots(n, all).isNotEmpty;
    if (!hasSource) return false;
    // A supportive argument for a prohibited route can remain in the pool but
    // never becomes an action recommendation. Its independent warning can.
    final directions = n.objects('directionByRoute');
    final currentRouteIds =
        file.current(NodeKind.route).map((n) => n.id).toSet();
    if (directions.isNotEmpty &&
        !directions.any((r) => currentRouteIds.contains(r['routeId'])))
      return false;
    bool blocked(String? id) {
      final route = file.node(id);
      if (route == null) return true;
      if (route.text('safety') == 'blocked' ||
          (file.latest(NodeKind.reappraisal)?.flag('safetyChanged') == true &&
              !route.flag('protective'))) return true;
      return file.current(NodeKind.routeFit).any((fit) =>
          fit.text('routeId') == id &&
          (fit.text('hardSafetyGate') == 'blocked' ||
              fit.text('bodySkillFit') == 'prohibited_due_to_safety'));
    }

    final unsafeOnly = directions.isNotEmpty &&
        directions.every((r) =>
            r['relation'] == 'supports' && blocked(r['routeId'] as String?));
    return !unsafeOnly && n.text('personalBasis') != 'generic';
  }

  static List<MirrorNode> shortlist(CaseFile file) {
    final candidates = distinct(file.current(NodeKind.motive));
    final valid = candidates
        .where((n) => n.text('factStatus') != 'contradicted')
        .toList();
    valid.sort((a, b) {
      int band(MirrorNode n) =>
          (isCritical(n) ? 8 : 0) +
          (isCounter(n) ? 4 : 0) +
          (isLong(n) ? 2 : 0) +
          (n.status == NodeStatus.accepted ? 1 : 0);
      final diff = band(b) - band(a);
      return diff != 0 ? diff : a.id.compareTo(b.id);
    });
    final result = <MirrorNode>[];
    // Critical warnings have protected slots before filling the diverse pool.
    for (final predicate in <bool Function(MirrorNode)>[
      isCritical,
      isCounter,
      isLong,
      (n) => n.status == NodeStatus.accepted
    ]) {
      final matching = valid.where(predicate);
      for (final n in matching.take(5)) {
        if (!result.contains(n)) result.add(n);
      }
    }
    for (final n in valid) {
      if (result.length >= 25) break;
      if (!result.contains(n)) result.add(n);
    }
    return result;
  }

  static MirrorNode build(CaseFile file,
      {List<double> weights = const [0.35, 0.25, 0.25, 0.15],
      Map<String, List<Json>> facets = const {},
      String method = 'rules',
      String model = '',
      DateTime? scoredAt,
      DateTime? expiresAt,
      String message = ''}) {
    if (weights.length != 4 ||
        weights.any((w) => !w.isFinite || w < 0) ||
        weights.fold<double>(0, (a, b) => a + b) <= 0)
      throw const MirrorProblem('权重必须是四个非负数，且总和大于零');
    final total = weights.fold<double>(0, (a, b) => a + b);
    final normalized = weights.map((w) => w / total).toList();
    final pool = shortlist(file);
    double? priority(MirrorNode n) {
      final fs = facets[n.id];
      if (fs == null || fs.length != 4) return null;
      var result = 0.0;
      for (var i = 0; i < 4; i++) {
        final matching =
            fs.where((f) => f['dimension'] == rankingDimensions[i]).toList();
        if (matching.length != 1 ||
            matching.single['status'] != 'scored' ||
            matching.single['score'] is! num) return null;
        result += (matching.single['score'] as num).toDouble() * normalized[i];
      }
      return result;
    }

    final candidates = pool
        .where((n) =>
            eligible(n, file) && (method != 'decisions' || priority(n) != null))
        .toList();
    candidates.sort((a, b) {
      if (method == 'decisions') {
        final diff = priority(b)!.compareTo(priority(a)!);
        if (diff != 0) return diff;
      }
      int band(MirrorNode n) =>
          (n.status == NodeStatus.accepted ? 8 : 0) +
          (n.text('personalBasis') == 'explicit' ? 4 : 0) +
          (n.text('materiality') == 'important' ? 2 : 0);
      final diff = band(b) - band(a);
      return diff != 0 ? diff : a.id.compareTo(b.id);
    });
    final selected = <MirrorNode>[];
    for (final predicate in <bool Function(MirrorNode)>[
      isCritical,
      isCounter,
      isLong
    ]) {
      final matching = candidates
          .where(predicate)
          .where((n) => !selected.any((s) => similar(s, n)))
          .toList();
      if (matching.isNotEmpty && !selected.contains(matching.first))
        selected.add(matching.first);
    }
    for (final n in candidates) {
      if (selected.length >= 5) break;
      if (!selected.any((s) => similar(s, n))) selected.add(n);
    }
    if (method == 'decisions')
      selected.sort((a, b) => priority(b)!.compareTo(priority(a)!));
    final unknown = pool
        .where((n) =>
            !eligible(n, file) ||
            (method == 'decisions' && priority(n) == null))
        .map((n) => n.id)
        .toList();
    bool unstable = false;
    for (var i = 1; i < selected.length; i++) {
      final a = priority(selected[i - 1]), b = priority(selected[i]);
      if (a != null && b != null && (a - b).abs() < 0.12) unstable = true;
    }
    final now = DateTime.now().toUtc();
    return MirrorNode(
        id: newId('ranking'),
        caseId: file.id,
        episodeId: file.episodeId,
        kind: NodeKind.recommendation,
        origin: EvidenceOrigin.productRule,
        phase: file.phase,
        recordedAt: now,
        knownAt: now,
        evidenceIds: selected.expand((n) => n.evidenceIds).toSet().toList(),
        links: pool.map((n) => n.id).toList(),
        body: {
          'method': method,
          'scoredAt': method == 'decisions'
              ? (scoredAt ?? now).toUtc().toIso8601String()
              : null,
          'expiresAt': method == 'decisions'
              ? (expiresAt ?? (scoredAt ?? now).add(const Duration(hours: 24)))
                  .toUtc()
                  .toIso8601String()
              : null,
          'rubricVersion': rubricVersion,
          'weights': normalized,
          'allFacets': [
            for (final n in pool)
              if (facets.containsKey(n.id))
                {'motiveId': n.id, 'facets': facets[n.id]}
          ],
          'ranked': [
            for (var i = 0; i < selected.length; i++)
              {
                'motiveId': selected[i].id,
                'rank': i + 1,
                'priority': priority(selected[i]),
                'reason': isCritical(selected[i])
                    ? '会影响安全或关键条件，优先审查'
                    : isCounter(selected[i])
                        ? '保留重要反方，避免只看到同一方向'
                        : isLong(selected[i])
                            ? '保留跨时间的代价与收益'
                            : selected[i].status == NodeStatus.accepted
                                ? '与你认可的理由有关，有当前来源可查看'
                                : '与当前课题和实际来源有关',
                'rule': method == 'decisions'
                    ? '四维量规加权后保留关键反方与时域差异'
                    : '来源资格与观点覆盖；未计算在线分数',
                'facets': facets[selected[i].id] ??
                    [
                      for (final dimension in rankingDimensions)
                        {
                          'dimension': dimension,
                          'score': null,
                          'confidence': null,
                          'status': 'unknown',
                          'answerName': '${selected[i].id}_$dimension'
                        }
                    ],
              }
          ],
          'shortlistIds': pool.map((n) => n.id).toList(),
          'nearMissIds': candidates
              .where((n) => !selected.contains(n))
              .map((n) => n.id)
              .toList(),
          'verifyFirstIds': unknown,
          'message': message,
          'model': model,
          'snapshotHash': digest(file.nodes
              .where((n) => n.usable)
              .map((n) => n.toJson())
              .toList()),
          'unstable': unstable
        });
  }

  static List<String> sensitivity(CaseFile file, List<double> weights,
          Map<String, List<Json>> facets) =>
      build(file, weights: weights, facets: facets, method: 'decisions')
          .objects('ranked')
          .map((r) => r['motiveId'] as String)
          .toList();
}
