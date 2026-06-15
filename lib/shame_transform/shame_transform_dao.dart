import 'package:sqflite/sqflite.dart';
import '../data/db.dart';
import 'shame_transform_models.dart';

class ShameTransformDao {
  Future<void> _ensure() async {
    final db = await AppDatabase.instance();
    await db.execute('''CREATE TABLE IF NOT EXISTS shame_events (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, intensity INTEGER NOT NULL, event_fact TEXT NOT NULL, toxic_language TEXT NOT NULL, emotion TEXT NOT NULL, body_reaction TEXT NOT NULL, responsibility TEXT NOT NULL, not_responsibility TEXT NOT NULL, healthy_rewrite TEXT NOT NULL, minimum_action TEXT NOT NULL, evidence_sentence TEXT NOT NULL, linked_goal_id TEXT NOT NULL DEFAULT '')''');
  }
  Future<List<ShameEvent>> listEvents() async { await _ensure(); final db = await AppDatabase.instance(); return (await db.query('shame_events', orderBy: 'created_at DESC')).map(ShameEvent.fromMap).toList(); }
  Future<void> save(ShameEvent event) async { await _ensure(); final db = await AppDatabase.instance(); await db.insert('shame_events', event.toMap(), conflictAlgorithm: ConflictAlgorithm.replace); }
  Future<void> delete(String id) async { await _ensure(); final db = await AppDatabase.instance(); await db.delete('shame_events', where: 'id = ?', whereArgs: [id]); }
}
