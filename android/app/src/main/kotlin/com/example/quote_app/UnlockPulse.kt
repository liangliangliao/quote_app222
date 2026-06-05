package com.example.quote_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.example.quote_app.data.DbInspector
import com.example.quote_app.data.DbRepo

/**
 * 无常驻通知的“命中率增强”方案：低频脉冲探测锁屏/解锁状态。
 *
 * 设计原则：
 * - 不依赖 SCREEN_ON / USER_PRESENT 是否投递（它们在部分 ROM/后台场景可能丢失）。
 * - 不进行周期性定位；仅在检测到“从锁屏 -> 已解锁”的状态跃迁时，才触发解锁轻提醒/地点规则。
 * - 为了兼容 Android 12+ 对 exact alarms 的限制，使用 setWindow（非 exact）自循环调度。
 *
 * 说明：这不是 WorkManager 周期定位任务；它只做状态检查（Keyguard/interactive），成本很低。
 */
object UnlockPulse {
  private const val ACTION = "com.example.quote_app.ACTION_UNLOCK_PULSE"
  private const val RC = 4412
  // 任务列表被移除/ROM 清理后台时，部分设备会清掉普通 alarm；这里提供一个低频“锚点”wakeup alarm。
  // 目的：尽量在用户下次亮屏/解锁前，重新把脉冲链路拉起来（不常驻通知）。
  private const val ACTION_ANCHOR = "com.example.quote_app.ACTION_UNLOCK_PULSE_ANCHOR"
  private const val RC_ANCHOR = 4413

  private const val PREF = "quote_prefs"
  private const val KEY_LAST_LOCKED = "unlock_pulse_last_locked"
  private const val KEY_LAST_SCHEDULED = "unlock_pulse_last_scheduled"
  private const val KEY_LAST_PULSE_ELAPSED = "unlock_pulse_last_elapsed"
  private const val KEY_LAST_HEARTBEAT_WALL = "unlock_pulse_last_heartbeat_wall"
  private const val KEY_LAST_ANCHOR_SCHEDULED = "unlock_pulse_last_anchor_scheduled"

  // 由于后台场景中 SQLite 打开/读取可能会偶发失败（例如 DB 正在被 Flutter 写入、ROM 冻结/恢复），
  // 若 shouldEnable() 直接在失败时返回 false，会导致脉冲自我取消，从而出现“后台完全不触发”的问题。
  // 因此这里缓存一次“是否启用脉冲”的判定结果，读取失败时优先回退到缓存。
  private const val KEY_ENABLED_CACHED = "unlock_pulse_enabled_cached"
  private const val KEY_ENABLED_CACHED_TS = "unlock_pulse_enabled_cached_ts"

  // 启用开关缓存的有效期：避免每次脉冲都打开 DB（I/O 耗电）。
  // 说明：用户在前台切换开关时，通常会触发 App/Flutter 侧的重建调度；这里设置较短 TTL 以兼顾及时性。
  private const val ENABLE_CACHE_TTL_MS = 2 * 60_000L // 2min

  // 轮询间隔：用于“未命中广播”的兜底。越小越及时，但耗电越高。
  // 当前配置：120s，配合「非唤醒 alarm」方案，尽量减少后台唤醒，同时在亮屏时仍能较快补投递。
  private const val INTERVAL_MS = 120_000L
  // 注意：Android 12+ 对 setWindow() 的窗口长度有更严格的限制（最小 10 分钟），
  // 小窗口会被系统强行放大，导致“脉冲”明显变慢甚至看起来不生效。
  // 因此本实现优先使用 set()/setAndAllowWhileIdle() 作为 inexact 调度。
  private const val WINDOW_MS = 20_000L

  // 调度/探测自检：如果发现脉冲“长时间没有回调”，则主动补调度一次。
  private const val RESCHEDULE_IF_STALE_MS = 10 * 60_000L // 10min
  // 低频“锚点”wakeup alarm：用于在用户把 App 从最近任务移除/ROM 清理后台后，尽量保住一个可回调入口。
  // 约束：频率必须很低，避免耗电。默认 6 小时内最多安排一次。
  private const val ANCHOR_MIN_INTERVAL_MS = 6 * 60 * 60_000L // 6h
  private const val ANCHOR_DELAY_MS = 5 * 60_000L // 5min

