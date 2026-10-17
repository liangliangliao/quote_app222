import 'package:flutter/material.dart';

import '../domain/model.dart';
import '../domain/workbench_projection.dart';
import 'design.dart';

/// These are projections of the existing ledger, not another collection of
/// answers. Every selectable claim opens its original source node.
class CaseJourneyHeader extends StatelessWidget {
  const CaseJourneyHeader({
    super.key,
    required this.file,
    required this.step,
    required this.onStep,
  });
  final CaseFile file;
  final int step;
  final ValueChanged<int> onStep;
  static const labels = ['理解处境', '正反理由', '新的认识', '可行走法', '准备', '现场', '回望'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('一件事，一次看清一步', style: theme.textTheme.labelLarge),
            ),
            Text('${step + 1} / 7', style: theme.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < labels.length; i++)
              ChoiceChip(
                key: ValueKey('mirror-step-$i'),
                label: Text(labels[i]),
                selected: i == step,
                onSelected: (_) => onStep(i),
                showCheckmark: false,
                avatar: i == step
                    ? const Icon(Icons.near_me_outlined, size: 16)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class CaseSituationCard extends StatelessWidget {
  const CaseSituationCard({
    super.key,
    required this.file,
    required this.onNode,
    required this.onAdd,
  });
  final CaseFile file;
  final ValueChanged<MirrorNode> onNode;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final u = file.latest(NodeKind.understanding);
    if (u == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final beliefs = file.current(NodeKind.belief);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EvidenceLane(
          label: '你描述的事实与体验',
          icon: Icons.format_quote,
          children: [
            for (final fact in u.objects('facts'))
              _SourceLine(
                text: fact['claim'] as String,
                caption: '来自你的原话',
                onTap: () => onNode(u),
              ),
          ],
        ),
        if (beliefs.isNotEmpty) ...[
          const SizedBox(height: 10),
          _EvidenceLane(
            label: '当时的认识，仍可检验',
            icon: Icons.psychology_outlined,
            children: [
              for (final b in beliefs.take(3))
                _SourceLine(
                  text: b.text('claim'),
                  caption:
                      '${humanValue(b.text('realityStatus'))} · ${sourceLabel(b.origin)}',
                  onTap: () => onNode(b),
                ),
            ],
          ),
        ],
        if (u.strings('unknowns').isNotEmpty) ...[
          const SizedBox(height: 10),
          _EvidenceLane(
            label: '会影响判断的未知',
            icon: Icons.help_outline,
            children: [
              for (final unknown in u.strings('unknowns').take(3))
                _SourceLine(text: unknown, caption: '尚待核实', onTap: onAdd),
            ],
          ),
        ],
        if (u.text('keyQuestion').isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('先核实这一件事', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(u.text('keyQuestion'), style: theme.textTheme.titleSmall),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_comment_outlined, size: 17),
              label: const Text('补充答案，也可以稍后'),
            ),
          ),
        ],
      ],
    );
  }
}

