/// 离线时也能说明弱点关联，但只对共同出现的行为词提出待核实的关联。
class GrowthGuidance {
  const GrowthGuidance._();
  static const _patterns = [
    '拖延',
    '回避',
    '完美',
    '害怕失败',
    '自我怀疑',
    '讨好',
    '冲动',
    '分心',
    '放弃',
    '犹豫'
  ];
  static String relate(
      Map<String, dynamic> digest, String current, String base) {
    final profile = digest['growth_profile'];
    if (profile is! Map || profile.isEmpty) return base;
    final items = profile['weaknesses'];
    if (items is! List) return base;
    for (final item in items) {
      if (item is! Map) continue;
      final description = (item['description'] ?? '').toString();
      if (!_patterns.any((p) => current.contains(p) && description.contains(p)))
        continue;
      final short = description.length > 40
          ? '${description.substring(0, 39)}…'
          : description;
      final note = '你自述的「$short」可能相关，先一起核实，再选一步改变。';
      final head = base.length + note.length > 195
          ? base.substring(0, (195 - note.length - 1).clamp(0, base.length))
          : base;
      return '$head\n$note';
    }
    return base;
  }
}
