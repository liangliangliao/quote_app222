import 'dart:math';

String normalizeText(String s) {
  var t = s;
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceAll('“', '"').replaceAll('”', '"').replaceAll('’', "'").replaceAll('‘', "'");
  return t.toLowerCase();
}

// Jaro-Winkler similarity in [0,1]
double jaroWinkler(String s1, String s2) {
  if (s1 == s2) return 1.0;
  if (s1.isEmpty || s2.isEmpty) return 0.0;

  final matchDistance = max((max(s1.length, s2.length) ~/ 2) - 1, 0);
  final s1Matches = List<bool>.filled(s1.length, false);
  final s2Matches = List<bool>.filled(s2.length, false);

  int matches = 0;
  for (int i = 0; i < s1.length; i++) {
    final start = max(0, i - matchDistance);
    final end = min(i + matchDistance + 1, s2.length);
    for (int j = start; j < end; j++) {
      if (s2Matches[j]) continue;
      if (s1[i] != s2[j]) continue;
      s1Matches[i] = true;
      s2Matches[j] = true;
      matches++;
      break;
    }
  }
  if (matches == 0) return 0.0;

  int t = 0;
  int k = 0;
  for (int i = 0; i < s1.length; i++) {
    if (!s1Matches[i]) continue;
    while (!s2Matches[k]) { k++; }
    if (s1[i] != s2[k]) t++;
    k++;
  }
  final m = matches.toDouble();
  final jaro = (m / s1.length + m / s2.length + (m - t / 2.0) / m) / 3.0;

  // Winkler prefix scaling
  int prefix = 0;
  for (; prefix < min(4, min(s1.length, s2.length)); prefix++) {
    if (s1[prefix] != s2[prefix]) break;
  }
  return jaro + prefix * 0.1 * (1 - jaro);
}