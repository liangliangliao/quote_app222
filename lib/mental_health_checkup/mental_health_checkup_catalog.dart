import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'mental_health_content_governance.dart';
import 'mental_health_checkup_models.dart';

class CheckupReferenceRule {
  final Map<String, String> fields;

  const CheckupReferenceRule(this.fields);

  String value(String key) => fields[key] ?? '';

  Map<String, String> toJson() => Map<String, String>.from(fields);
}

class CheckupSeedValidationResult {
  final bool valid;
  final String version;
  final int checkedFiles;
  final List<String> errors;

  const CheckupSeedValidationResult({
    required this.valid,
    required this.version,
    required this.checkedFiles,
    required this.errors,
  });
}

class MentalHealthCheckupCatalog {
  static const String assetRoot = 'assets/mental_health_checkup';
  static const String ruleVersion = '2.5';

  static const Map<String, String> domainNames = <String, String>{
    'D1': '情绪接纳与有效行动',
    'D2': '现实主义乐观',
    'D3': '知行转化与仪式',
    'D4': '目标、意义与自洽',
    'D5': '优势、压力与恢复',
    'D6': '睡眠、运动与身心基础',
    'D7': '关系、表达与连接',
    'D8': '自尊、自主与实现',
  };

  static const Map<String, String> domainDescriptions = <String, String>{
    'D1': '允许情绪存在，同时选择安全、有效的行动。',
    'D2': '承认事实与限制，也能看见可能性和可控部分。',
    'D3': '把理解变成可重复的小行动、结构和生活仪式。',
    'D4': '目标与个人价值、意义、兴趣和现实生活相协调。',
    'D5': '识别优势、管理负荷，并安排微观到长期恢复。',
    'D6': '睡眠、运动和身体恢复能够支持日常功能。',
    'D7': '在重要关系中被了解，并能真实、尊重地表达。',
    'D8': '不把基本价值完全交给外界认可，依据价值行动。',
  };

  static const Map<String, String> domainLectureAnchors = <String, String>{
    'D1': 'Lecture 4',
    'D2': 'Lecture 5-9',
    'D3': 'Lecture 1, 10-11, 23',
    'D4': 'Lecture 12',
    'D5': 'Lecture 13-17',
    'D6': 'Lecture 16-18',
    'D7': 'Lecture 19-21',
    'D8': 'Lecture 21-22',
  };

  final List<CheckupModeSpec> modes;
  final List<CheckupQuestion> b20Questions;
  final List<CheckupIndicator> indicators;
  final List<CheckupDiagnosisPattern> diagnosisPatterns;
  final List<CheckupPrescription> prescriptions;
  final List<CheckupReferenceRule> clinicalTerms;
  final List<CheckupReferenceRule> longitudinalCoverageRules;
  final List<CheckupReferenceRule> branchAlertRules;
  final List<CheckupReferenceRule> aiReportFields;
  final List<CheckupReferenceRule> doseAndCourseRules;
  final List<CheckupReferenceRule> prescriptionAdjustmentRules;
  final List<CheckupReferenceRule> recoveryMaintenanceRules;
  final List<CheckupReferenceRule> sourceBoundaryRules;
  final Map<String, Map<String, String>> seedFieldMappings;
  final List<CheckupContentCandidate> legacyContentCandidates;
  final List<CheckupContentCandidate> publishedContentCandidates;
  final List<CheckupQuestion> publishedQuestions;
  final List<CheckupQuestion> retiredPublishedQuestions;
  final CheckupSeedValidationResult validation;

  const MentalHealthCheckupCatalog({
    required this.modes,
    required this.b20Questions,
    required this.indicators,
    required this.diagnosisPatterns,
    required this.prescriptions,
    this.clinicalTerms = const <CheckupReferenceRule>[],
    this.longitudinalCoverageRules = const <CheckupReferenceRule>[],
    this.branchAlertRules = const <CheckupReferenceRule>[],
    this.aiReportFields = const <CheckupReferenceRule>[],
    this.doseAndCourseRules = const <CheckupReferenceRule>[],
    this.prescriptionAdjustmentRules = const <CheckupReferenceRule>[],
    this.recoveryMaintenanceRules = const <CheckupReferenceRule>[],
    this.sourceBoundaryRules = const <CheckupReferenceRule>[],
    this.seedFieldMappings = const <String, Map<String, String>>{},
    this.legacyContentCandidates = const <CheckupContentCandidate>[],
    this.publishedContentCandidates = const <CheckupContentCandidate>[],
    this.publishedQuestions = const <CheckupQuestion>[],
    this.retiredPublishedQuestions = const <CheckupQuestion>[],
    required this.validation,
  });

