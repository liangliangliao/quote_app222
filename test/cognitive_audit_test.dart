import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/concept_analysis.dart';
import 'package:quote_app/epistemic/history_timeline.dart';
import 'package:quote_app/epistemic/philosophy_benchmark.dart';
import 'package:quote_app/epistemic/reading_map_quality.dart';
import 'package:quote_app/epistemic/schopenhauer_guidance.dart';
import 'package:quote_app/epistemic/semantic_contract.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/services/ai_request_accounting.dart';
import 'package:quote_app/services/ai_request_audit.dart';
import 'package:quote_app/services/global_ai_request_settings.dart';

Map<String, dynamic> circle(String type) {
  final map = <String, dynamic>{
    'relation_type': type,
    'relation_scope': 'extension',
    'universe': '欧氏平面四边形',
    'set_a': '正方形',
    'set_b': '长方形',
    'criterion_a': '四边相等且四角为直角',
    'criterion_b': '四角为直角',
    'basis': '正方形是长方形的一种',
    'justification': '按定义检查成员，结构可表达不等于原句已获客观证明',
    'intersection': '',
    'only_a': '',
    'only_b': '',
    'other_member': '',
    'illustration': false,
  };
  switch (type) {
    case 'equal':
      map.addAll({'set_b': '四边相等的长方形', 'intersection': '边长1的正方形'});
    case 'subset':
      map.addAll({'intersection': '边长1的正方形', 'only_b': '边长2和3的长方形'});
    case 'superset':
      map.addAll({
        'set_a': '长方形',
        'set_b': '正方形',
        'intersection': '边长1的正方形',
        'only_a': '边长2和3的长方形'
      });
    case 'partition':
      map.addAll({
        'parts': [
          {'term': '长方形', 'criterion': '四角为直角', 'example': '边长2和3的长方形'},
          {'term': '非长方形四边形', 'criterion': '至少一角非直角', 'example': '无直角梯形'},
        ]
      });
    case 'overlap':
      map.addAll({
        'universe': '有色平面图形',
        'set_a': '红色图形',
        'set_b': '正方形',
        'intersection': '红色正方形',
        'only_a': '红色三角形',
        'only_b': '蓝色正方形'
      });
    case 'siblings':
      map.addAll({
        'set_a': '正方形',
        'set_b': '非正方形长方形',
        'only_a': '边长1的正方形',
        'only_b': '边长2和3的长方形',
        'other_member': '无直角梯形'
      });
  }
  return map;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('90000 is a ceiling with no hidden 64000 floor or replacement', () {
    const config = GlobalAiRequestConfig(
        timeoutSeconds: null,
        maxOutputTokens: 90000,
        temperature: null,
        topP: null,
        retryCount: null,
        retryDelayMs: null);
    expect(config.resolveMaxTokens(1800), 1800);
    expect(config.resolveMaxTokens(10000), 10000);
    expect(config.resolveMaxTokens(90000), 90000);
    expect(config.resolveMaxTokens(120000), 90000);
    expect(
        AiOutputBudget.resolve(10000, global: 90000, modelLimit: 6000)
            .effective,
        6000);
    expect(AiOutputBudget.resolve(10000, global: 16).effective, 16);
    expect(AiOutputBudget.resolve(10000, global: 90000).modelLimit, isNull);
  });
  test('usage keeps reasoning and cache as subsets, cumulative SSE once', () {
    final payload = {
      'usage': {
        'prompt_tokens': 21,
        'completion_tokens': 4,
        'prompt_tokens_details': {'cached_tokens': 10},
        'completion_tokens_details': {'reasoning_tokens': 2}
      }
    };
    final usage = AiTokenUsage.parse(
        'data: ${jsonEncode(payload)}\n\ndata: ${jsonEncode(payload)}\n\ndata: [DONE]\n');
    expect(usage.total, 25);
    expect(usage.input, 21);
    expect(usage.output, 4);
    expect(usage.cachedInput, 10);
    expect(usage.reasoning, 2);
    expect(AiTokenUsage.parse('{}').total, isNull);
  });
  test('Responses and Anthropic usage preserve unknown fields', () {
    final responses = AiTokenUsage.fromEnvelope({
      'response': {
        'usage': {
          'input_tokens': 30,
          'output_tokens': 12,
          'output_tokens_details': {'reasoning_tokens': 8}
        }
      }
    });
    expect(responses.total, 42);
    expect(responses.reasoning, 8);
    final anthropic = AiTokenUsage.fromEnvelope({
      'message': {
        'usage': {'input_tokens': 9}
      }
    }).merge(AiTokenUsage.fromEnvelope({
      'usage': {'output_tokens': 5}
    }));
    expect(anthropic.total, 14);
    final cached = AiTokenUsage.fromEnvelope({
      'usage': {
        'input_tokens': 9,
        'output_tokens': 6,
        'cache_read_input_tokens': 10,
        'cache_creation_input_tokens': 5
      }
    });
    expect(cached.input, 24);
    expect(cached.total, 30);
    expect(cached.cachedInput, 10);
    expect(
        AiTokenUsage.fromEnvelope({
          'usage': {'output_tokens': 0}
        }).total,
        isNull);
  });
  for (final type in [
    'equal',
    'subset',
    'superset',
    'partition',
    'overlap',
    'siblings'
  ]) {
    test('$type shared contract: adequate, missing and contradictory regions',
        () {
      final valid = circle(type);
      expect(MeaningCircleContract.gaps(valid), isEmpty);
      expect(ConceptScope.parse(valid, '正方形是长方形的一种'), isNotNull);
      final unknown = {...valid}..remove('universe');
      expect(MeaningCircleContract.gaps(unknown), isNotEmpty);
      expect(ConceptScope.parse(unknown, '正方形是长方形的一种'), isNull);
      final invalid = {...valid};
      if (type == 'partition') {
        invalid['parts'] = [
          {'term': '重复', 'criterion': 'C', 'example': 'E'},
          {'term': '重复', 'criterion': 'C', 'example': 'E'}
        ];
      } else if (type == 'equal' || type == 'subset') {
        invalid['only_a'] = '声称不存在的区域却填了成员';
      } else if (type == 'superset') {
        invalid['only_b'] = '声称不存在的区域却填了成员';
      } else if (type == 'siblings') {
        invalid['intersection'] = '声称互斥却填了共同成员';
      } else {
        invalid['intersection'] = '';
      }
      expect(MeaningCircleContract.gaps(invalid), isNotEmpty);
    });
  }
  test('negation and strengthened modalities are not promoted by an excerpt',
      () {
    final weak = PropositionConsistency.check('所有失败必然导致成长', '失败并不必然阻碍成长');
    expect(weak.status, VerificationStatus.unknown);
    expect(weak.reason, contains('强化'));
    expect(PropositionConsistency.check('这次观察足以证明因果', '这次观察不足以证明因果').status,
        VerificationStatus.contradicted);
    expect(PropositionConsistency.check('这个图形不是正方形', '这个图形是正方形').status,
        VerificationStatus.contradicted);
    final literal = PropositionConsistency.check('今天买了一本书', '今天买了一本书');
    expect(literal.status, VerificationStatus.supported);
    expect(literal.reason, contains('不证明'));
    expect(PropositionConsistency.check('旅行导致幸福', '旅行之后感到幸福').status,
        VerificationStatus.unknown);
    expect(
        PropositionConsistency.check(
                'Travel causes happiness.', 'Travel causes happiness?')
            .status,
        VerificationStatus.unknown);
  });
  test('short formal construction needs no four-level story or extra circles',
      () {
    const source = ScopeSource('A', '正方形是长方形的一种');
    final scope = SemanticScope.parse({
      'schema_version': 3,
      'concepts': [
        {
          'id': 'square',
          'label': '正方形',
          'definition': '四边相等且四角为直角',
          'kind': 'concept',
          'status': 'definition',
          'references': [
            {'source': 'A', 'excerpt': source.text}
          ]
        },
        {
          'id': 'construct',
          'label': '画边长1的正方形',
          'definition': '依定义构造四条单位边和四个直角',
          'kind': 'formal',
          'status': 'definition',
          'references': [
            {'source': 'A', 'excerpt': source.text}
          ]
        },
      ],
      'hierarchy': [
        {
          'parent': 'square',
          'child': 'construct',
          'kind': 'grounding',
          'explanation': '按定义构造空间图形',
          'references': [
            {'source': 'A', 'excerpt': source.text}
          ]
        }
      ]
    }, [
      source
    ]);
    expect(ReadingMapQuality.depth(scope), 2);
    expect(ReadingMapQuality.issues(scope), isEmpty);
    expect(scope.needsRepair, isFalse);
    expect(scope.relations, isEmpty);
  });
  test('compact reference IDs expand locally and reject invented evidence', () {
    final raw = <String, dynamic>{
      'schema_version': 3,
      'evidence': [
        {'id': 'e1', 'source': 'A', 'excerpt': '正方形是长方形的一种'}
      ],
      'concepts': [
        {
          'id': 'c1',
          'label': '正方形',
          'definition': '四边相等且四角为直角',
          'kind': 'concept',
          'status': 'definition',
          'references': ['e1']
        }
      ],
      'propositions': [
        {
          'id': 'p1',
          'subject': '正方形',
          'predicate': '是长方形的一种',
          'quantifier': '全称',
          'polarity': '肯定',
          'condition': '',
          'modality': '依定义',
          'conclusion': '正方形是长方形的一种',
          'evidence_ref': 'e1',
          'origin': 'definition'
        }
      ]
    };
    final value =
        SemanticScope.parse(raw, const [ScopeSource('A', '正方形是长方形的一种')]);
    expect(value.concepts.single.references.single.excerpt, '正方形是长方形的一种');
    expect(value.propositions.single.verification.status,
        VerificationStatus.supported);
    (raw['evidence'] as List).first['excerpt'] = '不存在的证据';
    expect(
        () => SemanticScope.parse(raw, const [ScopeSource('A', '正方形是长方形的一种')]),
        throwsFormatException);
  });
  test('v3 relations reuse canonical definitions and isolate changed meanings',
      () {
    final refs = [
      {'source': 'A', 'excerpt': '正方形是长方形的一种'}
    ];
    final raw = <String, dynamic>{
      'schema_version': 3,
      'material_kind': 'definition',
      'concepts': [
        {
          'id': 'a',
          'label': '正方形',
          'definition': '四边相等且四角为直角',
          'kind': 'concept',
          'status': 'definition',
          'references': refs
        },
        {
          'id': 'b',
          'label': '长方形',
          'definition': '四角为直角的四边形',
          'kind': 'concept',
          'status': 'definition',
          'references': refs
        }
      ],
      'relations': [
        {
          'placement': 'A',
          'statement': '按定义比较',
          'status': 'definition',
          'references': refs,
          'node_ids': ['a', 'b'],
          'scope': {
            'relation_type': 'subset',
            'relation_scope': 'extension',
            'universe': '欧氏平面四边形',
            'basis': '正方形是长方形的一种',
            'justification': '按给定定义',
            'intersection': '单位正方形',
            'only_b': '边长2和3的长方形'
          }
        }
      ]
    };
    final value =
        SemanticScope.parse(raw, const [ScopeSource('A', '正方形是长方形的一种')]);
    expect(value.relations.single.scope!.criterionA,
        value.concepts.first.definition);
    (raw['relations'] as List).first['scope']['criterion_a'] = '偷偷改成三角形';
    final changed =
        SemanticScope.parse(raw, const [ScopeSource('A', '正方形是长方形的一种')]);
    expect(changed.relations, isEmpty);
    expect(changed.needsRepair, isTrue);
  });
  test(
      'source version survives parse/serialize without upgrading old verification',
      () {
    final old = SemanticScope.parse({
      'schema_version': 1,
      'concepts': [
        {
          'id': 'x',
          'label': '定义',
          'definition': '规定',
          'kind': 'concept',
          'status': 'definition',
          'references': [
            {'source': 'A', 'excerpt': '原句'}
          ]
        }
      ]
    }, const [
      ScopeSource('A', '原句')
    ]);
    expect(old.legacy, isTrue);
    expect(
        SemanticScope.parse(old.toJson(), const [ScopeSource('A', '原句')])
            .legacy,
        isTrue);
  });
  test('one chronological direction and distinct duplicate-content instances',
      () {
    final rows = [
      {
        'id': 3,
        'quote_uid': 'b',
        'content': '同一句',
        'inserted_at': '2026-11-03 09:00:00'
      },
      {
        'id': 1,
        'quote_uid': 'a',
        'content': '同一句',
        'inserted_at': '2026-11-02 09:00:00'
      },
      {'id': 4, 'quote_uid': 'd', 'content': '未标时间'},
      {
        'id': 2,
        'quote_uid': 'c',
        'content': '第三句',
        'inserted_at': '2026-11-03 09:00:00'
      },
    ];
    final entries = groupTimelineRows(rows).expand((g) => g.entries).toList();
    expect(entries.map((e) => e.row['id']), [1, 3, 2, 4]);
    expect(entries[0].quote.contentKey, entries[1].quote.contentKey);
    expect(entries[0].instanceId, isNot(entries[1].instanceId));
    expect(
        groupTimelineRows(rows.reversed.toList())
            .expand((g) => g.entries)
            .map((e) => e.row['id']),
        [1, 3, 2, 4]);
  });
  test('shared instructions are deduplicated; deep style is optional', () {
    final off = SchopenhauerGuidance.forPurpose(
        'quote_ai.generate', SchopenhauerGuidance.core,
        deep: false)!;
    expect(off, contains(SchopenhauerGuidance.basic));
    expect(off, isNot(contains(SchopenhauerGuidance.core)));
    final on = SchopenhauerGuidance.forPurpose(
        'cognition.semantic.v4', SchopenhauerGuidance.core)!;
    expect(on.split(SchopenhauerGuidance.core).length, 2);
  });
  test('pending human review cannot pass; six completed dimensions required',
      () {
    final run = <String, dynamic>{
      'generation_status': 'received',
      'review': {}
    };
    expect(PhilosophyBenchmarkService.reviewStatus(run), 'pending');
    run['review'] = {
      for (final dimension in philosophyReviewDimensions) dimension: 'pass'
    };
    expect(PhilosophyBenchmarkService.reviewStatus(run), 'passed');
    (run['review'] as Map)[philosophyReviewDimensions.first] = 'issue';
    expect(PhilosophyBenchmarkService.reviewStatus(run), 'issues');
    expect(philosophyCases.length, 7);
    expect(philosophyCases.last.id, 'G');
  });
  test('concurrent operations retain independent audit scopes', () async {
    final a = AiOperation('a'), b = AiOperation('b');
    await Future.wait([
      AiRequestAudit.runOperation(a, () async {
        await Future<void>.delayed(Duration.zero);
        expect(AiRequestAudit.current, same(a));
      }),
      AiRequestAudit.runOperation(b, () async {
        await Future<void>.delayed(Duration.zero);
        expect(AiRequestAudit.current, same(b));
      }),
    ]);
    expect(AiRequestAudit.current, isNull);
  });
  test('a simple reported event needs no invented concepts or examples', () {
    final raw = {
      'schema_version': 3,
      'material_kind': 'fact',
      'propositions': [
        {
          'id': 'event',
          'subject': '我',
          'predicate': '买了一本书',
          'quantifier': '个别',
          'polarity': '肯定',
          'condition': '',
          'modality': '用户报告',
          'origin': 'text_claim',
          'evidence': '今天下午买了一本书',
          'conclusion': '今天下午买了一本书'
        }
      ]
    };
    final value = SemanticScope.parse(
        raw, const [ScopeSource('A', '今天下午买了一本书', origin: 'user_report')]);
    expect(value.hasContent, isTrue);
    expect(value.concepts, isEmpty);
    expect(value.availableViews, contains(EpistemicViewKind.judgment));
    expect(ReadingMapQuality.issues(value), isEmpty);
  });
}
