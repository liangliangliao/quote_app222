import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_case_page.dart';
import 'package:quote_app/self_os/self_os_insights.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'self_os_domain_test.dart' show plannedCase;
import 'self_os_v37_rules_test.dart' show decision;
import 'self_os_v37_widget_test.dart' show scrollTo;
import 'self_os_widget_test.dart' show MemoryRepository, offlineAi;

Widget workbench(SelfOsCase c, MemoryRepository repo, int section) =>
    MaterialApp(
        home: SelfOsCasePage(
            value: c,
            repository: repo,
            ai: offlineAi(),
            history: [c],
            profile: repo.profile,
            initialWorkspace: section));

void bridgeSettings(SelfOsCase c) => c.v37.settings.addAll({
      'bridgeStrengthId': 's',
      'bridgeWeakness': '面对复杂任务迟迟没有开始',
      'bridgeMechanism': '把善于比较细节用于寻找最小差异',
      'bridgeAction': '用五分钟列出任务里第一个可比较的小差异',
      'bridgeGuardrail': '超过五分钟仍在比较时停止，转去核对所需事实',
    });

void main() {
  testWidgets('一般价值不代替个人适配，表单保存未知项且不会自动成为主线', (tester) async {
    final c = plannedCase()..v37 = decision();
    c.v37.routes.first.data['mechanismDetail'] = '每周一小时改变当前安排';
    final repo = MemoryRepository();
    await tester.pumpWidget(workbench(c, repo, 0));
    await tester.pumpAndSettle();
    final edit = find.byTooltip('编辑路径').first;
    await scrollTo(tester, edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    for (final e in {
      'generalValue': '95',
      'desireFit': '35',
      'realityFit': '60'
    }.entries) {
      final field = find.byKey(ValueKey('v37_edit_${e.key}'));
      await tester.ensureVisible(field);
      await tester.enterText(field, e.value);
    }
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    final route = repo.records[c.id]!.v37.routes.first;
    expect(route.number('generalValue'), 95);
    expect(route.fit['desireFit'], 35);
    expect(route.fit['realityFit'], 60);
    expect(route.fit['abilityFit'], isNull);
    expect(route.fit['costAcceptance'], isNull);
    expect(route.status, isNot('active'));
    expect(repo.profile.activeRouteId, isEmpty);
    expect(find.textContaining('2/6 已记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('力量桥接带入第一动作和停止边界，候选力量不会变成已验证提示', (tester) async {
    final c = plannedCase();
    bridgeSettings(c);
    c.v37.settings['holdCue'] = '上一动作的旧提示';
    final repo = MemoryRepository();
    repo.profile.strengths.add(
        OsStrength({'id': 's', 'title': '细节比较', 'definition': '发现可核对的具体差异'}));
    await tester.pumpWidget(workbench(c, repo, 4));
    await tester.pumpAndSettle();
    final button = find.text('把桥接动作带入行动草稿');
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final saved = repo.records[c.id]!;
    expect(saved.text('firstAction'), c.v37.text('bridgeAction'));
    expect(saved.text('reconsiderWhen'), c.v37.text('bridgeGuardrail'));
    expect(osMap(saved.v37.settings['actionBridge'])['strengthId'], 's');
    expect(saved.v37.text('holdCue'), isEmpty);
    expect(saved.commitment, isNull);
    expect(
        SelfOsInsights.strength(repo.profile.strengths.single, [saved])
            .verified,
        isFalse);
    expect(find.byKey(const ValueKey('self_os_engine_action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('已有协议下更换力量桥接只改草稿，重要新信息必须重审', () {
    final c = plannedCase()..commit();
    final frozen = jsonEncode(c.commitment);
    bridgeSettings(c);
    c.stageStrengthBridge();
    expect(jsonEncode(c.commitment), frozen);
    expect(c.v37.flag('requiresReconsideration'), isTrue);
    expect(c.v37.flag('newInformationReviewed'), isFalse);
    expect(c.commit, throwsFormatException);
    expect(
        osMap(c.v37.settings['actionBridge'])['action'], c.text('firstAction'));
  });

  for (final field in ['notApplicable', 'doesNotApply']) {
    testWidgets('调用原则保留不适用情境、重审条件和来源：$field', (tester) async {
      final c = plannedCase();
      final repo = MemoryRepository();
      repo.profile.principles.add({
        'id': 'p',
        'rule': '先核对实际投入再承诺',
        'condition': '存在可核对的实际时间安排',
        field: '紧急情境不适用',
        'exception': '有新时间约束时重审',
        'evidenceIds': ['prior-review']
      });
      await tester.pumpWidget(workbench(c, repo, 2));
      await tester.pumpAndSettle();
      final expand = find.text('调用已经认可的个人原则');
      await scrollTo(tester, expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(find.textContaining('不适用：紧急情境不适用'), findsOneWidget);
      final apply = find.text('将这条原则用于本次比较');
      await scrollTo(tester, apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(repo.records[c.id]!.v37.text('principleId'), 'p');
      expect(repo.profile.principles.single['evidenceIds'], ['prior-review']);
      expect(repo.records[c.id]!.commitment, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
