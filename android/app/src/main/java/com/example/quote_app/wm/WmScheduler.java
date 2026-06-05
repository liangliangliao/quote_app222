package com.example.quote_app.wm;

import android.content.Context;

import androidx.work.Data;
import androidx.work.ExistingWorkPolicy;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;

import java.util.concurrent.TimeUnit;
import com.example.quote_app.data.DbRepository;

public final class WmScheduler {
    private WmScheduler() {}

    public static void schedulePair(Context ctx, long triggerAt, String uid, String runKey) {
        long now = System.currentTimeMillis();
        long delay = Math.max(0L, triggerAt - now);
        long fbDelay = delay + 2 * 60 * 1000L; // +2min fallback

        WorkManager wm = WorkManager.getInstance(ctx.getApplicationContext());

        // Build input data for main-wm and fallback-wm tasks. Use descriptive channel names
        // Provide both legacy and new key names for uid/runKey to support Dart
        // side variations. Legacy keys: task_uid, run_key. New keys: uid, runKey.
        Data normal = new Data.Builder()
                .putString("uid", uid)
                .putString("runKey", runKey)
                .putString("task_uid", uid)
                .putString("run_key", runKey)
                .putString("chan", "main-wm")
                .putInt("attempt", 1)
                .build();

        Data fallback = new Data.Builder()
                .putString("uid", uid)
                .putString("runKey", runKey)
                .putString("task_uid", uid)
                .putString("run_key", runKey)
                .putString("chan", "fallback-wm")
                .putInt("attempt", 1)
                .build();

        OneTimeWorkRequest normalReq = new OneTimeWorkRequest.Builder(NormalWorker.class)
                .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                // use descriptive tags
                .addTag("main-wm").addTag(uid)
                .setInputData(normal)
                .build();

        OneTimeWorkRequest fbReq = new OneTimeWorkRequest.Builder(FallbackWorker.class)
                .setInitialDelay(fbDelay, TimeUnit.MILLISECONDS)
                .addTag("fallback-wm").addTag(uid)
                .setInputData(fallback)
                .build();

        DbRepository.log(ctx, uid, "【原生】WM 正常通道注册 uid="+uid+" run="+runKey+" ts="+triggerAt);
        wm.enqueueUniqueWork(WmNames.normUnique(uid, runKey), ExistingWorkPolicy.REPLACE, normalReq);
        DbRepository.log(ctx, uid, "【原生】WM 兜底通道注册 uid="+uid+" run="+runKey+" ts="+(triggerAt+120000));
        wm.enqueueUniqueWork(WmNames.fbUnique(uid, runKey), ExistingWorkPolicy.REPLACE, fbReq);
    }

    /**
     * Cancel a fallback-wm task by its unique identifier. Caller should provide the unique id returned
     * by {@link WmNames#fbUnique(String, String)}.
     */
    public static void cancelFallback(Context ctx, String uniqueId) {
        DbRepository.log(ctx, uniqueId == null ? "" : uniqueId, "【原生】WM 取消兜底 id="+uniqueId);
        if (uniqueId == null) return;
        WorkManager.getInstance(ctx.getApplicationContext())
                .cancelUniqueWork(uniqueId);
    }


    public static void cancelByUid(Context ctx, String uid) {
        try {
            DbRepository.log(ctx, uid, "【原生】WM 取消(按uid) uid="+uid);
            WorkManager.getInstance(ctx.getApplicationContext()).cancelAllWorkByTag(uid);
        } catch (Throwable ignore) {}
    }


    /** Cancel by exact unique work name (身份证完整字符串). */
    public static void cancelByUnique(Context ctx, String unique) {
        if (unique == null) return;
        try { DbRepository.log(ctx, unique, "【原生】WM 取消(按unique) unique="+unique); } catch (Throwable ignore) {}
        try { WorkManager.getInstance(ctx.getApplicationContext()).cancelUniqueWork(unique); } catch (Throwable ignore) {}
    }

    /** Schedule a non-exact 'kick' AlarmManager broadcast to wake app near triggerAt. */
    public static void scheduleKick(Context ctx, long triggerAt, String uid, String runKey) {
        try { DbRepository.log(ctx, uid, "【原生】KICK 注册 uid="+uid+" run="+runKey+" ts="+triggerAt); } catch (Throwable ignore) {}
        android.app.AlarmManager am = (android.app.AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        android.content.Intent it = new android.content.Intent(ctx, com.example.quote_app.am.KickAlarmReceiver.class)
                .setAction(com.example.quote_app.am.KickAlarmReceiver.ACTION_KICK)
                .putExtra(com.example.quote_app.am.KickAlarmReceiver.EXTRA_UID, uid)
                .putExtra(com.example.quote_app.am.KickAlarmReceiver.EXTRA_RUNKEY, runKey);
        int req = com.example.quote_app.compat.DartParity.alarmId(uid, runKey + "|kick");
        int flags = android.os.Build.VERSION.SDK_INT >= 23
                ? android.app.PendingIntent.FLAG_UPDATE_CURRENT | android.app.PendingIntent.FLAG_IMMUTABLE
                : android.app.PendingIntent.FLAG_UPDATE_CURRENT;
        android.app.PendingIntent pi = android.app.PendingIntent.getBroadcast(ctx, req, it, flags);
        long window = 90_000L; // 1.5 min window
        try {
            am.setWindow(android.app.AlarmManager.RTC_WAKEUP, triggerAt, window, pi);
        } catch (Throwable e) {
            am.set(android.app.AlarmManager.RTC_WAKEUP, triggerAt, pi);
        }
    }

    /** Cancel the 'kick' alarm for a specific uid+runKey. */
    public static void cancelKick(Context ctx, String uid, String runKey) {
        android.app.AlarmManager am = (android.app.AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        android.content.Intent it = new android.content.Intent(ctx, com.example.quote_app.am.KickAlarmReceiver.class)
                .setAction(com.example.quote_app.am.KickAlarmReceiver.ACTION_KICK)
                .putExtra(com.example.quote_app.am.KickAlarmReceiver.EXTRA_UID, uid)
                .putExtra(com.example.quote_app.am.KickAlarmReceiver.EXTRA_RUNKEY, runKey);
        int req = com.example.quote_app.compat.DartParity.alarmId(uid, runKey + "|kick");
        int flags = android.os.Build.VERSION.SDK_INT >= 23
                ? android.app.PendingIntent.FLAG_UPDATE_CURRENT | android.app.PendingIntent.FLAG_IMMUTABLE
                : android.app.PendingIntent.FLAG_UPDATE_CURRENT;
        android.app.PendingIntent pi = android.app.PendingIntent.getBroadcast(ctx, req, it, flags);
        try { am.cancel(pi); } catch (Throwable ignore) {}
        try { com.example.quote_app.data.DbRepository.log(ctx, uid, "【原生】KICK 取消 uid="+uid+" runKey="+runKey); } catch (Throwable ignore) {}
    }

}
