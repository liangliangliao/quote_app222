
package com.example.quote_app

import android.app.Activity
import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.os.Build
import android.os.Bundle

class FgKickActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    try {
      if (!hasAnyLocationPermission()) {
        // 未授权定位权限时直接跳过，避免 Android 14+ 启动 location 前台服务导致崩溃
        finish()
        return
      }
      val intent = Intent(this, GeoForegroundService::class.java)
      if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
    } catch (_: Throwable) {}
    finish()
  }


  private fun hasAnyLocationPermission(): Boolean {
    return try {
      val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
      val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
      fine || coarse
    } catch (_: Throwable) {
      false
    }
  }
}