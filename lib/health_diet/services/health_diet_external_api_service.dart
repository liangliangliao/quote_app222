import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/debug_logger.dart';
import '../../services/translation_service.dart';
import '../../utils/deepseek_logger.dart';
import '../models/normalized_food_item.dart';
import '../models/normalized_recipe.dart';
import 'health_diet_settings_service.dart';

class HealthDietExternalApiService {
  HealthDietExternalApiService({HealthDietSettingsService? settings, TranslationService? translation})
      : _settings = settings ?? HealthDietSettingsService(),
        _translation = translation ?? TranslationService();

  final HealthDietSettingsService _settings;
  final TranslationService _translation;

  Future<List<NormalizedFoodItem>> searchFood(String query, {int limit = 5}) async {
    final settings = await _settings.load();
    final source = (settings[HealthDietSettingsService.defaultFoodSource] ?? 'auto').trim();
    final merged = <NormalizedFoodItem>[];
    final queries = _foodApiQueries(query).take(4).toList();
    for (final apiQuery in queries) {
      final tasks = <Future<List<NormalizedFoodItem>>>[];
      if (source == 'boohee') {
        await DLog.w('health_diet.api.boohee.search', '薄荷健康 API 尚未接入正式开放接口，本次自动回退到 USDA / Open Food Facts。query=$apiQuery');
        tasks.add(_searchUsda(apiQuery, settings, limit: limit));
        tasks.add(_searchOpenFoodFacts(apiQuery, settings, limit: limit));
      } else {
        final autoLike = source == 'auto' || source == 'china_barcode_first';
        // “国内条码优先”只影响扫码流程；普通食物名称营养补全仍然回退到 USDA / Open Food Facts，避免图片/语音识别后完全没有营养数据。
        if (source == 'usda' || autoLike) tasks.add(_searchUsda(apiQuery, settings, limit: limit));
        if (source == 'open_food_facts' || autoLike) tasks.add(_searchOpenFoodFacts(apiQuery, settings, limit: limit));
      }
      for (final task in tasks) {
        try {
          merged.addAll(await task);
        } catch (_) {}
      }
      if (_dedupeFoods(merged).length >= limit) break;
    }
    return _dedupeFoods(merged).take(limit).toList();
  }


