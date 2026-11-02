import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/model.dart';
import 'design.dart';
import 'tide.dart';

class SceneRehearsal extends StatefulWidget {
  const SceneRehearsal(
      {super.key,
      required this.scene,
      required this.duration,
      required this.animate,
      this.resolve,
      required this.onStop});
  final MirrorNode scene;
  final MirrorNode? Function(String)? resolve;
  final int duration;
  final bool animate;
  final VoidCallback onStop;
  @override
  State<SceneRehearsal> createState() => _SceneRehearsalState();
}

class _SceneRehearsalState extends State<SceneRehearsal>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _elapsed = 0;
  bool _paused = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused && mounted) {
        setState(() => _elapsed++);
        if (_elapsed >= widget.duration) {
          _timer?.cancel();
          widget.onStop();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      widget.onStop();
      if (mounted) setState(() => _paused = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.onStop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = widget.scene.objects('frames');
    final index = frames.isEmpty
        ? 0
        : math.min(frames.length - 1,
            (_elapsed * frames.length / widget.duration).floor());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AiOriginLabel(node: widget.scene, resolve: widget.resolve),
      MotiveTide(
          caption: _elapsed >= widget.duration
              ? '停在这里，回到眼前可以做的一步。'
              : '这是一种可能的画面，你可以随时退出。',
          animate: widget.animate && !_paused && _elapsed < widget.duration),
      const SizedBox(height: 20),
      LinearProgressIndicator(value: (_elapsed / widget.duration).clamp(0, 1)),
      const SizedBox(height: 12),
      Text('${math.min(_elapsed, widget.duration)} / ${widget.duration} 秒',
          style: Theme.of(context).textTheme.bodySmall),
      if (frames.isNotEmpty) ...[
        const SizedBox(height: 14),
        MirrorTag(humanValue(frames[index]['claimType'] as String)),
        const SizedBox(height: 12),
        AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 350),
            child: Text(frames[index]['text'] as String,
                key: ValueKey(index),
                style: Theme.of(context).textTheme.titleLarge))
      ],
      const SizedBox(height: 20),
      Text('现场的一句话：${widget.scene.text('fieldCue')}'),
      const SizedBox(height: 8),
      Text('可以退出：${widget.scene.text('fallback')}'),
      const SizedBox(height: 18),
      Wrap(spacing: 10, children: [
        OutlinedButton(
            onPressed: () {
              widget.onStop();
              setState(() => _paused = !_paused);
            },
            child: Text(_paused ? '继续画面' : '暂停')),
        FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_elapsed >= widget.duration ? '回到我的课题' : '跳过，回到现实'))
      ]),
    ]);
  }
}

class JourneyTimeline extends StatelessWidget {
  const JourneyTimeline({super.key, required this.file, required this.onNode});
  final CaseFile file;
  final ValueChanged<MirrorNode> onNode;
  @override
  Widget build(BuildContext context) {
    const kinds = {
      NodeKind.plan,
      NodeKind.triggerCheck,
      NodeKind.awareness,
      NodeKind.decision,
      NodeKind.interventionExecution,
      NodeKind.attempt,
      NodeKind.observation,
      NodeKind.acquisition,
      NodeKind.experience,
      NodeKind.principleApplication
    };
    final nodes = file.nodes
        .where((n) => n.usable && kinds.contains(n.kind))
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    if (nodes.isEmpty) return const Text('还没有实际历程。未走过的路线保留为可能。');
    return Column(children: [
      for (final n in nodes)
        IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: 26,
              child: CustomPaint(
                  painter: _TimelineStroke(
                      real: n.kind != NodeKind.plan,
                      color: Theme.of(context).colorScheme.primary))),
          Expanded(
              child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(10, 4, 0, 10),
                  title: Text(nodeTitle(n)),
                  subtitle: Text(
                      '${contentSourceLabel(n, resolve: file.node)} · ${kindLabel(n.kind)} · ${phaseLabel(n.phase)}\n发生：${timeLabel(n.happenedAt)}\n记录：${timeLabel(n.recordedAt)}'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => onNode(n))),
        ]))
    ]);
  }
}

