package com.example.quote_app.data;

import android.util.Log;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.text.TextUtils;

import com.example.quote_app.data.DbInspector.Contract;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Thin repository with defensive defaults; only APIs used by Biz/Receivers are implemented. */
public final class DbRepository {

    /**
     * Guard to prevent recursive calls to {@link #log(Context, String, String)} on the
     * same thread. If {@link #log(Context, String, String)} is invoked while already
     * executing on the current thread, the nested invocation will write only to the
     * Android system log rather than re-entering the database again. Using a
     * ThreadLocal ensures that calls on different threads are isolated.
     */
    private static final ThreadLocal<Boolean> LOG_GUARD = new ThreadLocal<Boolean>() {
        @Override protected Boolean initialValue() { return Boolean.FALSE; }
    };


    public static final class Task {
        public String uid;
        public String title;
        public String content;
        public long triggerAtMillis;
        public boolean enabled = true;
        public String type; // AUTO / MANUAL / CAROUSEL
        public String avatarPath;
    }

    public static final class Config {
        public String modelName;
        public String apiKey;
        public String baseUrl;
    }

    private static SQLiteDatabase openByPath(String path) {
        try { return SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE); }
        catch (Throwable e) { Log.e("DbRepository", "error", e);  return null; }
    }

    private static String or(String v, String d) { return TextUtils.isEmpty(v) ? d : v; }

    // -------- 日志 --------
    // -------- 日志 --------
    /**
     * Insert a log entry into the app's logs table. This method protects against
     * recursive invocation – if a call to {@link #log(Context, String, String)}
     * triggers another call (for example, via DbInspector.loadOrLightScan() which
     * itself may attempt to log), the nested call will short‑circuit to avoid a
     * stack overflow and ANR. Nested attempts fall back to a simple Android
     * system log entry instead of touching the database again.
     */
    public static void log(Context ctx, String uid, String detail) {
        // Use a ThreadLocal guard to detect re‑entrant calls on the same thread.
        Boolean inProgress = LOG_GUARD.get();
        if (inProgress != null && inProgress) {
            // Already logging on this thread – avoid re‑entering DbInspector / DB.
            try {
                Log.i("DbRepository", "[native log-only] uid=" + uid + ", detail=" + detail);
            } catch (Throwable ignore) {
            }
            return;
        }
        LOG_GUARD.set(Boolean.TRUE);
        try {
            Contract cc = DbInspector.loadOrLightScan(ctx);
            if (cc == null || TextUtils.isEmpty(cc.logsSource)) return;
            SQLiteDatabase db = openOrCreateFallback(ctx, cc);
            if (db == null) return;
            try {
                Map<String,String> m = cc.logColMap;
                ContentValues cv = new ContentValues();
                cv.put(or(m.get("uid"), "uid"), uid);
                cv.put(or(m.get("detail"), "detail"), detail);
                db.insert(cc.logsSource, null, cv);
            } catch (Throwable e) {
                Log.e("DbRepository", "error", e);
            } finally {
                try { db.close(); } catch (Throwable e) { Log.e("DbRepository", "error", e); }
            }
        } finally {
            // Clear the flag to allow future log calls on this thread.
            LOG_GUARD.set(Boolean.FALSE);
        }
    }

    // -------- run_guard 幂等 --------
    private static void ensureRunGuard(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE IF NOT EXISTS run_guard(uid TEXT, run_key TEXT, ts INTEGER, src TEXT, PRIMARY KEY(uid,run_key))");
    }

    public static boolean runGuardBegin(Context ctx, String uid, String runKey, String source) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null) return true;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return true;
        try {
            ensureRunGuard(db);
            Cursor c = db.rawQuery("SELECT 1 FROM run_guard WHERE uid=? AND run_key=?", new String[]{uid, runKey});
            boolean exists = c.moveToFirst();
            c.close();
            if (exists) return false;
            ContentValues cv = new ContentValues();
            cv.put("uid", uid);
            cv.put("run_key", runKey);
            cv.put("ts", System.currentTimeMillis());
            cv.put("src", source);
            db.insertWithOnConflict("run_guard", null, cv, SQLiteDatabase.CONFLICT_REPLACE);
            log(ctx, uid, "begin uid="+uid+" runKey="+runKey+" src="+(source==null?"":source));
            return true;
        } catch (Throwable e) { Log.e("DbRepository", "error", e); 
            log(ctx, uid, "begin error uid="+uid+" runKey="+runKey+" err="+e.getMessage());
            return true;
        } finally { try { db.close(); } catch (Throwable e) { Log.e("DbRepository", "error", e); } }
    }

    public static void runGuardEnd(Context ctx, String uid, String runKey, String source) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null) return;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return;
        try {
            ensureRunGuard(db);
            db.delete("run_guard", "uid=? AND run_key=?", new String[]{uid, runKey});
            log(ctx, uid, "end uid="+uid+" runKey="+runKey+" src="+(source==null?"":source));
        } catch (Throwable e) { Log.e("DbRepository", "error", e); 
            log(ctx, uid, "end error uid="+uid+" runKey="+runKey+" err="+e.getMessage());
        } finally { try { db.close(); } catch (Throwable e) { Log.e("DbRepository", "error", e); } }
    }

    public static void markLatestSuccess(Context ctx, String uid) {
        log(ctx, uid, "成功!");
    }

    // -------- sent_guard 幂等（Dart 同步语义） --------
    private static void ensureSentGuard(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE IF NOT EXISTS sent_guard(uid TEXT, run_key TEXT, chan TEXT, attempt INTEGER, ts INTEGER, PRIMARY KEY(uid,run_key,chan,attempt))");
    }

    public static boolean alreadySent(Context ctx, String uid, String runKey, String chan, int attempt) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null) return false;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return false;
        try {
            ensureSentGuard(db);
            Cursor c = db.rawQuery("SELECT 1 FROM sent_guard WHERE uid=? AND run_key=? AND chan=? AND attempt=?", new String[]{uid, runKey, chan, String.valueOf(attempt)});
            boolean exists = c.moveToFirst();
            c.close();
            return exists;
        } catch (Throwable e) { Log.e("DbRepository", "error", e); 
            return false;
        } finally { try { db.close(); } catch (Throwable e) { Log.e("DbRepository", "error", e); } }
    }

    public static void markAlreadySent(Context ctx, String uid, String runKey, String chan, int attempt) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null) return;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return;
        try {
            ensureSentGuard(db);
            ContentValues cv = new ContentValues();
            cv.put("uid", uid);
            cv.put("run_key", runKey);
            cv.put("chan", chan);
            cv.put("attempt", attempt);
            cv.put("ts", System.currentTimeMillis());
            db.insertWithOnConflict("sent_guard", null, cv, SQLiteDatabase.CONFLICT_REPLACE);
            log(ctx, uid, "已发送标记: chan="+chan+" attempt="+attempt+" runKey="+runKey);
        } catch (Throwable e) { Log.e("DbRepository", "error", e); 
        } finally { try { db.close(); } catch (Throwable e) { Log.e("DbRepository", "error", e); } }
    }

    // 调试记录：最近一次注册用的 runKey
    public static void setScheduledRunKey(Context ctx, String uid, String runKey) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null) return;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return;
        try {
            db.execSQL("CREATE TABLE IF NOT EXISTS scheduled_key(uid TEXT PRIMARY KEY, run_key TEXT, ts INTEGER)");
            ContentValues cv = new ContentValues();
            cv.put("uid", uid);
            cv.put("run_key", runKey);
            cv.put("ts", System.currentTimeMillis());
            db.insertWithOnConflict("scheduled_key", null, cv, SQLiteDatabase.CONFLICT_REPLACE);
        } catch (Throwable e) { Log.e("DbRepository", "error", e); 
        } finally { try { db.close(); } catch (Throwable e) { Log.e("DbRepository", "error", e); } }
    
        // Best-effort: also sync tasks table's scheduled_run_key & next_time for latest schedule
        try {
            com.example.quote_app.data.DbInspector.Contract cc2 = com.example.quote_app.data.DbInspector.loadOrLightScan(ctx);
            if (cc2 != null) {
                android.database.sqlite.SQLiteDatabase db2 = openOrCreateFallback(ctx, cc2);
                if (db2 != null) {
                    String table = android.text.TextUtils.isEmpty(cc2.tasksSource) ? "tasks" : cc2.tasksSource;
                    String uidCol = cc2.taskColMap.containsKey("uid") ? cc2.taskColMap.get("uid") : "task_uid";
                    String rkCol  = cc2.taskColMap.containsKey("scheduled_run_key") ? cc2.taskColMap.get("scheduled_run_key") : "scheduled_run_key";
                    String nextCol= cc2.taskColMap.containsKey("next_time") ? cc2.taskColMap.get("next_time") : "next_time";
                    android.content.ContentValues cv2 = new android.content.ContentValues();
                    cv2.put(rkCol, runKey);
                    String nextIso = null;
                    try {
                        if (runKey != null) {
                            if (runKey.startsWith("ts_")) {
                                long ms = Long.parseLong(runKey.substring(3));
                                java.text.SimpleDateFormat iso = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US);
                                nextIso = iso.format(new java.util.Date(ms));
                            } else {
                                java.text.SimpleDateFormat fmt = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US);
                                java.util.Date d = fmt.parse(runKey);
                                if (d != null) {
                                    java.text.SimpleDateFormat iso = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US);
                                    nextIso = iso.format(d);
                                }
                            }
                        }
                    } catch (Throwable ignore) {}
                    if (nextIso != null) { cv2.put(nextCol, nextIso); }
                    try { db2.update(table, cv2, uidCol + "=?", new String[]{ uid }); } catch (Throwable ignore) {}
                    try { db2.close(); } catch (Throwable ignore) {}
                }
            }
        } catch (Throwable ignore) {}
}

    // -------- 名人名言与任务（最小实现） --------
    public static long insertQuote(Context ctx, String taskUid, String text, String avatarPath) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null || TextUtils.isEmpty(cc.quotesSource)) return -1L;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return -1L;
        try {
            Map<String,String> m = cc.quoteColMap;
            ContentValues cv = new ContentValues();
            cv.put(or(m.get("task_uid"), "task_uid"), taskUid);
            cv.put(or(m.get("content"), "content"), text);
            cv.put(or(m.get("avatar"), "avatar"), avatarPath);
            cv.put(or(m.get("notified"), "notified"), 0);
            return db.insert(cc.quotesSource, null, cv);
        } catch (Throwable e) { Log.e("DbRepository", "error", e); 
            log(ctx, taskUid, "insert quote error: "+e.getMessage());
            return -1L;
        } finally { try { db.close(); } catch (Throwable e) { Log.e("DbRepository", "error", e); } }
    }

    public static void markQuoteNotified(Context ctx, long quoteId) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null || TextUtils.isEmpty(cc.quotesSource)) return;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return;
        try {
            Map<String,String> m = cc.quoteColMap;
            ContentValues cv = new ContentValues();
            cv.put(or(m.get("notified"), "notified"), 1);
            db.update(cc.quotesSource, cv, "rowid=?", new String[]{String.valueOf(quoteId)});
        } catch (Throwable e) { Log.e("DbRepository", "error", e); 
        } finally { try { db.close(); } catch (Throwable e) { Log.e("DbRepository", "error", e); } }
    }

    public static String getCarouselNextQuote(Context ctx, String taskUid) {
        List<String> list = listQuoteTextsForTask(ctx, taskUid, 1);
        return list.isEmpty() ? null : list.get(0);
    }

    public static List<String> listQuoteTextsForTask(Context ctx, String taskUid, int limit) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        List<String> out = new ArrayList<>();
        if (cc == null || TextUtils.isEmpty(cc.quotesSource)) return out;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return out;
        try {
            Map<String,String> m = cc.quoteColMap;
            String table = cc.quotesSource;
            String textCol = or(m.get("content"), "content");
            String taskCol = or(m.get("task_uid"), "task_uid");
            String sql;
            String[] args;
            if (TextUtils.isEmpty(taskUid)) {
                sql = "SELECT " + textCol + " FROM " + table + " ORDER BY rowid DESC LIMIT ?";
                args = new String[]{String.valueOf(limit)};
            } else {
                sql = "SELECT " + textCol + " FROM " + table + " WHERE " + taskCol + "=? ORDER BY rowid DESC LIMIT ?";
                args = new String[]{taskUid, String.valueOf(limit)};
            }
            Cursor c = db.rawQuery(sql, args);
            while (c.moveToNext()) out.add(c.getString(0));
            c.close();
        } catch (Throwable e) { Log.e("DbRepository", "error", e); 
        } finally { try { db.close(); } catch (Throwable e) { Log.e("DbRepository", "error", e); } }
        return out;
    }

    public static Task getTaskByUid(Context ctx, String uid) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null || TextUtils.isEmpty(cc.tasksSource)) return null;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return null;
        try {
            Map<String,String> m = cc.taskColMap;
            String table = cc.tasksSource;
            String uidCol = or(m.get("uid"), "uid");
            String titleCol = or(m.get("title"), "title");
            String contentCol = or(m.get("content"), "content");
            String typeCol = or(m.get("type"), "type");
            String avatarCol = or(m.get("avatar"), "avatar");
            String enableCol = or(m.get("enabled"), "enabled");
            String triggerCol = or(m.get("trigger_at"), "trigger_at");
            Cursor c = db.rawQuery("SELECT "+uidCol+","+titleCol+","+contentCol+","+typeCol+","+avatarCol+","+enableCol+","+triggerCol+" FROM "+table+" WHERE "+uidCol+"=? LIMIT 1", new String[]{uid});
            if (c.moveToFirst()) {
                Task t = new Task();
                t.uid = c.getString(0);
                t.title = c.getString(1);
                t.content = c.getString(2);
                t.type = c.getString(3);
                t.avatarPath = c.getString(4);
                String ev = c.getString(5);
                t.enabled = !( "0".equals(ev) || "off".equalsIgnoreCase(ev) );
t.triggerAtMillis = c.getLong(6);
                c.close();
                return t;
            }
            c.close();
            return null;
        } catch (Throwable e) { Log.e("DbRepository", "error", e); 
            return null;
        } finally { try { db.close(); } catch (Throwable e) { Log.e("DbRepository", "error", e); } }
    }
    /** 选取将要发送的名人名言（标题/正文/头像），按任务类型与游标规则：
      * 批量导入/自动：限定 task_uid；降序 + OFFSET cursor；预发送前做范围校验；超界则写日志并返回 null
      * 轮播：全表；降序 + OFFSET cursor；范围校验
      * 手动：限定 task_uid；只取 1 条
      */
    
    // 将本地文件路径转换为可在 WebView/HTML 中直接显示的 data URI（避免 file:/// 权限问题）
    private static String toWebDataUri(String path) {
        try {
            if (path == null) return null;
            java.io.File f = new java.io.File(path.replace("file://", ""));
            if (!f.exists() || f.length() <= 0) return path;
            java.io.FileInputStream in = new java.io.FileInputStream(f);
            byte[] buf = new byte[(int)Math.min(f.length(), 512*1024)]; // 限制 512KB，避免过大
            int n = in.read(buf); in.close();
            if (n <= 0) return path;
            String b64 = android.util.Base64.encodeToString(java.util.Arrays.copyOf(buf, n), android.util.Base64.NO_WRAP);
            // 粗略按扩展名判断 mime
            String mime = path.endsWith(".png") ? "image/png" : "image/jpeg";
            return "data:"+mime+";base64,"+b64;
        } catch (Throwable e) { return path; }
    }
