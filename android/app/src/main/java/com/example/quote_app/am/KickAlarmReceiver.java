package com.example.quote_app.am;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.example.quote_app.biz.Biz;
import com.example.quote_app.data.DbRepository;
import com.example.quote_app.schedule.AutoRescheduler;
import com.example.quote_app.wm.WmNames;
import com.example.quote_app.wm.WmScheduler;

public class KickAlarmReceiver extends BroadcastReceiver {
    private static final String TAG_LOG = "KickAlarmReceiver";
    public static final String ACTION_KICK = "com.example.quote_app.action.KICK_ALARM";
    public static final String EXTRA_UID = "uid";
    public static final String EXTRA_RUNKEY = "runKey";

    @Override public void onReceive(Context ctx, Intent it) {
        String uid = it.getStringExtra(EXTRA_UID);
        String runKey = it.getStringExtra(EXTRA_RUNKEY);
        if (uid == null || runKey == null) return;
        try { DbRepository.log(ctx, uid, "【原生】KICK 触发 uid="+uid+" run="+runKey); } catch (Throwable ignore) {}

        boolean entered = false;
        try { entered = DbRepository.runGuardBegin(ctx, uid, runKey, "kick-am"); } catch (Throwable ignore) {}
        if (!entered) {
            try { DbRepository.log(ctx, uid, "【原生】KICK 拦截 uid="+uid+" run="+runKey); } catch (Throwable ignore) {}
            return;
        }

        boolean ok = false;
        try { ok = Biz.run(ctx, uid); } catch (Throwable ignore) {}
        try { DbRepository.log(ctx, uid, "【原生】KICK 业务ok="+(ok?1:0)); } catch (Throwable ignore) {}

        // cursor +1 & quote status/time
        try { android.util.Log.d(TAG_LOG, "before rotateCursorByTaskType");
        DbRepository.rotateCursorByTaskType(ctx, uid); } catch (Throwable ignore) {}
        try { android.util.Log.d(TAG_LOG, "before updateQuoteNotify");
        DbRepository.updateQuoteNotify(ctx, uid, ok, System.currentTimeMillis()); } catch (Throwable ignore) {}

        try {
            if (ok) {
                try { DbRepository.markLatestSuccess(ctx, uid); } catch (Throwable ignore) {}
                // 取消同轮 WM（normal + fallback）
                try {
                    String nUnique = WmNames.normUnique(uid, runKey);
                    String fUnique = WmNames.fbUnique(uid, runKey);
                    WmScheduler.cancelByUnique(ctx, nUnique);
                    WmScheduler.cancelFallback(ctx, fUnique);
                } catch (Throwable ignore) {}
                // 续排下一次
                try { AutoRescheduler.scheduleNext(ctx, uid); } catch (Throwable ignore) {}
            }
        } finally {
            try { DbRepository.runGuardEnd(ctx, uid, runKey, "kick-am"); } catch (Throwable ignore) {}
        }
    }
}
