package com.example.quote_app

import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.URI
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/** No credentials, response bodies or private text are included in error messages. */
data class WakeupAccess(val baseUrl: String, val deviceToken: String, val serviceToken: String)
data class WakeupContent(val date: String, val text: String, val id: String,
  val title: String = "今日播报", val scheduledTime: String = "")
data class WakeupDay(val date: String, val tasks: List<WakeupContent>, val reminder: WakeupContent?) {
  val historyItems get() = tasks.ifEmpty { listOfNotNull(reminder) }
}

object VoiceAlarmWakeupClient {
  const val DEFAULT_URL = "https://ai-wakeup-personal-lab.fond-beech-0136.chatgpt.site"
  private val client = OkHttpClient.Builder().followRedirects(false).followSslRedirects(false)
    .connectTimeout(2, TimeUnit.SECONDS).readTimeout(3, TimeUnit.SECONDS)
    .callTimeout(5, TimeUnit.SECONDS).build()

  fun beijingDate(now: Date = Date()): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
    timeZone = TimeZone.getTimeZone("Asia/Shanghai")
  }.format(now)

  fun normalizeBaseUrl(value: String): String {
    val uri = try { URI(value.trim()) } catch (_: Exception) { throw IllegalArgumentException("请输入有效的 HTTPS 站点地址") }
    require(uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.rawUserInfo == null && uri.rawQuery == null && uri.rawFragment == null && (uri.path.isNullOrEmpty() || uri.path == "/")) { "站点地址须为 HTTPS 根地址，不能包含账号、路径或查询参数" }
    return uri.toASCIIString().trimEnd('/')
  }

  fun parseToday(raw: String, expectedDate: String): WakeupContent {
    return parseDay(raw, expectedDate).reminder ?: throw IllegalStateException("今日提醒尚未生成")
  }

  fun parseDay(raw: String, expectedDate: String): WakeupDay {
    val root = JSONObject(raw)
    require(root.optJSONObject("settings")?.opt("demoMode") == false) { "站点正式模式未启用，使用原闹钟内容" }
    require(root.optString("date") == expectedDate && root.optBoolean("shouldRing", false)) { "今日提醒尚未就绪或站点闹钟未启用" }
    val messages = root.optJSONArray("scheduledMessages")
    val tasks = (0 until (messages?.length() ?: 0)).mapNotNull { index ->
      val item = messages?.optJSONObject(index) ?: return@mapNotNull null
      if (item.optString("date") != expectedDate || item.opt("isDemo") != false) return@mapNotNull null
      val id = item.optString("id")
      val text = item.opt("text") as? String ?: return@mapNotNull null
      if (id.isBlank() || text.isBlank() || text.length > 16000) return@mapNotNull null
      WakeupContent(expectedDate, text, id, item.optString("task_title").ifBlank { "同步任务" }, item.optString("scheduled_time"))
    }.distinctBy { it.id }.sortedBy { it.scheduledTime.ifBlank { "99:99" } }
    val reminder = root.optJSONObject("content")?.let { item ->
      val text = item.opt("body") as? String
      if (item.optString("date") == expectedDate && item.optString("source") != "synthetic" && item.opt("isDemo") == false &&
          !text.isNullOrBlank() && text.length <= 16000) {
        WakeupContent(expectedDate, text, item.optString("id"), item.optString("title").ifBlank { "今日播报" })
      } else null
    }
    return WakeupDay(expectedDate, tasks, reminder)
  }

  fun fetch(access: WakeupAccess, date: String = beijingDate(), transport: OkHttpClient = client): WakeupContent {
    return fetchDay(access, date, transport).reminder ?: throw IllegalStateException("今日提醒尚未生成")
  }

  fun fetchDay(access: WakeupAccess, date: String = beijingDate(), transport: OkHttpClient = client): WakeupDay {
    val base = normalizeBaseUrl(access.baseUrl)
    require(access.deviceToken.isNotBlank()) { "请配置设备访问令牌" }
    require(!access.deviceToken.contains('\n') && !access.deviceToken.contains('\r') && !access.serviceToken.contains('\n') && !access.serviceToken.contains('\r')) { "访问凭据格式无效" }
    val request = Request.Builder().url("$base/api/alarm/today")
      .header("Accept", "application/json")
      .header("Cache-Control", "no-store")
      .header("Authorization", "Bearer ${access.deviceToken}")
      .apply { if (access.serviceToken.isNotBlank()) header("OAI-Sites-Authorization", "Bearer ${access.serviceToken}") }.build()
    // Redirects must never forward credentials to a sign-in page or another origin.
    val safeTransport = transport.newBuilder().followRedirects(false).followSslRedirects(false).build()
    safeTransport.newCall(request).execute().use { response ->
      require(response.code in 200..299) { "AI Wakeup 连接失败（HTTP ${response.code}），使用原闹钟内容" }
      require(response.header("Content-Type", "").orEmpty().substringBefore(';').trim().equals("application/json", true)) { "站点返回登录页或非 JSON 内容，请检查私有站点服务凭据" }
      val body = response.body ?: throw IllegalStateException("站点返回空响应")
      val out = ByteArrayOutputStream()
      body.byteStream().use { input ->
        val buffer = ByteArray(4096)
        while (true) { val n = input.read(buffer); if (n < 0) break; require(out.size() + n <= 65536) { "站点响应超出限制" }; out.write(buffer, 0, n) }
      }
      return parseDay(out.toString("UTF-8"), date)
    }
  }
}
