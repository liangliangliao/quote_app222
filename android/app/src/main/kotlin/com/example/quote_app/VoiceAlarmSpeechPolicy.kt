package com.example.quote_app

import java.util.ArrayDeque
import java.util.Locale

/** Acoustic cues are VAD, not speaker identity. Never infer "not a person" from ASR no-match. */
object VoiceAlarmSpeechPolicy {
  const val FRAME_MS = 20
  const val PCM_BYTES_PER_MS = 32 // PCM16, mono, 16 kHz
  const val FRAME_BYTES = FRAME_MS * PCM_BYTES_PER_MS
  const val FINAL_COMMIT_MS = 300L
  const val CLOUD_TTS_DEADLINE_MS = 5000L

  fun isVoice(rms: Int, peak: Int, zcr: Int, crest: Int, voiced: Int, noise: Double): Boolean =
    rms >= maxOf(70.0, noise * 2.2) &&
      peak >= maxOf(180.0, noise * 4.0) &&
      zcr in 5..300 && crest in 165..3000 && voiced >= 25

  fun canMuteMusic(output: String, rms: Int, peak: Int): Boolean =
    output != "voice" || (rms >= 700 && peak >= 2200)

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

/** Accept a clean final from an open conversation or a direct question during alarm standby. */
object VoiceAlarmConversationGate {
  enum class Route { ECHO, DRAFT, IGNORE, REVIEW, RELISTEN, OPEN_MIC, LOCAL, SEND }
  enum class RetryReason { INCOMPLETE, PLAYBACK_OVERLAP }
  data class Decision(val route: Route, val text: String, val retryReason: RetryReason? = null)
  private val interruptPhrases = setOf("打断一下", "请打断一下", "先听我说", "请先听我说", "先暂停播报", "请暂停播报")
  private val address = Regex("""^(小名小名|闹钟助手|你好AI|AI助手|(?:小名|助手)(?=$|[\s，。！？、：,:.!?]))[\s，。！？、：,:.!?]*""", RegexOption.IGNORE_CASE)
  // Android recognition often omits question marks. Use grammatical cues, keeping the original transcript.
  private val questionStart = Regex("^(?:为什么|为何|怎么|怎样|如何|能否|可否|能不能|可不可以|是不是|要不要|有没有).+")
  private val questionWords = Regex("(?:什么|谁|哪里|哪儿|哪[个位种些天年本条项部]|多少|几[个位种天点分秒次岁条件篇项名本部]|为什么|为何|怎么|怎样|如何|在不在|听不听得[见到])")
  private val reportedSpeech = Regex("^(?:[我你他她您]们?|大家|有人|别人)?(?:已经|早就|也)?(?:不知道|知道|记得|听说|在讨论|问过|告诉过|说过|想知道)")
  private val indefinite = Regex("^(?:无论|不管|随便).+|.+(?:都可以|都行|都一样|都没关系)$")
  private val directRequest = Regex("^(?:请问|能帮我|请?(?:帮我|提醒我|告诉我|介绍一下|解释一下|说说|讲讲)).+|^(?:继续说|继续讲|接着说|接着讲|换一个|陪我聊聊|跟我聊聊|我(?:已经|刚)?(?:起床|起来|醒)了)$")

  private fun isDirectQuestion(text: String): Boolean {
    val normalized = VoiceAlarmSpeechPolicy.normalized(text)
    if (normalized.length < 3) return false
    if (text.endsWith('？') || text.endsWith('?')) return true
    if (indefinite.matches(normalized)) return false
    return questionStart.matches(normalized) || normalized.endsWith('吗') ||
      (!reportedSpeech.containsMatchIn(normalized) && questionWords.containsMatchIn(normalized))
  }

  fun isInterruption(text: String) = VoiceAlarmSpeechPolicy.normalized(text) in interruptPhrases

  fun withoutAddress(text: String): String =
    address.find(text)?.let { text.substring(it.range.last + 1).trim() } ?: text

  fun canPauseForSpeech(text: String): Boolean = isInterruption(text) || address.containsMatchIn(text) || looksDirected(text)

  private fun looksDirected(text: String): Boolean = isDirectQuestion(text) || directRequest.matches(VoiceAlarmSpeechPolicy.normalized(text))

