import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_repository.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;

void main() {
  late Directory directory;
  late SelfOsRepository repository;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('self-os-test-');
    repository = SelfOsRepository(
        factory: databaseFactoryFfi, path: '${directory.path}/self-os.db');
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test('独立数据库关闭重开后保留完整案例、复盘和个人模型', () async {
    final c = plannedCase()..commit();
    c.addReview(reviewFor(c));
    await repository.saveCase(c);
    final profile = SelfOsProfile()..manual['strengths'] = '能在焦虑中先做十分钟';
    profile.principles.add({
      'id': 'p1',
      'rule': '先做小实验',
      'evidenceIds': [c.reviews.single.id]
    });
    await repository.saveProfile(profile);
    await repository.close();
    final loaded = (await repository.loadCases()).single;
    expect(loaded.reviews.single.predictionError, 3);
    expect((await repository.loadProfile()).principles.single['evidenceIds'],
        [c.reviews.single.id]);
    final tables = await (await repository.database)
        .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    expect(tables.map((t) => t['name']), containsAll(['cases', 'profile']));
    expect(tables.any((t) => '${t['name']}'.contains('will_mirror')), isFalse);
  });

  test('路线状态和取舍证据原子写入，拒绝两条同时主线', () async {
    final a = plannedCase()..routeStatus = 'active';
    final b = SelfOsCase(problem: '学习')..routeStatus = 'experimental';
    final profile = SelfOsProfile();
    await repository.saveRouteDecision([a, b], profile);
    a.routeStatus = 'secondary';
    b.routeStatus = 'active';
    profile.tradeoffs
        .add({'caseId': b.id, 'reason': '现实反馈', 'sacrifice': '减少副业投入'});
    await repository.saveRouteDecision([a, b], profile);
    expect(
        (await repository.loadCases())
            .singleWhere((c) => c.routeStatus == 'active')
            .id,
        b.id);
    expect((await repository.loadProfile()).tradeoffs, hasLength(1));
    a.routeStatus = 'active';
    await expectLater(
        repository.saveRouteDecision([a, b], profile), throwsFormatException);
    expect(
        (await repository.loadCases()).where((c) => c.routeStatus == 'active'),
        hasLength(1));
  });

  test('损坏记录报错而非清空历史，删除仅作用于指定案例', () async {
    final a = plannedCase();
    final b = SelfOsCase(problem: '读书');
    await repository.saveCase(a);
    await repository.saveCase(b);
    await repository.deleteCase(a.id);
    expect((await repository.loadCases()).single.id, b.id);
    await (await repository.database).update('cases', {'document': '{broken'},
        where: 'id = ?', whereArgs: [b.id]);
    await expectLater(repository.loadCases(), throwsFormatException);
    expect((await (await repository.database).query('cases')).length, 1);
  });
}
