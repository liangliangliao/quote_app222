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
    val path = uri?.path?.trimEnd('/').orEmpty()
    val azure = cfg.optString("provider").lowercase() in setOf("azure", "foundry", "msfoundry") &&
      listOf(".openai.azure.com", ".services.ai.azure.com", ".cognitiveservices.azure.com", ".ai.azure.com").any { host.endsWith(it) }
    val native = when {
      azure -> "web_search"
      cfg.optString("provider").lowercase() in setOf("xgrok", "xai", "grok") && host == "api.x.ai" -> "web_search"
      cfg.optString("provider") == "openai" && host == "api.openai.com" -> "web_search"
      cfg.optString("provider") == "openrouter" && host == "openrouter.ai" -> "openrouter:web_search"
      else -> null
    }
    val responses = path.endsWith("/responses")
    val supported = native != null && uri?.scheme == "https" && uri.userInfo == null &&
      (responses || path.endsWith("/chat/completions"))
    val search = enabled && supported
    val targetPath = when {
      !search -> path
      azure && !path.contains("/api/projects/") -> "/openai/v1/responses"
      responses -> path
      else -> path.removeSuffix("/chat/completions") + "/responses"
    }
    // Legacy Azure deployment/inference routes use api-version; v1 uses deployment in model.
    val query = if (search && azure) uri?.rawQuery?.split('&')?.filterNot { it.substringBefore('=').equals("api-version", true) }?.joinToString("&")?.ifEmpty { null } else uri?.rawQuery
    val target = if (search) URI(uri!!.scheme, null, uri.host, uri.port, targetPath, query, null).toString() else endpoint
    val body = JSONObject().put("model", cfg.optString("model"))
      .put(if (responses || search) "input" else "messages", messages).put("stream", false)
    val connection = cfg.optString("bingConnectionId").trim()
    var error: String? = null
    if (search) {
      val tool = JSONObject().put("type", native)
      if (azure && connection.isNotEmpty()) {
        if (!path.contains("/api/projects/")) error = "Bing Grounding 需要 Foundry 项目 Responses 地址及有效 Entra 鉴权，不能用于资源级部署地址。"
        tool.put("type", "bing_grounding").put("bing_grounding", JSONObject().put("search_configurations",
          JSONArray().put(JSONObject().put("project_connection_id", connection))))
      }
      body.put("tools", JSONArray().put(tool))
    }
    if (responses || search) body.put("store", false)
    else if (cfg.optBoolean("allowSamplingParams", true)) body.put("temperature", 0.7)
    if (!enabled && path.endsWith("/messages")) {
      val chat = JSONArray(); val system = mutableListOf<String>()
      for (i in 0 until messages.length()) messages.optJSONObject(i)?.let {
        if (it.optString("role") == "system") system.add(it.optString("content")) else chat.put(it)
      }
      body.remove("input"); body.remove("store")
      body.put("messages", chat).put("system", system.joinToString("\n")).put("max_tokens", 2048)
    }
    if (enabled && !supported) error = "当前地址尚未接入联网工具。支持 Azure/Foundry Responses、官方 OpenAI、xAI、OpenRouter；需部署本身支持搜索。可关闭联网使用普通对话。"

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
      if (item.optString("type") in setOf("web_search_call", "bing_grounding_call") && item.optString("status") == "completed") return true
    }
    return false
  }
}
