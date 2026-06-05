package com.example.quote_app

import android.app.KeyguardManager
import android.content.Context
import android.os.PowerManager
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.WorkManager
import com.example.quote_app.data.DbRepo
import java.util.concurrent.TimeUnit

/**
 * WorkManager 兜底任务：用于在系统长时间待机/ROM 冻结/清理后台后，
 * 尽量恢复 UnlockPulse 的 Alarm 调度。
 *
 * 重要：
 * - 该 Worker 不做定位、不做通知，只做“轻量恢复调度”；
 * - 即使被系统延迟也无妨，目标是防止“脉冲链路彻底断掉”。
 */

class AlarmProxyWorker(appContext: Context, params: WorkerParameters) : Worker(appContext, params) {
  override fun doWork(): Result {
    val ctx = applicationContext
    val job = try { inputData.getString("job") ?: "wm_unknown" } catch (_: Throwable) { "wm_unknown" }
    val reason = try { inputData.getString("reason") ?: "unknown" } catch (_: Throwable) { "unknown" }
    val startedAtWall = try { inputData.getLong("startedAtWall", 0L) } catch (_: Throwable) { 0L }
    val attempt = try { inputData.getInt("attempt", 0) } catch (_: Throwable) { 0 }
    try {
      when (job) {
        JOB_PULSE_REARM -> {
          // 历史版本可能遗留周期 GeoWorker；按需求此处保持清理，避免误触发。
          try { GeoWorker.cancel(ctx) } catch (_: Throwable) {}
          // 关键：确保 UnlockPulse 仍被调度（若开关开启）。
          try { UnlockPulse.ensureScheduledIfNeeded(ctx) } catch (_: Throwable) {}
          // 记录一次轻量日志，便于排查“被清理后是否有恢复尝试”。
          logWithTime(ctx, "【WM兜底】doWork job=$job -> ensureScheduledIfNeeded done")
        }

        JOB_UNLOCK_NUDGE -> {
          doUnlockNudge(ctx, reason, startedAtWall, attempt)
        }

        else -> {
          // 未知 job：保持向后兼容，按“rearm”处理。
          try { UnlockPulse.ensureScheduledIfNeeded(ctx) } catch (_: Throwable) {}
          logWithTime(ctx, "【WM兜底】doWork job=$job(unknown) -> fallback rearm done")
        }
      }
    } catch (t: Throwable) {
      try { logWithTime(ctx, "【WM兜底】doWork 异常 job=$job：" + (t.message ?: "unknown")) } catch (_: Throwable) {}
    }
    return Result.success()
  }

  private fun doUnlockNudge(ctx: Context, reason: String, startedAtWall: Long, attempt: Int) {
    // 仅在相关开关开启时才运行（避免无意义唤醒）
    if (!UnlockPulse.shouldEnable(ctx)) {
      logWithTime(ctx, "【WM解锁兜底】开关关闭，跳过（reason=$reason，回包：SKIP_DISABLED）")
      return
    }

    val app = ctx.applicationContext
    val pm = app.getSystemService(Context.POWER_SERVICE) as? PowerManager
    val km = app.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager

    val interactive = try { pm?.isInteractive ?: false } catch (_: Throwable) { false }
    val locked = try { km?.isKeyguardLocked ?: true } catch (_: Throwable) { true }
    val nowLocked = (!interactive) || locked

    // 若仍锁屏，则在短窗口内退避重试：尽量“解锁后几秒内”补上链路
    val now = System.currentTimeMillis()
    val started = if (startedAtWall > 0L) startedAtWall else now
    val elapsed = now - started
    if (nowLocked) {
      if (elapsed <= 20_000L && attempt < 10) {
        val nextDelay = when {
          attempt <= 1 -> 800L
          attempt <= 3 -> 1200L
          attempt <= 6 -> 2000L
          else -> 3000L
        }
        logWithTime(ctx, "【WM解锁兜底】仍锁屏，将在${nextDelay}ms 后再探测（attempt=$attempt reason=$reason 回包：WAIT）")
        enqueueUnlockNudge(app, reason = reason, startedAtWall = started, attempt = attempt + 1, delayMs = nextDelay)
      } else {
        logWithTime(ctx, "【WM解锁兜底】锁屏探测超时，结束（attempt=$attempt reason=$reason 回包：TIMEOUT）")
      }
      return
    }

    // 若已有主链路正在执行/刚执行完成，则不重复跑，避免地点规则重复提醒
    val inflightTs = try { UnlockEventHandler.getUnlockChainInflightTs(app) } catch (_: Throwable) { 0L }
    val doneTs = try { UnlockEventHandler.getUnlockChainDoneTs(app) } catch (_: Throwable) { 0L }
    if (inflightTs > 0L && (now - inflightTs) <= 25_000L) {
      // 主链路正在跑：稍后再看一次
      if (attempt < 6 && elapsed <= 30_000L) {
        logWithTime(ctx, "【WM解锁兜底】检测到主链路正在执行(inflightTs=$inflightTs)，5s 后再试（attempt=$attempt reason=$reason 回包：INFLIGHT）")
        enqueueUnlockNudge(app, reason = reason, startedAtWall = started, attempt = attempt + 1, delayMs = 5000L)
      }
      return
    }
    if (doneTs > 0L && (now - doneTs) <= 25_000L && doneTs >= started) {
      logWithTime(ctx, "【WM解锁兜底】主链路已完成(doneTs=$doneTs)，跳过（reason=$reason 回包：SKIP_DONE）")
      return
    }

    // 执行一次解锁链路（作为兜底，优先保证“解锁后可收到提醒”）
    try {
      UnlockEventHandler.markUnlockChainInflight(app, source = "wm:$reason")
      logWithTime(ctx, "【WM解锁兜底】检测到已解锁，执行解锁链路（attempt=$attempt reason=$reason 回包：OK）")
      UnlockEventHandler.withHighPriority(app, "wm:$reason") {
        try { UnlockEventHandler.handleUnlockLightReminder(app, source = "wm:$reason") } catch (_: Throwable) {}
        try { GeoUnlockOrchestrator.run(app, "wm:$reason") } catch (_: Throwable) {}
      }
    } finally {
      try { UnlockEventHandler.markUnlockChainDone(app, source = "wm:$reason") } catch (_: Throwable) {}
    }
  }

  companion object {
    const val JOB_PULSE_REARM = "wm_pulse_rearm"
    const val JOB_UNLOCK_NUDGE = "wm_unlock_nudge"

    private const val UNIQUE_UNLOCK_WORK = "wm_unlock_nudge_unique"

    fun enqueueUnlockNudge(ctx: Context, reason: String, startedAtWall: Long, attempt: Int, delayMs: Long) {
      val app = ctx.applicationContext
      try {
        val data = Data.Builder()
          .putString("job", JOB_UNLOCK_NUDGE)
          .putString("reason", reason)
          .putLong("startedAtWall", startedAtWall)
          .putInt("attempt", attempt)
          .build()

        val builder = OneTimeWorkRequestBuilder<AlarmProxyWorker>()
          .setInputData(data)
          // 尽量优先执行；若超出配额则降级为普通 work（不使用前台通知）。
          .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)

        if (delayMs > 0L) {
          builder.setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
        }

        val req = builder.build()
        WorkManager.getInstance(app)
          .enqueueUniqueWork(UNIQUE_UNLOCK_WORK, ExistingWorkPolicy.REPLACE, req)
      } catch (_: Throwable) {
        // ignore
      }
    }
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