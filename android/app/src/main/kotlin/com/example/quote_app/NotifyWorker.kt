package com.example.quote_app

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
// WorkManager import removed; cancellation handled via WmScheduler
import com.example.quote_app.schedule.AutoRescheduler
import com.example.quote_app.wm.WmScheduler
import com.example.quote_app.wm.WmNames
import com.example.quote_app.biz.Biz
import org.json.JSONObject
class NotifyWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
  override suspend fun doWork(): Result {
    val id = inputData.getInt("id", 0)
    val payload = inputData.getString("payload") ?: "{}"
    val obj = try { JSONObject(payload) } catch (_: Throwable) { JSONObject() }
    val uid = obj.optString("uid", "")
    val runKey = obj.optString("runKey", "")
    // use unified channel name for fallback
    val chan = "fallback-wm"

    if (uid.isEmpty()) return Result.success()

    var entered = false
    try {
      entered = com.example.quote_app.data.DbRepo.runGuardBegin(applicationContext, uid, runKey, chan)
      if (!entered) return Result.success()

      val handled = Biz.run(applicationContext, uid)
      if (handled) {
        // 业务成功：标记成功并续排下一次任务
        com.example.quote_app.data.DbRepo.markLatestSuccess(applicationContext, uid)
        try {
          // 使用统一的自动续排逻辑计算并注册下一次运行（AM/WM 兼容）
          AutoRescheduler.scheduleNext(applicationContext, uid)
        } catch (_: Throwable) {}
        // 取消当前兜底任务以避免重复触发
        try {
          val fbUnique = WmNames.fbUnique(uid, runKey)
          WmScheduler.cancelFallback(applicationContext, fbUnique)
        } catch (_: Throwable) {}
        return Result.success()
      } else {
        com.example.quote_app.data.DbRepo.log(applicationContext, uid, "WM兜底：业务未处理")
        return Result.retry()
      }
    } catch (t: Throwable) {
      com.example.quote_app.data.DbRepo.log(applicationContext, uid, "WM兜底异常: " + (t.message ?: "未知错误"))
      return Result.retry()
    } finally {
      try { com.example.quote_app.data.DbRepo.runGuardEnd(applicationContext, uid, runKey, chan) } catch (_: Throwable) {}
    }
  }
}