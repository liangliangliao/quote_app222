// Deterministic UI/contract fixtures, not results from a paid model or proof
// that the proposed literary interpretation is the author's unique meaning.
const winterQuote = '在隆冬，我终于知道，我身上有一个不可战胜的夏天。';
const willingQuote = '人宁愿意欲虚无，也不愿不欲。';

Map<String, dynamic> meaningNode(String id, String label, String definition,
        {String kind = 'concept', String status = 'interpretation'}) =>
    {
      'id': id,
      'label': label,
      'definition': definition,
      'kind': kind,
      'status': status,
      'references': ['e1']
    };
Map<String, dynamic> meaningLink(
        String from, String to, String kind, String explanation,
        {String status = 'interpretation'}) =>
    {
      'from': from,
      'to': to,
      'kind': kind,
      'explanation': explanation,
      'status': status,
      'references': ['e1']
    };

Map<String, dynamic> winterMap() => {
      'schema_version': 4,
      'material_kind': 'metaphor',
      'recommended_view': 'circles',
      'evidence': [
        {'id': 'e1', 'source': 'A', 'excerpt': winterQuote}
      ],
      'propositions': [
        {
          'id': 'report',
          'subject': '说话者',
          'predicate': '发现内在的夏天',
          'quantifier': '个别自述',
          'polarity': '肯定',
          'condition': '',
          'modality': '经验自述与文学隐喻',
          'origin': 'text_claim',
          'evidence_ref': 'e1',
          'conclusion': '说话者在隆冬中发现内在的夏天，表达外在处境与内在生命力的反差。',
        }
      ],
      'concepts': [
        meaningNode('winter', '隆冬意象', '原句采用的严冬意象；不是对实际气温的观察报告。',
            status: 'text_claim'),
        meaningNode('summer', '不可战胜的夏天', '原句置于“我身上”的夏天意象，不能直接等同于气象季节。',
            status: 'text_claim'),
        meaningNode('strength', '内在生命力', '对“不可战胜的夏天”的一种解释：在困境中仍保有的生命活力与坚韧。'),
        meaningNode(
            'report-event', '说话者自述发现内在的夏天', '原文所记述的这一次发现；材料是一项自述，不能由此证明普遍心理规律。',
            kind: 'experience', status: 'text_claim'),
      ],
      'hierarchy': [
        {
          'parent': 'strength',
          'child': 'report-event',
          'kind': 'grounding',
          'explanation': '对内在生命力的解释回到这一具体自述材料，不另造人物经历。',
          'references': ['e1'],
        }
      ],
      'meaning_links': [
        meaningLink(
            'winter', 'summer', 'contrast', '隆冬与夏天形成相反意象，突出所处背景与内在发现的反差。',
            status: 'text_claim'),
        meaningLink('summer', 'strength', 'metaphor',
            '将“不可战胜的夏天”理解为内在生命力；这是有语境根据的隐喻解释，不是夏天包含生命力。'),
        meaningLink('report-event', 'summer', 'predication',
            '说话者报告所发现的内容是自身的“不可战胜的夏天”。',
            status: 'text_claim'),
      ],
      'relations': [],
      'grounds': [],
      'judgments': [],
    };

Map<String, dynamic> winterExpansion({bool orphan = false}) => {
      'schema_version': 4,
      'material_kind': 'metaphor',
      'evidence': [
        {'id': 'e1', 'source': 'A', 'excerpt': winterQuote}
      ],
      'concepts': [
        meaningNode(
            'winter/adversity', '艰难处境', '对隆冬意象的一种解释：生活中的艰难处境；原句没有提供具体困境的事实。')
      ],
      'hierarchy': [],
      'meaning_links': orphan
          ? []
          : [
              meaningLink('winter', 'winter/adversity', 'metaphor',
                  '严寒意象可用来说明艰难处境，这是对意象的解释而非下位分类。'),
              meaningLink('winter/adversity', 'strength', 'contrast',
                  '以外在艰难对照内在生命力，连接原图既有概念，不从二者反差推导必然因果。'),
            ],
    };
