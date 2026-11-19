package com.example.quote_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
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
    private val musicState = VoiceAlarmMusicState()
    @Volatile var outputEpoch = 0L
      private set
    @Volatile private var voiceOutput = false
    @Volatile private var lastOutputChangeAt = -1000L
    fun outputKind(): String = when {
      voiceOutput -> "voice"
      activeSignalPlayback -> "music"
      android.os.SystemClock.elapsedRealtime() - lastOutputChangeAt < 350L -> "tail"
      else -> "quiet"
    }
    fun outputOrTailActive(): Boolean = outputKind() != "quiet"
    private fun outputChanged() {
      lastOutputChangeAt = android.os.SystemClock.elapsedRealtime()
      outputEpoch++
    }
    private var service: VoiceAlarmRingingService? = null
    val appReplySpeaking: Boolean get() = musicState.speaking(VoiceAlarmMusicState.Speaker.ASSISTANT)
    private val microphoneInUse: Boolean get() = musicState.speaking(VoiceAlarmMusicState.Speaker.LISTEN_REQUEST) ||
      musicState.speaking(VoiceAlarmMusicState.Speaker.USER)

    fun setSpeaking(speaker: VoiceAlarmMusicState.Speaker, owner: Any, active: Boolean) {
      if (musicState.setSpeaking(speaker, owner, active)) {
        if (speaker == VoiceAlarmMusicState.Speaker.REMINDER || speaker == VoiceAlarmMusicState.Speaker.ASSISTANT) {
          voiceOutput = musicState.speaking(VoiceAlarmMusicState.Speaker.REMINDER) || appReplySpeaking
          outputChanged()
        }
        service?.applyMusicGain()
      }
    }

    @Volatile var liveVoiceText: String? = null
      private set
    private const val ACTION_MUSIC = "com.example.quote_app.VOICE_ALARM_MUSIC"
    const val ACTION_VOICE_PLAYBACK_ERROR = "com.example.quote_app.VOICE_ALARM_VOICE_PLAYBACK_ERROR"
    @JvmStatic fun setBackgroundMusic(context: Context, enabled: Boolean) {
      if (activePayload == null) return
      context.startService(Intent(context, VoiceAlarmRingingService::class.java).apply {
        action = ACTION_MUSIC; putExtra("enabled", enabled)
      })
    }
    const val ACTION_ROUND_STATUS = "com.example.quote_app.VOICE_ALARM_ROUND_STATUS"
    @Volatile var roundStatus: String = ""; private set
    const val ACTION_DISMISSED = "com.example.quote_app.VOICE_ALARM_DISMISSED"
    private const val ACTION_SET_VOLUMES = "com.example.quote_app.VOICE_ALARM_SET_VOLUMES"
    @JvmStatic fun setPlaybackVolumes(context: Context, voice: Float, music: Float) {
      if (activePayload == null) return
      try { context.startService(Intent(context, VoiceAlarmRingingService::class.java).apply {
        action = ACTION_SET_VOLUMES; putExtra("voice", voice); putExtra("music", music)
      }) } catch (_: Exception) {}
    }
    private const val ACTION_START = "com.example.quote_app.VOICE_ALARM_START"
    private const val ACTION_STOP = "com.example.quote_app.VOICE_ALARM_STOP"
    private const val ACTION_ENABLE_MICROPHONE = "com.example.quote_app.VOICE_ALARM_ENABLE_MICROPHONE"
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
    fun enableVoiceInteraction(context: Context) {
      // Android 14 can deny microphone FGS type at the alarm's background start.
      // Retry only after the user-visible Activity is resumed and permission exists.
      if (context.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != android.content.pm.PackageManager.PERMISSION_GRANTED) return
      try {
        context.startService(Intent(context, VoiceAlarmRingingService::class.java).setAction(ACTION_ENABLE_MICROPHONE))
      } catch (_: Throwable) {}
    }

    @JvmStatic
    fun stop(context: Context) {
      // Clear persisted ringing state before attempting to stop.  Notification
      // actions may be delivered while the app is backgrounded/locked, where a
      // fresh startService(ACTION_STOP) can be rejected on Android O+.  stopService
      // is safe and prevents stale activePayload from re-opening the full-screen
      // alarm after the user has dismissed it.
      clearActivePayload(context)
      activeSignalPlayback = false
      context.sendBroadcast(Intent(ACTION_DISMISSED).setPackage(context.packageName))
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
      // Service state, not guessed duration, is authoritative for a long prompt.
      liveVoiceText?.let { return true to it }
      if (activePayload != null) return false to ""
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
    fun postponeVoiceReplay(context: Context, postponeMs: Long, interrupt: Boolean = false) {
      try {
        context.startService(Intent(context, VoiceAlarmRingingService::class.java).apply {
          action = ACTION_POSTPONE_VOICE_REPLAY
          putExtra(EXTRA_POSTPONE_MS, postponeMs)
          putExtra("interrupt", interrupt)
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

  private val voiceQueue = VoiceAlarmPlaybackQueue()
  private var voiceChunkWatchdog: Runnable? = null
  private val wakeupGate = VoiceAlarmReplyGate()
  private var wakeSession: VoiceAlarmWakeSession? = null
  private var roundBusy = false
  @Volatile private var roundClient: VoiceAlarmAiClient? = null
  private var readyRoundRunnable: Runnable? = null
  private val ttsInitGate = VoiceAlarmReplyGate()
  private var stopping = false
  private var currentVoiceVolume = 1f
  private var voicePlayer: MediaPlayer? = null
  private var musicPlayer: MediaPlayer? = null
  private var alarmSignalPlaybackActive = false
  private var alarmTts: TextToSpeech? = null
  private var alarmTtsReady = false
  private var alarmTtsSequence = 0L
  @Volatile private var alarmTtsPrefix = ""
  @Volatile private var alarmTtsLastId = ""
  private var pendingAlarmTts: Pair<String, Float>? = null
  private var vibrator: Vibrator? = null
  private var wakeLock: PowerManager.WakeLock? = null
  private var headsetPlaybackModeActive = false
  private var musicPrepared = false
  private var lastMusicGain: Float? = null
  private var currentMusicVolume = 0.4f
  private val replayHandler = Handler(Looper.getMainLooper())
  private var replayRunnable: Runnable? = null
  private var currentPayload: String = "{}"
  private var currentVoiceText: String = ""
  private var voiceReplayBlockedUntil = 0L
  private var alarmVoicePlaybackActive = false
  private var audioFocusRequest: Any? = null
  private var audioDeviceCallback: AudioDeviceCallback? = null

  private fun hasActiveSignalsFor(payload: String): Boolean {
    if (currentPayload != payload) return false
    return musicPlayer != null || voicePlayer != null || alarmTts != null || vibrator != null
  }

  override fun onCreate() {
    super.onCreate()
    service = this
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    logVoice("onStartCommand", "service command", mapOf("action" to (intent?.action ?: ""), "startId" to startId))
    if (intent?.action == ACTION_STOP) {
      stopping = true
      wakeupGate.next()
      clearActivePayload(this)
      stopSignals()
      stopSelf()
      return START_NOT_STICKY
    }
    if (intent?.action == ACTION_MUSIC) {
      if (activePayload == null) { stopSelf(startId); return START_NOT_STICKY }
      musicState.choose(intent.getBooleanExtra("enabled", false))
      if (musicState.enabled && musicPlayer == null) {
        val data = JSONObject(currentPayload)
        val path = randomExistingPath(data, "musicPaths", "musicPath")
        val uri = if (path.isNotBlank()) Uri.fromFile(File(path)) else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        if (uri != null) musicPlayer = createPlayer(uri, true, currentMusicVolume)
      }
      applyMusicGain()
      if (musicPrepared) {
        try { if (musicState.enabled) musicPlayer?.start() else musicPlayer?.pause() } catch (_: Exception) {}
      }
      applyMusicGain()
      return START_STICKY
    }
    if (intent?.action == ACTION_SET_VOLUMES) {
      if (activePayload == null) { stopSelf(startId); return START_NOT_STICKY }
      val previousVoiceVolume = currentVoiceVolume
      currentVoiceVolume = intent.getFloatExtra("voice", currentVoiceVolume).coerceIn(0f, 1f)
      currentMusicVolume = intent.getFloatExtra("music", currentMusicVolume).coerceIn(0f, 1f)
      val data = try { JSONObject(currentPayload) } catch (_: Exception) { JSONObject() }
      data.put("voiceVolume", currentVoiceVolume).put("musicVolume", currentMusicVolume)
      currentPayload = data.toString()
      try { voicePlayer?.setVolume(currentVoiceVolume, currentVoiceVolume) } catch (_: Exception) {}
      applyMusicGain()
      // Apply gain by replaying only the unacknowledged chunk, retaining the rest.
      if (currentVoiceVolume != previousVoiceVolume && alarmVoicePlaybackActive && voicePlayer == null && !appReplySpeaking) resumeAlarmChunk()
      return START_STICKY
    }
    if (intent?.action == ACTION_ENABLE_MICROPHONE) {
      val payload = activePayload ?: readActivePayload(this)
      if (payload == null) {
        stopSelf(startId)
        return START_NOT_STICKY
      }
      startForegroundAlarm(payload, openActivity = false)
      return START_STICKY
    }
    if (intent?.action == ACTION_POSTPONE_VOICE_REPLAY) {
      postponeVoiceReplay(intent.getLongExtra(EXTRA_POSTPONE_MS, 15_000L), intent.getBooleanExtra("interrupt", false))
      return START_STICKY
    }
    val payload = intent?.getStringExtra(EXTRA_PAYLOAD) ?: activePayload ?: readActivePayload(this) ?: "{}"
    val alreadyRingingSamePayload = hasActiveSignalsFor(payload)
    logVoice("start", "alarm service starting", mapOf("alreadyRingingSamePayload" to alreadyRingingSamePayload, "textLen" to (try { JSONObject(payload).optString("text", "").length } catch (_: Throwable) { 0 })))
    stopping = false
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
    if (stopping || activePayload == null) { super.onTaskRemoved(rootIntent); return }
    // Some launchers call this when the user swipes the full-screen alarm task
    // away.  The service is declared stopWithTask=false, but re-post the
    // foreground alarm notification and keep the audio/vibration alive as an
    // additional OEM-ROM safeguard.
    try { startForegroundAlarm(currentPayload) } catch (_: Throwable) {}
    try { acquireWakeLock() } catch (_: Throwable) {}
    super.onTaskRemoved(rootIntent)
  }

  override fun onDestroy() {
    stopping = true
    wakeupGate.next()
    activePayload = null
    stopSignals()
    replayRunnable?.let { replayHandler.removeCallbacks(it) }
    replayRunnable = null
    try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Throwable) {}
    wakeLock = null
    unregisterHeadsetRouteCallback()
    if (service === this) service = null
    super.onDestroy()
  }

  /**
   * When a wired/Bluetooth headset is present, route alarm voice + background music only to it
   * instead of Android's default "also play on the speaker" alarm behavior, and keep re-applying
   * that choice whenever the set of connected audio devices changes mid-alarm (headset plugged in
   * or removed while ringing).
   */
  private fun registerHeadsetRouteCallback() {
    if (audioDeviceCallback != null) return
    val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
    val callback = object : AudioDeviceCallback() {
      override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) = onConnectedAudioDevicesChanged()
      override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) = onConnectedAudioDevicesChanged()
    }
    try {
      audio.registerAudioDeviceCallback(callback, Handler(Looper.getMainLooper()))
      audioDeviceCallback = callback
    } catch (_: Throwable) {}
  }

  private fun unregisterHeadsetRouteCallback() {
    val callback = audioDeviceCallback ?: return
    audioDeviceCallback = null
    try {
      (getSystemService(Context.AUDIO_SERVICE) as? AudioManager)?.unregisterAudioDeviceCallback(callback)
    } catch (_: Throwable) {}
  }

  /**
   * USAGE_ALARM is "enforced audible": the platform always adds the speaker to the routed
   * devices for that strategy no matter what, so a connected headset never gets exclusive
   * playback (see VoiceAlarmAudioRoute's kdoc). Falling back to USAGE_MEDIA while a headset is
   * connected uses Android's normal, non-enforced device selection, which routes to the
   * connected wired/USB/Bluetooth device only - exactly the behavior every media app gets when
   * headphones are plugged in.
   */
  private fun headsetOutputConnected(): Boolean = VoiceAlarmAudioRoute.hasHeadsetOutput(this)

  private fun playbackUsage(): Int = if (headsetOutputConnected()) AudioAttributes.USAGE_MEDIA else AudioAttributes.USAGE_ALARM

  private fun playbackStream(): Int = if (headsetOutputConnected()) AudioManager.STREAM_MUSIC else AudioManager.STREAM_ALARM

  private fun applyPreferredOutputDevice(player: MediaPlayer?) {
    if (player == null) return
    try {
      val device = VoiceAlarmAudioRoute.preferredOutputDevice(this)
      val applied = player.setPreferredDevice(device)
      logVoice("audioRoute.apply", "applied preferred output device to player", mapOf("deviceType" to (device?.type ?: -1), "applied" to applied))
    } catch (_: Throwable) {}
  }

  private fun onConnectedAudioDevicesChanged() {
    val headsetNow = headsetOutputConnected()
    if (headsetNow == headsetPlaybackModeActive) {
      // Same routing mode (e.g. switching between two Bluetooth devices); just re-pin the
      // preferred device on the already-correctly-configured players.
      logVoice("audioRoute.deviceListChanged", "connected audio device set changed; headset mode unchanged, reapplying preferred device")
      applyPreferredOutputDevice(voicePlayer)
      applyPreferredOutputDevice(musicPlayer)
      return
    }
    // Headset presence flipped mid-ring: USAGE_ALARM vs USAGE_MEDIA can only be chosen when a
    // player/TTS engine/audio-focus request is (re)created, so rebuild playback from scratch
    // with the attributes that match the new state instead of trying to hot-swap them.
    logVoice("audioRoute.modeChanged", "headset presence changed mid-ring; rebuilding playback with matching audio attributes", mapOf("headsetNow" to headsetNow))
    if (wakeSession == null) { startSignals(currentPayload); return }
    headsetPlaybackModeActive = headsetNow
    requestAlarmAudioFocus()
    try { alarmTts?.setAudioAttributes(AudioAttributes.Builder().setUsage(playbackUsage()).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()) } catch (_: Throwable) {}
    if (voiceQueue.pending) { try { alarmTts?.stop() } catch (_: Throwable) {}; resumeAlarmChunk() }
    val data = latestVoiceReplayPayload(JSONObject())
    val musicPath = randomExistingPath(data, "musicPaths", "musicPath")
    val uri = if (musicPath.isNotBlank()) Uri.fromFile(File(musicPath)) else if (data.optBoolean("systemMusic", true)) RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) else null
    try { musicPlayer?.release() } catch (_: Throwable) {}
    musicPlayer = uri?.let { createPlayer(it, true, musicState.gain(currentMusicVolume)) }
  }

  private fun startForegroundAlarm(payload: String, openActivity: Boolean = true) {
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
    if (openActivity) try { contentIntent.send() } catch (_: Throwable) {}
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
    if (stopping || !alarmSignalPlaybackActive || activePayload == null) return
    if (alarmVoicePlaybackActive) return
    alarmVoicePlaybackActive = true
    setSpeaking(VoiceAlarmMusicState.Speaker.REMINDER, this, true)
    wakeSession?.markPlayback("已开始播报")
    liveVoiceText = currentVoiceText
    persistVoicePlaybackState(this, true, currentVoiceText)
    logVoice("voicePlayback.start", "voice prompt playback started", mapOf("textLen" to currentVoiceText.length))
    sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_START).setPackage(packageName).putExtra("text", currentVoiceText))
  }

  private fun notifyVoicePlaybackEnd(completed: Boolean = false) {
    setSpeaking(VoiceAlarmMusicState.Speaker.REMINDER, this, false)
    if (!alarmVoicePlaybackActive) return
    try { vibrator?.cancel() } catch (_: Throwable) {}
    alarmVoicePlaybackActive = false
    liveVoiceText = null
    persistVoicePlaybackState(this, false, currentVoiceText)
    logVoice("voicePlayback.end", "voice prompt playback ended", mapOf("textLen" to currentVoiceText.length))
    sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_END).setPackage(packageName)
      .putExtra("text", currentVoiceText).putExtra("completed", completed))
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
    lastMusicGain = null
    musicState.choose(true)
    val data = try { JSONObject(payload) } catch (_: Throwable) { JSONObject() }
    alarmSignalPlaybackActive = true
    activeSignalPlayback = false
    headsetPlaybackModeActive = headsetOutputConnected()
    registerHeadsetRouteCallback()
    logVoice("signals.start", "starting alarm signals", mapOf("hasVoicePath" to data.optString("voicePath", "").isNotBlank(), "textLen" to data.optString("text", "").length, "systemMusic" to data.optBoolean("systemMusic", true), "vibrate" to data.optBoolean("vibrate", true)))
    requestAlarmAudioFocus()
    // Respect manually selected system alarm/media volume; never raise it behind the user.
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
    currentVoiceVolume = data.optDouble("voiceVolume", 1.0).toFloat().coerceIn(0f, 1f)
    val adaptive = data.optBoolean("adaptiveWakeupEnabled", data.optString("mode") != "night")
    if (adaptive || data.optBoolean("aiWakeupEnabled", false)) {
      wakeSession = VoiceAlarmWakeSession(data.optString("text"), adaptive)
      requestWakeRound(data)
    } else if (hasVoicePrompt(data)) {
      playVoiceOnce(data)
      scheduleVoiceReplay(data)
    }
  }

  private fun reportRoundStatus(value: String) {
    roundStatus = value
    sendBroadcast(Intent(ACTION_ROUND_STATUS).setPackage(packageName).putExtra("status", value))
  }

  private fun requestWakeRound(data: JSONObject) {
    val session = wakeSession ?: return
    if (roundBusy || !session.active || stopping || activePayload == null) return
    roundBusy = true
    val token = wakeupGate.next()
    val client = VoiceAlarmAiClient()
    roundClient = client
    reportRoundStatus("正在准备第 ${session.nextNumber} 轮起床提醒…")
    Thread {
      val adaptive = data.optBoolean("adaptiveWakeupEnabled", data.optString("mode") != "night")
      val useRemote = data.optBoolean("aiWakeupEnabled", false)
      val date = VoiceAlarmWakeupClient.beijingDate()
      if (useRemote && session.needsRemote(date, android.os.SystemClock.elapsedRealtime())) {
        val day = try { VoiceAlarmWakeupStore.fetchDay(this) } catch (_: Exception) { null }
        session.rememberRemote(date, android.os.SystemClock.elapsedRealtime(), day)
      }
      val goals = if (adaptive) VoiceAlarmGoalReader.read(this) else emptyList()
      val prepared = (if (useRemote) session.remoteForRound(date) else null) ?: if (!adaptive) {
        VoiceAlarmWakeSession.Prepared(data.optString("text"), "original")
      } else try {
        val cfg = data.optJSONObject("aiConfig") ?: JSONObject()
        session.prepare(goals, null) { messages -> client.request(cfg, messages, false).text }
      } catch (_: Exception) {
        val ideas = listOf("先不要求自己精神饱满。现在坐起，把双脚放到地上。", "你仍然可以选择从很小的一步开始：离开枕头，坐到床边。", "把今天的决定落到一个动作：站起来，走向水杯。")
        VoiceAlarmWakeSession.Prepared(ideas[(session.nextNumber - 1) % ideas.size], "local_fallback")
      }
      replayHandler.post {
        if (!wakeupGate.isCurrent(token) || !session.active || stopping || activePayload == null) return@post
        roundClient = null
        // A late model response must not talk over an ongoing user conversation.
        readyRoundRunnable = object : Runnable {
          override fun run() {
            if (!wakeupGate.isCurrent(token) || !session.active || stopping || activePayload == null) return
            val remaining = voiceReplayBlockedUntil - System.currentTimeMillis()
            if (appReplySpeaking || microphoneInUse || alarmVoicePlaybackActive || remaining > 0) {
              replayHandler.postDelayed(this, if (remaining > 0) remaining else 500L); return
            }
            readyRoundRunnable = null; roundBusy = false
            if (prepared.source.startsWith("ai_wakeup") && date != VoiceAlarmWakeupClient.beijingDate()) {
              requestWakeRound(data)
              return
            }
            val round = session.accept(prepared.motivation, goals, prepared.source, prepared.task?.id)
            val latest = latestVoiceReplayPayload(data).put("text", round.body)
            if (prepared.source != "original") latest.put("voicePath", "")
            val status = when (prepared.source) {
              "ai_wakeup_task" -> prepared.task?.let { listOf(it.scheduledTime, it.title).filter(String::isNotBlank).joinToString(" ") }.orEmpty()
              "ai_wakeup" -> "AI Wakeup 当日原文"
              "ai" -> "AI 调整起床策略"
              "local_fallback" -> "本地动作提示"
              else -> ""
            }
            if (status.isNotBlank()) reportRoundStatus("第 ${round.number} 轮 · $status")
            if (hasVoicePrompt(latest)) playVoiceOnce(latest)
            scheduleVoiceReplay(data)
          }
        }
        readyRoundRunnable!!.run()
      }
    }.apply { name = "voice-wake-round"; isDaemon = true }.start()
  }

  private fun hasVoicePrompt(data: JSONObject): Boolean {
    val voicePath = data.optString("voicePath", "")
    return (voicePath.isNotBlank() && File(voicePath).isFile) || data.optString("text", "").isNotBlank()
  }

  private fun playVoiceOnce(data: JSONObject) {
    if (voiceQueue.pending && voiceQueue.fullText == data.optString("text", "").trim()) {
      resumeAlarmChunk(); return
    }
    currentVoiceText = data.optString("text", "").trim()
    val voicePath = data.optString("voicePath", "")
    logVoice("voice.playOnce", "playing voice prompt", mapOf("hasVoicePath" to voicePath.isNotBlank(), "textLen" to data.optString("text", "").length))
    val volume = data.optDouble("voiceVolume", currentVoiceVolume.toDouble()).toFloat().coerceIn(0f, 1f)
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
    if (stopping || !alarmSignalPlaybackActive || activePayload == null) return
    val cleanText = text.trim().ifBlank { "语音闹钟时间到了" }
    currentVoiceText = cleanText
    logVoice("voice.tts.speak", "platform alarm TTS requested", mapOf("textLen" to cleanText.length, "volume" to volume))
    if (alarmTtsReady && alarmTts != null) {
      // Re-apply attributes on every utterance (not just at engine construction time) so a
      // headset plugged/unplugged since the engine was created is reflected on this replay.
      try {
        alarmTts?.setAudioAttributes(
          AudioAttributes.Builder()
            .setUsage(playbackUsage())
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build(),
        )
      } catch (_: Throwable) {}
      voiceQueue.start(cleanText, minOf(180, TextToSpeech.getMaxSpeechInputLength()))
      playAlarmChunk()
      return
    }
    pendingAlarmTts = cleanText to volume
    if (alarmTts != null) return
    val initToken = ttsInitGate.next()
    alarmTts = TextToSpeech(this) { status ->
      if (!ttsInitGate.isCurrent(initToken) || stopping || !alarmSignalPlaybackActive) return@TextToSpeech
      if (status == TextToSpeech.SUCCESS) {
        alarmTtsReady = true
        try { alarmTts?.language = Locale.CHINA } catch (_: Throwable) {}
        if (Build.VERSION.SDK_INT >= 21) {
          try {
            alarmTts?.setAudioAttributes(
              AudioAttributes.Builder()
                .setUsage(playbackUsage())
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build(),
            )
          } catch (_: Throwable) {}
        }
        alarmTts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
          override fun onStart(utteranceId: String?) { replayHandler.post {
            if (utteranceId == voiceQueue.current?.id) notifyVoicePlaybackStart()
          } }
          override fun onDone(utteranceId: String?) { replayHandler.post {
            if (voiceQueue.done(utteranceId)) {
              if (voiceQueue.pending) playAlarmChunk() else {
                voiceChunkWatchdog?.let { replayHandler.removeCallbacks(it) }
                voiceChunkWatchdog = null
                wakeSession?.markPlayback("完整播报完成")
                notifyVoicePlaybackEnd(completed = true)
              }
            }
          } }
          @Deprecated("Deprecated in Java")
          override fun onError(utteranceId: String?) { replayHandler.post { failAlarmChunk(utteranceId) } }
          override fun onError(utteranceId: String?, errorCode: Int) { replayHandler.post { failAlarmChunk(utteranceId) } }
        })
        val pending = pendingAlarmTts
        pendingAlarmTts = null
        if (pending != null) {
          replayHandler.post { speakAlarmTextOnce(pending.first, currentVoiceVolume) }
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

  private fun resumeAlarmChunk() {
    voiceQueue.resume()
    try { alarmTts?.stop() } catch (_: Throwable) {}
    playAlarmChunk()
  }

  private fun playAlarmChunk() {
    val item = voiceQueue.current ?: return
    if (stopping || activePayload == null) return
    val params = Bundle().apply { putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, currentVoiceVolume) }
    voiceChunkWatchdog?.let { replayHandler.removeCallbacks(it) }
    voiceChunkWatchdog = Runnable { failAlarmChunk(item.id) }
    replayHandler.postDelayed(voiceChunkWatchdog!!, 15_000L + item.text.length * 800L)
    setSpeaking(VoiceAlarmMusicState.Speaker.REMINDER, this, true)
    val result = try { alarmTts?.speak(item.text, TextToSpeech.QUEUE_FLUSH, params, item.id) } catch (_: Throwable) { TextToSpeech.ERROR }
    if (result == null || result == TextToSpeech.ERROR) failAlarmChunk(item.id)
  }

  private fun failAlarmChunk(id: String?) {
    if (id == null || id != voiceQueue.current?.id) return
    voiceChunkWatchdog?.let { replayHandler.removeCallbacks(it) }; voiceChunkWatchdog = null
    if (voiceQueue.retry(id) != null) {
      val retryId = voiceQueue.current?.id
      replayHandler.postDelayed({ if (!stopping && voiceQueue.current?.id == retryId) playAlarmChunk() }, 500L)
    } else {
      voiceQueue.resume()
      wakeSession?.markPlayback("语音引擎失败，未播完")
      notifyVoicePlaybackEnd()
      sendBroadcast(Intent(ACTION_VOICE_PLAYBACK_ERROR).setPackage(packageName))
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
      // AI 回复正在播报时，不要让提醒语音（早上好…/晚上好…）同时响起；
      // 稍后再查，等这条 AI 回复播完再复读。
      if (appReplySpeaking || microphoneInUse || alarmVoicePlaybackActive || pendingAlarmTts != null) {
        replayHandler.postDelayed(replayRunnable!!, 1500L)
        return@Runnable
      }
      if (wakeSession != null && voiceQueue.pending) {
        resumeAlarmChunk(); scheduleVoiceReplay(latest)
      } else if (wakeSession != null) {
        requestWakeRound(latest)
      } else {
        playVoiceOnce(latest)
        scheduleVoiceReplay(latest)
      }
    }
    replayHandler.postDelayed(replayRunnable!!, seconds * 1000L)
  }

  private fun latestVoiceReplayPayload(fallbackData: JSONObject): JSONObject {
    return try { JSONObject(currentPayload) } catch (_: Throwable) { fallbackData }
  }

  private fun postponeVoiceReplay(postponeMs: Long, interrupt: Boolean = false) {
    val safePostponeMs = postponeMs.coerceIn(1000L, 180_000L)
    voiceReplayBlockedUntil = maxOf(voiceReplayBlockedUntil, System.currentTimeMillis() + safePostponeMs)
    if (!interrupt) return // postpone next repeat without cutting off this prompt
    logVoice("voice.interrupt", "stopping playback for barge-in", mapOf("voiceActive" to alarmVoicePlaybackActive))
    if (alarmVoicePlaybackActive || voiceQueue.pending) wakeSession?.markPlayback("用户插话中断，未保证听完")
    if (wakeSession != null) voiceQueue.cancel()
    voiceQueue.resume()
    voiceChunkWatchdog?.let { replayHandler.removeCallbacks(it) }; voiceChunkWatchdog = null
    try { voicePlayer?.stop() } catch (_: Throwable) {}
    try { voicePlayer?.release() } catch (_: Throwable) {}
    try { alarmTts?.stop() } catch (_: Throwable) {}
    pendingAlarmTts = null
    notifyVoicePlaybackEnd()
    voicePlayer = null
  }

  private fun applyMusicGain() {
    val gain = musicState.gain(currentMusicVolume)
    if (gain != lastMusicGain && alarmSignalPlaybackActive) {
      lastMusicGain = gain
      logVoice("music.gain", "background music gain", mapOf("gain" to gain, "configured" to currentMusicVolume))
    }
    try { musicPlayer?.setVolume(gain, gain) } catch (_: Throwable) {}
    val audible = alarmSignalPlaybackActive && gain > 0f && runCatching { musicPlayer?.isPlaying == true }.getOrDefault(false)
    if (activeSignalPlayback == audible) return
    activeSignalPlayback = audible
    outputChanged()
    sendBroadcast(Intent(if (audible) ACTION_SIGNAL_PLAYBACK_START else ACTION_SIGNAL_PLAYBACK_END)
      .setPackage(packageName).putExtra("hasMusic", audible))
  }

  private fun createPlayer(uri: Uri, looping: Boolean, volume: Float = 0.75f, notifyVoice: Boolean = false): MediaPlayer? {
    if (looping) musicPrepared = false
    return try {
      MediaPlayer().apply {
        setAudioAttributes(
          AudioAttributes.Builder()
            .setUsage(playbackUsage())
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build(),
        )
        setDataSource(this@VoiceAlarmRingingService, uri)
        isLooping = looping
        val initialGain = if (looping) musicState.gain(currentMusicVolume) else volume
        setVolume(initialGain, initialGain)
        applyPreferredOutputDevice(this)
        setOnPreparedListener { player ->
          try {
            logVoice("media.prepared", "MediaPlayer prepared", mapOf("notifyVoice" to notifyVoice, "looping" to looping, "volume" to volume))
            if (notifyVoice && player !== voicePlayer) return@setOnPreparedListener
            if (notifyVoice) notifyVoicePlaybackStart()
            if (looping) {
              if (player !== musicPlayer) return@setOnPreparedListener
              musicPrepared = true
              val gain = musicState.gain(currentMusicVolume)
              player.setVolume(gain, gain)
            }
            if (looping && !musicState.enabled) return@setOnPreparedListener
            player.start()
            if (looping) applyMusicGain()
          } catch (t: Throwable) {
            logVoice("media.start.error", t.message ?: t.javaClass.simpleName, mapOf("notifyVoice" to notifyVoice))
            if (notifyVoice && player === voicePlayer) notifyVoicePlaybackEnd()
            try { player.release() } catch (_: Throwable) {}
          }
        }
        setOnCompletionListener { player ->
          logVoice("media.completion", "MediaPlayer completed", mapOf("notifyVoice" to notifyVoice))
          if (notifyVoice && player === voicePlayer) notifyVoicePlaybackEnd(completed = true)
        }
        setOnErrorListener { player, what, extra ->
          if (looping && player === musicPlayer) { musicPrepared = false; musicPlayer = null; applyMusicGain() }
          logVoice("media.error", "MediaPlayer error", mapOf("notifyVoice" to notifyVoice, "what" to what, "extra" to extra))
          if (notifyVoice && player === voicePlayer) notifyVoicePlaybackEnd()
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
    wakeSession?.close(); wakeSession = null
    roundClient?.cancel(); roundClient = null; roundBusy = false
    readyRoundRunnable?.let { replayHandler.removeCallbacks(it) }; readyRoundRunnable = null
    replayRunnable?.let { replayHandler.removeCallbacks(it) }; replayRunnable = null
    roundStatus = ""
    wakeupGate.next()
    ttsInitGate.next()
    val shouldNotifySignalEnd = alarmSignalPlaybackActive
    alarmSignalPlaybackActive = false
    activeSignalPlayback = false
    if (shouldNotifySignalEnd) sendBroadcast(Intent(ACTION_SIGNAL_PLAYBACK_END).setPackage(packageName))
    voiceQueue.cancel()
    liveVoiceText = null
    voiceChunkWatchdog?.let { replayHandler.removeCallbacks(it) }; voiceChunkWatchdog = null
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
    alarmTtsPrefix = ""
    alarmTtsLastId = ""
    musicPlayer = null
    musicPrepared = false
    currentMusicVolume = 0.4f
    vibrator = null
    abandonAlarmAudioFocus()
  }


  private fun requestAlarmAudioFocus() {
    try {
      val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
      if (Build.VERSION.SDK_INT >= 26) {
        val attrs = AudioAttributes.Builder()
          .setUsage(playbackUsage())
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
        audio.requestAudioFocus(null, playbackStream(), AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
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

}
