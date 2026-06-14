package com.example.quote_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class VoiceAlarmActionReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    val payload = intent?.getStringExtra("payload") ?: "{}"
    VoiceAlarmRingingService.stop(context)
    if (intent?.action == "com.example.quote_app.VOICE_ALARM_SNOOZE") {
      VoiceAlarmScheduler.snooze(context, payload, 5)
    }
  }
}
