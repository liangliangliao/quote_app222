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

  WillMirrorActionRoute copyWith({
    String? title,
    String? promise,
    String? action,
    String? successSignal,
    String? whyItWorks,
    String? output,
    int? minutes,
    List<String>? theoryIds,
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
      };

  factory WillMirrorActionRoute.fromJson(Map<String, dynamic> json) {
    final rawTheory = json['theory_ids'];
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

  WillMirrorActionPlan copyWith({
    String? status,
    int? checkInCount,
    int? completedCount,
    int? updatedAt,
    int? lastCheckInAt,
    WillMirrorActionRoute? route,
    String? revisionNote,
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
      };

  String encode() => jsonEncode(toJson());

  factory WillMirrorActionPlan.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    final routeJson = json['route'];
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

  factory WillMirrorExampleCase.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['profile'];
    final rawTheory = json['theory_ids'];
    final rawDays = json['days'];
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
    );
  }
}
