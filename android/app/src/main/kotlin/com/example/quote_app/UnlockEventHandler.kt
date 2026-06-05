package com.example.quote_app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.os.PowerManager
import android.os.Process
import com.example.quote_app.data.DbInspector
import com.example.quote_app.data.DbRepo
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 解锁事件处理器：
 * - 目标：提升“解锁轻提醒/地点规则提醒”链路的实时性与稳定性。
 * - 手段：在解锁广播线程内（goAsync + 后台线程）直接处理，不依赖 WorkManager。
 *   同时提升线程优先级 + 短时 WakeLock（避免被系统延后/挂起）。
 */
object UnlockEventHandler {

  // ---- Unlock chain state (short-window dedup / fallback coordination) ----
  // 目的：在“广播/探测/脉冲/兜底”多入口并发时，避免重复触发地点规则通知。
  // 说明：
  // - inflight：表示解锁链路正在执行（短窗口内）
  // - done：表示解锁链路已完成（短窗口内）
  // 这些标记仅用于 <30s 的去重/协调，不改变既有的业务冷却策略。
  private const val SP = "quote_prefs"
  private const val KEY_UNLOCK_CHAIN_INFLIGHT_TS = "unlock_chain_inflight_ts"
  private const val KEY_UNLOCK_CHAIN_DONE_TS = "unlock_chain_done_ts"

  @JvmStatic
  fun markUnlockChainInflight(ctx: Context, source: String) {
    val app = ctx.applicationContext
    try {
      app.getSharedPreferences(SP, Context.MODE_PRIVATE)
        .edit()
        .putLong(KEY_UNLOCK_CHAIN_INFLIGHT_TS, System.currentTimeMillis())
        .apply()
    } catch (_: Throwable) {
      // ignore
    }
  }

  @JvmStatic
  fun markUnlockChainDone(ctx: Context, source: String) {
    val app = ctx.applicationContext
    try {
      app.getSharedPreferences(SP, Context.MODE_PRIVATE)
        .edit()
        .putLong(KEY_UNLOCK_CHAIN_DONE_TS, System.currentTimeMillis())
        .putLong(KEY_UNLOCK_CHAIN_INFLIGHT_TS, 0L)
        .apply()
    } catch (_: Throwable) {
      // ignore
    }
  }

  @JvmStatic
  fun getUnlockChainInflightTs(ctx: Context): Long {
    val app = ctx.applicationContext
    return try {
      app.getSharedPreferences(SP, Context.MODE_PRIVATE)
        .getLong(KEY_UNLOCK_CHAIN_INFLIGHT_TS, 0L)
    } catch (_: Throwable) {
      0L
    }
  }

  @JvmStatic
  fun getUnlockChainDoneTs(ctx: Context): Long {
    val app = ctx.applicationContext
    return try {
      app.getSharedPreferences(SP, Context.MODE_PRIVATE)
        .getLong(KEY_UNLOCK_CHAIN_DONE_TS, 0L)
    } catch (_: Throwable) {
      0L
    }
  }

  /**
   * 以较高优先级运行一段逻辑：
   * - 提升当前线程优先级到前台级
   * - 获取 10 秒 Partial WakeLock（超时自动释放）
   */
  @JvmStatic
  fun withHighPriority(ctx: Context, reason: String, block: () -> Unit) {
    val app = ctx.applicationContext

    // 1) 提升线程优先级
    try {
      Process.setThreadPriority(Process.THREAD_PRIORITY_FOREGROUND)
    } catch (_: Throwable) {
      // ignore
    }

    // 2) WakeLock：尽量保证解锁后立即完成本地 IO + 通知发送
    var wl: PowerManager.WakeLock? = null
    try {
      val pm = app.getSystemService(Context.POWER_SERVICE) as? PowerManager
      wl = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "quote_app:unlock:$reason")
      wl?.setReferenceCounted(false)
      wl?.acquire(10_000L)
    } catch (_: Throwable) {
      // ignore
    }

