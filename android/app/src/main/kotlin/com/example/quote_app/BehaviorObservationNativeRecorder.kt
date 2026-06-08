package com.example.quote_app

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.text.TextUtils
import com.example.quote_app.data.DbInspector
import org.json.JSONArray
import java.io.File
import java.util.Calendar

/**
 * V13 行为观察：通知快捷记录的原生落库器。
 *
 * 设计目标：用户收到提醒后，不必打开 Flutter 页面，直接在通知动作中选择观察层面、输入文字，
 * 原生侧把记录写入同一个 sqflite SQLite 数据库。
 */
object BehaviorObservationNativeRecorder {
  private const val TABLE = "behavior_tracking_records"

  @JvmStatic
  fun saveFromNotification(ctx: Context, layer: String?, text: String?, payload: String?): Long {
    val db = openAppDb(ctx) ?: return -1L
    return try {
      ensureTable(db)
      val now = System.currentTimeMillis()
      val recordDay = dayStartMs(now)
      val cleanLayer = normalizeLayer(layer)
      val content = (text ?: "").trim().ifBlank { "通知快捷记录" }
      val values = ContentValues().apply {
        put("created_at_ms", now)
        put("updated_at_ms", now)
        put("record_date_ms", recordDay)
        put("mode", "notification_quick")
        put("entry_mode", "notification_remote_input")
        put("template_key", templateKeyOf(cleanLayer))
        put("method_name", "通知快捷记录")
        put("primary_layer", cleanLayer)
        put("category", categoryOf(cleanLayer))
        put("title", titleOf(cleanLayer, content))
        put("source", "notification_remote_input")
        put("privacy_level", "local_only")
        put("notes", "来自行为观察提醒通知。用户在通知中选择「$cleanLayer」并直接输入保存。")
        put("tags_json", JSONArray(listOf("行为观察", "通知快捷记录", cleanLayer)).toString())
      }
      when (cleanLayer) {
        "时间层面" -> {
          values.put("behavior", content)
          values.put("unit", "分钟")
        }
        "行为层面" -> values.put("behavior", content)
        "情绪层面" -> {
          values.put("emotion", content)
          values.put("behavior", "通知中记录了一条情绪相关行为事实")
        }
        "认知层面" -> {
          values.put("automatic_thought", content)
          values.put("cognition", content)
          values.put("behavior", "通知中记录了一条认知/想法线索")
        }
        "结果层面" -> {
          values.put("short_term_result", content)
          values.put("outcome", content)
          values.put("behavior", "通知中记录了一条结果线索")
        }
        "环境层面" -> {
          values.put("environment", content)
          values.put("behavior", "通知中记录了一条环境线索")
        }
        "身体状态层面" -> {
          values.put("body_state", content)
          values.put("behavior", "通知中记录了一条身体状态线索")
          values.put("category", "休息")
        }
        else -> values.put("behavior", content)
      }
      db.insert(TABLE, null, values)
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorObservation] notification save failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
      -1L
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
  }



