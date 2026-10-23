import 'self_os_models.dart';

/// A proposal never has write access to commitment, observed results, verified
/// evidence, route activation or the user's risk assessment.
class OsAnalysisProposal {
  OsAnalysisProposal(this.data);
  final Map<String, dynamic> data;
  String get summary => osText(data['summary']);
  int get count => [
        'routes',
        'gaps',
        'nodes',
        'edges',
        'futureOptions',
        'interventions',
        'motiveChanges'
      ].fold(0, (n, k) => n + osMaps(data[k]).length);

  static const instructions = <String, String>{
    'routes':
        '''围绕用户已经确认的欲求扩展结构不同的候选路线。保留当前方案，覆盖适用的同类替代、能力匹配、过渡、组合、改变条件、实验、等待。相同机制不同名称不是新路径。不强求八类齐全。比较欲求、能力、代价、力量、现实与机会成本。已有机制充分或新信息边际低时说明停止原因。''',
    'gmrc':
        '''执行通用认识补全 GMRC。先标准化选项，按 option/valence/temporal/causal/abstraction/cumulative/conditional 检查结构，不依赖生活领域关键词。区分六类信息缺口。对关键未知提供合理的低/高情景与各自可能选择，用来判断是否翻转。为竞争选项建立同深度的有条件后果图，覆盖收益/代价、现在/近期/长期、直接/间接、单次/累积；不适用的维度说明，不捏造。把抽象后果转为可观察的现实。明确新认识可能新增/增强/削弱/使哪些动机失效。''',
    'horizon':
        '''执行 LHCP。只继续展开能够改变决定的高价值中间状态，保留 2nd/3rd+ order，默认3–7条主链。每节点最多2–4个关键条件分支（base/upside/downside）。有依据时记录强化/平衡闭环、打断条件、累积阈值、路径依赖和可逆窗口，不无限展开环。输出未来路径的 opened/preserved/easier/harder/deferred/foreclosed 变化，关联当前路线与节点。远期推断自动降低确定性；无信息价值时返回明确 stopReason，不能编造长故事。''',
    'prepare':
        '''只有明确未来时刻 T* 时才生成1–3项最小认识准备。每项绑定已有缺口 id、可追溯来源或待获取来源、具体动作、时点与预期 K/M/Att 变化。复杂知识提前；现场最多一条观念和第一动作，只可用 rehearse。按关键未知是否可能翻转选择、个人认知指纹、负担与时效安排；低敏感性和低信息增益时停止。不要生成无关阅读清单，不声称已经检索外部资料。''',
    'alignment':
        '''先区分稳定倾向、技能、情境行为、认知、环境、硬限制与尚未验证。当前不能不等于永远不能。根据已有力量证据提出 力量→当前弱点→新作用对象/条件→具体动作 的桥接，保留反证和过度使用护栏。只能建议候选，不能把问卷或一次行为升级为稳定性格。''',
  };

  static const schema = '''返回 JSON 对象，所有集合只输出任务相关项：
{"summary":"本次发现、依据与未知", "stopReason":"何时停止或不适用的原因",
"signals":{"longHorizon":false,"repeated":false,"changeObject":"unknown/nature/skill/habit/cognition/environment/limit","risk":"low/medium/high","reason":"结构证据"},
"routes":[{"id":"临时唯一id","title":"","mechanism":"current/alternative/ability/transition/combination/conditions/experiment/wait","mechanismDetail":"结构为何不同","desire":"服务的欲求","ability":"能力依据/未知","cost":"完整代价","reality":"现实约束","opportunityCost":"舍弃项","strength":"可用力量与依据","source":"候选依据"}],
"gaps":[{"id":"临时id","kind":"fact/consequence/time/alternative/counter/motive","question":"一个关键问题","reason":"为何会改变选择","access":"private/public/experience","lowScenario":"合理一种情况","highScenario":"另一种情况","lowChoice":"对应路线id或空","highChoice":"对应路线id或空"}],
"nodes":[{"id":"临时id","routeId":"已有或本次路线id","title":"具体结果/状态","concrete":"可观察的现实含义","order":1,"horizon":"now/near/long","valence":"benefit/cost/mixed","stateType":"能力/资源/关系/健康/责任/机会等","relevance":"high/medium/low","label":"inference/simulation/unknown","evidenceIds":["只能引用实际已提供的证据id"],"cumulative":false,"threshold":"阈值条件；未知保持未知","lockIn":"改道成本/锁定","reversibleWindow":"可回头的条件/窗口","counter":"反证/未知","prune":false,"pruneReason":""}],
"edges":[{"id":"临时id","from":"节点id","to":"节点id","condition":"何种条件下可能","basis":"因果依据/只是推断","label":"inference/simulation/unknown","evidenceIds":[],"branch":"base/upside/downside","signal":"能观察的分支触发信号","loop":"none/reinforcing/balancing","breakCondition":"回路打断条件","probabilityNote":"有证据才给范围，未知不编百分比"}],
"futureOptions":[{"id":"临时id","routeId":"路线id","nodeId":"因果节点id","title":"未来可行路径","delta":"opened/preserved/easier/harder/deferred/foreclosed","condition":"条件与不确定性","evidenceIds":[]}],
"interventions":[{"id":"临时id","gapId":"已有或本次缺口id","type":"read/reflect/retrieve/verify/rehearse/simulate/experiment/vicarious","task":"可验收动作","source":"信息来源或明确待核验的获取办法","window":"now/evening/before30/onsite","expectedChange":"预期K/M/Att怎样变化"}],
"motiveChanges":[{"motiveId":"已有id或空","title":"候选动机","optionId":"路线id","side":"for/against","change":"added/strengthened/weakened/invalidated","reason":"哪项认识导致变化","evidenceIds":[]}],
"bridges":[{"strengthId":"已有力量id或空","strength":"候选力量","weakness":"当前阻碍","mechanism":"怎样改变作用方式","action":"具体动作","guardrail":"过度使用边界","evidence":"真实来源或待验证"}]}
不要输出 verified、实际结果、承诺、主路线状态、已完成干预或用户主观概率。图的非反馈边应从低阶指向高阶，反馈用 loop 明确标记。不要用故事填满未知。''';

