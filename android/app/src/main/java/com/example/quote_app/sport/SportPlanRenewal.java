package com.example.quote_app.sport;

import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.text.TextUtils;

import com.example.quote_app.NativeSchedulerK;
import com.example.quote_app.data.DbInspector;
import com.example.quote_app.data.DbRepository;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Calendar;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

/**
 * Native sport plan renewal.
 *
 * Requirement:
 * - Renew repeating plans at 00:00:00 every day even if the Flutter process was killed.
 * - Sync plan status and reschedule sport_fullscreen / sport_reminder alarms.
 */
public final class SportPlanRenewal {
  private static final int MIDNIGHT_RENEW_ID = 1800000000;
  private static final int FULLSCREEN_BASE_ID = 1600000000;
  private static final int REMINDER_BASE_ID = 1700000000;

  private SportPlanRenewal() {}

  /** Schedule the next midnight renewal alarm (00:00:01). */
  public static void scheduleMidnightAlarm(Context ctx) {
    try {
      long next = nextMidnightEpochMs();
      JSONObject payload = new JSONObject();
      payload.put("type", "sport_midnight_renew");
      NativeSchedulerK.scheduleExactAt(ctx.getApplicationContext(), MIDNIGHT_RENEW_ID, next, payload.toString());
    } catch (Throwable ignore) {}
  }

  /** Entry called by AlarmReceiver when type=sport_midnight_renew. */
  public static void runMidnightRenew(Context ctx) {
    Context app = ctx.getApplicationContext();
    try {
      DbRepository.log(app, "_SYS_", "【原生】sport_midnight_renew: begin");
    } catch (Throwable ignore) {}

    SQLiteDatabase db = null;
    try {
      DbInspector.Contract cc = DbInspector.loadOrLightScan(app);
      if (cc == null || TextUtils.isEmpty(cc.dbPath)) {
        scheduleMidnightAlarm(app);
        return;
      }
      db = SQLiteDatabase.openDatabase(cc.dbPath, null, SQLiteDatabase.OPEN_READWRITE);
      renewAllPlans(app, db);
    } catch (Throwable t) {
      try {
        DbRepository.log(app, "_SYS_", "【原生】sport_midnight_renew error: " + (t.getMessage() == null ? "unknown" : t.getMessage()));
      } catch (Throwable ignore) {}
    } finally {
      try { if (db != null) db.close(); } catch (Throwable ignore) {}
      // Always reschedule next midnight.
      scheduleMidnightAlarm(app);
    }
  }

  /** Reschedule alarms for all plans from DB (useful on BOOT). */
  public static void rescheduleAllPlanAlarms(Context ctx) {
    Context app = ctx.getApplicationContext();
    SQLiteDatabase db = null;
    try {
      DbInspector.Contract cc = DbInspector.loadOrLightScan(app);
      if (cc == null || TextUtils.isEmpty(cc.dbPath)) return;
      db = SQLiteDatabase.openDatabase(cc.dbPath, null, SQLiteDatabase.OPEN_READWRITE);
      scheduleAllPlanAlarms(app, db);
    } catch (Throwable ignore) {
    } finally {
      try { if (db != null) db.close(); } catch (Throwable ignore) {}
    }
  }

  // ---------------- internal helpers ----------------

  private static void renewAllPlans(Context app, SQLiteDatabase db) {
    // Mark any unfinished records in the past as expired.
    try {
      long todayStart = todayStartEpochMs();
      String todayIso = isoFromEpochMs(todayStart);
      db.execSQL(
        "UPDATE sport_records SET status='expired', updated_at=? " +
          "WHERE status IN ('not_started','in_progress','paused','stopped') " +
          "AND (end_time IS NULL OR end_time='') " +
          "AND plan_time < ?",
        new Object[]{ nowIso(), todayIso }
      );
    } catch (Throwable ignore) {}

    Cursor c = null;
    try {
      c = db.rawQuery(
        "SELECT id, repeat_type, repeat_detail, notify_enabled, notify_advance, status, plan_time " +
          "FROM sport_plans",
        null
      );

      while (c.moveToNext()) {
        int planId = c.getInt(0);
        String repeatType = safeStr(c.getString(1), "daily");
        String repeatDetail = safeStr(c.getString(2), "");
        int notifyEnabled = safeInt(c, 3);
        int notifyAdvance = safeInt(c, 4);
        String status = safeStr(c.getString(5), "");
        String curPlanTime = safeStr(c.getString(6), "");

        // Skip canceled plans.
        if ("canceled".equals(status)) continue;

        // Skip renewal if there is an active unfinished record.
        if (hasActiveUnfinishedRecord(db, planId)) {
          continue;
        }

        long nextEpoch = computeNextEpochMs(repeatType, repeatDetail);
        if (nextEpoch <= 0) continue;

        String nextIso = isoFromEpochMs(nextEpoch);

        // Update plan_time + status.
        try {
          db.execSQL(
            "UPDATE sport_plans SET plan_time=?, status='not_started', updated_at=? WHERE id=?",
            new Object[]{ nextIso, nowIso(), planId }
          );
        } catch (Throwable ignore) {}

        // Reschedule alarms.
        try {
          schedulePlanAlarms(app, planId, nextEpoch, nextIso, notifyEnabled == 1, notifyAdvance);
        } catch (Throwable ignore) {}
      }

    } finally {
      try { if (c != null) c.close(); } catch (Throwable ignore) {}
    }
  }

