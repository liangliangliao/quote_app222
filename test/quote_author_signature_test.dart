import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/kv_dao.dart';
import 'package:quote_app/services/quote_ai_service.dart';
import 'package:quote_app/services/quote_author_signature_service.dart';
import 'package:quote_app/services/unified_ai_service.dart';

class _MemoryStorage extends KeyValueDao {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

class _Ai extends UnifiedAiService {
  _Ai(this.response);
  final Future<String> Function(String) response;
  int calls = 0;
  final prompts = <String>[];
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
    prompts.add(prompt);
    return response(prompt);
  }
}

String _name(String author, String original) => jsonEncode({
  'requested_author': author,
  'original_name': original,
  'confident': true,
});

void main() {
  test(
    'requested authors have original-language names without a network dependency',
    () async {
      final ai = _Ai((_) async => throw StateError('must stay offline'));
      final service = QuoteAuthorSignatureService(
        ai: ai,
        storage: _MemoryStorage(),
      );
      for (final entry in {
        '佛洛依德': 'Sigmund Freud',
        '——西格蒙德·弗洛伊德《文明及其不满》': 'Sigmund Freud',
        '萨特': 'Jean-Paul Sartre',
        '阿尔弗雷德·阿德勒': 'Alfred Adler',
        '班杜拉': 'Albert Bandura',
        '塔尔·本-沙哈尔（Tal Ben-Shahar）': 'Tal Ben-Shahar',
        '老子': '老子',
        '莫言': '莫言',
        'Gabriel García Márquez': 'Gabriel García Márquez',
      }.entries) {
        expect(await service.resolve(entry.key), entry.value);
      }
      expect(ai.calls, 0);
    },
  );

  test(
    'custom author lookups coalesce and survive a new service instance',
    () async {
      final pending = Completer<String>();
      final ai = _Ai((_) => pending.future);
      final storage = _MemoryStorage();
      final service = QuoteAuthorSignatureService(ai: ai, storage: storage);
      final first = service.resolve('乌尔苏拉·勒古恩');
      final second = service.resolve('——乌尔苏拉·勒古恩《一无所有》');
      await Future<void>.delayed(Duration.zero);
      expect(ai.calls, 1);
      pending.complete(_name('乌尔苏拉·勒古恩', 'Ursula K. Le Guin'));
      expect(await first, 'Ursula K. Le Guin');
      expect(await second, 'Ursula K. Le Guin');
      expect(service.displayName('乌尔苏拉·勒古恩'), 'Ursula K. Le Guin');
      final restarted = QuoteAuthorSignatureService(ai: ai, storage: storage);
      expect(await restarted.resolve('乌尔苏拉·勒古恩'), 'Ursula K. Le Guin');
      expect(ai.calls, 1);
      expect(ai.prompts.single, contains('外国作者不要返回中文译名'));
      expect(ai.prompts.single, contains('乌尔苏拉·勒古恩'));
    },
  );

  test(
    'uncertain and incorrect identity results never become signatures',
    () async {
      final storage = _MemoryStorage();
      final replies = [
        _name('另一位作者', 'Wrong Person'),
        _name('自定义作者', 'Some Author《Some Book》'),
        jsonEncode({
          'requested_author': '自定义作者',
          'original_name': 'A Guess',
          'confident': false,
        }),
        '',
      ];
      for (final reply in replies) {
        final service = QuoteAuthorSignatureService(
          ai: _Ai((_) async => reply),
          storage: storage,
        );
        expect(await service.resolve('自定义作者'), isNull);
        expect(storage.values, isEmpty);
      }
      expect(
        QuoteAuthorSignatureService.cleanOriginalName(
          'https://example.com/signature.png',
        ),
        isNull,
      );
      expect(
        QuoteAuthorSignatureService.cleanOriginalName('Sigmund Freud（弗洛伊德）'),
        isNull,
      );
      expect(
        QuoteAuthorSignatureService.cleanOriginalName('Неизвестный\n作者'),
        isNull,
      );
      expect(
        QuoteAuthorSignatureService.cleanOriginalName('Лев Толстой'),
        'Лев Толстой',
      );
    },
  );

  test('failed lookups pause retries and remain recoverable', () async {
    var now = DateTime(2026, 10, 28);
    final ai = _Ai((_) async => '');
    final service = QuoteAuthorSignatureService(
      ai: ai,
      storage: _MemoryStorage(),
      now: () => now,
    );
    expect(await service.resolve('自定义作者'), isNull);
    expect(await service.resolve('自定义作者'), isNull);
    expect(ai.calls, 1);
    now = now.add(const Duration(minutes: 3));
    expect(await service.resolve('自定义作者'), isNull);
    expect(ai.calls, 2);
  });

  test(
    'generation supplies and caches the original name in its single request',
    () async {
      final ai = _Ai(
        (_) async => jsonEncode({
          'quote': '真正的旅程是归返。',
          'author': '乌尔苏拉·勒古恩',
          'author_original_name': 'Ursula K. Le Guin',
          'practice_activities': [
            {
              'title': '留一刻观察',
              'steps': ['写下此刻想重新认识的一件事。'],
            },
          ],
        }),
      );
      final storage = _MemoryStorage();
      final signatures = QuoteAuthorSignatureService(ai: ai, storage: storage);
      final service = QuoteAiService(ai: ai, signatures: signatures);
      const config = QuoteAiTaskConfig(
        selectedFigures: ['乌尔苏拉·勒古恩'],
        downloadAvatar: false,
      );
      final generated = await service.generate({
        'task_uid': 'original-name',
        'freq_custom': config.encode(),
      });
      expect(generated.author, '乌尔苏拉·勒古恩');
      expect(generated.originalAuthorName, 'Ursula K. Le Guin');
      expect(
        generated.withAvatarPath('assets/test.jpg').originalAuthorName,
        generated.originalAuthorName,
      );
      expect(
        await signatures.resolve(generated.author),
        generated.originalAuthorName,
      );
      expect(ai.calls, 1);
      expect(ai.prompts.single, contains('author_original_name'));
      final restarted = QuoteAuthorSignatureService(ai: ai, storage: storage);
      expect(
        await restarted.resolve(generated.author),
        generated.originalAuthorName,
      );
      expect(ai.calls, 1);
    },
  );
}
