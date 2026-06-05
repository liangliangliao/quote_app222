import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// Stores the latest successful AI movie analysis for each movie.
///
/// The table uses a stable [movie_key] instead of only `tmdb_id` so the app can
/// still cache analysis results for cards that do not carry a numeric TMDb id.
/// For normal TMDb movies the key is `tmdb:<id>`.
class MovieAnalysisDao {
  Future<Database> _db() async {
    final db = await AppDatabase.instance();
    await ensureTable(db);
    return db;
  }

  Future<void> ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_ai_analyses (
        movie_key TEXT PRIMARY KEY,
        tmdb_id INTEGER,
        title TEXT,
        original_title TEXT,
        release_date TEXT,
        poster_path TEXT,
        overview TEXT,
        analysis_text TEXT NOT NULL,
        movie_json TEXT,
        provider TEXT,
        model TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  String movieKeyFromMovie(Map<String, dynamic> movie) {
    final rawId = movie['id'] ?? movie['tmdb_id'];
    final parsedId = rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
    if (parsedId != null && parsedId > 0) return 'tmdb:$parsedId';
    final title = (movie['title'] ?? movie['name'] ?? '').toString().trim().toLowerCase();
    final date = (movie['release_date'] ?? movie['first_air_date'] ?? '').toString().trim();
    return 'title:${title.replaceAll(RegExp(r"\s+"), " ")}|$date';
  }

  Future<Map<String, dynamic>?> getByMovie(Map<String, dynamic> movie) async {
    final db = await _db();
    final rows = await db.query(
      'movie_ai_analyses',
      where: 'movie_key = ?',
      whereArgs: [movieKeyFromMovie(movie)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> upsertAnalysis({
    required Map<String, dynamic> movie,
    required String analysisText,
    String? provider,
    String? model,
  }) async {
    final text = analysisText.trim();
    if (text.isEmpty) return;
    final db = await _db();
    final rawId = movie['id'] ?? movie['tmdb_id'];
    final parsedId = rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
    final now = DateTime.now().toIso8601String();
    final existing = await getByMovie(movie);
    final data = <String, dynamic>{
      'movie_key': movieKeyFromMovie(movie),
      'tmdb_id': parsedId,
      'title': (movie['title'] ?? movie['name'] ?? '').toString(),
      'original_title': (movie['original_title'] ?? movie['original_name'] ?? '').toString(),
      'release_date': (movie['release_date'] ?? movie['first_air_date'] ?? '').toString(),
      'poster_path': movie['poster_path']?.toString(),
      'overview': (movie['overview'] ?? '').toString(),
      'analysis_text': text,
      'movie_json': jsonEncode(movie),
      'provider': provider,
      'model': model,
      'created_at': existing == null ? now : (existing['created_at']?.toString() ?? now),
      'updated_at': now,
    };
    await db.insert(
      'movie_ai_analyses',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
