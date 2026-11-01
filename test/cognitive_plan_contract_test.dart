import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/cognitive_models.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/epistemic/cognitive_service.dart';
import 'package:quote_app/epistemic/cognitive_hint_budget.dart';
import 'package:quote_app/epistemic/cognitive_scope_hint.dart';
import 'package:quote_app/epistemic/cognitive_usage.dart';
import 'package:quote_app/epistemic/cognitive_record_adapter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'cognitive_core_test.dart' as core;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late CognitiveStore store;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = CognitiveStore(database: () async => db);
  });
  tearDown(() => db.close());

  CognitiveNote record(
          String id, String observation, String judgment) =>
      CognitiveNote(
          id: id,
          task: CognitiveTask.reflection,
          selection: CognitiveSelection.fromText(
              module: 'xiangji_problem',
              recordId: 'problem-1',
              title: '认识闭环',
              fullText: observation),
          analysis: CognitiveAnalysis(
              summary: judgment, basis: '当前记录', boundary: '仍待检验'),
          modelInfo: 'existing_record_snapshot',
          createdAt: '2026-11-01T00:00:00Z');

  test(
      'references are exact chosen ranges; forged record IDs and verified claims are discarded',
      () {
    const full = '未选中的私密前文。今天没有参加面试。未选中的私密结尾。';
    final start = full.indexOf('今天');
    final selection = CognitiveSelection.fromText(
        module: 'diary',
        recordId: 'entry-1',
        title: '日记',
        fullText: full,
        start: start,
        end: start + '今天没有参加面试。'.length);
    final analysis = CognitiveAnalysis.fromJson({
      'summary': '一种理解',
      'evidence_refs': [
        {
          'excerpt': '今天没有参加面试',
          'locator': 'diary:other-secret',
          'verified': true,
          'source_status': 'verified'
        },
        {'excerpt': '完全不存在的证据', 'locator': 'https://example.invalid/forged'},
      ]
    }, selection.text);
    final note = CognitiveNote(
        id: 'n',
        task: CognitiveTask.diary,
        selection: selection,
        analysis: analysis,
        modelInfo: 'test',
        createdAt: 'now');
    final ref = note.evidenceRefs.single;
    expect(ref['excerpt'], '今天没有参加面试');
    expect(ref['start'], start);
    expect(ref['locator'], startsWith('diary:entry-1#'));
    expect(ref['source_status'], 'unverified');
    final serialized = jsonEncode(note.toJson());
    expect(serialized, isNot(contains('other-secret')));
    expect(serialized, isNot(contains('example.invalid')));
    expect(serialized, isNot(contains('未选中的私密')));
    expect(
        CognitiveNote.fromJson(note.toJson()).evidenceRefs, note.evidenceRefs);
  });

  test(
      'old annotations gain local provenance and draft binding changes only their locator',
      () async {
    final note = record('old', '原始观察', '原始判断');
    final oldJson = note.toJson()..remove('evidence_refs');
    (oldJson['analysis'] as Map).remove('evidence_refs');
    final restored = CognitiveNote.fromJson(oldJson);
    expect(restored.evidenceRefs.single['excerpt'], '原始观察');
    await store.save(restored);
    await store.bindDraft('xiangji_problem', 'problem-1', 'saved-problem');
    final bound =
        (await store.forRecord('xiangji_problem', 'saved-problem')).single;
    expect(bound.evidenceRefs.single['locator'],
        startsWith('xiangji_problem:saved-problem#'));
    expect(bound.selection.text, restored.selection.text);
    expect(bound.selection.originalHash, restored.selection.originalHash);
  });

  test(
      'ambiguous evidence needs an exact range; repeated or invented snippets cannot forge support',
      () {
    expect(
        CognitiveEvidence.parse([
          {'excerpt': '观察'}
        ], '观察之后再观察'),
        isEmpty);
    final valid = CognitiveEvidence.parse([
      {'excerpt': '观察', 'start': 5, 'end': 7}
    ], '观察之后再观察');
    expect(valid.single.start, 5);
    expect(
        CognitiveEvidence.parse([
          {'excerpt': '观察', 'start': 1, 'end': 3}
        ], '观察之后再观察'),
        isEmpty);
  });

  test(
      'local scope detection preserves wording and skips already qualified statements',
      () {
    const text = '保留前一段。以后永远都做不好。保留后一段。';
    final claim = findAbsoluteClaim(text)!;
    expect(text.substring(claim.start, claim.end), claim.text);
    expect(claim.text, '以后永远都做不好。');
    expect(findAbsoluteClaim('这件事不一定会失败。'), isNull);
    expect(findAbsoluteClaim('并非总是如此。'), isNull);
    expect(findAbsoluteClaim('我从来不可能成功。'), isNotNull);
  });

  test(
      'all modules share a local-day hint budget and retain the prior enemy throttle',
      () async {
    var now = DateTime(2026, 11, 1, 23, 59);
    final first = CognitiveHintBudget(store: store, now: () => now);
    final otherModule = CognitiveHintBudget(store: store, now: () => now);
    expect(await first.claim(), isTrue);
    expect(await otherModule.claim(), isFalse);
    now = DateTime(2026, 11, 2);
    expect(await otherModule.claim(), isTrue);
    await db.delete('app_kv');
    await db.insert('app_kv',
        {'key': CognitiveHintBudget.legacyKey, 'value': '2026-11-02'});
    expect(await first.claim(), isFalse);
  });

  test(
      'usage is opt-in, race-safe, aggregate-only, and can be withdrawn and cleared',
      () async {
    var allowed = false;
    final usage = CognitiveUsageStore(store: store, allowed: () => allowed);
    await usage.record(CognitiveEvent.accepted);
    expect(await usage.read(), isEmpty);
    allowed = true;
    await Future.wait(
        List.generate(25, (_) => usage.record(CognitiveEvent.exampleOpened)));
    await usage.record(CognitiveEvent.invalidOutput);
    expect((await usage.read())[CognitiveEvent.exampleOpened], 25);
    final raw = (await db.query('app_kv',
            where: 'key=?', whereArgs: [CognitiveUsageStore.key]))
        .single['value'] as String;
    expect(jsonDecode(raw), {'exampleOpened': 25, 'invalidOutput': 1});
    allowed = false;
    await usage.record(CognitiveEvent.skipped);
    expect((await usage.read()).containsKey(CognitiveEvent.skipped), isFalse);
    await usage.clear();
    expect(await usage.read(), isEmpty);
  });

  test(
      'business snapshots form one reversible judgment chain without changing original material',
      () async {
    final adapter = CognitiveRecordAdapter(store: store);
    final original = record('v1', '第一次没有完成', '方法可能不合适');
    expect((await adapter.capture(original)).requiresRevision, isFalse);
    expect((await adapter.capture(original)).requiresRevision, isFalse);
    final next = record('v2', '第二次换方法后完成', '调整方法可以改善结果');
    final proposal = await adapter.capture(next);
    expect(proposal.requiresRevision, isTrue);
    final saved = await adapter.revise(proposal,
        judgment: next.analysis.summary,
        evidence: '第二次换方法后完成',
        reason: '出现了不同结果');
    expect(saved.id, original.id);
    expect(saved.selection.text, original.selection.text);
    expect(saved.revisions.single.previous, original.currentJudgment);
    expect(saved.revisions.single.sourceSnapshot, 'v2');
    expect((await adapter.capture(next)).requiresRevision, isFalse);
    final rolled = saved.revise(
        judgment: original.currentJudgment,
        evidence: '重新审视最初材料',
        reason: '用户回退');
    await store.save(rolled);
    expect(
        (await store.forRecord('xiangji_problem', 'problem-1'))
            .single
            .revisions
            .length,
        2);
    expect((await adapter.capture(next)).requiresRevision, isTrue);
    await expectLater(
        adapter.revise(proposal, judgment: '不应覆盖', evidence: '过期窗口'),
        throwsStateError);
  });

  test(
      'recap budget is explicit and never sends an oversized or changed selection',
      () async {
    final note = record('large', List.filled(13000, '字').join(), '暂定判断')
        .copyWith(accepted: true);
    await store.save(note);
    final ai = core.FakeCognitiveAi();
    final service = CognitiveService(ai: ai, store: store);
    await expectLater(service.reviewSelections([note]), throwsArgumentError);
    expect(ai.calls, 0);
    expect(CognitiveService.reviewSnapshot(note)['revisions'], isEmpty);
  });

  test('concurrent record revisions cannot overwrite each other', () async {
    final adapter = CognitiveRecordAdapter(store: store);
    await adapter.capture(record('first', '最初材料', '最初判断'));
    final a = await adapter.capture(record('second', '材料 A', '判断 A'));
    final b = await adapter.capture(record('third', '材料 B', '判断 B'));
    Future<bool> save(CognitiveRecordProposal p, String value) async {
      try {
        await adapter.revise(p, judgment: value, evidence: '具体新增材料');
        return true;
      } on StateError {
        return false;
      }
    }

    final results = await Future.wait([save(a, '判断 A'), save(b, '判断 B')]);
    expect(results.where((value) => value), hasLength(1));
    final note = (await store.forRecord('xiangji_problem', 'problem-1')).single;
    expect(note.revisions, hasLength(1));
    expect(note.revisions.single.previous, '最初判断');
  });
}
