package com.example.quote_app

import android.Manifest
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
