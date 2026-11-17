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
      if (end < text.length) {
        val boundary = (end - 1 downTo start + limit / 3).firstOrNull { text[it] in "。！？；.!?;\n" }
        if (boundary != null) end = boundary + 1
      }
      parts.add(text.substring(start, end))
      start = end
    }
    return parts
  }
}
