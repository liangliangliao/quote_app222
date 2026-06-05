import '../models/daily_diet_entry.dart';
import '../models/health_profile.dart';
import '../models/health_connect_daily_summary.dart';
import '../repositories/daily_diet_entry_repository.dart';
import '../repositories/food_item_repository.dart';
import '../repositories/health_connect_summary_repository.dart';
import '../repositories/health_profile_repository.dart';
import 'daily_diet_review_service.dart';
import 'health_rule_engine.dart';

class NutritionBudgetItem {
  const NutritionBudgetItem({
    required this.label,
    required this.unit,
    this.target,
    this.limit,
    this.consumed,
    required this.advice,
  });

  final String label;
  final String unit;
  final double? target;
  final double? limit;
  final double? consumed;
  final String advice;

  double? get remaining {
    final base = target ?? limit;
    if (base == null || consumed == null) return null;
    return base - consumed!;
  }

  bool get hasValue => consumed != null && (target != null || limit != null);

  String get display {
    final parts = <String>[];
    if (target != null) parts.add('目标 ${_fmt(target!)}$unit');
    if (limit != null) parts.add('上限 ${_fmt(limit!)}$unit');
    parts.add(consumed == null ? '已确认：未知' : '已确认 ${_fmt(consumed!)}$unit');
    if (remaining != null) parts.add(remaining! >= 0 ? '还差/余量 ${_fmt(remaining!)}$unit' : '已超 ${_fmt(-remaining!)}$unit');
    return parts.join(' · ');
  }

  static String _fmt(double v) => v >= 100 ? v.round().toString() : v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
}

class HealthDietRealtimeState {
  const HealthDietRealtimeState({
    required this.stateDate,
    required this.confidenceScore,
    required this.confidenceLevel,
    required this.confirmedFoodCount,
    required this.entryCount,
    required this.nutritionMatchedCount,
    required this.currentPhase,
    required this.nextMealType,
    required this.nextBestAction,
    required this.dataGaps,
    required this.riskFlags,
    required this.budgets,
    this.profile,
    this.healthSummary,
    this.review,
  });

  final String stateDate;
  final double confidenceScore;
  final String confidenceLevel;
  final int confirmedFoodCount;
  final int entryCount;
  final int nutritionMatchedCount;
  final String currentPhase;
  final String nextMealType;
  final String nextBestAction;
  final List<String> dataGaps;
  final List<String> riskFlags;
  final List<NutritionBudgetItem> budgets;
  final HealthProfile? profile;
  final HealthConnectDailySummary? healthSummary;
  final DailyDietReview? review;

  String get confidenceText => '$confidenceLevel（${(confidenceScore * 100).round()}%）';
}

class HealthDietRealtimeStateService {
  HealthDietRealtimeStateService({
    HealthProfileRepository? profileRepository,
    HealthConnectSummaryRepository? healthRepository,
    DailyDietEntryRepository? entryRepository,
    FoodItemRepository? foodRepository,
    DailyDietReviewService? reviewService,
    HealthRuleEngine? ruleEngine,
  })  : _profileRepo = profileRepository ?? HealthProfileRepository(),
        _healthRepo = healthRepository ?? HealthConnectSummaryRepository(),
        _entryRepo = entryRepository ?? DailyDietEntryRepository(),
        _foodRepo = foodRepository ?? FoodItemRepository(),
        _review = reviewService ?? DailyDietReviewService(),
        _ruleEngine = ruleEngine ?? HealthRuleEngine();

  final HealthProfileRepository _profileRepo;
  final HealthConnectSummaryRepository _healthRepo;
  final DailyDietEntryRepository _entryRepo;
  final FoodItemRepository _foodRepo;
  final DailyDietReviewService _review;
  final HealthRuleEngine _ruleEngine;

