package com.example.quote_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.json.JSONObject

object VoiceAlarmScheduler {
  private const val PREFS = "voice_alarm_native"
  private const val KEY_PAYLOAD = "payload"
  private const val KEY_AT = "at"
  const val ALARM_ID = 974001

  @JvmStatic
  fun schedule(context: Context, atMs: Long, payload: String, persist: Boolean = true) {
    val app = context.applicationContext
    val alarmManager = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val operation = PendingIntent.getBroadcast(
      app,
      ALARM_ID,
      Intent(app, VoiceAlarmReceiver::class.java).apply {
        action = "com.example.quote_app.VOICE_ALARM_FIRE"
        putExtra("payload", payload)
      },
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val showIntent = PendingIntent.getActivity(
      app,
      ALARM_ID + 1,
      app.packageManager.getLaunchIntentForPackage(app.packageName) ?: Intent(app, MainActivity::class.java),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(atMs, showIntent), operation)
    if (persist) {
      app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        .putString(KEY_PAYLOAD, payload)
        .putLong(KEY_AT, atMs)
        .apply()
    }
  }

  @JvmStatic
  fun cancel(context: Context) {
    val app = context.applicationContext
    val operation = PendingIntent.getBroadcast(
      app,
      ALARM_ID,
      Intent(app, VoiceAlarmReceiver::class.java).apply { action = "com.example.quote_app.VOICE_ALARM_FIRE" },
      PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
    )
    if (operation != null) {
      (app.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(operation)
      operation.cancel()
    }
    app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
  }

  @JvmStatic
  fun snooze(context: Context, payload: String, minutes: Int = 5) {
    schedule(context, System.currentTimeMillis() + minutes.coerceAtLeast(1) * 60_000L, payload, true)
  }

  @JvmStatic
  fun scheduleNextDaily(context: Context, payload: String) {
    val obj = try { JSONObject(payload) } catch (_: Throwable) { JSONObject() }
    val next = java.util.Calendar.getInstance().apply {
      set(java.util.Calendar.HOUR_OF_DAY, obj.optInt("hour", 8))
      set(java.util.Calendar.MINUTE, obj.optInt("minute", 0))
      set(java.util.Calendar.SECOND, 0)
      set(java.util.Calendar.MILLISECOND, 0)
      if (timeInMillis <= System.currentTimeMillis()) add(java.util.Calendar.DAY_OF_YEAR, 1)
    }
    schedule(context, next.timeInMillis, payload, true)
  }

  @JvmStatic
  fun restore(context: Context) {
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    val payload = prefs.getString(KEY_PAYLOAD, null) ?: return
    var at = prefs.getLong(KEY_AT, 0L)
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
      }
      at = next.timeInMillis
    }
    schedule(context, at, payload, true)
  }
}
