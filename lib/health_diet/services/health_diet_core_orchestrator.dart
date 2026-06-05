import '../models/daily_diet_entry.dart';
import '../models/normalized_food_item.dart';
import '../models/normalized_recipe.dart';
import '../repositories/food_item_repository.dart';
import 'diet_input_parser_service.dart';
import 'health_diet_ai_bridge_service.dart';
import 'health_diet_external_api_service.dart';

class HealthDietCoreOrchestrator {
  HealthDietCoreOrchestrator({
    DietInputParserService? parser,
    HealthDietAiBridgeService? ai,
    HealthDietExternalApiService? external,
    FoodItemRepository? foodRepo,
  })  : _parser = parser ?? DietInputParserService(),
        _ai = ai ?? HealthDietAiBridgeService(),
        _external = external ?? HealthDietExternalApiService(),
        _foodRepo = foodRepo ?? FoodItemRepository();

  final DietInputParserService _parser;
  final HealthDietAiBridgeService _ai;
  final HealthDietExternalApiService _external;
  final FoodItemRepository _foodRepo;

  Future<List<DetectedDietFood>> buildFoodsFromInputs({
    String? text,
    List<String> imagePaths = const [],
    String source = 'text',
  }) async {
    final merged = <DetectedDietFood>[];
    final local = _parser.parseText((text ?? '').trim(), source: source).toList();
    merged.addAll(local);

    if ((text ?? '').trim().isNotEmpty) {
      final aiText = await _ai.parseDietText(text!.trim(), source: source == 'voice' ? 'ai_voice' : 'ai_text');
      merged.addAll(aiText);
    }
    if (imagePaths.isNotEmpty) {
      final aiImage = await _ai.detectFoodsFromImages(imagePaths, extraText: text);
      merged.addAll(aiImage);
    }

    final deduped = _dedupe(merged);
    return _enrichFoods(deduped, imagePaths: imagePaths, extraContext: text);
  }

  Future<List<DetectedDietFood>> foodsFromBarcode(String barcode, {List<String> imagePaths = const []}) async {
    final value = barcode.trim();
    final products = await _external.lookupBarcodeCandidates(value);
    if (products.isNotEmpty) {
      final out = <DetectedDietFood>[];
      for (final product in products.take(6)) {
        final id = await _foodRepo.upsertFood(product);
        out.add(DetectedDietFood(
          foodName: _displayFood(product),
          normalizedFoodId: id,
          amountText: product.servingSizeG == null ? '1份' : '约${product.servingSizeG!.round()}g/1份',
          estimatedGrams: product.servingSizeG,
          mealType: 'unknown',
          confidenceScore: product.source.contains('open_food_facts') ? 0.95 : 0.86,
          source: product.source.contains('open_food_facts') ? 'open_food_facts_barcode' : '${product.source}_barcode',
        ));
      }
      return out;
    }

    if (imagePaths.isNotEmpty) {
      final aiFoods = await _ai.detectFoodsFromImages(
        imagePaths,
        extraText: '包装食品条形码：$value。Open Food Facts 未收录该条码，请只根据包装正面、配料表或营养成分表中清楚可见的信息识别食品名称；看不清时返回空数组。',
      );
      final enriched = await _enrichFoods(aiFoods.map((food) => food.copyWith(source: 'barcode_ai_image')).toList(), imagePaths: imagePaths, extraContext: '条形码：$value');
      if (enriched.isNotEmpty) return enriched;
    }

    return [
      DetectedDietFood(
        foodName: '条码未在公开库录入',
        amountText: '条形码：$value；请点此修改为真实食品名称，或返回上传包装正面/营养成分表照片后再识别',
        mealType: 'unknown',
        confidenceScore: 0.1,
        source: 'barcode_not_found',
      ),
    ];
  }

  Future<List<NormalizedRecipe>> searchOnlineRecipes(String query, {List<String>? healthTags, int limit = 8}) {
    return _external.searchRecipes(query, healthTags: healthTags, limit: limit);
  }

