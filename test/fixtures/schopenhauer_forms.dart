// Offline analytical definitions for projection tests, NOT paid AI output or
// a claim that the quoted author asserted these set-theoretic definitions.
const wangQuote = '“持志如心痛。一心在痛上，岂有工夫说闲话、管闲事？”\n“初学工夫如此用亦好。……若只死死守着，恐于工夫上又发病。”';
const practiceUniverse = '本次分析的修习片段';
Map<String, dynamic> practiceNode(String id, String label, String definition,
        {String kind = 'concept', String status = 'definition', String universe = practiceUniverse}) => {
  'id': id, 'label': label, 'definition': definition, 'kind': kind, 'status': status,
  'universe': universe, 'references': ['e1'],
};
Map<String, dynamic> classEdge(String parent, String child, String differentia) => {
  'parent': parent, 'child': child, 'kind': 'subtype',
  'differentia': differentia, 'explanation': '按本次明示定义，保留上位规定并增加：$differentia；不冒称原句已作此分类。',
  'basis_kind': 'analytic_definition', 'references': ['e1'],
};
const possibleRegions = {
  'Z:P': ['初学者将持守道德志向作为练习目标', '', '练习书法而未以持志为目标'],
  'F:Z': ['分心于闲谈后把注意收回道德志向的练习', '', '通过审视具体道德选择来持志，未采用专注收摄方法'],
  'R:F': ['情境改变仍僵固地保持同一专注方式', '', '专注当前志向并能随眼前任务调整注意'],
  'B:P': ['初次练习持志时收回分散的注意', '', '已有熟练基础者进行持志练习'],
  'B:Z': ['初学者专注于持志练习', '初学书法而未以持志为目标', '已有熟练基础者进行持志练习'],
  'F:B': ['初学者听见闲谈后将注意收回持志练习', '已有熟练基础者采用专注收摄方法持志', '初学书法而未采用专注收摄式持志'],
  'B:R': ['初学者在需要变通时仍机械专注同一方式', '初学者能随当前任务变通，没有固着', '已有熟练基础者在需要变通时仍僵固守着同一方式'],
};
Map<String, dynamic> scopeEdge(String a, String b, String type,
    {String intersectionId = ''}) => {
  'placement': 'A', 'statement': '在本次明示的修习片段定义下，核对两种成员判准；可能情形不是历史事实。',
  'status': 'definition', 'node_ids': [a,b], 'intersection_id': intersectionId, 'references': ['e1'],
  'scope': {
    'relation_type': type, 'relation_scope': 'extension', 'universe': practiceUniverse,
    'basis_kind': 'analytic_definition', 'basis_ref': 'e1',
    'justification': '按以下分析性定义进行有限建模，不归为作者原话；不以交集证明因果。',
    'intersection': possibleRegions['$a:$b']![0],
    'only_a': possibleRegions['$a:$b']![1],
    'only_b': possibleRegions['$a:$b']![2], 'illustration': false,
  }
};
Map<String, dynamic> wangForms() => {
  'schema_version': 5, 'material_kind': 'argument', 'recommended_view': 'hierarchy',
  'evidence': [{'id': 'e1', 'source': 'A', 'excerpt': wangQuote}],
  'concepts': [
    practiceNode('P','修习片段','为某一修习目标进行练习的可辨认活动片段。'),
    practiceNode('Z','以持志为目标','修习片段中，以持守道德志向为目标者；不将此目标等同单纯注意。'),
    practiceNode('F','专注收摄式持志','以持志为目标的片段中，以收回分散注意并持续着意于该目标为方法者。'),
    practiceNode('B','初学阶段的修习','修习片段中，练习者处于相应工夫的初学阶段者；这是阶段而非方法。'),
    practiceNode('J','初学中的专注持志','专注收摄式持志片段中，练习者同时处于相应工夫初学阶段者。'),
    practiceNode('R','固着式专注持志','本次限定为专注收摄式持志片段中，不顾具体情境而僵固守住同一注意方式者；不是所有专注或所有持志。'),
    practiceNode('M','收回分散的注意','对注意从旁务回到当前目标这一可辨别共同规定的概括。', status:'interpretation', universe:'注意活动'),
    practiceNode('E','听见闲谈后把注意收回练习','教学情境：一位初学者正练习持志，听到旁边闲谈后停下接话，把注意重新放回当前练习；用于理解所列规定，非原文史实。',kind:'experience',status:'example',universe:'教学情境'),
    practiceNode('ER','需要变通时仍机械守着原方法','教学情境：练习条件已经改变，一位练习者仍反复机械执行同一动作，无法回应眼前任务；用于说明本次固着判准，不证明原句医学因果。',kind:'experience',status:'example',universe:'教学情境'),
    practiceNode('pain','心痛的注意情境','原句以心痛时注意集中在痛上作类比；只取注意集中这一共同点，不转成持志的下位类。',status:'interpretation',universe:'类比意象'),
  ],
  'hierarchy': [
    classEdge('P','Z','以持志为目标'),classEdge('P','B','处于初学阶段'),
    classEdge('Z','F','采用专注收摄方法'),classEdge('F','J','同时处于初学阶段'),
    classEdge('B','J','同时专注收摄以持志'),classEdge('F','R','固着而不顾情境'),
    {'parent':'F','child':'M','kind':'mediation','explanation':'通过收回分散注意这一规定理解专注方式，并不把注意活动当作修习片段的子类。','references':['e1']},
    {'parent':'M','child':'E','kind':'instance','explanation':'教学情境让抽象的注意变化返回可辨别动作，不作事实证明。','references':['e1']},
    {'parent':'J','child':'E','kind':'instance','explanation':'初学且采用专注方式的可能片段。','references':['e1']},
    {'parent':'R','child':'ER','kind':'instance','explanation':'依本次限定呈现固着的可能情境。','references':['e1']},
  ],
  'relations': [
    scopeEdge('Z','P','subset'),scopeEdge('F','Z','subset'),scopeEdge('R','F','subset'),
    scopeEdge('B','P','subset'),scopeEdge('B','Z','overlap'),
    scopeEdge('F','B','overlap',intersectionId:'J'),scopeEdge('B','R','overlap'),
  ],
  'meaning_links': [
    {'from':'pain','to':'M','kind':'analogy','status':'interpretation','explanation':'只在注意集中这一规定上类比，不能据此等同目标、疼痛经验或外延。','references':['e1']}
  ],
  'propositions': [{
    'id':'caution','subject':'只死死守着的练习方式','predicate':'于工夫上发病',
    'quantifier':'有条件的可能','polarity':'肯定','condition':'若只死死守着','modality':'恐，表示担忧的可能性',
    'conclusion':'若只死死守着，恐于工夫上又发病。','evidence_ref':'e1','origin':'text_claim',
  }],
};
Map<String,dynamic> wangExpansion() => {
  'schema_version':5,'evidence':[{'id':'e1','source':'A','excerpt':wangQuote}],
  'concepts':[practiceNode('new-common','初学中的固着专注持志','固着式专注持志片段中，同时处于相应工夫初学阶段者。')],
  'hierarchy':[classEdge('R','new-common','同时处于初学阶段'),classEdge('B','new-common','同时固着式专注持志')],
  'relations':[scopeEdge('B','R','overlap',intersectionId:'new-common')],
};
