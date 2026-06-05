package com.example.quote_app

import android.annotation.SuppressLint
import android.content.Context
import android.location.Criteria
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.baidu.location.BDAbstractLocationListener
import com.baidu.location.BDLocation
import com.baidu.location.LocationClient
import com.baidu.location.LocationClientOption
import java.util.concurrent.atomic.AtomicBoolean
import java.text.SimpleDateFormat
import java.util.Locale
import kotlin.math.abs

object BaiduLocator {
    private const val TAG = "BaiduLocator"

    // 记录最近一次 Baidu SDK 回调的诊断信息（用于在 Flutter 侧打印失败 locType/原因）。
    @Volatile private var lastDiagLocType: Int? = null
    @Volatile private var lastDiagReason: String? = null
    @Volatile private var lastDiagTs: Long = 0L

    private fun clearDiag() {
        lastDiagLocType = null
        lastDiagReason = null
        lastDiagTs = 0L
    }

    private fun setDiag(locType: Int?, reason: String) {
        lastDiagLocType = locType
        lastDiagReason = reason
        lastDiagTs = System.currentTimeMillis()
    }

    fun peekLastDiag(): Pair<Int?, String?> = Pair(lastDiagLocType, lastDiagReason)

    data class Simple(val latitude: Double, val longitude: Double, val accuracy: Float, val provider: String?, val locType: Int? = null, val locTime: String? = null, val netType: String? = null)

