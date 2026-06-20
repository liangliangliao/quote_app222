package com.example.quote_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * BootReceiver listens for device boot completed or app package replacement
 * events and reinitializes all scheduled tasks.  It enqueues a one‑off
 * workmanager job with job name `wm_boot` which is handled in the Dart
 * dispatcher to restore all alarms and scheduled WorkManager tasks.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // VoiceAlarm uses device-protected storage and must be restored as early as
        // LOCKED_BOOT_COMPLETED.  WorkManager may touch credential-protected storage
        // before the user unlocks the phone, so restore voice alarms first and keep
        // WorkManager boot reinitialization best-effort.
        try { VoiceAlarmScheduler.restore(context.applicationContext) } catch (_: Throwable) {}

        try {
            val data = Data.Builder()
                .putString("job", "wm_boot")
                .build()
            val request = OneTimeWorkRequestBuilder<AlarmProxyWorker>()
                .setInputData(data)
                .build()
            WorkManager.getInstance(context).enqueue(request)
        } catch (_: Throwable) {
            // WorkManager is not direct-boot friendly on all devices; do not let it
            // prevent direct-boot alarm restoration.
        }

        // 兜底：周期性恢复 UnlockPulse 的 Alarm（避免长时间待机/ROM 冻结/清理后台后链路断掉）。
        // 电量友好：该 Worker 只做“恢复调度”，不做定位/不发通知，因此无需 15 分钟频率。
        try {
            val data2 = Data.Builder().putString("job", "wm_pulse_rearm").build()
            val constraints = Constraints.Builder().setRequiresBatteryNotLow(true).build()
            val periodic = PeriodicWorkRequestBuilder<AlarmProxyWorker>(2, TimeUnit.HOURS)
                .setConstraints(constraints)
                .setInputData(data2)
                .build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork("wm_pulse_rearm", ExistingPeriodicWorkPolicy.UPDATE, periodic)
        } catch (_: Throwable) {
            // ignore
        }

        // 按需求：地点规则提醒不再采用 WorkManager 周期任务；仅在“解锁广播”触发。
        // 这里仅做一次清理：取消历史版本可能遗留的周期 GeoWorker，避免误触发。
        try { GeoWorker.cancel(context) } catch (_: Throwable) { /* ignore */ }

        // 无常驻通知的命中率增强：开机/更新后恢复 UnlockPulse（若开关开启）。
        // 这是“状态探测”兜底，不做周期性定位。
        try { UnlockPulse.ensureScheduledIfNeeded(context) } catch (_: Throwable) { /* ignore */ }

        // Sport: ensure midnight renewal alarm exists after reboot and best-effort reschedule all sport plan alarms.
        try { com.example.quote_app.sport.SportPlanRenewal.scheduleMidnightAlarm(context) } catch (_: Throwable) {}
        try { com.example.quote_app.sport.SportPlanRenewal.rescheduleAllPlanAlarms(context) } catch (_: Throwable) {}

        // Behavior preset alarms: after reboot/package replace, restore upcoming alarm-clock style reminders
        // from local DB so they still work when the app process is not running.
        try { BehaviorPresetAlarmScheduler.rescheduleUpcoming(context.applicationContext) } catch (_: Throwable) {}
    }
}
