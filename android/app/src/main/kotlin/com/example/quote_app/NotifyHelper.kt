package com.example.quote_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.content.Intent
import android.app.PendingIntent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import org.json.JSONObject

object NotifyHelper {
  private const val DEFAULT_CHANNEL_ID = "quote_default_v2"
  private const val DEFAULT_CHANNEL_NAME = "Quotes"

  @JvmStatic
  fun send(
    ctx: Context,
    id: Int,
    title: String,
    body: String,
    avatarPath: String?,
    notifType: String? = null,
    payload: String? = null
  ) {
    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    // Android 13+ 需要 POST_NOTIFICATIONS 运行时权限；若缺失，静默失败。这里直接短路并记录。
    if (Build.VERSION.SDK_INT >= 33) {
      if (ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
        try { com.example.quote_app.data.DbRepo.log(ctx, null, "[Notify] skip: no POST_NOTIFICATIONS permission") } catch (_: Throwable) {}
        return
      }
    }

    // 系统级通知开关被关也会静默丢弃
    if (!nm.areNotificationsEnabled()) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[Notify] skip: notifications disabled at system level") } catch (_: Throwable) {}
      return
    }

    // 8.0+ 必须先创建渠道
    if (Build.VERSION.SDK_INT >= 26) {
      // 记录当前渠道的重要级别，帮助排查通知是否被静音/折叠
      try {
        val existing = nm.getNotificationChannel(DEFAULT_CHANNEL_ID)
        if (existing != null) {
          com.example.quote_app.data.DbRepo.log(
            ctx,
            null,
            "[Notify] existing channel id=%s importance=%d".format(DEFAULT_CHANNEL_ID, existing.importance)
          )
        } else {
          com.example.quote_app.data.DbRepo.log(
            ctx,
            null,
            "[Notify] creating new channel id=%s".format(DEFAULT_CHANNEL_ID)
          )
        }
      } catch (_: Throwable) {}


      val ch = NotificationChannel(
        DEFAULT_CHANNEL_ID,
        DEFAULT_CHANNEL_NAME,
        NotificationManager.IMPORTANCE_HIGH
      )
      nm.createNotificationChannel(ch)
    }

    val builder = NotificationCompat.Builder(ctx, DEFAULT_CHANNEL_ID)
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setContentTitle(title.ifBlank { "愿景提醒" })
      .setContentText(body)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setAutoCancel(true)
      // Open MainActivity when tapping notification; extras carry notification type and payload for navigation
      .apply {
        val launchIntent = Intent(ctx, MainActivity::class.java).apply {
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
          putExtra("from_notification", true)
          if (notifType != null) putExtra("notif_type", notifType)
          if (payload != null) putExtra("payload", payload)
        }
        val pi = PendingIntent.getActivity(
          ctx,
          1001,
          launchIntent,
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        setContentIntent(pi)
      }


    if (!avatarPath.isNullOrEmpty()) {
      try {
        val bmp = BitmapFactory.decodeFile(avatarPath)
        if (bmp != null) builder.setLargeIcon(bmp)
      } catch (_: Throwable) {}
    }

    nm.notify(id, builder.build())
    try { com.example.quote_app.data.DbRepo.log(ctx, null, "[Notify] posted id="+id+" chan="+DEFAULT_CHANNEL_ID) } catch (_: Throwable) {}
  }

  // 兼容旧版 Java 调用（仅有 avatarPath，缺少 notifType / payload）
  // Java 侧会匹配到这个重载方法，内部再委托给带完整参数的实现。
  @JvmStatic
  fun send(
    ctx: Context,
    id: Int,
    title: String,
    body: String,
    avatarPath: String?
  ) {
    send(ctx, id, title, body, avatarPath, null, null)
  }



  // =========================
  // Behavior Observation: inline notification form
  // =========================
  private const val BEHAVIOR_CHANNEL_ID = "behavior_observation_v1"
  private const val BEHAVIOR_CHANNEL_NAME = "行为观察提醒"

  private fun ensureBehaviorObservationChannel(ctx: Context, nm: NotificationManager) {
    if (Build.VERSION.SDK_INT >= 26) {
      val ch = NotificationChannel(
        BEHAVIOR_CHANNEL_ID,
        BEHAVIOR_CHANNEL_NAME,
        NotificationManager.IMPORTANCE_HIGH
      ).apply {
        description = "行为观察提醒：点击通知后选择层面并填写对应表单"
        enableVibration(true)
        setShowBadge(true)
      }
      nm.createNotificationChannel(ch)
    }
  }

