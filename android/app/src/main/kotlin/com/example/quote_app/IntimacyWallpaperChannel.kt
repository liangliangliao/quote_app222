package com.example.quote_app

import android.app.Activity
import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.service.wallpaper.WallpaperService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.example.quote_app.wallpaper.IntimacyMystifyWallpaperService

object IntimacyWallpaperChannel {
    private const val CHANNEL = "com.example.quote_app/intimacy_wallpaper"
    private const val PREFS = "intimacy_mystify_wallpaper"

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            try {
                when (call.method) {
                    "saveConfig" -> {
                        val prefs = activity.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        val editor = prefs.edit()
                        editor.putInt("style", numberArg(call, "style", 0.0).toInt())
                        editor.putString("wallpaperMode", call.argument<String>("wallpaperMode") ?: "mystify")
                        editor.putString("calligraphyText", (call.argument<String>("calligraphyText") ?: "行到水穷处，坐看云起时。").take(80))
                        editor.putString("calligraphyStyle", call.argument<String>("calligraphyStyle") ?: "kaishu")
                        editor.putFloat("calligraphySpeed", numberArg(call, "calligraphySpeed", 0.55).toFloat().coerceIn(0.15f, 1f))
                        editor.putString("calligraphyStrokeData", call.argument<String>("calligraphyStrokeData") ?: "{}")
                        editor.putString("calligraphyPlaylist", call.argument<String>("calligraphyPlaylist") ?: "[]")
                        editor.putString("calligraphyAiHistory", call.argument<String>("calligraphyAiHistory") ?: "[]")
                        editor.putFloat("intimacy", numberArg(call, "intimacy", 0.72).toFloat().coerceIn(0f, 1f))
                        editor.putFloat("randomness", numberArg(call, "randomness", 0.72).toFloat().coerceIn(0f, 1f))
                        editor.putFloat("ribbonWidth", numberArg(call, "ribbonWidth", 0.48).toFloat().coerceIn(0f, 1f))
                        editor.putFloat("trail", numberArg(call, "trail", 0.88).toFloat().coerceIn(0f, 1f))
                        editor.putFloat("fullScreenCoverage", numberArg(call, "fullScreenCoverage", 0.96).toFloat().coerceIn(0f, 1f))
                        editor.putFloat("strokeDensity", numberArg(call, "strokeDensity", 0.32).toFloat().coerceIn(0f, 1f))
                        editor.putBoolean("previewAccelerated", call.argument<Boolean>("previewAccelerated") ?: false)
                        editor.putFloat("previewCycleMinutes", numberArg(call, "previewCycleMinutes", 3.0).toFloat().coerceIn(0.5f, 60f))
                        editor.putBoolean("debugLoopEnabled", call.argument<Boolean>("debugLoopEnabled") ?: false)
                        editor.putFloat("debugCycleMinutes", numberArg(call, "debugCycleMinutes", 3.0).toFloat().coerceIn(1f, 60f))
                        editor.putBoolean("bubbles", call.argument<Boolean>("bubbles") ?: false)
                        editor.putBoolean("powerSave", call.argument<Boolean>("powerSave") ?: false)
                        editor.putBoolean("randomCycle", call.argument<Boolean>("randomCycle") ?: true)
                        editor.putFloat("cycleMinDays", numberArg(call, "cycleMinDays", 1.0).toFloat().coerceIn(1f, 365f))
                        editor.putFloat("cycleMaxDays", numberArg(call, "cycleMaxDays", 365.0).toFloat().coerceIn(1f, 365f))
                        editor.putFloat("fixedCycleDays", numberArg(call, "fixedCycleDays", 30.0).toFloat().coerceIn(1f, 365f))
                        editor.putFloat("ratioSeparation", numberArg(call, "ratioSeparation", 0.46).toFloat().coerceIn(0.001f, 1f))
                        editor.putFloat("ratioAttraction", numberArg(call, "ratioAttraction", 0.22).toFloat().coerceIn(0.001f, 1f))
                        editor.putFloat("ratioSync", numberArg(call, "ratioSync", 0.22).toFloat().coerceIn(0.001f, 1f))
                        editor.putFloat("ratioCritical", numberArg(call, "ratioCritical", 0.06).toFloat().coerceIn(0.001f, 1f))
                        editor.putFloat("ratioRelease", numberArg(call, "ratioRelease", 0.02).toFloat().coerceIn(0.001f, 1f))
                        editor.putFloat("ratioAfterglow", numberArg(call, "ratioAfterglow", 0.02).toFloat().coerceIn(0.001f, 1f))
                        editor.putFloat("criticalMinSec", numberArg(call, "criticalMinSec", 30.0).toFloat().coerceIn(5f, 3600f))
                        editor.putFloat("criticalMaxSec", numberArg(call, "criticalMaxSec", 180.0).toFloat().coerceIn(5f, 7200f))
                        editor.putFloat("releaseMinSec", numberArg(call, "releaseMinSec", 8.0).toFloat().coerceIn(2f, 600f))
                        editor.putFloat("releaseMaxSec", numberArg(call, "releaseMaxSec", 24.0).toFloat().coerceIn(2f, 1200f))
                        editor.putFloat("afterglowMinSec", numberArg(call, "afterglowMinSec", 20.0).toFloat().coerceIn(3f, 1800f))
                        editor.putFloat("afterglowMaxSec", numberArg(call, "afterglowMaxSec", 90.0).toFloat().coerceIn(3f, 3600f))
                        editor.putString("puzzleImagePaths", call.argument<String>("puzzleImagePaths") ?: "[]")
                        editor.putString("puzzleRotationMode", call.argument<String>("puzzleRotationMode") ?: "sequential")
                        editor.putInt("puzzleCols", numberArg(call, "puzzleCols", 5.0).toInt().coerceIn(2, 14))
                        editor.putInt("puzzleRows", numberArg(call, "puzzleRows", 7.0).toInt().coerceIn(2, 16))
                        editor.putFloat("puzzleAssembleSeconds", numberArg(call, "puzzleAssembleSeconds", 4.0).toFloat().coerceIn(1f, 1200f))
                        editor.putFloat("puzzleHoldSeconds", numberArg(call, "puzzleHoldSeconds", 2.0).toFloat().coerceIn(0.3f, 1200f))
                        editor.putFloat("puzzleScatterRadius", numberArg(call, "puzzleScatterRadius", 0.85).toFloat().coerceIn(0.2f, 2f))
                        editor.putInt("puzzleBatchSize", numberArg(call, "puzzleBatchSize", 0.0).toInt().coerceIn(0, 400))
                        val nowMs = System.currentTimeMillis()
                        val resetSeed = call.argument<Boolean>("resetSeed") ?: true
                        if (resetSeed) {
                            editor.putLong("seed", nowMs + (Math.random() * 1000000000.0).toLong())
                        }
                        editor.putLong("configUpdatedAtMs", nowMs)
                        // Use commit() here instead of apply(): the live wallpaper renderer may be
                        // running in another thread/process context and should see the new values
                        // before the UI tells the user they were saved.
                        result.success(editor.commit())
                    }
                    "getConfig" -> {
                        val prefs = activity.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        result.success(mapOf(
                            "wallpaperMode" to (prefs.getString("wallpaperMode", "mystify") ?: "mystify"),
                            "calligraphyText" to (prefs.getString("calligraphyText", "行到水穷处，坐看云起时。") ?: "行到水穷处，坐看云起时。"),
                            "calligraphyStyle" to (prefs.getString("calligraphyStyle", "kaishu") ?: "kaishu"),
                            "calligraphySpeed" to prefs.getFloat("calligraphySpeed", 0.55f).toDouble(),
                            "calligraphyStrokeData" to (prefs.getString("calligraphyStrokeData", "{}") ?: "{}"),
                            "calligraphyPlaylist" to (prefs.getString("calligraphyPlaylist", "[]") ?: "[]"),
                            "calligraphyAiHistory" to (prefs.getString("calligraphyAiHistory", "[]") ?: "[]"),
                            "puzzleImagePaths" to (prefs.getString("puzzleImagePaths", "[]") ?: "[]"),
                            "puzzleRotationMode" to (prefs.getString("puzzleRotationMode", "sequential") ?: "sequential"),
                            "puzzleCols" to prefs.getInt("puzzleCols", 5),
                            "puzzleRows" to prefs.getInt("puzzleRows", 7),
                            "puzzleAssembleSeconds" to prefs.getFloat("puzzleAssembleSeconds", 4f).toDouble(),
                            "puzzleHoldSeconds" to prefs.getFloat("puzzleHoldSeconds", 2f).toDouble(),
                            "puzzleScatterRadius" to prefs.getFloat("puzzleScatterRadius", 0.85f).toDouble(),
                            "puzzleBatchSize" to prefs.getInt("puzzleBatchSize", 0)
                        ))
                    }
                    "setLiveWallpaperDirect" -> {
                        val component = ComponentName(activity, IntimacyMystifyWallpaperService::class.java)
                        try {
                            // setWallpaperComponent is not available in the public SDK on all
                            // compileSdk / vendor combinations. Calling it directly breaks
                            // Kotlin compilation in those environments, so use reflection.
                            // If the platform blocks or does not expose it, return false and
                            // let Dart fall back to ACTION_CHANGE_LIVE_WALLPAPER preview.
                            val wm = WallpaperManager.getInstance(activity.applicationContext)
                            val method = WallpaperManager::class.java.getMethod(
                                "setWallpaperComponent",
                                ComponentName::class.java
                            )
                            method.invoke(wm, component)
                            result.success(true)
                        } catch (_: Throwable) {
                            result.success(false)
                        }
                    }
                    "openLiveWallpaper" -> {
                        // Do not claim success just because an implicit Intent object was created.
                        // Some OEM systems silently ignore ACTION_CHANGE_LIVE_WALLPAPER when it is
                        // launched from a FlutterActivity. Route through a tiny native Activity that
                        // launches the system wallpaper UI on the main thread and contains multiple
                        // fallbacks: exact live wallpaper preview -> live wallpaper chooser -> system
                        // wallpaper settings -> generic wallpaper picker.
                        try {
                            val launcher = Intent(activity, WallpaperApplyActivity::class.java).apply {
                                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                putExtra("source", "touch_mystify_page")
                            }
                            activity.startActivity(launcher)
                            result.success(true)
                        } catch (t: Throwable) {
                            result.error("OPEN_WALLPAPER_UI_FAILED", t.message ?: t.javaClass.simpleName, null)
                        }
                    }
                    "isLiveWallpaperApplied" -> {
                        val info = WallpaperManager.getInstance(activity.applicationContext).wallpaperInfo
                        val active = info != null &&
                                info.packageName == activity.packageName &&
                                info.serviceName == IntimacyMystifyWallpaperService::class.java.name
                        result.success(active)
                    }
                    "getLiveWallpaperDiagnostic" -> {
                        val pm = activity.packageManager
                        val serviceIntent = Intent(WallpaperService.SERVICE_INTERFACE)
                        val services = pm.queryIntentServices(serviceIntent, 0)
                        val ourServiceName = IntimacyMystifyWallpaperService::class.java.name
                        val registered = services.any { it.serviceInfo.packageName == activity.packageName && it.serviceInfo.name == ourServiceName }
                        val info = WallpaperManager.getInstance(activity.applicationContext).wallpaperInfo
                        val applied = info != null && info.packageName == activity.packageName && info.serviceName == ourServiceName
                        val previewIntent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
                            putExtra(
                                WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                                ComponentName(activity, IntimacyMystifyWallpaperService::class.java)
                            )
                        }
                        val chooserIntent = Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER)
                        @Suppress("DEPRECATION")
                        val previewTargets = pm.queryIntentActivities(previewIntent, 0).size
                        @Suppress("DEPRECATION")
                        val chooserTargets = pm.queryIntentActivities(chooserIntent, 0).size
                        val enableState = when {
                            applied -> "applied"
                            registered -> "registered_not_enabled"
                            else -> "not_registered"
                        }
                        val guide = when (enableState) {
                            "applied" -> "潮汐之间已经成为当前动态壁纸。"
                            "registered_not_enabled" -> "系统已识别潮汐之间，但尚未开启为当前动态壁纸。请进入系统动态壁纸页选择潮汐之间并点击设置壁纸/应用。"
                            else -> "系统尚未识别潮汐之间动态壁纸服务。请确认安装最新版，并在应用系统设置中允许后台运行/自启动/电池无限制后重试。"
                        }
                        result.success(mapOf(
                            "packageName" to activity.packageName,
                            "serviceName" to ourServiceName,
                            "registeredInLiveWallpaperList" to registered,
                            "availableLiveWallpaperServices" to services.size,
                            "previewIntentTargets" to previewTargets,
                            "chooserIntentTargets" to chooserTargets,
                            "applied" to applied,
                            "enableState" to enableState,
                            "needsEnableGuide" to !applied,
                            "enableGuide" to guide,
                            "currentWallpaperPackage" to (info?.packageName ?: ""),
                            "currentWallpaperService" to (info?.serviceName ?: "")
                        ))
                    }
                    "isSupported" -> result.success(true)
                    "savePuzzleImage" -> {
                        val srcPath = call.argument<String>("path")
                        if (srcPath.isNullOrEmpty()) {
                            result.error("NO_PATH", "path missing", null)
                        } else {
                            try {
                                val srcFile = java.io.File(srcPath)
                                if (!srcFile.exists()) {
                                    result.error("FILE_NOT_FOUND", "source file does not exist", null)
                                } else {
                                    // 把图片拷贝进 App 私有存储（filesDir，非缓存目录），这样动态壁纸
                                    // 引擎（可能在系统重启/不同进程上下文中运行）始终能用一个稳定路径
                                    // 读到图片，不依赖 image_picker 临时文件或 content:// Uri 的持久化
                                    // 授权。
                                    //
                                    // 关键修复：文件名必须带上时间戳+随机数等唯一后缀。早期版本固定用
                                    // 同一个文件名（puzzle_wallpaper_source.jpg），导致"更换图片"时新图片
                                    // 覆盖旧文件但路径字符串完全不变——原生引擎判断"是否要重新解码"是按
                                    // 路径是否变化来判断的，路径没变就永远不会重新加载新图内容，
                                    // 于是看起来像是"换图失败"。现在每张图片都有独立、稳定的路径，
                                    // 同时也是支持多图轮换的基础。
                                    val uniqueName = "puzzle_src_${System.currentTimeMillis()}_${(1000..9999).random()}.jpg"
                                    val destFile = java.io.File(activity.applicationContext.filesDir, uniqueName)
                                    srcFile.copyTo(destFile, overwrite = false)
                                    result.success(destFile.absolutePath)
                                }
                            } catch (t: Throwable) {
                                result.error("COPY_FAILED", t.message ?: t.javaClass.simpleName, null)
                            }
                        }
                    }
                    "deletePuzzleImageFile" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.success(false)
                        } else {
                            try {
                                val f = java.io.File(path)
                                // 安全检查：只允许删除 App 自己私有存储目录下、以拼图前缀命名的文件，
                                // 避免被滥用为任意路径删除。
                                val isOwnFile = f.parentFile?.absolutePath == activity.applicationContext.filesDir.absolutePath &&
                                        f.name.startsWith("puzzle_src_")
                                if (isOwnFile && f.exists()) {
                                    result.success(f.delete())
                                } else {
                                    result.success(false)
                                }
                            } catch (t: Throwable) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                result.error("INTIMACY_WALLPAPER", t.message ?: t.javaClass.simpleName, null)
            }
        }
    }

    private fun numberArg(call: MethodCall, name: String, fallback: Double): Double {
        val v = call.argument<Any>(name) ?: return fallback
        return when (v) {
            is Int -> v.toDouble()
            is Long -> v.toDouble()
            is Float -> v.toDouble()
            is Double -> v
            is Number -> v.toDouble()
            else -> fallback
        }
    }
}
