package com.example.quote_app.am;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.text.TextUtils;
import java.util.Calendar;

import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;

import androidx.work.WorkManager;

import com.example.quote_app.NotifyHelper;
import com.example.quote_app.NativeSchedulerK;
import com.example.quote_app.biz.Biz;
import com.example.quote_app.data.DbRepository;
import com.example.quote_app.data.DbInspector;
import com.example.quote_app.wm.WmScheduler;
import com.example.quote_app.wm.WmNames;
import com.example.quote_app.schedule.AutoRescheduler;

import org.json.JSONObject;

public final class AlarmReceiver extends BroadcastReceiver {
    private static final String TAG_LOG = "AlarmReceiver";
    @Override public void onReceive(Context context, Intent intent) {
        try { com.example.quote_app.data.DbRepo.log(context, null, "【原生】AM 广播触发"); } catch (Throwable ignore) {}
        String _act = intent==null?null:intent.getAction();
try { com.example.quote_app.data.DbRepo.log(context, null, "【原生】AM Intent action="+String.valueOf(_act)); } catch (Throwable ignore) {}
int id = intent != null ? intent.getIntExtra("id", 0) : 0;
        String payload = intent != null ? intent.getStringExtra("payload") : "{}";
        String uid = null;
        String runKey = "";

        // === Sport alarms (no uid) ===
        // Sport alarms use payload.type=sport_fullscreen / sport_reminder / sport_midnight_renew.
        // They must work even when the app process was killed.
        try {
            JSONObject o = new JSONObject(payload == null ? "{}" : payload);
            String type = o.optString("type", "");
            if (type != null && type.startsWith("sport_")) {
                if ("sport_midnight_renew".equals(type)) {
                    try { com.example.quote_app.sport.SportPlanRenewal.runMidnightRenew(context.getApplicationContext()); } catch (Throwable ignore) {}
                    return;
                }

                // Defensive: avoid showing stale notifications when old alarms still exist.
                // If payload carries planId+planTime, verify it matches current plan_time in DB.
                try {
                    int planId = o.optInt("planId", 0);
                    String planTime = o.optString("planTime", "");
                    if (planId > 0 && !TextUtils.isEmpty(planTime)) {
                        String cur = querySportPlanTime(context.getApplicationContext(), planId);
                        if (!TextUtils.isEmpty(cur) && !planTime.equals(cur)) {
                            // Stale alarm: cancel and ignore.
                            try { NativeSchedulerK.cancel(context.getApplicationContext(), id); } catch (Throwable ignore) {}
                            return;
                        }
                    }
                } catch (Throwable ignore) {}

                if ("sport_fullscreen".equals(type)) {
                    NotifyHelper.sendSportFullScreen(
                        context.getApplicationContext(),
                        id,
                        "运动开始",
                        "点击进入运动进行中",
                        type,
                        payload == null ? "{}" : payload
                    );
                } else {
                    NotifyHelper.sendSportReminder(
                        context.getApplicationContext(),
                        id,
                        "运动提醒",
                        "点击查看运动计划",
                        type,
                        payload == null ? "{}" : payload
                    );
                }
                return;
            }
        } catch (Throwable ignore) {}

        try {
            DbRepository.log(context.getApplicationContext(), uid==null?"":uid, "【原生】AM 触发 uid="+(uid==null?"":uid)+" run="+runKey);
            JSONObject obj = new JSONObject(payload == null ? "{}" : payload);
            uid = obj.optString("uid", null);
            runKey = obj.optString("runKey", "");
            try { DbRepository.log(context.getApplicationContext(), uid==null?"":uid, "【原生】AM 触发(解析后) uid="+(uid==null?"":uid)+" run="+runKey); } catch (Throwable ignore) {}

        } catch (Throwable ignore) {}

        if (TextUtils.isEmpty(uid)) {
            // 行为观察提醒：无 uid，但 payload 携带 module=behavior_tracking。
            // 需要保留 payload/type，点击通知后 Flutter 才能路由到对应模板。
            try {
                JSONObject obj = new JSONObject(payload == null ? "{}" : payload);
                String module = obj.optString("module", "");
                if ("health_diet".equals(module)) {
                    String title = obj.optString("title", "健康饮食 Agent");
                    String body = obj.optString("body", "到时间了，点击查看本次饮食安排或完成记录。");
                    NotifyHelper.send(
                        context.getApplicationContext(),
                        id,
                        title,
                        body,
                        null,
                        "health_diet_agent",
                        payload == null ? "{}" : payload
                    );
                    scheduleNextHealthDietReminder(context.getApplicationContext(), id, obj, payload);
                    return;
                }
                if ("zhixing_tree".equals(module)) {
                    String title = obj.optString("title", "知行树行动导师");
                    String body = obj.optString("body", "点击查看当前目标、行动与复盘建议");
                    NotifyHelper.send(
                        context.getApplicationContext(),
                        id,
                        title,
                        body,
                        null,
                        "zhixing_tree",
                        payload == null ? "{}" : payload
                    );
                    return;
                }
                if ("belief_mentor".equals(module)) {
                    String title = obj.optString("title", "Belief Mentor");
                    String body = obj.optString("body", "点击继续你的信念实验");
                    NotifyHelper.send(
                        context.getApplicationContext(),
                        id,
                        title,
                        body,
                        null,
                        "belief_mentor",
                        payload == null ? "{}" : payload
                    );
                    markBeliefMentorReminderSent(
                        context.getApplicationContext(),
                        obj.optString("reminderId", ""),
                        obj.optString("beliefId", ""),
                        obj.optString("experimentId", ""),
                        obj.optString("type", ""),
                        obj.optLong("scheduledAtMs", 0L),
                        id
                    );
                    return;
                }
                if ("behavior_tracking".equals(module)) {
                    String type = obj.optString("type", "");
                    if ("behavior_auto_sync".equals(type)) {
                        String result = com.example.quote_app.BehaviorObservationNativeImporter.runAutoSync(context.getApplicationContext(), payload == null ? "{}" : payload);
                        String body = "自动读取完成，结果已进入待确认队列。";
                        try { body = new JSONObject(result).optString("message", body); } catch (Throwable ignore2) {}
                        NotifyHelper.sendBehaviorObservationAutoSyncResult(context.getApplicationContext(), id, body);
                        return;
                    }
                    if ("behavior_preset_alarm".equals(type) || "behavior_preset_setup_alarm".equals(type)) {
                        String mergedPayload = payload == null ? "{}" : payload;
                        try { mergedPayload = com.example.quote_app.BehaviorPresetAlarmScheduler.normalizePayloadForFire(context.getApplicationContext(), mergedPayload); } catch (Throwable ignore2) {}
                        String fireKey = "";
                        try { fireKey = com.example.quote_app.BehaviorPresetAlarmScheduler.fireKey(mergedPayload); } catch (Throwable ignore2) {}
                        try {
                            android.content.SharedPreferences prefs = context.getApplicationContext().getSharedPreferences("behavior_preset_alarm_fire_guard", Context.MODE_PRIVATE);
                            String lastKey = prefs.getString("last_key", "");
                            long lastAt = prefs.getLong("last_at", 0L);
                            long nowMs = System.currentTimeMillis();
                            if (!TextUtils.isEmpty(fireKey) && fireKey.equals(lastKey) && nowMs - lastAt < 60_000L) {
                                try { DbRepository.log(context.getApplicationContext(), "", "[BehaviorPresetAlarm] duplicate fire ignored key=" + fireKey + " id=" + id); } catch (Throwable ignore3) {}
                                return;
                            }
                            prefs.edit().putString("last_key", fireKey).putLong("last_at", nowMs).apply();
                        } catch (Throwable ignore2) {}
                        try { com.example.quote_app.BehaviorPresetAlarmRingingService.startRinging(context.getApplicationContext(), id, mergedPayload); } catch (Throwable ringErr) {
                            try { DbRepository.log(context.getApplicationContext(), "", "[BehaviorPresetAlarm] legacy start ringing service failed: " + ringErr.getClass().getSimpleName() + " " + ringErr.getMessage()); } catch (Throwable ignore3) {}
                        }
                        // v40: BehaviorPresetAlarmRingingService owns overlay + full-screen notification UI. Avoid a
                        // second helper notification here, which can trigger duplicate foreground forms on some ROMs.
                        try { com.example.quote_app.BehaviorPresetAlarmScheduler.scheduleNextAfterFire(context.getApplicationContext(), mergedPayload); } catch (Throwable ignore2) {}
                        return;
                    }
                    String title = obj.optString("title", "行为观察提醒");
                    String body = obj.optString("body", obj.optString("message", "点击通知，选择观察层面，再填写对应字段表单"));
                    NotifyHelper.sendBehaviorObservationReminder(context.getApplicationContext(), id, title, body, payload == null ? "{}" : payload);
                    return;
                }
            } catch (Throwable ignore) {}

            // 兜底：没有 uid 仍然发一个到点提醒
            String title = "提醒";
            String body = "到点了";
            try { NotifyHelper.send(context.getApplicationContext(), id, title, body, null); } catch (Throwable ignore) {}
            return;
        }

        boolean entered = false;
        try {
            entered = DbRepository.runGuardBegin(context.getApplicationContext(), uid, runKey, "am");
            if (!entered) return;

            boolean handled = Biz.run(context.getApplicationContext(), uid);
            if (handled) {
                DbRepository.log(context.getApplicationContext(), uid, "【原生】AM 发送成功 uid="+uid+" run="+runKey);
                // 通知成功：标记成功并取消兜底和当前任务，安排下一次
                DbRepository.markLatestSuccess(context.getApplicationContext(), uid);
                try { android.util.Log.d(TAG_LOG, "before rotateCursorByTaskType");
        DbRepository.rotateCursorByTaskType(context.getApplicationContext(), uid); } catch (Throwable ignore) {}
                try { android.util.Log.d(TAG_LOG, "before updateQuoteNotify");
        DbRepository.updateQuoteNotify(context.getApplicationContext(), uid, true, System.currentTimeMillis());
                try { DbRepository.log(context.getApplicationContext(), uid, "【DB】(AM) cursor+1 & quote updated(success)"); } catch (Throwable ignore) {} } catch (Throwable ignore) {}
                // Cancel fallback by unique id
                try {
                    String fbId = WmNames.fbUnique(uid, runKey);
                    WmScheduler.cancelFallback(context.getApplicationContext(), fbId);
                } catch (Throwable ignore) {}
                // Cancel current AM
                try {
                    NativeSchedulerK.cancel(context.getApplicationContext(), id);
                } catch (Throwable ignore) {}
                // schedule next via AutoRescheduler
                AutoRescheduler.scheduleNext(context.getApplicationContext(), uid);
            } else {
                DbRepository.log(context.getApplicationContext(), uid, "【原生】AM 发送失败 uid="+uid+" run="+runKey);
                DbRepository.log(context.getApplicationContext(), uid, "AM通道：业务未处理");
                try { android.util.Log.d(TAG_LOG, "before rotateCursorByTaskType");
        DbRepository.rotateCursorByTaskType(context.getApplicationContext(), uid); } catch (Throwable ignore) {}
                try { android.util.Log.d(TAG_LOG, "before updateQuoteNotify");
        DbRepository.updateQuoteNotify(context.getApplicationContext(), uid, false, System.currentTimeMillis());
                try { DbRepository.log(context.getApplicationContext(), uid, "【DB】(AM) cursor+1 & quote updated(fail)"); } catch (Throwable ignore) {} } catch (Throwable ignore) {}
                // 通知失败：取消当前 AM，并安排下一次（兜底保持不动）
                try {
                    NativeSchedulerK.cancel(context.getApplicationContext(), id);
                } catch (Throwable ignore) {}
                AutoRescheduler.scheduleNext(context.getApplicationContext(), uid);
            }
        } catch (Throwable t) {
            DbRepository.log(context.getApplicationContext(), uid, "AM异常: " + (t.getMessage()==null?"未知错误":t.getMessage()));
            // Exception: cancel current and schedule next to avoid losing future tasks
            try {
                NativeSchedulerK.cancel(context.getApplicationContext(), id);
            } catch (Throwable ignore) {}
            try { AutoRescheduler.scheduleNext(context.getApplicationContext(), uid); } catch (Throwable ignore) {}
        } finally {
            try { DbRepository.runGuardEnd(context.getApplicationContext(), uid, runKey, "am"); } catch (Throwable ignore) {}
        }
    }