  private static void scheduleAllPlanAlarms(Context app, SQLiteDatabase db) {
    Cursor c = null;
    try {
      c = db.rawQuery(
        "SELECT id, plan_time, notify_enabled, notify_advance, status FROM sport_plans",
        null
      );
      while (c.moveToNext()) {
        int planId = c.getInt(0);
        String iso = safeStr(c.getString(1), "");
        int notifyEnabled = safeInt(c, 2);
        int notifyAdvance = safeInt(c, 3);
        String status = safeStr(c.getString(4), "");
        if ("canceled".equals(status)) continue;
        long epoch = parseIsoToEpochMs(iso);
        if (epoch <= 0) continue;
        schedulePlanAlarms(app, planId, epoch, iso, notifyEnabled == 1, notifyAdvance);
      }
    } catch (Throwable ignore) {
    } finally {
      try { if (c != null) c.close(); } catch (Throwable ignore) {}
    }
  }

  private static void schedulePlanAlarms(Context app, int planId, long planEpochMs, String planIso,
                                        boolean notifyEnabled, int notifyAdvanceMin) {
    // Cancel previous.
    int fsId = FULLSCREEN_BASE_ID + planId;
    int remId = REMINDER_BASE_ID + planId;
    try { NativeSchedulerK.cancel(app, fsId); } catch (Throwable ignore) {}
    try { NativeSchedulerK.cancel(app, remId); } catch (Throwable ignore) {}

    // Countdown changed to 5s: trigger full-screen 5 seconds before the plan time.
    // If scheduled too late, ensure it still fires (avoid scheduling in the past).
    long now = System.currentTimeMillis();
    long fsEpoch = planEpochMs - 5_000L;
    if (fsEpoch <= now + 500L) {
      fsEpoch = now + 500L;
    }
    JSONObject p1 = new JSONObject();
    try {
      p1.put("type", "sport_fullscreen");
      p1.put("planId", planId);
      p1.put("planTime", planIso);
    } catch (Throwable ignore) {}
    try { NativeSchedulerK.scheduleExactAt(app, fsId, fsEpoch, p1.toString()); } catch (Throwable ignore) {}

    if (notifyEnabled && notifyAdvanceMin > 0) {
      long remEpoch = planEpochMs - (long) notifyAdvanceMin * 60_000L;
      if (remEpoch > now) {
        JSONObject p2 = new JSONObject();
        try {
          p2.put("type", "sport_reminder");
          p2.put("planId", planId);
          p2.put("planTime", planIso);
        } catch (Throwable ignore) {}
        try { NativeSchedulerK.scheduleExactAt(app, remId, remEpoch, p2.toString()); } catch (Throwable ignore) {}
      }
    }
  }

  private static boolean hasActiveUnfinishedRecord(SQLiteDatabase db, int planId) {
    Cursor c = null;
    try {
      c = db.rawQuery(
        "SELECT id FROM sport_records WHERE plan_id=? AND status IN ('in_progress','paused','stopped') " +
          "AND (end_time IS NULL OR end_time='') ORDER BY id DESC LIMIT 1",
        new String[]{ String.valueOf(planId) }
      );
      return c.moveToFirst();
    } catch (Throwable ignore) {
      return false;
    } finally {
      try { if (c != null) c.close(); } catch (Throwable ignore) {}
    }
  }

