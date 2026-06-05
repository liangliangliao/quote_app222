package com.example.quote_app.schedule;

import android.content.Context;

import androidx.work.Data;
import androidx.work.OneTimeWorkRequest;
import androidx.work.ExistingWorkPolicy;
import androidx.work.WorkManager;

import com.example.quote_app.ExactAlarmHelper;
import com.example.quote_app.NativeSchedulerK;
import com.example.quote_app.compat.DartParity;
import com.example.quote_app.data.DbRepository;
import com.example.quote_app.wm.FallbackWorker;
import com.example.quote_app.wm.WmNames;
import com.example.quote_app.wm.WmScheduler;

import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.TimeUnit;

/**
 * Helper to automatically schedule the next execution for a task on the native side.
 * It mirrors the Dart‑side scheduleNextForTask but operates purely in native code.
 * Given a task UID, it computes the next trigger time using {@link NextTriggerCalculator},
 * formats a human‑readable runKey, updates the scheduled run key for debug purposes,
 * checks whether precise alarm permission is available, and registers the appropriate
 * AM and/or WM tasks with unique identifiers. Fallback tasks are delayed by +2 minutes.
 */
public final class AutoRescheduler {
    private AutoRescheduler() {}

    /**
     * Compute the next run time for the given UID and schedule the next AM/WM tasks.
     *
     * @param ctx Android context
     * @param uid task unique identifier
     */
    public static void scheduleNext(Context ctx, String uid) {
        if (uid == null || uid.isEmpty()) return;
        long next = NextTriggerCalculator.compute(ctx, uid);
        if (next <= 0L) return;
        // Build runKey (human‑readable) matching Dart format "yyyy‑MM‑dd HH:mm:ss"
        String runKey;
        try {
            SimpleDateFormat fmt = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US);
            runKey = fmt.format(new Date(next));
        } catch (Throwable t) {
            runKey = "ts_" + next;
        }
        // Persist scheduled runKey for debugging via DbRepository
        try { DbRepository.setScheduledRunKey(ctx, uid, runKey); } catch (Throwable ignore) {}
        try { DbRepository.setNextTime(ctx, uid, next); } catch (Throwable ignore) {}
        long now = System.currentTimeMillis();
        boolean hasExact = false;
        try {
            hasExact = ExactAlarmHelper.INSTANCE.hasExactAlarmPermission(ctx);
        } catch (Throwable ignore) {}
        if (hasExact) {
            // When precise alarm is allowed: register AM and fallback WM
            try {
                int alarmId = DartParity.alarmId(uid, runKey);
                // Build JSON payload containing uid and runKey; AlarmReceiver extracts these fields
                String payload = new JSONObject()
                        .put("uid", uid)
                        .put("runKey", runKey)
                        .toString();
                NativeSchedulerK.scheduleExactAt(ctx, alarmId, next, payload);
                DbRepository.log(ctx, uid, "【原生】AM 自动续排注册 uid="+uid+" run="+runKey+" ts="+next);
            } catch (Throwable ignore) {}
            // Also register a fallback WM task (+2min)
            try {
                long delay = Math.max(0L, next - now) + 2L * 60L * 1000L;
                Data fbData = new Data.Builder()
                        // Provide both new and legacy keys for uid/runKey
                        .putString("uid", uid)
                        .putString("runKey", runKey)
                        .putString("task_uid", uid)
                        .putString("run_key", runKey)
                        .putString("chan", "fallback-wm")
                        .putInt("attempt", 1)
                        .build();
                WmScheduler.cancelByUid(ctx, uid);
                OneTimeWorkRequest fbReq = new OneTimeWorkRequest.Builder(FallbackWorker.class)
                        .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                        .addTag("fallback-wm").addTag(uid)
                        .setInputData(fbData)
                        .build();
                String fbUnique = WmNames.fbUnique(uid, runKey);
                WorkManager.getInstance(ctx.getApplicationContext())
                        .enqueueUniqueWork(fbUnique, ExistingWorkPolicy.REPLACE, fbReq);
                DbRepository.log(ctx, uid, "【原生】WM 自动续排兜底注册 uid="+uid+" run="+runKey+" delay="+delay);
            } catch (Throwable ignore) {}
        } else {
            // Without precise permission: schedule both main and fallback via WM
            try {
                WmScheduler.cancelByUid(ctx, uid);
                WmScheduler.schedulePair(ctx, next, uid, runKey);
                try { WmScheduler.scheduleKick(ctx, next, uid, runKey); } catch (Throwable ignore) {}
                DbRepository.log(ctx, uid, "【原生】WM 自动续排注册 uid="+uid+" run="+runKey+" ts="+next);
            } catch (Throwable ignore) {}
        }
    }
}