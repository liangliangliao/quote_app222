package com.example.quote_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

class VoiceAlarmReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    val pending = goAsync()
    val app = context.applicationContext
    val payload = intent?.getStringExtra("payload") ?: "{}"
    Thread {
      try {
        if (!VoiceAlarmFireGuard.shouldSkip(app, payload)) {
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

          // Give the foreground service a moment to post its full-screen
          // notification, then make a best-effort Activity open.  The Activity
          // itself is lock-screen capable and the notification remains the legal
          // fallback when direct background Activity launch is blocked.
          Handler(Looper.getMainLooper()).postDelayed({
            try { VoiceAlarmRingingService.restoreFullScreenIfRinging(app) } catch (_: Throwable) {}
          }, 450L)
        }
        try { VoiceAlarmScheduler.scheduleNextDaily(app, payload) } catch (_: Throwable) {}
      } finally {
        pending.finish()
      }
    }.apply {
      name = "voice-alarm-fire"
      isDaemon = true
      start()
    }
  }
}
