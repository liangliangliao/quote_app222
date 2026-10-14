import 'dart:math' as math;

import '../copy.dart';
import '../data/models.dart';
import '../zhaojian_oracle.dart';

/// 全部是纯函数，不碰数据库、不碰界面，方便单元测试。

/// 一边的动机分量：抽象 / 直观分开算。
class ZSums {
  const ZSums(this.aAbs, this.aInt, this.bAbs, this.bInt);

  final double aAbs;
  final double aInt;
  final double bAbs;
  final double bInt;

  double get a => aAbs + aInt;
  double get b => bAbs + bInt;
  double get totalAbs => aAbs + bAbs;
  double get totalInt => aInt + bInt;

  double get maxValue =>
      math.max(1.0, math.max(math.max(aAbs, aInt), math.max(bAbs, bInt)));
}

/// 把评过分（分量大于 0）的动机按抽象/直观、A/B 汇总。
/// 「两边」的动机，分量对半分给 A 和 B。
ZSums sumMotives(Iterable<ZMotive> motives) {
  double aAbs = 0, aInt = 0, bAbs = 0, bInt = 0;
  for (final ZMotive m in motives) {
    if (m.weight <= 0) continue;
    final double w = m.weight.toDouble();
    final double part = m.side == 'both' ? w / 2 : w;
    if (m.side == 'a' || m.side == 'both') {
      if (m.isAbstract) {
        aAbs += part;
      } else {
        aInt += part;
      }
    }
    if (m.side == 'b' || m.side == 'both') {
      if (m.isAbstract) {
        bAbs += part;
      } else {
        bInt += part;
      }
    }
  }
  return ZSums(aAbs, aInt, bAbs, bInt);
}

/// 抽象动机偏向哪边（'a' / 'b'），打平返回 null。
String? absLean(ZSums s) => s.aAbs > s.bAbs ? 'a' : (s.aAbs < s.bAbs ? 'b' : null);

/// 直观动机偏向哪边，打平返回 null。
String? intLean(ZSums s) => s.aInt > s.bInt ? 'a' : (s.aInt < s.bInt ? 'b' : null);

/// 抽象与直观是否各自有明确的倾向，并且方向相反。
bool lanesDisagree(ZSums s) {
  if (s.totalAbs <= 0 || s.totalInt <= 0) return false;
  final String? x = absLean(s);
  final String? y = intLean(s);
  return x != null && y != null && x != y;
}

/// 勒温/米勒冲突诊断的中间量。
class ZConflict {
  const ZConflict(this.type, this.aAp, this.aAv, this.bAp, this.bAv);

  /// 0 冲突不强 / 1 趋-趋 / 2 避-避 / 3 趋-避 / 4 双趋避。
  final int type;
  final double aAp;
  final double aAv;
  final double bAp;
  final double bAv;
}

ZConflict conflictOf(Iterable<ZMotive> motives) {
  double aAp = 0, aAv = 0, bAp = 0, bAv = 0;
  for (final ZMotive m in motives) {
    if (m.weight <= 0) continue;
    final double w = m.weight.toDouble();
    final double part = m.side == 'both' ? w / 2 : w;
    final bool av = m.valence == 'av';
    if (m.side == 'a' || m.side == 'both') {
      if (av) {
        aAv += part;
      } else {
        aAp += part;
      }
    }
    if (m.side == 'b' || m.side == 'both') {
      if (av) {
        bAv += part;
      } else {
        bAp += part;
      }
    }
  }
  final double mx =
      math.max(1.0, math.max(math.max(aAp, aAv), math.max(bAp, bAv)));
  bool strong(double x) => x >= mx * 0.4;
  final bool aApS = strong(aAp);
  final bool aAvS = strong(aAv);
  final bool bApS = strong(bAp);
  final bool bAvS = strong(bAv);
  int type = 0;
  if (aApS && aAvS && bApS && bAvS) {
    type = 4;
  } else if ((aApS && aAvS) || (bApS && bAvS)) {
    type = 3;
  } else if (aApS && bApS && !aAvS && !bAvS) {
    type = 1;
  } else if (aAvS && bAvS && !aApS && !bApS) {
    type = 2;
  }
  return ZConflict(type, aAp, aAv, bAp, bAv);
}

