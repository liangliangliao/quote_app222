import 'dart:convert';

int _intValue(dynamic raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse((raw ?? '').toString()) ?? fallback;
}

bool _boolValue(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final text = (raw ?? '').toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes' || text == 'done' || text == 'completed';
}

List<String> _stringList(dynamic raw) {
  if (raw == null) return const <String>[];
  if (raw is List) {
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return _stringList(decoded);
    } catch (_) {}
    return text
        .split(RegExp(r'[,，;；\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return <String>[raw.toString()];
}

Map<String, dynamic> _map(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return _map(decoded);
    } catch (_) {}
  }
  return <String, dynamic>{};
}

String _string(dynamic raw) => (raw ?? '').toString();

class WoopActionCard {
  final int id;
  final int createdAtMs;
  final int updatedAtMs;
  final String source;
  final String scene;
  final String title;
  final String rawInput;
  final String currentJudgement;
  final String wish;
  final String outcome;
  final String obstacle;
  final String obstacleType;
  final List<String> obstacleTags;
  final String planIf;
  final String planThen;
  final String firstAction;
  final String reviewQuestion;
  final String reminder;
  final String feasibility;
  final String importance;
  final String controllability;
  final String cost;
  final String belongsToUser;
  final String direction;
  final String status;
  final String aiResponse;
  final String provider;
  final String modelLabel;
  final bool fromFallback;

  const WoopActionCard({
    this.id = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.source = 'manual',
    this.scene = 'action_conversion',
    this.title = '',
    this.rawInput = '',
    this.currentJudgement = '',
    this.wish = '',
    this.outcome = '',
    this.obstacle = '',
    this.obstacleType = '',
    this.obstacleTags = const <String>[],
    this.planIf = '',
    this.planThen = '',
    this.firstAction = '',
    this.reviewQuestion = '',
    this.reminder = '',
    this.feasibility = 'medium',
    this.importance = 'high',
    this.controllability = 'medium',
    this.cost = 'medium',
    this.belongsToUser = 'unclear',
    this.direction = 'continue',
    this.status = 'active',
    this.aiResponse = '',
    this.provider = 'local',
    this.modelLabel = '内置 WOOP 策略',
    this.fromFallback = true,
  });

  String get planText {
    final trigger = planIf.trim().isEmpty ? '关键障碍出现' : planIf.trim();
    final action = planThen.trim().isEmpty ? firstAction.trim() : planThen.trim();
    if (action.isEmpty) return '';
    return '如果$trigger，那么我就$action。';
  }

  bool get isActive => status == 'active';
  bool get isDone => status == 'done';
  bool get isArchived => status == 'archived' || status == 'dropped' || status == 'paused';

