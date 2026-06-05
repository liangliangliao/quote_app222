import '../models/daily_diet_entry.dart';
import '../models/health_profile.dart';
import '../models/health_connect_daily_summary.dart';
import '../models/normalized_food_item.dart';
import 'health_connect_diet_context_service.dart';
import 'diet_food_analysis_service.dart';
import 'health_rule_engine.dart';

class DailyDietReviewService {
  final DietFoodAnalysisService _analysis = DietFoodAnalysisService();

  DailyDietReview buildLocalReview({
    required String userId,
    required String summaryDate,
    required List<DetectedDietFood> foods,
    required HealthProfile? profile,
    HealthRuleResult? ruleResult,
    List<DailyDietEntry> entries = const [],
    HealthConnectDailySummary? healthSummary,
    List<NormalizedFoodItem> normalizedFoods = const [],
  }) {
    final summary = _analysis.summarize(foods, entries: entries, normalizedFoods: normalizedFoods);
    final problems = <String>[];
    final goodPoints = <String>[];
    final evidence = <DietReviewEvidence>[...summary.evidenceItems];
    final dataGaps = <String>[...summary.dataGaps];
    final healthHints = HealthConnectDietContextService().dietHintsFromSummary(healthSummary);
    final confidenceScore = _adjustConfidence(summary.confidenceScore, profile: profile, healthSummary: healthSummary);
    final confidenceLevel = _confidenceLevel(confidenceScore);

    if (profile == null) {
      dataGaps.add('还没有完整健康档案，复盘无法充分结合身高体重、健康目标、忌口、过敏和疾病风险。');
    } else {
      evidence.add(DietReviewEvidence(
        type: 'profile',
        title: '健康档案参与判断',
        detail: '当前目标：${_goalText(profile.mainGoal)}；已读取健康状况、饮食限制和偏好。',
        source: 'health_profiles/health_conditions/diet_restrictions',
        confidence: 0.78,
      ));
    }
    if (healthSummary?.hasAnyData == true) {
      evidence.add(DietReviewEvidence(
        type: 'health_connect',
        title: '身体状态参与判断',
        detail: healthSummary!.compactText(),
        source: 'health_connect_daily_summary',
        confidence: 0.76,
      ));
    } else {
      dataGaps.add('今天没有同步到 Health Connect 身体数据，睡眠、步数、运动量、饮水量等只能缺省处理。');
    }

    if (foods.isEmpty) {
      return DailyDietReview(
        userId: userId,
        summaryDate: summaryDate,
        recoveryScore: 50,
        proteinScore: 0,
        fiberScore: 0,
        vegetableScore: 0,
        sugarRiskScore: 0,
        sodiumRiskScore: 0,
        ultraProcessedScore: 0,
        confidenceScore: confidenceScore,
        confidenceLevel: '数据不足',
        evidenceItems: evidence,
        dataGaps: dataGaps,
        recipeNeeds: const [
          DietRecipeNeed(
            mealType: 'any',
            goal: 'record_first',
            queryText: 'simple healthy meal',
            reason: '今天缺少可分析食物，先推荐易记录、易执行的一餐。',
            prefer: ['鸡蛋', '豆腐', '青菜', '燕麦'],
            maxReadyMinutes: 20,
          ),
        ],
        overallSummary: entries.any((e) => e.imageCount > 0)
            ? '你已经上传了饮食图片，但还没有确认具体食物。请在确认页手动添加食物；未确认前，系统不会用图片文件名或无关文字生成错误分析。当前复盘可信度：数据不足。'
            : '今天还没有可分析的饮食记录。你可以先用文字、图片或语音简单记录一餐。当前复盘可信度：数据不足。',
        goodPoints: const ['愿意开始记录饮食，就是改善饮食习惯的第一步。'],
        mainProblems: const ['暂无足够记录用于判断。'],
        nextDayAdvice: '先准确记录一餐，不需要一开始就追求精确克数。',
      );
    }

    goodPoints.add('你今天已经确认了 ${foods.length} 个食物项，系统会优先基于这些“用户确认过的食物”生成复盘。');
    if (summary.goodTags.isNotEmpty) {
      goodPoints.add('今天的健康加分项：${summary.goodTags.join('、')}。');
    }
    if (summary.mealCount >= 2) {
      goodPoints.add('今天至少记录了 ${summary.mealCount} 类餐次，这比只记零散食物更有助于发现饮食模式。');
    }
    if (summary.nutritionTotals.hasAny) {
      goodPoints.add('已根据外部营养数据和份量线索估算今日营养总量，仍需以实际克数校正。');
    }

    if (summary.hasSugar) problems.add('甜饮、甜食或高糖食物出现，可能会增加糖负担，也容易形成“疲劳时靠糖硬撑”的循环。');
    if (summary.hasSodium) problems.add('方便面、火腿肠、麻辣烫、咸菜或外卖汤汁这类高盐/重口味食物需要注意。');
    if (summary.hasUltraProcessed) problems.add('加工食品出现时，不只看热量，还要关注钠、油、添加物和营养密度。');
    if (summary.hasFriedOrGrilled) problems.add('油炸、煎烤或烧烤类偏多时，饮食会更重油，对恢复型饮食不友好。');
    if (summary.hasSpicy && (profile?.conditions.contains('stomach_sensitive') ?? false)) problems.add('你档案中有胃肠敏感，辛辣刺激类食物建议更谨慎。');
    if (summary.skippedBreakfast) problems.add('今天出现早餐缺失，后续更容易用甜饮、重口味或夜宵来补偿。');
    if (!summary.hasVegetable) problems.add('今天记录中蔬菜、水果或高纤维食物偏少。');
    if (!summary.hasProtein) problems.add('今天记录中鸡蛋、奶、豆制品、鱼肉、瘦肉等优质蛋白来源不明显。');

    if (healthSummary?.sleepLow == true && summary.hasSugar) {
      problems.add('Health Connect 显示睡眠偏少，同时今天有甜饮/高糖食物，可能形成“疲劳时靠糖硬撑”的循环。');
    }
    if (healthSummary?.stepsLow == true && (summary.hasSugar || summary.hasFriedOrGrilled || summary.hasUltraProcessed)) {
      problems.add('今天活动量偏低，同时有高糖、高油或加工食品，晚餐和夜宵更建议清淡一些。');
    }
    if ((healthSummary?.stepsHigh == true || healthSummary?.exerciseHigh == true) && !summary.hasProtein) {
      problems.add('今天活动量较高，但优质蛋白来源不明显，运动恢复材料可能不足。');
    }

    final nextAction = _microAction(summary, profile, healthSummary);
    final profileGoal = profile?.mainGoal ?? 'general_health';
    final goalText = _goalText(profileGoal);
    final warning = ruleResult?.warnings.isNotEmpty == true ? '\n${ruleResult!.warnings.first}' : '';
    final tagText = summary.riskTags.isEmpty ? '暂无明显高风险标签' : summary.riskTags.join('、');
    final nutritionText = _nutritionTotalsText(summary);
    final healthText = healthHints.isEmpty ? '' : '\n身体状态提示：${healthHints.first}';
    final noticeText = warning.isEmpty ? '' : warning;
    final overallText = '结合你当前目标“$goalText”，系统会把饮食结构、外部营养数据、份量线索与 Health Connect 身体状态一起判断。今日识别到的重点标签：$tagText。当前复盘可信度：$confidenceLevel（${(confidenceScore * 100).round()}%）。$nutritionText$healthText$noticeText';
    final recipeNeeds = _recipeNeeds(summary, profile, healthSummary, problems, nextAction);

    return DailyDietReview(
      userId: userId,
      summaryDate: summaryDate,
      recoveryScore: summary.recoveryScore,
      proteinScore: summary.proteinScore,
      fiberScore: summary.fiberScore,
      vegetableScore: summary.vegetableScore,
      sugarRiskScore: summary.sugarRiskScore,
      sodiumRiskScore: summary.sodiumRiskScore,
      ultraProcessedScore: summary.ultraProcessedScore,
      totalCaloriesKcal: summary.nutritionTotals.caloriesKcal,
      totalProteinG: summary.nutritionTotals.proteinG,
      totalFatG: summary.nutritionTotals.fatG,
      totalCarbsG: summary.nutritionTotals.carbsG,
      totalFiberG: summary.nutritionTotals.fiberG,
      totalSugarG: summary.nutritionTotals.sugarG,
      totalSodiumMg: summary.nutritionTotals.sodiumMg,
      confidenceScore: confidenceScore,
      confidenceLevel: confidenceLevel,
      evidenceItems: evidence.take(12).toList(),
      dataGaps: _unique(dataGaps).take(6).toList(),
      recipeNeeds: recipeNeeds,
      overallSummary: overallText,
      goodPoints: goodPoints.take(4).toList(),
      mainProblems: problems.take(5).toList(),
      nextDayAdvice: nextAction,
    );
  }

