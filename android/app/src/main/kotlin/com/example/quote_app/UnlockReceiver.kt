package com.example.quote_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.KeyguardManager
import com.example.quote_app.data.DbRepo
import kotlin.concurrent.thread

/**
 * 解锁广播入口（高优先级/低延迟版）：
 * - 不再依赖 WorkManager（部分机型会延迟到数分钟甚至更久）。
 * - 在后台线程中直接完成（避免长时间占用 goAsync 导致广播 ANR）：
 *   1) 解锁轻提醒（若开关开启且不在冷却期）
 *   2) 方案B地点规则（快路径系统定位 -> 必要时短前台服务兜底）
 * - 通过 3 秒窗口去重，避免 USER_PRESENT 与 SCREEN_ON 探测双触发。
 */
class UnlockReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    val app = context.applicationContext
    val pending = goAsync()
    thread(name = "unlock-receiver") {
      try {
        val action = intent?.action ?: "unknown"

        // 额外保护：部分机型/系统版本可能出现 USER_PRESENT 触发时机异常。
        // 若此刻仍处于锁定状态，则不触发提醒（避免误触发/被恶意广播模拟）。
        try {
          val km = app.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
          val locked = try { km?.isKeyguardLocked ?: true } catch (_: Throwable) { true }
          if (locked) {
            logWithTime(app, "【解锁后台】收到解锁广播($action) 但仍处于锁屏状态，忽略（回包：SKIP_LOCKED）")
            return@thread
          }
        } catch (_: Throwable) {
          // ignore
        }

        val now = System.currentTimeMillis()

        // 主链路短窗口去重：避免 USER_PRESENT / SCREEN_ON 探测 / pulse 等入口并发导致重复通知
        val inflightTs = try { UnlockEventHandler.getUnlockChainInflightTs(app) } catch (_: Throwable) { 0L }
        if (inflightTs > 0L && (now - inflightTs) < 15_000L) {
          logWithTime(app, "【解锁后台】检测到主链路正在执行，15 秒内跳过重复（action=$action 回包：SKIP_CHAIN_INFLIGHT）")
          try { UnlockWatchdog.cancel(app) } catch (_: Throwable) {}
          return@thread
        }
        val doneTs = try { UnlockEventHandler.getUnlockChainDoneTs(app) } catch (_: Throwable) { 0L }
        if (doneTs > 0L && (now - doneTs) < 15_000L) {
          logWithTime(app, "【解锁后台】检测到主链路刚完成，15 秒内跳过重复（action=$action 回包：SKIP_CHAIN_DONE）")
          try { UnlockWatchdog.cancel(app) } catch (_: Throwable) {}
          return@thread
        }

        val sp = app.getSharedPreferences("quote_prefs", Context.MODE_PRIVATE)
        val last = sp.getLong("last_unlock_trigger_ts", 0L)
        if (last > 0 && (now - last) < 15_000L) {
          logWithTime(app, "【解锁后台】收到解锁广播($action) 但 15 秒内已触发过，跳过重复（回包：SKIP_DUP）")
          try { UnlockWatchdog.cancel(app) } catch (_: Throwable) {}
          return@thread
        }
        sp.edit()
          .putLong("last_unlock_trigger_ts", now)
          .putLong("last_user_present_ts", now)
          .apply()

        // 已收到 USER_PRESENT（或等价广播）并开始执行业务：取消 5 分钟兜底。
        try { UnlockWatchdog.cancel(app) } catch (_: Throwable) {}

        logWithTime(app, "【解锁后台】收到解锁广播($action)，开始执行高优先级解锁链路（回包：OK）")

        // 高优先级执行：加 WakeLock + 提升线程优先级，尽量避免被系统延后
        try {
          UnlockEventHandler.markUnlockChainInflight(app, source = "unlock:$action")
          UnlockEventHandler.withHighPriority(app, "unlock:$action") {
            // 1) 轻提醒：直接处理，避免 WorkManager 延迟
            try { UnlockEventHandler.handleUnlockLightReminder(app, source = "unlock:$action") } catch (t: Throwable) {
              logWithTime(app, "【解锁后台】轻提醒处理失败：" + (t.message ?: "unknown"))
            }

            // 2) 地点规则：方案B（快路径 -> 必要时前台兜底）
            try { GeoUnlockOrchestrator.run(app, "unlock:$action") } catch (t: Throwable) {
              logWithTime(app, "【解锁后台】触发 GeoUnlockOrchestrator 失败：" + (t.message ?: "unknown"))
            }
          }
        } finally {
          try { UnlockEventHandler.markUnlockChainDone(app, source = "unlock:$action") } catch (_: Throwable) {}
        }
      } catch (t: Throwable) {
        try {
          logWithTime(app, "【解锁后台】UnlockReceiver 异常：" + (t.message ?: "unknown"))
        } catch (_: Throwable) {}
      } finally {
        try { pending.finish() } catch (_: Throwable) {}
      }
    }
  }

  /** 写入包含时间戳的中文日志。 */
  private fun logWithTime(ctx: Context, msg: String) {
    try {
      val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault())
      val now = sdf.format(java.util.Date())
      DbRepo.log(ctx, null, "[$now] $msg")
    } catch (_: Throwable) {
      try { DbRepo.log(ctx, null, msg) } catch (_: Throwable) {}
    }
  }
}
