part of 'workbench.dart';

extension _ActionViews on _CaseWorkbenchState {
  Widget _preparation() {
    final route = f.node(f.selectedRouteId),
        preflight = f.latest(NodeKind.preflight),
        scene = f.latest(NodeKind.scene),
        plan = f.latest(NodeKind.plan);
    if (route != null && !EvidenceRules.routeCanBePrepared(route, f)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('先重新核实这条走法。'),
          const Text('新的认识或现实条件可能改变了原判断。旧记录仍可回看，先确认得失、限制与安全条件，再安排下一步。'),
          _primary('重新比较路线与条件', _busy ? null : () => _continue(3)),
        ],
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('给未来加入一个\n真实能改变的条件。', '预案是一份准备。真正到了现场，你仍然可以重新判断。'),
      if (route == null) ...[
        const Text('先选一条你愿意考虑、并符合现实门槛的路线。'),
        _primary('回到路线比较', () => _go(3))
      ] else ...[
        MirrorTag(route.text('title'),
            icon: Icons.route_outlined, emphasis: true),
        const SizedBox(height: 14),
        if (preflight == null) ...[
          const Text('可以让 AI 从已认可的理由和条件中整理准备，也可以直接写下自己的预案。'),
          OutlinedButton.icon(
              onPressed: _busy ? null : () => _analyze(AnalysisStage.prepare),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('整理具体的准备与备用方案')),
        ] else ...[
          Text('目前的基线', style: Theme.of(context).textTheme.labelLarge),
          Text(preflight.text('baseline')),
          const SizedBox(height: 12),
          Text('改变条件后的可能性', style: Theme.of(context).textTheme.labelLarge),
          Text(preflight.text('possibleWithChanges')),
          _sourceLink(preflight),
          for (final intervention in f
              .current(NodeKind.intervention)
              .where((n) => n.text('routeId') == route.id))
            _intervention(intervention),
        ],
        const Divider(),
        _principleCard(),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: const Text('让认可的理由更容易在现场想起'),
            subtitle: const Text('可选预演 · 也可以全程只看事实'),
            children: [
              const Text('未来画面只是预演。事实、可能障碍与应对会分别标明。'),
              const SizedBox(height: 12),
              if (scene != null) _sceneCard(scene),
              if (f.selectedMotiveIds.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('先在理由中选出 1–3 条你认可的线索，才能生成个人预演。')),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final entry in const {
                  'facts': '事实卡',
                  'future': '未来片段',
                  'future_obstacle': '未来与障碍',
                  'process': '未来、障碍与应对',
                  'verify_first': '先核实／换路线'
                }.entries)
                  ActionChip(
                      label: Text(entry.value),
                      onPressed: _busy || f.selectedMotiveIds.isEmpty
                          ? null
                          : () => _analyze(AnalysisStage.scene,
                              {'requestedMode': entry.key}))
              ]),
            ]),
        if (plan != null) ...[
          const SizedBox(height: 14),
          const MirrorTag('已有一份条件性预案', icon: Icons.lock_outline),
          const SizedBox(height: 10),
          Text(plan.text('ifThen')),
          _sourceLink(plan, label: '查看这份预案及版本')
        ],
        _primary(
            plan == null ? '保存准备，等待真实时刻' : '修订预案，保留原来版本', _busy ? null : _seal,
            icon: Icons.bookmark_outline),
        if (plan != null)
          TextButton(onPressed: () => _go(5), child: const Text('查看等待与现场卡')),
      ],
    ]);
  }

  Widget _intervention(MirrorNode intervention) {
    final done = f
        .current(NodeKind.interventionExecution)
        .where((n) => n.text('interventionId') == intervention.id)
        .toList();
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: MirrorCard(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.all(15),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(intervention.text('action'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text('需要：${intervention.text('cost')}'),
              Text('实施证据：${intervention.text('implementationEvidence')}'),
              if (done.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: MirrorTag(
                        '实际反馈：${humanValue(done.last.text('state'))}')),
              Wrap(spacing: 5, children: [
                FilterChip(
                    label: Text(intervention.status == NodeStatus.accepted
                        ? '已加入准备'
                        : '愿意安排这项准备'),
                    selected: intervention.status == NodeStatus.accepted,
                    onSelected: (v) => _act(() => c.feedback(
                        f.id, intervention.id, v ? 'accept' : 'later'))),
                TextButton(
                    onPressed: () => _recordPreparation(intervention),
                    child: const Text('记录实际实施'))
              ]),
              _sourceLink(intervention, label: '机制、风险与备用方式'),
            ])));
  }

  Future<void> _recordPreparation(MirrorNode intervention) async {
    final state = await chooseOption(context, title: '这项准备实际怎样了？', options: {
      'executed': '我确实做了',
      'partly_executed': '做了一部分',
      'not_executed': '我没有实施',
      'unknown': '现在还不知道'
    });
    if (state == null || !mounted) return;
    final detail = await askText(context, title: '只记录真实发生的部分', questions: [
      TextQuestion('detail', '实际做了什么（未知可以留空）',
          initial: state == 'executed' ? intervention.text('action') : '')
    ]);
    if (detail == null) return;
    final at =
        state == 'unknown' || !mounted ? null : await pickMoment(context);
    await _act(() => c.recordNode(
        f.id,
        NodeKind.interventionExecution,
        {
          'interventionId': intervention.id,
          'state': state,
          'detail': detail['detail']
        },
        happenedAt: at));
  }

  Widget _sceneCard(MirrorNode scene) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          MirrorTag(humanValue(scene.text('mode'))),
          MirrorTag(statusLabel(scene.status))
        ]),
        const SizedBox(height: 10),
        for (final frame in scene.objects('frames'))
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MirrorTag(humanValue(frame['claimType'] as String),
                        icon: frame['claimType'] == 'fact'
                            ? Icons.fact_check_outlined
                            : Icons.cloud_outlined),
                    const SizedBox(height: 6),
                    Text(frame['text'] as String)
                  ])),
        Text('现场的一句话：${scene.text('fieldCue')}',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          OutlinedButton.icon(
              onPressed: () => _playScene(scene),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('开始可跳过的预演')),
          TextButton(
              onPressed: () => _sceneFeedback(scene, 'approved'),
              child: const Text('内容准确，认可这份提示')),
          TextButton(
              onPressed: () => _sceneFeedback(scene, 'inaccurate'),
              child: const Text('不准确')),
          TextButton(
              onPressed: () => _sceneFeedback(scene, 'too_strong'),
              child: const Text('感受太强，改看事实')),
          TextButton(
              onPressed: () => _editScene(scene), child: const Text('修改文字'))
        ]),
        _sourceLink(scene, label: '查看预演来源与条件'),
      ]);
  Future<void> _sceneFeedback(MirrorNode scene, String response) async {
    await _act(() async {
      await c.recordNode(f.id, NodeKind.sceneFeedback,
          {'sceneId': scene.id, 'response': response, 'comment': ''});
      await c.feedback(
          f.id, scene.id, response == 'approved' ? 'accept' : 'reject');
    });
  }

  Future<void> _editScene(MirrorNode scene) async {
    final questions = [
      for (var i = 0; i < scene.objects('frames').length; i++)
        TextQuestion('frame$i',
            '${i + 1} · ${humanValue(scene.objects('frames')[i]['claimType'] as String)}',
            initial: scene.objects('frames')[i]['text'] as String,
            required: true),
      TextQuestion('cue', '20 秒内的现场短提示',
          initial: scene.text('fieldCue'), required: true)
    ];
    final result = await askText(context,
        title: '修改自己的预演',
        questions: questions,
        explanation: '修改后的未来想象仍是想象，不会变成已经发生的事实。');
    if (result == null) return;
    if (result['cue']!.runes.length > 95) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('现场短提示请控制在 95 字以内')));
      return;
    }
    await _act(() => c.recordNode(
        f.id,
        NodeKind.scene,
        {
          ...scene.body,
          'fieldCue': result['cue'],
          'frames': [
            for (var i = 0; i < scene.objects('frames').length; i++)
              {
                ...scene.objects('frames')[i], 'text': result['frame$i'],
                // An edited assertion is no longer a verbatim verified scene claim.
                'claimType': scene.objects('frames')[i]['claimType'] == 'fact'
                    ? 'plausible'
                    : scene.objects('frames')[i]['claimType']
              },
          ]
        },
        evidenceIds: scene.evidenceIds,
        links: [scene.id],
        revisionOf: scene.id));
  }

  Future<void> _playScene(MirrorNode scene) async {
    var duration = scene.number('durationSeconds')?.toInt() ?? 45;
    var voice = c.preferences.sound;
    _checkScene();
    _rehearsing = true;
    await mirrorSheet<void>(context,
        title: '按自己的节奏预演',
        child: StatefulBuilder(
            builder: (sheetContext, setState) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 30, label: Text('30 秒')),
                            ButtonSegment(value: 60, label: Text('60 秒')),
                            ButtonSegment(value: 90, label: Text('90 秒'))
                          ],
                          selected: {
                            duration <= 30
                                ? 30
                                : duration <= 60
                                    ? 60
                                    : 90
                          },
                          onSelectionChanged: (v) =>
                              setState(() => duration = v.first)),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('本次用语音朗读'),
                          value: voice,
                          onChanged: (v) => setState(() => voice = v)),
                      const Text('不需要努力说服自己。留意真实阻力、可做的一步，以及可以安全退出的条件。'),
                      const SizedBox(height: 14),
                      FilledButton(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            if (!mounted) return;
                            if (voice) {
                              await _tts.setLanguage('zh-CN');
                              await _tts.setSpeechRate(.43);
                              await _tts.speak(scene
                                  .objects('frames')
                                  .map((e) => e['text'])
                                  .join('。'));
                            }
                            if (!mounted) return;
                            await mirrorSheet<void>(context,
                                title: '未来画面 ≠ 实际结果',
                                child: SceneRehearsal(
                                    scene: scene,
                                    duration: duration,
                                    animate: c.preferences.animations,
                                    onStop: () => _tts.stop()));
                            _rehearsing = false;
                            await _tts.stop();
                          },
                          child: const Text('开始（随时可以跳过）')),
                    ])));
  }

  Future<void> _seal() async {
    final route = f.node(f.selectedRouteId);
    if (route == null) return;
    final preflight = f.latest(NodeKind.preflight),
        existing = f.latest(NodeKind.plan);
    final signal = TextEditingController(
        text: existing?.text('triggerSignal') ??
            preflight?.text('triggerSignal') ??
            '');
    final ifThen = TextEditingController(
        text: existing?.text('ifThen') ??
            (preflight == null
                ? route.text('firstStep')
                : '如果 ${preflight.text('triggerSignal')}，先核实条件，再考虑${route.text('firstStep')}'));
    final fallback = TextEditingController(
        text: existing?.text('fallback') ??
            preflight?.text('fallback') ??
            '条件变化时，先暂停核实，再决定是否改道。');
    final forecast = TextEditingController(
        text: existing?.text('forecast') ?? preflight?.text('forecast') ?? '');
    var prediction = true, remind = false;
    DateTime? at;
    final key = GlobalKey<FormState>();
    await mirrorSheet<void>(context,
        title: '为真正到来的时刻留一份预案',
        child: StatefulBuilder(
            builder: (sheetContext, setState) => Form(
                key: key,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(route.text('title'),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: signal,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              labelText: '什么实际条件出现时？',
                              hintText: '写可观察的信号；到时间不代表外部事件已发生'),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? '请写下需要核实的条件' : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: ifThen,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              labelText: '如果条件允许，我愿先做什么？'),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? '请留下一个具体的第一步' : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: fallback,
                          minLines: 2,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: '条件变了，我可以怎样调整？'),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? '请保留一个备用或暂停方式' : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: forecast,
                          minLines: 2,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: '当时的预测（可以不填）')),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('封存这一刻的认识与预测'),
                          subtitle: const Text('今后的修改另存版本，真实结果不会回填到这里'),
                          value: prediction,
                          onChanged: (v) => setState(() => prediction = v)),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('设置一次可选提醒'),
                          subtitle: const Text('锁屏只显示中性提示；没有提醒也能使用现场卡'),
                          value: remind,
                          onChanged: (v) => setState(() => remind = v)),
                      if (remind) ...[
                        OutlinedButton.icon(
                            onPressed: () async {
                              final chosen = await pickMoment(sheetContext,
                                  future: true,
                                  initial: DateTime.now()
                                      .add(const Duration(hours: 1)));
                              if (chosen != null) setState(() => at = chosen);
                            },
                            icon: const Icon(Icons.schedule),
                            label: Text(at == null ? '选择提醒时间' : timeLabel(at))),
                        const SizedBox(height: 8),
                        const Text('系统省电、关机或强行停止应用可能延迟提醒。这里不会把未回应记作失败。')
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                          onPressed: () async {
                            if (!key.currentState!.validate()) return;
                            if (remind &&
                                (at == null || !at!.isAfter(DateTime.now()))) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(content: Text('请选择将来的提醒时间')));
                              return;
                            }
                            final scene = f
                                .current(NodeKind.scene)
                                .where((n) =>
                                    n.status == NodeStatus.accepted &&
                                    n.text('routeId') == route.id)
                                .toList();
                            final application =
                                f.latest(NodeKind.principleApplication);
                            await _act(() => c.seal(
                                f.id,
                                {
                                  'routeId': route.id,
                                  'motiveIds': f.selectedMotiveIds,
                                  'sceneId':
                                      scene.isEmpty ? null : scene.last.id,
                                  'principleId':
                                      application?.text('exposure') ==
                                              'accepted'
                                          ? application?.text('principleId')
                                          : null,
                                  'triggerSignal': signal.text.trim(),
                                  'verifyFirst':
                                      preflight?.strings('verifyFirst') ??
                                          route.strings('conditions'),
                                  'ifThen': ifThen.text.trim(),
                                  'fallback': fallback.text.trim(),
                                  'safetyException':
                                      preflight?.text('safetyException') ??
                                          '新风险或前提不符时先暂停核实',
                                  'forecast': forecast.text.trim(),
                                  'interventionIds': f
                                      .current(NodeKind.intervention)
                                      .where((n) =>
                                          n.status == NodeStatus.accepted)
                                      .map((n) => n.id)
                                      .toList(),
                                  'intention': 'conditional',
                                  'remindAt': remind
                                      ? at?.toUtc().toIso8601String()
                                      : null,
                                  'expiresAt': null,
                                  'userConfirmed': true
                                },
                                prediction: prediction,
                                reminderPermission: remind));
                            if (sheetContext.mounted)
                              Navigator.pop(sheetContext);
                          },
                          child: const Text('保存预案，允许现场重新判断')),
                    ]))));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final input in [signal, ifThen, fallback, forecast]) {
      input.dispose();
    }
  }

  Widget _field() {
    final plan = f.latest(NodeKind.plan),
        trigger = f.latest(NodeKind.trigger),
        check = f.latest(NodeKind.triggerCheck);
    final confirmed = check?.text('state') == 'confirmed';
    final changed = check?.text('state') == 'changed';
    final seal = f.latest(NodeKind.seal);
    final reappraisal = f.latest(NodeKind.reappraisal);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(
          confirmed ? '把当时的理由，\n带到现在核实。' : '还在等什么条件？',
          confirmed
              ? '现实可以改变。保持原路线、先核实、改道或暂停都由你决定。'
              : '计划与提醒已经存在，并不表示现实中的条件已经发生。'),
      MotiveTide(
          caption: confirmed ? '现在核实条件，再决定下一步。' : '等待真正的条件，而不是等待一个预定答案。',
          phase: confirmed ? 'field' : 'waiting',
          animate: c.preferences.animations,
          height: 150),
      const SizedBox(height: 16),
      if (trigger == null) ...[
        const Text('尚未设置需要等待的条件。已经到了现场，也可以直接记录，不必补造事前预案。'),
        _primary('条件已经出现，直接记录现场', _directTrigger),
        TextButton(onPressed: () => _go(4), child: const Text('先回到事前准备'))
      ] else ...[
        Text(trigger.text('signal'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (parseTime(trigger.body['scheduledAt']) != null)
          Text('预约回看：${timeLabel(parseTime(trigger.body['scheduledAt']))}'),
        MirrorTag(check == null ? '现实条件尚未确认' : humanValue(check.text('state')),
            icon: Icons.fact_check_outlined),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          OutlinedButton(
              onPressed: () => _triggerCheck('confirmed'),
              child: const Text('真实条件出现了')),
          OutlinedButton(
              onPressed: () => _triggerCheck('changed'),
              child: const Text('条件有变化')),
          TextButton(
              onPressed: () =>
                  _act(() => c.verifyTrigger(f.id, 'unconfirmed', '还未确认真实条件')),
              child: const Text('还没有／暂不清楚')),
          TextButton(
              onPressed: () => _triggerCheck('expired'),
              child: const Text('原窗口已过／延后')),
        ]),
      ],
      if (plan != null) ...[
        const Divider(),
        Text('当时留给自己的预案', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(plan.text('ifThen')),
        if (seal != null)
          Text(
              EvidenceRules.verifySeal(seal)
                  ? '事前封存完整性通过 · ${timeLabel(parseTime(seal.body['sealedAt']))}'
                  : '原封存内容已删节或来源变化',
              style: Theme.of(context).textTheme.bodySmall),
        _sourceLink(plan, label: '看原来版本与备用路线')
      ],
      if (confirmed || changed) ...[
        const Divider(),
        _fieldMotives(),
        _principleCard(atField: true),
        if (reappraisal?.flag('safetyChanged') == true)
          const MirrorEmpty(
              title: '现场安全条件已变',
              body: '先保护自己、核实条件或选择安全替代。旧预案暂不用于推动行动。',
              icon: Icons.shield_outlined),
        Wrap(spacing: 8, runSpacing: 6, children: [
          OutlinedButton(
              onPressed: _fieldChanges, child: const Text('补充此刻的想法或新事实')),
          OutlinedButton(
              onPressed:
                  _busy ? null : () => _analyze(AnalysisStage.reappraise),
              child: const Text('按新事实重估路线'))
        ]),
        const SizedBox(height: 12),
        Text('现在，我作出了什么选择？', style: Theme.of(context).textTheme.titleMedium),
        Wrap(spacing: 7, runSpacing: 6, children: [
          FilledButton.tonal(
              onPressed: f.node(f.selectedRouteId) == null ||
                      !EvidenceRules.routeCanBePrepared(
                          f.node(f.selectedRouteId)!, f)
                  ? null
                  : () => _fieldDecision('original'),
              child: const Text('选择原路线')),
          OutlinedButton(
              onPressed: () => _fieldDecision('alternative'),
              child: const Text('先核实／换走法')),
          TextButton(
              onPressed: () => _fieldDecision('pause'),
              child: const Text('暂停或拒绝'))
        ]),
        _nodeList(NodeKind.decision, title: '本人记录的现场决定'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: _attempt,
            icon: const Icon(Icons.directions_walk),
            label: const Text('记录我确实尝试过的部分')),
        _nodeList(NodeKind.attempt),
      ],
      _primary('记录实际发生的事', () => _go(6)),
    ]);
  }

  Widget _fieldMotives() {
    final motives = f.selectedMotiveIds
        .map((id) => f.node(id))
        .whereType<MirrorNode>()
        .where((n) => n.usable && n.status == NodeStatus.accepted)
        .toList();
    final abstract =
        motives.where((n) => n.text('representation') != 'intuitive').toList();
    final key = abstract.isNotEmpty
        ? abstract.first
        : motives.isEmpty
            ? null
            : motives.first;
    final counter =
        f.current(NodeKind.motive).where(MotiveRanking.isCounter).toList();
    final scene = f
        .current(NodeKind.scene)
        .where((s) => s.status == NodeStatus.accepted)
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (key != null) ...[
        const MirrorTag('事前认可的一条理由'),
        const SizedBox(height: 8),
        Text(key.text('summary'),
            style: Theme.of(context).textTheme.titleMedium),
        TextButton(
            onPressed: () => _act(() => c.recordNode(f.id, NodeKind.awareness, {
                  'motiveId': key.id,
                  'stage': 'recalled',
                  'source': 'self_report',
                  'detail': '本人确认此刻想起'
                })),
            child: const Text('我此刻确实想起了它'))
      ],
      if (counter.isNotEmpty) ...[
        const SizedBox(height: 10),
        const MirrorTag('另一方仍值得听见'),
        const SizedBox(height: 7),
        Text(counter.first.text('summary'))
      ],
      if (scene.isNotEmpty &&
          f.latest(NodeKind.reappraisal)?.flag('safetyChanged') != true) ...[
        const SizedBox(height: 12),
        Text(scene.last.text('fieldCue')),
        TextButton.icon(
            onPressed: () => _playScene(scene.last),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('可选：回看自己的短预演'))
      ],
    ]);
  }

  Future<void> _directTrigger() async {
    final result = await askText(context,
        title: '已经出现了什么现实条件？',
        questions: [const TextQuestion('signal', '我亲自确认的条件', required: true)],
        explanation: '这会作为现场记录，不生成不存在的事前封存。');
    if (result == null || !mounted) return;
    final at = await pickMoment(context);
    if (at == null) return;
    await _act(() async {
      await c.recordNode(
          f.id,
          NodeKind.trigger,
          {
            'planId': null,
            'signal': result['signal'],
            'scheduledAt': null,
            'expiresAt': null,
            'verificationRequired': true
          },
          phase: TimePhase.t1);
      await c.verifyTrigger(f.id, 'confirmed', result['signal']!,
          occurredAt: at);
    });
  }

  Future<void> _triggerCheck(String state) async {
    final result = await askText(context,
        title: state == 'confirmed' ? '核实真正出现的条件' : '记录真实变化',
        questions: [
          TextQuestion(
              'detail', state == 'confirmed' ? '你实际看到了什么？' : '和原来相比，什么变了？',
              required: state == 'confirmed')
        ]);
    if (result == null || !mounted) return;
    final at = state == 'confirmed' ? await pickMoment(context) : null;
    if (state == 'confirmed' && at == null) return;
    await _act(
        () => c.verifyTrigger(f.id, state, result['detail']!, occurredAt: at));
  }

  Future<void> _fieldChanges() async {
    final check = f.latest(NodeKind.triggerCheck);
    if (check == null) return;
    final result = await askText(context, title: '此刻的情况', questions: [
      const TextQuestion('motive', '我现在真实想怎样做？'),
      const TextQuestion('change', '有哪些新事实或改变？')
    ]);
    if (result == null || !mounted) return;
    final risk = await chooseOption(context, title: '变化是否涉及安全或资格？', options: {
      'normal': '一般条件变化／暂不确定',
      'safety': '涉及健康、安全、资格或他人同意，需要先核实',
      if (f.latest(NodeKind.reappraisal)?.flag('safetyChanged') == true)
        'verified': '我已核实上面记录的新事实，原安全变化已解除'
    });
    if (risk == null) return;
    if (risk == 'verified' && result['change']!.trim().isEmpty) {
      await _act(() async => throw const MirrorProblem('请先记录实际核实的安全条件'));
      return;
    }
    await _act(() => c.recordNode(
        f.id,
        NodeKind.reappraisal,
        {
          'triggerCheckId': check.id,
          'planId': f.latest(NodeKind.plan)?.id,
          'changes':
              result['change']!.isEmpty ? <String>[] : [result['change']!],
          'immediateMotive': result['motive'],
          'rememberedMotiveIds': <String>[],
          'safetyChanged': risk == 'safety' ||
              (risk != 'verified' &&
                  f.latest(NodeKind.reappraisal)?.flag('safetyChanged') ==
                      true),
          'choice': 'verify',
          'routeId': null
        },
        phase: TimePhase.t1));
  }

  Future<void> _fieldDecision(String choice) async {
    String? routeId = f.selectedRouteId;
    if (choice == 'original' &&
        (f.node(routeId) == null ||
            !EvidenceRules.routeCanBePrepared(f.node(routeId)!, f))) {
      await _act(
          () async => throw const MirrorProblem('原路线条件尚未核实，请先核实、选择保护性走法或暂停'));
      return;
    }
    if (choice == 'alternative') {
      final routes = f
          .current(NodeKind.route)
          .where((route) => EvidenceRules.routeCanBePrepared(route, f))
          .toList();
      routeId = await chooseOption(context,
          title: '此刻愿意考虑哪条路线？',
          options: {for (final r in routes) r.id: r.text('title')});
      if (routeId == null) return;
    }
    if (choice == 'pause') routeId = null;
    final declaration = choice == 'pause'
        ? '我决定暂缓或拒绝原路线，保留重新判断的权利'
        : '我此刻决定考虑${f.node(routeId)?.text('title') ?? '所选路线'}；行动是否发生会另行记录';
    await _act(() => c.recordNode(
        f.id,
        NodeKind.decision,
        {
          'routeId': routeId,
          'declaration': declaration,
          'type': f.phase.index >= TimePhase.t2.index
              ? 'retrospective'
              : 'at_trigger',
          'userConfirmed': true,
          'jamesCandidates': <Json>[],
          'unknowns': <String>[]
        },
        happenedAt: DateTime.now(),
        phase: TimePhase.t1));
    if (choice == 'pause') await _act(() => c.pause(f.id));
  }

  Future<void> _attempt() async {
    final stage = await chooseOption(context,
        title: '哪一部分确实发生了？',
        explanation: '尝试、完成行动和外部结果分别记录。没有把握可以保留未知。',
        options: {
          'preparation': '我实际做了准备',
          'departed': '我已出发',
          'arrived': '我已到达',
          'attempted': '我实际开始尝试',
          'started_blocked': '开始后被条件阻断',
          'not_started': '我确认没有启动',
          'unknown': '目前不知道'
        });
    if (stage == null || !mounted) return;
    final detail = await askText(context, title: '保留真实尝试', questions: [
      const TextQuestion('detail', '实际做过的部分或未知原因', required: true)
    ]);
    if (detail == null || !mounted) return;
    final at = await pickMoment(context);
    await _act(() => c.recordNode(
        f.id,
        NodeKind.attempt,
        {
          'routeId':
              f.latest(NodeKind.decision)?.body['routeId'] ?? f.selectedRouteId,
          'decisionId': f.latest(NodeKind.decision)?.id,
          'stage': stage,
          'detail': detail['detail']
        },
        happenedAt: at,
        phase: TimePhase.t1));
  }
}
