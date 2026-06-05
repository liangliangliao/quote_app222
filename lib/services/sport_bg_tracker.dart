import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../data/sport_dao.dart';

/// A lightweight, process-lifetime background tracker used when the user leaves
/// SportRunningPage on iOS/other platforms (where we don't have a native
/// foreground service).
///
/// IMPORTANT LIMITATIONS:
/// - If the OS force-kills the process (e.g. iOS force-quit from app switcher),
///   this tracker will stop. This is a system limitation.
class SportBgTracker {
  SportBgTracker._();

  static final SportBgTracker instance = SportBgTracker._();

  final SportDao _dao = SportDao();

  int? _recordId;
  StreamSubscription<Position>? _posSub;
  Timer? _tick;

  int _baseDurationSec = 0;
  int _baseSteps = 0;
  double _baseDistanceM = 0.0;

  DateTime? _sessionStart;
  Position? _lastPos;
  double _sessionDistanceM = 0.0;

  Future<void> startIfNeeded({required int recordId}) async {
    if (_recordId == recordId && _posSub != null) return;
    await stopIfRunning(recordId);

    _recordId = recordId;
    _sessionStart = DateTime.now();
    _sessionDistanceM = 0.0;
    _lastPos = null;

    // Load base progress from DB (best-effort).
    try {
      final rec = await _dao.getRecord(recordId);
      if (rec != null) {
        _baseDurationSec = (rec['total_duration'] is num)
            ? (rec['total_duration'] as num).toInt()
            : int.tryParse(rec['total_duration']?.toString() ?? '') ?? 0;
        _baseSteps = (rec['total_steps'] is num)
            ? (rec['total_steps'] as num).toInt()
            : int.tryParse(rec['total_steps']?.toString() ?? '') ?? 0;
        _baseDistanceM = (rec['total_distance'] is num)
            ? (rec['total_distance'] as num).toDouble()
            : double.tryParse(rec['total_distance']?.toString() ?? '') ?? 0.0;
      }
    } catch (_) {}

    // Start location stream.
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );

    try {
      _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) {
          if (_recordId != recordId) return;
          _onPosition(pos);
        },
        onError: (_) {},
      );
    } catch (_) {
      _posSub = null;
    }

    // Persist periodically.
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _persistTick(recordId);
    });
  }

  Future<void> stopIfRunning(int recordId) async {
    if (_recordId != recordId) return;
    await _stopInternal();
  }

  Future<void> stopAll() => _stopInternal();

  Future<void> _stopInternal() async {
    _tick?.cancel();
    _tick = null;
    await _posSub?.cancel();
    _posSub = null;
    _recordId = null;
    _sessionStart = null;
    _lastPos = null;
    _sessionDistanceM = 0.0;
  }

  void _onPosition(Position pos) {
    if (pos.accuracy.isFinite && pos.accuracy > 80) return;

    final last = _lastPos;
    if (last != null) {
      final d = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (d.isFinite && d >= 0.8 && d < 200) {
        _sessionDistanceM += d;
      }
    }
    _lastPos = pos;
  }

  Future<void> _persistTick(int recordId) async {
    if (_recordId != recordId) return;

    // If status is no longer in_progress, stop tracking.
    try {
      final rec = await _dao.getRecord(recordId);
      if (rec == null) return;
      final st = (rec['status'] ?? '').toString();
      if (st != 'in_progress') {
        await _stopInternal();
        return;
      }
    } catch (_) {}

    final now = DateTime.now().toIso8601String();
    final elapsed = _sessionStart == null
        ? 0
        : DateTime.now().difference(_sessionStart!).inSeconds;

    final totalDuration = _baseDurationSec + math.max(0, elapsed);
    final totalDistance = _baseDistanceM + _sessionDistanceM;

    // Estimate steps from distance (0.7m/step).
    final estSteps = _baseSteps + (totalDistance / 0.7).round();

    final avg = totalDuration <= 0
        ? 0.0
        : (totalDistance / 1000.0) / (totalDuration / 3600.0);

    try {
      await _dao.updateRecord(recordId, <String, dynamic>{
        'updated_at': now,
        'total_duration': totalDuration,
        'total_steps': estSteps,
        'total_distance': totalDistance,
        'avg_speed': avg.isFinite ? avg : 0.0,
      });
    } catch (_) {}
  }
}
