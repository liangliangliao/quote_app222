import 'self_os_models.dart';

const osChangeability = {
  'irreversible_past': '过去已发生 · 仍可补救',
  'modifiable_now': '现在可以行动',
  'modifiable_with_support': '得到支持后再尝试',
  'hard_limit_for_task': '本任务有已核实的限制',
  'externally_dependent': '也取决于他人或制度',
  'uncertain': '还不能判断 · 先核实',
};
const osTaskFit = {
  'demonstrated_strength': '有实做支持的优势',
  'trainable_gap': '当前差距 · 可训练验证',
  'fit_with_support': '有工具或协作才可行',
  'variable_state': '暂时状态 · 需要复测',
  'task_mismatch': '当前任务条件不匹配',
  'unknown': '未知 · 可以低风险探索',
};

class SelfOsReality {
  static List<Map<String, dynamic>> currentAssessments(SelfOsCase c) {
    final latest = <String, Map<String, dynamic>>{};
    for (final a in osMaps(c.v37.settings['changeabilityAssessments'])) {
      latest[osText(a['factId']).isEmpty
          ? osText(a['id'])
          : osText(a['factId'])] = a;
    }
    return latest.values.toList();
  }

  static bool hasSafetyConcern(String text) =>
      RegExp(r'暴力|虐待|胁迫|强迫|剥削|歧视|威胁|伤害|殴打|家暴|性骚扰|自杀|自残').hasMatch(text);

  static Map<String, dynamic> assess(SelfOsCase c, Map<String, dynamic> input,
      {DateTime? at}) {
    final now = at ?? DateTime.now();
    final fact = osText(input['fact']).trim();
    final task = osText(input['task']).trim();
    final next = osText(input['nextAction']).trim();
    if (fact.isEmpty || task.isEmpty || next.isEmpty)
      throw const FormatException('请写明具体事实、当前任务和一个下一步');
    final ids = osStrings(input['evidenceIds']);
    final available = {
      for (final e in c.v37.evidence.where((e) => e.reliableAt(now))) e.id,
      for (final r in c.reviews)
        if (r.notes['experienceWithdrawn'] != 'yes' &&
            !r.createdAt.isAfter(now))
          r.id,
    };
    if (ids.any((id) => !available.contains(id)))
      throw const FormatException('依据须来自本案例仍有效的事实或实做记录');
    var classification = osChangeability.containsKey(input['classification'])
        ? osText(input['classification'])
        : 'uncertain';
    final safety = input['safetyConcern'] == true ||
        hasSafetyConcern('$fact $task $next ${c.problem}');
    if (ids.isEmpty || osText(input['reason']).trim().isEmpty)
      classification = 'uncertain';
    final happenedAt = DateTime.tryParse(osText(input['happenedAt']));
    if (classification == 'irreversible_past' &&
        (happenedAt == null || happenedAt.isAfter(now)))
      classification = 'uncertain';
    if (classification == 'hard_limit_for_task' &&
        !c.v37.evidence.any((e) => ids.contains(e.id) && e.reliableAt(now)))
      classification = 'uncertain';
    if (classification == 'modifiable_with_support' &&
        osText(input['support']).trim().isEmpty)
      throw const FormatException('请写明需要的工具、训练、协作或资源');
    final routeId = osText(input['routeId']);
    if (routeId.isNotEmpty && !c.v37.routes.any((r) => r.id == routeId))
      throw const FormatException('关联路线已改变，请重新选择');
    return {
      ...osClone(input),
      'id': selfOsId(),
      'caseId': c.id,
      'routeId': routeId,
      'factId': osText(input['factId']).isEmpty ? selfOsId() : input['factId'],
      'version': input['version'] is int ? (input['version'] as int) + 1 : 1,
      'safetyReviewRequired': false,
      'stale': false,
      'classification': classification,
      'sourceEvidenceIds': ids,
      'timeReference': now.toIso8601String(),
      'reviewAt': osText(input['reviewAt']),
      'safetyConcern': safety,
      'safeAlternatives': safety
          ? ['先保护安全，暂停危险安排', '向可信的人或适当专业机构求助', '按具体情况保存证据、投诉、寻求合法救济或安全离开']
          : [next],
      'acceptanceBoundary': '已发生的事实与仍可补救的责任分开；允许悲伤、愤怒和争取权利。',
      'counterfactualBoundary': '当时若换一种做法会怎样仍不确定，不能由结果倒推原因。',
    };
  }

  static List<Map<String, dynamic>> opportunities(
          List<SelfOsCase> cases, SelfOsCase current) =>
      [
        for (final c in cases)
          if (c.id == current.id || c.v37.flag('shareExperience'))
            for (final r in c.reviews)
              if (r.notes['experienceWithdrawn'] != 'yes' &&
                  ['done', 'partial'].contains(r.outcome) &&
                  [
                    'strength',
                    'trainable',
                    'misfit',
                    'limit',
                    'variable',
                    'support'
                  ].contains(r.notes['capability']))
                {
                  'caseId': c.id,
                  'evidenceId': r.id,
                  'task': c.problem,
                  'context': r.context,
                  'performance': r.result,
                  'classification': const {
                    'strength': 'demonstrated_strength',
                    'trainable': 'trainable_gap',
                    'misfit': 'task_mismatch',
                    // A self report is not verified permanent incapacity.
                    'limit': 'unknown',
                    'variable': 'variable_state',
                    'support': 'fit_with_support',
                  }[r.notes['capability']],
                  'nextStep': '先核对本次任务要求与条件，再用一次低成本尝试检验能否迁移；安全和资格先行。',
                },
      ];
}
