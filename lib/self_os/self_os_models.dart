import 'dart:convert';
import 'self_os_codec.dart';
import 'self_os_v37_models.dart';
import 'self_os_v37_rules.dart';
import 'self_os_guide_models.dart';
export 'self_os_codec.dart';
export 'self_os_v37_models.dart';
export 'self_os_guide_models.dart';

enum SelfOsEngine { desire, motivation, cognition, action, mirror }

extension SelfOsEngineLabel on SelfOsEngine {
  String get label => const ['真正欲求', '动机与环境', '认识纠错', '行动现场', '行动之镜'][index];
  String get question => const [
        '我真正可能想要什么？',
        '什么能在现场推动或阻止我？',
        '哪些认识需要现实检验？',
        '到那个时刻，怎样迈出第一步？',
        '这一次现实教会了我什么？'
      ][index];
}

const selfOsBlockers = <String, String>{
  'unknown': '还不确定，需要先辨别',
  'desire': '目标 / 欲求不匹配',
  'means': '想要，但当前路径不适合',
  'cognition': '认识错误、遗漏或时间尺度失真',
  'environment': '环境或现场阻力过强',
};
const selfOsRouteStates = <String, String>{
  'active': '当前主路线',
  'secondary': '次要保留',
  'deferred': '延期',
  'experimental': '低成本实验',
  'abandoned': '依据证据舍弃',
};
const selfOsCognitiveOperations = [
  '事实纠错',
  '遗漏补全',
  '时间重构',
  '方向重构',
  '手段重构',
  '意义重构',
  '分类 / 概念重构'
];
const selfOsMotiveTypes = [
  '即时收益',
  '损失避免',
  '生存与安全',
  '身份与尊严',
  '自我效能',
  '责任与承诺',
  '竞争与挑战',
  '好奇与自主',
  '后悔防止',
  '机会成本',
  '社会关系',
  '长期目标',
  '环境触发',
  '历史成功经验'
];

class SelfOsDesire {
  SelfOsDesire(
      {String? id,
      this.title = '',
      this.source = '用户提出',
      this.support = '',
      this.counter = '',
      this.question = '',
      this.confidence,
      this.verdict = 'pending',
      this.comparison = 'uncompared'})
      : id = id ?? selfOsId();
  final String id;
  String title, source, support, counter, question, verdict, comparison;
  double? confidence;
  bool get accepted => verdict == 'accepted';
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'source': source,
        'support': support,
        'counter': counter,
        'question': question,
        'confidence': confidence,
        'verdict': verdict,
        'comparison': comparison
      };
  factory SelfOsDesire.fromJson(Map<String, dynamic> j) => SelfOsDesire(
      id: osText(j['id']).isEmpty ? null : j['id'],
      title: osText(j['title']),
      source: osText(j['source']),
      support: osText(j['support']),
      counter: osText(j['counter']),
      question: osText(j['question']),
      confidence: osNumber(j['confidence']),
      verdict: osText(j['verdict']).isEmpty ? 'pending' : j['verdict'],
      comparison:
          osText(j['comparison']).isEmpty ? 'uncompared' : j['comparison']);
}

/// Multiple parents support merging branches. Only existing earlier nodes can be
/// parents, keeping the Why graph acyclic and safe to traverse.
class SelfOsWhyNode {
  SelfOsWhyNode(
      {String? id,
      required this.answer,
      this.question = '为什么这对我重要？',
      List<String>? parents})
      : id = id ?? selfOsId(),
        parents = parents ?? [];
  final String id;
  String answer, question;
  List<String> parents;
  Map<String, dynamic> toJson() =>
      {'id': id, 'answer': answer, 'question': question, 'parents': parents};
  factory SelfOsWhyNode.fromJson(Map<String, dynamic> j) => SelfOsWhyNode(
      id: osText(j['id']),
      answer: osText(j['answer']),
      question: osText(j['question']),
      parents: osStrings(j['parents']));
}

