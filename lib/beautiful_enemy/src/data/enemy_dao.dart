import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'enemy_schema.dart';
import 'models.dart';

/// 设置项的键。全部落在 be_setting，不碰宿主的配置表。
class EnemySettings {
  const EnemySettings._();

  /// 用户设定的档位 1..3，默认 2。
  static const String intensity = 'intensity';
  static const String quietStartHour = 'quiet_start_hour';
  static const String quietEndHour = 'quiet_end_hour';
  static const String dailyCap = 'daily_cap';

  /// 休战日：DateTime.monday..sunday（1..7），0 表示没有休战日。
  static const String truceWeekday = 'truce_weekday';

  /// 静音到什么时候（毫秒）。安全阀触发或用户点「停战」时写入。
  static const String mutedUntilMs = 'muted_until_ms';

  /// 用户点「太过了」的时间。
  static const String tooMuchAtMs = 'too_much_at_ms';

  /// 敌人怎么称呼你。默认「对手」。
  static const String address = 'address';

  /// 敌人的声音：用 TTS 念出来。默认关。
  static const String voiceOut = 'voice_out';

  /// 允许敌人随着你的行为实时插话（总开关，默认开）。
  static const String interject = 'interject';

  /// 在 App 的其它页面里，也允许它用通知插话（默认开）。
  static const String interjectEverywhere = 'interject_everywhere';

  /// 每天最多插话几次。
  static const String interjectCap = 'interject_cap';

  static const String lastInterjectMs = 'last_interject_ms';

  /// 已经「看过」的最大事件 id；之后新增的事件才会触发插话。
  static const String reactCursor = 'react_cursor';

  static String warned(int commitmentId) => 'warned_$commitmentId';

  /// 主动巡查（晨报 / 晚间结算 / 发呆提醒）的总开关，默认开。
  static const String patrol = 'patrol';

  /// 晚间结算的整点，默认 20 点。
  static const String patrolHour = 'patrol_hour';

  /// 某一类巡查今天是否已经做过。
  static String patrolDone(String kind, String day) => 'patrol_${kind}_$day';
  static const String patrolStallMs = 'patrol_stall_ms';

  /// App 在前台时每次心跳写入；后台巡查据此避免和前台重复开口。
  static const String heartbeatMs = 'foreground_heartbeat_ms';

  /// 自检用：敌人最近一次「看了一眼」的时间，和它这次为什么没开口 / 开了口。
  static const String lastStepMs = 'last_step_ms';
  static const String lastWhy = 'last_why';

  /// 自检用：后台巡查任务的登记结果与最近一次运行。
  static const String bgScheduledMs = 'bg_scheduled_ms';
  static const String bgScheduleError = 'bg_schedule_error';
  static const String bgLastRunMs = 'bg_last_run_ms';
  static const String bgLastNote = 'bg_last_note';

  static const String dailyNotify = 'daily_notify';
  static const String dailyNotifyHour = 'daily_notify_hour';
  static const String crisisNoticePending = 'crisis_notice_pending';

  /// 某个来源是否授权采集。缺省为未授权。
  static String consent(String source) => 'consent_$source';
}

class EnemyDao {
  EnemyDao(this.db);

  final Database db;

  Future<void> ensureSchema() => EnemySchema.createAll(db);

  // ---------------------------------------------------------------- settings

  Future<String?> getSetting(String key) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_setting',
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert(
      'be_setting',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> intSetting(String key, int fallback) async {
    final String? raw = await getSetting(key);
    return int.tryParse(raw ?? '') ?? fallback;
  }

  Future<bool> boolSetting(String key, {bool fallback = false}) async {
    final String? raw = await getSetting(key);
    if (raw == null) return fallback;
    return raw == '1';
  }

  Future<void> setBoolSetting(String key, bool value) =>
      setSetting(key, value ? '1' : '0');

  // ------------------------------------------------------------------ events

  /// 写入一条事件；同一个 dedupeKey 已存在时返回 null。
  Future<int?> insertEvent(EventDraft draft) async {
    final int id = await db.insert(
      'be_event',
      <String, Object?>{
        'ts': draft.ts,
        'source': draft.source,
        'type': draft.type,
        'payload': jsonEncode(draft.payload),
        'dedupe_key': draft.dedupeKey,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return id > 0 ? id : null;
  }

  Future<List<EnemyEvent>> eventsBetween(
    int fromMs,
    int toMs, {
    String? source,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_event',
      where: source == null ? 'ts >= ? AND ts < ?' : 'ts >= ? AND ts < ? AND source = ?',
      whereArgs: source == null
          ? <Object?>[fromMs, toMs]
          : <Object?>[fromMs, toMs, source],
      orderBy: 'ts ASC, id ASC',
    );
    return rows.map(EnemyEvent.fromMap).toList();
  }

  Future<List<EnemyEvent>> eventsByIds(List<int> ids) async {
    if (ids.isEmpty) return <EnemyEvent>[];
    final String marks = List<String>.filled(ids.length, '?').join(',');
    final List<Map<String, Object?>> rows = await db.query(
      'be_event',
      where: 'id IN ($marks)',
      whereArgs: ids.cast<Object?>(),
      orderBy: 'ts ASC',
    );
    return rows.map(EnemyEvent.fromMap).toList();
  }

  Future<List<EnemyEvent>> recentEvents({int limit = 200, String? source}) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_event',
      where: source == null ? null : 'source = ?',
      whereArgs: source == null ? null : <Object?>[source],
      orderBy: 'ts DESC, id DESC',
      limit: limit,
    );
    return rows.map(EnemyEvent.fromMap).toList();
  }

  Future<int> maxEventId() async {
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COALESCE(MAX(id), 0) AS m FROM be_event');
    return (rows.first['m'] as num?)?.toInt() ?? 0;
  }

  Future<List<EnemyEvent>> eventsAfterId(int afterId, {int limit = 100}) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_event',
      where: 'id > ?',
      whereArgs: <Object?>[afterId],
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(EnemyEvent.fromMap).toList();
  }

