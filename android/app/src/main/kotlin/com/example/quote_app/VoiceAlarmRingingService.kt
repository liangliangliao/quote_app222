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
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.File

class VoiceAlarmRingingService : Service() {
  companion object {
    private const val ACTION_START = "com.example.quote_app.VOICE_ALARM_START"
    private const val ACTION_STOP = "com.example.quote_app.VOICE_ALARM_STOP"
    private const val ACTION_POSTPONE_VOICE_REPLAY = "com.example.quote_app.VOICE_ALARM_POSTPONE_VOICE_REPLAY"
    private const val ACTION_SET_INTERACTION_ACTIVE = "com.example.quote_app.VOICE_ALARM_SET_INTERACTION_ACTIVE"
    private const val EXTRA_PAYLOAD = "payload"
    private const val EXTRA_POSTPONE_MS = "postponeMs"
    private const val EXTRA_INTERACTION_ACTIVE = "interactionActive"
    private const val EXTRA_INTERACTION_DURATION_MS = "interactionDurationMs"
    private const val CHANNEL_ID = "voice_alarm_ringing_v3"
    private const val NOTIFICATION_ID = 974002
    private const val STATE_PREFS = "voice_alarm_ringing_state"
    private const val KEY_ACTIVE_PAYLOAD = "activePayload"
    const val ACTION_VOICE_PLAYBACK_START = "com.example.quote_app.VOICE_ALARM_VOICE_PLAYBACK_START"
    const val ACTION_VOICE_PLAYBACK_END = "com.example.quote_app.VOICE_ALARM_VOICE_PLAYBACK_END"
    @Volatile private var activePayload: String? = null

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

    @JvmStatic
    fun restoreFullScreenIfRinging(context: Context) {
      val payload = activePayload ?: readActivePayload(context) ?: return
      try {
        context.startActivity(Intent(context, VoiceAlarmActivity::class.java).apply {
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
          putExtra("payload", payload)
        })
      } catch (_: Throwable) {}
    }

    private fun stateContexts(context: Context): List<Context> {
      val app = context.applicationContext
      return if (Build.VERSION.SDK_INT >= 24) {
        listOf(app.createDeviceProtectedStorageContext(), app)
      } else {
        listOf(app)
      }
    }

    private fun persistActivePayload(context: Context, payload: String) {
      activePayload = payload
      for (storageContext in stateContexts(context)) {
        try {
          storageContext.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ACTIVE_PAYLOAD, payload)
            .apply()
        } catch (_: Throwable) {}
      }
    }