    /** Keep the lightweight native reminder alive without requiring the Flutter process. */
    private static void scheduleNextHealthDietReminder(Context context, int id, JSONObject payloadObject, String payload) {
        try {
            int hour = payloadObject.optInt("hour", -1);
            int minute = payloadObject.optInt("minute", -1);
            if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return;

            Calendar now = Calendar.getInstance();
            Calendar next = Calendar.getInstance();
            next.set(Calendar.HOUR_OF_DAY, hour);
            next.set(Calendar.MINUTE, minute);
            next.set(Calendar.SECOND, 0);
            next.set(Calendar.MILLISECOND, 0);

            int dartWeekday = payloadObject.optInt("weekday", 0);
            if (dartWeekday >= 1 && dartWeekday <= 7) {
                int calendarWeekday = dartWeekday == 7 ? Calendar.SUNDAY : dartWeekday + 1;
                int days = (calendarWeekday - next.get(Calendar.DAY_OF_WEEK) + 7) % 7;
                if (days == 0 && next.getTimeInMillis() <= now.getTimeInMillis() + 60000L) days = 7;
                next.add(Calendar.DAY_OF_YEAR, days);
            } else if (next.getTimeInMillis() <= now.getTimeInMillis() + 60000L) {
                next.add(Calendar.DAY_OF_YEAR, 1);
            }
            NativeSchedulerK.scheduleExactAt(context, id, next.getTimeInMillis(), payload == null ? "{}" : payload);
        } catch (Throwable ignore) {}
    }