  /** 在 App 主进程启动 / 开机后调用：若功能开关开启则确保脉冲调度存在。 */
  fun ensureScheduledIfNeeded(ctx: Context) {
    val app = ctx.applicationContext
    if (!shouldEnable(app)) {
      cancel(app)
      return
    }

    // 初始化一次 lastLocked，避免首次运行因 lastLocked 默认值不准而漏判。
    try {
      val pm = app.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
      val km = app.getSystemService(Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
      val interactive = try { pm?.isInteractive ?: false } catch (_: Throwable) { false }
      val locked = try { km?.isKeyguardLocked ?: true } catch (_: Throwable) { true }
      val nowLocked = (!interactive) || locked
      setLastLocked(app, nowLocked)
    } catch (_: Throwable) {}

    // 若从未调度过，或上次调度时间过久（可能被系统取消/被冻结），则补调度一次。
    val sp = app.getSharedPreferences(PREF, Context.MODE_PRIVATE)
    val last = try { sp.getLong(KEY_LAST_SCHEDULED, 0L) } catch (_: Throwable) { 0L }
    val now = System.currentTimeMillis()
    val piAlive = try { hasPendingIntent(app) } catch (_: Throwable) { true }
    if (last <= 0L || (now - last) > RESCHEDULE_IF_STALE_MS || !piAlive) {
      scheduleNext(app, delayMs = 20_000L, preferExact = false, wakeup = false)
      logWithTime(app, "【解锁脉冲】ensureScheduled: lastScheduled=$last piAlive=$piAlive now=$now -> schedule(20s)")
    }
  }

  /**
   * 低频“锚点”wakeup alarm：用于部分 ROM 在“移除最近任务/清理后台”后清掉普通 alarm 的场景。
   *
   * 注意：这不是常驻通知/前台服务；只是极低频的一次性 wakeup 安排。
   * - 仅当用户已开启了解锁轻提醒或地点规则时才会启用；
   * - 6 小时内最多安排一次；
   * - 触发后仍由 UnlockPulseReceiver 自循环（默认非唤醒）维持后续链路。
   */
  fun scheduleAnchorWakeupIfNeeded(ctx: Context, source: String) {
    val app = ctx.applicationContext
    if (!shouldEnable(app)) return
    val sp = try { app.getSharedPreferences(PREF, Context.MODE_PRIVATE) } catch (_: Throwable) { null } ?: return
    val now = System.currentTimeMillis()
    val last = try { sp.getLong(KEY_LAST_ANCHOR_SCHEDULED, 0L) } catch (_: Throwable) { 0L }
    if (last > 0L && (now - last) < ANCHOR_MIN_INTERVAL_MS) return

    try {
      val am = app.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
      val alarmType = AlarmManager.ELAPSED_REALTIME_WAKEUP
      val triggerAt = SystemClock.elapsedRealtime() + ANCHOR_DELAY_MS
      val pi = pendingIntentAnchor(app)

      // Doze 下普通 wakeup 也可能被推迟；AllowWhileIdle 仍会被节流，但作为“锚点”足够。
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        try { am.setAndAllowWhileIdle(alarmType, triggerAt, pi) } catch (_: Throwable) { am.set(alarmType, triggerAt, pi) }
      } else {
        am.set(alarmType, triggerAt, pi)
      }

      try { sp.edit().putLong(KEY_LAST_ANCHOR_SCHEDULED, now).apply() } catch (_: Throwable) {}
      logWithTime(app, "【解锁脉冲】anchor scheduled delayMs=$ANCHOR_DELAY_MS source=$source")
    } catch (_: Throwable) {
    }
  }


  fun cancel(ctx: Context) {
    val app = ctx.applicationContext
    try {
      val am = app.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
      am?.cancel(pendingIntent(app))
      am?.cancel(pendingIntentAnchor(app))
    } catch (_: Throwable) {}
    try {
      app.getSharedPreferences(PREF, Context.MODE_PRIVATE).edit().remove(KEY_LAST_SCHEDULED).remove(KEY_LAST_ANCHOR_SCHEDULED).apply()
    } catch (_: Throwable) {}
  }

