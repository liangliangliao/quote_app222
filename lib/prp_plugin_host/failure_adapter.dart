import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../prp_plugin/prp_plugin.dart';

class PrpFailureAdapter {
  const PrpFailureAdapter(this.openDatabase, this.ensureTables);
  final Future<Database> Function() openDatabase;
  final Future<void> Function() ensureTables;

  Future<void> lessonSealed(PrpLesson lesson, int sessionId) async {
    if (lesson.source != PrpSurface.failureModule) return;
    await ensureTables();
    final db = await openDatabase();
    await db.transaction((txn) async {
      // Idempotency and both writes share the same transaction.
      final existing = await txn.rawQuery(
          "SELECT id FROM fp_practice_run WHERE task_id = 'PRP_PLUGIN' AND json_extract(result_json, '\$.prp_session_id') = ? LIMIT 1",
          [sessionId]);
      if (existing.isNotEmpty) return;
      final ts = lesson.sealedMs ?? lesson.createdMs;
      await txn.insert('fp_practice_run', {
        'task_id': 'PRP_PLUGIN',
        'ts_ms': ts,
        'result_json': jsonEncode({
          'prp_session_id': sessionId,
          'prp_lesson_id': lesson.id,
          'worked': lesson.worked,
          'failed': lesson.failed,
          'early_signal': lesson.earlySignal,
          'if_cue': lesson.ifCue,
          'then_action': lesson.thenAction,
          'quality': lesson.quality
        })
      });
      await txn.insert('fp_learning_card', {
        'ts_ms': ts,
        'title': 'PRP · ${lesson.category}',
        'body':
            '有效：${lesson.worked.join('；')}\n无效：${lesson.failed.join('；')}\n预警：${lesson.earlySignal}\n${lesson.rule}',
        'tags_json': jsonEncode(['PRP', '失败成长', '已盖印'])
      });
    });
  }
}
