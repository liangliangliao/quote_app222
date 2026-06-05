import 'package:sqflite/sqflite.dart';
import '../data/db.dart';

class Notebook {
  final int id;
  final String name;
  final int createdAt;
  final int updatedAt;
  Notebook({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
}

class DiaryEntry {
  final int id;
  final int notebookId;
  final int entryTime;
  final int? weatherCode;
  final String? weatherName;
  final String? moodName;
  final String? moodIcon;
  final String content;
  final String preview;
  final int starred;

  DiaryEntry({
    required this.id,
    required this.notebookId,
    required this.entryTime,
    required this.weatherCode,
    required this.weatherName,
    required this.moodName,
    required this.moodIcon,
    required this.content,
    required this.preview,
    required this.starred,
  });
}

class Tag {
  final int id;
  final String name;
  Tag({required this.id, required this.name});
}

class PageResult<T> {
  final List<T> items;
  final String? nextCursor;
  const PageResult(this.items, this.nextCursor);
}

class DiaryDao {
  Future<Database> get _db async => await AppDatabase.instance();

  /// Ensure tables exist (idempotent).
  Future<void> ensureSchema() async {
    final db = await _db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notebooks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        notebook_id INTEGER NOT NULL,
        entry_time INTEGER NOT NULL,
        weather_code INTEGER,
        weather_name TEXT,
        mood_name TEXT,
        mood_icon TEXT,
        content TEXT NOT NULL,
        preview TEXT NOT NULL,
        starred INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(notebook_id) REFERENCES notebooks(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_notebook_time ON entries(notebook_id, entry_time DESC, id DESC);',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entry_tags(
        entry_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY(entry_id, tag_id),
        FOREIGN KEY(entry_id) REFERENCES entries(id) ON DELETE CASCADE,
        FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
      );
    ''');
  }

  Future<List<Notebook>> listNotebooks() async {
    final db = await _db;
    final rows = await db.query('notebooks', orderBy: 'updated_at DESC');
    return rows
        .map((m) => Notebook(
              id: m['id'] as int,
              name: m['name'] as String,
              createdAt: m['created_at'] as int,
              updatedAt: m['updated_at'] as int,
            ))
        .toList();
  }

  Future<int> createNotebook(String name) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.insert('notebooks', {
      'name': name.trim(),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> touchNotebook(int notebookId) async {
    final db = await _db;
    await db.update(
      'notebooks',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id=?',
      whereArgs: [notebookId],
    );
  }

  Future<PageResult<DiaryEntry>> listEntries({
    required int notebookId,
    int limit = 50,
    String? cursor,
    String? keyword,
    DateTime? day,
    int? tagId,
  }) async {
    final db = await _db;

    final where = StringBuffer('notebook_id=?');
    final args = <Object?>[notebookId];

    if (cursor != null) {
      final parts = cursor.split(':');
      if (parts.length == 2) {
        final t = int.tryParse(parts[0]);
        final id = int.tryParse(parts[1]);
        if (t != null && id != null) {
          where.write(' AND (entry_time < ? OR (entry_time=? AND id < ?))');
          args.addAll([t, t, id]);
        }
      }
    }

    if (day != null) {
      final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999).millisecondsSinceEpoch;
      where.write(' AND (entry_time BETWEEN ? AND ?)');
      args.addAll([start, end]);
    }

    if (tagId != null) {
      where.write(' AND id IN (SELECT entry_id FROM entry_tags WHERE tag_id = ?)');
      args.add(tagId);
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      final kw = '%${keyword.trim()}%';
      where.write(' AND (content LIKE ? OR preview LIKE ?)');
      args.addAll([kw, kw]);
    }

    final rows = await db.query(
      'entries',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'entry_time DESC, id DESC',
      limit: limit,
    );
    final items = rows.map(_mapEntry).toList();
    final next = items.length == limit ? '${items.last.entryTime}:${items.last.id}' : null;
    return PageResult(items, next);
  }

  DiaryEntry _mapEntry(Map<String, Object?> m) {
    return DiaryEntry(
      id: m['id'] as int,
      notebookId: m['notebook_id'] as int,
      entryTime: m['entry_time'] as int,
      weatherCode: m['weather_code'] as int?,
      weatherName: m['weather_name'] as String?,
      moodName: m['mood_name'] as String?,
      moodIcon: m['mood_icon'] as String?,
      content: m['content'] as String,
      preview: m['preview'] as String,
      starred: (m['starred'] as int?) ?? 0,
    );
  }

  Future<DiaryEntry?> getEntry(int id) async {
    final db = await _db;
    final rows = await db.query('entries', where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _mapEntry(rows.first);
  }

  Future<int> upsertEntry(DiaryEntry e) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (e.id == 0) {
      return await db.insert('entries', {
        'notebook_id': e.notebookId,
        'entry_time': e.entryTime,
        'weather_code': e.weatherCode,
        'weather_name': e.weatherName,
        'mood_name': e.moodName,
        'mood_icon': e.moodIcon,
        'content': e.content,
        'preview': e.preview,
        'starred': e.starred,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'entries',
        {
          'entry_time': e.entryTime,
          'weather_code': e.weatherCode,
          'weather_name': e.weatherName,
          'mood_name': e.moodName,
          'mood_icon': e.moodIcon,
          'content': e.content,
          'preview': e.preview,
          'starred': e.starred,
          'updated_at': now,
        },
        where: 'id=?',
        whereArgs: [e.id],
      );
      return e.id;
    }
  }

  Future<DiaryEntry?> neighbor({
    required int notebookId,
    required DiaryEntry cur,
    required bool newer,
  }) async {
    final db = await _db;
    final t = cur.entryTime;
    final id = cur.id;

    if (newer) {
      final rows = await db.query(
        'entries',
        where: 'notebook_id=? AND (entry_time > ? OR (entry_time=? AND id > ?))',
        whereArgs: [notebookId, t, t, id],
        orderBy: 'entry_time ASC, id ASC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapEntry(rows.first);
    } else {
      final rows = await db.query(
        'entries',
        where: 'notebook_id=? AND (entry_time < ? OR (entry_time=? AND id < ?))',
        whereArgs: [notebookId, t, t, id],
        orderBy: 'entry_time DESC, id DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapEntry(rows.first);
    }
  }

  // Tags
  Future<List<Tag>> listTags() async {
    final db = await _db;
    final rows = await db.query('tags', orderBy: 'name ASC');
    return rows.map((m) => Tag(id: m['id'] as int, name: m['name'] as String)).toList();
  }

  Future<int> upsertTag(String name) async {
    final db = await _db;
    final n = name.trim();
    if (n.isEmpty) throw Exception('标签名不能为空');
    final rows = await db.query('tags', where: 'name=?', whereArgs: [n], limit: 1);
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return await db.insert('tags', {'name': n});
  }

  Future<List<Tag>> tagsForEntry(int entryId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT t.id, t.name FROM tags t
      INNER JOIN entry_tags et ON et.tag_id = t.id
      WHERE et.entry_id = ? ORDER BY t.name ASC
    ''', [entryId]);
    return rows.map((m) => Tag(id: m['id'] as int, name: m['name'] as String)).toList();
  }

  Future<void> setTagsForEntry(int entryId, List<int> tagIds) async {
    final db = await _db;
    final batch = db.batch();
    batch.delete('entry_tags', where: 'entry_id=?', whereArgs: [entryId]);
    for (final id in tagIds.toSet()) {
      batch.insert('entry_tags', {'entry_id': entryId, 'tag_id': id});
    }
    await batch.commit(noResult: true);
  }

  // Export / Import
  Future<Map<String, dynamic>> exportNotebook(int notebookId) async {
    final db = await _db;

    final notebooks = await db.query('notebooks', where: 'id=?', whereArgs: [notebookId], limit: 1);
    final entries = await db.query(
      'entries',
      where: 'notebook_id=?',
      whereArgs: [notebookId],
      orderBy: 'entry_time DESC, id DESC',
    );

    final entryIds = <int>[];
    for (final e in entries) {
      final id = e['id'];
      if (id is int) entryIds.add(id);
    }

    List<Map<String, Object?>> entryTags = [];
    List<Map<String, Object?>> tags = [];

    if (entryIds.isNotEmpty) {
      final ph = List.filled(entryIds.length, '?').join(',');
      entryTags = await db.rawQuery(
        'SELECT entry_id, tag_id FROM entry_tags WHERE entry_id IN ($ph)',
        entryIds,
      );

      final tagIdsSet = <int>{};
      for (final et in entryTags) {
        final tid = et['tag_id'];
        if (tid is int) tagIdsSet.add(tid);
      }
      final tagIds = tagIdsSet.toList();
      if (tagIds.isNotEmpty) {
        final ph2 = List.filled(tagIds.length, '?').join(',');
        tags = await db.rawQuery('SELECT id, name FROM tags WHERE id IN ($ph2)', tagIds);
      }
    }

    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'notebook': notebooks.isEmpty ? null : notebooks.first,
      'entries': entries,
      'tags': tags,
      'entry_tags': entryTags,
    };
  }

