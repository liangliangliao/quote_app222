import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('quote avatar resolution', () {
    test('maps Chinese author names to packaged portraits', () {
      expect(
        QuoteAvatarAssetResolver.forAuthor('尼采'),
        'assets/avatars/Friedrich Nietzsche.jpg',
      );
      expect(
        QuoteAvatarAssetResolver.forAuthor('——威廉·詹姆斯《心理学原理》'),
        'assets/avatars/250px-William_James_b1842c.jpg',
      );
      expect(QuoteAvatarAssetResolver.forAuthor('不存在的人物'), isEmpty);
      expect(
        QuoteAvatarDownloader.isIdentityVerifiedLocalPath(
          '/data/quote_avatars/quote_avatar_old.jpg',
        ),
        isFalse,
      );
    });

    test(
      'ignores an unverified preferred URL and falls back to the original',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'quote-avatar-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final requested = <Uri>[];
        const thumbnail =
            'https://thumb.wikimedia.org/wikipedia/commons/thumb/nietzsche.jpg';
        const original =
            'https://upload.wikimedia.org/wikipedia/commons/nietzsche.jpg';

        final downloader = QuoteAvatarDownloader(
          clientFactory: () => MockClient((request) async {
            requested.add(request.url);
            if (request.url.host == 'www.wikidata.org') {
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'claims': <String, dynamic>{
                    'P31': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'mainsnak': <String, dynamic>{
                          'datavalue': <String, dynamic>{
                            'value': <String, String>{'id': 'Q5'},
                          },
                        },
                      },
                    ],
                  },
                }),
                200,
                headers: const <String, String>{
                  'content-type': 'application/json',
                },
              );
            }
            if (request.url.path == '/w/api.php') {
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'query': <String, dynamic>{
                    'pages': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'title': '弗里德里希·尼采',
                        'index': 1,
                        'thumbnail': <String, String>{'source': thumbnail},
                        'original': <String, String>{'source': original},
                        'pageprops': <String, String>{
                          'wikibase_item': 'Q9358',
                        },
                      },
                    ],
                  },
                }),
                200,
                headers: const <String, String>{
                  'content-type': 'application/json',
                },
              );
            }
            if (request.url.toString() == thumbnail) {
              return http.Response('missing', 404);
            }
            if (request.url.toString() == original) {
              return http.Response.bytes(
                const <int>[0xff, 0xd8, 0xff, 0xd9],
                200,
                headers: const <String, String>{'content-type': 'image/jpeg'},
              );
            }
            return http.Response(
              '<html>article</html>',
              200,
              headers: const <String, String>{'content-type': 'text/html'},
            );
          }),
          documentsDirectory: () async => directory,
        );

        final result = await downloader.resolveAndDownload(
          author: '尼采',
          searchQuery: '弗里德里希·尼采 Friedrich Nietzsche',
          preferredUrl: 'https://zh.wikipedia.org/wiki/弗里德里希·尼采',
        );

        expect(result, isNotNull);
        expect(result!.sourceUrl, original);
        expect(await File(result.path).readAsBytes(), const <int>[
          0xff,
          0xd8,
          0xff,
          0xd9,
        ]);
        expect(requested.where((uri) => uri.path == '/w/api.php'), isNotEmpty);
        expect(
          requested.any((uri) => uri.queryParameters.containsKey('gsrwhat')),
          isFalse,
        );
        expect(
          requested.any(
            (uri) => uri.toString() == 'https://zh.wikipedia.org/wiki/弗里德里希·尼采',
          ),
          isFalse,
        );
        expect(
          QuoteAvatarDownloader.isIdentityVerifiedLocalPath(result.path),
          isTrue,
        );
      },
    );

    test('rejects buildings and non-human entities before downloading',
        () async {
      final directory = await Directory.systemTemp.createTemp(
        'quote-avatar-identity-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final requested = <Uri>[];
      const building =
          'https://upload.wikimedia.org/wikipedia/commons/auschwitz.jpg';
      const institute =
          'https://upload.wikimedia.org/wikipedia/commons/frankl-institute.jpg';
      const portrait =
          'https://upload.wikimedia.org/wikipedia/commons/Viktor_Frankl2.jpg';

      final downloader = QuoteAvatarDownloader(
        clientFactory: () => MockClient((request) async {
          requested.add(request.url);
          if (request.url.host == 'www.wikidata.org') {
            final entity = request.url.queryParameters['entity'];
            return http.Response(
              jsonEncode(<String, dynamic>{
                'claims': <String, dynamic>{
                  'P31': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'mainsnak': <String, dynamic>{
                        'datavalue': <String, dynamic>{
                          'value': <String, String>{
                            'id': entity == 'Q154723' ? 'Q5' : 'Q43229',
                          },
                        },
                      },
                    },
                  ],
                },
              }),
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }
          if (request.url.path == '/w/api.php') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'query': <String, dynamic>{
                  // MediaWiki does not guarantee this JSON list is already in
                  // search-rank order. The old implementation picked Auschwitz.
                  'pages': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'title': '奥斯威辛集中营',
                      'index': 3,
                      'original': <String, String>{'source': building},
                      'pageprops': <String, String>{'wikibase_item': 'Q7341'},
                    },
                    <String, dynamic>{
                      'title': 'Viktor Frankl',
                      'index': 0,
                      'original': <String, String>{'source': institute},
                      'pageprops': <String, String>{
                        'wikibase_item': 'Q999999',
                      },
                    },
                    <String, dynamic>{
                      'title': '维克多·弗兰克',
                      'index': 1,
                      'original': <String, String>{'source': portrait},
                      'pageprops': <String, String>{
                        'wikibase_item': 'Q154723',
                      },
                    },
                  ],
                },
              }),
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }
          if (request.url.toString() == portrait) {
            return http.Response.bytes(
              const <int>[0xff, 0xd8, 0xff, 0xd9],
              200,
              headers: const <String, String>{'content-type': 'image/jpeg'},
            );
          }
          return http.Response('wrong image', 200, headers: const {
            'content-type': 'image/jpeg',
          });
        }),
        documentsDirectory: () async => directory,
      );

      final result = await downloader.resolveAndDownload(
        author: '维克多·弗兰克尔',
        searchQuery: '维克多·弗兰克尔 Viktor Frankl',
        preferredUrl: building,
      );

      expect(result, isNotNull);
      expect(result!.sourceUrl, portrait);
      expect(requested, isNot(contains(Uri.parse(building))));
      expect(requested, isNot(contains(Uri.parse(institute))));
      expect(requested, contains(Uri.parse(portrait)));
    });
  });
}
