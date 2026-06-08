package com.example.quote_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * 行为观察桌面小组件。
 *
 * V29 调整：小组件按钮不再进入 Flutter 首页，也不再先弹通知。
 * 用户点击某个观察层面后，直接打开原生轻量表单 Activity，
 * 填完保存后 Activity 自动关闭，记录直接写入本地数据库。
 */
class BehaviorObservationWidgetProvider : AppWidgetProvider() {
  override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
    for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
  }

  override fun onReceive(context: Context, intent: Intent?) {
    super.onReceive(context, intent)
    if (intent?.action == ACTION_REFRESH_WIDGET) {
      refreshAll(context.applicationContext)
    }
  }

  companion object {
    private const val ACTION_REFRESH_WIDGET = "com.example.quote_app.behavior_observation_widget.REFRESH"

    @JvmStatic
    fun refreshAll(context: Context) {
      val mgr = AppWidgetManager.getInstance(context)
      val cn = ComponentName(context, BehaviorObservationWidgetProvider::class.java)
      val ids = mgr.getAppWidgetIds(cn)
      for (id in ids) updateWidget(context, mgr, id)
    }

    @JvmStatic
    fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
      val views = RemoteViews(context.packageName, R.layout.behavior_observation_widget)
      bindLayer(context, views, appWidgetId, R.id.widget_btn_behavior, "行为层面")
      bindLayer(context, views, appWidgetId, R.id.widget_btn_time, "时间层面")
      bindLayer(context, views, appWidgetId, R.id.widget_btn_emotion, "情绪层面")
      bindLayer(context, views, appWidgetId, R.id.widget_btn_cognition, "认知层面")
      bindLayer(context, views, appWidgetId, R.id.widget_btn_result, "结果层面")
      bindLayer(context, views, appWidgetId, R.id.widget_btn_environment, "环境层面")
      bindLayer(context, views, appWidgetId, R.id.widget_btn_body, "身体状态层面")
      appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun bindLayer(context: Context, views: RemoteViews, appWidgetId: Int, viewId: Int, layer: String) {
      val intent = Intent(context, BehaviorObservationWidgetFormActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        putExtra("primaryLayer", layer)
        putExtra("source", "desktop_widget")
        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
      }
      val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      val requestCode = appWidgetId * 100 + (layer.hashCode() and 0x7fffffff) % 997
      val pi = PendingIntent.getActivity(context, requestCode, intent, flags)
      views.setOnClickPendingIntent(viewId, pi)
    }
  }
}
