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
      // Android 8 ships SQLite without JSON1. Decode only PRP's rows in Dart,
      // inside the same transaction, rather than requiring json_extract.
      final prior = await txn.query('fp_practice_run',
          columns: ['result_json'],
          where: 'task_id = ?',
          whereArgs: ['PRP_PLUGIN']);
      for (final row in prior) {
        try {
          final result = jsonDecode('${row['result_json']}');
          if (result is Map && result['prp_session_id'] == sessionId) return;
        } on FormatException {
          // An unrelated damaged historical row must not prevent this result.
        }
      }
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
          if (lesson.insight.isNotEmpty) 'insight': lesson.insight,
          'quality': lesson.quality
        })
      });
      await txn.insert('fp_learning_card', {
        'ts_ms': ts,
        'title': 'PRP · ${lesson.category}',
        'body':
            '有效：${lesson.worked.join('；')}\n无效：${lesson.failed.join('；')}\n预警：${lesson.earlySignal}\n${lesson.rule}${lesson.insight.isEmpty ? '' : '\n这次看见：${lesson.insight}'}',
        'tags_json': jsonEncode(['PRP', '失败成长', '已盖印'])
      });
    });
  }
}
