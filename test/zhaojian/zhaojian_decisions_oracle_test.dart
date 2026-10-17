import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/zhaojian/zhaojian.dart';
import 'package:quote_app/zhaojian_host/zhaojian_decisions_oracle.dart';

List<ZMotive> motives(int n) => List<ZMotive>.generate(
      n,
      (int i) => ZMotive(text: '动机$i', cat: i % 12, kind: 'int'),
    );

Map<String, dynamic> bodyOf(http.Request r) => jsonDecode(r.body) as Map<String, dynamic>;

int indexOfName(String name) => int.parse(name.substring(1));

void main() {
  const ZDecisionsAccess access = ZDecisionsAccess(<String, String>{'Authorization': 'Bearer sk-test'});

  group('request shape follows the documented Decisions API', () {
    test('posts model, a text input and one score question per motive with five levels', () async {
      final List<http.Request> seen = <http.Request>[];
      final ZhaojianDecisionsOracle o = ZhaojianDecisionsOracle(
        access: () async => access,
        client: MockClient((http.Request req) async {
          seen.add(req);
          final List<dynamic> qs = bodyOf(req)['questions'] as List<dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'answers': <Map<String, dynamic>>[
                for (final dynamic q in qs)
                  <String, dynamic>{
                    'type': 'score',
                    'name': (q as Map<String, dynamic>)['name'],
                    'score': 2.5,
                    'probabilities': <Map<String, dynamic>>[],
                    'confidence': 0.7,
                  },
              ],
            }),
            200,
          );
        }),
      );
      final ZScoreResult r = await o.scoreMotives(situation: '他开口借钱', motives: motives(30));

      expect(seen.length, 3, reason: '12 + 12 + 6');
      final http.Request first = seen.first;
      expect(first.method, 'POST');
      expect(first.url.toString(), 'https://api.openai.com/v1/decisions');
      expect(first.headers['Authorization'], 'Bearer sk-test');
      expect(first.headers['Content-Type'], contains('application/json'));
      final Map<String, dynamic> body = bodyOf(first);
      expect(body['model'], 'gpt-6-luna');
      expect(body['input'], '他开口借钱');
      final List<dynamic> qs = body['questions'] as List<dynamic>;
      expect(qs.length, 12);
      final Map<String, dynamic> q0 = qs.first as Map<String, dynamic>;
      expect(q0['type'], 'score');
      expect(q0['name'], 'm0');
      expect((q0['instructions'] as String).contains('动机0'), isTrue);
      final List<dynamic> levels = q0['levels'] as List<dynamic>;
      expect(levels.length, 5);
      expect((levels.first as Map<String, dynamic>).keys.toSet(), <String>{'label', 'description'});
      expect(
        levels.map((dynamic l) => (l as Map<String, dynamic>)['label']).toSet().length,
        5,
        reason: '每个等级的标签互不相同',
      );

      expect(r.isEmpty, isFalse);
      expect(r.source, ZhaojianDecisionsOracle.sourceNote);
      expect(r.pulls.length, 30);
      expect(r.pulls[7], 2.5, reason: 'score 本身就是等级下标的概率加权平均，不再换算');
      expect(r.confidences[7], 0.7);
    });
  });

  group('response handling', () {
    test('refusals and malformed answers are skipped, the rest is kept', () async {
      final ZhaojianDecisionsOracle o = ZhaojianDecisionsOracle(
        access: () async => access,
        client: MockClient((http.Request req) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'answers': <dynamic>[
                <String, dynamic>{'type': 'refusal', 'name': 'm0'},
                <String, dynamic>{'type': 'score', 'name': 'm1', 'score': 9.0, 'confidence': 3},
                <String, dynamic>{'type': 'score', 'name': 'm2', 'score': 'x'},
                <String, dynamic>{'type': 'predicate', 'name': 'm3', 'probability': 0.5},
                <String, dynamic>{'type': 'score', 'name': 'm4', 'score': 1.0},
                <String, dynamic>{'type': 'score', 'name': 'm99', 'score': 1.0},
                'not a map',
              ],
            }),
            200,
          );
        }),
      );
      final ZScoreResult r = await o.scoreMotives(situation: 's', motives: motives(5));
      expect(r.pulls.keys.toSet(), <int>{1, 4});
      expect(r.pulls[1], 4.0, reason: '超出 0..4 的分数被截断');
      expect(r.confidences[1], 1.0);
      expect(r.pulls[4], 1.0);
    });

    test('fewer than half of the motives scored means unavailable', () async {
      final ZhaojianDecisionsOracle o = ZhaojianDecisionsOracle(
        access: () async => access,
        client: MockClient((http.Request req) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'answers': <dynamic>[
                <String, dynamic>{'type': 'score', 'name': 'm0', 'score': 2.0},
              ],
            }),
            200,
          );
        }),
      );
      expect((await o.scoreMotives(situation: 's', motives: motives(10))).isEmpty, isTrue);
    });

    test('a failing batch stops the run but keeps what already came back', () async {
      int calls = 0;
      final ZhaojianDecisionsOracle o = ZhaojianDecisionsOracle(
        access: () async => access,
        client: MockClient((http.Request req) async {
          calls += 1;
          if (calls > 1) return http.Response('{"error":"rate limited"}', 429);
          final List<dynamic> qs = bodyOf(req)['questions'] as List<dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'answers': <Map<String, dynamic>>[
                for (final dynamic q in qs)
                  <String, dynamic>{'type': 'score', 'name': (q as Map<String, dynamic>)['name'], 'score': 3.0},
              ],
            }),
            200,
          );
        }),
      );
      final ZScoreResult r = await o.scoreMotives(situation: 's', motives: motives(24));
      expect(calls, 2);
      expect(r.pulls.length, 12);
      expect(r.pulls.keys.every((int i) => i < 12), isTrue);
    });

    test('non-200, bad json and missing answers all degrade to empty', () async {
      for (final http.Response bad in <http.Response>[
        http.Response('{}', 404),
        http.Response('not json', 200),
        http.Response('{"answers":"x"}', 200),
        http.Response('{}', 200),
      ]) {
        final ZhaojianDecisionsOracle o = ZhaojianDecisionsOracle(
          access: () async => access,
          client: MockClient((http.Request req) async => bad),
        );
        expect((await o.scoreMotives(situation: 's', motives: motives(4))).isEmpty, isTrue);
      }
    });
  });

  group('availability', () {
    test('without an OpenAI key nothing is sent', () async {
      int calls = 0;
      final ZhaojianDecisionsOracle o = ZhaojianDecisionsOracle(
        access: () async => null,
        client: MockClient((http.Request req) async {
          calls += 1;
          return http.Response('{}', 200);
        }),
      );
      expect((await o.scoreMotives(situation: 's', motives: motives(3))).isEmpty, isTrue);
      expect(calls, 0);
    });

    test('a throwing access or client degrades to empty; no motives sends nothing', () async {
      final ZhaojianDecisionsOracle thrownAccess = ZhaojianDecisionsOracle(
        access: () async => throw StateError('no config'),
        client: MockClient((http.Request req) async => http.Response('{}', 200)),
      );
      expect((await thrownAccess.scoreMotives(situation: 's', motives: motives(3))).isEmpty, isTrue);

      final ZhaojianDecisionsOracle thrownClient = ZhaojianDecisionsOracle(
        access: () async => access,
        client: MockClient((http.Request req) async => throw http.ClientException('offline')),
      );
      expect((await thrownClient.scoreMotives(situation: 's', motives: motives(3))).isEmpty, isTrue);

      int calls = 0;
      final ZhaojianDecisionsOracle none = ZhaojianDecisionsOracle(
        access: () async => access,
        client: MockClient((http.Request req) async {
          calls += 1;
          return http.Response('{}', 200);
        }),
      );
      expect((await none.scoreMotives(situation: 's', motives: <ZMotive>[])).isEmpty, isTrue);
      expect(calls, 0);
    });

    test('it declares that it sends data and does not generate text', () async {
      final ZhaojianDecisionsOracle o = ZhaojianDecisionsOracle(access: () async => null);
      expect(o.sendsData, isTrue);
      expect(await o.completeMotives(question: 'q', optionA: 'a', optionB: 'b', profile: ''), isEmpty);
    });
  });
}