class SelfOsMotive {
  SelfOsMotive(
      {String? id,
      this.title = '',
      this.type = '即时收益',
      this.side = 'for',
      this.layer = '理性 / 概念',
      this.kind = '概率推断',
      this.reason = '',
      this.predicted,
      this.credibility,
      this.vividness,
      this.presence,
      this.selected = false,
      this.source = '用户提出',
      this.optionId = '',
      this.desireId = '',
      this.horizon = 'now',
      this.attention = 'midground',
      this.endorsement = 'known',
      this.actionLink = '',
      this.strengthId = '',
      this.importance,
      this.occupancy})
      : id = id ?? selfOsId();
  final String id;
  String optionId,
      desireId,
      horizon,
      attention,
      endorsement,
      actionLink,
      strengthId;
  double? importance, occupancy;
  String title, type, side, layer, kind, reason, source;
  double? predicted, credibility, vividness, presence;
  bool selected;
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'side': side,
        'layer': layer,
        'kind': kind,
        'reason': reason,
        'predicted': predicted,
        'credibility': credibility,
        'vividness': vividness,
        'presence': presence,
        'selected': selected,
        'optionId': optionId,
        'desireId': desireId,
        'horizon': horizon,
        'attention': attention,
        'endorsement': endorsement,
        'actionLink': actionLink,
        'strengthId': strengthId,
        'importance': importance,
        'occupancy': occupancy,
        'source': source
      };
  factory SelfOsMotive.fromJson(Map<String, dynamic> j) => SelfOsMotive(
      id: osText(j['id']).isEmpty ? null : j['id'],
      title: osText(j['title']),
      type: osText(j['type']),
      side: j['side'] == 'against' ? 'against' : 'for',
      layer: osText(j['layer']),
      kind: osText(j['kind']),
      reason: osText(j['reason']),
      predicted: osNumber(j['predicted']),
      credibility: osNumber(j['credibility']),
      vividness: osNumber(j['vividness']),
      presence: osNumber(j['presence']),
      selected: j['selected'] == true,
      optionId: osText(j['optionId']),
      desireId: osText(j['desireId']),
      horizon: osHorizons.containsKey(j['horizon']) ? j['horizon'] : 'now',
      attention: osAttentionStages.containsKey(j['attention'])
          ? j['attention']
          : 'midground',
      endorsement: osEndorsement.containsKey(j['endorsement'])
          ? j['endorsement']
          : 'known',
      actionLink: osText(j['actionLink']),
      strengthId: osText(j['strengthId']),
      importance: osNumber(j['importance']),
      occupancy: osNumber(j['occupancy']),
      source: osText(j['source']));
}

class SelfOsReview {
  SelfOsReview(
      {String? id,
      required this.round,
      required this.outcome,
      required this.result,
      required this.learning,
      required this.context,
      required this.snapshot,
      Map<String, String>? notes,
      Map<String, double>? scores,
      List<String>? effectiveMotives,
      this.motiveFeedbackRecorded = false,
      DateTime? createdAt})
      : id = id ?? selfOsId(),
        notes = notes ?? {},
        scores = scores ?? {},
        effectiveMotives = effectiveMotives ?? [],
        createdAt = createdAt ?? DateTime.now();
  final String id, outcome, result, learning, context;
  final int round;
  final DateTime createdAt;
  final Map<String, dynamic> snapshot;
  final Map<String, String> notes;
  final Map<String, double> scores;
  final List<String> effectiveMotives;
  final bool motiveFeedbackRecorded;
  double? get predictedDiscomfort =>
      osNumber(osMap(snapshot['scores'])['predictedDiscomfort'], 10);
  double? get predictionError =>
      predictedDiscomfort != null && scores['actualDiscomfort'] != null
          ? predictedDiscomfort! - scores['actualDiscomfort']!
          : null;
  Map<String, dynamic> toJson() => {
        'id': id,
        'round': round,
        'outcome': outcome,
        'result': result,
        'learning': learning,
        'context': context,
        'snapshot': snapshot,
        'notes': notes,
        'scores': scores,
        'effectiveMotives': effectiveMotives,
        'motiveFeedbackRecorded': motiveFeedbackRecorded,
        'createdAt': createdAt.toIso8601String()
      };
  factory SelfOsReview.fromJson(Map<String, dynamic> j) => SelfOsReview(
      id: osText(j['id']),
      round: (j['round'] as num?)?.toInt() ?? 1,
      outcome: osText(j['outcome']),
      result: osText(j['result']),
      learning: osText(j['learning']),
      context: osText(j['context']),
      snapshot: osMap(j['snapshot']),
      notes: osMap(j['notes']).map((k, v) => MapEntry(k, osText(v))),
      scores: {
        for (final e in osMap(j['scores']).entries)
          if (osNumber(e.value) != null) e.key: osNumber(e.value)!
      },
      effectiveMotives: osStrings(j['effectiveMotives']),
      motiveFeedbackRecorded: j['motiveFeedbackRecorded'] == true,
      createdAt: DateTime.tryParse(osText(j['createdAt'])));
}