class _EvidenceLane extends StatelessWidget {
  const _EvidenceLane({
    required this.label,
    required this.icon,
    required this.children,
  });
  final String label;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => MirrorCard(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.labelLarge),
                ),
              ],
            ),
            ...children,
          ],
        ),
      );
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({
    required this.text,
    required this.caption,
    required this.onTap,
  });
  final String text, caption;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              const SizedBox(height: 2),
              Text('$caption  ›', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class MotiveConflictPanel extends StatefulWidget {
  const MotiveConflictPanel({
    super.key,
    required this.file,
    required this.onNode,
  });
  final CaseFile file;
  final ValueChanged<MirrorNode> onNode;
  @override
  State<MotiveConflictPanel> createState() => _MotiveConflictPanelState();
}

class _MotiveConflictPanelState extends State<MotiveConflictPanel> {
  String? _routeId;
  @override
  Widget build(BuildContext context) {
    final routes = widget.file.current(NodeKind.route);
    if (routes.isEmpty) return const SizedBox.shrink();
    final route = routes.where((r) => r.id == _routeId).firstOrNull ??
        routes.where((r) => r.id == widget.file.selectedRouteId).firstOrNull ??
        routes.first;
    final reasons = RouteReasons.forRoute(widget.file, route);
    final theme = Theme.of(context);
    return MirrorCard(
      key: const ValueKey('mirror-conflict-lens'),
      color: theme.colorScheme.primaryContainer.withValues(alpha: .32),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('同一条路，为什么会犹豫？', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('选一条走法，看见把你拉向两边的候选理由。', style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < routes.length; i++)
                ChoiceChip(
                  label: Text('走法 ${i + 1}'),
                  selected: route.id == routes[i].id,
                  onSelected: (_) => setState(() => _routeId = routes[i].id),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(route.text('title'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final panels = [
                _side(context, '让我愿意靠近', Icons.arrow_forward, reasons.support),
                _side(
                  context,
                  '让我想停下或换路',
                  Icons.pause_circle_outline,
                  reasons.opposition,
                ),
              ];
              if (constraints.maxWidth < 285 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21)
                return Column(
                  children: [panels[0], const SizedBox(height: 10), panels[1]],
                );
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: panels[0]),
                    const SizedBox(width: 10),
                    Expanded(child: panels[1]),
                  ],
                ),
              );
            },
          ),
          if (reasons.conditional.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('取决于条件：${reasons.conditional.first.text('summary')}'),
          ],
          const SizedBox(height: 10),
          Text('两边的理由都值得核实；数量与位置不代表强弱或行动概率。', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _side(
    BuildContext context,
    String label,
    IconData icon,
    List<MirrorNode> motives,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.labelLarge),
          if (motives.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('尚无有来源的理由，不补造反方。'),
            ),
          for (final m in motives.take(2))
            _SourceLine(
              text: m.text('summary'),
              caption: '${humanValue(m.text('horizon'))} · 候选',
              onTap: () => widget.onNode(m),
            ),
        ],
      ),
    );
  }
}

class RecognitionBridge extends StatelessWidget {
  const RecognitionBridge({
    super.key,
    required this.file,
    required this.reframe,
    required this.onNode,
  });
  final CaseFile file;
  final MirrorNode reframe;
  final ValueChanged<MirrorNode> onNode;

  @override
  Widget build(BuildContext context) {
    final change = EvidenceChange.from(file, reframe);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statement(
          context,
          '原来这样理解',
          change.belief?.text('claim') ?? '原认识来源待复核',
          false,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.south, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('补入这项认识', style: theme.textTheme.labelLarge),
              ),
            ],
          ),
        ),
        _statement(context, '更完整的可能解释', reframe.text('newClaim'), true),
        const SizedBox(height: 14),
        Text('为什么可能改变选择', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(reframe.text('mechanism')),
        if (change.motives.isNotEmpty || change.routes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('它具体连到哪里', style: theme.textTheme.labelLarge),
          for (final n in [...change.motives.take(2), ...change.routes.take(2)])
            TextButton.icon(
              onPressed: () => onNode(n),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
              ),
              icon: Icon(
                n.kind == NodeKind.motive
                    ? Icons.lightbulb_outline
                    : Icons.alt_route,
                size: 17,
              ),
              label: Text(nodeTitle(n)),
            ),
        ],
        const SizedBox(height: 12),
        MirrorCard(
          color: theme.colorScheme.surfaceContainer,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('用现实检验，而不是强迫相信', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(reframe.text('test')),
            ],
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('原判断何时仍成立？什么会推翻新解释？'),
          children: [
            Text('原判断仍可能成立：${reframe.text('oldMayBeRight')}'),
            const SizedBox(height: 8),
            Text('新解释的反证：${reframe.text('falsifier')}'),
            if (reframe.strings('unknowns').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('还不知道：${reframe.strings('unknowns').join('；')}'),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ],
    );
  }

  Widget _statement(
    BuildContext context,
    String label,
    String text,
    bool proposed,
  ) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: proposed
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: .5)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(text, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}