  fun decide(raw: String, sources: List<String>, mixed: Boolean, final: Boolean, reliable: Boolean,
             armed: Boolean, localCommand: Boolean, passive: Boolean, overlapConfirmed: Boolean = false,
             stableDraft: Boolean = false, nearEndSpeech: Boolean = false, spokenPlayback: Boolean = false): Decision {
    val text = raw.trim()
    val prefix = address.find(text)
    val question = prefix?.let { text.substring(it.range.last + 1).trim() }
    val normalized = VoiceAlarmSpeechPolicy.normalized(text)
    val opensMic = question?.isEmpty() == true || normalized in interruptPhrases
    val directed = armed || question != null || looksDirected(text) || localCommand || opensMic
    val matchesRequest = question?.isNotEmpty() == true || looksDirected(text)
    val corroboratedRequest = nearEndSpeech && reliable && !localCommand && matchesRequest
    val unverifiedOverlap = (mixed || sources.isNotEmpty()) && !overlapConfirmed && !corroboratedRequest
    val usableDraft = stableDraft && !unverifiedOverlap && !localCommand && !opensMic && looksDirected(question ?: text)
    val route = when {
      text.isEmpty() -> Route.DRAFT
      VoiceAlarmSpeechPolicy.isEcho(text, sources, sources.isNotEmpty(), partial = !final) -> Route.ECHO
      !final -> Route.DRAFT
      // A delayed final from a turn that heard our speaker cannot become a chat
      // message or execute a command, even if the microphone was quiet later.
      spokenPlayback && !opensMic -> return if (localCommand || question != null || (matchesRequest && overlapConfirmed)) {
        Decision(Route.RELISTEN, "", RetryReason.PLAYBACK_OVERLAP)
      } else Decision(Route.IGNORE, "")
      !reliable && !usableDraft -> return if (directed) Decision(Route.RELISTEN, "", RetryReason.INCOMPLETE) else Decision(Route.IGNORE, "")
      opensMic && sources.any {
        VoiceAlarmSpeechPolicy.normalized(it).contains(VoiceAlarmSpeechPolicy.normalized(text))
      } -> Route.ECHO
      opensMic -> Route.OPEN_MIC
      unverifiedOverlap && !directed && nearEndSpeech -> Route.REVIEW
      unverifiedOverlap -> return if (directed) Decision(Route.RELISTEN, "", RetryReason.PLAYBACK_OVERLAP) else Decision(Route.IGNORE, "")
      localCommand -> Route.LOCAL
      armed || question != null || (passive && directed) -> Route.SEND
      else -> Route.IGNORE
    }
    return Decision(route, if (route == Route.SEND || route == Route.LOCAL) question ?: text else text)
  }
}

data class VoiceAlarmFrameStamp(val windowId: Long, val outputEpoch: Long, val output: String,
                                val spokenOutput: Boolean = output == "voice")

/** Immutable at the microphone endpoint. Network delays cannot erase a playback overlap. */
class VoiceAlarmCapture(private val initialEpoch: Long, initiallyMixed: Boolean,
                        initialOutput: String = if (initiallyMixed) "active" else "quiet", val windowId: Long = 0L,
                        private val initialSpokenEpoch: Long? = null, startedDuringSpokenOutput: Boolean = false) {
  private val sources = linkedSetOf<String>()
  private var mixed = initiallyMixed
  private var cause = if (initiallyMixed) "start_" + initialOutput else "none"
  private var spokenPlayback = startedDuringSpokenOutput
  private var frameSpokenOutput = false
  private var sealed = false
  data class Evidence(
    val sources: List<String>,
    val mixed: Boolean,
    val mixCause: String = if (mixed) "unknown" else "none",
    val windowId: Long = 0L,
    val quietSpeech: Boolean = false,
    val confirmedCue: String = "",
    val nearEndSpeech: Boolean = false,
    val spokenPlayback: Boolean = false,
  ) {
    val hasPlaybackOverlap get() = spokenPlayback || mixed || sources.isNotEmpty()
    fun belongsTo(activeWindow: Long) = activeWindow != 0L && windowId == activeWindow
    fun matchesConfirmedCue(text: String) =
      confirmedCue.isNotEmpty() && VoiceAlarmSpeechPolicy.normalized(text).startsWith(confirmedCue)
    val canRetryAudio get() = !spokenPlayback && (quietSpeech || nearEndSpeech || !hasPlaybackOverlap)
    // Audio merged across conversation windows is neither from the active window nor from standby.
    fun merge(other: Evidence) = Evidence((sources + other.sources).distinct(), mixed || other.mixed,
      if (mixed) mixCause else other.mixCause, if (windowId == other.windowId) windowId else -1L,
      quietSpeech = quietSpeech && other.quietSpeech, spokenPlayback = spokenPlayback || other.spokenPlayback)
  }
  private var pendingCue = ""
  private var cueAt = 0L
  private var confirmedCue = ""
  private var quietVoiceMs = 0L
  private var quietSpeech = false
  private var lastQuietLevelAt: Long? = null
  private val nearEndWindow = VoiceAlarmSpeechPolicy.StartWindow()
  private var playbackFloor = 160.0
  private var playbackFrames = 0
  private var lastPlaybackKind = ""
  private var nearEndSpeech = false
  var frameOutput = initialOutput
    private set

  // A stable, directed partial may pause spoken playback while the same turn keeps recording.
  @Synchronized fun confirmedPause(text: String, now: Long, currentSources: List<String>): Boolean {
    val cue = VoiceAlarmSpeechPolicy.normalized(text)
    val allSources = (sources + currentSources).toList()
    if (sealed || allSources.isEmpty() || cue.length < 4 || !VoiceAlarmConversationGate.canPauseForSpeech(text) ||
        VoiceAlarmSpeechPolicy.isEcho(text, allSources, true, partial = true)) {
      pendingCue = ""
      return false
    }
    if (pendingCue.isEmpty() || !cue.startsWith(pendingCue)) {
      pendingCue = cue
      cueAt = now
      return false
    }
    if (now - cueAt < 180L) return false
    sources.addAll(currentSources.filter { it.isNotBlank() })
    confirmedCue = pendingCue
    return true
  }
  @Synchronized fun noteFrame(before: VoiceAlarmFrameStamp, after: VoiceAlarmFrameStamp) {
    if (sealed) return
    frameSpokenOutput = before.spokenOutput || after.spokenOutput
    val changed = before.outputEpoch != after.outputEpoch
    frameOutput = when {
      before.output != "quiet" -> before.output
      changed -> "tail"
      else -> after.output
    }
    if (!mixed && frameOutput != "quiet") {
      mixed = true
      cause = if (changed && before.output == "quiet" && after.output == "quiet") "frame_output_changed" else "frame_" + frameOutput
    }
  }
  @Synchronized fun notePcmVoice(voice: Boolean, bytes: Int, rms: Int = 0, peak: Int = 0) {
    if (sealed) return
    if (voice && frameSpokenOutput) spokenPlayback = true
    recordQuietVoice(voice && frameOutput == "quiet", bytes.toLong() / VoiceAlarmSpeechPolicy.PCM_BYTES_PER_MS)
    if (nearEndSpeech) return
    if (frameOutput != lastPlaybackKind) {
      playbackFrames = 0
      playbackFloor = 160.0
      nearEndWindow.reset()
      lastPlaybackKind = frameOutput
    }
    if (frameOutput != "voice" && frameOutput != "music") return
    val strong = playbackFrames >= 8 && voice &&
      rms >= maxOf(700.0, playbackFloor * 2.6) && peak >= maxOf(2200.0, playbackFloor * 6.0)
    if (!strong) playbackFloor = playbackFloor * 0.94 + rms * 0.06
    playbackFrames++
    nearEndSpeech = nearEndWindow.accept(strong)
  }
  @Synchronized fun noteNativeLevel(voice: Boolean, output: String, now: Long) {
    if (sealed) return
    val previous = lastQuietLevelAt
    val quiet = voice && output == "quiet"
    lastQuietLevelAt = now.takeIf { quiet }
    if (!quiet || previous == null || now - previous !in 1L..160L) recordQuietVoice(false, 0)
    else recordQuietVoice(true, now - previous)
  }
  private fun recordQuietVoice(voice: Boolean, durationMs: Long) {
    if (quietSpeech) return
    quietVoiceMs = if (voice) quietVoiceMs + durationMs else 0
    quietSpeech = quietVoiceMs >= 60L
  }
  @Synchronized fun note(texts: List<String>) { if (!sealed) sources.addAll(texts.filter { it.isNotBlank() }) }
  @Synchronized fun hasUnmaskedAudio() = quietSpeech || (!spokenPlayback && !mixed && sources.isEmpty())
  @Synchronized fun finish(epoch: Long, audible: Boolean, output: String = if (audible) "active" else "quiet",
                           spokenEpoch: Long? = null, recentSpokenOutput: Boolean = false): Evidence {
    if (!sealed) {
      if (!mixed) cause = when { audible -> "end_" + output; epoch != initialEpoch -> "output_changed"; else -> "none" }
      mixed = mixed || epoch != initialEpoch || audible
      spokenPlayback = spokenPlayback || recentSpokenOutput || (initialSpokenEpoch != null && spokenEpoch != initialSpokenEpoch)
      sealed = true
    }
    return Evidence(sources.toList(), mixed, cause, windowId, quietSpeech, confirmedCue, nearEndSpeech, spokenPlayback)
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
