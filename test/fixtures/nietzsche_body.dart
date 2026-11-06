// A reviewed offline teaching model, not a result from the user's real model.
const bodyQuote = '下腹（下半身）之存在，是人不那么容易把自己当作上帝的原因。';
const bodyStory =
    '小周在讨论中说，自己像神一样，完全不受身体需要影响。几分钟后，他感到下腹胀和尿意，暂停发言去如厕。回来后他说，至少这次自己仍受身体需要限制。';

Map<String, dynamic> bodyGraph({bool omitCircles = false}) {
  Map<String, dynamic> node(
          String id, String label, String definition, String universe,
          {String role = 'core', String core = ''}) =>
      {
        'id': id,
        'label': label,
        'definition': definition,
        'universe': universe,
        'role': role,
        if (core.isNotEmpty) 'core_id': core,
        'reason': '围绕身体条件与自我评价的关系选取$label；区分原句、当前定义与教学案例。',
        'refs': ['q', 'c'],
      };
  Map<String, dynamic> link(String a, String b, String type, String why,
          {String added = ''}) =>
      {
        'from': a,
        'to': b,
        'type': type,
        'why': why,
        'refs': ['q', 'c'],
        'added': added,
      };
  const evaluation = '同一时段的一项自我评价';
  const episodes = '案例及其合理对照中的生活片段';
  return {
    'format': 'grounded_graph_v1',
    'schema_version': 6,
    'material_kind': 'argument',
    'purpose': '理解身体需要如何对身体方面的全能自我想象构成限制，并核对这一判断的根据。',
    'reading':
        '原句用下腹这一身体部位作带有讽刺意味的提醒：人有无法任意取消的身体需要，因此“自己超越一切身体条件”的想象会受到现实限制。这是一种解释；身体需要并不必然使每个人谦卑，原句也没有证明普遍的心理因果规律。',
    'selection':
        '选择身体性、生理需要、身体条件限制及自我评价；组成部位不是身体状况的下位。用具体案例区分原句主张、概念内容与支持案例判断的前提。',
    'evidence': [
      {'id': 'q', 'source': 'A', 'excerpt': bodyQuote},
      {'id': 'c', 'source': 'C1', 'excerpt': bodyStory},
      {'id': 'c0', 'source': 'C1', 'excerpt': '自己像神一样，完全不受身体需要影响'},
      {'id': 'c1', 'source': 'C1', 'excerpt': '他感到下腹胀和尿意，暂停发言去如厕'},
      {'id': 'c2', 'source': 'C1', 'excerpt': '至少这次自己仍受身体需要限制'},
    ],
    'cases': [
      {
        'id': 'C1',
        'title': '发言被身体需要打断',
        'text': bodyStory,
        'boundary':
            '这是教学情境，不是尼采或用户的经历。只说明本案例中的全能自我评价与身体需要不相容；不能推出所有人都会因此谦卑，也不把例子当成心理学定律。',
        'alignment': [
          {
            'quote_ref': 'q',
            'case_ref': 'c',
            'meaning': '保留身体条件与超越身体的自我想象之间的张力，并明确呈现需要、行动调整与自我评价的变化。'
          }
        ]
      }
    ],
    'concepts': [
      node('body', '身体性', '人以具体身体存在，活动须涉及相应的生理功能与条件。', '人的存在条件'),
      node('lower', '下腹', '原句指出的具体身体部位；用以提醒身体条件，不等于一种心理状况。', '身体部位',
          role: 'support'),
      node('needs', '生理需要', '人在具体情境中产生、要求回应的身体需要或冲动；不把需要本身等同道德缺陷。', '身体需要'),
      node('limit', '身体条件限制', '具体行动在当下不能不顾相应身体条件而任意实现的限定。', '行动条件'),
      node('adjust', '回应身体需要', '以具体动作调整当前活动以回应已经出现的身体需要。', '行动方式',
          role: 'support'),
      node('eval', '自我评价', '人在特定时段对自身能力、地位或限制所作的一项判断。', evaluation,
          role: 'support'),
      node('ack', '承认身体限制', '自我评价中，明确承认自己仍受某些身体条件制约的判断。', evaluation),
      node('divine', '身体方面的全能自我想象',
          '自我评价中，认定自己完全不受任何身体条件制约的判断；这是本次考量中的有限定义，不概括所有神学意义。', evaluation),
      node('nr', '出现身体需要的片段', '本次生活片段中，当事人出现需要回应的身体要求；不要求同时有自我反思。', episodes,
          role: 'perspective', core: 'needs'),
      node('ar', '认识到身体限制的片段', '本次生活片段中，当事人明确承认自身受身体条件制约；当前未必有正在发生的身体需要。',
          episodes,
          role: 'perspective', core: 'ack'),
      node('er', '形成自我评价的片段', '本次生活片段中，当事人形成至少一项对自身能力、地位或限制的判断。', episodes,
          role: 'perspective', core: 'eval'),
      node('dr', '形成全能自我想象的片段', '本次生活片段中，当事人形成完全不受身体条件制约的自我评价；片段中随后也可能修正它。',
          episodes,
          role: 'perspective', core: 'divine'),
    ],
    'experiences': [
      {
        'id': 'E0',
        'label': '小周宣称完全不受身体需要影响',
        'description': '在案例讨论开始时，小周说自己像神一样，完全不受身体需要影响。',
        'refs': ['c0']
      },
      {
        'id': 'E1',
        'label': '尿意打断发言并去如厕',
        'description': '几分钟后，小周感到下腹胀和尿意，暂停发言去如厕。个别身体感受与行动使这里的身体需要可以被辨认。',
        'refs': ['c1']
      },
      {
        'id': 'E2',
        'label': '回来后承认本次受身体需要限制',
        'description': '返回讨论后，小周明确说至少这次自己仍受身体需要限制；这是案例中设定的自述，不是从行为猜测其内心。',
        'refs': ['c2']
      },
    ],
    'links': [
      link('lower', 'body', 'part_of', '下腹是身体的组成部位，不是“身体状况”的下位类别。'),
      link(
          'body', 'needs', 'mediation', '通过身体功能及其需要理解这里身体性的一部分内容，不声称身体性只等于需要。'),
      link(
          'needs', 'adjust', 'mediation', '借需要要求回应及行动调整说明其内容，不断言有需要就一定采取某个动作。'),
      link('adjust', 'E1', 'instance', '案例给出暂停发言并去如厕的个别行动。'),
      link('lower', 'E1', 'grounding', '下腹胀和尿意是案例中明确描述的身体感受，不是抽象概念加“具体表现”。'),
      link('limit', 'E1', 'grounding', '案例的身体需要限制了原先继续发言的安排。'),
      link('needs', 'divine', 'constraint',
          '按本次定义，仍需回应身体要求与完全不受任何身体条件约束的全能自我评价不相容；不由此证明普遍心理因果。'),
      link('eval', 'ack', 'subtype', '承认身体限制仍是一项对自身限制的判断。',
          added: '明确承认仍受某些身体条件制约'),
      link('eval', 'divine', 'subtype', '身体方面的全能想象也是对自身能力和限制的评价。',
          added: '认定完全不受任何身体条件制约'),
      link('ack', 'E2', 'instance', '案例中明确作出的这次有限自我评价。'),
      link('divine', 'E0', 'instance', '案例中最初宣称完全摆脱身体需要的那项判断。'),
    ],
    'circles': omitCircles
        ? []
        : [
            {
              'a': 'ack',
              'b': 'divine',
              'type': 'siblings',
              'parent': 'eval',
              'why':
                  '单位是同一时段的一项一致自我评价：承认某些身体限制与断言完全没有任何身体限制互不相容；自我评价还有不涉及这个问题的其他类型，故不穷尽。',
              'a_only': '回来后承认本次仍受身体需要限制的那项判断',
              'b_only': '最初宣称完全不受身体需要影响的那项判断',
              'other': '只评价本次表达是否清楚、未判断身体限制的自我评价',
              'refs': ['q', 'c']
            },
            {
              'a': 'nr',
              'b': 'ar',
              'type': 'overlap',
              'why': '生活片段可同时包含身体需要及对限制的认识；需要不必伴随反思，回顾限制也不必伴随当下需要。',
              'common': '小周出现尿意、调整活动，并在这一片段中明确承认身体限制',
              'a_only': '出现尿意并去如厕，却未作身体限制方面的自我评价',
              'b_only': '此刻没有要回应的身体需要，回顾此前经历并承认身体限制',
              'refs': ['c']
            },
            {
              'a': 'ar',
              'b': 'er',
              'type': 'subset',
              'why': '按定义，每一次明确承认身体限制都形成自我评价；评价表达是否清楚也属于自我评价，但未必涉及身体限制。',
              'common': '回来后明确承认本次身体限制的片段',
              'b_only': '只评价自己表达是否清楚的片段',
              'refs': ['c']
            },
            {
              'a': 'dr',
              'b': 'er',
              'type': 'subset',
              'why': '形成身体方面的全能自我评价是形成自我评价的一种；承认身体限制也是自我评价而非全能想象。',
              'common': '讨论开始时宣称不受身体需要影响的片段',
              'b_only': '只承认本次身体限制、未形成全能想象的片段',
              'refs': ['c']
            },
            {
              'a': 'ar',
              'b': 'dr',
              'type': 'overlap',
              'why':
                  '单位是可包含先后变化的生活片段，不是同一时刻的一项判断；一个片段中可先宣称全能、后承认限制，也可以仅有其中一种自我评价。',
              'common': '案例整个讨论片段中先自认不受身体影响、后承认本次限制',
              'a_only': '只承认本次身体限制、此前未形成全能想象的片段',
              'b_only': '只宣称不受身体影响、未承认限制的片段',
              'refs': ['c']
            },
            {
              'a': 'nr',
              'b': 'dr',
              'type': 'overlap',
              'why': '身体需要出现与形成全能自我想象可在同一生活片段中并存；两者在事实中并存不使全能评价为真，也不强迫当事人反思。',
              'common': '案例整个讨论片段包含全能宣称和随后出现的尿意',
              'a_only': '出现尿意并去如厕、未形成全能评价的片段',
              'b_only': '宣称身体全能、该短暂片段中未出现要回应的身体需要',
              'refs': ['c']
            },
            {
              'a': 'nr',
              'b': 'er',
              'type': 'overlap',
              'why': '生活片段可同时包含身体需要与自我评价，也可仅有需要而未评价自己，或仅评价表达而未出现身体需要。',
              'common': '案例片段同时包含尿意和自我评价',
              'a_only': '身体需要出现并被回应，当事人未作自我评价',
              'b_only': '只评价自己的表达清晰度，未出现要回应的身体需要',
              'refs': ['c']
            },
          ],
    'judgments': [
      {
        'claim': '在案例及本次判准下，小周“完全不受身体需要影响”的自我评价不能成立。',
        'premises': [
          '全不受身体需要影响的自我评价，排除了需要回应身体要求的情形。',
          '案例明确给出小周出现尿意并调整发言安排的个别事件。'
        ],
        'why': '案例出现了该全称自我评价所排除的情形，因而构成对本案例中这项评价的反例；不从一个模拟例子推出所有人的心理反应。',
        'conditions': '只在给定案例与明示判准中讨论；不把身体需要视为必然导致谦卑。',
        'unknown': '原句没有提供经验研究，无法据此量定身体需要对所有人自我评价的影响。',
        'experiences': ['E1', 'E2'],
        'refs': ['c0', 'c1', 'c2']
      }
    ],
  };
}
