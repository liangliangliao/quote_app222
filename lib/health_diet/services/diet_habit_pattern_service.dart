import '../models/daily_diet_entry.dart';
import 'diet_food_analysis_service.dart';

class DietHabitPatternService {
  final DietFoodAnalysisService _analysis = DietFoodAnalysisService();

  List<DietHabitPatternView> analyzeLastDays(List<DailyDietEntry> entries, {int days = 7}) {
    if (entries.isEmpty) return const [];
    final byDate = <String, List<DailyDietEntry>>{};
    for (final entry in entries) {
      byDate.putIfAbsent(entry.entryDate, () => <DailyDietEntry>[]).add(entry);
    }

    int sugarDays = 0;
    int sodiumDays = 0;
    int processedDays = 0;
    int noProteinDays = 0;
    int noVegetableDays = 0;
    int skippedBreakfastDays = 0;
    final evidence = <String, List<String>>{};

    void addEvidence(String key, String value) => evidence.putIfAbsent(key, () => <String>[]).add(value);

    for (final date in byDate.keys) {
      final dayEntries = byDate[date]!;
      final foods = dayEntries.expand((e) => e.foods).toList();
      final summary = _analysis.summarize(foods, entries: dayEntries);
      final foodNames = foods.map((e) => e.foodName).where((e) => e.trim().isNotEmpty).take(5).join('、');
      final sample = '$date：${foodNames.isEmpty ? '有记录但未确认具体食物' : foodNames}';
      if (summary.hasSugar) {
        sugarDays++;
        addEvidence('sugar', sample);
      }
      if (summary.hasSodium) {
        sodiumDays++;
        addEvidence('sodium', sample);
      }
      if (summary.hasUltraProcessed) {
        processedDays++;
        addEvidence('processed', sample);
      }
      if (!summary.hasProtein) {
        noProteinDays++;
        addEvidence('protein', sample);
      }
      if (!summary.hasVegetable) {
        noVegetableDays++;
        addEvidence('vegetable', sample);
      }
      if (summary.skippedBreakfast) {
        skippedBreakfastDays++;
        addEvidence('breakfast', sample);
      }
    }

    final patterns = <DietHabitPatternView>[];
    void maybeAdd({
      required String type,
      required String name,
      required int count,
      required String impact,
      required String action,
      required String evidenceKey,
      int threshold = 2,
    }) {
      if (count < threshold) return;
      patterns.add(DietHabitPatternView(
        patternType: type,
        patternName: name,
        frequencyCount: count,
        evidence: (evidence[evidenceKey] ?? const []).take(4).toList(),
        impact: impact,
        microAction: action,
      ));
    }

    maybeAdd(
      type: 'frequent_sweet_drinks',
      name: '甜饮/高糖食物频繁',
      count: sugarDays,
      evidenceKey: 'sugar',
      impact: '容易让精力波动，也会挤占更有营养的饮食选择。',
      action: '下次先不完全戒，只把奶茶/甜饮改成小杯少糖，或换成无糖豆浆。',
    );
    maybeAdd(
      type: 'high_sodium_days',
      name: '高盐/重口味出现偏多',
      count: sodiumDays,
      evidenceKey: 'sodium',
      impact: '方便面、火腿肠、麻辣烫、外卖汤汁等容易让钠摄入偏高。',
      action: '吃泡面或外卖时先做一个小改变：少喝汤汁、调料减半、加一份青菜。',
    );
    maybeAdd(
      type: 'ultra_processed_foods',
      name: '加工食品出现偏多',
      count: processedDays,
      evidenceKey: 'processed',
      impact: '加工食品通常营养密度较低，更容易同时带来高盐、高油或高糖。',
      action: '下一次用“鸡蛋 + 青菜 + 主食”替代一部分加工食品。',
    );
    maybeAdd(
      type: 'low_protein',
      name: '优质蛋白来源不足',
      count: noProteinDays,
      evidenceKey: 'protein',
      impact: '恢复体力、运动恢复和饱腹感都需要稳定的蛋白质来源。',
      action: '明天早餐或午餐加一个鸡蛋、一杯牛奶/无糖豆浆、豆腐、鱼肉或鸡肉。',
    );
    maybeAdd(
      type: 'low_vegetable_fiber',
      name: '蔬菜水果和膳食纤维偏少',
      count: noVegetableDays,
      evidenceKey: 'vegetable',
      impact: '膳食纤维不足会影响饱腹感、肠道状态和饮食结构。',
      action: '明天只补一份：青菜、番茄、黄瓜、菌菇、南瓜或水果。',
    );
    maybeAdd(
      type: 'skip_breakfast',
      name: '早餐缺失',
      count: skippedBreakfastDays,
      evidenceKey: 'breakfast',
      impact: '早餐长期缺失时，后续更容易靠甜饮或重口味食物补偿。',
      action: '明天早餐先做到最小版本：鸡蛋或无糖豆浆任选一个。',
      threshold: 1,
    );

    patterns.sort((a, b) => b.frequencyCount.compareTo(a.frequencyCount));
    return patterns.take(5).toList();
  }
}

class DietHabitPatternView {
  const DietHabitPatternView({
    required this.patternType,
    required this.patternName,
    required this.frequencyCount,
    required this.evidence,
    required this.impact,
    required this.microAction,
  });

  final String patternType;
  final String patternName;
  final int frequencyCount;
  final List<String> evidence;
  final String impact;
  final String microAction;
}
