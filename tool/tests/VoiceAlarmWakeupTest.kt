package com.example.quote_app

import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.json.JSONObject
import org.json.JSONArray
import java.io.IOException
import java.time.Instant
import java.util.Date

/** All content and credentials below are fictional; no live private service is called. */
fun main() {
  val date = "2026-11-16"
  val text = "  今日测试：自主选择先坐起。\n双脚落地，再喝一口水。  "
  fun fixture(): JSONObject = JSONObject().put("date", date).put("shouldRing", true)
    .put("settings", JSONObject().put("demoMode", false))
    .put("content", JSONObject().put("date", date).put("isDemo", false)
      .put("source", "chatgpt").put("id", "fictional-1").put("body", text))
  var passed = 0
  fun scenario(name: String, body: () -> Unit) { body(); passed++; println("PASS $name") }
  fun rejects(body: () -> Unit): Exception {
    try { body() } catch (e: Exception) { return e }
    error("Expected rejection")
  }
  scenario("Beijing date crosses midnight at 16:00 UTC") {
    check(VoiceAlarmWakeupClient.beijingDate(Date.from(Instant.parse("2026-11-15T15:59:59Z"))) == "2026-11-15")
    check(VoiceAlarmWakeupClient.beijingDate(Date.from(Instant.parse("2026-11-15T16:00:00Z"))) == date)
  }
  scenario("today body is preserved verbatim including whitespace") {
    val content = VoiceAlarmWakeupClient.parseToday(fixture().toString(), date)
    check(content.date == date && content.id == "fictional-1" && content.text == text)
  }
  scenario("task-only response preserves each original and orders by schedule time") {
    fun item(id: String, time: String) = JSONObject().put("id", id).put("date", date).put("scheduled_time", time)
      .put("task_title", "任务 $id").put("text", "$id\n$text").put("isDemo", false)
    val raw = fixture().put("content", JSONObject.NULL).put("scheduledMessages", JSONArray()
      .put(item("two", "07:00")).put(item("old", "05:00").put("date", "2026-11-15"))
      .put(item("one", "06:00")).put(item("demo", "05:00").put("isDemo", true)).put(item("one", "06:00")))
    val parsed = VoiceAlarmWakeupClient.parseDay(raw.toString(), date)
    check(parsed.tasks.map { it.id } == listOf("one", "two"))
    check(parsed.tasks.first().text == "one\n$text" && parsed.historyItems == parsed.tasks && parsed.reminder == null)
  }
  scenario("legacy endpoint and empty day remain available to the existing alarm fallback") {
    check(VoiceAlarmWakeupClient.parseDay(fixture().toString(), date).historyItems.single().text == text)
    val empty = VoiceAlarmWakeupClient.parseDay(fixture().put("content", JSONObject.NULL).toString(), date)
    check(empty.tasks.isEmpty() && empty.historyItems.isEmpty())
  }
  scenario("finish each task once, then generate from completed originals and play late arrivals") {
    val first = WakeupContent(date, "任务一\n正文", "a", "一", "06:00")
    val second = WakeupContent(date, "任务二\n正文", "b", "二", "07:00")
    val late = WakeupContent(date, "后来同步的任务", "c", "三", "07:05")
    val session = VoiceAlarmWakeSession("本地开场", adaptive = false)
    check(session.needsRemote(date, 0))
    val day = WakeupDay(date, listOf(first, second), null)
    session.rememberRemote(date, 0, day)
    check(!session.needsRemote(date, 59000) && session.needsRemote(date, 60000))
    fun begin(expected: WakeupContent) {
      val next = session.remoteForRound(date) ?: error("missing task")
      check(next.task == expected)
      check(session.accept(next.motivation, emptyList(), next.source, next.task).body == expected.text)
    }
    begin(first)
    session.markPlayback("用户插话中断")
    check(!session.shouldFollowUpOnTasks(date))
    begin(first)
    session.markPlayback("完整播报完成", completed = true)
    session.rememberRemote(date, 60000, null, keepOnNetworkError = true)
    begin(second)
    session.markPlayback("完整播报完成", completed = true)
    check(session.remoteForRound(date) == null && session.shouldFollowUpOnTasks(date))
    val preview = session.prepare(emptyList(), null) { messages ->
      val context = JSONObject(messages.getJSONObject(1).getString("content"))
      val originals = context.getJSONArray("completedWakeupTasks")
      check((0 until originals.length()).map { originals.getJSONObject(it).getString("text") } == listOf(first.text, second.text))
      check(context.getJSONArray("previousAttempts").getJSONObject(0).getString("playback") == "用户插话中断")
      "取一个任务里的行动线索，现在就迈出第一步。"
    }
    check(preview.source == "ai" && preview.motivation != first.text)
    session.rememberRemote(date, 120000, day.copy(tasks = day.tasks + late))
    check(!session.shouldFollowUpOnTasks(date))
    begin(late)
    session.markPlayback("完整播报完成", completed = true)
    check(session.shouldFollowUpOnTasks(date))
    session.rememberRemote("2026-11-17", 180000, null, keepOnNetworkError = true)
    check(session.remoteForRound("2026-11-17") == null && !session.shouldFollowUpOnTasks("2026-11-17"))
  }
  scenario("history can import today's task while disabled alarms never play it") {
    val raw = fixture().put("shouldRing", false).put("scheduledMessages", JSONArray().put(
      JSONObject().put("date", date).put("isDemo", false).put("id", "task-disabled").put("text", text)))
    val day = VoiceAlarmWakeupClient.parseDay(raw.toString(), date)
    check(day.historyItems.single().text == text && !day.shouldRing)
    val session = VoiceAlarmWakeSession("本地开场")
    session.rememberRemote(date, 0, day)
    check(session.remoteForRound(date) == null && !session.shouldFollowUpOnTasks(date))
  }
  scenario("disabled alarm never supplies cloud content") {
    rejects { VoiceAlarmWakeupClient.parseToday(fixture().put("shouldRing", false).toString(), date) }
  }
  scenario("unknown or demo site mode never supplies formal content") {
    listOf(JSONObject(), JSONObject().put("demoMode", true)).forEach { settings ->
      rejects { VoiceAlarmWakeupClient.parseToday(fixture().put("settings", settings).toString(), date) }
    }
  }
  scenario("stale envelope or stale body is rejected") {
    rejects { VoiceAlarmWakeupClient.parseToday(fixture().put("date", "2026-11-15").toString(), date) }
    val stale = fixture(); stale.getJSONObject("content").put("date", "2026-11-15")
    rejects { VoiceAlarmWakeupClient.parseToday(stale.toString(), date) }
  }
  scenario("demo and synthetic messages are rejected even with today's date") {
    val demo = fixture(); demo.getJSONObject("content").put("isDemo", true)
    rejects { VoiceAlarmWakeupClient.parseToday(demo.toString(), date) }
    val synthetic = fixture(); synthetic.getJSONObject("content").put("source", "synthetic")
    rejects { VoiceAlarmWakeupClient.parseToday(synthetic.toString(), date) }
    val unknown = fixture(); unknown.getJSONObject("content").remove("isDemo")
    rejects { VoiceAlarmWakeupClient.parseToday(unknown.toString(), date) }
  }
  scenario("empty missing or oversized text falls back instead of speaking invalid data") {
    listOf(" ", "字".repeat(16001)).forEach { body ->
      val bad = fixture(); bad.getJSONObject("content").put("body", body)
      rejects { VoiceAlarmWakeupClient.parseToday(bad.toString(), date) }
    }
    rejects { VoiceAlarmWakeupClient.parseToday(fixture().put("content", JSONObject.NULL).toString(), date) }
  }
  scenario("long messages remain complete and emoji survive TTS chunk boundaries") {
    val long = "字".repeat(3999) + "🌅" + "继续行动。".repeat(1200)
    val chunks = VoiceAlarmTextChunks.split(long, 4000)
    check(chunks.size > 1 && chunks.joinToString("") == long)
    check(chunks.all { it.length <= 4000 && !it.last().isHighSurrogate() && !it.first().isLowSurrogate() })
  }
  scenario("only HTTPS root origins are accepted") {
    check(VoiceAlarmWakeupClient.normalizeBaseUrl(" https://wakeup.example/ ") == "https://wakeup.example")
    listOf("http://wakeup.example", "https://user:password@wakeup.example", "https://wakeup.example/api", "https://wakeup.example/?token=test", "https://wakeup.example/#fragment").forEach { url ->
      rejects { VoiceAlarmWakeupClient.normalizeBaseUrl(url) }
    }
  }
  val access = WakeupAccess("https://wakeup.example", "fictional-device", "fictional-platform")
  fun transport(code: Int, body: String, type: String = "application/json", inspect: (okhttp3.Request) -> Unit = {}): OkHttpClient =
    OkHttpClient.Builder().followRedirects(true).addInterceptor { chain ->
      inspect(chain.request())
      Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(code).message("fixture")
        .header("Content-Type", type).header("Location", "https://elsewhere.example/")
        .body(body.toResponseBody()).build()
    }.build()
  scenario("authenticated GET uses separate device and private-site headers") {
    var calls = 0
    val content = VoiceAlarmWakeupClient.fetch(access, date, transport(200, fixture().toString(), "application/json; charset=utf-8") { req ->
      calls++; check(req.method == "GET" && req.url.toString() == "https://wakeup.example/api/alarm/today")
      check(req.header("Authorization") == "Bearer fictional-device")
      check(req.header("OAI-Sites-Authorization") == "Bearer fictional-platform")
      check(req.header("Cache-Control") == "no-store")
    })
    check(calls == 1 && content.text == text)
  }
  scenario("HTTP auth failures and redirects never expose response or credentials") {
    listOf(302, 401, 403, 500).forEach { code ->
      val error = rejects { VoiceAlarmWakeupClient.fetch(access, date, transport(code, "PRIVATE fictional-device fictional-platform")) }
      check(error.message.orEmpty().contains("HTTP $code"))
      check(!error.message.orEmpty().contains("PRIVATE") && !error.message.orEmpty().contains("fictional-"))
    }
  }
  scenario("private-site HTML login page is rejected") {
    rejects { VoiceAlarmWakeupClient.fetch(access, date, transport(200, "<html>login</html>", "text/html")) }
  }
  scenario("unbounded HTTP bodies are rejected before JSON parsing") {
    rejects { VoiceAlarmWakeupClient.fetch(access, date, transport(200, "x".repeat(1048577))) }
  }
  scenario("header injection and missing device credential are rejected before HTTP") {
    val forbidden = OkHttpClient.Builder().addInterceptor { error("Must not call network") }.build()
    rejects { VoiceAlarmWakeupClient.fetch(access.copy(deviceToken = ""), date, forbidden) }
    rejects { VoiceAlarmWakeupClient.fetch(access.copy(serviceToken = "fake\r\nOther: value"), date, forbidden) }
  }
  scenario("network failure remains distinct from rejected live content") {
    val offline = OkHttpClient.Builder().addInterceptor { throw IOException("fictional offline") }.build()
    check(rejects { VoiceAlarmWakeupClient.fetch(access, date, offline) } is IOException)
    check(rejects { VoiceAlarmWakeupClient.fetch(access, date, transport(401, "{}")) } !is IOException)
  }
  scenario("dismiss or a new alarm invalidates an in-flight cloud response") {
    val gate = VoiceAlarmReplyGate()
    val pending = gate.next()
    gate.next() // same operation used by stopSignals / ACTION_STOP
    check(!gate.isCurrent(pending))
    val nextAlarm = gate.next()
    check(gate.isCurrent(nextAlarm) && !gate.isCurrent(pending))
  }
  println("$passed AI Wakeup regression scenarios passed")
}
