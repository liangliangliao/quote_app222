import '../models/daily_diet_entry.dart';
import '../models/normalized_food_item.dart';

/// Conservative local diet analyzer.
///
/// It combines three levels of evidence:
/// 1) user-confirmed foods and meal text,
/// 2) external/cache nutrition items when a food is matched,
/// 3) rough serving-size estimates when grams are available or can be inferred.
///
/// The result is intentionally transparent: it exposes evidence, data gaps and
/// estimated nutrition totals instead of pretending every item is precise.
class DietFoodAnalysisService {
  static const _proteinWords = [
    '鸡蛋', '蛋', '牛奶', '豆浆', '豆腐', '豆干', '鱼', '虾', '鸡胸', '鸡肉', '牛肉', '瘦肉', '酸奶', '豆类', '毛豆', '鸭肉', '猪肉', '羊肉', '蛋白'
  ];
  static const _vegetableFruitWords = [
    '青菜', '蔬菜', '西兰花', '菠菜', '白菜', '生菜', '油麦菜', '空心菜', '胡萝卜', '番茄', '西红柿', '黄瓜', '南瓜', '山药', '菌菇', '蘑菇', '水果', '苹果', '香蕉', '橙', '梨', '蓝莓', '草莓', '玉米', '红薯'
  ];
  static const _fiberWords = [
    '燕麦', '糙米', '全麦', '杂粮', '红薯', '玉米', '豆类', '蔬菜', '青菜', '西兰花', '菠菜', '水果', '菌菇', '海带', '木耳'
  ];
  static const _sugarWords = [
    '奶茶', '可乐', '雪碧', '甜饮料', '含糖饮料', '蛋糕', '甜点', '糖', '冰淇淋', '果汁', '巧克力', '饼干', '蛋挞', '甜品'
  ];
  static const _sodiumWords = [
    '方便面', '泡面', '火腿肠', '香肠', '咸菜', '腌', '卤味', '麻辣烫', '外卖', '烧烤', '薯片', '辣条', '调料包', '酸菜', '榨菜', '泡菜'
  ];
  static const _processedWords = [
    '方便面', '泡面', '火腿肠', '香肠', '薯片', '饼干', '辣条', '速冻', '罐头', '预制', '午餐肉', '蛋白棒', '零食'
  ];
  static const _friedWords = ['炸', '油条', '炸鸡', '薯条', '烧烤', '煎'];
  static const _spicyWords = ['辣', '麻辣', '火锅', '烧烤'];
  static const _drinkWords = ['奶茶', '咖啡', '可乐', '雪碧', '果汁', '饮料', '豆浆', '牛奶', '茶'];

