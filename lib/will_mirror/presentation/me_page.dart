import 'package:flutter/material.dart';
import '../application/controller.dart';
import '../domain/model.dart';
import 'design.dart';
import 'sheets.dart';
import 'visuals.dart';
import 'workbench.dart';

class MirrorMePage extends StatefulWidget {
  const MirrorMePage({super.key, required this.controller});
  final MirrorController controller;
  @override
  State<MirrorMePage> createState() => _MirrorMePageState();
}

class _MirrorMePageState extends State<MirrorMePage> {
  String? _domain;
  bool _possibilities = false;
  int _view = 0;
  MirrorController get c => widget.controller;
  void _details(MirrorNode n) => showNodeDetails(context, c, n);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final all = c.files
            .expand((f) => NodeKind.values
                .expand((kind) => f.current(kind, allEpisodes: true)))
            .toList();
        final domains = all
            .where((n) => n.kind == NodeKind.observation)
            .expand((n) => n.strings('domains'))
            .toSet();
        final caseIds = c.files
            .where((f) =>
                _domain == null ||
                f
                    .current(NodeKind.observation, allEpisodes: true)
                    .any((n) => n.strings('domains').contains(_domain)))
            .map((f) => f.id)
            .toSet();
        final actual = all
            .where((n) =>
                caseIds.contains(n.caseId) &&
                {NodeKind.observation, NodeKind.experience}.contains(n.kind) &&
                n.isFact)
            .toList();
        final walked = all
            .where((n) =>
                {NodeKind.observation, NodeKind.attempt}.contains(n.kind))
            .map((n) => n.text('routeId'))
            .toSet();
        final events = [
          ...actual,
          if (_possibilities)
            ...all.where((n) =>
                caseIds.contains(n.caseId) &&
                n.kind == NodeKind.route &&
                !walked.contains(n.id))
        ]..sort((a, b) => (a.happenedAt ?? a.recordedAt)
            .compareTo(b.happenedAt ?? b.recordedAt));
        final insights = all
            .where(
                (n) => caseIds.contains(n.caseId) && n.kind == NodeKind.insight)
            .toList();
        final principles = all
            .where((n) =>
                caseIds.contains(n.caseId) &&
                n.kind == NodeKind.principle &&
                !all.any((later) => later.revisionOf == n.id))
            .toList();
        return ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            children: [
              Text('沿着经历，\n一点点认识自己。',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 12),
              const Text('曲折是时间中的不同选择。上下位置没有优劣含义，也不决定你是什么样的人。'),
              const SizedBox(height: 20),
              SegmentedButton<int>(segments: const [
                ButtonSegment(value: 0, label: Text('人生折线')),
                ButtonSegment(value: 1, label: Text('经验认识')),
                ButtonSegment(value: 2, label: Text('个人原则'))
              ], selected: {
                _view
              }, onSelectionChanged: (s) => setState(() => _view = s.first)),
              const SizedBox(height: 16),
              if (domains.isNotEmpty)
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ChoiceChip(
                      label: const Text('全部领域'),
                      selected: _domain == null,
                      onSelected: (_) => setState(() => _domain = null)),
                  for (final domain in domains)
                    ChoiceChip(
                        label: Text(domain),
                        selected: _domain == domain,
                        onSelected: (_) => setState(() => _domain = domain))
                ]),
              const SizedBox(height: 12),
              if (_view == 0) ...[
                SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('也看看未走过的可能'),
                    subtitle: const Text('实线是实际经历，虚线是保留的路线'),
                    value: _possibilities,
                    onChanged: (v) => setState(() => _possibilities = v)),
                if (events.isEmpty)
                  const MirrorEmpty(
                      title: '还没有足够的实际经历',
                      body: '先把一个具体课题走下去。提醒、预演和准备不会自动成为行动证据。')
                else
                  LifeZigzag(events: events, onNode: _details),
                const SizedBox(height: 18),
                for (final relation in all.where((n) =>
                    n.kind == NodeKind.manifestation &&
                    caseIds.contains(n.caseId)))
                  _relation(relation),
              ],
              if (_view == 1) ...[
                if (insights.isEmpty)
                  const MirrorEmpty(
                      title: '先保留未知',
                      body: '完成真实反馈后，可以在课题工作台提炼有适用条件的经验。没有证据时不会生成性格标签。'),
                for (final insight in insights) _insight(insight),
              ],
              if (_view == 2) ...[
                const Text('原则是可以修订的做法。每次应用单独记录，旧版本与当时的结果仍会保留。'),
                const SizedBox(height: 14),
                if (principles.isEmpty)
                  const MirrorEmpty(
                      title: '从自己的证据长出原则',
                      body: '回望一段真实经历后，最多提出 3 条候选，默认先审议 1 条。你可以修改、不适用、稍后或跳过。'),
                for (final principle in principles) _principle(principle),
                ExpansionTile(title: const Text('已归档、否定或待复核的原则'), children: [
                  for (final n in c.files
                      .expand((f) => f.nodes)
                      .where((n) => n.kind == NodeKind.principle && !n.usable))
                    ListTile(
                        title: Text(nodeTitle(n)),
                        subtitle: Text(statusLabel(n.status)),
                        onTap: () => _details(n))
                ]),
              ],
            ]);
      });
  Widget _insight(MirrorNode n) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MirrorCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MirrorTag(humanValue(n.text('maturity'))),
        const SizedBox(height: 12),
        Text(n.text('claim'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Text('目前适用：${n.strings('contexts').join('；')}'),
        Text('还有其他解释：${n.strings('alternativeExplanations').join('；')}'),
        Text('什么会推翻它：${n.text('falsifier')}'),
        Text('下次检验：${n.text('nextTest')}'),
        Wrap(spacing: 5, children: [
          TextButton(onPressed: () => _details(n), child: const Text('证据与反例')),
          TextButton(
              onPressed: () => _feedback(n, 'accept'),
              child: const Text('目前认可')),
          TextButton(onPressed: () => _counter(n), child: const Text('补充反例')),
          TextButton(
              onPressed: () => _feedback(n, 'reject'),
              child: const Text('不符合我'))
        ]),
      ])));
  Widget _relation(MirrorNode n) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MirrorCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MirrorTag(humanValue(n.text('relation'))),
        const SizedBox(height: 10),
        Text(n.text('claim')),
        const SizedBox(height: 8),
        Text('其他解释：${n.strings('alternatives').join('；')}'),
        Wrap(children: [
          TextButton(onPressed: () => _details(n), child: const Text('查看相关经历')),
          TextButton(
              onPressed: () => _feedback(n, 'independent'),
              child: const Text('保留为独立经历'))
        ]),
      ])));
  Widget _principle(MirrorNode n) {
    final applications = c.files
        .expand((f) => f.nodes)
        .where((a) =>
            a.kind == NodeKind.principleApplication &&
            a.text('principleId') == n.id &&
            a.usable)
        .toList();
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: MirrorCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MirrorTag(statusLabel(n.status)),
          const SizedBox(height: 12),
          Text(n.text('summary'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text('如果 ${n.text('ifCondition')}，\n就先 ${n.text('thenAction')}。'),
          const SizedBox(height: 10),
          Text('例外：${n.text('exceptionRule')}'),
          Text('仍需检验：${n.text('nextTest')}'),
          Wrap(spacing: 6, children: [
            if (n.status != NodeStatus.accepted)
              TextButton(
                  onPressed: () => _feedback(n, 'accept'),
                  child: const Text('认可这条原则')),
            TextButton(onPressed: () => _edit(n), child: const Text('修订')),
            TextButton(onPressed: () => _counter(n), child: const Text('补充反例')),
            TextButton(
                onPressed: () => _feedback(n, 'not_applicable'),
                child: const Text('不适用')),
            TextButton(
                onPressed: () => _feedback(n, 'retire'),
                child: const Text('归档'))
          ]),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('出处与 ${applications.length} 条应用记录'),
              children: [
                ListTile(
                    title: const Text('原始证据、反证和版本'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _details(n)),
                for (final a in applications)
                  ListTile(
                      title: Text(
                          '${phaseLabel(a.phase)} · ${humanValue(a.text('exposure'))}'),
                      subtitle: Text(
                          '想起：${humanValue(a.text('recall'))}\n采用：${humanValue(a.text('application'))}\n${a.text('detail')}'),
                      onTap: () => _details(a)),
              ]),
          TextButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => CaseWorkbench(
                          controller: c, caseId: n.caseId, initialStep: 6))),
              icon: const Icon(Icons.arrow_forward, size: 17),
              label: const Text('回到这条经验的课题')),
        ])));
  }

  Future<void> _feedback(MirrorNode n, String action) =>
      runUiAction(context, () => c.feedback(n.caseId, n.id, action));
  Future<void> _counter(MirrorNode n) async {
    final value = await askText(context, title: '记录一个不一样的实际经历', questions: [
      const TextQuestion('text', '什么情境下，发生了什么不同的事？', required: true, lines: 3)
    ]);
    if (value != null && mounted)
      await runUiAction(context,
          () => c.addEvidence(n.caseId, value['text']!, category: 'counter'));
  }

  Future<void> _edit(MirrorNode n) async {
    final value = await askText(context, title: '修订自己的条件性原则', questions: [
      TextQuestion('ifCondition', '什么条件下？',
          initial: n.text('ifCondition'), required: true),
      TextQuestion('thenAction', '先做什么？',
          initial: n.text('thenAction'), required: true),
      TextQuestion('exceptionRule', '什么时候不适用？',
          initial: n.text('exceptionRule'), required: true),
      TextQuestion('falsifier', '什么证据会使你重新考虑？',
          initial: n.text('falsifier'), required: true)
    ]);
    if (value != null && mounted)
      await runUiAction(
          context,
          () => c.recordNode(
              n.caseId,
              NodeKind.principle,
              {
                ...n.body,
                ...value,
                'summary': '${value['ifCondition']}时，${value['thenAction']}',
                'maturity': 'tentative'
              },
              evidenceIds: n.evidenceIds,
              counterIds: n.counterIds,
              links: [n.id],
              revisionOf: n.id));
  }
}
