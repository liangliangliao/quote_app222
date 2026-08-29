import 'dart:convert';

enum WillMirrorNeedType { goal, problem }

extension WillMirrorNeedTypeX on WillMirrorNeedType {
  String get value => name;

  String get label => switch (this) {
        WillMirrorNeedType.goal => '我想实现一个目标',
        WillMirrorNeedType.problem => '我想解决一个问题',
      };

  String get shortLabel => switch (this) {
        WillMirrorNeedType.goal => '目标',
        WillMirrorNeedType.problem => '问题',
      };
}

WillMirrorNeedType parseWillMirrorNeedType(Object? value) {
  return WillMirrorNeedType.values.firstWhere(
    (item) => item.value == value,
    orElse: () => WillMirrorNeedType.goal,
  );
}

enum WillMirrorSupportStyle { practical, curious, gentle }

extension WillMirrorSupportStyleX on WillMirrorSupportStyle {
  String get value => name;

  String get label => switch (this) {
        WillMirrorSupportStyle.practical => '直接行动',
        WillMirrorSupportStyle.curious => '像侦探一样探索',
        WillMirrorSupportStyle.gentle => '轻松陪伴',
      };

  String get description => switch (this) {
        WillMirrorSupportStyle.practical => '少解释，先产出一个看得见的结果',
        WillMirrorSupportStyle.curious => '先理解动机和盲点，再选择行动',
        WillMirrorSupportStyle.gentle => '把压力降到最低，允许随时缩小任务',
      };
}

WillMirrorSupportStyle parseWillMirrorSupportStyle(Object? value) {
  return WillMirrorSupportStyle.values.firstWhere(
    (item) => item.value == value,
    orElse: () => WillMirrorSupportStyle.practical,
  );
}

enum WillMirrorInterest {
  create,
  learn,
  connect,
  organize,
  explore,
  care,
}

extension WillMirrorInterestX on WillMirrorInterest {
  String get value => name;

  String get label => switch (this) {
        WillMirrorInterest.create => '创造东西',
        WillMirrorInterest.learn => '学习掌握',
        WillMirrorInterest.connect => '人与关系',
        WillMirrorInterest.organize => '整理推进',
        WillMirrorInterest.explore => '发现未知',
        WillMirrorInterest.care => '照顾改善',
      };

  String get visibleTrace => switch (this) {
        WillMirrorInterest.create => '写一句、画一笔或做出一个最小草稿',
        WillMirrorInterest.learn => '弄懂一个关键点，并用自己的话写一句',
        WillMirrorInterest.connect => '写下一句真实想表达的话，或发出一次低风险联系',
        WillMirrorInterest.organize => '列出下一步，并完成其中最小的一格',
        WillMirrorInterest.explore => '查清一个最关键的未知事实并记下来',
        WillMirrorInterest.care => '做一个能让现状稍微好一点的具体动作',
      };
}

WillMirrorInterest parseWillMirrorInterest(Object? value) {
  return WillMirrorInterest.values.firstWhere(
    (item) => item.value == value,
    orElse: () => WillMirrorInterest.create,
  );
}

enum WillMirrorRouteType { actNow, understandThenAct, sevenDayExperiment }

extension WillMirrorRouteTypeX on WillMirrorRouteType {
  String get value => switch (this) {
        WillMirrorRouteType.actNow => 'act_now',
        WillMirrorRouteType.understandThenAct => 'understand_then_act',
        WillMirrorRouteType.sevenDayExperiment => 'seven_day_experiment',
      };
}

WillMirrorRouteType parseWillMirrorRouteType(Object? value) {
  final raw = (value ?? '').toString();
  return WillMirrorRouteType.values.firstWhere(
    (item) => item.value == raw,
    orElse: () => WillMirrorRouteType.actNow,
  );
}

class WillMirrorPracticeProfile {
  const WillMirrorPracticeProfile({
    required this.style,
    required this.interest,
    required this.energyMinutes,
  });

  final WillMirrorSupportStyle style;
  final WillMirrorInterest interest;
  final int energyMinutes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'style': style.value,
        'interest': interest.value,
        'energy_minutes': energyMinutes,
      };

  factory WillMirrorPracticeProfile.fromJson(Map<String, dynamic> json) {
    final minutes = int.tryParse((json['energy_minutes'] ?? 2).toString()) ?? 2;
    return WillMirrorPracticeProfile(
      style: parseWillMirrorSupportStyle(json['style']),
      interest: parseWillMirrorInterest(json['interest']),
      energyMinutes: <int>{2, 5, 15}.contains(minutes) ? minutes : 2,
    );
  }
}