    try {
      block()
    } finally {
      try {
        if (wl?.isHeld == true) wl?.release()
      } catch (_: Throwable) {
        // ignore
      }
    }
  }

  /**
   * 解锁轻提醒：
   * - 读取 notify_config.unlock_switch_enabled
   * - 读取冷却（unlock_cooldown_days / unlock_cooldown_minutes）
   * - 冷却通过则立即发送通知并写入 last_unlock_reminder_time
   */
  @JvmStatic
  fun handleUnlockLightReminder(ctx: Context, source: String) {
    val app = ctx.applicationContext
    val uid: String? = null

    // 读取数据库路径
    val contract = try { DbInspector.loadOrLightScan(app) } catch (_: Throwable) { null }
    if (contract == null || contract.dbPath == null) {
      logWithTime(app, uid, "【解锁轻提醒】无法定位数据库文件，跳过（source=$source，回包：SKIP_NO_DB）")
      return
    }

    var db: SQLiteDatabase? = null
    try {
      db = SQLiteDatabase.openDatabase(contract.dbPath, null, SQLiteDatabase.OPEN_READONLY)
    } catch (_: Throwable) {
      db = null
    }

    if (db == null) {
      logWithTime(app, uid, "【解锁轻提醒】数据库打开失败，跳过（source=$source，回包：SKIP_DB_OPEN_FAIL）")
      return
    }

    try {
      // 1) 开关
      var enabled = false
      try {
        db.rawQuery("SELECT value FROM notify_config WHERE key='unlock_switch_enabled' LIMIT 1", null).use { c ->
          if (c.moveToFirst()) {
            val v = c.getString(0)
            val s = v?.trim()?.lowercase() ?: ""
            enabled = (s == "1" || s == "true")
          }
        }
      } catch (_: Throwable) {
        // ignore
      }
      if (!enabled) {
        logWithTime(app, uid, "【解锁轻提醒】开关关闭，跳过（source=$source，回包：SKIP_SWITCH_OFF）")
        return
      }

      // 2) 冷却（默认 30 分钟）
      var cooldownMs = 30L * 60L * 1000L
      // 天优先
      try {
        db.rawQuery("SELECT value FROM notify_config WHERE key='unlock_cooldown_days' LIMIT 1", null).use { c ->
          if (c.moveToFirst()) {
            val v = c.getString(0)
            val d = v?.toDoubleOrNull()
            if (d != null && d > 0.0) {
              cooldownMs = (d * 24.0 * 60.0 * 60.0 * 1000.0).toLong()
            }
          }
        }
      } catch (_: Throwable) {
        // ignore
      }
      // 若天未覆盖，再按分钟
      if (cooldownMs == 30L * 60L * 1000L) {
        try {
          db.rawQuery("SELECT value FROM notify_config WHERE key='unlock_cooldown_minutes' LIMIT 1", null).use { c ->
            if (c.moveToFirst()) {
              val v = c.getString(0)
              val m = v?.toDoubleOrNull()
              if (m != null && m > 0.0) {
                cooldownMs = (m * 60.0 * 1000.0).toLong()
              }
            }
          }
        } catch (_: Throwable) {
          // ignore
        }
      }

      // 3) 冷却判断
      val now = System.currentTimeMillis()
      val prefs = app.getSharedPreferences("vision_prefs", Context.MODE_PRIVATE)
      val last = try { prefs.getLong("last_unlock_reminder_time", 0L) } catch (_: Throwable) { 0L }
      if (last > 0L && (now - last) < cooldownMs) {
        logWithTime(app, uid, "【解锁轻提醒】仍处于冷却期，跳过（cooldownMs=$cooldownMs，source=$source，回包：SKIP_COOLDOWN）")
        return
      }

      // 4) 发送通知（立即）
      val id = 10086
      val title = "继续专注"
      val body = "别忘了你的一件事！"

      try {
        NotifyHelper.sendUnlockReminder(app, id, title, body)
        try { prefs.edit().putLong("last_unlock_reminder_time", System.currentTimeMillis()).apply() } catch (_: Throwable) {}
        logWithTime(app, uid, "【解锁轻提醒】发送成功（source=$source，回包：SUCCESS）")
      } catch (t: Throwable) {
        logWithTime(app, uid, "【解锁轻提醒】发送失败：${t.message ?: "unknown"}（source=$source，回包：FAIL）")
      }
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
  }

  private fun logWithTime(ctx: Context, uid: String?, msg: String) {
    try {
      val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
      val now = sdf.format(Date())
      DbRepo.log(ctx, uid, "[$now] $msg")
    } catch (_: Throwable) {
      try { DbRepo.log(ctx, uid, msg) } catch (_: Throwable) {}
    }
  }
}
