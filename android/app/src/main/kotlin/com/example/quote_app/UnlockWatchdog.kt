package com.example.quote_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import com.example.quote_app.data.DbRepo

/**
 * 解锁链路延迟兜底（<= 5 分钟）：
 * - 由 SCREEN_ON 触发调度；在用户解锁前后某些 ROM 可能丢 USER_PRESENT 或延后处理。
 * - 仅在本次亮屏/解锁窗口内工作，不是周期性任务。
 * - 若 USER_PRESENT/探测链路已成功触发，则会取消该兜底。
 */
object UnlockWatchdog {
  private const val ACTION = "com.example.quote_app.ACTION_UNLOCK_WATCHDOG"
  private const val RC = 4407
  private const val EXTRA_STARTED_AT = "started_at"
  private const val EXTRA_ATTEMPT = "attempt"
  private const val WINDOW_MS = 5 * 60 * 1000L

  /** 在 SCREEN_ON 时调用：先做短探测，若仍锁屏则启动 5 分钟内的兜底探测。 */
  fun scheduleFromScreenOn(ctx: Context) {
    val app = ctx.applicationContext
    val now = System.currentTimeMillis()

    // 记录本轮窗口起点，供兜底判断；不影响业务冷却逻辑。
    try {
      app.getSharedPreferences("quote_prefs", Context.MODE_PRIVATE)
        .edit()
        .putLong("watchdog_window_start_ts", now)
        .apply()
    } catch (_: Throwable) {}

    // 第一次兜底检查延迟：5 秒（避免与 0~3 秒的快速探测重叠）
    schedule(app, startedAt = now, attempt = 0, delayMs = 5000L)
  }

  /** 在 USER_PRESENT 或探测确认已解锁并触发业务后调用：取消兜底。 */
  fun cancel(ctx: Context) {
    val app = ctx.applicationContext
    try {
      val am = app.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
      am?.cancel(pendingIntent(app, startedAt = 0L, attempt = 0))
    } catch (_: Throwable) {}
  }

  fun windowMs(): Long = WINDOW_MS

  internal fun schedule(ctx: Context, startedAt: Long, attempt: Int, delayMs: Long) {
    val app = ctx.applicationContext
    try {
      val am = app.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
      val triggerAt = SystemClock.elapsedRealtime() + delayMs
      val pi = pendingIntent(app, startedAt, attempt)

      // 尽量保证在 Doze/待机下也能在 5 分钟窗口内运行。
      // Android 12+ exact alarms 可能受用户开关影响；若无法调度 exact，则降级为 allowWhileIdle。
      val canExact = if (Build.VERSION.SDK_INT >= 31) {
        try { am.canScheduleExactAlarms() } catch (_: Throwable) { true }
      } else {
        true
      }
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        if (canExact) {
          am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
        } else {
          am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
          logWithTime(app, "【解锁兜底】无法调度 exact alarm，已降级为 allowWhileIdle（回包：DEGRADED）")
        }
      } else {
        @Suppress("DEPRECATION")
        am.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
      }
    } catch (_: Throwable) {}
  }

  internal fun pendingIntent(ctx: Context, startedAt: Long, attempt: Int): PendingIntent {
    val i = Intent(ctx, UnlockWatchdogReceiver::class.java).apply {
      action = ACTION
      putExtra(EXTRA_STARTED_AT, startedAt)
      putExtra(EXTRA_ATTEMPT, attempt)
    }
    val flags = (PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    return PendingIntent.getBroadcast(ctx, RC, i, flags)
  }

  internal fun parseStartedAt(i: Intent?): Long = try { i?.getLongExtra(EXTRA_STARTED_AT, 0L) ?: 0L } catch (_: Throwable) { 0L }
  internal fun parseAttempt(i: Intent?): Int = try { i?.getIntExtra(EXTRA_ATTEMPT, 0) ?: 0 } catch (_: Throwable) { 0 }

  internal fun logWithTime(ctx: Context, msg: String) {
    try {
      val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault())
      val now = sdf.format(java.util.Date())
      DbRepo.log(ctx, null, "[$now] $msg")
    } catch (_: Throwable) {
      try { DbRepo.log(ctx, null, msg) } catch (_: Throwable) {}
    }
  }
}
