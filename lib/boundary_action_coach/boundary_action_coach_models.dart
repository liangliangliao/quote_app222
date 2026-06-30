/// Standalone domain models for Boundary Action Coach.
///
/// These classes intentionally do not depend on `boundary_practice` or any other
/// growth module. They mirror the product design data objects so the module can
/// evolve from local prototype to persisted/remote AI workflows without changing
/// its public shape.
class BoundaryCase {
  const BoundaryCase({
    required this.sceneType,
    required this.relatedPerson,
    required this.description,
    required this.myFeeling,
    required this.otherRequest,
    required this.alreadyAgreed,
    required this.trueDesire,
    required this.guiltLevel,
    required this.resentmentLevel,
    required this.safetyRisk,
    required this.aiBoundary,
    required this.actualAction,
    required this.reviewResult,
  });

  final String sceneType;
  final String relatedPerson;
  final String description;
  final String myFeeling;
  final String otherRequest;
  final String alreadyAgreed;
  final String trueDesire;
  final int guiltLevel;
  final int resentmentLevel;
  final String safetyRisk;
  final String aiBoundary;
  final String actualAction;
  final String reviewResult;
}

class RelationshipProfile {
  const RelationshipProfile({
    required this.relationType,
    required this.commonPattern,
    required this.hasGuiltManipulation,
    required this.hasControl,
    required this.realNeed,
    required this.myTypicalReaction,
    required this.otherTypicalReaction,
    required this.availableBoundaries,
    required this.disabledStrategies,
    required this.safetyLevel,
  });

  final String relationType;
  final String commonPattern;
  final bool hasGuiltManipulation;
  final bool hasControl;
  final String realNeed;
  final String myTypicalReaction;
  final String otherTypicalReaction;
  final List<String> availableBoundaries;
  final List<String> disabledStrategies;
  final String safetyLevel;
}

class ResponsibilityMap {
  const ResponsibilityMap({
    required this.mine,
    required this.theirs,
    required this.shared,
    required this.burdens,
    required this.loads,
    required this.currentConsequenceOwner,
    required this.correctConsequenceOwner,
  });

  final List<String> mine;
  final List<String> theirs;
  final List<String> shared;
  final List<String> burdens;
  final List<String> loads;
  final String currentConsequenceOwner;
  final String correctConsequenceOwner;
}

class BoundaryScriptSet {
  const BoundaryScriptSet({
    required this.gentle,
    required this.shortDirect,
    required this.repeatUnderPressure,
    required this.highConflict,
    required this.workplace,
    required this.family,
    required this.reviewNote,
  });

  final String gentle;
  final String shortDirect;
  final String repeatUnderPressure;
  final String highConflict;
  final String workplace;
  final String family;
  final String reviewNote;
}

class BoundaryGrowthStage {
  const BoundaryGrowthStage({
    required this.currentStage,
    required this.weeklySmallNo,
    required this.weeklyFreeYes,
    required this.guiltChange,
    required this.resentmentChange,
    required this.respectOthersBoundaryScore,
    required this.supportSystemUse,
  });

  final int currentStage;
  final String weeklySmallNo;
  final String weeklyFreeYes;
  final int guiltChange;
  final int resentmentChange;
  final int respectOthersBoundaryScore;
  final String supportSystemUse;
}

class BoundaryFeatureModule {
  const BoundaryFeatureModule({
    required this.title,
    required this.problemSolved,
    required this.coreValue,
    required this.subFeatures,
    required this.aiOutputs,
    required this.dataObjects,
    required this.promptId,
    required this.releasePhase,
    required this.landed,
  });

  final String title;
  final String problemSolved;
  final String coreValue;
  final List<String> subFeatures;
  final List<String> aiOutputs;
  final List<String> dataObjects;
  final String promptId;
  final String releasePhase;
  final bool landed;
}