  DietFoodSummary summarize(
    List<DetectedDietFood> foods, {
    List<DailyDietEntry> entries = const [],
    List<NormalizedFoodItem> normalizedFoods = const [],
  }) {
    final normalizedNames = foods.map((e) => _normalize('${e.foodName}${e.amountText ?? ''}')).where((e) => e.isNotEmpty).toList();
    bool hasAny(List<String> words) => normalizedNames.any((name) => words.any((word) => name.contains(word)));
    int countAny(List<String> words) => normalizedNames.where((name) => words.any((word) => name.contains(word))).length;

    final normalizedById = <int, NormalizedFoodItem>{};
    for (final item in normalizedFoods) {
      if (item.id != null) normalizedById[item.id!] = item;
    }

    final totals = _estimateTotals(foods, normalizedById);
    final matchedNutritionCount = foods.where((f) => f.normalizedFoodId != null && normalizedById.containsKey(f.normalizedFoodId)).length;
    final knownAmountCount = foods.where((f) => _estimatedGramsForFood(f, normalizedById[f.normalizedFoodId]) != null).length;
    final confirmedCount = foods.where((f) => f.confirmedByUser).length;

    final hasApiNutrition = matchedNutritionCount > 0;
    final apiProtein = totals.proteinG ?? 0;
    final apiFiber = totals.fiberG ?? 0;
    final apiSugar = totals.sugarG ?? 0;
    final apiSodium = totals.sodiumMg ?? 0;
    final apiCalories = totals.caloriesKcal ?? 0;

    final apiHighProtein = apiProtein >= 18;
    final apiHasFiber = apiFiber >= 5;
    final apiHighSugar = apiSugar >= 18 || normalizedFoods.any((e) => e.healthTags.contains('high_sugar'));
    final apiHighSodium = apiSodium >= 800 || normalizedFoods.any((e) => e.healthTags.contains('high_sodium'));
    final apiUltraProcessed = normalizedFoods.any((e) => e.healthTags.contains('ultra_processed'));

    final meals = foods.map((e) => e.mealType).where((e) => e.isNotEmpty && e != 'unknown').toSet();
    final textBlob = entries.map((e) => '${e.textDescription ?? ''} ${e.voiceText ?? ''}').join('，');
    final skippedBreakfast = RegExp(r'(早餐|早饭|早上).{0,8}(没吃|没来得及|空腹|不吃)').hasMatch(textBlob);

    final protein = hasAny(_proteinWords) || apiHighProtein;
    final vegetable = hasAny(_vegetableFruitWords);
    final fiber = hasAny(_fiberWords) || apiHasFiber;
    final sugar = hasAny(_sugarWords) || apiHighSugar;
    final sodium = hasAny(_sodiumWords) || apiHighSodium;
    final processed = hasAny(_processedWords) || apiUltraProcessed;
    final fried = hasAny(_friedWords);
    final spicy = hasAny(_spicyWords);
    final drink = hasAny(_drinkWords);

    final riskTags = <String>[];
    final goodTags = <String>[];
    final evidence = <DietReviewEvidence>[];
    final dataGaps = <String>[];

    void addEvidence(String type, String title, String detail, String source, [double confidence = 0.65]) {
      evidence.add(DietReviewEvidence(type: type, title: title, detail: detail, source: source, confidence: confidence));
    }

    if (foods.isNotEmpty) {
      addEvidence('confirmed_foods', '用户确认食物', '今天有 ${foods.length} 个食物项，其中 $confirmedCount 个为用户确认项。', 'detected_diet_foods.confirmed_by_user', confirmedCount == foods.length ? 0.9 : 0.7);
    }
    if (hasApiNutrition) {
      addEvidence('nutrition_api', '外部营养数据', '已匹配 $matchedNutritionCount/${foods.length} 个食物到 USDA / Open Food Facts / 本地缓存营养数据。', 'food_items', 0.82);
    } else if (foods.isNotEmpty) {
      dataGaps.add('今日食物尚未匹配到可靠营养数据库，因此高盐、高糖、蛋白质等判断更多依赖食物名称和本地规则。');
    }
    if (knownAmountCount > 0) {
      addEvidence('serving_estimation', '份量估算', '有 $knownAmountCount/${foods.length} 个食物可估算克数，营养总量为粗略估计。', 'estimated_grams/amount_text', 0.68);
    } else if (foods.isNotEmpty) {
      dataGaps.add('缺少克数或份量，无法把每 100g 营养值稳定换算成真实摄入量。');
    }

    if (sugar) {
      riskTags.add('高糖/甜饮');
      addEvidence('risk_sugar', '高糖/甜饮风险', hasApiNutrition && apiSugar > 0 ? '营养数据估算糖约 ${apiSugar.toStringAsFixed(1)}g，或食物名称中出现甜饮/甜食。' : '食物名称中出现甜饮、甜食或高糖相关关键词。', hasApiNutrition ? 'nutrition_api + food_keywords' : 'food_keywords', hasApiNutrition ? 0.78 : 0.62);
    }
    if (sodium) {
      riskTags.add('高盐/重口味');
      addEvidence('risk_sodium', '高盐/重口味风险', hasApiNutrition && apiSodium > 0 ? '营养数据估算钠约 ${apiSodium.toStringAsFixed(0)}mg，或出现泡面、麻辣烫、外卖汤汁等高钠线索。' : '食物名称中出现泡面、火腿肠、麻辣烫、外卖汤汁、调料包等高盐线索。', hasApiNutrition ? 'nutrition_api + food_keywords' : 'food_keywords', hasApiNutrition ? 0.78 : 0.64);
    }
    if (processed) {
      riskTags.add('加工食品');
      addEvidence('risk_processed', '加工食品风险', '出现方便食品、包装食品、速冻/预制或高加工标签。', hasApiNutrition ? 'nutrition_api + food_keywords' : 'food_keywords', hasApiNutrition ? 0.76 : 0.62);
    }
    if (hasApiNutrition && apiCalories > 0) goodTags.add('已接入营养数据库辅助判断');
    if (fried) {
      riskTags.add('油炸/烧烤');
      addEvidence('risk_oil', '油炸/煎烤风险', '食物名称或烹饪方式中出现油炸、煎烤、烧烤等线索。', 'food_keywords/cooking_method', 0.62);
    }
    if (spicy) {
      riskTags.add('辛辣刺激');
      addEvidence('risk_spicy', '辛辣刺激', '食物名称中出现辣、麻辣、火锅、烧烤等刺激性线索。', 'food_keywords', 0.6);
    }
    if (skippedBreakfast) {
      riskTags.add('早餐缺失');
      addEvidence('meal_regularity', '早餐缺失', '用户输入中出现“早餐没吃/空腹/不吃”等表达。', 'daily_diet_entries.text/voice', 0.74);
    }
    if (protein) {
      goodTags.add(hasApiNutrition && apiProtein > 0 ? '有蛋白质来源（估算约 ${apiProtein.toStringAsFixed(1)}g）' : '有蛋白质来源');
      addEvidence('good_protein', '蛋白质来源', hasApiNutrition && apiProtein > 0 ? '营养数据估算蛋白质约 ${apiProtein.toStringAsFixed(1)}g。' : '食物名称中出现鸡蛋、奶、豆制品、鱼肉、瘦肉等蛋白质来源。', hasApiNutrition ? 'nutrition_api + food_keywords' : 'food_keywords', hasApiNutrition ? 0.8 : 0.65);
    }
    if (vegetable) {
      goodTags.add('有蔬菜水果');
      addEvidence('good_vegetable', '蔬菜水果', '食物名称中出现青菜、番茄、黄瓜、菌菇、水果等线索。', 'food_keywords', 0.64);
    }
    if (fiber) {
      goodTags.add(hasApiNutrition && apiFiber > 0 ? '有膳食纤维来源（估算约 ${apiFiber.toStringAsFixed(1)}g）' : '有膳食纤维来源');
      addEvidence('good_fiber', '膳食纤维', hasApiNutrition && apiFiber > 0 ? '营养数据估算膳食纤维约 ${apiFiber.toStringAsFixed(1)}g。' : '食物名称中出现燕麦、杂粮、豆类、蔬菜、水果、菌菇等高纤线索。', hasApiNutrition ? 'nutrition_api + food_keywords' : 'food_keywords', hasApiNutrition ? 0.78 : 0.62);
    }
    if (meals.length >= 3) goodTags.add('记录餐次较完整');

    final proteinScore = protein
        ? (hasApiNutrition ? (apiProtein >= 45 ? 88.0 : (apiProtein >= 25 ? 78.0 : 66.0)) : (countAny(_proteinWords) >= 2 ? 78.0 : 66.0))
        : 35.0;
    final vegetableScore = vegetable ? 68.0 : 28.0;
    final fiberScore = fiber ? (hasApiNutrition ? (apiFiber >= 15 ? 84.0 : (apiFiber >= 7 ? 70.0 : 62.0)) : 64.0) : 30.0;
    final sugarRisk = sugar ? (hasApiNutrition ? (apiSugar >= 35 ? 88.0 : 70.0) : (drink ? 78.0 : 68.0)) : 18.0;
    final sodiumRisk = sodium ? (hasApiNutrition ? (apiSodium >= 2000 ? 90.0 : (apiSodium >= 1200 ? 78.0 : 68.0)) : 78.0) : 22.0;
    final processedRisk = processed ? 76.0 : 22.0;
    final oilRisk = fried ? 72.0 : 18.0;
    final regularityScore = skippedBreakfast
        ? 35.0
        : (meals.length >= 3 ? 75.0 : (meals.length >= 2 ? 58.0 : 45.0));

    final recoveryScore = (proteinScore * 0.20 + vegetableScore * 0.18 + fiberScore * 0.14 + regularityScore * 0.12 + (100 - sugarRisk) * 0.12 + (100 - sodiumRisk) * 0.12 + (100 - processedRisk) * 0.08 + (100 - oilRisk) * 0.04)
        .clamp(20.0, 95.0)
        .toDouble();

    if (foods.isNotEmpty && foods.length < 3) dataGaps.add('今日记录食物项较少，可能无法代表全天真实饮食。');
    if (entries.isEmpty) dataGaps.add('缺少餐次记录，无法判断早餐、午餐、晚餐是否完整。');

    final confidenceScore = _confidenceScore(
      foods: foods,
      confirmedCount: confirmedCount,
      matchedNutritionCount: matchedNutritionCount,
      knownAmountCount: knownAmountCount,
      entries: entries,
    );

    return DietFoodSummary(
      hasProtein: protein,
      hasVegetable: vegetable,
      hasFiber: fiber,
      hasSugar: sugar,
      hasSodium: sodium,
      hasUltraProcessed: processed,
      hasFriedOrGrilled: fried,
      hasSpicy: spicy,
      skippedBreakfast: skippedBreakfast,
      mealCount: meals.length,
      proteinScore: proteinScore,
      vegetableScore: vegetableScore,
      fiberScore: fiberScore,
      sugarRiskScore: sugarRisk,
      sodiumRiskScore: sodiumRisk,
      ultraProcessedScore: processedRisk,
      oilRiskScore: oilRisk,
      mealRegularityScore: regularityScore,
      recoveryScore: recoveryScore,
      riskTags: riskTags,
      goodTags: goodTags,
      nutritionTotals: totals,
      evidenceItems: evidence,
      dataGaps: dataGaps,
      confidenceScore: confidenceScore,
      matchedNutritionCount: matchedNutritionCount,
      knownAmountCount: knownAmountCount,
      confirmedFoodCount: confirmedCount,
    );
  }

