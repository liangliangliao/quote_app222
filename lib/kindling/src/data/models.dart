/// 纯数据类。不含任何 UI、SQL 或格式化逻辑。
library;

/// 火种类别。仅用于内部标注来源，不在界面上展示。
class KKind {
  const KKind._();

  static const String recall = 'recall';
  static const String itch = 'itch';
  static const String defiance = 'defiance';
  static const String repair = 'repair';
  static const String curiosity = 'curiosity';
  static const String shelter = 'shelter';
  static const String other = 'other';

  static const List<String> all = <String>[
    recall,
    itch,
    defiance,
    repair,
    curiosity,
    shelter,
    other,
  ];

  static String normalize(String? raw) {
    if (raw == null) return other;
    return all.contains(raw) ? raw : other;
  }
}

/// 判别式回答。
class KVerdictAnswer {
  const KVerdictAnswer._();

  static const String yes = 'yes';
  static const String no = 'no';
  static const String unsure = 'unsure';
}

/// 回溯三问的 key。
class KRecallQuestion {
  const KRecallQuestion._();

  static const String lostTrack = 'lost_track';
  static const String itch = 'itch';
  static const String envy = 'envy';

  static const List<String> ordered = <String>[lostTrack, itch, envy];
}

int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _intOrNull(Object? v) {
  if (v == null) return null;
  return _int(v);
}

String _str(Object? v, [String fallback = '']) {
  if (v is String) return v;
  if (v == null) return fallback;
  return v.toString();
}

String? _strOrNull(Object? v) {
  if (v == null) return null;
  final String s = _str(v);
  return s.isEmpty ? null : s;
}

DateTime _time(Object? v) =>
    DateTime.fromMillisecondsSinceEpoch(_int(v)).toLocal();

DateTime? _timeOrNull(Object? v) {
  final int? ms = _intOrNull(v);
  if (ms == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
}

/// 一条火种。
class KItem {
  const KItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.releasedAt,
    this.releaseNote,
  });

  final int id;
  final String title;
  final String kind;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? releasedAt;
  final String? releaseNote;

  bool get isReleased => releasedAt != null;

  factory KItem.fromRow(Map<String, Object?> row) {
    return KItem(
      id: _int(row['id']),
      title: _str(row['title']),
      kind: KKind.normalize(_strOrNull(row['kind'])),
      note: _strOrNull(row['note']),
      createdAt: _time(row['created_at']),
      updatedAt: _time(row['updated_at']),
      releasedAt: _timeOrNull(row['released_at']),
      releaseNote: _strOrNull(row['release_note']),
    );
  }
}

/// 痒度自评。分值 0..4，永不展示给用户。
class KProbe {
  const KProbe({
    required this.id,
    required this.itemId,
    required this.score,
    required this.recordedAt,
  });

  final int id;
  final int itemId;
  final int score;
  final DateTime recordedAt;

  factory KProbe.fromRow(Map<String, Object?> row) => KProbe(
        id: _int(row['id']),
        itemId: _int(row['item_id']),
        score: _int(row['score']),
        recordedAt: _time(row['recorded_at']),
      );
}

/// 判别式结果。
class KVerdict {
  const KVerdict({
    required this.id,
    required this.itemId,
    required this.answer,
    required this.decidedAt,
  });

  final int id;
  final int itemId;
  final String answer;
  final DateTime decidedAt;

  factory KVerdict.fromRow(Map<String, Object?> row) => KVerdict(
        id: _int(row['id']),
        itemId: _int(row['item_id']),
        answer: _str(row['answer'], KVerdictAnswer.unsure),
        decidedAt: _time(row['decided_at']),
      );
}

/// 一次十五分钟。不记录连续天数。
class KBurn {
  const KBurn({
    required this.id,
    required this.itemId,
    required this.startedAt,
    required this.seconds,
    required this.aborted,
    this.wantMore,
  });

  final int id;
  final int itemId;
  final DateTime startedAt;
  final int seconds;
  final bool aborted;

  /// true=想 / false=不想 / null=未答。
  final bool? wantMore;

  factory KBurn.fromRow(Map<String, Object?> row) {
    final int? want = _intOrNull(row['want_more']);
    return KBurn(
      id: _int(row['id']),
      itemId: _int(row['item_id']),
      startedAt: _time(row['started_at']),
      seconds: _int(row['seconds']),
      aborted: _int(row['aborted']) == 1,
      wantMore: want == null ? null : want == 1,
    );
  }
}

/// 回溯会话里保留的原话。
class KRecallAnswer {
  const KRecallAnswer({
    required this.id,
    required this.questionKey,
    required this.rawText,
    required this.createdAt,
  });

  final int id;
  final String questionKey;
  final String rawText;
  final DateTime createdAt;

  factory KRecallAnswer.fromRow(Map<String, Object?> row) => KRecallAnswer(
        id: _int(row['id']),
        questionKey: _str(row['question_key']),
        rawText: _str(row['raw_text']),
        createdAt: _time(row['created_at']),
      );
}

/// 阻抗追问的一步。
class KResistanceStep {
  const KResistanceStep({
    required this.id,
    required this.step,
    required this.question,
    required this.createdAt,
    this.itemId,
    this.answer,
  });

  final int id;
  final int? itemId;
  final int step;
  final String question;
  final String? answer;
  final DateTime createdAt;

  factory KResistanceStep.fromRow(Map<String, Object?> row) => KResistanceStep(
        id: _int(row['id']),
        itemId: _intOrNull(row['item_id']),
        step: _int(row['step']),
        question: _str(row['question']),
        answer: _strOrNull(row['answer']),
        createdAt: _time(row['created_at']),
      );
}

/// 列表用的聚合视图：火种本体 + 排序所需信号。
///
/// 这些信号只喂给 heat()，任何一项都不得渲染成数字、星级或颜色深浅。
class KItemView {
  const KItemView({
    required this.item,
    required this.burnTotal,
    required this.wantMoreCount,
    required this.consecutiveNoCount,
    this.latestProbe,
    this.probeAt,
    this.lastBurnAt,
    this.verdict,
    this.verdictAt,
  });

  final KItem item;
  final int? latestProbe;
  final DateTime? probeAt;
  final int burnTotal;
  final int wantMoreCount;
  final DateTime? lastBurnAt;
  final String? verdict;
  final DateTime? verdictAt;

  /// 最近连续答「不想」的次数。达到 3 时，长按菜单把「放掉」置顶。
  final int consecutiveNoCount;

  int get id => item.id;
  String get title => item.title;

  /// 是否该把「放掉」置顶（不主动弹窗劝退）。
  bool get suggestRelease => consecutiveNoCount >= 3;
}