  WoopActionCard copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    String? source,
    String? scene,
    String? title,
    String? rawInput,
    String? currentJudgement,
    String? wish,
    String? outcome,
    String? obstacle,
    String? obstacleType,
    List<String>? obstacleTags,
    String? planIf,
    String? planThen,
    String? firstAction,
    String? reviewQuestion,
    String? reminder,
    String? feasibility,
    String? importance,
    String? controllability,
    String? cost,
    String? belongsToUser,
    String? direction,
    String? status,
    String? aiResponse,
    String? provider,
    String? modelLabel,
    bool? fromFallback,
  }) => WoopActionCard(
        id: id ?? this.id,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        source: source ?? this.source,
        scene: scene ?? this.scene,
        title: title ?? this.title,
        rawInput: rawInput ?? this.rawInput,
        currentJudgement: currentJudgement ?? this.currentJudgement,
        wish: wish ?? this.wish,
        outcome: outcome ?? this.outcome,
        obstacle: obstacle ?? this.obstacle,
        obstacleType: obstacleType ?? this.obstacleType,
        obstacleTags: obstacleTags ?? this.obstacleTags,
        planIf: planIf ?? this.planIf,
        planThen: planThen ?? this.planThen,
        firstAction: firstAction ?? this.firstAction,
        reviewQuestion: reviewQuestion ?? this.reviewQuestion,
        reminder: reminder ?? this.reminder,
        feasibility: feasibility ?? this.feasibility,
        importance: importance ?? this.importance,
        controllability: controllability ?? this.controllability,
        cost: cost ?? this.cost,
        belongsToUser: belongsToUser ?? this.belongsToUser,
        direction: direction ?? this.direction,
        status: status ?? this.status,
        aiResponse: aiResponse ?? this.aiResponse,
        provider: provider ?? this.provider,
        modelLabel: modelLabel ?? this.modelLabel,
        fromFallback: fromFallback ?? this.fromFallback,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'source': source,
        'scene': scene,
        'title': title,
        'raw_input': rawInput,
        'current_judgement': currentJudgement,
        'wish': wish,
        'outcome': outcome,
        'obstacle': obstacle,
        'obstacle_type': obstacleType,
        'obstacle_tags': obstacleTags,
        'plan_if': planIf,
        'plan_then': planThen,
        'first_action': firstAction,
        'review_question': reviewQuestion,
        'reminder': reminder,
        'feasibility': feasibility,
        'importance': importance,
        'controllability': controllability,
        'cost': cost,
        'belongs_to_user': belongsToUser,
        'direction': direction,
        'status': status,
        'ai_response': aiResponse,
        'provider': provider,
        'model_label': modelLabel,
        'from_fallback': fromFallback,
      };

  Map<String, Object?> toDbMap() => <String, Object?>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'source': source,
        'scene': scene,
        'title': title,
        'raw_input': rawInput,
        'current_judgement': currentJudgement,
        'wish': wish,
        'outcome': outcome,
        'obstacle': obstacle,
        'obstacle_type': obstacleType,
        'obstacle_tags_json': jsonEncode(obstacleTags),
        'plan_if': planIf,
        'plan_then': planThen,
        'first_action': firstAction,
        'review_question': reviewQuestion,
        'reminder': reminder,
        'feasibility': feasibility,
        'importance': importance,
        'controllability': controllability,
        'cost': cost,
        'belongs_to_user': belongsToUser,
        'direction': direction,
        'status': status,
        'ai_response': aiResponse,
        'provider': provider,
        'model_label': modelLabel,
        'from_fallback': fromFallback ? 1 : 0,
      };

  factory WoopActionCard.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final plan = _map(json['plan']);
    final target = _map(json['target_judgement']);
    final rawTags = json['obstacle_tags'] ?? json['obstacle_tags_json'] ?? json['tags'];
    final ifText = json['plan_if'] ?? plan['if'] ?? plan['trigger'] ?? '';
    final thenText = json['plan_then'] ?? plan['then'] ?? plan['action'] ?? '';
    return WoopActionCard(
      id: _intValue(json['id']),
      createdAtMs: _intValue(json['created_at_ms'], now),
      updatedAtMs: _intValue(json['updated_at_ms'], now),
      source: _string(json['source']).trim().isEmpty ? 'manual' : _string(json['source']).trim(),
      scene: _string(json['scene']).trim().isEmpty ? 'action_conversion' : _string(json['scene']).trim(),
      title: _string(json['title']).trim().isEmpty ? _string(json['wish']).trim() : _string(json['title']).trim(),
      rawInput: _string(json['raw_input'] ?? json['original_input']),
      currentJudgement: _string(json['current_judgement'] ?? json['current_judgment']),
      wish: _string(json['wish']),
      outcome: _string(json['outcome']),
      obstacle: _string(json['obstacle']),
      obstacleType: _string(json['obstacle_type']),
      obstacleTags: _stringList(rawTags),
      planIf: _string(ifText),
      planThen: _string(thenText),
      firstAction: _string(json['first_action'] ?? plan['first_action'] ?? plan['minimum_action']),
      reviewQuestion: _string(json['review_question'] ?? json['feedback_question']),
      reminder: _string(json['reminder']),
      feasibility: _string(json['feasibility'] ?? target['feasibility']).trim().isEmpty ? 'medium' : _string(json['feasibility'] ?? target['feasibility']).trim(),
      importance: _string(json['importance'] ?? target['importance']).trim().isEmpty ? 'high' : _string(json['importance'] ?? target['importance']).trim(),
      controllability: _string(json['controllability'] ?? target['controllability']).trim().isEmpty ? 'medium' : _string(json['controllability'] ?? target['controllability']).trim(),
      cost: _string(json['cost'] ?? target['cost']).trim().isEmpty ? 'medium' : _string(json['cost'] ?? target['cost']).trim(),
      belongsToUser: _string(json['belongs_to_user'] ?? target['belongs_to_user']).trim().isEmpty ? 'unclear' : _string(json['belongs_to_user'] ?? target['belongs_to_user']).trim(),
      direction: _string(json['direction']).trim().isEmpty ? 'continue' : _string(json['direction']).trim(),
      status: _string(json['status']).trim().isEmpty ? 'active' : _string(json['status']).trim(),
      aiResponse: _string(json['ai_response']),
      provider: _string(json['provider']).trim().isEmpty ? 'local' : _string(json['provider']).trim(),
      modelLabel: _string(json['model_label']).trim().isEmpty ? '内置 WOOP 策略' : _string(json['model_label']).trim(),
      fromFallback: _boolValue(json['from_fallback'] ?? true),
    );
  }

  factory WoopActionCard.fromDb(Map<String, Object?> row) => WoopActionCard.fromJson(<String, dynamic>{
        'id': row['id'],
        'created_at_ms': row['created_at_ms'],
        'updated_at_ms': row['updated_at_ms'],
        'source': row['source'],
        'scene': row['scene'],
        'title': row['title'],
        'raw_input': row['raw_input'],
        'current_judgement': row['current_judgement'],
        'wish': row['wish'],
        'outcome': row['outcome'],
        'obstacle': row['obstacle'],
        'obstacle_type': row['obstacle_type'],
        'obstacle_tags_json': row['obstacle_tags_json'],
        'plan_if': row['plan_if'],
        'plan_then': row['plan_then'],
        'first_action': row['first_action'],
        'review_question': row['review_question'],
        'reminder': row['reminder'],
        'feasibility': row['feasibility'],
        'importance': row['importance'],
        'controllability': row['controllability'],
        'cost': row['cost'],
        'belongs_to_user': row['belongs_to_user'],
        'direction': row['direction'],
        'status': row['status'],
        'ai_response': row['ai_response'],
        'provider': row['provider'],
        'model_label': row['model_label'],
        'from_fallback': row['from_fallback'],
      });
}

