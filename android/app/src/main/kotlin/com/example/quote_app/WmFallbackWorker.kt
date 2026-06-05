package com.example.quote_app

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class WmFallbackWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
  override suspend fun doWork(): Result {
    // 兜底占位，实际逻辑集中在 NotifyWorker
    return Result.success()
  }
}