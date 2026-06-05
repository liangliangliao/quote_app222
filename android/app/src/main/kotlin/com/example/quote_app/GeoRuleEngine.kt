package com.example.quote_app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.location.Location
import com.example.quote_app.data.DbRepo
import org.json.JSONObject
import kotlin.math.*

/**
 * 地点规则通用引擎：
 * - 读取 configs.location_rules_enabled 开关
 * - 遍历 vision_triggers(type='geo', enabled=1) 的所有目标位置
 * - 只要有一个目标位置在合理范围内，就发送一次通知提醒（取最近命中的那个）
 */
object GeoRuleEngine {

  private const val SP = "quote_prefs"
  private const val KEY_LAST_GEO_ANY_NOTIFY_TS = "geo_last_any_notify_ts"
  private const val KEY_GEO_NOTIFY_TS_PREFIX = "geo_last_notify_ts_"
  private const val GEO_NOTIFY_DEDUP_MS = 60_000L
  private val GEO_NOTIFY_LOCK = Any()

  data class GeoTarget(
    val lat: Double,
    val lng: Double,
    val place: String,
    val note: String,
    val coordType: String? = null
  )

  @JvmStatic
  fun isGeoEnabled(ctx: Context): Boolean {
    return try {
      val cc = com.example.quote_app.data.DbInspector.loadOrLightScan(ctx) ?: return false
      val db = SQLiteDatabase.openDatabase(cc.dbPath, null, SQLiteDatabase.OPEN_READONLY)
      try {
        db.rawQuery("SELECT location_rules_enabled FROM configs LIMIT 1", null).use { c ->
          c.moveToFirst() && (c.getInt(0) == 1)
        }
      } finally {
        try { db.close() } catch (_: Throwable) {}
      }
    } catch (_: Throwable) {
      false
    }
  }

  @JvmStatic
  fun loadTargets(ctx: Context): List<GeoTarget> {
    val out = ArrayList<GeoTarget>()
    try {
      val cc = com.example.quote_app.data.DbInspector.loadOrLightScan(ctx) ?: return emptyList()
      val db = SQLiteDatabase.openDatabase(cc.dbPath, null, SQLiteDatabase.OPEN_READONLY)
      try {
        db.rawQuery(
          "SELECT config, then_text FROM vision_triggers WHERE type='geo' AND enabled=1",
          null
        ).use { c ->
          while (c.moveToNext()) {
            val cfgStr = c.getString(0) ?: ""
            val thenText = c.getString(1) ?: ""
            try {
              val jo = JSONObject(cfgStr)
              val lat = jo.optDouble("lat", Double.NaN)
              val lng = jo.optDouble("lng", Double.NaN)
              if (lat.isNaN() || lng.isNaN()) continue
              val place = jo.optString("place", "").ifBlank { "目标地点" }
              val note = jo.optString("note", "").ifBlank { thenText.ifBlank { "你已到达 $place ，别忘了你的目标" } }
              val coordType = jo.optString("coordType", "").trim().ifBlank { null }
              out.add(GeoTarget(lat, lng, place, note, coordType))
            } catch (_: Throwable) {
              // ignore malformed
            }
          }
        }
      } finally {
        try { db.close() } catch (_: Throwable) {}
      }
    } catch (_: Throwable) {
      // ignore
    }
    return out
  }