public static String[] selectQuoteForNotify(Context ctx, String uid) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null) return null;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return null;
        try {
            String quotes = TextUtils.isEmpty(cc.quotesSource) ? "quotes" : cc.quotesSource;
            String tasks = TextUtils.isEmpty(cc.tasksSource) ? "tasks" : cc.tasksSource;
            String qTask = cc.quoteColMap.containsKey("uid") ? cc.quoteColMap.get("uid") : "task_uid";
java.util.Set<String> _cols = DbInspector.listColumns(db, quotes);
String qTitle = _cols.contains("theme") ? "theme" : (_cols.contains("title") ? "title" : (_cols.contains("author_name") ? "author_name" : null));
String qText  = _cols.contains("content") ? "content" : (_cols.contains("text") ? "text" : "content");
String qAvatar= _cols.contains("avatar") ? "avatar" : (_cols.contains("avatar_path") ? "avatar_path" : "avatar");
            String tType = cc.taskColMap.containsKey("type") ? cc.taskColMap.get("type") : "type";
            String tCur  = cc.taskColMap.containsKey("cursor") ? cc.taskColMap.get("cursor") : "cursor";
            String tOrder = cc.taskColMap.containsKey("carousel_order") ? cc.taskColMap.get("carousel_order") : "carousel_order";

            String type = "";
            int cursor = 0;
            String orderVal = null;
            // read type, cursor and carousel_order (if present) from tasks table
            try (Cursor c = db.query(tasks, new String[]{tType, tCur, tOrder}, "task_uid=?", new String[]{uid}, null, null, null)) {
                if (c != null && c.moveToFirst()) {
                    type = c.getString(0);
                    // handle possible null cursor values gracefully
                    if (!c.isNull(1)) cursor = c.getInt(1);
                    if (!c.isNull(2)) orderVal = c.getString(2);
                }
            }

            int total = 0;
            boolean scopedByTask = false;
            // Determine quote scope and total rows depending on task type
            if ("批量导入任务".equals(type) || "自动任务".equals(type) || "AUTO".equalsIgnoreCase(type)) {
                // batch import and auto tasks are scoped by task uid
                scopedByTask = true;
                try (Cursor c = db.rawQuery("SELECT COUNT(*) FROM "+quotes+" WHERE "+qTask+"=?", new String[]{uid})) {
                    if (c.moveToFirst()) total = c.getInt(0);
                }
            } else if ("carousel".equalsIgnoreCase(type) || "轮播".equals(type) || "轮播任务".equals(type)) {
                // carousel tasks read across entire quotes table
                scopedByTask = false;
                try (Cursor c = db.rawQuery("SELECT COUNT(*) FROM "+quotes, null)) {
                    if (c.moveToFirst()) total = c.getInt(0);
                }
            } else if ("手动任务".equals(type) || "MANUAL".equalsIgnoreCase(type) || "手动".equals(type)) {
                // manual tasks: pick the latest (descending) quote for this task
                String _tCol = (qTitle!=null ? qTitle : "'提醒'");
                String sql = "SELECT "+_tCol+","+qText+","+qAvatar+" FROM "+quotes+" WHERE "+qTask+"=? ORDER BY rowid DESC LIMIT 1";
                try (Cursor c = db.rawQuery(sql, new String[]{uid})) {
                    if (c.moveToFirst()) {
                        return new String[]{c.isNull(0)?null:c.getString(0), c.isNull(1)?null:c.getString(1), c.isNull(2)?null:c.getString(2)};
                    }
                }
                return null;
            }

            // Determine ordering for carousel tasks
            // Default order is descending
            String effectiveOrder = "DESC";
            boolean isCarousel = "carousel".equalsIgnoreCase(type) || "轮播".equals(type) || "轮播任务".equals(type);
            if (isCarousel) {
                String orderLower = (orderVal == null ? "" : orderVal.trim().toLowerCase(java.util.Locale.US));
                if ("asc".equals(orderLower) || "升序".equals(orderLower)) {
                    effectiveOrder = "ASC";
                } else if ("random".equals(orderLower) || "随机".equals(orderLower)) {
                    effectiveOrder = "DESC"; // random selection still uses descending order
                    // For random: generate random cursor and update tasks table
                    if (total > 0) {
                        try {
                            int randomIndex = new java.util.Random().nextInt(total);
                            cursor = randomIndex;
                            // update tasks table cursor to randomIndex
                            android.content.ContentValues cv = new android.content.ContentValues();
                            cv.put(tCur, randomIndex);
                            // update only if column exists
                            try { db.update(tasks, cv, (cc.taskColMap.containsKey("uid") ? cc.taskColMap.get("uid") : "task_uid") + "=?", new String[]{ uid }); } catch (Throwable ignore) {}
                        } catch (Throwable ignore) {
                            // fallback: keep current cursor
                        }
                    }
                } else {
                    effectiveOrder = "DESC";
                }
            }

            // After potential random adjustment, validate cursor range
            if (total <= 0 || cursor > (total - 1)) {
                try {
                    if ("批量导入任务".equals(type) || "自动任务".equals(type) || "AUTO".equalsIgnoreCase(type)) {
                        log(ctx, uid, "错误!批量导入任务找不到名人名言!");
                    } else if (isCarousel) {
                        log(ctx, uid, "错误!轮播任务找不到名人名言!");
                    }
                } catch (Throwable ignore) {}
                return null;
            }

            // Build SQL to select title, text, avatar at current cursor using effectiveOrder
            String orderBy = "rowid " + effectiveOrder;
            String sql;
            String[] args;
            if (scopedByTask) {
                sql = "SELECT "+qTitle+","+qText+","+qAvatar+" FROM "+quotes+" WHERE "+qTask+"=? ORDER BY "+orderBy+" LIMIT 1 OFFSET "+cursor;
                args = new String[]{uid};
            } else {
                sql = "SELECT "+qTitle+","+qText+","+qAvatar+" FROM "+quotes+" ORDER BY "+orderBy+" LIMIT 1 OFFSET "+cursor;
                args = null;
            }
            try (Cursor c = args != null ? db.rawQuery(sql, args) : db.rawQuery(sql, null)) {
                if (c.moveToFirst()) {
                    return new String[]{c.isNull(0)?null:c.getString(0), c.isNull(1)?null:c.getString(1), c.isNull(2)?null:c.getString(2)};
                }
            }
            return null;
        } catch (Throwable e) {
            Log.e("DbRepository","selectQuoteForNotify error", e);
            return null;
        } finally { try { db.close(); } catch (Throwable ignore) {} }
    }

    private static SQLiteDatabase openOrRescan(Context ctx, Contract cc) {
        SQLiteDatabase db = openByPath(cc.dbPath);
        if (db != null) return db;
        try {
            Contract cc2 = DbInspector.loadOrLightScan(ctx);
            if (cc2 != null && !TextUtils.isEmpty(cc2.dbPath)) {
                SQLiteDatabase db2 = openByPath(cc2.dbPath);
                if (db2 != null) return db2;
            }
        } catch (Throwable e) { Log.e("DbRepository", "rescan error", e); }
        return null;
    }


