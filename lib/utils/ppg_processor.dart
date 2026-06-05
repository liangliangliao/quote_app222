import 'dart:math' as math;

/// A lightweight, on-device camera PPG processor.
///
/// Goals:
/// - More stable HR than naive peak counting.
/// - Provide a signal quality score and reject poor samples.
/// - Compute HRV RMSSD from RR intervals (estimated from peaks).
///
/// Note: Camera PPG is sensitive to motion/pressure/lighting. We therefore
/// compute a basic signal quality index (SQI) and require a minimum number of
/// peaks and plausible RR ranges.
class PpgProcessor {
  /// Bandpass filter settings (Hz) for finger PPG.
  /// Typical HR is roughly 0.8–3.0 Hz (48–180 bpm). We'll use a slightly wider
  /// band so the filter still works for both lower and higher HR cases.
  ///
  /// Many mobile PPG implementations use an approximate heart-related band
  /// around 0.5–4 Hz.
  final double hpHz;
  final double lpHz;

  PpgProcessor({this.hpHz = 0.5, this.lpHz = 4.0});

  /// Hyperbolic tangent helper.
  ///
  /// Dart's `dart:math` does not expose `tanh` on all SDK versions,
  /// so we provide a small stable implementation here.
  double _tanh(double x) {
    // Clamp to avoid overflow in exp for large |x|.
    final double xx = x.clamp(-10.0, 10.0);
    final double ePos = math.exp(xx);
    final double eNeg = math.exp(-xx);
    return (ePos - eNeg) / (ePos + eNeg);
  }

  /// Runs bandpass filter (1st order HP + 1st order LP).
  List<double> bandpass(List<double> x, double fs) {
    if (x.length < 4) return x;
    final dt = 1.0 / fs;

    // High-pass (single pole)
    final rcHp = 1.0 / (2.0 * math.pi * hpHz);
    final aHp = rcHp / (rcHp + dt);
    final hp = List<double>.filled(x.length, 0.0);
    hp[0] = 0.0;
    for (int i = 1; i < x.length; i++) {
      hp[i] = aHp * (hp[i - 1] + x[i] - x[i - 1]);
    }

    // Low-pass (single pole)
    final rcLp = 1.0 / (2.0 * math.pi * lpHz);
    final aLp = dt / (rcLp + dt);
    final bp = List<double>.filled(x.length, 0.0);
    bp[0] = hp[0];
    for (int i = 1; i < x.length; i++) {
      bp[i] = bp[i - 1] + aLp * (hp[i] - bp[i - 1]);
    }
    return bp;
  }

  /// Forward-backward (zero-phase) bandpass filtering.
  ///
  /// This reduces phase distortion (peak timing bias) compared to a single
  /// forward IIR pass, improving RR interval estimation for HRV.
  List<double> bandpassZeroPhase(List<double> x, double fs) {
    if (x.length < 8) return bandpass(x, fs);
    final y = bandpass(x, fs);
    final yr = y.reversed.toList(growable: false);
    final y2 = bandpass(yr, fs);
    return y2.reversed.toList(growable: false);
  }

  /// Simple moving average smoothing.
  List<double> movingAverage(List<double> x, int win) {
    if (win <= 1 || x.isEmpty) return x;
    final w = math.max(2, win);
    final out = List<double>.filled(x.length, 0.0);
    double sum = 0;
    for (int i = 0; i < x.length; i++) {
      sum += x[i];
      if (i >= w) sum -= x[i - w];
      final denom = (i + 1 < w) ? (i + 1) : w;
      out[i] = sum / denom;
    }
    return out;
  }

