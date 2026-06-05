package com.example.quote_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.view.View
import android.widget.RemoteViews
import android.os.SystemClock
import android.text.TextUtils
import androidx.core.app.NotificationCompat
import com.example.quote_app.data.DbInspector
import kotlin.math.max

/**
 * Foreground service for Sport tracking:
 * - Keep collecting and computing sport metrics even if user leaves SportRunningPage
 *   or removes app from recents.
 *
 * Persist:
 * - sport_records.total_duration (sec)
 * - sport_records.total_steps
 * - sport_records.total_distance (m)
 * - sport_records.avg_speed (km/h)
 * - sport_records.current_speed (km/h)
 *
 * NOTE:
 * - This is Android-only. iOS cannot keep executing after user force-quits.
 */
class SportForegroundService : Service(), LocationListener, SensorEventListener {

  companion object {
    const val ACTION_START = "com.example.quote_app.action.SPORT_FG_START"
    const val ACTION_STOP = "com.example.quote_app.action.SPORT_FG_STOP"
    const val ACTION_PAUSE = "com.example.quote_app.action.SPORT_FG_PAUSE"
    const val ACTION_RESUME = "com.example.quote_app.action.SPORT_FG_RESUME"
    const val EXTRA_RECORD_ID = "record_id"
    const val EXTRA_TITLE = "title"
    const val EXTRA_FINAL_STATUS = "final_status"

    private const val CHANNEL_ID = "sport_fg_channel"
    private const val NOTIF_ID = 7772001

    @Volatile private var running: Boolean = false
    @Volatile private var runningRecordId: Int? = null

    @JvmStatic fun isRunning(): Boolean = running
    @JvmStatic fun getRunningRecordId(): Int? = runningRecordId
  }

  private var recordId: Int = -1
  private var title: String = "运动进行中"

  private var isPausedLocal: Boolean = false
  // start_time is written by Flutter when countdown finishes. Before that we
  // keep the service alive but must not sample or accumulate metrics.
  private var hasStartTimeLocal: Boolean = false
  private var targetType: String? = null
  private var targetValue: Double = 0.0
  private var targetUnit: String? = null

  private var handlerThread: HandlerThread? = null
  private var handler: Handler? = null

  private var locationManager: LocationManager? = null
  private var lastLoc: Location? = null
  private var lastLocTs: Long = 0L
  private var sessionDistanceM: Double = 0.0
  private var currentSpeedKmh: Double = 0.0

  // Drift suppression window to avoid counting GPS jitter while stationary.
  private var pendingDistM: Double = 0.0
  private var pendingStartLoc: Location? = null
  private var pendingCount: Int = 0
  private var pendingStartMs: Long = 0L
  private var stationaryStreak: Int = 0

  private var locationActive: Boolean = false
  private var sensorsActive: Boolean = false

  private var baseDurationSec: Int = 0
  private var baseSteps: Int = 0
  private var baseDistanceM: Double = 0.0
  private var sessionStartElapsed: Long = 0L

