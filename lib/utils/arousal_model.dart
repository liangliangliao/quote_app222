import 'dart:convert';
import 'dart:math' as math;

import 'fitbit_metrics.dart';

/// Model version for migration/debug.
const String kArousalModelVersion = 'v1.0.0';

/// The three-zone outcome.
enum ArousalZone { comfort, learning, panic }

String arousalZoneLabel(ArousalZone z) {
  switch (z) {
    case ArousalZone.comfort:
      return '舒适区';
    case ArousalZone.learning:
      return '学习区';
    case ArousalZone.panic:
      return '恐慌区';
  }
}

/// Inputs for the composite arousal / zone computation.
class ArousalInputs {
  ArousalInputs({
    // Subjective
    required this.stai6Prorated,
    required this.arousal0To100,
    required this.valence0To100,
    required this.demand0To100,
    required this.resources0To100,
    required this.distress0To100,
    // Objective PPG
    this.ppgBpm,
    this.ppgRmssdMs,
    this.ppgSignalQuality,
    // Wearable
    this.fitbit,
    // Baselines
    this.baselineRestingHr,
    this.baselineRmssdMs,
  });

  final double stai6Prorated; // 20..80
  final double arousal0To100; // 0..100
  final double valence0To100; // 0..100
  final double demand0To100;
  final double resources0To100;
  final double distress0To100;

  final double? ppgBpm;
  final double? ppgRmssdMs;
  final double? ppgSignalQuality;

  final FitbitMetrics? fitbit;

  final double? baselineRestingHr;
  final double? baselineRmssdMs;
}

/// Output for UI + storage.
class ArousalResult {
  ArousalResult({
    required this.arousal0To10,
    required this.zone,
    required this.confidence0To1,
    required this.subjectiveIndex0To1,
    required this.physiologicalIndex0To1,
    required this.explanation,
    required this.warnings,
  });

  final double arousal0To10;
  final ArousalZone zone;
  final double confidence0To1;
  final double subjectiveIndex0To1;
  final double physiologicalIndex0To1;
  final String explanation;
  final List<String> warnings;

  String get zoneLabel => arousalZoneLabel(zone);

  String warningsJson() => jsonEncode(warnings);
}

