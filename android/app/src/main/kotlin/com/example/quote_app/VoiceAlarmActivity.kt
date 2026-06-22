package com.example.quote_app

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
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
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class VoiceAlarmActivity : Activity() {
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
  private var iflytekSttClient: OkHttpClient? = null
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
  @Volatile private var appPlaybackStartedAt = 0L
  @Volatile private var strongPlaybackGateUntil = 0L
  @Volatile private var postPlaybackHandoffUntil = 0L
  @Volatile private var utteranceSessionStartedAt = 0L
  @Volatile private var lastSpeechChunkAt = 0L
  @Volatile private var semanticHoldExtended = false
  @Volatile private var lastTranscriptRevisionAt = 0L
  @Volatile private var lastDraftTextNormalized = ""
  private val alarmPlaybackReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      when (intent?.action) {
        VoiceAlarmRingingService.ACTION_VOICE_PLAYBACK_START -> handleAlarmVoicePlaybackStart()
        VoiceAlarmRingingService.ACTION_VOICE_PLAYBACK_END -> {
          alarmVoicePlaying = false
          alarmPlaybackWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
          alarmPlaybackWatchdogRunnable = null
          markPostPlaybackHandoff()
          if (speechBuffer.isNotBlank()) {
            scheduleBufferedSpeechProcessing(350L)
          }
          listenAgain(40L)
        }
      }
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    payload = intent?.getStringExtra("payload") ?: "{}"
    handleAlarmFireIntent(intent)
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
    if (VoiceAlarmFireGuard.shouldSkip(this, firePayload)) return
    try { VoiceAlarmRingingService.start(this, firePayload) } catch (_: Throwable) {}
    try { VoiceAlarmScheduler.scheduleNextDaily(this, firePayload) } catch (_: Throwable) {}
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

  private fun cloudSttConfigForSelected(): JSONObject? {
    val sttConfig = try { JSONObject(payload).optJSONObject("sttConfig") } catch (_: Throwable) { null }
    return when (selectedSttProvider()) {
      "microsoft" -> sttConfig?.optJSONObject("microsoft")?.takeIf { it.optString("apiKey", "").isNotBlank() }
      "iflytek" -> sttConfig?.optJSONObject("iflytek")?.takeIf {
        it.optString("appId", "").isNotBlank() &&
          it.optString("apiKey", "").isNotBlank() &&
          it.optString("apiSecret", "").isNotBlank()
      }
      else -> null
    }
  }

  private fun stopCloudStt(clearQueue: Boolean = true) {
    cloudSttActive = false
    cloudSttSession++
    try { cloudSttThread?.interrupt() } catch (_: Throwable) {}
    try { cloudSttRecognizeThread?.interrupt() } catch (_: Throwable) {}
    cloudSttThread = null
    cloudSttRecognizeThread = null
    if (clearQueue) microsoftPcmQueue.clear()
    releaseContinuousAudioRecord()
  }

  // Lazily creates (or reuses) a single AudioRecord that stays alive across
  // consecutive utterance segments. Only torn down and recreated when the
  // required audio source actually flips between normal VOICE_RECOGNITION
  // capture and the stricter VOICE_COMMUNICATION echo-guard capture used
  // during our own alarm/TTS playback, since AudioRecord's source can't be
  // changed without recreating the instance.
  private fun obtainContinuousAudioRecord(playbackGuard: Boolean): AudioRecord? {
    val existing = sharedCaptureRecord
    if (existing != null && existing.state == AudioRecord.STATE_INITIALIZED && sharedCaptureIsPlaybackGuard == playbackGuard) {
      return existing
    }
    releaseContinuousAudioRecord()
    val sampleRate = 16000
    val minBuffer = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
    if (minBuffer <= 0) return null
    val audioSource = if (playbackGuard) MediaRecorder.AudioSource.VOICE_COMMUNICATION else MediaRecorder.AudioSource.VOICE_RECOGNITION
    val record = try {
      AudioRecord(audioSource, sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, minBuffer * 4)
    } catch (_: Throwable) { null } ?: return null
    if (record.state != AudioRecord.STATE_INITIALIZED) {
      try { record.release() } catch (_: Throwable) {}
      return null
    }
    val effects = enableVoiceSeparationEffects(record.audioSessionId)
    try {
      record.startRecording()
    } catch (_: Throwable) {
      effects.release()
      try { record.release() } catch (_: Throwable) {}
      return null
    }
    sharedCaptureRecord = record
    sharedCaptureEffects = effects
    sharedCaptureIsPlaybackGuard = playbackGuard
    return record
  }

  private fun releaseContinuousAudioRecord() {
    try { sharedCaptureRecord?.stop() } catch (_: Throwable) {}
    try { sharedCaptureRecord?.release() } catch (_: Throwable) {}
    sharedCaptureEffects?.release()
    sharedCaptureRecord = null
    sharedCaptureEffects = null
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
    } else if (selectedSttProvider == "microsoft") {
      transcriptView?.text = "已选择微软语音识别，但缺少 Microsoft Speech API Key；暂时回退到系统识别。"
    } else if (selectedSttProvider == "iflytek") {
      transcriptView?.text = "已选择讯飞识别，但缺少 AppID/APIKey/APISecret；暂时回退到系统识别。"
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
            "正在收音并排队识别…（队列 ${microsoftPcmQueue.size} 段）"
          } else {
            "你：$base\n正在继续收音并排队识别…（队列 ${microsoftPcmQueue.size} 段）"
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
          runOnUiThread { transcriptView?.text = "微软识别失败：${t.message ?: t.javaClass.simpleName}；后续语音仍在继续排队…" }
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

  private fun containsSpeechEnergy(buffer: ByteArray, read: Int, threshold: Int = 520): Boolean {
    var peak = 0
    var i = 0
    val limit = read - 1
    while (i < limit) {
      val sample = (buffer[i].toInt() and 0xff) or (buffer[i + 1].toInt() shl 8)
      val value = kotlin.math.abs(sample.toShort().toInt())
      if (value > peak) peak = value
      if (peak >= threshold) return true
      i += 2
    }
    return false
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
    val conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
      requestMethod = "POST"
      connectTimeout = 12000
      readTimeout = 25000
      doOutput = true
      setRequestProperty("Ocp-Apim-Subscription-Key", cfg.optString("apiKey", ""))
      setRequestProperty("Content-Type", "audio/wav; codecs=audio/pcm; samplerate=16000")
      setRequestProperty("Accept", "application/json")
    }
    conn.outputStream.use { it.write(wavFromPcm(pcm, 16000)) }
    val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
    val resp = BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { it.readText() }
    if (conn.responseCode !in 200..299) throw IllegalStateException("HTTP ${conn.responseCode} ${resp.take(120)}")
    val obj = JSONObject(resp)
    val display = obj.optString("DisplayText", "")
    if (display.isNotBlank()) return display.trim()
    val nBest = obj.optJSONArray("NBest")
    return nBest?.optJSONObject(0)?.optString("Display", "")?.trim().orEmpty()
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
          .put("vad_eos", endpointingConfig().completeSilenceMs.toInt().coerceIn(700, 6000)),
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

  private fun registerAlarmPlaybackReceiver() {
    val filter = IntentFilter().apply {
      addAction(VoiceAlarmRingingService.ACTION_VOICE_PLAYBACK_START)
      addAction(VoiceAlarmRingingService.ACTION_VOICE_PLAYBACK_END)
    }
    if (Build.VERSION.SDK_INT >= 33) registerReceiver(alarmPlaybackReceiver, filter, RECEIVER_NOT_EXPORTED) else registerReceiver(alarmPlaybackReceiver, filter)
  }

  private fun handleAlarmVoicePlaybackStart() {
    // Do not call postponeAlarmVoiceReplay() here. This callback is emitted by
    // the alarm voice itself when playback starts; postponing here immediately
    // stops the current MediaPlayer/TTS and caused the opening reminder to be
    // cut off. Keep native recognition paused until playback-end arrives; cloud
    // STT may still collect text and will pass through echo filtering first.
    alarmVoicePlaying = true
    markExternalPlaybackStart()
    alarmPlaybackWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
    alarmPlaybackWatchdogRunnable = Runnable {
      alarmVoicePlaying = false
      alarmPlaybackWatchdogRunnable = null
      markPostPlaybackHandoff()
      listenAgain(40L)
    }
    speechHandler.postDelayed(alarmPlaybackWatchdogRunnable!!, estimatedAlarmVoiceWatchdogMs())
    suppressForAlarmPlayback(2500L)
  }

  private fun estimatedAlarmVoiceWatchdogMs(): Long {
    val textLen = try { JSONObject(payload).optString("text", "").length } catch (_: Throwable) { 0 }
    // Chinese TTS / custom voice prompts can be long.  The watchdog is only a
    // safety net for missing playback-end broadcasts, so prefer a generous bound
    // to avoid re-enabling recognition in the middle of a legitimate long prompt.
    return (12_000L + textLen * 320L).coerceIn(45_000L, 150_000L)
  }

  private fun suppressForAlarmPlayback(durationMs: Long) {
    suppressRecognitionUntil = maxOf(suppressRecognitionUntil, System.currentTimeMillis() + durationMs)
    try { recognizer?.cancel() } catch (_: Throwable) {}
    listening = false
    listeningStartedAt = 0L
    processSpeechRunnable?.let { speechHandler.removeCallbacks(it) }
    if (speechBuffer.isBlank()) {
      transcriptView?.text = "闹钟语音播报中，暂不把播报内容发送给 AI…"
    } else {
      transcriptView?.text = "闹钟语音播报中，已保留用户已说内容，播报结束后继续处理…\n你：$speechBuffer"
      scheduleBufferedSpeechProcessing(durationMs + 900)
    }
    scheduleListeningAfterSuppression()
  }

  private fun isAlarmPlaybackSuppressed(): Boolean = System.currentTimeMillis() < suppressRecognitionUntil

  private fun isPostPlaybackHandoffActive(): Boolean = System.currentTimeMillis() < postPlaybackHandoffUntil

  private fun markPostPlaybackHandoff(durationMs: Long = 2600L) {
    val now = System.currentTimeMillis()
    postPlaybackHandoffUntil = maxOf(postPlaybackHandoffUntil, now + durationMs)
    // Playback has already ended, so do not keep the old strong/suppression gates
    // alive for nearly a second.  A long gate right after TTS caused the user's
    // first words after the speaker stopped to be missed or classified as echo.
    strongPlaybackGateUntil = now + 180L
    suppressRecognitionUntil = minOf(maxOf(suppressRecognitionUntil, now + 80L), now + 160L)
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
    val now = System.currentTimeMillis()
    appPlaybackStartedAt = now
    strongPlaybackGateUntil = maxOf(strongPlaybackGateUntil, now + 1800L)
    suppressRecognitionUntil = maxOf(suppressRecognitionUntil, now + 1200L)
    try { recognizer?.cancel() } catch (_: Throwable) {}
    listening = false
    listeningStartedAt = 0L
  }

  private fun markAppTtsPlaybackStart() {
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
    markPostPlaybackHandoff()
    if (speechBuffer.isNotBlank()) {
      scheduleBufferedSpeechProcessing(350L)
      if (restart) runOnUiThread { listenAgain(40L) }
    } else if (processPendingAiUserSpeechIfReady()) {
      if (restart) runOnUiThread { listenAgain(40L) }
    } else if (restart) {
      runOnUiThread { listenAgain(40L) }
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
      alarmVoicePlaying = false
      alarmPlaybackWatchdogRunnable?.let { speechHandler.removeCallbacks(it) }
      alarmPlaybackWatchdogRunnable = null
      markPostPlaybackHandoff(1800L)
    }

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

    when (classifySpeechOrigin(text, finalChunk)) {
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
    transcriptView?.text = "正在听写：${speechBuffer}\n（实时草稿会动态修正；静音与文本稳定后自动发送给 AI）"
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

  private fun scheduleBufferedSpeechProcessing(delayMs: Long) {
    processSpeechRunnable?.let { speechHandler.removeCallbacks(it) }
    val endpoint = endpointingConfig()
    val actualDelay = delayMs.coerceIn(250L, endpoint.partialFallbackDelayMs)
    processSpeechRunnable = Runnable {
      val merged = speechBuffer.toString().trim()
      try { recognizer?.cancel() } catch (_: Throwable) {}
      listening = false
      listeningStartedAt = 0L
      if (merged.isBlank()) {
        resetUtteranceSessionIfIdle()
        listenAgain(300)
        return@Runnable
      }
      if (isLikelyPlaybackEcho(merged)) {
        speechBuffer.clear()
        resetUtteranceSessionIfIdle()
        transcriptView?.text = "已过滤播报回声，继续聆听…"
        listenAgain(500)
        return@Runnable
      }
      val urgent = isStopCommand(merged) || isSnoozeCommand(merged)
      recoverStuckPlaybackStateIfNeeded()
      if (isPlaybackActiveForSpeechGate() && !urgent) {
        transcriptView?.text = "正在听写：${speechBuffer}\n（播报尚未结束，继续暂存；播报结束并稳定后自动发送…）"
        scheduleBufferedSpeechProcessing(endpoint.finalCommitDelayMs)
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
    return isLikelyPlaybackEcho(text, listOf(alarmText, lastAssistantSpokenText))
  }

  private fun isLikelyPlaybackEcho(text: String): Boolean {
    val alarmText = try { JSONObject(payload).optString("text", "") } catch (_: Throwable) { "" }
    return isLikelyPlaybackEcho(text, listOf(alarmText, lastAssistantSpokenText))
  }

  private fun isLikelyPlaybackEcho(text: String, sources: List<String>): Boolean {
    val b = normalizeSpeechText(text)
    if (b.length < 3) return false
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
    if (aiBusy) return
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
    scheduleAiBusyWatchdog(requestSeq)
    transcriptView?.append("\nAI：正在思考…")
    Thread {
      val answer = try { callAi(aiConfig, userText) } catch (t: Throwable) { "AI 请求失败：${t.message ?: t.javaClass.simpleName}" }
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
    if (endpoint.isBlank() || apiKey.isBlank() || model.isBlank()) return "AI 配置不完整，请回到设置页重新保存闹钟。"
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
    OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body.toString()) }
    val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
    val resp = BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { it.readText() }
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
    try { unregisterReceiver(alarmPlaybackReceiver) } catch (_: Throwable) {}
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
