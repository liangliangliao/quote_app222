import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import '../services/sport_music_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/dao.dart';
import '../data/sport_dao.dart';
import '../services/native_sport_fg.dart';
import '../services/sport_bg_tracker.dart';
import '../services/location_service.dart';
import 'sport_detail_page.dart';

/// 运动进行中页
///
/// 关键特性（对齐需求）：
/// - 支持计划/非计划记录恢复：从 sport_records 读取并恢复步数/距离/用时/状态
/// - 进程被杀后：record(in_progress) 在启动时被置为 paused（由 SportDao.markInProgressAsPaused）；
///   进入本页会直接恢复暂停态并允许继续
/// - 步数：优先使用 Android StepCounter 传感器（EventChannel），避免 GPS 估算造成延迟/不准
/// - 运动过程中周期性持久化（每 3 秒一次 + 状态变更时）防止数据丢失
class SportRunningPage extends StatefulWidget {
  final int recordId;
  final Map<String, dynamic>? plan;
  final String mode; // plan / instant

  const SportRunningPage({
    super.key,
    required this.recordId,
    this.plan,
    required this.mode,
  });

  @override
  State<SportRunningPage> createState() => _SportRunningPageState();
}

class _SportRunningPageState extends State<SportRunningPage> {
  final SportDao _dao = SportDao();
  final ConfigDao _configDao = ConfigDao();

  static const MethodChannel _sys = MethodChannel('com.example.quote_app/sys');
  static const EventChannel _stepsCh = EventChannel('com.example.quote_app/steps');

  final AudioPlayer _audioPlayer = AudioPlayer();
  // Background music playlist (loop)
  List<String> _musicPlaylist = <String>[];
  String _musicMode = 'order'; // order / random
  int _musicIndex = 0;
  bool _musicStarted = false;
  final Random _musicRandom = Random();

  // UI settings
  String? _bgImagePath;
  String? _startSoundPath;
  Map<String, List<String>> _musicBgBindings = <String, List<String>>{};
  List<String> _activeBgImages = <String>[];
  int _activeBgIndex = 0;
  Timer? _bgRotateTimer;
  static const Duration _bgRotateInterval = Duration(seconds: 10);

  // Quote
  String _quoteContent = '生命在于运动';
  String _quoteAuthor = '';
  String _quoteExplanation = '';

  // State
  String _status = 'loading'; // not_started / in_progress / paused / stopped / completed
  int _countdown = 5;
  bool _inCountdownPhase = false;
  bool _ready = false;

  // Display title for this running session (shown on the page and used by notification).
  String _displayTitle = '运动进行中';

  // Actual start timestamp (written when countdown ends or when restart begins).
  String? _startedAtIso;


  // Progress
  double _distance = 0.0; // meters
  int _steps = 0;
  int _stepsOffset = 0; // for sensor reset on resume
  int _elapsedOffsetSec = 0; // persisted elapsed seconds
  final Stopwatch _segmentWatch = Stopwatch();

  // Native foreground (Android/iOS) elapsed smoothing for UI:
  // DB may update with jitter; we keep a local stopwatch so the UI seconds tick
  // smoothly and pause freezes immediately.
  int _nativeElapsedBaseSec = 0;
  final Stopwatch _nativeElapsedWatch = Stopwatch();
  String _nativeElapsedClockStatus = '';

  // Location
  Position? _lastPosition;
  Position? _startPosition;
  StreamSubscription<Position>? _posSub;
  String? _startLocName, _startLocAddr, _endLocName, _endLocAddr;
// Duplicate declaration removed: StreamSubscription<Position>? _posSub;
  DateTime? _lastPosTs;

  // For distance/speed: track accepted points to suppress GPS drift while stationary.
  Position? _lastAcceptedPosition;
  DateTime? _lastAcceptedTs;
  int _stationaryStreak = 0;

  // Pending movement confirmation window (to suppress GPS drift spikes while stationary).
  Position? _pendingPosition;
  DateTime? _pendingPositionTs;
  DateTime? _pendingStartTs;
  double _pendingDistance = 0.0;
  int _pendingCount = 0;
  int _pendingStartSteps = 0;
  DateTime? _inProgressStartedAt;

  double _currentSpeedMps = 0.0;


  // Steps
  StreamSubscription<dynamic>? _stepsSub;
  bool _sensorStepsActive = false;

  // Timers
  Timer? _countdownTimer;
  Timer? _uiTimer;
  Timer? _persistTimer;
  StreamSubscription<void>? _musicChangeSub;

  // Guard to avoid overlapping DB refreshes (prevents status/music race).
  bool _dbRefreshing = false;

  // Manual status override window to avoid DB stale status overriding user actions.
  String? _manualStatusOverride;
  int _manualStatusOverrideUntilMs = 0;

  // Background/restore support:
  // - Android: keep collecting via native foreground service even if page is left or app task removed.
  // - iOS/others: keep collecting within the same process via a Dart singleton tracker when leaving this page.
  bool _nativeFgMode = false; // Android-only native foreground mode
  Timer? _dbPollTimer;
  int _dbPollIntervalSec = 1;
  double _currentSpeedKmh = 0.0;


  // Plan
  int? _planId;
  Map<String, dynamic>? _loadedPlan;

  Map<String, dynamic>? get _plan => widget.plan ?? _loadedPlan;
  String get _targetType => (_plan?['target_type'] ?? 'steps').toString();
  double? get _targetValue => _plan?['target_value'] is num ? (_plan?['target_value'] as num).toDouble() : null;
  String get _targetUnit => (_plan?['target_unit'] ?? '步').toString();

