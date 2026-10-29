import 'self_os_codec.dart';

const osAttemptStates = {
  'unknown': '尚不清楚',
  'not_started': '没有开始尝试',
  'started_blocked': '已经尝试，途中受阻',
  'completed': '完成了本次行动',
  'revised_on_new_information': '根据新信息合理改道',
};
const osOpportunityStates = {
  'unknown': '是否有真实机会还不清楚',
  'present': '当时有可行的实际选择机会',
  'absent': '当时没有相应的可行机会',
};
const osAutonomyStates = {
  'unknown': '自主条件还不清楚',
  'voluntary': '在已知条件下自主选择',
  'coerced': '受到强迫或缺少实际选择',
};
const osTargetStates = {
  'unknown': '还不清楚 / 待观察',
  'not_acquired': '尚未获得目标',
  'acquired': '确实获得了目标',
  'practiced': '已真实体验对应的日常过程',
};

class SelfOsActionFacts {
  static Map<String, String> normalize(Map<String, String> notes) {
    final normalized = <String, String>{
      'attemptStatus': osAttemptStates.containsKey(notes['attemptStatus'])
          ? notes['attemptStatus']!
          : 'unknown',
      'opportunity': osOpportunityStates.containsKey(notes['opportunity'])
          ? notes['opportunity']!
          : 'unknown',
      'autonomy': osAutonomyStates.containsKey(notes['autonomy'])
          ? notes['autonomy']!
          : 'unknown',
      'targetStatus': osTargetStates.containsKey(notes['targetStatus'])
          ? notes['targetStatus']!
          : 'unknown',
      'preparation': notes['preparation'] ?? '',
      'alternativeExplanations': notes['alternativeExplanations'] ?? '',
      'realizedExperience': notes['realizedExperience'] ?? '',
      'ongoingBurden': notes['ongoingBurden'] ?? '',
      'actionEvidenceKind': 'user_self_report',
      'experienceCausality': 'unknown',
    };
    if (!['acquired', 'practiced'].contains(normalized['targetStatus']) &&
        (normalized['realizedExperience']!.trim().isNotEmpty ||
            normalized['ongoingBurden']!.trim().isNotEmpty))
      throw const FormatException('尚未真实获得或实践时，不能记录获得后的满意与持续负担；可把预期保留在事前记录。');
    if (normalized['opportunity'] != 'present' ||
        normalized['autonomy'] != 'voluntary')
      normalized['evidenceUse'] = 'contextOnly';
    return normalized;
  }

  static bool mayGeneralize(Map<String, String> notes) =>
      notes['experienceWithdrawn'] != 'yes' &&
      notes['evidenceUse'] == 'usable' &&
      notes['opportunity'] == 'present' &&
      notes['autonomy'] == 'voluntary';

  static Map<String, String> forAnalysis(Map<String, String> notes) => {
        for (final k in [
          'attemptStatus',
          'opportunity',
          'autonomy',
          'targetStatus',
          'preparation',
          'alternativeExplanations',
          'realizedExperience',
          'ongoingBurden'
        ])
          if (osText(notes[k]).isNotEmpty) k: notes[k]!,
      };
}
