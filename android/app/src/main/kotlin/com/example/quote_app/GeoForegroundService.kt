package com.example.quote_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import androidx.core.app.NotificationCompat
import com.example.quote_app.data.DbRepo
import kotlin.concurrent.thread

class GeoForegroundService : Service() {

  private val CHANNEL_ID = "geo_fg_channel"
  private val NOTIF_ID = 7771001

  private val SP = "quote_prefs"
  private val KEY_LAST_FG_KICK = "last_geo_fg_kick_ts"

  override fun onBind(intent: Intent?) = null

  override fun onCreate() {
    super.onCreate()
    try { logWithTime(this, "【前台服务-地点规则】onCreate") } catch (_: Throwable) {}
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    // 第一时间启动前台
    val notif = buildOngoingNotification("正在获取位置...")
    try {
      if (Build.VERSION.SDK_INT >= 29) {
        // 显式声明 FGS 类型，部分 Android 13/14 机型若未声明可能导致定位被系统降级/拦截。
        startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
      } else {
        startForeground(NOTIF_ID, notif)
      }
    } catch (_: Throwable) {
      // 兜底：保持兼容旧机型
      startForeground(NOTIF_ID, notif)
    }
    // 记录启动前台服务的日志
    try { logWithTime(this, "【前台服务-地点规则】已调用 startForeground，开始在前台运行") } catch (_: Throwable) {}
    thread(name = "geo-fg-exec") {
      try {
        executeCore()
      } catch (t: Throwable) {
        try { logWithTime(this, "【前台服务-地点规则】执行失败：" + (t.message ?: "unknown")) } catch (_: Throwable) {}
      } finally {
        try {
          // 尽快移除前台通知，避免常驻
          try {
            if (Build.VERSION.SDK_INT >= 24) {
              stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
              @Suppress("DEPRECATION")
              stopForeground(true)
            }
          } catch (_: Throwable) {
            @Suppress("DEPRECATION")
            try { stopForeground(true) } catch (_: Throwable) {}
          }
          stopSelf()
          // 记录销毁前台服务的日志
          try { logWithTime(this, "【前台服务-地点规则】前台服务已停止并销毁") } catch (_: Throwable) {}
        } catch (_: Throwable) {}
      }
    }
    return START_NOT_STICKY
  }

  private fun buildOngoingNotification(text: String): Notification {
    if (Build.VERSION.SDK_INT >= 26) {
      val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      // 为保证后台解锁场景下系统确实将服务视为“可见的前台服务”，
      // 这里使用 IMPORTANCE_LOW（仍然静默、不震动、不出声），避免部分 ROM 在 MIN 级别下抑制通知导致定位被降级。
      val ch = NotificationChannel(CHANNEL_ID, "地点规则检测", NotificationManager.IMPORTANCE_LOW).apply {
        setShowBadge(false)
        enableVibration(false)
        enableLights(false)
        setSound(null, null)
      }
      nm.createNotificationChannel(ch)
    }
    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle("愿景提醒")
      .setContentText(text)
      .setSmallIcon(android.R.drawable.ic_menu_mylocation)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .setSilent(true)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setVisibility(NotificationCompat.VISIBILITY_SECRET)
      .build()
  }

