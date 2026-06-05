import 'dart:math' as math;

import '../data/self_help_dao.dart';

/// A best-effort, device-agnostic summary of Fitbit data for a given day.
///
/// Fitbit Web API responses vary by account, device capabilities and approvals.
/// This class intentionally keeps all fields nullable and parses defensively.
class FitbitMetrics {
  FitbitMetrics({
    required this.date,
    this.restingHeartRate,
    this.currentHeartRate,
    this.hrvRmssdMs,
    this.breathingRate,
    this.sleepMinutes,
    this.sleepEfficiency,
    this.steps,
    this.spo2Avg,
    this.skinTempDeviation,
    this.activeZoneMinutes,
    this.cardioScore,
    this.recentSteps15m,
  });

  final String date;

  final double? restingHeartRate;
  final double? currentHeartRate;
  final double? hrvRmssdMs;
  final double? breathingRate;
  final double? sleepMinutes;
  /// 0..1
  final double? sleepEfficiency;
  final double? steps;

  final double? spo2Avg;
  /// In Celsius deviation (Fitbit often returns deviation from baseline)
  final double? skinTempDeviation;
  final double? activeZoneMinutes;
  final double? cardioScore;

  /// Rough exertion indicator: steps in the last ~15 minutes (best-effort).
  final double? recentSteps15m;

  /// Load the most relevant caches for [date] and parse to [FitbitMetrics].
  static Future<FitbitMetrics> load({required FitbitDao dao, required String date}) async {
    final hr = await dao.getCache('heartrate_intraday_$date');
    final act = await dao.getCache('activity_summary_$date');
    final stepsIntra = await dao.getCache('steps_intraday_$date');
    final sleep = await dao.getCache('sleep_$date');
    final hrv = await dao.getCache('hrv_$date');
    final br = await dao.getCache('breathing_rate_$date');
    final spo2 = await dao.getCache('spo2_$date');
    final skinTemp = await dao.getCache('skin_temperature_$date');
    final azm = await dao.getCache('active_zone_minutes_daily_$date');
    final cardio = await dao.getCache('cardioscore_$date');

    final resting = _parseRestingHr(act) ?? _parseRestingHrFromProfile(await dao.getCache('profile_$date'));
    final current = _parseCurrentHr(hr);
    final hrvRmssd = _parseHrvRmssd(hrv);
    final breathing = _parseBreathingRate(br);
    final sleepMin = _parseSleepMinutes(sleep);
    final sleepEff = _parseSleepEfficiency(sleep);
    final steps = _parseSteps(act) ?? _parseStepsFromIntraday(stepsIntra);
    final recentSteps15m = _parseRecentSteps15m(stepsIntra);
    final spo2Avg = _parseSpo2Avg(spo2);
    final tempDev = _parseSkinTempDeviation(skinTemp);
    final activeZoneMinutes = _parseActiveZoneMinutes(azm);
    final cardioScore = _parseCardioScore(cardio);

    return FitbitMetrics(
      date: date,
      restingHeartRate: resting,
      currentHeartRate: current,
      hrvRmssdMs: hrvRmssd,
      breathingRate: breathing,
      sleepMinutes: sleepMin,
      sleepEfficiency: sleepEff,
      steps: steps,
      spo2Avg: spo2Avg,
      skinTempDeviation: tempDev,
      activeZoneMinutes: activeZoneMinutes,
      cardioScore: cardioScore,
      recentSteps15m: recentSteps15m,
    );
  }

