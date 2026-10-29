import 'self_os_codec.dart';

const osEpistemicLabels = {
  'fact': '已核实事实',
  'personal': '个人实证',
  'external': '外部证据',
  'inference': '概率推断',
  'simulation': '情景模拟',
  'unknown': '未知',
};
const osMechanisms = {
  'current': '当前手段',
  'alternative': '同类替代',
  'ability': '能力匹配',
  'transition': '过渡方案',
  'combination': '组合方案',
  'conditions': '改变条件',
  'experiment': '低成本实验',
  'wait': '等待 / 不行动',
};
const osAttentionStages = {
  'foreground': '前景',
  'midground': '中景',
  'background': '背景',
  'omitted': '尚未进入考虑',
};
const osEndorsement = {
  'known': '知道',
  'believed': '相信',
  'valued': '长期重视',
  'available': '现场能想起',
  'linked': '已接上动作',
};
const osGapKinds = {
  'fact': '事实',
  'consequence': '后果',
  'time': '时间',
  'alternative': '替代方案',
  'counter': '反证',
  'motive': '动机 / 欲求',
};
const osRepresentationKinds = {
  'option': '选项缺口',
  'valence': '收益 / 代价缺口',
  'temporal': '时间截断',
  'causal': '因果截断',
  'abstraction': '抽象度缺口',
  'cumulative': '累积缺口',
  'conditional': '条件 / 概率缺口',
};
const osHorizons = {'now': '现在', 'near': '近期', 'long': '长期 / 重复后'};
const osValences = {'benefit': '收益', 'cost': '代价', 'mixed': '收益与代价并存'};
const osOptionDeltas = {
  'opened': '新增',
  'preserved': '保留',
  'easier': '变容易',
  'harder': '变困难',
  'deferred': '推迟',
  'foreclosed': '实质关闭',
};
const osInterventionTypes = {
  'read': '阅读可信材料',
  'reflect': '结构化反思',
  'retrieve': '获取资料',
  'verify': '核验事实',
  'rehearse': '预演现场',
  'simulate': '条件化后果模拟',
  'experiment': '低成本现实实验',
  'vicarious': '有来源的代理经验',
};
const osPreparationWindows = {
  'now': '现在',
  'evening': '决策前一晚',
  'before30': '决策前 30 分钟',
  'onsite': '行动现场',
};
const osChangeObjects = {
  'unknown': '尚未验证',
  'nature': '稳定倾向',
  'skill': '可训练技能',
  'habit': '情境行为',
  'cognition': '认知习惯',
  'environment': '环境条件',
  'limit': '现实硬限制',
};
const osJamesModes = {
  'unknown': '暂不足以分类',
  'rational': 'I · 理性澄清',
  'external': 'II · 外部偶然',
  'impulse': 'III · 内部自发爆发',
  'values': 'IV · 价值尺度变化',
  'effort': 'V · 努力决意',
};
const osPhases = {
  'expand': '扩面',
  'filter': '筛选',
  'experiment': '实验',
  'commit': '承诺',
  'protect': '守护',
  'revise': '修订',
};

/// JSON records have stable identities. Typed accessors keep absent observations
/// distinct from zero; snapshots always copy, including nested graph/trace data.
abstract class OsEntity {
  OsEntity(Map<String, dynamic> input) : data = osClone(input) {
    if (text('id').isEmpty) data['id'] = selfOsId();
  }
  final Map<String, dynamic> data;
  String get id => text('id');
  String text(String key) => osText(data[key]);
  bool flag(String key) => data[key] == true;
  double? number(String key, [double max = 100]) => osNumber(data[key], max);
  List<String> strings(String key) => osStrings(data[key]);
  DateTime? date(String key) => DateTime.tryParse(text(key));
  Map<String, dynamic> toJson() => osClone(data);
}

