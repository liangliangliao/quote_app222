import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/kindling/kindling.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Set<String>> tables() async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    return rows.map((Map<String, Object?> r) => '${r['name']}').toSet();
  }

  test('createAll builds every k_ table and is idempotent', () async {
    await KindlingSchema.createAll(db);
    await KindlingSchema.createAll(db);
    await KindlingSchema.createAll(db);

    final Set<String> names = await tables();
    for (final String expected in <String>[
      'k_item',
      'k_probe',
      'k_verdict',
      'k_burn',
      'k_recall',
      'k_resistance',
      'k_meta',
    ]) {
      expect(names, contains(expected));
    }
    expect(
      await KindlingSchema.readSchemaVersion(db),
      KindlingSchema.schemaVersion,
    );
  });

  test('migrate is idempotent and independent of host version numbers',
      () async {
    await KindlingSchema.migrate(db, 1, 35);
    await KindlingSchema.migrate(db, 35, 36);
    expect(
      await KindlingSchema.readSchemaVersion(db),
      KindlingSchema.schemaVersion,
    );
    expect(await tables(), contains('k_item'));
  });

  test('no foreign key points outside the module', () async {
    await KindlingSchema.createAll(db);
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'k!_%' ESCAPE '!'",
    );
    expect(rows, isNotEmpty);
    for (final Map<String, Object?> row in rows) {
      final String table = '${row['name']}';
      final List<Map<String, Object?>> fks =
          await db.rawQuery('PRAGMA foreign_key_list($table)');
      for (final Map<String, Object?> fk in fks) {
        expect('${fk['table']}', startsWith('k_'));
      }
    }
  });

  test('item schema carries no goal / plan / deadline / streak column',
      () async {
    await KindlingSchema.createAll(db);
    final List<Map<String, Object?>> cols =
        await db.rawQuery('PRAGMA table_info(k_item)');
    final Set<String> names =
        cols.map((Map<String, Object?> c) => '${c['name']}').toSet();
    expect(names, <String>{
      'id',
      'title',
      'kind',
      'note',
      'created_at',
      'updated_at',
      'released_at',
      'release_note',
    });
  });

  test('probe score is constrained to 0..4', () async {
    await KindlingSchema.createAll(db);
    final int itemId = await db.insert('k_item', <String, Object?>{
      'title': 'x',
      'kind': 'other',
      'created_at': 1,
      'updated_at': 1,
    });
    expect(
      () => db.insert('k_probe', <String, Object?>{
        'item_id': itemId,
        'score': 9,
        'recorded_at': 1,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
