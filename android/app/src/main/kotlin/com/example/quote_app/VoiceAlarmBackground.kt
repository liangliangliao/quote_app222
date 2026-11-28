package com.example.quote_app

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.graphics.Movie
import android.graphics.SurfaceTexture
import android.graphics.drawable.AnimatedImageDrawable
import android.media.MediaPlayer
import android.os.Build
import android.os.SystemClock
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.widget.ImageView
import java.io.File
import java.util.Locale

/** Owns the decorative background decoder and surface for one alarm screen. */
class VoiceAlarmBackground(context: Context, file: File) {
  private val videoFormats = setOf("mp4", "m4v", "webm", "3gp", "mov", "mkv")
  private var player: MediaPlayer? = null
  private var surface: Surface? = null
  private var ready = false
  private var active = false
  private var animation: android.graphics.drawable.Animatable? = null
  val view: View? = runCatching {
    when (file.extension.lowercase(Locale.ROOT)) {
      in videoFormats -> video(context, file)
      "gif" -> if (Build.VERSION.SDK_INT < 28) {
        Movie.decodeFile(file.path)?.let { GifView(context, it) }
      } else image(context, file)
      else -> image(context, file)
    }
  }.getOrNull()

  fun show(visible: Boolean) {
    active = visible
    if (visible) animation?.start() else animation?.stop()
    (view as? GifView)?.update(visible)
    if (ready) player?.let {
      runCatching { if (visible) it.start() else if (it.isPlaying) it.pause() }
    }
  }

  fun close() {
    show(false)
    (view as? TextureView)?.surfaceTextureListener = null
    releaseVideo()
  }

  private fun image(context: Context, file: File): ImageView? {
    val maxSide = maxOf(context.resources.displayMetrics.widthPixels, context.resources.displayMetrics.heightPixels).coerceAtLeast(480)
    return ImageView(context).apply {
      scaleType = ImageView.ScaleType.CENTER_CROP
      if (Build.VERSION.SDK_INT >= 28) {
        val drawable = ImageDecoder.decodeDrawable(ImageDecoder.createSource(file)) { decoder, info, _ ->
          decoder.setTargetSampleSize(maxOf(1, maxOf(info.size.width, info.size.height) / maxSide))
        }
        if (drawable is AnimatedImageDrawable) {
          drawable.repeatCount = AnimatedImageDrawable.REPEAT_INFINITE
          this@VoiceAlarmBackground.animation = drawable
        }
        setImageDrawable(drawable)
      } else {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        val opts = BitmapFactory.Options().apply { inSampleSize = maxOf(1, maxOf(bounds.outWidth, bounds.outHeight) / maxSide) }
        setImageBitmap(BitmapFactory.decodeFile(file.path, opts) ?: return null)
      }
    }
  }

  private fun video(context: Context, file: File): TextureView = TextureView(context).apply {
    fun crop(screenWidth: Int, screenHeight: Int) {
      val videoWidth = player?.videoWidth ?: 0
      val videoHeight = player?.videoHeight ?: 0
      if (minOf(videoWidth, videoHeight, screenWidth, screenHeight) <= 0) return
      val scale = maxOf(screenWidth.toFloat() / videoWidth, screenHeight.toFloat() / videoHeight)
      setTransform(Matrix().apply {
        setScale(videoWidth * scale / screenWidth, videoHeight * scale / screenHeight, screenWidth / 2f, screenHeight / 2f)
      })
    }
    surfaceTextureListener = object : TextureView.SurfaceTextureListener {
      override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
        surface = Surface(texture)
        val media = MediaPlayer()
        player = media
        try {
          media.setDataSource(file.absolutePath)
          media.setSurface(surface)
          media.setVolume(0f, 0f)
          media.isLooping = true
          media.setOnErrorListener { current, _, _ ->
            if (current === player) { releaseVideo(); visibility = View.INVISIBLE }
            true
          }
          media.setOnPreparedListener { current ->
            if (current === player) {
              ready = true
              crop(this@apply.width, this@apply.height)
              if (active) current.start()
            }
          }
          media.prepareAsync()
        } catch (_: Exception) {
          releaseVideo()
          visibility = View.INVISIBLE
        }
      }
      override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) { if (ready) crop(width, height) }
      override fun onSurfaceTextureUpdated(texture: SurfaceTexture) = Unit
      override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
        releaseVideo()
        return true
      }
    }
  }

  private fun releaseVideo() {
    ready = false
    player?.release()
    player = null
    surface?.release()
    surface = null
  }

  @Suppress("DEPRECATION")
  private class GifView(context: Context, private val movie: Movie) : View(context) {
    private var playing = false
    private var startedAt = 0L
    init { setLayerType(LAYER_TYPE_SOFTWARE, null) }
    fun update(visible: Boolean) {
      playing = visible
      if (visible) { startedAt = SystemClock.uptimeMillis(); invalidate() }
    }
    override fun onDraw(canvas: Canvas) {
      if (movie.width() <= 0 || movie.height() <= 0) return
      val ratio = maxOf(width.toFloat() / movie.width(), height.toFloat() / movie.height())
      if (playing) movie.setTime(((SystemClock.uptimeMillis() - startedAt) % movie.duration().coerceAtLeast(1)).toInt())
      canvas.save()
      canvas.translate((width - movie.width() * ratio) / 2f, (height - movie.height() * ratio) / 2f)
      canvas.scale(ratio, ratio)
      movie.draw(canvas, 0f, 0f)
      canvas.restore()
      if (playing) postInvalidateOnAnimation()
    }
  }
}