/// 想象深度：每张卡点了几项画面，以及两边是否对称。
class ZImagery {
  const ZImagery({
    required this.count,
    required this.average,
    required this.a,
    required this.b,
    required this.worst,
  });

  /// 补全过画面的卡数。
  final int count;
  final double average;
  final int a;
  final int b;

  /// 是否想象过「最坏的一刻/障碍」。
  final bool worst;

  /// 较少一边与较多一边的比；没有画面时为 null。
  double? get symmetry {
    final int hi = math.max(a, b);
    if (hi <= 0) return null;
    return math.min(a, b) / hi;
  }

  /// 一边明显比另一边想得多。
  bool get lopsided {
    final double? s = symmetry;
    return count > 0 && s != null && s < 0.5;
  }
}

ZImagery imageryOf(Iterable<ZMotive> cards) {
  int count = 0, total = 0, a = 0, b = 0;
  bool worst = false;
  for (final ZMotive c in cards) {
    if (c.imagery.isEmpty) continue;
    count += 1;
    total += c.imagery.length;
    if (c.side == 'a' || c.side == 'both') a += c.imagery.length;
    if (c.side == 'b' || c.side == 'both') b += c.imagery.length;
    if (c.imagery.contains(ZCopy.worstMomentTag)) worst = true;
  }
  return ZImagery(
    count: count,
    average: count == 0 ? 0 : total / count,
    a: a,
    b: b,
    worst: worst,
  );
}

/// 开牌后：当抽象与直观动机指向不同选项时，行动跟了哪一类。
/// 不满足「两类都有、方向相反」就返回 null。
String? followedKind(ZDecision d) {
  final String? actual = d.actual;
  if (actual == null) return null;
  final ZSums s = sumMotives(d.motives);
  if (!lanesDisagree(s)) return null;
  return actual == intLean(s) ? '直观' : '抽象';
}

/// 行动是否和天平上总分更重的一边相反（提示天平可能漏了动机）。
bool opposesBalance(ZDecision d) {
  final String? actual = d.actual;
  if (actual == null || d.motives.isEmpty) return false;
  final ZSums s = sumMotives(d.motives);
  if (s.a == s.b) return false;
  final String heavier = s.a > s.b ? 'a' : 'b';
  return heavier != actual;
}

/// 自知分：命中加筹码，落空扣筹码。
int selfScoreOf(ZDecision d) {
  if (d.actual == null) return 0;
  return d.hit ? d.stake : -d.stake;
}

int totalSelfScore(Iterable<ZDecision> ds) {
  int t = 0;
  for (final ZDecision d in ds) {
    t += selfScoreOf(d);
  }
  return t;
}

/// 预测命中率；没有样本返回 null。
double? hitRateOf(Iterable<ZDecision> ds) {
  int n = 0, h = 0;
  for (final ZDecision d in ds) {
    if (d.actual == null) continue;
    n += 1;
    if (d.hit) h += 1;
  }
  if (n == 0) return null;
  return h / n;
}

/// 按时间顺序一分为二：早期与近期。样本不足两个时近期为空。
({List<ZDecision> early, List<ZDecision> recent}) splitHalves(
    List<ZDecision> ds) {
  final int cut = (ds.length + 1) ~/ 2;
  return (early: ds.sublist(0, cut), recent: ds.sublist(cut));
}

/// 假设的状态：1 被行为支持 / 2 被行为反驳 / 0 待验证。
/// 支持至少 3 次且不少于反驳的 2 倍；反驳至少 2 次且多于支持。
int hypothesisStatus(int sup, int ref) {
  if (sup >= 3 && sup >= 2 * ref) return 1;
  if (ref >= 2 && ref > sup) return 2;
  return 0;
}

/// 前 5 推荐的一项。
class ZRank {
  const ZRank({
    required this.index,
    required this.motive,
    required this.pull,
    required this.confidence,
    required this.badge,
    required this.key,
    required this.scored,
  });

  /// 在原卡片列表里的下标。
  final int index;
  final ZMotive motive;

