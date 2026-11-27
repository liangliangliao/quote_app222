package com.example.quote_app

import java.io.IOException
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONException
import org.json.JSONObject

internal class VoiceAlarmMicrosoftSpeech {
  private val client = OkHttpClient.Builder()
    .retryOnConnectionFailure(false)
    .followRedirects(false)
    .build()

  fun recognize(endpoint: String, key: String, wav: ByteArray, timeoutMs: Long): String {
    val request = Request.Builder()
      .url(endpoint)
      .header("Ocp-Apim-Subscription-Key", key)
      .header("Accept", "application/json")
      .header("Content-Type", "audio/wav; codecs=audio/pcm; samplerate=16000")
      .post(wav.toRequestBody())
      .build()
    val call = client.newCall(request)
    call.timeout().timeout(timeoutMs, TimeUnit.MILLISECONDS)
    val result = call.execute().use { response ->
      if (!response.isSuccessful) throw IOException("Microsoft Speech HTTP ${response.code}")
      try {
        JSONObject(response.body?.string().orEmpty())
      } catch (error: JSONException) {
        throw IOException("Invalid Microsoft Speech response", error)
      }
    }
    val status = result.optString("RecognitionStatus", result.optString("status", ""))
    if (status in setOf("NoMatch", "InitialSilenceTimeout", "BabbleTimeout")) return ""
    if (status.isNotBlank() && status != "Success") throw IOException("Microsoft Speech recognition status: $status")
    val best = result.optJSONArray("NBest")?.optJSONObject(0)
    val text = sequenceOf(result.optString("DisplayText"), best?.optString("Display"),
      best?.optString("Lexical"), best?.optString("ITN")).firstOrNull { !it.isNullOrBlank() }?.trim().orEmpty()
    if (status.isBlank() && text.isBlank()) throw IOException("Missing Microsoft Speech recognition status")
    return text
  }
}
