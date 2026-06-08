package com.example.quote_app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.app.NotificationManager
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.text.InputType
import android.view.Gravity
import android.view.Window
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * V33：预设行为闹钟的语义调整。
 *
 * 闹钟不是让用户“立刻完成预设行为”，而是：
 * 1）当天没有预设行为时，强制督促用户先完成行为预设；
 * 2）当天已有预设行为时，只要求用户确认已收到/查看预设提醒。
 *
 * 如果当天没有预设行为而用户不填写预设，不能直接跳过；关闭或稍后会 5 分钟后再次提醒。
 */
class BehaviorPresetAlarmFormActivity : Activity() {
  private var payload = JSONObject()
  private var setupRequiredMode = false
  private lateinit var presetNameInput: EditText
  private lateinit var presetCategoryInput: EditText
  private lateinit var presetDurationInput: EditText
  private lateinit var presetNotesInput: EditText
  private var mediaPlayer: MediaPlayer? = null
  private var ringtone: Ringtone? = null
  private var vibrator: Vibrator? = null
  private var alarmFireIntent: Boolean = false
  private var ringServiceActiveForThisFire: Boolean = false
  private var nextAlarmScheduledForThisFire: Boolean = false
  private var originalAlarmStreamVolume: Int? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    requestWindowFeature(Window.FEATURE_NO_TITLE)
    super.onCreate(savedInstanceState)
    configureAlarmWindow()
    loadPayloadFromIntent(intent)
    try { BehaviorPresetAlarmOverlay.dismiss(applicationContext) } catch (_: Throwable) {}
    try { BehaviorPresetAlarmUiGate.markVisible(applicationContext, payload.toString()) } catch (_: Throwable) {}
    if (alarmFireIntent) {
      ensureRingingServiceForAlarmFire()
      handleAlarmFireSideEffects()
      if (!ringServiceActiveForThisFire) startAlarmSignal()
    }
    buildUiForCurrentPayload()
  }

  override fun onNewIntent(intent: Intent?) {
    super.onNewIntent(intent)
    stopAlarmSignal(stopService = false)
    setIntent(intent)
    nextAlarmScheduledForThisFire = false
    loadPayloadFromIntent(intent)
    try { BehaviorPresetAlarmOverlay.dismiss(applicationContext) } catch (_: Throwable) {}
    try { BehaviorPresetAlarmUiGate.markVisible(applicationContext, payload.toString()) } catch (_: Throwable) {}
    if (alarmFireIntent) {
      ensureRingingServiceForAlarmFire()
      handleAlarmFireSideEffects()
      if (!ringServiceActiveForThisFire) startAlarmSignal()
    }
    buildUiForCurrentPayload()
  }

  private fun configureAlarmWindow() {
    // Use both the modern APIs and legacy window flags. Several OEM ROMs still honor only the flags when an alarm
    // Activity is launched from a background process or while the keyguard is active.
    if (Build.VERSION.SDK_INT >= 27) {
      try { setShowWhenLocked(true) } catch (_: Throwable) {}
      try { setTurnScreenOn(true) } catch (_: Throwable) {}
    }
    @Suppress("DEPRECATION")
    window.addFlags(
      WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
    )
    if (Build.VERSION.SDK_INT >= 26) {
      try {
        (getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager)?.requestDismissKeyguard(this, null)
      } catch (_: Throwable) {}
    }
  }

  private fun loadPayloadFromIntent(intent: Intent?) {
    val rawPayload = intent?.getStringExtra("payload") ?: "{}"
    alarmFireIntent = intent?.getBooleanExtra("alarm_fire", false) == true || intent?.getBooleanExtra("from_preset_alarm", false) == true
    ringServiceActiveForThisFire = intent?.getBooleanExtra("ring_service_active", false) == true
    try {
      val normalized = if (alarmFireIntent) {
        BehaviorPresetAlarmScheduler.normalizePayloadForFire(applicationContext, rawPayload)
      } else {
        rawPayload
      }
      payload = JSONObject(normalized)
    } catch (_: Throwable) {
      try { payload = JSONObject(rawPayload) } catch (_: Throwable) { payload = JSONObject() }
    }
    setupRequiredMode = shouldRequirePresetSetup()
    cancelNotification()
  }

  private fun handleAlarmFireSideEffects() {
    if (nextAlarmScheduledForThisFire) return
    nextAlarmScheduledForThisFire = true
    try { BehaviorPresetAlarmScheduler.scheduleNextAfterFire(applicationContext, payload.toString()) } catch (_: Throwable) {}
    try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] ringing form opened alarmId=${payload.optInt("alarmId", 0)}") } catch (_: Throwable) {}
  }
  private fun buildUiForCurrentPayload() {
    if (isDailyReviewMode()) {
      buildDailyReviewPromptUi()
    } else if (setupRequiredMode) {
      buildPresetSetupUi()
    } else {
      buildPresetAckUi()
    }
  }

  private fun isDailyReviewMode(): Boolean {
    return payload.optString("type", "") == "behavior_preset_daily_review" || payload.optString("templateKey", "") == "preset_daily_review"
  }


  private fun ensureRingingServiceForAlarmFire() {
    if (!alarmFireIntent || ringServiceActiveForThisFire) return
    val id = payload.optInt("alarmId", 0).takeIf { it != 0 } ?: (97199999 + ((System.currentTimeMillis() / 60000L) % 100000L).toInt())
    try {
      BehaviorPresetAlarmRingingService.startRinging(applicationContext, id, payload.toString())
      ringServiceActiveForThisFire = true
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] form ensured ringing service id=$id") } catch (_: Throwable) {}
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] form failed to start ringing service: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
  }

  override fun onBackPressed() {
    if (isDailyReviewMode()) {
      snoozeFiveMinutes("用户返回，尚未完成每日预设行为复盘")
      Toast.makeText(this, "还没有完成每日复盘，5 分钟后会再次提醒", Toast.LENGTH_LONG).show()
      finish()
    } else if (setupRequiredMode) {
      snoozeFiveMinutes("用户返回，仍未完成行为预设")
      Toast.makeText(this, "还没有完成行为预设，5 分钟后会再次提醒", Toast.LENGTH_LONG).show()
      finish()
    } else {
      super.onBackPressed()
    }
  }

  override fun onDestroy() {
    try { BehaviorPresetAlarmUiGate.clearVisible(applicationContext, payload.toString()) } catch (_: Throwable) {}
    stopAlarmSignal()
    super.onDestroy()
  }

  private fun shouldRequirePresetSetup(): Boolean {
    if (isDailyReviewMode()) return false
    val explicitSetup = payload.optString("type", "") == "behavior_preset_setup_alarm" || payload.optBoolean("setupRequired", false)
    val arr = payload.optJSONArray("presets")
    if (arr != null) return explicitSetup || arr.length() <= 0
    return explicitSetup || payload.optInt("presetId", 0) <= 0
  }

  private fun startAlarmSignal() {
    val configuredVolume = BehaviorPresetAlarmSettings.getVolume(this).coerceIn(0f, 1f)
    if (configuredVolume > 0f) {
      try { boostAlarmStreamVolume(configuredVolume) } catch (_: Throwable) {}
      try {
        val configured = BehaviorPresetAlarmSettings.getSoundUri(this)
        val payloadUri = payload.optString("alarmSoundUri", "")
        val candidates = BehaviorPresetAlarmSettings.soundCandidates(this, configured, payloadUri)
        try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] form sound candidates=" + candidates.joinToString(" | ")) } catch (_: Throwable) {}

        for (uri in candidates) {
          try {
            val player = MediaPlayer().apply {
              setDataSource(this@BehaviorPresetAlarmFormActivity, uri)
              if (Build.VERSION.SDK_INT >= 21) {
                setAudioAttributes(
                  AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                )
              } else {
                @Suppress("DEPRECATION")
                setAudioStreamType(AudioManager.STREAM_ALARM)
              }
              isLooping = true
              setVolume(configuredVolume, configuredVolume)
              prepare()
              start()
            }
            mediaPlayer = player
            try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] MediaPlayer alarm sound started uri=$uri volume=$configuredVolume") } catch (_: Throwable) {}
            break
          } catch (one: Throwable) {
            try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] MediaPlayer sound candidate failed uri=$uri ${one.javaClass.simpleName} ${one.message}") } catch (_: Throwable) {}
          }
        }
        if (mediaPlayer == null) {
          for (uri in candidates) {
            try {
              val r = RingtoneManager.getRingtone(this, uri) ?: continue
              if (Build.VERSION.SDK_INT >= 21) {
                r.audioAttributes = AudioAttributes.Builder()
                  .setUsage(AudioAttributes.USAGE_ALARM)
                  .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                  .build()
              }
              if (Build.VERSION.SDK_INT >= 28) {
                r.isLooping = true
                r.volume = configuredVolume
              }
              r.play()
              ringtone = r
              try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] Ringtone alarm sound started uri=$uri volume=$configuredVolume") } catch (_: Throwable) {}
              break
            } catch (one: Throwable) {
              try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] Ringtone sound candidate failed uri=$uri ${one.javaClass.simpleName} ${one.message}") } catch (_: Throwable) {}
            }
          }
        }
      } catch (t: Throwable) {
        try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] play alarm sound failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
      }
    }

    val vibrateEnabled = BehaviorPresetAlarmSettings.isVibrateEnabled(this) || payload.optBoolean("alarmVibrate", false)
    if (!vibrateEnabled) return
    try {
      vibrator = if (Build.VERSION.SDK_INT >= 31) {
        (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
      } else {
        @Suppress("DEPRECATION")
        getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
      }
      if (vibrator?.hasVibrator() == false) return
      val pattern = longArrayOf(0L, 900L, 350L, 900L, 350L, 900L, 900L)
      if (Build.VERSION.SDK_INT >= 26) {
        val effect = VibrationEffect.createWaveform(pattern, 0)
        if (Build.VERSION.SDK_INT >= 21) {
          val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
          vibrator?.vibrate(effect, attrs)
        } else {
          vibrator?.vibrate(effect)
        }
      } else {
        @Suppress("DEPRECATION")
        vibrator?.vibrate(pattern, 0)
      }
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] vibration started") } catch (_: Throwable) {}
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] vibrate failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
  }

  private fun boostAlarmStreamVolume(configuredVolume: Float) {
    try {
      val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
      val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM).coerceAtLeast(1)
      val desired = kotlin.math.max(1, kotlin.math.round(max * configuredVolume).toInt()).coerceAtMost(max)
      val current = am.getStreamVolume(AudioManager.STREAM_ALARM)
      if (originalAlarmStreamVolume == null) originalAlarmStreamVolume = current
      if (current < desired) {
        am.setStreamVolume(AudioManager.STREAM_ALARM, desired, 0)
        try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] alarm stream volume boosted $current->$desired/$max") } catch (_: Throwable) {}
      }
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] boost alarm stream volume failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
  }

  private fun restoreAlarmStreamVolume() {
    val original = originalAlarmStreamVolume ?: return
    originalAlarmStreamVolume = null
    try {
      val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
      val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM).coerceAtLeast(1)
      am.setStreamVolume(AudioManager.STREAM_ALARM, original.coerceIn(0, max), 0)
    } catch (_: Throwable) {}
  }

  private fun stopAlarmSignal(stopService: Boolean = true) {
    try {
      mediaPlayer?.let { player ->
        try { if (player.isPlaying) player.stop() } catch (_: Throwable) {}
        try { player.release() } catch (_: Throwable) {}
      }
    } catch (_: Throwable) {}
    mediaPlayer = null
    try { ringtone?.stop() } catch (_: Throwable) {}
    ringtone = null
    try { vibrator?.cancel() } catch (_: Throwable) {}
    vibrator = null
    restoreAlarmStreamVolume()
    if (stopService) {
      try { BehaviorPresetAlarmOverlay.dismiss(applicationContext) } catch (_: Throwable) {}
      try { BehaviorPresetAlarmRingingService.stopRinging(applicationContext) } catch (_: Throwable) {}
    }
  }

  private fun buildDailyReviewPromptUi() {
    val presets = payloadPresets()
    val count = payload.optInt("presetCount", presets.length())
    val root = baseRoot()
    root.addView(title("每日预设行为复盘"))
    root.addView(desc("请登记今天所有已确认预设行为的最终完成/未完成状态。未完成项需要填写原因，也可以选择转入明天；复盘完成后会继续进入明天预设与闹钟注册。"))
    root.addView(card("复盘范围", if (count > 0) "今天共有 ${count} 个预设行为需要最终确认" else "今天暂无预设行为，也可以进入下一步设置明天"))
    if (presets.length() > 0) {
      for (i in 0 until presets.length()) {
        val p = presets.optJSONObject(i) ?: continue
        root.addView(card("${i + 1}. ${p.optString("presetName", p.optString("name", "预设行为"))}", "${p.optString("category", "未分类")} · ${planText(p)}"))
      }
    }
    root.addView(primaryButton("打开复盘登记") { openDailyReviewInApp() })
    root.addView(secondaryText("现在不方便，5 分钟后再提醒") {
      snoozeFiveMinutes("用户暂不进行每日复盘")
      Toast.makeText(this, "5 分钟后会再次提醒每日复盘", Toast.LENGTH_SHORT).show()
      finish()
    })
    setContentView(ScrollView(this).apply { addView(root) })
  }

  private fun openDailyReviewInApp() {
    stopAlarmSignal()
    try {
      val obj = JSONObject(payload.toString())
      obj.put("module", "behavior_tracking")
      obj.put("type", "behavior_preset_daily_review")
      obj.put("templateKey", "preset_daily_review")
      obj.put("route", "/behavior_tracking")
      val i = Intent(this, MainActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        putExtra("from_notification", true)
        putExtra("notif_type", "behavior_tracking")
        putExtra("payload", obj.toString())
      }
      startActivity(i)
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] open daily review failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
      Toast.makeText(this, "打开复盘页失败，请从行为观察-预设页进入每日复盘", Toast.LENGTH_LONG).show()
    }
    finish()
  }

  private fun buildPresetSetupUi() {
    val root = baseRoot()
    root.addView(title("请先完成行为预设"))
    root.addView(desc("这个闹钟不是要求你现在完成某个行为，而是提醒你先把今天要观察/确认的固定行为预设好。当天没有预设行为时不能直接跳过；如果暂不填写，5 分钟后会再次响铃提醒。"))

    presetNameInput = edit("预设行为名称（必填）", "例如：阅读 20 分钟 / 睡前复盘 / 运动", InputType.TYPE_CLASS_TEXT)
    root.addView(presetNameInput)
    presetCategoryInput = edit("类别", "默认：工作/学习，也可写健康、休息、自律等", InputType.TYPE_CLASS_TEXT)
    root.addView(presetCategoryInput)
    presetDurationInput = edit("计划时长（分钟，可选）", "例如 20", InputType.TYPE_CLASS_NUMBER)
    root.addView(presetDurationInput)
    presetNotesInput = edit("备注（可选）", "例如：每天提醒我确认一次", InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE, 3)
    root.addView(presetNotesInput)

    root.addView(primaryButton("保存预设并停止闹钟") { savePresetDefinition() })
    root.addView(secondaryText("现在不方便，5 分钟后再次提醒") {
      snoozeFiveMinutes("用户暂不填写预设")
      Toast.makeText(this, "5 分钟后会再次提醒你完成行为预设", Toast.LENGTH_LONG).show()
      finish()
    })
    setContentView(ScrollView(this).apply { addView(root) })
  }

  private fun buildPresetAckUi() {
    val presets = payloadPresets()
    val root = baseRoot()
    root.addView(title(if (presets.length() > 1) "预设提醒（${presets.length()}项）" else "预设提醒"))
    root.addView(desc("这是提醒你查看或确认这个闹钟时刻对应的预设，不是要求你现在完成行为。实际完成情况仍可在“预设”页的每日确认清单中处理。"))

    if (presets.length() <= 0) {
      root.addView(card("预设", payload.optString("presetName", "今天的预设行为")))
      root.addView(card("类别", payload.optString("category", "未分类")))
      root.addView(card("计划", planText(payload)))
    } else {
      for (i in 0 until presets.length()) {
        val p = presets.optJSONObject(i) ?: continue
        root.addView(card("${i + 1}. ${p.optString("presetName", p.optString("name", "预设行为"))}", "${p.optString("category", "未分类")} · ${planText(p)}"))
      }
    }

    root.addView(primaryButton(if (presets.length() > 1) "我已收到全部预设提醒" else "我已收到预设提醒") { acknowledgePresetReminder() })
    root.addView(secondaryText("5 分钟后再提醒") {
      snoozeFiveMinutes("用户选择稍后再提醒")
      Toast.makeText(this, "5 分钟后会再次提醒", Toast.LENGTH_SHORT).show()
      finish()
    })
    setContentView(ScrollView(this).apply { addView(root) })
  }

  private fun payloadPresets(): JSONArray {
    val arr = payload.optJSONArray("presets")
    if (arr != null) return arr
    val presetId = payload.optInt("presetId", 0)
    if (presetId <= 0) return JSONArray()
    return JSONArray().put(JSONObject().apply {
      put("presetId", presetId)
      put("presetName", payload.optString("presetName", "今天的预设行为"))
      put("category", payload.optString("category", "未分类"))
      put("unit", payload.optString("unit", "次"))
      put("targetValue", payload.opt("targetValue"))
      put("defaultDurationMin", payload.opt("defaultDurationMin"))
    })
  }

  private fun planText(obj: JSONObject): String {
    val unit = obj.optString("unit", "次")
    val targetRaw = obj.opt("targetValue")
    val target = if (targetRaw == null || targetRaw == JSONObject.NULL || targetRaw.toString() == "null") "" else targetRaw.toString()
    val durationRaw = obj.opt("defaultDurationMin")
    val duration = if (durationRaw == null || durationRaw == JSONObject.NULL) 0 else obj.optInt("defaultDurationMin", 0)
    return listOf(
      if (target.isNotBlank()) "$target$unit" else "无固定量",
      if (duration > 0) "默认 ${duration}分钟" else null
    ).filterNotNull().joinToString(" · ")
  }

  private fun savePresetDefinition() {
    val name = presetNameInput.text?.toString()?.trim().orEmpty()
    if (name.isBlank()) {
      Toast.makeText(this, "请先填写预设行为名称，不能跳过预设", Toast.LENGTH_LONG).show()
      return
    }
    val category = presetCategoryInput.text?.toString()?.trim().orEmpty().ifBlank { "工作/学习" }
    val duration = presetDurationInput.text?.toString()?.trim()
    val note = presetNotesInput.text?.toString()?.trim().orEmpty()
    val id = BehaviorObservationNativeRecorder.savePresetDefinitionFromAlarm(
      this,
      name,
      category,
      duration,
      note,
      payload.optInt("reminderHour", 21),
      payload.optInt("reminderMinute", 0),
      payload.optBoolean("alarmVibrate", true)
    )
    if (id > 0L) {
      try { BehaviorPresetAlarmScheduler.rescheduleUpcoming(applicationContext) } catch (_: Throwable) {}
      Toast.makeText(this, "已保存预设行为", Toast.LENGTH_SHORT).show()
      finish()
    } else {
      Toast.makeText(this, "保存失败，请先打开一次 App 初始化数据库", Toast.LENGTH_LONG).show()
    }
  }

  private fun acknowledgePresetReminder() {
    val presets = payloadPresets()
    if (presets.length() > 0) {
      for (i in 0 until presets.length()) {
        val p = presets.optJSONObject(i) ?: continue
        val one = JSONObject(payload.toString())
        one.put("presetId", p.optInt("presetId", p.optInt("id", 0)))
        one.put("presetName", p.optString("presetName", p.optString("name", "今天的预设行为")))
        one.put("category", p.optString("category", "未分类"))
        one.put("unit", p.optString("unit", "次"))
        one.put("targetValue", p.opt("targetValue"))
        one.put("defaultDurationMin", p.opt("defaultDurationMin"))
        BehaviorObservationNativeRecorder.savePresetAlarmCheckIn(this, one, "acknowledged", null, null, "已收到系统闹钟预设提醒")
      }
    } else {
      val presetId = payload.optInt("presetId", 0)
      if (presetId > 0) BehaviorObservationNativeRecorder.savePresetAlarmCheckIn(this, payload, "acknowledged", null, null, "已收到系统闹钟预设提醒")
    }
    Toast.makeText(this, "已确认收到预设提醒", Toast.LENGTH_SHORT).show()
    finish()
  }

  private fun snoozeFiveMinutes(reason: String) {
    try {
      val obj = JSONObject(payload.toString())
      obj.put("snoozeReason", reason)
      obj.put("snoozeAtMs", System.currentTimeMillis())
      if (setupRequiredMode) obj.put("setupRequired", true)
      val id = 96800000 + ((System.currentTimeMillis() / 1000L) % 900000L).toInt()
      obj.put("alarmId", id)
      NativeSchedulerK.scheduleAlarmClockAt(applicationContext, id, System.currentTimeMillis() + 5 * 60_000L, obj.toString())
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] snooze 5min: $reason") } catch (_: Throwable) {}
    } catch (_: Throwable) {}
  }

  private fun countActivePresetsForDay(dayMs: Long): Int {
    val db = openDbReadOnly() ?: return 0
    return try {
      val weekday = dartWeekday(dayMs)
      var count = 0
      db.rawQuery("SELECT weekdays_json FROM behavior_observation_presets WHERE active = 1", emptyArray()).use { c ->
        while (c.moveToNext()) {
          val raw = if (c.isNull(0)) "[]" else c.getString(0)
          val days = parseWeekdays(raw)
          if (days.isEmpty() || days.contains(weekday)) count++
        }
      }
      count
    } catch (_: Throwable) { 0 } finally { try { db.close() } catch (_: Throwable) {} }
  }

  private fun openDbReadOnly(): SQLiteDatabase? {
    return try {
      val contract = com.example.quote_app.data.DbInspector.loadOrLightScan(applicationContext)
      val path = contract?.dbPath
      if (!path.isNullOrBlank()) SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY) else null
    } catch (_: Throwable) { null }
  }

  private fun parseWeekdays(raw: String?): Set<Int> {
    val result = LinkedHashSet<Int>()
    try {
      val arr = JSONArray(raw ?: "[]")
      for (i in 0 until arr.length()) {
        val v = arr.optInt(i, 0)
        if (v in 1..7) result.add(v)
      }
    } catch (_: Throwable) {}
    return result
  }

  private fun dartWeekday(ms: Long): Int {
    val cal = Calendar.getInstance().apply { timeInMillis = ms }
    return when (cal.get(Calendar.DAY_OF_WEEK)) {
      Calendar.MONDAY -> 1
      Calendar.TUESDAY -> 2
      Calendar.WEDNESDAY -> 3
      Calendar.THURSDAY -> 4
      Calendar.FRIDAY -> 5
      Calendar.SATURDAY -> 6
      Calendar.SUNDAY -> 7
      else -> 1
    }
  }

  private fun dayStartMs(ms: Long): Long {
    val c = Calendar.getInstance().apply { timeInMillis = ms }
    c.set(Calendar.HOUR_OF_DAY, 0); c.set(Calendar.MINUTE, 0); c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0)
    return c.timeInMillis
  }

  private fun baseRoot(): LinearLayout = LinearLayout(this).apply {
    orientation = LinearLayout.VERTICAL
    setPadding(dp(20), dp(26), dp(20), dp(20))
    setBackgroundColor(0xFFFFFFFF.toInt())
  }

  private fun title(textValue: String): TextView = TextView(this).apply {
    text = textValue
    textSize = 28f
    setTextColor(0xFF0F172A.toInt())
    typeface = android.graphics.Typeface.DEFAULT_BOLD
  }

  private fun desc(textValue: String): TextView = TextView(this).apply {
    text = textValue
    textSize = 15f
    setTextColor(0xFF64748B.toInt())
    setPadding(0, dp(8), 0, dp(16))
  }

  private fun card(label: String, value: String): TextView = TextView(this).apply {
    text = "$label：$value"
    textSize = 16f
    setTextColor(0xFF0F172A.toInt())
    setPadding(dp(14), dp(12), dp(14), dp(12))
    setBackgroundColor(0xFFF8FAFC.toInt())
  }

  private fun edit(label: String, hintText: String, input: Int, lines: Int = 1): EditText = EditText(this).apply {
    hint = "$label${if (hintText.isNotBlank()) "，$hintText" else ""}"
    textSize = 16f
    inputType = input
    minLines = lines
    maxLines = if (lines > 1) 4 else 1
    setSingleLine(lines == 1)
  }

  private fun primaryButton(textValue: String, action: () -> Unit): Button = Button(this).apply {
    text = textValue
    textSize = 16f
    setTextColor(0xFFFFFFFF.toInt())
    setBackgroundColor(0xFF4F5FA3.toInt())
    setOnClickListener { action() }
  }.also { button ->
    button.layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(52)).apply { topMargin = dp(16) }
  }

  private fun secondaryText(textValue: String, action: () -> Unit): TextView = TextView(this).apply {
    text = textValue
    gravity = Gravity.CENTER
    textSize = 15f
    setTextColor(0xFF64748B.toInt())
    setPadding(0, dp(18), 0, 0)
    setOnClickListener { action() }
  }

  private fun cancelNotification() {
    try {
      val id = payload.optInt("alarmId", 0)
      if (id != 0) (getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)?.cancel(id)
    } catch (_: Throwable) {}
  }

  private fun dp(v: Int): Int = (v * resources.displayMetrics.density + 0.5f).toInt()
}
