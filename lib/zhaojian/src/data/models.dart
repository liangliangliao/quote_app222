import 'dart:convert';

import '../copy.dart';

/// 一条动机卡。
class ZMotive {
  ZMotive({
    required this.text,
    required this.cat,
    required this.kind,
    this.side = 'both',
    this.valence = 'ap',
    this.weight = 0,
    this.scene = '',
    this.imagery = const <String>[],
    this.rated = false,
    this.ai = false,
    this.own = false,
  });

  /// 动机文字。
  final String text;

  /// 类别序号，对应 [ZCopy.categories]；自己写的动机用 -1。
  final int cat;

  /// 'abs' 抽象 / 'int' 直观。
  final String kind;

  /// 它把人拉向哪边：'a' / 'b' / 'both'。
  String side;

  /// 'ap' 想要靠近 / 'av' 害怕回避。
  String valence;

  /// 此刻的分量 0 到 5。
  int weight;

  /// 「画面」：让人能感到这个动机的一句话。
  String scene;

  /// 用户真的想象到的画面维度。
  List<String> imagery;

  /// 用户是否已经评过这张卡。
  bool rated;

  /// 是否来自 AI 补全。
  final bool ai;

  /// 是否是用户自己写的。
  final bool own;

  bool get isAbstract => kind == 'abs';

  factory ZMotive.fromLibrary(int cat, String text) {
    final String tpl = ZCopy.sceneTemplates[cat];
    return ZMotive(
      text: text,
      cat: cat,
      kind: ZCopy.abstractCategories.contains(cat) ? 'abs' : 'int',
      valence: ZCopy.avoidanceCategories.contains(cat) ? 'av' : 'ap',
      scene: tpl.replaceAll('{t}', text),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        't': text,
        'c': cat,
        'k': kind,
        's': side,
        'y': valence,
        'w': weight,
        'v': scene,
        'im': imagery,
        'r': rated,
        'ai': ai,
        'own': own,
      };

  factory ZMotive.fromJson(Map<String, dynamic> j) {
    final dynamic im = j['im'];
    return ZMotive(
      text: (j['t'] ?? '').toString(),
      cat: j['c'] is int ? j['c'] as int : -1,
      kind: j['k'] == 'abs' ? 'abs' : 'int',
      side: (j['s'] == 'a' || j['s'] == 'b') ? j['s'] as String : 'both',
      valence: j['y'] == 'av' ? 'av' : 'ap',
      weight: j['w'] is int ? j['w'] as int : 0,
      scene: (j['v'] ?? '').toString(),
      imagery: im is List
          ? im.map((dynamic e) => e.toString()).toList()
          : <String>[],
      rated: j['r'] == true,
      ai: j['ai'] == true,
      own: j['own'] == true,
    );
  }

  static String encodeList(List<ZMotive> list) =>
      jsonEncode(list.map((ZMotive m) => m.toJson()).toList());

  static List<ZMotive> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return <ZMotive>[];
    try {
      final dynamic v = jsonDecode(raw);
      if (v is! List) return <ZMotive>[];
      return v
          .whereType<Map>()
          .map((Map e) => ZMotive.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return <ZMotive>[];
    }
  }
}

List<String> _decodeStrings(String? raw) {
  if (raw == null || raw.isEmpty) return <String>[];
  try {
    final dynamic v = jsonDecode(raw);
    if (v is! List) return <String>[];
    return v.map((dynamic e) => e.toString()).toList();
  } catch (_) {
    return <String>[];
  }
}

List<int> _decodeInts(String? raw) {
  if (raw == null || raw.isEmpty) return <int>[];
  try {
    final dynamic v = jsonDecode(raw);
    if (v is! List) return <int>[];
    return v.whereType<num>().map((num e) => e.toInt()).toList();
  } catch (_) {
    return <int>[];
  }
}

/// 一次决策：从封存预测到开牌。
class ZDecision {
  ZDecision({
    this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    this.importance = '',
    this.motives = const <ZMotive>[],
    required this.pred,
    required this.stake,
    this.feltFreedom,
    this.condition = '',
    this.jtPred,
    this.conflictType = 0,
    required this.sealedAt,
    this.actual,
    this.actualAt,
    this.reaction,
    this.body = const <String>[],
    this.jtActual,
    this.hypId,
    this.hypKind,
    this.missLogged = false,
    this.notes = const <String>[],
    this.imageryDepth,
    this.imagerySymmetry,
  });

