package com.example.quote_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import org.json.JSONObject

/**
 * Alarm sound/vibration engine for behavior preset reminders.
 *
 * Runs as a foreground service started by AlarmManager's receiver so sound/vibration still work when the app UI
 * process was not already running and even if a full-screen Activity launch is delayed or blocked by the system.
 */
class BehaviorPresetAlarmRingingService : Service() {
  companion object {
    private const val ACTION_START = "com.example.quote_app.behavior_preset_alarm.START_RINGING"
    private const val ACTION_STOP = "com.example.quote_app.behavior_preset_alarm.STOP_RINGING"
    private const val EXTRA_ID = "id"
    private const val EXTRA_PAYLOAD = "payload"
    private const val CHANNEL_ID = "behavior_preset_alarm_ringing_v40_overlay"
    private const val MAX_RING_MS = 10 * 60 * 1000L

    @JvmStatic
    fun startRinging(ctx: Context, id: Int, payload: String?) {
      val app = ctx.applicationContext
      val i = Intent(app, BehaviorPresetAlarmRingingService::class.java).apply {
        action = ACTION_START
        putExtra(EXTRA_ID, id)
        putExtra(EXTRA_PAYLOAD, payload ?: "{}")
      }
      if (Build.VERSION.SDK_INT >= 26) app.startForegroundService(i) else app.startService(i)
    }

    @JvmStatic
    fun stopRinging(ctx: Context) {
      val app = ctx.applicationContext
      val i = Intent(app, BehaviorPresetAlarmRingingService::class.java).apply { action = ACTION_STOP }
      try { app.startService(i) } catch (_: Throwable) {}
    }
  }