class OsEvidence extends OsEntity {
  OsEvidence(super.input);
  String get claim => text('claim');
  String get label =>
      osEpistemicLabels.containsKey(text('label')) ? text('label') : 'unknown';
  bool get verified => flag('verified') && text('source').trim().isNotEmpty;
  bool freshAt(DateTime now) =>
      date('observedAt') != null &&
      !date('observedAt')!.isAfter(now) &&
      (date('validUntil') == null || !date('validUntil')!.isBefore(now));
  bool reliableAt(DateTime now) =>
      verified &&
      ['fact', 'personal', 'external'].contains(label) &&
      text('contradiction') == 'clear' &&
      freshAt(now);
  String get effectiveLabel =>
      ['fact', 'personal', 'external'].contains(label) && !verified
          ? 'unknown'
          : label;
}

class OsRoute extends OsEntity {
  OsRoute(super.input);
  String get title => text('title');
  String get mechanism => osMechanisms.containsKey(text('mechanism'))
      ? text('mechanism')
      : 'current';
  String get status => text('status').isEmpty ? 'experimental' : text('status');
  List<String> get evidenceIds => strings('evidenceIds');
  String get structuralKey =>
      '${mechanism.toLowerCase()}:${text('mechanismDetail').trim().replaceAll(RegExp(r'\s+'), '').toLowerCase()}';
  Map<String, double?> get fit => {
        for (final key in [
          'desireFit',
          'abilityFit',
          'personalFit',
          'strengthFit',
          'costAcceptance',
          'realityFit'
        ])
          key: number(key)
      };
  double? get alignment {
    final known = fit.values.whereType<double>().toList();
    return known.isEmpty ? null : known.reduce((a, b) => a + b) / known.length;
  }
}

class OsGap extends OsEntity {
  OsGap(super.input);
  String get kind =>
      osGapKinds.containsKey(text('kind')) ? text('kind') : 'fact';
  String get sensitivity {
    if (text('lowScenario').isEmpty ||
        text('highScenario').isEmpty ||
        text('lowScenario').trim() == text('highScenario').trim() ||
        text('lowChoice').isEmpty ||
        text('highChoice').isEmpty) return 'unknown';
    return text('lowChoice') == text('highChoice') ? 'stable' : 'flip';
  }

  // Model-proposed choices are hypotheses. Only a user's comparison can make
  // an unknown irrelevant to the decision; an AI cannot waive its own gaps.
  bool get important =>
      !flag('irrelevant') &&
      !(flag('sensitivityReviewed') && sensitivity == 'stable');
  bool resolvedBy(List<OsEvidence> evidence, DateTime now) =>
      flag('resolutionConfirmed') &&
      text('resolutionAnswer').trim().isNotEmpty &&
      text('resolutionScope').trim().isNotEmpty &&
      strings('evidenceIds')
          .any((id) => evidence.any((e) => e.id == id && e.reliableAt(now)));
}

class OsConsequence extends OsEntity {
  OsConsequence(super.input);
  String get routeId => text('routeId');
  String get title => text('title');
  int get order => (number('order', 12) ?? 1).toInt().clamp(1, 12);
  String get horizon =>
      osHorizons.containsKey(text('horizon')) ? text('horizon') : 'now';
  String get label =>
      osEpistemicLabels.containsKey(text('label')) ? text('label') : 'unknown';
  bool get relevant => text('relevance') != 'low';
  List<String> get evidenceIds => strings('evidenceIds');
  bool observableAt(DateTime at) => date('observableAfter') != null
      ? !date('observableAfter')!.isAfter(at)
      : horizon != 'long';
}

class OsCausalEdge extends OsEntity {
  OsCausalEdge(super.input);
  String get from => text('from');
  String get to => text('to');
  bool get isLoop => ['reinforcing', 'balancing'].contains(text('loop'));
  List<String> get evidenceIds => strings('evidenceIds');
}

class OsFutureOption extends OsEntity {
  OsFutureOption(super.input);
  String get delta =>
      osOptionDeltas.containsKey(text('delta')) ? text('delta') : 'preserved';
}

