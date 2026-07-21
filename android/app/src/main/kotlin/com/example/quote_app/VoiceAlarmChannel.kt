package com.example.quote_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object VoiceAlarmChannel {
  private const val CHANNEL = "com.example.quote_app/voice_alarm"

  @JvmStatic
  fun register(engine: FlutterEngine, context: Context) {
    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      try {
        when (call.method) {
          "schedule" -> {
            val at = call.argument<Number>("atMs")?.toLong() ?: 0L
            val payload = call.argument<String>("payload") ?: "{}"
            require(at > System.currentTimeMillis()) { "闹钟时间必须晚于当前时间" }
            VoiceAlarmScheduler.schedule(context, at, payload)
            result.success(true)
          }
          "cancel" -> {
            VoiceAlarmScheduler.cancel(context)
            VoiceAlarmRingingService.stop(context)
            result.success(true)
          }
          "cancelAlarm" -> {
            val id = call.argument<Number>("id")?.toInt()
            if (id != null) VoiceAlarmScheduler.cancelById(context, id)
            else VoiceAlarmScheduler.cancel(context, call.argument<String>("alarmId"))
            result.success(true)
          }
          "cancelAllAlarms" -> {
            VoiceAlarmScheduler.cancel(context)
            VoiceAlarmRingingService.stop(context)
            result.success(true)
          }
          "listAlarms" -> result.success(VoiceAlarmScheduler.listPersistedAlarms(context))
          "snooze" -> {
            VoiceAlarmScheduler.snooze(context, call.argument<String>("payload") ?: "{}", 5)
            result.success(true)
          }
          "testRing" -> {
            VoiceAlarmRingingService.start(context, call.argument<String>("payload") ?: "{}")
            result.success(true)
          }
          "stopRing" -> {
            VoiceAlarmRingingService.stop(context)
            result.success(true)
          }
          "restore" -> {
            VoiceAlarmScheduler.restore(context)
            result.success(true)
          }
          "hasExactAlarmPermission" -> result.success(ExactAlarmHelper.hasExactAlarmPermission(context))
          "requestExactAlarmPermission" -> result.success(ExactAlarmHelper.requestExactAlarmPermission(context))
          "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent(context))
          "requestFullScreenIntentPermission" -> result.success(openFullScreenIntentSettings(context))
          "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations(context))
          "requestIgnoreBatteryOptimizations" -> result.success(requestIgnoreBatteryOptimizations(context))
          "isAlarmNotificationChannelImportant" -> result.success(VoiceAlarmRingingService.isAlarmChannelImportantEnough(context))
          "openAlarmNotificationChannelSettings" -> result.success(openAlarmNotificationChannelSettings(context))
          else -> result.notImplemented()
        }
      } catch (t: Throwable) {
        result.error("VOICE_ALARM_ERROR", t.message, null)
      }
    }
  }

  private fun canUseFullScreenIntent(ctx: Context): Boolean {
    return try {
      if (Build.VERSION.SDK_INT < 34) return true
      val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      val m = nm.javaClass.getMethod("canUseFullScreenIntent")
      m.invoke(nm) == true
    } catch (_: Throwable) { true }
  }

  private fun openFullScreenIntentSettings(ctx: Context): Boolean {
    return try {
      if (Build.VERSION.SDK_INT < 34) return true
      val intent = Intent("android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT").apply {
        data = Uri.parse("package:${ctx.packageName}")
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
      ctx.startActivity(intent)
      true
    } catch (_: Throwable) {
      try {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = Uri.parse("package:${ctx.packageName}")
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        ctx.startActivity(intent)
        true
      } catch (_: Throwable) { false }
    }
  }

  private fun openAlarmNotificationChannelSettings(ctx: Context): Boolean {
    return try {
      VoiceAlarmRingingService.ensureAlarmChannel(ctx)
      val intent = if (Build.VERSION.SDK_INT >= 26) {
        Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
          putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
          putExtra(Settings.EXTRA_CHANNEL_ID, VoiceAlarmRingingService.CHANNEL_ID)
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
      } else {
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = Uri.parse("package:${ctx.packageName}")
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
      }
      ctx.startActivity(intent)
      true
    } catch (_: Throwable) {
      try {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = Uri.parse("package:${ctx.packageName}")
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        ctx.startActivity(intent)
        true
      } catch (_: Throwable) { false }
    }
  }
  private fun isIgnoringBatteryOptimizations(ctx: Context): Boolean {
    return try {
      val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
      pm.isIgnoringBatteryOptimizations(ctx.packageName)
    } catch (_: Throwable) { true }
  }

  private fun requestIgnoreBatteryOptimizations(ctx: Context): Boolean {
    return try {
      if (isIgnoringBatteryOptimizations(ctx)) return true
      val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
        data = Uri.parse("package:${ctx.packageName}")
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
      ctx.startActivity(intent)
      true
    } catch (_: Throwable) {
      try {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = Uri.parse("package:${ctx.packageName}")
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        ctx.startActivity(intent)
        true
      } catch (_: Throwable) { false }
    }
  }

}
