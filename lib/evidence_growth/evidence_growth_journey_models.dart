import 'dart:convert';

typedef GrowthData = Map<String, dynamic>;
GrowthData growthMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<GrowthData> growthRows(Object? value) =>
    value is List ? value.map(growthMap).toList() : [];
List<String> growthStrings(Object? value) =>
    value is List ? value.map((v) => v.toString()).toList() : [];
int growthInt(Object? value, [int fallback = 0]) =>
    int.tryParse('$value') ?? fallback;

/// PRD §210. Classification proposes coordinates; it never makes a diagnosis or
/// a terminal business decision. Unknown coordinates stay visible to the user.
class GrowthProblemProfile {
  const GrowthProblemProfile(this.data);
  final GrowthData data;
  static const dimensions = <String, List<String>>{
    'intent_clarity': ['KNOWN_GOAL', 'PROVISIONAL', 'UNKNOWN_DISCOVERY'],
    'scope': [
      'EPISODE',
      'SHORT_HORIZON',
      'LONG_HORIZON',
      'CONTINUOUS',
      'RECURRING'
    ],
    'goal_mode': ['EXPLORE', 'SOLVE', 'CREATE', 'ENRICH', 'MAINTAIN', 'REPAIR'],
    'control_type': ['SELF', 'MIXED', 'EXTERNAL_DEPENDENT', 'SHARED_OWNED'],
    'structure_type': ['SINGLE', 'NESTED', 'DEPENDENCY_GRAPH', 'PORTFOLIO'],
    'ownership_mode': [
      'SINGLE_OWNER',
      'SHARED_OWNER',
      'CONTRIBUTOR',
      'EXTERNAL_ACTOR'
    ],
    'risk_class': ['NORMAL', 'SENSITIVE', 'HIGH_RISK', 'PROFESSIONAL_BOUNDARY'],
    'knowledge_status': [
      'PROCESS_SUFFICIENT',
      'DOMAIN_SUFFICIENT',
      'DOMAIN_INSUFFICIENT'
    ],
    'change_state': [
      'INTENT',
      'ATTEMPT',
      'LAPSE',
      'ADJUSTING',
      'CONSOLIDATING',
      'STABLE'
    ],
    'plan_state': [
      'NO_PLAN',
      'ACTIVE',
      'NEEDS_REPLAN',
      'REVISION',
      'SUPERSEDED'
    ],
    'outcome_state': [
      'SUCCESS',
      'PARTIAL',
      'FAILURE',
      'REJECTION',
      'DELAY',
      'CANCEL',
      'EXTERNAL',
      'UNKNOWN'
    ],
    'processing_state': ['READY', 'FACTS_ONLY', 'DEFERRED', 'RECOVERY_HOLD'],
    'lifecycle_type': [
      'EXPLORATORY',
      'FINITE',
      'CONTINUOUS',
      'RECURRING',
      'REOPENED'
    ],
  };
  String get scope => data['scope'] as String? ?? 'UNKNOWN';
  String get mode => data['goal_mode'] as String? ?? 'SOLVE';
  String get lifecycle => data['lifecycle_type'] as String? ?? 'FINITE';
  bool get intimate => data['shared_body'] == true;
  bool get sensitive => intimate || data['risk_class'] != 'NORMAL';
  bool get blocked =>
      data['gap'] == 'ARCHITECTURE_GAP_REVIEW' ||
      data['risk_class'] == 'HIGH_RISK';
  List<GrowthData> get fragments => growthRows(data['entry_fragments']);
  GrowthProblemProfile checked() {
    final bad = [
      for (final e in dimensions.entries)
        if (data[e.key] != null &&
            data[e.key] != 'UNKNOWN' &&
            !e.value.contains(data[e.key]))
          e.key
    ];
    return GrowthProblemProfile({
      ...data,
      if (bad.isNotEmpty) 'gap': 'ARCHITECTURE_GAP_REVIEW',
      'unresolved_dimensions':
          {...growthStrings(data['unresolved_dimensions']), ...bad}.toList()
    });
  }

