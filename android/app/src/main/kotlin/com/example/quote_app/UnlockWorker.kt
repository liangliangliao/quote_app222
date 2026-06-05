package com.example.quote_app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.OutOfQuotaPolicy
import com.example.quote_app.data.DbRepo
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.Date
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * UnlockWorker：在后台线程中执行“解锁/亮屏”后的完整业务逻辑：
 * 1. 记录日志（中文，带“回包”状态）
 * 2. 读取数据库：解锁轻提醒开关（notify_config.unlock_switch_enabled）
 * 3. 读取冷却时间（notify_config.unlock_cooldown_minutes / unlock_cooldown_days）并判断是否处于冷却期
 * 4. （若需要）发送解锁提醒通知（NotifyHelper.sendUnlockReminder）
 * 说明（已调整）：
 * - 按需求，地点规则提醒不再使用 WorkManager 周期任务轮询定位；仅在“解锁广播”链路触发。
 * - 为避免某些机型 WorkManager 严重延迟，本版本默认不再从 UnlockReceiver 调度本 Worker。
 * - 本类保留兼容（可能仍被旧调用点触发），但不会再调度 GeoWorker 周期任务。
 */
class UnlockWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {

  // 写入包含时间戳的日志。部分业务需带 UID 留空。
  private fun logWithTime(ctx: Context, uid: String?, msg: String) {
    try {
      val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
      val now = sdf.format(Date())
      DbRepo.log(ctx, uid, "[$now] $msg")
    } catch (_: Throwable) {
      try { DbRepo.log(ctx, uid, msg) } catch (_: Throwable) {}
    }
  }

  override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
    val ctx = applicationContext
    val uid: String? = null
    try {
      logWithTime(ctx, uid, "【解锁后台】UnlockWorker 启动，开始处理解锁/亮屏后的业务逻辑")
    } catch (_: Throwable) {}

    // 地点规则不再使用周期 GeoWorker；此处不再做任何调度。

    // 读取数据库（通过 DbInspector 推断路径）
    val contract = com.example.quote_app.data.DbInspector.loadOrLightScan(ctx)
    if (contract == null || contract.dbPath == null) {
      try { logWithTime(ctx, uid, "【解锁后台】无法定位数据库文件，跳过本次解锁提醒（回包：SKIP_NO_DB）") } catch (_: Throwable) {}
      return@withContext Result.success()
    }

    var db: SQLiteDatabase? = null
    try {
      db = SQLiteDatabase.openDatabase(contract.dbPath, null, SQLiteDatabase.OPEN_READONLY)
    } catch (_: Throwable) {}

    if (db == null) {
      try { logWithTime(ctx, uid, "【解锁后台】数据库打开失败，跳过本次解锁提醒（回包：SKIP_DB_OPEN_FAIL）") } catch (_: Throwable) {}
      return@withContext Result.success()
    }

