import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'self_os_models.dart';
import 'self_os_v37_rules.dart';
import 'self_os_widgets.dart';
import 'self_os_workbench_widgets.dart';

class SelfOsHorizonView extends StatefulWidget {
  const SelfOsHorizonView(
      {super.key,
      required this.state,
      required this.onEditNode,
      required this.onExpand,
      required this.onFutureRoute});
  final SelfOsV37 state;
  final ValueChanged<OsConsequence> onEditNode, onExpand;
  final ValueChanged<OsFutureOption> onFutureRoute;
  @override
  State<SelfOsHorizonView> createState() => _SelfOsHorizonViewState();
}

class _SelfOsHorizonViewState extends State<SelfOsHorizonView> {
  int _horizon = 0;
  bool _options = false, _showUncertain = false;
  String? _route;
  static const _certainty = {
    'direct': '直接证据',
    'supported': '支持性推断',
    'scenario': '情景 · 待现实验证',
    'unknown': '这里开始不确定'
  };

  void _inspect(OsConsequence node, String certainty) {
    final s = widget.state;
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * .78,
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                    children: [
                      Text(node.title,
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OsPill('第 ${node.order} 阶'),
                        OsPill(osHorizons[node.horizon]!),
                        OsPill(_certainty[certainty]!, color: osGold)
                      ]),
                      const SizedBox(height: 12),
                      Text(
                          node.text('concrete').isEmpty
                              ? '现实含义仍待补全'
                              : node.text('concrete'),
                          style: const TextStyle(height: 1.6)),
                      for (final item in {
                        'stateType': '改变的状态',
                        'counter': '反证 / 未知',
                        'threshold': '累积阈值',
                        'lockIn': '路径依赖 / 改道成本',
                        'reversibleWindow': '可逆窗口'
                      }.entries)
                        if (node.text(item.key).isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child:
                                  Text('${item.value}：${node.text(item.key)}')),
                      const SizedBox(height: 16),
                      Text('证据标签：${osEpistemicLabels[node.label]}；候选标签不等于已核实。'),
                      if (node.flag('calibrationNeedsReview'))
                        const OsNote('实际反馈使原推断需要修订，后续推演已暂停。请保留原预期，并根据反证调整条件。'),
                      for (final observation
                          in osMaps(node.data['observations']).reversed.take(3))
                        OsNote(
                            '实际观察：${observation['result']}\n适用范围：${observation['scope']}\n复盘记录：${observation['reviewId']}'),
                      if (node.evidenceIds.isEmpty)
                        const OsNote('尚未关联可追溯证据。此节点保留为推断、模拟或未知。'),
                      for (final e in s.evidence
                          .where((e) => node.evidenceIds.contains(e.id)))
                        OsNote(
                            '${e.claim}\n${osEpistemicLabels[e.effectiveLabel]} · ${e.text('source')}\n${e.text('contradiction') == 'conflict' ? '来源冲突' : e.freshAt(DateTime.now()) ? '时效范围内' : '未记录时点或已过期'}'),
                      for (final e in s.edges.where((e) => e.from == node.id))
                        OsRecordCard(
                            title: e.isLoop
                                ? '↺ ${e.text('loop') == 'reinforcing' ? '强化' : '平衡'}回路'
                                : '下一阶 · ${s.nodes.where((n) => n.id == e.to).first.title}',
                            tag: e.text('branch').isEmpty
                                ? '条件关系'
                                : {
                                      'base': '基准情景',
                                      'upside': '有利分支',
                                      'downside': '不利分支'
                                    }[e.text('branch')] ??
                                    '条件分支',
                            children: [
                              Text(
                                  '条件：${e.text('condition')}\n依据：${e.text('basis')}',
                                  style: const TextStyle(height: 1.6)),
                              Text(
                                  '关系置信度：${_certainty[SelfOsV37Rules.evidenceCertainty(s, e.text('label'), e.evidenceIds)]}'),
                              for (final proof in s.evidence
                                  .where((v) => e.evidenceIds.contains(v.id)))
                                Text(
                                    '关系来源：${proof.text('source')} · ${proof.claim}'),
                              if (e.text('signal').isNotEmpty)
                                Text('可观察信号：${e.text('signal')}'),
                              if (e.isLoop)
                                Text(
                                    '打断条件：${e.text('breakCondition').isEmpty ? '尚待确认' : e.text('breakCondition')}'),
                              if (e.text('probabilityNote').isNotEmpty)
                                Text('概率边界：${e.text('probabilityNote')}'),
                            ]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 10, runSpacing: 8, children: [
                        OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              widget.onEditNode(node);
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('编辑节点与证据')),
                        FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              widget.onExpand(node);
                            },
                            icon: const Icon(Icons.account_tree_outlined),
                            label: const Text('继续向后展开')),
                      ]),
                    ]))));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (_route != null && !s.routes.any((r) => r.id == _route)) _route = null;
    final paths = SelfOsV37Rules.causalPaths(s, routeId: _route);
    final pathIds = paths.expand((p) => p.nodes.map((n) => n.id)).toSet();
    final certainty = <String, String>{};
    const rank = ['unknown', 'scenario', 'supported', 'direct'];
    for (final path in paths) {
      for (final n in path.nodes) {
        final previous = certainty[n.id];
        final nodeCertainty = path.nodeCertainties[n.id] ?? path.certainty;
        if (previous == null ||
            rank.indexOf(nodeCertainty) < rank.indexOf(previous))
          certainty[n.id] = nodeCertainty;
      }
    }
    final visible = s.nodes.where((n) {
      if (_route != null && n.routeId != _route) return false;
      if (!_showUncertain && !pathIds.contains(n.id)) return false;
      return switch (_horizon) {
        0 => n.order <= 2,
        1 => n.order >= 3 && n.order <= 5,
        _ => n.horizon == 'long' || n.order >= 4
      };
    }).toList()
      ..sort((a, b) {
        final c = a.order.compareTo(b.order);
        return c == 0 ? a.id.compareTo(b.id) : c;
      });
    final levels = visible.map((n) => n.order).toSet().toList()..sort();
    final height =
        126.0 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
    const width = 244.0, gap = 68.0;
    final rows = <int, int>{};
    final positions = <String, Offset>{};
    for (final n in visible) {
      final row = rows[n.order] ?? 0;
      positions[n.id] = Offset(18 + levels.indexOf(n.order) * (width + gap),
          22 + row * (height + 30));
      rows[n.order] = row + 1;
    }
    final graphSize = Size(
        math.max(340, levels.length * (width + gap) + 36),
        math.max(
            300,
            (rows.values.isEmpty ? 1 : rows.values.reduce(math.max)) *
                    (height + 30) +
                40));
    final edges = s.edges
        .where(
            (e) => positions.containsKey(e.from) && positions.containsKey(e.to))
        .toList();
    final deltas = s.futureOptions
        .where((o) => _route == null || o.text('routeId') == _route)
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final item
            in {0: '近景 · 1–2 跳', 1: '中景 · 3–5 跳', 2: '远景 · 长期状态'}.entries)
          ChoiceChip(
              key: ValueKey('horizon_${item.key}'),
              label: Text(item.value),
              selected: _horizon == item.key,
              onSelected: (_) => setState(() => _horizon = item.key)),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _route ?? '',
          decoration: const InputDecoration(labelText: '比较范围'),
          items: [
            const DropdownMenuItem(value: '', child: Text('所有候选 · 同深度比较')),
            ...s.routes.map((r) => DropdownMenuItem(
                value: r.id,
                child: Text(r.title, overflow: TextOverflow.ellipsis)))
          ],
          onChanged: (v) => setState(() => _route = v == '' ? null : v)),
      const SizedBox(height: 12),
      if (visible.isEmpty)
        const OsNote('这一层还没有可靠展开的节点。添加后果、关联证据，或查看折叠的待验证候选。')
      else
        Container(
            height: 340,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: const Color(0xFFEFF3ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDE5D9))),
            child: InteractiveViewer(
                key: ValueKey('causal_canvas_$_horizon'),
                constrained: false,
                minScale: .35,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(70),
                child: SizedBox(
                    width: graphSize.width,
                    height: graphSize.height,
                    child: Stack(children: [
                      Positioned.fill(
                          child: CustomPaint(
                              painter: _CausalEdges(
                                  positions, edges, width, height))),
                      for (final n in visible)
                        Positioned(
                            left: positions[n.id]!.dx,
                            top: positions[n.id]!.dy,
                            width: width,
                            height: height,
                            child: Semantics(
                                label:
                                    '第${n.order}阶后果：${n.title}。${_certainty[certainty[n.id] ?? 'unknown']}',
                                button: true,
                                child: Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                        key: ValueKey('causal_node_${n.id}'),
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => _inspect(
                                            n, certainty[n.id] ?? 'unknown'),
                                        child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: certainty[n.id] ==
                                                                'direct' ||
                                                            certainty[n.id] ==
                                                                'supported'
                                                        ? osForest.withValues(
                                                            alpha: .4)
                                                        : osGold.withValues(
                                                            alpha: .5)),
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      '${osHorizons[n.horizon]} · 第${n.order}阶 · ${osValences[n.text('valence')] ?? '待分类'}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: osForest)),
                                                  const SizedBox(height: 7),
                                                  Expanded(
                                                      child: Text(n.title,
                                                          maxLines: 3,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              fontSize: 14,
                                                              height: 1.3,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700))),
                                                  Text(
                                                      '${n.flag('cumulative') ? '↗ 累积  ' : ''}${s.edges.any((e) => e.isLoop && e.from == n.id) ? '↺ 回路  ' : ''}${_certainty[certainty[n.id] ?? 'unknown']}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: osGold)),
                                                ])))))),
                    ])))),
      const SizedBox(height: 8),
      const Text('拖动 / 双指缩放，点节点查看条件、来源与下一阶。箭头表示条件关系。',
          style: TextStyle(fontSize: 11, color: Color(0xFF68786E))),
      SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('查看折叠的待验证节点'),
          subtitle: const Text('包含已剪枝或证据不足的候选，保持未知边界'),
          value: _showUncertain,
          onChanged: (v) => setState(() => _showUncertain = v)),
      SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('叠加未来选择空间'),
          value: _options,
          onChanged: (v) => setState(() => _options = v)),
      if (_options) ...[
        if (deltas.isEmpty)
          const OsNote('暂未记录未来路径变化。可以记录新增、保留、变易、变难、延期或实质关闭的路径。'),
        for (final d in deltas)
          OsRecordCard(
              title: d.text('title'),
              tag: osOptionDeltas[d.delta],
              children: [
                if (d.flag('needsReview'))
                  const OsNote('关联的后果已出现反证，这条未来路径需要重新核验。'),
                Text(d.text('condition').isEmpty
                    ? '条件尚未确认'
                    : d.text('condition')),
                TextButton(
                    onPressed: () => widget.onFutureRoute(d),
                    child: const Text('带入选择空间继续比较')),
              ]),
      ],
      if (paths.isNotEmpty)
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('${paths.length} 条主链的证据边界'),
            children: [
              for (final path in paths)
                OsNote(
                    '${path.nodes.map((n) => n.title).join(' → ')}\n${_certainty[path.certainty]}。${path.stopReason.isEmpty ? path.explanation : path.stopReason}'),
            ]),
    ]);
  }
}

class _CausalEdges extends CustomPainter {
  const _CausalEdges(
      this.positions, this.edges, this.nodeWidth, this.nodeHeight);
  final Map<String, Offset> positions;
  final List<OsCausalEdge> edges;
  final double nodeWidth, nodeHeight;
  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final a = positions[edge.from]! + Offset(nodeWidth, nodeHeight / 2);
      final b = positions[edge.to]! + Offset(0, nodeHeight / 2);
      final paint = Paint()
        ..color = edge.isLoop ? osGold : osForest.withValues(alpha: .45)
        ..strokeWidth = 1.7
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(a.dx, a.dy);
      if (edge.isLoop) {
        path.cubicTo(a.dx + 45, a.dy - nodeHeight, b.dx - 45, b.dy - nodeHeight,
            b.dx, b.dy);
      } else {
        path.cubicTo(a.dx + 32, a.dy, b.dx - 32, b.dy, b.dx, b.dy);
      }
      canvas.drawPath(path, paint);
      canvas.drawPath(
          Path()
            ..moveTo(b.dx - 7, b.dy - 4)
            ..lineTo(b.dx, b.dy)
            ..lineTo(b.dx - 7, b.dy + 4),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CausalEdges oldDelegate) => true;
}
