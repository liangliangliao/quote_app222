import '../models/quote_insight.dart';

/// An explicit teaching case, never an event attributed to the author/user.
class AlignedAnalysisCase {
  final String id, title, text, purpose, boundary;
  final List<Map<String, String>> alignment;
  const AlignedAnalysisCase(this.id, this.title, this.text, this.purpose,
      this.boundary, this.alignment);
  static AlignedAnalysisCase parse(dynamic raw, Map<String, String> originals) {
    final map = insightObject(raw), id = insightText(insightObject(raw), 'id');
    final text = insightText(map, 'text');
    final alignment = <Map<String, String>>[];
    if (id.isEmpty ||
        insightText(map, 'title').isEmpty ||
        originals.containsKey(id) ||
        text.isEmpty ||
        insightText(map, 'purpose').isEmpty ||
        insightText(map, 'boundary').isEmpty) {
      throw const FormatException('相关案例须有独立身份、具体情境、分析目的和适用边界，不能冒充原句事实');
    }
    for (final value
        in map['alignment'] is List ? map['alignment'] as List : const []) {
      final item = insightObject(value),
          source = insightText(insightObject(value), 'source');
      final excerpt = insightText(item, 'excerpt'),
          detail = insightText(item, 'case_detail');
      if (excerpt.isEmpty ||
          detail.isEmpty ||
          originals[source]?.contains(excerpt) != true ||
          !text.contains(detail) ||
          insightText(item, 'preserved_meaning').isEmpty) {
        throw const FormatException(
            '案例的意义对应须同时定位原句与案例细节，并解释保留了什么；主题相似不能代替逐项对应');
      }
      alignment.add({
        'source': source,
        'excerpt': excerpt,
        'case_detail': detail,
        'preserved_meaning': insightText(item, 'preserved_meaning')
      });
    }
    if (alignment.isEmpty) throw const FormatException('相关案例缺少与原句核心意义的对应');
    return AlignedAnalysisCase(id, insightText(map, 'title'), text,
        insightText(map, 'purpose'), insightText(map, 'boundary'), alignment);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'purpose': purpose,
        'boundary': boundary,
        'alignment': alignment
      };
}
