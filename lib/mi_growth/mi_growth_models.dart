import 'dart:convert';

class MiGrowthValueProfile {
  final List<String> values;
  final String identityDirection;
  final String importantRelationships;
  final String longTermDirection;
  final List<String> changeReasons;
  final int updatedAtMs;

  const MiGrowthValueProfile({
    this.values = const <String>[],
    this.identityDirection = '',
    this.importantRelationships = '',
    this.longTermDirection = '',
    this.changeReasons = const <String>[],
    this.updatedAtMs = 0,
  });

  MiGrowthValueProfile copyWith({
    List<String>? values,
    String? identityDirection,
    String? importantRelationships,
    String? longTermDirection,
    List<String>? changeReasons,
    int? updatedAtMs,
  }) {
    return MiGrowthValueProfile(
      values: values ?? this.values,
      identityDirection: identityDirection ?? this.identityDirection,
      importantRelationships: importantRelationships ?? this.importantRelationships,
      longTermDirection: longTermDirection ?? this.longTermDirection,
      changeReasons: changeReasons ?? this.changeReasons,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'values': values,
        'identity_direction': identityDirection,
        'important_relationships': importantRelationships,
        'long_term_direction': longTermDirection,
        'change_reasons': changeReasons,
        'updated_at_ms': updatedAtMs,
      };

  factory MiGrowthValueProfile.fromJson(Map<String, dynamic> json) {
    return MiGrowthValueProfile(
      values: _stringList(json['values']),
      identityDirection: (json['identity_direction'] ?? '').toString(),
      importantRelationships: (json['important_relationships'] ?? '').toString(),
      longTermDirection: (json['long_term_direction'] ?? '').toString(),
      changeReasons: _stringList(json['change_reasons']),
      updatedAtMs: _intValue(json['updated_at_ms']),
    );
  }

  static MiGrowthValueProfile fromRaw(String raw) {
    if (raw.trim().isEmpty) return const MiGrowthValueProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return MiGrowthValueProfile.fromJson(decoded);
      if (decoded is Map) return MiGrowthValueProfile.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return const MiGrowthValueProfile();
  }

  String encode() => jsonEncode(toJson());
}

class MiGrowthChangeTalk {
  final List<String> desire;
  final List<String> ability;
  final List<String> reasons;
  final List<String> need;
  final List<String> commitment;
  final List<String> activation;
  final List<String> takingSteps;

  const MiGrowthChangeTalk({
    this.desire = const <String>[],
    this.ability = const <String>[],
    this.reasons = const <String>[],
    this.need = const <String>[],
    this.commitment = const <String>[],
    this.activation = const <String>[],
    this.takingSteps = const <String>[],
  });

  bool get isEmpty => desire.isEmpty && ability.isEmpty && reasons.isEmpty && need.isEmpty && commitment.isEmpty && activation.isEmpty && takingSteps.isEmpty;

  List<String> get all => <String>[...desire, ...ability, ...reasons, ...need, ...commitment, ...activation, ...takingSteps];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'desire': desire,
        'ability': ability,
        'reasons': reasons,
        'need': need,
        'commitment': commitment,
        'activation': activation,
        'taking_steps': takingSteps,
      };

  factory MiGrowthChangeTalk.fromJson(Map<String, dynamic> json) => MiGrowthChangeTalk(
        desire: _stringList(json['desire']),
        ability: _stringList(json['ability']),
        reasons: _stringList(json['reasons']),
        need: _stringList(json['need']),
        commitment: _stringList(json['commitment']),
        activation: _stringList(json['activation']),
        takingSteps: _stringList(json['taking_steps']),
      );

  static MiGrowthChangeTalk fromRaw(String raw) {
    if (raw.trim().isEmpty) return const MiGrowthChangeTalk();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return MiGrowthChangeTalk.fromJson(decoded);
      if (decoded is Map) return MiGrowthChangeTalk.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return const MiGrowthChangeTalk();
  }

  String encode() => jsonEncode(toJson());
}

class MiGrowthActionPlan {
  final int? id;
  final int createdAtMs;
  final int updatedAtMs;
  final String title;
  final String focus;
  final String valueConnection;
  final String timeText;
  final String place;
  final String action;
  final String duration;
  final String backupPlan;
  final List<String> reviewQuestions;
  final int? confidenceScore;
  final String status;
  final int? sourceSessionId;