  double _confidenceScore({
    required List<DetectedDietFood> foods,
    required int confirmedCount,
    required int matchedNutritionCount,
    required int knownAmountCount,
    required List<DailyDietEntry> entries,
  }) {
    if (foods.isEmpty) return 0.18;
    final foodCount = foods.length.clamp(1, 999).toDouble();
    var score = 0.18;
    score += 0.26 * (confirmedCount / foodCount).clamp(0.0, 1.0);
    score += 0.25 * (matchedNutritionCount / foodCount).clamp(0.0, 1.0);
    score += 0.18 * (knownAmountCount / foodCount).clamp(0.0, 1.0);
    score += entries.length >= 2 ? 0.08 : 0.03;
    score += foods.length >= 5 ? 0.05 : 0.02;
    return score.clamp(0.0, 0.96).toDouble();
  }

  NutritionTotals _estimateTotals(List<DetectedDietFood> foods, Map<int, NormalizedFoodItem> normalizedById) {
    var any = false;
    var kcal = 0.0;
    var protein = 0.0;
    var fat = 0.0;
    var carbs = 0.0;
    var fiber = 0.0;
    var sugar = 0.0;
    var sodium = 0.0;

    for (final food in foods) {
      final item = normalizedById[food.normalizedFoodId];
      if (item == null) continue;
      final grams = _estimatedGramsForFood(food, item);
      if (grams == null || grams <= 0) continue;
      final factor = grams / 100.0;
      double add(double? value) => (value ?? 0) * factor;
      kcal += add(item.caloriesKcal);
      protein += add(item.proteinG);
      fat += add(item.fatG);
      carbs += add(item.carbsG);
      fiber += add(item.fiberG);
      sugar += add(item.sugarG);
      sodium += add(item.sodiumMg);
      any = true;
    }

    return NutritionTotals(
      caloriesKcal: any ? kcal : null,
      proteinG: any ? protein : null,
      fatG: any ? fat : null,
      carbsG: any ? carbs : null,
      fiberG: any ? fiber : null,
      sugarG: any ? sugar : null,
      sodiumMg: any ? sodium : null,
    );
  }

