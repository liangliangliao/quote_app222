package com.example.quote_app.interactiveimage

import android.app.Activity
import android.app.Dialog
import android.graphics.Color
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.VideoView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

internal class InteractiveMediaPlayback(private val activity: Activity) {
    private var reply: MethodChannel.Result? = null
    private var audio: MediaPlayer? = null
    private var video: VideoView? = null
    private var dialog: Dialog? = null
    private var speech: TextToSpeech? = null
    private val main = Handler(Looper.getMainLooper())

    fun playSystemSound(value: String?, result: MethodChannel.Result) {
        val type = when (value) {
            "notification" -> RingtoneManager.TYPE_NOTIFICATION
            "ringtone" -> RingtoneManager.TYPE_RINGTONE
            "alarm" -> RingtoneManager.TYPE_ALARM
            else -> { result.error("invalid_media", null, null); return }
        }
        playAudio(result) { it.setDataSource(activity, RingtoneManager.getDefaultUri(type)) }
    }

    fun speak(value: String?, result: MethodChannel.Result) {
        val text = value?.takeIf { it.isNotBlank() && it.length <= 300 }
        if (text == null) {
            result.error("invalid_media", null, null)
            return
        }
        stop()
        reply = result
        try {
            speech = TextToSpeech(activity) { status ->
                main.post {
                    val engine = speech
                    if (reply !== result || engine == null) return@post
                    try {
                        val locale = Locale.getDefault()
                        val voice = if (status == TextToSpeech.SUCCESS) engine.voices.orEmpty()
                            .filter { !it.isNetworkConnectionRequired && it.locale.language == locale.language }
                            .maxByOrNull { if (it.locale == locale) 10_000 + it.quality else it.quality }
                            else null
                        if (voice == null || engine.setVoice(voice) != TextToSpeech.SUCCESS) {
                            finish(completed = false, errorCode = "tts_unavailable")
                            return@post
                        }
                        engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                            override fun onStart(utteranceId: String?) {}
                            override fun onDone(utteranceId: String?) {
                                main.post { if (reply === result) finish(completed = true) }
                            }
                            @Deprecated("Required by Android TextToSpeech")
                            override fun onError(utteranceId: String?) {
                                main.post { if (reply === result) finish(completed = false, errorCode = "tts_unavailable") }
                            }
                        })
                        if (engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "interactive-feedback") != TextToSpeech.SUCCESS) {
                            finish(completed = false, errorCode = "tts_unavailable")
                        }
                    } catch (_: RuntimeException) {
                        finish(completed = false, errorCode = "tts_unavailable")
                    }
                }
            }
        } catch (_: RuntimeException) {
            finish(completed = false, errorCode = "tts_unavailable")
        }
    }

    fun playFile(file: File, isVideo: Boolean, muted: Boolean, result: MethodChannel.Result) {
        if (isVideo) playVideo(file, muted, result)
        else playAudio(result) { player -> file.inputStream().use { player.setDataSource(it.fd) } }
    }

    private fun playAudio(result: MethodChannel.Result, source: (MediaPlayer) -> Unit) {
        stop()
        reply = result
        try {
            val player = MediaPlayer()
            audio = player
            player.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            source(player)
            player.setOnPreparedListener { if (audio === player) player.start() }
            player.setOnCompletionListener { if (audio === player) finish(completed = true) }
            player.setOnErrorListener { _, _, _ ->
                if (audio === player) finish(completed = false, errorCode = "media_play_failed")
                true
            }
            player.prepareAsync()
        } catch (_: Exception) {
            finish(completed = false, errorCode = "media_play_failed")
        }
    }

    private fun playVideo(file: File, muted: Boolean, result: MethodChannel.Result) {
        stop()
        reply = result
        try {
            val player = VideoView(activity)
            video = player
            val container = FrameLayout(activity).apply { setBackgroundColor(Color.BLACK) }
            val modal = Dialog(activity, android.R.style.Theme_Material_NoActionBar_Fullscreen)
            dialog = modal
            container.addView(player, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT, Gravity.CENTER,
            ))
            val buttonSize = (48 * activity.resources.displayMetrics.density).toInt()
            val margin = (12 * activity.resources.displayMetrics.density).toInt()
            val close = ImageButton(activity).apply {
                setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
                contentDescription = "关闭视频"
                setBackgroundColor(0xAA202020.toInt())
                setOnClickListener { finish(completed = false) }
            }
            container.addView(close, FrameLayout.LayoutParams(buttonSize, buttonSize, Gravity.TOP or Gravity.END).apply {
                setMargins(margin, margin, margin, margin)
            })
            modal.setContentView(container)
            modal.setOnDismissListener { if (dialog === modal) finish(completed = false) }
            player.setOnPreparedListener { prepared ->
                if (video === player) {
                    if (muted) prepared.setVolume(0f, 0f)
                    player.start()
                }
            }
            player.setOnCompletionListener { if (video === player) finish(completed = true) }
            player.setOnErrorListener { _, _, _ ->
                if (video === player) finish(completed = false, errorCode = "media_play_failed")
                true
            }
            modal.show()
            modal.window?.let { window ->
                WindowCompat.getInsetsController(window, window.decorView).apply {
                    systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                    hide(WindowInsetsCompat.Type.systemBars())
                }
            }
            player.setVideoPath(file.path)
        } catch (_: Exception) {
            finish(completed = false, errorCode = "media_play_failed")
        }
    }

    private fun finish(completed: Boolean, errorCode: String? = null) {
        val result = reply ?: return
        reply = null
        val player = audio
        audio = null
        player?.release()
        val view = video
        video = null
        view?.stopPlayback()
        val modal = dialog
        dialog = null
        modal?.dismiss()
        val tts = speech
        speech = null
        tts?.stop()
        tts?.shutdown()
        if (errorCode != null) result.error(errorCode, null, null) else result.success(completed)
    }

    fun stop() = finish(completed = false)
}
