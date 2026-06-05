import 'dart:convert';

class FpEpisode {
  final int episodeNo;
  final String titleZh;
  final String titleEn;
  final int totalBigSections;
  final int totalSegments;

  const FpEpisode({
    required this.episodeNo,
    required this.titleZh,
    required this.titleEn,
    required this.totalBigSections,
    required this.totalSegments,
  });

  factory FpEpisode.fromMap(Map<String, dynamic> m) => FpEpisode(
        episodeNo: (m['episode_no'] as num).toInt(),
        titleZh: (m['title_zh'] ?? '').toString(),
        titleEn: (m['title_en'] ?? '').toString(),
        totalBigSections: (m['total_big_sections'] as num?)?.toInt() ?? 0,
        totalSegments: (m['total_segments'] as num?)?.toInt() ?? 0,
      );
}

class FpBigSection {
  final String id;
  final int episodeNo;
  final int sectionIndex;
  final String title;

  const FpBigSection({
    required this.id,
    required this.episodeNo,
    required this.sectionIndex,
    required this.title,
  });

  factory FpBigSection.fromMap(Map<String, dynamic> m) => FpBigSection(
        id: (m['id'] ?? '').toString(),
        episodeNo: (m['episode_no'] as num).toInt(),
        sectionIndex: (m['section_index'] as num?)?.toInt() ?? 0,
        title: (m['title'] ?? '').toString(),
      );
}

class FpSegment {
  final String segmentId;
  final int episodeNo;
  final String bigSectionId;
  final int sortIndex;
  final String summaryZh;
  final String excerptEn;
  final String primaryNode;
  final List<String> secondaryNodes;

  const FpSegment({
    required this.segmentId,
    required this.episodeNo,
    required this.bigSectionId,
    required this.sortIndex,
    required this.summaryZh,
    required this.excerptEn,
    required this.primaryNode,
    required this.secondaryNodes,
  });

  factory FpSegment.fromMap(Map<String, dynamic> m) {
    final sec = <String>[];
    final raw = m['secondary_nodes'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final xs = jsonDecode(raw);
        if (xs is List) {
          for (final v in xs) {
            final s = (v ?? '').toString().trim();
            if (s.isNotEmpty) sec.add(s);
          }
        }
      } catch (_) {}
    } else if (raw is List) {
      for (final v in raw) {
        final s = (v ?? '').toString().trim();
        if (s.isNotEmpty) sec.add(s);
      }
    }

    return FpSegment(
      segmentId: (m['segment_id'] ?? '').toString(),
      episodeNo: (m['episode_no'] as num).toInt(),
      bigSectionId: (m['big_section_id'] ?? '').toString(),
      sortIndex: (m['sort_index'] as num?)?.toInt() ?? 0,
      summaryZh: (m['summary_zh'] ?? '').toString(),
      excerptEn: (m['excerpt_en'] ?? '').toString(),
      primaryNode: (m['primary_node'] ?? '').toString(),
      secondaryNodes: sec,
    );
  }
}

class FpConceptNode {
  final String nodeId;
  final String category;
  final String name;
  final String definition;

  const FpConceptNode({
    required this.nodeId,
    required this.category,
    required this.name,
    required this.definition,
  });

  factory FpConceptNode.fromMap(Map<String, dynamic> m) => FpConceptNode(
        nodeId: (m['node_id'] ?? '').toString(),
        category: (m['category'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        definition: (m['definition'] ?? '').toString(),
      );
}

class FpConceptEdge {
  final String fromNode;
  final String toNode;
  final String relation;

  const FpConceptEdge({
    required this.fromNode,
    required this.toNode,
    required this.relation,
  });

  factory FpConceptEdge.fromMap(Map<String, dynamic> m) => FpConceptEdge(
        fromNode: (m['from_node'] ?? '').toString(),
        toNode: (m['to_node'] ?? '').toString(),
        relation: (m['relation'] ?? '').toString(),
      );
}

class FpTemplate {
  final String templateId;
  final String name;
  final String schemaJson;

  const FpTemplate({
    required this.templateId,
    required this.name,
    required this.schemaJson,
  });

  factory FpTemplate.fromMap(Map<String, dynamic> m) => FpTemplate(
        templateId: (m['template_id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        schemaJson: (m['schema_json'] ?? '{}').toString(),
      );
}

class FpTask {
  final String taskId;
  final String conceptId;
  final String title;
  final int difficulty;
  final int durationMin;
  final String description;
  final String templateId;
  final List<String> steps;

  const FpTask({
    required this.taskId,
    required this.conceptId,
    required this.title,
    required this.difficulty,
    required this.durationMin,
    required this.description,
    required this.templateId,
    required this.steps,
  });

  factory FpTask.fromMap(Map<String, dynamic> m) {
    final steps = <String>[];
    final raw = m['steps_json'] ?? m['steps'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final xs = jsonDecode(raw);
        if (xs is List) {
          for (final v in xs) {
            final s = (v ?? '').toString().trim();
            if (s.isNotEmpty) steps.add(s);
          }
        }
      } catch (_) {}
    } else if (raw is List) {
      for (final v in raw) {
        final s = (v ?? '').toString().trim();
        if (s.isNotEmpty) steps.add(s);
      }
    }

    return FpTask(
      taskId: (m['task_id'] ?? '').toString(),
      conceptId: (m['concept_id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      difficulty: (m['difficulty'] as num?)?.toInt() ?? 2,
      durationMin: (m['duration_min'] as num?)?.toInt() ?? 10,
      description: (m['description'] ?? '').toString(),
      templateId: (m['template_id'] ?? 'T_NOTE').toString(),
      steps: steps,
    );
  }
}

class FpPracticeRun {
  final int id;
  final String taskId;
  final int tsMs;
  final String resultJson;

  const FpPracticeRun({
    required this.id,
    required this.taskId,
    required this.tsMs,
    required this.resultJson,
  });

  factory FpPracticeRun.fromMap(Map<String, dynamic> m) => FpPracticeRun(
        id: (m['id'] as num).toInt(),
        taskId: (m['task_id'] ?? '').toString(),
        tsMs: (m['ts_ms'] as num?)?.toInt() ?? 0,
        resultJson: (m['result_json'] ?? '{}').toString(),
      );
}

class FpLearningCard {
  final int id;
  final int tsMs;
  final String title;
  final String body;
  final String tagsJson;

  const FpLearningCard({
    required this.id,
    required this.tsMs,
    required this.title,
    required this.body,
    required this.tagsJson,
  });

  factory FpLearningCard.fromMap(Map<String, dynamic> m) => FpLearningCard(
        id: (m['id'] as num).toInt(),
        tsMs: (m['ts_ms'] as num?)?.toInt() ?? 0,
        title: (m['title'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        tagsJson: (m['tags_json'] ?? '[]').toString(),
      );
}
