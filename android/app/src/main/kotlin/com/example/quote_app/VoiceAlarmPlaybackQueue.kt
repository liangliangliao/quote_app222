package com.example.quote_app

/** One acknowledged chunk at a time; stale callbacks cannot advance a new session. */
class VoiceAlarmPlaybackQueue {
  data class Item(val id: String, val text: String)
  private var generation = 0L
  private var parts = emptyList<String>()
  private var index = 0
  private var attempts = 0
  var fullText = ""; private set
  val pending: Boolean get() = index < parts.size
  val current: Item? get() = if (pending) Item("voice_${generation}_${index}_$attempts", parts[index]) else null
  fun start(text: String, limit: Int = 180): Item? {
    cancel(); fullText = text; parts = VoiceAlarmTextChunks.split(text, limit); return current
  }
  fun done(id: String?): Boolean {
    if (id == null || id != current?.id) return false
    index++; attempts = 0; return true
  }
  fun retry(id: String?): Item? {
    if (id == null || id != current?.id || attempts >= 2) return null
    attempts++; return current
  }
  fun resume(): Item? { generation++; attempts = 0; return current }
  fun cancel() { generation++; parts = emptyList(); index = 0; attempts = 0; fullText = "" }
}

/** Explicit music choice survives temporary microphone ducking and volume changes. */
class VoiceAlarmMusicState {
  var enabled = true; private set
  var duckUntil = 0L; private set
  fun choose(play: Boolean) { enabled = play; duckUntil = 0 }
  fun duck(now: Long, durationMs: Long) { duckUntil = maxOf(duckUntil, now + durationMs) }
  fun gain(now: Long, volume: Float): Float = if (enabled && now >= duckUntil) volume.coerceIn(0f, 1f) else 0f
}
