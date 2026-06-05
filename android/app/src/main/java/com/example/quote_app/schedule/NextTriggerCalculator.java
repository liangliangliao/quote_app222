package com.example.quote_app.schedule;

import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.text.TextUtils;

import com.example.quote_app.data.DbInspector;
import com.example.quote_app.data.DbRepository;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/**
 * Native mirror for Dart scheduling (common branch).
 * 1) prefer tasks.next_time (ISO) if in the future
 * 2) else parse tasks.start_time/trigger_at as HH:mm -> today or tomorrow
 */
public final class NextTriggerCalculator {
    private NextTriggerCalculator() {}

    public static long compute(Context ctx, String uid) {
        long now = System.currentTimeMillis();
        DbInspector.Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null || TextUtils.isEmpty(cc.dbPath)) {
            return now + 24L*60*60*1000;
        }
        SQLiteDatabase db = null;
        try {
            db = SQLiteDatabase.openDatabase(cc.dbPath, null, SQLiteDatabase.OPEN_READONLY);
            String table = TextUtils.isEmpty(cc.tasksSource) ? "tasks" : cc.tasksSource;
            String uidCol = cc.taskColMap.containsKey("uid") ? cc.taskColMap.get("uid") : "task_uid";
            String nextCol = cc.taskColMap.containsKey("next_time") ? cc.taskColMap.get("next_time") : "next_time";
            String startCol = cc.taskColMap.containsKey("trigger_at") ? cc.taskColMap.get("trigger_at") : "start_time";

            Cursor c = db.rawQuery("SELECT "+nextCol+","+startCol+" FROM "+table+" WHERE "+uidCol+"=? LIMIT 1", new String[]{uid});
            String nextIso = null; String startVal = null;
            if (c.moveToFirst()) {
                nextIso = safeGet(c,0);
                startVal = safeGet(c,1);
            }
            c.close();

            long ts = parseIso(nextIso);
            if (ts > now + 10_000L) return ts; // 10s grace

            int[] hm = parseHHmm(startVal);
            Calendar cal = Calendar.getInstance();
            cal.set(Calendar.SECOND, 0);
            cal.set(Calendar.MILLISECOND, 0);
            cal.set(Calendar.HOUR_OF_DAY, hm[0]);
            cal.set(Calendar.MINUTE, hm[1]);
            long cand = cal.getTimeInMillis();
            if (cand > now + 10_000L) return cand;
            cal.add(Calendar.DAY_OF_YEAR, 1);
            return cal.getTimeInMillis();
        } catch (Throwable e) {
            try { DbRepository.log(ctx, uid, "NextTriggerCalculator error: "+e.getMessage()); } catch (Throwable ignore) {}
            return now + 24L*60*60*1000;
        } finally {
            if (db != null) try { db.close(); } catch (Throwable ignore) {}
        }
    }

    private static String safeGet(Cursor c, int idx) { try { return c.isNull(idx) ? null : c.getString(idx); } catch (Throwable t) { return null; } }

    private static long parseIso(String s) {
        if (TextUtils.isEmpty(s)) return -1L;
        String[] fmts = new String[] {
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss"
        };
        for (String f : fmts) {
            try {
                SimpleDateFormat sdf = new SimpleDateFormat(f, Locale.US);
                sdf.setTimeZone(TimeZone.getDefault());
                Date d = sdf.parse(s);
                if (d != null) return d.getTime();
            } catch (ParseException ignore) {}
        }
        return -1L;
    }

    private static int[] parseHHmm(String v) {
        int h = 9, m = 0;
        if (!TextUtils.isEmpty(v)) {
            java.util.regex.Matcher m1 = java.util.regex.Pattern.compile("(\\d{1,2}):(\\d{2})").matcher(v);
            if (m1.find()) {
                try { h = Integer.parseInt(m1.group(1)); } catch (Throwable ignore) {}
                try { m = Integer.parseInt(m1.group(2)); } catch (Throwable ignore) {}
            }
        }
        if (h < 0 || h > 23) h = 9;
        if (m < 0 || m > 59) m = 0;
        return new int[]{h, m};
    }
}
