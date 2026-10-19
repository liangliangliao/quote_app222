import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_repository.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;
import 'self_os_v37_rules_test.dart' show decision, node, proof;

void main() {
  late Directory dir;
  late SelfOsRepository repo;
  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('self-os-v37-');
    repo = SelfOsRepository(
        factory: databaseFactoryFfi, path: '${dir.path}/self_os_v3.db');
  });
  tearDown(() async {
    await repo.close();
    await dir.delete(recursive: true);
  });

  test('V3.0 JSON 原地升级，不改历史快照、复盘 ID 或独立数据库名', () async {
    final c = plannedCase()..commit();
    c.addReview(reviewFor(c));
    final old = c.toJson()
      ..['schemaVersion'] = 1
      ..remove('v37');
    final snapshot = osMap(old['commitment'])..remove('v37');
    old['commitment'] = snapshot;
    final oldReview = osMaps(old['reviews']).single;
    oldReview['snapshot'] = snapshot;
    old['reviews'] = [oldReview];
    final db = await repo.database;
    await db.insert('cases', {
      'id': c.id,
      'updated_at': c.updatedAt.millisecondsSinceEpoch,
      'document': jsonEncode(old)
    });
    await db.insert('profile', {
      'id': 1,
      'document': jsonEncode({
        'schemaVersion': 1,
        'manual': {'values': '旧欲求'},
        'principles': [
          {'id': 'p', 'rule': '旧原则'}
        ]
      })
    });
    var loaded = (await repo.loadCases()).single;
    expect(loaded.v37.routes, isEmpty);
    expect(loaded.reviews.single.id, c.reviews.single.id);
    expect(loaded.commitment, snapshot);
    expect((await repo.loadProfile()).manual['values'], '旧欲求');
    loaded.v37.ensureCurrentRoute(loaded.problem, '');
    await repo.saveCase(loaded);
    await repo.close();
    loaded = (await repo.loadCases()).single;
    expect(loaded.v37.routes, hasLength(1));
    expect(loaded.commitment, snapshot);
    expect((await repo.loadProfile()).principles.single['id'], 'p');
  });

  test('主线跨案例原子切换，同时保存机会成本与上一条主线', () async {
    final a = plannedCase()..v37 = decision();
    final b = plannedCase()..v37 = decision();
    for (final c in [a, b]) {
      c.v37.routes.first.data.addAll({
        'desire': '稳定',
        'ability': '已有工作样本',
        'cost': '投入每周一小时',
        'reality': '已确认时间空档'
      });
      await repo.saveCase(c);
    }
    final choice = {
      'reason': '新行动证据',
      'sacrifice': '另一条路径的成长价值',
      'opportunityCost': '减少另一项投入',
      'accepted': true,
      'trigger': 'evidence'
    };
    await repo.transitionRoute(a, 'a', 'active', choice);
    await repo.transitionRoute(b, 'a', 'active', choice);
    final records = await repo.loadCases();
    expect(records.where((c) => c.routeStatus == 'active').single.id, b.id);
    expect(
        records.expand((c) => c.v37.routes).where((r) => r.status == 'active'),
        hasLength(1));
    final p = await repo.loadProfile();
    expect(p.activeCaseId, b.id);
    expect(p.tradeoffs.last['previousCaseId'], a.id);
    final blocked = records.firstWhere((c) => c.id == a.id);
    blocked.v37.settings['risk'] = 'unassessed';
    await expectLater(repo.transitionRoute(blocked, 'a', 'active', choice),
        throwsFormatException);
    expect((await repo.loadProfile()).activeCaseId, b.id);
    expect((await repo.loadProfile()).tradeoffs, hasLength(2));
    await repo.deleteCase(b.id);
    expect((await repo.loadProfile()).activeCaseId, isEmpty);
  });

  test('可逆实验许可不能升级为人生主线，失败不写入取舍记录', () async {
    final c = plannedCase()..v37 = decision();
    c.v37.gaps.add(OsGap({'question': '仍未知', 'access': 'experience'}));
    c.v37.settings['experimentPlan'] = '十分钟试验';
    await repo.saveCase(c);
    await expectLater(
        repo.transitionRoute(c, 'a', 'active', {
          'reason': '尝试',
          'sacrifice': '其他路径',
          'opportunityCost': '时间',
          'accepted': true
        }),
        throwsFormatException);
    expect((await repo.loadProfile()).tradeoffs, isEmpty);
    expect(
        (await repo.loadCases())
            .single
            .v37
            .routes
            .where((r) => r.status == 'active'),
        isEmpty);
  });

  test('新图、证据、准备、力量、认识差异与旧复盘关闭重开后完整保留', () async {
    final c = plannedCase()..v37 = decision();
    c.v37.evidence.add(proof());
    c.v37.nodes.add(node('n1', 1));
    c.v37.gaps.add(OsGap({
      'id': 'g',
      'question': '未来状态',
      'evidenceIds': ['proof']
    }));
    c.beginCognition();
    c.completeCognition('证据未改变选择', noChangeReason: '原先已经考虑');
    c.v37.futureOptions.add(OsFutureOption(
        {'routeId': 'a', 'nodeId': 'n1', 'delta': 'opened', 'title': '新机会'}));
    c.v37.settings['futureMoment'] =
        DateTime.now().add(const Duration(days: 1)).toIso8601String();
    final i = OsIntervention({
      'gapId': 'g',
      'type': 'reflect',
      'window': 'now',
      'task': '对照记录',
      'source': '行动日志',
      'expectedChange': '核对信念'
    });
    c.v37.interventions.add(i);
    c.startIntervention(i);
    c.completeIntervention(i, '未发生变化');
    c.commit();
    c.addReview(reviewFor(c));
    final p = SelfOsProfile()
      ..strengths.add(OsStrength({
        'title': '坚持',
        'observations': [
          {'reviewId': c.reviews.single.id, 'effect': 'helped'}
        ]
      }));
    await repo.saveCaseAndProfile(c, p);
    final before = c.toJson();
    await repo.close();
    expect((await repo.loadCases()).single.toJson(), before);
    expect((await repo.loadProfile()).toJson(), p.toJson());
  });
}
