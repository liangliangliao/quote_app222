package com.example.quote_app

import java.io.IOException
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/** Keep draining the microphone while a socket connects or waits for a final result. */
class VoiceAlarmPcmPump(
  private val readSource: (ByteArray) -> Int,
  capacityFrames: Int = 750, // bounded 15 seconds, never silently overwrite a user's words
  private val stamp: (() -> VoiceAlarmFrameStamp)? = null,
) {
  companion object { const val NEXT_WINDOW = -2 }
  private data class Frame(val pcm: ByteArray, val before: VoiceAlarmFrameStamp?, val after: VoiceAlarmFrameStamp?)
  private val frames = LinkedBlockingQueue<Frame>(capacityFrames)
  private var pending: Frame? = null
  @Volatile private var active = true
  @Volatile private var failure: IOException? = null
  private val worker = Thread {
    try {
      while (active) {
        val frame = ByteArray(VoiceAlarmSpeechPolicy.FRAME_BYTES)
        val before = stamp?.invoke()
        val count = readSource(frame)
        val after = stamp?.invoke()
        if (!active) break
        if (count < 0) throw IOException("麦克风读取失败（$count），请检查麦克风占用或权限")
        if (count == 0) { Thread.sleep(10); continue }
        if (!frames.offer(Frame(if (count == frame.size) frame else frame.copyOf(count), before, after))) {
          throw IOException("语音服务响应过慢，录音缓冲已满；请稍后重试刚才的话")
        }
      }
    } catch (t: Throwable) {
      if (active) failure = if (t is IOException) t else IOException("麦克风采集失败", t)
    }
  }.apply { name = "voice-alarm-pcm"; isDaemon = true; start() }

  @Synchronized fun read(target: ByteArray, capture: VoiceAlarmCapture? = null): Int {
    failure?.let { throw it }
    if (!active) return -1
    val frame = pending ?: frames.poll(250, TimeUnit.MILLISECONDS) ?: return 0
    pending = null
    val before = frame.before
    val after = frame.after
    if (capture != null && before != null && after != null) {
      if (before.windowId != after.windowId) return 0
      if (after.windowId != capture.windowId) {
        // Preserve the first frame of a newer live turn for its consumer.
        if (after.windowId == stamp?.invoke()?.windowId) {
          pending = frame
          return NEXT_WINDOW
        }
        return 0
      }
      capture.noteFrame(before, after)
    }
    require(target.size >= frame.pcm.size)
    frame.pcm.copyInto(target)
    return frame.pcm.size
  }

  fun close() { active = false; frames.clear(); worker.interrupt() }
}
