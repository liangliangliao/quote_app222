import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_ai_service.dart';
import 'package:quote_app/self_os/self_os_case_page.dart';
import 'package:quote_app/self_os/self_os_discover_entry.dart';
import 'package:quote_app/self_os/self_os_home_page.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_repository.dart';
import 'self_os_domain_test.dart' show plannedCase;

class MemoryRepository extends SelfOsRepository {
  final Map<String, SelfOsCase> records = {};
  SelfOsProfile profile = SelfOsProfile();
  bool fail = false;
  @override
  Future<List<SelfOsCase>> loadCases() async =>
      records.values.map((c) => c.copy()).toList();
  @override
  Future<SelfOsProfile> loadProfile() async => profile;
  @override
  Future<void> saveCase(SelfOsCase value) async {
    if (fail) throw const FileSystemException('test write failure');
    records[value.id] = value.copy();
  }

  @override
  Future<void> saveProfile(SelfOsProfile value) async {
    profile = value;
  }

  @override
  Future<void> saveRouteDecision(
      List<SelfOsCase> values, SelfOsProfile value) async {
    for (final c in values) {
      records[c.id] = c.copy();
    }
    profile = value;
  }

  @override
  Future<void> close() async {}
}

Future<void> reveal(WidgetTester tester, Finder target,
    {String engine = 'mirror'}) async {
  final scroll = find
      .descendant(
          of: find.byKey(ValueKey('self_os_engine_$engine')),
          matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(target, 420,
      scrollable: scroll, maxScrolls: 45);
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String key, String value,
    {String engine = 'mirror'}) async {
  final finder = find.byKey(ValueKey('self_os_field_${key}_0'));
  await reveal(tester, finder, engine: engine);
  await tester.enterText(finder, value);
  await tester.pump();
}

SelfOsAiService offlineAi() => SelfOsAiService(
    generate: (
            {required prompt,
            required purpose,
            required systemPrompt,
            required maxTokens}) async =>
        throw StateError('offline test'));

void main() {
  test('发现页仅新增独立 Self OS 入口', () {
    final source = File('lib/pages/discover_page.dart').readAsStringSync();
    expect(
        source, contains("import '../self_os/self_os_discover_entry.dart';"));
    expect('const SelfOsDiscoverEntry()'.allMatches(source), hasLength(1));
  });

  testWidgets('入口可点击，小屏首页三入口和四个导航可用', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MemoryRepository();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: SelfOsDiscoverEntry(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => SelfOsHomePage(
                                repository: repo, ai: offlineAi()))))))));
    await tester.tap(find.byKey(SelfOsDiscoverEntry.entryKey));
    await tester.pumpAndSettle();
    expect(find.text('我现在面临一个选择'), findsOneWidget);
    expect(find.text('我刚刚做了一件事'), findsOneWidget);
    expect(find.text('看看我逐渐认识出的自己'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('人生路线'));
    await tester.pumpAndSettle();
    expect(find.text('人生是一条线。'), findsOneWidget);
    await tester.tap(find.text('逐渐认识自己'));
    await tester.pumpAndSettle();
    expect(find.textContaining('证据覆盖 0 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新建选择、编辑与返回均持久化，AI失败保留输入', (tester) async {
    final repo = MemoryRepository();
    await tester.pumpWidget(
        MaterialApp(home: SelfOsHomePage(repository: repo, ai: offlineAi())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我现在面临一个选择'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('dialog_problem')), '我想换一份工作');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('我想换一份工作'), findsOneWidget);
    await fill(tester, 'goal', '先了解岗位要求', engine: 'desire');
    await reveal(tester, find.text('帮助辨别阻塞原因'), engine: 'desire');
    await tester.tap(find.text('帮助辨别阻塞原因'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI 暂时不可用'), findsOneWidget);
    expect(repo.records.values.single.text('goal'), '先了解岗位要求');
    await tester.tap(find.byTooltip('保存并返回'));
    await tester.pumpAndSettle();
    expect(find.text('成为自己'), findsOneWidget);
    expect(repo.records.values.single.problem, '我想换一份工作');
  });

  testWidgets('行动复盘保存结果和新证据，重复点击不增加历史样本', (tester) async {
    final repo = MemoryRepository();
    final c = plannedCase()..commit();
    await repo.saveCase(c);
    await tester.pumpWidget(MaterialApp(
        home: SelfOsCasePage(
            value: c,
            repository: repo,
            ai: offlineAi(),
            history: [c],
            profile: SelfOsProfile(),
            initialEngine: SelfOsEngine.mirror)));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('self_os_choice_review.outcome_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('做了，完成这一步').last);
    await tester.pumpAndSettle();
    await fill(tester, 'review.context', '早上，焦虑但没有外部阻碍');
    await fill(tester, 'review.result', '准时到了现场，参加了面试');
    await fill(tester, 'review.learning', '焦虑并没有阻止我先行动');
    await reveal(tester, find.byKey(const ValueKey('self_os_save_review')));
    await tester.tap(find.byKey(const ValueKey('self_os_save_review')));
    await tester.pumpAndSettle();
    expect(repo.records[c.id]!.reviews, hasLength(1));
    expect(
        repo.records[c.id]!.reviews.single.snapshot['scores']
            ['predictedDiscomfort'],
        9);
    expect(find.byKey(const ValueKey('self_os_save_review')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('事后补录不伪造事前预测，缺少新证据不能提交', (tester) async {
    final repo = MemoryRepository();
    final c = SelfOsCase(problem: '刚刚没有去面试', retrospective: true)
      ..scores['planProbability'] = 99;
    await tester.pumpWidget(MaterialApp(
        home: SelfOsCasePage(
            value: c,
            repository: repo,
            ai: offlineAi(),
            history: [],
            profile: SelfOsProfile(),
            initialEngine: SelfOsEngine.mirror)));
    await tester.pumpAndSettle();
    expect(find.textContaining('没有已确认的事前预测'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('self_os_choice_review.outcome_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('这次没有行动').last);
    await tester.pumpAndSettle();
    await fill(tester, 'review.context', '早上');
    await fill(tester, 'review.result', '留在家中');
    await reveal(tester, find.byKey(const ValueKey('self_os_save_review')));
    await tester.tap(find.byKey(const ValueKey('self_os_save_review')));
    await tester.pumpAndSettle();
    expect(repo.records, isEmpty);
    await fill(tester, 'review.learning', '下次先提前把衣服准备好');
    await reveal(tester, find.byKey(const ValueKey('self_os_save_review')));
    await tester.tap(find.byKey(const ValueKey('self_os_save_review')));
    await tester.pumpAndSettle();
    expect(repo.records[c.id]!.reviews.single.snapshot['scores'], isEmpty);
  });

  testWidgets('存储失败不丢弃输入，可重试并恢复', (tester) async {
    final repo = MemoryRepository()..fail = true;
    final c = SelfOsCase(problem: '学习的选择');
    await tester.pumpWidget(MaterialApp(
        home: SelfOsCasePage(
            value: c,
            repository: repo,
            ai: offlineAi(),
            history: [],
            profile: SelfOsProfile())));
    await tester.pumpAndSettle();
    await fill(tester, 'goal', '试学一节课', engine: 'desire');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(repo.records, isEmpty);
    repo.fail = false;
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(repo.records[c.id]!.text('goal'), '试学一节课');
  });

  testWidgets('窄屏行动页与大字体没有布局溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = plannedCase();
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: SelfOsCasePage(
            value: c,
            repository: MemoryRepository(),
            ai: offlineAi(),
            history: [],
            profile: SelfOsProfile(),
            initialEngine: SelfOsEngine.action)));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('self_os_commit')),
        engine: 'action');
    expect(tester.takeException(), isNull);
  });
}
