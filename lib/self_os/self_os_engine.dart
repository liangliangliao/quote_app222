import 'self_os_models.dart';
import 'self_os_action_facts.dart';

class SelfOsNextStep {
  const SelfOsNextStep(this.engine, this.reason);
  final SelfOsEngine engine;
  final String reason;
}

class SelfOsObservation {
  const SelfOsObservation(this.caseId, this.problem, this.review);
  final String caseId, problem;
  final SelfOsReview review;
}

class SelfOsFingerprint {
  const SelfOsFingerprint(this.label, this.helped, this.total);
  final String label;
  final int helped, total;
  double get rate => helped * 100 / total;
}

class SelfOsConflict {
  SelfOsConflict(this.first, this.second);
  final String first, second;
  int firstWins = 0, secondWins = 0;
  int get total => firstWins + secondWins;
}

/// Transparent routing and evidence arithmetic; these are not AI probabilities
/// or a psychometric personality diagnosis. Missing observations stay missing.
class SelfOsEngineService {
  static bool isRetrospective(String text) =>
      RegExp('刚刚|刚才|已经.*(做|去|完成)|做完|后悔|没有去|没去|放弃了').hasMatch(text);

  static SelfOsNextStep next(SelfOsCase c) {
    if (c.reviewed)
      return const SelfOsNextStep(
          SelfOsEngine.mirror, '本轮已产生新证据。查看复盘，或开始下一轮验证。');
    if (c.retrospective || c.committedAt != null)
      return const SelfOsNextStep(
          SelfOsEngine.mirror, '行动之后记录结果；尚未行动时，可回到行动现场查看协议。');
    if (c.blocker == 'desire')
      return const SelfOsNextStep(SelfOsEngine.desire, '先重新审视欲求与代价，允许改变或舍弃目标。');
    if (c.blocker == 'means')
      return const SelfOsNextStep(SelfOsEngine.desire, '保留深层欲求，比较更适合的手段。');
    if (c.acceptedDesires.isEmpty)
      return const SelfOsNextStep(
          SelfOsEngine.desire, '还没有经你确认的欲求假设，先分清目标与手段。');
    final recent = c.reviews.reversed.take(3).toList();
    if (recent.length >= 3 &&
        recent
                .where((r) =>
                    (osNumber(osMap(r.snapshot['scores'])['planProbability']) ??
                            0) >=
                        70 &&
                    r.outcome == 'notDone' &&
                    !['started_blocked', 'revised_on_new_information']
                        .contains(r.notes['attemptStatus']) &&
                    r.notes['autonomy'] != 'coerced' &&
                    r.notes['opportunity'] != 'absent')
                .length >=
            2) {
      return const SelfOsNextStep(
          SelfOsEngine.action, '最近三轮中，至少两次高计划意愿没有落地。先重新设计现场，再增加承诺。');
    }
    if ((c.temporalGap ?? 0) >= 25)
      return const SelfOsNextStep(
          SelfOsEngine.action, '计划与现场相差至少 25 个百分点，优先设计现场条件。该阈值是产品提示规则。');
    if (c.blocker == 'environment')
      return const SelfOsNextStep(
          SelfOsEngine.action, '认识可能合理，先调整环境、触发条件和第一步。');
    if (c.blocker == 'cognition' && c.text('k2').trim().isEmpty)
      return const SelfOsNextStep(SelfOsEngine.cognition, '检验错误或遗漏，目标是更完整的认识。');
    if ((c.scores['actionProbability'] ?? 100) < 50 && c.blocker == 'unknown')
      return const SelfOsNextStep(
          SelfOsEngine.desire, '行动意愿偏低：先区分欲求、手段、认识、环境四类原因。');
    if (!c.motives.any((m) => m.selected && m.side == 'for') ||
        !c.motives.any((m) => m.selected && m.side == 'against'))
      return const SelfOsNextStep(
          SelfOsEngine.motivation, '让正反动机都进入选择，再决定是否行动。');
    return const SelfOsNextStep(
        SelfOsEngine.action, '将选择变成可执行的第一步，并分别记录计划与现场预测。');
  }

  static List<SelfOsObservation> observations(List<SelfOsCase> cases) {
    final seen = <String>{};
    final result = <SelfOsObservation>[];
    for (final c in cases) {
      for (final r in c.reviews) {
        if (r.notes['experienceWithdrawn'] == 'yes') continue;
        if (seen.add(r.id)) result.add(SelfOsObservation(c.id, c.problem, r));
      }
    }
    result.sort((a, b) => b.review.createdAt.compareTo(a.review.createdAt));
    return result;
  }

  static double? average(Iterable<double?> values) {
    final known = values.whereType<double>().toList();
    return known.isEmpty ? null : known.reduce((a, b) => a + b) / known.length;
  }

  static List<SelfOsFingerprint> motiveFingerprint(List<SelfOsCase> cases) {
    final counts = <String, List<int>>{};
    for (final o in observations(cases)) {
      final r = o.review;
      if (!r.motiveFeedbackRecorded) continue;
      final motives = osMaps(r.snapshot['motives']);
      final types = motives.map((m) => osText(m['type'])).toSet();
      for (final type in types.where((t) => t.isNotEmpty)) {
        final count = counts.putIfAbsent(type, () => [0, 0]);
        count[1]++;
        if (motives.any(
            (m) => m['type'] == type && r.effectiveMotives.contains(m['id'])))
          count[0]++;
      }
    }
    return counts.entries
        .map((e) => SelfOsFingerprint(e.key, e.value[0], e.value[1]))
        .toList()
      ..sort((a, b) => b.rate.compareTo(a.rate));
  }

