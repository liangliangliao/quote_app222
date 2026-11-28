package com.example.quote_app

import org.json.JSONArray
import org.json.JSONObject

internal object VoiceAlarmWakeupHistory {
  data class Record(val content: WakeupContent, val fetchedAt: Long, val scheduledTask: Boolean)

  fun read(date: String, items: JSONArray): List<Record> =
    (0 until items.length()).mapNotNull { index ->
      val item = items.optJSONObject(index) ?: return@mapNotNull null
      val content = WakeupContent(date, item.optString("text"), item.optString("id"),
        item.optString("title"), item.optString("scheduledTime"))
      // Older archives lack a task flag. Keep untimed tasks and exclude the standard backup reminder.
      val scheduledTask = item.optBoolean("scheduledTask",
        content.scheduledTime.isNotBlank() || content.title != "今日播报")
      Record(content, item.optLong("fetchedAt"), scheduledTask)
    }.sortedWith(compareBy({ it.content.scheduledTime.ifBlank { "99:99" } }, { -it.fetchedAt }))

  fun replayRecords(records: List<Record>): List<Record> {
    val latestById = records.asReversed().filter {
      it.scheduledTask && it.content.id.isNotBlank() && it.content.text.isNotBlank()
    }.sortedByDescending { it.fetchedAt }.distinctBy { it.content.id }.toSet()
    return records.filter { it in latestById }.distinctBy { it.content.id }
  }

  // The archive can contain older revisions and tasks from a disabled site.
  // Keep the last confirmed task list and its playback flag together.
  fun taskSnapshot(day: WakeupDay, connection: String): JSONObject? {
    if (day.tasks.isEmpty()) return null
    return JSONObject().put("date", day.date).put("connection", connection).put("shouldRing", day.shouldRing)
      .put("tasks", JSONArray(day.tasks.map {
        JSONObject().put("id", it.id).put("text", it.text).put("title", it.title)
          .put("scheduledTime", it.scheduledTime).put("createdAt", it.createdAt)
      }))
  }

  fun cachedTaskDay(archive: JSONObject?, date: String, connection: String): WakeupDay? {
    val snapshot = archive?.optJSONObject("taskSnapshot") ?: return null
    if (snapshot.optString("date") != date || snapshot.optString("connection") != connection) return null
    val shouldRing = snapshot.opt("shouldRing") as? Boolean ?: return null
    val items = snapshot.optJSONArray("tasks") ?: return null
    val tasks = (0 until items.length()).map { index ->
      val item = items.optJSONObject(index) ?: return null
      val id = item.optString("id")
      val text = item.optString("text")
      if (id.isBlank() || text.isBlank() || text.length > 16000) return null
      WakeupContent(date, text, id, item.optString("title"), item.optString("scheduledTime"), item.optString("createdAt"))
    }
    if (tasks.isEmpty()) return null
    return WakeupDay(date, tasks, reminder = null, shouldRing = shouldRing)
  }
}

/** Owns the per-ring cursor. The last TTS chunk must finish before advancing to the next task. */
internal class VoiceAlarmHistoryReplay(private val tasks: List<WakeupContent>) {
  val total: Int get() = tasks.size
  var completed: Int = 0
    private set
  val current: WakeupContent? get() = tasks.getOrNull(completed)

  fun completeTask() {
    if (current != null) completed++
  }
}
