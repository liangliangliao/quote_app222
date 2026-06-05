import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// A lightweight data access object for sport plans and records.
///
/// The sport tables store user configured exercise plans (sport_plans)
/// and historical workout sessions (sport_records).  All fields are
/// optional to simplify migrations; consumers should perform null checks
/// where appropriate.  This DAO exposes basic CRUD operations and hides
/// the underlying SQLite details.
class SportDao {
  /// Fetch all sport plans ordered by descending id (latest first).
  Future<List<Map<String, dynamic>>> getPlans() async {
    final db = await AppDatabase.instance();
    return db.query('sport_plans', orderBy: 'id DESC');
  }

  /// Load a single plan by id. Returns null if not found.
  Future<Map<String, dynamic>?> getPlan(int id) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('sport_plans', where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Insert a new plan. Returns the new row id.
  Future<int> insertPlan(Map<String, dynamic> data) async {
    final db = await AppDatabase.instance();
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    return db.insert('sport_plans', data);
  }

  /// Update an existing plan. Returns the number of affected rows.
  Future<int> updatePlan(int id, Map<String, dynamic> data) async {
    final db = await AppDatabase.instance();
    data['updated_at'] = DateTime.now().toIso8601String();
    return db.update('sport_plans', data, where: 'id=?', whereArgs: [id]);
  }

  /// Delete a plan by id. Returns the number of affected rows.
  Future<int> deletePlan(int id) async {
    final db = await AppDatabase.instance();
    return db.delete('sport_plans', where: 'id=?', whereArgs: [id]);
  }

  /// Fetch all sport records ordered by descending id (latest first).
  Future<List<Map<String, dynamic>>> getRecords() async {
    final db = await AppDatabase.instance();
    return db.query('sport_records', orderBy: 'id DESC');
  }

  /// Fetch records associated with a particular plan id.
  Future<List<Map<String, dynamic>>> getRecordsByPlan(int planId) async {
    final db = await AppDatabase.instance();
    return db.query('sport_records', where: 'plan_id=?', whereArgs: [planId], orderBy: 'id DESC');
  }

  /// Insert a new record. Returns the new row id.
  Future<int> insertRecord(Map<String, dynamic> data) async {
    final db = await AppDatabase.instance();
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    return db.insert('sport_records', data);
  }

  /// Update a record by id. Returns the number of affected rows.
  Future<int> updateRecord(int id, Map<String, dynamic> data) async {
    final db = await AppDatabase.instance();
    data['updated_at'] = DateTime.now().toIso8601String();
    return db.update('sport_records', data, where: 'id=?', whereArgs: [id]);
  }

  /// Delete a record by id. Returns the number of affected rows.
  Future<int> deleteRecord(int id) async {
    final db = await AppDatabase.instance();
    return db.delete('sport_records', where: 'id=?', whereArgs: [id]);
  }

  /// Load a single record by id. Returns null if not found.
  Future<Map<String, dynamic>?> getRecord(int id) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('sport_records', where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Return the record id for a specific plan instance (plan_id + plan_time).
  ///
  /// Used to avoid inserting duplicate records when the plan time is reached
  /// while the app is in foreground.
  Future<int?> getRecordIdForPlanInstance(int planId, String planTimeIso) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'sport_records',
      columns: ['id'],
      where: 'plan_id=? AND plan_time=?',
      whereArgs: [planId, planTimeIso],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final id = rows.first['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse(id?.toString() ?? '');
  }

  /// Fetch the latest unfinished record (not_started/in_progress/paused/stopped/queued).
  ///
  /// If [planId] is provided, filters to that plan.
  ///
  /// Note: records with status `queued` are treated as unfinished for
  /// plan status purposes, but they are not considered active when
  /// determining concurrency (see [getLatestActiveRecord]).
  Future<Map<String, dynamic>?> getLatestUnfinishedRecord({int? planId}) async {
    final db = await AppDatabase.instance();
    final where = planId == null
        ? "status IN ('not_started','in_progress','paused','stopped','queued')"
        : "plan_id=? AND status IN ('not_started','in_progress','paused','stopped','queued')";
    final whereArgs = planId == null ? null : [planId];
    final rows = await db.query(
      'sport_records',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Fetch the latest active record (not_started/in_progress/paused) optionally excluding a record.
  ///
  /// This is used to detect if there is an existing running or paused
  /// session. Records marked `queued` or other states such as
  /// completed/stopped/expired/canceled are ignored.  If
  /// [excludeRecordId] is provided, that record is ignored in the
  /// search (useful when checking whether starting/resuming a
  /// particular record would conflict with another active session).
  Future<Map<String, dynamic>?> getLatestActiveRecord({int? excludeRecordId}) async {
    final db = await AppDatabase.instance();
    final clause = excludeRecordId == null
        ? "status IN ('not_started','in_progress','paused')"
        : "status IN ('not_started','in_progress','paused') AND id!=?";
    final args = excludeRecordId == null ? null : [excludeRecordId];
    final rows = await db.query(
      'sport_records',
      where: clause,
      whereArgs: args,
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Check if there exists any active record (not_started/in_progress/paused)
  /// optionally excluding a given record id.
  Future<bool> hasActiveRecord({int? excludeRecordId}) async {
    final r = await getLatestActiveRecord(excludeRecordId: excludeRecordId);
    return r != null;
  }

  /// Fetch the latest queued record. If [planId] is provided, filters to that plan.
  Future<Map<String, dynamic>?> getLatestQueuedRecord({int? planId}) async {
    final db = await AppDatabase.instance();
    final where = planId == null ? "status='queued'" : "plan_id=? AND status='queued'";
    final whereArgs = planId == null ? null : [planId];
    final rows = await db.query(
      'sport_records',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Fetch queued records ordered by queue time (FIFO).
  ///
  /// We use updated_at as the queue time (marking queued refreshes updated_at)
  /// and use id as a stable tie-breaker.
  Future<List<Map<String, dynamic>>> getQueuedRecordsOrdered({int? planId, int? limit}) async {
    final db = await AppDatabase.instance();
    final where = planId == null ? "status='queued'" : "plan_id=? AND status='queued'";
    final whereArgs = planId == null ? null : [planId];
    return db.query(
      'sport_records',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'updated_at ASC, id ASC',
      limit: limit,
    );
  }

  /// Return the earliest queued record (FIFO head).
  Future<Map<String, dynamic>?> getEarliestQueuedRecord({int? planId}) async {
    final rows = await getQueuedRecordsOrdered(planId: planId, limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Mark an existing record as queued and refresh its queue time.
  Future<void> markRecordQueued(int recordId) async {
    final db = await AppDatabase.instance();
    final nowIso = DateTime.now().toIso8601String();
    await db.update(
      'sport_records',
      {
        'status': 'queued',
        'start_time': null,
        'end_time': null,
        'updated_at': nowIso,
      },
      where: 'id=?',
      whereArgs: [recordId],
    );
  }

  /// Promote a queued record to prestart in_progress (start_time remains null).
  Future<void> promoteQueuedToPrestart(int recordId) async {
    final db = await AppDatabase.instance();
    final nowIso = DateTime.now().toIso8601String();
    await db.update(
      'sport_records',
      {
        'status': 'in_progress',
        'start_time': null,
        'end_time': null,
        'updated_at': nowIso,
      },
      where: 'id=?',
      whereArgs: [recordId],
    );
  }

  /// Fetch the latest paused record (used by the UI continue entry).
  Future<Map<String, dynamic>?> getLatestPausedRecord({required int planId}) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'sport_records',
      where: 'plan_id=? AND status=?',
      whereArgs: [planId, 'paused'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// When the app process is killed, any in_progress record should be treated as paused.
  Future<void> markInProgressAsPaused() async {
    final db = await AppDatabase.instance();
    final nowIso = DateTime.now().toIso8601String();
    // 1) Mark in-progress records as paused (process was killed)
    await db.update(
      'sport_records',
      {'status': 'paused', 'updated_at': nowIso},
      where: "status='in_progress'",
    );
    // 2) Sync linked plan status as paused as well (plan card should reflect the latest state)
    try {
      await db.rawUpdate(
        "UPDATE sport_plans SET status='paused', updated_at=? WHERE id IN (SELECT DISTINCT plan_id FROM sport_records WHERE status='paused' AND plan_id IS NOT NULL)",
        [nowIso],
      );
    } catch (_) {
      // ignore
    }
  }

  /// Update a plan's status (used to keep plan card status in sync with running records).
  Future<void> updatePlanStatus(int planId, String status) async {
    final db = await AppDatabase.instance();
    await db.update(
      'sport_plans',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id=?',
      whereArgs: [planId],
    );
  }

  /// Compute a plan's effective UI status from latest records and current time.
  ///
  /// This avoids stale plan.status when a plan repeats daily/weekly/monthly and
  /// the record table reflects the real latest state.
  Future<List<Map<String, dynamic>>> getPlansWithComputedStatus() async {
    final plans = await getPlans();
    final now = DateTime.now();
    for (final p in plans) {
      final pid = p['id'] as int?;
      if (pid == null) continue;

      // 1) Any unfinished record wins (paused/in_progress/stopped/not_started)
      final unfinished = await getLatestUnfinishedRecord(planId: pid);
      if (unfinished != null) {
        p['status'] = (unfinished['status'] ?? 'paused').toString();
        p['_unfinished_record_id'] = unfinished['id'];
        continue;
      }

      // 2) If latest record completed today -> completed
      try {
        final db = await AppDatabase.instance();
        final rows = await db.query(
          'sport_records',
          columns: ['status', 'plan_time', 'end_time'],
          where: 'plan_id=?',
          whereArgs: [pid],
          orderBy: 'id DESC',
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final r = rows.first;
          final st = (r['status'] ?? '').toString();
          if (st == 'completed') {
            final tIso = (r['plan_time'] ?? r['end_time'] ?? '').toString();
            final t = DateTime.tryParse(tIso);
            if (t != null && t.year == now.year && t.month == now.month && t.day == now.day) {
              p['status'] = 'completed';
              continue;
            }
          }
        }
      } catch (_) {
        // ignore and fall through
      }

      // 3) If plan_time already passed and there is no completed record today -> expired
      final ptIso = (p['plan_time'] ?? '').toString();
      final pt = DateTime.tryParse(ptIso);
      if (pt != null && pt.isBefore(now)) {
        p['status'] = 'expired';
      } else {
        p['status'] = 'not_started';
      }
    }
    return plans;
  }

  /// Meta key-value helpers (meta table exists since early versions).
  Future<String?> getMeta(String key) async {
    final db = await AppDatabase.instance();
    try {
      final rows = await db.query('meta', where: 'key=?', whereArgs: [key], limit: 1);
      if (rows.isEmpty) return null;
      return rows.first['value']?.toString();
    } catch (_) {
      // Some very old installs may not have the meta table (or it may be corrupted).
      // Create it defensively so sport plan renewal/status sync won't break plan listing.
      try {
        await db.execute('CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)');
      } catch (_) {
        // ignore
      }
      return null;
    }
  }

  Future<void> setMeta(String key, String value) async {
    final db = await AppDatabase.instance();
    // Ensure meta table exists before inserting.
    try {
      await db.execute('CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)');
    } catch (_) {
      // ignore
    }
    await db.insert(
      'meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Renew repeating plans when the day has changed (foreground safety net).
  ///
  /// The true midnight renewal is also implemented in native AlarmReceiver,
  /// but this ensures plans stay correct if the device blocks exact alarms.
  Future<void> renewPlansIfDayChanged() async {
    final now = DateTime.now();
    final dayKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final last = await getMeta('sport_plan_last_renew_day');
    if (last == dayKey) return;
    await _renewAllPlans(now);
    await setMeta('sport_plan_last_renew_day', dayKey);
  }

  Future<void> _renewAllPlans(DateTime now) async {
    final db = await AppDatabase.instance();
    final plans = await getPlans();
    for (final p in plans) {
      final pid = p['id'] as int?;
      if (pid == null) continue;
      // Skip renewal if there is an unfinished record.
      final unfinished = await getLatestUnfinishedRecord(planId: pid);
      if (unfinished != null) continue;
      final next = _computeNextTrigger(p, now);
      if (next == null) continue;
      try {
        await db.update(
          'sport_plans',
          {
            'plan_time': next.toIso8601String(),
            'status': 'not_started',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id=?',
          whereArgs: [pid],
        );
      } catch (_) {}
    }
  }

  DateTime? _computeNextTrigger(Map<String, dynamic> plan, DateTime now) {
    final repeatType = (plan['repeat_type'] ?? 'daily').toString();
    final detailStr = (plan['repeat_detail'] ?? '').toString();
    int hh = 9, mm = 0, ss = 0;
    Set<int> weekdays = {1, 2, 3, 4, 5, 6, 7};
    Set<int> monthdays = {};
    List<DateTime> customDates = [];
    try {
      if (detailStr.isNotEmpty) {
        final v = jsonDecode(detailStr);
        if (v is Map) {
          final time = v['time']?.toString();
          if (time != null && time.contains(':')) {
            final parts = time.split(':');
            if (parts.isNotEmpty) hh = int.tryParse(parts[0]) ?? hh;
            if (parts.length >= 2) mm = int.tryParse(parts[1]) ?? mm;
            if (parts.length >= 3) ss = int.tryParse(parts[2]) ?? ss;
          }
          if (repeatType == 'weekly' && v['weekdays'] is List) {
            weekdays = Set<int>.from(List<int>.from(v['weekdays']));
          }
          if (repeatType == 'monthly' && v['monthdays'] is List) {
            monthdays = Set<int>.from(List<int>.from(v['monthdays']));
          }
          if (repeatType == 'custom' && v['dates'] is List) {
            for (final s in List<String>.from(v['dates'])) {
              final d = DateTime.tryParse(s);
              if (d != null) customDates.add(DateTime(d.year, d.month, d.day));
            }
            customDates.sort((a, b) => a.compareTo(b));
          }
        }
      }
    } catch (_) {
      // ignore and fall back to plan_time's hms
      final pt = DateTime.tryParse((plan['plan_time'] ?? '').toString());
      if (pt != null) {
        hh = pt.hour;
        mm = pt.minute;
        ss = pt.second;
      }
    }

    DateTime at(int y, int mo, int d) => DateTime(y, mo, d, hh, mm, ss);

    if (repeatType == 'daily') {
      final today = at(now.year, now.month, now.day);
      return today.isAfter(now) ? today : today.add(const Duration(days: 1));
    }
    if (repeatType == 'weekly') {
      for (int i = 0; i < 14; i++) {
        final cand = at(now.year, now.month, now.day).add(Duration(days: i));
        if (!weekdays.contains(cand.weekday)) continue;
        if (cand.isAfter(now)) return cand;
      }
      return null;
    }
    if (repeatType == 'monthly') {
      for (int i = 0; i < 62; i++) {
        final cand = at(now.year, now.month, now.day).add(Duration(days: i));
        if (!monthdays.contains(cand.day)) continue;
        if (cand.isAfter(now)) return cand;
      }
      return null;
    }
    if (repeatType == 'custom') {
      for (final d in customDates) {
        final cand = at(d.year, d.month, d.day);
        if (cand.isAfter(now)) return cand;
      }
      return null;
    }
    // default: treat as daily
    final today = at(now.year, now.month, now.day);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// Fetch records for a plan within [startInclusive, endExclusive].
  Future<List<Map<String, dynamic>>> getRecordsByPlanBetween(
    int planId,
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final db = await AppDatabase.instance();
    return db.query(
      'sport_records',
      where: 'plan_id=? AND start_time>=? AND start_time<?',
      whereArgs: [planId, startInclusive.toIso8601String(), endExclusive.toIso8601String()],
      orderBy: 'start_time ASC',
    );
  }

  /// Aggregate summary for records between [startInclusive, endExclusive].
  /// If [planId] is provided, filters to that plan.
  Future<Map<String, dynamic>> getHistorySummary(
    DateTime startInclusive,
    DateTime endExclusive, {
    int? planId,
    String? mode, // plan / instant
  }) async {
    final db = await AppDatabase.instance();
    final List<String> cond = <String>['start_time>=?', 'start_time<?'];
    final List<Object?> args = <Object?>[startInclusive.toIso8601String(), endExclusive.toIso8601String()];

    if (planId != null) {
      cond.insert(0, 'plan_id=?');
      args.insert(0, planId);
    }
    if (mode != null && mode.isNotEmpty) {
      cond.add('mode=?');
      args.add(mode);
    }

    final where = cond.join(' AND ');
    final whereArgs = args;

    final rows = await db.rawQuery(
      'SELECT '
      'COUNT(*) AS total_count, '
      "SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END) AS completed_count, "
      'SUM(COALESCE(total_duration,0)) AS total_duration_sum, '
      'SUM(COALESCE(total_steps,0)) AS total_steps_sum, '
      'SUM(COALESCE(total_distance,0)) AS total_distance_sum '
      'FROM sport_records '
      'WHERE $where',
      whereArgs,
    );
    if (rows.isEmpty) {
      return {
        'total_count': 0,
        'completed_count': 0,
        'total_duration_sum': 0,
        'total_steps_sum': 0,
        'total_distance_sum': 0.0,
      };
    }
    return rows.first;
  }

  /// Get a random enabled sport quote from sport_quotes table.
  /// Returns null if table is empty.
  Future<Map<String, dynamic>?> getRandomSportQuote() async {
    final db = await AppDatabase.instance();
    try {
      final rows = await db.rawQuery(
        'SELECT content, author, explanation FROM sport_quotes WHERE enabled=1 ORDER BY RANDOM() LIMIT 1',
      );
      if (rows.isEmpty) return null;
      return rows.first;
    } catch (_) {
      // Table may not exist on very old installs (should be migrated by db.dart)
      return null;
    }
  }
}