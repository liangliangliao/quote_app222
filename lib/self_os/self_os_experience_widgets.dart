import 'package:flutter/material.dart';
import 'self_os_models.dart';
import 'self_os_principles.dart';
import 'self_os_widgets.dart';
import 'self_os_workbench_widgets.dart';

const osPrincipleFields = <OsInput>[
  OsInput('condition', '如果遇到什么情境？', required: true),
  OsInput('rule', '那么先做什么？（可观察的小动作）', required: true),
  OsInput('notApplicable', '什么情况下不适用？', required: true),
  OsInput('riskGate', '安全、资格或他人同意的门槛', required: true),
  OsInput('exception', '什么新事实会推翻或改变它？', required: true),
  OsInput('nextTest', '下一次怎样检验？', required: true),
];

Future<Map<String, dynamic>?> osCreatePrinciple(
    BuildContext context, List<SelfOsCase> cases,
    {String? currentCaseId, String? initialReviewId}) async {
  final sources =
      SelfOsPrinciples.evidence(cases, currentCaseId: currentCaseId);
  if (sources.isEmpty) {
    osMessage(context, '尚未找到可复用的真实经验。可以先做一次低风险尝试，也可以跳过原则。');
    return null;
  }
  final selected = <String, String>{
    if (initialReviewId != null && sources.containsKey(initialReviewId))
      initialReviewId: 'support',
  };
  final picked = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
                  title: const Text('先看经历，也找找反例'),
                  content: SizedBox(
                      width: 480,
                      child: ListView(shrinkWrap: true, children: [
                        const Text(
                            '经历相似不等于条件相同。选择支持记录，并主动检查不符合的经历；没有反例也可以保留未知。'),
                        for (final e in sources.entries)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${e.value.$1.problem}\n${e.value.$2.context}\n${e.value.$2.result}',
                                        style: const TextStyle(height: 1.5)),
                                    DropdownButton<String>(
                                        isExpanded: true,
                                        value: selected[e.key] ?? 'none',
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'none',
                                              child: Text('不引用 / 情境不可比')),
                                          DropdownMenuItem(
                                              value: 'support',
                                              child: Text('支持这次小方法')),
                                          DropdownMenuItem(
                                              value: 'counter',
                                              child: Text('反例 / 适用条件不同')),
                                        ],
                                        onChanged: (v) =>
                                            set(() => selected[e.key] = v!)),
                                  ])),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('跳过')),
                    FilledButton(
                        onPressed: selected.containsValue('support')
                            ? () => Navigator.pop(ctx, true)
                            : null,
                        child: const Text('已检查，写一条候选')),
                  ])));
  if (picked != true || !context.mounted) return null;
  final support = selected.entries
      .where((e) => e.value == 'support')
      .map((e) => e.key)
      .toList();
  final values = await osRecordEditor(context,
      title: '把经验写成一句可修改的话',
      initial: {
        'condition': sources[support.first]!.$2.context,
        'rule': sources[support.first]!.$2.learning,
        'notApplicable': '情境不再可比，或出现安全、资格、他人同意方面的新限制',
        'riskGate': '先核对本次安全、实际资格和他人同意；有疑问就暂停核实',
        'exception': '实际条件或可用支持改变，或观察到与预期相反的事实',
        'nextTest': '下次分别记录现场是否想起、实际采用的动作与观察结果',
      },
      fields: osPrincipleFields,
      note: '默认是候选。单次经验仅作暂定线索；用户认可也不等于科学验证。可以全部跳过。');
  if (values == null) return null;
  return SelfOsPrinciples.candidate(
      values,
      support,
      selected.entries
          .where((e) => e.value == 'counter')
          .map((e) => e.key)
          .toList(),
      cases,
      currentCaseId: currentCaseId);
}

Future<void> osPrincipleSources(BuildContext context, Map<String, dynamic> p,
    List<SelfOsCase> cases) async {
  final sources = SelfOsPrinciples.evidence(cases);
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
          child: FractionallySizedBox(
              heightFactor: .82,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Text('出处与反例 · v${p['version'] ?? 1}',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 14),
                for (final group in {
                  'evidenceIds': '支持',
                  'counterEvidenceIds': '反例'
                }.entries)
                  for (final id in osStrings(p[group.key]))
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${group.value} · ${sources[id]?.$2.context ?? '来源已撤回或删除'}'),
                        subtitle: Text(sources.containsKey(id)
                            ? '${sources[id]!.$1.problem}\n实做 / 自述：${sources[id]!.$2.result}\n'
                                '新认识：${sources[id]!.$2.learning}\n记录于 ${sources[id]!.$2.createdAt.toLocal()}\nID：$id'
                            : '旧解释已停止使用')),
                Text(osText(p['counterSearch'])),
                const SizedBox(height: 16),
                const Text('不同任务、健康状态、资源与他人参与可能使经历不可比。重复次数不直接证明长期性格。'),
                for (final h in osMaps(p['history']).reversed)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('历史 v${h['version']} · ${h['rule']}'),
                      subtitle:
                          Text('${h['revisionReason']}\n当 ${h['condition']}')),
              ]))));
}

