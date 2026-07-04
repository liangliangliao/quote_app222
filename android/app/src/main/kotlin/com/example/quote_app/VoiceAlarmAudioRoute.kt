package com.example.quote_app

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build

/**
 * Shared headset-detection helpers for the voice alarm feature.
 *
 * Android's alarm/notification ("sonification") audio strategy intentionally plays through
 * the speaker in addition to any connected headset, so an alarm cannot be silently missed.
 * That is undesirable here: when the user is wearing a headset we want alarm voice + background
 * music to stay private to the headset, and when the headset also has a mic we want the AI
 * conversation to capture from it instead of the phone's built-in mic/speaker loop. Both call
 * sites use these helpers to find the actual connected device and hand it to
 * MediaPlayer/AudioRecord.setPreferredDevice(...), which overrides the default dual-routing.
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
    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> 3
    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> 4
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