    /**
     * 高精度“流式”定位：优先使用百度 Location SDK，持续接收多次回调并选择最优精度，
     * 一旦达到目标精度（默认 30m）即结束；超时后返回当前最优值。
     *
     * 说明：
     * - 该方法由 Flutter 侧通过 MethodChannel('com.example.quote_app/sys') 调用。
     * - 为兼容旧逻辑，默认若 Baidu SDK 无回调/异常，将回退到系统 LocationManager 单次定位；
     *   但可通过 allowSystemFallback=false 禁用该行为，以便由 Flutter 侧统一做“系统兜底”。
     */
    @SuppressLint("MissingPermission")
    fun getOnce(ctx: Context, allowSystemFallback: Boolean = true, callback: (Simple?) -> Unit) {
        // 新一轮定位前清理诊断信息，避免 Flutter 侧读取到旧值。
        clearDiag()
        getOnceFromBaiduSdk(ctx, targetAccMeters = 35f, timeoutMs = 12_000L) { bd ->
            if (bd != null) {
                callback(bd)
            } else {
                if (allowSystemFallback) {
                    // Baidu SDK 获取失败时，回退系统定位（保持兼容）。
                    getOnceFromSystem(ctx, callback)
                } else {
                    callback(null)
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun getOnceFromBaiduSdk(
        ctx: Context,
        targetAccMeters: Float,
        timeoutMs: Long,
        callback: (Simple?) -> Unit
    ) {
        val appCtx = ctx.applicationContext
        val done = AtomicBoolean(false)
        val main = Handler(Looper.getMainLooper())

        val client: LocationClient = try {
            // 定位 SDK 隐私合规（v9.2.9+ 必须在任何 LocationClient 实例化/使用前调用）
            try { LocationClient.setAgreePrivacy(true) } catch (_: Throwable) {}
            LocationClient(appCtx)
        } catch (t: Throwable) {
            Log.w(TAG, "Baidu LocationClient init failed: ${t.message}")
            // 记录初始化失败原因，便于 Flutter 侧看到 NO_LOCATION 的 details。
            setDiag(null, "client_init_failed")
            callback(null)
            return
        }

        val option = LocationClientOption().apply {
            // 高精度模式 + GPS
            setLocationMode(LocationClientOption.LocationMode.Hight_Accuracy)
            setOpenGps(true)
            // 持续回调（流）以获得更稳定精度
            setScanSpan(1000)
            // 不要一次性定位，否则很容易只收到一次粗略回调
            setOnceLocation(false)
            // 坐标系：与现有 Dart 侧 lastProvider==baidu 的处理保持一致
            setCoorType("bd09ll")
            // 降低缓存导致的“假精准”（disableCache 在部分版本标记为 deprecated，但仍可用）
            try { disableCache(true) } catch (_: Throwable) {}
            // 不需要地址，避免额外耗时
            setIsNeedAddress(true)
            try { setIsNeedLocationDescribe(true) } catch (_: Throwable) {}
            try { setNeedNewVersionRgc(true) } catch (_: Throwable) {}
            try { setIsNeedLocationPoiList(true) } catch (_: Throwable) {}
            // 让 GPS 在 1s 级别更频繁回调
            try { setLocationNotify(true) } catch (_: Throwable) {}
            // 关闭模拟定位（若 SDK 支持）
            try { setEnableSimulateGps(false) } catch (_: Throwable) {}
            // 避免 SDK 杀进程
            try { setIgnoreKillProcess(true) } catch (_: Throwable) {}
        }

        try {
            client.locOption = option
        } catch (t: Throwable) {
            Log.w(TAG, "Baidu locOption set failed: ${t.message}")
        }

        val startMs = System.currentTimeMillis()
        val minCollectMs = 3_000L
        var lastAccepted: BDLocation? = null
        var acceptedCount = 0

        var best: BDLocation? = null
        var bestScore = Float.MAX_VALUE
        val listener = object : BDAbstractLocationListener() {
            override fun onReceiveLocation(loc: BDLocation?) {
                if (loc == null) {
                    setDiag(null, "null_location")
                    return
                }

                val locType = try { loc.locType } catch (_: Throwable) { 0 }
                setDiag(locType, "on_receive")

                // locType >= 500 通常表示鉴权/服务类致命问题（如 AK/服务未开启等），无需继续等待回调。
                if (locType >= 500) {
                    val desc = try { loc.locTypeDescription } catch (_: Throwable) { null }
                    Log.w(TAG, "Baidu SDK fatal locType=$locType, desc=$desc, will fallback to system")
                    setDiag(locType, if (desc.isNullOrBlank()) "fatal_locType" else "fatal_locType:$desc")
                    finish(null)
                    return
                }
                // 过滤明显不可用/缓存/离线结果（避免出现“假精准但位置偏移很大”）
                if (locType == 62 || locType == 63 || locType == 65 || locType == 66) {
                    Log.w(TAG, "Baidu SDK filtered locType=$locType (unreliable/offline/cache)")
                    setDiag(locType, "filtered_locType")
                    return
                }

                val now = System.currentTimeMillis()
                val locTimeStr = try { loc.time } catch (_: Throwable) { null }
                val locTimeMs = parseBaiduTimeMs(locTimeStr)
                if (locTimeMs != null && abs(now - locTimeMs) > 15_000L) {
                    // 过旧：通常是缓存/离线结果，直接丢弃
                    Log.w(TAG, "Baidu SDK stale location: locType=$locType, locTime=$locTimeStr")
                    setDiag(locType, "stale_time")
                    return
                }

                // loc.radius 可能为 0 或负数，做保护
                val acc = (loc.radius.takeIf { it > 0f } ?: Float.MAX_VALUE)

                // 评分：精度优先，其次偏好 GPS(61)，再偏好更新的结果
                val agePenalty = if (locTimeMs == null) 0f else ((now - locTimeMs).coerceAtLeast(0L) / 1000f) * 2f
                val typePenalty = if (locType == 61) 0f else 12f
                val score = acc + agePenalty + typePenalty

                if (best == null || score < bestScore) {
                    bestScore = score
                    best = loc
                }

                val prev = lastAccepted
                lastAccepted = loc
                acceptedCount++

                val elapsed = now - startMs

                // 允许快速结束：GPS 且达标（通常最接近真实位置）
                if (acc <= targetAccMeters && locType == 61) {
                    finish(loc)
                    return
                }

                // 其它情况：至少收集一段时间，并要求两次位置收敛（防止第一次网络结果漂移）
                if (acc <= targetAccMeters && elapsed >= minCollectMs && prev != null) {
                    val d = distanceMeters(prev, loc)
                    if (d <= 80.0) {
                        finish(loc)
                    }
                }
            }

            private fun finish(loc: BDLocation?) {
                if (!done.compareAndSet(false, true)) return
                try { client.unRegisterLocationListener(this) } catch (_: Throwable) {}
                try { client.stop() } catch (_: Throwable) {}
                // 取消超时
                main.removeCallbacksAndMessages(null)
                if (loc == null) {
                    setDiag(lastDiagLocType, "finish_null")
                    callback(null)
                } else {
                    callback(Simple(loc.latitude, loc.longitude, loc.radius, "baidu", loc.locType, loc.time, try { loc.networkLocationType } catch (_: Throwable) { null }))
                }
            }
        }

        try {
            client.registerLocationListener(listener)
        } catch (t: Throwable) {
            Log.w(TAG, "Baidu register listener failed: ${t.message}")
            setDiag(null, "register_listener_failed")
            callback(null)
            return
        }

        // 超时保护：超时后返回当前最优（若无则 null）
        main.postDelayed({
            if (!done.compareAndSet(false, true)) return@postDelayed
            try { client.unRegisterLocationListener(listener) } catch (_: Throwable) {}
            try { client.stop() } catch (_: Throwable) {}
            val b = best
            if (b == null) {
                // 没有任何有效回调或都被过滤掉：标记为超时，便于 Flutter 侧定位原因。
                setDiag(lastDiagLocType, "timeout_best_null")
                callback(null)
            } else {
                // 超时但有最优值：记录原因，帮助分析精度不达标。
                setDiag(b.locType, "timeout_return_best")
                callback(Simple(b.latitude, b.longitude, b.radius, "baidu", b.locType, b.time, try { b.networkLocationType } catch (_: Throwable) { null }))
            }
        }, timeoutMs)

        try {
            client.start()
        } catch (t: Throwable) {
            Log.w(TAG, "Baidu client.start failed: ${t.message}")
            setDiag(null, "client_start_failed")
            // 立即回调失败，避免悬挂
            try { client.unRegisterLocationListener(listener) } catch (_: Throwable) {}
            try { client.stop() } catch (_: Throwable) {}
            callback(null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun getOnceFromSystem(ctx: Context, callback: (Simple?) -> Unit) {
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            // Try lastKnown from both GPS and Network
            val candidates = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            var best: Location? = null
            for (p in candidates) {
                try {
                    val l = lm.getLastKnownLocation(p)
                    if (l != null && (best == null || l.accuracy < best!!.accuracy)) {
                        best = l
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "getLastKnownLocation($p) failed: ${e.message}")
                }
            }
            if (best != null) {
                callback(Simple(best!!.latitude, best!!.longitude, best!!.accuracy, best!!.provider))
                return
            }
        } catch (e: Exception) {
            Log.w(TAG, "lastKnown failed: ${e.message}")
        }

        // Request single fresh update
        try {
            val criteria = Criteria().apply {
                accuracy = Criteria.ACCURACY_FINE
                isAltitudeRequired = false
                isBearingRequired = false
                isSpeedRequired = false
                powerRequirement = Criteria.POWER_MEDIUM
            }
            val provider = lm.getBestProvider(criteria, true) ?: LocationManager.NETWORK_PROVIDER
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    try { lm.removeUpdates(this) } catch (_: Exception) {}
                    callback(Simple(location.latitude, location.longitude, location.accuracy, location.provider))
                }

                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(p0: String?, p1: Int, p2: Bundle?) {}

                override fun onProviderEnabled(p0: String) {}
                override fun onProviderDisabled(p0: String) {}
            }
            lm.requestSingleUpdate(provider, listener, Looper.getMainLooper())
            // Fallback timeout in case no callback in time
            Handler(Looper.getMainLooper()).postDelayed({
                try { lm.removeUpdates(listener) } catch (_: Exception) {}
                callback(null)
            }, 10_000L)
        } catch (e: Exception) {
            Log.e(TAG, "requestSingleUpdate failed: ${e.message}")
            callback(null)
        }
    }


    private fun parseBaiduTimeMs(timeStr: String?): Long? {
        if (timeStr == null) return null
        val s = timeStr.trim()
        if (s.isEmpty()) return null
        val patterns = arrayOf(
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        )
        for (p in patterns) {
            try {
                val df = SimpleDateFormat(p, Locale.getDefault())
                df.isLenient = true
                val d = df.parse(s) ?: continue
                return d.time
            } catch (_: Throwable) {}
        }
        return null
    }

    private fun distanceMeters(a: BDLocation, b: BDLocation): Double {
        val r = 6371000.0
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val dLat = lat2 - lat1
        val dLon = Math.toRadians(b.longitude - a.longitude)
        val sinLat = Math.sin(dLat / 2)
        val sinLon = Math.sin(dLon / 2)
        val h = sinLat * sinLat + Math.cos(lat1) * Math.cos(lat2) * sinLon * sinLon
        return 2 * r * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h))
    }

}