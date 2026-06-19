import 'dart:convert';

Map<String, dynamic> _sourcebookFromRaw(dynamic raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return const <String, dynamic>{};
  String cleaned = text;
  if (cleaned.startsWith('```')) {
    cleaned = cleaned
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```\s*$', multiLine: true), '')
        .trim();
  }
  try {
    final decoded = jsonDecode(cleaned);
    if (decoded is Map) {
      final sourcebook = decoded['sourcebookAnalysis'] ??
          decoded['sourcebook_analysis'] ??
          decoded['sourcebook'] ??
          decoded['sourcebookCase'];
      if (sourcebook is Map) return Map<String, dynamic>.from(sourcebook);
    }
  } catch (_) {
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(cleaned.substring(start, end + 1));
        if (decoded is Map) {
          final sourcebook = decoded['sourcebookAnalysis'] ??
              decoded['sourcebook_analysis'] ??
              decoded['sourcebook'] ??
              decoded['sourcebookCase'];
          if (sourcebook is Map) return Map<String, dynamic>.from(sourcebook);
        }
      } catch (_) {}
    }
  }
  return const <String, dynamic>{};
}


class CcActionVariant {
  final String actionType;
  final String label;
  final String title;
  final List<String> steps;
  final String completionCriteria;
  final String linkedValue;
  final String rawText;

  const CcActionVariant({
    this.actionType = '',
    this.label = '',
    this.title = '',
    this.steps = const <String>[],
    this.completionCriteria = '',
    this.linkedValue = '',
    this.rawText = '',
  });

  bool get hasContent =>
      title.trim().isNotEmpty ||
      steps.any((e) => e.trim().isNotEmpty) ||
      completionCriteria.trim().isNotEmpty ||
      linkedValue.trim().isNotEmpty ||
      rawText.trim().isNotEmpty;

  String get displayTitle => title.trim().isNotEmpty ? title.trim() : (label.trim().isNotEmpty ? label.trim() : rawText.trim());

  String get displayText {
    final parts = <String>[];
    final t = displayTitle;
    if (t.isNotEmpty) parts.add('行动名称：$t');
    final cleanSteps = steps.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleanSteps.isNotEmpty) parts.add('步骤：${cleanSteps.join('；')}');
    if (completionCriteria.trim().isNotEmpty) parts.add('完成标准：${completionCriteria.trim()}');
    if (linkedValue.trim().isNotEmpty) parts.add('对应价值：${linkedValue.trim()}');
    if (parts.isEmpty && rawText.trim().isNotEmpty) parts.add(rawText.trim());
    return parts.join('\n');
  }

  String get todoTitle {
    final t = displayTitle;
    if (t.isNotEmpty) return t;
    final text = rawText.trim();
    return text.length > 36 ? '${text.substring(0, 36)}…' : text;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'actionType': actionType,
        'label': label,
        'title': title,
        'steps': steps,
        'completionCriteria': completionCriteria,
        'linkedValue': linkedValue,
        'rawText': rawText,
      };

  static CcActionVariant fromJson(dynamic json, {String actionType = '', String label = '', String fallbackText = ''}) {
    if (json is Map) {
      final rawSteps = json['steps'];
      final parsedSteps = rawSteps is List
          ? rawSteps.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
      return CcActionVariant(
        actionType: (json['actionType'] ?? actionType).toString(),
        label: (json['label'] ?? label).toString(),
        title: (json['title'] ?? json['name'] ?? '').toString(),
        steps: parsedSteps,
        completionCriteria: (json['completionCriteria'] ?? json['criteria'] ?? '').toString(),
        linkedValue: (json['linkedValue'] ?? json['value'] ?? '').toString(),
        rawText: (json['rawText'] ?? '').toString(),
      );
    }
    final text = (json ?? fallbackText).toString();
    return CcActionVariant(actionType: actionType, label: label, title: '', rawText: text);
  }
}

class CcInformationAvoidanceBranches {
  final String avoidedInformation;
  final String fearedResult;
  final String smallestContactAction;
  final String betterThanExpected;
  final String worseThanExpected;
  final String ambiguous;
  final String nextInformationAction;

  const CcInformationAvoidanceBranches({
    this.avoidedInformation = '',
    this.fearedResult = '',
    this.smallestContactAction = '',
    this.betterThanExpected = '',
    this.worseThanExpected = '',
    this.ambiguous = '',
    this.nextInformationAction = '',
  });

  bool get hasContent =>
      avoidedInformation.trim().isNotEmpty ||
      fearedResult.trim().isNotEmpty ||
      smallestContactAction.trim().isNotEmpty ||
      betterThanExpected.trim().isNotEmpty ||
      worseThanExpected.trim().isNotEmpty ||
      ambiguous.trim().isNotEmpty ||
      nextInformationAction.trim().isNotEmpty;

  String get displayText {
    final parts = <String>[];
    if (avoidedInformation.trim().isNotEmpty) parts.add('正在回避的信息：${avoidedInformation.trim()}');
    if (fearedResult.trim().isNotEmpty) parts.add('害怕看到的结果：${fearedResult.trim()}');
    if (smallestContactAction.trim().isNotEmpty) parts.add('最小接触行动：${smallestContactAction.trim()}');
    if (betterThanExpected.trim().isNotEmpty) parts.add('结果比想象好：${betterThanExpected.trim()}');
    if (worseThanExpected.trim().isNotEmpty) parts.add('结果确实不好：${worseThanExpected.trim()}');
    if (ambiguous.trim().isNotEmpty) parts.add('结果仍然模糊：${ambiguous.trim()}');
    if (nextInformationAction.trim().isNotEmpty) parts.add('下一步信息行动：${nextInformationAction.trim()}');
    return parts.join('\n');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'avoidedInformation': avoidedInformation,
        'fearedResult': fearedResult,
        'smallestContactAction': smallestContactAction,
        'betterThanExpected': betterThanExpected,
        'worseThanExpected': worseThanExpected,
        'ambiguous': ambiguous,
        'nextInformationAction': nextInformationAction,
      };

  static CcInformationAvoidanceBranches fromJson(dynamic json, {String fallbackText = ''}) {
    if (json is Map) {
      final nested = json['branches'];
      final branches = nested is Map ? nested : const <String, dynamic>{};
      return CcInformationAvoidanceBranches(
        avoidedInformation: (json['avoidedInformation'] ?? '').toString(),
        fearedResult: (json['fearedResult'] ?? '').toString(),
        smallestContactAction: (json['smallestContactAction'] ?? json['smallestAction'] ?? '').toString(),
        betterThanExpected: (json['betterThanExpected'] ?? branches['betterThanExpected'] ?? '').toString(),
        worseThanExpected: (json['worseThanExpected'] ?? branches['worseThanExpected'] ?? '').toString(),
        ambiguous: (json['ambiguous'] ?? branches['ambiguous'] ?? '').toString(),
        nextInformationAction: (json['nextInformationAction'] ?? '').toString(),
      );
    }
    final text = (json ?? fallbackText).toString();
    return CcInformationAvoidanceBranches(smallestContactAction: text);
  }
}

class CcIdentityDialogue {
  final String oldIdentity;
  final String oldIdentityVoice;
  final String oldIdentityProtection;
  final String newIdentity;
  final String newIdentityVoice;
  final String fearOfLoss;
  final String newIdentityAction;
  final String postActionIdentitySentence;

  const CcIdentityDialogue({
    this.oldIdentity = '',
    this.oldIdentityVoice = '',
    this.oldIdentityProtection = '',
    this.newIdentity = '',
    this.newIdentityVoice = '',
    this.fearOfLoss = '',
    this.newIdentityAction = '',
    this.postActionIdentitySentence = '',
  });

  bool get hasContent =>
      oldIdentity.trim().isNotEmpty ||
      oldIdentityVoice.trim().isNotEmpty ||
      oldIdentityProtection.trim().isNotEmpty ||
      newIdentity.trim().isNotEmpty ||
      newIdentityVoice.trim().isNotEmpty ||
      fearOfLoss.trim().isNotEmpty ||
      newIdentityAction.trim().isNotEmpty ||
      postActionIdentitySentence.trim().isNotEmpty;

  String get displayText {
    final parts = <String>[];
    if (oldIdentity.trim().isNotEmpty) parts.add('旧身份：${oldIdentity.trim()}');
    if (oldIdentityVoice.trim().isNotEmpty) parts.add('旧身份声音：${oldIdentityVoice.trim()}');
    if (oldIdentityProtection.trim().isNotEmpty) parts.add('旧身份保护：${oldIdentityProtection.trim()}');
    if (newIdentity.trim().isNotEmpty) parts.add('新身份：${newIdentity.trim()}');
    if (newIdentityVoice.trim().isNotEmpty) parts.add('新身份声音：${newIdentityVoice.trim()}');
    if (fearOfLoss.trim().isNotEmpty) parts.add('害怕失去：${fearOfLoss.trim()}');
    if (newIdentityAction.trim().isNotEmpty) parts.add('新身份行动：${newIdentityAction.trim()}');
    if (postActionIdentitySentence.trim().isNotEmpty) parts.add('行动后解释：${postActionIdentitySentence.trim()}');
    return parts.join('\n');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'oldIdentity': oldIdentity,
        'oldIdentityVoice': oldIdentityVoice,
        'oldIdentityProtection': oldIdentityProtection,
        'newIdentity': newIdentity,
        'newIdentityVoice': newIdentityVoice,
        'fearOfLoss': fearOfLoss,
        'newIdentityAction': newIdentityAction,
        'postActionIdentitySentence': postActionIdentitySentence,
      };

  static CcIdentityDialogue fromJson(dynamic json, {String fallbackText = ''}) {
    if (json is Map) {
      return CcIdentityDialogue(
        oldIdentity: (json['oldIdentity'] ?? '').toString(),
        oldIdentityVoice: (json['oldIdentityVoice'] ?? '').toString(),
        oldIdentityProtection: (json['oldIdentityProtection'] ?? '').toString(),
        newIdentity: (json['newIdentity'] ?? '').toString(),
        newIdentityVoice: (json['newIdentityVoice'] ?? '').toString(),
        fearOfLoss: (json['fearOfLoss'] ?? '').toString(),
        newIdentityAction: (json['newIdentityAction'] ?? '').toString(),
        postActionIdentitySentence: (json['postActionIdentitySentence'] ?? '').toString(),
      );
    }
    final text = (json ?? fallbackText).toString();
    return CcIdentityDialogue(newIdentityVoice: text);
  }
}

class CcPlanResult {
  final String sessionId;
  final String coreConflict;
  final String changeEntry;
  final String oneDollarAction;
  final String preCommitment;
  final String inActionReminder;
  final String postActionExplanation;
  final String nextStep;
  final String riskReminder;
  final String valueLink;
  final String oldStory;
  final String evidenceLabel;
  final String believedValue;
  final String actualBehavior;
  final String selfExplanation;
  final String dissonancePoint;
  final String protectiveExplanation;
  final String avoidanceExplanation;
  final String repairAction;
  final String rewardRisk;
  final String identityDirection;
  final String evidenceCategory;

  // V14 modern cognitive dissonance expansion: New Look responsibility/consequence,
  // self-standards, rationalization map, and True Self bridge. Kept as flat strings
  // for backward-compatible SQLite result_json storage and resilient AI parsing.
  final String eventSummary;
  final String freedomOfChoice;
  final String negativeConsequence;
  final String foreseeability;
  final String responsibilityFeeling;
  final String repairability;
  final String notUserResponsibility;
  final String userResponsibility;
  final String overBlameRisk;
  final String avoidanceRisk;
  final String repairablePart;
  final String personalStandard;
  final String normativeStandard;
  final String familyOrGroupStandard;
  final String idealSelfStandard;
  final String adjustedStandard;
  final String rationalizationTypes;
  final String protectiveFunction;
  final String longTermCost;
  final String honestReframe;
  final String shameSignal;
  final String toxicShameLanguage;
  final String healthyShameReframe;
  final String recommendedShameScene;
  final String truePrideSentence;
  final bool shouldSyncTrueSelf;
  final String trueSelfBridgeReason;

  // V16专项场景结构化摘要：让不同场景不再挤压进通用卡片。
  final String choicePaths;
  final String sunkCostCheck;
  final String hypocrisyInduction;
  final String groupConflict;
  final String vicariousDissonance;
  final String todoWriteBackInsight;
  final String dissonanceReductionMode;
  final String verificationQuestion;
  final String verificationSuccessSignal;
  final int verificationDueDays;

  // V18 third value system: self-integrity, growth consistency, information contact,
  // simultaneous accessibility and dissonance-temperature tracking. Stored flat for
  // backward-compatible result_json parsing and simple UI rendering.
  final String dissonanceTypes;
  final int dissonanceIntensityScore;
  final String dissonanceIntensityLevel;
  final String dissonanceIntensityMainSources;
  final String dissonanceTemperature;
  final String simultaneousAccessibility;
  final String defensiveExplanation;
  final String shortTermProtection;
  final String growthExplanation;
  final String selfIntegrityCard;
  final String minimumAction;
  final String correctiveAction;
  final String evidenceAction;
  final CcActionVariant minimumActionVariant;
  final CcActionVariant correctiveActionVariant;
  final CcActionVariant evidenceActionVariant;
  final String informationAvoidance;
  final String identityConflict;
  final CcInformationAvoidanceBranches informationAvoidanceBranches;
  final CcIdentityDialogue identityDialogue;
  final String dailyReviewSeed;
  final CcSourcebookAnalysis sourcebookAnalysis;

  final String provider;
  final String modelLabel;
  final String rawResponse;
  final bool usedFallback;

  const CcPlanResult({
    this.sessionId = '',
    required this.coreConflict,
    required this.changeEntry,
    required this.oneDollarAction,
    required this.preCommitment,
    required this.inActionReminder,
    required this.postActionExplanation,
    required this.nextStep,
    required this.riskReminder,
    required this.valueLink,
    required this.oldStory,
    required this.evidenceLabel,
    this.believedValue = '',
    this.actualBehavior = '',
    this.selfExplanation = '',
    this.dissonancePoint = '',
    this.protectiveExplanation = '',
    this.avoidanceExplanation = '',
    this.repairAction = '',
    this.rewardRisk = '',
    this.identityDirection = '',
    this.evidenceCategory = 'start',
    this.eventSummary = '',
    this.freedomOfChoice = '',
    this.negativeConsequence = '',
    this.foreseeability = '',
    this.responsibilityFeeling = '',
    this.repairability = '',
    this.notUserResponsibility = '',
    this.userResponsibility = '',
    this.overBlameRisk = '',
    this.avoidanceRisk = '',
    this.repairablePart = '',
    this.personalStandard = '',
    this.normativeStandard = '',
    this.familyOrGroupStandard = '',
    this.idealSelfStandard = '',
    this.adjustedStandard = '',
    this.rationalizationTypes = '',
    this.protectiveFunction = '',
    this.longTermCost = '',
    this.honestReframe = '',
    this.shameSignal = '',
    this.toxicShameLanguage = '',
    this.healthyShameReframe = '',
    this.recommendedShameScene = '',
    this.truePrideSentence = '',
    this.shouldSyncTrueSelf = false,
    this.trueSelfBridgeReason = '',
    this.choicePaths = '',
    this.sunkCostCheck = '',
    this.hypocrisyInduction = '',
    this.groupConflict = '',
    this.vicariousDissonance = '',
    this.todoWriteBackInsight = '',
    this.dissonanceReductionMode = 'explanation_only',
    this.verificationQuestion = '',
    this.verificationSuccessSignal = '',
    this.verificationDueDays = 3,
    this.dissonanceTypes = '',
    this.dissonanceIntensityScore = 0,
    this.dissonanceIntensityLevel = '',
    this.dissonanceIntensityMainSources = '',
    this.dissonanceTemperature = '',
    this.simultaneousAccessibility = '',
    this.defensiveExplanation = '',
    this.shortTermProtection = '',
    this.growthExplanation = '',
    this.selfIntegrityCard = '',
    this.minimumAction = '',
    this.correctiveAction = '',
    this.evidenceAction = '',
    this.minimumActionVariant = const CcActionVariant(actionType: 'minimum', label: '最小行动'),
    this.correctiveActionVariant = const CcActionVariant(actionType: 'corrective', label: '修正行动'),
    this.evidenceActionVariant = const CcActionVariant(actionType: 'evidence', label: '证据行动'),
    this.informationAvoidance = '',
    this.identityConflict = '',
    this.informationAvoidanceBranches = const CcInformationAvoidanceBranches(),
    this.identityDialogue = const CcIdentityDialogue(),
    this.dailyReviewSeed = '',
    this.sourcebookAnalysis = const CcSourcebookAnalysis(),
    required this.provider,
    required this.modelLabel,
    required this.rawResponse,
    required this.usedFallback,
  });

  CcPlanResult copyWith({
    String? sessionId,
    String? coreConflict,
    String? changeEntry,
    String? oneDollarAction,
    String? preCommitment,
    String? inActionReminder,
    String? postActionExplanation,
    String? nextStep,
    String? riskReminder,
    String? valueLink,
    String? oldStory,
    String? evidenceLabel,
    String? believedValue,
    String? actualBehavior,
    String? selfExplanation,
    String? dissonancePoint,
    String? protectiveExplanation,
    String? avoidanceExplanation,
    String? repairAction,
    String? rewardRisk,
    String? identityDirection,
    String? evidenceCategory,
    String? eventSummary,
    String? freedomOfChoice,
    String? negativeConsequence,
    String? foreseeability,
    String? responsibilityFeeling,
    String? repairability,
    String? notUserResponsibility,
    String? userResponsibility,
    String? overBlameRisk,
    String? avoidanceRisk,
    String? repairablePart,
    String? personalStandard,
    String? normativeStandard,
    String? familyOrGroupStandard,
    String? idealSelfStandard,
    String? adjustedStandard,
    String? rationalizationTypes,
    String? protectiveFunction,
    String? longTermCost,
    String? honestReframe,
    String? shameSignal,
    String? toxicShameLanguage,
    String? healthyShameReframe,
    String? recommendedShameScene,
    String? truePrideSentence,
    bool? shouldSyncTrueSelf,
    String? trueSelfBridgeReason,
    String? choicePaths,
    String? sunkCostCheck,
    String? hypocrisyInduction,
    String? groupConflict,
    String? vicariousDissonance,
    String? todoWriteBackInsight,
    String? dissonanceReductionMode,
    String? verificationQuestion,
    String? verificationSuccessSignal,
    int? verificationDueDays,
    String? dissonanceTypes,
    int? dissonanceIntensityScore,
    String? dissonanceIntensityLevel,
    String? dissonanceIntensityMainSources,
    String? dissonanceTemperature,
    String? simultaneousAccessibility,
    String? defensiveExplanation,
    String? shortTermProtection,
    String? growthExplanation,
    String? selfIntegrityCard,
    String? minimumAction,
    String? correctiveAction,
    String? evidenceAction,
    CcActionVariant? minimumActionVariant,
    CcActionVariant? correctiveActionVariant,
    CcActionVariant? evidenceActionVariant,
    String? informationAvoidance,
    String? identityConflict,
    CcInformationAvoidanceBranches? informationAvoidanceBranches,
    CcIdentityDialogue? identityDialogue,
    String? dailyReviewSeed,
    CcSourcebookAnalysis? sourcebookAnalysis,
    String? provider,
    String? modelLabel,
    String? rawResponse,
    bool? usedFallback,
  }) {
    return CcPlanResult(
      sessionId: sessionId ?? this.sessionId,
      coreConflict: coreConflict ?? this.coreConflict,
      changeEntry: changeEntry ?? this.changeEntry,
      oneDollarAction: oneDollarAction ?? this.oneDollarAction,
      preCommitment: preCommitment ?? this.preCommitment,
      inActionReminder: inActionReminder ?? this.inActionReminder,
      postActionExplanation: postActionExplanation ?? this.postActionExplanation,
      nextStep: nextStep ?? this.nextStep,
      riskReminder: riskReminder ?? this.riskReminder,
      valueLink: valueLink ?? this.valueLink,
      oldStory: oldStory ?? this.oldStory,
      evidenceLabel: evidenceLabel ?? this.evidenceLabel,
      believedValue: believedValue ?? this.believedValue,
      actualBehavior: actualBehavior ?? this.actualBehavior,
      selfExplanation: selfExplanation ?? this.selfExplanation,
      dissonancePoint: dissonancePoint ?? this.dissonancePoint,
      protectiveExplanation: protectiveExplanation ?? this.protectiveExplanation,
      avoidanceExplanation: avoidanceExplanation ?? this.avoidanceExplanation,
      repairAction: repairAction ?? this.repairAction,
      rewardRisk: rewardRisk ?? this.rewardRisk,
      identityDirection: identityDirection ?? this.identityDirection,
      evidenceCategory: evidenceCategory ?? this.evidenceCategory,
      eventSummary: eventSummary ?? this.eventSummary,
      freedomOfChoice: freedomOfChoice ?? this.freedomOfChoice,
      negativeConsequence: negativeConsequence ?? this.negativeConsequence,
      foreseeability: foreseeability ?? this.foreseeability,
      responsibilityFeeling: responsibilityFeeling ?? this.responsibilityFeeling,
      repairability: repairability ?? this.repairability,
      notUserResponsibility: notUserResponsibility ?? this.notUserResponsibility,
      userResponsibility: userResponsibility ?? this.userResponsibility,
      overBlameRisk: overBlameRisk ?? this.overBlameRisk,
      avoidanceRisk: avoidanceRisk ?? this.avoidanceRisk,
      repairablePart: repairablePart ?? this.repairablePart,
      personalStandard: personalStandard ?? this.personalStandard,
      normativeStandard: normativeStandard ?? this.normativeStandard,
      familyOrGroupStandard: familyOrGroupStandard ?? this.familyOrGroupStandard,
      idealSelfStandard: idealSelfStandard ?? this.idealSelfStandard,
      adjustedStandard: adjustedStandard ?? this.adjustedStandard,
      rationalizationTypes: rationalizationTypes ?? this.rationalizationTypes,
      protectiveFunction: protectiveFunction ?? this.protectiveFunction,
      longTermCost: longTermCost ?? this.longTermCost,
      honestReframe: honestReframe ?? this.honestReframe,
      shameSignal: shameSignal ?? this.shameSignal,
      toxicShameLanguage: toxicShameLanguage ?? this.toxicShameLanguage,
      healthyShameReframe: healthyShameReframe ?? this.healthyShameReframe,
      recommendedShameScene: recommendedShameScene ?? this.recommendedShameScene,
      truePrideSentence: truePrideSentence ?? this.truePrideSentence,
      shouldSyncTrueSelf: shouldSyncTrueSelf ?? this.shouldSyncTrueSelf,
      trueSelfBridgeReason: trueSelfBridgeReason ?? this.trueSelfBridgeReason,
      choicePaths: choicePaths ?? this.choicePaths,
      sunkCostCheck: sunkCostCheck ?? this.sunkCostCheck,
      hypocrisyInduction: hypocrisyInduction ?? this.hypocrisyInduction,
      groupConflict: groupConflict ?? this.groupConflict,
      vicariousDissonance: vicariousDissonance ?? this.vicariousDissonance,
      todoWriteBackInsight: todoWriteBackInsight ?? this.todoWriteBackInsight,
      dissonanceReductionMode: dissonanceReductionMode ?? this.dissonanceReductionMode,
      verificationQuestion: verificationQuestion ?? this.verificationQuestion,
      verificationSuccessSignal: verificationSuccessSignal ?? this.verificationSuccessSignal,
      verificationDueDays: verificationDueDays ?? this.verificationDueDays,
      dissonanceTypes: dissonanceTypes ?? this.dissonanceTypes,
      dissonanceIntensityScore: dissonanceIntensityScore ?? this.dissonanceIntensityScore,
      dissonanceIntensityLevel: dissonanceIntensityLevel ?? this.dissonanceIntensityLevel,
      dissonanceIntensityMainSources: dissonanceIntensityMainSources ?? this.dissonanceIntensityMainSources,
      dissonanceTemperature: dissonanceTemperature ?? this.dissonanceTemperature,
      simultaneousAccessibility: simultaneousAccessibility ?? this.simultaneousAccessibility,
      defensiveExplanation: defensiveExplanation ?? this.defensiveExplanation,
      shortTermProtection: shortTermProtection ?? this.shortTermProtection,
      growthExplanation: growthExplanation ?? this.growthExplanation,
      selfIntegrityCard: selfIntegrityCard ?? this.selfIntegrityCard,
      minimumAction: minimumAction ?? this.minimumAction,
      correctiveAction: correctiveAction ?? this.correctiveAction,
      evidenceAction: evidenceAction ?? this.evidenceAction,
      minimumActionVariant: minimumActionVariant ?? this.minimumActionVariant,
      correctiveActionVariant: correctiveActionVariant ?? this.correctiveActionVariant,
      evidenceActionVariant: evidenceActionVariant ?? this.evidenceActionVariant,
      informationAvoidance: informationAvoidance ?? this.informationAvoidance,
      identityConflict: identityConflict ?? this.identityConflict,
      informationAvoidanceBranches: informationAvoidanceBranches ?? this.informationAvoidanceBranches,
      identityDialogue: identityDialogue ?? this.identityDialogue,
      dailyReviewSeed: dailyReviewSeed ?? this.dailyReviewSeed,
      sourcebookAnalysis: sourcebookAnalysis ?? this.sourcebookAnalysis,
      provider: provider ?? this.provider,
      modelLabel: modelLabel ?? this.modelLabel,
      rawResponse: rawResponse ?? this.rawResponse,
      usedFallback: usedFallback ?? this.usedFallback,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sessionId': sessionId,
        'coreConflict': coreConflict,
        'changeEntry': changeEntry,
        'oneDollarAction': oneDollarAction,
        'preCommitment': preCommitment,
        'inActionReminder': inActionReminder,
        'postActionExplanation': postActionExplanation,
        'nextStep': nextStep,
        'riskReminder': riskReminder,
        'valueLink': valueLink,
        'oldStory': oldStory,
        'evidenceLabel': evidenceLabel,
        'believedValue': believedValue,
        'actualBehavior': actualBehavior,
        'selfExplanation': selfExplanation,
        'dissonancePoint': dissonancePoint,
        'protectiveExplanation': protectiveExplanation,
        'avoidanceExplanation': avoidanceExplanation,
        'repairAction': repairAction,
        'rewardRisk': rewardRisk,
        'identityDirection': identityDirection,
        'evidenceCategory': evidenceCategory,
        'eventSummary': eventSummary,
        'freedomOfChoice': freedomOfChoice,
        'negativeConsequence': negativeConsequence,
        'foreseeability': foreseeability,
        'responsibilityFeeling': responsibilityFeeling,
        'repairability': repairability,
        'notUserResponsibility': notUserResponsibility,
        'userResponsibility': userResponsibility,
        'overBlameRisk': overBlameRisk,
        'avoidanceRisk': avoidanceRisk,
        'repairablePart': repairablePart,
        'personalStandard': personalStandard,
        'normativeStandard': normativeStandard,
        'familyOrGroupStandard': familyOrGroupStandard,
        'idealSelfStandard': idealSelfStandard,
        'adjustedStandard': adjustedStandard,
        'rationalizationTypes': rationalizationTypes,
        'protectiveFunction': protectiveFunction,
        'longTermCost': longTermCost,
        'honestReframe': honestReframe,
        'shameSignal': shameSignal,
        'toxicShameLanguage': toxicShameLanguage,
        'healthyShameReframe': healthyShameReframe,
        'recommendedShameScene': recommendedShameScene,
        'truePrideSentence': truePrideSentence,
        'shouldSyncTrueSelf': shouldSyncTrueSelf,
        'trueSelfBridgeReason': trueSelfBridgeReason,
        'choicePaths': choicePaths,
        'sunkCostCheck': sunkCostCheck,
        'hypocrisyInduction': hypocrisyInduction,
        'groupConflict': groupConflict,
        'vicariousDissonance': vicariousDissonance,
        'todoWriteBackInsight': todoWriteBackInsight,
        'dissonanceReductionMode': dissonanceReductionMode,
        'verificationQuestion': verificationQuestion,
        'verificationSuccessSignal': verificationSuccessSignal,
        'verificationDueDays': verificationDueDays,
        'dissonanceTypes': dissonanceTypes,
        'dissonanceIntensityScore': dissonanceIntensityScore,
        'dissonanceIntensityLevel': dissonanceIntensityLevel,
        'dissonanceIntensityMainSources': dissonanceIntensityMainSources,
        'dissonanceTemperature': dissonanceTemperature,
        'simultaneousAccessibility': simultaneousAccessibility,
        'defensiveExplanation': defensiveExplanation,
        'shortTermProtection': shortTermProtection,
        'growthExplanation': growthExplanation,
        'selfIntegrityCard': selfIntegrityCard,
        'minimumAction': minimumAction,
        'correctiveAction': correctiveAction,
        'evidenceAction': evidenceAction,
        'minimumActionVariant': minimumActionVariant.toJson(),
        'correctiveActionVariant': correctiveActionVariant.toJson(),
        'evidenceActionVariant': evidenceActionVariant.toJson(),
        'informationAvoidance': informationAvoidance,
        'identityConflict': identityConflict,
        'informationAvoidanceBranches': informationAvoidanceBranches.toJson(),
        'identityDialogue': identityDialogue.toJson(),
        'dailyReviewSeed': dailyReviewSeed,
        'sourcebookAnalysis': sourcebookAnalysis.toJson(),
        'provider': provider,
        'modelLabel': modelLabel,
        'rawResponse': rawResponse,
        'usedFallback': usedFallback,
      };

  static CcPlanResult fromJson(Map<String, dynamic> json) => CcPlanResult(
        sessionId: (json['sessionId'] ?? json['session_id'] ?? '').toString(),
        coreConflict: (json['coreConflict'] ?? '').toString(),
        changeEntry: (json['changeEntry'] ?? '').toString(),
        oneDollarAction: (json['oneDollarAction'] ?? '').toString(),
        preCommitment: (json['preCommitment'] ?? '').toString(),
        inActionReminder: (json['inActionReminder'] ?? '').toString(),
        postActionExplanation: (json['postActionExplanation'] ?? '').toString(),
        nextStep: (json['nextStep'] ?? '').toString(),
        riskReminder: (json['riskReminder'] ?? '').toString(),
        valueLink: (json['valueLink'] ?? '').toString(),
        oldStory: (json['oldStory'] ?? '').toString(),
        evidenceLabel: (json['evidenceLabel'] ?? '').toString(),
        believedValue: (json['believedValue'] ?? '').toString(),
        actualBehavior: (json['actualBehavior'] ?? '').toString(),
        selfExplanation: (json['selfExplanation'] ?? '').toString(),
        dissonancePoint: (json['dissonancePoint'] ?? '').toString(),
        protectiveExplanation: (json['protectiveExplanation'] ?? '').toString(),
        avoidanceExplanation: (json['avoidanceExplanation'] ?? '').toString(),
        repairAction: (json['repairAction'] ?? '').toString(),
        rewardRisk: (json['rewardRisk'] ?? '').toString(),
        identityDirection: (json['identityDirection'] ?? '').toString(),
        evidenceCategory: (json['evidenceCategory'] ?? 'start').toString(),
        eventSummary: (json['eventSummary'] ?? '').toString(),
        freedomOfChoice: (json['freedomOfChoice'] ?? '').toString(),
        negativeConsequence: (json['negativeConsequence'] ?? '').toString(),
        foreseeability: (json['foreseeability'] ?? '').toString(),
        responsibilityFeeling: (json['responsibilityFeeling'] ?? '').toString(),
        repairability: (json['repairability'] ?? '').toString(),
        notUserResponsibility: (json['notUserResponsibility'] ?? '').toString(),
        userResponsibility: (json['userResponsibility'] ?? '').toString(),
        overBlameRisk: (json['overBlameRisk'] ?? '').toString(),
        avoidanceRisk: (json['avoidanceRisk'] ?? '').toString(),
        repairablePart: (json['repairablePart'] ?? '').toString(),
        personalStandard: (json['personalStandard'] ?? '').toString(),
        normativeStandard: (json['normativeStandard'] ?? '').toString(),
        familyOrGroupStandard: (json['familyOrGroupStandard'] ?? '').toString(),
        idealSelfStandard: (json['idealSelfStandard'] ?? '').toString(),
        adjustedStandard: (json['adjustedStandard'] ?? '').toString(),
        rationalizationTypes: (json['rationalizationTypes'] ?? '').toString(),
        protectiveFunction: (json['protectiveFunction'] ?? '').toString(),
        longTermCost: (json['longTermCost'] ?? '').toString(),
        honestReframe: (json['honestReframe'] ?? '').toString(),
        shameSignal: (json['shameSignal'] ?? '').toString(),
        toxicShameLanguage: (json['toxicShameLanguage'] ?? '').toString(),
        healthyShameReframe: (json['healthyShameReframe'] ?? '').toString(),
        recommendedShameScene: (json['recommendedShameScene'] ?? '').toString(),
        truePrideSentence: (json['truePrideSentence'] ?? '').toString(),
        shouldSyncTrueSelf: json['shouldSyncTrueSelf'] == true || json['shouldSyncTrueSelf'] == 1 || json['shouldSyncTrueSelf'].toString().toLowerCase() == 'true',
        trueSelfBridgeReason: (json['trueSelfBridgeReason'] ?? '').toString(),
        choicePaths: (json['choicePaths'] ?? '').toString(),
        sunkCostCheck: (json['sunkCostCheck'] ?? '').toString(),
        hypocrisyInduction: (json['hypocrisyInduction'] ?? '').toString(),
        groupConflict: (json['groupConflict'] ?? '').toString(),
        vicariousDissonance: (json['vicariousDissonance'] ?? '').toString(),
        todoWriteBackInsight: (json['todoWriteBackInsight'] ?? '').toString(),
        dissonanceReductionMode: (json['dissonanceReductionMode'] ?? 'explanation_only').toString(),
        verificationQuestion: (json['verificationQuestion'] ?? '').toString(),
        verificationSuccessSignal: (json['verificationSuccessSignal'] ?? '').toString(),
        verificationDueDays: (json['verificationDueDays'] is num) ? (json['verificationDueDays'] as num).toInt() : int.tryParse((json['verificationDueDays'] ?? '3').toString()) ?? 3,
        dissonanceTypes: (json['dissonanceTypes'] ?? '').toString(),
        dissonanceIntensityScore: (json['dissonanceIntensityScore'] is num) ? (json['dissonanceIntensityScore'] as num).toInt() : int.tryParse((json['dissonanceIntensityScore'] ?? '0').toString()) ?? 0,
        dissonanceIntensityLevel: (json['dissonanceIntensityLevel'] ?? '').toString(),
        dissonanceIntensityMainSources: (json['dissonanceIntensityMainSources'] ?? '').toString(),
        dissonanceTemperature: (json['dissonanceTemperature'] ?? '').toString(),
        simultaneousAccessibility: (json['simultaneousAccessibility'] ?? '').toString(),
        defensiveExplanation: (json['defensiveExplanation'] ?? '').toString(),
        shortTermProtection: (json['shortTermProtection'] ?? '').toString(),
        growthExplanation: (json['growthExplanation'] ?? '').toString(),
        selfIntegrityCard: (json['selfIntegrityCard'] ?? '').toString(),
        minimumAction: (json['minimumAction'] ?? '').toString(),
        correctiveAction: (json['correctiveAction'] ?? '').toString(),
        evidenceAction: (json['evidenceAction'] ?? '').toString(),
        minimumActionVariant: CcActionVariant.fromJson(json['minimumActionVariant'] ?? json['minimumAction'], actionType: 'minimum', label: '最小行动', fallbackText: (json['minimumAction'] ?? '').toString()),
        correctiveActionVariant: CcActionVariant.fromJson(json['correctiveActionVariant'] ?? json['correctiveAction'], actionType: 'corrective', label: '修正行动', fallbackText: (json['correctiveAction'] ?? '').toString()),
        evidenceActionVariant: CcActionVariant.fromJson(json['evidenceActionVariant'] ?? json['evidenceAction'], actionType: 'evidence', label: '证据行动', fallbackText: (json['evidenceAction'] ?? '').toString()),
        informationAvoidance: (json['informationAvoidance'] ?? '').toString(),
        identityConflict: (json['identityConflict'] ?? '').toString(),
        informationAvoidanceBranches: CcInformationAvoidanceBranches.fromJson(json['informationAvoidanceBranches'] ?? json['informationAvoidance'], fallbackText: (json['informationAvoidance'] ?? '').toString()),
        identityDialogue: CcIdentityDialogue.fromJson(json['identityDialogue'] ?? json['identityConflict'], fallbackText: (json['identityConflict'] ?? '').toString()),
        dailyReviewSeed: (json['dailyReviewSeed'] ?? '').toString(),
        sourcebookAnalysis: CcSourcebookAnalysis.fromUnknown(json['sourcebookAnalysis'] ?? _sourcebookFromRaw(json['rawResponse'])),
        provider: (json['provider'] ?? '').toString(),
        modelLabel: (json['modelLabel'] ?? '').toString(),
        rawResponse: (json['rawResponse'] ?? '').toString(),
        usedFallback: json['usedFallback'] == true || json['usedFallback'] == 1,
      );
}

class CcSession {
  final String sessionId;
  final String sceneType;
  final String userGoal;
  final String userContext;
  final String userValues;
  final CcPlanResult result;
  final String status;
  final String sourceType;
  final String sourceId;
  final String rewardSource;
  final String originScene;
  final int createdAtMs;
  final int updatedAtMs;

  const CcSession({
    required this.sessionId,
    required this.sceneType,
    required this.userGoal,
    required this.userContext,
    required this.userValues,
    required this.result,
    required this.status,
    this.sourceType = '',
    this.sourceId = '',
    this.rewardSource = '',
    this.originScene = '',
    required this.createdAtMs,
    required this.updatedAtMs,
  });
}

class CcEvidenceRecord {
  final String evidenceId;
  final String sessionId;
  final String userGoal;
  final String plannedAction;
  final String completedAction;
  final String userReflection;
  final String evidenceLabel;
  final String valueLink;
  final String oldStory;
  final String newStory;
  final String evidenceCategory;
  final String identityDirection;
  final String rewardSource;
  final String sourceType;
  final String sourceId;
  final int effortMinutes;
  final int difficultyScore;
  final int startedAtMs;
  final int endedAtMs;
  final int createdAtMs;

  const CcEvidenceRecord({
    required this.evidenceId,
    required this.sessionId,
    required this.userGoal,
    required this.plannedAction,
    required this.completedAction,
    required this.userReflection,
    required this.evidenceLabel,
    required this.valueLink,
    required this.oldStory,
    required this.newStory,
    this.evidenceCategory = 'start',
    this.identityDirection = '',
    this.rewardSource = '',
    this.sourceType = '',
    this.sourceId = '',
    required this.effortMinutes,
    required this.difficultyScore,
    this.startedAtMs = 0,
    this.endedAtMs = 0,
    required this.createdAtMs,
  });
}

class CcValueProfile {
  final String valueId;
  final String valueLabel;
  final String why;
  final String identityDirection;
  final String exampleAction;
  final int priority;
  final int createdAtMs;
  final int updatedAtMs;

  const CcValueProfile({
    required this.valueId,
    required this.valueLabel,
    required this.why,
    required this.identityDirection,
    required this.exampleAction,
    required this.priority,
    required this.createdAtMs,
    required this.updatedAtMs,
  });
}


class CcEvidenceValueLink {
  final String evidenceId;
  final String valueId;
  final String valueLabel;
  final String relationType;
  final int createdAtMs;

  const CcEvidenceValueLink({
    required this.evidenceId,
    required this.valueId,
    required this.valueLabel,
    required this.relationType,
    required this.createdAtMs,
  });
}

class CcReportRecord {
  final String reportId;
  final String periodLabel;
  final String userValues;
  final String reportText;
  final String suggestedAction;
  final String adoptedEvidenceId;
  final int createdAtMs;

  const CcReportRecord({
    required this.reportId,
    required this.periodLabel,
    required this.userValues,
    required this.reportText,
    this.suggestedAction = '',
    this.adoptedEvidenceId = '',
    required this.createdAtMs,
  });
}



class CcReportActionLink {
  final String linkId;
  final String reportId;
  final String sessionId;
  final String todoStepId;
  final String evidenceId;
  final String status;
  final String suggestedAction;
  final int createdAtMs;
  final int updatedAtMs;

  const CcReportActionLink({
    required this.linkId,
    required this.reportId,
    this.sessionId = '',
    this.todoStepId = '',
    this.evidenceId = '',
    this.status = 'suggested',
    this.suggestedAction = '',
    required this.createdAtMs,
    required this.updatedAtMs,
  });
}

class CcValueRelationInsightRecord {
  final String insightId;
  final String selectedValueIds;
  final String selectedValueLabels;
  final String userGoal;
  final String userContext;
  final String insightText;
  final String linkedSessionId;
  final String linkedEvidenceId;
  final int createdAtMs;

  const CcValueRelationInsightRecord({
    required this.insightId,
    required this.selectedValueIds,
    required this.selectedValueLabels,
    this.userGoal = '',
    this.userContext = '',
    this.insightText = '',
    this.linkedSessionId = '',
    this.linkedEvidenceId = '',
    required this.createdAtMs,
  });
}

class CcSourceEvidenceSummary {
  final String sourceType;
  final String sourceId;
  final int count;
  final String latestAction;
  final int latestAtMs;
  final List<String> values;

  const CcSourceEvidenceSummary({
    required this.sourceType,
    required this.sourceId,
    required this.count,
    this.latestAction = '',
    this.latestAtMs = 0,
    this.values = const <String>[],
  });
}


class CcEffectivePatternRecord {
  final String patternId;
  final String evidenceId;
  final String valueLabels;
  final String oldStory;
  final String newStory;
  final String actionTemplate;
  final String successReason;
  final int createdAtMs;

  const CcEffectivePatternRecord({
    required this.patternId,
    required this.evidenceId,
    this.valueLabels = '',
    this.oldStory = '',
    this.newStory = '',
    this.actionTemplate = '',
    this.successReason = '',
    required this.createdAtMs,
  });
}

class CcActionTraceLink {
  final String linkId;
  final String fromType;
  final String fromId;
  final String toType;
  final String toId;
  final String relationType;
  final int createdAtMs;

  const CcActionTraceLink({
    required this.linkId,
    required this.fromType,
    required this.fromId,
    required this.toType,
    required this.toId,
    this.relationType = '',
    required this.createdAtMs,
  });
}

class CcTriggerSuggestion {
  final String suggestionId;
  final String sourceType;
  final String sourceId;
  final String triggerType;
  final String message;
  final String recommendedTab;
  final int severity;
  final int createdAtMs;

  const CcTriggerSuggestion({
    required this.suggestionId,
    required this.sourceType,
    required this.sourceId,
    required this.triggerType,
    this.message = '',
    this.recommendedTab = '',
    this.severity = 0,
    required this.createdAtMs,
  });
}


class CcVerificationTask {
  final String taskId;
  final String sessionId;
  final String sceneType;
  final String question;
  final String successSignal;
  final int dueAtMs;
  final String status;
  final String resultNote;
  final int createdAtMs;
  final int verifiedAtMs;

  const CcVerificationTask({
    required this.taskId,
    required this.sessionId,
    required this.sceneType,
    required this.question,
    this.successSignal = '',
    required this.dueAtMs,
    this.status = 'open',
    this.resultNote = '',
    required this.createdAtMs,
    this.verifiedAtMs = 0,
  });
}


class CcDissonanceTemperatureLog {
  final String logId;
  final String sessionId;
  final String evidenceId;
  final String phase;
  final int discomfortScore;
  final int guiltScore;
  final int anxietyScore;
  final int shameScore;
  final int defensivenessScore;
  final int avoidanceUrgeScore;
  final int clarityScore;
  final int responsibilityScore;
  final int actionWillingnessScore;
  final String note;
  final int createdAtMs;

  const CcDissonanceTemperatureLog({
    required this.logId,
    required this.sessionId,
    this.evidenceId = '',
    required this.phase,
    this.discomfortScore = 0,
    this.guiltScore = 0,
    this.anxietyScore = 0,
    this.shameScore = 0,
    this.defensivenessScore = 0,
    this.avoidanceUrgeScore = 0,
    this.clarityScore = 0,
    this.responsibilityScore = 0,
    this.actionWillingnessScore = 0,
    this.note = '',
    required this.createdAtMs,
  });
}

class CcValueConsistencySnapshot {
  final String valueId;
  final String valueLabel;
  final int beliefStrength;
  final int evidenceCount;
  final int dissonanceCount;
  final int repairCount;
  final int averageIntensity;
  final int averageDiscomfortDrop;
  final String latestDissonance;
  final String latestRepair;
  final String topRationalization;
  final String trend;

  const CcValueConsistencySnapshot({
    required this.valueId,
    required this.valueLabel,
    this.beliefStrength = 0,
    this.evidenceCount = 0,
    this.dissonanceCount = 0,
    this.repairCount = 0,
    this.averageIntensity = 0,
    this.averageDiscomfortDrop = 0,
    this.latestDissonance = '',
    this.latestRepair = '',
    this.topRationalization = '',
    this.trend = '证据不足',
  });
}



class CcTemperatureReviewItem {
  final String reviewId;
  final String sessionId;
  final String evidenceId;
  final String reviewText;
  final String repairMode;
  final String nextCoolingAction;
  final int createdAtMs;

  const CcTemperatureReviewItem({
    required this.reviewId,
    this.sessionId = '',
    this.evidenceId = '',
    this.reviewText = '',
    this.repairMode = '',
    this.nextCoolingAction = '',
    required this.createdAtMs,
  });
}

class CcInformationContactResult {
  final String resultId;
  final String sessionId;
  final String evidenceId;
  final String avoidedInformation;
  final String fearedResult;
  final String actualResult;
  final String resultType;
  final String catastrophizingCheck;
  final String repairAction;
  final String sourceType;
  final String sourceId;
  final String originScene;
  final int discomfortBefore;
  final int discomfortAfter;
  final int createdAtMs;

  const CcInformationContactResult({
    required this.resultId,
    this.sessionId = '',
    this.evidenceId = '',
    this.avoidedInformation = '',
    this.fearedResult = '',
    this.actualResult = '',
    this.resultType = '',
    this.catastrophizingCheck = '',
    this.repairAction = '',
    this.sourceType = '',
    this.sourceId = '',
    this.originScene = '',
    this.discomfortBefore = 0,
    this.discomfortAfter = 0,
    required this.createdAtMs,
  });
}

class CcIdentityTransitionRecord {
  final String transitionId;
  final String sessionId;
  final String evidenceId;
  final String oldIdentity;
  final String newIdentity;
  final String oldProtection;
  final String fearOfLoss;
  final String newIdentityAction;
  final String postActionIdentitySentence;
  final String nextIdentityAction;
  final String sourceType;
  final String sourceId;
  final String originScene;
  final int createdAtMs;

  const CcIdentityTransitionRecord({
    required this.transitionId,
    this.sessionId = '',
    this.evidenceId = '',
    this.oldIdentity = '',
    this.newIdentity = '',
    this.oldProtection = '',
    this.fearOfLoss = '',
    this.newIdentityAction = '',
    this.postActionIdentitySentence = '',
    this.nextIdentityAction = '',
    this.sourceType = '',
    this.sourceId = '',
    this.originScene = '',
    required this.createdAtMs,
  });
}

class CcPromptBackupRecord {
  final String key;
  final String promptId;
  final String versionLabel;
  final String value;

  const CcPromptBackupRecord({
    required this.key,
    this.promptId = '',
    this.versionLabel = '',
    this.value = '',
  });

  String get displayTime => versionLabel.isEmpty ? key : versionLabel;

  String get preview {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 48) return clean;
    return '${clean.substring(0, 48)}…';
  }
}

class CcDailyConsistencyReview {
  final String reviewId;
  final String dateLabel;
  final String closestValueAction;
  final String mainDissonance;
  final String rationalizationUsed;
  final String growthReframe;
  final String repairActionDone;
  final String tomorrowAction;
  final int createdAtMs;

  const CcDailyConsistencyReview({
    required this.reviewId,
    required this.dateLabel,
    this.closestValueAction = '',
    this.mainDissonance = '',
    this.rationalizationUsed = '',
    this.growthReframe = '',
    this.repairActionDone = '',
    this.tomorrowAction = '',
    required this.createdAtMs,
  });
}

class CcV18SessionDetails {
  final String sessionId;
  final List<String> dissonanceTypes;
  final int intensityScore;
  final String intensityLevel;
  final String intensitySources;
  final String defensiveExplanation;
  final String shortTermProtection;
  final String longTermCost;
  final String growthExplanation;
  final String responsiblePart;
  final String nextRepairAction;
  final String selfAcknowledge;
  final String selfNotEqual;
  final String selfStillValue;
  final String selfNextProof;

  const CcV18SessionDetails({
    required this.sessionId,
    this.dissonanceTypes = const <String>[],
    this.intensityScore = 0,
    this.intensityLevel = '',
    this.intensitySources = '',
    this.defensiveExplanation = '',
    this.shortTermProtection = '',
    this.longTermCost = '',
    this.growthExplanation = '',
    this.responsiblePart = '',
    this.nextRepairAction = '',
    this.selfAcknowledge = '',
    this.selfNotEqual = '',
    this.selfStillValue = '',
    this.selfNextProof = '',
  });
}

// V24 sourcebook/resolution typed wrapper models. The UI still accepts resilient Map payloads
// for backward compatibility, but these types document and stabilize the formal
// sourcebook practice-loop boundary.
class CcSourcebookAnalysis {
  final String currentStage;
  final Map<String, dynamic> cognitiveStructureMap;
  final Map<String, dynamic> conflictTypeRouting;
  final Map<String, dynamic> psychologicalFunction;
  final Map<String, dynamic> valueLayers;
  final Map<String, dynamic> alternativeInterpretations;
  final List<dynamic> protectedSelfImage;
  final List<dynamic> defensePatterns;
  final List<dynamic> realityTestingQuestions;
  final List<dynamic> userChoiceOptions;
  final List<dynamic> reflectionQuestions;
  final Map<String, dynamic> interpersonalBalance;
  final Map<String, dynamic> counterAttitudinalExperiment;
  final Map<String, dynamic> commitmentAction;
  final String integratedSelfStatement;

  const CcSourcebookAnalysis({
    this.currentStage = '',
    this.cognitiveStructureMap = const <String, dynamic>{},
    this.conflictTypeRouting = const <String, dynamic>{},
    this.psychologicalFunction = const <String, dynamic>{},
    this.valueLayers = const <String, dynamic>{},
    this.alternativeInterpretations = const <String, dynamic>{},
    this.protectedSelfImage = const <dynamic>[],
    this.defensePatterns = const <dynamic>[],
    this.realityTestingQuestions = const <dynamic>[],
    this.userChoiceOptions = const <dynamic>[],
    this.reflectionQuestions = const <dynamic>[],
    this.interpersonalBalance = const <String, dynamic>{},
    this.counterAttitudinalExperiment = const <String, dynamic>{},
    this.commitmentAction = const <String, dynamic>{},
    this.integratedSelfStatement = '',
  });

  static Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
  static List<dynamic> _list(dynamic value) => value is List ? List<dynamic>.from(value) : const <dynamic>[];
  static CcSourcebookAnalysis fromUnknown(dynamic value) {
    if (value is Map) return CcSourcebookAnalysis.fromMap(Map<String, dynamic>.from(value));
    if (value is String && value.trim().isNotEmpty) {
      return CcSourcebookAnalysis.fromMap(_sourcebookFromRaw(value));
    }
    return const CcSourcebookAnalysis();
  }

  factory CcSourcebookAnalysis.fromMap(Map<String, dynamic> map) => CcSourcebookAnalysis(
        currentStage: (map['currentStage'] ?? map['current_stage'] ?? '').toString(),
        cognitiveStructureMap: _map(map['cognitiveStructureMap'] ?? map['cognitive_structure_map']),
        conflictTypeRouting: _map(map['conflictTypeRouting'] ?? map['conflict_type_routing']),
        psychologicalFunction: _map(map['psychologicalFunction'] ?? map['psychological_function']),
        valueLayers: _map(map['valueLayers'] ?? map['value_layers']),
        alternativeInterpretations: _map(map['alternativeInterpretations'] ?? map['alternative_interpretations']),
        protectedSelfImage: _list(map['protectedSelfImage'] ?? map['protected_self_image']),
        defensePatterns: _list(map['defensePatterns'] ?? map['defense_patterns']),
        realityTestingQuestions: _list(map['realityTestingQuestions'] ?? map['reality_testing_questions']),
        userChoiceOptions: _list(map['userChoiceOptions'] ?? map['user_choice_options']),
        reflectionQuestions: _list(map['reflectionQuestions'] ?? map['reflection_questions']),
        interpersonalBalance: _map(map['interpersonalBalance'] ?? map['interpersonal_balance']),
        counterAttitudinalExperiment: _map(map['counterAttitudinalExperiment'] ?? map['counter_attitudinal_experiment']),
        commitmentAction: _map(map['commitmentAction'] ?? map['commitment_action']),
        integratedSelfStatement: (map['integratedSelfStatement'] ?? map['integrated_self_statement'] ?? '').toString(),
      );

  bool get isEmpty => toJson().entries.every((e) {
        final v = e.value;
        if (v is String) return v.trim().isEmpty;
        if (v is Map || v is List) return (v as dynamic).isEmpty == true;
        return v == null;
      });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'currentStage': currentStage,
        'protectedSelfImage': protectedSelfImage,
        'defensePatterns': defensePatterns,
        'cognitiveStructureMap': cognitiveStructureMap,
        'conflictTypeRouting': conflictTypeRouting,
        'psychologicalFunction': psychologicalFunction,
        'valueLayers': valueLayers,
        'alternativeInterpretations': alternativeInterpretations,
        'realityTestingQuestions': realityTestingQuestions,
        'userChoiceOptions': userChoiceOptions,
        'reflectionQuestions': reflectionQuestions,
        'interpersonalBalance': interpersonalBalance,
        'counterAttitudinalExperiment': counterAttitudinalExperiment,
        'commitmentAction': commitmentAction,
        'integratedSelfStatement': integratedSelfStatement,
      };
}

class CcSourcebookCaseDetail {
  final String sessionId;
  final Map<String, dynamic> caseMap;
  final List<dynamic> nodes;
  final List<dynamic> edges;
  final List<dynamic> evidence;

  const CcSourcebookCaseDetail({
    this.sessionId = '',
    this.caseMap = const <String, dynamic>{},
    this.nodes = const <dynamic>[],
    this.edges = const <dynamic>[],
    this.evidence = const <dynamic>[],
  });

  factory CcSourcebookCaseDetail.fromMap(String sessionId, Map<String, dynamic> map) => CcSourcebookCaseDetail(
        sessionId: sessionId,
        caseMap: map['case'] is Map ? Map<String, dynamic>.from(map['case'] as Map) : const <String, dynamic>{},
        nodes: map['nodes'] is List ? List<dynamic>.from(map['nodes'] as List) : const <dynamic>[],
        edges: map['edges'] is List ? List<dynamic>.from(map['edges'] as List) : const <dynamic>[],
        evidence: map['evidence'] is List ? List<dynamic>.from(map['evidence'] as List) : const <dynamic>[],
      );
}