class WoopActionReview {
  final int id;
  final int cardId;
  final int createdAtMs;
  final String result;
  final String actualEvent;
  final String obstacleAppeared;
  final String planWorked;
  final String newObstacle;
  final String nextAdjustment;
  final String note;

  const WoopActionReview({
    this.id = 0,
    this.cardId = 0,
    this.createdAtMs = 0,
    this.result = 'unknown',
    this.actualEvent = '',
    this.obstacleAppeared = '',
    this.planWorked = '',
    this.newObstacle = '',
    this.nextAdjustment = '',
    this.note = '',
  });

  Map<String, Object?> toDbMap() => <String, Object?>{
        if (id > 0) 'id': id,
        'card_id': cardId,
        'created_at_ms': createdAtMs,
        'result': result,
        'actual_event': actualEvent,
        'obstacle_appeared': obstacleAppeared,
        'plan_worked': planWorked,
        'new_obstacle': newObstacle,
        'next_adjustment': nextAdjustment,
        'note': note,
      };

  factory WoopActionReview.fromDb(Map<String, Object?> row) => WoopActionReview(
        id: _intValue(row['id']),
        cardId: _intValue(row['card_id']),
        createdAtMs: _intValue(row['created_at_ms']),
        result: _string(row['result']),
        actualEvent: _string(row['actual_event']),
        obstacleAppeared: _string(row['obstacle_appeared']),
        planWorked: _string(row['plan_worked']),
        newObstacle: _string(row['new_obstacle']),
        nextAdjustment: _string(row['next_adjustment']),
        note: _string(row['note']),
      );
}

class WoopActionPlanLog {
  final int id;
  final int cardId;
  final int createdAtMs;
  final String triggerText;
  final String actionText;
  final String result;
  final String note;

  const WoopActionPlanLog({
    this.id = 0,
    this.cardId = 0,
    this.createdAtMs = 0,
    this.triggerText = '',
    this.actionText = '',
    this.result = 'unknown',
    this.note = '',
  });

