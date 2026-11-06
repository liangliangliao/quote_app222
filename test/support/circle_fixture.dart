/// A bounded teaching model with explicit regions and source locators, not an
/// assertion that either philosophical quote proves a set-theoretic law.
Map<String, dynamic> teachingCircleFixture(String sourceA, String sourceB,
        {String type = 'overlap',
        String setA = '经历挑战',
        String setB = '愉悦体验'}) =>
    {
      'schema_version': 3,
      'recommended_view': 'circles',
      'relations': [
        {
          'placement': 'cross',
          'statement': '在明示判准下对三张模拟经历卡分类，用于练习，不推广到作者主张。',
          'status': 'definition',
          'references': [
            {'source': 'A', 'excerpt': sourceA},
            {'source': 'B', 'excerpt': sourceB}
          ],
          'scope': {
            'relation_type': type,
            'relation_scope': 'extension',
            'universe': '三张明示判准的模拟学习经历卡',
            'set_a': setA,
            'set_b': setB,
            'criterion_a': type == 'subset' ? '卡1满足较窄判准' : '卡1与卡2满足判准A',
            'criterion_b': type == 'subset' ? '卡1与卡2满足较宽判准' : '卡2与卡3满足判准B',
            'basis': sourceA,
            'justification': '按所列卡片定义核对成员，不以交集证明因果。',
            'intersection': type == 'subset' ? '卡1，满足窄类与宽类' : '卡2，挑战与愉悦均有记录',
            'only_a': type == 'subset' ? '' : '卡1，艰难完成练习而无乐趣',
            'only_b': type == 'subset' ? '卡2，只满足宽类' : '卡3，欣赏风景而无挑战',
            'illustration': true,
          },
        }
      ],
    };
