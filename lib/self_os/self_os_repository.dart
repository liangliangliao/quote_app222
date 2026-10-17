import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'self_os_models.dart';

/// A separate database: no migrations or writes to another product's tables.
class SelfOsRepository {
  SelfOsRepository({DatabaseFactory? factory, String? path})
      : _factory = factory ?? databaseFactorySqflitePlugin,
        _path = path;
  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open().catchError((Object e) {
        _opening = null;
        throw e;
      });
  Future<Database> _open() async => _factory.openDatabase(
      _path ?? p.join(await _factory.getDatabasesPath(), 'self_os_v3.db'),
      options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
                'CREATE TABLE cases (id TEXT PRIMARY KEY, updated_at INTEGER NOT NULL, document TEXT NOT NULL)');
            await db.execute(
                'CREATE TABLE profile (id INTEGER PRIMARY KEY CHECK(id = 1), document TEXT NOT NULL)');
          }));

  Future<List<SelfOsCase>> loadCases() async {
    final rows =
        await (await database).query('cases', orderBy: 'updated_at DESC');
    // Corruption is surfaced to the caller; it is never silently replaced with
    // an empty history that the next save would overwrite.
    return rows
        .map((r) =>
            SelfOsCase.fromJson(osMap(jsonDecode(r['document']! as String))))
        .toList();
  }

  Future<void> saveCase(SelfOsCase value) async {
    value.updatedAt = DateTime.now();
    await (await database).insert(
        'cases',
        {
          'id': value.id,
          'updated_at': value.updatedAt.millisecondsSinceEpoch,
          'document': jsonEncode(value.toJson())
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCase(String id) async =>
      (await database).transaction((tx) async {
        await tx.delete('cases', where: 'id = ?', whereArgs: [id]);
      });
  Future<SelfOsProfile> loadProfile() async {
    final rows = await (await database).query('profile', where: 'id = 1');
    return rows.isEmpty
        ? SelfOsProfile()
        : SelfOsProfile.fromJson(
            osMap(jsonDecode(rows.single['document']! as String)));
  }

  Future<void> saveProfile(SelfOsProfile value) async => (await database)
      .insert('profile', {'id': 1, 'document': jsonEncode(value.toJson())},
          conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> saveRouteDecision(
      List<SelfOsCase> cases, SelfOsProfile profile) async {
    if (cases.where((c) => c.routeStatus == 'active').length > 1)
      throw const FormatException('同一时刻只保留一条主路线');
    await (await database).transaction((tx) async {
      for (final c in cases) {
        c.updatedAt = DateTime.now();
        await tx.insert(
            'cases',
            {
              'id': c.id,
              'updated_at': c.updatedAt.millisecondsSinceEpoch,
              'document': jsonEncode(c.toJson())
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await tx.insert(
          'profile', {'id': 1, 'document': jsonEncode(profile.toJson())},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}
