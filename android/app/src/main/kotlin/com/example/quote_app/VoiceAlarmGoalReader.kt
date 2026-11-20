package com.example.quote_app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.time.Instant
import org.json.JSONArray

/** Read current local state at alarm time. Never reads chats, secrets, body_html or raw_json. */
object VoiceAlarmGoalReader {
  private const val RECENT_MS = 30L * 24 * 60 * 60 * 1000
  fun read(context: Context, now: Long = System.currentTimeMillis()): List<String> {
    val file = File(context.applicationInfo.dataDir, "app_flutter/quotes.db")
    if (!file.isFile) return emptyList() // Includes direct boot before unlock.
    val result = mutableListOf<Pair<Long, String>>()
    try {
      SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
        // Each independently optional module may not have created its table yet.
        try {
          val cutoff = Instant.ofEpochMilli(now - RECENT_MS).toString()
          db.rawQuery("""SELECT title, last_modified_date_time, due_date_time FROM ms_todo_tasks
            WHERE local_deleted = 0 AND COALESCE(status,'') NOT IN ('completed','deleted')
            AND (last_modified_date_time >= ? OR is_my_day = 1 OR (due_date_time >= ? AND due_date_time < ?))
            ORDER BY is_my_day DESC, last_modified_date_time DESC LIMIT 5""", arrayOf(cutoff, java.time.LocalDate.now(java.time.ZoneId.of("Asia/Shanghai")).toString(), java.time.LocalDate.now(java.time.ZoneId.of("Asia/Shanghai")).plusDays(8).toString())).use { c ->
            while (c.moveToNext()) {
              val title = c.getString(0).orEmpty().trim().take(160)
              val at = runCatching { Instant.parse(c.getString(1)).toEpochMilli() }.getOrDefault(now)
              if (title.isNotEmpty()) result.add(at to "待办：$title")
            }
          }
        } catch (_: Exception) {}
        try {
          db.rawQuery("""SELECT title, first_action, updated_at_ms FROM woop_action_cards
            WHERE updated_at_ms >= ? AND COALESCE(status,'active') = 'active'
            ORDER BY updated_at_ms DESC LIMIT 3""", arrayOf((now - RECENT_MS).toString())).use { c ->
            while (c.moveToNext()) {
              val title = c.getString(0).orEmpty().trim().take(120)
              val action = c.getString(1).orEmpty().trim().take(100)
              if (title.isNotEmpty()) result.add(c.getLong(2) to "WOOP 行动：$title${if (action.isEmpty()) "" else "，第一步：$action"}")
            }
          }
        } catch (_: Exception) {}
        try {
          db.rawQuery("SELECT value FROM notify_config WHERE key = ? LIMIT 1", arrayOf("goal_setting_module_actions_v1")).use { c ->
            if (c.moveToFirst()) {
              val items = JSONArray(c.getString(0))
              for (i in 0 until items.length()) {
                val item = items.optJSONObject(i) ?: continue
                val at = item.optLong("createdAt")
                val title = item.optString("title").trim().take(160)
                if (at >= now - RECENT_MS && title.isNotEmpty() && item.optString("status", "todo") in setOf("todo", "doing"))
                  result.add(at to "目标行动：$title")
              }
            }
          }
        } catch (_: Exception) {}
      }
    } catch (_: Exception) {} // Missing/locked/migrating DB must never silence an alarm.
    return result.sortedByDescending { it.first }.map { it.second }.distinct().take(3)
  }
}
