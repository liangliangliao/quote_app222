package com.example.quote_app

import android.app.Instrumentation
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.Bundle
import org.json.JSONObject
import java.io.File
import java.util.Calendar

/** Only installed on the disposable CI emulator; never included in release APK. */
class ReminderProbe : Instrumentation() {
    private var options = Bundle()
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); options = arguments ?: Bundle(); start() }
    override fun onStart() {
        val result = Bundle()
        try {
            check(Build.HARDWARE == "ranchu" || Build.HARDWARE == "goldfish") { "Disposable emulator only" }
            val phase = options.getString("phase", "kill")
            if (phase == "close_repeat") {
                val ctx = targetContext.applicationContext
                SQLiteDatabase.openDatabase(File(ctx.applicationInfo.dataDir,"app_flutter/quotes.db").absolutePath,null,SQLiteDatabase.OPEN_READWRITE).use {
                    it.execSQL("UPDATE evidence_growth_trials SET status='RESULT_CAPTURED' WHERE trial_id='ci_repeat'")
                }
                check(EvidenceGrowthReminderNative.reconcile(ctx))
                result.putString("stream","REMINDER_PROBE_READY:$phase\n")
                finish(-1,result)
                return
            }
            val id = when (phase) { "kill" -> 9101; "reboot" -> 9201; "stop" -> 9301; "repeat" -> 9401; else -> error("Unknown phase") }
            val ctx = targetContext.applicationContext
            val at = System.currentTimeMillis() + if (phase == "reboot") 180000 else 45000
            val dir = File(ctx.applicationInfo.dataDir, "app_flutter").apply { mkdirs() }
            SQLiteDatabase.openOrCreateDatabase(File(dir, "quotes.db"), null).use { db ->
                db.execSQL("CREATE TABLE IF NOT EXISTS notify_config (key TEXT PRIMARY KEY,value TEXT)")
                db.execSQL("CREATE TABLE IF NOT EXISTS evidence_growth_settings (setting_key TEXT PRIMARY KEY,setting_value TEXT)")
                db.execSQL("CREATE TABLE IF NOT EXISTS evidence_growth_trials (trial_id TEXT PRIMARY KEY,status TEXT,operator TEXT,operator_inputs_json TEXT,decision TEXT,node_ids_json TEXT,updated_at_ms INTEGER,created_at_ms INTEGER,review_at_ms INTEGER DEFAULT 0,next_review_at_ms INTEGER DEFAULT 0)")
                db.execSQL("CREATE TABLE IF NOT EXISTS evidence_growth_reminders (reminder_id INTEGER PRIMARY KEY,trial_id TEXT,kind TEXT,scheduled_at_ms INTEGER,title TEXT,body TEXT,source_ids_json TEXT,state TEXT,event_key TEXT UNIQUE,delivered_at_ms INTEGER DEFAULT 0,last_error TEXT DEFAULT '',window_key TEXT,UNIQUE(trial_id,window_key))")
                db.execSQL("INSERT OR REPLACE INTO evidence_growth_settings VALUES ('reminders_enabled','true')")
                db.execSQL("INSERT OR REPLACE INTO notify_config VALUES ('health_diet_agent_daily_schedule_enabled','1')")
                db.execSQL("INSERT OR REPLACE INTO notify_config VALUES ('health_diet_agent_schedule_notify_enabled','1')")
                db.execSQL("INSERT OR REPLACE INTO evidence_growth_settings VALUES ('missing_result_hours','1')")
                db.execSQL("INSERT OR REPLACE INTO evidence_growth_settings VALUES ('missing_repeat_hours','1')")
                db.execSQL("INSERT OR REPLACE INTO evidence_growth_trials VALUES (?, 'READY','START_5_MIN','{\"remind\":\"true\"}','','[\"KB35-A02\"]',?,?,?,0)", arrayOf("ci_$phase", at, at, if (phase == "repeat") at-3600000 else 0))
                db.execSQL("INSERT OR REPLACE INTO evidence_growth_reminders (reminder_id,trial_id,kind,scheduled_at_ms,title,body,source_ids_json,state,event_key,window_key) VALUES (?,?,?,?,?,?,'[\"KB35-A02\"]','pending',?,?)",
                    arrayOf(id, "ci_$phase", if (phase == "repeat") "missing_result" else "trial_start", at, "Growth CI $phase", "Disposable test reminder", "ci_$phase:${at/60000}", (at/60000).toString()))
            }
            check(EvidenceGrowthReminderNative.reconcile(ctx)) { "Growth registration blocked" }
            val clock = Calendar.getInstance().apply { timeInMillis = at }
            val payload = JSONObject().put("module", "health_diet").put("type", "health_diet_agent")
                .put("slot", "ci_$phase").put("target", "today_plan").put("title", "Diet CI $phase")
                .put("body", "Disposable test reminder").put("hour", clock.get(Calendar.HOUR_OF_DAY))
                .put("minute", clock.get(Calendar.MINUTE))
            check(NativeSchedulerK.scheduleExactAt(ctx, id + 10000, at, payload.toString())) { "Diet registration blocked" }
            result.putString("stream", "REMINDER_PROBE_READY:$phase\n")
            finish(-1, result)
        } catch (t: Throwable) {
            result.putString("stream", "REMINDER_PROBE_FAILED:${t.javaClass.simpleName}:${t.message}\n")
            finish(1, result)
        }
    }
}
