import 'self_os_models.dart';
import 'self_os_v37_rules.dart';

/// A user's interpretation of an actual observation. Predictions, observations
/// and conclusions retain separate identities and timestamps throughout.
class SelfOsLearning {
  static const verdicts = {
    'supported': '在这次情境里，预期得到支持',
    'weakened': '实际情况使原来的预期站不住了',
    'mixed': '有支持，也有不符合的地方',
    'uncertain': '观察还不足以判断',
    'unobserved': '这次没有得到对应的观察',
  };
  static const influences = {
    'toward': '更愿意尝试想接近的方向',
    'protect': '更重视原来想保护的东西',
    'unchanged': '暂不改变选择，保留这条认识',
  };

  static bool calibrated(SelfOsReview review) =>
      review.notes['calibrationId']?.isNotEmpty == true;

  static void calibrate(
    SelfOsCase c, {
    required String reviewId,
    required String verdict,
    required String conclusion,
    required String scope,
    required String influence,
    bool resolveGap = false,
    bool conflictsChecked = false,
  }) {
    final review = c.reviews
        .where((r) => r.id == reviewId && r.round == c.round)
        .firstOrNull;
    if (review == null || calibrated(review)) {
      throw const FormatException('只能校准本轮尚未确认的真实反馈，原来的校准记录会保留');
    }
    if (!verdicts.containsKey(verdict) ||
        !influences.containsKey(influence) ||
        conclusion.trim().isEmpty ||
        scope.trim().isEmpty) {
      throw const FormatException('请确认预期与实际的关系、新认识及其适用范围');
    }
    if (review.outcome == 'notDone' && verdict != 'unobserved') {
      throw const FormatException('没有进行这次行动，不能把想象的结果用来支持或否定预期');
    }
    final experiment = osMap(review.snapshot['experiment']);
    final gap =
        c.v37.gaps.where((g) => g.id == experiment['gapId']).firstOrNull;
    final conclusive = ['supported', 'weakened', 'mixed'].contains(verdict);
    if (resolveGap &&
        (!conclusive ||
            !conflictsChecked ||
            gap == null ||
            gap.text('access') == 'public' ||
            gap.text('question') != osText(experiment['question']))) {
      throw const FormatException(
          '只有实际回答了原问题、检查冲突并限定范围，才能关闭本次经验缺口；公共事实请核验原始来源');
    }
    final node =
        c.v37.nodes.where((n) => n.id == experiment['nodeId']).firstOrNull;
    final beforeNode = node?.toJson();
    final before = osClone(c.cognitiveSnapshot());
    final id = selfOsId(), now = DateTime.now().toIso8601String();
    var evidence = c.v37.evidence
        .where((e) => e.text('reviewId') == review.id)
        .firstOrNull;
    evidence ??= OsEvidence({
      'claim': review.result,
      'quote': review.result,
      'label': 'personal',
      'source': '本人第 ${review.round} 轮实际复盘 · ${review.id}',
      'observedAt': review.createdAt.toIso8601String(),
      'reviewId': review.id,
      'verified': true,
      'contradiction': 'unknown',
    });
    if (!c.v37.evidence.any((e) => e.id == evidence!.id))
      c.v37.evidence.add(evidence);
    // Checking the observation's source does not verify the hypothesis.
    if (conflictsChecked) evidence.data['contradiction'] = 'clear';
    evidence.data['scope'] = scope.trim();
    review.notes.addAll({
      'calibrationId': id,
      'calibrationVerdict': verdict,
      'calibrationConclusion': conclusion.trim(),
      'calibrationScope': scope.trim(),
      'calibrationInfluence': influence,
      'calibratedAt': now,
      'calibrationEvidenceId': evidence.id,
      'cognitionFeedback': 'user_calibrated',
    });
    c.beginCognition();
    c.fields['k2'] = conclusion.trim();
    c.fields['k3'] = conclusion.trim();
    c.fields['knowledgeSource'] =
        '第 ${review.round} 轮实际反馈，由本人校准 · ${review.id}';
    if (influence != 'unchanged') {
      for (final m
          in c.motives.where((m) => m.id.startsWith('guide_${c.id}_'))) {
        m.attention = (influence == 'toward' && m.side == 'for') ||
                (influence == 'protect' && m.side == 'against')
            ? 'foreground'
            : 'midground';
      }
    }
    c.completeCognition(
        '实际反馈 ${review.id}：${verdicts[verdict]}。${influences[influence]}。适用范围：${scope.trim()}',
        noChangeReason: '这次没有进一步改变已选动机的强弱或现场可用性，保留上述现实认识。');
    c.v37.knowledgeTraces.last.addAll({
      'reviewId': review.id,
      'evidenceIds': [evidence.id]
    });
    if (gap != null) {
      // Every observation is discoverable; only explicit sufficient answers
      // enter the set of evidence that can resolve this particular question.
      gap.data['observationIds'] =
          {...gap.strings('observationIds'), evidence.id}.toList();
      if (resolveGap) {
        gap.data.addAll({
          'evidenceIds': {...gap.strings('evidenceIds'), evidence.id}.toList(),
          'resolutionConfirmed': true,
          'resolutionAnswer': conclusion.trim(),
          'resolutionScope': scope.trim(),
          'resolutionReviewId': review.id,
          'resolutionAt': now,
        });
      }
    }
    if (node != null && verdict != 'unobserved') {
      final observation = {
        'reviewId': review.id,
        'evidenceId': evidence.id,
        'verdict': verdict,
        'result': review.result,
        'scope': scope.trim(),
        'at': now,
      };
      node.data.addAll({
        'observedOutcome': review.result,
        'observedAt': review.createdAt.toIso8601String(),
        'observations': [...osMaps(node.data['observations']), observation],
        if (verdict == 'weakened' || verdict == 'mixed')
          'calibrationNeedsReview': true,
      });
      c.v37.causalTraces.add({
        'id': id,
        'kind': 'actual_calibration',
        'reviewId': review.id,
        'evidenceId': evidence.id,
        'before': beforeNode,
        'after': node.toJson(),
        'at': now,
      });
      if (node.flag('calibrationNeedsReview')) {
        for (final option
            in c.v37.futureOptions.where((o) => o.text('nodeId') == node.id)) {
          option.data['needsReview'] = true;
        }
      }
    }
    for (final i in c.v37.interventions
        .where((i) => i.text('reviewId') == review.id && i.started)) {
      final after = c.cognitiveSnapshot();
      i.data.addAll({
        'feedbackAfter': after,
        'gain': SelfOsV37Rules.interventionGain(osMap(i.data['before']), after),
        'calibrationId': id,
      });
    }
    c.v37.decisionTraces.add({
      'id': id,
      'kind': 'calibration',
      'reviewId': review.id,
      'evidenceId': evidence.id,
      'before': before,
      'after': c.cognitiveSnapshot(),
      'verdict': verdict,
      'conclusion': conclusion.trim(),
      'scope': scope.trim(),
      'createdAt': now,
    });
    c.guide.draft.remove('calibrationDraft');
  }

