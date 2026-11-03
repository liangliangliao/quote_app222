import 'dart:async';
import '../data/kv_dao.dart';

class GlobalAiRequestConfig {
  final int? timeoutSeconds;
  final int? maxOutputTokens;
  final double? temperature;
  final double? topP;
  final int? retryCount;
  final int? retryDelayMs;

  const GlobalAiRequestConfig({
    required this.timeoutSeconds,
    int? maxOutputTokens,
    required this.temperature,
    required this.topP,
    required this.retryCount,
    required this.retryDelayMs,
  }) : maxOutputTokens = null;

  int resolveMaxTokens(int fallback) {
    // Compatibility with existing adapters: 0 means no application quota.
    return 0;
  }

  Duration resolveTimeout(Duration fallback) {
    final value = timeoutSeconds;
    if (value == null || value <= 0) return fallback;
    return Duration(seconds: value.clamp(5, 600).toInt());
  }

  double? resolveTemperature([double? fallback]) {
    final value = temperature;
    if (value == null) return fallback;
    return value.clamp(0.0, 2.0);
  }

  double? resolveTopP([double? fallback]) {
    final value = topP;
    if (value == null) return fallback;
    return value.clamp(0.0, 1.0);
  }

  int resolveRetryCount([int fallback = 0]) {
    final value = retryCount;
    if (value == null || value < 0) return fallback;
    return value.clamp(0, 5).toInt();
  }

  int resolveRetryDelayMs([int fallback = 800]) {
    final value = retryDelayMs;
    if (value == null || value < 0) return fallback;
    return value.clamp(0, 10000).toInt();
  }
}

class GlobalAiRequestSettings {
  static GlobalAiRequestConfig? cached;
  static final changes = StreamController<GlobalAiRequestConfig>.broadcast();
  static const String timeoutSecondsKey = 'global_ai_request_timeout_seconds';
  static const String maxOutputTokensKey =
      'global_ai_request_max_output_tokens';
  static const String temperatureKey = 'global_ai_request_temperature';
  static const String topPKey = 'global_ai_request_top_p';
  static const String retryCountKey = 'global_ai_request_retry_count';
  static const String retryDelayMsKey = 'global_ai_request_retry_delay_ms';

  final KeyValueDao _kvDao = KeyValueDao();

  Future<GlobalAiRequestConfig> getConfig() async {
    final values = {
      for (final row in await _kvDao.keyValuesWithPrefix('global_ai_request_'))
        row['key']: row['value']
    };
    final config = GlobalAiRequestConfig(
        timeoutSeconds: _parseInt(values[timeoutSecondsKey]),
        maxOutputTokens: null,
        temperature: _parseDouble(values[temperatureKey]),
        topP: _parseDouble(values[topPKey]),
        retryCount: _parseInt(values[retryCountKey]),
        retryDelayMs: _parseInt(values[retryDelayMsKey]));
    cached = config;
    changes.add(config);
    return config;
  }

  Future<void> saveRaw({
    required String timeoutSeconds,
    required String maxOutputTokens,
    required String temperature,
    required String topP,
    required String retryCount,
    required String retryDelayMs,
  }) async {
    await _kvDao.setString(timeoutSecondsKey, timeoutSeconds.trim());
    await _kvDao.setString(maxOutputTokensKey, '');
    await _kvDao.setString(temperatureKey, temperature.trim());
    await _kvDao.setString(topPKey, topP.trim());
    await _kvDao.setString(retryCountKey, retryCount.trim());
    await _kvDao.setString(retryDelayMsKey, retryDelayMs.trim());
    await getConfig();
  }

  int? _parseInt(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  double? _parseDouble(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
}
