
package com.example.quote_app.compat;

import android.content.Context;
import androidx.work.WorkManager;

public final class WmCancelCompat {
    private WmCancelCompat() {}
    public static void cancelBoth(Context ctx, String uid) {
        WorkManager wm = WorkManager.getInstance(ctx);
        try { wm.cancelUniqueWork("wm-main-" + uid); } catch (Throwable ignore) {}
        try { wm.cancelUniqueWork("wm-fallback-" + uid); } catch (Throwable ignore) {}
        try { wm.cancelAllWorkByTag(uid); } catch (Throwable ignore) {}
    }
}