  private var sensorManager: SensorManager? = null
  private var stepSensor: Sensor? = null
  private var stepBaseline: Long? = null
  private var lastStepCounter: Long? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    handlerThread = HandlerThread("sport_fg")
    handlerThread?.start()
    handler = Handler(handlerThread?.looper ?: Looper.getMainLooper())
    locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
    sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    ensureNotifChannel()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    try {
      val act = intent?.action
if (act == ACTION_STOP) {
  // Stop request from Flutter (or notification). We MUST finalize local DB state
  // before stopping the service, otherwise the record may remain "in_progress".
  val rid = intent?.getIntExtra(EXTRA_RECORD_ID, -1) ?: -1
  if (rid > 0) recordId = rid
  title = intent?.getStringExtra(EXTRA_TITLE) ?: title
  val finalStatus = intent?.getStringExtra(EXTRA_FINAL_STATUS) ?: "stopped"
  if (recordId > 0) {
    handleStopFinal(finalStatus)
  } else {
    stopSelfSafely()
  }
  return START_NOT_STICKY
}
if (act == ACTION_PAUSE) {
  val rid = intent?.getIntExtra(EXTRA_RECORD_ID, -1) ?: -1
  if (rid > 0) recordId = rid
  title = intent?.getStringExtra(EXTRA_TITLE) ?: title
  if (recordId > 0) handlePause()
  return START_STICKY
}
if (act == ACTION_RESUME) {
  val rid = intent?.getIntExtra(EXTRA_RECORD_ID, -1) ?: -1
  if (rid > 0) recordId = rid
  title = intent?.getStringExtra(EXTRA_TITLE) ?: title
  if (recordId > 0) handleResume()
  return START_STICKY
}
      // Start / sticky restart
      val rid = intent?.getIntExtra(EXTRA_RECORD_ID, -1) ?: -1
      if (rid <= 0) {
        stopSelfSafely()
        return START_NOT_STICKY
      }
      recordId = rid
      title = intent?.getStringExtra(EXTRA_TITLE) ?: title

      // Start foreground ASAP
      startForeground(NOTIF_ID, buildNotif("in_progress", 0, 0.0, 0))

      running = true
      runningRecordId = recordId
      // Load base from DB
      val status0 = loadBaseFromDb()

      // Restore last location from prefs (best-effort)
      restoreLastLocationFromPrefs()

      // Start sensors/location only when in-progress. If paused, keep service alive but stop sampling.
      // Do not start sampling during countdown (start_time NULL) or when paused.
    if (status0 == "in_progress" && hasStartTimeLocal) {
      sessionStartElapsed = SystemClock.elapsedRealtime()
      isPausedLocal = false
      startSensors()
      startLocation()
    } else {
      // paused / not_started / queued / countdown: keep sensors off
      isPausedLocal = (status0 == "paused")
      sessionStartElapsed = SystemClock.elapsedRealtime()
      stopSensors()
      stopLocation()
    }

      // Update notification to reflect current base values/status.
      try {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotif(status0, baseDurationSec, baseDistanceM, baseSteps))
      } catch (_: Throwable) {}