  Duration get _totalElapsed {
    if (_nativeFgMode) {
      final base = _nativeElapsedBaseSec;
      final add = (_nativeElapsedClockStatus == 'in_progress')
          ? _nativeElapsedWatch.elapsed.inSeconds
          : 0;
      return Duration(seconds: base + add);
    }
    return Duration(seconds: _elapsedOffsetSec + _segmentWatch.elapsed.inSeconds);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _initLocationPerm();
    await _loadUiSettings();
    await _loadQuote();
    await _restoreFromRecord();

    _musicChangeSub = SportMusicService.instance.onChanged.listen((_) {
      _syncBackgroundWithMusic();
    });

    // NOTE: For performance/battery, do not auto-sync music settings changes from Settings
    // during an active workout. Settings will take effect next time the workout starts.

    // Ensure we don't double-count if a background tracker was running while this page was not visible.
    // ignore: discarded_futures
    SportBgTracker.instance.stopIfRunning(widget.recordId);

    if (!mounted) return;
    setState(() {
      _ready = true;
    });
    // On Android/iOS, immediately start the native foreground service so that
    // the persistent notification appears even before countdown or resuming.
    if (Platform.isAndroid || Platform.isIOS) {
      _nativeFgMode = true;
      await NativeSportFg.ensureStarted(
        recordId: widget.recordId,
        title: _displayTitle,
        targetType: (_plan?['target_type'] ?? widget.plan?['target_type'])?.toString(),
        targetValue: (() {
          final v = _plan?['target_value'] ?? widget.plan?['target_value'];
          if (v is num) return v.toDouble();
          return double.tryParse(v?.toString() ?? '');
        })(),
        targetUnit: (_plan?['target_unit'] ?? widget.plan?['target_unit'])?.toString(),
      );
      // Start DB polling and refresh immediately so UI reflects current progress.
      _startDbPollTimer(intervalSec: 1);
      // ignore: discarded_futures
      await _refreshFromDb();
    }
    // Prestart: start 5s countdown when start_time is empty (actual start moment is after countdown).
    final bool needsCountdown = (_startedAtIso == null || _startedAtIso!.isEmpty) &&
        (_status == 'not_started' || _status == 'queued' || _status == 'in_progress') &&
        _elapsedOffsetSec == 0 &&
        _steps == 0 &&
        _distance == 0.0;

    if (needsCountdown) {
      // Normalize record status so running page is only entered for in_progress/paused.
      if (_status != 'in_progress') {
        _status = 'in_progress';
        try {
          await _dao.updateRecord(widget.recordId, {
            'status': 'in_progress',
            'start_time': null,
            'end_time': null,
            'updated_at': DateTime.now().toIso8601String(),
          });
          await _syncPlanStatus('in_progress');
        } catch (_) {}
      }
      _startCountdown();
    } else {
      // For resumed sessions, always start the UI timer. When using native
      // foreground tracking on Android/iOS we rely on DB polling for metrics.
      _startUiTimer();
      if (_status == 'in_progress') {
        if (!(Platform.isAndroid || Platform.isIOS)) {
          // For non-Android/iOS platforms, resume in-page sensors.
          _resumeRunning(startTimers: true);
        }
      }
    }
  }

  Future<void> _initLocationPerm() async {
    try {
      // Request permission proactively; some devices won't start streams otherwise.
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        // Can't force-enable here; just return and let stream fail gracefully.
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      // If deniedForever, don't spam dialogs.
    } catch (_) {}
  }

  Future<void> _loadUiSettings() async {
    try {
      final bg = await _configDao.getSportRunningBg();
      final sound = await _configDao.getSportStartSound();
      final list = await _configDao.getSportMusicPlaylist();
      final mode = await _configDao.getSportMusicMode();
      final bindings = await _configDao.getSportMusicBgBindings();
      if (!mounted) return;
      setState(() {
        _bgImagePath = (bg?.trim().isEmpty ?? true) ? null : bg;
        _startSoundPath = (sound?.trim().isEmpty ?? true) ? null : sound;
        _musicPlaylist = list;
        _musicMode = (mode == 'random') ? 'random' : 'order';
        _musicBgBindings = bindings;
      });

      // Setup playlist (global service) so music can continue across pages.
      await SportMusicService.instance.configure(playlist: list, mode: _musicMode);
      _syncBackgroundWithMusic();
    } catch (_) {}
  }

  void _syncBackgroundWithMusic() {
    if (!mounted) return;
    final currentMusic = SportMusicService.instance.currentPath;
    final List<String> images = List<String>.from(_musicBgBindings[currentMusic] ?? const <String>[]).where((e) => e.trim().isNotEmpty && File(e).existsSync()).toList();
    _bgRotateTimer?.cancel();
    if (images.isEmpty) {
      setState(() {
        _activeBgImages = <String>[];
        _activeBgIndex = 0;
        _bgImagePath = null;
      });
      return;
    }
    setState(() {
      _activeBgImages = images;
      _activeBgIndex = 0;
      _bgImagePath = images.first;
    });
    if (images.length > 1) {
      _bgRotateTimer = Timer.periodic(_bgRotateInterval, (_) {
        if (!mounted || _activeBgImages.isEmpty) return;
        setState(() {
          _activeBgIndex = (_activeBgIndex + 1) % _activeBgImages.length;
          _bgImagePath = _activeBgImages[_activeBgIndex];
        });
      });
    }
  }

  Future<void> _loadQuote() async {
    try {
      final q = await _dao.getRandomSportQuote();
      if (q == null) return;
      if (!mounted) return;
      setState(() {
        _quoteContent = (q['content'] ?? _quoteContent).toString();
        _quoteAuthor = (q['author'] ?? '').toString();
        _quoteExplanation = (q['explanation'] ?? '').toString();
      });
    } catch (_) {}
  }

  Future<void> _restoreFromRecord() async {
    final r = await _dao.getRecord(widget.recordId);
    if (r == null) return;

    _planId = r['plan_id'] as int?;
    if (widget.plan == null && _planId != null) {
      try {
        _loadedPlan = await _dao.getPlan(_planId!);
      } catch (_) {}
    }

    final st = (r['status'] ?? 'not_started').toString();
    final startIso = (r['start_time'] ?? '').toString();
    final title = (r['title'] ?? '').toString();
    final dur = (r['total_duration'] is num) ? (r['total_duration'] as num).toInt() : 0;
    final steps = (r['total_steps'] is num) ? (r['total_steps'] as num).toInt() : 0;
    final dist = (r['total_distance'] is num) ? (r['total_distance'] as num).toDouble() : 0.0;

    // Start location
    try {
      final sl = (r['start_location'] ?? '').toString();
      if (sl.isNotEmpty) {
        final m = jsonDecode(sl);
        if (m is Map) {
          final lat = m['lat'];
          final lon = m['lon'];
          if (lat != null && lon != null) {
            _startPosition = Position(
              latitude: (lat as num).toDouble(),
              longitude: (lon as num).toDouble(),
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              floor: null,
              isMocked: false,
              headingAccuracy: 0,
              altitudeAccuracy: 0,
            );
          }
          // Restore start location name/address if present
          final name = m['name'];
          final addr = m['address'];
          if (name != null && name.toString().trim().isNotEmpty) {
            _startLocName = name.toString();
          }
          if (addr != null && addr.toString().trim().isNotEmpty) {
            _startLocAddr = addr.toString();
          }
        }
      }
    } catch (_) {}

    setState(() {
      _status = st;
      _startedAtIso = startIso.isEmpty ? null : startIso;
      _displayTitle = title.trim().isNotEmpty
          ? title
          : ((_loadedPlan?['title'] ?? widget.plan?['title'] ?? '运动进行中').toString());
      _elapsedOffsetSec = dur;
      _steps = steps;
      _distance = dist;
      _stepsOffset = steps;
    });


  }

  /// Resolve a human-friendly place name/address using the same rule for both
  /// start and end location:
  /// 1) POI lookup (nearby)
  /// 2) Reverse geocode fallback
  Future<List<String>?> _resolvePlaceByPoiFirst(Position pos) async {
    try {
      final pois = await LocationService.fetchNearbyPois(
        latitude: pos.latitude,
        longitude: pos.longitude,
        radiusMeters: 100,
        pageSize: 1,
      );
      if (pois.isNotEmpty) {
        // POI fields may be nullable (String?), but our location fields and
        // history rendering expect non-null strings.
        final String name = (pois.first.name ?? '').trim();
        final String addr = (pois.first.address ?? '').trim();

        // If the POI doesn't have any usable text, fall back to reverse geocode.
        if (name.isNotEmpty || addr.isNotEmpty) {
          return <String>[name.isNotEmpty ? name : addr, addr];
        }
      }
    } catch (_) {}
    return _revGeoName(pos.latitude, pos.longitude);
  }

