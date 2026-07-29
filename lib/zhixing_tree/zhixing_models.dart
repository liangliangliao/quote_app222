import 'dart:convert';

enum ZhixingChallengeType {
  recovery,
  direction,
  start,
  breakthrough,
  strengthen,
  sustain,
  calibrate,
  stopLoss,
  collaborate,
  generate,
}

extension ZhixingChallengeTypeX on ZhixingChallengeType {
  String get code {
    switch (this) {
      case ZhixingChallengeType.recovery:
        return 'recovery';
      case ZhixingChallengeType.direction:
        return 'direction';
      case ZhixingChallengeType.start:
        return 'start';
      case ZhixingChallengeType.breakthrough:
        return 'breakthrough';
      case ZhixingChallengeType.strengthen:
        return 'strengthen';
      case ZhixingChallengeType.sustain:
        return 'sustain';
      case ZhixingChallengeType.calibrate:
        return 'calibrate';
      case ZhixingChallengeType.stopLoss:
        return 'stop_loss';
      case ZhixingChallengeType.collaborate:
        return 'collaborate';
      case ZhixingChallengeType.generate:
        return 'generate';
    }
  }

  String get label {
    switch (this) {
      case ZhixingChallengeType.recovery:
        return '恢复型';
      case ZhixingChallengeType.direction:
        return '定向型';
      case ZhixingChallengeType.start:
        return '启动型';
      case ZhixingChallengeType.breakthrough:
        return '突破型';
      case ZhixingChallengeType.strengthen:
        return '增强型';
      case ZhixingChallengeType.sustain:
        return '持续型';
      case ZhixingChallengeType.calibrate:
        return '校准型';
      case ZhixingChallengeType.stopLoss:
        return '止损型';
      case ZhixingChallengeType.collaborate:
        return '协同型';
      case ZhixingChallengeType.generate:
        return '生成型';
    }
  }

  static ZhixingChallengeType parse(Object? value) {
    final code = value?.toString().trim().toLowerCase() ?? '';
    return ZhixingChallengeType.values.firstWhere(
      (item) => item.code == code,
      orElse: () => ZhixingChallengeType.start,
    );
  }
}

enum ZhixingDifficulty { l1, l2, l3, l4 }

extension ZhixingDifficultyX on ZhixingDifficulty {
  String get code => name.toUpperCase();

  String get label {
    switch (this) {
      case ZhixingDifficulty.l1:
        return 'L1 微行动';
      case ZhixingDifficulty.l2:
        return 'L2 标准行动';
      case ZhixingDifficulty.l3:
        return 'L3 挑战行动';
      case ZhixingDifficulty.l4:
        return 'L4 转型行动';
    }
  }

  static ZhixingDifficulty parse(Object? value) {
    final code = value?.toString().trim().toLowerCase() ?? '';
    return ZhixingDifficulty.values.firstWhere(
      (item) => item.name == code,
      orElse: () => ZhixingDifficulty.l1,
    );
  }
}

enum ZhixingRiskLevel { none, elevated, high, crisis }

extension ZhixingRiskLevelX on ZhixingRiskLevel {
  String get code => name;

  static ZhixingRiskLevel parse(Object? value) {
    final code = value?.toString().trim().toLowerCase() ?? '';
    return ZhixingRiskLevel.values.firstWhere(
      (item) => item.name == code,
      orElse: () => ZhixingRiskLevel.none,
    );
  }
}

enum ZhixingActionStatus { ready, started, blocked, completed, recalibrate }

extension ZhixingActionStatusX on ZhixingActionStatus {
  String get code => name;

  static ZhixingActionStatus parse(Object? value) {
    final code = value?.toString().trim().toLowerCase() ?? '';
    return ZhixingActionStatus.values.firstWhere(
      (item) => item.name == code,
      orElse: () => ZhixingActionStatus.ready,
    );
  }
}

class ZhixingDiagnosis {
  final String id;
  final int createdAtMs;
  final String problem;
  final String autonomy;
  final String clarity;
  final String barrier;
  final String discomfort;
  final String experience;
  final String phase;
  final int availableMinutes;
  final List<String> values;
  final String note;
  final ZhixingRiskLevel risk;