  static Future<MentalHealthCheckupCatalog> load() async {
    final validation = await validateSeeds();
    if (!validation.valid) {
      throw StateError('课程种子校验失败：${validation.errors.join('；')}');
    }

    final values = await Future.wait<String>(<Future<String>>[
      rootBundle.loadString('$assetRoot/assessment_modes.json'),
      rootBundle.loadString('$assetRoot/b20_items.json'),
      rootBundle.loadString('$assetRoot/indicators.json'),
      rootBundle.loadString('$assetRoot/diagnosis_patterns.json'),
      rootBundle.loadString('$assetRoot/course_prescriptions.json'),
      rootBundle.loadString('$assetRoot/course_clinical_terms.json'),
      rootBundle.loadString('$assetRoot/longitudinal_coverage_rules.json'),
      rootBundle.loadString('$assetRoot/branch_alert_rules.json'),
      rootBundle.loadString('$assetRoot/ai_report_fields.json'),
      rootBundle.loadString('$assetRoot/dose_and_course_rules.json'),
      rootBundle.loadString('$assetRoot/prescription_adjustment_rules.json'),
      rootBundle.loadString('$assetRoot/recovery_maintenance_rules.json'),
      rootBundle.loadString('$assetRoot/source_boundaries.json'),
      rootBundle.loadString('$assetRoot/seed_field_mappings.json'),
      rootBundle.loadString('$assetRoot/legacy_content_candidates.json'),
    ]);

    final modeRows = _mapList(jsonDecode(values[0]));
    final b20Rows = _mapList(jsonDecode(values[1]));
    final indicatorRows = _mapList(jsonDecode(values[2]));
    final diagnosisRows = _mapList(jsonDecode(values[3]));
    final prescriptionRows = _mapList(jsonDecode(values[4]));

    final indicators = indicatorRows.map(_indicatorFromJson).toList();
    final byIndicatorId = <String, CheckupIndicator>{
      for (final indicator in indicators) indicator.id: indicator,
    };

    return MentalHealthCheckupCatalog(
      modes: modeRows.map(_modeFromJson).toList(growable: false),
      b20Questions: b20Rows
          .map((row) => _b20QuestionFromJson(row, byIndicatorId))
          .toList(growable: false),
      indicators: indicators,
      diagnosisPatterns:
          diagnosisRows.map(_diagnosisFromJson).toList(growable: false),
      prescriptions: prescriptionRows
          .map(_prescriptionFromJson)
          .toList(growable: false),
      clinicalTerms: _ruleList(jsonDecode(values[5])),
      longitudinalCoverageRules: _ruleList(jsonDecode(values[6])),
      branchAlertRules: _ruleList(jsonDecode(values[7])),
      aiReportFields: _ruleList(jsonDecode(values[8])),
      doseAndCourseRules: _ruleList(jsonDecode(values[9])),
      prescriptionAdjustmentRules: _ruleList(jsonDecode(values[10])),
      recoveryMaintenanceRules: _ruleList(jsonDecode(values[11])),
      sourceBoundaryRules: _ruleList(jsonDecode(values[12])),
      seedFieldMappings: _fieldMappings(jsonDecode(values[13])),
      legacyContentCandidates: _mapList(jsonDecode(values[14]))
          .map(CheckupContentCandidate.fromJson)
          .toList(growable: false),
      validation: validation,
    );
  }

  List<CheckupContentCandidate> get publishedBehaviorTasks =>
      publishedContentCandidates
          .where(
            (candidate) =>
                candidate.kind == CheckupContentKind.behaviorTask,
          )
          .toList(growable: false);

  MentalHealthCheckupCatalog withPublishedContent(
    Iterable<CheckupContentCandidate> candidates,
  ) {
    const governance = MentalHealthContentGovernanceEngine();
    final bySlot = <String, CheckupContentCandidate>{};
    final retired = <CheckupContentCandidate>[];
    for (final candidate in candidates) {
      if (!_isSignedGovernedContent(candidate, governance)) continue;
      if (candidate.stage == CheckupCandidateStage.retired) {
        retired.add(candidate);
        continue;
      }
      final slot = '${candidate.kind.name}|${candidate.primaryIndicatorId}|'
          '${candidate.contentCode}';
      final previous = bySlot[slot];
      if (previous == null ||
          candidate.version > previous.version ||
          candidate.version == previous.version &&
              candidate.updatedAtMs > previous.updatedAtMs) {
        bySlot[slot] = candidate;
      }
    }
    final published = bySlot.values.toList(growable: false)
      ..sort((left, right) {
        final indicatorComparison =
            left.primaryIndicatorId.compareTo(right.primaryIndicatorId);
        if (indicatorComparison != 0) return indicatorComparison;
        return left.contentCode.compareTo(right.contentCode);
      });
    final questions = published
        .map(_publishedQuestionFromCandidate)
        .whereType<CheckupQuestion>()
        .toList(growable: false);
    final retiredQuestions = retired
        .map(_publishedQuestionFromCandidate)
        .whereType<CheckupQuestion>()
        .toList(growable: false);
    return MentalHealthCheckupCatalog(
      modes: modes,
      b20Questions: b20Questions,
      indicators: indicators,
      diagnosisPatterns: diagnosisPatterns,
      prescriptions: prescriptions,
      clinicalTerms: clinicalTerms,
      longitudinalCoverageRules: longitudinalCoverageRules,
      branchAlertRules: branchAlertRules,
      aiReportFields: aiReportFields,
      doseAndCourseRules: doseAndCourseRules,
      prescriptionAdjustmentRules: prescriptionAdjustmentRules,
      recoveryMaintenanceRules: recoveryMaintenanceRules,
      sourceBoundaryRules: sourceBoundaryRules,
      seedFieldMappings: seedFieldMappings,
      legacyContentCandidates: legacyContentCandidates,
      publishedContentCandidates: published,
      publishedQuestions: questions,
      retiredPublishedQuestions: retiredQuestions,
      validation: validation,
    );
  }

  CheckupContentCandidate? publishedBehaviorTaskForIndicator(
    String indicatorId, {
    List<String> preferredCodes = const <String>['B1', 'B2', 'B0'],
  }) {
    for (final code in preferredCodes) {
      for (final candidate in publishedContentCandidates) {
        if (candidate.kind == CheckupContentKind.behaviorTask &&
            candidate.primaryIndicatorId == indicatorId &&
            candidate.contentCode == code) {
          return candidate;
        }
      }
    }
    return null;
  }

  static bool _isSignedGovernedContent(
    CheckupContentCandidate candidate,
    MentalHealthContentGovernanceEngine governance,
  ) {
    final author = candidate.author.trim().toLowerCase();
    final reviewer = candidate.reviewer.trim().toLowerCase();
    final signer = candidate.signer.trim().toLowerCase();
    return (candidate.stage == CheckupCandidateStage.official ||
            candidate.stage == CheckupCandidateStage.retired) &&
        candidate.evidenceReviewPassed &&
        candidate.constructReviewPassed &&
        candidate.cognitiveInterviewPassed &&
        candidate.pilotPassed &&
        candidate.pilotSampleSize > 0 &&
        reviewer.isNotEmpty &&
        signer.isNotEmpty &&
        reviewer != author &&
        !reviewer.contains('ai') &&
        !signer.contains('ai') &&
        governance.validate(candidate).valid;
  }

