import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/prp_plugin/src/enhancement_models.dart';
import 'package:quote_app/prp_plugin/src/runtime.dart';
import 'package:quote_app/prp_plugin/src/store.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PrpFixture f;
  setUp(() async {
    f = PrpFixture();
    await f.open();
  });
  tearDown(() async {
    await f.close();
  });
  test(
      'all enhancements are opt-in, including after an older preferences upgrade',
      () {
    final p = PrpPreferences.fromJson({'enabled': true, 'voice': true});
    expect([
      p.forecasts,
      p.nativeReminders,
      p.nativeVoice,
      p.particles,
      p.draftQuotes
    ], everyElement(false));
  });
  test('forecast disabled performs no storage or AI access', () async {
    expect(await f.runtime.predict(label: '明天开会发言', intensity: 8, days: 2),
        isNull);
    expect(await f.runtime.closeForecast(1, intensity: 2, days: 1), false);
    expect(f.databaseOpens, 0);
    expect(f.host.aiCalls, 0);
  });
  test('predictions and actuals form one immutable, finite comparison',
      () async {
    await f.enable();
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(forecasts: true));
    final prediction =
        await f.runtime.predict(label: '明天开会发言', intensity: 8, days: 3);
    expect(prediction, isNotNull);
    f.clock.advance(const Duration(days: 2));
    expect(
        await f.runtime.closeForecast(prediction!.id, intensity: 2, days: .5),
        true);
    expect(await f.runtime.closeForecast(prediction.id, intensity: 9, days: 7),
        false);
    final result = (await f.runtime.forecasts()).single;
    expect(result.intensityRatio, 4);
    expect(result.durationRatio, 6);
    expect(await f.runtime.predict(label: '明天提交报告', intensity: 11, days: 1),
        isNull);
    expect(
        await f.runtime
            .predict(label: '明天提交报告', intensity: 5, days: double.nan),
        isNull);
    expect(
        await f.runtime
            .predict(label: '明天提交报告', intensity: 5, days: double.infinity),
        isNull);
  });
  test('zero actual values remain observations without infinite coefficients',
      () async {
    await f.enable();
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(forecasts: true));
    final p =
        (await f.runtime.predict(label: '给同事发一条消息', intensity: 6, days: 1))!;
    await f.runtime.closeForecast(p.id, intensity: 0, days: 0);
    final result = (await f.runtime.forecasts()).single;
    expect(result.closed, true);
    expect(result.intensityRatio, isNull);
    expect(result.durationRatio, isNull);
  });
  test('crisis prediction exits and retains no label', () async {
    await f.enable();
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(forecasts: true));
    expect(
        await f.runtime.predict(label: '我不想活了', intensity: 8, days: 3), isNull);
    expect(f.host.safetyExits, 1);
    expect(await f.runtime.exportData(), isNot(contains('不想活')));
  });
  test(
      'legacy three-table PRP upgrades additively without altering any existing table',
      () async {
    for (final sql in PrpSchema.statements.take(3)) {
      await f.db.execute(sql);
    }
    final before = await f.db.rawQuery(
        "SELECT name,sql FROM sqlite_master WHERE name IN ('prp_lesson','prp_session','prp_recall') ORDER BY name");
    await f.enable();
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(forecasts: true));
    expect(await f.runtime.predict(label: '明天开会发言', intensity: 7, days: 1),
        isNotNull);
    expect(
        await f.db.rawQuery(
            "SELECT name,sql FROM sqlite_master WHERE name IN ('prp_lesson','prp_session','prp_recall') ORDER BY name"),
        before);
    expect(await f.runtime.store.tableExists(f.db, 'prp_event'), true);
  });
  test('adoption is explicit, idempotent and never fabricates an outcome',
      () async {
    await f.enable();
    final lesson = await f.seal();
    final recall = (await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior, subjectKey: 'habit:preset:5')))
        .single;
    expect(await f.runtime.adoptRecall(recall), true);
    expect(await f.runtime.adoptRecall(recall), true);
    expect(await f.db.query('prp_event'), hasLength(1));
    final metrics = await f.runtime.observations();
    expect(metrics.adopted, 1);
    expect(metrics.clicked, 1);
    expect(metrics.verificationRate, isNull);
    expect((await f.runtime.store.lesson(lesson.id))!.repeatedCount, 0);
    expect((await f.db.query('prp_recall')).single['outcome'], 'pending');
  });
  test(
      'a second confirmed miss recalls the old lesson without inventing a result',
      () async {
    await f.enable();
    final lesson = await f.seal();
    f.clock.advance(const Duration(days: 1));
    await f.runtime.signal(f.signal(ref: 'second-explicit-miss'));
    final recall = (await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior,
            subjectKey: 'habit:preset:5',
            location: 'repeat_detected',
            reference: 'second-explicit-miss')))
        .single;
    expect(recall.lesson.id, lesson.id);
    expect(recall.similarCount, 2);
    expect(recall.lesson.repeatedCount, 0);
    expect((await f.db.query('prp_recall')).single['outcome'], 'pending');
  });
  test(
      'native reminder reservations reuse the Flutter recall and global budget',
      () async {
    await f.enable(cap: 1);
    final lesson = await f.seal();
    final ref = 'preset:5:${f.runtime.dayStartMs}';
    final id = await f.db.insert('prp_recall', {
      'lesson_id': lesson.id,
      'ts': f.runtime.nowMs,
      'surface': 'behavior',
      'subject_key': 'habit:preset:5',
      'context': 'habit_reminder',
      'ref': ref
    });
    final recalled = (await f.runtime.recallFor(PrpContext(
            surface: PrpSurface.behavior,
            subjectKey: 'habit:preset:5',
            location: 'habit_reminder',
            reference: ref)))
        .single;
    expect(recalled.id, id);
    expect(
        await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.enemy,
            text: '阅读 20 分钟',
            location: 'new_commitment')),
        isEmpty);
    expect(await f.db.query('prp_recall'), hasLength(1));
  });
  test('observation rates exclude imported drafts and unreported recalls',
      () async {
    await f.enable();
    final lesson = await f.seal();
    final offer = f.runtime.pendingOffer(PrpSurface.behavior)!;
    await f.runtime.finishZoom(offer, 3);
    await f.runtime.importReviewDrafts([
      {
        'presetId': 9,
        'presetName': '写一页报告',
        'status': 'missed',
        'missedReason': '打开短视频没有写'
      }
    ], reviewMs: 100);
    final recall = (await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior, subjectKey: 'habit:preset:5')))
        .single;
    await f.runtime.adoptRecall(recall);
    await f.runtime.reportOutcome(recall.id, PrpOutcome.helped);
    final m = await f.runtime.observations();
    expect(m.sessions, 1);
    expect(m.completionRate, 1);
    expect(m.sealRate, 1);
    expect(m.adoptionRate, 1);
    expect(m.verificationRate, 1);
    expect(m.meanRepeatDays, isNull);
    expect((await f.runtime.store.lesson(lesson.id))!.verifiedCount, 1);
  });
  test('recurrence intervals use explicit results rather than unreported time',
      () async {
    await f.enable();
    final lesson = await f.seal();
    for (final days in [1, 2, 5]) {
      f.clock.advance(Duration(days: days));
      final recall = (await f.runtime.recallFor(PrpContext(
              surface: PrpSurface.behavior,
              subjectKey: lesson.subjectKey,
              reference: 'attempt:${f.runtime.nowMs}')))
          .single;
      await f.runtime.reportOutcome(recall.id, PrpOutcome.repeated);
    }
    f.clock.advance(const Duration(days: 2));
    await f.runtime.recallFor(PrpContext(
        surface: PrpSurface.behavior, subjectKey: lesson.subjectKey));
    final observation = await f.runtime.observations();
    expect(observation.repeatGaps[lesson.id], [2.0, 5.0]);
    expect(observation.meanRepeatDays, 3.5);
    expect(observation.repeated, 3);
    expect(observation.recalls, 4);
    expect(observation.stepCounts['zoom'], 1);
    expect(observation.meanEmotionChange, isNull);
    expect(observation.completed, 0);
  });
  test('export and clear include forecasts and adoption while disabled',
      () async {
    await f.enable();
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(forecasts: true));
    await f.runtime.predict(label: '给同事发一条消息', intensity: 5, days: 1);
    await f.seal();
    final recall = (await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior, subjectKey: 'habit:preset:5')))
        .single;
    await f.runtime.adoptRecall(recall);
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(enabled: false));
    final data = jsonDecode(await f.runtime.exportData()) as Map;
    expect(data['tables']['prp_forecast'], hasLength(1));
    expect(data['tables']['prp_event'], hasLength(1));
    await f.runtime.clearData();
    expect(await f.runtime.forecasts(), isEmpty);
    expect(await f.db.query('prp_event'), isEmpty);
    expect((await f.runtime.observations()).sessions, 0);
  });
  test(
      'practice quotations are original local prompts, not sealed evidence or quote rows',
      () async {
    await f.enable();
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(draftQuotes: true));
    for (final entry in PrpDraftQuote.entries) {
      expect(f.host.guardText(entry.text).allowed, true, reason: entry.id);
    }
    final offer = await f.runtime.reviewDraftQuote(PrpDraftQuote.entries.first);
    expect(offer, isNotNull);
    expect(f.runtime.initialLessons[offer!.sessionId]!.sentences.single.kind,
        PrpSentenceKind.interpretation);
    expect(await f.runtime.store.lessons(sealedOnly: true), isEmpty);
    expect(f.host.aiCalls, 0);
  });
}
