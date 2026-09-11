package com.example.quote_app

import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.os.UserManager
import androidx.work.*
import java.util.concurrent.TimeUnit

/** Recovery never depends on a Flutter engine or the AI request completing. */
class ReminderRecoveryWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        if (Build.VERSION.SDK_INT >= 24 && !(applicationContext.getSystemService(Context.USER_SERVICE) as UserManager).isUserUnlocked) return Result.retry()
        var failed = false
        try { EvidenceGrowthReminderNative.reconcile(applicationContext) } catch (_: Throwable) { failed = true }
        try { HealthDietReminderNative.restore(applicationContext, inputData.getBoolean("reset_clock", false)) } catch (_: Throwable) { failed = true }
        applicationContext.getSharedPreferences("reminder_recovery_status", Context.MODE_PRIVATE).edit()
            .putLong("at", System.currentTimeMillis()).putString("error", if (failed) "RECOVERY_RETRY" else "").apply()
        return if (failed) Result.retry() else Result.success()
    }
    companion object {
        fun enqueue(ctx: Context, resetClock: Boolean = false) {
            if (Build.VERSION.SDK_INT >= 24 && !(ctx.getSystemService(Context.USER_SERVICE) as UserManager).isUserUnlocked) return
            WorkManager.getInstance(ctx).enqueueUniqueWork("module_reminder_recovery", if (resetClock) ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.KEEP,
                OneTimeWorkRequestBuilder<ReminderRecoveryWorker>()
                    .setInputData(Data.Builder().putBoolean("reset_clock", resetClock).build())
                    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build())
            WorkManager.getInstance(ctx).enqueueUniquePeriodicWork("module_reminder_repair", ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<ReminderRecoveryWorker>(1, TimeUnit.HOURS).build())
        }
        fun wakeful(ctx: Context, task: () -> Unit) {
            val lock = (ctx.getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "quote_app:reminder_delivery")
            lock.acquire(60000)
            EvidenceGrowthReminderNative.background {
                try { task() } finally { if (lock.isHeld) lock.release() }
            }
        }
    }
}
