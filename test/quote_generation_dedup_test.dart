import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/quote_generation_history.dart';
import 'package:quote_app/services/quote_ai_service.dart';
import 'package:quote_app/services/quote_author_signature_service.dart';
import 'package:quote_app/services/quote_duplicate_guard.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures/quote_generation_fakes.dart';

class _Ai extends UnifiedAiService {
  _Ai(this.respond);
  final Future<String> Function(String purpose, String prompt) respond;
  final generationPrompts = <String>[];
  final checkPrompts = <String>[];

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
    (purpose == 'quote_ai.duplicate_check' ? checkPrompts : generationPrompts)
        .add(prompt);
    return respond(purpose, prompt);
  }
}

class _CompetingHistory extends MemoryQuoteHistory {
  var injected = false;

  @override
  Future<bool> rememberIfUnchanged(
    QuoteHistoryEntry entry, {
    required String taskUid,
    required List<QuoteHistoryEntry> checkedHistory,
  }) async {
    if (!injected) {
      injected = true;
      entries.insert(0, entry);
      return false;
    }
    return super.rememberIfUnchanged(entry,
        taskUid: taskUid, checkedHistory: checkedHistory);
  }
}

const oldQuote = QuoteHistoryEntry(
  content: '那些杀不死我的，终将使我更强大。',
  author: '尼采',
  originalContent: 'Was mich nicht umbringt, macht mich stärker.',
);
const newOriginal =
    'Man muss noch Chaos in sich haben, um einen tanzenden Stern gebären zu können.';

String response(String original, {String quote = '你心里必须有混沌，才能诞生一颗舞动的星。'}) =>
    jsonEncode({
      'quote': quote,
      'original_quote': original,
      'author': '尼采',
      'practice_activities': ['记录今天一个尚未成形的想法。'],
    });

Map<String, dynamic> task({bool translated = false, bool save = true}) => {
      'task_uid': 'nietzsche',
      'cursor': 4,
      'freq_custom': QuoteAiTaskConfig(
        selectedFigures: const ['尼采'],
        downloadAvatar: false,
        translateToChinese: translated,
        saveLocally: save,
      ).encode(),
    };

