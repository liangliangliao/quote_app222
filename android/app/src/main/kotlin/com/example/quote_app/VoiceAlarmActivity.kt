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
import java.util.Locale
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.io.File

class VoiceAlarmActivity : Activity() {
  private var payload = "{}"
  private var recognizer: SpeechRecognizer? = null
  private var tts: TextToSpeech? = null
  private var transcriptView: TextView? = null

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
    tts = TextToSpeech(this) { status -> if (status == TextToSpeech.SUCCESS) tts?.language = Locale.CHINA }
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
      text = "可直接说“小名小名/你好AI”开始交流；说“关闭闹钟”停止；说“延迟五分钟”稍后提醒。"
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
        override fun onReadyForSpeech(params: Bundle?) { transcriptView?.append("\n正在聆听…") }
        override fun onResults(results: Bundle?) { handleSpeech(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()) }
        override fun onPartialResults(partialResults: Bundle?) { }
        override fun onError(error: Int) { transcriptView?.postDelayed({ listenAgain() }, 700) }
        override fun onBeginningOfSpeech() {}
        override fun onEndOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
      })
    }
    listenAgain()
  }

  private fun listenAgain() {
    val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
      putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
      putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
      putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
    }
    try { recognizer?.startListening(i) } catch (_: Throwable) {}
  }

  private fun handleSpeech(text: String) {
    if (text.isBlank()) { listenAgain(); return }
    transcriptView?.text = "你：$text"
    when {
      text.contains("关闭") || text.contains("停止") || text.contains("关掉") -> {
        tts?.speak("好的，已关闭闹钟。", TextToSpeech.QUEUE_FLUSH, null, "alarm_stop")
        VoiceAlarmRingingService.stop(this)
        finishAndRemoveTask()
      }
      text.contains("延迟") || text.contains("稍后") || text.contains("五分钟") || text.contains("5分钟") -> {
        tts?.speak("好的，五分钟后再次提醒。", TextToSpeech.QUEUE_FLUSH, null, "alarm_snooze")
        VoiceAlarmScheduler.snooze(this, payload, 5)
        VoiceAlarmRingingService.stop(this)
        finishAndRemoveTask()
      }
      else -> {
        val answer = "我听到了：$text。闹钟全屏期间我会持续聆听，你可以继续说话，也可以说关闭闹钟或延迟五分钟。"
        transcriptView?.append("\nAI：$answer")
        tts?.speak(answer, TextToSpeech.QUEUE_FLUSH, null, "alarm_ai")
        transcriptView?.postDelayed({ listenAgain() }, 1200)
      }
    }
  }

  override fun onDestroy() {
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
