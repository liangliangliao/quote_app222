import '../models/quote_insight.dart';

enum CognitiveTask { diary, concept, calibration, reflection, review }

enum StatementKind {
  reportedEvent('用户报告的事件'),
  feeling('主观感受'),
  interpretation('一种解释'),
  judgment('暂定判断'),
  evidence('所引根据 · 待核对'),
  prediction('待验证预测'),
  unresolved('尚待区分');

  const StatementKind(this.label);
  final String label;
  static StatementKind parse(String value) => switch (value) {
        'reported_event' || 'reportedEvent' || 'fact' => reportedEvent,
        'feeling' => feeling,
        'interpretation' => interpretation,
        'judgment' => judgment,
        'evidence' => evidence,
        'prediction' => prediction,
        _ => unresolved,
      };
}

enum GroundLens {
  time('时间 · 过程', '事情先后怎样？先后本身不证明因果。'),
  space('空间 · 处境', '在哪里发生？哪些环境条件可能相关？'),
  cause('因果 · 条件', '哪些只是可能原因？还需要排除什么解释？'),
  evidence('认识根据 · 证据', '凭什么作出判断？现有材料支持到哪一步？'),
  motive('动机 · 意愿', '当时明确表达了什么愿望？未知动机保持未知。');

  const GroundLens(this.label, this.question);
  final String label, question;
}

List<String> cognitiveTexts(dynamic value, {int limit = 12}) => value is List
    ? value
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(limit)
        .toList()
    : const [];

/// Only the chosen text is sent to AI. The full original is hashed locally so
/// an edit can invalidate an annotation without uploading attachments or peers.
class CognitiveSelection {
  final String module, recordId, title, originalHash, text;
  final int start, end;
  const CognitiveSelection(
      {required this.module,
      required this.recordId,
      required this.title,
      required this.originalHash,
      required this.text,
      required this.start,
      required this.end});

  factory CognitiveSelection.fromText(
      {required String module,
      required String recordId,
      required String title,
      required String fullText,
      int start = 0,
      int? end}) {
    final finish = end ?? fullText.length;
    if (start < 0 || finish > fullText.length || finish <= start) {
      throw ArgumentError('请先选择需要分析的文字');
    }
    return CognitiveSelection(
        module: module,
        recordId: recordId,
        title: title,
        originalHash: insightHash(fullText),
        text: fullText.substring(start, finish),
        start: start,
        end: finish);
  }
  String get identity =>
      insightHash([module, recordId, originalHash, start, end, text]);
  bool matches(String current) =>
      insightHash(current) == originalHash &&
      start >= 0 &&
      end <= current.length &&
      current.substring(start, end) == text;
  CognitiveSelection withRecordId(String id) => CognitiveSelection(
      module: module,
      recordId: id,
      title: title,
      originalHash: originalHash,
      text: text,
      start: start,
      end: end);
  Map<String, dynamic> toJson() => {
        'module': module,
        'record_id': recordId,
        'title': title,
        'original_hash': originalHash,
        'text': text,
        'start': start,
        'end': end
      };
  factory CognitiveSelection.fromJson(dynamic value) {
    final m = insightObject(value);
    final text = insightText(m, 'text');
    final start = m['start'], end = m['end'];
    if (start is! int ||
        end is! int ||
        start < 0 ||
        end - start != text.length ||
        text.isEmpty) {
      throw const FormatException('注释位置已损坏');
    }
    return CognitiveSelection(
        module: insightText(m, 'module'),
        recordId: insightText(m, 'record_id'),
        title: insightText(m, 'title'),
        originalHash: insightText(m, 'original_hash'),
        text: text,
        start: start,
        end: end);
  }
}

class CognitiveSpan {
  final int start, end;
  final String text, reason;
  final StatementKind kind;
  const CognitiveSpan(
      {required this.start,
      required this.end,
      required this.text,
      required this.kind,
      this.reason = ''});
  CognitiveSpan withKind(StatementKind value) => CognitiveSpan(
      start: start, end: end, text: text, kind: value, reason: reason);
  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'text': text,
        'kind': kind.name,
        'reason': reason
      };

  /// Ground all spans in exact text, fill gaps with unknown, reject invented
  /// excerpts. A model's "fact" is always a user's report, never verified fact.
  static List<CognitiveSpan> parse(dynamic value, String original) {
    final spans = <CognitiveSpan>[];
    var cursor = 0;
    if (value is List) {
      for (final raw in value.take(40)) {
        final map = insightObject(raw);
        final excerpt = insightText(map, 'text');
        if (excerpt.isEmpty) continue;
        final offset = original.indexOf(excerpt, cursor);
        if (offset < 0) continue;
        if (offset > cursor) {
          spans.add(CognitiveSpan(
              start: cursor,
              end: offset,
              text: original.substring(cursor, offset),
              kind: StatementKind.unresolved));
        }
        spans.add(CognitiveSpan(
            start: offset,
            end: offset + excerpt.length,
            text: excerpt,
            kind: StatementKind.parse(insightText(map, 'kind')),
            reason: insightText(map, 'reason')));
        cursor = offset + excerpt.length;
      }
    }
    if (cursor < original.length) {
      spans.add(CognitiveSpan(
          start: cursor,
          end: original.length,
          text: original.substring(cursor),
          kind: StatementKind.unresolved));
    }
    return spans;
  }
}

