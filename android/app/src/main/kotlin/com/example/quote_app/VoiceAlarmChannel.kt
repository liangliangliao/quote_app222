package com.example.quote_app

import android.content.Context
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
          "hasExactAlarmPermission" -> result.success(ExactAlarmHelper.hasExactAlarmPermission(context))
          "requestExactAlarmPermission" -> result.success(ExactAlarmHelper.requestExactAlarmPermission(context))
          else -> result.notImplemented()
        }
      } catch (t: Throwable) {
        result.error("VOICE_ALARM_ERROR", t.message, null)
      }
    }
  }
}
