package com.example.quote_app.interactiveimage

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class InteractiveImageChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private companion object {
        const val PICK_IMAGE = 61203
        const val MAX_BYTES = 25L * 1024 * 1024
        const val MAX_DETECTION_SIDE = 1280
        const val MODEL_VERSION = "MediaPipe Tasks 0.10.32 / Pose Lite, Face, Hand float16 v1"
    }

    private class ImageTooLarge : IOException()
    private class Run(val id: String) {
        val cancelled = AtomicBoolean()
    }

    private val context = activity.applicationContext
    private val picker = PickVisualMedia()
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "com.example.quote_app/interactive_image")
    private val importCache = File(context.cacheDir, "interactive_image_import")
    private var pickReply: MethodChannel.Result? = null
    private var run: Run? = null
    private var closed = false

    init {
        channel.setMethodCallHandler { call, reply ->
            when (call.method) {
                "pickImage" -> pickImage(reply)
                "clearImportCache" -> worker.execute {
                    val cleared = importCache.deleteRecursively()
                    main.post {
                        if (cleared) reply.success(null) else reply.error("cache_cleanup_failed", null, null)
                    }
                }
                "recognize" -> recognize(call.argument("path"), call.argument("id"), reply)
                "cancelRecognition" -> {
                    run?.takeIf { it.id == call.argument<String>("id") }?.cancelled?.set(true)
                    reply.success(null)
                }
                else -> reply.notImplemented()
            }
        }
        worker.execute { importCache.deleteRecursively() }
    }

    @Suppress("DEPRECATION")
    private fun pickImage(reply: MethodChannel.Result) {
        if (pickReply != null) {
            reply.error("busy", null, null)
            return
        }
        try {
            val request = PickVisualMediaRequest(PickVisualMedia.ImageOnly)
            val intent = picker.createIntent(activity, request).putExtra(Intent.EXTRA_LOCAL_ONLY, true)
            pickReply = reply
            activity.startActivityForResult(intent, PICK_IMAGE)
        } catch (_: Exception) {
            pickReply = null
            reply.error("picker_unavailable", null, null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_IMAGE) return false
        val reply = pickReply ?: return true
        val uri = picker.parseResult(resultCode, data)
        if (uri == null) {
            pickReply = null
            reply.success(null)
            return true
        }
        worker.execute {
            try {
                val image = copySelection(uri)
                main.post {
                    pickReply = null
                    if (closed) image.first.delete()
                    else reply.success(mapOf("path" to image.first.path, "name" to image.second))
                }
            } catch (_: ImageTooLarge) {
                finishPickError(reply, "image_too_large")
            } catch (_: Exception) {
                finishPickError(reply, "image_read_failed")
            }
        }
        return true
    }

    private fun finishPickError(reply: MethodChannel.Result, code: String) {
        main.post {
            pickReply = null
            if (!closed) reply.error(code, null, null)
        }
    }

    private fun copySelection(uri: Uri): Pair<File, String> {
        val resolver = context.contentResolver
        val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
            ?: "未命名作品"
        importCache.mkdirs()
        val copy = File.createTempFile("selected-", ".image", importCache)
        try {
            val source = resolver.openInputStream(uri) ?: throw IOException()
            source.use { input ->
                copy.outputStream().use { output ->
                    val buffer = ByteArray(65536)
                    var size = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        size += count
                        if (size > MAX_BYTES) throw ImageTooLarge()
                        output.write(buffer, 0, count)
                    }
                }
            }
            return copy to name
        } catch (error: Exception) {
            copy.delete()
            throw error
        }
    }

    private fun recognize(path: String?, id: String?, reply: MethodChannel.Result) {
        if (path == null || id == null) {
            reply.error("invalid_image", null, null)
            return
        }
        if (run?.cancelled?.get() == false) {
            reply.error("busy", null, null)
            return
        }
        val request = Run(id)
        run = request
        worker.execute {
            try {
                val result = analyze(path, request)
                finishRun(request) {
                    if (request.cancelled.get()) reply.error("cancelled", null, null)
                    else reply.success(result)
                }
            } catch (_: OutOfMemoryError) {
                finishRun(request) { reply.error("low_memory", null, null) }
            } catch (_: LinkageError) {
                finishRun(request) { reply.error("model_unavailable", null, null) }
            } catch (_: Exception) {
                finishRun(request) { reply.error("model_failed", null, null) }
            }
        }
    }

    private fun finishRun(request: Run, complete: () -> Unit) {
        main.post {
            if (run === request) run = null
            if (!closed) complete()
        }
    }

    private fun analyze(path: String, request: Run): Map<String, Any?>? {
        if (request.cancelled.get()) return null
        val file = File(path).canonicalFile
        val storage = File(context.filesDir, "interactive_image_v1").canonicalFile
        require(file.name == "preview.png" && file.parentFile?.parentFile == storage)
        val bitmap = decodePreview(file)
        try {
            val image = BitmapImageBuilder(bitmap).build()
            try {
                val failures = mutableListOf<String>()
                val pose = detect("pose", request, failures) { poses(image) }
                val face = detect("face", request, failures) { faces(image) }
                val hand = detect("hand", request, failures) { hands(image) }
                if (request.cancelled.get()) return null
                check(failures.size < 3)
                return mapOf(
                    "model" to MODEL_VERSION,
                    "pose" to pose,
                    "face" to face,
                    "hand" to hand,
                    "unavailable" to failures,
                )
            } finally {
                image.close()
            }
        } finally {
            bitmap.recycle()
        }
    }

    private fun decodePreview(file: File): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0)
        val scale = minOf(1f, MAX_DETECTION_SIDE.toFloat() / maxOf(bounds.outWidth, bounds.outHeight))
        val bitmap = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }) ?: throw IOException()
        if (scale == 1f) return bitmap
        return try {
            Bitmap.createScaledBitmap(
                bitmap, (bitmap.width * scale).toInt().coerceAtLeast(1),
                (bitmap.height * scale).toInt().coerceAtLeast(1), true,
            )
        } finally {
            bitmap.recycle()
        }
    }

    private fun <T> detect(name: String, request: Run, failures: MutableList<String>, infer: () -> List<T>): List<T> {
        if (request.cancelled.get()) return emptyList()
        return try {
            infer()
        } catch (_: RuntimeException) {
            failures.add(name)
            emptyList()
        }
    }

    private fun model(asset: String) = BaseOptions.builder()
        .setModelAssetPath("interactive_image/$asset.task")
        .build()

    private fun poses(image: MPImage) = PoseLandmarker.createFromOptions(
        context, PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(model("pose_landmarker_lite"))
            .setNumPoses(5)
            .build(),
    ).use { detector -> detector.detect(image).landmarks().map { it.map(::point) } }

    private fun faces(image: MPImage) = FaceLandmarker.createFromOptions(
        context, FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(model("face_landmarker"))
            .setNumFaces(5)
            .build(),
    ).use { detector -> detector.detect(image).faceLandmarks().map { it.map(::point) } }

    private fun hands(image: MPImage) = HandLandmarker.createFromOptions(
        context, HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(model("hand_landmarker"))
            .setNumHands(10)
            .build(),
    ).use { detector -> detector.detect(image).landmarks().map { it.map(::point) } }

    private fun point(point: NormalizedLandmark): List<Double?> = listOf(
        point.x().toDouble(), point.y().toDouble(), point.z().toDouble(),
        point.visibility().map { it.toDouble() }.orElse(null),
        point.presence().map { it.toDouble() }.orElse(null),
    )

    fun dispose() {
        closed = true
        run?.cancelled?.set(true)
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