  private fun executeCore() {
    val ctx = this

    // 1) 配置开关
    if (!GeoRuleEngine.isGeoEnabled(ctx)) {
      try { logWithTime(ctx, "【前台服务-地点规则】开关=关闭，直接返回") } catch (_: Throwable) {}
      return
    }

    // 2) 读取所有启用地点规则（遍历）
    val targets = GeoRuleEngine.loadTargets(ctx)
    if (targets.isEmpty()) {
      try { logWithTime(ctx, "【前台服务-地点规则】未找到启用的地点规则，返回") } catch (_: Throwable) {}
      return
    }

    // 3) 获取当前位置：对齐“新增地点规则-手动定位”的系统定位实现（SysChannel.getSystemLocationOnce）
    //    - 更长的收敛时间
    //    - 不依赖主线程 Looper（避免解锁瞬间主线程未就绪/卡顿导致无回调）
    //    - best-effort：即便未达到 targetAcc，也返回 timeout 内的最优位置
    try {
      val env = LocationCore.debugEnv(ctx)
      logWithTime(ctx, "【前台服务-地点规则】定位环境：$env")
    } catch (_: Throwable) {}

    try { logWithTime(ctx, "【前台服务-地点规则】开始系统高精度流定位（mainLooper回调注册，best-effort）") } catch (_: Throwable) {}
    var loc: Location? = runCatching {
      // 在解锁/后台场景下，部分 ROM 对“非主线程 looper 注册定位回调”存在吞回调的问题。
      // 这里强制采用 mainLooper 注册回调（与 SysChannel.getSystemLocationOnce 更一致），并在本线程 await。
      LocationCore.getSystemHighAccLikeManualOnMainLooperOnly(
        ctx,
        targetAccMeters = 80.0,
        fusedTimeoutMs = 12_000L,
        gpsTimeoutMs = 8_000L
      )
    }.getOrNull()
    if (loc != null) {
      try { logWithTime(ctx, "【前台服务-地点规则】系统高精度流定位成功 acc=${loc.accuracy}") } catch (_: Throwable) {}
    } else {
      try { logWithTime(ctx, "【前台服务-地点规则】系统高精度流定位失败（无回调/超时/受限），将尝试百度SDK兜底") } catch (_: Throwable) {}
    }

    if (loc == null) {
      val ak = getBaiduAk(ctx)
      loc = runCatching { obtainBaiduLocation(ctx, ak, 60.0, 8_000L) }.getOrNull()
      if (loc != null) {
        try { logWithTime(ctx, "【前台服务-地点规则】百度SDK定位成功 acc=${loc.accuracy}") } catch (_: Throwable) {}
      }
    }

    if (loc == null) {
      loc = LocationCore.getLastKnown(ctx)
      if (loc != null) {
        try { logWithTime(ctx, "【前台服务-地点规则】使用最近已知位置 acc=${loc.accuracy}") } catch (_: Throwable) {}
      }
    }

    if (loc == null) {
      try { logWithTime(ctx, "【前台服务-地点规则】无法获取位置，返回") } catch (_: Throwable) {}
      // 若未拿到位置，允许下一次解锁尽快再次兜底（避免 15s 去重导致连续失败时“永远跳过”）
      try {
        ctx.getSharedPreferences(SP, Context.MODE_PRIVATE).edit().putLong(KEY_LAST_FG_KICK, 0L).apply()
      } catch (_: Throwable) {}
      return
    }

    // 4) 遍历比对并通知（只要命中任意一个目标就发送一次）
    GeoRuleEngine.evaluateAndNotify(ctx, loc, targets, radiusMeters = 100.0)
  }

