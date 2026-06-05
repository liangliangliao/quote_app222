package com.example.quote_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel

/**
 * Stream step counts to Flutter.
 *
 * Uses TYPE_STEP_COUNTER when available (cumulative since boot) and falls back to TYPE_STEP_DETECTOR.
 * Flutter can call resetSession() via MethodChannel to set a new baseline for a workout.
 */
class StepCounterStream(private val ctx: Context) : EventChannel.StreamHandler, SensorEventListener {

  private var sink: EventChannel.EventSink? = null
  private var sm: SensorManager? = null
  private var stepCounter: Sensor? = null
  private var stepDetector: Sensor? = null

  // For TYPE_STEP_COUNTER
  @Volatile private var lastTotal: Int = -1
  @Volatile private var baseline: Int = -1

  // For TYPE_STEP_DETECTOR
  @Volatile private var detectorCount: Int = 0

  private var lastEmitAtMs: Long = 0L

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
    if (sm == null) {
      sm = ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager
      stepCounter = sm!!.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
      stepDetector = sm!!.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
    }
    try {
      // Prefer GAME delay for quicker updates; most pedometer UIs expect near-real-time step increments.
      val delay = SensorManager.SENSOR_DELAY_GAME
      if (stepCounter != null) {
        sm!!.registerListener(this, stepCounter, delay)
      } else if (stepDetector != null) {
        sm!!.registerListener(this, stepDetector, delay)
      } else {
        // No sensor available; emit 0 once.
        sink?.success(0)
      }
    } catch (_: Throwable) {}
  }

  override fun onCancel(arguments: Any?) {
    try { sm?.unregisterListener(this) } catch (_: Throwable) {}
    sink = null
  }

  fun resetSession() {
    // Baseline will be set on next sensor event.
    baseline = -1
    detectorCount = 0
    lastEmitAtMs = 0L
  }

  override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
    // no-op
  }

  override fun onSensorChanged(event: SensorEvent?) {
    if (event == null) return
    val nowMs = SystemClock.elapsedRealtime()
    // Throttle to reduce UI jank (max ~10Hz)
    if (nowMs - lastEmitAtMs < 100) return
    lastEmitAtMs = nowMs

    try {
      when (event.sensor.type) {
        Sensor.TYPE_STEP_COUNTER -> {
          val total = event.values[0].toInt()
          lastTotal = total
          if (baseline < 0) baseline = total
          var session = total - baseline
          if (session < 0) {
            // Device reboot or counter reset.
            baseline = total
            session = 0
          }
          sink?.success(session)
        }
        Sensor.TYPE_STEP_DETECTOR -> {
          // Each event represents a step.
          detectorCount += 1
          sink?.success(detectorCount)
        }
      }
    } catch (_: Throwable) {
      // ignore
    }
  }
}