class CognitiveExample {
  final String situation, connection, boundary;
  const CognitiveExample(
      {required this.situation,
      required this.connection,
      required this.boundary});
  Map<String, dynamic> toJson() =>
      {'situation': situation, 'connection': connection, 'boundary': boundary};
}

/// A quote from the selected material, not an externally verified fact. Model
/// supplied URLs, record IDs and verification flags cannot create references.
class CognitiveEvidence {
  final int start, end;
  final String excerpt, explanation;
  const CognitiveEvidence(
      {required this.start,
      required this.end,
      required this.excerpt,
      this.explanation = ''});

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'excerpt': excerpt,
        'explanation': explanation
      };

  static List<CognitiveEvidence> parse(dynamic value, String original) {
    final result = <CognitiveEvidence>[];
    final seen = <String>{};
    for (final raw in value is List ? value.take(8) : const []) {
      final m = insightObject(raw);
      final excerpt = insightText(m, 'excerpt');
      if (excerpt.runes.length < 2) continue;
      var start = m['start'], end = m['end'];
      if (start is! int || end is! int) {
        start = original.indexOf(excerpt);
        if (start < 0 || original.indexOf(excerpt, start + 1) >= 0) continue;
        end = start + excerpt.length;
      }
      if (start < 0 ||
          end > original.length ||
          end <= start ||
          original.substring(start, end) != excerpt ||
          !seen.add('$start:$end')) continue;
      result.add(CognitiveEvidence(
          start: start,
          end: end,
          excerpt: excerpt,
          explanation: insightText(m, 'explanation')));
    }
    return result;
  }
}

class CognitiveAnalysis {
  final String summary,
      common,
      difference,
      boundary,
      counterExample,
      basis,
      unknown;
  final List<String> concepts, questions;
  final List<CognitiveSpan> spans;
  final List<CognitiveExample> examples;
  final List<CognitiveEvidence> evidence;
  final Map<GroundLens, String> lenses;
  const CognitiveAnalysis(
      {this.summary = '',
      this.common = '',
      this.difference = '',
      this.boundary = '',
      this.counterExample = '',
      this.basis = '',
      this.unknown = '',
      this.concepts = const [],
      this.questions = const [],
      this.spans = const [],
      this.examples = const [],
      this.evidence = const [],
      this.lenses = const {}});

  factory CognitiveAnalysis.fromJson(dynamic value, String original) {
    final m = insightObject(value);
    final examples = <CognitiveExample>[];
    if (m['examples'] is List) {
      for (final raw in (m['examples'] as List).take(4)) {
        final e = insightObject(raw);
        if (insightText(e, 'situation').isEmpty) continue;
        examples.add(CognitiveExample(
            situation: insightText(e, 'situation'),
            connection: insightText(e, 'connection'),
            boundary: insightText(e, 'boundary')));
      }
    }
    final lensMap = insightObject(m['lenses']);
    return CognitiveAnalysis(
        summary: insightText(m, 'summary'),
        common: insightText(m, 'common'),
        difference: insightText(m, 'difference'),
        boundary: insightText(m, 'boundary'),
        counterExample: insightText(m, 'counter_example'),
        basis: insightText(m, 'basis'),
        unknown: insightText(m, 'unknown'),
        concepts: cognitiveTexts(m['concepts']),
        questions: cognitiveTexts(m['questions']),
        spans: CognitiveSpan.parse(m['spans'], original),
        examples: examples,
        evidence: CognitiveEvidence.parse(m['evidence_refs'], original),
        lenses: {
          for (final lens in GroundLens.values)
            lens: insightText(lensMap, lens.name)
        });
  }
  CognitiveAnalysis withSpans(List<CognitiveSpan> value) => CognitiveAnalysis(
      summary: summary,
      common: common,
      difference: difference,
      boundary: boundary,
      counterExample: counterExample,
      basis: basis,
      unknown: unknown,
      concepts: concepts,
      questions: questions,
      spans: value,
      examples: examples,
      evidence: evidence,
      lenses: lenses);
  Map<String, dynamic> toJson() => {
        'summary': summary,
        'common': common,
        'difference': difference,
        'boundary': boundary,
        'counter_example': counterExample,
        'basis': basis,
        'unknown': unknown,
        'concepts': concepts,
        'questions': questions,
        'spans': spans.map((e) => e.toJson()).toList(),
        'examples': examples.map((e) => e.toJson()).toList(),
        'evidence_refs': evidence.map((e) => e.toJson()).toList(),
        'lenses': {
          for (final entry in lenses.entries) entry.key.name: entry.value
        }
      };
}