  /**
   * 遍历所有目标位置，若命中任意一个则发送一次通知（最近命中者）。
   */
  @JvmStatic
  fun evaluateAndNotify(ctx: Context, current: Location, targets: List<GeoTarget>, radiusMeters: Double = 100.0): Boolean {
    if (targets.isEmpty()) return false
    var best: GeoTarget? = null
    var bestDist = Double.MAX_VALUE

    for (t in targets) {
      val di = bestDistance(current, t)
      val d = di.dist
      try {
        val ct = t.coordType ?: "unknown"
        logWithTime(ctx, "【地点规则】对比目标(${t.place}) 距离=${d}m (coordType=$ct used=${di.used})")
      } catch (_: Throwable) {}
      if (d <= radiusMeters && d < bestDist) {
        bestDist = d
        best = t
      }
    }

    val hit = best
    if (hit != null) {
      try { logWithTime(ctx, "正在对比当前位置与目标位置距离，比对结果是当前位置在目标位置合理范围，将发送通知提醒") } catch (_: Throwable) {}
      val id = 3000 + ((hit.place.hashCode()) and 0x7fffffff)

      // 去重：避免一次解锁窗口内多入口并发导致同一地点重复提醒（即使通知 id 相同也会重复弹出/响铃）。
      val now = System.currentTimeMillis()
      try {
        val sp = ctx.getSharedPreferences(SP, Context.MODE_PRIVATE)
        synchronized(GEO_NOTIFY_LOCK) {
          val lastAny = try { sp.getLong(KEY_LAST_GEO_ANY_NOTIFY_TS, 0L) } catch (_: Throwable) { 0L }
          val lastThis = try { sp.getLong(KEY_GEO_NOTIFY_TS_PREFIX + id, 0L) } catch (_: Throwable) { 0L }
          val last = if (lastAny > lastThis) lastAny else lastThis
          if (last > 0L && (now - last) < GEO_NOTIFY_DEDUP_MS) {
            try { logWithTime(ctx, "【地点规则】${GEO_NOTIFY_DEDUP_MS}ms 内已提醒过，跳过重复发送（回包：SKIP_DUP）") } catch (_: Throwable) {}
            return true
          }
          try {
            sp.edit()
              .putLong(KEY_LAST_GEO_ANY_NOTIFY_TS, now)
              .putLong(KEY_GEO_NOTIFY_TS_PREFIX + id, now)
              .commit()
          } catch (_: Throwable) {
            // ignore
          }
        }
      } catch (_: Throwable) {}

      try { NotifyHelper.send(ctx, id, "愿景地点提醒", hit.note, null, "vision_focus", null) } catch (_: Throwable) {}
      try { logWithTime(ctx, "通知发送成功") } catch (_: Throwable) {}
      return true
    }

    try { logWithTime(ctx, "正在对比当前位置与目标位置距离，比对结果是当前位置不在目标位置合理范围，不发送通知提醒") } catch (_: Throwable) {}
    return false
  }

private data class DistInfo(val dist: Double, val used: String)

private fun bestDistance(current: Location, t: GeoTarget): DistInfo {
  val provider = try { current.provider?.lowercase() } catch (_: Throwable) { null }
    val curLL: Pair<Double, Double> = when {
      provider != null && provider.contains("baidu") -> bd09ToWgs84(current.latitude, current.longitude)
      provider != null && provider.contains("gcj") -> gcj02ToWgs84(current.latitude, current.longitude)
      else -> current.latitude to current.longitude
    }
    val curLat = curLL.first
    val curLon = curLL.second

  val ct = t.coordType?.trim()?.lowercase()
  val candidates: List<Pair<String, Pair<Double, Double>>> = when (ct) {
    "wgs84" -> listOf("wgs84" to (t.lat to t.lng))
    "gcj02", "gcj", "mars" -> listOf("gcj02->wgs84" to gcj02ToWgs84(t.lat, t.lng))
    "bd09", "bd09ll", "bd09llh", "bd" -> listOf("bd09->wgs84" to bd09ToWgs84(t.lat, t.lng))
    null, "" -> listOf(
      "raw" to (t.lat to t.lng),
      "gcj02->wgs84?" to gcj02ToWgs84(t.lat, t.lng),
      "bd09->wgs84?" to bd09ToWgs84(t.lat, t.lng)
    )
    else -> listOf(
      "raw($ct)" to (t.lat to t.lng),
      "gcj02->wgs84?($ct)" to gcj02ToWgs84(t.lat, t.lng),
      "bd09->wgs84?($ct)" to bd09ToWgs84(t.lat, t.lng)
    )
  }

  var best = Double.MAX_VALUE
  var bestUsed = "raw"
  for ((tag, ll) in candidates) {
    val distArr = FloatArray(1)
    Location.distanceBetween(curLat, curLon, ll.first, ll.second, distArr)
    val d = distArr[0].toDouble()
    if (d < best) {
      best = d
      bestUsed = tag
    }
  }
  return DistInfo(best, bestUsed)
}

// ---- Coordinate conversion helpers (WGS84 / GCJ-02 / BD-09) ----
// Minimal implementation for distance comparison. Widely-used public formulas.
private const val PI = 3.1415926535897932384626
private const val A = 6378245.0
private const val EE = 0.00669342162296594323

private fun outOfChina(lat: Double, lon: Double): Boolean {
  return lon < 72.004 || lon > 137.8347 || lat < 0.8293 || lat > 55.8271
}

private fun transformLat(x: Double, y: Double): Double {
  var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
  ret += (20.0 * sin(6.0 * x * PI) + 20.0 * sin(2.0 * x * PI)) * 2.0 / 3.0
  ret += (20.0 * sin(y * PI) + 40.0 * sin(y / 3.0 * PI)) * 2.0 / 3.0
  ret += (160.0 * sin(y / 12.0 * PI) + 320.0 * sin(y * PI / 30.0)) * 2.0 / 3.0
  return ret
}

private fun transformLon(x: Double, y: Double): Double {
  var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
  ret += (20.0 * sin(6.0 * x * PI) + 20.0 * sin(2.0 * x * PI)) * 2.0 / 3.0
  ret += (20.0 * sin(x * PI) + 40.0 * sin(x / 3.0 * PI)) * 2.0 / 3.0
  ret += (150.0 * sin(x / 12.0 * PI) + 300.0 * sin(x / 30.0 * PI)) * 2.0 / 3.0
  return ret
}

private fun gcj02ToWgs84(lat: Double, lon: Double): Pair<Double, Double> {
  if (outOfChina(lat, lon)) return lat to lon
  var dLat = transformLat(lon - 105.0, lat - 35.0)
  var dLon = transformLon(lon - 105.0, lat - 35.0)
  val radLat = lat / 180.0 * PI
  var magic = sin(radLat)
  magic = 1 - EE * magic * magic
  val sqrtMagic = sqrt(magic)
  dLat = (dLat * 180.0) / ((A * (1 - EE)) / (magic * sqrtMagic) * PI)
  dLon = (dLon * 180.0) / (A / sqrtMagic * cos(radLat) * PI)
  val mgLat = lat + dLat
  val mgLon = lon + dLon
  return (lat * 2 - mgLat) to (lon * 2 - mgLon)
}

private fun bd09ToGcj02(lat: Double, lon: Double): Pair<Double, Double> {
  val x = lon - 0.0065
  val y = lat - 0.006
  val z = sqrt(x * x + y * y) - 0.00002 * sin(y * PI)
  val theta = atan2(y, x) - 0.000003 * cos(x * PI)
  val ggLon = z * cos(theta)
  val ggLat = z * sin(theta)
  return ggLat to ggLon
}

private fun bd09ToWgs84(lat: Double, lon: Double): Pair<Double, Double> {
  val g = bd09ToGcj02(lat, lon)
  return gcj02ToWgs84(g.first, g.second)
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
