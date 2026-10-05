import 'dart:convert';

/// 一条证据事件。来源模块只负责“发生了什么”，不带任何评价。
class EnemyEvent {
  const EnemyEvent({
    required this.id,
    required this.ts,
    required this.source,
    required this.type,
    required this.payload,
  });

  final int id;

  /// 事件真实发生的时间（毫秒）。
  final int ts;

  /// 来源，例如 habit / kindling / knowledge / journal / commitment。
  final String source;
  final String type;
  final Map<String, dynamic> payload;

  String get day => (payload['day'] ?? '').toString();
  String get subject => (payload['subject'] ?? '').toString();
  String get label => (payload['label'] ?? '').toString();

  factory EnemyEvent.fromMap(Map<String, Object?> row) {
    Map<String, dynamic> payload = <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode((row['payload'] ?? '{}').toString());
      if (decoded is Map) {
        payload = decoded.map((Object? k, Object? v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      payload = <String, dynamic>{};
    }
    return EnemyEvent(
      id: (row['id'] as num).toInt(),
      ts: (row['ts'] as num).toInt(),
      source: (row['source'] ?? '').toString(),
      type: (row['type'] ?? '').toString(),
      payload: payload,
    );
  }
}

/// 等待写入的事件草稿。[dedupeKey] 相同的事件只会入库一次。
class EventDraft {
  const EventDraft({
    required this.ts,
    required this.source,
    required this.type,
    required this.dedupeKey,
    this.payload = const <String, dynamic>{},
  });

  final int ts;
  final String source;
  final String type;
  final String dedupeKey;
  final Map<String, dynamic> payload;
}

class CommitmentStatus {
  const CommitmentStatus._();
  static const String open = 'open';
  static const String done = 'done';
  static const String missed = 'missed';
  static const String excused = 'excused';
}

class EnemyCommitment {
  const EnemyCommitment({
    required this.id,
    required this.text,
    required this.createdMs,
    required this.dueMs,
    required this.status,
    required this.origin,
    this.verdictId,
    this.stake = '',
  });

  final int id;
  final String text;
  final int createdMs;
  final int? dueMs;
  final String status;

  /// 赌注：输了要兑现的一个行动。空表示没有赌注。
  final String stake;

  /// manual / verdict
  final String origin;
  final int? verdictId;

  bool isOverdue(int nowMs) =>
      status == CommitmentStatus.open && dueMs != null && dueMs! < nowMs;

  factory EnemyCommitment.fromMap(Map<String, Object?> row) {
    return EnemyCommitment(
      id: (row['id'] as num).toInt(),
      text: (row['text'] ?? '').toString(),
      createdMs: (row['created_ms'] as num).toInt(),
      dueMs: (row['due_ms'] as num?)?.toInt(),
      status: (row['status'] ?? CommitmentStatus.open).toString(),
      origin: (row['origin'] ?? 'manual').toString(),
      verdictId: (row['verdict_id'] as num?)?.toInt(),
      stake: (row['stake'] ?? '').toString(),
    );
  }
}

class VerdictResponse {
  const VerdictResponse._();
  static const String pending = 'pending';
  static const String ack = 'ack';
  static const String appeal = 'appeal';
  static const String ignored = 'ignored';
}

class EnemyVerdict {
  const EnemyVerdict({
    required this.id,
    required this.ts,
    required this.trigger,
    required this.intensity,
    required this.charge,
    required this.evidenceIds,
    required this.lessonHint,
    required this.action,
    required this.actionDueMs,
    required this.appealPrompt,
    required this.userResponse,
    required this.appealText,
    required this.outcome,
    required this.outcomeMs,
    required this.commitmentId,
    required this.factOnly,
  });

  final int id;
  final int ts;
  final String trigger;

  /// 实际生效的档位（0 表示纯事实播报）。
  final int intensity;
  final String charge;
  final List<int> evidenceIds;
  final String lessonHint;
  final String action;
  final int actionDueMs;
  final String appealPrompt;
  final String userResponse;
  final String appealText;

  /// pending / done / missed / excused
  final String outcome;
  final int? outcomeMs;
  final int? commitmentId;

  /// true 表示这条判词是本地按事实拼出来的（模型不可用或输出不合规）。
  final bool factOnly;

  factory EnemyVerdict.fromMap(Map<String, Object?> row) {
    List<int> ids = <int>[];
    try {
      final Object? decoded = jsonDecode((row['evidence_ids'] ?? '[]').toString());
      if (decoded is List) {
        ids = decoded.whereType<num>().map((num n) => n.toInt()).toList();
      }
    } catch (_) {
      ids = <int>[];
    }
    return EnemyVerdict(
      id: (row['id'] as num).toInt(),
      ts: (row['ts'] as num).toInt(),
      trigger: (row['trigger'] ?? '').toString(),
      intensity: (row['intensity'] as num?)?.toInt() ?? 0,
      charge: (row['charge'] ?? '').toString(),
      evidenceIds: ids,
      lessonHint: (row['lesson_hint'] ?? '').toString(),
      action: (row['action'] ?? '').toString(),
      actionDueMs: (row['action_due_ms'] as num).toInt(),
      appealPrompt: (row['appeal_prompt'] ?? '').toString(),
      userResponse: (row['user_response'] ?? VerdictResponse.pending).toString(),
      appealText: (row['appeal_text'] ?? '').toString(),
      outcome: (row['outcome'] ?? 'pending').toString(),
      outcomeMs: (row['outcome_ms'] as num?)?.toInt(),
      commitmentId: (row['commitment_id'] as num?)?.toInt(),
      factOnly: ((row['fact_only'] as num?)?.toInt() ?? 0) == 1,
    );
  }
}

class EnemyLesson {
  const EnemyLesson({
    required this.id,
    required this.verdictId,
    required this.category,
    required this.reasonText,
    required this.lesson,
    required this.createdMs,
    required this.timesRepeated,
  });

  final int id;
  final int? verdictId;
  final String category;
  final String reasonText;
  final String lesson;
  final int createdMs;
  final int timesRepeated;

  factory EnemyLesson.fromMap(Map<String, Object?> row) {
    return EnemyLesson(
      id: (row['id'] as num).toInt(),
      verdictId: (row['verdict_id'] as num?)?.toInt(),
      category: (row['category'] ?? '').toString(),
      reasonText: (row['reason_text'] ?? '').toString(),
      lesson: (row['lesson'] ?? '').toString(),
      createdMs: (row['created_ms'] as num).toInt(),
      timesRepeated: (row['times_repeated'] as num?)?.toInt() ?? 1,
    );
  }
}

class MessageRole {
  const MessageRole._();
  static const String user = 'user';
  static const String enemy = 'enemy';
}

class MessageKind {
  const MessageKind._();

  /// 日常对话（含开场白）。
  static const String chat = 'chat';

  /// 开庭产生的判词，refId 指向 be_verdict。
  static const String verdict = 'verdict';

  /// 敌人主动插话，refId 指向触发它的事件。
  static const String interject = 'interject';

  /// 敌人退场（安全阀 / 停战）。
  static const String exit = 'exit';

  /// 自检页上的演练。不算插话：不占每日上限。
  static const String drill = 'drill';
}

/// 对峙页里的一条消息。判词、插话、对话统一在同一条时间线上。
class EnemyMessage {
  const EnemyMessage({
    required this.id,
    required this.ts,
    required this.role,
    required this.kind,
    required this.text,
    this.refId,
    this.tone = 0,
  });

  final int id;
  final int ts;
  final String role;
  final String kind;
  final String text;
  final int? refId;
  final int tone;

  bool get fromEnemy => role == MessageRole.enemy;

  factory EnemyMessage.fromMap(Map<String, Object?> row) {
    return EnemyMessage(
      id: (row['id'] as num).toInt(),
      ts: (row['ts'] as num).toInt(),
      role: (row['role'] ?? MessageRole.enemy).toString(),
      kind: (row['kind'] ?? MessageKind.chat).toString(),
      text: (row['text'] ?? '').toString(),
      refId: (row['ref_id'] as num?)?.toInt(),
      tone: (row['tone'] as num?)?.toInt() ?? 0,
    );
  }
}
