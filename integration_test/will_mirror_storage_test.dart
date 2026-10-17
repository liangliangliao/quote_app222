import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/data/store.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/rules.dart';
import 'package:quote_app/will_mirror/presentation/module_page.dart';
import 'package:sqflite/sqflite.dart';

import '../test/will_mirror/fixtures.dart' show OfflineModel, TestReminders;

// Run on Android, with the real sqflite plugin and Android Keystore channel.
// Never open/delete the user's actual database or delete any Keystore alias.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('MIRROR_UPGRADE_PHASE');
  const sentinel = 'ANDROID-TEST-ONLY: 覆盖安装后仍保留的课题';

  if (phase == 'seed' || phase == 'verify') {
    testWidgets('Android persisted ledger across APK replacement: $phase', (
      tester,
    ) async {
      final path = p.join(
        await getDatabasesPath(),
        'will_mirror_android_upgrade_probe.sqlite',
      );
      if (phase == 'seed') await deleteDatabase(path);
      final store = await SqliteMirrorStore.open(path: path);
      try {
        if (phase == 'seed') {
          final file = CaseCommands().create(sentinel);
          await store.save(file, expectedRevision: 0);
          await store.save(
            file.evolve(step: 2),
            expectedRevision: file.revision,
          );
          await store.saveSettings(const MirrorSettings(darkMode: 'dark'));
        } else {
          final files = await store.list();
          expect(files, hasLength(1));
          expect(files.single.issue, sentinel);
          expect(files.single.step, 2);
          expect(await store.history(files.single.id), hasLength(2));
          expect((await store.settings()).darkMode, 'dark');
        }
      } finally {
        await store.close();
        if (phase == 'verify') await deleteDatabase(path);
      }
    });
    return;
  }

  testWidgets('real Android startup, encryption, reopen, withdrawal and delete',
      (
    tester,
  ) async {
    expect(
      Platform.isAndroid,
      isTrue,
      reason: 'This regression must exercise Android, not the desktop FFI.',
    );
    final path = p.join(
      await getDatabasesPath(),
      'will_mirror_android_probe_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    var store = await SqliteMirrorStore.open(path: path);
    MirrorController? controller;
    try {
      // Reproduce the original operation on Android itself, not only through
      // the desktop channel mock. The fixed open above uses rawQuery instead.
      await expectLater(
        store.db.execute('PRAGMA secure_delete = ON'),
        throwsA(isA<DatabaseException>()),
      );
      expect(await store.list(), isEmpty);
      expect(
        (await store.db.rawQuery('PRAGMA secure_delete')).single.values.single,
        1,
      );
      expect(
        (await store.db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      controller = MirrorController(
        store: store,
        model: OfflineModel(),
        reminders: TestReminders(),
      );
      await tester.pumpWidget(
        MaterialApp(home: WillMirrorModulePage(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mirror-case-input')), findsOneWidget);
      expect(find.text('资料暂时无法打开'), findsNothing);
      final file = await controller.create(sentinel);
      await controller.addEvidence(file.id, 'ANDROID-TEST-ONLY: 后续补充事实');
      await controller.savePreferences(const MirrorSettings(darkMode: 'dark'));
      final before = await store.db.query('cases');
      final historyBefore = await store.db.query('case_history');
      final payload = before.single['payload'] as String;
      expect(payload, startsWith('v1.'));
      expect(payload, isNot(contains(sentinel)));

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      controller = null;
      await store.close();
      store = await SqliteMirrorStore.open(path: path);
      expect(await store.db.query('cases'), before);
      expect(await store.db.query('case_history'), historyBefore);
      expect((await store.load(file.id))!.issue, sentinel);
      expect((await store.settings()).darkMode, 'dark');

      // AAD mismatch must fail without deleting data or creating another key.
      await expectLater(
        AndroidVaultCipher().decrypt(payload, 'wrong-context'),
        throwsA(isA<MirrorProblem>()),
      );
      expect(await store.db.query('cases'), before);
      expect((await store.load(file.id))!.issue, sentinel);

      // These used to run wal_checkpoint through execSQL and fail on Android.
      await store.retractEvidence({file.nodes.first.id});
      expect((await store.load(file.id))!.nodes.first.body, {'redacted': true});
      for (final version in await store.history(file.id)) {
        expect(canonicalJson(version.toJson()), isNot(contains(sentinel)));
      }
      await store.deleteCase(file.id);
      expect(await store.list(), isEmpty);
      expect(await store.history(file.id), isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller?.dispose();
      await store.close();
      await deleteDatabase(path);
    }
  });
}