  const ZhixingDiagnosis({
    required this.id,
    required this.createdAtMs,
    required this.problem,
    required this.autonomy,
    required this.clarity,
    required this.barrier,
    required this.discomfort,
    required this.experience,
    required this.phase,
    required this.availableMinutes,
    required this.values,
    this.note = '',
    this.risk = ZhixingRiskLevel.none,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'created_at_ms': createdAtMs,
        'problem': problem,
        'autonomy': autonomy,
        'clarity': clarity,
        'barrier': barrier,
        'discomfort': discomfort,
        'experience': experience,
        'phase': phase,
        'available_minutes': availableMinutes,
        'values': values,
        'note': note,
        'risk': risk.code,
      };

  static ZhixingDiagnosis fromJson(Map<String, dynamic> map) {
    return ZhixingDiagnosis(
      id: _string(map['id']),
      createdAtMs: _integer(map['created_at_ms'], DateTime.now().millisecondsSinceEpoch),
      problem: _string(map['problem']),
      autonomy: _string(map['autonomy'], 'partly'),
      clarity: _string(map['clarity'], 'vague'),
      barrier: _string(map['barrier'], 'thought'),
      discomfort: _string(map['discomfort'], 'moderate'),
      experience: _string(map['experience'], 'sometimes'),
      phase: _string(map['phase'], 'start'),
      availableMinutes: _integer(map['available_minutes'], 10),
      values: _strings(map['values']),
      note: _string(map['note']),
      risk: ZhixingRiskLevelX.parse(map['risk']),
    );
  }
}

class ZhixingActionProfile {
  final double autonomy;
  final double clarity;
  final double cognitiveFlexibility;
  final double willingness;
  final double selfEfficacy;
  final double optimalism;
  final double habitStructure;
  final double energy;
  final double opportunity;
  final double safety;
  final int completedCount;
  final int recalibrationCount;
  final int updatedAtMs;

  const ZhixingActionProfile({
    this.autonomy = .5,
    this.clarity = .5,
    this.cognitiveFlexibility = .5,
    this.willingness = .5,
    this.selfEfficacy = .5,
    this.optimalism = .5,
    this.habitStructure = .5,
    this.energy = .5,
    this.opportunity = .5,
    this.safety = 1,
    this.completedCount = 0,
    this.recalibrationCount = 0,
    this.updatedAtMs = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'autonomy': autonomy,
        'clarity': clarity,
        'cognitive_flexibility': cognitiveFlexibility,
        'willingness': willingness,
        'self_efficacy': selfEfficacy,
        'optimalism': optimalism,
        'habit_structure': habitStructure,
        'energy': energy,
        'opportunity': opportunity,
        'safety': safety,
        'completed_count': completedCount,
        'recalibration_count': recalibrationCount,
        'updated_at_ms': updatedAtMs,
      };

  String encode() => jsonEncode(toJson());

  static ZhixingActionProfile decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return fromJson(decoded.map((key, value) => MapEntry(key.toString(), value)));
      }
    } catch (_) {}
    return const ZhixingActionProfile();
  }

  static ZhixingActionProfile fromJson(Map<String, dynamic> map) {
    return ZhixingActionProfile(
      autonomy: _unit(map['autonomy']),
      clarity: _unit(map['clarity']),
      cognitiveFlexibility: _unit(map['cognitive_flexibility']),
      willingness: _unit(map['willingness']),
      selfEfficacy: _unit(map['self_efficacy']),
      optimalism: _unit(map['optimalism']),
      habitStructure: _unit(map['habit_structure']),
      energy: _unit(map['energy']),
      opportunity: _unit(map['opportunity']),
      safety: _unit(map['safety'], fallback: 1),
      completedCount: _integer(map['completed_count'], 0),
      recalibrationCount: _integer(map['recalibration_count'], 0),
      updatedAtMs: _integer(map['updated_at_ms'], 0),
    );
  }
}

class ZhixingThoughtMatch {
  final String dominant;
  final String executionTool;
  final List<String> assistants;
  final String balancing;
  final String rationale;
  final String boundary;
  final double confidence;
  final List<String> sources;

