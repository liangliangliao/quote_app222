import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../../data/self_help_dao.dart';

/// Fitbit OAuth + API client (Web API).
///
/// Notes:
/// - Uses Authorization Code + PKCE.
/// - Stores tokens locally (SQLite via [FitbitDao]).
/// - You must register your Fitbit app with redirect URI:
///   quoteappfitbit://auth
///
/// For some intraday endpoints, Fitbit requires additional approvals for
/// third-party apps depending on the application type and data type.
class FitbitClient {
  FitbitClient({required this.clientId, required this.clientSecret});

  final String clientId;
  final String clientSecret;

  static const String _redirectUri = 'quoteappfitbit://auth';
  static const String _tokenUrl = 'https://api.fitbit.com/oauth2/token';

  final FitbitDao _dao = FitbitDao();

  /// Start OAuth and save tokens.
  Future<void> connect({List<String> scopes = const [
    'profile',
    'activity',
    'heartrate',
    'sleep',
    'respiratory_rate',
    'oxygen_saturation',
    'temperature',
    'cardio_fitness',
    'nutrition',
    'weight',
    'settings',
    'social',
    // Newer/limited-access scopes (may require additional permissions):
    'electrocardiogram',
    'irregular_rhythm_notifications',
  ]}) async {
    final verifier = _codeVerifier();
    final challenge = _codeChallenge(verifier);
    final scope = Uri.encodeComponent(scopes.join(' '));
    final authUrl =
        'https://www.fitbit.com/oauth2/authorize?response_type=code&client_id=$clientId&redirect_uri=${Uri.encodeComponent(_redirectUri)}&scope=$scope&code_challenge=$challenge&code_challenge_method=S256';

    final result = await FlutterWebAuth2.authenticate(url: authUrl, callbackUrlScheme: 'quoteappfitbit');
    final uri = Uri.parse(result);
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('Fitbit OAuth failed: missing code');
    }
    await _exchangeCode(code: code, codeVerifier: verifier);
  }

  Future<void> _exchangeCode({required String code, required String codeVerifier}) async {
    final basic = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final resp = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Authorization': 'Basic $basic',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'client_id': clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'code_verifier': codeVerifier,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Fitbit token exchange failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final accessToken = (json['access_token'] ?? '') as String;
    final refreshToken = (json['refresh_token'] ?? '') as String;
    final userId = (json['user_id'] ?? '') as String;
    final scope = (json['scope'] ?? '') as String;
    final expiresIn = (json['expires_in'] ?? 0) as int;
    final expiresAtMs = DateTime.now().millisecondsSinceEpoch + expiresIn * 1000;

    await _dao.upsertAuth(
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      scope: scope,
      expiresAtMs: expiresAtMs,
    );
  }

  Future<String?> _ensureAccessToken() async {
    final auth = await _dao.getAuth();
    if (auth == null) return null;
    final accessToken = (auth['access_token'] ?? '') as String;
    final refreshToken = (auth['refresh_token'] ?? '') as String;
    final userId = (auth['user_id'] ?? '') as String;
    final scope = (auth['scope'] ?? '') as String;
    final expiresAt = (auth['expires_at_ms'] ?? 0) as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (accessToken.isNotEmpty && now < expiresAt - 30 * 1000) {
      return accessToken;
    }
    // refresh
    final basic = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final resp = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Authorization': 'Basic $basic',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // keep the old token so user can reconnect later.
      throw Exception('Fitbit refresh failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final newAccess = (json['access_token'] ?? '') as String;
    final newRefresh = (json['refresh_token'] ?? '') as String;
    final expiresIn = (json['expires_in'] ?? 0) as int;
    final expiresAtMs = DateTime.now().millisecondsSinceEpoch + expiresIn * 1000;
    await _dao.upsertAuth(
      userId: userId,
      accessToken: newAccess,
      refreshToken: newRefresh,
      scope: scope,
      expiresAtMs: expiresAtMs,
    );
    return newAccess;
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final token = await _ensureAccessToken();
    if (token == null) throw Exception('Fitbit not connected');
    final resp = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Fitbit API error: ${resp.statusCode} ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Fetch a broad set of Fitbit endpoints and cache raw JSON locally (best-effort).
  ///
  /// This is a pragmatic subset that most devices support:
  /// - Heart rate intraday (minute) for today
  /// - Sleep logs for today
  /// - HRV summary (sleep) for today
  Future<void> syncToday() async {
    final today = DateTime.now();
    final date = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final Map<String, String> endpoints = {
      // ---- Profile / devices ----
      'profile': 'https://api.fitbit.com/1/user/-/profile.json',
      'devices': 'https://api.fitbit.com/1/user/-/devices.json',
      // Friends (requires social scope)
      'friends': 'https://api.fitbit.com/1.1/user/-/friends.json',

      // ---- Activity / heart ----
      // Heart rate intraday (1min)
      'heartrate_intraday': 'https://api.fitbit.com/1/user/-/activities/heart/date/$date/1d/1min.json',
      // Daily activity summary
      'activity_summary': 'https://api.fitbit.com/1/user/-/activities/date/$date.json',
      // Intraday activity time series (best-effort; may require intraday approval)
      'steps_intraday': 'https://api.fitbit.com/1/user/-/activities/steps/date/$date/1d/1min.json',
      'calories_intraday': 'https://api.fitbit.com/1/user/-/activities/calories/date/$date/1d/1min.json',
      'distance_intraday': 'https://api.fitbit.com/1/user/-/activities/distance/date/$date/1d/1min.json',
      'floors_intraday': 'https://api.fitbit.com/1/user/-/activities/floors/date/$date/1d/1min.json',
      'elevation_intraday': 'https://api.fitbit.com/1/user/-/activities/elevation/date/$date/1d/1min.json',

      // Activity minutes (daily)
      'minutes_sedentary': 'https://api.fitbit.com/1/user/-/activities/minutesSedentary/date/$date/1d.json',
      'minutes_lightly_active': 'https://api.fitbit.com/1/user/-/activities/minutesLightlyActive/date/$date/1d.json',
      'minutes_fairly_active': 'https://api.fitbit.com/1/user/-/activities/minutesFairlyActive/date/$date/1d.json',
      'minutes_very_active': 'https://api.fitbit.com/1/user/-/activities/minutesVeryActive/date/$date/1d.json',

      // Active Zone Minutes (daily & intraday; intraday may 403)
      'active_zone_minutes_daily': 'https://api.fitbit.com/1/user/-/activities/active-zone-minutes/date/$date/1d.json',
      'active_zone_minutes_intraday': 'https://api.fitbit.com/1/user/-/activities/active-zone-minutes/date/$date/1d/1min.json',

      // Cardio fitness score (VO2 Max)
      'cardioscore': 'https://api.fitbit.com/1/user/-/cardioscore/date/$date.json',

      // ---- Sleep / health metrics (sleep-based) ----
      'sleep': 'https://api.fitbit.com/1.2/user/-/sleep/date/$date.json',
      'hrv': 'https://api.fitbit.com/1/user/-/hrv/date/$date.json',
      'hrv_intraday': 'https://api.fitbit.com/1/user/-/hrv/date/$date/all.json',
      'spo2': 'https://api.fitbit.com/1/user/-/spo2/date/$date.json',
      'spo2_intraday': 'https://api.fitbit.com/1/user/-/spo2/date/$date/all.json',
      'breathing_rate': 'https://api.fitbit.com/1/user/-/br/date/$date.json',
      'breathing_rate_intraday': 'https://api.fitbit.com/1/user/-/br/date/$date/all.json',
      'skin_temperature': 'https://api.fitbit.com/1/user/-/temp/skin/date/$date.json',
      'skin_temperature_intraday': 'https://api.fitbit.com/1/user/-/temp/skin/date/$date/all.json',

      // ---- Body / nutrition logs ----
      'weight_logs': 'https://api.fitbit.com/1/user/-/body/log/weight/date/$date.json',
      'fat_logs': 'https://api.fitbit.com/1/user/-/body/log/fat/date/$date.json',
      'water_logs': 'https://api.fitbit.com/1/user/-/foods/log/water/date/$date.json',
      'food_logs': 'https://api.fitbit.com/1/user/-/foods/log/date/$date.json',

      // ---- ECG / Irregular Rhythm Notifications (may be restricted) ----
      'ecg_list': 'https://api.fitbit.com/1/user/-/ecg/list.json',
      'irn_profile': 'https://api.fitbit.com/1/user/-/irn/profile.json',
      'irn_alerts': 'https://api.fitbit.com/1/user/-/irn/alerts/list.json',
    };

    // Fetch best-effort: some endpoints may not be available for every account/device.
    for (final entry in endpoints.entries) {
      try {
        final json = await _getJson(entry.value);
        await _dao.upsertCache(cacheKey: '${entry.key}_$date', endpoint: entry.key, date: date, json: json);
      } catch (_) {
        // ignore single-endpoint failures; keep syncing others
      }
    }
  }

  /// Get today's cached heart rate (minute level) if available.
  Future<Map<String, dynamic>?> getCachedTodayHeartRate() async {
    final today = DateTime.now();
    final date = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return await _dao.getCache('heartrate_intraday_$date');
  }

  Future<Map<String, dynamic>?> getCachedTodayHrv() async {
    final today = DateTime.now();
    final date = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return await _dao.getCache('hrv_$date');
  }

  // --- PKCE helpers ---

  String _codeVerifier() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rnd = Random.secure();
    final len = 64;
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String _codeChallenge(String verifier) {
    final bytes = sha256.convert(utf8.encode(verifier)).bytes;
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