      // Periodic DB persist
      scheduleTick()
      return START_STICKY
    } catch (_: Throwable) {
      stopSelfSafely()
      return START_NOT_STICKY
    }
  }

  override fun onTaskRemoved(rootIntent: Intent?) {
    // Do not stop; keep tracking.
    // START_STICKY will also allow system to recreate.
    super.onTaskRemoved(rootIntent)
  }

  override fun onDestroy() {
    super.onDestroy()
    try { handler?.removeCallbacksAndMessages(null) } catch (_: Throwable) {}
    stopLocation()
    stopSensors()
    try { handlerThread?.quitSafely() } catch (_: Throwable) {}
    handlerThread = null
    handler = null
    running = false
    runningRecordId = null
  }

  private fun stopSelfSafely() {
    try { stopForeground(true) } catch (_: Throwable) {}
    try { stopSelf() } catch (_: Throwable) {}
  }

  private fun ensureNotifChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      val ch = NotificationChannel(CHANNEL_ID, "运动进行中", NotificationManager.IMPORTANCE_LOW)
      ch.setShowBadge(false)
      nm.createNotificationChannel(ch)
    }
  }

  /**
   * Build a foreground notification reflecting current sport status and metrics.
   *
   * @param status current record status ("in_progress", "paused", "completed", "stopped", etc.)
   * @param durSec total duration in seconds (base + current session)
   * @param distM total distance in meters (base + current session)
   * @param steps total steps (base + current session)
   * @param avgKmh average speed (km/h); optional for expanded view
   * @param curKmh current speed (km/h); optional for expanded view
   * @return Notification configured with custom remote views and actions.
   */
  private fun buildNotif(
    status: String,
    durSec: Int,
    distM: Double,
    steps: Int,
    avgKmh: Double? = null,
    curKmh: Double? = null
  ): android.app.Notification {
    // Collapsed remote view
    val collapsed = RemoteViews(packageName, R.layout.sport_fg_notif_collapsed)
    val expanded = RemoteViews(packageName, R.layout.sport_fg_notif_expanded)
    // Title
    collapsed.setTextViewText(R.id.notif_title, title)
    expanded.setTextViewText(R.id.notif_title, title)
    // Content line for collapsed view: show either target progress or elapsed time
    val line1 = buildContentLine(status, durSec, distM, steps)
    collapsed.setTextViewText(R.id.notif_line1, line1)
    // Expanded view: per requirement, keep ONLY the progress bar (hide any step/distance text).
    expanded.setTextViewText(R.id.notif_line1, "")
    expanded.setViewVisibility(R.id.notif_line1, View.GONE)
    // Progress bar: only for target mode (returns -1 for non-target)
    val percent = computeTargetPercent(durSec, distM, steps)
    if (percent >= 0) {
      collapsed.setViewVisibility(R.id.notif_progress, View.VISIBLE)
      collapsed.setProgressBar(R.id.notif_progress, 100, percent, false)
      expanded.setViewVisibility(R.id.notif_progress, View.VISIBLE)
      expanded.setProgressBar(R.id.notif_progress, 100, percent, false)
    } else {
      collapsed.setViewVisibility(R.id.notif_progress, View.GONE)
      expanded.setViewVisibility(R.id.notif_progress, View.GONE)
    }
    // Play/Pause button icon and action: paused -> show play icon; else show pause icon
    val isPaused = (status == "paused")
    val playIcon = android.R.drawable.ic_media_play
    val pauseIcon = android.R.drawable.ic_media_pause
    val btnIcon = if (isPaused) playIcon else pauseIcon
    collapsed.setImageViewResource(R.id.notif_btn, btnIcon)
    expanded.setImageViewResource(R.id.notif_btn, btnIcon)
    // Button click triggers pause/resume
    val btnAction = if (isPaused) ACTION_RESUME else ACTION_PAUSE
    val btnIntent = Intent(this, SportForegroundService::class.java).apply {
      action = btnAction
      putExtra(EXTRA_RECORD_ID, recordId)
      putExtra(EXTRA_TITLE, title)
    }
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
    val btnPending = PendingIntent.getService(this, 0, btnIntent, flags)
    collapsed.setOnClickPendingIntent(R.id.notif_btn, btnPending)
    expanded.setOnClickPendingIntent(R.id.notif_btn, btnPending)
    // Set dynamic text color for readability based on dark/light mode
    try {
      val isDark = (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
      val textColor = if (isDark) 0xFFFFFFFF.toInt() else 0xFF000000.toInt()
      collapsed.setTextColor(R.id.notif_title, textColor)
      collapsed.setTextColor(R.id.notif_line1, textColor)
      expanded.setTextColor(R.id.notif_title, textColor)
      expanded.setTextColor(R.id.notif_line1, textColor)
    } catch (_: Throwable) {}
    // Content intent to open app and deep link into the running page.  We attach
    // extras so Flutter can navigate to the proper screen.  See NativeGuard
    // handler for handling of notif_type="sport_running".
    val contentIntent = Intent(this, MainActivity::class.java).apply {
      // Ensure the app opens correctly even if removed from recent tasks.  New
      // task + clear top flags allow launching from a notification into an
      // existing or new task, and single top avoids duplicate instances.
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("from_notification", true)
      putExtra("notif_type", "sport_running")
      // Encode the recordId as JSON payload so Flutter can parse it.
      putExtra("payload", "{" + "\"recordId\":${recordId}" + "}")
    }
    val contentPending = PendingIntent.getActivity(this, 1, contentIntent, flags)
    // Build notification
    val builder = NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(R.mipmap.ic_launcher)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .setContentIntent(contentPending)
      .setCustomContentView(collapsed)
      .setCustomBigContentView(expanded)
      .setPriority(NotificationCompat.PRIORITY_LOW)
    // Use summary fields for compatibility; not displayed with custom views but required on some OS.
    builder.setContentTitle(title)
    builder.setContentText(line1)
    return builder.build()
  }

  private fun buildTargetProgress(durSec: Int, distM: Double, steps: Int): String {
  val tt = targetType ?: return ""
  if (targetValue <= 0) return ""
  return when (tt) {
    "steps" -> {
      val tv = targetValue.toInt()
      if (tv <= 0) "" else "${steps} / ${tv} ${targetUnit ?: "步"}"
    }
    "distance" -> {
      val km = distM / 1000.0
      val tv = targetValue
      val u = targetUnit ?: "km"
      if (tv <= 0) "" else String.format("%.2f %s / %.2f %s", km, u, tv, u)
    }
    "duration" -> {
      val targetSec = (targetValue * 3600.0).toInt()
      if (targetSec <= 0) "" else "${formatDuration(durSec)} / ${formatDuration(targetSec)}"
    }
    else -> ""
  }
}

private fun formatDuration(sec: Int): String {
  val s = max(0, sec)
  val h = s / 3600
  val m = (s % 3600) / 60
  val ss = s % 60
  return String.format("%02d:%02d:%02d", h, m, ss)
}

private fun formatDistance(distM: Double): String {
  if (!distM.isFinite() || distM <= 0) return "0.00 km"
  val km = distM / 1000.0
  return String.format("%.2f km", km)
}


private fun buildContentLine(status: String, durSec: Int, distM: Double, steps: Int): String {
  val hasTarget = (targetType != null && targetType!!.isNotEmpty() && targetValue > 0.0)
  val isPaused = status == "paused"
  val prefix = if (isPaused) "已暂停 · " else ""
  return if (hasTarget) {
    // 计划模式：只显示“当前/目标”
    val tt = targetType!!
    when (tt) {
      "steps" -> {
        val tv = targetValue.toInt().coerceAtLeast(0)
        val unit = targetUnit ?: "步"
        if (tv > 0) prefix + "$steps / $tv $unit" else prefix
      }
      "distance" -> {
        val km = distM / 1000.0
        val tv = targetValue
        val u = targetUnit ?: "km"
        prefix + String.format("%.2f %s / %.2f %s", km, u, tv, u)
      }
      "duration" -> {
        val targetSec = (targetValue * 3600.0).toInt().coerceAtLeast(0)
        val durStr = formatDuration(durSec)
        val tarStr = formatDuration(targetSec)
        prefix + "$durStr / $tarStr"
      }
      else -> prefix
    }
  } else {
    // 非计划模式：只显示时间
    prefix + formatDuration(durSec)
  }
}


private fun buildExpandedMetrics(distM: Double, steps: Int, avgKmh: Double, curKmh: Double): String {
  val lines = mutableListOf<String>()
  // Expand view should not show distance.
  lines.add("步数 $steps")
  val avg = if (avgKmh.isFinite() && avgKmh >= 0) String.format("%.1f", avgKmh) else "0.0"
  val cur = if (curKmh.isFinite() && curKmh >= 0) String.format("%.1f", curKmh) else "0.0"
  lines.add("平均 $avg km/h  实时 $cur km/h")
  return lines.joinToString("\n")
}

private fun computeTargetPercent(durSec: Int, distM: Double, steps: Int): Int {
  val tt = targetType ?: return -1
  if (targetValue <= 0) return -1
  return try {
    val percent = when (tt) {
      "steps" -> {
        val tv = targetValue.toInt()
        if (tv <= 0) return -1
        (steps.toDouble() / tv.toDouble()) * 100.0
      }
      "distance" -> {
        val km = distM / 1000.0
        val tv = targetValue
        if (tv <= 0) return -1
        (km / tv) * 100.0
      }
      "duration" -> {
        val targetSec = (targetValue * 3600.0)
        if (targetSec <= 0) return -1
        (durSec.toDouble() / targetSec) * 100.0
      }
      else -> return -1
    }
    val p = percent.coerceIn(0.0, 100.0)
    p.toInt()
  } catch (_: Throwable) {
    -1
  }
}

  private fun startLocation() {
    try {
      if (locationActive) return
      val lm = locationManager ?: return
      val looper = handlerThread?.looper ?: Looper.getMainLooper()
      // Prefer GPS; fallback to network when available.
      try { lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, this, looper) } catch (_: Throwable) {}
      try { lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 2000L, 0f, this, looper) } catch (_: Throwable) {}
      locationActive = true
    } catch (_: Throwable) {}
  }

  private fun stopLocation() {
    try { locationManager?.removeUpdates(this) } catch (_: Throwable) {}
    locationActive = false
  }

  private fun startSensors() {
    try {
      if (sensorsActive) return
      val sm = sensorManager ?: return
      val s = stepSensor ?: return
      stepBaseline = null
      lastStepCounter = null
      val h = handler ?: Handler(Looper.getMainLooper())
      sm.registerListener(this, s, SensorManager.SENSOR_DELAY_NORMAL, h)
      sensorsActive = true
    } catch (_: Throwable) {}
  }

  private fun stopSensors() {
    try { sensorManager?.unregisterListener(this) } catch (_: Throwable) {}
    sensorsActive = false
  }

  override fun onLocationChanged(location: Location) {
    try {
      // Ignore updates when paused or before countdown finishes.
      if (isPausedLocal || !hasStartTimeLocal) return

      // Filter out very poor fixes.
      val accF = location.accuracy
      if (!accF.isNaN() && !accF.isInfinite() && accF > 80f) {
        return
      }

      val now = SystemClock.elapsedRealtime()
      val last = lastLoc

      // Dynamic movement threshold based on accuracy. This reduces distance drift when stationary.
      val acc = if (accF.isNaN() || accF.isInfinite()) 8.0 else accF.toDouble()
      val jitterTh = max(3.0, kotlin.math.min(25.0, acc * 1.2))
      val confirmTh = max(10.0, jitterTh * 2.5)

      if (last != null) {
        val dtMs = max(1L, now - lastLocTs)
        val d = last.distanceTo(location).toDouble()

        // Reset window on obviously invalid distances.
        if (d.isNaN() || d.isInfinite() || d <= 0) {
          lastLoc = location
          lastLocTs = now
          return
        }

        // Ignore huge jumps (bad fix / provider switch).
        if (d > 2000) {
          pendingDistM = 0.0
          pendingCount = 0
          pendingStartMs = 0L
          pendingStartLoc = null
          stationaryStreak = 0
          lastLoc = location
          lastLocTs = now
          saveLastLocationToPrefs(location)
          return
        }

        if (d < jitterTh) {
          // Treat as stationary jitter.
          stationaryStreak++
          pendingDistM = 0.0
          pendingCount = 0
          pendingStartMs = 0L
          pendingStartLoc = null
          currentSpeedKmh = 0.0
          // Still advance the anchor slowly to follow drift, but never add distance.
          lastLoc = location
          lastLocTs = now
          if (stationaryStreak >= 3) {
            saveLastLocationToPrefs(location)
          }
          return
        }

        // Movement candidate: require a short confirmation window (>=3 points and >=confirmTh meters displacement)
        stationaryStreak = 0
        if (pendingCount == 0) {
          pendingStartMs = now
          pendingStartLoc = last
        }
        val disp = (pendingStartLoc?.distanceTo(location)?.toDouble() ?: d)
        pendingDistM = disp
        pendingCount += 1

        // Expire pending window to avoid slowly accumulating drift.
        if (pendingStartMs > 0L && (now - pendingStartMs) > 12000L) {
          pendingDistM = 0.0
          pendingCount = 0
          pendingStartMs = 0L
          pendingStartLoc = null
        }

        if (pendingCount >= 3 && pendingDistM >= confirmTh) {
          sessionDistanceM += pendingDistM
          // Prefer provider speed if available; otherwise derive from last segment.
          currentSpeedKmh = if (location.hasSpeed()) {
            (location.speed.toDouble()) * 3.6
          } else {
            (d / (dtMs / 1000.0)) * 3.6
          }
          pendingDistM = 0.0
          pendingCount = 0
          pendingStartMs = 0L
          pendingStartLoc = null
          saveLastLocationToPrefs(location)
        } else {
          // Not confirmed yet: decay speed to 0.
          currentSpeedKmh *= 0.85
        }

        // Always advance last raw location for correct delta calculation.
        lastLoc = location
        lastLocTs = now
      } else {
        // First fix.
        lastLoc = location
        lastLocTs = now
        pendingDistM = 0.0
        pendingCount = 0
        pendingStartMs = 0L
        pendingStartLoc = null
        stationaryStreak = 0
        currentSpeedKmh = if (location.hasSpeed()) (location.speed.toDouble()) * 3.6 else 0.0
        saveLastLocationToPrefs(location)
      }
    } catch (_: Throwable) {}
  }

  override fun onProviderEnabled(provider: String) {}
  override fun onProviderDisabled(provider: String) {}
  override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}



  override fun onSensorChanged(event: SensorEvent?) {
    try {
      val e = event ?: return
      if (e.sensor.type != Sensor.TYPE_STEP_COUNTER) return
      val v = e.values?.getOrNull(0) ?: return
      val count = v.toLong()
      if (stepBaseline == null) {
        stepBaseline = count
      }
      lastStepCounter = count
    } catch (_: Throwable) {}
  }

  override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

  private fun scheduleTick() {
    val h = handler ?: return
    h.removeCallbacks(tickRunnable)
    h.post(tickRunnable)
  }