class WillMirrorTheoryApplication {
  const WillMirrorTheoryApplication({
    required this.theoryId,
    required this.concept,
    required this.application,
    required this.reason,
  });

  final String theoryId;
  final String concept;
  final String application;
  final String reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'theory_id': theoryId,
        'concept': concept,
        'application': application,
        'reason': reason,
      };

  factory WillMirrorTheoryApplication.fromJson(Map<String, dynamic> json) {
    return WillMirrorTheoryApplication(
      theoryId: (json['theory_id'] ?? '').toString(),
      concept: (json['concept'] ?? '').toString(),
      application: (json['application'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class WillMirrorIntelligenceReceipt {
  const WillMirrorIntelligenceReceipt({
    required this.aiRequested,
    required this.aiUsed,
    required this.provider,
    required this.model,
    required this.status,
    required this.knowledgeIds,
    required this.generatedAt,
    this.situationSummary = '',
    this.blindSpotQuestion = '',
    this.fallbackReason = '',
  });

  const WillMirrorIntelligenceReceipt.local({
    required this.knowledgeIds,
    required this.generatedAt,
    this.aiRequested = false,
    this.situationSummary = '',
    this.blindSpotQuestion = '',
    this.fallbackReason = '',
  })  : aiUsed = false,
        provider = 'local',
        model = '本地知识规则',
        status = 'local_grounded';

  final bool aiRequested;
  final bool aiUsed;
  final String provider;
  final String model;
  final String status;
  final List<String> knowledgeIds;
  final int generatedAt;
  final String situationSummary;
  final String blindSpotQuestion;
  final String fallbackReason;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ai_requested': aiRequested,
        'ai_used': aiUsed,
        'provider': provider,
        'model': model,
        'status': status,
        'knowledge_ids': knowledgeIds,
        'generated_at': generatedAt,
        'situation_summary': situationSummary,
        'blind_spot_question': blindSpotQuestion,
        'fallback_reason': fallbackReason,
      };

  factory WillMirrorIntelligenceReceipt.fromJson(Map<String, dynamic> json) {
    final rawIds = json['knowledge_ids'];
    return WillMirrorIntelligenceReceipt(
      aiRequested: json['ai_requested'] == true,
      aiUsed: json['ai_used'] == true,
      provider: (json['provider'] ?? 'local').toString(),
      model: (json['model'] ?? '本地知识规则').toString(),
      status: (json['status'] ?? 'local_grounded').toString(),
      knowledgeIds: rawIds is List
          ? rawIds.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      generatedAt: int.tryParse((json['generated_at'] ?? 0).toString()) ?? 0,
      situationSummary: (json['situation_summary'] ?? '').toString(),
      blindSpotQuestion: (json['blind_spot_question'] ?? '').toString(),
      fallbackReason: (json['fallback_reason'] ?? '').toString(),
    );
  }
}

class WillMirrorPracticeDraft {
  const WillMirrorPracticeDraft({
    required this.routes,
    required this.receipt,
  });

  final List<WillMirrorActionRoute> routes;
  final WillMirrorIntelligenceReceipt receipt;
}

class WillMirrorActionRoute {
  const WillMirrorActionRoute({
    required this.type,
    required this.title,
    required this.promise,
    required this.action,
    required this.successSignal,
    required this.whyItWorks,
    required this.output,
    required this.minutes,
    required this.theoryIds,
    this.theoryApplications = const <WillMirrorTheoryApplication>[],
  });

  final WillMirrorRouteType type;
  final String title;
  final String promise;
  final String action;
  final String successSignal;
  final String whyItWorks;
  final String output;
  final int minutes;
  final List<String> theoryIds;
  final List<WillMirrorTheoryApplication> theoryApplications;

  WillMirrorActionRoute copyWith({
    String? title,
    String? promise,
    String? action,
    String? successSignal,
    String? whyItWorks,
    String? output,
    int? minutes,
    List<String>? theoryIds,
    List<WillMirrorTheoryApplication>? theoryApplications,
  }) {
    return WillMirrorActionRoute(
      type: type,
      title: title ?? this.title,
      promise: promise ?? this.promise,
      action: action ?? this.action,
      successSignal: successSignal ?? this.successSignal,
      whyItWorks: whyItWorks ?? this.whyItWorks,
      output: output ?? this.output,
      minutes: minutes ?? this.minutes,
      theoryIds: theoryIds ?? this.theoryIds,
      theoryApplications: theoryApplications ?? this.theoryApplications,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.value,
        'title': title,
        'promise': promise,
        'action': action,
        'success_signal': successSignal,
        'why_it_works': whyItWorks,
        'output': output,
        'minutes': minutes,
        'theory_ids': theoryIds,
        'theory_applications': theoryApplications
            .map((item) => item.toJson())
            .toList(growable: false),
      };

  factory WillMirrorActionRoute.fromJson(Map<String, dynamic> json) {
    final rawTheory = json['theory_ids'];
    final rawApplications = json['theory_applications'];
    return WillMirrorActionRoute(
      type: parseWillMirrorRouteType(json['type']),
      title: (json['title'] ?? '').toString(),
      promise: (json['promise'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      successSignal: (json['success_signal'] ?? '').toString(),
      whyItWorks: (json['why_it_works'] ?? '').toString(),
      output: (json['output'] ?? '').toString(),
      minutes: int.tryParse((json['minutes'] ?? 2).toString()) ?? 2,
      theoryIds: rawTheory is List
          ? rawTheory.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      theoryApplications: rawApplications is List
          ? rawApplications
              .whereType<Map>()
              .map(
                (item) => WillMirrorTheoryApplication.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false)
          : const <WillMirrorTheoryApplication>[],
    );
  }
}

class WillMirrorActionPlan {
  const WillMirrorActionPlan({
    required this.id,
    required this.goalId,
    required this.hypothesisId,
    required this.experimentId,
    required this.needType,
    required this.need,
    required this.desiredOutcome,
    required this.obstacle,
    required this.profile,
    required this.route,
    required this.status,
    required this.checkInCount,
    required this.completedCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastCheckInAt,
    this.revisionNote = '',
    this.intelligenceReceipt,
  });

  final String id;
  final String goalId;
  final String hypothesisId;
  final String experimentId;
  final WillMirrorNeedType needType;
  final String need;
  final String desiredOutcome;
  final String obstacle;
  final WillMirrorPracticeProfile profile;
  final WillMirrorActionRoute route;
  final String status;
  final int checkInCount;
  final int completedCount;
  final int createdAt;
  final int updatedAt;
  final int? lastCheckInAt;
  final String revisionNote;
  final WillMirrorIntelligenceReceipt? intelligenceReceipt;

  WillMirrorActionPlan copyWith({
    String? status,
    int? checkInCount,
    int? completedCount,
    int? updatedAt,
    int? lastCheckInAt,
    WillMirrorActionRoute? route,
    String? revisionNote,
    WillMirrorIntelligenceReceipt? intelligenceReceipt,
  }) {
    return WillMirrorActionPlan(
      id: id,
      goalId: goalId,
      hypothesisId: hypothesisId,
      experimentId: experimentId,
      needType: needType,
      need: need,
      desiredOutcome: desiredOutcome,
      obstacle: obstacle,
      profile: profile,
      route: route ?? this.route,
      status: status ?? this.status,
      checkInCount: checkInCount ?? this.checkInCount,
      completedCount: completedCount ?? this.completedCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCheckInAt: lastCheckInAt ?? this.lastCheckInAt,
      revisionNote: revisionNote ?? this.revisionNote,
      intelligenceReceipt: intelligenceReceipt ?? this.intelligenceReceipt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal_id': goalId,
        'hypothesis_id': hypothesisId,
        'experiment_id': experimentId,
        'need_type': needType.value,
        'need': need,
        'desired_outcome': desiredOutcome,
        'obstacle': obstacle,
        'profile': profile.toJson(),
        'route': route.toJson(),
        'status': status,
        'check_in_count': checkInCount,
        'completed_count': completedCount,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'last_check_in_at': lastCheckInAt,
        'revision_note': revisionNote,
        'intelligence_receipt': intelligenceReceipt?.toJson(),
      };

  String encode() => jsonEncode(toJson());

  factory WillMirrorActionPlan.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    final routeJson = json['route'];
    final receiptJson = json['intelligence_receipt'];
    return WillMirrorActionPlan(
      id: (json['id'] ?? '').toString(),
      goalId: (json['goal_id'] ?? '').toString(),
      hypothesisId: (json['hypothesis_id'] ?? '').toString(),
      experimentId: (json['experiment_id'] ?? '').toString(),
      needType: parseWillMirrorNeedType(json['need_type']),
      need: (json['need'] ?? '').toString(),
      desiredOutcome: (json['desired_outcome'] ?? '').toString(),
      obstacle: (json['obstacle'] ?? '').toString(),
      profile: WillMirrorPracticeProfile.fromJson(
        profileJson is Map
            ? profileJson.map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{},
      ),
      route: WillMirrorActionRoute.fromJson(
        routeJson is Map
            ? routeJson.map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{},
      ),
      status: (json['status'] ?? 'active').toString(),
      checkInCount:
          int.tryParse((json['check_in_count'] ?? 0).toString()) ?? 0,
      completedCount:
          int.tryParse((json['completed_count'] ?? 0).toString()) ?? 0,
      createdAt: int.tryParse((json['created_at'] ?? 0).toString()) ?? 0,
      updatedAt: int.tryParse((json['updated_at'] ?? 0).toString()) ?? 0,
      lastCheckInAt: json['last_check_in_at'] == null
          ? null
          : int.tryParse(json['last_check_in_at'].toString()),
      revisionNote: (json['revision_note'] ?? '').toString(),
      intelligenceReceipt: receiptJson is Map
          ? WillMirrorIntelligenceReceipt.fromJson(
              receiptJson.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
    );
  }

  factory WillMirrorActionPlan.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('行动方案不是 JSON 对象');
    return WillMirrorActionPlan.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

class WillMirrorExampleDay {
  const WillMirrorExampleDay({
    required this.day,
    required this.didAct,
    required this.evidence,
    required this.adjustment,
  });

  final int day;
  final bool didAct;
  final String evidence;
  final String adjustment;

  factory WillMirrorExampleDay.fromJson(Map<String, dynamic> json) {
    return WillMirrorExampleDay(
      day: int.tryParse((json['day'] ?? 0).toString()) ?? 0,
      didAct: json['did_act'] == true,
      evidence: (json['evidence'] ?? '').toString(),
      adjustment: (json['adjustment'] ?? '').toString(),
    );
  }
}

class WillMirrorExampleCase {
  const WillMirrorExampleCase({
    required this.id,
    required this.title,
    required this.needType,
    required this.need,
    required this.desiredOutcome,
    required this.obstacle,
    required this.profile,
    required this.selectedRoute,
    required this.generatedAction,
    required this.successSignal,
    required this.theoryIds,
    required this.days,
    required this.result,
    required this.nextRevision,
    this.whyItWorks = '',
    this.theoryApplications = const <WillMirrorTheoryApplication>[],
    this.generationReceipt = '',
  });

  final String id;
  final String title;
  final WillMirrorNeedType needType;
  final String need;
  final String desiredOutcome;
  final String obstacle;
  final WillMirrorPracticeProfile profile;
  final WillMirrorRouteType selectedRoute;
  final String generatedAction;
  final String successSignal;
  final List<String> theoryIds;
  final List<WillMirrorExampleDay> days;
  final String result;
  final String nextRevision;
  final String whyItWorks;
  final List<WillMirrorTheoryApplication> theoryApplications;
  final String generationReceipt;

  factory WillMirrorExampleCase.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['profile'];
    final rawTheory = json['theory_ids'];
    final rawDays = json['days'];
    final rawApplications = json['theory_applications'];
    return WillMirrorExampleCase(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      needType: parseWillMirrorNeedType(json['need_type']),
      need: (json['need'] ?? '').toString(),
      desiredOutcome: (json['desired_outcome'] ?? '').toString(),
      obstacle: (json['obstacle'] ?? '').toString(),
      profile: WillMirrorPracticeProfile.fromJson(
        rawProfile is Map
            ? rawProfile.map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{},
      ),
      selectedRoute: parseWillMirrorRouteType(json['selected_route']),
      generatedAction: (json['generated_action'] ?? '').toString(),
      successSignal: (json['success_signal'] ?? '').toString(),
      theoryIds: rawTheory is List
          ? rawTheory.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      days: rawDays is List
          ? rawDays
              .whereType<Map>()
              .map(
                (item) => WillMirrorExampleDay.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false)
          : const <WillMirrorExampleDay>[],
      result: (json['result'] ?? '').toString(),
      nextRevision: (json['next_revision'] ?? '').toString(),
      whyItWorks: (json['why_it_works'] ?? '').toString(),
      theoryApplications: rawApplications is List
          ? rawApplications
              .whereType<Map>()
              .map(
                (item) => WillMirrorTheoryApplication.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false)
          : const <WillMirrorTheoryApplication>[],
      generationReceipt: (json['generation_receipt'] ?? '').toString(),
    );
  }
}