class OsIntervention extends OsEntity {
  OsIntervention(super.input);
  String get type =>
      osInterventionTypes.containsKey(text('type')) ? text('type') : 'reflect';
  bool get started => data['before'] is Map;
  bool get completed => date('completedAt') != null;
  DateTime? dueAt(DateTime? moment, DateTime now) {
    if (moment == null) return null;
    if (date('dueAt') != null) return date('dueAt');
    switch (text('window')) {
      case 'evening':
        return DateTime(moment.year, moment.month, moment.day)
            .subtract(const Duration(hours: 4));
      case 'before30':
        return moment.subtract(const Duration(minutes: 30));
      case 'onsite':
        return moment;
      default:
        return date('createdAt') ?? now;
    }
  }
}

class OsStrength extends OsEntity {
  OsStrength(super.input);
  String get title => text('title');
  List<Map<String, dynamic>> get observations => osMaps(data['observations']);
}

class SelfOsV37 {
  final Map<String, dynamic> settings = {
    'risk': 'unassessed',
    'reversible': true,
    'phase': 'expand',
    'mutuallyExclusive': true,
    'changeObject': 'unknown',
  };
  final List<OsRoute> routes = [];
  final List<OsEvidence> evidence = [];
  final List<OsGap> gaps = [];
  final List<OsConsequence> nodes = [];
  final List<OsCausalEdge> edges = [];
  final List<OsFutureOption> futureOptions = [];
  final List<OsIntervention> interventions = [];
  final List<Map<String, dynamic>> knowledgeTraces = [];
  final List<Map<String, dynamic>> causalTraces = [];
  final List<Map<String, dynamic>> decisionTraces = [];
  final List<Map<String, dynamic>> priorCommitments = [];
  Map<String, dynamic>? knowledgeBefore;
  Map<String, dynamic>? pendingProposal;
  String text(String key) => osText(settings[key]);
  bool flag(String key) => settings[key] == true;
  double? number(String key) => osNumber(settings[key]);
  DateTime? get futureMoment => DateTime.tryParse(text('futureMoment'));
  bool get highStakes =>
      text('risk') == 'high' ||
      !flag('reversible') ||
      flag('highOpportunityCost');
  bool get needsLongHorizon =>
      flag('longHorizon') ||
      flag('repeated') ||
      highStakes ||
      futureOptions.isNotEmpty;
  bool get cognitionOpen => knowledgeBefore != null;
  List<OsRoute> get consideredRoutes => routes
      .where((r) => r.status != 'abandoned' && r.status != 'deferred')
      .toList();

  bool dimensionWaived(String routeId, String dimension) =>
      osText(osMap(osMap(settings['coverageExceptions'])[routeId])[dimension])
          .trim()
          .isNotEmpty;

  void ensureCurrentRoute(String problem, String means) {
    if (routes.isNotEmpty) return;
    routes.add(OsRoute({
      'title': means.trim().isEmpty ? problem : means,
      'mechanism': 'current',
      'mechanismDetail': '用户当前提出的手段',
      'source': '用户原始问题',
      'status': 'experimental',
    }));
  }

