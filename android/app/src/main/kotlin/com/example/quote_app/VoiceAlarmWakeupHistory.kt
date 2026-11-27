package com.example.quote_app

import org.json.JSONArray

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
