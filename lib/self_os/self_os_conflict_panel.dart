part of 'self_os_workbench.dart';

extension _ConflictPanel on _SelfOsWorkbenchState {
  List<Widget> conflictPanel() {
    final map = c.motives.map((m) => m.toJson()).toList();
    final conflict = SelfOsV37Rules.conflict(s, map);
    final mode = SelfOsV37Rules.jamesMode(s);
    final breaks = SelfOsV37Rules.attentionBreaks(map);
    return [
      OsSection(
          title: '${SelfOsV37Rules.conflictLabels[conflict]}',
          subtitle: SelfOsV37Rules.conflictAdvice[conflict],
          children: [
            const OsNote('分类依据：已选动机、关联路径、重要度与互斥关系。重要度 ≥60 是当前产品提示阈值，不是人格测量。'),
            Wrap(children: [
              button('添加动机到舞台', Icons.add, () => editStageMotive()),
              button('搜索更完整的正反动机', Icons.search,
                  () => widget.onEngine(SelfOsEngine.motivation))
            ]),
          ]),
      OsSection(
          title: '此刻，谁占据前景？',
          subtitle: '长期重要度与当下注意占有分开记录。把背景动机带回来，同时保留反方的真实价值。',
          children: [
            for (final stage in osAttentionStages.entries)
              Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: stage.key == 'foreground'
                          ? const Color(0xFFE3EBDC)
                          : osPaper,
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(stage.value,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          OsPill(
                              '${c.motives.where((m) => m.selected && m.attention == stage.key).length} 项')
                        ]),
                        const SizedBox(height: 8),
                        if (!c.motives
                            .any((m) => m.selected && m.attention == stage.key))
                          text(stage.key == 'omitted'
                              ? '还有什么重要后果未进入考虑？'
                              : '这里暂未记录动机'),
                        for (final m in c.motives.where(
                            (m) => m.selected && m.attention == stage.key))
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                  m.side == 'for'
                                      ? Icons.add_circle_outline
                                      : Icons.remove_circle_outline,
                                  color: m.side == 'for' ? osForest : osGold),
                              title: Text(m.title),
                              subtitle: Text(
                                  '${routeNames[m.optionId] ?? '尚未关联路径'} · ${osHorizons[m.horizon]}\n重要 ${m.importance?.round() ?? '未知'} · 注意 ${m.occupancy?.round() ?? '未知'} · ${osEndorsement[m.endorsement]}'),
                              isThreeLine: true,
                              onTap: () => editStageMotive(m)),
                      ])),
            if (breaks.isNotEmpty)
              OsNote(
                  '知道但没接上行动：${breaks.map((m) => m['title']).join('、')}。可以提高现场可用性，或连接一个具体动作。',
                  icon: Icons.link_off),
            if (c.motives.any((m) => !m.selected))
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('未选入的候选与原有反方'),
                  children: [
                    for (final m in c.motives.where((m) => !m.selected))
                      ListTile(
                          title: Text(m.title),
                          subtitle:
                              Text(m.side == 'against' ? '反方 · 保留' : '正方 · 候选'),
                          onTap: () => editStageMotive(m)),
                  ]),
          ]),
      OsSection(
          title: '这一次，犹豫怎样结束？',
          subtitle:
              '${osJamesModes[mode]} · ${mode == 'unknown' ? '决定尚未形成或证据不足' : s.text('decisionConfidence').isEmpty ? '过程置信度待记录' : s.text('decisionConfidence')}',
          children: [
            if (s.text('decisionEvidence').isNotEmpty)
              text(s.text('decisionEvidence')),
            text(SelfOsV37Rules.stopAdvice(s)),
            Wrap(children: [
              button('记录决意过程', Icons.psychology_outlined, decisionProcess),
              button('承认舍弃与机会成本', Icons.balance, sacrifice)
            ]),
            if (s.flag('sacrificeAccepted'))
              OsNote(
                  '我选择让一条路成为现实，同时承认「${s.text('sacrificedValue')}」仍有价值。\n愿意接受：${s.text('opportunityCost')}'),
            if (s.text('reviewAt').isNotEmpty)
              text('约定复审：${osMoment(DateTime.tryParse(s.text('reviewAt')))}'),
            if (widget.profile.principles.isNotEmpty)
              ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('调用已经认可的个人原则'),
                  children: [
                    for (final p in widget.profile.principles)
                      OsRecordCard(title: osText(p['rule']), children: [
                        text(
                            '适用：${p['condition']}\n不适用：${p['doesNotApply'] ?? '待补充'}\n覆盖旧原则的新证据：${p['overrideEvidence'] ?? p['exception']}'),
                        TextButton(
                            onPressed: () => update(
                                (d) => d.settings['principleId'] = p['id']),
                            child: Text(s.text('principleId') == p['id']
                                ? '已用于本次比较'
                                : '将这条原则用于本次比较')),
                      ]),
                  ]),
          ]),
      cueCard(),
      button('带着选择设计行动现场', Icons.arrow_forward,
          () => widget.onEngine(SelfOsEngine.action),
          primary: true),
    ];
  }

  Future<void> editStageMotive([SelfOsMotive? motive]) async {
    final v = await osRecordEditor(context,
        title: '动机 · 重要度与在场度',
        initial: motive?.toJson() ??
            {
              'selected': true,
              'side': 'for',
              'attention': 'midground',
              'endorsement': 'known',
              'horizon': 'now',
              'kind': '概率推断',
              'type': '长期目标'
            },
        fields: [
          const OsInput('title', '具体动机', required: true),
          const OsInput('side', '方向',
              options: {'for': '趋近 / 支持这条路径', 'against': '回避 / 反对这条路径'},
              required: true),
          OsInput('optionId', '关联哪条路径？', options: routeNames, required: true),
          const OsInput('desireId', '服务的欲求 / 欲求证据'),
          const OsInput('reason', '因果机制与可信依据', required: true),
          const OsInput('kind', '认识性质',
              options: {'事实': '有来源事实', '概率推断': '概率推断', '想象模拟': '想象模拟'}),
          const OsInput('horizon', '时间距离', options: osHorizons, required: true),
          const OsInput('attention', '此刻的位置',
              options: osAttentionStages, required: true),
          const OsInput('importance', '长期 / 当前相关重要度（0–100）', kind: 'number'),
          const OsInput('occupancy', '此刻注意占有（0–100）', kind: 'number'),
          const OsInput('credibility', '可信度（0–100）', kind: 'number'),
          const OsInput('vividness', '鲜明度（0–100）', kind: 'number'),
          const OsInput('endorsement', '我认可到哪一步？',
              options: osEndorsement, required: true),
          const OsInput('actionLink', '它具体连接哪个动作？'),
          const OsInput('selected', '把它选入当前动机场', kind: 'bool'),
        ],
        note: '反方保留原有价值。重要但想不起、知道但未连接动作，都可以单独调整。');
    if (v == null || !mounted) return;
    final next = SelfOsMotive.fromJson({...v, 'source': '用户确认 / 修订'});
    final index = c.motives.indexWhere((m) => m.id == next.id);
    if (index < 0) {
      c.motives.add(next);
    } else {
      c.motives[index] = next;
    }
    await changed();
  }

  Future<void> decisionProcess() async {
    final v = await osRecordEditor(context,
        title: '只描述这一次决意',
        initial: s.settings,
        fields: const [
          OsInput('decisionStage', '决定目前处于哪个阶段？',
              options: {
                'deliberating': '仍在犹豫，尚不能分类',
                'near': '临近决定',
                'decided': '已经形成决定',
                'reviewed': '行动后回看'
              },
              required: true),
          OsInput('jamesMode', '最接近的过程特征',
              options: osJamesModes, required: true),
          OsInput('decisionEvidence', '本次过程证据：什么真正结束了犹豫？', required: true),
          OsInput('decisionConfidence', '对这次过程解释的置信度', options: {
            '低': '低 · 线索有限',
            '中': '中 · 有具体过程证据',
            '高': '高 · 多项本次证据一致'
          }),
          OsInput('externalTrigger', '是否有电话、他人的话、偶然机会推动？'),
          OsInput('valueShift', '什么价值突然变得更重要？持续性仍待观察'),
          OsInput('deliberationCycles', '同一证据已反复比较多少轮？', kind: 'number'),
          OsInput('informationGain', '最近一次比较新增了什么？',
              options: {'new': '有关键新信息', 'little': '少量新信息', 'none': '没有新增信息'}),
          OsInput('reviewAt', '不再重复比较，何时根据新证据复审？', kind: 'datetime'),
          OsInput('cooledAndReviewed', '重大决定已在冷却后重新核对证据和代价', kind: 'bool'),
        ]);
    if (v != null && mounted) await update((d) => d.settings.addAll(v));
  }

  Future<void> sacrifice() async {
    final v = await osRecordEditor(context,
        title: '承认被舍弃的真实价值',
        initial: s.settings,
        fields: const [
          OsInput('sacrificedValue', '落选的未来仍有什么真实价值？', required: true),
          OsInput('opportunityCost', '让当前选择成为现实，我会失去 / 延期什么？', required: true),
          OsInput('sacrificeAccepted', '我承认它的价值，并愿意接受这笔机会成本', kind: 'bool'),
          OsInput('sacrificeReview', '什么新证据出现时重新比较？', required: true),
        ]);
    if (v != null && mounted) await update((d) => d.settings.addAll(v));
  }

  Map<String, String> cueSources() => {
        for (final m in c.motives.where((m) =>
            m.selected &&
            ['valued', 'available', 'linked'].contains(m.endorsement) &&
            (m.credibility ?? 0) >= 60 &&
            m.reason.trim().isNotEmpty))
          'motive:${m.id}': '认可的动机 · ${m.title}',
        for (final strength in widget.profile.strengths.where((strength) =>
            SelfOsInsights.strength(strength, widget.history).verified))
          'strength:${strength.id}': '已验证力量 · ${strength.title}',
      };

  Widget cueCard() => OsSection(
          title: '现场，只带上一条观念',
          subtitle: '从你认可且可信的动机，或已有实证的力量中选择。短时保持后立刻接第一动作。',
          children: [
            if (s.text('holdCue').isNotEmpty)
              Text('“${s.text('holdCue')}”',
                  style: const TextStyle(
                      fontSize: 21, height: 1.6, fontWeight: FontWeight.w600)),
            if (s.text('holdCue').isNotEmpty)
              text(
                  '→ ${c.text('firstAction').isEmpty ? '第一动作仍待确认' : c.text('firstAction')}'),
            if (cueSources().isEmpty)
              const OsNote('先在意识舞台选择认可且有依据的动机，或积累力量证据。也可以直接执行已经确认的第一动作。'),
            Wrap(children: [
              button('选择 / 替换关键观念', Icons.center_focus_strong,
                  cueSources().isEmpty ? null : editCue),
              if (s.text('holdCue').isNotEmpty)
                button(
                    '这次不用提示',
                    Icons.close,
                    () => update((d) {
                          d.settings.remove('holdCue');
                          d.settings.remove('cueSource');
                        }))
            ]),
          ]);

  Future<void> editCue() async {
    final v = await osRecordEditor(context,
        title: '观念 → 第一动作',
        initial: {...s.settings, 'firstAction': c.text('firstAction')},
        fields: [
          OsInput('cueSource', '可信且认可的依据',
              required: true, options: cueSources()),
          const OsInput('holdCue', '现场只保留的一条短观念', required: true),
          const OsInput('firstAction', '保持后立刻做什么？', required: true),
          const OsInput('holdSeconds', '保持时长',
              options: {'10': '10 秒', '15': '15 秒', '20': '20 秒'},
              required: true),
        ],
        validate: (v) => osText(v['holdCue']).runes.length > 100
            ? '请缩短为 100 字以内的一条观念'
            : null,
        note: '可以拒绝或替换。提示是否有用，要在真实行动之后记录。力量提示与关键观念不会同时堆叠。');
    if (v == null || !mounted) return;
    c.fields['firstAction'] = osText(v['firstAction']);
    await update((d) => d.settings.addAll(v));
  }
}
