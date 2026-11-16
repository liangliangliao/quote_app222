import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// Only quotation text and attribution are used for duplicate checking.
/// Explanations, personal notes and task descriptions are never included.
class QuoteHistoryEntry {
  final String content;
  final String originalContent;
  final String author;
  final String source;

  const QuoteHistoryEntry({
    required this.content,
    this.originalContent = '',
    this.author = '',
    this.source = '',
  });

  Map<String, String> toJson() => {
        'quote': content,
        if (originalContent.isNotEmpty) 'original_quote': originalContent,
        'author': author,
        'source': source,
      };

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  bool sameTextAs(QuoteHistoryEntry other) {
    final texts = [content, originalContent]
        .map(normalize)
        .where((text) => text.isNotEmpty)
        .toSet();
    return [other.content, other.originalContent]
        .map(normalize)
        .any((text) => texts.contains(text));
  }

  static String revision(Iterable<QuoteHistoryEntry> entries) => sha256
      .convert(utf8
          .encode(jsonEncode(entries.map((entry) => entry.toJson()).toList())))
      .toString();
}

/// Tracks accepted AI results even when saving to the visible library is off.
/// Existing library records participate immediately, without a backfill job.
class QuoteGenerationHistory {
  final Future<Database> Function() _database;

  QuoteGenerationHistory({Future<Database> Function()? database})
      : _database = database ?? AppDatabase.instance;

  Future<Database> _open() async {
    final db = await _database();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quote_generation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_uid TEXT NOT NULL,
        content TEXT NOT NULL,
        original_content TEXT NOT NULL DEFAULT '',
        author TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    return db;
  }

  Future<List<QuoteHistoryEntry>> load() async => _read(await _open());

  Future<List<QuoteHistoryEntry>> _read(DatabaseExecutor db) async {
    final generated = await db.query('quote_generation_history',
        columns: ['content', 'original_content', 'author', 'source'],
        orderBy: 'id DESC');
    final library = await db.query('quotes',
        columns: ['content', 'author_name', 'source_from'], orderBy: 'id DESC');
    final entries = <QuoteHistoryEntry>[];
    final seen = <String>{};
    for (final row in [...generated, ...library]) {
      final entry = QuoteHistoryEntry(
        content: (row['content'] ?? '').toString().trim(),
        originalContent: (row['original_content'] ?? '').toString().trim(),
        author: (row['author'] ?? row['author_name'] ?? '').toString().trim(),
        source: (row['source'] ?? row['source_from'] ?? '').toString().trim(),
      );
      if (entry.content.isEmpty) continue;
      final key = QuoteHistoryEntry.normalize(entry.content);
      if (seen.add(key)) entries.add(entry);
    }
    return entries;
  }

  /// A competing foreground/background run must validate the updated history
  /// before accepting its result. No network request runs inside this transaction.
  Future<bool> rememberIfUnchanged(
    QuoteHistoryEntry entry, {
    required String taskUid,
    required List<QuoteHistoryEntry> checkedHistory,
  }) async {
    final db = await _open();
    return db.transaction((txn) async {
      final current = await _read(txn);
      if (QuoteHistoryEntry.revision(current) !=
              QuoteHistoryEntry.revision(checkedHistory) ||
          current.any(entry.sameTextAs)) {
        return false;
      }
      await txn.insert('quote_generation_history', {
        'task_uid': taskUid,
        'content': entry.content,
        'original_content': entry.originalContent,
        'author': entry.author,
        'source': entry.source,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    });
  }
}
