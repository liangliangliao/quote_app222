package com.example.quote_app

import android.Manifest
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.ContentUris
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.example.quote_app.data.DbInspector
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlinx.coroutines.runBlocking

/**
 * V15 行为观察：原生自动导入器。
 *
 * 该类在 Flutter 不运行时也能被 AlarmReceiver 调用：
 * - 自动读取 UsageStatsManager 今日屏幕使用时间；
 * - 自动读取 CalendarContract 未来日历时间块；
 * - 自动读取 Health Connect 今日身体数据摘要；
 * - 写入 behavior_tracking_import_queue，等待用户确认。
 */
object BehaviorObservationNativeImporter {
  private const val QUEUE_TABLE = "behavior_tracking_import_queue"

  @JvmStatic
  fun runAutoSync(ctx: Context, payload: String?): String {
    val appCtx = ctx.applicationContext
    val obj = try { JSONObject(payload ?: "{}") } catch (_: Throwable) { JSONObject() }
    val sourceKey = obj.optString("sourceKey", "all")
    val lookaheadDays = obj.optInt("lookaheadDays", 7).coerceIn(0, 30)
    val result = JSONObject()
    var usageCount = 0
    var calendarCount = 0
    var healthCount = 0
    var message = ""
    val db = openAppDb(appCtx)
    if (db == null) {
      result.put("ok", false)
      result.put("message", "未找到应用数据库，无法写入待确认队列。")
      return result.toString()
    }
    try {
      ensureQueueTable(db)
      if (sourceKey == "screen_usage" || sourceKey == "all") {
        usageCount = importUsage(appCtx, db)
      }
      if (sourceKey == "calendar" || sourceKey == "all") {
        calendarCount = importCalendar(appCtx, db, lookaheadDays)
      }
      if (sourceKey == "health_connect" || sourceKey == "all") {
        healthCount = importHealthConnect(appCtx, db)
      }
      message = "屏幕使用 $usageCount 条，日历 $calendarCount 条，健康数据 $healthCount 条。"
      result.put("ok", true)
      result.put("usage", usageCount)
      result.put("calendar", calendarCount)
      result.put("health", healthCount)
      result.put("message", message)
    } catch (t: Throwable) {
      result.put("ok", false)
      result.put("message", t.message ?: t.javaClass.simpleName)
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
    return result.toString()
  }

  private fun importUsage(ctx: Context, db: SQLiteDatabase): Int {
    if (!hasUsageAccess(ctx)) return 0
    val cal = Calendar.getInstance()
    cal.set(Calendar.HOUR_OF_DAY, 0)
    cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    val startMs = cal.timeInMillis
    val endMs = System.currentTimeMillis()
    val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    val pm = ctx.packageManager
    val aggregated = usm.queryAndAggregateUsageStats(startMs, endMs)
    var count = 0
    for ((pkg, stat) in aggregated) {
      val total = stat.totalTimeInForeground
      if (total < 3 * 60 * 1000L) continue
      var label = pkg
      var appCategory = "unknown"
      try {
        val info = pm.getApplicationInfo(pkg, 0)
        label = pm.getApplicationLabel(info)?.toString() ?: pkg
        appCategory = appCategory(info)
      } catch (_: Throwable) {}
      val minutes = (total / 60000L).coerceAtLeast(1L).coerceAtMost(24L * 60L).toInt()
      val category = "屏幕使用时间"
      val record = JSONObject()
        .put("created_at_ms", System.currentTimeMillis())
        .put("updated_at_ms", System.currentTimeMillis())
        .put("record_date_ms", startMs)
        .put("mode", "time_block")
        .put("entry_mode", "screen_usage_auto_sync")
        .put("template_key", "time_block")
        .put("method_name", "系统自动读取")
        .put("primary_layer", "时间层面")
        .put("category", category)
        .put("title", "屏幕使用：$label")
        .put("source", "screen_usage_auto_sync")
        .put("privacy_level", "local_sensitive")
        .put("behavior", "使用应用：$label")
        .put("actual_value", minutes)
        .put("unit", "分钟")
        .put("notes", "系统自动读取 UsageStatsManager 聚合时长：$minutes 分钟。包名：$pkg。请确认后写入正式记录。")
        .put("tags_json", JSONArray(listOf("屏幕使用", "自动读取", label)).toString())
      val raw = JSONObject()
        .put("packageName", pkg)
        .put("appName", label)
        .put("category", appCategory)
        .put("totalTimeMs", total)
        .put("lastTimeUsedMs", stat.lastTimeUsed)
      if (upsertQueue(db, "screen_usage", "screen_${pkg}_$startMs", "屏幕使用：$label", raw, record, "自动读取屏幕使用时间；确认后才进入正式行为记录。")) count++
      if (count >= 60) break
    }
    return count
  }

  private fun importCalendar(ctx: Context, db: SQLiteDatabase, days: Int): Int {
    if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) return 0
    val cal = Calendar.getInstance()
    cal.set(Calendar.HOUR_OF_DAY, 0)
    cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    val startMs = cal.timeInMillis
    val endMs = startMs + days.coerceAtLeast(1) * 24L * 60L * 60L * 1000L
    val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
    ContentUris.appendId(builder, startMs)
    ContentUris.appendId(builder, endMs)
    val projection = arrayOf(
      CalendarContract.Instances.EVENT_ID,
      CalendarContract.Instances.TITLE,
      CalendarContract.Instances.BEGIN,
      CalendarContract.Instances.END,
      CalendarContract.Instances.EVENT_LOCATION,
      CalendarContract.Instances.DESCRIPTION,
      CalendarContract.Instances.ALL_DAY,
      CalendarContract.Instances.CALENDAR_DISPLAY_NAME
    )
    var count = 0
    var c: Cursor? = null
    try {
      c = ctx.contentResolver.query(builder.build(), projection, null, null, CalendarContract.Instances.BEGIN + " ASC")
      if (c == null) return 0
      while (c.moveToNext() && count < 120) {
        val eventId = c.getLong(0)
        val title = c.getString(1) ?: "日历事件"
        val begin = c.getLong(2)
        val end = c.getLong(3).takeIf { it > begin } ?: begin
        val location = c.getString(4) ?: ""
        val description = c.getString(5) ?: ""
        val allDay = c.getInt(6) == 1
        val calendarName = c.getString(7) ?: ""
        val start = Calendar.getInstance().apply { timeInMillis = begin }
        val finish = Calendar.getInstance().apply { timeInMillis = end }
        val sameDay = start.get(Calendar.YEAR) == finish.get(Calendar.YEAR) && start.get(Calendar.DAY_OF_YEAR) == finish.get(Calendar.DAY_OF_YEAR)
        val recordDay = Calendar.getInstance().apply {
          timeInMillis = begin
          set(Calendar.HOUR_OF_DAY, 0)
          set(Calendar.MINUTE, 0)
          set(Calendar.SECOND, 0)
          set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val category = guessCalendarCategory(title)
        val record = JSONObject()
          .put("created_at_ms", System.currentTimeMillis())
          .put("updated_at_ms", System.currentTimeMillis())
          .put("record_date_ms", recordDay)
          .put("mode", "time_block")
          .put("entry_mode", "calendar_auto_sync")
          .put("template_key", "time_block")
          .put("method_name", "系统自动读取")
          .put("primary_layer", "时间层面")
          .put("category", category)
          .put("title", "日历：$title")
          .put("source", "calendar_auto_sync")
          .put("privacy_level", "local_sensitive")
          .put("behavior", "日历时间块：$title")
          .put("start_minute", start.get(Calendar.HOUR_OF_DAY) * 60 + start.get(Calendar.MINUTE))
          .put("end_minute", if (sameDay) finish.get(Calendar.HOUR_OF_DAY) * 60 + finish.get(Calendar.MINUTE) else 23 * 60 + 59)
          .put("notes", "系统自动读取日历。位置：$location\n说明：$description\n请确认计划是否实际发生。")
          .put("tags_json", JSONArray(listOf("日历", "自动读取", "时间块", title)).toString())
        val raw = JSONObject()
          .put("eventId", eventId)
          .put("title", title)
          .put("startMs", begin)
          .put("endMs", end)
          .put("location", location)
          .put("description", description)
          .put("allDay", allDay)
          .put("calendarName", calendarName)
        if (upsertQueue(db, "calendar", "calendar_${eventId}_$begin", "日历：$title", raw, record, "自动读取系统日历；这是计划时间块，确认后才进入正式行为记录。")) count++
      }
    } finally {
      try { c?.close() } catch (_: Throwable) {}
    }
    return count
  }


  private fun importHealthConnect(ctx: Context, db: SQLiteDatabase): Int {
    return try {
      runBlocking {
        if (HealthConnectClient.getSdkStatus(ctx) != HealthConnectClient.SDK_AVAILABLE) return@runBlocking 0
        val client = HealthConnectClient.getOrCreate(ctx)
        val granted = client.permissionController.getGrantedPermissions()
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now(zone)
        val start = today.atStartOfDay(zone).toInstant()
        val end = Instant.now()
        val todayRange = TimeRangeFilter.between(start, end)
        var steps: Long? = null
        var sleepMinutes: Long? = null
        var exerciseMinutes: Long? = null

        try {
          val permission = HealthPermission.getReadPermission(StepsRecord::class)
          if (granted.contains(permission)) {
            val records = client.readRecords(ReadRecordsRequest(recordType = StepsRecord::class, timeRangeFilter = todayRange)).records
            steps = records.sumOf { it.count }
          }
        } catch (_: Throwable) {}

        try {
          val permission = HealthPermission.getReadPermission(SleepSessionRecord::class)
          if (granted.contains(permission)) {
            val sleepStart = today.minusDays(1).atStartOfDay(zone).toInstant()
            val range = TimeRangeFilter.between(sleepStart, end)
            val records = client.readRecords(ReadRecordsRequest(recordType = SleepSessionRecord::class, timeRangeFilter = range)).records
            var total = 0L
            for (r in records) {
              val s = if (r.startTime.isBefore(start)) start else r.startTime
              val e = if (r.endTime.isAfter(end)) end else r.endTime
              if (e.isAfter(s)) total += java.time.Duration.between(s, e).toMinutes()
            }
            if (total > 0L) sleepMinutes = total
          }
        } catch (_: Throwable) {}

        try {
          val permission = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
          if (granted.contains(permission)) {
            val records = client.readRecords(ReadRecordsRequest(recordType = ExerciseSessionRecord::class, timeRangeFilter = todayRange)).records
            val total = records.sumOf { java.time.Duration.between(it.startTime, it.endTime).toMinutes().coerceAtLeast(0L) }
            if (total > 0L) exerciseMinutes = total
          }
        } catch (_: Throwable) {}

        if (steps == null && sleepMinutes == null && exerciseMinutes == null) return@runBlocking 0
        val dayMs = Calendar.getInstance().apply {
          set(Calendar.HOUR_OF_DAY, 0)
          set(Calendar.MINUTE, 0)
          set(Calendar.SECOND, 0)
          set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val parts = ArrayList<String>()
        if (sleepMinutes != null) parts.add("睡眠 ${sleepMinutes} 分钟")
        if (steps != null) parts.add("步数 ${steps}")
        if (exerciseMinutes != null) parts.add("运动 ${exerciseMinutes} 分钟")
        val body = if (parts.isEmpty()) "Health Connect 今日身体数据" else parts.joinToString("；")
        val record = JSONObject()
          .put("created_at_ms", System.currentTimeMillis())
          .put("updated_at_ms", System.currentTimeMillis())
          .put("record_date_ms", dayMs)
          .put("mode", "body_snapshot")
          .put("entry_mode", "health_connect_auto_sync")
          .put("template_key", "body_snapshot")
          .put("method_name", "系统自动读取")
          .put("primary_layer", "身体状态层面")
          .put("category", "休息")
          .put("title", "Health Connect：今日身体状态")
          .put("source", "health_connect_auto_sync")
          .put("privacy_level", "local_sensitive")
          .put("behavior", "自动读取 Health Connect 今日身体状态")
          .put("body_state", body)
          .put("sleep", if (sleepMinutes != null) "约 ${sleepMinutes} 分钟" else "")
          .put("sleep_duration_min", sleepMinutes)
          .put("steps", steps)
          .put("exercise_min", exerciseMinutes)
          .put("notes", "系统自动读取 Health Connect 今日摘要。请确认后写入正式记录。")
          .put("tags_json", JSONArray(listOf("Health Connect", "健康数据", "自动读取", "身体状态")).toString())
        val raw = JSONObject()
          .put("steps", steps)
          .put("sleepMinutes", sleepMinutes)
          .put("exerciseMinutes", exerciseMinutes)
          .put("readAtMs", System.currentTimeMillis())
        if (upsertQueue(db, "health_connect", "health_$dayMs", "Health Connect：今日身体状态", raw, record, "自动读取 Health Connect 身体数据；确认后才进入正式行为记录。")) 1 else 0
      }
    } catch (_: Throwable) {
      0
    }
  }

  private fun upsertQueue(db: SQLiteDatabase, source: String, externalId: String, title: String, raw: JSONObject, record: JSONObject, note: String): Boolean {
    val now = System.currentTimeMillis()
    var existingId: Long? = null
    var c: Cursor? = null
    try {
      c = db.rawQuery("SELECT id, status FROM $QUEUE_TABLE WHERE source_key=? AND external_id=? ORDER BY updated_at_ms DESC, id DESC LIMIT 1", arrayOf(source, externalId))
      if (c.moveToFirst()) {
        // 已确认过的同一外部数据重新读取时，也重新变为 pending，
        // 让用户能看到今日数据已刷新；确认写入时 Flutter 侧会按 source+title+date 更新正式记录，避免重复累计。
        existingId = c.getLong(0)
      }
    } catch (_: Throwable) {
    } finally {
      try { c?.close() } catch (_: Throwable) {}
    }
    val values = android.content.ContentValues().apply {
      put("source_key", source)
      put("external_id", externalId)
      put("title", title)
      put("raw_json", raw.toString(2))
      put("mapped_record_json", record.toString(2))
      put("status", "pending")
      put("note", note)
      put("updated_at_ms", now)
      if (existingId == null) put("created_at_ms", now)
    }
    return if (existingId != null) {
      db.update(QUEUE_TABLE, values, "id=?", arrayOf(existingId.toString())) >= 0
    } else {
      db.insert(QUEUE_TABLE, null, values) > 0
    }
  }

  private fun ensureQueueTable(db: SQLiteDatabase) {
    db.execSQL("""
      CREATE TABLE IF NOT EXISTS $QUEUE_TABLE (
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
    """.trimIndent())
    db.execSQL("CREATE INDEX IF NOT EXISTS idx_behavior_import_status ON $QUEUE_TABLE(status, updated_at_ms DESC)")
    db.execSQL("CREATE INDEX IF NOT EXISTS idx_behavior_import_source_external ON $QUEUE_TABLE(source_key, external_id)")
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
    for (path in candidates.distinct()) {
      try {
        if (path.isBlank()) continue
        val f = File(path)
        if (!f.exists()) continue
        return SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE)
      } catch (_: Throwable) {}
    }
    return null
  }

  private fun hasUsageAccess(ctx: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return false
    return try {
      val appOps = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
      val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), ctx.packageName)
      } else {
        @Suppress("DEPRECATION")
        appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), ctx.packageName)
      }
      mode == AppOpsManager.MODE_ALLOWED
    } catch (_: Throwable) { false }
  }

  private fun appCategory(info: ApplicationInfo): String {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return "unknown"
    return when (info.category) {
      ApplicationInfo.CATEGORY_GAME -> "game"
      ApplicationInfo.CATEGORY_AUDIO -> "audio"
      ApplicationInfo.CATEGORY_VIDEO -> "video"
      ApplicationInfo.CATEGORY_IMAGE -> "image"
      ApplicationInfo.CATEGORY_SOCIAL -> "social"
      ApplicationInfo.CATEGORY_NEWS -> "news"
      ApplicationInfo.CATEGORY_MAPS -> "maps"
      ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
      else -> "unknown"
    }
  }

  private fun categoryForUsage(appCategory: String): String = when (appCategory) {
    "game", "audio", "video", "image", "social", "news" -> "娱乐"
    "productivity" -> "工作/学习"
    "maps" -> "生活事务"
    else -> "其他"
  }

  private fun guessCalendarCategory(title: String): String {
    val t = title.lowercase()
    return when {
      t.contains("study") || t.contains("work") || t.contains("meeting") || title.contains("学习") || title.contains("工作") || title.contains("会议") -> "工作/学习"
      title.contains("运动") || title.contains("健身") -> "健康"
      title.contains("家") || title.contains("购物") || title.contains("做饭") || title.contains("通勤") -> "生活事务"
      title.contains("朋友") || title.contains("聚会") || title.contains("家人") -> "人际"
      else -> "其他"
    }
  }
}
