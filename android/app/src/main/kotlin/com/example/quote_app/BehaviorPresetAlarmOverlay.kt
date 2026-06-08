package com.example.quote_app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Full-screen overlay fallback for alarm forms.
 *
 * New Android/OEM builds can block background Activity launches even when an alarm is ringing.  When the user grants
 * “display over other apps”, this overlay is drawn by the foreground ringing service and therefore does not depend on
 * background Activity start permission.  The overlay is intentionally simple and includes an “open full form” button
 * for the complete Activity-based form.
 */
object BehaviorPresetAlarmOverlay {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val showing = AtomicBoolean(false)
  @Volatile private var rootView: View? = null
  @Volatile private var currentPayload: String? = null

  @JvmStatic
  fun canDraw(ctx: Context): Boolean {
    return try {
      if (Build.VERSION.SDK_INT >= 23) Settings.canDrawOverlays(ctx.applicationContext) else true
    } catch (_: Throwable) { false }
  }

  @JvmStatic
  fun show(ctx: Context, id: Int, payload: String?) {
    val app = ctx.applicationContext
    if (!canDraw(app)) {
      try { com.example.quote_app.data.DbRepo.log(app, null, "[BehaviorPresetAlarm] overlay skipped: permission missing") } catch (_: Throwable) {}
      return
    }
    mainHandler.post {
      try {
        dismissNow(app)
        val normalized = try { BehaviorPresetAlarmScheduler.normalizePayloadForFire(app, payload) } catch (_: Throwable) { payload ?: "{}" }
        currentPayload = normalized
        showing.set(true)
        BehaviorPresetAlarmUiGate.markVisible(app, normalized)
        val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val view = buildView(app, id, normalized)
        rootView = view
        val lp = WindowManager.LayoutParams(
          WindowManager.LayoutParams.MATCH_PARENT,
          WindowManager.LayoutParams.MATCH_PARENT,
          WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
          WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
          PixelFormat.TRANSLUCENT
        ).apply {
          gravity = Gravity.CENTER
          if (Build.VERSION.SDK_INT >= 28) layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        wm.addView(view, lp)
        try { com.example.quote_app.data.DbRepo.log(app, null, "[BehaviorPresetAlarm] overlay shown id=$id") } catch (_: Throwable) {}
      } catch (t: Throwable) {
        showing.set(false)
        try { com.example.quote_app.data.DbRepo.log(app, null, "[BehaviorPresetAlarm] overlay show failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
      }
    }
  }


  private fun dismissNow(app: Context) {
    val view = rootView ?: run {
      showing.set(false)
      return
    }
    rootView = null
    showing.set(false)
    val oldPayload = currentPayload
    currentPayload = null
    try { (app.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(view) } catch (_: Throwable) {}
    try { BehaviorPresetAlarmUiGate.clearVisible(app, oldPayload) } catch (_: Throwable) {}
  }

  @JvmStatic
  fun dismiss(ctx: Context) {
    val app = ctx.applicationContext
    mainHandler.post { dismissNow(app) }
  }

  @JvmStatic
  fun isShowing(): Boolean = showing.get()

  private fun buildView(ctx: Context, id: Int, rawPayload: String): View {
    val payload = try { JSONObject(rawPayload) } catch (_: Throwable) { JSONObject() }
    val dailyReview = payload.optString("type", "") == "behavior_preset_daily_review" || payload.optString("templateKey", "") == "preset_daily_review"
    val setupRequired = !dailyReview && (payload.optBoolean("setupRequired", false) || payload.optString("type") == "behavior_preset_setup_alarm")
    val presets = payload.optJSONArray("presets") ?: JSONArray()

    val outer = LinearLayout(ctx).apply {
      orientation = LinearLayout.VERTICAL
      gravity = Gravity.CENTER
      setBackgroundColor(Color.argb(210, 8, 13, 26))
      setPadding(dp(ctx, 18), dp(ctx, 28), dp(ctx, 18), dp(ctx, 28))
    }

    val panel = LinearLayout(ctx).apply {
      orientation = LinearLayout.VERTICAL
      setPadding(dp(ctx, 20), dp(ctx, 20), dp(ctx, 20), dp(ctx, 18))
      background = roundBg(Color.WHITE, dp(ctx, 24).toFloat())
    }

    panel.addView(TextView(ctx).apply {
      text = if (dailyReview) "每日预设行为复盘" else if (setupRequired) "请先完成行为预设" else if (presets.length() > 1) "预设提醒（${presets.length()}项）" else "预设提醒"
      setTextColor(Color.rgb(15, 23, 42))
      textSize = 24f
      typeface = Typeface.DEFAULT_BOLD
    })

    panel.addView(TextView(ctx).apply {
      text = if (dailyReview) {
        "请登记今天所有预设行为的完成/未完成情况。未完成需填写原因，也可转入明天。"
      } else if (setupRequired) {
        "这个闹钟用于督促你先做好当天行为预设。点击下方按钮打开完整表单完成设置。"
      } else {
        "这是该闹钟时刻对应的预设行为汇总。你可以直接确认已收到，或打开完整表单查看。"
      }
      setTextColor(Color.rgb(71, 85, 105))
      textSize = 15f
      setPadding(0, dp(ctx, 8), 0, dp(ctx, 12))
    })

    val list = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
    if (presets.length() <= 0) {
      val fallbackTitle = if (dailyReview) "今天暂无预设行为" else if (setupRequired) "尚未设置当天预设" else "今天的预设行为"
      val fallbackBody = if (dailyReview) "可打开复盘页，直接进入明天预设行为设置。" else payload.optString("category", "请打开完整表单继续处理")
      list.addView(card(ctx, payload.optString("presetName", fallbackTitle), fallbackBody))
    } else {
      for (i in 0 until presets.length()) {
        val p = presets.optJSONObject(i) ?: continue
        list.addView(card(ctx, "${i + 1}. ${p.optString("presetName", p.optString("name", "预设行为"))}", "${p.optString("category", "未分类")} · ${planText(p)}"))
      }
    }
    panel.addView(ScrollView(ctx).apply {
      addView(list)
      layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
    })

    panel.addView(button(ctx, if (dailyReview) "打开复盘登记" else if (setupRequired) "打开完整表单完成预设" else "打开完整表单", {
      openForm(ctx, rawPayload)
    }))
    panel.addView(button(ctx, if (setupRequired || dailyReview) "5分钟后再提醒" else "稍后5分钟再提醒", {
      snooze(ctx, id, rawPayload)
      dismiss(ctx)
      BehaviorPresetAlarmRingingService.stopRinging(ctx)
    }, filled = false))
    if (!setupRequired && !dailyReview) {
      panel.addView(button(ctx, "我已收到，停止闹钟", {
        dismiss(ctx)
        BehaviorPresetAlarmRingingService.stopRinging(ctx)
      }, filled = false))
    }

    outer.addView(panel, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT))
    return outer
  }

  private fun openForm(ctx: Context, payload: String) {
    try {
      BehaviorPresetAlarmUiGate.markVisible(ctx, payload)
      val intent = Intent(ctx.applicationContext, BehaviorPresetAlarmFormActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        putExtra("payload", payload)
        putExtra("from_preset_alarm", true)
        putExtra("alarm_fire", true)
        putExtra("ring_service_active", true)
        putExtra("from_overlay", true)
      }
      ctx.applicationContext.startActivity(intent)
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorPresetAlarm] overlay open form failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
  }

  private fun snooze(ctx: Context, id: Int, rawPayload: String) {
    try {
      val obj = JSONObject(rawPayload)
      obj.put("alarmId", id + 43000)
      obj.put("snoozed", true)
      val triggerAt = System.currentTimeMillis() + 5 * 60 * 1000L
      NativeSchedulerK.scheduleAlarmClockAt(ctx.applicationContext, id + 43000, triggerAt, obj.toString())
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorPresetAlarm] overlay snooze failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
  }

  private fun card(ctx: Context, title: String, body: String): View {
    return LinearLayout(ctx).apply {
      orientation = LinearLayout.VERTICAL
      setPadding(dp(ctx, 12), dp(ctx, 10), dp(ctx, 12), dp(ctx, 10))
      background = roundBg(Color.rgb(248, 250, 252), dp(ctx, 16).toFloat(), Color.rgb(226, 232, 240))
      val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
      lp.setMargins(0, 0, 0, dp(ctx, 8))
      layoutParams = lp
      addView(TextView(ctx).apply {
        text = title
        setTextColor(Color.rgb(15, 23, 42))
        textSize = 17f
        typeface = Typeface.DEFAULT_BOLD
      })
      addView(TextView(ctx).apply {
        text = body
        setTextColor(Color.rgb(71, 85, 105))
        textSize = 14f
        setPadding(0, dp(ctx, 3), 0, 0)
      })
    }
  }

  private fun button(ctx: Context, textValue: String, onClick: () -> Unit, filled: Boolean = true): View {
    return Button(ctx).apply {
      text = textValue
      textSize = 16f
      isAllCaps = false
      setTextColor(if (filled) Color.WHITE else Color.rgb(37, 99, 235))
      background = roundBg(if (filled) Color.rgb(37, 99, 235) else Color.TRANSPARENT, dp(ctx, 18).toFloat(), if (filled) Color.rgb(37, 99, 235) else Color.rgb(191, 219, 254))
      setOnClickListener { onClick() }
      val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(ctx, 50))
      lp.setMargins(0, dp(ctx, 10), 0, 0)
      layoutParams = lp
    }
  }

  private fun planText(obj: JSONObject): String {
    val target = obj.opt("targetValue")
    val unit = obj.optString("unit", "次")
    val dur = obj.optInt("defaultDurationMin", 0)
    val bits = ArrayList<String>()
    if (target != null && target.toString() != "null" && target.toString().isNotBlank()) bits.add("目标 $target$unit")
    if (dur > 0) bits.add("$dur 分钟")
    return if (bits.isEmpty()) "请查看/确认" else bits.joinToString(" · ")
  }

  private fun dp(ctx: Context, value: Int): Int = (value * ctx.resources.displayMetrics.density + 0.5f).toInt()

  private fun roundBg(color: Int, radius: Float, strokeColor: Int? = null): GradientDrawable {
    return GradientDrawable().apply {
      setColor(color)
      cornerRadius = radius
      if (strokeColor != null) setStroke(1, strokeColor)
    }
  }
}
