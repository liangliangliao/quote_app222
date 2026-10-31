import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../data/db.dart';
import '../models/quote_insight.dart';
import 'cognitive_models.dart';

class CognitiveStore {
  final Future<Database> Function() _database;
  CognitiveStore({Future<Database> Function()? database})
      : _database = database ?? AppDatabase.instance;
  Future<Database> get database async {
    final db = await _database();
    await db.execute(
        'CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT)');
    return db;
  }

  String _prefix(String module, String id) =>
      'cognition.note.${insightHash([module, id])}.';
  String _key(CognitiveNote note) =>
      '${_prefix(note.selection.module, note.selection.recordId)}${note.id}';
  Future<void> save(CognitiveNote note) async {
    final db = await database;
    await db.insert(
        'app_kv', {'key': _key(note), 'value': jsonEncode(note.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CognitiveNote>> _read(String glob) async {
    final db = await database;
    final rows = await db.query('app_kv',
        columns: ['value'],
        where: 'key GLOB ?',
        whereArgs: [glob],
        orderBy: 'rowid DESC');
    final notes = <CognitiveNote>[];
    for (final row in rows) {
      try {
        notes.add(CognitiveNote.fromJson(row['value']));
      } catch (_) {}
    }
    return notes;
  }

  Future<List<CognitiveNote>> forRecord(String module, String id) =>
      _read('${_prefix(module, id)}*');
  Future<List<CognitiveNote>> forRecords(
      String module, List<String> ids) async {
    final db = await database;
    final unique = ids.toSet().toList();
    final result = <CognitiveNote>[];
    for (var start = 0; start < unique.length; start += 150) {
      final batch = unique.skip(start).take(150).toList();
      final rows = await db.query('app_kv',
          columns: ['value'],
          where: List.filled(batch.length, 'key GLOB ?').join(' OR '),
          whereArgs: batch.map((id) => '${_prefix(module, id)}*').toList(),
          orderBy: 'rowid DESC');
      for (final row in rows) {
        try {
          result.add(CognitiveNote.fromJson(row['value']));
        } catch (_) {}
      }
    }
    return result;
  }

  // Called only by the user-opened recap picker. No business module gets an
  // implicit feed of other modules' originals, diaries or private attachments.
  Future<List<CognitiveNote>> acceptedForRecap() async =>
      (await _read('cognition.note.*')).where((e) => e.accepted).toList();
  Future<void> delete(CognitiveNote note) async {
    final db = await database;
    await db.delete('app_kv', where: 'key=?', whereArgs: [_key(note)]);
  }

  Future<void> deleteRecord(String module, String id) async {
    final db = await database;
    await db.delete('app_kv',
        where: 'key GLOB ?', whereArgs: ['${_prefix(module, id)}*']);
  }

  Future<void> bindDraft(String module, String draftId, String recordId) async {
    final notes = await forRecord(module, draftId);
    final db = await database;
    await db.transaction((txn) async {
      for (final note in notes) {
        final bound =
            note.copyWith(selection: note.selection.withRecordId(recordId));
        await txn.insert(
            'app_kv', {'key': _key(bound), 'value': jsonEncode(bound.toJson())},
            conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.delete('app_kv', where: 'key=?', whereArgs: [_key(note)]);
      }
    });
  }
}
