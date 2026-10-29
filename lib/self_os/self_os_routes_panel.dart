part of 'self_os_workbench.dart';

extension _RoutesPanel on _SelfOsWorkbenchState {
  List<Widget> routesPanel() => [
        gateCard(),
        OsSection(
            title: '先扩面，再收线',
            subtitle: '当前手段只是候选之一。不同机制之间比较，而不是给同一方案换名字。',
            children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final phase in osPhases.entries)
                  ChoiceChip(
                      label: Text(phase.value),
                      selected: s.text('phase') == phase.key,
                      onSelected: (_) async {
                        if (phase.key == 'commit' &&
                            !SelfOsV37Rules.gate(s).mayCommit) {
                          osMessage(context, '先完成认识闸门，再进入承诺');
                          return;
                        }
                        await update((d) => d.settings['phase'] = phase.key);
                      })
              ]),
              const SizedBox(height: 12),
              text(
                  '已覆盖 ${s.routes.map((r) => r.mechanism).toSet().length} 类结构 · ${s.routes.length} 条候选'),
              if (s.routes.length < 2 && !s.flag('expansionSkipped'))
                const OsNote('目前只看到一条实现路径。推荐先扩面；本次无需展开时也可以写明原因。'),
              Wrap(children: [
                ai('扩展不同机制的路径', 'routes'),
                button('手动添加路径', Icons.add, () => editRoute()),
                button('先辨认真正欲求', Icons.spa_outlined,
                    () => widget.onEngine(SelfOsEngine.desire)),
                button('扩面边界', Icons.filter_alt_outlined, expansionBoundary)
              ]),
              for (final reason in SelfOsV37Rules.expansionStop(s))
                OsNote(reason),
            ]),
        for (final warning
            in SelfOsInsights.pathGuard(widget.history, widget.profile))
          OsNote(warning, icon: Icons.route_outlined),
        for (final route in s.routes)
          OsSection(
              title: route.title,
              subtitle:
                  '${osMechanisms[route.mechanism]} · ${route.text('mechanismDetail')}',
              trailing: IconButton(
                  tooltip: '编辑路径',
                  onPressed: () => editRoute(route),
                  icon: const Icon(Icons.edit_outlined)),
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OsPill(selfOsRouteStates[route.status] ?? '候选'),
                  OsPill(
                      '个人适配 ${route.alignment?.toStringAsFixed(0) ?? '未知'} · ${route.fit.values.whereType<double>().length}/6 已记录'),
                  OsPill(
                      '一般价值 ${route.number('generalValue')?.toStringAsFixed(0) ?? '未知'}')
                ]),
                const SizedBox(height: 12),
                text('实施难度：${const {
                          'unknown': '未知',
                          'low': '较低',
                          'medium': '中等',
                          'high': '较高'
                        }[route.text('difficulty')] ?? '未知'} · '
                    '依据：${route.text('difficultyBasis').isEmpty ? '尚待核实' : route.text('difficultyBasis')}。与欲求一致性和安全分别判断。'),
                for (final e in {
                  'desire': '服务欲求',
                  'ability': '能力与训练',
                  'strength': '可用力量',
                  'cost': '完整代价',
                  'reality': '现实条件',
                  'opportunityCost': '机会成本',
                  'relation': '与主线关系'
                }.entries)
                  if (route.text(e.key).isNotEmpty)
                    text('${e.value}：${route.text(e.key)}'),
                if (route.text('cost').isEmpty || route.text('ability').isEmpty)
                  const OsNote('能力或代价仍未展开。兴趣与通常价值不能代替个人适配证据。'),
                DropdownButtonFormField<String>(
                    key: ValueKey(
                        'route_status_${route.id}_${route.status}_$routeSelectionRevision'),
                    isExpanded: true,
                    initialValue: route.status,
                    decoration: const InputDecoration(labelText: '投入方式'),
                    items: selfOsRouteStates.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) async {
                      if (v != null && v != route.status) {
                        await widget.onRouteState(route, v);
                        routeSelectionRevision++;
                        redraw();
                      }
                    }),
                const SizedBox(height: 10),
                Wrap(children: [
                  button('关联路线证据', Icons.link, () async {
                    final ids = await pickEvidence(route.evidenceIds);
                    if (ids != null && mounted)
                      await update((d) => d.routes
                          .firstWhere((r) => r.id == route.id)
                          .data['evidenceIds'] = ids);
                  }),
                  button('查看这条路的后果', Icons.account_tree_outlined, () {
                    section = 1;
                    redraw();
                  })
                ]),
              ]),
        if (c.routeStatus == 'active')
          const OsNote('当前主线已集中投入。新的机会先比较：增强、补充、竞争、替代还是分散；允许现实证据推动转向。'),
      ];

  Future<void> expansionBoundary() async {
    final v = await osRecordEditor(context,
        title: '这次何时停止扩面？',
        initial: s.settings,
        fields: const [
          OsInput('constraintsCovered', '关键现实约束已覆盖', kind: 'bool'),
          OsInput('expansionSkipped', '本次选择无需进一步扩面', kind: 'bool'),
          OsInput('expansionReason', '停止或跳过的依据', required: true),
          OsInput('triggerSource', '新目标主要从哪里来？', options: {
            'evidence': '现实新证据',
            'novelty': '新鲜感',
            'comparison': '他人的成功 / 羡慕',
            'escape': '想离开当前不适',
            'unknown': '仍不确定'
          }),
          OsInput('fullLifePicture', '这条生活的完整日常、压力、能力要求与代价'),
          OsInput('fullLifeAccepted', '连同完整生活结构，我仍愿意认真验证', kind: 'bool'),
        ]);
    if (v != null && mounted) await update((d) => d.settings.addAll(v));
  }

  Future<void> editRoute([OsRoute? route]) async {
    final v = await osRecordEditor(context,
        title: route == null ? '添加一条不同的路径' : '比较这条路径',
        initial: route?.toJson() ??
            {'mechanism': 'alternative', 'status': 'experimental'},
        fields: const [
          OsInput('title', '路径名称', required: true),
          OsInput('mechanism', '路径机制', required: true, options: osMechanisms),
          OsInput('mechanismDetail', '为什么它与已有路径结构不同？', required: true),
          OsInput('desire', '服务哪个真实欲求？'),
          OsInput('ability', '需要什么能力？哪些有证据，哪些可训练？'),
          OsInput('strength', '哪些力量可用？证据是什么？'),
          OsInput('cost', '完整代价：时间、压力、资源与不确定性'),
          OsInput('reality', '现实约束与尚未满足的条件'),
          OsInput('difficulty', '当前实施难度（独立判断）', options: {
            'unknown': '尚不清楚',
            'low': '较低',
            'medium': '中等',
            'high': '较高'
          }),
          OsInput('difficultyBasis', '难在哪里？依据、可降低阻力的支持与未知'),
          OsInput('opportunityCost', '选择它会让什么让位？'),
          OsInput('relation', '与当前主线的关系', options: {
            'enhance': '增强',
            'support': '补充',
            'compete': '竞争',
            'replace': '替代',
            'distract': '分散',
            'unknown': '待比较'
          }),
          OsInput('source', '候选来自什么信息或经历？'),
          OsInput('generalValue', '通常意义的价值（0–100，未知留空）', kind: 'number'),
          OsInput('desireFit', '欲求匹配（0–100）', kind: 'number'),
          OsInput('abilityFit', '能力匹配（0–100）', kind: 'number'),
          OsInput('personalFit', '个人适配（0–100）', kind: 'number'),
          OsInput('strengthFit', '力量适配（0–100）', kind: 'number'),
          OsInput('costAcceptance', '代价接受（0–100）', kind: 'number'),
          OsInput('realityFit', '现实可行性（0–100）', kind: 'number'),
        ],
        note: '这些数字是你的暂估，缺失项保持未知。主路线必须通过独立的取舍确认。');
    if (v == null || !mounted) return;
    final next = OsRoute(v);
    await update((d) => put(d.routes, next));
  }

  Future<void> adoptFutureRoute(OsFutureOption option) async {
    final v = await osRecordEditor(context, title: '把未来路径带回选择空间', initial: {
      'title': option.text('title'),
      'mechanism': 'conditions',
      'mechanismDetail': option.text('condition'),
      'source': '来自因果地平线：${osOptionDeltas[option.delta]}；仍需现实验证',
      'status': 'experimental',
      'originFutureOptionId': option.id,
    }, fields: const [
      OsInput('title', '候选路径', required: true),
      OsInput('mechanism', '机制', options: osMechanisms, required: true),
      OsInput('mechanismDetail', '哪些条件出现后才可行？', required: true),
      OsInput('cost', '探索这条路的代价')
    ]);
    if (v == null || !mounted) return;
    await update((d) {
      final r = OsRoute(v);
      d.routes.add(r);
      d.futureOptions
          .firstWhere((e) => e.id == option.id)
          .data['linkedRouteId'] = r.id;
    });
    section = 0;
    redraw();
  }
}
