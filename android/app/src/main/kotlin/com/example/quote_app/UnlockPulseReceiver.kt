package com.example.quote_app

import android.app.KeyguardManager
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import kotlin.concurrent.thread

/**
 * UnlockPulse 的回调接收器：
 * - 每次触发后自循环调度下一次（非 WorkManager）；
 * - 只在检测到“从锁屏->已解锁”的状态跃迁时触发业务；
 * - 其余时间只更新 lastLocked 状态。
 */
class UnlockPulseReceiver : BroadcastReceiver() {

  override fun onReceive(context: Context, intent: Intent?) {
    val app = context.applicationContext
    val pending = goAsync()
    thread(name = "unlock-pulse") {
      try {
        // 如果功能已关闭，则取消后续脉冲。
        if (!UnlockPulse.shouldEnable(app)) {
          UnlockPulse.logWithTime(app, "【解锁脉冲】功能已关闭，取消脉冲（回包：DISABLED）")
          UnlockPulse.cancel(app)
          return@thread
        }

        val pm = app.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val km = app.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager

        // 记录“脉冲回调是否长期没跑”的 gap：用于兜底判断。
        val nowElapsed = try { SystemClock.elapsedRealtime() } catch (_: Throwable) { 0L }
        val lastElapsed = try { UnlockPulse.getLastPulseElapsed(app) } catch (_: Throwable) { 0L }
        val gapMs = if (nowElapsed > 0L && lastElapsed > 0L) (nowElapsed - lastElapsed) else 0L
        try { UnlockPulse.setLastPulseElapsed(app, nowElapsed) } catch (_: Throwable) {}

        val interactive = try { pm?.isInteractive ?: false } catch (_: Throwable) { false }
        val locked = try { km?.isKeyguardLocked ?: true } catch (_: Throwable) { true }

        // 将“屏幕不亮/不可交互”也视为 locked，便于后续识别 unlock 跃迁。
        val nowLocked = (!interactive) || locked
        val lastLocked = UnlockPulse.getLastLocked(app)

        // 更新 lastLocked（先更新，避免并发）
        UnlockPulse.setLastLocked(app, nowLocked)

        val nowWall = System.currentTimeMillis()

        val sp = app.getSharedPreferences("quote_prefs", Context.MODE_PRIVATE)

        // 若 SCREEN_ON / USER_PRESENT 广播被系统延迟或忽略，脉冲可能是唯一入口。
        // 因此当检测到「从非交互 -> 交互」时，视为一次“亮屏”，记录 last_screen_on_ts 并请求一次短窗口 WorkManager 兜底。
        try {
          val lastInteractive = sp.getBoolean("unlock_pulse_last_interactive", false)
          if (!lastInteractive && interactive) {
            sp.edit().putLong("last_screen_on_ts", nowWall).apply()
            try {
              AlarmProxyWorker.enqueueUnlockNudge(app, reason = "pulse_screen_on", startedAtWall = nowWall, attempt = 0, delayMs = 1200L)
            } catch (_: Throwable) {}
          }
          sp.edit().putBoolean("unlock_pulse_last_interactive", interactive).apply()
        } catch (_: Throwable) {}

        // 自循环调度下一次：
        // - 屏幕不亮（interactive=false）：使用非唤醒 alarm 且短延迟（20s），不会为了探测而唤醒 CPU；
        //   当用户亮屏时若该 alarm 已过期，会立即补投递，及时进入解锁判定。
        // - 屏幕已亮但仍上锁：短间隔复查（5s），覆盖“广播延迟/漏投递”的场景
        // - 已解锁：降低频率（5min），降低后台开销
        val powerSave = try { pm?.isPowerSaveMode ?: false } catch (_: Throwable) { false }
        val nextDelay = when {
          !interactive -> if (powerSave) 60_000L else 20_000L
          nowLocked -> if (powerSave) 10_000L else 5_000L
          else -> if (powerSave) 10 * 60_000L else 5 * 60_000L
        }
        // 省电关键：默认使用非唤醒 alarm（wakeup=false），避免后台定时唤醒导致耗电。
        UnlockPulse.scheduleNext(app, delayMs = nextDelay, preferExact = false, wakeup = false)

        // 低频心跳日志（避免你在“日志表”里看不到任何动静，以为没生效）：
        // - 状态变化时记录
        // - 或每 10 分钟记录一次
        val lastHeartbeat = try { UnlockPulse.getLastHeartbeatWall(app) } catch (_: Throwable) { 0L }
        val shouldHeartbeat = (lastLocked != nowLocked) || (lastHeartbeat <= 0L) || ((nowWall - lastHeartbeat) > 10 * 60_000L)
        if (shouldHeartbeat) {
          try { UnlockPulse.setLastHeartbeatWall(app, nowWall) } catch (_: Throwable) {}

          val bucket = describeStandbyBucket(app)
          val ignoringOpt = try { pm?.isIgnoringBatteryOptimizations(app.packageName) ?: false } catch (_: Throwable) { false }
          UnlockPulse.logWithTime(
            app,
            "【解锁脉冲】tick interactive=$interactive keyguardLocked=$locked nowLocked=$nowLocked lastLocked=$lastLocked gapMs=$gapMs nextDelayMs=$nextDelay bucket=$bucket ignoreBattOpt=$ignoringOpt"
          )
        }

        // 触发条件：
        // A) 正常状态跃迁：locked -> unlocked
        // B) 兜底：脉冲长时间未回调（常见于 Doze/冻结），但当前已是 unlocked，则推断“刚刚发生过解锁”
        //    - 该兜底可以覆盖“锁屏期间 alarm 被系统延迟，导致 lastLocked 没来得及更新为 true”的场景。
        val transitionUnlock = lastLocked && !nowLocked
        val lastScreenOnTs = try { sp.getLong("last_screen_on_ts", 0L) } catch (_: Throwable) { 0L }
        val recentScreenOn = (lastScreenOnTs > 0L) && ((nowWall - lastScreenOnTs) < 2 * 60_000L)
        val gapUnlock = (!nowLocked) && (!lastLocked) && (gapMs >= 3 * 60_000L) && recentScreenOn
        if (transitionUnlock || gapUnlock) {
          // 主链路短窗口去重：避免与 SCREEN_ON 探测 / USER_PRESENT 并发导致重复通知
          val inflightTs = try { UnlockEventHandler.getUnlockChainInflightTs(app) } catch (_: Throwable) { 0L }
          if (inflightTs > 0L && (nowWall - inflightTs) < 15_000L) {
            UnlockPulse.logWithTime(app, "【解锁脉冲】检测到主链路正在执行，15 秒内跳过（回包：SKIP_CHAIN_INFLIGHT）")
            return@thread
          }
          val doneTs = try { UnlockEventHandler.getUnlockChainDoneTs(app) } catch (_: Throwable) { 0L }
          if (doneTs > 0L && (nowWall - doneTs) < 15_000L) {
            UnlockPulse.logWithTime(app, "【解锁脉冲】检测到主链路刚完成，15 秒内跳过（回包：SKIP_CHAIN_DONE）")
            return@thread
          }

          val lastTrigger = sp.getLong("last_unlock_trigger_ts", 0L)
          if (lastTrigger > 0 && (nowWall - lastTrigger) < 15_000L) {
            UnlockPulse.logWithTime(app, "【解锁脉冲】15 秒内已触发过解锁链路，跳过（回包：SKIP_DUP）")
            return@thread
          }
          // gapUnlock 可能发生在系统“补投递”多个延迟 alarm 的情况下，额外加一道更长的去重。
          if (gapUnlock && lastTrigger > 0 && (nowWall - lastTrigger) < 120_000L) {
            UnlockPulse.logWithTime(app, "【解锁脉冲】gapUnlock 2 分钟内已触发过，跳过（回包：SKIP_GAP_DUP）")
            return@thread
          }

          sp.edit().putLong("last_unlock_trigger_ts", nowWall).apply()

          // 已确认解锁并即将执行业务：取消 5 分钟窗口兜底（避免重复）
          try { UnlockWatchdog.cancel(app) } catch (_: Throwable) {}

          val reason = if (transitionUnlock) "TRANSITION" else "GAP"
          UnlockPulse.logWithTime(app, "【解锁脉冲】触发解锁链路 reason=$reason gapMs=$gapMs（回包：OK）")

          // 若是 gapUnlock（常见于系统延迟/冻结导致的“解锁事件丢/晚到”），额外请求一次 WorkManager 兜底。
          // 目的：当本次脉冲线程执行过程中被系统回收/挂起时，仍尽量在后续数秒内完成一次链路。
          if (gapUnlock) {
            try {
              val now = System.currentTimeMillis()
              AlarmProxyWorker.enqueueUnlockNudge(app, reason = "pulse_gap", startedAtWall = now, attempt = 0, delayMs = 1200L)
            } catch (_: Throwable) {}
          }

          try {
            try { UnlockEventHandler.markUnlockChainInflight(app, source = "pulse") } catch (_: Throwable) {}
            UnlockEventHandler.withHighPriority(app, "pulse") {
              try { UnlockEventHandler.handleUnlockLightReminder(app, source = "pulse") } catch (_: Throwable) {}
              try { GeoUnlockOrchestrator.run(app, "pulse") } catch (_: Throwable) {}
            }
          } finally {
            try { UnlockEventHandler.markUnlockChainDone(app, source = "pulse") } catch (_: Throwable) {}
          }
        }
      } catch (t: Throwable) {
        try { UnlockPulse.logWithTime(app, "【解锁脉冲】异常：" + (t.message ?: "unknown")) } catch (_: Throwable) {}
        // 异常时仍尽量保持脉冲链路不断：下一次 60s 再试
        try { UnlockPulse.scheduleNext(app, delayMs = 60_000L, preferExact = false, wakeup = false) } catch (_: Throwable) {}
      } finally {
        try { pending.finish() } catch (_: Throwable) {}
      }
    }
  }

  private fun describeStandbyBucket(ctx: Context): String {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return "n/a"
    return try {
      val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
      val b = usm?.appStandbyBucket ?: -1
      when (b) {
        UsageStatsManager.STANDBY_BUCKET_ACTIVE -> "ACTIVE"
        UsageStatsManager.STANDBY_BUCKET_WORKING_SET -> "WORKING_SET"
        UsageStatsManager.STANDBY_BUCKET_FREQUENT -> "FREQUENT"
        UsageStatsManager.STANDBY_BUCKET_RARE -> "RARE"
        UsageStatsManager.STANDBY_BUCKET_RESTRICTED -> "RESTRICTED"
        else -> b.toString()
      }
    } catch (_: Throwable) {
      "unknown"
    }
  }
}
