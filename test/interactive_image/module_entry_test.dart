import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:quote_app/conscious_change/conscious_change_home_page.dart';
import 'package:quote_app/conscious_change/interactive_image/interactive_image_home_page.dart';

void main() {
  testWidgets(
      'the module homepage opens both the image library and the learning page',
      (tester) async {
    final workspace =
        Directory.systemTemp.createTempSync('interactive-image-home-');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(workspace.path);
    addTearDown(() {
      PathProviderPlatform.instance = original;
      workspace.deleteSync(recursive: true);
    });
    await tester.pumpWidget(const MaterialApp(home: ConsciousChangeHomePage()));
    expect(find.text('学习模块'), findsOneWidget);
    expect(find.text('上传图片 · 识别区域 · 设置触摸反馈'), findsOneWidget);
    await tester.tap(find.text('AI 智能图片交互'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InteractiveImageHomePage), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('学习模块'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ConsciousChangeLearningPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;

  @override
  Future<String> getApplicationSupportPath() async => path;
}
