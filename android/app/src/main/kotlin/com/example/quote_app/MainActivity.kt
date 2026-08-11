package com.example.quote_app

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent

import com.example.quote_app.ppg.PpgCamera2Channel
import com.example.quote_app.wallpaper.MystifyPreviewPlatformViewFactory

class MainActivity : FlutterActivity() {


    private fun maybeHandleNotificationIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra("from_notification", false)) {
            // Extract additional extras for navigation
            val notifType = intent.getStringExtra("notif_type")
            val payload = intent.getStringExtra("payload")
            // Record and emit the event with type/payload
            Channels.markNotificationTapped()
            Channels.emitNotificationTap(notifType, payload)
            BehaviorTrackingNativeChannel.onNotificationIntent(notifType, payload)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Edge-to-edge: allow Flutter to draw behind the system status/navigation bars.
        // This is required for background images/colors to be visible under 3-button navigation.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Disable the Android 10+ contrast-enforcement scrims that would otherwise turn
            // the status bar / 3-button navigation areas into opaque backgrounds.
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        maybeHandleNotificationIntent(intent)
        try {
            if (intent?.getBooleanExtra("from_notification", false) == true) {
                com.example.quote_app.data.DbRepo.log(
                    applicationContext,
                    null,
                    "[NotifTap] onCreate from_notification=true"
                )
            }
        } catch (_: Throwable) {}
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        maybeHandleNotificationIntent(intent)
        try {
            if (intent.getBooleanExtra("from_notification", false)) {
                com.example.quote_app.data.DbRepo.log(
                    applicationContext,
                    null,
                    "[NotifTap] onNewIntent from_notification=true"
                )
            }
        } catch (_: Throwable) {}
    }


    @Deprecated("Deprecated in Android framework; kept for Health Connect permission contract bridge.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (HealthDietHealthConnectChannel.handleActivityResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 仅注册通道；不引入业务逻辑，避免后续维护成本
        Channels.register(flutterEngine, applicationContext)
		// 高精度 PPG：Android Camera2（含可选预览）
		try { PpgCamera2Channel.register(flutterEngine, applicationContext) } catch (_: Throwable) {}
		try { HealthDietHealthConnectChannel.register(this, flutterEngine) } catch (_: Throwable) {}
		try { BehaviorTrackingNativeChannel.register(this, flutterEngine) } catch (_: Throwable) {}
		try { VoiceAlarmChannel.register(flutterEngine, applicationContext) } catch (_: Throwable) {}
		try { WillMirrorVaultChannel.register(flutterEngine, applicationContext) } catch (_: Throwable) {}
			// 发现之旅/触摸：动态艺术壁纸（Mystify 亲密艺术）原生通道。
			try { IntimacyWallpaperChannel.register(this, flutterEngine) } catch (_: Throwable) {}
			// 触摸页原生 OpenGL 预览：复用动态壁纸同一套 renderer，避免 Flutter 预览与真实壁纸效果不一致。
			try {
				flutterEngine.platformViewsController.registry.registerViewFactory(
					"com.example.quote_app/intimacy_mystify_preview",
					MystifyPreviewPlatformViewFactory()
				)
			} catch (_: Throwable) {}
	        // 注意：SysChannel 与 Channels 使用相同 MethodChannel 名称（com.example.quote_app/sys）。
	        // 为避免 handler 被覆盖导致系统/权限相关方法丢失，这里不再重复注册 SysChannel。
    }
}