  DailyDietReview mergeAiReview(DailyDietReview base, Map<String, dynamic>? ai) {
    if (ai == null || ai.isEmpty) return base;
    final problems = _stringList(ai['priority_problems'] ?? ai['core_problems']);
    final advice = (ai['tomorrow_minimum_action'] ?? ai['next_day_advice'] ?? '').toString().trim();
    final summary = (ai['coach_summary'] ?? ai['overall_summary'] ?? '').toString().trim();
    final needs = _recipeNeedsFromAi(ai['recipe_needs']);
    return base.copyWith(
      aiReviewJson: ai,
      overallSummary: summary.isEmpty ? base.overallSummary : '${base.overallSummary}\n\nAI 二次审查：$summary',
      mainProblems: problems.isEmpty ? base.mainProblems : _unique([...problems, ...base.mainProblems]).take(5).toList(),
      nextDayAdvice: advice.isEmpty ? base.nextDayAdvice : advice,
      recipeNeeds: needs.isEmpty ? base.recipeNeeds : needs,
    );
  }

  List<DietRecipeNeed> _recipeNeeds(DietFoodSummary summary, HealthProfile? profile, HealthConnectDailySummary? healthSummary, List<String> problems, String nextAction) {
    final goal = profile?.mainGoal ?? 'balanced';
    final text = '${problems.join(' ')} $nextAction';
    final out = <DietRecipeNeed>[];
    void add(DietRecipeNeed need) {
      if (!out.any((e) => e.mealType == need.mealType && e.goal == need.goal && e.queryText == need.queryText)) out.add(need);
    }

    if (summary.hasSodium || text.contains('高盐') || text.contains('汤汁')) {
      add(DietRecipeNeed(
        mealType: 'dinner',
        goal: 'low_sodium',
        queryText: '低盐 清淡 蔬菜 蛋白 豆腐 菌菇',
        reason: '今日出现高盐/重口味线索，明日晚餐优先降低钠负担。',
        prefer: const ['豆腐', '菌菇', '青菜', '鱼肉'],
        avoid: const ['腌制品', '调料包', '外卖汤汁', '火腿肠'],
        maxSodiumMg: 600,
        maxReadyMinutes: 30,
      ));
    }
    if (summary.hasSugar || text.contains('甜饮') || text.contains('高糖')) {
      add(DietRecipeNeed(
        mealType: 'breakfast',
        goal: 'blood_sugar_friendly',
        queryText: '控糖 无糖 高蛋白 早餐 燕麦 鸡蛋 酸奶',
        reason: '今日有甜饮/高糖线索，明天先稳定早餐，减少靠糖硬撑。',
        prefer: const ['鸡蛋', '燕麦', '无糖酸奶', '豆浆'],
        avoid: const ['含糖饮料', '甜点', '奶茶'],
        minProteinG: 18,
        maxReadyMinutes: 15,
      ));
    }
    if (!summary.hasProtein || summary.proteinScore < 55) {
      add(DietRecipeNeed(
        mealType: healthSummary?.exerciseHigh == true ? 'post_workout' : 'lunch',
        goal: 'high_protein',
        queryText: '高蛋白 家常 清淡 鸡蛋 豆腐 鸡胸肉',
        reason: '今日优质蛋白来源不明显，明天需要补一个易执行蛋白来源。',
        prefer: const ['鸡蛋', '豆腐', '鱼肉', '鸡胸肉', '牛奶'],
        minProteinG: 22,
        maxReadyMinutes: 25,
      ));
    }
    if (!summary.hasVegetable || !summary.hasFiber) {
      add(DietRecipeNeed(
        mealType: 'any',
        goal: 'fiber_boost',
        queryText: '高纤维 蔬菜 家常 青菜 菌菇 豆腐',
        reason: '今日蔬菜水果或膳食纤维偏少，明天任意一餐先补一份蔬菜。',
        prefer: const ['青菜', '番茄', '黄瓜', '菌菇', '豆类'],
        maxReadyMinutes: 20,
      ));
    }
    if (profile?.conditions.contains('stomach_sensitive') == true || goal == 'stomach_care') {
      add(DietRecipeNeed(
        mealType: 'dinner',
        goal: 'stomach_care',
        queryText: '养胃粥 清淡 蒸煮 南瓜 山药 鸡肉',
        reason: '档案含胃肠敏感/调理肠胃目标，推荐温和、少油少辣、蒸煮炖类。',
        prefer: const ['粥', '南瓜', '山药', '鸡肉', '豆腐'],
        avoid: const ['辛辣', '油炸', '冰饮'],
        maxReadyMinutes: 30,
      ));
    }
    if (out.isEmpty) {
      add(DietRecipeNeed(
        mealType: 'any',
        goal: goal,
        queryText: '健康家常菜 清淡 蛋白 蔬菜',
        reason: '今日没有极端风险，优先保持有蛋白、有蔬菜、少甜饮、少重盐的基础结构。',
        prefer: const ['鸡蛋', '豆腐', '青菜', '鱼肉'],
        maxReadyMinutes: 25,
      ));
    }
    return out.take(4).toList();
  }

