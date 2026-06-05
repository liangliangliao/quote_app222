package com.example.quote_app.am;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import com.example.quote_app.compat.DartParity;
import com.example.quote_app.data.DbRepository;

public final class AmCancel {
    private AmCancel() {}

    public static boolean cancelExactById(Context ctx, String uid, String runKey) {
        DbRepository.log(ctx, uid==null?"":uid, "【原生】AM 取消请求 uid="+(uid==null?"":uid)+" run="+String.valueOf(runKey));
        try {
            int id = DartParity.alarmId(uid, runKey);
            AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return false;

            // 尝试多种 action 以最大兼容性
            String[] actions = new String[] {
                    null,
                    "com.example.quote_app.AM",
                    "am_alarm",
                    "com.example.quote_app/AM"
            };
            boolean cancelled = false;
            for (String action : actions) {
                Intent i = new Intent(ctx, AlarmReceiver.class);
                if (action != null) i.setAction(action);
                int flags = PendingIntent.FLAG_NO_CREATE | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
                PendingIntent pi = PendingIntent.getBroadcast(ctx, id, i, flags);
                if (pi != null) {
                    am.cancel(pi);
                    pi.cancel();
                    cancelled = true;
                }
            }
            DbRepository.log(ctx, uid==null?"":uid, "【原生】AM 取消完成 uid="+(uid==null?"":uid)+" run="+String.valueOf(runKey)+" ok="+cancelled);
            return cancelled;
        } catch (Throwable t) {
            return false;
        }
    }
}
