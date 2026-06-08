package com.example.quote_app

import android.content.Intent
import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.FileInputStream
import android.media.MediaScannerConnection
import android.provider.MediaStore
import android.os.Build
import android.content.ContentValues
import android.os.Environment
import android.os.Handler
import android.os.Looper
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

import android.app.usage.UsageStatsManager
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat

import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

import com.baidu.mapapi.model.LatLng
import com.baidu.mapapi.search.core.SearchResult
import com.baidu.mapapi.search.geocode.GeoCodeResult
import com.baidu.mapapi.search.geocode.GeoCoder
import com.baidu.mapapi.search.geocode.OnGetGeoCoderResultListener
import com.baidu.mapapi.search.geocode.ReverseGeoCodeOption
import com.baidu.mapapi.search.geocode.ReverseGeoCodeResult

import com.baidu.mapapi.search.poi.PoiSearch
import com.baidu.mapapi.search.poi.OnGetPoiSearchResultListener
import com.baidu.mapapi.search.poi.PoiNearbySearchOption
import com.baidu.mapapi.search.poi.PoiResult
import com.baidu.mapapi.search.core.PoiInfo

object Channels {
  private const val CH = "native.scheduler"
  private var sysChannel: MethodChannel? = null
  private var stepStream: StepCounterStream? = null
  @Volatile private var tappedNotification: Boolean = false

  // Read-only self status; no special permission needed for own app.
  private fun describeStandbyBucket(ctx: Context): String {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return "n/a"
    return try {
      val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
      val b = usm?.appStandbyBucket ?: return "unknown"
      when (b) {
        UsageStatsManager.STANDBY_BUCKET_ACTIVE -> "ACTIVE"
        UsageStatsManager.STANDBY_BUCKET_WORKING_SET -> "WORKING_SET"
        UsageStatsManager.STANDBY_BUCKET_FREQUENT -> "FREQUENT"
        UsageStatsManager.STANDBY_BUCKET_RARE -> "RARE"
        UsageStatsManager.STANDBY_BUCKET_RESTRICTED -> "RESTRICTED"
        else -> "bucket_${'$'}b"
      }
    } catch (_: Throwable) {
      "unknown"
    }
  }



  fun markNotificationTapped() {
    tappedNotification = true
  }

  fun consumeLaunchFromNotificationFlag(): Boolean {
    val v = tappedNotification
    tappedNotification = false
    return v
  }

  fun emitNotificationTap(type: String? = null, payload: String? = null) {
    try {
      if (sysChannel == null) return
      val args: MutableMap<String, Any?> = HashMap()
      if (type != null) args["type"] = type
      if (payload != null) args["payload"] = payload
      sysChannel?.invokeMethod("onNativeNotificationTap", args)
    } catch (_: Throwable) {}
  }

  fun emitSportMusicAction(action: String) {
    try {
      if (sysChannel == null) return
      val args: MutableMap<String, Any?> = HashMap()
      args["action"] = action
      sysChannel?.invokeMethod("onSportMusicAction", args)
    } catch (_: Throwable) {}
  }

