import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/data/store.dart';
import 'package:sqflite/sqflite.dart';

import 'fixtures.dart';

// Android's SQLiteDatabase.execSQL rejects result-producing PRAGMAs. The FFI
// backend does not, so exercise the real Dart plugin against this platform
// contract too. integration_test covers the actual Android SQLite/Keystore.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tekartik.sqflite');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('Android startup and privacy cleanup use result-capable SQL operations',
      () async {
    final temp = await Directory.systemTemp.createTemp('mirror_android_sql_');
    final queries = <String>[];
    var nextId = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      final sql = args['sql'] as String? ?? '';
      switch (call.method) {
        case 'openDatabase':
          return {'id': ++nextId};
        case 'closeDatabase':
        case 'options':
          return null;
        case 'execute':
          if (sql.contains('PRAGMA secure_delete') ||
              sql.contains('PRAGMA wal_checkpoint')) {
            throw PlatformException(
                code: 'sqlite_error',
                message: 'Queries can be performed using SQLiteDatabase query '
                    'or rawQuery methods only.');
          }
          return args['inTransaction'] == true ? {'transactionId': 1} : null;
        case 'query':
          queries.add(sql);
          if (sql == 'PRAGMA user_version') {
            return [{'user_version': 0}];
          }
          if (sql == 'PRAGMA secure_delete = ON') {
            return [{'secure_delete': 1}];
          }
          if (sql == 'PRAGMA wal_checkpoint(TRUNCATE)') {
            return [{'busy': 0, 'log': -1, 'checkpointed': -1}];
          }
          return <Map<String, Object?>>[];
        case 'update':
          return 0;
        default:
          throw StateError('Unexpected database method ${call.method}');
      }
    });
    SqliteMirrorStore? store;
    try {
      // First demonstrate that the pre-fix open callback fails this contract.
      await expectLater(
          databaseFactorySqflitePlugin.openDatabase('${temp.path}/legacy.sqlite',
              options: OpenDatabaseOptions(onConfigure: (db) async {
                await db.execute('PRAGMA secure_delete = ON');
              })),
          throwsA(isA<DatabaseException>()));

      store = await SqliteMirrorStore.open(
          factory: databaseFactorySqflitePlugin,
          path: '${temp.path}/current.sqlite',
          cipher: TestCipher());
      expect(await store.list(), isEmpty);
      await store.retractEvidence({'unused-test-id'});
      await store.deleteCase('unused-test-case');
      expect(queries, contains('PRAGMA secure_delete = ON'));
      expect(queries.where((sql) => sql == 'PRAGMA wal_checkpoint(TRUNCATE)'),
          hasLength(3));
    } finally {
      await store?.close();
      messenger.setMockMethodCallHandler(channel, null);
      await temp.delete(recursive: true);
    }
  });
}
