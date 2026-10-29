part of 'workbench.dart';

extension _ReviewViews on _CaseWorkbenchState {
  Widget _review() {
    final observation = f.latest(NodeKind.observation),
        review = f.latest(NodeKind.review);
    final revealable = EvidenceRules.canReveal(f);
    final revealed =
        {CaseStage.revealed, CaseStage.revised}.contains(f.stage) && revealable;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('让实际发生的事，\n修订原来的认识。', '准备过、尝试过、受阻、改道、暂停，都分别留下它们的事实。'),
      if (observation == null) ...[
        const Text('现在还没有真实反馈。这里不会根据计划、提醒或沉默判断成败。'),
        _primary('记录实际观察', _observe, icon: Icons.edit_note)
      ],
      if (observation != null) ...[
        RealityEvidenceTrace(file: f, onNode: _details),
        _comparison(
            '外部结果 · 与行动分开',
            '${humanValue(observation.text('outcomeState'))}${observation.text('externalOutcome').isEmpty ? '' : '：${observation.text('externalOutcome')}'}',
            observation),
        const SizedBox(height: 14),
        MotiveTide(
            phase: revealed ? 'revealed' : 'waiting',
            evidenceCount: revealed
                ? f
                    .current(NodeKind.observation)
                    .where((n) => n.text('actionState') != 'unknown')
                    .length
                : 0,
            caption: revealed ? '点亮的是这次真实记录。原因和长期适配仍需检验。' : '尚未点亮的部分，继续保留为未知。',
            animate: c.preferences.animations,
            height: 164),
        if (revealable && !revealed)
          _primary(
              '按真实反馈揭晓',
              () => _act(() async {
                    await c.reveal(f.id);
                    if (c.preferences.haptics)
                      await HapticFeedback.lightImpact();
                  }),
              icon: Icons.waves),
        if (!revealable)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('行为仍不清楚，继续等待观察，不生成结果动画。')),
        Wrap(spacing: 6, children: [
          TextButton(onPressed: _observe, child: const Text('补充一次真实反馈')),
          TextButton(onPressed: _opportunity, child: const Text('补充当时的真实选择机会'))
        ]),
        _nodeList(NodeKind.interventionExecution, title: '哪些准备确实做了'),
        _nodeList(NodeKind.attempt, title: '尝试与受阻'),
        const Divider(),
        Text('真正得到以后，是否适合？', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('完成行动、取得结果和实际体验是不同的事。没有经历过的部分保持未知。'),
        _nodeList(NodeKind.acquisition),
        _nodeList(NodeKind.experience),
        Wrap(spacing: 7, children: [
          OutlinedButton(onPressed: _acquisition, child: const Text('记录实际取得')),
          OutlinedButton(onPressed: _experience, child: const Text('记录后续真实体验'))
        ]),
        const Divider(),
        if (review == null) ...[
          const Text('AI 会对照这些记录，审查最早的偏差、可能的原因、反证、补救和下一次可验证的条件。'),
          _primary(
              '基于真实记录复盘', _busy ? null : () => _analyze(AnalysisStage.review),
              icon: Icons.auto_awesome_outlined),
        ] else ...[
          if (review.objects('revisedClaims').isNotEmpty) ...[
            Text(
              '这次现实改变了哪些判断',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final item in review.objects('revisedClaims').take(3))
              MirrorCard(
                padding: const EdgeInsets.all(14),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MirrorTag(
                      const {
                            'supported': '得到初步支持',
                            'challenged': '遇到反例',
                            'uncertain': '仍不确定',
                          }[item['direction']] ??
                          '待核实',
                    ),
                    const SizedBox(height: 8),
                    Text(item['reason'] as String),
                    if (f.node(item['nodeId'] as String) case final old?)
                      _sourceLink(old, label: '对照原判断与依据'),
                  ],
                ),
              ),
            const SizedBox(height: 14),
          ],
          Text(review.text('summary'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final hypothesis in review.objects('hypotheses'))
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MirrorTag(humanValue(hypothesis['status'] as String)),
                      const SizedBox(height: 6),
                      Text(hypothesis['claim'] as String),
                      Text('可推翻条件：${hypothesis['falsifier']}',
                          style: Theme.of(context).textTheme.bodySmall)
                    ])),
          Text('下次可验证：${review.text('nextTest')}'),
          _sourceLink(review, label: '事实、偏差、反证与未知'),
          for (final assessment in f.current(NodeKind.changeability))
            ChangeabilityCard(
                node: assessment,
                resolve: c.resolve,
                onDetails: () => _details(assessment),
                onRecord: _evidence),
          _nodeList(NodeKind.repair, title: '可以自主选择的补救'),
          _nodeList(NodeKind.insight, title: '这次支持或质疑了什么认识'),
          _nodeList(NodeKind.manifestation, title: '同一个我，多种经历'),
          _principleCard(),
          OutlinedButton(
              onPressed: _busy ? null : () => _analyze(AnalysisStage.review),
              child: const Text('有新反馈，修订这次复盘')),
        ],
        if (f.current(NodeKind.principleApplication).isNotEmpty) ...[
          const Divider(),
          _principleApplicationReview()
        ],
        const Divider(),
        OutlinedButton.icon(
            onPressed: _journey,
            icon: const Icon(Icons.timeline),
            label: const Text('回看同一课题的真实历程')),
        _primary('带着这次认识，开始下一轮',
            _busy ? null : () => _act(() => c.nextEpisode(f.id)),
            icon: Icons.subdirectory_arrow_right),
      ],
    ]);
  }

  Widget _comparison(String title, String body, MirrorNode? node) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MirrorCard(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.all(15),
          onTap: node == null ? null : () => _details(node),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 7),
            Text(body)
          ])));
  Future<void> _observe() async {
    final action = TextEditingController();
    final external = TextEditingController();
    final feeling = TextEditingController();
    final form = GlobalKey<FormState>();
    var state = 'unknown', outcome = 'unknown', saving = false;
    DateTime? happenedAt;
    const states = {
      'completed': '确实完成',
      'partial': '做了一部分',
      'changed': '换了走法',
      'blocked': '尝试后受阻',
      'not_performed': '确实没行动',
      'unknown': '尚不清楚',
    };
    const outcomes = {
      'unknown': '还不知道',
      'pending': '等待后续',
      'achieved': '确实取得',
      'partial': '取得一部分',
      'not_achieved': '确实未取得',
    };
    await mirrorSheet<void>(
      context,
      title: '这次实际发生了什么？',
      child: StatefulBuilder(
        builder: (sheetContext, refresh) => Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('一次反馈即可。做过的部分会留下；不知道的部分可以保持未知。'),
              const SizedBox(height: 14),
              Text('行动本身', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in states.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: state == entry.key,
                      onSelected: saving
                          ? null
                          : (_) => refresh(() => state = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('mirror-observation-action'),
                controller: action,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '实际做了什么？',
                  hintText: '例如：已出发，但对方取消了。只写真实发生的部分。',
                ),
                validator: (v) => state != 'unknown' && (v ?? '').trim().isEmpty
                    ? '请留下一句实际情况'
                    : null,
              ),
              const SizedBox(height: 16),
              Text('外部结果', style: Theme.of(context).textTheme.titleSmall),
              const Text('采取了行动，也可能仍要等待对方或后续结果。'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in outcomes.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: outcome == entry.key,
                      onSelected: saving
                          ? null
                          : (_) => refresh(() => outcome = entry.key),
                    ),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('补充结果、感受或发生时间（可选）'),
                children: [
                  TextFormField(
                    controller: external,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '外部结果的具体事实'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: feeling,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '你的真实感受'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final at = await pickMoment(sheetContext);
                      if (at != null && sheetContext.mounted)
                        refresh(() => happenedAt = at);
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      happenedAt == null ? '发生时间未指定' : timeLabel(happenedAt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('mirror-save-observation'),
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        refresh(() => saving = true);
                        var saved = false;
                        await _act(() async {
                          final text = action.text.trim().isEmpty
                              ? '本轮行动情况尚不清楚'
                              : action.text.trim();
                          await c.observe(
                            f.id,
                            {
                              'routeId': f
                                      .latest(NodeKind.decision)
                                      ?.body['routeId'] ??
                                  f.selectedRouteId,
                              'attemptId': f.latest(NodeKind.attempt)?.id,
                              'actionState': state,
                              'action': text,
                              'externalOutcome': external.text.trim(),
                              'outcomeState': outcome,
                              'feeling': feeling.text.trim(),
                              'noticedMotiveIds': <String>[],
                              'context': '',
                              'domains': f
                                      .latest(NodeKind.understanding)
                                      ?.strings('domains') ??
                                  <String>[],
                              'opportunityId':
                                  f.latest(NodeKind.opportunity)?.id
                            },
                            text,
                            happenedAt: happenedAt,
                          );
                          saved = true;
                        });
                        if (sheetContext.mounted) {
                          if (saved) {
                            Navigator.pop(sheetContext);
                          } else {
                            refresh(() => saving = false);
                          }
                        }
                      },
                child: const Text('保存真实反馈'),
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    action.dispose();
    external.dispose();
    feeling.dispose();
  }

  Future<void> _opportunity() async {
    final choice = await chooseOption(context,
        title: '当时真的存在选择机会吗？',
        options: {'unclear': '还不清楚', 'yes': '确有现实可选的不同走法', 'no': '没有真实可选机会'});
    if (choice == null || !mounted) return;
    final autonomy = await chooseOption(context, title: '当时的自主条件', options: {
      'unknown': '未知／不想补充',
      'reasonably_free': '相对自主',
      'pressured': '有明显压力',
      'coerced': '受到强迫'
    });
    if (autonomy == null || !mounted) return;
    final details = await askText(context, title: '当时的现实条件', questions: [
      const TextQuestion('conditions', '哪些选项当时确实可行、也被你知道？'),
      const TextQuestion('tradeoff', '实际承担或放弃了什么？')
    ]);
    if (details == null || !mounted) return;
    final actualRoutes = <String>{}, knownRoutes = <String>{};
    final routes = f.current(NodeKind.route).toList();
    if (choice == 'yes' && routes.isNotEmpty) {
      final saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (sheetContext) => StatefulBuilder(
              builder: (context, update) => FractionallySizedBox(
                  heightFactor: .78,
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('当时可行，也被我知道的走法',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            const Text(
                                '只勾选实际核实的条件。未勾选保留未知，分析阶段出现过的路线不等于当时真实可选。'),
                            Expanded(
                                child: ListView(children: [
                              for (final route in routes) ...[
                                const Divider(),
                                Text(route.text('title')),
                                CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('当时确实可以选择'),
                                    value: actualRoutes.contains(route.id),
                                    onChanged: (value) => update(() =>
                                        value == true
                                            ? actualRoutes.add(route.id)
                                            : actualRoutes.remove(route.id))),
                                CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('当时已经知道这条走法'),
                                    value: knownRoutes.contains(route.id),
                                    onChanged: (value) => update(() =>
                                        value == true
                                            ? knownRoutes.add(route.id)
                                            : knownRoutes.remove(route.id))),
                              ]
                            ])),
                            FilledButton(
                                onPressed: () =>
                                    Navigator.pop(sheetContext, true),
                                child: const Text('保留记录（可以不勾选）'))
                          ])))));
      if (saved != true) return;
    }
    await _act(() => c.recordNode(
        f.id,
        NodeKind.opportunity,
        {
          'state': choice,
          'actualRouteIds': actualRoutes.toList(),
          'knownRouteIds': knownRoutes.toList(),
          'conditions': details['conditions'],
          'autonomy': autonomy,
          'tradeoff': details['tradeoff'],
          'evidenceQuality': 'limited',
          'assessment': [
            {
              'dimension': 'choice_availability',
              'state': choice == 'unclear' ? 'unknown' : 'limited',
              'reason': choice == 'no'
                  ? '本人报告当时没有真实可选机会'
                  : choice == 'yes'
                      ? '本人报告存在选择机会；具体可选路线仍需核实'
                      : '尚未核实'
            },
            {
              'dimension': 'autonomy',
              'state': autonomy == 'reasonably_free'
                  ? 'supported'
                  : autonomy == 'unknown'
                      ? 'unknown'
                      : 'limited',
              'reason': humanValue(autonomy)
            },
            {
              'dimension': 'known_tradeoff',
              'state': details['tradeoff']!.isEmpty ? 'unknown' : 'limited',
              'reason': details['tradeoff']!.isEmpty
                  ? '尚未记录当时已知代价'
                  : details['tradeoff']!
            },
            {
              'dimension': 'observation_reliability',
              'state': 'limited',
              'reason': '本人回述，尚未独立核实'
            },
            {
              'dimension': 'deliberation_access',
              'state': knownRoutes.length >= 2 ? 'limited' : 'unknown',
              'reason': knownRoutes.length >= 2
                  ? '本人报告当时知道不同走法，是否充分审议仍需核实'
                  : '尚未记录不同走法是否进入当时意识'
            },
            {
              'dimension': 'context_coverage',
              'state': 'limited',
              'reason': '这一条只描述本次经历，不能代表所有情境'
            },
            {
              'dimension': 'alternatives',
              'state': 'unknown',
              'reason': '其他影响实际行为的解释仍需审查'
            },
          ]
        },
        revisionOf: f.latest(NodeKind.opportunity)?.id,
        phase: TimePhase.t2));
  }

  Future<void> _acquisition() async {
    final observation = f.latest(NodeKind.observation);
    if (observation == null) return;
    final state = await chooseOption(context,
        title: '目标结果是否真的取得？',
        explanation: '取得结果不会自动成为满意或长期适配的证据。',
        options: {
          'unknown': '未知',
          'acquired': '实际取得',
          'partly_acquired': '部分取得',
          'not_acquired': '尚未取得'
        });
    if (state == null || !mounted) return;
    final details = await askText(context,
        title: '保留取得结果的事实',
        questions: [const TextQuestion('detail', '具体得到什么，或还有什么未确认？')]);
    if (details == null || !mounted) return;
    final at = await pickMoment(context);
    await _act(() => c.recordNode(
        f.id,
        NodeKind.acquisition,
        {
          'observationId': observation.id,
          'routeId': observation.body['routeId'],
          'state': state,
          'detail': details['detail']
        },
        evidenceIds: [observation.id],
        happenedAt: at,
        phase: TimePhase.t3));
  }

  Future<void> _experience() async {
    final observation = f.latest(NodeKind.observation);
    if (observation == null) return;
    final window =
        await chooseOption(context, title: '这段真实体验属于哪个阶段？', options: {
      'initial': '初次体验',
      'routine': '已经进入日常',
      'sustained': '持续经历',
      'custom': '我的自定义观察窗口'
    });
    if (window == null || !mounted) return;
    final value = await askText(context,
        title: '实际体验，与原来期待分别保留',
        questions: [
          const TextQuestion('benefits', '实际得到的收益（没有或未知可不填）'),
          const TextQuestion('costs', '真实遇到的负担（未知可不填）'),
          const TextQuestion('feeling', '真实感受与当时条件', required: true)
        ],
        explanation: '短期体验只说明这一段时间，不会据此判定一生适不适合。');
    if (value == null || !mounted) return;
    final at = await pickMoment(context);
    await _act(() => c.recordNode(
        f.id,
        NodeKind.experience,
        {
          'observationId': observation.id,
          'routeId': observation.body['routeId'],
          'wantIds': <String>[],
          'window': window,
          'benefits':
              value['benefits']!.isEmpty ? <String>[] : [value['benefits']!],
          'costs': value['costs']!.isEmpty ? <String>[] : [value['costs']!],
          'feeling': value['feeling'],
          'conditions': '',
          'unknowns': <String>[],
          'reviewAt': null
        },
        evidenceIds: [observation.id],
        happenedAt: at,
        phase: TimePhase.t3));
  }

  MirrorNode? _applicablePrinciple({bool atField = false}) {
    final application = f.latest(NodeKind.principleApplication);
    if (application?.text('exposure') == 'declined') return null;
    if (application != null) {
      final p = c.resolve(application.text('principleId'));
      final adopted = {'accepted', 'scheduled', 'delivered'}
          .contains(application.text('exposure'));
      if ((!atField || adopted) &&
          p != null &&
          EvidenceRules.principleCanBePrepared(p, f,
              authorized: c.authorizedHistory)) return p;
    }
    // Showing a draft at T1 must not imply it was adopted for this occasion.
    if (atField) return null;
    final matches = f
        .current(NodeKind.principleMatch)
        .where((n) => {'applicable', 'conditional'}.contains(n.text('fit')));
    for (final match in matches) {
      final p = c.resolve(match.text('principleId'));
      if (p != null &&
          EvidenceRules.principleCanBePrepared(p, f,
              authorized: c.authorizedHistory)) return p;
    }
    final own = f.current(NodeKind.principle);
    if (own.isNotEmpty)
      return own.where((p) => p.id == _focusedPrincipleId).firstOrNull ??
          own.first;
    final earlier = f.current(NodeKind.principle, allEpisodes: true).where(
        (p) => EvidenceRules.principleCanBePrepared(p, f,
            authorized: c.authorizedHistory));
    return earlier.isEmpty ? null : earlier.first;
  }

  Widget _principleCard({bool atField = false}) {
    final principle = _applicablePrinciple(atField: atField);
    if (principle == null) return const SizedBox.shrink();
    final latest = f.latest(NodeKind.principleApplication);
    final application =
        latest?.text('principleId') == principle.id ? latest : null;
    final canAdopt = EvidenceRules.principleCanBePrepared(principle, f,
        authorized: c.authorizedHistory, requireAccepted: false);
    final adopted = {'accepted', 'scheduled', 'delivered'}
        .contains(application?.text('exposure'));
    final cue = principle.text('fieldCue').isNotEmpty
        ? principle.text('fieldCue')
        : principle.text('thenAction').runes.length <= 60
            ? '${principle.text('thenAction')}。条件变化时可以暂停。'
            : '先核实这条经验是否适用，再自主选择下一步；条件变化时可以暂停。';
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: MirrorCard(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: .3),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const MirrorTag('我的经验原则 · 仍可修订', icon: Icons.bookmark_border),
              const SizedBox(height: 12),
              Text(atField ? cue : principle.text('summary'),
                  style: Theme.of(context).textTheme.titleMedium),
              if (!atField) ...[
                const SizedBox(height: 8),
                Text(
                    '如果 ${principle.text('ifCondition')}，\n就先 ${principle.text('thenAction')}。'),
                const SizedBox(height: 9),
                Text('不适用时：${principle.text('exceptionRule')}'),
                Text('仍需验证：${principle.text('nextTest')}'),
                if (principle.text('reviewReason').isNotEmpty)
                  Text(principle.text('reviewReason')),
              ] else
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('适用条件、例外与完整做法'),
                  children: [
                    Text(
                        '如果 ${principle.text('ifCondition')}，就先 ${principle.text('thenAction')}。'),
                    Text('不适用时：${principle.text('exceptionRule')}'),
                    Text('仍需验证：${principle.text('nextTest')}'),
                  ],
                ),
              _sourceLink(principle, label: '实际出处、反例和适用条件'),
              if (!atField && !canAdopt)
                const Text('适用条件或安全限制需要重新核实。可以修改这条原则，也可以不使用原则继续。'),
              if (!atField)
                Wrap(spacing: 6, runSpacing: 4, children: [
                  FilledButton.tonal(
                      onPressed: canAdopt && !adopted
                          ? () => _adoptPrinciple(principle)
                          : null,
                      child: Text(adopted ? '已采用为本次参考' : '采用为本次参考')),
                  TextButton(
                      onPressed: () => _editPrinciple(principle),
                      child: const Text('修改')),
                  TextButton(
                      onPressed: () =>
                          _declinePrinciple(principle, 'not_applicable'),
                      child: const Text('不适用')),
                  TextButton(
                      onPressed: () => _declinePrinciple(principle, 'later'),
                      child: const Text('稍后')),
                  TextButton(
                      onPressed: () => _declinePrinciple(principle, 'skip'),
                      child: const Text('跳过'))
                ]),
              if (!atField && f.current(NodeKind.principle).length > 1)
                ExpansionTile(
                  title: const Text('也看看其他候选 · 可以全部跳过'),
                  children: [
                    const Text('不同做法可能适合不同条件。只选择这次适用的一条，冲突时先核实。'),
                    for (final other in f
                        .current(NodeKind.principle)
                        .where((p) => p.id != principle.id)
                        .take(2))
                      ListTile(
                        title: Text(other.text('summary')),
                        subtitle: Text('适用：${other.text('ifCondition')}'),
                        onTap: () => _focusPrinciple(other.id),
                      ),
                  ],
                ),
              if (atField && application != null)
                Wrap(spacing: 6, children: [
                  TextButton(
                      onPressed: () => _updateApplication(application,
                          {'recall': 'explicitly_recalled'}, TimePhase.t1),
                      child: const Text('我现场确实想起了它')),
                  TextButton(
                      onPressed: () => _updateApplication(application,
                          {'recall': 'context_changed'}, TimePhase.t1),
                      child: const Text('当前条件不适用'))
                ]),
            ])));
  }

  Future<void> _adoptPrinciple(MirrorNode principle) async {
    await _act(() async {
      if (principle.caseId == f.id && principle.status != NodeStatus.accepted)
        await c.feedback(f.id, principle.id, 'accept');
      final prior = f.latest(NodeKind.principleApplication);
      await c.recordNode(
          f.id,
          NodeKind.principleApplication,
          {
            'principleId': principle.id,
            'principleVersion': principle.id,
            'triggerId': f.latest(NodeKind.trigger)?.id,
            'exposure': 'accepted',
            'recall': 'unknown',
            'application': 'unknown',
            'attemptIds': <String>[],
            'observationIds': <String>[],
            'detail': '本人选为这次参考，尚无实际应用证据'
          },
          evidenceIds: principle.evidenceIds,
          links: [principle.id],
          revisionOf:
              prior?.text('principleId') == principle.id ? prior?.id : null);
    });
  }

  Future<void> _declinePrinciple(MirrorNode principle, String action) async {
    await _act(() async {
      final latest = f.latest(NodeKind.principleApplication);
      final application =
          latest?.text('principleId') == principle.id ? latest : null;
      await c.recordNode(
          f.id,
          NodeKind.principleApplication,
          {
            'principleId': principle.id,
            'principleVersion': principle.id,
            'triggerId': f.latest(NodeKind.trigger)?.id,
            'exposure': 'declined',
            'recall': application?.text('recall') ?? 'unknown',
            'application': application?.text('application') ?? 'unknown',
            'attemptIds': application?.strings('attemptIds') ?? <String>[],
            'observationIds':
                application?.strings('observationIds') ?? <String>[],
            'detail': action == 'later'
                ? '本人选择稍后考虑'
                : action == 'skip'
                    ? '本人选择跳过'
                    : '当前情境不适用；不代表其他情境也无效',
          },
          evidenceIds: principle.evidenceIds,
          links: [principle.id],
          revisionOf: application?.id);
    });
  }

  Future<void> _editPrinciple(MirrorNode principle) async {
    final value = await askText(context, title: '把原则改成你认可的做法', questions: [
      TextQuestion('ifCondition', '什么情境下？',
          initial: principle.text('ifCondition'), required: true),
      TextQuestion('thenAction', '具体先做什么？',
          initial: principle.text('thenAction'), required: true),
      TextQuestion('exceptionRule', '什么时候不适用？',
          initial: principle.text('exceptionRule'), required: true),
      TextQuestion('fieldCue', '现场只提醒这一句（75 字以内）',
          maxLength: 75,
          initial: principle.text('fieldCue').isNotEmpty
              ? principle.text('fieldCue')
              : principle.text('thenAction').runes.length <= 75
                  ? principle.text('thenAction')
                  : '',
          required: true),
    ]);
    if (value == null) return;
    await _act(() => c.recordNode(
        f.id,
        NodeKind.principle,
        {
          ...principle.body,
          ...value,
          'summary': '${value['ifCondition']}时，${value['thenAction']}',
          'maturity': 'tentative',
          'reviewReason': '本人调整了条件与做法，仍需下一次真实经历检验。',
        },
        evidenceIds: principle.evidenceIds,
        counterIds: principle.counterIds,
        links: [principle.id],
        revisionOf: principle.caseId == f.id ? principle.id : null));
  }

  Future<void> _updateApplication(
          MirrorNode application, Json changes, TimePhase phase) =>
      _act(() => c.recordNode(f.id, NodeKind.principleApplication,
          {...application.body, ...changes},
          evidenceIds: application.evidenceIds,
          links: [application.text('principleId')],
          revisionOf: application.id,
          phase: phase));
  Widget _principleApplicationReview() {
    final application = f.latest(NodeKind.principleApplication)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('这条原则实际怎样参与了？', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      Text(
          '现场想起：${humanValue(application.text('recall'))}\n实际采用：${humanValue(application.text('application'))}'),
      const Text('结果与原因分开。完成了行动，并不自动证明某条原则起了作用。'),
      Wrap(spacing: 6, children: [
        TextButton(
            onPressed: () =>
                _applicationOutcome(application, 'applied_self_report'),
            child: const Text('本人确认实际采用')),
        TextButton(
            onPressed: () => _applicationOutcome(application, 'not_applied'),
            child: const Text('没有采用')),
        TextButton(
            onPressed: () => _applicationOutcome(application, 'unknown'),
            child: const Text('仍然未知'))
      ]),
      _sourceLink(application, label: '查看当时使用的原则版本'),
    ]);
  }

  Future<void> _applicationOutcome(MirrorNode application, String state) async {
    final details = await askText(context, title: '原则应用与结果分别记录', questions: [
      TextQuestion('detail', '具体用了什么做法，或为什么尚不清楚？',
          required: state == 'applied_self_report')
    ]);
    if (details == null) return;
    await _updateApplication(
        application,
        {
          'application': state,
          'detail': details['detail'],
          'attemptIds': f.current(NodeKind.attempt).map((n) => n.id).toList(),
          'observationIds':
              f.current(NodeKind.observation).map((n) => n.id).toList(),
          'preparationIds': f
              .current(NodeKind.interventionExecution)
              .where((n) =>
                  {'executed', 'partly_executed'}.contains(n.text('state')))
              .map((n) => n.id)
              .toList(),
        },
        TimePhase.t2);
  }
}
