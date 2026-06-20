package com.example.quote_app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
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
  private var transcriptView: TextView? = null
  @Volatile private var destroyed = false
  @Volatile private var aiAwake = false
  @Volatile private var listening = false
  @Volatile private var speaking = false
  @Volatile private var aiBusy = false
  private val conversation = mutableListOf<Pair<String, String>>()
  private val ttsRestartByUtterance = mutableMapOf<String, Boolean>()
  private val speechHandler = Handler(Looper.getMainLooper())
  private val speechBuffer = StringBuilder()
  private var processSpeechRunnable: Runnable? = null
  private var resumeListeningRunnable: Runnable? = null
  @Volatile private var suppressRecognitionUntil = 0L
  @Volatile private var cloudSttActive = false
  private var cloudSttThread: Thread? = null
  private var iflytekSttClient: OkHttpClient? = null
  private var lastReplayPostponeSentAt = 0L
  private var lastReplayPostponeUntil = 0L
  private val alarmPlaybackReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      when (intent?.action) {
        VoiceAlarmRingingService.ACTION_VOICE_PLAYBACK_START -> suppressForAlarmPlayback(30_000L)
        VoiceAlarmRingingService.ACTION_VOICE_PLAYBACK_END -> {
          suppressRecognitionUntil = System.currentTimeMillis() + 900L
          scheduleListeningAfterSuppression()
        }
      }
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    payload = intent?.getStringExtra("payload") ?: "{}"
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
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    tts = TextToSpeech(this) { status ->
      if (status == TextToSpeech.SUCCESS) {
        tts?.language = Locale.CHINA
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
          override fun onStart(utteranceId: String?) { speaking = true }
          override fun onDone(utteranceId: String?) { handleTtsFinished(utteranceId, success = true) }
          @Deprecated("Deprecated in Java")
          override fun onError(utteranceId: String?) { handleTtsFinished(utteranceId, success = false) }
          override fun onError(utteranceId: String?, errorCode: Int) { handleTtsFinished(utteranceId, success = false) }
        })
      }
    }
    setContentView(buildContent())
    registerAlarmPlaybackReceiver()
    startVoiceAssistant()
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

  private fun startVoiceAssistant() {
    val sttConfig = try { JSONObject(payload).optJSONObject("sttConfig") } catch (_: Throwable) { null }
    val selectedSttProvider = try { JSONObject(payload).optString("sttProvider", "native") } catch (_: Throwable) { "native" }
    if (selectedSttProvider == "microsoft") {
      val microsoftConfig = sttConfig?.optJSONObject("microsoft")
      if (microsoftConfig != null && microsoftConfig.optString("apiKey", "").isNotBlank()) {
        startMicrosoftCloudStt(microsoftConfig)
        return
      }
      transcriptView?.text = "已选择微软语音识别，但缺少 Microsoft Speech API Key；暂时回退到系统识别。"
    } else if (selectedSttProvider == "iflytek") {
      val iflytekConfig = sttConfig?.optJSONObject("iflytek")
      if (iflytekConfig != null &&
        iflytekConfig.optString("appId", "").isNotBlank() &&
        iflytekConfig.optString("apiKey", "").isNotBlank() &&
        iflytekConfig.optString("apiSecret", "").isNotBlank()
      ) {
        startIflytekCloudStt(iflytekConfig)
        return
      }
      transcriptView?.text = "已选择讯飞识别，但缺少 AppID/APIKey/APISecret；暂时回退到系统识别。"
    }
    if (!SpeechRecognizer.isRecognitionAvailable(this)) {
      transcriptView?.text = "当前设备没有可用语音识别服务，可使用屏幕按钮。"
      return
    }
    recognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
      setRecognitionListener(object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) { listening = true; updateListeningStatus() }
        override fun onResults(results: Bundle?) {
          listening = false
          onSpeechChunk(
            results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty(),
            finalChunk = true,
          )
          // Android SpeechRecognizer is utterance-based rather than a true
          // continuous stream. Restart immediately after each final segment
          // while the debounce timer keeps collecting subsequent segments.
          if (!speaking && !aiBusy) listenAgain(150)
        }
        override fun onPartialResults(partialResults: Bundle?) {
          onSpeechChunk(
            partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty(),
            finalChunk = false,
          )
        }
        override fun onError(error: Int) {
          listening = false
          if (speechBuffer.isNotBlank()) {
            scheduleBufferedSpeechProcessing(2200)
            if (!speaking && !aiBusy) listenAgain(350)
          }
          else if (!speaking && !aiBusy) listenAgain(700)
        }
        override fun onBeginningOfSpeech() {}
        override fun onEndOfSpeech() { listening = false }
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
      })
    }
    listenAgain(300)
  }

  private fun startMicrosoftCloudStt(cfg: JSONObject) {
    if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      transcriptView?.text = "微软云识别需要麦克风权限；请返回闹钟设置页授权后重新保存。"
      return
    }
    cloudSttActive = true
    transcriptView?.text = "微软云识别已启用，正在持续聆听…"
    cloudSttThread = Thread {
      while (!destroyed && cloudSttActive) {
        if (speaking || aiBusy || isAlarmPlaybackSuppressed()) {
          Thread.sleep(180)
          continue
        }
        postponeAlarmVoiceReplay(20_000L)
        val pcm = recordPcmChunk(12000)
        if (pcm.isEmpty() || destroyed || !cloudSttActive || speaking || aiBusy || isAlarmPlaybackSuppressed()) continue
        val text = try { recognizeWithMicrosoft(cfg, pcm) } catch (t: Throwable) {
          runOnUiThread { transcriptView?.text = "微软识别失败：${t.message ?: t.javaClass.simpleName}；正在重试…" }
          ""
        }
        if (text.isNotBlank()) runOnUiThread { onSpeechChunk(text, finalChunk = true) }
      }
    }.apply {
      name = "voice-alarm-microsoft-stt"
      isDaemon = true
      start()
    }
  }

  private fun startIflytekCloudStt(cfg: JSONObject) {
    if (Build.VERSION.SDK_INT >= 23 && checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      transcriptView?.text = "讯飞云识别需要麦克风权限；请返回闹钟设置页授权后重新保存。"
      return
    }
    cloudSttActive = true
    transcriptView?.text = "讯飞流式识别已启用，正在持续聆听…"
    cloudSttThread = Thread {
      while (!destroyed && cloudSttActive) {
        if (speaking || aiBusy || isAlarmPlaybackSuppressed()) {
          Thread.sleep(180)
          continue
        }
        postponeAlarmVoiceReplay(22_000L)
        val text = try { recognizeWithIflytekStreaming(cfg, 15000) } catch (t: Throwable) {
          runOnUiThread { transcriptView?.text = "讯飞识别失败：${t.message ?: t.javaClass.simpleName}；正在重试…" }
          ""
        }
        if (text.isNotBlank() && !destroyed && cloudSttActive && !speaking && !aiBusy && !isAlarmPlaybackSuppressed()) {
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
    val audioRecord = AudioRecord(
      MediaRecorder.AudioSource.VOICE_RECOGNITION,
      sampleRate,
      AudioFormat.CHANNEL_IN_MONO,
      AudioFormat.ENCODING_PCM_16BIT,
      minBuffer * 2,
    )
    val out = ByteArrayOutputStream()
    val buffer = ByteArray(minBuffer)
    try {
      audioRecord.startRecording()
      val deadline = System.currentTimeMillis() + durationMs
      while (!destroyed && cloudSttActive && !speaking && !aiBusy && !isAlarmPlaybackSuppressed() && System.currentTimeMillis() < deadline) {
        val read = audioRecord.read(buffer, 0, buffer.size)
        if (read > 0) out.write(buffer, 0, read)
      }
    } finally {
      try { audioRecord.stop() } catch (_: Throwable) {}
      try { audioRecord.release() } catch (_: Throwable) {}
    }
    return out.toByteArray()
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
    val minBuffer = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
    if (minBuffer <= 0) return ""
    val chunkSize = 1280 // 40ms at 16kHz 16-bit mono; matches iFlytek IAT streaming recommendations.
    val audioRecord = AudioRecord(
      MediaRecorder.AudioSource.VOICE_RECOGNITION,
      sampleRate,
      AudioFormat.CHANNEL_IN_MONO,
      AudioFormat.ENCODING_PCM_16BIT,
      maxOf(minBuffer * 2, chunkSize * 2),
    )
    val opened = CountDownLatch(1)
    val closed = CountDownLatch(1)
    val text = StringBuilder()
    val iflytekSegments = sortedMapOf<Int, String>()
    var webSocket: WebSocket? = null
    val client = getIflytekSttClient()
    val listener = object : WebSocketListener() {
      override fun onOpen(webSocket: WebSocket, response: Response) {
        opened.countDown()
      }

      override fun onMessage(webSocket: WebSocket, message: String) {
        val piece = parseIflytekResult(message)
        if (piece.text.isNotBlank()) {
          synchronized(text) {
            if (piece.replaceStart != null && piece.replaceEnd != null) {
              for (sn in piece.replaceStart..piece.replaceEnd) iflytekSegments.remove(sn)
            }
            if (piece.sn >= 0) {
              iflytekSegments[piece.sn] = piece.text
              text.clear()
              iflytekSegments.values.forEach { text.append(it) }
            } else if (!text.endsWith(piece.text)) {
              text.append(piece.text)
            }
          }
          runOnUiThread { transcriptView?.text = "你：$text\n（讯飞流式识别中，继续说完即可…）" }
        }
        val code = try { JSONObject(message).optInt("code", 0) } catch (_: Throwable) { 0 }
        if (code != 0) closed.countDown()
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
      audioRecord.startRecording()
      val deadline = System.currentTimeMillis() + durationMs
      var status = 0
      val buffer = ByteArray(chunkSize)
      while (!destroyed && cloudSttActive && !speaking && !aiBusy && !isAlarmPlaybackSuppressed() && System.currentTimeMillis() < deadline) {
        val read = audioRecord.read(buffer, 0, buffer.size)
        if (read > 0) {
          webSocket.send(iflytekFrame(cfg, status, buffer.copyOf(read)))
          status = 1
          Thread.sleep(35)
        }
      }
      webSocket.send(iflytekFrame(cfg, 2, ByteArray(0)))
      closed.await(4, TimeUnit.SECONDS)
    } finally {
      try { audioRecord.stop() } catch (_: Throwable) {}
      try { audioRecord.release() } catch (_: Throwable) {}
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
          .put("dwa", "wpgs"),
      )
    }
    root.put("data", data)
    return root.toString()
  }

  private data class IflytekRecognitionPiece(
    val sn: Int,
    val text: String,
    val replaceStart: Int?,
    val replaceEnd: Int?,
  )

  private fun parseIflytekResult(message: String): IflytekRecognitionPiece {
    val empty = IflytekRecognitionPiece(-1, "", null, null)
    val result = try { JSONObject(message).optJSONObject("data")?.optJSONObject("result") } catch (_: Throwable) { null } ?: return empty
    val words = result.optJSONArray("ws") ?: return IflytekRecognitionPiece(result.optInt("sn", -1), "", null, null)
    val out = StringBuilder()
    for (i in 0 until words.length()) {
      val candidates = words.optJSONObject(i)?.optJSONArray("cw") ?: continue
      for (j in 0 until candidates.length()) {
        val word = candidates.optJSONObject(j)?.optString("w", "") ?: ""
        if (word.isNotBlank()) out.append(word)
      }
    }
    val range = result.optJSONArray("rg")
    return IflytekRecognitionPiece(
      sn = result.optInt("sn", -1),
      text = out.toString(),
      replaceStart = if (result.optString("pgs", "") == "rpl" && range != null && range.length() >= 2) range.optInt(0) else null,
      replaceEnd = if (result.optString("pgs", "") == "rpl" && range != null && range.length() >= 2) range.optInt(1) else null,
    )
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
    if (destroyed || speaking || aiBusy || listening) return
    if (isAlarmPlaybackSuppressed()) {
      scheduleListeningAfterSuppression()
      return
    }
    transcriptView?.postDelayed({
      if (destroyed || speaking || aiBusy || listening) return@postDelayed
      if (isAlarmPlaybackSuppressed()) {
        scheduleListeningAfterSuppression()
        return@postDelayed
      }
      val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L)
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L)
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 6000L)
        putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
      }
      try {
        recognizer?.cancel()
        recognizer?.startListening(i)
        listening = true
      } catch (_: Throwable) {
        listening = false
      }
    }, delayMs)
  }

  private fun scheduleListeningAfterSuppression(extraDelayMs: Long = 180L) {
    if (destroyed || speaking || aiBusy || listening) return
    resumeListeningRunnable?.let { speechHandler.removeCallbacks(it) }
    val delayMs = (suppressRecognitionUntil - System.currentTimeMillis() + extraDelayMs).coerceAtLeast(extraDelayMs)
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

  private fun suppressForAlarmPlayback(durationMs: Long) {
    suppressRecognitionUntil = maxOf(suppressRecognitionUntil, System.currentTimeMillis() + durationMs)
    try { recognizer?.cancel() } catch (_: Throwable) {}
    listening = false
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

  private fun onSpeechChunk(chunk: String, finalChunk: Boolean) {
    val text = chunk.trim()
    if (text.isBlank()) return
    postponeAlarmVoiceReplay(18_000L)
    if (isAlarmPlaybackSuppressed()) {
      if (isLikelyAlarmPlayback(text)) {
        suppressForAlarmPlayback(2000L)
        return
      }
      appendSpeechChunk(text)
      transcriptView?.text = "你：${speechBuffer}\n（闹钟播报中，已暂存用户语音，播报结束后发送…）"
      val delayMs = (suppressRecognitionUntil - System.currentTimeMillis() + 900L).coerceAtLeast(900L)
      scheduleBufferedSpeechProcessing(delayMs)
      return
    }
    if (isLikelyAlarmPlayback(text)) {
      suppressForAlarmPlayback(2000L)
      return
    }
    appendSpeechChunk(text)
    transcriptView?.text = "你：${speechBuffer}\n（正在识别，继续说完即可…）"
    val shouldHandleQuickly = finalChunk && (isStopCommand(text) || isSnoozeCommand(text))
    scheduleBufferedSpeechProcessing(
      when {
        shouldHandleQuickly -> 250
        cloudSttActive && finalChunk -> 6500
        finalChunk -> 2800
        else -> 4200
      },
    )
  }

  private fun appendSpeechChunk(text: String) {
    val current = speechBuffer.toString()
    if (current.contains(text)) return
    if (text.contains(current) && current.isNotBlank()) {
      speechBuffer.clear()
      speechBuffer.append(text)
      return
    }
    if (speechBuffer.isNotBlank()) speechBuffer.append(' ')
    speechBuffer.append(text)
  }

  private fun scheduleBufferedSpeechProcessing(delayMs: Long) {
    processSpeechRunnable?.let { speechHandler.removeCallbacks(it) }
    processSpeechRunnable = Runnable {
      val merged = speechBuffer.toString().trim()
      speechBuffer.clear()
      try { recognizer?.cancel() } catch (_: Throwable) {}
      listening = false
      if (merged.isNotBlank()) handleSpeech(merged) else listenAgain(300)
    }
    speechHandler.postDelayed(processSpeechRunnable!!, delayMs)
  }


  private fun handleSpeech(rawText: String) {
    val text = rawText.trim()
    if (text.isBlank()) { listenAgain(300); return }
    postponeAlarmVoiceReplay(20_000L)
    if (isLikelyAlarmPlayback(text)) {
      transcriptView?.text = "已忽略闹钟播报回声，继续聆听用户语音…"
      listenAgain(500)
      return
    }
    transcriptView?.text = "你：$text"
    when {
      isStopCommand(text) -> {
        speak("好的，已关闭闹钟。", "alarm_stop", restart = false)
        VoiceAlarmRingingService.stop(this)
        transcriptView?.postDelayed({ finishAndRemoveTask() }, 5000)
      }
      isSnoozeCommand(text) -> {
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
    val a = normalizeSpeechText(alarmText)
    val b = normalizeSpeechText(text)
    if (a.length < 8 || b.length < 8) return false
    if (a.contains(b) || b.contains(a.take(24))) return true
    val common = b.windowed(2, 1).count { a.contains(it) }
    return common >= (b.length / 2).coerceAtLeast(8)
  }

  private fun normalizeSpeechText(value: String): String = value.lowercase(Locale.ROOT).filter { it.isLetterOrDigit() || it in '\u4e00'..'\u9fff' }

  private fun isStopCommand(text: String): Boolean = listOf("关闭", "停止", "关掉", "结束闹钟", "停掉闹钟", "不响了").any { text.contains(it) }

  private fun isSnoozeCommand(text: String): Boolean =
    (listOf("延迟", "稍后", "等会", "再响", "贪睡", "小睡").any { text.contains(it) } &&
      listOf("五分钟", "5分钟", "五 分钟", "5 分钟", "五分", "5分").any { text.contains(it) }) ||
      text.contains("延迟五") || text.contains("延迟5")

  private fun isWakeCommand(text: String): Boolean = listOf("小名小名", "你好AI", "你好ai", "闹钟助手", "AI助手", "ai助手", "小名", "助手").any { text.contains(it) }

  private fun stripWakeWords(text: String): String {
    var out = text
    for (w in listOf("小名小名", "你好AI", "你好ai", "闹钟助手", "AI助手", "ai助手", "小名", "助手")) out = out.replace(w, "")
    return out.trim(' ', '，', ',', '。', '：', ':')
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
    transcriptView?.append("\nAI：正在思考…")
    Thread {
      val answer = try { callAi(aiConfig, userText) } catch (t: Throwable) { "AI 请求失败：${t.message ?: t.javaClass.simpleName}" }
      runOnUiThread {
        aiBusy = false
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
    postponeAlarmVoiceReplay(45_000L)
    try { recognizer?.cancel() } catch (_: Throwable) {}
    listening = false
    speaking = true
    synchronized(ttsRestartByUtterance) { ttsRestartByUtterance[utteranceId] = restart }
    val params = Bundle().apply { putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId) }
    val result = tts?.speak(text.take(600), TextToSpeech.QUEUE_FLUSH, params, utteranceId)
    if (result == null || result == TextToSpeech.ERROR) {
      synchronized(ttsRestartByUtterance) { ttsRestartByUtterance.remove(utteranceId) }
      speaking = false
      if (restart) listenAgain(500)
    }
  }

  private fun handleTtsFinished(utteranceId: String?, success: Boolean) {
    val restart = synchronized(ttsRestartByUtterance) {
      if (utteranceId == null) true else ttsRestartByUtterance.remove(utteranceId) ?: true
    }
    speaking = false
    if (!success) postponeAlarmVoiceReplay(3000L)
    if (restart) runOnUiThread { listenAgain(500) }
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
    cloudSttActive = false
    try { cloudSttThread?.interrupt() } catch (_: Throwable) {}
    try { iflytekSttClient?.dispatcher?.executorService?.shutdown() } catch (_: Throwable) {}
    try { iflytekSttClient?.connectionPool?.evictAll() } catch (_: Throwable) {}
    iflytekSttClient = null
    synchronized(ttsRestartByUtterance) { ttsRestartByUtterance.clear() }
    processSpeechRunnable?.let { speechHandler.removeCallbacks(it) }
    resumeListeningRunnable?.let { speechHandler.removeCallbacks(it) }
    try { unregisterReceiver(alarmPlaybackReceiver) } catch (_: Throwable) {}
    try { recognizer?.destroy() } catch (_: Throwable) {}
    try { tts?.shutdown() } catch (_: Throwable) {}
    recognizer = null
    tts = null
    super.onDestroy()
  }

  override fun onBackPressed() {
    // 防止误触返回键静默关闭界面；必须明确选择稍后提醒或停止闹钟。
  }
}
