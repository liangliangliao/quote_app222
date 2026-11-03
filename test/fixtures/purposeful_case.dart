// An explicit offline teaching model, not a model-quality evaluation or history.
const camusPassage = '在隆冬之中，我终于在自己内心发现了一个不可战胜的夏天。';
const alignedStory =
    '小林连续三次求职被拒，几天里感到低落。他想找到一份合适的工作，于是仍每天练习面试，并和朋友交流遇到的困难。一周后，他意识到自己虽然难过，却仍能继续学习和尝试；第二天，他修改简历并再次申请职位。';
Map<String, dynamic> purposefulCase() {
  const question = '理解外在逆境、内在力量与自我认识的关系，以及它如何落实为行动';
  Map<String, dynamic> node(
          String id, String label, String definition, String universe,
          {String role = 'core', String core = '', String kind = 'concept'}) =>
      {
        'id': id,
        'label': label,
        'definition': definition,
        'universe': universe,
        'kind': kind,
        'status': kind == 'experience' ? 'example' : 'definition',
        'role': role,
        'core_id': core,
        'selection_reason': switch (id) {
          'adversity' => '用逆境概括案例中的拒绝和阻力，对照原句的隆冬意象。',
          'resilience' => '区分仍能行动的内在力量与外在处境顺利，解释原句反差。',
          'awareness' => '区分实际拥有某种能力与意识到这种能力，对应终于发现。',
          _ => '为本次考量解释$label的共同规定及其与案例动作的联系。',
        },
        'references': ['q', 'c'],
      };
  Map<String, dynamic> sub(String p, String c, String criterion) => {
        'parent': p,
        'child': c,
        'kind': 'subtype',
        'differentia': criterion,
        'basis_kind': 'analytic_definition',
        'explanation': '保留上位规定，再限定$criterion。',
        'references': ['q', 'c']
      };
  Map<String, dynamic> overlap(
          String a, String b, String common, String onlyA, String onlyB) =>
      {
        'placement': 'C1',
        'node_ids': [a, b],
        'status': 'definition',
        'statement': '按本次生活经历判准比较共同规定及差异，案例与对照情境不是现实中的普遍证明。',
        'references': ['c'],
        'scope': {
          'relation_type': 'overlap',
          'relation_scope': 'extension',
          'universe': '案例及其合理对照中的生活经历',
          'basis_kind': 'analytic_definition',
          'basis_ref': 'c',
          'justification': '用本次明示的经历判准联系核心概念，保留两者不等同的区别。',
          'intersection': common,
          'only_a': onlyA,
          'only_b': onlyB,
          'illustration': true
        }
      };
  return {
    'schema_version': 6,
    'material_kind': 'metaphor',
    'analysis_purpose': question,
    'selection_strategy':
        '围绕外在处境、内在能力与对能力的认识选取概念；原句未提供足够具体事件，因此借高度对应的案例分析。冬夏是意象，不组成表达情形分类。',
    'recommended_view': 'circles',
    'aligned_cases': [
      {
        'id': 'C1',
        'title': '受挫后仍能继续尝试',
        'text': alignedStory,
        'purpose': question,
        'boundary': '案例不属于作者或用户的真实经历；继续尝试不保证求职成功，拥有韧性也不等于不再难过。',
        'alignment': [
          {
            'source': 'A',
            'excerpt': '隆冬',
            'case_detail': '连续三次求职被拒',
            'preserved_meaning': '以具体受挫处境承接外在逆境这一规定，不把隆冬当作实际日期。'
          },
          {
            'source': 'A',
            'excerpt': '不可战胜的夏天',
            'case_detail': '仍每天练习面试，并和朋友交流遇到的困难',
            'preserved_meaning': '外在阻力中仍保留学习、联系他人和行动的力量。'
          },
          {
            'source': 'A',
            'excerpt': '终于在自己内心发现',
            'case_detail': '他意识到自己虽然难过，却仍能继续学习和尝试',
            'preserved_meaning': '保持力量与认识到这种力量有区别，案例明确呈现后者。'
          },
        ]
      }
    ],
    'evidence': [
      {'id': 'q', 'source': 'A', 'excerpt': camusPassage},
      {'id': 'c', 'source': 'C1', 'excerpt': alignedStory}
    ],
    'concepts': [
      node('situation', '生活处境', '人在活动中面对的外在条件。', '生活处境', role: 'support'),
      node('adversity', '逆境', '生活处境中，当前行动遇到外在阻力和挫折的处境。', '生活处境'),
      node('force', '内在力量', '人在困难中或困难之后维持、恢复有价值生活活动的能力。', '人的心理能力',
          role: 'support'),
      node('resilience', '韧性', '内在力量中，遭遇挫折后能调整方法并继续有价值行动的能力。', '人的心理能力'),
      node('knowing', '认识', '主体对事物及其规定形成理解的活动。', '认识活动', role: 'support'),
      node('awareness', '自我认识', '认识活动中，以自己的感受、能力及行为为对象者。', '认识活动'),
      node('action', '持续尝试', '以具体行为继续接近所选目标，不等于保证结果。', '行动方式', role: 'support'),
      node('event', '被拒后练习面试并再次申请', '小林在被拒且感到低落后，练习面试、交流困难、修改简历并再次申请。', '案例事件',
          kind: 'experience'),
      node('insight', '意识到自己仍能继续尝试', '一周后，小林意识到难过与仍能学习和尝试可以同时存在。', '案例事件',
          kind: 'experience'),
      node('range-a', '逆境经历', '生活经历中，本次考察的时段里，行动正遇到外在挫折或阻力者。', '案例及其合理对照中的生活经历',
          role: 'perspective', core: 'adversity'),
      node(
          'range-b',
          '展现韧性的经历',
          '生活经历中，人在受挫后呈现维持、恢复或调整行动的过程；挫折可能在此前，当前外部处境未必仍有阻力。一般顺利情境中的行动不因此就算韧性。',
          '案例及其合理对照中的生活经历',
          role: 'perspective',
          core: 'resilience'),
      node(
          'range-c', '自我认识的经历', '生活经历中，主体对自己的感受、能力或行为形成新认识者。', '案例及其合理对照中的生活经历',
          role: 'perspective', core: 'awareness'),
    ],
    'hierarchy': [
      sub('situation', 'adversity', '存在外在阻力或挫折'),
      sub('force', 'resilience', '遭遇挫折后能调整并继续有价值行动'),
      sub('knowing', 'awareness', '以自己为认识对象'),
      {
        'parent': 'resilience',
        'child': 'action',
        'kind': 'mediation',
        'explanation': '通过困难中仍可辨认的调整与持续行为理解这里的韧性。',
        'references': ['q', 'c']
      },
      {
        'parent': 'action',
        'child': 'event',
        'kind': 'instance',
        'explanation': '案例给出练习、交流、修改和申请这些可辨认动作。',
        'references': ['c']
      },
      {
        'parent': 'adversity',
        'child': 'event',
        'kind': 'instance',
        'explanation': '具体求职受挫情境帮助理解逆境。',
        'references': ['c']
      },
      {
        'parent': 'awareness',
        'child': 'insight',
        'kind': 'instance',
        'explanation': '案例中的明确自我认识事件。',
        'references': ['c']
      },
    ],
    'relations': [
      overlap('range-a', 'range-b', '被拒且难过时仍练习并再次申请', '面对挫折后放弃所有尝试的对照情境',
          '外在障碍已经消退，仍在从此前挫折中恢复节奏并调整方法的对照情境'),
      overlap('range-b', 'range-c', '小林在受挫后继续练习，并意识到自己仍可学习和尝试',
          '受挫后调整行动但尚未反思自己能力的对照情境', '认识到自身局限却暂未行动的对照情境'),
      overlap('range-a', 'range-c', '受挫中认识到自己的感受和能力', '受挫但尚未形成自我认识的对照情境',
          '顺利经历中认识自己专长的对照情境'),
    ],
    'grounds': [
      {
        'kind': 'motive',
        'from': '想找到一份合适的工作',
        'to': '继续练习并申请职位',
        'link': '案例明确写出目标及于是采取的动作，作为本次行动理解的线索。',
        'status': 'example',
        'references': ['c']
      },
      {
        'kind': 'time',
        'from': '连续求职被拒并感到低落',
        'to': '一周后意识到自己仍能尝试',
        'temporal_relation': 'before',
        'link': '只表示案例中这两个具体事件的先后，不以先后证明因果。',
        'status': 'example',
        'references': ['c']
      },
    ],
  };
}
