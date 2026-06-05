import '../models/health_profile.dart';
import '../models/normalized_recipe.dart';

class HealthyRecipeRecommendationService {
  List<NormalizedRecipe> searchRecipes({
    required String query,
    HealthProfile? profile,
    String? goalCode,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final activeGoal = goalCode?.isNotEmpty == true ? goalCode! : (profile?.mainGoal ?? 'balanced');
    final restrictions = profile?.restrictions ?? const <String>[];
    final conditions = profile?.conditions ?? const <String>[];

    final filtered = _catalog.where((recipe) {
      if (_blockedByRestrictions(recipe, restrictions)) return false;
      final text = [
        recipe.title,
        ...recipe.ingredients,
        ...recipe.healthTags,
        ...recipe.dietTags,
        ...recipe.cautions,
      ].join(' ').toLowerCase();
      final queryOk = normalizedQuery.isEmpty || text.contains(normalizedQuery);
      final goalOk = activeGoal == 'balanced' || recipe.healthTags.contains(activeGoal) || recipe.dietTags.contains(activeGoal);
      final conditionOk = conditions.isEmpty || _matchesCondition(recipe, conditions);
      return queryOk && (goalOk || conditionOk || normalizedQuery.isNotEmpty);
    }).toList();

    filtered.sort((a, b) {
      final scoreA = _score(a, activeGoal, restrictions, conditions, normalizedQuery);
      final scoreB = _score(b, activeGoal, restrictions, conditions, normalizedQuery);
      return scoreB.compareTo(scoreA);
    });
    return filtered;
  }

  List<String> healthChangeSuggestions(NormalizedRecipe recipe, HealthProfile? profile) {
    final suggestions = <String>[];
    final goal = profile?.mainGoal ?? 'balanced';
    final conditions = profile?.conditions ?? const <String>[];
    final restrictions = profile?.restrictions ?? const <String>[];

    if (goal == 'low_sodium' || conditions.contains('hypertension')) {
      suggestions.add('低盐改造：盐和酱油减半，尽量不用浓汤宝、火腿肠、咸菜等高钠配料。');
    }
    if (goal == 'blood_sugar_friendly' || conditions.contains('diabetes_or_high_glucose')) {
      suggestions.add('控糖改造：主食控制在七分量，优先搭配蔬菜和蛋白质，避免额外加糖。');
    }
    if (goal == 'muscle_gain') {
      suggestions.add('高蛋白改造：可适量增加鸡蛋、鱼肉、鸡胸肉、豆腐或酸奶，运动后更适合。');
    }
    if (goal == 'stomach_care' || conditions.contains('stomach_sensitive') || restrictions.contains('no_spicy')) {
      suggestions.add('肠胃友好改造：不加辣椒、胡椒和冰冷饮品，优先蒸、煮、炖，口味保持清淡。');
    }
    if (goal == 'weight_control') {
      suggestions.add('控重改造：减少油量和酱汁，蔬菜量加倍，主食不过量，不用极端节食。');
    }
    if (goal == 'restore_energy' || conditions.contains('fatigue')) {
      suggestions.add('恢复体力改造：保证一份优质蛋白和稳定碳水，不用奶茶或甜饮料代替正餐。');
    }
    if (suggestions.isEmpty) {
      suggestions.add('均衡改造：保持一份蛋白质、一份主食和两份蔬菜的结构，少油少盐。');
    }
    return suggestions;
  }

  List<String> buildShoppingItems(NormalizedRecipe recipe) {
    final seen = <String>{};
    final items = <String>[];
    for (final ingredient in recipe.ingredients) {
      final value = ingredient.trim();
      if (value.isEmpty) continue;
      final key = value.replaceAll(RegExp(r'\s+'), '');
      if (seen.add(key)) items.add(value);
    }
    return items;
  }

  bool _blockedByRestrictions(NormalizedRecipe recipe, List<String> restrictions) {
    final text = [recipe.title, ...recipe.ingredients].join(' ');
    if (restrictions.contains('egg_allergy') && text.contains('蛋')) return true;
    if ((restrictions.contains('milk_allergy') || restrictions.contains('lactose_intolerance')) && (text.contains('牛奶') || text.contains('酸奶') || text.contains('奶酪'))) return true;
    if (restrictions.contains('seafood_allergy') && (text.contains('鱼') || text.contains('虾') || text.contains('海鲜'))) return true;
    if (restrictions.contains('peanut_allergy') && text.contains('花生')) return true;
    if (restrictions.contains('vegetarian') && (text.contains('鸡') || text.contains('鱼') || text.contains('牛肉') || text.contains('猪') || text.contains('虾'))) return true;
    if (restrictions.contains('no_spicy') && (text.contains('辣椒') || text.contains('胡椒'))) return true;
    return false;
  }

  bool _matchesCondition(NormalizedRecipe recipe, List<String> conditions) {
    if (conditions.contains('hypertension') && (recipe.healthTags.contains('low_sodium') || recipe.dietTags.contains('low_sodium'))) return true;
    if (conditions.contains('diabetes_or_high_glucose') && recipe.healthTags.contains('blood_sugar_friendly')) return true;
    if (conditions.contains('stomach_sensitive') && recipe.healthTags.contains('stomach_care')) return true;
    if (conditions.contains('fatigue') && recipe.healthTags.contains('restore_energy')) return true;
    if (conditions.contains('constipation') && recipe.healthTags.contains('fiber_boost')) return true;
    return false;
  }

  int _score(NormalizedRecipe recipe, String goal, List<String> restrictions, List<String> conditions, String query) {
    var score = 0;
    if (recipe.healthTags.contains(goal) || recipe.dietTags.contains(goal)) score += 40;
    if (_matchesCondition(recipe, conditions)) score += 24;
    if (recipe.dietTags.contains('quick_meal')) score += 8;
    if (recipe.dietTags.contains('light_taste')) score += 8;
    if (query.isNotEmpty && recipe.title.toLowerCase().contains(query)) score += 16;
    if (recipe.readyMinutes != null && recipe.readyMinutes! <= 25) score += 6;
    if (recipe.proteinG != null && recipe.proteinG! >= 18) score += 4;
    if (recipe.sodiumMg != null && recipe.sodiumMg! <= 600) score += 4;
    return score;
  }

  static const List<NormalizedRecipe> _catalog = [
    NormalizedRecipe(
      source: 'local_stage5',
      sourceId: 'yam_chicken_porridge',
      title: '山药鸡肉粥',
      ingredients: ['大米 60g', '山药 150g', '鸡胸肉 120g', '胡萝卜 半根', '姜片 2片', '盐 少量'],
      steps: ['大米洗净后浸泡 20 分钟。', '鸡胸肉切丝，山药和胡萝卜切块。', '锅中加水和大米煮开后转小火。', '加入山药、胡萝卜煮至软烂。', '加入鸡肉丝煮熟，出锅前少量加盐。'],
      healthTags: ['restore_energy', 'stomach_care', 'post_recovery'],
      dietTags: ['light_taste', 'quick_meal', 'chinese_food'],
      cautions: ['肾脏疾病或需限制蛋白质者请遵医嘱。'],
      caloriesKcal: 420,
      proteinG: 30,
      fatG: 5,
      carbsG: 62,
      sodiumMg: 420,
      readyMinutes: 35,
      servings: 1,
      dataQuality: 'local_guidance',
    ),
    NormalizedRecipe(
      source: 'local_stage5',
      sourceId: 'tomato_egg_soup',
      title: '番茄鸡蛋豆腐汤',
      ingredients: ['番茄 2个', '鸡蛋 1个', '嫩豆腐 150g', '青菜 一把', '葱花 少量', '盐 少量'],
      steps: ['番茄切块，豆腐切小块。', '锅中少油或无油，加入番茄炒出汁。', '加水煮开后加入豆腐。', '淋入蛋液，加入青菜煮熟。', '少量盐调味，撒葱花。'],
      healthTags: ['balanced', 'weight_control', 'low_sodium', 'stomach_care'],
      dietTags: ['light_taste', 'quick_meal', 'chinese_food'],
      cautions: ['鸡蛋过敏者可去掉鸡蛋，改加豆腐。'],
      caloriesKcal: 260,
      proteinG: 18,
      fatG: 10,
      carbsG: 22,
      sodiumMg: 380,
      readyMinutes: 18,
      servings: 1,
      dataQuality: 'local_guidance',
    ),
    NormalizedRecipe(
      source: 'local_stage5',
      sourceId: 'low_sodium_steamed_fish',
      title: '低盐清蒸鱼配西兰花',
      ingredients: ['鱼片 180g', '西兰花 200g', '姜丝 少量', '葱段 少量', '低钠酱油 1小勺', '橄榄油 少量'],
      steps: ['鱼片用姜丝和葱段去腥。', '西兰花焯水或蒸熟。', '鱼片上锅蒸 8-10 分钟。', '出锅后只淋少量低钠酱油和热油。', '搭配西兰花食用，不额外喝咸汤汁。'],
      healthTags: ['low_sodium', 'restore_energy', 'muscle_gain'],
      dietTags: ['light_taste', 'chinese_food'],
      cautions: ['海鲜或鱼类过敏者不要选择。'],
      caloriesKcal: 330,
      proteinG: 38,
      fatG: 12,
      carbsG: 18,
      sodiumMg: 520,
      readyMinutes: 25,
      servings: 1,
      dataQuality: 'local_guidance',
    ),
    NormalizedRecipe(
      source: 'local_stage5',
      sourceId: 'oat_yogurt_bowl',
      title: '燕麦酸奶坚果碗',
      ingredients: ['即食燕麦 40g', '无糖酸奶 200g', '蓝莓或苹果 80g', '核桃 10g', '奇亚籽 5g'],
      steps: ['碗中加入无糖酸奶。', '加入燕麦和水果。', '撒上核桃和奇亚籽。', '搅拌后静置 5 分钟即可。'],
      healthTags: ['fiber_boost', 'weight_control', 'sleep_support', 'balanced'],
      dietTags: ['quick_meal', 'no_cook'],
      cautions: ['乳糖不耐或牛奶过敏者可改用无糖豆浆和豆乳酸奶。'],
      caloriesKcal: 360,
      proteinG: 18,
      fatG: 12,
      carbsG: 48,
      sodiumMg: 120,
      readyMinutes: 8,
      servings: 1,
      dataQuality: 'local_guidance',
    ),
    NormalizedRecipe(
      source: 'local_stage5',
      sourceId: 'blood_sugar_plate',
      title: '控糖餐盘：鸡胸肉杂粮饭',
      ingredients: ['鸡胸肉 150g', '糙米饭 半碗', '西兰花 150g', '蘑菇 100g', '番茄 1个', '橄榄油 少量'],
      steps: ['鸡胸肉煎熟或水煮后切片。', '西兰花和蘑菇焯水或清炒。', '糙米饭控制在半碗。', '餐盘中先放蔬菜，再放鸡胸肉，最后放主食。', '少油少盐调味。'],
      healthTags: ['blood_sugar_friendly', 'muscle_gain', 'weight_control'],
      dietTags: ['meal_prep', 'light_taste'],
      cautions: ['糖尿病用药中请根据医生或营养师建议安排主食量。'],
      caloriesKcal: 480,
      proteinG: 42,
      fatG: 12,
      carbsG: 48,
      sodiumMg: 480,
      readyMinutes: 30,
      servings: 1,
      dataQuality: 'local_guidance',
    ),
    NormalizedRecipe(
      source: 'local_stage5',
      sourceId: 'pumpkin_millet_porridge',
      title: '小米南瓜粥配水煮蛋',
      ingredients: ['小米 50g', '南瓜 150g', '鸡蛋 1个', '枸杞 少量', '水 适量'],
      steps: ['小米淘洗干净。', '南瓜去皮切块。', '锅中加水放入小米和南瓜，小火煮至软烂。', '另煮一个鸡蛋。', '粥出锅前可放少量枸杞，不额外加糖。'],
      healthTags: ['stomach_care', 'restore_energy', 'sleep_support'],
      dietTags: ['light_taste', 'rice_cooker', 'chinese_food'],
      cautions: ['鸡蛋过敏者可换成豆腐或少量瘦肉。'],
      caloriesKcal: 350,
      proteinG: 14,
      fatG: 7,
      carbsG: 60,
      sodiumMg: 110,
      readyMinutes: 28,
      servings: 1,
      dataQuality: 'local_guidance',
    ),
    NormalizedRecipe(
      source: 'local_stage5',
      sourceId: 'tofu_mushroom_greens',
      title: '豆腐菌菇青菜煲',
      ingredients: ['北豆腐 200g', '香菇或口蘑 120g', '青菜 200g', '姜丝 少量', '盐 少量', '生抽 半小勺'],
      steps: ['豆腐切块，菌菇切片，青菜洗净。', '锅中加水、姜丝和菌菇煮出鲜味。', '加入豆腐小火煮 8 分钟。', '加入青菜煮熟。', '用少量盐和半小勺生抽调味。'],
      healthTags: ['balanced', 'low_sodium', 'fiber_boost', 'weight_control'],
      dietTags: ['vegetarian', 'light_taste', 'quick_meal', 'chinese_food'],
      cautions: ['肾脏疾病或需限制钾、磷者请遵医嘱。'],
      caloriesKcal: 300,
      proteinG: 24,
      fatG: 13,
      carbsG: 24,
      sodiumMg: 360,
      readyMinutes: 22,
      servings: 1,
      dataQuality: 'local_guidance',
    ),
    NormalizedRecipe(
      source: 'local_stage5',
      sourceId: 'beef_spinach_iron',
      title: '菠菜牛肉温沙拉',
      ingredients: ['瘦牛肉 120g', '菠菜 200g', '彩椒 半个', '芝麻 少量', '橄榄油 少量', '柠檬汁 少量'],
      steps: ['牛肉切片煎熟或水煮。', '菠菜焯水后沥干。', '彩椒切丝。', '将牛肉、菠菜和彩椒拌匀。', '加入少量橄榄油、柠檬汁和芝麻。'],
      healthTags: ['restore_energy', 'anemia_support', 'muscle_gain'],
      dietTags: ['quick_meal', 'light_taste'],
      cautions: ['高尿酸或痛风急性期请谨慎选择红肉。'],
      caloriesKcal: 380,
      proteinG: 33,
      fatG: 18,
      carbsG: 20,
      sodiumMg: 420,
      readyMinutes: 20,
      servings: 1,
      dataQuality: 'local_guidance',
    ),
  ];
}
