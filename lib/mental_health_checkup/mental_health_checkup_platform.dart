import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class MentalHealthCheckupPlatform {
  static const MethodChannel _channel =
      MethodChannel('com.example.quote_app/mental_health_checkup');

  const MentalHealthCheckupPlatform();

  Future<String> encryptSensitiveText(String value) async {
    if (value.isEmpty) return '';
    if (!Platform.isAndroid) {
      return 'development:${base64Encode(utf8.encode(value))}';
    }
    final encrypted =
        await _channel.invokeMethod<String>('encryptText', <String, Object?>{
      'value': value,
    });
    if (encrypted == null || encrypted.isEmpty) {
      throw PlatformException(
        code: 'encryption_failed',
        message: '敏感字段加密失败。',
      );
    }
    return encrypted;
  }

  Future<String> decryptSensitiveText(String value) async {
    if (value.isEmpty) return '';
    if (!Platform.isAndroid) {
      if (!value.startsWith('development:')) return value;
      return utf8.decode(base64Decode(value.substring('development:'.length)));
    }
    return await _channel.invokeMethod<String>(
          'decryptText',
          <String, Object?>{'value': value},
        ) ??
        '';
  }

  Future<bool> exportEncryptedBackup({
    required String payload,
    required String password,
    required String suggestedName,
  }) async {
    _requireAndroid();
    return await _channel.invokeMethod<bool>(
          'exportEncryptedBackup',
          <String, Object?>{
            'payload': payload,
            'password': password,
            'suggestedName': suggestedName,
          },
        ) ??
        false;
  }

  Future<String?> importEncryptedBackup({required String password}) async {
    _requireAndroid();
    return _channel.invokeMethod<String>(
      'importEncryptedBackup',
      <String, Object?>{'password': password},
    );
  }

  Future<bool> exportReportPdf({
    required String suggestedName,
    required String title,
    required List<String> lines,
  }) async {
    _requireAndroid();
    return await _channel.invokeMethod<bool>(
          'exportReportPdf',
          <String, Object?>{
            'suggestedName': suggestedName,
            'title': title,
            'lines': lines,
          },
        ) ??
        false;
  }

  Future<void> setSecureScreen(bool enabled) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>(
      'setSecureScreen',
      <String, Object?>{'enabled': enabled},
    );
  }

  Future<bool> canAuthenticateAppLock() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('isDeviceLockAvailable') ?? false;
  }

  Future<bool> authenticateAppLock() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('authenticateAppLock') ?? false;
  }

  Future<void> scheduleReminders({
    required bool enabled,
    required int hour,
    required int minute,
    required int quietStartHour,
    required int quietEndHour,
    required bool lockScreenPrivacy,
    required int? nextRetestAtMs,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>(
      'scheduleReminders',
      <String, Object?>{
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'quietStartHour': quietStartHour,
        'quietEndHour': quietEndHour,
        'lockScreenPrivacy': lockScreenPrivacy,
        'nextRetestAtMs': nextRetestAtMs,
      },
    );
  }

  Future<void> clearSecurityAndReminders() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('clearSecurityAndReminders');
  }

  void _requireAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('此功能目前仅在 Android 版本提供。');
    }
  }
}
