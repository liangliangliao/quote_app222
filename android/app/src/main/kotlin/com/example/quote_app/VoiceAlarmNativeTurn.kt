package com.example.quote_app

/** A system recognizer owns its microphone until a terminal result/error, not onEndOfSpeech. */
class VoiceAlarmNativeTurn {
  var active = false; private set
  var ready = false; private set
  var hasSpeech = false; private set
  var awaitingFinal = false; private set
  private var draft = ""
  private val overlappingSources = linkedSetOf<String>()
  val playbackSources: List<String> get() = overlappingSources.toList()

  fun notePlayback(sources: List<String>) {
    if (active && hasSpeech && !awaitingFinal) overlappingSources.addAll(sources.filter { it.isNotBlank() })
  }
  // A new capture must never postpone delivery of the preceding confirmed result.
  fun shouldWaitForFinal(bufferIsFinal: Boolean): Boolean = active && hasSpeech && !bufferIsFinal

  fun timeoutMs(maxUtteranceMs: Long): Long = when {
    awaitingFinal && draft.isNotBlank() -> 2500L
    awaitingFinal || !ready -> 8000L
    hasSpeech -> maxOf(65000L, maxUtteranceMs + 5000L)
    else -> 18000L
  }

  companion object {
    fun bestCandidate(candidates: List<String>?): String =
      candidates?.firstOrNull { it.isNotBlank() }?.trim().orEmpty()
  }

  fun begin(): Boolean {
    if (active) return false
    overlappingSources.clear()
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
  fun cancel() { overlappingSources.clear(); active = false; ready = false; hasSpeech = false; awaitingFinal = false; draft = "" }
}