  factory OsAnalysisProposal.parse(Map<String, dynamic> raw, SelfOsCase c) {
    if (osText(raw['summary']).trim().isEmpty)
      throw const FormatException('分析缺少依据与未知说明，原记录已保留');
    final data = <String, dynamic>{
      'summary': osText(raw['summary']),
      'stopReason': osText(raw['stopReason'])
    };
    final idMap = <String, String>{};
    final known = <String>{
      ...c.v37.routes.map((r) => r.id),
      ...c.v37.nodes.map((n) => n.id),
      ...c.v37.gaps.map((g) => g.id)
    };
    const limits = {
      'routes': 10,
      'gaps': 12,
      'nodes': 35,
      'edges': 42,
      'futureOptions': 14,
      'interventions': 3,
      'motiveChanges': 15,
      'bridges': 5
    };
    const fields = {
      'routes': [
        'id',
        'title',
        'mechanism',
        'mechanismDetail',
        'desire',
        'ability',
        'cost',
        'reality',
        'opportunityCost',
        'strength',
        'source'
      ],
      'gaps': [
        'id',
        'kind',
        'question',
        'reason',
        'access',
        'lowScenario',
        'highScenario',
        'lowChoice',
        'highChoice'
      ],
      'nodes': [
        'id',
        'routeId',
        'title',
        'concrete',
        'order',
        'horizon',
        'valence',
        'stateType',
        'relevance',
        'label',
        'evidenceIds',
        'cumulative',
        'threshold',
        'lockIn',
        'reversibleWindow',
        'counter',
        'prune',
        'pruneReason'
      ],
      'edges': [
        'id',
        'from',
        'to',
        'condition',
        'basis',
        'label',
        'evidenceIds',
        'branch',
        'signal',
        'loop',
        'breakCondition',
        'probabilityNote'
      ],
      'futureOptions': [
        'id',
        'routeId',
        'nodeId',
        'title',
        'delta',
        'condition',
        'evidenceIds'
      ],
      'interventions': [
        'id',
        'gapId',
        'type',
        'task',
        'source',
        'window',
        'expectedChange'
      ],
      'motiveChanges': [
        'motiveId',
        'title',
        'optionId',
        'side',
        'change',
        'reason',
        'evidenceIds'
      ],
      'bridges': [
        'strengthId',
        'strength',
        'weakness',
        'mechanism',
        'action',
        'guardrail',
        'evidence'
      ],
    };
    for (final key in fields.keys) {
      final rows = osMaps(raw[key]);
      if (rows.length > limits[key]!)
        throw FormatException('返回的 $key 超过本次认知负荷上限，请缩小范围重试');
      data[key] = <Map<String, dynamic>>[];
      for (final row in rows) {
        final clean = <String, dynamic>{
          for (final k in fields[key]!)
            if (row.containsKey(k)) k: row[k]
        };
        if (fields[key]!.contains('id')) {
          final original = osText(clean['id']);
          if (original.isEmpty ||
              idMap.containsKey(original) ||
              known.contains(original))
            throw const FormatException('候选标识重复或缺失，不能覆盖已有记录');
          clean['id'] = idMap[original] = selfOsId();
        }
        if (key == 'nodes' || key == 'edges') {
          clean['label'] =
              ['inference', 'simulation', 'unknown'].contains(clean['label'])
                  ? clean['label']
                  : 'unknown';
        }
        if (fields[key]!.contains('evidenceIds')) {
          clean['evidenceIds'] = osStrings(clean['evidenceIds'])
              .where((id) => c.v37.evidence.any((e) => e.id == id))
              .toList();
          if (osStrings(row['evidenceIds']).length !=
              osStrings(clean['evidenceIds']).length)
            throw const FormatException('分析引用了不存在的证据，未采用这些候选');
        }
        if (key == 'motiveChanges' &&
            (osText(clean['motiveId']).isNotEmpty &&
                !c.motives.any((m) => m.id == clean['motiveId']))) {
          throw const FormatException('动机变化引用了不存在的动机');
        }
        if (key == 'routes') {
          if (!osMechanisms.containsKey(clean['mechanism']) ||
              osText(clean['mechanismDetail']).isEmpty ||
              osText(clean['title']).isEmpty)
            throw const FormatException('候选路线缺少具体机制');
          clean['status'] = 'experimental';
        }
        if (key == 'gaps' &&
            (!osGapKinds.containsKey(clean['kind']) ||
                osText(clean['question']).isEmpty ||
                !['private', 'public', 'experience'].contains(clean['access'])))
          throw const FormatException('信息缺口缺少有效分类或获取方式');
        if (key == 'nodes' &&
            (osText(clean['title']).isEmpty ||
                !osHorizons.containsKey(clean['horizon']) ||
                !osValences.containsKey(clean['valence'])))
          throw const FormatException('因果节点缺少时间、收益代价或具体后果');
        if (key == 'futureOptions' &&
            (!osOptionDeltas.containsKey(clean['delta']) ||
                osText(clean['title']).isEmpty))
          throw const FormatException('未来路径需要具体名称与有效的变化类型');
        if (key == 'edges' &&
            (osText(clean['condition']).isEmpty ||
                osText(clean['basis']).isEmpty))
          throw const FormatException('因果边必须保留条件和依据');
        if (key == 'interventions') {
          if (c.v37.futureMoment == null ||
              !osInterventionTypes.containsKey(clean['type']) ||
              !osPreparationWindows.containsKey(clean['window']) ||
              ['task', 'source', 'expectedChange']
                  .any((k) => osText(clean[k]).isEmpty))
            throw const FormatException('认识准备缺少未来时刻、来源或预期变化');
          if (clean['window'] == 'onsite' && clean['type'] != 'rehearse')
            throw const FormatException('现场不能堆叠复杂信息，改在决策前准备');
          clean['createdAt'] = DateTime.now().toIso8601String();
        }
        (data[key] as List).add(clean);
      }
    }
    for (final key in fields.keys) {
      for (final row in osMaps(data[key])) {
        for (final ref in [
          'routeId',
          'nodeId',
          'from',
          'to',
          'gapId',
          'lowChoice',
          'highChoice',
          'optionId'
        ]) {
          if (row.containsKey(ref) && osText(row[ref]).isNotEmpty) {
            final value = osText(row[ref]);
            row[ref] = idMap[value] ?? value;
            if (!known.contains(value) && !idMap.containsKey(value))
              throw const FormatException('候选引用了未提供的路线、节点或缺口');
          }
        }
      }
      // osMaps copies maps, so explicitly persist the remapped rows.
      data[key] = osMaps(data[key])
          .map((row) => {
                ...row,
                for (final ref in [
                  'routeId',
                  'nodeId',
                  'from',
                  'to',
                  'gapId',
                  'lowChoice',
                  'highChoice',
                  'optionId'
                ])
                  if (row.containsKey(ref))
                    ref: idMap[osText(row[ref])] ?? row[ref],
              })
          .toList();
    }
    final signals = osMap(raw['signals']);
    data['signals'] = {
      'longHorizon': signals['longHorizon'] == true,
      'repeated': signals['repeated'] == true,
      'changeObject': osChangeObjects.containsKey(signals['changeObject'])
          ? signals['changeObject']
          : 'unknown',
      'risk': ['low', 'medium', 'high'].contains(signals['risk'])
          ? signals['risk']
          : 'unassessed',
      'reason': osText(signals['reason']),
    };
    final proposal = OsAnalysisProposal(data);
    if (proposal.count == 0 &&
        osMaps(data['bridges']).isEmpty &&
        osText(data['stopReason']).isEmpty)
      throw const FormatException('没有可用候选或明确停止依据');
    proposal.preview(c.v37).validate();
    return proposal;
  }

