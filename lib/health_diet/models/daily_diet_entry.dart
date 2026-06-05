class DailyDietEntry {
  const DailyDietEntry({
    this.id,
    required this.userId,
    required this.entryDate,
    required this.mealType,
    required this.inputType,
    this.textDescription,
    this.voiceText,
    this.imageCount = 0,
    this.barcode,
    this.createdAt,
    this.updatedAt,
    this.foods = const [],
    this.images = const [],
  });

  final int? id;
  final String userId;
  final String entryDate;
  final String mealType;
  final String inputType;
  final String? textDescription;
  final String? voiceText;
  final int imageCount;
  final String? barcode;
  final String? createdAt;
  final String? updatedAt;
  final List<DetectedDietFood> foods;
  final List<DailyDietImage> images;

  factory DailyDietEntry.fromMap(Map<String, Object?> map) {
    return DailyDietEntry(
      id: int.tryParse((map['id'] ?? '').toString()),
      userId: (map['user_id'] ?? 'local_user').toString(),
      entryDate: (map['entry_date'] ?? '').toString(),
      mealType: (map['meal_type'] ?? 'unknown').toString(),
      inputType: (map['input_type'] ?? 'text').toString(),
      textDescription: map['text_description']?.toString(),
      voiceText: map['voice_text']?.toString(),
      imageCount: int.tryParse((map['image_count'] ?? '0').toString()) ?? 0,
      barcode: map['barcode']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  DailyDietEntry copyWith({
    int? id,
    String? userId,
    String? entryDate,
    String? mealType,
    String? inputType,
    String? textDescription,
    String? voiceText,
    int? imageCount,
    String? barcode,
    String? createdAt,
    String? updatedAt,
    List<DetectedDietFood>? foods,
    List<DailyDietImage>? images,
  }) {
    return DailyDietEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entryDate: entryDate ?? this.entryDate,
      mealType: mealType ?? this.mealType,
      inputType: inputType ?? this.inputType,
      textDescription: textDescription ?? this.textDescription,
      voiceText: voiceText ?? this.voiceText,
      imageCount: imageCount ?? this.imageCount,
      barcode: barcode ?? this.barcode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      foods: foods ?? this.foods,
      images: images ?? this.images,
    );
  }
}

class DetectedDietFood {
  const DetectedDietFood({
    this.id,
    this.entryId,
    required this.foodName,
    this.normalizedFoodId,
    this.amountText,
    this.estimatedGrams,
    required this.mealType,
    this.cookingMethod,
    this.confidenceScore,
    this.confirmedByUser = false,
    required this.source,
    this.createdAt,
  });

  final int? id;
  final int? entryId;
  final String foodName;
  final int? normalizedFoodId;
  final String? amountText;
  final double? estimatedGrams;
  final String mealType;
  final String? cookingMethod;
  final double? confidenceScore;
  final bool confirmedByUser;
  final String source;
  final String? createdAt;

  factory DetectedDietFood.fromMap(Map<String, Object?> map) {
    return DetectedDietFood(
      id: int.tryParse((map['id'] ?? '').toString()),
      entryId: int.tryParse((map['entry_id'] ?? '').toString()),
      foodName: (map['food_name'] ?? '').toString(),
      normalizedFoodId: int.tryParse((map['normalized_food_id'] ?? '').toString()),
      amountText: map['amount_text']?.toString(),
      estimatedGrams: double.tryParse((map['estimated_grams'] ?? '').toString()),
      mealType: (map['meal_type'] ?? 'unknown').toString(),
      cookingMethod: map['cooking_method']?.toString(),
      confidenceScore: double.tryParse((map['confidence_score'] ?? '').toString()),
      confirmedByUser: (int.tryParse((map['confirmed_by_user'] ?? '0').toString()) ?? 0) == 1,
      source: (map['source'] ?? 'manual').toString(),
      createdAt: map['created_at']?.toString(),
    );
  }

  Map<String, Object?> toInsertMap(int newEntryId) {
    return {
      'entry_id': newEntryId,
      'food_name': foodName,
      'normalized_food_id': normalizedFoodId,
      'amount_text': amountText,
      'estimated_grams': estimatedGrams,
      'meal_type': mealType,
      'cooking_method': cookingMethod,
      'confidence_score': confidenceScore,
      'confirmed_by_user': confirmedByUser ? 1 : 0,
      'source': source,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  DetectedDietFood copyWith({
    int? id,
    int? entryId,
    String? foodName,
    int? normalizedFoodId,
    String? amountText,
    double? estimatedGrams,
    String? mealType,
    String? cookingMethod,
    double? confidenceScore,
    bool? confirmedByUser,
    String? source,
    String? createdAt,
  }) {
    return DetectedDietFood(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      foodName: foodName ?? this.foodName,
      normalizedFoodId: normalizedFoodId ?? this.normalizedFoodId,
      amountText: amountText ?? this.amountText,
      estimatedGrams: estimatedGrams ?? this.estimatedGrams,
      mealType: mealType ?? this.mealType,
      cookingMethod: cookingMethod ?? this.cookingMethod,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      confirmedByUser: confirmedByUser ?? this.confirmedByUser,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DailyDietImage {
  const DailyDietImage({
    this.id,
    this.entryId,
    required this.localPath,
    required this.imageType,
    this.recognizedText,
    this.aiDetectedFoodsJson,
    this.userConfirmedFoodsJson,
    this.confidenceScore,
    this.createdAt,
  });

  final int? id;
  final int? entryId;
  final String localPath;
  final String imageType;
  final String? recognizedText;
  final String? aiDetectedFoodsJson;
  final String? userConfirmedFoodsJson;
  final double? confidenceScore;
  final String? createdAt;

  factory DailyDietImage.fromMap(Map<String, Object?> map) {
    return DailyDietImage(
      id: int.tryParse((map['id'] ?? '').toString()),
      entryId: int.tryParse((map['entry_id'] ?? '').toString()),
      localPath: (map['local_path'] ?? '').toString(),
      imageType: (map['image_type'] ?? 'meal_photo').toString(),
      recognizedText: map['recognized_text']?.toString(),
      aiDetectedFoodsJson: map['ai_detected_foods_json']?.toString(),
      userConfirmedFoodsJson: map['user_confirmed_foods_json']?.toString(),
      confidenceScore: double.tryParse((map['confidence_score'] ?? '').toString()),
      createdAt: map['created_at']?.toString(),
    );
  }
}

class DailyDietReview {
  const DailyDietReview({
    this.id,
    required this.userId,
    required this.summaryDate,
    this.recoveryScore,
    this.proteinScore,
    this.fiberScore,
    this.vegetableScore,
    this.sugarRiskScore,
    this.sodiumRiskScore,
    this.ultraProcessedScore,
    this.totalCaloriesKcal,
    this.totalProteinG,
    this.totalFatG,
    this.totalCarbsG,
    this.totalFiberG,
    this.totalSugarG,
    this.totalSodiumMg,
    this.confidenceScore = 0.0,
    this.confidenceLevel = '数据不足',
    this.evidenceItems = const [],
    this.dataGaps = const [],
    this.recipeNeeds = const [],
    this.aiReviewJson,
    required this.overallSummary,
    required this.goodPoints,
    required this.mainProblems,
    required this.nextDayAdvice,
    this.createdAt,
  });

  final int? id;
  final String userId;
  final String summaryDate;
  final double? recoveryScore;
  final double? proteinScore;
  final double? fiberScore;
  final double? vegetableScore;
  final double? sugarRiskScore;
  final double? sodiumRiskScore;
  final double? ultraProcessedScore;
  final double? totalCaloriesKcal;
  final double? totalProteinG;
  final double? totalFatG;
  final double? totalCarbsG;
  final double? totalFiberG;
  final double? totalSugarG;
  final double? totalSodiumMg;
  final double confidenceScore;
  final String confidenceLevel;
  final List<DietReviewEvidence> evidenceItems;
  final List<String> dataGaps;
  final List<DietRecipeNeed> recipeNeeds;
  final Map<String, dynamic>? aiReviewJson;
  final String overallSummary;
  final List<String> goodPoints;
  final List<String> mainProblems;
  final String nextDayAdvice;
  final String? createdAt;

  DailyDietReview copyWith({
    double? recoveryScore,
    double? proteinScore,
    double? fiberScore,
    double? vegetableScore,
    double? sugarRiskScore,
    double? sodiumRiskScore,
    double? ultraProcessedScore,
    double? totalCaloriesKcal,
    double? totalProteinG,
    double? totalFatG,
    double? totalCarbsG,
    double? totalFiberG,
    double? totalSugarG,
    double? totalSodiumMg,
    double? confidenceScore,
    String? confidenceLevel,
    List<DietReviewEvidence>? evidenceItems,
    List<String>? dataGaps,
    List<DietRecipeNeed>? recipeNeeds,
    Map<String, dynamic>? aiReviewJson,
    String? overallSummary,
    List<String>? goodPoints,
    List<String>? mainProblems,
    String? nextDayAdvice,
  }) {
    return DailyDietReview(
      id: id,
      userId: userId,
      summaryDate: summaryDate,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      proteinScore: proteinScore ?? this.proteinScore,
      fiberScore: fiberScore ?? this.fiberScore,
      vegetableScore: vegetableScore ?? this.vegetableScore,
      sugarRiskScore: sugarRiskScore ?? this.sugarRiskScore,
      sodiumRiskScore: sodiumRiskScore ?? this.sodiumRiskScore,
      ultraProcessedScore: ultraProcessedScore ?? this.ultraProcessedScore,
      totalCaloriesKcal: totalCaloriesKcal ?? this.totalCaloriesKcal,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalFatG: totalFatG ?? this.totalFatG,
      totalCarbsG: totalCarbsG ?? this.totalCarbsG,
      totalFiberG: totalFiberG ?? this.totalFiberG,
      totalSugarG: totalSugarG ?? this.totalSugarG,
      totalSodiumMg: totalSodiumMg ?? this.totalSodiumMg,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      evidenceItems: evidenceItems ?? this.evidenceItems,
      dataGaps: dataGaps ?? this.dataGaps,
      recipeNeeds: recipeNeeds ?? this.recipeNeeds,
      aiReviewJson: aiReviewJson ?? this.aiReviewJson,
      overallSummary: overallSummary ?? this.overallSummary,
      goodPoints: goodPoints ?? this.goodPoints,
      mainProblems: mainProblems ?? this.mainProblems,
      nextDayAdvice: nextDayAdvice ?? this.nextDayAdvice,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toEvidencePromptJson() => {
        'summary_date': summaryDate,
        'scores': {
          'recovery': recoveryScore,
          'protein': proteinScore,
          'fiber': fiberScore,
          'vegetable': vegetableScore,
          'sugar_risk': sugarRiskScore,
          'sodium_risk': sodiumRiskScore,
          'ultra_processed_risk': ultraProcessedScore,
        },
        'nutrition_totals_estimated': {
          'calories_kcal': totalCaloriesKcal,
          'protein_g': totalProteinG,
          'fat_g': totalFatG,
          'carbs_g': totalCarbsG,
          'fiber_g': totalFiberG,
          'sugar_g': totalSugarG,
          'sodium_mg': totalSodiumMg,
        },
        'confidence': {'score': confidenceScore, 'level': confidenceLevel},
        'good_points': goodPoints,
        'main_problems': mainProblems,
        'next_day_advice': nextDayAdvice,
        'data_gaps': dataGaps,
        'evidence': evidenceItems.map((e) => e.toJson()).toList(),
        'recipe_needs': recipeNeeds.map((e) => e.toJson()).toList(),
      };
}

class DietReviewEvidence {
  const DietReviewEvidence({
    required this.type,
    required this.title,
    required this.detail,
    required this.source,
    this.confidence = 0.6,
  });

  final String type;
  final String title;
  final String detail;
  final String source;
  final double confidence;

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'detail': detail,
        'source': source,
        'confidence': confidence,
      };
}

class DietRecipeNeed {
  const DietRecipeNeed({
    required this.mealType,
    required this.goal,
    required this.queryText,
    required this.reason,
    this.prefer = const [],
    this.avoid = const [],
    this.maxSodiumMg,
    this.minProteinG,
    this.maxReadyMinutes,
  });

  final String mealType;
  final String goal;
  final String queryText;
  final String reason;
  final List<String> prefer;
  final List<String> avoid;
  final double? maxSodiumMg;
  final double? minProteinG;
  final int? maxReadyMinutes;

  Map<String, dynamic> toJson() => {
        'meal_type': mealType,
        'goal': goal,
        'query_text': queryText,
        'reason': reason,
        'prefer': prefer,
        'avoid': avoid,
        'max_sodium_mg': maxSodiumMg,
        'min_protein_g': minProteinG,
        'max_ready_minutes': maxReadyMinutes,
      };
}
