package com.example.quote_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 统一定位能力：
 * - 系统高精度流（Fused -> GPS/Network）
 * - Baidu SDK（由调用方决定是否需要；这里不强依赖）
 * - 最近已知位置（lastKnown）
 */
object LocationCore {

  private fun hasAnyLocationPermission(ctx: Context): Boolean {
    return try {
      val fine = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
      val coarse = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
      fine || coarse
    } catch (_: Throwable) {
      false
    }
  }

  // （debugEnv / getSystemHighAccLikeManual 定义在下方，避免重复实现）

  /**
   * 系统高精度流：优先 Fused（更稳），失败再用 LocationManager（GPS/Network）。
   * 返回 best effort：
   * - 若在 timeout 内达到 targetAccMeters 会尽快返回
   * - 否则返回 timeout 内的最优精度位置
   */
  @JvmStatic
  fun getSystemHighAcc(ctx: Context, targetAccMeters: Double, timeoutMs: Long): Location? {
    if (!hasAnyLocationPermission(ctx)) return null
    // 1) Fused
    val fused = runCatching { obtainFusedHighAccOnWorkerLooper(ctx, targetAccMeters, timeoutMs, minUpdates = 1) }.getOrNull()
    if (fused != null) return fused

    // 2) GPS/Network stream
    return runCatching { obtainGpsHighAccOnWorkerLooper(ctx, targetAccMeters, timeoutMs, minUpdates = 1) }.getOrNull()
  }

  /**
   * 对齐“新增地点规则-手动定位”（SysChannel.getSystemLocationOnce）的系统定位实现：
   * - Fused 高精度流（更长收敛）-> LocationManager(GPS/Network)
   * - best-effort：即使未达到 targetAcc 也返回 timeout 内的最优位置
   * - 使用独立 HandlerThread 的 looper 接收回调，避免在解锁瞬间主线程繁忙导致收不到回调。
   */
  @JvmStatic
  fun getSystemHighAccLikeManual(
    ctx: Context,
    targetAccMeters: Double,
    fusedTimeoutMs: Long,
    gpsTimeoutMs: Long,
  ): Location? {
    if (!hasAnyLocationPermission(ctx)) return null

    // 注意：该方法会被 Flutter 手动定位通过 SysChannel.getSystemLocationOnce 间接使用。
    // Flutter 调用发生在前台 UI 线程的可能性较高，因此这里保持“若在主线程则不阻塞”的约束。
    // - 若在主线程：使用 worker looper 版本（不会阻塞主线程 Looper）
    // - 若不在主线程：优先使用 main looper 注册回调（更贴近 SysChannel 的实现，部分 ROM 在后台更稳定）
    val useMainLooper = Looper.myLooper() != Looper.getMainLooper()

    // 0) 先尝试 lastKnown（可快速给出 seed，避免完全无回调导致 best=null）
    val seed = getLastKnown(ctx)

    // 1) Fused（若设备无 GMS/不可用则会快速失败，直接进入 2)
    val fused = runCatching {
      if (useMainLooper) obtainFusedHighAccOnMainLooper(ctx, targetAccMeters, fusedTimeoutMs, minUpdates = 2, seed = seed)
      else obtainFusedHighAccOnWorkerLooper(ctx, targetAccMeters, fusedTimeoutMs, minUpdates = 2)
    }.getOrNull()
    if (fused != null) return fused

    // 2) GPS/Network stream
    val gps = runCatching {
      if (useMainLooper) obtainGpsHighAccOnMainLooper(ctx, targetAccMeters, gpsTimeoutMs, minUpdates = 2, seed = seed)
      else obtainGpsHighAccOnWorkerLooper(ctx, targetAccMeters, gpsTimeoutMs, minUpdates = 2)
    }.getOrNull()
    return gps ?: seed
  }

  /**
   * 仅供后台/前台服务等非 UI 主线程使用：
   * - 在 main looper 注册定位回调（与 SysChannel.obtainFusedHighAcc/obtainHighAccuracyLocation 一致）
   * - await 在调用线程阻塞（因此严禁在主线程调用）
   */
  @JvmStatic
  fun getSystemHighAccLikeManualOnMainLooperOnly(
    ctx: Context,
    targetAccMeters: Double,
    fusedTimeoutMs: Long,
    gpsTimeoutMs: Long,
  ): Location? {
    if (!hasAnyLocationPermission(ctx)) return null
    if (Looper.myLooper() == Looper.getMainLooper()) {
      // 防止主线程误用导致 ANR
      return null
    }
    val seed = getLastKnown(ctx)
    val fused = runCatching { obtainFusedHighAccOnMainLooper(ctx, targetAccMeters, fusedTimeoutMs, minUpdates = 2, seed = seed) }.getOrNull()
    if (fused != null) return fused
    val gps = runCatching { obtainGpsHighAccOnMainLooper(ctx, targetAccMeters, gpsTimeoutMs, minUpdates = 2, seed = seed) }.getOrNull()
    return gps ?: seed
  }

