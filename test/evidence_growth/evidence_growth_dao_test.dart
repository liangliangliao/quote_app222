import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/evidence_growth/evidence_growth_ai_service.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge.dart';
import 'package:quote_app/evidence_growth/evidence_growth_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late EvidenceGrowthDao dao;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = EvidenceGrowthDao(database: () async => db);
    await dao.ensureTables();
  });
  tearDown(() => db.close());

  test('prediction-result-review-decision persists without changing public KB', () async {
    final publicBefore = jsonEncode(EvidenceGrowthKnowledge.byId('TAL-A01')!.toJson());
    final route = const EvidenceGrowthRouter().route('我知道要投简历，但没开始，一直等待动力。');
    const prediction = '我预测五分钟后会留下一个行动痕迹。';
    var trial = await dao.createTrial(route, prediction: prediction, probability: .65, reviewAt: DateTime.now().add(const Duration(minutes: 10)));
    trial = await dao.startTrial(trial);
    trial = await dao.captureResult(trial, didAction: true, actualOutcome: '完成一次投递。', unexpected: '阻力小于预测。');
    final local = EvidenceGrowthAiService(dao: dao).localReview(trial);
    expect(local.predictionOriginal, prediction);
    const review = TrialReviewResult(
      predictionOriginal: prediction,
      actualFacts: ['完成一次投递。'],
      predictionError: '低估开始后的顺畅程度。',
      failureClass: 'NO_FAILURE',
      learning: '摩擦集中在第一步。',
      ruleUpdate: '等待动力改为先做五分钟。',
      decision: 'ACT',
      nextChangeOneVariable: '明天再取一个样本。',
      knowledgeNodeIds: ['TAL-A01'],
    );
    trial = await dao.saveReview(trial, review);
    trial = await dao.decide(trial, decision: 'ACT', reason: review.learning, nextAction: review.nextChangeOneVariable);
    final restored = await dao.byId(trial.id);
    expect(restored!.prediction, prediction);
    expect(restored.actualOutcome, '完成一次投递。');
    expect(restored.decision, 'ACT');
    expect((await dao.summary()).completedActions, 1);
    expect(jsonEncode(EvidenceGrowthKnowledge.byId('TAL-A01')!.toJson()), publicBefore);
    final exported = jsonDecode(await dao.exportJson()) as Map<String, dynamic>;
    expect(exported['trials'], hasLength(1));
  });

  test('privacy switch removes raw user text', () async {
    await dao.setSetting('keep_raw_input', 'false');
    final route = const EvidenceGrowthRouter().route('我拖延，还没开始。');
    final trial = await dao.createTrial(route, prediction: '我会开始。', probability: .5, reviewAt: DateTime.now().add(const Duration(minutes: 10)));
    expect(trial.rawInput, isEmpty);
    expect(trial.facts.any((e) => e.startsWith('用户原话：')), isFalse);
  });

  test('EXIT preserves learning rather than becoming identity failure', () async {
    final route = const EvidenceGrowthRouter().route('坚持两年没结果，我需要退出。');
    var trial = await dao.createTrial(route, prediction: '继续仍无反馈。', probability: .7, reviewAt: DateTime.now());
    trial = await dao.startTrial(trial);
    trial = await dao.captureResult(trial, didAction: false, actualOutcome: '成本上升，反证未变化。', unexpected: '');
    const review = TrialReviewResult(
      predictionOriginal: '继续仍无反馈。',
      actualFacts: ['成本上升，反证未变化。'],
      predictionError: '与预测一致。',
      failureClass: 'INTELLIGENT',
      learning: '当前路线不再保留下一轮资格。',
      ruleUpdate: '不把坚持本身当作成功。',
      decision: 'EXIT',
      nextChangeOneVariable: 'Hypothesis Closed。',
      knowledgeNodeIds: ['TAL-G12'],
    );
    trial = await dao.saveReview(trial, review);
    trial = await dao.decide(trial, decision: 'EXIT', reason: review.learning, nextAction: review.nextChangeOneVariable);
    expect(trial.learning, review.learning);
    expect(trial.decision, 'EXIT');
  });
}
