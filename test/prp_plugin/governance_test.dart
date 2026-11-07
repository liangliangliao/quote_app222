import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/src/governance.dart';
import 'package:quote_app/prp_plugin/src/models.dart';

import 'fakes.dart';

void main() {
  group('PrpGovernor.allowOffer', () {
    test('用户亲手触发的不受限制', () async {
      final r = Rig();
      r.host.muted = true;
      r.host.quiet = true;
      expect(
        await r.engine.governor.allowOffer(
          enemySignal(userInitiated: true),
          r.host.now,
        ),
        isTrue,
      );
    });

    test('主动提议：静音或静默时段不提议', () async {
      final r = Rig();
      r.host.muted = true;
      expect(
        await r.engine.governor.allowOffer(
          enemySignal(userInitiated: false),
          r.host.now,
        ),
        isFalse,
      );
      r.host.muted = false;
      r.host.quiet = true;
      expect(
        await r.engine.governor.allowOffer(
          enemySignal(userInitiated: false),
          r.host.now,
        ),
        isFalse,
      );
    });

    test('主动提议：每天最多 1 次，第二天恢复', () async {
      final r = Rig();
      final sig = enemySignal(userInitiated: false);
      expect(await r.engine.governor.allowOffer(sig, r.host.now), isTrue);
      await r.store.insertSession(
        PrpSession(
          surface: PrpSurface.enemy,
          triggerKind: 'commitment_missed',
          startedMs: r.host.now,
        ),
      );
      expect(await r.engine.governor.allowOffer(sig, r.host.now), isFalse);
      r.host.now += 24 * 3600 * 1000;
      expect(await r.engine.governor.allowOffer(sig, r.host.now), isTrue);
    });

    test('上限设为 0 时不主动提议', () async {
      final r = Rig();
      await r.settings.setOfferCap(0);
      expect(
        await r.engine.governor.allowOffer(
          enemySignal(userInitiated: false),
          r.host.now,
        ),
        isFalse,
      );
    });
  });

  group('PrpGovernor.allowRecall', () {
    test('用户主动查看（pull）不受限制', () async {
      final r = Rig();
      r.host.muted = true;
      final c = const PrpContext(surface: PrpSurface.enemy, pull: true);
      expect(await r.engine.governor.allowRecall(c, r.host.now), isTrue);
    });

    test('新建字据的回访每天 1 次；查看手册的记录不占预算', () async {
      final r = Rig();
      final c = const PrpContext(surface: PrpSurface.enemy);
      expect(await r.engine.governor.allowRecall(c, r.host.now), isTrue);
      await r.store.insertRecall(
        PrpRecall(lessonId: 1, ts: r.host.now, context: 'playbook'),
      );
      expect(await r.engine.governor.allowRecall(c, r.host.now), isTrue);
      await r.store.insertRecall(
        PrpRecall(lessonId: 1, ts: r.host.now, context: 'new_commitment'),
      );
      expect(await r.engine.governor.allowRecall(c, r.host.now), isFalse);
    });
  });

  group('PrpBreaker', () {
    test('连续 3 次异常熔断；成功会重置连续计数', () {
      final b = PrpBreaker();
      b.failure('a', 'x');
      b.failure('a', 'x');
      b.success();
      b.failure('a', 'x');
      b.failure('a', 'x');
      expect(b.tripped, isFalse);
      b.failure('a', 'x');
      expect(b.tripped, isTrue);
      expect(b.failures, 5);
      expect(b.log, isNotEmpty);
    });

    test('reset 之后恢复', () {
      final b = PrpBreaker(threshold: 1);
      b.failure('a', 'x');
      expect(b.tripped, isTrue);
      b.reset();
      expect(b.tripped, isFalse);
    });
  });

  test('startOfLocalDayMs 是当天 0 点', () {
    final now = DateTime(2026, 11, 4, 15, 30).millisecondsSinceEpoch;
    expect(
      startOfLocalDayMs(now),
      DateTime(2026, 11, 4).millisecondsSinceEpoch,
    );
  });
}