  @JvmStatic
  fun saveFromNativeForm(ctx: Context, layer: String?, category: String?, valuesJson: org.json.JSONObject?): Long {
    val db = openAppDb(ctx) ?: return -1L
    return try {
      ensureTable(db)
      val now = System.currentTimeMillis()
      val recordDay = dayStartMs(now)
      val cleanLayer = normalizeLayer(layer)
      val values = valuesJson ?: org.json.JSONObject()
      val content = firstNonBlank(values, listOf("behavior", "event", "situation", "thought", "short_result", "location", "sleep", "notes")).ifBlank { "桌面小组件记录" }
      val cleanCategory = (category ?: "").trim().ifBlank { categoryOf(cleanLayer) }
      val cv = ContentValues().apply {
        put("created_at_ms", now)
        put("updated_at_ms", now)
        put("record_date_ms", recordDay)
        put("mode", "desktop_widget_form")
        put("entry_mode", "widget_native_form")
        put("template_key", templateKeyOf(cleanLayer))
        put("method_name", "桌面小组件表单")
        put("primary_layer", cleanLayer)
        put("category", cleanCategory)
        put("title", "桌面小组件 · ${cleanLayer.replace("层面", "")}：${shortText(content, 24)}")
        put("source", "desktop_widget_form")
        put("privacy_level", "local_only")
        put("notes", opt(values, "notes"))
        put("tags_json", JSONArray(listOf("行为观察", "桌面小组件", cleanLayer)).toString())
        put("template_answers_json", values.toString())
      }
      when (cleanLayer) {
        "时间层面" -> {
          cv.put("behavior", firstNonBlank(values, listOf("behavior", "notes")))
          cv.put("start_minute", parseMinuteOfDay(opt(values, "start_time")))
          cv.put("end_minute", parseMinuteOfDay(opt(values, "end_time")))
          cv.put("focus_score", parseIntOrNull(opt(values, "focus")))
          cv.put("unit", "分钟")
        }
        "行为层面" -> {
          cv.put("behavior", opt(values, "behavior"))
          cv.put("reason", opt(values, "reason"))
          cv.put("actual_value", parseDoubleOrNull(opt(values, "actual")))
          cv.put("unit", opt(values, "unit"))
        }
        "情绪层面" -> {
          cv.put("trigger_text", opt(values, "event"))
          cv.put("emotion", opt(values, "emotion"))
          cv.put("emotion_intensity", parseIntOrNull(opt(values, "intensity")))
          cv.put("reaction", opt(values, "reaction"))
          cv.put("behavior", firstNonBlank(values, listOf("event", "reaction", "emotion")))
        }
        "认知层面" -> {
          cv.put("trigger_text", opt(values, "situation"))
          cv.put("automatic_thought", opt(values, "thought"))
          cv.put("cognition", opt(values, "thought"))
          cv.put("reaction", opt(values, "reaction"))
          cv.put("behavior", firstNonBlank(values, listOf("reaction", "situation", "thought")))
        }
        "结果层面" -> {
          cv.put("behavior", opt(values, "behavior"))
          cv.put("short_term_result", opt(values, "short_result"))
          cv.put("long_term_impact", opt(values, "long_impact"))
          cv.put("outcome", firstNonBlank(values, listOf("short_result", "long_impact")))
        }
        "环境层面" -> {
          cv.put("location_type", opt(values, "location"))
          cv.put("people_context", opt(values, "people"))
          cv.put("phone_distance", opt(values, "objects"))
          cv.put("environment", firstNonBlank(values, listOf("location", "people", "objects", "effect")))
          cv.put("behavior", opt(values, "effect"))
        }
        "身体状态层面" -> {
          cv.put("sleep", opt(values, "sleep"))
          cv.put("body_state", firstNonBlank(values, listOf("energy", "fatigue", "sleep")))
          cv.put("steps", parseIntOrNull(opt(values, "steps")))
          cv.put("exercise_min", parseIntOrNull(opt(values, "exercise")))
          cv.put("behavior", firstNonBlank(values, listOf("energy", "fatigue", "sleep", "steps", "exercise")))
        }
        else -> cv.put("behavior", content)
      }
      db.insert(TABLE, null, cv)
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorObservation] widget native form save failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
      -1L
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
  }



