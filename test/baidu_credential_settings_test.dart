import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/data/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory docs;
  setUpAll(() async {
    docs = await Directory.systemTemp.createTemp('baidu_config_');
    databaseFactory = databaseFactoryFfiNoIsolate;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    await AppDatabase.instance();
  });
  tearDownAll(() async {
    await (await AppDatabase.instance()).close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await docs.delete(recursive: true);
  });

  test(
    'Baidu starts unconfigured and retains separately saved Web and Android settings',
    () async {
      final settings = ConfigDao();
      expect(await settings.getBaiduAk(), isEmpty);
      expect(await settings.getBaiduAndroidAk(), isEmpty);
      await settings.setBaiduAk(' test-web-setting ');
      expect(await ConfigDao().getBaiduAk(), 'test-web-setting');
      expect(
        await ConfigDao().getBaiduAndroidAk(),
        isEmpty,
        reason:
            'A Web API credential cannot substitute for an Android SDK credential.',
      );
      await settings.setBaiduAndroidAk(' test-android-setting ');
      expect(await ConfigDao().getBaiduAndroidAk(), 'test-android-setting');
      expect(await ConfigDao().getBaiduAk(), 'test-web-setting');
      await settings.setBaiduAk('');
      await settings.setBaiduAndroidAk('');
      expect(await ConfigDao().getBaiduAk(), isEmpty);
      expect(await ConfigDao().getBaiduAndroidAk(), isEmpty);
    },
  );
}