/// Composite arousal + zone model.
///
/// Design goals for this app module:
/// - Combine subjective + objective signals.
/// - Output 0..10 arousal with a confidence score.
/// - Provide interpretable reasoning.
/// - Be robust to missing wearable data (best-effort).
class ArousalModel {
  /// Compute a composite result.
  static ArousalResult compute(ArousalInputs i) {
    final warnings = <String>[];

    // ----- Subjective (0..1)
    final stai01 = ((i.stai6Prorated - 20.0) / 60.0).clamp(0.0, 1.0);
    final arousal01 = (i.arousal0To100 / 100.0).clamp(0.0, 1.0);
    final valence01 = (i.valence0To100 / 100.0).clamp(0.0, 1.0);
    final demand01 = (i.demand0To100 / 100.0).clamp(0.0, 1.0);
    final resources01 = (i.resources0To100 / 100.0).clamp(0.0, 1.0);
    final distress01 = (i.distress0To100 / 100.0).clamp(0.0, 1.0);

    final gap = (demand01 - resources01).clamp(-1.0, 1.0);

    // A challenge/threat blend: when demand > resources, it's closer to threat.
    final threat01 = _sigmoid((gap - 0.10) * 6.0); // ~0.5 around 0.1 gap

    // Subjective index emphasizes immediate distress + arousal + state anxiety.
    final subjectiveIndex = (0.30 * arousal01 + 0.25 * distress01 + 0.25 * stai01 + 0.20 * threat01).clamp(0.0, 1.0);

    // ----- Physiological (0..1)
    // Baselines: prefer Fitbit resting HR/HRV, fallback to provided baselines.
    final baseHr = (i.fitbit?.restingHeartRate ?? i.baselineRestingHr ?? 60.0).clamp(35.0, 110.0);
    final baseRmssd = (i.fitbit?.hrvRmssdMs ?? i.baselineRmssdMs ?? 40.0).clamp(5.0, 200.0);
    final baseBr = 16.0;

    // Choose current HR: prefer camera PPG if quality is good; else Fitbit current HR; else null.
    double? curHr;
    if (i.ppgBpm != null && (i.ppgSignalQuality ?? 0) >= 0.45) {
      curHr = i.ppgBpm;
    } else if (i.fitbit?.currentHeartRate != null) {
      curHr = i.fitbit!.currentHeartRate;
    } else if (i.ppgBpm != null) {
      // Use low-quality PPG only as weak signal.
      curHr = i.ppgBpm;
      warnings.add('PPG信号质量偏低，心率参考价值下降');
    }

    // HR elevation relative to baseline.
    final hrElev01 = curHr == null
        ? null
        : _sigmoid(((curHr - baseHr) / (baseHr * 0.25)) * 3.0); // 0.5 near +0

    // HRV suppression: lower RMSSD => higher activation.
    double? hrvSupp01;
    final curRmssd = i.ppgRmssdMs ?? i.fitbit?.hrvRmssdMs;
    if (curRmssd != null) {
      final ratio = (baseRmssd / curRmssd).clamp(0.3, 3.5); // >1 means suppressed
      hrvSupp01 = _sigmoid((ratio - 1.0) * 2.2);
    }

    // Breathing rate: if available.
    double? br01;
    if (i.fitbit?.breathingRate != null) {
      final br = i.fitbit!.breathingRate!.clamp(4.0, 40.0);
      br01 = _sigmoid(((br - baseBr) / 5.0) * 2.0);
    }

    // Sleep debt: insufficient sleep raises baseline stress.
    double? sleepDebt01;
    if (i.fitbit?.sleepMinutes != null) {
      final sleepMin = i.fitbit!.sleepMinutes!.clamp(0.0, 24 * 60.0);
      sleepDebt01 = ((420.0 - sleepMin) / 240.0).clamp(0.0, 1.0); // <7h => rises
    }
    double? sleepIneff01;
    if (i.fitbit?.sleepEfficiency != null) {
      final eff = i.fitbit!.sleepEfficiency!.clamp(0.0, 1.0);
      sleepIneff01 = ((0.90 - eff) / 0.25).clamp(0.0, 1.0);
    }

    // SpO2 & skin temp can indicate recovery strain. Use as small modifiers.
    double? spo201;
    if (i.fitbit?.spo2Avg != null) {
      final spo2 = i.fitbit!.spo2Avg!.clamp(50.0, 100.0);
      // Below ~95 usually considered low for many adults; map to higher activation.
      spo201 = ((95.0 - spo2) / 5.0).clamp(0.0, 1.0);
      if (spo2 < 93.0) {
        warnings.add('血氧平均值偏低（${spo2.toStringAsFixed(0)}%），如有不适请注意休息/必要时就医');
      }
    }
    double? temp01;
    if (i.fitbit?.skinTempDeviation != null) {
      final dev = i.fitbit!.skinTempDeviation!.clamp(-10.0, 10.0);
      final abs = dev.abs();
      temp01 = ((abs - 0.3) / 1.5).clamp(0.0, 1.0);
      if (abs >= 1.0) {
        warnings.add('皮温相对基线偏离较大（${dev >= 0 ? '+' : ''}${dev.toStringAsFixed(1)}°C），可能提示恢复压力/作息影响');
      }
    }

    // Exercise confound: high recent steps/azm means HR elevation might be activity.
    final exertion = _computeExertion01(i.fitbit);
    if (exertion != null && exertion >= 0.65) {
      warnings.add('检测到可能的运动/活动混淆，心率升高会被下调权重');
    }

    // Aggregate physiological index with best-effort weighting.
    double phys = 0.0;
    double wSum = 0.0;
    void add(double? v, double w) {
      if (v == null) return;
      phys += v * w;
      wSum += w;
    }

    add(hrElev01, 0.40);
    add(hrvSupp01, 0.35);
    add(br01, 0.10);
    add(sleepDebt01, 0.10);
    add(sleepIneff01, 0.05);
    add(spo201, 0.04);
    add(temp01, 0.04);
    add(spo201, 0.05);
    add(temp01, 0.05);

    if (wSum <= 0.0) {
      warnings.add('缺少可用的客观生理数据（PPG/可穿戴），综合结果更依赖主观量表');
    }
    phys = (wSum <= 0.0) ? 0.0 : (phys / wSum).clamp(0.0, 1.0);

    // Downweight physiological if exertion likely.
    final exertion01 = exertion ?? 0.0;
    if (exertion01 > 0.0) {
      final down = (1.0 - 0.35 * exertion01).clamp(0.65, 1.0);
      phys = (phys * down).clamp(0.0, 1.0);
    }

    // ----- Composite arousal (0..10)
    final subjWeight = (wSum <= 0.0) ? 0.65 : 0.45;
    final physWeight = 1.0 - subjWeight;
    final composite01 = (subjWeight * subjectiveIndex + physWeight * phys).clamp(0.0, 1.0);
    final arousal0To10 = (composite01 * 10.0).clamp(0.0, 10.0);

    // ----- Confidence (0..1)
    double conf = 0.20; // baseline
    // subjective completeness
    conf += 0.25; // stai + sliders are always present
    // PPG quality
    final sqi = i.ppgSignalQuality;
    if (i.ppgBpm != null && sqi != null) {
      if (sqi >= 0.55) {
        conf += 0.22;
      } else if (sqi >= 0.45) {
        conf += 0.15;
      } else {
        conf += 0.05;
      }
    }
    // Fitbit availability
    final fb = i.fitbit;
    int fbSignals = 0;
    if (fb?.restingHeartRate != null) fbSignals++;
    if (fb?.currentHeartRate != null) fbSignals++;
    if (fb?.hrvRmssdMs != null) fbSignals++;
    if (fb?.sleepMinutes != null) fbSignals++;
    if (fb?.breathingRate != null) fbSignals++;
    if (fbSignals >= 3) {
      conf += 0.23;
    } else if (fbSignals >= 1) {
      conf += 0.12;
    }

    conf = conf.clamp(0.0, 1.0);

    // ----- Zone classification
    final zone = _classifyZone(
      arousal0To10: arousal0To10,
      distress01: distress01,
      gap: gap,
      subjectiveIndex: subjectiveIndex,
      physiologicalIndex: phys,
      valence01: valence01,
    );

    final explanation = _buildExplanation(
      arousal0To10: arousal0To10,
      zone: zone,
      confidence: conf,
      subjectiveIndex: subjectiveIndex,
      physiologicalIndex: phys,
      baseHr: baseHr,
      curHr: curHr,
      baseRmssd: baseRmssd,
      curRmssd: curRmssd,
      demand01: demand01,
      resources01: resources01,
      distress01: distress01,
    );

    return ArousalResult(
      arousal0To10: arousal0To10,
      zone: zone,
      confidence0To1: conf,
      subjectiveIndex0To1: subjectiveIndex,
      physiologicalIndex0To1: phys,
      explanation: explanation,
      warnings: warnings,
    );
  }