  const ZhixingThoughtMatch({
    required this.dominant,
    required this.executionTool,
    this.assistants = const <String>[],
    required this.balancing,
    required this.rationale,
    required this.boundary,
    required this.confidence,
    this.sources = const <String>[],
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dominant': dominant,
        'execution_tool': executionTool,
        'assistants': assistants,
        'balancing': balancing,
        'rationale': rationale,
        'boundary': boundary,
        'confidence': confidence,
        'sources': sources,
      };

  static ZhixingThoughtMatch fromJson(Map<String, dynamic> map) {
    return ZhixingThoughtMatch(
      dominant: _string(map['dominant'], '威廉·詹姆斯'),
      executionTool: _string(map['execution_tool'], '第一身体动作 + 如果—那么计划'),
      assistants: _strings(map['assistants']),
      balancing: _string(map['balancing'], 'COM-B：检查现实条件'),
      rationale: _string(map['rationale'], '当前最需要把抽象目标翻译成可观察动作。'),
      boundary: _string(map['boundary'], '这是一种行动启发式，不是临床诊断。'),
      confidence: _unit(map['confidence'], fallback: .65),
      sources: _strings(map['sources']),
    );
  }
}

class ZhixingPrescription {
  final String id;
  final String diagnosisId;
  final int createdAtMs;
  final int updatedAtMs;
  final String problem;
  final ZhixingChallengeType challengeType;
  final ZhixingDifficulty difficulty;
  final String title;
  final String value;
  final String action;
  final String trigger;
  final String firstPhysicalAction;
  final String successEvidence;
  final String stuckShrink;
  final String stuckAdapt;
  final String stuckCarry;
  final String stuckReconsider;
  final ZhixingThoughtMatch thoughtMatch;
  final int rewardXp;
  final int rewardCoins;
  final int rewardWater;
  final int rewardSunlight;
  final int rewardFertilizer;
  final ZhixingRiskLevel risk;
  final String safetyMessage;
  final ZhixingActionStatus status;
  final int? startedAtMs;
  final int? completedAtMs;
  final String provider;
  final String modelLabel;
  final String selectedStuckStrategy;

  const ZhixingPrescription({
    required this.id,
    required this.diagnosisId,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.problem,
    required this.challengeType,
    required this.difficulty,
    required this.title,
    required this.value,
    required this.action,
    required this.trigger,
    required this.firstPhysicalAction,
    required this.successEvidence,
    required this.stuckShrink,
    required this.stuckAdapt,
    required this.stuckCarry,
    required this.stuckReconsider,
    required this.thoughtMatch,
    required this.rewardXp,
    required this.rewardCoins,
    this.rewardWater = 0,
    this.rewardSunlight = 0,
    this.rewardFertilizer = 0,
    this.risk = ZhixingRiskLevel.none,
    this.safetyMessage = '',
    this.status = ZhixingActionStatus.ready,
    this.startedAtMs,
    this.completedAtMs,
    this.provider = 'local',
    this.modelLabel = '内置知行策略',
    this.selectedStuckStrategy = '',
  });

  bool get isSafetyRoute =>
      risk == ZhixingRiskLevel.high || risk == ZhixingRiskLevel.crisis;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'diagnosis_id': diagnosisId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'problem': problem,
        'challenge_type': challengeType.code,
        'difficulty': difficulty.name,
        'title': title,
        'value': value,
        'action': action,
        'trigger': trigger,
        'first_physical_action': firstPhysicalAction,
        'success_evidence': successEvidence,
        'stuck_shrink': stuckShrink,
        'stuck_adapt': stuckAdapt,
        'stuck_carry': stuckCarry,
        'stuck_reconsider': stuckReconsider,
        'thought_match': thoughtMatch.toJson(),
        'reward_xp': rewardXp,
        'reward_coins': rewardCoins,
        'reward_water': rewardWater,
        'reward_sunlight': rewardSunlight,
        'reward_fertilizer': rewardFertilizer,
        'risk': risk.code,
        'safety_message': safetyMessage,
        'status': status.code,
        'started_at_ms': startedAtMs,
        'completed_at_ms': completedAtMs,
        'provider': provider,
        'model_label': modelLabel,
        'selected_stuck_strategy': selectedStuckStrategy,
      };

  String encode() => jsonEncode(toJson());