  Map<String, Object?> toDbMap() => <String, Object?>{
        if (id > 0) 'id': id,
        'card_id': cardId,
        'created_at_ms': createdAtMs,
        'trigger_text': triggerText,
        'action_text': actionText,
        'result': result,
        'note': note,
      };

  factory WoopActionPlanLog.fromDb(Map<String, Object?> row) => WoopActionPlanLog(
        id: _intValue(row['id']),
        cardId: _intValue(row['card_id']),
        createdAtMs: _intValue(row['created_at_ms']),
        triggerText: _string(row['trigger_text']),
        actionText: _string(row['action_text']),
        result: _string(row['result']),
        note: _string(row['note']),
      );
}

class WoopActionDailyCheckIn {
  final int id;
  final int createdAtMs;
  final String dateKey;
  final String energy;
  final String mood;
  final String mainWish;
  final int selectedCardId;
  final String note;

  const WoopActionDailyCheckIn({
    this.id = 0,
    this.createdAtMs = 0,
    this.dateKey = '',
    this.energy = 'medium',
    this.mood = '',
    this.mainWish = '',
    this.selectedCardId = 0,
    this.note = '',
  });

  Map<String, Object?> toDbMap() => <String, Object?>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'date_key': dateKey,
        'energy': energy,
        'mood': mood,
        'main_wish': mainWish,
        'selected_card_id': selectedCardId,
        'note': note,
      };

  factory WoopActionDailyCheckIn.fromDb(Map<String, Object?> row) => WoopActionDailyCheckIn(
        id: _intValue(row['id']),
        createdAtMs: _intValue(row['created_at_ms']),
        dateKey: _string(row['date_key']),
        energy: _string(row['energy']).trim().isEmpty ? 'medium' : _string(row['energy']).trim(),
        mood: _string(row['mood']),
        mainWish: _string(row['main_wish']),
        selectedCardId: _intValue(row['selected_card_id']),
        note: _string(row['note']),
      );
}

class WoopActionProfile {
  final int updatedAtMs;
  final String userValues;
  final List<String> lifeDomains;
  final List<String> commonObstacles;
  final String preferredActionWindow;
  final String supportBoundary;
  final String professionalHelpReminder;

  const WoopActionProfile({
    this.updatedAtMs = 0,
    this.userValues = '',
    this.lifeDomains = const <String>[],
    this.commonObstacles = const <String>[],
    this.preferredActionWindow = '',
    this.supportBoundary = '',
    this.professionalHelpReminder = 'WOOP 是自我调节工具；涉及医疗、法律、财务、严重心理风险时应寻求专业支持。',
  });

  bool get isEmpty =>
      userValues.trim().isEmpty &&
      lifeDomains.isEmpty &&
      commonObstacles.isEmpty &&
      preferredActionWindow.trim().isEmpty &&
      supportBoundary.trim().isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'updated_at_ms': updatedAtMs,
        'user_values': userValues,
        'life_domains': lifeDomains,
        'common_obstacles': commonObstacles,
        'preferred_action_window': preferredActionWindow,
        'support_boundary': supportBoundary,
        'professional_help_reminder': professionalHelpReminder,
      };

  String toContextText() {
    final parts = <String>[];
    if (userValues.trim().isNotEmpty) parts.add('用户长期价值/重视方向：$userValues');
    if (lifeDomains.isNotEmpty) parts.add('用户关注生活领域：${lifeDomains.join('、')}');
    if (commonObstacles.isNotEmpty) parts.add('用户常见内在障碍：${commonObstacles.join('、')}');
    if (preferredActionWindow.trim().isNotEmpty) parts.add('用户偏好的最小行动窗口：$preferredActionWindow');
    if (supportBoundary.trim().isNotEmpty) parts.add('需要尊重的边界：$supportBoundary');
    if (professionalHelpReminder.trim().isNotEmpty) parts.add('专业边界提醒：$professionalHelpReminder');
    return parts.join('\n');
  }

  factory WoopActionProfile.fromJson(Map<String, dynamic> json) => WoopActionProfile(
        updatedAtMs: _intValue(json['updated_at_ms']),
        userValues: _string(json['user_values']),
        lifeDomains: _stringList(json['life_domains']),
        commonObstacles: _stringList(json['common_obstacles']),
        preferredActionWindow: _string(json['preferred_action_window']),
        supportBoundary: _string(json['support_boundary']),
        professionalHelpReminder: _string(json['professional_help_reminder']).trim().isEmpty
            ? 'WOOP 是自我调节工具；涉及医疗、法律、财务、严重心理风险时应寻求专业支持。'
            : _string(json['professional_help_reminder']),
      );

  factory WoopActionProfile.fromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const WoopActionProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return WoopActionProfile.fromJson(_map(decoded));
    } catch (_) {}
    return const WoopActionProfile();
  }
}


