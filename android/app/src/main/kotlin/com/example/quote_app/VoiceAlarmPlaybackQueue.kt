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

/** The foreground service and its activity update this mixer on the main thread. */
class VoiceAlarmMusicState {
  enum class Speaker { REMINDER, ASSISTANT, USER }
  private val speakers = mutableMapOf<Speaker, Any>()
  var enabled = true
    private set

  fun choose(play: Boolean) { enabled = play }
  fun speaking(speaker: Speaker): Boolean = speaker in speakers

  // An old activity or recorder finishing cannot release a newer owner's mute.
  fun setSpeaking(speaker: Speaker, owner: Any, active: Boolean): Boolean {
    if (active) return speakers.put(speaker, owner) !== owner
    if (speakers[speaker] !== owner) return false
    speakers.remove(speaker)
    return true
  }

  fun gain(volume: Float): Float = if (enabled && speakers.isEmpty()) volume.coerceIn(0f, 1f) else 0f
}