  /// Peak detection on a quasi-periodic waveform.
  ///
  /// - threshold = mean + k*std
  /// - enforce a minimum distance between peaks (in samples)
  ///
  /// Notes:
  /// Phone camera PPG is noisy; overly strict peak criteria can cause
  /// "no peak" failures (SQI=0) even when a usable HR estimate exists.
  /// We therefore keep the default relatively permissive and rely on RR
  /// plausibility + SQI regularity checks downstream.
  List<int> findPeaks(
    List<double> x, {
    required double fs,
    double k = 0.45,
    double promFactor = 0.12,
  }) {
    if (x.length < 5) return [];
    final mean = x.reduce((a, b) => a + b) / x.length;
    double varianceSum = 0;
    for (final v in x) {
      final d = v - mean;
      varianceSum += d * d;
    }
    final std = math.sqrt(varianceSum / math.max(1, x.length - 1));
    final thr = mean + k * std;

    // Minimum distance between peaks ~ 0.25s (240 bpm max).
    final minDist = math.max(1, (0.25 * fs).round());

    // Additional prominence requirement (reduces false peaks when signal is noisy).
    // NOTE: Checking only immediate neighbors is brittle when the PPG waveform
    // is smoothed (common on some devices), creating a plateau around the peak.
    // Use a small local window to compute a more standard prominence.
    final prom = promFactor * std;
    final promWin = math.max(1, (0.18 * fs).round());

    final peaks = <int>[];
    int lastPeak = -minDist;
    for (int i = 1; i < x.length - 1; i++) {
      if (i - lastPeak < minDist) continue;
      final isPeak = x[i] > thr && x[i] > x[i - 1] && x[i] >= x[i + 1];
      if (!isPeak) continue;

      // Local prominence: peak height over the higher of the local minima on
      // the left and right.
      final l0 = math.max(0, i - promWin);
      final r1 = math.min(x.length - 1, i + promWin);
      double minL = x[l0];
      for (int j = l0 + 1; j < i; j++) {
        if (x[j] < minL) minL = x[j];
      }
      double minR = x[i];
      for (int j = i + 1; j <= r1; j++) {
        if (x[j] < minR) minR = x[j];
      }
      final prominence = x[i] - math.max(minL, minR);
      if (prominence < prom) continue;

      peaks.add(i);
      lastPeak = i;
    }
    return peaks;
  }

  /// Peak tracking using an expected period (from a spectral HR estimate).
  ///
  /// When the signal is weak, threshold-based peak detection may return too
  /// few peaks (thus HRV becomes unavailable). If we have a reasonably confident
  /// BPM estimate, we can track peaks by repeatedly looking for the strongest
  /// local maximum near the expected next beat.
  ///
  /// Returns a list of peak indices (may be empty).
  List<int> trackPeaksByBpm(
    List<double> x, {
    required double fs,
    required double bpm,
  }) {
    if (x.length < 32 || fs <= 0 || bpm <= 0) return [];
    if (bpm < 35 || bpm > 200) return [];

    final period = (fs * 60.0 / bpm).round();
    if (period < 3) return [];

    final minDist = math.max(1, (0.25 * fs).round());
    final halfWin = math.max(1, (0.35 * period).round());

    int argmax(int s, int e) {
      int bestI = s;
      double bestV = x[s];
      for (int i = s + 1; i <= e; i++) {
        if (x[i] > bestV) {
          bestV = x[i];
          bestI = i;
        }
      }
      return bestI;
    }

    // Start from the global maximum in the first ~1.5 periods.
    final startEnd = math.min(x.length - 2, (period * 3 ~/ 2));
    int p0 = argmax(1, startEnd);

    // Ensure p0 is a local maximum (or near-plateau).
    if (!(x[p0] >= x[p0 - 1] && x[p0] >= x[p0 + 1])) {
      // Snap to the nearest local max in a small neighborhood.
      final s0 = math.max(1, p0 - halfWin);
      final e0 = math.min(x.length - 2, p0 + halfWin);
      p0 = argmax(s0, e0);
    }

    final peaks = <int>[p0];
    int next = p0 + period;
    while (next < x.length - 2) {
      final s = math.max(peaks.last + minDist, next - halfWin);
      final e = math.min(x.length - 2, next + halfWin);
      if (e <= s) break;

      final p = argmax(s, e);
      if (p - peaks.last >= minDist) {
        peaks.add(p);
        next = p + period;
      } else {
        next += period;
      }
    }

    return peaks;
  }

