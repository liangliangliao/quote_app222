import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/services/quote_ai_service.dart';

void main() {
  group('QuoteAiTaskConfig', () {
    test('round-trips settings and rotates figures in saved order', () {
      final config = QuoteAiTaskConfig(
        selectedFigures: const <String>['孔子', '爱因斯坦'],
        customFigures: const <String>['汉娜·阿伦特'],
        theme: '勇气与行动',
        userDescription: '在不确定中仍然行动',
        intervalMinutes: 120,
      );
      final decoded = QuoteAiTaskConfig.fromTask(<String, dynamic>{
        'freq_custom': config.encode(),
      });

      expect(decoded.figureForCursor(0), '孔子');
      expect(decoded.figureForCursor(1), '爱因斯坦');
      expect(decoded.figureForCursor(2), '汉娜·阿伦特');
      expect(decoded.figureForCursor(3), '孔子');
      expect(decoded.intervalMinutes, 120);
      expect(decoded.userDescription, '在不确定中仍然行动');
    });

    test(
      'custom input removes empty and repeated names without reordering',
      () {
        expect(
          QuoteAiTaskConfig.parseFigureInput('费曼、费曼，阿伦特; 王阳明'),
          const <String>['费曼', '阿伦特', '王阳明'],
        );
      },
    );
  });

  group('QuoteAiService prompt and parser', () {
    test(
      'prompt carries semantic intent and never needs local quote history',
      () {
        const config = QuoteAiTaskConfig(
          theme: '成长与改变',
          userDescription: '我害怕改变，但也不想停在原地',
        );
        final prompt = QuoteAiService.buildPrompt(
          taskUid: 'task_1',
          config: config,
          selectedFigure: '卡尔·荣格',
          cursor: 4,
        );

        expect(prompt, contains('卡尔·荣格'));
        expect(prompt, contains('我害怕改变，但也不想停在原地'));
        expect(prompt, contains('语义匹配优先级最高'));
        expect(prompt, contains('应用不会发送历史名言正文'));
      },
    );

    test('parses fenced JSON and builds the complete local explanation', () {
      const raw = '''```json
{
  "quote": "未经审视的人生不值得过。",
  "author": "苏格拉底",
  "source": "柏拉图《申辩篇》",
  "theme": "人生智慧",
  "core_match": "强调主动反思",
  "analysis": "作者把反思视为有意义生活的条件。",
  "problem_addressed": "应对未经辨析便随波逐流的问题。",
  "related_person": "孔子",
  "related_thought": "吾日三省吾身，同样强调持续自省。",
  "source_confidence": "高：有古典文本记录",
  "avatar_search_query": "苏格拉底 Socrates",
  "avatar_url": "https://example.com/not-trusted.jpg"
}
```''';

      final result = QuoteAiService.parseResponse(
        raw,
        selectedFigure: '苏格拉底',
        fallbackTheme: '',
        nextCursor: 8,
      );

      expect(result.author, '苏格拉底');
      expect(result.avatarSourceUrl, isEmpty);
      expect(result.nextCursor, 8);
      expect(result.explanation, contains('核心思想匹配：强调主动反思'));
      expect(result.explanation, contains('它试图回应的问题'));
      expect(result.explanation, contains('关联思想（孔子）'));
    });

    test('uses explicit uncertainty instead of inventing a missing source', () {
      final result = QuoteAiService.parseResponse(
        '{"quote":"先行动，再修正。","author":"某思想家"}',
        selectedFigure: '',
        fallbackTheme: '勇气与行动',
        nextCursor: 1,
      );

      expect(result.source, '出处待考');
      expect(result.theme, '勇气与行动');
    });

    test('rejects a response attributed to a different selected person', () {
      expect(
        () => QuoteAiService.parseResponse(
          '{"quote":"保持前进。","author":"林肯"}',
          selectedFigure: '孔子',
          fallbackTheme: '',
          nextCursor: 1,
        ),
        throwsFormatException,
      );
    });
  });
}
