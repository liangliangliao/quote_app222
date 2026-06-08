package com.example.quote_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.RemoteInput

/** Handles notification inline-reply actions for 行为观察. */
class BehaviorObservationQuickRecordReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    val ctx = context.applicationContext
    val safeIntent = intent ?: return
    val layer = safeIntent.getStringExtra(EXTRA_LAYER) ?: "行为层面"
    val payload = safeIntent.getStringExtra(EXTRA_PAYLOAD) ?: "{}"
    val notificationId = safeIntent.getIntExtra(EXTRA_NOTIFICATION_ID, 880013)
    val input = RemoteInput.getResultsFromIntent(safeIntent)?.getCharSequence(KEY_TEXT)?.toString()?.trim().orEmpty()
    val savedId = BehaviorObservationNativeRecorder.saveFromNotification(ctx, layer, input, payload)
    try {
      (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(notificationId)
    } catch (_: Throwable) {}
    NotifyHelper.sendBehaviorObservationSaved(ctx, notificationId + 1, layer, input, savedId)
  }

  companion object {
    const val ACTION = "com.example.quote_app.behavior_observation.QUICK_RECORD"
    const val KEY_TEXT = "behavior_observation_text"
    const val EXTRA_LAYER = "layer"
    const val EXTRA_PAYLOAD = "payload"
    const val EXTRA_NOTIFICATION_ID = "notification_id"
    const val EXTRA_SUMMARY_NOTIFICATION_ID = "summary_notification_id"
  }
}
