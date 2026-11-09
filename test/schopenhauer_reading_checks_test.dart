import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