  Future<void> _captureStartLocationBestEffort({bool persist = false}) async {
    try {
      Position? pos = _startPosition;
      pos ??= await LocationService.getCurrentPositionPreferBaidu(allowFallback: true);
      if (pos == null) return;
      _startPosition = pos;
      final r = await _resolvePlaceByPoiFirst(pos);
      if (r != null) {
        _startLocName = r[0];
        _startLocAddr = r[1];
      }
      if (persist) {
        await _persistProgress(reason: 'prestart');
      }
    } catch (_) {}
  }

  Future<void> _captureEndLocationBestEffort() async {
    try {
      Position? pos = _lastPosition;
      pos ??= await LocationService.getCurrentPositionPreferBaidu(allowFallback: true);
      if (pos == null) return;
      _lastPosition = pos;
      final r = await _resolvePlaceByPoiFirst(pos);
      if (r != null) {
        _endLocName = r[0];
        _endLocAddr = r[1];
      }
    } catch (_) {}
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 5;
      _inCountdownPhase = true;
    });
    // During countdown we should already capture the start location and persist it
    // for history display (best-effort).
    // ignore: discarded_futures
    _captureStartLocationBestEffort(persist: true);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      // When the countdown reaches 1, start the run immediately on the next tick
      // without rendering the intermediate "0" on the screen.  This avoids
      // showing a frozen "0" before the metrics appear.
      if (_countdown <= 1) {
        t.cancel();
        _startRunningFromCountdown();
        return;
      }
      setState(() {
        _countdown -= 1;
      });
    });
  }

  Future<void> _startRunningFromCountdown() async {
    if (!mounted) return;
    setState(() {
      _status = 'in_progress';
      _inCountdownPhase = false;
    });
    _startedAtIso = DateTime.now().toIso8601String();
    await _playStartBell();
    _segmentWatch
      ..reset()
      ..start();
    _elapsedOffsetSec = 0;
    _distance = 0.0;
    _steps = 0;
    _stepsOffset = 0;
    // Do not clear the captured start position here; keep it so it can be persisted.
    _lastPosition = null;
    _lastAcceptedPosition = null;
    _lastAcceptedTs = null;
    _stationaryStreak = 0;
    _pendingPosition = null;
    _pendingPositionTs = null;
    _pendingStartTs = null;
    _pendingDistance = 0.0;
    _pendingCount = 0;
    _pendingStartSteps = 0;
    _inProgressStartedAt = DateTime.now();

    if (Platform.isAndroid || Platform.isIOS) {
      _nativeFgMode = true;
      // Persist start fields before starting native service so it can restore correctly.
      _startUiTimer();
      await _startSensors();
      _startPersistTimer();
      await _startMusicLoopIfNeeded(reloadSettings: true);
      await _persistProgress(reason: 'start');
      await _syncPlanStatus('in_progress');
      // Start/refresh Android native foreground tracking (foreground notification + survive task removal).
      // We re-issue start here so the service can reset its sessionStartElapsed at countdown end.
      await NativeSportFg.ensureStarted(
        recordId: widget.recordId,
        title: '运动进行中',
        targetType: _targetType,
        targetValue: _targetValue,
        targetUnit: _targetUnit,
      );
      _startDbPollTimer(intervalSec: 1);
      // Pull immediately.
      // ignore: discarded_futures
      _refreshFromDb();
      return;
    }
    await _startMusicLoopIfNeeded(reloadSettings: true);
    _startUiTimer();
    _startPersistTimer();
    await _persistProgress(reason: 'start');
    await _syncPlanStatus('in_progress');
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_nativeFgMode) {
        // In native mode, metrics come from DB poll; avoid repainting every second
        // while paused to reduce power usage.
        if (_status == 'in_progress' || _inCountdownPhase) {
          setState(() {});
        }
      } else {
        setState(() {});
      }
      _checkTargetReached();
    });
  }

  Future<void> _startSensors() async {
    await _startStepStream();
    await _startLocationStream();
  }

  void _stopSensors() {
    _posSub?.cancel();
    _posSub = null;
    _stopStepStream();
  }

  Future<void> _startStepStream() async {
    // Ask runtime permission on Android 10+.
    try {
      final st = await Permission.activityRecognition.request();
      if (!st.isGranted) {
        _sensorStepsActive = false;
        return;
      }
    } catch (_) {
      // If permission_handler doesn't support the platform, ignore.
    }

    try {
      await _sys.invokeMethod('resetStepCounter');
    } catch (_) {}

    _stepsSub?.cancel();
    _sensorStepsActive = true;
    _stepsSub = _stepsCh.receiveBroadcastStream().listen((v) {
      if (!_sensorStepsActive) return;
      final x = (v is num) ? v.toInt() : int.tryParse(v.toString());
      if (x == null) return;
      if (!mounted) return;
      setState(() {
        _steps = _stepsOffset + x;
      });
    }, onError: (_) {
      _sensorStepsActive = false;
    });
  }

  void _stopStepStream() {
    _sensorStepsActive = false;
    _stepsSub?.cancel();
    _stepsSub = null;
  }

  Future<void> _startLocationStream() async {
    _posSub?.cancel();
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();
      if (!enabled || perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        // If location isn't available, keep distance at 0 but don't crash.
        return;
      }
    } catch (_) {
      // If geolocator throws, still try to subscribe; onError will handle.
    }

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        // Use a slightly larger distance filter to suppress jitter/drift.
        distanceFilter: 5,
      ),
    ).listen(
      _onPositionUpdate,
      onError: (_) {
        // If stream errors (permission revoked, GPS off...), decay speed to 0.
        _currentSpeedMps = 0.0;
      },
    );
  }

  void _onPositionUpdate(Position pos) {
    if (_status != 'in_progress') return;

    // First location as start location
    _startPosition ??= pos;

    final nowTs = pos.timestamp ?? DateTime.now();

    // Always track the raw last fix (even if we reject it for distance) to keep timestamps moving.
    final accCur = (pos.accuracy.isFinite) ? pos.accuracy : 0.0;
    _lastPosition = pos;
    _lastPosTs = nowTs;

    // Drop extremely inaccurate points early.
    // NOTE: Some devices often report 60~90m indoors; don't block all movement.
    if (accCur > 120) {
      _stationaryStreak++;
      if (_stationaryStreak >= 3) {
        _currentSpeedMps = 0.0;
      } else {
        _currentSpeedMps *= 0.85;
      }
      return;
    }

    // Initialize accepted anchor.
    _lastAcceptedPosition ??= pos;
    _lastAcceptedTs ??= nowTs;

    final lastAcc = _lastAcceptedPosition!;
    final lastAccTs = _lastAcceptedTs!;
    final accLast = (lastAcc.accuracy.isFinite) ? lastAcc.accuracy : 0.0;

    final dist = Geolocator.distanceBetween(
      lastAcc.latitude,
      lastAcc.longitude,
      pos.latitude,
      pos.longitude,
    );

    // Time delta (seconds) based on accepted anchor.
    final dtMs = nowTs.difference(lastAccTs).inMilliseconds;
    final dtSec = dtMs <= 0 ? 0.001 : dtMs / 1000.0;

    // Compute speed from distance/time; use sensor speed only if it's reasonable (often 0 on many devices).
    final computedSpeed = (dist.isFinite && dist > 0) ? (dist / dtSec) : 0.0;
    final sensorSpeed = (pos.speed.isFinite && pos.speed > 0.3) ? pos.speed : 0.0;
    final speedMps = max(computedSpeed, sensorSpeed);

    final warmupActive = _inProgressStartedAt != null &&
        nowTs.difference(_inProgressStartedAt!).inSeconds < 8;

    // Jitter / drift gate:
    // - Require displacement larger than the accuracy radius (scaled).
    // - Require a plausible speed.
    // This reduces "原地漂移" (distance grows while staying still).
    final baseAcc = max(accCur, accLast);
    final threshold = max(4.0, min(25.0, baseAcc * 1.2));

    var candidateOk = true;
    var rejectedByJitter = false;
    if (!dist.isFinite || dist <= 0) {
      candidateOk = false;
      rejectedByJitter = true;
    } else if (dist < threshold) {
      candidateOk = false;
      rejectedByJitter = true;
    } else if (dist > 120 && speedMps > 10) {
      // Huge jump with very high speed -> likely a bad fix.
      candidateOk = false;
    } else {
      // Speed gate: accept when either sensor speed is reliable,
      // or computed speed is plausible with decent accuracy.
      final okBySensor = sensorSpeed > 0.6;
      final okByComputedStrict = (computedSpeed > 0.8 && baseAcc <= 20);
      final okByComputedLoose = (computedSpeed > 1.2 && baseAcc <= 35);
      if (!(okBySensor || okByComputedStrict || okByComputedLoose)) {
        candidateOk = false;
        rejectedByJitter = true;
      }
    }

    if (candidateOk) {
      // Build a short "confirmation" window before committing distance.
      // This prevents single GPS drift spikes from immediately inflating distance.
      if (_pendingCount == 0) {
        _pendingStartTs = nowTs;
        _pendingStartSteps = _steps;
        _pendingDistance = dist;
        _pendingCount = 1;
        _pendingPosition = pos;
        _pendingPositionTs = nowTs;
      } else {
        final prev = _pendingPosition;
        if (prev != null) {
          final seg = Geolocator.distanceBetween(
            prev.latitude,
            prev.longitude,
            pos.latitude,
            pos.longitude,
          );
          if (seg.isFinite && seg > 0) {
            _pendingDistance += seg;
          }
        }
        _pendingCount += 1;
        _pendingPosition = pos;
        _pendingPositionTs = nowTs;
      }

      final pendingAgeSec = _pendingStartTs == null ? 0 : nowTs.difference(_pendingStartTs!).inSeconds;
      final stepsDelta = _steps - _pendingStartSteps;
      final hasStepEvidence = !_sensorStepsActive || stepsDelta >= 1;

      // Confirm movement: need consecutive points and enough cumulative displacement.
      final requiredCount = _sensorStepsActive ? 2 : 3;
      final requiredDistBase = _sensorStepsActive ? 10.0 : 15.0;
      final accSum = accCur + accLast;
      final requiredDist = max(requiredDistBase, min(30.0, accSum * 1.2));

      var confirmed = _pendingCount >= requiredCount &&
          _pendingDistance >= requiredDist &&
          hasStepEvidence &&
          (!warmupActive || stepsDelta >= 1);

      // If step sensor is active but there are still no steps after a while,
      // treat it as drift: move the anchor without adding distance.
      if (_sensorStepsActive && stepsDelta < 1 && pendingAgeSec >= 10) {
        confirmed = false;
        _lastAcceptedPosition = pos;
        _lastAcceptedTs = nowTs;
        _pendingPosition = null;
        _pendingPositionTs = null;
        _pendingStartTs = null;
        _pendingDistance = 0.0;
        _pendingCount = 0;
        _pendingStartSteps = _steps;
        _stationaryStreak = max(_stationaryStreak, 2);
        _currentSpeedMps = 0.0;
        return;
      }

      if (confirmed) {
        _distance += _pendingDistance;
        // Fallback step estimation when sensor unavailable
        if (!_sensorStepsActive) {
          _steps = (_distance / 0.7).floor();
        }
        _lastAcceptedPosition = _pendingPosition;
        _lastAcceptedTs = _pendingPositionTs;
        _stationaryStreak = 0;
        // Low-pass filter for display speed.
        _currentSpeedMps = _currentSpeedMps * 0.6 + speedMps * 0.4;

        // Clear pending window.
        _pendingPosition = null;
        _pendingPositionTs = null;
        _pendingStartTs = null;
        _pendingDistance = 0.0;
        _pendingCount = 0;
        _pendingStartSteps = _steps;
      } else {
        // Not confirmed yet: if no steps, keep speed 0 to avoid fake km/h while stationary.
        if (_sensorStepsActive && stepsDelta < 1) {
          _currentSpeedMps = 0.0;
        } else {
          _currentSpeedMps *= 0.85;
        }
      }
    } else {
      // Clear pending window on rejection.
      if (_pendingCount > 0) {
        _pendingPosition = null;
        _pendingPositionTs = null;
        _pendingStartTs = null;
        _pendingDistance = 0.0;
        _pendingCount = 0;
        _pendingStartSteps = _steps;
      }

      // Stationary detection:
      // - if rejected by jitter gate, treat as stationary
      // - otherwise use small speed to detect stationary
      if (rejectedByJitter) {
        _stationaryStreak++;
      } else if (speedMps < 0.3) {
        _stationaryStreak++;
      } else {
        _stationaryStreak = 0;
      }

      if ((_stationaryStreak >= 2 && rejectedByJitter) || _stationaryStreak >= 3) {
        _currentSpeedMps = 0.0;
      } else {
        _currentSpeedMps *= 0.85;
      }
    }
  }

  Future<void> _playStartBell() async {
    try {
      final p = _startSoundPath;
      if (p != null && p.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(p));
        return;
      }
    } catch (_) {}
    try {
      await _sys.invokeMethod('playSystemNotificationSound');
    } catch (_) {}
  }

  Future<void> _startMusicLoopIfNeeded({bool reloadSettings = false}) async {
    try {
      if (_status != 'in_progress') return;
      if (_inCountdownPhase) return;

      // Only load music settings once per workout (or when explicitly requested).
      // This avoids frequent DB reads and saves power.
      if (reloadSettings || _musicPlaylist.isEmpty) {
        final list = await _configDao.getSportMusicPlaylist();
        final modeRaw = await _configDao.getSportMusicMode();
        final mode = (modeRaw == 'random') ? 'random' : 'order';
        if (list.isEmpty) return;

        if (mounted) {
          setState(() {
            _musicPlaylist = list;
            _musicMode = mode;
          });
        } else {
          _musicPlaylist = list;
          _musicMode = mode;
        }
      }

      if (_musicPlaylist.isEmpty) return;

      await SportMusicService.instance.applySettings(playlist: _musicPlaylist, mode: _musicMode);
      await SportMusicService.instance.startIfNeeded();
      _musicStarted = SportMusicService.instance.isStarted;
    } catch (_) {
      // ignore
    }
  }

  Future<void> _playMusicAt(int idx) async {
    try {
      if (_musicPlaylist.isEmpty) return;
      await SportMusicService.instance.applySettings(playlist: _musicPlaylist, mode: _musicMode);
      await SportMusicService.instance.playAt(idx);
      _musicStarted = true;
      _musicIndex = idx.clamp(0, _musicPlaylist.length - 1);
    } catch (_) {
      // ignore
    }
  }

  void _playNextMusic() {
    if (!_musicStarted) return;
    if (_musicPlaylist.isEmpty) return;
    if (_status != 'in_progress') return;
    if (_musicPlaylist.length == 1) {
      // repeat
      _playMusicAt(0);
      return;
    }
    if (_musicMode == 'random') {
      var next = _musicRandom.nextInt(_musicPlaylist.length);
      // Avoid repeating the same track when possible.
      if (next == _musicIndex) {
        next = (next + 1) % _musicPlaylist.length;
      }
      _musicIndex = next;
    } else {
      _musicIndex = (_musicIndex + 1) % _musicPlaylist.length;
    }
    _playMusicAt(_musicIndex);
  }

  Future<void> _pauseMusic() async {
    try {
      await SportMusicService.instance.pause();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _stopMusic() async {
    try {
      await SportMusicService.instance.stop();
    } catch (_) {
      // ignore
    }
    _musicStarted = false;
  }

  void _setManualStatusOverride(String status) {
    _manualStatusOverride = status;
    _manualStatusOverrideUntilMs = DateTime.now().millisecondsSinceEpoch + 2000;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    // Do NOT escape '$' here, otherwise UI will literally show "$h:$m:$s".
    return '$h:$m:$s';
  }

  String _formatDistance(double meters) {
    if (!meters.isFinite || meters <= 0) return '0 m';
    if (meters < 1000) {
      return '${meters.toStringAsFixed(1)} m';
    }
    return '${(meters / 1000.0).toStringAsFixed(2)} km';
  }

  String _formatSpeedKmH(double mps) {
    if (!mps.isFinite || mps <= 0) return '0.00 km/h';
    final kmh = (mps * 3.6).clamp(0, 99.0);
    return '${kmh.toStringAsFixed(2)} km/h';
  }

  double _calcAvgSpeedKmH() {
    final sec = _totalElapsed.inSeconds;
    if (sec <= 0) return 0;
    final hours = sec / 3600.0;
    return (_distance / 1000.0) / hours;
  }

  void _togglePause() async {
    if (_nativeFgMode) {
      if (_status == 'in_progress') {
        _setManualStatusOverride('paused');
        // Pause: keep metrics in DB, just mark status and stop native foreground tracking.
        // Pause background music when pausing (UI button or notification button).
        await _pauseMusic();
        _stopSensors();
        setState(() {
          _status = 'paused';
          _stepsOffset = _steps;
        });
        try {
          await _dao.updateRecord(widget.recordId, {'status': 'paused'});
        } catch (_) {}
        await _syncPlanStatus('paused');
        await NativeSportFg.pause(recordId: widget.recordId, title: '运动进行中');
        // Keep polling DB while paused so notification 'continue' can immediately
        // sync this page back to in_progress.
        _startDbPollTimer(intervalSec: 2);
        return;
      }
      if (_status == 'paused') {
        _setManualStatusOverride('in_progress');
        // Resume
        setState(() {
          _status = 'in_progress';
        });
        try {
          await _dao.updateRecord(widget.recordId, {'status': 'in_progress'});
        } catch (_) {}
        await _syncPlanStatus('in_progress');
        // Ensure foreground service exists even if the system killed it while paused.
        await NativeSportFg.ensureStarted(
          recordId: widget.recordId,
          title: '运动进行中',
          targetType: _targetType,
          targetValue: _targetValue,
          targetUnit: _targetUnit,
        );
        // ignore: discarded_futures
        await NativeSportFg.resume(recordId: widget.recordId, title: '运动进行中');
        await _startSensors();
        _startPersistTimer();
        _startDbPollTimer(intervalSec: 1);
        // ignore: discarded_futures
        _startMusicLoopIfNeeded();
        return;
      }
    }
    if (_status == 'in_progress') {
      // pause
      _elapsedOffsetSec += _segmentWatch.elapsed.inSeconds;
      _segmentWatch
        ..stop()
        ..reset();
      _stopSensors();
      // Pause background music when pausing (UI button or notification button).
      await _pauseMusic();
      setState(() {
        _status = 'paused';
        _stepsOffset = _steps;
      });
      await _persistProgress(reason: 'pause');
      await _syncPlanStatus('paused');
      return;
    }
    if (_status == 'paused') {
      // resume
      setState(() {
        _status = 'in_progress';
      });

      // Reset motion filters so the first GPS fix after resume does not create a large jump.
      _lastAcceptedPosition = null;
      _lastAcceptedTs = null;
      _stationaryStreak = 0;
      _pendingPosition = null;
      _pendingPositionTs = null;
      _pendingStartTs = null;
      _pendingDistance = 0.0;
      _pendingCount = 0;
      _pendingStartSteps = _steps;
      _inProgressStartedAt = DateTime.now();

      _segmentWatch
        ..reset()
        ..start();
      _stepsOffset = _steps;
      await _startSensors();
      await _startMusicLoopIfNeeded();
      _startPersistTimer();
      await _persistProgress(reason: 'resume');
      await _syncPlanStatus('in_progress');
    }
  }

  /// Internal implementation for stopping a run.
  ///
  /// This method performs all underlying operations to stop the current
  /// activity (e.g. stopping sensors, persisting progress, resolving the
  /// endpoint location, updating the plan status, etc.) but **does not**
  /// navigate away from this page or show any confirmation dialogs. Callers
  /// should handle any UI interactions and navigation themselves.  This
  /// separation allows us to wrap the stop logic with confirmation and
  /// loading indicators.
  Future<void> _stopInternal() async {
    if (_nativeFgMode) {
      // Stop the native foreground service completely so the notification is removed.
      // Requirement: stop foreground service immediately.
      await NativeSportFg.stop(recordId: widget.recordId, title: _displayTitle, finalStatus: 'stopped');
      _stopDbPollTimer();
      await _stopMusic();
      setState(() {
        _status = 'stopped';
        _stepsOffset = _steps;
      });
      await _captureEndLocationBestEffort();
      await _persistProgress(reason: 'stop', forceEndTime: true);
      await _syncPlanStatus('stopped');
      return;
    }

    if (_status == 'completed') return;
    if (_status == 'in_progress') {
      _elapsedOffsetSec += _segmentWatch.elapsed.inSeconds;
    }
    _segmentWatch
      ..stop()
      ..reset();
    _stopSensors();
    await _stopMusic();
    setState(() {
      _status = 'stopped';
      _stepsOffset = _steps;
    });
    await _captureEndLocationBestEffort();
    await _persistProgress(reason: 'stop', forceEndTime: true);
    await _syncPlanStatus('stopped');
  }

  Future<T?> _runWithTransparentLoading<T>(Future<T> Function() task) async {
    BuildContext? dialogCtx;
    if (!mounted) return null;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'loading',
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, __) {
        dialogCtx = ctx;
        return const Material(
          type: MaterialType.transparency,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
    // Allow the dialog route to build before running the task.
    await Future<void>.delayed(Duration.zero);
    try {
      return await task();
    } finally {
      if (dialogCtx != null) {
        try {
          Navigator.of(dialogCtx!).pop();
        } catch (_) {}
      }
    }
  }

  /// Stops the current run after asking the user for confirmation and
  /// presenting a loading indicator while all tasks complete.  Once
  /// finished, the page is dismissed and the user is returned to the
  /// previous screen (usually the Sport home page).
  Future<void> _stop() async {
    // Confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('结束运动'),
          content: Text(widget.mode == 'instant'
              ? '确定结束本次运动吗？'
              : '确定结束本次运动吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _runWithTransparentLoading<void>(() async {
      await _stopInternal();
    });
    if (!mounted) return;
    // After backend processing and FG service destruction, go back to sport home.
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SportDetailPage()),
      (r) => false,
    );
  }

  void _restart() async {
    if (_nativeFgMode) {
      await _refreshFromDb();
      await NativeSportFg.pause(recordId: widget.recordId, title: '运动进行中');
      _stopDbPollTimer();
      final now = DateTime.now().toIso8601String();
      setState(() {
        _status = 'in_progress';
        _elapsedOffsetSec = 0;
        _steps = 0;
        _stepsOffset = 0;
        _distance = 0.0;
        _currentSpeedKmh = 0.0;
        _currentSpeedMps = 0.0;
      });
      await _dao.updateRecord(widget.recordId, <String, dynamic>{
        'start_time': now,
        'end_time': null,
        'total_duration': 0,
        'paused_total_sec': 0,
        'total_steps': 0,
        'total_distance': 0.0,
        'avg_speed': 0.0,
        'current_speed': 0.0,
        'status': 'in_progress',
        'updated_at': now,
      });
      await _syncPlanStatus('in_progress');
      _startUiTimer();
      await _startSensors();
      _startPersistTimer();
      await _startMusicLoopIfNeeded();
      // ignore: discarded_futures
      await NativeSportFg.resume(recordId: widget.recordId, title: '运动进行中');
      await _startMusicLoopIfNeeded();
      _startDbPollTimer(intervalSec: 1);
      // ignore: discarded_futures
      _refreshFromDb();
      return;
    }

    // Reset and start immediately (no countdown) – aligns with “重新开始”行为
    _elapsedOffsetSec = 0;
    _distance = 0;
    _steps = 0;
    _stepsOffset = 0;
    _startPosition = null;
    _lastPosition = null;
    _lastAcceptedPosition = null;
    _lastAcceptedTs = null;
    _stationaryStreak = 0;
    _pendingPosition = null;
    _pendingPositionTs = null;
    _pendingStartTs = null;
    _pendingDistance = 0.0;
    _pendingCount = 0;
    _pendingStartSteps = _steps;
    _inProgressStartedAt = DateTime.now();
    _segmentWatch
      ..reset()
      ..start();
    _startedAtIso = DateTime.now().toIso8601String();
    setState(() {
      _status = 'in_progress';
    });
    await _startSensors();
    await _startMusicLoopIfNeeded();
    _startUiTimer();
    _startPersistTimer();
    await _persistProgress(reason: 'restart');
    await _syncPlanStatus('in_progress');
  }

  void _resumeRunning({required bool startTimers}) {
    _segmentWatch
      ..reset()
      ..start();
    _lastAcceptedPosition = null;
    _lastAcceptedTs = null;
    _stationaryStreak = 0;
    _pendingPosition = null;
    _pendingPositionTs = null;
    _pendingStartTs = null;
    _pendingDistance = 0.0;
    _pendingCount = 0;
    _pendingStartSteps = _steps;
    _inProgressStartedAt = DateTime.now();
    _startSensors();
    // Best-effort: resume music only when actually running.
    // ignore: discarded_futures
    _startMusicLoopIfNeeded();
    if (startTimers) {
      _startUiTimer();
      _startPersistTimer();
    }
  }

  void _checkTargetReached() {
    if (_status != 'in_progress') return;
    final targetVal = _targetValue;
    if (targetVal == null || targetVal <= 0) return;

    double progress;
    if (_targetType == 'steps') {
      progress = _steps.toDouble();
    } else if (_targetType == 'duration') {
      // target_value uses hours in plan dialog
      progress = _totalElapsed.inSeconds / 3600.0;
    } else {
      progress = _distance / 1000.0;
    }
    if (progress >= targetVal) {
      // Auto-complete when target reached without asking the user for confirmation.
      // Use the internal implementation so no confirmation or extra dialogs are shown.
      // ignore: discarded_futures
      _completeInternal();
    }
  }

  /// Internal implementation for completing a run.
  ///
  /// Performs all necessary operations to mark the run as completed:
  /// stops services/sensors, captures the end position, persists progress
  /// and updates plan status.  No user dialogs or navigation occurs in
  /// this method – callers should handle those separately.
  Future<void> _completeInternal({String? dialogTitle, String? dialogContent}) async {
    if (_status == 'completed') return;
    if (_nativeFgMode) {
      // Requirement: stop foreground service immediately.
      await NativeSportFg.stop(recordId: widget.recordId, title: _displayTitle, finalStatus: 'completed'); // fully stop the service so notification is removed
      _stopDbPollTimer();
      await _stopMusic();
      setState(() {
        _status = 'completed';
        _stepsOffset = _steps;
      });
    } else {
      _elapsedOffsetSec += _segmentWatch.elapsed.inSeconds;
      _segmentWatch
        ..stop()
        ..reset();
      _stopSensors();
      await _stopMusic();
      setState(() {
        _status = 'completed';
        _stepsOffset = _steps;
      });
    }
    await _captureEndLocationBestEffort();
    await _persistProgress(reason: 'complete', forceEndTime: true);
    await _syncPlanStatus('completed');
  }

  /// Completes the current run after confirming with the user and
  /// displaying a loading indicator while tasks finish.  When the
  /// underlying operations have finished, the page is dismissed.
  Future<void> _complete() async {
    // Confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('结束运动'),
          content: Text(widget.mode == 'instant'
              ? '确定结束本次运动吗？'
              : '确定结束本次运动吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _runWithTransparentLoading<void>(() async {
      await _completeInternal();
    });
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SportDetailPage()),
      (r) => false,
    );
  }

  void _startPersistTimer() {
    _persistTimer?.cancel();
    _persistTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_status == 'in_progress') {
        _persistProgress(reason: 'tick');
      }
    });
  }
  void _startDbPollTimer({int intervalSec = 1}) {
    final sec = intervalSec < 1 ? 1 : intervalSec;
    if (_dbPollTimer != null && _dbPollIntervalSec == sec) return;
    _dbPollIntervalSec = sec;
    _dbPollTimer?.cancel();
    _dbPollTimer = Timer.periodic(Duration(seconds: sec), (_) {
      // Keep UI variables fresh from DB, so returning to this page restores correctly.
      _refreshFromDb();
    });
  }

  void _stopDbPollTimer() {
    _dbPollTimer?.cancel();
    _dbPollTimer = null;
  }

  
  void _syncNativeElapsedClock(int durSec, String status) {
    if (!_nativeFgMode) return;
    final st = status.isEmpty ? _nativeElapsedClockStatus : status;
    if (_nativeElapsedClockStatus != st) {
      _nativeElapsedClockStatus = st;
      _nativeElapsedBaseSec = durSec;
      _nativeElapsedWatch
        ..stop()
        ..reset();
      if (st == 'in_progress') {
        _nativeElapsedWatch.start();
      }
      return;
    }

    if (st == 'in_progress') {
      if (!_nativeElapsedWatch.isRunning) {
        _nativeElapsedBaseSec = durSec;
        _nativeElapsedWatch
          ..reset()
          ..start();
        return;
      }
      final shown = _nativeElapsedBaseSec + _nativeElapsedWatch.elapsed.inSeconds;
      final diff = durSec - shown;
      if (diff.abs() >= 2) {
        final newBase = durSec - _nativeElapsedWatch.elapsed.inSeconds;
        _nativeElapsedBaseSec = newBase < 0 ? 0 : newBase;
      }
    } else {
      // paused/stopped: freeze immediately.
      if (_nativeElapsedWatch.isRunning) {
        _nativeElapsedWatch.stop();
      }
      _nativeElapsedWatch.reset();
      _nativeElapsedBaseSec = durSec;
    }
  }