  private static long computeNextEpochMs(String repeatType, String repeatDetailJson) {
    // Defaults
    int hh = 9, mm = 0, ss = 0;
    Set<Integer> weekdays = new HashSet<>();
    for (int i = 1; i <= 7; i++) weekdays.add(i);
    Set<Integer> monthdays = new HashSet<>();
    JSONArray customDates = null;

    try {
      if (!TextUtils.isEmpty(repeatDetailJson)) {
        JSONObject v = new JSONObject(repeatDetailJson);
        String time = v.optString("time", null);
        if (time != null && time.contains(":")) {
          String[] parts = time.split(":");
          if (parts.length > 0) hh = safeParseInt(parts[0], hh);
          if (parts.length > 1) mm = safeParseInt(parts[1], mm);
          if (parts.length > 2) ss = safeParseInt(parts[2], ss);
        }
        if ("weekly".equals(repeatType)) {
          JSONArray arr = v.optJSONArray("weekdays");
          if (arr != null) {
            weekdays.clear();
            for (int i = 0; i < arr.length(); i++) weekdays.add(arr.optInt(i));
          }
        }
        if ("monthly".equals(repeatType)) {
          JSONArray arr = v.optJSONArray("monthdays");
          if (arr != null) {
            monthdays.clear();
            for (int i = 0; i < arr.length(); i++) monthdays.add(arr.optInt(i));
          }
        }
        if ("custom".equals(repeatType)) {
          customDates = v.optJSONArray("dates");
        }
      }
    } catch (Throwable ignore) {}

    long now = System.currentTimeMillis();
    Calendar base = Calendar.getInstance();
    base.setTimeInMillis(now);
    // start from today 00:00.
    Calendar today = Calendar.getInstance();
    today.set(base.get(Calendar.YEAR), base.get(Calendar.MONTH), base.get(Calendar.DAY_OF_MONTH), 0, 0, 0);
    today.set(Calendar.MILLISECOND, 0);

    if ("daily".equals(repeatType) || TextUtils.isEmpty(repeatType)) {
      Calendar cand = (Calendar) today.clone();
      cand.set(Calendar.HOUR_OF_DAY, hh);
      cand.set(Calendar.MINUTE, mm);
      cand.set(Calendar.SECOND, ss);
      cand.set(Calendar.MILLISECOND, 0);
      if (cand.getTimeInMillis() <= now) cand.add(Calendar.DAY_OF_MONTH, 1);
      return cand.getTimeInMillis();
    }

    if ("weekly".equals(repeatType)) {
      for (int i = 0; i < 14; i++) {
        Calendar d = (Calendar) today.clone();
        d.add(Calendar.DAY_OF_MONTH, i);
        int dartW = toDartWeekday(d.get(Calendar.DAY_OF_WEEK));
        if (!weekdays.contains(dartW)) continue;
        d.set(Calendar.HOUR_OF_DAY, hh);
        d.set(Calendar.MINUTE, mm);
        d.set(Calendar.SECOND, ss);
        d.set(Calendar.MILLISECOND, 0);
        if (d.getTimeInMillis() > now) return d.getTimeInMillis();
      }
      return -1;
    }

    if ("monthly".equals(repeatType)) {
      if (monthdays.isEmpty()) return -1;
      Calendar m = (Calendar) today.clone();
      for (int k = 0; k < 12; k++) {
        int year = m.get(Calendar.YEAR);
        int month = m.get(Calendar.MONTH);
        int maxDay = m.getActualMaximum(Calendar.DAY_OF_MONTH);
        long best = Long.MAX_VALUE;
        for (Integer md : monthdays) {
          if (md == null) continue;
          int day = md;
          if (day < 1 || day > maxDay) continue;
          Calendar d = Calendar.getInstance();
          d.set(year, month, day, hh, mm, ss);
          d.set(Calendar.MILLISECOND, 0);
          long t = d.getTimeInMillis();
          if (t > now && t < best) best = t;
        }
        if (best != Long.MAX_VALUE) return best;
        m.add(Calendar.MONTH, 1);
        m.set(Calendar.DAY_OF_MONTH, 1);
      }
      return -1;
    }

    if ("custom".equals(repeatType)) {
      if (customDates == null) return -1;
      long best = Long.MAX_VALUE;
      for (int i = 0; i < customDates.length(); i++) {
        String s = customDates.optString(i, "");
        if (TextUtils.isEmpty(s)) continue;
        // Expect yyyy-MM-dd
        String[] parts = s.split("-");
        if (parts.length < 3) continue;
        int y = safeParseInt(parts[0], -1);
        int mo = safeParseInt(parts[1], -1);
        int da = safeParseInt(parts[2], -1);
        if (y <= 0 || mo <= 0 || da <= 0) continue;
        Calendar d = Calendar.getInstance();
        d.set(y, mo - 1, da, hh, mm, ss);
        d.set(Calendar.MILLISECOND, 0);
        long t = d.getTimeInMillis();
        if (t > now && t < best) best = t;
      }
      return best == Long.MAX_VALUE ? -1 : best;
    }

    // Unknown type -> daily fallback
    Calendar cand = (Calendar) today.clone();
    cand.set(Calendar.HOUR_OF_DAY, hh);
    cand.set(Calendar.MINUTE, mm);
    cand.set(Calendar.SECOND, ss);
    cand.set(Calendar.MILLISECOND, 0);
    if (cand.getTimeInMillis() <= now) cand.add(Calendar.DAY_OF_MONTH, 1);
    return cand.getTimeInMillis();
  }

