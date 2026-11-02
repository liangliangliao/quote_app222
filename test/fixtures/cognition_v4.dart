import 'package:quote_app/epistemic/semantic_scope.dart';

const happiness = '幸福并非抵达山顶，也不是漫无目的地在山间攀爬；幸福是朝着山顶攀登的体验。';
const frankl = '归根结底，人不应追问生命的意义是什么，而应承认：是生命在向他发问。';
const willing = '人宁愿意欲虚无，也不愿不欲。';
const networkText = '苹果属于水果，黄色香蕉也属于水果。红色物体与水果部分相交，与苹果也部分相交。';
List<Map<String, dynamic>> refs(String source, String excerpt) => [
      {'source': source, 'excerpt': excerpt}
    ];
Map<String, dynamic> node(
        String id, String label, String definition, String excerpt,
        {String source = 'A',
        String kind = 'concept',
        String observed = '',
        String retained = '',
        String omitted = ''}) =>
    {
      'id': id,
      'label': label,
      'definition': definition,
      'kind': kind,
      'status': kind == 'experience' ? 'example' : 'interpretation',
      'observed': observed,
      'retained': retained,
      'omitted': omitted,
      'references': refs(source, excerpt),
    };
Map<String, dynamic> happinessMap() => {
      'schema_version': 2,
      'recommended_view': 'hierarchy',
      'concepts': [
        node('happiness', '幸福', '按原句理解：朝向目标的体验，而非单独以抵达为判准。', happiness,
            observed: '原句用登山区别终点与过程。',
            retained: '有方向的过程体验',
            omitted: '具体山峰、天气、同伴与体力'),
        node('process', '过程中的幸福', '在朝向目标的行动过程中感受到的幸福。', '幸福是朝着山顶攀登的体验',
            observed: '模拟：结伴沿安全山路向上走。',
            retained: '目标与体验同时存在',
            omitted: '每段路的个别感受'),
        node('walk', '沿山路前进的体验', '模拟示例：我沿安全山路向上走，享受同行交谈，尚未抵达山顶。', '朝着山顶攀登的体验',
            kind: 'experience'),
      ],
      'hierarchy': [
        {
          'parent': 'happiness',
          'child': 'process',
          'kind': 'subtype',
          'explanation': '在原句的语境中进一步限定体验发生在朝向目标的过程中。',
          'references': refs('A', happiness)
        },
        {
          'parent': 'process',
          'child': 'walk',
          'kind': 'instance',
          'explanation': '这次模拟经历呈现过程中的幸福，不能穷尽幸福的全部含义。',
          'references': refs('A', '朝着山顶攀登的体验')
        },
      ],
      'relations': [],
      'grounds': [],
      'judgments': [],
    };
Map<String, dynamic> comparisonMap() => {
      'schema_version': 2,
      'recommended_view': 'judgment',
      'concepts': [
        node('meaning', '生命的意义', 'A句中的价值问题，原句没有列出意义的具体内容。', '生命的意义',
            observed: '模拟：面对一项责任时思考如何回应。',
            retained: '回应具体处境',
            omitted: '具体责任的内容'),
        node('will', '意欲', 'B句区分意欲的对象与没有意欲的状态。', '意欲虚无',
            source: 'B',
            observed: '模拟：仍想追求某物，与完全无所欲求作区分。',
            retained: '意欲活动',
            omitted: '意欲的具体对象'),
      ],
      'hierarchy': [],
      'relations': [],
      'grounds': [],
      'judgments': [
        {
          'placement': 'A',
          'question': '面对生命应如何提问与回应？',
          'difference': '追问意义，与把处境理解为需要自己回应的问题。',
          'decisive': '原句改变提问方向，但未列出每一种应答。',
          'basis': '“不应……而应……”表达规范性对照。',
          'references': refs('A', frankl)
        },
        {
          'placement': 'B',
          'question': '意欲虚无与不意欲有何区别？',
          'difference': '意欲的对象，与意欲活动是否存在，是两个判断尺度。',
          'basis': '“宁愿……也不愿……”表达两者的区分。',
          'references': refs('B', willing)
        },
        {
          'placement': 'cross',
          'question': '两句讨论的是同一个问题吗？',
          'common': '都涉及人如何面向生活。',
          'difference': 'A讨论意义与回应，B讨论意欲的对象与活动。',
          'decisive': '判断目的不同，不能直接把回应责任等同于意欲虚无。',
          'conditions': '需要补充具体处境后才能比较行动选择。',
          'basis': '这是对两句措辞的暂定理解。',
          'references': [...refs('A', frankl), ...refs('B', willing)]
        },
      ],
    };
Map<String, dynamic> networkMap() {
  const universe = '同一时刻的可观察物体';
  const labels = {
    'fruit': '水果',
    'apple': '苹果',
    'banana': '黄色香蕉',
    'red': '红色物体'
  };
  const definitions = {
    'fruit': '可供食用的果实',
    'apple': '属于苹果的果实',
    'banana': '表面为黄色的香蕉果实',
    'red': '表面为红色的物体'
  };
  Map<String, dynamic> relation(String a, String b, String type, String basis,
          {String intersection = '', String onlyA = '', String onlyB = ''}) =>
      {
        'placement': 'A',
        'status': 'text_claim',
        'statement': '按所列成员判准理解原句，示例仅说明范围。',
        'node_ids': [a, b],
        'references': refs('A', basis),
        'scope': {
          'relation_type': type,
          'relation_scope': 'extension',
          'universe': universe,
          'set_a': labels[a],
          'set_b': labels[b],
          'criterion_a': definitions[a],
          'criterion_b': definitions[b],
          'basis': basis,
          'justification': '固定同一时刻、对象和分类尺度。',
          'intersection': intersection,
          'only_a': onlyA,
          'only_b': onlyB
        },
      };
  return {
    'schema_version': 2,
    'recommended_view': 'circles',
    'concepts': [
      for (final id in labels.keys)
        node(id, labels[id]!, definitions[id]!, networkText)
    ],
    'hierarchy': [],
    'judgments': [],
    'grounds': [],
    'relations': [
      relation('apple', 'fruit', 'subset', '苹果属于水果',
          intersection: '一个红苹果', onlyB: '一颗梨'),
      relation('banana', 'fruit', 'subset', '黄色香蕉也属于水果',
          intersection: '一根黄色香蕉', onlyB: '一个苹果'),
      relation('red', 'fruit', 'overlap', '红色物体与水果部分相交',
          intersection: '红苹果', onlyA: '红布', onlyB: '黄色香蕉'),
      relation('red', 'apple', 'overlap', '与苹果也部分相交',
          intersection: '红苹果', onlyA: '红布', onlyB: '绿苹果'),
    ]
  };
}

SemanticScope happinessScope() =>
    SemanticScope.parse(happinessMap(), const [ScopeSource('A', happiness)]);
SemanticScope networkScope() =>
    SemanticScope.parse(networkMap(), const [ScopeSource('A', networkText)]);
