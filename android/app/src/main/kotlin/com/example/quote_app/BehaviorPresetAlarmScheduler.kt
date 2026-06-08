package com.example.quote_app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

object BehaviorPresetAlarmScheduler {
  @JvmStatic
  fun normalizePayloadForFire(ctx: Context, rawPayload: String?): String {
    return try {
      val src = JSONObject(rawPayload ?: "{}")
      val hour = src.optInt("reminderHour", 21).coerceIn(0, 23)
      val minute = src.optInt("reminderMinute", 0).coerceIn(0, 59)
      val dayMs = dayStartMs(src.optLong("checkDateMs", System.currentTimeMillis()))
      val settings = BehaviorPresetAlarmSettings.asMap(ctx)
      val out = JSONObject(src.toString())
      out.put("module", "behavior_tracking")
      out.put("reminderHour", hour)
      out.put("reminderMinute", minute)
      out.put("checkDateMs", dayMs)
      out.put("alarmSoundUri", settings["soundUri"] ?: "")
      out.put("alarmSoundTitle", settings["soundTitle"] ?: "系统默认闹钟铃声")
      out.put("alarmVolume", settings["volume"] ?: 1.0)
      out.put("alarmVibrate", settings["vibrate"] ?: true)
      if (src.optString("type", "") == "behavior_preset_daily_review" || src.optString("templateKey", "") == "preset_daily_review") {
        val allPresets = queryActivePresetsForDay(ctx.applicationContext, dayMs)
        out.put("type", "behavior_preset_daily_review")
        out.put("templateKey", "preset_daily_review")
        out.put("setupRequired", false)
        out.put("presets", allPresets)
        out.put("presetCount", allPresets.length())
        if (allPresets.length() > 0) copyFirstPreset(out, allPresets.optJSONObject(0))
        out.put("title", "每日预设行为复盘")
        out.put("body", "请登记今天全部预设行为的完成/未完成情况，并开始明天预设。")
        return out.toString()
      }
      val presets = queryPresetsFor(ctx.applicationContext, dayMs, hour, minute)
      if (presets.length() > 0) {
        out.put("type", "behavior_preset_alarm")
        out.put("setupRequired", false)
        out.put("presets", presets)
        out.put("presetCount", presets.length())
        val first = presets.optJSONObject(0)
        if (first != null) copyFirstPreset(out, first)
        out.put("title", "预设提醒")
        out.put("body", if (presets.length() == 1) "请查看/确认今天的预设行为。" else "请查看/确认这个时刻的 ${presets.length()} 个预设行为。")
      } else {
        out.put("type", "behavior_preset_setup_alarm")
        out.put("setupRequired", true)
        out.put("presets", JSONArray())
        out.put("presetCount", 0)
        out.put("title", "行为预设提醒")
        out.put("body", "这个时刻没有可确认的预设行为，请先设置预设提醒闹钟或新增预设行为。")
      }
      out.toString()
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorPresetAlarm] normalize failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
      rawPayload ?: "{}"
    }
  }

  @JvmStatic
  fun fireKey(rawPayload: String?): String {
    return try {
      val obj = JSONObject(rawPayload ?: "{}")
      val type = obj.optString("type", "")
      val day = dayStartMs(obj.optLong("checkDateMs", System.currentTimeMillis()))
      val h = obj.optInt("reminderHour", 21).coerceIn(0, 23)
      val m = obj.optInt("reminderMinute", 0).coerceIn(0, 59)
      "$type-$day-$h-$m"
    } catch (_: Throwable) { "" }
  }

  @JvmStatic
  fun scheduleNextAfterFire(ctx: Context, rawPayload: String?) {
    try {
      val obj = JSONObject(rawPayload ?: "{}")
      val hour = obj.optInt("reminderHour", 21).coerceIn(0, 23)
      val minute = obj.optInt("reminderMinute", 0).coerceIn(0, 59)
      val start = Calendar.getInstance()
      start.timeInMillis = dayStartMs(obj.optLong("checkDateMs", System.currentTimeMillis()))
      start.add(Calendar.DAY_OF_YEAR, 1)
      if (obj.optString("type", "") == "behavior_preset_daily_review" || obj.optString("templateKey", "") == "preset_daily_review") {
        for (i in 0..31) {
          val day = start.clone() as Calendar
          day.add(Calendar.DAY_OF_YEAR, i)
          day.set(Calendar.HOUR_OF_DAY, 0)
          day.set(Calendar.MINUTE, 0)
          day.set(Calendar.SECOND, 0)
          day.set(Calendar.MILLISECOND, 0)
          val trigger = day.clone() as Calendar
          trigger.set(Calendar.HOUR_OF_DAY, hour)
          trigger.set(Calendar.MINUTE, minute)
          trigger.set(Calendar.SECOND, 0)
          trigger.set(Calendar.MILLISECOND, 0)
          if (trigger.timeInMillis <= System.currentTimeMillis() + 20_000L) continue
          val settings = BehaviorPresetAlarmSettings.asMap(ctx)
          val presets = queryActivePresetsForDay(ctx.applicationContext, day.timeInMillis)
          val next = JSONObject()
          next.put("module", "behavior_tracking")
          next.put("type", "behavior_preset_daily_review")
          next.put("templateKey", "preset_daily_review")
          next.put("setupRequired", false)
          next.put("presets", presets)
          next.put("presetCount", presets.length())
          next.put("checkDateMs", day.timeInMillis)
          next.put("reminderHour", hour)
          next.put("reminderMinute", minute)
          next.put("alarmSoundUri", settings["soundUri"] ?: "")
          next.put("alarmSoundTitle", settings["soundTitle"] ?: "系统默认闹钟铃声")
          next.put("alarmVolume", settings["volume"] ?: 1.0)
          next.put("alarmVibrate", settings["vibrate"] ?: true)
          next.put("title", "每日预设行为复盘")
          next.put("body", "请登记今天全部预设行为的完成/未完成情况，并开始明天预设。")
          if (presets.length() > 0) copyFirstPreset(next, presets.optJSONObject(0))
          val id = dailyReviewAlarmId(day.timeInMillis)
          next.put("alarmId", id)
          NativeSchedulerK.scheduleAlarmClockAt(ctx.applicationContext, id, trigger.timeInMillis, next.toString())
          return
        }
        return
      }
      for (i in 0..31) {
        val day = start.clone() as Calendar
        day.add(Calendar.DAY_OF_YEAR, i)
        day.set(Calendar.HOUR_OF_DAY, 0)
        day.set(Calendar.MINUTE, 0)
        day.set(Calendar.SECOND, 0)
        day.set(Calendar.MILLISECOND, 0)
        val trigger = day.clone() as Calendar
        trigger.set(Calendar.HOUR_OF_DAY, hour)
        trigger.set(Calendar.MINUTE, minute)
        trigger.set(Calendar.SECOND, 0)
        trigger.set(Calendar.MILLISECOND, 0)
        if (trigger.timeInMillis <= System.currentTimeMillis() + 20_000L) continue
        val presets = queryPresetsFor(ctx.applicationContext, day.timeInMillis, hour, minute)
        if (presets.length() <= 0 && !obj.optBoolean("setupRequired", false) && obj.optString("type", "") != "behavior_preset_setup_alarm") continue
        val settings = BehaviorPresetAlarmSettings.asMap(ctx)
        val next = JSONObject()
        next.put("module", "behavior_tracking")
        next.put("type", if (presets.length() > 0) "behavior_preset_alarm" else "behavior_preset_setup_alarm")
        next.put("setupRequired", presets.length() <= 0)
        next.put("presets", presets)
        next.put("presetCount", presets.length())
        next.put("checkDateMs", day.timeInMillis)
        next.put("reminderHour", hour)
        next.put("reminderMinute", minute)
        next.put("alarmSoundUri", settings["soundUri"] ?: "")
        next.put("alarmSoundTitle", settings["soundTitle"] ?: "系统默认闹钟铃声")
        next.put("alarmVolume", settings["volume"] ?: 1.0)
        next.put("alarmVibrate", settings["vibrate"] ?: true)
        if (presets.length() > 0) copyFirstPreset(next, presets.optJSONObject(0))
        val id = groupAlarmId(day.timeInMillis, hour, minute)
        next.put("alarmId", id)
        NativeSchedulerK.scheduleAlarmClockAt(ctx.applicationContext, id, trigger.timeInMillis, next.toString())
        return
      }
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorPresetAlarm] schedule next failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
  }

  @JvmStatic
  fun rescheduleUpcoming(ctx: Context): Int {
    var count = 0
    try {
      val db = openDbReadOnly(ctx) ?: return 0
      val pairs = LinkedHashSet<String>()
      val legacyPresetIds = ArrayList<Int>()
      try {
        db.rawQuery("SELECT id, reminder_hour, reminder_minute FROM behavior_observation_presets WHERE active = 1 AND reminder_enabled = 1 AND reminder_hour IS NOT NULL AND reminder_minute IS NOT NULL", emptyArray()).use { c ->
          while (c.moveToNext()) {
            legacyPresetIds.add(c.getInt(0))
            pairs.add("${c.getInt(1)}:${c.getInt(2)}")
          }
        }
      } finally { try { db.close() } catch (_: Throwable) {} }
      val now = Calendar.getInstance()
      // Cancel legacy v33/v34 per-preset broadcast alarms.  They use a different PendingIntent kind from the
      // new Activity-backed alarm-clock entries, so merely scheduling the new grouped alarm would not replace them.
      try {
        for (presetId in legacyPresetIds) {
          for (i in 0 until 14) {
            val day = Calendar.getInstance().apply {
              set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
              add(Calendar.DAY_OF_YEAR, i)
            }
            NativeSchedulerK.cancel(ctx.applicationContext, presetAlarmId(presetId, day.timeInMillis))
          }
        }
      } catch (_: Throwable) {}
      for (pair in pairs) {
        val parts = pair.split(":")
        val hour = parts.getOrNull(0)?.toIntOrNull()?.coerceIn(0,23) ?: 21
        val minute = parts.getOrNull(1)?.toIntOrNull()?.coerceIn(0,59) ?: 0
        for (i in 0 until 14) {
          val day = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, i)
          }
          val trigger = day.clone() as Calendar
          trigger.set(Calendar.HOUR_OF_DAY, hour); trigger.set(Calendar.MINUTE, minute); trigger.set(Calendar.SECOND, 0); trigger.set(Calendar.MILLISECOND, 0)
          if (trigger.timeInMillis <= now.timeInMillis + 20_000L) continue
          val presets = queryPresetsFor(ctx.applicationContext, day.timeInMillis, hour, minute)
          if (presets.length() <= 0) continue
          val settings = BehaviorPresetAlarmSettings.asMap(ctx)
          val payload = JSONObject().apply {
            put("module", "behavior_tracking")
            put("type", "behavior_preset_alarm")
            put("title", "预设提醒")
            put("body", if (presets.length() == 1) "请查看/确认今天的预设行为。" else "请查看/确认这个时刻的 ${presets.length()} 个预设行为。")
            put("presets", presets)
            put("presetCount", presets.length())
            put("checkDateMs", day.timeInMillis)
            put("reminderHour", hour)
            put("reminderMinute", minute)
            put("alarmSoundUri", settings["soundUri"] ?: "")
            put("alarmSoundTitle", settings["soundTitle"] ?: "系统默认闹钟铃声")
            put("alarmVolume", settings["volume"] ?: 1.0)
            put("alarmVibrate", settings["vibrate"] ?: true)
          }
          copyFirstPreset(payload, presets.optJSONObject(0))
          val id = groupAlarmId(day.timeInMillis, hour, minute)
          payload.put("alarmId", id)
          if (NativeSchedulerK.scheduleAlarmClockAt(ctx.applicationContext, id, trigger.timeInMillis, payload.toString())) count++
        }
      }
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorPresetAlarm] reschedule upcoming failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
    return count
  }

  private fun copyFirstPreset(out: JSONObject, first: JSONObject?) {
    if (first == null) return
    out.put("presetId", first.optInt("presetId", first.optInt("id", 0)))
    out.put("presetName", first.optString("presetName", first.optString("name", "今天的预设行为")))
    out.put("category", first.optString("category", "未分类"))
    out.put("primaryLayer", first.optString("primaryLayer", "行为层面"))
    out.put("targetValue", first.opt("targetValue"))
    out.put("unit", first.optString("unit", "次"))
    out.put("defaultDurationMin", first.optInt("defaultDurationMin", 0))
    out.put("weekdays", first.optJSONArray("weekdays") ?: JSONArray())
  }

  private fun queryActivePresetsForDay(ctx: Context, dayStartMs: Long): JSONArray {
    val arr = JSONArray()
    val db = openDbReadOnly(ctx) ?: return arr
    return try {
      val weekday = javaWeekdayToDart(Calendar.getInstance().apply { timeInMillis = dayStartMs }.get(Calendar.DAY_OF_WEEK))
      val sql = """
        SELECT id, name, category, primary_layer, target_value, unit, default_duration_min, weekdays_json
        FROM behavior_observation_presets
        WHERE active = 1
        ORDER BY sort_order ASC, id ASC
      """.trimIndent()
      db.rawQuery(sql, emptyArray()).use { c ->
        while (c.moveToNext()) {
          val weekdaysRaw = if (c.isNull(7)) "[]" else c.getString(7)
          val weekdays = parseWeekdays(weekdaysRaw)
          if (weekdays.isNotEmpty() && !weekdays.contains(weekday)) continue
          val o = JSONObject()
          val presetId = c.getInt(0)
          o.put("id", presetId)
          o.put("presetId", presetId)
          o.put("name", c.getString(1) ?: "")
          o.put("presetName", c.getString(1) ?: "")
          o.put("category", if (c.isNull(2)) "未分类" else c.getString(2))
          o.put("primaryLayer", if (c.isNull(3)) "行为层面" else c.getString(3))
          if (!c.isNull(4)) o.put("targetValue", c.getDouble(4)) else o.put("targetValue", JSONObject.NULL)
          o.put("unit", if (c.isNull(5)) "次" else c.getString(5))
          if (!c.isNull(6)) o.put("defaultDurationMin", c.getInt(6)) else o.put("defaultDurationMin", JSONObject.NULL)
          o.put("weekdays", JSONArray(weekdaysRaw))
          arr.put(o)
        }
      }
      arr
    } catch (_: Throwable) { JSONArray() } finally { try { db.close() } catch (_: Throwable) {} }
  }

  private fun queryPresetsFor(ctx: Context, dayStartMs: Long, hour: Int, minute: Int): JSONArray {
    val arr = JSONArray()
    val db = openDbReadOnly(ctx) ?: return arr
    return try {
      val weekday = javaWeekdayToDart(Calendar.getInstance().apply { timeInMillis = dayStartMs }.get(Calendar.DAY_OF_WEEK))
      val sql = """
        SELECT id, name, category, primary_layer, target_value, unit, default_duration_min, weekdays_json
        FROM behavior_observation_presets
        WHERE active = 1 AND reminder_enabled = 1 AND reminder_hour = ? AND reminder_minute = ?
        ORDER BY sort_order ASC, id ASC
      """.trimIndent()
      db.rawQuery(sql, arrayOf(hour.toString(), minute.toString())).use { c ->
        while (c.moveToNext()) {
          val weekdaysRaw = if (c.isNull(7)) "[]" else c.getString(7)
          val weekdays = parseWeekdays(weekdaysRaw)
          if (weekdays.isNotEmpty() && !weekdays.contains(weekday)) continue
          val o = JSONObject()
          val presetId = c.getInt(0)
          o.put("id", presetId)
          o.put("presetId", presetId)
          o.put("name", c.getString(1) ?: "")
          o.put("presetName", c.getString(1) ?: "")
          o.put("category", if (c.isNull(2)) "未分类" else c.getString(2))
          o.put("primaryLayer", if (c.isNull(3)) "行为层面" else c.getString(3))
          if (!c.isNull(4)) o.put("targetValue", c.getDouble(4)) else o.put("targetValue", JSONObject.NULL)
          o.put("unit", if (c.isNull(5)) "次" else c.getString(5))
          if (!c.isNull(6)) o.put("defaultDurationMin", c.getInt(6)) else o.put("defaultDurationMin", JSONObject.NULL)
          o.put("weekdays", JSONArray(weekdaysRaw))
          arr.put(o)
        }
      }
      arr
    } catch (_: Throwable) { JSONArray() } finally { try { db.close() } catch (_: Throwable) {} }
  }

  private fun openDbReadOnly(ctx: Context): SQLiteDatabase? {
    return try {
      val contract = com.example.quote_app.data.DbInspector.loadOrLightScan(ctx.applicationContext)
      val path = contract?.dbPath
      if (!path.isNullOrBlank()) SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY) else null
    } catch (_: Throwable) { null }
  }

  private fun parseWeekdays(raw: Any?): Set<Int> {
    val result = LinkedHashSet<Int>()
    try {
      val arr = when (raw) {
        is JSONArray -> raw
        is String -> if (raw.trim().startsWith("[")) JSONArray(raw) else JSONArray()
        else -> JSONArray()
      }
      for (i in 0 until arr.length()) {
        val v = arr.optInt(i, 0)
        if (v in 1..7) result.add(v)
      }
    } catch (_: Throwable) {}
    return result
  }

  private fun javaWeekdayToDart(javaDay: Int): Int = when (javaDay) {
    Calendar.MONDAY -> 1
    Calendar.TUESDAY -> 2
    Calendar.WEDNESDAY -> 3
    Calendar.THURSDAY -> 4
    Calendar.FRIDAY -> 5
    Calendar.SATURDAY -> 6
    Calendar.SUNDAY -> 7
    else -> 1
  }

  private fun dayStartMs(ms: Long): Long {
    val c = Calendar.getInstance().apply { timeInMillis = ms }
    c.set(Calendar.HOUR_OF_DAY, 0)
    c.set(Calendar.MINUTE, 0)
    c.set(Calendar.SECOND, 0)
    c.set(Calendar.MILLISECOND, 0)
    return c.timeInMillis
  }

  private fun presetAlarmId(presetId: Int, dayStartMs: Long): Int {
    val base = Calendar.getInstance().apply {
      set(2020, Calendar.JANUARY, 1, 0, 0, 0)
      set(Calendar.MILLISECOND, 0)
    }
    val dayNo = ((dayStartMs - base.timeInMillis) / 86_400_000L).toInt()
    return 97000000 + ((presetId * 1000 + dayNo) % 900000)
  }

  private fun dailyReviewAlarmId(dayMs: Long): Int {
    val base = Calendar.getInstance().apply {
      set(2020, Calendar.JANUARY, 1, 0, 0, 0)
      set(Calendar.MILLISECOND, 0)
    }
    val dayNo = ((dayStartMs(dayMs) - base.timeInMillis) / 86_400_000L).toInt()
    return 96200000 + (kotlin.math.abs(dayNo) % 500000)
  }

  private fun groupAlarmId(dayStartMs: Long, hour: Int, minute: Int): Int {
    val base = Calendar.getInstance().apply {
      set(2020, Calendar.JANUARY, 1, 0, 0, 0)
      set(Calendar.MILLISECOND, 0)
    }
    val dayNo = ((dayStartMs - base.timeInMillis) / 86_400_000L).toInt()
    val minuteOfDay = hour.coerceIn(0, 23) * 60 + minute.coerceIn(0, 59)
    return 97100000 + ((dayNo * 1440 + minuteOfDay) % 900000)
  }
}
