package com.example.quote_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
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
import kotlin.random.Random
import java.io.File

class VoiceAlarmRingingService : Service() {
  private fun logVoice(event: String, detail: String = "", data: Map<String, Any?> = emptyMap()) {
    VoiceAlarmDebugLog.write(this, "service.$event", detail, data)
  }

  companion object {
    private const val ACTION_START = "com.example.quote_app.VOICE_ALARM_START"
    private const val ACTION_STOP = "com.example.quote_app.VOICE_ALARM_STOP"
    private const val ACTION_POSTPONE_VOICE_REPLAY = "com.example.quote_app.VOICE_ALARM_POSTPONE_VOICE_REPLAY"
    private const val EXTRA_PAYLOAD = "payload"
    private const val EXTRA_POSTPONE_MS = "postponeMs"
    const val CHANNEL_ID = "voice_alarm_ringing_v5"
    private const val NOTIFICATION_ID = 974002
    private const val STATE_PREFS = "voice_alarm_ringing_state"
    private const val KEY_ACTIVE_PAYLOAD = "activePayload"
    private const val KEY_ACTIVE_AT = "activeAt"
    private const val KEY_VOICE_PLAYBACK_ACTIVE = "voicePlaybackActive"
    private const val KEY_VOICE_PLAYBACK_TEXT = "voicePlaybackText"
    private const val KEY_VOICE_PLAYBACK_AT = "voicePlaybackAt"
    private const val VOICE_PLAYBACK_STATE_TTL_MS = 90_000L
    private const val ACTIVE_PAYLOAD_TTL_MS = 12L * 60L * 60L * 1000L
    const val ACTION_VOICE_PLAYBACK_START = "com.example.quote_app.VOICE_ALARM_VOICE_PLAYBACK_START"
    const val ACTION_VOICE_PLAYBACK_END = "com.example.quote_app.VOICE_ALARM_VOICE_PLAYBACK_END"
    const val ACTION_SIGNAL_PLAYBACK_START = "com.example.quote_app.VOICE_ALARM_SIGNAL_PLAYBACK_START"
    const val ACTION_SIGNAL_PLAYBACK_END = "com.example.quote_app.VOICE_ALARM_SIGNAL_PLAYBACK_END"
    @Volatile private var activePayload: String? = null
    @Volatile private var activeSignalPlayback = false

    @JvmStatic
    fun currentSignalPlaybackState(): Boolean = activeSignalPlayback

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
      // Clear persisted ringing state before attempting to stop.  Notification
      // actions may be delivered while the app is backgrounded/locked, where a
      // fresh startService(ACTION_STOP) can be rejected on Android O+.  stopService
      // is safe and prevents stale activePayload from re-opening the full-screen
      // alarm after the user has dismissed it.
      clearActivePayload(context)
      try { (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION_ID) } catch (_: Throwable) {}
      val intent = Intent(context, VoiceAlarmRingingService::class.java).apply { action = ACTION_STOP }
      try { context.startService(intent) } catch (_: Throwable) {}
      try { context.stopService(Intent(context, VoiceAlarmRingingService::class.java)) } catch (_: Throwable) {}
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
            .putLong(KEY_ACTIVE_AT, System.currentTimeMillis())
            .apply()
        } catch (_: Throwable) {}
      }
    }

    private fun readActivePayload(context: Context): String? {
      for (storageContext in stateContexts(context)) {
        try {
          val prefs = storageContext.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
          val activeAt = prefs.getLong(KEY_ACTIVE_AT, 0L)
          val payload = prefs.getString(KEY_ACTIVE_PAYLOAD, null)
          if (!payload.isNullOrBlank()) {
            if (activeAt > 0L && System.currentTimeMillis() - activeAt <= ACTIVE_PAYLOAD_TTL_MS) return payload
            try { prefs.edit().remove(KEY_ACTIVE_PAYLOAD).remove(KEY_ACTIVE_AT).apply() } catch (_: Throwable) {}
          }
        } catch (_: Throwable) {}
      }
      return null
    }

    @JvmStatic
    fun currentVoicePlaybackState(context: Context): Pair<Boolean, String> {
      for (storageContext in stateContexts(context)) {
        try {
          val prefs = storageContext.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
          val active = prefs.getBoolean(KEY_VOICE_PLAYBACK_ACTIVE, false)
          val activeAt = prefs.getLong(KEY_VOICE_PLAYBACK_AT, 0L)
          val text = prefs.getString(KEY_VOICE_PLAYBACK_TEXT, "") ?: ""
          if (active && activeAt > 0L && System.currentTimeMillis() - activeAt <= VOICE_PLAYBACK_STATE_TTL_MS) {
            return true to text
          }
        } catch (_: Throwable) {}
      }
      return false to ""
    }

    private fun persistVoicePlaybackState(context: Context, active: Boolean, text: String) {
      for (storageContext in stateContexts(context)) {
        try {
          storageContext.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_VOICE_PLAYBACK_ACTIVE, active)
            .putString(KEY_VOICE_PLAYBACK_TEXT, if (active) text else "")
            .putLong(KEY_VOICE_PLAYBACK_AT, if (active) System.currentTimeMillis() else 0L)
            .apply()
        } catch (_: Throwable) {}
      }
    }

    private fun clearActivePayload(context: Context) {
      activePayload = null
      for (storageContext in stateContexts(context)) {
        try {
          storageContext.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_ACTIVE_PAYLOAD)
            .remove(KEY_ACTIVE_AT)
            .remove(KEY_VOICE_PLAYBACK_ACTIVE)
            .remove(KEY_VOICE_PLAYBACK_TEXT)
            .remove(KEY_VOICE_PLAYBACK_AT)
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
    fun ensureAlarmChannel(context: Context) {
      if (Build.VERSION.SDK_INT < 26) return
      val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
      if (existing != null) return
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

    @JvmStatic
    fun isAlarmChannelImportantEnough(context: Context): Boolean {
      if (Build.VERSION.SDK_INT < 26) return true
      return try {
        ensureAlarmChannel(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = notificationManager.getNotificationChannel(CHANNEL_ID) ?: return true
        channel.importance >= NotificationManager.IMPORTANCE_HIGH
      } catch (_: Throwable) {
        true
      }
    }
  }

  private var voicePlayer: MediaPlayer? = null
  private var musicPlayer: MediaPlayer? = null
  private var alarmSignalPlaybackActive = false
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
  private var currentVoiceText: String = ""
  private var voiceReplayBlockedUntil = 0L
  private var alarmVoicePlaybackActive = false
  private var audioFocusRequest: Any? = null

  private fun hasActiveSignalsFor(payload: String): Boolean {
    if (currentPayload != payload) return false
    return musicPlayer != null || voicePlayer != null || alarmTts != null || vibrator != null
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    logVoice("onStartCommand", "service command", mapOf("action" to (intent?.action ?: ""), "startId" to startId))
    if (intent?.action == ACTION_STOP) {
      clearActivePayload(this)
      stopSelf()
      return START_NOT_STICKY
    }
    if (intent?.action == ACTION_POSTPONE_VOICE_REPLAY) {
      postponeVoiceReplay(intent.getLongExtra(EXTRA_POSTPONE_MS, 15_000L))
      return START_STICKY
    }
    val payload = intent?.getStringExtra(EXTRA_PAYLOAD) ?: activePayload ?: readActivePayload(this) ?: "{}"
    val alreadyRingingSamePayload = hasActiveSignalsFor(payload)
    logVoice("start", "alarm service starting", mapOf("alreadyRingingSamePayload" to alreadyRingingSamePayload, "textLen" to (try { JSONObject(payload).optString("text", "").length } catch (_: Throwable) { 0 })))
    persistActivePayload(this, payload)
    startForegroundAlarm(payload)
    acquireWakeLock()
    currentPayload = payload
    if (intent?.getBooleanExtra("fromAlarmFire", false) == true) {
      // Direct foreground-service fallback can be the only path that survives on
      // aggressive OEM ROMs.  Make it self-contained by scheduling the next daily
      // occurrence here too; repeated calls are idempotent because request codes
      // are stable and FLAG_UPDATE_CURRENT is used.
      try { VoiceAlarmScheduler.scheduleNextDaily(this, payload) } catch (_: Throwable) {}
    }
    if (!alreadyRingingSamePayload) {
      startSignals(payload)
    }
    return START_STICKY
  }

  override fun onTaskRemoved(rootIntent: Intent?) {
    // Some launchers call this when the user swipes the full-screen alarm task
    // away.  The service is declared stopWithTask=false, but re-post the
    // foreground alarm notification and keep the audio/vibration alive as an
    // additional OEM-ROM safeguard.
    try { startForegroundAlarm(currentPayload) } catch (_: Throwable) {}
    try { acquireWakeLock() } catch (_: Throwable) {}
    super.onTaskRemoved(rootIntent)
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
    ensureAlarmChannel(this)
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
    var foregroundStarted = false
    if (Build.VERSION.SDK_INT >= 30) {
      try {
        startForeground(
          NOTIFICATION_ID,
          notification,
          ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
        )
        foregroundStarted = true
      } catch (_: Throwable) {
        try {
          startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
          foregroundStarted = true
        } catch (_: Throwable) {
          try {
            startForeground(NOTIFICATION_ID, notification)
            foregroundStarted = true
          } catch (_: Throwable) {}
        }
      }
    } else if (Build.VERSION.SDK_INT >= 29) {
      try {
        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        foregroundStarted = true
      } catch (_: Throwable) {
        try {
          startForeground(NOTIFICATION_ID, notification)
          foregroundStarted = true
        } catch (_: Throwable) {}
      }
    } else {
      try {
        startForeground(NOTIFICATION_ID, notification)
        foregroundStarted = true
      } catch (_: Throwable) {}
    }
    if (!foregroundStarted) {
      try { notificationManager.notify(NOTIFICATION_ID, notification) } catch (_: Throwable) {}
    }
    try { contentIntent.send() } catch (_: Throwable) {}
  }

  private fun acquireWakeLock() {
    try {
      if (wakeLock?.isHeld == true) return
    } catch (_: Throwable) {}
    val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
    wakeLock = manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "quote_app:voiceAlarm").apply {
      setReferenceCounted(false)
      acquire(10 * 60 * 1000L)
    }
  }

  private fun notifyVoicePlaybackStart() {
    if (alarmVoicePlaybackActive) return
    alarmVoicePlaybackActive = true
    persistVoicePlaybackState(this, true, currentVoiceText)
    logVoice("voicePlayback.start", "voice prompt playback started", mapOf("textLen" to currentVoiceText.length))
    sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_START).setPackage(packageName).putExtra("text", currentVoiceText))
  }

  private fun notifyVoicePlaybackEnd() {
    if (!alarmVoicePlaybackActive) return
    alarmVoicePlaybackActive = false
    persistVoicePlaybackState(this, false, currentVoiceText)
    logVoice("voicePlayback.end", "voice prompt playback ended", mapOf("textLen" to currentVoiceText.length))
    sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName).putExtra("text", currentVoiceText))
  }

  private fun randomExistingPath(data: JSONObject, listKey: String, legacyKey: String): String {
    val values = mutableListOf<String>()
    val arr = data.optJSONArray(listKey)
    if (arr != null) {
      for (i in 0 until arr.length()) {
        val path = arr.optString(i, "")
        if (path.isNotBlank() && File(path).isFile) values.add(path)
      }
    }
    val legacy = data.optString(legacyKey, "")
    if (legacy.isNotBlank() && File(legacy).isFile) values.add(legacy)
    return values.distinct().let { if (it.isEmpty()) "" else it[Random.nextInt(it.size)] }
  }

  private fun startSignals(payload: String) {
    stopSignals()
    val data = try { JSONObject(payload) } catch (_: Throwable) { JSONObject() }
    alarmSignalPlaybackActive = true
    activeSignalPlayback = true
    sendBroadcast(Intent(ACTION_SIGNAL_PLAYBACK_START).setPackage(packageName).putExtra("hasMusic", data.optBoolean("systemMusic", true) || data.optString("musicPath", "").isNotBlank() || data.optJSONArray("musicPaths")?.length()?.let { it > 0 } == true))
    logVoice("signals.start", "starting alarm signals", mapOf("hasVoicePath" to data.optString("voicePath", "").isNotBlank(), "textLen" to data.optString("text", "").length, "systemMusic" to data.optBoolean("systemMusic", true), "vibrate" to data.optBoolean("vibrate", true)))
    requestAlarmAudioFocus()
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
    val musicPath = randomExistingPath(data, "musicPaths", "musicPath")
    currentMusicVolume = data.optDouble("musicVolume", 0.4).toFloat().coerceIn(0f, 1f)
    if (musicPath.isNotBlank()) {
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
    currentVoiceText = data.optString("text", "").trim()
    val voicePath = data.optString("voicePath", "")
    logVoice("voice.playOnce", "playing voice prompt", mapOf("hasVoicePath" to voicePath.isNotBlank(), "textLen" to data.optString("text", "").length))
    val volume = data.optDouble("voiceVolume", 1.0).toFloat().coerceIn(0f, 1f)
    if (voicePath.isNotBlank() && File(voicePath).isFile) {
      try { voicePlayer?.stop() } catch (_: Throwable) {}
      try { voicePlayer?.release() } catch (_: Throwable) {}
      voicePlayer = createPlayer(Uri.fromFile(File(voicePath)), false, volume = volume, notifyVoice = true)
      if (voicePlayer != null) return
      // Corrupt/inaccessible custom voice file should not make the alarm silent.
      // Fall through to platform TTS using the saved alarm text.
    }
    // Direct-boot or first-unlock edge case: generated voice files may live in
    // credential-protected app storage and be unreadable even though the alarm
    // payload has been restored from device-protected storage.  Fall back to the
    // platform TTS so the user still hears the alarm text instead of silent music.
    speakAlarmTextOnce(data.optString("text", "语音闹钟时间到了"), volume)
  }

  private fun speakAlarmTextOnce(text: String, volume: Float) {
    val cleanText = text.trim().ifBlank { "语音闹钟时间到了" }
    currentVoiceText = cleanText
    logVoice("voice.tts.speak", "platform alarm TTS requested", mapOf("textLen" to cleanText.length, "volume" to volume))
    if (alarmTtsReady && alarmTts != null) {
      val utteranceId = "alarm_tts_${System.currentTimeMillis()}"
      val params = Bundle().apply { putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume.coerceIn(0f, 1f)) }
      try {
        val result = alarmTts?.speak(cleanText, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
        if (result == null || result == TextToSpeech.ERROR) notifyVoicePlaybackEnd()
      } catch (_: Throwable) {
        notifyVoicePlaybackEnd()
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
            logVoice("voice.tts.onStart", "alarm TTS started", mapOf("utteranceId" to (utteranceId ?: "")))
            notifyVoicePlaybackStart()
          }
          override fun onDone(utteranceId: String?) {
            logVoice("voice.tts.onDone", "alarm TTS completed", mapOf("utteranceId" to (utteranceId ?: "")))
            notifyVoicePlaybackEnd()
          }
          @Deprecated("Deprecated in Java")
          override fun onError(utteranceId: String?) {
            logVoice("voice.tts.onError", "alarm TTS error", mapOf("utteranceId" to (utteranceId ?: "")))
            notifyVoicePlaybackEnd()
          }
          override fun onError(utteranceId: String?, errorCode: Int) {
            logVoice("voice.tts.onError", "alarm TTS error", mapOf("utteranceId" to (utteranceId ?: ""), "errorCode" to errorCode))
            notifyVoicePlaybackEnd()
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
        try { alarmTts?.shutdown() } catch (_: Throwable) {}
        alarmTts = null
        notifyVoicePlaybackEnd()
      }
    }
  }

  private fun scheduleVoiceReplay(initialData: JSONObject) {
    replayRunnable?.let { replayHandler.removeCallbacks(it) }
    val fallbackData = initialData
    val seconds = initialData.optInt("replayIntervalSeconds", 60).coerceIn(15, 3600)
    replayRunnable = Runnable {
      val latest = latestVoiceReplayPayload(fallbackData)
      val blockedMs = voiceReplayBlockedUntil - System.currentTimeMillis()
      if (blockedMs > 0) {
        replayHandler.postDelayed(replayRunnable!!, blockedMs.coerceAtLeast(1000L))
        return@Runnable
      }
      playVoiceOnce(latest)
      scheduleVoiceReplay(latest)
    }
    replayHandler.postDelayed(replayRunnable!!, seconds * 1000L)
  }

  private fun latestVoiceReplayPayload(fallbackData: JSONObject): JSONObject {
    return try { JSONObject(currentPayload) } catch (_: Throwable) { fallbackData }
  }

  private fun postponeVoiceReplay(postponeMs: Long) {
    val safePostponeMs = postponeMs.coerceIn(1000L, 180_000L)
    voiceReplayBlockedUntil = maxOf(voiceReplayBlockedUntil, System.currentTimeMillis() + safePostponeMs)
    try { voicePlayer?.stop() } catch (_: Throwable) {}
    try { voicePlayer?.release() } catch (_: Throwable) {}
    try { alarmTts?.stop() } catch (_: Throwable) {}
    pendingAlarmTts = null
    notifyVoicePlaybackEnd()
    voicePlayer = null
    duckMusicFor(safePostponeMs.coerceAtMost(30_000L))
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
        setOnPreparedListener { player ->
          try {
            logVoice("media.prepared", "MediaPlayer prepared", mapOf("notifyVoice" to notifyVoice, "looping" to looping, "volume" to volume))
            if (notifyVoice) notifyVoicePlaybackStart()
            player.start()
          } catch (t: Throwable) {
            logVoice("media.start.error", t.message ?: t.javaClass.simpleName, mapOf("notifyVoice" to notifyVoice))
            if (notifyVoice) notifyVoicePlaybackEnd()
            try { player.release() } catch (_: Throwable) {}
          }
        }
        setOnCompletionListener {
          logVoice("media.completion", "MediaPlayer completed", mapOf("notifyVoice" to notifyVoice))
          if (notifyVoice) notifyVoicePlaybackEnd()
        }
        setOnErrorListener { player, what, extra ->
          logVoice("media.error", "MediaPlayer error", mapOf("notifyVoice" to notifyVoice, "what" to what, "extra" to extra))
          if (notifyVoice) notifyVoicePlaybackEnd()
          try { player.release() } catch (_: Throwable) {}
          true
        }
        try { setWakeMode(this@VoiceAlarmRingingService, PowerManager.PARTIAL_WAKE_LOCK) } catch (_: Throwable) {}
        prepareAsync()
      }
    } catch (_: Throwable) {
      null
    }
  }

  private fun stopSignals() {
    val shouldNotifySignalEnd = alarmSignalPlaybackActive
    alarmSignalPlaybackActive = false
    activeSignalPlayback = false
    if (shouldNotifySignalEnd) sendBroadcast(Intent(ACTION_SIGNAL_PLAYBACK_END).setPackage(packageName))
    logVoice("signals.stop", "stopping alarm signals")
    try { voicePlayer?.stop() } catch (_: Throwable) {}
    try { voicePlayer?.release() } catch (_: Throwable) {}
    try { alarmTts?.stop() } catch (_: Throwable) {}
    try { alarmTts?.shutdown() } catch (_: Throwable) {}
    try { musicPlayer?.stop() } catch (_: Throwable) {}
    try { musicPlayer?.release() } catch (_: Throwable) {}
    try { vibrator?.cancel() } catch (_: Throwable) {}
    notifyVoicePlaybackEnd()
    voicePlayer = null
    alarmTts = null
    alarmTtsReady = false
    pendingAlarmTts = null
    musicPlayer = null
    currentMusicVolume = 0.4f
    vibrator = null
    abandonAlarmAudioFocus()
  }


  private fun requestAlarmAudioFocus() {
    try {
      val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
      if (Build.VERSION.SDK_INT >= 26) {
        val attrs = AudioAttributes.Builder()
          .setUsage(AudioAttributes.USAGE_ALARM)
          .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
          .build()
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
          .setAudioAttributes(attrs)
          .setOnAudioFocusChangeListener { /* Alarm playback keeps running; user must dismiss/snooze. */ }
          .build()
        audio.requestAudioFocus(request)
        audioFocusRequest = request
      } else {
        @Suppress("DEPRECATION")
        audio.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
      }
    } catch (_: Throwable) {}
  }

  private fun abandonAlarmAudioFocus() {
    try {
      val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
      if (Build.VERSION.SDK_INT >= 26) {
        (audioFocusRequest as? AudioFocusRequest)?.let { audio.abandonAudioFocusRequest(it) }
      } else {
        @Suppress("DEPRECATION")
        audio.abandonAudioFocus(null)
      }
    } catch (_: Throwable) {}
    audioFocusRequest = null
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
