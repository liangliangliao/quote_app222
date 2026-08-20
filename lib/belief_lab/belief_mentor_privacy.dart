import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Field-level encryption boundary for Belief Mentor's high-sensitivity text.
///
/// Android uses the app's existing AES-256-GCM Keystore channel. Non-Android
/// test/development environments use an explicit development envelope so tests
/// never mistake it for production encryption. Legacy plaintext is accepted
/// only for one-time migration and is encrypted on the next DAO initialization.
class BeliefMentorSensitiveCodec {
  const BeliefMentorSensitiveCodec();

  static const MethodChannel _channel = MethodChannel(
    'com.example.quote_app/mental_health_checkup',
  );
  static const String _androidPrefix = 'keystore-v1:';
  static const String _developmentPrefix = 'development:';

  bool isEncrypted(String value) =>
      value.isEmpty ||
      value.startsWith(_androidPrefix) ||
      value.startsWith(_developmentPrefix);

  Future<String> encrypt(String value) async {
    if (value.isEmpty || isEncrypted(value)) return value;
    if (!Platform.isAndroid) {
      return '$_developmentPrefix${base64Encode(utf8.encode(value))}';
    }
    final encrypted = await _channel.invokeMethod<String>(
      'encryptText',
      <String, Object?>{'value': value},
    );
    if (encrypted == null || !encrypted.startsWith(_androidPrefix)) {
      throw StateError('Android Keystore 未返回有效密文，已阻止敏感文本写入。');
    }
    return encrypted;
  }

  Future<String> decrypt(String value) async {
    if (value.isEmpty) return '';
    if (value.startsWith(_developmentPrefix)) {
      return utf8.decode(
        base64Decode(value.substring(_developmentPrefix.length)),
      );
    }
    if (!value.startsWith(_androidPrefix)) return value;
    if (!Platform.isAndroid) {
      throw StateError('当前平台不能解密 Android Keystore 密文。');
    }
    return await _channel.invokeMethod<String>('decryptText', <String, Object?>{
          'value': value,
        }) ??
        '';
  }
}
