part of 'self_os_workbench.dart';

extension _StrengthPanel on _SelfOsWorkbenchState {
  List<Widget> strengthPanel() => [
        OsSection(
            title: '接受真实结构，改善具体表现',
            subtitle: SelfOsV37Rules.natureAdvice(s),
            children: [
              OsPill(osChangeObjects[s.text('changeObject')] ?? '尚未验证'),
              const SizedBox(height: 12),
              if (s.text('natureEvidence').isNotEmpty)
                text('依据与情境范围：${s.text('natureEvidence')}'),
              Wrap(children: [
                button('先辨别改变的对象', Icons.category_outlined, changeObject),
                ai('寻找与我兼容的改变方式', 'alignment')
              ]),
            ]),
        OsSection(
            title: '力量证据实验室',
            subtitle: '自我认同、问卷、真实行动、反证和过度使用一起保留。三次支持、两个情境与两个案例是当前提示门槛。',
            children: [
              button('记录候选力量', Icons.add, () => editStrength()),
              if (widget.profile.strengths.isEmpty)
                const OsNote('从一个具体行为定义开始，例如“对自己和他人使用相同证据标准”。一次自评只是线索。'),
              for (final strength in widget.profile.strengths)
                strengthCard(strength),
            ]),
        OsSection(
            title: '力量 → 弱点桥接',
            subtitle: '改变作用对象、方向或条件，连接一个具体行为，并为过度使用设置边界。',
            children: [
              for (final b in osMaps(s.settings['bridgeSuggestions']))
                OsNote(
                    '${b['strength']} → ${b['weakness']}\n${b['mechanism']}\n候选动作：${b['action']}\n过度使用护栏：${b['guardrail']}\n依据：${b['evidence']}'),
              if (s.text('bridgeAction').isNotEmpty)
                OsNote(
                    '当前桥接：${s.text('bridgeWeakness')} → ${s.text('bridgeMechanism')} → ${s.text('bridgeAction')}\n护栏：${s.text('bridgeGuardrail')}'),
              button('设计一个可验证的桥接', Icons.merge_type,
                  widget.profile.strengths.isEmpty ? null : bridge),
              if (s.text('bridgeAction').isNotEmpty)
                button('把桥接动作带入行动草稿', Icons.arrow_forward, () async {
                  if (!widget.profile.strengths
                      .any((v) => v.id == s.text('bridgeStrengthId'))) {
                    osMessage(context, '关联的力量已改变，请重新选择后再尝试');
                    return;
                  }
                  try {
                    c.stageStrengthBridge();
                    if (await widget.onChanged() && mounted)
                      widget.onEngine(SelfOsEngine.action);
                  } on FormatException catch (e) {
                    if (mounted) osMessage(context, e.message);
                  }
                }, primary: true),
              const OsNote('已验证力量可以进入现场提示；未验证力量先作为实验候选。使用后在行动之镜记录帮助、无帮助或反作用。'),
            ]),
      ];