  Future<List<DetectedDietFood>> _enrichFoods(
    List<DetectedDietFood> foods, {
    List<String> imagePaths = const [],
    String? extraContext,
  }) async {
    final out = <DetectedDietFood>[];
    final unresolved = <DetectedDietFood>[];
    for (final food in foods) {
      if (food.normalizedFoodId != null) {
        out.add(food);
        continue;
      }
      final matches = await _external.searchFood(food.foodName, limit: 3);
      final normalized = _bestNutritionMatch(food, matches);
      if (normalized == null) {
        unresolved.add(food);
        out.add(food);
        continue;
      }
      final id = await _foodRepo.upsertFood(normalized);
      out.add(food.copyWith(
        normalizedFoodId: id,
        estimatedGrams: food.estimatedGrams ?? normalized.servingSizeG,
        source: '${food.source}+${normalized.source}',
      ));
    }

    if (unresolved.isEmpty) return out;

    // 外部营养库未命中时，再让 AI 做“保守营养粗估”。
    // AI 估算不替代 USDA/OFF/国内接口，但比 0 kcal 更适合后续复盘、健康目标差距与下一餐动态安排。
    final estimates = await _ai.estimateNutritionForFoods(unresolved, imagePaths: imagePaths, extraContext: extraContext);
    if (estimates.isEmpty) return out;
    final estimateByName = <String, NormalizedFoodItem>{};
    for (final item in estimates) {
      estimateByName[_norm(item.name)] = item;
    }
    for (var i = 0; i < out.length; i++) {
      final food = out[i];
      if (food.normalizedFoodId != null) continue;
      final estimate = estimateByName[_norm(food.foodName)] ?? _closestEstimate(food.foodName, estimates);
      if (estimate == null) continue;
      final id = await _foodRepo.upsertFood(estimate);
      out[i] = food.copyWith(
        normalizedFoodId: id,
        estimatedGrams: food.estimatedGrams ?? estimate.servingSizeG,
        source: '${food.source}+ai_nutrition_estimate',
      );
    }
    return out;
  }

  NormalizedFoodItem? _bestNutritionMatch(DetectedDietFood food, List<NormalizedFoodItem> matches) {
    if (matches.isEmpty) return null;
    NormalizedFoodItem? best;
    var bestScore = -1.0;
    for (final item in matches) {
      var score = 0.0;
      if (_norm(item.name) == _norm(food.foodName)) score += 4;
      if (_norm(item.name).contains(_norm(food.foodName)) || _norm(food.foodName).contains(_norm(item.name))) score += 2;
      if (item.caloriesKcal != null) score += 1;
      if (item.proteinG != null || item.carbsG != null || item.fatG != null) score += 1;
      if (item.source == 'usda') score += 0.8;
      if (item.source == 'open_food_facts') score += 0.4;
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return bestScore <= 0 ? null : best;
  }

  NormalizedFoodItem? _closestEstimate(String foodName, List<NormalizedFoodItem> estimates) {
    final key = _norm(foodName);
    for (final item in estimates) {
      final n = _norm(item.name);
      if (n == key || n.contains(key) || key.contains(n)) return item;
    }
    return estimates.length == 1 ? estimates.first : null;
  }

  String _norm(String value) => value.toLowerCase().replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[，,。.!！?？；;：:（）()]+'), '');

  List<DetectedDietFood> _dedupe(List<DetectedDietFood> foods) {
    final seen = <String>{};
    final out = <DetectedDietFood>[];
    for (final food in foods) {
      final name = food.foodName.trim();
      if (name.isEmpty) continue;
      final normalizedName = name.replaceAll(RegExp(r'\s+'), '');
      final amount = food.amountText ?? '';
      final key = '$normalizedName:${food.mealType}:$amount'.toLowerCase();
      if (seen.add(key)) out.add(food);
    }
    return out;
  }

  String _displayFood(NormalizedFoodItem item) {
    final brand = (item.brand ?? '').trim();
    return brand.isEmpty ? item.name : '${item.name}（$brand）';
  }
}