  const MiGrowthActionPlan({
    this.id,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.title = '',
    this.focus = '',
    this.valueConnection = '',
    this.timeText = '',
    this.place = '',
    this.action = '',
    this.duration = '',
    this.backupPlan = '',
    this.reviewQuestions = const <String>[],
    this.confidenceScore,
    this.status = 'open',
    this.sourceSessionId,
  });

  bool get hasConcreteStep => action.trim().isNotEmpty || title.trim().isNotEmpty;

  MiGrowthActionPlan copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    String? title,
    String? focus,
    String? valueConnection,
    String? timeText,
    String? place,
    String? action,
    String? duration,
    String? backupPlan,
    List<String>? reviewQuestions,
    int? confidenceScore,
    String? status,
    int? sourceSessionId,
  }) {
    return MiGrowthActionPlan(
      id: id ?? this.id,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      title: title ?? this.title,
      focus: focus ?? this.focus,
      valueConnection: valueConnection ?? this.valueConnection,
      timeText: timeText ?? this.timeText,
      place: place ?? this.place,
      action: action ?? this.action,
      duration: duration ?? this.duration,
      backupPlan: backupPlan ?? this.backupPlan,
      reviewQuestions: reviewQuestions ?? this.reviewQuestions,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      status: status ?? this.status,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'title': title,
        'focus': focus,
        'value_connection': valueConnection,
        'time_text': timeText,
        'place': place,
        'action': action,
        'duration': duration,
        'backup_plan': backupPlan,
        'review_questions': reviewQuestions,
        'confidence_score': confidenceScore,
        'status': status,
        'source_session_id': sourceSessionId,
      };

  factory MiGrowthActionPlan.fromJson(Map<String, dynamic> json) => MiGrowthActionPlan(
        id: _nullableInt(json['id']),
        createdAtMs: _intValue(json['created_at_ms']),
        updatedAtMs: _intValue(json['updated_at_ms']),
        title: (json['title'] ?? '').toString(),
        focus: (json['focus'] ?? '').toString(),
        valueConnection: (json['value_connection'] ?? '').toString(),
        timeText: (json['time_text'] ?? '').toString(),
        place: (json['place'] ?? '').toString(),
        action: (json['action'] ?? '').toString(),
        duration: (json['duration'] ?? '').toString(),
        backupPlan: (json['backup_plan'] ?? '').toString(),
        reviewQuestions: _stringList(json['review_questions']),
        confidenceScore: _nullableInt(json['confidence_score']),
        status: (json['status'] ?? 'open').toString(),
        sourceSessionId: _nullableInt(json['source_session_id']),
      );

  static MiGrowthActionPlan fromRaw(String raw) {
    if (raw.trim().isEmpty) return const MiGrowthActionPlan();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return MiGrowthActionPlan.fromJson(decoded);
      if (decoded is Map) return MiGrowthActionPlan.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return const MiGrowthActionPlan();
  }

  String encode() => jsonEncode(toJson());
}

class MiGrowthSessionRecord {
  final int? id;
  final int createdAtMs;
  final String scene;
  final String stage;
  final String userInput;
  final String aiResponse;
  final String focus;
  final List<String> valuesDetected;
  final MiGrowthChangeTalk changeTalk;
  final List<String> sustainTalk;
  final List<String> discordSignals;
  final MiGrowthActionPlan nextAction;
  final String riskLevel;
  final String strategy;

  const MiGrowthSessionRecord({
    this.id,
    this.createdAtMs = 0,
    this.scene = 'daily_growth',
    this.stage = 'engaging',
    this.userInput = '',
    this.aiResponse = '',
    this.focus = '',
    this.valuesDetected = const <String>[],
    this.changeTalk = const MiGrowthChangeTalk(),
    this.sustainTalk = const <String>[],
    this.discordSignals = const <String>[],
    this.nextAction = const MiGrowthActionPlan(),
    this.riskLevel = 'none',
    this.strategy = 'reflection',
  });