  /// 引擎给的拉力 0 到 4；没打分为 0。
  final double pull;
  final double? confidence;
  final String badge;

  /// 排序键。
  final double key;

  /// 是否有引擎打分（否则是规则推荐）。
  final bool scored;
}

/// 对候选动机排序并取前 5：每类最多 2 个，保证多样。
///
/// [pulls] 是引擎给的拉力（下标 -> 0 到 4），没有则按类别规则排序；
/// [missCats] 是用户常漏掉的类别，会得到小幅加成。
List<ZRank> rankTop5(
  List<ZMotive> cards,
  Map<int, double> pulls, {
  Map<int, double> confidences = const <int, double>{},
  Set<int> missCats = const <int>{},
}) {
  final List<ZRank> all = <ZRank>[];
  for (int i = 0; i < cards.length; i++) {
    final ZMotive c = cards[i];
    final double? p = pulls[i];
    final double? cf = confidences[i];
    final bool hit = missCats.contains(c.cat);
    double k;
    if (p == null) {
      k = (c.cat == ZCopy.hiddenCategory ? 0.3 : 0.0) +
          (hit ? 0.3 : 0.0) +
          (<int>{0, 2, 3, 11}.contains(c.cat) ? 0.1 : 0.0);
    } else {
      final double pp = p.clamp(0.0, 4.0).toDouble();
      k = pp / 4 * (0.6 + 0.4 * (cf ?? 0.5)) +
          (hit ? 0.08 : 0.0) +
          (c.cat == ZCopy.hiddenCategory ? 0.05 : 0.0);
    }
    String badge = hit ? '你常漏这类' : '';
    if (c.cat == ZCopy.hiddenCategory && badge.isEmpty) badge = '不愿承认的动机';
    all.add(ZRank(
      index: i,
      motive: c,
      pull: p == null ? 0 : p.clamp(0.0, 4.0).toDouble(),
      confidence: cf,
      badge: badge,
      key: k,
      scored: p != null,
    ));
  }
  // Dart 的 List.sort 不保证稳定，所以键相同时按原下标排。
  all.sort((ZRank x, ZRank y) {
    final int c = y.key.compareTo(x.key);
    return c != 0 ? c : x.index.compareTo(y.index);
  });
  final List<ZRank> pick = <ZRank>[];
  final Map<int, int> count = <int, int>{};
  for (final ZRank r in all) {
    if (pick.length >= 5) break;
    final int n = count[r.motive.cat] ?? 0;
    if (n >= 2) continue;
    count[r.motive.cat] = n + 1;
    pick.add(r);
  }
  return pick;
}

/// 用户常漏的类别（出现次数最多的前 3 个）。
Set<int> topMissCategories(Iterable<ZMiss> misses) {
  final Map<int, int> c = <int, int>{};
  for (final ZMiss m in misses) {
    if (m.cat < 0) continue;
    c[m.cat] = (c[m.cat] ?? 0) + 1;
  }
  final List<MapEntry<int, int>> es = c.entries.toList()
    ..sort((MapEntry<int, int> x, MapEntry<int, int> y) {
      final int d = y.value.compareTo(x.value);
      return d != 0 ? d : x.key.compareTo(y.key);
    });
  return es.take(3).map((MapEntry<int, int> e) => e.key).toSet();
}

/// 自由感与可预测性：按平均数分高低两组，各至少 2 个才比较。
class ZFreedomStat {
  const ZFreedomStat({
    required this.highCount,
    required this.lowCount,
    required this.highHit,
    required this.lowHit,
  });
  final int highCount;
  final int lowCount;
  final double highHit;
  final double lowHit;
}

/// 样本不足（少于 6 个）或高低差异不够返回 null。
ZFreedomStat? freedomStat(Iterable<ZDecision> revealed) {
  final List<ZDecision> q = revealed
      .where((ZDecision d) => d.actual != null && d.feltFreedom != null)
      .toList();
  if (q.length < 6) return null;
  double sum = 0;
  for (final ZDecision d in q) {
    sum += d.feltFreedom!.toDouble();
  }
  final double mean = sum / q.length;
  final List<ZDecision> hi =
      q.where((ZDecision d) => d.feltFreedom! > mean).toList();
  final List<ZDecision> lo =
      q.where((ZDecision d) => d.feltFreedom! <= mean).toList();
  if (hi.length < 2 || lo.length < 2) return null;
  return ZFreedomStat(
    highCount: hi.length,
    lowCount: lo.length,
    highHit: hitRateOf(hi) ?? 0,
    lowHit: hitRateOf(lo) ?? 0,
  );
}

