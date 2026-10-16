import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/ai/workbench_pass.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/ranking.dart';
import 'package:quote_app/will_mirror/presentation/design.dart';
import 'package:quote_app/will_mirror/presentation/workbench.dart';
import 'fixtures.dart';
import 'intent_workbench_test.dart' show fitBody;
import 'widget_flow_test.dart' show preview;

/// Entirely fictional rendering data. It never becomes a production fallback
/// or a local user's evidence, and it does not claim any real model output.
CaseFile visualCase() {
  var f = newCase('虚构示例：明早去了解岗位。我想争取收入，也担心一去就必须答应。岗位条件还没核实，醒来时又可能只想休息。');
  final evidence = f.nodes.first.id;
  MirrorNode candidate(NodeKind kind, Json body) =>
      commands.record(f, kind, body,
          evidenceIds: [evidence],
          origin: EvidenceOrigin.aiHypothesis,
          status: NodeStatus.draft);
  final understanding = candidate(NodeKind.understanding, {
    'summary': '你在争取生活机会，同时也想保留选择的余地。出门、了解条件和答应入职，可以先分别核实。',
    'facts': [
      {
        'claim': '已经考虑明早了解岗位；岗位条件尚未核实。',
        'quote': '岗位条件还没核实',
        'evidenceIds': [evidence]
      }
    ],
    'unknowns': ['到场是否带来任何承诺？', '岗位要求与你的当前条件是否相符？'],
    'keyQuestion': '能否先取得具体要求，再决定是否到场？',
    'domains': ['工作'],
    'riskFlags': <String>[],
    'timeContext': 'future',
  });
  final want = candidate(NodeKind.want, {
    'claim': '争取收入，同时保留知情选择的余地',
    'contexts': ['本次了解岗位'],
    'alternatives': ['可能主要在意避免草率承诺'],
    'falsifier': '了解条件后，发现这份机会并不重要',
    'specificity': 'tentative',
    'attractionSources': ['anticipated_outcome'],
    'immediateBenefit': '留在住处可以立即休息，暂时不用面对未知。',
    'longTermCost': '若始终没有取得信息，机会和选择仍然不清楚。',
    'nextTest': '先核实实际要求，再看自己是否仍愿意探索。',
  });
  final belief = candidate(NodeKind.belief, {
    'claim': '一去就必须答应入职',
    'kind': 'prediction',
    'realityStatus': 'hypothesized',
    'confidence': null,
    'awareness': 'known_before',
    'influence': 'unknown',
    'verify': '核实到场流程、收费和承诺条件',
  });
  f = commands.append(f, [understanding, want, belief]);
  final titles = ['先核实岗位，再决定是否出发', '条件允许时到场，只了解情况', '暂缓这次机会，寻找其他走法'];
  final steps = [
    '列出职责、时间、费用和是否绑定承诺四个问题。',
    '带着已核实的要求到场，出现新限制时暂停。',
    '确认错过这次机会的实际代价，再保留其他渠道。'
  ];
  final routes = [
    for (var i = 0; i < 3; i++)
      candidate(NodeKind.route, {
        ...route(f).body,
        'title': titles[i],
        'firstStep': steps[i],
        'description': steps[i],
        'family': ['verify', 'explore', 'defer'][i],
        'wantIds': [want.id],
        'protective': i != 1,
        'expectedBenefits': ['增加知情选择'],
        'expectedCosts': ['花费核实时间'],
      })
  ];
  f = commands.append(f, routes);
  final texts = [
    '先获得具体信息，可以保留之后选择的余地。',
    '留在住处，能立即避开出门与被评价的不适。',
    '如果到场确实绑定承诺，就应先停止并核实。',
    '核实实际任务要求，有助于换一个合适的手段。',
    '仅仅计划去，还不能知道现场会怎样选择。'
  ];
  final motives = [
    for (var i = 0; i < 5; i++)
      candidate(NodeKind.motive, {
        ...motive(f, i).body,
        'summary': texts[i],
        'wantIds': [want.id],
        'beliefIds': [belief.id],
        'directionByRoute': [
          for (var r = 0; r < routes.length; r++)
            {
              'routeId': routes[r].id,
              'relation': i == 1 || (i == 2 && r == 1) ? 'opposes' : 'supports',
              'reason': texts[i],
            }
        ],
      })
  ];
  f = commands.append(f, motives);
  final reframe = candidate(NodeKind.reframe, {
    'oldBeliefId': belief.id,
    'newClaim': '了解岗位和接受岗位可能是两步。先核实绑定条件，再保留到场、改道或拒绝的选择。',
    'operator': '目标与手段分离',
    'operatorWhy': '担心的承诺与眼前的信息核实被合在了一起。',
    'mechanism': '如果核实后仍能自由决定，出门就不必被理解为永久承诺；若确有绑定条件，这项解释就不成立。',
    'oldMayBeRight': '到场确实需要先签约或承担不可退的费用。',
    'alternatives': ['到场也可能只是流程的一部分，具体规则未知。'],
    'falsifier': '书面要求表明到场会触发不可撤回的义务。',
    'test': '先询问：到场前是否收费或签约？是否可以了解后再决定？',
    'conditions': ['取得可信回复'],
    'unknowns': ['实际到场规则'],
    'affectedMotiveIds': [motives[0].id, motives[2].id],
    'affectedRouteIds': [routes[0].id, routes[1].id],
    'theoryRefs': ['product_evidence'],
  });
  f = commands.append(f, [reframe]);
  final fits = [
    for (var i = 0; i < routes.length; i++)
      candidate(NodeKind.routeFit, {
        ...fitBody(routes[i].id),
        'wantFit': 'partial',
        'difficulty': i + 1,
        'matrix': [
          {
            'wantId': want.id,
            'horizon': 'now',
            'effect': i == 0 ? 'promotes' : 'mixed',
            'reason': i == 0 ? '先减少未知，但仍需花时间核实。' : '保留一种选择，也承担相应时间或机会成本。',
            'conditions': <String>[],
            'evidenceIds': [evidence]
          },
          {
            'wantId': want.id,
            'horizon': 'long',
            'effect': 'unknown',
            'reason': '是否带来合适、持续的生活机会，仍需实际体验。',
            'conditions': <String>[],
            'evidenceIds': [evidence]
          },
        ],
      })
  ];
  f = commands.append(f, fits);
  return commands.append(f, [MotiveRanking.build(f)]).evolve(step: 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
    if (await font.exists()) {
      for (final name in ['sans-serif', 'Roboto']) {
        await (FontLoader(name)
              ..addFont(
                  Future.value(ByteData.sublistView(await font.readAsBytes()))))
            .load();
      }
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  test(
      'accepting a reframe invalidates affected route fits and keeps other fits',
      () async {
    final store = MemoryStore();
    final f = visualCase();
    await store.save(f, expectedRevision: 0);
    final c = MirrorController(
        store: store, model: OfflineModel(), reminders: TestReminders());
    await c.initialize();
    final reframe = f.current(NodeKind.reframe).single;
    await c.acceptReframe(f.id, reframe.id);
    final revised = c.file(f.id)!;
    final affected = reframe.strings('affectedRouteIds');
    expect(revised.current(NodeKind.routeFit).length, 1);
    expect(
        revised
            .current(NodeKind.routeFit)
            .any((n) => affected.contains(n.text('routeId'))),
        isFalse);
    expect(stepHasAnalysis(revised, 3), isFalse);
    expect(revised.nodes.first.toJson(), f.nodes.first.toJson());
    expect(revised.latest(NodeKind.graphShift), isNotNull);
    expect(revised.current(NodeKind.observation), isEmpty);
    c.dispose();
  });
  testWidgets(
      'one fictional case renders understanding, conflict, recognition and route comparisons',
      (tester) async {
    final store = MemoryStore();
    final file = visualCase();
    await store.save(file, expectedRevision: 0);
    final c = MirrorController(
        store: store, model: OfflineModel(), reminders: TestReminders());
    await c.initialize();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: mirrorTheme(Brightness.light),
        home: RepaintBoundary(
            key: key, child: CaseWorkbench(controller: c, caseId: file.id))));
    await tester.pumpAndSettle();
    await preview(tester, key, 'intent-understanding');
    for (final entry in {
      1: 'intent-conflict',
      2: 'intent-recognition',
      3: 'intent-routes'
    }.entries) {
      await c.advance(file.id, entry.key);
      await tester.pumpAndSettle();
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, 1800));
      await tester.pumpAndSettle();
      await preview(tester, key, entry.value);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
