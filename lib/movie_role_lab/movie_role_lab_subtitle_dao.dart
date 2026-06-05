import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'movie_role_lab_models.dart';

class MovieRoleLabSubtitleDao {
  static const MethodChannel _nativeScheduler = MethodChannel('native.scheduler');
  Future<Database> _db() async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_role_lab_subtitles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        movie_id INTEGER NOT NULL UNIQUE,
        movie_title TEXT,
        imdb_id TEXT,
        source TEXT,
        language TEXT,
        subtitle_name TEXT,
        imported_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_role_lab_subtitle_cues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subtitle_id INTEGER NOT NULL,
        cue_index INTEGER NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        text TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_role_lab_search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL,
        movie_id INTEGER NOT NULL,
        title TEXT,
        overview TEXT,
        poster_path TEXT,
        backdrop_path TEXT,
        release_date TEXT,
        vote_average REAL,
        movie_json TEXT,
        searched_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mrl_search_history_time ON movie_role_lab_search_history(searched_at_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mrl_search_history_movie ON movie_role_lab_search_history(movie_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mrl_subtitle_movie ON movie_role_lab_subtitles(movie_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mrl_subtitle_cues_sid_idx ON movie_role_lab_subtitle_cues(subtitle_id, cue_index)');
    await _ensureColumn(db, 'movie_role_lab_subtitle_cues', 'speaker_name', 'TEXT');
    await _ensureColumn(db, 'movie_role_lab_subtitle_cues', 'speaker_confidence', 'TEXT');
    await _ensureColumn(db, 'movie_role_lab_subtitle_cues', 'speaker_source', 'TEXT');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_role_lab_episodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        movie_id INTEGER NOT NULL,
        episode_index INTEGER NOT NULL,
        title TEXT,
        summary TEXT,
        previous_context TEXT,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        raw_json TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_role_lab_episode_roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        episode_id INTEGER NOT NULL,
        character_name TEXT,
        character_name_zh TEXT,
        character_name_en TEXT,
        actor_name TEXT,
        profile_path TEXT,
        role_type TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_role_lab_episode_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        episode_id INTEGER NOT NULL,
        line_index INTEGER NOT NULL,
        cue_index INTEGER,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        character_name TEXT,
        character_name_zh TEXT,
        character_name_en TEXT,
        text TEXT NOT NULL,
        confidence TEXT,
        source TEXT,
        raw_json TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mrl_episodes_movie ON movie_role_lab_episodes(movie_id, episode_index)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mrl_episode_roles_eid ON movie_role_lab_episode_roles(episode_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mrl_episode_lines_eid_idx ON movie_role_lab_episode_lines(episode_id, line_index)');
  }


  Future<void> _ensureColumn(Database db, String table, String column, String type) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final exists = rows.any((row) => (row['name'] ?? '').toString() == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> saveSearchResults({
    required String query,
    required List<MovieRoleLabMovie> movies,
    required List<Map<String, dynamic>> rawResults,
  }) async {
    if (query.trim().isEmpty || movies.isEmpty) return;
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < movies.length; i++) {
        final movie = movies[i];
        final raw = i < rawResults.length ? rawResults[i] : movie.toJson();
        batch.insert('movie_role_lab_search_history', {
          'query': query.trim(),
          'movie_id': movie.id,
          'title': movie.title,
          'overview': movie.overview,
          'poster_path': movie.posterPath,
          'backdrop_path': movie.backdropPath,
          'release_date': movie.releaseDate,
          'vote_average': movie.voteAverage,
          'movie_json': const JsonEncoder.withIndent('  ').convert(raw),
          'searched_at_ms': now,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<MovieRoleLabSearchHistoryItem>> loadSearchHistory({int limit = 80}) async {
    final db = await _db();
    final rows = await db.query(
      'movie_role_lab_search_history',
      orderBy: 'searched_at_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map((row) {
      final movie = MovieRoleLabMovie(
        id: (row['movie_id'] as num?)?.toInt() ?? 0,
        title: (row['title'] ?? '').toString(),
        overview: (row['overview'] ?? '').toString(),
        posterPath: row['poster_path']?.toString(),
        backdropPath: row['backdrop_path']?.toString(),
        releaseDate: (row['release_date'] ?? '').toString(),
        voteAverage: (row['vote_average'] as num?)?.toDouble() ?? 0,
      );
      return MovieRoleLabSearchHistoryItem(
        id: (row['id'] as num?)?.toInt() ?? 0,
        query: (row['query'] ?? '').toString(),
        movie: movie,
        rawJson: (row['movie_json'] ?? '').toString(),
        searchedAtMs: (row['searched_at_ms'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<MovieRoleLabStoredSubtitle?> findByMovieId(int movieId) async {
    final db = await _db();
    final subtitles = await db.query(
      'movie_role_lab_subtitles',
      where: 'movie_id = ?',
      whereArgs: [movieId],
      limit: 1,
    );
    if (subtitles.isEmpty) return null;
    return _hydrate(db, subtitles.first);
  }

  Future<MovieRoleLabStoredSubtitle> saveForMovie({
    required MovieRoleLabMovie movie,
    required String imdbId,
    required String source,
    required String language,
    required String subtitleName,
    required List<MovieRoleLabSubtitleCue> cues,
  }) async {
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    late int subtitleId;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'movie_role_lab_subtitles',
        columns: ['id'],
        where: 'movie_id = ?',
        whereArgs: [movie.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final oldId = (existing.first['id'] as num).toInt();
        await txn.delete('movie_role_lab_subtitle_cues', where: 'subtitle_id = ?', whereArgs: [oldId]);
        await txn.delete('movie_role_lab_subtitles', where: 'id = ?', whereArgs: [oldId]);
      }
      subtitleId = await txn.insert('movie_role_lab_subtitles', {
        'movie_id': movie.id,
        'movie_title': movie.title,
        'imdb_id': imdbId,
        'source': source,
        'language': language,
        'subtitle_name': subtitleName,
        'imported_at_ms': now,
      });
      final batch = txn.batch();
      for (var i = 0; i < cues.length; i++) {
        final cue = cues[i];
        batch.insert('movie_role_lab_subtitle_cues', {
          'subtitle_id': subtitleId,
          'cue_index': cue.cueIndex > 0 ? cue.cueIndex : i + 1,
          'start_ms': cue.startMs,
          'end_ms': cue.endMs,
          'text': cue.text,
        });
      }
      await batch.commit(noResult: true);
    });
    final stored = await findByMovieId(movie.id);
    if (stored == null) {
      throw Exception('字幕已保存但重新读取失败');
    }
    return stored;
  }

  Future<MovieRoleLabStoredSubtitle> _hydrate(Database db, Map<String, Object?> subtitleRow) async {
    final subtitleId = (subtitleRow['id'] as num).toInt();
    final cueRows = await db.query(
      'movie_role_lab_subtitle_cues',
      where: 'subtitle_id = ?',
      whereArgs: [subtitleId],
      orderBy: 'cue_index ASC, start_ms ASC',
    );
    final cues = cueRows.map((row) {
      return MovieRoleLabSubtitleCue(
        cueIndex: (row['cue_index'] as num?)?.toInt() ?? 0,
        startMs: (row['start_ms'] as num?)?.toInt() ?? 0,
        endMs: (row['end_ms'] as num?)?.toInt() ?? 0,
        text: (row['text'] ?? '').toString(),
      );
    }).toList();

    return MovieRoleLabStoredSubtitle(
      id: subtitleId,
      movieId: (subtitleRow['movie_id'] as num?)?.toInt() ?? 0,
      movieTitle: (subtitleRow['movie_title'] ?? '').toString(),
      imdbId: (subtitleRow['imdb_id'] ?? '').toString(),
      source: (subtitleRow['source'] ?? '').toString(),
      language: (subtitleRow['language'] ?? '').toString(),
      subtitleName: (subtitleRow['subtitle_name'] ?? '').toString(),
      importedAtMs: (subtitleRow['imported_at_ms'] as num?)?.toInt() ?? 0,
      cues: cues,
    );
  }



  Future<bool> hasEpisodes(int movieId) async {
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM movie_role_lab_episodes WHERE movie_id = ?',
      [movieId],
    );
    final count = (rows.first['c'] as num?)?.toInt() ?? 0;
    return count > 0;
  }

  Future<void> clearEpisodesByMovieId(int movieId) async {
    final db = await _db();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'movie_role_lab_episodes',
        columns: ['id'],
        where: 'movie_id = ?',
        whereArgs: [movieId],
      );
      final ids = rows.map((e) => (e['id'] as num).toInt()).toList();
      for (final id in ids) {
        await txn.delete('movie_role_lab_episode_lines', where: 'episode_id = ?', whereArgs: [id]);
        await txn.delete('movie_role_lab_episode_roles', where: 'episode_id = ?', whereArgs: [id]);
      }
      await txn.delete('movie_role_lab_episodes', where: 'movie_id = ?', whereArgs: [movieId]);
    });
  }

  Future<void> deleteEpisode(int episodeId) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete('movie_role_lab_episode_lines', where: 'episode_id = ?', whereArgs: [episodeId]);
      await txn.delete('movie_role_lab_episode_roles', where: 'episode_id = ?', whereArgs: [episodeId]);
      await txn.delete('movie_role_lab_episodes', where: 'id = ?', whereArgs: [episodeId]);
    });
  }

  Future<List<MovieRoleLabEpisode>> loadEpisodesByMovieId(int movieId) async {
    final db = await _db();
    final rows = await db.query(
      'movie_role_lab_episodes',
      where: 'movie_id = ?',
      whereArgs: [movieId],
      orderBy: 'episode_index ASC, start_ms ASC',
    );
    final episodes = <MovieRoleLabEpisode>[];
    for (final row in rows) {
      episodes.add(await _hydrateEpisode(db, row));
    }
    return episodes;
  }

  Future<MovieRoleLabEpisode?> loadEpisodeById(int episodeId) async {
    final db = await _db();
    final rows = await db.query(
      'movie_role_lab_episodes',
      where: 'id = ?',
      whereArgs: [episodeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _hydrateEpisode(db, rows.first);
  }

  Future<List<MovieRoleLabEpisode>> saveEpisodesForMovie({
    required int movieId,
    required List<MovieRoleLabEpisode> episodes,
  }) async {
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final oldRows = await txn.query('movie_role_lab_episodes', columns: ['id'], where: 'movie_id = ?', whereArgs: [movieId]);
      final oldIds = oldRows.map((e) => (e['id'] as num).toInt()).toList();
      for (final id in oldIds) {
        await txn.delete('movie_role_lab_episode_lines', where: 'episode_id = ?', whereArgs: [id]);
        await txn.delete('movie_role_lab_episode_roles', where: 'episode_id = ?', whereArgs: [id]);
      }
      await txn.delete('movie_role_lab_episodes', where: 'movie_id = ?', whereArgs: [movieId]);

      for (var i = 0; i < episodes.length; i++) {
        final ep = episodes[i];
        final episodeId = await txn.insert('movie_role_lab_episodes', {
          'movie_id': movieId,
          'episode_index': ep.episodeIndex <= 0 ? i + 1 : ep.episodeIndex,
          'title': ep.title,
          'summary': ep.summary,
          'previous_context': ep.previousContext,
          'start_ms': ep.startMs,
          'end_ms': ep.endMs,
          'raw_json': const JsonEncoder.withIndent('  ').convert(ep.toJson()),
          'created_at_ms': now,
        });
        final roleBatch = txn.batch();
        for (final role in ep.roles) {
          roleBatch.insert('movie_role_lab_episode_roles', {
            'episode_id': episodeId,
            'character_name': role.name,
            'character_name_zh': role.nameZh,
            'character_name_en': role.nameEn,
            'actor_name': role.actorName,
            'profile_path': role.profilePath,
            'role_type': role.roleType,
          });
        }
        await roleBatch.commit(noResult: true);

        final lineBatch = txn.batch();
        for (var j = 0; j < ep.lines.length; j++) {
          final line = ep.lines[j];
          lineBatch.insert('movie_role_lab_episode_lines', {
            'episode_id': episodeId,
            'line_index': line.lineIndex <= 0 ? j + 1 : line.lineIndex,
            'cue_index': line.cueIndex,
            'start_ms': line.startMs,
            'end_ms': line.endMs,
            'character_name': line.characterName,
            'character_name_zh': line.characterNameZh,
            'character_name_en': line.characterNameEn,
            'text': line.text,
            'confidence': line.confidence,
            'source': line.source,
            'raw_json': const JsonEncoder.withIndent('  ').convert(line.toJson()),
          });
        }
        await lineBatch.commit(noResult: true);
      }
    });
    return loadEpisodesByMovieId(movieId);
  }

  Future<List<MovieRoleLabEpisode>> appendEpisodesForMovie({
    required int movieId,
    required List<MovieRoleLabEpisode> episodes,
  }) async {
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (var i = 0; i < episodes.length; i++) {
        final ep = episodes[i];
        final episodeId = await txn.insert('movie_role_lab_episodes', {
          'movie_id': movieId,
          'episode_index': ep.episodeIndex <= 0 ? i + 1 : ep.episodeIndex,
          'title': ep.title,
          'summary': ep.summary,
          'previous_context': ep.previousContext,
          'start_ms': ep.startMs,
          'end_ms': ep.endMs,
          'raw_json': const JsonEncoder.withIndent('  ').convert(ep.toJson()),
          'created_at_ms': now,
        });
        final roleBatch = txn.batch();
        for (final role in ep.roles) {
          roleBatch.insert('movie_role_lab_episode_roles', {
            'episode_id': episodeId,
            'character_name': role.name,
            'character_name_zh': role.nameZh,
            'character_name_en': role.nameEn,
            'actor_name': role.actorName,
            'profile_path': role.profilePath,
            'role_type': role.roleType,
          });
        }
        await roleBatch.commit(noResult: true);

        final lineBatch = txn.batch();
        for (var j = 0; j < ep.lines.length; j++) {
          final line = ep.lines[j];
          lineBatch.insert('movie_role_lab_episode_lines', {
            'episode_id': episodeId,
            'line_index': line.lineIndex <= 0 ? j + 1 : line.lineIndex,
            'cue_index': line.cueIndex,
            'start_ms': line.startMs,
            'end_ms': line.endMs,
            'character_name': line.characterName,
            'character_name_zh': line.characterNameZh,
            'character_name_en': line.characterNameEn,
            'text': line.text,
            'confidence': line.confidence,
            'source': line.source,
            'raw_json': const JsonEncoder.withIndent('  ').convert(line.toJson()),
          });
        }
        await lineBatch.commit(noResult: true);
      }
    });
    return loadEpisodesByMovieId(movieId);
  }

  Future<MovieRoleLabEpisode> _hydrateEpisode(Database db, Map<String, Object?> row) async {
    final episodeId = (row['id'] as num?)?.toInt() ?? 0;
    final roleRows = await db.query(
      'movie_role_lab_episode_roles',
      where: 'episode_id = ?',
      whereArgs: [episodeId],
      orderBy: 'id ASC',
    );
    final lineRows = await db.query(
      'movie_role_lab_episode_lines',
      where: 'episode_id = ?',
      whereArgs: [episodeId],
      orderBy: 'line_index ASC, start_ms ASC',
    );
    final roles = roleRows.map((r) => MovieRoleLabEpisodeRole(
          name: (r['character_name'] ?? '').toString(),
          nameZh: (r['character_name_zh'] ?? '').toString(),
          nameEn: (r['character_name_en'] ?? '').toString(),
          actorName: (r['actor_name'] ?? '').toString(),
          profilePath: r['profile_path']?.toString(),
          roleType: (r['role_type'] ?? '').toString(),
        )).toList();
    final lines = lineRows.map((r) => MovieRoleLabScriptLine(
          id: (r['id'] as num?)?.toInt() ?? 0,
          lineIndex: (r['line_index'] as num?)?.toInt() ?? 0,
          cueIndex: (r['cue_index'] as num?)?.toInt() ?? 0,
          startMs: (r['start_ms'] as num?)?.toInt() ?? 0,
          endMs: (r['end_ms'] as num?)?.toInt() ?? 0,
          characterName: (r['character_name'] ?? '').toString(),
          characterNameZh: (r['character_name_zh'] ?? '').toString(),
          characterNameEn: (r['character_name_en'] ?? '').toString(),
          text: (r['text'] ?? '').toString(),
          confidence: (r['confidence'] ?? 'medium').toString(),
          source: (r['source'] ?? 'ai_inferred_from_subtitle').toString(),
        )).toList();
    return MovieRoleLabEpisode(
      id: episodeId,
      movieId: (row['movie_id'] as num?)?.toInt() ?? 0,
      episodeIndex: (row['episode_index'] as num?)?.toInt() ?? 0,
      title: (row['title'] ?? '').toString(),
      summary: (row['summary'] ?? '').toString(),
      previousContext: (row['previous_context'] ?? '').toString(),
      startMs: (row['start_ms'] as num?)?.toInt() ?? 0,
      endMs: (row['end_ms'] as num?)?.toInt() ?? 0,
      createdAtMs: (row['created_at_ms'] as num?)?.toInt() ?? 0,
      roles: roles,
      lines: lines,
    );
  }

  Future<String> exportTxt(MovieRoleLabStoredSubtitle subtitle) async {
    final fileName = _safeFileName('${subtitle.movieTitle}_${subtitle.language}_${subtitle.movieId}.txt');
    final buffer = StringBuffer();
    buffer.writeln('电影：${subtitle.movieTitle}');
    buffer.writeln('字幕：${subtitle.subtitleName}');
    buffer.writeln('来源：${subtitle.source}');
    buffer.writeln('语言：${subtitle.language}');
    buffer.writeln('IMDb：${subtitle.imdbId}');
    buffer.writeln('导出时间：${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    buffer.writeln(subtitle.toDisplayText());
    final text = buffer.toString();
    try {
      final saved = await _nativeScheduler.invokeMethod<String>('saveTextToDownloads', {
        'name': fileName,
        'text': text,
        'mime': 'text/plain; charset=utf-8',
      });
      if (saved != null && saved.trim().isNotEmpty) return saved;
    } catch (_) {
      // 兜底：如果原生 MediaStore 写入失败，仍保存到 App 专属外部目录，避免导出完全失败。
    }

    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final exportDir = Directory(path.join(dir.path, 'movie_role_lab_exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File(path.join(exportDir.path, fileName));
    await file.writeAsString(text, flush: true);
    return file.path;
  }

  String _safeFileName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'movie_subtitle.txt' : cleaned;
  }
}
