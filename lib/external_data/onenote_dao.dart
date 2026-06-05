import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'onenote_config.dart';
import 'onenote_models.dart';

class OneNoteDao {
  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_onenote_auth (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        account_id TEXT,
        display_name TEXT,
        access_token TEXT,
        refresh_token TEXT,
        scope TEXT,
        expires_at_ms INTEGER,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_onenote_notebooks (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        created_time TEXT,
        last_modified_time TEXT,
        self_url TEXT,
        raw_json TEXT,
        synced_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_onenote_sections (
        id TEXT PRIMARY KEY,
        notebook_id TEXT NOT NULL,
        display_name TEXT NOT NULL,
        created_time TEXT,
        last_modified_time TEXT,
        self_url TEXT,
        raw_json TEXT,
        synced_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_onenote_pages (
        id TEXT PRIMARY KEY,
        notebook_id TEXT NOT NULL,
        section_id TEXT NOT NULL,
        title TEXT,
        created_time TEXT,
        last_modified_time TEXT,
        order_value INTEGER,
        html_content TEXT,
        plain_text TEXT,
        raw_json TEXT,
        synced_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_onenote_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        page_id TEXT NOT NULL,
        resource_id TEXT,
        file_name TEXT,
        mime_type TEXT,
        remote_url TEXT,
        local_path TEXT,
        size_bytes INTEGER,
        synced_at_ms INTEGER NOT NULL,
        UNIQUE(page_id, resource_id, remote_url)
      )
    ''');
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_onenote_settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ms_onenote_sections_notebook ON ms_onenote_sections(notebook_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ms_onenote_pages_section ON ms_onenote_pages(section_id, last_modified_time DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ms_onenote_pages_notebook ON ms_onenote_pages(notebook_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ms_onenote_attach_page ON ms_onenote_attachments(page_id)');
  }

  Future<String?> getSetting(String key) async {
    final db = await _db;
    final rows = await db.query('ms_onenote_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _db;
    await db.insert(
      'ms_onenote_settings',
      {
        'key': key,
        'value': value,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> getRedirectUri() async {
    final saved = (await getSetting('microsoft_onenote_redirect_uri'))?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    return OneNoteConfig.defaultRedirectUri;
  }

  Future<void> saveRedirectUri(String redirectUri) async {
    final value = redirectUri.trim();
    if (value.isEmpty) {
      await setSetting('microsoft_onenote_redirect_uri', OneNoteConfig.defaultRedirectUri);
      return;
    }
    final parsed = Uri.tryParse(value);
    if (parsed == null || parsed.scheme.isEmpty) {
      throw Exception('重定向 URI 格式不正确。示例：${OneNoteConfig.defaultRedirectUri}');
    }
    if (parsed.scheme.toLowerCase() != OneNoteConfig.defaultCallbackScheme) {
      throw Exception('当前 Android 回调只支持 msauth:// 开头的 Microsoft 重定向 URI。');
    }
    await setSetting('microsoft_onenote_redirect_uri', value);
  }

  Future<void> resetRedirectUri() async {
    await setSetting('microsoft_onenote_redirect_uri', OneNoteConfig.defaultRedirectUri);
  }

  Future<void> saveAuth({
    required String accountId,
    required String displayName,
    required String accessToken,
    required String refreshToken,
    required String scope,
    required int expiresAtMs,
  }) async {
    final db = await _db;
    await db.insert(
      'ms_onenote_auth',
      {
        'id': 1,
        'account_id': accountId,
        'display_name': displayName,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'scope': scope,
        'expires_at_ms': expiresAtMs,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> getAuth() async {
    final db = await _db;
    final rows = await db.query('ms_onenote_auth', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> clearAuth() async {
    final db = await _db;
    await db.delete('ms_onenote_auth');
  }

  Future<void> upsertNotebook(Map<String, dynamic> notebook) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = (notebook['id'] ?? '').toString();
    if (id.isEmpty) return;
    await db.insert(
      'ms_onenote_notebooks',
      {
        'id': id,
        'display_name': (notebook['displayName'] ?? notebook['display_name'] ?? '未命名笔记本').toString(),
        'created_time': (notebook['createdDateTime'] ?? notebook['createdTime'] ?? '').toString(),
        'last_modified_time': (notebook['lastModifiedDateTime'] ?? notebook['lastModifiedTime'] ?? '').toString(),
        'self_url': (notebook['self'] ?? '').toString(),
        'raw_json': jsonEncode(notebook),
        'synced_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertSection(Map<String, dynamic> section, {String? fallbackNotebookId}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = (section['id'] ?? '').toString();
    if (id.isEmpty) return;
    final parentNotebook = section['parentNotebook'];
    final notebookId = (parentNotebook is Map ? parentNotebook['id'] : null)?.toString() ?? fallbackNotebookId ?? '';
    await db.insert(
      'ms_onenote_sections',
      {
        'id': id,
        'notebook_id': notebookId,
        'display_name': (section['displayName'] ?? section['display_name'] ?? '未命名分区').toString(),
        'created_time': (section['createdDateTime'] ?? section['createdTime'] ?? '').toString(),
        'last_modified_time': (section['lastModifiedDateTime'] ?? section['lastModifiedTime'] ?? '').toString(),
        'self_url': (section['self'] ?? '').toString(),
        'raw_json': jsonEncode(section),
        'synced_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertPage({
    required Map<String, dynamic> page,
    required String notebookId,
    required String sectionId,
    required String html,
    required String plainText,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = (page['id'] ?? '').toString();
    if (id.isEmpty) return;
    await db.insert(
      'ms_onenote_pages',
      {
        'id': id,
        'notebook_id': notebookId,
        'section_id': sectionId,
        'title': (page['title'] ?? '未命名页面').toString(),
        'created_time': (page['createdDateTime'] ?? page['createdTime'] ?? '').toString(),
        'last_modified_time': (page['lastModifiedDateTime'] ?? page['lastModifiedTime'] ?? '').toString(),
        'order_value': int.tryParse((page['order'] ?? '0').toString()) ?? 0,
        'html_content': html,
        'plain_text': plainText,
        'raw_json': jsonEncode(page),
        'synced_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceAttachments(String pageId, List<Map<String, Object?>> attachments) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete('ms_onenote_attachments', where: 'page_id = ?', whereArgs: [pageId]);
      for (final a in attachments) {
        await txn.insert('ms_onenote_attachments', {
          'page_id': pageId,
          'resource_id': (a['resource_id'] ?? '').toString(),
          'file_name': (a['file_name'] ?? '').toString(),
          'mime_type': (a['mime_type'] ?? '').toString(),
          'remote_url': (a['remote_url'] ?? '').toString(),
          'local_path': (a['local_path'] ?? '').toString(),
          'size_bytes': a['size_bytes'] is num ? (a['size_bytes'] as num).toInt() : int.tryParse((a['size_bytes'] ?? '0').toString()) ?? 0,
          'synced_at_ms': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> addApiLog({
    required String source,
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
        'source': source,
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

  Future<List<OneNoteNotebookRecord>> listNotebooks() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT n.*,
             (SELECT COUNT(*) FROM ms_onenote_sections s WHERE s.notebook_id = n.id) AS section_count,
             (SELECT COUNT(*) FROM ms_onenote_pages p WHERE p.notebook_id = n.id) AS page_count
      FROM ms_onenote_notebooks n
      ORDER BY n.last_modified_time DESC, n.display_name ASC
    ''');
    return rows.map(OneNoteNotebookRecord.fromMap).toList();
  }

  Future<OneNoteNotebookRecord?> getNotebook(String id) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT n.*,
             (SELECT COUNT(*) FROM ms_onenote_sections s WHERE s.notebook_id = n.id) AS section_count,
             (SELECT COUNT(*) FROM ms_onenote_pages p WHERE p.notebook_id = n.id) AS page_count
      FROM ms_onenote_notebooks n WHERE n.id = ? LIMIT 1
    ''', [id]);
    if (rows.isEmpty) return null;
    return OneNoteNotebookRecord.fromMap(rows.first);
  }

  Future<List<OneNoteSectionRecord>> listSections(String notebookId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.*,
             (SELECT COUNT(*) FROM ms_onenote_pages p WHERE p.section_id = s.id) AS page_count
      FROM ms_onenote_sections s
      WHERE s.notebook_id = ?
      ORDER BY s.display_name ASC
    ''', [notebookId]);
    return rows.map(OneNoteSectionRecord.fromMap).toList();
  }

  Future<OneNoteSectionRecord?> getSection(String id) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.*,
             (SELECT COUNT(*) FROM ms_onenote_pages p WHERE p.section_id = s.id) AS page_count
      FROM ms_onenote_sections s WHERE s.id = ? LIMIT 1
    ''', [id]);
    if (rows.isEmpty) return null;
    return OneNoteSectionRecord.fromMap(rows.first);
  }

  Future<List<OneNotePageRecord>> listPages(String sectionId, {int limit = 30, int offset = 0}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT p.*,
             (SELECT COUNT(*) FROM ms_onenote_attachments a WHERE a.page_id = p.id) AS attachment_count
      FROM ms_onenote_pages p
      WHERE p.section_id = ?
      ORDER BY p.last_modified_time DESC, p.created_time DESC
      LIMIT ? OFFSET ?
    ''', [sectionId, limit, offset]);
    return rows.map(OneNotePageRecord.fromMap).toList();
  }

  Future<OneNotePageRecord?> getPage(String pageId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT p.*,
             (SELECT COUNT(*) FROM ms_onenote_attachments a WHERE a.page_id = p.id) AS attachment_count
      FROM ms_onenote_pages p WHERE p.id = ? LIMIT 1
    ''', [pageId]);
    if (rows.isEmpty) return null;
    return OneNotePageRecord.fromMap(rows.first);
  }

  Future<List<OneNoteAttachmentRecord>> listAttachments(String pageId) async {
    final db = await _db;
    final rows = await db.query(
      'ms_onenote_attachments',
      where: 'page_id = ?',
      whereArgs: [pageId],
      orderBy: 'id ASC',
    );
    return rows.map(OneNoteAttachmentRecord.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> recentApiLogs({int limit = 80}) async {
    final db = await _db;
    return db.query('external_api_logs', where: 'source = ?', whereArgs: ['onenote'], orderBy: 'id DESC', limit: limit);
  }

  String _limit(String? s, {int max = 1200}) {
    if (s == null) return '';
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...(truncated)';
  }
}