  factory GrowthProblemProfile.resolve(String raw) {
    bool has(String p) => RegExp(p, caseSensitive: false).hasMatch(raw);
    final unknown = has(r'不知道.{0,10}(想要|方向|做什么|该做|想做)|没有方向|探索方向');
    final episode = has(r'今晚|这次约会|本次活动|今天.*(聚会|约会)|一次体验');
    final recurring = has(r'每天|每周|每月|每晚');
    final continuous = has(r'保持|维持|持续维护|长期坚持');
    final finite = has(r'直到.{0,12}(找到|完成|实现|达成)|找到工作|获得录用|通过考试');
    final intimate = has(r'做爱|性行为|亲密接触|接吻|共同身体');
    final shared = has(r'(我和|我们|双方|共同).{0,15}(一起|共同|存钱|创业|目标|决定)');
    final professional = has(r'诊断|药物|疼痛|症状|治疗|医疗|法律|投资|性健康');
    final domain = professional || has(r'求职|找工作|招聘|结婚|签单|职业策略');
    final selfJudgment = has(r'我.{0,3}(很懒|没用|废物|缺点|天生|无能)');
    final highRisk = has(r'自杀|杀人|强迫.{0,8}(性|同意)|跟踪骚扰|伤害自己');
    final fragments = <GrowthData>[];
    const entries = {
      'BELIEF': r'相信|认为|担心|害怕|我是|很懒|缺点',
      'GOAL': r'想|希望|目标|直到|决定',
      'ACTION': r'做了|开始|已经|尝试|投递|发出|试图',
      'OUTCOME': r'失败|拒绝|结果|成功|完成|没有去|未做|中止',
      'REVIEW': r'意识到|发现|总结|学到|原来|反思',
      'CHANGE': r'改变|调整|改成|以后|重新|不再'
    };
    for (final part
        in raw.split(RegExp(r'[。；;\n]')).where((s) => s.trim().isNotEmpty)) {
      final matched =
          entries.entries.where((e) => RegExp(e.value).hasMatch(part)).toList();
      if (matched.isEmpty)
        fragments.add({'node': 'UNKNOWN', 'text': part, 'source': 'USER'});
      for (final e in matched)
        fragments.add({'node': e.key, 'text': part, 'source': 'USER'});
    }
    final life = unknown
        ? 'EXPLORATORY'
        : !finite && recurring
            ? 'RECURRING'
            : !finite && continuous
                ? 'CONTINUOUS'
                : 'FINITE';
    final mode = unknown
        ? 'EXPLORE'
        : !finite && (continuous || recurring)
            ? 'MAINTAIN'
            : has(r'修复|挽回|修补')
                ? 'REPAIR'
                : has(r'美好|享受|丰富|愉快')
                    ? 'ENRICH'
                    : has(r'创造|创作|设计')
                        ? 'CREATE'
                        : 'SOLVE';
    final metrics = <GrowthData>[
      for (final m in RegExp(r'\d+\s*(分钟|小时|次|天|元|年)').allMatches(raw))
        {
          'text': m.group(0),
          'role': 'PREFERENCE',
          'optimization_allowed': false,
          'source': 'USER_LITERAL'
        }
    ];
    return GrowthProblemProfile({
      'entry_fragments': fragments,
      'intent_clarity': unknown
          ? 'UNKNOWN_DISCOVERY'
          : has(r'想|希望|目标|直到')
              ? 'KNOWN_GOAL'
              : 'PROVISIONAL',
      'scope': episode
          ? 'EPISODE'
          : life == 'RECURRING'
              ? 'RECURRING'
              : life == 'CONTINUOUS'
                  ? 'CONTINUOUS'
                  : has(r'年|长期')
                      ? 'LONG_HORIZON'
                      : 'UNKNOWN',
      'goal_mode': mode,
      'control_type': shared
          ? 'SHARED_OWNED'
          : has(r'客户|录用|招聘|对方|女朋友|结婚')
              ? 'EXTERNAL_DEPENDENT'
              : 'UNKNOWN',
      'structure_type': 'SINGLE',
      'ownership_mode': shared ? 'SHARED_OWNER' : 'SINGLE_OWNER',
      'metric_profile': metrics,
      'shared_body': intimate,
      'risk_class': highRisk
          ? 'HIGH_RISK'
          : professional
              ? 'PROFESSIONAL_BOUNDARY'
              : intimate
                  ? 'SENSITIVE'
                  : 'NORMAL',
      'knowledge_status': domain ? 'DOMAIN_INSUFFICIENT' : 'PROCESS_SUFFICIENT',
      'change_state': has(r'又犯|复发|再次中断')
          ? 'LAPSE'
          : has(r'试图|正在改|尝试改变')
              ? 'ATTEMPT'
              : 'INTENT',
      'plan_state': has(r'重新.{0,8}计划|重新安排') ? 'NEEDS_REPLAN' : 'NO_PLAN',
      'outcome_state': has(r'拒绝')
          ? 'REJECTION'
          : has(r'失败')
              ? 'FAILURE'
              : 'UNKNOWN',
      'processing_state': has(r'晚点|稍后复盘') ? 'DEFERRED' : 'UNKNOWN',
      'lifecycle_type': life,
      'self_judgment': selfJudgment
          ? {
              'label': raw,
              'status': 'HYPOTHESIS_NOT_IDENTITY',
              'observed_pattern': '',
              'context': '',
              'impact': '',
              'desired_pattern': ''
            }
          : null,
      'gap': highRisk
          ? 'SAFETY_HOLD'
          : domain
              ? 'DOMAIN_EVIDENCE_INSUFFICIENT'
              : '',
      'confidence': 0.55,
      'provenance': 'LOCAL_RULE_PROPOSAL_USER_CORRECTABLE',
      'unresolved_dimensions': [
        if (!episode && !recurring && !continuous && !has(r'年|长期')) 'scope',
        if (!shared) 'control_type'
      ],
    }).checked();
  }
  static GrowthData outcome(String facts,
      {String object = 'UNKNOWN', bool explicit = false}) {
    final rejection = RegExp(r'拒绝|不愿意|不同意').hasMatch(facts);
    const objects = [
      'UNKNOWN',
      'INVITATION',
      'PROPOSAL',
      'RELATIONSHIP',
      'CONTACT',
      'APPLICATION',
      'EVENT',
      'TASK'
    ];
    if (!objects.contains(object)) throw ArgumentError('请选择实际被回应的对象');
    return {
      'verb': rejection ? 'REJECTION' : 'OBSERVED',
      'object': object,
      'explicit': explicit,
      'facts': facts,
      'interpretation': '',
      'route_effect': !explicit || !rejection
          ? 'NO_CLOSURE'
          : object == 'RELATIONSHIP' || object == 'CONTACT'
              ? 'ROUTE_CLOSED'
              : object == 'PROPOSAL'
                  ? 'STAGE_BLOCKED'
                  : 'LOCAL_BOUNDARY',
      'source': 'USER_ATTESTATION'
    };
  }

