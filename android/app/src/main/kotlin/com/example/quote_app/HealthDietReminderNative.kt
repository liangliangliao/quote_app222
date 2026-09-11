package com.example.quote_app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.core.app.NotificationManagerCompat
import androidx.work.*
import com.example.quote_app.data.DbInspector
import com.example.quote_app.schedule.ReminderCalendar
import org.json.JSONObject
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/** Durable daily/weekly notification plans, independent of Flutter/AI workers. */
object HealthDietReminderNative {
    private fun prefs(ctx: Context) = ctx.getSharedPreferences("health_diet_native_plans", Context.MODE_PRIVATE)
    @JvmStatic @Synchronized fun remember(ctx: Context, id: Int, at: Long, raw: String?): String? {
        val data = try { JSONObject(raw ?: "{}") } catch (_: Throwable) { return raw }
        if (data.optString("module") != "health_diet") return raw
        val old = prefs(ctx).getString("$id", null)?.let { JSONObject(it).optLong("native_due_ms") }
        if (old != null && old != at) WorkManager.getInstance(ctx).cancelUniqueWork("diet_${id}_$old")
        data.put("native_due_ms", at)
        data.put("native_zone", TimeZone.getDefault().id)
        check(prefs(ctx).edit().putString("$id", data.toString()).commit())
        val fallback = OneTimeWorkRequestBuilder<HealthDietReminderWorker>()
            .setInputData(Data.Builder().putInt("id", id).putLong("at", at).build())
            .setInitialDelay(maxOf(0L, at + 120000 - System.currentTimeMillis()), TimeUnit.MILLISECONDS).build()
        WorkManager.getInstance(ctx).enqueueUniqueWork("diet_${id}_$at", ExistingWorkPolicy.KEEP, fallback)
        return data.toString()
    }
    @JvmStatic @Synchronized fun forget(ctx: Context, id: Int) {
        val raw = prefs(ctx).getString("$id", null) ?: return
        val at = JSONObject(raw).optLong("native_due_ms")
        prefs(ctx).edit().remove("$id").commit()
        WorkManager.getInstance(ctx).cancelUniqueWork("diet_${id}_$at")
    }
    private fun enabled(ctx: Context): Boolean {
        val path = DbInspector.loadOrLightScan(ctx)?.dbPath ?: throw IllegalStateException("DATABASE_UNAVAILABLE")
        SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
            for (key in listOf("health_diet_agent_daily_schedule_enabled", "health_diet_agent_schedule_notify_enabled")) {
                val value = db.rawQuery("SELECT value FROM notify_config WHERE key=?", arrayOf(key)).use { if (it.moveToFirst()) it.getString(0) else "1" }
                if (value.trim().lowercase() !in listOf("1", "true", "yes")) return false
            }
        }
        return true
    }
    private fun next(data: JSONObject): Long = ReminderCalendar.next(System.currentTimeMillis(),
        data.getInt("hour"), data.getInt("minute"), data.optInt("weekday", 0), TimeZone.getDefault())
    @JvmStatic @Synchronized fun restore(ctx: Context, resetClock: Boolean = false) {
        val plans = prefs(ctx).all.filterKeys { it.toIntOrNull() != null }
        if (plans.isEmpty()) return
        val on = enabled(ctx)
        for ((key, raw) in plans) {
            val id = key.toInt()
            if (!on) { NativeSchedulerK.cancel(ctx, id); continue }
            val data = JSONObject(raw as String)
            var at = data.getLong("native_due_ms")
            // Expired meal slots are not replayed as a whole historical backlog.
            if (resetClock || data.optString("native_zone", TimeZone.getDefault().id) != TimeZone.getDefault().id || System.currentTimeMillis() - at > 7200000) at = next(data)
            check(NativeSchedulerK.scheduleExactAt(ctx, id, at, data.toString())) { "DIET_SCHEDULE_FAILED" }
        }
    }
    @JvmStatic @Synchronized fun fire(ctx: Context, id: Int, at: Long) {
        val raw = prefs(ctx).getString("$id", null) ?: return
        val data = JSONObject(raw)
        if (data.getLong("native_due_ms") != at || at > System.currentTimeMillis()) return
        if (!enabled(ctx)) { NativeSchedulerK.cancel(ctx, id); return }
        if (!NotificationManagerCompat.from(ctx).areNotificationsEnabled()) return
        // Re-arm before optional display; a display error cannot break tomorrow's schedule.
        NativeSchedulerK.scheduleExactAt(ctx, id, next(data), raw)
        if (System.currentTimeMillis() - at > 7200000) return
        NotifyHelper.send(ctx, id, data.optString("title", "健康饮食 Agent"),
            data.optString("body", "到时间了，点击查看本次饮食安排或完成记录。"), null, "health_diet_agent", raw)
    }
}

class HealthDietReminderWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result = try {
        HealthDietReminderNative.fire(applicationContext, inputData.getInt("id", 0), inputData.getLong("at", 0))
        Result.success()
    } catch (_: Throwable) { if (runAttemptCount < 5) Result.retry() else Result.failure() }
}
