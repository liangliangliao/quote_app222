package com.example.quote_app

import android.app.AlarmManager
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.lang.ref.WeakReference

object ExactAlarmHelper {

    private const val PREFS = "exact_alarm_permission_flow"
    private const val KEY_PENDING = "pending"
    private const val KEY_REQUESTED_AT = "requested_at"
    private const val REQUEST_VALID_MS = 10 * 60 * 1000L
    @Volatile private var hostActivity: WeakReference<Activity>? = null

    @JvmStatic
    fun attachActivity(activity: Activity) {
        hostActivity = WeakReference(activity)
    }

    @JvmStatic
    fun detachActivity(activity: Activity) {
        if (hostActivity?.get() === activity) hostActivity = null
    }

    @JvmStatic
    fun hasExactAlarmPermission(ctx: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.canScheduleExactAlarms()
        } else {
            // Android 12 以下无需该权限，视为已允许
            true
        }
    }

    @JvmStatic
    fun requestExactAlarmPermission(ctx: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (hasExactAlarmPermission(ctx)) return true
            try {
                ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean(KEY_PENDING, true)
                    .putLong(KEY_REQUESTED_AT, System.currentTimeMillis())
                    .apply()
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:${ctx.packageName}")
                    // The settings page is only a transient permission step.  When the
                    // permission-state broadcast arrives we bring MainActivity forward;
                    // NO_HISTORY then removes this page from the task automatically.
                    addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
                    addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                }
                val activity = hostActivity?.get()
                if (activity != null && !activity.isFinishing &&
                    (Build.VERSION.SDK_INT < Build.VERSION_CODES.JELLY_BEAN_MR1 || !activity.isDestroyed)) {
                    activity.startActivity(intent)
                } else {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    ctx.startActivity(intent)
                }
                true
            } catch (_: Throwable) {
                clearPendingRequest(ctx)
                false
            }
        } else {
            true
        }
    }

    /**
     * Called for ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED.
     *
     * Android sends this foreground broadcast when access is granted.  Only a
     * permission page opened by an explicit in-app action is allowed to bring the
     * app back; boot/time-change rescheduling must never surface UI by itself.
     */
    @JvmStatic
    fun returnToAppAfterGrantIfPending(ctx: Context): Boolean {
        if (!hasExactAlarmPermission(ctx)) return false
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = prefs.getBoolean(KEY_PENDING, false)
        val requestedAt = prefs.getLong(KEY_REQUESTED_AT, 0L)
        clearPendingRequest(ctx)
        if (!pending || requestedAt <= 0L ||
            System.currentTimeMillis() - requestedAt > REQUEST_VALID_MS) {
            return false
        }
        return try {
            val launch = Intent(ctx, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("exact_alarm_permission_granted", true)
            }
            ctx.startActivity(launch)
            true
        } catch (_: Throwable) {
            false
        }
    }

    @JvmStatic
    fun clearPendingRequest(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_PENDING)
            .remove(KEY_REQUESTED_AT)
            .apply()
    }
}