private fun handlePause() {
  // Freeze duration and persist latest metrics, then stop sensors/location.
  val durSec = baseDurationSec + ((SystemClock.elapsedRealtime() - sessionStartElapsed) / 1000L).toInt()
  val distM = baseDistanceM + sessionDistanceM
  val steps = computeTotalSteps()
  val avgKmh = if (durSec <= 0) 0.0 else (distM / 1000.0) / (durSec / 3600.0)
  persistToDb(
    totalDurationSec = durSec,
    totalSteps = steps,
    totalDistanceM = distM,
    avgSpeedKmh = if (avgKmh.isFinite()) avgKmh else 0.0,
    currentSpeedKmh = 0.0
  )
  updateStatusInDb("paused")
  baseDurationSec = durSec
  baseDistanceM = distM
  baseSteps = steps
  sessionDistanceM = 0.0
  currentSpeedKmh = 0.0
  pendingDistM = 0.0
  pendingCount = 0
  pendingStartMs = 0L
  pendingStartLoc = null
  stationaryStreak = 0
  isPausedLocal = true
  stopLocation()
  stopSensors()
  val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
  nm.notify(NOTIF_ID, buildNotif("paused", durSec, distM, steps))
  try { Channels.emitSportMusicAction("pause") } catch (_: Throwable) {}
}