  // ------------------------
  // Parsers (defensive)
  // ------------------------

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString();
    return double.tryParse(s);
  }

  static double? _parseRestingHr(Map<String, dynamic>? act) {
    if (act == null) return null;
    final summary = act['summary'];
    if (summary is Map) {
      final rhr = summary['restingHeartRate'];
      final d = _asDouble(rhr);
      if (d != null && d > 30 && d < 140) return d;
    }
    return null;
  }

  static double? _parseRestingHrFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    // Some profiles include top-level "user" with restingHeartRate.
    final user = profile['user'];
    if (user is Map) {
      final rhr = user['restingHeartRate'];
      final d = _asDouble(rhr);
      if (d != null && d > 30 && d < 140) return d;
    }
    return null;
  }

  static double? _parseCurrentHr(Map<String, dynamic>? hr) {
    if (hr == null) return null;
    final intraday = hr['activities-heart-intraday'];
    if (intraday is Map) {
      final dataset = intraday['dataset'];
      if (dataset is List && dataset.isNotEmpty) {
        final last = dataset.last;
        if (last is Map) {
          final v = _asDouble(last['value']);
          if (v != null && v > 30 && v < 240) return v;
        }
      }
    }
    return null;
  }

  static double? _parseHrvRmssd(Map<String, dynamic>? hrv) {
    if (hrv == null) return null;
    final arr = hrv['hrv'];
    if (arr is List && arr.isNotEmpty) {
      final first = arr.first;
      if (first is Map) {
        final val = first['value'];
        if (val is Map) {
          final rmssd = _asDouble(val['rmssd']);
          if (rmssd != null && rmssd > 1 && rmssd < 500) return rmssd;
        }
      }
    }
    // Some responses may be {"value": {"rmssd":...}}
    final val = hrv['value'];
    if (val is Map) {
      final rmssd = _asDouble(val['rmssd']);
      if (rmssd != null && rmssd > 1 && rmssd < 500) return rmssd;
    }
    return null;
  }

  static double? _parseBreathingRate(Map<String, dynamic>? br) {
    if (br == null) return null;
    final arr = br['br'];
    if (arr is List && arr.isNotEmpty) {
      final first = arr.first;
      if (first is Map) {
        final val = first['value'];
        if (val is Map) {
          final d = _asDouble(val['breathingRate']);
          if (d != null && d > 4 && d < 40) return d;
        }
      }
    }
    return null;
  }

  static double? _parseSleepMinutes(Map<String, dynamic>? sleep) {
    if (sleep == null) return null;
    final summary = sleep['summary'];
    if (summary is Map) {
      final d = _asDouble(summary['totalMinutesAsleep']);
      if (d != null && d >= 0 && d <= 24 * 60) return d;
    }
    return null;
  }

  static double? _parseSleepEfficiency(Map<String, dynamic>? sleep) {
    if (sleep == null) return null;
    // Fitbit sleep logs often include "sleep" list with "efficiency" (0..100)
    final arr = sleep['sleep'];
    if (arr is List && arr.isNotEmpty) {
      final first = arr.first;
      if (first is Map) {
        final eff = _asDouble(first['efficiency']);
        if (eff != null && eff >= 0 && eff <= 100) return (eff / 100.0).clamp(0.0, 1.0);
      }
    }
    return null;
  }

  static double? _parseSteps(Map<String, dynamic>? act) {
    if (act == null) return null;
    final summary = act['summary'];
    if (summary is Map) {
      final d = _asDouble(summary['steps']);
      if (d != null && d >= 0) return d;
    }
    return null;
  }

  static double? _parseStepsFromIntraday(Map<String, dynamic>? stepsIntra) {
    if (stepsIntra == null) return null;
    // Some time series endpoints return {"activities-steps": [{"value":"123"}]}
    final arr = stepsIntra['activities-steps'];
    if (arr is List && arr.isNotEmpty) {
      final last = arr.last;
      if (last is Map) {
        final d = _asDouble(last['value']);
        if (d != null && d >= 0) return d;
      }
    }
    return null;
  }

  static double? _parseRecentSteps15m(Map<String, dynamic>? stepsIntra) {
    if (stepsIntra == null) return null;
    final intraday = stepsIntra['activities-steps-intraday'];
    if (intraday is Map) {
      final dataset = intraday['dataset'];
      if (dataset is List && dataset.length >= 2) {
        // dataset entries contain time and value (cumulative in the bucket)
        // We approximate the last 15 minutes by summing the last 15 points for 1min granularity.
        final int take = math.min(15, dataset.length);
        double sum = 0.0;
        for (int i = dataset.length - take; i < dataset.length; i++) {
          final it = dataset[i];
          if (it is Map) {
            sum += (_asDouble(it['value']) ?? 0.0);
          }
        }
        if (sum >= 0) return sum;
      }
    }
    return null;
  }

  static double? _parseSpo2Avg(Map<String, dynamic>? spo2) {
    if (spo2 == null) return null;
    final arr = spo2['spo2'];
    if (arr is List && arr.isNotEmpty) {
      final first = arr.first;
      if (first is Map) {
        final val = first['value'];
        if (val is Map) {
          final avg = _asDouble(val['avg']);
          if (avg != null && avg > 50 && avg <= 100) return avg;
        }
      }
    }
    return null;
  }

  static double? _parseSkinTempDeviation(Map<String, dynamic>? skinTemp) {
    if (skinTemp == null) return null;
    // Typical structure: {"tempSkin": [{"value": {"nightlyRelative": 0.2}}]}
    final arr = skinTemp['tempSkin'] ?? skinTemp['temp_skin'] ?? skinTemp['temperature'];
    if (arr is List && arr.isNotEmpty) {
      final first = arr.first;
      if (first is Map) {
        final val = first['value'];
        if (val is Map) {
          final dev = _asDouble(val['nightlyRelative']) ?? _asDouble(val['relative']) ?? _asDouble(val['temp']);
          if (dev != null && dev.abs() <= 10) return dev;
        }
      }
    }
    return null;
  }

  static double? _parseActiveZoneMinutes(Map<String, dynamic>? azm) {
    if (azm == null) return null;
    final arr = azm['activities-active-zone-minutes'];
    if (arr is List && arr.isNotEmpty) {
      final first = arr.first;
      if (first is Map) {
        final d = _asDouble(first['value']);
        if (d != null && d >= 0) return d;
      }
    }
    // Some responses include summary.
    final summary = azm['summary'];
    if (summary is Map) {
      final d = _asDouble(summary['activeZoneMinutes']);
      if (d != null && d >= 0) return d;
    }
    return null;
  }

  static double? _parseCardioScore(Map<String, dynamic>? cardio) {
    if (cardio == null) return null;
    // cardioscore returns "cardioScore" list with "value" that may be a string.
    final arr = cardio['cardioScore'];
    if (arr is List && arr.isNotEmpty) {
      final first = arr.first;
      if (first is Map) {
        final val = first['value'];
        if (val is Map) {
          final d = _asDouble(val['vo2Max']) ?? _asDouble(val['value']);
          if (d != null && d > 0 && d < 100) return d;
        } else {
          final d = _asDouble(val);
          if (d != null && d > 0 && d < 100) return d;
        }
      }
    }
    return null;
  }
}
