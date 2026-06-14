package com.example.quote_app

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
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.File

class VoiceAlarmRingingService : Service() {
  companion object {
    private const val ACTION_START = "com.example.quote_app.VOICE_ALARM_START"
    private const val ACTION_STOP = "com.example.quote_app.VOICE_ALARM_STOP"
    private const val EXTRA_PAYLOAD = "payload"
    private const val CHANNEL_ID = "voice_alarm_ringing_v2"
    private const val NOTIFICATION_ID = 974002

    @JvmStatic
    fun start(context: Context, payload: String) {
      val intent = Intent(context, VoiceAlarmRingingService::class.java).apply {
        action = ACTION_START
        putExtra(EXTRA_PAYLOAD, payload)
      }
      if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
    }

    @JvmStatic
    fun stop(context: Context) {
      try {
        context.startService(Intent(context, VoiceAlarmRingingService::class.java).apply { action = ACTION_STOP })
      } catch (_: Throwable) {}
    }
  }

  private var voicePlayer: MediaPlayer? = null
  private var musicPlayer: MediaPlayer? = null
  private var vibrator: Vibrator? = null
  private var wakeLock: PowerManager.WakeLock? = null
  private var originalAlarmVolume: Int? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent?.action == ACTION_STOP) {
      stopSelf()
      return START_NOT_STICKY
    }
    val payload = intent?.getStringExtra(EXTRA_PAYLOAD) ?: "{}"
    startForegroundAlarm(payload)
    acquireWakeLock()
    startSignals(payload)
    return START_STICKY
  }

  override fun onDestroy() {
    stopSignals()
    try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Throwable) {}
    wakeLock = null
    restoreAlarmVolume()
    super.onDestroy()
  }

  private fun startForegroundAlarm(payload: String) {
    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 26) {
      notificationManager.createNotificationChannel(
        NotificationChannel(CHANNEL_ID, "语音闹钟响铃", NotificationManager.IMPORTANCE_HIGH).apply {
          description = "即使 App 在后台或进程未运行，也会播放语音闹钟并震动"
          enableVibration(false)
          setSound(null, null)
          lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        },
      )
    }
    val launchIntent = (packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }
    val contentIntent = PendingIntent.getActivity(
      this,
      NOTIFICATION_ID,
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val stopIntent = PendingIntent.getBroadcast(
      this,
      NOTIFICATION_ID + 1,
      Intent(this, VoiceAlarmActionReceiver::class.java).apply {
        action = "com.example.quote_app.VOICE_ALARM_STOP_ACTION"
        putExtra("payload", payload)
      },
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val snoozeIntent = PendingIntent.getBroadcast(
      this,
      NOTIFICATION_ID + 2,
      Intent(this, VoiceAlarmActionReceiver::class.java).apply {
        action = "com.example.quote_app.VOICE_ALARM_SNOOZE"
        putExtra("payload", payload)
      },
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val text = try { JSONObject(payload).optString("text", "语音闹钟时间到了") } catch (_: Throwable) { "语音闹钟时间到了" }
    val notification = NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
      .setContentTitle("语音闹钟")
      .setContentText(text)
      .setStyle(NotificationCompat.BigTextStyle().bigText(text))
      .setPriority(NotificationCompat.PRIORITY_MAX)
      .setCategory(NotificationCompat.CATEGORY_ALARM)
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      .setOngoing(true)
      .setAutoCancel(false)
      .setContentIntent(contentIntent)
      .setFullScreenIntent(contentIntent, true)
      .addAction(android.R.drawable.ic_media_pause, "5分钟后提醒", snoozeIntent)
      .addAction(android.R.drawable.ic_menu_close_clear_cancel, "关闭", stopIntent)
      .build()
    if (Build.VERSION.SDK_INT >= 29) {
      startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
    } else {
      startForeground(NOTIFICATION_ID, notification)
    }
  }

  private fun acquireWakeLock() {
    val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
    wakeLock = manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "quote_app:voiceAlarm").apply {
      setReferenceCounted(false)
      acquire(10 * 60 * 1000L)
    }
  }

  private fun startSignals(payload: String) {
    stopSignals()
    val data = try { JSONObject(payload) } catch (_: Throwable) { JSONObject() }
    ensureAudibleAlarmVolume()
    if (data.optBoolean("vibrate", true)) {
      vibrator = if (Build.VERSION.SDK_INT >= 31) {
        (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
      } else {
        @Suppress("DEPRECATION")
        getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
      }
      val pattern = longArrayOf(0, 800, 450, 800, 450, 1200)
      if (Build.VERSION.SDK_INT >= 26) vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
      else {
        @Suppress("DEPRECATION")
        vibrator?.vibrate(pattern, 0)
      }
    }
    val musicPath = data.optString("musicPath", "")
    if (musicPath.isNotBlank() && File(musicPath).isFile) {
      musicPlayer = createPlayer(Uri.fromFile(File(musicPath)), true, 0.4f)
    } else if (data.optBoolean("systemMusic", true)) {
      val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
      if (alarmUri != null) musicPlayer = createPlayer(alarmUri, true, 0.4f)
    }
    val voicePath = data.optString("voicePath", "")
    if (voicePath.isNotBlank() && File(voicePath).isFile) {
      voicePlayer = createPlayer(Uri.fromFile(File(voicePath)), false, volume = 1f)
    }
  }

  private fun createPlayer(uri: Uri, looping: Boolean, volume: Float = 0.75f): MediaPlayer? {
    return try {
      MediaPlayer().apply {
        setAudioAttributes(
          AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build(),
        )
        setDataSource(this@VoiceAlarmRingingService, uri)
        isLooping = looping
        setVolume(volume, volume)
        setOnPreparedListener { it.start() }
        setOnErrorListener { player, _, _ ->
          try { player.release() } catch (_: Throwable) {}
          true
        }
        prepareAsync()
      }
    } catch (_: Throwable) {
      null
    }
  }

  private fun stopSignals() {
    try { voicePlayer?.stop() } catch (_: Throwable) {}
    try { voicePlayer?.release() } catch (_: Throwable) {}
    try { musicPlayer?.stop() } catch (_: Throwable) {}
    try { musicPlayer?.release() } catch (_: Throwable) {}
    try { vibrator?.cancel() } catch (_: Throwable) {}
    voicePlayer = null
    musicPlayer = null
    vibrator = null
  }

  private fun ensureAudibleAlarmVolume() {
    try {
      val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
      val current = audio.getStreamVolume(AudioManager.STREAM_ALARM)
      originalAlarmVolume = current
      val target = maxOf(1, (audio.getStreamMaxVolume(AudioManager.STREAM_ALARM) * 0.7f).toInt())
      if (current < target) audio.setStreamVolume(AudioManager.STREAM_ALARM, target, 0)
    } catch (_: Throwable) {}
  }

  private fun restoreAlarmVolume() {
    try {
      val value = originalAlarmVolume ?: return
      val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
      audio.setStreamVolume(AudioManager.STREAM_ALARM, value, 0)
    } catch (_: Throwable) {}
    originalAlarmVolume = null
  }
}
