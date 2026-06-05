package com.example.quote_app

import android.content.Context
import android.location.Location
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.WorkManager
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.ExistingWorkPolicy
import androidx.work.OutOfQuotaPolicy
import androidx.work.Data
import com.example.quote_app.data.DbRepo
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * GeoWorker（保留兼容）：
 * - 旧版本曾使用 WorkManager 周期任务轮询定位并触发地点规则提醒。
 * - 当前版本已按需求“仅解锁触发提醒”禁用周期调度：不再创建任何周期 Work。
 * - 仍保留 OneTime 入口 triggerOnce（用于调试或极端兜底），但默认链路不再调用。
 */
class GeoWorker(appContext: Context, workerParams: WorkerParameters) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        val ctx = applicationContext
        // Gate: only run geo rules when the switch is enabled in configs.
        if (!GeoRuleEngine.isGeoEnabled(ctx)) {
            try { logWithTime(ctx, "[GeoWorker] 地点规则开关关闭，跳过本次检查（回包：SKIP_SWITCH_OFF）") } catch (_: Throwable) {}
            return Result.success()
        }

        val targets = GeoRuleEngine.loadTargets(ctx)
        if (targets.isEmpty()) return Result.success()

        try {
            // 统一定位顺序：系统高精度流 -> 百度SDK -> lastKnown
            var loc: Location? = runCatching { LocationCore.getSystemHighAcc(ctx, 80.0, 6_000L) }.getOrNull()
            if (loc != null) {
                try { logWithTime(ctx, "[GeoWorker] 系统高精度流定位成功 acc=${loc.accuracy}") } catch (_: Throwable) {}
            }

            if (loc == null) {
                // Baidu SDK 兜底（不走 IP 接口）
                val latch = CountDownLatch(1)
                var bd: Location? = null
                try {
                    BaiduLocator.getOnce(ctx, allowSystemFallback = false) { s ->
                        try {
                            if (s != null) {
                                val l = Location("baidu")
                                l.latitude = s.latitude
                                l.longitude = s.longitude
                                l.accuracy = s.accuracy
                                bd = l
                            }
                        } catch (_: Throwable) {}
                        latch.countDown()
                    }
                } catch (_: Throwable) {
                    latch.countDown()
                }
                try { latch.await(6, TimeUnit.SECONDS) } catch (_: Throwable) {}
                loc = bd
                if (loc != null) {
                    try { logWithTime(ctx, "[GeoWorker] 百度SDK定位成功 acc=${loc.accuracy}") } catch (_: Throwable) {}
                }
            }

            if (loc == null) {
                loc = LocationCore.getLastKnown(ctx)
                if (loc != null) {
                    try { logWithTime(ctx, "[GeoWorker] 使用最近已知位置 acc=${loc.accuracy}") } catch (_: Throwable) {}
                }
            }

            if (loc != null) {
                GeoRuleEngine.evaluateAndNotify(ctx, loc, targets, radiusMeters = 100.0)
            }
        } catch (_: Throwable) {
            // ignore
        }
        return Result.success()
    }

    /**
     * 统一在 GeoWorker 中写入带时间戳的日志，方便调试与排查。
     * 如果格式化时间失败，则回退到原始消息。
     */
    private fun logWithTime(ctx: Context, msg: String) {
        try {
            val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault())
            val now = sdf.format(java.util.Date())
            DbRepo.log(ctx, null, "[$now] $msg")
        } catch (_: Throwable) {
            try {
                DbRepo.log(ctx, null, msg)
            } catch (_: Throwable) {
                // ignore secondary failures
            }
        }
    }

    companion object {
        private const val UNIQUE_NAME = "vision_geo_worker"

        private const val UNIQUE_ONCE = "vision_geo_worker_once"

        /**
         * 立即触发一次性地点规则检查（用于解锁后尽快刷新）。
         * 使用 WorkManager expedited + unique work (REPLACE) 避免积压。
         */
        @JvmStatic
        fun triggerOnce(ctx: Context, reason: String? = null) {
            try {
                val data = Data.Builder().apply {
                    if (reason != null) putString("reason", reason)
                }.build()
                val req = OneTimeWorkRequestBuilder<GeoWorker>()
                    .setInputData(data)
                    .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                    .addTag(UNIQUE_NAME)
                    .addTag(UNIQUE_ONCE)
                    .build()
                WorkManager.getInstance(ctx.applicationContext)
                    .enqueueUniqueWork(UNIQUE_ONCE, ExistingWorkPolicy.REPLACE, req)
                try {
                    val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault())
                    val now = sdf.format(java.util.Date())
                    DbRepo.log(ctx, null, "[$now] 【GeoWorker】已触发一次性地点规则检查（回包：OK）")
                } catch (_: Throwable) {}
            } catch (_: Throwable) {
                try {
                    val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault())
                    val now = sdf.format(java.util.Date())
                    DbRepo.log(ctx, null, "[$now] 【GeoWorker】触发一次性地点规则检查失败（回包：FAIL）")
                } catch (_: Throwable) {}
            }
        }

        /**
         * ⚠️ 已禁用：周期性轮询定位会导致后台耗电/系统延迟/与“仅解锁触发提醒”的设计冲突。
         *
         * 现策略：
         * - 地点规则提醒只在「解锁屏幕事件」链路中触发（见 GeoUnlockOrchestrator）。
         * - 本方法保留仅用于兼容旧调用点，但不会再创建任何周期 WorkManager 任务。
         * - 同时会尝试取消历史版本遗留的周期任务，避免旧任务继续运行。
         */
        @JvmStatic
        fun schedule(context: Context) {
            try {
                // 清理旧版本可能遗留的周期任务
                WorkManager.getInstance(context.applicationContext)
                    .cancelUniqueWork(UNIQUE_NAME)
                DbRepo.log(context, null, "【GeoWorker】周期任务已禁用（已尝试取消历史遗留任务，回包：OK）")
            } catch (_: Throwable) { /* ignore */ }
        }

        /**
         * 取消周期性的 GeoWorker（用于地点规则开关关闭时彻底停止后台自动定位）。
         */
        @JvmStatic
        fun cancel(ctx: Context) {
            try {
                WorkManager.getInstance(ctx.applicationContext)
                    .cancelUniqueWork(UNIQUE_NAME)
            } catch (_: Throwable) { }
            try {
                DbRepo.log(ctx, null, "【GeoWorker】已取消周期任务（回包：OK）")
            } catch (_: Throwable) { }
        }
    }

}