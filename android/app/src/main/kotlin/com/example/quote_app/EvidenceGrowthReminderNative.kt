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
import org.json.JSONArray
import com.example.quote_app.evidence.GrowthReminderText
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
    private fun journey(db: SQLiteDatabase, trial: String): JSONObject? {
        val exists = db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='evidence_growth_journeys'", null).use { it.moveToFirst() }
        if (!exists) return null
        val id = if (trial.startsWith("journey:")) trial.substring(8) else db.rawQuery(
            "SELECT journey_id FROM evidence_growth_journey_actions WHERE trial_id=?", arrayOf(trial)
        ).use { if (it.moveToFirst()) it.getString(0) else return null }
        return db.rawQuery("SELECT body_json FROM evidence_growth_journeys WHERE id=?", arrayOf(id)).use {
            if (it.moveToFirst()) JSONObject(it.getString(0)) else null
        }
    }
    private fun portfolio(db: SQLiteDatabase): JSONObject? = db.rawQuery(
        "SELECT body_json FROM evidence_growth_journeys WHERE id='portfolio'", null
    ).use { if (it.moveToFirst()) JSONObject(it.getString(0)) else null }
    private fun parentAllows(db: SQLiteDatabase, j: JSONObject): Boolean {
        if (j.optString("status") !in listOf("ACTIVE", "ACTIVE_BUILD", "RECOVERY_CYCLE")) return false
        if (j.optString("node") != "ACTION" || j.optString("readiness") in listOf("FACTS_ONLY", "DEFERRED", "RECOVERY_HOLD")) return false
        if (j.optString("mutuality") in listOf("PAUSED", "WITHDRAWN", "ENDED")) return false
        val now = System.currentTimeMillis()
        if (j.optString("event_phase") == "IN_EVENT_QUIET" && (j.optLong("event_end_ms") == 0L || j.optLong("event_end_ms") > now)) return false
        val p = portfolio(db) ?: return true
        val recovery = p.optJSONArray("protected_recovery")
        for (i in 0 until (recovery?.length() ?: 0)) {
            val slot = recovery!!.getJSONObject(i)
            if (now >= slot.optLong("start") && now < slot.optLong("end")) return false
        }
        fun satisfied(ref: String): Boolean {
            if (ref.startsWith("external:")) return p.optJSONObject("external_conditions")?.optBoolean(ref) == true
            return db.rawQuery("SELECT status FROM evidence_growth_journeys WHERE id=?", arrayOf(ref)).use {
                it.moveToFirst() && it.getString(0) in listOf("ACHIEVED", "MAINTAINING")
            }
        }
        val edges = p.optJSONArray("edges")
        for (i in 0 until (edges?.length() ?: 0)) {
            val e = edges!!.getJSONObject(i)
            if (e.optString("type") == "REQUIRES" && e.optString("from") == j.optString("id") && !satisfied(e.optString("to"))) return false
            if (e.optString("type") == "BLOCKS" && e.optString("to") == j.optString("id") && !satisfied(e.optString("from"))) return false
        }
        return true
    }
    private fun withinRepeatLimit(db: SQLiteDatabase, trial: String, inputs: JSONObject): Boolean {
        val cap = inputs.optString("max_repeat", "0").toIntOrNull() ?: 0
        if (cap <= 0) return true // Existing user policy is preserved on migration.
        val due = db.rawQuery("SELECT CASE WHEN next_review_at_ms>0 THEN next_review_at_ms ELSE review_at_ms END FROM evidence_growth_trials WHERE trial_id=?",arrayOf(trial)).use { if(it.moveToFirst()) it.getLong(0) else 0L }
        val count = db.rawQuery("SELECT COUNT(*) FROM $TABLE WHERE trial_id=? AND kind='missing_result' AND scheduled_at_ms>=? AND delivered_at_ms>0",arrayOf(trial,due.toString())).use { it.moveToFirst();it.getInt(0) }
        if(count >= cap) db.execSQL("INSERT OR REPLACE INTO evidence_growth_settings(setting_key,setting_value) VALUES (?, 'NO_REALITY_FEEDBACK')",arrayOf("feedback_state_$trial"))
        return count < cap
    }
    private fun valid(db: SQLiteDatabase, trialId: String, kind: String): Boolean {
        val global = db.rawQuery("SELECT setting_value FROM evidence_growth_settings WHERE setting_key='reminders_enabled'", null)
            .use { if (it.moveToFirst()) it.getString(0) else "true" }
        if (global == "false") return false
        val j = journey(db, trialId)
        if (kind == "journey_maintenance") return j != null && j.optString("status") == "MAINTAINING"
        if (kind == "journey_review") return j != null && j.optString("readiness") == "DEFERRED" && j.optString("node") == "REVIEW" && j.optString("status") !in listOf("ARCHIVED","CLOSED","DELETED")
        if (j != null && (j.optString("trial_id") != trialId || !parentAllows(db,j))) return false
        return db.rawQuery("SELECT status, operator, operator_inputs_json, decision FROM evidence_growth_trials WHERE trial_id=?", arrayOf(trialId)).use { c ->
            if (!c.moveToFirst()) return@use false
            val override = db.rawQuery("SELECT setting_value FROM evidence_growth_settings WHERE setting_key=?", arrayOf("remind_trial_$trialId"))
                .use { if (it.moveToFirst()) it.getString(0) else null }
            if ((override ?: JSONObject(c.getString(2)).optString("remind")) != "true") return@use false
            if (kind == "missing_result" && !withinRepeatLimit(db,trialId,JSONObject(c.getString(2)))) return@use false
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

    /** Reconstruct exactly one next missing-feedback event per active Trial.
     * Called in the delivery transaction as well as after reboot: no Flutter timer.
     */
    private fun ensureMissingPlans(db: SQLiteDatabase) {
        fun hours(key: String, fallback: Long): Long = db.rawQuery(
            "SELECT setting_value FROM evidence_growth_settings WHERE setting_key=?", arrayOf(key)
        ).use { if (it.moveToFirst()) it.getString(0).toLongOrNull()?.coerceIn(1,168) ?: fallback else fallback }
        val delay = hours("missing_result_hours",24) * 3600000
        val interval = hours("missing_repeat_hours",delay / 3600000) * 3600000
        db.rawQuery("SELECT trial_id,review_at_ms,next_review_at_ms FROM evidence_growth_trials WHERE status IN ('READY','IN_PROGRESS','OBSERVING')",null).use { trials ->
            while (trials.moveToNext()) {
                val trial = trials.getString(0)
                if (!valid(db,trial,"missing_result")) continue
                val due = if (trials.getLong(2) > 0) trials.getLong(2) else trials.getLong(1)
                if (due <= 0) continue
                val first = due + delay
                val covered = db.rawQuery("SELECT MAX(MAX(scheduled_at_ms,delivered_at_ms)) FROM $TABLE WHERE trial_id=? AND kind='missing_result' AND scheduled_at_ms>=? AND (state IN ('delivered','expired') OR delivered_at_ms>0)",arrayOf(trial,due.toString())).use {
                    if (it.moveToFirst() && !it.isNull(0)) it.getLong(0) else 0L
                }
                var at = if (covered < first) first else first + ((covered-first)/interval+1)*interval
                // Respect a different event that already occupies this minute window.
                while (true) {
                    val occupied = db.rawQuery("SELECT state,kind,delivered_at_ms FROM $TABLE WHERE trial_id=? AND window_key=?",arrayOf(trial,(at/60000).toString())).use {
                        it.moveToFirst() && (it.getString(1) != "missing_result" || it.getString(0) in listOf("delivered","expired") || it.getLong(2)>0)
                    }
                    if (!occupied) break
                    at += interval
                }
                db.execSQL("UPDATE $TABLE SET state='cancelled' WHERE trial_id=? AND kind='missing_result' AND scheduled_at_ms<>? AND state IN ('pending','scheduled','blocked')",arrayOf(trial,at))
                val window = (at/60000).toString()
                db.execSQL("INSERT OR IGNORE INTO $TABLE (event_key,trial_id,kind,scheduled_at_ms,window_key,title,body,source_ids_json,state) VALUES (?,?,'missing_result',?,?,?,?,'[\"KB35-R01\",\"KB35-G-EXT2-01\"]','pending')",
                    arrayOf("$trial:$window",trial,at,window,"证据成长｜结果节点 · 待反馈","继续之前，先补充现实证据。记录完成、部分、未做、中止或继续观察；未反馈会按设置间隔继续提醒。"))
                db.execSQL("UPDATE $TABLE SET state='pending',last_error='' WHERE trial_id=? AND window_key=? AND state='cancelled' AND delivered_at_ms=0",arrayOf(trial,window))
            }
        }
    }

    /** Boot, package update, permission return and app resume all use this path. */
    @JvmStatic fun reconcile(ctx: Context): Boolean {
        val db = database(ctx) ?: return true
        db.use {
            db.beginTransaction()
            try {
                db.rawQuery("SELECT reminder_id,trial_id,kind FROM $TABLE WHERE state='cancelled' AND last_error='JOURNEY_HOLD' AND delivered_at_ms=0",null).use { held ->
                    while(held.moveToNext()) if(valid(db,held.getString(1),held.getString(2))) db.execSQL("UPDATE $TABLE SET state='pending',last_error='' WHERE reminder_id=?",arrayOf(held.getInt(0)))
                }
                ensureMissingPlans(db); db.setTransactionSuccessful()
            } finally { db.endTransaction() }
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
                        if (state != "delivered") db.execSQL("UPDATE $TABLE SET state='cancelled',last_error='JOURNEY_HOLD' WHERE reminder_id=?", arrayOf(id))
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

    private data class Notice(val id: Int, val text: GrowthReminderText, val target: JSONObject)
    private fun notice(db: SQLiteDatabase, id: Int): Notice? {
        return db.rawQuery("SELECT trial_id,kind,scheduled_at_ms,event_key FROM $TABLE WHERE reminder_id=?", arrayOf(id.toString())).use { c ->
            if (!c.moveToFirst()) return@use null
            val trialId=c.getString(0); val kind=c.getString(1)
            val parent=journey(db,trialId); val profile=parent?.optJSONObject("profile")
            var goal=parent?.optString("title") ?: ""; var action=""; var prediction=""
            var sensitive=profile?.optBoolean("shared_body") == true || (profile != null && profile.optString("risk_class", "NORMAL") != "NORMAL")
            if (!trialId.startsWith("journey:")) db.rawQuery("SELECT goal_state,action_instruction,prediction,operator_inputs_json FROM evidence_growth_trials WHERE trial_id=?", arrayOf(trialId)).use { t ->
                if(t.moveToFirst()) {
                    if(goal.isBlank())goal=t.getString(0) ?: ""
                    action=t.getString(1) ?: ""; prediction=t.getString(2) ?: ""
                    sensitive=sensitive || JSONObject(t.getString(3)).optString("sensitive")=="true"
                }
            }
            val whenText=java.text.SimpleDateFormat("MM-dd HH:mm", java.util.Locale.getDefault()).format(java.util.Date(c.getLong(2)))
            val text=GrowthReminderText.build(kind,goal,action,prediction,whenText,parent?.optJSONObject("maintenance")?.optString("acceptable_band") ?: "",sensitive)
            val target=JSONObject().put("trial_id",if(trialId.startsWith("journey:")) "" else trialId)
                .put("journey_id",parent?.optString("id") ?: if(trialId.startsWith("journey:")) trialId.substring(8) else "")
                .put("node",text.node).put("type",kind).put("reminder_id",id).put("event_key",c.getString(3))
                .put("title",text.title+" · "+if(sensitive) "私密目标" else goal.take(36))
                .put("summary",text.body)
            Notice(id,text,target)
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
                        db.execSQL("UPDATE $TABLE SET state='cancelled',last_error='JOURNEY_HOLD' WHERE reminder_id=?", arrayOf(id))
                        db.setTransactionSuccessful(); cancel(ctx, id); return true
                    }
                    if (at > System.currentTimeMillis()) return true
                    if (status(ctx)["notifications"] != true || !ExactAlarmHelper.hasExactAlarmPermission(ctx)) {
                        db.execSQL("UPDATE $TABLE SET state='blocked',last_error='PERMISSION_UNAVAILABLE' WHERE reminder_id=?", arrayOf(id))
                        db.setTransactionSuccessful(); return true
                    }
                    val peers = mutableListOf<Int>()
                    db.rawQuery("SELECT reminder_id,trial_id,kind FROM $TABLE WHERE reminder_id<>? AND scheduled_at_ms/60000=? AND scheduled_at_ms<=? AND state IN ('pending','scheduled','blocked') ORDER BY reminder_id LIMIT 49",arrayOf(id.toString(),(at/60000).toString(),System.currentTimeMillis().toString())).use { peer ->
                        while(peer.moveToNext()) if(valid(db,peer.getString(1),peer.getString(2))) peers.add(peer.getInt(0))
                    }
                    val entries=(listOf(id)+peers).mapNotNull { notice(db,it) }
                    if(entries.isEmpty()) return true
                    val first=entries.first()
                    val many=entries.size>1
                    val labels=entries.map { GrowthReminderText.nodeLabel(it.text.node) }.distinct()
                    val title=if(many) "证据成长｜${labels.take(3).joinToString("/")} · ${entries.size}项待办" else first.text.title
                    val body=if(many) first.text.body.substringBefore("\n")+"；另有 ${entries.size-1} 项，点击逐项处理。" else first.text.body
                    val payload=JSONObject().put("module",TAG).put("version",2).put("type",if(many) "portfolio_check" else kind)
                        .put("trial_id",first.target.optString("trial_id")).put("journey_id",first.target.optString("journey_id"))
                        .put("node",first.text.node).put("reminder_id",id).put("event_key",c.getString(7))
                        .put("targets",JSONArray().apply { entries.forEach { put(it.target) } })
                        .put("source_ids",JSONArray(c.getString(5)))
                    val launch = Intent(ctx, MainActivity::class.java)
                        .setData(Uri.parse("quote-app://evidence-growth/$id"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        .putExtra("from_notification", true).putExtra("notif_type", TAG).putExtra("payload", payload.toString())
                    val click = PendingIntent.getActivity(ctx, id, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val publicNotice=NotificationCompat.Builder(ctx,CHANNEL).setSmallIcon(android.R.drawable.ic_dialog_info)
                        .setContentTitle(title).setContentText("打开查看对应事项").build()
                    val builder = NotificationCompat.Builder(ctx, CHANNEL).setSmallIcon(android.R.drawable.ic_dialog_info)
                        .setContentTitle(title).setContentText(body).setSubText("发现之旅 · 六模块证据成长")
                        .setPriority(NotificationCompat.PRIORITY_HIGH).setCategory(NotificationCompat.CATEGORY_REMINDER)
                        .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setPublicVersion(publicNotice)
                        .setOnlyAlertOnce(true).setAutoCancel(true).setContentIntent(click)
                        .addAction(0, if(many) "查看待办清单" else first.text.actionLabel, click)
                    if(many) builder.setStyle(NotificationCompat.InboxStyle().also { style ->
                        entries.take(7).forEach { style.addLine("${GrowthReminderText.nodeLabel(it.text.node)}｜${it.text.body.substringBefore("\n")}") }
                        style.setSummaryText("共 ${entries.size} 项，点击后逐项定位")
                    }) else builder.setStyle(NotificationCompat.BigTextStyle().bigText(body))
                    val notification=builder.build()
                    // Stable tag/ID replaces the same notification if interrupted between notify and commit.
                    manager(ctx).notify(TAG, id, notification)
                    for(entry in entries) {
                        db.execSQL("UPDATE $TABLE SET state='delivered',delivered_at_ms=?,last_error=?,title=?,body=? WHERE reminder_id=?",
                            arrayOf(System.currentTimeMillis(),if(entry.id==id) "" else "PORTFOLIO_MERGED",entry.text.title,entry.text.body,entry.id))
                        if(entry.id!=id)cancel(ctx,entry.id)
                    }
                    ensureMissingPlans(db)
                }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        }
        cancel(ctx, id, false)
        return reconcile(ctx)
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