    /** Query current plan_time for sport plan to avoid showing stale notifications from legacy alarms. */
    private static String querySportPlanTime(Context ctx, int planId) {
        SQLiteDatabase db = null;
        Cursor c = null;
        try {
            DbInspector.Contract cc = DbInspector.loadOrLightScan(ctx.getApplicationContext());
            if (cc == null || TextUtils.isEmpty(cc.dbPath)) return "";
            db = SQLiteDatabase.openDatabase(cc.dbPath, null, SQLiteDatabase.OPEN_READONLY);
            c = db.rawQuery("SELECT plan_time FROM sport_plans WHERE id=? LIMIT 1", new String[]{String.valueOf(planId)});
            if (c.moveToFirst()) {
                String v = c.getString(0);
                return v == null ? "" : v;
            }
        } catch (Throwable ignore) {
        } finally {
            try { if (c != null) c.close(); } catch (Throwable ignore) {}
            try { if (db != null) db.close(); } catch (Throwable ignore) {}
        }
        return "";
    }

    /** Keep the local reminder state and weekly report truthful when the alarm fires natively. */
    private static void markBeliefMentorReminderSent(
        Context ctx,
        String reminderId,
        String beliefId,
        String experimentId,
        String reminderType,
        long scheduledAtMs,
        int alarmId
    ) {
        if (TextUtils.isEmpty(reminderId)) return;
        SQLiteDatabase db = null;
        try {
            DbInspector.Contract cc = DbInspector.loadOrLightScan(ctx.getApplicationContext());
            if (cc == null || TextUtils.isEmpty(cc.dbPath)) return;
            db = SQLiteDatabase.openDatabase(cc.dbPath, null, SQLiteDatabase.OPEN_READWRITE);
            long now = System.currentTimeMillis();
            android.database.sqlite.SQLiteStatement update = db.compileStatement(
                "UPDATE belief_mentor_reminders SET state='sent', updated_at_ms=? WHERE id=? AND state IN ('created','scheduled','snoozed','rescheduled')"
            );
            update.bindLong(1, now);
            update.bindString(2, reminderId);
            int changed = update.executeUpdateDelete();
            update.close();
            if (changed == 0) return;
            JSONObject properties = new JSONObject();
            try {
                properties.put("type", reminderType == null ? "" : reminderType);
                properties.put("scheduled_delta_seconds", scheduledAtMs <= 0L ? 0L : Math.max(0L, (now - scheduledAtMs) / 1000L));
            } catch (Throwable ignore) {}
            db.execSQL(
                "INSERT OR IGNORE INTO belief_mentor_events(id,event_name,belief_id,experiment_id,properties_json,created_at_ms) VALUES(?,?,?,?,?,?)",
                new Object[]{"event_native_" + reminderId, "reminder_sent", beliefId, experimentId, properties.toString(), now}
            );
        } catch (Throwable ignore) {
        } finally {
            try { if (db != null) db.close(); } catch (Throwable ignore) {}
        }
    }
}
