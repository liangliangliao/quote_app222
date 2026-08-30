import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_method_catalog.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_schopenhauer_core_catalog.dart';

void main() {
  test('Rev5.2 catalog preserves all 14 distinct product concepts', () {
    final entries = XiangjiMethodCatalog.entries;

    expect(entries, hasLength(14));
    expect(entries.map((entry) => entry.id).toSet(), hasLength(14));
    expect(entries.map((entry) => entry.displayName).toSet(), hasLength(14));
    for (final entry in entries) {
      expect(entry.displayName, isNotEmpty, reason: entry.id);
      expect(entry.domain, isNotEmpty, reason: entry.id);
      expect(entry.sourceConcept, isNotEmpty, reason: entry.id);
      expect(entry.principle, isNotEmpty, reason: entry.id);
      expect(entry.triggerSummary, isNotEmpty, reason: entry.id);
      expect(entry.stateEffect, isNotEmpty, reason: entry.id);
      expect(entry.realityTest, isNotEmpty, reason: entry.id);
      expect(entry.sourceLocator, isNotEmpty, reason: entry.id);
      expect(entry.relatedRuleIds, isNotEmpty, reason: entry.id);
      expect(entry.coreConceptIds, isNotEmpty, reason: entry.id);
      expect(
        entry.coreConceptIds,
        everyElement(isIn(XiangjiSchopenhauerCoreCatalog.ids)),
        reason: entry.id,
      );
    }
  });

  test('persistent solver concepts are not misattributed as philosophy', () {
    for (final id in const <String>[
      'MEC-011',
      'MEC-012',
      'MEC-013',
      'MEC-014',
    ]) {
      final entry = XiangjiMethodCatalog.forId(id);
      expect(entry.domain, '持续问题求解', reason: id);
      expect(entry.sourceLocator, startsWith('Master PRD'), reason: id);
    }
  });

  test('bundled JSON registry matches the runtime catalog', () {
    final raw = jsonDecode(
      File(
        'assets/xiangji_future_strategist/'
        'signature_method_capabilities_rev5_2.json',
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    final capabilities = (raw['capabilities'] as List<Object?>)
        .cast<Map<String, Object?>>();

    expect(raw['version'], XiangjiMethodCatalog.version);
    expect(
      capabilities.map((item) => item['id']).toList(),
      XiangjiMethodCatalog.ids,
    );
    for (final item in capabilities) {
      final entry = XiangjiMethodCatalog.forId(item['id'].toString());
      expect(item['display_name'], entry.displayName, reason: entry.id);
      expect(item['domain'], entry.domain, reason: entry.id);
      expect(item['layer'], entry.layer, reason: entry.id);
      expect(item['source_concept'], entry.sourceConcept, reason: entry.id);
      expect(item['source_locator'], entry.sourceLocator, reason: entry.id);
      expect(item['related_rules'], entry.relatedRuleIds, reason: entry.id);
      expect(item['core_concepts'], entry.coreConceptIds, reason: entry.id);
    }
  });
}
