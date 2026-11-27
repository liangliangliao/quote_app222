package com.example.quote_app

import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/** Keeps one continuous recording while the socket opens or its send cadence falls behind. */
internal class VoiceAlarmIflytekAudio : ByteArrayOutputStream() {
  data class Packet(val status: Int, val pcm: ByteArray)

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

/** The IAT result envelope can terminate a stream without another word fragment. */
class VoiceAlarmIflytekTranscript {
  data class Update(val text: String, val code: Int, val sequence: Int, val correction: String, val complete: Boolean)

  private val transcript = VoiceAlarmTranscript()
  @Volatile var text = ""
    private set
  @Volatile var complete = false
    private set

  fun outcome(audioInterrupted: Boolean, voiceEndByte: Int, sentBytes: Int, transportFailure: String?,
              microphoneTimedOut: Boolean = false, quietSpeech: Boolean = false): String = when {
    audioInterrupted -> "microphone_interrupted"
    complete && voiceEndByte > sentBytes -> "unsent_speech_tail"
    transportFailure != null -> transportFailure
    microphoneTimedOut -> "microphone_no_frames"
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
