import 'dart:convert';
import 'dart:math';

String selfOsId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(1 << 32).toRadixString(36)}';

Map<String, dynamic> osMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> osMaps(dynamic value) =>
    value is List ? value.whereType<Map>().map(osMap).toList() : [];
String osText(dynamic value) => value is String ? value : '';
double? osNumber(dynamic value, [double max = 100]) {
  final n = value is num ? value.toDouble() : double.tryParse('$value');
  return n != null && n.isFinite ? n.clamp(0, max).toDouble() : null;
}

List<String> osStrings(dynamic value) =>
    value is List ? value.whereType<String>().toList() : [];

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
  '意义重构'
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
      this.source = '用户提出'})
      : id = id ?? selfOsId();
  final String id;
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
      };

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
    committedAt = DateTime.now();
    commitment = evidenceSnapshot();
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
  }

  void nextRound() {
    if (!reviewed) throw const FormatException('请先完成本轮复盘');
    final previous = reviews.singleWhere((r) => r.round == round);
    fields['k1'] = previous.learning;
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
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
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
    if (j['schemaVersion'] != 1 || osText(j['id']).isEmpty)
      throw const FormatException('无法读取此版本的 Self OS 案例');
    final c = SelfOsCase(
        id: j['id'],
        problem: osText(j['problem']),
        retrospective: j['retrospective'] == true,
        createdAt: DateTime.tryParse(osText(j['createdAt'])));
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
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'manual': manual,
        'principles': principles,
        'tradeoffs': tradeoffs
      };
  factory SelfOsProfile.fromJson(Map<String, dynamic> j) {
    if (j.isNotEmpty && j['schemaVersion'] != 1)
      throw const FormatException('无法读取此版本的 Self OS 个人模型');
    return SelfOsProfile()
      ..manual.addAll(osMap(j['manual']).map((k, v) => MapEntry(k, osText(v))))
      ..principles.addAll(osMaps(j['principles']))
      ..tradeoffs.addAll(osMaps(j['tradeoffs']));
  }
  SelfOsProfile();
}
