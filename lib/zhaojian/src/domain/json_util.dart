import 'dart:convert';

/// 从模型返回的文本里取出 JSON。去掉代码围栏，取第一个到最后一个括号。
/// 解析失败一律返回空，不抛异常。
dynamic zParseJson(String raw, {required bool array}) {
  final String s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
  final int a = s.indexOf(array ? '[' : '{');
  final int b = s.lastIndexOf(array ? ']' : '}');
  if (a < 0 || b <= a) return null;
  try {
    return jsonDecode(s.substring(a, b + 1));
  } catch (_) {
    return null;
  }
}

List<dynamic> zParseArray(String raw) {
  final dynamic v = zParseJson(raw, array: true);
  return v is List ? v : <dynamic>[];
}

Map<String, dynamic>? zParseObject(String raw) {
  final dynamic v = zParseJson(raw, array: false);
  return v is Map ? Map<String, dynamic>.from(v) : null;
}

List<String> zStrings(dynamic v, {int max = 6}) {
  if (v is! List) return <String>[];
  return v
      .map((dynamic e) => '$e'.trim())
      .where((String e) => e.isNotEmpty)
      .take(max)
      .toList();
}
