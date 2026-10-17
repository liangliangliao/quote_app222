import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/meditation_module/meditation_dao.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('确实没有可读正文时保留原响应，日志可按错误筛选', () async {
    final docs =
        await Directory.systemTemp.createTemp('meditation_validation_log_');
    databaseFactory = databaseFactoryFfi;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const native = MethodChannel('native.scheduler');
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => docs.path);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (_) async => null);
    try {
      await MeditationDao().insertAiOutput(
        feature: 'daily_script',
        inputJson: '{}',
        outputText: '{"segments":[]}',
        provider: 'openrouter',
        model: 'test-only-model',
        success: false,
        errorMessage: 'AI 已返回内容，但未能读取到可播放的引导正文；未自动重写',
      );
      final errors = await LogDao().latest(
          errorOnly: true, keyword: 'meditation.daily_script.validation');
      expect(errors, hasLength(1));
      expect(errors.single['detail'], contains('【OpenRouter异常】'));
      expect(errors.single['detail'], contains('未能读取到可播放的引导正文'));
      final db = await AppDatabase.instance();
      final saved = await db.query('meditation_ai_outputs');
      expect(saved.single['output_text'], '{"segments":[]}');
      expect(saved.single['success'], 0);
      await db.close();
    } finally {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
      binding.defaultBinaryMessenger.setMockMethodCallHandler(native, null);
      await docs.delete(recursive: true);
    }
  });
}