    try {
      // 1）检查 unlock_switch_enabled 开关
      var configEnabled = false
      try {
        val c = db.rawQuery("SELECT value FROM notify_config WHERE key='unlock_switch_enabled' LIMIT 1", null)
        if (c.moveToFirst()) {
          val v = c.getString(0)
          if (v != null) {
            val s = v.trim().lowercase()
            configEnabled = (s == "1" || s == "true")
          }
        }
        c.close()
      } catch (_: Throwable) {}

      if (!configEnabled) {
        try { logWithTime(ctx, uid, "【解锁后台】解锁轻提醒开关已关闭，跳过（回包：SKIP_SWITCH_OFF）") } catch (_: Throwable) {}
        return@withContext Result.success()
      }

      // 2）计算冷却时间（默认30分钟，可被按天/按分钟配置覆盖）
      var cooldownMs = 30L * 60L * 1000L
      try {
        // 按天优先
        try {
          val cDay = db.rawQuery("SELECT value FROM notify_config WHERE key='unlock_cooldown_days' LIMIT 1", null)
          if (cDay.moveToFirst()) {
            val v = cDay.getString(0)
            try {
              val d = v?.toDouble()
              if (d != null && d > 0.0) cooldownMs = (d * 24.0 * 60.0 * 60.0 * 1000.0).toLong()
            } catch (_: Throwable) {}
          }
          cDay.close()
        } catch (_: Throwable) {}

        // 若天未覆盖，尝试按分钟
        if (cooldownMs == 30L * 60L * 1000L) {
          try {
            val cMin = db.rawQuery("SELECT value FROM notify_config WHERE key='unlock_cooldown_minutes' LIMIT 1", null)
            if (cMin.moveToFirst()) {
              val v = cMin.getString(0)
              try {
                val m = v?.toDouble()
                if (m != null && m > 0.0) cooldownMs = (m * 60.0 * 1000.0).toLong()
              } catch (_: Throwable) {}
            }
            cMin.close()
          } catch (_: Throwable) {}
        }
      } catch (_: Throwable) {}

      // 3）冷却判断（基于 SharedPreferences）
      var inCooldown = false
      try {
        val prefs = ctx.getSharedPreferences("vision_prefs", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val last = prefs.getLong("last_unlock_reminder_time", 0L)
        if (last > 0L && (now - last) < cooldownMs) inCooldown = true
      } catch (_: Throwable) {}

      if (inCooldown) {
        try { logWithTime(ctx, uid, "【解锁后台】仍处于冷却期，跳过（cooldownMs=$cooldownMs，回包：SKIP_COOLDOWN）") } catch (_: Throwable) {}
        return@withContext Result.success()
      }

      // 4）发送解锁提醒通知（带简短延迟）
      val id = 10086
      val title = "继续专注"
      val body = "别忘了你的一件事！"

      try {
        // 记录本次计划发送的时间戳
        val ts = System.currentTimeMillis()
        logWithTime(ctx, uid, "【解锁后台】300ms 后发送解锁提醒，ts=$ts，通知ID=$id")
      } catch (_: Throwable) {}

      // 取消人为延迟，提升解锁提醒实时性（避免被系统延后/忽略）

      try {
        NotifyHelper.sendUnlockReminder(ctx, id, title, body)
        // 发送成功后，更新冷却时间戳（避免短期重复）
        try {
          val prefs = ctx.getSharedPreferences("vision_prefs", Context.MODE_PRIVATE)
          prefs.edit().putLong("last_unlock_reminder_time", System.currentTimeMillis()).apply()
        } catch (_: Throwable) {}
        try { logWithTime(ctx, uid, "【解锁后台】解锁提醒发送成功（回包：SUCCESS）") } catch (_: Throwable) {}
      } catch (t: Throwable) {
        try { logWithTime(ctx, uid, "【解锁后台】解锁提醒发送失败，异常=" + (t.message ?: "unknown") + "（回包：FAIL）") } catch (_: Throwable) {}
      }

      return@withContext Result.success()
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
  }
companion object {
  private const val UNIQUE_NAME = "unlock_bg"

  /** 供外部（广播/应用启动）触发：用 REPLACE 策略，确保“刷新一次”语义 */
  fun trigger(context: android.content.Context) {
    try {
      val req = androidx.work.OneTimeWorkRequestBuilder<UnlockWorker>()
        .setExpedited(androidx.work.OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
        .addTag(UNIQUE_NAME)
        .build()
      androidx.work.WorkManager.getInstance(context)
        .enqueueUniqueWork(UNIQUE_NAME, androidx.work.ExistingWorkPolicy.REPLACE, req)
      try {
        val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
        val now = sdf.format(Date())
        com.example.quote_app.data.DbRepo.log(context, null, "[$now] 【解锁后台】已触发 UnlockWorker（加速执行模式，ExistingWorkPolicy.REPLACE，回包：OK）")
      } catch (_: Throwable) {}
    } catch (_: Throwable) {
      try {
        val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
        val now = sdf.format(Date())
        com.example.quote_app.data.DbRepo.log(context, null, "[$now] 【解锁后台】触发 UnlockWorker 失败（回包：FAIL）")
      } catch (_: Throwable) {}
    }
  }
}
}
