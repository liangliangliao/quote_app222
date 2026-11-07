import 'models.dart';

/// 键值存储的最小抽象。宿主用 KeyValueDao 实现；测试用 [MemoryPrpKv]。
abstract class PrpKv {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
}

class MemoryPrpKv implements PrpKv {
  final Map<String, String> data = <String, String>{};

  @override
  Future<String?> get(String key) async => data[key];

  @override
  Future<void> set(String key, String value) async => data[key] = value;
}

/// 设置页里的开关和参数。全部以 prp. 为前缀，存在 KeyValueDao 里。
class PrpSettings {
  PrpSettings(this._kv);

  final PrpKv _kv;

  static const String keyEnabled = 'prp.enabled';
  static const String keyPauseSec = 'prp.pause_sec';
  static const String keyOfferCap = 'prp.offer_cap';
  static const String keyRecallCap = 'prp.recall_cap';
  static const String keyAiConsent = 'prp.ai_consent';
  static const String keyQuoteLastMs = 'prp.quote_last_ms';
  static const String keyIntroSeen = 'prp.intro_seen';

  static String surfaceKey(PrpSurface s) => 'prp.surface.${s.key}';

  static const int defaultPauseSec = 60;
  static const int minPauseSec = 15;
  static const int maxPauseSec = 300;
  static const int defaultOfferCap = 1;
  static const int defaultRecallCap = 1;

  Future<bool> _bool(String key, bool fallback) async {
    final String? v = await _kv.get(key);
    if (v == null || v.isEmpty) return fallback;
    return v == '1';
  }

  Future<int> _int(String key, int fallback) async {
    final String? v = await _kv.get(key);
    if (v == null || v.isEmpty) return fallback;
    return int.tryParse(v) ?? fallback;
  }

  /// 总开关。默认关闭（内测期）。
  Future<bool> enabled() => _bool(keyEnabled, false);

  Future<void> setEnabled(bool v) => _kv.set(keyEnabled, v ? '1' : '0');

  Future<bool> surfaceEnabled(PrpSurface s) =>
      _bool(surfaceKey(s), s.defaultOn);

  Future<void> setSurface(PrpSurface s, bool v) =>
      _kv.set(surfaceKey(s), v ? '1' : '0');

  Future<int> pauseSec() async {
    final int v = await _int(keyPauseSec, defaultPauseSec);
    return v.clamp(minPauseSec, maxPauseSec);
  }

  Future<void> setPauseSec(int v) =>
      _kv.set(keyPauseSec, v.clamp(minPauseSec, maxPauseSec).toString());

  Future<int> offerCap() async =>
      (await _int(keyOfferCap, defaultOfferCap)).clamp(0, 5);

  Future<void> setOfferCap(int v) =>
      _kv.set(keyOfferCap, v.clamp(0, 5).toString());

  Future<int> recallCap() async =>
      (await _int(keyRecallCap, defaultRecallCap)).clamp(0, 5);

  Future<void> setRecallCap(int v) =>
      _kv.set(keyRecallCap, v.clamp(0, 5).toString());

  Future<bool> aiConsent() => _bool(keyAiConsent, false);

  Future<void> setAiConsent(bool v) => _kv.set(keyAiConsent, v ? '1' : '0');

  /// 首次开启时的一次性说明是否已经看过。
  Future<bool> introSeen() => _bool(keyIntroSeen, false);

  Future<void> setIntroSeen(bool v) => _kv.set(keyIntroSeen, v ? '1' : '0');

  Future<int> quoteLastMs() => _int(keyQuoteLastMs, 0);

  Future<void> setQuoteLastMs(int v) => _kv.set(keyQuoteLastMs, v.toString());

  Future<PrpConfig> snapshot({required bool installed}) async {
    final Map<PrpSurface, bool> surfaces = <PrpSurface, bool>{};
    for (final PrpSurface s in PrpSurface.values) {
      surfaces[s] = await surfaceEnabled(s);
    }
    return PrpConfig(
      installed: installed,
      enabled: await enabled(),
      surfaces: surfaces,
      pauseSec: await pauseSec(),
      offerCap: await offerCap(),
      recallCap: await recallCap(),
      aiConsent: await aiConsent(),
    );
  }
}
