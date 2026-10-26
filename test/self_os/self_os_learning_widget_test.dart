import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_guidance.dart';
import 'package:quote_app/self_os/self_os_learning.dart';
import 'package:quote_app/self_os/self_os_home_page.dart';
import 'self_os_guide_widget_test.dart' show guideApp, guideTap, guideFill;
import 'self_os_widget_test.dart' show MemoryRepository, offlineAi;
import 'self_os_guide_test.dart' show experimentGuide;
import 'self_os_learning_test.dart' show observedExperiment, calibrate;

void main() {
  testWidgets('反馈校准失败保留草稿，重试后真实认识连接原问题并可继续', (tester) async {
    final c = observedExperiment();
    final repo = MemoryRepository();
    await repo.saveCase(c);
    await tester.pumpWidget(guideApp(c, repo, offlineAi()));
    await tester.pumpAndSettle();
    await guideTap(
        tester, find.byKey(const ValueKey('guide_calibration_weakened')));
    await guideFill(tester, 'guide_1_learn_conclusion', '这次没有获得授权，其他任务还不知道');
    await guideFill(tester, 'guide_1_learn_scope', '只限于周三这项小任务');
    await guideTap(tester, find.text(SelfOsLearning.influences['protect']!));
    repo.fail = true;
    await guideTap(tester, find.byKey(const ValueKey('guide_calibrate')));
    expect(repo.records[c.id]!.reviews.single.notes['calibrationId'], isNull);
    expect(find.textContaining('保存失败'), findsOneWidget);
    repo.fail = false;
    await guideTap(tester, find.byKey(const ValueKey('guide_calibrate')));
    final saved = repo.records[c.id]!;
    expect(saved.reviews.single.notes['calibrationConclusion'],
        '这次没有获得授权，其他任务还不知道');
    expect(saved.v37.causalTraces, hasLength(1));
    expect(saved.reviews.single.notes['calibrationScope'], '只限于周三这项小任务');
    expect(find.text('认识已回到原问题'), findsOneWidget);
    await guideTap(tester, find.byKey(const ValueKey('guide_next_step')));
    expect(find.byKey(const ValueKey('self_os_workbench')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未行动不展示支持或推翻结果；窄屏大字体校准不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = observedExperiment(outcome: 'notDone');
    final repo = MemoryRepository();
    await repo.saveCase(c);
    await tester.pumpWidget(guideApp(c, repo, offlineAi(), scale: 1.6));
    await tester.pumpAndSettle();
    await guideTap(
        tester, find.byKey(const ValueKey('guide_calibration_unobserved')));
    expect(find.byKey(const ValueKey('guide_calibration_supported')),
        findsNothing);
    expect(
        find.byKey(const ValueKey('guide_calibration_weakened')), findsNothing);
    await guideTap(tester, find.text(SelfOsLearning.influences['unchanged']!));
    await guideTap(tester, find.byKey(const ValueKey('guide_calibrate')));
    expect(repo.records[c.id]!.reviews.single.notes['calibrationVerdict'],
        'unobserved');
    expect(
        repo.records[c.id]!.v37.gaps.single
            .resolvedBy(repo.records[c.id]!.v37.evidence, DateTime.now()),
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页把未校准反馈作为下一步，自我认识可以回到真实案例', (tester) async {
    final c = observedExperiment();
    final repo = MemoryRepository();
    await repo.saveCase(c);
    await tester.pumpWidget(
        MaterialApp(home: SelfOsHomePage(repository: repo, ai: offlineAi())));
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('把这次发现带回原问题'), 300,
        scrollable: list);
    expect(find.text('把这次发现带回原问题'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    calibrate(c, verdict: 'uncertain', influence: 'unchanged');
    await repo.saveCase(c);
    await tester.pumpWidget(
        MaterialApp(home: SelfOsHomePage(repository: repo, ai: offlineAi())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('逐渐认识自己').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('从现实中修订过的认识'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(c.reviews.single.notes['calibrationConclusion']!),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重新打开有重要新信息的旧约定时进入重审，不能继续旧动作', (tester) async {
    final c = experimentGuide();
    SelfOsGuidance.commitExperiment(c);
    c.fields['newInformation'] = '主管不同意原来的边界';
    c.v37.settings['newInformationReviewed'] = false;
    final repo = MemoryRepository();
    await repo.saveCase(c);
    await tester.pumpWidget(guideApp(c, repo, offlineAi()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide_focus')), findsNothing);
    expect(find.text('哪一处需要重新理解？'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
