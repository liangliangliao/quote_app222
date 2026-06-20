package com.example.quote_app

import android.content.Context
import android.os.Build

object VoiceAlarmFireGuard {
  private const val PREFS = "voice_alarm_fire_guard"
  private const val KEY_LAST_AT = "lastAt"
  private const val KEY_LAST_HASH = "lastHash"
  private const val WINDOW_MS = 15_000L

  @JvmStatic
  fun shouldSkip(context: Context, payload: String): Boolean {
    val app = context.applicationContext
    val storageContext = if (Build.VERSION.SDK_INT >= 24) app.createDeviceProtectedStorageContext() else app
    return try {
      val prefs = storageContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      val now = System.currentTimeMillis()
      val lastAt = prefs.getLong(KEY_LAST_AT, 0L)
      val lastHash = prefs.getInt(KEY_LAST_HASH, 0)
      val hash = payload.hashCode()
      if (hash == lastHash && now - lastAt in 0L..WINDOW_MS) {
        true
      } else {
        prefs.edit().putLong(KEY_LAST_AT, now).putInt(KEY_LAST_HASH, hash).apply()
        false
      }
    } catch (_: Throwable) {
      false
    }
  }
}
