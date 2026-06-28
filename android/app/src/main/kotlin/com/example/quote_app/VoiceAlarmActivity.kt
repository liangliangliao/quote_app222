package com.example.quote_app

import android.app.Activity
import android.app.AlertDialog
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.content.Intent
import android.content.IntentFilter
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.io.BufferedReader
import java.io.ByteArrayOutputStream
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.TimeZone
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.LinkedBlockingDeque
import java.util.Locale
import java.util.Base64
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString.Companion.toByteString
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.DataOutputStream

class VoiceAlarmActivity : Activity() {
  private val batchChatPipelineVersion = "chat_input_v29_immediate_post_playback_resume_20260628"
  private val batchChatPipelineSummary = "自动待命多轮录音：播报结束保留已打开麦克风并快速恢复，短冷却后立即接收用户开头"

  private fun logVoice(event: String, detail: String = "", data: Map<String, Any?> = emptyMap()) {
    VoiceAlarmDebugLog.write(this, event, detail, data)
  }

  private fun logPreview(value: String, max: Int = 160): String {
    val compact = value.replace("\n", " ").trim()
    return if (compact.length > max) compact.take(max) + "…" else compact
  }

  private var payload = "{}"
  private var recognizer: SpeechRecognizer? = null
  private var tts: TextToSpeech? = null
  @Volatile private var ttsReady = false
  @Volatile private var currentAppTtsStartedByEngine = false
  private var ttsStartWatchdogRunnable: Runnable? = null
  private var pendingSpeakText = ""
  private var pendingSpeakUtteranceId = ""
  private var pendingSpeakRestart = true
  private var pendingSpeakAttempts = 0
  private var transcriptView: TextView? = null
  private var batchStatusView: TextView? = null
  private var batchRetryButton: Button? = null
  @Volatile private var destroyed = false
  @Volatile private var aiAwake = false
  @Volatile private var listening = false
  @Volatile private var speaking = false
  @Volatile private var alarmVoicePlaying = false
  @Volatile private var aiBusy = false
  @Volatile private var aiRequestSeq = 0
  @Volatile private var aiBusyStartedAt = 0L
  private var aiBusyWatchdogRunnable: Runnable? = null
  private var pendingAiWatchdogRunnable: Runnable? = null
  private val conversation = mutableListOf<Pair<String, String>>()
  private var pendingAiUserText = ""
  private var pendingAiUserTextAt = 0L
  private val ttsRestartByUtterance = mutableMapOf<String, Boolean>()
  private val speechHandler = Handler(Looper.getMainLooper())
  private val speechBuffer = StringBuilder()
  private var processSpeechRunnable: Runnable? = null
  private var resumeListeningRunnable: Runnable? = null
  private var alarmPlaybackWatchdogRunnable: Runnable? = null
  private var appTtsWatchdogRunnable: Runnable? = null
  @Volatile private var currentAppTtsUtteranceId = ""
  @Volatile private var appTtsStartedAt = 0L
  @Volatile private var listeningStartedAt = 0L
  @Volatile private var suppressRecognitionUntil = 0L
  @Volatile private var cloudSttActive = false
  @Volatile private var cloudSttSession = 0
  private var cloudSttThread: Thread? = null
  private var cloudSttRecognizeThread: Thread? = null
  private val microsoftPcmQueue = LinkedBlockingDeque<ByteArray>(32)
  private val batchPcmQueue = LinkedBlockingDeque<BatchPcmJob>(32)
  private var iflytekSttClient: OkHttpClient? = null
  private var xaiSttClient: OkHttpClient? = null
  private data class BatchRecordSegment(
    val pcm: ByteArray,
    val originalPcm: ByteArray,
    val startedAt: Long,
    val endedAt: Long,
    val submittedManually: Boolean,
    val speechDetected: Boolean,
    val peak: Int = 0,
    val rms: Int = 0,
  ) {
    val durationMs: Long get() = (endedAt - startedAt).coerceAtLeast(0L)
  }

  private data class BatchPcmJob(
    val pcm: ByteArray,
    val originalPcm: ByteArray,
    val submittedManually: Boolean,
    val startedAt: Long,
    val submittedAt: Long,
    val durationMs: Long,
    val speechDetected: Boolean,
    val peak: Int = 0,
    val rms: Int = 0,
  )

