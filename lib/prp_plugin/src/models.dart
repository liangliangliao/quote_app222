import 'dart:convert';

enum PrpSurface {
  enemy('enemy', '美丽的敌人'),
  behavior('behavior', '行为追踪'),
  failureModule('failure_module', '失败与完美主义'),
  kindling('kindling', '火种'),
  quoteHome('quote_home', '名人名言首页');

  const PrpSurface(this.key, this.label);
  final String key;
  final String label;

  static PrpSurface parse(String key) => values.firstWhere(
        (s) => s.key == key,
        orElse: () => failureModule,
      );
}

enum PrpStep { pause, ledger, columns, signal, seal, zoom, done }

enum PrpOutcome { pending, helped, repeated, ignored }

enum PrpSentenceKind { fact, interpretation, selfBlame }

class PrpSignal {
  const PrpSignal({
    required this.surface,
    required this.kind,
    required this.subjectKey,
    required this.expected,
    required this.tsMs,
    this.facts = const [],
    this.reference,
    this.category,
    this.confirmed = false,
  });

  final PrpSurface surface;
  final String kind;
  final String subjectKey;
  final String expected;
  final int tsMs;
  final List<String> facts;
  final String? reference;
  final String? category;

  /// Only an explicit user confirmation may turn missing data into a miss.
  final bool confirmed;
  String get dedupeKey => reference ?? '$subjectKey:$tsMs';
}

class PrpOffer {
  const PrpOffer({required this.sessionId, required this.signal});
  final int sessionId;
  final PrpSignal signal;
  String get voice => signal.surface == PrpSurface.enemy ? 'enemy' : 'neutral';
}

class PrpContext {
  const PrpContext({
    required this.surface,
    this.subjectKey,
    this.category,
    this.text = '',
    this.location = 'next_attempt',
    this.reference,
    this.occurredMs,
  });
  final PrpSurface surface;
  final String? subjectKey;
  final String? category;
  final String text;
  final String location;
  final String? reference;

  /// Explicit outcome time, to avoid applying a backdated check-in to a later recall.
  final int? occurredMs;
}

class PrpEvidence {
  const PrpEvidence({
    required this.source,
    required this.id,
    required this.label,
    this.kind = 'record',
  });
  final String source;
  final String id;
  final String label;
  final String kind;
  Map<String, dynamic> toJson() =>
      {'src': source, 'id': id, 'label': label, 'kind': kind};
  static PrpEvidence fromJson(Map<String, dynamic> m) => PrpEvidence(
        source: '${m['src'] ?? ''}',
        id: '${m['id'] ?? ''}',
        label: '${m['label'] ?? ''}',
        kind: '${m['kind'] ?? 'record'}',
      );
}

class PrpDayMark {
  const PrpDayMark({required this.dateMs, required this.status});
  final int dateMs;

  /// done / missed / unknown. Unknown is never counted as missed.
  final String status;
}

class PrpSentence {
  const PrpSentence(this.text, this.kind, {this.revision = ''});
  final String text;
  final PrpSentenceKind kind;
  final String revision;
  Map<String, dynamic> toJson() =>
      {'text': text, 'kind': kind.name, 'revision': revision};
  static PrpSentence fromJson(Map<String, dynamic> m) => PrpSentence(
        '${m['text'] ?? ''}',
        PrpSentenceKind.values.firstWhere(
          (k) => k.name == m['kind'],
          orElse: () => PrpSentenceKind.interpretation,
        ),
        revision: '${m['revision'] ?? ''}',
      );
}

class PrpLesson {
  const PrpLesson({
    this.id = 0,
    required this.subjectKey,
    required this.source,
    required this.createdMs,
    this.category = '其他',
    this.state = 'draft',
    this.worked = const [],
    this.failed = const [],
    this.triggerText = '',
    this.earlySignal = '',
    this.ifCue = '',
    this.thenAction = '',
    this.evidence = const [],
    this.sentences = const [],
    this.quality = 0,
    this.sealedMs,
    this.parentId,
    this.verifiedCount = 0,
    this.repeatedCount = 0,
    this.quoteAllowed = false,
    this.voicePath = '',
  });
  final int id;
  final String subjectKey;
  final PrpSurface source;
  final int createdMs;
  final String category;
  final String state;
  final List<String> worked;
  final List<String> failed;
  final String triggerText;
  final String earlySignal;
  final String ifCue;
  final String thenAction;
  final List<PrpEvidence> evidence;
  final List<PrpSentence> sentences;
  final int quality;
  final int? sealedMs;
  final int? parentId;
  final int verifiedCount;
  final int repeatedCount;
  final bool quoteAllowed;
  final String voicePath;