  static ArousalZone _classifyZone({
    required double arousal0To10,
    required double distress01,
    required double gap,
    required double subjectiveIndex,
    required double physiologicalIndex,
    required double valence01,
  }) {
    // Comfort: low activation + low gap + low distress.
    if (arousal0To10 < 3.5 && distress01 < 0.45 && gap < 0.15) {
      return ArousalZone.comfort;
    }
    // Panic: high distress, very high activation, or high demand-resource gap + high activation.
    if (distress01 >= 0.85) return ArousalZone.panic;
    if (arousal0To10 >= 7.5 && distress01 >= 0.60) return ArousalZone.panic;
    if (gap >= 0.25 && (subjectiveIndex >= 0.70 || physiologicalIndex >= 0.70)) return ArousalZone.panic;
    // Very negative valence + high distress pushes toward panic.
    if (valence01 < 0.25 && distress01 >= 0.70 && arousal0To10 >= 6.5) return ArousalZone.panic;

    return ArousalZone.learning;
  }

  static double? _computeExertion01(FitbitMetrics? fb) {
    if (fb == null) return null;
    // recentSteps15m > ~250 often implies walking; >500 implies brisk.
    final rs = fb.recentSteps15m;
    double step01 = 0.0;
    if (rs != null) {
      step01 = ((rs - 150.0) / 500.0).clamp(0.0, 1.0);
    }
    final azm = fb.activeZoneMinutes;
    double azm01 = 0.0;
    if (azm != null) {
      azm01 = (azm / 30.0).clamp(0.0, 1.0);
    }
    final out = math.max(step01, azm01);
    if (out <= 0.0) return null;
    return out;
  }

  static String _buildExplanation({
    required double arousal0To10,
    required ArousalZone zone,
    required double confidence,
    required double subjectiveIndex,
    required double physiologicalIndex,
    required double baseHr,
    required double? curHr,
    required double baseRmssd,
    required double? curRmssd,
    required double demand01,
    required double resources01,
    required double distress01,
  }) {
    final sb = StringBuffer();
    sb.write('综合唤醒 ${arousal0To10.toStringAsFixed(1)}/10 · ${arousalZoneLabel(zone)}');
    sb.write('（置信度 ${(confidence * 100).toStringAsFixed(0)}%）\n');

    sb.write('主观指数 ${(subjectiveIndex * 100).toStringAsFixed(0)}%');
    sb.write('，客观指数 ${(physiologicalIndex * 100).toStringAsFixed(0)}%。');

    sb.write('\n');
    sb.write('需求 ${(demand01 * 100).toStringAsFixed(0)} / 资源 ${(resources01 * 100).toStringAsFixed(0)}');
    sb.write('，困扰 ${(distress01 * 100).toStringAsFixed(0)}。');

    if (curHr != null) {
      final delta = curHr - baseHr;
      sb.write('\n心率 ${curHr.toStringAsFixed(0)} bpm');
      sb.write('（较基线 ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}）');
    }
    if (curRmssd != null) {
      final ratio = (curRmssd / baseRmssd).clamp(0.05, 5.0);
      sb.write('，HRV(RMSSD) ${curRmssd.toStringAsFixed(0)}ms');
      sb.write('（基线的 ${(ratio * 100).toStringAsFixed(0)}%）');
    }
    return sb.toString();
  }

  static double _sigmoid(double x) {
    // numerically stable
    if (x >= 0) {
      final z = math.exp(-x);
      return 1.0 / (1.0 + z);
    } else {
      final z = math.exp(x);
      return z / (1.0 + z);
    }
  }
}
