import 'dart:convert';

/// 行动模板：把“概念”翻译成现实中可执行、可复盘的动作结构。
///
/// 设计目标：
/// - 概念与行动一致：每个模板都给出“操作性定义（operationalDefinition）”与“成功判据（successCriteria）”。
/// - 支持计划/非计划两种模式（mode）。
/// - 为后续目标模块/失败模块/学习模块/改变模块预留字段。
class BeliefActionTemplate {
  final String id; // stable
  final String conceptId;
  final String title;
  final String version; // e.g. 基础版/进阶版
  final String categoryPath; // e.g. 工作/管理/期待升级
  final String mode; // planned | quick

  final String operationalDefinition;
  final String successCriteria;
  final List<String> actionChecklist;
  final List<String> refSegmentKeys; // references into 57 segments

  // Optional link hooks
  final List<String> learningTags; // for behaviorism knowledge base later
  final String changePath; // brief path steps for habit change

  const BeliefActionTemplate({
    required this.id,
    required this.conceptId,
    required this.title,
    required this.version,
    required this.categoryPath,
    required this.mode,
    required this.operationalDefinition,
    required this.successCriteria,
    required this.actionChecklist,
    required this.refSegmentKeys,
    this.learningTags = const [],
    this.changePath = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'conceptId': conceptId,
        'title': title,
        'version': version,
        'categoryPath': categoryPath,
        'mode': mode,
        'operationalDefinition': operationalDefinition,
        'successCriteria': successCriteria,
        'actionChecklist': actionChecklist,
        'refSegmentKeys': refSegmentKeys,
        'learningTags': learningTags,
        'changePath': changePath,
      };

  static BeliefActionTemplate fromJson(Map<String, dynamic> m) => BeliefActionTemplate(
        id: (m['id'] ?? '').toString(),
        conceptId: (m['conceptId'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        version: (m['version'] ?? '').toString(),
        categoryPath: (m['categoryPath'] ?? '').toString(),
        mode: (m['mode'] ?? 'quick').toString(),
        operationalDefinition: (m['operationalDefinition'] ?? '').toString(),
        successCriteria: (m['successCriteria'] ?? '').toString(),
        actionChecklist: (m['actionChecklist'] is List)
            ? List<String>.from((m['actionChecklist'] as List).map((e) => e.toString()))
            : const <String>[],
        refSegmentKeys: (m['refSegmentKeys'] is List)
            ? List<String>.from((m['refSegmentKeys'] as List).map((e) => e.toString()))
            : const <String>[],
        learningTags: (m['learningTags'] is List)
            ? List<String>.from((m['learningTags'] as List).map((e) => e.toString()))
            : const <String>[],
        changePath: (m['changePath'] ?? '').toString(),
      );

  /// 支持从 belief_progress.payload_json 中解析。
  static BeliefActionTemplate? tryParseProgressPayload(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      if (payload['template'] is Map<String, dynamic>) {
        return BeliefActionTemplate.fromJson(payload['template'] as Map<String, dynamic>);
      }
      if (payload['id'] != null && payload['conceptId'] != null && payload['title'] != null) {
        return BeliefActionTemplate.fromJson(payload);
      }
    }
    if (payload is String) {
      try {
        final m = jsonDecode(payload);
        if (m is Map<String, dynamic>) {
          return BeliefActionTemplate.fromJson(m);
        }
      } catch (_) {}
    }
    return null;
  }

  String get modeLabel => mode == 'planned' ? '计划模式' : '非计划模式';

  List<String> get categoryParts {
    final s = categoryPath.trim();
    if (s.isEmpty) return const [];
    return s.split('/').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}
