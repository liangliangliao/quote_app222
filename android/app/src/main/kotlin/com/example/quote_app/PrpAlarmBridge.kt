package com.example.quote_app

import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.Calendar
import java.util.Locale
import kotlin.math.roundToInt

/** The native host reads PRP's existing local ledger, including when Flutter is stopped.
 * It does not create alarms, notifications, missing check-ins, or legacy module tables. */
object PrpAlarmBridge {
    const val ACTION_CHANGED = "com.example.quote_app.PRP_CHANGED"
    @Volatile private var runtimeState: JSONObject? = null
    private var channel: MethodChannel? = null
    data class Hint(val lessonId: Long, val recallId: Long, val subject: String,
        val rule: String, val worked: String, val voicePath: String, val autoPlay: Boolean)

    fun register(engine: FlutterEngine, context: Context) {
        val bridge = MethodChannel(engine.dartExecutor.binaryMessenger, "prp.native")
        channel = bridge
        val app = context.applicationContext
        engine.addEngineLifecycleListener(object: FlutterEngine.EngineLifecycleListener {
            override fun onPreEngineRestart() { if (channel === bridge) flutterStopped(app) }
            override fun onEngineWillDestroy() {
                if (channel === bridge) { channel=null; flutterStopped(app) }
            }
        })
        bridge.setMethodCallHandler { call, result ->
            when (call.method) {
                "state_changed" -> {
                    stateChanged(context, JSONObject(call.arguments as? Map<*, *> ?: emptyMap<String, Any>()))
                    result.success(null)
                }
                "stop_audio" -> { PrpAlarmAudio.stop(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    /** A destroyed Flutter view cannot keep a native reminder suppressed forever.
     * Keep all negative safety/consent gates; only the active-view flag expires. */
    fun flutterStopped(context: Context) {
        runtimeState = runtimeState?.let { JSONObject(it.toString()).apply { remove("session_active") } }
        context.sendBroadcast(Intent(ACTION_CHANGED).setPackage(context.packageName))
    }

    private fun ledgerChanged(context: Context) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try { channel?.invokeMethod("ledger_changed",null) } catch (_: Throwable) {}
            context.sendBroadcast(Intent(ACTION_CHANGED).setPackage(context.packageName))
        }
    }

    fun stateChanged(context: Context, state: JSONObject) {
        runtimeState = state
        if (!state.optBoolean("enabled", false) || !state.optBoolean("voice", false) ||
            !state.optBoolean("native_reminders", false) || state.optBoolean("circuit_open", false) ||
            state.optLong("crisis_until_ms", 0) > System.currentTimeMillis()) PrpAlarmAudio.stop()
        PrpAlarmAudio.refreshGate()
        context.sendBroadcast(Intent(ACTION_CHANGED).setPackage(context.packageName))
    }

    private fun open(context: Context, write: Boolean = false): SQLiteDatabase? {
        val path = File(context.applicationInfo.dataDir, "app_flutter/quotes.db")
        if (!path.isFile) return null
        return try { SQLiteDatabase.openDatabase(path.path, null,
            if (write) SQLiteDatabase.OPEN_READWRITE else SQLiteDatabase.OPEN_READONLY) }
        catch (_: Throwable) { null }
    }
    private fun has(db: SQLiteDatabase, table: String): Boolean =
        db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?", arrayOf(table)).use { it.moveToFirst() }
    private fun value(db: SQLiteDatabase, table: String, key: String): String? {
        if (!has(db, table)) return null
        return db.rawQuery("SELECT value FROM $table WHERE key=?", arrayOf(key)).use { if (it.moveToFirst()) it.getString(0) else null }
    }
    private fun preferences(db: SQLiteDatabase): JSONObject? = try {
        JSONObject(value(db, "notify_config", "prp.preferences.v1") ?: "{}")
    } catch (_: Throwable) { null }

    private fun allowed(db: SQLiteDatabase, voice: Boolean = false): Boolean {
        val now = System.currentTimeMillis()
        val state = runtimeState
        if (state != null && (!state.optBoolean("enabled", false) || state.optBoolean("circuit_open", false) ||
            state.optLong("crisis_until_ms", 0) > now || state.optBoolean("session_active",false) || !state.optBoolean("native_reminders", false) || !state.optBoolean("recalls", true) ||
            state.optJSONObject("surfaces")?.optBoolean("behavior", true) == false ||
            (voice && !state.optBoolean("voice", false)))) return false
        val p = preferences(db) ?: return false
        if (!p.optBoolean("enabled", false) || !p.optBoolean("native_reminders", false) ||
            !p.optBoolean("recalls", true) || p.optJSONObject("surfaces")?.optBoolean("behavior", true) == false ||
            (voice && !p.optBoolean("voice", false))) return false
        if ((value(db, "notify_config", "prp.crisis_until_ms")?.toLongOrNull() ?: 0) > now) return false
        if ((value(db, "be_setting", "muted_until_ms")?.toLongOrNull() ?: 0) > now) return false
        val start = (value(db, "be_setting", "quiet_start_hour")?.toIntOrNull() ?: 23).coerceIn(0, 23)
        val end = (value(db, "be_setting", "quiet_end_hour")?.toIntOrNull() ?: 7).coerceIn(0, 23)
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        if (start != end && (if (start < end) hour >= start && hour < end else hour >= start || hour < end)) return false
        return true
    }
    fun dayStart(now: Long): Long = Calendar.getInstance().apply {
        timeInMillis = now; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    private fun grams(text: String): Set<String> {
        val points = text.lowercase(Locale.ROOT)
            .replace(Regex("[\\p{P}\\s]"), "").codePoints().toArray().map { String(Character.toChars(it)) }
        if (points.size < 2) return points.toSet()
        return (0 until points.size - 1).map { points[it] + points[it+1] }.toSet()
    }
    private fun similarity(a: String, b: String): Double {
        val x = grams(a); val y = grams(b)
        if (x.isEmpty() || y.isEmpty()) return 0.0
        return x.intersect(y).size.toDouble() / x.union(y).size
    }

    /** Same context/ref as Flutter's daily-confirmation recall, so one exposure
     * is reused by the service, overlay, form and Flutter reminder. */
    fun autoVoiceEnabled(context: Context): Boolean = try {
        open(context)?.use { db -> allowed(db, true) &&
            runtimeState?.optBoolean("native_voice", false) != false &&
            preferences(db)?.optBoolean("native_voice", false) == true &&
            BehaviorPresetAlarmSettings.getVolume(context) > 0f } ?: false
    } catch (_: Throwable) { false }

    fun hint(context: Context, payload: JSONObject, requireVoice: Boolean = false): Hint? {
        if (payload.optBoolean("setupRequired", false) || payload.optString("type") in
            listOf("behavior_preset_daily_review", "behavior_preset_setup_alarm")) return null
        val today = dayStart(System.currentTimeMillis())
        val date = dayStart(payload.optLong("checkDateMs", today))
        if (date != today) return null
        open(context)?.use { if (!allowed(it) || !has(it, "prp_lesson") || !has(it, "prp_recall")) return null } ?: return null
        val subjects = mutableMapOf<String, String>()
        fun add(p: JSONObject) {
            val id = p.optInt("presetId", p.optInt("id", 0))
            if (id > 0) subjects["habit:preset:$id"] = p.optString("presetName", p.optString("name", ""))
        }
        add(payload)
        val presets = payload.optJSONArray("presets")
        if (presets != null) for (i in 0 until presets.length()) presets.optJSONObject(i)?.let(::add)
        if (subjects.isEmpty()) return null
        return try { open(context, true)?.use { db ->
            db.beginTransaction()
            try {
                if (!allowed(db)) return null
                data class Candidate(val id: Long, val subject: String, val text: String,
                    val worked: String, val path: String, val score: Int, val sealed: Long)
                var best: Candidate? = null
                db.rawQuery("SELECT id,subject_key,trigger_text,if_cue,then_action,worked,voice_path,sealed_ms FROM prp_lesson WHERE state='sealed'", null).use { c ->
                    while (c.moveToNext()) for ((subject, name) in subjects) {
                        if (requireVoice && !PrpAlarmAudio.validClip(context,c.getString(6) ?: "")) continue
                        val score = if (subject == c.getString(1)) 100 else {
                            val sim = similarity((c.getString(2) ?: "") + (c.getString(3) ?: ""), name)
                            if (sim >= .26) (sim * 50).roundToInt() else 0
                        }
                        if (score <= 0) continue
                        val candidate = Candidate(c.getLong(0), subject,
                            "如果${c.getString(3)}，我就${c.getString(4)}", c.getString(5) ?: "[]", c.getString(6) ?: "", score, c.getLong(7))
                        val current = best
                        if (current == null || score > current.score || score == current.score && candidate.sealed > current.sealed) best = candidate
                    }
                }
                val chosen = best ?: return null
                val id = chosen.subject.substringAfterLast(':')
                val ref = "preset:$id:$date"
                var recallId: Long? = null
                db.rawQuery("SELECT id,outcome FROM prp_recall WHERE lesson_id=? AND surface='behavior' AND context='habit_reminder' AND ref=? AND ts>=? LIMIT 1",
                    arrayOf(chosen.id.toString(), ref, today.toString())).use { c ->
                    if (c.moveToFirst()) {
                        if (c.getString(1) != "pending") return null
                        recallId = c.getLong(0)
                    }
                }
                if (recallId == null) {
                    val cap = (preferences(db)?.optInt("recall_cap", 1) ?: 1).coerceIn(0, 3)
                    val count = db.rawQuery("SELECT COUNT(*) FROM prp_recall WHERE ts>=?", arrayOf(today.toString())).use { it.moveToFirst(); it.getInt(0) }
                    if (count >= cap) return null
                    val ignored = db.rawQuery("SELECT id FROM prp_recall WHERE outcome='ignored' AND ts>? LIMIT 1",
                        arrayOf((System.currentTimeMillis() - 86400000L).toString())).use { it.moveToFirst() }
                    if (ignored) return null
                    val values = android.content.ContentValues().apply {
                        put("lesson_id", chosen.id); put("ts", System.currentTimeMillis()); put("surface", "behavior")
                        put("subject_key", chosen.subject); put("context", "habit_reminder"); put("ref", ref)
                    }
                    recallId = db.insertOrThrow("prp_recall", null, values)
                }
                if (!allowed(db)) return null
                val worked = try { val a = org.json.JSONArray(chosen.worked); (0 until a.length()).joinToString("；") { a.optString(it) } } catch (_: Throwable) { "" }
                val result = Hint(chosen.id, recallId!!, chosen.subject, chosen.text, worked, chosen.path,
                    preferences(db)?.optBoolean("native_voice", false) == true)
                db.setTransactionSuccessful()
                result
            } finally { db.endTransaction() }
        } } catch (_: Throwable) { null }
    }

    fun stillAllowed(context: Context, hint: Hint, voice: Boolean = false, automatic: Boolean = false): Boolean = try {
        open(context)?.use { db ->
            allowed(db, voice) && (!automatic || (runtimeState?.optBoolean("native_voice", false) != false &&
                preferences(db)?.optBoolean("native_voice", false) == true)) &&
            db.rawQuery("SELECT l.id FROM prp_lesson l JOIN prp_recall r ON r.lesson_id=l.id WHERE l.id=? AND l.state='sealed' AND r.id=? AND r.outcome='pending'",
                arrayOf(hint.lessonId.toString(), hint.recallId.toString())).use { it.moveToFirst() }
        } ?: false
    } catch (_: Throwable) { false }

    fun adopt(context: Context, hint: Hint): Boolean { return try {
        open(context, true)?.use { db ->
            db.beginTransaction()
            try {
                if (!allowed(db)) return false
                val valid = db.rawQuery("SELECT r.id FROM prp_recall r JOIN prp_lesson l ON l.id=r.lesson_id WHERE r.id=? AND r.outcome='pending' AND l.id=? AND l.state='sealed'",
                    arrayOf(hint.recallId.toString(), hint.lessonId.toString())).use { it.moveToFirst() }
                if (!valid) return false
                db.execSQL("CREATE TABLE IF NOT EXISTS prp_event (id INTEGER PRIMARY KEY AUTOINCREMENT,kind TEXT NOT NULL,recall_id INTEGER NOT NULL,created_ms INTEGER NOT NULL,UNIQUE(kind,recall_id),FOREIGN KEY(recall_id) REFERENCES prp_recall(id) ON DELETE CASCADE)")
                db.execSQL("INSERT OR IGNORE INTO prp_event(kind,recall_id,created_ms) VALUES ('recall_adopted',?,?)", arrayOf(hint.recallId, System.currentTimeMillis()))
                db.setTransactionSuccessful(); ledgerChanged(context); true
            } finally { db.endTransaction() }
        } ?: false
    } catch (_: Throwable) { false } }

    fun report(context: Context, hint: Hint, outcome: String): Boolean {
        if (outcome !in listOf("helped", "repeated", "ignored")) return false
        return try { open(context, true)?.use { db ->
            db.beginTransaction()
            try {
                if (!allowed(db)) return false
                val valid = db.rawQuery("SELECT r.id FROM prp_recall r JOIN prp_lesson l ON l.id=r.lesson_id WHERE r.id=? AND l.id=? AND l.state='sealed' AND r.outcome='pending'",
                    arrayOf(hint.recallId.toString(), hint.lessonId.toString())).use { it.moveToFirst() }
                if (!valid) return false
                db.execSQL("UPDATE prp_recall SET outcome=?,outcome_ms=? WHERE id=? AND outcome='pending'", arrayOf(outcome,System.currentTimeMillis(),hint.recallId))
                if (outcome != "ignored") {
                    val column = if (outcome == "helped") "verified_cnt" else "repeated_cnt"
                    db.execSQL("UPDATE prp_lesson SET $column=$column+1 WHERE id=?", arrayOf(hint.lessonId))
                }
                db.setTransactionSuccessful(); ledgerChanged(context); true
            } finally { db.endTransaction() }
        } ?: false } catch (_: Throwable) { false }
    }
}
