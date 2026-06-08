package com.example.quote_app

import android.app.Application
import android.app.Activity
import android.app.ActivityManager
import android.app.KeyguardManager
import android.os.PowerManager
import android.os.Bundle
import com.example.quote_app.GeoWorker
import com.example.quote_app.NotifyHelper
import com.example.quote_app.data.DbInspector
import android.database.sqlite.SQLiteDatabase
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import android.content.pm.PackageManager
import java.security.MessageDigest
import androidx.work.Data
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * Application (Flutter V2 embedding).
 * No custom plugin registrant callbacks are used.
 * Workmanager/plugin registration is handled by the framework and plugins themselves.
 */
class App : Application(), Application.ActivityLifecycleCallbacks {
  private var unlockReceiver: UnlockReceiver? = null
  private var startedActivities: Int = 0
  private var didSyntheticUnlockInThisProcess: Boolean = false
  private val SP_QUOTE = "quote_prefs"
  private val KEY_PROC_START_TS = "proc_start_ts"

  override fun onCreate() {
    super.onCreate()
    registerActivityLifecycleCallbacks(this)

    // NOTE: Application.onCreate() runs in every process of this app (including ":remote").
    // Heavy init + broadcast registrations should only run in the main process, otherwise:
    // - Baidu Location remote process crashes/restarts can spam logs ("动态解锁接收器注册成功...")
    // - unnecessary receivers are registered in the :remote process.
    val isMain = isMainProcess()

    // ---- Baidu SDK common init (runs in all processes, including ":remote") ----
    // Location SDK privacy + AK must be set before any LocationClient usage.
    try {
      try { com.baidu.location.LocationClient.setAgreePrivacy(true) } catch (_: Throwable) {}
      val ak = try { readBaiduAkForMapSdk(applicationContext) } catch (_: Throwable) { "oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh" }

      // 仅在主进程打印一次：帮助排查百度 AK 与签名(SHA1)/包名不匹配（locType=505）
      if (isMain) {
        try {
          val sha1 = getSigningSha1(applicationContext) ?: "na"
          Log.i("App", "Baidu AK=${maskAk(ak)}, package=${applicationContext.packageName}, sha1=$sha1, process=${getProcessNameSafe()}")
        
          com.example.quote_app.data.DbRepo.log(
            applicationContext,
            null,
            "【App】Baidu AK=${maskAk(ak)}, package=${applicationContext.packageName}, sha1=$sha1, process=${getProcessNameSafe()}"
          )
} catch (_: Throwable) {}
      }

      // Location SDK requires explicit AK; use reflection to avoid version-coupling.
      invokeBaiduSdkStatic("com.baidu.location.LocationClient", "setKey", ak)

      // ---- Baidu Map/Search init (main process only) ----
      if (isMain) {
        try { com.baidu.mapapi.SDKInitializer.setAgreePrivacy(applicationContext, true) } catch (_: Throwable) {}
        invokeBaiduSdkStatic("com.baidu.mapapi.SDKInitializer", "setApiKey", ak)
        try { com.baidu.mapapi.SDKInitializer.initialize(applicationContext) } catch (_: Throwable) {}
        try { com.baidu.mapapi.SDKInitializer.setCoordType(com.baidu.mapapi.CoordType.BD09LL) } catch (_: Throwable) {}
        invokeBaiduSdkStatic("com.baidu.mapapi.SDKInitializer", "setHttpsEnable", true)
      }
    } catch (_: Throwable) {}

    if (isMain) {
      // 记录本次主进程启动时间：用于“解锁广播未回放/被系统忽略”时在前台做一次合成补偿。
      // 说明：USER_PRESENT/SCREEN_ON 等系统广播不是粘性的；
      // 当解锁发生在进程未运行期间，回到前台也不会再收到一次广播。
      try {
        val now = System.currentTimeMillis()
        applicationContext
          .getSharedPreferences(SP_QUOTE, Context.MODE_PRIVATE)
          .edit()
          .putLong(KEY_PROC_START_TS, now)
          .apply()
        didSyntheticUnlockInThisProcess = false
      } catch (_: Throwable) {
        // ignore
      }

      // 按需求：地点规则不再使用 WorkManager 周期任务；这里取消历史遗留的周期 GeoWorker，避免误触发。
      try { GeoWorker.cancel(this) } catch (_: Throwable) {}

      // 无常驻通知的命中率增强：若用户开启了解锁轻提醒或地点规则开关，
      // 则启动低频脉冲兜底探测（不取定位，只有检测到解锁跃迁才触发业务）。
      try { UnlockPulse.ensureScheduledIfNeeded(this) } catch (_: Throwable) {}

      // 兜底：定期用 WorkManager 重新确保 UnlockPulse 的 Alarm 仍存在。
      // 说明：
      // - 不依赖解锁/亮屏广播（Android 8+ 对 manifest 隐式广播有限制）；
      // - 即使用户“清理后台/移除最近任务”导致进程被杀，也尽量在后续恢复调度；
      // - 电量友好：无需 15min 频率，改为更低频的周期恢复（不做定位）。
      try { schedulePulseRearmWorker() } catch (_: Throwable) {}

      // 关键：只要进程还活着，解锁广播就会进 UnlockReceiver
      registerUnlockReceiver()

      // 注册 SCREEN_ON 探测接收器（仅用于确认是否已解锁，不直接触发业务）
      try {
        val f2 = android.content.IntentFilter().apply { addAction(android.content.Intent.ACTION_SCREEN_ON) }
        val r2 = ScreenOnProbeReceiver()
        if (android.os.Build.VERSION.SDK_INT >= 33) {
          // SCREEN_ON 由系统/系统组件发送；部分 ROM 下 NOT_EXPORTED 可能导致回调不稳定。
          registerReceiver(r2, f2, RECEIVER_EXPORTED)
        } else {
          @Suppress("DEPRECATION")
          registerReceiver(r2, f2)
        }
        com.example.quote_app.data.DbRepo.log(this, null, "【App】runtime SCREEN_ON 探测接收器已注册（仅用于确认已解锁，不直接触发业务）")
      } catch (_: Throwable) {}

      // 行为预设闹钟：每次主进程启动时轻量恢复未来闹钟。
      // 这能覆盖用户升级/系统清理/ROM 丢失 PendingIntent 后，仅打开一次 App 即恢复后续 setAlarmClock 触发。
      try { BehaviorPresetAlarmScheduler.rescheduleUpcoming(applicationContext) } catch (_: Throwable) {}

      // 说明：按需求“仅解锁广播触发提醒”，不再在 App 启动时兜底补发解锁提醒。
    }
  }

