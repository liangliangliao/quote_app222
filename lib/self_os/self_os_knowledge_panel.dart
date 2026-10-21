part of 'self_os_workbench.dart';

extension _KnowledgePanel on _SelfOsWorkbenchState {
  List<Widget> knowledgePanel() {
    final missing = SelfOsV37Rules.representationGaps(s);
    return [
      gateCard(),
      OsSection(
          title: '认识完整性 · 只补会改变决定的部分',
          subtitle: '先保存 K1，再获取证据、展开后果，最后说明 K2 怎样改变动机场。',
          children: [
            Wrap(children: [
              ai('识别缺口并对称补全', 'gmrc'),
              button('手动记录关键未知', Icons.help_outline, () => editGap()),
              button('开始一次认识更新', Icons.compare_arrows, () async {
                c.beginCognition();
                await changed();
              })
            ]),
            if (s.knowledgeBefore != null)
              OsNote(
                  '已保存补全前快照：${osText(s.knowledgeBefore!['knowledge']).isEmpty ? '当时的认识尚未记录' : s.knowledgeBefore!['knowledge']}'),
            if (missing.isNotEmpty)
              ExpansionTile(
                  key: const ValueKey('representation_gaps'),
                  tilePadding: EdgeInsets.zero,
                  title: Text('${missing.length} 项结构性检查'),
                  subtitle: const Text('选项、效价、时间、因果、抽象度、累积、条件'),
                  children: [
                    for (final g in missing)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              '${osRepresentationKinds[g.kind]}${g.routeId.isEmpty ? '' : ' · ${routeNames[g.routeId]}'}'),
                          subtitle: Text(g.reason),
                          trailing: g.routeId.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '说明本次不适用',
                                  icon: const Icon(Icons.rule),
                                  onPressed: () => waiveDimension(g))),
                  ]),
            for (final warning in SelfOsV37Rules.symmetryWarnings(s))
              OsNote(warning),
            if (missing.isEmpty) const OsNote('当前已表示的关键维度已覆盖。覆盖完整不代表所有推断已经证实。'),
          ]),
      for (final gap in s.gaps)
        OsSection(
            title: gap.text('question'),
            subtitle: '${osGapKinds[gap.kind]} · ${gap.text('reason')}',
            trailing: IconButton(
                tooltip: '编辑关键未知',
                onPressed: () => editGap(gap),
                icon: const Icon(Icons.edit_outlined)),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                OsPill(gap.resolvedBy(s.evidence, DateTime.now())
                    ? '已有可用证据'
                    : '仍待补证据'),
                OsPill(
                    {
                      'flip': '不同答案会翻转选择',
                      'stable': '已记录的情景不改变选择',
                      'unknown': '对选择的敏感性未知'
                    }[gap.sensitivity]!,
                    color: osGold),
                OsPill({
                      'private': 'ASK · 私有事实',
                      'public': 'RETRIEVE · 公共资料',
                      'experience': 'EXPERIMENT · 现实样本'
                    }[gap.text('access')] ??
                    '获取方式待确认')
              ]),
              const SizedBox(height: 12),
              if (gap.text('lowScenario').isNotEmpty)
                text(
                    '如果 ${gap.text('lowScenario')} → ${routeNames[gap.text('lowChoice')] ?? '选择尚不明确'}'),
              if (gap.text('highScenario').isNotEmpty)
                text(
                    '如果 ${gap.text('highScenario')} → ${routeNames[gap.text('highChoice')] ?? '选择尚不明确'}'),
              Wrap(children: [
                button('关联回答与证据', Icons.link, () async {
                  final ids = await pickEvidence(gap.strings('evidenceIds'));
                  if (ids != null && mounted)
                    await update((d) => d.gaps
                        .firstWhere((g) => g.id == gap.id)
                        .data['evidenceIds'] = ids);
                }),
                if (gap.text('access') == 'public')
                  button('读取原文来源', Icons.travel_explore,
                      retrieving ? null : retrieveSource),
                if (gap.text('access') == 'experience')
                  button('安排现实实验', Icons.science_outlined, () {
                    section = 3;
                    redraw();
                  }),
                if (gap.text('access') == 'private')
                  button('记录我的事实回答', Icons.edit_note, () => editEvidence())
              ]),
            ]),
      OsSection(
          title: '证据台账',
          subtitle: '重要主张保留来源、核验状态、置信度、时效与反证。来源冲突会阻止直接承诺。',
          children: [
            Wrap(children: [
              button('添加材料 / 私有事实', Icons.add, () => editEvidence()),
              button(retrieving ? '正在读取来源…' : '读取 HTTPS 原文', Icons.public,
                  retrieving ? null : retrieveSource)
            ]),
            if (retrieving) const LinearProgressIndicator(),
            if (s.evidence.isEmpty)
              const OsNote('尚无可追溯证据。AI 的解释、链接或想象场景不会自动成为已核实事实。'),
            for (final e in s.evidence)
              OsRecordCard(
                  title: e.claim,
                  onEdit: () => editEvidence(e),
                  tag: osEpistemicLabels[e.effectiveLabel],
                  children: [
                    text(
                        '来源：${e.text('source').isEmpty ? '尚未记录' : e.text('source')}'),
                    if (e.text('quote').isNotEmpty)
                      text('摘录：${e.text('quote')}'),
                    text(
                        '记录于 ${osMoment(e.date('observedAt'))} · ${e.text('contradiction') == 'conflict' ? '来源冲突' : e.freshAt(DateTime.now()) ? '时效范围内' : '缺少时点 / 已过期'} · 置信度 ${e.number('confidence')?.toStringAsFixed(0) ?? '未知'}'),
                    if (e.text('counter').isNotEmpty)
                      text('反证 / 冲突详情：${e.text('counter')}'),
                    if (Uri.tryParse(e.text('source'))?.scheme == 'https')
                      TextButton.icon(
                          onPressed: () => openSource(e.text('source')),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('查看原文')),
                  ]),
          ]),
      OsSection(
          title: '因果地平线',
          subtitle: '追踪决定相关的中间状态。远期包含更多条件；回路闭环呈现，未知处停止延伸。',
          children: [
            Wrap(children: [
              ai('展开多阶与条件分支', 'horizon'),
              button('添加后果节点', Icons.add, () => editNode()),
              button(
                  '连接条件 / 反馈', Icons.account_tree_outlined, () => editEdge()),
              button('记录未来路径变化', Icons.alt_route, editFutureOption)
            ]),
            SelfOsHorizonView(
                state: s,
                onEditNode: editNode,
                onExpand: (node) async {
                  await update((d) => d.settings['focusNodeId'] = node.id);
                  if (mounted) await widget.onAi('v37.horizon');
                },
                onFutureRoute: adoptFutureRoute),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('全部节点与连线 · ${s.nodes.length} / ${s.edges.length}'),
                children: [
                  for (final n in s.nodes)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(n.title),
                        subtitle: Text(
                            '${routeNames[n.routeId]} · 第${n.order}阶 · ${osEpistemicLabels[n.label]}'),
                        onTap: () => editNode(n),
                        trailing: IconButton(
                            tooltip: '关联节点证据',
                            icon: const Icon(Icons.link),
                            onPressed: () async {
                              final ids = await pickEvidence(n.evidenceIds);
                              if (ids != null && mounted)
                                await update((d) => d.nodes
                                    .firstWhere((v) => v.id == n.id)
                                    .data['evidenceIds'] = ids);
                            })),
                  for (final e in s.edges)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            Text('${nodeNames[e.from]} → ${nodeNames[e.to]}'),
                        subtitle: Text(e.text('condition')),
                        onTap: () => editEdge(e),
                        trailing: IconButton(
                            tooltip: '关联因果依据',
                            icon: const Icon(Icons.link),
                            onPressed: () async {
                              final ids = await pickEvidence(e.evidenceIds);
                              if (ids != null && mounted)
                                await update((d) => d.edges
                                    .firstWhere((v) => v.id == e.id)
                                    .data['evidenceIds'] = ids);
                            })),
                ]),
          ]),
      reentryCard(),
    ];
  }

  Future<void> waiveDimension(OsRepresentationGap gap) async {
    final v = await osRecordEditor(context,
        title: '说明这个维度为何不适用',
        fields: const [
          OsInput('reason', '依据是什么？缺少信息应保留未知，不能当作不适用', required: true)
        ]);
    if (v == null || !mounted) return;
    await update((d) {
      final all = osMap(d.settings['coverageExceptions']);
      final route = osMap(all[gap.routeId]);
      route[gap.kind] = v['reason'];
      all[gap.routeId] = route;
      d.settings['coverageExceptions'] = all;
    });
  }

  Future<void> editGap([OsGap? gap]) async {
    final v = await osRecordEditor(context,
        title: '哪一个未知可能改变决定？',
        initial: gap?.toJson() ?? {'kind': 'fact', 'access': 'private'},
        fields: [
          const OsInput('question', '关键问题', required: true),
          const OsInput('kind', '缺口类别', required: true, options: osGapKinds),
          const OsInput('reason', '它为什么会影响路线、动机或损失？', required: true),
          const OsInput('access', '怎样获取', required: true, options: {
            'private': '向我询问私有事实',
            'public': '获取可追溯公共资料',
            'experience': '只能用现实实验了解'
          }),
          const OsInput('lowScenario', '合理情景一（不编造概率）'),
          OsInput('lowChoice', '情景一我会选哪条路？',
              options: {'': '仍不能判断', ...routeNames}),
          const OsInput('highScenario', '合理情景二'),
          OsInput('highChoice', '情景二我会选哪条路？',
              options: {'': '仍不能判断', ...routeNames}),
          const OsInput('unavailable', '关键资料目前不可得 / 无法降低这个未知', kind: 'bool'),
          const OsInput('irrelevant', '经比较，这个问题不影响当前决定', kind: 'bool'),
        ],
        note: '不同情景指向不同路线时标记“会翻转选择”。相同则允许停止搜索；缺失答案仍为未知。');
    if (v == null || !mounted) return;
    await update((d) => put(d.gaps, OsGap(v)));
  }

  Future<void> editEvidence(
      [OsEvidence? evidence, OsSourceDocument? document]) async {
    final v = await osRecordEditor(context,
        title: document == null ? '记录证据与认识边界' : '核对来源与摘录',
        initial: evidence?.toJson() ??
            {
              'label': document == null ? 'unknown' : 'external',
              'source': document?.url ?? '',
              'observedAt':
                  (document?.fetchedAt ?? DateTime.now()).toIso8601String(),
              'contradiction': 'unchecked',
              'verified': false,
            },
        fields: const [
          OsInput('claim', '与决定相关的具体主张', required: true),
          OsInput('label', '认识性质', required: true, options: osEpistemicLabels),
          OsInput('source', '来源：原文链接 / 个人经历 / 行动记录', required: true),
          OsInput('quote', '原文摘录或可核对的观察'),
          OsInput('observedAt', '记录 / 获取时间', kind: 'datetime', required: true),
          OsInput('validUntil', '何时失效或应重新核验？', kind: 'datetime'),
          OsInput('confidence', '我对这条材料的可信度（未知留空）', kind: 'number'),
          OsInput('contradiction', '与已有证据的关系', required: true, options: {
            'unchecked': '尚未检查冲突',
            'clear': '已检查，未发现冲突',
            'conflict': '存在冲突，需保留并核验'
          }),
          OsInput('counter', '反证、冲突内容与适用条件'),
          OsInput('verified', '我已检查原始材料及其适用范围', kind: 'bool'),
        ],
        note: document == null
            ? '模型推断和模拟不会因打勾变成已核实事实。事实需要原始来源，个人经验注明具体情境。'
            : '已读取：${document.url}\n下面保存的摘录必须存在于这次读取的正文。来源可读不等于主张已被证明。',
        validate: (v) {
      if (document != null &&
          (!document.containsQuote(osText(v['quote'])) ||
              v['source'] != document.url)) return '请保留实际来源链接，并从已读取正文选取原文摘录';
      final start = DateTime.tryParse(osText(v['observedAt']));
      final end = DateTime.tryParse(osText(v['validUntil']));
      if (start != null && start.isAfter(DateTime.now())) return '获取时间不能在未来';
      if (start != null && end != null && end.isBefore(start))
        return '有效期不能早于获取时间';
      return null;
    });
    if (v == null || !mounted) return;
    c.beginCognition();
    await update((d) => put(d.evidence, OsEvidence(v)));
  }

  Future<void> openSource(String url) async {
    try {
      final ok = await launchUrl(SelfOsSourceService.checkedUrl(url),
          mode: LaunchMode.externalApplication);
      if (!ok && mounted) osMessage(context, '暂时无法打开来源，请复制链接到浏览器');
    } catch (_) {
      if (mounted) osMessage(context, '来源链接无效或浏览器不可用');
    }
  }

  Future<void> retrieveSource() async {
    final v = await osRecordEditor(context,
        title: '读取你选择的公共来源',
        fields: const [OsInput('url', 'HTTPS 原文链接', required: true)],
        note: '仅访问你填写的链接。不会把个人案例或 API 配置发送到来源网站。');
    if (v == null || !mounted) return;
    retrieving = true;
    redraw();
    try {
      final doc = await SelfOsSourceService().retrieve(osText(v['url']));
      if (!mounted) return;
      retrieving = false;
      redraw();
      final next = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('已读取的原文'),
                  content: SizedBox(
                      width: 540,
                      child: SingleChildScrollView(
                          child: SelectableText(doc.text))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('暂不记录')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('记录相关摘录'))
                  ]));
      if (next == true && mounted) await editEvidence(null, doc);
    } catch (e) {
      if (mounted)
        osMessage(
            context,
            e is FormatException
                ? e.message
                : '读取超时或来源不可用。请在浏览器核验后手动记录，已有数据保留。');
    } finally {
      retrieving = false;
      redraw();
    }
  }

  Future<void> editNode([OsConsequence? node]) async {
    if (s.routes.isEmpty) {
      osMessage(context, '先保存一条候选路径');
      return;
    }
    final v = await osRecordEditor(context,
        title: '一个决定相关的后果 / 状态',
        initial: node?.toJson() ??
            {
              'routeId': s.routes.first.id,
              'order': 1,
              'horizon': 'now',
              'valence': 'mixed',
              'label': 'unknown',
              'relevance': 'high'
            },
        fields: [
          OsInput('routeId', '属于哪条路径？', options: routeNames, required: true),
          const OsInput('title', '结果或状态', required: true),
          const OsInput('concrete', '在现实中具体意味着什么？', required: true),
          const OsInput('order', '第几阶后果（1–12）',
              kind: 'number', max: 12, required: true),
          const OsInput('horizon', '时间跨度', options: osHorizons, required: true),
          const OsInput('valence', '收益 / 代价',
              options: osValences, required: true),
          const OsInput('label', '证据标签',
              options: osEpistemicLabels, required: true),
          const OsInput('stateType', '改变什么状态？能力、资源、关系、健康、机会…'),
          const OsInput('relevance', '与当前决定的相关性', options: {
            'high': '高 · 可能改变选择',
            'medium': '中 · 帮助理解',
            'low': '低 · 默认剪枝'
          }),
          const OsInput('cumulative', '依赖重复累积', kind: 'bool'),
          const OsInput('threshold', '达到什么条件 / 阈值后才可能改变？'),
          const OsInput('lockIn', '之后改道会更贵、更难或被锁定吗？'),
          const OsInput('reversibleWindow', '在哪个节点、何种条件下仍可回头？'),
          const OsInput('counter', '反证、关键未知、适用范围'),
          const OsInput('prune', '停止继续向后延伸', kind: 'bool'),
          const OsInput('pruneReason', '剪枝原因：相关性、未知、负担或新增信息不足'),
          const OsInput('observedOutcome', '后续真实结果（未发生就留空）'),
          const OsInput('observedAt', '后续结果观察时间', kind: 'datetime'),
        ], validate: (v) {
      if ((osNumber(v['order'], 12) ?? 0) < 1) return '阶数从 1 开始';
      if (osText(v['observedOutcome']).isNotEmpty &&
          osText(v['observedAt']).isEmpty) return '真实结果需要观察时间';
      final at = DateTime.tryParse(osText(v['observedAt']));
      if (at != null && at.isAfter(DateTime.now())) return '尚未发生的结果不能记录为实际观察';
      try {
        final draft = s.copy();
        put(draft.nodes, OsConsequence(v));
        draft.validate();
        return null;
      } on FormatException catch (e) {
        return e.message;
      }
    });
    if (v == null || !mounted) return;
    c.beginCognition();
    await update((d) {
      if (node != null)
        d.causalTraces.add({
          'id': selfOsId(),
          'before': node.toJson(),
          'after': osClone(v),
          'at': DateTime.now().toIso8601String()
        });
      put(d.nodes, OsConsequence(v));
    });
  }

  Future<void> editEdge([OsCausalEdge? edge]) async {
    if (s.nodes.length < 2) {
      osMessage(context, '先保存至少两个后果节点，再连接条件关系');
      return;
    }
    final v = await osRecordEditor(context,
        title: '条件关系 / 反馈回路',
        initial: edge?.toJson() ??
            {'label': 'unknown', 'branch': 'base', 'loop': 'none'},
        fields: [
          OsInput('from', '前一状态', options: nodeNames, required: true),
          OsInput('to', '后一状态', options: nodeNames, required: true),
          const OsInput('condition', '满足什么条件时才可能发生？', required: true),
          const OsInput('basis', '因果依据；推断必须说明', required: true),
          const OsInput('label', '依据性质',
              options: osEpistemicLabels, required: true),
          const OsInput('branch', '情景束',
              options: {'base': '基准', 'upside': '有利条件', 'downside': '不利条件'}),
          const OsInput('signal', '哪个现实信号说明进入这条分支？'),
          const OsInput('loop', '是否反馈到先前状态？', options: {
            'none': '普通条件关系',
            'reinforcing': '强化回路',
            'balancing': '平衡回路'
          }),
          const OsInput('breakCondition', '什么条件可以打断 / 改变这个回路？'),
          const OsInput('probabilityNote', '概率或范围的依据（未知不编数字）'),
        ], validate: (v) {
      try {
        final d = s.copy();
        put(d.edges, OsCausalEdge(v));
        d.validate();
        return null;
      } on FormatException catch (e) {
        return e.message;
      }
    });
    if (v == null || !mounted) return;
    c.beginCognition();
    await update((d) => put(d.edges, OsCausalEdge(v)));
  }

  Future<void> editFutureOption() async {
    if (s.nodes.isEmpty) {
      osMessage(context, '先建立后果节点，再关联未来可选路径');
      return;
    }
    final v = await osRecordEditor(context,
        title: '这会怎样改变未来的选择？',
        initial: {'delta': 'opened'},
        fields: [
          OsInput('routeId', '当前候选路线', options: routeNames, required: true),
          OsInput('nodeId', '由哪个状态变化带来？', options: nodeNames, required: true),
          const OsInput('title', '未来的一条具体路径', required: true),
          const OsInput('delta', '选择空间的变化',
              options: osOptionDeltas, required: true),
          const OsInput('condition', '依赖什么条件？哪里仍不确定？', required: true),
        ],
        validate: (v) =>
            s.nodes.firstWhere((n) => n.id == v['nodeId']).routeId !=
                    v['routeId']
                ? '请选择属于同一路线的因果节点'
                : null);
    if (v != null && mounted)
      await update((d) => d.futureOptions.add(OsFutureOption(v)));
  }

  Widget reentryCard() => OsSection(
          title: '把新认识带回动机场',
          subtitle: '新增文本不等于完成补全。明确哪个动机新增、增强、减弱或失效，再把选择交回给你。',
          children: [
            for (final suggestion in c.suggestions['v37.reentry'] ?? [])
              OsNote('${suggestion['title']} · ${{
                    'added': '可能新增',
                    'strengthened': '可能增强',
                    'weakened': '可能减弱',
                    'invalidated': '可能失效'
                  }[suggestion['change']] ?? '待判断'}\n依据：${suggestion['reason']}'),
            Wrap(children: [
              button('调整动机与注意位置', Icons.tune, () {
                section = 2;
                redraw();
              }),
              button('记录 K2 与变化关系', Icons.compare_arrows, finishCognition,
                  primary: true)
            ]),
            text(SelfOsV37Rules.stopAdvice(s)),
            for (final trace in s.knowledgeTraces.reversed.take(3))
              OsRecordCard(
                  title:
                      trace['status'] == 'rebuilt' ? '认识已重新进入动机场' : '新信息未改变决定',
                  children: [
                    text(
                        '之前：${osMap(trace['before'])['knowledge']}\n之后：${osMap(trace['after'])['knowledge']}'),
                    text(osText(trace['reason'])),
                    for (final d in osMaps(trace['delta']))
                      text('${d['title']} · ${{
                        'added': '新增',
                        'strengthened': '增强',
                        'weakened': '减弱',
                        'invalidated': '失效',
                        'availability': '可用性变化'
                      }[d['change']]}'),
                    if (osText(trace['noChangeReason']).isNotEmpty)
                      text('停止准备的依据：${trace['noChangeReason']}'),
                  ]),
          ]);

  Future<void> finishCognition() async {
    if (!s.cognitionOpen) {
      c.beginCognition();
      await changed();
      if (mounted) osMessage(context, '已记录当前基线。调整认识与动机后，再完成这次更新。');
      return;
    }
    final v = await osRecordEditor(context, title: '保存 K2 与动机变化', initial: {
      'k2': c.text('k2')
    }, fields: const [
      OsInput('k2', '更完整且仍可修正的认识 K2', required: true),
      OsInput('reason', '哪条证据改变了哪个动机？', required: true),
      OsInput('noChangeReason', '若动机场未变，为什么可以停止继续准备？'),
    ], validate: (v) {
      final probe = c.copy();
      probe.fields['k2'] = osText(v['k2']);
      try {
        probe.completeCognition(osText(v['reason']),
            noChangeReason: osText(v['noChangeReason']));
        return null;
      } on FormatException catch (e) {
        return e.message;
      }
    });
    if (v == null || !mounted) return;
    c.fields['k2'] = osText(v['k2']);
    c.completeCognition(osText(v['reason']),
        noChangeReason: osText(v['noChangeReason']));
    await changed();
  }
}
