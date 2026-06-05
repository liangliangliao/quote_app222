import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

/// Downloads an image from [url] and saves it to an app-owned folder.
///
/// Notes:
/// - To avoid adding extra permissions/dependencies, this saves into an
///   app-accessible directory (external app dir on Android when available,
///   documents dir otherwise).
/// - Returns the saved file path.
class ImageDownloader {
  static Future<String> saveImage(String url) async {
    final uri = Uri.parse(url);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('下载失败: ${res.statusCode}');
    }

    Directory baseDir;
    if (Platform.isAndroid) {
      baseDir = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final saveDir = Directory(p.join(baseDir.path, 'downloads', 'images'));
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final ext = _extFromUrl(url);
    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}$ext';
    final filePath = p.join(saveDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(res.bodyBytes, flush: true);
    return filePath;
  }

  /// Downloads an image from [url] and saves it to the system gallery.
  ///
  /// Returns a best-effort string describing the saved location/identifier.
  ///
  /// Notes:
  /// - On modern Android (scoped storage), MediaStore saving generally works
  ///   without extra permissions.
  /// - On older Android versions, we request storage permission when possible.
  static const MethodChannel _ch = MethodChannel('native.scheduler');

  /// Downloads an image from [url] and saves it to the system gallery (相册).
  ///
  /// Implementation note:
  /// - We download the image into a temporary file in Dart, then delegate the
  ///   final gallery insertion to Android via MethodChannel (MediaStore).
  /// - If saving fails, an exception will be thrown.
  static Future<String> saveImageToGallery(String url) async {
    final uri = Uri.parse(url);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('下载失败: ${res.statusCode}');
    }

    // Best-effort permissions: on Android 10+ MediaStore generally works without
    // storage permission; on older devices we try to request it.
    if (Platform.isAndroid) {
      try {
        await Permission.storage.request();
        await Permission.photos.request();
      } catch (_) {}
    } else if (Platform.isIOS) {
      try {
        await Permission.photosAddOnly.request();
      } catch (_) {}
    }

    final ext = _extFromUrl(url);
    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}$ext';

    final tmp = await getTemporaryDirectory();
    final tmpFile = File(p.join(tmp.path, fileName));
    await tmpFile.writeAsBytes(res.bodyBytes, flush: true);

    final mime = ext.toLowerCase() == '.png' ? 'image/png' : 'image/jpeg';
    final saved = await _ch.invokeMethod('saveImageToGallery', {
      'path': tmpFile.path,
      'name': fileName,
      'mime': mime,
    });

    // Native side returns a string path/uri on success.
    if (saved is String && saved.trim().isNotEmpty) return saved;
    return '相册';
  }

  static String _extFromUrl(String url) {
    try {
      final path = Uri.parse(url).path;
      final ext = p.extension(path);
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    } catch (_) {}
    return '.jpg';
  }
}
