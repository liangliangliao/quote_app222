part of 'workbench.dart';

extension _AnalysisViews on _CaseWorkbenchState {
  Widget _understanding() {
    final understood = f.latest(NodeKind.understanding);
    final wants = f.current(NodeKind.want);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('这次满足了什么，\n又可能牺牲什么？'),
      if (understood == null) ...[
        const Text('先忠实保留你的描述。AI 会从这里分开事实、当时的认识和仍然未知的部分。'),
        const SizedBox(height: 14),
        for (final node in f.current(NodeKind.evidence))
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(node.text('text')),
              subtitle: Text(sourceLabel(node.origin)),
              onTap: () => _details(node)),
        _primary('从这件事开始分析', _busy ? null : () => _analyze(),
            icon: Icons.auto_awesome_outlined),
      ] else ...[
        Text(understood.text('summary'),
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        for (final fact in understood.objects('facts'))
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.format_quote, size: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(fact['claim'] as String))
              ])),
        if (understood.strings('unknowns').isNotEmpty) ...[
          const SizedBox(height: 10),
          const MirrorTag('还不知道的事', icon: Icons.help_outline),
          for (final item in understood.strings('unknowns'))
            Padding(
                padding: const EdgeInsets.only(top: 8), child: Text('· $item'))
        ],
        _sourceLink(understood, label: '查看原话与事实来源'),
        if (understood.text('keyQuestion').isNotEmpty)
          MirrorCard(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(understood.text('keyQuestion')),
                    TextButton(
                        onPressed: () => _evidence(),
                        child: const Text('补充这条信息（可以稍后）'))
                  ])),
      ],
      _nodeList(NodeKind.capability, title: '原文中的任务能力线索 · 待核实'),
      if (wants.isNotEmpty) ...[
        const Divider(),
        Text('可能在意的东西', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text('它们是候选。你可以认可，也可以说不符合。'),
        for (final want in wants)
          Padding(
              padding: const EdgeInsets.only(top: 14),
              child: MirrorCard(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(want.text('claim'),
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(spacing: 5, runSpacing: 5, children: [
                          MirrorTag(humanValue(want.text('specificity'))),
                          if (want.status == NodeStatus.accepted)
                            const MirrorTag('你已认可')
                        ]),
                        if (want.text('immediateBenefit').isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Text('当下：${want.text('immediateBenefit')}')
                        ],
                        if (want.text('longTermCost').isNotEmpty)
                          Text('更长时间：${want.text('longTermCost')}'),
                        _sourceLink(want),
                        Wrap(spacing: 6, children: [
                          TextButton(
                              onPressed: () => _act(
                                  () => c.feedback(f.id, want.id, 'accept')),
                              child: const Text('符合我')),
                          TextButton(
                              onPressed: () => _act(
                                  () => c.feedback(f.id, want.id, 'reject')),
                              child: const Text('不符合'))
                        ]),
                      ])))
      ],
      if (understood != null)
        _primary('看看有哪些正反理由', _busy ? null : () => _go(1)),
      if (understood != null)
        TextButton(
            onPressed: _busy ? null : () => _analyze(),
            child: const Text('根据补充的事实更新分析')),
      if (f.retrospective)
        TextButton(onPressed: () => _go(6), child: const Text('直接记录实际发生的事')),
    ]);
  }

  Widget _motives() {
    final ranking = f.latest(NodeKind.recommendation);
    final motives = MotiveRanking.distinct(f.current(NodeKind.motive));
    final ranked = ranking?.objects('ranked') ?? <Json>[];
    final expiresAt = parseTime(ranking?.body['expiresAt']);
    final expired =
        expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt);
    final previousOnline = f
        .current(NodeKind.recommendation)
        .where((n) => n.id != ranking?.id && n.text('method') == 'decisions')
        .toList();
    final displayed = ranked
        .map((r) => f.node(r['motiveId'] as String))
        .whereType<MirrorNode>()
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('先认真看看这些理由。', '它们是本次值得审议的线索。正方、反方与需要核实的风险都可以留下。'),
      if (motives.isEmpty) ...[
        const Text('候选池还没有生成。你不需要先回答五十道问题。'),
        _primary('补全这次的理由', _busy ? null : () => _analyze(),
            icon: Icons.auto_awesome_outlined)
      ] else ...[
        Wrap(spacing: 6, runSpacing: 6, children: [
          MirrorTag('${motives.length} 条不同候选'),
          MirrorTag(ranking?.text('method') == 'decisions'
              ? expired
                  ? '过期在线记录 · 待复核'
                  : '在线四维量规记录'
              : '来源规则摘要'),
          MirrorTag('已选 ${f.selectedMotiveIds.length}/3')
        ]),
        const SizedBox(height: 12),
        if (ranking != null)
          Text(ranking.text('message'),
              style: Theme.of(context).textTheme.bodySmall),
        if (ranking?.text('method') == 'decisions')
          Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                  '评分于 ${timeLabel(parseTime(ranking?.body['scoredAt']) ?? ranking?.recordedAt)}'
                  '\n${expired ? '缓存已过期' : '缓存到期'}：${timeLabel(expiresAt)}。24 小时是回看提示，不是准确性保证；事实改变需立即复核。',
                  style: Theme.of(context).textTheme.bodySmall)),
        if (ranking?.text('method') != 'decisions' && previousOnline.isNotEmpty)
          TextButton(
              onPressed: () => _details(previousOnline.last),
              child: Text(
                  '查看旧在线榜单 · ${timeLabel(previousOnline.last.recordedAt)}')),
        if (displayed.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('暂时没有可靠的 Top5。可以先阅读代表性理由，核实其中最关键的事实。')),
        for (var i = 0; i < displayed.length; i++)
          _motiveCard(displayed[i], rank: i + 1, score: ranked[i]),
        if (ranking?.flag('unstable') == true)
          const Text('这些量规分数很接近，排序并不稳定；请一起审议。'),
        if (ranking != null && ranking.strings('verifyFirstIds').isNotEmpty)
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('重要但仍待核实的理由'),
              children: [
                for (final id in ranking.strings('verifyFirstIds'))
                  if (f.node(id) != null) _motiveCard(f.node(id)!)
              ]),
        Wrap(spacing: 8, runSpacing: 6, children: [
          OutlinedButton(
              onPressed: () => _showMotives(
                  motives.where(MotiveRanking.isCounter).toList(), '重要反方理由'),
              child: const Text('看重要反方')),
          OutlinedButton(
              onPressed: () =>
                  _showMotives(motives.take(8).toList(), '差异较大的代表理由'),
              child: const Text('看 6–8 条代表理由')),
          OutlinedButton(
              onPressed: () =>
                  _showMotives(motives, '全部 ${motives.length} 条候选'),
              child: const Text('展开全部')),
          OutlinedButton(
              onPressed: () => mirrorSheet<void>(context,
                  title: '理由怎样连接不同路线',
                  child: MotiveGraphView(file: f, onNode: _details)),
              child: const Text('查看动机关系')),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: _weights, child: const Text('量规与权重')),
          TextButton(
              onPressed: _busy ? null : _score, child: const Text('本次远程评分'))
        ]),
        _primary('看看有哪些认识值得核实', _busy ? null : () => _go(2)),
      ],
    ]);
  }

  Widget _motiveCard(MirrorNode motive, {int? rank, Json? score}) {
    final selected = f.selectedMotiveIds.contains(motive.id);
    final directions = motive.objects('directionByRoute');
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: MirrorCard(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (rank != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('本次优先审议 ${rank.toString().padLeft(2, '0')}',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.primary))),
              Text(motive.text('summary'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                MirrorTag(humanValue(motive.text('representation'))),
                MirrorTag(humanValue(motive.text('horizon'))),
                MirrorTag(humanValue(motive.text('factStatus')))
              ]),
              for (final direction in directions.take(2))
                Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                        '${humanValue(direction['relation'] as String)} · ${f.node(direction['routeId'] as String)?.text('title') ?? '关联路线'}',
                        style: Theme.of(context).textTheme.bodySmall)),
              if (score?['priority'] != null)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                        '审议量规 ${(score!['priority'] as num).toStringAsFixed(1)} / 4 · 非动机强度')),
              if (score != null) ...[
                const SizedBox(height: 7),
                Text(score['reason'] as String,
                    style: Theme.of(context).textTheme.bodySmall),
                TextButton(
                    onPressed: () => _scoreDetails(motive, score),
                    child: const Text('为什么它排在这里'))
              ],
              _sourceLink(motive),
              Wrap(spacing: 6, runSpacing: 4, children: [
                FilterChip(
                    label: Text(selected ? '已选为现场理由' : '认可，留作现场理由'),
                    selected: selected,
                    onSelected: (value) =>
                        _act(() => c.selectMotive(f.id, motive.id, value))),
                TextButton(
                    onPressed: () =>
                        _act(() => c.feedback(f.id, motive.id, 'reject')),
                    child: const Text('不符合我')),
                TextButton(
                    onPressed: () => _evidence(category: 'correction'),
                    child: const Text('核实事实'))
              ]),
            ])));
  }

  Future<void> _showMotives(List<MirrorNode> motives, String title) =>
      mirrorSheet<void>(context,
          title: title,
          child: AnimatedBuilder(
              animation: c,
              builder: (_, __) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (motives.isEmpty)
                          const Text('目前没有有来源的这类候选，不会为了正反配额补造。'),
                        for (final motive in motives)
                          if (c.resolve(motive.id)?.usable == true)
                            _motiveCard(c.resolve(motive.id)!),
                      ])));
  Future<void> _scoreDetails(MirrorNode motive, Json score) =>
      mirrorSheet<void>(context,
          title: '这条理由为什么值得先看',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(motive.text('summary'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(score['reason'] as String),
            const SizedBox(height: 8),
            Text(score['rule'] as String),
            const Divider(),
            for (final facet in (score['facets'] as List).map(jsonMap))
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(const {
                        'personal_fit': '个人相关性',
                        'evidence_quality': '来源证据质量',
                        'decision_materiality': '对选择的区分度',
                        'context_relevance': '当前情境相关性'
                      }[facet['dimension']] ??
                      '量规维度'),
                  trailing: Text(facet['score'] == null
                      ? '未评分'
                      : '${(facet['score'] as num).toStringAsFixed(1)} / 4'),
                  subtitle: facet['confidence'] == null
                      ? null
                      : Text(
                          '模型回答置信度：${(facet['confidence'] as num).toStringAsFixed(2)}；不等于事实质量')),
            const Text('评分只属于这个课题、这份证据和当前量规版本。分数相近时不能理解为科学上的精确差异。'),
            _sourceLink(motive),
          ]));
  Future<void> _score() async {
    final consent = await askAnalysisConsent(context, c, f, action: '评分本次候选');
    if (consent != null) await _act(() => c.score(consent));
  }

  Future<void> _weights() async {
    final weights = [...c.preferences.weights];
    await mirrorSheet<void>(context,
        title: '本次审议的四项量规',
        child: StatefulBuilder(
            builder: (sheetContext, setState) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('权重是可调整的产品规则，不是心理学常数。证据未知不会补成零分。'),
                      const SizedBox(height: 12),
                      for (var i = 0; i < 4; i++)
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${const [
                                '个人相关性',
                                '证据质量',
                                '决策区分度',
                                '当前情境相关性'
                              ][i]} · ${(weights[i] * 100).round()}'),
                              Slider(
                                  value: weights[i],
                                  min: 0,
                                  max: 1,
                                  divisions: 20,
                                  onChanged: (v) =>
                                      setState(() => weights[i] = v))
                            ]),
                      FilledButton(
                          onPressed: weights.every((w) => w == 0)
                              ? null
                              : () async {
                                  await _act(
                                      () => c.updateWeights(weights, f.id));
                                  if (sheetContext.mounted)
                                    Navigator.pop(sheetContext);
                                },
                          child: const Text('保存权重并比较排序')),
                    ])));
  }

  Widget _cognition() {
    final reframes = f.current(NodeKind.reframe);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('有哪项认识，\n可能让走法不同？', '旧认识可以是正确的。每项新认识都需要现实检验。'),
      if (reframes.isEmpty) ...[
        const Text('目前还没有可展示的转换候选。资料不足时，可以先保留原判断并核实一条关键事实。'),
        _primary(
            '寻找可检验的新认识', _busy ? null : () => _analyze(AnalysisStage.cognition),
            icon: Icons.auto_awesome_outlined)
      ],
      for (final reframe in reframes)
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: MirrorCard(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MirrorTag('原来的认识'),
                      const SizedBox(height: 8),
                      Text(f.node(reframe.text('oldBeliefId'))?.text('claim') ??
                          '原认识来源待复核'),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 9),
                          child: Icon(Icons.south, size: 20)),
                      const MirrorTag('一个可检验的新认识', emphasis: true),
                      const SizedBox(height: 10),
                      Text(reframe.text('newClaim'),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Text('可能改变：${reframe.text('mechanism')}'),
                      const SizedBox(height: 8),
                      Text('原判断也可能成立：${reframe.text('oldMayBeRight')}'),
                      const SizedBox(height: 10),
                      Text('可以核实：${reframe.text('test')}'),
                      _sourceLink(reframe),
                      Wrap(spacing: 6, children: [
                        FilledButton.tonal(
                            onPressed: reframe.status == NodeStatus.accepted
                                ? null
                                : () => _act(
                                    () => c.acceptReframe(f.id, reframe.id)),
                            child: Text(reframe.status == NodeStatus.accepted
                                ? '已认可，仍待实践'
                                : '认可这项认识')),
                        TextButton(
                            onPressed: () => _act(
                                () => c.feedback(f.id, reframe.id, 'reject')),
                            child: const Text('不符合')),
                        TextButton(
                            onPressed: () => _evidence(category: 'counter'),
                            child: const Text('补充反证'))
                      ]),
                    ]))),
      _nodeList(NodeKind.graphShift, title: '认识前后的变化'),
      if (f.current(NodeKind.graphShift).isNotEmpty)
        OutlinedButton(
            onPressed: _busy ? null : () => _analyze(AnalysisStage.reappraise),
            child: const Text('根据新认识更新理由与路线')),
      TextButton(
          onPressed: () => mirrorSheet<void>(context,
              title: '方法从哪里来',
              child: Column(children: [
                for (final card in theoryCards)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${card['author']} · ${card['kind']}'),
                      subtitle: Text('${card['source']}\n${card['text']}'))
              ])),
          child: const Text('查看方法与理论边界')),
      _primary('比较可以实际采取的走法', _busy ? null : () => _go(3)),
    ]);
  }

  Widget _routes() {
    final routes = f.current(NodeKind.route);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('不止一种走法。', '想要什么、现在能否实施、需要什么支持，分开看。'),
      if (routes.isEmpty) const Text('还没有生成路线。可以补全分析，也可以写下你自己的走法。'),
      for (final route in routes) _routeCard(route),
      if (routes.length > 1)
        OutlinedButton.icon(
            onPressed: () => mirrorSheet<void>(context,
                title: '把路线放在一起比较',
                child: RouteComparison(file: f, onNode: _details)),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('比较欲求、时间、难度与现实条件')),
      _nodeList(NodeKind.resourceConflict, title: '是否真的争夺同一资源'),
      if (f.current(NodeKind.resourceConflict).isNotEmpty)
        TextButton(onPressed: _tradeoff, child: const Text('记录我选择的聚焦、并行或暂缓')),
      _nodeList(NodeKind.consequence, title: '时间中的后果与恢复条件'),
      _nodeList(NodeKind.strengthMatch, title: '已有能力可以用在哪里'),
      _nodeList(NodeKind.boundaryReview, title: '自己能做的事与他人的自主'),
      const SizedBox(height: 10),
      TextButton.icon(
          onPressed: _ownRoute,
          icon: const Icon(Icons.edit_road_outlined),
          label: const Text('写下我自己的走法')),
      if (f.selectedRouteId != null)
        _primary('为这条路线做准备', _busy ? null : () => _go(4)),
    ]);
  }

  Widget _routeCard(MirrorNode route) {
    final fits = f
        .current(NodeKind.routeFit)
        .where((n) => n.text('routeId') == route.id)
        .toList();
    final fit = fits.isEmpty ? null : fits.last;
    final safe = EvidenceRules.routeCanBePrepared(route, f);
    final chosen = f.selectedRouteId == route.id;
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: MirrorCard(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(route.text('title'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 7),
              Text(route.text('description')),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                MirrorTag(humanValue(route.text('safety')),
                    icon: Icons.shield_outlined),
                MirrorTag(humanValue(route.text('reversibility')))
              ]),
              const SizedBox(height: 12),
              Text(
                  '满足什么：${route.strings('wantIds').map((id) => f.node(id)?.text('claim') ?? '待核实欲求').join('；')}'),
              Text(
                  '欲求适配：${fit == null ? '未知' : humanValue(fit.text('wantFit'))}'),
              Text(
                  '当前任务与能力：${fit == null ? '未核实' : humanValue(fit.text('bodySkillFit'))}'),
              Text(
                  '外部能否实施：${humanValue(fit?.text('externalFeasibility') ?? route.text('feasibility'))}'),
              Text(
                  '行动难度：${fit?.number('difficulty') == null ? '未知' : '${fit!.number('difficulty')} / 5'}'),
              if (fit != null) Text('认识与动机：${fit.text('motivationCognition')}'),
              const SizedBox(height: 12),
              Text('第一小步：${route.text('firstStep')}',
                  style: Theme.of(context).textTheme.titleSmall),
              for (final obstacle in f
                  .current(NodeKind.obstacle)
                  .where((n) => n.text('routeId') == route.id)
                  .take(2))
                TextButton.icon(
                    onPressed: () => _details(obstacle),
                    icon: const Icon(Icons.help_outline, size: 16),
                    label: Text('为什么可能卡住：${obstacle.text('statement')}')),
              for (final support in f
                  .current(NodeKind.supportVariant)
                  .where((n) => n.text('routeId') == route.id)
                  .take(2))
                TextButton.icon(
                    onPressed: () => _details(support),
                    icon: const Icon(Icons.alt_route, size: 16),
                    label: Text('支持或替代：${support.text('action')}')),
              Wrap(spacing: 6, children: [
                _sourceLink(route, label: '条件、日常过程与来源'),
                if (fit != null) _sourceLink(fit, label: '查看完整适配矩阵')
              ]),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                      onPressed: safe
                          ? () => _act(() => c.selectRoute(f.id, route.id))
                          : null,
                      child: Text(chosen
                          ? '已选这条走法'
                          : safe
                              ? '选择这条走法'
                              : '先核实限制或选择保护性路线'))),
            ])));
  }

  Future<void> _ownRoute() async {
    final value = await askText(context, title: '我自己的走法', questions: [
      const TextQuestion('title', '这条走法', required: true, lines: 1),
      const TextQuestion('step', '具体第一小步', required: true),
      const TextQuestion('conditions', '需要先具备哪些条件？')
    ]);
    if (value == null || !mounted) return;
    final safety = await chooseOption(context, title: '目前的现实门槛', options: {
      'clear': '我已核实，这一步满足当前安全与资格条件',
      'verify_first': '这一步只用于核实条件或保护性暂停',
      'blocked': '目前存在不允许实施的硬性限制'
    });
    if (safety == null) return;
    await _act(() => c.recordNode(f.id, NodeKind.route, {
          'title': value['title'],
          'description': value['title'],
          'firstStep': value['step'],
          'family': '本人提出',
          'wantIds': f
              .current(NodeKind.want)
              .where((n) => n.status == NodeStatus.accepted)
              .map((n) => n.id)
              .toList(),
          'conditions': value['conditions']!.isEmpty
              ? <String>[]
              : [value['conditions']!],
          'constraints': <String>[],
          'reversibility': 'unknown',
          'safety': safety,
          'feasibility': safety == 'blocked'
              ? 'infeasible'
              : safety == 'clear'
                  ? 'verified'
                  : 'conditional',
          'verify':
              value['conditions']!.isEmpty ? '尚有条件待核实' : value['conditions'],
          'protective': safety == 'verify_first',
          'dailyProcess': <String>[],
          'expectedBenefits': <String>[],
          'expectedCosts': <String>[],
          'explorationState': 'considered'
        }));
  }

  Future<void> _tradeoff() async {
    final mode = await chooseOption(context, title: '这次怎样安排投入？', options: {
      'retain': '先保留，继续核实',
      'parallel': '兼容的路线并行',
      'sequence': '先后安排',
      'reduce': '减少投入量',
      'defer': '暂缓，保留恢复条件',
      'switch': '改用其他手段',
      'drop': '本人明确放弃所选路线'
    });
    if (mode == null || !mounted) return;
    final routes = f.current(NodeKind.route);
    final chosen = <String>{if (f.selectedRouteId != null) f.selectedRouteId!};
    final deferred = <String>{};
    await mirrorSheet<void>(context,
        title: '这段时间，我怎样安排',
        child: StatefulBuilder(
            builder: (sheetContext, setState) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('可以同时保留兼容的路线。暂缓不会被记录为放弃；实际互斥仍需按来源核实。'),
                      for (final route in routes)
                        Column(children: [
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(route.text('title')),
                              subtitle:
                                  Text(mode == 'drop' ? '本人明确选择放弃' : '当前考虑投入'),
                              value: chosen.contains(route.id),
                              onChanged: (v) => setState(() {
                                    if (v == true) {
                                      chosen.add(route.id);
                                      deferred.remove(route.id);
                                    } else {
                                      chosen.remove(route.id);
                                    }
                                  })),
                          if (!chosen.contains(route.id))
                            CheckboxListTile(
                                dense: true,
                                title: const Text('稍后探索'),
                                value: deferred.contains(route.id),
                                onChanged: (v) => setState(() {
                                      if (v == true) {
                                        deferred.add(route.id);
                                      } else {
                                        deferred.remove(route.id);
                                      }
                                    }))
                        ]),
                      FilledButton(
                          onPressed: () async {
                            final details = await askText(sheetContext,
                                title: '保留恢复的条件',
                                questions: [
                                  const TextQuestion('restore', '什么时候重新考虑？',
                                      initial: '出现新的条件或资源时重新考虑',
                                      required: true),
                                  const TextQuestion('cost', '已经知道的真实代价（可不填）')
                                ]);
                            if (details == null) return;
                            await _act(
                                () => c.recordNode(f.id, NodeKind.tradeoff, {
                                      'selectedRouteIds': mode == 'drop'
                                          ? <String>[]
                                          : chosen.toList(),
                                      'deferredRouteIds': deferred.toList(),
                                      'abandonedRouteIds': mode == 'drop'
                                          ? chosen.toList()
                                          : <String>[],
                                      'mode': mode,
                                      'cost': details['cost'],
                                      'restoreCondition': details['restore'],
                                      'userConfirmed': true
                                    }));
                            if (sheetContext.mounted)
                              Navigator.pop(sheetContext);
                          },
                          child: const Text('保存阶段性安排')),
                    ])));
  }
}
