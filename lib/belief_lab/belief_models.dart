import 'dart:convert';

class BeliefSegment {
  final int id;
  final int lecture; // 5/6/7
  final int segNo;   // 1..n (within lecture)
  final String title;
  final String body;
  final String tagsJson; // simple JSON array string

  BeliefSegment({
    required this.id,
    required this.lecture,
    required this.segNo,
    required this.title,
    required this.body,
    required this.tagsJson,
  });

  List<String> get tags {
    try {
      final v = json.decode(tagsJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  String get key => 'L$lecture#$segNo';

  Map<String, Object?> toRow() => {
        'id': id,
        'lecture': lecture,
        'seg_no': segNo,
        'title': title,
        'body': body,
        'tags_json': tagsJson,
      };

  static BeliefSegment fromRow(Map<String, Object?> r) => BeliefSegment(
        id: (r['id'] as num).toInt(),
        lecture: (r['lecture'] as num).toInt(),
        segNo: (r['seg_no'] as num).toInt(),
        title: (r['title'] ?? '').toString(),
        body: (r['body'] ?? '').toString(),
        tagsJson: (r['tags_json'] ?? '[]').toString(),
      );
}

class BeliefProgress {
  final String key; // e.g. episode:<id> or mission:<id> or learn:L6#12
  final int status; // 0 not started, 1 in progress, 2 done
  final int updatedAtMs;
  final String payloadJson;

  BeliefProgress({
    required this.key,
    required this.status,
    required this.updatedAtMs,
    required this.payloadJson,
  });

  Map<String, Object?> toRow() => {
        'key': key,
        'status': status,
        'updated_at_ms': updatedAtMs,
        'payload_json': payloadJson,
      };

  static BeliefProgress fromRow(Map<String, Object?> r) => BeliefProgress(
        key: (r['key'] ?? '').toString(),
        status: (r['status'] as num?)?.toInt() ?? 0,
        updatedAtMs: (r['updated_at_ms'] as num?)?.toInt() ?? 0,
        payloadJson: (r['payload_json'] ?? '{}').toString(),
      );

  Map<String, dynamic> get payload {
    try { return json.decode(payloadJson) as Map<String, dynamic>; } catch (_) { return {}; }
  }
}

class BeliefConcept {
  final String id; // stable id
  final String title;
  /// Short tagline shown on the concept card.
  final String oneLiner;

  /// Category group for the concept map (used for grouping & ordering).
  final String group;

  /// Longer description shown in the concept detail page.
  final String detail;

  /// Sort order within the same group (smaller first).
  final int order;

  /// Segment keys like "L6#12".
  final List<String> segmentKeys;

  /// Replay episodes (optional).
  final List<String> episodeIds;

  /// Action missions (optional).
  final List<String> missionIds;

  const BeliefConcept({
    required this.id,
    required this.title,
    required this.oneLiner,
    this.group = '未分组',
    this.detail = '',
    this.order = 0,
    required this.segmentKeys,
    required this.episodeIds,
    required this.missionIds,
  });
}

class BeliefEpisode {
  final String id;
  final String title;
  final String subtitle;
  final String conceptId;
  final List<BeliefStep> steps;

  const BeliefEpisode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.conceptId,
    required this.steps,
  });
}

enum BeliefStepType { info, singleChoice, multiChoice, input, checklist, rating, summary }

class BeliefChoice {
  final String id;
  final String text;
  final String? hint;
  final int score; // optional scoring for diagnose
  const BeliefChoice({required this.id, required this.text, this.hint, this.score = 0});
}

class BeliefStep {
  final String id;
  final BeliefStepType type;
  final String title;
  final String body;
  final List<BeliefChoice> choices;
  final List<String> checklist;
  final bool required;
  final int minRating;
  final int maxRating;

  const BeliefStep({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.choices = const [],
    this.checklist = const [],
    this.required = true,
    this.minRating = 1,
    this.maxRating = 5,
  });
}

class BeliefMission {
  final String id;
  final String title;
  final String subtitle;
  final String conceptId;
  final List<BeliefStep> steps;

  const BeliefMission({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.conceptId,
    required this.steps,
  });
}
