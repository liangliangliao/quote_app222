import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/cognitive_models.dart';
import 'package:quote_app/epistemic/cognitive_preferences.dart';
import 'package:quote_app/epistemic/cognitive_service.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const text = '今天没去面试。我很失落。我不适合这份工作，以后一定找不到工作。';
Map<String, dynamic> response() => {
      'summary': '一次经历与长期判断需要分开看。',
      'boundary': '一次未参加面试不能决定未来所有求职结果。',
      'questions': ['这次未参加的具体原因是什么？'],
      'spans': [
        {'text': '今天没去面试。', 'kind': 'fact'},
        {'text': '我很失落。', 'kind': 'feeling'},
        {'text': '我不适合这份工作，', 'kind': 'interpretation'},
        {'text': '以后一定找不到工作。', 'kind': 'prediction'},
      ],
      'common': '未参加和未通过都可能被概括为求职受挫',
      'difference': '未参加不能显示面试时的技能表现，不能据此判断职业能力',
      'basis': '原文只报告今天没去面试，长期预测尚缺其他材料',
      'abstractions': [
        {
          'term': '职业适合性',
          'definition': '技能、任务和条件之间的匹配程度',
          'observed': '原文只报告未去面试',
          'retained': '特定要求与能力的匹配',
          'omitted': '岗位条件与其他面试表现',
          'counter_example': '一次未参加不属于能力测评',
        },
      ],
      'source_status': 'verified',
      'epistemic_status': 'supported',
      'lenses': {'cause': '原因尚不能确定', 'motive': '意愿尚不能确定'},
    };