  /// Compute BPM and RMSSD from peak indices.
  ///
  /// We use a robust median-based approach (BPM from median RR) and reject
  /// large outliers using MAD. This is usually more stable on phone PPG.
  Map<String, double?> computeHrAndHrv({required List<int> peaks, required double fs, List<double>? waveform}) {
    // Allow HR with >=3 peaks (2 RR intervals). HRV needs more.
    if (peaks.length < 3) {
      return {'bpm': null, 'rmssd': null};
    }

    // RR intervals in milliseconds (from peak-to-peak).
    //
    // Note: with camera PPG, fs is usually 25–60 Hz. Using raw integer peak
    // indices quantizes RR to ~16–40 ms steps, which can bias RMSSD.
    // We therefore apply a small quadratic interpolation around each peak to
    // get sub-sample peak timing when a waveform is available.
    double _refinedIndex(int i) {
      final w = waveform;
      if (w == null) return i.toDouble();
      if (i <= 0 || i >= w.length - 1) return i.toDouble();
      final y1 = w[i - 1];
      final y2 = w[i];
      final y3 = w[i + 1];
      final denom = (y1 - 2.0 * y2 + y3);
      if (denom.abs() < 1e-12) return i.toDouble();
      // Vertex offset of parabola through (−1,y1),(0,y2),(+1,y3)
      final d = 0.5 * (y1 - y3) / denom;
      if (!d.isFinite) return i.toDouble();
      return (i.toDouble() + d.clamp(-0.5, 0.5));
    }

    final rr = <double>[]; // ms
    double prevT = _refinedIndex(peaks[0]) / fs;
    for (int i = 1; i < peaks.length; i++) {
      final t = _refinedIndex(peaks[i]) / fs;
      final ms = (t - prevT) * 1000.0;
      prevT = t;
      // plausible RR (30–200 bpm)
      if (ms >= 300 && ms <= 2000) rr.add(ms);
    }
    if (rr.length < 2) {
      return {'bpm': null, 'rmssd': null};
    }

    double median(List<double> a) {
      if (a.isEmpty) return double.nan;
      final b = List<double>.from(a)..sort();
      final mid = b.length ~/ 2;
      if (b.length.isOdd) return b[mid];
      return 0.5 * (b[mid - 1] + b[mid]);
    }

    final med0 = median(rr);
    final absDev = rr.map((v) => (v - med0).abs()).toList();
    final mad = median(absDev);

    List<double> cleaned = rr;
    if (mad.isFinite && mad > 1e-9) {
      // 1.4826 * MAD approximates std for normal distributions.
      final thr = 3.0 * 1.4826 * mad;
      cleaned = rr.where((v) => (v - med0).abs() <= thr).toList(growable: false);
      if (cleaned.length < 3) cleaned = rr;
    }

    final medRr = median(cleaned);
    final bpm = 60000.0 / medRr;

    // RMSSD (time-domain HRV) from successive RR differences.
    if (cleaned.length < 3) {
      return {'bpm': bpm, 'rmssd': null};
    }
    final diffs2 = <double>[];
    for (int i = 1; i < cleaned.length; i++) {
      final d = cleaned[i] - cleaned[i - 1];
      diffs2.add(d * d);
    }
    final meanDiff2 = diffs2.reduce((a, b) => a + b) / diffs2.length;
    final rmssd = math.sqrt(meanDiff2);

    return {'bpm': bpm, 'rmssd': rmssd};
  }

  /// Basic signal quality index (SQI) based on peak regularity and amplitude.
  /// Returns 0..1.
  double signalQuality({required List<double> filtered, required List<int> peaks, required double fs}) {
    // Allow SQI computation with >=3 peaks.
    if (filtered.isEmpty || peaks.length < 3) return 0.0;

    // amplitude proxy
    final maxV = filtered.reduce(math.max);
    final minV = filtered.reduce(math.min);
    final amp = (maxV - minV).abs();
    if (amp < 1e-6) return 0.0;

    // RR regularity
    final rr = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      rr.add((peaks[i] - peaks[i - 1]) / fs);
    }
    if (rr.length < 2) return 0.0;
    final mean = rr.reduce((a, b) => a + b) / rr.length;
    double varianceSum = 0;
    for (final v in rr) {
      final d = v - mean;
      varianceSum += d * d;
    }
    final std = math.sqrt(varianceSum / math.max(1, rr.length - 1));

    // normalize: lower std => higher quality
    final reg = (1.0 - math.min(1.0, std / (0.15 * mean))).clamp(0.0, 1.0);

    // amplitude normalized loosely (avoid device dependence): map amp to 0..1 with tanh
    final ampScore = _tanh(amp / 0.05).clamp(0.0, 1.0);

