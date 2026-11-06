import '../models/quote_insight.dart';
import 'source_excerpt.dart';

/// One definition per identity. Wire relations reference identities, not copies
/// of their labels/criteria. This adapter supplies structure, never new claims.
class GroundedGraphWire {
  static const format = 'grounded_graph_v1';
  static List<Map<String, dynamic>> list(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : [];
  static List<String> ids(dynamic raw) =>
      raw is List ? raw.whereType<String>().toList() : [];

  static Map<String, dynamic> normalize(Map<String, dynamic> input,
      {Map<String, Map<String, dynamic>> known = const {},
      Map<String, String> sources = const {}}) {
    if (input['format'] != format) return input;
    final map = <String, dynamic>{...input}..remove('format');
    final texts = {...sources};
    for (final c in [...list(map['cases']), ...list(map['aligned_cases'])]) {
      texts.putIfAbsent('${c['id']}', () => '${c['text'] ?? ''}');
    }
    final normalizedEvidence = [
      for (final e in list(map['evidence']))
        {
          ...e,
          'excerpt': locateSourceExcerpt(
                  texts['${e['source']}'] ?? '', '${e['excerpt'] ?? ''}') ??
              e['excerpt']
        }
    ];
    final evidence = <String, Map<String, dynamic>>{};
    for (final e in normalizedEvidence)
      evidence.putIfAbsent('${e['id']}', () => e);
    map['evidence'] =
        normalizedEvidence; // Keep duplicates visible to validation.
    List<String> references(Map<String, dynamic> m) =>
        ids(m['refs'] ?? m['references']);
    String placement(List<String> refs) {
      final sources =
          refs.map((r) => evidence[r]?['source']).whereType<String>().toSet();
      return sources.length == 1 ? sources.single : 'cross';
    }

    final purpose = insightText(map, 'purpose');
    map['schema_version'] = 6;
    map['analysis_purpose'] = purpose;
    map['analysis_summary'] = insightText(map, 'reading');
    map['selection_strategy'] = insightText(map, 'selection');
    map['aligned_cases'] = [
      ...list(map['aligned_cases']),
      for (final entry in list(map['cases']).indexed)
        {
          ...entry.$2,
          'title': insightText(entry.$2, 'title').isEmpty
              ? '相关案例 ${entry.$1 + 1}'
              : entry.$2['title'],
          'purpose': entry.$2['purpose'] ?? purpose,
          'alignment': [
            for (final pair in list(entry.$2['alignment']))
              {
                'source':
                    evidence[pair['quote_ref']]?['source'] ?? pair['source'],
                'excerpt':
                    evidence[pair['quote_ref']]?['excerpt'] ?? pair['excerpt'],
                'case_detail': evidence[pair['case_ref']]?['excerpt'] ??
                    pair['case_detail'],
                'preserved_meaning':
                    pair['meaning'] ?? pair['preserved_meaning'],
              }
          ],
        }
    ];
    final caseIds = list(map['aligned_cases']).map((c) => c['id']).toSet();
    final nodes = <String, Map<String, dynamic>>{...known};
    final concepts = <Map<String, dynamic>>[];
    for (final n in [
      ...list(map['concepts']),
      ...list(map['experiences']).map((e) => {...e, 'kind': 'experience'})
    ]) {
      final refs = references(n);
      final experience = n['kind'] == 'experience';
      final node = <String, dynamic>{
        ...n,
        'kind': n['kind'] ?? 'concept',
        'definition': n['definition'] ?? n['description'],
        'status': n['status'] ?? (experience ? 'example' : 'definition'),
        'role': n['role'] ?? 'core',
        'selection_reason': n['reason'] ?? n['selection_reason'],
        'references': refs,
      };
      // A case event is always an illustration, even when the model forgets
      // the marker; the wire contract explicitly declares cases fictional.
      if (experience &&
          refs.any((r) => caseIds.contains(evidence[r]?['source'])))
        node['status'] = 'example';
      nodes['${n['id']}'] = node;
      concepts.add(node);
    }
    map['concepts'] = concepts;
    final hierarchy = list(map['hierarchy']);
    final meaning = list(map['meaning_links']);
    for (final edge in list(map['links'])) {
      final type = insightText(edge, 'type');
      final refs = references(edge);
      if (const ['subtype', 'mediation', 'instance', 'grounding']
          .contains(type)) {
        hierarchy.add({
          'parent': edge['from'],
          'child': edge['to'],
          'kind': type,
          'differentia': edge['added'] ?? '',
          'basis_kind': edge['basis_kind'] ?? 'analytic_definition',
          'explanation': edge['why'],
          'references': refs
        });
      } else {
        meaning.add({
          'from': edge['from'],
          'to': edge['to'],
          'kind': type,
          'explanation': edge['why'],
          'status': edge['status'] ?? 'interpretation',
          'references': refs
        });
      }
    }
    map['hierarchy'] = hierarchy;
    map['meaning_links'] = meaning;
    map['relations'] = [
      ...list(map['relations']),
      for (final circle in list(map['circles']))
        {
          'placement': placement(references(circle)),
          'node_ids': [circle['a'], circle['b']],
          'universe_id': circle['parent'] ?? '',
          'part_ids': ids(circle['parts']),
          'intersection_id': circle['intersection_id'] ?? '',
          'status': 'definition',
          'statement': circle['why'],
          'references': references(circle),
          'scope': {
            'relation_type': circle['type'],
            'relation_scope': 'extension',
            'universe': circle['universe'] ?? nodes[circle['a']]?['universe'],
            'basis_kind': 'analytic_definition',
            'basis_ref': references(circle).firstOrNull ?? '',
            'justification': circle['why'],
            'illustration': references(circle)
                .any((r) => caseIds.contains(evidence[r]?['source'])),
            'intersection': circle['common'] ?? '',
            'only_a': circle['a_only'] ?? '',
            'only_b': circle['b_only'] ?? '',
            'other_member': circle['other'] ?? '',
            'parts': [
              for (final id in ids(circle['parts']))
                {
                  'term': nodes[id]?['label'],
                  'criterion': nodes[id]?['definition'],
                  'example': insightObject(circle['examples'])[id] ?? '',
                }
            ],
          },
        },
    ];
    final grounds = list(map['grounds']);
    final judgments = <Map<String, dynamic>>[];
    for (final j in list(map['judgments'])) {
      final refs = references(j);
      final claim = insightText(j, 'claim');
      final premises = ids(j['premises']);
      judgments.add({
        ...j,
        'placement': j['placement'] ?? placement(refs),
        'question': j['question'] ?? claim,
        'basis': j['why'] ?? j['basis'],
        'references': refs
      });
      if (premises.isNotEmpty && claim.isNotEmpty) {
        final fromCase =
            refs.any((r) => caseIds.contains(evidence[r]?['source']));
        grounds.add({
          'kind': 'evidence',
          'from': premises.join('\n'),
          'to': claim,
          'premises': premises,
          'link': j['why'],
          'status': fromCase ? 'example' : 'interpretation',
          'experience_ids': ids(j['experiences']),
          'references': refs
        });
      }
    }
    map['judgments'] = judgments;
    map['grounds'] = grounds;
    return map;
  }

  static const instructions = '''
返回 format="grounded_graph_v1" 的单个JSON。先解释名言实际说了什么，再依当前目的选概念，给出具体经验内容、必要中介、关系及含义圈。不能把句子切成名词就称为概念树。
严格区分：subtype=每一个下位也是上位；part_of=部分属于整体，不能当上下位；mediation=理解上位内容所需概念中介；instance=个别经验体现该概念的规定；grounding=追溯内容所依据的个别经验，未必是该概念的下位实例；metaphor/contrast/condition/constraint/cause/analogy=各自有根据的语义联系。身体部位不是“身体状况”的下位；经验提醒不是自动成立的心理因果定律。每条边用why说明关系为什么成立，不能只写“相关”。
concepts仅写一次定义。circles只引用a/b的概念id，不重复set_a、criterion_a等定义。两端必须有相同非空universe和明确的成员判准，保留全部关键限定。用equal/subset/superset/overlap/siblings/partition画真实区域，不用分散圆或一般箭头充当含义圈。没有固定层数、链长或圈数；有需要的中介应保留。overlap给common/a_only/b_only；subset给common/b_only；superset给common/a_only；equal给common；siblings给parent及a_only/b_only/other；partition给parent、parts子类id和examples按子类id填写实例。互斥不代表穷尽，不为画交集放宽定义。若合画多个圈，同一论域中各可见圈之间的相对范围须有明确判断或可由已列包含/互斥关系推出；未确定的两圈采用局部关系图，不能通过布局补造交集。
原句不宜直接演示时，在同次回复中给与关键意义逐项对应的教学案例cases；展示人物、处境、动作、具体变化，不冒充作者/用户事实。引用只在evidence写一次，alignment通过quote_ref/case_ref引用同一表，避免重复摘录出错。案例有boundary。experiences给可辨认的个别事件而不是“X的具体表现”，用links中的instance/grounding接回概念，并保留必要mediation。经验描述帮助返回直观，不等于直接观察或现实证据。
判断的认识根据用judgments表示：premises列出支持判断的前提，claim给有条件结论，why说明推理。区分“为什么相信这个判断”与“事件为什么发生”；不能把“原文措辞→AI解释”当作完整认识根据。引用只定位材料，不能证明解释。案例前提只能支持案例中的结论，不能证明普遍规律。不凑齐四重根据。
证据evidence的source必须是原sources的id或cases的id，excerpt逐字来自该材料，尽量选包含相关否定、量词与条件的完整分句，不能截去限制只留下几个词。选择自然核心概念并给reason；role=core/support/imagery/perspective，范围投影perspective用core_id回指核心，不能偷换定义。概念的核心内容必须能沿必要中介返回experiences；不要为了层数造同义节点。
字段约定（字段名列表，不是示例答案；所有id及引用必须在本次材料中实际定义）：
顶层：format、schema_version=6、material_kind、purpose、reading、selection、evidence、cases、concepts、experiences、links、circles、judgments。
evidence条目：id,source,excerpt。
cases条目：id,title,text,boundary,alignment；alignment条目：quote_ref,case_ref,meaning（两引用必须指向evidence内的原句与该案例细节）。
concepts条目：id,label,definition,universe,role,reason,refs；范围投影另给core_id。必要时补observed,retained,omitted,counter_example。
experiences条目：id,label,description,refs（必须引用实际来源或本次完整案例）。
links条目：from,to,type,why,refs；subtype另给added新增限定与basis_kind=analytic_definition/source_assertion。instance的目标必须是experience。
circles条目：a,b,type,why,refs，以及此图式必需的common,a_only,b_only,other,parent,parts,examples。a/b/parent/parts均引用已有concept id。若命名共同范围，可用intersection_id引用同时保留两个上位规定的独立概念。省略本图式不存在的区域。
judgments条目：claim,premises,why,conditions,unknown,experiences,refs；premises为前提字符串列表，experiences为已定义的经验id列表。
不要返回未定义的占位id，不把类型说明或字段名当概念。只返回完整JSON。
若既有context.concept_id，返回连接原图的增量，沿用既有id/定义/论域和案例；只有本次已有概念以外的新id可增加。完整重试则允许纠正旧概念与关系，旧分析只是待批评的材料。
''';
}
