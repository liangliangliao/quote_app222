import 'dart:math' as math;

Map<String, String> depthEvidence(List<dynamic> segments) {
  String quote(String phase) {
    final segment = segments.firstWhere((s) => s['phase'] == phase);
    final text = segment['text'] as String;
    final end = text.indexOf(RegExp(r'[。！？!?]'));
    return text.substring(0, math.min(24, end >= 3 ? end + 1 : text.length));
  }

  return {
    'pattern': quote('body_emotion'),
    'experiment': quote('embodied_shift'),
    'emotional_contact': quote('allow_experience'),
    'meaning': quote('integration'),
    'transfer': quote('real_life_rehearsal'),
  };
}