  Future<NormalizedFoodItem?> lookupBarcode(String barcode) async {
    final candidates = await lookupBarcodeCandidates(barcode);
    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  Future<List<NormalizedFoodItem>> lookupBarcodeCandidates(String barcode) async {
    final settings = await _settings.load();
    final value = barcode.trim();
    if (value.isEmpty) return const [];
    final chinaEnabled = _settings.isEnabledValue(settings[HealthDietSettingsService.chinaBarcodeEnabled]);
    final source = (settings[HealthDietSettingsService.defaultFoodSource] ?? 'auto').trim();
    final domesticFirst = source == 'china_barcode_first';
    final merged = <NormalizedFoodItem>[];

    Future<void> addOpenFoodFacts() async {
      final off = await _lookupOpenFoodFactsBarcode(value);
      if (off != null) merged.add(off);
    }

    Future<void> addDomestic() async {
      if (!chinaEnabled) return;
      merged.addAll(await _lookupDomesticBarcodeCandidates(value, settings));
    }

    if (domesticFirst) {
      await addDomestic();
      await addOpenFoodFacts();
    } else {
      await addOpenFoodFacts();
      await addDomestic();
    }
    return _dedupeFoods(merged).toList();
  }

  Future<NormalizedFoodItem?> _lookupOpenFoodFactsBarcode(String barcode) async {
    final settings = await _settings.load();
    final ua = _userAgent(settings);
    final value = barcode.trim();
    if (value.isEmpty) return null;
    final uri = Uri.https('world.openfoodfacts.org', '/api/v2/product/$value.json', {
      'fields': 'code,product_name,brands,categories,quantity,serving_size,nutriments,ingredients_text,allergens_tags,nutriscore_grade,nova_group,image_url,image_front_url,image_nutrition_url,selected_images',
    });
    try {
      await _logGetRequest('health_diet.api.open_food_facts.barcode', 'Open Food Facts', uri, {'User-Agent': ua, 'Accept': 'application/json'}, model: 'barcode_lookup');
      final resp = await http.get(uri, headers: {'User-Agent': ua, 'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      await _logHttpResponse('health_diet.api.open_food_facts.barcode', 'Open Food Facts', uri, resp, model: 'barcode_lookup');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['status'].toString() == '1') {
          final product = decoded['product'];
          if (product is Map) {
            final item = _foodFromOpenFoodFacts(product.cast<String, dynamic>(), value);
            if (_shouldLocalizeExternalApi(settings)) {
              return await _localizeFoodItem(item);
            }
            return item;
          }
        }
      } else if (resp.statusCode == 404) {
        await DLog.w('health_diet.api.open_food_facts.barcode', 'Open Food Facts 未收录该条码，不代表扫码失败：barcode=$value。准备尝试按 code 搜索兜底。');
      }

      final fallback = await _lookupBarcodeViaOpenFoodFactsSearch(value, settings);
      if (fallback != null) return fallback;
      return null;
    } catch (e, st) {
      await _logApiError('health_diet.api.open_food_facts.barcode', 'Open Food Facts', uri, e, st, model: 'barcode_lookup');
      return null;
    }
  }

  Future<NormalizedFoodItem?> _lookupBarcodeViaOpenFoodFactsSearch(String barcode, Map<String, String> settings) async {
    final ua = _userAgent(settings);
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': barcode,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '5',
      'fields': 'code,product_name,brands,categories,quantity,serving_size,nutriments,ingredients_text,allergens_tags,nutriscore_grade,nova_group,image_url,image_front_url,image_nutrition_url,selected_images',
    });
    try {
      await _logGetRequest('health_diet.api.open_food_facts.barcode_fallback_search', 'Open Food Facts', uri, {'User-Agent': ua, 'Accept': 'application/json'}, model: 'barcode_search_fallback');
      final resp = await http.get(uri, headers: {'User-Agent': ua, 'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      await _logHttpResponse('health_diet.api.open_food_facts.barcode_fallback_search', 'Open Food Facts', uri, resp, model: 'barcode_search_fallback');
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final decoded = jsonDecode(resp.body);
      final products = decoded is Map ? decoded['products'] : null;
      if (products is! List || products.isEmpty) return null;
      Map<String, dynamic>? exact;
      for (final item in products.whereType<Map>()) {
        final code = (item['code'] ?? '').toString().trim();
        if (code == barcode) {
          exact = item.cast<String, dynamic>();
          break;
        }
      }
      if (exact == null) return null;
      final item = _foodFromOpenFoodFacts(exact, barcode);
      if (_shouldLocalizeExternalApi(settings)) {
        return await _localizeFoodItem(item);
      }
      return item;
    } catch (e, st) {
      await _logApiError('health_diet.api.open_food_facts.barcode_fallback_search', 'Open Food Facts', uri, e, st, model: 'barcode_search_fallback');
      return null;
    }
  }


  Future<List<NormalizedFoodItem>> _lookupDomesticBarcodeCandidates(String barcode, Map<String, String> settings) async {
    final out = <NormalizedFoodItem>[];
    final juhe = await _lookupJuheBarcode(barcode, settings);
    if (juhe != null) out.add(juhe);
    final tanshu = await _lookupTanshuBarcode(barcode, settings, nutrition: false);
    if (tanshu != null) out.add(tanshu);
    final tanshuNutrition = await _lookupTanshuBarcode(barcode, settings, nutrition: true);
    if (tanshuNutrition != null) out.add(tanshuNutrition);
    final custom = await _lookupCustomChinaBarcode(barcode, settings);
    if (custom != null) out.add(custom);
    return out;
  }

  Future<NormalizedFoodItem?> _lookupJuheBarcode(String barcode, Map<String, String> settings) async {
    final key = (settings[HealthDietSettingsService.juheBarcodeApiKey] ?? '').trim();
    if (key.isEmpty) return null;
    final uri = Uri.https('apis.juhe.cn', '/barcode/query', {'key': key, 'barcode': barcode});
    try {
      await _logGetRequest('health_diet.api.juhe.barcode', '聚合数据条码查询', uri, {'Accept': 'application/json'}, redactedValues: [key], model: 'barcode_query');
      final resp = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      await _logHttpResponse('health_diet.api.juhe.barcode', '聚合数据条码查询', uri, resp, redactedValues: [key], model: 'barcode_query');
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final decoded = jsonDecode(resp.body);
      final item = _foodFromLooseBarcodePayload(decoded, source: 'juhe_barcode', barcode: barcode);
      if (item == null) return null;
      if (_shouldLocalizeExternalApi(settings)) return await _localizeFoodItem(item);
      return item;
    } catch (e, st) {
      await _logApiError('health_diet.api.juhe.barcode', '聚合数据条码查询', uri, e, st, redactedValues: [key], model: 'barcode_query');
      return null;
    }
  }

  Future<NormalizedFoodItem?> _lookupTanshuBarcode(String barcode, Map<String, String> settings, {required bool nutrition}) async {
    final token = (settings[HealthDietSettingsService.tanshuBarcodeToken] ?? '').trim();
    final url = (settings[nutrition ? HealthDietSettingsService.tanshuBarcodeNutritionUrl : HealthDietSettingsService.tanshuBarcodeBasicUrl] ?? '').trim();
    if (token.isEmpty || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final purpose = nutrition ? 'health_diet.api.tanshu.barcode_nutrition' : 'health_diet.api.tanshu.barcode_basic';
    try {
      final headers = {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
      final body = {'barcode': barcode};
      await _logHttpRequest(purpose, '探数数据条码查询', uri, headers, method: 'POST', body: body, redactedValues: [token], model: nutrition ? 'barcode_nutrition' : 'barcode_basic');
      final resp = await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
      await _logHttpResponse(purpose, '探数数据条码查询', uri, resp, redactedValues: [token], model: nutrition ? 'barcode_nutrition' : 'barcode_basic');
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final decoded = jsonDecode(resp.body);
      final item = _foodFromLooseBarcodePayload(decoded, source: nutrition ? 'tanshu_barcode_nutrition' : 'tanshu_barcode', barcode: barcode);
      if (item == null) return null;
      if (_shouldLocalizeExternalApi(settings)) return await _localizeFoodItem(item);
      return item;
    } catch (e, st) {
      await _logApiError(purpose, '探数数据条码查询', uri, e, st, redactedValues: [token], model: nutrition ? 'barcode_nutrition' : 'barcode_basic');
      return null;
    }
  }

  Future<NormalizedFoodItem?> _lookupCustomChinaBarcode(String barcode, Map<String, String> settings) async {
    final template = (settings[HealthDietSettingsService.chinaBarcodeApiUrlTemplate] ?? '').trim();
    if (template.isEmpty) return null;
    final key = (settings[HealthDietSettingsService.chinaBarcodeApiKey] ?? '').trim();
    final url = template.replaceAll('{barcode}', Uri.encodeComponent(barcode)).replaceAll('{key}', Uri.encodeComponent(key));
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final headerName = (settings[HealthDietSettingsService.chinaBarcodeApiHeaderName] ?? '').trim();
    final appCode = (settings[HealthDietSettingsService.chinaBarcodeAppCode] ?? '').trim();
    final headers = <String, String>{'Accept': 'application/json'};
    if (appCode.isNotEmpty) {
      headers['Authorization'] = 'APPCODE $appCode';
    } else if (headerName.isNotEmpty && key.isNotEmpty) {
      headers[headerName] = key;
    }
    try {
      await _logGetRequest('health_diet.api.china_barcode.custom', '自定义国内条码接口', uri, headers, redactedValues: [key, appCode], model: 'custom_barcode');
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
      await _logHttpResponse('health_diet.api.china_barcode.custom', '自定义国内条码接口', uri, resp, redactedValues: [key, appCode], model: 'custom_barcode');
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final decoded = jsonDecode(resp.body);
      final item = _foodFromLooseBarcodePayload(decoded, source: 'china_barcode_custom', barcode: barcode);
      if (item == null) return null;
      if (_shouldLocalizeExternalApi(settings)) return await _localizeFoodItem(item);
      return item;
    } catch (e, st) {
      await _logApiError('health_diet.api.china_barcode.custom', '自定义国内条码接口', uri, e, st, redactedValues: [key, appCode], model: 'custom_barcode');
      return null;
    }
  }

  NormalizedFoodItem? _foodFromLooseBarcodePayload(Object? decoded, {required String source, required String barcode}) {
    final data = _firstMeaningfulMap(decoded);
    if (data == null) return null;
    final name = _firstText(data, const ['goods_name', 'goodsName', 'product_name', 'productName', 'name', 'title', 'spuName', 'itemName', 'commodityName']);
    if (name == null || name.trim().isEmpty) return null;
    final brand = _firstText(data, const ['brand', 'brands', 'brandName', 'trademark', 'manufacturer', 'factory', 'company']);
    final category = _firstText(data, const ['category', 'categories', 'type', 'classify', 'goodsType']);
    final image = _firstText(data, const ['image', 'image_url', 'img', 'pic', 'picture', 'logo', 'goods_img', 'goodsImage']);
    final ingredientsText = _firstText(data, const ['ingredients', 'ingredient', 'ingredients_text', 'material', '配料表']);
    final ingredients = ingredientsText == null ? const <String>[] : ingredientsText.split(RegExp(r'[,，、;；]')).map((e) => e.trim()).where((e) => e.isNotEmpty).take(40).toList();
    final calories = _firstDouble(data, const ['energy_kcal', 'calories', 'calorie', 'kcal', '能量']);
    final protein = _firstDouble(data, const ['protein_g', 'protein', '蛋白质']);
    final fat = _firstDouble(data, const ['fat_g', 'fat', '脂肪']);
    final carbs = _firstDouble(data, const ['carbs_g', 'carbohydrate', 'carbohydrates', '碳水化合物']);
    final sodium = _firstDouble(data, const ['sodium_mg', 'sodium', 'natrium', '钠']);
    final sugar = _firstDouble(data, const ['sugar_g', 'sugar', 'sugars', '糖']);
    final fiber = _firstDouble(data, const ['fiber_g', 'fiber', '膳食纤维']);
    final rawWithImage = Map<String, dynamic>.from(data);
    if (image != null && (image.startsWith('http://') || image.startsWith('https://'))) {
      rawWithImage['image_url'] = image;
    }
    rawWithImage['barcode_provider'] = source;
    return NormalizedFoodItem(
      source: source,
      sourceId: '${source}_$barcode',
      name: name.trim(),
      brand: brand,
      barcode: barcode,
      category: category,
      imageUrl: image != null && (image.startsWith('http://') || image.startsWith('https://')) ? image : null,
      servingSizeG: 100,
      caloriesKcal: calories,
      proteinG: protein,
      fatG: fat,
      carbsG: carbs,
      fiberG: fiber,
      sugarG: sugar,
      sodiumMg: sodium,
      ingredients: ingredients,
      healthTags: _healthTagsFromNutrients(protein: protein, fiber: fiber, sugar: sugar, sodium: sodium),
      dataQuality: '${source}_barcode_payload',
      raw: rawWithImage,
    );
  }

  Map<String, dynamic>? _firstMeaningfulMap(Object? value) {
    if (value is Map) {
      final map = value.map((key, value) => MapEntry(key.toString(), value));
      for (final key in const ['result', 'data', 'showapi_res_body', 'goods', 'product', 'item', 'info']) {
        final child = map[key];
        final found = _firstMeaningfulMap(child);
        if (found != null && _firstText(found, const ['goods_name', 'goodsName', 'product_name', 'productName', 'name', 'title', 'spuName', 'itemName', 'commodityName']) != null) return found;
      }
      if (_firstText(map, const ['goods_name', 'goodsName', 'product_name', 'productName', 'name', 'title', 'spuName', 'itemName', 'commodityName']) != null) return map;
      for (final child in map.values) {
        final found = _firstMeaningfulMap(child);
        if (found != null) return found;
      }
    }
    if (value is List) {
      for (final child in value) {
        final found = _firstMeaningfulMap(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _firstText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = _findValue(map, key);
      if (v == null) continue;
      final text = v.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  double? _firstDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = _findValue(map, key);
      final d = _toDouble(v);
      if (d != null) return d;
    }
    return null;
  }

  Object? _findValue(Object? node, String key) {
    if (node is Map) {
      for (final entry in node.entries) {
        if (entry.key.toString().toLowerCase() == key.toLowerCase()) return entry.value;
      }
      for (final value in node.values) {
        final found = _findValue(value, key);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findValue(value, key);
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<List<NormalizedRecipe>> searchRecipes(String query, {List<String>? healthTags, int limit = 8}) async {
    final settings = await _settings.load();
    final source = (settings[HealthDietSettingsService.defaultRecipeSource] ?? 'auto').trim();
    final queries = _recipeApiQueries(query, healthTags: healthTags).take(2).toList();
    final merged = <NormalizedRecipe>[];
    for (final apiQuery in queries) {
      final tasks = <Future<List<NormalizedRecipe>>>[];
      if (source == 'spoonacular' || source == 'auto') tasks.add(_searchSpoonacular(apiQuery, settings, limit: limit));
      if (source == 'edamam' || source == 'auto') tasks.add(_searchEdamam(apiQuery, settings, healthTags: healthTags, limit: limit));
      for (final task in tasks) {
        try {
          merged.addAll(await task);
        } catch (_) {}
      }
      if (_dedupeRecipes(merged).length >= limit) break;
    }
    return _dedupeRecipes(merged).take(limit).toList();
  }

  Future<List<NormalizedFoodItem>> _searchUsda(String query, Map<String, String> settings, {int limit = 5}) async {
    final key = (settings[HealthDietSettingsService.usdaApiKey] ?? '').trim();
    if (key.isEmpty) {
      await DLog.w('health_diet.api.usda.search', 'USDA API Key 未配置，已跳过请求。query=$query');
      return const [];
    }

    // USDA FoodData Central 的 foods/search GET 在某些网关环境下会因为
    // dataType=Foundation,SR Legacy,Survey (FNDDS),Branded 这类包含空格、括号、逗号的
    // 组合参数返回 nginx 400。这里优先改用官方同时支持的 POST JSON 请求，把 dataType
    // 作为数组提交；如果 POST 仍失败，再自动降级为不带 dataType 的 GET，避免“接口成功配置但页面无数据”。
    final postUri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {'api_key': key});
    try {
      final body = <String, Object?>{
        'query': query,
        'pageSize': limit,
        'dataType': const ['Foundation', 'SR Legacy', 'Survey (FNDDS)', 'Branded'],
      };
      await _logHttpRequest(
        'health_diet.api.usda.search',
        'USDA FoodData Central',
        postUri,
        {'Accept': 'application/json', 'Content-Type': 'application/json'},
        method: 'POST',
        body: body,
        redactedValues: [key],
        model: 'foods_search',
      );
      final resp = await http
          .post(
            postUri,
            headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      await _logHttpResponse('health_diet.api.usda.search', 'USDA FoodData Central', postUri, resp, redactedValues: [key], model: 'foods_search');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final parsed = await _parseUsdaFoodResponse(resp.body, localize: _shouldLocalizeExternalApi(settings));
        if (parsed.isNotEmpty) return parsed.take(limit).toList();
      }
      await DLog.w('health_diet.api.usda.search', 'USDA POST 未返回可用数据，准备降级 GET：status=${resp.statusCode}, query=$query');
    } catch (e, st) {
      await _logApiError('health_diet.api.usda.search', 'USDA FoodData Central', postUri, e, st, redactedValues: [key], model: 'foods_search');
    }

    final fallbackUri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
      'api_key': key,
      'query': query,
      'pageSize': '$limit',
    });
    try {
      await _logGetRequest('health_diet.api.usda.search.fallback', 'USDA FoodData Central', fallbackUri, {'Accept': 'application/json'}, redactedValues: [key], model: 'foods_search_get_no_data_type');
      final resp = await http.get(fallbackUri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      await _logHttpResponse('health_diet.api.usda.search.fallback', 'USDA FoodData Central', fallbackUri, resp, redactedValues: [key], model: 'foods_search_get_no_data_type');
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final parsed = await _parseUsdaFoodResponse(resp.body, localize: _shouldLocalizeExternalApi(settings));
      return parsed.take(limit).toList();
    } catch (e, st) {
      await _logApiError('health_diet.api.usda.search.fallback', 'USDA FoodData Central', fallbackUri, e, st, redactedValues: [key], model: 'foods_search_get_no_data_type');
      return const [];
    }
  }

  Future<List<NormalizedFoodItem>> _parseUsdaFoodResponse(String body, {bool localize = true}) async {
    final decoded = jsonDecode(body);
    final foods = decoded is Map ? decoded['foods'] : null;
    if (foods is! List) return const [];
    final items = foods.whereType<Map>().map((e) => _foodFromUsda(e.cast<String, dynamic>())).where((e) => e.name.trim().isNotEmpty).toList();
    if (localize) {
      return await _localizeFoodItems(items);
    }
    return items;
  }

  Future<List<NormalizedFoodItem>> _searchOpenFoodFacts(String query, Map<String, String> settings, {int limit = 5}) async {
    final ua = _userAgent(settings);
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '$limit',
      'fields': 'code,product_name,brands,categories,quantity,serving_size,nutriments,ingredients_text,allergens_tags,nutriscore_grade,nova_group,image_url,image_front_url,image_nutrition_url,selected_images',
    });
    try {
      await _logGetRequest('health_diet.api.open_food_facts.search', 'Open Food Facts', uri, {'User-Agent': ua, 'Accept': 'application/json'}, model: 'products_search');
      final resp = await http.get(uri, headers: {'User-Agent': ua, 'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      await _logHttpResponse('health_diet.api.open_food_facts.search', 'Open Food Facts', uri, resp, model: 'products_search');
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final decoded = jsonDecode(resp.body);
      final products = decoded is Map ? decoded['products'] : null;
      if (products is! List) return const [];
      final items = products.whereType<Map>().map((e) => _foodFromOpenFoodFacts(e.cast<String, dynamic>(), e['code']?.toString())).where((e) => e.name.trim().isNotEmpty).toList();
      if (_shouldLocalizeExternalApi(settings)) {
        return await _localizeFoodItems(items);
      }
      return items;
    } catch (e, st) {
      await _logApiError('health_diet.api.open_food_facts.search', 'Open Food Facts', uri, e, st, model: 'products_search');
      return const [];
    }
  }

  Future<List<NormalizedRecipe>> _searchSpoonacular(String query, Map<String, String> settings, {int limit = 8}) async {
    final key = (settings[HealthDietSettingsService.spoonacularApiKey] ?? '').trim();
    if (key.isEmpty) {
      await DLog.w('health_diet.api.spoonacular.search', 'Spoonacular API Key 未配置，已跳过请求。query=$query');
      return const [];
    }
    final uri = Uri.https('api.spoonacular.com', '/recipes/complexSearch', {
      'apiKey': key,
      'query': query,
      'number': '$limit',
      'addRecipeInformation': 'true',
      'addRecipeNutrition': 'true',
      'instructionsRequired': 'false',
      'fillIngredients': 'true',
    });
    try {
      await _logGetRequest('health_diet.api.spoonacular.search', 'Spoonacular', uri, {'Accept': 'application/json'}, redactedValues: [key], model: 'complexSearch');
      final resp = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      await _logHttpResponse('health_diet.api.spoonacular.search', 'Spoonacular', uri, resp, redactedValues: [key], model: 'complexSearch');
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final decoded = jsonDecode(resp.body);
      final results = decoded is Map ? decoded['results'] : null;
      if (results is! List) return const [];
      final recipes = results.whereType<Map>().map((e) => _recipeFromSpoonacular(e.cast<String, dynamic>())).where((e) => e.title.trim().isNotEmpty).toList();
      if (_shouldLocalizeExternalApi(settings)) {
        return await _localizeRecipes(recipes);
      }
      return recipes;
    } catch (e, st) {
      await _logApiError('health_diet.api.spoonacular.search', 'Spoonacular', uri, e, st, redactedValues: [key], model: 'complexSearch');
      return const [];
    }
  }

  Future<List<NormalizedRecipe>> _searchEdamam(String query, Map<String, String> settings, {List<String>? healthTags, int limit = 8}) async {
    final appId = (settings[HealthDietSettingsService.edamamAppId] ?? '').trim();
    final appKey = (settings[HealthDietSettingsService.edamamAppKey] ?? '').trim();
    if (appId.isEmpty || appKey.isEmpty) {
      await DLog.w('health_diet.api.edamam.search', 'Edamam App ID 或 App Key 未配置，已跳过请求。query=$query');
      return const [];
    }
    final params = <String, String>{
      'type': 'public',
      'q': query,
      'app_id': appId,
      'app_key': appKey,
      'random': 'false',
    };
    for (final tag in _edamamHealthTags(healthTags ?? const [])) {
      params['health'] = tag;
      break;
    }
    final uri = Uri.https('api.edamam.com', '/api/recipes/v2', params);
    try {
      await _logGetRequest('health_diet.api.edamam.search', 'Edamam', uri, {'Accept': 'application/json', 'Edamam-Account-User': 'quote_app_local_user'}, redactedValues: [appKey, appId], model: 'recipe_search_v2');
      final resp = await http.get(uri, headers: {'Accept': 'application/json', 'Edamam-Account-User': 'quote_app_local_user'}).timeout(const Duration(seconds: 20));
      await _logHttpResponse('health_diet.api.edamam.search', 'Edamam', uri, resp, redactedValues: [appKey, appId], model: 'recipe_search_v2');
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final decoded = jsonDecode(resp.body);
      final hits = decoded is Map ? decoded['hits'] : null;
      if (hits is! List) return const [];
      final recipes = hits.whereType<Map>().map((e) => _recipeFromEdamam((e['recipe'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{})).where((e) => e.title.trim().isNotEmpty).take(limit).toList();
      if (_shouldLocalizeExternalApi(settings)) {
        return await _localizeRecipes(recipes);
      }
      return recipes;
    } catch (e, st) {
      await _logApiError('health_diet.api.edamam.search', 'Edamam', uri, e, st, redactedValues: [appKey, appId], model: 'recipe_search_v2');
      return const [];
    }
  }

  NormalizedFoodItem _foodFromUsda(Map<String, dynamic> food) {
    double? nutrient(List<String> names) {
      final list = food['foodNutrients'];
      if (list is! List) return null;
      for (final item in list.whereType<Map>()) {
        final name = (item['nutrientName'] ?? item['name'] ?? '').toString().toLowerCase();
        if (names.any((n) => name.contains(n.toLowerCase()))) {
          return _toDouble(item['value'] ?? item['amount']);
        }
      }
      return null;
    }

    final id = (food['fdcId'] ?? '').toString();
    return NormalizedFoodItem(
      source: 'usda',
      sourceId: id,
      name: (food['description'] ?? food['lowercaseDescription'] ?? '').toString(),
      brand: (food['brandOwner'] ?? food['brandName'])?.toString(),
      category: food['foodCategory']?.toString(),
      imageUrl: _imageUrlFromExternalRaw(food),
      servingSizeG: _toDouble(food['servingSize']) ?? 100,
      caloriesKcal: nutrient(['Energy']),
      proteinG: nutrient(['Protein']),
      fatG: nutrient(['Total lipid', 'Total fat']),
      carbsG: nutrient(['Carbohydrate']),
      fiberG: nutrient(['Fiber']),
      sugarG: nutrient(['Sugars']),
      sodiumMg: nutrient(['Sodium']),
      saturatedFatG: nutrient(['Fatty acids, total saturated', 'Saturated']),
      healthTags: _healthTagsFromNutrients(protein: nutrient(['Protein']), fiber: nutrient(['Fiber']), sugar: nutrient(['Sugars']), sodium: nutrient(['Sodium'])),
      dataQuality: 'official_usda_per_100g',
      raw: food,
    );
  }


  String? _imageUrlFromExternalRaw(Map<String, dynamic> raw) {
    for (final key in const ['image_url', 'image_front_url', 'image_nutrition_url']) {
      final v = raw[key]?.toString().trim();
      if (v != null && (v.startsWith('http://') || v.startsWith('https://'))) return v;
    }
    final images = raw['images'];
    if (images is Map) {
      for (final key in const ['REGULAR', 'SMALL', 'THUMBNAIL']) {
        final obj = images[key];
        if (obj is Map) {
          final v = obj['url']?.toString().trim();
          if (v != null && (v.startsWith('http://') || v.startsWith('https://'))) return v;
        }
      }
    }
    final selected = raw['selected_images'];
    if (selected is Map) {
      final front = selected['front'];
      if (front is Map) {
        final display = front['display'];
        if (display is Map) {
          final v = (display['zh'] ?? display['en'])?.toString().trim();
          if (v != null && (v.startsWith('http://') || v.startsWith('https://'))) return v;
        }
      }
    }
    return null;
  }

  NormalizedFoodItem _foodFromOpenFoodFacts(Map<String, dynamic> product, String? barcode) {
    final nutriments = (product['nutriments'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    double? n(String key) => _toDouble(nutriments['${key}_100g'] ?? nutriments[key]);
    final ingredients = (product['ingredients_text'] ?? '').toString().split(RegExp(r'[,，、;；]')).map((e) => e.trim()).where((e) => e.isNotEmpty).take(40).toList();
    final allergens = product['allergens_tags'] is List ? (product['allergens_tags'] as List).map((e) => e.toString()).toList() : const <String>[];
    final protein = n('proteins');
    final fiber = n('fiber');
    final sugar = n('sugars');
    final sodium = (n('sodium') != null) ? n('sodium')! * 1000 : n('salt');
    final nova = _toDouble(product['nova_group']);
    return NormalizedFoodItem(
      source: 'open_food_facts',
      sourceId: (product['code'] ?? barcode ?? '').toString(),
      name: (product['product_name'] ?? '').toString(),
      brand: product['brands']?.toString(),
      barcode: barcode ?? product['code']?.toString(),
      category: product['categories']?.toString(),
      imageUrl: _imageUrlFromExternalRaw(product),
      servingSizeG: _parseServing(product['serving_size']?.toString()),
      caloriesKcal: n('energy-kcal') ?? ((n('energy') != null) ? n('energy')! / 4.184 : null),
      proteinG: protein,
      fatG: n('fat'),
      carbsG: n('carbohydrates'),
      fiberG: fiber,
      sugarG: sugar,
      sodiumMg: sodium,
      saturatedFatG: n('saturated-fat'),
      allergens: allergens,
      ingredients: ingredients,
      healthTags: [
        ..._healthTagsFromNutrients(protein: protein, fiber: fiber, sugar: sugar, sodium: sodium),
        if (nova != null && nova >= 4) 'ultra_processed',
        if ((product['nutriscore_grade'] ?? '').toString().isNotEmpty) 'nutriscore_${product['nutriscore_grade']}',
      ],
      dataQuality: 'community_open_food_facts_per_100g',
      raw: product,
    );
  }

  NormalizedRecipe _recipeFromSpoonacular(Map<String, dynamic> item) {
    final nutrition = (item['nutrition'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final nutrients = nutrition['nutrients'] is List ? nutrition['nutrients'] as List : const [];
    double? nutrient(String name) {
      for (final n in nutrients.whereType<Map>()) {
        if ((n['name'] ?? '').toString().toLowerCase() == name.toLowerCase()) return _toDouble(n['amount']);
      }
      return null;
    }

    final ingredients = item['extendedIngredients'] is List
        ? (item['extendedIngredients'] as List).whereType<Map>().map((e) => (e['original'] ?? e['name'] ?? '').toString()).where((e) => e.trim().isNotEmpty).toList()
        : const <String>[];
    final instructions = <String>[];
    final analyzed = item['analyzedInstructions'];
    if (analyzed is List) {
      for (final group in analyzed.whereType<Map>()) {
        final steps = group['steps'];
        if (steps is List) instructions.addAll(steps.whereType<Map>().map((e) => (e['step'] ?? '').toString()).where((e) => e.trim().isNotEmpty));
      }
    }
    return NormalizedRecipe(
      source: 'spoonacular',
      sourceId: (item['id'] ?? '').toString(),
      title: (item['title'] ?? '').toString(),
      imageUrl: item['image']?.toString(),
      ingredients: ingredients,
      steps: instructions,
      healthTags: _recipeTagsFromNutrition(protein: nutrient('Protein'), fiber: nutrient('Fiber'), sodium: nutrient('Sodium'), sugar: nutrient('Sugar')),
      dietTags: [if (item['vegetarian'] == true) 'vegetarian', if (item['vegan'] == true) 'vegan', if (item['glutenFree'] == true) 'gluten_free'],
      cautions: const [],
      caloriesKcal: nutrient('Calories'),
      proteinG: nutrient('Protein'),
      fatG: nutrient('Fat'),
      carbsG: nutrient('Carbohydrates'),
      sodiumMg: nutrient('Sodium'),
      readyMinutes: int.tryParse((item['readyInMinutes'] ?? '').toString()),
      servings: int.tryParse((item['servings'] ?? '').toString()),
      dataQuality: 'spoonacular_api',
      raw: item,
    );
  }

  NormalizedRecipe _recipeFromEdamam(Map<String, dynamic> recipe) {
    final nutrients = (recipe['totalNutrients'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    double? nutrient(String key) => _toDouble((nutrients[key] as Map?)?['quantity']);
    final calories = _toDouble(recipe['calories']);
    final yieldValue = _toDouble(recipe['yield']);
    double? perServing(double? value) => (value != null && yieldValue != null && yieldValue > 0) ? value / yieldValue : value;
    return NormalizedRecipe(
      source: 'edamam',
      sourceId: (recipe['uri'] ?? recipe['url'] ?? recipe['label'] ?? '').toString(),
      title: (recipe['label'] ?? '').toString(),
      imageUrl: _imageUrlFromExternalRaw(recipe) ?? recipe['image']?.toString(),
      ingredients: recipe['ingredientLines'] is List ? (recipe['ingredientLines'] as List).map((e) => e.toString()).toList() : const [],
      steps: recipe['url'] == null ? const [] : ['查看原始菜谱网页：${recipe['url']}'],
      healthTags: recipe['healthLabels'] is List ? (recipe['healthLabels'] as List).map((e) => e.toString()).toList() : const [],
      dietTags: recipe['dietLabels'] is List ? (recipe['dietLabels'] as List).map((e) => e.toString()).toList() : const [],
      cautions: recipe['cautions'] is List ? (recipe['cautions'] as List).map((e) => e.toString()).toList() : const [],
      caloriesKcal: perServing(calories),
      proteinG: perServing(nutrient('PROCNT')),
      fatG: perServing(nutrient('FAT')),
      carbsG: perServing(nutrient('CHOCDF')),
      sodiumMg: perServing(nutrient('NA')),
      readyMinutes: int.tryParse((recipe['totalTime'] ?? '').toString()),
      servings: yieldValue?.round(),
      dataQuality: 'edamam_api',
      raw: recipe,
    );
  }

  bool _shouldLocalizeExternalApi(Map<String, String> settings) {
    // 外部健康平台返回英文时可以用 AI 翻译，但不能复用“AI 饮食建议”总开关。
    // 自动托管、菜谱搜索、营养补全会批量调用 USDA/Open Food Facts/Spoonacular/Edamam，
    // 如果每个标题/食材/步骤都调用一次 AI 翻译，会造成日志风暴、页面长时间转圈和 token 快速消耗。
    // 因此单独使用一个默认关闭的开关，用户确实需要少量手动查询中文化时再开启。
    return _settings.isEnabledValue(settings[HealthDietSettingsService.externalApiAiTranslationEnabled]);
  }

  Future<List<NormalizedFoodItem>> _localizeFoodItems(List<NormalizedFoodItem> items) async {
    if (items.isEmpty) return items;
    final out = <NormalizedFoodItem>[];
    for (final item in items) {
      out.add(await _localizeFoodItem(item));
    }
    return out;
  }

  Future<NormalizedFoodItem> _localizeFoodItem(NormalizedFoodItem item) async {
    final name = await _translateToChineseIfNeeded(item.name);
    final brand = item.brand == null ? null : await _translateToChineseIfNeeded(item.brand!);
    final category = item.category == null ? null : await _translateToChineseIfNeeded(item.category!);
    final ingredients = await _translateListToChineseIfNeeded(item.ingredients, maxItems: 12);
    return NormalizedFoodItem(
      id: item.id,
      source: item.source,
      sourceId: item.sourceId,
      name: name,
      brand: brand,
      barcode: item.barcode,
      category: category,
      imageUrl: item.imageUrl,
      servingSizeG: item.servingSizeG,
      caloriesKcal: item.caloriesKcal,
      proteinG: item.proteinG,
      fatG: item.fatG,
      carbsG: item.carbsG,
      fiberG: item.fiberG,
      sugarG: item.sugarG,
      sodiumMg: item.sodiumMg,
      saturatedFatG: item.saturatedFatG,
      allergens: item.allergens,
      ingredients: ingredients,
      healthTags: item.healthTags,
      dataQuality: item.dataQuality.contains('ai_zh') ? item.dataQuality : '${item.dataQuality}_ai_zh',
      raw: item.raw,
    );
  }

  Future<List<NormalizedRecipe>> _localizeRecipes(List<NormalizedRecipe> recipes) async {
    if (recipes.isEmpty) return recipes;
    final out = <NormalizedRecipe>[];
    for (final recipe in recipes) {
      out.add(await _localizeRecipe(recipe));
    }
    return out;
  }

  Future<NormalizedRecipe> _localizeRecipe(NormalizedRecipe recipe) async {
    final title = await _translateToChineseIfNeeded(recipe.title);
    final ingredients = await _translateListToChineseIfNeeded(recipe.ingredients, maxItems: 16);
    final steps = await _translateListToChineseIfNeeded(recipe.steps, maxItems: 10);
    final cautions = await _translateListToChineseIfNeeded(recipe.cautions, maxItems: 8);
    return NormalizedRecipe(
      source: recipe.source,
      sourceId: recipe.sourceId,
      title: title,
      imageUrl: recipe.imageUrl,
      ingredients: ingredients,
      steps: steps,
      healthTags: recipe.healthTags,
      dietTags: recipe.dietTags,
      cautions: cautions,
      caloriesKcal: recipe.caloriesKcal,
      proteinG: recipe.proteinG,
      fatG: recipe.fatG,
      carbsG: recipe.carbsG,
      sodiumMg: recipe.sodiumMg,
      readyMinutes: recipe.readyMinutes,
      servings: recipe.servings,
      dataQuality: recipe.dataQuality.contains('ai_zh') ? recipe.dataQuality : '${recipe.dataQuality}_ai_zh',
      raw: recipe.raw,
    );
  }

  Future<List<String>> _translateListToChineseIfNeeded(List<String> values, {int maxItems = 12}) async {
    if (values.isEmpty) return values;
    final out = <String>[];
    for (var i = 0; i < values.length; i++) {
      if (i >= maxItems) {
        out.add(values[i]);
        continue;
      }
      out.add(await _translateToChineseIfNeeded(values[i]));
    }
    return out;
  }

  Future<String> _translateToChineseIfNeeded(String text) async {
    final value = text.trim();
    if (value.isEmpty) return text;
    if (!_looksLikeForeignDisplayText(value)) return text;
    try {
      final translated = await _translation.translateOne(text: value, target: 'zh');
      final clean = translated.trim();
      if (clean.isNotEmpty && clean != value) return clean;
    } catch (e, st) {
      await DLog.w('health_diet.api.ai_translate', '外部健康数据中文化失败，已保留原文：$value; error=$e');
    }
    return text;
  }

  bool _looksLikeForeignDisplayText(String value) {
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(value)) return false;
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) return false;
    // URL、纯 ID、长原始 JSON 段不翻译。
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return false;
    if (value.length > 260) return false;
    return true;
  }

  List<String> _edamamHealthTags(List<String> tags) {
    final mapped = <String>[];
    if (tags.contains('low_sodium')) mapped.add('low-sodium');
    if (tags.contains('blood_sugar_friendly')) mapped.add('sugar-conscious');
    if (tags.contains('vegetarian')) mapped.add('vegetarian');
    if (tags.contains('gluten_free')) mapped.add('gluten-free');
    return mapped;
  }



  List<String> _foodApiQueries(String query) {
    final raw = query.trim();
    final out = <String>[];
    void add(String value) {
      final v = value.trim();
      if (v.isEmpty) return;
      if (!out.any((e) => e.toLowerCase() == v.toLowerCase())) out.add(v);
    }

    if (raw.isEmpty) return out;
    add(raw);
    final n = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    final aliases = <String, List<String>>{
      '大白菜': ['napa cabbage', 'chinese cabbage'],
      '白菜': ['chinese cabbage', 'napa cabbage'],
      '小白菜': ['bok choy', 'chinese cabbage'],
      '青菜': ['bok choy', 'leafy greens'],
      '生菜': ['lettuce'],
      '西兰花': ['broccoli'],
      '胡萝卜': ['carrot'],
      '土豆': ['potato'],
      '番茄': ['tomato'],
      '西红柿': ['tomato'],
      '黄瓜': ['cucumber'],
      '米饭': ['cooked white rice', 'rice cooked'],
      '面条': ['noodles cooked'],
      '面粉': ['wheat flour', 'all purpose flour'],
      '馒头': ['steamed bun'],
      '包子': ['steamed bun'],
      '鸡蛋': ['egg whole raw', 'egg boiled'],
      '牛奶': ['milk'],
      '豆浆': ['soy milk'],
      '豆腐': ['tofu'],
      '鸡胸肉': ['chicken breast'],
      '鸡肉': ['chicken meat'],
      '鱼肉': ['fish'],
      '方便面': ['instant noodles'],
      '泡面': ['instant noodles'],
      '火腿肠': ['sausage'],
      '冰淇淋': ['ice cream'],
      '抹茶味冰淇淋': ['matcha ice cream', 'green tea ice cream'],
      '奶茶': ['milk tea'],
      '酸奶': ['yogurt'],
      '燕麦': ['oats'],
    };
    for (final entry in aliases.entries) {
      if (n.contains(entry.key.toLowerCase())) {
        for (final v in entry.value) add(v);
      }
    }
    if (n.contains('抹茶') && n.contains('冰')) add('green tea ice cream');
    if (n.contains('蔬菜')) add('vegetables');
    if (n.contains('水果')) add('fruit');
    return out;
  }

  List<String> _recipeApiQueries(String query, {List<String>? healthTags}) {
    final raw = query.trim();
    final tags = healthTags ?? const <String>[];
    final out = <String>[];
    void add(String value) {
      final v = value.trim();
      if (v.isEmpty) return;
      if (!out.any((e) => e.toLowerCase() == v.toLowerCase())) out.add(v);
    }

    final lower = raw.toLowerCase();
    final hasCjk = RegExp(r'[一-鿿]').hasMatch(raw);

    for (final tag in tags) {
      switch (tag) {
        case 'low_sodium':
          add('low sodium chicken vegetables');
          add('steamed fish vegetables');
          add('tofu vegetable soup');
          break;
        case 'blood_sugar_friendly':
          add('diabetic chicken vegetables');
          add('high fiber high protein lunch');
          break;
        case 'stomach_care':
          add('gentle chicken rice soup');
          add('pumpkin oatmeal porridge');
          break;
        case 'muscle_gain':
        case 'high_protein':
          add('high protein chicken vegetables');
          add('high protein breakfast eggs oats');
          add('tofu eggs vegetables');
          break;
        case 'fiber_boost':
          add('high fiber vegetable soup');
          add('tofu mushroom vegetables');
          add('bean vegetable stew');
          break;
        case 'weight_control':
          add('healthy low calorie chicken vegetables');
          add('tofu vegetable soup');
          break;
        case 'restore_energy':
          add('healthy chicken rice bowl');
          add('egg oatmeal breakfast');
          break;
        case 'balanced':
          add('healthy chicken vegetables');
          add('tofu vegetable soup');
          add('healthy dinner vegetables protein');
          break;
      }
    }

    if (raw.isEmpty) {
      add('healthy chicken vegetables');
      add('tofu vegetable soup');
      return out;
    }

    if (!hasCjk) add(raw);

    if (hasCjk || lower.contains('balanced') || lower.contains('general')) {
      if (raw.contains('普通健康') || raw.contains('均衡') || lower == 'balanced') {
        add('healthy chicken vegetables');
        add('tofu vegetable soup');
        add('healthy dinner vegetables protein');
      }
      if (raw.contains('低盐') || raw.contains('清淡')) {
        add('low sodium chicken vegetables');
        add('steamed fish vegetables');
        add('tofu vegetable soup');
      }
      if (raw.contains('高蛋白') || raw.contains('蛋白')) {
        add('high protein chicken vegetables');
        add('high protein breakfast eggs oats');
      }
      if (raw.contains('高纤维') || raw.contains('蔬菜')) {
        add('high fiber vegetable soup');
        add('tofu mushroom vegetables');
      }
      if (raw.contains('养胃') || raw.contains('粥') || raw.contains('胃')) {
        add('gentle chicken rice soup');
        add('pumpkin oatmeal porridge');
      }
      if (raw.contains('控糖') || raw.contains('无糖')) {
        add('diabetic chicken vegetables');
        add('sugar conscious high protein breakfast');
      }
      if (raw.contains('午餐')) add('healthy lunch chicken vegetables');
      if (raw.contains('晚餐')) add('healthy dinner tofu vegetables');
      if (raw.contains('早餐')) add('high protein breakfast eggs oats');
      if (raw.contains('加餐')) add('healthy snack yogurt nuts');
      if (raw.contains('豆腐')) add('tofu vegetable soup');
      if (raw.contains('菌菇') || raw.contains('蘑菇')) add('mushroom tofu vegetables');
      if (raw.contains('燕麦')) add('oatmeal yogurt bowl');
      if (raw.contains('鱼')) add('steamed fish vegetables');
      if (raw.contains('鸡')) add('chicken vegetable soup');
    }

    if (out.isEmpty) {
      add('healthy chicken vegetables');
      add('tofu vegetable soup');
    }
    return out;
  }

  List<String> _healthTagsFromNutrients({double? protein, double? fiber, double? sugar, double? sodium}) => [
        if ((protein ?? 0) >= 10) 'high_protein',
        if ((fiber ?? 0) >= 5) 'high_fiber',
        if ((sugar ?? 0) >= 10) 'high_sugar',
        if ((sodium ?? 0) >= 400) 'high_sodium',
      ];

  List<String> _recipeTagsFromNutrition({double? protein, double? fiber, double? sodium, double? sugar}) => [
        if ((protein ?? 0) >= 20) 'muscle_gain',
        if ((fiber ?? 0) >= 6) 'fiber_boost',
        if ((sodium ?? 9999) <= 600) 'low_sodium',
        if ((sugar ?? 0) <= 8) 'blood_sugar_friendly',
        'balanced',
      ];

  double? _parseServing(String? text) {
    if (text == null) return null;
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*g').firstMatch(text.toLowerCase());
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  String _userAgent(Map<String, String> settings) {
    final v = (settings[HealthDietSettingsService.openFoodFactsUserAgent] ?? '').trim();
    return v.isEmpty ? 'quote_app_health_diet/1.0 (Android; contact: user-configured)' : v;
  }

  Future<void> _logGetRequest(
    String module,
    String provider,
    Uri uri,
    Map<String, String> headers, {
    List<String> redactedValues = const [],
    String? model,
  }) async {
    return _logHttpRequest(
      module,
      provider,
      uri,
      headers,
      method: 'GET',
      redactedValues: redactedValues,
      model: model,
    );
  }

  Future<void> _logHttpRequest(
    String module,
    String provider,
    Uri uri,
    Map<String, String> headers, {
    String method = 'GET',
    Object? body,
    List<String> redactedValues = const [],
    String? model,
  }) async {
    final redactedUri = _redactUri(uri, redactedValues: redactedValues);
    await DeepSeekLogger.logRequest(
      provider: provider,
      module: module,
      method: method,
      endpoint: redactedUri.toString(),
      headers: headers,
      body: <String, Object?>{
        'query_parameters': _redactMap(uri.queryParameters, redactedValues: redactedValues),
        if (body != null) 'body': body,
        'note': '健康饮食模块外部数据源请求；敏感密钥已隐藏。图片 URL 会在页面解析展示；英文结果是否 AI 中文化由独立开关控制。',
      },
      model: model,
    );
  }

  Future<void> _logHttpResponse(
    String module,
    String provider,
    Uri uri,
    http.Response response, {
    List<String> redactedValues = const [],
    String? model,
  }) async {
    final redactedUri = _redactUri(uri, redactedValues: redactedValues);
    await DeepSeekLogger.logResponse(
      provider: provider,
      module: module,
      endpoint: redactedUri.toString(),
      statusCode: response.statusCode,
      body: <String, Object?>{
        'headers': response.headers,
        'body': _bodyForLog(response.body, redactedValues: redactedValues),
        'body_length': response.body.length,
      },
      model: model,
    );
  }

  Future<void> _logApiError(
    String module,
    String provider,
    Uri uri,
    Object error,
    StackTrace stackTrace, {
    List<String> redactedValues = const [],
    String? model,
  }) async {
    final redactedUri = _redactUri(uri, redactedValues: redactedValues);
    await DeepSeekLogger.logError(
      provider: provider,
      module: module,
      endpoint: redactedUri.toString(),
      error: error,
      stackTrace: stackTrace,
      model: model,
    );
    await DLog.e(module, '$provider API failed: $error');
  }

  Uri _redactUri(Uri uri, {List<String> redactedValues = const []}) {
    final params = _redactMap(uri.queryParameters, redactedValues: redactedValues);
    return uri.replace(queryParameters: params.isEmpty ? null : params);
  }

  Map<String, String> _redactMap(Map<String, String> input, {List<String> redactedValues = const []}) {
    final sensitiveKeys = {'api_key', 'apikey', 'app_key', 'app_id', 'token', 'key'};
    return input.map((key, value) {
      final lower = key.toLowerCase();
      if (sensitiveKeys.any(lower.contains)) return MapEntry(key, '***REDACTED***');
      var v = value;
      for (final secret in redactedValues) {
        if (secret.trim().isNotEmpty) v = v.replaceAll(secret, '***REDACTED***');
      }
      return MapEntry(key, v);
    });
  }

  Object _bodyForLog(String body, {List<String> redactedValues = const []}) {
    var text = body;
    for (final secret in redactedValues) {
      if (secret.trim().isNotEmpty) text = text.replaceAll(secret, '***REDACTED***');
    }
    const maxChars = 12000;
    final logged = text.length <= maxChars ? text : '${text.substring(0, maxChars)}...\n[truncated: ${text.length - maxChars} chars omitted]';
    try {
      return jsonDecode(logged);
    } catch (_) {
      return logged;
    }
  }

  String _short(String body) => body.length <= 900 ? body : '${body.substring(0, 900)}...';
  String _hideKey(String text, String key) => key.isEmpty ? text : text.replaceAll(key, '***');

  List<NormalizedFoodItem> _dedupeFoods(List<NormalizedFoodItem> items) {
    final seen = <String>{};
    final out = <NormalizedFoodItem>[];
    for (final item in items) {
      final key = '${item.source}:${item.sourceId}:${item.name}'.toLowerCase();
      if (seen.add(key)) out.add(item);
    }
    return out;
  }

  List<NormalizedRecipe> _dedupeRecipes(List<NormalizedRecipe> items) {
    final seen = <String>{};
    final out = <NormalizedRecipe>[];
    for (final item in items) {
      final key = '${item.source}:${item.sourceId}:${item.title}'.toLowerCase();
      if (seen.add(key)) out.add(item);
    }
    return out;
  }
}
