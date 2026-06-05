import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/self_help_dao.dart';
import '../data/kv_dao.dart';
import '../integrations/fitbit/fitbit_client.dart';
import '../utils/ppg_processor.dart';
import '../utils/fitbit_metrics.dart';
import '../utils/arousal_model.dart';
import '../utils/self_help_logger.dart';
import '../platform/ppg_camera2_bridge.dart';
import 'change_self_help_report_page.dart';
import 'change_intervention_page.dart';
import 'fitbit_settings_page.dart';



enum _PpgSignalMode { auto, greenUV, greenVU, redUV, redVU, luma, bgraGreen }

class _PpgGateResult {
  const _PpgGateResult({
    required this.grade,
    required this.hrOk,
    required this.hrvOk,
    required this.hrConfidence0To1,
    required this.hrvConfidence0To1,
    required this.reasons,
    this.message,
    this.fsHz,
    this.fpsCv,
    this.specQ,
    this.specBpm,
    this.bpm,
  });

  /// good / fair / poor / invalid
  final String grade;

  /// Whether heart rate is considered usable.
  final bool hrOk;

  /// Whether HRV (RMSSD) is considered usable.
  final bool hrvOk;

  /// 0..1 (for logs/UI, not shown by default).
  final double hrConfidence0To1;
  final double hrvConfidence0To1;

  /// Human-readable reasons (Chinese) describing the limiting factors.
  final List<String> reasons;

  /// Optional UI message (Chinese).
  final String? message;

  final double? fsHz;
  final double? fpsCv;
  final double? specQ;
  final double? specBpm;
  final double? bpm;
}

String _ppgGradeLabelCn(String g) {
  switch (g) {
    case 'good':
      return '良好';
    case 'fair':
      return '一般';
    case 'poor':
      return '较差';
    case 'invalid':
    default:
      return '无效';
  }
}

/// "改变 · 心理自助"（Change module）
///
/// - 主观：STAI-6（状态焦虑短表） + Affective Slider（唤醒/愉悦）
/// - 客观：手机后置摄像头 PPG（心率 + HRV RMSSD 估算）
/// - 可选：Fitbit 数据同步（心率、睡眠、HRV 等）
class ChangeSelfHelpPage extends StatefulWidget {
  const ChangeSelfHelpPage({super.key});

  @override
  State<ChangeSelfHelpPage> createState() => _ChangeSelfHelpPageState();
}

class _ChangeSelfHelpPageState extends State<ChangeSelfHelpPage> {
  final _dao = SelfHelpDao();
  final _kv = KeyValueDao();
  final _ppg = PpgProcessor();

  // --- subjective ---
  // STAI-6 items (1..4)
  final List<int> _stai6 = List<int>.filled(6, 2);
  // Affective Slider (0..100)
  double _arousal = 50;
  double _valence = 50;

  // Zone appraisal (0..100)
  double _demand = 50; // perceived challenge/demand
  double _resources = 60; // perceived coping resources/control
  double _distress = 35; // subjective distress (SUDS)

  // --- objective (camera PPG) ---
  CameraController? _cam;
  StreamSubscription<Map<String, dynamic>>? _cam2Sub;
  bool _usingCamera2 = false;
  bool _warmupDone = false;
  int _usableStartWallMs = 0;
  int _measureStartWallMs = 0;
  double? _liveFps;
  bool _measuring = false;
  double? _bpm;
  double? _rmssd;
  double? _sqi;
  String? _ppgQualityLabel;
  List<String> _ppgQualityReasons = const [];
  String? _ppgError;
  int _secondsLeft = 0;
  Timer? _ticker;
  bool _torchEnabled = false;

  // Camera2 preview (Flutter texture)
  int? _cam2TextureId;
  double? _cam2PreviewAspectRatio;

  // green channel samples & timestamps (ms)
  final List<double> _samples = [];
  final List<int> _tsMs = [];

  // PPG signal extraction mode auto-selection (to improve robustness across devices).
  _PpgSignalMode _ppgSignalMode = _PpgSignalMode.auto;
  final List<double> _probeGreenUv = [];
  final List<double> _probeGreenVu = [];
  final List<double> _probeRedUv = [];
  final List<double> _probeRedVu = [];
  final List<double> _probeLuma = [];
  int _probeTarget = 45; // ~3s at ~15fps

  // PPG warmup to allow torch exposure + finger settling
  int _ppgStartMs = 0;
  static const int _ppgWarmupMs = 1000;

  // --- fitbit ---
  bool _fitbitSyncing = false;
  String? _fitbitStatus;

  final _fitbitDao = FitbitDao();
  int _fitbitCacheCount = 0;
  List<String> _fitbitCachedEndpoints = const [];

  FitbitMetrics? _fitbitMetrics;
  double? _baselineRestingHr;
  double? _baselineRmssdMs;

  ArousalResult? _lastComputed;

  @override
  void initState() {
    super.initState();
    _reloadBaselinesAndFitbit();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopCamera();
    super.dispose();
  }

  // =======================
  // Subjective scoring
  // =======================

  /// STAI-6 scoring (Marteau & Bekker 1992): reverse score positive items,
  /// sum 6 items (range 6..24), and optionally prorate to 20-item STAI
  /// by multiplying by (20/6) producing 20..80.
  ///
  /// Reverse-scored items: calm, relaxed, content.
  int _stai6Raw() {
    // indices: 0 calm (R), 1 tense, 2 upset, 3 relaxed (R), 4 content (R), 5 worried
    int rev(int v) => 5 - v; // 1<->4
    final v0 = rev(_stai6[0]);
    final v1 = _stai6[1];
    final v2 = _stai6[2];
    final v3 = rev(_stai6[3]);
    final v4 = rev(_stai6[4]);
    final v5 = _stai6[5];
    return v0 + v1 + v2 + v3 + v4 + v5;
  }

  double _stai6Prorated() {
    return _stai6Raw() * (20.0 / 6.0);
  }

  // =======================
  // Baselines & Fitbit metrics
  // =======================

  String _todayDateStr() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  double? _median(List<double> xs) {
    if (xs.isEmpty) return null;
    final a = [...xs]..sort();
    final m = a.length ~/ 2;
    if (a.length.isOdd) return a[m];
    return (a[m - 1] + a[m]) / 2.0;
  }

  double? _baselineFromRecentHr(List<double> bpm) {
    if (bpm.isEmpty) return null;
    final a = [...bpm]..sort();
    // Use the lower 30% to approximate resting baseline.
    final take = math.max(1, (a.length * 0.30).ceil());
    return _median(a.take(take).toList(growable: false));
  }

  double? _baselineFromRecentRmssd(List<double> rmssd) {
    if (rmssd.isEmpty) return null;
    final a = [...rmssd]..sort();
    // Use the upper 30% (higher HRV) to approximate calm baseline.
    final take = math.max(1, (a.length * 0.30).ceil());
    return _median(a.skip(math.max(0, a.length - take)).toList(growable: false));
  }

