package com.example.quote_app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class BehaviorPresetRingtonePickActivity : Activity() {
  companion object {
    private const val REQ_PICK = 51042
    private const val REQ_AUDIO_PERMISSION = 51043
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    if (!hasAudioReadPermission()) {
      requestAudioReadPermission()
    } else {
      openPicker()
    }
  }

  private fun hasAudioReadPermission(): Boolean {
    return try {
      when {
        Build.VERSION.SDK_INT >= 33 -> ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO) == PackageManager.PERMISSION_GRANTED
        Build.VERSION.SDK_INT >= 23 -> ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        else -> true
      }
    } catch (_: Throwable) { true }
  }

  private fun requestAudioReadPermission() {
    try {
      val perm = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE
      ActivityCompat.requestPermissions(this, arrayOf(perm), REQ_AUDIO_PERMISSION)
    } catch (_: Throwable) {
      // Some ringtone providers grant their own read access even without media-library permission.  Still let the
      // user choose a sound instead of blocking the flow completely.
      openPicker()
    }
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    if (requestCode == REQ_AUDIO_PERMISSION) {
      if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
        openPicker()
      } else {
        Toast.makeText(this, "未授予音频读取权限，部分自定义 MP3 可能无法响铃，将尝试系统铃声通道", Toast.LENGTH_LONG).show()
        openPicker()
      }
    }
  }

  private fun openPicker() {
    try {
      val current = BehaviorPresetAlarmSettings.getSoundUri(this).takeIf { it.isNotBlank() }?.let { Uri.parse(it) }
      val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
        putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "选择预设行为闹钟铃声")
        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
        putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, current)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        if (Build.VERSION.SDK_INT >= 19) addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
      }
      startActivityForResult(intent, REQ_PICK)
    } catch (t: Throwable) {
      Toast.makeText(this, "无法打开系统铃声选择器", Toast.LENGTH_SHORT).show()
      finish()
    }
  }

  @Deprecated("Deprecated in Android framework; suitable for this small picker proxy activity.")
  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    if (requestCode == REQ_PICK && resultCode == RESULT_OK) {
      val uri: Uri? = if (Build.VERSION.SDK_INT >= 33) {
        data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
      } else {
        @Suppress("DEPRECATION")
        data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
      }
      if (uri != null) {
        try {
          val flags = (data?.flags ?: 0) and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
          if (Build.VERSION.SDK_INT >= 19 && flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0) {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
          }
        } catch (_: Throwable) {}
        val title = BehaviorPresetAlarmSettings.titleForUri(this, uri.toString())
        BehaviorPresetAlarmSettings.set(this, uri.toString(), title, null, null)
        Toast.makeText(this, "已选择：$title", Toast.LENGTH_SHORT).show()
      }
    }
    finish()
  }
}
