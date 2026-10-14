import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'fixtures.dart';

// These 24 synthetic scenarios verify ledger invariants only. They are also the
// input set for the separate live-model blind-review protocol, not proof that
// any model meets the qualitative checks in scenarios.json.
void main() {
  final cases = jsonDecode(
          File('docs/will_mirror/evaluation/scenarios.json').readAsStringSync())
      as List;
  for (final raw in cases) {
    final scenario = jsonMap(raw);
    test(
        '${scenario['id']} ${scenario['domain']}: no fabricated facts across a new evidence version',
        () {
      var f = newCase(scenario['initial'] as String);
      final first = f.nodes.single;
      expect(first.text('text'), scenario['initial']);
      expect(first.origin, EvidenceOrigin.selfReport);
      expect(first.happenedAt, isNull);
      final updated = commands.record(
          f,
          NodeKind.evidence,
          {
            'text': scenario['new_evidence'],
            'category': 'condition',
            'source': 'self_report',
            'sensitive': false,
            'scope': 'case_only'
          },
          phase: TimePhase.t1,
          knownAt: time.add(const Duration(days: 1)));
      f = commands.append(f, [updated]);
      expect(f.nodes.first.toJson(), first.toJson());
      expect(f.nodes.last.phase, TimePhase.t1);
      expect(f.current(NodeKind.observation), isEmpty);
      expect(f.current(NodeKind.principle), isEmpty);
      expect(f.current(NodeKind.recommendation), isEmpty);
      final wiped = commands.retract(f, {updated.id});
      expect(canonicalJson(wiped.toJson()),
          isNot(contains(scenario['new_evidence'])));
      expect(wiped.nodes.first.text('text'), scenario['initial']);
    });
  }
}
