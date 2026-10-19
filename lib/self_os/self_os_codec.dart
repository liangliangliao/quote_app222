import 'dart:convert';
import 'dart:math';

String selfOsId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(1 << 32).toRadixString(36)}';
Map<String, dynamic> osMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> osMaps(dynamic value) =>
    value is List ? value.whereType<Map>().map(osMap).toList() : [];
String osText(dynamic value) => value is String ? value : '';
double? osNumber(dynamic value, [double max = 100]) {
  final n = value is num ? value.toDouble() : double.tryParse('$value');
  return n != null && n.isFinite ? n.clamp(0, max).toDouble() : null;
}

List<String> osStrings(dynamic value) =>
    value is List ? value.whereType<String>().toList() : [];
Map<String, dynamic> osClone(Map<String, dynamic> value) =>
    osMap(jsonDecode(jsonEncode(value)));