  SelfOsV37 preview(SelfOsV37 state) {
    final copy = state.copy();
    copy.routes.addAll(osMaps(data['routes']).map(OsRoute.new));
    copy.gaps.addAll(osMaps(data['gaps']).map(OsGap.new));
    copy.nodes.addAll(osMaps(data['nodes']).map(OsConsequence.new));
    copy.edges.addAll(osMaps(data['edges']).map(OsCausalEdge.new));
    copy.futureOptions
        .addAll(osMaps(data['futureOptions']).map(OsFutureOption.new));
    copy.interventions
        .addAll(osMaps(data['interventions']).map(OsIntervention.new));
    final signals = osMap(data['signals']);
    if (signals['longHorizon'] == true) copy.settings['longHorizon'] = true;
    if (signals['repeated'] == true) copy.settings['repeated'] = true;
    // Inferred risk can raise attention, never silently lower the user's gate.
    if (signals['risk'] == 'high') {
      copy.settings['riskSuggestion'] = 'high';
      copy.settings['riskSuggestionReviewed'] = false;
    }
    copy.settings['alignmentSuggestion'] = signals['changeObject'];
    copy.settings['analysisSummary'] = summary;
    copy.settings['stopReason'] = osText(data['stopReason']);
    copy.settings['bridgeSuggestions'] = osMaps(data['bridges']);
    copy.pendingProposal = null;
    copy.validate();
    return copy;
  }
}