  private var batchSubmitButton: Button? = null
  private var batchLastRetryJob: BatchPcmJob? = null
  @Volatile private var batchAwaitingAiCommit = false
  @Volatile private var batchManualSubmitRequested = false
  @Volatile private var batchHasSpeech = false
  @Volatile private var batchRecognitionInFlight = false
  @Volatile private var batchSubmitInProgress = false
  @Volatile private var batchCurrentBufferedBytes = 0
  @Volatile private var batchCurrentCachedSeconds = 0.0
  @Volatile private var batchCurrentSpeechDetected = false
  @Volatile private var batchCurrentConfirmedSpeech = false
  @Volatile private var batchCurrentStartedAt = 0L
  @Volatile private var batchLastSpeechAt = 0L
  @Volatile private var batchLastKnownStatus = ""
  // Shared/continuous capture device for cloud STT. Previously every single
  // utterance segment created and tore down its own AudioRecord, which leaves
  // a real (device-dependent, often 50-300ms) hardware gap between segments.
  // If the user starts the next sentence right after a short pause, the first
  // word(s) can fall into that gap and never reach the recognizer at all.
  // Keeping one AudioRecord alive across consecutive segments (and only
  // recreating it when the required audio source actually changes, e.g.
  // switching into/out of the alarm/TTS echo-guard window) removes that gap
  // for the common case.
  private var sharedCaptureRecord: AudioRecord? = null
  private var sharedCaptureEffects: VoiceAudioEffects? = null
  private var sharedCaptureIsPlaybackGuard: Boolean = false
  private var sharedCaptureAudioSource: Int = -1
  // Tracks the position in `speechBuffer` where the most recently appended,
  // not-yet-finalized chunk begins. Used by appendSpeechChunk() to make sure
  // similarity-based "revise the draft" merging can only ever touch the tail
  // contributed by the latest in-flight utterance, never text that was
  // already committed by an earlier, separate utterance.
  private var lastAppendedChunkStart: Int = 0
  private var lastReplayPostponeSentAt = 0L
  private var lastReplayPostponeUntil = 0L
  private var lastHandledSpeechNormalized = ""
  private var lastHandledSpeechAt = 0L
  @Volatile private var lastAssistantSpokenText = ""
  @Volatile private var lastAlarmSpokenText = ""
  @Volatile private var appPlaybackStartedAt = 0L
  @Volatile private var strongPlaybackGateUntil = 0L
  @Volatile private var postPlaybackHandoffUntil = 0L
  @Volatile private var batchSpeakerPlaybackBlockUntil = 0L
  @Volatile private var batchPlaybackEchoGuardUntil = 0L
  @Volatile private var batchPlaybackBlockedStatusAt = 0L
  // Monotonic invalidation token for batch capture.  If our own speaker starts or ends while
  // an utterance is being recorded, the recorder must discard the whole buffer instead of
  // uploading a file that may contain alarm/AI playback audio.
  @Volatile private var batchSpeakerPlaybackEpoch = 0L
  private var alarmPlaybackReceiverRegistered = false
  @Volatile private var utteranceSessionStartedAt = 0L
  @Volatile private var lastSpeechChunkAt = 0L
  @Volatile private var semanticHoldExtended = false
  @Volatile private var lastTranscriptRevisionAt = 0L
  @Volatile private var lastDraftTextNormalized = ""
  private val alarmPlaybackReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      when (intent?.action) {
        VoiceAlarmRingingService.ACTION_VOICE_PLAYBACK_START -> handleAlarmVoicePlaybackStart(intent?.getStringExtra("text").orEmpty())
        VoiceAlarmRingingService.ACTION_VOICE_PLAYBACK_END -> {
          val playbackText = intent?.getStringExtra("text").orEmpty()
          if (playbackText.isNotBlank()) lastAlarmSpokenText = playbackText
          logVoice("alarm.playback.end", "alarm voice playback end broadcast received", mapOf("text" to logPreview(playbackText)))
          alarmVoicePlaying = false
          alarmPlaybackWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
          alarmPlaybackWatchdogRunnable = null
          markPostPlaybackHandoff(700L)
          resetBatchCurrentCaptureForSpeakerPlayback("闹钟播报刚结束：非实时录音已保持就绪，短暂冷却后立即接收你接下来的开头。", cooldownMs = 80L, preserveOpenRecorder = true)
          if (speechBuffer.isNotBlank()) {
            scheduleBufferedSpeechProcessing(350L)
          }
          listenAgain(0L)
        }
      }
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    payload = intent?.getStringExtra("payload") ?: "{}"
    logVoice("activity.onCreate", "VoiceAlarmActivity created", mapOf("mode" to selectedSttMode(), "provider" to selectedSttProvider(), "logPath" to VoiceAlarmDebugLog.latestLogPath(this)))
    resetVoiceRuntimeForFreshAlarm("activity_onCreate")
    if (Build.VERSION.SDK_INT >= 27) {
      setShowWhenLocked(true)
      setTurnScreenOn(true)
    } else {
      @Suppress("DEPRECATION")
      window.addFlags(
        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
          WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
          WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
      )
    }
    @Suppress("DEPRECATION")
    window.addFlags(
      WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
    )
    if (Build.VERSION.SDK_INT >= 26) {
      try { (getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).requestDismissKeyguard(this, null) } catch (_: Throwable) {}
    }
    tts = TextToSpeech(this) { status ->
      if (status == TextToSpeech.SUCCESS) {
        val languageResult = try { tts?.setLanguage(Locale.CHINA) ?: TextToSpeech.ERROR } catch (_: Throwable) { TextToSpeech.ERROR }
        ttsReady = languageResult != TextToSpeech.LANG_MISSING_DATA && languageResult != TextToSpeech.LANG_NOT_SUPPORTED && languageResult != TextToSpeech.ERROR
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
          override fun onStart(utteranceId: String?) {
            currentAppTtsStartedByEngine = true
            ttsStartWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
            ttsStartWatchdogRunnable = null
            markAppTtsPlaybackStart()
          }
          override fun onDone(utteranceId: String?) { handleTtsFinished(utteranceId, success = true) }
          @Deprecated("Deprecated in Java")
          override fun onError(utteranceId: String?) { handleTtsFinished(utteranceId, success = false) }
          override fun onError(utteranceId: String?, errorCode: Int) { handleTtsFinished(utteranceId, success = false) }
        })
        flushPendingSpeakIfReady()
      } else {
        ttsReady = false
        transcriptView?.append("\n（系统语音引擎初始化失败，AI文字已显示，可继续语音操作。）")
        listenAgain(120L)
      }
    }
    setContentView(buildContent())
    registerAlarmPlaybackReceiver()
    syncExistingAlarmPlaybackState()
    handleAlarmFireIntent(intent)
    startVoiceAssistant()
  }

  override fun onResume() {
    super.onResume()
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    when {
      cloudSttActive && !isCloudSttHealthy() -> {
        cloudSttActive = false
        startVoiceAssistant()
      }
      recognizer != null -> listenAgain(300)
      recognizer == null && !cloudSttActive -> startVoiceAssistant()
    }
  }

  override fun onStop() {
    super.onStop()
    // Keep the voice assistant alive while the alarm is ringing in the background.
    // The foreground ringing service carries the microphone foreground-service type.
  }

  override fun onNewIntent(intent: Intent?) {
    super.onNewIntent(intent)
    if (intent != null) setIntent(intent)
    val nextPayload = intent?.getStringExtra("payload")
    if (!nextPayload.isNullOrBlank() && nextPayload != payload) {
      resetVoiceRuntimeForFreshAlarm("activity_onNewIntent_payload_changed")
      payload = nextPayload
      setContentView(buildContent())
    }
    handleAlarmFireIntent(intent)
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    if (cloudSttActive && !isCloudSttHealthy()) {
      cloudSttActive = false
      startVoiceAssistant()
    } else if (recognizer != null) {
      listenAgain(200)
    } else if (!cloudSttActive) {
      startVoiceAssistant()
    }
  }

  private fun handleAlarmFireIntent(intent: Intent?) {
    if (intent?.getBooleanExtra("fromAlarmFire", false) != true) return
    val firePayload = intent.getStringExtra("payload") ?: payload
    logVoice("alarm.fireIntent", "received", mapOf("mode" to selectedSttMode(), "provider" to selectedSttProvider()))
    resetVoiceRuntimeForFreshAlarm("alarm_fire_intent")
    registerAlarmPlaybackReceiver()
    if (VoiceAlarmFireGuard.shouldSkip(this, firePayload)) {
      logVoice("alarm.fireIntent.skip", "VoiceAlarmFireGuard skipped duplicate alarm fire")
      return
    }
    primeBatchBlockForInitialAlarmPlayback(firePayload)
    try {
      VoiceAlarmRingingService.start(this, firePayload)
      logVoice("alarm.service.start", "VoiceAlarmRingingService.start invoked")
    } catch (t: Throwable) {
      logVoice("alarm.service.start.error", t.message ?: t.javaClass.simpleName)
    }
    try { VoiceAlarmScheduler.scheduleNextDaily(this, firePayload) } catch (t: Throwable) { logVoice("alarm.scheduleNext.error", t.message ?: t.javaClass.simpleName) }
  }

  private fun resetVoiceRuntimeForFreshAlarm(reason: String) {
    processSpeechRunnable?.let { speechHandler.removeCallbacks(it) }
    resumeListeningRunnable?.let { speechHandler.removeCallbacks(it) }
    alarmPlaybackWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    appTtsWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    ttsStartWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    aiBusyWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    pendingAiWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    processSpeechRunnable = null
    resumeListeningRunnable = null
    alarmPlaybackWatchdogRunnable = null
    appTtsWatchdogRunnable = null
    ttsStartWatchdogRunnable = null
    aiBusyWatchdogRunnable = null
    pendingAiWatchdogRunnable = null
    pendingAiUserText = ""
    pendingAiUserTextAt = 0L
    pendingSpeakText = ""
    pendingSpeakUtteranceId = ""
    aiBusy = false
    batchAwaitingAiCommit = false
    batchRecognitionInFlight = false
    batchSubmitInProgress = false
    batchPcmQueue.clear()
    microsoftPcmQueue.clear()
    speechBuffer.clear()
    speaking = false
    alarmVoicePlaying = false
    currentAppTtsUtteranceId = ""
    currentAppTtsStartedByEngine = false
    appTtsStartedAt = 0L
    appPlaybackStartedAt = 0L
    strongPlaybackGateUntil = 0L
    suppressRecognitionUntil = 0L
    postPlaybackHandoffUntil = 0L
    batchSpeakerPlaybackBlockUntil = 0L
    batchPlaybackEchoGuardUntil = 0L
    batchSpeakerPlaybackEpoch += 1L
    batchManualSubmitRequested = false
    batchHasSpeech = false
    batchCurrentBufferedBytes = 0
    batchCurrentCachedSeconds = 0.0
    batchCurrentSpeechDetected = false
    batchCurrentConfirmedSpeech = false
    batchCurrentStartedAt = 0L
    batchLastSpeechAt = 0L
    batchLastKnownStatus = ""
    lastDraftTextNormalized = ""
    lastAlarmSpokenText = ""
    lastAssistantSpokenText = ""
    lastHandledSpeechNormalized = ""
    lastHandledSpeechAt = 0L
    semanticHoldExtended = false
    lastTranscriptRevisionAt = 0L
    try { tts?.stop() } catch (_: Throwable) {}
    stopNativeRecognizer()
    releaseContinuousAudioRecord()
    logVoice("voiceSession.reset", "reset runtime voice state for fresh alarm UI", mapOf("reason" to reason, "pipeline" to batchChatPipelineVersion))
  }

  private fun buildContent(): View {
    val data = try { JSONObject(payload) } catch (_: Throwable) { JSONObject() }
    val root = FrameLayout(this)
    val backgroundPath = data.optString("backgroundPath", "")
    if (backgroundPath.isNotBlank() && File(backgroundPath).isFile) {
      val image = ImageView(this).apply {
        scaleType = ImageView.ScaleType.CENTER_CROP
        setImageDrawable(BitmapDrawable(resources, backgroundPath))
      }
      root.addView(image, FrameLayout.LayoutParams(-1, -1))
      root.addView(View(this).apply { setBackgroundColor(0x88000000.toInt()) }, FrameLayout.LayoutParams(-1, -1))
    } else {
      val morning = data.optString("mode", "morning") == "morning"
      root.background = GradientDrawable(
        GradientDrawable.Orientation.TL_BR,
        if (morning)
          intArrayOf(0xFFF59E0B.toInt(), 0xFFFB7185.toInt(), 0xFF7C3AED.toInt())
        else
          intArrayOf(0xFF0F172A.toInt(), 0xFF312E81.toInt(), 0xFF1D4ED8.toInt()),
      )
    }
    val panel = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      gravity = Gravity.CENTER
      setPadding(56, 80, 56, 64)
    }
    panel.addView(TextView(this).apply {
      text = "语音闹钟"
      textSize = 34f
      setTextColor(Color.WHITE)
      gravity = Gravity.CENTER
    })
    panel.addView(TextView(this).apply {
      text = data.optString("text", "闹钟时间到了")
      textSize = 24f
      setTextColor(Color.WHITE)
      gravity = Gravity.CENTER
      setPadding(0, 48, 0, 64)
    }, LinearLayout.LayoutParams(-1, 0, 1f))
    transcriptView = TextView(this).apply {
      text = "可直接说“小名小名/你好AI/闹钟助手”唤醒 AI；说“关闭闹钟”停止；说“延迟五分钟”稍后提醒。"
      textSize = 16f
      setTextColor(Color.WHITE)
      gravity = Gravity.CENTER
      setPadding(0, 0, 0, 32)
    }
    panel.addView(transcriptView, LinearLayout.LayoutParams(-1, -2))
    batchSubmitButton = null
    batchRetryButton = null
    batchStatusView = null
    if (selectedSttMode() == "batch") {
      batchStatusView = TextView(this).apply {
        text = "非实时录音准备中…"
        textSize = 14f
        setTextColor(0xFFE5E7EB.toInt())
        gravity = Gravity.CENTER
        setPadding(0, 0, 0, 20)
      }
      panel.addView(batchStatusView, LinearLayout.LayoutParams(-1, -2))
      val submitButton = Button(this).apply {
        text = "发送当前录音转文字"
        textSize = 18f
        setOnClickListener { requestBatchManualSubmit() }
      }
      batchSubmitButton = submitButton
      panel.addView(submitButton, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = 12 })
      val retryButton = Button(this).apply {
        text = "重试上一次录音"
        textSize = 16f
        isEnabled = false
        setOnClickListener { retryLastBatchAudio() }
      }
      batchRetryButton = retryButton
      panel.addView(retryButton, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = 24 })
    }
    panel.addView(Button(this).apply {
      text = "查看语音调试日志"
      textSize = 16f
      setOnClickListener { showVoiceDebugLogDialog() }
    }, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = 12 })
    panel.addView(Button(this).apply {
      text = "5 分钟后再次提醒"
      textSize = 18f
      setOnClickListener {
        VoiceAlarmScheduler.snooze(this@VoiceAlarmActivity, payload, 5)
        VoiceAlarmRingingService.stop(this@VoiceAlarmActivity)
        finishAndRemoveTask()
      }
    }, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = 24 })
    panel.addView(Button(this).apply {
      text = "停止闹钟"
      textSize = 18f
      setOnClickListener {
        VoiceAlarmRingingService.stop(this@VoiceAlarmActivity)
        finishAndRemoveTask()
      }
    }, LinearLayout.LayoutParams(-1, -2))
    root.addView(panel, FrameLayout.LayoutParams(-1, -1))
    return root
  }

  private fun createSpeechRecognizerCompat(): SpeechRecognizer {
    if (Build.VERSION.SDK_INT >= 31) {
      try { return SpeechRecognizer.createOnDeviceSpeechRecognizer(this) } catch (_: Throwable) {}
    }
    return SpeechRecognizer.createSpeechRecognizer(this)
  }

  private fun isCloudSttHealthy(): Boolean {
    val recorderAlive = cloudSttThread?.isAlive == true
    val recognizeThread = cloudSttRecognizeThread
    val recognizerAlive = recognizeThread == null || recognizeThread.isAlive
    return recorderAlive && recognizerAlive
  }

  private fun selectedSttProvider(): String = try { JSONObject(payload).optString("sttProvider", "native") } catch (_: Throwable) { "native" }

  private fun selectedSttMode(): String = try {
    val raw = JSONObject(payload).optString("sttMode", "realtime")
    if (raw == "batch") "batch" else "realtime"
  } catch (_: Throwable) { "realtime" }

  private fun cloudSttConfigForProvider(provider: String): JSONObject? {
    val sttConfig = try { JSONObject(payload).optJSONObject("sttConfig") } catch (_: Throwable) { null }
    return when (provider) {
      "microsoft" -> sttConfig?.optJSONObject("microsoft")?.takeIf { it.optString("apiKey", "").isNotBlank() }
      "iflytek" -> sttConfig?.optJSONObject("iflytek")?.takeIf {
        it.optString("appId", "").isNotBlank() &&
          it.optString("apiKey", "").isNotBlank() &&
          it.optString("apiSecret", "").isNotBlank()
      }
      "xai" -> sttConfig?.optJSONObject("xai")?.takeIf { it.optString("apiKey", "").isNotBlank() }
      else -> null
    }
  }

  private fun cloudSttConfigForSelected(): JSONObject? = cloudSttConfigForProvider(selectedSttProvider())

  private fun stopCloudStt(clearQueue: Boolean = true) {
    cloudSttActive = false
    cloudSttSession++
    try { cloudSttThread?.interrupt() } catch (_: Throwable) {}
    try { cloudSttRecognizeThread?.interrupt() } catch (_: Throwable) {}
    cloudSttThread = null
    cloudSttRecognizeThread = null
    if (clearQueue) {
      microsoftPcmQueue.clear()
      batchPcmQueue.clear()
    }
    batchManualSubmitRequested = false
    batchHasSpeech = false
    batchRecognitionInFlight = false
    batchSubmitInProgress = false
    batchCurrentBufferedBytes = 0
    batchCurrentCachedSeconds = 0.0
    batchCurrentSpeechDetected = false
    batchCurrentConfirmedSpeech = false
    batchCurrentStartedAt = 0L
    batchLastSpeechAt = 0L
    batchLastKnownStatus = ""
    batchLastRetryJob = null
    batchAwaitingAiCommit = false
    runOnUiThread {
      updateBatchSubmitButton(false)
      updateBatchRetryButton(false)
    }
    releaseContinuousAudioRecord()
  }

  // Lazily creates (or reuses) a single AudioRecord that stays alive across
  // consecutive utterance segments.  Non-real-time dictation must be robust on
  // different Android devices, so we do not assume VOICE_RECOGNITION always
  // works.  Some phones suppress or fail that source while an alarm / TTS /
  // audio focus session is active.  We therefore fall back to MIC and only
  // enable platform AEC/NS/AGC when we are explicitly in playback echo-guard
  // mode; otherwise those effects can over-suppress quiet user speech and make
  // batch STT look completely broken.
  private fun obtainContinuousAudioRecord(playbackGuard: Boolean): AudioRecord? {
    val existing = sharedCaptureRecord
    if (existing != null && existing.state == AudioRecord.STATE_INITIALIZED && sharedCaptureIsPlaybackGuard == playbackGuard) {
      return existing
    }
    releaseContinuousAudioRecord()
    val sampleRate = 16000
    val minBuffer = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
    if (minBuffer <= 0) {
      logVoice("audioRecord.minBuffer.error", "AudioRecord.getMinBufferSize returned invalid buffer", mapOf("minBuffer" to minBuffer))
      return null
    }
    val candidates = if (playbackGuard) {
      listOf(MediaRecorder.AudioSource.VOICE_COMMUNICATION, MediaRecorder.AudioSource.VOICE_RECOGNITION, MediaRecorder.AudioSource.MIC)
    } else {
      listOf(MediaRecorder.AudioSource.VOICE_RECOGNITION, MediaRecorder.AudioSource.MIC)
    }
    for (source in candidates) {
      val record = try {
        AudioRecord(source, sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, (minBuffer * 6).coerceAtLeast(sampleRate * 2))
      } catch (_: Throwable) { null } ?: continue
      if (record.state != AudioRecord.STATE_INITIALIZED) {
        try { record.release() } catch (_: Throwable) {}
        continue
      }
      val effects = if (playbackGuard) enableVoiceSeparationEffects(record.audioSessionId) else VoiceAudioEffects(null, null, null)
      try {
        record.startRecording()
      } catch (t: Throwable) {
        logVoice("audioRecord.start.error", t.message ?: t.javaClass.simpleName, mapOf("source" to source, "playbackGuard" to playbackGuard))
        effects.release()
        try { record.release() } catch (_: Throwable) {}
        continue
      }
      logVoice("audioRecord.start", "AudioRecord started", mapOf("source" to source, "playbackGuard" to playbackGuard, "minBuffer" to minBuffer))
      sharedCaptureRecord = record
      sharedCaptureEffects = effects
      sharedCaptureIsPlaybackGuard = playbackGuard
      sharedCaptureAudioSource = source
      return record
    }
    return null
  }

  private fun releaseContinuousAudioRecord() {
    val hadRecord = sharedCaptureRecord != null
    val oldSource = sharedCaptureAudioSource
    try { sharedCaptureRecord?.stop() } catch (_: Throwable) {}
    try { sharedCaptureRecord?.release() } catch (_: Throwable) {}
    sharedCaptureEffects?.release()
    if (hadRecord) logVoice("audioRecord.release", "AudioRecord released", mapOf("source" to oldSource))
    sharedCaptureRecord = null
    sharedCaptureEffects = null
    sharedCaptureAudioSource = -1
  }

  private fun stopNativeRecognizer() {
    listening = false
    listeningStartedAt = 0L
    try { recognizer?.cancel() } catch (_: Throwable) {}
    try { recognizer?.destroy() } catch (_: Throwable) {}
    recognizer = null
  }

  private fun startVoiceAssistant() {
    val selectedSttProvider = selectedSttProvider()
    val cloudCfg = cloudSttConfigForSelected()
    logVoice("voiceAssistant.start", "starting voice assistant", mapOf("mode" to selectedSttMode(), "provider" to selectedSttProvider, "hasCloudConfig" to (cloudCfg != null)))
    if (selectedSttMode() == "batch" && selectedSttProvider in setOf("microsoft", "iflytek", "xai")) {
      stopNativeRecognizer()
      if (cloudCfg == null) {
        stopCloudStt()
        setBatchStatus("非实时语音识别未启动：${sttProviderLabel(selectedSttProvider)}配置不完整，请检查 API Key / AppId / Secret 后重新保存。")
        logVoice("batch.config.missing", "Non-realtime STT config incomplete", mapOf("provider" to selectedSttProvider))
        return
      }
      if (cloudSttActive && isCloudSttHealthy()) return
      stopCloudStt()
      startBatchCloudStt(selectedSttProvider, cloudCfg)
      return
    }
    if (selectedSttProvider == "microsoft" && cloudCfg != null) {
      stopNativeRecognizer()
      if (cloudSttActive && isCloudSttHealthy()) return
      stopCloudStt()
      startMicrosoftCloudStt(cloudCfg)
      return
    } else if (selectedSttProvider == "iflytek" && cloudCfg != null) {
      stopNativeRecognizer()
      if (cloudSttActive && isCloudSttHealthy()) return
      stopCloudStt()
      startIflytekCloudStt(cloudCfg)
      return
    } else if (selectedSttProvider == "xai" && cloudCfg != null) {
      stopNativeRecognizer()
      if (cloudSttActive && isCloudSttHealthy()) return
      stopCloudStt()
      startXaiCloudStt(cloudCfg)
      return
    } else if (selectedSttProvider == "microsoft") {
      transcriptView?.text = "已选择微软语音识别，但缺少 Microsoft Speech API Key；暂时回退到系统识别。"
    } else if (selectedSttProvider == "iflytek") {
      transcriptView?.text = "已选择讯飞识别，但缺少 AppID/APIKey/APISecret；暂时回退到系统识别。"
    } else if (selectedSttProvider == "xai") {
      transcriptView?.text = "已选择 xAI 语音识别，但缺少 xAI API Key；暂时回退到系统识别。"
    }

    stopCloudStt()
    stopNativeRecognizer()
    if (!SpeechRecognizer.isRecognitionAvailable(this)) {
      transcriptView?.text = "当前设备没有可用语音识别服务，可使用屏幕按钮。"
      return
    }
    recognizer = createSpeechRecognizerCompat().apply {
      setRecognitionListener(object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) { listening = true; listeningStartedAt = System.currentTimeMillis(); updateListeningStatus() }
        override fun onResults(results: Bundle?) {
          listening = false
          listeningStartedAt = 0L
          onSpeechChunk(
            results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty(),
            finalChunk = true,
          )
          // Android SpeechRecognizer is utterance-based rather than a true
          // continuous stream. Restart immediately after each final segment
          // while the debounce timer keeps collecting subsequent segments.
          if (!speaking) listenAgain(80)
        }
        override fun onPartialResults(partialResults: Bundle?) {
          onSpeechChunk(
            partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty(),
            finalChunk = false,
          )
        }
        override fun onError(error: Int) {
          listening = false
          listeningStartedAt = 0L
          if (speechBuffer.isNotBlank()) {
            scheduleBufferedSpeechProcessing(endpointingConfig().partialFallbackDelayMs)
            if (!speaking) listenAgain(180)
          }
          else if (!speaking) listenAgain(350)
        }
        override fun onBeginningOfSpeech() {
          // Beginning-of-speech can be triggered by the alarm voice leaking into
          // the microphone.  Do not stop the current alarm prompt until we have
          // actual recognized text and can filter likely echo.
          if (!alarmVoicePlaying && !isAlarmPlaybackSuppressed()) postponeAlarmVoiceReplay(30_000L)
        }
        override fun onEndOfSpeech() { listening = false; listeningStartedAt = 0L }
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
      })
    }
    listenAgain(300)
  }
  private fun startMicrosoftCloudStt(cfg: JSONObject) {
    if (cloudSttActive && isCloudSttHealthy()) return
    if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      transcriptView?.text = "微软云识别需要麦克风权限；请返回闹钟设置页授权后重新保存。"
      return
    }
    cloudSttActive = true
    val session = ++cloudSttSession
    microsoftPcmQueue.clear()
    transcriptView?.text = "微软云识别已启用，正在持续聆听…\n系统会持续收音，按“静音稳定 + 文本稳定”自动提交给 AI。"

    // 录音线程只负责连续采集。之前“录一段 -> 等网络识别 -> 再录下一段”的串行方式，
    // 会在 HTTP 请求期间完全停止麦克风，用户连着说一大段时很容易漏掉中间内容。
    cloudSttThread = Thread {
      while (!destroyed && cloudSttActive && cloudSttSession == session) {
        val endpoint = endpointingConfig()
        val duration = if (isStrictPlaybackActiveForCapture()) 3200 else endpoint.maxUtteranceMs.toInt()
        val pcm = try { recordPcmChunk(duration) } catch (t: Throwable) {
          runOnUiThread { transcriptView?.text = "微软录音启动失败：${t.message ?: t.javaClass.simpleName}；稍后重试…" }
          Thread.sleep(600)
          ByteArray(0)
        }
        if (pcm.isEmpty() || destroyed || !cloudSttActive || cloudSttSession != session) continue
        // 队列容量足够覆盖短时间网络抖动。极端情况下宁可合并到队尾，也不要静默丢弃最新语音。
        if (!microsoftPcmQueue.offer(pcm)) {
          val tail = microsoftPcmQueue.pollLast()
          if (tail != null) {
            val merged = ByteArrayOutputStream()
            merged.write(tail)
            merged.write(pcm)
            microsoftPcmQueue.offer(merged.toByteArray())
          } else {
            microsoftPcmQueue.offer(pcm)
          }
        }
        runOnUiThread {
          val base = speechBuffer.toString().trim()
          transcriptView?.text = if (base.isBlank()) {
            "正在收音并等待微软云端返回最终文字…"
          } else {
            "你：$base\n正在等待微软云端返回最终文字…"
          }
        }
      }
    }.apply {
      name = "voice-alarm-microsoft-recorder"
      isDaemon = true
      start()
    }

    // 识别线程只负责按顺序消费录音队列。这样网络慢也不会让麦克风停下来。
    cloudSttRecognizeThread = Thread {
      while (!destroyed && cloudSttActive && cloudSttSession == session) {
        val pcm = try { microsoftPcmQueue.poll(500, TimeUnit.MILLISECONDS) } catch (_: InterruptedException) { null } ?: continue
        val text = try { recognizeWithMicrosoft(cfg, pcm) } catch (t: Throwable) {
          runOnUiThread { transcriptView?.text = "微软识别失败：${t.message ?: t.javaClass.simpleName}；后续语音仍可继续转写…" }
          ""
        }
        if (text.isNotBlank() && !destroyed && cloudSttActive && cloudSttSession == session) runOnUiThread { onSpeechChunk(text, finalChunk = true) }
      }
    }.apply {
      name = "voice-alarm-microsoft-recognizer"
      isDaemon = true
      start()
    }
  }

  private fun startIflytekCloudStt(cfg: JSONObject) {
    if (cloudSttActive && isCloudSttHealthy()) return
    if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      transcriptView?.text = "讯飞云识别需要麦克风权限；请返回闹钟设置页授权后重新保存。"
      return
    }
    cloudSttActive = true
    val session = ++cloudSttSession
    cloudSttRecognizeThread = null
    microsoftPcmQueue.clear()
    transcriptView?.text = "讯飞流式识别已启用，正在持续聆听…"
    cloudSttThread = Thread {
      while (!destroyed && cloudSttActive && cloudSttSession == session) {
        // 允许在闹钟/AI 播报期间继续短窗口收音，再通过回声过滤判断是否是真人插话。
        // 这样用户连续说话或打断 AI 时，不会因为 speaking=true 直接丢掉整段内容。
        val endpoint = endpointingConfig()
        val text = try { recognizeWithIflytekStreaming(cfg, if (isStrictPlaybackActiveForCapture()) 3600 else endpoint.maxUtteranceMs.toInt()) } catch (t: Throwable) {
          runOnUiThread { transcriptView?.text = "讯飞识别失败：${t.message ?: t.javaClass.simpleName}；正在重试…" }
          ""
        }
        if (text.isNotBlank() && !destroyed && cloudSttActive && cloudSttSession == session) {
          // If alarm playback interrupted the stream, still pass the recognized
          // user text through the central buffering/filtering path instead of
          // dropping it.  That path suppresses alarm echo and waits for playback
          // completion before sending real user speech to AI.
          runOnUiThread { onSpeechChunk(text, finalChunk = true) }
        }
      }
    }.apply {
      name = "voice-alarm-iflytek-stt"
      isDaemon = true
      start()
    }
  }


  private fun startXaiCloudStt(cfg: JSONObject) {
    if (cloudSttActive && isCloudSttHealthy()) return
    if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      transcriptView?.text = "xAI 云识别需要麦克风权限；请返回闹钟设置页授权后重新保存。"
      return
    }
    cloudSttActive = true
    val session = ++cloudSttSession
    cloudSttRecognizeThread = null
    microsoftPcmQueue.clear()
    transcriptView?.text = "xAI 实时语音识别已启用，正在持续聆听…"
    cloudSttThread = Thread {
      while (!destroyed && cloudSttActive && cloudSttSession == session) {
        val endpoint = endpointingConfig()
        val text = try { recognizeWithXaiStreaming(cfg, if (isStrictPlaybackActiveForCapture()) 3600 else endpoint.maxUtteranceMs.toInt()) } catch (t: Throwable) {
          runOnUiThread { transcriptView?.text = "xAI 实时识别失败：${t.message ?: t.javaClass.simpleName}；正在重试…" }
          ""
        }
        if (text.isNotBlank() && !destroyed && cloudSttActive && cloudSttSession == session) {
          runOnUiThread { onSpeechChunk(text, finalChunk = true) }
        }
      }
    }.apply {
      name = "voice-alarm-xai-stt"
      isDaemon = true
      start()
    }
  }

  private fun startBatchCloudStt(provider: String, cfg: JSONObject) {
    if (cloudSttActive && isCloudSttHealthy()) return
    if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      setBatchStatus("非实时语音识别需要麦克风权限；请返回闹钟设置页授权后重新保存。")
      return
    }
    cloudSttActive = true
    val session = ++cloudSttSession
    batchPcmQueue.clear()
    batchManualSubmitRequested = false
    batchHasSpeech = false
    batchRecognitionInFlight = false
    batchSubmitInProgress = false
    batchCurrentBufferedBytes = 0
    batchCurrentCachedSeconds = 0.0
    batchCurrentSpeechDetected = false
    batchCurrentConfirmedSpeech = false
    batchCurrentStartedAt = 0L
    batchLastSpeechAt = 0L
    batchLastKnownStatus = ""
    batchLastRetryJob = null
    batchAwaitingAiCommit = false
    logVoice("batch.start", "Non-realtime STT started", mapOf("provider" to provider, "pipeline" to batchChatPipelineVersion, "summary" to batchChatPipelineSummary, "logPath" to VoiceAlarmDebugLog.latestLogPath(this)))
    runOnUiThread {
      updateBatchSubmitButton(false)
      updateBatchRetryButton(false)
      setBatchStatus("非实时录音识别已启用：自动待命的聊天输入框式流程。无需手动开启录音；空闲时自动监听，确认你开始说话后才建立本轮录音，说完静音自动提交；播报期间不录入 STT，也不后台排队。\n调试日志：${VoiceAlarmDebugLog.latestLogPath(this)}")
    }

    // v6 改成真正的聊天 App 单轮流程：录音 -> 上传 STT -> 得到最终文字 -> 发 AI -> 播报结束，
    // 这一轮未完成前不再后台继续收音，也不创建第二段队列。这样可以避免后半句被分到
    // 另一条 STT 请求里、也避免闹钟/AI 播报声混进下一段音频。
    cloudSttThread = Thread {
      var lastBusyLogAt = 0L
      while (!destroyed && cloudSttActive && cloudSttSession == session) {
        if (isBatchStrictSingleTurnBusy()) {
          releaseContinuousAudioRecord()
          batchManualSubmitRequested = false
          batchCurrentBufferedBytes = 0
          batchCurrentCachedSeconds = 0.0
          batchCurrentSpeechDetected = false
          batchCurrentConfirmedSpeech = false
          val now = System.currentTimeMillis()
          if (now - lastBusyLogAt >= 1500L) {
            lastBusyLogAt = now
            val reason = batchStrictSingleTurnBusyReason()
            logVoice("batch.singleTurn.wait", "strict single-turn pipeline is busy; recorder paused", mapOf("reason" to reason, "inFlight" to batchRecognitionInFlight, "submit" to batchSubmitInProgress, "queue" to batchPcmQueue.size, "aiBusy" to aiBusy, "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "awaitingAi" to batchAwaitingAiCommit, "pipeline" to batchChatPipelineVersion))
            runOnUiThread {
              updateBatchSubmitButton(true)
              setBatchStatus("严格单轮处理中：$reason。录音已暂停，避免漏句、排队或把播报声写入转文字。")
            }
          }
          try { Thread.sleep(250L) } catch (_: Throwable) {}
          continue
        }
        val segment = try { recordBatchPcmUntilSubmit() } catch (t: Throwable) {
          logVoice("batch.record.error", t.message ?: t.javaClass.simpleName)
          setBatchStatus("非实时录音失败：${t.message ?: t.javaClass.simpleName}；稍后重试…")
          Thread.sleep(600)
          null
        }
        if (segment == null || segment.pcm.isEmpty() || destroyed || !cloudSttActive || cloudSttSession != session) {
          if (!destroyed && cloudSttActive && cloudSttSession == session && batchSubmitInProgress && batchPcmQueue.isEmpty() && !batchRecognitionInFlight) {
            batchSubmitInProgress = false
            runOnUiThread {
              updateBatchSubmitButton(false)
              setBatchStatus("本次没有足够可提交的录音，已恢复收音；请靠近麦克风再说一次。")
            }
          }
          continue
        }
        val submittedAudioDurationMs = ((segment.pcm.size.toLong() * 1000L) / (16000L * 2L)).coerceAtLeast(0L)
        val job = BatchPcmJob(
          pcm = segment.pcm,
          originalPcm = segment.originalPcm,
          submittedManually = segment.submittedManually,
          startedAt = segment.startedAt,
          submittedAt = segment.endedAt,
          durationMs = submittedAudioDurationMs,
          speechDetected = segment.speechDetected,
          peak = segment.peak,
          rms = segment.rms,
        )
        // v6 单轮：这里不再合并、不再排队多条语音。正常情况下进入这里时队列必为空。
        // 如果因为线程竞态残留了旧 job，直接清掉旧队列，保证只处理当前这一条完整录音。
        if (batchPcmQueue.isNotEmpty()) {
          logVoice("batch.queue.cleared", "cleared stale queued utterances in strict single-turn mode", mapOf("oldQueue" to batchPcmQueue.size, "pipeline" to batchChatPipelineVersion))
          batchPcmQueue.clear()
        }
        batchPcmQueue.offer(job)
        batchSubmitInProgress = true
        runOnUiThread {
          updateBatchSubmitButton(true)
          val submitKind = if (job.submittedManually) "手动提交" else "自动静音提交"
          val seconds = String.format(Locale.CHINA, "%.1f", job.durationMs / 1000.0)
          setBatchStatus("${submitKind}：已提交这一条完整录音给${sttProviderLabel(provider)}转文字，音频 ${seconds} 秒；录音暂停，等待最终文字和 AI 回复。")
        }
      }
    }.apply {
      name = "voice-alarm-batch-recorder"
      isDaemon = true
      start()
    }

    cloudSttRecognizeThread = Thread {
      while (!destroyed && cloudSttActive && cloudSttSession == session) {
        val job = try { batchPcmQueue.poll(500, TimeUnit.MILLISECONDS) } catch (_: InterruptedException) { null } ?: continue
        batchRecognitionInFlight = true
        batchSubmitInProgress = true
        runOnUiThread {
          updateBatchSubmitButton(true)
          val seconds = String.format(Locale.CHINA, "%.1f", job.durationMs / 1000.0)
          setBatchStatus("识别中：正在请求${sttProviderLabel(provider)}返回当前完整录音的最终文字…（音频 ${seconds} 秒）")
        }
        val debugAudioPath = saveBatchDebugWav("last_batch_stt.wav", job.pcm)
        val debugOriginalPath = if (job.originalPcm.isNotEmpty() && job.originalPcm.size != job.pcm.size) {
          saveBatchDebugWav("last_batch_stt_original.wav", job.originalPcm)
        } else ""
        logVoice(
          "batch.audio.saved",
          "saved last submitted batch audio for playback/debug",
          mapOf("path" to debugAudioPath, "originalPath" to debugOriginalPath, "pcmBytes" to job.pcm.size, "originalBytes" to job.originalPcm.size, "peak" to job.peak, "rms" to job.rms),
        )
        var lastError = ""
        logVoice(
          "batch.singleUpload.start",
          "upload one complete utterance audio to STT; no rolling chunks or local split retries",
          mapOf("provider" to provider, "pcmBytes" to job.pcm.size, "audioSeconds" to String.format(Locale.US, "%.2f", job.pcm.size / (16000.0 * 2.0))),
        )
        var raw = try { recognizeBatchWithProvider(provider, cfg, job.pcm) } catch (t: Throwable) {
          lastError = t.message ?: t.javaClass.simpleName
          setBatchStatus("${sttProviderLabel(provider)}非实时识别失败：$lastError；本次按完整录音提交，没有再做本地拆分重试。")
          ""
        }
        var echoDiscarded = false
        if (raw.isNotBlank()) {
          val sanitized = sanitizeBatchTranscriptEcho(raw)
          echoDiscarded = sanitized.isBlank()
          raw = sanitized
        }
        if (raw.isNotBlank() && isLowQualityBatchTranscript(raw, job.pcm.size)) {
          logVoice("batch.result.lowQuality", "batch STT returned filler-only text; treat as no valid transcript", mapOf("raw" to logPreview(raw), "pcmBytes" to job.pcm.size, "audioSeconds" to String.format(Locale.US, "%.2f", job.pcm.size / (16000.0 * 2.0))))
          raw = ""
        }
        val text = if (raw.isBlank()) "" else try { maybeAutoCorrectBatchTranscript(raw) } catch (_: Throwable) { raw }
        batchRecognitionInFlight = false
        val stillSubmitting = batchPcmQueue.isNotEmpty()
        batchSubmitInProgress = stillSubmitting
        runOnUiThread { updateBatchSubmitButton(stillSubmitting) }
        if (text.isNotBlank() && !destroyed && cloudSttActive && cloudSttSession == session) {
          batchLastRetryJob = null
          batchAwaitingAiCommit = true
          runOnUiThread {
            updateBatchRetryButton(false)
            onBatchTranscriptionResult(text)
          }
        } else if (!destroyed && cloudSttActive && cloudSttSession == session) {
          batchAwaitingAiCommit = false
          if (echoDiscarded) {
            batchLastRetryJob = null
            runOnUiThread { updateBatchRetryButton(false) }
            runOnUiThread {
              setBatchStatus("刚才识别到的是闹钟/AI 播报内容，已丢弃且不会发送给 AI。请在播报结束后重新说；这一版会从源头失效跨播报窗口的录音缓存。")
            }
          } else {
            batchLastRetryJob = job
            runOnUiThread { updateBatchRetryButton(true) }
            runOnUiThread {
              val seconds = String.format(Locale.CHINA, "%.1f", job.durationMs / 1000.0)
              val audioSeconds = String.format(Locale.CHINA, "%.1f", (if (job.originalPcm.isNotEmpty()) job.originalPcm.size else job.pcm.size) / (16000.0 * 2.0))
              val audioInfo = "音频 ${audioSeconds} 秒，peak=${job.peak}，rms=${job.rms}"
              val errorInfo = if (lastError.isNotBlank()) "；服务商错误：${lastError.take(140)}" else ""
              val debugInfo = if (debugAudioPath.isNotBlank()) "；已保存最近提交音频，可在日志里查看 last_batch_stt.wav 路径" else ""
              val hint = if (job.speechDetected || job.submittedManually) "已提交 ${seconds} 秒录音（$audioInfo），但没有拿到文字$errorInfo$debugInfo；可点“重试上一次录音”，或临时切换到 xAI/微软验证。" else "当前段可能音量过低（$audioInfo）$errorInfo$debugInfo；请靠近麦克风再说一次。"
              setBatchStatus("${sttProviderLabel(provider)}未返回有效文字。$hint")
            }
          }
        }
      }
    }.apply {
      name = "voice-alarm-batch-recognizer"
      isDaemon = true
      start()
    }
  }


  private fun isBatchStrictSingleTurnBusy(): Boolean {
    if (selectedSttMode() != "batch") return false
    val now = System.currentTimeMillis()
    val allowPlaybackBargeIn = batchPlaybackBargeInEnabled()
    return batchRecognitionInFlight ||
      batchSubmitInProgress ||
      batchPcmQueue.isNotEmpty() ||
      batchAwaitingAiCommit ||
      (!allowPlaybackBargeIn && speaking) ||
      (!allowPlaybackBargeIn && alarmVoicePlaying) ||
      pendingAiUserText.isNotBlank() ||
      speechBuffer.toString().trim().isNotBlank() ||
      (!allowPlaybackBargeIn && now < batchSpeakerPlaybackBlockUntil) ||
      (!allowPlaybackBargeIn && now < batchPlaybackEchoGuardUntil) ||
      (!allowPlaybackBargeIn && now < suppressRecognitionUntil) ||
      (!allowPlaybackBargeIn && now < strongPlaybackGateUntil)
  }

  private fun batchStrictSingleTurnBusyReason(): String {
    val now = System.currentTimeMillis()
    return when {
      batchRecognitionInFlight -> "正在把上一条完整录音转成文字"
      batchSubmitInProgress || batchPcmQueue.isNotEmpty() -> "上一条完整录音等待转文字"
      batchAwaitingAiCommit || speechBuffer.toString().trim().isNotBlank() -> "已拿到转文字结果，正在准备发送给 AI"
      aiBusy -> "AI 正在生成回复"
      speaking || alarmVoicePlaying -> "闹钟/AI 正在播报"
      pendingAiUserText.isNotBlank() -> "已有一条待处理语音文本"
      now < batchSpeakerPlaybackBlockUntil || now < batchPlaybackEchoGuardUntil || now < suppressRecognitionUntil || now < strongPlaybackGateUntil -> "播报刚结束，正在短暂回声冷却"
      else -> "上一轮尚未结束"
    }
  }

  private fun showVoiceDebugLogDialog() {
    val path = VoiceAlarmDebugLog.latestLogPath(this)
    val dir = VoiceAlarmDebugLog.logDirectoryPath(this)
    val body = VoiceAlarmDebugLog.latestLogText(this, maxBytes = 96 * 1024).ifBlank {
      "当前还没有写入日志。请先触发一次闹钟语音/语音识别流程后再查看。"
    }
    val text = buildString {
      append("日志目录：").append(dir.ifBlank { "未知" }).append("\n")
      append("当前日志：").append(path.ifBlank { "未知" }).append("\n")
      append("也可用：adb logcat -s VoiceAlarmDebug 查看实时日志。\n")
      append("\n—— 最近日志内容 ——\n")
      append(body)
    }
    val contentView = ScrollView(this).apply {
      addView(TextView(this@VoiceAlarmActivity).apply {
        this.text = text
        textSize = 12f
        setTextColor(Color.BLACK)
        setPadding(24, 18, 24, 18)
        setTextIsSelectable(true)
      })
    }
    val dialog = AlertDialog.Builder(this)
      .setTitle("语音闹钟调试日志")
      .setView(contentView)
      .setPositiveButton("关闭", null)
      .setNeutralButton("复制全部", null)
      .setNegativeButton("清空日志", null)
      .create()
    dialog.setOnShowListener {
      dialog.getButton(AlertDialog.BUTTON_NEUTRAL)?.setOnClickListener {
        try {
          val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
          cm.setPrimaryClip(ClipData.newPlainText("voice_alarm_debug_log", text))
          Toast.makeText(this, "已复制语音调试日志", Toast.LENGTH_SHORT).show()
          logVoice("debugLog.copy", "user copied visible debug log", mapOf("chars" to text.length, "path" to path))
        } catch (t: Throwable) {
          Toast.makeText(this, "复制失败：${t.message ?: t.javaClass.simpleName}", Toast.LENGTH_SHORT).show()
        }
      }
      dialog.getButton(AlertDialog.BUTTON_NEGATIVE)?.setOnClickListener {
        try {
          val deleted = VoiceAlarmDebugLog.clear(this)
          Toast.makeText(this, "已清空语音调试日志/录音（$deleted 个文件）", Toast.LENGTH_SHORT).show()
          dialog.dismiss()
        } catch (t: Throwable) {
          Toast.makeText(this, "清空失败：${t.message ?: t.javaClass.simpleName}", Toast.LENGTH_SHORT).show()
        }
      }
    }
    dialog.show()
  }

  private fun requestBatchManualSubmit() {
    if (selectedSttMode() != "batch") return
    logVoice("batch.manualSubmit.click", "manual submit clicked", mapOf("cachedSeconds" to batchCurrentCachedSeconds, "bufferedBytes" to batchCurrentBufferedBytes, "blocked" to isBatchSpeakerPlaybackBlocked(), "submitting" to batchSubmitInProgress))
    if (isBatchSpeakerPlaybackBlocked()) {
      batchManualSubmitRequested = false
      updateBatchSubmitButton(false, 0.0)
      setBatchStatus("闹钟/AI 正在播报：严格单轮模式暂停录音，等播报结束后再开始，避免播报声进入转文字。")
      return
    }
    if (batchRecognitionInFlight || batchPcmQueue.isNotEmpty() || batchAwaitingAiCommit || aiBusy || speaking || alarmVoicePlaying || pendingAiUserText.isNotBlank()) {
      updateBatchSubmitButton(true)
      setBatchStatus("上一轮语音还没有完成：${batchStrictSingleTurnBusyReason()}。请等 AI 回复/播报结束后再开始下一次录音。")
      return
    }
    if (batchManualSubmitRequested) {
      updateBatchSubmitButton(true)
      setBatchStatus("手动提交中：正在结束当前完整录音并发送转文字，请勿重复点击。")
      return
    }
    if (batchCurrentBufferedBytes <= 0 && !batchHasSpeech && !batchCurrentSpeechDetected) {
      setBatchStatus("麦克风正在初始化或尚未读取到录音。若持续如此，请检查录音权限/系统是否限制后台麦克风。")
      return
    }
    batchManualSubmitRequested = true
    batchSubmitInProgress = true
    updateBatchSubmitButton(true)
    val cached = String.format(Locale.CHINA, "%.1f", batchCurrentCachedSeconds)
    setBatchStatus("手动提交中：正在截取当前 ${cached} 秒录音并发送给语音服务转文字…")
  }

  private fun setBatchStatus(message: String) {
    if (message != batchLastKnownStatus) logVoice("batch.status", message)
    batchLastKnownStatus = message
    val apply = {
      val view = batchStatusView ?: transcriptView
      view?.text = message
    }
    if (Looper.myLooper() == Looper.getMainLooper()) apply() else runOnUiThread { apply() }
  }

  private fun updateBatchSubmitButton(submitting: Boolean, cachedSeconds: Double = batchCurrentCachedSeconds) {
    if (isBatchSpeakerPlaybackBlocked()) {
      batchSubmitButton?.isEnabled = false
      batchSubmitButton?.text = "播报中，暂停收音"
      return
    }
    val hasCurrentAudio = cachedSeconds >= 0.4 || batchCurrentBufferedBytes > 16000
    batchSubmitButton?.isEnabled = !submitting && hasCurrentAudio
    batchSubmitButton?.text = when {
      submitting -> "识别中，请稍候…"
      cachedSeconds >= 0.4 -> "发送当前录音转文字（${String.format(Locale.CHINA, "%.1f", cachedSeconds)}秒）"
      else -> "开始说话后可发送"
    }
  }

  private fun updateBatchRetryButton(enabled: Boolean = batchLastRetryJob != null && !batchSubmitInProgress && !batchRecognitionInFlight && batchPcmQueue.isEmpty()) {
    batchRetryButton?.isEnabled = enabled
    batchRetryButton?.text = if (enabled) "重试上一次录音" else "暂无可重试录音"
  }

  private fun retryLastBatchAudio() {
    if (selectedSttMode() != "batch") return
    if (batchSubmitInProgress || batchRecognitionInFlight || batchPcmQueue.isNotEmpty()) {
      updateBatchSubmitButton(true)
      updateBatchRetryButton(false)
      setBatchStatus("提交中：当前已有录音正在识别，完成后才能重试上一段。")
      return
    }
    val job = batchLastRetryJob
    if (job == null) {
      setBatchStatus("暂无可重试的录音。")
      updateBatchRetryButton(false)
      return
    }
    val retryJob = job.copy(submittedManually = true, submittedAt = System.currentTimeMillis())
    if (batchPcmQueue.offerFirst(retryJob)) {
      batchSubmitInProgress = true
      updateBatchSubmitButton(true)
      updateBatchRetryButton(false)
      val seconds = String.format(Locale.CHINA, "%.1f", retryJob.durationMs / 1000.0)
      setBatchStatus("重试提交中：正在重新发送上一次 ${seconds} 秒录音给${sttProviderLabel(selectedSttProvider())}。")
    } else {
      setBatchStatus("重试失败：语音识别暂时不可用，请稍后再试。")
    }
  }

  private fun batchSttConfig(): JSONObject? = try { JSONObject(payload).optJSONObject("batchStt") } catch (_: Throwable) { null }
  private fun batchAutoSubmitEnabled(): Boolean = batchSttConfig()?.optBoolean("autoSubmit", true) ?: true
  private fun batchAutoSubmitSilenceMs(): Long = (batchSttConfig()?.optLong("autoSubmitSilenceMs", 5000L) ?: 5000L).coerceIn(800L, 30000L)
  private fun batchMaxRecordMs(): Long = (batchSttConfig()?.optLong("maxRecordMs", 60000L) ?: 60000L).coerceIn(5000L, 300000L)
  private fun batchRollingSegmentMs(): Long {
    // ChatGPT / Claude / Grok style voice input should not split one spoken
    // utterance into rolling local fragments.  The recorder now waits for the
    // real endpoint (manual send or trailing silence) and uploads one complete
    // utterance audio file to STT.  Keep this value beyond maxRecordMs so the
    // legacy rolling-submit branch is never reached during normal capture.
    return batchMaxRecordMs() + 10_000L
  }
  private fun batchAutoCorrectEnabled(): Boolean = batchSttConfig()?.optBoolean("autoCorrect", false) ?: false

  private fun recordBatchPcmUntilSubmit(): BatchRecordSegment? {
    val sampleRate = 16000
    val minBuffer = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
    if (minBuffer <= 0) {
      setBatchStatus("录音初始化失败：系统没有返回可用的 AudioRecord buffer。")
      logVoice("batch.record.minBuffer.error", "invalid minBuffer", mapOf("minBuffer" to minBuffer))
      return null
    }
    if (isBatchSpeakerPlaybackBlocked()) {
      releaseContinuousAudioRecord()
      logVoice("batch.record.blockedBeforeStart", "skip opening microphone while alarm/AI is playing", mapOf("speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "blockRemainMs" to (batchSpeakerPlaybackBlockUntil - System.currentTimeMillis()).coerceAtLeast(0L)))
      setBatchStatus("闹钟/AI 播报中：播报帧不会写入 STT；检测到你插话后会先停止播报，再重新干净录音。")
      try { Thread.sleep(250L) } catch (_: Throwable) {}
      return null
    }
    val captureEpoch = batchSpeakerPlaybackEpoch
    val playbackEchoGuard = isBatchPlaybackEchoGuardActive()
    val audioRecord = obtainContinuousAudioRecord(playbackEchoGuard) ?: run {
      setBatchStatus("麦克风启动失败：VOICE_RECOGNITION/MIC 均不可用，请检查录音权限、系统麦克风占用或省电限制。")
      return null
    }
    val out = ByteArrayOutputStream()
    val fallbackOut = ByteArrayOutputStream()
    val buffer = ByteArray(minBuffer)
    val maxMs = batchMaxRecordMs()
    // Chat-app style: no local rolling segments. One user utterance is submitted only on manual send, silence endpoint, or safety max duration.
    val rollingSegmentMs = Long.MAX_VALUE / 4
    val autoSilenceMs = batchAutoSubmitSilenceMs()
    val autoSubmit = batchAutoSubmitEnabled()
    val segmentStartedAt = System.currentTimeMillis()
    val deadline = segmentStartedAt + maxMs
    var speechStarted = false
    var speechStartedAt = 0L
    var softSpeechStarted = false
    var activityStarted = false
    var candidateStarted = false
    var speechHitCount = 0
    var softSpeechHitCount = 0
    var activityHitCount = 0
    var candidateHitCount = 0
    var autoArmStartHitCount = 0
    var autoArmStartFirstAt = 0L
    var autoArmStartLastAt = 0L
    var autoArmVoiceLikeHitCount = 0
    var autoArmStrongVoiceLikeHitCount = 0
    var autoArmRejectedHitCount = 0
    var autoArmEndpointVoiceLikeHitCount = 0
    var autoArmContinuationVoiceLikeStreak = 0
    var autoArmLastVoiceLikeAt = 0L
    var lastSpeechAt = 0L
    var lastSoftSpeechAt = 0L
    var lastActivityAt = 0L
    var lastCandidateAt = 0L
    var submittedManually = false
    var submittedByPlaybackInterrupt = false
    var noiseRms = if (playbackEchoGuard) 120.0 else 24.0
    var lastLevel = AudioLevel(0, 0)
    var lastStatusUiAt = 0L
    var lastEarlyValidationAt = 0L
    val preRoll = java.util.ArrayDeque<ByteArray>()
    var preRollBytes = 0
    val preRollLimitBytes = sampleRate * 2 * 1600 / 1000
    var utteranceFallbackStartByte = -1
    val minBytes = ((sampleRate * 2L * 260L) / 1000L).toInt().coerceAtLeast(sampleRate * 2 / 8)
    batchManualSubmitRequested = false
    batchHasSpeech = false
    batchCurrentBufferedBytes = 0
    batchCurrentCachedSeconds = 0.0
    batchCurrentSpeechDetected = false
    batchCurrentConfirmedSpeech = false
    batchCurrentStartedAt = segmentStartedAt
    batchLastSpeechAt = 0L
    runOnUiThread {
      val submitting = batchSubmitInProgress || batchRecognitionInFlight || batchPcmQueue.isNotEmpty()
      updateBatchSubmitButton(submitting)
      val message = if (submitting) {
        "上一条完整录音正在转文字；录音暂停，等待这一轮完成。"
      } else {
        "自动监听已就绪：无需手动开启；检测到你开始说话后才保存本轮录音，说完${if (autoSubmit) "静音 ${String.format(Locale.CHINA, "%.1f", autoSilenceMs / 1000.0)} 秒自动提交，或" else ""}点击“发送当前录音转文字”。"
      }
      setBatchStatus(message)
    }
    try {
      while (!destroyed && cloudSttActive && System.currentTimeMillis() < deadline) {
        val read = audioRecord.read(buffer, 0, buffer.size)
        if (read < 0) {
          releaseContinuousAudioRecord()
          break
        }
        if (read > 0) {
          val now = System.currentTimeMillis()
          if (batchSpeakerPlaybackEpoch != captureEpoch) {
            val cachedBytes = fallbackOut.size()
            if (speechStarted && cachedBytes >= minBytes) {
              submittedByPlaybackInterrupt = true
              logVoice("batch.capture.playbackEpochSubmit", "playback epoch changed after confirmed speech; submit cached user utterance instead of discarding it", mapOf("cachedBytes" to cachedBytes, "cachedSeconds" to batchCurrentCachedSeconds, "captureEpoch" to captureEpoch, "currentEpoch" to batchSpeakerPlaybackEpoch, "pipeline" to batchChatPipelineVersion))
              runOnUiThread {
                updateBatchSubmitButton(true, batchCurrentCachedSeconds)
                setBatchStatus("检测到播报状态变化，但已捕获到你的语音：保留并提交刚才这段录音，避免漏掉长句。")
              }
              break
            }
            releaseContinuousAudioRecord()
            fallbackOut.reset()
            out.reset()
            preRoll.clear()
            preRollBytes = 0
            batchManualSubmitRequested = false
            batchHasSpeech = false
            batchCurrentBufferedBytes = 0
            batchCurrentCachedSeconds = 0.0
            batchCurrentSpeechDetected = false
            batchCurrentConfirmedSpeech = false
            logVoice("batch.capture.invalidatedByPlayback", "discard current batch capture because app speaker state changed", mapOf("cachedBytes" to cachedBytes, "captureEpoch" to captureEpoch, "currentEpoch" to batchSpeakerPlaybackEpoch, "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "pipeline" to batchChatPipelineVersion))
            runOnUiThread {
              updateBatchSubmitButton(false, 0.0)
              setBatchStatus("检测到闹钟/AI 播报开始或结束：已丢弃当前录音缓存，避免把播报声转成用户文字；播报结束后请重新说。")
            }
            return null
          }
          val frame = buffer.copyOf(read)
          val guardJustBecameActive = isBatchPlaybackEchoGuardActive() && !sharedCaptureIsPlaybackGuard
          if (guardJustBecameActive) {
            // 扬声器播报/播报冷却窗口不能提交当前缓存。
            // 上一版在这里把“播报期间录到的声音”当作 pre-playback speech 提交，
            // 导致闹钟提示词被讯飞完整转成用户文字。
            val cachedBeforeSwitch = fallbackOut.size()
            if (speechStarted && cachedBeforeSwitch >= minBytes) {
              submittedByPlaybackInterrupt = true
              logVoice("batch.capture.speakerMaskSubmit", "playback guard became active after confirmed speech; submit cached user utterance before masking speaker frames", mapOf("cachedBytes" to cachedBeforeSwitch, "cachedSeconds" to batchCurrentCachedSeconds, "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "pipeline" to batchChatPipelineVersion))
              runOnUiThread {
                updateBatchSubmitButton(true, batchCurrentCachedSeconds)
                setBatchStatus("播报/回声保护已启动，但你的语音已确认：先提交当前录音，再屏蔽后续扬声器帧。")
              }
              break
            }
            releaseContinuousAudioRecord()
            fallbackOut.reset()
            out.reset()
            preRoll.clear()
            preRollBytes = 0
            speechStarted = false
            speechStartedAt = 0L
            utteranceFallbackStartByte = -1
            softSpeechStarted = false
            activityStarted = false
            candidateStarted = false
            speechHitCount = 0
            softSpeechHitCount = 0
            activityHitCount = 0
            candidateHitCount = 0
            autoArmStartHitCount = 0
            autoArmStartFirstAt = 0L
            autoArmStartLastAt = 0L
            autoArmVoiceLikeHitCount = 0
            autoArmStrongVoiceLikeHitCount = 0
            autoArmRejectedHitCount = 0
            lastSpeechAt = 0L
            lastSoftSpeechAt = 0L
            lastActivityAt = 0L
            lastCandidateAt = 0L
            batchManualSubmitRequested = false
            batchHasSpeech = false
            batchCurrentBufferedBytes = 0
            batchCurrentCachedSeconds = 0.0
            batchCurrentSpeechDetected = false
            batchCurrentConfirmedSpeech = false
            logVoice("batch.capture.speakerMaskReset", "playback echo guard became active; discard all current audio instead of submitting speaker-prone cache", mapOf("cachedBytes" to cachedBeforeSwitch, "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "pipeline" to batchChatPipelineVersion))
            runOnUiThread {
              updateBatchSubmitButton(false, 0.0)
              setBatchStatus("检测到闹钟/AI 播报：本次麦克风缓存已作废，播报声音不会写入转文字音频；请等播报结束后再说。")
            }
            return null
          }
          // 非实时文件转写不能像实时 barge-in 一样边播报边收音：
          // 文件模式一旦把闹钟/TTS 扬声器声音写入音频，服务商会把它当成用户文字返回。
          // 因此只要 App 自己正在播报、闹钟服务正在播报，或刚播报结束的冷却窗口内，
          // 当前缓存全部作废并丢弃这些帧；播报结束稳定后重新从 0 开始缓存用户声音。
          if (isBatchSpeakerPlaybackBlocked()) {
            val cachedBeforePlayback = fallbackOut.size()
            val hasSubmitReadySpeech = speechStarted && cachedBeforePlayback >= minBytes
            releaseContinuousAudioRecord()
            if (hasSubmitReadySpeech) {
              // 如果闹钟/TTS 播报在用户说完前后突然开始，不要把前面已经录到的用户语音直接丢掉。
              // 当前帧尚未写入 fallbackOut，因此不会把刚开始的扬声器声音混入提交音频。
              submittedByPlaybackInterrupt = true
              logVoice("batch.record.playbackInterruptSubmit", "playback started; submit cached user speech before pausing microphone", mapOf("speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "cachedBytes" to cachedBeforePlayback, "cachedSeconds" to batchCurrentCachedSeconds, "speechStarted" to speechStarted, "softSpeechStarted" to softSpeechStarted))
              runOnUiThread {
                updateBatchSubmitButton(true, batchCurrentCachedSeconds)
                setBatchStatus("播报开始前已捕获到用户语音：先提交刚才的录音转文字，再暂停麦克风避免录入播报声。")
              }
              break
            }
            fallbackOut.reset()
            out.reset()
            preRoll.clear()
            preRollBytes = 0
            speechStarted = false
            utteranceFallbackStartByte = -1
            softSpeechStarted = false
            activityStarted = false
            candidateStarted = false
            speechHitCount = 0
            softSpeechHitCount = 0
            activityHitCount = 0
            candidateHitCount = 0
            autoArmStartHitCount = 0
            autoArmStartFirstAt = 0L
            autoArmStartLastAt = 0L
            autoArmVoiceLikeHitCount = 0
            autoArmStrongVoiceLikeHitCount = 0
            autoArmRejectedHitCount = 0
            lastSpeechAt = 0L
            lastSoftSpeechAt = 0L
            lastActivityAt = 0L
            lastCandidateAt = 0L
            batchManualSubmitRequested = false
            batchHasSpeech = false
            batchCurrentBufferedBytes = 0
            batchCurrentCachedSeconds = 0.0
            batchCurrentSpeechDetected = false
            batchCurrentConfirmedSpeech = false
            logVoice("batch.record.blockedDuringCapture", "playback started during batch capture; no confirmed user speech, discard current cache and release microphone", mapOf("speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "cachedBytes" to cachedBeforePlayback, "speechStarted" to speechStarted, "softSpeechStarted" to softSpeechStarted))
            if (now - batchPlaybackBlockedStatusAt >= 1200L) {
              batchPlaybackBlockedStatusAt = now
              runOnUiThread {
                updateBatchSubmitButton(false, 0.0)
                setBatchStatus("闹钟/AI 播报中：录音暂停，避免把播报声当成用户输入。")
              }
            }
            try { Thread.sleep(250L) } catch (_: Throwable) {}
            return null
          }
          val dynamicPlaybackGuard = isBatchPlaybackEchoGuardActive()
          val level = audioFrameLevel(buffer, read)
          lastLevel = level
          if (dynamicPlaybackGuard) {
            // 聊天 App 式非实时输入的核心：App 自己的播报帧不能写入待转写音频。
            // 这里仍然读取麦克风、计算能量，只用于判断用户是否强插话；不把扬声器声音缓存到 fallback/out/preRoll。
            val bargeInShape = batchAudioVoiceShape(frame, read)
            val strongBargeIn = hasBatchBargeInSpeech(level, bargeInShape, noiseRms) && (speaking || alarmVoicePlaying)
            if (strongBargeIn) {
              logVoice("batch.bargeIn.detected", "strong user speech detected while app speaker is active; stop speaker and discard speaker frames before clean capture", mapOf("rms" to level.rms, "peak" to level.peak, "noiseRms" to String.format(Locale.US, "%.1f", noiseRms), "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "pipeline" to batchChatPipelineVersion))
              interruptPlaybackForUserSpeech("用户插话")
              fallbackOut.reset()
              out.reset()
              preRoll.clear()
              preRollBytes = 0
              speechStarted = false
              speechStartedAt = 0L
              utteranceFallbackStartByte = -1
              softSpeechStarted = false
              activityStarted = false
              candidateStarted = false
              speechHitCount = 0
              softSpeechHitCount = 0
              activityHitCount = 0
              candidateHitCount = 0
              autoArmStartHitCount = 0
              autoArmStartFirstAt = 0L
              autoArmStartLastAt = 0L
              lastSpeechAt = 0L
              lastSoftSpeechAt = 0L
              lastActivityAt = 0L
              lastCandidateAt = 0L
              batchCurrentBufferedBytes = 0
              batchCurrentCachedSeconds = 0.0
              batchCurrentSpeechDetected = false
              batchCurrentConfirmedSpeech = false
              runOnUiThread { setBatchStatus("检测到你在播报中说话：已停止播报并清空扬声器帧，正在重新干净录音。") }
              continue
            }
            if (speechStarted && fallbackOut.size() >= minBytes) {
              submittedByPlaybackInterrupt = true
              logVoice("batch.speakerFrame.masked.submit", "speaker/echo-guard frame arrived after confirmed speech; submit cached user utterance instead of resetting it", mapOf("rms" to level.rms, "peak" to level.peak, "cachedBytes" to fallbackOut.size(), "cachedSeconds" to batchCurrentCachedSeconds, "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "pipeline" to batchChatPipelineVersion))
              runOnUiThread {
                updateBatchSubmitButton(true, batchCurrentCachedSeconds)
                setBatchStatus("检测到播报/回声帧，但已缓存到你的完整语音：正在提交当前录音，后续扬声器帧不会进入 STT。")
              }
              break
            }
            if (fallbackOut.size() > 0 || out.size() > 0 || preRollBytes > 0 || speechStarted || softSpeechStarted || activityStarted || candidateStarted) {
              logVoice("batch.speakerFrame.masked.reset", "speaker/echo-guard frame detected; discard current cache so prompt audio is not submitted as user speech", mapOf("rms" to level.rms, "peak" to level.peak, "cachedBytes" to fallbackOut.size(), "strictBytes" to out.size(), "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "pipeline" to batchChatPipelineVersion))
            }
            fallbackOut.reset()
            out.reset()
            preRoll.clear()
            preRollBytes = 0
            speechStarted = false
            speechStartedAt = 0L
            utteranceFallbackStartByte = -1
            softSpeechStarted = false
            activityStarted = false
            candidateStarted = false
            speechHitCount = 0
            softSpeechHitCount = 0
            activityHitCount = 0
            candidateHitCount = 0
            autoArmStartHitCount = 0
            autoArmStartFirstAt = 0L
            autoArmStartLastAt = 0L
            autoArmVoiceLikeHitCount = 0
            autoArmStrongVoiceLikeHitCount = 0
            autoArmRejectedHitCount = 0
            lastSpeechAt = 0L
            lastSoftSpeechAt = 0L
            lastActivityAt = 0L
            lastCandidateAt = 0L
            batchManualSubmitRequested = false
            batchHasSpeech = false
            batchCurrentBufferedBytes = 0
            batchCurrentCachedSeconds = 0.0
            batchCurrentSpeechDetected = false
            batchCurrentConfirmedSpeech = false
            if (now - batchPlaybackBlockedStatusAt >= 1200L) {
              batchPlaybackBlockedStatusAt = now
              logVoice("batch.speakerFrame.masked", "speaker/echo-guard frame ignored; waiting for clean user speech", mapOf("rms" to level.rms, "peak" to level.peak, "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "pipeline" to batchChatPipelineVersion))
              runOnUiThread {
                updateBatchSubmitButton(false, 0.0)
                setBatchStatus("闹钟/AI 播报或回声冷却中：录音已暂停，等播报/回声冷却结束后再开始。")
              }
            }
            continue
          }

          // v9：自动待命，但不是“从打开麦克风开始无限缓存”。
          // 麦克风会自动开启并等待用户开口；只有确认用户开始说话后，才创建这一轮
          // user_utterance buffer。开口前只保留很短 pre-roll，避免把长空白、等待、
          // 播报冷却、环境噪声当成待上传音频。
          var wroteCurrentFrameToFallback = false
          if (speechStarted) {
            fallbackOut.write(frame)
            wroteCurrentFrameToFallback = true
          }
          batchCurrentBufferedBytes = fallbackOut.size()
          batchCurrentCachedSeconds = fallbackOut.size() / (sampleRate * 2.0)

          val speech = hasBatchSpeechEnergy(level, noiseRms, dynamicPlaybackGuard)
          val softSpeech = hasBatchSoftSpeechEnergy(level, noiseRms, dynamicPlaybackGuard)
          val likelyVoiceActivity = hasBatchLikelyVoiceActivity(level, noiseRms, dynamicPlaybackGuard)
          val candidateVoiceActivity = hasBatchCandidateVoiceActivity(level, noiseRms, dynamicPlaybackGuard)
          // v13：参考成熟 VAD 的做法：RMS/peak 只允许进入“候选”，不能单独确认用户开口。
          // 每一帧都计算轻量人声形态，这样 speechStarted=true 之后也不会退化成纯能量端点。
          val autoArmVoiceShape = batchAudioVoiceShape(frame, read)
          val candidateLooksVoiceLike = candidateVoiceActivity && isBatchCandidateVoiceLike(autoArmVoiceShape, level, noiseRms, dynamicPlaybackGuard)
          val autoArmStartEnergy = hasBatchAutoArmStartSpeechEnergy(level, noiseRms, dynamicPlaybackGuard)
          val postPlaybackHandoffActive = isPostPlaybackHandoffActive()
          val autoArmWarmVoiceEnergy = !postPlaybackHandoffActive && hasBatchAutoArmWarmVoiceEnergy(level, noiseRms, dynamicPlaybackGuard) && candidateLooksVoiceLike
          val autoArmStartCandidate = autoArmStartEnergy || autoArmWarmVoiceEnergy
          val autoArmVoiceLike = if (autoArmStartEnergy) {
            isBatchAutoArmVoiceLike(autoArmVoiceShape, level, noiseRms)
          } else {
            autoArmWarmVoiceEnergy
          }
          val autoArmEndpointVoiceLike = isBatchAutoArmEndpointVoiceLike(autoArmVoiceShape, level, noiseRms, dynamicPlaybackGuard)
          val autoArmContinuationVoiceLike = isBatchEndpointContinuationVoiceLike(autoArmVoiceShape, level, noiseRms, dynamicPlaybackGuard)
          val autoArmStartSpeech = autoArmStartCandidate && autoArmVoiceLike
          if (!speechStarted && !softSpeech && !speech && !autoArmStartCandidate && level.rms < 180 && level.peak < 1200 && !dynamicPlaybackGuard) {
            noiseRms = (noiseRms * 0.96 + level.rms.toDouble() * 0.04).coerceIn(10.0, 900.0)
          }
          if (!speechStarted) {
            preRollBytes = pushPreRoll(preRoll, frame, preRollBytes, preRollLimitBytes)
            // v10：自动待命模式不能用普通 speech=true 直接确认“用户开始说话”。
            // 之前 rms≈300-600、peak≈800-1600 的环境声/残留声会被累计 2 帧后误判，
            // 于是明明没人说话也创建 18 秒录音。现在只有连续强开口证据才会建本轮 utterance。
            if (autoArmStartCandidate) {
              if (autoArmStartHitCount == 0) autoArmStartFirstAt = now
              autoArmStartHitCount += 1
              autoArmStartLastAt = now
              if (autoArmVoiceLike) {
                autoArmVoiceLikeHitCount += 1
                if (autoArmVoiceShape.voicedScore >= 22 || autoArmVoiceShape.zcrPermille in 10..220 || autoArmVoiceShape.crestX100 in 140..2400) {
                  autoArmStrongVoiceLikeHitCount += 1
                }
              } else {
                autoArmRejectedHitCount += 1
              }
            } else {
              autoArmStartHitCount = 0
              autoArmStartFirstAt = 0L
              autoArmStartLastAt = 0L
              autoArmVoiceLikeHitCount = 0
              autoArmStrongVoiceLikeHitCount = 0
              autoArmRejectedHitCount = 0
              autoArmEndpointVoiceLikeHitCount = 0
              autoArmContinuationVoiceLikeStreak = 0
              autoArmLastVoiceLikeAt = 0L
            }
            if (autoArmEndpointVoiceLike) {
              autoArmEndpointVoiceLikeHitCount += 1
              autoArmLastVoiceLikeAt = now
            }
            speechHitCount = if (autoArmStartSpeech) speechHitCount + 1 else 0
            softSpeechHitCount = if (softSpeech) softSpeechHitCount + 1 else 0
            activityHitCount = if (likelyVoiceActivity) activityHitCount + 1 else 0
          } else if (likelyVoiceActivity) {
            activityHitCount = activityHitCount + 1
          } else {
            activityHitCount = 0
          }
          if (speechStarted && autoArmEndpointVoiceLike) {
            autoArmEndpointVoiceLikeHitCount += 1
            autoArmLastVoiceLikeAt = now
          }
          if (candidateVoiceActivity) {
            candidateHitCount = (candidateHitCount + 1).coerceAtMost(100)
          } else if (candidateHitCount > 0) {
            candidateHitCount -= 1
          }
          if (candidateVoiceActivity && candidateLooksVoiceLike && candidateHitCount >= 3) {
            candidateStarted = true
            lastCandidateAt = now
            // 只是候选声音，不等于用户说话；不建立可提交录音，也不点亮“发送”。
            batchCurrentSpeechDetected = false
          }
          if (likelyVoiceActivity && candidateLooksVoiceLike && activityHitCount >= 4) {
            activityStarted = true
            lastActivityAt = now
            // 只是可能的人声活动，不等于已确认用户开口。
            batchCurrentSpeechDetected = false
          }
          // v13：采用“候选 -> 确认 -> 迟滞”的三段式。
          // 参考 WebRTC/服务端 VAD 的思想：连续窗口、人声形态和 padding/端点要分开处理；
          // 纯能量连续很久也只能是候选，不能变成 speech_started。
          val requiredHits = if (postPlaybackHandoffActive) 18 else 8
          val minStartWindowMs = if (postPlaybackHandoffActive) 1200L else 480L
          val startWindowOk = autoArmStartFirstAt > 0L && (now - autoArmStartFirstAt) >= minStartWindowMs
          val voiceLikeRatioOk = autoArmStartHitCount > 0 && autoArmVoiceLikeHitCount * 100 >= autoArmStartHitCount * 58
          val strongVoiceShapeOk = autoArmStrongVoiceLikeHitCount >= maxOf(3, requiredHits / 3)
          val endpointVoiceOk = autoArmEndpointVoiceLikeHitCount >= maxOf(4, requiredHits / 2)
          val warmVoiceShapeOk =
            autoArmVoiceLikeHitCount >= maxOf(5, requiredHits / 2) &&
            autoArmEndpointVoiceLikeHitCount >= maxOf(5, requiredHits / 2)
          val sustainedWarmVoiceOk =
            autoArmStartHitCount >= maxOf(requiredHits * 2, 12) &&
            autoArmStrongVoiceLikeHitCount >= maxOf(requiredHits, 8) &&
            autoArmVoiceLikeHitCount * 100 >= autoArmStartHitCount * 68 &&
            autoArmEndpointVoiceLikeHitCount >= maxOf(2, requiredHits / 4) &&
            (speech || softSpeech) &&
            autoArmStartFirstAt > 0L &&
            now - autoArmStartFirstAt >= maxOf(minStartWindowMs, 900L)
          val rejectedTooMany = autoArmRejectedHitCount >= 4 && autoArmRejectedHitCount * 100 > autoArmStartHitCount * 24
          val confirmedSpeech = speechStarted ||
            (autoArmStartSpeech && speechHitCount >= requiredHits && startWindowOk && voiceLikeRatioOk && (strongVoiceShapeOk || warmVoiceShapeOk) && (endpointVoiceOk || sustainedWarmVoiceOk) && !rejectedTooMany)
          if (softSpeech && softSpeechHitCount >= 2) {
            // 软声音只代表“有较明显声音输入”，不能直接确认为用户说话；
            // 否则底噪/口水音/残留播放声会持续刷新静音端点，导致永远不提交，
            // 或把一整段无效长录音送到讯飞，只返回“嗯。”。
            softSpeechStarted = true
            lastSoftSpeechAt = now
          }
          if (confirmedSpeech) {
            if (!speechStarted) {
              val startingDuringPlayback = isBatchPlaybackEchoGuardActive()
              speechStarted = true
              speechStartedAt = now
              utteranceFallbackStartByte = 0
              batchHasSpeech = true
              batchCurrentSpeechDetected = true
              batchCurrentConfirmedSpeech = true
              if (startingDuringPlayback) {
                // 真正的 barge-in 流程：识别线程一直监听，但一旦发现足够强的人声，
                // 先停止/延后 App 自己的播报，再从后续干净帧开始保存用户语音。
                // 不把播报期间的 pre-roll 写入待转写文件，避免“补水/整理好心情”等播报词混入用户文本。
                logVoice("batch.bargeIn.detected", "strong user speech detected during playback; stop speaker and start clean capture", mapOf("rms" to level.rms, "peak" to level.peak, "noiseRms" to String.format(Locale.US, "%.1f", noiseRms), "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying))
                interruptPlaybackForUserSpeech("用户插话")
                out.reset()
                fallbackOut.reset()
                preRoll.clear()
                preRollBytes = 0
                batchCurrentBufferedBytes = 0
                batchCurrentCachedSeconds = 0.0
                speechStarted = false
                speechStartedAt = 0L
                utteranceFallbackStartByte = -1
                batchCurrentConfirmedSpeech = false
                lastSpeechAt = 0L
                batchLastSpeechAt = 0L
                speechHitCount = 0
                softSpeechHitCount = 0
                activityHitCount = 0
                candidateHitCount = 0
                autoArmStartHitCount = 0
                autoArmStartFirstAt = 0L
                autoArmStartLastAt = 0L
                autoArmVoiceLikeHitCount = 0
                autoArmStrongVoiceLikeHitCount = 0
                autoArmRejectedHitCount = 0
                autoArmEndpointVoiceLikeHitCount = 0
                autoArmContinuationVoiceLikeStreak = 0
                autoArmLastVoiceLikeAt = 0L
                runOnUiThread { setBatchStatus("检测到播报期间有声音：已丢弃播报窗口音频，等播报结束后重新录音。") }
                continue
              }
              fallbackOut.reset()
              for (frameInPreRoll in preRoll) {
                out.write(frameInPreRoll)
                fallbackOut.write(frameInPreRoll)
              }
              utteranceFallbackStartByte = 0
              lastSpeechAt = now
              batchLastSpeechAt = now
              preRoll.clear()
              preRollBytes = 0
              logVoice("batch.vad.speechStart", "confirmed user speech start", mapOf("rms" to level.rms, "peak" to level.peak, "noiseRms" to String.format(Locale.US, "%.1f", noiseRms), "speech" to speech, "softSpeech" to softSpeech, "autoStart" to autoArmStartSpeech, "warmVoice" to autoArmWarmVoiceEnergy, "startHits" to autoArmStartHitCount, "requiredHits" to requiredHits, "startWindowMs" to (now - autoArmStartFirstAt).coerceAtLeast(0L), "voiceLikeHits" to autoArmVoiceLikeHitCount, "strongVoiceLikeHits" to autoArmStrongVoiceLikeHitCount, "endpointVoiceLikeHits" to autoArmEndpointVoiceLikeHitCount, "rejectedHits" to autoArmRejectedHitCount, "zcr" to autoArmVoiceShape.zcrPermille, "voicedScore" to autoArmVoiceShape.voicedScore, "crestX100" to autoArmVoiceShape.crestX100, "mode" to "auto_armed_balanced_chat_vad_manual_send_semantics"))
              runOnUiThread {
                if (!batchSubmitInProgress) {
                  setBatchStatus("已检测到用户说话，非实时录音中…说完停顿后自动提交。")
                }
              }
            }
            if (!wroteCurrentFrameToFallback) {
              fallbackOut.write(frame)
              wroteCurrentFrameToFallback = true
              batchCurrentBufferedBytes = fallbackOut.size()
              batchCurrentCachedSeconds = fallbackOut.size() / (sampleRate * 2.0)
            }
            out.write(buffer, 0, read)
            // speechStarted=true 只代表“这一段已经开始录用户语音”，不能每一帧都刷新 lastSpeechAt。
            // 播报后第二句常是短句；如果把后续低能量环境声/残留回声都当作续写，
            // 静音倒计时会被反复重置，表现为“缓存时长一直增加但不转文字”。
            // 只有连续、足够强的人声续写证据才刷新端点；短句结束后让静音计时自然提交。
            val cachedSecondsNow = fallbackOut.size() / (sampleRate * 2.0)
            if (autoArmContinuationVoiceLike) {
              autoArmContinuationVoiceLikeStreak += 1
            } else {
              autoArmContinuationVoiceLikeStreak = 0
            }
            val strongContinuationEnergy = speech || (softSpeech && level.rms >= maxOf(760.0, noiseRms * 4.8).toInt())
            val canRefreshSpeechTail = when {
              cachedSecondsNow < 6.0 -> autoArmContinuationVoiceLikeStreak >= 2
              cachedSecondsNow < 12.0 -> autoArmContinuationVoiceLikeStreak >= 3 && strongContinuationEnergy
              else -> autoArmContinuationVoiceLikeStreak >= 4 && speech
            }
            if (canRefreshSpeechTail) {
              lastSpeechAt = now
              batchLastSpeechAt = now
              autoArmLastVoiceLikeAt = now
            }
          } else if (speechStarted) {
            out.write(buffer, 0, read)
          }
          if (
            speechStarted &&
            !submittedManually &&
            !batchSubmitInProgress &&
            speechStartedAt > 0L &&
            now - speechStartedAt >= 1200L &&
            now - lastEarlyValidationAt >= 500L &&
            fallbackOut.size() >= minBytes &&
            fallbackOut.size() < sampleRate * 2 * 4200 / 1000 &&
            (lastSpeechAt == 0L || now - lastSpeechAt >= 1200L)
          ) {
            lastEarlyValidationAt = now
            val earlyValidation = validateBatchAutoArmSpeechSegment(fallbackOut.toByteArray(), sampleRate, noiseRms)
            val likelyShortUserUtterance = earlyValidation.durationMs <= 5200L && (
              earlyValidation.voiceFrames >= 2 || earlyValidation.strongFrames >= 1
            )
            if (!earlyValidation.ok && likelyShortUserUtterance) {
              logVoice("batch.vad.falseStartEarlyKeep", "keep likely short user utterance despite early weak validation; let silence endpoint submit it", mapOf("reason" to earlyValidation.reason, "frames" to earlyValidation.frames, "voiceFrames" to earlyValidation.voiceFrames, "strongFrames" to earlyValidation.strongFrames, "durationMs" to earlyValidation.durationMs, "cachedBytes" to fallbackOut.size(), "cachedSeconds" to String.format(Locale.US, "%.1f", fallbackOut.size() / (sampleRate * 2.0)), "bestRms" to earlyValidation.bestRms, "bestPeak" to earlyValidation.bestPeak, "noiseRms" to String.format(Locale.US, "%.1f", noiseRms), "pipeline" to batchChatPipelineVersion))
            } else if (!earlyValidation.ok) {
              logVoice("batch.vad.falseStartEarlyReset", "early reset false-start capture so silent cache does not keep growing", mapOf("reason" to earlyValidation.reason, "frames" to earlyValidation.frames, "voiceFrames" to earlyValidation.voiceFrames, "strongFrames" to earlyValidation.strongFrames, "durationMs" to earlyValidation.durationMs, "cachedBytes" to fallbackOut.size(), "cachedSeconds" to String.format(Locale.US, "%.1f", fallbackOut.size() / (sampleRate * 2.0)), "bestRms" to earlyValidation.bestRms, "bestPeak" to earlyValidation.bestPeak, "noiseRms" to String.format(Locale.US, "%.1f", noiseRms), "pipeline" to batchChatPipelineVersion))
              fallbackOut.reset()
              out.reset()
              preRoll.clear()
              preRollBytes = 0
              speechStarted = false
              speechStartedAt = 0L
              utteranceFallbackStartByte = -1
              softSpeechStarted = false
              activityStarted = false
              candidateStarted = false
              speechHitCount = 0
              softSpeechHitCount = 0
              activityHitCount = 0
              candidateHitCount = 0
              autoArmStartHitCount = 0
              autoArmStartFirstAt = 0L
              autoArmStartLastAt = 0L
              autoArmVoiceLikeHitCount = 0
              autoArmStrongVoiceLikeHitCount = 0
              autoArmRejectedHitCount = 0
              autoArmEndpointVoiceLikeHitCount = 0
              autoArmContinuationVoiceLikeStreak = 0
              autoArmLastVoiceLikeAt = 0L
              lastSpeechAt = 0L
              batchLastSpeechAt = 0L
              batchHasSpeech = false
              batchCurrentBufferedBytes = 0
              batchCurrentCachedSeconds = 0.0
              batchCurrentSpeechDetected = false
              batchCurrentConfirmedSpeech = false
              runOnUiThread {
                updateBatchSubmitButton(false, 0.0)
                setBatchStatus("自动监听待命：刚才像是环境声误触发，已清空缓存；请继续正常说话。")
              }
              continue
            }
          }
          if (now - lastStatusUiAt >= 1200L) {
            lastStatusUiAt = now
            val cachedSec = fallbackOut.size() / (sampleRate * 2.0)
            val effectiveSilenceMs = if (speechStarted && cachedSec >= 12.0) minOf(autoSilenceMs, 2500L) else autoSilenceMs
            runOnUiThread {
              if (!batchSubmitInProgress) {
                val state = when {
                  speechStarted -> "已检测到用户说话"
                  softSpeechStarted || activityStarted || candidateStarted -> "检测到疑似人声，尚未确认是用户说话"
                  candidateVoiceActivity -> "检测到环境声/底噪，未建立录音"
                  else -> "等待说话"
                }
                val cachedText = String.format(Locale.CHINA, "%.1f", cachedSec)
                val silenceReferenceAtForUi = when {
                  speechStarted && lastSpeechAt > 0L -> lastSpeechAt
                  else -> 0L
                }
                val submitHint = if (autoSubmit && silenceReferenceAtForUi > 0L) {
                  val left = ((effectiveSilenceMs - (now - silenceReferenceAtForUi)).coerceAtLeast(0L)) / 1000.0
                  "静音倒计时 ${String.format(Locale.CHINA, "%.1f", left)} 秒自动提交。"
                } else if (autoSubmit && (activityStarted || candidateStarted)) {
                  "请继续正常说话；系统会在人声连续稳定后才开始录音。"
                } else if (autoSubmit && candidateVoiceActivity) {
                  "当前更像环境声/底噪，不会提交给语音服务。"
                } else if (autoSubmit) {
                  "说完停顿 ${String.format(Locale.CHINA, "%.1f", autoSilenceMs / 1000.0)} 秒自动提交。"
                } else {
                  "可手动提交。"
                }
                logVoice("batch.vad.status", "batch VAD state", mapOf("state" to state, "rms" to lastLevel.rms, "peak" to lastLevel.peak, "noiseRms" to String.format(Locale.US, "%.1f", noiseRms), "speech" to speech, "soft" to softSpeech, "activity" to likelyVoiceActivity, "candidate" to candidateVoiceActivity, "candidateVoiceLike" to candidateLooksVoiceLike, "autoStartEnergy" to autoArmStartEnergy, "warmVoiceEnergy" to autoArmWarmVoiceEnergy, "autoStartVoiceLike" to autoArmVoiceLike, "startHits" to autoArmStartHitCount, "voiceLikeHits" to autoArmVoiceLikeHitCount, "strongVoiceLikeHits" to autoArmStrongVoiceLikeHitCount, "endpointVoiceLikeHits" to autoArmEndpointVoiceLikeHitCount, "rejectedHits" to autoArmRejectedHitCount, "requiredHits" to requiredHits, "zcr" to autoArmVoiceShape.zcrPermille, "voicedScore" to autoArmVoiceShape.voicedScore, "speechStarted" to speechStarted, "softStarted" to softSpeechStarted, "cachedSeconds" to String.format(Locale.US, "%.1f", cachedSec)))
                updateBatchSubmitButton(false, cachedSec)
                if (speechStarted) {
                  setBatchStatus("非实时录音中：$state，已缓存 $cachedText 秒。$submitHint")
                } else {
                  setBatchStatus("自动监听待命：$state；尚未建立待提交录音。$submitHint")
                }
              }
            }
          }
          if (batchManualSubmitRequested) {
            submittedManually = true
            logVoice("batch.record.manualSubmit", "manual submit breaks current capture", mapOf("cachedBytes" to fallbackOut.size(), "cachedSeconds" to batchCurrentCachedSeconds, "speechStarted" to speechStarted, "softSpeechStarted" to softSpeechStarted, "activityStarted" to activityStarted, "candidateStarted" to candidateStarted))
            break
          }
          val silenceReferenceAt = when {
            speechStarted && lastSpeechAt > 0L -> lastSpeechAt
            else -> 0L
          }
          val effectiveAutoSilenceMs = if (speechStarted && fallbackOut.size() / (sampleRate * 2.0) >= 12.0) minOf(autoSilenceMs, 2500L) else autoSilenceMs
          // Disabled by design. ChatGPT / Claude / Grok style voice input records one complete user utterance
          // and sends that complete audio once. Local rolling split was the root cause of missing tails.
          if (speechStarted && autoSubmit && silenceReferenceAt > 0L && now - silenceReferenceAt >= effectiveAutoSilenceMs) {
            val validation = validateBatchAutoArmSpeechSegment(fallbackOut.toByteArray(), sampleRate, noiseRms)
            val likelyShortUserUtterance = validation.durationMs <= 6500L && (
              validation.voiceFrames >= 2 || validation.strongFrames >= 1
            )
            if (!validation.ok && !likelyShortUserUtterance) {
              logVoice("batch.vad.falseStartDiscarded", "discard auto-start capture because buffered audio does not contain enough speech-like frames", mapOf("reason" to validation.reason, "frames" to validation.frames, "voiceFrames" to validation.voiceFrames, "strongFrames" to validation.strongFrames, "durationMs" to validation.durationMs, "cachedBytes" to fallbackOut.size(), "cachedSeconds" to String.format(Locale.US, "%.1f", batchCurrentCachedSeconds), "bestRms" to validation.bestRms, "bestPeak" to validation.bestPeak, "noiseRms" to String.format(Locale.US, "%.1f", noiseRms), "pipeline" to batchChatPipelineVersion))
              fallbackOut.reset()
              out.reset()
              preRoll.clear()
              preRollBytes = 0
              speechStarted = false
              speechStartedAt = 0L
              softSpeechStarted = false
              activityStarted = false
              candidateStarted = false
              speechHitCount = 0
              softSpeechHitCount = 0
              activityHitCount = 0
              candidateHitCount = 0
              autoArmStartHitCount = 0
              autoArmStartFirstAt = 0L
              autoArmStartLastAt = 0L
              autoArmVoiceLikeHitCount = 0
              autoArmStrongVoiceLikeHitCount = 0
              autoArmRejectedHitCount = 0
              autoArmEndpointVoiceLikeHitCount = 0
              autoArmContinuationVoiceLikeStreak = 0
              autoArmLastVoiceLikeAt = 0L
              lastSpeechAt = 0L
              batchLastSpeechAt = 0L
              batchCurrentBufferedBytes = 0
              batchCurrentCachedSeconds = 0.0
              batchCurrentSpeechDetected = false
              batchCurrentConfirmedSpeech = false
              runOnUiThread { setBatchStatus("自动监听待命：刚才的声音不像完整用户语音，已丢弃；请继续正常说话。") }
              continue
            }
            logVoice("batch.record.autoSubmit", "user speech silence timeout reached", mapOf("silenceMs" to (now - silenceReferenceAt), "thresholdMs" to effectiveAutoSilenceMs, "configuredThresholdMs" to autoSilenceMs, "cachedBytes" to fallbackOut.size(), "cachedSeconds" to batchCurrentCachedSeconds, "lastRms" to lastLevel.rms, "lastPeak" to lastLevel.peak, "noiseRms" to String.format(Locale.US, "%.1f", noiseRms), "voiceFrames" to validation.voiceFrames, "strongFrames" to validation.strongFrames))
            break
          }
        }
      }
    } catch (_: Throwable) {
      releaseContinuousAudioRecord()
      return null
    } finally {
      batchManualSubmitRequested = false
      batchHasSpeech = false
      batchCurrentBufferedBytes = 0
      batchCurrentCachedSeconds = 0.0
      batchCurrentSpeechDetected = false
      batchCurrentConfirmedSpeech = false
      batchCurrentStartedAt = 0L
      batchLastSpeechAt = 0L
    }
    if (batchSpeakerPlaybackEpoch != captureEpoch && !submittedByPlaybackInterrupt) {
      val cachedBytes = fallbackOut.size()
      releaseContinuousAudioRecord()
      logVoice("batch.capture.invalidatedBeforeSubmit", "discard captured audio before upload because playback changed during this turn", mapOf("cachedBytes" to cachedBytes, "captureEpoch" to captureEpoch, "currentEpoch" to batchSpeakerPlaybackEpoch, "pipeline" to batchChatPipelineVersion))
      runOnUiThread {
        updateBatchSubmitButton(false, 0.0)
        setBatchStatus("刚才的录音跨过了闹钟/AI 播报窗口，已丢弃以避免误识别播报内容；请在播报结束后重新说一遍。")
      }
      return null
    }
    val endedAt = System.currentTimeMillis()
    val strictAudio = out.toByteArray()
    val fallbackAudio = fallbackOut.toByteArray()
    if (speechStarted) {
      // Chat-app style upload: submit the full utterance window once.
      // Prefer the continuous fallback slice from confirmed speech start to endpoint because it contains every frame,
      // including quiet gaps inside the user's sentence. The older strict buffer could be shorter than the real utterance.
      val fullUtteranceAudio = if (utteranceFallbackStartByte >= 0 && utteranceFallbackStartByte < fallbackAudio.size) {
        fallbackAudio.copyOfRange(utteranceFallbackStartByte, fallbackAudio.size)
      } else strictAudio
      val naturalAudio = if (fullUtteranceAudio.size >= minBytes) fullUtteranceAudio else strictAudio
      if (naturalAudio.size >= minBytes) {
        val compactedAudio = compactPcmForStt(naturalAudio, sampleRate, reason = if (submittedManually) "manualSubmit" else "autoSubmit")
        val submittedAudio = if (compactedAudio.size >= minBytes) compactedAudio else naturalAudio
        val originalAudio = naturalAudio
        val metrics = audioFrameLevel(submittedAudio, submittedAudio.size)
        logVoice("batch.record.segment", "complete utterance segment ready", mapOf("manual" to submittedManually, "playbackInterrupt" to submittedByPlaybackInterrupt, "durationMs" to (endedAt - segmentStartedAt), "submittedBytes" to submittedAudio.size, "originalBytes" to originalAudio.size, "strictBytes" to strictAudio.size, "fallbackBytes" to fallbackAudio.size, "utteranceStartByte" to utteranceFallbackStartByte, "peak" to metrics.peak, "rms" to metrics.rms, "pipeline" to batchChatPipelineVersion))
        return BatchRecordSegment(submittedAudio, originalAudio, segmentStartedAt, endedAt, submittedManually, speechDetected = true, peak = metrics.peak, rms = metrics.rms)
      }
    }
    // 手动提交：只要当前段有可用音频，就像聊天输入框点击发送一样立刻提交，不再因 VAD 没确认而拒绝。
    // 自动提交：需要至少软语音启动，避免环境噪声无限触发空请求。
    if ((submittedManually || speechStarted) && fallbackAudio.size >= minBytes) {
      val compactedAudio = compactPcmForStt(fallbackAudio, sampleRate, reason = if (submittedManually) "manualFallback" else "autoFallback")
      val submittedAudio = if (compactedAudio.size >= minBytes) compactedAudio else fallbackAudio
      val metrics = audioFrameLevel(submittedAudio, submittedAudio.size)
      logVoice("batch.record.segment", "complete fallback utterance segment ready", mapOf("manual" to submittedManually, "playbackInterrupt" to submittedByPlaybackInterrupt, "durationMs" to (endedAt - segmentStartedAt), "submittedBytes" to submittedAudio.size, "originalBytes" to fallbackAudio.size, "peak" to metrics.peak, "rms" to metrics.rms, "speech" to (softSpeechStarted || speechStarted), "pipeline" to batchChatPipelineVersion))
      return BatchRecordSegment(submittedAudio, fallbackAudio, segmentStartedAt, endedAt, submittedManually, speechDetected = softSpeechStarted || speechStarted, peak = metrics.peak, rms = metrics.rms)
    }
    logVoice("batch.record.empty", "capture ended without enough submit-ready audio", mapOf("manual" to submittedManually, "fallbackBytes" to fallbackAudio.size, "strictBytes" to strictAudio.size, "speechStarted" to speechStarted, "softSpeechStarted" to softSpeechStarted, "activityStarted" to activityStarted, "candidateStarted" to candidateStarted))
    return null
  }

  private fun hasBatchAutoArmStartSpeechEnergy(level: AudioLevel, noiseRms: Double, playbackGuard: Boolean): Boolean {
    if (playbackGuard) return false
    // v13：能量只能打开“候选窗口”。上一版在 rms≈670/peak≈1750 的房间噪声上也会累计为开口；
    // 这里把自动开口能量底线抬高一点，但保留“近距离低 RMS / 高峰值”的真实说话入口。
    val rmsThreshold = maxOf(760.0, noiseRms * 12.0).toInt()
    val peakThreshold = maxOf(2200, (noiseRms * 45.0).toInt())
    val strongPeak = maxOf(3600, (noiseRms * 82.0).toInt())
    val companionRms = maxOf(620.0, noiseRms * 9.0).toInt()
    return (level.rms >= rmsThreshold && level.peak >= peakThreshold) ||
      (level.peak >= strongPeak && level.rms >= companionRms)
  }

  private fun hasBatchAutoArmWarmVoiceEnergy(level: AudioLevel, noiseRms: Double, playbackGuard: Boolean): Boolean {
    if (playbackGuard) return false
    // v15：上一版只保留了强开口入口，较轻/离麦稍远的真人说话会一直停在“候选”。
    // 这里补回聊天输入常用的 warm-up path：能量只需明显高于底噪，但必须由
    // isBatchCandidateVoiceLike() 提供人声形态，且后续仍要通过连续窗口/endpoint 检查。
    val rmsThreshold = maxOf(220.0, noiseRms * 2.2).toInt()
    val peakThreshold = maxOf(760, (noiseRms * 5.5).toInt())
    val nearFieldPeak = maxOf(1200, (noiseRms * 9.0).toInt())
    return (level.rms >= rmsThreshold && level.peak >= peakThreshold) ||
      (level.peak >= nearFieldPeak && level.rms >= maxOf(180.0, noiseRms * 1.6).toInt())
  }

  private fun hasBatchCandidateVoiceActivity(level: AudioLevel, noiseRms: Double, playbackGuard: Boolean): Boolean {
    if (playbackGuard) return (level.rms >= 220 && level.peak >= 900) || level.peak >= 2600
    // “检测到声音输入”只代表麦克风有明显能量，不等于用户说话。
    // 它只用于页面提示和手动发送按钮，不参与静音自动提交计时。
    val rmsThreshold = maxOf(38.0, noiseRms * 1.55).toInt()
    val peakThreshold = maxOf(180, (noiseRms * 5.5).toInt())
    return level.rms >= rmsThreshold || level.peak >= peakThreshold
  }

  private fun isBatchCandidateVoiceLike(shape: AudioVoiceShape, level: AudioLevel, noiseRms: Double, playbackGuard: Boolean): Boolean {
    if (playbackGuard) return false
    // ChatGPT/Grok/Claude 类语音输入不会把单帧音量当成 speech_started：
    // 音量只进入候选层，UI 也只有在“候选 + 基本人声形态”同时满足时才显示疑似人声。
    // 这能把截图中 rms≈145、peak≈580、voicedScore=0 的安静房间底噪留在“环境声/底噪”状态。
    val aboveNoise = level.rms >= maxOf(150.0, noiseRms * 1.55).toInt() || level.peak >= maxOf(760, (noiseRms * 6.5).toInt())
    if (!aboveNoise) return false
    val zcrLooksSpeech = shape.zcrPermille in 6..240
    val crestLooksSpeech = shape.crestX100 in 120..2800
    val voicedLooksSpeech = shape.voicedScore >= 10
    val closeMicPeak = level.peak >= maxOf(1800, (noiseRms * 20.0).toInt()) && level.rms >= maxOf(210.0, noiseRms * 2.2).toInt()
    return (crestLooksSpeech && (voicedLooksSpeech || zcrLooksSpeech) && level.rms >= maxOf(170.0, noiseRms * 1.75).toInt()) || closeMicPeak
  }

  private fun hasBatchLikelyVoiceActivity(level: AudioLevel, noiseRms: Double, playbackGuard: Boolean): Boolean {
    if (playbackGuard) return (level.rms >= 360 && level.peak >= 1400) || level.peak >= 3600
    // 可能语音活动：只用于页面提示，不参与“用户说话”确认，也不刷新静音端点。
    val rmsThreshold = maxOf(150.0, noiseRms * 4.2).toInt()
    val peakThreshold = maxOf(850, (noiseRms * 18.0).toInt())
    return level.rms >= rmsThreshold || level.peak >= peakThreshold
  }

  private fun hasBatchSpeechEnergy(level: AudioLevel, noiseRms: Double, playbackGuard: Boolean): Boolean {
    if (playbackGuard) return (level.rms >= 900 && level.peak >= 3200) || (level.peak >= 6500 && level.rms >= 550)
    // 正式“用户说话”门限再次收紧：日志显示 rms≈260/peak≈860 这类房间噪声或尾音仍会被当成 speech，
    // 导致 5 秒静音倒计时反复重置，最后只能靠滚动/最大时长提交。现在要求能量形态更像真人语音：
    // 要么 RMS 和峰值同时明显高于底噪，要么瞬时峰值很强且 RMS 不太低。
    val rmsThreshold = maxOf(420.0, noiseRms * 7.5).toInt()
    val peakCompanion = maxOf(1250, (noiseRms * 18.0).toInt())
    val peakThreshold = maxOf(2600, (noiseRms * 42.0).toInt())
    return (level.rms >= rmsThreshold && level.peak >= peakCompanion) ||
      (level.peak >= peakThreshold && level.rms >= maxOf(150.0, noiseRms * 3.0).toInt())
  }

  private fun hasBatchBargeInSpeech(level: AudioLevel, shape: AudioVoiceShape, noiseRms: Double): Boolean {
    // During our own TTS/alarm playback we still do not save microphone frames to STT.
    // This gate only decides whether to stop playback and begin a clean capture.
    // It follows voice-chat barge-in semantics: stronger-than-normal energy plus
    // basic voice shape, but not the extremely high close-mic threshold that made
    // later user turns disappear while the assistant was speaking.
    val zcrLooksSpeech = shape.zcrPermille in 10..210
    val crestLooksSpeech = shape.crestX100 in 130..2400
    val voicedLooksSpeech = shape.voicedScore >= 55
    val voiceShapeOk = crestLooksSpeech && voicedLooksSpeech && zcrLooksSpeech
    val mediumBargeIn = level.rms >= maxOf(900.0, noiseRms * 7.0).toInt() && level.peak >= maxOf(2600, (noiseRms * 24.0).toInt())
    val sharpBargeIn = level.peak >= maxOf(5200, (noiseRms * 44.0).toInt()) && level.rms >= maxOf(700.0, noiseRms * 5.2).toInt()
    return voiceShapeOk && (mediumBargeIn || sharpBargeIn)
  }

  private fun hasBatchSoftSpeechEnergy(level: AudioLevel, noiseRms: Double, playbackGuard: Boolean): Boolean {
    if (playbackGuard) return (level.rms >= 520 && level.peak >= 1800) || level.peak >= 4200
    // 软语音只代表“声音输入较像人声”，不能确认用户说话，也不能刷新静音端点。
    val rmsThreshold = maxOf(220.0, noiseRms * 5.0).toInt()
    val peakThreshold = maxOf(1200, (noiseRms * 24.0).toInt())
    return level.rms >= rmsThreshold || level.peak >= peakThreshold
  }


  private fun pcmDurationMs(pcm: ByteArray, sampleRate: Int = 16000): Long {
    if (pcm.isEmpty()) return 0L
    return ((pcm.size.toLong() * 1000L) / (sampleRate.toLong() * 2L)).coerceAtLeast(0L)
  }

  private fun chooseBatchSubmittedAudio(
    sourceAudio: ByteArray,
    originalAudio: ByteArray,
    trimmedAudio: ByteArray,
    submittedManually: Boolean,
    sampleRate: Int,
  ): ByteArray {
    // Disabled for chat-app pipeline. Never prefer a locally trimmed segment over the complete utterance.
    val full = if (originalAudio.isNotEmpty()) originalAudio else sourceAudio
    return if (full.isNotEmpty()) full else trimmedAudio
  }

  private fun trimPcmForBatchSubmission(pcm: ByteArray, sampleRate: Int, allowFallbackOriginal: Boolean): ByteArray {
    return compactPcmForStt(pcm, sampleRate, reason = "legacyTrimCompat")
  }

  private fun compactPcmForStt(pcm: ByteArray, sampleRate: Int = 16000, reason: String = "submit"): ByteArray {
    // 聊天 App 的服务端 STT 一般拿到的是“当前语音输入”的有效语音段，而不是等待/播报/长空白。
    // 这里不再做破坏性切句；只删除长静音/空白帧，并在每个有声音片段前后保留 padding，
    // 同时保留短停顿，避免把一句话剪得不自然。
    if (pcm.size < sampleRate * 2 / 2) return pcm
    val bytesPerSample = 2
    val frameMs = 20
    val frameBytesRaw = sampleRate * bytesPerSample * frameMs / 1000
    val frameBytes = (frameBytesRaw / 2 * 2).coerceAtLeast(320)
    if (pcm.size <= frameBytes * 8) return pcm
    data class FrameInfo(val start: Int, val end: Int, val rms: Int, val peak: Int)
    val frames = ArrayList<FrameInfo>()
    var pos = 0
    while (pos < pcm.size) {
      val end = minOf(pcm.size, pos + frameBytes)
      val evenEnd = if (((end - pos) and 1) == 0) end else end - 1
      if (evenEnd <= pos) break
      val level = audioFrameLevel(pcm.copyOfRange(pos, evenEnd), evenEnd - pos)
      frames.add(FrameInfo(pos, evenEnd, level.rms, level.peak))
      pos = evenEnd
    }
    if (frames.isEmpty()) return pcm
    val sortedRms = frames.map { it.rms }.sorted()
    val p20 = sortedRms[(sortedRms.size * 0.20).toInt().coerceIn(0, sortedRms.lastIndex)]
    val p50 = sortedRms[(sortedRms.size * 0.50).toInt().coerceIn(0, sortedRms.lastIndex)]
    val noiseRms = minOf(p20, p50).coerceIn(8, 900)
    val rmsThreshold = maxOf(90, (noiseRms * 2.2).toInt()).coerceAtMost(900)
    val peakThreshold = maxOf(520, noiseRms * 8).coerceAtMost(4200)
    fun isVoiceLike(f: FrameInfo): Boolean {
      // 绝对阈值保护弱语音；动态阈值保护底噪。
      return f.rms >= rmsThreshold || f.peak >= peakThreshold || f.rms >= 260 || f.peak >= 1500
    }
    val voiced = frames.map { isVoiceLike(it) }
    val rawSegments = ArrayList<Pair<Int, Int>>()
    var i = 0
    while (i < frames.size) {
      while (i < frames.size && !voiced[i]) i += 1
      if (i >= frames.size) break
      val start = i
      while (i < frames.size && voiced[i]) i += 1
      val endExclusive = i
      rawSegments.add(start to endExclusive)
    }
    if (rawSegments.isEmpty()) {
      logVoice("batch.voiceCompact.noVoice", "voice compaction found no voiced frames; keep original audio", mapOf("reason" to reason, "bytes" to pcm.size, "seconds" to String.format(Locale.US, "%.2f", pcm.size / (sampleRate * 2.0)), "noiseRms" to noiseRms, "rmsTh" to rmsThreshold, "peakTh" to peakThreshold, "pipeline" to batchChatPipelineVersion))
      return pcm
    }
    val padFrames = (260 / frameMs).coerceAtLeast(3)
    val maxGapFrames = (520 / frameMs).coerceAtLeast(6)
    val minSegmentFrames = (80 / frameMs).coerceAtLeast(2)
    val merged = ArrayList<Pair<Int, Int>>()
    for ((segStart, segEnd) in rawSegments) {
      if (segEnd - segStart < minSegmentFrames) continue
      val paddedStart = (segStart - padFrames).coerceAtLeast(0)
      val paddedEnd = (segEnd + padFrames).coerceAtMost(frames.size)
      if (merged.isEmpty()) {
        merged.add(paddedStart to paddedEnd)
      } else {
        val last = merged.removeAt(merged.lastIndex)
        if (paddedStart - last.second <= maxGapFrames) {
          merged.add(last.first to maxOf(last.second, paddedEnd))
        } else {
          merged.add(last)
          merged.add(paddedStart to paddedEnd)
        }
      }
    }
    if (merged.isEmpty()) return pcm
    val out = ByteArrayOutputStream(pcm.size)
    for ((startFrame, endFrame) in merged) {
      val byteStart = frames[startFrame].start
      val byteEnd = frames[endFrame - 1].end
      if (byteEnd > byteStart) out.write(pcm, byteStart, byteEnd - byteStart)
    }
    val compacted = out.toByteArray()
    val originalMs = pcmDurationMs(pcm, sampleRate)
    val compactMs = pcmDurationMs(compacted, sampleRate)
    if (compacted.size < sampleRate * 2 * 350 / 1000 || compacted.size >= (pcm.size * 0.96).toInt()) {
      logVoice("batch.voiceCompact.keepOriginal", "voice compaction not beneficial; keep original audio", mapOf("reason" to reason, "originalMs" to originalMs, "compactMs" to compactMs, "segments" to merged.size, "noiseRms" to noiseRms, "rmsTh" to rmsThreshold, "peakTh" to peakThreshold, "pipeline" to batchChatPipelineVersion))
      return pcm
    }
    logVoice("batch.voiceCompact.applied", "removed long silent/empty spans before STT upload", mapOf("reason" to reason, "originalMs" to originalMs, "compactMs" to compactMs, "removedMs" to (originalMs - compactMs).coerceAtLeast(0L), "segments" to merged.size, "noiseRms" to noiseRms, "rmsTh" to rmsThreshold, "peakTh" to peakThreshold, "pipeline" to batchChatPipelineVersion))
    return compacted
  }

  private fun sttProviderLabel(provider: String): String = when (provider) {
    "microsoft" -> "微软"
    "iflytek" -> "讯飞"
    "xai" -> "xAI"
    else -> "语音服务商"
  }

  private fun recognizeBatchWithProvider(provider: String, cfg: JSONObject, pcm: ByteArray): String {
    val audioMs = pcmDurationMs(pcm)
    if (provider == "iflytek" && audioMs >= 22_000L) {
      val chunked = recognizeBatchByChunks(provider, cfg, pcm, reason = "iflytek_long_file_${audioMs}ms")
      if (chunked.isNotBlank()) return chunked
      logVoice("batch.chunk.primary.empty", "long iFlytek chunk transcription returned empty; fall back to single upload", mapOf("provider" to provider, "audioMs" to audioMs, "bytes" to pcm.size, "pipeline" to batchChatPipelineVersion))
    }
    fun call(p: String, c: JSONObject): String = when (p) {
      "microsoft" -> recognizeWithMicrosoft(c, pcm)
      "iflytek" -> recognizeWithIflytekPcm(c, pcm)
      "xai" -> recognizeWithXaiRest(c, pcm)
      else -> ""
    }.trim()
    val primary = call(provider, cfg)
    if (primary.isNotBlank()) return primary

    // Some STT services can return HTTP 200 + empty transcript for a real user utterance.
    // In batch/chat-input mode, try other configured providers before declaring failure.
    val alternates = listOf("iflytek", "xai", "microsoft").filter { it != provider }
    for (alternate in alternates) {
      val altCfg = cloudSttConfigForProvider(alternate) ?: continue
      val text = try { call(alternate, altCfg) } catch (t: Throwable) {
        logVoice("batch.stt.fallback.error", t.message ?: t.javaClass.simpleName, mapOf("from" to provider, "to" to alternate, "bytes" to pcm.size, "pipeline" to batchChatPipelineVersion))
        ""
      }
      if (text.isNotBlank()) {
        logVoice("batch.stt.fallback.success", "primary STT returned empty; fallback provider returned text", mapOf("from" to provider, "to" to alternate, "bytes" to pcm.size, "chars" to text.length, "pipeline" to batchChatPipelineVersion))
        return text
      }
    }
    return ""
  }

  private fun recognizeBatchByChunks(provider: String, cfg: JSONObject, pcm: ByteArray, reason: String): String {
    if (pcm.isEmpty()) return ""
    val sampleRate = 16000
    val bytesPerMs = sampleRate * 2 / 1000
    val chunkMs = if (provider == "iflytek") 14_000 else 20_000
    val overlapMs = if (provider == "iflytek") 650 else 450
    val chunkBytes = (chunkMs * bytesPerMs / 2 * 2).coerceAtLeast(sampleRate * 2)
    val overlapBytes = (overlapMs * bytesPerMs / 2 * 2).coerceAtLeast(0)
    if (pcm.size <= chunkBytes) return ""
    val totalMs = pcmDurationMs(pcm, sampleRate)
    logVoice("batch.chunk.start", "transcribe long batch audio by complete-file chunks", mapOf("provider" to provider, "reason" to reason, "bytes" to pcm.size, "audioMs" to totalMs, "chunkMs" to chunkMs, "overlapMs" to overlapMs, "pipeline" to batchChatPipelineVersion))
    fun callChunk(chunk: ByteArray): String = when (provider) {
      "iflytek" -> recognizeWithIflytekPcm(cfg, chunk)
      "microsoft" -> recognizeWithMicrosoft(cfg, chunk)
      "xai" -> recognizeWithXaiRest(cfg, chunk)
      else -> ""
    }.trim()
    val parts = mutableListOf<String>()
    var start = 0
    var index = 0
    while (start < pcm.size && index < 12) {
      val end = minOf(pcm.size, start + chunkBytes)
      val chunk = pcm.copyOfRange(start, end)
      val chunkText = try { callChunk(chunk) } catch (t: Throwable) {
        logVoice("batch.chunk.error", t.message ?: t.javaClass.simpleName, mapOf("provider" to provider, "index" to index, "startMs" to (start / bytesPerMs), "endMs" to (end / bytesPerMs), "bytes" to chunk.size, "pipeline" to batchChatPipelineVersion))
        ""
      }
      logVoice("batch.chunk.part", "chunk STT result", mapOf("provider" to provider, "index" to index, "startMs" to (start / bytesPerMs), "endMs" to (end / bytesPerMs), "chars" to chunkText.length, "text" to logPreview(chunkText), "pipeline" to batchChatPipelineVersion))
      if (chunkText.isNotBlank()) parts.add(chunkText)
      if (end >= pcm.size) break
      val nextStart = (end - overlapBytes).coerceAtLeast(start + sampleRate * 2)
      start = nextStart
      index += 1
    }
    val merged = parts.fold("") { acc, part -> mergeSpeechText(acc, part) }.trim()
    logVoice("batch.chunk.done", "chunked batch transcription completed", mapOf("provider" to provider, "reason" to reason, "chunks" to (index + 1), "parts" to parts.size, "chars" to merged.length, "text" to logPreview(merged), "pipeline" to batchChatPipelineVersion))
    return merged
  }

  private fun isGenericAlarmPromptTranscript(normalized: String): Boolean {
    if (normalized.length < 10) return false
    val promptHints = listOf(
      "早安", "早上好", "新的一天", "已经开始", "慢慢起身", "先喝口水",
      "整理好心情", "昨夜的疲惫", "轻轻放下", "愿你", "步伐从容",
      "平静与期待", "迎接属于自己的每一刻"
    )
    val hits = promptHints.count { normalized.contains(it) }
    return hits >= 3
  }

  private fun sanitizeBatchTranscriptEcho(raw: String): String {
    val normalized = normalizeSpeechText(raw)
    if (normalized.isBlank()) return ""
    if (isGenericAlarmPromptTranscript(normalized)) {
      logVoice("batch.result.genericAlarmPromptIgnored", "ignored built-in alarm prompt transcript", mapOf("raw" to logPreview(raw)))
      return ""
    }
    var cleaned = normalized
    val sources = listOf(
      try { JSONObject(payload).optString("text", "") } catch (_: Throwable) { "" },
      lastAlarmSpokenText,
      lastAssistantSpokenText,
    )
    for (source in sources) {
      val src = normalizeSpeechText(source)
      if (src.length < 4) continue
      val fragments = linkedSetOf<String>()
      fragments.add(src)
      // Remove meaningful source fragments, not single words. This catches
      // “补水整理好心情，听见了吗” by removing the alarm prompt fragment while preserving the user's suffix.
      val window = minOf(10, src.length)
      if (window >= 4) {
        var i = 0
        while (i + window <= src.length) {
          fragments.add(src.substring(i, i + window))
          i += maxOf(2, window / 2)
        }
      }
      // Also add punctuation-separated phrases from the raw source.
      source.split(Regex("[\\s，。！？、；：,.!?;:（）()【】\\[\\]《》]+"))
        .map { normalizeSpeechText(it) }
        .filter { it.length >= 4 }
        .forEach { fragments.add(it) }
      for (fragment in fragments.sortedByDescending { it.length }) {
        if (fragment.length >= 4 && cleaned.contains(fragment)) cleaned = cleaned.replace(fragment, "")
      }
    }
    if (cleaned != normalized) {
      logVoice("batch.result.echoStripped", "removed playback prompt fragments from batch transcript", mapOf("raw" to logPreview(raw), "cleaned" to logPreview(cleaned)))
    }
    return cleaned.trim()
  }

  private fun isLowQualityBatchTranscript(text: String, pcmBytes: Int): Boolean {
    val normalized = text
      .replace(Regex("[\\s\\p{Punct}，。！？、；：‘’“”《》（）【】…]"), "")
      .trim()
    if (normalized.isBlank()) return true
    // Keep real short utterances such as “听见了吗/今天没定吧/不要叫了”.
    // Previous logic rejected many short but valid phrases merely because the
    // audio was long, causing the UI to show “无有效文字” even when STT did return
    // a plausible user sentence. Only pure fillers are considered low quality.
    val filler = setOf("嗯", "啊", "哦", "噢", "呃", "诶", "唉", "嗯嗯", "啊啊", "哦哦", "呃呃", "呃嗯", "嗯啊")
    return normalized in filler
  }

  private fun recordPcmChunk(durationMs: Int): ByteArray {
    val sampleRate = 16000
    val minBuffer = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
    if (minBuffer <= 0) return ByteArray(0)
    val playbackEchoGuard = isStrictPlaybackActiveForCapture()
    val audioRecord = obtainContinuousAudioRecord(playbackEchoGuard) ?: return ByteArray(0)
    val out = ByteArrayOutputStream()
    val buffer = ByteArray(minBuffer)
    try {
      val endpoint = endpointingConfig()
      val deadline = System.currentTimeMillis() + durationMs
      val startDeadline = System.currentTimeMillis() + if (playbackEchoGuard) 1800L else maxOf(4500L, endpoint.minUtteranceMs + 1800L)
      var speechStarted = false
      var lastSpeechAt = 0L
      var speechHitCount = 0
      val preRoll = java.util.ArrayDeque<ByteArray>()
      var preRollBytes = 0
      val preRollLimitBytes = sampleRate * 2 * (if (playbackEchoGuard || isPostPlaybackHandoffActive()) 1200 else 900) / 1000
      while (!destroyed && cloudSttActive && System.currentTimeMillis() < deadline) {
        val read = audioRecord.read(buffer, 0, buffer.size)
        if (read < 0) {
          // The shared recorder entered a bad state (e.g. audio focus loss).
          // Drop it so the next call rebuilds a fresh one instead of looping
          // on a permanently broken instance.
          releaseContinuousAudioRecord()
          break
        }
        if (read > 0) {
          val now = System.currentTimeMillis()
          val dynamicPlaybackGuard = isStrictPlaybackActiveForCapture()
          val energyThreshold = voiceSpeechEnergyThreshold(dynamicPlaybackGuard)
          val silenceMs = if (dynamicPlaybackGuard) minOf(endpoint.completeSilenceMs, 900L) else endpoint.completeSilenceMs
          val speech = containsSpeechEnergy(buffer, read, energyThreshold)
          var justStarted = false
          if (!speechStarted) {
            preRollBytes = pushPreRoll(preRoll, buffer.copyOf(read), preRollBytes, preRollLimitBytes)
            speechHitCount = if (speech) speechHitCount + 1 else 0
          }
          val requiredSpeechHits = if (isPostPlaybackHandoffActive()) 1 else 2
          val confirmedSpeech = speechStarted || (speech && speechHitCount >= requiredSpeechHits)
          if (speech && confirmedSpeech) {
            if (!speechStarted) {
              speechStarted = true
              justStarted = true
              for (frame in preRoll) out.write(frame)
              preRoll.clear()
              preRollBytes = 0
            }
            lastSpeechAt = now
          }
          if (speechStarted && !justStarted) out.write(buffer, 0, read)
          // During the post-playback handoff window, keep the recorder alive even
          // if a chunk started while TTS was still speaking.  Otherwise a soft
          // first word right after playback ends can be discarded by the old high
          // echo threshold/start deadline.
          if (!speechStarted && now >= startDeadline && !isPostPlaybackHandoffActive()) break
          if (speechStarted && now - lastSpeechAt >= silenceMs) break
        }
      }
      val minBytes = ((sampleRate * 2L * 160L) / 1000L).toInt().coerceAtLeast(sampleRate * 2 / 10)
      if (!speechStarted || out.size() < minBytes) return ByteArray(0)
    } catch (t: Throwable) {
      releaseContinuousAudioRecord()
      return ByteArray(0)
    }
    // Intentionally do NOT stop/release the AudioRecord here: it is shared and
    // kept alive across consecutive segments by obtainContinuousAudioRecord().
    // It is torn down centrally in stopCloudStt()/releaseContinuousAudioRecord().
    return out.toByteArray()
  }


  private fun defaultSpeechHotwords(): List<String> = listOf(
    "讯飞", "微信", "DeepSeek", "ChatGPT", "API", "Flutter", "源码", "编译", "报错",
    "模型", "语音识别", "语音播报", "语音转文字", "转文字", "闹钟", "TTS", "AI",
    "动态纠错", "自动提交", "热词", "上下文", "用户体验", "功能", "沟通", "表达"
  )

  private fun voiceSpeechEnergyThreshold(playbackGuard: Boolean): Int {
    return when {
      isPostPlaybackHandoffActive() -> 180
      playbackGuard -> 1500
      else -> 260
    }
  }


  private data class AudioVoiceShape(
    val zcrPermille: Int,
    val voicedScore: Int,
    val crestX100: Int,
  )

  private fun batchAudioVoiceShape(buffer: ByteArray, read: Int): AudioVoiceShape {
    val limit = read - 1
    if (limit <= 4) return AudioVoiceShape(0, 0, 0)
    val samples = ShortArray((limit + 1) / 2)
    var count = 0
    var peak = 0
    var sumSquares = 0.0
    var crossings = 0
    var previousSign = 0
    var i = 0
    while (i < limit) {
      val sample = ((buffer[i].toInt() and 0xff) or (buffer[i + 1].toInt() shl 8)).toShort().toInt()
      samples[count] = sample.toShort()
      val abs = kotlin.math.abs(sample)
      if (abs > peak) peak = abs
      sumSquares += sample.toDouble() * sample.toDouble()
      val sign = when {
        sample > 96 -> 1
        sample < -96 -> -1
        else -> 0
      }
      if (sign != 0) {
        if (previousSign != 0 && sign != previousSign) crossings += 1
        previousSign = sign
      }
      count += 1
      i += 2
    }
    if (count <= 8) return AudioVoiceShape(0, 0, 0)
    val rms = kotlin.math.sqrt(sumSquares / count).coerceAtLeast(1.0)
    val zcrPermille = ((crossings * 1000.0) / count).toInt().coerceIn(0, 1000)
    val crestX100 = ((peak * 100.0) / rms).toInt().coerceIn(0, 5000)
    // A light-weight voiced-speech cue. Human speech often has short-term periodicity
    // in the 80-450Hz range. Pure room noise, taps, fans and many echoes tend not to
    // keep this correlation across consecutive frames. This is not a biometric/user ID;
    // it only helps avoid starting a chat turn from non-speech energy.
    var best = 0.0
    val minLag = 35
    val maxLag = minOf(220, count - 4)
    if (maxLag > minLag && rms >= 180.0) {
      var lag = minLag
      while (lag <= maxLag) {
        var dot = 0.0
        var e1 = 0.0
        var e2 = 0.0
        var j = lag
        while (j < count) {
          val a = samples[j].toDouble()
          val b = samples[j - lag].toDouble()
          dot += a * b
          e1 += a * a
          e2 += b * b
          j += 2
        }
        if (e1 > 1.0 && e2 > 1.0) {
          val corr = kotlin.math.abs(dot) / kotlin.math.sqrt(e1 * e2)
          if (corr > best) best = corr
        }
        lag += 3
      }
    }
    val voicedScore = (best * 100.0).toInt().coerceIn(0, 100)
    return AudioVoiceShape(zcrPermille, voicedScore, crestX100)
  }

  private fun isBatchAutoArmVoiceLike(shape: AudioVoiceShape, level: AudioLevel, noiseRms: Double): Boolean {
    // v13：自动开口确认不能再接受“能量 + 任意一个宽松形态”。
    // 采用类似 WebRTC VAD 的思路：短帧能量只是候选，必须同时具备过零率/周期性/峰均比中的稳定人声线索。
    val zcrLooksSpeech = shape.zcrPermille in 8..210
    val crestLooksSpeech = shape.crestX100 in 145..2100
    val voicedLooksSpeech = shape.voicedScore >= 18
    val mediumEnergy = level.rms >= maxOf(760.0, noiseRms * 12.0).toInt() && level.peak >= maxOf(2200, (noiseRms * 45.0).toInt())
    val clearLowVoice = level.rms >= maxOf(620.0, noiseRms * 9.0).toInt() && level.peak >= maxOf(2600, (noiseRms * 55.0).toInt()) && voicedLooksSpeech && zcrLooksSpeech
    val strongCloseMic = level.rms >= maxOf(1250.0, noiseRms * 18.0).toInt() && level.peak >= maxOf(3600, (noiseRms * 82.0).toInt()) && shape.zcrPermille in 6..260 && shape.crestX100 in 120..2600
    return (mediumEnergy && zcrLooksSpeech && crestLooksSpeech && voicedLooksSpeech) || clearLowVoice || strongCloseMic
  }

  private fun isBatchAutoArmEndpointVoiceLike(shape: AudioVoiceShape, level: AudioLevel, noiseRms: Double, playbackGuard: Boolean): Boolean {
    if (playbackGuard) return false
    val zcrLooksSpeech = shape.zcrPermille in 6..240
    val crestLooksSpeech = shape.crestX100 in 120..2600
    val voicedLooksSpeech = shape.voicedScore >= 12
    val energyOk = (level.rms >= maxOf(520.0, noiseRms * 7.5).toInt() && level.peak >= maxOf(1600, (noiseRms * 30.0).toInt())) ||
      (level.peak >= maxOf(3000, (noiseRms * 65.0).toInt()) && level.rms >= maxOf(420.0, noiseRms * 6.0).toInt())
    return energyOk && crestLooksSpeech && (voicedLooksSpeech || zcrLooksSpeech)
  }

  private fun isBatchEndpointContinuationVoiceLike(shape: AudioVoiceShape, level: AudioLevel, noiseRms: Double, playbackGuard: Boolean): Boolean {
    if (playbackGuard) return false
    // Starting a turn can be warm, but extending the tail should be stricter.
    // Otherwise low-level room noise / keyboard / residual echo keeps refreshing
    // lastSpeechAt and a 10-15s user utterance can grow into a 40s STT upload.
    val zcrLooksSpeech = shape.zcrPermille in 10..200
    val crestLooksSpeech = shape.crestX100 in 130..2200
    val voicedLooksSpeech = shape.voicedScore >= 55
    val strongSyllable = level.rms >= maxOf(900.0, noiseRms * 6.2).toInt() && level.peak >= maxOf(2400, (noiseRms * 16.0).toInt())
    val strongPeak = level.peak >= maxOf(3600, (noiseRms * 26.0).toInt()) && level.rms >= maxOf(650.0, noiseRms * 4.2).toInt()
    return crestLooksSpeech && voicedLooksSpeech && zcrLooksSpeech && (strongSyllable || strongPeak)
  }

  private data class AutoArmSegmentValidation(
    val ok: Boolean,
    val reason: String,
    val frames: Int,
    val voiceFrames: Int,
    val strongFrames: Int,
    val durationMs: Long,
    val bestRms: Int,
    val bestPeak: Int,
  )

  private fun validateBatchAutoArmSpeechSegment(pcm: ByteArray, sampleRate: Int = 16000, noiseRms: Double): AutoArmSegmentValidation {
    if (pcm.size < sampleRate * 2 * 500 / 1000) {
      return AutoArmSegmentValidation(false, "too_short", 0, 0, 0, pcmDurationMs(pcm, sampleRate), 0, 0)
    }
    val frameMs = 30
    val frameBytes = ((sampleRate * 2 * frameMs / 1000) / 2 * 2).coerceAtLeast(320)
    var pos = 0
    var frames = 0
    var voiceFrames = 0
    var strongFrames = 0
    var bestRms = 0
    var bestPeak = 0
    while (pos + 2 <= pcm.size) {
      val end = minOf(pcm.size, pos + frameBytes)
      val evenEnd = if (((end - pos) and 1) == 0) end else end - 1
      if (evenEnd <= pos) break
      val frame = pcm.copyOfRange(pos, evenEnd)
      val level = audioFrameLevel(frame, frame.size)
      val shape = batchAudioVoiceShape(frame, frame.size)
      if (level.rms > bestRms) bestRms = level.rms
      if (level.peak > bestPeak) bestPeak = level.peak
      val voice = isBatchAutoArmEndpointVoiceLike(shape, level, noiseRms, playbackGuard = false)
      val strong = isBatchAutoArmVoiceLike(shape, level, noiseRms)
      if (voice) voiceFrames += 1
      if (strong) strongFrames += 1
      frames += 1
      pos = evenEnd
    }
    val durationMs = pcmDurationMs(pcm, sampleRate)
    val minVoiceFrames = if (durationMs < 1800L) 5 else 8
    val ok = voiceFrames >= minVoiceFrames && (strongFrames >= 3 || voiceFrames * 100 >= frames.coerceAtLeast(1) * 18)
    val reason = when {
      ok -> "ok"
      voiceFrames < minVoiceFrames -> "not_enough_voice_like_frames"
      else -> "weak_voice_shape"
    }
    return AutoArmSegmentValidation(ok, reason, frames, voiceFrames, strongFrames, durationMs, bestRms, bestPeak)
  }

  private data class AudioLevel(val peak: Int, val rms: Int)

  private fun audioFrameLevel(buffer: ByteArray, read: Int): AudioLevel {
    var peak = 0
    var sumSquares = 0.0
    var count = 0
    var i = 0
    val limit = read - 1
    while (i < limit) {
      val sample = (buffer[i].toInt() and 0xff) or (buffer[i + 1].toInt() shl 8)
      val value = kotlin.math.abs(sample.toShort().toInt())
      if (value > peak) peak = value
      sumSquares += value.toDouble() * value.toDouble()
      count += 1
      i += 2
    }
    val rms = if (count > 0) kotlin.math.sqrt(sumSquares / count).toInt() else 0
    return AudioLevel(peak, rms)
  }

  private fun hasSpeechEnergy(level: AudioLevel, threshold: Int = 520): Boolean {
    val rmsThreshold = (threshold / 5).coerceAtLeast(24)
    return level.peak >= threshold || level.rms >= rmsThreshold
  }

  private fun hasSoftSpeechEnergy(level: AudioLevel, playbackGuard: Boolean): Boolean {
    return if (playbackGuard) {
      level.peak >= 900 || level.rms >= 180
    } else {
      level.peak >= 140 || level.rms >= 28
    }
  }

  private fun containsSpeechEnergy(buffer: ByteArray, read: Int, threshold: Int = 520): Boolean {
    return hasSpeechEnergy(audioFrameLevel(buffer, read), threshold)
  }

  private fun pushPreRoll(preRoll: java.util.ArrayDeque<ByteArray>, frame: ByteArray, currentBytes: Int, limitBytes: Int): Int {
    var bytes = currentBytes + frame.size
    preRoll.addLast(frame)
    while (bytes > limitBytes && preRoll.isNotEmpty()) {
      bytes -= preRoll.removeFirst().size
    }
    return bytes.coerceAtLeast(0)
  }

  private data class VoiceAudioEffects(
    val aec: AcousticEchoCanceler?,
    val ns: NoiseSuppressor?,
    val agc: AutomaticGainControl?,
  ) {
    fun release() {
      try { aec?.release() } catch (_: Throwable) {}
      try { ns?.release() } catch (_: Throwable) {}
      try { agc?.release() } catch (_: Throwable) {}
    }
  }

  private fun enableVoiceSeparationEffects(sessionId: Int): VoiceAudioEffects {
    fun <T> create(block: () -> T?): T? = try { block() } catch (_: Throwable) { null }
    val aec = create {
      if (AcousticEchoCanceler.isAvailable()) AcousticEchoCanceler.create(sessionId)?.apply { enabled = true } else null
    }
    val ns = create {
      if (NoiseSuppressor.isAvailable()) NoiseSuppressor.create(sessionId)?.apply { enabled = true } else null
    }
    val agc = create {
      if (AutomaticGainControl.isAvailable()) AutomaticGainControl.create(sessionId)?.apply { enabled = true } else null
    }
    return VoiceAudioEffects(aec, ns, agc)
  }

  private fun recognizeWithMicrosoft(cfg: JSONObject, pcm: ByteArray): String {
    val region = cfg.optString("region", "eastasia").ifBlank { "eastasia" }
    val language = cfg.optString("language", "zh-CN").ifBlank { "zh-CN" }
    val endpoint = microsoftSttEndpoint(region, cfg.optString("endpoint", ""), language)
    val apiKey = cfg.optString("apiKey", "")
    val first = recognizeWithMicrosoftOnce(endpoint, apiKey, language, pcm, attempt = "primary")
    if (first.isNotBlank()) return first
    // Microsoft occasionally returns RecognitionStatus=Success with empty DisplayText/NBest for short
    // conversational recordings.  Retrying with a small leading/trailing silence pad often helps
    // the service endpointing model lock onto the speech rather than treating the whole file as no-match.
    val padded = padPcmSilence(pcm, 16000, leadMs = 500, tailMs = 900)
    if (padded.size != pcm.size) {
      logVoice("stt.microsoft.http.retryPadded", "retry Microsoft STT with padded WAV after empty success", mapOf("originalBytes" to pcm.size, "paddedBytes" to padded.size))
      val second = recognizeWithMicrosoftOnce(endpoint, apiKey, language, padded, attempt = "padded")
      if (second.isNotBlank()) return second
    }
    return ""
  }

  private fun recognizeWithMicrosoftOnce(endpoint: String, apiKey: String, language: String, pcm: ByteArray, attempt: String): String {
    val conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
      requestMethod = "POST"
      connectTimeout = 12000
      readTimeout = 30000
      doOutput = true
      setRequestProperty("Ocp-Apim-Subscription-Key", apiKey)
      setRequestProperty("Content-Type", "audio/wav; codecs=audio/pcm; samplerate=16000")
      setRequestProperty("Accept", "application/json")
    }
    logVoice("stt.microsoft.http.start", "Microsoft batch STT request", mapOf("endpoint" to endpoint.take(160), "language" to language, "bytes" to pcm.size, "attempt" to attempt))
    conn.outputStream.use { it.write(wavFromPcm(pcm, 16000)) }
    val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
    val resp = BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { it.readText() }
    logVoice("stt.microsoft.http.result", "Microsoft batch STT response", mapOf("status" to conn.responseCode, "attempt" to attempt, "resp" to resp.take(260)))
    if (conn.responseCode !in 200..299) throw IllegalStateException("HTTP ${conn.responseCode} ${resp.take(120)}")
    val obj = JSONObject(resp)
    val display = obj.optString("DisplayText", "")
    if (display.isNotBlank()) return display.trim()
    val nBest = obj.optJSONArray("NBest")
    val bestObj = nBest?.optJSONObject(0)
    val best = if (bestObj != null) {
      bestObj.optString("Display", bestObj.optString("Lexical", bestObj.optString("ITN", ""))).trim()
    } else ""
    if (best.isNotBlank()) return best
    val status = obj.optString("RecognitionStatus", obj.optString("status", ""))
    if (status.isNotBlank() && status != "Success") throw IllegalStateException("微软 RecognitionStatus=$status")
    return ""
  }

  private fun padPcmSilence(pcm: ByteArray, sampleRate: Int, leadMs: Int, tailMs: Int): ByteArray {
    if (pcm.isEmpty()) return pcm
    val leadBytes = ((sampleRate * 2L * leadMs) / 1000L).toInt().coerceAtLeast(0)
    val tailBytes = ((sampleRate * 2L * tailMs) / 1000L).toInt().coerceAtLeast(0)
    val out = ByteArrayOutputStream(leadBytes + pcm.size + tailBytes)
    if (leadBytes > 0) out.write(ByteArray(leadBytes))
    out.write(pcm)
    if (tailBytes > 0) out.write(ByteArray(tailBytes))
    return out.toByteArray()
  }

  private fun recognizeWithXaiRest(cfg: JSONObject, pcm: ByteArray): String {
    val endpoint = cfg.optString("endpoint", "https://api.x.ai/v1/stt").ifBlank { "https://api.x.ai/v1/stt" }
    val apiKey = cfg.optString("apiKey", "")
    if (apiKey.isBlank()) throw IllegalStateException("缺少 xAI API Key")
    val boundary = "----QuoteAppVoiceAlarm${System.currentTimeMillis()}"
    val conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
      requestMethod = "POST"
      connectTimeout = 15000
      readTimeout = 60000
      doOutput = true
      setRequestProperty("Authorization", "Bearer $apiKey")
      setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
      setRequestProperty("Accept", "application/json")
    }
    logVoice("stt.xai.rest.start", "xAI REST STT request", mapOf("endpoint" to endpoint.take(160), "bytes" to pcm.size, "language" to cfg.optString("language", "")))
    DataOutputStream(conn.outputStream).use { out ->
      fun field(name: String, value: String) {
        out.writeBytes("--$boundary\r\n")
        out.writeBytes("Content-Disposition: form-data; name=\"$name\"\r\n\r\n")
        out.write(value.toByteArray(Charsets.UTF_8))
        out.writeBytes("\r\n")
      }
      val language = normalizedXaiFormattingLanguage(cfg.optString("language", ""))
      if (language != null) {
        field("language", language)
        field("format", "true")
      }
      if (cfg.optBoolean("fillerWords", false)) field("filler_words", "true")
      for (term in defaultSpeechHotwords().take(20)) field("keyterm", term)
      out.writeBytes("--$boundary\r\n")
      out.writeBytes("Content-Disposition: form-data; name=\"file\"; filename=\"voice_alarm.wav\"\r\n")
      out.writeBytes("Content-Type: audio/wav\r\n\r\n")
      out.write(wavFromPcm(pcm, 16000))
      out.writeBytes("\r\n--$boundary--\r\n")
      out.flush()
    }
    val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
    val resp = BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { it.readText() }
    logVoice("stt.xai.rest.result", "xAI REST STT response", mapOf("status" to conn.responseCode, "resp" to resp.take(260)))
    if (conn.responseCode !in 200..299) throw IllegalStateException("HTTP ${conn.responseCode} ${resp.take(160)}")
    return extractTranscriptText(JSONObject(resp)).trim()
  }

  private fun normalizedXaiFormattingLanguage(language: String): String? {
    val normalized = language.trim().lowercase(Locale.US).substringBefore("-").substringBefore("_")
    val supported = setOf(
      "ar", "cs", "da", "nl", "en", "fil", "fr", "de", "hi", "id", "it", "ja", "ko",
      "mk", "ms", "fa", "pl", "pt", "ro", "ru", "es", "sv", "th", "tr", "vi"
    )
    return normalized.takeIf { it in supported }
  }

  private fun recognizeWithXaiStreaming(cfg: JSONObject, durationMs: Int): String {
    val sampleRate = 16000
    val chunkSize = sampleRate * 2 / 10 // 100ms PCM16 mono
    val playbackEchoGuard = isStrictPlaybackActiveForCapture()
    val audioRecord = obtainContinuousAudioRecord(playbackEchoGuard) ?: return ""
    val ready = CountDownLatch(1)
    val closed = CountDownLatch(1)
    val bestText = StringBuilder()
    var webSocket: WebSocket? = null
    val client = getXaiSttClient()
    val request = Request.Builder()
      .url(xaiStreamingUrl(cfg))
      .addHeader("Authorization", "Bearer ${cfg.optString("apiKey", "")}")
      .build()
    val listener = object : WebSocketListener() {
      override fun onOpen(webSocket: WebSocket, response: Response) {
        // xAI sends transcript.created when the backend is ready. Keep this as a
        // fallback so transient missing created events do not deadlock recording.
        speechHandler.postDelayed({ ready.countDown() }, 1200L)
      }
      override fun onMessage(webSocket: WebSocket, message: String) {
        val obj = try { JSONObject(message) } catch (_: Throwable) { JSONObject() }
        val type = obj.optString("type", obj.optString("event", ""))
        if (type == "transcript.created") ready.countDown()
        val text = extractTranscriptText(obj)
        if (text.isNotBlank()) {
          synchronized(bestText) {
            bestText.setLength(0)
            bestText.append(text)
          }
          runOnUiThread {
            transcriptView?.text = if (isPlaybackActiveForSpeechGate()) {
              "xAI 识别候选：$text\n（播报中，稍后先做回声过滤，再决定是否作为用户语音…）"
            } else {
              "xAI 正在听写：$text\n（实时候选会继续修正；静音与文本稳定后自动发送给 AI）"
            }
          }
        }
        val done = type == "transcript.done" || obj.optBoolean("speech_final", false)
        if (done) closed.countDown()
        if (type == "error") closed.countDown()
      }
      override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) { closed.countDown() }
      override fun onClosed(webSocket: WebSocket, code: Int, reason: String) { closed.countDown() }
    }
    try {
      webSocket = client.newWebSocket(request, listener)
      if (!ready.await(5, TimeUnit.SECONDS)) return ""
      val endpoint = endpointingConfig()
      val deadline = System.currentTimeMillis() + durationMs
      val startDeadline = System.currentTimeMillis() + if (playbackEchoGuard) 1800L else maxOf(4500L, endpoint.minUtteranceMs + 1800L)
      val buffer = ByteArray(chunkSize)
      var speechStarted = false
      var lastSpeechAt = 0L
      var speechHitCount = 0
      val preRoll = java.util.ArrayDeque<ByteArray>()
      var preRollBytes = 0
      val preRollLimitBytes = sampleRate * 2 * (if (playbackEchoGuard || isPostPlaybackHandoffActive()) 1200 else 900) / 1000
      val streamFromOpen = !playbackEchoGuard || isPostPlaybackHandoffActive()
      fun sendFrame(frame: ByteArray) { webSocket?.send(frame.toByteString(0, frame.size)) }
      while (!destroyed && cloudSttActive && System.currentTimeMillis() < deadline) {
        val read = audioRecord.read(buffer, 0, buffer.size)
        if (read < 0) {
          releaseContinuousAudioRecord()
          break
        }
        if (read > 0) {
          val now = System.currentTimeMillis()
          val dynamicPlaybackGuard = isStrictPlaybackActiveForCapture()
          val speech = containsSpeechEnergy(buffer, read, voiceSpeechEnergyThreshold(dynamicPlaybackGuard))
          var justStarted = false
          val frame = buffer.copyOf(read)
          if (!speechStarted) {
            preRollBytes = pushPreRoll(preRoll, frame, preRollBytes, preRollLimitBytes)
            speechHitCount = if (speech) speechHitCount + 1 else 0
          }
          val confirmedSpeech = speechStarted || (speech && speechHitCount >= if (isPostPlaybackHandoffActive()) 1 else 2)
          if (speech && confirmedSpeech) {
            if (!speechStarted) {
              speechStarted = true
              justStarted = true
              if (!streamFromOpen) for (cached in preRoll) sendFrame(cached)
              preRoll.clear()
              preRollBytes = 0
            }
            lastSpeechAt = now
          }
          if (streamFromOpen || (speechStarted && !justStarted)) sendFrame(frame)
          if (!speechStarted && now >= startDeadline && !isPostPlaybackHandoffActive()) break
          val silenceMs = if (dynamicPlaybackGuard) minOf(endpoint.completeSilenceMs, 1000L) else endpoint.completeSilenceMs
          if (speechStarted && now - lastSpeechAt >= silenceMs) break
          Thread.sleep(20)
        }
      }
      try { webSocket?.send(JSONObject().put("type", "audio.done").toString()) } catch (_: Throwable) {}
      closed.await(4, TimeUnit.SECONDS)
    } catch (t: Throwable) {
      releaseContinuousAudioRecord()
    } finally {
      try { webSocket?.close(1000, "done") } catch (_: Throwable) {}
    }
    return synchronized(bestText) { bestText.toString().trim() }
  }

  private fun recognizeWithIflytekPcm(cfg: JSONObject, pcm: ByteArray): String {
    if (pcm.isEmpty()) return ""
    val opened = CountDownLatch(1)
    val closed = CountDownLatch(1)
    val text = StringBuilder()
    val iflytekSegments = sortedMapOf<Int, String>()
    val iflytekAppendOnlySegments = linkedMapOf<Int, String>()
    val iflytekProtectedReplaceRanges = mutableListOf<IntRange>()
    var webSocket: WebSocket? = null
    var errorMessage = ""
    var messageCount = 0
    var nonEmptyPieceCount = 0
    var sentFinalFrameWithAudio = false
    val serverDone = java.util.concurrent.atomic.AtomicBoolean(false)
    val client = getIflytekSttClient()
    fun rebuildIflytekDraftLocked(): String {
      text.setLength(0)
      for (value in iflytekSegments.values) if (value.isNotBlank()) text.append(value)
      return text.toString().trim()
    }
    fun rebuildIflytekAppendOnlyDraftLocked(): String =
      iflytekAppendOnlySegments.toSortedMap().values.joinToString("").trim()

    fun chooseIflytekBatchDraftLocked(): String {
      val structured = rebuildIflytekDraftLocked()
      val appendOnly = rebuildIflytekAppendOnlyDraftLocked()
      if (appendOnly.length > structured.length + 2 && !structured.contains(appendOnly)) return appendOnly
      return if (structured.isNotBlank()) structured else appendOnly
    }

    fun applyIflytekPieceLocked(piece: IflytekRecognitionPiece): String {
      if (piece.text.isBlank()) return text.toString().trim()
      if (piece.isReplacement && piece.replaceStart != null && piece.replaceEnd != null) {
        // iFlytek can send one utterance as several sn packets, and may also
        // send pgs=rpl dynamic-correction packets.  Treat rg as the old sn
        // range to replace, insert the corrected text at the range start, and
        // protect that range from late apd packets.  Without inserting the
        // replacement at a stable key, later packets can make the final draft
        // look like only the last message chunk survived.
        val start = minOf(piece.replaceStart, piece.replaceEnd)
        val end = maxOf(piece.replaceStart, piece.replaceEnd)
        for (sn in start..end) iflytekSegments.remove(sn)
        iflytekSegments[start] = piece.text
        iflytekAppendOnlySegments[start] = piece.text
        iflytekProtectedReplaceRanges.removeAll { it.first <= end && start <= it.last }
        iflytekProtectedReplaceRanges.add(start..end)
        return chooseIflytekBatchDraftLocked()
      }
      if (piece.sn >= 0) {
        val protectedByReplacement = iflytekProtectedReplaceRanges.any { piece.sn in it }
        if (protectedByReplacement && !piece.isReplacement) return chooseIflytekBatchDraftLocked()
        iflytekSegments[piece.sn] = piece.text
        iflytekAppendOnlySegments[piece.sn] = piece.text
        return chooseIflytekBatchDraftLocked()
      }
      val current = text.toString()
      if (!current.endsWith(piece.text)) text.append(piece.text)
      return text.toString().trim()
    }
    val listener = object : WebSocketListener() {
      override fun onOpen(webSocket: WebSocket, response: Response) {
        logVoice("stt.iflytek.batch.open", "iFlytek batch WebSocket opened", mapOf("status" to response.code, "pcmBytes" to pcm.size, "eosMs" to iflytekEosMs(cfg)))
        opened.countDown()
      }
      override fun onMessage(webSocket: WebSocket, message: String) {
        messageCount += 1
        val piece = parseIflytekResult(message)
        val draft = synchronized(text) { applyIflytekPieceLocked(piece) }
        if (piece.text.isNotBlank()) nonEmptyPieceCount += 1
        val obj = try { JSONObject(message) } catch (_: Throwable) { JSONObject() }
        val code = obj.optInt("code", 0)
        if (code != 0) errorMessage = "讯飞 code=$code ${obj.optString("message", obj.optString("desc", ""))}"
        if (code != 0 || piece.isLast) serverDone.set(true)
        if (code != 0 || piece.text.isNotBlank() || piece.isLast) {
          logVoice(
            "stt.iflytek.batch.message",
            "iFlytek batch message",
            mapOf("code" to code, "sn" to piece.sn, "last" to piece.isLast, "piece" to logPreview(piece.text), "draft" to logPreview(draft), "raw" to message.take(320)),
          )
        }
        if (code != 0 || piece.isLast) closed.countDown()
      }
      override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        serverDone.set(true)
        errorMessage = t.message ?: t.javaClass.simpleName
        logVoice("stt.iflytek.batch.failure", errorMessage, mapOf("http" to (response?.code ?: -1)))
        closed.countDown()
      }
      override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
        serverDone.set(true)
        logVoice("stt.iflytek.batch.closed", reason, mapOf("code" to code, "messages" to messageCount, "pieces" to nonEmptyPieceCount))
        closed.countDown()
      }
    }
    webSocket = client.newWebSocket(Request.Builder().url(iflytekSignedUrl(cfg)).build(), listener)
    if (!opened.await(5, TimeUnit.SECONDS)) throw IllegalStateException("讯飞 WebSocket 连接超时")
    val chunkSize = 1280
    var offset = 0
    var frameIndex = 0
    while (offset < pcm.size && !serverDone.get()) {
      val end = minOf(offset + chunkSize, pcm.size)
      // 讯飞 IAT 的最后一帧应该用 status=2 携带最后一段真实音频。
      // 旧逻辑把所有真实音频都按 0/1 发送，最后再发一个空的 status=2，部分账号/机型会出现服务端收尾异常，返回空文本。
      val frameStatus = when {
        frameIndex == 0 -> 0
        end >= pcm.size -> 2
        else -> 1
      }
      if (frameStatus == 2) sentFinalFrameWithAudio = true
      webSocket?.send(iflytekFrame(cfg, frameStatus, pcm.copyOfRange(offset, end)))
      offset = end
      frameIndex += 1
      Thread.sleep(42)
      if (serverDone.get()) break
    }
    if (!sentFinalFrameWithAudio && !serverDone.get()) {
      // 极短音频只有首帧时仍补一个空尾帧，保证协议闭合。正常长录音不会走这里。
      webSocket?.send(iflytekFrame(cfg, 2, ByteArray(0)))
    }
    val waitSeconds = ((pcm.size / (16000.0 * 2.0)) + 8.0).toLong().coerceIn(8L, 90L)
    val completed = closed.await(waitSeconds, TimeUnit.SECONDS)
    try { webSocket?.close(1000, "done") } catch (_: Throwable) {}
    val result = synchronized(text) { chooseIflytekBatchDraftLocked() }
    val appendOnlyResult = synchronized(text) { rebuildIflytekAppendOnlyDraftLocked() }
    logVoice(
      "stt.iflytek.batch.done",
      "iFlytek batch completed",
      mapOf("completed" to completed, "messages" to messageCount, "pieces" to nonEmptyPieceCount, "pcmBytes" to pcm.size, "audioSeconds" to String.format(Locale.US, "%.2f", pcm.size / (16000.0 * 2.0)), "finalWithAudio" to sentFinalFrameWithAudio, "appendChars" to appendOnlyResult.length, "appendResult" to logPreview(appendOnlyResult), "result" to logPreview(result), "error" to errorMessage),
    )
    if (result.isBlank()) {
      if (errorMessage.isNotBlank()) throw IllegalStateException(errorMessage)
      throw IllegalStateException("讯飞未返回文字：messages=$messageCount, pieces=$nonEmptyPieceCount, completed=$completed, finalWithAudio=$sentFinalFrameWithAudio")
    }
    return result
  }

  private fun recognizeWithIflytekStreaming(cfg: JSONObject, durationMs: Int): String {
    val sampleRate = 16000
    val chunkSize = 1280 // 40ms at 16kHz 16-bit mono; matches iFlytek IAT streaming recommendations.
    val playbackEchoGuard = isStrictPlaybackActiveForCapture()
    val audioRecord = obtainContinuousAudioRecord(playbackEchoGuard) ?: return ""
    val opened = CountDownLatch(1)
    val closed = CountDownLatch(1)
    val text = StringBuilder()
    val iflytekSegments = sortedMapOf<Int, String>()
    val iflytekProtectedReplaceRanges = mutableListOf<IntRange>()
    var webSocket: WebSocket? = null
    val client = getIflytekSttClient()

    fun rebuildIflytekDraftLocked(): String {
      text.clear()
      iflytekSegments.values.forEach { text.append(it) }
      return text.toString().trim()
    }

    fun applyIflytekPieceLocked(piece: IflytekRecognitionPiece): String {
      if (piece.text.isBlank()) return text.toString().trim()
      if (piece.isReplacement && piece.replaceStart != null && piece.replaceEnd != null) {
        // iFlytek dynamic correction uses pgs=rpl + rg=[start,end]. Treat rg as
        // the authoritative old-sn range. Remove the old range, place the new
        // text at the start position, and protect that range from late apd
        // packets that may arrive after the correction and would otherwise
        // overwrite the corrected text.
        val start = minOf(piece.replaceStart, piece.replaceEnd)
        val end = maxOf(piece.replaceStart, piece.replaceEnd)
        for (sn in start..end) iflytekSegments.remove(sn)
        iflytekSegments[start] = piece.text
        iflytekProtectedReplaceRanges.removeAll { it.first <= end && start <= it.last }
        iflytekProtectedReplaceRanges.add(start..end)
        return rebuildIflytekDraftLocked()
      }
      if (piece.sn >= 0) {
        val protectedByReplacement = iflytekProtectedReplaceRanges.any { piece.sn in it }
        if (protectedByReplacement && !piece.isReplacement) return rebuildIflytekDraftLocked()
        iflytekSegments[piece.sn] = piece.text
        return rebuildIflytekDraftLocked()
      }
      val current = text.toString()
      if (!current.endsWith(piece.text)) text.append(piece.text)
      return text.toString().trim()
    }

    val listener = object : WebSocketListener() {
      override fun onOpen(webSocket: WebSocket, response: Response) {
        opened.countDown()
      }

      override fun onMessage(webSocket: WebSocket, message: String) {
        val piece = parseIflytekResult(message)
        val draft = synchronized(text) { applyIflytekPieceLocked(piece) }
        if (draft.isNotBlank()) {
          runOnUiThread {
            val correctionLabel = when (piece.pgs) {
              "rpl" -> "讯飞已动态修正"
              "apd" -> "讯飞实时听写"
              else -> "讯飞识别中"
            }
            transcriptView?.text = if (isPlaybackActiveForSpeechGate()) {
              "识别候选：$draft\n（播报中，稍后先做回声过滤，再决定是否作为用户语音…）"
            } else {
              "正在听写：$draft\n（$correctionLabel；静音与文本稳定后自动发送给 AI）"
            }
          }
        }
        val code = try { JSONObject(message).optInt("code", 0) } catch (_: Throwable) { 0 }
        if (code != 0 || piece.isLast) closed.countDown()
      }

      override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        closed.countDown()
      }

      override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
        closed.countDown()
      }
    }

    try {
      webSocket = client.newWebSocket(Request.Builder().url(iflytekSignedUrl(cfg)).build(), listener)
      if (!opened.await(5, TimeUnit.SECONDS)) return ""
      val endpoint = endpointingConfig()
      val deadline = System.currentTimeMillis() + durationMs
      var status = 0
      val buffer = ByteArray(chunkSize)
      val startDeadline = System.currentTimeMillis() + if (playbackEchoGuard) 1800L else maxOf(4500L, endpoint.minUtteranceMs + 1800L)
      var speechStarted = false
      var lastSpeechAt = 0L
      var speechHitCount = 0
      val preRoll = java.util.ArrayDeque<ByteArray>()
      var preRollBytes = 0
      val preRollLimitBytes = sampleRate * 2 * (if (playbackEchoGuard || isPostPlaybackHandoffActive()) 1200 else 900) / 1000
      val streamFromOpen = !playbackEchoGuard || isPostPlaybackHandoffActive()
      fun sendSpeechFrame(frame: ByteArray) {
        webSocket?.send(iflytekFrame(cfg, status, frame))
        status = 1
      }
      while (!destroyed && cloudSttActive && System.currentTimeMillis() < deadline) {
        val read = audioRecord.read(buffer, 0, buffer.size)
        if (read < 0) {
          releaseContinuousAudioRecord()
          break
        }
        if (read > 0) {
          val now = System.currentTimeMillis()
          val dynamicPlaybackGuard = isStrictPlaybackActiveForCapture()
          val frame = buffer.copyOf(read)
          val energyThreshold = voiceSpeechEnergyThreshold(dynamicPlaybackGuard)
          val silenceMs = if (dynamicPlaybackGuard) minOf(endpoint.completeSilenceMs, 1000L) else endpoint.completeSilenceMs
          val speech = containsSpeechEnergy(buffer, read, energyThreshold)
          var justStarted = false
          if (!speechStarted) {
            preRollBytes = pushPreRoll(preRoll, frame, preRollBytes, preRollLimitBytes)
            speechHitCount = if (speech) speechHitCount + 1 else 0
          }
          val requiredSpeechHits = if (isPostPlaybackHandoffActive()) 1 else 2
          val confirmedSpeech = speechStarted || (speech && speechHitCount >= requiredSpeechHits)
          if (speech && confirmedSpeech) {
            if (!speechStarted) {
              speechStarted = true
              justStarted = true
              if (!streamFromOpen) {
                for (cached in preRoll) sendSpeechFrame(cached)
              }
              preRoll.clear()
              preRollBytes = 0
            }
            lastSpeechAt = now
          }
          // Normal iFlytek dictation should be streamed from the moment the
          // socket opens, letting the vendor VAD/language model see the full
          // acoustic context.  Local VAD is still used as a guard and timeout.
          // During our own playback we keep the stricter old gating to reduce
          // speaker echo, then rely on text-level echo filtering afterwards.
          if (streamFromOpen || (speechStarted && !justStarted)) sendSpeechFrame(frame)
          if (!speechStarted && now >= startDeadline && !isPostPlaybackHandoffActive()) break
          if (speechStarted && now - lastSpeechAt >= silenceMs) break
          Thread.sleep(35)
        }
      }
      if (status > 0) {
        webSocket?.send(iflytekFrame(cfg, 2, ByteArray(0)))
        closed.await(4, TimeUnit.SECONDS)
      }
    } catch (t: Throwable) {
      releaseContinuousAudioRecord()
    } finally {
      // The AudioRecord itself is shared/continuous and intentionally left
      // running (torn down centrally in stopCloudStt()); only the per-segment
      // WebSocket is closed here.
      try { webSocket?.close(1000, "done") } catch (_: Throwable) {}
    }
    return synchronized(text) { text.toString().trim() }
  }

  private fun getIflytekSttClient(): OkHttpClient {
    return iflytekSttClient ?: OkHttpClient.Builder()
      .readTimeout(0, TimeUnit.MILLISECONDS)
      .build()
      .also { iflytekSttClient = it }
  }

  private fun iflytekEosMs(cfg: JSONObject): Int {
    val defaultMs = if (selectedSttMode() == "batch") {
      // Local endpointing already decided the user stopped talking.  The remote
      // IAT session should not cut the uploaded file in the middle just because
      // the utterance contains a natural pause.  iFLYTEK documents `eos` as the
      // backend silence duration, in milliseconds.
      maxOf(8000L, batchAutoSubmitSilenceMs() + 2500L).toInt()
    } else {
      endpointingConfig().completeSilenceMs.toInt()
    }
    return cfg.optInt("eos", cfg.optInt("vadEos", cfg.optInt("vad_eos", defaultMs))).coerceIn(700, 60000)
  }

  private fun iflytekFrame(cfg: JSONObject, status: Int, audio: ByteArray): String {
    val data = JSONObject()
      .put("status", status)
      .put("format", "audio/L16;rate=16000")
      .put("encoding", "raw")
      .put("audio", Base64.getEncoder().encodeToString(audio))
    val root = JSONObject()
    if (status == 0) {
      root.put("common", JSONObject().put("app_id", cfg.optString("appId", "")))
      root.put(
        "business",
        JSONObject()
          .put("language", cfg.optString("language", "zh_cn").ifBlank { "zh_cn" })
          .put("domain", "iat")
          .put("accent", cfg.optString("accent", "mandarin").ifBlank { "mandarin" })
          .put("dwa", "wpgs")
          .put("ptt", 1)
          // WebAPI v2 uses `eos` for backend endpointing silence.  The old code
          // sent `vad_eos`, which this API can ignore, leaving the default 2000ms
          // and causing the server to send `ls=true` before the client had sent
          // the tail of a long utterance.  Keep `vad_eos` too as a harmless
          // compatibility alias, but make `eos` authoritative.
          .put("eos", iflytekEosMs(cfg))
          .put("vad_eos", iflytekEosMs(cfg)),
      )
    }
    root.put("data", data)
    return root.toString()
  }

  private data class IflytekRecognitionPiece(
    val sn: Int,
    val text: String,
    val pgs: String,
    val replaceStart: Int?,
    val replaceEnd: Int?,
    val isLast: Boolean,
  ) {
    val isReplacement: Boolean get() = pgs == "rpl"
  }

  private fun parseIflytekRange(result: JSONObject): Pair<Int?, Int?> {
    val raw = result.opt("rg") ?: return null to null
    val nums = when (raw) {
      is JSONArray -> (0 until raw.length()).map { raw.optInt(it) }
      is String -> Regex("""-?\d+""").findAll(raw).map { it.value.toIntOrNull() ?: 0 }.toList()
      else -> emptyList()
    }
    if (nums.size < 2) return null to null
    return minOf(nums[0], nums[1]) to maxOf(nums[0], nums[1])
  }

  private fun parseIflytekResult(message: String): IflytekRecognitionPiece {
    fun emptyPiece(isLast: Boolean = false) = IflytekRecognitionPiece(-1, "", "", null, null, isLast)
    val result = try { JSONObject(message).optJSONObject("data")?.optJSONObject("result") } catch (_: Throwable) { null }
      ?: return emptyPiece()
    val sn = result.optInt("sn", -1)
    val pgs = result.optString("pgs", "")
    val isLast = result.optBoolean("ls", false)
    val words = result.optJSONArray("ws") ?: return IflytekRecognitionPiece(sn, "", pgs, null, null, isLast)
    val out = StringBuilder()
    for (i in 0 until words.length()) {
      val candidates = words.optJSONObject(i)?.optJSONArray("cw") ?: continue
      // For IAT, cw is a candidate list for the same token.  Taking every
      // candidate makes the transcript look duplicated and prevents visible
      // correction.  Use the best candidate only, as input methods do.
      val word = candidates.optJSONObject(0)?.optString("w", "") ?: ""
      if (word.isNotBlank()) out.append(word)
    }
    val (replaceStart, replaceEnd) = if (pgs == "rpl") parseIflytekRange(result) else null to null
    return IflytekRecognitionPiece(sn, out.toString(), pgs, replaceStart, replaceEnd, isLast)
  }

  private fun iflytekSignedUrl(cfg: JSONObject): String {
    val rawEndpoint = cfg.optString("endpoint", "wss://iat-api.xfyun.cn/v2/iat").ifBlank { "wss://iat-api.xfyun.cn/v2/iat" }
    val endpoint = rawEndpoint.replace("https://", "wss://").replace("http://", "ws://")
    val url = URL(endpoint.replace("wss://", "https://").replace("ws://", "http://"))
    val host = url.host
    val path = if (url.query.isNullOrBlank()) url.path else "${url.path}?${url.query}"
    val dateFormat = SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss z", Locale.US).apply { timeZone = TimeZone.getTimeZone("GMT") }
    val date = dateFormat.format(Date())
    val signatureOrigin = "host: $host\ndate: $date\nGET $path HTTP/1.1"
    val mac = Mac.getInstance("HmacSHA256").apply {
      init(SecretKeySpec(cfg.optString("apiSecret", "").toByteArray(Charsets.UTF_8), "HmacSHA256"))
    }
    val signature = Base64.getEncoder().encodeToString(mac.doFinal(signatureOrigin.toByteArray(Charsets.UTF_8)))
    val authorizationOrigin = "api_key=\"${cfg.optString("apiKey", "")}\", algorithm=\"hmac-sha256\", headers=\"host date request-line\", signature=\"$signature\""
    val authorization = Base64.getEncoder().encodeToString(authorizationOrigin.toByteArray(Charsets.UTF_8))
    val separator = if (endpoint.contains("?")) "&" else "?"
    return "$endpoint$separator" +
      "authorization=${URLEncoder.encode(authorization, "UTF-8")}" +
      "&date=${URLEncoder.encode(date, "UTF-8")}" +
      "&host=${URLEncoder.encode(host, "UTF-8")}"
  }


  private fun getXaiSttClient(): OkHttpClient {
    return xaiSttClient ?: OkHttpClient.Builder()
      .readTimeout(0, TimeUnit.MILLISECONDS)
      .build()
      .also { xaiSttClient = it }
  }

  private fun xaiStreamingUrl(cfg: JSONObject): String {
    val base = cfg.optString("streamingEndpoint", "wss://api.x.ai/v1/stt").ifBlank { "wss://api.x.ai/v1/stt" }
    val endpoint = endpointingConfig()
    val params = mutableListOf(
      "sample_rate=16000",
      "encoding=pcm",
      "interim_results=true",
      "endpointing=${endpoint.completeSilenceMs.coerceIn(0L, 5000L)}",
      "smart_turn=0.7",
      "smart_turn_timeout=${endpoint.completeSilenceMs.coerceIn(1L, 5000L)}",
    )
    val language = normalizedXaiFormattingLanguage(cfg.optString("language", ""))
    if (language != null) params.add("language=${URLEncoder.encode(language, "UTF-8")}")
    for (term in defaultSpeechHotwords().take(20)) params.add("keyterm=${URLEncoder.encode(term, "UTF-8")}")
    val separator = if (base.contains("?")) "&" else "?"
    return base + separator + params.joinToString("&")
  }

  private fun extractTranscriptText(obj: JSONObject): String {
    val directKeys = arrayOf("text", "transcript", "display_text", "DisplayText", "Display")
    for (key in directKeys) {
      val value = obj.optString(key, "")
      if (value.isNotBlank()) return value.trim()
    }
    val best = obj.optJSONArray("NBest")?.optJSONObject(0)?.optString("Display", "") ?: ""
    if (best.isNotBlank()) return best.trim()
    val alternatives = obj.optJSONArray("alternatives")
    if (alternatives != null && alternatives.length() > 0) {
      val alt = alternatives.optJSONObject(0)
      val text = alt?.let { it.optString("transcript", it.optString("text", "")) } ?: ""
      if (text.isNotBlank()) return text.trim()
    }
    val channel = obj.optJSONArray("channels")?.optJSONObject(0)
    if (channel != null) {
      val text = extractTranscriptText(channel)
      if (text.isNotBlank()) return text
    }
    val result = obj.optJSONObject("result")
    if (result != null) {
      val text = extractTranscriptText(result)
      if (text.isNotBlank()) return text
    }
    return ""
  }

  private fun maybeAutoCorrectBatchTranscript(rawText: String): String {
    val text = rawText.trim()
    if (!batchAutoCorrectEnabled() || text.length < 2 || isStopCommand(text) || isSnoozeCommand(text)) return text
    val cfg = try { JSONObject(payload).optJSONObject("aiConfig") } catch (_: Throwable) { null } ?: return text
    if (!cfg.optBoolean("available", false)) return text
    val endpoint = cfg.optString("endpoint", "")
    val apiKey = cfg.optString("apiKey", "")
    val model = cfg.optString("model", "")
    val provider = cfg.optString("provider", "")
    if (endpoint.isBlank() || apiKey.isBlank() || model.isBlank()) return text
    val correctionTokenBudget = (text.length * 2 + 120).coerceIn(220, 1800)
    val messages = JSONArray().apply {
      put(JSONObject().put("role", "system").put("content", "你是语音识别转文字纠错器。只根据输入文本纠正明显的错别字、同音字、断句和标点；不要改写含义，不要添加信息，不要解释。必须保留原文全部信息，长文本也完整输出，不能摘要、不能截断、不能只输出前半段。只输出纠正后的完整文本。"))
      put(JSONObject().put("role", "user").put("content", text))
    }
    val body = if (provider == "openai" && endpoint.contains("/responses")) {
      JSONObject().put("model", model).put("input", messages).put("max_output_tokens", correctionTokenBudget).put("temperature", 0.0)
    } else {
      JSONObject().put("model", model).put("messages", messages).put("max_tokens", correctionTokenBudget).put("temperature", 0.0).put("stream", false)
    }
    val conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
      requestMethod = "POST"
      connectTimeout = 10000
      readTimeout = 30000
      doOutput = true
      setRequestProperty("Content-Type", "application/json")
      setRequestProperty("Authorization", "Bearer $apiKey")
      if (provider == "openrouter") setRequestProperty("X-OpenRouter-Title", "Quote App Voice Alarm STT Correction")
      if (provider == "edenai") setRequestProperty("Accept", "application/json")
    }
    logVoice("batch.correct.http.start", "calling AI endpoint for STT correction", mapOf("provider" to provider, "model" to model, "endpoint" to endpoint.take(120), "bodyChars" to body.toString().length))
    OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body.toString()) }
    val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
    val resp = BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { it.readText() }
    if (conn.responseCode !in 200..299) return text
    val corrected = extractAiText(JSONObject(resp)).trim()
    if (corrected.isBlank()) return text
    if (corrected.length > text.length * 3 + 20) return text
    val originalCompact = normalizeSpeechText(text)
    val correctedCompact = normalizeSpeechText(corrected)
    // 语音纠错只能“修错字/标点”，绝不能摘要或只返回前半段。
    // 之前 DeepSeek 纠错把讯飞已经返回的完整长句截成前 20 个字，导致用户看到“只转出一部分”。
    // 现在只要纠错结果明显短于原始转写，就丢弃纠错结果，保留 STT 原文。
    if (originalCompact.length >= 12 && correctedCompact.length + 4 < originalCompact.length) {
      logVoice("batch.correct.discardShort", "discarded shortened correction result", mapOf("rawChars" to text.length, "correctedChars" to corrected.length, "raw" to logPreview(text), "corrected" to logPreview(corrected)))
      return text
    }
    if (text.length >= 40 && corrected.length < (text.length * 0.85).toInt()) {
      logVoice("batch.correct.discardShort", "discarded likely truncated long correction", mapOf("rawChars" to text.length, "correctedChars" to corrected.length))
      return text
    }
    val correctionSimilarity = textSimilarity(originalCompact, correctedCompact)
    if (originalCompact.length >= 8 && correctionSimilarity < 0.88) {
      logVoice("batch.correct.discardRewrite", "discarded correction that changed too much content", mapOf("similarity" to String.format(Locale.US, "%.2f", correctionSimilarity), "raw" to logPreview(text), "corrected" to logPreview(corrected)))
      return text
    }
    return corrected
  }

  private fun microsoftSttEndpoint(region: String, customEndpoint: String, language: String): String {
    val base = customEndpoint.trim().ifBlank {
      "https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1"
    }
    val separator = if (base.contains("?")) "&" else "?"
    return "$base${separator}language=$language&format=detailed"
  }

  private fun wavFromPcm(pcm: ByteArray, sampleRate: Int): ByteArray {
    val out = ByteArrayOutputStream()
    val byteRate = sampleRate * 2
    fun writeInt(value: Int) {
      out.write(value and 0xff)
      out.write((value shr 8) and 0xff)
      out.write((value shr 16) and 0xff)
      out.write((value shr 24) and 0xff)
    }
    fun writeShort(value: Int) {
      out.write(value and 0xff)
      out.write((value shr 8) and 0xff)
    }
    out.write("RIFF".toByteArray())
    writeInt(36 + pcm.size)
    out.write("WAVEfmt ".toByteArray())
    writeInt(16)
    writeShort(1)
    writeShort(1)
    writeInt(sampleRate)
    writeInt(byteRate)
    writeShort(2)
    writeShort(16)
    out.write("data".toByteArray())
    writeInt(pcm.size)
    out.write(pcm)
    return out.toByteArray()
  }

  private fun saveBatchDebugWav(name: String, pcm: ByteArray): String {
    if (pcm.isEmpty()) return ""
    return try {
      val dir = (getExternalFilesDir("voice_alarm_audio_debug") ?: File(filesDir, "voice_alarm_audio_debug")).apply { mkdirs() }
      val safeName = name.replace(Regex("[^A-Za-z0-9_.-]"), "_")
      val file = File(dir, safeName)
      file.writeBytes(wavFromPcm(pcm, 16000))
      file.absolutePath
    } catch (t: Throwable) {
      logVoice("batch.audio.save.error", t.message ?: t.javaClass.simpleName)
      ""
    }
  }


  private fun updateListeningStatus() {
    val current = transcriptView?.text?.toString().orEmpty()
    val base = current.lineSequence().filter { it.isNotBlank() && !it.contains("正在聆听") }.take(8).joinToString("\n")
    transcriptView?.text = if (base.isBlank()) "正在聆听…" else "$base\n正在聆听…"
  }

  private fun listenAgain(delayMs: Long = 0L) {
    recoverStuckPlaybackStateIfNeeded()
    if (destroyed || speaking || listening) return
    // Cloud STT is driven by its own continuous recorder thread.  Do not mark
    // listening=true when no native SpeechRecognizer exists; that fake state was
    // able to block all future recovery after TTS/barge-in handoff.
    if (recognizer == null) {
      val cloudCfg = cloudSttConfigForSelected()
      if (cloudCfg != null) {
        if (!cloudSttActive || !isCloudSttHealthy()) startVoiceAssistant()
        return
      }
      startVoiceAssistant()
      if (recognizer == null) return
    }
    if (alarmVoicePlaying) {
      scheduleListeningAfterSuppression(500L)
      return
    }
    if (isAlarmPlaybackSuppressed() && !isPostPlaybackHandoffActive()) {
      scheduleListeningAfterSuppression()
      return
    }
    transcriptView?.postDelayed({
      recoverStuckPlaybackStateIfNeeded()
      if (destroyed || speaking || listening) return@postDelayed
      if (recognizer == null) {
        val cloudCfg = cloudSttConfigForSelected()
        if (cloudCfg != null) {
          if (!cloudSttActive || !isCloudSttHealthy()) startVoiceAssistant()
          return@postDelayed
        }
        startVoiceAssistant()
        if (recognizer == null) return@postDelayed
      }
      if (alarmVoicePlaying) {
        scheduleListeningAfterSuppression(500L)
        return@postDelayed
      }
      if (isAlarmPlaybackSuppressed() && !isPostPlaybackHandoffActive()) {
        scheduleListeningAfterSuppression()
        return@postDelayed
      }
      val endpoint = endpointingConfig()
      val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, endpoint.completeSilenceMs)
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, endpoint.possiblyCompleteSilenceMs)
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, endpoint.minUtteranceMs)
        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
        putStringArrayListExtra("android.speech.extra.BIASING_STRINGS", ArrayList(defaultSpeechHotwords()))
      }
      try {
        val r = recognizer ?: return@postDelayed
        r.cancel()
        r.startListening(i)
        listening = true
        listeningStartedAt = System.currentTimeMillis()
      } catch (_: Throwable) {
        listening = false
        listeningStartedAt = 0L
      }
    }, delayMs)
  }

  private fun scheduleListeningAfterSuppression(extraDelayMs: Long = 180L) {
    recoverStuckPlaybackStateIfNeeded()
    if (destroyed || speaking || listening) return
    resumeListeningRunnable?.let { speechHandler.removeCallbacks(it) }
    val delayMs = if (isPostPlaybackHandoffActive()) {
      minOf(extraDelayMs, 80L)
    } else if (alarmVoicePlaying) {
      500L.coerceAtLeast(extraDelayMs)
    } else {
      (suppressRecognitionUntil - System.currentTimeMillis() + extraDelayMs).coerceAtLeast(extraDelayMs)
    }
    resumeListeningRunnable = Runnable {
      resumeListeningRunnable = null
      listenAgain(0)
    }
    speechHandler.postDelayed(resumeListeningRunnable!!, delayMs)
  }

  private fun primeBatchBlockForInitialAlarmPlayback(alarmPayload: String) {
    if (selectedSttMode() != "batch") return
    val data = try { JSONObject(alarmPayload) } catch (_: Throwable) { JSONObject() }
    val voicePath = data.optString("voicePath", "")
    val hasVoicePrompt = data.optString("text", "").isNotBlank() || (voicePath.isNotBlank() && File(voicePath).isFile)
    if (!hasVoicePrompt) return
    val textLen = data.optString("text", "").length
    val now = System.currentTimeMillis()
    // This is only a very short fail-safe window before the service emits the
    // real playback-start broadcast.  The previous implementation guessed the
    // whole prompt duration here (up to 45s) and set alarmVoicePlaying=true;
    // if the playback-end broadcast was missed, batch STT stayed blocked and
    // the user's first sentence was never recorded.  Registering the receiver
    // before starting the service plus this short pre-start guard prevents
    // speaker leakage without hiding the microphone for tens of seconds.
    val guardMs = 1600L
    batchSpeakerPlaybackBlockUntil = maxOf(batchSpeakerPlaybackBlockUntil, now + guardMs)
    suppressRecognitionUntil = maxOf(suppressRecognitionUntil, now + guardMs)
    strongPlaybackGateUntil = maxOf(strongPlaybackGateUntil, now + guardMs)
    releaseContinuousAudioRecord()
    logVoice("batch.initialPlaybackGate", "short pre-start guard opened; waiting for real playback broadcasts", mapOf("guardMs" to guardMs, "textLen" to textLen, "hasVoicePath" to voicePath.isNotBlank(), "receiverRegistered" to alarmPlaybackReceiverRegistered))
    setBatchStatus("正在启动闹钟语音播报：严格单轮模式会暂停录音，避免播报声进入 STT。")
    alarmPlaybackWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    alarmPlaybackWatchdogRunnable = Runnable {
      alarmPlaybackWatchdogRunnable = null
      if (!alarmVoicePlaying) {
        markPostPlaybackHandoff(durationMs = 500L)
        batchSpeakerPlaybackBlockUntil = minOf(batchSpeakerPlaybackBlockUntil, System.currentTimeMillis() + 80L)
        logVoice("batch.initialPlaybackGate.failOpen", "no playback start broadcast during short guard; microphone reopened")
        setBatchStatus("闹钟播报启动保护已结束：现在可以说话；若听到播报仍在继续，请等播报结束再说。")
      }
    }
    speechHandler.postDelayed(alarmPlaybackWatchdogRunnable!!, guardMs)
  }

  private fun registerAlarmPlaybackReceiver() {
    if (alarmPlaybackReceiverRegistered) return
    val filter = IntentFilter().apply {
      addAction(VoiceAlarmRingingService.ACTION_VOICE_PLAYBACK_START)
      addAction(VoiceAlarmRingingService.ACTION_VOICE_PLAYBACK_END)
    }
    try {
      if (Build.VERSION.SDK_INT >= 33) registerReceiver(alarmPlaybackReceiver, filter, RECEIVER_NOT_EXPORTED) else registerReceiver(alarmPlaybackReceiver, filter)
      alarmPlaybackReceiverRegistered = true
      logVoice("alarm.playback.receiver.registered", "registered before starting ringing service")
    } catch (t: Throwable) {
      logVoice("alarm.playback.receiver.register.error", t.message ?: t.javaClass.simpleName)
    }
  }

  private fun syncExistingAlarmPlaybackState() {
    if (selectedSttMode() != "batch") return
    val (active, playbackText) = VoiceAlarmRingingService.currentVoicePlaybackState(this)
    if (!active) return
    alarmVoicePlaying = true
    if (playbackText.isNotBlank()) lastAlarmSpokenText = playbackText
    markExternalPlaybackStart()
    resetBatchCurrentCaptureForSpeakerPlayback("检测到闹钟语音已在播放：非实时模式先暂停录音，避免刚进页面把播报声当成用户说话。", cooldownMs = 1800L)
    alarmPlaybackWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    alarmPlaybackWatchdogRunnable = Runnable {
      alarmPlaybackWatchdogRunnable = null
      alarmVoicePlaying = false
      markPostPlaybackHandoff(700L)
      resetBatchCurrentCaptureForSpeakerPlayback("闹钟播报同步保护超时结束：非实时录音已保持就绪，短暂冷却后恢复。", cooldownMs = 80L, preserveOpenRecorder = true)
      listenAgain(0L)
    }
    speechHandler.postDelayed(alarmPlaybackWatchdogRunnable!!, estimatedAlarmVoiceWatchdogMs())
    logVoice("alarm.playback.stateSync", "synced already-active alarm voice playback from service state", mapOf("text" to logPreview(playbackText), "pipeline" to batchChatPipelineVersion))
  }

  private fun shouldDeferAlarmPlaybackForBatchVoiceInput(): Boolean {
    if (selectedSttMode() != "batch") return false
    val activeCapture = batchCurrentConfirmedSpeech || (batchHasSpeech && batchCurrentCachedSeconds >= 0.8)
    val activeSubmit = batchSubmitInProgress || batchRecognitionInFlight || batchPcmQueue.isNotEmpty() || batchAwaitingAiCommit || speechBuffer.toString().trim().isNotBlank() || aiBusy
    // When the microphone has the floor, the app must not start its own speaker. This mirrors chat apps:
    // record user audio first, submit it, then play/answer after the transcript is committed.
    return activeCapture || activeSubmit
  }

  private fun handleAlarmVoicePlaybackStart(playbackText: String = "") {
    if (playbackText.isNotBlank()) lastAlarmSpokenText = playbackText
    logVoice("alarm.playback.start", "alarm voice playback start broadcast received", mapOf("text" to logPreview(playbackText), "pipeline" to batchChatPipelineVersion))
    if (shouldDeferAlarmPlaybackForBatchVoiceInput()) {
      logVoice("batch.playback.deferredForVoiceInput", "alarm playback started while user voice input/STT was active; postpone speaker to protect complete utterance", mapOf("pipeline" to batchChatPipelineVersion, "confirmedSpeech" to batchCurrentConfirmedSpeech, "submit" to batchSubmitInProgress, "inFlight" to batchRecognitionInFlight, "queue" to batchPcmQueue.size, "cachedSeconds" to String.format(Locale.US, "%.1f", batchCurrentCachedSeconds)))
      VoiceAlarmRingingService.postponeVoiceReplay(this, 30_000L)
      alarmVoicePlaying = false
      markPostPlaybackHandoff(120L)
      setBatchStatus("正在处理你的完整语音：已延后闹钟播报，避免把播报声写入 STT 音频。")
      return
    }
    // Do not call postponeAlarmVoiceReplay() here. This callback is emitted by
    // the alarm voice itself when playback starts; postponing here immediately
    // stops the current MediaPlayer/TTS and caused the opening reminder to be
    // cut off. Keep native recognition paused until playback-end arrives; cloud
    // STT may still collect text and will pass through echo filtering first.
    alarmVoicePlaying = true
    markExternalPlaybackStart()
    resetBatchCurrentCaptureForSpeakerPlayback("闹钟语音播报中：非实时模式暂停录音，避免把播报声识别成用户文字。", cooldownMs = 1200L)
    alarmPlaybackWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    alarmPlaybackWatchdogRunnable = Runnable {
      alarmVoicePlaying = false
      alarmPlaybackWatchdogRunnable = null
      markPostPlaybackHandoff(700L)
      resetBatchCurrentCaptureForSpeakerPlayback("闹钟播报状态超时结束：非实时录音已保持就绪，立即恢复。", cooldownMs = 80L, preserveOpenRecorder = true)
      listenAgain(0L)
    }
    speechHandler.postDelayed(alarmPlaybackWatchdogRunnable!!, estimatedAlarmVoiceWatchdogMs())
    suppressForAlarmPlayback(2500L)
  }

  private fun estimatedAlarmVoiceWatchdogMs(): Long {
    val textLen = try { JSONObject(payload).optString("text", "").length } catch (_: Throwable) { 0 }
    // Chinese TTS / custom voice prompts can be long.  The watchdog is only a
    // safety net for missing playback-end broadcasts, so prefer a generous bound
    // to avoid re-enabling recognition in the middle of a legitimate long prompt.
    return (10_000L + textLen * 260L).coerceIn(10_000L, 60_000L)
  }

  private fun suppressForAlarmPlayback(durationMs: Long) {
    suppressRecognitionUntil = maxOf(suppressRecognitionUntil, System.currentTimeMillis() + durationMs)
    try { recognizer?.cancel() } catch (_: Throwable) {}
    listening = false
    listeningStartedAt = 0L
    processSpeechRunnable?.let { speechHandler.removeCallbacks(it) }
    if (speechBuffer.isBlank()) {
      transcriptView?.text = "闹钟语音播报中：只屏蔽播报音频；若已有用户转文字，会继续发送给 AI。"
    } else {
      transcriptView?.text = "闹钟语音播报中，已保留用户已说内容并继续准备发送给 AI…\n你：$speechBuffer"
      scheduleBufferedSpeechProcessing(350L)
    }
    scheduleListeningAfterSuppression()
  }

  private fun isAlarmPlaybackSuppressed(): Boolean = System.currentTimeMillis() < suppressRecognitionUntil

  private fun isPostPlaybackHandoffActive(): Boolean = System.currentTimeMillis() < postPlaybackHandoffUntil

  private fun markPostPlaybackHandoff(durationMs: Long = 900L) {
    val now = System.currentTimeMillis()
    postPlaybackHandoffUntil = maxOf(postPlaybackHandoffUntil, now + durationMs)
    // Playback has already ended, so keep only a very short echo gate.  Longer
    // handoff windows forced the stricter post-playback VAD for several seconds
    // and caused the first words after播报 to be missed.
    strongPlaybackGateUntil = now + 80L
    suppressRecognitionUntil = minOf(maxOf(suppressRecognitionUntil, now + 40L), now + 90L)
  }

  private fun batchPlaybackBargeInEnabled(): Boolean = true

  private fun isBatchPlaybackEchoGuardActive(): Boolean {
    val now = System.currentTimeMillis()
    return batchPlaybackBargeInEnabled() &&
      (speaking || alarmVoicePlaying || now < batchPlaybackEchoGuardUntil || now < suppressRecognitionUntil || now < strongPlaybackGateUntil)
  }

  private fun isBatchSpeakerPlaybackBlocked(): Boolean {
    val now = System.currentTimeMillis()
    if (batchPlaybackBargeInEnabled()) return false
    return speaking || alarmVoicePlaying || now < batchSpeakerPlaybackBlockUntil || now < suppressRecognitionUntil || now < strongPlaybackGateUntil
  }

  private fun resetBatchCurrentCaptureForSpeakerPlayback(message: String? = null, cooldownMs: Long = 220L, preserveOpenRecorder: Boolean = false) {
    val now = System.currentTimeMillis()
    if (!preserveOpenRecorder) batchSpeakerPlaybackEpoch += 1L
    if (batchPlaybackBargeInEnabled()) {
      // 播报正在进行时需要较长的 speaker-mask 窗口；播报已经结束时只保留很短冷却，
      // 避免用户刚开口被 1.8s 固定窗口吃掉。无论哪种窗口，音频帧只用于打断检测，不写入 STT 文件。
      val guardMs = if (speaking || alarmVoicePlaying) maxOf(cooldownMs, 1800L) else cooldownMs.coerceAtMost(260L)
      batchPlaybackEchoGuardUntil = maxOf(batchPlaybackEchoGuardUntil, now + guardMs)
      logVoice("batch.playbackEchoGuard", message ?: "batch playback echo guard active; speaker frames will be masked", mapOf("guardMs" to guardMs, "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "preserveOpenRecorder" to preserveOpenRecorder, "pipeline" to batchChatPipelineVersion))
      if (selectedSttMode() == "batch") {
        runOnUiThread {
          if (!message.isNullOrBlank()) setBatchStatus((message ?: "") + " 播报帧不会写入转文字音频；检测到真人插话会先停止播报，再从干净音频重新录入。")
        }
      }
      return
    }
    batchSpeakerPlaybackBlockUntil = maxOf(batchSpeakerPlaybackBlockUntil, now + cooldownMs)
    releaseContinuousAudioRecord()
    logVoice("batch.playbackGate.reset", message ?: "batch capture gate reset for playback", mapOf("cooldownMs" to cooldownMs, "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "epoch" to batchSpeakerPlaybackEpoch))
    batchManualSubmitRequested = false
    batchHasSpeech = false
    batchCurrentBufferedBytes = 0
    batchCurrentCachedSeconds = 0.0
    batchCurrentSpeechDetected = false
    batchLastSpeechAt = 0L
    if (selectedSttMode() == "batch") {
      runOnUiThread {
        updateBatchSubmitButton(false, 0.0)
        if (!message.isNullOrBlank()) setBatchStatus(message)
      }
    }
  }

  private fun isStrictPlaybackActiveForCapture(): Boolean {
    val now = System.currentTimeMillis()
    return speaking || alarmVoicePlaying || (!isPostPlaybackHandoffActive() && (now < suppressRecognitionUntil || now < strongPlaybackGateUntil))
  }

  private fun isPlaybackActiveForSpeechGate(): Boolean {
    val now = System.currentTimeMillis()
    return speaking || alarmVoicePlaying || (!isPostPlaybackHandoffActive() && (now < suppressRecognitionUntil || now < strongPlaybackGateUntil))
  }

  private fun markExternalPlaybackStart() {
    resetBatchCurrentCaptureForSpeakerPlayback(null, cooldownMs = 1200L)
    val now = System.currentTimeMillis()
    appPlaybackStartedAt = now
    strongPlaybackGateUntil = maxOf(strongPlaybackGateUntil, now + 1800L)
    suppressRecognitionUntil = maxOf(suppressRecognitionUntil, now + 1200L)
    try { recognizer?.cancel() } catch (_: Throwable) {}
    listening = false
    listeningStartedAt = 0L
  }

  private fun markAppTtsPlaybackStart() {
    logVoice("ai.tts.playback.start", "AI TTS playback state entered")
    resetBatchCurrentCaptureForSpeakerPlayback("AI 语音播报中：非实时模式暂停录音，避免把 AI 回复当成用户输入。", cooldownMs = 1200L)
    speaking = true
    val now = System.currentTimeMillis()
    appTtsStartedAt = now
    appPlaybackStartedAt = now
    // The first 1.8s after our own speaker starts is almost always echo pickup.
    // Keep native STT gated and require cloud STT text to pass the echo classifier.
    strongPlaybackGateUntil = maxOf(strongPlaybackGateUntil, now + 1800L)
    suppressRecognitionUntil = maxOf(suppressRecognitionUntil, now + 1200L)
  }

  private fun recoverStuckPlaybackStateIfNeeded() {
    val now = System.currentTimeMillis()
    if (speaking) {
      val startedAt = appTtsStartedAt
      // Some Android TTS engines do not reliably invoke onDone/onError when the
      // utterance is flushed, interrupted by audio focus, or cancelled while the
      // user is speaking.  A stale speaking=true blocks listenAgain() forever, so
      // force-release it after a generous timeout.
      if (startedAt > 0L && now - startedAt > 120_000L) {
        appTtsWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
        appTtsWatchdogRunnable = null
        ttsStartWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
        ttsStartWatchdogRunnable = null
        currentAppTtsUtteranceId = ""
        currentAppTtsStartedByEngine = false
        speaking = false
        markPostPlaybackHandoff()
      }
    }
    if (listening && listeningStartedAt > 0L && now - listeningStartedAt > 18_000L) {
      try { recognizer?.cancel() } catch (_: Throwable) {}
      listening = false
      listeningStartedAt = 0L
    }
  }

  private fun estimatedAppTtsWatchdogMs(text: String): Long {
    // Chinese TTS is usually 3-5 chars/sec. This watchdog is only a safety net
    // for missing completion callbacks, so choose a generous upper bound.
    return (8_000L + text.length * 420L).coerceIn(12_000L, 120_000L)
  }

  private fun scheduleAppTtsWatchdog(utteranceId: String, text: String, restart: Boolean) {
    appTtsWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    val timeout = estimatedAppTtsWatchdogMs(text)
    appTtsWatchdogRunnable = Runnable {
      if (destroyed) return@Runnable
      if (speaking && currentAppTtsUtteranceId == utteranceId) {
        synchronized(ttsRestartByUtterance) { ttsRestartByUtterance.remove(utteranceId) }
        ttsStartWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
        ttsStartWatchdogRunnable = null
        currentAppTtsUtteranceId = ""
        currentAppTtsStartedByEngine = false
        speaking = false
        markPostPlaybackHandoff()
        transcriptView?.append("\n（播报状态已自动恢复，继续聆听…）")
        if (speechBuffer.isNotBlank()) {
          scheduleBufferedSpeechProcessing(350L)
          if (restart) listenAgain(40L)
        } else if (processPendingAiUserSpeechIfReady()) {
          if (restart) listenAgain(40L)
        } else if (restart) listenAgain(40L)
      }
    }
    speechHandler.postDelayed(appTtsWatchdogRunnable!!, timeout)
  }

  private fun finishAppTtsPlaybackState(utteranceId: String?, restart: Boolean) {
    logVoice("ai.tts.playback.finish", "AI TTS playback finished", mapOf("utteranceId" to (utteranceId ?: ""), "restart" to restart))
    if (utteranceId == null || utteranceId == currentAppTtsUtteranceId) {
      appTtsWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
      appTtsWatchdogRunnable = null
      ttsStartWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
      ttsStartWatchdogRunnable = null
      currentAppTtsUtteranceId = ""
      appTtsStartedAt = 0L
      currentAppTtsStartedByEngine = false
    }
    speaking = false
    markPostPlaybackHandoff(700L)
    resetBatchCurrentCaptureForSpeakerPlayback("AI 语音播报刚结束：非实时录音已保持就绪，短暂冷却后立即接收你接下来的开头。", cooldownMs = 80L, preserveOpenRecorder = true)
    if (speechBuffer.isNotBlank()) {
      scheduleBufferedSpeechProcessing(350L)
      if (restart) runOnUiThread { listenAgain(0L) }
    } else if (processPendingAiUserSpeechIfReady()) {
      if (restart) runOnUiThread { listenAgain(0L) }
    } else if (restart) {
      runOnUiThread { listenAgain(0L) }
    }
  }

  private fun interruptPlaybackForUserSpeech(text: String) {
    val wasSpeaking = speaking
    val wasAlarmVoice = alarmVoicePlaying
    if (!wasSpeaking && !wasAlarmVoice) return

    if (wasSpeaking) {
      // Treat a confirmed USER chunk during our own AI/TTS playback as barge-in.
      // Stop the current TTS and release the speaking gate immediately; do not
      // wait for onDone/onError because many engines do not fire it after stop().
      try { tts?.stop() } catch (_: Throwable) {}
      val currentId = currentAppTtsUtteranceId
      synchronized(ttsRestartByUtterance) {
        if (currentId.isNotBlank()) ttsRestartByUtterance.remove(currentId)
      }
      finishAppTtsPlaybackState(currentId.ifBlank { null }, restart = false)
    }

    if (wasAlarmVoice) {
      // Stop the foreground alarm voice in the service as soon as a real barge-in is detected.
      // Merely flipping alarmVoicePlaying=false leaves MediaPlayer/TTS playing in the service,
      // so the microphone keeps recording the app prompt and STT returns phrases like “补水整理好心情”。
      VoiceAlarmRingingService.postponeVoiceReplay(this, 30_000L)
      alarmVoicePlaying = false
      alarmPlaybackWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
      alarmPlaybackWatchdogRunnable = null
      markPostPlaybackHandoff(500L)
    }
    // Once the user has clearly barged in and playback has been stopped, do not
    // keep the echo guard alive for another 1.8 seconds.  Keeping that gate active
    // made recordBatchPcmUntilSubmit repeatedly reset the capture and lose the
    // first words after the interruption.
    val nowAfterStop = System.currentTimeMillis()
    batchPlaybackEchoGuardUntil = nowAfterStop
    batchSpeakerPlaybackBlockUntil = nowAfterStop
    suppressRecognitionUntil = minOf(suppressRecognitionUntil, nowAfterStop + 80L)
    strongPlaybackGateUntil = minOf(strongPlaybackGateUntil, nowAfterStop + 80L)

    if (!isStopCommand(text) && !isSnoozeCommand(text)) {
      transcriptView?.text = "检测到用户插话，已暂停播报并保留你的语音…"
    }
    scheduleRecognitionRecoveryAfterBargeIn()
  }

  private fun scheduleRecognitionRecoveryAfterBargeIn() {
    speechHandler.postDelayed({
      if (destroyed) return@postDelayed
      recoverStuckPlaybackStateIfNeeded()
      when {
        cloudSttActive && !isCloudSttHealthy() -> {
          cloudSttActive = false
          startVoiceAssistant()
        }
        !cloudSttActive && !speaking && !listening -> listenAgain(350L)
      }
    }, 900L)
  }

  private data class VoiceEndpointingConfig(
    val preset: String,
    val completeSilenceMs: Long,
    val possiblyCompleteSilenceMs: Long,
    val minUtteranceMs: Long,
    val finalCommitDelayMs: Long,
    val partialFallbackDelayMs: Long,
    val semanticExtraWaitMs: Long,
    val stableTextMs: Long,
    val maxUtteranceMs: Long,
    val minCommitChars: Int,
    val semanticEndpointing: Boolean,
  )

  private fun endpointingConfig(): VoiceEndpointingConfig {
    val data = try { JSONObject(payload).optJSONObject("voiceEndpointing") } catch (_: Throwable) { null }
    val preset = data?.optString("preset", "balanced")?.ifBlank { "balanced" } ?: "balanced"
    fun longValue(name: String, fallback: Long, min: Long, max: Long): Long {
      val raw = data?.optLong(name, fallback) ?: fallback
      return raw.coerceIn(min, max)
    }
    fun intValue(name: String, fallback: Int, min: Int, max: Int): Int {
      val raw = data?.optInt(name, fallback) ?: fallback
      return raw.coerceIn(min, max)
    }
    fun boolValue(name: String, fallback: Boolean): Boolean = data?.optBoolean(name, fallback) ?: fallback

    val defaults = when (preset) {
      "fast" -> VoiceEndpointingConfig(preset, 900, 700, 500, 900, 1800, 0, 500, 12000, 1, false)
      "complete" -> VoiceEndpointingConfig(preset, 2200, 1500, 800, 2100, 3600, 0, 1000, 35000, 1, false)
      "long" -> VoiceEndpointingConfig(preset, 3200, 2200, 1000, 3200, 5200, 0, 1400, 60000, 1, false)
      else -> VoiceEndpointingConfig("balanced", 1400, 1000, 600, 1300, 2600, 0, 750, 22000, 1, false)
    }

    return defaults.copy(
      completeSilenceMs = longValue("completeSilenceMs", defaults.completeSilenceMs, 700, 6000),
      possiblyCompleteSilenceMs = longValue("possiblyCompleteSilenceMs", defaults.possiblyCompleteSilenceMs, 500, 5000),
      minUtteranceMs = longValue("minUtteranceMs", defaults.minUtteranceMs, 500, 6000),
      finalCommitDelayMs = longValue("finalCommitDelayMs", defaults.finalCommitDelayMs, 800, 8000),
      partialFallbackDelayMs = longValue("partialFallbackDelayMs", defaults.partialFallbackDelayMs, 1800, 10000),
      semanticExtraWaitMs = longValue("semanticExtraWaitMs", defaults.semanticExtraWaitMs, 0, 5000),
      stableTextMs = longValue("stableTextMs", defaults.stableTextMs, 300, 3000),
      maxUtteranceMs = longValue("maxUtteranceMs", defaults.maxUtteranceMs, 8000, 60000),
      minCommitChars = intValue("minCommitChars", defaults.minCommitChars, 1, 30),
      semanticEndpointing = boolValue("semanticEndpointing", defaults.semanticEndpointing),
    )
  }

  private fun resetUtteranceSessionIfIdle() {
    if (speechBuffer.isBlank()) {
      utteranceSessionStartedAt = 0L
      lastSpeechChunkAt = 0L
      semanticHoldExtended = false
      lastTranscriptRevisionAt = 0L
      lastDraftTextNormalized = ""
      lastAppendedChunkStart = 0
    }
  }

  private enum class SpeechOrigin { USER, PLAYBACK_ECHO, NOISE }

  private fun onSpeechChunk(chunk: String, finalChunk: Boolean) {
    val text = chunk.trim()
    if (text.isBlank()) return
    val origin = classifySpeechOrigin(text, finalChunk)
    logVoice("stt.chunk", "STT chunk received", mapOf("mode" to selectedSttMode(), "provider" to selectedSttProvider(), "final" to finalChunk, "origin" to origin.name, "text" to logPreview(text)))

    when (origin) {
      SpeechOrigin.PLAYBACK_ECHO -> {
        val label = if (speaking) "AI 播报回声" else "闹钟播报回声"
        transcriptView?.text = "已忽略${label}，继续等待用户真人语音…"
        // Do not postpone/stop the alarm or AI voice here. This is our own speaker.
        strongPlaybackGateUntil = maxOf(strongPlaybackGateUntil, System.currentTimeMillis() + 900L)
        scheduleListeningAfterSuppression(500L)
        return
      }
      SpeechOrigin.NOISE -> {
        if (!isPlaybackActiveForSpeechGate()) listenAgain(350)
        return
      }
      SpeechOrigin.USER -> Unit
    }

    // Only real user speech reaches this point. If the user talks over our
    // playback, treat it as barge-in: stop local AI/TTS immediately and release
    // stale playback gates before scheduling recognition again.
    val interruptedPlayback = speaking || alarmVoicePlaying
    if (interruptedPlayback) interruptPlaybackForUserSpeech(text)

    // Now it is safe to postpone the next alarm replay; doing this before
    // classification caused the app to stop its own TTS/MediaPlayer when cloud
    // STT heard speaker echo.
    postponeAlarmVoiceReplay(30_000L)

    if (!interruptedPlayback && isPlaybackActiveForSpeechGate() && !isStopCommand(text) && !isSnoozeCommand(text)) {
      appendSpeechChunk(text, finalChunk)
      transcriptView?.text = "正在听写：${speechBuffer}\n（播报中已暂存真人语音，播报结束并稳定后自动发送…）"
      scheduleBufferedSpeechProcessing(if (speaking || alarmVoicePlaying) endpointingConfig().finalCommitDelayMs else endpointingConfig().possiblyCompleteSilenceMs)
      return
    }

    appendSpeechChunk(text, finalChunk)
    transcriptView?.text = if (selectedSttMode() == "batch") {
      "非实时识别结果：${speechBuffer}\n（已显示语音转文字结果，静音与文本稳定后自动发送给 AI）"
    } else {
      "正在听写：${speechBuffer}\n（实时草稿会动态修正；静音与文本稳定后自动发送给 AI）"
    }
    val endpoint = endpointingConfig()
    val shouldHandleQuickly = finalChunk && (isStopCommand(text) || isSnoozeCommand(text))
    scheduleBufferedSpeechProcessing(
      when {
        shouldHandleQuickly -> 250L
        finalChunk -> endpoint.finalCommitDelayMs
        else -> endpoint.partialFallbackDelayMs
      },
    )
  }

  private fun onBatchTranscriptionResult(text: String) {
    val clean = sanitizeBatchTranscriptEcho(text.trim())
    if (clean.isBlank()) { batchAwaitingAiCommit = false; return }
    logVoice("batch.result", "batch STT text returned", mapOf("text" to logPreview(clean), "chars" to clean.length))
    // 非实时识别是“提交一段音频文件后返回文本”。如果这段文件里录到了闹钟/AI 播报声，
    // 服务商无法知道那是扬声器回声，会照样转成文字。因此非实时结果仍必须做文本级回声过滤，
    // 但只拦截与闹钟播报/上一条 AI 播报高度相似的文本，不再用普通噪声规则误杀长句。
    if (!isStopCommand(clean) && !isSnoozeCommand(clean) && isLikelyPlaybackEcho(clean)) {
      logVoice("batch.result.echoIgnored", "batch result looked like playback echo", mapOf("text" to logPreview(clean)))
      setBatchStatus("已忽略疑似播报回声：这段非实时转写与闹钟/AI 播报内容高度相似，没有作为用户输入发送。播报结束后请重新说。")
      transcriptView?.text = "已忽略疑似播报回声，继续等待用户真人语音…"
      batchAwaitingAiCommit = false
      return
    }
    val interruptedPlayback = speaking || alarmVoicePlaying
    if (interruptedPlayback) interruptPlaybackForUserSpeech(clean)
    postponeAlarmVoiceReplay(30_000L)
    appendSpeechChunk(clean, finalChunk = true)
    transcriptView?.text = "非实时识别结果：${speechBuffer}\n（结果已显示；静音与文本稳定后自动发送给 AI，也可继续说下一段）"
    setBatchStatus("识别完成：已显示当前完整录音的转文字结果；录音暂停，准备发送给 AI。")
    val endpoint = endpointingConfig()
    scheduleBufferedSpeechProcessing(
      when {
        isStopCommand(clean) || isSnoozeCommand(clean) -> 250L
        else -> endpoint.finalCommitDelayMs
      },
    )
  }

  private fun classifySpeechOrigin(text: String, finalChunk: Boolean): SpeechOrigin {
    val normalized = normalizeSpeechText(text)
    if (normalized.isBlank()) return SpeechOrigin.NOISE
    val urgent = isStopCommand(text) || isSnoozeCommand(text) || isWakeCommand(text)
    if (urgent) return SpeechOrigin.USER
    if (isLikelyPlaybackEcho(text)) return SpeechOrigin.PLAYBACK_ECHO
    if (isLikelyNoise(text)) return SpeechOrigin.NOISE

    val now = System.currentTimeMillis()
    val playbackActive = isPlaybackActiveForSpeechGate()
    if (playbackActive) {
      val sincePlaybackStart = now - appPlaybackStartedAt
      // A short, non-command fragment at the beginning of our own playback is far
      // more likely to be acoustic echo than a meaningful user interruption.
      if (sincePlaybackStart in 0..1800L && normalized.length < 10) return SpeechOrigin.PLAYBACK_ECHO
      // During playback, very short non-command snippets such as “好的/嗯/今天”
      // are usually speaker leakage or room noise. Real user interruption must be
      // either a command/wake word or a fuller sentence that survives echo matching.
      if (normalized.length < 4) return SpeechOrigin.PLAYBACK_ECHO
      if (!finalChunk && normalized.length < 8) return SpeechOrigin.PLAYBACK_ECHO
    }
    return SpeechOrigin.USER
  }

  private fun isLikelyNoise(text: String): Boolean {
    val normalized = normalizeSpeechText(text)
    if (normalized.isBlank()) return true
    // Previously ANY result of length <= 2 was discarded unless it happened to
    // match a stop/snooze/wake command. That silently swallowed extremely
    // common, meaningful short Chinese replies such as "好的" "可以" "知道"
    // "没事" "谢谢" "好" "对" "走" before they ever reached the speech buffer —
    // a direct cause of "words the user said keep getting dropped". Only treat
    // text as noise when it is exactly a bare filler/interjection with no
    // other content, regardless of its character length.
    val fillers = setOf(
      "嗯", "啊", "呃", "额", "哦", "喂", "哈", "唉", "呀",
      "嗯嗯", "啊啊", "呃呃", "哦哦", "哈哈", "呀呀", "诶", "噢", "唔",
    )
    if (fillers.contains(normalized)) return true
    return false
  }

  private fun appendSpeechChunk(text: String, finalChunk: Boolean = false) {
    val clean = text.trim()
    if (clean.isBlank()) return
    val now = System.currentTimeMillis()
    val fullBefore = speechBuffer.toString()
    if (fullBefore.isBlank()) {
      utteranceSessionStartedAt = now
      semanticHoldExtended = false
      lastAppendedChunkStart = 0
    }
    val safeStart = lastAppendedChunkStart.coerceIn(0, fullBefore.length)
    val committedPrefix = fullBefore.substring(0, safeStart)
    val revisableTail = fullBefore.substring(safeStart)

    // Only the tail contributed by the most recent, still-in-flight chunk is
    // ever eligible for similarity/containment-based "replace" merging (see
    // mergeLiveDictationText). Everything before `safeStart` is content that a
    // PREVIOUS call already finalized and is passed through mergeSpeechText,
    // which only stitches a literal seam overlap or concatenates — it can
    // never discard either side wholesale. This is what stops a later,
    // textually-similar-but-unrelated sentence from silently erasing earlier
    // user speech, which was the root cause of words/sentences disappearing.
    val revisedTail = if (revisableTail.isBlank()) clean else mergeLiveDictationText(revisableTail, clean, finalChunk)
    val merged = if (committedPrefix.isBlank()) revisedTail else mergeSpeechText(committedPrefix, revisedTail)

    speechBuffer.clear()
    speechBuffer.append(merged)

    lastAppendedChunkStart = if (finalChunk) {
      // Lock everything in. The next incoming chunk — whether the next
      // independent cloud-STT utterance or a fresh native-recognizer session
      // — is always brand-new content from here on.
      merged.length
    } else {
      safeStart
    }

    lastSpeechChunkAt = now
    val normalizedMerged = normalizeSpeechText(merged)
    if (normalizedMerged != lastDraftTextNormalized) {
      lastDraftTextNormalized = normalizedMerged
      lastTranscriptRevisionAt = now
    }
  }

  private fun mergeLiveDictationText(current: String, incoming: String, finalChunk: Boolean): String {
    val a = current.trim()
    val b = incoming.trim()
    val normalizedA = normalizeSpeechText(a)
    val normalizedB = normalizeSpeechText(b)
    if (normalizedB.isBlank()) return a
    if (normalizedA.isBlank()) return b
    if (normalizedB == normalizedA) return if (b.length >= a.length) b else a
    if (normalizedA.contains(normalizedB)) return a
    if (normalizedB.contains(normalizedA)) return b

    val similarity = textSimilarity(normalizedA, normalizedB)
    if (similarity >= 0.72) {
      // Streaming ASR often rewrites the same sentence after more context is
      // available.  Prefer replacement over append to mimic input-method style
      // dynamic correction and avoid duplicated fragments.
      return if (b.length >= a.length || !finalChunk) b else a
    }

    return mergeSpeechText(a, b)
  }

  private fun textSimilarity(a: String, b: String): Double {
    if (a.isBlank() || b.isBlank()) return 0.0
    val lcs = longestCommonSubsequenceLength(a, b).toDouble()
    return lcs / maxOf(a.length, b.length).toDouble()
  }

  private fun mergeSpeechText(current: String, incoming: String): String {
    val a = current.trim()
    val b = incoming.trim()
    if (b.isBlank()) return a
    if (a.isBlank()) return b
    val normalizedA = normalizeSpeechText(a)
    val normalizedB = normalizeSpeechText(b)
    if (normalizedA.isBlank()) return b
    if (normalizedB.isBlank()) return a
    // Exact duplicate, e.g. a retried network call delivering the same
    // utterance twice — safe to collapse to a single copy.
    if (normalizedA == normalizedB) return if (b.length >= a.length) b else a

    // Deliberately NOT using a whole-string "A contains B" / "B contains A"
    // shortcut here. Two genuinely separate, unrelated utterances can easily
    // share a short common phrase ("公园", "好的", "明天" ...). Discarding one
    // side just because it textually overlaps with the other is exactly how
    // real user speech silently disappeared from the transcript. Only a
    // literal overlap sitting right at the seam between the two chunks (e.g.
    // shared pre-roll audio causing the same boundary word to be transcribed
    // twice) is safe to dedupe.
    val compactA = a.replace(Regex("\\s+"), "")
    val compactB = b.replace(Regex("\\s+"), "")
    val maxOverlap = minOf(compactA.length, compactB.length, 32)
    for (size in maxOverlap downTo 2) {
      if (compactA.takeLast(size) == compactB.take(size)) {
        return compactA + compactB.substring(size)
      }
    }
    val lastA = a.lastOrNull()
    val firstB = b.firstOrNull()
    val needsSpacer = lastA != null && firstB != null &&
      lastA.code < 128 && firstB.code < 128 && lastA.isLetterOrDigit() && firstB.isLetterOrDigit()
    return if (needsSpacer) "$a $b" else "$a$b"
  }

  private fun shouldHoldBatchAiCommit(urgent: Boolean): Boolean {
    if (selectedSttMode() != "batch" || urgent) return false
    val now = System.currentTimeMillis()
    if (isBatchSpeakerPlaybackBlocked()) return true
    val hasVisibleTranscript = speechBuffer.toString().trim().isNotBlank()
    val transcriptAgeMs = if (lastSpeechChunkAt > 0L) now - lastSpeechChunkAt else 0L
    val recentConfirmedSpeech = batchCurrentConfirmedSpeech && batchLastSpeechAt > 0L && now - batchLastSpeechAt < batchAutoSubmitSilenceMs() + 1200L
    // 只要还有非实时 STT 请求正在识别，就不要提前把尚未稳定的文本发给 AI。
    // 之前的 forceRelease 允许 inFlight=true 时放行，造成“前半段先触发 AI，后半段还没转出来”。
    if (batchRecognitionInFlight || batchPcmQueue.isNotEmpty() || batchSubmitInProgress) return true
    // 如果下一条完整录音已经确认有人声，说明用户可能还在连续说话。
    // 暂缓把已识别文本发给 AI，等本次完整转写稳定后再提交。
    if (recentConfirmedSpeech) return true
    // 后续分段已经全部结束但没有新增有效文本时，放行已经稳定的有效转写，避免永久卡住。
    if (hasVisibleTranscript && transcriptAgeMs >= maxOf(2200L, batchAutoSubmitSilenceMs() / 2) && !recentConfirmedSpeech) {
      logVoice("batch.aiHold.forceRelease", "force release held batch transcript to AI after queue drained", mapOf("transcriptAgeMs" to transcriptAgeMs, "queue" to batchPcmQueue.size, "inFlight" to batchRecognitionInFlight, "submitting" to batchSubmitInProgress))
      return false
    }
    return false
  }

  private fun scheduleBufferedSpeechProcessing(delayMs: Long) {
    processSpeechRunnable?.let { speechHandler.removeCallbacks(it) }
    val endpoint = endpointingConfig()
    val actualDelay = delayMs.coerceIn(250L, endpoint.partialFallbackDelayMs)
    processSpeechRunnable = Runnable {
      processSpeechRunnable = null
      val merged = speechBuffer.toString().trim()
      try { recognizer?.cancel() } catch (_: Throwable) {}
      listening = false
      listeningStartedAt = 0L
      if (merged.isBlank()) {
        batchAwaitingAiCommit = false
        resetUtteranceSessionIfIdle()
        listenAgain(300)
        return@Runnable
      }
      if (isLikelyPlaybackEcho(merged)) {
        batchAwaitingAiCommit = false
        speechBuffer.clear()
        resetUtteranceSessionIfIdle()
        transcriptView?.text = "已过滤播报回声，继续聆听…"
        listenAgain(500)
        return@Runnable
      }
      val urgent = isStopCommand(merged) || isSnoozeCommand(merged)
      recoverStuckPlaybackStateIfNeeded()
      if (isPlaybackActiveForSpeechGate() && !urgent) {
        logVoice("batch.aiDuringPlayback.allowed", "send confirmed user transcript to AI while playback is active; playback echo filtering remains enabled", mapOf("chars" to merged.length, "speaking" to speaking, "alarmVoicePlaying" to alarmVoicePlaying, "pipeline" to batchChatPipelineVersion))
      }
      if (shouldHoldBatchAiCommit(urgent)) {
        transcriptView?.text = "非实时识别结果：$merged\n（严格单轮模式：当前文字准备发送给 AI，录音暂停）"
        setBatchStatus("严格单轮处理中：当前文字准备发送给 AI，录音暂停，避免混入下一轮。")
        scheduleBufferedSpeechProcessing(900L)
        return@Runnable
      }
      if (selectedSttMode() == "batch") {
        speechBuffer.clear()
        batchAwaitingAiCommit = false
        resetUtteranceSessionIfIdle()
        handleSpeech(merged)
        return@Runnable
      }
      if (!urgent && shouldWaitForMoreSpeech(merged)) {
        val waitMs = nextEndpointWaitDelay(merged)
        val waitSeconds = (waitMs / 1000.0).let { String.format(Locale.CHINA, "%.1f", it) }
        transcriptView?.text = "正在听写：$merged\n（自动提交等待：文本仍在稳定；约 ${waitSeconds} 秒内无新变化将发送给 AI）"
        listenAgain(80L)
        scheduleBufferedSpeechProcessing(waitMs)
        return@Runnable
      }
      speechBuffer.clear()
      batchAwaitingAiCommit = false
      resetUtteranceSessionIfIdle()
      handleSpeech(merged)
    }
    speechHandler.postDelayed(processSpeechRunnable!!, actualDelay)
  }

  private fun shouldWaitForMoreSpeech(text: String): Boolean {
    val endpoint = endpointingConfig()
    val normalized = normalizeSpeechText(text)
    if (normalized.isBlank()) return true
    if (isStopCommand(text) || isSnoozeCommand(text) || isWakeCommand(text)) return false

    val now = System.currentTimeMillis()
    val startedAt = if (utteranceSessionStartedAt > 0L) utteranceSessionStartedAt else lastSpeechChunkAt
    val sessionAge = if (startedAt > 0L) now - startedAt else endpoint.maxUtteranceMs
    val sinceLastChunk = if (lastSpeechChunkAt > 0L) now - lastSpeechChunkAt else endpoint.finalCommitDelayMs
    val sinceRevision = if (lastTranscriptRevisionAt > 0L) now - lastTranscriptRevisionAt else endpoint.stableTextMs

    if (sessionAge >= endpoint.maxUtteranceMs) return false
    if (isShortCompleteUtterance(text)) {
      return sinceLastChunk < minOf(endpoint.finalCommitDelayMs, 900L) || sinceRevision < minOf(endpoint.stableTextMs, 650L)
    }
    // Do not guess whether the user has semantically finished.  Treat text as a
    // live dictation draft and commit only after the audio endpoint and the text
    // have both been stable for the configured time window.
    if (sessionAge < endpoint.minUtteranceMs && normalized.length < 3) return true
    if (sinceLastChunk < endpoint.finalCommitDelayMs) return true
    if (sinceRevision < endpoint.stableTextMs) return true
    return false
  }

  private fun nextEndpointWaitDelay(text: String): Long {
    val endpoint = endpointingConfig()
    val now = System.currentTimeMillis()
    val sinceLastChunk = if (lastSpeechChunkAt > 0L) now - lastSpeechChunkAt else endpoint.finalCommitDelayMs
    val sinceRevision = if (lastTranscriptRevisionAt > 0L) now - lastTranscriptRevisionAt else endpoint.stableTextMs
    val audioRemain = (endpoint.finalCommitDelayMs - sinceLastChunk).coerceAtLeast(0L)
    val textRemain = (endpoint.stableTextMs - sinceRevision).coerceAtLeast(0L)
    val base = maxOf(audioRemain, textRemain, 350L)
    return base.coerceIn(350L, endpoint.partialFallbackDelayMs)
  }

  private fun isShortCompleteUtterance(text: String): Boolean {
    val raw = text.trim()
    val normalized = normalizeSpeechText(raw)
    if (normalized.isBlank()) return false
    if (isStopCommand(raw) || isSnoozeCommand(raw) || isWakeCommand(raw)) return true
    if (raw.any { it == '？' || it == '?' || it == '！' || it == '!' || it == '。' || it == '.' }) return normalized.length >= 2
    // Chinese short questions often contain no punctuation after STT. Treat these
    // as complete utterances instead of forcing them to pass a generic min length.
    val shortQuestionEndings = listOf("吗", "么", "呢", "吧", "对吗", "好吗", "行吗", "可以吗", "确定吗", "真的吗")
    if (normalized.length in 2..12 && shortQuestionEndings.any { normalized.endsWith(normalizeSpeechText(it)) }) return true
    val shortAck = listOf("可以", "确定", "好的", "好", "行", "对", "不是", "不用", "不要", "暂停", "继续")
    if (normalized.length in 1..6 && shortAck.any { normalized == normalizeSpeechText(it) }) return true
    return false
  }

  private fun looksSemanticallyComplete(text: String): Boolean {
    val raw = text.trim()
    val normalized = normalizeSpeechText(raw)
    if (normalized.isBlank()) return false
    if (isShortCompleteUtterance(raw)) return true
    if (raw.any { it == '。' || it == '？' || it == '?' || it == '！' || it == '!' || it == '；' || it == ';' }) return true
    if (isStopCommand(raw) || isSnoozeCommand(raw) || isWakeCommand(raw)) return true
    val continuationSuffixes = listOf(
      "然后", "但是", "可是", "因为", "所以", "如果", "假如", "就是", "而且", "还有", "另外",
      "比如", "例如", "我想", "我觉得", "我希望", "我现在", "能不能", "要不要", "或者", "以及", "并且",
      "首先", "其次", "最后", "接着", "同时", "关于", "对于", "这个", "那个", "就是在"
    ).map { normalizeSpeechText(it) }
    if (continuationSuffixes.any { normalized.endsWith(it) }) return false
    val continuationStarts = listOf("因为", "如果", "假如", "当", "虽然", "既然", "关于", "至于").map { normalizeSpeechText(it) }
    if (normalized.length < 18 && continuationStarts.any { normalized.startsWith(it) }) return false
    if (normalized.length >= 22) return true
    val intentWords = listOf("关闭", "延迟", "帮我", "提醒", "告诉", "解释", "分析", "总结", "为什么", "怎么", "如何", "是什么")
    return intentWords.any { raw.contains(it) || normalized.contains(normalizeSpeechText(it)) }
  }

  private fun queuePendingAiUserSpeech(text: String) {
    val clean = text.trim()
    if (clean.isBlank()) return
    pendingAiUserText = if (pendingAiUserText.isBlank()) clean else mergeSpeechText(pendingAiUserText, clean)
    pendingAiUserTextAt = System.currentTimeMillis()
    transcriptView?.append("\nAI 正在处理上一句，已暂存你的新语音：$clean")
    schedulePendingAiUserSpeechWatchdog()
  }

  private fun schedulePendingAiUserSpeechWatchdog() {
    pendingAiWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    pendingAiWatchdogRunnable = Runnable {
      pendingAiWatchdogRunnable = null
      recoverStuckPlaybackStateIfNeeded()
      if (pendingAiUserText.isBlank() || destroyed) return@Runnable
      if (!processPendingAiUserSpeechIfReady() && !aiBusy && !speaking && !alarmVoicePlaying && speechBuffer.isBlank()) {
        val pending = takePendingAiUserSpeech()
        if (pending.isNotBlank()) handleSpeech(pending)
      }
    }
    speechHandler.postDelayed(pendingAiWatchdogRunnable!!, 18_000L)
  }

  private fun takePendingAiUserSpeech(): String {
    pendingAiWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    pendingAiWatchdogRunnable = null
    val pending = pendingAiUserText.trim()
    pendingAiUserText = ""
    pendingAiUserTextAt = 0L
    return pending
  }

  private fun processPendingAiUserSpeechIfReady(): Boolean {
    if (destroyed || aiBusy || speaking || alarmVoicePlaying || speechBuffer.isNotBlank()) return false
    val pending = takePendingAiUserSpeech()
    if (pending.isBlank()) return false
    transcriptView?.append("\n继续处理刚才暂存的话…")
    speechHandler.post { handleSpeech(pending) }
    return true
  }

  private fun handleSpeech(rawText: String) {
    val text = rawText.trim()
    if (text.isBlank()) { listenAgain(300); return }
    logVoice("speech.handle", "handling user speech", mapOf("text" to logPreview(text), "mode" to selectedSttMode(), "provider" to selectedSttProvider()))
    if (isLikelyAlarmPlayback(text)) {
      transcriptView?.text = "已忽略播报回声，继续聆听用户真人语音…"
      listenAgain(500)
      return
    }
    postponeAlarmVoiceReplay(20_000L)
    transcriptView?.text = "你：$text"
    val isStop = isStopCommand(text)
    val isSnooze = isSnoozeCommand(text)
    if (!isStop && !isSnooze && aiBusy) {
      queuePendingAiUserSpeech(text)
      listenAgain(120)
      return
    }
    val normalizedForDedupe = normalizeSpeechText(text)
    val now = System.currentTimeMillis()
    if (!isStop && !isSnooze && normalizedForDedupe == lastHandledSpeechNormalized && now - lastHandledSpeechAt < 8000L) {
      transcriptView?.append("\n已忽略重复识别片段，继续聆听…")
      listenAgain(500)
      return
    }
    if (!isStop && !isSnooze) {
      lastHandledSpeechNormalized = normalizedForDedupe
      lastHandledSpeechAt = now
    }
    when {
      isStop -> {
        speak("好的，已关闭闹钟。", "alarm_stop", restart = false)
        VoiceAlarmRingingService.stop(this)
        transcriptView?.postDelayed({ finishAndRemoveTask() }, 5000)
      }
      isSnooze -> {
        speak("好的，五分钟后再次提醒。", "alarm_snooze", restart = false)
        VoiceAlarmScheduler.snooze(this, payload, 5)
        VoiceAlarmRingingService.stop(this)
        transcriptView?.postDelayed({ finishAndRemoveTask() }, 5000)
      }
      isWakeCommand(text) -> {
        aiAwake = true
        val query = stripWakeWords(text).ifBlank { "你好" }
        askAi(query)
      }
      aiAwake -> askAi(text)
      else -> {
        // 用户可能直接开始提问；非指令语音默认视为一次 AI 对话，唤醒词仍可用但不再强制。
        aiAwake = true
        askAi(text)
      }
    }
  }

  private fun isLikelyAlarmPlayback(text: String): Boolean {
    val alarmText = try { JSONObject(payload).optString("text", "") } catch (_: Throwable) { "" }
    return isLikelyPlaybackEcho(text, listOf(alarmText, lastAlarmSpokenText, lastAssistantSpokenText))
  }

  private fun isLikelyPlaybackEcho(text: String): Boolean {
    val alarmText = try { JSONObject(payload).optString("text", "") } catch (_: Throwable) { "" }
    return isLikelyPlaybackEcho(text, listOf(alarmText, lastAlarmSpokenText, lastAssistantSpokenText))
  }

  private fun isLikelyPlaybackEcho(text: String, sources: List<String>): Boolean {
    val b = normalizeSpeechText(text)
    if (b.length < 3) return false
    if (isGenericAlarmPromptTranscript(b)) return true
    for (source in sources) {
      val a = normalizeSpeechText(source)
      if (a.length < 4) continue
      // Exact/substring match: most common when STT hears our own TTS verbatim.
      if (a.contains(b) || b.contains(a.take(minOf(24, a.length)))) return true
      if (b.length >= 6 && a.windowed(minOf(6, b.length), 1).any { b.contains(it) }) return true

      val lcs = longestCommonSubsequenceLength(a, b)
      val shortBase = minOf(a.length, b.length).coerceAtLeast(1)
      val longBase = maxOf(a.length, b.length).coerceAtLeast(1)
      val shortRatio = lcs.toDouble() / shortBase
      val longRatio = lcs.toDouble() / longBase

      if (isPlaybackActiveForSpeechGate()) {
        // During playback, partial ASR fragments may be short and not perfectly
        // literal. LCS catches “same content with missing/extra words”.
        if (b.length <= 12 && shortRatio >= 0.58) return true
        if (b.length > 12 && (shortRatio >= 0.52 || longRatio >= 0.36)) return true
      } else {
        if (b.length >= 8 && shortRatio >= 0.72) return true
      }

      val bigramCommon = if (b.length >= 2) b.windowed(2, 1).count { a.contains(it) } else 0
      val bigramRatio = bigramCommon.toDouble() / maxOf(1, b.length - 1)
      if (isPlaybackActiveForSpeechGate() && bigramRatio >= 0.62) return true
      if (!isPlaybackActiveForSpeechGate() && b.length >= 8 && bigramRatio >= 0.78) return true
    }
    return false
  }

  private fun longestCommonSubsequenceLength(a: String, b: String): Int {
    if (a.isBlank() || b.isBlank()) return 0
    val m = a.length
    val n = b.length
    var prev = IntArray(n + 1)
    var curr = IntArray(n + 1)
    for (i in 1..m) {
      for (j in 1..n) {
        curr[j] = if (a[i - 1] == b[j - 1]) prev[j - 1] + 1 else maxOf(prev[j], curr[j - 1])
      }
      val tmp = prev
      prev = curr
      curr = tmp
      java.util.Arrays.fill(curr, 0)
    }
    return prev[n]
  }

  private fun normalizeSpeechText(value: String): String = value.lowercase(Locale.ROOT).filter { it.isLetterOrDigit() || it in '\u4e00'..'\u9fff' }

  private fun isStopCommand(text: String): Boolean {
    val normalized = normalizeSpeechText(text)
    return listOf("关闭", "停止", "关掉", "结束闹钟", "停掉闹钟", "不响了", "不要响", "别响", "停", "关").any {
      text.contains(it) || normalized.contains(normalizeSpeechText(it))
    }
  }

  private fun isSnoozeCommand(text: String): Boolean {
    val normalized = normalizeSpeechText(text)
    val hasSnoozeIntent = listOf("延迟", "延时", "推迟", "稍后", "等会", "再响", "贪睡", "小睡", "过会").any {
      text.contains(it) || normalized.contains(normalizeSpeechText(it))
    }
    val hasFiveMinutes = listOf("五分钟", "5分钟", "五 分钟", "5 分钟", "五分", "5分", "五分钟后", "5分钟后").any {
      text.contains(it) || normalized.contains(normalizeSpeechText(it))
    }
    return (hasSnoozeIntent && hasFiveMinutes) ||
      normalized.contains("延迟五") || normalized.contains("延迟5") ||
      normalized.contains("延时五") || normalized.contains("延时5") ||
      normalized.contains("五分钟后提醒") || normalized.contains("5分钟后提醒")
  }

  private fun isWakeCommand(text: String): Boolean = listOf("小名小名", "你好AI", "你好ai", "闹钟助手", "AI助手", "ai助手", "小名", "助手").any { text.contains(it) }

  private fun stripWakeWords(text: String): String {
    var out = text
    for (w in listOf("小名小名", "你好AI", "你好ai", "闹钟助手", "AI助手", "ai助手", "小名", "助手")) out = out.replace(w, "")
    return out.trim(' ', '，', ',', '。', '：', ':')
  }

  private fun scheduleAiBusyWatchdog(requestSeq: Int) {
    aiBusyWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    aiBusyWatchdogRunnable = Runnable {
      aiBusyWatchdogRunnable = null
      if (destroyed || !aiBusy || aiRequestSeq != requestSeq) return@Runnable
      val age = System.currentTimeMillis() - aiBusyStartedAt
      if (age >= 70_000L) {
        aiBusy = false
        aiRequestSeq++
        transcriptView?.append("\nAI 请求超时，已恢复语音识别；可继续说话。")
        if (!processPendingAiUserSpeechIfReady()) listenAgain(120L)
      }
    }
    speechHandler.postDelayed(aiBusyWatchdogRunnable!!, 72_000L)
  }

  private fun askAi(userText: String) {
    if (aiBusy) {
      logVoice("ai.ask.skipped", "AI busy; skipped direct ask", mapOf("text" to logPreview(userText)))
      return
    }
    postponeAlarmVoiceReplay(90_000L)
    val aiConfig = try { JSONObject(payload).optJSONObject("aiConfig") } catch (_: Throwable) { null }
    if (aiConfig == null || !aiConfig.optBoolean("available", false)) {
      val answer = "我已经被唤醒了，但当前闹钟没有可用的全局 AI 配置快照。请回到设置页配置 AI 后重新保存闹钟。你仍可说关闭闹钟或延迟五分钟。"
      transcriptView?.append("\nAI：$answer")
      speak(answer, "alarm_ai_unavailable")
      return
    }
    aiBusy = true
    aiBusyStartedAt = System.currentTimeMillis()
    val requestSeq = ++aiRequestSeq
    logVoice("ai.ask.start", "AI request started", mapOf("seq" to requestSeq, "text" to logPreview(userText), "provider" to aiConfig.optString("provider", ""), "model" to aiConfig.optString("model", "")))
    scheduleAiBusyWatchdog(requestSeq)
    transcriptView?.append("\nAI：正在思考…")
    Thread {
      val answer = try { callAi(aiConfig, userText) } catch (t: Throwable) {
        logVoice("ai.ask.error", t.message ?: t.javaClass.simpleName, mapOf("seq" to requestSeq))
        "AI 请求失败：${t.message ?: t.javaClass.simpleName}"
      }
      runOnUiThread {
        if (requestSeq != aiRequestSeq || destroyed) return@runOnUiThread
        aiBusyWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
        aiBusyWatchdogRunnable = null
        aiBusy = false
        aiBusyStartedAt = 0L
        val clean = answer.ifBlank { "AI 没有返回内容。你可以再说一遍，或说关闭闹钟 / 延迟五分钟。" }
        transcriptView?.append("\nAI：$clean")
        conversation.add("user" to userText)
        conversation.add("assistant" to clean)
        while (conversation.size > 12) conversation.removeAt(0)
        speak(clean, "alarm_ai_${System.currentTimeMillis()}")
      }
    }.start()
  }

  private fun speak(text: String, utteranceId: String, restart: Boolean = true) {
    val safeText = text.take(600).trim()
    if (safeText.isBlank()) { if (restart) listenAgain(120L); return }
    lastAssistantSpokenText = safeText
    if (tts == null || !ttsReady) {
      queuePendingSpeak(safeText, utteranceId, restart)
      return
    }
    performTtsSpeak(safeText, utteranceId, restart, retry = 0)
  }

  private fun queuePendingSpeak(text: String, utteranceId: String, restart: Boolean) {
    pendingSpeakText = text
    pendingSpeakUtteranceId = utteranceId
    pendingSpeakRestart = restart
    pendingSpeakAttempts = 0
    transcriptView?.append("\n（语音引擎准备中，AI文字已显示，稍后自动播报…）")
    speechHandler.postDelayed({ flushPendingSpeakIfReady() }, 500L)
    speechHandler.postDelayed({ flushPendingSpeakIfReady() }, 1500L)
    if (restart) listenAgain(120L)
  }

  private fun flushPendingSpeakIfReady() {
    if (destroyed || pendingSpeakText.isBlank()) return
    if (tts == null || !ttsReady) {
      pendingSpeakAttempts++
      if (pendingSpeakAttempts >= 8) {
        transcriptView?.append("\n（系统语音引擎暂不可用，已保留文字回答，可继续说话。）")
        pendingSpeakText = ""
        pendingSpeakUtteranceId = ""
        if (pendingSpeakRestart) listenAgain(120L)
      }
      return
    }
    val text = pendingSpeakText
    val id = pendingSpeakUtteranceId.ifBlank { "alarm_ai_${System.currentTimeMillis()}" }
    val restart = pendingSpeakRestart
    pendingSpeakText = ""
    pendingSpeakUtteranceId = ""
    pendingSpeakAttempts = 0
    performTtsSpeak(text, id, restart, retry = 0)
  }

  private fun performTtsSpeak(text: String, utteranceId: String, restart: Boolean, retry: Int) {
    logVoice("ai.tts.start", "AI TTS speak requested", mapOf("utteranceId" to utteranceId, "restart" to restart, "retry" to retry, "text" to logPreview(text)))
    lastAssistantSpokenText = text
    markAppTtsPlaybackStart()
    currentAppTtsUtteranceId = utteranceId
    currentAppTtsStartedByEngine = false
    postponeAlarmVoiceReplay(45_000L)
    try { recognizer?.cancel() } catch (_: Throwable) {}
    listening = false
    listeningStartedAt = 0L
    speaking = true
    synchronized(ttsRestartByUtterance) { ttsRestartByUtterance[utteranceId] = restart }
    scheduleAppTtsWatchdog(utteranceId, text, restart)
    scheduleTtsStartWatchdog(text, utteranceId, restart, retry)
    val params = Bundle().apply { putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId) }
    val result = try { tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, utteranceId) } catch (_: Throwable) { TextToSpeech.ERROR }
    if (result == null || result == TextToSpeech.ERROR) {
      ttsStartWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
      ttsStartWatchdogRunnable = null
      synchronized(ttsRestartByUtterance) { ttsRestartByUtterance.remove(utteranceId) }
      if (retry < 2 && !destroyed) {
        speechHandler.postDelayed({ performTtsSpeak(text, "${utteranceId}_retry${retry + 1}", restart, retry + 1) }, 700L)
      } else {
        transcriptView?.append("\n（AI文字已返回，但系统语音播报启动失败，可继续语音操作。）")
        finishAppTtsPlaybackState(utteranceId, restart)
      }
    }
  }

  private fun scheduleTtsStartWatchdog(text: String, utteranceId: String, restart: Boolean, retry: Int) {
    ttsStartWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    ttsStartWatchdogRunnable = Runnable {
      if (destroyed) return@Runnable
      if (currentAppTtsUtteranceId == utteranceId && speaking && !currentAppTtsStartedByEngine) {
        try { tts?.stop() } catch (_: Throwable) {}
        synchronized(ttsRestartByUtterance) { ttsRestartByUtterance.remove(utteranceId) }
        appTtsWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
        appTtsWatchdogRunnable = null
        if (retry < 2) {
          transcriptView?.append("\n（语音播报未启动，正在自动重试…）")
          performTtsSpeak(text, "${utteranceId}_startRetry${retry + 1}", restart, retry + 1)
        } else {
          transcriptView?.append("\n（AI文字已返回，但系统语音引擎没有开始播报，已恢复聆听。）")
          currentAppTtsUtteranceId = ""
          currentAppTtsStartedByEngine = false
          speaking = false
          markPostPlaybackHandoff()
          resetBatchCurrentCaptureForSpeakerPlayback("AI 语音播报未启动，非实时录音已恢复。", cooldownMs = 300L)
          if (restart) listenAgain(80L)
        }
      }
    }
    speechHandler.postDelayed(ttsStartWatchdogRunnable!!, 1700L)
  }

  private fun handleTtsFinished(utteranceId: String?, success: Boolean) {
    val restart = synchronized(ttsRestartByUtterance) {
      if (utteranceId == null) true else ttsRestartByUtterance.remove(utteranceId) ?: true
    }
    finishAppTtsPlaybackState(utteranceId, restart)
    if (!success) postponeAlarmVoiceReplay(3000L)
  }

  private fun postponeAlarmVoiceReplay(postponeMs: Long) {
    val now = System.currentTimeMillis()
    val nextUntil = now + postponeMs
    if (nextUntil <= lastReplayPostponeUntil + 2000L && now - lastReplayPostponeSentAt < 1000L) return
    lastReplayPostponeSentAt = now
    lastReplayPostponeUntil = nextUntil
    VoiceAlarmRingingService.postponeVoiceReplay(this, postponeMs)
  }

  private fun resolveSystemPrompt(): String {
    val fromPayload = try { JSONObject(payload).optString("aiSystemPrompt", "") } catch (_: Throwable) { "" }
    if (fromPayload.isNotBlank()) return fromPayload
    return "你是一个正在全屏闹钟界面中陪伴用户的中文语音 AI。回答要简短、自然、适合朗读，通常不超过80字。用户可以说关闭闹钟或延迟五分钟。"
  }

  private fun callAi(cfg: JSONObject, userText: String): String {
    val provider = cfg.optString("provider", "deepseek")
    val endpoint = cfg.optString("endpoint", "")
    val apiKey = cfg.optString("apiKey", "")
    val model = cfg.optString("model", "")
    if (endpoint.isBlank() || apiKey.isBlank() || model.isBlank()) {
      logVoice("ai.call.configMissing", "AI config incomplete", mapOf("provider" to provider, "model" to model, "endpointBlank" to endpoint.isBlank(), "apiKeyBlank" to apiKey.isBlank()))
      return "AI 配置不完整，请回到设置页重新保存闹钟。"
    }
    val messages = JSONArray().apply {
      put(JSONObject().put("role", "system").put("content", resolveSystemPrompt()))
      for ((role, content) in conversation.takeLast(10)) put(JSONObject().put("role", role).put("content", content))
      put(JSONObject().put("role", "user").put("content", userText))
    }
    val body = if (provider == "openai" && endpoint.contains("/responses")) {
      JSONObject()
        .put("model", model)
        .put("input", messages)
        .put("max_output_tokens", 220)
        .put("temperature", 0.7)
    } else {
      JSONObject()
        .put("model", model)
        .put("messages", messages)
        .put("max_tokens", 220)
        .put("temperature", 0.7)
        .put("stream", false)
    }
    val conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
      requestMethod = "POST"
      connectTimeout = 15000
      readTimeout = 45000
      doOutput = true
      setRequestProperty("Content-Type", "application/json")
      setRequestProperty("Authorization", "Bearer $apiKey")
      if (provider == "openrouter") setRequestProperty("X-OpenRouter-Title", "Quote App Voice Alarm")
      if (provider == "edenai") setRequestProperty("Accept", "application/json")
    }
    logVoice("ai.call.http.start", "calling AI endpoint", mapOf("provider" to provider, "model" to model, "endpoint" to endpoint.take(120), "bodyChars" to body.toString().length))
    OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body.toString()) }
    val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
    val resp = BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { it.readText() }
    logVoice("ai.call.http.result", "AI HTTP response", mapOf("provider" to provider, "status" to conn.responseCode, "resp" to resp.take(220)))
    if (conn.responseCode !in 200..299) return "AI 请求失败：HTTP ${conn.responseCode} ${resp.take(120)}"
    return extractAiText(JSONObject(resp))
  }

  private fun extractAiText(obj: JSONObject): String {
    val choices = obj.optJSONArray("choices")
    if (choices != null && choices.length() > 0) {
      val msg = choices.optJSONObject(0)?.optJSONObject("message")?.optString("content", "") ?: ""
      if (msg.isNotBlank()) return msg.trim()
      val text = choices.optJSONObject(0)?.optString("text", "") ?: ""
      if (text.isNotBlank()) return text.trim()
    }
    val outputText = obj.optString("output_text", "")
    if (outputText.isNotBlank()) return outputText.trim()
    val output = obj.optJSONArray("output")
    if (output != null) {
      val parts = mutableListOf<String>()
      for (i in 0 until output.length()) {
        val content = output.optJSONObject(i)?.optJSONArray("content") ?: continue
        for (j in 0 until content.length()) {
          val text = content.optJSONObject(j)?.optString("text", "") ?: ""
          if (text.isNotBlank()) parts.add(text)
        }
      }
      if (parts.isNotEmpty()) return parts.joinToString("\n").trim()
    }
    return ""
  }

  override fun onDestroy() {
    destroyed = true
    stopCloudStt()
    try { iflytekSttClient?.dispatcher?.executorService?.shutdown() } catch (_: Throwable) {}
    try { iflytekSttClient?.connectionPool?.evictAll() } catch (_: Throwable) {}
    iflytekSttClient = null
    synchronized(ttsRestartByUtterance) { ttsRestartByUtterance.clear() }
    pendingAiUserText = ""
    pendingAiUserTextAt = 0L
    processSpeechRunnable?.let { speechHandler.removeCallbacks(it) }
    resumeListeningRunnable?.let { speechHandler.removeCallbacks(it) }
    alarmPlaybackWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    appTtsWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    ttsStartWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    aiBusyWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    pendingAiWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    if (alarmPlaybackReceiverRegistered) { try { unregisterReceiver(alarmPlaybackReceiver) } catch (_: Throwable) {} ; alarmPlaybackReceiverRegistered = false }
    try { recognizer?.destroy() } catch (_: Throwable) {}
    pendingSpeakText = ""
    pendingSpeakUtteranceId = ""
    ttsReady = false
    try { tts?.shutdown() } catch (_: Throwable) {}
    recognizer = null
    tts = null
    super.onDestroy()
  }

  override fun onBackPressed() {
    // 防止误触返回键静默关闭界面；必须明确选择稍后提醒或停止闹钟。
  }
}