  private fun saveImageToSystemGallery(appCtx: Context, srcPath: String, displayName: String?, mimeType: String?): String {
    val srcFile = File(srcPath)
    if (!srcFile.exists()) {
      throw IllegalArgumentException("源文件不存在: $srcPath")
    }

    val mime = if (mimeType.isNullOrBlank()) "image/jpeg" else mimeType
    val name = if (displayName.isNullOrBlank()) srcFile.name else displayName

    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val resolver = appCtx.contentResolver
      val values = ContentValues()
      values.put(MediaStore.Images.Media.DISPLAY_NAME, name)
      values.put(MediaStore.Images.Media.MIME_TYPE, mime)
      values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/QuoteApp")
      values.put(MediaStore.Images.Media.IS_PENDING, 1)

      val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        ?: throw RuntimeException("写入 MediaStore 失败")

      resolver.openOutputStream(uri).use { out ->
        if (out == null) throw RuntimeException("无法打开输出流")
        FileInputStream(srcFile).use { input ->
          input.copyTo(out)
        }
      }

      val done = ContentValues()
      done.put(MediaStore.Images.Media.IS_PENDING, 0)
      resolver.update(uri, done, null, null)
      uri.toString()
    } else {
      // Android 9 及以下：写入公共 Pictures 目录，并触发媒体扫描
      val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
      val destDir = File(picturesDir, "QuoteApp")
      if (!destDir.exists()) {
        destDir.mkdirs()
      }
      val destFile = File(destDir, name)
      FileInputStream(srcFile).use { input ->
        destFile.outputStream().use { output ->
          input.copyTo(output)
        }
      }
      MediaScannerConnection.scanFile(appCtx, arrayOf(destFile.absolutePath), arrayOf(mime), null)
      destFile.absolutePath
    }
  }


  private fun saveFileToDownloads(appCtx: Context, srcPath: String, displayName: String?, mimeType: String?, subDir: String?): String {
    val srcFile = File(srcPath)
    if (!srcFile.exists()) {
      throw IllegalArgumentException("源文件不存在: $srcPath")
    }
    val rawName = if (displayName.isNullOrBlank()) srcFile.name else displayName
    val safeName = rawName.replace(Regex("""[\/:*?"<>|]+"""), "_").trim().ifEmpty { "ebook.epub" }
    val mime = if (mimeType.isNullOrBlank()) "application/octet-stream" else mimeType
    val folder = if (subDir.isNullOrBlank()) "Ebooks" else subDir.replace(Regex("""[\/:*?"<>|]+"""), "_").trim().ifEmpty { "Ebooks" }

    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val resolver = appCtx.contentResolver
      val values = ContentValues().apply {
        put(MediaStore.Downloads.DISPLAY_NAME, safeName)
        put(MediaStore.Downloads.MIME_TYPE, mime)
        put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/" + folder)
        put(MediaStore.Downloads.IS_PENDING, 1)
      }
      val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        ?: throw RuntimeException("写入系统下载目录失败")
      resolver.openOutputStream(uri).use { out ->
        if (out == null) throw RuntimeException("无法打开下载目录输出流")
        FileInputStream(srcFile).use { input -> input.copyTo(out) }
        out.flush()
      }
      val done = ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }
      resolver.update(uri, done, null, null)
      "Downloads/$folder/$safeName"
    } else {
      val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
      val destDir = File(downloadsDir, folder)
      if (!destDir.exists()) destDir.mkdirs()
      val destFile = File(destDir, safeName)
      FileInputStream(srcFile).use { input -> destFile.outputStream().use { output -> input.copyTo(output) } }
      MediaScannerConnection.scanFile(appCtx, arrayOf(destFile.absolutePath), arrayOf(mime), null)
      destFile.absolutePath
    }
  }

  private fun saveAudioToDownloads(appCtx: Context, srcPath: String, displayName: String?, mimeType: String?): String {
    val srcFile = File(srcPath)
    if (!srcFile.exists()) {
      throw IllegalArgumentException("源文件不存在: $srcPath")
    }
    val rawName = if (displayName.isNullOrBlank()) srcFile.name else displayName
    val safeName = rawName.replace(Regex("""[\/:*?"<>|]+"""), "_").trim().ifEmpty { "tts_audio.mp3" }
    val mime = if (mimeType.isNullOrBlank()) "audio/mpeg" else mimeType

    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val resolver = appCtx.contentResolver
      val values = ContentValues().apply {
        put(MediaStore.Downloads.DISPLAY_NAME, safeName)
        put(MediaStore.Downloads.MIME_TYPE, mime)
        put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/VirtualTeacher")
        put(MediaStore.Downloads.IS_PENDING, 1)
      }
      val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        ?: throw RuntimeException("写入系统下载目录失败")
      resolver.openOutputStream(uri).use { out ->
        if (out == null) throw RuntimeException("无法打开下载目录输出流")
        FileInputStream(srcFile).use { input -> input.copyTo(out) }
        out.flush()
      }
      val done = ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }
      resolver.update(uri, done, null, null)
      "Downloads/VirtualTeacher/$safeName"
    } else {
      val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
      val destDir = File(downloadsDir, "VirtualTeacher")
      if (!destDir.exists()) destDir.mkdirs()
      val destFile = File(destDir, safeName)
      FileInputStream(srcFile).use { input -> destFile.outputStream().use { output -> input.copyTo(output) } }
      MediaScannerConnection.scanFile(appCtx, arrayOf(destFile.absolutePath), arrayOf(mime), null)
      destFile.absolutePath
    }
  }

  private fun saveTextToDownloads(appCtx: Context, displayName: String?, text: String?, mimeType: String?): String {
    val rawName = if (displayName.isNullOrBlank()) "movie_subtitle.txt" else displayName
    val safeName = rawName.replace(Regex("""[\\\\/:*?"<>|]+"""), "_").trim().ifEmpty { "movie_subtitle.txt" }
    val mime = if (mimeType.isNullOrBlank()) "text/plain" else mimeType
    val body = text ?: ""
    val bytes = body.toByteArray(Charsets.UTF_8)

    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val resolver = appCtx.contentResolver
      val values = ContentValues().apply {
        put(MediaStore.Downloads.DISPLAY_NAME, safeName)
        put(MediaStore.Downloads.MIME_TYPE, mime)
        put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/MovieRoleLab")
        put(MediaStore.Downloads.IS_PENDING, 1)
      }
      val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        ?: throw RuntimeException("写入系统下载目录失败")
      resolver.openOutputStream(uri).use { out ->
        if (out == null) throw RuntimeException("无法打开下载目录输出流")
        out.write(bytes)
        out.flush()
      }
      val done = ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }
      resolver.update(uri, done, null, null)
      "Downloads/MovieRoleLab/$safeName"
    } else {
      val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
      val destDir = File(downloadsDir, "MovieRoleLab")
      if (!destDir.exists()) destDir.mkdirs()
      val destFile = File(destDir, safeName)
      destFile.writeBytes(bytes)
      MediaScannerConnection.scanFile(appCtx, arrayOf(destFile.absolutePath), arrayOf(mime), null)
      destFile.absolutePath
    }
  }


  fun register(engine: FlutterEngine, appCtx: Context) {
    MethodChannel(engine.dartExecutor.binaryMessenger, CH).setMethodCallHandler { call, result ->
      try {
        when (call.method) {
          "ensureUnlockRegistered" -> {
            try {
              (appCtx as? App)?.ensureUnlockReceiverRegistered()
              result.success(true)
            } catch (t: Throwable) { result.success(false) }
          }

                "isNativeWM" -> result.success(true)
                "isNativeAM" -> result.success(true)
          "canScheduleExact" -> result.success(ExactAlarmHelper.hasExactAlarmPermission(appCtx))
          "requestExactPermission" -> result.success(ExactAlarmHelper.requestExactAlarmPermission(appCtx))
          "scheduleExactAt" -> {
            val id = call.argument<Int>("id") ?: 0
            val epochMs = call.argument<Long>("epochMs") ?: 0L
            val payload = call.argument<String>("payload")
            val ok = NativeSchedulerK.scheduleExactAt(appCtx, id, epochMs, payload)
            result.success(ok)
          }
          "scheduleAlarmClockAt" -> {
            val id = call.argument<Int>("id") ?: 0
            val epochMs = call.argument<Long>("epochMs") ?: 0L
            val payload = call.argument<String>("payload")
            val ok = NativeSchedulerK.scheduleAlarmClockAt(appCtx, id, epochMs, payload)
            result.success(ok)
          }
          "cancel" -> {
            val id = call.argument<Int>("id") ?: 0
            NativeSchedulerK.cancel(appCtx, id)
            result.success(null)
          }

          "saveImageToGallery" -> {
            val pth = call.argument<String>("path")
            val name = call.argument<String>("name")
            val mime = call.argument<String>("mime")
            if (pth == null || pth.trim().isEmpty()) {
              result.error("ARG", "path missing", null)
            } else {
              try {
                val saved = saveImageToSystemGallery(appCtx, pth, name, mime)
                result.success(saved)
              } catch (t: Throwable) {
                result.error("ERR", t.message, null)
              }
            }
          }



          "saveFileToDownloads" -> {
            val pth = call.argument<String>("path")
            val name = call.argument<String>("name")
            val mime = call.argument<String>("mime")
            val subDir = call.argument<String>("subDir")
            if (pth == null || pth.trim().isEmpty()) {
              result.error("ARG", "path missing", null)
            } else {
              try {
                val saved = saveFileToDownloads(appCtx, pth, name, mime, subDir)
                result.success(saved)
              } catch (t: Throwable) {
                result.error("ERR", t.message, null)
              }
            }
          }

          "saveAudioToDownloads" -> {
            val pth = call.argument<String>("path")
            val name = call.argument<String>("name")
            val mime = call.argument<String>("mime")
            if (pth == null || pth.trim().isEmpty()) {
              result.error("ARG", "path missing", null)
            } else {
              try {
                val saved = saveAudioToDownloads(appCtx, pth, name, mime)
                result.success(saved)
              } catch (t: Throwable) {
                result.error("ERR", t.message, null)
              }
            }
          }

          "saveTextToDownloads" -> {
            val name = call.argument<String>("name")
            val text = call.argument<String>("text")
            val mime = call.argument<String>("mime")
            if (name == null || name.trim().isEmpty()) {
              result.error("ARG", "name missing", null)
            } else {
              try {
                val saved = saveTextToDownloads(appCtx, name, text, mime)
                result.success(saved)
              } catch (t: Throwable) {
                result.error("ERR", t.message, null)
              }
            }
          }

          "cancelAll" -> { NativeSchedulerK.cancelAll(appCtx); result.success(null) }
                    "scheduleWmPair" -> {
            val uid = call.argument<String>("uid")
            val runKey = call.argument<String>("runKey")
            val triggerAt = call.argument<Long>("triggerAtMillis")
            if (uid == null || runKey == null || triggerAt == null) {
              result.error("ARG","uid/runKey/triggerAtMillis missing", null)
            } else {
              com.example.quote_app.wm.WmScheduler.schedulePair(appCtx, triggerAt, uid, runKey)
              result.success(true)
            }
          }
          "scheduleKickAt" -> {
            val arg = call.arguments as? Map<*, *>
            val uid = arg?.get("uid") as? String
            val runKey = arg?.get("runKey") as? String
            val at = (arg?.get("triggerAtMillis") as? Number)?.toLong()
            if (uid == null || runKey == null || at == null) {
              result.error("ARG", "uid/runKey/triggerAtMillis missing", null)
            } else {
              com.example.quote_app.wm.WmScheduler.scheduleKick(appCtx, at, uid, runKey)
              result.success(true)
            }
          }
          "cancelKick" -> {
            val arg = call.arguments as? Map<*, *>
            val uid = arg?.get("uid") as? String
            val runKey = arg?.get("runKey") as? String
            if (uid == null || runKey == null) {
              result.error("ARG", "uid/runKey missing", null)
            } else {
              com.example.quote_app.wm.WmScheduler.cancelKick(appCtx, uid, runKey)
              result.success(true)
            }
          }
          "cancelWmByUnique" -> {
            val unique = call.argument<String>("unique")
            if (unique == null) {
              result.error("ARG","unique missing", null)
            } else {
              com.example.quote_app.wm.WmScheduler.cancelByUnique(appCtx, unique)
              result.success(true)
            }
          }
          
          
          
          "cancelExactById" -> {
            val arg = call.arguments as? Map<*, *>
            val uid = arg?.get("uid") as? String
            val rk  = arg?.get("runKey") as? String
            if (uid.isNullOrEmpty() || rk.isNullOrEmpty()) {
              result.error("ARG","uid/runKey missing", null)
            } else {
              val id = com.example.quote_app.compat.DartParity.alarmId(uid, rk)
              NativeSchedulerK.cancel(appCtx, id)
              result.success(true)
            }
          }
"cancelExactByNext" -> {
            val arg = call.arguments as? Map<*, *>
            val uid = arg?.get("uid") as? String
            val at = (arg?.get("triggerAtMillis") as? Number)?.toLong()
            if (uid == null || at == null) {
              result.error("ARG","uid/triggerAtMillis missing", null)
            } else {
              val fmt = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US)
            val runKey = fmt.format(java.util.Date(at))
            val id = com.example.quote_app.compat.DartParity.alarmId(uid, runKey)
              NativeSchedulerK.cancel(appCtx, id)
              result.success(true)
            }
          }
          "cancelWmByUidBoth" -> {
            val uid = call.argument<String>("uid")
            if (uid == null) {
              result.error("ARG","uid missing", null)
            } else {
              com.example.quote_app.compat.WmCancelCompat.cancelBoth(appCtx, uid)
              result.success(true)
            }
          }
          "dbInfo" -> {
            try {
              val arg = call.arguments as? Map<*, *>
              val path = arg?.get("dbPath") as? String
              val ver = (arg?.get("version") as? Int) ?: 1
              if (!path.isNullOrEmpty()) {
                android.util.Log.i("Channels", "dbInfo received path=" + path + " ver=" + ver + " schema=" + ( (arg?.get("schema") as? Map<*,*>)?.size ?: 0))
                // save minimal contract into prefs so DbInspector can pick it up
                val o = org.json.JSONObject()
                o.put("dbPath", path)
                o.put("version", ver)
                o.put("logsSource", "logs");
                o.put("tasksSource", "tasks");
                o.put("quotesSource", "quotes");
                val logMap = org.json.JSONObject();
                logMap.put("uid", "task_uid");
                logMap.put("detail", "detail");
                o.put("logColMap", logMap);
                val taskMap = org.json.JSONObject();
                taskMap.put("uid", "task_uid");
                taskMap.put("title", "name");
                taskMap.put("content", "prompt");
                taskMap.put("avatar", "avatar_path");
                taskMap.put("enabled", "status");
                taskMap.put("trigger_at", "start_time");
                taskMap.put("next_time", "next_time");
                o.put("taskColMap", taskMap);
                val quoteMap = org.json.JSONObject();
                quoteMap.put("uid", "task_uid");
                quoteMap.put("content", "content");
                o.put("quoteColMap", quoteMap)
                // optional: persist full schema if provided by Dart
                val schemaArg = arg?.get("schema")
                if (schemaArg is Map<*, *>) {
                    val schemaJson = org.json.JSONObject(schemaArg)
                    o.put("schema", schemaJson)
                }
                val sp = android.preference.PreferenceManager.getDefaultSharedPreferences(appCtx)
                sp.edit().putString("db.contract", o.toString()).apply()
                result.success(true)
              } else result.error("bad_args","missing path", null)
            } catch (t: Throwable) { result.error("ERR", t.message, null) }
          }
    
          
          "getBaiduLocationOnce" -> {
            try {
              val clientClazz = Class.forName("com.baidu.location.LocationClient")
              val optionsClazz = Class.forName("com.baidu.location.LocationClientOption")
              val listenerIfc = Class.forName("com.baidu.location.BDAbstractLocationListener")
              val bdLocClazz = Class.forName("com.baidu.location.BDLocation")

              val client = clientClazz.getConstructor(Context::class.java).newInstance(appCtx)
              val opts = optionsClazz.getDeclaredConstructor().newInstance()
              try { optionsClazz.getMethod("setOpenGps", Boolean::class.java).invoke(opts, true) } catch (_: Throwable) {}
              try { optionsClazz.getMethod("setIsNeedAddress", Boolean::class.java).invoke(opts, true) } catch (_: Throwable) {}
              try { clientClazz.getMethod("setLocOption", optionsClazz).invoke(client, opts) } catch (_: Throwable) {}

              val holder = arrayOfNulls<Any>(1)
              val handler = java.lang.reflect.Proxy.newProxyInstance(
                listenerIfc.classLoader, arrayOf(listenerIfc)
              ) { _, method, args ->
                if (method.name == "onReceiveLocation" && args != null && args.isNotEmpty()) {
                  holder[0] = args[0]
                }
                null
              }
              clientClazz.getMethod("registerLocationListener", listenerIfc).invoke(client, handler)
              clientClazz.getMethod("start").invoke(client)

              var waited = 0
              while (holder[0] == null && waited < 30000) {
                Thread.sleep(200); waited += 200
              }
              try { clientClazz.getMethod("stop").invoke(client) } catch (_: Throwable) {}

              val cur = holder[0]
              if (cur != null) {
                val acc = (bdLocClazz.getMethod("getRadius").invoke(cur) as? Float) ?: 0f
                val lat = bdLocClazz.getMethod("getLatitude").invoke(cur) as? Double
                val lng = bdLocClazz.getMethod("getLongitude").invoke(cur) as? Double
                result.success(hashMapOf("lat" to lat, "lng" to lng, "acc" to acc))
              } else {
                result.success(null)
              }
            } catch (t: Throwable) {
              result.error("ERR", t.message, null)
            }
          }
else -> result.notImplemented()
        }
      } catch (t: Throwable) {
        result.error("ERR", t.message, null)
      }
    }

    // Step counter stream for SportRunningPage (EventChannel).
    try {
      stepStream = StepCounterStream(appCtx)
      EventChannel(engine.dartExecutor.binaryMessenger, "com.example.quote_app/steps").setStreamHandler(stepStream)
    } catch (_: Throwable) {}

    // System/perm support channel used by Dart (PermHelper & NativeGuard)
    MethodChannel(engine.dartExecutor.binaryMessenger, "com.example.quote_app/sys")
      .also { ch2 -> sysChannel = ch2 }
      .setMethodCallHandler { call, result ->
      try {
        when (call.method) {
          "resetStepCounter" -> {
            try {
              stepStream?.resetSession()
              result.success(true)
            } catch (t: Throwable) {
              result.success(false)
            }
          }
          "startSportForeground" -> {
            val rid = call.argument<Int>("recordId")
            val title = call.argument<String>("title") ?: "运动进行中"
            if (rid == null || rid <= 0) {
              result.error("ARG", "recordId missing", null)
            } else {
              try {
                val it = Intent(appCtx, SportForegroundService::class.java)
                it.action = SportForegroundService.ACTION_START
                it.putExtra(SportForegroundService.EXTRA_RECORD_ID, rid)
                it.putExtra(SportForegroundService.EXTRA_TITLE, title)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                  appCtx.startForegroundService(it)
                } else {
                  appCtx.startService(it)
                }
                result.success(true)
              } catch (t: Throwable) {
                result.error("ERR", t.message, null)
              }
            }
          }

          "stopSportForeground" -> {
            try {
              val rid = call.argument<Int>("recordId")
              val title = call.argument<String>("title")
              val finalStatus = call.argument<String>("finalStatus")
              val it = Intent(appCtx, SportForegroundService::class.java).apply {
                action = SportForegroundService.ACTION_STOP
                if (rid != null) putExtra(SportForegroundService.EXTRA_RECORD_ID, rid)
                if (!title.isNullOrEmpty()) putExtra(SportForegroundService.EXTRA_TITLE, title)
                if (!finalStatus.isNullOrEmpty()) putExtra(SportForegroundService.EXTRA_FINAL_STATUS, finalStatus)
              }
              appCtx.startService(it)
              result.success(true)
            } catch (t: Throwable) {
              result.error("ERR", t.message, null)
            }
          }
          "pauseSportForeground" -> {
            try {
              val rid = call.argument<Int>("recordId")
              val title = call.argument<String>("title")
              val finalStatus = call.argument<String>("finalStatus")
              val it = Intent(appCtx, SportForegroundService::class.java).apply {
                action = SportForegroundService.ACTION_PAUSE
                if (rid != null) putExtra(SportForegroundService.EXTRA_RECORD_ID, rid)
                if (!title.isNullOrEmpty()) putExtra(SportForegroundService.EXTRA_TITLE, title)
                if (!finalStatus.isNullOrEmpty()) putExtra(SportForegroundService.EXTRA_FINAL_STATUS, finalStatus)
              }
              appCtx.startService(it)
              result.success(true)
            } catch (t: Throwable) {
              result.error("ERR", t.message, null)
            }
          }
          "resumeSportForeground" -> {
            try {
              val rid = call.argument<Int>("recordId")
              val title = call.argument<String>("title")
              val finalStatus = call.argument<String>("finalStatus")
              val it = Intent(appCtx, SportForegroundService::class.java).apply {
                action = SportForegroundService.ACTION_RESUME
                if (rid != null) putExtra(SportForegroundService.EXTRA_RECORD_ID, rid)
                if (!title.isNullOrEmpty()) putExtra(SportForegroundService.EXTRA_TITLE, title)
                if (!finalStatus.isNullOrEmpty()) putExtra(SportForegroundService.EXTRA_FINAL_STATUS, finalStatus)
              }
              appCtx.startService(it)
              result.success(true)
            } catch (t: Throwable) {
              result.error("ERR", t.message, null)
            }
          }

          "isSportForegroundRunning" -> {
            try {
              result.success(SportForegroundService.isRunning())
            } catch (_: Throwable) {
              result.success(false)
            }
          }

          "ensureUnlockRegistered" -> {
            try {
              (appCtx as? App)?.ensureUnlockReceiverRegistered()
              result.success(true)
            } catch (t: Throwable) { result.success(false) }
          }

          "createNoMediaGuards" -> {
            try {
              // Create .nomedia in app-specific external files (Pictures & root)
              val dirs = arrayOf(
                appCtx.getExternalFilesDir(null),
                appCtx.getExternalFilesDir(Environment.DIRECTORY_PICTURES),
                appCtx.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)
              )
              for (d in dirs) {
                if (d != null) {
                  if (!d.exists()) d.mkdirs()
                  try {
                    val nm = File(d, ".nomedia")
                    if (!nm.exists()) nm.createNewFile()
                  } catch (_: Throwable) {}
                }
              }
              result.success(true)
            } catch (t: Throwable) { result.error("ERR", t.message, null) }
          }

          "isNativeWmEnabled" -> result.success(true)
          "isNativeAmEnabled" -> result.success(true)
          "hasExactAlarmPermission" -> result.success(ExactAlarmHelper.hasExactAlarmPermission(appCtx))
          "requestExactAlarmPermission" -> result.success(ExactAlarmHelper.requestExactAlarmPermission(appCtx))

          // === 后台保障自检/引导（不常驻通知的前提下，尽量提高后台触发稳定性） ===
          // Flutter: invokeMethod('getBgGuardStatus')
          "getBgGuardStatus" -> {
            try {
              val pm = appCtx.getSystemService(Context.POWER_SERVICE) as? PowerManager
              val ignoreOpt = try { pm?.isIgnoringBatteryOptimizations(appCtx.packageName) ?: false } catch (_: Throwable) { false }
              val bucket = try { describeStandbyBucket(appCtx) } catch (_: Throwable) { "unknown" }
              val canExact = try { ExactAlarmHelper.hasExactAlarmPermission(appCtx) } catch (_: Throwable) { false }
              val notifEnabled = try { NotificationManagerCompat.from(appCtx).areNotificationsEnabled() } catch (_: Throwable) { true }
              val bgLocGranted = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                  appCtx.checkSelfPermission(android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
                } else true
              } catch (_: Throwable) { true }
              result.success(
                hashMapOf(
                  "sdkInt" to Build.VERSION.SDK_INT,
                  "ignoreBattOpt" to ignoreOpt,
                  "bucket" to bucket,
                  "canExactAlarm" to canExact,
                  "notifEnabled" to notifEnabled,
                  "bgLocationGranted" to bgLocGranted
                )
              )
            } catch (t: Throwable) {
              result.success(hashMapOf<String, Any?>("error" to (t.message ?: "unknown")))
            }
          }

          // Flutter: invokeMethod('requestIgnoreBatteryOptimizations')
          "requestIgnoreBatteryOptimizations" -> {
            try {
              val pm = appCtx.getSystemService(Context.POWER_SERVICE) as? PowerManager
              val already = try { pm?.isIgnoringBatteryOptimizations(appCtx.packageName) ?: false } catch (_: Throwable) { false }
              if (already) {
                result.success(true)
              } else {
                val it = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                  data = Uri.parse("package:" + appCtx.packageName)
                  addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try {
                  appCtx.startActivity(it)
                  result.success(true)
                } catch (e: Throwable) {
                  // fallback: open app details
                  try {
                    val it2 = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                      data = Uri.parse("package:" + appCtx.packageName)
                      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    appCtx.startActivity(it2)
                    result.success(true)
                  } catch (_: Throwable) {
                    result.success(false)
                  }
                }
              }
            } catch (_: Throwable) {
              result.success(false)
            }
          }

          // Flutter: invokeMethod('openAppDetailsSettings')
          "openAppDetailsSettings" -> {
            try {
              val it = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:" + appCtx.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
              }
              appCtx.startActivity(it)
              result.success(true)
            } catch (_: Throwable) {
              result.success(false)
            }
          }

          // Flutter: invokeMethod('openIgnoreBatteryOptimizationSettings')
          "openIgnoreBatteryOptimizationSettings" -> {
            try {
              val it = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
              }
              appCtx.startActivity(it)
              result.success(true)
            } catch (_: Throwable) {
              result.success(false)
            }
          }

          // Flutter: invokeMethod('ensureUnlockPulseScheduled')
          "ensureUnlockPulseScheduled" -> {
            try {
              UnlockPulse.ensureScheduledIfNeeded(appCtx)
              result.success(true)
            } catch (_: Throwable) {
              result.success(false)
            }
          }

          // Play a one-shot system notification sound (used by Sport start bell when no custom ringtone is set)
          "playSystemNotificationSound" -> {
            try {
              val uri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION)
              val rt = android.media.RingtoneManager.getRingtone(appCtx, uri)
              rt?.play()
              result.success(true)
            } catch (t: Throwable) {
              result.success(false)
            }
          }


          "getBaiduLocationOnce" -> {
            try {
	              // 重要：禁用 BaiduLocator 内部的“系统回退”，避免 Baidu 调用返回 system(lastKnown) 但被误判为百度定位。
	              // Flutter 侧会在 Baidu 失败/不达标后统一走 getSystemLocationOnce 兜底。
	              BaiduLocator.getOnce(appCtx, allowSystemFallback = false) { loc ->
                if (loc == null) {
                  val (lt, reason) = BaiduLocator.peekLastDiag()
                  result.error("NO_LOCATION", "Timeout or no provider", mapOf("locType" to lt, "reason" to reason))
                } else {
                  val map = hashMapOf<String, Any>(
                  "lat" to loc.latitude,
                  "lng" to loc.longitude,
                  "acc" to loc.accuracy.toDouble(),
                  "provider" to (loc.provider ?: "system")
                )
                loc.locType?.let { map["locType"] = it }
                loc.locTime?.let { map["locTime"] = it }
                loc.netType?.let { map["netType"] = it }
                  result.success(map)
                }
              }
            } catch (e: Throwable) {
              result.error("EX", e.message, null)
            }
          }

          // 系统高精度流：优先 Fused(PRIORITY_HIGH_ACCURACY + waitForAccurateLocation)，
          // 失败再回退 GPS LocationManager 流式收敛。
          // Flutter: invokeMethod('getSystemLocationOnce')
          "getSystemLocationOnce" -> {
            try {
              // IMPORTANT: do NOT block the platform (main) thread here, otherwise Flutter UI will freeze and ANR.
              // Run the blocking high-accuracy flow on a background thread and post the result back to main.
              val mainHandler = Handler(Looper.getMainLooper())
              val replied = AtomicBoolean(false)

              // 兜底超时：保证一定会回包，避免 Flutter 侧 Future 长时间悬挂导致 TimeoutException。
              // 需小于 Dart 侧 timeout（当前 25s）。
              mainHandler.postDelayed({
                if (replied.getAndSet(true)) return@postDelayed
                try { result.success(null) } catch (_: Throwable) {}
              }, 24_000L)

              Thread {
                val best: Location? = try {
                  obtainFusedHighAcc(appCtx, 31.0, 12_000L) ?: obtainGpsHighAcc(appCtx, 31.0, 10_000L)
                } catch (t: Throwable) {
                  android.util.Log.w("Channels", "getSystemLocationOnce background flow failed: ${t.message}")
                  null
                }

                mainHandler.post {
                  if (replied.getAndSet(true)) return@post
                  try {
                    if (best == null) {
                      result.success(null)
                    } else {
                      val map = hashMapOf<String, Any?>(
                        "lat" to best.latitude,
                        "lng" to best.longitude,
                        "acc" to best.accuracy.toDouble(),
                        "provider" to (best.provider ?: "system"),
                        "time" to best.time
                      )
                      result.success(map)
                    }
                  } catch (_: Throwable) {
                    // ignored
                  }
                }
              }.start()
            } catch (e: Throwable) {
              result.error("EX", e.message, null)
            }
          }

	          // Baidu Map SDK reverse-geocode (POI list). Used by Flutter:
	          // invokeMethod('reverseGeocodePoisBaiduSdk', {'lat':..,'lng':..,'radius':..})
	          "reverseGeocodePoisBaiduSdk" -> {
	            try {
	              val lat = (call.argument<Number>("lat") ?: 0).toDouble()
	              val lng = (call.argument<Number>("lng") ?: 0).toDouble()
	              val radius = (call.argument<Number>("radius") ?: 50).toInt()
                  val coordType = call.argument<String>("coordType")
	              Channels.reverseGeocodePoisBaiduSdk(appCtx, lat, lng, radius, coordType, result)
	            } catch (e: Throwable) {
	              // 保持 Dart 侧容错：返回空 pois 而不是直接抛异常
	              result.success(hashMapOf<String, Any?>("pois" to emptyList<Map<String, Any?>>()))
	            }
	          }

	          // Baidu Map Search SDK：周边检索（多关键字）。
	          // invokeMethod('searchNearbyPoisBaiduSdk', {'lat':..,'lng':..,'radius':..,'coordType':..,'keywords':[...]} )
	          "searchNearbyPoisBaiduSdk" -> {
	            try {
	              val lat = (call.argument<Number>("lat")?.toDouble()) ?: 0.0
	              val lng = (call.argument<Number>("lng")?.toDouble()) ?: 0.0
	              val radius = (call.argument<Number>("radius")?.toInt()) ?: 50
	              val coordType = call.argument<String>("coordType")
	              val kwsAny = call.argument<List<Any>>("keywords")
	              val keywords = kwsAny?.mapNotNull { it?.toString() }?.filter { it.isNotBlank() } ?: emptyList()
	              Channels.searchNearbyPoisBaiduSdk(appCtx, lat, lng, radius, coordType, keywords, result)
	            } catch (t: Throwable) {
	              result.error("ERR", t.message, null)
	            }
	          }
          
          
          "cancelExactByNext" -> {
            val arg = call.arguments as? Map<*, *>
            val uid = arg?.get("uid") as? String
            val at = (arg?.get("triggerAtMillis") as? Number)?.toLong()
            if (uid == null || at == null) {
              result.error("ARG","uid/triggerAtMillis missing", null)
            } else {
              val fmt = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US)
            val runKey = fmt.format(java.util.Date(at))
            val id = com.example.quote_app.compat.DartParity.alarmId(uid, runKey)
              NativeSchedulerK.cancel(appCtx, id)
              result.success(true)
            }
          }
          "cancelWmByUidBoth" -> {
            val uid = call.argument<String>("uid")
            if (uid == null) {
              result.error("ARG","uid missing", null)
            } else {
              com.example.quote_app.compat.WmCancelCompat.cancelBoth(appCtx, uid)
              result.success(true)
            }
          }
          "dbInfo" -> {
            try {
              val arg = call.arguments as? Map<*, *>
              val path = arg?.get("dbPath") as? String
              val ver = (arg?.get("version") as? Int) ?: 1
              if (!path.isNullOrEmpty()) {
                android.util.Log.i("Channels", "dbInfo received path=" + path + " ver=" + ver + " schema=" + ( (arg?.get("schema") as? Map<*,*>)?.size ?: 0))
                // save minimal contract into prefs so DbInspector can pick it up
                val o = org.json.JSONObject()
                o.put("dbPath", path)
                o.put("version", ver)
                o.put("logsSource", "logs");
                o.put("tasksSource", "tasks");
                o.put("quotesSource", "quotes");
                val logMap = org.json.JSONObject();
                logMap.put("uid", "task_uid");
                logMap.put("detail", "detail");
                o.put("logColMap", logMap);
                val taskMap = org.json.JSONObject();
                taskMap.put("uid", "task_uid");
                taskMap.put("title", "name");
                taskMap.put("content", "prompt");
                taskMap.put("avatar", "avatar_path");
                taskMap.put("enabled", "status");
                taskMap.put("trigger_at", "start_time");
                taskMap.put("next_time", "next_time");
                o.put("taskColMap", taskMap);
                val quoteMap = org.json.JSONObject();
                quoteMap.put("uid", "task_uid");
                quoteMap.put("content", "content");
                o.put("quoteColMap", quoteMap)
                // optional: persist full schema if provided by Dart
                val schemaArg = arg?.get("schema")
                if (schemaArg is Map<*, *>) {
                    val schemaJson = org.json.JSONObject(schemaArg)
                    o.put("schema", schemaJson)
                }
                val sp = android.preference.PreferenceManager.getDefaultSharedPreferences(appCtx)
                sp.edit().putString("db.contract", o.toString()).apply()
                result.success(true)
              } else result.error("bad_args","missing path", null)
            } catch (t: Throwable) { result.error("ERR", t.message, null) }
          }
    
          "consumeLaunchFromNotificationFlag" -> {
            result.success(consumeLaunchFromNotificationFlag())
          }

          else -> result.notImplemented()
        }
      } catch (t: Throwable) {
        result.error("ERR", t.message, null)
      }
    }
  }

  // ---- Baidu Map SDK reverse-geocode (POI list) for Flutter ----
  fun reverseGeocodePoisBaiduSdk(
    ctx: Context,
    lat: Double,
    lng: Double,
    radiusMeters: Int,
    coordType: String?,
    result: MethodChannel.Result
  ) {
    val radius = radiusMeters.coerceIn(1, 1000)

    // 坐标系一致性：GeoCoder/POI 坐标默认为 BD09LL。
    // 若输入来自系统定位(WGS84/GCJ02)，需要先转换为 BD09LL，否则会出现“定位点与 POI 完全不一致”。
    val center: LatLng = try {
      toBd09ll(lat, lng, coordType)
    } catch (_: Throwable) {
      LatLng(lat, lng)
    }

    val coder = try { GeoCoder.newInstance() } catch (e: Throwable) {
      android.util.Log.e("LocationService", "reverseGeocodePoisBaiduSdk init failed", e)
      result.error("baidu_sdk_init_failed", e.toString(), hashMapOf("cause" to (e.cause?.toString())))
      return
    }

    val done = AtomicBoolean(false)

    fun haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Int {
      val r = 6371000.0
      val dLat = Math.toRadians(lat2 - lat1)
      val dLon = Math.toRadians(lon2 - lon1)
      val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2)
      val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      return (r * c).toInt()
    }

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

        val outPois = ArrayList<Map<String, Any?>>()
        val seen = HashSet<String>()

        // 兜底：把“当前位置语义描述/地址”作为 0m 的候选项，避免列表为空时误显示远处 POI
        try {
          val sem = try {
            res.javaClass.getMethod("getSematicDescription").invoke(res) as? String
          } catch (_: Throwable) {
            try { res.javaClass.getField("sematicDescription").get(res) as? String } catch (_: Throwable) { null }
          }
          val addrObj: Any? = try { res.address } catch (_: Throwable) { null }
          val addrText: String? = when (addrObj) {
            is String -> addrObj
            else -> try {
              // ReverseGeoCodeResult.Address is an inner model with getAddress() sometimes
              addrObj?.javaClass?.getMethod("getAddress")?.invoke(addrObj) as? String
            } catch (_: Throwable) { null }
          }
          val display = (sem?.trim().takeIf { !it.isNullOrEmpty() }) ?: (addrText?.trim().takeIf { !it.isNullOrEmpty() })
          if (!display.isNullOrEmpty()) {
            val key = "当前位置|${center.latitude}|${center.longitude}"
            if (seen.add(key)) {
              outPois.add(
                hashMapOf<String, Any?>(
                  "name" to display,
                  "address" to addrText,
                  "lat" to center.latitude,
                  "lng" to center.longitude,
                  "distance" to 0
                )
              )
            }
          }
        } catch (_: Throwable) {}

        val poiListAny: Any? = try { res.poiList } catch (_: Throwable) { null }
        val poiList = (poiListAny as? List<*>) ?: emptyList<Any?>()

        for (p in poiList) {
          if (p == null) continue
          try {
            val clazz = p.javaClass
            val name = (try { clazz.getMethod("getName").invoke(p) as? String } catch (_: Throwable) {
              try { clazz.getField("name").get(p) as? String } catch (_: Throwable) { null }
            })?.trim().orEmpty()
            if (name.isEmpty()) continue

            val addr = (try { clazz.getMethod("getAddress").invoke(p) as? String } catch (_: Throwable) {
              try { clazz.getField("address").get(p) as? String } catch (_: Throwable) { null }
            })?.trim()

            val latLngAny: Any? = try {
              clazz.getMethod("getLocation").invoke(p)
            } catch (_: Throwable) {
              try { clazz.getMethod("getPt").invoke(p) } catch (_: Throwable) { null }
            }

            var poiLat: Double? = null
            var poiLng: Double? = null
            if (latLngAny != null) {
              try {
                val llClazz = latLngAny.javaClass
                poiLat = (try { llClazz.getField("latitude").get(latLngAny) as? Double } catch (_: Throwable) {
                  try { llClazz.getMethod("getLatitude").invoke(latLngAny) as? Double } catch (_: Throwable) { null }
                })
                poiLng = (try { llClazz.getField("longitude").get(latLngAny) as? Double } catch (_: Throwable) {
                  try { llClazz.getMethod("getLongitude").invoke(latLngAny) as? Double } catch (_: Throwable) { null }
                })
              } catch (_: Throwable) {}
            }

            // 关键：不要信任 SDK 内置 distance（可能基于不同坐标系/不同中心点计算），统一按输入中心点重算
            val dist = if (poiLat != null && poiLng != null) {
              haversineMeters(center.latitude, center.longitude, poiLat!!, poiLng!!)
            } else {
              // fallback: try SDK distance when coordinate is missing
              val distAny = try { clazz.getMethod("getDistance").invoke(p) } catch (_: Throwable) { null }
              when (distAny) {
                is Int -> distAny
                is Number -> distAny.toInt()
                else -> Int.MAX_VALUE
              }
            }

            if (dist > radius) continue

            val outLat = poiLat ?: center.latitude
            val outLng = poiLng ?: center.longitude
            val key = name + "|" + outLat.toString() + "|" + outLng.toString()
            if (!seen.add(key)) continue

            outPois.add(
              hashMapOf<String, Any?>(
                "name" to name,
                "address" to addr,
                "lat" to outLat,
                "lng" to outLng,
                "distance" to dist
              )
            )
          } catch (_: Throwable) {
            // ignore broken item
          }
        }

        outPois.sortWith(compareBy<Map<String, Any?>> { (it["distance"] as? Int) ?: Int.MAX_VALUE })
        result.success(hashMapOf<String, Any?>(
          "centerLat" to center.latitude,
          "centerLng" to center.longitude,
          "pois" to outPois
        ))
      }
    }

    try {
      coder.setOnGetGeoCodeResultListener(listener)
    } catch (e: Throwable) {
      try { coder.destroy() } catch (_: Throwable) {}
      result.error("baidu_sdk_listener_failed", e.message ?: "setOnGetGeoCodeResultListener failed", null)
      return
    }

    val opt = ReverseGeoCodeOption().location(center)
    try { opt.radius(radius) } catch (_: Throwable) {}

    // 某些百度地图 SDK 版本：逆地理默认不返回 poiList，需要开启 newVersion 并设置分页参数。
    // 使用反射以兼容不同 SDK 版本（避免编译期 API 不存在）。
    try { opt.javaClass.getMethod("pageNum", Int::class.javaPrimitiveType).invoke(opt, 0) } catch (_: Throwable) {}
    try { opt.javaClass.getMethod("pageSize", Int::class.javaPrimitiveType).invoke(opt, 20) } catch (_: Throwable) {}
    try { opt.javaClass.getMethod("newVersion", Int::class.javaPrimitiveType).invoke(opt, 1) } catch (_: Throwable) {}

    // Timeout protection to avoid hanging MethodChannel calls.
    Handler(Looper.getMainLooper()).postDelayed({
      if (!done.compareAndSet(false, true)) return@postDelayed
      try { coder.destroy() } catch (_: Throwable) {}
      result.success(hashMapOf<String, Any?>(
        "centerLat" to center.latitude,
        "centerLng" to center.longitude,
        "pois" to emptyList<Map<String, Any?>>()
      ))
    }, 4500)

    try {
      coder.reverseGeoCode(opt)
    } catch (e: Throwable) {
      if (done.compareAndSet(false, true)) {
        try { coder.destroy() } catch (_: Throwable) {}
        result.error("baidu_sdk_reverse_failed", e.message ?: "reverseGeoCode failed", null)
      }
    }
  }

  /**
   * Baidu Map Search SDK：周边 POI 检索（radius 内）。
   *
   * 说明：Search SDK 的 nearby 检索需要 keyword，因此这里支持传入多个关键字并聚合去重，
   * 用于覆盖“公司/餐饮/住宿/商店”等常见场景。
   */
  fun searchNearbyPoisBaiduSdk(
    ctx: Context,
    lat: Double,
    lng: Double,
    radius: Int,
    coordType: String?,
    keywords: List<String>,
    result: MethodChannel.Result
  ) {
    val safeRadius = radius.coerceIn(10, 1000)
    val center = toBd09ll(lat, lng, coordType)

    // IMPORTANT: 不要在 platform 主线程阻塞等待，否则会导致 UI 卡顿/ANR。
    val main = Handler(Looper.getMainLooper())
    val replied = AtomicBoolean(false)

    Thread {
      val kws = if (keywords.isEmpty()) {
        listOf("公司", "餐厅", "酒店", "商店", "超市", "便利店")
      } else {
        // 防御：限制关键字数量，避免过多请求。
        keywords.filter { it.isNotBlank() }.take(8)
      }

      // 聚合去重：name|lat|lng
      val out = LinkedHashMap<String, MutableMap<String, Any?>>()

      fun addPoi(pi: PoiInfo) {
        val loc = pi.location ?: return
        val name = (pi.name ?: "").trim()
        if (name.isEmpty()) return
        val addr = (pi.address ?: "").trim()

        val dArr = FloatArray(1)
        try {
          Location.distanceBetween(center.latitude, center.longitude, loc.latitude, loc.longitude, dArr)
        } catch (_: Throwable) {
          dArr[0] = 9_999_999f
        }
        val dist = dArr[0].toInt()
        if (dist > safeRadius) return

        val k = name + "|" + String.format("%.6f", loc.latitude) + "|" + String.format("%.6f", loc.longitude)
        if (out.containsKey(k)) return
        out[k] = hashMapOf(
          "name" to name,
          "address" to addr,
          "lat" to loc.latitude,
          "lng" to loc.longitude,
          "distance" to dist
        )
      }

      for (kw in kws) {
        val latch = CountDownLatch(1)
        main.post {
          try {
            val search = PoiSearch.newInstance()
            search.setOnGetPoiSearchResultListener(object : OnGetPoiSearchResultListener {
              override fun onGetPoiResult(res: PoiResult?) {
                try {
                  if (res != null && res.error == SearchResult.ERRORNO.NO_ERROR) {
                    val all = res.allPoi
                    if (all != null) {
                      for (pi in all) {
                        try { addPoi(pi) } catch (_: Throwable) {}
                      }
                    }
                  }
                } catch (_: Throwable) {
                } finally {
                  try { search.destroy() } catch (_: Throwable) {}
                  latch.countDown()
                }
              }

              override fun onGetPoiDetailResult(detail: com.baidu.mapapi.search.poi.PoiDetailResult?) {
                // ignore
              }

              override fun onGetPoiDetailResult(detail: com.baidu.mapapi.search.poi.PoiDetailSearchResult?) {
                // ignore
              }

              override fun onGetPoiIndoorResult(indoor: com.baidu.mapapi.search.poi.PoiIndoorResult?) {
                // ignore
              }
            })

            val opt = PoiNearbySearchOption()
              .location(center)
              .radius(safeRadius)
              .keyword(kw)
              .pageCapacity(20)
              .pageNum(0)

            val started = search.searchNearby(opt)
            if (!started) {
              try { search.destroy() } catch (_: Throwable) {}
              latch.countDown()
            }
          } catch (_: Throwable) {
            latch.countDown()
          }
        }

        // 每个关键字等待短超时，避免长时间卡住。
        try { latch.await(1800, TimeUnit.MILLISECONDS) } catch (_: Throwable) {}
      }

      // 结果按距离排序输出
      val list = out.values.toMutableList()
      list.sortBy { (it["distance"] as? Number)?.toInt() ?: Int.MAX_VALUE }

      main.post {
        if (replied.getAndSet(true)) return@post
        result.success(
          hashMapOf(
            "centerLat" to center.latitude,
            "centerLng" to center.longitude,
            "pois" to list
          )
        )
      }
    }.start()
  }

  // ---------------------------------------------------------------------------
  // System high-accuracy stream helpers (Fused + GPS)
  // ---------------------------------------------------------------------------

  private fun obtainFusedHighAcc(ctx: Context, targetAccMeters: Double, timeoutMs: Long): Location? {
    return try {
      val client = LocationServices.getFusedLocationProviderClient(ctx)
      val latch = CountDownLatch(1)
      var best: Location? = null

      val req = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L)
        .setWaitForAccurateLocation(true)
        .setMaxUpdates(6)
        .build()

      val cb = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
          for (l in result.locations) {
            if (best == null || l.accuracy < best!!.accuracy) best = l
          }
          if (best != null && best!!.accuracy < targetAccMeters) {
            try { latch.countDown() } catch (_: Throwable) {}
          }
        }
      }

      try { client.requestLocationUpdates(req, cb, Looper.getMainLooper()) } catch (_: Throwable) {}
      try { latch.await(timeoutMs, TimeUnit.MILLISECONDS) } catch (_: Throwable) {}
      try { client.removeLocationUpdates(cb) } catch (_: Throwable) {}
      best
    } catch (_: Throwable) {
      null
    }
  }

  private fun obtainGpsHighAcc(ctx: Context, targetAccMeters: Double, timeoutMs: Long): Location? {
    return try {
      val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
      val latch = CountDownLatch(1)
      var best: Location? = null

      val listener = object : LocationListener {
        override fun onLocationChanged(loc: Location) {
          if (best == null || loc.accuracy < best!!.accuracy) best = loc
          if (best != null && best!!.accuracy < targetAccMeters) {
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
      null
    }
  }
  // ---- Coordinate conversion helpers (no Baidu Map utils dependency) ----
  // Many Baidu Search/GeoCoder APIs assume BD09LL in Mainland China. System providers usually output WGS84.
  // We convert WGS84 -> GCJ02 -> BD09 to keep the reverse-geocode center consistent.
  private fun toBd09ll(lat: Double, lng: Double, coordType: String?): LatLng {
    val t = (coordType ?: "bd09ll").lowercase()
    return when (t) {
      "bd09ll", "bd09" -> LatLng(lat, lng)
      "gcj02", "common" -> {
        val bd = gcj02ToBd09(lat, lng)
        LatLng(bd[0], bd[1])
      }
      "gps", "wgs84" -> {
        val gcj = wgs84ToGcj02(lat, lng)
        val bd = gcj02ToBd09(gcj[0], gcj[1])
        LatLng(bd[0], bd[1])
      }
      else -> LatLng(lat, lng)
    }
  }

  private fun outOfChina(lat: Double, lon: Double): Boolean {
    return lon < 72.004 || lon > 137.8347 || lat < 0.8293 || lat > 55.8271
  }

  private fun wgs84ToGcj02(lat: Double, lon: Double): DoubleArray {
    if (outOfChina(lat, lon)) return doubleArrayOf(lat, lon)
    val a = 6378245.0
    val ee = 0.00669342162296594323
    var dLat = transformLat(lon - 105.0, lat - 35.0)
    var dLon = transformLon(lon - 105.0, lat - 35.0)
    val radLat = lat / 180.0 * Math.PI
    var magic = Math.sin(radLat)
    magic = 1 - ee * magic * magic
    val sqrtMagic = Math.sqrt(magic)
    dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Math.PI)
    dLon = (dLon * 180.0) / (a / sqrtMagic * Math.cos(radLat) * Math.PI)
    val mgLat = lat + dLat
    val mgLon = lon + dLon
    return doubleArrayOf(mgLat, mgLon)
  }

  private fun gcj02ToBd09(lat: Double, lon: Double): DoubleArray {
    val xPi = Math.PI * 3000.0 / 180.0
    val x = lon
    val y = lat
    val z = Math.sqrt(x * x + y * y) + 0.00002 * Math.sin(y * xPi)
    val theta = Math.atan2(y, x) + 0.000003 * Math.cos(x * xPi)
    val bdLon = z * Math.cos(theta) + 0.0065
    val bdLat = z * Math.sin(theta) + 0.006
    return doubleArrayOf(bdLat, bdLon)
  }

  private fun transformLat(x: Double, y: Double): Double {
    var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x))
    ret += (20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0 / 3.0
    ret += (20.0 * Math.sin(y * Math.PI) + 40.0 * Math.sin(y / 3.0 * Math.PI)) * 2.0 / 3.0
    ret += (160.0 * Math.sin(y / 12.0 * Math.PI) + 320.0 * Math.sin(y * Math.PI / 30.0)) * 2.0 / 3.0
    return ret
  }

  private fun transformLon(x: Double, y: Double): Double {
    var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x))
    ret += (20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0 / 3.0
    ret += (20.0 * Math.sin(x * Math.PI) + 40.0 * Math.sin(x / 3.0 * Math.PI)) * 2.0 / 3.0
    ret += (150.0 * Math.sin(x / 12.0 * Math.PI) + 300.0 * Math.sin(x / 30.0 * Math.PI)) * 2.0 / 3.0
    return ret
  }
}