  Future<void> _reloadBaselinesAndFitbit() async {
    // Baseline from recent local records.
    try {
      final recents = await _dao.recentRecords(limit: 30);
      final bpm = <double>[];
      final rmssd = <double>[];
      for (final r in recents) {
        final b = (r['bpm'] as num?)?.toDouble();
        final h = (r['rmssd_ms'] as num?)?.toDouble();
        final sqi = (r['signal_quality'] as num?)?.toDouble() ?? 0.0;
        if (b != null && b >= 35 && b <= 200 && sqi >= 0.45) bpm.add(b);
        if (h != null && h >= 5 && h <= 200 && sqi >= 0.45) rmssd.add(h);
      }
      final baseHr = _baselineFromRecentHr(bpm);
      final baseRmssd = _baselineFromRecentRmssd(rmssd);
      if (mounted) {
        setState(() {
          _baselineRestingHr = baseHr;
          _baselineRmssdMs = baseRmssd;
        });
      }
    } catch (_) {
      // ignore
    }

    // Fitbit caches and parsed metrics for today.
    try {
      final date = _todayDateStr();
      final caches = await _fitbitDao.listCachesForDate(date);
      final endpoints = <String>[];
      for (final c in caches) {
        final ep = (c['endpoint'] ?? '')?.toString() ?? '';
        if (ep.isNotEmpty) endpoints.add(ep);
      }
      endpoints.sort();
      final metrics = await FitbitMetrics.load(dao: _fitbitDao, date: date);
      if (mounted) {
        setState(() {
          _fitbitCacheCount = caches.length;
          _fitbitCachedEndpoints = endpoints.toSet().toList(growable: false);
          // Only keep metrics if it has at least one signal.
          final hasAny = metrics.restingHeartRate != null ||
              metrics.currentHeartRate != null ||
              metrics.hrvRmssdMs != null ||
              metrics.sleepMinutes != null ||
              metrics.breathingRate != null;
          _fitbitMetrics = hasAny ? metrics : null;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  // =======================
  // Zone classification
  // =======================

  
  String _zoneFromMetrics({double? bpm, double? rmssd, double? arousal0To100, double? staiProrated, double? demand0To100, double? resources0To100, double? distress0To100}) {
    // -----------------------
    // 科学化三区自评思路（主观）：
    // - 需求/挑战（Demand）
    // - 资源/掌控感（Resources / Control）
    // - 困扰强度（SUDS / Distress）
    //
    // 结合：唤醒（Arousal） + 状态焦虑（STAI-6） + 生理激活（HR/HRV）
    // 三区判定核心：需求与资源的“差距” + 困扰强度
    // -----------------------

    // Subjective
    final a = ((arousal0To100 ?? _arousal) / 100.0).clamp(0.0, 1.0);
    final s = (((staiProrated ?? _stai6Prorated()) - 20.0) / 60.0).clamp(0.0, 1.0); // 20..80 -> 0..1
    final d = ((demand0To100 ?? _demand) / 100.0).clamp(0.0, 1.0);
    final r = ((resources0To100 ?? _resources) / 100.0).clamp(0.0, 1.0);
    final u = ((distress0To100 ?? _distress) / 100.0).clamp(0.0, 1.0);

    // Objective contribution: high HR + low HRV suggests higher arousal.
    double o = 0.0;
    if (bpm != null) {
      o += ((bpm - 60.0) / 60.0).clamp(0.0, 1.0);
    }
    if (rmssd != null) {
      // typical RMSSD often ~20-80ms; lower => more stress.
      o += (1.0 - ((rmssd - 20.0) / 60.0).clamp(0.0, 1.0));
    }
    o = (o / 2.0).clamp(0.0, 1.0);

    // Appraisal gap: demand > resources implies overload risk.
    final gap = (d - r).clamp(-1.0, 1.0);

    // Composite activation: distress & arousal matter most for immediate self-help.
    final activation = (0.30 * a + 0.25 * s + 0.20 * o + 0.25 * u).clamp(0.0, 1.0);

    // Comfort zone: low demand + low distress + low activation.
    if (activation < 0.42 && d < 0.45 && u < 0.45) return '舒适区';

    // Panic zone: very high distress OR demand significantly exceeds resources (especially with high activation).
    if (u >= 0.85) return '恐慌区';
    if (gap >= 0.25 && (u >= 0.65 || activation >= 0.72)) return '恐慌区';
    if (activation >= 0.80 && u >= 0.60) return '恐慌区';

    // Learning zone: moderate challenge + manageable distress, even if activation is moderate.
    return '学习区';
  }

  String _zoneAdvice(String zone) {
    switch (zone) {
      case '舒适区':
        return '你当前较稳定。可以尝试一个“小挑战”：把目标分解到 10 分钟能完成的下一步。';
      case '学习区':
        return '你处在可成长的张力区间。建议：设定 25 分钟专注 + 5 分钟恢复；结束后做一次身体扫描/伸展。';
      case '恐慌区':
      default:
        return '唤醒水平偏高。先做“降唤醒”：4-6 呼吸（吸 4 秒、呼 6 秒）× 3 轮；把任务缩小到“最小下一步”。必要时暂停并寻求支持。';
    }
  }

  // =======================
  // Camera PPG
  // =======================

  Future<bool> _ensureCameraPermission() async {
    final st = await Permission.camera.request();
    return st.isGranted;
  }
  /// Extract a scalar PPG signal from [CameraImage].
  ///
  /// 参考 Google Fit 等消费级 App 的相机 PPG（指尖覆盖后置镜头）做法：
  /// - torch/闪光灯在暗环境下可提升信噪比（但过亮会饱和，需要做门控）
  /// - 以“类绿色通道”强度作为主要 PPG 信号（通常比红色更稳）
  /// - 对不同机型可能存在的 YUV U/V 顺序差异做探测并自动选择
  ///
  /// Output is normalized to 0..1.
  double _extractPpgSignal(CameraImage img) {
    // ROI in the center to reduce edge leakage when finger doesn't fully cover lens.
    final w = img.width;
    final h = img.height;
    final x0 = (w * 0.35).round().clamp(0, w - 1);
    final x1 = (w * 0.65).round().clamp(1, w);
    final y0 = (h * 0.35).round().clamp(0, h - 1);
    final y1 = (h * 0.65).round().clamp(1, h);
    const step = 4; // downsample for speed

    // BGRA (some iOS devices) – use green byte (BGRA ordering).
    if (img.format.group == ImageFormatGroup.bgra8888 && img.planes.isNotEmpty) {
      final p = img.planes[0];
      final bytes = p.bytes;
      final rowStride = p.bytesPerRow;
      double sum = 0.0;
      int n = 0;
      for (int y = y0; y < y1; y += step) {
        final row = y * rowStride;
        for (int x = x0; x < x1; x += step) {
          final i = row + x * 4;
          if (i + 1 >= bytes.length) continue;
          final g = bytes[i + 1].toDouble();
          sum += g;
          n++;
        }
      }
      if (n <= 0) return 0.0;
      return (sum / n) / 255.0;
    }

    // YUV420 (Android) – derive normalized luma / green / red candidates.
    if (img.planes.length < 3) return 0.0;
    final yPlane = img.planes[0];
    final uPlane = img.planes[1];
    final vPlane = img.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 2;
    final vPixelStride = vPlane.bytesPerPixel ?? 2;

    double sumL = 0.0;
    double sumGreenUv = 0.0;
    double sumGreenVu = 0.0;
    double sumRedUv = 0.0;
    double sumRedVu = 0.0;
    int n = 0;

    for (int y = y0; y < y1; y += step) {
      final yRow = y * yRowStride;
      final uRow = (y >> 1) * uRowStride;
      final vRow = (y >> 1) * vRowStride;
      for (int x = x0; x < x1; x += step) {
        final yi = yRow + x;
        final ui = uRow + (x >> 1) * uPixelStride;
        final vi = vRow + (x >> 1) * vPixelStride;
        if (yi < 0 || yi >= yBytes.length) continue;
        if (ui < 0 || ui >= uBytes.length) continue;
        if (vi < 0 || vi >= vBytes.length) continue;

        final yy = yBytes[yi].toDouble();
        final uu = uBytes[ui].toDouble() - 128.0;
        final vv = vBytes[vi].toDouble() - 128.0;

        sumL += yy;

        // Standard ordering: planes[1]=U, planes[2]=V
        sumRedUv += (yy + 1.402 * vv);
        sumGreenUv += (yy - 0.344136 * uu - 0.714136 * vv);

        // Swapped ordering fallback (treat U as V)
        sumRedVu += (yy + 1.402 * uu);
        sumGreenVu += (yy - 0.344136 * vv - 0.714136 * uu);

        n++;
      }
    }

    if (n <= 0) return 0.0;

    double clamp255(double v) => v < 0.0 ? 0.0 : (v > 255.0 ? 255.0 : v);
    double norm01(double v) => clamp255(v) / 255.0;

    final luma = norm01(sumL / n);
    final greenUv = norm01(sumGreenUv / n);
    final greenVu = norm01(sumGreenVu / n);
    final redUv = norm01(sumRedUv / n);
    final redVu = norm01(sumRedVu / n);

    // Auto-probe first few seconds to choose the channel with the most variability
    // and avoid near-black/near-white saturation.
    if (_ppgSignalMode == _PpgSignalMode.auto) {
      _probeGreenUv.add(greenUv);
      _probeGreenVu.add(greenVu);
      _probeRedUv.add(redUv);
      _probeRedVu.add(redVu);
      _probeLuma.add(luma);

      if (_probeGreenUv.length >= _probeTarget) {
        double meanOf(List<double> a) => a.isEmpty ? 0.0 : a.reduce((p, c) => p + c) / a.length;

        double stdOf(List<double> a) {
          if (a.length < 2) return 0.0;
          final m = meanOf(a);
          double s = 0.0;
          for (final v in a) {
            final d = v - m;
            s += d * d;
          }
          return math.sqrt(s / math.max(1, a.length - 1));
        }

        double score(List<double> a) {
          final m = meanOf(a);
          final s = stdOf(a);
          // Extreme brightness usually means not covering lens/torch or over-saturation.
          final penalty = (m < 0.12 || m > 0.97) ? 0.35 : 1.0;
          return s * penalty;
        }

        final sGreenUv = score(_probeGreenUv);
        final sGreenVu = score(_probeGreenVu);
        final sRedUv = score(_probeRedUv);
        final sRedVu = score(_probeRedVu);
        final sLuma = score(_probeLuma);

        // Prefer green variants; fallback to others if they clearly dominate.
        final best = <_PpgSignalMode, double>{
          _PpgSignalMode.greenUV: sGreenUv,
          _PpgSignalMode.greenVU: sGreenVu,
          _PpgSignalMode.redUV: sRedUv,
          _PpgSignalMode.redVU: sRedVu,
          _PpgSignalMode.luma: sLuma,
        }.entries.reduce((a, b) => a.value >= b.value ? a : b);

        // Prefer luma if it's close to the best score (often the most robust on Android).
        if (sLuma >= best.value * 0.85) {
          _ppgSignalMode = _PpgSignalMode.luma;
        } else {
          _ppgSignalMode = best.key;
        }

        _probeGreenUv.clear();
        _probeGreenVu.clear();
        _probeRedUv.clear();
        _probeRedVu.clear();
        _probeLuma.clear();
      }

      // While probing, use luma as a robust default (works even if UV planes vary by device).
      return luma;
    }

    switch (_ppgSignalMode) {
      case _PpgSignalMode.greenUV:
        return greenUv;
      case _PpgSignalMode.greenVU:
        return greenVu;
      case _PpgSignalMode.redUV:
        return redUv;
      case _PpgSignalMode.redVU:
        return redVu;
      case _PpgSignalMode.luma:
        return luma;
      case _PpgSignalMode.bgraGreen:
        // Not expected here because BGRA branch returns early, but keep for completeness.
        return greenUv;
      case _PpgSignalMode.auto:
        return greenUv;
    }
  }

  Future<void> _startMeasurement() async {
    setState(() {
      _ppgError = null;
      _bpm = null;
      _rmssd = null;
      _sqi = null;
      _ppgQualityLabel = null;
      _ppgQualityReasons = const [];
      _torchEnabled = false;
    });

    await SelfHelpLogger.log('INFO', 'ppg', 'start_measurement');

    if (!await _ensureCameraPermission()) {
      setState(() => _ppgError = '未获得相机权限');
      await SelfHelpLogger.log('WARN', 'ppg', 'camera_permission_denied');
      return;
    }

    // Android 优先使用 Camera2 原生桥接（更稳定的 FPS，有利于 HRV 精度）。
    if (Platform.isAndroid) {
      final ok = await _startMeasurementCamera2();
      if (ok) return;
    }

    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.isNotEmpty ? cameras.first : throw Exception('No camera'),
      );

      // Note: some Android 14 devices are unstable with ResolutionPreset.low for imageStream.
      // medium is still lightweight but tends to provide more stable YUV planes.
      final ctrl = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();

      // Best-effort camera tuning:
      // - Let exposure/focus settle shortly, then lock them to avoid hunting.
      try {
        await ctrl.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await ctrl.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await ctrl.setExposurePoint(const Offset(0.5, 0.5));
      } catch (_) {}
      try {
        await ctrl.setFocusPoint(const Offset(0.5, 0.5));
      } catch (_) {}

      final nowWall = DateTime.now().millisecondsSinceEpoch;
      _ppgStartMs = nowWall;
      _usableStartWallMs = nowWall + 1000; // 1s warmup
      _measureStartWallMs = 0;
      _warmupDone = false;
      _usingCamera2 = false;
      _liveFps = null;

      setState(() {
        _cam = ctrl;
        _measuring = true;
        _secondsLeft = 30;
        _samples.clear();
        _tsMs.clear();
        _ppgQualityLabel = null;
        _ppgQualityReasons = const [];
        _ppgSignalMode = _PpgSignalMode.auto;
        _probeGreenUv.clear();
        _probeGreenVu.clear();
        _probeRedUv.clear();
        _probeRedVu.clear();
        _probeLuma.clear();
        _ppgError = '预热中…（约 1 秒）';
      });

      // Start stream first, then enable torch (some devices require this order).
      int lastAddedMs = 0;
      await ctrl.startImageStream((img) {
        if (!_measuring) return;

        final now = DateTime.now().millisecondsSinceEpoch;

        // Warmup discard (torch exposure + finger settling).
        if (now < _usableStartWallMs) return;

        if (!_warmupDone) {
          _warmupDone = true;
          _measureStartWallMs = now;
          if (mounted) {
            setState(() {
              _secondsLeft = 30;
              _ppgError = null;
            });
          }
          unawaited(SelfHelpLogger.log('INFO', 'ppg', 'warmup_done', extra: {
            'mode': 'camera',
            'startWallMs': _measureStartWallMs,
          }));
        }

        // Light throttle (avoid bursty callbacks);
        // keep high FPS for precision when available.
        if (now - lastAddedMs < 15) return;
        lastAddedMs = now;

        final mean = _extractPpgSignal(img);
        _samples.add(mean);
        _tsMs.add(now);
      });

      // Enable torch after stream started.
      try {
        await ctrl.setFlashMode(FlashMode.torch);
      } catch (_) {}
      _torchEnabled = ctrl.value.flashMode == FlashMode.torch;

      // Reset warmup window after torch is actually enabled.
      _usableStartWallMs = DateTime.now().millisecondsSinceEpoch + 1000;
      _warmupDone = false;
      _measureStartWallMs = 0;

      // Avoid obvious saturation: use a mild negative exposure offset if supported.
      // (Do not over-darken; keep it conservative.)
      try {
        final minOff = await ctrl.getMinExposureOffset();
        final maxOff = await ctrl.getMaxExposureOffset();
        final target = (minOff * 0.25).clamp(minOff, maxOff);
        await ctrl.setExposureOffset(target);
      } catch (_) {}

      // Lock exposure/focus after torch has stabilized (best-effort).
      Future.delayed(const Duration(milliseconds: _ppgWarmupMs + 400), () {
        if (!mounted) return;
        if (!_measuring) return;
        if (_cam != ctrl) return;
        unawaited(() async {
          try {
            await ctrl.setExposureMode(ExposureMode.locked);
          } catch (_) {}
          try {
            await ctrl.setFocusMode(FocusMode.locked);
          } catch (_) {}
        }());
      });

      await SelfHelpLogger.log('INFO', 'ppg', 'stream_started', extra: {
        // Camera-plugin path: torch state is tracked by _torchEnabled.
        'torch': _torchEnabled,
        'previewSize': ctrl.value.previewSize?.toString(),
      });

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) return;
        if (!_measuring) {
          t.cancel();
          return;
        }

        // During warmup we don't countdown.
        if (!_warmupDone || _measureStartWallMs <= 0) {
          final remainWarmMs = (_usableStartWallMs - DateTime.now().millisecondsSinceEpoch).clamp(0, 2000);
          setState(() {
            _secondsLeft = 30;
            _ppgError = remainWarmMs > 0 ? '预热中…（约 ${(remainWarmMs / 1000).toStringAsFixed(1)} 秒）' : _ppgError;
          });
          return;
        }

        final wallNow = DateTime.now().millisecondsSinceEpoch;
        final elapsedSec = ((wallNow - _measureStartWallMs) / 1000).floor();
        final remain = 30 - elapsedSec;
        if (remain <= 0) {
          t.cancel();
          await _finishMeasurement();
          return;
        }

        setState(() => _secondsLeft = remain);

        if (remain % 5 == 0 || remain == 29) {
          final st = _estimateLiveStatus();
          if (st.isNotEmpty) {
            unawaited(SelfHelpLogger.log('INFO', 'ppg', 'live', extra: {
              'mode': 'camera',
              'remain': remain,
              ...st,
            }));
          }
        }
      });
    } catch (e) {
      setState(() {
        _ppgError = '启动测量失败：$e';
        _measuring = false;
      });
      await SelfHelpLogger.log('ERROR', 'ppg', 'start_failed', extra: {'error': e.toString()});
      await _stopCamera();
    }
  }

