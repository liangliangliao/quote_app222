import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'todo_models.dart';

class TodoDao {
  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_todo_lists (
        list_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        wellknown_list_name TEXT,
        is_owner INTEGER DEFAULT 0,
        is_shared INTEGER DEFAULT 0,
        theme_color TEXT DEFAULT '#5E72C3',
        background_mode TEXT DEFAULT 'color',
        background_asset TEXT,
        background_local_path TEXT,
        raw_json TEXT,
        local_status TEXT DEFAULT 'synced',
        local_deleted INTEGER DEFAULT 0,
        synced_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_todo_tasks (
        task_id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL,
        title TEXT NOT NULL,
        body_text TEXT,
        body_html TEXT,
        body_content_type TEXT,
        status TEXT,
        importance TEXT,
        created_date_time TEXT,
        last_modified_date_time TEXT,
        due_date_time TEXT,
        due_time_zone TEXT,
        start_date_time TEXT,
        start_time_zone TEXT,
        is_reminder_on INTEGER DEFAULT 0,
        is_my_day INTEGER DEFAULT 0,
        reminder_date_time TEXT,
        reminder_time_zone TEXT,
        completed_date_time TEXT,
        recurrence_json TEXT,
        categories_json TEXT,
        has_attachments INTEGER DEFAULT 0,
        raw_json TEXT,
        local_status TEXT DEFAULT 'synced',
        local_deleted INTEGER DEFAULT 0,
        synced_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_todo_task_children (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        list_id TEXT NOT NULL,
        task_id TEXT NOT NULL,
        child_type TEXT NOT NULL,
        child_id TEXT,
        title TEXT,
        content TEXT,
        is_checked INTEGER DEFAULT 0,
        remote_url TEXT,
        local_path TEXT,
        raw_json TEXT,
        local_status TEXT DEFAULT 'synced',
        local_deleted INTEGER DEFAULT 0,
        synced_at_ms INTEGER NOT NULL,
        UNIQUE(task_id, child_type, child_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_todo_groups (
        group_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        remote_group_id TEXT,
        sort_order INTEGER DEFAULT 0,
        raw_json TEXT,
        local_status TEXT DEFAULT 'synced',
        local_deleted INTEGER DEFAULT 0,
        synced_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_todo_group_lists (
        group_id TEXT NOT NULL,
        list_id TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        synced_at_ms INTEGER NOT NULL,
        PRIMARY KEY (group_id, list_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_todo_settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_todo_sync_tombstones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        parent_id TEXT,
        reason TEXT,
        raw_json TEXT,
        deleted_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ms_todo_tombstones_entity ON ms_todo_sync_tombstones(entity_type, entity_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS external_api_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        endpoint TEXT,
        method TEXT,
        request_params TEXT,
        response_body TEXT,
        status_code INTEGER,
        error_message TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await _ensureColumn(db, 'ms_todo_lists', 'theme_color', "TEXT DEFAULT '#5E72C3'");
    await _ensureColumn(db, 'ms_todo_lists', 'background_mode', "TEXT DEFAULT 'color'");
    await _ensureColumn(db, 'ms_todo_lists', 'background_asset', 'TEXT');
    await _ensureColumn(db, 'ms_todo_lists', 'background_local_path', 'TEXT');
    await _ensureColumn(db, 'ms_todo_tasks', 'start_date_time', 'TEXT');
    await _ensureColumn(db, 'ms_todo_tasks', 'start_time_zone', 'TEXT');
    await _ensureColumn(db, 'ms_todo_tasks', 'is_reminder_on', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'ms_todo_tasks', 'is_my_day', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'ms_todo_tasks', 'recurrence_json', 'TEXT');
    await _ensureColumn(db, 'ms_todo_tasks', 'categories_json', 'TEXT');
    await _ensureColumn(db, 'ms_todo_task_children', 'local_status', "TEXT DEFAULT 'synced'");
    await _ensureColumn(db, 'ms_todo_task_children', 'local_deleted', 'INTEGER DEFAULT 0');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ms_todo_tasks_list ON ms_todo_tasks(list_id, local_deleted, last_modified_date_time DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ms_todo_child_task ON ms_todo_task_children(task_id)');
    await _ensureColumn(db, 'ms_todo_groups', 'remote_group_id', 'TEXT');
    await _ensureColumn(db, 'ms_todo_groups', 'sort_order', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'ms_todo_groups', 'local_status', "TEXT DEFAULT 'synced'");
    await _ensureColumn(db, 'ms_todo_groups', 'local_deleted', 'INTEGER DEFAULT 0');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ms_todo_group_lists_group ON ms_todo_group_lists(group_id, sort_order)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ms_todo_group_lists_list ON ms_todo_group_lists(list_id)');
    await _purgeLegacyRemoteDeletedRows(db);
  }

  Future<void> _purgeLegacyRemoteDeletedRows(Database db) async {
    // v25 以前远端删除会把主表记录软删除为 remote_deleted。
    // v26 改为“远端镜像确认不存在 => 本地主表/子表物理删除”，
    // 这里只清理历史 remote_deleted 僵尸数据，保留 external_api_logs 和 tombstones。
    await db.transaction((txn) async {
      final remoteDeletedTasks = await txn.query(
        'ms_todo_tasks',
        columns: ['task_id', 'list_id', 'raw_json'],
        where: "local_status = 'remote_deleted'",
      );
      for (final row in remoteDeletedTasks) {
        final taskId = (row['task_id'] ?? '').toString();
        if (taskId.isEmpty) continue;
        await txn.insert('ms_todo_sync_tombstones', {
          'entity_type': 'task',
          'entity_id': taskId,
          'parent_id': (row['list_id'] ?? '').toString(),
          'reason': 'purge_legacy_remote_deleted',
          'raw_json': (row['raw_json'] ?? '').toString(),
          'deleted_at_ms': DateTime.now().millisecondsSinceEpoch,
        });
        await txn.delete('ms_todo_task_children', where: 'task_id = ?', whereArgs: [taskId]);
        await txn.delete('ms_todo_tasks', where: 'task_id = ?', whereArgs: [taskId]);
      }

      final remoteDeletedLists = await txn.query(
        'ms_todo_lists',
        columns: ['list_id', 'raw_json'],
        where: "local_status = 'remote_deleted'",
      );
      for (final row in remoteDeletedLists) {
        final listId = (row['list_id'] ?? '').toString();
        if (listId.isEmpty) continue;
        await txn.insert('ms_todo_sync_tombstones', {
          'entity_type': 'list',
          'entity_id': listId,
          'parent_id': '',
          'reason': 'purge_legacy_remote_deleted',
          'raw_json': (row['raw_json'] ?? '').toString(),
          'deleted_at_ms': DateTime.now().millisecondsSinceEpoch,
        });
        await txn.delete('ms_todo_group_lists', where: 'list_id = ?', whereArgs: [listId]);
        await txn.delete('ms_todo_task_children', where: 'list_id = ?', whereArgs: [listId]);
        await txn.delete('ms_todo_tasks', where: 'list_id = ?', whereArgs: [listId]);
        await txn.delete('ms_todo_lists', where: 'list_id = ?', whereArgs: [listId]);
      }

      await txn.delete('ms_todo_task_children', where: "local_status = 'remote_deleted'");
    });
  }

  Future<void> _ensureColumn(Database db, String table, String column, String type) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final exists = rows.any((r) => (r['name'] ?? '').toString() == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  String newLocalId(String prefix) => 'local_${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> addApiLog({
    required String endpoint,
    required String method,
    String? requestParams,
    String? responseBody,
    int? statusCode,
    String? errorMessage,
  }) async {
    try {
      final db = await _db;
      await db.insert('external_api_logs', {
        'source': 'todo',
        'endpoint': endpoint,
        'method': method,
        'request_params': _limit(requestParams),
        'response_body': _limit(responseBody, max: 5000),
        'status_code': statusCode,
        'error_message': _limit(errorMessage, max: 2000),
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<List<Map<String, Object?>>> recentApiLogs({int limit = 80}) async {
    final db = await _db;
    return db.query('external_api_logs', where: 'source = ?', whereArgs: ['todo'], orderBy: 'id DESC', limit: limit);
  }

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final db = await _db;
    final rows = await db.query('ms_todo_settings', columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return defaultValue;
    final value = (rows.first['value'] ?? '').toString();
    return value.isEmpty ? defaultValue : value;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _db;
    await db.insert(
      'ms_todo_settings',
      {
        'key': key,
        'value': value,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> getPreferredTimeZone() => getSetting('todo_preferred_time_zone', defaultValue: 'Asia/Shanghai');

  Future<void> setPreferredTimeZone(String timeZone) async {
    final value = timeZone.trim().isEmpty ? 'Asia/Shanghai' : timeZone.trim();
    await setSetting('todo_preferred_time_zone', value);
  }

  Future<Map<String, String>> _listAppearanceFields(Database db, String listId) async {
    final rows = await db.query(
      'ms_todo_lists',
      columns: ['theme_color', 'background_mode', 'background_asset', 'background_local_path'],
      where: 'list_id = ?',
      whereArgs: [listId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const {
        'theme_color': '#5E72C3',
        'background_mode': 'color',
        'background_asset': '',
        'background_local_path': '',
      };
    }
    String v(String key, String fallback) {
      final raw = (rows.first[key] ?? '').toString();
      return raw.trim().isEmpty ? fallback : raw;
    }

    return {
      'theme_color': v('theme_color', '#5E72C3'),
      'background_mode': v('background_mode', 'color'),
      'background_asset': v('background_asset', ''),
      'background_local_path': v('background_local_path', ''),
    };
  }

  Future<void> updateListAppearance({
    required String listId,
    required String themeColor,
    required String backgroundMode,
    String backgroundAsset = '',
    String backgroundLocalPath = '',
  }) async {
    final db = await _db;
    await db.update(
      'ms_todo_lists',
      {
        'theme_color': _normalizeHexColor(themeColor),
        'background_mode': backgroundMode.trim().isEmpty ? 'color' : backgroundMode.trim(),
        'background_asset': backgroundAsset.trim(),
        'background_local_path': backgroundLocalPath.trim(),
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'list_id = ?',
      whereArgs: [listId],
    );
  }

  String _normalizeHexColor(String raw) {
    final s = raw.trim();
    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)) return s.toUpperCase();
    return '#5E72C3';
  }

  Future<void> upsertList(Map<String, dynamic> item) async {
    final db = await _db;
    final id = (item['id'] ?? item['list_id'] ?? '').toString();
    if (id.isEmpty) return;
    final appearance = await _listAppearanceFields(db, id);
    await db.insert(
      'ms_todo_lists',
      {
        'list_id': id,
        'display_name': (item['displayName'] ?? item['display_name'] ?? '未命名任务列表').toString(),
        'wellknown_list_name': (item['wellknownListName'] ?? item['wellknown_list_name'] ?? '').toString(),
        'is_owner': _boolToInt(item['isOwner'] ?? item['is_owner']),
        'is_shared': _boolToInt(item['isShared'] ?? item['is_shared']),
        'theme_color': appearance['theme_color'] ?? '#5E72C3',
        'background_mode': appearance['background_mode'] ?? 'color',
        'background_asset': appearance['background_asset'] ?? '',
        'background_local_path': appearance['background_local_path'] ?? '',
        'raw_json': jsonEncode(item),
        'local_status': 'synced',
        'local_deleted': 0,
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> createLocalList(
    String displayName, {
    String themeColor = '#5E72C3',
    String backgroundMode = 'color',
    String backgroundAsset = '',
    String backgroundLocalPath = '',
  }) async {
    final db = await _db;
    final id = newLocalId('todo_list');
    await db.insert('ms_todo_lists', {
      'list_id': id,
      'display_name': displayName.trim().isEmpty ? '未命名任务列表' : displayName.trim(),
      'wellknown_list_name': '',
      'is_owner': 1,
      'is_shared': 0,
      'theme_color': _normalizeHexColor(themeColor),
      'background_mode': backgroundMode.trim().isEmpty ? 'color' : backgroundMode.trim(),
      'background_asset': backgroundAsset.trim(),
      'background_local_path': backgroundLocalPath.trim(),
      'raw_json': '{}',
      'local_status': 'pending_create',
      'local_deleted': 0,
      'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<void> replaceLocalListId(String oldId, Map<String, dynamic> remote) async {
    final db = await _db;
    final newId = (remote['id'] ?? '').toString();
    if (oldId.isEmpty || newId.isEmpty || oldId == newId) return;
    final appearance = await _listAppearanceFields(db, oldId);
    await db.transaction((txn) async {
      await txn.update('ms_todo_tasks', {'list_id': newId}, where: 'list_id = ?', whereArgs: [oldId]);
      await txn.update('ms_todo_task_children', {'list_id': newId}, where: 'list_id = ?', whereArgs: [oldId]);
      await txn.update('ms_todo_group_lists', {'list_id': newId}, where: 'list_id = ?', whereArgs: [oldId]);
      await txn.delete('ms_todo_lists', where: 'list_id = ?', whereArgs: [oldId]);
      await txn.insert('ms_todo_lists', {
        'list_id': newId,
        'display_name': (remote['displayName'] ?? '未命名任务列表').toString(),
        'wellknown_list_name': (remote['wellknownListName'] ?? '').toString(),
        'is_owner': _boolToInt(remote['isOwner']),
        'is_shared': _boolToInt(remote['isShared']),
        'theme_color': appearance['theme_color'] ?? '#5E72C3',
        'background_mode': appearance['background_mode'] ?? 'color',
        'background_asset': appearance['background_asset'] ?? '',
        'background_local_path': appearance['background_local_path'] ?? '',
        'raw_json': jsonEncode(remote),
        'local_status': 'synced',
        'local_deleted': 0,
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<TodoGroupRecord>> listGroups({bool includeDeleted = false}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT g.*,
             (SELECT COUNT(*) FROM ms_todo_group_lists gl
              JOIN ms_todo_lists l ON l.list_id = gl.list_id
              WHERE gl.group_id = g.group_id AND COALESCE(l.local_deleted, 0) = 0) AS list_count
      FROM ms_todo_groups g
      ${includeDeleted ? '' : 'WHERE COALESCE(g.local_deleted, 0) = 0'}
      ORDER BY g.sort_order ASC, g.display_name ASC
    ''');
    return rows.map(TodoGroupRecord.fromMap).toList();
  }

  Future<TodoGroupRecord?> getGroup(String groupId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT g.*,
             (SELECT COUNT(*) FROM ms_todo_group_lists gl
              JOIN ms_todo_lists l ON l.list_id = gl.list_id
              WHERE gl.group_id = g.group_id AND COALESCE(l.local_deleted, 0) = 0) AS list_count
      FROM ms_todo_groups g
      WHERE g.group_id = ? LIMIT 1
    ''', [groupId]);
    if (rows.isEmpty) return null;
    return TodoGroupRecord.fromMap(rows.first);
  }

  Future<String> createLocalGroup(String displayName) async {
    final db = await _db;
    final id = newLocalId('todo_group');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('ms_todo_groups', {
      'group_id': id,
      'display_name': displayName.trim().isEmpty ? '未命名组' : displayName.trim(),
      'remote_group_id': '',
      'sort_order': now,
      'raw_json': '{}',
      'local_status': 'pending_create',
      'local_deleted': 0,
      'synced_at_ms': now,
    });
    return id;
  }

  Future<void> updateLocalGroup(String groupId, String displayName, {String localStatus = 'pending_update'}) async {
    final db = await _db;
    await db.update('ms_todo_groups', {
      'display_name': displayName.trim().isEmpty ? '未命名组' : displayName.trim(),
      'local_status': localStatus,
      'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, where: 'group_id = ?', whereArgs: [groupId]);
  }

  Future<void> removeGroup(String groupId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('ms_todo_group_lists', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('ms_todo_groups', where: 'group_id = ?', whereArgs: [groupId]);
    });
  }

  Future<void> assignListToGroup({required String listId, required String groupId, int sortOrder = 0}) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('ms_todo_group_lists', where: 'list_id = ?', whereArgs: [listId]);
      if (groupId.trim().isEmpty) return;
      await txn.insert('ms_todo_group_lists', {
        'group_id': groupId,
        'list_id': listId,
        'sort_order': sortOrder,
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> unassignListFromGroups(String listId) async {
    final db = await _db;
    await db.delete('ms_todo_group_lists', where: 'list_id = ?', whereArgs: [listId]);
  }

  Future<Map<String, String>> listGroupAssignments() async {
    final db = await _db;
    final rows = await db.query('ms_todo_group_lists');
    final out = <String, String>{};
    for (final row in rows) {
      final listId = (row['list_id'] ?? '').toString();
      final groupId = (row['group_id'] ?? '').toString();
      if (listId.isNotEmpty && groupId.isNotEmpty) out[listId] = groupId;
    }
    return out;
  }

  Future<List<TodoListRecord>> listListsInGroup(String groupId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT l.*,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status != 'completed') AS task_count,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status != 'completed') AS open_task_count,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status = 'completed') AS completed_task_count
      FROM ms_todo_group_lists gl
      JOIN ms_todo_lists l ON l.list_id = gl.list_id
      WHERE gl.group_id = ? AND COALESCE(l.local_deleted, 0) = 0
      ORDER BY gl.sort_order ASC, l.display_name ASC
    ''', [groupId]);
    return rows.map(TodoListRecord.fromMap).toList();
  }

  Future<TodoUnsyncedSummary> unsyncedSummary({String listId = ''}) async {
    final db = await _db;
    final argsForTasks = <Object?>[];
    final argsForChildren = <Object?>[];
    var taskWhere = "COALESCE(local_deleted, 0) = 0 AND COALESCE(local_status, 'synced') != 'synced'";
    var childWhere = "COALESCE(local_deleted, 0) = 0 AND COALESCE(local_status, 'synced') != 'synced'";
    if (listId.trim().isNotEmpty && !listId.startsWith('smart_')) {
      taskWhere += ' AND list_id = ?';
      childWhere += ' AND list_id = ?';
      argsForTasks.add(listId.trim());
      argsForChildren.add(listId.trim());
    }
    final listRows = listId.trim().isNotEmpty && !listId.startsWith('smart_')
        ? await db.rawQuery("SELECT COUNT(*) AS c FROM ms_todo_lists WHERE list_id = ? AND COALESCE(local_deleted, 0) = 0 AND COALESCE(local_status, 'synced') != 'synced'", [listId.trim()])
        : await db.rawQuery("SELECT COUNT(*) AS c FROM ms_todo_lists WHERE COALESCE(local_deleted, 0) = 0 AND COALESCE(local_status, 'synced') != 'synced'");
    final taskRows = await db.rawQuery('SELECT COUNT(*) AS c FROM ms_todo_tasks WHERE $taskWhere', argsForTasks);
    final childRows = await db.rawQuery('SELECT COUNT(*) AS c FROM ms_todo_task_children WHERE $childWhere', argsForChildren);
    return TodoUnsyncedSummary(
      lists: _asInt(listRows.isEmpty ? 0 : listRows.first['c']),
      tasks: _asInt(taskRows.isEmpty ? 0 : taskRows.first['c']),
      children: _asInt(childRows.isEmpty ? 0 : childRows.first['c']),
    );
  }

  Future<List<TodoListRecord>> pendingLocalLists() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT l.*,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status != 'completed') AS task_count,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status != 'completed') AS open_task_count,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status = 'completed') AS completed_task_count
      FROM ms_todo_lists l
      WHERE COALESCE(l.local_deleted, 0) = 0
        AND COALESCE(l.local_status, 'synced') != 'synced'
      ORDER BY CASE WHEN l.list_id LIKE 'local_%' OR l.local_status = 'pending_create' THEN 0 ELSE 1 END,
               l.synced_at_ms ASC
    ''');
    return rows.map(TodoListRecord.fromMap).toList();
  }

  Future<List<TodoTaskRecord>> pendingLocalTasks({String listId = ''}) async {
    final db = await _db;
    final args = <Object?>[];
    var where = "COALESCE(t.local_deleted, 0) = 0 AND COALESCE(t.local_status, 'synced') != 'synced'";
    if (listId.trim().isNotEmpty && !listId.startsWith('smart_')) {
      where += ' AND t.list_id = ?';
      args.add(listId.trim());
    }
    final rows = await db.rawQuery('''
      SELECT t.*,
             COALESCE(l.display_name, '') AS list_display_name,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'checklistItem' AND COALESCE(c.local_deleted, 0) = 0) AS checklist_count,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'attachment' AND COALESCE(c.local_deleted, 0) = 0) AS attachment_count,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'linkedResource' AND COALESCE(c.local_deleted, 0) = 0) AS linked_resource_count
      FROM ms_todo_tasks t
      LEFT JOIN ms_todo_lists l ON l.list_id = t.list_id
      WHERE $where
      ORDER BY CASE WHEN t.task_id LIKE 'local_%' OR t.local_status = 'pending_create' THEN 0 ELSE 1 END,
               t.synced_at_ms ASC
    ''', args);
    return rows.map(TodoTaskRecord.fromMap).toList();
  }

  Future<List<TodoChildRecord>> pendingChecklistItems({String taskId = ''}) async {
    final db = await _db;
    final args = <Object?>[];
    var where = "child_type = 'checklistItem' AND COALESCE(local_status, 'synced') != 'synced'";
    if (taskId.trim().isNotEmpty) {
      where += ' AND task_id = ?';
      args.add(taskId.trim());
    }
    final rows = await db.query(
      'ms_todo_task_children',
      where: where,
      whereArgs: args,
      orderBy: 'id ASC',
    );
    return rows.map(TodoChildRecord.fromMap).toList();
  }
  Future<void> updateLocalList(String listId, String displayName, {String localStatus = 'pending_update'}) async {
    final db = await _db;
    final oldRows = await db.query('ms_todo_lists', columns: ['local_status'], where: 'list_id = ?', whereArgs: [listId], limit: 1);
    final oldStatus = oldRows.isNotEmpty ? (oldRows.first['local_status'] ?? '').toString() : '';
    final nextStatus = listId.startsWith('local_') || oldStatus == 'pending_create' ? 'pending_create' : localStatus;
    await db.update(
      'ms_todo_lists',
      {
        'display_name': displayName.trim().isEmpty ? '未命名任务列表' : displayName.trim(),
        'local_status': nextStatus,
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'list_id = ?',
      whereArgs: [listId],
    );
  }

  Future<void> markListDeleted(String listId, {String localStatus = 'pending_delete'}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'ms_todo_lists',
        {
          'local_deleted': 1,
          'local_status': localStatus,
          'synced_at_ms': now,
        },
        where: 'list_id = ?',
        whereArgs: [listId],
      );
      await txn.update(
        'ms_todo_tasks',
        {
          'local_deleted': 1,
          'local_status': localStatus,
          'synced_at_ms': now,
        },
        where: 'list_id = ?',
        whereArgs: [listId],
      );
      await txn.update(
        'ms_todo_task_children',
        {
          'local_deleted': 1,
          'local_status': localStatus,
          'synced_at_ms': now,
        },
        where: 'list_id = ?',
        whereArgs: [listId],
      );
      await txn.delete('ms_todo_group_lists', where: 'list_id = ?', whereArgs: [listId]);
    });
  }

  Future<void> removeList(String listId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('ms_todo_group_lists', where: 'list_id = ?', whereArgs: [listId]);
      await txn.delete('ms_todo_task_children', where: 'list_id = ?', whereArgs: [listId]);
      await txn.delete('ms_todo_tasks', where: 'list_id = ?', whereArgs: [listId]);
      await txn.delete('ms_todo_lists', where: 'list_id = ?', whereArgs: [listId]);
    });
  }

  Future<void> upsertTask(Map<String, dynamic> item, {required String listId}) async {
    final db = await _db;
    final id = (item['id'] ?? item['task_id'] ?? '').toString();
    if (id.isEmpty) return;
    final oldRows = await db.query('ms_todo_tasks', columns: ['is_my_day'], where: 'task_id = ?', whereArgs: [id], limit: 1);
    final preservedMyDay = oldRows.isNotEmpty ? _boolToInt(oldRows.first['is_my_day']) : 0;
    final body = item['body'];
    final due = item['dueDateTime'];
    final start = item['startDateTime'];
    final reminder = item['reminderDateTime'];
    final completed = item['completedDateTime'];
    final recurrence = item['recurrence'];
    final categories = item['categories'];
    await db.insert(
      'ms_todo_tasks',
      {
        'task_id': id,
        'list_id': listId,
        'title': (item['title'] ?? '未命名任务').toString(),
        'body_text': _plainBody(body),
        'body_html': body is Map ? (body['content'] ?? '').toString() : '',
        'body_content_type': body is Map ? (body['contentType'] ?? '').toString() : '',
        'status': (item['status'] ?? 'notStarted').toString(),
        'importance': (item['importance'] ?? 'normal').toString(),
        'created_date_time': (item['createdDateTime'] ?? '').toString(),
        'last_modified_date_time': (item['lastModifiedDateTime'] ?? '').toString(),
        'due_date_time': due is Map ? (due['dateTime'] ?? '').toString() : '',
        'due_time_zone': due is Map ? (due['timeZone'] ?? '').toString() : '',
        'start_date_time': start is Map ? (start['dateTime'] ?? '').toString() : '',
        'start_time_zone': start is Map ? (start['timeZone'] ?? '').toString() : '',
        'is_reminder_on': _boolToInt(item['isReminderOn']),
        'is_my_day': _boolToInt(item['isInMyDay'] ?? item['isMyDay']) == 1 ? 1 : preservedMyDay,
        'reminder_date_time': reminder is Map ? (reminder['dateTime'] ?? '').toString() : '',
        'reminder_time_zone': reminder is Map ? (reminder['timeZone'] ?? '').toString() : '',
        'completed_date_time': completed is Map ? (completed['dateTime'] ?? '').toString() : '',
        'recurrence_json': recurrence == null ? '' : jsonEncode(recurrence),
        'categories_json': categories == null ? '' : jsonEncode(categories),
        'has_attachments': _boolToInt(item['hasAttachments']),
        'raw_json': jsonEncode(item),
        'local_status': 'synced',
        'local_deleted': 0,
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> createLocalTask({
    required String listId,
    required String title,
    required String bodyText,
    required String status,
    required String importance,
    String dueDateTime = '',
    String dueTimeZone = 'Asia/Shanghai',
    String startDateTime = '',
    String startTimeZone = 'Asia/Shanghai',
    bool isReminderOn = false,
    String reminderDateTime = '',
    String reminderTimeZone = 'Asia/Shanghai',
    String recurrenceJson = '',
    String categoriesJson = '',
    bool isMyDay = false,
  }) async {
    final db = await _db;
    final id = newLocalId('todo_task');
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('ms_todo_tasks', {
      'task_id': id,
      'list_id': listId,
      'title': title.trim().isEmpty ? '未命名任务' : title.trim(),
      'body_text': bodyText,
      'body_html': bodyText,
      'body_content_type': 'text',
      'status': status,
      'importance': importance,
      'created_date_time': now,
      'last_modified_date_time': now,
      'due_date_time': dueDateTime,
      'due_time_zone': dueTimeZone,
      'start_date_time': startDateTime,
      'start_time_zone': startTimeZone,
      'is_reminder_on': isReminderOn ? 1 : 0,
      'is_my_day': isMyDay ? 1 : 0,
      'reminder_date_time': reminderDateTime,
      'reminder_time_zone': reminderTimeZone,
      'completed_date_time': '',
      'recurrence_json': recurrenceJson,
      'categories_json': categoriesJson,
      'has_attachments': 0,
      'raw_json': '{}',
      'local_status': 'pending_create',
      'local_deleted': 0,
      'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<void> replaceLocalTaskId(String oldId, String listId, Map<String, dynamic> remote) async {
    final db = await _db;
    final newId = (remote['id'] ?? '').toString();
    if (oldId.isEmpty || newId.isEmpty || oldId == newId) return;
    final oldRows = await db.query('ms_todo_tasks', columns: ['is_my_day'], where: 'task_id = ?', whereArgs: [oldId], limit: 1);
    final oldIsMyDay = oldRows.isNotEmpty ? _boolToInt(oldRows.first['is_my_day']) : 0;
    await db.transaction((txn) async {
      await txn.update('ms_todo_task_children', {'task_id': newId}, where: 'task_id = ?', whereArgs: [oldId]);
      await txn.delete('ms_todo_tasks', where: 'task_id = ?', whereArgs: [oldId]);
    });
    await upsertTask(remote, listId: listId);
    if (oldIsMyDay == 1) {
      await db.update('ms_todo_tasks', {'is_my_day': 1}, where: 'task_id = ?', whereArgs: [newId]);
    }
  }

  Future<void> replaceTaskWithRemoteDroppingChildren({
    required String oldTaskId,
    required String listId,
    required Map<String, dynamic> remote,
  }) async {
    final db = await _db;
    final newTaskId = (remote['id'] ?? '').toString();
    if (oldTaskId.isEmpty || newTaskId.isEmpty) return;
    final oldRows = await db.query(
      'ms_todo_tasks',
      columns: ['is_my_day'],
      where: 'task_id = ?',
      whereArgs: [oldTaskId],
      limit: 1,
    );
    final oldIsMyDay = oldRows.isNotEmpty ? _boolToInt(oldRows.first['is_my_day']) : 0;
    await db.transaction((txn) async {
      await txn.delete('ms_todo_task_children', where: 'task_id = ?', whereArgs: [oldTaskId]);
      if (newTaskId != oldTaskId) {
        await txn.delete('ms_todo_task_children', where: 'task_id = ?', whereArgs: [newTaskId]);
      }
      await txn.delete('ms_todo_tasks', where: 'task_id = ?', whereArgs: [oldTaskId]);
      if (newTaskId != oldTaskId) {
        await txn.delete('ms_todo_tasks', where: 'task_id = ?', whereArgs: [newTaskId]);
      }
    });
    await upsertTask(remote, listId: listId);
    if (oldIsMyDay == 1) {
      await db.update('ms_todo_tasks', {'is_my_day': 1}, where: 'task_id = ?', whereArgs: [newTaskId]);
    }
  }

  Future<void> updateLocalTask({
    required String taskId,
    required String title,
    required String bodyText,
    required String status,
    required String importance,
    required String dueDateTime,
    required String dueTimeZone,
    required String startDateTime,
    required String startTimeZone,
    required bool isReminderOn,
    required String reminderDateTime,
    required String reminderTimeZone,
    required String recurrenceJson,
    required String categoriesJson,
    required bool isMyDay,
    String localStatus = 'pending_update',
  }) async {
    final db = await _db;
    final oldRows = await db.query('ms_todo_tasks', columns: ['local_status'], where: 'task_id = ?', whereArgs: [taskId], limit: 1);
    final oldStatus = oldRows.isNotEmpty ? (oldRows.first['local_status'] ?? '').toString() : '';
    final nextStatus = taskId.startsWith('local_') || oldStatus == 'pending_create' ? 'pending_create' : localStatus;
    await db.update(
      'ms_todo_tasks',
      {
        'title': title.trim().isEmpty ? '未命名任务' : title.trim(),
        'body_text': bodyText,
        'body_html': bodyText,
        'body_content_type': 'text',
        'status': status,
        'importance': importance,
        'due_date_time': dueDateTime,
        'due_time_zone': dueTimeZone,
        'start_date_time': startDateTime,
        'start_time_zone': startTimeZone,
        'is_reminder_on': isReminderOn ? 1 : 0,
        'is_my_day': isMyDay ? 1 : 0,
        'reminder_date_time': reminderDateTime,
        'reminder_time_zone': reminderTimeZone,
        'recurrence_json': recurrenceJson,
        'categories_json': categoriesJson,
        'local_status': nextStatus,
        'last_modified_date_time': DateTime.now().toUtc().toIso8601String(),
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }



  Future<void> updateTaskCompletion({
    required String taskId,
    required bool completed,
    String localStatus = 'pending_update',
  }) async {
    final db = await _db;
    final oldRows = await db.query('ms_todo_tasks', columns: ['local_status'], where: 'task_id = ?', whereArgs: [taskId], limit: 1);
    final oldStatus = oldRows.isNotEmpty ? (oldRows.first['local_status'] ?? '').toString() : '';
    final nextStatus = taskId.startsWith('local_') || oldStatus == 'pending_create' ? 'pending_create' : localStatus;
    await db.update(
      'ms_todo_tasks',
      {
        'status': completed ? 'completed' : 'notStarted',
        'completed_date_time': completed ? DateTime.now().toUtc().toIso8601String() : '',
        'local_status': nextStatus,
        'last_modified_date_time': DateTime.now().toUtc().toIso8601String(),
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }


  Future<void> markTaskDeleted(String taskId, {String localStatus = 'pending_delete'}) async {
    final db = await _db;
    await db.update(
      'ms_todo_tasks',
      {
        'local_deleted': 1,
        'local_status': localStatus,
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> removeTask(String taskId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('ms_todo_task_children', where: 'task_id = ?', whereArgs: [taskId]);
      await txn.delete('ms_todo_tasks', where: 'task_id = ?', whereArgs: [taskId]);
    });
  }

  Future<void> markRemoteTasksDeletedForList({required String listId, required Set<String> remoteTaskIds}) async {
    final db = await _db;
    final rows = await db.query(
      'ms_todo_tasks',
      columns: ['task_id', 'raw_json'],
      where: "list_id = ? AND task_id NOT LIKE 'local_%'",
      whereArgs: [listId],
    );
    final removedRows = rows.where((row) {
      final taskId = (row['task_id'] ?? '').toString();
      return taskId.isNotEmpty && !remoteTaskIds.contains(taskId);
    }).toList();
    if (removedRows.isEmpty) return;

    await db.transaction((txn) async {
      for (final row in removedRows) {
        final taskId = (row['task_id'] ?? '').toString();
        if (taskId.isEmpty) continue;
        await txn.insert('ms_todo_sync_tombstones', {
          'entity_type': 'task',
          'entity_id': taskId,
          'parent_id': listId,
          'reason': 'remote_missing_in_list_sync',
          'raw_json': (row['raw_json'] ?? '').toString(),
          'deleted_at_ms': DateTime.now().millisecondsSinceEpoch,
        });
        await txn.delete('ms_todo_task_children', where: 'task_id = ?', whereArgs: [taskId]);
        await txn.delete('ms_todo_tasks', where: 'task_id = ?', whereArgs: [taskId]);
      }
    });
  }

  Future<void> markRemoteListsDeleted({required Set<String> remoteListIds}) async {
    final db = await _db;
    final rows = await db.query(
      'ms_todo_lists',
      columns: ['list_id', 'raw_json'],
      where: "list_id NOT LIKE 'local_%'",
    );
    final removedRows = rows.where((row) {
      final listId = (row['list_id'] ?? '').toString();
      return listId.isNotEmpty && !remoteListIds.contains(listId);
    }).toList();
    if (removedRows.isEmpty) return;

    await db.transaction((txn) async {
      for (final row in removedRows) {
        final listId = (row['list_id'] ?? '').toString();
        if (listId.isEmpty) continue;
        await _purgeListMirrorInTransaction(
          txn,
          listId: listId,
          listRawJson: (row['raw_json'] ?? '').toString(),
          reason: 'remote_missing_in_full_sync',
        );
      }
    });
  }

  Future<void> markRemoteListDeleted(String listId) async {
    if (listId.trim().isEmpty) return;
    final db = await _db;
    final rows = await db.query('ms_todo_lists', columns: ['raw_json'], where: 'list_id = ?', whereArgs: [listId], limit: 1);
    await db.transaction((txn) async {
      await _purgeListMirrorInTransaction(
        txn,
        listId: listId,
        listRawJson: rows.isNotEmpty ? (rows.first['raw_json'] ?? '').toString() : '',
        reason: 'remote_list_get_404',
      );
    });
  }

  Future<void> _purgeListMirrorInTransaction(
    Transaction txn, {
    required String listId,
    required String reason,
    String listRawJson = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final taskRows = await txn.query(
      'ms_todo_tasks',
      columns: ['task_id', 'raw_json'],
      where: 'list_id = ?',
      whereArgs: [listId],
    );
    for (final taskRow in taskRows) {
      final taskId = (taskRow['task_id'] ?? '').toString();
      if (taskId.isEmpty) continue;
      await txn.insert('ms_todo_sync_tombstones', {
        'entity_type': 'task',
        'entity_id': taskId,
        'parent_id': listId,
        'reason': reason,
        'raw_json': (taskRow['raw_json'] ?? '').toString(),
        'deleted_at_ms': now,
      });
    }
    await txn.insert('ms_todo_sync_tombstones', {
      'entity_type': 'list',
      'entity_id': listId,
      'parent_id': '',
      'reason': reason,
      'raw_json': listRawJson,
      'deleted_at_ms': now,
    });
    await txn.delete('ms_todo_group_lists', where: 'list_id = ?', whereArgs: [listId]);
    await txn.delete('ms_todo_task_children', where: 'list_id = ?', whereArgs: [listId]);
    await txn.delete('ms_todo_tasks', where: 'list_id = ?', whereArgs: [listId]);
    await txn.delete('ms_todo_lists', where: 'list_id = ?', whereArgs: [listId]);
  }

  Future<void> replaceChildren({required String listId, required String taskId, required String childType, required List<Map<String, dynamic>> rows}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete('ms_todo_task_children', where: 'task_id = ? AND child_type = ?', whereArgs: [taskId, childType]);
      for (final row in rows) {
        final childId = (row['id'] ?? '').toString();
        String title = (row['displayName'] ?? row['subject'] ?? row['title'] ?? row['name'] ?? '').toString();
        String content = (row['content'] ?? row['webUrl'] ?? row['applicationName'] ?? '').toString();
        String remoteUrl = (row['contentUrl'] ?? row['webUrl'] ?? row['externalLink'] ?? '').toString();
        final checked = row['isChecked'] == true || (row['checkedDateTime'] != null && row['checkedDateTime'].toString().isNotEmpty);
        await txn.insert('ms_todo_task_children', {
          'list_id': listId,
          'task_id': taskId,
          'child_type': childType,
          'child_id': childId,
          'title': title,
          'content': content,
          'is_checked': checked ? 1 : 0,
          'remote_url': remoteUrl,
          'local_path': '',
          'raw_json': jsonEncode(row),
          'local_status': 'synced',
          'local_deleted': 0,
          'synced_at_ms': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<TodoListRecord>> smartLists() async {
    final ids = <String>['smart_myday', 'smart_important', 'smart_planned', 'smart_all', 'smart_completed', 'smart_assigned'];
    final out = <TodoListRecord>[];
    for (final id in ids) {
      final item = await getList(id);
      if (item != null) out.add(item);
    }
    return out;
  }

  Future<TodoListRecord?> _smartList(String listId) async {
    if (!listId.startsWith('smart_')) return null;
    final db = await _db;
    final where = _smartWhere(listId, todayPrefix: await _todayPrefixForPreferredZone());
    if (where == null) return null;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS task_count,
             SUM(CASE WHEN status != 'completed' THEN 1 ELSE 0 END) AS open_task_count,
             SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_task_count
      FROM ms_todo_tasks t
      WHERE t.local_deleted = 0 AND $where
    ''');
    final row = rows.isEmpty ? <String, Object?>{} : rows.first;
    return TodoListRecord(
      listId: listId,
      displayName: _smartTitle(listId),
      wellknownListName: listId,
      isOwner: true,
      isShared: false,
      taskCount: _asInt(row['task_count']),
      openTaskCount: _asInt(row['open_task_count']),
      completedTaskCount: _asInt(row['completed_task_count']),
      themeColor: '#5E72C3',
      backgroundMode: 'color',
      backgroundAsset: '',
      backgroundLocalPath: '',
      localStatus: listId == 'smart_myday' ? 'virtual_limited' : 'virtual',
      localDeleted: false,
      syncedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String? _smartWhere(String listId, {String? todayPrefix}) {
    // Microsoft To Do treats My Day / Important / Planned / All as active-task
    // views. Completed tasks are kept out of those views and shown by Completed.
    switch (listId) {
      case 'smart_all':
        return "t.status != 'completed'";
      case 'smart_assigned':
        return '0 = 1';
      case 'smart_completed':
        return "t.status = 'completed'";
      case 'smart_important':
        return "t.importance = 'high' AND t.status != 'completed'";
      case 'smart_planned':
        return "(COALESCE(t.due_date_time, '') != '' OR COALESCE(t.start_date_time, '') != '' OR COALESCE(t.reminder_date_time, '') != '') AND t.status != 'completed'";
      case 'smart_myday':
        final today = todayPrefix ?? _todayPrefix();
        return "(t.is_my_day = 1 OR t.due_date_time LIKE '$today%' OR t.start_date_time LIKE '$today%' OR t.reminder_date_time LIKE '$today%') AND t.status != 'completed'";
      default:
        return null;
    }
  }

  String _smartTitle(String listId) {
    switch (listId) {
      case 'smart_myday':
        return '我的一天';
      case 'smart_assigned':
        return '已分配给我';
      case 'smart_important':
        return '重要';
      case 'smart_planned':
        return '计划内';
      case 'smart_all':
        return '全部';
      case 'smart_completed':
        return '已完成';
      default:
        return listId;
    }
  }

  Future<String> _todayPrefixForPreferredZone() async {
    final tz = await getPreferredTimeZone();
    final now = _nowInPreferredZone(tz);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  DateTime _nowInPreferredZone(String timeZone) {
    final utc = DateTime.now().toUtc();
    final offsetMinutes = _timeZoneOffsetMinutes(timeZone);
    if (offsetMinutes == null) return DateTime.now();
    return utc.add(Duration(minutes: offsetMinutes));
  }

  int? _timeZoneOffsetMinutes(String timeZone) {
    switch (timeZone.trim()) {
      case 'UTC':
      case 'Etc/GMT':
        return 0;
      case 'Asia/Shanghai':
      case 'Asia/Singapore':
      case 'Asia/Taipei':
        return 8 * 60;
      case 'Asia/Tokyo':
      case 'Asia/Seoul':
        return 9 * 60;
      case 'Europe/London':
        return 0;
      case 'Europe/Paris':
      case 'Europe/Berlin':
        return 60;
      case 'America/New_York':
        return -5 * 60;
      case 'America/Los_Angeles':
        return -8 * 60;
      default:
        return null;
    }
  }

  String _todayPrefix() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<List<TodoListRecord>> listLists({bool includeDeleted = false}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT l.*,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status != 'completed') AS task_count,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status != 'completed') AS open_task_count,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status = 'completed') AS completed_task_count
      FROM ms_todo_lists l
      ${includeDeleted ? '' : 'WHERE l.local_deleted = 0'}
      ORDER BY l.wellknown_list_name DESC, l.display_name ASC
    ''');
    return rows.map(TodoListRecord.fromMap).toList();
  }

  Future<TodoListRecord?> getList(String listId) async {
    final smart = await _smartList(listId);
    if (smart != null) return smart;
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT l.*,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status != 'completed') AS task_count,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status != 'completed') AS open_task_count,
             (SELECT COUNT(*) FROM ms_todo_tasks t WHERE t.list_id = l.list_id AND t.local_deleted = 0 AND t.status = 'completed') AS completed_task_count
      FROM ms_todo_lists l WHERE l.list_id = ? AND COALESCE(l.local_deleted, 0) = 0 LIMIT 1
    ''', [listId]);
    if (rows.isEmpty) return null;
    return TodoListRecord.fromMap(rows.first);
  }

  Future<List<TodoTaskRecord>> listTasks(String listId, {String filter = 'all', int limit = 50, int offset = 0}) async {
    final db = await _db;
    final args = <Object?>[];
    var where = 'COALESCE(t.local_deleted, 0) = 0';
    if (listId.startsWith('smart_')) {
      final smartWhere = _smartWhere(listId, todayPrefix: await _todayPrefixForPreferredZone());
      if (smartWhere != null) where += ' AND $smartWhere';
    } else {
      where += ' AND t.list_id = ?';
      args.add(listId);
    }

    if (filter == 'completed' || listId == 'smart_completed') {
      where += " AND t.status = 'completed'";
    } else {
      where += " AND t.status != 'completed'";
    }

    final rows = await db.rawQuery('''
      SELECT t.*,
             COALESCE(l.display_name, '') AS list_display_name,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'checklistItem' AND COALESCE(c.local_deleted, 0) = 0) AS checklist_count,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'attachment' AND COALESCE(c.local_deleted, 0) = 0) AS attachment_count,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'linkedResource' AND COALESCE(c.local_deleted, 0) = 0) AS linked_resource_count
      FROM ms_todo_tasks t
      LEFT JOIN ms_todo_lists l ON l.list_id = t.list_id
      WHERE $where
      ORDER BY t.due_date_time ASC, t.last_modified_date_time DESC
      LIMIT ? OFFSET ?
    ''', [...args, limit, offset]);
    return rows.map(TodoTaskRecord.fromMap).toList();
  }

  Future<List<TodoTaskRecord>> searchTasks(String query, {int limit = 100}) async {
    final q = query.trim();
    if (q.isEmpty) return <TodoTaskRecord>[];
    final db = await _db;
    final like = '%$q%';
    final rows = await db.rawQuery('''
      SELECT t.*,
             COALESCE(l.display_name, '') AS list_display_name,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'checklistItem' AND COALESCE(c.local_deleted, 0) = 0) AS checklist_count,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'attachment' AND COALESCE(c.local_deleted, 0) = 0) AS attachment_count,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'linkedResource' AND COALESCE(c.local_deleted, 0) = 0) AS linked_resource_count
      FROM ms_todo_tasks t
      LEFT JOIN ms_todo_lists l ON l.list_id = t.list_id
      WHERE COALESCE(t.local_deleted, 0) = 0
        AND (
          t.title LIKE ?
          OR COALESCE(t.body_text, '') LIKE ?
          OR EXISTS (
            SELECT 1 FROM ms_todo_task_children c
            WHERE c.task_id = t.task_id
              AND COALESCE(c.local_deleted, 0) = 0
              AND (
                COALESCE(c.title, '') LIKE ?
                OR COALESCE(c.content, '') LIKE ?
              )
          )
        )
      ORDER BY CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END,
               t.due_date_time ASC,
               t.last_modified_date_time DESC
      LIMIT ?
    ''', [like, like, like, like, limit]);
    return rows.map(TodoTaskRecord.fromMap).toList();
  }

  Future<TodoTaskRecord?> getTask(String taskId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT t.*,
             COALESCE(l.display_name, '') AS list_display_name,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'checklistItem' AND COALESCE(c.local_deleted, 0) = 0) AS checklist_count,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'attachment' AND COALESCE(c.local_deleted, 0) = 0) AS attachment_count,
             (SELECT COUNT(*) FROM ms_todo_task_children c WHERE c.task_id = t.task_id AND c.child_type = 'linkedResource' AND COALESCE(c.local_deleted, 0) = 0) AS linked_resource_count
      FROM ms_todo_tasks t
      LEFT JOIN ms_todo_lists l ON l.list_id = t.list_id
      WHERE t.task_id = ? AND COALESCE(t.local_deleted, 0) = 0
      LIMIT 1
    ''', [taskId]);
    if (rows.isEmpty) return null;
    return TodoTaskRecord.fromMap(rows.first);
  }

  Future<List<TodoChildRecord>> listChildren(String taskId, String type) async {
    final db = await _db;
    final rows = await db.query(
      'ms_todo_task_children',
      where: 'task_id = ? AND child_type = ? AND COALESCE(local_deleted, 0) = 0',
      whereArgs: [taskId, type],
      orderBy: 'id ASC',
    );
    return rows.map(TodoChildRecord.fromMap).toList();
  }


  Future<String> upsertLocalChecklistItem({
    required String listId,
    required String taskId,
    String childId = '',
    required String title,
    bool isChecked = false,
    String localStatus = 'pending_update',
  }) async {
    final db = await _db;
    final id = childId.trim().isEmpty ? newLocalId('todo_step') : childId.trim();
    final oldRows = childId.trim().isEmpty
        ? <Map<String, Object?>>[]
        : await db.query('ms_todo_task_children', where: 'task_id = ? AND child_type = ? AND child_id = ?', whereArgs: [taskId, 'checklistItem', childId], limit: 1);
    final oldRaw = oldRows.isNotEmpty ? (oldRows.first['raw_json'] ?? '{}').toString() : '{}';
    await db.insert(
      'ms_todo_task_children',
      {
        'list_id': listId,
        'task_id': taskId,
        'child_type': 'checklistItem',
        'child_id': id,
        'title': title.trim().isEmpty ? '下一步' : title.trim(),
        'content': '',
        'is_checked': isChecked ? 1 : 0,
        'remote_url': '',
        'local_path': '',
        'raw_json': oldRaw,
        'local_status': id.startsWith('local_') ? 'pending_create' : localStatus,
        'local_deleted': 0,
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<void> markChecklistItemDeleted({required String taskId, required String childId}) async {
    final db = await _db;
    await db.update(
      'ms_todo_task_children',
      {
        'local_deleted': 1,
        'local_status': childId.startsWith('local_') ? 'local_deleted' : 'pending_delete',
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'task_id = ? AND child_type = ? AND child_id = ?',
      whereArgs: [taskId, 'checklistItem', childId],
    );
  }

  Future<void> removeChecklistItem({required String taskId, required String childId}) async {
    final db = await _db;
    await db.delete(
      'ms_todo_task_children',
      where: 'task_id = ? AND child_type = ? AND child_id = ?',
      whereArgs: [taskId, 'checklistItem', childId],
    );
  }

  Future<void> replaceLocalChecklistItemId({
    required String taskId,
    required String oldChildId,
    required Map<String, dynamic> remote,
  }) async {
    final newChildId = (remote['id'] ?? '').toString();
    if (newChildId.isEmpty) return;
    final db = await _db;
    await db.delete('ms_todo_task_children', where: 'task_id = ? AND child_type = ? AND child_id = ?', whereArgs: [taskId, 'checklistItem', oldChildId]);
    await db.insert(
      'ms_todo_task_children',
      {
        'list_id': (remote['list_id'] ?? '').toString(),
        'task_id': taskId,
        'child_type': 'checklistItem',
        'child_id': newChildId,
        'title': (remote['displayName'] ?? remote['title'] ?? '下一步').toString(),
        'content': '',
        'is_checked': (remote['isChecked'] == true || remote['checkedDateTime'] != null) ? 1 : 0,
        'remote_url': '',
        'local_path': '',
        'raw_json': jsonEncode(remote),
        'local_status': 'synced',
        'local_deleted': 0,
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  String _plainBody(Object? body) {
    if (body is! Map) return '';
    final raw = (body['content'] ?? '').toString();
    var s = raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'</(p|div|li)>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    s = s.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  int _boolToInt(Object? v) => v == true || v == 1 || v?.toString() == 'true' ? 1 : 0;

  String _limit(String? s, {int max = 1200}) {
    if (s == null) return '';
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...(truncated)';
  }
}
