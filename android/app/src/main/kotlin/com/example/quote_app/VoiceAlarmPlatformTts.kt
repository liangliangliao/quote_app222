package com.example.quote_app

import android.speech.tts.TextToSpeech
import android.speech.tts.Voice
import java.util.Locale

internal fun TextToSpeech.selectAlarmChineseVoice(): Int {
  val offlineVoice = runCatching {
    voices.orEmpty().filter {
      it.locale.language == Locale.CHINESE.language && !it.isNetworkConnectionRequired &&
        TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED !in it.features.orEmpty()
    }.maxWithOrNull(compareBy<Voice> { it.locale.country == Locale.CHINA.country }.thenBy { it.quality })
  }.getOrNull()
  if (offlineVoice != null && runCatching { setVoice(offlineVoice) }.getOrNull() == TextToSpeech.SUCCESS) {
    return TextToSpeech.LANG_AVAILABLE
  }
  return runCatching { setLanguage(Locale.CHINA) }.getOrDefault(TextToSpeech.ERROR)
}
