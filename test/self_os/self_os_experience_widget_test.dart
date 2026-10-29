import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_experience_page.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_principles.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;
import 'self_os_principles_test.dart' show experienceSource, principleFor;
import 'self_os_widget_test.dart' show MemoryRepository;

Future<void> showExperience(WidgetTester tester, SelfOsCase c,
    MemoryRepository repo, List<SelfOsCase> cases) async {
  repo.records[c.id] = c;
  await tester.pumpWidget(MaterialApp(
      home: SelfOsExperiencePage(
          value: c, profile: repo.profile, history: cases, repository: repo)));
  await tester.pumpAndSettle();
}

Future<void> scroll(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 300,
      scrollable: find.byType(Scrollable).first, maxScrolls: 35);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('T343 无经验仍可打开完整工作台，零原则不是错误', (tester) async {
    final c = plannedCase(), repo = MemoryRepository();
    await showExperience(tester, c, repo, [c]);
    expect(find.textContaining('尚未找到可复用且已认可'), findsOneWidget);
    await tester.tap(find.text('从真实经历提炼一条候选'));
    await tester.pumpAndSettle();
    expect(find.textContaining('可以先做一次低风险尝试'), findsOneWidget);
    expect(repo.profile.principles, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T330 候选不默认推荐，用户仍能展开审核和拒绝', (tester) async {
    final source = experienceSource(),
        c = plannedCase(),
        repo = MemoryRepository();
    final p = principleFor([source], accepted: false);
    repo.profile.principles.add(p);
    await showExperience(tester, c, repo, [source, c]);
    expect(find.text('核对条件，选入本轮'), findsNothing);
    await tester.tap(find.byKey(ValueKey('principle_${p['id']}')));
    await tester.pumpAndSettle();
    await scroll(tester, find.text('不适合我'));
    await tester.tap(find.text('不适合我'));
    await tester.pumpAndSettle();
    expect(repo.profile.principles.single['status'], 'user_rejected');
    expect(SelfOsPrinciples.applications(repo.records[c.id]!), isEmpty);
  });

  for (final fail in [false, true]) {
    testWidgets('条件与安全确认后才写T0，失败不推进状态：$fail', (tester) async {
      final source = experienceSource(),
          c = plannedCase(),
          repo = MemoryRepository();
      repo.profile.principles.add(principleFor([source]));
      repo.fail = fail;
      await showExperience(tester, c, repo, [source, c]);
      await tester.tap(find.text('核对条件，选入本轮'));
      await tester.pumpAndSettle();
      for (final key in ['contextMatches', 'safe']) {
        final field = find.byKey(ValueKey('v37_edit_$key'));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      if (fail) {
        expect(find.textContaining('保存失败'), findsOneWidget);
        expect(SelfOsPrinciples.applications(repo.records[c.id]!), isEmpty);
      } else {
        final a = SelfOsPrinciples.applications(repo.records[c.id]!).single;
        expect(a['applicationStatus'], 'unknown');
        expect(a['atT1'], isNull);
        expect(a['atT0'], isNotNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('T335 打开现场登记不自动写想起，取消不生成T1', (tester) async {
    final source = experienceSource(),
        c = plannedCase(),
        repo = MemoryRepository();
    final p = principleFor([source]);
    repo.profile.principles.add(p);
    SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true);
    await showExperience(tester, c, repo, [source, c]);
    await scroll(tester, find.text('到现场了，核对一下'));
    await tester.tap(find.text('到现场了，核对一下'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    final a = SelfOsPrinciples.applications(repo.records[c.id]!).single;
    expect(a['recallStatus'], 'unknown');
    expect(a['atT1'], isNull);
  });

  testWidgets('T337 完成了行动仍需单独反馈原则作用', (tester) async {
    final source = experienceSource(),
        c = plannedCase(),
        repo = MemoryRepository();
    final p = principleFor([source]);
    repo.profile.principles.add(p);
    SelfOsPrinciples.choose(c, p, [source, c],
        contextMatches: true, safe: true);
    c.addReview(reviewFor(c));
    await showExperience(tester, c, repo, [source, c]);
    await scroll(tester, find.text('对照真实复盘，记录采用情况'));
    await tester.tap(find.text('对照真实复盘，记录采用情况'));
    await tester.pumpAndSettle();
    expect(find.textContaining('结果好不等于原则必然有效'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    final a = SelfOsPrinciples.applications(repo.records[c.id]!).single;
    expect(a['atT2'], isNotNull);
    expect(a['applicationStatus'], 'unknown');
    expect(a['reportedEffect'], 'unknown');
    expect(a['observedOutcome'], 'done');
  });

  testWidgets('T361/T362 离线、窄屏大字体中可查看来源与拒绝，不依赖通知权限', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = experienceSource(),
        c = plannedCase(),
        repo = MemoryRepository();
    final p = principleFor([source]);
    repo.profile.principles.add(p);
    await tester.pumpWidget(MaterialApp(
        builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!),
        home: SelfOsExperiencePage(
            value: c,
            profile: repo.profile,
            history: [source, c],
            repository: repo)));
    await tester.pumpAndSettle();
    final tile = find.byKey(ValueKey('principle_${p['id']}'));
    await scroll(tester, tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final evidence = find.text('出处、反例与版本');
    await scroll(tester, evidence);
    await tester.tap(evidence);
    await tester.pumpAndSettle();
    expect(find.textContaining('出处与反例'), findsOneWidget);
    expect(find.textContaining(source.reviews.single.id), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
