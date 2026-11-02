package com.example.quote_app

import java.io.IOException
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/** Keep draining the microphone while a socket connects or waits for a final result. */
class VoiceAlarmPcmPump(
  private val readSource: (ByteArray) -> Int,
  capacityFrames: Int = 750, // bounded 15 seconds, never silently overwrite a user's words
) {
  private val frames = LinkedBlockingQueue<ByteArray>(capacityFrames)
  @Volatile private var active = true
  @Volatile private var failure: IOException? = null
  private val worker = Thread {
    try {
      while (active) {
        val frame = ByteArray(VoiceAlarmSpeechPolicy.FRAME_BYTES)
        val count = readSource(frame)
        if (!active) break
        if (count < 0) throw IOException("麦克风读取失败（$count），请检查麦克风占用或权限")
        if (count == 0) { Thread.sleep(10); continue }
        if (!frames.offer(frame.copyOf(count))) {
          throw IOException("语音服务响应过慢，录音缓冲已满；请稍后重试刚才的话")
        }
      }
    } catch (t: Throwable) {
      if (active) failure = if (t is IOException) t else IOException("麦克风采集失败", t)
    }
  }.apply { name = "voice-alarm-pcm"; isDaemon = true; start() }

  fun read(target: ByteArray): Int {
    failure?.let { throw it }
    if (!active) return -1
    val frame = frames.poll(250, TimeUnit.MILLISECONDS) ?: return 0
    require(target.size >= frame.size)
    frame.copyInto(target)
    return frame.size
  }

  fun clear() = frames.clear()
  fun close() { active = false; frames.clear(); worker.interrupt() }
}
