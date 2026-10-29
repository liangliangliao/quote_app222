import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'self_os_models.dart';
import 'self_os_v37_rules.dart';
import 'self_os_principles.dart';
import 'self_os_experience_reminders.dart';

class SelfOsStaleWrite implements Exception {
  const SelfOsStaleWrite();
  @override
  String toString() => '本地记录已有更新，旧草稿不能覆盖新的事实或权限。';
}

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
    final committed =
        await (await database).transaction((tx) => _writeCase(tx, value));
    value.storageRevision = committed.$1;
    value.updatedAt = committed.$2;
  }

  Future<(int, DateTime)> _writeCase(
      DatabaseExecutor tx, SelfOsCase value) async {
    final rows =
        await tx.query('cases', where: 'id = ?', whereArgs: [value.id]);
    final stored = rows.isEmpty
        ? null
        : osMap(jsonDecode(rows.single['document']! as String));
    final revision = stored?['storageRevision'] as int? ?? 0;
    if ((stored == null && value.storageRevision != 0) ||
        (stored != null && revision != value.storageRevision))
      throw const SelfOsStaleWrite();
    final now = DateTime.now(), next = revision + 1;
    await tx.insert(
        'cases',
        {
          'id': value.id,
          'updated_at': now.millisecondsSinceEpoch,
          'document': jsonEncode({
            ...value.toJson(),
            'storageRevision': next,
            'updatedAt': now.toIso8601String()
          })
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    return (next, now);
  }

  Future<void> saveCaseAndProfile(
      SelfOsCase value, SelfOsProfile profile) async {
    value.v37.validate();
    late (int, DateTime) committed;
    final cancellations = <String>{};
    await (await database).transaction((tx) async {
      await _checkPrincipleVersions(tx, profile);
      cancellations
          .addAll(await _reconcileApplications(tx, profile, current: value));
      committed = await _writeCase(tx, value);
      await tx.insert(
          'profile',
          {
            'id': 1,
            'document': jsonEncode({
              ...profile.toJson(),
              'storageRevision': profile.storageRevision + 1
            })
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    value.storageRevision = committed.$1;
    value.updatedAt = committed.$2;
    profile.storageRevision++;
    for (final id in cancellations) await SelfOsExperienceReminders.cancel(id);
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
      final gate = SelfOsV37Rules.gate(current.v37, routeId: routeId);
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
        final stored = rows.where((row) => row['id'] == c.id).firstOrNull;
        if (stored == null ||
            jsonEncode(c.toJson()) !=
                jsonEncode(SelfOsCase.fromJson(
                        osMap(jsonDecode(stored['document']! as String)))
                    .toJson())) await _writeCase(tx, c);
      }
      profile.storageRevision++;
      await tx.insert(
          'profile', {'id': 1, 'document': jsonEncode(profile.toJson())},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> deleteCase(String id) async =>
      (await database).transaction((tx) async {
        final documents = await tx.query('cases');
        final cases = documents
            .map((r) => SelfOsCase.fromJson(
                osMap(jsonDecode(r['document']! as String))))
            .toList();
        final withdrawn = {
          for (final c in cases.where((c) => c.id == id))
            for (final r in c.reviews) r.id,
        };
        await tx.delete('cases', where: 'id = ?', whereArgs: [id]);
        final rows = await tx.query('profile', where: 'id = 1');
        if (rows.isNotEmpty) {
          final profile = SelfOsProfile.fromJson(
              osMap(jsonDecode(rows.single['document']! as String)));
          if (profile.activeCaseId == id) {
            profile.activeCaseId = '';
            profile.activeRouteId = '';
          }
          cases.removeWhere((c) => c.id == id);
          SelfOsPrinciples.invalidate(profile, cases, withdrawn);
          for (final c in cases) {
            await _writeCase(tx, c);
          }
          profile.storageRevision++;
          await tx.update('profile', {'document': jsonEncode(profile.toJson())},
              where: 'id = 1');
        }
      }).then((_) => _reconcileReminders());

  Future<void> _reconcileReminders() async {
    // Post-commit platform cleanup. Link validation already blocks revoked data
    // if Android is temporarily unavailable or a generic notification remains.
    try {
      final profile = await loadProfile();
      final ids = await (await database)
          .transaction((tx) => _reconcileApplications(tx, profile));
      for (final id in ids) await SelfOsExperienceReminders.cancel(id);
    } catch (_) {}
  }

  /// Withdraw a source or cross-case permission and all derived cues atomically.
  Future<void> withdrawExperience(String caseId, {String? reviewId}) async =>
      (await database).transaction((tx) async {
        final rows = await tx.query('cases');
        final cases = rows
            .map((r) => SelfOsCase.fromJson(
                osMap(jsonDecode(r['document']! as String))))
            .toList();
        final source = cases.firstWhere((c) => c.id == caseId);
        final withdrawn = <String>{};
        if (reviewId == null) source.v37.settings['shareExperience'] = false;
        for (final r in source.reviews) {
          if (reviewId == null || r.id == reviewId) {
            withdrawn.add(r.id);
            if (reviewId != null) r.notes['experienceWithdrawn'] = 'yes';
          }
        }
        final profiles = await tx.query('profile', where: 'id = 1');
        final profile = profiles.isEmpty
            ? SelfOsProfile()
            : SelfOsProfile.fromJson(
                osMap(jsonDecode(profiles.single['document']! as String)));
        SelfOsPrinciples.invalidate(profile, cases, withdrawn);
        for (final c in cases) {
          await _writeCase(tx, c);
        }
        profile.storageRevision++;
        await tx.insert(
            'profile', {'id': 1, 'document': jsonEncode(profile.toJson())},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }).then((_) => _reconcileReminders());
  Future<SelfOsProfile> loadProfile() async {
    final rows = await (await database).query('profile', where: 'id = 1');
    return rows.isEmpty
        ? SelfOsProfile()
        : SelfOsProfile.fromJson(
            osMap(jsonDecode(rows.single['document']! as String)));
  }

  Future<void> _checkPrincipleVersions(
      DatabaseExecutor tx, SelfOsProfile value) async {
    final rows = await tx.query('profile', where: 'id = 1');
    if (rows.isEmpty) {
      if (value.storageRevision != 0) throw const SelfOsStaleWrite();
      return;
    }
    final stored = SelfOsProfile.fromJson(
        osMap(jsonDecode(rows.single['document']! as String)));
    if (value.storageRevision != stored.storageRevision)
      throw const SelfOsStaleWrite();
    if (stored.principles
        .any((p) => !value.principles.any((next) => next['id'] == p['id'])))
      throw const FormatException('个人原则列表已有更新，请重新读取后保存');
    for (final next in value.principles) {
      final prior =
          stored.principles.where((p) => p['id'] == next['id']).firstOrNull;
      if (prior == null) continue;
      final oldVersion = SelfOsPrinciples.normalize(prior)['version'] as int;
      final newVersion = SelfOsPrinciples.normalize(next)['version'] as int;
      if (newVersion < oldVersion ||
          (prior['stale'] == true && next['stale'] != true))
        throw const FormatException('个人原则或权限已有更新，请重新读取后保存');
      if (newVersion == oldVersion && prior['status'] != next['status']) {
        final oldTime = DateTime.tryParse(osText(prior['statusAt']));
        final newTime = DateTime.tryParse(osText(next['statusAt']));
        if (oldTime != null && (newTime == null || !newTime.isAfter(oldTime)))
          throw const FormatException('个人原则的认可状态已有更新，请重新读取后保存');
      }
      if (oldVersion == newVersion &&
          [
            'rule',
            'condition',
            'notApplicable',
            'exception',
            'riskGate',
            'nextTest'
          ].any((key) => osText(prior[key]) != osText(next[key])))
        throw const FormatException('原则内容修订必须保留旧版本');
    }
  }

  Future<Set<String>> _reconcileApplications(
      DatabaseExecutor tx, SelfOsProfile profile,
      {SelfOsCase? current}) async {
    final rows = await tx.query('cases');
    final cancellations = <String>{};
    for (final row in rows.where((r) => r['id'] != current?.id)) {
      final c =
          SelfOsCase.fromJson(osMap(jsonDecode(row['document']! as String)));
      cancellations.addAll(SelfOsPrinciples.reconcile(profile, c));
      if (jsonEncode(c.toJson()) != row['document']) await _writeCase(tx, c);
    }
    if (current != null)
      cancellations.addAll(SelfOsPrinciples.reconcile(profile, current));
    return cancellations;
  }

  Future<void> saveProfile(SelfOsProfile value) async {
    final cancellations = <String>{};
    await (await database).transaction((tx) async {
      await _checkPrincipleVersions(tx, value);
      cancellations.addAll(await _reconcileApplications(tx, value));
      await tx.insert(
          'profile',
          {
            'id': 1,
            'document': jsonEncode({
              ...value.toJson(),
              'storageRevision': value.storageRevision + 1
            })
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    value.storageRevision++;
    for (final id in cancellations) await SelfOsExperienceReminders.cancel(id);
  }

  Future<void> saveRouteDecision(
      List<SelfOsCase> cases, SelfOsProfile profile) async {
    if (cases.where((c) => c.routeStatus == 'active').length > 1)
      throw const FormatException('同一时刻只保留一条主路线');
    final committed = <SelfOsCase, (int, DateTime)>{};
    await (await database).transaction((tx) async {
      await _checkPrincipleVersions(tx, profile);
      for (final c in cases) {
        committed[c] = await _writeCase(tx, c);
      }
      await tx.insert(
          'profile',
          {
            'id': 1,
            'document': jsonEncode({
              ...profile.toJson(),
              'storageRevision': profile.storageRevision + 1
            })
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    for (final e in committed.entries) {
      e.key.storageRevision = e.value.$1;
      e.key.updatedAt = e.value.$2;
    }
    profile.storageRevision++;
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}
