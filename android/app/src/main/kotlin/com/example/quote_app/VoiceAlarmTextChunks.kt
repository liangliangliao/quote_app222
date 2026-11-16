package com.example.quote_app

/** Preserve the complete message while respecting the platform TTS input limit. */
object VoiceAlarmTextChunks {
  fun split(text: String, limit: Int): List<String> {
    require(limit >= 2)
    val parts = mutableListOf<String>()
    var start = 0
    while (start < text.length) {
      var end = (start + limit).coerceAtMost(text.length)
      if (end < text.length && text[end - 1].isHighSurrogate() && text[end].isLowSurrogate()) end--
      parts.add(text.substring(start, end))
      start = end
    }
    return parts
  }
}
