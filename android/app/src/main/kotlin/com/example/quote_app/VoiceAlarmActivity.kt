package com.example.quote_app

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
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
    setContentView(buildContent())
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

  override fun onBackPressed() {
    // 防止误触返回键静默关闭界面；必须明确选择稍后提醒或停止闹钟。
  }
}