Future<void> _refreshFromDb() async {
    if (_dbRefreshing) return;
    _dbRefreshing = true;
    try {
      // iOS native tracking persists metrics in native side; sync into DB on resume/poll.
      if (Platform.isIOS && _nativeFgMode) {
        final snap = await NativeSportFg.getSnapshot(widget.recordId);
        if (snap != null) {
          final dur = (snap['total_duration'] is num)
              ? (snap['total_duration'] as num).toInt()
              : int.tryParse(snap['total_duration']?.toString() ?? '') ?? 0;
          final steps = (snap['total_steps'] is num)
              ? (snap['total_steps'] as num).toInt()
              : int.tryParse(snap['total_steps']?.toString() ?? '') ?? 0;
          final dist = (snap['total_distance'] is num)
              ? (snap['total_distance'] as num).toDouble()
              : double.tryParse(snap['total_distance']?.toString() ?? '') ?? 0.0;
          final curSp = (snap['current_speed'] is num)
              ? (snap['current_speed'] as num).toDouble()
              : double.tryParse(snap['current_speed']?.toString() ?? '') ?? 0.0;
          final avgSp = (snap['avg_speed'] is num)
              ? (snap['avg_speed'] as num).toDouble()
              : double.tryParse(snap['avg_speed']?.toString() ?? '') ?? 0.0;
          final snapStatus = (snap['status'] ?? '').toString();

          try {
            await _dao.updateRecord(widget.recordId, {
              'status': snapStatus.isNotEmpty ? snapStatus : 'in_progress',
              'total_duration': dur,
              'total_steps': steps,
              'total_distance': dist,
              'current_speed': curSp,
              'avg_speed': avgSp,
            });
          } catch (_) {
            // ignore
          }
        }
      }

      final rec = await _dao.getRecord(widget.recordId);
      if (rec == null) return;

      final st = (rec['status'] ?? '').toString();
      final dur = (rec['total_duration'] is num)
          ? (rec['total_duration'] as num).toInt()
          : int.tryParse(rec['total_duration']?.toString() ?? '') ?? 0;
      final steps = (rec['total_steps'] is num)
          ? (rec['total_steps'] as num).toInt()
          : int.tryParse(rec['total_steps']?.toString() ?? '') ?? 0;
      final dist = (rec['total_distance'] is num)
          ? (rec['total_distance'] as num).toDouble()
          : double.tryParse(rec['total_distance']?.toString() ?? '') ?? 0.0;
      final sp = (rec['current_speed'] is num)
          ? (rec['current_speed'] as num).toDouble()
          : double.tryParse(rec['current_speed']?.toString() ?? '') ?? 0.0;

      if (!mounted) return;

      // Apply a short manual override window after user pause/resume to avoid DB stale status
      // causing music to resume immediately (race with service/DB writes).
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      var effectiveStatus = st.isEmpty ? _status : st;
      if (_manualStatusOverride != null && nowMs < _manualStatusOverrideUntilMs) {
        effectiveStatus = _manualStatusOverride!;
      } else if (_manualStatusOverride != null) {
        _manualStatusOverride = null;
      }

      final int mergedSteps = (_status == 'in_progress' || effectiveStatus == 'in_progress')
          ? (_steps > steps ? _steps : steps)
          : steps;
      final double mergedDistance = (_status == 'in_progress' || effectiveStatus == 'in_progress')
          ? (_distance > dist ? _distance : dist)
          : dist;
      final double mergedSpeedKmh = (_status == 'in_progress' || effectiveStatus == 'in_progress')
          ? (_currentSpeedKmh > sp ? _currentSpeedKmh : sp)
          : sp;

      setState(() {
        _status = effectiveStatus;
        _elapsedOffsetSec = dur;
        _steps = mergedSteps;
        _distance = mergedDistance;
        _currentSpeedKmh = mergedSpeedKmh;
        _currentSpeedMps = mergedSpeedKmh / 3.6;
      });

      // Smooth elapsed seconds in native mode so UI ticks 1/sec without jumping.
      _syncNativeElapsedClock(dur, effectiveStatus);

      // Power: adjust DB polling interval when paused.
      if (_nativeFgMode) {
        final desired = (effectiveStatus == 'paused') ? 2 : 1;
        if (_dbPollIntervalSec != desired) {
          _startDbPollTimer(intervalSec: desired);
        }

        // Robust music control:
        // - paused => always pause music
        // - in_progress => ensure music is running (startIfNeeded is cheap after our service fix)
        if (effectiveStatus == 'paused') {
          try {
            await _pauseMusic();
          } catch (_) {}
        } else if (effectiveStatus == 'in_progress' && !_inCountdownPhase) {
          try {
            await _startMusicLoopIfNeeded();
          } catch (_) {}
        }
      }
    } catch (_) {
      // ignore
    } finally {
      _dbRefreshing = false;
    }
  }

