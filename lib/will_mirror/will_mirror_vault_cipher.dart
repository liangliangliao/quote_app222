import 'dart:io';

import 'package:flutter/services.dart';

/// Encryption boundary for the private life vault.
///
/// Production never falls back to plaintext. Android delegates AES-GCM to a
/// key held by Android Keystore. Tests can inject an isolated cipher.
abstract class WillMirrorVaultCipher {
  Future<bool> isAvailable();

  Future<String> encrypt(String plaintext);

  Future<String> decrypt(String ciphertext);

  Future<void> destroyKey();
}

class AndroidKeystoreWillMirrorCipher implements WillMirrorVaultCipher {
  static const MethodChannel _channel =
      MethodChannel('com.example.quote_app/will_mirror_vault');

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String> encrypt(String plaintext) async {
    if (!Platform.isAndroid) {
      throw StateError('意志之镜私密 Vault 仅在 Android Keystore 可用时写入。');
    }
    final result = await _channel.invokeMethod<String>(
      'encrypt',
      <String, Object?>{'plaintext': plaintext},
    );
    if (result == null || !result.startsWith('wm1:')) {
      throw StateError('Android Keystore 未返回有效密文，已阻止明文写入。');
    }
    return result;
  }

  @override
  Future<String> decrypt(String ciphertext) async {
    if (!Platform.isAndroid) {
      throw StateError('当前平台无法解密意志之镜私密 Vault。');
    }
    if (!ciphertext.startsWith('wm1:')) {
      throw FormatException('拒绝读取非意志之镜加密格式的数据。');
    }
    final result = await _channel.invokeMethod<String>(
      'decrypt',
      <String, Object?>{'ciphertext': ciphertext},
    );
    if (result == null) throw StateError('Android Keystore 解密失败。');
    return result;
  }

  @override
  Future<void> destroyKey() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('destroyKey');
  }
}
