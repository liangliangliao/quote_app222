import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../data/db.dart';
import '../data/kv_dao.dart';

/// Complete quotation snapshots keep the collection available after edits.
/// Store the complete quotation so bundled/offline quotations can be collected.
class QuoteLibraryStore {
  static const favoritePrefix = 'quote_library.favorite.';
  final KeyValueDao _kv = KeyValueDao();

  static String identity(Map<String, dynamic> quote) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            (quote['content'] ?? quote['quote'] ?? '').toString().trim(),
            (quote['theme'] ?? quote['topic'] ?? '').toString().trim(),
          ]),
        ),
      )
      .toString();

  static String _author(Map<String, dynamic> row) {
    var author = (row['author_name'] ?? row['author'] ?? '')
        .toString()
        .trim()
        .replaceFirst(RegExp(r'^[—–\-\s]+'), '');
    final source = (row['source_from'] ?? row['source'] ?? '')
        .toString()
        .trim();
    if (source.isNotEmpty && author.endsWith('《$source》'))
      author = author.substring(0, author.length - source.length - 2).trim();
    return author;
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> row) => {
    ...row,
    'content': row['content'] ?? row['quote'] ?? '',
    'theme': row['theme'] ?? row['topic'] ?? '',
    'author_name': _author(row),
    'source_from': row['source_from'] ?? row['source'] ?? '',
    'explanation': row['explanation'] ?? row['note'] ?? '',
    'avatar': row['avatar'] ?? row['avatarUrl'] ?? '',
  };

  Future<bool> isFavorite(Map<String, dynamic> row) async =>
      ((await _kv.getString('$favoritePrefix${identity(row)}')) ?? '')
          .isNotEmpty;

  Future<void> setFavorite(Map<String, dynamic> row, bool selected) async {
    if ((row['content'] ?? row['quote'] ?? '').toString().trim().isEmpty)
      return;
    await _kv.setString(
      '$favoritePrefix${identity(row)}',
      selected
          ? jsonEncode({
              ...normalize(row),
              'favorited_at': DateTime.now().toIso8601String(),
            })
          : '',
    );
  }

  Future<List<Map<String, dynamic>>> favorites() async {
    final values = await _kv.keyValuesWithPrefix(favoritePrefix);
    final result = <Map<String, dynamic>>[];
    for (final entry in values) {
      try {
        final row = jsonDecode(entry['value'] ?? '');
        if (row is Map<String, dynamic>) result.add(normalize(row));
      } catch (_) {
        /* Ignore empty/corrupt collection entries. */
      }
    }
    result.sort(
      (a, b) => (b['favorited_at'] ?? '').toString().compareTo(
        (a['favorited_at'] ?? '').toString(),
      ),
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> bundledQuotes() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/fallback/camus_fallback.json'),
    );
    final entries = data is List ? data : [data];
    return entries.whereType<Map<String, dynamic>>().map(normalize).toList();
  }

  Future<List<Map<String, dynamic>>> page({
    String query = '',
    String theme = '',
    int offset = 0,
    int limit = 60,
  }) async {
    final db = await AppDatabase.instance();
    final conditions = <String>[];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      conditions.add(
        '(instr(lower(content),lower(?)) > 0 OR instr(lower(author_name),lower(?)) > 0 OR instr(lower(theme),lower(?)) > 0)',
      );
      args.addAll([query.trim(), query.trim(), query.trim()]);
    }
    if (theme.isNotEmpty) {
      conditions.add('theme = ?');
      args.add(theme);
    }
    return db.query(
      'quotes',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'id DESC',
      offset: offset,
      limit: limit,
    );
  }

  Future<List<String>> themes() async {
    final db = await AppDatabase.instance();
    final rows = await db.rawQuery(
      "SELECT DISTINCT theme FROM quotes WHERE theme IS NOT NULL AND trim(theme) != '' ORDER BY theme",
    );
    return rows.map((row) => row['theme'].toString()).toList();
  }

  Future<Map<String, dynamic>?> randomOther(String currentQuote) async {
    final db = await AppDatabase.instance();
    final rows = await db.rawQuery(
      'SELECT * FROM quotes WHERE trim(content) != ? AND trim(content) != ? ORDER BY RANDOM() LIMIT 1',
      [currentQuote.trim(), ''],
    );
    return rows.isEmpty ? null : rows.first;
  }
}
