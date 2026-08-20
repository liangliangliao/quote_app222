import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/kindling/src/data/models.dart';
import 'package:quote_app/kindling/src/domain/heat.dart';

KItemView _view({
  required int id,
  int? probe,
  DateTime? probeAt,
  int burnTotal = 0,
  int wantMoreCount = 0,
  DateTime? lastBurnAt,
  String? verdict,
  DateTime? updatedAt,
}) {
  final DateTime stamp = updatedAt ?? DateTime(2026, 1, 1);
  return KItemView(
    item: KItem(
      id: id,
      title: 'item $id',
      kind: KKind.other,
      createdAt: stamp,
      updatedAt: stamp,
    ),
    latestProbe: probe,
    probeAt: probeAt,
    burnTotal: burnTotal,
    wantMoreCount: wantMoreCount,
    lastBurnAt: lastBurnAt,
    verdict: verdict,
    consecutiveNoCount: 0,
  );
}

void main() {
  final DateTime now = DateTime(2026, 6, 1);

  test('"不做" sinks the item to the bottom', () {
    expect(
      heat(
        latestProbe: 4,
        probeAt: now,
        burnTotal: 3,
        wantMoreCount: 3,
        lastBurnAt: now,
        verdict: 'no',
        now: now,
      ),
      -1,
    );
  });

  test('"做" adds a bonus over an otherwise identical item', () {
    double score(String? verdict) => heat(
          latestProbe: 2,
          probeAt: now,
          burnTotal: 2,
          wantMoreCount: 1,
          lastBurnAt: now,
          verdict: verdict,
          now: now,
        );
    expect(score('yes'), greaterThan(score(null)));
    expect(score('yes') - score(null), closeTo(0.15, 1e-9));
  });

  test('an unrated item lands on the neutral middle', () {
    final double score = heat(
      latestProbe: null,
      probeAt: null,
      burnTotal: 0,
      wantMoreCount: 0,
      lastBurnAt: null,
      verdict: null,
      now: now,
    );
    expect(score, closeTo(0.5, 1e-6));
  });

  test('a 14-day-old self report is halved in weight', () {
    final double fresh = heat(
      latestProbe: 4,
      probeAt: now,
      burnTotal: 0,
      wantMoreCount: 0,
      lastBurnAt: null,
      verdict: null,
      now: now,
    );
    final double stale = heat(
      latestProbe: 4,
      probeAt: now.subtract(const Duration(days: 14)),
      burnTotal: 0,
      wantMoreCount: 0,
      lastBurnAt: null,
      verdict: null,
      now: now,
    );
    expect(stale, lessThan(fresh));
    expect(stale, greaterThan(0.5));
  });

  test('the result stays inside 0..1.2', () {
    final double score = heat(
      latestProbe: 4,
      probeAt: now,
      burnTotal: 5,
      wantMoreCount: 5,
      lastBurnAt: now,
      verdict: 'yes',
      now: now,
    );
    expect(score, lessThanOrEqualTo(1.2));
    expect(score, greaterThanOrEqualTo(0.0));
  });

  test('sortByHeat only reorders, it never annotates', () {
    final List<KItemView> sorted = sortByHeat(
      <KItemView>[
        _view(id: 1, probe: 0, probeAt: now),
        _view(id: 2, probe: 4, probeAt: now, verdict: 'yes'),
        _view(id: 3, probe: 4, probeAt: now, verdict: 'no'),
        _view(id: 4, probe: 3, probeAt: now),
      ],
      now: now,
    );
    expect(
      sorted.map((KItemView v) => v.id).toList(),
      <int>[2, 4, 1, 3],
    );
  });
}