    return (0.6 * reg + 0.4 * ampScore).clamp(0.0, 1.0);
  }

  /// Estimate heart rate via a lightweight spectral scan (Goertzel) as a fallback
  /// when peak detection is unreliable (e.g. noisy signal / low SQI).
  ///
  /// Returns a map with:
  /// - bpm: best estimate (null if none)
  /// - quality: 0..1 spectral peakness (higher = clearer periodicity)
  static Map<String, double?> estimateBpmByGoertzel(
    List<double> x,
    double fs, {
    double fMinHz = 0.8,
    double fMaxHz = 3.5,
    double stepHz = 0.02,
  }) {
    if (x.length < 64 || fs <= 0) return const {'bpm': null, 'quality': null};

    // Preprocess:
    // - Remove DC
    // - Remove slow linear trend (baseline drift pushes power to fMin)
    // - Apply a Hann window to reduce edge leakage
    final mean = x.reduce((a, b) => a + b) / x.length;
    final n = x.length;
    final tmp = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      tmp[i] = x[i] - mean;
    }
    final start = tmp.first;
    final end = tmp.last;
    final denom = math.max(1, n - 1);
    final xs = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final trend = start + (end - start) * (i / denom);
      final w = 0.5 * (1.0 - math.cos(2.0 * math.pi * (i / denom)));
      xs[i] = (tmp[i] - trend) * w;
    }

    final freqs = <double>[];
    final powers = <double>[];
    double sumP = 0.0;

    // Scan frequency band.
    for (double f = fMinHz; f <= fMaxHz + 1e-9; f += stepHz) {
      final w = 2.0 * math.pi * f / fs;
      final coeff = 2.0 * math.cos(w);
      double sPrev = 0.0;
      double sPrev2 = 0.0;
      for (final v in xs) {
        final s = v + coeff * sPrev - sPrev2;
        sPrev2 = sPrev;
        sPrev = s;
      }
      final power = sPrev2 * sPrev2 + sPrev * sPrev - coeff * sPrev * sPrev2;
      if (power.isFinite && power > 0) {
        freqs.add(f);
        powers.add(power);
        sumP += power;
      } else {
        freqs.add(f);
        powers.add(0.0);
      }
    }

    if (powers.isEmpty) return const {'bpm': null, 'quality': null};

    final avgP = sumP / math.max(1, powers.length);

    double powerAt(double f) {
      if (f < fMinHz || f > fMaxHz) return 0.0;
      final idx = ((f - fMinHz) / stepHz).round();
      if (idx < 0 || idx >= powers.length) return 0.0;
      return powers[idx];
    }

    // Harmonic scoring:
    // Some PPG waveforms have a stronger 2nd harmonic, which can produce a 2x BPM error
    // if we simply take the maximum single-bin power. We therefore score each candidate
    // by combining its fundamental with its harmonics (if present), which tends to favor
    // the true fundamental frequency.
    int bestI = 0;
    double bestScore = -1.0;
    // Also track the best candidate away from band edges. Edge maxima are
    // frequently caused by residual drift or motion artifacts.
    const int edgeBins = 2;
    int bestInteriorI = 0;
    double bestInteriorScore = -1.0;

    for (int i = 0; i < freqs.length; i++) {
      final f = freqs[i];
      final p1 = powers[i];
      final p2 = powerAt(2.0 * f);
      final p3 = powerAt(3.0 * f);
      final score = p1 + 0.5 * p2 + 0.25 * p3;
      if (score > bestScore) {
        bestScore = score;
        bestI = i;
      }

      if (i >= edgeBins && i <= freqs.length - 1 - edgeBins) {
        if (score > bestInteriorScore) {
          bestInteriorScore = score;
          bestInteriorI = i;
        }
      }
    }

    // Prefer an interior maximum when it is close to the global maximum.
    // This reduces "stuck at fMin" behavior on phone PPG.
    if (bestInteriorScore > 0 && bestInteriorScore >= bestScore * 0.90) {
      bestI = bestInteriorI;
      bestScore = bestInteriorScore;
    }

    final bestF = freqs[bestI];

    if (bestF <= 0 || bestScore <= 0) return const {'bpm': null, 'quality': null};

    final ratio = bestScore / (avgP + 1e-9);

    // Map score ratio to 0..1. Ratio ~1 means flat spectrum; >=4 is pretty good.
    var quality = ((ratio - 1.0) / 3.0).clamp(0.0, 1.0);

    // If the selected peak is on/near the band edge, down-weight confidence.
    if (bestI <= edgeBins || bestI >= freqs.length - 1 - edgeBins) {
      quality = (quality * 0.55).clamp(0.0, 1.0);
    }
    return {'bpm': bestF * 60.0, 'quality': quality};
  }

}