class _TimelineStroke extends CustomPainter {
  const _TimelineStroke({required this.real, required this.color});
  final bool real;
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = color.withValues(alpha: .45)
      ..strokeWidth = 1.5;
    if (real) {
      c.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), p);
    } else {
      for (double y = 0; y < s.height; y += 9) {
        c.drawLine(Offset(s.width / 2, y),
            Offset(s.width / 2, math.min(y + 4, s.height)), p);
      }
    }
    c.drawCircle(
        Offset(s.width / 2, 22),
        4.5,
        Paint()
          ..color = color
          ..style = real ? PaintingStyle.fill : PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_TimelineStroke old) =>
      old.real != real || old.color != color;
}

class MotiveGraphView extends StatefulWidget {
  const MotiveGraphView({super.key, required this.file, required this.onNode});
  final CaseFile file;
  final ValueChanged<MirrorNode> onNode;
  @override
  State<MotiveGraphView> createState() => _MotiveGraphViewState();
}

class _MotiveGraphViewState extends State<MotiveGraphView> {
  String? _route;
  bool _all = false;
  @override
  Widget build(BuildContext context) {
    final routes = widget.file.current(NodeKind.route);
    final motives = widget.file
        .current(NodeKind.motive)
        .where((n) =>
            _route == null ||
            n.objects('directionByRoute').any((d) => d['routeId'] == _route))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (motives.firstOrNull case final generated?)
        AiOriginLabel(node: generated, resolve: widget.file.node),
      const Text('同一个理由可能支持一条路线，也可能反对另一条。连线表示当前解释，实际作用仍需要现场与事后证据。'),
      const SizedBox(height: 14),
      Wrap(spacing: 6, runSpacing: 6, children: [
        ChoiceChip(
            label: const Text('所有路线'),
            selected: _route == null,
            onSelected: (_) => setState(() => _route = null)),
        for (final route in routes)
          ChoiceChip(
              label: Text(route.text('title')),
              selected: _route == route.id,
              onSelected: (_) => setState(() => _route = route.id))
      ]),
      const SizedBox(height: 16),
      for (final motive in motives.take(_all ? motives.length : 8))
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MirrorCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                          onTap: () => widget.onNode(motive),
                          child: Text(motive.text('summary'),
                              style: Theme.of(context).textTheme.titleSmall)),
                      for (final edge in motive
                          .objects('directionByRoute')
                          .where(
                              (e) => _route == null || e['routeId'] == _route))
                        Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                      edge['relation'] == 'opposes'
                                          ? Icons.remove_circle_outline
                                          : edge['relation'] == 'supports'
                                              ? Icons.arrow_forward
                                              : Icons.help_outline,
                                      size: 17),
                                  const SizedBox(width: 9),
                                  Expanded(
                                      child: Text(
                                          '${humanValue(edge['relation'] as String)} → ${widget.file.node(edge['routeId'] as String)?.text('title') ?? '原路线'}\n${edge['reason']}'))
                                ])),
                    ]))),
      if (motives.length > 8)
        TextButton(
            onPressed: () => setState(() => _all = !_all),
            child: Text(_all ? '收起' : '展开全部 ${motives.length} 条')),
      for (final conflict in widget.file.current(NodeKind.conflict))
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(conflict.text('title')),
            subtitle: Text(
                '${humanValue(conflict.text('kind'))} · ${conflict.text('explanation')}'),
            onTap: () => widget.onNode(conflict)),
      ExpansionTile(title: const Text('认识、触发条件和替代关系'), children: [
        for (final edge in widget.file.current(NodeKind.graphEdge))
          ListTile(
              title: Text(
                  '${widget.file.node(edge.text('fromId')) == null ? '原记录' : nodeTitle(widget.file.node(edge.text('fromId'))!)}\n↓ ${humanValue(edge.text('relation'))}\n${widget.file.node(edge.text('toId')) == null ? '原记录' : nodeTitle(widget.file.node(edge.text('toId'))!)}'),
              subtitle: Text(edge.text('reason')),
              onTap: () => widget.onNode(edge))
      ]),
    ]);
  }
}

