import 'json_util.dart';

/// 不允许出现在 AI 分析结论里的措辞：医疗诊断、外貌体型、宿命式。
/// 命中就丢掉那一条，而不是改写它。
final RegExp _bannedInAnalysis = RegExp(
    r'诊断|抑郁症|焦虑症|人格障碍|强迫症|多动症|自闭|精神病|双相|长相|相貌|体型|身材|注定|一辈子|本性难移|天生就|改不了|永远都');

/// 一条暂定的行为模式假设。
class ZPattern {
  const ZPattern(this.t, this.ev, this.tier, this.phase);

  /// 假设的内容。
  final String t;

  /// 依据。
  final String ev;

  /// 证据等级：强 / 中 / 弱。
  final String tier;

  /// 跨人生阶段的情况，可为空。
  final String phase;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'t': t, 'ev': ev, 'tier': tier, 'phase': phase};
}

/// 一个「还没被检验」的情境，以及可以预先系的绳子。
class ZUntested {
  const ZUntested(this.sit, this.rope);

  final String sit;
  final String rope;

  Map<String, dynamic> toJson() => <String, dynamic>{'sit': sit, 'rope': rope};
}

/// AI 分析的结果。
class ZAnalysis {
  const ZAnalysis({
    this.patterns = const <ZPattern>[],
    this.untested = const <ZUntested>[],
    this.compare = '',
    this.dropped = 0,
  });

  final List<ZPattern> patterns;
  final List<ZUntested> untested;

  /// 与上一版的比较。
  final String compare;

  /// 因措辞不合规被丢掉的条数。
  final int dropped;

  bool get isEmpty => patterns.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'patterns': patterns.map((ZPattern p) => p.toJson()).toList(),
        'untested': untested.map((ZUntested u) => u.toJson()).toList(),
        'compare': compare,
      };

  factory ZAnalysis.fromJson(Map<String, dynamic> j) {
    final List<ZPattern> ps = <ZPattern>[];
    final dynamic pr = j['patterns'];
    if (pr is List) {
      for (final dynamic e in pr) {
        if (e is Map) {
          ps.add(ZPattern('${e['t'] ?? ''}', '${e['ev'] ?? ''}',
              '${e['tier'] ?? '弱'}', '${e['phase'] ?? ''}'));
        }
      }
    }
    final List<ZUntested> us = <ZUntested>[];
    final dynamic un = j['untested'];
    if (un is List) {
      for (final dynamic e in un) {
        if (e is Map) us.add(ZUntested('${e['sit'] ?? ''}', '${e['rope'] ?? ''}'));
      }
    }
    return ZAnalysis(patterns: ps, untested: us, compare: '${j['compare'] ?? ''}');
  }
}

/// 解析模型返回的分析：规整证据等级、限制条数、丢掉不合规的措辞。解析失败返回空结果。
ZAnalysis parseAnalysis(String raw) {
  final Map<String, dynamic>? o = zParseObject(raw);
  if (o == null) return const ZAnalysis();
  int dropped = 0;
  final List<ZPattern> ps = <ZPattern>[];
  final dynamic pr = o['patterns'];
  if (pr is List) {
    for (final dynamic e in pr) {
      if (e is! Map) continue;
      final String t = '${e['t'] ?? ''}'.trim();
      if (t.isEmpty) continue;
      final String ev = '${e['ev'] ?? ''}'.trim();
      final String phase = '${e['phase'] ?? ''}'.trim();
      if (_bannedInAnalysis.hasMatch('$t$ev$phase')) {
        dropped += 1;
        continue;
      }
      final String tier = '${e['tier'] ?? ''}'.trim();
      ps.add(ZPattern(t, ev, <String>['强', '中', '弱'].contains(tier) ? tier : '弱', phase));
    }
  }
  final List<ZUntested> us = <ZUntested>[];
  final dynamic un = o['untested'];
  if (un is List) {
    for (final dynamic e in un) {
      if (e is! Map) continue;
      final String sit = '${e['sit'] ?? ''}'.trim();
      final String rope = '${e['rope'] ?? ''}'.trim();
      if (sit.isEmpty) continue;
      if (_bannedInAnalysis.hasMatch('$sit$rope')) {
        dropped += 1;
        continue;
      }
      us.add(ZUntested(sit, rope));
    }
  }
  final String cmp = '${o['compare'] ?? ''}'.trim();
  return ZAnalysis(
    patterns: ps.take(5).toList(),
    untested: us.take(3).toList(),
    compare: _bannedInAnalysis.hasMatch(cmp) ? '' : cmp,
    dropped: dropped,
  );
}