  /** 输出定位环境信息，便于排查“为什么取不到位置”。 */
  @JvmStatic
  fun debugEnv(ctx: Context): String {
    return try {
      val fine = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
      val coarse = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
      val bg = if (android.os.Build.VERSION.SDK_INT >= 29) {
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
      } else {
        true
      }
      val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
      val gpsOn = runCatching { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) }.getOrDefault(false)
      val netOn = runCatching { lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) }.getOrDefault(false)
      val locOn = if (android.os.Build.VERSION.SDK_INT >= 28) {
        runCatching { lm.isLocationEnabled }.getOrDefault(gpsOn || netOn)
      } else {
        gpsOn || netOn
      }
      "perm(fine=$fine, coarse=$coarse, bg=$bg), locationEnabled=$locOn, gps=$gpsOn, network=$netOn"
    } catch (_: Throwable) {
      "env_unknown"
    }
  }

  @JvmStatic
  fun getLastKnown(ctx: Context): Location? {
    if (!hasAnyLocationPermission(ctx)) return null
    return try {
      val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
      val list = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
      list.mapNotNull { p ->
        try { lm.getLastKnownLocation(p) } catch (_: Throwable) { null }
      }.maxByOrNull { it.time }
    } catch (_: Throwable) {
      null
    }
  }

  private fun obtainFusedHighAccOnWorkerLooper(
    ctx: Context,
    targetAccMeters: Double,
    timeoutMs: Long,
    minUpdates: Int,
  ): Location? {
    // NOTE: 在部分机型/ROM 中，后台前台服务使用非主线程 Looper 接收定位回调存在“收不到回调”的情况。
    // 为对齐 SysChannel.getSystemLocationOnce（手动定位的原生实现），这里默认在主线程 Looper 注册回调，
    // 但绝不在主线程阻塞等待（本方法由 Worker/Service 后台线程调用）。
    // 若调用方错误地在主线程调用，则直接返回 null，避免 ANR。
    if (Looper.myLooper() == Looper.getMainLooper()) return null
    return try {
      val client = LocationServices.getFusedLocationProviderClient(ctx)
      val latch = CountDownLatch(1)
      var best: Location? = null
      var seen = 0
      val done = AtomicBoolean(false)

      val req = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L)
        .setWaitForAccurateLocation(true)
        .setMaxUpdates(6)
        .build()

      val cb = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
          for (l in result.locations) {
            seen++
            if (best == null || l.accuracy < best!!.accuracy) best = l
          }
          if (best != null && best!!.accuracy <= targetAccMeters && seen >= minUpdates) {
            if (done.compareAndSet(false, true)) {
              try { latch.countDown() } catch (_: Throwable) {}
            }
          }
        }
      }

      // 先尝试取 fused lastLocation 作为 seed（很多后台场景下不会立刻产生新 fix，但 lastLocation 仍可用）
      try {
        client.lastLocation.addOnSuccessListener { l ->
          if (l != null) {
            seen++
            if (best == null || l.accuracy < best!!.accuracy) best = l
            if (best != null && best!!.accuracy <= targetAccMeters && seen >= minUpdates) {
              if (done.compareAndSet(false, true)) {
                try { latch.countDown() } catch (_: Throwable) {}
              }
            }
          }
        }
      } catch (_: Throwable) {}

      try { client.requestLocationUpdates(req, cb, Looper.getMainLooper()) } catch (_: Throwable) {}
      try { latch.await(timeoutMs, TimeUnit.MILLISECONDS) } catch (_: Throwable) {}
      try { client.removeLocationUpdates(cb) } catch (_: Throwable) {}
      best
    } catch (_: Throwable) {
      null
    }
  }

  /**
   * 在 main looper 注册 fused 回调：更贴近 SysChannel 实现，部分机型在“前台服务但App未打开”场景更稳定。
   * 注意：调用方必须确保不在主线程阻塞。
   */
  private fun obtainFusedHighAccOnMainLooper(
    ctx: Context,
    targetAccMeters: Double,
    timeoutMs: Long,
    minUpdates: Int,
    seed: Location?,
  ): Location? {
    return try {
      val client = LocationServices.getFusedLocationProviderClient(ctx)
      val latch = CountDownLatch(1)
      val released = AtomicBoolean(false)
      var best: Location? = seed
      var seen = if (seed != null) 1 else 0

      // 先拿一次 lastLocation 作为候选（即便后续无回调，也能返回 best-effort）
      try {
        client.lastLocation.addOnSuccessListener { l ->
          if (l != null) {
            if (best == null || l.accuracy < best!!.accuracy) best = l
            seen++
            if (!released.get() && best != null && best!!.accuracy <= targetAccMeters && seen >= minUpdates) {
              released.set(true)
              try { latch.countDown() } catch (_: Throwable) {}
            }
          }
        }
      } catch (_: Throwable) {}

      val req = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L)
        // 背景场景下 waitForAccurateLocation(true) 有概率导致长时间无回调，因此这里不强等“足够精准”
        .setWaitForAccurateLocation(false)
        .setMaxUpdates(6)
        .build()

      val cb = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
          for (l in result.locations) {
            seen++
            if (best == null || l.accuracy < best!!.accuracy) best = l
          }
          if (!released.get() && best != null && best!!.accuracy <= targetAccMeters && seen >= minUpdates) {
            released.set(true)
            try { latch.countDown() } catch (_: Throwable) {}
          }
        }
      }

      try { client.requestLocationUpdates(req, cb, Looper.getMainLooper()) } catch (_: Throwable) {}
      try { latch.await(timeoutMs, TimeUnit.MILLISECONDS) } catch (_: Throwable) {}
      try { client.removeLocationUpdates(cb) } catch (_: Throwable) {}
      best
    } catch (_: Throwable) {
      seed
    }
  }

  private fun obtainGpsHighAccOnWorkerLooper(
    ctx: Context,
    targetAccMeters: Double,
    timeoutMs: Long,
    minUpdates: Int,
  ): Location? {
    // 同 fused：在主线程 Looper 注册回调，避免部分 ROM 背景场景下 worker looper 无回调。
    if (Looper.myLooper() == Looper.getMainLooper()) return null
    return try {
      val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
      val latch = CountDownLatch(1)
      var best: Location? = null
      var seen = 0
      val done = AtomicBoolean(false)

      // 先用 lastKnown seed（避免等待新 fix 但一直没有回调导致 best=null）
      try {
        val seed = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
          .mapNotNull { p -> try { lm.getLastKnownLocation(p) } catch (_: Throwable) { null } }
          .maxByOrNull { it.time }
        if (seed != null) {
          seen++
          best = seed
          if (best != null && best!!.accuracy <= targetAccMeters && seen >= minUpdates) {
            if (done.compareAndSet(false, true)) {
              try { latch.countDown() } catch (_: Throwable) {}
            }
          }
        }
      } catch (_: Throwable) {}

      val listener = object : LocationListener {
        override fun onLocationChanged(loc: Location) {
          seen++
          if (best == null || loc.accuracy < best!!.accuracy) best = loc
          if (best != null && best!!.accuracy <= targetAccMeters && seen >= minUpdates) {
            if (done.compareAndSet(false, true)) {
              try { latch.countDown() } catch (_: Throwable) {}
            }
          }
        }

        @Deprecated("deprecated")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
      }

      try { lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, listener, Looper.getMainLooper()) } catch (_: Throwable) {}
      try { lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 1000L, 0f, listener, Looper.getMainLooper()) } catch (_: Throwable) {}
      try { latch.await(timeoutMs, TimeUnit.MILLISECONDS) } catch (_: Throwable) {}
      try { lm.removeUpdates(listener) } catch (_: Throwable) {}
      best
    } catch (_: Throwable) {
      null
    }
  }

  /**
   * 在 main looper 注册 LocationManager 回调（与 SysChannel.obtainHighAccuracyLocation 接近）。
   * 注意：调用方必须确保不在主线程阻塞。
   */
  private fun obtainGpsHighAccOnMainLooper(
    ctx: Context,
    targetAccMeters: Double,
    timeoutMs: Long,
    minUpdates: Int,
    seed: Location?,
  ): Location? {
    return try {
      val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
      val latch = CountDownLatch(1)
      val released = AtomicBoolean(false)
      var best: Location? = seed
      var seen = if (seed != null) 1 else 0

      // 同步 seed: 直接拉取 provider 的 lastKnown 作为候选
      try {
        val g = runCatching { lm.getLastKnownLocation(LocationManager.GPS_PROVIDER) }.getOrNull()
        if (g != null && (best == null || g.accuracy < best!!.accuracy)) { best = g; seen++ }
      } catch (_: Throwable) {}
      try {
        val n = runCatching { lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) }.getOrNull()
        if (n != null && (best == null || n.accuracy < best!!.accuracy)) { best = n; seen++ }
      } catch (_: Throwable) {}

      val listener = object : LocationListener {
        override fun onLocationChanged(loc: Location) {
          seen++
          if (best == null || loc.accuracy < best!!.accuracy) best = loc
          if (!released.get() && best != null && best!!.accuracy <= targetAccMeters && seen >= minUpdates) {
            released.set(true)
            try { latch.countDown() } catch (_: Throwable) {}
          }
        }

        @Deprecated("deprecated")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
      }

      try { lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, listener, Looper.getMainLooper()) } catch (_: Throwable) {}
      try { lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 1000L, 0f, listener, Looper.getMainLooper()) } catch (_: Throwable) {}
      try { latch.await(timeoutMs, TimeUnit.MILLISECONDS) } catch (_: Throwable) {}
      try { lm.removeUpdates(listener) } catch (_: Throwable) {}
      best
    } catch (_: Throwable) {
      seed
    }
  }

}
