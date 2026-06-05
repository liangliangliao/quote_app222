import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// Simple key-value storage based on notify_config.
///
/// Used for lightweight secrets/configs like Fitbit client id/secret.
class KeyValueDao {
  Future<String?> getString(String key) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('notify_config', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    final v = rows.first['value'];
    return v?.toString();
  }

  Future<void> setString(String key, String value) async {
    final db = await AppDatabase.instance();
    await db.insert(
      'notify_config',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