/// 抽象与直观冲突时的胜出统计。
class ZWinStat {
  const ZWinStat({required this.intuitive, required this.abstractWins});
  final int intuitive;
  final int abstractWins;
  int get total => intuitive + abstractWins;
}

ZWinStat winStat(Iterable<ZDecision> revealed) {
  int i = 0, a = 0;
  for (final ZDecision d in revealed) {
    final String? f = followedKind(d);
    if (f == '直观') i += 1;
    if (f == '抽象') a += 1;
  }
  return ZWinStat(intuitive: i, abstractWins: a);
}

/// 想象深度与预测命中：按平均数分「想得深 / 想得浅」两组，各至少 2 个才比较。
class ZImageryStat {
  const ZImageryStat({
    required this.deepCount,
    required this.shallowCount,
    required this.deepHit,
    required this.shallowHit,
  });
  final int deepCount;
  final int shallowCount;
  final double deepHit;
  final double shallowHit;
}

/// 样本不足（少于 6 个已开牌且记过想象）或深浅差异不够返回 null。
ZImageryStat? imageryStat(Iterable<ZDecision> revealed) {
  final List<ZDecision> q = revealed
      .where((ZDecision d) =>
          d.actual != null && d.imageryDepth != null && d.imageryDepth! > 0)
      .toList();
  if (q.length < 6) return null;
  double sum = 0;
  for (final ZDecision d in q) {
    sum += d.imageryDepth!;
  }
  final double mean = sum / q.length;
  final List<ZDecision> deep =
      q.where((ZDecision d) => d.imageryDepth! > mean).toList();
  final List<ZDecision> shallow =
      q.where((ZDecision d) => d.imageryDepth! <= mean).toList();
  if (deep.length < 2 || shallow.length < 2) return null;
  return ZImageryStat(
    deepCount: deep.length,
    shallowCount: shallow.length,
    deepHit: hitRateOf(deep) ?? 0,
    shallowHit: hitRateOf(shallow) ?? 0,
  );
}

// ---------------------------------------------------------------------------
// 一致度与难度
// ---------------------------------------------------------------------------

/// 一致度的汇总：每个选项在三个尺度上按欲求的证据强弱加权平均。
class ZAlignCalc {
  const ZAlignCalc({
    required this.weekA,
    required this.yearA,
    required this.decadeA,
    required this.loA,
    required this.hiA,
    required this.weekB,
    required this.yearB,
    required this.decadeB,
    required this.loB,
    required this.hiB,
    required this.flip,
    required this.confidence,
    required this.manual,
    required this.weakOnly,
  });

  final int weekA;
  final int yearA;
  final int decadeA;

  /// 一年尺度上，各个欲求给出的最低与最高值。
  final int loA;
  final int hiA;
  final int weekB;
  final int yearB;
  final int decadeB;
  final int loB;
  final int hiB;

  /// 排序随欲求而变：结论取决于你到底要什么。
  final bool flip;

  /// 模型自报置信度，按欲求的证据等级封顶后的值；没有则为 null。
  final double? confidence;

  /// 是否是用户自评。
  final bool manual;

  /// 对照的欲求是否全是自述。
  final bool weakOnly;

  int yearOf(String side) => side == 'a' ? yearA : yearB;
}

/// 强证据（被行为支持）权重 1，自述权重 0.3。
double desireWeight(ZDesire d) => d.strong ? 1.0 : 0.3;

