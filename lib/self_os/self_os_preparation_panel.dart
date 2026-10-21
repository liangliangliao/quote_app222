part of 'self_os_workbench.dart';

extension _PreparationPanel on _SelfOsWorkbenchState {
  List<Widget> preparationPanel() => [
        OsSection(
            title: '为未来那一刻做准备',
            subtitle: '复杂信息提前处理；到现场只带一条观念和第一动作。',
            children: [
              Text(osMoment(s.futureMoment),
                  style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: osForest)),
              const SizedBox(height: 12),
              if (s.text('futureDirectTendency').isNotEmpty)
                text('现场可能占据前景：${s.text('futureDirectTendency')}'),
              if (s.text('futureMissingMotive').isNotEmpty)
                text('可能退到背景：${s.text('futureMissingMotive')}'),
              if (s.text('futureConditions').isNotEmpty)
                text('预计条件：${s.text('futureConditions')}'),
              Wrap(children: [
                button('建模未来决策时刻', Icons.event, futureMoment),
                if (s.futureMoment != null) ai('选择最小必要准备', 'prepare'),
                button('手动安排准备动作', Icons.add, () => editIntervention())
              ]),
              if (s.futureMoment == null)
                const OsNote('只有存在明确未来决策 / 行动时刻时，才安排认识准备。普通小事无需填写整套计划。'),
            ]),
        if (s.interventions.isEmpty)
          const OsNote('准备的成功信号是认识、动机可用性或行动预测改变，而不是读了多少内容。'),
        for (final i in s.interventions)
          OsSection(
              title: i.text('task'),
              subtitle:
                  '${osInterventionTypes[i.type]} · ${osPreparationWindows[i.text('window')]} · ${osMoment(i.dueAt(s.futureMoment, DateTime.now()))}',
              trailing: i.started
                  ? null
                  : IconButton(
                      tooltip: '编辑准备动作',
                      onPressed: () => editIntervention(i),
                      icon: const Icon(Icons.edit_outlined)),
              children: [
                text(
                    '针对的缺口：${s.gaps.where((g) => g.id == i.text('gapId')).map((g) => g.text('question')).join()}'),
                text(
                    '来源：${i.text('source')}\n预期变化：${i.text('expectedChange')}'),
                if (i.completed) ...[
                  OsPill(
                      osMap(i.data['gain'])['decisionConditionsChanged'] == true
                          ? '观察到决策条件变化'
                          : '未观察到决策条件变化',
                      color:
                          osMap(i.data['gain'])['decisionConditionsChanged'] ==
                                  true
                              ? osForest
                              : osGold),
                  const SizedBox(height: 8),
                  text('实际观察：${i.text('observation')}'),
                  if (i.flag('late'))
                    const OsNote('完成时已晚于决策时刻，不能记作对这次决定的事前准备。'),
                  text('行动回写：${{
                        'done': '已行动',
                        'partial': '部分行动',
                        'notDone': '未行动'
                      }[i.text('actualOutcome')] ?? '等待真实行动之镜'}'),
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('查看 K / M / Att 前后记录'),
                      children: [
                        text(
                            '之前：${osMap(i.data['before'])['knowledge']}\n之后：${osMap(i.data['after'])['knowledge']}'),
                        text(
                            '动机变化 ${osMaps(osMap(i.data['gain'])['motiveChanges']).length} 项 · 行动预测${osMap(i.data['gain'])['predictionChanged'] == true ? '已变' : '未变或未记录'}'),
                      ]),
                ] else
                  Wrap(children: [
                    if (!i.started)
                      button('开始 · 保存当前认识', Icons.play_arrow, () async {
                        try {
                          c.startIntervention(i);
                          await changed();
                        } on FormatException catch (e) {
                          if (mounted) osMessage(context, e.message);
                        }
                      }, primary: true),
                    if (i.started) ...[
                      button('更新认识与动机', Icons.edit_note, () {
                        section = 1;
                        redraw();
                      }),
                      button('完成 · 记录实际变化', Icons.check,
                          () => finishIntervention(i),
                          primary: true),
                    ],
                  ]),
              ]),
        cueCard(),
      ];

  Future<void> futureMoment() async {
    final v = await osRecordEditor(context,
        title: '未来决策时刻',
        initial: s.settings,
        fields: const [
          OsInput('futureMoment', '预计何时决定 / 行动？',
              kind: 'datetime', required: true),
          OsInput('futureDirectTendency', '届时可能出现什么直接倾向？', required: true),
          OsInput('futureMissingMotive', '什么重要认识或动机可能退到背景？', required: true),
          OsInput('futureConditions', '当时的身体、时间、环境与已知缺口'),
        ],
        validate: (v) => DateTime.tryParse(osText(v['futureMoment']))
                    ?.isAfter(DateTime.now()) !=
                true
            ? '请选择未来时刻；已发生的行动请进入行动之镜'
            : null);
    if (v != null && mounted) await update((d) => d.settings.addAll(v));
  }

  Future<void> editIntervention([OsIntervention? intervention]) async {
    if (s.futureMoment == null) {
      await futureMoment();
      if (!mounted || s.futureMoment == null) return;
    }
    if (s.gaps.isEmpty) {
      osMessage(context, '先记录一个会影响未来决定的具体缺口');
      await editGap();
      if (!mounted || s.gaps.isEmpty) return;
    }
    final v = await osRecordEditor(context,
        title: '最小必要的认识准备',
        initial: intervention?.toJson() ??
            {
              'type': 'reflect',
              'window': 'now',
              'createdAt': DateTime.now().toIso8601String()
            },
        fields: [
          OsInput('gapId', '针对哪一个缺口？',
              options: {for (final g in s.gaps) g.id: g.text('question')},
              required: true),
          const OsInput('type', '准备方式',
              options: osInterventionTypes, required: true),
          const OsInput('task', '具体做什么？完成标准是什么？', required: true),
          const OsInput('source', '信息来源或具体获取办法', required: true),
          const OsInput('window', '什么时候做？',
              options: osPreparationWindows, required: true),
          const OsInput('dueAt', '最晚完成时间（留空按窗口安排）', kind: 'datetime'),
          const OsInput('expectedChange', '预期哪项 K / M / Att 会怎样变化？',
              required: true),
        ], validate: (v) {
      if (v['window'] == 'onsite' && v['type'] != 'rehearse')
        return '复杂知识提前处理，现场只做一条观念的短时预演';
      final i = OsIntervention(v);
      final due = i.dueAt(s.futureMoment, DateTime.now());
      if (due == null || due.isAfter(s.futureMoment!))
        return '准备应安排在还来得及影响决定的时间';
      if (due.isBefore(DateTime.now()) && v['window'] != 'now')
        return '这个窗口已经过去，请改为现在或更晚的可行时点';
      return null;
    });
    if (v != null && mounted)
      await update((d) => put(d.interventions, OsIntervention(v)));
  }

  Future<void> finishIntervention(OsIntervention i) async {
    final v = await osRecordEditor(context,
        title: '这次准备实际改变了什么？',
        fields: const [
          OsInput('observation', '实际观察：认识、动机、注意或预测的变化；没有也如实记录', required: true)
        ],
        note: '先在工作台更新实际认识与动机，再记录完成。只阅读完成而没有条件变化，不计为有决策增益。');
    if (v == null || !mounted) return;
    try {
      c.completeIntervention(i, osText(v['observation']));
      await changed();
    } on FormatException catch (e) {
      if (mounted) osMessage(context, e.message);
    }
  }
}