  @JvmStatic
  fun sendBehaviorObservationReminder(
    ctx: Context,
    id: Int,
    title: String,
    body: String,
    payload: String?
  ) {
    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 33 && ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorObservation] skip reminder: no POST_NOTIFICATIONS permission") } catch (_: Throwable) {}
      return
    }
    if (!nm.areNotificationsEnabled()) return
    ensureBehaviorObservationChannel(ctx, nm)

    val safeTitle = title.ifBlank { "行为观察提醒" }
    // V21：通知栏只保留简短提醒，不再显示操作步骤说明。
    // 兼容旧提醒计划：如果旧 body 里包含“下拉框/打开后/步骤”等说明，通知展示时自动收敛为一句话。
    val cleanedBody = body.trim()
    val safeBody = if (cleanedBody.isBlank() || cleanedBody.contains("下拉框") || cleanedBody.contains("打开后") || cleanedBody.contains("步骤") || cleanedBody.contains("选择观察层面")) {
      "现在可以记录一条行为观察。"
    } else {
      cleanedBody
    }

    val selectPayload = try {
      val obj = JSONObject(payload ?: "{}")
      obj.put("module", "behavior_tracking")
      obj.put("route", "/behavior_tracking")
      obj.put("templateKey", "notification_layer_select")
      obj.put("entryMode", "notification_layer_selector")
      obj.toString()
    } catch (_: Throwable) {
      "{\"module\":\"behavior_tracking\",\"route\":\"/behavior_tracking\",\"templateKey\":\"notification_layer_select\",\"entryMode\":\"notification_layer_selector\"}"
    }

    val openSelectorIntent = Intent(ctx, MainActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("from_notification", true)
      putExtra("notif_type", "behavior_tracking")
      putExtra("payload", selectPayload)
    }
    val openSelectorPi = PendingIntent.getActivity(
      ctx,
      id + 9100,
      openSelectorIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val n = NotificationCompat.Builder(ctx, BEHAVIOR_CHANNEL_ID)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setContentTitle(safeTitle)
      .setContentText(safeBody)
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      .setDefaults(NotificationCompat.DEFAULT_ALL)
      .setContentIntent(openSelectorPi)
      .setAutoCancel(true)
      .setCategory(NotificationCompat.CATEGORY_REMINDER)
      .addAction(android.R.drawable.ic_menu_edit, "选择层面填写", openSelectorPi)
      .build()

    nm.notify(id, n)
    try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorObservation] posted single selector reminder id=$id") } catch (_: Throwable) {}
  }


  @JvmStatic
  fun sendBehaviorObservationAutoSyncResult(ctx: Context, id: Int, body: String?) {
    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 33 && ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
    ensureBehaviorObservationChannel(ctx, nm)
    val text = body?.takeIf { it.isNotBlank() } ?: "自动读取完成，结果已进入待确认队列。"
    val launchIntent = Intent(ctx, MainActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("from_notification", true)
      putExtra("notif_type", "behavior_tracking")
      putExtra("payload", "{\"module\":\"behavior_tracking\",\"route\":\"/behavior_tracking\",\"templateKey\":\"data_sources\"}")
    }
    val pi = PendingIntent.getActivity(ctx, id + 9400, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    val n = NotificationCompat.Builder(ctx, BEHAVIOR_CHANNEL_ID)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setContentTitle("行为观察自动读取完成")
      .setContentText(text)
      .setPriority(NotificationCompat.PRIORITY_DEFAULT)
      .setContentIntent(pi)
      .setAutoCancel(true)
      .build()
    nm.notify(id, n)
  }


  /**
   * 桌面小组件入口：点击某一观察层面后，弹出一条支持 Direct Reply 的通知。
   * 用户可在通知中输入一句话保存，无需打开完整 App。
   * 返回 false 表示通知权限不可用，调用方可回退到打开轻量表单页。
   */
  @JvmStatic
  fun sendBehaviorObservationWidgetQuickReply(ctx: Context, layer: String?): Boolean {
    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 33 && ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
      try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorObservationWidget] no POST_NOTIFICATIONS permission") } catch (_: Throwable) {}
      return false
    }
    if (!nm.areNotificationsEnabled()) return false
    ensureBehaviorObservationChannel(ctx, nm)

    val cleanLayer = when {
      layer == null -> "行为层面"
      layer.contains("时间") -> "时间层面"
      layer.contains("行为") -> "行为层面"
      layer.contains("情绪") -> "情绪层面"
      layer.contains("认知") || layer.contains("想法") -> "认知层面"
      layer.contains("结果") -> "结果层面"
      layer.contains("环境") -> "环境层面"
      layer.contains("身体") || layer.contains("睡眠") || layer.contains("精力") -> "身体状态层面"
      else -> "行为层面"
    }
    val shortName = cleanLayer.replace("层面", "")
    val id = ((System.currentTimeMillis() / 1000L) % 1000000L).toInt() + 895000
    val payload = try {
      JSONObject().apply {
        put("module", "behavior_tracking")
        put("route", "/behavior_tracking")
        put("templateKey", "notification_layer_select")
        put("entryMode", "desktop_widget_remote_input")
        put("primaryLayer", cleanLayer)
        put("source", "desktop_widget")
      }.toString()
    } catch (_: Throwable) { "{}" }

    val replyIntent = Intent(ctx, BehaviorObservationQuickRecordReceiver::class.java).apply {
      action = BehaviorObservationQuickRecordReceiver.ACTION
      putExtra(BehaviorObservationQuickRecordReceiver.EXTRA_LAYER, cleanLayer)
      putExtra(BehaviorObservationQuickRecordReceiver.EXTRA_PAYLOAD, payload)
      putExtra(BehaviorObservationQuickRecordReceiver.EXTRA_NOTIFICATION_ID, id)
    }
    // Direct Reply 必须使用可变 PendingIntent，否则系统无法把用户输入写入 Intent。
    val replyFlags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
    val replyPi = PendingIntent.getBroadcast(ctx, id + (cleanLayer.hashCode() and 0x7fffffff) % 997, replyIntent, replyFlags)
    val input = RemoteInput.Builder(BehaviorObservationQuickRecordReceiver.KEY_TEXT)
      .setLabel("输入${shortName}观察内容")
      .build()
    val replyAction = NotificationCompat.Action.Builder(android.R.drawable.ic_menu_edit, "输入并保存", replyPi)
      .addRemoteInput(input)
      .setAllowGeneratedReplies(false)
      .build()

    val openIntent = Intent(ctx, MainActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("from_notification", true)
      putExtra("notif_type", "behavior_tracking")
      putExtra("payload", payload)
    }
    val openPi = PendingIntent.getActivity(ctx, id + 9200, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    val n = NotificationCompat.Builder(ctx, BEHAVIOR_CHANNEL_ID)
      .setSmallIcon(android.R.drawable.ic_menu_edit)
      .setContentTitle("桌面小组件 · ${shortName}观察")
      .setContentText("不用打开 App，点“输入并保存”记录一句话。")
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      .setDefaults(NotificationCompat.DEFAULT_ALL)
      .setContentIntent(openPi)
      .setAutoCancel(true)
      .setCategory(NotificationCompat.CATEGORY_REMINDER)
      .addAction(replyAction)
      .build()
    nm.notify(id, n)
    try { com.example.quote_app.data.DbRepo.log(ctx, null, "[BehaviorObservationWidget] posted quick reply layer=$cleanLayer id=$id") } catch (_: Throwable) {}
    return true
  }

  @JvmStatic
  fun sendBehaviorObservationSaved(ctx: Context, id: Int, layer: String, text: String?, savedId: Long) {
    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 33 && ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
    ensureBehaviorObservationChannel(ctx, nm)
    val ok = savedId > 0L
    val body = if (ok) {
      val t = (text ?: "").trim().ifBlank { "已保存一条记录" }
      "已保存到行为观察：${layer.replace("层面", "")} · $t"
    } else {
      "保存失败：请打开 App 后再试，或检查数据库是否已初始化。"
    }
    val launchIntent = Intent(ctx, MainActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("from_notification", true)
      putExtra("notif_type", "behavior_tracking")
      putExtra("payload", "{\"module\":\"behavior_tracking\",\"route\":\"/behavior_tracking\",\"templateKey\":\"quick_capture\"}")
    }
    val pi = PendingIntent.getActivity(ctx, id + 9300, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    val n = NotificationCompat.Builder(ctx, BEHAVIOR_CHANNEL_ID)
      .setSmallIcon(if (ok) android.R.drawable.ic_dialog_info else android.R.drawable.ic_dialog_alert)
      .setContentTitle(if (ok) "行为观察已保存" else "行为观察保存失败")
      .setContentText(body)
      .setPriority(NotificationCompat.PRIORITY_DEFAULT)
      .setContentIntent(pi)
      .setAutoCancel(true)
      .setTimeoutAfter(8000)
      .build()
    nm.notify(id, n)
  }



  private const val BEHAVIOR_PRESET_ALARM_CHANNEL_ID = "behavior_preset_alarm_v40_fullscreen"

  private fun ensureBehaviorPresetAlarmChannel(ctx: Context, nm: NotificationManager) {
    if (Build.VERSION.SDK_INT >= 26) {
      val ch = NotificationChannel(
        BEHAVIOR_PRESET_ALARM_CHANNEL_ID,
        "预设行为闹钟提醒",
        NotificationManager.IMPORTANCE_HIGH
      ).apply {
        description = "预设行为到点后弹出全屏确认表单；铃声/音量/震动由响铃服务统一控制"
        // 使用新的高优先级渠道，但不配置渠道声音/震动，避免覆盖用户选择的统一铃声和震动。
        // 不再把通知本身标记为 silent；部分 ROM 会把 silent 通知降级，导致 fullScreenIntent 不弹出。
        enableVibration(false)
        setShowBadge(true)
        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        setSound(null, null)
      }
      nm.createNotificationChannel(ch)
    }
  }

  @JvmStatic
  fun sendBehaviorPresetAlarmFullScreen(ctx: Context, id: Int, payload: String?) {
    sendBehaviorPresetAlarmFullScreen(ctx, id, payload, false)
  }

  @JvmStatic
  fun sendBehaviorPresetAlarmFullScreen(ctx: Context, id: Int, payload: String?, ringServiceActive: Boolean) {
    val app = ctx.applicationContext
    val normalizedPayload = payload ?: "{}"
    val formIntent = Intent(app, BehaviorPresetAlarmFormActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("payload", normalizedPayload)
      putExtra("from_preset_alarm", true)
      putExtra("alarm_fire", true)
      putExtra("ring_service_active", ringServiceActive)
    }
    val flags = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
    val fullScreenPi = PendingIntent.getActivity(app, id + 730000, formIntent, flags)

    // Do not start the Activity unconditionally here.  v39 did that from Receiver + Service + Notification paths and
    // foreground users could get several forms.  v40 lets the ringing service show an overlay first; when overlay is
    // unavailable, only one direct Activity launch is allowed by the shared UI gate.
    if (!BehaviorPresetAlarmOverlay.canDraw(app) && BehaviorPresetAlarmUiGate.claimUi(app, normalizedPayload)) {
      try {
        app.startActivity(formIntent)
        try { com.example.quote_app.data.DbRepo.log(app, null, "[BehaviorPresetAlarm] direct fullscreen form id=$id") } catch (_: Throwable) {}
      } catch (t: Throwable) {
        try { com.example.quote_app.data.DbRepo.log(app, null, "[BehaviorPresetAlarm] direct form start failed; full-screen notification fallback: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
      }
    }

    try {
      val nm = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      ensureBehaviorPresetAlarmChannel(app, nm)
      val n = NotificationCompat.Builder(app, BEHAVIOR_PRESET_ALARM_CHANNEL_ID)
        .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
        .setContentTitle("预设行为闹钟")
        .setContentText("到点了，点击查看预设提醒表单")
        .setPriority(NotificationCompat.PRIORITY_MAX)
        .setCategory(NotificationCompat.CATEGORY_ALARM)
        .setFullScreenIntent(fullScreenPi, true)
        .setContentIntent(fullScreenPi)
        .setOngoing(true)
        .setAutoCancel(true)
        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        .setDefaults(0)
        .setOnlyAlertOnce(false)
        .build()
      if (Build.VERSION.SDK_INT < 33 || ActivityCompat.checkSelfPermission(app, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
        nm.notify(id, n)
      }
    } catch (t: Throwable) {
      try { com.example.quote_app.data.DbRepo.log(app, null, "[BehaviorPresetAlarm] full-screen notification failed: ${t.javaClass.simpleName} ${t.message}") } catch (_: Throwable) {}
    }
  }


  /**
   * 解锁提醒专用通知发送入口：
   * - 使用独立的解锁提醒通知渠道（quote_unlock_v1），便于和普通通知区分；
   * - 渠道重要级别固定为 IMPORTANCE_HIGH，默认开启声音与震动，提升被系统弹出的概率；
   * - 在发送前详细记录渠道状态与每一步操作，方便后续从数据库日志中还原通知行为。
   */
  @JvmStatic
  fun sendUnlockReminder(
    ctx: Context,
    id: Int,
    title: String,
    body: String
  ) {
    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val channelId = "quote_unlock_v1"
    val channelName = "解锁提醒"

    try {
      com.example.quote_app.data.DbRepo.log(
        ctx,
        null,
        "【解锁提醒-通知助手】准备通过专用渠道发送解锁提醒通知，id=" + id + "，title=" + title
      )
    } catch (_: Throwable) {
    }

    // 统一在这里再次确认系统级通知总开关状态，避免在被关闭时反复尝试发送
    try {
      if (!nm.areNotificationsEnabled()) {
        com.example.quote_app.data.DbRepo.log(
          ctx,
          null,
          "【解锁提醒-通知助手】系统级通知总开关已关闭，本次解锁提醒通知将被静默丢弃"
        )
        return
      }
    } catch (_: Throwable) {
      // 读取通知开关状态失败不影响后续流程，仅记录日志
      try {
        com.example.quote_app.data.DbRepo.log(
          ctx,
          null,
          "【解锁提醒-通知助手】检查系统通知总开关状态时发生异常，继续尝试发送解锁提醒通知"
        )
      } catch (_: Throwable) {
      }
    }

    // Android 8.0+ 需要确保渠道存在，这里专门为解锁提醒维护一个高优先级渠道
    if (Build.VERSION.SDK_INT >= 26) {
      try {
        val existing = nm.getNotificationChannel(channelId)
        if (existing != null) {
          com.example.quote_app.data.DbRepo.log(
            ctx,
            null,
            "【解锁提醒-通知助手】检测到解锁提醒通知渠道已存在，id=" + channelId +
              "，importance=" + existing.importance
          )
        } else {
          com.example.quote_app.data.DbRepo.log(
            ctx,
            null,
            "【解锁提醒-通知助手】未检测到解锁提醒通知渠道，将以 IMPORTANCE_HIGH 创建新渠道，id=" + channelId
          )
        }
      } catch (_: Throwable) {
      }

      try {
        val ch = NotificationChannel(
          channelId,
          channelName,
          NotificationManager.IMPORTANCE_HIGH
        ).apply {
          enableVibration(true)
          enableLights(true)
          setShowBadge(true)
        }
        nm.createNotificationChannel(ch)
      } catch (e: Throwable) {
        try {
          com.example.quote_app.data.DbRepo.log(
            ctx,
            null,
            "【解锁提醒-通知助手】创建解锁提醒通知渠道时发生异常，exception=" +
              e.javaClass.simpleName + "，message=" + (e.message ?: "null")
          )
        } catch (_: Throwable) {
        }
      }
    }

    val builder = NotificationCompat.Builder(ctx, channelId)
      .setContentTitle(title.ifBlank { "愿景提醒" })
      .setContentText(body)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setAutoCancel(true)
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      // 默认开启声音与震动，增加被系统识别为“需要提醒”的概率
      .setDefaults(NotificationCompat.DEFAULT_ALL)
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      .apply {
        // 解锁提醒点击后统一跳转到 MainActivity，并携带 notif_type=vision_focus 方便页面做精确导航
        try {
          val launchIntent = Intent(ctx, com.example.quote_app.MainActivity::class.java).apply {
            addFlags(
              Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra("from_notification", true)
            putExtra("notif_type", "vision_focus")
          }
          val pi = PendingIntent.getActivity(
            ctx,
            2000,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
          )
          setContentIntent(pi)
        } catch (e: Throwable) {
          try {
            com.example.quote_app.data.DbRepo.log(
              ctx,
              null,
              "【解锁提醒-通知助手】构建解锁提醒 PendingIntent 时发生异常，exception=" +
                e.javaClass.simpleName + "，message=" + (e.message ?: "null")
            )
          } catch (_: Throwable) {
          }
        }
      }

    try {
      nm.notify(id, builder.build())
      com.example.quote_app.data.DbRepo.log(
        ctx,
        null,
        "【解锁提醒-通知助手】解锁提醒通知已通过专用渠道交给系统展示，id=" + id +
          "，channelId=" + channelId
      )
    } catch (e: Throwable) {
      try {
        com.example.quote_app.data.DbRepo.log(
          ctx,
          null,
          "【解锁提醒-通知助手】调用 NotificationManager.notify 发送解锁提醒通知失败，exception=" +
            e.javaClass.simpleName + "，message=" + (e.message ?: "null")
        )
      } catch (_: Throwable) {
      }
    }
  }

  // =========================
  // Sport: alarm full-screen + reminder
  // =========================

  private const val SPORT_CHANNEL_ID = "sport_alarm_v1"
  private const val SPORT_CHANNEL_NAME = "运动提醒提醒"

  private fun ensureSportChannel(ctx: Context, nm: NotificationManager) {
    if (Build.VERSION.SDK_INT >= 26) {
      try {
        val existing = nm.getNotificationChannel(SPORT_CHANNEL_ID)
        if (existing == null) {
          val ch = NotificationChannel(
            SPORT_CHANNEL_ID,
            SPORT_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
          )
          nm.createNotificationChannel(ch)
        }
      } catch (_: Throwable) {}
    }
  }

  @JvmStatic
  fun sendSportReminder(
    ctx: Context,
    id: Int,
    title: String,
    body: String,
    notifType: String,
    payload: String
  ) {
    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    if (Build.VERSION.SDK_INT >= 33) {
      if (ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
        try { com.example.quote_app.data.DbRepo.log(ctx, null, "[SportNotify] skip: no POST_NOTIFICATIONS permission") } catch (_: Throwable) {}
        return
      }
    }
    if (!nm.areNotificationsEnabled()) return
    ensureSportChannel(ctx, nm)

    val launchIntent = Intent(ctx, MainActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("from_notification", true)
      putExtra("notif_type", notifType)
      putExtra("payload", payload)
    }
    val pi = PendingIntent.getActivity(
      ctx,
      3001 + (id % 100000),
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val builder = NotificationCompat.Builder(ctx, SPORT_CHANNEL_ID)
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setCategory(NotificationCompat.CATEGORY_REMINDER)
      .setContentTitle(title)
      .setContentText(body)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setAutoCancel(true)
      .setContentIntent(pi)

    nm.notify(id, builder.build())
  }

  @JvmStatic
  fun sendSportFullScreen(
    ctx: Context,
    id: Int,
    title: String,
    body: String,
    notifType: String,
    payload: String
  ) {
    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    if (Build.VERSION.SDK_INT >= 33) {
      if (ActivityCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
        try { com.example.quote_app.data.DbRepo.log(ctx, null, "[SportNotify] skip: no POST_NOTIFICATIONS permission") } catch (_: Throwable) {}
        return
      }
    }
    if (!nm.areNotificationsEnabled()) return
    ensureSportChannel(ctx, nm)

    val launchIntent = Intent(ctx, MainActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      putExtra("from_notification", true)
      putExtra("notif_type", notifType)
      putExtra("payload", payload)
    }
    val pi = PendingIntent.getActivity(
      ctx,
      4001 + (id % 100000),
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val builder = NotificationCompat.Builder(ctx, SPORT_CHANNEL_ID)
      .setPriority(NotificationCompat.PRIORITY_MAX)
      .setCategory(NotificationCompat.CATEGORY_ALARM)
      .setContentTitle(title)
      .setContentText(body)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setAutoCancel(true)
      .setContentIntent(pi)
      // Full-screen intent: tries to immediately bring MainActivity to foreground (alarm-like)
      .setFullScreenIntent(pi, true)

    nm.notify(id, builder.build())
  }

}