private fun handleResume() {
  updateStatusInDb("in_progress")
  // Reload base values from DB (in case app updated them).
  loadBaseFromDb()
  sessionDistanceM = 0.0
  currentSpeedKmh = 0.0
  pendingDistM = 0.0
  pendingCount = 0
  pendingStartMs = 0L
  pendingStartLoc = null
  stationaryStreak = 0
  lastLoc = null
  lastLocTs = 0
  restoreLastLocationFromPrefs()
  sessionStartElapsed = SystemClock.elapsedRealtime()
  isPausedLocal = false
  startLocation()
  startSensors()
  val durSec = baseDurationSec
  val distM = baseDistanceM
  val steps = baseSteps
  val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
  nm.notify(NOTIF_ID, buildNotif("in_progress", durSec, distM, steps))
  try { Channels.emitSportMusicAction("resume") } catch (_: Throwable) {}
}

  private val tickRunnable: Runnable = object : Runnable {
  override fun run() {
    try {
      if (recordId <= 0) return

      // Reload base values and meta from DB, including start_time.
      val status = loadBaseFromDb(loadTotals = false)
      if (status == "stopped" || status == "completed") {
        stopSelfSafely()
        return
      }
      // Prestart countdown/queued phase: keep the service alive (notification stays)
      // but do NOT sample or accumulate.
      //
      // - not_started: new record before countdown
      // - queued: user hasn't begun (waiting)
      // - in_progress + start_time NULL: countdown is running
      if (status == "not_started" || status == "queued" || (status == "in_progress" && !hasStartTimeLocal)) {
        stopLocation()
        stopSensors()
        sessionDistanceM = 0.0
        currentSpeedKmh = 0.0
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotif("in_progress", baseDurationSec, baseDistanceM, baseSteps, 0.0, 0.0))
        handler?.postDelayed(this, 1000L)
        return
      }

      
      // Ensure sampling starts right after countdown ends (start_time becomes non-null).
      if (status == "in_progress" && hasStartTimeLocal && !isPausedLocal) {
        if (!locationActive && !sensorsActive) {
          // Starting a new active segment. Reset timer baseline.
          sessionStartElapsed = SystemClock.elapsedRealtime()
          pendingDistM = 0.0
          pendingCount = 0
          pendingStartMs = 0L
          pendingStartLoc = null
          stationaryStreak = 0
          lastLoc = null
          lastLocTs = 0
          restoreLastLocationFromPrefs()
        }
        if (!locationActive) startLocation()
        if (!sensorsActive) startSensors()
      }
if (status == "paused") {
        if (!isPausedLocal) {
          // Pause triggered from UI (or other source)
          handlePause()
        }
      } else if (status == "in_progress") {
        if (isPausedLocal) {
          // Resume triggered from UI (or other source)
          handleResume()
        }
      }

      val durSec = if (status == "paused") {
        baseDurationSec
      } else {
        baseDurationSec + ((SystemClock.elapsedRealtime() - sessionStartElapsed) / 1000L).toInt()
      }
      val distM = baseDistanceM + sessionDistanceM

      // Steps
      val totalSteps = computeTotalSteps()

      val avgKmh = if (durSec <= 0) 0.0 else (distM / 1000.0) / (durSec / 3600.0)

      persistToDb(
        totalDurationSec = durSec,
        totalSteps = totalSteps,
        totalDistanceM = distM,
        avgSpeedKmh = if (avgKmh.isFinite()) avgKmh else 0.0,
        currentSpeedKmh = if (status == "paused") 0.0 else (if (currentSpeedKmh.isFinite()) currentSpeedKmh else 0.0)
      )

      // Auto-complete when target achieved (for plan mode). percent <0 means no target.
      val percent = computeTargetPercent(durSec, distM, totalSteps)
      if (percent >= 100) {
        // Mark completed and persist an end_time before stopping.
        handleStopFinal("completed")
        return
      }

      // Update notification.
      val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      nm.notify(NOTIF_ID, buildNotif(status, durSec, distM, totalSteps, avgKmh, currentSpeedKmh))

      // schedule next tick
      val delay = if (status == "paused") 3000L else 1000L
      handler?.postDelayed(this, delay)
    } catch (_: Throwable) {
      // Try again later to avoid breaking the service
      handler?.postDelayed(this, 1500L)
    }
  }
}


  private fun queryStatus(): String? {
    var db: SQLiteDatabase? = null
    var c: Cursor? = null
    return try {
      db = openDb() ?: return null
      c = db.rawQuery("SELECT status FROM sport_records WHERE id=? LIMIT 1", arrayOf(recordId.toString()))
      if (c.moveToFirst() && !c.isNull(0)) c.getString(0) else null
    } catch (_: Throwable) {
      null
    } finally {
      try { c?.close() } catch (_: Throwable) {}
      try { db?.close() } catch (_: Throwable) {}
    }
  }

  private fun updateStatusInDb(status: String, setEndTime: Boolean = false) {
    var db: SQLiteDatabase? = null
    try {
      db = openDb() ?: return
      val now = nowIso()
      if (setEndTime) {
        db.execSQL(
          "UPDATE sport_records SET status=?, end_time=?, updated_at=? WHERE id=?",
          arrayOf(status, now, now, recordId)
        )
      } else {
        db.execSQL(
          "UPDATE sport_records SET status=?, updated_at=? WHERE id=?",
          arrayOf(status, now, recordId)
        )
      }
    } catch (_: Throwable) {
    } finally {
      try { db?.close() } catch (_: Throwable) {}
    }
  }

  /**
   * Finalize current session state into DB (status + end_time + latest totals), then stop.
   *
   * This is critical for robustness:
   * - If the user taps "结束" (stop/complete) and the Flutter side fails to persist due to
   *   transient DB locks (native tick) or other exceptions, we still ensure the record does
   *   NOT remain "in_progress" in history.
   */
  private fun handleStopFinal(finalStatus: String) {
    try {
      handler?.removeCallbacksAndMessages(null)
    } catch (_: Throwable) {}

    // Stop sampling first to avoid further DB writes and reduce lock risk.
    stopLocation()
    stopSensors()

    // Reload base totals/status.
    val status0 = loadBaseFromDb(loadTotals = true)
    val paused = (status0 == "paused") || isPausedLocal

    val durSec = if (!hasStartTimeLocal) {
      baseDurationSec
    } else if (paused) {
      baseDurationSec
    } else {
      baseDurationSec + ((SystemClock.elapsedRealtime() - sessionStartElapsed) / 1000L).toInt()
    }
    val distM = (baseDistanceM + sessionDistanceM)
    val steps = if (!hasStartTimeLocal) baseSteps else computeTotalSteps()
    val avgKmh = if (durSec <= 0) 0.0 else (distM / 1000.0) / (durSec / 3600.0)

    // Persist one last snapshot.
    persistToDb(
      totalDurationSec = durSec,
      totalSteps = steps,
      totalDistanceM = distM,
      avgSpeedKmh = if (avgKmh.isFinite()) avgKmh else 0.0,
      currentSpeedKmh = 0.0
    )

    // Persist final status + end time.
    updateStatusInDb(finalStatus, setEndTime = true)

    try { Channels.emitSportMusicAction("stop") } catch (_: Throwable) {}

    // Mark globals.
    running = false
    runningRecordId = null

    // Stop service and remove notification.
    stopSelfSafely()
  }

  private fun loadBaseFromDb(loadTotals: Boolean = true): String {
    var db: SQLiteDatabase? = null
    var c: Cursor? = null
    var status = "in_progress"
    try {
      db = openDb() ?: return status
      c = db.rawQuery(
        "SELECT total_duration, total_steps, total_distance, status, target_type, target_value, target_unit, start_time FROM sport_records WHERE id=? LIMIT 1",
        arrayOf(recordId.toString())
      )
      if (c.moveToFirst()) {
        if (loadTotals) {
          baseDurationSec = if (c.isNull(0)) 0 else c.getInt(0)
          baseSteps = if (c.isNull(1)) 0 else c.getInt(1)
          baseDistanceM = if (c.isNull(2)) 0.0 else c.getDouble(2)
        }
        status = if (c.isNull(3)) "in_progress" else (c.getString(3) ?: "in_progress")
        targetType = if (c.isNull(4)) null else c.getString(4)
        targetValue = if (c.isNull(5)) 0.0 else c.getDouble(5)
        targetUnit = if (c.isNull(6)) null else c.getString(6)
        hasStartTimeLocal = !c.isNull(7)
        // Prestart countdown uses status=in_progress with start_time NULL.
        // Do NOT override isPausedLocal here; it is controlled by handlePause/handleResume.
      }
    } catch (_: Throwable) {
    } finally {
      try { c?.close() } catch (_: Throwable) {}
      try { db?.close() } catch (_: Throwable) {}
    }
    return status
  }

  private fun computeTotalSteps(): Int {
    return try {
      val baseline = stepBaseline
      val last = lastStepCounter
      if (baseline == null || last == null) return baseSteps
      val session = max(0L, last - baseline)
      val total = baseSteps.toLong() + session
      if (total > Int.MAX_VALUE.toLong()) Int.MAX_VALUE else total.toInt()
    } catch (_: Throwable) {
      baseSteps
    }
  }

