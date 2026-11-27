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
  enum class Speaker { REMINDER, ASSISTANT, USER, LISTEN_REQUEST, QUIET_CAPTURE }
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

  fun gain(volume: Float): Float {
    if (!enabled || speaking(Speaker.USER) || speaking(Speaker.QUIET_CAPTURE)) return 0f
    val configured = volume.coerceIn(0f, 1f)
    return if (speaking(Speaker.REMINDER) || speaking(Speaker.ASSISTANT)) configured * 0.22f else configured
  }
}

/** Counts audible playing time before the initial reminder. */
internal class VoiceAlarmMusicIntro(durationMs: Long) {
  enum class Output { PREPARING, AUDIBLE, TEMPORARILY_MUTED, UNAVAILABLE }

  private var remainingMs = durationMs
  private var audibleSince: Long? = null
  private var prepareDeadline: Long? = null

  // Zero means start the voice. Null means a temporary microphone mute will
  // notify us through the mixer when music becomes audible again.
  fun nextCheckDelay(now: Long, output: Output): Long? {
    audibleSince?.let { remainingMs -= (now - it).coerceAtLeast(0) }
    audibleSince = now.takeIf { output == Output.AUDIBLE }
    if (remainingMs <= 0) return 0
    if (output != Output.PREPARING) prepareDeadline = null
    return when (output) {
      Output.AUDIBLE -> remainingMs
      Output.TEMPORARILY_MUTED -> null
      Output.PREPARING -> {
        val deadline = prepareDeadline ?: (now + 4000L).also { prepareDeadline = it }
        (deadline - now).coerceAtLeast(0)
      }
      Output.UNAVAILABLE -> 0
    }
  }
}
