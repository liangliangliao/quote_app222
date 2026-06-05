import 'package:sqflite/sqflite.dart';
import '../data/db.dart';
import '../utils/debug_logger.dart';

class RunGuard {
  static Future<void> _ensure(Database db) async {
    await db.execute(
      "CREATE TABLE IF NOT EXISTS run_guard("
      "uid TEXT NOT NULL,"
      "run_key TEXT NOT NULL,"
      "source TEXT,"
      "ts INTEGER,"
      "PRIMARY KEY(uid, run_key)"
      ")"
    );
  }

  /// 尝试开始一次运行：当 (uid, runKey) 尚不存在时写入一条记录；若已存在则返回 false（抑制重复）
  static Future<bool> begin(String uid, String runKey, {String? source}) async {
    final db = await AppDatabase.instance();
    await _ensure(db);
    try {
      await db.insert('run_guard', {
        'uid': uid,
        'run_key': runKey,
        'source': source ?? '',
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      await DLog.w('RunGuard', 'dup run suppressed uid=$uid runKey=$runKey src=${source ?? ""}');
      return false;
    }
  }

  /// 结束一次运行：删除对应 (uid, runKey) 记录
  static Future<void> end(String uid, String runKey, {String? source}) async {
    final db = await AppDatabase.instance();
    await _ensure(db);
    try {
      await db.delete('run_guard', where: 'uid=? AND run_key=?', whereArgs: [uid, runKey]);
      await DLog.i('RunGuard', 'end uid=$uid runKey=$runKey src=${source ?? ""}');
    } catch (e) {
      await DLog.w('RunGuard', 'end error uid=$uid runKey=$runKey err=$e');
    }
  }
}