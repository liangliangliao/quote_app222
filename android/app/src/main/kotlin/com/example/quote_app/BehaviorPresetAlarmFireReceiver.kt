package com.example.quote_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

/**
 * Reliable entry point for behavior preset alarm-clock fires.
 *
 * The previous v35 path used an Activity PendingIntent as the AlarmManager operation.  Some Android/OEM builds
 * still block or drop that background Activity launch, so the code that plays sound/vibration never runs.  A
 * manifest receiver delivered by AlarmManager is the stable wake-up point: it starts a foreground ringing service
 * immediately, then asks the notification/full-screen path to show the form.
 */
class BehaviorPresetAlarmFireReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    val app = context.applicationContext
    var rawPayload = intent?.getStringExtra("payload") ?: "{}"
    try { rawPayload = BehaviorPresetAlarmScheduler.normalizePayloadForFire(app, rawPayload) } catch (_: Throwable) {}

    var id = intent?.getIntExtra("id", 0) ?: 0
    try {
      val obj = JSONObject(rawPayload)
      if (id == 0) id = obj.optInt("alarmId", 0)
      if (id == 0) {
        val day = obj.optLong("checkDateMs", System.currentTimeMillis())
        val h = obj.optInt("reminderHour", 21)
        val m = obj.optInt("reminderMinute", 0)
        id = (97100000 + ((day / 60000L + h * 60L + m) % 900000L)).toInt()
        obj.put("alarmId", id)
        rawPayload = obj.toString()
      }
    } catch (_: Throwable) {}
    if (id == 0) id = (97100000 + ((System.currentTimeMillis() / 60000L) % 900000L)).toInt()

    try { com.example.quote_app.data.DbRepo.log(app, null, "[BehaviorPresetAlarm] fire receiver received id=$id") } catch (_: Throwable) {}

    // Start the signal first.  This is independent of notification permission and independent of whether the
    // full-screen Activity is allowed to appear, so the user still gets alarm-like sound/vibration.
    try { BehaviorPresetAlarmRingingService.startRinging(app, id, rawPayload) } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(app, null, "[BehaviorPresetAlarm] start ringing service failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }

    // v40: the foreground ringing service owns overlay + full-screen notification UI.  Calling NotifyHelper here as
    // well can make foreground devices receive several full-screen launches for one alarm fire.

    // Schedule the next occurrence from the receiver so it does not depend on the form being displayed/opened.
    try { BehaviorPresetAlarmScheduler.scheduleNextAfterFire(app, rawPayload) } catch (_: Throwable) {}
  }
}
