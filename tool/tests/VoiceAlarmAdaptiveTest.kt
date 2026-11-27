package com.example.quote_app

import org.json.JSONObject
import org.json.JSONArray
import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

fun main() {
  var passed = 0
  fun scenario(name: String, body: () -> Unit) { body(); passed++; println("PASS $name") }
  fun rejects(body: () -> Unit) { check(runCatching(body).isFailure) }
  scenario("Microsoft speech distinguishes a normal no-match from a failed service") {
    val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
    server.createContext("/") { exchange ->
      check(exchange.requestHeaders.getFirst("Ocp-Apim-Subscription-Key") == "test-key")
      check(exchange.requestHeaders.getFirst("Content-Type") == "audio/wav; codecs=audio/pcm; samplerate=16000")
      check(exchange.requestBody.use { it.readBytes() }.contentEquals(byteArrayOf(1, 2)))
      val (status, body) = when (exchange.requestURI.path) {
        "/result" -> 200 to """{"RecognitionStatus":"Success","NBest":[{"Display":"","Lexical":"查一下天气"}]}"""
        "/silent" -> 200 to """{"RecognitionStatus":"InitialSilenceTimeout"}"""
        "/no-match" -> 200 to """{"RecognitionStatus":"NoMatch"}"""
        "/missing-status" -> 200 to "{}"
        "/bad-json" -> 200 to "Unexpected response"
        else -> 401 to "unauthorized"
      }
      val bytes = body.toByteArray()
      exchange.sendResponseHeaders(status, bytes.size.toLong())
      exchange.responseBody.use { it.write(bytes) }
    }
    server.start()
    try {
      val speech = VoiceAlarmMicrosoftSpeech()
      fun recognize(path: String) =
        speech.recognize("http://127.0.0.1:${server.address.port}/$path", "test-key", byteArrayOf(1, 2), 1500L)
      check(recognize("result") == "查一下天气")
      check(recognize("silent").isEmpty())
      check(recognize("no-match").isEmpty())
      val denied = runCatching { recognize("bad-key") }.exceptionOrNull()
      check(denied is java.io.IOException && denied.message == "Microsoft Speech HTTP 401")
      check(runCatching { recognize("missing-status") }.exceptionOrNull() is java.io.IOException)
      check(runCatching { recognize("bad-json") }.exceptionOrNull() is java.io.IOException)
    } finally {
      server.stop(0)
    }
  }
  scenario("Microsoft speech has one total deadline even if the response stalls mid-body") {
    val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
    val headersSent = CountDownLatch(1)
    val releaseBody = CountDownLatch(1)
    server.createContext("/slow") { exchange ->
      exchange.requestBody.use { it.readBytes() }
      exchange.sendResponseHeaders(200, 100)
      headersSent.countDown()
      releaseBody.await(3L, TimeUnit.SECONDS)
      exchange.close()
    }
    server.start()
    try {
      val started = System.nanoTime()
      val result = runCatching {
        VoiceAlarmMicrosoftSpeech().recognize("http://127.0.0.1:${server.address.port}/slow",
          "test-key", byteArrayOf(1, 2), 500L)
      }
      check(headersSent.count == 0L)
      check(result.exceptionOrNull() is java.io.InterruptedIOException)
      check(TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started) < 2400L)
    } finally {
      releaseBody.countDown()
      server.stop(0)
    }
  }
  scenario("iFlytek envelope-only final retains and completes the accumulated paragraph") {
    val stream = VoiceAlarmIflytekTranscript()
    check(stream.accept("""{"code":0,"data":{"status":1,"result":{"sn":1,"ws":[{"cw":[{"w":"第一句。"},{"w":"干扰候选"}]}]}}}""")?.text == "第一句。")
    check(stream.accept("""{"code":0,"data":{"status":1,"result":{"sn":2,"ws":[{"cw":[{"w":"还有最后一句。"}]}]}}}""")?.complete == false)
    val done = stream.accept("""{"code":0,"data":{"status":2}}""")
    check(done?.complete == true && done.text == "第一句。还有最后一句。")
    check(stream.outcome(false, 12800, 14080, null) == "final")
    check(stream.accept("""{"code":0,"data":{"status":2}}""") == null)
  }
  scenario("iFlytek terminal words apply the correction before completing") {
    val stream = VoiceAlarmIflytekTranscript()
    stream.accept("""{"code":0,"data":{"result":{"sn":1,"ws":[{"cw":[{"w":"带错字的草稿"}]}]}}}""")
    val done = stream.accept("""{"code":0,"data":{"status":2,"result":{"sn":2,"ls":true,"pgs":"rpl","rg":[1,1],"ws":[{"cw":[{"w":"修正后的内容"}]}]}}}""")
    check(done?.complete == true && done.text == "修正后的内容")
  }
  scenario("iFlytek draft, close, unsent tail, and microphone interruption are never marked complete") {
    val stream = VoiceAlarmIflytekTranscript()
    stream.accept("""{"code":0,"data":{"status":1,"result":{"sn":0,"ws":[{"cw":[{"w":"没有收到结尾"}]}]}}}""")
    check(stream.accept("not a JSON response") == null)
    check(stream.accept("""{"code":10165,"data":{"status":2}}""")?.complete == false)
    check(stream.outcome(false, 10000, 10000, null) == "missing_final")
    check(stream.outcome(false, 10000, 10000, "closed_before_final") == "closed_before_final")
    check(stream.text == "没有收到结尾")
    check(stream.accept("""{"code":0,"data":{"status":2,"result":{"sn":0,"ls":true,"ws":[]}}}""")?.text == "没有收到结尾")
    check(stream.outcome(false, 11000, 10000, null) == "unsent_speech_tail")
    check(stream.outcome(true, 10000, 10000, null) == "microphone_interrupted")
  }
  scenario("iFlytek retains PCM during opening and leaves the last packet for the terminal frame") {
    val recording = VoiceAlarmIflytekAudio()
    for (i in 1..5) recording.write(ByteArray(640) { i.toByte() })
    val first = recording.packet(0, finishing = false)!!
    check(first.status == 0 && first.pcm.size == 1280)
    check(first.pcm.first() == 1.toByte() && first.pcm.last() == 2.toByte())
    check(recording.packet(1280, finishing = false) == null)
    val next = recording.packet(1280, finishing = true)!!
    check(next.status == 1 && next.pcm.first() == 3.toByte() && next.pcm.last() == 4.toByte())
    val last = recording.packet(2560, finishing = true)!!
    check(last.status == 2 && last.pcm.all { it == 5.toByte() })
    check(recording.packet(3200, finishing = true) == null)
    check(recording.toByteArray().size == 3200)
  }
  scenario("iFlytek streams music-only PCM without a local onset and finalizes the idle interval") {
    val audio = VoiceAlarmIflytekAudio()
    val capture = VoiceAlarmCapture(0L, false, windowId = 1L, acceptedFramesOnly = true)
    val voice = VoiceAlarmFrameStamp(1L, 1L, "voice")
    capture.noteFrame(voice, voice)
    check(!audio.appendCapture(ByteArray(640) { 1 }, spokenOutput = true, allowSpoken = false))
    val music = VoiceAlarmFrameStamp(1L, 2L, "music")
    capture.noteFrame(music, music)
    repeat(4) {
      check(audio.appendCapture(ByteArray(640) { 2 }, spokenOutput = false, allowSpoken = false))
      capture.noteAcceptedFrame()
    }
    val evidence = capture.finish(3L, true, "voice")
    check(evidence.mixCause == "frame_music" && !evidence.spokenPlayback && evidence.sources.isEmpty())
    val first = audio.packet(0, finishing = false)!!
    check(first.status == 0 && first.pcm.all { it == 2.toByte() })
    val last = audio.packet(first.pcm.size, finishing = true)!!
    check(last.status == 2 && last.pcm.size == 1280)

    val result = VoiceAlarmConversationGate.decide("今天有没有大的新闻发生啊", evidence.sources, evidence.mixed,
      final = true, reliable = true, armed = false, localCommand = false, passive = true,
      spokenPlayback = evidence.spokenPlayback, playbackOverlap = evidence.playbackOverlap)
    check(result.route == VoiceAlarmConversationGate.Route.SEND)
  }
  scenario("nearby speech during a spoken prompt retains onset audio and keeps its echo provenance") {
    val audio = VoiceAlarmIflytekAudio()
    val capture = VoiceAlarmCapture(0L, false, windowId = 1L, acceptedFramesOnly = true)
    val voice = VoiceAlarmFrameStamp(1L, 1L, "voice")
    capture.noteFrame(voice, voice)
    check(!audio.appendCapture(ByteArray(640) { 5 }, spokenOutput = true, allowSpoken = false))
    check(audio.appendCapture(ByteArray(640) { 6 }, spokenOutput = true, allowSpoken = true))
    val prompt = listOf("早上好，新的一天开始了。")
    capture.noteAcceptedFrame(prompt)
    val evidence = capture.finish(2L, false)
    check(audio.toByteArray().take(640).all { it == 5.toByte() })
    check(audio.size() == 1280 && evidence.spokenPlayback && evidence.sources == prompt)
    check(!evidence.canRetryAudio)
    val result = VoiceAlarmConversationGate.decide(prompt.single(), evidence.sources, evidence.mixed,
      final = true, reliable = true, armed = true, localCommand = false, passive = false,
      spokenPlayback = evidence.spokenPlayback, playbackOverlap = evidence.playbackOverlap)
    check(result.route == VoiceAlarmConversationGate.Route.ECHO)
  }
  scenario("an idle iFlytek socket is distinguished from a missing utterance final") {
    val stream = VoiceAlarmIflytekTranscript()
    check(stream.outcome(false, 0, 0, null, speechExpected = false) == "idle_no_words")
    check(stream.outcome(false, 0, 92160, null, speechExpected = false) == "idle_no_words")
    check(stream.outcome(false, 3200, 3200, null) == "missing_final")
    check(stream.outcome(false, 0, 0, "open_failed", speechExpected = false) == "open_failed")
  }
  scenario("successive music-only empty iFlytek turns get one quiet raw microphone retry") {
    val recovery = VoiceAlarmIflytekInputRecovery()
    check(recovery.observe(emptyWithPlayback = true, digitalSilence = false, alreadyQuiet = false) == null)
    recovery.recognizedSpeech()
    check(recovery.observe(emptyWithPlayback = true, digitalSilence = false, alreadyQuiet = false) == null)
    check(recovery.observe(emptyWithPlayback = true, digitalSilence = false, alreadyQuiet = false) ==
      VoiceAlarmIflytekInputRecovery.Action.QUIET_RETRY)
    check(recovery.useRawMic)
    repeat(5) { check(recovery.observe(emptyWithPlayback = true, digitalSilence = true, alreadyQuiet = false) == null) }
  }
  scenario("PCM frames effectively at zero can reopen an already-quiet microphone without rearming the alarm") {
    val recovery = VoiceAlarmIflytekInputRecovery()
    check(!VoiceAlarmIflytekInputRecovery.hasDigitalSilence(38399L, 0))
    check(!VoiceAlarmIflytekInputRecovery.hasDigitalSilence(38400L, 3))
    check(VoiceAlarmIflytekInputRecovery.hasDigitalSilence(38400L, 2))
    check(recovery.observe(emptyWithPlayback = false, digitalSilence = true, alreadyQuiet = true) ==
      VoiceAlarmIflytekInputRecovery.Action.REOPEN_QUIET_INPUT)
    check(recovery.useRawMic)
  }
  scenario("iFlytek keeps regular packet timing and catches up a queued microphone without a burst") {
    val audio = VoiceAlarmIflytekAudio()
    audio.write(ByteArray(167040))
    check(audio.nextSendAt(0L, 92160, 100L) == 130L)
    check(audio.nextSendAt(130L, 93440, 142L) == 162L)
    check(audio.nextSendAt(162L, 160000, 166L) == 202L)
  }
  scenario("a second cloud failure switches the microphone to system recognition for this alarm") {
    val recovery = VoiceAlarmCloudRecovery()
    check(!recovery.failed())
    recovery.success()
    check(!recovery.failed())
    check(recovery.failed() && recovery.useSystem)
    recovery.success()
    check(recovery.useSystem)
    check(VoiceAlarmCloudRecovery().failed(attempts = 2))
  }
  scenario("active cloud dictation can finish after idle expiry with a bounded recovery deadline") {
    val listening = VoiceAlarmListenWindow(18000L)
    listening.open(1000L)
    listening.ready(2000L)
    check(listening.expiresAt == 20000L)
    check(listening.mayFinishCloudTurn(40000L))
    check(!listening.mayFinishCloudTurn(131000L))
  }
  scenario("system network recovery keeps a quiet turn open after a late ready callback but remains bounded") {
    val listening = VoiceAlarmListenWindow(12000L)
    listening.open(0L)
    listening.ready(150L)
    listening.recovering(11500L, 100L)
    val oldExpiry = listening.expiresAt
    listening.reconnecting(oldExpiry - 600L, 400L)
    val readyAfterReconnect = oldExpiry - 300L
    listening.ready(readyAfterReconnect)
    check(listening.expiresAt - readyAfterReconnect >= 8000L)
    listening.reconnecting(38000L, 3200L)
    listening.ready(38500L)
    check(listening.expiresAt == 39000L)
    listening.reconnecting(39000L, 3200L)
    check(listening.expiresAt == 39000L)

    val automatic = VoiceAlarmListenWindow(6000L, connectingMs = 5000L, reconnectBudgetMs = 8000L)
    automatic.open(0L)
    automatic.ready(200L)
    automatic.reconnecting(5600L, 400L)
    automatic.ready(6150L)
    check(automatic.expiresAt == 14150L)
    automatic.reconnecting(13800L, 800L)
    automatic.ready(14700L)
    check(automatic.expiresAt == 19000L)
  }
  scenario("network timeout selects local once then falls back if Chinese is unavailable") {
    val policy = VoiceAlarmNativeRecovery()
    val network = VoiceAlarmNativeRecovery.Failure.NETWORK
    check(policy.failed(network, true)!!.replaceEngine && policy.onDevice)
    check(policy.failed(VoiceAlarmNativeRecovery.Failure.LANGUAGE, true)!!.replaceEngine && !policy.onDevice)
    check(!policy.failed(network, true)!!.replaceEngine && !policy.onDevice)
  }
  scenario("installed Chinese prefers offline on the default engine and timeout can still try dedicated local") {
    val policy = VoiceAlarmNativeRecovery()
    val network = VoiceAlarmNativeRecovery.Failure.NETWORK
    check(!policy.preferOffline && !policy.onDevice)
    policy.preferInstalledChinese()
    check(policy.preferOffline && !policy.onDevice)
    repeat(4) { check(!policy.failed(VoiceAlarmNativeRecovery.Failure.NO_MATCH, true)!!.replaceEngine) }
    check(policy.preferOffline && !policy.onDevice)
    check(policy.failed(network, true)!!.replaceEngine)
    check(policy.onDevice && !policy.preferOffline)
    check(policy.failed(network, true)!!.replaceEngine)
    check(!policy.onDevice && !policy.preferOffline)
    policy.preferInstalledChinese()
    check(!policy.preferOffline)
  }
  scenario("empty no-match rearms fast while persistent network failure has a bounded retry delay") {
    val policy = VoiceAlarmNativeRecovery()
    val network = VoiceAlarmNativeRecovery.Failure.NETWORK
    val delays = (1..6).map { policy.failed(network, false)!!.delayMs }
    check(delays == listOf(400L, 800L, 1600L, 3200L, 3200L, 3200L))
    check(policy.failed(VoiceAlarmNativeRecovery.Failure.NO_MATCH, true)!!.delayMs == 100L)
    check(!policy.onDevice)
    policy.success()
    check(policy.failed(network, false)!!.delayMs == 400L)
    check(policy.failed(VoiceAlarmNativeRecovery.Failure.PERMISSION, true) == null)
  }
  scenario("alternating native timeout and no-match during music can open a quiet follow-up") {
    val policy = VoiceAlarmNativeRecovery()
    val network = VoiceAlarmNativeRecovery.Failure.NETWORK
    val miss = VoiceAlarmNativeRecovery.Failure.NO_MATCH
    val music = VoiceAlarmConversationGate.PlaybackOverlap.MUSIC
    check(!policy.canRetryQuietAfter(network, music, requested = false))
    check(!policy.canRetryQuietAfter(network, null, requested = true))
    check(policy.canRetryQuietAfter(network, music, requested = true))
    check(policy.canRetryQuietAfter(miss, music, requested = true))
    check(!policy.retryInQuiet(VoiceAlarmNativeRecovery.Interference.MUSIC, 5000L))
    check(policy.retryInQuiet(VoiceAlarmNativeRecovery.Interference.MUSIC, 10000L))
  }
  scenario("early vendor speechBegin cannot invent a human onset or hold the microphone for a minute") {
    val signal = VoiceAlarmNativeSignal()
    val turn = VoiceAlarmNativeTurn()
    turn.begin()
    if (signal.began(ready = false)) turn.speechStarted()
    check(signal.onlyEarlyBegin && !turn.hasSpeech)
    turn.ready()
    check(turn.timeoutMs(20000) == 18000L)
    check(!signal.sample(3f, true) && signal.sample(3f, true))
    check(signal.detected && !signal.onlyEarlyBegin && signal.rmsCallbacks == 2 && signal.peakDb == 3f)
    check(!signal.sample(Float.NaN, true))
  }
  scenario("empty idle turns do not change engines, repeated intentional misses do") {
    val policy = VoiceAlarmNativeRecovery()
    val miss = VoiceAlarmNativeRecovery.Failure.NO_MATCH
    repeat(8) { check(!policy.failed(miss, true)!!.replaceEngine) }
    check(!policy.failed(miss, true, expectedSpeech = true)!!.replaceEngine)
    check(policy.failed(miss, true, expectedSpeech = true)!!.replaceEngine && policy.onDevice)
    policy.failed(miss, true, expectedSpeech = true)
    check(policy.failed(miss, true, expectedSpeech = true)!!.replaceEngine && !policy.onDevice)
  }
  scenario("a recognizer ignoring the offline preference cannot trap idle listening in an empty offline trial") {
    val policy = VoiceAlarmNativeRecovery()
    policy.failed(VoiceAlarmNativeRecovery.Failure.NETWORK, false, allowDefaultOffline = true)
    check(policy.preferOffline)
    repeat(2) { policy.failed(VoiceAlarmNativeRecovery.Failure.NO_MATCH, false) }
    check(!policy.preferOffline && !policy.onDevice)
    policy.failed(VoiceAlarmNativeRecovery.Failure.NETWORK, false, allowDefaultOffline = true)
    check(!policy.preferOffline)
  }
  scenario("161 through 167 recover without silently forcing an unavailable offline engine") {
    val policy = VoiceAlarmNativeRecovery()
    val miss = VoiceAlarmNativeRecovery.Failure.NO_MATCH
    val net = VoiceAlarmNativeRecovery.Failure.NETWORK
    check(policy.failed(miss, false)!!.delayMs == 100L)
    check(policy.failed(net, false, allowDefaultOffline = true) != null && policy.preferOffline)
    policy.success()
    repeat(3) { check(policy.failed(miss, false) != null) }
    check(policy.failed(net, false, allowDefaultOffline = true)!!.replaceEngine && !policy.preferOffline)
    check(!policy.failed(net, false, allowDefaultOffline = true)!!.replaceEngine && !policy.preferOffline)
  }
  scenario("follow-up time starts when ready, survives a long sentence, and ends after silence") {
    val window = VoiceAlarmListenWindow(12000)
    window.open(1000)
    window.ready(6000)
    check(window.expiresAt == 18000L)
    window.ready(10000)
    check(window.expiresAt == 18000L)
    window.activity(17000)
    check(window.expiresAt == 25000L)
    window.activity(75000)
    check(window.expiresAt == 76000L)
  }
  scenario("ending a quiet utterance near the deadline leaves one bounded chance for the final result") {
    val window = VoiceAlarmListenWindow(18000L)
    window.open(1000)
    window.awaitingFinal(12500)
    check(window.expiresAt == 13000L)
    window.ready(6000)
    check(window.expiresAt == 24000L)
    window.awaitingFinal(10000)
    check(window.expiresAt == 24000L)
    window.awaitingFinal(23750)
    check(window.expiresAt == 27250L)
    window.awaitingFinal(27000)
    check(window.expiresAt == 27250L)
  }
  scenario("two native no-match retries leave the next result in the same conversation window") {
    val window = VoiceAlarmListenWindow(12000L)
    window.open(0)
    window.ready(110)
    window.recovering(4500, 100)
    check(window.expiresAt == 12110L)
    window.recovering(9250, 180)
    check(window.expiresAt == 15430L && window.expiresAt > 13000L)
    window.recovering(14600, 180)
    check(window.expiresAt == 15430L)
  }
  scenario("a native retry accepts its final after a quiet recording without RMS callbacks") {
    val mix = VoiceAlarmMusicState()
    val owner = Any()
    val listening = VoiceAlarmMusicState.Speaker.LISTEN_REQUEST
    val quiet = VoiceAlarmMusicState.Speaker.QUIET_CAPTURE
    val text = "帮我起床"
    fun route(evidence: VoiceAlarmCapture.Evidence, armed: Boolean) =
      VoiceAlarmConversationGate.decide(text, evidence.sources, evidence.mixed, final = true,
        reliable = true, armed = armed, localCommand = false, passive = !armed).route

    val first = VoiceAlarmCapture(6, true, "music", 1).finish(6, true, "music")
    check(route(first, armed = false) == VoiceAlarmConversationGate.Route.RELISTEN)
    mix.setSpeaking(listening, owner, true)
    check(mix.gain(.4f) == .4f)
    mix.setSpeaking(quiet, owner, true)
    check(mix.gain(.4f) == 0f)

    val native = VoiceAlarmNativeTurn()
    val signal = VoiceAlarmNativeSignal()
    check(native.begin() && !signal.began(native.ready))
    native.ready()
    val retry = VoiceAlarmCapture(8, false, "quiet", 2)
    check(!native.hasSpeech && signal.earlyBegin && signal.rmsCallbacks == 0)
    check(native.finish(text) == text)
    check(route(retry.finish(8, false), armed = true) == VoiceAlarmConversationGate.Route.SEND)
    mix.setSpeaking(quiet, owner, false)
    check(mix.gain(.4f) == .4f)
  }
  scenario("music returning at native speech end cannot change the saved capture evidence") {
    val capture = VoiceAlarmCapture(10, false, "quiet", 3)
    check(!capture.finish(10, false).hasPlaybackOverlap)
    check(!capture.finish(11, true, "music").hasPlaybackOverlap)
    val interrupted = VoiceAlarmCapture(10, false, "quiet", 4)
    check(interrupted.finish(11, true, "music").hasPlaybackOverlap)
  }
  scenario("a silent system recognizer with no levels is replaced sooner without cutting off observed speech") {
    val turn = VoiceAlarmNativeTurn()
    check(turn.begin())
    turn.ready()
    check(turn.timeoutMs(22000L, hasLevelCallbacks = false) == 10000L)
    check(turn.timeoutMs(22000L, hasLevelCallbacks = true) == 18000L)
    turn.partial("已经确认的起床问题")
    check(turn.timeoutMs(22000L, hasLevelCallbacks = false) >= 27000L)
  }
  scenario("native end-of-speech cannot prematurely begin another recognition") {
    val turn = VoiceAlarmNativeTurn(); check(turn.begin()); turn.ready(); turn.speechStarted()
    turn.partial("请关闭背景"); turn.endSpeech(); check(!turn.begin() && turn.active && turn.awaitingFinal)
    check(turn.finish("请关闭背景音乐") == "请关闭背景音乐"); check(!turn.hasSpeech)
    check(turn.begin() && !turn.hasSpeech)
  }
  scenario("empty final/error retains partial and duplicate callback is ignored") {
    val turn = VoiceAlarmNativeTurn(); turn.begin(); turn.partial("明天的计划")
    check(turn.finish("") == "明天的计划"); check(turn.finish() == null)
    turn.begin(); turn.partial("不能带到下次"); turn.cancel(); turn.begin(); check(turn.finish() == "")
  }
  scenario("a new noise onset cannot hold the previous finalized user sentence") {
    val turn = VoiceAlarmNativeTurn()
    turn.begin(); turn.ready(); turn.speechStarted()
    check(!turn.shouldWaitForFinal(true))
    check(turn.shouldWaitForFinal(false))
    turn.partial("上海周末下雨吗")
    check(turn.shouldWaitForFinal(true))
    turn.finish()
    check(!turn.shouldWaitForFinal(true))
  }
  scenario("lost final can recover an existing draft without cutting off live speech") {
    val turn = VoiceAlarmNativeTurn()
    turn.begin(); turn.ready(); turn.partial("虚构的完整问题")
    check(turn.timeoutMs(20000) >= 65000)
    turn.endSpeech()
    check(turn.timeoutMs(20000) == 2500L)
    check(turn.finish() == "虚构的完整问题")
    check(turn.finish("迟到的最终结果") == null)
    check(VoiceAlarmNativeTurn.bestCandidate(listOf("", " 首个可用结果 ", "另一个")) == "首个可用结果")
  }
  scenario("native endpoint retains a stable draft and resets stability on a correction") {
    val turn = VoiceAlarmNativeTurn()
    check(turn.begin())
    turn.ready()
    turn.partial("今天要做什么", 100)
    turn.partial("今天要做什么准备", 230)
    check(!turn.hasStableEndpointDraft)
    turn.endSpeech()
    check(turn.hasStableEndpointDraft)
    turn.partial("明天要做什么", 280)
    check(!turn.hasStableEndpointDraft)
    check(turn.finish() == "明天要做什么")
    check(turn.begin() && !turn.hasStableEndpointDraft)
  }
  scenario("iFlytek distinguishes an idle connection from missing PCM or empty recognition of speech") {
    val empty = VoiceAlarmIflytekTranscript()
    check(empty.outcome(false, 0, 0, "open_failed", microphoneTimedOut = true) == "open_failed")
    check(empty.outcome(false, 0, 0, null, microphoneTimedOut = true) == "microphone_no_frames")
    empty.accept("""{"code":0,"data":{"status":2}}""")
    check(empty.outcome(false, 0, 0, null) == "empty_final")
    check(empty.outcome(false, 32000, 32000, null, quietSpeech = true) == "empty_final_with_speech")
    check(empty.outcome(false, 32000, 32000, null) == "empty_final")
  }
  scenario("a delayed native final uses only speech overlapping this capture") {
    val turn = VoiceAlarmNativeTurn()
    val prompt = listOf("愿你专注、充满力量。")
    check(turn.begin())
    turn.notePlayback(prompt)
    check(turn.playbackSources == prompt) // Some engines never report speech-start.
    turn.endSpeech()
    turn.notePlayback(listOf("另一条提醒"))
    val final = turn.finish("专注充满力量")!!
    check(turn.playbackSources == prompt)
    check(VoiceAlarmSpeechPolicy.isEcho(final, turn.playbackSources, true))
    check(turn.begin() && turn.playbackSources.isEmpty()) // User may now quote the reminder.
  }
  scenario("consecutive empty music turns open a bounded quiet retry without treating early begin as speech") {
    val policy = VoiceAlarmNativeRecovery()
    val music = VoiceAlarmNativeRecovery.Interference.MUSIC
    check(!policy.retryInQuiet(music, 5000L))
    check(policy.retryInQuiet(music, 10000L))
    check(!policy.retryInQuiet(null, 16000L))
    check(!policy.retryInQuiet(music, 21000L))
    check(!policy.retryInQuiet(music, 26000L))
    check(policy.retryInQuiet(music, 35000L))
    check(!policy.retryInQuiet(music, 65000L))

    val quiet = VoiceAlarmListenWindow(idleMs = 6000L, connectingMs = 5000L)
    quiet.open(10000L)
    check(quiet.expiresAt == 15000L)
    quiet.ready(12000L)
    check(quiet.expiresAt == 18000L)
  }
  scenario("a spoken echo following a reminder miss triggers a quiet turn without trusting the early begin") {
    val policy = VoiceAlarmNativeRecovery()
    val music = VoiceAlarmNativeRecovery.Interference.MUSIC
    val reminder = VoiceAlarmNativeRecovery.Interference.REMINDER
    check(!policy.retryInQuiet(music, 5000L))
    check(!policy.retryInQuiet(reminder, 9500L))
    policy.success() // An echo shows that the engine returned text, but is unusable as user speech.
    check(policy.retryInQuiet(reminder, 14000L))
    check(!policy.retryInQuiet(reminder, 28000L))
    check(!policy.retryInQuiet(null, 32000L))
    check(!policy.retryInQuiet(reminder, 40000L))
    check(policy.retryInQuiet(reminder, 44500L))
  }
  scenario("two empty quiet turns can recover a silent recognizer and return to default if offline remains empty") {
    val policy = VoiceAlarmNativeRecovery()
    val miss = VoiceAlarmNativeRecovery.Failure.NO_MATCH
    check(!policy.failed(miss, true, recoverEmptyQuietTurn = true)!!.replaceEngine)
    check(policy.failed(miss, true, recoverEmptyQuietTurn = true)!!.replaceEngine && policy.onDevice)
    check(!policy.failed(miss, true, recoverEmptyQuietTurn = true)!!.replaceEngine)
    check(policy.failed(miss, true, recoverEmptyQuietTurn = true)!!.replaceEngine && !policy.onDevice)
    check(!policy.failed(miss, true)!!.replaceEngine && !policy.onDevice)
  }
  scenario("first Wakeup body is exact and bypasses generation") {
    val s = VoiceAlarmWakeSession("固定朗读。"); val original = "  当日正式提醒。\n先坐起。  "
    val p = s.prepare(listOf("虚构目标"), original) { error("First round must not generate") }
    check(p.motivation == original && p.source == "ai_wakeup")
    val round = s.accept(p.motivation, listOf("虚构目标"), p.source)
    check(round.body == "固定朗读。\n\n你最近设定的目标或待办：虚构目标。\n\n$original")
  }
  scenario("subsequent round has original and failure context and changes strategy") {
    val s = VoiceAlarmWakeSession("固定内容")
    val first = s.accept("首轮测试", listOf("虚构计划"), "ai_wakeup"); s.markPlayback("完整播报完成")
    val next = s.prepare(listOf("更新计划"), "不可再次用作首轮") { messages ->
      val user = JSONObject(messages.getJSONObject(1).getString("content"))
      check(user.getInt("round") == 2 && user.getJSONArray("recentUserGoals").getString(0) == "更新计划")
      val previous = user.getJSONArray("previousAttempts").getJSONObject(0)
      check(previous.getString("motivation") == first.motivation)
      check(previous.getString("feedback").contains("推定仍未起床"))
      check(user.getString("suggestedStrategy") != first.strategy)
      "换个动作：坐到床边。"
    }
    check(next.source == "ai" && next.motivation != first.motivation)
  }
  scenario("no Wakeup invokes configured model; absent goals never fabricated") {
    val s = VoiceAlarmWakeSession("早上好"); var calls = 0
    val p = s.prepare(emptyList(), null) { calls++; "测试生成" }
    check(calls == 1 && s.accept(p.motivation, emptyList(), p.source).body == "早上好\n\n测试生成")
  }
  scenario("repeated model output retries once then fails honestly") {
    val s = VoiceAlarmWakeSession(""); s.accept("相同正文", emptyList(), "ai")
    var calls = 0; rejects { s.prepare(emptyList(), null) { calls++; "相同正文" } }; check(calls == 2)
  }
  scenario("closing rejects late generation and no later acceptance") {
    val s = VoiceAlarmWakeSession("")
    rejects { s.prepare(emptyList(), null) { s.close(); "迟到回复" } }
    rejects { s.accept("迟到回复", emptyList(), "ai") }
  }
  scenario("interrupted rounds are not described as fully heard") {
    val s = VoiceAlarmWakeSession(""); s.accept("测试", emptyList(), "ai"); s.markPlayback("用户插话中断，未保证听完")
    check(s.messages(emptyList()).toString().contains("用户插话中断"))
  }
  scenario("long session retains first text and evidence from every attempt") {
    val s = VoiceAlarmWakeSession(""); repeat(40) { s.accept("虚构提醒$it".repeat(50), emptyList(), "ai") }
    val past = JSONObject(s.messages(emptyList()).getJSONObject(1).getString("content")).getJSONArray("previousAttempts")
    check(past.length() == 40 && !past.getJSONObject(0).getBoolean("isExcerpt"))
    check(past.getJSONObject(1).getBoolean("isExcerpt") && !past.getJSONObject(39).getBoolean("isExcerpt"))
  }
  fun cfg(endpoint: String, model: String = "custom-deployment") = JSONObject().put("provider", "azure").put("endpoint", endpoint).put("model", model).put("apiKey", "fictional")
  scenario("Azure legacy and Foundry inference routes use same-origin v1") {
    for (e in listOf("https://fictional.openai.azure.com/openai/deployments/custom/chat/completions?api-version=2024-10-21", "https://fictional.services.ai.azure.com/models/chat/completions?api-version=2024-05-01-preview")) {
      val p = VoiceAlarmWebSearch.plan(cfg(e), JSONArray(), true)
      check(p.error == null && p.enabled && p.endpoint.endsWith("/openai/v1/responses") && !p.endpoint.contains("api-version"))
      check(p.body.getString("model") == "custom-deployment")
    }
  }
  scenario("no model-name whitelist rejects non-OpenAI Foundry deployments") {
    val p = VoiceAlarmWebSearch.plan(cfg("https://fictional.services.ai.azure.com/openai/v1/chat/completions", "custom-deepseek"), JSONArray(), true)
    check(p.error == null && p.body.getString("model") == "custom-deepseek")
  }
  scenario("optional Azure search model never changes origin or leaks Anthropic headers") {
    val c = cfg("https://fictional.services.ai.azure.com/anthropic/v1/messages", "claude-test")
      .put("searchDeployment", "gpt-search-test").put("authHeaders", JSONObject().put("x-api-key", "fictional").put("anthropic-version", "2023-06-01"))
    val search = VoiceAlarmAiClient.searchConfiguration(c)
    check(search.getString("model") == "gpt-search-test" && !search.has("searchDeployment"))
    check(search.getString("endpoint") == "https://fictional.services.ai.azure.com/openai/v1/responses")
    check(search.getJSONObject("authHeaders").getString("api-key") == "fictional" && !search.getJSONObject("authHeaders").has("x-api-key"))
    rejects { VoiceAlarmAiClient.searchConfiguration(c.put("endpoint", "https://evil.example/anthropic/v1/messages")) }
  }
  scenario("Foundry Claude messages and output retain actual text") {
    val c = cfg("https://fictional.services.ai.azure.com/anthropic/v1/messages", "claude-test")
    val p = VoiceAlarmWebSearch.plan(c, JSONArray("""[{"role":"system","content":"规则"},{"role":"user","content":"你好"}]"""), false)
    check(p.body.getString("system") == "规则" && p.body.getJSONArray("messages").length() == 1 && p.body.getInt("max_tokens") > 0)
    check(VoiceAlarmAiClient.responseText(JSONObject("""{"content":[{"type":"text","text":"完整回答"}]}""")) == "完整回答")
  }
  scenario("Bing connection requires project route") {
    val c = cfg("https://fictional.services.ai.azure.com/openai/v1/responses").put("bingConnectionId", "fictional-connection")
    check(VoiceAlarmWebSearch.plan(c, JSONArray(), true).error != null)
    c.put("endpoint", "https://fictional.services.ai.azure.com/api/projects/test/openai/v1/responses")
    val p = VoiceAlarmWebSearch.plan(c, JSONArray(), true)
    check(p.error == null && p.body.getJSONArray("tools").getJSONObject(0).getString("type") == "bing_grounding")
  }
  scenario("HTTP request preserves messages, authentication and full response") {
    val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
    server.createContext("/chat/completions") { e ->
      check(e.requestHeaders.getFirst("Authorization") == "Bearer fictional")
      val body = JSONObject(e.requestBody.reader().readText()); check(body.getJSONArray("messages").getJSONObject(0).getString("content") == "虚构完整请求")
      val bytes = JSONObject().put("choices", JSONArray().put(JSONObject().put("message", JSONObject().put("content", "完整测试回答")))).toString().toByteArray()
      e.sendResponseHeaders(200, bytes.size.toLong()); e.responseBody.use { it.write(bytes) }
    }; server.start()
    try {
      val c = JSONObject().put("provider", "openai").put("endpoint", "http://127.0.0.1:${server.address.port}/chat/completions").put("model", "fictional").put("apiKey", "fictional")
      val answer = VoiceAlarmAiClient().request(c, JSONArray().put(JSONObject().put("role", "user").put("content", "虚构完整请求")), false)
      check(answer.text == "完整测试回答" && answer.webStatus == "联网已关闭")
      val cancelled = VoiceAlarmAiClient(); cancelled.cancel(); rejects { cancelled.request(c, JSONArray(), false) }
    } finally { server.stop(0) }
  }
  scenario("Foundry other-model search runs retrieval then grounded answer over HTTP") {
    val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
    var searchCalls = 0; var answerCalls = 0
    server.createContext("/openai/v1/responses") { e ->
      searchCalls++
      val body = JSONObject(e.requestBody.reader().readText())
      check(body.getString("model") == "search-test" && body.has("tools"))
      check(e.requestHeaders.getFirst("api-key") == "fictional" && e.requestHeaders.getFirst("x-api-key") == null)
      val bytes = """{"output":[{"type":"message","content":[{"type":"output_text","text":"虚构检索资料","annotations":[{"type":"url_citation","url":"https://example.org/fictional"}]}]}]}""".toByteArray()
      e.sendResponseHeaders(200, bytes.size.toLong()); e.responseBody.use { it.write(bytes) }
    }
    server.createContext("/anthropic/v1/messages") { e ->
      answerCalls++
      val body = JSONObject(e.requestBody.reader().readText())
      check(body.getString("model") == "claude-test" && !body.has("tools") && body.toString().contains("https://example.org/fictional"))
      check(e.requestHeaders.getFirst("x-api-key") == "fictional")
      val bytes = """{"content":[{"type":"text","text":"基于检索资料的虚构回答"}]}""".toByteArray()
      e.sendResponseHeaders(200, bytes.size.toLong()); e.responseBody.use { it.write(bytes) }
    }
    server.start()
    try {
      val c = cfg("https://fictional.services.ai.azure.com/anthropic/v1/messages", "claude-test")
        .put("searchDeployment", "search-test").put("authHeaders", JSONObject().put("x-api-key", "fictional"))
      val client = VoiceAlarmAiClient { url ->
        check(url.host == "fictional.services.ai.azure.com")
        java.net.URL("http://127.0.0.1:${server.address.port}${url.path}").openConnection() as java.net.HttpURLConnection
      }
      val result = client.request(c, JSONArray().put(JSONObject().put("role", "user").put("content", "虚构实时问题")), true)
      check(searchCalls == 1 && answerCalls == 1 && result.sources == listOf("https://example.org/fictional"))
      check(result.text == "基于检索资料的虚构回答" && result.webStatus.contains("已通过"))
    } finally { server.stop(0) }
  }
  println("$passed adaptive alarm regression scenarios passed")
}
