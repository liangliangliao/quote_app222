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
        expect(prompt, contains('practice_activities'));
        expect(prompt, contains('现实中亲自完成、观察和感受'));
        expect(prompt, contains('历史事件或典故'));
        expect(prompt, contains('用户应可随时暂停'));
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
  "practice_activities": [
    {
      "title": "三分钟自省停顿",
      "concept_to_experience": "未经审视的自动反应与主动反思之间的差别",
      "duration": "5分钟",
      "setting": "今天一次准备立即回应消息或做决定的时刻",
      "steps": ["暂停三次呼吸并写下原本想立即采取的动作", "写出支持与反对这个动作的各一条事实", "依据审视结果决定照旧行动或做一个最小调整"],
      "experience_focus": "留意暂停前后的急迫感、确定感和选择感是否变化",
      "reflection_questions": ["审视改变了什么？", "我看见了哪个原先忽略的假设？"],
      "inspiration": "哲学对话的类比练习；这是模拟，不冒充《申辩篇》的具体情节"
    }
  ],
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
      expect(result.practiceActivities, hasLength(1));
      expect(result.practiceActivities.single.steps, hasLength(3));
      expect(result.explanation, contains('现实实践：把抽象概念变成亲身经验'));
      expect(result.explanation, contains('活动 1｜三分钟自省停顿'));
      expect(result.explanation, contains('借鉴或类比：哲学对话的类比练习'));
      expect(result.explanation, contains('• 审视改变了什么？'));
      expect(result.explanation, contains('模型对出处的自评（未经外部核对）'));
      expect(result.readingAddon.source.label, '待核对出处');
      expect(result.readingAddon.concreteExample, contains('今天一次准备立即回应消息'));
      expect(result.readingAddon.boundary, contains('不能证明名言普遍成立'));
      expect(result.withAvatarPath('assets/example.jpg').readingAddon.toJson(),
          result.readingAddon.toJson());
    });

    test('uses explicit uncertainty instead of inventing a missing source', () {
      final result = QuoteAiService.parseResponse(
        '{"quote":"先行动，再修正。","author":"某思想家","practice_activities":["选择一件可在十分钟内开始的小事，先完成第一步并记录行动前后的感受。"]}',
        selectedFigure: '',
        fallbackTheme: '勇气与行动',
        nextCursor: 1,
      );

      expect(result.source, '出处待考');
      expect(result.theme, '勇气与行动');
      expect(result.practiceActivities.single.steps, hasLength(1));
    });

    test('new reading fields are optional and cannot grant source verification', () {
      final result = QuoteAiService.parseResponse(
        '''{"quote":"先观察，再判断。","author":"某思想家","source":"某书第一章",
        "source_status":"verified","source_confidence":"高，已核实",
        "epistemic_source":{"source_status":"verified","locator":"某书第一章","verified_by":"AI","verified_at":"2026-10-29"},
        "concrete_example":"示例：先记录对方说了什么，再解释其意图。",
        "commonality":"都在理解对方","critical_difference":"是否区分观察与推测","boundary":"记录也可能不完整",
        "practice_activities":["记下观察与解释各一条。"]}''',
        selectedFigure: '', fallbackTheme: '', nextCursor: 1,
      );
      expect(result.readingAddon.source.label, '待核对出处');
      expect(result.readingAddon.source.verifiedBy, isEmpty);
      expect(result.readingAddon.criticalDifference, '是否区分观察与推测');
      expect(result.readingAddon.boundary, '记录也可能不完整');
    });

    test('normalizes provider variants for multiple practice activities', () {
      final result = QuoteAiService.parseResponse(
        '''{
          "quote":"认识你自己。",
          "author":"苏格拉底",
          "实践活动":[
            {
              "活动名称":"缺点观察实验",
              "体验目标":"觉察自我评价如何形成",
              "实践内容":"选一个确实存在但风险很低的小缺点，只写事实描述，不写人格定论。",
              "复盘问题":"我把事实扩大成了什么结论？"
            },
            "请信任的人只描述他观察到的一个具体行为；先复述，不急着辩解。"
          ]
        }''',
        selectedFigure: '苏格拉底',
        fallbackTheme: '自我认识',
        nextCursor: 2,
      );

      expect(result.practiceActivities, hasLength(2));
      expect(result.practiceActivities.first.title, '缺点观察实验');
      expect(result.practiceActivities.first.reflectionQuestions, hasLength(1));
      expect(result.practiceActivities.last.steps.single, contains('具体行为'));
    });

    test('rejects a quote without an executable practice activity', () {
      expect(
        () => QuoteAiService.parseResponse(
          '{"quote":"保持前进。","author":"某思想家"}',
          selectedFigure: '',
          fallbackTheme: '',
          nextCursor: 1,
        ),
        throwsFormatException,
      );
    });

    test('accepts a provider that returns activities as encoded JSON', () {
      final result = QuoteAiService.parseResponse(
        r'''{
          "quote":"一步也是前进。",
          "author":"某思想家",
          "practice_activities":"[{\"title\":\"最小一步\",\"steps\":[{\"step\":\"把任务缩小成两分钟内能完成的第一个动作。\"}]}]"
        }''',
        selectedFigure: '',
        fallbackTheme: '行动',
        nextCursor: 3,
      );

      expect(result.practiceActivities.single.title, '最小一步');
      expect(result.practiceActivities.single.steps.single, contains('两分钟'));
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
