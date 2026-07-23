package com.example.quote_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.concurrent.TimeUnit

object MentalHealthCheckupReminderScheduler {
    private const val PREFS = "mental_health_checkup_reminders"
    private const val ACTION_WORK = "mh_checkup_action_reminder"
    private const val RETEST_WORK = "mh_checkup_retest_reminder"

    private const val KEY_ENABLED = "enabled"
    private const val KEY_HOUR = "hour"
    private const val KEY_MINUTE = "minute"
    private const val KEY_QUIET_START = "quiet_start"
    private const val KEY_QUIET_END = "quiet_end"
    private const val KEY_PRIVATE = "private"
    private const val KEY_RETEST_AT = "retest_at"

    fun configure(
        context: Context,
        enabled: Boolean,
        hour: Int,
        minute: Int,
        quietStartHour: Int,
        quietEndHour: Int,
        lockScreenPrivacy: Boolean,
        nextRetestAtMs: Long?,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putInt(KEY_HOUR, hour.coerceIn(0, 23))
            .putInt(KEY_MINUTE, minute.coerceIn(0, 59))
            .putInt(KEY_QUIET_START, quietStartHour.coerceIn(0, 23))
            .putInt(KEY_QUIET_END, quietEndHour.coerceIn(0, 23))
            .putBoolean(KEY_PRIVATE, lockScreenPrivacy)
            .putLong(KEY_RETEST_AT, nextRetestAtMs ?: 0L)
            .apply()
        if (!enabled) {
            cancel(context)
            return
        }
        scheduleNextAction(context)
        scheduleRetest(context, nextRetestAtMs)
    }

    fun scheduleNextAction(context: Context, from: ZonedDateTime = ZonedDateTime.now()) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        val hour = prefs.getInt(KEY_HOUR, 19).coerceIn(0, 23)
        val minute = prefs.getInt(KEY_MINUTE, 0).coerceIn(0, 59)
        var target = from.withHour(hour).withMinute(minute).withSecond(0).withNano(0)
        if (!target.isAfter(from)) target = target.plusDays(1)
        target = moveOutOfQuietHours(target, prefs)
        enqueue(
            context = context,
            uniqueName = ACTION_WORK,
            kind = "action",
            delayMs = Duration.between(from, target).toMillis(),
        )
    }

    private fun scheduleRetest(context: Context, requestedAtMs: Long?) {
        WorkManager.getInstance(context).cancelUniqueWork(RETEST_WORK)
        if (requestedAtMs == null || requestedAtMs <= 0) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        val now = ZonedDateTime.now()
        var target = Instant.ofEpochMilli(requestedAtMs)
            .atZone(ZoneId.systemDefault())
        if (!target.isAfter(now)) target = now.plusMinutes(1)
        target = moveOutOfQuietHours(target, prefs)
        enqueue(
            context = context,
            uniqueName = RETEST_WORK,
            kind = "retest",
            delayMs = Duration.between(now, target).toMillis(),
        )
    }

    private fun moveOutOfQuietHours(
        time: ZonedDateTime,
        prefs: android.content.SharedPreferences,
    ): ZonedDateTime {
        val start = prefs.getInt(KEY_QUIET_START, 22).coerceIn(0, 23)
        val end = prefs.getInt(KEY_QUIET_END, 8).coerceIn(0, 23)
        if (start == end) return time
        val hour = time.hour
        val quiet = if (start < end) {
            hour >= start && hour < end
        } else {
            hour >= start || hour < end
        }
        if (!quiet) return time
        var moved = time.withHour(end).withMinute(0).withSecond(0).withNano(0)
        if (!moved.isAfter(time)) moved = moved.plusDays(1)
        return moved
    }

    private fun enqueue(
        context: Context,
        uniqueName: String,
        kind: String,
        delayMs: Long,
    ) {
        val request = OneTimeWorkRequestBuilder<MentalHealthCheckupReminderWorker>()
            .setInitialDelay(delayMs.coerceAtLeast(1_000L), TimeUnit.MILLISECONDS)
            .setInputData(Data.Builder().putString("kind", kind).build())
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            uniqueName,
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    fun reschedule(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        scheduleNextAction(context)
        scheduleRetest(context, prefs.getLong(KEY_RETEST_AT, 0L))
    }

    fun snooze(context: Context, kind: String, minutes: Long = 60L) {
        enqueue(
            context = context,
            uniqueName = if (kind == "retest") RETEST_WORK else ACTION_WORK,
            kind = kind,
            delayMs = TimeUnit.MINUTES.toMillis(minutes.coerceIn(15L, 240L)),
        )
    }

    private fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(ACTION_WORK)
        WorkManager.getInstance(context).cancelUniqueWork(RETEST_WORK)
    }

    fun clear(context: Context) {
        cancel(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }

    fun lockScreenPrivacy(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_PRIVATE, true)
}

class MentalHealthCheckupReminderWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val kind = inputData.getString("kind") ?: "action"
        if (kind == "action") {
            MentalHealthCheckupReminderScheduler.scheduleNextAction(
                applicationContext,
                ZonedDateTime.now().plusMinutes(1),
            )
        }
        if (
            android.os.Build.VERSION.SDK_INT >= 33 &&
            ActivityCompat.checkSelfPermission(
                applicationContext,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return Result.success()
        }
        createChannels()
        val isRetest = kind == "retest"
        val channelId = if (isRetest) {
            "mental_health_checkup_retest"
        } else {
            "mental_health_checkup_action"
        }
        val intent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("from_notification", true)
            putExtra("notif_type", "mental_health_checkup")
            putExtra("payload", kind)
        }
        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            if (isRetest) 4202 else 4201,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val snoozeIntent = Intent(
            applicationContext,
            MentalHealthCheckupReminderActionReceiver::class.java,
        ).apply {
            action = "com.example.quote_app.MH_CHECKUP_SNOOZE"
            putExtra("kind", kind)
        }
        val skipIntent = Intent(
            applicationContext,
            MentalHealthCheckupReminderActionReceiver::class.java,
        ).apply {
            action = "com.example.quote_app.MH_CHECKUP_SKIP"
            putExtra("kind", kind)
        }
        val shrinkIntent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("from_notification", true)
            putExtra("notif_type", "mental_health_checkup")
            putExtra("payload", "shrink")
        }
        val notification = NotificationCompat.Builder(applicationContext, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(if (isRetest) "到了回看近况的时间" else "今天的最小行动")
            .setContentText(
                if (isRetest) {
                    "可以完成一次本地复验，也可以稍后再做。"
                } else {
                    "可以完成可接受的最小版本，也可以跳过或缩小。"
                },
            )
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .addAction(
                0,
                "稍后",
                PendingIntent.getBroadcast(
                    applicationContext,
                    if (isRetest) 4212 else 4211,
                    snoozeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .addAction(
                0,
                "跳过",
                PendingIntent.getBroadcast(
                    applicationContext,
                    if (isRetest) 4222 else 4221,
                    skipIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .addAction(
                0,
                "缩小行动",
                PendingIntent.getActivity(
                    applicationContext,
                    4231,
                    shrinkIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .setVisibility(
                if (MentalHealthCheckupReminderScheduler.lockScreenPrivacy(
                        applicationContext,
                    )
                ) {
                    NotificationCompat.VISIBILITY_SECRET
                } else {
                    NotificationCompat.VISIBILITY_PRIVATE
                },
            )
            .build()
        NotificationManagerCompat.from(applicationContext).notify(
            if (isRetest) 4202 else 4201,
            notification,
        )
        return Result.success()
    }

    private fun createChannels() {
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                "mental_health_checkup_action",
                "课程行动提醒",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "用户主动开启的中性课程行动提醒"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                "mental_health_checkup_retest",
                "课程复验提醒",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "用户主动开启的中性复验提醒"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            },
        )
    }
}

class MentalHealthCheckupReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val kind = intent?.getStringExtra("kind") ?: "action"
        when (intent?.action) {
            "com.example.quote_app.MH_CHECKUP_SNOOZE" ->
                MentalHealthCheckupReminderScheduler.snooze(context, kind)
            "com.example.quote_app.MH_CHECKUP_SKIP" -> Unit
        }
        NotificationManagerCompat.from(context).cancel(
            if (kind == "retest") 4202 else 4201,
        )
    }
}

class MentalHealthCheckupTimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (
            intent?.action == Intent.ACTION_TIMEZONE_CHANGED ||
            intent?.action == Intent.ACTION_TIME_CHANGED ||
            intent?.action == Intent.ACTION_BOOT_COMPLETED
        ) {
            MentalHealthCheckupReminderScheduler.reschedule(
                context.applicationContext,
            )
        }
    }
}
