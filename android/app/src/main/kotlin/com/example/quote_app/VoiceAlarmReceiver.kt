package com.example.quote_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class VoiceAlarmReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    val app = context.applicationContext
    val payload = intent?.getStringExtra("payload") ?: "{}"
    if (VoiceAlarmFireGuard.shouldSkip(app, payload)) return

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
}
