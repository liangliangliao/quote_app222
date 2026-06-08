package com.example.quote_app

import android.content.Context

/**
 * Shared one-shot gate for the behavior preset alarm UI.
 *
 * Alarm delivery can arrive through several legal Android paths (AlarmClock receiver, foreground-service
 * notification, notification tap, legacy receiver).  Without a process/prefs gate, foreground devices may open the
 * same form multiple times.  The gate is deliberately persisted so it also deduplicates quick process restarts.
 */
object BehaviorPresetAlarmUiGate {
  private const val PREF = "behavior_preset_alarm_ui_gate_v40"
  private const val KEY_LAST_UI_KEY = "last_ui_key"
  private const val KEY_LAST_UI_MS = "last_ui_ms"
  private const val KEY_VISIBLE_KEY = "visible_key"
  private const val KEY_VISIBLE_MS = "visible_ms"
  private const val WINDOW_MS = 90_000L

  private fun prefs(ctx: Context) = ctx.applicationContext.getSharedPreferences(PREF, Context.MODE_PRIVATE)

  @JvmStatic
  fun keyFor(payload: String?): String {
    val k = try { BehaviorPresetAlarmScheduler.fireKey(payload) } catch (_: Throwable) { "" }
    if (k.isNotBlank()) return k
    return try {
      val obj = org.json.JSONObject(payload ?: "{}")
      val id = obj.optInt("alarmId", 0)
      if (id != 0) "id:$id" else "raw:${(payload ?: "{}").hashCode()}"
    } catch (_: Throwable) { "raw:${(payload ?: "{}").hashCode()}" }
  }

  @JvmStatic
  fun isRecentlyShown(ctx: Context, payload: String?, windowMs: Long = WINDOW_MS): Boolean {
    return try {
      val key = keyFor(payload)
      val p = prefs(ctx)
      val now = System.currentTimeMillis()
      val lastKey = p.getString(KEY_LAST_UI_KEY, "") ?: ""
      val lastMs = p.getLong(KEY_LAST_UI_MS, 0L)
      val visibleKey = p.getString(KEY_VISIBLE_KEY, "") ?: ""
      val visibleMs = p.getLong(KEY_VISIBLE_MS, 0L)
      val lastDelta = now - lastMs
      val visibleDelta = now - visibleMs
      (key == lastKey && lastDelta >= 0L && lastDelta <= windowMs) ||
        (key == visibleKey && visibleDelta >= 0L && visibleDelta <= 10 * 60 * 1000L)
    } catch (_: Throwable) { false }
  }

  @JvmStatic
  fun claimUi(ctx: Context, payload: String?, windowMs: Long = WINDOW_MS): Boolean {
    return try {
      if (isRecentlyShown(ctx, payload, windowMs)) return false
      val key = keyFor(payload)
      prefs(ctx).edit()
        .putString(KEY_LAST_UI_KEY, key)
        .putLong(KEY_LAST_UI_MS, System.currentTimeMillis())
        .apply()
      true
    } catch (_: Throwable) { true }
  }

  @JvmStatic
  fun markVisible(ctx: Context, payload: String?) {
    try {
      prefs(ctx).edit()
        .putString(KEY_VISIBLE_KEY, keyFor(payload))
        .putLong(KEY_VISIBLE_MS, System.currentTimeMillis())
        .apply()
    } catch (_: Throwable) {}
  }

  @JvmStatic
  fun clearVisible(ctx: Context, payload: String?) {
    try {
      val key = keyFor(payload)
      val p = prefs(ctx)
      if ((p.getString(KEY_VISIBLE_KEY, "") ?: "") == key) {
        p.edit().remove(KEY_VISIBLE_KEY).remove(KEY_VISIBLE_MS).apply()
      }
    } catch (_: Throwable) {}
  }
}
