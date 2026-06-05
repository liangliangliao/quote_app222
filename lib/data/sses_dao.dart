import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// DAO for storing and retrieving EMA/SSES self‑esteem answers.
/// Each record represents a single answer to one state self‑esteem question.
/// Fields:
/// - item_id: the question identifier (e.g. P1, S2, A1)
/// - dimension: performance/social/appearance
/// - score: user rating on a 1–7 Likert scale
/// - created_at: ISO date string when the answer was recorded
class SsesDao {
  /// Insert a new answer into the sses_answers table.
  Future<int> insert({required String itemId, required String dimension, required int score}) async {
    final db = await AppDatabase.instance();
    final now = DateTime.now();
    final createdAt = now.toIso8601String();
    return await db.insert('sses_answers', {
      'item_id': itemId,
      'dimension': dimension,
      'score': score,
      'created_at': createdAt,
    });
  }

  /// Return the most recent N answers, ordered from newest to oldest.
  /// If count is null or <=0, defaults to 6.
  Future<List<Map<String, dynamic>>> recentAnswers({int count = 6}) async {
    final limit = count <= 0 ? 6 : count;
    final db = await AppDatabase.instance();
    return await db.query(
      'sses_answers',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
  }
}