QuoteAiService service(_Ai ai, QuoteGenerationHistory history) =>
    QuoteAiService(
      ai: ai,
      history: history,
      signatures:
          QuoteAuthorSignatureService(ai: ai, storage: MemoryQuoteKeyValue()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalization catches punctuation, case and original-language identity',
      () {
    const a = QuoteHistoryEntry(
        content: '“Was mich nicht umbringt, macht mich stärker.”');
    expect(
        a.sameTextAs(const QuoteHistoryEntry(
          content: 'WAS MICH NICHT UMBRINGT — MACHT MICH STÄRKER!',
        )),
        isTrue);
    expect(a.sameTextAs(oldQuote), isTrue);
    expect(oldQuote.sameTextAs(const QuoteHistoryEntry(content: '人应当热爱生命。')),
        isFalse);
  });

  test('exact duplicates do not spend a semantic-check request', () async {
    final ai = _Ai((_, __) async => throw StateError('no API call'));
    expect(await QuoteDuplicateGuard(ai).isDuplicate(oldQuote, [oldQuote]),
        isTrue);
    expect(ai.checkPrompts, isEmpty);
  });

  test(
      'semantic check identifies paraphrases and translations of old library text',
      () async {
    final ai = _Ai((_, prompt) async {
      expect(prompt, contains('不同译文、跨语言版本、改写'));
      expect(prompt, contains('凡不能毁灭我的'));
      expect(prompt, contains('Was mich nicht umbringt'));
      return '{"decision":"duplicate","matched_index":0}';
    });
    expect(
        await QuoteDuplicateGuard(ai).isDuplicate(oldQuote, const [
          QuoteHistoryEntry(content: '凡不能毁灭我的，必使我强大。', author: '尼采'),
        ]),
        isTrue);
  });

  test(
      'semantic checks include every history batch, including the oldest quote',
      () async {
    final ai = _Ai((_, prompt) async {
      if (prompt.contains('oldest-marker')) {
        return '{"decision":"duplicate","matched_index":2}';
      }
      return '{"decision":"distinct","matched_index":null}';
    });
    final history =
        List.generate(102, (i) => QuoteHistoryEntry(content: 'history-$i'))
          ..add(const QuoteHistoryEntry(content: 'oldest-marker'));
    expect(
        await QuoteDuplicateGuard(ai).isDuplicate(oldQuote, history), isTrue);
    expect(ai.checkPrompts, hasLength(3));
  });

  test('invalid or uncertain duplicate checks cannot accept a quote', () async {
    for (final raw in [
      '',
      'not JSON',
      '{"decision":"uncertain"}',
      '{"decision":"distinct","matched_index":0}'
    ]) {
      final ai = _Ai((_, __) async => raw);
      await expectLater(
          QuoteDuplicateGuard(ai).isDuplicate(
              const QuoteHistoryEntry(content: newOriginal), [oldQuote]),
          throwsStateError);
    }
  });

  test('generation retries a duplicate and advances the figure cursor once',
      () async {
    var generations = 0;
    final ai = _Ai((purpose, _) async => purpose == 'quote_ai.duplicate_check'
        ? '{"decision":"distinct","matched_index":null}'
        : response(
            ++generations == 1 ? oldQuote.originalContent : newOriginal));
    final history = MemoryQuoteHistory([oldQuote]);
    final result = await service(ai, history).generate(task());
    expect(result.content, newOriginal);
    expect(result.nextCursor, 5);
    expect(ai.generationPrompts, hasLength(2));
    expect(ai.checkPrompts, hasLength(1));
    expect(ai.generationPrompts.last, contains(oldQuote.content));
    expect(ai.generationPrompts.last, contains(oldQuote.originalContent));
    expect(history.entries, hasLength(2));
  });

  test('semantic duplicate triggers a fresh generation rather than a save',
      () async {
    var generations = 0;
    var checks = 0;
    final history = MemoryQuoteHistory(const [
      QuoteHistoryEntry(content: '凡不能毁灭我的，必使我强大。', author: '尼采'),
    ]);
    final ai = _Ai((purpose, _) async => purpose == 'quote_ai.duplicate_check'
        ? (++checks == 1
            ? '{"decision":"duplicate"}'
            : '{"decision":"distinct"}')
        : response(
            ++generations == 1 ? oldQuote.originalContent : newOriginal));
    expect((await service(ai, history).generate(task())).content, newOriginal);
    expect(generations, 2);
    expect(history.entries, hasLength(2));
  });

  test('repeated duplicates exhaust a bounded retry without recording a result',
      () async {
    final ai = _Ai((_, __) async => response(oldQuote.originalContent));
    final history = MemoryQuoteHistory([oldQuote]);
    await expectLater(service(ai, history).generate(task()), throwsStateError);
    expect(ai.generationPrompts, hasLength(3));
    expect(ai.checkPrompts, isEmpty);
    expect(history.entries, hasLength(1));
  });

  test('translation and save-local switches cannot reset acquisition history',
      () async {
    var generations = 0;
    final history = MemoryQuoteHistory();
    final ai = _Ai((purpose, _) async => purpose == 'quote_ai.duplicate_check'
        ? '{"decision":"distinct"}'
        : response(++generations < 3 ? oldQuote.originalContent : newOriginal,
            quote:
                generations < 3 ? oldQuote.content : '你心里必须有混沌，才能诞生一颗舞动的星。'));
    final first = await service(ai, history).generate(task(save: false));
    final next = await service(ai, history)
        .generate(task(translated: true, save: false));
    expect(first.content, oldQuote.originalContent);
    expect(next.originalContent, newOriginal);
    expect(next.content, '你心里必须有混沌，才能诞生一颗舞动的星。');
    expect(history.entries, hasLength(2));
  });

  test('failed semantic validation leaves no accepted history entry', () async {
    final ai = _Ai((purpose, _) async =>
        purpose == 'quote_ai.duplicate_check' ? '' : response(newOriginal));
    final history = MemoryQuoteHistory([oldQuote]);
    await expectLater(service(ai, history).generate(task()), throwsStateError);
    expect(history.entries, hasLength(1));
    expect(ai.generationPrompts, hasLength(1));
  });

  test('generation rechecks a quote accepted by another task during validation',
      () async {
    var generations = 0;
    final history = _CompetingHistory();
    final ai = _Ai((purpose, _) async => purpose == 'quote_ai.duplicate_check'
        ? '{"decision":"distinct"}'
        : response(
            ++generations == 1 ? oldQuote.originalContent : newOriginal));
    final result = await service(ai, history).generate(task());
    expect(result.content, newOriginal);
    expect(generations, 2);
    expect(history.entries, hasLength(2));
  });

  test('generation cannot silently accept a translation without an original',
      () async {
    final history = MemoryQuoteHistory();
    final ai = _Ai((_, __) async => jsonEncode({
          'quote': oldQuote.content,
          'author': '尼采',
          'practice_activities': ['观察今天一件事。'],
        }));
    await expectLater(
        service(ai, history).generate(task()), throwsFormatException);
    expect(history.entries, isEmpty);
  });

  group('SQLite acquisition history', () {
    late Database db;
    late QuoteGenerationHistory history;
    setUp(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
      await db.execute(
          'CREATE TABLE quotes (id INTEGER PRIMARY KEY, content TEXT, author_name TEXT, source_from TEXT)');
      history = QuoteGenerationHistory(database: () async => db);
    });
    tearDown(() => db.close());

    test(
        'existing library participates and accepted history survives store recreation',
        () async {
      await db.insert('quotes', {
        'content': oldQuote.content,
        'author_name': '尼采',
        'source_from': '旧记录'
      });
      final before = await history.load();
      expect(before.single.content, oldQuote.content);
      const entry = QuoteHistoryEntry(content: newOriginal, author: '尼采');
      expect(
          await history.rememberIfUnchanged(entry,
              taskUid: 'one', checkedHistory: before),
          isTrue);
      final reopened = QuoteGenerationHistory(database: () async => db);
      expect(await reopened.load(), hasLength(2));
      expect(await db.query('quotes'), hasLength(1));
    });

    test(
        'concurrent snapshots cannot accept the same original with a new translation',
        () async {
      final snapshot = await history.load();
      final results = await Future.wait([
        history.rememberIfUnchanged(oldQuote,
            taskUid: 'first', checkedHistory: snapshot),
        history.rememberIfUnchanged(
            const QuoteHistoryEntry(
              content: '凡不能毁灭我的，必使我强大。',
              originalContent: 'Was mich nicht umbringt, macht mich stärker.',
            ),
            taskUid: 'second',
            checkedHistory: snapshot),
      ]);
      expect(results.where((accepted) => accepted), hasLength(1));
      expect(await history.load(), hasLength(1));
    });

    test('a manual insert during validation invalidates the checked snapshot',
        () async {
      final snapshot = await history.load();
      await db.insert('quotes', {'content': '新增的历史名言'});
      expect(
          await history.rememberIfUnchanged(oldQuote,
              taskUid: 'first', checkedHistory: snapshot),
          isFalse);
      expect(await db.query('quote_generation_history'), isEmpty);
    });
  });
}