Future<List<String>?> _revGeoName(double lat, double lon) async {
  try {
    final list = await placemarkFromCoordinates(lat, lon);
    if (list.isEmpty) return null;
    final p = list.first;
    final name = [p.name, p.street, p.subLocality].firstWhere((e) => (e != null && e.toString().trim().isNotEmpty), orElse: () => p.name);
    // Build an address string from nullable placemark parts.
    final addrParts = <String?>[p.locality, p.administrativeArea, p.country, p.street]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return [name?.toString() ?? '', addrParts.join(' ')];
  } catch (_) { return null; }
}
Future<void> _persistProgress({required String reason, bool forceEndTime = false}) async {
    // Persist minimal progress frequently to avoid loss on crash/kill.
    final now = DateTime.now().toIso8601String();
    final totalSec = _totalElapsed.inSeconds;
    final m = <String, dynamic>{
      'updated_at': now,
      'status': _status,
      'total_duration': totalSec,
      'total_steps': _steps,
      'total_distance': _distance,
      'avg_speed': _calcAvgSpeedKmH(),
    };

    // Only set start_time when the session actually begins.
    // For resumed records, keep the original start_time.
    if ((reason == 'start' || reason == 'restart') && (_startedAtIso != null && _startedAtIso!.isNotEmpty)) {
      m['start_time'] = _startedAtIso;
    }
    if (_startPosition != null) {
      m['start_location'] = jsonEncode({'lat': _startPosition!.latitude, 'lon': _startPosition!.longitude, if (_startLocName != null) 'name': _startLocName, if (_startLocAddr != null) 'address': _startLocAddr});
    }
    if (forceEndTime || _status == 'completed') {
      m['end_time'] = now;
      if (_lastPosition != null) {
        m['end_location'] = jsonEncode({'lat': _lastPosition!.latitude, 'lon': _lastPosition!.longitude, if (_endLocName != null) 'name': _endLocName, if (_endLocAddr != null) 'address': _endLocAddr});
      }
    }

    final int attempts = (reason == 'stop' || reason == 'complete' || forceEndTime) ? 4 : 1;
    for (int i = 0; i < attempts; i++) {
      try {
        await _dao.updateRecord(widget.recordId, m);
        break;
      } catch (_) {
        // On critical transitions (stop/complete), transient DB locks can happen
        // due to native foreground tick writing. Retry a few times to guarantee
        // status/end_time is persisted.
        if (i == attempts - 1) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 120 * (i + 1)));
      }
    }

  }

  Future<void> _syncPlanStatus(String status) async {
    final pid = _planId;
    if (pid == null) return;
    try {
      await _dao.updatePlanStatus(pid, status);
    } catch (_) {}
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _persistTimer?.cancel();
    _countdownTimer?.cancel();
    _musicChangeSub?.cancel();
    _bgRotateTimer?.cancel();
    _stopDbPollTimer();
    // Stop in-page sensors (UI is leaving), but DO NOT pause/stop the workout state.
    // Data collection continues via:
    // - Android: native foreground service
    // - iOS/others: Dart background tracker (within same process)
    if (_status == 'in_progress') {
      // Pause background music when leaving the page (best-effort).
      // ignore: discarded_futures
      // _pauseMusic(); // keep playing as per requirement
      if (!_nativeFgMode) {
        // Start Dart tracker so leaving this page doesn't stop collection.
        // ignore: discarded_futures
        SportBgTracker.instance.startIfNeeded(recordId: widget.recordId);
      }
    }
    _stopSensors();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        appBar: AppBar(title: const Text('运动进行中')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final elapsed = _totalElapsed;

    final targetVal = _targetValue;
    final remainingText = () {
      if (targetVal == null || targetVal <= 0) return '';
      double progress;
      double remain;
      String unit;
      if (_targetType == 'steps') {
        progress = _steps.toDouble();
        remain = targetVal - progress;
        unit = '步';
      } else if (_targetType == 'duration') {
        progress = elapsed.inSeconds / 3600.0;
        remain = targetVal - progress;
        unit = '小时';
      } else {
        progress = _distance / 1000.0;
        remain = targetVal - progress;
        unit = 'km';
      }
      if (remain < 0) remain = 0;
      return '剩余: ${remain.toStringAsFixed(1)} $unit';
    }();

    final statusText = _status == 'in_progress'
        ? '进行中'
        : _status == 'paused'
            ? '已暂停'
            : _status == 'stopped'
                ? '已停止'
                : _status == 'completed'
                    ? '已完成'
                    : '未开始';

    final hasBottomBar = !(_status == 'not_started' || _status == 'completed');
    // When extendBody=true, body will render behind bottomNavigationBar.
    // Add extra bottom padding so content isn't covered by the action buttons.
    final bottomPad = 16.0 + MediaQuery.of(context).padding.bottom + (hasBottomBar ? (kBottomNavigationBarHeight + 12) : 0);

    return Scaffold(
      appBar: AppBar(title: const Text('运动进行中')),
      // Let the background extend behind the transparent BottomAppBar.
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen background
          Positioned.fill(
            child: (_bgImagePath != null && _bgImagePath!.isNotEmpty && File(_bgImagePath!).existsSync())
                ? Image.file(
                    File(_bgImagePath!),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : Container(color: Colors.white),
          ),
          // Overlay to keep text readable while keeping background visible
          Positioned.fill(
            child: (_bgImagePath != null && _bgImagePath!.isNotEmpty)
                ? Container(color: Colors.white.withOpacity(0.55))
                : const SizedBox.shrink(),
          ),
          // Main content; use Positioned.fill so Stack always expands to full screen.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
              child: Column(
                children: [
                Card(
                  color: const Color(0xFFF0F8FF).withOpacity(0.92),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          _quoteContent,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (_quoteAuthor.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('—— $_quoteAuthor', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                        ],
                        if (_quoteExplanation.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_quoteExplanation, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_inCountdownPhase)
                  Column(
                    children: [
                      Text('准备开始', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Text(
                        '$_countdown',
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  )
                else
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('状态: $statusText', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('已用时: ${_formatDuration(elapsed)}', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('步数: $_steps 步${_sensorStepsActive ? '' : '（估算）'}', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('距离: ${_formatDistance(_distance)}', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('实时速度: ${_formatSpeedKmH(_currentSpeedMps)}', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('平均速度: ${_calcAvgSpeedKmH().toStringAsFixed(2)} km/h', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        if (targetVal != null && targetVal > 0) Text(remainingText, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
              ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: !hasBottomBar
          ? null
          : BottomAppBar(
              color: Colors.transparent,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (_status == 'in_progress' || _status == 'paused')
                      IconButton(
                        icon: Icon(_status == 'paused' ? Icons.play_arrow : Icons.pause),
                        onPressed: _togglePause,
                      ),
                    if (_status == 'in_progress' || _status == 'paused')
                      IconButton(
                        icon: Icon(widget.mode == 'instant' ? Icons.flag : Icons.stop),
                        onPressed: widget.mode == 'instant' ? () => _complete() : _stop,
                      ),
                    if (_status == 'stopped')
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _restart,
                      ),
                  ],
                ),
              ),
            ),
    );
  }

// (removed stray reverse geocode code that was outside of any method)
}