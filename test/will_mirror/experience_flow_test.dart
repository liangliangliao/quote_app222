import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/rules.dart';
import 'package:quote_app/will_mirror/presentation/design.dart';
import 'package:quote_app/will_mirror/presentation/experience_cards.dart';
import 'package:quote_app/will_mirror/presentation/me_page.dart';
import 'package:quote_app/will_mirror/presentation/workbench.dart';

import 'fixtures.dart';
import 'principle_application_test.dart' show principle, application;
import 'experience_qualification_test.dart'
    show taskRequirement, capability, strengthMatch, changeabilityAssessment;
import 'widget_flow_test.dart' show preview;

Future<MirrorController> controller(
    MemoryStore store, TestReminders reminders) async {
  final c = MirrorController(
      store: store,
      model: OfflineModel(),
      reminders: reminders,
      commands: commands);
  await c.initialize();
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
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

  testWidgets(
      'T332: an edited principle can be explicitly adopted on the workbench',
      (tester) async {
    final store = MemoryStore();
    var f = prepared();
    final old = principle(f);
    f = commands.append(f, [old]).evolve(step: 4);
    await store.save(f, expectedRevision: 0);
    final c = await controller(store, TestReminders());
    addTearDown(c.dispose);
    await c.recordNode(
        f.id,
        NodeKind.principle,
        {
          ...old.body,
          'thenAction': '先核实这次新增的材料要求',
          'fieldCue': '先核对新增要求。',
        },
        evidenceIds: old.evidenceIds,
        revisionOf: old.id);
    final revised = c.file(f.id)!.latest(NodeKind.principle)!;
    expect(revised.status, NodeStatus.draft);
    await tester.pumpWidget(
        MaterialApp(home: CaseWorkbench(controller: c, caseId: f.id)));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, '采用为本次参考');
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final after = c.file(f.id)!;
    expect(after.node(revised.id)!.status, NodeStatus.accepted);
    expect(
        after.latest(NodeKind.principleApplication)!.text('principleVersion'),
        revised.id);
    expect(after.latest(NodeKind.principleApplication)!.text('application'),
        'unknown');
    expect(after.node(old.id)!.body, old.body);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'T338 T339 T364: a source counterexample stops cross-case cues and OS reminders',
      () async {
    final store = MemoryStore(), reminders = TestReminders();
    var source = prepared();
    final p = principle(source);
    source = commands.append(source, [p]);
    await store.save(source, expectedRevision: 0);
    var target = prepared();
    final authorized = {for (final n in source.nodes) n.id: n};
    final match = commands.record(target, NodeKind.principleMatch, {
      'principleId': p.id,
      'routeIds': [target.selectedRouteId],
      'fit': 'applicable',
      'reason': '本轮任务要求已对照',
      'changedConditions': <String>[],
      'riskGate': 'clear',
    }, evidenceIds: [
      target.nodes.first.id
    ], links: [
      p.id
    ]);
    target = commands.append(target, [match], authorized: authorized);
    final used = application(target, p);
    target = commands.append(target, [used], authorized: authorized);
    await store.save(target, expectedRevision: 0);
    await store.saveSettings(store.config.change({
      'crossCaseIds': [source.id]
    }));
    final c = await controller(store, reminders);
    addTearDown(c.dispose);
    await c.seal(
        target.id,
        {
          ...planBody(target),
          'principleId': p.id,
          'remindAt': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 2))
              .toIso8601String(),
        },
        reminderPermission: true);
    final link = reminders.jobs.values.single;
    final seal = c.file(target.id)!.latest(NodeKind.seal)!;
    await c.addCounterEvidence(source.id, p.id, '另一情境下这种做法没有帮助，需要重新对照');
    expect(reminders.jobs, isEmpty);
    expect(reminders.cancelled, contains(link.jobId));
    expect(await c.openNotification(link), isFalse);
    expect(c.file(source.id)!.latest(NodeKind.principle)!.text('maturity'),
        'needs_review');
    final after = c.file(target.id)!;
    expect(after.node(match.id)!.status, NodeStatus.stale);
    expect(after.node(used.id)!.body, used.body);
    expect(after.node(used.id)!.usable, isTrue);
    expect(canonicalJson(after.node(seal.id)!.body), canonicalJson(seal.body));
    expect(
        EvidenceRules.principleCanBePrepared(p, after,
            authorized: c.authorizedHistory),
        isFalse);
  });

  test('T332 T364: editing a principle cancels reminders for its old version',
      () async {
    final store = MemoryStore(), reminders = TestReminders();
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    await store.save(f, expectedRevision: 0);
    final c = await controller(store, reminders);
    addTearDown(c.dispose);
    await c.seal(
        f.id,
        {
          ...planBody(f),
          'principleId': p.id,
          'remindAt': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 2))
              .toIso8601String(),
        },
        reminderPermission: true);
    final link = reminders.jobs.values.single;
    await c.recordNode(
        f.id,
        NodeKind.principle,
        {
          ...p.body,
          'thenAction': '先核实一项新要求',
          'fieldCue': '先核实新条件；有风险可暂停。',
        },
        evidenceIds: p.evidenceIds,
        revisionOf: p.id);
    expect(reminders.jobs, isEmpty);
    expect(await c.openNotification(link), isFalse);
    expect(c.file(f.id)!.node(p.id)!.text('thenAction'), p.text('thenAction'));
  });

  test(
      'T338: an empty counterexample has no side effects or reminder cancellation',
      () async {
    final store = MemoryStore(), reminders = TestReminders();
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    await store.save(f, expectedRevision: 0);
    final c = await controller(store, reminders);
    addTearDown(c.dispose);
    final before = canonicalJson(c.file(f.id)!.toJson());
    await expectLater(
        c.addCounterEvidence(f.id, p.id, '  '), throwsA(isA<MirrorProblem>()));
    expect(canonicalJson(c.file(f.id)!.toJson()), before);
    expect(reminders.cancelled, isEmpty);
  });

  testWidgets(
      'T338 T365: the counterexample UI shows review status and retains historical applications',
      (tester) async {
    final store = MemoryStore();
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    final original = application(f, p);
    f = commands.append(f, [original]);
    f = commands.append(f, [application(f, p, revisionOf: original.id)]);
    await store.save(f, expectedRevision: 0);
    final c = await controller(store, TestReminders());
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MirrorMePage(controller: c))));
    await tester.tap(find.text('个人原则'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('补充反例'));
    await tester.tap(find.text('补充反例'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '实际遇到不同情况，需要重新检查原来的条件');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('需要对照反例'), findsOneWidget);
    expect(find.text('认可这条原则'), findsNothing);
    expect(find.text('出处与 1 条应用记录'), findsOneWidget);
    expect(c.file(f.id)!.latest(NodeKind.principle)!.counterIds, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'T342: other candidates can be considered without automatically adopting either',
      (tester) async {
    final store = MemoryStore();
    var f = prepared();
    final first = principle(f, status: NodeStatus.draft);
    final other = commands.record(
        f,
        NodeKind.principle,
        {
          ...first.body,
          'summary': '另一候选：先询问是否需要协作',
          'ifCondition': '任务确实需要多人协作时',
          'thenAction': '先协商分工',
        },
        evidenceIds: first.evidenceIds,
        origin: EvidenceOrigin.aiHypothesis,
        status: NodeStatus.draft);
    f = commands.append(f, [first, other]).evolve(step: 4);
    await store.save(f, expectedRevision: 0);
    final c = await controller(store, TestReminders());
    addTearDown(c.dispose);
    await tester.pumpWidget(
        MaterialApp(home: CaseWorkbench(controller: c, caseId: f.id)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('也看看其他候选 · 可以全部跳过'));
    await tester.tap(find.text('也看看其他候选 · 可以全部跳过'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(other.text('summary')));
    await tester.tap(find.text(other.text('summary')));
    await tester.pumpAndSettle();
    expect(find.text('如果 任务确实需要多人协作时，\n就先 先协商分工。'), findsOneWidget);
    expect(c.file(f.id)!.latest(NodeKind.principleApplication), isNull);
    expect(c.file(f.id)!.node(first.id)!.status, NodeStatus.draft);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'T344 T350 T356: practical cards retain evidence and work with large text',
      (tester) async {
    var f = prepared();
    final requirement = taskRequirement(f), cap = capability(f);
    f = commands.append(f, [requirement, cap]);
    final strength = strengthMatch(f,
        requirements: [requirement.id], capabilities: [cap.id]);
    final change = changeabilityAssessment(f, 'externally_dependent');
    final boundary = commands.record(f, NodeKind.boundaryReview, {
      'ownActions': ['说明一次实际需要，并设定自己的边界'],
      'otherAutonomy': ['对方是否愿意回应'],
      'verifiedObligations': <String>[],
      'unknownObligations': ['合同是否约定了回复期限'],
      'safeOptions': ['核对记录，必要时寻求适当帮助'],
      'riskGate': 'clear',
      'nextVerification': '核对约定的实际内容与对方回应',
    }, evidenceIds: [
      f.nodes.first.id
    ]);
    f = commands.append(f, [strength, change, boundary]);
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = 0;
    final content = ListView(padding: const EdgeInsets.all(16), children: [
      StrengthOpportunityCard(
          node: strength, resolve: f.node, onDetails: () => opened++),
      ChangeabilityCard(
          node: change, resolve: f.node, onDetails: () => opened++),
      InterpersonalBoundaryCard(node: boundary, onDetails: () => opened++),
    ]);
    await tester.pumpWidget(MaterialApp(
        theme: mirrorTheme(Brightness.light),
        home: RepaintBoundary(key: key, child: Scaffold(body: content))));
    await tester.pumpAndSettle();
    await preview(tester, key, 'experience-opportunities-synthetic');
    await tester.tap(find.text('条件、依据与重查时机').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('能力出处：'), findsOneWidget);
    await tester.ensureVisible(find.text('查看原始出处与反例').first);
    await tester.tap(find.text('查看原始出处与反例').first);
    expect(opened, 1);
    tester.view.physicalSize = const Size(320, 760);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 760), textScaler: TextScaler.linear(1.8)),
            child: Scaffold(body: content))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
