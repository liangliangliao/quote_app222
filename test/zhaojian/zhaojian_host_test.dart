import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhaojian/zhaojian.dart';
import 'package:quote_app/zhaojian_host/zhaojian_ai_oracle.dart';

Future<String> _reply(String text) async => text;

void main() {
  group('discover entry', () {
    testWidgets('shows the title and reports taps', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ZhaojianDiscoverEntry(onTap: () => taps += 1)),
      ));
      expect(find.text(ZCopy.title), findsOneWidget);
      expect(find.text(ZCopy.discoverSubtitle), findsOneWidget);
      await tester.tap(find.byKey(ZhaojianDiscoverEntry.entryKey));
      expect(taps, 1);
    });
  });

  group('AI oracle parsing', () {
    test('parseMotives keeps valid rows and tolerates fences and noise', () {
      const String raw = '这是结果：\n```json\n[\n'
          '{"t":"怕被说小气","c":1,"k":"int","s":"a","y":"av","v":"想象旁边有人看着"},\n'
          '{"t":"","c":2,"k":"abs","s":"b","y":"ap","v":"没有动机文字，应被丢弃"},\n'
          '{"t":"家人至上","c":99,"k":"abs","s":"x","y":"zzz","v":"类别越界时回到起始类别"},\n'
          '"not a map"\n]\n```';
      final List<ZMotive> r = ZhaojianAiOracle.parseMotives(raw, from: 6, to: 11);
      expect(r.length, 2);
      expect(r.first.text, '怕被说小气');
      expect(r.first.cat, 1);
      expect(r.first.kind, 'int');
      expect(r.first.side, 'a');
      expect(r.first.valence, 'av');
      expect(r.first.ai, isTrue);
      expect(r.last.cat, 6, reason: '越界类别回到 from');
      expect(r.last.side, 'both');
      expect(r.last.valence, 'ap');
    });

    test('parseMotives returns empty for garbage', () {
      expect(ZhaojianAiOracle.parseMotives('没有数组'), isEmpty);
      expect(ZhaojianAiOracle.parseMotives('[{oops'), isEmpty);
    });

    test('parseScores clamps values and needs at least half of the candidates', () {
      final ZScoreResult ok = ZhaojianAiOracle.parseScores(
        '[{"i":0,"s":9,"conf":2},{"i":1,"s":"2.5","conf":0.4},{"i":7,"s":1}]',
        3,
      );
      expect(ok.isEmpty, isFalse);
      expect(ok.pulls[0], 4.0);
      expect(ok.confidences[0], 1.0);
      expect(ok.pulls[1], 2.5);
      expect(ok.pulls.containsKey(7), isFalse);
      expect(ok.source, ZhaojianAiOracle.sourceNote);

      expect(ZhaojianAiOracle.parseScores('[{"i":0,"s":1}]', 5).isEmpty, isTrue);
      expect(ZhaojianAiOracle.parseScores('garbage', 5).isEmpty, isTrue);
    });
  });

  group('AI oracle fallbacks', () {
    test('unavailable AI yields empty results without calling the model', () async {
      int calls = 0;
      final ZhaojianAiOracle o = ZhaojianAiOracle(
        call: ({
          required String prompt,
          required String systemPrompt,
          required String purpose,
          required int maxTokens,
        }) {
          calls += 1;
          return _reply('[]');
        },
        isAvailable: () async => false,
      );
      expect(
        await o.completeMotives(question: 'q', optionA: 'a', optionB: 'b', profile: ''),
        isEmpty,
      );
      expect(
        (await o.scoreMotives(
          situation: 's',
          motives: <ZMotive>[ZMotive(text: 'x', cat: 0, kind: 'int')],
        ))
            .isEmpty,
        isTrue,
      );
      expect(calls, 0);
    });

    test('a throwing model call degrades to empty', () async {
      final ZhaojianAiOracle o = ZhaojianAiOracle(
        call: ({
          required String prompt,
          required String systemPrompt,
          required String purpose,
          required int maxTokens,
        }) async {
          throw StateError('network down');
        },
        isAvailable: () async => true,
      );
      expect(
        await o.completeMotives(question: 'q', optionA: 'a', optionB: 'b', profile: ''),
        isEmpty,
      );
      expect(
        (await o.scoreMotives(
          situation: 's',
          motives: <ZMotive>[ZMotive(text: 'x', cat: 0, kind: 'int')],
        ))
            .isEmpty,
        isTrue,
      );
    });

    test('a working model call returns parsed motives and scores', () async {
      final ZhaojianAiOracle o = ZhaojianAiOracle(
        call: ({
          required String prompt,
          required String systemPrompt,
          required String purpose,
          required int maxTokens,
        }) {
          if (purpose == 'zhaojian.complete_motives') {
            return _reply(
                '[{"t":"想被感谢","c":0,"k":"int","s":"a","y":"ap","v":"他说谢谢时你嘴角动了一下"}]');
          }
          return _reply('[{"i":0,"s":3,"conf":0.8},{"i":1,"s":1,"conf":0.6}]');
        },
        isAvailable: () async => true,
      );
      final List<ZMotive> ms =
          await o.completeMotives(question: 'q', optionA: 'a', optionB: 'b', profile: '');
      expect(ms.length, 2, reason: '两路各返回一条');
      final ZScoreResult r = await o.scoreMotives(
        situation: 's',
        motives: <ZMotive>[
          ZMotive(text: 'x', cat: 0, kind: 'int'),
          ZMotive(text: 'y', cat: 1, kind: 'int'),
        ],
      );
      expect(r.isEmpty, isFalse);
      expect(r.pulls[0], 3.0);
    });
  });
}
