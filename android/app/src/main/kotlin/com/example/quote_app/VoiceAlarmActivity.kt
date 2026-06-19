package com.example.quote_app

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.content.Intent
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
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
          override fun onDone(utteranceId: String?) { speaking = false; runOnUiThread { listenAgain(500) } }
          @Deprecated("Deprecated in Java")
          override fun onError(utteranceId: String?) { speaking = false; runOnUiThread { listenAgain(500) } }
          override fun onError(utteranceId: String?, errorCode: Int) { speaking = false; runOnUiThread { listenAgain(500) } }
        })
      }
    }
    setContentView(buildContent())
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
    if (!SpeechRecognizer.isRecognitionAvailable(this)) {
      transcriptView?.text = "当前设备没有可用语音识别服务，可使用屏幕按钮。"
      return
    }
    recognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
      setRecognitionListener(object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) { listening = true; transcriptView?.append("\n正在聆听…") }
        override fun onResults(results: Bundle?) {
          listening = false
          handleSpeech(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty())
        }
        override fun onPartialResults(partialResults: Bundle?) { }
        override fun onError(error: Int) {
          listening = false
          if (!speaking && !aiBusy) listenAgain(700)
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

  private fun listenAgain(delayMs: Long = 0L) {
    if (destroyed || speaking || aiBusy || listening) return
    transcriptView?.postDelayed({
      if (destroyed || speaking || aiBusy || listening) return@postDelayed
      val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
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

  private fun handleSpeech(rawText: String) {
    val text = rawText.trim()
    if (text.isBlank()) { listenAgain(300); return }
    transcriptView?.text = "你：$text"
    when {
      isStopCommand(text) -> {
        speak("好的，已关闭闹钟。", "alarm_stop", restart = false)
        VoiceAlarmRingingService.stop(this)
        transcriptView?.postDelayed({ finishAndRemoveTask() }, 450)
      }
      isSnoozeCommand(text) -> {
        speak("好的，五分钟后再次提醒。", "alarm_snooze", restart = false)
        VoiceAlarmScheduler.snooze(this, payload, 5)
        VoiceAlarmRingingService.stop(this)
        transcriptView?.postDelayed({ finishAndRemoveTask() }, 450)
      }
      isWakeCommand(text) -> {
        aiAwake = true
        val query = stripWakeWords(text).ifBlank { "你好" }
        askAi(query)
      }
      aiAwake -> askAi(text)
      else -> {
        transcriptView?.append("\n提示：请先说“小名小名”或“你好AI”唤醒 AI；也可以直接说“关闭闹钟 / 延迟五分钟”。")
        listenAgain(500)
      }
    }
  }

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
    try { recognizer?.cancel() } catch (_: Throwable) {}
    listening = false
    speaking = true
    val params = Bundle().apply { putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId) }
    val result = tts?.speak(text.take(600), TextToSpeech.QUEUE_FLUSH, params, utteranceId)
    if (result == null || result == TextToSpeech.ERROR || !restart) {
      speaking = false
      if (restart) listenAgain(500)
    }
  }

  private fun callAi(cfg: JSONObject, userText: String): String {
    val provider = cfg.optString("provider", "deepseek")
    val endpoint = cfg.optString("endpoint", "")
    val apiKey = cfg.optString("apiKey", "")
    val model = cfg.optString("model", "")
    if (endpoint.isBlank() || apiKey.isBlank() || model.isBlank()) return "AI 配置不完整，请回到设置页重新保存闹钟。"
    val messages = JSONArray().apply {
      put(JSONObject().put("role", "system").put("content", "你是一个正在全屏闹钟界面中陪伴用户的中文语音 AI。回答要简短、自然、适合朗读，通常不超过80字。不要说你无法控制闹钟；用户可说关闭闹钟或延迟五分钟。"))
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
