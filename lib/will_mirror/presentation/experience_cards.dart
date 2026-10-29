import 'package:flutter/material.dart';

import '../domain/model.dart';
import 'design.dart';

/// The same evidence records as the workbench, expressed as a short practical
/// question. Full sources remain one tap away; these cards infer no new facts.
class StrengthOpportunityCard extends StatelessWidget {
  const StrengthOpportunityCard(
      {super.key,
      required this.node,
      required this.resolve,
      required this.onDetails,
      this.onRecord});
  final MirrorNode node;
  final MirrorNode? Function(String) resolve;
  final VoidCallback onDetails;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final route = resolve(node.text('routeId'));
    return _ExperienceCard(
      title: '已有能力，可以怎样用？',
      state: humanValue(node.text('state')),
      summary: node.text('claim'),
      lines: [
        if (route != null) '这项任务：${route.text('title')}',
        for (final id in node.strings('capabilityIds'))
          if (resolve(id) case final capability?)
            '能力出处：${capability.text('description')}',
        for (final id in node.strings('requirementIds'))
          if (resolve(id) case final requirement?)
            '实际要求：${requirement.text('requirement')}',
        for (final id in node.strings('supportVariantIds'))
          if (resolve(id) case final support?)
            '可用支持：${support.text('action')}；需要 ${support.text('prerequisite')}',
      ],
      nextStep: node.text('nextTest'),
      review: '这是当前任务的线索。训练、工具和新兴趣都可以继续检验。',
      blocked: node.text('riskGate') != 'clear',
      onDetails: onDetails,
      onRecord: onRecord,
    );
  }
}

class ChangeabilityCard extends StatelessWidget {
  const ChangeabilityCard(
      {super.key,
      required this.node,
      required this.resolve,
      required this.onDetails,
      this.onRecord});
  final MirrorNode node;
  final MirrorNode? Function(String) resolve;
  final VoidCallback onDetails;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final fact = resolve(node.text('factId'));
    final actions = node.strings('safeAlternatives');
    return _ExperienceCard(
      title: '这件事，还能改变哪一部分？',
      state: humanValue(node.text('classification')),
      summary: node.text('reason'),
      lines: [
        if (fact != null) '针对的事实：${nodeTitle(fact)}',
        '判断时的条件：${node.text('timeReference')}',
        ...node.strings('contextRequirements'),
        ...actions.skip(1),
      ],
      nextStep: actions.firstOrNull ?? node.text('reviewCondition'),
      review: '何时重查：${node.text('reviewCondition')}\n过去的事实与今后的补救分别看，感受也可以保留。',
      onDetails: onDetails,
      onRecord: onRecord,
    );
  }
}

class InterpersonalBoundaryCard extends StatelessWidget {
  const InterpersonalBoundaryCard(
      {super.key, required this.node, required this.onDetails, this.onRecord});
  final MirrorNode node;
  final VoidCallback onDetails;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) => _ExperienceCard(
        title: '我的行动，与对方的选择',
        state: '沟通、义务与边界分别看',
        summary: node.strings('ownActions').isEmpty
            ? '先核实自己能够采取的行动。'
            : '我可以：${node.strings('ownActions').join('；')}',
        lines: [
          for (final item in node.strings('otherAutonomy')) '对方自主决定：$item',
          for (final item in node.strings('verifiedObligations'))
            '已有出处的义务：$item',
          for (final item in node.strings('unknownObligations')) '义务尚待核实：$item',
          ...node.strings('safeOptions'),
        ],
        nextStep: node.text('nextVerification'),
        review: '一次回应不决定他人永远怎样。可以协商边界，也可以选择适当的求助渠道。',
        blocked: node.text('riskGate') == 'blocked',
        onDetails: onDetails,
        onRecord: onRecord,
      );
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard(
      {required this.title,
      required this.state,
      required this.summary,
      required this.lines,
      required this.nextStep,
      required this.review,
      required this.onDetails,
      this.onRecord,
      this.blocked = false});
  final String title, state, summary, nextStep, review;
  final List<String> lines;
  final bool blocked;
  final VoidCallback onDetails;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: MirrorCard(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            MirrorTag(state),
            const SizedBox(height: 10),
            Text(summary),
            if (blocked) ...[
              const SizedBox(height: 8),
              const Text('先核实安全与资格条件，必要时暂停或选择保护性走法。'),
            ],
            const SizedBox(height: 10),
            Text('下一小步：$nextStep'),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('条件、依据与重查时机'),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(line)),
                Text(review),
                TextButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.notes_outlined, size: 17),
                    label: const Text('查看原始出处与反例')),
              ],
            ),
            if (onRecord != null)
              TextButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.edit_note, size: 17),
                  label: const Text('补充尝试或核实后的事实')),
          ]),
        ),
      );
}