  static List<SelfOsFingerprint> cognitiveFingerprint(List<SelfOsCase> cases) {
    final counts = <String, List<int>>{};
    for (final o in observations(cases)) {
      final operation =
          osText(osMap(o.review.snapshot['fields'])['cognitiveOperation']);
      final feedback = o.review.notes['cognitionFeedback'];
      if (operation.isEmpty || !['helped', 'notHelped'].contains(feedback))
        continue;
      final count = counts.putIfAbsent(operation, () => [0, 0]);
      count[1]++;
      if (feedback == 'helped') count[0]++;
    }
    return counts.entries
        .map((e) => SelfOsFingerprint(e.key, e.value[0], e.value[1]))
        .toList()
      ..sort((a, b) => b.rate.compareTo(a.rate));
  }

  static double motiveRank(SelfOsMotive m, List<SelfOsFingerprint> history) {
    final effect = currentMotiveEffect(m, history);
    if (effect != null) return effect;
    final samples = history.where((h) => h.label == m.type && h.total >= 3);
    // Once measured, personal history takes precedence over AI's prior score.
    if (samples.isNotEmpty) return samples.first.rate;
    return m.predicted ?? 0;
  }

  /// An explanatory availability index, never a probability of taking action.
  /// Unknown factors stay unknown; we do not turn missing attention into zero.
  static double? currentMotiveEffect(
      SelfOsMotive m, List<SelfOsFingerprint> history) {
    final samples = history.where((h) => h.label == m.type && h.total >= 3);
    final base = samples.isNotEmpty ? samples.first.rate : m.predicted;
    final factors = [
      m.importance,
      m.credibility,
      m.vividness,
      m.occupancy,
      base
    ];
    if (factors.any((v) => v == null)) return null;
    return factors.fold<double>(
        100, (value, factor) => value * factor!.clamp(0, 100) / 100);
  }

  static List<String> patterns(List<SelfOsCase> cases) {
    final grouped = <String, List<SelfOsObservation>>{};
    for (final o in observations(cases)) {
      if (!o.review.mayGeneralize) continue;
      final desire = (o.review.notes['servedDesire'] ?? '').trim();
      if (desire.isNotEmpty) grouped.putIfAbsent(desire, () => []).add(o);
    }
    final result = <String>[];
    for (final e in grouped.entries) {
      final contexts = e.value.map((o) => o.review.context.trim()).toSet();
      final caseIds = e.value.map((o) => o.caseId).toSet();
      if (e.value.length >= 3 && contexts.length >= 2 && caseIds.length >= 2) {
        result.add(
            '在 ${caseIds.length} 个案例、${contexts.length} 种情境的 ${e.value.length} 次复盘中，你记录行动服务了「${e.key}」。这是待反证的情境模式，不是固定性格。');
      }
    }
    return result;
  }

  static List<SelfOsConflict> conflicts(List<SelfOsCase> cases) {
    final pairs = <String, SelfOsConflict>{};
    for (final o in observations(cases)) {
      final served = (o.review.notes['servedDesire'] ?? '').trim();
      if (!o.review.mayGeneralize) continue;
      final sacrificed = (o.review.notes['sacrificedDesire'] ?? '').trim();
      if (served.isEmpty || sacrificed.isEmpty || served == sacrificed)
        continue;
      final names = [served, sacrificed]..sort();
      final key = '${names.first.length}:${names.first}${names.last}';
      final pair =
          pairs.putIfAbsent(key, () => SelfOsConflict(names.first, names.last));
      if (served == pair.first) {
        pair.firstWins++;
      } else {
        pair.secondWins++;
      }
    }
    return pairs.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  static double? actionCalibrationError(List<SelfOsCase> cases) =>
      average(observations(cases).map((o) {
        final r = o.review;
        final p = osNumber(osMap(r.snapshot['scores'])['revisedProbability']) ??
            osNumber(osMap(r.snapshot['scores'])['actionProbability']);
        if (p == null ||
            r.outcome == 'partial' ||
            ['started_blocked', 'revised_on_new_information']
                .contains(r.notes['attemptStatus']) ||
            r.notes['autonomy'] == 'coerced' ||
            r.notes['opportunity'] == 'absent') return null;
        return (p - (r.outcome == 'done' ? 100 : 0)).abs();
      }));

  static Map<String, dynamic> historyForAi(List<SelfOsCase> cases) => {
        'evidenceCount': observations(cases).length,
        'recentEvidence': observations(cases)
            .take(12)
            .map((o) => {
                  'id': o.review.id,
                  'context': o.review.context,
                  'result': o.review.result,
                  'learning': o.review.learning,
                  'actionFacts': SelfOsActionFacts.forAnalysis(o.review.notes),
                  'predictionError': o.review.predictionError
                })
            .toList(),
        'motivationFingerprint': motiveFingerprint(cases)
            .map((f) =>
                {'type': f.label, 'observed': f.helped, 'samples': f.total})
            .toList(),
        'cognitiveFingerprint': cognitiveFingerprint(cases)
            .map((f) =>
                {'operation': f.label, 'helped': f.helped, 'samples': f.total})
            .toList(),
        'tentativePatterns': patterns(cases),
      };
}