  Map<String, dynamic> toJson() => {
        'version': 37,
        'settings': osClone(settings),
        'routes': routes.map((e) => e.toJson()).toList(),
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'gaps': gaps.map((e) => e.toJson()).toList(),
        'nodes': nodes.map((e) => e.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'futureOptions': futureOptions.map((e) => e.toJson()).toList(),
        'interventions': interventions.map((e) => e.toJson()).toList(),
        'knowledgeTraces': knowledgeTraces.map(osClone).toList(),
        'causalTraces': causalTraces.map(osClone).toList(),
        'decisionTraces': decisionTraces.map(osClone).toList(),
        'priorCommitments': priorCommitments.map(osClone).toList(),
        'knowledgeBefore':
            knowledgeBefore == null ? null : osClone(knowledgeBefore!),
        'pendingProposal':
            pendingProposal == null ? null : osClone(pendingProposal!),
      };

  factory SelfOsV37.fromJson(Map<String, dynamic> j) {
    if (j.isNotEmpty && j['version'] != 37)
      throw const FormatException('无法读取此版本的 Self OS 决策工作台');
    final s = SelfOsV37();
    s.settings.addAll(osMap(j['settings']));
    s.routes.addAll(osMaps(j['routes']).map(OsRoute.new));
    s.evidence.addAll(osMaps(j['evidence']).map(OsEvidence.new));
    s.gaps.addAll(osMaps(j['gaps']).map(OsGap.new));
    s.nodes.addAll(osMaps(j['nodes']).map(OsConsequence.new));
    s.edges.addAll(osMaps(j['edges']).map(OsCausalEdge.new));
    s.futureOptions.addAll(osMaps(j['futureOptions']).map(OsFutureOption.new));
    s.interventions.addAll(osMaps(j['interventions']).map(OsIntervention.new));
    s.knowledgeTraces.addAll(osMaps(j['knowledgeTraces']));
    s.causalTraces.addAll(osMaps(j['causalTraces']));
    s.decisionTraces.addAll(osMaps(j['decisionTraces']));
    s.priorCommitments.addAll(osMaps(j['priorCommitments']));
    s.knowledgeBefore = j['knowledgeBefore'] is Map
        ? osClone(osMap(j['knowledgeBefore']))
        : null;
    s.pendingProposal = j['pendingProposal'] is Map
        ? osClone(osMap(j['pendingProposal']))
        : null;
    s.validate();
    return s;
  }
  SelfOsV37();
  SelfOsV37 copy() => SelfOsV37.fromJson(toJson());

  void validate() {
    final ids = <String>{};
    for (final e in <OsEntity>[
      ...routes,
      ...evidence,
      ...gaps,
      ...nodes,
      ...edges,
      ...futureOptions,
      ...interventions
    ]) {
      if (!ids.add(e.id)) throw const FormatException('决策记录含重复标识，已保留原数据');
    }
    if (routes.where((r) => r.status == 'active').length > 1)
      throw const FormatException('一次选择只能有一条当前主路线');
    final routeIds = routes.map((e) => e.id).toSet();
    final nodeIds = nodes.map((e) => e.id).toSet();
    for (final node in nodes) {
      if (!routeIds.contains(node.routeId))
        throw const FormatException('因果节点缺少所属路线');
    }
    for (final edge in edges) {
      if (!nodeIds.contains(edge.from) || !nodeIds.contains(edge.to))
        throw const FormatException('因果连线存在未保存的节点');
      if (edge.from == edge.to && !edge.isLoop)
        throw const FormatException('自我反馈必须明确标记回路');
    }
    final nodeById = {for (final n in nodes) n.id: n};
    for (final edge in edges) {
      final a = nodeById[edge.from]!, b = nodeById[edge.to]!;
      if (a.routeId != b.routeId)
        throw const FormatException('互斥路线各自展开，不能把一条路线的后果接成另一条');
      if (!edge.isLoop && b.order <= a.order)
        throw const FormatException('普通因果边应指向更高阶后果；反馈请明确标记回路');
      if (edge.isLoop && edge.text('breakCondition').trim().isEmpty)
        throw const FormatException('反馈回路需要记录打断条件，未知请明确说明');
    }
    for (final intervention in interventions) {
      if (!gaps.any((g) => g.id == intervention.text('gapId')))
        throw const FormatException('认识准备必须关联已有缺口');
    }
    for (final delta in futureOptions) {
      if (nodeById[delta.text('nodeId')]?.routeId != delta.text('routeId') ||
          !routeIds.contains(delta.text('routeId')) ||
          !nodeIds.contains(delta.text('nodeId')))
        throw const FormatException('未来路径变化必须关联路线与因果节点');
    }
  }
}
