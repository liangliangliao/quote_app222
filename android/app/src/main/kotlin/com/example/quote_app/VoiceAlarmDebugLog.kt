package com.example.quote_app

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object VoiceAlarmDebugLog {
  private const val TAG = "VoiceAlarmDebug"
  private const val MAX_FILE_BYTES = 2L * 1024L * 1024L
  private val dayFormat = SimpleDateFormat("yyyyMMdd", Locale.US)
  private val timeFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

  @Synchronized
  fun write(context: Context?, event: String, detail: String = "", data: Map<String, Any?> = emptyMap()) {
    val safeEvent = event.take(80)
    val safeDetail = detail.take(1200)
    val line = buildString {
      append(timeFormat.format(Date()))
      append(" | ").append(safeEvent)
      if (safeDetail.isNotBlank()) append(" | ").append(safeDetail.replace('\n', ' '))
      if (data.isNotEmpty()) {
        append(" | ")
        append(JSONObject().apply {
          for ((key, value) in data) put(key, sanitizeValue(key, value))
        }.toString())
      }
    }
    try { Log.d(TAG, line) } catch (_: Throwable) {}
    val ctx = context ?: return
    try {
      val dir = (ctx.getExternalFilesDir("voice_alarm_logs") ?: File(ctx.filesDir, "voice_alarm_logs")).apply { mkdirs() }
      val file = File(dir, "voice_alarm_${dayFormat.format(Date())}.log")
      if (file.exists() && file.length() > MAX_FILE_BYTES) {
        val backup = File(dir, "voice_alarm_${dayFormat.format(Date())}_${System.currentTimeMillis()}.old.log")
        try { file.renameTo(backup) } catch (_: Throwable) {}
      }
      file.appendText(line + "\n", Charsets.UTF_8)
    } catch (_: Throwable) {}
  }


  @Synchronized
  fun clear(context: Context?): Int {
    val ctx = context ?: return 0
    return try {
      val dir = (ctx.getExternalFilesDir("voice_alarm_logs") ?: File(ctx.filesDir, "voice_alarm_logs")).apply { mkdirs() }
      var deleted = 0
      dir.listFiles()?.forEach { file ->
        if (file.isFile && file.name.startsWith("voice_alarm_") && file.delete()) deleted += 1
      }
      // 调试音频也属于语音闹钟排障资料；用户点击“清空日志”时一并清理，避免隐私音频长期残留。
      val audioDir = (ctx.getExternalFilesDir("voice_alarm_audio_debug") ?: File(ctx.filesDir, "voice_alarm_audio_debug")).apply { mkdirs() }
      audioDir.listFiles()?.forEach { file ->
        if (file.isFile && (file.name.endsWith(".wav") || file.name.endsWith(".pcm")) && file.delete()) deleted += 1
      }
      try { Log.d(TAG, "debugLog.clear | cleared $deleted voice alarm debug files") } catch (_: Throwable) {}
      deleted
    } catch (_: Throwable) { 0 }
  }

  fun latestLogPath(context: Context?): String {
    return latestLogFile(context)?.absolutePath ?: ""
  }

  fun logDirectoryPath(context: Context?): String {
    val ctx = context ?: return ""
    return try {
      (ctx.getExternalFilesDir("voice_alarm_logs") ?: File(ctx.filesDir, "voice_alarm_logs")).apply { mkdirs() }.absolutePath
    } catch (_: Throwable) { "" }
  }

  fun latestLogText(context: Context?, maxBytes: Int = 64 * 1024): String {
    val file = latestLogFile(context) ?: return ""
    return try {
      if (!file.exists()) return ""
      val bytes = file.readBytes()
      val start = (bytes.size - maxBytes.coerceAtLeast(4096)).coerceAtLeast(0)
      String(bytes, start, bytes.size - start, Charsets.UTF_8)
    } catch (t: Throwable) {
      "读取日志失败：${t.message ?: t.javaClass.simpleName}"
    }
  }

  private fun latestLogFile(context: Context?): File? {
    val ctx = context ?: return null
    return try {
      val dir = (ctx.getExternalFilesDir("voice_alarm_logs") ?: File(ctx.filesDir, "voice_alarm_logs")).apply { mkdirs() }
      File(dir, "voice_alarm_${dayFormat.format(Date())}.log")
    } catch (_: Throwable) { null }
  }

  private fun sanitizeValue(key: String, value: Any?): Any {
    val lower = key.lowercase(Locale.US)
    if (lower.contains("key") || lower.contains("secret") || lower.contains("token") || lower.contains("authorization")) {
      val s = value?.toString().orEmpty()
      return if (s.isBlank()) "" else "***${s.takeLast(4)}"
    }
    val text = value?.toString() ?: "null"
    return if (text.length > 600) text.take(600) + "…" else text
  }
}
