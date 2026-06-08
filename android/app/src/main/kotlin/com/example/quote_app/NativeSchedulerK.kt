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
      .setAction("com.example.quote_app.ALARM." + id.toString())
      .setPackage(ctx.packageName)
      .putExtra("id", id)
      .putExtra("payload", payload ?: "{}")
    val flags = if (Build.VERSION.SDK_INT >= 23)
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    else
      PendingIntent.FLAG_UPDATE_CURRENT
    return PendingIntent.getBroadcast(ctx, id, i, flags)
  }

  private fun buildAlarmActivityPi(ctx: Context, id: Int, payload: String?): PendingIntent {
    val i = Intent(ctx, BehaviorPresetAlarmFormActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("payload", payload ?: "{}")
      putExtra("from_preset_alarm", true)
      putExtra("alarm_fire", true)
      putExtra("alarm_clock_activity", true)
    }
    val flags = if (Build.VERSION.SDK_INT >= 23)
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    else
      PendingIntent.FLAG_UPDATE_CURRENT
    return PendingIntent.getActivity(ctx, id + 510000, i, flags)
  }


  private fun buildBehaviorPresetAlarmFirePi(ctx: Context, id: Int, payload: String?): PendingIntent {
    val i = Intent(ctx, BehaviorPresetAlarmFireReceiver::class.java)
      .setAction("com.example.quote_app.BEHAVIOR_PRESET_ALARM." + id.toString())
      .setPackage(ctx.packageName)
      .putExtra("id", id)
      .putExtra("payload", payload ?: "{}")
      .putExtra("alarm_fire", true)
    val flags = if (Build.VERSION.SDK_INT >= 23)
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    else
      PendingIntent.FLAG_UPDATE_CURRENT
    return PendingIntent.getBroadcast(ctx, id + 520000, i, flags)
  }

  private fun buildAlarmClockShowPi(ctx: Context, id: Int, payload: String?): PendingIntent {
    // This intent is used when the user taps the system's upcoming-alarm affordance before the alarm fires.
    // It must not open the ringing form, otherwise merely inspecting the system alarm indicator would start
    // sound/vibration early. Open the app instead and keep the payload for optional routing/diagnostics.
    val i = Intent(ctx, MainActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("from_behavior_preset_alarm_clock", true)
      putExtra("notif_type", "behavior_tracking")
      putExtra("payload", payload ?: "{}")
    }
    val flags = if (Build.VERSION.SDK_INT >= 23)
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    else
      PendingIntent.FLAG_UPDATE_CURRENT
    return PendingIntent.getActivity(ctx, id + 610000, i, flags)
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


  private fun scheduleExactActivityAt(ctx: Context, id: Int, epochMs: Long, payload: String?): Boolean {
    return try {
      val app = ctx.applicationContext
      val am = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
      try { am.cancel(buildPi(app, id, null)) } catch (_: Throwable) {}
      try { am.cancel(buildAlarmActivityPi(app, id, null)) } catch (_: Throwable) {}
      try { am.cancel(buildAlarmClockShowPi(app, id, null)) } catch (_: Throwable) {}
      try { am.cancel(buildBehaviorPresetAlarmFirePi(app, id, null)) } catch (_: Throwable) {}
      val pi = buildAlarmActivityPi(app, id, payload)
      if (Build.VERSION.SDK_INT >= 23) {
        try {
          am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, epochMs, pi)
        } catch (_: Throwable) {
          am.setExact(AlarmManager.RTC_WAKEUP, epochMs, pi)
        }
      } else {
        am.setExact(AlarmManager.RTC_WAKEUP, epochMs, pi)
      }
      try { com.example.quote_app.data.DbRepo.log(app, null, "【BehaviorPresetAlarm】exact Activity fallback id="+id+" at="+epochMs); } catch (_: Throwable) {}
      true
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "【BehaviorPresetAlarm】exact Activity fallback failed: ${t.javaClass.simpleName} ${t.message}"); } catch (_: Throwable) {}
      false
    }
  }

  /**
   * Alarm-clock style schedule for behavior preset alarms.
   * setAlarmClock is intentionally used here because these reminders should behave like a user-visible alarm:
   * it is allowed to wake the device from idle and is restored by the OS even when the app process is not alive.
   */
  @JvmStatic fun scheduleAlarmClockAt(ctx: Context, id: Int, epochMs: Long, payload: String?): Boolean {
    return try {
      val app = ctx.applicationContext
      val am = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
      // Cancel all historical variants.  v39 registered both a Receiver alarm and delayed Activity alarms; keeping
      // those active caused several foreground forms for one fire.  v40 uses exactly one AlarmClock operation: the
      // Receiver wakes the foreground ringing service, and that service owns UI/overlay/notification display.
      try { am.cancel(buildPi(app, id, null)) } catch (_: Throwable) {}
      try { am.cancel(buildAlarmActivityPi(app, id, null)) } catch (_: Throwable) {}
      try { am.cancel(buildAlarmClockShowPi(app, id, null)) } catch (_: Throwable) {}
      try { am.cancel(buildBehaviorPresetAlarmFirePi(app, id, null)) } catch (_: Throwable) {}

      val signalOperation = buildBehaviorPresetAlarmFirePi(app, id, payload)
      val show = buildAlarmClockShowPi(app, id, payload)
      val info = AlarmManager.AlarmClockInfo(epochMs, show)
      am.setAlarmClock(info, signalOperation)
      try { com.example.quote_app.data.DbRepo.log(app, null, "【BehaviorPresetAlarm】v40 setAlarmClock Receiver+Service only id="+id+" at="+epochMs); } catch (_: Throwable) {}
      true
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "【BehaviorPresetAlarm】v40 setAlarmClock receiver failed, fallback exact Receiver: ${t.javaClass.simpleName} ${t.message}"); } catch (_: Throwable) {}
      scheduleExactAt(ctx, id, epochMs, payload)
    }
  }

  @JvmStatic fun cancel(ctx: Context, id: Int): Boolean {
    return try {
      val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
      val pi = buildPi(ctx, id, null)
      am.cancel(pi)
      try { am.cancel(buildAlarmActivityPi(ctx, id, null)) } catch (_: Throwable) {}
      try { am.cancel(buildAlarmClockShowPi(ctx, id, null)) } catch (_: Throwable) {}
      try { am.cancel(buildBehaviorPresetAlarmFirePi(ctx, id, null)) } catch (_: Throwable) {}
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
