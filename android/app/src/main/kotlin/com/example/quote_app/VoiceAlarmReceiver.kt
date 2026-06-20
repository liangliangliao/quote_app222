package com.example.quote_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class VoiceAlarmReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    val app = context.applicationContext
    val payload = intent?.getStringExtra("payload") ?: "{}"
    if (isDuplicateFire(app, payload)) return

    try {
      VoiceAlarmRingingService.start(app, payload)
    } catch (_: Throwable) {
      // Last-resort path for OEM/background-start restrictions: still try to
      // bring up the full-screen alarm UI so the user receives a visible alarm.
      try {
        app.startActivity(Intent(app, VoiceAlarmActivity::class.java).apply {
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
          putExtra("payload", payload)
        })
      } catch (_: Throwable) {}
    }
    VoiceAlarmScheduler.scheduleNextDaily(app, payload)
  }

  private fun isDuplicateFire(context: Context, payload: String): Boolean {
    val storageContext = if (Build.VERSION.SDK_INT >= 24) context.createDeviceProtectedStorageContext() else context
    return try {
      val prefs = storageContext.getSharedPreferences("voice_alarm_fire_guard", Context.MODE_PRIVATE)
      val now = System.currentTimeMillis()
      val lastAt = prefs.getLong("lastAt", 0L)
      val lastHash = prefs.getInt("lastHash", 0)
      val hash = payload.hashCode()
      if (hash == lastHash && now - lastAt in 0L..15_000L) {
        true
      } else {
        prefs.edit().putLong("lastAt", now).putInt("lastHash", hash).apply()
        false
      }
    } catch (_: Throwable) {
      false
    }
  }
}
