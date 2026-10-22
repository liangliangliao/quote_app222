import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_repository.dart';
import 'self_os_domain_test.dart' show plannedCase, reviewFor;
import 'self_os_v37_rules_test.dart' show decision, node, proof;
import 'self_os_guide_test.dart' show experimentGuide;
import 'package:quote_app/self_os/self_os_guidance.dart';
import 'package:quote_app/self_os/self_os_learning.dart';
import 'self_os_learning_test.dart' show observedExperiment, calibrate;
import 'package:quote_app/self_os/self_os_strength_learning.dart';
import 'self_os_spec37_test.dart' show strengthCase, strengthProfile;

void main() {
  late Directory dir;
  late SelfOsRepository repo;
  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('self-os-v37-');
    repo = SelfOsRepository(
        factory: databaseFactoryFfi, path: '${dir.path}/self_os_v3.db');
  });
  tearDown(() async {
    await repo.close();
    await dir.delete(recursive: true);
  });

  test('原文 A26：力量分阶段观察与复盘共同持久化，重开不改变封存协议', () async {
    final c = strengthCase(), profile = strengthProfile();
    final frozen = jsonEncode(c.commitment);
    final review = c.reviews.single;
    review.notes.addAll({
      'strength.curiosity.cognition.effect': 'helped',
      'strength.curiosity.cognition.usage': 'optimal',
      'strength.curiosity.cognition.observation': '把担忧改写成可核对的问题',
    });
    SelfOsStrengthLearning.applyFeedback(review, profile);
    await repo.saveCaseAndProfile(c, profile);
    await repo.close();
    final loadedCase = (await repo.loadCases()).single;
    final loadedProfile = await repo.loadProfile();
    expect(
        loadedCase.reviews.single.notes['strength.curiosity.cognition.effect'],
        'helped');
    expect(loadedProfile.strengths.single.observations.single['reviewId'],
        review.id);
    expect(
        osMaps(loadedProfile
                .strengths.single.observations.single['stageEffects'])
            .single['stage'],
        'cognition');
    expect(jsonEncode(loadedCase.commitment), frozen);
    SelfOsStrengthLearning.applyFeedback(
        loadedCase.reviews.single, loadedProfile);
    await repo.saveCaseAndProfile(loadedCase, loadedProfile);
    await repo.close();
    expect(
        (await repo.loadProfile()).strengths.single.observations, hasLength(1));
  });

  test('实际校准关闭重开不丢证据链，下一轮从修订结论继续', () async {
    final c = observedExperiment();
    calibrate(c, resolve: true, conflictsChecked: true);
    final frozen = jsonEncode(c.commitment);
    await repo.saveCase(c);
    await repo.close();
    final restored = (await repo.loadCases()).single;
    expect(
        SelfOsLearning.history([restored]).single['scope'], contains('不能推广'));
    expect(
        restored.v37.gaps.single
            .resolvedBy(restored.v37.evidence, DateTime.now()),
        isTrue);
    expect(restored.v37.nodes.any((n) => n.flag('calibrationNeedsReview')),
        isTrue);
    expect(jsonEncode(restored.commitment), frozen);
    restored.nextRound();
    expect(
        restored.text('k1'), c.reviews.single.notes['calibrationConclusion']);
    expect(jsonEncode(restored.reviews.single.snapshot), frozen);
    expect(restored.round, 2);
  });

  test('即使旧风险确认仍在，未审视的新信息也不能提升人生主线', () async {
    final c = plannedCase()..v37 = decision();
    c.v37.routes.first.data.addAll({
      'desire': '自主',
      'ability': '有相应工作样本',
      'cost': '投入时间',
      'reality': '可用时间已确认'
    });
    c.fields['newInformation'] = '可用时间突然改变';
    c.v37.settings['newInformationReviewed'] = false;
    await repo.saveCase(c);
    await expectLater(
        repo.transitionRoute(c, 'a', 'active', {
          'reason': '仍想尝试',
          'sacrifice': '其他安排',
          'opportunityCost': '减少其他投入',
          'accepted': true,
        }),
        throwsFormatException);
    expect((await repo.loadProfile()).activeRouteId, isEmpty);
    expect((await repo.loadCases()).single.v37.routes.first.status,
        isNot('active'));
  });

  test('引导中断后关闭重开恢复草稿，实验封存与实际反馈保持对应', () async {
    final c = experimentGuide();
    c.guide.compose = '明天的安排还有一点需要确认';
    await repo.saveCase(c);
    await repo.close();
    final resumed = (await repo.loadCases()).single;
    expect(resumed.guide.phase, 'plan');
    expect(resumed.guide.compose, '明天的安排还有一点需要确认');
    expect(resumed.guide.confirmed, isTrue);
    SelfOsGuidance.commitExperiment(resumed);
    await repo.saveCase(resumed);
    await repo.close();
    final active = (await repo.loadCases()).single;
    final frozen = jsonEncode(active.commitment);
    SelfOsGuidance.review(active,
        outcome: 'notDone',
        result: '主管一直在开会',
        learning: '需要先约时间',
        context: '例会取消');
    await repo.saveCase(active);
    await repo.close();
    final learned = (await repo.loadCases()).single;
    expect(learned.guide.phase, 'learn');
    expect(jsonEncode(learned.reviews.single.snapshot), frozen);
    expect(learned.v37.evidence.single.text('reviewId'),
        learned.reviews.single.id);
    expect((await repo.loadProfile()).activeRouteId, isEmpty);
  });

  test('V3.0 JSON 原地升级，不改历史快照、复盘 ID 或独立数据库名', () async {
    final c = plannedCase()..commit();
    c.addReview(reviewFor(c));
    final old = c.toJson()
      ..['schemaVersion'] = 1
      ..remove('v37');
    final snapshot = osMap(old['commitment'])..remove('v37');
    old['commitment'] = snapshot;
    final oldReview = osMaps(old['reviews']).single;
    oldReview['snapshot'] = snapshot;
    old['reviews'] = [oldReview];
    final db = await repo.database;
    await db.insert('cases', {
      'id': c.id,
      'updated_at': c.updatedAt.millisecondsSinceEpoch,
      'document': jsonEncode(old)
    });
    await db.insert('profile', {
      'id': 1,
      'document': jsonEncode({
        'schemaVersion': 1,
        'manual': {'values': '旧欲求'},
        'principles': [
          {'id': 'p', 'rule': '旧原则'}
        ]
      })
    });
    var loaded = (await repo.loadCases()).single;
    expect(loaded.v37.routes, isEmpty);
    expect(loaded.reviews.single.id, c.reviews.single.id);
    expect(loaded.commitment, snapshot);
    expect((await repo.loadProfile()).manual['values'], '旧欲求');
    loaded.v37.ensureCurrentRoute(loaded.problem, '');
    await repo.saveCase(loaded);
    await repo.close();
    loaded = (await repo.loadCases()).single;
    expect(loaded.v37.routes, hasLength(1));
    expect(loaded.commitment, snapshot);
    expect((await repo.loadProfile()).principles.single['id'], 'p');
  });

  test('主线跨案例原子切换，同时保存机会成本与上一条主线', () async {
    final a = plannedCase()..v37 = decision();
    final b = plannedCase()..v37 = decision();
    for (final c in [a, b]) {
      c.v37.routes.first.data.addAll({
        'desire': '稳定',
        'ability': '已有工作样本',
        'cost': '投入每周一小时',
        'reality': '已确认时间空档'
      });
      await repo.saveCase(c);
    }
    final choice = {
      'reason': '新行动证据',
      'sacrifice': '另一条路径的成长价值',
      'opportunityCost': '减少另一项投入',
      'accepted': true,
      'trigger': 'evidence'
    };
    await repo.transitionRoute(a, 'a', 'active', choice);
    await repo.transitionRoute(b, 'a', 'active', choice);
    final records = await repo.loadCases();
    expect(records.where((c) => c.routeStatus == 'active').single.id, b.id);
    expect(
        records.expand((c) => c.v37.routes).where((r) => r.status == 'active'),
        hasLength(1));
    final p = await repo.loadProfile();
    expect(p.activeCaseId, b.id);
    expect(p.tradeoffs.last['previousCaseId'], a.id);
    final blocked = records.firstWhere((c) => c.id == a.id);
    blocked.v37.settings['risk'] = 'unassessed';
    await expectLater(repo.transitionRoute(blocked, 'a', 'active', choice),
        throwsFormatException);
    expect((await repo.loadProfile()).activeCaseId, b.id);
    expect((await repo.loadProfile()).tradeoffs, hasLength(2));
    await repo.deleteCase(b.id);
    expect((await repo.loadProfile()).activeCaseId, isEmpty);
  });

  test('可逆实验许可不能升级为人生主线，失败不写入取舍记录', () async {
    final c = plannedCase()..v37 = decision();
    c.v37.gaps.add(OsGap({'question': '仍未知', 'access': 'experience'}));
    c.v37.settings['experimentPlan'] = '十分钟试验';
    await repo.saveCase(c);
    await expectLater(
        repo.transitionRoute(c, 'a', 'active', {
          'reason': '尝试',
          'sacrifice': '其他路径',
          'opportunityCost': '时间',
          'accepted': true
        }),
        throwsFormatException);
    expect((await repo.loadProfile()).tradeoffs, isEmpty);
    expect(
        (await repo.loadCases())
            .single
            .v37
            .routes
            .where((r) => r.status == 'active'),
        isEmpty);
  });

  test('新图、证据、准备、力量、认识差异与旧复盘关闭重开后完整保留', () async {
    final c = plannedCase()..v37 = decision();
    c.v37.evidence.add(proof());
    c.v37.nodes.add(node('n1', 1));
    c.v37.gaps.add(OsGap({
      'id': 'g',
      'question': '未来状态',
      'resolutionConfirmed': true,
      'resolutionAnswer': '已通过行动日志核对本次所需的状态',
      'resolutionScope': '这次可逆行动前，日志覆盖的条件',
      'evidenceIds': ['proof']
    }));
    c.beginCognition();
    c.completeCognition('证据未改变选择', noChangeReason: '原先已经考虑');
    c.v37.futureOptions.add(OsFutureOption(
        {'routeId': 'a', 'nodeId': 'n1', 'delta': 'opened', 'title': '新机会'}));
    c.v37.settings['futureMoment'] =
        DateTime.now().add(const Duration(days: 1)).toIso8601String();
    final i = OsIntervention({
      'gapId': 'g',
      'type': 'reflect',
      'window': 'now',
      'task': '对照记录',
      'source': '行动日志',
      'expectedChange': '核对信念'
    });
    c.v37.interventions.add(i);
    c.startIntervention(i);
    c.completeIntervention(i, '未发生变化');
    c.v37.settings['understandingReviewed'] = true;
    c.commit();
    c.addReview(reviewFor(c));
    final p = SelfOsProfile()
      ..strengths.add(OsStrength({
        'title': '坚持',
        'observations': [
          {'reviewId': c.reviews.single.id, 'effect': 'helped'}
        ]
      }));
    await repo.saveCaseAndProfile(c, p);
    final before = c.toJson();
    await repo.close();
    expect((await repo.loadCases()).single.toJson(), before);
    expect((await repo.loadProfile()).toJson(), p.toJson());
  });
}
