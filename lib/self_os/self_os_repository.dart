import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'self_os_models.dart';
import 'self_os_v37_rules.dart';

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
    value.v37.validate();
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

  Future<void> saveCaseAndProfile(
      SelfOsCase value, SelfOsProfile profile) async {
    value.v37.validate();
    value.updatedAt = DateTime.now();
    await (await database).transaction((tx) async {
      await tx.insert(
          'cases',
          {
            'id': value.id,
            'updated_at': value.updatedAt.millisecondsSinceEpoch,
            'document': jsonEncode(value.toJson())
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.insert(
          'profile', {'id': 1, 'document': jsonEncode(profile.toJson())},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Route state and its sacrifice/evidence record change in one transaction.
  /// Other cases are read inside that transaction, preserving a single life line.
  Future<void> transitionRoute(SelfOsCase current, String routeId,
      String status, Map<String, dynamic> decision) async {
    if (!selfOsRouteStates.containsKey(status) ||
        !current.v37.routes.any((r) => r.id == routeId))
      throw const FormatException('路线或状态无效');
    if (osText(decision['reason']).trim().isEmpty ||
        osText(decision['sacrifice']).trim().isEmpty)
      throw const FormatException('请记录选择依据与被舍弃的真实价值');
    if (status == 'active') {
      if (current.text('newInformation').trim().isNotEmpty &&
          !current.v37.flag('newInformationReviewed')) {
        throw const FormatException('先回应现场出现的重要新信息，再确认人生主线');
      }
      final gate = SelfOsV37Rules.gate(current.v37);
      if (gate.action != 'PASS')
        throw FormatException('${gate.label}：${gate.reasons.first}');
      if (decision['accepted'] != true ||
          osText(decision['opportunityCost']).trim().isEmpty)
        throw const FormatException('主线承诺需要明确接受机会成本');
      final selected = current.v37.routes.firstWhere((r) => r.id == routeId);
      if (selected.text('desire').isEmpty ||
          selected.text('ability').isEmpty ||
          selected.text('cost').isEmpty ||
          selected.text('reality').isEmpty)
        throw const FormatException('先补充路线服务的欲求、能力依据、完整代价与现实条件');
    }
    await (await database).transaction((tx) async {
      final rows = await tx.query('cases');
      final cases = rows
          .map((r) =>
              SelfOsCase.fromJson(osMap(jsonDecode(r['document']! as String))))
          .toList();
      cases.removeWhere((c) => c.id == current.id);
      cases.add(current.copy());
      final profiles = await tx.query('profile', where: 'id = 1');
      final profile = profiles.isEmpty
          ? SelfOsProfile()
          : SelfOsProfile.fromJson(
              osMap(jsonDecode(profiles.single['document']! as String)));
      final previousCase = profile.activeCaseId,
          previousRoute = profile.activeRouteId;
      final target = cases.firstWhere((c) => c.id == current.id);
      final route = target.v37.routes.firstWhere((r) => r.id == routeId);
      final from = route.status;
      if (status == 'active') {
        for (final c in cases) {
          if (c.routeStatus == 'active') c.routeStatus = 'secondary';
          for (final r in c.v37.routes.where((r) => r.status == 'active')) {
            r.data['status'] = 'secondary';
          }
        }
        target.routeStatus = 'active';
        target.v37.settings['phase'] = 'protect';
        profile.activeCaseId = target.id;
        profile.activeRouteId = route.id;
      } else if (profile.activeCaseId == target.id &&
          profile.activeRouteId == route.id) {
        profile.activeCaseId = '';
        profile.activeRouteId = '';
        target.routeStatus = status;
        target.v37.settings['phase'] = 'revise';
      }
      route.data['status'] = status;
      profile.tradeoffs.add({
        ...osClone(decision),
        'id': selfOsId(),
        'caseId': target.id,
        'routeId': route.id,
        'title': route.title,
        'from': from,
        'to': status,
        'previousCaseId': previousCase,
        'previousRouteId': previousRoute,
        'createdAt': DateTime.now().toIso8601String()
      });
      for (final c in cases) {
        c.v37.validate();
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

  Future<void> deleteCase(String id) async =>
      (await database).transaction((tx) async {
        await tx.delete('cases', where: 'id = ?', whereArgs: [id]);
        final rows = await tx.query('profile', where: 'id = 1');
        if (rows.isNotEmpty) {
          final profile = SelfOsProfile.fromJson(
              osMap(jsonDecode(rows.single['document']! as String)));
          if (profile.activeCaseId == id) {
            profile.activeCaseId = '';
            profile.activeRouteId = '';
            await tx.update(
                'profile', {'document': jsonEncode(profile.toJson())},
                where: 'id = 1');
          }
        }
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