  /// Android Camera2 (native bridge) path.
  ///
  /// Returns true if we successfully started native streaming.
  Future<bool> _startMeasurementCamera2() async {
    try {
      final supported = await PpgCamera2Bridge.isSupported();
      if (!supported) {
        await SelfHelpLogger.log('INFO', 'ppg', 'camera2_not_supported');
        return false;
      }

      final cfg = await PpgCamera2Bridge.start(width: 640, height: 480, fps: 30, torch: true);

      final tid = (cfg['textureId'] as num?)?.toInt();
      final cw = (cfg['width'] as num?)?.toDouble();
      final ch = (cfg['height'] as num?)?.toDouble();
      final ar = (cw != null && ch != null && ch > 0) ? (cw / ch) : null;

      final nowWall = DateTime.now().millisecondsSinceEpoch;
      _usableStartWallMs = nowWall + 1000; // 1s warmup
      _measureStartWallMs = 0;
      _warmupDone = false;
      _usingCamera2 = true;
      _liveFps = null;
      _torchEnabled = true;

      setState(() {
        _cam = null;
        _cam2TextureId = tid;
        _cam2PreviewAspectRatio = ar;
        _measuring = true;
        _secondsLeft = 30;
        _samples.clear();
        _tsMs.clear();
        _ppgQualityLabel = null;
        _ppgQualityReasons = const [];
        _ppgSignalMode = _PpgSignalMode.luma; // luma is more robust for finger+torch on many devices
        _ppgError = '预热中…（约 1 秒）';
      });

      await SelfHelpLogger.log('INFO', 'ppg', 'camera2_started', extra: {
        'cfg': cfg.toString(),
      });

      await _cam2Sub?.cancel();
      _cam2Sub = PpgCamera2Bridge.frames().listen((m) {
        if (!_measuring || !_usingCamera2) return;
        final wallNow = DateTime.now().millisecondsSinceEpoch;
        final ts = (m['tsMs'] as num?)?.toInt();
        if (ts == null) return;

        final fps = (m['fps'] as num?)?.toDouble();
        if (fps != null && fps.isFinite && fps > 0) {
          _liveFps = fps;
        }

        // Warmup discard.
        if (wallNow < _usableStartWallMs) return;

        if (!_warmupDone) {
          _warmupDone = true;
          _measureStartWallMs = wallNow;
          if (mounted) {
            setState(() {
              _secondsLeft = 30;
              _ppgError = null;
            });
          }
          unawaited(SelfHelpLogger.log('INFO', 'ppg', 'warmup_done', extra: {
            'mode': 'camera2',
            'startWallMs': _measureStartWallMs,
          }));
        }

        final g = (m['g'] as num?)?.toDouble();
        final y = (m['y'] as num?)?.toDouble();
        // Use luma (Y) when available; it's usually less device-dependent than a single RGB channel
        // under finger+torch transmission.
        final sample = (y ?? g ?? 0.0);
        if (!sample.isFinite) return;

        _samples.add(sample);
        _tsMs.add(ts);
      }, onError: (e) {
        unawaited(SelfHelpLogger.log('ERROR', 'ppg', 'camera2_stream_error', extra: {'error': e.toString()}));
      });

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) return;
        if (!_measuring) {
          t.cancel();
          return;
        }

        // During warmup we don't countdown.
        if (!_warmupDone || _measureStartWallMs <= 0) {
          final remainWarmMs = (_usableStartWallMs - DateTime.now().millisecondsSinceEpoch).clamp(0, 2000);
          setState(() {
            _secondsLeft = 30;
            _ppgError = remainWarmMs > 0 ? '预热中…（约 ${(remainWarmMs / 1000).toStringAsFixed(1)} 秒）' : _ppgError;
          });
          return;
        }

        final wallNow = DateTime.now().millisecondsSinceEpoch;
        final elapsedSec = ((wallNow - _measureStartWallMs) / 1000).floor();
        final remain = 30 - elapsedSec;
        if (remain <= 0) {
          t.cancel();
          await _finishMeasurement();
          return;
        }

        final st = _estimateLiveStatus();
        setState(() {
          _secondsLeft = remain;
          final sb = st['specBpm'];
          final sq = st['specQ'];
          if (sb is num && sb.isFinite) {
            final v = sb.toDouble();
            if (v > 20 && v < 220) _bpm = v;
          }
          if (sq is num && sq.isFinite) {
            _sqi = sq.toDouble().clamp(0.0, 1.0);
          }
        });

        // Key status logs every 5 seconds.
        if ((remain % 5 == 0 || remain == 29) && st.isNotEmpty) {
          unawaited(SelfHelpLogger.log('INFO', 'ppg', 'live', extra: {
            'mode': 'camera2',
            'remain': remain,
            ...st,
          }));
        }
      });

      return true;
    } catch (e) {
      await SelfHelpLogger.log('WARN', 'ppg', 'camera2_start_failed', extra: {'error': e.toString()});
      try {
        await PpgCamera2Bridge.stop();
      } catch (_) {}
      _usingCamera2 = false;
      _warmupDone = false;
      return false;
    }
  }

  Map<String, dynamic> _estimateLiveStatus() {
    try {
      if (_samples.length < 120 || _tsMs.length != _samples.length) return const {};
      // Use last ~10 seconds window for stability.
      final int n = _samples.length;
      final int end = n;
      int start = (n - 300).clamp(0, n); // ~10s at 30fps
      if (end - start < 120) start = (n - 160).clamp(0, n);
      if (end - start < 120) return const {};

      final seg = _samples.sublist(start, end);
      final ts = _tsMs.sublist(start, end);
      final dtTotal = (ts.last - ts.first).clamp(1, 1 << 31);
      final fs = (seg.length - 1) * 1000.0 / dtTotal;
      if (fs < 8 || fs > 90) return {'fs': fs};

      // Live status should be stable and avoid "stuck at band edge".
      // Apply the same light preprocessing as the final pipeline
      // (detrend + bandpass) before spectral scan.
      final mean = seg.reduce((a, b) => a + b) / seg.length;
      final x0 = seg.map((v) => v - mean).toList(growable: false);
      final filt = _ppg.bandpassZeroPhase(x0, fs);
      final sm = _ppg.movingAverage(filt, (fs * 0.15).round());

      final est = PpgProcessor.estimateBpmByGoertzel(sm, fs);
      final bpm = est['bpm'];
      final q = est['quality'];
      return {
        'fs': fs,
        'specBpm': bpm,
        'specQ': q,
        'fpsNative': _liveFps,
        'samples': _samples.length,
      };
    } catch (_) {
      return const {};
    }
  }


  Map<String, double> _frameTimingStatsMs(List<int> tsMs) {
    // Compute timing jitter (CV of frame intervals). Wearables typically have
    // very stable sampling; phone camera streams can be bursty, which inflates HRV.
    if (tsMs.length < 6) return const {};
    final dts = <double>[];
    for (int i = 1; i < tsMs.length; i++) {
      final dt = tsMs[i] - tsMs[i - 1];
      if (dt <= 0) continue;
      if (dt > 250) continue; // drop large stalls
      if (dt < 5) continue; // drop impossible bursts
      dts.add(dt.toDouble());
    }
    if (dts.length < 5) return const {};
    final mean = dts.reduce((a, b) => a + b) / dts.length;
    double s2 = 0.0;
    for (final v in dts) {
      final d = v - mean;
      s2 += d * d;
    }
    final std = math.sqrt(s2 / dts.length);
    final cv = (mean <= 0) ? 9.9 : (std / mean);
    final fpsMean = (mean <= 0) ? 0.0 : (1000.0 / mean);
    return {
      'meanDtMs': mean,
      'stdDtMs': std,
      'cv': cv,
      'fpsMean': fpsMean,
    };
  }

  Map<String, double?> _spectralBpmOnWindow(List<double> x, List<int> tsMs, {required int i0, required int i1}) {
    // Return {bpm, q, fs} for a segment [i0, i1).
    if (i1 - i0 < 120) return const {'bpm': null, 'q': null, 'fs': null};
    if (i0 < 0 || i1 > x.length || i1 > tsMs.length) return const {'bpm': null, 'q': null, 'fs': null};
    final seg = x.sublist(i0, i1);
    final ts = tsMs.sublist(i0, i1);
    final dtTotal = (ts.last - ts.first).clamp(1, 1 << 31);
    final fs = (seg.length - 1) * 1000.0 / dtTotal;
    if (!fs.isFinite || fs < 8 || fs > 90) return {'bpm': null, 'q': null, 'fs': fs};
    final est = PpgProcessor.estimateBpmByGoertzel(seg, fs);
    return {'bpm': est['bpm'], 'q': est['quality'], 'fs': fs};
  }

  _PpgGateResult _evaluatePpgGate({
    required List<double> raw01,
    required List<double> waveform, // filtered, centered (for spectral checks)
    required List<int> tsMs,
    required double fs,
    required int peaks,
    required double? bpm,
    required double? rmssd,
    required double sqi,
    required double? specBpm,
    required double? specQ,
    required bool torchDuringMeasurement,
  }) {
    final reasons = <String>[];

    final durSec = (tsMs.isNotEmpty) ? ((tsMs.last - tsMs.first) / 1000.0) : 0.0;

    double mean01(List<double> xs) {
      if (xs.isEmpty) return 0.0;
      double s = 0.0;
      for (final v in xs) {
        s += v;
      }
      return s / xs.length;
    }

    double range01(List<double> xs) {
      if (xs.isEmpty) return 0.0;
      double minV = xs.first;
      double maxV = xs.first;
      for (final v in xs) {
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      return (maxV - minV).abs();
    }

    final rawMean = mean01(raw01);
    final rawRange = range01(raw01);

    // Timing jitter (CV of frame intervals).
    final timing = _frameTimingStatsMs(tsMs);
    final fpsCv = timing['cv'];

    // Segment stability: compare first and last ~10s spectral BPM.
    double? driftBpm;
    if (waveform.length >= 360 && tsMs.length == waveform.length) {
      final n = waveform.length;
      final win = (fs * 10.0).round().clamp(180, (n / 2).floor());
      final a = _spectralBpmOnWindow(waveform, tsMs, i0: 0, i1: win);
      final b = _spectralBpmOnWindow(waveform, tsMs, i0: (n - win), i1: n);
      final aBpm = a['bpm'];
      final bBpm = b['bpm'];
      final aQ = a['q'] ?? 0.0;
      final bQ = b['q'] ?? 0.0;
      if (aBpm != null && bBpm != null && aBpm.isFinite && bBpm.isFinite && aQ >= 0.25 && bQ >= 0.25) {
        driftBpm = (aBpm - bBpm).abs();
      }
    }

    bool invalid = false;

    // Hard constraints (invalidate).
    if (durSec < 18.0) {
      invalid = true;
      reasons.add('有效时长偏短（${durSec.toStringAsFixed(1)}s）');
    }
    if (!fs.isFinite || fs < 20.0 || fs > 40.0) {
      invalid = true;
      reasons.add('采样帧率异常（${fs.toStringAsFixed(1)}Hz）');
    }
    if (fpsCv != null && fpsCv.isFinite && fpsCv > 0.35) {
      invalid = true;
      reasons.add('帧率抖动过大（CV=${fpsCv.toStringAsFixed(2)}）');
    }

    // Saturation / darkness / flat signal.
    if (torchDuringMeasurement && rawMean > 0.985) {
      invalid = true;
      reasons.add('可能过亮/饱和（均值=${rawMean.toStringAsFixed(3)}）');
    } else {
      // Note: "光线不足" in camera-PPG does NOT mean the room is dark. The finger blocks ambient light;
      // this is about the effective brightness / baseline level under the finger+torch path.
      // Some devices show a low mean on certain channels even when measurement is valid,
      // so we only hard-invalidate when it is severely dark AND lacks periodicity evidence.
      final qSpecNow = (specQ ?? 0.0).clamp(0.0, 1.0);
      final darkTh = torchDuringMeasurement ? 0.012 : 0.06;
      if (rawMean < darkTh) {
        if (rawRange < 0.010 && qSpecNow < 0.45) {
          invalid = true;
          reasons.add('信号偏暗/遮挡不全（均值=${rawMean.toStringAsFixed(3)}）');
        } else {
          reasons.add('基线偏暗（均值=${rawMean.toStringAsFixed(3)}）');
        }
      }
    }
    if (rawRange < 0.008) {
      invalid = true;
      reasons.add('信号变化很小（range=${rawRange.toStringAsFixed(3)}）');
    }

    // Periodicity evidence.
    final qSpec = (specQ ?? 0.0).clamp(0.0, 1.0);
    final qPeak = sqi.clamp(0.0, 1.0);
    if (!invalid && qSpec < 0.18 && qPeak < 0.25) {
      invalid = true;
      reasons.add('缺少稳定的脉搏周期（specQ=${qSpec.toStringAsFixed(2)}, SQI=${qPeak.toStringAsFixed(2)}）');
    }

    // Consistency between peak-based HR and spectral HR.
    double? bpmDiff;
    if (bpm != null && specBpm != null && bpm.isFinite && specBpm.isFinite) {
      bpmDiff = (bpm - specBpm).abs();
      if (qSpec >= 0.45 && bpmDiff > 12.0) {
        reasons.add('心率估计不一致（Δ≈${bpmDiff.toStringAsFixed(1)}）');
      }
    }

    if (driftBpm != null && driftBpm.isFinite && driftBpm > 6.0) {
      reasons.add('前后心率漂移较大（Δ≈${driftBpm.toStringAsFixed(1)}）');
    }

    // Confidence score (0..1) for HR & HRV.
    double clamp01(double v) => v.clamp(0.0, 1.0);
    final fpsTerm = (fpsCv == null || !fpsCv.isFinite) ? 0.5 : clamp01(1.0 - (fpsCv / 0.35));
    double hrConf = 0.0;
    hrConf += 0.45 * qPeak;
    hrConf += 0.35 * qSpec;
    hrConf += 0.20 * fpsTerm;

    if (bpmDiff != null && qSpec >= 0.45) {
      hrConf -= 0.10 * clamp01((bpmDiff - 6.0) / 12.0);
    }
    if (driftBpm != null) {
      hrConf -= 0.10 * clamp01((driftBpm - 4.0) / 8.0);
    }
    // Penalize if too few peaks for a 20s+ window.
    if (durSec >= 18.0 && peaks < 4) {
      hrConf -= 0.10;
      reasons.add('峰值数量偏少（$peaks）');
    }

    hrConf = clamp01(hrConf);

    // HRV requires stricter conditions (wearables-grade).
    double hrvConf = hrConf;
    if (rmssd == null) hrvConf *= 0.2;
    if (peaks < 5) hrvConf *= 0.5;
    if (fpsCv != null && fpsCv.isFinite) {
      // HRV is very sensitive to jitter; penalize more.
      hrvConf *= clamp01(1.0 - (fpsCv / 0.20));
    }
    // Ensure periodicity evidence for HRV.
    if (qSpec < 0.30 && qPeak < 0.55) {
      hrvConf *= 0.5;
    }
    hrvConf = clamp01(hrvConf);

    if (invalid) {
      final msg = reasons.isEmpty ? '测量无效：请保持手指稳定并重试' : '测量无效：${reasons.first}，请按提示调整后重试';
      return _PpgGateResult(
        grade: 'invalid',
        hrOk: false,
        hrvOk: false,
        hrConfidence0To1: 0.0,
        hrvConfidence0To1: 0.0,
        reasons: reasons.take(4).toList(growable: false),
        message: msg,
        fsHz: fs,
        fpsCv: fpsCv,
        specQ: specQ,
        specBpm: specBpm,
        bpm: bpm,
      );
    }

    final hrOk = bpm != null && bpm.isFinite && bpm >= 35 && bpm <= 200 && hrConf >= 0.50;

    final hrvOk = hrOk && rmssd != null && hrvConf >= 0.75;

    String grade = 'poor';
    if (hrConf >= 0.80 && hrvConf >= 0.80) {
      grade = 'good';
    } else if (hrConf >= 0.65) {
      grade = 'fair';
    }

    String? msg;
    if (grade == 'poor') {
      msg = reasons.isEmpty ? '信号质量较差，心率参考价值下降；建议重测' : '信号质量较差：${reasons.first}；建议重测';
    } else if (grade == 'fair') {
      msg = reasons.isEmpty ? null : '信号质量一般：${reasons.first}；如需更准可再测一次取中位数';
    } else {
      msg = null;
    }

    // If HRV not ok but HR ok, add a clear hint.
    if (hrOk && !hrvOk) {
      reasons.add('HRV 对稳定度要求更高，本次不展示 HRV');
    }

    return _PpgGateResult(
      grade: grade,
      hrOk: hrOk,
      hrvOk: hrvOk,
      hrConfidence0To1: hrConf,
      hrvConfidence0To1: hrvConf,
      reasons: reasons.take(5).toList(growable: false),
      message: msg,
      fsHz: fs,
      fpsCv: fpsCv,
      specQ: specQ,
      specBpm: specBpm,
      bpm: bpm,
    );
  }

  Future<void> _finishMeasurement() async {
    setState(() => _measuring = false);

    final torchDuringMeasurement = _torchEnabled;

    // stop stream & torch
    await _stopCamera();

    if (_samples.length < 120 || _tsMs.length != _samples.length) {
      setState(() {
        _ppgError = '采样不足，请保持手指稳定并重试';
        _ppgQualityLabel = _ppgGradeLabelCn('invalid');
        _ppgQualityReasons = const ['采样不足'];
      });
      await SelfHelpLogger.log('WARN', 'ppg', 'not_enough_samples', extra: {
        'samples': _samples.length,
      });
      return;
    }

    // Estimate sample rate from timestamps
    final dtTotal = (_tsMs.last - _tsMs.first).clamp(1, 1 << 31);
    final fs = (_samples.length - 1) * 1000.0 / dtTotal;

    if (fs < 8 || fs > 90) {
      setState(() {
        _ppgError = '采样帧率异常（${fs.toStringAsFixed(1)} Hz），请重试';
        _ppgQualityLabel = _ppgGradeLabelCn('invalid');
        _ppgQualityReasons = const ['采样帧率异常'];
      });
      await SelfHelpLogger.log('WARN', 'ppg', 'bad_fps', extra: {'fs': fs, 'samples': _samples.length});
      return;
    }

    // Detrend + filter
    // Trim a small head/tail window to reduce settling and end-of-test motion.
    // (Wearables typically use longer windows; this helps 30s phone measurements.)
    int trimStartMs = _tsMs.first + 2000; // drop first 2s
    int trimEndMs = _tsMs.last - 500; // drop last 0.5s
    if (trimEndMs > trimStartMs + 4000) {
      final i0 = _tsMs.indexWhere((t) => t >= trimStartMs);
      int i1 = _tsMs.lastIndexWhere((t) => t <= trimEndMs);
      if (i0 >= 0 && i1 > i0 + 50) {
        final s2 = _samples.sublist(i0, i1 + 1);
        final t2 = _tsMs.sublist(i0, i1 + 1);
        _samples
          ..clear()
          ..addAll(s2);
        _tsMs
          ..clear()
          ..addAll(t2);
      }
    }

    final mean = _samples.reduce((a, b) => a + b) / _samples.length;
    final x0 = _samples.map((v) => v - mean).toList(growable: false);
    final filt = _ppg.bandpassZeroPhase(x0, fs);
    final sm = _ppg.movingAverage(filt, (fs * 0.15).round());
    List<double> smUsed = sm;

    // Peak detection (multi-threshold + prominence fallback)
    // Some devices smooth the camera stream heavily, reducing apparent peak
    // prominence. We progressively relax both threshold (k) and prominence.
    List<int> peaks = _ppg.findPeaks(smUsed, fs: fs, k: 0.60, promFactor: 0.12);
    if (peaks.length < 3) {
      final p2 = _ppg.findPeaks(smUsed, fs: fs, k: 0.45, promFactor: 0.10);
      if (p2.length > peaks.length) peaks = p2;
    }
    if (peaks.length < 3) {
      final p3 = _ppg.findPeaks(smUsed, fs: fs, k: 0.35, promFactor: 0.08);
      if (p3.length > peaks.length) peaks = p3;
    }
    if (peaks.length < 3) {
      final p4 = _ppg.findPeaks(smUsed, fs: fs, k: 0.25, promFactor: 0.06);
      if (p4.length > peaks.length) peaks = p4;
    }

    var hrHrv = _ppg.computeHrAndHrv(peaks: peaks, fs: fs, waveform: smUsed);
    var sqi = _ppg.signalQuality(filtered: smUsed, peaks: peaks, fs: fs);

    double? bpm = hrHrv['bpm'];
    double? rmssd = hrHrv['rmssd'];

    // Some devices produce inverted waveform (pulse as trough).
    if (bpm == null || bpm < 35 || bpm > 200) {
      final smInv = sm.map((v) => -v).toList(growable: false);
      List<int> peaksInv = _ppg.findPeaks(smInv, fs: fs, k: 0.60, promFactor: 0.12);
      if (peaksInv.length < 3) {
        final p2 = _ppg.findPeaks(smInv, fs: fs, k: 0.45, promFactor: 0.10);
        if (p2.length > peaksInv.length) peaksInv = p2;
      }
      if (peaksInv.length < 3) {
        final p3 = _ppg.findPeaks(smInv, fs: fs, k: 0.35, promFactor: 0.08);
        if (p3.length > peaksInv.length) peaksInv = p3;
      }
      if (peaksInv.length < 3) {
        final p4 = _ppg.findPeaks(smInv, fs: fs, k: 0.25, promFactor: 0.06);
        if (p4.length > peaksInv.length) peaksInv = p4;
      }
      final hrHrvInv = _ppg.computeHrAndHrv(peaks: peaksInv, fs: fs, waveform: smInv);
      final bpmInv = hrHrvInv['bpm'];
      if (bpmInv != null && bpmInv >= 35 && bpmInv <= 200) {
        peaks = peaksInv;
        hrHrv = hrHrvInv;
        smUsed = smInv;
        sqi = _ppg.signalQuality(filtered: smUsed, peaks: peaksInv, fs: fs);
        bpm = bpmInv;
        rmssd = hrHrvInv['rmssd'];
      }
    }

    // Spectral estimate (Goertzel). We use it in three cases:
    // 1) Peak detection fails -> fallback HR;
    // 2) Peak detection returns too few peaks -> track peaks to unlock HRV;
    // 3) Peak-based HR has a likely 1/2x or 2x alias -> correct using spectrum.
    final est = PpgProcessor.estimateBpmByGoertzel(smUsed, fs);
    final specBpm = est['bpm'];
    final specQ = est['quality'];

    if (specBpm != null && specBpm >= 35 && specBpm <= 200) {
      // (1) Pure fallback
      if (bpm == null || bpm < 35 || bpm > 200) {
        bpm = specBpm;
      }

      // (2)(3) Peak tracking when HRV is missing or alias is likely.
      final needMorePeaks = peaks.length < 4 || rmssd == null;
      final diff = (bpm != null) ? (bpm! - specBpm).abs() : 999.0;
      final likelyAlias = (bpm != null) && (specQ ?? 0.0) >= 0.45 && diff > 12 &&
          ((((bpm! * 2) - specBpm).abs() < 7) || (((bpm! / 2) - specBpm).abs() < 7));

      if ((needMorePeaks && (specQ ?? 0.0) >= 0.30) || likelyAlias) {
        final tracked = _ppg.trackPeaksByBpm(smUsed, fs: fs, bpm: specBpm);
        if (tracked.length >= 3 && tracked.length >= peaks.length) {
          final h2 = _ppg.computeHrAndHrv(peaks: tracked, fs: fs, waveform: smUsed);
          final b2 = h2['bpm'];
          if (b2 != null && b2 >= 35 && b2 <= 200) {
            peaks = tracked;
            hrHrv = h2;
            bpm = b2;
            rmssd = h2['rmssd'];
            sqi = _ppg.signalQuality(filtered: smUsed, peaks: peaks, fs: fs);
          }
        }
      }
    }

    if (specQ != null) {
      // Blend spectral quality in when peak-based SQI is low.
      sqi = math.max(sqi, (specQ * 0.55).clamp(0.0, 1.0));
    }

    // Still no plausible HR -> hard failure with actionable hints.
    if (bpm == null || bpm < 35 || bpm > 200) {
      double range0(List<double> xs) {
        if (xs.isEmpty) return 0.0;
        final maxV = xs.reduce(math.max);
        final minV = xs.reduce(math.min);
        return (maxV - minV).abs();
      }

      final rawRange = range0(_samples);
      final rawMean = _samples.reduce((a, b) => a + b) / _samples.length;
      final flat = rawRange < 0.01;
      String hint;

      if (rawMean > 0.97) {
        hint = '可能过亮/饱和：请轻压覆盖镜头（不要用力挤压），尽量避免漏光；如可选可关闭闪光灯或调暗环境光后重试。';
      } else if (rawMean < (torchDuringMeasurement ? 0.02 : 0.12)) {
        hint =
            '信号偏暗：请确认手指完全覆盖镜头与闪光灯并轻压覆盖（不要用力挤压/不要漏光）。此提示与白天/夜晚环境亮度关系不大，主要取决于镜头下通过手指接收到的光强。';
      } else if (!torchDuringMeasurement && flat) {
        hint = '当前设备可能未开启/不支持持续闪光灯，且信号变化很小；请靠近光源、轻压覆盖镜头并保持手指不动重试。';
      } else if (flat) {
        hint = '信号变化很小：请确保手指同时覆盖镜头和闪光灯、保持手指不动、不要用力挤压、避免漏光后重试。';
      } else {
        hint = '未能识别到稳定心率：请保持手指不动、轻压覆盖镜头和闪光灯、避免漏光后重试。';
      }

      setState(() {
        _ppgError = hint;
        _bpm = null;
        _rmssd = null;
        _sqi = sqi.clamp(0.0, 1.0);
        _ppgQualityLabel = _ppgGradeLabelCn('invalid');
        _ppgQualityReasons = const ['未能识别稳定心率'];
      });

      await SelfHelpLogger.log('WARN', 'ppg', 'no_hr', extra: {
        'fs': fs,
        'samples': _samples.length,
        'rawMean': rawMean,
        'rawRange': rawRange,
        'torch': torchDuringMeasurement,
        'mode': _ppgSignalMode.toString(),
        'sqi': sqi,
        'specQ': specQ,
      });
      return;
    }
    // 商用级“质量门控”：HR 可弱门控；HRV 强门控（对抖动/运动非常敏感）。
    final sqiClamped = sqi.clamp(0.0, 1.0);

    final gate = _evaluatePpgGate(
      raw01: _samples,
      waveform: smUsed,
      tsMs: _tsMs,
      fs: fs,
      peaks: peaks.length,
      bpm: bpm,
      rmssd: rmssd,
      sqi: sqiClamped,
      specBpm: specBpm,
      specQ: specQ,
      torchDuringMeasurement: torchDuringMeasurement,
    );

    final rmssdClamped = (!gate.hrvOk || rmssd == null) ? null : rmssd.clamp(5.0, 200.0).toDouble();
    final bpmFinal = gate.hrOk ? bpm : null;

    setState(() {
      _bpm = bpmFinal;
      _rmssd = rmssdClamped;
      _sqi = sqiClamped;
      _ppgQualityLabel = _ppgGradeLabelCn(gate.grade);
      _ppgQualityReasons = gate.reasons;
      _ppgError = gate.message;
    });

    await SelfHelpLogger.log('INFO', 'ppg', 'result', extra: {
      'fs': fs,
      'samples': _samples.length,
      'mode': _ppgSignalMode.toString(),
      'torch': torchDuringMeasurement,
      'bpm': bpmFinal,
      'rmssd': rmssdClamped,
      'sqi': sqiClamped,
      'peaks': peaks.length,
      'specBpm': specBpm,
      'specQ': specQ,
      'fpsCv': gate.fpsCv,
      'grade': gate.grade,
      'hrOk': gate.hrOk,
      'hrvOk': gate.hrvOk,
      'hrConf': gate.hrConfidence0To1,
      'hrvConf': gate.hrvConfidence0To1,
      'reasons': gate.reasons,
    });
  }

  Future<void> _stopCamera() async {
    // Camera2 native path (Android)
    if (_usingCamera2) {
      _usingCamera2 = false;
      _cam2TextureId = null;
      _cam2PreviewAspectRatio = null;
      _warmupDone = false;
      _measureStartWallMs = 0;
      try {
        await _cam2Sub?.cancel();
      } catch (_) {}
      _cam2Sub = null;
      try {
        await PpgCamera2Bridge.stop();
      } catch (_) {}
      _torchEnabled = false;
      _liveFps = null;
      return;
    }

    final ctrl = _cam;
    _cam = null;
    if (ctrl == null) return;
    try {
      // Some devices keep the torch on if we only dispose the controller.
      // We therefore try to turn it off both before and after stopping the stream.
      try {
        await ctrl.setFlashMode(FlashMode.off);
      } catch (_) {}

      try {
        if (ctrl.value.isStreamingImages) {
          await ctrl.stopImageStream();
        }
      } catch (_) {}

      try {
        await ctrl.setFlashMode(FlashMode.off);
      } catch (_) {}

      await ctrl.dispose();
    } catch (_) {
      // ignore
    }
  }

  double _meanLumaFromYuv420(CameraImage img) {
    // Finger-on-camera PPG is very sensitive to motion and non-uniform lighting.
    // Sampling a small center ROI (rather than the whole frame) usually reduces
    // noise from edges and improves stability.
    final plane = img.planes[0]; // Y plane (luma)
    final bytes = plane.bytes;
    if (bytes.isEmpty) return 0.0;

    final int w = img.width;
    final int h = img.height;
    final int rowStride = plane.bytesPerRow;

    final int x0 = (w * 0.35).floor();
    final int x1 = (w * 0.65).floor();
    final int y0 = (h * 0.35).floor();
    final int y1 = (h * 0.65).floor();

    final int xStep = math.max(1, ((x1 - x0) / 50).floor());
    final int yStep = math.max(1, ((y1 - y0) / 50).floor());

    int sum = 0;
    int cnt = 0;
    final int len = bytes.length;
    for (int y = y0; y < y1; y += yStep) {
      final int row = y * rowStride;
      for (int x = x0; x < x1; x += xStep) {
        final int idx = row + x;
        if (idx >= 0 && idx < len) {
          sum += bytes[idx];
          cnt++;
        }
      }
    }
    if (cnt == 0) return 0.0;
    return sum / cnt;
  }


  // =======================
  // Fitbit
  // =======================

  Future<FitbitClient?> _fitbitClient() async {
    final id = (await _kv.getString('fitbit_client_id'))?.trim() ?? '';
    final sec = (await _kv.getString('fitbit_client_secret'))?.trim() ?? '';
    if (id.isEmpty || sec.isEmpty) return null;
    return FitbitClient(clientId: id, clientSecret: sec);
  }

  Future<void> _connectFitbit() async {
    final client = await _fitbitClient();
    if (client == null) {
      if (!mounted) return;
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const FitbitSettingsPage()));
      return;
    }
    setState(() {
      _fitbitSyncing = true;
      _fitbitStatus = '正在连接 Fitbit…';
    });
    try {
      await client.connect();
      setState(() => _fitbitStatus = '已连接');
    } catch (e) {
      setState(() => _fitbitStatus = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _fitbitSyncing = false);
    }
  }

  Future<void> _syncFitbitToday() async {
    final client = await _fitbitClient();
    if (client == null) {
      if (!mounted) return;
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const FitbitSettingsPage()));
      return;
    }
    setState(() {
      _fitbitSyncing = true;
      _fitbitStatus = '同步今日数据…';
    });
    try {
      await client.syncToday();
      final now = DateTime.now();
      final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final caches = await _fitbitDao.listCachesForDate(date);
      final endpoints = <String>[];
      for (final c in caches) {
        final ep = (c['endpoint'] ?? '')?.toString() ?? '';
        if (ep.isNotEmpty) endpoints.add(ep);
      }
      endpoints.sort();
      final metrics = await FitbitMetrics.load(dao: _fitbitDao, date: date);
      setState(() {
        _fitbitCacheCount = caches.length;
        _fitbitCachedEndpoints = endpoints.toSet().toList(growable: false);
        final hasAny = metrics.restingHeartRate != null ||
            metrics.currentHeartRate != null ||
            metrics.hrvRmssdMs != null ||
            metrics.sleepMinutes != null ||
            metrics.breathingRate != null;
        _fitbitMetrics = hasAny ? metrics : null;
        _fitbitStatus = '同步完成（${caches.length} 项）';
      });
    } catch (e) {
      setState(() => _fitbitStatus = '同步失败：$e');
    } finally {
      if (mounted) setState(() => _fitbitSyncing = false);
    }
  }

  // =======================
  // Save record
  // =======================

  Future<void> _save() async {
    final raw = _stai6Raw();
    final prorated = _stai6Prorated();
    final inputs = ArousalInputs(
      stai6Prorated: prorated,
      arousal0To100: _arousal,
      valence0To100: _valence,
      demand0To100: _demand,
      resources0To100: _resources,
      distress0To100: _distress,
      ppgBpm: _bpm,
      ppgRmssdMs: _rmssd,
      ppgSignalQuality: _sqi,
      fitbit: _fitbitMetrics,
      baselineRestingHr: _baselineRestingHr,
      baselineRmssdMs: _baselineRmssdMs,
    );
    final res = ArousalModel.compute(inputs);
    _lastComputed = res;
    await _dao.insertRecord(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      stai6Score: raw,
      stai6Prorated: prorated,
      arousal0To100: _arousal,
      valence0To100: _valence,
      demand0To100: _demand,
      resources0To100: _resources,
      distress0To100: _distress,
      bpm: _bpm,
      rmssdMs: _rmssd,
      signalQuality: _sqi,
      arousal0To10: res.arousal0To10,
      confidence0To1: res.confidence0To1,
      subjectiveIndex0To1: res.subjectiveIndex0To1,
      physiologicalIndex0To1: res.physiologicalIndex0To1,
      modelVersion: kArousalModelVersion,
      modelExplain: res.explanation,
      warningsJson: res.warningsJson(),
      fitbitRestingBpm: _fitbitMetrics?.restingHeartRate,
      fitbitCurrentBpm: _fitbitMetrics?.currentHeartRate,
      fitbitHrvRmssdMs: _fitbitMetrics?.hrvRmssdMs,
      fitbitBreathingRate: _fitbitMetrics?.breathingRate,
      fitbitSleepMinutes: _fitbitMetrics?.sleepMinutes,
      fitbitSleepEfficiency: _fitbitMetrics?.sleepEfficiency,
      fitbitSteps: _fitbitMetrics?.steps,
      fitbitSpo2Avg: _fitbitMetrics?.spo2Avg,
      fitbitSkinTempDev: _fitbitMetrics?.skinTempDeviation,
      fitbitActiveZoneMinutes: _fitbitMetrics?.activeZoneMinutes,
      fitbitCardioScore: _fitbitMetrics?.cardioScore,
      zone: res.zoneLabel,
      note: null,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存测评记录')));
    await _reloadBaselinesAndFitbit();
    if (mounted) setState(() {});
  }

  // =======================
  // UI
  // =======================

  @override
  Widget build(BuildContext context) {
    final inputs = ArousalInputs(
      stai6Prorated: _stai6Prorated(),
      arousal0To100: _arousal,
      valence0To100: _valence,
      demand0To100: _demand,
      resources0To100: _resources,
      distress0To100: _distress,
      ppgBpm: _bpm,
      ppgRmssdMs: _rmssd,
      ppgSignalQuality: _sqi,
      fitbit: _fitbitMetrics,
      baselineRestingHr: _baselineRestingHr,
      baselineRmssdMs: _baselineRmssdMs,
    );
    final res = ArousalModel.compute(inputs);
    _lastComputed = res;
    final advice = _zoneAdvice(res.zoneLabel);
    return Scaffold(
      appBar: AppBar(
        title: const Text('改变 · 心理自助'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const FitbitSettingsPage()));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('主观评估（更科学）'),
          const SizedBox(height: 8),
          _buildStai6(),
          const SizedBox(height: 12),
          _buildAffectiveSlider(),
          const SizedBox(height: 12),
          _buildZoneSelfCheck(),
          const SizedBox(height: 20),
          _sectionTitle('客观测量（摄像头 PPG）'),
          const SizedBox(height: 8),
          _buildPpgCard(),
          const SizedBox(height: 16),
          _sectionTitle('可穿戴设备（Fitbit，可选）'),
          const SizedBox(height: 8),
          _buildFitbitCard(),
          const SizedBox(height: 16),
          _sectionTitle('结果'),
          const SizedBox(height: 8),
          _buildResult(res, advice),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存本次测评'),
          ),
          const SizedBox(height: 8),
          const Text(
            '免责声明：本功能仅用于情绪/压力自助与习惯养成参考，不用于医学诊断。\n若出现持续强烈不适或自伤想法，请及时求助专业机构/紧急电话。',
            style: TextStyle(color: Colors.black54, height: 1.4, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
  }

  Widget _buildStai6() {
    final items = const [
      '我感到平静',
      '我感到紧张',
      '我感到心烦/不安',
      '我感到放松',
      '我感到满足',
      '我感到担忧',
    ];
    final opts = const ['一点也不', '有一点', '相当', '非常'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('STAI-6（状态焦虑短表，最近“此刻”）', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('每题 1-4 分。系统会对正向题做反向计分，并换算到 20-80 的 STAI 区间。', style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
            const SizedBox(height: 8),
            for (int i = 0; i < items.length; i++) ...[
              Text(items[i], style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (int k = 0; k < 4; k++)
                    ChoiceChip(
                      label: Text(opts[k]),
                      selected: _stai6[i] == (k + 1),
                      onSelected: (_) => setState(() => _stai6[i] = (k + 1)),
                    ),
                ],
              ),
              const Divider(height: 18),
            ],
            Text('STAI-6 原始分：${_stai6Raw()}（6-24）  ·  换算：${_stai6Prorated().toStringAsFixed(1)}（20-80）',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildAffectiveSlider() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Affective Slider（移动端情绪自评）', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('用两条滑杆快速评估：唤醒程度（强度）与愉悦程度（正/负）。', style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text('😴 低唤醒'), Text('唤醒'), Text('😳 高唤醒')],
            ),
            Slider(
              value: _arousal,
              min: 0,
              max: 100,
              divisions: 100,
              label: _arousal.round().toString(),
              onChanged: (v) => setState(() => _arousal = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text('🙁 负性'), Text('愉悦'), Text('🙂 正性')],
            ),
            Slider(
              value: _valence,
              min: 0,
              max: 100,
              divisions: 100,
              label: _valence.round().toString(),
              onChanged: (v) => setState(() => _valence = v),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildZoneSelfCheck() {
    final gap = ((_demand - _resources) / 100.0).clamp(-1.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('三区自评（舒适区 / 学习区 / 恐慌区）', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              '''用“需求-资源”与“困扰强度”来刻画：
• 需求/挑战：事情对你的压力/难度
• 资源/掌控：你感觉自己能否应对
• 困扰强度：此刻的不适/紧张有多强（SUDS）
系统会把它们与 STAI-6、唤醒以及心率/HRV 结合，给出区间判断。''',
              style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text('轻松'), Text('需求/挑战'), Text('很难')],
            ),
            Slider(
              value: _demand,
              min: 0,
              max: 100,
              divisions: 100,
              label: _demand.round().toString(),
              onChanged: (v) => setState(() => _demand = v),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text('无把握'), Text('资源/掌控'), Text('很有把握')],
            ),
            Slider(
              value: _resources,
              min: 0,
              max: 100,
              divisions: 100,
              label: _resources.round().toString(),
              onChanged: (v) => setState(() => _resources = v),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [Text('几乎没有'), Text('困扰强度'), Text('非常强')],
            ),
            Slider(
              value: _distress,
              min: 0,
              max: 100,
              divisions: 100,
              label: _distress.round().toString(),
              onChanged: (v) => setState(() => _distress = v),
            ),

            const SizedBox(height: 6),
            Text(
              '挑战-资源差距：${(gap * 10).toStringAsFixed(1)}/10（越大越可能“超载”）',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPpgCard() {
    final ctrl = _cam;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('用指腹轻盖住后置摄像头与闪光灯，保持稳定约 30 秒。', style: TextStyle(height: 1.4)),
            const SizedBox(height: 10),
            if (_usingCamera2 && _cam2TextureId != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: _cam2PreviewAspectRatio ?? (4.0 / 3.0),
                  child: Texture(textureId: _cam2TextureId!),
                ),
              )
            else if (ctrl != null && ctrl.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: ctrl.value.aspectRatio,
                  child: CameraPreview(ctrl),
                ),
              )
            else
              Container(
                height: 160,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('相机预览'),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _measuring ? null : _startMeasurement,
                    icon: const Icon(Icons.favorite_border),
                    label: Text(_measuring ? '测量中… $_secondsLeft s' : '开始测量'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _measuring
                      ? () async {
                          _ticker?.cancel();
                          await _finishMeasurement();
                        }
                      : null,
                  child: const Text('提前结束'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_ppgError != null)
              Text(
                _ppgError!,
                style: TextStyle(
                  color: (_ppgQualityLabel == '无效' ||
                          _ppgError!.contains('无效') ||
                          _ppgError!.contains('异常') ||
                          _ppgError!.contains('未能') ||
                          _ppgError!.contains('失败'))
                      ? Colors.redAccent
                      : Colors.black54,
                  height: 1.3,
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _metricChip('心率', _bpm == null ? '--' : '${_bpm!.toStringAsFixed(1)} bpm'),
                _metricChip('HRV(RMSSD)', _rmssd == null ? '--' : '${_rmssd!.toStringAsFixed(1)} ms'),
                _metricChip('信号质量', _sqi == null ? '--' : 'SQI ${_sqi!.toStringAsFixed(2)}'),
                _metricChip('可信度', _ppgQualityLabel ?? '--'),
              ],
            ),
            if (!_measuring && _ppgQualityReasons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '质量原因：${_ppgQualityReasons.take(2).join('；')}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.3),
                ),
              ),
            const SizedBox(height: 8),
            const Text('提示：若结果波动大，多数是因为按压不稳/漏光/手指移动/过度挤压；请“轻压覆盖”，不要用力挤压；手指保持温暖，运动后先休息 2–3 分钟再测。',
                style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildFitbitCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _fitbitSyncing ? null : _connectFitbit,
                    icon: const Icon(Icons.link),
                    label: const Text('连接 Fitbit'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _fitbitSyncing ? null : _syncFitbitToday,
                  child: const Text('同步今日'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_fitbitStatus != null)
              Text(_fitbitStatus!, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            if (_fitbitCacheCount > 0)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                title: Text('已同步数据源（$_fitbitCacheCount 项）', style: const TextStyle(fontSize: 14)),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _fitbitCachedEndpoints.take(16).map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 12)))).toList(growable: false),
                  ),
                  if (_fitbitCachedEndpoints.length > 16)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('…以及其他 ${_fitbitCachedEndpoints.length - 16} 项', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ),
                ],
              ),

            const Text(
              '同步后会把 Fitbit 的原始 JSON 缓存到本地数据库，用于后续综合评估（睡眠 HRV、心率趋势、活动量等）。',
              style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ArousalResult res, String advice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '综合唤醒 ${res.arousal0To10.toStringAsFixed(1)}/10',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  '置信度 ${(res.confidence0To1 * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (res.arousal0To10 / 10.0).clamp(0.0, 1.0),
              minHeight: 8,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _metricChip('区间', res.zoneLabel),
                _metricChip('主观', '${(res.subjectiveIndex0To1 * 10).toStringAsFixed(1)}/10'),
                _metricChip('客观', '${(res.physiologicalIndex0To1 * 10).toStringAsFixed(1)}/10'),
                _metricChip('需求', '${(_demand / 10).toStringAsFixed(1)}/10'),
                _metricChip('资源', '${(_resources / 10).toStringAsFixed(1)}/10'),
                _metricChip('困扰', '${(_distress / 10).toStringAsFixed(1)}/10'),
              ],
            ),
            const SizedBox(height: 10),
            Text(advice, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 10),
            Text(res.explanation, style: const TextStyle(color: Colors.black87, fontSize: 12, height: 1.4)),
            if (res.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: res.warnings
                    .map((w) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('• $w', style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
                        ))
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ChangeSelfHelpReportPage()));
                  },
                  icon: const Icon(Icons.show_chart_outlined),
                  label: const Text('趋势报告'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ChangeInterventionPage(zone: res.zoneLabel, arousal0To10: res.arousal0To10)));
                  },
                  icon: const Icon(Icons.self_improvement_outlined),
                  label: const Text('干预建议'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
