package com.example.quote_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat

object BehaviorPresetAlarmSettings {
  private const val PREFS = "behavior_preset_alarm_settings"
  private const val KEY_SOUND_URI = "sound_uri"
  private const val KEY_SOUND_TITLE = "sound_title"
  private const val KEY_VOLUME = "volume"
  private const val KEY_VIBRATE = "vibrate"

  @JvmStatic
  fun prefs(ctx: Context) = ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

  @JvmStatic
  fun defaultSoundUri(ctx: Context): String {
    return try {
      val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
      uri?.toString() ?: ""
    } catch (_: Throwable) { "" }
  }

  @JvmStatic
  fun getSoundUri(ctx: Context): String {
    val p = prefs(ctx)
    val saved = p.getString(KEY_SOUND_URI, null)
    return if (!saved.isNullOrBlank()) saved else defaultSoundUri(ctx)
  }

  @JvmStatic
  fun getSoundTitle(ctx: Context): String {
    val p = prefs(ctx)
    val saved = p.getString(KEY_SOUND_TITLE, null)
    if (!saved.isNullOrBlank()) return saved
    return titleForUri(ctx, getSoundUri(ctx)).ifBlank { "系统默认闹钟铃声" }
  }

  @JvmStatic
  fun getVolume(ctx: Context): Float {
    return prefs(ctx).getFloat(KEY_VOLUME, 1.0f).coerceIn(0.0f, 1.0f)
  }

  @JvmStatic
  fun isVibrateEnabled(ctx: Context): Boolean {
    return prefs(ctx).getBoolean(KEY_VIBRATE, true)
  }

  @JvmStatic
  fun set(ctx: Context, soundUri: String?, soundTitle: String?, volume: Float?, vibrate: Boolean?) {
    val editor = prefs(ctx).edit()
    if (soundUri != null) editor.putString(KEY_SOUND_URI, soundUri)
    if (soundTitle != null) editor.putString(KEY_SOUND_TITLE, soundTitle)
    if (volume != null) editor.putFloat(KEY_VOLUME, volume.coerceIn(0.0f, 1.0f))
    if (vibrate != null) editor.putBoolean(KEY_VIBRATE, vibrate)
    editor.apply()
  }

  @JvmStatic
  fun asMap(ctx: Context): HashMap<String, Any?> {
    return hashMapOf(
      "soundUri" to getSoundUri(ctx),
      "soundTitle" to getSoundTitle(ctx),
      "volume" to getVolume(ctx).toDouble(),
      "vibrate" to isVibrateEnabled(ctx),
      "hasAudioReadPermission" to hasAudioReadPermission(ctx)
    )
  }

  @JvmStatic
  fun titleForUri(ctx: Context, uriText: String?): String {
    if (uriText.isNullOrBlank()) return "系统默认闹钟铃声"
    return try {
      val ringtone = RingtoneManager.getRingtone(ctx.applicationContext, Uri.parse(uriText))
      ringtone?.getTitle(ctx.applicationContext) ?: "系统默认闹钟铃声"
    } catch (_: Throwable) { "系统默认闹钟铃声" }
  }

  @JvmStatic
  fun hasAudioReadPermission(ctx: Context): Boolean {
    return try {
      when {
        Build.VERSION.SDK_INT >= 33 -> ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_MEDIA_AUDIO) == PackageManager.PERMISSION_GRANTED
        Build.VERSION.SDK_INT >= 23 -> ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        else -> true
      }
    } catch (_: Throwable) { true }
  }

  @JvmStatic
  fun soundCandidates(ctx: Context, configuredText: String?, payloadText: String?): List<Uri> {
    val out = ArrayList<Uri>()
    fun add(uri: Uri?) {
      if (uri == null) return
      if (out.none { it.toString() == uri.toString() }) out.add(uri)
    }
    fun addExpanded(text: String?) {
      if (text.isNullOrBlank()) return
      val uri = try { Uri.parse(text) } catch (_: Throwable) { null } ?: return
      // When the picker returns the symbolic "default alarm" URI, expand it to the actual current ringtone first.
      // This avoids playing a generic fallback when the provider cannot stream content://settings/system/alarm_alert.
      val uriText = uri.toString()
      try {
        if (uriText == Settings.System.DEFAULT_ALARM_ALERT_URI.toString()) {
          add(RingtoneManager.getActualDefaultRingtoneUri(ctx, RingtoneManager.TYPE_ALARM))
        } else if (uriText == Settings.System.DEFAULT_RINGTONE_URI.toString()) {
          add(RingtoneManager.getActualDefaultRingtoneUri(ctx, RingtoneManager.TYPE_RINGTONE))
        } else if (uriText == Settings.System.DEFAULT_NOTIFICATION_URI.toString()) {
          add(RingtoneManager.getActualDefaultRingtoneUri(ctx, RingtoneManager.TYPE_NOTIFICATION))
        }
      } catch (_: Throwable) {}
      add(uri)
    }

    addExpanded(configuredText)
    addExpanded(payloadText)
    try { add(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)) } catch (_: Throwable) {}
    try { add(RingtoneManager.getActualDefaultRingtoneUri(ctx, RingtoneManager.TYPE_ALARM)) } catch (_: Throwable) {}
    try { add(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)) } catch (_: Throwable) {}
    try { add(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)) } catch (_: Throwable) {}
    return out
  }
}