  CheckupQuestion? _publishedQuestionFromCandidate(
    CheckupContentCandidate candidate,
  ) {
    if (candidate.kind != CheckupContentKind.assessmentItem ||
        candidate.contentCode == 'A8') {
      return null;
    }
    final indicator = indicatorById(candidate.primaryIndicatorId);
    if (indicator == null) return null;
    final code = candidate.contentCode;
    final role = switch (code) {
      'A7' => CheckupQuestionScoringRole.knowledge,
      'A1' || 'A9' => CheckupQuestionScoringRole.contextOnly,
      'A3' || 'A6F' || 'A6I' => CheckupQuestionScoringRole.behavior,
      'A2' || 'A4' || 'A5' => CheckupQuestionScoringRole.attitude,
      _ => null,
    };
    if (role == null) return null;
    final choices = _choicesForPublishedCandidate(candidate);
    if (choices.length < 2) return null;
    final correctIndex = candidate.correctAnswerIndex;
    if (role == CheckupQuestionScoringRole.knowledge &&
        (correctIndex == null ||
            correctIndex < 0 ||
            correctIndex >= choices.length)) {
      return null;
    }
    final domainId = _domainForIndicator(indicator);
    return CheckupQuestion(
      id: role == CheckupQuestionScoringRole.knowledge
          ? 'B20-KP-${candidate.candidateId}'
          : 'PUB-${candidate.candidateId}',
      group: '${domainNames[domainId]} · 正式题库 v${candidate.version}',
      kind: _publishedKindLabel(code, indicator.type),
      prompt: candidate.content,
      scaleLabel: candidate.scaleOrDuration,
      direction: candidate.scoringDirection,
      indicatorId: indicator.id,
      sourceLevel: candidate.sourceLevel,
      required: false,
      domainId: domainId,
      lecture: indicator.lecture,
      evidenceLocation: candidate.courseEvidenceIds.join('、'),
      choices: choices,
      scoringRole: role,
      correctChoiceValue:
          correctIndex == null ? null : choices[correctIndex].value,
      contentCandidateId: candidate.candidateId,
      contentVersion: candidate.version,
      contentCode: code,
      retiredSnapshot:
          candidate.stage == CheckupCandidateStage.retired,
    );
  }

  static List<CheckupAnswerChoice> _choicesForPublishedCandidate(
    CheckupContentCandidate candidate,
  ) {
    if (candidate.answerOptions.length >= 2) {
      final startsAtOne =
          RegExp(r'(^|\D)1\s*[—–~-]\s*5(\D|$)')
              .hasMatch(candidate.scaleOrDuration);
      return List<CheckupAnswerChoice>.generate(
        candidate.answerOptions.length,
        (index) => CheckupAnswerChoice(
          candidate.answerOptions[index],
          (startsAtOne ? index + 1 : index).toDouble(),
        ),
      );
    }
    if (candidate.scaleOrDuration.contains('1—5') ||
        candidate.scaleOrDuration.contains('1-5')) {
      return const <CheckupAnswerChoice>[
        CheckupAnswerChoice('1 · 完全不符合', 1),
        CheckupAnswerChoice('2 · 较不符合', 2),
        CheckupAnswerChoice('3 · 一般/不确定', 3),
        CheckupAnswerChoice('4 · 较符合', 4),
        CheckupAnswerChoice('5 · 非常符合', 5),
      ];
    }
    return const <CheckupAnswerChoice>[
      CheckupAnswerChoice('0 · 从未/完全不符合', 0),
      CheckupAnswerChoice('1 · 很少/较不符合', 1),
      CheckupAnswerChoice('2 · 有时/一般', 2),
      CheckupAnswerChoice('3 · 经常/较符合', 3),
      CheckupAnswerChoice('4 · 几乎总是/非常符合', 4),
    ];
  }

  static String _publishedKindLabel(String code, String indicatorType) =>
      switch (code) {
        'A1' => '理论理解信心（不计K分）',
        'A2' => '态度倾向',
        'A3' => '近期行为观察',
        'A4' => '风险合理化',
        'A5' => '高端制衡',
        'A6F' => '现实结果频率',
        'A6I' => '现实功能影响',
        'A7' => '课程情境判断',
        'A9' => '元认知校准（不计健康分）',
        _ => indicatorType,
      };

  List<String> sourceBoundaryStatements() {
    if (sourceBoundaryRules.isEmpty) {
      return const <String>[
        'C1：课程直接内容；可直接支持定义、机制或行动。',
        'C2：课程机制推导；用于候选解释，仍需现实证据验证。',
        'D1：题量、量尺、阈值、剂量和复验期限等产品参数。',
        'D2：安全与功能分流；不进入“课程幸福总分”。',
        '本报告是课程型评估，不是医学疾病诊断、药物处方或治愈承诺。',
      ];
    }
    final values = sourceBoundaryRules.map((rule) {
      final level = rule.value('等级');
      final meaning = rule.value('含义');
      final use = rule.value('在V2.2中的用途');
      return '$level：$meaning；$use。';
    }).toList(growable: true);
    for (final rule in clinicalTerms) {
      if (rule.value('术语') != '课程型诊断') continue;
      final clinical =
          '${rule.value('术语')}不代表${rule.value('不代表什么')}。';
      if (clinical.isNotEmpty) values.add(clinical);
      break;
    }
    return values;
  }

  Map<String, Object?> governanceContext() => <String, Object?>{
        'clinical_terms':
            clinicalTerms.map((rule) => rule.toJson()).toList(growable: false),
        'longitudinal_coverage_rules': longitudinalCoverageRules
            .map((rule) => rule.toJson())
            .toList(growable: false),
        'branch_alert_rules': branchAlertRules
            .map((rule) => rule.toJson())
            .toList(growable: false),
        'ai_report_fields':
            aiReportFields.map((rule) => rule.toJson()).toList(growable: false),
        'dose_and_course_rules': doseAndCourseRules
            .map((rule) => rule.toJson())
            .toList(growable: false),
        'prescription_adjustment_rules': prescriptionAdjustmentRules
            .map((rule) => rule.toJson())
            .toList(growable: false),
        'recovery_maintenance_rules': recoveryMaintenanceRules
            .map((rule) => rule.toJson())
            .toList(growable: false),
        'source_boundaries': sourceBoundaryRules
            .map((rule) => rule.toJson())
            .toList(growable: false),
        'seed_field_mappings': seedFieldMappings,
        'legacy_content_candidates': <String, Object?>{
          'count': legacyContentCandidates.length,
          'status': '历史候选，待独立审核、认知访谈与试测',
        },
      };