  int? id;
  final String question;
  final String optionA;
  final String optionB;

  /// 小 / 中 / 大 / 空。
  final String importance;

  /// 评过分（分量大于 0）的动机，和自己写的动机。
  final List<ZMotive> motives;

  /// 封存的预测：'a' / 'b'。
  final String pred;

  /// 押注筹码 1 到 5（虚拟）。
  final int stake;

  /// 封存时记录的「两边都有可能」的感觉 0 到 10；没记就是 null。
  final int? feltFreedom;

  /// 「我在等什么条件出现」。
  final String condition;

  /// 预计的决定方式（詹姆斯五种，下标）。
  final int? jtPred;

  /// 勒温/米勒冲突类型，下标，对应 [ZCopy.conflictTypes]。
  final int conflictType;

  final DateTime sealedAt;

  /// 开牌后的实际结果。
  String? actual;
  DateTime? actualAt;
  String? reaction;
  List<String> body;
  int? jtActual;
  int? hypId;
  String? hypKind;
  bool missLogged;

  /// 后果的尽头 / 深信的信念 / 过去怎么做 三段笔记。
  final List<String> notes;

  /// 想象深度（平均每张卡点了几项画面）与两边的对称度。
  final double? imageryDepth;
  final double? imagerySymmetry;

  bool get revealed => actual != null;
  bool get hit => actual != null && actual == pred;

  Map<String, Object?> toRow() => <String, Object?>{
        if (id != null) 'id': id,
        'question': question,
        'option_a': optionA,
        'option_b': optionB,
        'importance': importance,
        'motives_json': ZMotive.encodeList(motives),
        'pred': pred,
        'stake': stake,
        'felt_freedom': feltFreedom,
        'condition_text': condition,
        'jt_pred': jtPred,
        'conflict_type': conflictType,
        'sealed_at': sealedAt.millisecondsSinceEpoch,
        'actual': actual,
        'actual_at': actualAt?.millisecondsSinceEpoch,
        'reaction': reaction,
        'body_json': jsonEncode(body),
        'jt_actual': jtActual,
        'hyp_id': hypId,
        'hyp_kind': hypKind,
        'miss_logged': missLogged ? 1 : 0,
        'notes_json': jsonEncode(notes),
        'imagery_depth': imageryDepth,
        'imagery_sym': imagerySymmetry,
      };

  factory ZDecision.fromRow(Map<String, Object?> r) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    double? asDouble(Object? v) => v is num ? v.toDouble() : null;
    final int sealed = asInt(r['sealed_at']) ?? 0;
    final int? actualMs = asInt(r['actual_at']);
    return ZDecision(
      id: asInt(r['id']),
      question: (r['question'] ?? '').toString(),
      optionA: (r['option_a'] ?? '').toString(),
      optionB: (r['option_b'] ?? '').toString(),
      importance: (r['importance'] ?? '').toString(),
      motives: ZMotive.decodeList(r['motives_json'] as String?),
      pred: (r['pred'] ?? 'a').toString(),
      stake: asInt(r['stake']) ?? 1,
      feltFreedom: asInt(r['felt_freedom']),
      condition: (r['condition_text'] ?? '').toString(),
      jtPred: asInt(r['jt_pred']),
      conflictType: asInt(r['conflict_type']) ?? 0,
      sealedAt: DateTime.fromMillisecondsSinceEpoch(sealed),
      actual: r['actual'] as String?,
      actualAt:
          actualMs == null ? null : DateTime.fromMillisecondsSinceEpoch(actualMs),
      reaction: r['reaction'] as String?,
      body: _decodeStrings(r['body_json'] as String?),
      jtActual: asInt(r['jt_actual']),
      hypId: asInt(r['hyp_id']),
      hypKind: r['hyp_kind'] as String?,
      missLogged: asInt(r['miss_logged']) == 1,
      notes: _decodeStrings(r['notes_json'] as String?),
      imageryDepth: asDouble(r['imagery_depth']),
      imagerySymmetry: asDouble(r['imagery_sym']),
    );
  }
}

