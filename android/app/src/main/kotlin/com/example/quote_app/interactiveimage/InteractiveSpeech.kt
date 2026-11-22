package com.example.quote_app.interactiveimage

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

internal class InteractiveSpeech(private val context: Context, private val emit: (Map<String, Any>) -> Unit) {
    private val main = Handler(Looper.getMainLooper())
    private var session: SpeechRecognizer? = null
    private var allowSystem = false
    private var onDevice = false
    private var busyRetries = 0

    fun start(allowSystemSpeech: Boolean): String? {
        stop()
        allowSystem = allowSystemSpeech
        val local = Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        if (!local && !allowSystem) return "offline_unavailable"
        return startSession(local)
    }

    private fun startSession(offline: Boolean): String? {
        onDevice = offline
        busyRetries = 0
        if (!offline && !SpeechRecognizer.isRecognitionAvailable(context)) return "speech_unavailable"
        val speech = try {
            if (offline && Build.VERSION.SDK_INT >= 31) SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            else SpeechRecognizer.createSpeechRecognizer(context)
        } catch (_: RuntimeException) {
            return "speech_unavailable"
        }
        session = speech
        speech.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                if (session === speech) emit(mapOf("kind" to "ready"))
            }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
            override fun onResults(results: Bundle?) {
                if (session !== speech) return
                val words = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()
                if (words.isNotEmpty()) emit(mapOf("kind" to "result", "words" to words))
                busyRetries = 0
                retry(speech, 280)
            }
            override fun onError(error: Int) {
                if (session !== speech) return
                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                        busyRetries = 0
                        retry(speech, 320)
                    }
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> {
                        if (++busyRetries <= 2) retry(speech, 800) else fail("speech_busy")
                    }
                    SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED, SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> {
                        if (onDevice && allowSystem) {
                            stop()
                            startSession(false)?.let(::fail)
                        } else fail("language_unavailable")
                    }
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> fail("microphone_denied")
                    else -> fail("speech_unavailable")
                }
            }
        })
        return if (listen(speech)) null else {
            stop()
            "speech_unavailable"
        }
    }

    private fun listen(speech: SpeechRecognizer): Boolean = try {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 4)
        speech.startListening(intent)
        true
    } catch (_: RuntimeException) {
        false
    }

    private fun retry(speech: SpeechRecognizer, delay: Long) {
        main.postDelayed({ if (session === speech && !listen(speech)) fail("speech_unavailable") }, delay)
    }

    private fun fail(code: String) {
        stop()
        emit(mapOf("kind" to "error", "code" to code))
    }

    fun stop() {
        val previous = session
        session = null
        previous?.cancel()
        previous?.destroy()
    }
}
