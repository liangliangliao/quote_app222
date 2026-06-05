package com.example.quote_app.wm;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.work.Data;
import androidx.work.ListenableWorker;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import com.example.quote_app.biz.Biz;
import com.example.quote_app.data.DbRepository;
import com.example.quote_app.schedule.AutoRescheduler;
import com.example.quote_app.wm.WmNames;

public final class NormalWorker extends Worker {
    private static final String TAG_LOG = "NormalWorker";

    public NormalWorker(@NonNull Context context, @NonNull WorkerParameters params) {
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
        String chan = in.getString("chan");
        int attempt = in.getInt("attempt", 1);

        try {
            // 记录触发日志
            DbRepository.log(ctx, uid, "【原生】WM 正常通道触发 uid="+uid+" run="+runKey+" attempt="+attempt);
            boolean ok = Biz.run(ctx, uid);
            if (ok) {
                // 通知成功：记录成功并取消兜底任务及当前 WM 任务，然后安排下一次
                DbRepository.markLatestSuccess(ctx, uid);
                try { android.util.Log.d(TAG_LOG, "before rotateCursorByTaskType");
        DbRepository.rotateCursorByTaskType(ctx, uid); } catch (Throwable ignore) {}
                try { android.util.Log.d(TAG_LOG, "before updateQuoteNotify");
        DbRepository.updateQuoteNotify(ctx, uid, true, System.currentTimeMillis());
                try { DbRepository.log(ctx, uid, "【DB】(WM Normal) cursor+1 & quote updated(success)"); } catch (Throwable ignore) {} } catch (Throwable ignore) {}
                // Cancel fallback by unique id to prevent a later duplicate notification
                try {
                    String fbUnique = WmNames.fbUnique(uid, runKey);
                    WmScheduler.cancelFallback(ctx, fbUnique);
                } catch (Throwable ignore) {}
                // Cancel current normal WM unique work. WorkManager will otherwise keep the work alive
                try {
                    String normUnique = WmNames.normUnique(uid, runKey);
                    WmScheduler.cancelByUnique(ctx, normUnique);
                try { WmScheduler.cancelKick(ctx, uid, runKey);
                try { DbRepository.log(ctx, uid, "【原生】KICK 取消(by WM) uid="+uid+" run="+runKey); } catch (Throwable ignore) {} } catch (Throwable ignore) {}
                } catch (Throwable ignore) {}
                // 调用自动续排：根据 uid 计算下一次时间，并注册 AM + fallback 或 WM
                AutoRescheduler.scheduleNext(ctx, uid);
                // 返回成功，不再重试
                return Result.success();
            } else {
                // 通知失败：取消当前 main-wm 任务并安排下一次（兜底不取消）
                DbRepository.log(ctx, uid, "【原生】WM 正常通道发送失败 uid=" + uid + " run=" + runKey);
                try {
                    // Cancel current unique work to avoid duplicate retries
                    String normUnique = WmNames.normUnique(uid, runKey);
                    WmScheduler.cancelByUnique(ctx, normUnique);
                try { WmScheduler.cancelKick(ctx, uid, runKey);
                try { DbRepository.log(ctx, uid, "【原生】KICK 取消(by WM) uid="+uid+" run="+runKey); } catch (Throwable ignore) {} } catch (Throwable ignore) {}
                } catch (Throwable ignore) {}
                AutoRescheduler.scheduleNext(ctx, uid);
                // 表示工作已完成，让 WorkManager 不再重试；兜底保留
                return Result.success();
            }
        } catch (Throwable t) {
            DbRepository.log(ctx, uid, "WM正常通道异常: " + (t.getMessage()==null?"未知错误":t.getMessage()));
            // 异常情况下尝试安排下一次任务，避免任务丢失
            try { AutoRescheduler.scheduleNext(ctx, uid); } catch (Throwable ignore) {}
            return Result.retry();
        }
    }
}