  MiGrowthSessionRecord copyWith({
    int? id,
    int? createdAtMs,
    String? scene,
    String? stage,
    String? userInput,
    String? aiResponse,
    String? focus,
    List<String>? valuesDetected,
    MiGrowthChangeTalk? changeTalk,
    List<String>? sustainTalk,
    List<String>? discordSignals,
    MiGrowthActionPlan? nextAction,
    String? riskLevel,
    String? strategy,
  }) {
    return MiGrowthSessionRecord(
      id: id ?? this.id,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      scene: scene ?? this.scene,
      stage: stage ?? this.stage,
      userInput: userInput ?? this.userInput,
      aiResponse: aiResponse ?? this.aiResponse,
      focus: focus ?? this.focus,
      valuesDetected: valuesDetected ?? this.valuesDetected,
      changeTalk: changeTalk ?? this.changeTalk,
      sustainTalk: sustainTalk ?? this.sustainTalk,
      discordSignals: discordSignals ?? this.discordSignals,
      nextAction: nextAction ?? this.nextAction,
      riskLevel: riskLevel ?? this.riskLevel,
      strategy: strategy ?? this.strategy,
    );
  }

  factory MiGrowthSessionRecord.fromMap(Map<String, Object?> row) => MiGrowthSessionRecord(
        id: _nullableInt(row['id']),
        createdAtMs: _intValue(row['created_at_ms']),
        scene: (row['scene'] ?? 'daily_growth').toString(),
        stage: (row['stage'] ?? 'engaging').toString(),
        userInput: (row['user_input'] ?? '').toString(),
        aiResponse: (row['ai_response'] ?? '').toString(),
        focus: (row['focus'] ?? '').toString(),
        valuesDetected: _stringListFromRaw((row['values_json'] ?? '').toString()),
        changeTalk: MiGrowthChangeTalk.fromRaw((row['change_talk_json'] ?? '').toString()),
        sustainTalk: _stringListFromRaw((row['sustain_talk_json'] ?? '').toString()),
        discordSignals: _stringListFromRaw((row['discord_json'] ?? '').toString()),
        nextAction: MiGrowthActionPlan.fromRaw((row['action_json'] ?? '').toString()),
        riskLevel: (row['risk_level'] ?? 'none').toString(),
        strategy: (row['strategy'] ?? 'reflection').toString(),
      );
}

class MiGrowthReviewRecord {
  final int? id;
  final int actionId;
  final int createdAtMs;
  final String status;
  final String whatHappened;
  final String donePart;
  final String stuckPart;
  final String nextAdjustment;
  final String valueConnection;

  const MiGrowthReviewRecord({
    this.id,
    this.actionId = 0,
    this.createdAtMs = 0,
    this.status = 'partial',
    this.whatHappened = '',
    this.donePart = '',
    this.stuckPart = '',
    this.nextAdjustment = '',
    this.valueConnection = '',
  });

  factory MiGrowthReviewRecord.fromMap(Map<String, Object?> row) => MiGrowthReviewRecord(
        id: _nullableInt(row['id']),
        actionId: _intValue(row['action_id']),
        createdAtMs: _intValue(row['created_at_ms']),
        status: (row['status'] ?? 'partial').toString(),
        whatHappened: (row['what_happened'] ?? '').toString(),
        donePart: (row['done_part'] ?? '').toString(),
        stuckPart: (row['stuck_part'] ?? '').toString(),
        nextAdjustment: (row['next_adjustment'] ?? '').toString(),
        valueConnection: (row['value_connection'] ?? '').toString(),
      );
}

class MiGrowthStats {
  final int sessions;
  final int actions;
  final int openActions;
  final int reviews;
  final int changeTalkCount;
  final int valueCount;

  const MiGrowthStats({
    this.sessions = 0,
    this.actions = 0,
    this.openActions = 0,
    this.reviews = 0,
    this.changeTalkCount = 0,
    this.valueCount = 0,
  });
}

List<String> _stringList(Object? value) {
  if (value == null) return <String>[];
  if (value is List) {
    return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  final raw = value.toString().trim();
  if (raw.isEmpty) return <String>[];
  if (raw.startsWith('[')) return _stringListFromRaw(raw);
  return raw.split(RegExp(r'[,，;；\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
}

List<String> _stringListFromRaw(String raw) {
  if (raw.trim().isEmpty) return <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return _stringList(decoded);
  } catch (_) {}
  return _stringList(raw);
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value.toString());
  return parsed;
}
