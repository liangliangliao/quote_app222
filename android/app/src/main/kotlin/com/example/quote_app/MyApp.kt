package com.example.quote_app

import android.app.Application
import com.example.quote_app.GeoWorker
import com.example.quote_app.NotifyHelper
import com.example.quote_app.data.DbInspector
import android.database.sqlite.SQLiteDatabase
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build

/**
 * Application (Flutter V2 embedding).
 * No custom plugin registrant callbacks are used.
 * Workmanager/plugin registration is handled by the framework and plugins themselves.
 */
class MyApp : Application() {
  private var unlockReceiver: UnlockReceiver? = null

  override fun onCreate() {
    super.onCreate()
    // 按需求：地点规则仅在解锁广播触发，不再使用 WorkManager 周期任务。
    // 这里仅清理历史遗留的周期 GeoWorker，避免误触发。
    try { GeoWorker.cancel(this) } catch (_: Throwable) {}
// Previously onCreate did nothing else.
  }

  private fun registerUnlockReceiver() {
    try {
      if (unlockReceiver == null) {
        val r = UnlockReceiver()
        val filter = IntentFilter().apply {
          addAction(Intent.ACTION_USER_PRESENT)
          addAction(Intent.ACTION_USER_UNLOCKED)
          addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(r, filter)
        unlockReceiver = r
        try {
          com.example.quote_app.data.DbRepo.log(this, null, "[App] registerUnlockReceiver ok")
        } catch (_: Throwable) {}
      }
    } catch (_: Throwable) {
      try {
        com.example.quote_app.data.DbRepo.log(this, null, "[App] registerUnlockReceiver failed")
      } catch (_: Throwable) {}
    }
  }

  /**
   * 作为解锁提醒的兜底逻辑：
   * - 理想情况：UnlockReceiver 能正常收到 USER_PRESENT 并直接发通知；
   * - 某些机型/电池策略过于激进时，广播可能收不到，这里在 App 启动时
   *   按一定规则补发一条提醒，避免完全收不到通知；同时加入限流，杜绝
   *   每次打开 App 都弹一条的情况。
   */
  private fun maybeSendUnlockReminderOnAppStart() {
    try {
      val prefs = getSharedPreferences("vision_prefs", Context.MODE_PRIVATE)
      val now = System.currentTimeMillis()

      // 1）如果刚刚是 UnlockReceiver 通过解锁事件发过一条（10 秒内），
      //    则此处不再重复发送。
      val lastUnlockReminder = prefs.getLong("last_unlock_reminder_time", 0L)
      if (lastUnlockReminder > 0L && (now - lastUnlockReminder) <= 10_000L) {
        return
      }

      // 2）兜底渠道增加冷却时间，防止频繁打开 App 被通知轰炸。
      // 默认值 30 分钟，如果 notify_config 中配置了 unlock_cooldown_minutes 或 unlock_cooldown_days，则覆盖默认值。
      var cooldownMs = 30L * 60L * 1000L
      try {
        val cc = com.example.quote_app.data.DbInspector.loadOrLightScan(this)
        if (cc != null && cc.dbPath != null) {
          val dbConf = SQLiteDatabase.openDatabase(cc.dbPath, null, SQLiteDatabase.OPEN_READONLY)
          // 优先读取天数配置
          try {
            val cDay = dbConf.rawQuery("SELECT value FROM notify_config WHERE key='unlock_cooldown_days' LIMIT 1", null)
            if (cDay.moveToFirst()) {
              val v = cDay.getString(0)
              try {
                val d = v?.toDouble()
                if (d != null && d > 0.0) {
                  cooldownMs = (d * 24.0 * 60.0 * 60.0 * 1000.0).toLong()
                }
              } catch (_: Throwable) {
                // ignore parse
              }
            }
            cDay.close()
          } catch (_: Throwable) {
            // ignore
          }
          // 如果未由天数配置覆盖，则读取分钟配置
          if (cooldownMs == 30L * 60L * 1000L) {
            try {
              val cMin = dbConf.rawQuery("SELECT value FROM notify_config WHERE key='unlock_cooldown_minutes' LIMIT 1", null)
              if (cMin.moveToFirst()) {
                val v2 = cMin.getString(0)
                try {
                  val m = v2?.toInt()
                  if (m != null && m > 0) {
                    cooldownMs = m.toLong() * 60L * 1000L
                  }
                } catch (_: Throwable) {
                  // ignore parse
                }
              }
              cMin.close()
            } catch (_: Throwable) {
              // ignore
            }
          }
          dbConf.close()
        }
      } catch (_: Throwable) {
        // ignore
      }
      val lastAppReminder = prefs.getLong("last_app_start_reminder_time", 0L)
      if (lastAppReminder > 0L && (now - lastAppReminder) <= cooldownMs) {
        return
      }

      // 3）判断是否需要兜底：
      //    - 如果从未记录过 unlock 时间（last_unlock_time == 0），说明很多
      //      机型根本收不到 USER_PRESENT，这种情况直接认为需要兜底；
      //    - 否则仅在“解锁后 10 秒内启动 App”时认为需要兜底。
      val lastUnlock = prefs.getLong("last_unlock_time", 0L)
      val needFallback = if (lastUnlock == 0L) {
        true
      } else {
        (now - lastUnlock) <= 10_000L
      }
      if (!needFallback) {
        return
      }

      // 4）确认数据库中确实存在已启用的 screen_unlock 触发规则
      val contract = DbInspector.loadOrLightScan(this)
      if (contract == null || contract.dbPath == null) return
      val path = contract.dbPath!!
      val db = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY)
      val c = db.rawQuery(
        "SELECT config FROM vision_triggers WHERE type='screen_unlock' AND enabled=1 LIMIT 1",
        null
      )
      val has = c.moveToFirst()
      c.close()
      db.close()
      if (has) {
        NotifyHelper.send(this, 2000, "愿景提醒", "别忘了你的一件事！", null, "vision_focus", null)
        // 记录为一次 App 启动兜底提醒，30 分钟内不再触发
        prefs.edit().putLong("last_app_start_reminder_time", now).apply()
      }
    } catch (_: Throwable) {
      // swallow errors，避免影响 App 启动
    }
  }
}