/// 把引擎结果按欲求的证据强弱加权汇总。没有结果返回 null。
ZAlignCalc? calcAlignment(ZAlignResult r, List<ZDesire> desires) {
  final int n = math.min(r.rows.length, desires.length);
  if (n == 0) return null;
  double totalW = 0;
  for (int i = 0; i < n; i++) {
    totalW += desireWeight(desires[i]);
  }
  int avg(int Function(ZAlignRow row) pick) {
    double sum = 0;
    for (int i = 0; i < n; i++) {
      sum += desireWeight(desires[i]) * pick(r.rows[i]);
    }
    return (sum / totalW).round();
  }

  int at(List<int> v, int k) => k < v.length ? v[k].clamp(0, 100).toInt() : 50;
  int loA = 100, hiA = 0, loB = 100, hiB = 0;
  bool up = false, down = false;
  for (int i = 0; i < n; i++) {
    final int ya = at(r.rows[i].a, 1);
    final int yb = at(r.rows[i].b, 1);
    loA = math.min(loA, ya);
    hiA = math.max(hiA, ya);
    loB = math.min(loB, yb);
    hiB = math.max(hiB, yb);
    if (ya > yb) up = true;
    if (ya < yb) down = true;
  }
  final bool anyStrong = desires.take(n).any((ZDesire d) => d.strong);
  final double cap = anyStrong ? 0.9 : 0.5;
  final double? conf = r.confidence == null
      ? null
      : math.min(r.confidence!.clamp(0.0, 1.0).toDouble(), cap);
  return ZAlignCalc(
    weekA: avg((ZAlignRow x) => at(x.a, 0)),
    yearA: avg((ZAlignRow x) => at(x.a, 1)),
    decadeA: avg((ZAlignRow x) => at(x.a, 2)),
    loA: loA,
    hiA: hiA,
    weekB: avg((ZAlignRow x) => at(x.b, 0)),
    yearB: avg((ZAlignRow x) => at(x.b, 1)),
    decadeB: avg((ZAlignRow x) => at(x.b, 2)),
    loB: loB,
    hiB: hiB,
    flip: up && down,
    confidence: conf,
    manual: false,
    weakOnly: !anyStrong,
  );
}

/// 用户自评：只有一年尺度的一个数，三个尺度取同一个值，没有范围和置信度。
ZAlignCalc manualAlignment(int a, int b) {
  final int x = a.clamp(0, 100).toInt();
  final int y = b.clamp(0, 100).toInt();
  return ZAlignCalc(
    weekA: x,
    yearA: x,
    decadeA: x,
    loA: x,
    hiA: x,
    weekB: y,
    yearB: y,
    decadeB: y,
    loB: y,
    hiB: y,
    flip: false,
    confidence: null,
    manual: true,
    weakOnly: true,
  );
}

/// 某个选项在天平里的拉力占比（两边加起来为 1）；没有评分时为 0.5。
double pullShare(ZSums s, String side) {
  final double total = s.a + s.b;
  if (total <= 0) return 0.5;
  return (side == 'a' ? s.a : s.b) / total;
}

/// 「一致度 × 拉力」四象限的下标，对应 [ZCopy.quadrants]：
/// 0 高一致高拉力 / 1 高一致低拉力 / 2 低一致高拉力 / 3 低一致低拉力。
int quadrantOf(int year, double share) {
  final bool highAlign = year >= 60;
  final bool highPull = share > 0.5;
  if (highAlign && highPull) return 0;
  if (highAlign) return 1;
  if (highPull) return 2;
  return 3;
}

/// 「选择贴近欲求」：所选项的一年一致度，早期与近期的平均。
/// 做过一致度的已开牌决定不足两个时返回 null。
({double? early, double? recent})? alignTrend(List<ZDecision> revealed) {
  final List<ZDecision> q = revealed
      .where((ZDecision d) => d.actual != null && d.align != null)
      .toList();
  if (q.length < 2) return null;
  final ({List<ZDecision> early, List<ZDecision> recent}) h = splitHalves(q);
  double? mean(List<ZDecision> ds) {
    if (ds.isEmpty) return null;
    double sum = 0;
    for (final ZDecision d in ds) {
      sum += d.align!.yearOf(d.actual!);
    }
    return sum / ds.length;
  }

  return (early: mean(h.early), recent: mean(h.recent));
}