/// 随手记的一次行为。
class ZLog {
  ZLog({
    this.id,
    required this.what,
    required this.reaction,
    this.deliberate = '',
    this.typical = '',
    this.body = const <String>[],
    this.hypId,
    this.hypKind,
    required this.createdAt,
  });

  int? id;
  final String what;
  final String reaction;

  /// 思虑过 / 一时冲动 / 空。
  final String deliberate;

  /// 大多数人也会 / 大多数人不会 / 空。
  final String typical;
  final List<String> body;
  final int? hypId;

  /// 'sup' 表达了它 / 'ref' 背离了它。
  final String? hypKind;
  final DateTime createdAt;

  Map<String, Object?> toRow() => <String, Object?>{
        if (id != null) 'id': id,
        'what': what,
        'reaction': reaction,
        'deliberate': deliberate,
        'typical': typical,
        'body_json': jsonEncode(body),
        'hyp_id': hypId,
        'hyp_kind': hypKind,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ZLog.fromRow(Map<String, Object?> r) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    return ZLog(
      id: asInt(r['id']),
      what: (r['what'] ?? '').toString(),
      reaction: (r['reaction'] ?? '').toString(),
      deliberate: (r['deliberate'] ?? '').toString(),
      typical: (r['typical'] ?? '').toString(),
      body: _decodeStrings(r['body_json'] as String?),
      hypId: asInt(r['hyp_id']),
      hypKind: r['hyp_kind'] as String?,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(asInt(r['created_at']) ?? 0),
    );
  }
}

/// 一条「主线」假设：只有被后来的行为反复支持，才算认识了自己的一部分。
class ZHypothesis {
  ZHypothesis({
    this.id,
    required this.text,
    this.test = '',
    List<int>? sup,
    List<int>? ref,
    this.status = 0,
    required this.createdAt,
  })  : sup = sup ?? <int>[],
        ref = ref ?? <int>[];

  int? id;
  final String text;

  /// 检验：下次遇到什么情境，预计会怎么做。
  final String test;

  /// 支持、反驳的时间戳（毫秒）。
  final List<int> sup;
  final List<int> ref;

  /// 0 待验证 / 1 被行为支持 / 2 被行为反驳。
  int status;
  final DateTime createdAt;

  Map<String, Object?> toRow() => <String, Object?>{
        if (id != null) 'id': id,
        'text': text,
        'test': test,
        'sup_json': jsonEncode(sup),
        'ref_json': jsonEncode(ref),
        'status': status,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ZHypothesis.fromRow(Map<String, Object?> r) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    return ZHypothesis(
      id: asInt(r['id']),
      text: (r['text'] ?? '').toString(),
      test: (r['test'] ?? '').toString(),
      sup: _decodeInts(r['sup_json'] as String?),
      ref: _decodeInts(r['ref_json'] as String?),
      status: asInt(r['status']) ?? 0,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(asInt(r['created_at']) ?? 0),
    );
  }
}

/// 开牌时登记的「天平漏掉的动机」。
class ZMiss {
  ZMiss({
    this.id,
    required this.cat,
    required this.text,
    this.decisionId,
    required this.createdAt,
  });

  int? id;

  /// 类别序号；没选类别为 -1。
  final int cat;
  final String text;
  final int? decisionId;
  final DateTime createdAt;

  Map<String, Object?> toRow() => <String, Object?>{
        if (id != null) 'id': id,
        'cat': cat,
        'text': text,
        'decision_id': decisionId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ZMiss.fromRow(Map<String, Object?> r) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    return ZMiss(
      id: asInt(r['id']),
      cat: asInt(r['cat']) ?? -1,
      text: (r['text'] ?? '').toString(),
      decisionId: asInt(r['decision_id']),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(asInt(r['created_at']) ?? 0),
    );
  }
}
