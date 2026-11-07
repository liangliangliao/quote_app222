import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/src/models.dart';

import 'fakes.dart';

void main() {
  group('关闭零痕迹', () {
    test('默认关闭：信号为 null、回访为空、没有名言，且完全不碰存储', () async {
      final r = Rig();
      expect(await r.core.isEnabled(), isFalse);
      expect(await r.core.signal(enemySignal()), isNull);
      expect(
        await r.core.recallFor(
          const PrpContext(surface: PrpSurface.enemy, text: '晨读'),
        ),
        isEmpty,
      );
      expect(
        await r.core.hintFor(
          const PrpContext(surface: PrpSurface.enemy, text: '晨读'),
        ),
        isEmpty,
      );
      expect(await r.core.ownQuoteRow(), isNull);
      expect((await r.core.playbookData()).sealed, isEmpty);
      expect(r.mem.writeCount, 0);
      expect(r.mem.readCount, 0);
      expect(r.host.mirrored, isEmpty);
    });

    test('总开关开、分功能关：该功能零痕迹，其他功能照常', () async {
      final r = Rig();
      await r.settings.setEnabled(true);
      await r.settings.setSurface(PrpSurface.enemy, false);
      expect(await r.core.signal(enemySignal()), isNull);
      expect(r.mem.writeCount, 0);
      await r.settings.setSurface(PrpSurface.enemy, true);
      expect(await r.core.signal(enemySignal()), isNotNull);
      expect(r.mem.writeCount, greaterThan(0));
    });

    test('名言首页默认关闭，打开后才给自己的名言', () async {
      final r = Rig();
      await r.settings.setEnabled(true);
      final sig = enemySignal();
      final offer = await r.core.signal(sig);
      await r.core.seal(offer!.sessionId, sig, goodDraft);
      expect(await r.core.ownQuoteRow(), isNull);
      await r.settings.setSurface(PrpSurface.quoteHome, true);
      expect(await r.core.ownQuoteRow(), isNotNull);
    });
  });

  group('数据保留', () {
    test('关闭后手册不显示，但数据还在；设置页可以查看；重新开启后恢复', () async {
      final r = Rig();
      await r.settings.setEnabled(true);
      final sig = enemySignal();
      final offer = await r.core.signal(sig);
      final res = await r.core.seal(offer!.sessionId, sig, goodDraft);
      expect(res!.ok, isTrue);
      expect((await r.core.playbookData()).sealed.length, 1);

      await r.settings.setEnabled(false);
      expect((await r.core.playbookData()).sealed, isEmpty);
      expect((await r.core.playbookData(viewAlways: true)).sealed.length, 1);

      await r.settings.setEnabled(true);
      expect((await r.core.playbookData()).sealed.length, 1);
    });

    test('导出包含教训；清除后为空', () async {
      final r = Rig();
      await r.settings.setEnabled(true);
      final sig = enemySignal();
      final offer = await r.core.signal(sig);
      await r.core.seal(offer!.sessionId, sig, goodDraft);
      final data =
          jsonDecode(await r.core.exportJson()) as Map<String, dynamic>;
      expect((data['lessons'] as List).length, 1);
      await r.core.clearAll();
      expect((await r.core.playbookData(viewAlways: true)).sealed, isEmpty);
    });
  });

  group('熔断', () {
    test('连续 3 次内部异常后整体静默，之后不再碰存储', () async {
      final failing = FailingStore();
      final r = Rig(storeOverride: failing);
      await r.settings.setEnabled(true);
      for (int i = 0; i < 3; i++) {
        expect(await r.core.signal(enemySignal()), isNull);
      }
      expect(r.core.breaker.tripped, isTrue);
      expect(failing.calls, 3);
      expect(await r.core.signal(enemySignal()), isNull);
      expect(failing.calls, 3);
      expect(await r.core.isEnabled(), isFalse);
    });

    test('诊断信息反映熔断和日志', () async {
      final failing = FailingStore();
      final r = Rig(storeOverride: failing);
      await r.settings.setEnabled(true);
      for (int i = 0; i < 3; i++) {
        await r.core.signal(enemySignal());
      }
      final d = await r.core.diagnostics();
      expect(d.tripped, isTrue);
      expect(d.failures, 3);
      expect(d.log, isNotEmpty);
    });
  });

  group('信号与治理', () {
    test('主动提议受每日上限限制，用户亲手触发不受限', () async {
      final r = Rig();
      await r.settings.setEnabled(true);
      expect(await r.core.signal(enemySignal(userInitiated: false)), isNotNull);
      expect(await r.core.signal(enemySignal(userInitiated: false)), isNull);
      expect(await r.core.signal(enemySignal(userInitiated: true)), isNotNull);
    });

    test('诊断统计会话、教训、回访', () async {
      final r = Rig();
      await r.settings.setEnabled(true);
      final sig = enemySignal();
      final offer = await r.core.signal(sig);
      await r.core.seal(offer!.sessionId, sig, goodDraft);
      final d = await r.core.diagnostics();
      expect(d.enabled, isTrue);
      expect(d.sessions, 1);
      expect(d.sealedLessons, 1);
      expect(d.draftLessons, 0);
    });
  });
}
