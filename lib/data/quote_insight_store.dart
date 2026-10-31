import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/quote_insight.dart';
import 'db.dart';

/// Optional sidecar data in the existing KV store. No quote schema migration,
/// original-text rewrite or cross-module data query is needed.
class QuoteInsightStore {
  final Future<Database> Function() _database;
  QuoteInsightStore({Future<Database> Function()? database})
      : _database = database ?? AppDatabase.instance;

  Future<Database> _ready() async {
    final db = await _database();
    await db.execute(
        'CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT)');
    return db;
  }

  Future<String?> _read(String key) async {
    final db = await _ready();
    final rows = await db.query('app_kv',
        columns: ['value'], where: 'key=?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _write(String key, Object value) async {
    final db = await _ready();
    await db.insert('app_kv', {'key': key, 'value': jsonEncode(value)},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<QuoteAnalysisAddon> readAddon(QuoteReference quote) async =>
      QuoteAnalysisAddon.fromStoredJson(
          await _read('quote_insight.addon.${quote.contentKey}'));

  Future<void> saveAddon(QuoteReference quote, QuoteAnalysisAddon addon) =>
      _write('quote_insight.addon.${quote.contentKey}', addon.toJson());

  Future<Map<String, QuoteAnalysisAddon>> readAddons(List<QuoteReference> quotes) async {
    final db = await _ready();
    final result = <String, QuoteAnalysisAddon>{};
    final keys = quotes.map((q) => 'quote_insight.addon.${q.contentKey}').toSet().toList();
    for (var offset = 0; offset < keys.length; offset += 200) {
      final batch = keys.skip(offset).take(200).toList();
      final rows = await db.query('app_kv', where: 'key IN (${List.filled(batch.length, '?').join(',')})', whereArgs: batch);
      for (final row in rows) {
        final key = row['key'] as String;
        result[key.substring('quote_insight.addon.'.length)] = QuoteAnalysisAddon.fromStoredJson(row['value']);
      }
    }
    return result;
  }

  Future<String?> readComparison(String cacheKey) =>
      _read('quote_insight.comparison.$cacheKey');

  Future<void> saveComparison(String cacheKey, QuoteComparison value) async {
    await _write('quote_insight.comparison.$cacheKey', value.toJson());
    final db = await _ready();
    // Keep cache bounded. Addons and unrelated KV entries are never pruned.
    await db.rawDelete(
        "DELETE FROM app_kv WHERE key IN (SELECT key FROM app_kv WHERE key GLOB 'quote_insight.comparison.*' ORDER BY rowid DESC LIMIT -1 OFFSET 100)");
  }

  Future<void> deleteComparison(String cacheKey) async {
    final db = await _ready();
    await db.delete('app_kv',
        where: 'key=?', whereArgs: ['quote_insight.comparison.$cacheKey']);
  }
}