  private fun schedulePulseRearmWorker() {
    // 电量友好：周期兜底不需要过于频繁。
    // - 该 Worker 只做“恢复 UnlockPulse 调度”，不做定位/不发通知；
    // - 仍应尽量减少后台唤醒：这里改为 2 小时一次，并在电量低时暂停。
    val data = Data.Builder().putString("job", "wm_pulse_rearm").build()
    val constraints = Constraints.Builder()
      .setRequiresBatteryNotLow(true)
      .build()
    val req = PeriodicWorkRequestBuilder<AlarmProxyWorker>(2, TimeUnit.HOURS)
      .setConstraints(constraints)
      .setInputData(data)
      .build()
    WorkManager.getInstance(applicationContext)
      .enqueueUniquePeriodicWork("wm_pulse_rearm", ExistingPeriodicWorkPolicy.UPDATE, req)
  }

  private fun isMainProcess(): Boolean {
    // API 28+ provides Application.getProcessName(); older devices use ActivityManager.
    val pn = packageName
    val current = try {
      if (Build.VERSION.SDK_INT >= 28) {
        Application.getProcessName()
      } else {
        getProcessNameCompat()
      }
    } catch (_: Throwable) {
      null
    }
    return current == null || current == pn
  }

  private fun getProcessNameCompat(): String? {
    return try {
      val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
      val myPid = android.os.Process.myPid()
      val procs = am?.runningAppProcesses ?: return null
      for (p in procs) {
        if (p.pid == myPid) return p.processName
      }
      null
    } catch (_: Throwable) {
      null
    }
  }

  private fun getProcessNameSafe(): String {
    return try {
      if (Build.VERSION.SDK_INT >= 28) {
        Application.getProcessName()
      } else {
        getProcessNameCompat() ?: "unknown"
      }
    } catch (_: Throwable) {
      "unknown"
    }
  }



