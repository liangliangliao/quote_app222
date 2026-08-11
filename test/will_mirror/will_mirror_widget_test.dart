import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/will_mirror_discover_entry.dart';
import 'package:quote_app/will_mirror/will_mirror_home_page.dart';
import 'package:quote_app/will_mirror/will_mirror_knowledge_repository.dart';
import 'package:quote_app/will_mirror/will_mirror_vault.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets('Discover entry has stable key and opens Will Mirror',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WillMirrorDiscoverEntry(onTap: () => opened = true),
        ),
      ),
    );

    expect(find.byKey(WillMirrorDiscoverEntry.entryKey), findsOneWidget);
    expect(find.text('意志之镜 · 自我一致人生'), findsOneWidget);
    expect(find.textContaining('强制反证'), findsOneWidget);

    await tester.tap(find.byKey(WillMirrorDiscoverEntry.entryKey));
    expect(opened, isTrue);
  });

  testWidgets('home exposes the five long-term V4 entries', (tester) async {
    final directory = await Directory.systemTemp.createTemp('will_mirror_ui_');
    final vault = WillMirrorVault(
      factory: databaseFactoryFfi,
      baseDirectoryProvider: () async => directory.path,
    );
    final knowledge = WillMirrorKnowledgeRepository(
      factory: databaseFactoryFfi,
      baseDirectoryProvider: () async => directory.path,
    );
    addTearDown(() async {
      await vault.close();
      await knowledge.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WillMirrorHomePage(vault: vault, knowledge: knowledge),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前欲望'), findsOneWidget);
    expect(find.text('Why Tree'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Real-Me'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Real-Me'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('行动镜'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('行动镜'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('当前实验'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('当前实验'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('不是精神疾病诊断'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('不是精神疾病诊断'), findsOneWidget);
  });
}
