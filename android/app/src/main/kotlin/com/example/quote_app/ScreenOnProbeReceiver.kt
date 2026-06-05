package com.example.quote_app

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.example.quote_app.data.DbRepo

/**
 * 兜底：监听 SCREEN_ON，延迟检查是否已解锁（无锁屏/智能解锁等）。
 * 只有确认“已解锁”时，才触发：
 * 1) 解锁轻提醒（直接执行，避免 WorkManager 延迟）
 * 2) 方案B地点规则（快路径 -> 必要时前台兜底）
 * 同时做 3 秒去重，避免与 USER_PRESENT 双触发。
 */
class ScreenOnProbeReceiver : BroadcastReceiver() {

  override fun onReceive(context: Context, intent: Intent?) {
    if (intent?.action != Intent.ACTION_SCREEN_ON) return

    val app = context.applicationContext

    // 记录最近一次亮屏时间：用于后续“漏/延迟解锁事件”的诊断与兜底判断。
    try {
      app.getSharedPreferences("quote_prefs", Context.MODE_PRIVATE)
        .edit()
        .putLong("last_screen_on_ts", System.currentTimeMillis())
        .apply()
    } catch (_: Throwable) {}

    // 额外兜底：立刻请求一次 WorkManager（短窗口探测解锁状态）。
    // 目的：当本次 SCREEN_ON 触发后，进程很快被系统回收/挂起时，仍尽量在后续数秒内完成一次解锁链路。
    // 注意：该 Work 在短窗口内自退避重试，不是周期任务，电量影响很小。
    try {
      val now = System.currentTimeMillis()
      AlarmProxyWorker.enqueueUnlockNudge(app, reason = "screen_on", startedAtWall = now, attempt = 0, delayMs = 1200L)
    } catch (_: Throwable) {}
    // 重要：不要在 BroadcastReceiver 中长时间占用 goAsync()。
    // 部分 ROM/系统版本对广播处理时间非常严格（约 10s），
    // 若未及时 finish 会触发“Broadcast of SCREEN_ON” ANR 并被系统杀进程。

    // 5 分钟窗口兜底：防止 USER_PRESENT 丢失或系统延后处理导致“解锁后长时间无提醒”。
    // 仅在本次亮屏/解锁窗口内工作，不是周期任务。
    try {
      UnlockWatchdog.cancel(app)
      UnlockWatchdog.scheduleFromScreenOn(app)
    } catch (_: Throwable) {}

    try { logWithTime(app, "【解锁后台-探测】收到 SCREEN_ON，600ms 后检查是否已解锁（回包：PROBE）") } catch (_: Throwable) {}

    val km = app.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager

    val h = Handler(Looper.getMainLooper())

    fun checkUnlocked(attempt: Int) {
      try {
        val isLocked = try { km.isKeyguardLocked } catch (_: Throwable) { true }
        if (isLocked) {
          // 某些机型/系统版本下 USER_PRESENT 可能不稳定/被拦截。
          // 为了保证“亮屏 -> 解锁”场景的实时性，这里在短窗口内继续探测。
          if (attempt == 0) {
            try { logWithTime(app, "【解锁后台-探测】SCREEN_ON 后仍处于上锁状态，将继续探测解锁（回包：WAIT_PROBE）") } catch (_: Throwable) {}
          }
          if (attempt >= 18) {
            try { logWithTime(app, "【解锁后台-探测】探测超时仍未解锁，结束（回包：TIMEOUT）") } catch (_: Throwable) {}
            return
          }
          // 快速探测窗口（约 15 秒）：
          // - 前 8 次用更密集的递增探测
          // - 之后用 1s 间隔探测，覆盖用户输入密码/指纹失败重试等场景
          val nextDelay = if (attempt < 8) {
            200L + (attempt * 100L)
          } else {
            1000L
          }
          h.postDelayed({ checkUnlocked(attempt + 1) }, nextDelay)
          return
        }

        // 去重：15 秒窗口内若已触发过解锁链路，则跳过
        val now = System.currentTimeMillis()

        // 主链路短窗口去重：避免 SCREEN_ON 探测 与 pulse/USER_PRESENT 等入口并发导致重复通知。
        val inflightTs = try { UnlockEventHandler.getUnlockChainInflightTs(app) } catch (_: Throwable) { 0L }
        if (inflightTs > 0L && (now - inflightTs) < 15_000L) {
          try { logWithTime(app, "【解锁后台-探测】检测到主链路正在执行，15 秒内跳过重复（回包：SKIP_CHAIN_INFLIGHT）") } catch (_: Throwable) {}
          return
        }
        val doneTs = try { UnlockEventHandler.getUnlockChainDoneTs(app) } catch (_: Throwable) { 0L }
        if (doneTs > 0L && (now - doneTs) < 15_000L) {
          try { logWithTime(app, "【解锁后台-探测】检测到主链路刚完成，15 秒内跳过重复（回包：SKIP_CHAIN_DONE）") } catch (_: Throwable) {}
          return
        }

        val sp = app.getSharedPreferences("quote_prefs", Context.MODE_PRIVATE)
        val last = sp.getLong("last_unlock_trigger_ts", 0L)
        if (last > 0 && (now - last) < 15_000L) {
          try { logWithTime(app, "【解锁后台-探测】15 秒内已触发过解锁链路，跳过重复（回包：SKIP_DUP）") } catch (_: Throwable) {}
          return
        }

        sp.edit()
          .putLong("last_unlock_trigger_ts", now)
          .putLong("last_user_present_ts", now)
          .apply()

        // 已确认解锁并即将执行业务：取消 5 分钟兜底
        try { UnlockWatchdog.cancel(app) } catch (_: Throwable) {}

        try { logWithTime(app, "【解锁后台-探测】检测到未上锁，判定为已解锁，执行高优先级解锁链路（回包：OK）") } catch (_: Throwable) {}

        // 重要：不要在主线程执行数据库/定位等耗时逻辑，避免卡顿与丢回调
        kotlin.concurrent.thread(name = "screen-on-probe") {
          try {
            try { UnlockEventHandler.markUnlockChainInflight(app, source = "screen_on_probe") } catch (_: Throwable) {}
            UnlockEventHandler.withHighPriority(app, "screen_on_probe") {
              try { UnlockEventHandler.handleUnlockLightReminder(app, source = "screen_on_probe") } catch (t: Throwable) {
                try { logWithTime(app, "【解锁后台-探测】轻提醒处理失败：" + (t.message ?: "unknown")) } catch (_: Throwable) {}
              }
              try { GeoUnlockOrchestrator.run(app, "screen_on_probe") } catch (t: Throwable) {
                try { logWithTime(app, "【解锁后台-探测】触发 GeoUnlockOrchestrator 失败：" + (t.message ?: "unknown")) } catch (_: Throwable) {}
              }
            }
            try { UnlockEventHandler.markUnlockChainDone(app, source = "screen_on_probe") } catch (_: Throwable) {}
          } catch (t: Throwable) {
            try { logWithTime(app, "【解锁后台-探测】后台线程异常：" + (t.message ?: "unknown")) } catch (_: Throwable) {}
          }
        }
      } catch (t: Throwable) {
        try { logWithTime(app, "【解锁后台-探测】异常：" + (t.message ?: "unknown")) } catch (_: Throwable) {}
      }
    }

    // 首次延迟 600ms：给系统一点时间从 SCREEN_ON 进入解锁流程
    h.postDelayed({ checkUnlocked(0) }, 600)
  }

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
