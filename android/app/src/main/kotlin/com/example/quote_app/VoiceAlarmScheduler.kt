package com.example.quote_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import org.json.JSONObject

object VoiceAlarmScheduler {
  private const val PREFS = "voice_alarm_native"
  private const val KEY_PAYLOAD = "payload"
  private const val KEY_AT = "at"
  private const val MORNING_ALARM_ID = 974001
  private const val NIGHT_ALARM_ID = 974002

  private fun protectedPrefs(context: Context): SharedPreferences {
    val storageContext = if (Build.VERSION.SDK_INT >= 24) context.createDeviceProtectedStorageContext() else context
    return storageContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
  }

  private fun credentialPrefs(context: Context): SharedPreferences =
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

  private fun persistAlarm(context: Context, mode: String, payload: String, atMs: Long) {
    for (prefs in listOf(protectedPrefs(context), credentialPrefs(context))) {
      prefs.edit()
        .putString("${KEY_PAYLOAD}_$mode", payload)
        .putLong("${KEY_AT}_$mode", atMs)
        .apply()
    }
  }

  private fun clearPersistedAlarms(context: Context) {
    protectedPrefs(context).edit().clear().apply()
    credentialPrefs(context).edit().clear().apply()
  }

  private fun alarmId(payload: String): Int {
    val mode = try { JSONObject(payload).optString("mode", "morning") } catch (_: Throwable) { "morning" }
    return if (mode == "night") NIGHT_ALARM_ID else MORNING_ALARM_ID
  }

  @JvmStatic
  fun schedule(context: Context, atMs: Long, payload: String, persist: Boolean = true) {
    val app = context.applicationContext
    val id = alarmId(payload)
    val mode = if (id == NIGHT_ALARM_ID) "night" else "morning"
    val alarmManager = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val operation = PendingIntent.getBroadcast(
      app,
      id,
      Intent(app, VoiceAlarmReceiver::class.java).apply {
        action = "com.example.quote_app.VOICE_ALARM_FIRE"
        putExtra("payload", payload)
      },
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val showIntent = PendingIntent.getActivity(
      app,
      id + 100,
      app.packageManager.getLaunchIntentForPackage(app.packageName) ?: Intent(app, MainActivity::class.java),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(atMs, showIntent), operation)
    if (persist) {
      persistAlarm(app, mode, payload, atMs)
    }
  }

  @JvmStatic
  fun cancel(context: Context) {
    val app = context.applicationContext
    for (id in intArrayOf(MORNING_ALARM_ID, NIGHT_ALARM_ID)) {
      val operation = PendingIntent.getBroadcast(
        app,
        id,
        Intent(app, VoiceAlarmReceiver::class.java).apply { action = "com.example.quote_app.VOICE_ALARM_FIRE" },
        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
      )
      if (operation != null) {
        (app.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(operation)
        operation.cancel()
      }
    }
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
    for (mode in arrayOf("morning", "night")) {
      val protected = protectedPrefs(context)
      val credential = credentialPrefs(context)
      val payload = protected.getString("${KEY_PAYLOAD}_$mode", null)
        ?: credential.getString("${KEY_PAYLOAD}_$mode", null)
        ?: continue
      var at = protected.getLong("${KEY_AT}_$mode", 0L).takeIf { it > 0L }
        ?: credential.getLong("${KEY_AT}_$mode", 0L)
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
