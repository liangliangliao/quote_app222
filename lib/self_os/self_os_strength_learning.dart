import 'self_os_models.dart';

const osStrengthStages = {
  'cognition': '认识纠错',
  'motivation': '动机形成',
  'action': '行动现场',
};

/// A planned use is not an observed effect. Only explicit feedback tied to a
/// real review can update the strength evidence, once per review/strength.
class SelfOsStrengthLearning {
  static void draftUse(SelfOsCase c, String id, String stage, String detail) {
    if (id.isEmpty || !osStrengthStages.containsKey(stage)) return;
    final uses = osMaps(c.v37.settings['strengthUses'])
      ..removeWhere((u) =>
          u['strengthId'] == id &&
          u['stage'] == stage &&
          u['round'] == c.round);
    uses.add(
        {'strengthId': id, 'stage': stage, 'detail': detail, 'round': c.round});
    c.v37.settings['strengthUses'] = uses;
  }

  static List<Map<String, String>> uses(Map<String, dynamic> snapshot) {
    final result = <String, Map<String, String>>{};
    void add(String id, String stage, String detail) {
      if (id.isEmpty || !osStrengthStages.containsKey(stage)) return;
      result['$id.$stage'] = {
        'key': '$id.$stage',
        'strengthId': id,
        'stage': stage,
        'detail': detail
      };
    }

    final settings = osMap(osMap(snapshot['v37'])['settings']);
    for (final use in osMaps(settings['strengthUses'])) {
      if (use['round'] == snapshot['round']) {
        add(osText(use['strengthId']), osText(use['stage']),
            osText(use['detail']));
      }
    }
    for (final motive in osMaps(snapshot['motives'])) {
      if (motive['selected'] == true)
        add(osText(motive['strengthId']), 'motivation',
            osText(motive['reason']));
    }
    final cue = osText(settings['cueSource']);
    if (cue.startsWith('strength:')) {
      add(cue.substring('strength:'.length), 'action',
          osText(settings['holdCue']));
    }
    final bridge = osMap(settings['actionBridge']);
    add(osText(bridge['strengthId']), 'action', osText(bridge['mechanism']));
    return result.values.toList();
  }

  static bool applyFeedback(SelfOsReview review, SelfOsProfile profile) {
    final feedback = <String, List<Map<String, dynamic>>>{};
    final touched = <String>{};
    for (final use in uses(review.snapshot)) {
      final prefix = 'strength.${use['key']}';
      final effect = review.notes['$prefix.effect'];
      if (review.notes.containsKey('$prefix.effect'))
        touched.add(use['strengthId']!);
      final observation = review.notes['$prefix.observation']?.trim() ?? '';
      if (!['helped', 'notHelped', 'harmed'].contains(effect) ||
          observation.isEmpty) continue;
      feedback.putIfAbsent(use['strengthId']!, () => []).add({
        'stage': use['stage'],
        'effect': effect,
        'usage': review.notes['$prefix.usage'] ?? 'unknown',
        'observation': observation,
      });
    }
    final legacyId = review.notes['strengthId'] ?? '';
    final legacyEffect = review.notes['strengthEffect'];
    if (legacyId.isNotEmpty &&
        !touched.contains(legacyId) &&
        !feedback.containsKey(legacyId) &&
        ['helped', 'notHelped', 'harmed'].contains(legacyEffect)) {
      feedback[legacyId] = [
        {
          'stage': 'reported',
          'effect': legacyEffect,
          'usage': review.notes['strengthUsage'] ?? 'unknown',
          'observation': review.learning
        }
      ];
    }
    var changed = false;
    for (final strength in profile.strengths) {
      final stages = feedback[strength.id];
      if (stages == null || stages.isEmpty) {
        if (touched.contains(strength.id)) {
          strength.data['observations'] = strength.observations
            ..removeWhere((o) => o['reviewId'] == review.id);
          changed = true;
        }
        continue;
      }
      final observations = strength.observations
        ..removeWhere((o) => o['reviewId'] == review.id);
      final effects = stages.map((s) => s['effect']).toSet();
      final usages = stages.map((s) => s['usage']).toSet();
      observations.add({
        'reviewId': review.id,
        'context': review.context,
        'effect': effects.contains('harmed')
            ? 'harmed'
            : effects.contains('helped')
                ? 'helped'
                : 'notHelped',
        'usage': usages.contains('overuse')
            ? 'overuse'
            : usages.contains('optimal')
                ? 'optimal'
                : 'unknown',
        'stageEffects': stages,
        'observation': stages
            .map((s) =>
                '${osStrengthStages[s['stage']] ?? '实际自报'}：${s['observation']}')
            .join('\n'),
        'recordedAt': DateTime.now().toIso8601String(),
      });
      strength.data['observations'] = observations;
      changed = true;
    }
    return changed;
  }
}
