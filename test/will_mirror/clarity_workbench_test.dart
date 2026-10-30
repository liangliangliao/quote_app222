import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/failures.dart';
import 'package:quote_app/will_mirror/presentation/design.dart';
import 'package:quote_app/will_mirror/presentation/workbench.dart';

import 'fixtures.dart';
import 'widget_flow_test.dart' show preview;

const learningText = '我想练习一项新技能，但总觉得只要失败一次，就说明我没有能力。所以练习前就想放弃。';
const learningClarity = {
  'stuckPoint': '你想学会新技能，却担心一次做不好就会变成对自己能力的否定。还没开始，压力就先到了。',
  'perspective': '一次做不好，能帮你发现这次哪里需要调整；单凭这一次，还不足以判断你能不能学会。',
  'nextStep': '先写下想练的具体技能，把目标缩成一个动作。只问“哪里需要调整”，暂时不给自己的能力下结论。',
  'whyThisStep': '先把笼统的担心变成一个具体问题，再决定怎样开始练习。',
  'question': '你想先学会哪一项具体技能？',
};

MirrorNode understanding(CaseFile f, {bool withClarity = true}) =>
    commands.record(
        f,
        NodeKind.understanding,
        {
          'summary': '你想学习，又担心失败会否定自己的能力。',
          if (withClarity) 'clarity': learningClarity,
          'facts': [
            {
              'claim': '当事人自述想练习，练习前已有放弃念头，但不能当作已经放弃。',
              'quote': f.issue,
              'evidenceIds': [f.nodes.first.id]
            }
          ],
          'unknowns': ['具体技能和练习要求未知', '是否已有练习经历尚待说明'],
          'keyQuestion': learningClarity['question'],
          'domains': ['学习'],
          'riskFlags': <String>[],
          'timeContext': 'future',
        },
        evidenceIds: [f.nodes.first.id],
        origin: EvidenceOrigin.aiHypothesis,
        status: NodeStatus.draft);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final font = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
    if (await font.exists()) {
      final bytes = ByteData.sublistView(await font.readAsBytes());
      for (final family in ['sans-serif', 'Roboto']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
    }
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'), (_) async => 1);
  });

  Future<(MirrorController, CaseFile)> contextFor(
      {bool withClarity = true}) async {
    final c = MirrorController(
        store: MemoryStore(),
        model: OfflineModel(),
        reminders: TestReminders());
    await c.initialize();
    var f = newCase(learningText);
    f = commands.append(f, [understanding(f, withClarity: withClarity)]);
    await c.store.save(f, expectedRevision: 0);
    await c.reload();
    return (c, f);
  }

  testWidgets(
      'the first screen gives a point of view and a small step before optional evidence',
      (tester) async {
    final (c, f) = await contextFor();
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: mirrorTheme(Brightness.light),
        home: RepaintBoundary(
            key: key, child: CaseWorkbench(controller: c, caseId: f.id))));
    await tester.pumpAndSettle();
    expect(find.text('我理解的卡点'), findsOneWidget);
    expect(find.text('AI 生成'), findsWidgets);
    expect(find.text(learningClarity['perspective']!), findsOneWidget);
    expect(find.text(learningClarity['nextStep']!), findsOneWidget);
    expect(find.textContaining('当事人'), findsNothing);
    expect(find.text('具体技能和练习要求未知'), findsNothing);
    expect(find.textContaining('这次满足了什么'), findsNothing);
    await preview(tester, key, 'clarity-learning-first-screen');
    await tester.ensureVisible(
        find.byKey(const ValueKey('mirror-understanding-evidence')));
    await tester.tap(find.text('原话、依据与未确认的部分'));
    await tester.pumpAndSettle();
    expect(find.text('具体技能和练习要求未知'), findsOneWidget);
    expect(find.textContaining('当事人'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'existing reports remain accessible and can request a clearer response',
      (tester) async {
    final (c, f) = await contextFor(withClarity: false);
    addTearDown(c.dispose);
    await tester.pumpWidget(
        MaterialApp(home: CaseWorkbench(controller: c, caseId: f.id)));
    await tester.pumpAndSettle();
    expect(find.text('重新梳理为简短建议'), findsOneWidget);
    expect(find.text(learningClarity['nextStep']!), findsNothing);
    expect(
        c
            .file(f.id)!
            .latest(NodeKind.understanding)!
            .body
            .containsKey('clarity'),
        isFalse);
    expect(find.text('原话、依据与未确认的部分'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('clarity remains readable on a narrow screen with large text',
      (tester) async {
    final (c, f) = await contextFor();
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 760), textScaler: TextScaler.linear(1.8)),
            child: CaseWorkbench(controller: c, caseId: f.id))));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('mirror-clarity-next-step')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recovery messages expose neither record IDs nor schema paths',
      (tester) async {
    final (c, f) = await contextFor();
    addTearDown(c.dispose);
    for (final problem in [
      const MirrorProblem('来源不存在：run_PRIVATE_0_3',
          code: 'source_reference_invalid'),
      const MirrorProblem('body.violations[0] 的数据类型或状态无效',
          code: 'response_shape_invalid'),
    ]) {
      c.error = analysisFailureMessage(problem);
      await tester.pumpWidget(
          MaterialApp(home: CaseWorkbench(controller: c, caseId: f.id)));
      await tester.pumpAndSettle();
      expect(find.textContaining('run_PRIVATE'), findsNothing);
      expect(find.textContaining('body.violations'), findsNothing);
      expect(find.text('重试这一步'), findsOneWidget);
      expect(find.textContaining('检查资料'), findsNothing);
      expect(find.text(learningClarity['perspective']!), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
