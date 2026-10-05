/// 核对用户的话和案卷是否对得上——「寻找真相」的最小实现：
/// 不猜动机，不下结论，只指出「账上有」或「账上没有」。
enum ClaimKind {
  /// 没有可核对的说法。
  none,

  /// 说做完了，但案卷里最近 24 小时没有任何完成记录。
  doneWithoutRecord,

  /// 说做完了，案卷里确实有完成记录。
  doneWithRecord,

  /// 说没时间，但今天在 App 里待了不短的时间。
  busyButOnline,
}

class ClaimAssessment {
  const ClaimAssessment(this.kind, {this.hint = '', this.minutes = 0, this.records = 0});

  final ClaimKind kind;

  /// 追加给模型的情境提示。
  final String hint;
  final int minutes;
  final int records;

  static const ClaimAssessment none = ClaimAssessment(ClaimKind.none);
}

class ClaimCheck {
  const ClaimCheck._();

  static const List<String> doneClaims = <String>[
    '做完了', '完成了', '搞定了', '搞定', '做好了', '弄完了', '写完了', '译完了', '跑完了', '练完了', '已经做了',
  ];

  static const List<String> busyClaims = <String>[
    '没时间', '太忙', '忙死了', '顾不上', '没空', '抽不出时间',
  ];

  /// 今天在 App 里待多久以上，「没时间」就值得被拿出来对一对。
  static const int busyMinutesThreshold = 30;

  static ClaimAssessment assess(String text, Map<String, dynamic> digest) {
    final String t = text.replaceAll(RegExp(r'\s'), '');
    if (t.isEmpty) return ClaimAssessment.none;

    final bool claimsDone = doneClaims.any(t.contains);
    final bool claimsBusy = busyClaims.any(t.contains);

    if (claimsDone) {
      final int records = _doneRecords(digest);
      if (records == 0) {
        return const ClaimAssessment(
          ClaimKind.doneWithoutRecord,
          hint: '他声称做完了某件事，但案卷里最近 24 小时没有任何完成记录。'
              '盘问他：做的是什么、几点做的、为什么没有记录。'
              '不要说他撒谎，只指出账上没有。',
        );
      }
      return ClaimAssessment(
        ClaimKind.doneWithRecord,
        records: records,
        hint: '他声称做完了某件事，案卷里最近 24 小时有 $records 条完成记录。'
            '核对他说的是不是其中一条；对得上就干脆认账，对不上就问清楚。',
      );
    }

    if (claimsBusy) {
      final int minutes = _usageMinutes(digest);
      if (minutes >= busyMinutesThreshold) {
        return ClaimAssessment(
          ClaimKind.busyButOnline,
          minutes: minutes,
          hint: '他说没时间，但今天他在这个 App 里待了 $minutes 分钟。'
              '把这个数字摆给他看，问这段时间花在了哪里。不评价他这个人。',
        );
      }
    }
    return ClaimAssessment.none;
  }

  static int _doneRecords(Map<String, dynamic> digest) {
    int sum = 0;
    sum += _int(_map(digest['habits'])['done']);
    sum += _int(_map(digest['kindling'])['completed']);
    sum += _int(_map(digest['commitments'])['done']);
    sum += _int(_map(digest['knowledge'])['conversions']);
    return sum;
  }

  static int _usageMinutes(Map<String, dynamic> digest) =>
      _int(_map(digest['usage'])['minutes_today']);

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? v.map((Object? k, Object? val) => MapEntry(k.toString(), val)) : <String, dynamic>{};

  static int _int(Object? v) => v is num ? v.toInt() : 0;
}