  static Future<CheckupSeedValidationResult> validateSeeds() async {
    final errors = <String>[];
    var version = '';
    var checked = 0;
    try {
      final raw = await rootBundle.loadString('$assetRoot/seed_catalog.json');
      final catalog = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      version = (catalog['version'] ?? '').toString();
      final exports = catalog['exports'] as List? ?? const <Object?>[];
      for (final item in exports.whereType<Map>()) {
        final row = Map<String, dynamic>.from(item);
        final file = (row['file'] ?? '').toString();
        final expectedHash = (row['sha256'] ?? '').toString().toLowerCase();
        final expectedRows = (row['rows'] as num?)?.toInt();
        final format = (row['format'] ?? '').toString();
        if (file.isEmpty || expectedHash.isEmpty) {
          errors.add('seed_catalog 存在缺失字段');
          continue;
        }
        try {
          final bytes = await _loadSeedBytes(file);
          final actualHash = sha256.convert(bytes).toString();
          if (actualHash != expectedHash) errors.add('$file 哈希不一致');
          if (expectedRows != null) {
            final text = utf8.decode(bytes);
            final int actualRows;
            if (format == 'jsonl') {
              actualRows = const LineSplitter()
                  .convert(text)
                  .where((line) => line.trim().isNotEmpty)
                  .length;
            } else {
              final decoded = jsonDecode(text);
              actualRows = decoded is List ? decoded.length : -1;
            }
            if (actualRows != expectedRows) {
              errors.add('$file 记录数应为 $expectedRows，实际为 $actualRows');
            }
          }
          checked++;
        } catch (error) {
          errors.add('$file 无法读取：$error');
        }
      }
    } catch (error) {
      errors.add('seed_catalog.json 无法读取：$error');
    }
    return CheckupSeedValidationResult(
      valid: errors.isEmpty,
      version: version,
      checkedFiles: checked,
      errors: errors,
    );
  }

  static Future<Uint8List> _loadSeedBytes(String file) async {
    try {
      final data = await rootBundle.load('$assetRoot/$file');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      // The two evidence graphs are losslessly gzipped in the APK to keep the
      // repository and install size reasonable. Hashes and row counts are
      // still checked against the original, decompressed V2.5 package bytes.
      if (!file.endsWith('.jsonl')) rethrow;
      final data = await rootBundle.load('$assetRoot/$file.gz');
      final compressed = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return Uint8List.fromList(gzip.decode(compressed));
    }
  }

  CheckupModeSpec modeById(String id) => modes.firstWhere(
        (mode) => mode.id == id,
        orElse: () => modes.firstWhere((mode) => mode.id == 'b20'),
      );

  CheckupPrescription? prescriptionById(String id) {
    for (final item in prescriptions) {
      if (item.id == id) return item;
    }
    return null;
  }

