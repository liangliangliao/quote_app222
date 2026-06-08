package com.example.quote_app

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast

/**
 * 长按应用图标的静态快捷方式入口：尝试拉起系统“小组件固定到桌面”流程。
 *
 * 说明：是否在“长按 App 图标”里展示小组件入口由桌面启动器决定，应用无法强制。
 * 但静态快捷方式通常可以显示在长按菜单中，用来补足用户找不到小组件入口的问题。
 */
class BehaviorObservationWidgetPinActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    tryRequestPin()
    finish()
  }

  private fun tryRequestPin() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val manager = getSystemService(AppWidgetManager::class.java)
      val provider = ComponentName(this, BehaviorObservationWidgetProvider::class.java)
      if (manager != null && manager.isRequestPinAppWidgetSupported) {
        val successIntent = Intent(this, BehaviorObservationWidgetProvider::class.java)
        val successCallback = PendingIntent.getBroadcast(
          this,
          2901,
          successIntent,
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        manager.requestPinAppWidget(provider, null, successCallback)
        Toast.makeText(this, "请选择添加“行为观察”桌面小组件", Toast.LENGTH_LONG).show()
        return
      }
    }
    Toast.makeText(this, "当前桌面不支持应用内添加，请长按桌面空白处 → 小组件 → 名人名言 → 行为观察", Toast.LENGTH_LONG).show()
    try {
      startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    } catch (_: Throwable) {}
  }
}