class WoopActionExperiment {
  final int id;
  final int cardId;
  final int createdAtMs;
  final int updatedAtMs;
  final String title;
  final String hypothesis;
  final String triggerText;
  final String actionText;
  final String expectedDifficulty;
  final int scheduledAtMs;
  final String status;
  final String result;
  final String learning;

  const WoopActionExperiment({
    this.id = 0,
    this.cardId = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.title = '',
    this.hypothesis = '',
    this.triggerText = '',
    this.actionText = '',
    this.expectedDifficulty = 'medium',
    this.scheduledAtMs = 0,
    this.status = 'planned',
    this.result = '',
    this.learning = '',
  });

  Map<String, Object?> toDbMap() => <String, Object?>{
        if (id > 0) 'id': id,
        'card_id': cardId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'title': title,
        'hypothesis': hypothesis,
        'trigger_text': triggerText,
        'action_text': actionText,
        'expected_difficulty': expectedDifficulty,
        'scheduled_at_ms': scheduledAtMs,
        'status': status,
        'result': result,
        'learning': learning,
      };

  factory WoopActionExperiment.fromDb(Map<String, Object?> row) => WoopActionExperiment(
        id: _intValue(row['id']),
        cardId: _intValue(row['card_id']),
        createdAtMs: _intValue(row['created_at_ms']),
        updatedAtMs: _intValue(row['updated_at_ms']),
        title: _string(row['title']),
        hypothesis: _string(row['hypothesis']),
        triggerText: _string(row['trigger_text']),
        actionText: _string(row['action_text']),
        expectedDifficulty: _string(row['expected_difficulty']).trim().isEmpty ? 'medium' : _string(row['expected_difficulty']).trim(),
        scheduledAtMs: _intValue(row['scheduled_at_ms']),
        status: _string(row['status']).trim().isEmpty ? 'planned' : _string(row['status']).trim(),
        result: _string(row['result']),
        learning: _string(row['learning']),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'card_id': cardId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'title': title,
        'hypothesis': hypothesis,
        'trigger_text': triggerText,
        'action_text': actionText,
        'expected_difficulty': expectedDifficulty,
        'scheduled_at_ms': scheduledAtMs,
        'status': status,
        'result': result,
        'learning': learning,
      };
}

class WoopActionCourseProgress {
  final int id;
  final String unitId;
  final int createdAtMs;
  final int updatedAtMs;
  final int completedAtMs;
  final String status;
  final String reflection;

  const WoopActionCourseProgress({
    this.id = 0,
    this.unitId = '',
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.completedAtMs = 0,
    this.status = 'open',
    this.reflection = '',
  });

  bool get isDone => status == 'done' || completedAtMs > 0;

  Map<String, Object?> toDbMap() => <String, Object?>{
        if (id > 0) 'id': id,
        'unit_id': unitId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'completed_at_ms': completedAtMs,
        'status': status,
        'reflection': reflection,
      };

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'unit_id': unitId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'completed_at_ms': completedAtMs,
        'status': status,
        'reflection': reflection,
      };

  factory WoopActionCourseProgress.fromDb(Map<String, Object?> row) => WoopActionCourseProgress(
        id: _intValue(row['id']),
        unitId: _string(row['unit_id']),
        createdAtMs: _intValue(row['created_at_ms']),
        updatedAtMs: _intValue(row['updated_at_ms']),
        completedAtMs: _intValue(row['completed_at_ms']),
        status: _string(row['status']).trim().isEmpty ? 'open' : _string(row['status']).trim(),
        reflection: _string(row['reflection']),
      );
}
