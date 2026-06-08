package com.example.quote_app

import android.content.ComponentName
import android.appwidget.AppWidgetManager
import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * 行为观察原生桥：
 * - UsageStatsManager：真实屏幕使用时间读取，必须由用户手动授予“使用情况访问权限”。
 * - CalendarContract.Instances：真实系统日历读取，必须授予 READ_CALENDAR。
 * - Notification payload：保留并下发通知点击参数，让 Flutter 可跳转到行为观察模板。
 */
object BehaviorTrackingNativeChannel {
  private const val CHANNEL = "behavior.tracking.native"
  private const val REQ_CALENDAR = 8708

  @Volatile private var channel: MethodChannel? = null
  @Volatile private var lastNotificationPayload: String? = null
  @Volatile private var lastNotificationType: String? = null

  fun register(activity: Activity, engine: FlutterEngine) {
    val appCtx = activity.applicationContext
    val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
    channel = ch
    ch.setMethodCallHandler { call, result ->
      try {
        when (call.method) {
          "hasUsageAccess" -> result.success(hasUsageAccess(appCtx))
          "openUsageAccessSettings" -> {
            val ok = openSettings(activity, Settings.ACTION_USAGE_ACCESS_SETTINGS)
            result.success(ok)
          }
          "queryUsageStats" -> {
            val startMs = (call.argument<Number>("startMs") ?: 0).toLong()
            val endMs = (call.argument<Number>("endMs") ?: System.currentTimeMillis()).toLong()
            val minMs = (call.argument<Number>("minMs") ?: 60_000).toLong()
            if (!hasUsageAccess(appCtx)) {
              result.error("NO_USAGE_ACCESS", "用户尚未授予使用情况访问权限", null)
            } else {
              result.success(queryUsageStats(appCtx, startMs, endMs, minMs))
            }
          }
          "hasPostNotificationsPermission" -> result.success(hasPostNotificationsPermission(appCtx))
          "requestPostNotificationsPermission" -> {
            if (hasPostNotificationsPermission(appCtx)) {
              result.success(true)
            } else if (Build.VERSION.SDK_INT >= 33) {
              ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 8709)
              result.success(false)
            } else {
              result.success(true)
            }
          }
          "hasCalendarPermission" -> result.success(hasCalendarPermission(appCtx))
          "requestCalendarPermission" -> {
            if (hasCalendarPermission(appCtx)) {
              result.success(true)
            } else {
              ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.READ_CALENDAR), REQ_CALENDAR)
              result.success(false)
            }
          }
          "openAppPermissionSettings" -> {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
              data = android.net.Uri.parse("package:" + appCtx.packageName)
              addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            result.success(true)
          }
          "queryCalendarEvents" -> {
            val startMs = (call.argument<Number>("startMs") ?: 0).toLong()
            val endMs = (call.argument<Number>("endMs") ?: System.currentTimeMillis()).toLong()
            if (!hasCalendarPermission(appCtx)) {
              result.error("NO_CALENDAR_PERMISSION", "用户尚未授予日历读取权限", null)
            } else {
              result.success(queryCalendarInstances(appCtx, startMs, endMs))
            }
          }
          "consumeLastNotificationPayload" -> {
            val payload = lastNotificationPayload
            val type = lastNotificationType
            lastNotificationPayload = null
            lastNotificationType = null
            result.success(hashMapOf<String, Any?>("type" to type, "payload" to payload))
          }
          "showBehaviorObservationQuickRecordNotification" -> {
            val title = call.argument<String>("title") ?: "行为观察提醒"
            val body = call.argument<String>("body") ?: "下拉通知，选择观察层面，直接输入并保存。"
            val payload = call.argument<String>("payload") ?: "{}"
            if (!hasPostNotificationsPermission(appCtx)) {
              result.success(false)
            } else {
              val id = ((System.currentTimeMillis() / 1000L) % 1000000L).toInt() + 880000
              NotifyHelper.sendBehaviorObservationReminder(appCtx, id, title, body, payload)
              result.success(true)
            }
          }
          "getPresetAlarmSettings" -> {
            result.success(BehaviorPresetAlarmSettings.asMap(appCtx))
          }
          "savePresetAlarmSettings" -> {
            val soundUri = call.argument<String>("soundUri")
            val soundTitle = call.argument<String>("soundTitle")
            val volume = call.argument<Number>("volume")?.toFloat()
            val vibrate = call.argument<Boolean>("vibrate")
            BehaviorPresetAlarmSettings.set(appCtx, soundUri, soundTitle, volume, vibrate)
            result.success(BehaviorPresetAlarmSettings.asMap(appCtx))
          }
          "openPresetAlarmRingtonePicker" -> {
            val intent = Intent(activity, BehaviorPresetRingtonePickActivity::class.java)
            activity.startActivity(intent)
            result.success(true)
          }
          "requestPresetAlarmRuntimePermissions" -> {
            val perms = ArrayList<String>()
            if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
              perms.add(Manifest.permission.POST_NOTIFICATIONS)
            }
            if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_MEDIA_AUDIO) != PackageManager.PERMISSION_GRANTED) {
              perms.add(Manifest.permission.READ_MEDIA_AUDIO)
            } else if (Build.VERSION.SDK_INT in 23..32 && ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
              perms.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
            if (perms.isNotEmpty()) ActivityCompat.requestPermissions(activity, perms.toTypedArray(), 8711)
            result.success(perms.isEmpty())
          }
          "canUseFullScreenIntent" -> {
            result.success(canUseFullScreenIntent(appCtx))
          }
          "openFullScreenIntentSettings" -> {
            result.success(openFullScreenIntentSettings(activity))
          }
          "canDrawBehaviorPresetAlarmOverlay" -> {
            result.success(BehaviorPresetAlarmOverlay.canDraw(appCtx))
          }
          "openBehaviorPresetAlarmOverlaySettings" -> {
            result.success(openOverlaySettings(activity))
          }
          "requestPinBehaviorObservationWidget" -> {
            result.success(requestPinBehaviorObservationWidget(activity))
          }
          else -> result.notImplemented()
        }
      } catch (t: Throwable) {
        result.error("ERR", t.message ?: t.javaClass.simpleName, null)
      }
    }
  }


  private fun canUseFullScreenIntent(ctx: Context): Boolean {
    return try {
      if (Build.VERSION.SDK_INT < 34) return true
      val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
      val m = nm.javaClass.getMethod("canUseFullScreenIntent")
      m.invoke(nm) == true
    } catch (_: Throwable) { true }
  }

  private fun openFullScreenIntentSettings(activity: Activity): Boolean {
    return try {
      if (Build.VERSION.SDK_INT < 34) return true
      val intent = Intent("android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT").apply {
        data = android.net.Uri.parse("package:" + activity.packageName)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
      activity.startActivity(intent)
      true
    } catch (_: Throwable) {
      try {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = android.net.Uri.parse("package:" + activity.packageName)
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
        true
      } catch (_: Throwable) { false }
    }
  }

  private fun openOverlaySettings(activity: Activity): Boolean {
    return try {
      if (Build.VERSION.SDK_INT < 23) return true
      val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
        data = android.net.Uri.parse("package:" + activity.packageName)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
      activity.startActivity(intent)
      true
    } catch (_: Throwable) {
      try {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = android.net.Uri.parse("package:" + activity.packageName)
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
        true
      } catch (_: Throwable) { false }
    }
  }

  private fun requestPinBehaviorObservationWidget(activity: Activity): Boolean {
    return try {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
      val manager = activity.getSystemService(AppWidgetManager::class.java) ?: return false
      if (!manager.isRequestPinAppWidgetSupported) return false
      val provider = ComponentName(activity, BehaviorObservationWidgetProvider::class.java)
      manager.requestPinAppWidget(provider, null, null)
      true
    } catch (_: Throwable) {
      false
    }
  }

  fun onNotificationIntent(type: String?, payload: String?) {
    if (payload.isNullOrBlank() && type.isNullOrBlank()) return
    lastNotificationType = type
    lastNotificationPayload = payload
    try {
      val args = hashMapOf<String, Any?>("type" to type, "payload" to payload)
      channel?.invokeMethod("onBehaviorNotificationTap", args)
    } catch (_: Throwable) {}
  }

  private fun hasUsageAccess(ctx: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return false
    return try {
      val appOps = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
      val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), ctx.packageName)
      } else {
        @Suppress("DEPRECATION")
        appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), ctx.packageName)
      }
      mode == AppOpsManager.MODE_ALLOWED
    } catch (_: Throwable) {
      false
    }
  }

  private fun hasPostNotificationsPermission(ctx: Context): Boolean {
    return Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
  }

  private fun hasCalendarPermission(ctx: Context): Boolean {
    return ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
  }

  private fun openSettings(activity: Activity, action: String): Boolean {
    return try {
      val intent = Intent(action).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
      activity.startActivity(intent)
      true
    } catch (_: Throwable) {
      try {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = android.net.Uri.parse("package:" + activity.packageName)
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
        true
      } catch (_: Throwable) {
        false
      }
    }
  }

  private fun queryUsageStats(ctx: Context, startMs: Long, endMs: Long, minMs: Long): List<Map<String, Any?>> {
    val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    val pm = ctx.packageManager
    val aggregated = usm.queryAndAggregateUsageStats(startMs, endMs)
    val rows = ArrayList<Map<String, Any?>>()
    for ((pkg, stat) in aggregated) {
      val total = stat.totalTimeInForeground
      if (total < minMs) continue
      var label = pkg
      var category = "unknown"
      try {
        val info = pm.getApplicationInfo(pkg, 0)
        label = pm.getApplicationLabel(info)?.toString() ?: pkg
        category = appCategory(info)
      } catch (_: Throwable) {}
      rows.add(hashMapOf<String, Any?>(
        "packageName" to pkg,
        "appName" to label,
        "category" to category,
        "totalTimeMs" to total,
        "lastTimeUsedMs" to stat.lastTimeUsed,
        "firstTimeStampMs" to stat.firstTimeStamp,
        "lastTimeStampMs" to stat.lastTimeStamp
      ))
    }
    rows.sortByDescending { (it["totalTimeMs"] as? Number)?.toLong() ?: 0L }
    return rows
  }

  private fun appCategory(info: ApplicationInfo): String {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return "unknown"
    return when (info.category) {
      ApplicationInfo.CATEGORY_GAME -> "game"
      ApplicationInfo.CATEGORY_AUDIO -> "audio"
      ApplicationInfo.CATEGORY_VIDEO -> "video"
      ApplicationInfo.CATEGORY_IMAGE -> "image"
      ApplicationInfo.CATEGORY_SOCIAL -> "social"
      ApplicationInfo.CATEGORY_NEWS -> "news"
      ApplicationInfo.CATEGORY_MAPS -> "maps"
      ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
      else -> "unknown"
    }
  }

  private fun queryCalendarInstances(ctx: Context, startMs: Long, endMs: Long): List<Map<String, Any?>> {
    val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
    ContentUris.appendId(builder, startMs)
    ContentUris.appendId(builder, endMs)
    val uri = builder.build()
    val projection = arrayOf(
      CalendarContract.Instances.EVENT_ID,
      CalendarContract.Instances.TITLE,
      CalendarContract.Instances.DESCRIPTION,
      CalendarContract.Instances.BEGIN,
      CalendarContract.Instances.END,
      CalendarContract.Instances.EVENT_LOCATION,
      CalendarContract.Instances.ALL_DAY,
      CalendarContract.Instances.CALENDAR_DISPLAY_NAME
    )
    val rows = ArrayList<Map<String, Any?>>()
    ctx.contentResolver.query(uri, projection, null, null, CalendarContract.Instances.BEGIN + " ASC")?.use { c ->
      val idIdx = c.getColumnIndex(CalendarContract.Instances.EVENT_ID)
      val titleIdx = c.getColumnIndex(CalendarContract.Instances.TITLE)
      val descIdx = c.getColumnIndex(CalendarContract.Instances.DESCRIPTION)
      val beginIdx = c.getColumnIndex(CalendarContract.Instances.BEGIN)
      val endIdx = c.getColumnIndex(CalendarContract.Instances.END)
      val locIdx = c.getColumnIndex(CalendarContract.Instances.EVENT_LOCATION)
      val allDayIdx = c.getColumnIndex(CalendarContract.Instances.ALL_DAY)
      val calIdx = c.getColumnIndex(CalendarContract.Instances.CALENDAR_DISPLAY_NAME)
      while (c.moveToNext()) {
        val id = if (idIdx >= 0) c.getLong(idIdx).toString() else ""
        val title = if (titleIdx >= 0) c.getString(titleIdx) ?: "未命名日历事件" else "未命名日历事件"
        val begin = if (beginIdx >= 0) c.getLong(beginIdx) else startMs
        val end = if (endIdx >= 0) c.getLong(endIdx) else begin
        val raw = JSONObject()
        try {
          raw.put("eventId", id)
          raw.put("title", title)
          raw.put("calendar", if (calIdx >= 0) c.getString(calIdx) else null)
          raw.put("location", if (locIdx >= 0) c.getString(locIdx) else null)
        } catch (_: Throwable) {}
        rows.add(hashMapOf<String, Any?>(
          "eventId" to id,
          "title" to title,
          "description" to if (descIdx >= 0) c.getString(descIdx) else null,
          "startMs" to begin,
          "endMs" to end,
          "location" to if (locIdx >= 0) c.getString(locIdx) else null,
          "allDay" to (if (allDayIdx >= 0) c.getInt(allDayIdx) == 1 else false),
          "calendarName" to if (calIdx >= 0) c.getString(calIdx) else null,
          "rawJson" to raw.toString()
        ))
      }
    }
    return rows
  }
}
