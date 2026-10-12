import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/meditation_module/meditation_ai_service.dart';
import 'package:quote_app/meditation_module/meditation_home_page.dart';
import 'package:quote_app/meditation_module/meditation_models.dart';

import 'experiential_mentor_test.dart' show FakeAi, FakeDao, FakeSettings;
import 'duration_fixtures.dart';
import 'response_recovery_test.dart' show cognitiveChangeScript;

class PageDao extends FakeDao {
  final List<MeditationSessionTemplate> savedSessions = [];

  @override
  Future<int> upsertCustomSession(MeditationSessionTemplate session) async {
    savedSessions.add(session);
    return 1;
  }

  @override
  Future<MeditationStats> loadStats() async => const MeditationStats(
      totalSeconds: 0,
      todaySeconds: 0,
      weekCompletedCount: 0,
      streakDays: 0,
      totalCompletedCount: 0);

  @override
  Future<List<MeditationRecord>> recentRecords({int limit = 20}) async => [];
}

class PageService extends MeditationAiService {
  final Completer<String> reason = Completer<String>();

  PageService(FakeAi ai, PageDao dao)
      : super(ai: ai, settings: FakeSettings(), dao: dao);

  @override
  Future<String> generateRecommendationReason(
          {required String currentState,
          required MeditationSessionTemplate recommended}) =>
      reason.future;
}

Future<void> submit(
    WidgetTester tester, PageService service, PageDao dao) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
      MaterialApp(home: MeditationModulePage(dao: dao, aiService: service)));
  await tester.pumpAndSettle();
  final input = find.byType(TextField);
  await tester.scrollUntilVisible(input, 300,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.enterText(input, '认知转变');
  final button = find.text('生成我的专家引导');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('完整 AI 正文展示为可开始的引导，附加说明慢或失败都不会吞掉结果', (tester) async {
    final dao = PageDao();
    final service =
        PageService(FakeAi([jsonEncode(cognitiveChangeScript())]), dao);
    await submit(tester, service, dao);
    expect(find.text('让念头与行动之间多一点空间'), findsOneWidget);
    expect(find.text('本次体验邀请'), findsOneWidget);
    expect(find.text('开始专家引导'), findsOneWidget);
    final regenerate = find.ancestor(
        of: find.text('重生成'), matching: find.byType(OutlinedButton));
    expect(tester.widget<OutlinedButton>(regenerate).onPressed, isNotNull);
    expect(find.textContaining('AI 暂时未生成可用内容'), findsNothing);
    expect(find.textContaining('AI 已返回引导，但还需要调整'), findsNothing);
    service.reason
        .completeError(StateError('optional explanation unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('开始专家引导'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('确实未通过内容校验时页面说明 AI 已返回与具体原因', (tester) async {
    final script = cognitiveChangeScript()..remove('experience_design');
    final raw = jsonEncode(script);
    final dao = PageDao();
    final service = PageService(FakeAi([raw, raw]), dao);
    await submit(tester, service, dao);
    expect(find.textContaining('AI 已返回引导，但还需要调整'), findsOneWidget);
    expect(find.textContaining('缺少把主题转成感官、身体和情绪体验'), findsOneWidget);
    expect(find.textContaining('可能是配置或网络异常'), findsNothing);
    expect(find.text('开始专家引导'), findsNothing);
    expect(find.text('生成我的专家引导'), findsOneWidget);
    expect(dao.outputs.single['raw'], raw);
    expect(tester.takeException(), isNull);
  });

  testWidgets('569 秒有效引导显示目标和预计时长，用户能选择完整版本或重新生成八分钟版', (tester) async {
    final dao = PageDao();
    final ai = FakeAi([
      jsonEncode(timedCognitiveChangeScript(569)),
      jsonEncode(cognitiveChangeScript())
    ]);
    final service = PageService(ai, dao);
    await submit(tester, service, dao);
    expect(find.textContaining('目标8分钟 · 预计9分29秒'), findsOneWidget);
    expect(find.text('开始完整引导（9分29秒）'), findsOneWidget);
    expect(find.text('重新生成8分钟版'), findsOneWidget);
    expect(find.textContaining('AI 已返回引导，但还需要调整'), findsNothing);
    final start = find.ancestor(
        of: find.text('开始完整引导（9分29秒）'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton));
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('重新生成8分钟版'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新生成8分钟版'));
    await tester.pumpAndSettle();
    expect(ai.calls, hasLength(2));
    expect(ai.calls.last['prompt'], contains('"duration_minutes": 8'));
    expect(find.text('开始专家引导'), findsOneWidget);
    expect(find.textContaining('预计8分钟'), findsOneWidget);
    expect(find.textContaining('9分29秒'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('完整版本保存真实时间轴与预计时长，不把九分钟内容保存成八分钟', (tester) async {
    final dao = PageDao();
    final service =
        PageService(FakeAi([jsonEncode(timedCognitiveChangeScript(569))]), dao);
    await submit(tester, service, dao);
    final save = find.text('保存到本地，供以后重复使用');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final saved = dao.savedSessions.single;
    expect(saved.durationSeconds, 569);
    expect(saved.description, contains('目标8分钟，完整引导预计9分29秒'));
    expect(saved.steps.last.intent, contains('closing'));
    expect(find.text('已保存，可在练习库重复使用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
