
package com.example.quote_app

import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import com.example.quote_app.data.DbRepo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.location.*
import android.os.Handler
import java.util.concurrent.atomic.AtomicBoolean
import com.baidu.mapapi.model.LatLng
import com.baidu.mapapi.search.core.SearchResult
import com.baidu.mapapi.search.geocode.GeoCoder
import com.baidu.mapapi.search.geocode.OnGetGeoCoderResultListener
import com.baidu.mapapi.search.geocode.ReverseGeoCodeOption
import com.baidu.mapapi.search.geocode.ReverseGeoCodeResult
import com.baidu.mapapi.search.geocode.GeoCodeResult

object SysChannel {
  private const val CHANNEL = "com.example.quote_app/sys"

  fun register(engine: FlutterEngine, appContext: Context) {
    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
      when (call.method) {
        "getBaiduLocationOnce" -> {
          // IMPORTANT: Do NOT block the platform (main) thread here.
          // Location acquisition uses CountDownLatch.await internally; running it on the
          // main thread will cause ANR and freeze Flutter loading spinners.
          Thread {
            try {
              val ak = try { readBaiduAk(appContext) } catch (_: Throwable) { "oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh" }
              // Accept <= 31m (inclusive) per product requirement.
              val loc = obtainBaiduLocation(appContext, ak, 40.0, 12_000L)
              Handler(Looper.getMainLooper()).post {
                if (loc != null) {
                  val map = mapOf(
                    "lat" to loc.latitude,
                    "lng" to loc.longitude,
                    "acc" to loc.accuracy,
                    "provider" to (loc.provider ?: "baidu")
                  )
                  logWithTime(appContext, "【LocationService】【定位】Baidu SDK 成功 acc=${loc.accuracy}")
                  result.success(map)
                } else {
                  logWithTime(appContext, "【LocationService】【定位】Baidu SDK 失败")
                  result.error("NO_LOC", "baidu failed", null)
                }
              }
            } catch (t: Throwable) {
              Handler(Looper.getMainLooper()).post {
                logWithTime(appContext, "【LocationService】【定位】Baidu SDK 异常：" + (t.message ?: "unknown"))
                result.error("EX", t.message, null)
              }
            }
          }.start()
        }
        
        "reverseGeocodePoisBaiduSdk" -> {
          try {
            val lat = (call.argument<Number>("lat") ?: 0).toDouble()
            val lng = (call.argument<Number>("lng") ?: 0).toDouble()
            val radius = (call.argument<Number>("radius") ?: 50).toInt()
            reverseGeocodeBaiduSdk(appContext, lat, lng, radius, result)
          } catch (e: Throwable) {
            logWithTime(appContext, "【LocationService】【逆地理】Baidu SDK 逆地理异常: ${'$'}e")
            result.success(mapOf("pois" to emptyList<Map<String, Any?>>(), "address" to ""))
          }
        }

        "getSystemLocationOnce" -> {
          // IMPORTANT: Do NOT block the platform (main) thread here.
          // The internal implementation awaits on a latch while receiving updates on the
          // main looper; awaiting on the main thread itself will deadlock/ANR.
          Thread {
            try {
              logWithTime(appContext, "【LocationService】【定位】优先使用 Fused 高精度流")
              // Accept <= 31m (inclusive)
              var loc: Location? = obtainFusedHighAcc(appContext, 40.0, 12_000L)
              if (loc == null) loc = obtainHighAccuracyLocation(appContext, 40.0, 10_000L)
              Handler(Looper.getMainLooper()).post {
                if (loc == null) {
                  result.error("NO_LOC", "system failed", null)
                } else {
                  val map = mapOf(
                    "lat" to loc!!.latitude,
                    "lng" to loc!!.longitude,
                    "acc" to loc!!.accuracy,
                    "provider" to (loc!!.provider ?: "system")
                  )
                  logWithTime(appContext, "【LocationService】【定位】System 成功 acc=${loc!!.accuracy}")
                  result.success(map)
                }
              }
            } catch (t: Throwable) {
              Handler(Looper.getMainLooper()).post {
                logWithTime(appContext, "【LocationService】【定位】System 异常：" + (t.message ?: "unknown"))
                result.error("EX", t.message, null)
              }
            }
          }.start()
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun logWithTime(ctx: Context, msg: String) {
    try {
      val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.getDefault())
      val now = sdf.format(java.util.Date())
      DbRepo.log(ctx, null, "[$now] $msg")
    } catch (_: Throwable) { try { DbRepo.log(ctx, null, msg) } catch (_: Throwable) {} }
  }

  private fun readBaiduAk(ctx: Context): String {
    val defAndroid = "oMtxRk6dE7Q8w8SXZ3frrwzAak3gqOTh"
    val defWeb = "kmHcLsW5heS5miYWLpbRUsrQapGIJ5m2"
    return try {
      val cc = com.example.quote_app.data.DbInspector.loadOrLightScan(ctx)
      val path = cc?.dbPath
      if (path.isNullOrEmpty()) return defAndroid
      val db = android.database.sqlite.SQLiteDatabase.openDatabase(path, null, android.database.sqlite.SQLiteDatabase.OPEN_READONLY)
      try {
        var v: String? = null
        try {
          db.rawQuery("SELECT baidu_ak_android FROM configs LIMIT 1", null).use { c ->
            if (c.moveToFirst()) v = c.getString(0)
          }
        } catch (_: Throwable) { /* 表/列不存在时忽略 */ }

        if (v == null || v!!.trim().isEmpty()) {
          // 兼容旧列：只有当旧列不是默认 Web AK 时才沿用（避免误用 Web AK 触发 505）
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
    } catch (_: Throwable) {
      defAndroid
    }
  }
  private fun obtainFusedHighAcc(ctx: Context, targetAccMeters: Double, timeoutMs: Long): Location? {
    return try {
      val client = LocationServices.getFusedLocationProviderClient(ctx)
      val latch = java.util.concurrent.CountDownLatch(1)
      var best: Location? = null
      var seen = 0
      val req = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L)
        .setWaitForAccurateLocation(true).setMaxUpdates(6).build()
      val cb = object: LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
          for (l in result.locations) { seen++; if (best == null || l.accuracy < best!!.accuracy) best = l }
          if (best != null && best!!.accuracy <= targetAccMeters && seen >= 2) { try { latch.countDown() } catch (_: Throwable) {} }
        }
      }
      try { client.requestLocationUpdates(req, cb, Looper.getMainLooper()) } catch (_: Throwable) {}
      try { latch.await(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS) } catch (_: Throwable) {}
      try { client.removeLocationUpdates(cb) } catch (_: Throwable) {}
      best
    } catch (_: Throwable) { null }
  }

  private fun obtainHighAccuracyLocation(ctx: Context, targetAccMeters: Double, timeoutMs: Long): Location? {
    return try {
      val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
      val latch = java.util.concurrent.CountDownLatch(1)
      var best: Location? = null
      var seen = 0
      val listener = object: LocationListener {
        override fun onLocationChanged(loc: Location) {
          seen++;
          if (best == null || loc.accuracy < best!!.accuracy) best = loc
          if (best != null && best!!.accuracy <= targetAccMeters && seen >= 2) { try { latch.countDown() } catch (_: Throwable) {} }
        }
        @Deprecated("deprecated") override fun onStatusChanged(p: String?, s: Int, b: Bundle?) {}
        override fun onProviderEnabled(p: String) {}
        override fun onProviderDisabled(p: String) {}
      }
      try { lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, listener, Looper.getMainLooper()) } catch (_: Throwable) {}
      try { lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 1000L, 0f, listener, Looper.getMainLooper()) } catch (_: Throwable) {}
      try { latch.await(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS) } catch (_: Throwable) {}
      try { lm.removeUpdates(listener) } catch (_: Throwable) {}
      best
    } catch (_: Throwable) { null }
  }

  private fun obtainBaiduLocation(ctx: Context, ak: String, targetAccMeters: Double, timeoutMs: Long): Location? {
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
            val la = bdLoc.javaClass.getMethod("getLatitude").invoke(bdLoc) as Double
            val lo = bdLoc.javaClass.getMethod("getLongitude").invoke(bdLoc) as Double
            val acc = (bdLoc.javaClass.getMethod("getRadius").invoke(bdLoc) as Number).toFloat()
            val l = Location("baidu"); l.latitude = la; l.longitude = lo; l.accuracy = acc
            if (best == null || l.accuracy < best!!.accuracy) best = l
            if (best != null && best!!.accuracy <= targetAccMeters && seen >= 2) { try { latch.countDown() } catch (_: Throwable) {} }
          } catch (_: Throwable) {}
        }
        null
      }
      clazz.getMethod("registerLocationListener", listenerClazz).invoke(locClient, proxy)
      clazz.getMethod("start").invoke(locClient)
      try { latch.await(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS) } catch (_: Throwable) {}
      try { clazz.getMethod("stop").invoke(locClient) } catch (_: Throwable) {}
      best
    } catch (_: Throwable) { null }
  }

  // Baidu Map SDK reverse-geocode (POI list). Used by Flutter: invokeMethod('reverseGeocodePoisBaiduSdk', {'lat':..,'lng':..,'radius':..})
  private fun reverseGeocodeBaiduSdk(ctx: Context, lat: Double, lng: Double, radiusMeters: Int, result: MethodChannel.Result) {
    val radius = radiusMeters.coerceIn(1, 1000)

    val coder = try { GeoCoder.newInstance() } catch (e: Throwable) {
      result.error("baidu_sdk_init_failed", e.message ?: "GeoCoder.newInstance failed", null)
      return
    }

    val done = AtomicBoolean(false)

    val listener = object : OnGetGeoCoderResultListener {
      override fun onGetGeoCodeResult(res: GeoCodeResult?) {
        // not used
      }

      override fun onGetReverseGeoCodeResult(res: ReverseGeoCodeResult?) {
        if (!done.compareAndSet(false, true)) return
        try { coder.destroy() } catch (_: Throwable) {}

        if (res == null) {
          result.error("reverse_geocode_null", "ReverseGeoCodeResult is null", null)
          return
        }

        val err = try { res.error } catch (_: Throwable) { null }
        if (err != null && err != SearchResult.ERRORNO.NO_ERROR) {
          result.error("reverse_geocode_error", "Baidu reverse geocode error: $err", null)
          return
        }

        val poiListAny: Any? = try { res.poiList } catch (_: Throwable) { null }
        val poiList = (poiListAny as? List<*>) ?: emptyList<Any?>()

        val outPois = ArrayList<Map<String, Any?>>()
        for (p in poiList) {
          if (p == null) continue
          try {
            val clazz = p.javaClass
            val name = try { clazz.getMethod("getName").invoke(p) as? String } catch (_: Throwable) { null } ?: ""
            val addr = try { clazz.getMethod("getAddress").invoke(p) as? String } catch (_: Throwable) { null } ?: ""
            val distAny = try { clazz.getMethod("getDistance").invoke(p) } catch (_: Throwable) { null }
            val dist = when (distAny) {
              is Int -> distAny
              is Number -> distAny.toInt()
              else -> null
            }
            val ll = try { clazz.getMethod("getLocation").invoke(p) as? LatLng } catch (_: Throwable) { null }
            val plat = ll?.latitude
            val plng = ll?.longitude
            if (name.isNotBlank() && plat != null && plng != null) {
              outPois.add(
                hashMapOf<String, Any?>(
                  "name" to name,
                  "address" to addr,
                  "lat" to plat,
                  "lng" to plng,
                  "distance" to dist
                )
              )
            }
          } catch (_: Throwable) {
            // ignore broken item
          }
        }

        result.success(hashMapOf<String, Any?>("pois" to outPois))
      }
    }

    try {
      coder.setOnGetGeoCodeResultListener(listener)
    } catch (e: Throwable) {
      try { coder.destroy() } catch (_: Throwable) {}
      result.error("baidu_sdk_listener_failed", e.message ?: "setOnGetGeoCodeResultListener failed", null)
      return
    }

    // Timeout protection to avoid hanging the MethodChannel call forever.
    Handler(Looper.getMainLooper()).postDelayed({
      if (done.compareAndSet(false, true)) {
        try { coder.destroy() } catch (_: Throwable) {}
        result.error("reverse_geocode_timeout", "Baidu reverse geocode timeout", null)
      }
    }, 4500L)

    try {
      val opt = ReverseGeoCodeOption()
        .location(LatLng(lat, lng))
        .radius(radius)

      // Some SDK versions support: pageNum / pageSize / newVersion. Use reflection for compatibility.
      try { opt.javaClass.getMethod("pageNum", Int::class.javaPrimitiveType).invoke(opt, 0) } catch (_: Throwable) {}
      try { opt.javaClass.getMethod("pageSize", Int::class.javaPrimitiveType).invoke(opt, 20) } catch (_: Throwable) {}
      try { opt.javaClass.getMethod("newVersion", Int::class.javaPrimitiveType).invoke(opt, 1) } catch (_: Throwable) {}

      coder.reverseGeoCode(opt)
    } catch (e: Throwable) {
      if (done.compareAndSet(false, true)) {
        try { coder.destroy() } catch (_: Throwable) {}
        result.error("reverse_geocode_invoke_failed", e.message ?: "reverseGeoCode failed", null)
      }
    }
  }



}