  /**
   * 写入包含时间戳的日志。所有地点规则前台服务的日志都通过此方法统一前缀当前时间，
   * 便于调试和排查问题。
   */
  private fun logWithTime(ctx: Context, msg: String) {
    try {
      val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault())
      val now = sdf.format(java.util.Date())
      DbRepo.log(ctx, null, "[$now] $msg")
    } catch (_: Throwable) {
      // fallback to original log without timestamp
      try { DbRepo.log(ctx, null, msg) } catch (_: Throwable) {}
    }
  }

  private fun getBaiduAk(ctx: Context): String {
    val defAndroid = "oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh"
    val defWeb = "kmHcLsW5heS5miYWLpbRUsrQapGIJ5m2"
    return try {
      val cc = com.example.quote_app.data.DbInspector.loadOrLightScan(ctx) ?: return defAndroid
      val db = android.database.sqlite.SQLiteDatabase.openDatabase(cc.dbPath, null, android.database.sqlite.SQLiteDatabase.OPEN_READONLY)
      try {
        var v: String? = null
        try {
          db.rawQuery("SELECT baidu_ak_android FROM configs LIMIT 1", null).use { c ->
            if (c.moveToFirst()) v = c.getString(0)
          }
        } catch (_: Throwable) {}

        if (v == null || v!!.trim().isEmpty()) {
          // 兼容旧列：仅当旧列不是默认 Web AK 才沿用
          var oldV: String? = null
          try {
            db.rawQuery("SELECT baidu_ak FROM configs LIMIT 1", null).use { c ->
              if (c.moveToFirst()) oldV = c.getString(0)
            }
          } catch (_: Throwable) {}
          if (oldV != null) {
            val vv = oldV!!.trim()
            if (vv.isNotEmpty() && vv != defWeb) v = vv
          }
        }

        val out = v?.trim() ?: ""
        if (out.isEmpty()) defAndroid else out
      } finally { try { db.close() } catch (_: Throwable) {} }
    } catch (_: Throwable) { defAndroid }
  }

  // obtainBaiduLocation 仍保留作为兜底：通过反射调用百度定位（若依赖不可用将直接返回 null）

  // 通过反射调用百度定位（若依赖不可用将直接返回 null）
  private fun obtainBaiduLocation(ctx: Context, ak: String, targetAccMeters: Double, timeoutMs: Long): Location? {
    // 与 SysChannel.obtainBaiduLocation 保持一致：一次定位 + latest + latch 等待（无 Thread.sleep 轮询）
    return try {
      val clazz = Class.forName("com.baidu.location.LocationClient")
      val optionClazz = Class.forName("com.baidu.location.LocationClientOption")
      val locClient = clazz.getConstructor(Context::class.java).newInstance(ctx)
      val opt = optionClazz.getConstructor().newInstance()
      try { optionClazz.getMethod("setLocationCacheEnable", java.lang.Boolean.TYPE).invoke(opt, false) } catch (_: Throwable) {}
      try { optionClazz.getMethod("setOnceLocation", java.lang.Boolean.TYPE).invoke(opt, true) } catch (_: Throwable) {}
      try { optionClazz.getMethod("setOnceLocationLatest", java.lang.Boolean.TYPE).invoke(opt, true) } catch (_: Throwable) {}
      optionClazz.getMethod("setOpenGps", Boolean::class.javaPrimitiveType).invoke(opt, true)
      optionClazz.getMethod("setCoorType", String::class.java).invoke(opt, "bd09ll")
      optionClazz.getMethod("setScanSpan", Int::class.javaPrimitiveType).invoke(opt, 0)
      optionClazz.getMethod("setIsNeedAddress", Boolean::class.javaPrimitiveType).invoke(opt, false)
      clazz.getMethod("setLocOption", optionClazz).invoke(locClient, opt)

      val listenerClazz = Class.forName("com.baidu.location.BDAbstractLocationListener")
      val latch = java.util.concurrent.CountDownLatch(1)
      var best: Location? = null
      var seen = 0

      val proxy = java.lang.reflect.Proxy.newProxyInstance(listenerClazz.classLoader, arrayOf(listenerClazz)) { _, method, args ->
        if (method.name == "onReceiveLocation" && args != null && args.isNotEmpty()) {
          val bdLoc = args[0]
          try {
            seen++
            val la = bdLoc.javaClass.getMethod("getLatitude").invoke(bdLoc) as Double
            val lo = bdLoc.javaClass.getMethod("getLongitude").invoke(bdLoc) as Double
            val acc = (bdLoc.javaClass.getMethod("getRadius").invoke(bdLoc) as Number).toFloat()
            val l = Location("baidu"); l.latitude = la; l.longitude = lo; l.accuracy = acc
            if (best == null || l.accuracy < best!!.accuracy) best = l
            if (best != null && best!!.accuracy <= targetAccMeters && seen >= 2) {
              try { latch.countDown() } catch (_: Throwable) {}
            }
          } catch (_: Throwable) {}
        }
        null
      }

      clazz.getMethod("registerLocationListener", listenerClazz).invoke(locClient, proxy)
      clazz.getMethod("start").invoke(locClient)
      try { latch.await(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS) } catch (_: Throwable) {}
      try { clazz.getMethod("stop").invoke(locClient) } catch (_: Throwable) {}
      best
    } catch (_: Throwable) {
      null
    }
  }

}
