import 'dart:convert';

class OsPrincipleLink {
  const OsPrincipleLink(this.caseId, this.principleId, this.triggerId);
  final String caseId, principleId, triggerId;
  static const prefix = 'self_os_principle:';
  String encode() => '$prefix${base64Url.encode(utf8.encode(jsonEncode({
            'caseId': caseId,
            'principleId': principleId,
            'triggerId': triggerId,
          })))}';
  static OsPrincipleLink? parse(String? payload) {
    if (payload == null || !payload.startsWith(prefix) || payload.length > 2048)
      return null;
    try {
      final j = jsonDecode(
          utf8.decode(base64Url.decode(payload.substring(prefix.length))));
      if (j is! Map ||
          ['caseId', 'principleId', 'triggerId'].any((k) =>
              j[k] is! String ||
              (j[k] as String).isEmpty ||
              (j[k] as String).length > 180)) return null;
      return OsPrincipleLink(j['caseId'], j['principleId'], j['triggerId']);
    } catch (_) {
      return null;
    }
  }
}
