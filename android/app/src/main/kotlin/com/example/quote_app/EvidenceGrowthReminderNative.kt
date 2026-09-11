package com.example.quote_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.*
import com.example.quote_app.data.DbInspector
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** The durable SQLite outbox is shared by AlarmManager and WorkManager.
 * No Flutter engine, model call, or network connection is needed to deliver.
 */
object EvidenceGrowthReminderNative {
    private const val TABLE = "evidence_growth_reminders"
    private const val CHANNEL = "evidence_growth_trials_v1"
    private const val TAG = "evidence_growth"
    private val executor = Executors.newSingleThreadExecutor()
    fun background(task: () -> Unit) { executor.execute(task) }

    private fun database(ctx: Context): SQLiteDatabase? {
        val primary = java.io.File(ctx.applicationInfo.dataDir, "app_flutter/quotes.db")
        val path = if (primary.exists()) primary.absolutePath else DbInspector.loadOrLightScan(ctx)?.dbPath
        if (path.isNullOrBlank()) throw IllegalStateException("DATABASE_UNAVAILABLE")
        val db = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE)
        val exists = db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?", arrayOf(TABLE)).use { it.moveToFirst() }
        if (!exists) { db.close(); return null }
        return db
    }

    private fun manager(ctx: Context) = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun channel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            manager(ctx).createNotificationChannel(NotificationChannel(CHANNEL, "现实试验与成长提醒", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "试验开始、结果反馈、连续退出与恢复窗口"
                enableVibration(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PRIVATE
            })
        }
    }
    fun status(ctx: Context): Map<String, Any> {
        channel(ctx)
        val notifications = NotificationManagerCompat.from(ctx).areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 26 || manager(ctx).getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
        val power = ctx.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        val activity = ctx.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val recovery = ctx.getSharedPreferences("reminder_recovery_status", Context.MODE_PRIVATE)
        return mapOf("available" to true, "notifications" to notifications, "exact" to ExactAlarmHelper.hasExactAlarmPermission(ctx),
            "battery_optimized" to (Build.VERSION.SDK_INT >= 23 && !power.isIgnoringBatteryOptimizations(ctx.packageName)),
            "background_restricted" to (Build.VERSION.SDK_INT >= 28 && activity.isBackgroundRestricted),
            "last_recovery_ms" to recovery.getLong("at", 0), "last_recovery_error" to (recovery.getString("error", "") ?: ""))
    }
    fun openSettings(ctx: Context) {
        val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName).putExtra(Settings.EXTRA_CHANNEL_ID, CHANNEL)
        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}"))
        ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
    private fun alarmIntent(ctx: Context, id: Int): PendingIntent = PendingIntent.getBroadcast(ctx, id,
        Intent(ctx, EvidenceGrowthReminderReceiver::class.java).setData(Uri.parse("quote-app://evidence-reminder/$id"))
            .putExtra("reminder_id", id), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancel(ctx: Context, id: Int, notification: Boolean = true) {
        (ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(alarmIntent(ctx, id))
        WorkManager.getInstance(ctx).cancelUniqueWork("eg_reminder_$id")
        if (notification) manager(ctx).cancel(TAG, id)
    }
    private fun valid(db: SQLiteDatabase, trialId: String, kind: String): Boolean {
        val global = db.rawQuery("SELECT setting_value FROM evidence_growth_settings WHERE setting_key='reminders_enabled'", null)
            .use { if (it.moveToFirst()) it.getString(0) else "true" }
        if (global == "false") return false
        return db.rawQuery("SELECT status, operator, operator_inputs_json, decision FROM evidence_growth_trials WHERE trial_id=?", arrayOf(trialId)).use { c ->
            if (!c.moveToFirst()) return@use false
            val override = db.rawQuery("SELECT setting_value FROM evidence_growth_settings WHERE setting_key=?", arrayOf("remind_trial_$trialId"))
                .use { if (it.moveToFirst()) it.getString(0) else null }
            if ((override ?: JSONObject(c.getString(2)).optString("remind")) != "true") return@use false
            val state = c.getString(0)
            when (kind) {
                "repeated_avoidance" -> state == "DECIDED" && c.getString(3) == "EXIT" && repeatedExit(db, trialId)
                "trial_start" -> state == "READY"
                "recovery_end" -> state == "IN_PROGRESS" && c.getString(1) == "RECOVER"
                "trial_review_due", "missing_result" -> state in listOf("READY", "IN_PROGRESS", "OBSERVING")
                else -> false
            }
        }
    }

    private fun repeatedExit(db: SQLiteDatabase, trialId: String): Boolean {
        val node = db.rawQuery("SELECT node_ids_json FROM evidence_growth_trials WHERE trial_id=?", arrayOf(trialId))
            .use { if (it.moveToFirst()) org.json.JSONArray(it.getString(0)).optString(0) else "" }
        if (node.isEmpty()) return false
        var count = 0
        db.rawQuery("SELECT trial_id,node_ids_json,decision FROM evidence_growth_trials WHERE status='DECIDED' ORDER BY updated_at_ms DESC,created_at_ms DESC,trial_id DESC", null).use { c ->
            while (c.moveToNext()) {
                if (org.json.JSONArray(c.getString(1)).optString(0) != node) continue
                if (count == 0 && c.getString(0) != trialId) return false
                if (c.getString(2) != "EXIT") return false
                if (++count == 3) return true
            }
        }
        return false
    }

    /** Boot, package update, permission return and app resume all use this path. */
    @JvmStatic fun reconcile(ctx: Context): Boolean {
        val db = database(ctx) ?: return true
        db.use {
            val wm = WorkManager.getInstance(ctx)
            wm.enqueueUniquePeriodicWork("eg_reminder_repair", ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<EvidenceGrowthReminderWorker>(1, TimeUnit.HOURS).build())
            val capabilities = status(ctx)
            val ready = capabilities["notifications"] == true && capabilities["exact"] == true
            val prefs = ctx.getSharedPreferences("eg_reminder_registry", Context.MODE_PRIVATE)
            val known = prefs.getStringSet("ids", emptySet())!!.toSet()
            val retained = mutableSetOf<String>()
            val now = System.currentTimeMillis()
            var allScheduled = true
            // Latest overdue window wins after an outage; don't emit a backlog of start/result alerts.
            db.rawQuery("SELECT reminder_id, trial_id, kind, scheduled_at_ms, state FROM $TABLE ORDER BY scheduled_at_ms DESC", null).use { c ->
                val overdueTrials = mutableSetOf<String>()
                while (c.moveToNext()) {
                    val id = c.getInt(0); val trial = c.getString(1); val kind = c.getString(2)
                    val at = c.getLong(3); val state = c.getString(4)
                    retained.add(id.toString())
                    if (!valid(db, trial, kind) || state == "cancelled" || state == "expired") {
                        cancel(ctx, id)
                        if (state != "delivered") db.execSQL("UPDATE $TABLE SET state='cancelled' WHERE reminder_id=?", arrayOf(id))
                        continue
                    }
                    if (state == "delivered") {
                        if (at <= now) overdueTrials.add(trial)
                        cancel(ctx, id, false); continue
                    }
                    if (at <= now && !overdueTrials.add(trial)) {
                        db.execSQL("UPDATE $TABLE SET state='expired', last_error='SUPERSEDED_OVERDUE_WINDOW' WHERE reminder_id=?", arrayOf(id))
                        cancel(ctx, id); continue
                    }
                    if (!ready) {
                        allScheduled = false
                        cancel(ctx, id)
                        db.execSQL("UPDATE $TABLE SET state='blocked', last_error=? WHERE reminder_id=?",
                            arrayOf(if (capabilities["notifications"] != true) "NOTIFICATION_PERMISSION" else "EXACT_ALARM_PERMISSION", id))
                        continue
                    }
                    // A persisted ID and data URI keep registrations stable and separate from other modules.
                    try {
                        val fireAt = maxOf(at, now + 1000)
                        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        if (Build.VERSION.SDK_INT >= 23) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, alarmIntent(ctx, id))
                        else am.setExact(AlarmManager.RTC_WAKEUP, fireAt, alarmIntent(ctx, id))
                        val fallback = OneTimeWorkRequestBuilder<EvidenceGrowthReminderWorker>()
                            .setInputData(Data.Builder().putInt("reminder_id", id).build())
                            .setInitialDelay(maxOf(0L, fireAt + 120000 - now), TimeUnit.MILLISECONDS).build()
                        wm.enqueueUniqueWork("eg_reminder_$id", ExistingWorkPolicy.KEEP, fallback)
                        db.execSQL("UPDATE $TABLE SET state='scheduled', last_error='' WHERE reminder_id=? AND state IN ('pending','scheduled','blocked')", arrayOf(id))
                    } catch (_: Throwable) { allScheduled = false
                        db.execSQL("UPDATE $TABLE SET state='blocked', last_error='SCHEDULE_FAILED' WHERE reminder_id=?", arrayOf(id))
                    }
                }
            }
            for (removed in known - retained) removed.toIntOrNull()?.let { cancel(ctx, it) }
            prefs.edit().putStringSet("ids", retained).apply()
            return allScheduled
        }
    }

    @JvmStatic fun fire(ctx: Context, id: Int): Boolean {
        val db = database(ctx) ?: return true
        db.use {
            db.beginTransaction()
            try {
                db.rawQuery("SELECT trial_id,kind,scheduled_at_ms,title,body,source_ids_json,state,event_key FROM $TABLE WHERE reminder_id=?", arrayOf(id.toString())).use { c ->
                    if (!c.moveToFirst()) { cancel(ctx, id); return true }
                    val trial = c.getString(0); val kind = c.getString(1); val at = c.getLong(2)
                    if (c.getString(6) !in listOf("pending", "scheduled", "blocked")) return true
                    if (!valid(db, trial, kind)) {
                        db.execSQL("UPDATE $TABLE SET state='cancelled' WHERE reminder_id=?", arrayOf(id))
                        db.setTransactionSuccessful(); cancel(ctx, id); return true
                    }
                    if (at > System.currentTimeMillis()) return true
                    if (status(ctx)["notifications"] != true || !ExactAlarmHelper.hasExactAlarmPermission(ctx)) {
                        db.execSQL("UPDATE $TABLE SET state='blocked',last_error='PERMISSION_UNAVAILABLE' WHERE reminder_id=?", arrayOf(id))
                        db.setTransactionSuccessful(); return true
                    }
                    val payload = JSONObject().put("module", TAG).put("type", kind).put("trial_id", trial)
                        .put("reminder_id", id).put("event_key", c.getString(7)).put("source_ids", org.json.JSONArray(c.getString(5)))
                    val launch = Intent(ctx, MainActivity::class.java)
                        .setData(Uri.parse("quote-app://evidence-growth/$id"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        .putExtra("from_notification", true).putExtra("notif_type", TAG).putExtra("payload", payload.toString())
                    val click = PendingIntent.getActivity(ctx, id, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val notification = NotificationCompat.Builder(ctx, CHANNEL).setSmallIcon(android.R.drawable.ic_dialog_info)
                        .setContentTitle(c.getString(3)).setContentText(c.getString(4))
                        .setStyle(NotificationCompat.BigTextStyle().bigText(c.getString(4)))
                        .setPriority(NotificationCompat.PRIORITY_HIGH).setCategory(NotificationCompat.CATEGORY_REMINDER)
                        .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setOnlyAlertOnce(true).setAutoCancel(true)
                        .setContentIntent(click).addAction(0, if (kind == "trial_start") "去开始" else "返回本轮", click).build()
                    // Stable tag/ID replaces the same notification if interrupted between notify and commit.
                    manager(ctx).notify(TAG, id, notification)
                    db.execSQL("UPDATE $TABLE SET state='delivered',delivered_at_ms=?,last_error='' WHERE reminder_id=?",
                        arrayOf(System.currentTimeMillis(), id))
                }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        }
        cancel(ctx, id, false)
        return true
    }
}

class EvidenceGrowthReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        ReminderRecoveryWorker.wakeful(context.applicationContext) {
            try { EvidenceGrowthReminderNative.fire(context.applicationContext, intent.getIntExtra("reminder_id", 0)) }
            catch (_: Throwable) { /* The persisted WorkManager fallback retries this event. */ }
            finally { pending.finish() }
        }
    }
}

class EvidenceGrowthReminderWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result = try {
        val id = inputData.getInt("reminder_id", 0)
        if (id > 0) EvidenceGrowthReminderNative.fire(applicationContext, id)
        else EvidenceGrowthReminderNative.reconcile(applicationContext)
        Result.success()
    } catch (_: Throwable) { if (runAttemptCount < 3) Result.retry() else Result.failure() }
}