  static GrowthData metric(GrowthProblemProfile p, String text, String role,
      {bool confirmed = false, bool selfControlled = false}) {
    if (!const ['PREFERENCE', 'WINDOW', 'MEASUREMENT', 'CONSTRAINT', 'KPI']
        .contains(role)) throw ArgumentError('指标身份无效');
    if (role == 'KPI' &&
        (!confirmed ||
            !selfControlled ||
            p.intimate ||
            p.data['risk_class'] == 'PROFESSIONAL_BOUNDARY')) {
      throw StateError('数字仅作参考；只有明确、自主可控且合适的指标可作为绩效');
    }
    return {
      'text': text,
      'role': role,
      'optimization_allowed': role == 'KPI',
      'user_confirmed': confirmed,
      'self_controlled': selfControlled
    };
  }
}

class GrowthJourney {
  const GrowthJourney(this.data);
  final GrowthData data;
  String get id => data['id'] as String;
  int get version => growthInt(data['version']);
  int get cycle => growthInt(data['cycle'], 1);
  String get title => data['title'] as String? ?? '';
  String get safeTitle => profile.sensitive ? '私密目标' : title;
  String get status => data['status'] as String? ?? 'DRAFT';
  String get node => data['node'] as String? ?? 'BELIEF';
  String get trialId => data['trial_id'] as String? ?? '';
  GrowthProblemProfile get profile =>
      GrowthProblemProfile(growthMap(data['profile']));
  GrowthData get contract => growthMap(data['contract']);
  GrowthData get plan => growthMap(data['plan']);
  bool get confirmed => contract['confirmed'] == true;
  bool get terminal =>
      const ['ACHIEVED', 'CLOSED', 'ARCHIVED', 'DELETED'].contains(status);
  String get gate => profile.lifecycle == 'EXPLORATORY'
      ? 'DISCOVERY_GATE'
      : const ['CONTINUOUS', 'RECURRING'].contains(profile.lifecycle)
          ? 'MAINTENANCE_GATE'
          : 'GOAL_GATE';
  static const labels = {
    'BELIEF': '信念',
    'GOAL': '目标',
    'ACTION': '行动',
    'OUTCOME': '结果与失败',
    'REVIEW': '复盘',
    'CHANGE': '改变',
    'BELIEF_CHECKPOINT': '信念校准',
    'GOAL_GATE': '目标核验',
    'DISCOVERY_GATE': '探索选择',
    'MAINTENANCE_GATE': '保持检查',
    'DRAFT': '待确认',
    'ACTIVE': '正在推进',
    'ACTIVE_BUILD': '建立稳定结构',
    'PAUSED': '已暂停',
    'PARKED': '稍后推进',
    'BLOCKED': '等待前置条件',
    'MAINTAINING': '保持中',
    'RECOVERY_CYCLE': '恢复中',
    'DRIFT_DETECTED': '发现偏离',
    'ACHIEVED': '已按证据达成',
    'CLOSED': '已结束',
    'ARCHIVED': '已归档',
    'UNKNOWN': '待核对',
    'READY_NOW': '现在可以复盘',
    'FACTS_ONLY': '先记事实',
    'DEFERRED': '晚点复盘',
    'RECOVERY_HOLD': '先恢复',
    'FINITE': '有限目标',
    'EXPLORATORY': '探索方向',
    'CONTINUOUS': '持续保持',
    'RECURRING': '周期保持'
  };
  String get nodeLabel => labels[node] ?? node;
  String get statusLabel => labels[status] ?? status;
  GrowthJourney copy(GrowthData patch) => GrowthJourney({...data, ...patch});
  GrowthJourney detached() =>
      GrowthJourney(growthMap(jsonDecode(jsonEncode(data))));
}