class RouteTradeoffCard extends StatelessWidget {
  const RouteTradeoffCard({
    super.key,
    required this.file,
    required this.route,
    required this.index,
    required this.safe,
    required this.onSelect,
    required this.onDetails,
  });
  final CaseFile file;
  final MirrorNode route;
  final int index;
  final bool safe;
  final VoidCallback onSelect, onDetails;

  @override
  Widget build(BuildContext context) {
    final fit = file
        .current(NodeKind.routeFit)
        .where((n) => n.text('routeId') == route.id)
        .lastOrNull;
    final selected = file.selectedRouteId == route.id;
    final theme = Theme.of(context);
    final reasons = RouteReasons.forRoute(file, route);
    String effects(String horizon) {
      final rows = fit
              ?.objects('matrix')
              .where((row) => row['horizon'] == horizon)
              .take(2)
              .toList() ??
          [];
      return rows.isEmpty
          ? '尚未形成有依据的判断'
          : rows
              .map(
                (r) => '${humanValue(r['effect'] as String)}：${r['reason']}',
              )
              .join('\n');
    }

    return Container(
      key: ValueKey('mirror-route-${route.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MirrorTag('走法 ${index + 1}', icon: Icons.alt_route),
              if (selected)
                const MirrorTag('本人已选', icon: Icons.check_circle_outline),
              MirrorTag(safe ? '当前可准备' : '先核实条件', icon: Icons.shield_outlined),
            ],
          ),
          const SizedBox(height: 12),
          Text(route.text('title'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('先做：${route.text('firstStep')}'),
          const SizedBox(height: 14),
          _EvidenceLane(
            label: '眼前的得失',
            icon: Icons.today_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(effects('now')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _EvidenceLane(
            label: '更长时间的得失',
            icon: Icons.update,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(effects('long')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MirrorTag(
                '欲求：${fit == null ? '待核实' : humanValue(fit.text('wantFit'))}',
              ),
              MirrorTag(
                '难度：${fit?.number('difficulty') ?? '未知'}${fit?.number('difficulty') == null ? '' : '/5'}',
              ),
              MirrorTag(
                '能力：${fit == null ? '待核实' : humanValue(fit.text('bodySkillFit'))}',
              ),
              MirrorTag(
                '外部：${humanValue(fit?.text('externalFeasibility') ?? route.text('feasibility'))}',
              ),
            ],
          ),
          if (reasons.support.isNotEmpty || reasons.opposition.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('这条路的支持、反方与条件'),
              children: [
                if (reasons.support.isNotEmpty)
                  Text('支持：${reasons.support.first.text('summary')}'),
                if (reasons.opposition.isNotEmpty)
                  Text('反方：${reasons.opposition.first.text('summary')}'),
                if (route.strings('conditions').isNotEmpty)
                  Text('前提：${route.strings('conditions').join('；')}'),
                Text('需要核实：${route.text('verify')}'),
              ],
            ),
          TextButton.icon(
            onPressed: onDetails,
            icon: const Icon(Icons.notes_outlined, size: 17),
            label: const Text('完整依据、限制与替代支持'),
          ),
          FilledButton.tonal(
            onPressed: safe ? onSelect : null,
            child: Text(
              selected
                  ? '已选这条走法'
                  : safe
                      ? '选择这条走法'
                      : '先核实限制或选择保护性路线',
            ),
          ),
        ],
      ),
    );
  }
}

class RealityEvidenceTrace extends StatelessWidget {
  const RealityEvidenceTrace({
    super.key,
    required this.file,
    required this.onNode,
  });
  final CaseFile file;
  final ValueChanged<MirrorNode> onNode;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('从计划到现实，分别留下证据', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          for (final row in realityTrace(file))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    row.source == null
                        ? Icons.radio_button_unchecked
                        : Icons.article_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap:
                          row.source == null ? null : () => onNode(row.source!),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(row.text),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}
