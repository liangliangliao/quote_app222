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

  // One ASR substitution inside a longer audible passage, with exact anchors on both sides.
  // Preserve question words, quantities and negations that change what the user meant.
  private fun hasInternalSubstitution(spoken: String, candidate: String): Boolean {
    if (candidate.length < 8) return false
    val protected = "不是没别勿几谁怎啥哪吗么多少零一二三四五六七八九十两"
    var start = spoken.indexOf(candidate.take(2))
    while (start >= 0 && start + candidate.length <= spoken.length) {
      var i = 2
      while (i < candidate.length && spoken[start + i] == candidate[i]) i++
      if (i in 2..candidate.length - 3 && candidate[i] !in protected && spoken[start + i] !in protected &&
          spoken.regionMatches(start + i + 1, candidate, i + 1, candidate.length - i - 1)) return true
      start = spoken.indexOf(candidate.take(2), start + 1)
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
        containsHan && hasInternalSubstitution(spoken, candidate) -> true
        containsHan && hasInternalOmission(spoken, candidate, partial) -> true
        partial -> spoken.contains(candidate)
        candidate.length >= 8 || (containsHan && candidate.length >= 4) -> spoken.contains(candidate)
        containsHan -> source.split(phraseBoundary).any { normalized(it) == candidate }
        else -> false
      }
    }
  }
}

/** Only a final, clean, explicitly addressed or user-armed turn may enter automatic dialogue. */
object VoiceAlarmConversationGate {
  enum class Route { ECHO, DRAFT, REVIEW, OPEN_MIC, LOCAL, SEND }
  data class Decision(val route: Route, val text: String)
  private val address = Regex("""^(小名小名|闹钟助手|你好AI|AI助手|(?:小名|助手)(?=$|[\s，。！？、：,:.!?]))[\s，。！？、：,:.!?]*""", RegexOption.IGNORE_CASE)

  fun decide(raw: String, sources: List<String>, mixed: Boolean, final: Boolean, reliable: Boolean,
             armed: Boolean, localCommand: Boolean): Decision {
    val text = raw.trim()
    val prefix = address.find(text)
    val question = prefix?.let { text.substring(it.range.last + 1).trim() }
    val route = when {
      text.isEmpty() -> Route.DRAFT
      VoiceAlarmSpeechPolicy.isEcho(text, sources, sources.isNotEmpty(), partial = !final) -> Route.ECHO
      !final -> Route.DRAFT
      !reliable -> Route.REVIEW
      question != null && question.isEmpty() && sources.any {
        VoiceAlarmSpeechPolicy.normalized(it).contains(VoiceAlarmSpeechPolicy.normalized(text))
      } -> Route.ECHO
      question != null && question.isEmpty() -> Route.OPEN_MIC
      localCommand -> Route.LOCAL
      mixed || sources.isNotEmpty() -> Route.REVIEW
      armed || question != null -> Route.SEND
      else -> Route.REVIEW
    }
    return Decision(route, if (route == Route.SEND && question != null) question else text)
  }
}

/** Immutable at the microphone endpoint. Network delays cannot erase a playback overlap. */
class VoiceAlarmCapture(private val initialEpoch: Long, initiallyMixed: Boolean) {
  private val sources = linkedSetOf<String>()
  private var mixed = initiallyMixed
  private var sealed = false
  data class Evidence(val sources: List<String>, val mixed: Boolean) {
    fun merge(other: Evidence) = Evidence((sources + other.sources).distinct(), mixed || other.mixed)
  }
  @Synchronized fun note(texts: List<String>) { if (!sealed) sources.addAll(texts.filter { it.isNotBlank() }) }
  @Synchronized fun finish(epoch: Long, audible: Boolean): Evidence {
    if (!sealed) { mixed = mixed || epoch != initialEpoch || audible; sealed = true }
    return Evidence(sources.toList(), mixed)
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
