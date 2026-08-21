import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 宿主开库冒烟测试。
///
/// main() 在 runApp 之前会 await 一次开库；那里的 try/catch 只挡得住异常，挡不住
/// 永不返回。所以这里给开库上时限：卡住就是启动卡在闪屏。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory docs;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('host_db_open_');
    databaseFactory = databaseFactoryFfi;

    // path_provider 与原生通道在测试里没有实现，按宿主的调用形状挡掉。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => docs.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('native.scheduler'),
      (MethodCall call) async => null,
    );
  });

  tearDown(() async {
    try {
      await docs.delete(recursive: true);
    } catch (_) {}
  });

  test('opening the host database finishes instead of hanging', () async {
    final Database db = await AppDatabase.instance().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('开库没有返回：启动会卡在闪屏'),
    );

    // 火种的表应该在开库后就位。
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'k!_%' ESCAPE '!'",
    );
    expect(
      rows.map((Map<String, Object?> r) => '${r['name']}'),
      contains('k_item'),
    );
  });
}

class TimeoutException implements Exception {
  TimeoutException(this.message);
  final String message;
  @override
  String toString() => message;
}
