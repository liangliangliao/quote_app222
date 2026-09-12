import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/evidence_growth/evidence_growth_ai_service.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_notification_service.dart';
import 'package:quote_app/evidence_growth/evidence_growth_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late EvidenceGrowthDao dao;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = EvidenceGrowthDao(database: () async => db);
  });
  tearDown(() => db.close());
  final scenarios = <String>[
    '我知道要投简历，但没开始，一直等待动力。', '我一直改作品，不敢发给别人看。',
    '我一上床手就自动点开短视频。', '目标明确但不知道今天下一步做什么。',
    '面试失败说明我天生不适合。', '我复盘很多但都只是感想。',
    '坚持两年没结果，不知道继续还是退出。', '我要完全像电影主角一样生活。',
    '换了很多方法还是反复，是系统结构问题。',
  ];
  for (var i = 0; i < scenarios.length; i++) {
    test('S${i+1} persists complete evidence-result-review-decision loop', () async {
      final route = const EvidenceGrowthRouter().route(scenarios[i]);
      var trial = await dao.createTrial(route, prediction: '一天内获得一条现实反馈', probability: .7,
        reviewAt: DateTime.now().add(const Duration(days: 1)), riskConfirmed: true);
      trial = await dao.startTrial(trial);
      trial = await dao.captureResult(trial, didAction: true, actualOutcome: '执行了选定动作，获得一条反馈。',
        unexpected: '结果没有完全符合预期', resultMeasurements: {'prediction_occurred': 'true'});
      final review = EvidenceGrowthAiService(dao: dao).localReview(trial);
      trial = await dao.saveReview(trial, review);
      final decision = i == 6 ? 'EXIT' : i.isEven ? 'ACT' : 'ADJUST';
      trial = await dao.decide(trial, decision: decision, reason: review.learning, nextAction: review.nextChangeOneVariable);
      final saved = (await dao.byId(trial.id))!;
      expect(saved.isClosed, isTrue);
      expect(saved.prediction, '一天内获得一条现实反馈');
      expect(saved.decision, decision);
      expect(await dao.timeline(trial.id), hasLength(5));
      expect((await dao.evidenceSnapshots(trial.id)).every((e) => e['snapshot_json'] != '{}'), isTrue);
    });
  }
  Future<RealityTrial> start() async {
    final route = const EvidenceGrowthRouter().route('拖延，没开始');
    return dao.startTrial(await dao.createTrial(route, prediction: '会获得反馈', probability: .5,
      reviewAt: DateTime.now().add(const Duration(hours: 1)), riskConfirmed: true));
  }
  test('repeated start is idempotent and stale capture cannot double count', () async {
    final trial = await start();
    await dao.startTrial(trial);
    await dao.captureResult(trial, didAction: true, actualOutcome: '完成动作', unexpected: '');
    await expectLater(dao.captureResult(trial, didAction: true, actualOutcome: '重复提交', unexpected: ''), throwsStateError);
    expect((await dao.summary()).completedActions, 1);
    final stats = await db.query('evidence_growth_personal_node_stats');
    expect(stats.single['used_count'], 1);
  });
  test('partial, not done and aborted remain distinct', () async {
    for (final status in ['PARTIAL','NOT_DONE','ABORTED']) {
      final trial = await start();
      await dao.captureResult(trial, didAction: status == 'PARTIAL', actualOutcome: '本次记录 $status', unexpected: '', resultStatus: status);
    }
    final summary = await dao.summary();
    expect(summary.completedActions, 0);
    expect(summary.partialActions, 1);
    expect(summary.notDoneActions, 1);
    expect(summary.abortedActions, 1);
  });
  test('OBSERVE keeps trial active and allows a later result', () async {
    var trial = await start();
    trial = await dao.captureResult(trial, didAction: false, actualOutcome: '尚未收到回复', unexpected: '', resultStatus: 'OBSERVING');
    final review = EvidenceGrowthAiService(dao: dao).localReview(trial);
    expect(review.decision, 'OBSERVE');
    trial = await dao.saveReview(trial, review);
    trial = await dao.decide(trial, decision: 'OBSERVE', reason: '窗口不足', nextAction: '继续等待回复');
    expect(trial.isClosed, isFalse);
    expect(await dao.activeTrials(), hasLength(1));
    trial = await dao.captureResult(trial, didAction: true, actualOutcome: '收到回复', unexpected: '', resultStatus: 'DONE');
    expect(trial.prediction, '会获得反馈');
  });
  test('SQL and service both reject rewritten predictions', () async {
    final trial = await start();
    await expectLater(db.update('evidence_growth_predictions', {'statement': '改写'}, where: 'trial_id = ?', whereArgs: [trial.id]), throwsA(isA<DatabaseException>()));
    await expectLater(db.update('evidence_growth_trials', {'prediction': '改写'}, where: 'trial_id = ?', whereArgs: [trial.id]), throwsA(isA<DatabaseException>()));
  });
  test('unconfirmed safety cannot create a trial', () async {
    final route = const EvidenceGrowthRouter().route('拖延，没开始');
    await expectLater(dao.createTrial(route, prediction: '会开始', probability: .5, reviewAt: DateTime.now()), throwsStateError);
  });
  test('reminders deduplicate time windows and stop for closed trials', () async {
    final trial = await start();
    final reminders = EvidenceGrowthNotificationService.plan(trial, trial.createdAtMs);
    expect(reminders.map((e) => e.atMs).toSet().length, reminders.length);
    expect(reminders.map((e) => e.kind), contains('missing_result'));
    expect(EvidenceGrowthNotificationService.plan(trial.copyWith(status: 'DECIDED'), trial.createdAtMs), isEmpty);
  });
}
