import 'self_os_models.dart';
import 'self_os_engine.dart';

class OsStrengthAssessment {
  const OsStrengthAssessment(
      this.supports, this.counters, this.contexts, this.cases, this.overuse);
  final int supports, counters, contexts, cases, overuse;
  bool get verified =>
      supports >= 3 && contexts >= 2 && cases >= 2 && supports > counters;
  String get confidence => verified ? '多情境支持 · 仍可反证' : '候选力量 · 继续验证';
}

class SelfOsInsights {
  static OsStrengthAssessment strength(OsStrength s, List<SelfOsCase> cases) {
    final reviews = {
      for (final c in cases)
        for (final r in c.reviews) r.id: (c.id, r)
    };
    final seen = <String>{}, contexts = <String>{}, caseIds = <String>{};
    var supports = 0, counters = 0, overuse = 0;
    for (final observation in s.observations) {
      final id = osText(observation['reviewId']);
      if (!seen.add(id) || !reviews.containsKey(id)) continue;
      final (caseId, r) = reviews[id]!;
      if (observation['effect'] == 'helped') {
        supports++;
        if (r.context.trim().isNotEmpty) contexts.add(r.context.trim());
        caseIds.add(caseId);
      } else if (['notHelped', 'harmed'].contains(observation['effect'])) {
        counters++;
      }
      if (observation['usage'] == 'overuse') overuse++;
    }
    return OsStrengthAssessment(
        supports, counters, contexts.length, caseIds.length, overuse);
  }

  static List<Map<String, String>> attribution(SelfOsReview r) {
    final fields = osMap(r.snapshot['fields']);
    final settings = osMap(osMap(r.snapshot['v37'])['settings']);
    final comparisons = <String, (String, String)>{
      'K · 新认识': (
        osText(fields['k2']).isEmpty
            ? osText(fields['k1'])
            : osText(fields['k2']),
        r.notes['knowledgeAtAction'] ?? ''
      ),
      'M · 动机结构': ('', r.notes['motivationChange'] ?? ''),
      'Att · 注意前景': ('', r.notes['attentionChange'] ?? ''),
      'E · 环境结构': (
        osText(fields['environment']),
        r.notes['environmentAtAction'] ?? ''
      ),
      'T · 身体 / 时点': (
        osText(fields['actionState']),
        r.notes['stateAtAction'] ?? ''
      ),
      'Skill · 技能': (
        osText(settings['skillBaseline']),
        r.notes['skillAtAction'] ?? ''
      ),
    };
    return [
      for (final e in comparisons.entries)
        {
          'source': e.key,
          'level': e.value.$2.isEmpty
              ? '未知'
              : e.value.$1.isNotEmpty && e.value.$1 != e.value.$2
                  ? '中等证据'
                  : '自报线索',
          'state': e.value.$2.isEmpty
              ? 'unknown'
              : e.value.$2 == e.value.$1
                  ? 'stable'
                  : 'changed',
          'evidence': e.value.$2.isEmpty
              ? '未记录行动时的这一条件，不能推断没有变化。'
              : '${e.value.$1.isEmpty ? '事前未记录，缺少直接对照' : '事前：${e.value.$1}'}\n行动时：${e.value.$2}',
        },
      {
        'source': 'C · 稳定模式',
        'level': '尚不构成性格改变证据',
        'state': 'unknown',
        'evidence': '这一次只形成案例证据。先比较认识、动机、注意、环境、状态和技能，再跨情境检验。',
      }
    ];
  }

  static List<String> stableChanges(List<SelfOsCase> cases) {
    final groups = <String, List<SelfOsObservation>>{};
    for (final o in SelfOsEngineService.observations(cases)) {
      final r = o.review;
      if (r.notes['evidenceUse'] != 'usable' ||
          (r.notes['patternClaim'] ?? '').trim().isEmpty) continue;
      final conditions = attribution(r).take(6).toList();
      if (['K', 'M', 'Att', 'E', 'T', 'Skill']
              .any((k) => r.notes['control.$k'] != 'stable') ||
          conditions
              .any((e) => e['state'] == 'changed' && e['level'] == '中等证据') ||
          (r.notes['alternativeExplanationCheck'] ?? '').trim().isEmpty)
        continue;
      groups.putIfAbsent(r.notes['patternClaim']!.trim(), () => []).add(o);
    }
    return [
      for (final e in groups.entries)
        if (e.value.length >= 3 &&
            e.value.map((o) => o.caseId).toSet().length >= 2 &&
            e.value.map((o) => o.review.context).toSet().length >= 2)
          '「${e.key}」已有 ${e.value.length} 次跨情境对照，且记录了对其他变化来源的检查。可作为待反证的稳定模式，仍保留情境范围。'
    ];
  }

  static List<String> pathGuard(List<SelfOsCase> cases, SelfOsProfile profile,
      {DateTime? at}) {
    final now = at ?? DateTime.now();
    final recent = profile.tradeoffs.where((t) {
      final d = DateTime.tryParse(osText(t['createdAt']));
      return d != null &&
          !d.isAfter(now) &&
          now.difference(d).inDays < 7 &&
          t['to'] == 'active';
    }).toList();
    final attracted = recent
        .where(
            (t) => ['novelty', 'comparison', 'escape'].contains(t['trigger']))
        .length;
    final comparisons = cases
        .where((c) =>
            c.v37.text('triggerSource') == 'comparison' &&
            !c.v37.flag('fullLifeAccepted'))
        .toList();
    return [
      if (recent.map((t) => '${t['caseId']}:${t['routeId']}').toSet().length >=
              3 &&
          attracted >= 2)
        '主线护栏：7 天内多次切换主线，其中 $attracted 次由新鲜、羡慕或即时逃避触发。先比较新证据，也可以保留为实验。',
      for (final c in comparisons.take(2))
        '适配检查：${c.problem}。除了羡慕的外观，连同日常、压力、能力要求和代价一起，你仍愿意吗？',
    ];
  }

  static List<String> decisionFingerprint(List<SelfOsCase> cases) {
    final groups = <String, List<SelfOsReview>>{};
    for (final o in SelfOsEngineService.observations(cases)) {
      final r = o.review;
      final mode = r.notes['jamesMode'] ?? 'unknown';
      if (mode == 'unknown' ||
          !osJamesModes.containsKey(mode) ||
          (r.notes['decisionProcessEvidence'] ?? '').isEmpty) continue;
      groups.putIfAbsent(mode, () => []).add(r);
    }
    return [
      for (final e in groups.entries)
        '${osJamesModes[e.key]}：${e.value.length} 次有过程证据的决意；${e.value.where((r) => r.notes['holdEffect'] == 'helped').length} 次明确反馈关键观念保持有帮助。这描述过程，不定义人格。'
    ];
  }

  static List<String> interventionFingerprint(List<SelfOsCase> cases) {
    final groups = <String, List<OsIntervention>>{};
    for (final c in cases) {
      for (final i in c.v37.interventions.where((i) =>
          i.completed &&
          i.text('reviewId').isNotEmpty &&
          c.reviews.any((r) => r.id == i.text('reviewId')))) {
        groups.putIfAbsent('${i.type}|${i.text('window')}', () => []).add(i);
      }
    }
    return [
      for (final e in groups.entries)
        '${osInterventionTypes[e.value.first.type]} · ${osPreparationWindows[e.value.first.text('window')]}：${e.value.length} 次有行动回写，${e.value.where((i) => osMap(i.data['gain'])['decisionConditionsChanged'] == true && !i.flag('late')).length} 次在决定前观察到条件变化。不是因果效果概率。'
    ];
  }
}
