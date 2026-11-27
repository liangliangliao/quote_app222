package com.example.quote_app

import org.json.JSONArray
import org.json.JSONObject

fun main() {
  var passed = 0
  fun scenario(name: String, test: () -> Unit) { test(); passed++; println("PASS $name") }
  scenario("long reminder preserves all characters and requires acknowledgements") {
    val text = "这是一段虚构提醒。🙂请坐起，双脚落地。\n".repeat(400)
    val queue = VoiceAlarmPlaybackQueue(); queue.start(text)
    val spoken = StringBuilder()
    while (queue.pending) {
      val item = queue.current!!; check(item.text.length <= 180); spoken.append(item.text)
      check(!queue.done("stale")); check(queue.done(item.id)); check(!queue.done(item.id))
    }
    check(spoken.toString() == text)
  }
  scenario("pause and volume changes keep unread chunks and invalidate old callbacks") {
    val q = VoiceAlarmPlaybackQueue(); q.start("abc".repeat(300)); q.done(q.current!!.id)
    val old = q.current!!; val next = q.resume()!!
    check(old.text == next.text && old.id != next.id && !q.done(old.id) && q.done(next.id))
  }
  scenario("a quiet listening pause resumes from the unread chunk and ignores callbacks from before the pause") {
    val text = "第一句已听完。第二句被暂停。第三句继续播。"
    val q = VoiceAlarmPlaybackQueue()
    val first = q.start(text, limit = 7)!!
    check(q.done(first.id))
    val interrupted = q.current!!
    q.resume() // Invalidate the TTS callback before stopping the speaker.
    check(!q.done(interrupted.id))
    q.resume()
    val rest = StringBuilder()
    check(q.current!!.text == interrupted.text)
    while (q.pending) {
      val item = q.current!!
      rest.append(item.text)
      check(q.done(item.id))
    }
    check(first.text + rest.toString() == text)
  }
  scenario("TTS retry is bounded and does not discard unread text") {
    val q = VoiceAlarmPlaybackQueue(); q.start("测试")
    repeat(2) { check(q.retry(q.current!!.id) != null) }
    check(q.retry(q.current!!.id) == null && q.current!!.text == "测试")
  }
  scenario("dismiss prevents late callbacks reviving output") {
    val q = VoiceAlarmPlaybackQueue(); val old = q.start("测试")!!; q.cancel()
    check(!q.pending && !q.done(old.id) && q.resume() == null && !q.done(null))
  }
  scenario("sentence splitting preserves whitespace and surrogate pairs") {
    val text = "啊🙂。\n你好！  世界\n最后一句"
    for (n in 2..12) {
      val parts = VoiceAlarmTextChunks.split(text, n)
      check(parts.joinToString("") == text)
      check(parts.all { it.length <= n && !it.first().isLowSurrogate() && !it.last().isHighSurrogate() })
    }
  }
  scenario("music commands do not dismiss alarm") {
    for (text in listOf("请关闭背景音乐", "请帮我关掉背景音乐", "暂停播放音乐", "把背景音乐关掉", "不要播放背景音乐")) {
      check(VoiceAlarmCommands.music(text) == VoiceAlarmCommands.Music.STOP); check(!VoiceAlarmCommands.isStop(text))
    }
    for (text in listOf("播放背景音乐", "请打开背景音乐", "恢复播放音乐", "把背景音乐打开")) check(VoiceAlarmCommands.music(text) == VoiceAlarmCommands.Music.PLAY)
  }
  scenario("negations questions and discussion do not change music") {
    for (text in listOf("不要关闭背景音乐", "别关掉音乐", "为什么关闭背景音乐", "我刚才说播放背景音乐了吗", "如果关闭背景音乐", "不要停止音乐")) check(VoiceAlarmCommands.music(text) == null)
  }
  scenario("music resumes only after all overlapping speakers end") {
    val mix = VoiceAlarmMusicState()
    val owner = Any()
    for (speaker in listOf(VoiceAlarmMusicState.Speaker.USER, VoiceAlarmMusicState.Speaker.REMINDER, VoiceAlarmMusicState.Speaker.ASSISTANT)) mix.setSpeaking(speaker, owner, true)
    for (speaker in listOf(VoiceAlarmMusicState.Speaker.REMINDER, VoiceAlarmMusicState.Speaker.ASSISTANT)) {
      mix.setSpeaking(speaker, owner, false)
      check(mix.gain(.35f) == 0f)
    }
    mix.setSpeaking(VoiceAlarmMusicState.Speaker.USER, owner, false)
    check(mix.gain(.35f) == .35f)
  }
  scenario("reminder and assistant duck music while an idle listening window keeps full gain") {
    val mix = VoiceAlarmMusicState()
    val owner = Any()
    mix.setSpeaking(VoiceAlarmMusicState.Speaker.LISTEN_REQUEST, owner, true)
    check(mix.gain(.8f) == .8f)
    for (speaker in listOf(VoiceAlarmMusicState.Speaker.REMINDER, VoiceAlarmMusicState.Speaker.ASSISTANT)) {
      mix.setSpeaking(speaker, owner, true)
      mix.choose(false)
      check(mix.gain(.8f) == 0f)
      mix.choose(true)
      check(mix.gain(.8f) in 0.17f..0.18f && mix.gain(0f) == 0f)
      mix.setSpeaking(VoiceAlarmMusicState.Speaker.USER, owner, true)
      check(mix.gain(.6f) == 0f)
      mix.setSpeaking(VoiceAlarmMusicState.Speaker.USER, owner, false)
      check(mix.gain(.6f) in 0.13f..0.14f)
      mix.setSpeaking(speaker, owner, false)
      check(mix.gain(.6f) == .6f)
    }
  }
  scenario("manual music OFF survives the last speech end and stale owners") {
    val mix = VoiceAlarmMusicState()
    val old = Any()
    val current = Any()
    val user = VoiceAlarmMusicState.Speaker.USER
    mix.setSpeaking(user, old, true)
    mix.setSpeaking(user, current, true)
    check(!mix.setSpeaking(user, old, false) && mix.gain(.6f) == 0f)
    mix.choose(false)
    mix.setSpeaking(user, current, false)
    check(mix.gain(.6f) == 0f)
  }
  scenario("startup listening lowers audible music, speech mutes it, and releasing the startup hold restores it") {
    val mix = VoiceAlarmMusicState()
    val owner = Any()
    val startup = VoiceAlarmMusicState.Speaker.STARTUP_LISTEN
    val user = VoiceAlarmMusicState.Speaker.USER
    mix.setSpeaking(startup, owner, true)
    check(mix.gain(.4f) in .087f.. .089f)
    mix.setSpeaking(user, owner, true)
    mix.setSpeaking(startup, owner, false)
    check(mix.gain(.4f) == 0f)
    mix.setSpeaking(user, owner, false)
    check(mix.gain(.4f) == .4f)
  }
  scenario("music intro starts counting when the track plays and pauses during a microphone mute") {
    val intro = VoiceAlarmMusicIntro(5000)
    val preparing = VoiceAlarmMusicIntro.Output.PREPARING
    val audible = VoiceAlarmMusicIntro.Output.AUDIBLE
    val muted = VoiceAlarmMusicIntro.Output.TEMPORARILY_MUTED
    check(intro.nextCheckDelay(1000, preparing) == 4000L)
    check(intro.nextCheckDelay(2400, audible) == 5000L)
    check(intro.nextCheckDelay(4000, muted) == null)
    check(intro.nextCheckDelay(6000, audible) == 3400L)
    check(intro.nextCheckDelay(9400, audible) == 0L)
  }
  scenario("music intro preserves remaining time on route changes and skips unavailable music") {
    val audible = VoiceAlarmMusicIntro.Output.AUDIBLE
    val preparing = VoiceAlarmMusicIntro.Output.PREPARING
    val unavailable = VoiceAlarmMusicIntro.Output.UNAVAILABLE
    val intro = VoiceAlarmMusicIntro(10000)
    check(intro.nextCheckDelay(1000, audible) == 10000L)
    check(intro.nextCheckDelay(4000, preparing) == 4000L)
    check(intro.nextCheckDelay(5000, audible) == 7000L)
    check(intro.nextCheckDelay(5100, unavailable) == 0L)
    val stalled = VoiceAlarmMusicIntro(20000)
    check(stalled.nextCheckDelay(0, preparing) == 4000L)
    check(stalled.nextCheckDelay(4000, preparing) == 0L)
  }
  scenario("pre-roll and first syllables survive byte for byte") {
    val turn = VoiceAlarmTurnBuffer(800, 10000)
    val frames = (1..20).map { ByteArray(640) { _ -> it.toByte() } }
    frames.forEachIndexed { i, frame -> turn.add(frame, i >= 14) }
    check(turn.started && turn.audio().contentEquals(frames.flatMap { it.toList() }.toByteArray()))
  }
  scenario("sentence pauses retained and endpoint waits for full silence") {
    val turn = VoiceAlarmTurnBuffer(800, 10000)
    repeat(10) { check(!turn.add(ByteArray(640) { 1 }, true)) }
    repeat(20) { check(!turn.add(ByteArray(640), false)) }
    repeat(10) { check(!turn.add(ByteArray(640) { 2 }, true)) }
    repeat(39) { check(!turn.add(ByteArray(640), false)) }
    check(turn.add(ByteArray(640), false)); check(turn.audio().size == 80 * 640)
  }
  scenario("idle time never consumes user turn duration") {
    val turn = VoiceAlarmTurnBuffer(800, 2000)
    repeat(4000) { check(!turn.add(ByteArray(640), false)) }
    repeat(50) { check(!turn.add(ByteArray(640) { 2 }, true)) }
    check(turn.started && turn.audio().size > 32000)
  }
  scenario("consonant gaps preserve complete onset") {
    val turn = VoiceAlarmTurnBuffer(800, 10000)
    listOf(true,false,true,true,false,true,true,true).forEachIndexed { i,v -> turn.add(ByteArray(640) { i.toByte() },v) }
    check(turn.started && turn.audio().size == 8 * 640)
  }
  scenario("manual submit keeps unconfirmed soft speech") {
    val turn = VoiceAlarmTurnBuffer(800,10000); repeat(12) { turn.add(ByteArray(640) { 1 },false) }
    check(turn.audio().isEmpty() && turn.audio(true).size == 12 * 640)
  }
  scenario("delayed echo uses capture snapshot while user quotations survive") {
    val text = "这是一条虚构的完整唤醒提醒"
    check(VoiceAlarmSpeechPolicy.isEcho(text, listOf(text), true))
    check(!VoiceAlarmSpeechPolicy.isEcho(text + "是什么意思", listOf(text), true))
  }
  fun config(provider: String, endpoint: String) = JSONObject().put("provider",provider).put("endpoint",endpoint).put("model","fictional")
  scenario("three providers send actual native search tools with same origin") {
    for ((p,h,prefix) in listOf(Triple("openai","api.openai.com","/v1"),Triple("xgrok","api.x.ai","/v1"),Triple("openrouter","openrouter.ai","/api/v1"))) {
      val plan = VoiceAlarmWebSearch.plan(config(p,"https://$h$prefix/chat/completions"), JSONArray(),true)
      check(plan.enabled && plan.error == null && plan.endpoint == "https://$h$prefix/responses")
      check(plan.body.has("input") && !plan.body.has("messages") && !plan.body.has("temperature"))
      check(plan.body.getJSONArray("tools").getJSONObject(0).getString("type") == if (p == "openrouter") "openrouter:web_search" else "web_search")
      check(!plan.body.getBoolean("store"))
    }
  }
  scenario("search OFF preserves existing ordinary conversation") {
    val plan = VoiceAlarmWebSearch.plan(config("deepseek","https://api.deepseek.com/chat/completions"),JSONArray(),false)
    check(!plan.enabled && plan.error == null && plan.body.has("messages") && !plan.body.has("tools"))
  }
  scenario("unsupported or custom endpoints never silently migrate credentials") {
    for (c in listOf(config("deepseek","https://api.deepseek.com/chat/completions"),config("openai","https://custom.example/v1/chat/completions"),config("openai","http://api.openai.com/v1/chat/completions"))) {
      val plan = VoiceAlarmWebSearch.plan(c,JSONArray(),true)
      check(!plan.enabled && plan.error != null && plan.endpoint == c.getString("endpoint"))
    }
  }
  scenario("sources need structured evidence and unsafe URLs are rejected") {
    val obj = JSONObject("""{"output":[{"type":"message","content":[{"type":"output_text","annotations":[{"type":"url_citation","url":"https://example.org/source"},{"type":"url_citation","url":"javascript:alert(1)"}]}]}],"citations":["https://example.org/source","https://user:secret@example.org/secret"]}""")
    check(VoiceAlarmWebSearch.sources(obj) == listOf("https://example.org/source"))
    check(VoiceAlarmWebSearch.searched(obj)); check(!VoiceAlarmWebSearch.searched(JSONObject("""{"output_text":"I searched online"}""")))
  }
  scenario("xAI chunk finals retain prior words and full correction wins") {
    val t = VoiceAlarmXaiTranscript()
    check(t.apply(JSONObject("""{"type":"transcript.partial","text":"第一句话。","start":0,"is_final":true}""")) == "第一句话。")
    check(t.apply(JSONObject("""{"type":"transcript.partial","text":"第二","start":3}""")) == "第一句话。第二")
    check(t.apply(JSONObject("""{"type":"transcript.partial","text":"第二句话。","start":3,"is_final":true}""")) == "第一句话。第二句话。")
    check(t.apply(JSONObject("""{"type":"transcript.partial","text":"修正后的完整句。","speech_final":true,"is_final":true}""")) == "修正后的完整句。")
    check(t.apply(JSONObject("""{"type":"transcript.done","duration":6}""")) == "修正后的完整句。")
  }
  println("$passed live voice regression scenarios passed")
}
