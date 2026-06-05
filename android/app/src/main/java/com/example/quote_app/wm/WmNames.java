package com.example.quote_app.wm;

import com.example.quote_app.compat.DartParity;

public final class WmNames {
    private WmNames() {}

    /**
     * Generate a unique identifier for a normal WorkManager task. The new format embeds
     * channel (main-wm), runKey and uid for clarity. Example: src=main-wm_runkey=2025-10-01 10:30:50_uid=task123.
     */
    public static String normUnique(String uid, String runKey) {
        String rk = (runKey == null ? "" : runKey);
        return "src=main-wm_runkey=" + rk + "_uid=" + uid;
    }

    /**
     * Generate a unique identifier for a fallback WorkManager task. The new format embeds
     * channel (fallback-wm), runKey and uid. Attempt suffix may be appended by the caller if needed.
     */
    public static String fbUnique(String uid, String runKey) {
        String rk = (runKey == null ? "" : runKey);
        return "src=fallback-wm_runkey=" + rk + "_uid=" + uid;
    }
}