class SelfOsPrincipleLibrary extends StatefulWidget {
  const SelfOsPrincipleLibrary(
      {super.key,
      required this.profile,
      required this.cases,
      required this.onSave});
  final SelfOsProfile profile;
  final List<SelfOsCase> cases;
  final Future<bool> Function(SelfOsProfile) onSave;
  @override
  State<SelfOsPrincipleLibrary> createState() => _SelfOsPrincipleLibraryState();
}

class _SelfOsPrincipleLibraryState extends State<SelfOsPrincipleLibrary> {
  bool _busy = false;
  Future<void> _change(Map<String, dynamic> source,
      void Function(Map<String, dynamic>) edit) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final draft = SelfOsProfile.fromJson(osClone(widget.profile.toJson()));
      edit(draft.principles.firstWhere((p) => p['id'] == source['id']));
      await widget.onSave(draft);
    } on FormatException catch (e) {
      if (mounted) osMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OsSection(
          title: '个人决策宪法',
          subtitle: '个人原则 · 实际适用 · 反例 · 尚待验证。你可以修改、拒绝或归档。',
          children: [
            if (widget.profile.principles.isEmpty)
              const Text('还没有可复用的原则。先保留真实经历，再决定是否提炼；没有原则也能继续。'),
            for (final raw in widget.profile.principles)
              Builder(builder: (context) {
                final p = SelfOsPrinciples.normalize(raw);
                return ExpansionTile(
                    key: ValueKey('principle_${p['id']}'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(osText(p['rule'])),
                    subtitle: Text(
                        '${osPrincipleStatuses[p['status']]} · v${p['version']} · 暂定经验'),
                    children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              '如果：${p['condition']}\n不适用：${p['notApplicable']}\n'
                              '先核对：${p['riskGate']}\n重审：${p['exception']}\n下次检验：${p['nextTest']}',
                              style: const TextStyle(height: 1.7))),
                      Wrap(spacing: 6, children: [
                        TextButton(
                            onPressed: () =>
                                osPrincipleSources(context, p, widget.cases),
                            child: const Text('出处、反例与版本')),
                        if (p['stale'] != true)
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final values = await osRecordEditor(
                                          context,
                                          title: '修订个人原则',
                                          initial: p,
                                          fields: osPrincipleFields,
                                          note: '保存新版本后需重新认可。旧应用保留当时的版本。');
                                      if (values != null)
                                        await _change(
                                            raw,
                                            (draft) => SelfOsPrinciples.revise(
                                                draft, values,
                                                expectedVersion: p['version']));
                                    },
                              child: const Text('修改')),
                        if (p['status'] != 'user_accepted' &&
                            p['stale'] != true)
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _change(
                                      raw,
                                      (draft) => SelfOsPrinciples.setStatus(
                                          draft,
                                          'user_accepted',
                                          widget.cases)),
                              child: const Text('我认可，继续检验')),
                        if (p['status'] != 'user_rejected')
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _change(
                                      raw,
                                      (draft) => SelfOsPrinciples.setStatus(
                                          draft,
                                          'user_rejected',
                                          widget.cases)),
                              child: const Text('不适合我')),
                        if (p['status'] != 'retired')
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _change(
                                      raw,
                                      (draft) => SelfOsPrinciples.setStatus(
                                          draft, 'retired', widget.cases)),
                              child: const Text('归档')),
                      ]),
                    ]);
              }),
          ]);
}

class SelfOsExperienceCard extends StatelessWidget {
  const SelfOsExperienceCard(
      {super.key,
      required this.value,
      required this.profile,
      required this.history,
      required this.onOpen});
  final SelfOsCase value;
  final SelfOsProfile profile;
  final List<SelfOsCase> history;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final apps = SelfOsPrinciples.applications(value)
        .where((a) =>
            a['round'] == value.round &&
            a['stale'] != true &&
            !['cancelled', 'declined'].contains(a['exposureStatus']))
        .toList();
    final usable = SelfOsPrinciples.eligible(profile, history, value);
    return OsSection(title: '我的经验原则', children: [
      Text(apps.isNotEmpty
          ? '本轮：${osMap(apps.last['principleSnapshot'])['rule']}\n'
              '现场：${osPrincipleRecall[apps.last['recallStatus']]} · '
              '采用：${osPrincipleUse[apps.last['applicationStatus']]}'
          : usable.isNotEmpty
              ? '过去的方法也许能帮到这次：${usable.first['rule']}'
              : '从真实经历带走一条可修改的方法。没有可靠经验时，也可以先尝试。'),
      TextButton.icon(
          key: const ValueKey('open_experience'),
          onPressed: onOpen,
          icon: const Icon(Icons.spa_outlined),
          label: Text(value.reviewed ? '回看应用、反例与下一步' : '选一条，核对这次是否适用')),
    ]);
  }
}