  CheckupIndicator? indicatorById(String id) {
    for (final item in indicators) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<CheckupQuestion> questionsForMode(
    String modeId, {
    String? focusDomainId,
    DateTime? now,
    CheckupAssessmentPlan? assessmentPlan,
    List<CheckupSession> history = const <CheckupSession>[],
  }) {
    final clock = now ?? DateTime.now();
    final byId = <String, CheckupQuestion>{
      for (final question in b20Questions) question.id: question,
    };
    List<CheckupQuestion> pick(List<String> ids) => ids
        .map((id) => byId[id])
        .whereType<CheckupQuestion>()
        .toList(growable: false);
    List<CheckupQuestion> finish(List<CheckupQuestion> questions) {
      final filtered = assessmentPlan?.includeUncoveredCheck == false
          ? questions
              .where((question) => !question.isOpenCheck)
              .toList(growable: false)
          : questions;
      final mode = modeById(modeId);
      final limit = (assessmentPlan?.questionLimit ?? mode.maxQuestionCount)
          .clamp(1, mode.maxQuestionCount)
          .toInt();
      return filtered.take(limit).toList(growable: false);
    }

    switch (modeId) {
      case 'safety':
        return finish(pick(const <String>[
          'B20-S1',
          'B20-S2',
          'B20-S3',
          'B20-S4',
          'B20-F1',
        ]));
      case 'daily':
        final start = clock.difference(DateTime(2025)).inDays.abs() % 8;
        final domainIds = List<String>.generate(
          4,
          (index) => 'B20-D${(start + index) % 8 + 1}',
        );
        return finish(pick(<String>['B20-S1', 'B20-F1', ...domainIds]));
      case 'five_minute':
        return finish(pick(<String>[
          'B20-S1',
          'B20-S2',
          'B20-S3',
          'B20-S4',
          'B20-F1',
          'B20-F2',
          ...List<String>.generate(8, (index) => 'B20-D${index + 1}'),
        ]));
      case 'standard':
        return finish(<CheckupQuestion>[
          ...b20Questions,
          for (final domainId in domainNames.keys)
            ..._indicatorQuestions(
              domainId,
              2,
              clock,
              assessmentPlan: assessmentPlan,
              history: history,
            ),
        ]);
      case 'focused':
        final domainId = domainNames.containsKey(focusDomainId)
            ? focusDomainId!
            : 'D1';
        final anchorId = 'B20-D${domainId.substring(1)}';
        return finish(<CheckupQuestion>[
          ...pick(const <String>[
            'B20-S1',
            'B20-S2',
            'B20-S3',
            'B20-S4',
            'B20-F1',
            'B20-F2',
          ]),
          ...pick(<String>[
            anchorId,
            'B20-C1',
            'B20-C2',
            'B20-Q1',
            'B20-Q2',
          ]),
          ..._indicatorQuestions(
            domainId,
            30,
            clock,
            assessmentPlan: assessmentPlan,
            history: history,
          ),
        ]);
      case 'comprehensive':
        return finish(<CheckupQuestion>[
          ...b20Questions,
          for (final domainId in domainNames.keys)
            ..._indicatorQuestions(
              domainId,
              5,
              clock,
              assessmentPlan: assessmentPlan,
              history: history,
            ),
        ]);
      case 'b20':
      default:
        return finish(List<CheckupQuestion>.unmodifiable(b20Questions));
    }
  }

  List<CheckupQuestion> adaptiveQuestions({
    required String modeId,
    required CheckupQuestion question,
    required CheckupAnswer answer,
    required Set<String> existingQuestionIds,
    DateTime? now,
    CheckupAssessmentPlan? assessmentPlan,
    List<CheckupSession> history = const <CheckupSession>[],
  }) {
    if (modeId == 'safety' ||
        modeId == 'daily' ||
        modeId == 'five_minute' ||
        modeId == 'focused' ||
        modeId == 'comprehensive') {
      return const <CheckupQuestion>[];
    }
    final clock = now ?? DateTime.now();
    final candidates = <CheckupQuestion>[];
    final domainMatch = RegExp(r'B20-D([1-8])').firstMatch(question.id);
    if (domainMatch != null && answer.value <= 2) {
      candidates.addAll(
        _indicatorQuestions(
          'D${domainMatch.group(1)}',
          4,
          clock,
          assessmentPlan: assessmentPlan,
          history: history,
        ),
      );
    }
    if (question.id == 'B20-C1' && answer.value >= 2) {
      candidates.addAll(
        _indicatorQuestions(
          'D3',
          4,
          clock,
          assessmentPlan: assessmentPlan,
          history: history,
        ),
      );
    }
    if (question.isFunction && answer.value >= 2) {
      candidates.addAll(_functionBranchQuestions());
    }
    return candidates
        .where((item) => !existingQuestionIds.contains(item.id))
        .toList(growable: false);
  }

  List<CheckupQuestion> restoreQuestionOrder(
    List<CheckupQuestion> questions, {
    required String sessionId,
    List<String> storedQuestionIds = const <String>[],
    bool preservePriorityOrder = false,
  }) {
    final byId = <String, CheckupQuestion>{
      for (final question in questions) question.id: question,
    };
    if (storedQuestionIds.isNotEmpty) {
      for (final retired in retiredPublishedQuestions) {
        if (storedQuestionIds.contains(retired.id)) {
          byId.putIfAbsent(retired.id, () => retired);
        }
      }
      final restored = storedQuestionIds
          .map((id) => byId.remove(id))
          .whereType<CheckupQuestion>()
          .toList(growable: true);
      restored.addAll(byId.values);
      return restored;
    }

    final gates = questions
        .where((item) => item.isSafety || item.isFunction)
        .toList(growable: false);
    final remainder = questions
        .where((item) => !item.isSafety && !item.isFunction)
        .toList(growable: true);
    if (preservePriorityOrder) {
      return <CheckupQuestion>[...gates, ...remainder];
    }
    var seed = 0x811C9DC5;
    for (final unit in sessionId.codeUnits) {
      seed = ((seed ^ unit) * 0x01000193) & 0x7FFFFFFF;
    }
    for (var index = remainder.length - 1; index > 0; index--) {
      seed = (1103515245 * seed + 12345) & 0x7FFFFFFF;
      final target = seed % (index + 1);
      final value = remainder[index];
      remainder[index] = remainder[target];
      remainder[target] = value;
    }
    return <CheckupQuestion>[...gates, ...remainder];
  }

  List<CheckupQuestion> _indicatorQuestions(
    String domainId,
    int count,
    DateTime now, {
    CheckupAssessmentPlan? assessmentPlan,
    List<CheckupSession> history = const <CheckupSession>[],
  }) {
    final matching = indicators
        .where((indicator) => _domainForIndicator(indicator) == domainId)
        .toList(growable: false);
    if (matching.isEmpty) return const <CheckupQuestion>[];
    final anchorIndicatorIds = b20Questions
        .map((e) => e.indicatorId)
        .whereType<String>()
        .toSet();
    var candidates = matching
        .where(
          (indicator) =>
              !anchorIndicatorIds.contains(indicator.id) ||
              publishedQuestions.any(
                (question) => question.indicatorId == indicator.id,
              ),
        )
        .toList(growable: false);
    if (candidates.isEmpty) return const <CheckupQuestion>[];
    final selected = <CheckupIndicator>[];
    if (assessmentPlan?.useLongitudinalPrioritization == true &&
        history.isNotEmpty) {
      final plan = assessmentPlan!;
      candidates = List<CheckupIndicator>.of(candidates)
        ..sort((left, right) {
          final comparison = _indicatorPriority(
            right,
            history: history,
            now: now,
            assessmentPlan: plan,
          ).compareTo(
            _indicatorPriority(
              left,
              history: history,
              now: now,
              assessmentPlan: plan,
            ),
          );
          return comparison != 0 ? comparison : left.id.compareTo(right.id);
        });
      selected.addAll(candidates.take(count));
    } else {
      final offset = (now.year * 372 +
              now.month * 31 +
              now.day +
              domainId.hashCode.abs()) %
          candidates.length;
      for (var index = 0;
          index < count && index < candidates.length;
          index++) {
        selected.add(candidates[(offset + index) % candidates.length]);
      }
    }
    final questions = <CheckupQuestion>[];
    for (final indicator in selected) {
      final published = _publishedQuestionsForIndicator(indicator, now);
      if (published.isNotEmpty) {
        questions.addAll(published);
        continue;
      }
      final risk = indicator.type == '风险型';
      final promptPrefix = risk
          ? '过去14天，以下情况出现的程度是：'
          : indicator.type == '功能结果'
              ? '过去14天，以下现实功能在多大程度上符合你：'
              : '过去14天，以下能力在多大程度上符合你：';
      questions.add(CheckupQuestion(
        id: 'IND-${indicator.id}',
        group: '${domainNames[domainId]} · 深入追问',
        kind: indicator.type,
        prompt: '$promptPrefix${indicator.name}',
        scaleLabel: risk
            ? '0 从未 - 4 几乎总是（越高风险越高）'
            : '0 完全不符合 - 4 非常符合（越高越健康）',
        direction: risk ? '越高风险越高' : '越高越健康',
        indicatorId: indicator.id,
        sourceLevel:
            indicator.directness.contains('直接证据较强') ? 'C1' : 'C2',
        required: false,
        domainId: domainId,
        lecture: indicator.lecture,
        evidenceLocation: indicator.definitionLocation,
        choices: _zeroToFourChoices(),
      ));
    }
    return questions.take(count).toList(growable: false);
  }

  List<CheckupQuestion> _publishedQuestionsForIndicator(
    CheckupIndicator indicator,
    DateTime now,
  ) {
    final available = publishedQuestions
        .where((question) => question.indicatorId == indicator.id)
        .toList(growable: false);
    if (available.isEmpty) return const <CheckupQuestion>[];
    final knowledge = available
        .where((question) => question.isKnowledge)
        .toList(growable: false);
    if (indicator.id.contains('-K')) {
      if (knowledge.isEmpty) {
        // A1/A9 are confidence evidence only. They must never replace the
        // paired objective A7 item or enter the K score by themselves.
        return const <CheckupQuestion>[];
      }
      final result = <CheckupQuestion>[
        knowledge[
            _stableHash('${indicator.id}:${now.year}-${now.month}') %
                knowledge.length],
      ];
      final calibration = available
          .where(
            (question) =>
                question.scoringRole ==
                CheckupQuestionScoringRole.contextOnly,
          )
          .toList(growable: false);
      if (calibration.isNotEmpty) {
        result.add(
          calibration[
              _stableHash('${indicator.id}:${now.year}-${now.month}-${now.day}') %
                  calibration.length],
        );
      }
      return result;
    }
    final scoreBearing = available
        .where((question) => question.contributesToHealth)
        .toList(growable: false);
    if (scoreBearing.isEmpty) return const <CheckupQuestion>[];
    return <CheckupQuestion>[
      scoreBearing[
          _stableHash('${indicator.id}:${now.year}-${now.month}-${now.day}') %
              scoreBearing.length],
    ];
  }

  double _indicatorPriority(
    CheckupIndicator indicator, {
    required List<CheckupSession> history,
    required DateTime now,
    required CheckupAssessmentPlan assessmentPlan,
  }) {
    final observations = <({CheckupAnswer answer, CheckupSession session})>[];
    for (final session in history) {
      for (final answer in session.answers) {
        final indicatorId = _indicatorIdForQuestion(answer.questionId);
        if (indicatorId == indicator.id) {
          observations.add((answer: answer, session: session));
        }
      }
    }
    observations.sort(
      (left, right) =>
          right.session.completedAtMs.compareTo(left.session.completedAtMs),
    );

    double riskFor(CheckupAnswer answer) {
      final normalized = (answer.value / 4).clamp(0, 1).toDouble();
      return indicator.type.contains('风险') ? normalized : 1 - normalized;
    }

    final latestRisk =
        observations.isEmpty ? 0.35 : riskFor(observations.first.answer);
    final priorRisk =
        observations.length < 2 ? latestRisk : riskFor(observations[1].answer);
    final deterioration = (latestRisk - priorRisk).clamp(0, 1).toDouble();
    final latestQuality = observations.isEmpty
        ? 50.0
        : observations.first.session.report.dataQuality;
    final evidenceUncertainty = indicator.directEvidenceCount <= 1 ||
            indicator.reviewStatus.contains('待')
        ? 1.0
        : indicator.directness.contains('直接证据较强')
            ? 0.15
            : 0.55;
    final uncertainty =
        (((100 - latestQuality) / 100) * 0.55 + evidenceUncertainty * 0.45)
            .clamp(0, 1)
            .toDouble();
    final daysSince = observations.isEmpty
        ? 365
        : now
            .difference(
              DateTime.fromMillisecondsSinceEpoch(
                observations.first.session.completedAtMs,
              ),
            )
            .inDays
            .clamp(0, 3650);
    final coverage = (daysSince / 90).clamp(0, 1).toDouble();
    final randomExploration =
        (_stableHash('${indicator.id}:${now.year}-${now.month}') % 1000) / 999;
    final stableStrength =
        latestRisk < 0.25 && deterioration == 0 && observations.isNotEmpty;
    final burden = stableStrength
        ? assessmentPlan.timeBudgetMinutes <= 10
            ? 1.0
            : 0.65
        : assessmentPlan.timeBudgetMinutes <= 5
            ? 0.35
            : 0.1;
    final dueDays = _maximumUncheckedDays(
      latestRisk: latestRisk,
      hasObservation: observations.isNotEmpty,
      indicator: indicator,
    );
    final dueBoost = daysSince >= dueDays ? 0.25 : 0.0;
    return latestRisk * 0.30 +
        deterioration * 0.25 +
        uncertainty * 0.15 +
        coverage * 0.20 +
        randomExploration * 0.10 -
        burden * 0.15 +
        dueBoost;
  }

  String? _indicatorIdForQuestion(String questionId) {
    if (questionId.startsWith('IND-')) return questionId.substring(4);
    for (final question in <CheckupQuestion>[
      ...b20Questions,
      ...publishedQuestions,
    ]) {
      if (question.id == questionId) return question.indicatorId;
    }
    return null;
  }

  int _maximumUncheckedDays({
    required double latestRisk,
    required bool hasObservation,
    required CheckupIndicator indicator,
  }) {
    String target;
    if (latestRisk >= 0.5) {
      target = '红/橙指标';
    } else if (latestRisk >= 0.25) {
      target = '黄色指标';
    } else if (!hasObservation) {
      target = '23讲核心指标';
    } else if (indicator.directEvidenceCount >= 3) {
      target = '关键指标';
    } else {
      target = '微观指标';
    }
    for (final rule in longitudinalCoverageRules) {
      if (rule.value('指标层级') != target) continue;
      final values = RegExp(r'\d+')
          .allMatches(rule.value('最长未检查时间'))
          .map((match) => int.tryParse(match.group(0) ?? ''))
          .whereType<int>()
          .toList(growable: false);
      if (values.isNotEmpty) return values.last;
    }
    return switch (target) {
      '红/橙指标' => 7,
      '黄色指标' => 30,
      '23讲核心指标' => 60,
      '关键指标' => 90,
      _ => 180,
    };
  }

  static int _stableHash(String value) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  static List<CheckupQuestion> _functionBranchQuestions() =>
      const <CheckupQuestion>[
        CheckupQuestion(
          id: 'BR-F-TIME',
          group: '功能分支',
          kind: '功能时间线',
          prompt: '现实功能受到影响的时间更接近哪一种？',
          scaleLabel: '结构化时间线，不保存开放文本',
          direction: 'D2安全与功能分流',
          sourceLevel: 'D2',
          required: false,
          choices: <CheckupAnswerChoice>[
            CheckupAnswerChoice('今天或昨天开始', 3),
            CheckupAnswerChoice('过去1周内开始', 2),
            CheckupAnswerChoice('持续2周以上', 1),
            CheckupAnswerChoice('不确定', 0),
          ],
        ),
        CheckupQuestion(
          id: 'BR-F-BREADTH',
          group: '功能分支',
          kind: '功能范围',
          prompt: '影响目前覆盖多少类现实生活？',
          scaleLabel: '学习/工作、关系、自我照护、睡眠等',
          direction: '越高风险越高',
          sourceLevel: 'D2',
          required: false,
          choices: <CheckupAnswerChoice>[
            CheckupAnswerChoice('尚未明显影响', 0),
            CheckupAnswerChoice('主要影响1类', 1),
            CheckupAnswerChoice('影响2类', 2),
            CheckupAnswerChoice('影响3类及以上', 3),
          ],
        ),
        CheckupQuestion(
          id: 'BR-F-BODY',
          group: '功能分支',
          kind: '共同原因',
          prompt: '睡眠、身体不适、药物变化或恢复不足，是否可能解释本次变化？',
          scaleLabel: '用于避免把课程外因素误判为课程机制',
          direction: '用于分流',
          sourceLevel: 'D2',
          required: false,
          choices: <CheckupAnswerChoice>[
            CheckupAnswerChoice('不太可能', 0),
            CheckupAnswerChoice('不确定', 1),
            CheckupAnswerChoice('有一定可能', 2),
            CheckupAnswerChoice('很可能', 3),
          ],
        ),
        CheckupQuestion(
          id: 'BR-F-SUPPORT',
          group: '功能分支',
          kind: '支持可及性',
          prompt: '如果状态继续恶化，你目前是否有可信任的人或专业支持可以联系？',
          scaleLabel: '用于支持路径，不进入幸福总分',
          direction: '越高保护越强',
          sourceLevel: 'D2',
          required: false,
          choices: <CheckupAnswerChoice>[
            CheckupAnswerChoice('没有或不确定', 0),
            CheckupAnswerChoice('可能有，但尚未联系', 1),
            CheckupAnswerChoice('有明确联系人', 2),
            CheckupAnswerChoice('已经在获得支持', 3),
          ],
        ),
      ];

  static List<Map<String, dynamic>> _mapList(dynamic value) =>
      (value as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);

  static List<CheckupReferenceRule> _ruleList(dynamic value) => _mapList(value)
      .map(
        (row) => CheckupReferenceRule(
          <String, String>{
            for (final entry in row.entries)
              entry.key: entry.value?.toString() ?? '',
          },
        ),
      )
      .toList(growable: false);

  static Map<String, Map<String, String>> _fieldMappings(dynamic value) {
    if (value is! Map) return const <String, Map<String, String>>{};
    return <String, Map<String, String>>{
      for (final entry in value.entries)
        entry.key.toString(): <String, String>{
          if (entry.value is Map)
            for (final field in (entry.value as Map).entries)
              field.key.toString(): field.value?.toString() ?? '',
        },
    };
  }

  static CheckupModeSpec _modeFromJson(Map<String, dynamic> json) {
    final name = (json['模式'] ?? '').toString();
    return CheckupModeSpec(
      id: _modeIdForName(name),
      name: name,
      duration: (json['时间'] ?? '').toString(),
      baseQuestionCount: _firstInt(json['基础题量']) ?? 0,
      maxQuestionCount: _firstInt(json['最多题量']) ?? 0,
      fixedContent: (json['固定内容'] ?? '').toString(),
      actionCount: (json['行动数'] ?? '').toString(),
      useCase: (json['适用场景'] ?? '').toString(),
      coverageLevel: (json['结论覆盖等级'] ?? '').toString(),
    );
  }

  static String _modeIdForName(String name) {
    const map = <String, String>{
      '安全快检': 'safety',
      '每日脉搏': 'daily',
      '五分钟版': 'five_minute',
      'B20快速基准': 'b20',
      '标准版': 'standard',
      '聚焦深入版': 'focused',
      '综合深入版': 'comprehensive',
    };
    return map[name] ?? 'b20';
  }

  static int? _firstInt(dynamic value) {
    final match = RegExp(r'\d+').firstMatch((value ?? '').toString());
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static CheckupIndicator _indicatorFromJson(Map<String, dynamic> json) =>
      CheckupIndicator(
        id: (json['指标ID'] ?? '').toString(),
        lecture: (json['讲次'] as num?)?.toInt() ?? 0,
        area: (json['领域'] ?? '').toString(),
        name: (json['指标名称'] ?? '').toString(),
        type: (json['类型'] ?? '').toString(),
        definitionLocation: (json['DEF定义位置'] ?? '').toString(),
        lowLocation: (json['LOW低端位置'] ?? '').toString(),
        highLocation: (json['HIGH高端位置'] ?? '').toString(),
        actionLocation: (json['ACT行动位置'] ?? '').toString(),
        directEvidenceCount: (json['直接证据数'] as num?)?.toInt() ?? 0,
        directness: (json['直接性'] ?? '').toString(),
        reviewStatus: (json['审核状态'] ?? '').toString(),
      );

  static CheckupQuestion _b20QuestionFromJson(
    Map<String, dynamic> json,
    Map<String, CheckupIndicator> indicators,
  ) {
    final id = (json['题号'] ?? '').toString();
    final indicatorId = json['指标ID']?.toString();
    final indicator = indicatorId == null ? null : indicators[indicatorId];
    return CheckupQuestion(
      id: id,
      group: (json['组别'] ?? '').toString(),
      kind: (json['题型'] ?? '').toString(),
      prompt: (json['题目'] ?? '').toString(),
      scaleLabel: (json['量尺/选项'] ?? '').toString(),
      direction: (json['计分方向'] ?? '').toString(),
      indicatorId: indicatorId,
      sourceLevel: (json['来源等级'] ?? '').toString(),
      required: (json['是否固定'] ?? '').toString() == '是',
      domainId: _domainForB20(id, indicator?.area),
      lecture: indicator?.lecture,
      evidenceLocation: indicator?.definitionLocation,
      choices: _choicesForB20(id, (json['量尺/选项'] ?? '').toString()),
    );
  }

  static List<CheckupAnswerChoice> _choicesForB20(
      String id, String rawScale) {
    if (id == 'B20-S1' || id == 'B20-S2' || id == 'B20-S4') {
      return const <CheckupAnswerChoice>[
        CheckupAnswerChoice('否', 0),
        CheckupAnswerChoice('不确定', 1),
        CheckupAnswerChoice('是', 2),
      ];
    }
    if (id == 'B20-S3') {
      return const <CheckupAnswerChoice>[
        CheckupAnswerChoice('无', 0),
        CheckupAnswerChoice('轻度', 1),
        CheckupAnswerChoice('明显', 2),
        CheckupAnswerChoice('严重', 3),
      ];
    }
    if (id == 'B20-Q1') {
      return const <CheckupAnswerChoice>[
        CheckupAnswerChoice('否', 0),
        CheckupAnswerChoice('是（本轮只记录“存在遗漏”，不保存原文）', 1),
      ];
    }
    if (id == 'B20-K1' || id == 'B20-K2') {
      final parts = rawScale
          .split(RegExp('[;；]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      return List<CheckupAnswerChoice>.generate(
        parts.length,
        (index) => CheckupAnswerChoice(parts[index], index.toDouble()),
      );
    }
    if (rawScale.trim().startsWith('1')) {
      return List<CheckupAnswerChoice>.generate(
        5,
        (index) => CheckupAnswerChoice('${index + 1}', (index + 1).toDouble()),
      );
    }
    return _zeroToFourChoices();
  }

  static List<CheckupAnswerChoice> _zeroToFourChoices() =>
      List<CheckupAnswerChoice>.generate(
        5,
        (index) => CheckupAnswerChoice('$index', index.toDouble()),
      );

  static String? _domainForB20(String id, String? area) {
    final match = RegExp(r'B20-D([1-8])').firstMatch(id);
    if (match != null) return 'D${match.group(1)}';
    if (id == 'B20-C1' || id == 'B20-C2') return 'D3';
    return area == null ? null : _domainForArea(area);
  }

  static String _domainForArea(String area) {
    switch (area) {
      case '情绪与认知':
        return 'D1';
      case '目标与意义':
        return 'D4';
      case '优势与压力':
        return 'D5';
      case '身心基础':
        return 'D6';
      case '关系与连接':
        return 'D7';
      case '自尊与实现':
        return 'D8';
      case '学习与转化':
      case '改变与习惯':
      case '整合与持续':
      default:
        return 'D3';
    }
  }

  static String _domainForIndicator(CheckupIndicator indicator) {
    // The source corpus groups Lectures 4-9 under one broad area, while the
    // checkup specification deliberately separates emotional acceptance (D1)
    // from realistic optimism (D2). Keep that split deterministic and local.
    if (indicator.area == '情绪与认知') {
      return indicator.lecture >= 5 && indicator.lecture <= 9 ? 'D2' : 'D1';
    }
    return _domainForArea(indicator.area);
  }

  static CheckupDiagnosisPattern _diagnosisFromJson(
          Map<String, dynamic> json) =>
      CheckupDiagnosisPattern(
        id: (json['模式ID'] ?? '').toString(),
        name: (json['课程型诊断名称'] ?? '').toString(),
        triggerIndicatorIds: _splitIds(json['触发指标']),
        mechanism: (json['机制假设'] ?? '').toString(),
        prescriptionIds: _splitIds(json['推荐处方ID']),
        priorityAction: (json['优先行动'] ?? '').toString(),
        evidenceNeeded: (json['诊断所需证据'] ?? '').toString(),
        exclusions: (json['主要反证/排除'] ?? '').toString(),
        confidenceRule: (json['置信度要求'] ?? '').toString(),
        reviewStatus: (json['审核状态'] ?? '').toString(),
      );

  static List<String> _splitIds(dynamic value) => (value ?? '')
      .toString()
      .split(RegExp('[;；]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  static CheckupPrescription _prescriptionFromJson(
          Map<String, dynamic> json) =>
      CheckupPrescription(
        id: (json['处方ID'] ?? '').toString(),
        lecture: (json['讲次'] as num?)?.toInt() ?? 0,
        theme: (json['课程主题'] ?? '').toString(),
        primaryIndicatorId: (json['主要指标ID'] ?? '').toString(),
        primaryIndicator: (json['主要指标'] ?? '').toString(),
        actionLocation: (json['ACT课程位置'] ?? '').toString(),
        mechanism: (json['适用机制'] ?? '').toString(),
        startingAction: (json['起始课程处方'] ?? '').toString(),
        deepeningAction: (json['深入课程处方'] ?? '').toString(),
        microDose: (json['微量'] ?? '').toString(),
        startingDose: (json['起始量'] ?? '').toString(),
        consolidationDose: (json['巩固量'] ?? '').toString(),
        trialPeriod: (json['建议试验期'] ?? '').toString(),
        outcomeEvidence: (json['疗效证据'] ?? '').toString(),
        stopRule: (json['过度化/停止规则'] ?? '').toString(),
        sourceLevel: (json['来源等级'] ?? '').toString(),
        reviewStatus: (json['审核状态'] ?? '').toString(),
      );
}