  Widget strengthCard(OsStrength strength) {
    final assessment = SelfOsInsights.strength(strength, widget.history);
    return OsRecordCard(
        title: strength.title,
        onEdit: () => editStrength(strength),
        tag: assessment.confidence,
        children: [
          text(strength.text('definition')),
          text(
              '${assessment.supports} 条支持 · ${assessment.counters} 条反证 · ${assessment.contexts} 种情境 · ${assessment.overuse} 次过度使用'),
          if (strength.text('selfReport').isNotEmpty)
            text('自评 / 问卷线索：${strength.text('selfReport')}'),
          if (strength.text('counter').isNotEmpty)
            text('反证与失效条件：${strength.text('counter')}'),
          if (strength.text('overuseGuard').isNotEmpty)
            text('过度使用护栏：${strength.text('overuseGuard')}'),
          if (strength.observations.isNotEmpty)
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('查看实际行动来源'),
                children: [
                  for (final o in strength.observations)
                    text('${o['context'] ?? '行动情境'} · ${{
                          'helped': '有帮助',
                          'notHelped': '没有帮助',
                          'harmed': '产生反作用'
                        }[o['effect']] ?? '未知'}\n${o['observation'] ?? ''}'),
                ]),
          button('关联已有行动证据', Icons.link, () => strengthObservation(strength)),
        ]);
  }

  Future<void> changeObject() async {
    final v = await osRecordEditor(context,
        title: '真正想改变的是什么？',
        initial: s.settings,
        fields: const [
          OsInput('changeObject', '改变对象',
              options: osChangeObjects, required: true),
          OsInput('natureEvidence', '现有证据、反证与适用情境', required: true),
          OsInput('natureTarget', '保留真实目标，具体改善哪一种表现？', required: true),
          OsInput('skillBaseline', '目前已知的技能 / 能力起点'),
          OsInput('natureConflict', '目标是否长期对抗已验证倾向或硬限制？', kind: 'bool'),
        ],
        note: '没有证据的“天生不能”仍属未验证。稳定倾向与具体技能分别处理。');
    if (v != null && mounted) await update((d) => d.settings.addAll(v));
  }

  Future<void> editStrength([OsStrength? strength]) async {
    final v = await osRecordEditor(context,
        title: '记录可验证的力量候选',
        initial: strength?.toJson() ?? {},
        fields: const [
          OsInput('title', '力量名称', required: true),
          OsInput('definition', '怎样的具体行为算使用了它？', required: true),
          OsInput('selfReport', '自我认同 / 问卷来源（只是线索）'),
          OsInput('counter', '什么情境下无效或产生反作用？'),
          OsInput('overuseGuard', '过度使用信号与边界'),
          OsInput('efficacy', '真实使用后的效能感与观察'),
        ]);
    if (v == null || !mounted) return;
    final profile = SelfOsProfile.fromJson(widget.profile.toJson());
    put(profile.strengths, OsStrength(v));
    await widget.onProfile(profile);
  }

  Future<void> strengthObservation(OsStrength strength) async {
    final observations = {
      for (final item in widget.history)
        for (final r in item.reviews) r.id: '${r.context} · ${r.learning}'
    };
    if (observations.isEmpty) {
      osMessage(context, '完成一次真实行动之镜后，再关联力量证据');
      return;
    }
    final v = await osRecordEditor(context, title: '力量实际起了什么作用？', fields: [
      OsInput('reviewId', '真实行动来源', options: observations, required: true),
      const OsInput('effect', '实际作用',
          options: {'helped': '有帮助', 'notHelped': '未观察到帮助', 'harmed': '产生反作用'},
          required: true),
      const OsInput('usage', '使用强度',
          options: {'underuse': '使用不足', 'optimal': '合适使用', 'overuse': '过度使用'},
          required: true),
      const OsInput('observation', '具体如何起作用或失效？', required: true),
    ]);
    if (v == null || !mounted) return;
    final source = widget.history
        .expand((c) => c.reviews)
        .firstWhere((r) => r.id == v['reviewId']);
    final profile = SelfOsProfile.fromJson(widget.profile.toJson());
    final target = profile.strengths.firstWhere((e) => e.id == strength.id);
    final rows = target.observations
      ..removeWhere((o) => o['reviewId'] == v['reviewId']);
    rows.add({
      ...v,
      'context': source.context,
      'recordedAt': DateTime.now().toIso8601String()
    });
    target.data['observations'] = rows;
    await widget.onProfile(profile);
  }

  Future<void> bridge() async {
    final v = await osRecordEditor(context,
        title: '力量怎样支持当前弱点？',
        initial: s.settings,
        fields: [
          OsInput('bridgeStrengthId', '尝试调用的力量',
              options: {
                for (final strength in widget.profile.strengths)
                  strength.id:
                      '${strength.title} · ${SelfOsInsights.strength(strength, widget.history).verified ? '已有实证' : '候选'}'
              },
              required: true),
          const OsInput('bridgeWeakness', '现在的阻碍是什么？', required: true),
          const OsInput('bridgeMechanism', '改变哪个作用对象、方向或条件？', required: true),
          const OsInput('bridgeAction', '具体行为', required: true),
          const OsInput('bridgeGuardrail', '如何防止过度使用？', required: true),
        ]);
    if (v != null && mounted) await update((d) => d.settings.addAll(v));
  }
}