  List<DietRecipeNeed> _recipeNeedsFromAi(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) {
      final q = (item['query_text'] ?? item['query'] ?? '').toString().trim();
      if (q.isEmpty) return null;
      return DietRecipeNeed(
        mealType: (item['meal_type'] ?? 'any').toString(),
        goal: (item['goal'] ?? 'ai_review').toString(),
        queryText: q,
        reason: (item['reason'] ?? 'AI 二次审查生成的菜谱需求。').toString(),
        prefer: _stringList(item['prefer']),
        avoid: _stringList(item['avoid']),
        maxSodiumMg: double.tryParse((item['max_sodium_mg'] ?? '').toString()),
        minProteinG: double.tryParse((item['min_protein_g'] ?? '').toString()),
        maxReadyMinutes: int.tryParse((item['max_ready_minutes'] ?? '').toString()),
      );
    }).whereType<DietRecipeNeed>().take(4).toList();
  }

  List<String> _stringList(Object? value) {
    if (value is List) return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return const [];
    return text.split(RegExp(r'[,，;；、\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  String _nutritionTotalsText(DietFoodSummary summary) {
    final t = summary.nutritionTotals;
    if (!t.hasAny) return '\n营养总量：份量或营养数据不足，暂不显示伪精确热量。';
    final parts = <String>[];
    if (t.caloriesKcal != null) parts.add('热量约 ${t.caloriesKcal!.round()} kcal');
    if (t.proteinG != null) parts.add('蛋白质约 ${t.proteinG!.toStringAsFixed(1)}g');
    if (t.fiberG != null) parts.add('纤维约 ${t.fiberG!.toStringAsFixed(1)}g');
    if (t.sugarG != null) parts.add('糖约 ${t.sugarG!.toStringAsFixed(1)}g');
    if (t.sodiumMg != null) parts.add('钠约 ${t.sodiumMg!.round()}mg');
    return '\n营养总量粗估：${parts.join('，')}。';
  }

  double _adjustConfidence(double base, {HealthProfile? profile, HealthConnectDailySummary? healthSummary}) {
    var score = base;
    if (profile != null) score += 0.05;
    if (healthSummary?.hasAnyData == true) score += 0.07;
    return score.clamp(0.0, 0.98).toDouble();
  }

  String _confidenceLevel(double score) {
    if (score < 0.35) return '数据不足';
    if (score < 0.58) return '基础可信';
    if (score < 0.78) return '中等可信';
    return '较高可信';
  }

  String _microAction(DietFoodSummary summary, HealthProfile? profile, HealthConnectDailySummary? healthSummary) {
    final conditions = profile?.conditions ?? const <String>[];
    final goal = profile?.mainGoal ?? 'general_health';
    if (healthSummary?.sleepLow == true && summary.hasSugar) return '明天先把“疲劳时靠甜饮硬撑”改小一点：奶茶改小杯少糖，早餐加一个鸡蛋或一杯无糖豆浆。';
    if ((healthSummary?.stepsHigh == true || healthSummary?.exerciseHigh == true) && !summary.hasProtein) return '明天如果还有运动或步数较多，运动后补一个蛋白质来源：鸡蛋、牛奶/豆浆、豆腐、鱼肉或鸡胸肉。';
    if (healthSummary?.stepsLow == true && summary.hasSodium) return '明天活动量低时，先减少重盐外卖汤汁或泡面调料包，再加一份青菜。';
    if (summary.hasSugar) return '明天先不用完全戒甜饮料，只把奶茶/甜饮改成小杯少糖，或者换成无糖豆浆、无糖酸奶。';
    if (summary.hasSodium) return '明天如果吃泡面、麻辣烫或外卖，先做一个小改变：少喝汤汁，调料包只放一半，再加一份青菜。';
    if (summary.skippedBreakfast) return '明天早餐先做“最小版本”：一个鸡蛋或一杯无糖豆浆即可，不要求复杂。';
    if (!summary.hasVegetable) return '明天只补一个最小动作：任意一餐加一份青菜、番茄、黄瓜、南瓜或菌菇。';
    if (!summary.hasProtein) return '明天早餐或午餐加一个鸡蛋、一杯无糖豆浆、牛奶、豆腐或鱼肉，让身体恢复更有材料。';
    if (conditions.contains('stomach_sensitive')) return '明天继续保持清淡，优先选择粥、汤、蒸煮类，少油少辣。';
    if (goal == 'muscle_gain') return '明天继续保持记录，并在运动后补充蛋白质和适量主食，避免只吃零食或甜饮。';
    return '明天继续保持记录，并优先维持“有蛋白、有蔬菜、少甜饮、少重盐”的简单结构。';
  }

  String _goalText(String code) {
    switch (code) {
      case 'restore_energy':
        return '恢复体力';
      case 'stomach_care':
        return '调理肠胃';
      case 'weight_control':
        return '控制体重';
      case 'muscle_gain':
        return '增肌';
      case 'blood_sugar_friendly':
        return '控糖饮食';
      case 'low_sodium':
        return '低盐饮食';
      case 'teen_growth':
        return '青少年健康成长';
      case 'balanced':
        return '普通健康均衡饮食';
      default:
        return '健康饮食';
    }
  }

  List<String> _unique(Iterable<String> input) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in input) {
      final v = item.trim();
      if (v.isEmpty) continue;
      if (seen.add(v)) out.add(v);
    }
    return out;
  }
}