  private static int safeParseInt(String s, int def) {
    try { return Integer.parseInt(s.trim()); } catch (Throwable ignore) { return def; }
  }

  private static int toDartWeekday(int calDow) {
    // Calendar: 1=Sun..7=Sat, Dart: 1=Mon..7=Sun
    return ((calDow + 5) % 7) + 1;
  }

  private static long todayStartEpochMs() {
    Calendar c = Calendar.getInstance();
    c.set(Calendar.HOUR_OF_DAY, 0);
    c.set(Calendar.MINUTE, 0);
    c.set(Calendar.SECOND, 0);
    c.set(Calendar.MILLISECOND, 0);
    return c.getTimeInMillis();
  }

  private static long nextMidnightEpochMs() {
    Calendar c = Calendar.getInstance();
    c.set(Calendar.HOUR_OF_DAY, 0);
    c.set(Calendar.MINUTE, 0);
    // Requirement: run at 00:00:00.
    c.set(Calendar.SECOND, 0);
    c.set(Calendar.MILLISECOND, 0);
    c.add(Calendar.DAY_OF_MONTH, 1);
    return c.getTimeInMillis();
  }

  private static String nowIso() {
    return isoFromEpochMs(System.currentTimeMillis());
  }

  private static String isoFromEpochMs(long epochMs) {
    Calendar c = Calendar.getInstance();
    c.setTimeInMillis(epochMs);
    return String.format(
      Locale.US,
      "%04d-%02d-%02dT%02d:%02d:%02d.000",
      c.get(Calendar.YEAR),
      c.get(Calendar.MONTH) + 1,
      c.get(Calendar.DAY_OF_MONTH),
      c.get(Calendar.HOUR_OF_DAY),
      c.get(Calendar.MINUTE),
      c.get(Calendar.SECOND)
    );
  }

  private static long parseIsoToEpochMs(String iso) {
    try {
      if (TextUtils.isEmpty(iso)) return -1;
      String s = iso;
      // Remove milliseconds
      int dot = s.indexOf('.');
      if (dot > 0) s = s.substring(0, dot);
      String[] dt = s.split("T");
      if (dt.length < 2) return -1;
      String[] d = dt[0].split("-");
      String[] t = dt[1].split(":");
      if (d.length < 3 || t.length < 2) return -1;
      int y = safeParseInt(d[0], -1);
      int mo = safeParseInt(d[1], -1);
      int da = safeParseInt(d[2], -1);
      int hh = safeParseInt(t[0], 0);
      int mm = safeParseInt(t[1], 0);
      int ss = t.length >= 3 ? safeParseInt(t[2], 0) : 0;
      if (y <= 0 || mo <= 0 || da <= 0) return -1;
      Calendar c = Calendar.getInstance();
      c.set(y, mo - 1, da, hh, mm, ss);
      c.set(Calendar.MILLISECOND, 0);
      return c.getTimeInMillis();
    } catch (Throwable ignore) {
      return -1;
    }
  }

  private static String safeStr(String s, String def) {
    return s == null ? def : s;
  }

  private static int safeInt(Cursor c, int idx) {
    try {
      if (c.isNull(idx)) return 0;
      return c.getInt(idx);
    } catch (Throwable ignore) {
      return 0;
    }
  }
}
