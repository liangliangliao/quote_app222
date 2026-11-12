import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/ground_coverage.dart';
import 'package:quote_app/epistemic/reading_map_quality.dart';
import 'package:quote_app/epistemic/schopenhauer_guidance.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';

import 'fixtures/purposeful_case.dart';

const _camus = '在隆冬之中，我终于在自己内心发现了一个不可战胜的夏天。';

Map<String, dynamic> _concept(String id, String label, String definition,
        {String ref = 'e1'}) =>
    {
      'id': id,
      'label': label,
      'definition': definition,
      'selection_reason': '原句所谈',
      'role': 'core',
      'kind': 'concept',
      'status': 'interpretation',
      'universe': '人的能力',
      'references': [ref],
    };

Map<String, dynamic> _edge(String parent, String child) => {
      'parent': parent,
      'child': child,
      'kind': 'subtype',
      'explanation': '限定',
      'differentia': '特指困难情境下',
      'basis_kind': 'analytic_definition',
      'references': ['e1'],
    };

// The reading that was seen on a phone: two unconnected two-step chains made of
// abstract near-synonyms, and a conclusion that stops at "literal or figurative".
Map<String, dynamic> _stalledMap(
        {bool disclaimer = true, bool evidenceRef = true}) =>
    {
      'schema_version': 6,
      'analysis_purpose': '理解名言的核心概念及其与生活经验的关系',
      'selection_strategy': '选取心理能力与自我认识',
      'material_kind': 'metaphor',
      'evidence': [
        {'id': 'e1', 'source': 'A', 'excerpt': '我终于在自己内心发现了一个不可战胜的夏天'}
      ],
      'concepts': [
        _concept('c1', '心理能力', '人的心理方面的能力'),
        _concept('c2', '逆境中的韧性能力', '困难情境下的韧性'),
        _concept('c3', '自我认识活动', '认识自己'),
        _concept('c4', '在困难中识认自身韧性的活动', '在困难中认识自己的韧性'),
      ],
      'hierarchy': [_edge('c1', 'c2'), _edge('c3', 'c4')],
      'propositions': [
        {
          'id': 'p1',
          'subject': '说话者',
          'predicate': '发现了夏天',
          'quantifier': '',
          'polarity': 'positive',
          'condition': '',
          'modality': 'assertion',
          'conclusion': disclaimer
              ? '说话者称自己终于在内心发现了一个不可战胜的夏天；原句未说明这是字面季节还是隐喻。'
              : '说话者在最艰难的处境里发现了不可摧毁的内在生机。',
          if (evidenceRef) 'evidence_ref': 'e1',
          'origin': 'A',
        }
      ],
    };

SemanticScope _stalled({bool disclaimer = true}) => SemanticScope.parse(
    _stalledMap(disclaimer: disclaimer), [const ScopeSource('A', _camus)]);

