import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../health_diet/services/health_connect_diet_context_service.dart';
import '../platform/native_scheduler.dart';
import 'behavior_tracking_dao.dart';
import 'behavior_tracking_models.dart';

/// V12：纯行为观察模块保留的数据源能力。
///
/// 这些能力只负责“自动收集/提醒记录/生成行为证据”，不做行为改变、干预实验或替代方案推荐。
class BehaviorTrackingNativeBridge {
  static const MethodChannel _channel = MethodChannel('behavior.tracking.native');

  static Future<bool> hasUsageAccess() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openUsageAccessSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> queryUsageStats(DateTime start, DateTime end, {int minMinutes = 3}) async {
    if (!Platform.isAndroid) return const [];
    final rows = await _channel.invokeMethod<List<dynamic>>('queryUsageStats', {
      'startMs': start.millisecondsSinceEpoch,
      'endMs': end.millisecondsSinceEpoch,
      'minMs': minMinutes * 60 * 1000,
    });
    return (rows ?? const [])
        .whereType<Map>()
        .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  static Future<bool> hasCalendarPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasCalendarPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestCalendarPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('requestCalendarPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasPostNotificationsPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPostNotificationsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPostNotificationsPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPostNotificationsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openAppPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openAppPermissionSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> queryCalendarEvents(DateTime start, DateTime end) async {
    if (!Platform.isAndroid) return const [];
    final rows = await _channel.invokeMethod<List<dynamic>>('queryCalendarEvents', {
      'startMs': start.millisecondsSinceEpoch,
      'endMs': end.millisecondsSinceEpoch,
    });
    return (rows ?? const [])
        .whereType<Map>()
        .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }



  static Future<bool> requestPinBehaviorObservationWidget() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPinBehaviorObservationWidget') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> showBehaviorObservationQuickRecordNotification({
    String title = '行为观察提醒',
    String body = '现在可以记录一条行为观察。',
    String templateKey = 'notification_layer_select',
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final payload = <String, dynamic>{
        'module': 'behavior_tracking',
        'route': '/behavior_tracking',
        'title': title,
        'body': body,
        'message': body,
        'templateKey': templateKey,
        'entryMode': 'notification_layer_selector',
      };
      return await _channel.invokeMethod<bool>('showBehaviorObservationQuickRecordNotification', {
            'title': title,
            'body': body,
            'payload': jsonEncode(payload),
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> consumeLastNotificationPayload() async {
    if (!Platform.isAndroid) return null;
    try {
      final row = await _channel.invokeMethod<Map<dynamic, dynamic>>('consumeLastNotificationPayload');
      if (row == null) return null;
      return row.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  static void installNotificationTapHandler(FutureOr<void> Function(Map<String, dynamic> payload) onPayload) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onBehaviorNotificationTap') return null;
      final args = call.arguments;
      if (args is! Map) return null;
      final payload = decodePayloadEnvelope(args.map((key, value) => MapEntry(key.toString(), value)));
      if (payload != null) await onPayload(payload);
      return null;
    });
  }

  static Map<String, dynamic>? decodePayloadEnvelope(Map<String, dynamic>? envelope) {
    if (envelope == null) return null;
    final rawPayload = envelope['payload'];
    if (rawPayload is Map) return rawPayload.map((key, value) => MapEntry(key.toString(), value));
    final text = rawPayload?.toString();
    if (text == null || text.trim().isEmpty) return envelope;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {}
    return envelope;
  }
}

class BehaviorImportQueueItem {
  final int? id;
  final String sourceKey;
  final String externalId;
  final String title;
  final String rawJson;
  final String mappedRecordJson;
  final String status;
  final String note;
  final int createdAtMs;
  final int updatedAtMs;

  const BehaviorImportQueueItem({
    this.id,
    required this.sourceKey,
    required this.externalId,
    required this.title,
    required this.rawJson,
    required this.mappedRecordJson,
    required this.status,
    required this.note,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'source_key': sourceKey,
        'external_id': externalId,
        'title': title,
        'raw_json': rawJson,
        'mapped_record_json': mappedRecordJson,
        'status': status,
        'note': note,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory BehaviorImportQueueItem.fromMap(Map<String, Object?> map) => BehaviorImportQueueItem(
        id: _asInt(map['id']),
        sourceKey: (map['source_key'] ?? '').toString(),
        externalId: (map['external_id'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        rawJson: (map['raw_json'] ?? '{}').toString(),
        mappedRecordJson: (map['mapped_record_json'] ?? '{}').toString(),
        status: (map['status'] ?? 'pending').toString(),
        note: (map['note'] ?? '').toString(),
        createdAtMs: _asInt(map['created_at_ms']) ?? DateTime.now().millisecondsSinceEpoch,
        updatedAtMs: _asInt(map['updated_at_ms']) ?? DateTime.now().millisecondsSinceEpoch,
      );

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }
}

class BehaviorTrackingReminderPlan {
  final int? id;
  final String title;
  final String message;
  final String templateKey;
  final int timeMinute;
  final bool enabled;
  final int createdAtMs;
  final int updatedAtMs;

  const BehaviorTrackingReminderPlan({
    this.id,
    required this.title,
    required this.message,
    required this.templateKey,
    required this.timeMinute,
    required this.enabled,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  factory BehaviorTrackingReminderPlan.defaultNight() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return BehaviorTrackingReminderPlan(
      title: '睡前行为观察',
      message: '现在可以记录一条行为观察。',
      templateKey: 'notification_layer_select',
      timeMinute: 22 * 60,
      enabled: true,
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  String get timeLabel => '${(timeMinute ~/ 60).toString().padLeft(2, '0')}:${(timeMinute % 60).toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'template_key': templateKey,
        'time_minute': timeMinute,
        'enabled': enabled ? 1 : 0,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory BehaviorTrackingReminderPlan.fromMap(Map<String, Object?> map) => BehaviorTrackingReminderPlan(
        id: BehaviorImportQueueItem._asInt(map['id']),
        title: (map['title'] ?? '行为观察提醒').toString(),
        message: (map['message'] ?? '现在可以记录一条行为观察。').toString(),
        templateKey: (map['template_key'] ?? 'notification_layer_select').toString(),
        timeMinute: BehaviorImportQueueItem._asInt(map['time_minute']) ?? 22 * 60,
        enabled: (BehaviorImportQueueItem._asInt(map['enabled']) ?? 1) == 1,
        createdAtMs: BehaviorImportQueueItem._asInt(map['created_at_ms']) ?? DateTime.now().millisecondsSinceEpoch,
        updatedAtMs: BehaviorImportQueueItem._asInt(map['updated_at_ms']) ?? DateTime.now().millisecondsSinceEpoch,
      );

  BehaviorTrackingReminderPlan copyWith({
    int? id,
    String? title,
    String? message,
    String? templateKey,
    int? timeMinute,
    bool? enabled,
    int? updatedAtMs,
  }) =>
      BehaviorTrackingReminderPlan(
        id: id ?? this.id,
        title: title ?? this.title,
        message: message ?? this.message,
        templateKey: templateKey ?? this.templateKey,
        timeMinute: timeMinute ?? this.timeMinute,
        enabled: enabled ?? this.enabled,
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );
}


class BehaviorTrackingAutoSyncPlan {
  final int? id;
  final String sourceKey;
  final String title;
  final int timeMinute;
  final bool enabled;
  final int lookbackDays;
  final int lookaheadDays;
  final int createdAtMs;
  final int updatedAtMs;

  const BehaviorTrackingAutoSyncPlan({
    this.id,
    required this.sourceKey,
    required this.title,
    required this.timeMinute,
    required this.enabled,
    required this.lookbackDays,
    required this.lookaheadDays,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  factory BehaviorTrackingAutoSyncPlan.defaultFor(String sourceKey) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (sourceKey == 'calendar') {
      return BehaviorTrackingAutoSyncPlan(
        sourceKey: 'calendar',
        title: '系统日历自动读取',
        timeMinute: 7 * 60 + 30,
        enabled: false,
        lookbackDays: 0,
        lookaheadDays: 7,
        createdAtMs: now,
        updatedAtMs: now,
      );
    }
    if (sourceKey == 'health_connect') {
      return BehaviorTrackingAutoSyncPlan(
        sourceKey: 'health_connect',
        title: '健康数据自动读取',
        timeMinute: 22 * 60,
        enabled: false,
        lookbackDays: 0,
        lookaheadDays: 0,
        createdAtMs: now,
        updatedAtMs: now,
      );
    }
    return BehaviorTrackingAutoSyncPlan(
      sourceKey: 'screen_usage',
      title: '屏幕使用时间自动读取',
      timeMinute: 23 * 60,
      enabled: false,
      lookbackDays: 0,
      lookaheadDays: 0,
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  String get timeLabel => '${(timeMinute ~/ 60).toString().padLeft(2, '0')}:${(timeMinute % 60).toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() => {
        'id': id,
        'source_key': sourceKey,
        'title': title,
        'time_minute': timeMinute,
        'enabled': enabled ? 1 : 0,
        'lookback_days': lookbackDays,
        'lookahead_days': lookaheadDays,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory BehaviorTrackingAutoSyncPlan.fromMap(Map<String, Object?> map) => BehaviorTrackingAutoSyncPlan(
        id: BehaviorImportQueueItem._asInt(map['id']),
        sourceKey: (map['source_key'] ?? '').toString(),
        title: (map['title'] ?? '自动读取').toString(),
        timeMinute: BehaviorImportQueueItem._asInt(map['time_minute']) ?? 23 * 60,
        enabled: (BehaviorImportQueueItem._asInt(map['enabled']) ?? 0) == 1,
        lookbackDays: BehaviorImportQueueItem._asInt(map['lookback_days']) ?? 0,
        lookaheadDays: BehaviorImportQueueItem._asInt(map['lookahead_days']) ?? 0,
        createdAtMs: BehaviorImportQueueItem._asInt(map['created_at_ms']) ?? DateTime.now().millisecondsSinceEpoch,
        updatedAtMs: BehaviorImportQueueItem._asInt(map['updated_at_ms']) ?? DateTime.now().millisecondsSinceEpoch,
      );

  BehaviorTrackingAutoSyncPlan copyWith({
    int? id,
    String? sourceKey,
    String? title,
    int? timeMinute,
    bool? enabled,
    int? lookbackDays,
    int? lookaheadDays,
    int? updatedAtMs,
  }) =>
      BehaviorTrackingAutoSyncPlan(
        id: id ?? this.id,
        sourceKey: sourceKey ?? this.sourceKey,
        title: title ?? this.title,
        timeMinute: timeMinute ?? this.timeMinute,
        enabled: enabled ?? this.enabled,
        lookbackDays: lookbackDays ?? this.lookbackDays,
        lookaheadDays: lookaheadDays ?? this.lookaheadDays,
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );
}

class BehaviorTrackingExternalDao {
  static const queueTable = 'behavior_tracking_import_queue';
  static const remindersTable = 'behavior_tracking_reminders';
  static const autoSyncTable = 'behavior_tracking_auto_sync_plans';
  final BehaviorTrackingDao _recordDao = BehaviorTrackingDao();

  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await _recordDao.ensureTables(db);
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $queueTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_key TEXT NOT NULL,
        external_id TEXT,
        title TEXT,
        raw_json TEXT,
        mapped_record_json TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        note TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_import_status ON $queueTable(status, updated_at_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_import_source_external ON $queueTable(source_key, external_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $remindersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        message TEXT,
        template_key TEXT,
        time_minute INTEGER,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $autoSyncTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_key TEXT NOT NULL UNIQUE,
        title TEXT,
        time_minute INTEGER,
        enabled INTEGER NOT NULL DEFAULT 0,
        lookback_days INTEGER NOT NULL DEFAULT 0,
        lookahead_days INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await _ensureDefaultAutoSyncPlans(db);
  }

  Future<int> saveQueueItem(BehaviorImportQueueItem item) async {
    final db = await _db;
    final existing = await db.query(queueTable, where: 'source_key = ? AND external_id = ?', whereArgs: [item.sourceKey, item.externalId], orderBy: 'updated_at_ms DESC, id DESC', limit: 1);
    if (existing.isNotEmpty) {
      final id = BehaviorImportQueueItem._asInt(existing.first['id'])!;
      final status = (existing.first['status'] ?? '').toString();
      // 同一个外部数据源的同一条数据只保留一个队列项：
      // pending：刷新最新原始数据；approved：重新读取时改回 pending，方便用户看到“今日数据已刷新”。
      // 确认写入时会按 source + title + record_date_ms 更新已有正式记录，避免重复累计时间。
      final data = item.copyStatus(id: id, status: item.status).toMap();
      data.remove('id');
      await db.update(queueTable, data, where: 'id = ?', whereArgs: [id]);
      return id;
    }
    final data = item.toMap()..remove('id');
    return db.insert(queueTable, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BehaviorImportQueueItem>> queue({String status = 'pending', int limit = 100}) async {
    final db = await _db;
    final rows = await db.query(queueTable, where: 'status = ?', whereArgs: [status], orderBy: 'updated_at_ms DESC, id DESC', limit: limit);
    return rows.map(BehaviorImportQueueItem.fromMap).toList();
  }

  Future<int> pendingCount() async => (await queue(status: 'pending', limit: 1000)).length;

  Future<BehaviorTrackingRecord?> approveQueueItem(int id) async {
    final db = await _db;
    final rows = await db.query(queueTable, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final item = BehaviorImportQueueItem.fromMap(rows.first);
    final decoded = jsonDecode(item.mappedRecordJson);
    if (decoded is! Map) return null;
    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    map.remove('id');
    var record = BehaviorTrackingRecord.fromMap(map);
    final source = (map['source'] ?? '').toString().trim();
    final title = (map['title'] ?? '').toString().trim();
    final recordDateMs = BehaviorImportQueueItem._asInt(map['record_date_ms']);
    if (source.isNotEmpty && title.isNotEmpty && recordDateMs != null) {
      final existing = await db.query(
        BehaviorTrackingDao.tableName,
        columns: ['id'],
        where: 'source = ? AND title = ? AND record_date_ms = ?',
        whereArgs: [source, title, recordDateMs],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingId = BehaviorImportQueueItem._asInt(existing.first['id']);
        if (existingId != null) record = record.copyWith(id: existingId);
      }
    }
    final savedId = await _recordDao.save(record);
    await db.update(queueTable, {'status': 'approved', 'updated_at_ms': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
    return record.copyWith(id: savedId);
  }

  Future<int> approveAllPending() async {
    final items = await queue(status: 'pending', limit: 500);
    var count = 0;
    for (final item in items) {
      if (item.id == null) continue;
      final saved = await approveQueueItem(item.id!);
      if (saved != null) count++;
    }
    return count;
  }

  Future<void> rejectQueueItem(int id) async {
    final db = await _db;
    await db.update(queueTable, {'status': 'rejected', 'updated_at_ms': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> rejectAllPending() async {
    final db = await _db;
    return db.update(queueTable, {'status': 'rejected', 'updated_at_ms': DateTime.now().millisecondsSinceEpoch}, where: 'status = ?', whereArgs: ['pending']);
  }


  Future<void> _ensureDefaultAutoSyncPlans(Database db) async {
    for (final source in const ['screen_usage', 'calendar', 'health_connect']) {
      final plan = BehaviorTrackingAutoSyncPlan.defaultFor(source);
      final data = plan.toMap()..remove('id');
      await db.insert(autoSyncTable, data, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<BehaviorTrackingAutoSyncPlan>> autoSyncPlans() async {
    final db = await _db;
    await _ensureDefaultAutoSyncPlans(db);
    final rows = await db.query(autoSyncTable, orderBy: 'source_key ASC');
    final plans = rows.map(BehaviorTrackingAutoSyncPlan.fromMap).toList();
    plans.sort((a, b) {
      int order(String key) => key == 'screen_usage' ? 0 : key == 'calendar' ? 1 : key == 'health_connect' ? 2 : 9;
      final o = order(a.sourceKey).compareTo(order(b.sourceKey));
      return o != 0 ? o : a.timeMinute.compareTo(b.timeMinute);
    });
    return plans;
  }

  Future<int> saveAutoSyncPlan(BehaviorTrackingAutoSyncPlan plan) async {
    final db = await _db;
    final data = plan.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch).toMap();
    if (plan.id == null) {
      data.remove('id');
      return db.insert(autoSyncTable, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await db.update(autoSyncTable, data, where: 'id = ?', whereArgs: [plan.id]);
    return plan.id!;
  }

  Future<int> saveReminder(BehaviorTrackingReminderPlan plan) async {
    final db = await _db;
    final data = plan.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch).toMap();
    if (plan.id == null) {
      data.remove('id');
      return db.insert(remindersTable, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await db.update(remindersTable, data, where: 'id = ?', whereArgs: [plan.id]);
    return plan.id!;
  }

  Future<List<BehaviorTrackingReminderPlan>> reminders() async {
    final db = await _db;
    final rows = await db.query(remindersTable, orderBy: 'time_minute ASC, id ASC');
    return rows.map(BehaviorTrackingReminderPlan.fromMap).toList();
  }

  Future<void> deleteReminder(int id) async {
    final db = await _db;
    await db.delete(remindersTable, where: 'id = ?', whereArgs: [id]);
  }
}

extension on BehaviorImportQueueItem {
  BehaviorImportQueueItem copyStatus({int? id, String? status}) => BehaviorImportQueueItem(
        id: id ?? this.id,
        sourceKey: sourceKey,
        externalId: externalId,
        title: title,
        rawJson: rawJson,
        mappedRecordJson: mappedRecordJson,
        status: status ?? this.status,
        note: note,
        createdAtMs: createdAtMs,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
}

class BehaviorExternalImportResult {
  final int imported;
  final List<String> details;
  const BehaviorExternalImportResult({required this.imported, required this.details});
}

class BehaviorTrackingExternalService {
  final BehaviorTrackingDao _records = BehaviorTrackingDao();
  final BehaviorTrackingExternalDao _external = BehaviorTrackingExternalDao();
  final HealthConnectDietContextService _health = HealthConnectDietContextService();

  Future<BehaviorExternalImportResult> importTodayScreenUsage() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final rows = await BehaviorTrackingNativeBridge.queryUsageStats(start, now, minMinutes: 3);
    var imported = 0;
    final details = <String>[];
    for (final row in rows.take(40)) {
      final record = _usageRowToRecord(row, start);
      final item = _queueItem(sourceKey: 'screen_usage', externalId: 'screen_${row['packageName']}_${start.millisecondsSinceEpoch}', title: record.title, raw: row, record: record, note: '系统屏幕使用统计：这是应用聚合使用时长，不代表精确开始/结束。请确认后写入记录。');
      await _external.saveQueueItem(item);
      imported++;
      details.add('${row['appName'] ?? row['packageName'] ?? '未知应用'} · ${record.actualValue?.round() ?? 0} 分钟');
    }
    return BehaviorExternalImportResult(imported: imported, details: details);
  }

  Future<BehaviorExternalImportResult> importCalendarEvents({int days = 7}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(Duration(days: days));
    final rows = await BehaviorTrackingNativeBridge.queryCalendarEvents(start, end);
    var imported = 0;
    final details = <String>[];
    for (final row in rows.take(80)) {
      final record = _calendarRowToRecord(row);
      final item = _queueItem(sourceKey: 'calendar', externalId: 'calendar_${row['eventId']}_${row['startMs']}', title: record.title, raw: row, record: record, note: '系统日历导入：日历是计划，不等于实际发生。请确认后写入记录。');
      await _external.saveQueueItem(item);
      imported++;
      details.add('${row['title'] ?? '日历事件'} · ${record.timeRangeLabel}');
    }
    return BehaviorExternalImportResult(imported: imported, details: details);
  }


  Future<HealthConnectStatus> requestHealthReauthorization() async {
    final opened = await _health.openSettings();
    if (opened.available || opened.status != 'missing_plugin') return opened;
    return _health.requestPermissions();
  }

  Future<BehaviorTrackingRecord> syncHealthConnectToday() async {
    final permission = await _health.requestPermissions();
    final summary = await _health.readAndSaveToday();
    final record = BehaviorTrackingRecord.blank(mode: 'body_snapshot', templateKey: 'body_snapshot', entryMode: 'health_connect', primaryLayer: '身体状态层面').copyWith(
      title: 'Health Connect 身体数据',
      source: 'health_connect',
      category: '休息',
      bodyState: summary.compactText(),
      sleep: summary.sleepMinutes == null ? '' : '睡眠 ${_fmtMinutes(summary.sleepMinutes!)}',
      sleepDurationMin: summary.sleepMinutes,
      steps: summary.steps,
      exerciseMin: summary.exerciseMinutes,
      actualValue: summary.activeCalories,
      unit: summary.activeCalories == null ? '' : 'kcal',
      notes: 'Health Connect 状态：${summary.status}\n权限状态：${permission.status}${permission.message == null ? '' : '\n${permission.message}'}${summary.message == null ? '' : '\n${summary.message}'}',
      tags: ['Health Connect', '身体状态', if (summary.status.isNotEmpty) summary.status],
    );
    final id = await _records.save(record);
    return record.copyWith(id: id);
  }

  Future<BehaviorTrackingRecord> savePomodoroCompletion({required DateTime start, required DateTime end, required String project, int focusScore = 4, String notes = ''}) async {
    final duration = end.difference(start).inMinutes.clamp(1, 24 * 60).toInt();
    final record = BehaviorTrackingRecord.blank(mode: 'time_block', templateKey: 'pomodoro', entryMode: 'pomodoro_event_bus', primaryLayer: '时间层面').copyWith(
      recordDateMs: DateTime(start.year, start.month, start.day).millisecondsSinceEpoch,
      title: project.trim().isEmpty ? '番茄钟专注' : '番茄钟：${project.trim()}',
      source: 'pomodoro_event_bus',
      category: '工作/学习',
      projectKey: project.trim(),
      startMinute: start.hour * 60 + start.minute,
      endMinute: end.hour * 60 + end.minute,
      focusScore: focusScore,
      behavior: project.trim().isEmpty ? '完成一段专注会话' : '专注：${project.trim()}',
      actualValue: duration.toDouble(),
      unit: '分钟',
      shortTermResult: '完成 $duration 分钟专注。',
      notes: notes.trim(),
      tags: ['番茄钟', '专注', '事件总线', if (project.trim().isNotEmpty) project.trim()],
    );
    final id = await _records.save(record);
    final saved = record.copyWith(id: id);
    BehaviorPomodoroEventBus.emit(BehaviorPomodoroEvent.completed(saved));
    return saved;
  }


  Future<int> scheduleAutoSyncNextThirtyDays(List<BehaviorTrackingAutoSyncPlan> plans) async {
    final active = plans.where((p) => p.enabled).toList();
    var success = 0;
    final now = DateTime.now();
    for (final plan in active) {
      for (var i = 0; i < 30; i++) {
        final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
        var target = day.add(Duration(minutes: plan.timeMinute));
        if (target.isBefore(now.add(const Duration(seconds: 30)))) target = target.add(const Duration(days: 1));
        final idSeed = plan.sourceKey == 'screen_usage' ? 810000 : plan.sourceKey == 'calendar' ? 820000 : 830000;
        final ok = await NativeScheduler.scheduleExactAt(id: idSeed + i, epochMs: target.millisecondsSinceEpoch, payload: {
          'module': 'behavior_tracking',
          'type': 'behavior_auto_sync',
          'sourceKey': plan.sourceKey,
          'title': plan.title,
          'body': '已按配置自动读取 ${plan.title}，结果进入待确认队列。',
          'message': '已按配置自动读取 ${plan.title}，结果进入待确认队列。',
          'lookbackDays': plan.lookbackDays,
          'lookaheadDays': plan.lookaheadDays,
        });
        if (ok) success++;
      }
    }
    return success;
  }

  Future<int> scheduleNextSevenDays(List<BehaviorTrackingReminderPlan> plans) async {
    final active = plans.where((p) => p.enabled).toList();
    var success = 0;
    final now = DateTime.now();
    for (final plan in active) {
      for (var i = 0; i < 7; i++) {
        var day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
        var target = day.add(Duration(minutes: plan.timeMinute));
        if (target.isBefore(now.add(const Duration(seconds: 30)))) target = target.add(const Duration(days: 1));
        final id = 720000 + (plan.id ?? 0) * 31 + i;
        final ok = await NativeScheduler.scheduleExactAt(id: id, epochMs: target.millisecondsSinceEpoch, payload: {
          'module': 'behavior_tracking',
          'route': '/behavior_tracking',
          'title': plan.title,
          'body': plan.message,
          'message': plan.message,
          'templateKey': plan.templateKey,
          'entryMode': 'pure_tracking_reminder',
          'reminderId': plan.id,
        });
        if (ok) success++;
      }
    }
    return success;
  }

  BehaviorTrackingRecord _usageRowToRecord(Map<String, dynamic> row, DateTime day) {
    final app = (row['appName'] ?? row['packageName'] ?? '未知应用').toString();
    final totalMs = (row['totalTimeMs'] is num) ? (row['totalTimeMs'] as num).toInt() : int.tryParse('${row['totalTimeMs']}') ?? 0;
    final minutes = (totalMs / 60000).round().clamp(1, 24 * 60).toInt();
    return BehaviorTrackingRecord.blank(mode: 'time_block', templateKey: 'time_block', entryMode: 'screen_usage_import', primaryLayer: '时间层面').copyWith(
      recordDateMs: day.millisecondsSinceEpoch,
      title: '屏幕使用：$app',
      source: 'screen_usage',
      category: '屏幕使用时间',
      behavior: '使用应用：$app',
      actualValue: minutes.toDouble(),
      unit: '分钟',
      notes: '系统 UsageStatsManager 聚合时长：$minutes 分钟。包名：${row['packageName'] ?? ''}',
      tags: ['屏幕使用', app],
    );
  }

  BehaviorTrackingRecord _calendarRowToRecord(Map<String, dynamic> row) {
    final title = (row['title'] ?? '日历事件').toString();
    final startMs = _asInt(row['startMs']) ?? DateTime.now().millisecondsSinceEpoch;
    final endMs = _asInt(row['endMs']) ?? startMs;
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final end = DateTime.fromMillisecondsSinceEpoch(endMs);
    final sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
    return BehaviorTrackingRecord.blank(mode: 'time_block', templateKey: 'time_block', entryMode: 'calendar_import', primaryLayer: '时间层面').copyWith(
      recordDateMs: DateTime(start.year, start.month, start.day).millisecondsSinceEpoch,
      title: '日历：$title',
      source: 'calendar',
      category: '工作/学习',
      behavior: '日历时间块：$title',
      startMinute: start.hour * 60 + start.minute,
      endMinute: sameDay ? end.hour * 60 + end.minute : 23 * 60 + 59,
      notes: '系统日历导入。位置：${row['location'] ?? ''}\n说明：${row['description'] ?? ''}',
      tags: ['日历', '时间块', title],
    );
  }

  BehaviorImportQueueItem _queueItem({required String sourceKey, required String externalId, required String title, required Map<String, dynamic> raw, required BehaviorTrackingRecord record, required String note}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return BehaviorImportQueueItem(
      sourceKey: sourceKey,
      externalId: externalId,
      title: title,
      rawJson: const JsonEncoder.withIndent('  ').convert(raw),
      mappedRecordJson: const JsonEncoder.withIndent('  ').convert(record.toMap()),
      status: 'pending',
      note: note,
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '$m 分钟';
    if (m == 0) return '$h 小时';
    return '$h 小时$m 分钟';
  }
}

class BehaviorPomodoroEvent {
  final String type;
  final String message;
  final DateTime at;
  final BehaviorTrackingRecord? record;

  const BehaviorPomodoroEvent._(this.type, this.message, this.at, [this.record]);
  factory BehaviorPomodoroEvent.started(String project) => BehaviorPomodoroEvent._('started', '开始专注：${project.trim().isEmpty ? '未命名' : project.trim()}', DateTime.now());
  factory BehaviorPomodoroEvent.completed(BehaviorTrackingRecord record) => BehaviorPomodoroEvent._('completed', '完成并写入：${record.title}', DateTime.now(), record);
  factory BehaviorPomodoroEvent.cancelled(String project) => BehaviorPomodoroEvent._('cancelled', '取消专注：${project.trim().isEmpty ? '未命名' : project.trim()}', DateTime.now());
}

class BehaviorPomodoroEventBus {
  static final StreamController<BehaviorPomodoroEvent> _controller = StreamController<BehaviorPomodoroEvent>.broadcast();
  static Stream<BehaviorPomodoroEvent> get stream => _controller.stream;
  static void emit(BehaviorPomodoroEvent event) => _controller.add(event);
}

class BehaviorTrackingDataSourcesPage extends StatefulWidget {
  final Future<void> Function() onRecordsChanged;
  const BehaviorTrackingDataSourcesPage({super.key, required this.onRecordsChanged});

  @override
  State<BehaviorTrackingDataSourcesPage> createState() => _BehaviorTrackingDataSourcesPageState();
}

class _BehaviorTrackingDataSourcesPageState extends State<BehaviorTrackingDataSourcesPage> {
  final BehaviorTrackingExternalDao _dao = BehaviorTrackingExternalDao();
  final BehaviorTrackingExternalService _service = BehaviorTrackingExternalService();
  final TextEditingController _project = TextEditingController(text: '学习/工作专注');
  final TextEditingController _note = TextEditingController();

  List<BehaviorImportQueueItem> _pending = const [];
  List<BehaviorTrackingReminderPlan> _reminders = const [];
  List<BehaviorTrackingAutoSyncPlan> _autoPlans = const [];
  bool _loading = true;
  bool _usageAccess = false;
  bool _calendarPermission = false;
  bool _notificationPermission = false;
  String _status = '准备就绪。';
  DateTime? _pomodoroStart;
  int _focusScore = 4;
  StreamSubscription<BehaviorPomodoroEvent>? _pomodoroSub;
  final List<String> _pomodoroEvents = [];

  @override
  void initState() {
    super.initState();
    _pomodoroSub = BehaviorPomodoroEventBus.stream.listen((event) {
      if (!mounted) return;
      setState(() {
        _pomodoroEvents.insert(0, '${_fmtTime(event.at)} ${event.message}');
        if (_pomodoroEvents.length > 6) _pomodoroEvents.removeLast();
      });
    });
    _load();
  }

  @override
  void dispose() {
    _pomodoroSub?.cancel();
    _project.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _pending = await _dao.queue(status: 'pending');
      _reminders = await _dao.reminders();
      _autoPlans = await _dao.autoSyncPlans();
      _usageAccess = await BehaviorTrackingNativeBridge.hasUsageAccess();
      _calendarPermission = await BehaviorTrackingNativeBridge.hasCalendarPermission();
      _notificationPermission = await BehaviorTrackingNativeBridge.hasPostNotificationsPermission();
    } catch (e) {
      _status = '加载数据源状态失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _importUsage() async {
    setState(() => _status = '正在读取今日屏幕使用时间...');
    try {
      final result = await _service.importTodayScreenUsage();
      _status = result.imported == 0 ? '没有读取到可导入的屏幕使用记录，或使用时长低于阈值。' : '已生成 ${result.imported} 条待确认屏幕使用记录：\n${result.details.take(8).join('\n')}';
    } catch (e) {
      _status = '屏幕使用时间读取失败：$e';
    }
    await _load();
  }

  Future<void> _importCalendar() async {
    setState(() => _status = '正在读取未来7天系统日历...');
    try {
      final result = await _service.importCalendarEvents(days: 7);
      _status = result.imported == 0 ? '未来7天没有可导入的日历事件。' : '已生成 ${result.imported} 条待确认日历时间块：\n${result.details.take(8).join('\n')}';
    } catch (e) {
      _status = '系统日历读取失败：$e';
    }
    await _load();
  }

  Future<void> _syncHealth() async {
    setState(() => _status = '正在同步 Health Connect 今日身体数据...');
    try {
      final saved = await _service.syncHealthConnectToday();
      _status = '已生成身体状态记录：${saved.bodyState.isEmpty ? saved.title : saved.bodyState}';
      await widget.onRecordsChanged();
    } catch (e) {
      _status = 'Health Connect 同步失败：$e';
    }
    await _load();
  }


  Future<void> _reauthorizeHealth() async {
    setState(() => _status = '正在打开 Health Connect 授权管理页面...');
    try {
      final status = await _service.requestHealthReauthorization();
      _status = status.message ?? (status.granted ? 'Health Connect 权限已授权。' : '已打开或请求 Health Connect 权限，请返回后再次同步。');
    } catch (e) {
      _status = 'Health Connect 重新授权失败：$e';
    }
    await _load();
  }

  Future<void> _approve(BehaviorImportQueueItem item) async {
    if (item.id == null) return;
    final saved = await _dao.approveQueueItem(item.id!);
    _status = saved == null ? '确认失败：无法解析导入记录。' : '已确认并写入正式记录：${saved.title}';
    await widget.onRecordsChanged();
    await _load();
  }


  Future<void> _showQueueDetail(BehaviorImportQueueItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(item.title.isEmpty ? item.sourceKey : item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 6),
            Text('来源：${item.sourceKey}\n状态：${item.status}\n说明：${item.note}', style: const TextStyle(color: Color(0xFF64748B), height: 1.45)),
            const SizedBox(height: 12),
            const Text('映射后的行为记录', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            SelectableText(item.mappedRecordJson, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.35)),
            const SizedBox(height: 12),
            const Text('原始数据', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            SelectableText(item.rawJson, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.35)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(onPressed: () { Navigator.pop(ctx); _approve(item); }, icon: const Icon(Icons.check), label: const Text('确认写入')),
              TextButton.icon(onPressed: () { Navigator.pop(ctx); _reject(item); }, icon: const Icon(Icons.close), label: const Text('忽略')),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _reject(BehaviorImportQueueItem item) async {
    if (item.id == null) return;
    await _dao.rejectQueueItem(item.id!);
    _status = '已忽略：${item.title}';
    await _load();
  }

  Future<void> _approveAll() async {
    final count = await _dao.approveAllPending();
    _status = '已批量确认 $count 条导入记录。';
    await widget.onRecordsChanged();
    await _load();
  }

  Future<void> _rejectAll() async {
    final count = await _dao.rejectAllPending();
    _status = '已批量忽略 $count 条导入记录。';
    await _load();
  }

  Future<bool> _ensureReminderRuntimePermissions({bool openExactSettings = true}) async {
    if (!_notificationPermission) {
      await BehaviorTrackingNativeBridge.requestPostNotificationsPermission();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _notificationPermission = await BehaviorTrackingNativeBridge.hasPostNotificationsPermission();
    }
    if (!_notificationPermission) {
      _status = '通知权限未开启：请先允许通知，否则到点提醒不会弹出。';
      return false;
    }
    final canExact = await NativeScheduler.canScheduleExactAlarm();
    if (!canExact) {
      if (openExactSettings) {
        await NativeScheduler.requestExactAlarmPermission();
      }
      _status = '精确闹钟权限未开启：已尝试打开系统授权页。授权后请返回本页，重新点击“注册未来7天”。';
      return false;
    }
    return true;
  }

  Future<void> _createReminder() async {
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 22, minute: 0));
    if (time == null) return;
    final plan = BehaviorTrackingReminderPlan.defaultNight().copyWith(timeMinute: time.hour * 60 + time.minute);
    final savedId = await _dao.saveReminder(plan);
    final savedPlan = plan.copyWith(id: savedId);
    final okToSchedule = await _ensureReminderRuntimePermissions();
    if (!okToSchedule) {
      _status = '已保存提醒时间，但还没有真正注册系统闹钟。${_status.isEmpty ? '' : '\n$_status'}';
      await _load();
      return;
    }
    final count = await _service.scheduleNextSevenDays([savedPlan]);
    _status = count > 0
        ? '已创建并注册未来7天 $count 个行为观察提醒。到点后会弹出一条行为观察提醒，点击后用下拉框选择层面并填写表单。'
        : '已保存提醒时间，但注册系统闹钟失败。请检查精确闹钟权限、通知权限和系统省电限制。';
    await _load();
  }

  Future<void> _deleteReminder(BehaviorTrackingReminderPlan plan) async {
    if (plan.id == null) return;
    await _dao.deleteReminder(plan.id!);
    _status = '已删除提醒配置：${plan.title}';
    await _load();
  }

  Future<void> _registerReminders() async {
    final okToSchedule = await _ensureReminderRuntimePermissions();
    if (!okToSchedule) {
      setState(() {});
      await _load();
      return;
    }
    final count = await _service.scheduleNextSevenDays(_reminders);
    _status = count > 0 ? '已注册未来7天 $count 个行为观察提醒。到点会弹出一条行为观察提醒，点击后用下拉框选择层面并填写表单。' : '没有成功注册提醒。请检查通知/精确闹钟权限、原生通道或系统省电限制。';
    await _load();
  }


  Future<void> _changeAutoSyncTime(BehaviorTrackingAutoSyncPlan plan) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: plan.timeMinute ~/ 60, minute: plan.timeMinute % 60),
    );
    if (picked == null) return;
    await _dao.saveAutoSyncPlan(plan.copyWith(timeMinute: picked.hour * 60 + picked.minute));
    _status = '已更新${plan.title}时间：${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}。请点击“注册每日自动读取”让系统闹钟生效。';
    await _load();
  }

  Future<void> _toggleAutoSync(BehaviorTrackingAutoSyncPlan plan, bool enabled) async {
    await _dao.saveAutoSyncPlan(plan.copyWith(enabled: enabled));
    _status = enabled ? '已启用${plan.title}。请点击“注册每日自动读取”。' : '已关闭${plan.title}。已注册的旧闹钟可能需等待过期或在系统中取消。';
    await _load();
  }

  Future<void> _registerAutoSync() async {
    final canExact = await NativeScheduler.canScheduleExactAlarm();
    if (!canExact) {
      await NativeScheduler.requestExactAlarmPermission();
      _status = '精确闹钟权限未开启：已尝试打开系统授权页。授权后请返回本页，重新点击“注册每日自动读取”。';
      await _load();
      return;
    }
    final count = await _service.scheduleAutoSyncNextThirtyDays(_autoPlans);
    _status = count > 0
        ? '已注册未来30天 $count 个自动读取任务。到点后会自动读取已启用的数据源，并进入待确认队列。'
        : '没有成功注册自动读取任务。请先启用至少一个数据源，并检查精确闹钟权限。';
    await _load();
  }

  Future<void> _requestDesktopWidget() async {
    final ok = await BehaviorTrackingNativeBridge.requestPinBehaviorObservationWidget();
    setState(() {
      _status = ok
          ? '已向系统桌面发起添加“行为观察”小组件请求。添加后在桌面点选层面，会直接打开对应的轻量表单。'
          : '当前桌面或系统不支持应用内添加小组件。可长按桌面空白处 → 小组件 → 找到“名人名言/行为观察”手动添加。';
    });
  }

  Future<void> _showQuickRecordNotification() async {
    if (!_notificationPermission) {
      await BehaviorTrackingNativeBridge.requestPostNotificationsPermission();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _notificationPermission = await BehaviorTrackingNativeBridge.hasPostNotificationsPermission();
    }
    final ok = await BehaviorTrackingNativeBridge.showBehaviorObservationQuickRecordNotification();
    setState(() {
      _status = ok
          ? '已弹出行为观察提醒通知。点击通知或按钮后，会直接进入轻量记录表单。'
          : '未能弹出快捷记录通知。请检查通知权限或原生通道。';
    });
    await _load();
  }

  Future<void> _startPomodoro() async {
    final project = _project.text.trim().isEmpty ? '专注会话' : _project.text.trim();
    setState(() {
      _pomodoroStart = DateTime.now();
      _status = '已发出番茄钟 started 事件。';
    });
    BehaviorPomodoroEventBus.emit(BehaviorPomodoroEvent.started(project));
  }

  Future<void> _completePomodoro() async {
    final start = _pomodoroStart;
    if (start == null) return;
    final saved = await _service.savePomodoroCompletion(start: start, end: DateTime.now(), project: _project.text, focusScore: _focusScore, notes: _note.text);
    setState(() {
      _pomodoroStart = null;
      _status = '番茄钟完成，已写入正式行为记录：${saved.title}';
    });
    await widget.onRecordsChanged();
  }

  void _cancelPomodoro() {
    final project = _project.text.trim().isEmpty ? '专注会话' : _project.text.trim();
    setState(() {
      _pomodoroStart = null;
      _status = '已取消本次专注，只发送事件，不写入记录。';
    });
    BehaviorPomodoroEventBus.emit(BehaviorPomodoroEvent.cancelled(project));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 96), children: [
        _DataHero(pending: _pending.length, reminders: _reminders.length, usageAccess: _usageAccess, calendarPermission: _calendarPermission),
        const SizedBox(height: 12),
        _DataCard(title: '每日自动读取配置', subtitle: '可为真实屏幕使用时间、系统日历、健康数据分别设置每天自动读取时间；结果仍先进入待确认队列。', icon: Icons.sync_lock_outlined, children: [
          if (_autoPlans.isEmpty) const _DataLine('暂无自动读取计划。') else for (final plan in _autoPlans) _AutoSyncTile(plan: plan, onToggle: (v) => _toggleAutoSync(plan, v), onChangeTime: () => _changeAutoSyncTime(plan)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: _autoPlans.any((p) => p.enabled) ? _registerAutoSync : null, icon: const Icon(Icons.alarm_on_outlined), label: const Text('注册每日自动读取')),
            TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('刷新配置')),
          ]),
          const _DataLine('说明：自动读取只负责采集证据，不直接写入正式行为记录；用户确认后才保存。'),
        ]),
        const SizedBox(height: 12),
        _DataCard(title: '待确认导入队列', subtitle: '屏幕使用、日历和健康数据都先进入这里，确认后才写入正式行为记录。', icon: Icons.fact_check_outlined, children: [
          if (_pending.isEmpty) const _DataLine('暂无待确认导入记录。') else _DataLine('当前待确认：${_pending.length} 条'),
          if (_pending.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(onPressed: _approveAll, icon: const Icon(Icons.done_all), label: const Text('全部确认')),
              TextButton.icon(onPressed: _rejectAll, icon: const Icon(Icons.clear_all), label: const Text('全部忽略')),
            ]),
          for (final item in _pending.take(8)) _QueueTile(item: item, onTap: () => _showQueueDetail(item), onApprove: () => _approve(item), onReject: () => _reject(item)),
        ]),
        const SizedBox(height: 12),
        _DataCard(title: '真实屏幕使用时间读取', subtitle: '读取 Android UsageStatsManager 的今日应用使用时长，只作为时间/行为证据。', icon: Icons.phone_android_outlined, children: [
          _DataLine(_usageAccess ? '权限状态：已授权。' : '权限状态：未授权，需要系统设置中打开“使用情况访问权限”。'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(onPressed: BehaviorTrackingNativeBridge.openUsageAccessSettings, icon: const Icon(Icons.settings_outlined), label: const Text('打开授权设置')),
            FilledButton.icon(onPressed: _usageAccess ? _importUsage : null, icon: const Icon(Icons.download_outlined), label: const Text('导入今日使用')),
            TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('刷新')),
          ]),
        ]),
        const SizedBox(height: 12),
        _DataCard(title: '真实系统日历读取', subtitle: '读取未来7天日历事件，作为计划时间块；确认后才成为行为记录。', icon: Icons.event_note_outlined, children: [
          _DataLine(_calendarPermission ? '权限状态：已获得日历读取权限。' : '权限状态：未获得日历读取权限。'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(onPressed: () async { await BehaviorTrackingNativeBridge.requestCalendarPermission(); await Future<void>.delayed(const Duration(milliseconds: 500)); await _load(); }, icon: const Icon(Icons.event_available_outlined), label: const Text('请求日历权限')),
            FilledButton.icon(onPressed: _calendarPermission ? _importCalendar : null, icon: const Icon(Icons.download_for_offline_outlined), label: const Text('导入未来7天')),
            TextButton.icon(onPressed: BehaviorTrackingNativeBridge.openAppPermissionSettings, icon: const Icon(Icons.app_settings_alt_outlined), label: const Text('应用权限')),
          ]),
        ]),
        const SizedBox(height: 12),
        _DataCard(title: 'Health Connect 身体数据同步', subtitle: '同步睡眠、步数、运动等身体状态，生成一条身体快照记录。', icon: Icons.health_and_safety_outlined, children: [
          const _DataLine('身体数据只用于行为观察中的“身体状态层面”，不生成干预建议。'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(onPressed: _reauthorizeHealth, icon: const Icon(Icons.verified_user_outlined), label: const Text('重新授权')),
            FilledButton.icon(onPressed: _syncHealth, icon: const Icon(Icons.sync_outlined), label: const Text('同步今日身体数据')),
          ]),
        ]),
        const SizedBox(height: 12),
        _DataCard(title: '记录提醒配置', subtitle: '提醒通知可直接选择观察层面并输入内容保存；不涉及行为改变或干预。', icon: Icons.notifications_active_outlined, children: [
          _DataLine(_notificationPermission ? '通知权限：已授权或当前系统无需运行时授权。' : '通知权限：未授权，Android 13+ 需要允许通知。'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(onPressed: _createReminder, icon: const Icon(Icons.add_alert_outlined), label: const Text('新增提醒')),
            FilledButton.icon(onPressed: _reminders.isEmpty ? null : _registerReminders, icon: const Icon(Icons.alarm_on_outlined), label: const Text('注册未来7天')),
            TextButton.icon(onPressed: _showQuickRecordNotification, icon: const Icon(Icons.reply_all_outlined), label: const Text('测试可填写通知')),
          ]),
          if (_reminders.isEmpty) const _DataLine('暂无提醒配置。') else for (final r in _reminders) _ReminderTile(plan: r, onDelete: () => _deleteReminder(r)),
        ]),
        const SizedBox(height: 12),
        _DataCard(title: '桌面小组件快速记录', subtitle: '把“行为观察”放到手机桌面，点选层面后直接进入对应轻量表单。', icon: Icons.widgets_outlined, children: [
          const _DataLine('小组件会显示七个观察层面。点击某个层面后直接打开对应的轻量记录表单，不再弹出一条通知。'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: _requestDesktopWidget, icon: const Icon(Icons.add_to_home_screen_outlined), label: const Text('添加桌面小组件')),
            TextButton.icon(onPressed: _showQuickRecordNotification, icon: const Icon(Icons.reply_all_outlined), label: const Text('先测试通知输入')),
          ]),
          const _DataLine('如果长按应用图标没有“小组件”入口，请长按桌面空白处 → 小组件/添加工具 → 名人名言 → 行为观察；也可优先使用上方“添加桌面小组件”按钮。不同桌面启动器入口名称可能不同。'),
        ]),
        const SizedBox(height: 12),
        _DataCard(title: '番茄钟事件总线', subtitle: '内部专注事件 started/completed/cancelled；完成后写入一条时间块记录。', icon: Icons.timer_outlined, children: [
          TextField(controller: _project, decoration: const InputDecoration(labelText: '专注项目', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Text('专注感：$_focusScore/5', style: const TextStyle(fontWeight: FontWeight.w800)),
          Slider(value: _focusScore.toDouble(), min: 1, max: 5, divisions: 4, label: '$_focusScore', onChanged: (v) => setState(() => _focusScore = v.round())),
          TextField(controller: _note, decoration: const InputDecoration(labelText: '备注（可选）', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 10),
          _DataLine(_pomodoroStart == null ? '当前没有进行中的专注。' : '进行中：${_fmtTime(_pomodoroStart!)} 开始。'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: _pomodoroStart == null ? _startPomodoro : null, icon: const Icon(Icons.play_arrow), label: const Text('开始')),
            FilledButton.tonalIcon(onPressed: _pomodoroStart == null ? null : _completePomodoro, icon: const Icon(Icons.check_circle_outline), label: const Text('完成并记录')),
            TextButton.icon(onPressed: _pomodoroStart == null ? null : _cancelPomodoro, icon: const Icon(Icons.close), label: const Text('取消')),
          ]),
          if (_pomodoroEvents.isEmpty) const _DataLine('暂无番茄钟事件。') else for (final e in _pomodoroEvents) _DataLine('• $e'),
        ]),
        const SizedBox(height: 12),
        _DataCard(title: '当前状态', subtitle: '用于确认功能是否生效。', icon: Icons.info_outline, children: [SelectableText(_status, style: const TextStyle(color: Color(0xFF334155), height: 1.45))]),
      ]),
    );
  }

  String _fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _DataHero extends StatelessWidget {
  final int pending;
  final int reminders;
  final bool usageAccess;
  final bool calendarPermission;
  const _DataHero({required this.pending, required this.reminders, required this.usageAccess, required this.calendarPermission});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x22111827), blurRadius: 24, offset: Offset(0, 12))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('数据源与提醒', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('保留真实接入能力，但只服务于“行为观察”：导入证据、同步身体状态、提醒记录。', style: TextStyle(color: Color(0xFFCBD5E1), height: 1.4)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _HeroPill('待确认 $pending'),
            _HeroPill('提醒 $reminders'),
            _HeroPill(usageAccess ? '屏幕已授权' : '屏幕未授权'),
            _HeroPill(calendarPermission ? '日历已授权' : '日历未授权'),
          ]),
        ]),
      );
}

class _HeroPill extends StatelessWidget {
  final String text;
  const _HeroPill(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.14))),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

class _DataCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  const _DataCard({required this.title, required this.subtitle, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFF2563EB))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
            ])),
          ]),
          const SizedBox(height: 12),
          ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)),
        ]),
      );
}