class RouteComparison extends StatelessWidget {
  const RouteComparison({super.key, required this.file, required this.onNode});
  final CaseFile file;
  final ValueChanged<MirrorNode> onNode;
  @override
  Widget build(BuildContext context) {
    final routes = file.current(NodeKind.route);
    final fits = {
      for (final n in file.current(NodeKind.routeFit)) n.text('routeId'): n
    };
    const axes = {
      'wantFit': '与欲求的关系',
      'bodySkillFit': '身体与技能适配',
      'externalFeasibility': '外部可行性',
      'motivationCognition': '理由与认识',
      'hardSafetyGate': '安全门槛',
      'difficulty': '实施难度'
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (fits.values.firstOrNull case final assessment?)
        AiOriginLabel(node: assessment, resolve: file.node),
      const Text('安全与现实条件先核实。各个维度分别比较，综合数字不能抵消硬性限制。'),
      const SizedBox(height: 16),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
              dataRowMinHeight: 60,
              dataRowMaxHeight: 150,
              columnSpacing: 22,
              columns: [
                const DataColumn(label: Text('分别看什么')),
                for (final route in routes)
                  DataColumn(
                      label: SizedBox(
                          width: 160,
                          child: Text(route.text('title'), maxLines: 4)))
              ],
              rows: [
                for (final axis in axes.entries)
                  DataRow(cells: [
                    DataCell(Text(axis.value)),
                    for (final route in routes)
                      DataCell(
                          SizedBox(
                              width: 160,
                              child: Text(fits[route.id]?.body[axis.key] == null
                                  ? '未知'
                                  : axis.key == 'difficulty'
                                      ? '${fits[route.id]!.body[axis.key]} / 5（产品分级）'
                                      : humanValue(fits[route.id]!
                                          .body[axis.key]
                                          .toString()))),
                          onTap: () => onNode(fits[route.id] ?? route))
                  ])
              ])),
      const SizedBox(height: 18),
      for (final route in routes)
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(route.text('title')),
            subtitle: Text(fits[route.id]?.text('uncertainty') ?? '还需要核实具体条件'),
            children: [
              for (final row in fits[route.id]?.objects('matrix') ?? <Json>[])
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        '${file.node(row['wantId'] as String)?.text('claim') ?? '欲求待核实'} · ${humanValue(row['horizon'] as String)}'),
                    subtitle: Text(
                        '${humanValue(row['effect'] as String)}：${row['reason']}\n条件：${stringList(row['conditions']).join('；')}')),
              for (final factor
                  in fits[route.id]?.objects('difficultyFactors') ?? <Json>[])
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(humanValue(factor['factor'] as String)),
                    subtitle: Text(
                        '${factor['assessment']} · ${factor['level'] ?? '未知'}')),
              TextButton(
                  onPressed: () => onNode(fits[route.id] ?? route),
                  child: const Text('查看依据、反证与替代路线')),
            ]),
    ]);
  }
}

/// Positions encode chronology only; vertical turns never imply improvement.
class LifeZigzag extends StatelessWidget {
  const LifeZigzag({super.key, required this.events, required this.onNode});
  final List<MirrorNode> events;
  final ValueChanged<MirrorNode> onNode;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                SizedBox(
                    width: 48,
                    child: CustomPaint(
                        painter: _LifeStroke(
                            odd: i.isOdd,
                            first: i == 0,
                            last: i == events.length - 1,
                            real: events[i].kind != NodeKind.route,
                            color: Theme.of(context).colorScheme.primary))),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MirrorCard(
                            padding: const EdgeInsets.all(15),
                            onTap: () => onNode(events[i]),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      events[i].kind == NodeKind.route
                                          ? '未走过的可能'
                                          : '真实经历 · ${phaseLabel(events[i].phase)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium),
                                  const SizedBox(height: 6),
                                  AiOriginLabel(node: events[i]),
                                  Text(nodeTitle(events[i]),
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Text(
                                      events[i].happenedAt == null
                                          ? '发生时间未知 · 记录于 ${timeLabel(events[i].recordedAt)}'
                                          : timeLabel(events[i].happenedAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ])))),
              ]))
      ]);
}

class _LifeStroke extends CustomPainter {
  const _LifeStroke(
      {required this.odd,
      required this.first,
      required this.last,
      required this.real,
      required this.color});
  final bool odd, first, last, real;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final x = odd ? 38.0 : 10.0, previousX = odd ? 10.0 : 38.0;
    final point = Offset(x, 24);
    final path = Path();
    if (first) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.moveTo(previousX, 0);
      path.lineTo(point.dx, point.dy);
    }
    if (!last) path.lineTo(x, size.height);
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    if (real) {
      canvas.drawPath(path, pen);
    } else {
      for (final metric in path.computeMetrics()) {
        for (var start = 0.0; start < metric.length; start += 10) {
          canvas.drawPath(
              metric.extractPath(start, (start + 5).clamp(0, metric.length)),
              pen);
        }
      }
    }
    canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = color
          ..style = real ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(_LifeStroke old) =>
      old.odd != odd ||
      old.first != first ||
      old.last != last ||
      old.real != real ||
      old.color != color;
}
