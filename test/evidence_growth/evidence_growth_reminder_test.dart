import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_router.dart';
import 'package:quote_app/evidence_growth/evidence_growth_review_engine.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reminder_plan.dart';

void main() {
  late Database db;
  late EvidenceGrowthDao dao;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,options:OpenDatabaseOptions(singleInstance:false));
    dao = EvidenceGrowthDao(database:() async => db);
  });
  tearDown(() => db.close());
  Future<RealityTrial> create({String text='拖延，没开始',bool remind=true}) async {
    final now=DateTime.now();
    return dao.createTrial(const EvidenceGrowthRouter().route(text),prediction:'会留下现实痕迹',probability:.6,
      reviewAt:now.add(const Duration(hours:4)),riskConfirmed:true,
      operatorInputs:{'remind':'$remind','scheduled_start_ms':'${now.add(const Duration(hours:1)).millisecondsSinceEpoch}'});
  }
  Future<List<Map<String,Object?>>> pending(String id) async => (await dao.reminderRecords(trialId:id))
    .where((r)=>r['state']=='pending').toList();
  Future<RealityTrial> close(RealityTrial t,String decision) async {
    t=await dao.captureResult(t,didAction:false,actualOutcome:'这一轮没有开始，环境条件不适合。',unexpected:'',resultStatus:'NOT_DONE');
    t=await dao.saveReview(t,const EvidenceGrowthReviewEngine().review(t));
    return dao.decide(t,decision:decision,reason:'根据本轮事实调整路线',nextAction:'换一个可执行环境');
  }
  test('creation commits five-trigger outbox inputs and source provenance',() async {
    final t=await create();
    final rows=await pending(t.id);
    expect(rows.map((r)=>r['kind']),containsAll(['trial_start','trial_review_due','missing_result']));
    expect(rows.map((r)=>r['window_key']).toSet(),hasLength(rows.length));
    for(final p in EvidenceGrowthReminderPlan.build(t,t.createdAtMs)) {
      expect(p.sourceIds.every((id)=>EvidenceGrowthKnowledge.byId(id)!=null),isTrue);
    }
    expect(await pending((await create(remind:false)).id),isEmpty);
  });
  test('start removes start alarm and recovery end uses the chosen window exactly once',() async {
    final ready=await create(text:'我特别累，三天没睡好');
    final started=await dao.startTrial(ready);
    final rows=await pending(started.id);
    expect(rows.any((r)=>r['kind']=='trial_start'),isFalse);
    expect(rows.where((r)=>r['scheduled_at_ms']==started.reviewAtMs).single['kind'],'recovery_end');
  });
  test('unstarted trial records nonaction without fabricating a start and cancels due alarms',() async {
    var t=await create();
    await expectLater(dao.captureResult(t,didAction:true,actualOutcome:'伪完成',unexpected:''),throwsStateError);
    t=await dao.captureResult(t,didAction:false,actualOutcome:'没有开始',unexpected:'',resultStatus:'NOT_DONE');
    expect(t.startedAtMs,0); expect(await pending(t.id),isEmpty);
    final targetDb=await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,options:OpenDatabaseOptions(singleInstance:false));
    try {
      final other=EvidenceGrowthDao(database:()async=>targetDb);
      await other.importTrialBundle(await dao.trialBundle(t.id),baseDigest:'');
      expect((await other.byId(t.id))!.startedAtMs,0);
    } finally { await targetDb.close(); }
  });
  test('OBSERVE creates a fresh window and never reactivates the delivered one',() async {
    var t=await dao.startTrial(await create());
    final due=(await pending(t.id)).firstWhere((r)=>r['kind']=='trial_review_due');
    await db.update('evidence_growth_reminders',{'state':'delivered','delivered_at_ms':1},where:'reminder_id = ?',whereArgs:[due['reminder_id']]);
    t=await dao.captureResult(t,didAction:false,actualOutcome:'等待外部反馈',unexpected:'',resultStatus:'OBSERVING');
    t=await dao.saveReview(t,const EvidenceGrowthReviewEngine().review(t));
    final next=DateTime.now().add(const Duration(days:2));
    t=await dao.decide(t,decision:'OBSERVE',reason:'结果尚未出现',nextAction:'等待回复',nextReviewAt:next);
    expect((await pending(t.id)).firstWhere((r)=>r['kind']=='trial_review_due')['scheduled_at_ms'],next.millisecondsSinceEpoch);
    expect((await dao.reminderRecords(trialId:t.id)).firstWhere((r)=>r['reminder_id']==due['reminder_id'])['state'],'delivered');
  });
  test('third EXIT on the same primary node triggers once; ADJUST breaks the sequence',() async {
    final a=await close(await create(),'EXIT');
    final b=await close(await create(),'EXIT');
    expect(await pending(a.id),isEmpty); expect(await pending(b.id),isEmpty);
    final c=await close(await create(),'EXIT');
    expect((await pending(c.id)).single['kind'],'repeated_avoidance');
    await dao.configureReminders(enabled:true);
    expect(await pending(c.id),hasLength(1));
    await close(await create(),'ADJUST');
    expect(await dao.repeatedAvoidance(c),isFalse);
    final d=await close(await create(),'EXIT');
    expect(await pending(d.id),isEmpty);
  });
  test('permissions can be retried without duplicate IDs and per-trial opt out persists',() async {
    final t=await create();
    final initial=await pending(t.id);
    await dao.configureReminders(enabled:false);
    expect(await pending(t.id),isEmpty);
    await dao.configureReminders(enabled:true);
    expect((await pending(t.id)).map((r)=>r['reminder_id']).toSet(),initial.map((r)=>r['reminder_id']).toSet());
    await dao.configureReminders(trialId:t.id,trialEnabled:false);
    await dao.startTrial(t);
    expect(await pending(t.id),isEmpty);
  });
  test('missing result delay changes alarms without rewriting the original prediction window',() async {
    final t=await create();
    await dao.configureReminders(missingHours:48);
    expect((await pending(t.id)).singleWhere((r)=>r['kind']=='missing_result')['scheduled_at_ms'],t.reviewAtMs+48*3600000);
    expect((await dao.byId(t.id))!.reviewAtMs,t.reviewAtMs);
    await dao.deletePersonalEvidence();
    expect(await dao.reminderRecords(),isEmpty);
  });
  test('one-hour missing reminder follows the selected fourteen-day window, not app opening',() async {
    final start = DateTime(2026, 9, 11, 18, 58);
    final due = start.add(const Duration(days:14));
    final t = await dao.createTrial(const EvidenceGrowthRouter().route('拖延，没开始'),
      prediction:'会留下现实痕迹',probability:.6,reviewAt:due,riskConfirmed:true,
      operatorInputs:{'remind':'true','scheduled_start_ms':'${start.millisecondsSinceEpoch}'});
    await dao.configureReminders(missingHours:1);
    final rows = await pending(t.id);
    expect(rows.singleWhere((r)=>r['kind']=='missing_result')['scheduled_at_ms'],
      DateTime(2026,9,25,19,58).millisecondsSinceEpoch);
    expect(rows.singleWhere((r)=>r['kind']=='trial_review_due')['scheduled_at_ms'],due.millisecondsSinceEpoch);
    final missing = rows.singleWhere((r)=>r['kind']=='missing_result');
    await db.update('evidence_growth_reminders',{'state':'delivered','delivered_at_ms':1},
      where:'reminder_id = ?',whereArgs:[missing['reminder_id']]);
    await dao.configureReminders(enabled:true);
    expect((await pending(t.id)).singleWhere((r)=>r['kind']=='missing_result')['scheduled_at_ms'],
      DateTime(2026,9,26,19,58).millisecondsSinceEpoch);
  });
  test('repeats survive refresh, interval changes, toggle and feedback cancellation',() async {
    var t = await create();
    await dao.configureReminders(missingHours:1,repeatHours:1);
    var row = (await pending(t.id)).singleWhere((r)=>r['kind']=='missing_result');
    final first = row['scheduled_at_ms'] as int;
    await db.update('evidence_growth_reminders',{'state':'delivered','delivered_at_ms':first+1000},where:'reminder_id = ?',whereArgs:[row['reminder_id']]);
    await dao.configureReminders(enabled:true);
    row = (await pending(t.id)).singleWhere((r)=>r['kind']=='missing_result');
    expect(row['scheduled_at_ms'],first+3600000);
    final nextId = row['reminder_id'];
    await dao.configureReminders(enabled:true);
    expect((await pending(t.id)).singleWhere((r)=>r['kind']=='missing_result')['reminder_id'],nextId);
    await dao.configureReminders(repeatHours:6);
    expect((await pending(t.id)).singleWhere((r)=>r['kind']=='missing_result')['scheduled_at_ms'],first+6*3600000);
    await dao.configureReminders(trialId:t.id,trialEnabled:false);
    expect(await pending(t.id),isEmpty);
    await dao.configureReminders(trialId:t.id,trialEnabled:true);
    expect((await pending(t.id)).where((r)=>r['kind']=='missing_result'),hasLength(1));
    t = await dao.captureResult(t,didAction:false,actualOutcome:'这一轮没有做',unexpected:'',resultStatus:'NOT_DONE');
    await dao.configureReminders(enabled:true);
    expect(await pending(t.id),isEmpty);
  });
  test('late delivery skips missed slots and old window history does not affect OBSERVE',() {
    expect(EvidenceGrowthReminderPlan.nextMissingAt(1000,3600000,1000+4*3600000+500),1000+5*3600000);
    expect(EvidenceGrowthReminderPlan.nextMissingAt(10000000,3600000,500),10000000);
  });
  test('upgrade recovers the chain after an old single reminder was delivered',() async {
    final t = await create();
    await dao.configureReminders(missingHours:1);
    final row = (await pending(t.id)).singleWhere((r)=>r['kind']=='missing_result');
    final at = row['scheduled_at_ms'] as int;
    await db.update('evidence_growth_reminders',{'state':'delivered','delivered_at_ms':at},where:'reminder_id = ?',whereArgs:[row['reminder_id']]);
    await dao.setSetting('reminder_schema','1');
    await db.delete('evidence_growth_settings',where:'setting_key = ?',whereArgs:['missing_repeat_hours']);
    final upgraded = EvidenceGrowthDao(database:()async=>db);
    await upgraded.ensureTables();
    expect(await upgraded.getSetting('missing_repeat_hours'),'1');
    final next = (await upgraded.reminderRecords(trialId:t.id)).where((r)=>r['kind']=='missing_result' && r['state']=='pending');
    expect(next.single['scheduled_at_ms'],at+3600000);
  });
  test('new OBSERVE window restarts missing feedback timing and cancels old continuation',() async {
    var t = await dao.startTrial(await create());
    await dao.configureReminders(missingHours:1,repeatHours:1);
    final row = (await pending(t.id)).singleWhere((r)=>r['kind']=='missing_result');
    await db.update('evidence_growth_reminders',{'state':'delivered','delivered_at_ms':row['scheduled_at_ms']},where:'reminder_id = ?',whereArgs:[row['reminder_id']]);
    await dao.configureReminders(enabled:true);
    final oldNext = (await pending(t.id)).singleWhere((r)=>r['kind']=='missing_result')['reminder_id'];
    t = await dao.captureResult(t,didAction:false,actualOutcome:'等待反馈',unexpected:'',resultStatus:'OBSERVING');
    t = await dao.saveReview(t,const EvidenceGrowthReviewEngine().review(t));
    final nextDue = DateTime.now().add(const Duration(days:2));
    t = await dao.decide(t,decision:'OBSERVE',reason:'尚未到反馈时间',nextAction:'继续观察',nextReviewAt:nextDue);
    expect((await pending(t.id)).singleWhere((r)=>r['kind']=='missing_result')['scheduled_at_ms'],nextDue.millisecondsSinceEpoch+3600000);
    expect((await dao.reminderRecords(trialId:t.id)).singleWhere((r)=>r['reminder_id']==oldNext)['state'],'cancelled');
  });
  test('postponing a start moves its alarm while preserving the original observation window',() async {
    final t=await create();
    final moved=DateTime.now().add(const Duration(hours:2));
    final changed=await dao.rescheduleStart(t,moved);
    final rows=await pending(t.id);
    expect(rows.singleWhere((r)=>r['kind']=='trial_start')['scheduled_at_ms'],moved.millisecondsSinceEpoch);
    expect(changed.reviewAtMs,t.reviewAtMs); expect(changed.prediction,t.prediction);
    await expectLater(dao.rescheduleStart(changed,DateTime.fromMillisecondsSinceEpoch(t.reviewAtMs+1)),throwsArgumentError);
  });
}
