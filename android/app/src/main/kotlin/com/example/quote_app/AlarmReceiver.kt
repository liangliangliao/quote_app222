package com.example.quote_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 保留一个无副作用的占位 Receiver（Kotlin 版）。真正的 AM 主通道使用 Java 包 com.example.quote_app.am.AlarmReceiver。
 * 该类仅仅保证项目可编译，不参与业务。
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // no-op
    }
}