import 'package:flutter/foundation.dart';

import '../data/db.dart';

class DiaryBgConfig {
  final String? imagePath;
  final double opacity;

  const DiaryBgConfig({this.imagePath, required this.opacity});

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}

class DiaryTheme {
  // 全局内存缓存：日记背景配置
  static final ValueNotifier<DiaryBgConfig> bgConfig =
      ValueNotifier<DiaryBgConfig>(
        const DiaryBgConfig(imagePath: null, opacity: 0.25),
      );

  static DiaryBgConfig get current => bgConfig.value;

  // 从数据库读取最新配置，写入内存缓存
  static Future<void> reloadFromDatabase() async {
    try {
      await AppDatabase.ensureDiaryColumns();
    } catch (_) {}
    try {
      final db = await AppDatabase.instance();
      final rows = await db.rawQuery(
        "SELECT diary_bg_image, diary_bg_opacity FROM configs "
        "WHERE (diary_bg_image IS NOT NULL AND diary_bg_image != '') "
        "   OR diary_bg_opacity IS NOT NULL "
        "   OR (diary_pin IS NOT NULL AND diary_pin != '') "
        "ORDER BY id DESC LIMIT 1",
      );
      String? path;
      double opacity = bgConfig.value.opacity;
      if (rows.isNotEmpty) {
        final img = rows.first['diary_bg_image'];
        final imgStr = img?.toString() ?? '';
        path = imgStr.isEmpty ? null : imgStr;
        final op = rows.first['diary_bg_opacity'];
        if (op != null) {
          opacity = double.tryParse(op.toString()) ?? opacity;
        }
      } else {
        path = null;
      }
      bgConfig.value = DiaryBgConfig(imagePath: path, opacity: opacity);
    } catch (_) {
      // ignore
    }
  }

  // 设置页一旦修改背景，先更新内存缓存，再异步落库
  static void updateInMemory({String? imagePath, required double opacity}) {
    bgConfig.value = DiaryBgConfig(imagePath: imagePath, opacity: opacity);
  }
}