  @JvmStatic
  fun savePresetAlarmCheckIn(
    ctx: Context,
    payload: org.json.JSONObject?,
    status: String?,
    actualValueText: String?,
    actualDurationText: String?,
    noteText: String?
  ): Long {
    val db = openAppDb(ctx) ?: return -1L
    return try {
      ensureTable(db)
      ensurePresetCheckinTable(db)
      val obj = payload ?: org.json.JSONObject()
      val presetId = obj.optInt("presetId", 0)
      if (presetId <= 0) return -1L
      val dayMs = dayStartMs(obj.optLong("checkDateMs", System.currentTimeMillis()))
      val nowMs = System.currentTimeMillis()
      val presetName = obj.optString("presetName", "预设行为")
      val category = obj.optString("category", "其他").ifBlank { "其他" }
      val layer = normalizeLayer(obj.optString("primaryLayer", "行为层面"))
      val unit = obj.optString("unit", "次")
      val targetValue = parseDoubleOrNull(obj.opt("targetValue")?.toString() ?: "")
      val actualValue = parseDoubleOrNull(actualValueText ?: "") ?: targetValue
      val defaultDuration = obj.optInt("defaultDurationMin", 0).takeIf { it > 0 }
      val actualDuration = parseIntOrNull(actualDurationText ?: "") ?: defaultDuration
      val note = (noteText ?: "").trim()
      val cleanStatus = when (status) {
        "done", "missed", "skipped", "acknowledged" -> status
        else -> "pending"
      }

      var oldId: Long? = null
      var oldRecordId: Long? = null
      var oldStatus: String? = null
      db.rawQuery(
        "SELECT id, record_id, status FROM behavior_observation_preset_checkins WHERE preset_id = ? AND check_date_ms = ? LIMIT 1",
        arrayOf(presetId.toString(), dayMs.toString())
      ).use { c ->
        if (c.moveToFirst()) {
          oldId = c.getLong(0)
          if (!c.isNull(1)) oldRecordId = c.getLong(1)
          oldStatus = if (c.isNull(2)) null else c.getString(2)
        }
      }

      if (cleanStatus == "acknowledged" && oldStatus in listOf("done", "missed", "skipped")) {
        return oldRecordId ?: oldId ?: 1L
      }

      var recordId: Long? = oldRecordId
      if (cleanStatus == "done") {
        val now = Calendar.getInstance()
        val nowMin = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val startMin = if (actualDuration != null && actualDuration > 0) (nowMin - actualDuration + 24 * 60) % (24 * 60) else null
        val cv = ContentValues().apply {
          if (recordId != null) put("id", recordId)
          put("created_at_ms", nowMs)
          put("updated_at_ms", nowMs)
          put("record_date_ms", dayMs)
          put("mode", "planned_behavior_checkin")
          put("entry_mode", "preset_alarm_fullscreen")
          put("template_key", "planned_behavior")
          put("method_name", "系统闹钟预设行为")
          put("primary_layer", layer)
          put("category", category)
          put("title", "预设行为 · $presetName")
          put("source", "planned_behavior_alarm")
          put("privacy_level", "local_sensitive")
          put("behavior", presetName)
          if (targetValue != null) put("planned_value", targetValue)
          if (actualValue != null) put("actual_value", actualValue)
          put("unit", unit)
          put("completion_state", "已完成")
          put("evidence_type", "preset_alarm_checkin")
          if (startMin != null) put("start_minute", startMin)
          if (actualDuration != null && actualDuration > 0) put("end_minute", nowMin)
          put("notes", note.ifBlank { obj.optString("notes", "") })
          put("tags_json", JSONArray(listOf("预设行为", "计划行为", "系统闹钟", category)).toString())
          put("template_answers_json", org.json.JSONObject().apply {
            put("presetId", presetId)
            put("presetName", presetName)
            put("checkDateMs", dayMs)
            put("status", cleanStatus)
            put("actualValue", actualValue)
            put("actualDurationMin", actualDuration)
            put("entry", "preset_alarm_fullscreen")
          }.toString())
        }
        recordId = if (oldRecordId != null) {
          db.update(TABLE, cv, "id = ?", arrayOf(oldRecordId.toString()))
          oldRecordId
        } else {
          db.insert(TABLE, null, cv)
        }
      } else if ((cleanStatus == "missed" || cleanStatus == "skipped") && oldRecordId != null) {
        try { db.delete(TABLE, "id = ?", arrayOf(oldRecordId.toString())) } catch (_: Throwable) {}
        recordId = null
      }

      val check = ContentValues().apply {
        put("preset_id", presetId)
        put("check_date_ms", dayMs)
        put("status", cleanStatus)
        if (actualValue != null) put("actual_value", actualValue) else putNull("actual_value")
        if (actualDuration != null) put("actual_duration_min", actualDuration) else putNull("actual_duration_min")
        put("note", note)
        if (recordId != null && recordId > 0L) put("record_id", recordId) else putNull("record_id")
        put("created_at_ms", oldId?.let { nowMs } ?: nowMs)
        put("updated_at_ms", nowMs)
      }
      if (oldId == null) {
        db.insert("behavior_observation_preset_checkins", null, check)
      } else {
        db.update("behavior_observation_preset_checkins", check, "id = ?", arrayOf(oldId.toString()))
      }
      recordId ?: oldId ?: 1L
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorObservation] preset alarm save failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
      -1L
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
  }