  static ZhixingPrescription decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid ZhixingPrescription JSON');
    }
    return fromJson(decoded.map((key, value) => MapEntry(key.toString(), value)));
  }

  static ZhixingPrescription fromJson(Map<String, dynamic> map) {
    final match = _map(map['thought_match']);
    return ZhixingPrescription(
      id: _string(map['id']),
      diagnosisId: _string(map['diagnosis_id']),
      createdAtMs: _integer(map['created_at_ms'], DateTime.now().millisecondsSinceEpoch),
      updatedAtMs: _integer(map['updated_at_ms'], DateTime.now().millisecondsSinceEpoch),
      problem: _string(map['problem']),
      challengeType: ZhixingChallengeTypeX.parse(map['challenge_type']),
      difficulty: ZhixingDifficultyX.parse(map['difficulty']),
      title: _string(map['title'], '今天的知行卡'),
      value: _string(map['value'], '成长'),
      action: _string(map['action'], '完成一个 5 分钟最小行动。'),
      trigger: _string(map['trigger'], '今天第一个可用的 5 分钟'),
      firstPhysicalAction: _string(map['first_physical_action'], '打开所需材料'),
      successEvidence: _string(map['success_evidence'], '留下一个可见的完成记录'),
      stuckShrink: _string(map['stuck_shrink'], '把行动缩小到 30 秒，只完成第一动作。'),
      stuckAdapt: _string(map['stuck_adapt'], '移除一个环境阻力或请求具体支持。'),
      stuckCarry: _string(map['stuck_carry'], '允许不适存在，同时完成最低动作。'),
      stuckReconsider: _string(map['stuck_reconsider'], '暂停并检查目标、风险、资源或恢复需要。'),
      thoughtMatch: ZhixingThoughtMatch.fromJson(match),
      rewardXp: _integer(map['reward_xp'], 5),
      rewardCoins: _integer(map['reward_coins'], 5),
      rewardWater: _integer(map['reward_water'], 0),
      rewardSunlight: _integer(map['reward_sunlight'], 0),
      rewardFertilizer: _integer(map['reward_fertilizer'], 0),
      risk: ZhixingRiskLevelX.parse(map['risk']),
      safetyMessage: _string(map['safety_message']),
      status: ZhixingActionStatusX.parse(map['status']),
      startedAtMs: _nullableInteger(map['started_at_ms']),
      completedAtMs: _nullableInteger(map['completed_at_ms']),
      provider: _string(map['provider'], 'local'),
      modelLabel: _string(map['model_label'], '内置知行策略'),
      selectedStuckStrategy: _string(map['selected_stuck_strategy']),
    );
  }

  ZhixingPrescription copyWith({
    int? updatedAtMs,
    String? title,
    String? value,
    String? action,
    String? trigger,
    String? firstPhysicalAction,
    String? successEvidence,
    String? stuckShrink,
    String? stuckAdapt,
    String? stuckCarry,
    String? stuckReconsider,
    ZhixingThoughtMatch? thoughtMatch,
    ZhixingActionStatus? status,
    int? startedAtMs,
    bool clearStartedAt = false,
    int? completedAtMs,
    bool clearCompletedAt = false,
    String? provider,
    String? modelLabel,
    String? selectedStuckStrategy,
  }) {
    return ZhixingPrescription(
      id: id,
      diagnosisId: diagnosisId,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      problem: problem,
      challengeType: challengeType,
      difficulty: difficulty,
      title: title ?? this.title,
      value: value ?? this.value,
      action: action ?? this.action,
      trigger: trigger ?? this.trigger,
      firstPhysicalAction: firstPhysicalAction ?? this.firstPhysicalAction,
      successEvidence: successEvidence ?? this.successEvidence,
      stuckShrink: stuckShrink ?? this.stuckShrink,
      stuckAdapt: stuckAdapt ?? this.stuckAdapt,
      stuckCarry: stuckCarry ?? this.stuckCarry,
      stuckReconsider: stuckReconsider ?? this.stuckReconsider,
      thoughtMatch: thoughtMatch ?? this.thoughtMatch,
      rewardXp: rewardXp,
      rewardCoins: rewardCoins,
      rewardWater: rewardWater,
      rewardSunlight: rewardSunlight,
      rewardFertilizer: rewardFertilizer,
      risk: risk,
      safetyMessage: safetyMessage,
      status: status ?? this.status,
      startedAtMs: clearStartedAt ? null : (startedAtMs ?? this.startedAtMs),
      completedAtMs: clearCompletedAt ? null : (completedAtMs ?? this.completedAtMs),
      provider: provider ?? this.provider,
      modelLabel: modelLabel ?? this.modelLabel,
      selectedStuckStrategy: selectedStuckStrategy ?? this.selectedStuckStrategy,
    );
  }
}