  /// Apply a user-edited motive, not the AI's label "strengthened/weakened".
  /// The eventual K/M/Att delta is computed from actual before/after values.
  static void reviewMotive(SelfOsCase c, Map<String, dynamic> suggestion,
      SelfOsMotive reviewed, String reason) {
    if (reason.trim().isEmpty ||
        reviewed.title.trim().isEmpty ||
        !['for', 'against'].contains(reviewed.side) ||
        (reviewed.optionId.isNotEmpty &&
            !c.v37.routes.any((r) => r.id == reviewed.optionId))) {
      throw const FormatException('请记录你认可的动机、所属路径和实际调整依据');
    }
    final expectedId = osText(suggestion['motiveId']);
    if (expectedId.isNotEmpty && expectedId != reviewed.id) {
      throw const FormatException('动机标识已改变，请重新校准');
    }
    c.beginCognition();
    reviewed.reason = reason.trim();
    reviewed.source = '本人校准的认识变化';
    final index = c.motives.indexWhere((m) => m.id == reviewed.id);
    if (index < 0) {
      c.motives.add(reviewed);
    } else {
      c.motives[index] = reviewed;
    }
    suggestion.addAll({
      'reviewStatus': 'reviewed',
      'reviewedMotiveId': reviewed.id,
      'reviewReason': reason.trim(),
      'reviewedAt': DateTime.now().toIso8601String()
    });
  }

  static List<Map<String, dynamic>> history(List<SelfOsCase> cases) => [
        for (final c in cases)
          for (final r in c.reviews.where(calibrated))
            {
              'caseId': c.id,
              'reviewId': r.id,
              'problem': c.problem,
              'prediction':
                  osText(osMap(r.snapshot['experiment'])['prediction']),
              'actual': r.result,
              'context': r.context,
              'verdict': r.notes['calibrationVerdict'],
              'conclusion': r.notes['calibrationConclusion'],
              'scope': r.notes['calibrationScope'],
              'at': r.notes['calibratedAt']
            }
      ]..sort((a, b) => osText(b['at']).compareTo(osText(a['at'])));
}