class _DataLine extends StatelessWidget {
  final String text;
  const _DataLine(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: Color(0xFF475569), height: 1.45));
}

class _QueueTile extends StatelessWidget {
  final BehaviorImportQueueItem item;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _QueueTile({required this.item, required this.onTap, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title.isEmpty ? item.sourceKey : item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${item.sourceKey} · ${item.note}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.35)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(onPressed: onApprove, icon: const Icon(Icons.check), label: const Text('确认')),
              TextButton.icon(onPressed: onReject, icon: const Icon(Icons.close), label: const Text('忽略')),
            ]),
            const SizedBox(height: 4),
            const Text('点击查看映射详情', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ]),
        ),
      );
}


class _AutoSyncTile extends StatelessWidget {
  final BehaviorTrackingAutoSyncPlan plan;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChangeTime;
  const _AutoSyncTile({required this.plan, required this.onToggle, required this.onChangeTime});

  @override
  Widget build(BuildContext context) {
    final source = plan.sourceKey == 'screen_usage' ? '真实屏幕使用时间' : plan.sourceKey == 'calendar' ? '真实系统日历' : plan.sourceKey == 'health_connect' ? 'Health Connect 健康数据' : plan.sourceKey;
    final range = plan.sourceKey == 'calendar' ? '读取未来 ${plan.lookaheadDays} 天' : '读取当天使用统计';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Switch(value: plan.enabled, onChanged: onToggle),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(source, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('${plan.enabled ? '已启用' : '未启用'} · 每天 ${plan.timeLabel} · $range', style: const TextStyle(color: Color(0xFF64748B), height: 1.35)),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: onChangeTime, icon: const Icon(Icons.schedule_outlined), label: const Text('修改同步时间'))),
        ])),
      ]),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final BehaviorTrackingReminderPlan plan;
  final VoidCallback onDelete;
  const _ReminderTile({required this.plan, required this.onDelete});
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.notifications_none_outlined),
        title: Text('${plan.timeLabel} · ${plan.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${plan.message}\n模板：${plan.templateKey}', style: const TextStyle(height: 1.3)),
        trailing: IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
      );
}
