package com.example.quote_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.work.*
import java.util.concurrent.TimeUnit
object NativeSchedulerK {

  private const val UNIQUE_WORK_PREFIX = "wm_once_"

  private fun buildPi(ctx: Context, id: Int, payload: String?): PendingIntent {
    val i = Intent(ctx, com.example.quote_app.am.AlarmReceiver::class.java)
      .setAction("com.example.quote_app.ALARM."+id.toString())
      .setPackage(ctx.packageName)
    .putExtra("id", id)
      .putExtra("payload", payload ?: "{}")
    val flags = if (Build.VERSION.SDK_INT >= 23)
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    else
      PendingIntent.FLAG_UPDATE_CURRENT
    return PendingIntent.getBroadcast(ctx, id, i, flags)
  }

  @JvmStatic fun scheduleExactAt(ctx: Context, id: Int, epochMs: Long, payload: String?): Boolean {
    return try {
      val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
      val pi = buildPi(ctx, id, payload)
      if (Build.VERSION.SDK_INT >= 23) {
        try {
          am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
        } catch (_: Throwable) {
          am.setExact(AlarmManager.RTC_WAKEUP, epochMs, pi)
        }
      } else {
        am.setExact(AlarmManager.RTC_WAKEUP, epochMs, pi)
      }
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "【原生】AM 计划 id="+id+" at="+epochMs); } catch (_: Throwable) {}
      true
    } catch (_: Throwable) { false }
  }

  @JvmStatic fun cancel(ctx: Context, id: Int): Boolean {
    return try {
      val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
      val pi = buildPi(ctx, id, null)
      am.cancel(pi)
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "【原生】AM 取消 id="+id); } catch (_: Throwable) {}
      true
    } catch (_: Throwable) { false }
  }

  @JvmStatic fun cancelAll(ctx: Context): Boolean {
    return try {
      // 仅能可靠取消 WM 的任务；AM 需提供具体 id 才能取消
      WorkManager.getInstance(ctx).cancelAllWork()
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "【原生】WM 全部取消"); } catch (_: Throwable) {}
      true
    } catch (_: Throwable) { false }
  }

  @JvmStatic fun scheduleExactWmCompat(ctx: Context, id: Int, epochMs: Long, payload: String?): Boolean {
    val delayMs = kotlin.math.max(0L, epochMs - System.currentTimeMillis())
    val data = Data.Builder()
      .putInt("id", id)
      .putString("payload", payload ?: "{}")
      .putString("job", "wm_run")
      .build()
    val req = OneTimeWorkRequestBuilder<NotifyWorker>()
      .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
      .addTag(UNIQUE_WORK_PREFIX + id.toString())
      .setInputData(data)
      .build()
    return try {
      WorkManager.getInstance(ctx).enqueueUniqueWork(
        UNIQUE_WORK_PREFIX + id.toString(),
        ExistingWorkPolicy.REPLACE,
        req
      )
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "【原生】WM 兜底注册完成 id="+id+" delay="+delayMs+"ms"); } catch (_: Throwable) {}
      true
    } catch (_: Throwable) { false }
  }

  @JvmStatic fun scheduleSelfCheck(ctx: Context, minutes: Int): Boolean {
    val data = Data.Builder().putString("job","selfcheck").build()
    val req = OneTimeWorkRequestBuilder<SelfCheckWorker>()
      .setInitialDelay(minutes.toLong(), TimeUnit.MINUTES)
      .setInputData(data)
      .build()
    return try {
      WorkManager.getInstance(ctx).enqueue(req)
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "【原生】WM 自检计划 +"+minutes+"min"); } catch (_: Throwable) {}
      true
    } catch (_: Throwable) { false }
  }
}