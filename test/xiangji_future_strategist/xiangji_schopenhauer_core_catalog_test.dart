import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_method_catalog.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_schopenhauer_core_catalog.dart';

void main() {
  test('V5 Schopenhauer L0 catalog keeps the complete frozen concept core', () {
    final entries = XiangjiSchopenhauerCoreCatalog.entries;

    expect(entries, hasLength(24));
    expect(entries.map((entry) => entry.id).toSet(), hasLength(24));
    expect(entries.map((entry) => entry.displayName).toSet(), hasLength(24));
    expect(
      XiangjiSchopenhauerCoreCatalog.frozenArchitecture,
      contains('经验世界 I'),
    );
    expect(
      XiangjiSchopenhauerCoreCatalog.frozenArchitecture,
      contains('抽象反思世界 C'),
    );
    expect(
      XiangjiSchopenhauerCoreCatalog.frozenArchitecture,
      contains('新经验世界 I′'),
    );
    expect(XiangjiSchopenhauerCoreCatalog.layerArchitecture, hasLength(4));

    for (final entry in entries) {
      expect(entry.displayName, isNotEmpty, reason: entry.id);
      expect(entry.originalTerm, isNotEmpty, reason: entry.id);
      expect(entry.category, isNotEmpty, reason: entry.id);
      expect(entry.conceptKind, isNotEmpty, reason: entry.id);
      expect(entry.definition, isNotEmpty, reason: entry.id);
      expect(entry.operationalRule, isNotEmpty, reason: entry.id);
      expect(entry.featureBindings, isNotEmpty, reason: entry.id);
      expect(entry.relatedRuleIds, isNotEmpty, reason: entry.id);
      expect(entry.sourceLocator, isNotEmpty, reason: entry.id);
      expect(entry.passageIds, isNotEmpty, reason: entry.id);
    }
  });

  test('product operationalizations never masquerade as original terminology',
      () {
    final derived = XiangjiSchopenhauerCoreCatalog.entries
        .where((entry) => entry.isProductOperationalization)
        .toList();

    expect(derived, isNotEmpty);
    expect(
      derived.every(
        (entry) => entry.conceptKind.contains('不冒充原典术语'),
      ),
      isTrue,
    );
    expect(
      XiangjiSchopenhauerCoreCatalog.forId('SC-K0-008').displayName,
      '认识债务',
    );
  });

  test('every runtime method is constrained by L0 and every core is reachable',
      () {
    final linkedCoreIds = <String>{};

    for (final method in XiangjiMethodCatalog.entries) {
      expect(method.coreConceptIds, isNotEmpty, reason: method.id);
      expect(
        method.coreConceptIds,
        everyElement(isIn(XiangjiSchopenhauerCoreCatalog.ids)),
        reason: method.id,
      );
      expect(method.coreConceptNames, isNotEmpty, reason: method.id);
      linkedCoreIds.addAll(method.coreConceptIds);
    }

    expect(linkedCoreIds, containsAll(XiangjiSchopenhauerCoreCatalog.ids));
  });
}
