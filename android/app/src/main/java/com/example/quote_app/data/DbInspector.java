package com.example.quote_app.data;

import android.util.Log;

import android.content.Context;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.preference.PreferenceManager;
import android.text.TextUtils;

import org.json.JSONObject;

import java.io.File;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;

public final class DbInspector {

    public static final class Contract {
        public String dbPath;
        public String tasksSource;
        public String quotesSource;
        public String logsSource;
        public int version;
        public final Map<String, String> taskColMap = new HashMap<>();
        public final Map<String, String> quoteColMap = new HashMap<>();
        public final Map<String, String> logColMap = new HashMap<>();
    }

    private static final String PREF_KEY = "db.contract";

    /**
     * Best-effort check: whether the given sqlite file looks like our app DB.
     *
     * 背景接收器（如 UnlockPulse）需要读取开关配置并写入日志表。
     * 若误把 /databases 下的 workdb 等数据库当成业务库，会导致：
     * - 读取 notify_config 失败 -> 认为开关关闭 -> 脉冲被取消（看起来“完全没效果”）
     * - 写日志写入到了错误的 DB -> 应用内“日志表”看不到
     */
    private static boolean looksLikeAppDb(String path) {
        if (TextUtils.isEmpty(path)) return false;
        SQLiteDatabase db = null;
        try {
            db = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY);
            // 1) Prefer notify_config (unlock/geo 开关都在这张表)
            try (Cursor c = db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='notify_config' LIMIT 1", null)) {
                if (c.moveToFirst()) return true;
            } catch (Throwable ignore) {}

            // 2) Fallback: tasks 表存在且包含 task_uid/uid 列
            try (Cursor tc = db.rawQuery("PRAGMA table_info(tasks)", null)) {
                while (tc.moveToNext()) {
                    String col = tc.getString(1);
                    if ("task_uid".equals(col) || "uid".equals(col)) return true;
                }
            } catch (Throwable ignore) {}
        } catch (Throwable ignore) {
            // ignore
        } finally {
            try { if (db != null) db.close(); } catch (Throwable ignore) {}
        }
        return false;
    }

    public static Contract loadOrLightScan(Context ctx) {
        Contract cached = loadFromPrefs(ctx);
        if (cached != null && !TextUtils.isEmpty(cached.dbPath)) {
            try {
                java.io.File f = new java.io.File(cached.dbPath);
                if (f.exists() && looksLikeAppDb(cached.dbPath)) return cached;
            } catch (Throwable ignore) {}
        }
        Contract c = new Contract();
        try {
            File dbDir = new File(ctx.getApplicationInfo().dataDir, "databases");
            if (dbDir.exists()) {
                File[] files = dbDir.listFiles();
        if (files != null && files.length > 0) {
            // prefer DB that has our expected tables/columns
            for (File f : files) {
                // Skip obvious non-business DBs early (workmanager, analytics, etc.)
                try {
                    String n = (f == null) ? "" : f.getName();
                    if (n.contains("workdb") || n.contains("workmanager") || n.contains("measurement")) continue;
                } catch (Throwable ignore) {}
                try (SQLiteDatabase db = SQLiteDatabase.openDatabase(f.getAbsolutePath(), null, SQLiteDatabase.OPEN_READONLY)) {
                    try (Cursor tc = db.rawQuery("PRAGMA table_info(tasks)", null)) {
                        boolean hasTasks = false;
                        while (tc.moveToNext()) {
                            String col = tc.getString(1);
                            if ("task_uid".equals(col) || "uid".equals(col)) { hasTasks = true; break; }
                        }
                        if (hasTasks) { c.dbPath = f.getAbsolutePath(); break; }
                    } catch (Throwable e) { Log.e("DbInspector", "error", e); }
                } catch (Throwable e) { Log.e("DbInspector", "error", e); }
            }
            // IMPORTANT:
            // Do NOT fall back to files[0] here. /databases often contains workmanager's workdb,
            // which would make background features falsely think the switch is disabled and
            // write logs into the wrong DB.
        }
            }
            if (TextUtils.isEmpty(c.dbPath)) {
            // Prefer sqflite default db name if present
            File cand = ctx.getDatabasePath("quote_app.db");
            if (cand != null && cand.exists() && looksLikeAppDb(cand.getAbsolutePath())) {
                c.dbPath = cand.getAbsolutePath();
            } else {
                // Only use app.db if it actually exists; otherwise keep empty and let other fallbacks/scans decide.
                File cand2 = ctx.getDatabasePath("app.db");
                if (cand2 != null && cand2.exists() && looksLikeAppDb(cand2.getAbsolutePath())) {
                    c.dbPath = cand2.getAbsolutePath();
                }
            // Fallbacks for common sqflite locations
            if (TextUtils.isEmpty(c.dbPath)) {
                try { java.io.File f1 = new java.io.File(ctx.getFilesDir(), "quotes.db"); if (f1.exists()) c.dbPath = f1.getAbsolutePath(); } catch (Throwable e) { Log.e("DbInspector","error", e);} 
            }
            if (TextUtils.isEmpty(c.dbPath)) {
                try { java.io.File f2 = new java.io.File(ctx.getApplicationInfo().dataDir + "/app_flutter/quotes.db"); if (f2.exists()) c.dbPath = f2.getAbsolutePath(); } catch (Throwable e) { Log.e("DbInspector","error", e);} 
            }

            }
            }
        } catch (Throwable e) { Log.e("DbInspector", "error", e); }

        if (TextUtils.isEmpty(c.tasksSource)) c.tasksSource = "tasks";
        if (TextUtils.isEmpty(c.quotesSource)) c.quotesSource = "quotes";
        if (TextUtils.isEmpty(c.logsSource)) c.logsSource = "logs";

        if (!c.taskColMap.containsKey("uid")) c.taskColMap.put("uid", "task_uid");
if (!c.taskColMap.containsKey("title")) c.taskColMap.put("title", "name");
if (!c.taskColMap.containsKey("content")) c.taskColMap.put("content", "prompt");
if (!c.taskColMap.containsKey("avatar")) c.taskColMap.put("avatar", "avatar_path");
if (!c.taskColMap.containsKey("enabled")) c.taskColMap.put("enabled", "status");
if (!c.taskColMap.containsKey("trigger_at")) c.taskColMap.put("trigger_at", "start_time");
if (!c.taskColMap.containsKey("next_time")) c.taskColMap.put("next_time", "next_time");
if (!c.quoteColMap.containsKey("uid")) c.quoteColMap.put("uid", "task_uid");
if (!c.quoteColMap.containsKey("content")) c.quoteColMap.put("content", "content");
        if (!c.quoteColMap.containsKey("title")) c.quoteColMap.put("title", "theme");

        if (!c.logColMap.containsKey("uid")) c.logColMap.put("uid", "task_uid");
if (!c.logColMap.containsKey("detail")) c.logColMap.put("detail", "detail");

        c.version = 1;
        
        // Map to Flutter DB schema
        if (!c.taskColMap.containsKey("uid")) c.taskColMap.put("uid", "task_uid");
if (!c.taskColMap.containsKey("title")) c.taskColMap.put("title", "name");
if (!c.taskColMap.containsKey("content")) c.taskColMap.put("content", "prompt");
if (!c.taskColMap.containsKey("avatar")) c.taskColMap.put("avatar", "avatar_path");
if (!c.taskColMap.containsKey("enabled")) c.taskColMap.put("enabled", "status");
        if (!c.taskColMap.containsKey("title")) c.taskColMap.put("title", "name");
        if (!c.taskColMap.containsKey("content")) c.taskColMap.put("content", "prompt");
        if (!c.taskColMap.containsKey("type")) c.taskColMap.put("type", "type");
        if (!c.taskColMap.containsKey("avatar")) c.taskColMap.put("avatar", "avatar_path");
        if (!c.taskColMap.containsKey("enabled")) c.taskColMap.put("enabled", "status");
        if (!c.taskColMap.containsKey("trigger_at")) c.taskColMap.put("trigger_at", "start_time");
        if (!c.taskColMap.containsKey("next_time")) c.taskColMap.put("next_time", "next_time");
if (!c.quoteColMap.containsKey("uid")) c.quoteColMap.put("uid", "task_uid");
        if (!c.quoteColMap.containsKey("content")) c.quoteColMap.put("content", "content");
        if (!c.quoteColMap.containsKey("title")) c.quoteColMap.put("title", "theme");
        if (!c.quoteColMap.containsKey("avatar")) c.quoteColMap.put("avatar", "avatar");

        if (!c.logColMap.containsKey("uid")) c.logColMap.put("uid", "task_uid");
        if (!c.logColMap.containsKey("detail")) c.logColMap.put("detail", "detail");
    saveToPrefs(ctx, c);
        try { DbRepository.log(ctx, "_SYS_", "【原生】数据库检测：使用dbPath="+c.dbPath+", tasks="+c.tasksSource+", quotes="+c.quotesSource+", logs="+c.logsSource); } catch (Throwable ignore) {}
        return c;
    }

    private static Contract loadFromPrefs(Context ctx) {
        Contract c = new Contract();
        String preFoundDbPath = null;
        try {
            if (TextUtils.isEmpty(c.dbPath)) {
            File af = new File(ctx.getApplicationInfo().dataDir, "app_flutter");
            if (af.exists()) {
                File[] afs = af.listFiles();
                if (afs != null) {
                    // prefer quotes.db
                    File preferred = null;
                    for (File f : afs) {
                        if (f.getName().equalsIgnoreCase("quotes.db")) { preferred = f; break; }
                    }
                    if (preferred != null) {
                        c.dbPath = preferred.getAbsolutePath();
                    } else {
                        for (File f : afs) {
                            if (!f.getName().endsWith(".db")) continue;
                            try (SQLiteDatabase db = SQLiteDatabase.openDatabase(f.getAbsolutePath(), null, SQLiteDatabase.OPEN_READONLY)) {
                                try (Cursor tc = db.rawQuery("PRAGMA table_info(tasks)", null)) {
                                    boolean hasTasks = false;
                                    while (tc.moveToNext()) {
                                        String col = tc.getString(1);
                                        if ("task_uid".equals(col) || "uid".equals(col)) { hasTasks = true; break; }
                                    }
                                    if (hasTasks) { c.dbPath = f.getAbsolutePath(); }
                                } catch (Throwable e) { Log.e("DbInspector", "error", e); }
                            } catch (Throwable ignore) {}
                            if (!TextUtils.isEmpty(c.dbPath)) break;
                        }
                    }
                }
            }
        }

            // Remember any db we discovered on disk before reading prefs.
            preFoundDbPath = c.dbPath;

            SharedPreferences sp = PreferenceManager.getDefaultSharedPreferences(ctx);
            String raw = sp.getString(PREF_KEY, null);
            if (TextUtils.isEmpty(raw)) {
                // 若尚未持久化合约，但已在 app_flutter 发现 quotes.db，则直接使用它，避免首次运行落到 fallback app.db。
                if (!TextUtils.isEmpty(c.dbPath)) {
                    if (TextUtils.isEmpty(c.tasksSource)) c.tasksSource = "tasks";
                    if (TextUtils.isEmpty(c.quotesSource)) c.quotesSource = "quotes";
                    if (TextUtils.isEmpty(c.logsSource)) c.logsSource = "logs";
                    if (!c.taskColMap.containsKey("uid")) c.taskColMap.put("uid", "task_uid");
                    if (!c.quoteColMap.containsKey("uid")) c.quoteColMap.put("uid", "task_uid");
                    if (!c.logColMap.containsKey("uid")) c.logColMap.put("uid", "task_uid");
                    if (!c.logColMap.containsKey("detail")) c.logColMap.put("detail", "detail");
                    saveToPrefs(ctx, c);
                    return c;
                }
                try { DbRepository.log(ctx, "_SYS_", "【原生】数据库检测：未找到有效数据库，返回空合约"); } catch (Throwable ignore) {}
                return null;
            }
            JSONObject o = new JSONObject(raw);
            
            c.dbPath = o.optString("dbPath", null);
            c.tasksSource = o.optString("tasksSource", null);
            c.quotesSource = o.optString("quotesSource", null);
            c.logsSource = o.optString("logsSource", null);
            c.version = o.optInt("version", 1);
            JSONObject tm = o.optJSONObject("taskColMap");
            if (tm != null) {
                Iterator<String> it = tm.keys();
                while (it.hasNext()) {
                    String k = it.next();
                    String v = tm.optString(k, null);
                    if (v != null) c.taskColMap.put(k, v);
                }
            }
            JSONObject qm = o.optJSONObject("quoteColMap");
            if (qm != null) {
                Iterator<String> it = qm.keys();
                while (it.hasNext()) {
                    String k = it.next();
                    String v = qm.optString(k, null);
                    if (v != null) c.quoteColMap.put(k, v);
                }
            }
            JSONObject lm = o.optJSONObject("logColMap");
            if (lm != null) {
                Iterator<String> it = lm.keys();
                while (it.hasNext()) {
                    String k = it.next();
                    String v = lm.optString(k, null);
                    if (v != null) c.logColMap.put(k, v);
                }
            }

            // Validate persisted dbPath: if it doesn't exist, discard it so callers won't crash
            // trying to open a non-existent DB (common after reinstall / data cleanup).
            try {
                if (!TextUtils.isEmpty(c.dbPath)) {
                    File f = new File(c.dbPath);
                    if (!f.exists() || !f.isFile()) {
                        try { sp.edit().remove(PREF_KEY).apply(); } catch (Throwable ignore) {}
                        // If we discovered a valid db on disk earlier, use it instead.
                        if (!TextUtils.isEmpty(preFoundDbPath)) {
                            try {
                                File f2 = new File(preFoundDbPath);
                                if (f2.exists() && f2.isFile()) {
                                    c.dbPath = preFoundDbPath;
                                    if (TextUtils.isEmpty(c.tasksSource)) c.tasksSource = "tasks";
                                    if (TextUtils.isEmpty(c.quotesSource)) c.quotesSource = "quotes";
                                    if (TextUtils.isEmpty(c.logsSource)) c.logsSource = "logs";
                                    saveToPrefs(ctx, c);
                                    return c;
                                }
                            } catch (Throwable ignore) {}
                        }
                        return null;
                    }
                }
            } catch (Throwable ignore) {}
            return c;
        } catch (Throwable e) { Log.e("DbInspector", "error", e); 
            return null;
        }
    }

    private static void saveToPrefs(Context ctx, Contract c) {
        try {
            JSONObject o = new JSONObject();
            o.put("dbPath", c.dbPath);
            o.put("tasksSource", c.tasksSource);
            o.put("quotesSource", c.quotesSource);
            o.put("logsSource", c.logsSource);
            o.put("version", c.version);

            JSONObject tm = new JSONObject();
            for (Map.Entry<String, String> e : c.taskColMap.entrySet()) {
                tm.put(e.getKey(), e.getValue());
            }
            o.put("taskColMap", tm);

            JSONObject qm = new JSONObject();
            for (Map.Entry<String, String> e : c.quoteColMap.entrySet()) {
                qm.put(e.getKey(), e.getValue());
            }
            o.put("quoteColMap", qm);

            JSONObject lm = new JSONObject();
            for (Map.Entry<String, String> e : c.logColMap.entrySet()) {
                lm.put(e.getKey(), e.getValue());
            }
            o.put("logColMap", lm);

            if (TextUtils.isEmpty(c.dbPath)) {
            File af = new File(ctx.getApplicationInfo().dataDir, "app_flutter");
            if (af.exists()) {
                File[] afs = af.listFiles();
                if (afs != null) {
                    // prefer quotes.db
                    File preferred = null;
                    for (File f : afs) {
                        if (f.getName().equalsIgnoreCase("quotes.db")) { preferred = f; break; }
                    }
                    if (preferred != null) {
                        c.dbPath = preferred.getAbsolutePath();
                    } else {
                        for (File f : afs) {
                            if (!f.getName().endsWith(".db")) continue;
                            try (SQLiteDatabase db = SQLiteDatabase.openDatabase(f.getAbsolutePath(), null, SQLiteDatabase.OPEN_READONLY)) {
                                try (Cursor tc = db.rawQuery("PRAGMA table_info(tasks)", null)) {
                                    boolean hasTasks = false;
                                    while (tc.moveToNext()) {
                                        String col = tc.getString(1);
                                        if ("task_uid".equals(col) || "uid".equals(col)) { hasTasks = true; break; }
                                    }
                                    if (hasTasks) { c.dbPath = f.getAbsolutePath(); }
                                } catch (Throwable e) { Log.e("DbInspector", "error", e); }
                            } catch (Throwable ignore) {}
                            if (!TextUtils.isEmpty(c.dbPath)) break;
                        }
                    }
                }
            }
        }

            SharedPreferences sp = PreferenceManager.getDefaultSharedPreferences(ctx);
            sp.edit().putString(PREF_KEY, o.toString()).apply();
        } catch (Throwable e) { Log.e("DbInspector", "error", e); }
    }

    public static Set<String> listColumns(SQLiteDatabase db, String table) {
        Set<String> s = new HashSet<>();
        if (db == null || TextUtils.isEmpty(table)) return s;
        try (Cursor c = db.rawQuery("PRAGMA table_info(" + table + ")", null)) {
            while (c.moveToNext()) s.add(c.getString(1));
        } catch (Throwable e) { Log.e("DbInspector", "error", e); }
        return s;
    }
}