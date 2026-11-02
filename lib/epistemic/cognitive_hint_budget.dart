import 'package:sqflite/sqflite.dart';
import 'cognitive_store.dart';

class CognitiveHintBudget {
  static const key = 'cognition.scope_hint.last_day';
  static const legacyKey = 'cognition.gentle.last_day';
  final CognitiveStore _store;
  final DateTime Function() _now;
  CognitiveHintBudget({CognitiveStore? store, DateTime Function()? now})
      : _store = store ?? CognitiveStore(),
        _now = now ?? DateTime.now;

  Future<bool> claim() async {
    final db = await _store.database;
    final day = _now().toIso8601String().substring(0, 10);
    return db.transaction((txn) async {
      final rows = await txn
          .query('app_kv', where: 'key IN (?,?)', whereArgs: [key, legacyKey]);
      if (rows.any((r) => r['value'] == day)) return false;
      await txn.insert('app_kv', {'key': key, 'value': day},
          conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }
}
