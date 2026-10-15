import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/data/store.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/presentation/module_page.dart';

import 'fixtures.dart';

class _UnavailableModel extends OfflineModel {
  @override
  Future<String> label() async => throw StateError('PRIVATE_PROVIDER_DETAIL');
}

class _UnavailableReminders extends TestReminders {
  @override
  Future<Set<int>> pending() async =>
      throw PlatformException(code: 'PRIVATE_NOTIFICATION_DETAIL');
}

class _RetryStore extends MemoryStore {
  Object? failure;
  int reads = 0;
  @override
  Future<List<CaseFile>> list() async {
    reads++;
    if (failure != null) throw failure!;
    return super.list();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(AndroidVaultCipher.channel, null),
  );

  test(
    'native vault errors expose only safe categories, never native details',
    () async {
      final cipher = AndroidVaultCipher();
      for (final code in [
        'vault_key_missing',
        'vault_authentication_failed',
        'vault_invalid_payload',
        'vault_unavailable',
        'UNKNOWN_PRIVATE_CODE',
      ]) {
        messenger.setMockMethodCallHandler(AndroidVaultCipher.channel, (
          _,
        ) async {
          throw PlatformException(
            code: code,
            message: 'PRIVATE_PLAINTEXT',
            details: 'PRIVATE_CIPHERTEXT_AND_CREDENTIAL',
          );
        });
        for (final request in [
          () => cipher.encrypt('private text', 'context'),
          () => cipher.decrypt('private ciphertext', 'context'),
        ]) {
          await expectLater(
            request(),
            throwsA(
              isA<MirrorProblem>()
                  .having(
                    (e) => e.code,
                    'safe code',
                    code.startsWith('vault_') ? code : 'vault_unavailable',
                  )
                  .having(
                    (e) => e.message,
                    'no private details',
                    isNot(contains('PRIVATE')),
                  ),
            ),
          );
        }
      }
    },
  );

  test(
    'missing channel and empty native reply cannot write plaintext',
    () async {
      final cipher = AndroidVaultCipher();
      await expectLater(
        cipher.encrypt('private text', 'context'),
        throwsA(isA<MirrorProblem>()),
      );
      messenger.setMockMethodCallHandler(
        AndroidVaultCipher.channel,
        (_) async => null,
      );
      await expectLater(
        cipher.encrypt('private text', 'context'),
        throwsA(isA<MirrorProblem>()),
      );
      await expectLater(
        cipher.decrypt('ciphertext', 'context'),
        throwsA(isA<MirrorProblem>()),
      );
    },
  );

  test(
    'optional provider and reminder failures keep the local ledger usable',
    () async {
      final store = MemoryStore();
      final existing = newCase('保留已有真实记录');
      await store.save(existing, expectedRevision: 0);
      final controller = MirrorController(
        store: store,
        model: _UnavailableModel(),
        reminders: _UnavailableReminders(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.initialized, isTrue);
      expect(controller.file(existing.id)?.issue, existing.issue);
      expect(controller.notice, contains('继续本地记录'));
      expect(controller.notice, contains('未确认提醒已送达'));
      expect(controller.notice, isNot(contains('PRIVATE')));
      final created = await controller.create('服务不可用时仍可新增事实');
      expect(await store.load(created.id), isNotNull);
      expect(controller.files, hasLength(2));
      expect(
        controller.files.expand((f) => f.current(NodeKind.reminder)),
        isEmpty,
      );
    },
  );

  test(
    'storage failures remain blocking and preserve the existing records',
    () async {
      final store = _RetryStore()
        ..failure = const MirrorProblem(
          '资料验证未通过',
          code: 'vault_authentication_failed',
        );
      final existing = newCase('不得用空库替代');
      await store.save(existing, expectedRevision: 0);
      final controller = MirrorController(
        store: store,
        model: OfflineModel(),
        reminders: TestReminders(),
      );
      addTearDown(controller.dispose);
      await expectLater(controller.initialize(), throwsA(isA<MirrorProblem>()));
      expect(controller.initialized, isFalse);
      expect(store.data[existing.id]?.issue, existing.issue);
      store.failure = null;
      await controller.initialize();
      expect(controller.file(existing.id)?.issue, existing.issue);
    },
  );

  testWidgets(
    'startup error can retry without deleting or replacing any data',
    (tester) async {
      final store = _RetryStore()
        ..failure = const MirrorProblem(
          '本地资料库暂时无法打开。原资料已保留。',
          code: 'database_open_failed',
        );
      final existing = newCase('覆盖安装前保存的课题');
      await store.save(existing, expectedRevision: 0);
      final controller = MirrorController(
        store: store,
        model: OfflineModel(),
        reminders: TestReminders(),
      );
      await tester.pumpWidget(
        MaterialApp(home: WillMirrorModulePage(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('database_open_failed'), findsOneWidget);
      expect(find.textContaining('加密资料'), findsNothing);
      store.failure = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mirror-case-input')), findsOneWidget);
      expect(controller.file(existing.id)?.issue, existing.issue);
      expect(store.reads, 2);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('unknown startup error is neutral and usable with large text', (
    tester,
  ) async {
    final store = _RetryStore()..failure = StateError('PRIVATE_EXCEPTION_TEXT');
    final controller = MirrorController(
      store: store,
      model: OfflineModel(),
      reminders: TestReminders(),
    );
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: WillMirrorModulePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE_EXCEPTION_TEXT'), findsNothing);
    expect(find.textContaining('加密资料'), findsNothing);
    expect(find.textContaining('module_startup_failed'), findsOneWidget);
    await tester.ensureVisible(find.text('重试'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
