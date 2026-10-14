import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/model.dart';
import '../domain/rules.dart';

abstract interface class VaultCipher {
  Future<String> encrypt(String cleartext, String context);
  Future<String> decrypt(String ciphertext, String context);
}

/// Android AES-256-GCM; the non-exportable key never crosses the platform channel.
class AndroidVaultCipher implements VaultCipher {
  static const channel = MethodChannel('quote_app/will_mirror_v28_vault');
  @override
  Future<String> encrypt(String cleartext, String context) async {
    final result = await channel.invokeMethod<String>(
        'encrypt', {'data': cleartext, 'context': context});
    if (result == null) throw const MirrorProblem('加密服务不可用，未写入未加密记录');
    return result;
  }

  @override
  Future<String> decrypt(String ciphertext, String context) async {
    try {
      final result = await channel.invokeMethod<String>(
          'decrypt', {'data': ciphertext, 'context': context});
      if (result == null) throw const MirrorProblem('无法解密记录');
      return result;
    } on PlatformException {
      throw const MirrorProblem('无法打开加密资料。原文件已保留，请勿清除应用数据。');
    }
  }
}

abstract interface class MirrorStore {
  Future<List<CaseFile>> list();
  Future<CaseFile?> load(String id);
  Future<void> save(CaseFile file, {required int expectedRevision});
  Future<List<CaseFile>> history(String id);
  Future<Set<String>> retractEvidence(Set<String> ids);
  Future<Set<String>> revokeCrossCase(String sourceCaseId);
  Future<void> deleteCase(String id);
  Future<MirrorSettings> settings();
  Future<void> saveSettings(MirrorSettings settings);
  Future<String> exportJson();
  Future<void> close();
}

class SqliteMirrorStore implements MirrorStore {
  SqliteMirrorStore._(this.db, this.cipher);
  final Database db;
  final VaultCipher cipher;

