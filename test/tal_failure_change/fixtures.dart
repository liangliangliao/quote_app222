import 'dart:convert';
import 'dart:io';
import 'package:quote_app/failure_module/fp_dao.dart';
import 'package:quote_app/failure_module/tal/tal_failure_change.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

TalCatalog loadCatalog() => TalCatalog.fromJson(
    jsonDecode(File('assets/failure_module/tal/method_case_catalog.json')
        .readAsStringSync()) as Map<String, dynamic>,
    jsonDecode(File('assets/failure_module/tal/routing_rules.json')
        .readAsStringSync()) as Map<String, dynamic>);

class TalFixture {
  late Database db;
  late FpDao dao;
  late TalLessonLedger ledger;
  DateTime now = DateTime(2026, 11, 11, 12);
  Future<void> open() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    dao = FpDao(openDatabase: () async => db);
    ledger = TalLessonLedger(dao: dao, clock: () => now);
  }

  Future<TalRecord> planned(
      {String id = 'event:1', String subject = 'habit:preset:5'}) async {
    await ledger.captureManualEvent(
        eventId: id, subjectKey: subject, plan: '找工作', observed: '没去');
    await ledger.saveDraft(id,
        plan: '找工作',
        observed: '没去',
        reflection: {'lessons': '先了解岗位要求，可能更容易开始'},
        choice: TalChoice.continueGoal,
        reminderConsent: true);
    return ledger.recordTrial(id,
        methodId: 'personal_trial',
        action: '收藏 1 个岗位',
        trigger: '下次打开招聘页',
        check: '收藏列表与匹配要求');
  }
}