  double? _estimatedGramsForFood(DetectedDietFood food, NormalizedFoodItem? item) {
    if (food.estimatedGrams != null && food.estimatedGrams! > 0) return food.estimatedGrams;
    final text = '${food.amountText ?? ''} ${food.foodName}'.trim();
    final direct = RegExp(r'(\d+(?:\.\d+)?)\s*(?:g|克|公克)').firstMatch(text.toLowerCase());
    if (direct != null) return double.tryParse(direct.group(1)!);
    final ml = RegExp(r'(\d+(?:\.\d+)?)\s*(?:ml|毫升)').firstMatch(text.toLowerCase());
    if (ml != null) return double.tryParse(ml.group(1)!);
    final serving = item?.servingSizeG;
    if ((food.amountText ?? '').contains('份') && serving != null && serving > 0) return serving;
    final name = food.foodName;
    if (name.contains('鸡蛋') || name == '蛋' || name.contains('蛋')) {
      if ((food.amountText ?? '').contains('两个') || (food.amountText ?? '').contains('2')) return 100;
      return 50;
    }
    if (name.contains('奶茶') || name.contains('可乐') || name.contains('饮料')) return 500;
    if (name.contains('牛奶') || name.contains('豆浆') || name.contains('酸奶')) return 250;
    if ((food.amountText ?? '').contains('一碗') || (food.amountText ?? '').contains('1碗')) return 250;
    if ((food.amountText ?? '').contains('一杯') || (food.amountText ?? '').contains('1杯')) return 250;
    if ((food.amountText ?? '').contains('一个') || (food.amountText ?? '').contains('1个')) return serving ?? 120;
    if ((food.amountText ?? '').contains('一份') || (food.amountText ?? '').contains('1份')) return serving ?? 180;
    return null;
  }

