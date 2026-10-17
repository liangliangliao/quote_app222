import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/data/store.dart';
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/integration/reminders.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory temp;
  late SqliteMirrorStore store;
  late TestCipher cipher;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wm_store_test_');
    cipher = TestCipher();
    store = await SqliteMirrorStore.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/test.sqlite',
        cipher: cipher);
  });
  tearDown(() async {
    await store.close();
    await temp.delete(recursive: true);
  });
  test(
    'first open configures secure deletion and foreign key enforcement',
    () async {
      expect(
        (await store.db.rawQuery('PRAGMA secure_delete')).single.values.single,
        1,
      );
      expect(
        (await store.db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      expect(await store.list(), isEmpty);
      expect((await store.settings()).remoteScoring, isFalse);
    },
  );
  test(
    'reopening preserves encrypted settings, cases and every old revision',
    () async {
      final f = newCase('覆盖安装与重启必须保留的记录');
      await store.save(f, expectedRevision: 0);
      final revised = f.evolve(step: 2);
      await store.save(revised, expectedRevision: f.revision);
      await store.saveSettings(const MirrorSettings(darkMode: 'dark'));
      final cases = await store.db.query('cases');
      final history = await store.db.query('case_history');
      final settings = await store.db.query('settings');
      await store.close();
      store = await SqliteMirrorStore.open(
        factory: databaseFactoryFfi,
        path: '${temp.path}/test.sqlite',
        cipher: cipher,
      );
      expect(await store.db.query('cases'), cases);
      expect(await store.db.query('case_history'), history);
      expect(await store.db.query('settings'), settings);
      expect((await store.load(f.id))!.revision, revised.revision);
      expect((await store.settings()).darkMode, 'dark');
      expect(await store.history(f.id), hasLength(2));
      await store.deleteCase(f.id);
      expect(await store.list(), isEmpty);
      expect(await store.history(f.id), isEmpty);
    },
  );
  test('database and history persist cipher payload, no private raw strings',
      () async {
    final f = newCase('PRIVATE-CASE-SENTINEL');
    await store.save(f, expectedRevision: 0);
    final next = f.evolve(step: 2);
    await store.save(next, expectedRevision: f.revision);
    final rows = await store.db.query('cases');
    expect(rows.single['payload'], startsWith('opaque-'));
    expect(rows.toString(), isNot(contains(f.issue)));
    expect((await store.history(f.id)).map((x) => x.revision),
        [next.revision, f.revision]);
    expect((await store.load(f.id))!.issue, f.issue);
    final bytes = await File('${temp.path}/test.sqlite').readAsBytes();
    expect(String.fromCharCodes(bytes), isNot(contains(f.issue)));
  });
  test('optimistic concurrency prevents late AI from overwriting a correction',
      () async {
    final f = newCase();
    await store.save(f, expectedRevision: 0);
    await store.save(f.evolve(step: 2), expectedRevision: f.revision);
    await expectLater(
        store.save(f.evolve(step: 3), expectedRevision: f.revision),
        throwsA(isA<VersionConflict>()));
    expect((await store.load(f.id))!.step, 2);
  });
  test(
      'authentication failure preserves rows and never manufactures empty replacement',
      () async {
    final f = newCase();
    await store.save(f, expectedRevision: 0);
    await store.db.update('cases', {'payload': 'tampered'});
    await expectLater(store.load(f.id), throwsA(isA<MirrorProblem>()));
    expect(await store.db.query('cases'), hasLength(1));
  });
  test('withdrawal redacts all versions and dependent cross-case explanations',
      () async {
    var a = prepared();
    a = commands.sealPlan(a, planBody(a));
    await store.save(a, expectedRevision: 0);
    await store.save(a.evolve(step: 6), expectedRevision: a.revision);
    var b = newCase('独立课题');
    final m = motive(b, 1, refs: [a.nodes.first.id]);
    b = commands.append(b, [m], authorized: {a.nodes.first.id: a.nodes.first});
    await store.save(b, expectedRevision: 0);
    final dates = (await store.history(a.id)).map((v) => v.updatedAt).toList();
    final changed = await store.retractEvidence({a.nodes.first.id});
    expect(changed, containsAll([a.id, b.id]));
    expect((await store.load(b.id))!.node(m.id)!.status, NodeStatus.stale);
    final history = await store.history(a.id);
    expect(history.skip(1).map((v) => v.updatedAt), dates);
    for (final version in history) {
      expect(canonicalJson(version.toJson()), isNot(contains('我明天要确认岗位条件')));
      expect(version.nodes.first.body, {'redacted': true});
    }
  });
  test(
      'cross-case revoke preserves source while clearing all dependent histories',
      () async {
    final a = newCase('SOURCE PRIVATE');
    await store.save(a, expectedRevision: 0);
    var b = newCase('第二课题');
    final m = motive(b, 1, refs: [a.nodes.first.id]);
    b = commands.append(b, [m], authorized: {a.nodes.first.id: a.nodes.first});
    await store.save(b, expectedRevision: 0);
    await store.revokeCrossCase(a.id);
    expect((await store.load(a.id))!.issue, 'SOURCE PRIVATE');
    expect((await store.load(b.id))!.node(m.id)!.body, {'redacted': true});
    expect(
        (await store.history(b.id))
            .every((f) => f.node(m.id)!.body['redacted'] == true),
        isTrue);
  });
  test('case deletion removes histories and export excludes credentials',
      () async {
    final f = newCase();
    await store.save(f, expectedRevision: 0);
    await store.saveSettings(const MirrorSettings(
        gatewayAccessToken: 'TOKEN_SENTINEL', crossCaseIds: ['removed']));
    expect(await store.exportJson(), isNot(contains('TOKEN_SENTINEL')));
    await store.deleteCase(f.id);
    expect(await store.load(f.id), isNull);
    expect(await store.history(f.id), isEmpty);
  });
  test(
      'notification round trip verifies all IDs and opened is device event only',
      () async {
    final reminders = TestReminders();
    final c = MirrorController(
        store: store, model: OfflineModel(), reminders: reminders);
    await c.initialize();
    var f = prepared();
    await store.save(f, expectedRevision: 0);
    await c.reload();
    await c.seal(
        f.id,
        {
          ...planBody(f),
          'remindAt': DateTime.now()
              .add(const Duration(hours: 1))
              .toUtc()
              .toIso8601String()
        },
        reminderPermission: true);
    final link = reminders.jobs.values.single;
    expect(MirrorLink.parse(link.encode())!.planId, link.planId);
    final wrong = MirrorLink(
        caseId: link.caseId,
        planId: link.planId,
        triggerId: link.triggerId,
        jobId: link.jobId,
        version: link.version,
        sceneId: 'forged');
    expect(await c.openNotification(wrong), isFalse);
    expect(await c.openNotification(link), isTrue);
    f = c.file(f.id)!;
    expect(f.phase, TimePhase.t0);
    expect(f.latest(NodeKind.reminder)!.origin, EvidenceOrigin.deviceEvent);
    expect(f.current(NodeKind.observation), isEmpty);
    expect(f.current(NodeKind.triggerCheck), isEmpty);
    expect(await c.openNotification(link), isFalse);
    c.dispose();
  });
  test('withdrawal cancels OS reminder before its job ID is redacted',
      () async {
    final reminders = TestReminders();
    final c = MirrorController(
        store: store, model: OfflineModel(), reminders: reminders);
    await c.initialize();
    final f = prepared();
    await store.save(f, expectedRevision: 0);
    await c.reload();
    await c.seal(
        f.id,
        {
          ...planBody(f),
          'remindAt': DateTime.now()
              .add(const Duration(hours: 1))
              .toUtc()
              .toIso8601String()
        },
        reminderPermission: true);
    final job = reminders.jobs.keys.single;
    await c.retract(f.nodes.first.id);
    expect(reminders.jobs, isEmpty);
    expect(reminders.cancelled, contains(job));
    expect(c.file(f.id)!.latest(NodeKind.plan), isNull);
    c.dispose();
  });
  test(
      'denied reminder permission preserves plan and never fabricates delivery',
      () async {
    final reminders = TestReminders()..permitted = false;
    final c = MirrorController(
        store: store, model: OfflineModel(), reminders: reminders);
    await c.initialize();
    final f = prepared();
    await store.save(f, expectedRevision: 0);
    await c.reload();
    await c.seal(
        f.id,
        {
          ...planBody(f),
          'remindAt': DateTime.now()
              .add(const Duration(hours: 1))
              .toUtc()
              .toIso8601String()
        },
        reminderPermission: true);
    expect(c.file(f.id)!.latest(NodeKind.plan), isNotNull);
    expect(c.file(f.id)!.latest(NodeKind.reminder)!.text('state'), 'denied');
    expect(reminders.jobs, isEmpty);
    c.dispose();
  });
  test(
      'malformed or unrelated notification payload is not handled by this module',
      () {
    for (final value in [
      'https://case/123',
      'willmirror://other/123',
      'willmirror://case/123?step=99',
      'willmirror://case/a/b',
      'willmirror://case/'
    ]) {
      expect(MirrorLink.parse(value), isNull);
    }
  });
}
