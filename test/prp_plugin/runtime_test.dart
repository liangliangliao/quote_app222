import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/prp_plugin/src/validator.dart';
import 'package:quote_app/prp_plugin/src/runtime.dart';

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

  test('Noop is side-effect free and all slots collapse', () async {
    const noop = NoopPrpPlugin();
    final s = f.signal();
    expect(await noop.signal(s), isNull);
    expect(await noop.recallFor(const PrpContext(surface: PrpSurface.behavior)),
        isEmpty);
    expect(await noop.workedItems(), isEmpty);
    expect(await noop.quotesForStream(), isEmpty);
    expect(noop.playbook(), isA<SizedBox>());
    expect(
        noop.sessionCard(PrpOffer(sessionId: 1, signal: s)), isA<SizedBox>());
  });

  for (final surface in PrpSurface.values) {
    for (final master in [false, true]) {
      for (final sourceEnabled in [false, true]) {
        test(
            '${surface.key}: master=$master surface=$sourceEnabled controls every entry',
            () async {
          await f.runtime.updatePreferences(f.runtime.preferences
              .copyWith(enabled: master, surfaces: {
            for (final s in PrpSurface.values) s: s == surface && sourceEnabled
          }));
          final before = f.databaseOpens;
          final s = f.signal(
              surface: surface,
              kind: surface == PrpSurface.enemy
                  ? 'commitment_missed'
                  : surface == PrpSurface.failureModule
                      ? 'manual'
                      : 'habit_missed');
          final offer = await f.runtime.signal(s);
          final validSource =
              ![PrpSurface.kindling, PrpSurface.quoteHome].contains(surface);
          expect(offer != null, master && sourceEnabled && validSource);
          if (!master || !sourceEnabled) {
            expect(
                await f.runtime.recallFor(
                    PrpContext(surface: surface, subjectKey: 'habit:preset:5')),
                isEmpty);
            expect(f.runtime.recallChip(PrpContext(surface: surface)),
                isA<SizedBox>());
            await f.runtime.importReviewDrafts([
              {'status': 'missed', 'presetId': 5, 'missedReason': '打开短视频'}
            ], reviewMs: 1);
            expect(f.databaseOpens, before);
            expect(
                await f.db.rawQuery(
                    "SELECT name FROM sqlite_master WHERE name LIKE 'prp_%'"),
                isEmpty);
          }
        });
      }
    }
  }

  test('off methods never open storage or call AI, even with old offer IDs',
      () async {
    final offer = PrpOffer(sessionId: 100, signal: f.signal());
    await f.runtime
        .saveDraft(offer, f.lesson(), step: PrpStep.columns, pauseSeconds: 0);
    await f.runtime
        .seal(offer, f.lesson(), pauseSeconds: 60, heldMilliseconds: 3000);
    await f.runtime.reportOutcome(1, PrpOutcome.repeated);
    await f.runtime.reportSubjectOutcome(
        const PrpContext(
            surface: PrpSurface.behavior, subjectKey: 'habit:preset:5'),
        PrpOutcome.helped);
    expect(await f.runtime.quotesForStream(), isEmpty);
    expect(await f.runtime.evidenceRows(0), isEmpty);
    expect(await f.runtime.workedItems(), isEmpty);
    expect(f.databaseOpens, 0);
    expect(f.host.aiCalls, 0);
  });

  test('master off/on and process restart retain sealed lessons and settings',
      () async {
    await f.enable();
    final lesson = await f.seal();
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(enabled: false));
    final snapshot = await f.db.query('prp_lesson');
    expect(snapshot.single['id'], lesson.id);
    expect(f.runtime.playbook(), isA<SizedBox>());
    final restarted = f.newRuntime();
    await restarted.initialize();
    expect(restarted.enabled, false);
    await restarted
        .updatePreferences(restarted.preferences.copyWith(enabled: true));
    expect((await restarted.store.lessons()).single.id, lesson.id);
    expect(restarted.preferences.pauseSeconds, 30);
  });

  test('daily offer budget is atomic under concurrent distinct signals',
      () async {
    await f.enable(cap: 1);
    final offers = await Future.wait(List.generate(
        8, (i) => f.runtime.signal(f.signal(ref: 'different:$i'))));
    expect(offers.whereType<PrpOffer>(), hasLength(1));
    expect(await f.db.query('prp_session'), hasLength(1));
  });

  test('same event is idempotent and can reopen its unfinished offer',
      () async {
    await f.enable(cap: 1);
    final offers = await Future.wait(
        List.generate(5, (_) => f.runtime.signal(f.signal(ref: 'same'))));
    expect(offers.map((o) => o!.sessionId).toSet(), hasLength(1));
    expect(await f.db.query('prp_session'), hasLength(1));
  });

  test('missing data, skipped and kindling aborted never become misses',
      () async {
    await f.enable();
    expect(await f.runtime.signal(f.signal(confirmed: false)), isNull);
    expect(await f.runtime.signal(f.signal(kind: 'skipped')), isNull);
    expect(
        await f.runtime
            .signal(f.signal(surface: PrpSurface.kindling, kind: 'aborted')),
        isNull);
    expect(f.databaseOpens, 0);
  });

  test('quiet and mute suppress offers and recalls without consuming budgets',
      () async {
    await f.enable();
    f.host.quiet = true;
    expect(await f.runtime.signal(f.signal()), isNull);
    expect(f.databaseOpens, 0);
    f.host.quiet = false;
    final lesson = await f.seal();
    f.host.muted = true;
    expect(
        await f.runtime.recallFor(PrpContext(
            surface: PrpSurface.behavior, subjectKey: lesson.subjectKey)),
        isEmpty);
    expect(await f.db.query('prp_recall'), isEmpty);
  });

  test('three consecutive internal errors trip only this process circuit',
      () async {
    await f.enable();
    f.host.fail = true;
    for (var i = 0; i < 3; i++) {
      expect(await f.runtime.signal(f.signal(ref: '$i')), isNull);
    }
    expect(f.runtime.circuitOpen, true);
    expect(f.runtime.enabled, false);
    f.host.fail = false;
    expect(await f.runtime.signal(f.signal()), isNull);
    final restarted = f.newRuntime();
    await restarted.initialize();
    expect(restarted.enabled, true);
    expect(await restarted.signal(f.signal()), isNotNull);
  });

  test('disable cancels an in-flight offer before it can create a schema',
      () async {
    await f.enable();
    f.host.governancePending = Completer<void>();
    final offered = f.runtime.signal(f.signal());
    await Future<void>.delayed(Duration.zero);
    final disabled = f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(enabled: false));
    f.host.governancePending!.complete();
    expect(await offered, isNull);
    await disabled;
    expect(
        await f.db
            .rawQuery("SELECT name FROM sqlite_master WHERE name LIKE 'prp_%'"),
        isEmpty);
  });

  test(
      'partial pause, short hold, and skipped drafts cannot be sealed or recalled',
      () async {
    await f.enable();
    final offer = (await f.runtime.signal(f.signal()))!;
    expect(f.runtime.hasActiveSession, false);
    f.runtime.sessionShown(offer);
    expect(f.runtime.hasActiveSession, true);
    expect(
        await f.runtime
            .seal(offer, f.lesson(), pauseSeconds: 29, heldMilliseconds: 3000),
        isNull);
    expect(
        await f.runtime
            .seal(offer, f.lesson(), pauseSeconds: 30, heldMilliseconds: 2999),
        isNull);
    final draft = await f.runtime.saveDraft(offer, f.lesson(),
        step: PrpStep.columns, pauseSeconds: 12, skipped: true);
    expect(draft!.state, 'draft');
    expect(f.runtime.hasActiveSession, false);
    expect(
        await f.runtime
            .seal(offer, draft, pauseSeconds: 60, heldMilliseconds: 3000),
        isNull);
    expect(
        await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior, subjectKey: 'habit:preset:5')),
        isEmpty);
    expect(f.host.sealed, isEmpty);
  });

  test(
      'guard rejects banned words, identity judgments, vague and untestable actions',
      () async {
    final validator = LessonValidator(f.host);
    expect(validator.validate(f.lesson()).quality, 5);
    for (final action in ['下次努力', '我就是失败的人', '你是个废物', '你他妈的是', '打开书' * 15]) {
      expect(validator.validate(f.lesson(action: action)).valid, false,
          reason: action);
    }
    await f.enable();
    final offer = (await f.runtime.signal(f.signal()))!;
    expect(
        await f.runtime.saveDraft(offer, f.lesson(action: '我是一个没用的人'),
            step: PrpStep.seal, pauseSeconds: 30),
        isNull);
    expect(await f.db.query('prp_lesson'), isEmpty);
  });

  test(
      'crisis exits without retaining text, drafts or recall eligibility; survives restart',
      () async {
    await f.enable();
    final offer = (await f.runtime.signal(f.signal()))!;
    await f.runtime
        .saveDraft(offer, f.lesson(), step: PrpStep.columns, pauseSeconds: 30);
    expect(
        await f.runtime.saveDraft(offer, f.lesson(action: '我不想活了'),
            step: PrpStep.signal, pauseSeconds: 30),
        isNull);
    expect((await f.db.query('prp_session')).single['outcome'], 'crisis_exit');
    expect(await f.db.query('prp_lesson'), isEmpty);
    expect(f.runtime.enabled, false);
    final exported = await f.runtime.exportData();
    expect(f.host.safetyExits, 1);
    expect(exported, isNot(contains('不想活')));
    final restarted = f.newRuntime();
    await restarted.initialize();
    expect(restarted.enabled, false);
  });

  test(
      'same subject recall reuses pending exposure and outcome increments once',
      () async {
    await f.enable();
    final lesson = await f.seal();
    final context =
        PrpContext(surface: PrpSurface.behavior, subjectKey: lesson.subjectKey);
    final first = (await f.runtime.recallFor(context)).single;
    expect((await f.runtime.recallFor(context)).single.id, first.id);
    await Future.wait(List.generate(
        6, (_) => f.runtime.reportOutcome(first.id, PrpOutcome.helped)));
    expect((await f.runtime.store.lesson(lesson.id))!.verifiedCount, 1);
    expect((await f.runtime.store.lesson(lesson.id))!.repeatedCount, 0);
    expect(await f.db.query('prp_recall'), hasLength(1));
  });

  test('empty contexts and unrelated text do not get an arbitrary lesson',
      () async {
    await f.enable();
    await f.seal();
    expect(
        await f.runtime.recallFor(const PrpContext(surface: PrpSurface.enemy)),
        isEmpty);
    expect(
        await f.runtime.recallFor(
            const PrpContext(surface: PrpSurface.enemy, text: '今天和朋友在公园散步')),
        isEmpty);
    expect(
        await f.runtime.recallFor(
            const PrpContext(surface: PrpSurface.enemy, text: '准备阅读时打开短视频')),
        hasLength(1));
  });

  test('daily recall cap persists across restarts and pending means unverified',
      () async {
    await f.enable(cap: 1);
    final lesson = await f.seal();
    final recall = (await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior,
            subjectKey: 'habit:preset:5',
            reference: 'one')))
        .single;
    await f.runtime.reportOutcome(recall.id, PrpOutcome.pending);
    final restarted = f.newRuntime();
    await restarted.initialize();
    expect(
        await restarted.recallFor(const PrpContext(
            surface: PrpSurface.enemy, category: '拖延', reference: 'two')),
        isEmpty);
    final stored = (await restarted.store.lesson(lesson.id))!;
    expect(stored.verifiedCount + stored.repeatedCount, 0);
    expect((await f.db.query('prp_recall')).single['outcome'], 'pending');
  });

  test('backdated outcome cannot validate a later recall', () async {
    await f.enable();
    final lesson = await f.seal();
    await f.runtime.recallFor(PrpContext(
        surface: PrpSurface.behavior, subjectKey: lesson.subjectKey));
    await f.runtime.reportSubjectOutcome(
        PrpContext(
            surface: PrpSurface.behavior,
            subjectKey: lesson.subjectKey,
            occurredMs: f.clock.now
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch),
        PrpOutcome.repeated);
    expect((await f.runtime.store.lesson(lesson.id))!.repeatedCount, 0);
    await f.runtime.reportSubjectOutcome(
        PrpContext(surface: PrpSurface.behavior, subjectKey: lesson.subjectKey),
        PrpOutcome.repeated);
    expect((await f.runtime.store.lesson(lesson.id))!.repeatedCount, 1);
  });

  test('rewriting retires parent only when the new version is actually sealed',
      () async {
    await f.enable();
    final original = await f.seal();
    final offer = (await f.runtime.resumeLesson(original, rewrite: true))!;
    expect((await f.runtime.store.lesson(original.id))!.state, 'sealed');
    final updated = await f.runtime.seal(
        offer, f.lesson(parentId: original.id, action: '关掉手机读 2 页'),
        pauseSeconds: 30, heldMilliseconds: 3000);
    expect(updated!.parentId, original.id);
    expect((await f.runtime.store.lesson(original.id))!.state, 'retired');
    final recall = (await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior, subjectKey: 'habit:preset:5')))
        .single;
    expect(recall.lesson.id, updated.id);
  });

  test(
      'own quotes require stream, surface and per-lesson consent plus a 24-hour gap',
      () async {
    await f.enable();
    final lesson = await f.seal(quote: true);
    expect(await f.runtime.quotesForStream(), isEmpty);
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(quoteStream: true));
    final quote = (await f.runtime.quotesForStream()).single;
    expect(quote.lessonId, lesson.id);
    expect(quote.author, '我');
    f.clock.advance(const Duration(hours: 13));
    expect(await f.runtime.quotesForStream(), isEmpty);
    f.clock.advance(const Duration(hours: 11));
    expect(await f.runtime.quotesForStream(), hasLength(1));
    await f.runtime.setQuoteAllowed(lesson, false);
    f.clock.advance(const Duration(days: 1));
    expect(await f.runtime.quotesForStream(), isEmpty);
  });

  test(
      'daily review imports only explicit grounded misses as idempotent drafts',
      () async {
    await f.enable();
    final details = [
      {
        'presetId': 5,
        'presetName': '阅读 20 分钟',
        'status': 'missed',
        'missedReason': '坐下后打开短视频'
      },
      {'presetId': 6, 'status': 'pending', 'missedReason': '未记录'},
      {'presetId': 7, 'status': 'skipped', 'missedReason': '略过'},
      {'presetId': 8, 'status': 'aborted', 'missedReason': '中途退出'}
    ];
    await f.runtime.importReviewDrafts(details, reviewMs: 100);
    await f.runtime.importReviewDrafts(details, reviewMs: 100);
    final lessons = await f.runtime.store.lessons();
    expect(lessons, hasLength(1));
    expect(lessons.single.state, 'draft');
    expect(lessons.single.worked, isEmpty);
    expect(await f.runtime.workedItems(), isEmpty);
  });

  test(
      'AI is never called without consent and invented classifications are discarded',
      () async {
    await f.enable();
    final offer = (await f.runtime.signal(f.signal()))!;
    f.host.aiResponse = '{"sentences":[{"text":"他昨天没有学习","kind":"fact"}]}';
    await f.runtime.classifyText(offer, '今天读了 1 页');
    expect(f.host.aiCalls, 0);
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(aiConsent: true));
    final fresh = (await f.runtime.signal(f.signal()))!;
    final result = await f.runtime.classifyText(fresh, '今天读了 1 页');
    expect(f.host.aiCalls, 1);
    expect(result.single.text, '今天读了 1 页');
  });

  test('revoking AI consent cancels the in-flight classification result',
      () async {
    await f.enable();
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(aiConsent: true));
    final offer = (await f.runtime.signal(f.signal()))!;
    f.host.aiPending = Completer<String?>();
    final call = f.runtime.classifyText(offer, '今天读了 1 页');
    await Future<void>.delayed(Duration.zero);
    final revocation = f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(aiConsent: false));
    f.host.aiPending!.complete(
        '{"sentences":[{"text":"今天读了 1 页","kind":"interpretation"}]}');
    final result = await call;
    await revocation;
    expect(result.single.kind, PrpSentenceKind.fact);
    expect(f.runtime.aiAllowed, false);
  });

  test('AI draft rejects ungrounded or guarded actions and safely falls back',
      () async {
    await f.enable();
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(aiConsent: true));
    final offer = (await f.runtime.signal(f.signal()))!;
    final input = f.lesson();
    f.host.aiResponse = jsonEncode({
      'worked': input.worked,
      'failed': input.failed,
      'early_signal': input.earlySignal,
      'if_then': {'cue': input.ifCue, 'action': '每天凌晨跑 50 公里'}
    });
    expect(identical(await f.runtime.draftWithAi(offer, input), input), true);
    f.host.aiResponse = 'broken json';
    expect(identical(await f.runtime.draftWithAi(offer, input), input), true);
  });

  test(
      'new PRP schema leaves existing tables byte-for-byte unchanged; clear affects only PRP',
      () async {
    await f.db.execute(
        'CREATE TABLE be_lesson (id INTEGER PRIMARY KEY, lesson TEXT)');
    await f.db.execute(
        'CREATE TABLE fp_learning_card (id INTEGER PRIMARY KEY, body TEXT)');
    await f.db.insert('be_lesson', {'id': 1, 'lesson': '原有教训'});
    final before = await f.db.rawQuery(
        "SELECT name, sql FROM sqlite_master WHERE name IN ('be_lesson', 'fp_learning_card') ORDER BY name");
    await f.enable();
    await f.seal();
    expect(
        await f.db.rawQuery(
            "SELECT name, sql FROM sqlite_master WHERE name IN ('be_lesson', 'fp_learning_card') ORDER BY name"),
        before);
    final exported = jsonDecode(await f.runtime.exportData()) as Map;
    expect((exported['tables'] as Map)['prp_lesson'], hasLength(1));
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(enabled: false));
    await f.runtime.clearData();
    expect(await f.runtime.store.lessons(), isEmpty);
    expect((await f.db.query('be_lesson')).single['lesson'], '原有教训');
  });

  test('missing host guard fails closed before any PRP database write',
      () async {
    final detached =
        PrpRuntime(settings: f.settings.adapter, store: f.runtime.store);
    await detached
        .updatePreferences(detached.preferences.copyWith(enabled: true));
    expect(await detached.signal(f.signal()), isNull);
    expect(f.databaseOpens, 0);
  });

  test('importing a daily-review draft never consumes or suppresses an offer',
      () async {
    await f.enable(cap: 1);
    await f.runtime.importReviewDrafts([
      {
        'presetId': 5,
        'presetName': '阅读 20 分钟',
        'status': 'missed',
        'missedReason': '坐下后打开短视频'
      }
    ], reviewMs: 100);
    expect(
        await f.runtime.signal(f.signal(ref: 'new-explicit-miss')), isNotNull);
    final rows = await f.db.query('prp_session');
    expect(rows.where((r) => r['counts_offer'] == 1), hasLength(1));
    expect(rows.where((r) => r['counts_offer'] == 0), hasLength(1));
  });

  test(
      'manual revision is available even after the automatic-offer budget is spent',
      () async {
    await f.enable(cap: 1);
    final lesson = await f.seal();
    expect(await f.runtime.resumeLesson(lesson, rewrite: true), isNotNull);
    final rows = await f.db.query('prp_session');
    expect(rows.where((r) => r['counts_offer'] == 1), hasLength(1));
  });

  test(
      'daily-review AI candidates require consent, stay grounded and remain unsealed',
      () async {
    await f.enable();
    final detail = <String, dynamic>{
      'presetId': 5,
      'presetName': '阅读 20 分钟',
      'status': 'missed',
      'missedReason': '先读1页后打开短视频',
      'prp_candidate': {
        'category': '拖延',
        'worked': ['先读1页'],
        'failed': ['打开短视频'],
        'early_signal': '打开短视频',
        'if_cue': '打开短视频',
        'then_action': '先读1页',
      }
    };
    await f.runtime.importReviewDrafts([detail], reviewMs: 100);
    expect((await f.runtime.store.lessons()).single.worked, isEmpty);
    await f.runtime
        .updatePreferences(f.runtime.preferences.copyWith(aiConsent: true));
    await f.runtime.importReviewDrafts([detail], reviewMs: 100);
    final draft = (await f.runtime.store.lessons()).single;
    expect(draft.worked, ['先读1页']);
    expect(draft.state, 'draft');
    expect(draft.quality, 5);
    expect(
        await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior, subjectKey: 'habit:preset:5')),
        isEmpty);
  });

  test(
      'ignoring a recall suppresses further exposure for 24 hours across midnight',
      () async {
    await f.enable();
    await f.seal();
    final first = (await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior,
            subjectKey: 'habit:preset:5',
            reference: 'first')))
        .single;
    await f.runtime.reportOutcome(first.id, PrpOutcome.ignored);
    f.clock.advance(const Duration(hours: 13));
    expect(
        await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior,
            subjectKey: 'habit:preset:5',
            reference: 'second')),
        isEmpty);
    f.clock.advance(const Duration(hours: 11));
    expect(
        await f.runtime.recallFor(const PrpContext(
            surface: PrpSurface.behavior,
            subjectKey: 'habit:preset:5',
            reference: 'third')),
        hasLength(1));
  });
}
