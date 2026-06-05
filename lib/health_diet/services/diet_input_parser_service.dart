import '../models/daily_diet_entry.dart';

class DietInputParserService {
  static const Map<String, List<String>> _mealKeywords = {
    'breakfast': ['早餐', '早饭', '早上', '上午'],
    'lunch': ['午餐', '午饭', '中午'],
    'dinner': ['晚餐', '晚饭', '晚上'],
    'snack': ['加餐', '零食', '下午茶', '夜宵', '宵夜'],
    'drink': ['饮料', '喝了', '奶茶', '咖啡'],
  };

  static final RegExp _amountStart = RegExp(r'^(约|大约|大概|差不多|可能)?\s*([0-9一二两三四五六七八九十半几]+)\s*(个|份|碗|杯|根|块|片|瓶|袋|桶|盒|盘|口|勺)?');
  static final RegExp _standaloneNoise = RegExp(r'^(今天|明天|明年|昨天|后天|早上|中午|晚上|早餐|午餐|晚餐|早饭|午饭|晚饭|这个|那个|这包|这份|这些|一些|东西|食物|记录|图片|照片|拍照|上传|分析|确认|明|年|月|日)$');
  static final RegExp _skipMeal = RegExp(r'(没吃|没有吃|没来得及吃|不吃|空腹|跳过|未吃)');

  List<DetectedDietFood> parseText(String text, {String source = 'text'}) {
    final input = text.trim();
    if (input.isEmpty) return const [];
    final segments = _splitByMeal(input);
    final foods = <DetectedDietFood>[];
    for (final segment in segments) {
      if (_skipMeal.hasMatch(segment.text)) continue;
      final tokens = _extractFoodTokens(segment.text);
      for (final token in tokens) {
        final cleaned = _cleanFoodName(token);
        if (!_looksLikeFood(cleaned)) continue;
        foods.add(DetectedDietFood(
          foodName: cleaned,
          amountText: _amountText(token, cleaned),
          mealType: segment.mealType,
          cookingMethod: _guessCookingMethod(token),
          confidenceScore: segment.mealType == 'unknown' ? 0.58 : 0.74,
          confirmedByUser: false,
          source: source,
        ));
      }
    }
    return _deduplicate(foods);
  }

  List<_MealSegment> _splitByMeal(String input) {
    final matches = <_KeywordMatch>[];
    _mealKeywords.forEach((mealType, keywords) {
      for (final keyword in keywords) {
        var start = 0;
        while (true) {
          final index = input.indexOf(keyword, start);
          if (index < 0) break;
          matches.add(_KeywordMatch(index, keyword.length, mealType));
          start = index + keyword.length;
        }
      }
    });
    matches.sort((a, b) => a.index.compareTo(b.index));
    if (matches.isEmpty) return [_MealSegment('unknown', input)];

    final segments = <_MealSegment>[];
    for (var i = 0; i < matches.length; i++) {
      final current = matches[i];
      final end = i + 1 < matches.length ? matches[i + 1].index : input.length;
      var text = input.substring(current.index + current.length, end);
      text = text.replaceAll(RegExp(r'^[：:，,。；;\s]+'), '').trim();
      if (text.isNotEmpty) segments.add(_MealSegment(current.mealType, text));
    }
    if (segments.isEmpty) return [_MealSegment('unknown', input)];
    return segments;
  }

  List<String> _extractFoodTokens(String segment) {
    var text = segment;
    text = text.replaceAll(RegExp(r'[。；;\n]'), '，');
    text = text.replaceAll(RegExp(r'(然后|还有|以及|另外|并且|搭配|配了|加了|加|和|、|\+)'), '，');
    text = _insertSeparatorBetweenAmountFoods(text);
    final raw = text.split(RegExp(r'[，,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final result = <String>[];
    for (final item in raw) {
      final clean = item
          .replaceAll(RegExp(r'^(我|今天|大概|差不多|可能|主要|只|就|也|有|吃了|吃|喝了|喝|点了|买了|用了|来了一份|一份|这包|这个|那个)'), '')
          .replaceAll(RegExp(r'(左右|大约|大概)$'), '')
          .trim();
      if (clean.length >= 2 && !_standaloneNoise.hasMatch(clean)) result.add(clean);
    }
    return result;
  }

  /// Split common compact descriptions such as “两个包子一杯豆浆” into
  /// “两个包子，一杯豆浆”. This is intentionally simple and conservative.
  String _insertSeparatorBetweenAmountFoods(String text) {
    return text.replaceAllMapped(
      RegExp(r'([\u4e00-\u9fa5]{2,})([一二两三四五六七八九十0-9半几]+\s*(个|份|碗|杯|根|块|片|瓶|袋|桶|盒|盘))'),
      (m) => '${m.group(1)}，${m.group(2)}',
    );
  }

  String _cleanFoodName(String token) {
    var value = token.trim();
    value = value.replaceAll(_amountStart, '');
    value = value.replaceAll(RegExp(r'(约|左右|一份|一碗|一杯|一个|两个|三个|半份|少量|很多)$'), '');
    value = value.replaceAll(RegExp(r'^(的|了|些|点|份)'), '').trim();
    value = value.replaceAll(RegExp(r'[。！？!?,，；;：:]'), '').trim();
    return value.trim();
  }

  String? _amountText(String token, String cleanedName) {
    final trimmed = token.trim();
    final m = _amountStart.firstMatch(trimmed);
    if (m != null) {
      final amount = m.group(0)?.trim();
      if (amount != null && amount.isNotEmpty) return amount;
    }
    if (trimmed != cleanedName && trimmed.contains(cleanedName)) return trimmed;
    return null;
  }

  bool _looksLikeFood(String value) {
    final v = value.trim();
    if (v.length < 2 || v.length > 18) return false;
    if (_standaloneNoise.hasMatch(v)) return false;
    if (_skipMeal.hasMatch(v)) return false;
    if (RegExp(r'^[0-9一二两三四五六七八九十半几]+$').hasMatch(v)) return false;
    return true;
  }

  String? _guessCookingMethod(String token) {
    if (token.contains('炸') || token.contains('油条')) return 'fried';
    if (token.contains('烤') || token.contains('烧烤')) return 'grilled';
    if (token.contains('蒸')) return 'steamed';
    if (token.contains('煮') || token.contains('粥') || token.contains('汤')) return 'boiled';
    if (token.contains('炒')) return 'stir_fried';
    if (token.contains('奶茶') || token.contains('咖啡') || token.contains('饮料') || token.contains('豆浆')) return 'drink';
    return null;
  }

  List<DetectedDietFood> _deduplicate(List<DetectedDietFood> foods) {
    final seen = <String>{};
    final result = <DetectedDietFood>[];
    for (final food in foods) {
      final key = '${food.mealType}:${food.foodName}:${food.amountText ?? ''}';
      if (seen.add(key)) result.add(food);
    }
    return result;
  }
}

class _KeywordMatch {
  const _KeywordMatch(this.index, this.length, this.mealType);
  final int index;
  final int length;
  final String mealType;
}

class _MealSegment {
  const _MealSegment(this.mealType, this.text);
  final String mealType;
  final String text;
}
