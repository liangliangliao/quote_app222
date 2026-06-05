import 'dart:convert';
import 'dart:io';

import '../../services/unified_ai_service.dart';
import '../../utils/debug_logger.dart';
import '../models/daily_diet_entry.dart';
import '../models/normalized_food_item.dart';
import 'health_diet_settings_service.dart';

class HealthDietAiBridgeService {
  HealthDietAiBridgeService({UnifiedAiService? ai, HealthDietSettingsService? settings})
      : _ai = ai ?? UnifiedAiService(),
        _settings = settings ?? HealthDietSettingsService();

  final UnifiedAiService _ai;
  final HealthDietSettingsService _settings;

  Future<bool> get enabled async {
    final values = await _settings.load();
    return _settings.isEnabledValue(values[HealthDietSettingsService.aiAdviceEnabled]);
  }

  Future<List<DetectedDietFood>> parseDietText(String text, {String source = 'ai_text'}) async {
    if (text.trim().isEmpty || !await enabled) return const [];
    final prompt = '''
你是饮食记录解析助手。请把用户的自然语言饮食描述解析成结构化食物列表。
要求：
1. 不评价健康好坏，不给建议，只抽取用户明确提到的食物。
2. 不编造用户没说的食物。
3. 份量不明确时 amount_text 写空字符串；如果可估算克数，estimated_grams 写数字，否则写 null。
4. 餐次只允许 breakfast/lunch/dinner/snack/drink/unknown。
5. 输出严格 JSON，不要 Markdown。

用户输入：
$text

输出格式：
{"foods":[{"name":"","amount_text":"","estimated_grams":null,"meal_type":"unknown","cooking_method":"","confidence":0.8}]}
''';
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'health_diet.ai.parse_text',
        expectJson: true,
        maxTokens: 900,
        temperature: 0.1,
      );
      await DLog.i('health_diet.ai.parse_text', raw);
      return _foodsFromJson(raw, source: source);
    } catch (e, st) {
      await DLog.e('health_diet.ai.parse_text', 'AI text parse failed: $e\n$st');
      return const [];
    }
  }

  Future<List<DetectedDietFood>> detectFoodsFromImages(List<String> imagePaths, {String? extraText}) async {
    if (imagePaths.isEmpty || !await enabled) return const [];
    final parts = <UnifiedAiContentPart>[];
    for (final path in imagePaths.take(4)) {
      final dataUrl = await _imageToDataUrl(path);
      if (dataUrl != null) parts.add(UnifiedAiContentPart.imageUrl(dataUrl));
    }
    if (parts.isEmpty) return const [];
    final prompt = '''
你是饮食图片识别助手。请根据图片识别餐食、包装食品、营养成分表或配料表中能确认的食物。
要求：
1. 只输出你能从图片较有把握识别到的食物。
2. 不要把文件名、日期、说明文字当作食物。
3. 如果看不清，foods 返回空数组。
4. 份量不确定时 amount_text 写“约1份”或空字符串，confidence 低于0.5；如果能从图中大致估算份量，estimated_grams 写数字，否则写 null。
5. 如果图片里有多个食物，请尽量分别列出，不要把餐盘整体当作一个食物。
6. 餐次无法判断时 meal_type 写 unknown。
7. 输出严格 JSON，不要 Markdown。

用户补充描述：${extraText ?? ''}

输出格式：
{"foods":[{"name":"","amount_text":"","estimated_grams":null,"meal_type":"unknown","cooking_method":"","confidence":0.7}]}
''';
    try {
      final raw = await _ai.generateChatMessages(
        messages: [UnifiedAiChatMessage(role: 'user', content: prompt, parts: parts)],
        purpose: 'health_diet.ai.image_food_detection',
        maxTokens: 1000,
        temperature: 0.1,
      );
      await DLog.i('health_diet.ai.image_food_detection', raw);
      return _foodsFromJson(raw, source: 'ai_image');
    } catch (e, st) {
      await DLog.e('health_diet.ai.image_food_detection', 'AI image detection failed: $e\n$st');
      return const [];
    }
  }



  Future<List<NormalizedFoodItem>> estimateNutritionForFoods(
    List<DetectedDietFood> foods, {
    List<String> imagePaths = const [],
    String? extraContext,
  }) async {
    if (foods.isEmpty || !await enabled) return const [];
    final parts = <UnifiedAiContentPart>[];
    for (final path in imagePaths.take(3)) {
      final dataUrl = await _imageToDataUrl(path);
      if (dataUrl != null) parts.add(UnifiedAiContentPart.imageUrl(dataUrl));
    }
    final payload = foods.map((food) => {
      'name': food.foodName,
      'amount_text': food.amountText ?? '',
      'estimated_grams': food.estimatedGrams,
      'meal_type': food.mealType,
      'source': food.source,
      'confidence': food.confidenceScore,
    }).toList();
    final prompt = """
你是“AI 营养估算助手”。当 USDA/Open Food Facts/国内条码库没有命中时，请基于食物名称、份量描述和图片，对每个食物给出保守的营养粗估。

要求：
1. 只对输入 food_items 里的食物估算，不新增食物，不把图片背景物品当作食物。
2. 这是粗估，不是权威数据库；不确定时 confidence 降低，并写明 reason。
3. 所有营养值按“实际本次份量”估算，同时给出 estimated_grams。
4. calories_kcal/protein_g/fat_g/carbs_g/fiber_g/sugar_g/sodium_mg 必须是数字；无法判断时用 0 并降低 confidence。
5. 中文输出，严格 JSON，不要 Markdown。

输入食物：
${jsonEncode(payload)}

补充上下文：${extraContext ?? ''}

输出格式：
{
  "items":[
    {
      "name":"与输入食物名一致",
      "estimated_grams":100,
      "calories_kcal":0,
      "protein_g":0,
      "fat_g":0,
      "carbs_g":0,
      "fiber_g":0,
      "sugar_g":0,
      "sodium_mg":0,
      "confidence":0.45,
      "reason":"为什么只能粗估"
    }
  ]
}
""";
    try {
      final raw = await _ai.generateChatMessages(
        messages: [UnifiedAiChatMessage(role: 'user', content: prompt, parts: parts)],
        purpose: 'health_diet.ai.nutrition_estimate',
        maxTokens: 1500,
        temperature: 0.05,
      );
      await DLog.i('health_diet.ai.nutrition_estimate', raw);
      final jsonText = _extractJson(raw);
      if (jsonText.isEmpty) return const [];
      final decoded = jsonDecode(jsonText);
      final list = decoded is Map ? decoded['items'] : (decoded is List ? decoded : null);
      if (list is! List) return const [];
      return list.whereType<Map>().map((item) {
        final name = (item['name'] ?? '').toString().trim();
        if (name.isEmpty || _blockedNonFood(name)) return null;
        double? d(Object? v) => v is num ? v.toDouble() : double.tryParse((v ?? '').toString());
        final grams = d(item['estimated_grams']) ?? 100;
        final confidence = d(item['confidence']) ?? 0.35;
        final per100Factor = grams <= 0 ? 1.0 : 100.0 / grams;
        double per100(Object? value) {
          final n = d(value) ?? 0;
          return n * per100Factor;
        }
        return NormalizedFoodItem(
          source: 'ai_nutrition_estimate',
          sourceId: 'ai_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}',
          name: name,
          servingSizeG: grams,
          caloriesKcal: per100(item['calories_kcal']),
          proteinG: per100(item['protein_g']),
          fatG: per100(item['fat_g']),
          carbsG: per100(item['carbs_g']),
          fiberG: per100(item['fiber_g']),
          sugarG: per100(item['sugar_g']),
          sodiumMg: per100(item['sodium_mg']),
          healthTags: const ['ai_estimated'],
          dataQuality: 'ai_estimate_not_database',
          raw: {
            'ai_estimated': true,
            'estimated_for_actual_grams': grams,
            'confidence': confidence,
            'reason': (item['reason'] ?? '').toString(),
            'actual_values': item.map((key, value) => MapEntry(key.toString(), value)),
          },
        );
      }).whereType<NormalizedFoodItem>().toList();
    } catch (e, st) {
      await DLog.e('health_diet.ai.nutrition_estimate', 'AI nutrition estimate failed: $e\n$st');
      return const [];
    }
  }


  Future<Map<String, dynamic>?> reviewDietWithEvidence(DailyDietReview review, {Map<String, Object?> extraContext = const {}}) async {
    if (!await enabled) return null;
    final payload = <String, Object?>{
      'local_review': review.toEvidencePromptJson(),
      'extra_context': extraContext,
      'strict_rule': '只能基于 local_review 和 extra_context 分析，不允许编造未出现的食物、疾病或检测数据。数据不足时必须写入 data_gaps。',
    };
    final prompt = '''
你是“健康饮食复盘二次审查 Agent”。请审查本地复盘结果，补充更清晰的优先级和菜谱需求。

安全要求：
1. 不能诊断疾病，不能替代医生、营养师。
2. 只能基于输入 JSON 的证据链、营养估算、健康档案和 Health Connect 摘要分析。
3. 若证据不足，必须明确指出，不要伪精确。
4. 输出必须是严格 JSON，不要 Markdown。

输入数据：
${jsonEncode(payload)}

输出格式：
{
  "coach_summary":"一句话说明今天最关键的饮食模式，不超过80字",
  "priority_problems":["按重要性排序的问题，每条不超过60字"],
  "tomorrow_minimum_action":"明天最小可执行改变，不超过80字",
  "data_gaps":["仍缺少哪些关键数据"],
  "recipe_needs":[
    {
      "meal_type":"breakfast/lunch/dinner/any/post_workout",
      "goal":"low_sodium/high_protein/blood_sugar_friendly/fiber_boost/stomach_care/balanced",
      "query_text":"用于菜谱搜索的中文短语",
      "reason":"为什么需要这类菜谱",
      "prefer":["优先食材"],
      "avoid":["尽量避免"],
      "max_sodium_mg":600,
      "min_protein_g":20,
      "max_ready_minutes":25
    }
  ],
  "confidence_comment":"说明复盘可信度为什么是这个水平"
}
''';
    try {
      final raw = await _ai.generateText(
        prompt: prompt,
        purpose: 'health_diet.ai.review_evidence_agent',
        expectJson: true,
        maxTokens: 1400,
        temperature: 0.15,
      );
      await DLog.i('health_diet.ai.review_evidence_agent', raw);
      final jsonText = _extractJson(raw);
      if (jsonText.isEmpty) return null;
      final decoded = jsonDecode(jsonText);
      if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
      return null;
    } catch (e, st) {
      await DLog.e('health_diet.ai.review_evidence_agent', 'AI review failed: $e\n$st');
      return null;
    }
  }


  Future<String?> _imageToDataUrl(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final lower = path.toLowerCase();
      final mime = lower.endsWith('.png') ? 'image/png' : lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
  }

  List<DetectedDietFood> _foodsFromJson(String raw, {required String source}) {
    final jsonText = _extractJson(raw);
    if (jsonText.isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonText);
      final list = decoded is Map ? decoded['foods'] : (decoded is List ? decoded : null);
      if (list is! List) return const [];
      return list.whereType<Map>().map((item) {
        final name = (item['name'] ?? item['food_name'] ?? '').toString().trim();
        if (name.isEmpty || _blockedNonFood(name)) return null;
        return DetectedDietFood(
          foodName: name,
          amountText: (item['amount_text'] ?? item['amount'] ?? '').toString().trim().isEmpty ? null : (item['amount_text'] ?? item['amount']).toString().trim(),
          estimatedGrams: double.tryParse((item['estimated_grams'] ?? item['grams'] ?? '').toString()),
          mealType: _cleanMealType((item['meal_type'] ?? '').toString()),
          cookingMethod: (item['cooking_method'] ?? '').toString().trim().isEmpty ? null : (item['cooking_method'] ?? '').toString().trim(),
          confidenceScore: double.tryParse((item['confidence'] ?? '0.65').toString()) ?? 0.65,
          source: source,
        );
      }).whereType<DetectedDietFood>().toList();
    } catch (_) {
      return const [];
    }
  }

  String _extractJson(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false).firstMatch(text);
    final candidate = fenced?.group(1)?.trim() ?? text;
    final firstObj = candidate.indexOf('{');
    final lastObj = candidate.lastIndexOf('}');
    if (firstObj >= 0 && lastObj > firstObj) return candidate.substring(firstObj, lastObj + 1);
    final firstArr = candidate.indexOf('[');
    final lastArr = candidate.lastIndexOf(']');
    if (firstArr >= 0 && lastArr > firstArr) return candidate.substring(firstArr, lastArr + 1);
    return '';
  }

  String _cleanMealType(String raw) {
    final v = raw.trim().toLowerCase();
    const allowed = {'breakfast', 'lunch', 'dinner', 'snack', 'drink', 'unknown'};
    return allowed.contains(v) ? v : 'unknown';
  }

  bool _blockedNonFood(String name) {
    final n = name.trim();
    if (n.length <= 1) return true;
    return ['图片', '照片', '食物', '饮食', '记录', '明天', '明年', 'hello', 'HELLO'].contains(n);
  }
}