  Future<HealthDietRealtimeState> build({String userId = HealthProfileRepository.defaultUserId}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final profile = await _profileRepo.latestProfile(userId: userId);
    final health = await _healthRepo.latestForDate(userId: userId, date: today);
    final entries = await _entryRepo.entriesForDate(today, userId: userId);
    final foods = entries.expand((e) => e.foods).where((e) => e.confirmedByUser || e.source != 'placeholder').toList();
    final normalized = await _foodRepo.byIds(foods.map((f) => f.normalizedFoodId));
    final rule = profile == null ? null : _ruleEngine.evaluateProfile(profile);
    final review = _review.buildLocalReview(
      userId: userId,
      summaryDate: today,
      foods: foods,
      profile: profile,
      ruleResult: rule,
      entries: entries,
      healthSummary: health,
      normalizedFoods: normalized,
    );
    final gaps = <String>[...review.dataGaps];
    if (entries.isEmpty) gaps.add('今天尚未记录任何一餐，Agent 只能按健康档案给出保守方案。');
    if (foods.isEmpty) gaps.add('今天确认食物为 0，无法计算“已吃/还缺/已超”。');
    if (normalized.isEmpty && foods.isNotEmpty) gaps.add('今日食物尚未匹配到 USDA / Open Food Facts 营养数据。');
    final budgets = _budgets(profile, review, health);
    return HealthDietRealtimeState(
      stateDate: today,
      confidenceScore: review.confidenceScore,
      confidenceLevel: review.confidenceLevel,
      confirmedFoodCount: foods.length,
      entryCount: entries.length,
      nutritionMatchedCount: normalized.length,
      currentPhase: _phase(DateTime.now()),
      nextMealType: _nextMeal(DateTime.now()),
      nextBestAction: _nextBestAction(review, profile, health),
      dataGaps: _unique(gaps).take(6).toList(),
      riskFlags: _riskFlags(review, profile, health),
      budgets: budgets,
      profile: profile,
      healthSummary: health,
      review: review,
    );
  }

  List<NutritionBudgetItem> _budgets(HealthProfile? profile, DailyDietReview review, HealthConnectDailySummary? health) {
    final weight = profile?.weightKg ?? health?.weightKg;
    final sodiumLimit = _sodiumLimit(profile);
    final sugarLimit = _sugarLimit(profile);
    final proteinTarget = _proteinTarget(profile, weight);
    final fiberTarget = _fiberTarget(profile);
    final waterTarget = weight == null ? 1800.0 : (weight * 30).clamp(1600.0, 2600.0).toDouble();
    return [
      NutritionBudgetItem(
        label: '蛋白质',
        unit: 'g',
        target: proteinTarget,
        consumed: review.totalProteinG,
        advice: profile?.conditions.contains('kidney_problem') == true ? '档案含肾脏问题，蛋白以适量为主，避免盲目高蛋白。' : '用于恢复、饱腹和维持肌肉，优先鸡蛋、豆腐、鱼肉、奶/豆浆。',
      ),
      NutritionBudgetItem(
        label: '膳食纤维',
        unit: 'g',
        target: fiberTarget,
        consumed: review.totalFiberG,
        advice: '便秘、脂肪肝和控糖都需要更稳定的蔬菜、全谷物、豆类和菌菇。',
      ),
      NutritionBudgetItem(
        label: '钠',
        unit: 'mg',
        limit: sodiumLimit,
        consumed: review.totalSodiumMg,
        advice: '高血压、肾脏问题或水肿风险时，优先少汤汁、少调料包、少腌制/加工肉。',
      ),
      NutritionBudgetItem(
        label: '添加糖/糖',
        unit: 'g',
        limit: sugarLimit,
        consumed: review.totalSugarG,
        advice: '疲劳时尤其容易靠甜饮硬撑，优先用早餐蛋白和稳定主食替代。',
      ),
      NutritionBudgetItem(
        label: '饮水',
        unit: 'ml',
        target: waterTarget,
        consumed: (health?.extraDouble('hydrationLiters') ?? 0) > 0 ? health!.extraDouble('hydrationLiters')! * 1000 : null,
        advice: '饮水不足会影响便秘、疲劳和部分结石风险；如果有医嘱限水，以医嘱为准。',
      ),
    ];
  }