  String get rule => '如果$ifCue，我就$thenAction';
  bool get isSealed => state == 'sealed';

  PrpLesson copyWith({
    int? id,
    String? state,
    int? quality,
    int? sealedMs,
    bool? quoteAllowed,
    String? voicePath,
  }) =>
      PrpLesson(
        id: id ?? this.id,
        subjectKey: subjectKey,
        source: source,
        createdMs: createdMs,
        category: category,
        state: state ?? this.state,
        worked: worked,
        failed: failed,
        triggerText: triggerText,
        earlySignal: earlySignal,
        ifCue: ifCue,
        thenAction: thenAction,
        evidence: evidence,
        sentences: sentences,
        quality: quality ?? this.quality,
        sealedMs: sealedMs ?? this.sealedMs,
        parentId: parentId,
        verifiedCount: verifiedCount,
        repeatedCount: repeatedCount,
        quoteAllowed: quoteAllowed ?? this.quoteAllowed,
        voicePath: voicePath ?? this.voicePath,
      );

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'subject_key': subjectKey,
        'source': source.key,
        'created_ms': createdMs,
        'category': category,
        'state': state,
        'worked': jsonEncode(worked),
        'failed': jsonEncode(failed),
        'trigger_text': triggerText,
        'early_signal': earlySignal,
        'if_cue': ifCue,
        'then_action': thenAction,
        'evidence_refs': jsonEncode(evidence.map((e) => e.toJson()).toList()),
        'sentences_json': jsonEncode(sentences.map((s) => s.toJson()).toList()),
        'quality': quality,
        'sealed_ms': sealedMs,
        'parent_id': parentId,
        'verified_cnt': verifiedCount,
        'repeated_cnt': repeatedCount,
        'quote_allowed': quoteAllowed ? 1 : 0,
        'voice_path': voicePath,
      };

  static PrpLesson fromMap(Map<String, Object?> m) {
    List<dynamic> list(String key) => jsonDecode('${m[key] ?? '[]'}') as List;
    return PrpLesson(
      id: (m['id'] as num).toInt(),
      subjectKey: '${m['subject_key'] ?? ''}',
      source: PrpSurface.parse('${m['source']}'),
      createdMs: (m['created_ms'] as num).toInt(),
      category: '${m['category'] ?? '其他'}',
      state: '${m['state']}',
      worked: list('worked').cast<String>(),
      failed: list('failed').cast<String>(),
      triggerText: '${m['trigger_text'] ?? ''}',
      earlySignal: '${m['early_signal'] ?? ''}',
      ifCue: '${m['if_cue'] ?? ''}',
      thenAction: '${m['then_action'] ?? ''}',
      evidence: list('evidence_refs')
          .map((e) => PrpEvidence.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      sentences: list('sentences_json')
          .map((s) => PrpSentence.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      quality: (m['quality'] as num?)?.toInt() ?? 0,
      sealedMs: (m['sealed_ms'] as num?)?.toInt(),
      parentId: (m['parent_id'] as num?)?.toInt(),
      verifiedCount: (m['verified_cnt'] as num?)?.toInt() ?? 0,
      repeatedCount: (m['repeated_cnt'] as num?)?.toInt() ?? 0,
      quoteAllowed: m['quote_allowed'] == 1,
      voicePath: '${m['voice_path'] ?? ''}',
    );
  }
}

class PrpRecall {
  const PrpRecall(
      {required this.id, required this.lesson, required this.surface});
  final int id;
  final PrpLesson lesson;
  final PrpSurface surface;
}

class PrpQuote {
  const PrpQuote(
      {required this.lessonId, required this.text, required this.author});
  final int lessonId;
  final String text;
  final String author;
}

class PrpGuardResult {
  const PrpGuardResult(
      {this.crisis = false, this.truce = false, this.problems = const []});
  final bool crisis;
  final bool truce;
  final List<String> problems;
  bool get allowed => !crisis && !truce && problems.isEmpty;
}

class PrpGovernance {
  const PrpGovernance({this.quiet = false, this.muted = false});
  final bool quiet;
  final bool muted;
  bool get allows => !quiet && !muted;
}