  private var mediaPlayer: MediaPlayer? = null
  private var ringtone: Ringtone? = null
  private var vibrator: Vibrator? = null
  private var wakeLock: PowerManager.WakeLock? = null
  private var screenWakeLock: PowerManager.WakeLock? = null
  private var originalAlarmStreamVolume: Int? = null
  private val handler = Handler(Looper.getMainLooper())
  private val autoStop = Runnable { stopSelfSafely("auto timeout") }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent?.action == ACTION_STOP) {
      stopSelfSafely("explicit stop")
      return START_NOT_STICKY
    }

    val id = intent?.getIntExtra(EXTRA_ID, 0)?.takeIf { it != 0 } ?: 97199999
    var payload = intent?.getStringExtra(EXTRA_PAYLOAD) ?: "{}"
    try { payload = BehaviorPresetAlarmScheduler.normalizePayloadForFire(applicationContext, payload) } catch (_: Throwable) {}

    try { startAsForeground(id, payload) } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] startForeground failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
    try { acquireWakeLock() } catch (_: Throwable) {}
    try { acquireScreenWakeLock() } catch (_: Throwable) {}
    try { startSignal(payload) } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service signal failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
    handler.removeCallbacks(autoStop)
    handler.postDelayed(autoStop, MAX_RING_MS)
    return START_STICKY
  }

  override fun onDestroy() {
    stopSignal()
    releaseWakeLock()
    releaseScreenWakeLock()
    handler.removeCallbacks(autoStop)
    super.onDestroy()
  }

  private fun startAsForeground(id: Int, payload: String) {
    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 26) {
      val ch = NotificationChannel(CHANNEL_ID, "预设行为闹钟响铃", NotificationManager.IMPORTANCE_HIGH).apply {
        description = "行为预设闹钟到点后的响铃/震动与全屏表单"
        // 新渠道：高优先级但渠道本身不发声/不震动，避免覆盖用户选择的系统铃声和震动设置。
        // 不把通知标记为 silent，避免部分 ROM 降级 fullScreenIntent。
        enableVibration(false)
        setSound(null, null)
        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        setShowBadge(true)
      }
      nm.createNotificationChannel(ch)
    }

    val formIntent = Intent(this, BehaviorPresetAlarmFormActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("payload", payload)
      putExtra("from_preset_alarm", true)
      putExtra("alarm_fire", true)
      putExtra("ring_service_active", true)
    }
    val piFlags = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
    val fullScreenPi = PendingIntent.getActivity(this, id + 750000, formIntent, piFlags)

    val payloadObj = try { JSONObject(payload) } catch (_: Throwable) { JSONObject() }
    val isDailyReview = payloadObj.optString("type", "") == "behavior_preset_daily_review" || payloadObj.optString("templateKey", "") == "preset_daily_review"
    val notifyTitle = if (isDailyReview) "每日预设行为复盘" else "预设行为闹钟"
    val notifyText = if (isDailyReview) "请登记今天完成/未完成情况，未完成需填写原因" else "到点了，点击查看预设提醒表单"

    val n: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
      .setContentTitle(notifyTitle)
      .setContentText(notifyText)
      .setPriority(NotificationCompat.PRIORITY_MAX)
      .setCategory(NotificationCompat.CATEGORY_ALARM)
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      .setDefaults(0)
      .setOnlyAlertOnce(false)
      .setOngoing(true)
      .setAutoCancel(false)
      .setContentIntent(fullScreenPi)
      .setFullScreenIntent(fullScreenPi, true)
      .build()

    if (Build.VERSION.SDK_INT >= 29) {
      startForeground(id, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
    } else {
      startForeground(id, n)
    }
    try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] ringing foreground service started id=$id") } catch (_: Throwable) {}
    tryLaunchAlarmFormAggressively(id, payload, formIntent, fullScreenPi)
  }

  private fun acquireWakeLock() {
    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
    if (wakeLock?.isHeld == true) return
    wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "quote_app:behaviorPresetAlarm").apply {
      setReferenceCounted(false)
      acquire(MAX_RING_MS + 30_000L)
    }
  }

  private fun releaseWakeLock() {
    try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Throwable) {}
    wakeLock = null
  }

  @Suppress("DEPRECATION")
  private fun acquireScreenWakeLock() {
    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
    if (screenWakeLock?.isHeld == true) return
    val flags = PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE
    screenWakeLock = pm.newWakeLock(flags, "quote_app:behaviorPresetAlarmScreen").apply {
      setReferenceCounted(false)
      acquire(30_000L)
    }
  }

  private fun releaseScreenWakeLock() {
    try { if (screenWakeLock?.isHeld == true) screenWakeLock?.release() } catch (_: Throwable) {}
    screenWakeLock = null
  }

  private fun tryLaunchAlarmFormAggressively(id: Int, payload: String, formIntent: Intent, fullScreenPi: PendingIntent) {
    // v39 repeatedly sent PendingIntent/startActivity at several delays.  That occasionally helped on one ROM but it
    // also made the foreground case open several forms.  v40 uses one deterministic UI path:
    //   1) draw a real full-screen overlay when the user granted "display over other apps";
    //   2) always post a full-screen alarm notification;
    //   3) if no overlay is available, attempt one Activity launch only.
    try { BehaviorPresetAlarmOverlay.show(applicationContext, id, payload) } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service overlay failed id=$id ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
    // The foreground-service notification created above already carries the full-screen intent.  Avoid posting a
    // second alarm notification for the same id, because some ROMs execute both full-screen intents.

    if (!BehaviorPresetAlarmOverlay.canDraw(applicationContext) && BehaviorPresetAlarmUiGate.claimUi(applicationContext, payload)) {
      handler.postDelayed({
        trySendActivityPendingIntent(id, fullScreenPi)
        try {
          val i = Intent(formIntent).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
          }
          startActivity(i)
          try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service single startActivity form id=$id") } catch (_: Throwable) {}
        } catch (t: Throwable) {
          try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service single startActivity blocked id=$id ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
        }
      }, 250L)
    }
  }

  private fun trySendActivityPendingIntent(id: Int, pi: PendingIntent) {
    try {
      if (Build.VERSION.SDK_INT >= 34) {
        // compileSdk is intentionally kept lower in this project; use reflection for the Android 14+
        // background-activity-start opt-in when this process sends its own alarm Activity PendingIntent.
        try {
          val cls = Class.forName("android.app.ActivityOptions")
          val makeBasic = cls.getMethod("makeBasic")
          val opts = makeBasic.invoke(null)
          val method = cls.getMethod("setPendingIntentBackgroundActivityStartMode", java.lang.Integer.TYPE)
          // ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED == 1 on Android 14/15.
          method.invoke(opts, 1)
          val bundle = cls.getMethod("toBundle").invoke(opts) as? android.os.Bundle
          pi.send(this, 0, null, null, null, null, bundle)
          try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service PendingIntent.send with BAL opt-in id=$id") } catch (_: Throwable) {}
          return
        } catch (_: Throwable) {}
      }
      pi.send()
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service PendingIntent.send id=$id") } catch (_: Throwable) {}
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service PendingIntent.send failed id=$id ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
  }

  private fun startSignal(payload: String) {
    if (mediaPlayer?.isPlaying == true || ringtone?.isPlaying == true) return
    val configuredVolume = BehaviorPresetAlarmSettings.getVolume(this).coerceIn(0f, 1f)
    if (configuredVolume > 0f) {
      boostAlarmStreamVolume(configuredVolume)
      val configured = try { BehaviorPresetAlarmSettings.getSoundUri(this) } catch (_: Throwable) { "" }
      val payloadUri = try { org.json.JSONObject(payload).optString("alarmSoundUri", "") } catch (_: Throwable) { "" }
      val candidates = BehaviorPresetAlarmSettings.soundCandidates(this, configured, payloadUri)
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service sound candidates=" + candidates.joinToString(" | ")) } catch (_: Throwable) {}

      for (uri in candidates) {
        try {
          val player = MediaPlayer().apply {
            setDataSource(this@BehaviorPresetAlarmRingingService, uri)
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
          try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service MediaPlayer sound started uri=$uri volume=$configuredVolume") } catch (_: Throwable) {}
          break
        } catch (one: Throwable) {
          try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service MediaPlayer candidate failed uri=$uri ${one.javaClass.simpleName} ${one.message}") } catch (_: Throwable) {}
        }
      }

      // Some OEM ringtone providers expose URIs that MediaPlayer cannot open directly.  RingtoneManager can still
      // resolve and play them through the system ringtone pipeline, so use it as a second sound path.
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
            try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service Ringtone sound started uri=$uri volume=$configuredVolume") } catch (_: Throwable) {}
            break
          } catch (one: Throwable) {
            try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service Ringtone candidate failed uri=$uri ${one.javaClass.simpleName} ${one.message}") } catch (_: Throwable) {}
          }
        }
      }
    }

    val payloadVibrate = try { org.json.JSONObject(payload).optBoolean("alarmVibrate", false) } catch (_: Throwable) { false }
    if (!BehaviorPresetAlarmSettings.isVibrateEnabled(this) && !payloadVibrate) return
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
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service vibration started") } catch (_: Throwable) {}
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service vibrate failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
  }

  private fun boostAlarmStreamVolume(configuredVolume: Float) {
    try {
      val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
      val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM).coerceAtLeast(1)
      val desired = kotlin.math.max(1, kotlin.math.round(max * configuredVolume).toInt()).coerceAtMost(max)
      val current = am.getStreamVolume(AudioManager.STREAM_ALARM)
      if (originalAlarmStreamVolume == null) originalAlarmStreamVolume = current
      if (current < desired) am.setStreamVolume(AudioManager.STREAM_ALARM, desired, 0)
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] service boost volume failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
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

  private fun stopSignal() {
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
  }

  private fun stopSelfSafely(reason: String) {
    try { com.example.quote_app.data.DbRepo.log(this, null, "[BehaviorPresetAlarm] ringing service stop: $reason") } catch (_: Throwable) {}
    try { BehaviorPresetAlarmOverlay.dismiss(applicationContext) } catch (_: Throwable) {}
    stopSignal()
    releaseWakeLock()
    releaseScreenWakeLock()
    try { stopForeground(true) } catch (_: Throwable) {}
    stopSelf()
  }
}
