package com.example.quote_app.compat;

import android.content.Context;
import android.text.TextUtils;

import com.example.quote_app.NativeSchedulerK;
import com.example.quote_app.data.DbRepository;
import com.example.quote_app.wm.WmScheduler;

import org.json.JSONObject;

public final class DartParity {
    private DartParity() {}

    public static int alarmId(String uid, String runKey) {
        // Stable cross‑platform 32‑bit FNV‑1a over UTF‑8 of "uid|runKey"
        final int FNV_PRIME = 16777619;
        long h = 2166136261L;
        byte[] bs;
        try { bs = (uid + "|" + runKey).getBytes("UTF-8"); } catch (Throwable ignore) { bs = (uid + "|" + runKey).getBytes(); }
        for (int i = 0; i < bs.length; i++) {
            h ^= (bs[i] & 0xff);
            h = (h * FNV_PRIME) & 0xffffffffL;
        }
        return (int)(h & 0x7fffffffL);
    }

    public static boolean canScheduleExact(Context ctx) {
        try { return com.example.quote_app.ExactAlarmHelper.INSTANCE.hasExactAlarmPermission(ctx); }
        catch (Throwable ignore) { return true; }
    }

    public static boolean requestExactPermission(Context ctx) { return true; }

    public static boolean scheduleExactAt(Context ctx, long epochMs, String uid, String runKey, String payloadJson) {
        if (epochMs <= 0L || TextUtils.isEmpty(uid)) return false;
        final int id = alarmId(uid, runKey);
        String payload;
        try {
            if (TextUtils.isEmpty(payloadJson)) {
                payload = new JSONObject().put("uid", uid).put("runKey", runKey).put("chan","am").toString();
            } else {
                payload = payloadJson;
            }
        } catch (Throwable e) {
            payload = "{\"uid\":\""+uid+"\",\"runKey\":\""+(runKey==null?"":runKey)+"\",\"chan\":\"am\"}";
        }
        boolean ok = false;
        try { ok = NativeSchedulerK.scheduleExactWmCompat(ctx, id, epochMs, payload); } catch (Throwable ignore) {}
        try { DbRepository.setScheduledRunKey(ctx, uid, TextUtils.isEmpty(runKey) ? String.valueOf(epochMs) : runKey); } catch (Throwable ignore) {}
        try { WmScheduler.schedulePair(ctx, epochMs, uid, runKey); } catch (Throwable ignore) {}
        return ok;
    }

    public static void cancel(Context ctx, String uid, String runKey) {
        int id = alarmId(uid, runKey);
        try { NativeSchedulerK.cancel(ctx, id); } catch (Throwable ignore) {}
    }

    public static void cancelAll(Context ctx) {
        try { NativeSchedulerK.cancelAll(ctx); } catch (Throwable ignore) {}
    }

    public static boolean alreadySent(Context ctx, String uid, String runKey, String chan, int attempt) {
        try { return DbRepository.alreadySent(ctx, uid, runKey, chan, attempt); }
        catch (Throwable ignore) { return false; }
    }

    public static void markAlreadySent(Context ctx, String uid, String runKey, String chan, int attempt) {
        try { DbRepository.markAlreadySent(ctx, uid, runKey, chan, attempt); } catch (Throwable ignore) {}
    }
}
