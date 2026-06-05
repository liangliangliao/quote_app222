import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// Data access object for the movie_favorites table.
///
/// This DAO provides methods to insert, remove, query and check
/// favourite movies stored locally. Each favourite row stores both
/// selected fields (id, title, overview, poster, backdrop, rating, vote
/// count, release date) and the raw JSON blob returned by the TMDb
/// API. The `tmdb_id` column is marked UNIQUE to prevent duplicate
/// entries for the same movie.
class MovieFavoriteDao {
  /// Returns a list of all favourited movies. If [query] is non‑null and
  /// non‑empty it performs a LIKE search on the `title` column. Results
  /// are ordered by `created_at` descending (most recent first).
  Future<List<Map<String, dynamic>>> listFavorites({String? query}) async {
    final db = await AppDatabase.instance();
    if (query != null && query.trim().isNotEmpty) {
      final keyword = '%${query.trim()}%';
      return db.query(
        'movie_favorites',
        where: 'title LIKE ?',
        whereArgs: [keyword],
        orderBy: 'created_at DESC',
      );
    }
    return db.query('movie_favorites', orderBy: 'created_at DESC');
  }

  /// Inserts a movie into favourites. If a movie with the same tmdb_id
  /// already exists this call does nothing and returns the existing row id.
  Future<int> insert(Map<String, dynamic> movie) async {
    final db = await AppDatabase.instance();
    // Ensure created_at timestamp
    final data = Map<String, dynamic>.from(movie);
    data['created_at'] = DateTime.now().toIso8601String();
    return db.insert(
      'movie_favorites',
      data,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Removes a movie from favourites by its TMDb id. Returns the number
  /// of rows deleted (0 or 1).
  Future<int> deleteByTmdbId(int tmdbId) async {
    final db = await AppDatabase.instance();
    return db.delete('movie_favorites', where: 'tmdb_id = ?', whereArgs: [tmdbId]);
  }

  /// Determines whether a movie is favourited based on its TMDb id.
  Future<bool> isFavorited(int tmdbId) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('movie_favorites', where: 'tmdb_id = ?', whereArgs: [tmdbId], limit: 1);
    return rows.isNotEmpty;
  }

  /// Returns a set of all favourited TMDb ids. Useful for bulk
  /// favourited state detection. The returned set contains `int` ids.
  Future<Set<int>> allFavoriteIds() async {
    final db = await AppDatabase.instance();
    final rows = await db.rawQuery('SELECT tmdb_id FROM movie_favorites');
    return rows.map((e) => (e['tmdb_id'] as int)).toSet();
  }
}