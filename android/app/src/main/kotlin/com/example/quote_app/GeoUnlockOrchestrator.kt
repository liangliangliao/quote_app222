package com.example.quote_app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.example.quote_app.data.DbRepo

/**
 * 方案B（解锁触发地点规则）
 * - 优先走“无前台服务”快路径：在 1.5s 内尝试获取系统高精度位置并完成地点规则匹配
 * - 若快路径无法获取到足够可靠的位置，则启动 GeoForegroundService 兜底（通知只在服务运行期间短暂出现）
 * - 服务完成后会立刻 stopForeground + stopSelf，不会常驻
 */
object GeoUnlockOrchestrator {

  private const val SP = "quote_prefs"
  private const val KEY_LAST_FG_KICK = "last_geo_fg_kick_ts"
  private const val KEY_LAST_GEO_RUN = "last_geo_unlock_run_ts"
  private const val GEO_RUN_DEDUP_MS = 12_000L

  // 快路径最长等待（毫秒）
  private const val FAST_TIMEOUT_MS = 1500L

  // 快路径接受的最大误差（过大则视为不可靠，转兜底）
  private const val FAST_MAX_ACC = 120.0

  // 前台兜底的最小触发间隔，避免频繁闪通知
  private const val FG_DEDUP_MS = 15_000L

  @JvmStatic
  fun run(ctx: Context, reason: String) {
    val app = ctx.applicationContext

    // 运行去重：避免一次解锁窗口内多入口并发（screen_on_probe / pulse / user_present / wm）导致重复地点规则通知。
    try {
      val sp = app.getSharedPreferences(SP, Context.MODE_PRIVATE)
      val now = System.currentTimeMillis()
      val last = sp.getLong(KEY_LAST_GEO_RUN, 0L)
      if (last > 0L && (now - last) < GEO_RUN_DEDUP_MS) {
        try { logWithTime(app, "【解锁-地点规则】${GEO_RUN_DEDUP_MS}ms 内已执行过，跳过重复（reason=$reason 回包：SKIP_DUP）") } catch (_: Throwable) {}
        return
      }
      sp.edit().putLong(KEY_LAST_GEO_RUN, now).apply()
    } catch (_: Throwable) {}

    // 0) 开关 & 目标列表预检：避免无意义启动
    if (!GeoRuleEngine.isGeoEnabled(app)) return
    val targets = GeoRuleEngine.loadTargets(app)
    if (targets.isEmpty()) return

    // 1) 无前台服务快路径：尽量在解锁后立刻出结果
    try {
      val loc = LocationCore.getSystemHighAcc(app, targetAccMeters = 80.0, timeoutMs = FAST_TIMEOUT_MS)
      if (loc != null && loc.accuracy <= FAST_MAX_ACC) {
        try { logWithTime(app, "【解锁-地点规则】快路径系统定位成功 acc=${loc.accuracy}m，将遍历目标位置") } catch (_: Throwable) {}
        val hit = GeoRuleEngine.evaluateAndNotify(app, loc, targets, radiusMeters = 100.0)
        if (hit) return
        // 不命中时不启动前台兜底（避免误报/扰民）
        return
      }

      // lastKnown 仅作为“最近且还算靠谱”时的加速手段
      val last = LocationCore.getLastKnown(app)
      if (last != null) {
        val age = System.currentTimeMillis() - last.time
        if (age <= 60_000L && last.accuracy <= FAST_MAX_ACC) {
          try { logWithTime(app, "【解锁-地点规则】快路径使用 recent lastKnown acc=${last.accuracy}m age=${age}ms") } catch (_: Throwable) {}
          val hit = GeoRuleEngine.evaluateAndNotify(app, last, targets, radiusMeters = 100.0)
          if (hit) return
          return
        }
      }

      try { logWithTime(app, "【解锁-地点规则】快路径未拿到可靠位置（reason=$reason），将启动前台服务兜底") } catch (_: Throwable) {}
    } catch (_: Throwable) {
      try { logWithTime(app, "【解锁-地点规则】快路径异常（reason=$reason），将启动前台服务兜底") } catch (_: Throwable) {}
    }

    // 2) 兜底：启动前台服务（短生命周期）
    kickForegroundGeo(app, reason)
  }

  private fun kickForegroundGeo(ctx: Context, reason: String) {
    // 去重：避免 USER_PRESENT + SCREEN_ON 探测导致短时间重复启动
    try {
      val sp = ctx.getSharedPreferences(SP, Context.MODE_PRIVATE)
      val now = System.currentTimeMillis()
      val last = sp.getLong(KEY_LAST_FG_KICK, 0L)
      if (last > 0 && (now - last) < FG_DEDUP_MS) {
        try { logWithTime(ctx, "【解锁-地点规则】前台兜底 15s 内已启动过，跳过重复（回包：SKIP_DUP）") } catch (_: Throwable) {}
        return
      }
      sp.edit().putLong(KEY_LAST_FG_KICK, now).apply()
    } catch (_: Throwable) {}

    // 权限检查：Android 14+ 若无定位权限启动 location 前台服务会崩
    if (!hasAnyLocationPermission(ctx)) {
      try { logWithTime(ctx, "【解锁-地点规则】无定位权限，跳过前台兜底") } catch (_: Throwable) {}
      return
    }

    try {
      val i = Intent(ctx, GeoForegroundService::class.java).apply {
        putExtra("reason", reason)
      }
      if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
      try { logWithTime(ctx, "【解锁-地点规则】已直接启动 GeoForegroundService（前台兜底，回包：OK）") } catch (_: Throwable) {}
      return
    } catch (t: Throwable) {
      try { logWithTime(ctx, "【解锁-地点规则】直接启动前台服务失败：${t.message ?: "unknown"}，尝试 FgKickActivity 兜底") } catch (_: Throwable) {}
    }

    // 某些系统限制后台启动前台服务：使用透明 Activity 兜底
    try {
      val a = Intent(ctx, FgKickActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
      ctx.startActivity(a)
      try { logWithTime(ctx, "【解锁-地点规则】已启动 FgKickActivity 以拉起前台服务兜底（回包：OK）") } catch (_: Throwable) {}
    } catch (t: Throwable) {
      try { logWithTime(ctx, "【解锁-地点规则】FgKickActivity 启动失败：${t.message ?: "unknown"}（回包：FAIL）") } catch (_: Throwable) {}
    }
  }

  private fun hasAnyLocationPermission(ctx: Context): Boolean {
    return try {
      val fine = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
      val coarse = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
      fine || coarse
    } catch (_: Throwable) {
      false
    }
  }

  private fun logWithTime(ctx: Context, msg: String) {
    try {
      val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault())
      val now = sdf.format(java.util.Date())
      DbRepo.log(ctx, null, "[$now] $msg")
    } catch (_: Throwable) {
      try { DbRepo.log(ctx, null, msg) } catch (_: Throwable) {}
    }
  }
}
