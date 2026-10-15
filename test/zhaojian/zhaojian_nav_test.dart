import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhaojian/src/ui/nav.dart';

void main() {
  group('ZNav registry', () {
    test('every destination has display info and belongs to a known group', () {
      for (final ZDest d in ZDest.values) {
        expect(ZNav.info.containsKey(d), isTrue, reason: '${d.name} 缺少展示信息');
        expect(ZNav.groups.contains(ZNav.info[d]!.group), isTrue, reason: '${d.name} 的分组未知');
      }
    });

    test('ready destinations show up in their group and nowhere else', () {
      final Set<ZDest> seen = <ZDest>{};
      for (final String g in ZNav.groups) {
        for (final ZDest d in ZNav.inGroup(g)) {
          expect(ZNav.isReady(d), isTrue);
          expect(ZNav.info[d]!.group, g);
          expect(seen.add(d), isTrue, reason: '${d.name} 出现了两次');
        }
      }
      expect(seen.length, ZDest.values.where(ZNav.isReady).length);
    });

    test('byName round-trips and rejects unknown names', () {
      for (final ZDest d in ZDest.values) {
        expect(ZNav.byName(d.name), d);
      }
      expect(ZNav.byName(''), isNull);
      expect(ZNav.byName('nope'), isNull);
    });

    test('every destination is registered once the port is complete', () {
      for (final ZDest d in ZDest.values) {
        expect(ZNav.isReady(d), isTrue, reason: '${d.name} 还没注册');
      }
    });

    test('the core pages are registered', () {
      for (final ZDest d in <ZDest>[
        ZDest.decide, ZDest.pending, ZDest.log, ZDest.hypothesis, ZDest.growth,
        ZDest.self, ZDest.evidence, ZDest.style, ZDest.map,
        ZDest.engine, ZDest.plans, ZDest.rope, ZDest.wall, ZDest.accept, ZDest.cog,
        ZDest.belief, ZDest.knowAct, ZDest.regret,
        ZDest.goal, ZDest.line, ZDest.forgo, ZDest.probe, ZDest.shift, ZDest.signature, ZDest.analysis,
      ]) {
        expect(ZNav.isReady(d), isTrue, reason: '${d.name} 应已注册');
      }
    });
  });
}
