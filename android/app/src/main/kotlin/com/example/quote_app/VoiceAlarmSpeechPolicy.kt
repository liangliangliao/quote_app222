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

  private val phraseBoundary = Regex("[，。！？、；：,.!?;:\\s]+")

  // ASR can drop a short word in the middle of otherwise verbatim Chinese playback.
  // Require anchors on both sides and never discard novel words from the transcript.
  private fun hasInternalOmission(spoken: String, candidate: String, partial: Boolean): Boolean {
    val minLength = if (partial) 4 else 6
    if (candidate.length < minLength) return false
    val anchor = candidate.take(2)
    var start = spoken.indexOf(anchor)
    while (start >= 0) {
      var matched = 2
      while (matched < candidate.length && start + matched < spoken.length &&
        spoken[start + matched] == candidate[matched]) matched++
      // Try earlier split points too, in case the omitted word starts with a repeated character.
      for (split in 2..minOf(matched, candidate.length - 2)) {
        for (gap in 1..2) {
          val after = start + split + gap
          if (after > spoken.length || !spoken.regionMatches(after, candidate, split, candidate.length - split)) continue
          if (spoken.substring(start + split, after).none { it in "不没别勿甭未莫" }) return true
        }
      }
      start = spoken.indexOf(anchor, start + 1)
    }
    return false
  }

  // Only near-verbatim playback captured during playback can be echo. Do not delete
  // matching phrases from a user's sentence: "不要关闭闹钟" must retain its negation.
  fun isEcho(text: String, sources: List<String>, overlapsPlayback: Boolean, partial: Boolean = false): Boolean {
    if (!overlapsPlayback) return false
    val candidate = normalized(text)
    if (candidate.length < 2) return false
    val containsHan = candidate.any { Character.UnicodeScript.of(it.code) == Character.UnicodeScript.HAN }
    return sources.any { source ->
      val spoken = normalized(source)
      when {
        spoken == candidate -> true
        containsHan && hasInternalOmission(spoken, candidate, partial) -> true
        partial -> spoken.contains(candidate)
        candidate.length >= 8 || (containsHan && candidate.length >= 4) -> spoken.contains(candidate)
        containsHan -> source.split(phraseBoundary).any { normalized(it) == candidate }
        else -> false
      }
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
