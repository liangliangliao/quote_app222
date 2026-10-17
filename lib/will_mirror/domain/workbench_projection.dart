import 'model.dart';

/// Read-only relationships, never a psychological strength score. A reason's
/// direction is relative to ONE route; the same reason may oppose another.
class RouteReasons {
  RouteReasons._(this.route, this.support, this.opposition, this.conditional);
  final MirrorNode route;
  final List<MirrorNode> support, opposition, conditional;

  factory RouteReasons.forRoute(CaseFile file, MirrorNode route) {
    final groups = <String, List<MirrorNode>>{
      'supports': [],
      'opposes': [],
      'conditional': [],
    };
    for (final motive in file.current(NodeKind.motive)) {
      final directions = motive
          .objects('directionByRoute')
          .where((d) => d['routeId'] == route.id);
      for (final direction in directions) {
        final group = groups[direction['relation']];
        if (group != null && !group.any((n) => n.id == motive.id))
          group.add(motive);
      }
    }
    return RouteReasons._(
      route,
      groups['supports']!,
      groups['opposes']!,
      groups['conditional']!,
    );
  }
}

class EvidenceChange {
  EvidenceChange(this.belief, this.reframe, this.motives, this.routes);
  final MirrorNode? belief;
  final MirrorNode reframe;
  final List<MirrorNode> motives, routes;

  factory EvidenceChange.from(CaseFile file, MirrorNode reframe) {
    final motiveIds = reframe.strings('affectedMotiveIds').toSet();
    final routeIds = reframe.strings('affectedRouteIds').toSet();
    final belief = file.node(reframe.text('oldBeliefId'));
    return EvidenceChange(
      belief?.usable == true ? belief : null,
      reframe,
      file
          .current(NodeKind.motive)
          .where((n) => motiveIds.contains(n.id))
          .toList(),
      file
          .current(NodeKind.route)
          .where((n) => routeIds.contains(n.id))
          .toList(),
    );
  }
}

/// Display the evidence state of each time layer independently, even when the
/// result is completed. Opening a notification never supplies any of these.
List<({String label, String text, MirrorNode? source})> realityTrace(
  CaseFile file,
) {
  // Historical plans remain a valid T0 comparison after conditions changed;
  // they are never returned to the executable-plan APIs. Retraction wins.
  final plan = file.nodes
      .where((n) =>
          n.kind == NodeKind.plan &&
          n.episodeId == file.episodeId &&
          !n.flag('redacted') &&
          n.status != NodeStatus.retracted)
      .lastOrNull;
  final trigger = file.latest(NodeKind.triggerCheck);
  final decision = file
      .current(NodeKind.decision)
      .where((n) => n.text('type') == 'at_trigger')
      .lastOrNull;
  final attempt = file.latest(NodeKind.attempt);
  final observation = file.latest(NodeKind.observation);
  final experience = file.latest(NodeKind.experience);
  return [
    (label: '事前预案', text: plan?.text('ifThen') ?? '未记录', source: plan),
    (label: '真实条件', text: trigger?.text('detail') ?? '尚未核实', source: trigger),
    (
      label: '临场选择',
      text: decision?.text('declaration') ?? '尚未记录',
      source: decision,
    ),
    (
      label: '真实尝试',
      text: attempt?.text('detail') ?? '尚无单独尝试记录',
      source: attempt,
    ),
    (
      label: '实际行动',
      text: observation?.text('action') ?? '尚未收到反馈',
      source: observation,
    ),
    (
      label: '后续体验',
      text: experience == null
          ? '尚待实际体验'
          : experience.text('feeling').isEmpty
              ? '已有后续体验记录，满意程度未填写'
              : experience.text('feeling'),
      source: experience,
    ),
  ];
}