class FakeCognitiveAi extends UnifiedAiService {
  int calls = 0;
  bool available = true;
  String model = 'test';
  String? lastPrompt;
  Map<String, dynamic>? responseOverride;
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig({
    String? forcedProvider,
    String? forcedModel,
  }) async =>
      UnifiedAiResolvedConfig(
        provider: 'test',
        apiKey: '',
        model: model,
        endpoint: 'https://example.invalid',
        label: 'test',
        displayModel: model,
        available: available,
      );
  @override
  Future<String> generateText({
    required String prompt,
    required String purpose,
    String? systemPrompt,
    int maxTokens = 1800,
    bool expectJson = false,
    String? forcedProvider,
    String? forcedModel,
    double? temperature,
  }) async {
    calls++;
    lastPrompt = prompt;
    return jsonEncode(responseOverride ?? response());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late CognitiveStore store;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = CognitiveStore(database: () async => db);
  });
  tearDown(() async => db.close());
  CognitiveSelection selection({String id = '1'}) =>
      CognitiveSelection.fromText(
        module: 'diary',
        recordId: id,
        title: '日记',
        fullText: text,
      );

  test(
      'explicit reanalysis preserves accepted history and rejects shallow output',
      () async {
    final ai = FakeCognitiveAi();
    final service = CognitiveService(ai: ai, store: store);
    final first = await service.analyze(selection(), CognitiveTask.diary);
    await store.save(first
        .copyWith(accepted: true)
        .revise(judgment: '保留的判断', evidence: '新增具体材料'));
    final next =
        await service.analyze(selection(), CognitiveTask.diary, force: true);
    expect(next.id, isNot(first.id));
    final notes = await store.forRecord('diary', '1');
    expect(notes.length, 2);
    expect(notes.last.accepted, isTrue);
    expect(notes.last.currentJudgment, '保留的判断');
    ai.responseOverride = response()..remove('abstractions');
    await expectLater(
        service.analyze(selection(), CognitiveTask.diary, force: true),
        throwsFormatException);
    expect((await store.forRecord('diary', '1')).length, 2);
  });

  test(
    'selected range is exact and other diary text or attachments never enter the prompt',
    () {
      const full = '另一段私密记录\n[图片] /private/image.jpg\n$text\n没有选中的结尾';
      final start = full.indexOf(text);
      final s = CognitiveSelection.fromText(
        module: 'diary',
        recordId: '1',
        title: '私密标题',
        fullText: full,
        start: start,
        end: start + text.length,
      );
      final prompt = CognitiveService.buildPrompt(s, CognitiveTask.diary);
      expect(
        prompt,
        contains(jsonEncode({'selected_text': text, 'kind': 'diary'})),
      );
      expect(prompt, isNot(contains('另一段私密记录')));
      expect(prompt, isNot(contains('/private/image.jpg')));
      expect(prompt, isNot(contains('私密标题')));
      expect(s.matches(full), isTrue);
      expect(s.matches('增加了一行\n$full'), isFalse);
      expect(s.text, text);
    },
  );

  test(
    'classification preserves every character and never treats model fact as verified',
    () {
      final analysis = CognitiveService.parse(
        jsonEncode(response()),
        selection(),
        CognitiveTask.diary,
      );
      expect(analysis.spans.map((s) => s.text).join(), text);
      expect(analysis.spans.first.kind, StatementKind.reportedEvent);
      expect(analysis.spans.last.kind, StatementKind.prediction);
      final spans = CognitiveSpan.parse([
        {'text': '🙂今天', 'kind': 'feeling'},
        {'text': '不存在的事实', 'kind': 'fact'},
        {'text': '明天', 'kind': 'prediction'},
      ], '🙂今天，明天？');
      expect(spans.map((s) => s.text).join(), '🙂今天，明天？');
      for (final span in spans) {
        expect('🙂今天，明天？'.substring(span.start, span.end), span.text);
      }
    },
  );

  test(
    'invented excerpts and missing boundaries cannot produce a successful diary annotation',
    () {
      final fake = response()
        ..['spans'] = [
          {'text': '他患有某种疾病', 'kind': 'fact'},
        ];
      expect(
        () => CognitiveService.parse(
          jsonEncode(fake),
          selection(),
          CognitiveTask.diary,
        ),
        throwsFormatException,
      );
      final incomplete = response()..remove('boundary');
      expect(
        () => CognitiveService.parse(
          jsonEncode(incomplete),
          selection(),
          CognitiveTask.diary,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'annotation cache, acceptance, editing, rollback and deletion never touch the diary row',
    () async {
      await db.execute(
        'CREATE TABLE entries (id INTEGER PRIMARY KEY, content TEXT, updated_at INTEGER)',
      );
      await db.insert('entries', {'id': 1, 'content': text, 'updated_at': 123});
      final ai = FakeCognitiveAi();
      final service = CognitiveService(ai: ai, store: store);
      final initial = await service.analyze(selection(), CognitiveTask.diary);
      expect(initial.toJson()['source_status'], 'unverified');
      expect(initial.toJson()['epistemic_status'], 'provisional');
      expect(await store.acceptedForRecap(), isEmpty);
      var note = initial.copyWith(accepted: true);
      await store.save(note);
      expect(await store.acceptedForRecap(), hasLength(1));
      final changed = [...note.analysis.spans];
      changed.last = changed.last.withKind(StatementKind.interpretation);
      note = note.copyWith(analysis: note.analysis.withSpans(changed));
      await store.save(note);
      ai.available = false;
      expect(
        (await service.analyze(
          selection(),
          CognitiveTask.diary,
        ))
            .analysis
            .spans
            .last
            .kind,
        StatementKind.interpretation,
      );
      expect(ai.calls, 1);
      final revised = note.revise(
        judgment: '这次未参加不决定后续结果',
        evidence: '我收到了另一次面试邀请',
      );
      final restored = revised.revise(
        judgment: revised.revisions.first.previous,
        evidence: '重新审视先前判断',
        reason: '手动回退',
      );
      expect(restored.revisions, hasLength(2));
      expect(restored.selection.text, text);
      await store.save(restored.copyWith(accepted: false));
      expect(await store.acceptedForRecap(), isEmpty);
      await store.delete(restored);
      expect(await store.forRecord('diary', '1'), isEmpty);
      expect((await db.query('entries')).single, {
        'id': 1,
        'content': text,
        'updated_at': 123,
      });
    },
  );

  test(
    'cache is isolated by record, range, model and task; repeated explicit requests coalesce',
    () async {
      final ai = FakeCognitiveAi();
      final service = CognitiveService(ai: ai, store: store);
      await Future.wait([
        service.analyze(selection(), CognitiveTask.diary),
        service.analyze(selection(), CognitiveTask.diary),
      ]);
      expect(ai.calls, 1);
      await service.analyze(selection(id: '2'), CognitiveTask.diary);
      ai.model = 'other';
      await service.analyze(selection(), CognitiveTask.diary);
      await service.analyze(selection(), CognitiveTask.calibration);
      expect(ai.calls, 4);
    },
  );

  test(
    'draft annotation follows normal diary save without touching unrelated KV',
    () async {
      final service = CognitiveService(ai: FakeCognitiveAi(), store: store);
      await service.analyze(selection(id: 'draft'), CognitiveTask.diary);
      await db.insert('app_kv', {'key': 'user.setting', 'value': 'keep'});
      await store.bindDraft('diary', 'draft', '3');
      expect(await store.forRecord('diary', 'draft'), isEmpty);
      expect(
        (await store.forRecord('diary', '3')).single.selection.recordId,
        '3',
      );
      await store.deleteRecord('diary', '3');
      expect((await db.query('app_kv')).single['value'], 'keep');
    },
  );

  test(
    'global preferences persist and unknown older fields have safe defaults',
    () async {
      final prefs = CognitivePreferenceStore(store: store);
      await prefs.update(
        prefs.value.change('style', 'comparative').change('prompts', false),
      );
      final reopened = CognitivePreferenceStore(store: store);
      await reopened.load();
      expect(reopened.value.style, CognitiveStyle.comparative);
      expect(reopened.value.prompts, isFalse);
      expect(reopened.value.grounds, isTrue);
      expect(CognitivePreferences.fromJson('{invalid').enabled, isFalse);
      prefs.dispose();
      reopened.dispose();
    },
  );
}
