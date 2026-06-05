class HealthDietExpertPlan {
  const HealthDietExpertPlan({
    required this.userId,
    required this.planDate,
    required this.focusTitle,
    required this.focusReason,
    required this.riskLevel,
    required this.dataCoverageLevel,
    required this.profileSummary,
    required this.healthConnectSummary,
    required this.recentDietSummary,
    required this.next24hStrategy,
    required this.microActionTitle,
    required this.microActionReason,
    required this.recipeGoal,
    required this.meals,
    required this.priorityProblems,
    required this.recommendedFoods,
    required this.limitFoods,
    required this.dataGaps,
    required this.safetyNotices,
    required this.evidence,
    required this.apiDiagnostics,
    this.aiCoachText,
  });

  final String userId;
  final String planDate;
  final String focusTitle;
  final String focusReason;
  final String riskLevel;
  final String dataCoverageLevel;
  final String profileSummary;
  final String healthConnectSummary;
  final String recentDietSummary;
  final String next24hStrategy;
  final String microActionTitle;
  final String microActionReason;
  final String recipeGoal;
  final List<ExpertMealBlock> meals;
  final List<String> priorityProblems;
  final List<String> recommendedFoods;
  final List<String> limitFoods;
  final List<String> dataGaps;
  final List<String> safetyNotices;
  final List<HealthDietEvidence> evidence;
  final List<ApiDiagnosticItem> apiDiagnostics;
  final String? aiCoachText;

  HealthDietExpertPlan copyWith({String? aiCoachText}) {
    return HealthDietExpertPlan(
      userId: userId,
      planDate: planDate,
      focusTitle: focusTitle,
      focusReason: focusReason,
      riskLevel: riskLevel,
      dataCoverageLevel: dataCoverageLevel,
      profileSummary: profileSummary,
      healthConnectSummary: healthConnectSummary,
      recentDietSummary: recentDietSummary,
      next24hStrategy: next24hStrategy,
      microActionTitle: microActionTitle,
      microActionReason: microActionReason,
      recipeGoal: recipeGoal,
      meals: meals,
      priorityProblems: priorityProblems,
      recommendedFoods: recommendedFoods,
      limitFoods: limitFoods,
      dataGaps: dataGaps,
      safetyNotices: safetyNotices,
      evidence: evidence,
      apiDiagnostics: apiDiagnostics,
      aiCoachText: aiCoachText ?? this.aiCoachText,
    );
  }

  Map<String, Object?> toPromptJson() => {
        'date': planDate,
        'focus_title': focusTitle,
        'focus_reason': focusReason,
        'risk_level': riskLevel,
        'profile_summary': profileSummary,
        'health_connect_summary': healthConnectSummary,
        'recent_diet_summary': recentDietSummary,
        'priority_problems': priorityProblems,
        'next_24h_strategy': next24hStrategy,
        'micro_action': {'title': microActionTitle, 'reason': microActionReason},
        'meals': meals.map((e) => e.toPromptJson()).toList(),
        'recommended_foods': recommendedFoods,
        'limit_foods': limitFoods,
        'data_gaps': dataGaps,
        'safety_notices': safetyNotices,
        'evidence': evidence.map((e) => e.toPromptJson()).toList(),
      };
}

class ExpertMealBlock {
  const ExpertMealBlock({
    required this.mealType,
    required this.title,
    required this.purpose,
    required this.suggestions,
    required this.reason,
    required this.avoid,
    required this.recipeQuery,
  });

  final String mealType;
  final String title;
  final String purpose;
  final List<String> suggestions;
  final String reason;
  final List<String> avoid;
  final String recipeQuery;

  Map<String, Object?> toPromptJson() => {
        'meal_type': mealType,
        'title': title,
        'purpose': purpose,
        'suggestions': suggestions,
        'reason': reason,
        'avoid': avoid,
        'recipe_query': recipeQuery,
      };
}

class HealthDietEvidence {
  const HealthDietEvidence({
    required this.label,
    required this.value,
    required this.source,
    this.strength = 'medium',
  });

  final String label;
  final String value;
  final String source;
  final String strength;

  Map<String, Object?> toPromptJson() => {
        'label': label,
        'value': value,
        'source': source,
        'strength': strength,
      };
}

class ApiDiagnosticItem {
  const ApiDiagnosticItem({
    required this.name,
    required this.status,
    required this.message,
  });

  final String name;
  final String status;
  final String message;
}