    private fun readActivePayload(context: Context): String? {
      for (storageContext in stateContexts(context)) {
        val payload = try {
          storageContext.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE).getString(KEY_ACTIVE_PAYLOAD, null)
        } catch (_: Throwable) {
          null
        }
        if (!payload.isNullOrBlank()) return payload
      }
      return null
    }

    private fun clearActivePayload(context: Context) {
      activePayload = null
      for (storageContext in stateContexts(context)) {
        try {
          storageContext.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_ACTIVE_PAYLOAD)
            .apply()
        } catch (_: Throwable) {}
      }
    }

    @JvmStatic
    fun postponeVoiceReplay(context: Context, postponeMs: Long) {
      try {
        context.startService(Intent(context, VoiceAlarmRingingService::class.java).apply {
          action = ACTION_POSTPONE_VOICE_REPLAY
          putExtra(EXTRA_POSTPONE_MS, postponeMs)
        })
      } catch (_: Throwable) {}
    }

    @JvmStatic
    fun setInteractionActive(context: Context, active: Boolean, interactionDurationMs: Long = 0L) {
      try {
        context.startService(Intent(context, VoiceAlarmRingingService::class.java).apply {
          action = ACTION_SET_INTERACTION_ACTIVE
          putExtra(EXTRA_INTERACTION_ACTIVE, active)
          putExtra(EXTRA_INTERACTION_DURATION_MS, interactionDurationMs)
        })
      } catch (_: Throwable) {}
    }
  }

  private var voicePlayer: MediaPlayer? = null
  private var musicPlayer: MediaPlayer? = null
  private var alarmTts: TextToSpeech? = null
  private var alarmTtsReady = false
  private var pendingAlarmTts: Pair<String, Float>? = null
  private var vibrator: Vibrator? = null
  private var wakeLock: PowerManager.WakeLock? = null
  private var originalAlarmVolume: Int? = null
  private var currentMusicVolume = 0.4f
  private var musicRestoreRunnable: Runnable? = null
  private val replayHandler = Handler(Looper.getMainLooper())
  private var replayRunnable: Runnable? = null
  private var currentPayload: String = "{}"
  private var voiceReplayBlockedUntil = 0L
  private var voiceInteractionActiveUntil = 0L

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent?.action == ACTION_STOP) {
      clearActivePayload(this)
      stopSelf()
      return START_NOT_STICKY
    }
    if (intent?.action == ACTION_POSTPONE_VOICE_REPLAY) {
      postponeVoiceReplay(intent.getLongExtra(EXTRA_POSTPONE_MS, 15_000L))
      return START_STICKY
    }
    if (intent?.action == ACTION_SET_INTERACTION_ACTIVE) {
      setVoiceInteractionActive(
        intent.getBooleanExtra(EXTRA_INTERACTION_ACTIVE, false),
        intent.getLongExtra(EXTRA_INTERACTION_DURATION_MS, 0L),
      )
      return START_STICKY
    }
    val payload = intent?.getStringExtra(EXTRA_PAYLOAD) ?: activePayload ?: readActivePayload(this) ?: "{}"
    persistActivePayload(this, payload)
    startForegroundAlarm(payload)
    acquireWakeLock()
    currentPayload = payload
    startSignals(payload)
    return START_STICKY
  }

  override fun onDestroy() {
    activePayload = null
    stopSignals()
    replayRunnable?.let { replayHandler.removeCallbacks(it) }
    replayRunnable = null
    musicRestoreRunnable?.let { replayHandler.removeCallbacks(it) }
    musicRestoreRunnable = null
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
          enableVibration(true)
          vibrationPattern = longArrayOf(0, 900, 350, 900, 350, 1400)
          setSound(null, null)
          lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        },
      )
    }
    val launchIntent = Intent(this, VoiceAlarmActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("payload", payload)
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
      .setVibrate(longArrayOf(0, 900, 350, 900, 350, 1400))
      .setOngoing(true)
      .setAutoCancel(false)
      .setContentIntent(contentIntent)
      .setFullScreenIntent(contentIntent, true)
      .addAction(android.R.drawable.ic_media_pause, "5分钟后提醒", snoozeIntent)
      .addAction(android.R.drawable.ic_menu_close_clear_cancel, "关闭", stopIntent)
      .build()
    if (Build.VERSION.SDK_INT >= 30) {
      try {
        startForeground(
          NOTIFICATION_ID,
          notification,
          ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
        )
      } catch (_: Throwable) {
        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
      }
    } else if (Build.VERSION.SDK_INT >= 29) {
      startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
    } else {
      startForeground(NOTIFICATION_ID, notification)
    }
    try { contentIntent.send() } catch (_: Throwable) {}
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
      val pattern = longArrayOf(0, 900, 350, 900, 350, 1400)
      val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255)
      if (Build.VERSION.SDK_INT >= 26) {
        val effect = VibrationEffect.createWaveform(pattern, amplitudes, 0)
        vibrator?.vibrate(
          effect,
          AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build(),
        )
      }
      else {
        @Suppress("DEPRECATION")
        vibrator?.vibrate(pattern, 0)
      }
    }
    val musicPath = data.optString("musicPath", "")
    currentMusicVolume = data.optDouble("musicVolume", 0.4).toFloat().coerceIn(0f, 1f)
    if (musicPath.isNotBlank() && File(musicPath).isFile) {
      musicPlayer = createPlayer(Uri.fromFile(File(musicPath)), true, currentMusicVolume)
    } else if (data.optBoolean("systemMusic", true)) {
      val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
      if (alarmUri != null) musicPlayer = createPlayer(alarmUri, true, currentMusicVolume)
    }
    if (hasVoicePrompt(data)) {
      playVoiceOnce(data)
      scheduleVoiceReplay(data)
    }
  }

  private fun hasVoicePrompt(data: JSONObject): Boolean {
    val voicePath = data.optString("voicePath", "")
    return (voicePath.isNotBlank() && File(voicePath).isFile) || data.optString("text", "").isNotBlank()
  }

  private fun playVoiceOnce(data: JSONObject) {
    val voicePath = data.optString("voicePath", "")
    val volume = data.optDouble("voiceVolume", 1.0).toFloat().coerceIn(0f, 1f)
    if (voicePath.isNotBlank() && File(voicePath).isFile) {
      try { voicePlayer?.stop() } catch (_: Throwable) {}
      try { voicePlayer?.release() } catch (_: Throwable) {}
      voicePlayer = createPlayer(Uri.fromFile(File(voicePath)), false, volume = volume, notifyVoice = true)
      return
    }
    // Direct-boot or first-unlock edge case: generated voice files may live in
    // credential-protected app storage and be unreadable even though the alarm
    // payload has been restored from device-protected storage.  Fall back to the
    // platform TTS so the user still hears the alarm text instead of silent music.
    speakAlarmTextOnce(data.optString("text", "语音闹钟时间到了"), volume)
  }

  private fun speakAlarmTextOnce(text: String, volume: Float) {
    val cleanText = text.trim().ifBlank { "语音闹钟时间到了" }
    if (alarmTtsReady && alarmTts != null) {
      val utteranceId = "alarm_tts_${System.currentTimeMillis()}"
      val params = Bundle().apply { putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume.coerceIn(0f, 1f)) }
      try {
        sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_START).setPackage(packageName))
        alarmTts?.speak(cleanText, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
      } catch (_: Throwable) {
        sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName))
      }
      return
    }
    pendingAlarmTts = cleanText to volume
    if (alarmTts != null) return
    alarmTts = TextToSpeech(this) { status ->
      if (status == TextToSpeech.SUCCESS) {
        alarmTtsReady = true
        try { alarmTts?.language = Locale.CHINA } catch (_: Throwable) {}
        if (Build.VERSION.SDK_INT >= 21) {
          try {
            alarmTts?.setAudioAttributes(
              AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build(),
            )
          } catch (_: Throwable) {}
        }
        alarmTts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
          override fun onStart(utteranceId: String?) {
            sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_START).setPackage(packageName))
          }
          override fun onDone(utteranceId: String?) {
            sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName))
          }
          @Deprecated("Deprecated in Java")
          override fun onError(utteranceId: String?) {
            sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName))
          }
          override fun onError(utteranceId: String?, errorCode: Int) {
            sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName))
          }
        })
        val pending = pendingAlarmTts
        pendingAlarmTts = null
        if (pending != null) {
          Handler(Looper.getMainLooper()).post { speakAlarmTextOnce(pending.first, pending.second) }
        }
      } else {
        alarmTtsReady = false
        pendingAlarmTts = null
        sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName))
      }
    }
    replayHandler.postDelayed(replayRunnable!!, replayDelayMs)
  }

  private fun resolveVoiceReplayPayload(fallbackData: JSONObject): JSONObject {
    return try { JSONObject(currentPayload) } catch (_: Throwable) { fallbackData }
  }

  private fun postponeVoiceReplay(postponeMs: Long) {
    val safePostponeMs = postponeMs.coerceIn(1000L, 180_000L)
    voiceReplayBlockedUntil = maxOf(voiceReplayBlockedUntil, System.currentTimeMillis() + safePostponeMs)
    try { voicePlayer?.stop() } catch (_: Throwable) {}
    try { voicePlayer?.release() } catch (_: Throwable) {}
    try { alarmTts?.stop() } catch (_: Throwable) {}
    pendingAlarmTts = null
    if (voicePlayer != null || alarmTts != null) sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName))
    voicePlayer = null
    duckMusicFor(safePostponeMs.coerceAtMost(30_000L))
  }

  private fun scheduleVoiceReplay(initialData: JSONObject) {
    replayRunnable?.let { replayHandler.removeCallbacks(it) }
    val fallbackData = initialData
    val replayDelayMs = initialData.optInt("replayIntervalSeconds", 60).coerceIn(15, 3600) * 1000L
    replayRunnable = Runnable {
      val latest = resolveVoiceReplayPayload(fallbackData)
      val blockedUntil = maxOf(voiceReplayBlockedUntil, voiceInteractionActiveUntil)
      val blockedMs = blockedUntil - System.currentTimeMillis()
      if (blockedMs > 0) {
        replayHandler.postDelayed(replayRunnable!!, blockedMs.coerceAtLeast(1000L))
        return@Runnable
      }
      playVoiceOnce(latest)
      scheduleVoiceReplay(latest)
    }
    replayHandler.postDelayed(replayRunnable!!, replayDelayMs)
  }

  private fun resolveVoiceReplayPayload(fallbackData: JSONObject): JSONObject {
    return try { JSONObject(currentPayload) } catch (_: Throwable) { fallbackData }
  }

  private fun postponeVoiceReplay(postponeMs: Long) {
    val safePostponeMs = postponeMs.coerceIn(1000L, 180_000L)
    voiceReplayBlockedUntil = maxOf(voiceReplayBlockedUntil, System.currentTimeMillis() + safePostponeMs)
    try { voicePlayer?.stop() } catch (_: Throwable) {}
    try { voicePlayer?.release() } catch (_: Throwable) {}
    try { alarmTts?.stop() } catch (_: Throwable) {}
    pendingAlarmTts = null
    if (voicePlayer != null || alarmTts != null) sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName))
    voicePlayer = null
    duckMusicFor(safePostponeMs.coerceAtMost(30_000L))
  }

  private fun setVoiceInteractionActive(active: Boolean, interactionDurationMs: Long) {
    if (active) {
      val activeDurationMs = interactionDurationMs.coerceIn(3000L, 180_000L)
      voiceInteractionActiveUntil = maxOf(
        voiceInteractionActiveUntil,
        System.currentTimeMillis() + activeDurationMs,
      )
      return
    }
    val idleDurationMs = interactionDurationMs.coerceIn(1000L, 15_000L)
    voiceInteractionActiveUntil = System.currentTimeMillis() + idleDurationMs
  }

  private fun duckMusicFor(durationMs: Long) {
    val player = musicPlayer ?: return
    try { player.setVolume(currentMusicVolume * 0.18f, currentMusicVolume * 0.18f) } catch (_: Throwable) { return }
    musicRestoreRunnable?.let { replayHandler.removeCallbacks(it) }
    musicRestoreRunnable = Runnable {
      musicRestoreRunnable = null
      try { musicPlayer?.setVolume(currentMusicVolume, currentMusicVolume) } catch (_: Throwable) {}
    }
    replayHandler.postDelayed(musicRestoreRunnable!!, durationMs.coerceAtLeast(1000L))
  }

  private fun createPlayer(uri: Uri, looping: Boolean, volume: Float = 0.75f, notifyVoice: Boolean = false): MediaPlayer? {
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
        setOnPreparedListener {
          if (notifyVoice) sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_START).setPackage(packageName))
          it.start()
        }
        setOnCompletionListener {
          if (notifyVoice) sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName))
        }
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
    try { alarmTts?.stop() } catch (_: Throwable) {}
    try { alarmTts?.shutdown() } catch (_: Throwable) {}
    try { musicPlayer?.stop() } catch (_: Throwable) {}
    try { musicPlayer?.release() } catch (_: Throwable) {}
    try { vibrator?.cancel() } catch (_: Throwable) {}
    if (voicePlayer != null || alarmTts != null) sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName))
    voicePlayer = null
    alarmTts = null
    alarmTtsReady = false
    pendingAlarmTts = null
    musicPlayer = null
    currentMusicVolume = 0.4f
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
