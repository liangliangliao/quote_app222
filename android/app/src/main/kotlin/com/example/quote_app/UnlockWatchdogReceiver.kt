package com.example.quote_app

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlin.concurrent.thread

/**
 * 5 分钟窗口内的解锁兜底探测：
 * - 若仍锁屏，按退避策略继续调度下一次探测；
 * - 若已解锁但业务未触发，则立即执行高优先级解锁链路；
 * - 若窗口结束仍未解锁，则结束。
 */
class UnlockWatchdogReceiver : BroadcastReceiver() {

  override fun onReceive(context: Context, intent: Intent?) {
    val app = context.applicationContext
    thread(name = "unlock-watchdog") {
      try {
        val startedAt = UnlockWatchdog.parseStartedAt(intent)
        val attempt = UnlockWatchdog.parseAttempt(intent)

        if (startedAt <= 0L) {
          UnlockWatchdog.logWithTime(app, "【解锁兜底】参数缺失，结束（回包：BAD_ARGS）")
          return@thread
        }

        val now = System.currentTimeMillis()
        val elapsed = now - startedAt
        if (elapsed > UnlockWatchdog.windowMs()) {
          UnlockWatchdog.logWithTime(app, "【解锁兜底】超过 5 分钟窗口仍未完成解锁，结束（回包：TIMEOUT）")
          UnlockWatchdog.cancel(app)
          return@thread
        }

        // 已经由 USER_PRESENT/探测触发过则不再兜底
        val sp = app.getSharedPreferences("quote_prefs", Context.MODE_PRIVATE)
        val lastTrigger = sp.getLong("last_unlock_trigger_ts", 0L)
        if (lastTrigger >= startedAt) {
          UnlockWatchdog.logWithTime(app, "【解锁兜底】窗口内已触发过解锁链路，取消兜底（回包：SKIP_ALREADY）")
          UnlockWatchdog.cancel(app)
          return@thread
        }

        val km = app.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        val locked = try { km?.isKeyguardLocked ?: true } catch (_: Throwable) { true }

        if (locked) {
          // 仍锁屏：继续调度下一次探测（退避 + 限定窗口）
          val nextDelay = nextDelayMs(attempt)
          UnlockWatchdog.logWithTime(app, "【解锁兜底】仍处于锁屏状态，${nextDelay}ms 后再探测（attempt=$attempt，回包：WAIT）")
          UnlockWatchdog.schedule(app, startedAt = startedAt, attempt = attempt + 1, delayMs = nextDelay)
          return@thread
        }

        // 已解锁但业务未触发：执行高优先级链路
        val triggerNow = System.currentTimeMillis()
        sp.edit().putLong("last_unlock_trigger_ts", triggerNow).apply()
        UnlockWatchdog.logWithTime(app, "【解锁兜底】检测到已解锁但业务未触发，执行高优先级解锁链路（回包：OK）")
        UnlockWatchdog.cancel(app)

        try {
          try { UnlockEventHandler.markUnlockChainInflight(app, source = "watchdog") } catch (_: Throwable) {}
          UnlockEventHandler.withHighPriority(app, "watchdog") {
            try { UnlockEventHandler.handleUnlockLightReminder(app, source = "watchdog") } catch (_: Throwable) {}
            try { GeoUnlockOrchestrator.run(app, "watchdog") } catch (_: Throwable) {}
          }
        } finally {
          try { UnlockEventHandler.markUnlockChainDone(app, source = "watchdog") } catch (_: Throwable) {}
        }
      } catch (t: Throwable) {
        try { UnlockWatchdog.logWithTime(app, "【解锁兜底】异常：" + (t.message ?: "unknown")) } catch (_: Throwable) {}
      }
    }
  }

  private fun nextDelayMs(attempt: Int): Long {
    // 退避策略：尽量在用户解锁后快速命中，同时控制总次数（<= 5min）。
    // 前 1 分钟：每 5 秒探测一次（提高解锁后“几秒内触发”的概率）
    // 之后逐步放缓，但仍保证 5 分钟窗口内可触发。
    return when {
      attempt <= 11 -> 5000L
      attempt <= 17 -> 15000L
      else -> 30000L
    }
  }
}