class SelfOsCase {
  SelfOsCase(
      {String? id,
      this.problem = '',
      this.retrospective = false,
      DateTime? createdAt})
      : id = id ?? selfOsId(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = createdAt ?? DateTime.now();
  final String id;
  final DateTime createdAt;
  DateTime updatedAt;
  String problem;
  bool retrospective;
  int round = 1;
  String blocker = 'unknown';
  String routeStatus = 'experimental';
  DateTime? committedAt;
  Map<String, dynamic>? commitment;
  final Map<String, String> fields = {};
  final Map<String, double> scores = {};
  final List<SelfOsDesire> desires = [];
  final List<SelfOsWhyNode> whyTree = [];
  final List<SelfOsMotive> motives = [];
  final List<SelfOsReview> reviews = [];
  SelfOsV37 v37 = SelfOsV37();
  OsGuideState guide = OsGuideState();
  final Map<String, List<Map<String, dynamic>>> suggestions = {};
  String text(String key) => fields[key] ?? '';
  bool get reviewed => reviews.any((r) => r.round == round);
  String get evidenceLevel => reviews.isNotEmpty
      ? '行动证据'
      : committedAt != null
          ? '决意证据'
          : '愿望证据';
  double? get temporalGap =>
      scores['planProbability'] != null && scores['actionProbability'] != null
          ? scores['planProbability']! - scores['actionProbability']!
          : null;
  String get statusLabel => reviewed
      ? '已复盘'
      : committedAt != null
          ? '待行动 / 复盘'
          : '探索中';
  List<SelfOsDesire> get acceptedDesires =>
      desires.where((d) => d.accepted).toList();

  void addWhy(SelfOsWhyNode node) {
    if (whyTree.any((n) => n.id == node.id) ||
        node.parents.any((p) => !whyTree.any((n) => n.id == p))) {
      throw const FormatException('Why Tree 的分支只能连接已有节点');
    }
    whyTree.add(node);
  }

  void removeWhy(String id) {
    whyTree.removeWhere((n) => n.id == id);
    for (final node in whyTree) {
      node.parents.remove(id);
    }
  }

  Map<String, dynamic> evidenceSnapshot() => {
        'caseId': id,
        'problem': problem,
        'round': round,
        'blocker': blocker,
        'fields': Map<String, String>.from(fields),
        'scores': Map<String, double>.from(scores),
        'desires': acceptedDesires.map((d) => d.toJson()).toList(),
        'motives':
            motives.where((m) => m.selected).map((m) => m.toJson()).toList(),
        'committedAt': committedAt?.toIso8601String(),
        'guide': {
          'revision': guide.revision,
          'confirmed': guide.confirmed,
          'frame': guide.frame == null ? null : osClone(guide.frame!),
        },
        'v37': v37.toJson()
          ..remove('priorCommitments')
          ..remove('knowledgeTraces')
          ..remove('decisionTraces')
          ..remove('pendingProposal'),
      };

  Map<String, dynamic> cognitiveSnapshot({bool original = false}) => {
        'knowledge': original || text('k2').isEmpty ? text('k1') : text('k2'),
        'motives':
            motives.where((m) => m.selected).map((m) => m.toJson()).toList(),
        'probability':
            scores['revisedProbability'] ?? scores['actionProbability'],
        'environment': text('environment'),
        'state': text('actionState'),
        'skill': v37.text('skillBaseline'),
        'evidenceIds': v37.evidence.map((e) => e.id).toList(),
        'round': round,
        'capturedAt': DateTime.now().toIso8601String(),
      };

  void beginCognition() {
    v37.knowledgeBefore ??= osClone(cognitiveSnapshot());
    v37.settings['understandingReviewed'] = false;
    if (committedAt != null && !reviewed) {
      v37.settings['requiresReconsideration'] = true;
      v37.settings['phase'] = 'revise';
    }
  }

  void completeCognition(String reason, {String noChangeReason = ''}) {
    final before = v37.knowledgeBefore;
    if (before == null) throw const FormatException('请先保存补全前的认识与动机快照');
    if (text('k2').trim().isEmpty || reason.trim().isEmpty)
      throw const FormatException('请填写 K2 及新增认识与动机变化的关系');
    final after = cognitiveSnapshot();
    final delta = SelfOsV37Rules.motiveDelta(before, after);
    if (delta.isEmpty && noChangeReason.trim().isEmpty)
      throw const FormatException('尚未观察到动机场变化。请关联动机变化，或说明为何新信息不改变决定');
    v37.knowledgeTraces.add({
      'id': selfOsId(),
      'round': round,
      'before': osClone(before),
      'after': osClone(after),
      'delta': delta,
      'reason': reason,
      'noChangeReason': noChangeReason,
      'status': delta.isEmpty ? 'no_decision_change' : 'rebuilt',
      'createdAt': DateTime.now().toIso8601String(),
    });
    v37.knowledgeBefore = null;
    v37.settings['deliberationCycles'] =
        (v37.number('deliberationCycles') ?? 0).toInt() + 1;
    v37.settings['informationGain'] =
        delta.isEmpty && before['probability'] == after['probability']
            ? 'none'
            : 'new';
    v37.settings['understandingSummary'] = text('k2');
    if (text('newInformation').trim().isNotEmpty)
      v37.settings['newInformationReviewed'] = true;
    v37.settings['requiresReconsideration'] = false;
  }

  void startIntervention(OsIntervention i) {
    if (i.completed || i.started) throw const FormatException('这项准备已开始或完成');
    if (v37.futureMoment == null) throw const FormatException('先确定未来决策时刻');
    if (v37.futureMoment!.isBefore(DateTime.now()) &&
        i.text('window') != 'onsite')
      throw const FormatException('决策时刻已经过去，请先更新未来时刻，或直接记录实际行动');
    if (i.text('gapId').isEmpty ||
        !v37.gaps.any((g) => g.id == i.text('gapId')) ||
        i.text('task').isEmpty ||
        i.text('source').isEmpty ||
        i.text('expectedChange').isEmpty) {
      throw const FormatException('准备动作必须绑定缺口、来源和预期变化');
    }
    if (i.text('window') == 'onsite' && !['rehearse'].contains(i.type))
      throw const FormatException('复杂信息应提前处理，现场只保留一条观念与第一动作');
    i.data['before'] = osClone(cognitiveSnapshot());
    i.data['startedAt'] = DateTime.now().toIso8601String();
  }

  void completeIntervention(OsIntervention i, String observation) {
    if (!i.started || i.completed || observation.trim().isEmpty)
      throw const FormatException('先记录干预前快照，完成后写下实际观察');
    final after = cognitiveSnapshot();
    i.data.addAll({
      'after': after,
      'observation': observation,
      'gain': SelfOsV37Rules.interventionGain(osMap(i.data['before']), after),
      'completedAt': DateTime.now().toIso8601String(),
      'late':
          v37.futureMoment == null || DateTime.now().isAfter(v37.futureMoment!),
    });
  }

  void commit() {
    if (reviewed) throw const FormatException('本轮已复盘，请开始下一轮验证');
    if (text('firstAction').trim().isEmpty || text('trigger').trim().isEmpty)
      throw const FormatException('请填写行动触发条件和第一个动作');
    if (scores['planProbability'] == null ||
        scores['actionProbability'] == null)
      throw const FormatException('请分别记录计划时和行动现场的主观概率');
    if (!motives.any((m) => m.selected && m.side == 'for') ||
        !motives.any((m) => m.selected && m.side == 'against'))
      throw const FormatException('请同时选入至少一个正方动机和一个反方动机');
    final gate = SelfOsV37Rules.gate(v37);
    if (!gate.mayCommit)
      throw FormatException('${gate.label}：${gate.reasons.first}');
    if (text('newInformation').trim().isNotEmpty &&
        !v37.flag('newInformationReviewed'))
      throw const FormatException('现场出现重要新信息，先补全认识并重新审视协议');
    if (SelfOsV37Rules.jamesMode(v37) == 'effort' &&
        (!v37.flag('sacrificeAccepted') ||
            v37.text('sacrificedValue').trim().isEmpty ||
            v37.text('opportunityCost').trim().isEmpty)) {
      throw const FormatException('请承认被舍弃的真实价值，并确认机会成本');
    }
    if (commitment != null) v37.priorCommitments.add(osClone(commitment!));
    committedAt = DateTime.now();
    v37.settings['phase'] =
        gate.action == 'EXPERIMENT' ? 'experiment' : 'commit';
    commitment = osClone({
      ...evidenceSnapshot(),
      'commitmentScope': gate.action == 'EXPERIMENT' ? 'experiment' : 'decision'
    });
  }

  /// Bring a reviewed strength bridge into the action draft. It never approves
  /// a commitment or makes a candidate strength a verified trait.
  void stageStrengthBridge() {
    if (reviewed) throw const FormatException('本轮已复盘，请在下一轮尝试这个桥接动作');
    for (final key in [
      'bridgeStrengthId',
      'bridgeWeakness',
      'bridgeMechanism',
      'bridgeAction',
      'bridgeGuardrail'
    ]) {
      if (v37.text(key).trim().isEmpty)
        throw const FormatException('先补齐力量、阻碍、作用方式、动作与过度使用边界');
    }
    if (committedAt != null) {
      beginCognition();
      fields['newInformation'] = '根据力量桥接修改行动草稿：${v37.text('bridgeAction')}';
      v37.settings['newInformationReviewed'] = false;
    }
    fields['firstAction'] = v37.text('bridgeAction');
    fields['reconsiderWhen'] = v37.text('bridgeGuardrail');
    v37.settings['actionBridge'] = {
      'strengthId': v37.text('bridgeStrengthId'),
      'weakness': v37.text('bridgeWeakness'),
      'mechanism': v37.text('bridgeMechanism'),
      'action': v37.text('bridgeAction'),
      'guardrail': v37.text('bridgeGuardrail'),
      'stagedAt': DateTime.now().toIso8601String(),
    };
    // A previous cue was endorsed for a different action; choose it again if
    // still appropriate. Staging a bridge never creates a strength cue.
    v37.settings.remove('holdCue');
    v37.settings.remove('cueSource');
    if (guide.confirmed && guide.phase == 'plan') {
      guide.draft.addAll({
        'action': fields['firstAction'],
        'stopWhen': fields['reconsiderWhen'],
        'costAccepted': false,
        'reversible': false,
        'cueAccepted': false
      });
    }
  }

  void addReview(SelfOsReview review) {
    if (review.round != round || reviewed)
      throw const FormatException('本轮已保存复盘，请开始下一轮后记录新行动');
    if (!['done', 'partial', 'notDone'].contains(review.outcome) ||
        review.result.trim().isEmpty ||
        review.learning.trim().isEmpty ||
        review.context.trim().isEmpty)
      throw const FormatException('请记录真实行动、结果、情境和至少一条新证据');
    reviews.add(review);
    v37.settings['phase'] = 'revise';
    v37.decisionTraces.add({
      'id': selfOsId(),
      'reviewId': review.id,
      'round': round,
      'before': osClone(osMap(review.snapshot['v37'])),
      'observed': Map<String, String>.from(review.notes),
      'outcome': review.outcome,
      'result': review.result,
      'createdAt': review.createdAt.toIso8601String(),
    });
    for (final i in v37.interventions
        .where((i) => i.completed && i.data['reviewId'] == null)) {
      i.data['reviewId'] = review.id;
      i.data['actualOutcome'] = review.outcome;
    }
  }

  void nextRound() {
    if (!reviewed) throw const FormatException('请先完成本轮复盘');
    final previous = reviews.singleWhere((r) => r.round == round);
    fields['k1'] = previous.notes['calibrationConclusion'] ?? previous.learning;
    fields['knowledgeSource'] = '第 $round 轮行动之镜';
    fields.remove('k2');
    fields.remove('cognitiveOperation');
    round += 1;
    committedAt = null;
    commitment = null;
    retrospective = false;
    for (final key in [
      'planProbability',
      'actionProbability',
      'revisedProbability',
      'predictedDiscomfort'
    ]) {
      scores.remove(key);
    }
    fields.remove('newInformation');
    v37.knowledgeBefore = null;
    v37.pendingProposal = null;
    guide
      ..phase = 'explore'
      ..frame = null
      ..confirmedRevision = null
      ..compose = '';
    guide.revision++;
    guide.draft.clear();
    v37.settings['understandingReviewed'] = false;
    v37.settings['requiresReconsideration'] = false;
    v37.settings['phase'] = v37.routes.length >= 2 ? 'filter' : 'expand';
    v37.settings['holdCue'] = '';
    for (final key in [
      'jamesMode',
      'decisionStage',
      'decisionEvidence',
      'holdResult',
      'holdCompletedAt',
      'newInformationReviewed',
      'cooledAndReviewed'
    ]) {
      v37.settings.remove(key);
    }
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 2,
        'v37': v37.toJson(),
        'guide': guide.toJson(),
        'id': id,
        'problem': problem,
        'retrospective': retrospective,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'round': round,
        'blocker': blocker,
        'routeStatus': routeStatus,
        'committedAt': committedAt?.toIso8601String(),
        'commitment': commitment,
        'fields': fields,
        'scores': scores,
        'desires': desires.map((d) => d.toJson()).toList(),
        'whyTree': whyTree.map((n) => n.toJson()).toList(),
        'motives': motives.map((m) => m.toJson()).toList(),
        'reviews': reviews.map((r) => r.toJson()).toList(),
        'suggestions': suggestions
      };
  SelfOsCase copy() =>
      SelfOsCase.fromJson(osMap(jsonDecode(jsonEncode(toJson()))));
  factory SelfOsCase.fromJson(Map<String, dynamic> j) {
    if (![1, 2].contains(j['schemaVersion']) || osText(j['id']).isEmpty)
      throw const FormatException('无法读取此版本的 Self OS 案例');
    final c = SelfOsCase(
        id: j['id'],
        problem: osText(j['problem']),
        retrospective: j['retrospective'] == true,
        createdAt: DateTime.tryParse(osText(j['createdAt'])));
    c.v37 = SelfOsV37.fromJson(osMap(j['v37']));
    c.guide = OsGuideState.fromJson(osMap(j['guide']));
    c.updatedAt = DateTime.tryParse(osText(j['updatedAt'])) ?? c.createdAt;
    c.round = (j['round'] as num?)?.toInt() ?? 1;
    c.blocker =
        selfOsBlockers.containsKey(j['blocker']) ? j['blocker'] : 'unknown';
    c.routeStatus = selfOsRouteStates.containsKey(j['routeStatus'])
        ? j['routeStatus']
        : 'experimental';
    c.committedAt = DateTime.tryParse(osText(j['committedAt']));
    c.commitment = j['commitment'] is Map ? osMap(j['commitment']) : null;
    c.fields.addAll(osMap(j['fields']).map((k, v) => MapEntry(k, osText(v))));
    for (final e in osMap(j['scores']).entries) {
      final v = osNumber(e.value);
      if (v != null) c.scores[e.key] = v;
    }
    c.desires.addAll(osMaps(j['desires']).map(SelfOsDesire.fromJson));
    for (final node in osMaps(j['whyTree']).map(SelfOsWhyNode.fromJson)) {
      c.addWhy(node);
    }
    c.motives.addAll(osMaps(j['motives']).map(SelfOsMotive.fromJson));
    c.reviews.addAll(osMaps(j['reviews']).map(SelfOsReview.fromJson));
    c.suggestions
        .addAll(osMap(j['suggestions']).map((k, v) => MapEntry(k, osMaps(v))));
    return c;
  }
}

class SelfOsProfile {
  final Map<String, String> manual = {};
  final List<Map<String, dynamic>> principles = [];
  final List<Map<String, dynamic>> tradeoffs = [];
  final List<OsStrength> strengths = [];
  String activeCaseId = '', activeRouteId = '';
  Map<String, dynamic> toJson() => {
        'schemaVersion': 2,
        'strengths': strengths.map((s) => s.toJson()).toList(),
        'activeCaseId': activeCaseId,
        'activeRouteId': activeRouteId,
        'manual': manual,
        'principles': principles,
        'tradeoffs': tradeoffs
      };
  factory SelfOsProfile.fromJson(Map<String, dynamic> j) {
    if (j.isNotEmpty && ![1, 2].contains(j['schemaVersion']))
      throw const FormatException('无法读取此版本的 Self OS 个人模型');
    return SelfOsProfile()
      ..strengths.addAll(osMaps(j['strengths']).map(OsStrength.new))
      ..activeCaseId = osText(j['activeCaseId'])
      ..activeRouteId = osText(j['activeRouteId'])
      ..manual.addAll(osMap(j['manual']).map((k, v) => MapEntry(k, osText(v))))
      ..principles.addAll(osMaps(j['principles']))
      ..tradeoffs.addAll(osMaps(j['tradeoffs']));
  }
  SelfOsProfile();
}
