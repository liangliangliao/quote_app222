import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_journey_models.dart';

/// Successful responses survive page reconstruction and process restarts.
/// Context/model/schema changes invalidate by content; viewing is not a change.
class GrowthAiCache {
  GrowthAiCache(this.dao);
  final EvidenceGrowthDao dao;
  static final _pending = <String, Future<GrowthData>>{};
  static Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => '$k').toList()..sort();
      return {for (final k in keys) k: canonical(value[k])};
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  static String fingerprint(Object? value) =>
      sha256.convert(utf8.encode(jsonEncode(canonical(value)))).toString();

  Future<GrowthData> run(
    String purpose,
    Object? context,
    Future<GrowthData> Function() generate, {
    bool refresh = false,
    bool Function(GrowthData)? accept,
  }) async {
    await dao.ensureTables();
    final key = fingerprint(['growth-ai-v4', purpose, context]);
    final db = await dao.knowledgeDatabase();
    if (!refresh) {
      final rows = await db.query(
        'evidence_growth_ai_cache',
        where: 'cache_key=?',
        whereArgs: [key],
      );
      if (rows.isNotEmpty) {
        try {
          return {
            ...growthMap(jsonDecode(rows.single['body_json'] as String)),
            'cache_hit': true,
          };
        } catch (_) {
          /* Replace an unreadable cache, never user data. */
        }
      }
    }
    if (_pending.containsKey(key)) return _pending[key]!;
    final future = (() async {
      final result = await generate();
      if (accept?.call(result) ?? result['origin'] == 'AI') {
        await db.insert(
            'evidence_growth_ai_cache',
            {
              'cache_key': key,
              'purpose': purpose,
              'body_json': jsonEncode(result),
              'created_at_ms': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return result;
    })();
    _pending[key] = future;
    try {
      return await future;
    } finally {
      _pending.remove(key);
    }
  }
}