class ZhixingEvidence {
  final String id;
  final String prescriptionId;
  final int createdAtMs;
  final bool completed;
  final double predictedDiscomfort;
  final double actualDiscomfort;
  final String fit;
  final String scale;
  final String factResult;
  final String learning;
  final String nextStep;

  const ZhixingEvidence({
    required this.id,
    required this.prescriptionId,
    required this.createdAtMs,
    required this.completed,
    required this.predictedDiscomfort,
    required this.actualDiscomfort,
    required this.fit,
    required this.scale,
    required this.factResult,
    required this.learning,
    required this.nextStep,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'prescription_id': prescriptionId,
        'created_at_ms': createdAtMs,
        'completed': completed,
        'predicted_discomfort': predictedDiscomfort,
        'actual_discomfort': actualDiscomfort,
        'fit': fit,
        'scale': scale,
        'fact_result': factResult,
        'learning': learning,
        'next_step': nextStep,
      };

  String encode() => jsonEncode(toJson());

  static ZhixingEvidence decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Invalid evidence JSON');
    return fromJson(decoded.map((key, value) => MapEntry(key.toString(), value)));
  }

  static ZhixingEvidence fromJson(Map<String, dynamic> map) {
    return ZhixingEvidence(
      id: _string(map['id']),
      prescriptionId: _string(map['prescription_id']),
      createdAtMs: _integer(map['created_at_ms'], DateTime.now().millisecondsSinceEpoch),
      completed: _boolean(map['completed']),
      predictedDiscomfort: _number(map['predicted_discomfort'], 5),
      actualDiscomfort: _number(map['actual_discomfort'], 5),
      fit: _string(map['fit'], '合适'),
      scale: _string(map['scale'], '合适'),
      factResult: _string(map['fact_result']),
      learning: _string(map['learning']),
      nextStep: _string(map['next_step']),
    );
  }
}

class ZhixingGameState {
  final int xp;
  final int coins;
  final int water;
  final int sunlight;
  final int fertilizer;
  final int dailyXp;
  final int dailyCoins;
  final String dayKey;
  final int level;
  final String stage;
  final String highestStage;
  final String condition;
  final double health;
  final bool dormant;
  final int rebirthCount;
  final int treeBirthAtMs;
  final int? lastActionAtMs;
  final int completedCount;
  final int returnCount;

  const ZhixingGameState({
    this.xp = 0,
    this.coins = 0,
    this.water = 1,
    this.sunlight = 1,
    this.fertilizer = 0,
    this.dailyXp = 0,
    this.dailyCoins = 0,
    this.dayKey = '',
    this.level = 1,
    this.stage = 'seed',
    this.highestStage = 'seed',
    this.condition = 'healthy',
    this.health = 100,
    this.dormant = false,
    this.rebirthCount = 0,
    this.treeBirthAtMs = 0,
    this.lastActionAtMs,
    this.completedCount = 0,
    this.returnCount = 0,
  });

  String get levelTitle {
    const titles = <String>['', '觉察者', '启动者', '行动者', '复归者', '突破者', '调整者', '自主者'];
    return titles[level.clamp(1, 7).toInt()];
  }

  String get stageLabel {
    const labels = <String, String>{
      'seed': '种子',
      'sprout': '发芽',
      'sapling': '幼苗',
      'small_tree': '小树',
      'mature_tree': '成树',
      'great_tree': '大树',
      'ancient_tree': '苍天大树',
    };
    return labels[stage] ?? '种子';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'xp': xp,
        'coins': coins,
        'water': water,
        'sunlight': sunlight,
        'fertilizer': fertilizer,
        'daily_xp': dailyXp,
        'daily_coins': dailyCoins,
        'day_key': dayKey,
        'level': level,
        'stage': stage,
        'highest_stage': highestStage,
        'condition': condition,
        'health': health,
        'dormant': dormant,
        'rebirth_count': rebirthCount,
        'tree_birth_at_ms': treeBirthAtMs,
        'last_action_at_ms': lastActionAtMs,
        'completed_count': completedCount,
        'return_count': returnCount,
      };

  String encode() => jsonEncode(toJson());