  Future<int> eventCount({int? sinceMs}) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      sinceMs == null
          ? 'SELECT COUNT(*) AS c FROM be_event'
          : 'SELECT COUNT(*) AS c FROM be_event WHERE ts >= ?',
      sinceMs == null ? null : <Object?>[sinceMs],
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> eventCountsBySource() async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT source, COUNT(*) AS c FROM be_event GROUP BY source',
    );
    return <String, int>{
      for (final Map<String, Object?> r in rows)
        (r['source'] ?? '').toString(): (r['c'] as num?)?.toInt() ?? 0,
    };
  }

  Future<int> deleteEventsBySource(String source) => db.delete(
        'be_event',
        where: 'source = ?',
        whereArgs: <Object?>[source],
      );

  Future<int> deleteAllEvents() => db.delete('be_event');

  // ------------------------------------------------------------- commitments

  Future<int> insertCommitment({
    required String text,
    required int createdMs,
    int? dueMs,
    String origin = 'manual',
    int? verdictId,
    String stake = '',
  }) {
    return db.insert('be_commitment', <String, Object?>{
      'text': text,
      'created_ms': createdMs,
      'due_ms': dueMs,
      'status': CommitmentStatus.open,
      'origin': origin,
      'verdict_id': verdictId,
      'stake': stake,
    });
  }

  Future<EnemyCommitment?> commitment(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_commitment',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : EnemyCommitment.fromMap(rows.first);
  }

  Future<List<EnemyCommitment>> commitments({String? status, int limit = 200}) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_commitment',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : <Object?>[status],
      orderBy: 'COALESCE(due_ms, created_ms) DESC, id DESC',
      limit: limit,
    );
    return rows.map(EnemyCommitment.fromMap).toList();
  }

  Future<List<EnemyCommitment>> overdueOpen(int nowMs) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_commitment',
      where: "status = 'open' AND due_ms IS NOT NULL AND due_ms < ?",
      whereArgs: <Object?>[nowMs],
      orderBy: 'due_ms ASC',
    );
    return rows.map(EnemyCommitment.fromMap).toList();
  }

  Future<List<EnemyCommitment>> commitmentsSince(int sinceMs) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_commitment',
      where: 'COALESCE(due_ms, created_ms) >= ?',
      whereArgs: <Object?>[sinceMs],
      orderBy: 'COALESCE(due_ms, created_ms) ASC',
    );
    return rows.map(EnemyCommitment.fromMap).toList();
  }

  Future<void> setCommitmentStatus(int id, String status) async {
    await db.update(
      'be_commitment',
      <String, Object?>{'status': status},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  // ---------------------------------------------------------------- verdicts

  Future<int> insertVerdict({
    required int ts,
    required String trigger,
    required int intensity,
    required String charge,
    required List<int> evidenceIds,
    required String lessonHint,
    required String action,
    required int actionDueMs,
    required String appealPrompt,
    required bool factOnly,
  }) {
    return db.insert('be_verdict', <String, Object?>{
      'ts': ts,
      'trigger': trigger,
      'intensity': intensity,
      'charge': charge,
      'evidence_ids': jsonEncode(evidenceIds),
      'lesson_hint': lessonHint,
      'action': action,
      'action_due_ms': actionDueMs,
      'appeal_prompt': appealPrompt,
      'fact_only': factOnly ? 1 : 0,
    });
  }

  Future<EnemyVerdict?> verdict(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_verdict',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : EnemyVerdict.fromMap(rows.first);
  }

  Future<EnemyVerdict?> latestVerdict() async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_verdict',
      orderBy: 'ts DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : EnemyVerdict.fromMap(rows.first);
  }

  Future<List<EnemyVerdict>> recentVerdicts({int limit = 30}) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_verdict',
      orderBy: 'ts DESC, id DESC',
      limit: limit,
    );
    return rows.map(EnemyVerdict.fromMap).toList();
  }

  Future<List<EnemyVerdict>> verdictsSince(int sinceMs) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_verdict',
      where: 'ts >= ?',
      whereArgs: <Object?>[sinceMs],
      orderBy: 'ts DESC, id DESC',
    );
    return rows.map(EnemyVerdict.fromMap).toList();
  }

  Future<void> setVerdictResponse(
    int id,
    String response, {
    String appealText = '',
  }) async {
    await db.update(
      'be_verdict',
      <String, Object?>{'user_response': response, 'appeal_text': appealText},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> setVerdictOutcome(int id, String outcome, int ms) async {
    await db.update(
      'be_verdict',
      <String, Object?>{'outcome': outcome, 'outcome_ms': ms},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> linkVerdictCommitment(int verdictId, int commitmentId) async {
    await db.update(
      'be_verdict',
      <String, Object?>{'commitment_id': commitmentId},
      where: 'id = ?',
      whereArgs: <Object?>[verdictId],
    );
  }

  // ----------------------------------------------------------------- lessons

  /// 同类别在 [withinMs] 内已有教训时只累加次数，否则新增一条。
  Future<EnemyLesson> addOrBumpLesson({
    required int? verdictId,
    required String category,
    required String reasonText,
    required String lesson,
    required int nowMs,
    int withinMs = 30 * 24 * 3600 * 1000,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_lesson',
      where: 'category = ? AND created_ms >= ?',
      whereArgs: <Object?>[category, nowMs - withinMs],
      orderBy: 'created_ms DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final EnemyLesson old = EnemyLesson.fromMap(rows.first);
      await db.update(
        'be_lesson',
        <String, Object?>{
          'times_repeated': old.timesRepeated + 1,
          'reason_text': reasonText,
          'lesson': lesson,
          'verdict_id': verdictId,
          'created_ms': nowMs,
        },
        where: 'id = ?',
        whereArgs: <Object?>[old.id],
      );
      return EnemyLesson(
        id: old.id,
        verdictId: verdictId,
        category: category,
        reasonText: reasonText,
        lesson: lesson,
        createdMs: nowMs,
        timesRepeated: old.timesRepeated + 1,
      );
    }
    final int id = await db.insert('be_lesson', <String, Object?>{
      'verdict_id': verdictId,
      'category': category,
      'reason_text': reasonText,
      'lesson': lesson,
      'created_ms': nowMs,
      'times_repeated': 1,
    });
    return EnemyLesson(
      id: id,
      verdictId: verdictId,
      category: category,
      reasonText: reasonText,
      lesson: lesson,
      createdMs: nowMs,
      timesRepeated: 1,
    );
  }

  Future<List<EnemyLesson>> lessons({int limit = 100}) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_lesson',
      orderBy: 'created_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(EnemyLesson.fromMap).toList();
  }

  Future<EnemyLesson?> latestLesson() async {
    final List<EnemyLesson> all = await lessons(limit: 1);
    return all.isEmpty ? null : all.first;
  }

  // ------------------------------------------------------------------- usage

  /// 记一分钟 App 前台时间。只存计数，不存任何内容。
  Future<void> addUsageMinute({
    required String day,
    required bool lateNight,
    required int nowMs,
  }) async {
    await setSetting('usage_min_$day', '${await intSetting('usage_min_$day', 0) + 1}');
    if (lateNight) {
      await setSetting('usage_late_$day', '${await intSetting('usage_late_$day', 0) + 1}');
    }
    if (await getSetting('usage_first_$day') == null) {
      await setSetting('usage_first_$day', '$nowMs');
    }
  }

  Future<({int minutes, int lateNight, int firstMs})> usageFor(String day) async {
    return (
      minutes: await intSetting('usage_min_$day', 0),
      lateNight: await intSetting('usage_late_$day', 0),
      firstMs: await intSetting('usage_first_$day', 0),
    );
  }

  // ---------------------------------------------------------------- messages

  Future<int> insertMessage({
    required int ts,
    required String role,
    required String kind,
    required String text,
    int? refId,
    int tone = 0,
  }) {
    return db.insert('be_message', <String, Object?>{
      'ts': ts,
      'role': role,
      'kind': kind,
      'text': text,
      'ref_id': refId,
      'tone': tone,
    });
  }

  /// 最近 [limit] 条，按时间从旧到新返回（直接可用于从上到下显示）。
  Future<List<EnemyMessage>> recentMessages({int limit = 80}) async {
    final List<Map<String, Object?>> rows = await db.query(
      'be_message',
      orderBy: 'ts DESC, id DESC',
      limit: limit,
    );
    return rows.reversed.map(EnemyMessage.fromMap).toList();
  }

  Future<int> messageCount({String? kind, int? sinceMs}) async {
    final List<String> where = <String>[];
    final List<Object?> args = <Object?>[];
    if (kind != null) {
      where.add('kind = ?');
      args.add(kind);
    }
    if (sinceMs != null) {
      where.add('ts >= ?');
      args.add(sinceMs);
    }
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM be_message'
      '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}',
      args,
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  // ------------------------------------------------------------------- clear

  /// 只清证据（案卷）。判词、承诺、教训保留。
  Future<void> clearEvidence() => deleteAllEvents();

  /// 清空模块的全部数据（设置保留）。
  Future<void> wipeEverything() async {
    await db.delete('be_event');
    await db.delete('be_commitment');
    await db.delete('be_verdict');
    await db.delete('be_lesson');
    await db.delete('be_message');
  }
}