  static Future<SqliteMirrorStore> open(
      {DatabaseFactory? factory, String? path, VaultCipher? cipher}) async {
    final selectedFactory = factory ?? databaseFactory;
    final db = await selectedFactory.openDatabase(
        path ??
            p.join(await selectedFactory.getDatabasesPath(),
                'will_mirror_rebuilt_v28.sqlite'),
        options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) async {
              await db.execute('PRAGMA foreign_keys = ON');
              await db.execute('PRAGMA secure_delete = ON');
            },
            onCreate: (db, version) async {
              await db.execute(
                  'CREATE TABLE cases (id TEXT PRIMARY KEY, revision INTEGER NOT NULL, payload TEXT NOT NULL)');
              await db.execute(
                  'CREATE TABLE case_history (case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE, revision INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(case_id,revision))');
              await db.execute(
                  'CREATE TABLE settings (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)');
            },
            onUpgrade: (db, oldVersion, newVersion) async {
              // Future migrations must decode and re-encrypt; never reinterpret old
              // booleans as actual behavior or fill unknown event times with now.
              if (oldVersion != newVersion)
                throw const MirrorProblem('请使用兼容资料版本的应用');
            }));
    return SqliteMirrorStore._(db, cipher ?? AndroidVaultCipher());
  }

  String _context(String id, int revision) =>
      'will-mirror/v28/case/$id/revision/$revision';
  Future<CaseFile> _decode(Map<String, Object?> row,
      {bool historical = false}) async {
    final id = row[historical ? 'case_id' : 'id'] as String;
    final revision = row['revision'] as int;
    final clear =
        await cipher.decrypt(row['payload'] as String, _context(id, revision));
    final file = CaseFile.fromJson(jsonMap(jsonDecode(clear)));
    if (file.id != id || file.revision != revision)
      throw const MirrorProblem('资料完整性检查未通过');
    return file;
  }

  @override
  Future<List<CaseFile>> list() async {
    final rows = await db.query('cases');
    final files = <CaseFile>[];
    for (final row in rows) {
      files.add(await _decode(row));
    }
    files.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return files;
  }

  @override
  Future<CaseFile?> load(String id) async {
    final rows = await db.query('cases', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _decode(rows.single);
  }

  @override
  Future<void> save(CaseFile file, {required int expectedRevision}) async {
    if (file.revision <= expectedRevision) throw const VersionConflict();
    final payload = await cipher.encrypt(
        canonicalJson(file.toJson()), _context(file.id, file.revision));
    await db.transaction((tx) async {
      final current = await tx.query('cases',
          columns: ['revision'], where: 'id = ?', whereArgs: [file.id]);
      if ((current.isEmpty ? 0 : current.single['revision']) !=
          expectedRevision) throw const VersionConflict();
      if (current.isEmpty) {
        await tx.insert('cases',
            {'id': file.id, 'revision': file.revision, 'payload': payload});
      } else {
        final changed = await tx.update(
            'cases', {'revision': file.revision, 'payload': payload},
            where: 'id = ? AND revision = ?',
            whereArgs: [file.id, expectedRevision]);
        if (changed != 1) throw const VersionConflict();
      }
      await tx.insert('case_history',
          {'case_id': file.id, 'revision': file.revision, 'payload': payload});
    });
  }

  @override
  Future<List<CaseFile>> history(String id) async {
    final rows = await db.query('case_history',
        where: 'case_id = ?', whereArgs: [id], orderBy: 'revision DESC');
    final result = <CaseFile>[];
    for (final row in rows) {
      result.add(await _decode(row, historical: true));
    }
    return result;
  }

  @override
  Future<Set<String>> retractEvidence(Set<String> ids) => _redact(ids);

  Future<Set<String>> _redact(Set<String> roots,
      {String? preserveSource}) async {
    // One SQLite transaction covers current and historical encrypted snapshots.
    // No raw content is written to WAL, metadata, logs, or a sidecar cache.
    final affected = <String>{};
    final changedCases = <String>{};
    await db.transaction((tx) async {
      final rows = await tx.query('case_history');
      final versions = <CaseFile>[];
      for (final row in rows) {
        versions.add(await _decode(row, historical: true));
      }
      affected.addAll(EvidenceRules.invalidationClosure(
          versions.expand((e) => e.nodes), roots));
      for (final file in versions) {
        if (file.id == preserveSource ||
            !file.nodes.any((n) => affected.contains(n.id))) continue;
        final redacted = CaseCommands()
            .retract(file, roots, affected: affected)
            .evolve(revision: file.revision, now: file.updatedAt);
        final payload = await cipher.encrypt(
            canonicalJson(redacted.toJson()), _context(file.id, file.revision));
        await tx.update('case_history', {'payload': payload},
            where: 'case_id = ? AND revision = ?',
            whereArgs: [file.id, file.revision]);
        changedCases.add(file.id);
      }
      for (final id in changedCases) {
        final row =
            (await tx.query('cases', where: 'id = ?', whereArgs: [id])).single;
        final file = await _decode(row);
        final revised = CaseCommands().retract(file, roots, affected: affected);
        final payload = await cipher.encrypt(
            canonicalJson(revised.toJson()), _context(id, revised.revision));
        await tx.update(
            'cases', {'revision': revised.revision, 'payload': payload},
            where: 'id = ?', whereArgs: [id]);
        await tx.insert('case_history',
            {'case_id': id, 'revision': revised.revision, 'payload': payload});
      }
    });
    await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    return changedCases;
  }

  @override
  Future<Set<String>> revokeCrossCase(String sourceCaseId) async {
    final versions = await history(sourceCaseId);
    return _redact(versions.expand((f) => f.nodes.map((n) => n.id)).toSet(),
        preserveSource: sourceCaseId);
  }

  @override
  Future<void> deleteCase(String id) async {
    await revokeCrossCase(id);
    await db.delete('cases', where: 'id = ?', whereArgs: [id]);
    final config = await settings();
    if (config.crossCaseIds.contains(id))
      await saveSettings(config.change({
        'crossCaseIds': config.crossCaseIds.where((e) => e != id).toList()
      }));
    await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  @override
  Future<MirrorSettings> settings() async {
    final rows = await db.query('settings');
    if (rows.isEmpty) return const MirrorSettings();
    return MirrorSettings.fromJson(jsonMap(jsonDecode(await cipher.decrypt(
        rows.single['payload'] as String, 'will-mirror/v28/settings'))));
  }

  @override
  Future<void> saveSettings(MirrorSettings settings) async {
    final encrypted = await cipher.encrypt(
        canonicalJson(settings.toJson()), 'will-mirror/v28/settings');
    await db.insert('settings', {'id': 1, 'payload': encrypted},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<String> exportJson() async =>
      const JsonEncoder.withIndent('  ').convert({
        'format': 'will-mirror-v28-rebuilt',
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'cases': (await list()).map((f) => f.toJson()).toList(),
        'note': '自述与观察、假设、设备事件分别标明；没有测量人格或未来行为概率。'
      });
  Future<Uint8List> encryptedBackup() async {
    final encrypted =
        await cipher.encrypt(await exportJson(), 'will-mirror/v28/backup');
    return Uint8List.fromList(utf8.encode(canonicalJson(
        {'format': 'device-bound-will-mirror-backup', 'payload': encrypted})));
  }

  @override
  Future<void> close() => db.close();
}