class JudgmentRevision {
  final String previous, judgment, evidence, reason, createdAt;
  final String sourceSnapshot;
  const JudgmentRevision(
      {required this.previous,
      required this.judgment,
      required this.evidence,
      required this.reason,
      required this.createdAt,
      this.sourceSnapshot = ''});
  Map<String, dynamic> toJson() => {
        'previous': previous,
        'judgment': judgment,
        'evidence': evidence,
        'reason': reason,
        'created_at': createdAt,
        if (sourceSnapshot.isNotEmpty) 'source_snapshot': sourceSnapshot,
      };
  factory JudgmentRevision.fromJson(dynamic value) {
    final m = insightObject(value);
    return JudgmentRevision(
        previous: insightText(m, 'previous'),
        judgment: insightText(m, 'judgment'),
        evidence: insightText(m, 'evidence'),
        reason: insightText(m, 'reason'),
        createdAt: insightText(m, 'created_at'),
        sourceSnapshot: insightText(m, 'source_snapshot'));
  }
}

class CognitiveNote {
  static const version = 1;
  final String id, modelInfo, createdAt;
  final CognitiveTask task;
  final CognitiveSelection selection;
  final CognitiveAnalysis analysis;
  final bool accepted;
  final List<JudgmentRevision> revisions;
  final List<Map<String, dynamic>> classificationHistory;
  const CognitiveNote(
      {required this.id,
      required this.task,
      required this.selection,
      required this.analysis,
      required this.modelInfo,
      required this.createdAt,
      this.accepted = false,
      this.revisions = const [],
      this.classificationHistory = const []});
  String get currentJudgment =>
      revisions.isEmpty ? analysis.summary : revisions.last.judgment;
  String get currentSnapshot =>
      revisions.isEmpty ? id : revisions.last.sourceSnapshot;
  List<Map<String, dynamic>> get evidenceRefs {
    final grounded = analysis.evidence
        .where((e) =>
            e.start >= 0 &&
            e.end <= selection.text.length &&
            e.end > e.start &&
            selection.text.substring(e.start, e.end) == e.excerpt)
        .toList();
    final evidence = grounded.isEmpty
        ? [
            CognitiveEvidence(
                start: 0,
                end: selection.text.length,
                excerpt: selection.text,
                explanation: '本次明确选中的原始材料；尚未外部核对。')
          ]
        : grounded;
    return [
      for (final e in evidence)
        {
          'locator':
              '${selection.module}:${selection.recordId}#${selection.start + e.start}-${selection.start + e.end}',
          'source_type': 'selected_record',
          'source_status': 'unverified',
          'excerpt': e.excerpt,
          'explanation': e.explanation,
          'start': selection.start + e.start,
          'end': selection.start + e.end,
          'original_hash': selection.originalHash,
        }
    ];
  }

  CognitiveNote copyWith(
          {CognitiveSelection? selection,
          CognitiveAnalysis? analysis,
          bool? accepted,
          List<JudgmentRevision>? revisions,
          List<Map<String, dynamic>>? classificationHistory}) =>
      CognitiveNote(
          id: id,
          task: task,
          selection: selection ?? this.selection,
          analysis: analysis ?? this.analysis,
          modelInfo: modelInfo,
          createdAt: createdAt,
          accepted: accepted ?? this.accepted,
          revisions: revisions ?? this.revisions,
          classificationHistory:
              classificationHistory ?? this.classificationHistory);
  CognitiveNote revise(
      {required String judgment,
      required String evidence,
      String reason = '',
      String sourceSnapshot = ''}) {
    if (judgment.trim().isEmpty || evidence.trim().isEmpty) {
      throw ArgumentError('修订需要新的判断和具体材料');
    }
    return copyWith(revisions: [
      ...revisions,
      JudgmentRevision(
          previous: currentJudgment,
          judgment: judgment.trim(),
          evidence: evidence.trim(),
          reason: reason.trim(),
          createdAt: DateTime.now().toUtc().toIso8601String(),
          sourceSnapshot: sourceSnapshot)
    ]);
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'id': id,
        'task': task.name,
        'selection': selection.toJson(),
        'analysis': analysis.toJson(),
        'model_info': modelInfo,
        'created_at': createdAt,
        'accepted': accepted,
        'revisions': revisions.map((e) => e.toJson()).toList(),
        'classification_history': classificationHistory,
        'evidence_refs': evidenceRefs,
        'review_status': accepted ? 'accepted' : 'pending',
        'content_kind': 'interpretation',
        'epistemic_status': 'provisional',
        'source_status': 'unverified'
      };
  factory CognitiveNote.fromJson(dynamic value) {
    final m = insightObject(value);
    if (m['version'] != version) throw const FormatException('注释版本不支持');
    final selection = CognitiveSelection.fromJson(m['selection']);
    return CognitiveNote(
        id: insightText(m, 'id'),
        task: CognitiveTask.values.firstWhere((e) => e.name == m['task']),
        selection: selection,
        analysis: CognitiveAnalysis.fromJson(m['analysis'], selection.text),
        modelInfo: insightText(m, 'model_info'),
        createdAt: insightText(m, 'created_at'),
        accepted: m['accepted'] == true,
        revisions: m['revisions'] is List
            ? (m['revisions'] as List).map(JudgmentRevision.fromJson).toList()
            : const [],
        classificationHistory: m['classification_history'] is List
            ? (m['classification_history'] as List).map(insightObject).toList()
            : const []);
  }
}