  @JvmStatic
  fun savePresetDefinitionFromAlarm(
    ctx: Context,
    nameText: String?,
    categoryText: String?,
    durationText: String?,
    noteText: String?,
    reminderHour: Int,
    reminderMinute: Int,
    vibrate: Boolean
  ): Long {
    val cleanName = (nameText ?: "").trim()
    if (cleanName.isBlank()) return -1L
    val db = openAppDb(ctx) ?: return -1L
    return try {
      ensurePresetTable(db)
      val nowMs = System.currentTimeMillis()
      val cv = ContentValues().apply {
        put("created_at_ms", nowMs)
        put("updated_at_ms", nowMs)
        put("name", cleanName)
        put("category", (categoryText ?: "").trim().ifBlank { "工作/学习" })
        put("primary_layer", "行为层面")
        putNull("target_value")
        put("unit", "次")
        val duration = parseIntOrNull(durationText ?: "")
        if (duration != null && duration > 0) put("default_duration_min", duration) else putNull("default_duration_min")
        put("reminder_enabled", 1)
        put("reminder_hour", reminderHour.coerceIn(0, 23))
        put("reminder_minute", reminderMinute.coerceIn(0, 59))
        put("reminder_fullscreen", 1)
        put("reminder_vibrate", if (vibrate) 1 else 0)
        put("weekdays_json", "[]")
        put("active", 1)
        put("notes", (noteText ?: "").trim().ifBlank { "由预设闹钟全屏表单创建" })
        put("sort_order", 1000)
      }
      val id = db.insert("behavior_observation_presets", null, cv)
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorPresetAlarm] created preset from alarm id=$id name=$cleanName") } catch (_: Throwable) {}
      id
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorPresetAlarm] create preset failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
      -1L
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
  }

  private fun ensurePresetTable(db: SQLiteDatabase) {
    db.execSQL("""
      CREATE TABLE IF NOT EXISTS behavior_observation_presets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        name TEXT NOT NULL,
        category TEXT,
        primary_layer TEXT,
        target_value REAL,
        unit TEXT,
        default_duration_min INTEGER,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        reminder_hour INTEGER,
        reminder_minute INTEGER,
        reminder_fullscreen INTEGER NOT NULL DEFAULT 1,
        reminder_vibrate INTEGER NOT NULL DEFAULT 1,
        weekdays_json TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        sort_order INTEGER NOT NULL DEFAULT 1000
      )
    """.trimIndent())
  }

  private fun ensurePresetCheckinTable(db: SQLiteDatabase) {
    db.execSQL("""
      CREATE TABLE IF NOT EXISTS behavior_observation_preset_checkins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        preset_id INTEGER NOT NULL,
        check_date_ms INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        actual_value REAL,
        actual_duration_min INTEGER,
        note TEXT,
        record_id INTEGER,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        UNIQUE(preset_id, check_date_ms)
      )
    """.trimIndent())
  }

  private fun openAppDb(ctx: Context): SQLiteDatabase? {
    val candidates = ArrayList<String>()
    try {
      val contract = DbInspector.loadOrLightScan(ctx.applicationContext)
      val path = contract?.dbPath
      if (!path.isNullOrBlank()) candidates.add(path)
    } catch (_: Throwable) {}
    try { candidates.add(File(ctx.applicationInfo.dataDir + "/app_flutter/quotes.db").absolutePath) } catch (_: Throwable) {}
    try { candidates.add(File(ctx.filesDir, "quotes.db").absolutePath) } catch (_: Throwable) {}
    val distinct = candidates.distinct().filter { it.isNotBlank() }
    for (path in distinct) {
      try {
        val f = File(path)
        if (f.exists()) return SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE)
      } catch (_: Throwable) {}
    }
    // 桌面小组件可能在用户打开 Flutter 前被点击。此时直接创建 Flutter 文档目录下的同名数据库，
    // 后续 AppDatabase 会打开同一个文件；ensureTable 会保证行为观察表先存在。
    val fallback = distinct.firstOrNull() ?: return null
    return try {
      val f = File(fallback)
      try { f.parentFile?.mkdirs() } catch (_: Throwable) {}
      SQLiteDatabase.openOrCreateDatabase(f, null)
    } catch (_: Throwable) { null }
  }

  private fun ensureTable(db: SQLiteDatabase) {
    db.execSQL("""
      CREATE TABLE IF NOT EXISTS $TABLE (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        record_date_ms INTEGER NOT NULL,
        mode TEXT,
        entry_mode TEXT,
        template_key TEXT,
        method_name TEXT,
        primary_layer TEXT,
        category TEXT,
        title TEXT,
        source TEXT,
        privacy_level TEXT,
        start_minute INTEGER,
        end_minute INTEGER,
        behavior TEXT,
        reason TEXT,
        outcome TEXT,
        emotion TEXT,
        emotion_intensity INTEGER,
        trigger_text TEXT,
        cognition TEXT,
        reaction TEXT,
        automatic_thought TEXT,
        short_term_result TEXT,
        long_term_impact TEXT,
        environment TEXT,
        body_state TEXT,
        sleep TEXT,
        steps INTEGER,
        exercise_min INTEGER,
        notes TEXT,
        tags_json TEXT,
        template_answers_json TEXT
      )
    """.trimIndent())
    val needed = linkedMapOf(
      "entry_mode" to "TEXT", "template_key" to "TEXT", "method_name" to "TEXT", "primary_layer" to "TEXT",
      "source" to "TEXT", "privacy_level" to "TEXT", "behavior" to "TEXT", "unit" to "TEXT",
      "planned_value" to "REAL", "completion_state" to "TEXT", "evidence_type" to "TEXT",
      "outcome" to "TEXT", "cognition" to "TEXT", "automatic_thought" to "TEXT", "short_term_result" to "TEXT",
      "long_term_impact" to "TEXT", "environment" to "TEXT", "body_state" to "TEXT", "notes" to "TEXT", "tags_json" to "TEXT",
      "focus_score" to "INTEGER", "actual_value" to "REAL", "location_type" to "TEXT", "people_context" to "TEXT",
      "phone_distance" to "TEXT", "start_minute" to "INTEGER", "end_minute" to "INTEGER", "sleep" to "TEXT",
      "steps" to "INTEGER", "exercise_min" to "INTEGER", "trigger_text" to "TEXT", "reaction" to "TEXT", "reason" to "TEXT",
      "template_answers_json" to "TEXT"
    )
    val existing = HashSet<String>()
    var c: Cursor? = null
    try {
      c = db.rawQuery("PRAGMA table_info($TABLE)", null)
      while (c.moveToNext()) existing.add(c.getString(1))
    } finally {
      try { c?.close() } catch (_: Throwable) {}
    }
    for ((name, type) in needed) {
      if (!existing.contains(name)) {
        try { db.execSQL("ALTER TABLE $TABLE ADD COLUMN $name $type") } catch (_: Throwable) {}
      }
    }
  }

  private fun dayStartMs(now: Long): Long {
    val cal = Calendar.getInstance()
    cal.timeInMillis = now
    cal.set(Calendar.HOUR_OF_DAY, 0)
    cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    return cal.timeInMillis
  }


  private fun opt(obj: org.json.JSONObject, key: String): String = try { obj.optString(key, "").trim() } catch (_: Throwable) { "" }

  private fun firstNonBlank(obj: org.json.JSONObject, keys: List<String>): String {
    for (key in keys) {
      val value = opt(obj, key)
      if (value.isNotBlank()) return value
    }
    return ""
  }

  private fun shortText(text: String, max: Int): String {
    val clean = text.trim().replace("\n", " ")
    return if (clean.length > max) clean.substring(0, max) + "…" else clean
  }

  private fun parseIntOrNull(text: String): Int? {
    val clean = text.trim()
    if (clean.isEmpty()) return null
    return clean.toIntOrNull()
  }

  private fun parseDoubleOrNull(text: String): Double? {
    val clean = text.trim()
    if (clean.isEmpty()) return null
    return clean.toDoubleOrNull()
  }

  private fun parseMinuteOfDay(text: String): Int? {
    val clean = text.trim()
    if (clean.isEmpty()) return null
    val parts = clean.split(":", "：")
    if (parts.size < 2) return null
    val h = parts[0].toIntOrNull() ?: return null
    val m = parts[1].take(2).toIntOrNull() ?: return null
    if (h !in 0..23 || m !in 0..59) return null
    return h * 60 + m
  }

  private fun normalizeLayer(layer: String?): String {
    val raw = (layer ?: "").trim()
    return when {
      raw.contains("时间") -> "时间层面"
      raw.contains("行为") -> "行为层面"
      raw.contains("情绪") -> "情绪层面"
      raw.contains("认知") || raw.contains("想法") -> "认知层面"
      raw.contains("结果") -> "结果层面"
      raw.contains("环境") -> "环境层面"
      raw.contains("身体") || raw.contains("睡眠") || raw.contains("精力") -> "身体状态层面"
      else -> "行为层面"
    }
  }

  private fun templateKeyOf(layer: String): String = when (layer) {
    "时间层面" -> "time_block"
    "行为层面" -> "quick_capture"
    "情绪层面" -> "emotion_thought"
    "认知层面" -> "emotion_thought"
    "结果层面" -> "tbr"
    "环境层面" -> "full_observation"
    "身体状态层面" -> "body_snapshot"
    else -> "quick_capture"
  }

  private fun categoryOf(layer: String): String = when (layer) {
    "身体状态层面" -> "休息"
    else -> "未分类"
  }

  private fun titleOf(layer: String, content: String): String {
    val short = if (content.length > 18) content.substring(0, 18) + "…" else content
    return "通知记录 · ${layer.replace("层面", "")}：$short"
  }
}
