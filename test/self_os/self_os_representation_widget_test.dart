import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_case_page.dart';
import 'package:quote_app/self_os/self_os_guide_page.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_representation_learning.dart';
import 'self_os_domain_test.dart' show plannedCase;
import 'self_os_guide_widget_test.dart' show guideTap;
import 'self_os_representation_test.dart' show expressionCase;
import 'self_os_widget_test.dart' show MemoryRepository, offlineAi, reveal;

void main() {
  testWidgets('A38：手动表达可采用并保存；没有模型也能留下事前记录', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = plannedCase(), repo = MemoryRepository();
    c.fields.addAll({
      'representation.task': 'discomfort',
      'representation.window': 'evening'
    });
    final history = [
      for (var i = 0; i < 3; i++) expressionCase(context: '情境 $i')
    ];
    await tester.pumpWidget(MaterialApp(
        home: SelfOsCasePage(
            value: c,
            repository: repo,
            ai: offlineAi(),
            history: history,
            profile: SelfOsProfile(),
            initialEngine: SelfOsEngine.cognition)));
    await tester.pumpAndSettle();
    Future<void> tap(String key) async {
      final f = find.byKey(ValueKey(key));
      await reveal(tester, f, engine: 'cognition');
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await tap('representation_editor');
    await tap('representation_use_recommendation');
    final draft = find.byKey(const ValueKey('representation_draft_1'));
    await reveal(tester, draft, engine: 'cognition');
    await tester.enterText(draft, '今晚确认路线，明天了解岗位，之后再决定是否继续。');
    final source = find.byKey(const ValueKey('representation_source_1'));
    await reveal(tester, source, engine: 'cognition');
    await tester.enterText(source, '预约通知，岗位内容仍待了解');
    await tap('representation_adopt');
    await tester.tap(find.text('保存').first);
    await tester.pumpAndSettle();
    final saved = repo.records[c.id]!;
    expect(saved.text('k2'), contains('之后再决定'));
    expect(osMaps(saved.v37.settings['representationUses']).single['format'],
        'timeline');
    expect(saved.v37.flag('understandingReviewed'), isFalse);
    expect(saved.reviews, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final guided in [false, true]) {
    testWidgets('A38：${guided ? '引导' : '详细'}表达反馈失败保留草稿，重试不重复计数',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = expressionCase(feedback: false), repo = MemoryRepository();
      final id = SelfOsRepresentationLearning.uses(c.commitment!).single['id'];
      final prefix = 'representation.$id';
      await repo.saveCase(c);
      await tester.pumpWidget(MaterialApp(
          home: guided
              ? SelfOsGuidePage(
                  value: c,
                  repository: repo,
                  ai: offlineAi(),
                  history: [c],
                  profile: SelfOsProfile())
              : SelfOsCasePage(
                  value: c,
                  repository: repo,
                  ai: offlineAi(),
                  history: [c],
                  profile: SelfOsProfile(),
                  initialEngine: SelfOsEngine.mirror)));
      await tester.pumpAndSettle();
      Future<void> tap(Finder f) async {
        if (guided) {
          await guideTap(tester, f);
        } else {
          await reveal(tester, f);
          await tester.tap(f);
          await tester.pumpAndSettle();
        }
      }

      Future<void> choose(String key, String label) async {
        await tap(find.byKey(ValueKey(key)));
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      Future<void> enter(String key, String text) async {
        final f = find.byKey(ValueKey(key));
        if (guided) {
          await tester.ensureVisible(f);
        } else {
          await reveal(tester, f);
        }
        await tester.enterText(f, text);
        await tester.pumpAndSettle();
      }

      await tap(find.byKey(ValueKey('representation_feedback_$id')));
      await choose('$prefix.understanding', '有帮助');
      final save = find.byKey(const ValueKey('save_representation_feedback'));
      await tap(save);
      expect(repo.records[c.id]!.reviews.single.notes['$prefix.understanding'],
          isNull);
      await enter('$prefix.observation', '把担忧放在对应时间点后，能分清现在真正要确认的事情。');
      await choose('$prefix.attribution', '已考虑其他变化，可在相近条件下参考');
      await enter('$prefix.conditions', '睡眠和交通没有变化，仅适用于短时了解岗位。');
      repo.fail = true;
      await tap(save);
      expect(repo.records[c.id]!.reviews.single.notes['$prefix.understanding'],
          isNull);
      repo.fail = false;
      await tap(save);
      await tap(save);
      final pattern =
          SelfOsRepresentationLearning.patterns([repo.records[c.id]!]).single;
      expect(pattern.total, 1);
      expect(pattern.helped, 1);
      expect(pattern.acted, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