private fun persistToDb(
    totalDurationSec: Int,
    totalSteps: Int,
    totalDistanceM: Double,
    avgSpeedKmh: Double,
    currentSpeedKmh: Double
  ) {
    var db: SQLiteDatabase? = null
    try {
      db = openDb() ?: return
      val now = nowIso()
      db.execSQL(
        "UPDATE sport_records SET total_duration=?, total_steps=?, total_distance=?, avg_speed=?, current_speed=?, updated_at=? WHERE id=?",
        arrayOf(
          totalDurationSec,
          totalSteps,
          totalDistanceM,
          avgSpeedKmh,
          currentSpeedKmh,
          now,
          recordId
        )
      )
    } catch (_: Throwable) {
    } finally {
      try { db?.close() } catch (_: Throwable) {}
    }
  }

  private fun openDb(): SQLiteDatabase? {
    try {
      val cc = DbInspector.loadOrLightScan(this)
      val p = if (cc != null && !TextUtils.isEmpty(cc.dbPath)) cc.dbPath else null
      return if (!p.isNullOrEmpty()) {
        SQLiteDatabase.openDatabase(p, null, SQLiteDatabase.OPEN_READWRITE)
      } else {
        val fallback = getDatabasePath("app.db").absolutePath
        SQLiteDatabase.openOrCreateDatabase(fallback, null)
      }
    } catch (_: Throwable) {
      return null
    }
  }

  private fun nowIso(): String {
    return try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        java.time.OffsetDateTime.now().toString()
      } else {
        val fmt = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ", java.util.Locale.US)
        fmt.format(java.util.Date())
      }
    } catch (_: Throwable) {
      System.currentTimeMillis().toString()
    }
  }

  private fun saveLastLocationToPrefs(loc: Location) {
    try {
      val sp = getSharedPreferences("sport_fg", Context.MODE_PRIVATE)
      sp.edit()
        .putFloat("last_lat_$recordId", loc.latitude.toFloat())
        .putFloat("last_lng_$recordId", loc.longitude.toFloat())
        .apply()
    } catch (_: Throwable) {}
  }

  private fun restoreLastLocationFromPrefs() {
    try {
      val sp = getSharedPreferences("sport_fg", Context.MODE_PRIVATE)
      val has = sp.contains("last_lat_$recordId") && sp.contains("last_lng_$recordId")
      if (!has) return
      val lat = sp.getFloat("last_lat_$recordId", 0f).toDouble()
      val lng = sp.getFloat("last_lng_$recordId", 0f).toDouble()
      val l = Location("stored")
      l.latitude = lat
      l.longitude = lng
      lastLoc = l
      lastLocTs = SystemClock.elapsedRealtime()
    } catch (_: Throwable) {}
  }
}