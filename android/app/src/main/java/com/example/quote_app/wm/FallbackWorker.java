package com.example.quote_app.wm;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.work.Data;
import androidx.work.ListenableWorker;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import com.example.quote_app.biz.Biz;
import com.example.quote_app.data.DbRepository;
import com.example.quote_app.schedule.AutoRescheduler;
import com.example.quote_app.wm.WmNames;
import com.example.quote_app.compat.DartParity;
import com.example.quote_app.NativeSchedulerK;

import java.util.concurrent.TimeUnit;

public final class FallbackWorker extends Worker {

    public FallbackWorker(@NonNull Context context, @NonNull WorkerParameters params) {
        super(context, params);
    }

    @NonNull
    @Override public ListenableWorker.Result doWork() {
        Context ctx = getApplicationContext();
        Data in = getInputData();
        // Extract uid/runKey from either legacy or new keys. Dart side may provide
        // 'task_uid' and 'run_key' whereas native side uses 'uid' and 'runKey'.
        String uid = in.getString("uid");
        if (uid == null || uid.isEmpty()) uid = in.getString("task_uid");
        String runKey = in.getString("runKey");
        if (runKey == null || runKey.isEmpty()) runKey = in.getString("run_key");
        int attempt = in.getInt("attempt", 1);

        try {
            DbRepository.log(ctx, uid, "【原生】fallback-wm 触发 uid="+uid+" run="+runKey+" attempt="+attempt);
            boolean ok = Biz.run(ctx, uid);
            if (ok) {
                // 成功：取消当前兜底任务，不再安排下一次
                DbRepository.markLatestSuccess(ctx, uid);
try { DbRepository.updateQuoteNotify(ctx, uid, true, System.currentTimeMillis());
                    try { DbRepository.log(ctx, uid, "【DB】(WM FB) cursor+1 & quote updated(success)"); } catch (Throwable ignore) {} } catch (Throwable ignore) {}
                // Cancel current fallback unique work
                try {
                    String fbUnique = WmNames.fbUnique(uid, runKey);
                    WmScheduler.cancelFallback(ctx, fbUnique);
                    try { WmScheduler.cancelKick(ctx, uid, runKey);
                    try { DbRepository.log(ctx, uid, "【原生】KICK 取消(by Fallback) uid="+uid+" run="+runKey); } catch (Throwable ignore) {} } catch (Throwable ignore) {}
                } catch (Throwable ignore) {}
                // 取消可能遗留的 AM 任务以防重复触发
                try {
                    int alarmId = DartParity.alarmId(uid, runKey);
                    NativeSchedulerK.cancel(ctx, alarmId);
                } catch (Throwable ignore) {}
                // 不调用自动续排；下次任务将由主通道负责安排
                return Result.success();
            } else {
                // 失败：重试一次立刻执行的兜底；超过 2 次则放弃
                DbRepository.log(ctx, uid, "【原生】fallback-wm 发送失败 uid="+uid+" run="+runKey+" attempt="+attempt);
                if (attempt < 2) {
                    Data in2 = new Data.Builder()
                            // Include both new and legacy keys for uid/runKey
                            .putString("uid", uid)
                            .putString("runKey", runKey)
                            .putString("task_uid", uid)
                            .putString("run_key", runKey)
                            .putString("chan", "fallback-wm")
                            .putInt("attempt", attempt + 1)
                            .build();
                    OneTimeWorkRequest req = new OneTimeWorkRequest.Builder(FallbackWorker.class)
                            .setInitialDelay(0, TimeUnit.MILLISECONDS)
                            .addTag("fallback-wm-retry")
                            .setInputData(in2)
                            .build();
                    // use new unique id to replace
                    WorkManager.getInstance(ctx)
                            .enqueueUniqueWork(WmNames.fbUnique(uid, runKey),
                                    androidx.work.ExistingWorkPolicy.REPLACE, req);
                    return Result.success();
                } else {
                    DbRepository.log(ctx, uid, "兜底失败达到2次，停止兜底");
                    // Cancel current fallback
                    try {
                        String fbUnique = WmNames.fbUnique(uid, runKey);
                        WmScheduler.cancelFallback(ctx, fbUnique);
                    try { WmScheduler.cancelKick(ctx, uid, runKey);
                    try { DbRepository.log(ctx, uid, "【原生】KICK 取消(by Fallback) uid="+uid+" run="+runKey); } catch (Throwable ignore) {} } catch (Throwable ignore) {}
                    } catch (Throwable ignore) {}
                    // 取消可能遗留的 AM 任务以防重复触发
                    try {
                        int alarmId = DartParity.alarmId(uid, runKey);
                        NativeSchedulerK.cancel(ctx, alarmId);
                    } catch (Throwable ignore) {}
                    // 不再重试，也不安排下一次，交由主通道自动续排
try { DbRepository.updateQuoteNotify(ctx, uid, false, System.currentTimeMillis());
                    try { DbRepository.log(ctx, uid, "【DB】(WM FB) cursor+1 & quote updated(fail)"); } catch (Throwable ignore) {} } catch (Throwable ignore) {}
                    return Result.failure();
                }
            }
        } catch (Throwable t) {
            DbRepository.log(ctx, uid, "WM兜底异常: " + t.getMessage());
            return Result.retry();
        }
    }
}
