package com.example.quote_app

/** A system recognizer owns its microphone until a terminal result/error, not onEndOfSpeech. */
class VoiceAlarmNativeTurn {
  var active = false; private set
  var ready = false; private set
  var hasSpeech = false; private set
  var awaitingFinal = false; private set
  private var draft = ""
  val hasDraft: Boolean get() = draft.isNotBlank()
  private val overlappingSources = linkedSetOf<String>()
  val playbackSources: List<String> get() = overlappingSources.toList()

  fun notePlayback(sources: List<String>) {
    if (active && hasSpeech && !awaitingFinal) overlappingSources.addAll(sources.filter { it.isNotBlank() })
  }
  // A new capture must never postpone delivery of the preceding confirmed result.
  fun shouldWaitForFinal(bufferIsFinal: Boolean): Boolean = active && hasSpeech && !bufferIsFinal

  fun timeoutMs(maxUtteranceMs: Long, hasLevelCallbacks: Boolean = true): Long = when {
    awaitingFinal && draft.isNotBlank() -> 2500L
    awaitingFinal || !ready -> 8000L
    hasSpeech -> maxOf(65000L, maxUtteranceMs + 5000L)
    !hasLevelCallbacks -> 10000L
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

/** Recovery decisions are scoped to one alarm. Network loss and an empty recognition are distinct. */
class VoiceAlarmNativeRecovery {
  enum class Failure { NETWORK, NO_MATCH, BUSY, LANGUAGE, PERMISSION, OTHER }
  data class Retry(val delayMs: Long, val replaceEngine: Boolean = false)
  var onDevice = false
    private set
  private var triedOnDevice = false
  private var triedDefaultOffline = false
  var preferOffline = false
    private set
  private var networkFailures = 0
  private var missedSpeech = 0
  private var trialEmptyResults = 0
  private var offlineVerified = false

  fun success() {
    networkFailures = 0
    missedSpeech = 0
    trialEmptyResults = 0
    offlineVerified = onDevice || preferOffline
  }
  fun localUnavailable() { onDevice = false }

  fun failed(kind: Failure, localAvailable: Boolean, expectedSpeech: Boolean = false,
             allowDefaultOffline: Boolean = false): Retry? {
    if (kind == Failure.PERMISSION) return null
    if (kind == Failure.NO_MATCH && expectedSpeech) missedSpeech++ else if (kind != Failure.NETWORK) missedSpeech = 0
    val repeatMiss = missedSpeech >= 2
    if ((onDevice || preferOffline) && !offlineVerified && kind == Failure.NO_MATCH) trialEmptyResults++
    val failedTrial = trialEmptyResults >= 2
    val engineFailed = kind == Failure.LANGUAGE || kind == Failure.OTHER || kind == Failure.NETWORK
    if ((onDevice || preferOffline) && (engineFailed || repeatMiss || failedTrial)) {
      localUnavailable()
      preferOffline = false
      offlineVerified = false
      trialEmptyResults = 0
      missedSpeech = 0
      return Retry(120, replaceEngine = true)
    }
    if (kind == Failure.NETWORK || repeatMiss) {
      if (!triedOnDevice && localAvailable) {
        triedOnDevice = true
        onDevice = true
        missedSpeech = 0
        return Retry(100, replaceEngine = true)
      }
      if (!triedDefaultOffline && allowDefaultOffline && !onDevice) {
        triedDefaultOffline = true
        preferOffline = true
        missedSpeech = 0
        return Retry(100)
      }
      if (repeatMiss) {
        // Rebind once per missed-speech streak, not on every silence timeout.
        if (missedSpeech == 2) return Retry(180, replaceEngine = true)
      }
    }
    return when (kind) {
      Failure.NETWORK -> {
        networkFailures = (networkFailures + 1).coerceAtMost(4)
        Retry(400L shl (networkFailures - 1), replaceEngine = networkFailures == 2)
      }
      Failure.LANGUAGE, Failure.PERMISSION -> null
      Failure.BUSY -> Retry(1000)
      Failure.NO_MATCH -> Retry(100)
      Failure.OTHER -> Retry(350)
    }
  }
}

/** RMS is a capture diagnostic, never evidence of who spoke. Some engines omit it entirely. */
class VoiceAlarmNativeSignal {
  var rmsCallbacks = 0; private set
  var peakDb: Float? = null; private set
  var earlyBegin = false; private set
  var detected = false; private set
  private var consecutive = 0

  fun began(ready: Boolean): Boolean {
    if (!ready) earlyBegin = true
    if (ready) detected = true
    return ready
  }

  fun sample(db: Float, ready: Boolean): Boolean {
    if (!db.isFinite()) return false
    rmsCallbacks++
    peakDb = maxOf(peakDb ?: db, db)
    if (!ready || detected) return false
    consecutive = if (db >= 2f) consecutive + 1 else 0
    if (consecutive < 2) return false
    detected = true
    return true
  }
}

/** A person gets a full response interval once the mic is ready, bounded even if callbacks repeat. */
class VoiceAlarmListenWindow(private val idleMs: Long) {
  private var readyAt: Long? = null
  private var openedAt = 0L
  private var finalGraceUsed = false
  private var recoveryGraceUsed = false
  var expiresAt = 0L; private set
  fun open(now: Long) {
    openedAt = now
    readyAt = null
    expiresAt = now + 12000L
    finalGraceUsed = false
    recoveryGraceUsed = false
  }
  fun ready(now: Long) {
    if (readyAt == null) { readyAt = now; expiresAt = now + idleMs }
  }
  fun activity(now: Long) {
    if (readyAt != null) expiresAt = maxOf(expiresAt, minOf(openedAt + 75000L, now + 8000L))
  }
  fun awaitingFinal(now: Long) {
    if (readyAt == null || finalGraceUsed || expiresAt - now >= 3500L) return
    finalGraceUsed = true
    expiresAt = maxOf(expiresAt, minOf(openedAt + 75000L, now + 3500L))
  }
  fun recovering(now: Long, delayMs: Long) {
    if (readyAt == null || recoveryGraceUsed || expiresAt - now >= delayMs + 6000L) return
    recoveryGraceUsed = true
    expiresAt = maxOf(expiresAt, minOf(openedAt + 75000L, now + delayMs + 6000L))
  }
}
