package com.example.quote_app

import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.example.quote_app.data.DbRepo

/**
 * ScreenGatekeeperService（兼容保留）
 * 说明：本类已废弃，不再承担任何前台/守护/自恢复逻辑，仅保留最小实现以保证旧引用编译通过。
 */
class ScreenGatekeeperService : Service() {

  override fun onCreate() {
    super.onCreate()
    try { DbRepo.log(this, null, "【解锁守护服务】onCreate：已废弃，不再注册任何监听或恢复逻辑") } catch (_: Throwable) {}
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    try { DbRepo.log(this, null, "【解锁守护服务】onStartCommand：已禁用（仅记录日志），返回 START_NOT_STICKY") } catch (_: Throwable) {}
    return START_NOT_STICKY
  }

  override fun onTaskRemoved(rootIntent: Intent?) {
    try { DbRepo.log(this, null, "【解锁守护服务】onTaskRemoved：已禁用自我恢复") } catch (_: Throwable) {}
    super.onTaskRemoved(rootIntent)
  }

  override fun onDestroy() {
    try { DbRepo.log(this, null, "【解锁守护服务】onDestroy：已禁用自我恢复") } catch (_: Throwable) {}
    super.onDestroy()
  }

  override fun onBind(intent: Intent?): IBinder? = null
}
