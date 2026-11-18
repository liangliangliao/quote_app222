package com.example.quote_app

/** A system recognizer owns its microphone until a terminal result/error, not onEndOfSpeech. */
class VoiceAlarmNativeTurn {
  var active = false; private set
  var ready = false; private set
  var hasSpeech = false; private set
  var awaitingFinal = false; private set
  private var draft = ""
  fun begin(): Boolean {
    if (active) return false
    active = true; ready = false; hasSpeech = false; awaitingFinal = false; draft = ""; return true
  }
  fun ready() { if (active) ready = true }
  fun endSpeech() { if (active) awaitingFinal = true }
  fun speechStarted() { if (active) hasSpeech = true }
  fun partial(text: String) { if (active && text.isNotBlank()) { draft = text; hasSpeech = true } }
  fun finish(text: String = ""): String? {
    if (!active) return null
    active = false; ready = false; hasSpeech = false; awaitingFinal = false
    return text.takeIf { it.isNotBlank() } ?: draft
  }
  fun cancel() { active = false; ready = false; hasSpeech = false; awaitingFinal = false; draft = "" }
}