  internal fun scheduleNext(
  ctx: Context,
  delayMs: Long = INTERVAL_MS,
  preferExact: Boolean = false,
  wakeup: Boolean = false
) {
  val app = ctx.applicationContext
  if (!shouldEnable(app)) {
    cancel(app)
    return
  }

  val am = app.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
  val alarmType = if (wakeup) AlarmManager.ELAPSED_REALTIME_WAKEUP else AlarmManager.ELAPSED_REALTIME
  val triggerAt = SystemClock.elapsedRealtime() + delayMs
  val pi = pendingIntent(app)

  try {
    var scheduled = false

    // 说明：
    // - wakeup=false（默认）：使用非唤醒 alarm，不会为了“探测”而主动点亮/唤醒 CPU，显著降低耗电。
    //   当设备因用户亮屏/解锁而变为可运行时，过期的非唤醒 alarm 会立刻补投递，从而仍能及时识别 unlock 跃迁。
    // - wakeup=true：仅用于极少数需要在设备休眠时也强制执行的场景（不推荐，耗电更高）。
    // - preferExact=true：仅在 wakeup=true 且系统允许 exact alarms 时才会生效；否则自动降级。
    val canExact: Boolean = if (wakeup && preferExact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        try { am.canScheduleExactAlarms() } catch (_: Throwable) { false }
      } else {
        true
      }
    } else {
      false
    }

    if (!wakeup) {
      // 非唤醒：只要到了设备可运行的时机就会回调，不主动唤醒 CPU。
      try {
        am.set(alarmType, triggerAt, pi)
        scheduled = true
      } catch (_: Throwable) {
        scheduled = false
      }
    } else {
      // 唤醒：Doze / App Standby 下普通 alarm 可能被推迟；AllowWhileIdle 仍会被系统节流。
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        if (preferExact && canExact) {
          try {
            am.setExactAndAllowWhileIdle(alarmType, triggerAt, pi)
            scheduled = true
          } catch (_: SecurityException) {
            scheduled = false
          } catch (_: Throwable) {
            scheduled = false
          }
        }
        if (!scheduled) {
          try {
            am.setAndAllowWhileIdle(alarmType, triggerAt, pi)
            scheduled = true
          } catch (_: Throwable) {
            scheduled = false
          }
        }
      } else {
        if (preferExact && canExact) {
          try {
            am.setExact(alarmType, triggerAt, pi)
            scheduled = true
          } catch (_: SecurityException) {
            scheduled = false
          } catch (_: Throwable) {
            scheduled = false
          }
        }
        if (!scheduled) {
          try {
            am.set(alarmType, triggerAt, pi)
            scheduled = true
          } catch (_: Throwable) {
            scheduled = false
          }
        }
      }
    }

