package com.example.quote_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object VoiceAlarmScheduler {
  private const val PREFS = "voice_alarm_native"
  private const val KEY_PAYLOAD = "payload"
  private const val KEY_AT = "at"
  private const val KEY_IDS = "ids"
  private const val MORNING_ALARM_ID = 974001
  private const val NIGHT_ALARM_ID = 974002
  private const val EXACT_FALLBACK_OFFSET = 200
  private const val SERVICE_FALLBACK_OFFSET = 400
  private const val ACTIVITY_FALLBACK_OFFSET = 600

  private fun deviceProtectedPrefs(context: Context): SharedPreferences {
    val storageContext = if (Build.VERSION.SDK_INT >= 24) context.createDeviceProtectedStorageContext() else context
    return storageContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
  }

  private fun credentialProtectedPrefs(context: Context): SharedPreferences =
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

  private fun persistedPrefs(context: Context): List<SharedPreferences> = listOf(
    deviceProtectedPrefs(context),
    credentialProtectedPrefs(context),
  )

  private fun persistedRequestKey(payload: String): String {
    val id = alarmId(payload)
    return id.toString()
  }

  private fun persistAlarm(context: Context, mode: String, payload: String, atMs: Long) {
    val requestKey = persistedRequestKey(payload)
    for (prefs: SharedPreferences in persistedPrefs(context)) {
      val ids = LinkedHashSet<String>()
      val raw = prefs.getString(KEY_IDS, "[]") ?: "[]"
      try {
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) ids.add(arr.optString(i))
      } catch (_: Throwable) {}
      ids.add(requestKey)
      val nextIds = JSONArray()
      ids.forEach { nextIds.put(it) }
      prefs.edit()
        .putString("${KEY_PAYLOAD}_$mode", payload)
        .putLong("${KEY_AT}_$mode", atMs)
        .putString("${KEY_PAYLOAD}_$requestKey", payload)
        .putLong("${KEY_AT}_$requestKey", atMs)
        .putString(KEY_IDS, nextIds.toString())
        .apply()
    }
  }

  private fun clearPersistedAlarms(context: Context) {
    deviceProtectedPrefs(context).edit().clear().apply()
    credentialProtectedPrefs(context).edit().clear().apply()
  }

  private fun alarmId(payload: String): Int {
    val obj = try { JSONObject(payload) } catch (_: Throwable) { JSONObject() }
    val customId = obj.optString("alarmId", "")
    if (customId.isNotBlank()) {
      return 974100 + (customId.hashCode() and 0x3fffffff) % 400000
    }
    val mode = obj.optString("mode", "morning")
    return if (mode == "night") NIGHT_ALARM_ID else MORNING_ALARM_ID
  }

  private fun alarmFireIntent(app: Context, payload: String, actionName: String): Intent =
    Intent(app, VoiceAlarmReceiver::class.java).apply {
      action = actionName
      addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
      putExtra("payload", payload)
      putExtra("fromAlarmFire", true)
    }

  private fun alarmServiceIntent(app: Context, payload: String): Intent =
    Intent(app, VoiceAlarmRingingService::class.java).apply {
      action = "com.example.quote_app.VOICE_ALARM_START"
      putExtra("payload", payload)
      putExtra("fromAlarmFire", true)
    }

  private fun foregroundServicePendingIntent(app: Context, requestCode: Int, payload: String): PendingIntent {
    val intent = alarmServiceIntent(app, payload)
    return if (Build.VERSION.SDK_INT >= 26) {
      PendingIntent.getForegroundService(
        app,
        requestCode,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
    } else {
      PendingIntent.getService(
        app,
        requestCode,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
    }
  }

  private fun activityFallbackPendingIntent(app: Context, requestCode: Int, payload: String): PendingIntent {
    val intent = Intent(app, VoiceAlarmActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("payload", payload)
      putExtra("fromAlarmFire", true)
    }
    return PendingIntent.getActivity(
      app,
      requestCode,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }


  private fun scheduleBestEffortInexact(alarmManager: AlarmManager, atMs: Long, operation: PendingIntent) {
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, operation)
      } else {
        alarmManager.set(AlarmManager.RTC_WAKEUP, atMs, operation)
      }
    } catch (_: Throwable) {
      try { alarmManager.set(AlarmManager.RTC_WAKEUP, atMs, operation) } catch (_: Throwable) {}
    }
  }

  @JvmStatic
  fun schedule(context: Context, atMs: Long, payload: String, persist: Boolean = true) {
    val app = context.applicationContext
    val id = alarmId(payload)
    val mode = if (id == NIGHT_ALARM_ID) "night" else "morning"
    val alarmManager = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    // Do not use an Activity PendingIntent as the alarm delivery endpoint.
    // Cold-start/background Activity launches are exactly where many OEM ROMs
    // are most restrictive.  Deliver to a direct-boot-aware BroadcastReceiver
    // first, then let the foreground ringing service post a full-screen alarm
    // notification and open VoiceAlarmActivity when the system allows it.
    val operation = PendingIntent.getBroadcast(
      app,
      id,
      alarmFireIntent(app, payload, "com.example.quote_app.VOICE_ALARM_FIRE"),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val showIntent = PendingIntent.getActivity(
      app,
      id + 100,
      Intent(app, VoiceAlarmActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        putExtra("payload", payload)
      },
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    try {
      alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(atMs, showIntent), operation)
    } catch (se: SecurityException) {
      // Android 12+ can revoke exact-alarm privileges. Keep a best-effort
      // inexact wakeup instead of throwing out of schedule(), otherwise the
      // Flutter page may report “saved” failure and no persisted alarm remains.
      scheduleBestEffortInexact(alarmManager, atMs, operation)
    } catch (_: Throwable) {
      scheduleBestEffortInexact(alarmManager, atMs, operation)
    }

    // Some OEM ROMs are aggressive about alarm-clock PendingIntent delivery when
    // the process is cold. Keep setAlarmClock as the primary wakeup, and add a
    // second exact/allow-while-idle alarm with a different request code as a
    // best-effort fallback. VoiceAlarmReceiver de-duplicates near-simultaneous
    // firings so the user does not get two ringing services.
    val fallbackOperation = PendingIntent.getBroadcast(
      app,
      id + EXACT_FALLBACK_OFFSET,
      alarmFireIntent(app, payload, "com.example.quote_app.VOICE_ALARM_FIRE_FALLBACK"),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val serviceFallbackOperation = foregroundServicePendingIntent(app, id + SERVICE_FALLBACK_OFFSET, payload)
    val activityFallbackOperation = activityFallbackPendingIntent(app, id + ACTIVITY_FALLBACK_OFFSET, payload)
    try {
      val canUseExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
      if (canUseExact) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, fallbackOperation)
          alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs + 1500L, serviceFallbackOperation)
          alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs + 3000L, activityFallbackOperation)
        } else {
          alarmManager.setExact(AlarmManager.RTC_WAKEUP, atMs, fallbackOperation)
          alarmManager.setExact(AlarmManager.RTC_WAKEUP, atMs + 1500L, serviceFallbackOperation)
          alarmManager.setExact(AlarmManager.RTC_WAKEUP, atMs + 3000L, activityFallbackOperation)
        }
      } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        // Best-effort non-exact fallback for devices where the user has not yet
        // granted the special exact-alarm access.  It may be delayed by Doze, but
        // it avoids the silent "nothing was scheduled" failure mode.
        scheduleBestEffortInexact(alarmManager, atMs, fallbackOperation)
        scheduleBestEffortInexact(alarmManager, atMs + 1500L, serviceFallbackOperation)
        scheduleBestEffortInexact(alarmManager, atMs + 3000L, activityFallbackOperation)
      }
    } catch (_: Throwable) {
      scheduleBestEffortInexact(alarmManager, atMs, fallbackOperation)
      scheduleBestEffortInexact(alarmManager, atMs + 1500L, serviceFallbackOperation)
      scheduleBestEffortInexact(alarmManager, atMs + 3000L, activityFallbackOperation)
    }

    if (persist) {
      persistAlarm(app, mode, payload, atMs)
    }
  }

  private fun cancelRequestCode(app: Context, id: Int) {
    val alarmManager = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val primary = PendingIntent.getBroadcast(
      app,
      id,
      Intent(app, VoiceAlarmReceiver::class.java).apply { action = "com.example.quote_app.VOICE_ALARM_FIRE" },
      PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
    )
    if (primary != null) {
      alarmManager.cancel(primary)
      primary.cancel()
    }
    val fallback = PendingIntent.getBroadcast(
      app,
      id + EXACT_FALLBACK_OFFSET,
      Intent(app, VoiceAlarmReceiver::class.java).apply { action = "com.example.quote_app.VOICE_ALARM_FIRE_FALLBACK" },
      PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
    )
    if (fallback != null) {
      alarmManager.cancel(fallback)
      fallback.cancel()
    }
    val serviceFallbackIntent = Intent(app, VoiceAlarmRingingService::class.java).apply {
      action = "com.example.quote_app.VOICE_ALARM_START"
    }
    val serviceFallback = if (Build.VERSION.SDK_INT >= 26) {
      PendingIntent.getForegroundService(
        app,
        id + SERVICE_FALLBACK_OFFSET,
        serviceFallbackIntent,
        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
      )
    } else {
      PendingIntent.getService(
        app,
        id + SERVICE_FALLBACK_OFFSET,
        serviceFallbackIntent,
        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
      )
    }
    if (serviceFallback != null) {
      alarmManager.cancel(serviceFallback)
      serviceFallback.cancel()
    }
    val activityFallback = PendingIntent.getActivity(
      app,
      id + ACTIVITY_FALLBACK_OFFSET,
      Intent(app, VoiceAlarmActivity::class.java).apply { putExtra("fromAlarmFire", true) },
      PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
    )
    if (activityFallback != null) {
      alarmManager.cancel(activityFallback)
      activityFallback.cancel()
    }
  }

  @JvmStatic
  fun cancel(context: Context, alarmKey: String? = null) {
    val app = context.applicationContext
    if (!alarmKey.isNullOrBlank()) {
      val id = alarmId(JSONObject().put("alarmId", alarmKey).toString())
      cancelRequestCode(app, id)
      for (prefs: SharedPreferences in persistedPrefs(app)) {
        prefs.edit().remove("${KEY_PAYLOAD}_$id").remove("${KEY_AT}_$id").apply()
      }
      return
    }
    val ids = LinkedHashSet<Int>()
    ids.add(MORNING_ALARM_ID)
    ids.add(NIGHT_ALARM_ID)
    for (prefs: SharedPreferences in persistedPrefs(app)) {
      val raw = prefs.getString(KEY_IDS, "[]") ?: "[]"
      try {
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) arr.optString(i).toIntOrNull()?.let { ids.add(it) }
      } catch (_: Throwable) {}
    }
    ids.forEach { cancelRequestCode(app, it) }
    clearPersistedAlarms(app)
  }

  @JvmStatic
  fun snooze(context: Context, payload: String, minutes: Int = 5) {
    schedule(context, System.currentTimeMillis() + minutes.coerceAtLeast(1) * 60_000L, payload, true)
  }

  @JvmStatic
  fun scheduleNextDaily(context: Context, payload: String) {
    val obj = try { JSONObject(payload) } catch (_: Throwable) { JSONObject() }
    val allowed = mutableSetOf<Int>()
    val rawDays = obj.optJSONArray("weekdays")
    if (rawDays != null) for (i in 0 until rawDays.length()) allowed.add(rawDays.optInt(i))
    if (allowed.isEmpty()) allowed.addAll(1..7)
    val next = java.util.Calendar.getInstance().apply {
      set(java.util.Calendar.HOUR_OF_DAY, obj.optInt("hour", 8))
      set(java.util.Calendar.MINUTE, obj.optInt("minute", 0))
      set(java.util.Calendar.SECOND, 0)
      set(java.util.Calendar.MILLISECOND, 0)
      if (timeInMillis <= System.currentTimeMillis()) add(java.util.Calendar.DAY_OF_YEAR, 1)
      var guard = 0
      while (!allowed.contains(if (get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.SUNDAY) 7 else get(java.util.Calendar.DAY_OF_WEEK) - 1) && guard < 8) {
        add(java.util.Calendar.DAY_OF_YEAR, 1)
        guard++
      }
    }
    schedule(context, next.timeInMillis, payload, true)
  }

  @JvmStatic
  fun restore(context: Context) {
    val entries = LinkedHashMap<String, String>()
    val devicePrefs = deviceProtectedPrefs(context)
    val credentialPrefs = credentialProtectedPrefs(context)
    for (prefs in listOf(devicePrefs, credentialPrefs)) {
      val raw = prefs.getString(KEY_IDS, "[]") ?: "[]"
      try {
        val arr = JSONArray(raw)
        for (i in 0 until arr.length()) {
          val key = arr.optString(i)
          val payload = prefs.getString("${KEY_PAYLOAD}_$key", null)
          if (!payload.isNullOrBlank()) entries[key] = payload
        }
      } catch (_: Throwable) {}
    }
    for (mode in arrayOf("morning", "night")) {
      val payload = devicePrefs.getString("${KEY_PAYLOAD}_$mode", null)
        ?: credentialPrefs.getString("${KEY_PAYLOAD}_$mode", null)
      if (!payload.isNullOrBlank()) entries[mode] = payload
    }
    for ((key, payload) in entries) {
      var at = devicePrefs.getLong("${KEY_AT}_$key", 0L).takeIf { it > 0L }
        ?: credentialPrefs.getLong("${KEY_AT}_$key", 0L)
      if (at <= System.currentTimeMillis()) {
        val obj = try { JSONObject(payload) } catch (_: Throwable) { JSONObject() }
        val hour = obj.optInt("hour", 8)
        val minute = obj.optInt("minute", 0)
        val now = java.util.Calendar.getInstance()
        val next = java.util.Calendar.getInstance().apply {
          set(java.util.Calendar.HOUR_OF_DAY, hour)
          set(java.util.Calendar.MINUTE, minute)
          set(java.util.Calendar.SECOND, 0)
          set(java.util.Calendar.MILLISECOND, 0)
          if (timeInMillis <= now.timeInMillis) add(java.util.Calendar.DAY_OF_YEAR, 1)
          val allowed = mutableSetOf<Int>()
          val rawDays = obj.optJSONArray("weekdays")
          if (rawDays != null) for (i in 0 until rawDays.length()) allowed.add(rawDays.optInt(i))
          if (allowed.isEmpty()) allowed.addAll(1..7)
          var guard = 0
          while (!allowed.contains(if (get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.SUNDAY) 7 else get(java.util.Calendar.DAY_OF_WEEK) - 1) && guard < 8) {
            add(java.util.Calendar.DAY_OF_YEAR, 1)
            guard++
          }
        }
        at = next.timeInMillis
      }
      schedule(context, at, payload, true)
    }
  }

}
