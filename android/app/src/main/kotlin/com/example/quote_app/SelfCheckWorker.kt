package com.example.quote_app

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

class SelfCheckWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
  override fun doWork(): Result = Result.success()
}