  static ZhixingGameState decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return fromJson(decoded.map((key, value) => MapEntry(key.toString(), value)));
      }
    } catch (_) {}
    return ZhixingGameState(treeBirthAtMs: DateTime.now().millisecondsSinceEpoch);
  }

  static ZhixingGameState fromJson(Map<String, dynamic> map) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ZhixingGameState(
      xp: _integer(map['xp'], 0),
      coins: _integer(map['coins'], 0),
      water: _integer(map['water'], 1),
      sunlight: _integer(map['sunlight'], 1),
      fertilizer: _integer(map['fertilizer'], 0),
      dailyXp: _integer(map['daily_xp'], 0),
      dailyCoins: _integer(map['daily_coins'], 0),
      dayKey: _string(map['day_key']),
      level: _integer(map['level'], 1).clamp(1, 7).toInt(),
      stage: _string(map['stage'], 'seed'),
      highestStage: _string(map['highest_stage'], 'seed'),
      condition: _string(map['condition'], 'healthy'),
      health: _number(map['health'], 100).clamp(0, 100).toDouble(),
      dormant: _boolean(map['dormant']),
      rebirthCount: _integer(map['rebirth_count'], 0),
      treeBirthAtMs: _integer(map['tree_birth_at_ms'], now),
      lastActionAtMs: _nullableInteger(map['last_action_at_ms']),
      completedCount: _integer(map['completed_count'], 0),
      returnCount: _integer(map['return_count'], 0),
    );
  }

  ZhixingGameState copyWith({
    int? xp,
    int? coins,
    int? water,
    int? sunlight,
    int? fertilizer,
    int? dailyXp,
    int? dailyCoins,
    String? dayKey,
    int? level,
    String? stage,
    String? highestStage,
    String? condition,
    double? health,
    bool? dormant,
    int? rebirthCount,
    int? treeBirthAtMs,
    int? lastActionAtMs,
    bool clearLastActionAt = false,
    int? completedCount,
    int? returnCount,
  }) {
    return ZhixingGameState(
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      water: water ?? this.water,
      sunlight: sunlight ?? this.sunlight,
      fertilizer: fertilizer ?? this.fertilizer,
      dailyXp: dailyXp ?? this.dailyXp,
      dailyCoins: dailyCoins ?? this.dailyCoins,
      dayKey: dayKey ?? this.dayKey,
      level: level ?? this.level,
      stage: stage ?? this.stage,
      highestStage: highestStage ?? this.highestStage,
      condition: condition ?? this.condition,
      health: health ?? this.health,
      dormant: dormant ?? this.dormant,
      rebirthCount: rebirthCount ?? this.rebirthCount,
      treeBirthAtMs: treeBirthAtMs ?? this.treeBirthAtMs,
      lastActionAtMs: clearLastActionAt ? null : (lastActionAtMs ?? this.lastActionAtMs),
      completedCount: completedCount ?? this.completedCount,
      returnCount: returnCount ?? this.returnCount,
    );
  }
}

class ZhixingRewardResult {
  final ZhixingGameState game;
  final int grantedXp;
  final int grantedCoins;
  final bool returnBonus;
  final bool alreadySettled;

  const ZhixingRewardResult({
    required this.game,
    required this.grantedXp,
    required this.grantedCoins,
    required this.returnBonus,
    this.alreadySettled = false,
  });
}

class ZhixingDashboard {
  final ZhixingGameState game;
  final ZhixingActionProfile profile;
  final ZhixingPrescription? active;
  final List<ZhixingPrescription> recentActions;
  final List<ZhixingEvidence> recentEvidence;

  const ZhixingDashboard({
    required this.game,
    required this.profile,
    required this.active,
    required this.recentActions,
    required this.recentEvidence,
  });
}

class ZhixingThoughtModule {
  final String name;
  final String coreValue;
  final String mechanism;
  final String suitableFor;
  final String actionRule;
  final String boundary;
  final String source;
  final String evidenceLevel;

  const ZhixingThoughtModule({
    required this.name,
    required this.coreValue,
    required this.mechanism,
    required this.suitableFor,
    required this.actionRule,
    required this.boundary,
    required this.source,
    required this.evidenceLevel,
  });
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

String _string(Object? value, [String fallback = '']) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

int _integer(Object? value, int fallback) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _nullableInteger(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _number(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double _unit(Object? value, {double fallback = .5}) {
  return _number(value, fallback).clamp(0, 1).toDouble();
}

bool _boolean(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

List<String> _strings(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return const <String>[];
  return text.split(RegExp(r'[,，、;；]')).map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
}
