import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'semantic_consistency_models.dart';

class SemanticConsistencyDao {
  Future<Database> _db() async {
    final db = await AppDatabase.instance();
    await AppDatabase.ensureSemanticConsistencyTables(db);
    return db;
  }

  Future<int> insertResult(SemanticConsistencyResult result) async {
    final db = await _db();
    return db.insert('semantic_consistency_records', result.toDbMap());
  }

  Future<List<SemanticConsistencyResult>> latest({int limit = 20}) async {
    final db = await _db();
    final rows = await db.query(
      'semantic_consistency_records',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(SemanticConsistencyResult.fromDb).toList();
  }

  Future<void> clearHistory() async {
    final db = await _db();
    await db.delete('semantic_consistency_records');
  }

  Future<void> clearEmbeddingCache() async {
    final db = await _db();
    await db.delete('semantic_embedding_cache');
  }

  Future<List<double>?> findEmbedding({
    required String textHash,
    required String provider,
    required String model,
    required int dimensions,
  }) async {
    final db = await _db();
    final rows = await db.query(
      'semantic_embedding_cache',
      where: 'text_hash = ? AND provider = ? AND model = ? AND dimensions = ?',
      whereArgs: <Object?>[textHash, provider, model, dimensions],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode((rows.first['vector_json'] ?? '').toString());
      if (decoded is! List) return null;
      return decoded.map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertEmbedding({
    required String textHash,
    required String textContent,
    required String provider,
    required String model,
    required int dimensions,
    required List<double> vector,
  }) async {
    final db = await _db();
    await db.insert(
      'semantic_embedding_cache',
      <String, Object?>{
        'text_hash': textHash,
        'text_content': textContent,
        'provider': provider,
        'model': model,
        'dimensions': dimensions,
        'vector_json': jsonEncode(vector),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
