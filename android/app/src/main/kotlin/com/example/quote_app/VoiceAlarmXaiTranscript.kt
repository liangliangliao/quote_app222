package com.example.quote_app

import org.json.JSONObject

/** Partials describe chunks; only speech_final/done describe complete utterances. */
class VoiceAlarmXaiTranscript {
  private val committed = sortedMapOf<Double, String>()
  private var finalText: String? = null
  @Synchronized fun apply(event: JSONObject): String {
    val text = event.optString("text", "").trim()
    if (event.optString("type") == "transcript.done" || event.optBoolean("speech_final", false)) {
      if (text.isNotEmpty()) finalText = text
      return finalText ?: committed.values.joinToString("")
    }
    finalText?.let { return it }
    val start = event.optDouble("start", 0.0)
    if (event.optBoolean("is_final", false)) {
      committed[start] = text; return committed.values.joinToString("")
    }
    return committed.filterKeys { it < start }.values.joinToString("") + text
  }
}
