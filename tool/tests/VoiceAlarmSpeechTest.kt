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