// Fallback open: if path invalid or db missing, create app.db at internal databases dir.
    private static SQLiteDatabase openOrCreateFallback(Context ctx, Contract cc) {
        try {
            String path = (cc != null && !TextUtils.isEmpty(cc.dbPath)) ? cc.dbPath : null;
            SQLiteDatabase db = null;
            if (path != null) {
                try {
                    android.util.Log.i("DbRepository", "trying open db path=" + path);
                    db = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE);
                    android.util.Log.i("DbRepository", "opened db path=" + path);
                } catch (Throwable ignore) {
                    android.util.Log.w("DbRepository", "open by path failed", ignore);
                }
            }
            if (db == null) {
                String fallbackPath = ctx.getDatabasePath("app.db").getAbsolutePath();
                android.util.Log.i("DbRepository", "using fallback db path=" + fallbackPath);
                db = SQLiteDatabase.openOrCreateDatabase(fallbackPath, null);
                android.util.Log.i("DbRepository", "opened fallback db path=" + fallbackPath);
            }
            // Ensure that the logs table always exists before we insert into it.
            // Some devices may have been running an older schema without a `logs` table.
            // If missing, any call to DbRepository.log() will fail and break subsequent DB operations.
            // Here we defensively create a basic logs table if it doesn't already exist.  The table
            // structure is compatible with the Flutter-side logs table; additional columns are allowed.
            try {
                // Determine the logs table name from the contract; default to "logs" if empty.
                String logsTable = (cc != null && !TextUtils.isEmpty(cc.logsSource)) ? cc.logsSource : "logs";
                // Use a minimal schema with the commonly used columns. The task_uid/detail columns
                // match the default mapping in DbInspector.logColMap. Additional columns are optional.
                String createSql = "CREATE TABLE IF NOT EXISTS " + logsTable + " (" +
                        "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                        "log_uid TEXT UNIQUE, " +
                        "task_uid TEXT, " +
                        "detail TEXT, " +
                        "created_at INTEGER, " +
                        "task_name_snapshot TEXT, " +
                        "task_start_time_snapshot TEXT" +
                        ")";
                db.execSQL(createSql);
            } catch (Throwable e) {
                Log.e("DbRepository", "ensure logs table error", e);
            }
            return db;
        } catch (Throwable e) {
            Log.e("DbRepository", "openOrCreateFallback error", e);
            return null;
        }
    }

    public static void setNextTime(Context ctx, String uid, long nextEpochMs) {
        DbInspector.Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null) return;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return;
        try {
            String table = TextUtils.isEmpty(cc.tasksSource) ? "tasks" : cc.tasksSource;
            String uidCol = cc.taskColMap.containsKey("uid") ? cc.taskColMap.get("uid") : "task_uid";
            String nextCol = cc.taskColMap.containsKey("next_time") ? cc.taskColMap.get("next_time") : "next_time";
            // Format to ISO-like string 'yyyy-MM-ddTHH:mm:ss'
            java.text.SimpleDateFormat fmt = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US);
            String iso = fmt.format(new java.util.Date(nextEpochMs));
            android.content.ContentValues cv = new android.content.ContentValues();
            cv.put(nextCol, iso);
            int __affected = 0;
            try { __affected = db.update(table, cv, uidCol + "=?", new String[]{uid}); } catch (Throwable ignore) {}
            if (__affected == 0) {
                // FALLBACK_TODAY_BY_TASK: update today's row by task_uid when quote_uid mismatch
                String taskCol = cc.quoteColMap.containsKey("task_uid") ? cc.quoteColMap.get("task_uid") : "task_uid";
                String where = taskCol + "=? AND DATE(COALESCE(last_notified_at, inserted_at, strftime('%Y-%m-%d %H:%M:%S', created_at/1000,'unixepoch','localtime'))) = DATE('now','localtime')";
                try { db.update(table, cv, where, new String[]{ uid }); } catch (Throwable ignore) {}
            }
        } catch (Throwable e) {
            android.util.Log.e("DbRepository", "setNextTime error", e);
        } finally {
            try { db.close(); } catch (Throwable e) { android.util.Log.e("DbRepository", "error", e); }
        }
    }


    /** Increase task cursor (游标) by delta (default +1). Safe: no-op if column missing. */
    public static void incTaskCursor(Context ctx, String uid, int delta) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null) return;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return;
        try {
            String table = TextUtils.isEmpty(cc.tasksSource) ? "tasks" : cc.tasksSource;
            String uidCol = cc.taskColMap.containsKey("uid") ? cc.taskColMap.get("uid") : "task_uid";
            String curCol = cc.taskColMap.containsKey("cursor") ? cc.taskColMap.get("cursor") : "cursor";
            // check column exists
            boolean has = false;
            try (Cursor c = db.rawQuery("PRAGMA table_info("+table+")", null)) {
                while (c.moveToNext()) {
                    String col = c.getString(1);
                    if (curCol.equalsIgnoreCase(col)) { has = true; break; }
                }
            }
            if (!has) { log(ctx, uid, "incTaskCursor: column '"+curCol+"' missing in "+table); return; }
            db.execSQL("UPDATE "+table+" SET "+curCol+"=COALESCE("+curCol+",0)+? WHERE "+uidCol+"=?", new Object[]{delta, uid});
        } catch (Throwable e) { Log.e("DbRepository","incTaskCursor error", e); }
        finally { try { db.close(); } catch (Throwable ignore) {} }
    }

    /** Update quotes table: last notify time (yyyy-MM-dd HH:mm) and notify status (1/0). */
    public static void updateQuoteNotify(Context ctx, String uid, boolean success, long nowMs) {
        Contract cc = DbInspector.loadOrLightScan(ctx);
        if (cc == null) return;
        SQLiteDatabase db = openOrCreateFallback(ctx, cc);
        if (db == null) return;
        try {
            String table = TextUtils.isEmpty(cc.quotesSource) ? "quotes" : cc.quotesSource;
            String tasks = android.text.TextUtils.isEmpty(cc.tasksSource) ? "tasks" : cc.tasksSource;


            java.text.SimpleDateFormat fmt = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US);
            String ts = fmt.format(new java.util.Date(nowMs));

            android.content.ContentValues cv = new android.content.ContentValues();
            cv.put("notified", success ? 1 : 0);
            cv.put("last_notified_at", ts);
                        java.util.Set<String> _cols = com.example.quote_app.data.DbInspector.listColumns(db, table);
            try { if (_cols != null && _cols.contains("notify_status")) cv.put("notify_status", success ? 1 : 0); } catch (Throwable ignore) {}
            try { if (_cols != null && _cols.contains("last_notify_time")) cv.put("last_notify_time", ts); } catch (Throwable ignore) {}
            try { if (_cols == null || !_cols.contains("last_notify_time")) DbRepository.log(ctx, uid, "【原生】update：logs 提示：无 last_notify_time 列，已跳过写入"); } catch (Throwable ignore) {}

            
            int cursorVal = 0;
            String typeVal = "";
            String orderVal = null;
            String curColName = "cursor";
            String typeColName = "type";
            String orderColName = "carousel_order";
            // Map dynamic column names according to DbInspector
            try {
                if (cc.taskColMap.containsKey("cursor")) curColName = cc.taskColMap.get("cursor");
                if (cc.taskColMap.containsKey("type")) typeColName = cc.taskColMap.get("type");
                if (cc.taskColMap.containsKey("carousel_order")) orderColName = cc.taskColMap.get("carousel_order");
            } catch (Throwable ignore) {}
            try (android.database.Cursor c0 = db.query(tasks, new String[]{ curColName, typeColName, orderColName }, "task_uid=?", new String[]{ uid }, null, null, null)) {
                if (c0 != null && c0.moveToFirst()) {
                    // read cursor
                    if (!c0.isNull(0)) cursorVal = c0.getInt(0);
                    // read type
                    if (!c0.isNull(1)) typeVal = c0.getString(1);
                    // read order
                    if (!c0.isNull(2)) orderVal = c0.getString(2);
                }
            } catch (Throwable ignore) {}

            // Determine the total number of quotes and scope depending on task type
            int total = 0;
            boolean scopedByTask = false;
            if ("批量导入任务".equals(typeVal) || "自动任务".equals(typeVal) || "AUTO".equalsIgnoreCase(typeVal)) {
                scopedByTask = true;
                try (android.database.Cursor c = db.rawQuery("SELECT COUNT(*) FROM "+table+" WHERE task_uid=?", new String[]{uid})) {
                    if (c != null && c.moveToFirst()) total = c.getInt(0);
                } catch (Throwable ignore) {}
            } else if ("carousel".equalsIgnoreCase(typeVal) || "轮播".equals(typeVal)) {
                scopedByTask = false;
                try (android.database.Cursor c = db.rawQuery("SELECT COUNT(*) FROM "+table, null)) {
                    if (c != null && c.moveToFirst()) total = c.getInt(0);
                } catch (Throwable ignore) {}
            }

            // Calculate target offset based on cursor (cursor-1, or wrap to total-1)
            int targetOffset;
            if (total > 0) {
                targetOffset = (cursorVal > 0) ? (cursorVal - 1) : (total - 1);
            } else {
                targetOffset = Math.max(0, cursorVal - 1);
            }

            // Determine ordering: default DESC; for carousel tasks check carousel_order
            String effectiveOrder = "DESC";
            boolean isCarousel = "carousel".equalsIgnoreCase(typeVal) || "轮播".equals(typeVal);
            if (isCarousel) {
                String orderLower = (orderVal == null ? "" : orderVal.trim().toLowerCase(java.util.Locale.US));
                if ("asc".equals(orderLower) || "升序".equals(orderLower)) {
                    effectiveOrder = "ASC";
                } else {
                    // random and desc both use DESC here
                    effectiveOrder = "DESC";
                }
            }

            long targetRowId = -1L;
            String orderBy = "rowid " + effectiveOrder;
            // Query rowid of the previously sent quote (cursor-1) using order and scope
            try (android.database.Cursor cq = scopedByTask
                    ? db.query(table, new String[]{"rowid"}, "task_uid=?", new String[]{ uid }, null, null, orderBy, "1 OFFSET " + targetOffset)
                    : db.query(table, new String[]{"rowid"}, null, null, null, null, orderBy, "1 OFFSET " + targetOffset)) {
                if (cq != null && cq.moveToFirst()) targetRowId = cq.getLong(0);
            } catch (Throwable ignore) {}

            try { log(ctx, uid, "【DB】update pick: scoped="+scopedByTask+", cursor="+cursorVal+", total="+total+", targetOffset="+targetOffset+", targetRowId="+targetRowId); } catch (Throwable ignore) {}
            if (targetRowId != -1L) {
                db.update(table, cv, "rowid=?", new String[]{ String.valueOf(targetRowId) });
                try { log(ctx, uid, "【原生】更新通知状态：notified="+(success?1:0)+"，时间="+ts+"，目标rowid="+targetRowId); } catch (Throwable ignore) {}
            } else {
                try { log(ctx, uid, "【原生】未找到可更新的名人名言记录（可能游标超出范围）；success="+(success?1:0)+", 游标="+cursorVal+", 时间="+ts); } catch (Throwable ignore) {} }
        } catch (Throwable e) {
            android.util.Log.e("DbRepository","updateQuoteNotify error", e);
        } finally {
            try { db.close(); } catch (Throwable ignore) {}
        }
}


    public static void rotateCursorByTaskType(Context ctx, String uid) {
        SQLiteDatabase db = null;
        try {
            DbInspector.Contract cc = DbInspector.loadOrLightScan(ctx);
            if (cc == null) return;
            db = SQLiteDatabase.openDatabase(cc.dbPath, null, SQLiteDatabase.OPEN_READWRITE);
            String tasks = cc.tasksSource != null ? cc.tasksSource : "tasks";
            String quotes = cc.quotesSource != null ? cc.quotesSource : "quotes";
            String tUid = cc.taskColMap.containsKey("uid") ? cc.taskColMap.get("uid") : "task_uid";
            String tType = cc.taskColMap.containsKey("type") ? cc.taskColMap.get("type") : "type";
            String tCur  = cc.taskColMap.containsKey("cursor") ? cc.taskColMap.get("cursor") : "cursor";
            String qUid  = cc.quoteColMap.containsKey("uid") ? cc.quoteColMap.get("uid") : "task_uid";
            // read task row
            String type = null; int cur = 0;
            try (Cursor c = db.rawQuery("SELECT "+tType+", "+tCur+" FROM "+tasks+" WHERE "+tUid+"=?", new String[]{uid})) {
                if (!c.moveToFirst()) { return; }
                type = c.isNull(0) ? "" : c.getString(0);
                cur = c.isNull(1) ? 0 : c.getInt(1);
            }
            // decide total
            int total = 0;
            if ("批量导入任务".equals(type) || "自动任务".equals(type) || "AUTO".equalsIgnoreCase(type)) {
                try (Cursor c = db.rawQuery("SELECT COUNT(*) FROM "+quotes+" WHERE "+qUid+"=?", new String[]{uid})) {
                    if (c.moveToFirst()) total = c.getInt(0);
                }
            } else if ("carousel".equals(type) || "轮播".equals(type) || "轮播任务".equals(type)) {
                try (Cursor c = db.rawQuery("SELECT COUNT(*) FROM "+quotes, null)) {
                    if (c.moveToFirst()) total = c.getInt(0);
                }
            } else {
                // other types: do not update cursor
                return;
            }
            int next = 0;
            if (total <= 0) {
                next = 0;
            } else {
                next = (cur < (total - 1)) ? (cur + 1) : 0;
            }
            android.content.ContentValues cv = new android.content.ContentValues();
            cv.put(tCur, next);
            db.update(tasks, cv, tUid + "=?", new String[]{uid});
            try { log(ctx, uid, "【DB】cursor rotate type="+type+" cur="+cur+" total="+total+" -> next="+next); } catch (Throwable ignore) {}
        } catch (Throwable e) {
            android.util.Log.e("DbRepository","rotateCursorByTaskType error", e);
        } finally {
            if (db != null) try { db.close(); } catch (Throwable ignore) {}
        }
    }
    
}