package com.example.quote_app

import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Offline regression cases. These are not an acoustic accuracy benchmark. */
fun main() {
  var passed = 0
  fun scenario(name: String, body: () -> Unit) {
    body()
    passed++
    println("PASS $name")
  }
  scenario("quiet speech can start without high-volume endpoint frames") {
    val voice = VoiceAlarmSpeechPolicy.isVoice(160, 520, 45, 325, 65, 24.0)
    check(voice)
    val window = VoiceAlarmSpeechPolicy.StartWindow()
    repeat(5) { check(!window.accept(voice)) }
    check(window.accept(voice))
  }
  scenario("consonants and short gaps do not reset the complete onset") {
    val window = VoiceAlarmSpeechPolicy.StartWindow()
    listOf(true, false, true, true, false, true, true).forEach { check(!window.accept(it)) }
    check(window.accept(true))
  }
  scenario("isolated taps and old noise cannot accumulate into a turn") {
    val window = VoiceAlarmSpeechPolicy.StartWindow()
    repeat(100) { i -> check(!window.accept(i % 5 == 0)) }
    repeat(12) { window.accept(false) }
    check(!window.accept(true))
  }
  scenario("silence, broadband noise and DC are rejected") {
    check(!VoiceAlarmSpeechPolicy.isVoice(0, 0, 0, 0, 0, 24.0))
    check(!VoiceAlarmSpeechPolicy.isVoice(800, 2500, 480, 312, 8, 24.0))
    check(!VoiceAlarmSpeechPolicy.isVoice(800, 800, 0, 100, 100, 24.0))
  }
  scenario("high-frequency human speech is not declared music by ZCR") {
    check(VoiceAlarmSpeechPolicy.isVoice(300, 1200, 125, 400, 55, 24.0))
  }
  scenario("noise floor is relative instead of a mandatory loudness threshold") {
    check(!VoiceAlarmSpeechPolicy.isVoice(180, 650, 40, 360, 60, 100.0))
    check(VoiceAlarmSpeechPolicy.isVoice(360, 1250, 40, 347, 60, 100.0))
  }
  scenario("speaker fragment transcribed without punctuation must not stop TTS") {
    // Synthetic prompt containing the six-character fragment from the bug report.
    val playing = listOf("测试提醒。愿你专注、充满力量。现在站起来。")
    check(VoiceAlarmSpeechPolicy.isEcho("专注充满力量", playing, true))
    check(VoiceAlarmSpeechPolicy.isEcho("充满力量", playing, true))
    check(VoiceAlarmSpeechPolicy.isEcho("专注", listOf("愿你平静、专注、充满力量。"), true))
    check(!VoiceAlarmSpeechPolicy.isEcho("起来", playing, true)) // Only part of a longer clause.
    check(!VoiceAlarmSpeechPolicy.isEcho("ring", listOf("bringing coffee"), true))
    check(!VoiceAlarmSpeechPolicy.isEcho("专注充满力量是什么意思", playing, true))
    check(!VoiceAlarmSpeechPolicy.isEcho("请关闭背景音乐", playing, true))
    check(!VoiceAlarmSpeechPolicy.isEcho("关闭闹钟", playing, true))
    check(!VoiceAlarmSpeechPolicy.isEcho("专注充满力量", playing, false))
  }
  scenario("a two-character ASR omission stays echo across streaming revisions and final") {
    val sources = listOf("测试提醒。扶着床沿站起来，停三秒。")
    for (draft in listOf("扶着", "扶着站起", "扶着站起来", "扶着站起来停")) {
      check(VoiceAlarmSpeechPolicy.isEcho(draft, sources, true, partial = true))
    }
    check(VoiceAlarmSpeechPolicy.isEcho("扶着站起来停三秒", sources, true))
    check(!VoiceAlarmSpeechPolicy.isEcho("扶着站起来停三秒", sources, false))
  }
  scenario("nearby questions new words negations and distant fragments remain user speech") {
    val sources = listOf("扶着床沿站起来，停三秒。现在不要打开音乐。")
    for (reply in listOf("扶着站起来停几秒", "我不想站起来", "扶着站起来停三秒吗", "现在打开音乐", "请打开音乐")) {
      check(!VoiceAlarmSpeechPolicy.isEcho(reply, sources, true))
    }
    check(!VoiceAlarmSpeechPolicy.isEcho("扶着站起来停三秒", listOf("扶着桌边喝水之后再站起来停三秒"), true))
  }
  val echo = VoiceAlarmConversationGate.Route.ECHO
  val review = VoiceAlarmConversationGate.Route.REVIEW
  val send = VoiceAlarmConversationGate.Route.SEND
  val mic = VoiceAlarmConversationGate.Route.OPEN_MIC
  fun route(text: String, sources: List<String> = emptyList(), mixed: Boolean = false,
            final: Boolean = true, reliable: Boolean = true, armed: Boolean = false, passive: Boolean = !armed) =
    VoiceAlarmConversationGate.decide(text, sources, mixed, final, reliable, armed, localCommand = false, passive = passive)

  scenario("v44 incident replay cannot interrupt TTS or enter correction or conversation") {
    val source = listOf("测试。平静、专注、充满力量。每周专注一项、每天检查行为。")
    val capture = VoiceAlarmCapture(2, true)
    capture.note(source)
    val atEnd = capture.finish(3, false)
    val routes = listOf("平静专注充满力量", "专注一下每天检查行为").map {
      route(it, atEnd.sources, atEnd.mixed, armed = true).route
    }
    check(routes == listOf(echo, echo))
  }
  scenario("unrelated or heavily mangled playback goes to review even if it sounds like a question") {
    for (candidate in listOf("怎么整理测试记录", "闹钟助手我今天要做什么", "我已经起来了")) {
      check(route(candidate, listOf("虚构测试播报"), true, armed = true).route == review)
      check(route(candidate, emptyList(), true, armed = true).route == review)
    }
  }
  scenario("clean intentional voice accepts questions and ordinary conversation without dropping words") {
    check(route("闹钟助手，我今天该先做什么？").let { it.route == send && it.text == "我今天该先做什么？" })
    check(route("我已经坐起来了", armed = true).route == send)
    check(route("专注一下每天检查行为", armed = true).route == send)
    check(route("刚才听到闹钟助手这个词").route == review)
    check(route("助手这个词是什么意思").let { it.route == send && it.text == "助手这个词是什么意思" })
  }
  scenario("a complete question in quiet standby goes directly to AI even without punctuation") {
    for (question in listOf("他有几个兄弟", "这件事的动力是什么", "能不能解释一下", "今天有安排吗", "Are you there?")) {
      check(route(question).let { it.route == send && it.text == question })
    }
    check(route("我记得他有几个兄弟").route == review)
    check(route("我不知道他有几个兄弟").route == review)
    check(route("随便选哪一个都行").route == review)
    check(route("我已经回来了").route == review)
  }
  scenario("question-shaped words cannot bypass echo, partial, or playback overlap checks") {
    val question = "他有几个兄弟"
    val reminder = listOf("读完故事后想想，他有几个兄弟？")
    check(route(question, reminder, mixed = true).route == echo)
    check(route(question, mixed = true).reviewReason == VoiceAlarmConversationGate.ReviewReason.PLAYBACK_OVERLAP)
    check(route(question, final = false).route == VoiceAlarmConversationGate.Route.DRAFT)
    check(route(question, reliable = false).reviewReason == VoiceAlarmConversationGate.ReviewReason.INCOMPLETE)
  }
  scenario("an intentional reply window never authorizes a previous cloud job or joined captures") {
    val old = VoiceAlarmCapture(2, false, windowId = 3).finish(2, false)
    val current = VoiceAlarmCapture(2, false, windowId = 4).finish(2, false)
    check(!old.belongsTo(4) && !old.merge(current).belongsTo(4))
    check(!current.belongsTo(0) && current.belongsTo(4))
    check(route("我还想再问一句", armed = current.belongsTo(4)).route == send)
    check(route("我还想再问一句", armed = old.belongsTo(4)).route == review)
    val standby = VoiceAlarmCapture(2, false).finish(2, false)
    for (capture in listOf(old, old.merge(current), old.merge(standby))) {
      check(capture.windowId != 0L)
      check(route("还有什么安排", armed = capture.belongsTo(4), passive = capture.windowId == 0L).route == review)
    }
    val echo = listOf("下一步整理桌面")
    check(route("整理桌面", echo, mixed = true, armed = true).route == VoiceAlarmConversationGate.Route.ECHO)
  }
  scenario("two stable interruption drafts can pause speech but never send a user query") {
    val capture = VoiceAlarmCapture(1, true)
    val source = listOf("请看窗边的日历。")
    check(!capture.confirmedPause("先听我说", 100, source))
    check(!capture.confirmedPause("先听我说", 200, source))
    check(capture.confirmedPause("先听我说", 300, source))
    check(route("先听我说", source, mixed = true).route == mic)
    check(route("先听我说", listOf("先听我说，再看日历"), mixed = true).route == echo)
    check(!capture.confirmedPause("先听我说", 600, listOf("请先听我说完")))
    capture.finish(2, false)
    check(!capture.confirmedPause("先听我说", 900, source))
  }
  scenario("music-only and tail overlap remain reviewable and preserve the reason when results arrive late") {
    val bed = VoiceAlarmCapture(1, true, "music", 12)
    val held = bed.finish(2, false)
    check(held.sources.isEmpty() && held.mixCause == "start_music")
    check(route("五字测试句", held.sources, held.mixed, armed = held.belongsTo(12)).route == review)
    check(VoiceAlarmCapture(2, false).finish(3, false).mixCause == "output_changed")
    check(VoiceAlarmCapture(2, false).finish(2, true, "tail").mixCause == "end_tail")
  }
  scenario("only a final standalone wake cue can open a fresh microphone turn") {
    check(route("闹钟助手", mixed = true).route == mic)
    check(route("小名", listOf("请把小名写在这里"), mixed = true).route == echo)
    check(route("闹钟助手", final = false).route == VoiceAlarmConversationGate.Route.DRAFT)
    check(route("闹钟助手", reliable = false).route == review)
    check(route("我想继续", armed = true, reliable = false).route == review)
  }
  scenario("capture retains music-only or missed playback across online recognition delays") {
    val mixed = VoiceAlarmCapture(5, false)
    val result = mixed.finish(7, false)
    check(result.mixed && result.sources.isEmpty())
    val clean = VoiceAlarmCapture(8, false)
    check(!clean.finish(8, false).mixed)
    clean.note(listOf("晚到的新播报"))
    check(!clean.finish(10, true).mixed && clean.finish(10, true).sources.isEmpty())
    check(result.merge(clean.finish(10, true)).mixed)
  }
  scenario("substitutions changing intent stay available for review or as a clean question") {
    check(!VoiceAlarmSpeechPolicy.isEcho("请告诉我停几秒再走", listOf("请告诉我停三秒再走"), true))
    check(route("请告诉我停几秒再走", listOf("请告诉我停三秒再走"), mixed = true).route == review)
  }
  scenario("clean reply can quote or repeat the assistant") {
    check(!VoiceAlarmSpeechPolicy.isEcho("新的一天开始了", listOf("早上好，新的一天开始了"), false))
    check(!VoiceAlarmSpeechPolicy.isEcho("早上好，新的一天开始了", listOf("早上好，新的一天开始了"), false))
  }
  scenario("negation and punctuation are not stripped from user speech") {
    check(!VoiceAlarmSpeechPolicy.isEcho("请不要关闭闹钟！", listOf("关闭闹钟"), true))
    check(!VoiceAlarmSpeechPolicy.isEcho("你说整理好心情，是什么意思？", listOf("整理好心情"), true))
    check(VoiceAlarmSpeechPolicy.isEcho("早上好，新的一天开始了", listOf("早上好，新的一天开始了"), true))
  }
  scenario("iFlytek corrections replace all old packets, even when shorter") {
    val transcript = VoiceAlarmTranscript()
    transcript.apply(0, "我想")
    transcript.apply(1, "关闭闹钟")
    check(transcript.apply(2, "不要关闭", 0, 1) == "不要关闭")
    check(transcript.apply(1, "关闭闹钟") == "不要关闭")
    check(transcript.apply(3, "不要关闭闹钟", 2, 2) == "不要关闭闹钟")
    check(transcript.apply(2, "不要关闭", 0, 1) == "不要关闭闹钟")
  }
  scenario("empty replacement removes hallucinated speech") {
    val transcript = VoiceAlarmTranscript()
    transcript.apply(0, "错误文本")
    check(transcript.apply(1, "", 0, 0).isEmpty())
  }
  scenario("late cloud result cannot revive interrupted or superseded reply") {
    val gate = VoiceAlarmReplyGate()
    val first = gate.next()
    val fallback = gate.next()
    check(!gate.isCurrent(first))
    check(gate.isCurrent(fallback))
    gate.next() // user interrupts during local fallback
    check(!gate.isCurrent(fallback))
  }
  scenario("mentioning or negating an alarm command never dismisses it") {
    check(VoiceAlarmCommands.isStop("请关闭闹钟。"))
    check(VoiceAlarmCommands.isStop("不要再响了"))
    check(!VoiceAlarmCommands.isStop("请不要关闭闹钟！"))
    check(!VoiceAlarmCommands.isStop("为什么关闭闹钟？"))
    check(!VoiceAlarmCommands.isStop("我刚才说关闭闹钟了吗"))
    check(VoiceAlarmCommands.discussesOrNegatesSnooze("不要延迟五分钟"))
    check(VoiceAlarmCommands.discussesOrNegatesSnooze("如何设置稍后提醒"))
  }
  scenario("snooze parses whole Chinese numbers, not suffix matches") {
    check(VoiceAlarmCommands.snoozeMinutes("延迟四十五分钟") == 45)
    check(VoiceAlarmCommands.snoozeMinutes("延迟二十五分钟") == 25)
    check(VoiceAlarmCommands.snoozeMinutes("一百零五分钟后提醒") == 105)
    check(VoiceAlarmCommands.snoozeMinutes("延迟两小时") == 120)
    check(VoiceAlarmCommands.snoozeMinutes("延迟200分钟") == null)
    check(VoiceAlarmCommands.snoozeMinutes("延迟0分钟") == null)
  }
  scenario("microphone keeps recording during network waits and preserves order") {
    val captured = CountDownLatch(4)
    val hold = CountDownLatch(1)
    var seq = 0
    val pump = VoiceAlarmPcmPump({ frame ->
      if (seq >= 4) hold.await()
      frame.fill((++seq).toByte())
      captured.countDown()
      frame.size
    }, 8)
    try {
      check(captured.await(2, TimeUnit.SECONDS))
      val frame = ByteArray(VoiceAlarmSpeechPolicy.FRAME_BYTES)
      for (expected in 1..4) {
        check(pump.read(frame) == frame.size)
        check(frame.all { it == expected.toByte() })
      }
    } finally { pump.close(); hold.countDown() }
  }
  scenario("buffered TTS samples keep their capture-time provenance and the first clean syllable stays queued") {
    val bed = VoiceAlarmFrameStamp(0, 11, "voice")
    val live = VoiceAlarmFrameStamp(4, 12, "quiet")
    val copied = CountDownLatch(3)
    val stop = CountDownLatch(1)
    var written = 0
    var stamps = 0
    val pump = VoiceAlarmPcmPump({ frame ->
      if (written >= 3) stop.await()
      frame.fill((++written).toByte())
      copied.countDown()
      frame.size
    }, 6, stamp = {
      if (Thread.currentThread().name == "voice-alarm-pcm" && stamps++ < 2) bed else live
    })
    try {
      check(copied.await(2, TimeUnit.SECONDS))
      val bytes = ByteArray(640)
      val old = VoiceAlarmCapture(12, false)
      val next = VoiceAlarmCapture(12, false, windowId = 4)
      check(pump.read(bytes, old) == 640 && bytes.first() == 1.toByte())
      check(pump.read(bytes, old) == VoiceAlarmPcmPump.NEXT_WINDOW)
      check(old.finish(12, false).mixCause == "frame_voice")
      for (index in 2..3) check(pump.read(bytes, next) == 640 && bytes.all { it == index.toByte() })
      val received = next.finish(12, false)
      check(received.belongsTo(4) && !received.mixed)
    } finally { pump.close(); stop.countDown() }
  }
  scenario("overflow and dead microphone are explicit recoverable errors") {
    val pump = VoiceAlarmPcmPump({ frame -> frame.size }, 1)
    try {
      val end = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
      var error: IOException? = null
      while (error == null && System.nanoTime() < end) {
        Thread.yield()
        try { pump.read(ByteArray(640)) } catch (t: IOException) { error = t }
      }
      check(error != null)
    } finally { pump.close() }
    val dead = VoiceAlarmPcmPump({ -6 })
    try {
      val end = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
      var failed = false
      while (!failed && System.nanoTime() < end) {
        try { dead.read(ByteArray(640)) } catch (_: IOException) { failed = true }
      }
      check(failed)
    } finally { dead.close() }
  }
  println("$passed voice-alarm regression scenarios passed")
}
