package com.example.quote_app.interactiveimage

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.view.WindowManager
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors

class InteractiveFeedbackChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private companion object {
        const val PICK_MEDIA = 61204
        const val CHATGPT = "com.openai.chatgpt"
        val ARTWORK_ID = Regex("[a-f0-9]{32}")
        val MEDIA_NAME = Regex("[a-f0-9]{32}\\.(audio|video)")
    }

    private data class Pick(val reply: MethodChannel.Result, val folder: File, val kind: String, val gallery: Boolean)
    private class MediaTooLarge : IOException()
    private class InvalidMedia : IOException()

    private val context = activity.applicationContext
    private val channel = MethodChannel(messenger, "com.example.quote_app/interactive_feedback")
    private val voiceEvents = EventChannel(messenger, "com.example.quote_app/interactive_feedback/voice")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val media = InteractiveMediaPlayback(activity)
    private var voiceSink: EventChannel.EventSink? = null
    private val voice = InteractiveSpeech(context) { event -> voiceSink?.success(event) }
    private val picker = PickVisualMedia()
    private var pick: Pick? = null
    private var ownsScreenOnFlag = false
    private var closed = false

    init {
        voiceEvents.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { voiceSink = events }
            override fun onCancel(arguments: Any?) { voiceSink = null; voice.stop() }
        })
        channel.setMethodCallHandler { call, reply ->
            try {
                when (call.method) {
                    "apps" -> reply.success(installedApps().map { mapOf("name" to it.first, "package" to it.second) })
                    "openApp" -> openApp(call.argument("name"), call.argument("package"), reply)
                    "openLink" -> openLink(call.arguments as? String, reply)
                    "pickMedia" -> pickMedia(call.argument("artworkId"), call.argument("kind"), call.argument<Boolean>("gallery") == true, reply)
                    "playMedia" -> {
                        val kind = call.argument<String>("kind")
                        val value = call.argument<String>("value")
                        when (kind) {
                            "systemSound" -> media.playSystemSound(value, reply)
                            "speak" -> media.speak(value, reply)
                            "audio", "video" -> {
                                val file = mediaFile(call.argument("artworkId"), value, kind)
                                media.playFile(file, kind == "video", call.argument<Boolean>("muted") == true, reply)
                            }
                            else -> reply.error("invalid_media", null, null)
                        }
                    }
                    "stopMedia" -> { media.stop(); reply.success(null) }
                    "startVoice" -> {
                        val error = voice.start(call.arguments == true)
                        if (error == null) reply.success(null) else reply.error(error, null, null)
                    }
                    "stopVoice" -> { voice.stop(); reply.success(null) }
                    "setHoldScreenOn" -> { setHoldScreenOn(call.arguments == true); reply.success(null) }
                    "setImmersive" -> { immersive(call.arguments == true); reply.success(null) }
                    else -> reply.notImplemented()
                }
            } catch (_: Exception) {
                reply.error("action_unavailable", null, null)
            }
        }
    }

    private fun installedApps(): List<Pair<String, String>> {
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val manager = activity.packageManager
        return manager.queryIntentActivities(launcher, 0)
            .asSequence()
            .filterNot { it.activityInfo.packageName == activity.packageName }
            .map { it.loadLabel(manager).toString() to it.activityInfo.packageName }
            .distinctBy { it.second }
            .sortedBy { it.first.lowercase(Locale.ROOT) }
            .toList()
    }

    private fun openApp(name: String?, packageName: String?, reply: MethodChannel.Result) {
        val installed = installedApps()
        val selected = installed.firstOrNull { it.second == packageName }
        val matches = if (selected != null) listOf(selected) else installed.filter { it.first.equals(name?.trim(), ignoreCase = true) }
        if (matches.size != 1) {
            reply.error(if (matches.isEmpty()) "app_missing" else "app_ambiguous", null, null)
            return
        }
        val launch = activity.packageManager.getLaunchIntentForPackage(matches.single().second)
        if (launch != null && startActivity(launch)) reply.success(null)
        else reply.error("app_missing", null, null)
    }

    private fun openLink(url: String?, reply: MethodChannel.Result) {
        val uri = url?.let(Uri::parse)
        if (uri == null || uri.scheme !in setOf("http", "https") || uri.host.isNullOrEmpty() || uri.userInfo != null) {
            reply.error("invalid_link", null, null)
            return
        }
        fun view(target: Uri) = Intent(Intent.ACTION_VIEW, target).addCategory(Intent.CATEGORY_BROWSABLE)
        if (uri.host?.lowercase(Locale.ROOT) in setOf("chatgpt.com", "www.chatgpt.com")) {
            val chatgpt = view(uri).setPackage(CHATGPT)
            if (chatgpt.resolveActivity(activity.packageManager) != null && startActivity(chatgpt)) {
                reply.success(null)
                return
            }
        }
        val manager = activity.packageManager
        // Resolve handlers for an ordinary web address so link-specific apps do not take the browser fallback.
        val probe = view(Uri.parse("https://example.com/"))
        fun handlers(intent: Intent) = manager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            .map { it.activityInfo.packageName }.toSet()
        val genericHandlers = handlers(probe).intersect(handlers(view(Uri.parse("https://example.org/"))))
        val browserCategory = handlers(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_BROWSER))
        val browsers = genericHandlers + browserCategory
        val defaultBrowser = probe.resolveActivity(manager)?.packageName
        val targets = browsers.map { view(uri).setPackage(it) }.filter { it.resolveActivity(manager) != null }
        val preferred = targets.firstOrNull { it.`package` == defaultBrowser }
        val intent = preferred ?: when (targets.size) {
            0 -> null
            1 -> targets.first()
            else -> Intent.createChooser(targets.first(), "选择浏览器").putExtra(Intent.EXTRA_INITIAL_INTENTS, targets.drop(1).toTypedArray())
        }
        if (intent != null && startActivity(intent)) reply.success(null)
        else reply.error("browser_missing", null, null)
    }

    private fun startActivity(intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: android.content.ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }

    private fun artworkFolder(artworkId: String?): File {
        require(artworkId != null && ARTWORK_ID.matches(artworkId))
        val root = File(context.filesDir, "interactive_image_v1").canonicalFile
        val folder = File(root, artworkId).canonicalFile
        require(folder.parentFile == root && folder.isDirectory)
        return folder
    }

    private fun mediaFile(artworkId: String?, value: String?, kind: String): File {
        require(value != null && MEDIA_NAME.matches(value) && value.endsWith(".$kind"))
        val folder = artworkFolder(artworkId)
        val mediaRoot = File(folder, "media").canonicalFile
        val file = File(mediaRoot, value).canonicalFile
        require(mediaRoot.parentFile == folder && file.parentFile == mediaRoot && file.isFile)
        return file
    }

    @Suppress("DEPRECATION")
    private fun pickMedia(artworkId: String?, kind: String?, gallery: Boolean, reply: MethodChannel.Result) {
        if (pick != null || kind !in setOf("audio", "video")) {
            reply.error("picker_unavailable", null, null)
            return
        }
        val useGallery = gallery && kind == "video"
        val folder = artworkFolder(artworkId)
        val intent = if (useGallery) {
            picker.createIntent(activity, PickVisualMediaRequest(PickVisualMedia.VideoOnly))
        } else {
            Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("$kind/*")
        }.putExtra(Intent.EXTRA_LOCAL_ONLY, true)
        pick = Pick(reply, folder, kind!!, useGallery)
        try {
            activity.startActivityForResult(intent, PICK_MEDIA)
        } catch (_: Exception) {
            pick = null
            reply.error("picker_unavailable", null, null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_MEDIA) return false
        val pending = pick ?: return true
        val uri = if (pending.gallery) picker.parseResult(resultCode, data)
            else data?.data?.takeIf { resultCode == Activity.RESULT_OK }
        if (uri == null) {
            pick = null
            pending.reply.success(null)
            return true
        }
        worker.execute {
            val result = runCatching { importMedia(pending, uri) }
            main.post {
                pick = null
                if (closed) {
                    result.getOrNull()?.first?.delete()
                } else {
                    result.fold(
                        onSuccess = { (file, name) -> pending.reply.success(mapOf("file" to file.name, "name" to name)) },
                        onFailure = { error -> pending.reply.error(when (error) {
                            is MediaTooLarge -> "media_too_large"
                            is InvalidMedia -> "invalid_media"
                            else -> "media_read_failed"
                        }, null, null) },
                    )
                }
            }
        }
        return true
    }

    private fun importMedia(pending: Pick, uri: Uri): Pair<File, String> {
        val resolver = context.contentResolver
        val label = runCatching {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) it.getString(0) else null
            }
        }.getOrNull()?.take(120) ?: if (pending.kind == "video") "视频" else "音频"
        val mediaRoot = File(pending.folder, "media").canonicalFile
        require(mediaRoot.parentFile == pending.folder)
        mediaRoot.mkdirs()
        val staging = File.createTempFile(".media-", ".tmp", mediaRoot)
        val limit = (if (pending.kind == "video") 150L else 30L) * 1024 * 1024
        try {
            val input = resolver.openInputStream(uri) ?: throw IOException()
            input.use { source ->
                staging.outputStream().use { target ->
                    val buffer = ByteArray(65536)
                    var length = 0L
                    while (true) {
                        val count = source.read(buffer)
                        if (count < 0) break
                        length += count
                        if (length > limit) throw MediaTooLarge()
                        target.write(buffer, 0, count)
                    }
                    target.fd.sync()
                }
            }
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(staging.path)
                val key = if (pending.kind == "video") MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO
                    else MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO
                if (retriever.extractMetadata(key) != "yes") throw InvalidMedia()
            } catch (_: RuntimeException) {
                throw InvalidMedia()
            } finally {
                retriever.release()
            }
            val name = UUID.randomUUID().toString().replace("-", "") + ".${pending.kind}"
            val target = File(mediaRoot, name)
            if (!staging.renameTo(target)) throw IOException()
            return target to label
        } finally {
            staging.delete()
        }
    }

    fun onPause() {
        voice.stop()
        setHoldScreenOn(false)
    }

    private fun setHoldScreenOn(enabled: Boolean) {
        val flag = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        val window = activity.window
        if (enabled && (window.attributes.flags and flag) == 0) {
            window.addFlags(flag)
            ownsScreenOnFlag = true
        } else if (!enabled && ownsScreenOnFlag) {
            window.clearFlags(flag)
            ownsScreenOnFlag = false
        }
    }

    private fun immersive(enabled: Boolean) {
        val controller = WindowCompat.getInsetsController(activity.window, activity.window.decorView)
        if (enabled) {
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller.hide(WindowInsetsCompat.Type.systemBars())
        } else controller.show(WindowInsetsCompat.Type.systemBars())
    }

    fun dispose() {
        closed = true
        onPause()
        media.stop()
        voiceEvents.setStreamHandler(null)
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
