import 'dart:math' as math;

import '../data/models.dart';

/// 痒度。越大越靠前。不对用户暴露。
///
/// 分数只用于列表排序，绝不渲染成数字、星级或颜色深浅。
double heat({
  required int? latestProbe, // 0..4，null=未评
  required DateTime? probeAt,
  required int burnTotal, // 该火种的十五分钟次数
  required int wantMoreCount, // 其中答"还想做"的次数
  required DateTime? lastBurnAt,
  required String? verdict, // yes|no|unsure|null
  required DateTime now,
}) {
  if (verdict == 'no') return -1; // 伪目标沉底

  final double probe = (latestProbe ?? 2) / 4.0;
  final double want = burnTotal == 0 ? 0.5 : wantMoreCount / burnTotal;

  // 半衰期 14 天：久未触碰的自评降权，回归中性
  double decay(DateTime? t) {
    if (t == null) return 0.5;
    final int d = now.difference(t).inDays;
    return math.pow(0.5, d / 14.0).toDouble();
  }

  final double probeW = decay(probeAt);
  final double wantW = decay(lastBurnAt);
  final double base =
      (probe * probeW + want * wantW) / (probeW + wantW + 1e-9);
  final double bonus = verdict == 'yes' ? 0.15 : 0.0;
  return (base + bonus).clamp(0.0, 1.2);
}

/// 用聚合视图算痒度。
double heatOf(KItemView view, {DateTime? now}) {
  return heat(
    latestProbe: view.latestProbe,
    probeAt: view.probeAt,
    burnTotal: view.burnTotal,
    wantMoreCount: view.wantMoreCount,
    lastBurnAt: view.lastBurnAt,
    verdict: view.verdict,
    now: now ?? DateTime.now(),
  );
}

/// 按痒度排序。排序结果在 UI 上只表现为顺序。
List<KItemView> sortByHeat(List<KItemView> views, {DateTime? now}) {
  final DateTime at = now ?? DateTime.now();
  final List<KItemView> sorted = List<KItemView>.of(views);
  sorted.sort((KItemView a, KItemView b) {
    final int byHeat = heatOf(b, now: at).compareTo(heatOf(a, now: at));
    if (byHeat != 0) return byHeat;
    // 同痒度时用最近更新兜底，保证顺序稳定。
    return b.item.updatedAt.compareTo(a.item.updatedAt);
  });
  return sorted;
}
