package com.example.quote_app

import java.net.URI
import org.json.JSONArray
import org.json.JSONObject

/** Native search tools; never move a user's credentials to a different origin. */
object VoiceAlarmWebSearch {
  data class Plan(val endpoint: String, val body: JSONObject, val enabled: Boolean, val error: String? = null)
  fun plan(cfg: JSONObject, messages: JSONArray, enabled: Boolean): Plan {
    val endpoint = cfg.optString("endpoint")
    val uri = try { URI(endpoint) } catch (_: Exception) { null }
    val host = uri?.host?.lowercase().orEmpty()
    val native = when {
      cfg.optString("provider").lowercase() in setOf("xgrok", "xai", "grok") && host == "api.x.ai" -> "web_search"
      cfg.optString("provider") == "openai" && host == "api.openai.com" -> "web_search"
      cfg.optString("provider") == "openrouter" && host == "openrouter.ai" -> "openrouter:web_search"
      else -> null
    }
    val responses = uri?.path?.trimEnd('/')?.endsWith("/responses") == true
    val supported = native != null && uri?.scheme == "https" && (responses || uri.path.trimEnd('/').endsWith("/chat/completions"))
    val search = enabled && supported
    val target = if (search && !responses) URI(uri!!.scheme, uri.userInfo, uri.host, uri.port,
      uri.path.trimEnd('/').removeSuffix("/chat/completions") + "/responses", uri.query, null).toString() else endpoint
    val body = JSONObject().put("model", cfg.optString("model"))
      .put(if (responses || search) "input" else "messages", messages).put("stream", false)
    if (search) body.put("tools", JSONArray().put(JSONObject().put("type", native)))
    if (responses || search) body.put("store", false)
    else if (cfg.optBoolean("allowSamplingParams", true)) body.put("temperature", 0.7)
    val error = if (enabled && !supported) "当前 AI 服务或自定义地址尚未接入联网搜索。请在全局 AI 设置选择官方 OpenAI、xAI 或 OpenRouter 的支持搜索模型，或关闭语音闹钟联网开关后使用普通对话。" else null
    return Plan(target, body, search, error)
  }
  fun sources(response: JSONObject): List<String> {
    val urls = linkedSetOf<String>()
    fun add(raw: String) {
      val uri = try { URI(raw) } catch (_: Exception) { return }
      if (uri.scheme in setOf("http", "https") && !uri.host.isNullOrBlank() && uri.userInfo == null) urls.add(raw)
    }
    fun visit(value: Any?) {
      when (value) {
        is JSONObject -> {
          if (value.optString("type") == "url_citation") {
            add(value.optString("url")); value.optJSONObject("url_citation")?.let { add(it.optString("url")) }
          }
          val citations = value.optJSONArray("citations")
          if (citations != null) for (i in 0 until citations.length()) {
            val citation = citations.opt(i)
            if (citation is String) add(citation) else if (citation is JSONObject) add(citation.optString("url"))
          }
          value.keys().forEach { visit(value.opt(it)) }
        }
        is JSONArray -> for (i in 0 until value.length()) visit(value.opt(i))
      }
    }
    visit(response); return urls.toList()
  }
  fun searched(response: JSONObject): Boolean {
    if (sources(response).isNotEmpty()) return true
    val output = response.optJSONArray("output") ?: return false
    for (i in 0 until output.length()) {
      val item = output.optJSONObject(i) ?: continue
      if (item.optString("type") == "web_search_call" && item.optString("status") == "completed") return true
    }
    return false
  }
}
