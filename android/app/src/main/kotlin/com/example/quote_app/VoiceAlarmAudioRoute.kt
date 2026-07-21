package com.example.quote_app

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build

/**
 * Shared headset-detection helpers for the voice alarm feature.
 *
 * IMPORTANT: AudioAttributes.USAGE_ALARM (mapped to STREAM_ALARM) is deliberately
 * "enforced audible" by the Android audio policy: the platform always adds the speaker
 * to the output device set for that strategy, in addition to any connected headset, so an
 * alarm can never be silently missed. This is done at the native audio policy layer and is
 * NOT overridden by AudioTrack/MediaPlayer/AudioRecord.setPreferredDevice() - that call is
 * a no-op for the alarm strategy. The only way to get headset-exclusive routing is to stop
 * using USAGE_ALARM while a headset is connected and use a normal, non-enforced usage
 * (USAGE_MEDIA) instead, which is naturally routed only to the connected wired/USB/Bluetooth
 * device by the platform's default output selection - the same behavior every media app gets
 * automatically when headphones are plugged in. See VoiceAlarmRingingService, which switches
 * the voice/music players' AudioAttributes usage based on hasHeadsetOutput() and only relies
 * on setPreferredDevice() as an extra hint for picking among multiple connected devices.
 */
object VoiceAlarmAudioRoute {
  private fun audioManager(context: Context): AudioManager? =
    try { context.applicationContext.getSystemService(Context.AUDIO_SERVICE) as? AudioManager } catch (_: Throwable) { null }

  private fun isHeadsetOutputType(type: Int): Boolean = when (type) {
    AudioDeviceInfo.TYPE_WIRED_HEADSET,
    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
    AudioDeviceInfo.TYPE_USB_HEADSET,
    -> true
    else -> Build.VERSION.SDK_INT >= 31 && type == AudioDeviceInfo.TYPE_BLE_HEADSET
  }

  /** Devices that also expose a microphone usable for a two-way conversation. */
  private fun isMicCapableType(type: Int): Boolean = when (type) {
    AudioDeviceInfo.TYPE_WIRED_HEADSET,
    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
    AudioDeviceInfo.TYPE_USB_HEADSET,
    -> true
    else -> Build.VERSION.SDK_INT >= 31 && type == AudioDeviceInfo.TYPE_BLE_HEADSET
  }

  private fun outputPriority(type: Int): Int = when (type) {
    AudioDeviceInfo.TYPE_WIRED_HEADSET -> 0
    AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> 1
    AudioDeviceInfo.TYPE_USB_HEADSET -> 2
    // 播放优先走 A2DP（高品质、正常音量），而不是 SCO（电话通道，单声道、音量小）。
    // 之前把 SCO 排在 A2DP 前面，蓝牙耳机时播报/音乐被路由到 SCO，声音很小。
    // SCO 只应给麦克风采集用（见 preferredInputDevice，仅在 mic-capable 里选择，不受此影响）。
    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> 3
    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> 4
    else -> 5
  }

  /** The best headset output device to route alarm voice/music to, or null if none connected. */
  fun preferredOutputDevice(context: Context): AudioDeviceInfo? {
    val manager = audioManager(context) ?: return null
    return try {
      manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        .filter { isHeadsetOutputType(it.type) }
        .minByOrNull { outputPriority(it.type) }
    } catch (_: Throwable) {
      null
    }
  }

  fun hasHeadsetOutput(context: Context): Boolean = preferredOutputDevice(context) != null

  /** The best mic-capable headset input device for recording, or null if none connected. */
  fun preferredInputDevice(context: Context): AudioDeviceInfo? {
    val manager = audioManager(context) ?: return null
    return try {
      manager.getDevices(AudioManager.GET_DEVICES_INPUTS)
        .filter { isMicCapableType(it.type) }
        .minByOrNull { outputPriority(it.type) }
    } catch (_: Throwable) {
      null
    }
  }

  fun isBluetoothScoType(type: Int): Boolean = type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
}
