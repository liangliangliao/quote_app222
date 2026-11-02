import 'reading_map_quality.dart';
import 'semantic_scope.dart';

/// A transparent, bounded teaching exercise for the no-universal-life-recipe
/// passage. Its finite records make adjacent intersections independently
/// inspectable; no personal history or author's own example is invented.
SemanticScope? readingIllustration(String text) {
  final lower = text.toLowerCase();
  if (!((RegExp(r'\bno\s+(?:(?:single|universal)\s+)?recipe\b')
              .hasMatch(lower) &&
          (lower.contains('life') || lower.contains('living'))) ||
      (text.contains('处方') &&
          (text.contains('生活') || text.contains('人生')) &&
          RegExp(r'没有|不存在|并无|无通用|无万能').hasMatch(text)))) return null;
  final refs = [
    {'source': 'A', 'excerpt': text}
  ];
  final concepts = <Map<String, dynamic>>[],
      hierarchy = <Map<String, dynamic>>[],
      relations = <Map<String, dynamic>>[];
  void node(String id, String label, String definition,
      {String kind = 'concept', String observed = ''}) {
    concepts.add({
      'id': id,
      'label': label,
      'definition': definition,
      'kind': kind,
      'status': kind == 'experience' ? 'example' : 'definition',
      'observed': observed,
      'retained': definition,
      'omitted':
          kind == 'experience' ? '此模拟的条件不能代表所有人的生活。' : '具体个人、时间、体力和作息的不同。',
      'references': refs
    });
  }

  void edge(String p, String c,
          {bool instance = false, bool mediation = false}) =>
      hierarchy.add({
        'parent': p,
        'child': c,
        'kind': instance
            ? 'grounding'
            : mediation
                ? 'mediation'
                : 'subtype',
        'explanation': instance
            ? '这个模拟场景说明可以观察什么，以及这些可感知差异如何为该概念提供内容；不声称文字描述本身就是当场直观。'
            : mediation
                ? '理解前一概念需要借助后一概念的规定，再沿链路返回感知场景；这不是下位分类或因果关系。'
                : '保留上位规定，进一步限定对象、条件或活动，不表示因果或穷尽。',
        'references': refs
      });
  node('practical', '实践判断', '把一般建议带回一个具体处境，判断它是否适用的活动。');
  node('life', '生活安排的判断', '实践判断中，以日常生活安排为对象的判断。');
  edge('practical', 'life');
  node('advice', '生活处方', '本练习中，对作息、休息和行动安排提出建议的命题。');
  edge('life', 'advice', mediation: true);
  node('conditional', '有条件的生活建议', '明确说明建议适用于何种处境，而不声称对所有人无例外适用。');
  edge('advice', 'conditional');
  node('fit', '个体适配', '有条件的建议中，根据某人的作息、疲劳和目标调整方案。');
  edge('conditional', 'fit', mediation: true);
  node('night', '夜班后的运动安排', '个体适配中，根据一次夜班后的疲劳选择运动时段和强度。');
  edge('fit', 'night', mediation: true);
  node('night-example', '夜班后把晨跑改为午后散步',
      '模拟：一名护士结束夜班后只睡了四小时；她把原定晨跑改为午后散步二十分钟，途中停下休息一次，并记下当时的疲劳感。',
      kind: 'experience');
  edge('night', 'night-example', instance: true);
  node('universal', '普遍适用的断言', '本练习中，声称某条生活建议对每个人、每种处境均适用的命题。');
  edge('advice', 'universal');
  node('note-example', '相同晨练安排下，两人的步态与感受不同',
      '模拟：一名夜班者与一名白班者，同在六点走同一段路，一人频繁停下扶栏，另一人步态轻快。这使“同样安排对所有人均合适”的断言需要联系个体条件复核。',
      kind: 'experience');
  edge('universal', 'note-example', instance: true);
  const labels = ['审视生活建议', '核对个人处境', '调整行动方案', '试行并观察', '依据体验修订', '复核适用条件'];
  const records = [
    '卡0：读者只检查“人人都要早起”这条建议的量词和前提，尚未收集个人资料。',
    '卡1：咨询者检查早起建议的前提，同时核对一名夜班护士最近两天的睡眠记录。',
    '卡2：护士核对自己只睡四小时的处境，据此把晨跑调整为午后散步。',
    '卡3：护士试行调整后的二十分钟散步方案，同时记录强度是否合适。',
    '卡4：咨询者比较试行时的头晕记录，并据此调低第二天的运动强度。',
    '卡5：咨询者修订建议时，明确写出“夜班后疲劳时”，并复核这项适用条件。',
    '卡6：另一位读者只核查既有建议是否适合自己的白班作息，尚未修改该建议。',
  ];
  const universe = '本地模拟练习的7张行动记录卡（仅比较这一组记录）';
  for (var i = 0; i < records.length; i++) {
    node(
        'record$i',
        String.fromCharCodes(
            records[i].replaceFirst(RegExp(r'^卡\d+[：:]'), '').runes.take(32)),
        '本地模拟：${records[i]} 这是限定的练习记录，可观察的动作、对象和条件只指本卡。',
        kind: 'experience');
  }
  for (var i = 0; i < labels.length; i++) {
    node('activity$i', labels[i],
        '在本次有限记录中，明确呈现“${labels[i]}”活动的记录卡；本组成员为卡$i和卡${i + 1}。',
        observed: records[i + 1]);
    edge('practical', 'activity$i', mediation: true);
    edge('activity$i', 'record$i', instance: true);
    edge('activity$i', 'record${i + 1}', instance: true);
  }
  for (var i = 0; i < labels.length - 1; i++) {
    relations.add({
      'placement': 'A',
      'status': 'definition',
      'statement': '教学模拟：相邻活动可在同一张记录卡上同时出现；交叠表示共同成员，不表示活动之间的因果。',
      'references': refs,
      'node_ids': ['activity$i', 'activity${i + 1}'],
      'scope': {
        'relation_type': 'overlap',
        'relation_scope': 'extension',
        'universe': universe,
        'set_a': labels[i],
        'set_b': labels[i + 1],
        'criterion_a': '在本组记录卡中，出现“${labels[i]}”这一活动；成员为卡$i、卡${i + 1}。',
        'criterion_b':
            '在本组记录卡中，出现“${labels[i + 1]}”这一活动；成员为卡${i + 1}、卡${i + 2}。',
        'basis': text,
        'justification':
            '原句提醒生活建议须联系个体条件。此有限练习只帮助区分阅读、判断与试行，不声称是原作者提供的案例，也不推广到全部生活。',
        'only_a': records[i],
        'intersection': records[i + 1],
        'only_b': records[i + 2],
        'illustration': true
      }
    });
  }
  return SemanticScope.parse({
    'schema_version': 2,
    'recommended_view': 'hierarchy',
    'concepts': concepts,
    'hierarchy': hierarchy,
    'relations': relations,
    'grounds': [],
    'judgments': [
      {
        'placement': 'A',
        'question': readingMapPurpose,
        'common': '一般建议需要回到具体处境判断。',
        'difference': '声称普遍适用，与说明针对何种个人条件，是不同的命题规定。',
        'decisive': '是否说明并检验适用条件，会改变建议能否用于这一位夜班工作者的判断。',
        'basis': '将原句主题带入一个明确标记的有限模拟。',
        'references': refs
      }
    ]
  }, [
    ScopeSource('A', text)
  ]);
}
