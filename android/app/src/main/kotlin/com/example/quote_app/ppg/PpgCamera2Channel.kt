package com.example.quote_app.ppg

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.Image
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Range
import android.util.Size
import android.view.Surface

import com.example.quote_app.data.DbRepo

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.view.TextureRegistry
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Camera2-based finger PPG sampler (optional preview surface).
 *
 * Why: Flutter camera imageStream is often capped to ~15-16fps on some Android 14 devices,
 * which hurts HRV (RMSSD) and overall stability. Camera2 allows us to request a stable FPS
 * range and keep the torch on reliably.
 *
 * This channel streams ROI mean values (Y/U/V + derived G/R) via EventChannel.
 */
class PpgCamera2Channel private constructor(
  private val ctx: Context,
  messenger: io.flutter.plugin.common.BinaryMessenger,
  private val textures: TextureRegistry?,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

  private val method = MethodChannel(messenger, METHOD_CH)
  private val events = EventChannel(messenger, EVENT_CH)

  @Volatile private var sink: EventChannel.EventSink? = null
  @Volatile private var engine: Engine? = null

  private val mainHandler = Handler(Looper.getMainLooper())

  init {
    method.setMethodCallHandler(this)
    events.setStreamHandler(this)
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
  }

  override fun onCancel(arguments: Any?) {
    sink = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "isSupported" -> {
        result.success(findBackCameraId(ctx) != null)
      }
      "start" -> {
        try {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
          val reqW = (args["width"] as? Number)?.toInt() ?: 640
          val reqH = (args["height"] as? Number)?.toInt() ?: 480
          val reqFps = (args["fps"] as? Number)?.toInt() ?: 30
          val torch = (args["torch"] as? Boolean) ?: true

          stopInternal()

          val e = Engine(
            ctx = ctx,
            textures = textures,
            send = { m ->
              try {
                val s = sink
                if (s != null) {
                  mainHandler.post {
                    try { s.success(m) } catch (_: Throwable) {}
                  }
                }
              } catch (_: Throwable) {
              }
            },
          )
          engine = e
          val cfg = e.start(reqW, reqH, reqFps, torch)
          result.success(cfg)
        } catch (t: Throwable) {
          DbRepo.log(ctx, null, "[PPG-C2] start failed: ${t.message}")
          stopInternal()
          result.error("START_FAILED", t.message, null)
        }
      }
      "stop" -> {
        stopInternal()
        result.success(true)
      }
      else -> result.notImplemented()
    }
  }

  private fun stopInternal() {
    try {
      engine?.stop()
    } catch (_: Throwable) {
    }
    engine = null
  }

  companion object {
    private const val METHOD_CH = "com.example.quote_app/ppg_camera2"
    private const val EVENT_CH = "com.example.quote_app/ppg_camera2_stream"

    fun register(flutterEngine: FlutterEngine, ctx: Context) {
      // Creating an instance registers handlers.
      PpgCamera2Channel(ctx.applicationContext, flutterEngine.dartExecutor.binaryMessenger, flutterEngine.renderer)
    }

    private fun findBackCameraId(ctx: Context): String? {
      val cm = ctx.getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return null
      return try {
        cm.cameraIdList.firstOrNull { id ->
          val ch = cm.getCameraCharacteristics(id)
          val facing = ch.get(CameraCharacteristics.LENS_FACING)
          facing == CameraCharacteristics.LENS_FACING_BACK
        }
      } catch (_: Throwable) {
        null
      }
    }
  }

  // -----------------
  // Internal engine
  // -----------------
  private class Engine(
    private val ctx: Context,
    private val textures: TextureRegistry?,
    private val send: (Map<String, Any?>) -> Unit,
  ) {
    private val cm: CameraManager = ctx.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private var cameraId: String? = null
    private var camera: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var reader: ImageReader? = null
    private var thread: HandlerThread? = null
    private var handler: Handler? = null

    // Optional Flutter texture preview
    private var previewEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private var previewTextureId: Long? = null

    private var targetRange: Range<Int>? = null
    private var torchEnabled: Boolean = true
    private var size: Size = Size(640, 480)

    // FPS estimation.
    // NOTE: For HRV we care about *sensor* timing stability. Use Image.timestamp
    // (nanoseconds, monotonic in sensor time base) rather than wall-clock, to
    // avoid inflating jitter due to thread scheduling / event delivery.
    private var fpsStartNs: Long = 0L
    private var fpsCount: Int = 0
    private var fpsValue: Double = 0.0
    private var startedWallMs: Long = 0L

    @SuppressLint("MissingPermission")
    fun start(reqW: Int, reqH: Int, reqFps: Int, torch: Boolean): Map<String, Any?> {
      torchEnabled = torch
      cameraId = findBackCameraId(ctx)
      if (cameraId == null) {
        throw IllegalStateException("No back camera")
      }

      // Pick best size close to requested.
      val ch = cm.getCameraCharacteristics(cameraId!!)
      val map = ch.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        ?: throw IllegalStateException("No stream map")
      val sizes = map.getOutputSizes(ImageFormat.YUV_420_888)?.toList() ?: emptyList()
      val chosen = chooseSize(sizes, reqW, reqH)
      size = chosen

      // Create preview texture (best-effort). If preview is not shown on Flutter side,
      // the camera still works normally.
      try {
        previewEntry?.release()
      } catch (_: Throwable) {}
      previewEntry = null
      try {
        val entry = textures?.createSurfaceTexture()
        if (entry != null) {
          entry.surfaceTexture().setDefaultBufferSize(size.width, size.height)
          previewEntry = entry
          previewTextureId = entry.id()
          previewSurface = Surface(entry.surfaceTexture())
        }
      } catch (_: Throwable) {
        previewEntry = null
        previewTextureId = null
        try { previewSurface?.release() } catch (_: Throwable) {}
        previewSurface = null
      }

      // Pick FPS range.
      val ranges = ch.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)?.toList()
        ?: emptyList()
      targetRange = chooseFpsRange(ranges, reqFps)

      thread = HandlerThread("ppg_cam2")
      thread!!.start()
      handler = Handler(thread!!.looper)

      reader = ImageReader.newInstance(size.width, size.height, ImageFormat.YUV_420_888, 2)
      reader!!.setOnImageAvailableListener({ r ->
        val img = try { r.acquireLatestImage() } catch (_: Throwable) { null }
        if (img != null) {
          try {
            onImage(img)
          } catch (_: Throwable) {
          } finally {
            try { img.close() } catch (_: Throwable) {}
          }
        }
      }, handler)

      // Use wall clock only for logging cadence; use sensor timestamps for measurement.
      startedWallMs = SystemClock.elapsedRealtime()
      fpsStartNs = 0L
      fpsCount = 0
      fpsValue = 0.0

      DbRepo.log(ctx, null, "[PPG-C2] start size=${size.width}x${size.height} fps=${targetRange?.lower}-${targetRange?.upper} torch=$torchEnabled")

      cm.openCamera(cameraId!!, object : CameraDevice.StateCallback() {
        override fun onOpened(device: CameraDevice) {
          camera = device
          createSession()
        }

        override fun onDisconnected(device: CameraDevice) {
          DbRepo.log(ctx, null, "[PPG-C2] camera disconnected")
          stop()
        }

        override fun onError(device: CameraDevice, error: Int) {
          DbRepo.log(ctx, null, "[PPG-C2] camera error=$error")
          stop()
        }
      }, handler)

      // Return immediately; session creation is async. Flutter will receive frames when ready.
      return mapOf(
        "width" to size.width,
        "height" to size.height,
        "fpsLower" to (targetRange?.lower ?: 0),
        "fpsUpper" to (targetRange?.upper ?: 0),
        "torch" to torchEnabled,
        "textureId" to previewTextureId,
      )
    }

    private fun createSession() {
      val device = camera ?: return
      val surface = reader?.surface ?: return
      val surfaces = mutableListOf(surface)
      previewSurface?.let { surfaces.add(it) }
      try {
        device.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
          override fun onConfigured(s: CameraCaptureSession) {
            session = s
            startRepeating(lockAe = false)
            // After a short delay, attempt to lock AE (best-effort).
            handler?.postDelayed({
              startRepeating(lockAe = true)
            }, 900)
          }

          override fun onConfigureFailed(s: CameraCaptureSession) {
            DbRepo.log(ctx, null, "[PPG-C2] configure failed")
          }
        }, handler)
      } catch (t: Throwable) {
        DbRepo.log(ctx, null, "[PPG-C2] createSession failed: ${t.message}")
      }
    }

    private fun startRepeating(lockAe: Boolean) {
      val device = camera ?: return
      val s = session ?: return
      val surface = reader?.surface ?: return
      try {
        val req = device.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
        req.addTarget(surface)
        previewSurface?.let { req.addTarget(it) }
        req.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
        req.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
        if (torchEnabled) {
          req.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_TORCH)
        } else {
          req.set(CaptureRequest.FLASH_MODE, CameraMetadata.FLASH_MODE_OFF)
        }
        targetRange?.let { req.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, it) }
        req.set(CaptureRequest.CONTROL_AE_LOCK, lockAe)
        // Prefer stable, fast processing.
        req.set(CaptureRequest.NOISE_REDUCTION_MODE, CameraMetadata.NOISE_REDUCTION_MODE_FAST)
        req.set(CaptureRequest.EDGE_MODE, CameraMetadata.EDGE_MODE_FAST)
        s.setRepeatingRequest(req.build(), null, handler)
      } catch (_: Throwable) {
      }
    }

    private fun onImage(img: Image) {
      // Use the sensor-provided timestamp for accurate timing.
      // https://developer.android.com/reference/android/media/Image#getTimestamp()
      val tsNs = img.timestamp
      val tsMs = tsNs / 1_000_000L

      // Update fps estimate using sensor time to avoid scheduler jitter.
      if (fpsStartNs == 0L) {
        fpsStartNs = tsNs
        fpsCount = 0
      }
      fpsCount += 1
      val dtNs = tsNs - fpsStartNs
      if (dtNs >= 900_000_000L) {
        fpsValue = fpsCount * 1_000_000_000.0 / dtNs.toDouble()
        fpsCount = 0
        fpsStartNs = tsNs
        // Log at most once per ~5s (wall clock based).
        val wallNow = SystemClock.elapsedRealtime()
        if ((wallNow - startedWallMs) % 5000L < 950L) {
          DbRepo.log(ctx, null, "[PPG-C2] fps=${"%.1f".format(fpsValue)}")
        }
      }

      // ROI mean on YUV planes.
      val w = img.width
      val h = img.height
      val x0 = (w * 0.35).toInt()
      val x1 = (w * 0.65).toInt()
      val y0 = (h * 0.35).toInt()
      val y1 = (h * 0.65).toInt()
      // Smaller sampling step improves SNR at the cost of some CPU.
      // ROI is already small, so step=2 is typically safe on modern devices.
      val step = 2

      val yMean = meanPlane(img.planes[0], w, h, x0, x1, y0, y1, step, isChroma = false)
      val uMean = meanPlane(img.planes[1], w / 2, h / 2, x0 / 2, x1 / 2, y0 / 2, y1 / 2, step, isChroma = true)
      val vMean = meanPlane(img.planes[2], w / 2, h / 2, x0 / 2, x1 / 2, y0 / 2, y1 / 2, step, isChroma = true)

      val u = uMean - 128.0
      val v = vMean - 128.0
      val r = clamp255(yMean + 1.402 * v)
      val g = clamp255(yMean - 0.344136 * u - 0.714136 * v)

      send(
        mapOf(
          "tsMs" to tsMs,
          "y" to (yMean / 255.0),
          "u" to (uMean / 255.0),
          "v" to (vMean / 255.0),
          "r" to (r / 255.0),
          "g" to (g / 255.0),
          "fps" to fpsValue,
          "torch" to torchEnabled,
          "w" to w,
          "h" to h,
        )
      )
    }

    private fun meanPlane(
      plane: Image.Plane,
      width: Int,
      height: Int,
      x0: Int,
      x1: Int,
      y0: Int,
      y1: Int,
      step: Int,
      isChroma: Boolean,
    ): Double {
      val buf = plane.buffer
      val rowStride = plane.rowStride
      val pixelStride = plane.pixelStride
      var sum = 0.0
      var cnt = 0
      val xx0 = x0.coerceIn(0, width - 1)
      val xx1 = x1.coerceIn(xx0 + 1, width)
      val yy0 = y0.coerceIn(0, height - 1)
      val yy1 = y1.coerceIn(yy0 + 1, height)
      // Use a slightly larger step for chroma planes.
      val st = if (isChroma) (step.coerceAtLeast(4)) else step
      for (y in yy0 until yy1 step st) {
        val row = y * rowStride
        for (x in xx0 until xx1 step st) {
          val idx = row + x * pixelStride
          if (idx >= 0 && idx < buf.limit()) {
            val v = buf.get(idx).toInt() and 0xFF
            sum += v.toDouble()
            cnt += 1
          }
        }
      }
      return if (cnt <= 0) 0.0 else (sum / cnt.toDouble())
    }

    private fun clamp255(v: Double): Double {
      return when {
        v < 0.0 -> 0.0
        v > 255.0 -> 255.0
        else -> v
      }
    }

    fun stop() {
      try {
        // Best-effort: turn off torch before closing.
        torchEnabled = false
        startRepeating(lockAe = false)
      } catch (_: Throwable) {
      }
      try { session?.close() } catch (_: Throwable) {}
      session = null
      try { camera?.close() } catch (_: Throwable) {}
      camera = null
      try { reader?.close() } catch (_: Throwable) {}
      reader = null
      try { previewSurface?.release() } catch (_: Throwable) {}
      previewSurface = null
      try { previewEntry?.release() } catch (_: Throwable) {}
      previewEntry = null
      previewTextureId = null
      try {
        thread?.quitSafely()
        thread?.join(600)
      } catch (_: Throwable) {}
      thread = null
      handler = null
      DbRepo.log(ctx, null, "[PPG-C2] stopped")
    }

    private fun chooseSize(candidates: List<Size>, reqW: Int, reqH: Int): Size {
      if (candidates.isEmpty()) return Size(reqW, reqH)
      // Prefer exact match.
      candidates.firstOrNull { it.width == reqW && it.height == reqH }?.let { return it }
      // Prefer same aspect ratio and closest area.
      val reqRatio = reqW.toDouble() / reqH.toDouble()
      fun score(s: Size): Double {
        val ratio = s.width.toDouble() / s.height.toDouble()
        val ratioPenalty = kotlin.math.abs(ratio - reqRatio) * 1000.0
        val areaPenalty = kotlin.math.abs((s.width * s.height) - (reqW * reqH)).toDouble() / 1000.0
        return ratioPenalty + areaPenalty
      }
      return candidates.minByOrNull { score(it) } ?: candidates.first()
    }

    private fun chooseFpsRange(ranges: List<Range<Int>>, reqFps: Int): Range<Int>? {
      if (ranges.isEmpty()) return null
      // Prefer fixed reqFps range.
      ranges.firstOrNull { it.lower == reqFps && it.upper == reqFps }?.let { return it }
      // Prefer ranges whose upper >= reqFps and lower is as high as possible.
      val cands = ranges.filter { it.upper >= reqFps }
      if (cands.isNotEmpty()) {
        return cands.maxByOrNull { it.lower } ?: cands.first()
      }
      // Otherwise, pick highest upper.
      return ranges.maxByOrNull { it.upper } ?: ranges.first()
    }

    private fun findBackCameraId(ctx: Context): String? {
      val cm = ctx.getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return null
      return try {
        cm.cameraIdList.firstOrNull { id ->
          val ch = cm.getCameraCharacteristics(id)
          val facing = ch.get(CameraCharacteristics.LENS_FACING)
          facing == CameraCharacteristics.LENS_FACING_BACK
        }
      } catch (_: Throwable) {
        null
      }
    }
  }
}