void main() {
  test('a stalled reading of a metaphor is sent back for a positive reading', () {
    final issues = ReadingMapQuality.structureIssues(_stalled(),
        requestedViews: const ['hierarchy', 'circles']);
    final byPath = {for (final i in issues) i.path: i};
    expect(byPath['reading.metaphor_disclaimer']?.retryable, isTrue);
    expect(byPath['reading.metaphor_disclaimer']!.message, contains('正面读法'));
    expect(byPath['reading.metaphor_mapping']?.retryable, isTrue);
    expect(byPath['reading.metaphor_mapping']!.message, contains('隆冬'));
    expect(byPath['reading.fragmented_tree']?.retryable, isTrue);
    expect(byPath['reading.fragmented_tree']!.message, contains('2段'));
  });

  test('without a stalled conclusion the missing imagery is only advice', () {
    final issues = ReadingMapQuality.structureIssues(_stalled(disclaimer: false),
        requestedViews: const ['hierarchy']);
    final mapping = issues.singleWhere((i) => i.path == 'reading.metaphor_mapping');
    expect(mapping.retryable, isFalse);
    expect(issues.any((i) => i.path == 'reading.metaphor_disclaimer'), isFalse);
  });

  test('a map with a substantial tree is not called fragmented', () {
    final good = SemanticScope.parse(purposefulCase(),
        [const ScopeSource('A', camusPassage)]);
    final issues = ReadingMapQuality.structureIssues(good,
        requestedViews: const ['hierarchy', 'circles']);
    expect(issues.where((i) => i.retryable), isEmpty);
    expect(issues.any((i) => i.path == 'reading.fragmented_tree'), isFalse);
  });

  test('structure checks stay silent when no view was requested', () {
    expect(ReadingMapQuality.issues(_stalled()).any((i) => i.path.startsWith('reading.metaphor')), isFalse);
  });

  group('references are repaired locally instead of dropping the connection',
      () {
    final sources = [const ScopeSource('A', camusPassage)];
    Map<String, dynamic> damaged(void Function(Map<String, dynamic>) edit) {
      final map =
          jsonDecode(jsonEncode(purposefulCase())) as Map<String, dynamic>;
      edit(map);
      return map;
    }

    test('relations that cite only the sentence keep their circles', () {
      final map = damaged((m) {
        for (final r in m['relations'] as List) {
          (r as Map)['references'] = ['q'];
        }
      });
      final value = SemanticScope.parse(map, sources);
      expect(value.relations.length, 3);
      expect(value.issues, isEmpty);
    });

    test('a wrong excerpt is still rejected', () {
      final map = damaged((m) {
        ((m['relations'] as List).first as Map)['references'] = [
          {'source': 'A', 'excerpt': '原句里没有的话'}
        ];
      });
      final value = SemanticScope.parse(map, sources);
      expect(value.relations.length, 2);
      expect(value.issues.single.message, contains('不符'));
    });

    test('a link between two materials keeps both sides located', () {
      final value = SemanticScope.parse({
        'schema_version': 6,
        'analysis_purpose': '比较两则材料中的认真',
        'selection_strategy': '各取一个核心概念',
        'material_kind': 'argument',
        'evidence': [
          {'id': 'e1', 'source': 'A', 'excerpt': '成年人的成熟'},
          {'id': 'e2', 'source': 'B', 'excerpt': '全神贯注'},
        ],
        'concepts': [
          _concept('a1', '成年人的成熟', '成年人身上的成熟状态', ref: 'e1'),
          _concept('b1', '孩子的专注', '孩子玩耍时的全神贯注', ref: 'e2'),
        ],
        'meaning_links': [
          {
            'from': 'a1',
            'to': 'b1',
            'kind': 'analogy',
            'explanation': '成熟中的认真与游戏中的专注相似',
            'status': 'interpretation',
            'references': ['e1'],
          }
        ],
      }, [
        const ScopeSource('A', '成年人的成熟，就是找回孩提时玩耍所具有的认真。'),
        const ScopeSource('B', '孩子玩耍时全神贯注。'),
      ]);
      expect(value.meaningLinks.length, 1);
      expect(value.issues, isEmpty);
    });

    test('with one sentence, a proposition without a locator is kept and flagged',
        () {
      final value = SemanticScope.parse(_stalledMap(evidenceRef: false),
          [const ScopeSource('A', _camus)]);
      expect(value.propositions.length, 1);
      final note = value.issues
          .singleWhere((i) => i.path == 'propositions[0].evidence');
      expect(note.retryable, isFalse);
      expect(note.message, contains('整句'));
    });
  });

  group('a circle is not discarded for a formal slip', () {
    const quote = '在隆冬之中，我终于在自己内心发现了一个不可战胜的夏天。';
    const excerpt = '我终于在自己内心发现了一个不可战胜的夏天';
    Map<String, dynamic> node(String id, String label, String definition,
            {String universe = '人的经历'}) =>
        _concept(id, label, definition)..['universe'] = universe;
    Map<String, dynamic> data(
        void Function(Map<String, dynamic> scope, Map<String, dynamic> map)
            edit) {
      final map = {
        'schema_version': 6,
        'analysis_purpose': '理解名言',
        'selection_strategy': '取处境与力量',
        'material_kind': 'metaphor',
        'evidence': [
          {'id': 'e1', 'source': 'A', 'excerpt': excerpt}
        ],
        'concepts': [
          node('c1', '艰难处境', '人所处的艰难、受压的状态'),
          node('c2', '内在力量', '人在内心体验到的、未被击垮的力量'),
        ],
        'relations': [
          {
            'placement': 'A',
            'statement': '在分析性定义下，艰难处境与内在力量可以在同一段经历中并存',
            'status': 'definition',
            'outcome': 'drawable',
            'node_ids': ['c1', 'c2'],
            'references': ['e1'],
            'scope': {
              'relation_type': 'overlap',
              'relation_scope': 'extension',
              'universe': '人的经历',
              'basis_kind': 'analytic_definition',
              'basis_ref': 'e1',
              'justification': '依所列定义核对',
              'intersection': '在艰难中仍感到内在力量的经历',
              'only_a': '只有艰难、感到被击垮的经历',
              'only_b': '顺境中感到力量的经历',
              'illustration': false,
            },
          }
        ],
      };
      final copy = jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
      edit(((copy['relations'] as List).first as Map)['scope']
          as Map<String, dynamic>, copy);
      return copy;
    }

    SemanticScope parse(Map<String, dynamic> map) =>
        SemanticScope.parse(map, [const ScopeSource('A', quote)]);

    test('the conforming reply is drawn', () {
      expect(parse(data((s, m) {})).scopeRelations.length, 1);
    });
    test('a different wording of the shared universe', () {
      final v = parse(data((s, m) => s['universe'] = '人的生活经历与体验'));
      expect(v.scopeRelations.length, 1);
      expect(v.issues, isEmpty);
    });
    test('a paraphrased basis is replaced by the located excerpt', () {
      final v = parse(data((s, m) {
        s.remove('basis_ref');
        s['basis'] = '原句把处境与内心力量放在一起';
      }));
      expect(v.scopeRelations.single.scope!.basis, excerpt);
    });
    test('a missing relation_scope or justification', () {
      expect(parse(data((s, m) => s.remove('relation_scope'))).scopeRelations.length, 1);
      expect(parse(data((s, m) => s.remove('justification'))).scopeRelations.length, 1);
    });
    test('reworded member criteria are replaced by the concept definitions', () {
      final v = parse(data((s, m) {
        s['criterion_a'] = '人处在艰难、受压的境况之中';
        s['criterion_b'] = '内心体验到的不被击垮的力量';
      }));
      final scope = v.scopeRelations.single.scope!;
      expect(scope.criterionA, '人所处的艰难、受压的状态');
      expect(scope.criterionB, '人在内心体验到的、未被击垮的力量');
      final notes = v.issues.where((i) => i.path.contains('.criterion_'));
      expect(notes.length, 2);
      expect(notes.any((i) => i.retryable), isFalse);
    });
    test('node ids are found by exact label, and swapped sets are put right',
        () {
      final byLabel = parse(data((s, m) {
        s['set_a'] = '艰难处境';
        s['set_b'] = '内在力量';
        ((m['relations'] as List).first as Map).remove('node_ids');
      }));
      expect(byLabel.scopeRelations.single.nodeIds, ['c1', 'c2']);
      final swapped = parse(data((s, m) {
        s['set_a'] = '内在力量';
        s['set_b'] = '艰难处境';
      }));
      final relation = swapped.scopeRelations.single;
      expect(relation.nodeIds, ['c2', 'c1']);
      expect(relation.scope!.setA, '内在力量');
    });
    test('an analytic scope is labelled a definition, and a missing statement is filled',
        () {
      final v = parse(data((s, m) {
        ((m['relations'] as List).first as Map)['status'] = 'interpretation';
        ((m['relations'] as List).first as Map).remove('statement');
      }));
      final relation = v.scopeRelations.single;
      expect(relation.status, 'definition');
      expect(relation.statement, '依所列定义核对');
    });
    test('a proper subset with identical criteria is still refused', () {
      final v = parse(data((s, m) {
        s['relation_type'] = 'subset';
        s.remove('only_a');
        ((m['concepts'] as List)[1] as Map)['definition'] = '人所处的艰难、受压的状态';
      }));
      expect(v.scopeRelations, isEmpty);
      expect(v.issues.single.message, contains('相同成员判准'));
    });
    test('real gaps are still refused', () {
      final differentUniverse = parse(data((s, m) {
        ((m['concepts'] as List)[1] as Map)['universe'] = '人的力量';
      }));
      expect(differentUniverse.scopeRelations, isEmpty);
      expect(differentUniverse.issues.single.message, contains('同一论域'));
      final missingRegion = parse(data((s, m) => s.remove('only_b')));
      expect(missingRegion.scopeRelations, isEmpty);
      expect(missingRegion.issues.single.message, contains('only_b'));
    });
  });

  group('the five forms of the principle of sufficient reason', () {
    GroundCoverage row(List<GroundCoverage> rows, String kind) =>
        rows.singleWhere((r) => r.form.kind == kind);

    test('a metaphor states little: cues are hints, not grounds', () {
      final rows = GroundCoverage.of(_stalled(), const [_camus]);
      expect(row(rows, 'time').presence, GroundPresence.cueOnly);
      expect(row(rows, 'time').cues, contains('终于'));
      expect(row(rows, 'time').status, contains('意象'));
      expect(row(rows, 'space').presence, GroundPresence.cueOnly);
      expect(row(rows, 'evidence').cues, ['发现']);
      expect(row(rows, 'cause').presence, GroundPresence.absent);
      expect(row(rows, 'motive').presence, GroundPresence.absent);
      expect(rows.where((r) => r.needsCase).length, 5);
    });

    test('a related case expresses what the sentence does not', () {
      final value = SemanticScope.parse(
          purposefulCase(), [const ScopeSource('A', camusPassage)]);
      final rows = GroundCoverage.of(value, [camusPassage]);
      expect(row(rows, 'motive').presence, GroundPresence.viaCase);
      expect(row(rows, 'time').presence, GroundPresence.viaCase);
      expect(row(rows, 'time').status, '本句没有，由相关案例表示');
      expect(row(rows, 'cause').needsCase, isTrue);
      expect(row(rows, 'motive').needsCase, isFalse);
    });

    test('a form the sentence states is shown as stated', () {
      const sentence = '因为下雨，所以地面湿了。';
      final value = SemanticScope.parse({
        'schema_version': 6,
        'analysis_purpose': '理解',
        'selection_strategy': '取因果',
        'material_kind': 'argument',
        'evidence': [
          {'id': 'e1', 'source': 'A', 'excerpt': '因为下雨，所以地面湿了'}
        ],
        'grounds': [
          {
            'kind': 'cause',
            'from': '下雨',
            'to': '地面湿了',
            'link': '雨水落到地面使地面变湿',
            'status': 'text_claim',
            'references': ['e1'],
          }
        ],
      }, [const ScopeSource('A', sentence)]);
      final rows = GroundCoverage.of(value, const [sentence]);
      expect(row(rows, 'cause').presence, GroundPresence.stated);
      expect(row(rows, 'cause').status, '本句明示');
      expect(row(rows, 'cause').cues, containsAll(['因为', '所以']));
      expect(row(rows, 'time').presence, GroundPresence.absent);
      expect(row(rows, 'time').status, '本句没有；尚无相关案例表示');
    });

    test('the grounds advice is only advice and only when requested', () {
      final requested = ReadingMapQuality.structureIssues(_stalled(),
          requestedViews: const ['grounds']);
      final note = requested.singleWhere((i) => i.path == 'reading.grounds_via_case');
      expect(note.retryable, isFalse);
      expect(note.message, contains('时间、空间、因果、认识根据、动机'));
      expect(
          ReadingMapQuality.structureIssues(_stalled(),
                  requestedViews: const ['hierarchy'])
              .any((i) => i.path == 'reading.grounds_via_case'),
          isFalse);
    });
  });

  test('guidance v9 carries the reading principles for every graph', () {
    expect(SchopenhauerGuidance.version, 9);
    for (final needle in [
      '读图总纲（v9',
      '个别经历是圈里的点',
      '向上读“是”',
      '向下问“追溯”',
      '按离直观隔了几层概念来分',
      '禁止以“原句未说明是字面还是隐喻”收尾',
      '意象词及其所指',
    ]) {
      expect(SchopenhauerGuidance.core, contains(needle), reason: needle);
    }
  });
}
