import 'package:flutter/material.dart';

import 'xiangji_models.dart';
import 'xiangji_ui_support.dart';

/// The single user-facing means-ends chain required by the Rev.5.2 Master PRD.
///
/// Internal solver vocabulary deliberately stays out of the default surface.
/// The same view is used in the conversation result and the full problem
/// workspace so a user never has to infer where the actual solver lives.
class XiangjiSolverCockpitView extends StatelessWidget {
  const XiangjiSolverCockpitView({
    super.key,
    required this.problem,
    required this.currentState,
    required this.goal,
    required this.keyGap,
    required this.activeHypothesis,
    required this.subgoal,
    required this.currentAction,
    required this.mechanism,
    required this.prediction,
    this.originalNeed = '',
    this.realityFacts = const <String>[],
    this.epistemicStatus = '',
    this.keyGapReason = '',
    this.actionBoundary = '',
    this.progressLabel = '',
    this.currentFocus = '',
    this.footer,
  });

  final String problem;
  final String currentState;
  final String goal;
  final String keyGap;
  final String activeHypothesis;
  final String subgoal;
  final String currentAction;
  final String mechanism;
  final String prediction;
  final String originalNeed;
  final List<String> realityFacts;
  final String epistemicStatus;
  final String keyGapReason;
  final String actionBoundary;
  final String progressLabel;
  final String currentFocus;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return XiangjiSectionCard(
      title: '军师解题台',
      subtitle: '始终聚焦同一道真实问题：看清现状、找到最大差距、行动，再让现实验算。',
      trailing: progressLabel.trim().isEmpty
          ? null
          : XiangjiStateBadge(label: progressLabel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (originalNeed.trim().isNotEmpty &&
              originalNeed.trim() != problem.trim())
            XiangjiLabeledValue(label: '你最初带来的需要', value: originalNeed),
          XiangjiLabeledValue(label: '这道题', value: problem),
          if (currentFocus.trim().isNotEmpty)
            XiangjiLabeledValue(label: '现在解到哪里', value: currentFocus),
          XiangjiLabeledValue(label: '现在实际处于什么状态', value: currentState),
          if (realityFacts.isNotEmpty)
            XiangjiLabeledValue(
              label: '当前最重要的事实与体验',
              value: realityFacts.take(5).join('；'),
            ),
          XiangjiLabeledValue(label: '希望现实变成什么样', value: goal),
          XiangjiLabeledValue(label: '目前最关键的差距', value: keyGap),
          if (keyGapReason.trim().isNotEmpty)
            XiangjiLabeledValue(label: '为什么先解决它', value: keyGapReason),
          XiangjiLabeledValue(
            label: '军师正在区分的原因',
            value: activeHypothesis,
            empty: '尚未需要区分新的原因',
          ),
          if (epistemicStatus.trim().isNotEmpty)
            XiangjiLabeledValue(label: '当前判断有多稳', value: epistemicStatus),
          XiangjiLabeledValue(label: '先解决哪一小步', value: subgoal),
          XiangjiLabeledValue(label: '当前唯一行动', value: currentAction),
          if (actionBoundary.trim().isNotEmpty)
            XiangjiLabeledValue(label: '时间与边界', value: actionBoundary),
          XiangjiLabeledValue(
            label: '为什么这个办法可能有效',
            value: mechanism,
          ),
          XiangjiLabeledValue(
            label: '如果有效，现实中应该看到什么',
            value: prediction,
          ),
          if (footer != null) ...[
            const SizedBox(height: 2),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Contextual method feedback from the Rev.5.2 experience contract.
///
/// It exposes the trigger and the user-relevant before/after change, while
/// deliberately omitting internal IDs, JSON and solver vocabulary.
class XiangjiMethodEffectCard extends StatelessWidget {
  const XiangjiMethodEffectCard({
    super.key,
    required this.event,
    this.footer,
  });

  final XiangjiMethodEvent event;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final changed = event.changedState;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: changed
          ? const Color(0xFFFFF3DD)
          : const Color(0xFFEAF4EF),
      child: ExpansionTile(
        leading: Icon(
          changed ? Icons.change_circle_outlined : Icons.fact_check_outlined,
          color: changed ? const Color(0xFFC8641B) : XiangjiPalette.pine,
        ),
        title: Text(
          '${changed ? '军师改判' : '本轮已检查'} · ${event.methodLabel}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_userLanguage(event.userVisibleSummary)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          XiangjiLabeledValue(
            label: '什么现实或线索触发了它',
            value: _userLanguage(event.trigger),
          ),
          if (changed) ...[
            XiangjiLabeledValue(
              label: '此前怎样理解',
              value: _stateSummary(event.beforeStateRefs),
            ),
            XiangjiLabeledValue(
              label: '现在怎样理解',
              value: _stateSummary(event.afterStateRefs),
            ),
          ] else
            XiangjiLabeledValue(
              label: '为什么暂时不改',
              value: _userLanguage(event.retainedStateReason),
            ),
          XiangjiLabeledValue(
            label: '怎样改变当前解法',
            value: _userLanguage(event.decisionEffect),
          ),
          XiangjiLabeledValue(
            label: '下一步由什么现实验算',
            value: _userLanguage(event.realityTest),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }

  String _stateSummary(Map<String, Object?> state) {
    final parts = <String>[];
    _addPart(parts, '真问题', state['problem_frame'], const <String>[
      'statement',
      'true_problem',
      'summary',
    ]);
    _addPart(parts, '现实状态', state['current_state'], const <String>[
      'summary',
      'facts',
      'experiences',
    ]);
    _addPart(parts, '现实目标', state['goal_state'], const <String>[
      'statement',
      'goal',
      'success_criteria',
    ]);
    _addHypotheses(parts, state['hypotheses']);
    _addPart(parts, '关键差距', state['key_gap'], const <String>[
      'label',
      'description',
    ]);
    _addPart(parts, '当前小步', state['active_subgoal'], const <String>[
      'label',
      'description',
    ]);
    _addPart(parts, '当前行动', state['active_operator'], const <String>[
      'title',
      'name',
      'summary',
    ]);
    _addPart(parts, '事前预测', state['prediction_ledger'], const <String>[
      'prediction',
      'summary',
    ]);
    _addPart(parts, '认识状态', state['epistemic_profile'], const <String>[
      'epistemic_status',
      'status',
    ]);
    return parts.isEmpty ? '本轮状态已留存，可在完整解题纸中追溯' : parts.join('\n');
  }

  void _addPart(
    List<String> target,
    String label,
    Object? raw,
    List<String> preferredKeys,
  ) {
    if (raw is! Map) return;
    for (final key in preferredKeys) {
      final value = _valueText(raw[key]);
      if (value.isEmpty || value == '{}' || value == '[]') continue;
      target.add('$label：${_userLanguage(value)}');
      return;
    }
  }

  void _addHypotheses(List<String> target, Object? raw) {
    if (raw is! List) return;
    final values = raw
        .whereType<Map>()
        .map(
          (item) => _valueText(
            item['statement'] ?? item['claim'] ?? item['label'],
          ),
        )
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList();
    if (values.isNotEmpty) target.add('正在区分的原因：${values.join('；')}');
  }

  String _valueText(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(5)
          .join('；');
    }
    return raw?.toString().trim() ?? '';
  }

  String _userLanguage(String value) {
    var result = value;
    const replacements = <String, String>{
      'CurrentState S0': '当前现实状态',
      'Goal G': '现实目标',
      'ConceptRealityMismatch': '概念与现实冲突',
      'PredictionLedger': '事前预测记录',
      'RealityResult': '现实结果',
      'ProblemFrame': '真问题定义',
      'KeyGap': '当前关键差距',
      'SubGoal': '当前小步',
      'Operator': '当前办法',
      'Precondition': '生效前提',
      'Hypothesis': '候选原因',
      'Prediction': '事前预测',
      'Execution': '执行',
      'Concept': '当前概念',
      'Judgment': '判断',
      'Goal': '目标',
      'Fact': '事实',
      'S0': '当前状态',
    };
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}
