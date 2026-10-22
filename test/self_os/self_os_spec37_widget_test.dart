import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_ai_service.dart';
import 'package:quote_app/self_os/self_os_case_page.dart';
import 'package:quote_app/self_os/self_os_guide_page.dart';
import 'package:quote_app/self_os/self_os_horizon_view.dart';
import 'package:quote_app/self_os/self_os_home_page.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;
import 'self_os_guide_widget_test.dart' show guideApp, guideTap;
import 'self_os_spec37_test.dart'
    show routedCase, strengthCase, strengthProfile;
import 'self_os_v37_rules_test.dart' show decision, node, link, proof;
import 'self_os_widget_test.dart'
    show MemoryRepository, offlineAi, reveal, fill;

void main() {
  testWidgets('原文首页卡：冲突仅展示三项关键信息，力量要有跨情境实证', (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = plannedCase(),
        repo = MemoryRepository(),
        profile = strengthProfile();
    for (final m in c.motives) {
      m.optionId = 'same';
      m.importance = 80;
      m.attention = m.side == 'for' ? 'foreground' : 'background';
    }
    await repo.saveCaseAndProfile(c, profile);
    Future<void> open() async {
      await tester.pumpWidget(
          MaterialApp(home: SelfOsHomePage(repository: repo, ai: offlineAi())));
      await tester.pumpAndSettle();
    }

    await open();
    await tester.scrollUntilVisible(find.text('看清这次真实的拉扯'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('当前冲突：趋近—回避'), findsOneWidget);
    expect(find.textContaining('眼前最鲜明：稳定收入'), findsOneWidget);
    expect(find.textContaining('重要但退到背景：保住眼前舒适'), findsOneWidget);
    expect(find.textContaining('从实际行动中看见的力量'), findsNothing);
    final observations = <Map<String, dynamic>>[];
    for (var i = 0; i < 3; i++) {
      final past = plannedCase()..commit();
      past.addReview(reviewFor(past, context: '实际情境 $i'));
      observations.add({
        'reviewId': past.reviews.single.id,
        'effect': 'helped',
        'usage': 'optimal'
      });
      await repo.saveCase(past);
    }
    profile.strengths.single.data['observations'] = observations;
    await repo.saveProfile(profile);
    await tester.pumpWidget(const SizedBox());
    await open();
    await tester.scrollUntilVisible(find.textContaining('从实际行动中看见的力量'), 220,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('3 次支持 · 0 次反证'), findsOneWidget);
    expect(find.textContaining('失效条件：紧张时也会问得太多'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('原文 A17：引导分流可直接启动对应分析，候选不自动成为决定', (tester) async {
    final c = routedCase('horizon'), repo = MemoryRepository();
    await repo.saveCase(c);
    final purposes = <String>[];
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      purposes.add(purpose);
      return jsonEncode({
        'summary': '继续比较多阶状态与未来可选路径',
        'stopReason': '仅展开会影响选择的后果',
        'signals': {'longHorizon': true}
      });
    });
    await tester.pumpWidget(guideApp(c, repo, ai));
    await tester.pumpAndSettle();
    await guideTap(tester, find.byKey(const ValueKey('guide_analyse_next')));
    expect(purposes, ['self_os.v37.horizon']);
    expect(find.byKey(const ValueKey('self_os_workbench')), findsOneWidget);
    expect(repo.records[c.id]!.v37.pendingProposal, isNotNull);
    expect(repo.records[c.id]!.v37.flag('longHorizon'), isFalse);
    expect(repo.records[c.id]!.committedAt, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('原文 A17：认识引擎接续当前问题并保留待采用的建议', (tester) async {
    final c = routedCase('cognition'), repo = MemoryRepository();
    await repo.saveCase(c);
    final purposes = <String>[];
    final ai = SelfOsAiService(generate: (
        {required prompt,
        required purpose,
        required systemPrompt,
        required maxTokens}) async {
      purposes.add(purpose);
      return jsonEncode({
        'suggestions': [
          {'field': 'k2', 'value': '先区分未知事实与自己的担心', 'reason': '当前材料仍缺事实'}
        ]
      });
    });
    await tester.pumpWidget(guideApp(c, repo, ai));
    await tester.pumpAndSettle();
    await guideTap(tester, find.byKey(const ValueKey('guide_next_engine')));
    expect(purposes, ['self_os.cognition']);
    expect(
        find.byKey(const ValueKey('self_os_engine_cognition')), findsOneWidget);
    expect(repo.records[c.id]!.suggestions['cognition'], isNotEmpty);
    expect(repo.records[c.id]!.text('k2'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('原文 A05：已确认协议依据过期后，引导给出核验入口并隐藏执行入口', (tester) async {
    final c = plannedCase()..commit();
    c.v37.evidence.add(proof()
      ..data['validUntil'] =
          DateTime.now().subtract(const Duration(hours: 1)).toIso8601String());
    c.v37.gaps.add(OsGap({
      'id': 'g',
      'question': '原场地现在仍可用吗',
      'access': 'public',
      'resolutionConfirmed': true,
      'resolutionAnswer': '曾经可用',
      'resolutionScope': '只用于原来的约定',
      'evidenceIds': ['proof']
    }));
    final repo = MemoryRepository();
    await repo.saveCase(c);
    await tester.pumpWidget(guideApp(c, repo, offlineAi()));
    await tester.pumpAndSettle();
    expect(find.text('先核对变化，再行动。'), findsOneWidget);
    expect(find.byKey(const ValueKey('guide_focus')), findsNothing);
    await guideTap(tester, find.byKey(const ValueKey('guide_next_step')));
    expect(find.byKey(const ValueKey('self_os_workbench')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final guided in [false, true]) {
    testWidgets('原文 A26：${guided ? '引导' : '详细复盘'}力量反馈失败不写入，重试保留观察并只记一次',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = strengthCase(),
          profile = strengthProfile(),
          repo = MemoryRepository();
      await repo.saveCaseAndProfile(c, profile);
      await tester.pumpWidget(MaterialApp(
          home: guided
              ? SelfOsGuidePage(
                  value: c,
                  repository: repo,
                  ai: offlineAi(),
                  history: [c],
                  profile: profile)
              : SelfOsCasePage(
                  value: c,
                  repository: repo,
                  ai: offlineAi(),
                  history: [c],
                  profile: profile,
                  initialEngine: SelfOsEngine.mirror)));
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        if (guided) {
          await guideTap(tester, finder);
        } else {
          await reveal(tester, finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }
      }

      await tap(
          find.byKey(const ValueKey('strength_feedback_curiosity.cognition')));
      await tap(
          find.byKey(const ValueKey('strength.curiosity.cognition.effect')));
      await tester.tap(find.text('有帮助').last);
      await tester.pumpAndSettle();
      // A claimed effect without an actual observation cannot enter the model.
      await tap(find.byKey(const ValueKey('save_strength_feedback')));
      expect(repo.profile.strengths.single.observations, isEmpty);
      final observation = find
          .byKey(const ValueKey('strength_observation_curiosity.cognition'));
      if (guided) {
        // Scroll upward from the save button to the still-open feedback form.
        await tester.ensureVisible(observation);
      } else {
        await reveal(tester, observation);
      }
      await tester.enterText(observation, '具体提问让我发现可用时间与原来想的不同');
      repo.fail = true;
      await tap(find.byKey(const ValueKey('save_strength_feedback')));
      expect(repo.profile.strengths.single.observations, isEmpty);
      expect(
          repo.records[c.id]!.reviews.single
              .notes['strength.curiosity.cognition.effect'],
          isNull);
      repo.fail = false;
      await tap(find.byKey(const ValueKey('save_strength_feedback')));
      expect(repo.profile.strengths.single.observations, hasLength(1));
      expect(
          repo.records[c.id]!.reviews.single
              .notes['strength.curiosity.cognition.observation'],
          contains('可用时间'));
      await tap(find.byKey(const ValueKey('save_strength_feedback')));
      expect(repo.profile.strengths.single.observations, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('原文 A21：真实复盘写入失败可重试，不形成半条经历', (tester) async {
    final c = plannedCase()..commit(), repo = MemoryRepository();
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
    await fill(tester, 'review.context', '周三沟通');
    await fill(tester, 'review.result', '确认了一项授权');
    await fill(tester, 'review.learning', '这个具体任务有调整空间');
    repo.fail = true;
    final save = find.byKey(const ValueKey('self_os_save_review'));
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.records[c.id]!.reviews, isEmpty);
    expect(save, findsOneWidget);
    repo.fail = false;
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.records[c.id]!.reviews, hasLength(1));
    expect(repo.records[c.id]!.reviews.single.result, '确认了一项授权');
    expect(tester.takeException(), isNull);
  });

  testWidgets('原文 A37/A51：图中逐节点置信度与关系来源可查看', (tester) async {
    final s = decision()..evidence.add(proof());
    s.nodes.addAll([node('a1', 1, label: 'fact'), node('a2', 2)]);
    s.edges.add(link('a1', 'a2'));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SelfOsHorizonView(
                    state: s,
                    onEditNode: (_) {},
                    onExpand: (_) {},
                    onFutureRoute: (_) {})))));
    await tester.pumpAndSettle();
    expect(find.text('直接证据'), findsOneWidget);
    await tester.tap(find.text('状态 1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('关系置信度：'), 160,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('关系置信度：支持性推断'), findsOneWidget);
    expect(find.textContaining('关系来源：行动日志 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
