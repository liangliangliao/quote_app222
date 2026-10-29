package com.example.quote_app

import java.util.ArrayDeque
import java.util.Locale

/** Acoustic cues are VAD, not speaker identity. Never infer "not a person" from ASR no-match. */
object VoiceAlarmSpeechPolicy {
  const val FRAME_MS = 20
  const val FRAME_BYTES = 640 // PCM16, mono, 16 kHz
  const val FINAL_COMMIT_MS = 300L
  const val CLOUD_TTS_DEADLINE_MS = 5000L

  fun isVoice(rms: Int, peak: Int, zcr: Int, crest: Int, voiced: Int, noise: Double): Boolean =
    rms >= maxOf(70.0, noise * 2.2) &&
      peak >= maxOf(180.0, noise * 4.0) &&
      zcr in 5..300 && crest in 165..3000 && voiced >= 25

  /** A rolling 240 ms window tolerates unvoiced consonants/brief gaps without losing a quiet onset. */
  class StartWindow {
    private val frames = ArrayDeque<Boolean>()
    fun accept(voice: Boolean): Boolean {
      frames.addLast(voice)
      if (frames.size > 12) frames.removeFirst()
      return voice && frames.count { it } >= 6
    }
    fun reset() = frames.clear()
  }

  fun normalized(text: String): String = text.lowercase(Locale.ROOT).filter { it.isLetterOrDigit() }

  // Only near-verbatim playback captured during playback can be echo. Do not delete
  // matching phrases from a user's sentence: "不要关闭闹钟" must retain its negation.
  fun isEcho(text: String, sources: List<String>, overlapsPlayback: Boolean): Boolean {
    if (!overlapsPlayback) return false
    val candidate = normalized(text)
    if (candidate.length < 4) return false
    return sources.any { source ->
      val spoken = normalized(source)
      spoken.length >= 4 && (spoken == candidate ||
        (candidate.length >= 8 && spoken.contains(candidate)))
    }
  }
}

/** The provider's corrected sequence is authoritative; a longer old draft is not more accurate. */
class VoiceAlarmTranscript {
  private val segments = sortedMapOf<Int, String>()
  private val replaced = mutableListOf<IntRange>()

  @Synchronized
  fun apply(sn: Int, text: String, start: Int? = null, end: Int? = null): String {
    if (sn >= 0 && replaced.any { sn in it }) return segments.values.joinToString("").trim()
    if (start != null && end != null) {
      val range = minOf(start, end)..maxOf(start, end)
      segments.keys.removeAll { it in range }
      // Keep the correction at its own sequence number. Later corrections refer to
      // that number, not the start of the previously replaced range.
      if (sn >= 0) segments[sn] = text else segments[range.first] = text
      replaced.add(range)
    } else if (sn >= 0 && replaced.none { sn in it }) {
      segments[sn] = text
    }
    return segments.values.joinToString("").trim()
  }
}

/** A late network result/completion callback must never revive an interrupted reply. */
class VoiceAlarmReplyGate {
  private var generation = 0L
  @Synchronized fun next(): Long = ++generation
  @Synchronized fun isCurrent(token: Long): Boolean = token == generation
}
