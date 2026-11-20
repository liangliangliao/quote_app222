package com.example.quote_app

import java.io.ByteArrayOutputStream
import java.util.ArrayDeque

/** PCM16 mono 16kHz: retain onset/pauses; endpoint on audio time, not network time. */
class VoiceAlarmTurnBuffer(private val silenceMs: Long, private val maxMs: Long) {
  private val preRoll = ArrayDeque<ByteArray>()
  private var preBytes = 0
  private val out = ByteArrayOutputStream()
  private val onset = VoiceAlarmSpeechPolicy.StartWindow()
  private var quietBytes = 0
  var started = false; private set
  val size: Int get() = if (started) out.size() else preBytes
  val durationMs: Long get() = size * 1000L / 32000
  fun add(frame: ByteArray, voiced: Boolean): Boolean {
    if (!started) {
      preRoll.addLast(frame.copyOf()); preBytes += frame.size
      while (preBytes > 19200 && preRoll.size > 1) preBytes -= preRoll.removeFirst().size
      if (!onset.accept(voiced)) return false
      started = true
      preRoll.forEach { out.write(it) }; preRoll.clear(); preBytes = 0
    } else out.write(frame)
    quietBytes = if (voiced) 0 else quietBytes + frame.size
    return quietBytes * 1000L / 32000 >= silenceMs || durationMs >= maxMs
  }
  fun audio(manual: Boolean = false): ByteArray = if (started) out.toByteArray()
    else if (manual) ByteArrayOutputStream().also { stream -> preRoll.forEach { stream.write(it) } }.toByteArray()
    else ByteArray(0)
}
