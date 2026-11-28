package com.example.quote_app

import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException

/** One quiet retry per alarm separates input/playback trouble from normal idle speech recognition. */
internal class VoiceAlarmIflytekInputRecovery {
  enum class Action { QUIET_RETRY, REOPEN_QUIET_INPUT }
  private var emptyPlaybackTurns = 0
  var useRawMic = false
    private set

  fun recognizedSpeech() { emptyPlaybackTurns = 0 }

  fun observe(emptyWithPlayback: Boolean, digitalSilence: Boolean, alreadyQuiet: Boolean): Action? {
    if (useRawMic) return null
    emptyPlaybackTurns = if (emptyWithPlayback) emptyPlaybackTurns + 1 else 0
    if (!digitalSilence && emptyPlaybackTurns < 2) return null
    useRawMic = true
    return if (alreadyQuiet) Action.REOPEN_QUIET_INPUT else Action.QUIET_RETRY
  }

  companion object {
    fun hasDigitalSilence(pcmReadBytes: Long, peak: Int): Boolean =
      pcmReadBytes >= 38400L && peak <= 2
  }
}

/** Keeps one continuous recording while the socket opens or its send cadence falls behind. */
internal class VoiceAlarmIflytekAudio : ByteArrayOutputStream() {
  data class Packet(val status: Int, val pcm: ByteArray)

  private val spokenLeadIn = ArrayDeque<ByteArray>()
  private var leadInBytes = 0

  /** Stream music/quiet frames immediately; retain spoken lead-in only for a local speech onset. */
  fun appendCapture(pcm: ByteArray, spokenOutput: Boolean, allowSpoken: Boolean): Boolean {
    if (spokenOutput && !allowSpoken) {
      spokenLeadIn.addLast(pcm)
      leadInBytes += pcm.size
      while (leadInBytes > 38400) leadInBytes -= spokenLeadIn.removeFirst().size
      return false
    }
    if (spokenOutput) for (frame in spokenLeadIn) write(frame)
    spokenLeadIn.clear()
    leadInBytes = 0
    write(pcm)
    return true
  }

  fun nextSendAt(previousDue: Long, sentBytes: Int, now: Long): Long {
    // Make up a small backlog from connecting/finalizing without sending a burst.
    val interval = if (size() - sentBytes >= 12800) 30L else 40L
    return maxOf((previousDue.takeIf { it > 0L } ?: now) + interval, now + 20L)
  }

  fun packet(offset: Int, finishing: Boolean): Packet? {
    val remaining = size() - offset
    if (remaining <= 0 || (!finishing && remaining < 2560)) return null
    val count = minOf(1280, remaining)
    val status = when {
      offset == 0 -> 0
      finishing && remaining == count -> 2
      else -> 1
    }
    return Packet(status, buf.copyOfRange(offset, offset + count))
  }
}

/** An early server final covers a prefix. Open a new stream for the unsent audio. */
internal object VoiceAlarmIflytekRecovery {
  data class Result(val text: String, val sentBytes: Int)

  private const val CHUNK_BYTES = 12 * 1000 * VoiceAlarmSpeechPolicy.PCM_BYTES_PER_MS
  private const val OVERLAP_BYTES = 400 * VoiceAlarmSpeechPolicy.PCM_BYTES_PER_MS
  private const val MIN_PROGRESS_BYTES = 800 * VoiceAlarmSpeechPolicy.PCM_BYTES_PER_MS

  fun finish(pcm: ByteArray, prefix: Result, transcribe: (ByteArray) -> Result,
             merge: (String, String) -> String): String {
    var text = prefix.text
    var covered = prefix.sentBytes.coerceIn(0, pcm.size)
    var attempts = 0
    while (covered < pcm.size && attempts++ < 8) {
      val overlap = if (text.isBlank()) 0 else OVERLAP_BYTES
      val start = (covered - overlap).coerceAtLeast(0)
      val end = minOf(start + CHUNK_BYTES, pcm.size)
      val result = transcribe(pcm.copyOfRange(start, end))
      val sentThrough = start + result.sentBytes.coerceIn(0, end - start)
      if (sentThrough < pcm.size && sentThrough - covered < MIN_PROGRESS_BYTES) {
        throw IOException("iFlytek ended before making progress on the unsent recording")
      }
      text = merge(text, result.text)
      covered = sentThrough
    }
    if (covered < pcm.size) throw IOException("iFlytek retry did not cover all recorded speech")
    return text
  }
}

/** The IAT result envelope can terminate a stream without another word fragment. */
class VoiceAlarmIflytekTranscript {
  data class Update(val text: String, val code: Int, val sequence: Int, val correction: String, val complete: Boolean)

  private val transcript = VoiceAlarmTranscript()
  @Volatile var text = ""
    private set
  @Volatile var complete = false
    private set

  fun outcome(audioInterrupted: Boolean, voiceEndByte: Int, sentBytes: Int, transportFailure: String?,
              microphoneTimedOut: Boolean = false, quietSpeech: Boolean = false,
              speechExpected: Boolean = true): String = when {
    audioInterrupted -> "microphone_interrupted"
    complete && voiceEndByte > sentBytes -> "unsent_speech_tail"
    transportFailure != null -> transportFailure
    microphoneTimedOut -> "microphone_no_frames"
    !speechExpected && text.isBlank() -> "idle_no_words"
    !complete -> "missing_final"
    text.isBlank() && voiceEndByte > 0 && quietSpeech -> "empty_final_with_speech"
    text.isBlank() -> "empty_final"
    else -> "final"
  }

  @Synchronized fun accept(message: String): Update? {
    if (complete) return null
    val envelope = runCatching { JSONObject(message) }.getOrNull() ?: return null
    val code = envelope.optInt("code", -1)
    val data = envelope.optJSONObject("data")
    val result = data?.optJSONObject("result")
    val sequence = result?.optInt("sn", -1) ?: -1
    val correction = result?.optString("pgs", "").orEmpty()
    if (code == 0) {
      if (result != null && sequence >= 0) {
        val words = result.optJSONArray("ws")
        val fragment = buildString {
          for (i in 0 until (words?.length() ?: 0)) {
            val word = words?.optJSONObject(i)?.optJSONArray("cw")?.optJSONObject(0)?.optString("w", "").orEmpty()
            if (word.isNotBlank()) append(word)
          }
        }
        val range = if (correction == "rpl") replacement(result.opt("rg")) else null
        // A terminal envelope with no words must not erase an earlier fragment at the same sequence.
        if (fragment.isNotEmpty() || range != null) text = transcript.apply(sequence, fragment, range?.first, range?.last)
      }
      complete = data?.optInt("status", -1) == 2 || result?.optBoolean("ls", false) == true
    }
    return Update(text, code, sequence, correction, complete)
  }

  private fun replacement(raw: Any?): IntRange? {
    val numbers = when (raw) {
      is JSONArray -> if (raw.length() >= 2) listOf(raw.optInt(0, -1), raw.optInt(1, -1)) else emptyList()
      is String -> Regex("-?\\d+").findAll(raw).take(2).mapNotNull { it.value.toIntOrNull() }.toList()
      else -> emptyList()
    }
    if (numbers.size != 2 || numbers.any { it < 0 }) return null
    return minOf(numbers[0], numbers[1])..maxOf(numbers[0], numbers[1])
  }
}
