package com.example.quote_app

import android.app.Activity
import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.wallpaper.WallpaperService
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.example.quote_app.wallpaper.IntimacyMystifyWallpaperService

/**
 * Live-wallpaper enable/apply helper.
 *
 * Important: third-party apps cannot reliably enable a live wallpaper silently.
 * The user must choose this WallpaperService in the system live-wallpaper UI and
 * press "设置壁纸/应用". This helper detects the current state and guides the user
 * instead of pretending that an Intent launch equals successful application.
 */
class WallpaperApplyActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var launchedExternalUi = false
    private lateinit var root: LinearLayout
    private lateinit var statusView: TextView
    private lateinit var guideView: TextView

    private val wallpaperComponent: ComponentName by lazy {
        ComponentName(this, IntimacyMystifyWallpaperService::class.java)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        buildUi()
        refreshStatus()
        handler.postDelayed({
            // Auto-try once, but keep the helper visible if the OEM ROM ignores it.
            launchExactPreview(showToastOnFailure = false)
        }, 300L)
    }

    override fun onResume() {
        super.onResume()
        refreshStatus()
    }

    override fun onStop() {
        super.onStop()
        if (launchedExternalUi) {
            // Do not finish immediately. Some OEM wallpaper pages open as overlays or return
            // quickly. Delay a little so the user can come back and see the updated status.
            handler.postDelayed({ if (!isFinishing) refreshStatus() }, 600L)
        }
    }

    private data class EnableState(
        val registered: Boolean,
        val applied: Boolean,
        val serviceCount: Int,
        val previewTargets: Int,
        val chooserTargets: Int,
        val currentPackage: String,
        val currentService: String
    )

    private fun readState(): EnableState {
        val pm = packageManager
        val ourServiceName = IntimacyMystifyWallpaperService::class.java.name
        val services = pm.queryIntentServices(Intent(WallpaperService.SERVICE_INTERFACE), 0)
        val registered = services.any {
            it.serviceInfo.packageName == packageName && it.serviceInfo.name == ourServiceName
        }
        val info = WallpaperManager.getInstance(applicationContext).wallpaperInfo
        val applied = info != null && info.packageName == packageName && info.serviceName == ourServiceName
        val previewIntent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
            putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, wallpaperComponent)
        }
        val chooserIntent = Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER)
        return EnableState(
            registered = registered,
            applied = applied,
            serviceCount = services.size,
            previewTargets = pm.queryIntentActivities(previewIntent, 0).size,
            chooserTargets = pm.queryIntentActivities(chooserIntent, 0).size,
            currentPackage = info?.packageName ?: "",
            currentService = info?.serviceName ?: ""
        )
    }

    private fun buildUi() {
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(28), dp(22), dp(28))
            setBackgroundColor(Color.rgb(4, 7, 18))
        }
        val scroll = ScrollView(this).apply { addView(root) }
        setContentView(scroll)

        root.addView(text("动态壁纸应用助手", 24f, true, Color.WHITE))
        root.addView(text(
            "此页面会检测“潮汐之间”动态壁纸服务是否被系统识别、是否已经启用。若未启用，必须进入系统动态壁纸页面选择“潮汐之间”，再点击“设置壁纸 / 应用”。",
            15f,
            false,
            Color.rgb(205, 213, 230)
        ).apply { setPadding(0, dp(10), 0, dp(16)) })

        statusView = text("正在检测动态壁纸状态...", 14f, false, Color.rgb(232, 232, 238)).apply {
            setPadding(dp(14), dp(12), dp(14), dp(12))
            background = rounded(Color.argb(72, 255, 255, 255), Color.argb(42, 255, 255, 255), dp(18))
        }
        root.addView(statusView)

        guideView = text("", 14f, false, Color.rgb(224, 231, 255)).apply {
            setPadding(dp(14), dp(12), dp(14), dp(12))
            background = rounded(Color.argb(54, 100, 116, 255), Color.argb(68, 160, 170, 255), dp(18))
            val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            lp.topMargin = dp(10)
            layoutParams = lp
        }
        root.addView(guideView)

        root.addView(button("1. 打开本动态壁纸预览页", true) { launchExactPreview(true) })
        root.addView(button("2. 打开动态壁纸列表", false) { launchLiveWallpaperChooser(true) })
        root.addView(button("3. 打开系统壁纸设置", false) { launchWallpaperSettings(true) })
        root.addView(button("4. 打开通用壁纸选择器", false) { launchGenericWallpaperPicker(true) })
        root.addView(button("5. 打开本应用系统设置", false) { launchAppDetails(true) })
        root.addView(button("刷新检测状态", false) { refreshStatus(); toast("已刷新动态壁纸状态") })
        root.addView(button("返回应用", false) { finish() })
    }

    private fun refreshStatus() {
        if (!::statusView.isInitialized || !::guideView.isInitialized) return
        val state = readState()
        val statusText = when {
            state.applied -> "当前状态：已开启。潮汐之间已成为当前动态壁纸。"
            state.registered -> "当前状态：系统已识别潮汐之间，但尚未启用为当前动态壁纸。"
            else -> "当前状态：系统尚未识别潮汐之间动态壁纸服务。"
        }
        statusView.text = statusText + "\n\n" +
            "系统动态壁纸服务数：${state.serviceCount}\n" +
            "指定预览入口目标数：${state.previewTargets}\n" +
            "动态壁纸列表入口目标数：${state.chooserTargets}\n" +
            "当前动态壁纸：${state.currentPackage.ifEmpty { "无/静态壁纸" }}${if (state.currentService.isNotEmpty()) "\n${state.currentService}" else ""}"
        statusView.setTextColor(if (state.applied) Color.rgb(185, 255, 205) else Color.rgb(232, 232, 238))

        guideView.text = when {
            state.applied -> "已完成：动态壁纸服务已启用。返回桌面即可看到真实壁纸效果。"
            state.registered -> "需要开启：请点击“1. 打开本动态壁纸预览页”。如果没有反应，点“2. 打开动态壁纸列表”，在列表中选择“潮汐之间”，进入预览页后点击“设置壁纸 / 应用”。这一步才等于开启动态壁纸服务。"
            else -> "需要处理：系统没有识别到本应用的动态壁纸服务。请先确认安装的是最新版；如果仍未识别，打开“本应用系统设置”，允许后台运行/自启动/电池无限制后重启应用，再回到系统动态壁纸列表查找“潮汐之间”。"
        }
    }

    private fun launchExactPreview(showToastOnFailure: Boolean) {
        val exact = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
            putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, wallpaperComponent)
        }
        if (tryStart(exact)) return

        val legacy = Intent("android.service.wallpaper.CHANGE_LIVE_WALLPAPER").apply {
            putExtra("android.service.wallpaper.extra.LIVE_WALLPAPER_COMPONENT", wallpaperComponent)
        }
        if (tryStart(legacy)) return

        if (showToastOnFailure) toast("本机未响应指定动态壁纸预览入口，请尝试动态壁纸列表。")
    }

    private fun launchLiveWallpaperChooser(showToastOnFailure: Boolean) {
        if (tryStart(Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER))) return
        if (tryStart(Intent("android.service.wallpaper.LIVE_WALLPAPER_CHOOSER"))) return
        if (showToastOnFailure) toast("本机未提供标准动态壁纸列表入口，请尝试系统壁纸设置。")
    }

    private fun launchWallpaperSettings(showToastOnFailure: Boolean) {
        if (tryStart(Intent("android.settings.WALLPAPER_SETTINGS"))) return
        if (tryStart(Intent("com.android.wallpaper.SETTINGS"))) return
        if (tryStart(Intent("android.intent.action.SET_WALLPAPER"))) return
        if (showToastOnFailure) toast("无法打开系统壁纸设置，请从手机系统设置中手动进入“壁纸/动态壁纸”。")
    }

    private fun launchGenericWallpaperPicker(showToastOnFailure: Boolean) {
        if (tryStart(Intent(Intent.ACTION_SET_WALLPAPER))) return
        if (showToastOnFailure) toast("无法打开通用壁纸选择器。")
    }

    private fun launchAppDetails(showToastOnFailure: Boolean) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        if (tryStart(intent)) return
        if (showToastOnFailure) toast("无法打开应用设置。")
    }

    private fun tryStart(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val resolved = intent.resolveActivity(packageManager)
            if (resolved == null) return false
            startActivity(intent)
            launchedExternalUi = true
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun text(s: String, size: Float, bold: Boolean, color: Int): TextView {
        return TextView(this).apply {
            text = s
            textSize = size
            setTextColor(color)
            setLineSpacing(0f, 1.18f)
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }
    }

    private fun button(label: String, primary: Boolean, action: () -> Unit): Button {
        return Button(this).apply {
            text = label
            textSize = 15f
            setTextColor(if (primary) Color.rgb(10, 15, 30) else Color.WHITE)
            background = rounded(
                if (primary) Color.rgb(224, 231, 255) else Color.argb(52, 255, 255, 255),
                Color.argb(72, 255, 255, 255),
                dp(22)
            )
            setPadding(dp(12), dp(8), dp(12), dp(8))
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(52)
            ).apply { topMargin = dp(10) }
            layoutParams = lp
            gravity = Gravity.CENTER
            setOnClickListener { action() }
        }
    }

    private fun rounded(fill: Int, stroke: Int, radius: Int): GradientDrawable {
        return GradientDrawable().apply {
            setColor(fill)
            cornerRadius = radius.toFloat()
            setStroke(1, stroke)
        }
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_LONG).show()

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density + 0.5f).toInt()
}
