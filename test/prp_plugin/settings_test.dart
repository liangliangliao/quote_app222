import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/src/models.dart';
import 'package:quote_app/prp_plugin/src/settings.dart';

void main() {
  group('PrpSettings', () {
    test('默认值', () async {
      final s = PrpSettings(MemoryPrpKv());
      expect(await s.enabled(), isFalse);
      expect(await s.surfaceEnabled(PrpSurface.enemy), isTrue);
      expect(await s.surfaceEnabled(PrpSurface.behavior), isTrue);
      expect(await s.surfaceEnabled(PrpSurface.failureModule), isTrue);
      expect(await s.surfaceEnabled(PrpSurface.kindling), isFalse);
      expect(await s.surfaceEnabled(PrpSurface.quoteHome), isFalse);
      expect(await s.pauseSec(), 60);
      expect(await s.offerCap(), 1);
      expect(await s.recallCap(), 1);
      expect(await s.aiConsent(), isFalse);
    });

    test('参数会被夹在合理范围内', () async {
      final s = PrpSettings(MemoryPrpKv());
      await s.setPauseSec(5);
      expect(await s.pauseSec(), 15);
      await s.setPauseSec(999);
      expect(await s.pauseSec(), 300);
      await s.setOfferCap(9);
      expect(await s.offerCap(), 5);
      await s.setRecallCap(-3);
      expect(await s.recallCap(), 0);
    });

    test('开关可以读写，键带 prp. 前缀', () async {
      final kv = MemoryPrpKv();
      final s = PrpSettings(kv);
      await s.setEnabled(true);
      await s.setSurface(PrpSurface.quoteHome, true);
      expect(await s.enabled(), isTrue);
      expect(await s.surfaceEnabled(PrpSurface.quoteHome), isTrue);
      expect(kv.data.keys.every((String k) => k.startsWith('prp.')), isTrue);
    });

    test('首次说明的标记默认未看过，可以记下已看过', () async {
      final s = PrpSettings(MemoryPrpKv());
      expect(await s.introSeen(), isFalse);
      await s.setIntroSeen(true);
      expect(await s.introSeen(), isTrue);
    });

    test('snapshot 汇总所有设置', () async {
      final s = PrpSettings(MemoryPrpKv());
      await s.setEnabled(true);
      final c = await s.snapshot(installed: true);
      expect(c.installed, isTrue);
      expect(c.enabled, isTrue);
      expect(c.surfaces.length, PrpSurface.values.length);
    });
  });
}