  double? _proteinTarget(HealthProfile? profile, double? weightKg) {
    if (weightKg == null || weightKg <= 0) return null;
    if (profile?.conditions.contains('kidney_problem') == true) return weightKg * 0.8;
    if (profile?.mainGoal == 'muscle_gain') return weightKg * 1.4;
    if (profile?.mainGoal == 'restore_energy') return weightKg * 1.0;
    return weightKg * 0.9;
  }

  double _fiberTarget(HealthProfile? profile) {
    if (profile?.conditions.contains('constipation') == true) return 28;
    return 25;
  }

  double _sodiumLimit(HealthProfile? profile) {
    if (profile?.mainGoal == 'low_sodium' || profile?.conditions.contains('hypertension') == true || profile?.conditions.contains('kidney_problem') == true) return 1500;
    return 2000;
  }

  double _sugarLimit(HealthProfile? profile) {
    if (profile?.mainGoal == 'blood_sugar_friendly' || profile?.conditions.contains('fatty_liver') == true) return 25;
    return 36;
  }

  String _phase(DateTime now) {
    final m = now.hour * 60 + now.minute;
    if (m < 10 * 60 + 30) return '早餐/上午阶段';
    if (m < 14 * 60 + 30) return '午餐阶段';
    if (m < 17 * 60 + 30) return '下午加餐阶段';
    if (m < 21 * 60 + 30) return '晚餐阶段';
    return '晚间复盘阶段';
  }

  String _nextMeal(DateTime now) {
    final h = now.hour;
    if (h < 10) return '早餐';
    if (h < 14) return '午餐';
    if (h < 17) return '加餐';
    if (h < 21) return '晚餐';
    return '明日早餐';
  }

  String _nextBestAction(DailyDietReview review, HealthProfile? profile, HealthConnectDailySummary? health) {
    if (review.mainProblems.any((e) => e.contains('暂无足够记录'))) return '先记录并确认一餐真实食物；没有真实饮食数据时，Agent 只能给保守方案。';
    if (profile?.conditions.contains('kidney_problem') == true && review.mainProblems.any((e) => e.contains('蛋白'))) return '档案含肾脏问题，下一餐先选择“适量蛋白 + 低盐 + 蔬菜”，不要盲目高蛋白。';
    if (health?.stepsLow == true && review.mainProblems.any((e) => e.contains('高盐'))) return '活动量偏低且有高盐线索，下一餐先少汤汁/调料包，再加一份青菜。';
    return review.nextDayAdvice;
  }

  List<String> _riskFlags(DailyDietReview review, HealthProfile? profile, HealthConnectDailySummary? health) {
    final out = <String>[];
    out.addAll(review.mainProblems.where((e) => !e.contains('暂无')).take(4));
    if (profile?.conditions.contains('kidney_problem') == true) out.add('档案含肾脏问题：蛋白、钠、钾、磷建议保守，必要时以医生/营养师医嘱为准。');
    if (profile?.conditions.contains('fatty_liver') == true) out.add('档案含脂肪肝：甜饮、精制碳水、夜宵和总能量需要重点管理。');
    if (profile?.conditions.contains('constipation') == true) out.add('档案含便秘：纤维、水分和步行活动需要一起跟踪。');
    if (health?.sleepLow == true) out.add('睡眠偏少：今天更容易靠甜饮和重口味补偿，需提前安排稳定早餐/加餐。');
    return _unique(out).take(6).toList();
  }

  List<String> _unique(Iterable<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final value in values) {
      final v = value.trim();
      if (v.isEmpty) continue;
      if (seen.add(v)) out.add(v);
    }
    return out;
  }
}