    if (scheduled) {
      try {
        app.getSharedPreferences(PREF, Context.MODE_PRIVATE)
          .edit()
          .putLong(KEY_LAST_SCHEDULED, System.currentTimeMillis())
          .apply()
      } catch (_: Throwable) {}
    }
  } catch (_: Throwable) {}
}

  internal fun pendingIntent(ctx: Context): PendingIntent {
    val i = Intent(ctx, UnlockPulseReceiver::class.java).apply {
      action = ACTION
    }
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    return PendingIntent.getBroadcast(ctx, RC, i, flags)
  }

  internal fun pendingIntentAnchor(ctx: Context): PendingIntent {
    val i = Intent(ctx, UnlockPulseReceiver::class.java).apply {
      action = ACTION_ANCHOR
    }
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    return PendingIntent.getBroadcast(ctx, RC_ANCHOR, i, flags)
  }

  internal fun hasPendingIntent(ctx: Context): Boolean {
    return try {
      val i = Intent(ctx, UnlockPulseReceiver::class.java).apply { action = ACTION }
      val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
      PendingIntent.getBroadcast(ctx, RC, i, flags) != null
    } catch (_: Throwable) { false }
  }


  /** 判断是否需要启用脉冲：解锁轻提醒开关 or 地点规则开关 */
  internal fun shouldEnable(ctx: Context): Boolean {
    val app = ctx.applicationContext
    val sp = try { app.getSharedPreferences(PREF, Context.MODE_PRIVATE) } catch (_: Throwable) { null }
    val hasCached = try { sp?.contains(KEY_ENABLED_CACHED) ?: false } catch (_: Throwable) { false }
    val cached = try { if (hasCached) sp?.getBoolean(KEY_ENABLED_CACHED, false) else null } catch (_: Throwable) { null }

    val now = System.currentTimeMillis()
    val cachedTs = try { sp?.getLong(KEY_ENABLED_CACHED_TS, 0L) ?: 0L } catch (_: Throwable) { 0L }
    val cacheFresh = (cached != null) && (cachedTs > 0L) && ((now - cachedTs) < ENABLE_CACHE_TTL_MS)
    if (cacheFresh) return cached!!

    // 先尝试从 DB 读取（更准确）
    val fromDb = readShouldEnableFromDbOrNull(app)
    if (fromDb != null) {
      try {
        sp?.edit()
          ?.putBoolean(KEY_ENABLED_CACHED, fromDb)
          ?.putLong(KEY_ENABLED_CACHED_TS, System.currentTimeMillis())
          ?.apply()
      } catch (_: Throwable) {}
      return fromDb
    }

    // DB 读取失败时回退到缓存，避免“后台偶发 DB 打不开 -> 直接 cancel 脉冲”导致完全不触发
    if (cached != null) return cached

    // 首次运行且 DB 仍不可读：保守地保持脉冲开启（只做轻量状态检查，不取定位），避免漏提醒。
    return true
  }

  /**
   * 尽量一次性从业务 DB 读取两个开关，并返回「是否启用脉冲」。
   *
   * 返回值：
   * - true/false: 成功读取到至少一个开关（并据此给出判定）
   * - null: DB 路径不可得、DB 打不开或两个查询都失败（此时 shouldEnable() 会回退到缓存）
   */
  private fun readShouldEnableFromDbOrNull(ctx: Context): Boolean? {
    val app = ctx.applicationContext
    val cc = try { DbInspector.loadOrLightScan(app) } catch (_: Throwable) { null } ?: return null
    val path = cc.dbPath

    var db: SQLiteDatabase? = null
    try {
      db = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY)
    } catch (_: Throwable) {
      db = null
    }
    if (db == null) return null

    var unlockEnabled: Boolean? = null
    var geoEnabled: Boolean? = null
    try {
      try {
        db.rawQuery("SELECT value FROM notify_config WHERE key='unlock_switch_enabled' LIMIT 1", null).use { c ->
          if (c.moveToFirst()) {
            val v = c.getString(0)
            val s = v?.trim()?.lowercase() ?: ""
            unlockEnabled = (s == "1" || s == "true")
          } else {
            unlockEnabled = false
          }
        }
      } catch (_: Throwable) {
        // keep null
      }

      try {
        db.rawQuery("SELECT location_rules_enabled FROM configs LIMIT 1", null).use { c ->
          if (c.moveToFirst()) {
            geoEnabled = (c.getInt(0) == 1)
          } else {
            geoEnabled = false
          }
        }
      } catch (_: Throwable) {
        // keep null
      }

      if (unlockEnabled == null && geoEnabled == null) return null
      return (unlockEnabled == true) || (geoEnabled == true)
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
  }

  private fun isUnlockLightEnabled(ctx: Context): Boolean {
    val app = ctx.applicationContext
    val cc = try { DbInspector.loadOrLightScan(app) } catch (_: Throwable) { null }
    val path = cc?.dbPath ?: return false

    var db: SQLiteDatabase? = null
    try {
      db = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY)
    } catch (_: Throwable) {
      db = null
    }
    if (db == null) return false

    try {
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
      return enabled
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
  }

  internal fun getLastLocked(ctx: Context): Boolean {
    return try {
      ctx.applicationContext.getSharedPreferences(PREF, Context.MODE_PRIVATE)
        .getBoolean(KEY_LAST_LOCKED, false)
    } catch (_: Throwable) { false }
  }

  internal fun getLastPulseElapsed(ctx: Context): Long {
    return try {
      ctx.applicationContext.getSharedPreferences(PREF, Context.MODE_PRIVATE)
        .getLong(KEY_LAST_PULSE_ELAPSED, 0L)
    } catch (_: Throwable) { 0L }
  }

  internal fun setLastPulseElapsed(ctx: Context, v: Long) {
    try {
      ctx.applicationContext.getSharedPreferences(PREF, Context.MODE_PRIVATE)
        .edit().putLong(KEY_LAST_PULSE_ELAPSED, v).apply()
    } catch (_: Throwable) {}
  }

  internal fun getLastHeartbeatWall(ctx: Context): Long {
    return try {
      ctx.applicationContext.getSharedPreferences(PREF, Context.MODE_PRIVATE)
        .getLong(KEY_LAST_HEARTBEAT_WALL, 0L)
    } catch (_: Throwable) { 0L }
  }

  internal fun setLastHeartbeatWall(ctx: Context, v: Long) {
    try {
      ctx.applicationContext.getSharedPreferences(PREF, Context.MODE_PRIVATE)
        .edit().putLong(KEY_LAST_HEARTBEAT_WALL, v).apply()
    } catch (_: Throwable) {}
  }

  internal fun setLastLocked(ctx: Context, v: Boolean) {
    try {
      ctx.applicationContext.getSharedPreferences(PREF, Context.MODE_PRIVATE)
        .edit().putBoolean(KEY_LAST_LOCKED, v).apply()
    } catch (_: Throwable) {}
  }

  internal fun logWithTime(ctx: Context, msg: String) {
    // 既写入 DB 日志，也写入 logcat，便于你验证“脉冲是否真的在跑”。
    try { Log.i("UnlockPulse", msg) } catch (_: Throwable) {}
    try {
      val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault())
      val now = sdf.format(java.util.Date())
      DbRepo.log(ctx, "_SYS_", "[$now] $msg")
    } catch (_: Throwable) {
      try { DbRepo.log(ctx, "_SYS_", msg) } catch (_: Throwable) {}
    }
  }
}
