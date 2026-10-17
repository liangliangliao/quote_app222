import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';
import 'package:quote_app/zhaojian/zhaojian.dart';
import 'package:quote_app/zhaojian_host/zhaojian_host_oracle.dart';
import 'package:quote_app/zhaojian_host/zhaojian_jev_oracle.dart';

List<ZMotive> motives(int n) => List<ZMotive>.generate(
      n,
      (int i) => ZMotive(text: '动机$i', cat: i % 12, kind: 'int'),
    );

Map<String, dynamic> questionsOf(http.Request req) {
  final Map<String, dynamic> body =
      jsonDecode(req.body) as Map<String, dynamic>;
  return body['questions'] as Map<String, dynamic>;
}

int indexOf(String key) =>
    int.parse(key.substring(ZhaojianJevOracle.keyPrefix.length));

class _Fake extends ZhaojianOracle {
  _Fake(this.result, {this.throws = false});

  final ZScoreResult result;
  final bool throws;
  int scoreCalls = 0;

  @override
  String get label => 'fake';

  @override
  Future<List<ZMotive>> completeMotives({
    required String question,
    required String optionA,
    required String optionB,
    required String profile,
  }) async =>
      <ZMotive>[ZMotive(text: 'from-text', cat: 0, kind: 'int')];

  @override
  Future<ZScoreResult> scoreMotives({
    required String situation,
    required List<ZMotive> motives,
  }) async {
    scoreCalls += 1;
    if (throws) throw StateError('boom');
    return result;
  }
}