  private fun registerUnlockReceiver() {
    try {
      if (unlockReceiver == null) {
        val r = UnlockReceiver()
        val filter = IntentFilter().apply {
          // 仅监听解锁事件（USER_PRESENT / USER_UNLOCKED），避免多余广播干扰
          addAction(Intent.ACTION_USER_PRESENT)
          addAction(Intent.ACTION_USER_UNLOCKED)
        }

        if (Build.VERSION.SDK_INT >= 33) {
          // Android 13+：部分解锁相关广播可能来自高权限应用（如 SystemUI）。
          // 使用 RECEIVER_EXPORTED 以确保能收到这些系统广播。
          // 安全性：UnlockReceiver 内部会再次校验“确实已解锁”并做冷却去重。
          registerReceiver(r, filter, RECEIVER_EXPORTED)
        } else {
          @Suppress("DEPRECATION")
          registerReceiver(r, filter)
        }

        unlockReceiver = r
        try {
          com.example.quote_app.data.DbRepo.log(this, null, "【App】动态解锁接收器注册成功，只监听解锁事件 ACTION_USER_PRESENT/ACTION_USER_UNLOCKED（回包：OK）")
        } catch (_: Throwable) {}
      }
    } catch (_: Throwable) {
      try {
        com.example.quote_app.data.DbRepo.log(this, null, "【App】动态解锁接收器注册失败（回包：FAIL）")
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

      // 仅当“最近一次解锁”发生在 5 秒内，才认为是解锁相关的启动；否则不发送兜底提醒
      try {
        val sp = getSharedPreferences("quote_prefs", Context.MODE_PRIVATE)
        val lastUp = sp.getLong("last_user_present_ts", 0L)
        if (lastUp <= 0L || (now - lastUp) > 5000L) {
          try { com.example.quote_app.data.DbRepo.log(this, null, "【App】启动兜底检查：最近未发生解锁（>5s），本次不发送愿景提醒（回包：SKIP）") } catch (_: Throwable) {}
          return
        }
      } catch (_: Throwable) {}

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

    
    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        if (activity is io.flutter.embedding.android.FlutterActivity) {
            try {
                // 通过反射获取 flutterEngine，避免直接访问受保护的属性。
                val field = io.flutter.embedding.android.FlutterActivity::class.java.getDeclaredField("flutterEngine")
                field.isAccessible = true
                val engine = field.get(activity) as? io.flutter.embedding.engine.FlutterEngine
	                if (engine != null) {
	                    // 注意：SysChannel 与 Channels 使用相同 MethodChannel 名称（com.example.quote_app/sys）。
	                    // 为避免 handler 被覆盖导致系统/权限相关方法丢失，这里仅注册 Channels。
	                    try { Channels.register(engine, applicationContext) } catch (_: Throwable) {}
	                }
            } catch (_: Throwable) {
                // 忽略，保持兼容
            }
        }
    }
    override fun onActivityStarted(activity: Activity) {
        try { startedActivities = (startedActivities + 1).coerceAtLeast(0) } catch (_: Throwable) { startedActivities = 0 }
    }
    override fun onActivityResumed(activity: Activity) {
        // 前台补偿（严格收敛）：
        // 仅当“确实发生了解锁事件（last_user_present_ts 近期更新）但链路尚未触发”时，才允许在前台补偿一次。
        // 这样可避免“仅仅重新打开 App 也触发解锁轻提醒/地点规则提醒”的误触。
        try { maybeSynthesizeUnlockOnForeground(applicationContext, source = "activity_resumed") } catch (_: Throwable) {}
    }
    override fun onActivityPaused(activity: Activity) {}
    override fun onActivityStopped(activity: Activity) {
        try { startedActivities = (startedActivities - 1).coerceAtLeast(0) } catch (_: Throwable) { startedActivities = 0 }
        // UI 全部不可见：用户可能把任务移除/清理后台。
        // 这里安排：
        // 1) 一次“很快到期的非唤醒脉冲”（5s）：如果随后锁屏，该脉冲会在用户下次亮屏/解锁时被系统补投递，
        //    从而不依赖 USER_PRESENT/SCREEN_ON 是否投递（它们在后台/移除任务后经常丢失）。
        // 2) 一次低频“锚点”wakeup alarm：用于部分 ROM 会在“移除最近任务/清理后台”后清掉普通 alarm 的场景。
        if (startedActivities == 0) {
            try {
                UnlockPulse.scheduleNext(applicationContext, delayMs = 5000L, preferExact = false, wakeup = false)
                UnlockPulse.logWithTime(applicationContext, "【解锁脉冲】ui_hidden scheduled due-soon tick delayMs=5000")
            } catch (_: Throwable) {}
            try { UnlockPulse.scheduleAnchorWakeupIfNeeded(applicationContext, source = "ui_hidden") } catch (_: Throwable) {}
        }
    }
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
    override fun onActivityDestroyed(activity: Activity) {}


  /**
   * 合成解锁触发（前台补偿）：
   * - 解决“解锁发生在进程未运行期间，回到前台也不会再收到广播”的误解/缺口。
   * - 仅在短窗口内触发一次，且依旧遵循原有冷却/开关逻辑（由 UnlockEventHandler 与 GeoUnlockOrchestrator 控制）。
   */
  private fun maybeSynthesizeUnlockOnForeground(ctx: Context, source: String) {
    if (didSyntheticUnlockInThisProcess) return
    val app = ctx.applicationContext
    val now = System.currentTimeMillis()
    val sp = try { app.getSharedPreferences(SP_QUOTE, Context.MODE_PRIVATE) } catch (_: Throwable) { null }
    val lastUnlockTrigger = try { sp?.getLong("last_unlock_trigger_ts", 0L) ?: 0L } catch (_: Throwable) { 0L }
    val lastUserPresent = try { sp?.getLong("last_user_present_ts", 0L) ?: 0L } catch (_: Throwable) { 0L }

    // 最近 8 秒已经触发过解锁链路：无需合成
    if (lastUnlockTrigger > 0L && (now - lastUnlockTrigger) < 8000L) return

    // 仅在“确实发生了解锁事件（last_user_present_ts 更新）后的短窗口内”补偿：
    // - 避免仅仅重新打开 App 也触发通知。
    // - 同时要求该解锁事件尚未被链路消费（last_unlock_trigger_ts < last_user_present_ts）。
    if (lastUserPresent <= 0L) return
    if ((now - lastUserPresent) > 30_000L) return
    if (lastUnlockTrigger > 0L && lastUnlockTrigger >= lastUserPresent) return

    // 设备当前必须处于“亮屏且未上锁”
    val pm = try { app.getSystemService(Context.POWER_SERVICE) as? PowerManager } catch (_: Throwable) { null }
    val km = try { app.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager } catch (_: Throwable) { null }
    val interactive = try { pm?.isInteractive ?: true } catch (_: Throwable) { true }
    val locked = try { km?.isKeyguardLocked ?: false } catch (_: Throwable) { false }
    if (!interactive || locked) return

    // 标记本进程只做一次，防止多次 onResume 重复触发
    didSyntheticUnlockInThisProcess = true

    // 写入 trigger_ts 以便与其他入口去重
    try {
      sp?.edit()
        ?.putLong("last_unlock_trigger_ts", now)
        ?.apply()
    } catch (_: Throwable) {}

    try {
      com.example.quote_app.data.DbRepo.log(app, null, "【合成解锁】满足补偿条件，开始执行解锁链路 source=$source")
    } catch (_: Throwable) {}

    kotlin.concurrent.thread(name = "synthetic-unlock") {
      try {
        try { UnlockEventHandler.markUnlockChainInflight(app, source = "synthetic:$source") } catch (_: Throwable) {}
        UnlockEventHandler.withHighPriority(app, "synthetic:$source") {
          try { UnlockEventHandler.handleUnlockLightReminder(app, source = "synthetic:$source") } catch (_: Throwable) {}
          try { GeoUnlockOrchestrator.run(app, "synthetic:$source") } catch (_: Throwable) {}
        }
      } finally {
        try { UnlockEventHandler.markUnlockChainDone(app, source = "synthetic:$source") } catch (_: Throwable) {}
      }
    }
  }

  private fun isGeoRulesEnabled(ctx: Context): Boolean {
    return try {
      val cc = DbInspector.loadOrLightScan(ctx) ?: return false
      val db = SQLiteDatabase.openDatabase(
        cc.dbPath,
        null,
        SQLiteDatabase.OPEN_READONLY
      )
      try {
        var enabled = false
        try {
          db.rawQuery(
            "SELECT location_rules_enabled FROM configs ORDER BY id DESC LIMIT 1",
            null
          ).use { c ->
            if (c.moveToFirst()) {
              enabled = (c.getInt(0) == 1)
            }
          }
        } catch (_: Throwable) {
        }
        enabled
      } finally {
        try {
          db.close()
        } catch (_: Throwable) {
        }
      }
    } catch (_: Throwable) {
      false
    }
  }

private fun readBaiduAkForMapSdk(ctx: Context): String {
  // Android AK：用于 Baidu Location/Map/Search SDK（包名+SHA1 绑定）
  val defAndroid = "oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh"
  val defWeb = "kmHcLsW5heS5miYWLpbRUsrQapGIJ5m2"
  return try {
    val cc = DbInspector.loadOrLightScan(ctx)
    val path = cc?.dbPath
    if (path.isNullOrEmpty()) return defAndroid
    // 防御：prefs 残留无效 dbPath 时避免 openDatabase 报错
    try {
      val f = java.io.File(path)
      if (!f.exists() || !f.isFile) return defAndroid
    } catch (_: Throwable) {
      return defAndroid
    }
    val db = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY)
    try {
      var vAndroid: String? = null
      try {
        db.rawQuery("SELECT baidu_ak_android FROM configs LIMIT 1", null).use { c ->
          if (c.moveToFirst()) vAndroid = c.getString(0)
        }
      } catch (_: Throwable) {
        // ignore when table/column missing
      }

      // 兼容老版本：如果新列为空，但旧列里存的是“自定义 AK”（且不是默认 Web AK），则沿用旧列
      if (vAndroid == null || vAndroid!!.trim().isEmpty()) {
        var vOld: String? = null
        try {
          db.rawQuery("SELECT baidu_ak FROM configs LIMIT 1", null).use { c ->
            if (c.moveToFirst()) vOld = c.getString(0)
          }
        } catch (_: Throwable) {}
        if (vOld != null) {
          val vv = vOld!!.trim()
          if (vv.isNotEmpty() && vv != defWeb) vAndroid = vv
        }
      }

      val out = vAndroid?.trim() ?: ""
      if (out.isEmpty()) defAndroid else out
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
  } catch (_: Throwable) {
    defAndroid
  }
}


  private fun maskAk(ak: String): String {
    return try {
      if (ak.length <= 8) "***"
      else ak.substring(0, 4) + "****" + ak.substring(ak.length - 4)
    } catch (_: Throwable) { "***" }
  }

  /** 获取当前安装包签名证书 SHA1（用于百度控制台 Android SDK 安全码校验）。失败返回 null。 */
  private fun getSigningSha1(ctx: Context): String? {
    return try {
      val pm = ctx.packageManager
      val pi = if (Build.VERSION.SDK_INT >= 28) {
        pm.getPackageInfo(ctx.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
      } else {
        @Suppress("DEPRECATION")
        pm.getPackageInfo(ctx.packageName, PackageManager.GET_SIGNATURES)
      }

      val sigBytes: ByteArray? = if (Build.VERSION.SDK_INT >= 28) {
        val si = pi.signingInfo ?: return null
        val sigs = if (si.hasMultipleSigners()) si.apkContentsSigners else si.signingCertificateHistory
        if (sigs.isNotEmpty()) sigs[0].toByteArray() else null
      } else {
        @Suppress("DEPRECATION")
        run {
          val sigs = pi.signatures
          if (sigs != null && sigs.isNotEmpty()) sigs[0].toByteArray() else null
        }
      }

      if (sigBytes == null) return null
      val md = MessageDigest.getInstance("SHA1")
      val digest = md.digest(sigBytes)
      digest.joinToString(":") { b -> "%02X".format(b) }
    } catch (_: Throwable) {
      null
    }
  }

  private fun invokeBaiduSdkStatic(className: String, methodName: String, vararg args: Any?) {
    try {
      val clazz = Class.forName(className)
      val methods = clazz.methods
      for (m in methods) {
        if (m.name == methodName && m.parameterTypes.size == args.size) {
          try { m.invoke(null, *args) } catch (_: Throwable) {}
          return
        }
      }
    } catch (_: Throwable) {}
  }


  // Public entry for Flutter to ensure dynamic unlock receivers are registered.
  fun ensureUnlockReceiverRegistered() {
    try { registerUnlockReceiver() } catch (_: Throwable) {}
  }
}