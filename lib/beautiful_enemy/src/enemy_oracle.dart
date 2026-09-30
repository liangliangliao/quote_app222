import 'copy.dart';

/// 一份判词草稿。还没校验、没入库。
class EnemyDraft {
  const EnemyDraft({
    required this.charge,
    required this.evidenceIds,
    required this.toneLevel,
    required this.lessonHint,
    required this.action,
    required this.actionDueMs,
    required this.appealPrompt,
    this.factOnly = false,
  });

  final String charge;
  final List<int> evidenceIds;
  final int toneLevel;
  final String lessonHint;
  final String action;
  final int actionDueMs;
  final String appealPrompt;
  final bool factOnly;
}

/// 判词生成器。宿主可以接模型；不接或模型不可用时用 [LocalFactOracle]。
///
/// 返回 null 表示“这次没产出”（不可用、超时、解析失败），引擎会重试或降级。
abstract class EnemyOracle {
  Future<EnemyDraft?> judge({
    required Map<String, dynamic> digest,
    required int intensity,
    required int nowMs,
  });
}

/// 纯本地：只陈列事实，不带语气。
class LocalFactOracle implements EnemyOracle {
  const LocalFactOracle();

  static const int _maxEvidence = 6;
  static const int _maxActionChars = 30;

  @override
  Future<EnemyDraft?> judge({
    required Map<String, dynamic> digest,
    required int intensity,
    required int nowMs,
  }) async {
    final Map<String, dynamic> habits = _map(digest['habits']);
    final Map<String, dynamic> commitments = _map(digest['commitments']);
    final Map<String, dynamic> kindling = _map(digest['kindling']);
    final Map<String, dynamic> knowledge = _map(digest['knowledge']);
    final Map<String, dynamic> journal = _map(digest['journal']);

    final List<String> parts = <String>[];
    if (_int(habits['done']) + _int(habits['missed']) + _int(habits['skipped']) > 0) {
      parts.add(_fmt(EnemyCopy.factHabits, <int>[
        _int(habits['done']),
        _int(habits['missed']),
        _int(habits['skipped']),
      ]));
    }
    if (_int(commitments['due']) > 0) {
      parts.add(_fmt(EnemyCopy.factCommitments, <int>[
        _int(commitments['due']),
        _int(commitments['done']),
        _int(commitments['missed']),
      ]));
    }
    if (_int(kindling['completed']) + _int(kindling['aborted']) > 0) {
      parts.add(_fmt(EnemyCopy.factKindling, <int>[
        _int(kindling['completed']),
        _int(kindling['aborted']),
      ]));
    }
    if (_int(knowledge['conversions']) > 0) {
      parts.add(_fmt(EnemyCopy.factKnowledge, <int>[_int(knowledge['conversions'])]));
    }
    if (_int(journal['entries']) > 0) {
      parts.add(_fmt(EnemyCopy.factJournal, <int>[_int(journal['entries'])]));
    }
    if (parts.isEmpty) return null;

    final List<int> evidence = _allEvidence(digest).take(_maxEvidence).toList();
    if (evidence.isEmpty) return null;

    return EnemyDraft(
      charge: '${parts.join('；')}。',
      evidenceIds: evidence,
      toneLevel: 0,
      lessonHint: '',
      action: _pickAction(habits, commitments, kindling),
      actionDueMs: nowMs + const Duration(hours: 2).inMilliseconds,
      appealPrompt: EnemyCopy.defaultAppealPrompt,
      factOnly: true,
    );
  }

  static String _pickAction(
    Map<String, dynamic> habits,
    Map<String, dynamic> commitments,
    Map<String, dynamic> kindling,
  ) {
    for (final Object? raw in _list(commitments['items'])) {
      final Map<String, dynamic> item = _map(raw);
      if (item['status'] == 'missed' || item['status'] == 'open') {
        return _clip('${EnemyCopy.actionCatchUp}${item['text'] ?? ''}');
      }
    }
    for (final Object? raw in _list(habits['items'])) {
      final Map<String, dynamic> item = _map(raw);
      if (item['status'] == 'missed') {
        return _clip('${EnemyCopy.actionCatchUp}${item['name'] ?? ''}');
      }
    }
    if (_int(kindling['completed']) == 0) return EnemyCopy.actionKindling;
    return EnemyCopy.actionWriteCommitment;
  }

  static String _clip(String s) {
    final String t = s.trim();
    if (t.length <= _maxActionChars) return t;
    return t.substring(0, _maxActionChars);
  }

  static List<int> _allEvidence(Map<String, dynamic> digest) {
    final List<Object?> raw = _list(digest['evidence_ids']);
    return raw.whereType<num>().map((num n) => n.toInt()).toList();
  }

  static String _fmt(String template, List<int> args) {
    String out = template;
    for (final int a in args) {
      out = out.replaceFirst('%d', '$a');
    }
    return out;
  }
}

Map<String, dynamic> _map(Object? v) {
  if (v is Map) {
    return v.map((Object? k, Object? val) => MapEntry(k.toString(), val));
  }
  return <String, dynamic>{};
}

List<Object?> _list(Object? v) => v is List ? v.cast<Object?>() : <Object?>[];

int _int(Object? v) => v is num ? v.toInt() : 0;
