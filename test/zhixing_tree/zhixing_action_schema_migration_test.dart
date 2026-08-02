import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('legacy required diagnosis_id is removed before a current action insert',
      () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await database.execute('''
      CREATE TABLE zhixing_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_uid TEXT,
        diagnosis_id INTEGER NOT NULL,
        goal_id INTEGER,
        session_id INTEGER,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        barrier TEXT NOT NULL,
        risk_level TEXT NOT NULL,
        prescription_json TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await database.insert('zhixing_actions', <String, Object?>{
      'action_uid': 'legacy_with_diagnosis',
      'diagnosis_id': 17,
      'goal_id': 9,
      'session_id': 17,
      'title': '旧版行动',
      'status': 'active',
      'difficulty': 'l1',
      'barrier': 'reflectiveMotivation',
      'risk_level': 'r1',
      'prescription_json': '{}',
      'created_at_ms': 100,
      'updated_at_ms': 200,
    });

    await AppDatabase.ensureZhixingActionSchema(database);

    final info = await database.rawQuery('PRAGMA table_info(zhixing_actions)');
    final columns = info.map((row) => row['name']).toSet();
    expect(columns, isNot(contains('diagnosis_id')));
    expect(columns, contains('action_uid'));

    final migrated = await database.query('zhixing_actions');
    expect(migrated, hasLength(1));
    expect(migrated.single['session_id'], 17);
    expect(migrated.single['title'], '旧版行动');
    expect(
      (migrated.single['action_uid'] ?? '').toString(),
      'legacy_with_diagnosis',
    );

    await database.insert('zhixing_actions', <String, Object?>{
      'action_uid': 'zx_current_action',
      'goal_id': 9,
      'session_id': null,
      'title': '当前版本行动',
      'status': 'active',
      'difficulty': 'l1',
      'barrier': 'reflectiveMotivation',
      'risk_level': 'r1',
      'prescription_json': '{}',
      'created_at_ms': 300,
      'updated_at_ms': 300,
    });

    expect(await database.query('zhixing_actions'), hasLength(2));
  });
}
