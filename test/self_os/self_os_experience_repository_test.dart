import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_principles.dart';
import 'package:quote_app/self_os/self_os_repository.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;
import 'self_os_principles_test.dart' show experienceSource, principleFor;

void main() {
  late Directory directory;
  late SelfOsRepository repo;
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('self-os-experience-');
    repo = SelfOsRepository(
        factory: databaseFactoryFfi, path: '${directory.path}/self-os.db');
  });
  tearDown(() async {
    await repo.close();
    await directory.delete(recursive: true);
  });

  test('T361 关闭重开保留原则版本、T0/T1/T2、反例和独立结果', () async {
    final source = experienceSource(), c = plannedCase();
    final p = principleFor([source]),
        profile = SelfOsProfile()..principles.add(p);
    final a = SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true);
    SelfOsPrinciples.checkIn(c, a['id'], 'explicitly_recalled');
    final r = reviewFor(c);
    c.addReview(r);
    SelfOsPrinciples.review(c, profile, a['id'], r,
        use: 'applied_self_report',
        attempt: 'completed',
        preparation: '准备资料',
        effect: 'unknown',
        counterExample: true);
    await repo.saveCase(source);
    await repo.saveCaseAndProfile(c, profile);
    await repo.close();
    final cases = await repo.loadCases();
    final stored = cases.firstWhere((v) => v.id == c.id);
    final saved = SelfOsPrinciples.applications(stored).single;
    expect(saved['atT0'], isNotNull);
    expect(saved['atT1'], isNotNull);
    expect(saved['atT2'], isNotNull);
    expect(saved['principleVersion'], 1);
    expect((await repo.loadProfile()).principles.single['version'], 2);
    expect(saved['causalConclusion'], 'unknown');
    expect(stored.reviews.single.id, r.id);
  });

  for (final operation in ['delete', 'withdraw', 'unshare']) {
    test('T339/T363 $operation 在同一事务撤回派生解释，其他案例实做保留', () async {
      final source = experienceSource(), c = plannedCase();
      final p = principleFor([source]),
          profile = SelfOsProfile()..principles.add(p);
      SelfOsPrinciples.choose(c, p, [source, c],
          contextMatches: true, safe: true);
      await repo.saveCase(source);
      await repo.saveCaseAndProfile(c, profile);
      switch (operation) {
        case 'delete':
          await repo.deleteCase(source.id);
        case 'withdraw':
          await repo.withdrawExperience(source.id,
              reviewId: source.reviews.single.id);
        case 'unshare':
          await repo.withdrawExperience(source.id);
      }
      await repo.close();
      final cases = await repo.loadCases(),
          savedProfile = await repo.loadProfile();
      final saved = cases.firstWhere((v) => v.id == c.id);
      expect(savedProfile.principles.single['stale'], isTrue);
      expect(savedProfile.principles.single['rule'], isNot(contains('岗位')));
      expect(SelfOsPrinciples.applications(saved).single['principleSnapshot'],
          isEmpty);
      expect(SelfOsPrinciples.eligible(savedProfile, cases, saved), isEmpty);
      if (operation == 'delete') {
        expect(cases.any((v) => v.id == source.id), isFalse);
      } else {
        final preserved = cases.firstWhere((v) => v.id == source.id);
        expect(preserved.reviews.single.result, source.reviews.single.result);
        if (operation == 'withdraw')
          expect(preserved.reviews.single.notes['experienceWithdrawn'], 'yes');
        if (operation == 'unshare')
          expect(preserved.v37.flag('shareExperience'), isFalse);
      }
    });
  }

  test('撤回写入失败完整回滚，不留下只删源却仍可用的原则', () async {
    final source = experienceSource(), c = plannedCase();
    final profile = SelfOsProfile()..principles.add(principleFor([source]));
    await repo.saveCase(source);
    await repo.saveCaseAndProfile(c, profile);
    final db = await repo.database;
    await db.execute(
        "CREATE TRIGGER reject_profile_update BEFORE UPDATE ON profile BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(repo.deleteCase(source.id), throwsException);
    expect((await repo.loadCases()).any((v) => v.id == source.id), isTrue);
    expect(jsonEncode((await repo.loadProfile()).toJson()),
        jsonEncode(profile.toJson()));
  });

  test('旧版个人原则保留数据，需补齐边界并重新认可后使用', () async {
    final profile = SelfOsProfile()
      ..principles.add({
        'id': 'legacy',
        'rule': '旧规则',
        'condition': '旧条件',
        'evidenceIds': ['old-review']
      });
    await repo.saveProfile(profile);
    final raw = (await repo.loadProfile()).principles.single;
    expect(raw['rule'], '旧规则');
    expect(SelfOsPrinciples.normalize(raw)['status'], 'needs_review');
  });

  test('T339/T363 撤回后的迟到AI保存和旧个人模型均不能恢复旧解释', () async {
    final source = experienceSource(), c = plannedCase();
    final profile = SelfOsProfile()..principles.add(principleFor([source]));
    SelfOsPrinciples.choose(c, profile.principles.single, [source, c],
        contextMatches: true, safe: true);
    await repo.saveCase(source);
    await repo.saveCaseAndProfile(c, profile);
    final lateCase = c.copy(),
        lateProfile = SelfOsProfile.fromJson(osClone(profile.toJson()));
    await repo.withdrawExperience(source.id,
        reviewId: source.reviews.single.id);
    lateCase.suggestions['action'] = [
      {'field': 'firstAction', 'value': '迟到的旧解释'}
    ];
    await expectLater(
        repo.saveCase(lateCase), throwsA(isA<SelfOsStaleWrite>()));
    await expectLater(
        repo.saveProfile(lateProfile), throwsA(isA<SelfOsStaleWrite>()));
    final stored = (await repo.loadCases()).firstWhere((v) => v.id == c.id);
    expect(stored.storageRevision, greaterThan(lateCase.storageRevision));
    expect(stored.suggestions, isEmpty);
    expect(SelfOsPrinciples.applications(stored).single['stale'], isTrue);
    expect((await repo.loadProfile()).principles.single['stale'], isTrue);
  });

  test('T362 关闭全部经验提醒取消安排，保留手动工作台和未知送达状态', () async {
    final source = experienceSource(), c = plannedCase();
    final p = principleFor([source]),
        profile = SelfOsProfile()..principles.add(p);
    profile.experienceSettings['remindersEnabled'] = true;
    final a = SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true);
    final entries = SelfOsPrinciples.applications(c);
    entries.single
        .addAll({'reminderStatus': 'scheduled', 'deliveryStatus': 'unknown'});
    c.v37.settings['principleApplications'] = entries;
    await repo.saveCase(source);
    await repo.saveCaseAndProfile(c, profile);
    profile.experienceSettings['remindersEnabled'] = false;
    await repo.saveProfile(profile);
    final saved = (await repo.loadCases()).firstWhere((v) => v.id == c.id);
    final stored = SelfOsPrinciples.applications(saved).single;
    expect(stored['id'], a['id']);
    expect(stored['reminderStatus'], 'cancelled');
    expect(stored['deliveryStatus'], 'unknown');
    expect(stored['exposureStatus'], 'accepted');
    expect(SelfOsPrinciples.eligible(profile, [source, saved], saved),
        hasLength(1));
  });

  test('原子保存失败不提前推进存储版本，同一份草稿可在恢复后重试', () async {
    final c = plannedCase(), profile = SelfOsProfile();
    await repo.saveCaseAndProfile(c, profile);
    final cVersion = c.storageRevision, pVersion = profile.storageRevision;
    final db = await repo.database;
    await db.execute(
        "CREATE TRIGGER block_profile_insert BEFORE INSERT ON profile BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    c.fields['k2'] = '仍保留的用户草稿';
    await expectLater(repo.saveCaseAndProfile(c, profile), throwsException);
    expect(c.storageRevision, cVersion);
    expect(profile.storageRevision, pVersion);
    expect((await repo.loadCases()).single.text('k2'), isNot('仍保留的用户草稿'));
    await db.execute('DROP TRIGGER block_profile_insert');
    await repo.saveCaseAndProfile(c, profile);
    expect((await repo.loadCases()).single.text('k2'), '仍保留的用户草稿');
    expect(c.storageRevision, cVersion + 1);
    expect(profile.storageRevision, pVersion + 1);
  });
}
