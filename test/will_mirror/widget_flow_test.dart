import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/ranking.dart';
import 'package:quote_app/will_mirror/presentation/me_page.dart';
import 'package:quote_app/will_mirror/presentation/module_page.dart';
import 'package:quote_app/will_mirror/presentation/workbench.dart';
import 'package:quote_app/will_mirror/presentation/design.dart';
import 'package:quote_app/will_mirror/presentation/sheets.dart';
import 'fixtures.dart';

Future<void> preview(WidgetTester tester, GlobalKey key, String name) async {
  final path = Platform.environment['WM_PREVIEW_DIR'];
  if (path == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(path).create(recursive: true);
    await File('$path/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final file = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
    if (await file.exists()) {
      for (final family in ['sans-serif', 'Roboto']) {
        final loader = FontLoader(family)
          ..addFont(
              Future.value(ByteData.sublistView(await file.readAsBytes())));
        await loader.load();
      }
    }
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'), (_) async => 1);
  });
  Future<MirrorController> controller() async {
    final c = MirrorController(
        store: MemoryStore(),
        model: OfflineModel(),
        reminders: TestReminders());
    await c.initialize();
    return c;
  }

  testWidgets(
      'independent module has one entry input and three navigation destinations',
      (tester) async {
    final c = await controller();
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
            key: key, child: WillMirrorModulePage(controller: c))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mirror-case-input')), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    await preview(tester, key, 'rebuilt-home');
    await tester.tap(find.text('逐渐认识的我').last);
    await tester.pumpAndSettle();
    expect(find.text('还没有足够的实际经历'), findsOneWidget);
    await preview(tester, key, 'rebuilt-me');
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(find.text('画面与声音'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'one free input creates a persistent case before optional AI consent',
      (tester) async {
    final c = await controller();
    await tester
        .pumpWidget(MaterialApp(home: WillMirrorModulePage(controller: c)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('mirror-case-input')), '测试：明天想了解岗位条件。');
    await tester
        .ensureVisible(find.byKey(const ValueKey('mirror-create-case')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mirror-create-case')));
    await tester.pumpAndSettle();
    expect(c.files, hasLength(1));
    expect(find.text('这次允许 AI 使用哪些资料？'), findsOneWidget);
    await tester.ensureVisible(find.text('暂不发送，继续本地记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暂不发送，继续本地记录'));
    await tester.pumpAndSettle();
    expect(find.text('这件事的工作台'), findsOneWidget);
    expect(
        c.files.single.nodes
            .where((n) => n.origin == EvidenceOrigin.aiHypothesis),
        isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'unknown observation keeps waiting and no reveal button invents result',
      (tester) async {
    final c = await controller();
    var f = prepared();
    f = commands.observe(f,
        body: observationBody(f, state: 'unknown'), evidenceText: '还没核实');
    await c.store.save(f, expectedRevision: 0);
    await c.reload();
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: mirrorTheme(Brightness.light),
        home: RepaintBoundary(
            key: key, child: CaseWorkbench(controller: c, caseId: f.id))));
    await tester.pumpAndSettle();
    expect(find.textContaining('继续等待'), findsWidgets);
    expect(c.file(f.id)!.stage, CaseStage.noObservation);
    await preview(tester, key, 'rebuilt-unknown');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'active source detail removes private content immediately after withdrawal',
      (tester) async {
    final c = await controller();
    final f = await c.create('PRIVATE_WIDGET_SENTINEL');
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showNodeDetails(context, c, f.nodes.first),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE_WIDGET_SENTINEL'), findsWidgets);
    await c.retract(f.nodes.first.id);
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE_WIDGET_SENTINEL'), findsNothing);
    expect(find.textContaining('原文'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('populated Top5 keeps counterarguments visible on a phone',
      (tester) async {
    final c = await controller();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var f = prepared();
    final descriptions = [
      '先弄清真实排班，才能判断这份工作是否留得下休息时间。',
      '收入增加可能有帮助，但还需要核实工作内容和实际成本。',
      '过早作出承诺，也可能缩小后续比较其他岗位的空间。',
      '一次简短询问能增加信息，同时保留暂不决定的余地。',
      '如果工作节奏长期不适合，短期收入未必能抵消持续消耗。'
    ];
    f = commands.append(f, [
      for (var i = 0; i < 5; i++)
        commands.record(
            f,
            NodeKind.motive,
            {
              ...motive(f, i,
                      relation: i == 2 ? 'opposes' : 'supports',
                      horizon: i == 4 ? 'long' : 'now')
                  .body,
              'summary': descriptions[i]
            },
            evidenceIds: [f.nodes.first.id],
            origin: EvidenceOrigin.aiHypothesis,
            status: NodeStatus.draft)
    ]);
    f = commands.append(f, [MotiveRanking.build(f)]).evolve(step: 1);
    await c.store.save(f, expectedRevision: 0);
    await c.reload();
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: mirrorTheme(Brightness.light),
        home: RepaintBoundary(
            key: key, child: CaseWorkbench(controller: c, caseId: f.id))));
    await tester.pumpAndSettle();
    expect(find.text('先认真看看这些理由。'), findsOneWidget);
    expect(find.text('5 条不同候选'), findsOneWidget);
    expect(find.text(descriptions[2]), findsWidgets);
    expect(tester.takeException(), isNull);
    await preview(tester, key, 'rebuilt-top5-synthetic');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'life path renders actual episodes and optional possible branches distinctly',
      (tester) async {
    final c = await controller();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var f = prepared();
    f = commands.observe(f, body: observationBody(f), evidenceText: '已经发出询问');
    f = commands.nextEpisode(f);
    f = commands.append(f, [route(f)]);
    f = commands.observe(f,
        body: {...observationBody(f), 'action': '收到回复后比较了工作时间'},
        evidenceText: '比较了实际条件');
    await c.store.save(f, expectedRevision: 0);
    await c.reload();
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: mirrorTheme(Brightness.light),
        home: Scaffold(
            body: RepaintBoundary(
                key: key,
                child: ColoredBox(
                    color: mirrorPaper, child: MirrorMePage(controller: c))))));
    await tester.pumpAndSettle();
    expect(find.textContaining('真实经历'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await preview(tester, key, 'rebuilt-life-synthetic');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
      'small screen with enlarged text has no overflow in all module tabs',
      (tester) async {
    final c = await controller();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!),
        home: WillMirrorModulePage(controller: c)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('逐渐认识的我').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
