import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'self_os_models.dart';
import 'self_os_engine.dart';
import 'self_os_principles.dart';
import 'self_os_v37_rules.dart';

/// An explicit rules fallback. This never presents provider scores or treats
/// recommendation order as new psychological evidence.
class SelfOsMotiveRecommendations {
  static const version = 'self-os-rules-v28.1';
  static Map<String, dynamic> build(SelfOsCase c, List<SelfOsCase> history) {
    final allowed = SelfOsPrinciples.allowedHistory(c, history);
    final reviews = SelfOsPrinciples.evidence(allowed, currentCaseId: c.id);
    final ids = {
      ...reviews.keys,
      for (final e in c.v37.evidence.where((e) => e.reliableAt(DateTime.now())))
        e.id,
    };
    final fingerprints = SelfOsEngineService.motiveFingerprint(allowed);
    final candidates =
        c.motives.where((m) => m.userStatus == 'candidate').toList();
    bool valid(SelfOsMotive m) =>
        m.evidenceIds.isNotEmpty &&
        m.evidenceIds.every(ids.contains) &&
        (m.optionId.isEmpty || c.v37.routes.any((r) => r.id == m.optionId)) &&
        (m.desireId.isEmpty || c.desires.any((d) => d.id == m.desireId)) &&
        !(m.side == 'for' &&
            m.optionId.isNotEmpty &&
            SelfOsV37Rules.taskLimit(c.v37, routeId: m.optionId) != null);
    double? estimate(SelfOsMotive m) =>
        SelfOsEngineService.currentMotiveEffect(m, fingerprints) ?? m.predicted;
    final eligible = candidates.where(valid).toList()
      ..sort((a, b) {
        final proof = b.evidenceIds.length.compareTo(a.evidenceIds.length);
        if (proof != 0) return proof;
        return (estimate(b) ?? -1).compareTo(estimate(a) ?? -1);
      });
    String cluster(SelfOsMotive m) =>
        (m.semanticKey.trim().isEmpty ? m.title : m.semanticKey)
            .toLowerCase()
            .replaceAll(RegExp(r'[\s，。！？、,.;:!？]+'), '');
    final selected = <SelfOsMotive>[];
    final clusters = <String>{};
    for (final m in eligible) {
      if (selected.length == 5) break;
      if (clusters.add(cluster(m))) selected.add(m);
    }
    final opposition = eligible.where((m) => m.side == 'against').firstOrNull;
    if (opposition != null && !selected.any((m) => m.side == 'against')) {
      selected.removeWhere((m) => cluster(m) == cluster(opposition));
      if (selected.length == 5) selected.removeLast();
      selected.add(opposition);
    }
    final pending = candidates
        .where((m) =>
            !valid(m) && (m.side == 'against' || (m.importance ?? 0) >= 60))
        .toList();
    final uncertainOrder = selected.length > 1 &&
        List.generate(
            selected.length - 1,
            (i) => (estimate(selected[i]) == null ||
                estimate(selected[i + 1]) == null ||
                (estimate(selected[i])! - estimate(selected[i + 1])!).abs() <=
                    3)).any((v) => v);
    return {
      'method': 'rules',
      'version': version,
      'ranked': [
        for (final m in selected)
          {
            'motiveId': m.id,
            'routeId': m.optionId,
            'wantId': m.desireId,
            'title': m.title,
            'side': m.side,
            'evidenceIds': m.evidenceIds,
            'estimate': estimate(m),
            'why': '先核对来源，再比较现有暂估；已保留反方。',
          }
      ],
      'pendingIds': pending.map((m) => m.id).toList(),
      'uncertainOrder': uncertainOrder,
      'message': selected.isEmpty
          ? '尚无足够来源形成推荐，保留未评分候选供探索。'
          : '最多五条审议线索；数字若有，仅为暂估，不是意志强度、行动概率或已证因果。',
    };
  }

  static void record(SelfOsCase c, List<SelfOsCase> history) {
    final ranking = build(c, history);
    final signature = sha256
        .convert(utf8.encode(jsonEncode({
          'ranking': ranking,
          'motives': c.motives.map((m) => m.toJson()).toList(),
          'facts': c.v37.evidence.map((e) => e.toJson()).toList(),
        })))
        .toString();
    final runs = osMaps(c.v37.settings['motiveRecommendationRuns']);
    if (runs.isNotEmpty &&
        runs.last['signature'] == signature &&
        runs.last['round'] == c.round) return;
    runs.add({
      ...osClone(ranking),
      'id': selfOsId(),
      'round': c.round,
      'at': DateTime.now().toIso8601String(),
      'signature': signature
    });
    c.v37.settings['motiveRecommendationRuns'] = runs;
  }
}