  Future<void> importToNotebook(int notebookId, Map<String, dynamic> data) async {
    final db = await _db;

    final entries = (data['entries'] as List?) ?? const [];
    final entryTags = (data['entry_tags'] as List?) ?? const [];
    final tags = (data['tags'] as List?) ?? const [];

    await db.transaction((txn) async {
      // upsert tags by name -> id
      final Map<dynamic, int> tagIdMap = {};
      for (final t in tags) {
        if (t is Map) {
          final name = (t['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          final row = await txn.query('tags', where: 'name=?', whereArgs: [name], limit: 1);
          int id;
          if (row.isNotEmpty) {
            id = row.first['id'] as int;
          } else {
            id = await txn.insert('tags', {'name': name});
          }
          tagIdMap[t['id']] = id;
        }
      }

      // insert entries mapped to target notebook
      final Map<dynamic, int> entryIdMap = {};
      for (final e in entries) {
        if (e is Map) {
          final newId = await txn.insert('entries', {
            'notebook_id': notebookId,
            'entry_time': e['entry_time'],
            'weather_code': e['weather_code'],
            'weather_name': e['weather_name'],
            'mood_name': e['mood_name'],
            'mood_icon': e['mood_icon'],
            'content': e['content'],
            'preview': e['preview'],
            'starred': e['starred'] ?? 0,
            'created_at': e['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
          entryIdMap[e['id']] = newId;
        }
      }

      // recreate entry_tags
      for (final et in entryTags) {
        if (et is Map) {
          final oldE = et['entry_id'];
          final oldT = et['tag_id'];
          if (!entryIdMap.containsKey(oldE)) continue;
          final newE = entryIdMap[oldE]!;
          final newT = tagIdMap[oldT];
          if (newT == null) continue;
          await txn.insert(
            'entry_tags',
            {'entry_id': newE, 'tag_id': newT},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }

  Future<int> countEntries(int notebookId) async {
    final db = await _db;
    final c = await db.rawQuery('SELECT COUNT(*) AS c FROM entries WHERE notebook_id=?', [notebookId]);
    if (c.isEmpty) return 0;
    final v = c.first['c'];
    return int.tryParse(v.toString()) ?? 0;
  }

  /// Position (0-based) of the entry in ordering (newest first).
  Future<int?> positionOfEntry(int notebookId, int entryId) async {
    final db = await _db;
    final cur = await db.rawQuery('SELECT entry_time, id FROM entries WHERE id=? LIMIT 1', [entryId]);
    if (cur.isEmpty) return 0;
    final t = int.tryParse(cur.first['entry_time'].toString()) ?? 0;
    final id = int.tryParse(cur.first['id'].toString()) ?? 0;
    final newer = await db.rawQuery('SELECT COUNT(*) AS c FROM entries WHERE notebook_id=? AND (entry_time > ? OR (entry_time=? AND id > ?))', [notebookId, t, t, id]);
    if (newer.isEmpty) return 0;
    final v = newer.first['c'];
    return int.tryParse(v.toString());
  }
}