  String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), '').trim();
}

class NutritionTotals {
  const NutritionTotals({
    this.caloriesKcal,
    this.proteinG,
    this.fatG,
    this.carbsG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
  });

  final double? caloriesKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;

  bool get hasAny => [caloriesKcal, proteinG, fatG, carbsG, fiberG, sugarG, sodiumMg].any((e) => e != null && e > 0);
}

class DietFoodSummary {
  const DietFoodSummary({
    required this.hasProtein,
    required this.hasVegetable,
    required this.hasFiber,
    required this.hasSugar,
    required this.hasSodium,
    required this.hasUltraProcessed,
    required this.hasFriedOrGrilled,
    required this.hasSpicy,
    required this.skippedBreakfast,
    required this.mealCount,
    required this.proteinScore,
    required this.vegetableScore,
    required this.fiberScore,
    required this.sugarRiskScore,
    required this.sodiumRiskScore,
    required this.ultraProcessedScore,
    required this.oilRiskScore,
    required this.mealRegularityScore,
    required this.recoveryScore,
    required this.riskTags,
    required this.goodTags,
    required this.nutritionTotals,
    required this.evidenceItems,
    required this.dataGaps,
    required this.confidenceScore,
    required this.matchedNutritionCount,
    required this.knownAmountCount,
    required this.confirmedFoodCount,
  });

  final bool hasProtein;
  final bool hasVegetable;
  final bool hasFiber;
  final bool hasSugar;
  final bool hasSodium;
  final bool hasUltraProcessed;
  final bool hasFriedOrGrilled;
  final bool hasSpicy;
  final bool skippedBreakfast;
  final int mealCount;

  final double proteinScore;
  final double vegetableScore;
  final double fiberScore;
  final double sugarRiskScore;
  final double sodiumRiskScore;
  final double ultraProcessedScore;
  final double oilRiskScore;
  final double mealRegularityScore;
  final double recoveryScore;

  final List<String> riskTags;
  final List<String> goodTags;
  final NutritionTotals nutritionTotals;
  final List<DietReviewEvidence> evidenceItems;
  final List<String> dataGaps;
  final double confidenceScore;
  final int matchedNutritionCount;
  final int knownAmountCount;
  final int confirmedFoodCount;
}
