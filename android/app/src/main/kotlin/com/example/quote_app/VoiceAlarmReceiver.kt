package com.example.quote_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class VoiceAlarmReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    val payload = intent?.getStringExtra("payload") ?: "{}"
    VoiceAlarmRingingService.start(context.applicationContext, payload)
    VoiceAlarmScheduler.scheduleNextDaily(context.applicationContext, payload)
  }
}