// ---------------------------------------------------------------------------
// 通用统计
// ---------------------------------------------------------------------------

/// 数每个非空字符串出现的次数。
Map<String, int> countStrings(Iterable<String> items) {
  final Map<String, int> c = <String, int>{};
  for (final String s in items) {
    if (s.isEmpty) continue;
    c[s] = (c[s] ?? 0) + 1;
  }
  return c;
}

/// 出现次数最多的前 n 个，形如「松了口气 3　胃沉 2」。
String topCounts(Map<String, int> c, {int n = 6}) {
  final List<MapEntry<String, int>> es = c.entries.toList()
    ..sort((MapEntry<String, int> x, MapEntry<String, int> y) {
      final int d = y.value.compareTo(x.value);
      return d != 0 ? d : x.key.compareTo(y.key);
    });
  return es
      .take(n)
      .map((MapEntry<String, int> e) => '${e.key} ${e.value}')
      .join('　');
}

// ---------------------------------------------------------------------------
// 改变：假设行动判词、安全检测、宿命式措辞
// ---------------------------------------------------------------------------

/// 假设行动的结论：保留 / 继续 / 重设 / 弃 / 信息不全。
/// [reaction]、[belief]、[aligned] 分别是 [ZCopy.asifReactions]、[ZCopy.asifBeliefs]、
/// [ZCopy.asifAligned] 里的选项，没填就是空串。
String asifVerdict(String reaction, String belief, String aligned) {
  if (reaction.isEmpty || belief.isEmpty || aligned.isEmpty) {
    return '信息不全：先把三项检验都填完。';
  }
  if (aligned == '更远了') {
    return '弃：它不通向你真正想要的，别硬撑；回到「一致度」重新看你要什么。';
  }
  if (belief == '成真了') {
    return '重设：担心成真了。先别加码，用更小的实验去查证那个担心。';
  }
  if (reaction == '自然' && belief == '没成真' && aligned == '更靠近') {
    return '保留：反应自然、担心没成真、也更靠近你要的。可以固定下来，继续小步重复。';
  }
  if (aligned == '更靠近') {
    return '继续（有代价）：通向你要的，但有别扭或部分成真的担心。降低强度、拉长时间再试。';
  }
  return '再观察：证据还不够，再做几次，别急着下结论。';
}

final RegExp _crisisPattern = RegExp(
    r'不想活|想死|自杀|自残|结束生命|活着没(有)?意思|伤害自己|不如死了|了结自己');

/// 文字里是否出现绝望或自伤的迹象。出现就要停下重构，转向求助。
bool zCrisis(String text) => _crisisPattern.hasMatch(text);

final RegExp _fatalismPattern = RegExp(
    r'反正|注定|本性难移|改不了|天生就|没救了|一辈子就这样|就是这样的人|永远都');

/// 宿命式措辞的第一处匹配；没有返回 null。
String? zFatalism(String text) => _fatalismPattern.firstMatch(text)?.group(0);

/// 绳子的守住情况：序列里 'y' 守住、'n' 被破。
({int kept, int broken}) ropeStats(List<String> seq) {
  int k = 0, b = 0;
  for (final String s in seq) {
    if (s == 'y') k += 1;
    if (s == 'n') b += 1;
  }
  return (kept: k, broken: b);
}

/// 接受页：不可控的项是否可以给「必然性」的安慰。
/// 必须先写过绕开办法，并且确认它不会因为你的努力而改变。
bool acceptComfortAllowed({
  required int control,
  required String bypass,
  required bool confirmedFixed,
}) {
  return control == 2 && bypass.trim().isNotEmpty && confirmedFixed;
}

/// 同时进行的事项过多：进行中的计划、没出结论的假设行动、没完成的探测。
int activeThreads(ZhaojianControllerView c) => c.activePlans + c.activeAsif + c.activeProbes;

/// 给分散度提醒用的最小只读视图，避免纯函数依赖控制器。
class ZhaojianControllerView {
  const ZhaojianControllerView({
    required this.activePlans,
    required this.activeAsif,
    required this.activeProbes,
  });

  final int activePlans;
  final int activeAsif;
  final int activeProbes;
}
