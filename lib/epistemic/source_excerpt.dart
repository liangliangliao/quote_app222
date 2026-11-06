/// Recover the exact source span after harmless typography/whitespace changes.
/// Words, negation, quantities and operators are never removed or paraphrased.
String? locateSourceExcerpt(String source, String excerpt) {
  var needle = excerpt.trim();
  if (needle.isEmpty) return null;
  if (source.contains(needle)) return needle;
  const pairs = {'“': '”', '「': '」', '‘': '’', '"': '"', "'": "'"};
  if (needle.length > 1 && pairs[needle[0]] == needle[needle.length - 1]) {
    needle = needle.substring(1, needle.length - 1).trim();
    if (needle.isNotEmpty && source.contains(needle)) return needle;
  }
  const punctuation = {
    '“': '"',
    '”': '"',
    '「': '"',
    '」': '"',
    '‘': "'",
    '’': "'",
    '，': ',',
    '。': '.',
    '：': ':',
    '；': ';',
    '（': '(',
    '）': ')',
    '！': '!',
    '？': '?'
  };
  (String, List<int>, List<int>) normalize(String value) {
    final out = StringBuffer(), starts = <int>[], ends = <int>[];
    var space = false;
    for (var i = 0; i < value.length; i++) {
      final c = value[i];
      if (RegExp(r'\s').hasMatch(c)) {
        if (space) {
          if (ends.isNotEmpty) ends[ends.length - 1] = i + 1;
          continue;
        }
        out.write(' ');
        starts.add(i);
        ends.add(i + 1);
        space = true;
      } else {
        out.write(punctuation[c] ?? c);
        starts.add(i);
        ends.add(i + 1);
        space = false;
      }
    }
    return (out.toString(), starts, ends);
  }

  final haystack = normalize(source), target = normalize(needle).$1;
  if (target.isEmpty) return null;
  final at = haystack.$1.indexOf(target);
  if (at < 0 || haystack.$1.indexOf(target, at + 1) >= 0) return null;
  return source.substring(haystack.$2[at], haystack.$3[at + target.length - 1]);
}
