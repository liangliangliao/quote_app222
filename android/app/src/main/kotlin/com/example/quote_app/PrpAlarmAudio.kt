package com.example.quote_app

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import java.io.File

/** One local player shared by the service and both alarm views. No network/TTS. */
object PrpAlarmAudio {
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var app: Context? = null
    private var hint: PrpAlarmBridge.Hint? = null
    private var automatic = false
    private var started = false
    private var deadline = 0L
    private var owner: Any? = null
    private var before: (() -> Unit)? = null
    private var after: (() -> Unit)? = null
    val isPlaying: Boolean get() = try { player?.isPlaying == true } catch (_: Throwable) { false }
    private val tick = object: Runnable {
        override fun run() {
            if (player == null) return
            if (SystemClock.elapsedRealtime() >= deadline || !gate()) { stop(); return }
            handler.postDelayed(this, 250)
        }
    }
    fun attach(owner: Any, before: () -> Unit, after: () -> Unit) {
        this.owner = owner; this.before = before; this.after = after
    }
    fun detach(owner: Any) { if (this.owner === owner) { this.owner=null; before=null; after=null } }
    private fun gate(): Boolean {
        val context = app ?: return false
        val value = hint ?: return false
        return PrpAlarmBridge.stillAllowed(context, value, voice=true, automatic=automatic)
    }
    fun refreshGate() { if (player != null && !gate()) stop() }
    fun validClip(context: Context, path: String): Boolean = try {
        val root=File(context.applicationInfo.dataDir,"app_flutter/prp_voice").canonicalPath+File.separator
        val file=File(path).canonicalFile
        if (!file.isFile || !file.path.startsWith(root) || file.extension.lowercase() !in listOf("m4a","wav")) false
        else {
            val reader=MediaMetadataRetriever()
            try { reader.setDataSource(file.path)
                val duration=reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                duration in 1..15500
            } finally { reader.release() }
        }
    } catch (_: Throwable) { false }
    fun play(context: Context, value: PrpAlarmBridge.Hint, auto: Boolean = false): Boolean {
        if (!PrpAlarmBridge.stillAllowed(context, value, voice=true, automatic=auto)) return false
        val root = File(context.applicationInfo.dataDir,"app_flutter/prp_voice")
        val file = try { File(value.voicePath).canonicalFile } catch (_: Throwable) { return false }
        if (!file.isFile || !file.path.startsWith(root.canonicalPath+File.separator) ||
            file.extension.lowercase() !in listOf("m4a","wav")) return false
        stop()
        app=context.applicationContext; hint=value; automatic=auto
        deadline=SystemClock.elapsedRealtime()+15000
        return try {
            val media=MediaPlayer()
            player=media
            media.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            media.setDataSource(file.path)
            val volume=BehaviorPresetAlarmSettings.getVolume(context).coerceIn(0f,1f)
            media.setVolume(volume,volume)
            media.setOnPreparedListener {
                if (player !== media) return@setOnPreparedListener
                if (!gate() || media.duration > 15500 || media.duration <= 0) { stop(); return@setOnPreparedListener }
                try { before?.invoke(); started=true; media.start() } catch (_: Throwable) { stop() }
            }
            media.setOnCompletionListener { if (player === media) stop() }
            media.setOnErrorListener { _,_,_ -> if (player === media) stop(); true }
            media.prepareAsync()
            handler.postDelayed(tick,250)
            true
        } catch (_: Throwable) { stop(); false }
    }
    fun stop() {
        handler.removeCallbacks(tick)
        val previous=player; player=null
        try { previous?.stop() } catch (_: Throwable) {}
        try { previous?.release() } catch (_: Throwable) {}
        val restore=started; started=false; app=null; hint=null
        if (restore) try { after?.invoke() } catch (_: Throwable) {}
    }
}
