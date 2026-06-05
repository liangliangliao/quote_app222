import '../models/daily_diet_entry.dart';
import '../models/diet_habit_models.dart';
import '../repositories/daily_diet_entry_repository.dart';
import '../repositories/diet_habit_repository.dart';
import '../repositories/health_profile_repository.dart';
import 'diet_food_analysis_service.dart';
import 'diet_habit_pattern_service.dart';

class DietLongTermReportService {
  DietLongTermReportService({
    DailyDietEntryRepository? entryRepository,
    DietHabitRepository? habitRepository,
    DietFoodAnalysisService? analysisService,
    DietHabitPatternService? patternService,
  })  : _entryRepo = entryRepository ?? DailyDietEntryRepository(),
        _habitRepo = habitRepository ?? DietHabitRepository(),
        _analysis = analysisService ?? DietFoodAnalysisService(),
        _patternService = patternService ?? DietHabitPatternService();

  final DailyDietEntryRepository _entryRepo;
  final DietHabitRepository _habitRepo;
  final DietFoodAnalysisService _analysis;
  final DietHabitPatternService _patternService;

  Future<DietLongTermReport> buildReport({
    String userId = HealthProfileRepository.defaultUserId,
    int days = 7,
  }) async {
    final entries = await _entryRepo.recentEntries(userId: userId, limit: days * 8);
    final cutoff = DateTime.now().subtract(Duration(days: days - 1));
    final filtered = entries.where((entry) {
      final date = DateTime.tryParse(entry.entryDate);
      if (date == null) return true;
      return !date.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day));
    }).toList();

    final byDate = <String, List<DailyDietEntry>>{};
    for (final entry in filtered) {
      byDate.putIfAbsent(entry.entryDate, () => <DailyDietEntry>[]).add(entry);
    }

    final trendPoints = <DietTrendPoint>[];
    for (final date in byDate.keys) {
      final dayEntries = byDate[date]!;
      final foods = dayEntries.expand((e) => e.foods).toList();
      final summary = _analysis.summarize(foods, entries: dayEntries);
      final hasBreakfast = foods.any((f) => f.mealType == 'breakfast') || dayEntries.any((e) => e.mealType == 'breakfast');
      trendPoints.add(DietTrendPoint(
        date: date,
        entryCount: dayEntries.length,
        recoveryScore: summary.recoveryScore,
        proteinScore: summary.proteinScore,
        vegetableScore: summary.vegetableScore,
        fiberScore: summary.fiberScore,
        sugarRiskScore: summary.sugarRiskScore,
        sodiumRiskScore: summary.sodiumRiskScore,
        processedRiskScore: summary.ultraProcessedScore,
        hasBreakfast: hasBreakfast && !summary.skippedBreakfast,
      ));
    }
    trendPoints.sort((a, b) => a.date.compareTo(b.date));

    double avg(double Function(DietTrendPoint p) selector) {
      if (trendPoints.isEmpty) return 0;
      return trendPoints.map(selector).reduce((a, b) => a + b) / trendPoints.length;
    }

    final patternViews = _patternService.analyzeLastDays(filtered, days: days);
    await _habitRepo.replaceActivePatterns(patternViews, userId: userId);
    final persistedPatterns = await _habitRepo.activePatterns(userId: userId);
    final priorityAction = await _ensurePriorityAction(persistedPatterns, userId: userId);

    return DietLongTermReport(
      days: days,
      recordedDays: byDate.length,
      totalEntries: filtered.length,
      averageRecoveryScore: avg((p) => p.recoveryScore),
      averageProteinScore: avg((p) => p.proteinScore),
      averageVegetableScore: avg((p) => p.vegetableScore),
      averageFiberScore: avg((p) => p.fiberScore),
      averageSugarRisk: avg((p) => p.sugarRiskScore),
      averageSodiumRisk: avg((p) => p.sodiumRiskScore),
      averageProcessedRisk: avg((p) => p.processedRiskScore),
      breakfastDays: trendPoints.where((p) => p.hasBreakfast).length,
      trendPoints: trendPoints,
      patterns: persistedPatterns,
      priorityAction: priorityAction,
    );
  }

  Future<DietMicroAction?> _ensurePriorityAction(List<DietHabitPatternRecord> patterns, {required String userId}) async {
    final existing = await _habitRepo.latestActiveAction(userId: userId);
    if (existing != null) return existing;
    if (patterns.isEmpty) return null;
    final top = patterns.first;
    final action = _actionForPattern(top);
    final id = await _habitRepo.createMicroAction(
      userId: userId,
      actionTitle: action.title,
      actionReason: action.reason,
      relatedPattern: top.patternType,
      difficultyLevel: 'easy',
    );
    final actions = await _habitRepo.microActions(userId: userId, limit: 1);
    return actions.firstWhere((a) => a.id == id, orElse: () => DietMicroAction(
          id: id,
          userId: userId,
          actionDate: DateTime.now().toIso8601String().substring(0, 10),
          actionTitle: action.title,
          actionReason: action.reason,
          relatedPattern: top.patternType,
        ));
  }

  _ActionSuggestion _actionForPattern(DietHabitPatternRecord pattern) {
    switch (pattern.patternType) {
      case 'frequent_sweet_drinks':
        return const _ActionSuggestion('把下一杯奶茶改成小杯少糖', '先不要求完全戒掉甜饮，只把最容易执行的一杯改小、改少糖。');
      case 'high_sodium_days':
        return const _ActionSuggestion('下一次外卖少喝汤汁或调料减半', '这是降低高盐负担最容易执行的一步。');
      case 'ultra_processed_foods':
        return const _ActionSuggestion('用鸡蛋或豆腐替代一部分加工食品', '先给身体补上更稳定的蛋白质来源。');
      case 'low_protein':
        return const _ActionSuggestion('明天早餐加一个鸡蛋或一杯无糖豆浆', '恢复体力和饱腹感都需要稳定蛋白质。');
      case 'low_vegetable_fiber':
        return const _ActionSuggestion('明天任意一餐加一份青菜或菌菇', '先补一份蔬菜，比追求完美饮食更容易坚持。');
      case 'skip_breakfast':
        return const _ActionSuggestion('明天吃一个最小早餐', '鸡蛋、无糖豆浆、牛奶或香蕉任选一个即可。');
      default:
        return const _ActionSuggestion('明天只做一个小饮食改变', '先选择最容易执行的一点，不一次性改变所有问题。');
    }
  }
}


class _ActionSuggestion {
  const _ActionSuggestion(this.title, this.reason);
  final String title;
  final String reason;
}