void main() {
  group('ZhaojianJevOracle', () {
    test('sends one independent score question per motive in small batches', () async {
      final List<http.Request> seen = <http.Request>[];
      final EvidenceGrowthJev jev = EvidenceGrowthJev(
        client: MockClient((http.Request req) async {
          seen.add(req);
          final Map<String, dynamic> q = questionsOf(req);
          return http.Response(
            jsonEncode(<String, dynamic>{
              'model': 'jev-test',
              'answers': <String, dynamic>{
                for (final String k in q.keys)
                  k: <String, dynamic>{
                    'type': 'score',
                    'score': (indexOf(k) % 5).toDouble(),
                    'confidence': 0.7,
                  },
              },
            }),
            200,
          );
        }),
      );
      final ZhaojianJevOracle o =
          ZhaojianJevOracle(readKey: () async => 'test-key', jev: jev);
      final ZScoreResult r =
          await o.scoreMotives(situation: '他开口借钱', motives: motives(30));

      expect(r.isEmpty, isFalse);
      expect(r.source, ZhaojianJevOracle.sourceNote);
      expect(r.pulls.length, 30);
      expect(r.pulls[7], closeTo(2.0, 1e-9), reason: '分数 2/4 再乘回 4');
      expect(r.confidences[7], closeTo(0.7, 1e-9));
      expect(seen.length, 3, reason: '12 + 12 + 6');
      expect(seen.every((http.Request q) => questionsOf(q).length <= 12), isTrue);
      expect(seen.first.url.toString(), 'https://api.typesafe.ai/v1/systemone');
      expect(seen.first.headers['Authorization'], 'Bearer test-key');

      final Map<String, dynamic> body =
          jsonDecode(seen.first.body) as Map<String, dynamic>;
      expect(body['model'], ZhaojianJevOracle.model);
      final Map<String, dynamic> first =
          questionsOf(seen.first).values.first as Map<String, dynamic>;
      expect(first['type'], 'score');
      expect((first['criteria'] as List<dynamic>).length, 5);
      expect((first['instructions'] as String).contains('动机0'), isTrue);
    });

    test('does nothing without a key', () async {
      int calls = 0;
      final ZhaojianJevOracle o = ZhaojianJevOracle(
        readKey: () async => '  ',
        jev: EvidenceGrowthJev(
          client: MockClient((http.Request req) async {
            calls += 1;
            return http.Response('{}', 200);
          }),
        ),
      );
      expect((await o.scoreMotives(situation: 's', motives: motives(5))).isEmpty, isTrue);
      expect(calls, 0);
    });

    test('a failing endpoint yields empty results', () async {
      final ZhaojianJevOracle o = ZhaojianJevOracle(
        readKey: () async => 'k',
        jev: EvidenceGrowthJev(
          client: MockClient((http.Request req) async => http.Response('{}', 503)),
        ),
      );
      expect((await o.scoreMotives(situation: 's', motives: motives(5))).isEmpty, isTrue);
    });

    test('fewer than half of the motives scored counts as unavailable', () async {
      final ZhaojianJevOracle o = ZhaojianJevOracle(
        readKey: () async => 'k',
        jev: EvidenceGrowthJev(
          client: MockClient((http.Request req) async {
            final Map<String, dynamic> q = questionsOf(req);
            return http.Response(
              jsonEncode(<String, dynamic>{
                'answers': <String, dynamic>{
                  for (final String k in q.keys)
                    if (indexOf(k) < 4)
                      k: <String, dynamic>{
                        'type': 'score',
                        'score': 3.0,
                        'confidence': 0.5,
                      },
                },
              }),
              200,
            );
          }),
        ),
      );
      expect((await o.scoreMotives(situation: 's', motives: motives(10))).isEmpty, isTrue);
    });

    test('invalid answers are skipped but the valid ones are kept', () async {
      final ZhaojianJevOracle o = ZhaojianJevOracle(
        readKey: () async => 'k',
        jev: EvidenceGrowthJev(
          client: MockClient((http.Request req) async {
            final Map<String, dynamic> q = questionsOf(req);
            return http.Response(
              jsonEncode(<String, dynamic>{
                'answers': <String, dynamic>{
                  for (final String k in q.keys)
                    k: indexOf(k) == 0
                        ? <String, dynamic>{'type': 'noul', 'noul': 0.5}
                        : <String, dynamic>{
                            'type': 'score',
                            'score': 4.0,
                            'confidence': 0.9,
                          },
                },
              }),
              200,
            );
          }),
        ),
      );
      final ZScoreResult r =
          await o.scoreMotives(situation: 's', motives: motives(6));
      expect(r.isEmpty, isFalse);
      expect(r.pulls.containsKey(0), isFalse);
      expect(r.pulls[3], 4.0);
    });

    test('JEV does not generate text and is declared as sending data', () async {
      final ZhaojianJevOracle o = ZhaojianJevOracle(readKey: () async => '');
      expect(
        await o.completeMotives(question: 'q', optionA: 'a', optionB: 'b', profile: ''),
        isEmpty,
      );
      expect(o.sendsData, isTrue);
    });
  });

  group('ZhaojianJevOracle alignment', () {
    test('asks one score question per desire, option and horizon and rebuilds the rows', () async {
      final List<http.Request> seen = <http.Request>[];
      final EvidenceGrowthJev jev = EvidenceGrowthJev(
        client: MockClient((http.Request req) async {
          seen.add(req);
          final Map<String, dynamic> q = questionsOf(req);
          return http.Response(
            jsonEncode(<String, dynamic>{
              'answers': <String, dynamic>{
                for (final String k in q.keys)
                  k: <String, dynamic>{
                    'type': 'score',
                    // 原始分 0..4：选项 a 得 3 分，选项 b 得 1 分（客户端会除以 4 归一）。
                    'score': k.contains('a0a') || k.contains('a1a') ? 3.0 : 1.0,
                    'confidence': 0.6,
                  },
              },
            }),
            200,
          );
        }),
      );
      final ZhaojianJevOracle o = ZhaojianJevOracle(readKey: () async => 'k', jev: jev);
      final ZAlignResult r = await o.scoreAlignment(
        situation: '他开口借钱',
        optionA: '借',
        optionB: '不借',
        desires: const <ZDesire>[ZDesire('自由', strong: true), ZDesire('被认可')],
      );
      final int total = seen.fold(0, (int a, http.Request q) => a + questionsOf(q).length);
      expect(total, 12, reason: '2 个欲求 × 2 个选项 × 3 个尺度');
      expect(seen.length, 1);
      expect(r.isEmpty, isFalse);
      expect(r.rows.length, 2);
      expect(r.rows[0].a, <int>[75, 75, 75]);
      expect(r.rows[0].b, <int>[25, 25, 25]);
      expect(r.confidence, closeTo(0.6, 1e-9));
      expect(r.source, ZhaojianJevOracle.sourceNote);
      expect(r.diffA.tier, '', reason: 'JEV 给不了文字：难度留空，由文字引擎补');
    });

    test('a desire with missing scores makes the whole result empty', () async {
      final ZhaojianJevOracle o = ZhaojianJevOracle(
        readKey: () async => 'k',
        jev: EvidenceGrowthJev(
          client: MockClient((http.Request req) async {
            final Map<String, dynamic> q = questionsOf(req);
            return http.Response(
              jsonEncode(<String, dynamic>{
                'answers': <String, dynamic>{
                  for (final String k in q.keys)
                    if (!k.endsWith('b2')) k: <String, dynamic>{'type': 'score', 'score': 0.5, 'confidence': 0.5},
                },
              }),
              200,
            );
          }),
        ),
      );
      expect(
        (await o.scoreAlignment(situation: 's', optionA: 'a', optionB: 'b', desires: const <ZDesire>[ZDesire('x')])).isEmpty,
        isTrue,
      );
    });

    test('no key or no desires means empty and no request', () async {
      int calls = 0;
      final EvidenceGrowthJev jev = EvidenceGrowthJev(
        client: MockClient((http.Request req) async {
          calls += 1;
          return http.Response('{}', 200);
        }),
      );
      expect((await ZhaojianJevOracle(readKey: () async => '', jev: jev).scoreAlignment(situation: 's', optionA: 'a', optionB: 'b', desires: const <ZDesire>[ZDesire('x')])).isEmpty, isTrue);
      expect((await ZhaojianJevOracle(readKey: () async => 'k', jev: jev).scoreAlignment(situation: 's', optionA: 'a', optionB: 'b', desires: const <ZDesire>[])).isEmpty, isTrue);
      expect(calls, 0);
    });
  });

  group('ZhaojianHostOracle', () {
    const ZScoreResult good = ZScoreResult(
      pulls: <int, double>{0: 3.0},
      source: 'good',
    );
    const ZScoreResult other = ZScoreResult(
      pulls: <int, double>{0: 1.0},
      source: 'other',
    );

    test('prefers the scorer and does not touch the text engine', () async {
      final _Fake text = _Fake(other);
      final ZhaojianHostOracle o =
          ZhaojianHostOracle(text: text, scorer: _Fake(good));
      final ZScoreResult r =
          await o.scoreMotives(situation: 's', motives: motives(1));
      expect(r.source, 'good');
      expect(text.scoreCalls, 0);
    });

    test('falls back to the text engine when the scorer is empty or throws', () async {
      final ZhaojianHostOracle empty = ZhaojianHostOracle(
        text: _Fake(other),
        scorer: _Fake(const ZScoreResult()),
      );
      expect((await empty.scoreMotives(situation: 's', motives: motives(1))).source, 'other');

      final ZhaojianHostOracle thrown = ZhaojianHostOracle(
        text: _Fake(other),
        scorer: _Fake(good, throws: true),
      );
      expect((await thrown.scoreMotives(situation: 's', motives: motives(1))).source, 'other');
    });

    test('motive completion comes from the text engine and data sending is declared', () async {
      final ZhaojianHostOracle o =
          ZhaojianHostOracle(text: _Fake(other), scorer: _Fake(good));
      final List<ZMotive> ms =
          await o.completeMotives(question: 'q', optionA: 'a', optionB: 'b', profile: '');
      expect(ms.single.text, 'from-text');
      expect(o.sendsData, isTrue);
    });
  });

  group('ZhaojianHostOracle chains', () {
    const ZScoreResult real = ZScoreResult(pulls: <int, double>{0: 2.0}, source: 'real');
    const ZScoreResult alt = ZScoreResult(pulls: <int, double>{0: 1.0}, source: 'alt');

    test('tries the extra scorers in order after the first one comes back empty', () async {
      final _Fake second = _Fake(alt);
      final _Fake text = _Fake(const ZScoreResult(pulls: <int, double>{0: 3.0}, source: 'text'));
      final ZhaojianHostOracle o = ZhaojianHostOracle(
        text: text,
        scorer: _Fake(const ZScoreResult()),
        extraScorers: <ZhaojianOracle>[second],
      );
      final ZScoreResult r = await o.scoreMotives(situation: 's', motives: motives(1));
      expect(r.source, 'alt');
      expect(text.scoreCalls, 0);
    });

    test('alignment keeps the real scores and takes difficulty and reasons from the text engine', () async {
      final _AlignFake realEngine = _AlignFake(const ZAlignResult(
        rows: <ZAlignRow>[ZAlignRow(a: <int>[70, 70, 70], b: <int>[30, 30, 30])],
        confidence: 0.8,
        source: 'JEV',
      ));
      final _AlignFake words = _AlignFake(const ZAlignResult(
        rows: <ZAlignRow>[ZAlignRow(a: <int>[1, 1, 1], b: <int>[2, 2, 2], reasonA: '推进自由', reasonB: '背离')],
        diffA: ZDifficulty(tier: '难', ring: '动机'),
        confidence: 0.4,
        source: 'AI',
      ));
      final ZhaojianHostOracle o = ZhaojianHostOracle(text: words, scorer: realEngine);
      final ZAlignResult r = await o.scoreAlignment(
        situation: 's', optionA: 'a', optionB: 'b', desires: const <ZDesire>[ZDesire('自由')]);
      expect(r.rows.single.a, <int>[70, 70, 70], reason: '分数来自真实引擎');
      expect(r.rows.single.reasonA, '推进自由');
      expect(r.diffA.tier, '难');
      expect(r.confidence, 0.8);
      expect(r.source, contains('JEV'));
      expect(r.source, contains('AI'));
    });

    test('alignment falls back to whichever side is available', () async {
      const ZAlignResult only = ZAlignResult(
        rows: <ZAlignRow>[ZAlignRow(a: <int>[60, 60, 60], b: <int>[40, 40, 40])], source: 'x');
      final ZhaojianHostOracle textOnly = ZhaojianHostOracle(
          text: _AlignFake(only), scorer: _AlignFake(const ZAlignResult()));
      expect((await textOnly.scoreAlignment(situation: 's', optionA: 'a', optionB: 'b', desires: const <ZDesire>[ZDesire('x')])).rows.length, 1);
      final ZhaojianHostOracle realOnly = ZhaojianHostOracle(
          text: _AlignFake(const ZAlignResult()), scorer: _AlignFake(only));
      expect((await realOnly.scoreAlignment(situation: 's', optionA: 'a', optionB: 'b', desires: const <ZDesire>[ZDesire('x')])).rows.length, 1);
      final ZhaojianHostOracle neither = ZhaojianHostOracle(
          text: _AlignFake(const ZAlignResult()), scorer: _AlignFake(const ZAlignResult()));
      expect((await neither.scoreAlignment(situation: 's', optionA: 'a', optionB: 'b', desires: const <ZDesire>[ZDesire('x')])).isEmpty, isTrue);
    });
  });
}

class _AlignFake extends ZhaojianOracle {
  _AlignFake(this.result);

  final ZAlignResult result;

  @override
  String get label => 'align-fake';

  @override
  Future<List<ZMotive>> completeMotives({
    required String question,
    required String optionA,
    required String optionB,
    required String profile,
  }) async =>
      <ZMotive>[];

  @override
  Future<ZScoreResult> scoreMotives({
    required String situation,
    required List<ZMotive> motives,
  }) async =>
      const ZScoreResult();

  @override
  Future<ZAlignResult> scoreAlignment({
    required String situation,
    required String optionA,
    required String optionB,
    required List<ZDesire> desires,
  }) async =>
      result;
}
