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

  test('内容拒绝原因能从全局日志的错误筛选中找到，并保留原始返回', () async {
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
        errorMessage: 'AI 已返回引导，但还需要调整：缺少 embodied_shift',
      );
      final errors = await LogDao().latest(
          errorOnly: true, keyword: 'meditation.daily_script.validation');
      expect(errors, hasLength(1));
      expect(errors.single['detail'], contains('【OpenRouter异常】'));
      expect(errors.single['detail'], contains('缺少 embodied_shift'));
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
